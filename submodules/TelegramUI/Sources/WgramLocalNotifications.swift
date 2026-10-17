import Foundation
import UIKit
import UserNotifications
import Intents
import TelegramCore
import Postbox
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import Display
import AvatarNode

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
        
        // 5. Determine Sender and Group
        let mainPeer = messageMainPeer(EngineMessage(firstMessage))
        let authorPeer = firstMessage.author.flatMap { EnginePeer($0) }
        
        var senderPeer: EnginePeer?
        var groupTitle: String?
        var isGroup = false
        
        if let main = mainPeer {
            if let author = authorPeer, author.id != main.id {
                // Message in group/supergroup from an author
                senderPeer = author
                isGroup = true
                if let threadData = threadData {
                    groupTitle = "\(threadData.info.title) (\(main.displayTitle(strings: strings, displayOrder: nameDisplayOrder)))"
                } else {
                    groupTitle = main.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                }
            } else {
                // 1-on-1 chat or channel broadcast
                senderPeer = main
                isGroup = false
            }
        } else {
            senderPeer = authorPeer
        }
        
        guard let effectiveSenderPeer = senderPeer else { return }
        let senderName = effectiveSenderPeer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
        
        // Fallback title for non-intent notifications
        var title = senderName
        if isGroup, let group = groupTitle {
            title = "\(senderName) (\(group))"
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
        
        // 7. Base notification content
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
        
        var finalContent: UNNotificationContent = content
        
        // 8. Communication Notification with Contact Avatar (iOS 15+)
        if #available(iOS 15.0, *) {
            let avatarImage = self.getAvatarImage(context: context, peer: effectiveSenderPeer)
            
            var personNameComponents = PersonNameComponents()
            if let user = effectiveSenderPeer._asPeer() as? TelegramUser {
                personNameComponents.givenName = user.firstName
                personNameComponents.familyName = user.lastName
            } else {
                personNameComponents.nickname = senderName
            }
            
            let senderPerson = INPerson(
                personHandle: INPersonHandle(value: "\(effectiveSenderPeer.id.toInt64())", type: .unknown),
                nameComponents: personNameComponents,
                displayName: senderName,
                image: avatarImage,
                contactIdentifier: nil,
                customIdentifier: "\(effectiveSenderPeer.id.toInt64())",
                isMe: false,
                suggestionType: .none
            )
            
            let mePerson = INPerson(
                personHandle: INPersonHandle(value: "0", type: .unknown),
                nameComponents: nil,
                displayName: nil,
                image: nil,
                contactIdentifier: nil,
                customIdentifier: nil,
                isMe: true,
                suggestionType: .none
            )
            
            let speakableGroup: INSpeakableString? = (isGroup && groupTitle != nil) ? INSpeakableString(spokenPhrase: groupTitle!) : nil
            let conversationId = "\(firstMessage.id.peerId.toInt64())"
            
            let intent = INSendMessageIntent(
                recipients: [mePerson],
                outgoingMessageType: .outgoingMessageText,
                content: body,
                speakableGroupName: speakableGroup,
                conversationIdentifier: conversationId,
                serviceName: nil,
                sender: senderPerson,
                attachments: nil
            )
            if let avatarImage = avatarImage {
                intent.setImage(avatarImage, forParameterNamed: \.sender)
            }
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.direction = .incoming
            interaction.donate(completion: nil)
            
            do {
                finalContent = try content.updating(from: intent)
            } catch {
                print("[Wgram] updating(from: intent) error: \(error)")
            }
        }
        
        let identifier = "wgram_msg_\(firstMessage.id.peerId.toInt64())_\(firstMessage.id.id)"
        let request = UNNotificationRequest(identifier: identifier, content: finalContent, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    private static func getAvatarImage(context: AccountContext, peer: EnginePeer) -> INImage? {
        let size = CGSize(width: 100.0, height: 100.0)
        var avatarUIImage: UIImage?
        
        if let resource = peer.smallProfileImage?.resource {
            if let path = context.account.postbox.mediaBox.completedResourcePath(resource),
               let rawImage = UIImage(contentsOfFile: path) {
                let renderer = UIGraphicsImageRenderer(size: size)
                avatarUIImage = renderer.image { _ in
                    let rect = CGRect(origin: .zero, size: size)
                    UIBezierPath(ovalIn: rect).addClip()
                    
                    let imageWidth = rawImage.size.width
                    let imageHeight = rawImage.size.height
                    if imageWidth > 0 && imageHeight > 0 {
                        let scale = max(size.width / imageWidth, size.height / imageHeight)
                        let drawWidth = imageWidth * scale
                        let drawHeight = imageHeight * scale
                        let drawOrigin = CGPoint(x: (size.width - drawWidth) / 2.0, y: (size.height - drawHeight) / 2.0)
                        rawImage.draw(in: CGRect(origin: drawOrigin, size: CGSize(width: drawWidth, height: drawHeight)))
                    }
                }
            } else {
                let ref: MediaResourceReference = PeerReference(peer._asPeer()).flatMap { .avatar(peer: $0, resource: resource) } ?? .standalone(resource: resource)
                let _ = fetchedMediaResource(
                    mediaBox: context.account.postbox.mediaBox,
                    userLocation: .other,
                    userContentType: .avatar,
                    reference: ref,
                    statsCategory: .generic
                ).start()
            }
        }
        
        if avatarUIImage == nil {
            let avatarFont = avatarPlaceholderFont(size: 42.0)
            avatarUIImage = generateImage(size, rotatedContext: { size, ctx in
                ctx.clear(CGRect(origin: .zero, size: size))
                drawPeerAvatarLetters(
                    context: ctx,
                    size: size,
                    round: true,
                    font: avatarFont,
                    letters: peer.displayLetters,
                    peerId: peer.id,
                    nameColor: peer.nameColor
                )
            })
        }
        
        guard let uiImage = avatarUIImage, let data = uiImage.jpegData(compressionQuality: 0.9) else { return nil }
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wgram-avatars", isDirectory: true)
        let _ = try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        let fileUrl = tempDir.appendingPathComponent("\(peer.id.toInt64()).jpg")
        
        do {
            try data.write(to: fileUrl, options: .atomic)
            return INImage(url: fileUrl)
        } catch {
            return nil
        }
    }
}
