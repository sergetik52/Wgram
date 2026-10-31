import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public struct WgramCloudChatSummary {
    public var totalCount: Int
    public var myCount: Int
    public var peerCount: Int
    public var photoCount: Int
    public var videoCount: Int
    public var voiceCount: Int
    public var roundVideoCount: Int
    public var documentCount: Int
    public var firstMessageDate: Date?
    
    public init(
        totalCount: Int = 0,
        myCount: Int = 0,
        peerCount: Int = 0,
        photoCount: Int = 0,
        videoCount: Int = 0,
        voiceCount: Int = 0,
        roundVideoCount: Int = 0,
        documentCount: Int = 0,
        firstMessageDate: Date? = nil
    ) {
        self.totalCount = totalCount
        self.myCount = myCount
        self.peerCount = peerCount
        self.photoCount = photoCount
        self.videoCount = videoCount
        self.voiceCount = voiceCount
        self.roundVideoCount = roundVideoCount
        self.documentCount = documentCount
        self.firstMessageDate = firstMessageDate
    }
}

public func fetchWgramCloudChatSummary(account: Account, peerId: PeerId) -> Signal<WgramCloudChatSummary, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer?, Api.InputPeer?) in
        let chatPeer = transaction.getPeer(peerId).flatMap(apiInputPeer)
        let myPeer = transaction.getPeer(account.peerId).flatMap(apiInputPeer)
        return (chatPeer, myPeer)
    }
    |> mapToSignal { chatPeer, myPeer -> Signal<WgramCloudChatSummary, NoError> in
        guard let inputPeer = chatPeer else {
            return .single(WgramCloudChatSummary())
        }
        
        func queryCount(filter: Api.MessagesFilter, fromId: Api.InputPeer? = nil) -> Signal<Int, NoError> {
            var flags: Int32 = 0
            if fromId != nil {
                flags |= (1 << 0)
            }
            return account.network.request(Api.functions.messages.search(
                flags: flags,
                peer: inputPeer,
                q: "",
                fromId: fromId,
                savedPeerId: nil,
                savedReaction: nil,
                topMsgId: nil,
                filter: filter,
                minDate: 0,
                maxDate: 0,
                offsetId: 0,
                addOffset: 0,
                limit: 1,
                maxId: 0,
                minId: 0,
                hash: 0
            ))
            |> map { result -> Int in
                switch result {
                case let .channelMessages(data):
                    return Int(data.count)
                case let .messages(data):
                    return data.messages.count
                case let .messagesSlice(data):
                    return Int(data.count)
                case let .messagesNotModified(data):
                    return Int(data.count)
                }
            }
            |> `catch` { _ -> Signal<Int, NoError> in
                return .single(0)
            }
        }
        
        let totalCountSignal = queryCount(filter: .inputMessagesFilterEmpty)
        let myCountSignal = queryCount(filter: .inputMessagesFilterEmpty, fromId: myPeer)
        let photoCountSignal = queryCount(filter: .inputMessagesFilterPhotos)
        let videoCountSignal = queryCount(filter: .inputMessagesFilterVideo)
        let voiceCountSignal = queryCount(filter: .inputMessagesFilterVoice)
        let roundVideoCountSignal = queryCount(filter: .inputMessagesFilterRoundVideo)
        let docCountSignal = queryCount(filter: .inputMessagesFilterDocument)
        
        let firstMessageSignal = account.network.request(Api.functions.messages.getHistory(
            peer: inputPeer,
            offsetId: 0,
            offsetDate: 1,
            addOffset: -1,
            limit: 1,
            maxId: 0,
            minId: 0,
            hash: 0
        ))
        |> map { result -> Date? in
            let messages: [Api.Message]
            switch result {
            case let .channelMessages(data):
                messages = data.messages
            case let .messages(data):
                messages = data.messages
            case let .messagesSlice(data):
                messages = data.messages
            case .messagesNotModified:
                messages = []
            }
            for msg in messages {
                switch msg {
                case let .message(data):
                    return Date(timeIntervalSince1970: TimeInterval(data.date))
                case let .messageService(data):
                    return Date(timeIntervalSince1970: TimeInterval(data.date))
                case .messageEmpty:
                    break
                }
            }
            return nil
        }
        |> `catch` { _ -> Signal<Date?, NoError> in
            return .single(nil)
        }
        
        return combineLatest(
            totalCountSignal,
            myCountSignal,
            photoCountSignal,
            videoCountSignal,
            voiceCountSignal,
            roundVideoCountSignal,
            docCountSignal,
            firstMessageSignal
        )
        |> map { total, my, photos, videos, voices, roundVideos, docs, firstDate in
            let effectiveMy = my > 0 ? my : 0
            let effectivePeer = max(0, total - effectiveMy)
            return WgramCloudChatSummary(
                totalCount: total,
                myCount: effectiveMy,
                peerCount: effectivePeer,
                photoCount: photos,
                videoCount: videos,
                voiceCount: voices,
                roundVideoCount: roundVideos,
                documentCount: docs,
                firstMessageDate: firstDate
            )
        }
    }
}

