import Foundation

public struct WgramSettings {
    public static let didChangeNotification = Notification.Name("WgramSettingsDidChangeNotification")

    private static let ghostModeEnabledKey = "Wgram_GhostModeEnabled"
    private static let ghostDontReadMessagesKey = "Wgram_GhostDontReadMessages"
    private static let ghostDontSendTypingKey = "Wgram_GhostDontSendTyping"
    private static let ghostDontUpdateOnlineKey = "Wgram_GhostDontUpdateOnline"
    private static let ghostDontReadStoriesKey = "Wgram_GhostDontReadStories"
    private static let ghostDontReadMediaKey = "Wgram_GhostDontReadMedia"
    private static let keepAliveInBackgroundKey = "Wgram_KeepAliveInBackground"

    private static func notifyChanged() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

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

    public static var keepAliveInBackground: Bool {
        get { UserDefaults.standard.bool(forKey: keepAliveInBackgroundKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: keepAliveInBackgroundKey)
            notifyChanged()
        }
    }
}
