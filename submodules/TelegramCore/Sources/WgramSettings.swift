import Foundation
import Postbox

public struct WgramSettings {
    public static let didChangeNotification = Notification.Name("WgramSettingsDidChangeNotification")

    private static let ghostModeEnabledKey = "Wgram_GhostModeEnabled"
    private static let ghostDontReadMessagesKey = "Wgram_GhostDontReadMessages"
    private static let ghostDontSendTypingKey = "Wgram_GhostDontSendTyping"
    private static let ghostDontUpdateOnlineKey = "Wgram_GhostDontUpdateOnline"
    private static let ghostDontReadStoriesKey = "Wgram_GhostDontReadStories"
    private static let ghostDontReadMediaKey = "Wgram_GhostDontReadMedia"
    private static let ghostSendKey = "Wgram_GhostSend"
    private static let markReadAfterActionKey = "Wgram_MarkReadAfterAction"

    private static let bypassCopyProtectionKey = "Wgram_BypassCopyProtection"
    private static let bypassViewOnceKey = "Wgram_BypassViewOnce"
    private static let hideSponsoredMessagesKey = "Wgram_HideSponsoredMessages"

    private static let confirmVoiceSendKey = "Wgram_ConfirmVoiceSend"
    private static let confirmVideoSendKey = "Wgram_ConfirmVideoSend"
    private static let confirmStickerSendKey = "Wgram_ConfirmStickerSend"

    private static let antiDeleteMessagesKey = "Wgram_AntiDeleteMessages"
    private static let saveEditHistoryKey = "Wgram_SaveEditHistory"
    private static let antiDeleteExcludedPeerIdsKey = "Wgram_AntiDeleteExcludedPeerIds"
    private static let logEditsAndDeletesToChatEnabledKey = "Wgram_LogEditsAndDeletesToChatEnabled"
    private static let logChatTargetUsernameKey = "Wgram_LogChatTargetUsername"
    private static let logChatTargetPeerIdKey = "Wgram_LogChatTargetPeerId"
    private static let logPrivateChatsKey = "Wgram_LogPrivateChats"
    private static let logGroupsKey = "Wgram_LogGroups"
    private static let logChannelsKey = "Wgram_LogChannels"
    private static let logDeletedMessagesKey = "Wgram_LogDeletedMessages"
    private static let logEditedMessagesKey = "Wgram_LogEditedMessages"
    private static let logIncludeChatInfoKey = "Wgram_LogIncludeChatInfo"

    private static let showPeerIdAndDcKey = "Wgram_ShowPeerIdAndDc"
    private static let showChatMessageCountKey = "Wgram_ShowChatMessageCount"
    private static let showMessageSecondsKey = "Wgram_ShowMessageSeconds"
    private static let videoNoteCameraIsBackKey = "Wgram_VideoNoteCameraIsBack"
    private static let maxVideoNoteDurationKey = "Wgram_MaxVideoNoteDuration"
    private static let splitLongVideoNotesKey = "Wgram_SplitLongVideoNotes"

    private static let keepAliveInBackgroundKey = "Wgram_KeepAliveInBackground"

    private static let tgWsProxyEnabledKey = "Wgram_TgWsProxyEnabled"
    private static let tgWsSelectedDomainKey = "Wgram_TgWsSelectedDomain"
    private static let tgWsCustomDomainKey = "Wgram_TgWsCustomDomain"
    private static let tgWsAutoFallbackKey = "Wgram_TgWsAutoFallback"
    private static let tgWsCallsBridgeEnabledKey = "Wgram_TgWsCallsBridgeEnabled"

    private static let localPremiumEnabledKey = "Wgram_LocalPremiumEnabled"
    private static let localPremiumCustomEmojiKey = "Wgram_LocalPremiumCustomEmoji"
    private static let currentAccountPeerIdKey = "Wgram_CurrentAccountPeerId"
    private static let isRealPremiumKey = "Wgram_IsRealPremium"