public final class WgramStreakManager {
    public static let shared = WgramStreakManager()
    public static let streakUpdatedNotification = Notification.Name("WgramStreakUpdatedNotification")
    
    private let queue = Queue(name: "WgramStreakManagerQueue")
    private var inMemoryStreaks: [Int64: Int] = [:]
    private var isCalculating: Set<Int64> = []
    private var lastChecked: [Int64: Double] = [:]
    
    private init() {
        self.loadFromDisk()
    }
    
    private func loadFromDisk() {
        UserDefaults.standard.removeObject(forKey: "Wgram_Streaks_Cache")
        UserDefaults.standard.removeObject(forKey: "Wgram_Streaks_Cache_v2")
        if let dict = UserDefaults.standard.dictionary(forKey: "Wgram_Streaks_Cache_v3") as? [String: Int] {
            for (key, val) in dict {
                if let id = Int64(key) {
                    self.inMemoryStreaks[id] = val
                }
            }
        }
    }
    
    private func saveToDisk() {
        var dict: [String: Int] = [:]
        for (id, val) in self.inMemoryStreaks {
            dict["\(id)"] = val
        }
        UserDefaults.standard.set(dict, forKey: "Wgram_Streaks_Cache_v3")
    }
    
    public func getStreak(peerId: PeerId) -> Int {
        return self.inMemoryStreaks[peerId.toInt64()] ?? 0
    }
    
    public func setStreak(peerId: PeerId, streak: Int) {
        let key = peerId.toInt64()
        if self.inMemoryStreaks[key] != streak {
            self.inMemoryStreaks[key] = streak
            self.saveToDisk()
            Queue.mainQueue().async {
                NotificationCenter.default.post(name: WgramStreakManager.streakUpdatedNotification, object: peerId)
            }
        }
    }
    
    public static func computeStreak(timestamps: [Int32], calendar: Calendar = Calendar.current) -> (current: Int, longest: Int) {
        let details = self.computeStreakDetails(timestamps: timestamps, calendar: calendar)
        return (details.current, details.longest)
    }
    
