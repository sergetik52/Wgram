import Foundation

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

    private static let confirmVoiceSendKey = "Wgram_ConfirmVoiceSend"
    private static let confirmVideoSendKey = "Wgram_ConfirmVideoSend"
    private static let confirmStickerSendKey = "Wgram_ConfirmStickerSend"

    private static let antiDeleteMessagesKey = "Wgram_AntiDeleteMessages"
    private static let saveEditHistoryKey = "Wgram_SaveEditHistory"

    private static let showPeerIdAndDcKey = "Wgram_ShowPeerIdAndDc"
    private static let showMessageSecondsKey = "Wgram_ShowMessageSeconds"

    private static let keepAliveInBackgroundKey = "Wgram_KeepAliveInBackground"

    private static let tgWsProxyEnabledKey = "Wgram_TgWsProxyEnabled"
    private static let tgWsSelectedDomainKey = "Wgram_TgWsSelectedDomain"
    private static let tgWsCustomDomainKey = "Wgram_TgWsCustomDomain"
    private static let tgWsAutoFallbackKey = "Wgram_TgWsAutoFallback"

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

    public static var showMessageSeconds: Bool {
        get { UserDefaults.standard.bool(forKey: showMessageSecondsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: showMessageSecondsKey)
            notifyChanged()
        }
    }

    // MARK: - Keep Alive
    public static var keepAliveInBackground: Bool {
        get { UserDefaults.standard.bool(forKey: keepAliveInBackgroundKey) }
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
}
