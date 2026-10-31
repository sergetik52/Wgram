import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public final class WgramChatStatsData {
    public enum Period: Int, CaseIterable {
        case days7 = 0
        case days30 = 1
        case year1 = 2
        case allTime = 3
        
        public var title: String {
            switch self {
            case .days7: return "7 дней"
            case .days30: return "30 дней"
            case .year1: return "1 год"
            case .allTime: return "Всё время"
            }
        }
    }
    
    public var peerId: PeerId
    public var accountPeerId: PeerId
    public var period: Period = .allTime
    
    // Block 1: Overview
    public var firstMessageDate: Date?
    public var totalMessages: Int = 0
    public var myMessagesCount: Int = 0
    public var peerMessagesCount: Int = 0
    public var currentStreakDays: Int = 0
    public var longestStreakDays: Int = 0
    public var longestSilenceDays: Int = 0
    public var longestSilenceStartDate: Date?
    public var longestSilenceEndDate: Date?
    
    // Block 2: Heatmap
    public var dailyCounts: [String: Int] = [:] // "YYYY-MM-DD" -> count
    public var maxDailyCount: Int = 0
    
    // Block 3: Time of Day
    public var hourlyCounts: [Int: Int] = [:] // 0..23 -> count
    public var peakWindowStart: Int = 20
    public var peakWindowEnd: Int = 23
    
    // Block 4: Days of Week
    public var weekdayCounts: [Int: Int] = [:] // 0(Mon)..6(Sun) -> count
    public var topWeekday: Int = 4
    
    // Block 5: Message Types
    public var textCount: Int = 0
    public var voiceCount: Int = 0
    public var videoNoteCount: Int = 0
    public var photoCount: Int = 0
    public var videoCount: Int = 0
    public var stickerCount: Int = 0
    public var fileCount: Int = 0
    public var locationCount: Int = 0
    public var otherCount: Int = 0
    
    // Block 6: Reactions
    public var topReactions: [(emoji: String, total: Int, myCount: Int, peerCount: Int)] = []
    public var totalReactions: Int = 0
    public var myTopReaction: String?
    public var myTopReactionCount: Int = 0
    public var peerTopReaction: String?
    public var peerTopReactionCount: Int = 0
    
    // Block 7: Words & Linguistics
    public var totalWords: Int = 0
    public var myTopWord: String?
    public var myTopWordCount: Int = 0
    public var peerTopWord: String?
    public var peerTopWordCount: Int = 0
    public var myAvgWordsPerMessage: Double = 0
    public var peerAvgWordsPerMessage: Double = 0
    public var topWordsCloud: [(word: String, count: Int)] = []
    
    // Block 8: Response Speed
    public var myAvgResponseTimeSeconds: Double = 0
    public var peerAvgResponseTimeSeconds: Double = 0
    public var fastestResponseSeconds: Double = 0
    public var longestResponseSeconds: Double = 0
    
    // Block 9: Hall of Records
    public var longestDayDate: Date?
    public var longestDayCount: Int = 0
    public var longestMessageLength: Int = 0
    public var longestMessageDate: Date?
    public var fastest100MessagesSeconds: Double = 0
    public var longestVoiceSeconds: Double = 0
    public var longestVoiceDate: Date?
    
    // Block 10: Relationship Timeline
    public var monthlyCounts: [(monthKey: String, count: Int)] = [] // "YYYY-MM" -> count
    
    // Block 11: On this day
    public var onThisDayItems: [(yearsAgo: Int, quote: String, isOutgoing: Bool, date: Date)] = []
    
    public init(peerId: PeerId, accountPeerId: PeerId, period: Period = .allTime) {
        self.peerId = peerId
        self.accountPeerId = accountPeerId
        self.period = period
    }
}

public final class WgramChatStatsEngine {
    public static let shared = WgramChatStatsEngine()
    
    private let queue = Queue(name: "WgramChatStatsEngineQueue", qos: .userInitiated)
    private var inMemoryCache: [Int64: [WgramChatStatsData.Period: WgramChatStatsData]] = [:]
    
