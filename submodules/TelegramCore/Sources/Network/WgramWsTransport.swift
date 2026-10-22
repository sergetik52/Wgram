import Foundation
import MtProtoKit

public final class WgramWsDomainPool {
    public static let shared = WgramWsDomainPool()

    public static let defaultDomains: [String] = [
        "noskomnadzor.co.uk",
        "cakeisalie.co.uk",
        "kartoshka.co.uk",
        "pclead.co.uk",
        "pomogite.co.uk",
        "stopblocking.co.uk",
        "offshor.co.uk",
        "web.telegram.org"
    ]

    private var currentIndex: Int = 0
    private let lock = NSLock()

    public func getBaseDomain() -> String {
        let selected = WgramSettings.tgWsSelectedDomain
        if selected == "custom" {
            let custom = WgramSettings.tgWsCustomDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            if !custom.isEmpty {
                return custom
            }
        } else if selected != "auto" && !selected.isEmpty {
            return selected
        }

        self.lock.lock()
        defer { self.lock.unlock() }
        return Self.defaultDomains[self.currentIndex % Self.defaultDomains.count]
    }

    public func reportFailure(domain: String) {
        guard WgramSettings.tgWsAutoFallback else { return }
        self.lock.lock()
        defer { self.lock.unlock() }
        let current = Self.defaultDomains[self.currentIndex % Self.defaultDomains.count]
        if current == domain {
            self.currentIndex = (self.currentIndex + 1) % Self.defaultDomains.count
        }
    }

    public static func endpointUrl(dc: Int, isMedia: Bool = false) -> (url: URL, baseDomain: String)? {
        let base = shared.getBaseDomain()
        let prefix = isMedia ? "kws\(dc)-1" : "kws\(dc)"
        let host: String
        if base.contains("web.telegram.org") {
            host = "\(prefix).web.telegram.org"
        } else if base.hasPrefix("kws") {
            host = base
        } else {
            host = "\(prefix).\(base)"
        }
        guard let url = URL(string: "wss://\(host)/apiws") else {
            return nil
        }
        return (url, base)
    }

    public static func voipEndpointUrl(ip: String, port: Int32) -> (url: URL, baseDomain: String)? {
        let base = shared.getBaseDomain()
        let host: String
        if base.contains("web.telegram.org") {
            host = "kws1.web.telegram.org"
        } else if base.hasPrefix("kws") {
            host = base
        } else {
            host = "kws1.\(base)"
        }
        guard let url = URL(string: "wss://\(host)/voipws?ip=\(ip)&port=\(port)") else {
            return nil
        }
        return (url, base)
    }
}

public final class WgramWsTransport {
    public static let shared = WgramWsTransport()

    public func makeConnectionInterface(delegate: MTTcpConnectionInterfaceDelegate, delegateQueue: DispatchQueue) -> MTTcpConnectionInterface {
        return WgramWsConnection(delegate: delegate, delegateQueue: delegateQueue)
    }
}

private final class WgramWsConnection: NSObject, MTTcpConnectionInterface, URLSessionWebSocketDelegate {
    private struct ReadRequest {
        let length: Int
        let tag: Int
    }

    private weak var delegate: MTTcpConnectionInterfaceDelegate?
    private let delegateQueue: DispatchQueue
    private let queue = DispatchQueue(label: "org.wgram.wsConnection")

    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var baseDomain: String = ""
    private var incoming = Data()
    private var reads: [ReadRequest] = []
    private var closed = false
    private var hasSentHandshake = false
    private var isConnected = false

    init(delegate: MTTcpConnectionInterfaceDelegate, delegateQueue: DispatchQueue) {
        self.delegate = delegate
        self.delegateQueue = delegateQueue
        super.init()
    }

    public func setGetLogPrefix(_ getLogPrefix: (() -> String)?) {
    }

    public func setUsageCalculationInfo(_ usageCalculationInfo: MTNetworkUsageCalculationInfo?) {
    }

