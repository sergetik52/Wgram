import Foundation
import Postbox
import SwiftSignalKit

public func wgramMessageSummary(text: String, media: [Media]) -> String {
    if !text.isEmpty {
        return text
    }
    for item in media {
        if item is TelegramMediaImage {
            return "[Фото]"
        } else if let file = item as? TelegramMediaFile {
            if file.isVoice {
                return "[Голосовое сообщение]"
            } else if file.isInstantVideo {
                return "[Видеосообщение]"
            } else if file.isVideo {
                return "[Видео]"
            } else if file.isSticker {
                return "[Стикер]"
            } else if file.isAnimatedSticker {
                return "[Анимированный стикер]"
            } else {
                let name = file.fileName ?? "файл"
                return "[Файл: \(name)]"
            }
        } else if item is TelegramMediaContact {
            return "[Контакт]"
        } else if item is TelegramMediaMap {
            return "[Геолокация]"
        } else if item is TelegramMediaPoll {
            return "[Опрос]"
        }
    }
    return "[Пустое сообщение]"
}

public enum WgramChatType {
    case direct
    case group
    case channel
    case unknown
}

public func wgramChatType(for peer: Peer?) -> WgramChatType {
    guard let peer = peer else { return .unknown }
    if peer is TelegramUser {
        return .direct
    } else if peer is TelegramGroup {
        return .group
    } else if let channel = peer as? TelegramChannel {
        if case .group = channel.info {
            return .group
        } else {
            return .channel
        }
    }
    return .unknown
}

public final class WgramEventLogger {
    public static let shared = WgramEventLogger()
    
    public weak var account: Account?
    
    private var recentlyLoggedDeletions = Set<MessageId>()
    private var recentlyLoggedEdits = [MessageId: String]()
    private let lock = NSLock()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    private init() {}
    
    public func logEdited(
        messageId: MessageId,
        sourceChatPeer: Peer?,
        authorTitle: String,
        authorUsername: String?,
        authorId: Int64,
        oldText: String,
        newText: String,
        timestamp: Int32? = nil
    ) {
        guard WgramSettings.logEditsAndDeletesToChatEnabled && WgramSettings.logEditedMessages else { return }
        
        let chatType = wgramChatType(for: sourceChatPeer)
        switch chatType {
        case .direct:
            if !WgramSettings.logPrivateChats { return }
        case .group:
            if !WgramSettings.logGroups { return }
        case .channel:
            if !WgramSettings.logChannels { return }
        case .unknown:
            break
        }
        
        self.lock.lock()
        if let logged = self.recentlyLoggedEdits[messageId], logged == newText {
            self.lock.unlock()
            return
        }
        self.recentlyLoggedEdits[messageId] = newText
        if self.recentlyLoggedEdits.count > 500 {
            self.recentlyLoggedEdits.removeAll()
        }
        self.lock.unlock()
        
        Queue.mainQueue().async { [weak self] in
            guard let strongSelf = self, let account = strongSelf.account else { return }
            
            let userTag = (authorUsername != nil && !authorUsername!.isEmpty) ? " (@\(authorUsername!))" : ""
            var header = "✏️ [ИЗМЕНЕНИЕ СООБЩЕНИЯ]\n"
            header += "👤 Автор: \(authorTitle)\(userTag) [ID: \(authorId)]\n"
            if WgramSettings.logIncludeChatInfo, let chatPeer = sourceChatPeer, chatType != .direct {
                let chatTypeLabel = chatType == .channel ? "Канал" : "Группа"
                let chatTitle = chatPeer.debugDisplayTitle
                let chatId = chatPeer.id.id._internalGetInt64Value()
                header += "📍 \(chatTypeLabel): \(chatTitle) [ID: \(chatId)]\n"
            }
            let timeString: String
            if let timestamp = timestamp {
                timeString = strongSelf.timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
            } else {
                timeString = strongSelf.timeFormatter.string(from: Date())
            }
            header += "⏰ Время: \(timeString)\n"
            let separator = "\n↓ ↓ ↓ (Новая версия) ↓ ↓ ↓\n"
            let fullText = "\(header)\(oldText)\(separator)\(newText)"
            
            let headerUtf16 = header.utf16.count
            let oldUtf16 = oldText.utf16.count
            let sepUtf16 = separator.utf16.count
            let newUtf16 = newText.utf16.count
            
            let oldRange = headerUtf16 ..< (headerUtf16 + oldUtf16)
            let newRange = (headerUtf16 + oldUtf16 + sepUtf16) ..< (headerUtf16 + oldUtf16 + sepUtf16 + newUtf16)
            
            let entities: [MessageTextEntity] = [
                MessageTextEntity(range: oldRange, type: .BlockQuote(isCollapsed: false)),
                MessageTextEntity(range: newRange, type: .BlockQuote(isCollapsed: false))
            ]
            
            strongSelf.deliverEvent(account: account, sourcePeerId: messageId.peerId, fullText: fullText, entities: entities)
        }
    }
    