    private static let stopWords: Set<String> = [
        "и", "в", "не", "на", "я", "что", "с", "а", "как", "это", "по", "но", "к", "у", "ты", "из", "за", "от", "о", "же", "бы", "то", "всё", "все", "так", "мы", "он", "она", "они", "мне", "меня", "тебе", "тебя", "ему", "ей", "его", "ее", "её", "их", "да", "нет", "ну", "во", "до", "ли", "если", "уже", "еще", "ещё", "тут", "там", "где", "куда", "когда", "кто", "чем", "для", "или", "было", "был", "была", "были", "будет", "будут", "тоже", "также", "даже", "только", "вот", "просто", "через", "при", "без", "под", "над", "после", "перед", "the", "be", "to", "of", "and", "a", "in", "that", "have", "i", "it", "for", "not", "on", "with", "he", "as", "you", "do", "at", "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all", "would", "there", "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "me", "https", "http", "com", "ru"
    ]
    
    public func getCached(peerId: PeerId, period: WgramChatStatsData.Period) -> WgramChatStatsData? {
        return self.inMemoryCache[peerId.toInt64()]?[period]
    }
    
    public func scanChat(postbox: Postbox, peerId: PeerId, accountPeerId: PeerId, period: WgramChatStatsData.Period, progress: @escaping (Int, Bool, WgramChatStatsData?) -> Void) {
        if let cached = self.getCached(peerId: peerId, period: period) {
            progress(cached.totalMessages, true, cached)
            return
        }
        
        self.queue.async {
            var rawMessages: [Message] = []
            var fromIndex = MessageIndex.absoluteUpperBound()
            let limit = 1000
            var hasMore = true
            
            while hasMore {
                var currentBatch: [Message] = []
                let _ = postbox.transaction { transaction in
                    currentBatch = transaction.getMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, from: fromIndex, includeFrom: false, to: MessageIndex.absoluteLowerBound(), limit: limit)
                }.start(next: { _ in })
                
                if currentBatch.isEmpty {
                    break
                }
                
                rawMessages.append(contentsOf: currentBatch)
                if let last = currentBatch.last {
                    fromIndex = last.index
                }
                
                Queue.mainQueue().async {
                    progress(rawMessages.count, false, nil)
                }
                
                if currentBatch.count < limit {
                    hasMore = false
                }
            }
            
            // Sort chronologically (oldest to newest)
            rawMessages.sort(by: { $0.timestamp < $1.timestamp })
            
            // Update Streak Manager with full timestamps
            let allTimestamps = rawMessages.map { $0.timestamp }
            let streakResult = WgramStreakManager.computeStreak(timestamps: allTimestamps)
            WgramStreakManager.shared.setStreak(peerId: peerId, streak: streakResult.current)
            
            // Compute stats for all periods and cache them
            let statsMap = self.processAllPeriods(rawMessages: rawMessages, peerId: peerId, accountPeerId: accountPeerId, streakResult: streakResult)
            
            self.inMemoryCache[peerId.toInt64()] = statsMap
            
            let resultData = statsMap[period] ?? statsMap[.allTime]!
            Queue.mainQueue().async {
                progress(resultData.totalMessages, true, resultData)
            }
        }
    }
    
    private func processAllPeriods(rawMessages: [Message], peerId: PeerId, accountPeerId: PeerId, streakResult: (current: Int, longest: Int)) -> [WgramChatStatsData.Period: WgramChatStatsData] {
        var map: [WgramChatStatsData.Period: WgramChatStatsData] = [:]
        let now = Int32(Date().timeIntervalSince1970)
        
        for period in WgramChatStatsData.Period.allCases {
            let filteredMessages: [Message]
            switch period {
            case .days7:
                let threshold = now - 7 * 86400
                filteredMessages = rawMessages.filter { $0.timestamp >= threshold }
            case .days30:
                let threshold = now - 30 * 86400
                filteredMessages = rawMessages.filter { $0.timestamp >= threshold }
            case .year1:
                let threshold = now - 365 * 86400
                filteredMessages = rawMessages.filter { $0.timestamp >= threshold }
            case .allTime:
                filteredMessages = rawMessages
            }
            
            let data = self.calculateStats(messages: filteredMessages, peerId: peerId, accountPeerId: accountPeerId, period: period, streakResult: streakResult)
            map[period] = data
        }
        
        return map
    }
    
    private func calculateStats(messages: [Message], peerId: PeerId, accountPeerId: PeerId, period: WgramChatStatsData.Period, streakResult: (current: Int, longest: Int)) -> WgramChatStatsData {
        let data = WgramChatStatsData(peerId: peerId, accountPeerId: accountPeerId, period: period)
        guard !messages.isEmpty else { return data }
        
        let calendar = Calendar.current
        data.firstMessageDate = Date(timeIntervalSince1970: TimeInterval(messages[0].timestamp))
        data.totalMessages = messages.count
        data.currentStreakDays = streakResult.current
        data.longestStreakDays = streakResult.longest
        
        var myWords: [String: Int] = [:]
        var peerWords: [String: Int] = [:]
        var allWords: [String: Int] = [:]
        var myTotalWords = 0
        var peerTotalWords = 0
        var myMessageCount = 0
        var peerMessageCount = 0
        
        var myReactionCounts: [String: Int] = [:]
        var peerReactionCounts: [String: Int] = [:]
        var allReactionCounts: [String: Int] = [:]
        
        var dailyMap: [String: Int] = [:]
        var monthlyMap: [String: Int] = [:]
        var hourlyMap: [Int: Int] = [:]
        var weekdayMap: [Int: Int] = [:]
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        
        var lastAuthorIsMe: Bool? = nil
        var lastMessageTimestamp: Int32 = 0
        var myResponseDelays: [Double] = []
        var peerResponseDelays: [Double] = []
        
        var longestSilenceGap: Double = 0
        var longestSilenceStart: Date? = nil
        var longestSilenceEnd: Date? = nil
        
        let todayComponents = calendar.dateComponents([.month, .day, .year], from: Date())
        let todayMonth = todayComponents.month ?? 0
        let todayDay = todayComponents.day ?? 0
        let todayYear = todayComponents.year ?? 0
        
        for i in 0 ..< messages.count {
            let msg = messages[i]
            let isOutgoing = msg.flags.contains(.Incoming) == false || msg.author?.id == accountPeerId
            let date = Date(timeIntervalSince1970: TimeInterval(msg.timestamp))
            
            // 1. Author breakdown
            if isOutgoing {
                myMessageCount += 1
            } else {
                peerMessageCount += 1
            }
            
            // 2. Response Delays
            if let lastIsMe = lastAuthorIsMe {
                let delay = Double(msg.timestamp - lastMessageTimestamp)
                if delay > longestSilenceGap && delay >= 86400.0 {
                    longestSilenceGap = delay
                    longestSilenceStart = Date(timeIntervalSince1970: TimeInterval(lastMessageTimestamp))
                    longestSilenceEnd = date
                }
                
                // Track conversation replies (ignoring > 7 days breaks)
                if delay > 0 && delay < 86400.0 * 7.0 {
                    if lastIsMe != isOutgoing {
                        if isOutgoing {
                            myResponseDelays.append(delay)
                        } else {
                            peerResponseDelays.append(delay)
                        }
                    }
                }
            }
            lastAuthorIsMe = isOutgoing
            lastMessageTimestamp = msg.timestamp
            
            // 3. Time, Day & Month mapping
            let dayKey = dayFormatter.string(from: date)
            dailyMap[dayKey, default: 0] += 1
            
            let monthKey = monthFormatter.string(from: date)
            monthlyMap[monthKey, default: 0] += 1
            
            let hour = calendar.component(.hour, from: date)
            hourlyMap[hour, default: 0] += 1
            
            // 0 = Monday, 6 = Sunday
            let weekday = (calendar.component(.weekday, from: date) + 5) % 7
            weekdayMap[weekday, default: 0] += 1
            
            // 4. Message Types
            var classified = false
            for media in msg.media {
                if let file = media as? TelegramMediaFile {
                    if file.isInstantVideo {
                        data.videoNoteCount += 1
                        classified = true
                    } else if file.isVoice {
                        data.voiceCount += 1
                        let duration = file.duration.flatMap { Double($0) } ?? 0
                        if duration > data.longestVoiceSeconds {
                            data.longestVoiceSeconds = duration
                            data.longestVoiceDate = date
                        }
                        classified = true
                    } else if file.isSticker {
                        data.stickerCount += 1
                        classified = true
                    } else if file.isVideo {
                        data.videoCount += 1
                        classified = true
                    } else {
                        data.fileCount += 1
                        classified = true
                    }
                } else if media is TelegramMediaImage {
                    data.photoCount += 1
                    classified = true
                } else if media is TelegramMediaMap {
                    data.locationCount += 1
                    classified = true
                }
            }
            
            if !classified {
                if !msg.text.isEmpty {
                    data.textCount += 1
                } else {
                    data.otherCount += 1
                }
            }
            
            // 5. Longest text message
            let textLen = msg.text.count
            if textLen > data.longestMessageLength {
                data.longestMessageLength = textLen
                data.longestMessageDate = date
            }
            
            // 6. Word Analysis
            if !msg.text.isEmpty {
                let words = msg.text.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 2 }
                
                for w in words {
                    if isOutgoing {
                        myTotalWords += 1
                    } else {
                        peerTotalWords += 1
                    }
                    
                    if !WgramChatStatsEngine.stopWords.contains(w) && w.count >= 3 {
                        allWords[w, default: 0] += 1
                        if isOutgoing {
                            myWords[w, default: 0] += 1
                        } else {
                            peerWords[w, default: 0] += 1
                        }
                    }
                }
            }
            
            // 7. Reactions Analysis
            for attr in msg.attributes {
                if let reactionsAttr = attr as? ReactionsMessageAttribute {
                    for reaction in reactionsAttr.reactions {
                        let emojiStr: String
                        switch reaction.value {
                        case let .builtin(str):
                            emojiStr = str
                        case .custom:
                            emojiStr = "⭐️"
                        case .stars:
                            emojiStr = "⭐️"
                        }
                        
                        let count = Int(reaction.count)
                        allReactionCounts[emojiStr, default: 0] += count
                        if reaction.chosenOrder != nil {
                            myReactionCounts[emojiStr, default: 0] += 1
                        } else {
                            peerReactionCounts[emojiStr, default: 0] += 1
                        }
                    }
                }
            }
            
            // 8. On This Day (Flashbacks)
            let msgComponents = calendar.dateComponents([.month, .day, .year], from: date)
            if msgComponents.month == todayMonth && msgComponents.day == todayDay, let msgYear = msgComponents.year, msgYear < todayYear {
                let diff = todayYear - msgYear
                if !msg.text.isEmpty && data.onThisDayItems.filter({ $0.yearsAgo == diff }).count < 2 {
                    data.onThisDayItems.append((yearsAgo: diff, quote: msg.text, isOutgoing: isOutgoing, date: date))
                }
            }
        }
        
        data.myMessagesCount = myMessageCount
        data.peerMessagesCount = peerMessageCount
        data.longestSilenceDays = Int(longestSilenceGap / 86400.0)
        data.longestSilenceStartDate = longestSilenceStart
        data.longestSilenceEndDate = longestSilenceEnd
        
        // Heatmap & Peak Day
        data.dailyCounts = dailyMap
        var maxD = 0
        var topDayStr: String? = nil
        for (dayStr, c) in dailyMap {
            if c > maxD {
                maxD = c
                topDayStr = dayStr
            }
        }
        data.maxDailyCount = maxD
        data.longestDayCount = maxD
        if let topDayStr = topDayStr {
            data.longestDayDate = dayFormatter.date(from: topDayStr)
        }
        
        // Hourly & Peak Window
        data.hourlyCounts = hourlyMap
        var bestWindowStart = 20
        var bestWindowSum = 0
        for h in 0 ..< 24 {
            let sum = (hourlyMap[h] ?? 0) + (hourlyMap[(h + 1) % 24] ?? 0) + (hourlyMap[(h + 2) % 24] ?? 0)
            if sum > bestWindowSum {
                bestWindowSum = sum
                bestWindowStart = h
            }
        }
        data.peakWindowStart = bestWindowStart
        data.peakWindowEnd = (bestWindowStart + 2) % 24
        
        // Weekdays & Top Day
        data.weekdayCounts = weekdayMap
        var topW = 0
        var topWCount = 0
        for (w, c) in weekdayMap {
            if c > topWCount {
                topWCount = c
                topW = w
            }
        }
        data.topWeekday = topW
        
        // Monthly Timeline (sorted keys)
        let sortedMonths = monthlyMap.keys.sorted()
        data.monthlyCounts = sortedMonths.map { (monthKey: $0, count: monthlyMap[$0] ?? 0) }
        
        // Word Linguistics
        data.totalWords = myTotalWords + peerTotalWords
        if myMessageCount > 0 {
            data.myAvgWordsPerMessage = (Double(myTotalWords) / Double(myMessageCount) * 10).rounded() / 10
        }
        if peerMessageCount > 0 {
            data.peerAvgWordsPerMessage = (Double(peerTotalWords) / Double(peerMessageCount) * 10).rounded() / 10
        }
        
        let sortedMyWords = myWords.sorted(by: { $0.value > $1.value })
        if let top = sortedMyWords.first {
            data.myTopWord = top.key
            data.myTopWordCount = top.value
        }
        let sortedPeerWords = peerWords.sorted(by: { $0.value > $1.value })
        if let top = sortedPeerWords.first {
            data.peerTopWord = top.key
            data.peerTopWordCount = top.value
        }
        data.topWordsCloud = allWords.sorted(by: { $0.value > $1.value }).prefix(40).map { (word: $0.key, count: $0.value) }
        
        // Reactions
        data.totalReactions = allReactionCounts.values.reduce(0, +)
        let sortedReactions = allReactionCounts.sorted(by: { $0.value > $1.value })
        data.topReactions = sortedReactions.prefix(6).map { item in
            let emoji = item.key
            return (emoji: emoji, total: item.value, myCount: myReactionCounts[emoji] ?? 0, peerCount: peerReactionCounts[emoji] ?? 0)
        }
        if let myTop = myReactionCounts.max(by: { $0.value < $1.value }) {
            data.myTopReaction = myTop.key
            data.myTopReactionCount = myTop.value
        }
        if let peerTop = peerReactionCounts.max(by: { $0.value < $1.value }) {
            data.peerTopReaction = peerTop.key
            data.peerTopReactionCount = peerTop.value
        }
        
        // Response Delays
        if !myResponseDelays.isEmpty {
            data.myAvgResponseTimeSeconds = myResponseDelays.reduce(0, +) / Double(myResponseDelays.count)
        }
        if !peerResponseDelays.isEmpty {
            data.peerAvgResponseTimeSeconds = peerResponseDelays.reduce(0, +) / Double(peerResponseDelays.count)
        }
        let allDelays = myResponseDelays + peerResponseDelays
        if let minD = allDelays.filter({ $0 >= 1.0 }).min() {
            data.fastestResponseSeconds = minD
        }
        data.longestResponseSeconds = longestSilenceGap
        
        // Fastest 100 messages sprint
        if messages.count >= 100 {
            var min100 = Double.greatestFiniteMagnitude
            for i in 0 ..< (messages.count - 100) {
                let diff = Double(messages[i + 99].timestamp - messages[i].timestamp)
                if diff > 0 && diff < min100 {
                    min100 = diff
                }
            }
            if min100 < Double.greatestFiniteMagnitude {
                data.fastest100MessagesSeconds = min100
            }
        }
        
        return data
    }
}