    public static func computeStreakDetails(timestamps: [Int32], calendar: Calendar = Calendar.current) -> (current: Int, longest: Int, oldestStreakDay: Date?) {
        guard !timestamps.isEmpty else { return (0, 0, nil) }
        
        var uniqueDays = Set<Date>()
        for ts in timestamps {
            let date = Date(timeIntervalSince1970: TimeInterval(ts))
            uniqueDays.insert(calendar.startOfDay(for: date))
        }
        
        let sortedDays = uniqueDays.sorted(by: >)
        guard let latestDay = sortedDays.first else { return (0, 0, nil) }
        
        var currentStreak = 0
        var oldestStreakDay: Date? = nil
        
        if calendar.isDateInToday(latestDay) || calendar.isDateInYesterday(latestDay) {
            currentStreak = 1
            oldestStreakDay = latestDay
            var lastStreakDay = latestDay
            for day in sortedDays.dropFirst() {
                let diff = calendar.dateComponents([.day], from: day, to: lastStreakDay).day ?? 0
                if diff == 0 {
                    continue
                } else if diff == 1 {
                    currentStreak += 1
                    lastStreakDay = day
                    oldestStreakDay = day
                } else {
                    break
                }
            }
        }
        
        var longestStreak = 0
        var tempStreak = 0
        var prevDay: Date? = nil
        
        for day in sortedDays.reversed() {
            if let prev = prevDay {
                let diff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if diff == 1 {
                    tempStreak += 1
                } else if diff > 1 {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            prevDay = day
            if tempStreak > longestStreak {
                longestStreak = tempStreak
            }
        }
        
        return (currentStreak, longestStreak, oldestStreakDay)
    }
    
    public func checkAndCalculateIfNeeded(account: Account, peerId: PeerId) {
        let key = peerId.toInt64()
        let now = CFAbsoluteTimeGetCurrent()
        
        if self.isCalculating.contains(key) {
            return
        }
        if let last = self.lastChecked[key], (now - last) < 180.0, self.inMemoryStreaks[key] != nil {
            return
        }
        self.isCalculating.insert(key)
        self.lastChecked[key] = now
        
        let _ = (account.postbox.transaction { transaction -> (peer: Peer?, messages: [(id: Int32, timestamp: Int32)]) in
            let peer = transaction.getPeer(peerId)
            var list: [(id: Int32, timestamp: Int32)] = []
            var fromIndex = MessageIndex.upperBound(peerId: peerId, namespace: Namespaces.Message.Cloud)
            let toIndex = MessageIndex.lowerBound(peerId: peerId, namespace: Namespaces.Message.Cloud)
            
            while true {
                let batch = transaction.getMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, from: fromIndex, includeFrom: false, to: toIndex, limit: 1000)
                if batch.isEmpty {
                    break
                }
                for msg in batch {
                    list.append((id: msg.id.id, timestamp: msg.timestamp))
                }
                if let last = batch.last {
                    fromIndex = last.index
                }
                if batch.count < 1000 || list.count >= 2000 {
                    break
                }
            }
            return (peer, list)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] peer, localMessages in
            guard let strongSelf = self else { return }
            
            let calendar = Calendar.current
            let allTimestamps = localMessages.map { $0.timestamp }
            let streakDetails = WgramStreakManager.computeStreakDetails(timestamps: allTimestamps, calendar: calendar)
            
            let oldestLocalTs = localMessages.last?.timestamp
            let oldestLocalDay = oldestLocalTs.flatMap { calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval($0))) }
            
            let needCloudFetch: Bool
            if streakDetails.current > 0, let oldestStreak = streakDetails.oldestStreakDay, let oldestLocal = oldestLocalDay {
                needCloudFetch = oldestStreak <= oldestLocal
            } else if localMessages.isEmpty {
                needCloudFetch = true
            } else {
                needCloudFetch = false
            }
            
            if needCloudFetch, let peer = peer, let inputPeer = apiInputPeer(peer) {
                let oldestId = localMessages.last?.id ?? 0
                strongSelf.fetchCloudHistoryForStreak(
                    account: account,
                    inputPeer: inputPeer,
                    peerId: peerId,
                    offsetId: oldestId,
                    accumulatedTimestamps: allTimestamps,
                    batchesLeft: 15
                )
            } else {
                strongSelf.isCalculating.remove(key)
                strongSelf.setStreak(peerId: peerId, streak: streakDetails.current)
            }
        })
    }
    
    public func checkAndCalculateIfNeeded(postbox: Postbox, peerId: PeerId) {
        let key = peerId.toInt64()
        let now = CFAbsoluteTimeGetCurrent()
        if self.isCalculating.contains(key) {
            return
        }
        if let last = self.lastChecked[key], (now - last) < 180.0, self.inMemoryStreaks[key] != nil {
            return
        }
        self.isCalculating.insert(key)
        self.lastChecked[key] = now
        
        let _ = (postbox.transaction { transaction -> [Int32] in
            var allTimestamps: [Int32] = []
            var fromIndex = MessageIndex.upperBound(peerId: peerId, namespace: Namespaces.Message.Cloud)
            let toIndex = MessageIndex.lowerBound(peerId: peerId, namespace: Namespaces.Message.Cloud)
            
            while true {
                let batch = transaction.getMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, from: fromIndex, includeFrom: false, to: toIndex, limit: 1000)
                if batch.isEmpty {
                    break
                }
                allTimestamps.append(contentsOf: batch.map { $0.timestamp })
                if let last = batch.last {
                    fromIndex = last.index
                }
                if batch.count < 1000 || allTimestamps.count >= 2000 {
                    break
                }
            }
            return allTimestamps
        }
        |> deliverOn(self.queue)).start(next: { [weak self] timestamps in
            guard let strongSelf = self else { return }
            strongSelf.isCalculating.remove(key)
            let result = WgramStreakManager.computeStreak(timestamps: timestamps)
            strongSelf.setStreak(peerId: peerId, streak: result.current)
        })
    }
    
    private func fetchCloudHistoryForStreak(
        account: Account,
        inputPeer: Api.InputPeer,
        peerId: PeerId,
        offsetId: Int32,
        accumulatedTimestamps: [Int32],
        batchesLeft: Int
    ) {
        let key = peerId.toInt64()
        if batchesLeft <= 0 {
            self.isCalculating.remove(key)
            let (finalStreak, _) = WgramStreakManager.computeStreak(timestamps: accumulatedTimestamps)
            self.setStreak(peerId: peerId, streak: finalStreak)
            return
        }
        
        let request = account.network.request(Api.functions.messages.getHistory(
            peer: inputPeer,
            offsetId: offsetId,
            offsetDate: 0,
            addOffset: 0,
            limit: 100,
            maxId: Int32.max - 1,
            minId: 0,
            hash: 0
        ))
        
        let _ = (request
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            guard let strongSelf = self else { return }
            
            let apiMessages: [Api.Message]
            switch result {
            case let .channelMessages(data):
                apiMessages = data.messages
            case let .messages(data):
                apiMessages = data.messages
            case let .messagesSlice(data):
                apiMessages = data.messages
            case .messagesNotModified:
                apiMessages = []
            }
            
            if apiMessages.isEmpty {
                strongSelf.isCalculating.remove(key)
                let (finalStreak, _) = WgramStreakManager.computeStreak(timestamps: accumulatedTimestamps)
                strongSelf.setStreak(peerId: peerId, streak: finalStreak)
                return
            }
            
            var newTimestamps: [Int32] = []
            var nextOffsetId: Int32 = offsetId
            var oldestBatchTs: Int32 = Int32.max
            
            for msg in apiMessages {
                var msgId: Int32?
                var msgDate: Int32?
                switch msg {
                case let .message(data):
                    msgId = data.id
                    msgDate = data.date
                case let .messageService(data):
                    msgId = data.id
                    msgDate = data.date
                case .messageEmpty:
                    break
                }
                if let id = msgId, let date = msgDate {
                    newTimestamps.append(date)
                    nextOffsetId = id
                    if date < oldestBatchTs {
                        oldestBatchTs = date
                    }
                }
            }
            
            var updatedTimestamps = accumulatedTimestamps
            updatedTimestamps.append(contentsOf: newTimestamps)
            
            let calendar = Calendar.current
            let details = WgramStreakManager.computeStreakDetails(timestamps: updatedTimestamps, calendar: calendar)
            let oldestBatchDay = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(oldestBatchTs)))
            
            if let oldestStreak = details.oldestStreakDay, oldestStreak > oldestBatchDay {
                strongSelf.isCalculating.remove(key)
                strongSelf.setStreak(peerId: peerId, streak: details.current)
            } else {
                strongSelf.fetchCloudHistoryForStreak(
                    account: account,
                    inputPeer: inputPeer,
                    peerId: peerId,
                    offsetId: nextOffsetId,
                    accumulatedTimestamps: updatedTimestamps,
                    batchesLeft: batchesLeft - 1
                )
            }
        }, error: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.isCalculating.remove(key)
            let (finalStreak, _) = WgramStreakManager.computeStreak(timestamps: accumulatedTimestamps)
            strongSelf.setStreak(peerId: peerId, streak: finalStreak)
        })
    }
}