    private static func notifyChanged() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    // MARK: - Ghost Mode
    public static var ghostModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: ghostModeEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: ghostModeEnabledKey)
            notifyChanged()
        }
    }

    public static var dontReadMessages: Bool {
        get {
            if !ghostModeEnabled { return false }
            return UserDefaults.standard.object(forKey: ghostDontReadMessagesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ghostDontReadMessagesKey)
            notifyChanged()
        }
    }

    public static var dontSendTyping: Bool {
        get {
            if !ghostModeEnabled { return false }
            return UserDefaults.standard.object(forKey: ghostDontSendTypingKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ghostDontSendTypingKey)
            notifyChanged()
        }
    }

    public static var dontUpdateOnline: Bool {
        get {
            if !ghostModeEnabled { return false }
            return UserDefaults.standard.object(forKey: ghostDontUpdateOnlineKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ghostDontUpdateOnlineKey)
            notifyChanged()
        }
    }

    public static var dontReadStories: Bool {
        get {
            if !ghostModeEnabled { return false }
            return UserDefaults.standard.object(forKey: ghostDontReadStoriesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ghostDontReadStoriesKey)
            notifyChanged()
        }
    }

    public static var dontReadMedia: Bool {
        get {
            if !ghostModeEnabled { return false }
            return UserDefaults.standard.object(forKey: ghostDontReadMediaKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ghostDontReadMediaKey)
            notifyChanged()
        }
    }

    public static var ghostSend: Bool {
        get {
            if !ghostModeEnabled { return false }
            return UserDefaults.standard.bool(forKey: ghostSendKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ghostSendKey)
            notifyChanged()
        }
    }

    public static var markReadAfterAction: Bool {
        get {
            if !ghostModeEnabled { return false }
            return UserDefaults.standard.bool(forKey: markReadAfterActionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: markReadAfterActionKey)
            notifyChanged()
        }
    }

    // MARK: - Copy Protection Bypass
    public static var bypassCopyProtection: Bool {
        get {
            return UserDefaults.standard.object(forKey: bypassCopyProtectionKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: bypassCopyProtectionKey)
            notifyChanged()
        }
    }

    public static var bypassViewOnce: Bool {
        get {
            return UserDefaults.standard.object(forKey: bypassViewOnceKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: bypassViewOnceKey)
            notifyChanged()
        }
    }

    // MARK: - Sponsored Messages
    public static var hideSponsoredMessages: Bool {
        get {
            return UserDefaults.standard.object(forKey: hideSponsoredMessagesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hideSponsoredMessagesKey)
            notifyChanged()
        }
    }

    // MARK: - Confirmation Protections
    public static var confirmVoiceSend: Bool {
        get { UserDefaults.standard.bool(forKey: confirmVoiceSendKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: confirmVoiceSendKey)
            notifyChanged()
        }
    }

    public static var confirmVideoSend: Bool {
        get { UserDefaults.standard.bool(forKey: confirmVideoSendKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: confirmVideoSendKey)
            notifyChanged()
        }
    }

    public static var confirmStickerSend: Bool {
        get { UserDefaults.standard.bool(forKey: confirmStickerSendKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: confirmStickerSendKey)
            notifyChanged()
        }
    }

    // MARK: - Message History & Anti-Delete
    public static var antiDeleteMessages: Bool {
        get {
            return UserDefaults.standard.object(forKey: antiDeleteMessagesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: antiDeleteMessagesKey)
            notifyChanged()
        }
    }

    public static var saveEditHistory: Bool {
        get {
            return UserDefaults.standard.object(forKey: saveEditHistoryKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: saveEditHistoryKey)
            notifyChanged()
        }
    }

    public static var antiDeleteExcludedPeerIds: [Int64] {
        get {
            let array = UserDefaults.standard.array(forKey: antiDeleteExcludedPeerIdsKey)
            if let numbers = array as? [NSNumber] {
                return numbers.map { $0.int64Value }
            } else if let int64s = array as? [Int64] {
                return int64s
            }
            return []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: antiDeleteExcludedPeerIdsKey)
            notifyChanged()
        }
    }

    public static func isAntiDeleteExcluded(peerId: PeerId) -> Bool {
        let fullId = peerId.toInt64()
        let rawId = peerId.id._internalGetInt64Value()
        let list = antiDeleteExcludedPeerIds
        return list.contains(fullId) || list.contains(rawId)
    }

    public static func addAntiDeleteExcluded(peerId: PeerId) {
        var list = antiDeleteExcludedPeerIds
        let fullId = peerId.toInt64()
        let rawId = peerId.id._internalGetInt64Value()
        list.removeAll { $0 == rawId || $0 == fullId }
        list.append(fullId)
        antiDeleteExcludedPeerIds = list
    }

    public static func removeAntiDeleteExcluded(peerId: PeerId) {
        var list = antiDeleteExcludedPeerIds
        let fullId = peerId.toInt64()
        let rawId = peerId.id._internalGetInt64Value()
        list.removeAll { $0 == rawId || $0 == fullId }
        antiDeleteExcludedPeerIds = list
    }

    public static var logEditsAndDeletesToChatEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: logEditsAndDeletesToChatEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: logEditsAndDeletesToChatEnabledKey)
            notifyChanged()
        }
    }

    public static var logChatTargetUsername: String {
        get { UserDefaults.standard.string(forKey: logChatTargetUsernameKey) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: logChatTargetUsernameKey)
            notifyChanged()
        }
    }

    public static var logChatTargetPeerId: Int64 {
        get {
            return (UserDefaults.standard.object(forKey: logChatTargetPeerIdKey) as? NSNumber)?.int64Value ?? 0
        }
        set {
            UserDefaults.standard.set(NSNumber(value: newValue), forKey: logChatTargetPeerIdKey)
            // Caching peerId should not fire notifications to avoid presence resets
        }
    }

    public static var logPrivateChats: Bool {
        get { UserDefaults.standard.object(forKey: logPrivateChatsKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: logPrivateChatsKey)
            notifyChanged()
        }
    }

    public static var logGroups: Bool {
        get { UserDefaults.standard.object(forKey: logGroupsKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: logGroupsKey)
            notifyChanged()
        }
    }

    public static var logChannels: Bool {
        get { UserDefaults.standard.object(forKey: logChannelsKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: logChannelsKey)
            notifyChanged()
        }
    }

    public static var logDeletedMessages: Bool {
        get { UserDefaults.standard.object(forKey: logDeletedMessagesKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: logDeletedMessagesKey)
            notifyChanged()
        }
    }

    public static var logEditedMessages: Bool {
        get { UserDefaults.standard.object(forKey: logEditedMessagesKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: logEditedMessagesKey)
            notifyChanged()
        }
    }

    public static var logIncludeChatInfo: Bool {
        get { UserDefaults.standard.object(forKey: logIncludeChatInfoKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: logIncludeChatInfoKey)
            notifyChanged()
        }
    }

    // MARK: - UI & Information
    public static var showPeerIdAndDc: Bool {
        get {
            return UserDefaults.standard.object(forKey: showPeerIdAndDcKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showPeerIdAndDcKey)
            notifyChanged()
        }
    }

    public static var showChatMessageCount: Bool {
        get {
            return UserDefaults.standard.object(forKey: showChatMessageCountKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showChatMessageCountKey)
            notifyChanged()
        }
    }

    public static var showMessageSeconds: Bool {
        get { UserDefaults.standard.bool(forKey: showMessageSecondsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: showMessageSecondsKey)
            notifyChanged()
        }
    }

    // MARK: - Video Notes & Camera
    public static var videoNoteCameraIsBack: Bool {
        get { UserDefaults.standard.bool(forKey: videoNoteCameraIsBackKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: videoNoteCameraIsBackKey)
            notifyChanged()
        }
    }

    public static var maxVideoNoteDuration: Double {
        get {
            let val = UserDefaults.standard.double(forKey: maxVideoNoteDurationKey)
            return val > 0 ? val : 600.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: maxVideoNoteDurationKey)
            notifyChanged()
        }
    }

    public static var splitLongVideoNotes: Bool {
        get {
            return UserDefaults.standard.object(forKey: splitLongVideoNotesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: splitLongVideoNotesKey)
            notifyChanged()
        }
    }

    // MARK: - Keep Alive
    public static var keepAliveInBackground: Bool {
        get { UserDefaults.standard.object(forKey: keepAliveInBackgroundKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: keepAliveInBackgroundKey)
            notifyChanged()
        }
    }

    // MARK: - TG WS Proxy
    public static var tgWsProxyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: tgWsProxyEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: tgWsProxyEnabledKey)
            notifyChanged()
        }
    }

    public static var tgWsSelectedDomain: String {
        get { UserDefaults.standard.string(forKey: tgWsSelectedDomainKey) ?? "noskomnadzor.co.uk" }
        set {
            UserDefaults.standard.set(newValue, forKey: tgWsSelectedDomainKey)
            notifyChanged()
        }
    }

    public static var tgWsCustomDomain: String {
        get { UserDefaults.standard.string(forKey: tgWsCustomDomainKey) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: tgWsCustomDomainKey)
            notifyChanged()
        }
    }

    public static var tgWsAutoFallback: Bool {
        get { UserDefaults.standard.object(forKey: tgWsAutoFallbackKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: tgWsAutoFallbackKey)
            notifyChanged()
        }
    }

    public static var tgWsCallsBridgeEnabled: Bool {
        get { UserDefaults.standard.object(forKey: tgWsCallsBridgeEnabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: tgWsCallsBridgeEnabledKey)
            notifyChanged()
        }
    }

    // MARK: - Local Premium
    public static var localPremiumEnabled: Bool {
        get { UserDefaults.standard.object(forKey: localPremiumEnabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: localPremiumEnabledKey)
            notifyChanged()
        }
    }

    public static var localPremiumCustomEmoji: Bool {
        get { UserDefaults.standard.object(forKey: localPremiumCustomEmojiKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: localPremiumCustomEmojiKey)
            notifyChanged()
        }
    }

    public static var currentAccountPeerId: Int64 {
        get { UserDefaults.standard.object(forKey: currentAccountPeerIdKey) as? Int64 ?? 0 }
        set {
            UserDefaults.standard.set(newValue, forKey: currentAccountPeerIdKey)
        }
    }

    public static var isRealPremium: Bool {
        get { UserDefaults.standard.bool(forKey: isRealPremiumKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: isRealPremiumKey)
        }
    }

    public static func parseCustomEmojiUrl(_ url: String) -> Int64? {
        guard !url.isEmpty else { return nil }

        if let components = URLComponents(string: url) {
            let host = components.host?.lowercased()
            let path = components.path.lowercased()
            let scheme = components.scheme?.lowercased()

            let isTgEmoji = (scheme == "tg" && (host == "emoji" || path == "/emoji" || path == "emoji"))
            let isHttpEmoji = ((scheme == "https" || scheme == "http") && (host == "t.me" || host == "telegram.me") && (path == "/emoji" || path == "emoji"))

            if isTgEmoji || isHttpEmoji {
                if let queryItems = components.queryItems,
                   let idItem = queryItems.first(where: { $0.name.lowercased() == "id" }),
                   let value = idItem.value,
                   let fileId = Int64(value) {
                    return fileId
                }
            }
        }

        let prefixes = ["tg://emoji?id=", "https://t.me/emoji?id=", "http://t.me/emoji?id=", "t.me/emoji?id="]
        for prefix in prefixes {
            if url.lowercased().hasPrefix(prefix) {
                let idStr = String(url.dropFirst(prefix.count))
                let digits = idStr.prefix(while: { ($0 >= "0" && $0 <= "9") || $0 == "-" })
                if let fileId = Int64(digits) {
                    return fileId
                }
            }
        }

        return nil
    }
}
