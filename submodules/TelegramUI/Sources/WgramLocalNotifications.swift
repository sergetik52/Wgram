import Foundation
import UIKit
import UserNotifications
import TelegramCore
import Postbox
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences

public final class WgramLocalNotifications {
    public static func postNotification(
        context: AccountContext,
        messages: [EngineRawMessage],
        threadData: EngineMessageHistoryThreadData?,
        strings: PresentationStrings,
        nameDisplayOrder: PresentationPersonNameOrder
    ) {
        guard let firstMessage = messages.first else { return }
        
        // 1. Only if Keep-Alive / background reception is enabled
        guard WgramSettings.keepAliveInBackground else { return }
        
        // 2. Only incoming messages
        guard firstMessage.effectivelyIncoming(context.account.peerId) else { return }
        
        // 3. Ignore own messages / saved messages unless scheduled
        if firstMessage.id.peerId == context.account.peerId && !firstMessage.flags.contains(.WasScheduled) {
            return
        }
        
        // 4. Check if chat is muted
        let isMuted = firstMessage.attributes.contains(where: { attribute in
            if let attribute = attribute as? NotificationInfoMessageAttribute {
                return attribute.flags.contains(.muted)
            }
            return false
        })
        if isMuted {
            return
        }
        
        // 5. Build Title (Chat / Sender name)
        var title = "Wgram"
        if let peer = messageMainPeer(EngineMessage(firstMessage)) {
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                title = peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
            } else if let author = firstMessage.author {
                let authorString = author.id == context.account.peerId ? strings.DialogList_You : EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                if author.id != peer.id {
                    if let threadData = threadData {
                        title = "\(authorString) → \(threadData.info.title)"
                    } else {
                        title = "\(authorString) (\(peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)))"
                    }
                } else {
                    title = peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                }
            } else {
                title = peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
            }
        }
        
        // 6. Build Body preview
        var body = firstMessage.text
        if body.isEmpty {
            for media in firstMessage.media {
                if media is TelegramMediaImage {
                    body = "📷 Фото"
                    break
                } else if let file = media as? TelegramMediaFile {
                    if file.isVoice {
                        body = "🎤 Голосовое сообщение"
                    } else if file.isInstantVideo {
                        body = "📹 Видеосообщение"
                    } else if file.isVideo {
                        body = "📹 Видео"
                    } else if file.isAnimatedSticker || file.isSticker {
                        body = "🎨 Стикер"
                    } else {
                        body = "📎 Файл"
                    }
                    break
                } else if media is TelegramMediaContact {
                    body = "👤 Контакт"
                    break
                } else if media is TelegramMediaMap {
                    body = "📍 Геолокация"
                    break
                } else if media is TelegramMediaPoll {
                    body = "📊 Опрос"
                    break
                }
            }
        }
        if body.isEmpty {
            body = "Новое сообщение"
        }
        
        // 7. Dispatch Local Notification via UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "c"
        
        var userInfo: [String: Any] = [
            "peerId": firstMessage.id.peerId.toInt64(),
            "messageId.namespace": firstMessage.id.namespace,
            "messageId.id": firstMessage.id.id,
            "userId": Int(context.account.peerId.id._internalGetInt64Value())
        ]
        if let threadId = firstMessage.threadId {
            userInfo["threadId"] = threadId
        }
        content.userInfo = userInfo
        
        let identifier = "wgram_msg_\(firstMessage.id.peerId.toInt64())_\(firstMessage.id.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
