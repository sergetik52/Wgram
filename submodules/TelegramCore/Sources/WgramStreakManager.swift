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
        if let dict = UserDefaults.standard.dictionary(forKey: "Wgram_Streaks_Cache") as? [String: Int] {
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
        UserDefaults.standard.set(dict, forKey: "Wgram_Streaks_Cache")
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
        
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return (0, 0) }
        
        var currentStreak = 0
        if latestDay == today || latestDay == yesterday {
            currentStreak = 1
            if var expectedPrev = calendar.date(byAdding: .day, value: -1, to: latestDay) {
                for day in sortedDays.dropFirst() {
                    if day == expectedPrev {
                        currentStreak += 1
                        if let nextExpected = calendar.date(byAdding: .day, value: -1, to: expectedPrev) {
                            expectedPrev = nextExpected
                        } else {
                            break
                        }
                    } else if day > expectedPrev {
                        continue
                    } else {
                        break
                    }
                }
            }
        }
        
        var longestStreak = 0
        var tempStreak = 0
        var expectedNext: Date? = nil
        
        for day in sortedDays.reversed() {
            if let expected = expectedNext {
                if day == expected {
                    tempStreak += 1
                } else if day > expected {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            if tempStreak > longestStreak {
                longestStreak = tempStreak
            }
            expectedNext = calendar.date(byAdding: .day, value: 1, to: day)
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
            let fromIndex = MessageIndex.upperBound(peerId: peerId, namespace: Namespaces.Message.Cloud)
            let toIndex = MessageIndex.lowerBound(peerId: peerId, namespace: Namespaces.Message.Cloud)
            let messages = transaction.getMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, from: fromIndex, includeFrom: true, to: toIndex, limit: 200)
            return messages.map { $0.timestamp }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] timestamps in
            guard let strongSelf = self else { return }
            strongSelf.isCalculating.remove(key)
            let result = WgramStreakManager.computeStreak(timestamps: timestamps)
            strongSelf.setStreak(peerId: peerId, streak: result.current)
        })
    }
}
