import Foundation
import Network

public final class WgramVoipWsBridge {
    public static let shared = WgramVoipWsBridge()

    public struct TargetEndpoint: Hashable {
        public let ip: String
        public let port: Int32

        public init(ip: String, port: Int32) {
            self.ip = ip
            self.port = port
        }
    }

    private final class RelaySession {
        let endpoint: TargetEndpoint
        let localConnection: NWConnection
        let wsTask: URLSessionWebSocketTask
        let session: URLSession
        let queue: DispatchQueue
        private var isClosed: Bool = false
        private var hasReceivedWsData = false
        private var directFallbackConnection: NWConnection?
        private var pendingLocalData: [Data] = []

        init(endpoint: TargetEndpoint, localConnection: NWConnection, wsTask: URLSessionWebSocketTask, session: URLSession, queue: DispatchQueue) {
            self.endpoint = endpoint
            self.localConnection = localConnection
            self.wsTask = wsTask
            self.session = session
            self.queue = queue
        }

        func start() {
            self.localConnection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .failed, .cancelled:
                    self?.close()
                default:
                    break
                }
            }
            self.readFromLocal()
            self.readFromWs()
        }

        private func readFromLocal() {
            self.localConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                guard let self = self, !self.isClosed else { return }
                if let data = data, !data.isEmpty {
                    if let direct = self.directFallbackConnection {
                        direct.send(content: data, completion: .contentProcessed({ [weak self] sendError in
                            if sendError != nil {
                                self?.close()
                            }
                        }))
                    } else {
                        self.pendingLocalData.append(data)
                        self.wsTask.send(.data(data)) { [weak self] sendError in
                            if sendError != nil {
                                self?.fallbackToDirect()
                            }
                        }
                    }
                }
                if isComplete || error != nil {
                    self.close()
                    return
                }
                self.readFromLocal()
            }
        }

        private func readFromWs() {
            self.wsTask.receive { [weak self] result in
                guard let self = self, !self.isClosed else { return }
                switch result {
                case let .success(message):
                    self.hasReceivedWsData = true
                    self.pendingLocalData.removeAll()
                    let data: Data?
                    switch message {
                    case let .data(d):
                        data = d
                    case let .string(s):
                        data = s.data(using: .utf8)
                    @unknown default:
                        data = nil
                    }
                    if let data = data, !data.isEmpty {
                        self.localConnection.send(content: data, completion: .contentProcessed({ [weak self] sendError in
                            if sendError != nil {
                                self?.close()
                            }
                        }))
                    }
                    self.readFromWs()
                case .failure:
                    if !self.hasReceivedWsData {
                        self.fallbackToDirect()
                    } else {
                        self.close()
                    }
                }
            }
        }

        private func fallbackToDirect() {
            guard !self.isClosed, !self.hasReceivedWsData, self.directFallbackConnection == nil else {
                self.close()
                return
            }
            self.wsTask.cancel(with: .goingAway, reason: nil)
            let targetHost = NWEndpoint.Host(self.endpoint.ip)
            guard let targetPort = NWEndpoint.Port(rawValue: UInt16(self.endpoint.port)) else {
                self.close()
                return
            }
            let direct = NWConnection(host: targetHost, port: targetPort, using: .tcp)
            self.directFallbackConnection = direct
            direct.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    guard let self = self else { return }
                    for pending in self.pendingLocalData {
                        direct.send(content: pending, completion: .contentProcessed({ _ in }))
                    }
                    self.pendingLocalData.removeAll()
                    self.readFromDirect()
                case .failed, .cancelled:
                    self?.close()
                default:
                    break
                }
            }
            direct.start(queue: self.queue)
        }

        private func readFromDirect() {
            guard let direct = self.directFallbackConnection else { return }
            direct.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                guard let self = self, !self.isClosed else { return }
                if let data = data, !data.isEmpty {
                    self.localConnection.send(content: data, completion: .contentProcessed({ [weak self] sendError in
                        if sendError != nil {
                            self?.close()
                        }
                    }))
                }
                if isComplete || error != nil {
                    self.close()
                    return
                }
                self.readFromDirect()
            }
        }

        func close() {
            self.queue.async {
                guard !self.isClosed else { return }
                self.isClosed = true
                self.localConnection.stateUpdateHandler = nil
                self.localConnection.cancel()
                self.directFallbackConnection?.stateUpdateHandler = nil
                self.directFallbackConnection?.cancel()
                self.directFallbackConnection = nil
                self.wsTask.cancel(with: .goingAway, reason: nil)
                self.session.invalidateAndCancel()
                self.pendingLocalData.removeAll()
            }
        }
    }

    private final class BridgeListener {
        let endpoint: TargetEndpoint
        let listener: NWListener
        let port: UInt16
        let queue: DispatchQueue
        private var sessions: [RelaySession] = []
        private let sessionsLock = NSLock()

        init(endpoint: TargetEndpoint, listener: NWListener, port: UInt16, queue: DispatchQueue) {
            self.endpoint = endpoint
            self.listener = listener
            self.port = port
            self.queue = queue

            self.listener.newConnectionHandler = { [weak self] connection in
                self?.handleIncoming(connection: connection)
            }
        }

        private func handleIncoming(connection: NWConnection) {
            connection.start(queue: self.queue)

            guard let endpointInfo = WgramWsDomainPool.voipEndpointUrl(ip: self.endpoint.ip, port: self.endpoint.port) else {
                connection.cancel()
                return
            }

            var request = URLRequest(url: endpointInfo.url)
            request.setValue("binary", forHTTPHeaderField: "Sec-WebSocket-Protocol")
            request.timeoutInterval = 10.0

            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.urlCache = nil
            config.timeoutIntervalForRequest = 15.0
            config.timeoutIntervalForResource = 86400.0

            let session = URLSession(configuration: config)
            let task = session.webSocketTask(with: request)
            task.resume()

            let relay = RelaySession(endpoint: self.endpoint, localConnection: connection, wsTask: task, session: session, queue: self.queue)
            relay.start()

            self.sessionsLock.lock()
            self.sessions.append(relay)
            self.sessionsLock.unlock()
        }

        func stop() {
            self.listener.stateUpdateHandler = nil
            self.listener.newConnectionHandler = nil
            self.listener.cancel()

            self.sessionsLock.lock()
            let sessionsToClose = self.sessions
            self.sessions.removeAll()
            self.sessionsLock.unlock()

            for s in sessionsToClose {
                s.close()
            }
        }
    }

    private let queue = DispatchQueue(label: "org.wgram.voipWsBridge", qos: .userInteractive)
    private var listeners: [TargetEndpoint: BridgeListener] = [:]
    private let lock = NSLock()

    private init() {}

    public func setupBridge(endpoints: [TargetEndpoint]) -> [TargetEndpoint: UInt16] {
        self.lock.lock()
        defer { self.lock.unlock() }

        var result: [TargetEndpoint: UInt16] = [:]

        for endpoint in endpoints {
            if let existing = self.listeners[endpoint] {
                result[endpoint] = existing.port
                continue
            }

            do {
                let tcpOptions = NWProtocolTCP.Options()
                let parameters = NWParameters(tls: nil, tcp: tcpOptions)
                parameters.allowLocalEndpointReuse = true
                parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)

                let listener = try NWListener(using: parameters, on: .any)
                var allocatedPort: UInt16?
                let semaphore = DispatchSemaphore(value: 0)

                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        if let p = listener.port?.rawValue {
                            allocatedPort = p
                        }
                        semaphore.signal()
                    case .failed:
                        semaphore.signal()
                    default:
                        break
                    }
                }

                listener.start(queue: self.queue)
                _ = semaphore.wait(timeout: .now() + .milliseconds(600))

                if let port = allocatedPort {
                    let bridgeListener = BridgeListener(endpoint: endpoint, listener: listener, port: port, queue: self.queue)
                    self.listeners[endpoint] = bridgeListener
                    result[endpoint] = port
                }
            } catch {
            }
        }

        return result
    }

    public func stopAll() {
        self.lock.lock()
        let active = Array(self.listeners.values)
        self.listeners.removeAll()
        self.lock.unlock()

        for listener in active {
            listener.stop()
        }
    }
}