    public func connect(toHost inHost: String, onPort port: UInt16, viaInterface inInterface: String?, withTimeout timeout: TimeInterval, error errPtr: NSErrorPointer) -> Bool {
        self.queue.async {
            guard !self.closed else { return }
            let dc = self.resolveDatacenterId(from: inHost)
            guard let endpoint = WgramWsDomainPool.endpointUrl(dc: dc) else {
                self.notifyDisconnect(error: NSError(domain: "WgramWs", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint URL"]))
                return
            }
            self.baseDomain = endpoint.baseDomain

            var request = URLRequest(url: endpoint.url)
            request.setValue("binary", forHTTPHeaderField: "Sec-WebSocket-Protocol")
            request.timeoutInterval = min(max(timeout, 5.0), 15.0)

            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.urlCache = nil
            config.timeoutIntervalForRequest = 20.0
            config.timeoutIntervalForResource = 86400.0

            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session

            let task = session.webSocketTask(with: request)
            self.webSocketTask = task
            task.resume()

            self.startReceiving()
        }
        return true
    }

    private func resolveDatacenterId(from host: String) -> Int {
        if host.contains("149.154.175.5") || host.contains("149.154.175.10") { return 1 }
        if host.contains("149.154.167.5") || host.contains("95.161.76.100") || host.contains("149.154.167.40") { return 2 }
        if host.contains("149.154.175.100") || host.contains("149.154.175.117") { return 3 }
        if host.contains("149.154.167.9") { return 4 }
        if host.contains("149.154.171.5") { return 5 }
        return 2
    }

    private func startReceiving() {
        guard !self.closed, let task = self.webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            self.queue.async {
                guard !self.closed else { return }
                switch result {
                case let .success(message):
                    switch message {
                    case let .data(data):
                        self.handleIncoming(data)
                    case let .string(string):
                        if let data = string.data(using: .utf8) {
                            self.handleIncoming(data)
                        }
                    @unknown default:
                        break
                    }
                    self.startReceiving()
                case let .failure(error):
                    WgramWsDomainPool.shared.reportFailure(domain: self.baseDomain)
                    self.notifyDisconnect(error: error)
                }
            }
        }
    }

    private func handleIncoming(_ data: Data) {
        self.incoming.append(data)
        self.drainReads()
    }

    public func write(_ data: Data) {
        self.queue.async {
            guard !self.closed, let task = self.webSocketTask else { return }
            if !self.hasSentHandshake {
                self.hasSentHandshake = true
                if data.count >= 64 {
                    let handshake = data.prefix(64)
                    let remaining = data.dropFirst(64)
                    task.send(.data(Data(handshake))) { [weak self] error in
                        if let error = error {
                            self?.queue.async {
                                self?.notifyDisconnect(error: error)
                            }
                        }
                    }
                    if !remaining.isEmpty {
                        task.send(.data(Data(remaining))) { [weak self] error in
                            if let error = error {
                                self?.queue.async {
                                    self?.notifyDisconnect(error: error)
                                }
                            }
                        }
                    }
                    return
                }
            }

            task.send(.data(data)) { [weak self] error in
                if let error = error {
                    self?.queue.async {
                        self?.notifyDisconnect(error: error)
                    }
                }
            }
        }
    }

    public func readData(toLength length: UInt, withTimeout timeout: TimeInterval, tag: Int) {
        self.queue.async {
            guard !self.closed, length > 0, length <= UInt(Int.max) else { return }
            self.reads.append(ReadRequest(length: Int(length), tag: tag))
            self.drainReads()
        }
    }

    private func drainReads() {
        while let request = self.reads.first, self.incoming.count >= request.length {
            self.reads.removeFirst()
            let chunk = self.incoming.prefix(request.length)
            self.incoming.removeFirst(request.length)

            let delegate = self.delegate
            let chunkData = Data(chunk)
            self.delegateQueue.async { [weak delegate] in
                delegate?.connectionInterfaceDidReadPartialData(ofLength: UInt(request.length), tag: request.tag)
                delegate?.connectionInterfaceDidRead(chunkData, withTag: request.tag, networkType: 0)
            }
        }
    }

    public func disconnect() {
        self.queue.async {
            guard !self.closed else { return }
            self.closed = true
            self.webSocketTask?.cancel(with: .normalClosure, reason: nil)
            self.webSocketTask = nil
            self.session?.invalidateAndCancel()
            self.session = nil
            self.incoming.removeAll()
            self.reads.removeAll()
            let delegate = self.delegate
            self.delegateQueue.async { [weak delegate] in
                delegate?.connectionInterfaceDidDisconnectWithError(nil)
            }
        }
    }

    public func resetDelegate() {
        self.queue.async {
            self.delegate = nil
        }
    }

    private func notifyDisconnect(error: Error?) {
        guard !self.closed else { return }
        self.closed = true
        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.webSocketTask = nil
        self.session?.invalidateAndCancel()
        self.session = nil
        self.incoming.removeAll()
        self.reads.removeAll()
        let delegate = self.delegate
        self.delegateQueue.async { [weak delegate] in
            delegate?.connectionInterfaceDidDisconnectWithError(error)
        }
    }

    // MARK: - URLSessionWebSocketDelegate
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.queue.async {
            guard !self.closed, !self.isConnected else { return }
            self.isConnected = true
            let delegate = self.delegate
            self.delegateQueue.async { [weak delegate] in
                delegate?.connectionInterfaceDidConnect()
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.queue.async {
                WgramWsDomainPool.shared.reportFailure(domain: self.baseDomain)
                self.notifyDisconnect(error: error)
            }
        }
    }
}