    public func logDeleted(
        messageId: MessageId,
        sourceChatPeer: Peer?,
        authorTitle: String,
        authorUsername: String?,
        authorId: Int64,
        text: String,
        timestamp: Int32? = nil
    ) {
        guard WgramSettings.logEditsAndDeletesToChatEnabled && WgramSettings.logDeletedMessages else { return }
        
        let chatType = wgramChatType(for: sourceChatPeer)
        switch chatType {
        case .direct:
            if !WgramSettings.logPrivateChats { return }
        case .group:
            if !WgramSettings.logGroups { return }
        case .channel:
            if !WgramSettings.logChannels { return }
        case .unknown:
            break
        }
        
        self.lock.lock()
        if self.recentlyLoggedDeletions.contains(messageId) {
            self.lock.unlock()
            return
        }
        self.recentlyLoggedDeletions.insert(messageId)
        if self.recentlyLoggedDeletions.count > 500 {
            self.recentlyLoggedDeletions.removeAll()
        }
        self.lock.unlock()
        
        Queue.mainQueue().async { [weak self] in
            guard let strongSelf = self, let account = strongSelf.account else { return }
            
            let userTag = (authorUsername != nil && !authorUsername!.isEmpty) ? " (@\(authorUsername!))" : ""
            var header = "🗑️ [УДАЛЕНИЕ СООБЩЕНИЯ]\n"
            header += "👤 Автор: \(authorTitle)\(userTag) [ID: \(authorId)]\n"
            if WgramSettings.logIncludeChatInfo, let chatPeer = sourceChatPeer, chatType != .direct {
                let chatTypeLabel = chatType == .channel ? "Канал" : "Группа"
                let chatTitle = chatPeer.debugDisplayTitle
                let chatId = chatPeer.id.id._internalGetInt64Value()
                header += "📍 \(chatTypeLabel): \(chatTitle) [ID: \(chatId)]\n"
            }
            let timeString: String
            if let timestamp = timestamp {
                timeString = strongSelf.timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
            } else {
                timeString = strongSelf.timeFormatter.string(from: Date())
            }
            header += "⏰ Время: \(timeString)\n"
            let fullText = "\(header)\(text)"
            
            let headerUtf16 = header.utf16.count
            let textUtf16 = text.utf16.count
            let textRange = headerUtf16 ..< (headerUtf16 + textUtf16)
            
            let entities: [MessageTextEntity] = [
                MessageTextEntity(range: textRange, type: .BlockQuote(isCollapsed: false))
            ]
            
            strongSelf.deliverEvent(account: account, sourcePeerId: messageId.peerId, fullText: fullText, entities: entities)
        }
    }
    
    private func deliverEvent(account: Account, sourcePeerId: PeerId, fullText: String, entities: [MessageTextEntity]) {
        let targetPeerIdNum = WgramSettings.logChatTargetPeerId
        if targetPeerIdNum != 0 {
            let targetPeerId = PeerId(targetPeerIdNum)
            if targetPeerId == sourcePeerId {
                return
            }
            self.sendMessage(account: account, targetPeerId: targetPeerId, fullText: fullText, entities: entities)
            return
        }
        
        let targetUsername = WgramSettings.logChatTargetUsername.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        if !targetUsername.isEmpty {
            let _ = (_internal_resolvePeerByName(account: account, name: targetUsername, referrer: nil)
            |> deliverOn(Queue.mainQueue())).start(next: { [weak self] result in
                guard let strongSelf = self else { return }
                if case let .result(peerId) = result, let peerId = peerId {
                    WgramSettings.logChatTargetPeerId = peerId.toInt64()
                    if peerId != sourcePeerId {
                        strongSelf.sendMessage(account: account, targetPeerId: peerId, fullText: fullText, entities: entities)
                    }
                } else {
                    if account.peerId != sourcePeerId {
                        strongSelf.sendMessage(account: account, targetPeerId: account.peerId, fullText: fullText, entities: entities)
                    }
                }
            })
            return
        }
        
        // Default: Saved Messages
        if account.peerId != sourcePeerId {
            self.sendMessage(account: account, targetPeerId: account.peerId, fullText: fullText, entities: entities)
        }
    }
    
    private func sendMessage(account: Account, targetPeerId: PeerId, fullText: String, entities: [MessageTextEntity]) {
        var attributes: [MessageAttribute] = [TextEntitiesMessageAttribute(entities: entities)]
        
        // Stealth Ghost Mode guarantee:
        // Always attach OutgoingScheduleInfoMessageAttribute if ghost mode or dontUpdateOnline is enabled.
        // Scheduled messages are executed without triggering online presence!
        if WgramSettings.ghostModeEnabled || WgramSettings.dontUpdateOnline {
            let scheduleTime = Int32(Date().timeIntervalSince1970) + 1
            attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime, repeatPeriod: nil))
        }
        
        let message = EnqueueMessage.message(
            text: fullText,
            attributes: attributes,
            inlineStickers: [:],
            mediaReference: nil,
            threadId: nil,
            replyToMessageId: nil,
            replyToStoryId: nil,
            localGroupingKey: nil,
            correlationId: nil,
            bubbleUpEmojiOrStickersets: []
        )
        let _ = enqueueMessages(account: account, peerId: targetPeerId, messages: [message]).startStandalone()
    }
}
