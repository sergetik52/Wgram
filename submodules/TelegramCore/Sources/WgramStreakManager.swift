import Foundation
import Postbox
import SwiftSignalKit

public final class WgramStreakManager {
    public static let shared = WgramStreakManager()
    public static let streakUpdatedNotification = Notification.Name("WgramStreakUpdatedNotification")
    
    private let queue = Queue(name: "WgramStreakManagerQueue")
    private var inMemoryStreaks: [Int64: Int] = [:]
    private var isCalculating: Set<Int64> = []
    
    private init() {
        self.loadFromDisk()
    }
    
    private func loadFromDisk() {
        UserDefaults.standard.removeObject(forKey: "Wgram_Streaks_Cache")
        if let dict = UserDefaults.standard.dictionary(forKey: "Wgram_Streaks_Cache_v2") as? [String: Int] {
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
        UserDefaults.standard.set(dict, forKey: "Wgram_Streaks_Cache_v2")
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
        guard !timestamps.isEmpty else { return (0, 0) }
        
        var uniqueDays = Set<Date>()
        for ts in timestamps {
            let date = Date(timeIntervalSince1970: TimeInterval(ts))
            uniqueDays.insert(calendar.startOfDay(for: date))
        }
        
        let sortedDays = uniqueDays.sorted(by: >)
        guard let latestDay = sortedDays.first else { return (0, 0) }
        
        var currentStreak = 0
        if calendar.isDateInToday(latestDay) || calendar.isDateInYesterday(latestDay) {
            currentStreak = 1
            var lastStreakDay = latestDay
            for day in sortedDays.dropFirst() {
                let diff = calendar.dateComponents([.day], from: day, to: lastStreakDay).day ?? 0
                if diff == 0 {
                    continue
                } else if diff == 1 {
                    currentStreak += 1
                    lastStreakDay = day
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
        
        return (currentStreak, longestStreak)
    }
    
    public func checkAndCalculateIfNeeded(postbox: Postbox, peerId: PeerId) {
        let key = peerId.toInt64()
        if self.inMemoryStreaks[key] != nil || self.isCalculating.contains(key) {
            return
        }
        self.isCalculating.insert(key)
        
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
                if batch.count < 1000 || allTimestamps.count >= 5000 {
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
}
