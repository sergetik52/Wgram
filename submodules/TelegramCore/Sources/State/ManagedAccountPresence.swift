import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

private typealias SignalKitTimer = SwiftSignalKit.Timer


private final class AccountPresenceManagerImpl {
    private let queue: Queue
    private let network: Network
    let isPerformingUpdate = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var shouldKeepOnlinePresenceDisposable: Disposable?
    private let currentRequestDisposable = MetaDisposable()
    private var onlineTimer: SignalKitTimer?
    
    private var wasOnline: Bool = false
    private var settingsNotificationObserver: AnyObject?
    
    init(queue: Queue, shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network) {
        self.queue = queue
        self.network = network
        
        self.shouldKeepOnlinePresenceDisposable = (shouldKeepOnlinePresence
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            guard let `self` = self else {
                return
            }
            if self.wasOnline != value {
                self.wasOnline = value
                self.updatePresence(value)
            }
        })

        self.settingsNotificationObserver = NotificationCenter.default.addObserver(forName: WgramSettings.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.queue.async {
                let targetOnline = WgramSettings.dontUpdateOnline ? false : strongSelf.wasOnline
                strongSelf.updatePresence(targetOnline)
            }
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.shouldKeepOnlinePresenceDisposable?.dispose()
        self.currentRequestDisposable.dispose()
        self.onlineTimer?.invalidate()
        if let observer = self.settingsNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updatePresence(_ isOnline: Bool) {
        let request: Signal<Api.Bool, MTRpcError>
        if isOnline {
            self.onlineTimer?.invalidate()
            if WgramSettings.dontUpdateOnline {
                self.onlineTimer = nil
                request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
            } else {
                let timer = SignalKitTimer(timeout: 25.0, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updatePresence(true)
                }, queue: self.queue)
                self.onlineTimer = timer
                timer.start()
                request = self.network.request(Api.functions.account.updateStatus(offline: .boolFalse))
            }
        } else {
            self.onlineTimer?.invalidate()
            self.onlineTimer = nil
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        }
        self.isPerformingUpdate.set(true)
        self.currentRequestDisposable.set((request
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPerformingUpdate.set(false)
        }))
    }
}

final class AccountPresenceManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<AccountPresenceManagerImpl>
    
    init(shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return AccountPresenceManagerImpl(queue: queue, shouldKeepOnlinePresence: shouldKeepOnlinePresence, network: network)
        })
    }
    
    func isPerformingUpdate() -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isPerformingUpdate.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
