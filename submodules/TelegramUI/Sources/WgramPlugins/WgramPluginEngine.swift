import Foundation
import UIKit
import JavaScriptCore
import CoreMotion
import Postbox
import TelegramCore

public final class WgramPassthroughWindow: UIWindow {
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == self || hitView == self.rootViewController?.view {
            return nil
        }
        return hitView
    }
}

public final class WgramPluginEngine {
    public static let shared = WgramPluginEngine()
    public static let pluginsChangedNotification = Notification.Name("WgramPluginsChangedNotification")
    
    private let storageKey = "Wgram_Installed_Plugins_v1"
    private var plugins: [WgramPlugin] = []
    
    private var activeContexts: [String: JSContext] = [:]
    private var activeWidgets: [String: [WgramFloatingWidget]] = [:]
    private var outgoingMessageHooks: [String: JSValue] = [:]
    private var commandHooks: [String: [String: JSValue]] = [:] // pluginId -> [command -> function]
    
    private var motionManager: CMMotionManager?
    private var motionListeners: [String: JSValue] = [:]
    private var lastShakeTime: CFTimeInterval = 0
    
    public var installedPlugins: [WgramPlugin] {
        return self.plugins
    }
    
    public var enabledPluginsCount: Int {
        return self.plugins.filter { $0.isEnabled }.count
    }
    
    private init() {
        self.loadFromDisk()
        self.startEnabledPlugins()
    }
    
    // MARK: - Persistence
    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: self.storageKey),
           let list = try? JSONDecoder().decode([WgramPlugin].self, from: data) {
            self.plugins = list
        } else {
            self.plugins = []
        }
    }
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(self.plugins) {
            UserDefaults.standard.set(data, forKey: self.storageKey)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: WgramPluginEngine.pluginsChangedNotification, object: nil)
        }
    }
    
    // MARK: - Lifecycle Management
    private func startEnabledPlugins() {
        for plugin in self.plugins where plugin.isEnabled {
            self.startPlugin(plugin)
        }
    }
    
    public func startPlugin(_ plugin: WgramPlugin) {
        self.stopPlugin(id: plugin.id)
        
        let context = JSContext()!
        context.exceptionHandler = { _, exception in
            print("[WgramPlugin \(plugin.id) Error]: \(exception?.toString() ?? "unknown error")")
        }
        
        // Define 'wgram' bridge
        let wgramObj = JSValue(newObjectIn: context)!
        wgramObj.setValue(plugin.id, forProperty: "id")
        wgramObj.setValue(plugin.name, forProperty: "name")
        wgramObj.setValue(plugin.version, forProperty: "version")
        
        // wgram.log
        let logHandler: @convention(block) (String) -> Void = { msg in
            print("[WgramPlugin: \(plugin.name)] \(msg)")
        }
        wgramObj.setValue(logHandler, forProperty: "log")
        
        // wgram.showToast
        let toastHandler: @convention(block) (String) -> Void = { msg in
            DispatchQueue.main.async {
                WgramPluginEngine.showToastAlert(message: msg)
            }
        }
        wgramObj.setValue(toastHandler, forProperty: "showToast")
        
        // wgram.storage
        let storageObj = JSValue(newObjectIn: context)!
        let getStorage: @convention(block) (String, JSValue) -> JSValue = { key, defaultVal in
            let fullKey = "wgram_plugin_\(plugin.id)_\(key)"
            if let val = UserDefaults.standard.string(forKey: fullKey) {
                return JSValue(object: val, in: context)
            }
            return defaultVal
        }
        let setStorage: @convention(block) (String, String) -> Void = { key, val in
            let fullKey = "wgram_plugin_\(plugin.id)_\(key)"
            UserDefaults.standard.set(val, forKey: fullKey)
        }
        storageObj.setValue(getStorage, forProperty: "get")
        storageObj.setValue(setStorage, forProperty: "set")
        wgramObj.setValue(storageObj, forProperty: "storage")
        
        // wgram.onSendMessage
        let onSendHandler: @convention(block) (JSValue) -> Void = { [weak self] callback in
            self?.outgoingMessageHooks[plugin.id] = callback
        }
        wgramObj.setValue(onSendHandler, forProperty: "onSendMessage")
        
        // wgram.registerCommand
        let regCmdHandler: @convention(block) (String, JSValue) -> Void = { [weak self] name, callback in
            guard let strongSelf = self else { return }
            var cmdMap = strongSelf.commandHooks[plugin.id] ?? [:]
            cmdMap[name.lowercased()] = callback
            strongSelf.commandHooks[plugin.id] = cmdMap
        }
        wgramObj.setValue(regCmdHandler, forProperty: "registerCommand")
        
        // wgram.createFloatingWidget
        let createWidgetHandler: @convention(block) (JSValue) -> JSValue? = { [weak self] options in
            guard let strongSelf = self else { return nil }
            let width = CGFloat(options.forProperty("width")?.toDouble() ?? 72.0)
            let height = CGFloat(options.forProperty("height")?.toDouble() ?? 52.0)
            let initX = CGFloat(options.forProperty("initialX")?.toDouble() ?? 100.0)
            let initY = CGFloat(options.forProperty("initialY")?.toDouble() ?? 250.0)
            
            var widget: WgramFloatingWidget?
            if Thread.isMainThread {
                widget = strongSelf.spawnWidget(pluginId: plugin.id, width: width, height: height, initialX: initX, initialY: initY)
            } else {
                DispatchQueue.main.sync {
                    widget = strongSelf.spawnWidget(pluginId: plugin.id, width: width, height: height, initialX: initX, initialY: initY)
                }
            }
            guard let createdWidget = widget else { return nil }
            return JSValue(object: createdWidget, in: context)
        }
        wgramObj.setValue(createWidgetHandler, forProperty: "createFloatingWidget")
        
        // wgram.startMotion / stopMotion
        let startMotionHandler: @convention(block) (JSValue) -> Void = { [weak self] callback in
            guard let strongSelf = self else { return }
            strongSelf.motionListeners[plugin.id] = callback
            strongSelf.ensureMotionUpdates()
        }
        let stopMotionHandler: @convention(block) () -> Void = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.motionListeners.removeValue(forKey: plugin.id)
            if strongSelf.motionListeners.isEmpty {
                strongSelf.motionManager?.stopAccelerometerUpdates()
            }
        }
        wgramObj.setValue(startMotionHandler, forProperty: "startMotion")
        wgramObj.setValue(stopMotionHandler, forProperty: "stopMotion")
        
        // wgram.haptic
        let hapticHandler: @convention(block) (String) -> Void = { type in
            DispatchQueue.main.async {
                switch type {
                case "light":
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                case "medium":
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                case "heavy":
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                case "success":
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                case "warning":
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                case "error":
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                default:
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        wgramObj.setValue(hapticHandler, forProperty: "haptic")
        
        // wgram.getScreenSize
        let screenSizeHandler: @convention(block) () -> [String: Double] = {
            let bounds = UIScreen.main.bounds
            let insets = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.safeAreaInsets ?? .zero
            return [
                "width": Double(bounds.width),
                "height": Double(bounds.height),
                "safeTop": Double(insets.top),
                "safeBottom": Double(insets.bottom)
            ]
        }
        wgramObj.setValue(screenSizeHandler, forProperty: "getScreenSize")
        
        // wgram.fetch
        let fetchHandler: @convention(block) (String, JSValue?, JSValue?) -> Void = { urlString, options, callback in
            guard let url = URL(string: urlString) else {
                callback?.call(withArguments: [JSValue(object: ["error": "Invalid URL"], in: context)!])
                return
            }
            var request = URLRequest(url: url)
            if let method = options?.forProperty("method")?.toString() {
                request.httpMethod = method
            }
            if let headers = options?.forProperty("headers")?.toDictionary() as? [String: String] {
                for (k, v) in headers {
                    request.setValue(v, forHTTPHeaderField: k)
                }
            }
            if let body = options?.forProperty("body")?.toString() {
                request.httpBody = body.data(using: .utf8)
            }
            URLSession.shared.dataTask(with: request) { data, response, error in
                let respObj = JSValue(newObjectIn: context)!
                if let httpResp = response as? HTTPURLResponse {
                    respObj.setValue(httpResp.statusCode, forProperty: "status")
                }
                if let err = error {
                    respObj.setValue(err.localizedDescription, forProperty: "error")
                } else if let d = data, let text = String(data: d, encoding: .utf8) {
                    respObj.setValue(text, forProperty: "text")
                }
                DispatchQueue.main.async {
                    callback?.call(withArguments: [respObj])
                }
            }.resume()
        }
        wgramObj.setValue(fetchHandler, forProperty: "fetch")
        
        // Set global 'wgram'
        context.setObject(wgramObj, forKeyedSubscript: "wgram" as NSString)
        
        // Evaluate Code
        context.evaluateScript(plugin.code)
        
        self.activeContexts[plugin.id] = context
    }
    
    private var overlayWindow: WgramPassthroughWindow?
    
    private func ensureOverlayWindow() -> WgramPassthroughWindow {
        if let existing = self.overlayWindow {
            existing.isHidden = false
            return existing
        }
        
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        
        let window: WgramPassthroughWindow
        if let scene = windowScene {
            window = WgramPassthroughWindow(windowScene: scene)
        } else {
            window = WgramPassthroughWindow(frame: UIScreen.main.bounds)
        }
        
        window.windowLevel = UIWindow.Level.statusBar - 0.001
        window.backgroundColor = .clear
        window.isOpaque = false
        
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        window.rootViewController = rootVC
        window.isHidden = false
        
        self.overlayWindow = window
        return window
    }
    
    private func spawnWidget(pluginId: String, width: CGFloat, height: CGFloat, initialX: CGFloat, initialY: CGFloat) -> WgramFloatingWidget {
        let window = self.ensureOverlayWindow()
        let widget = WgramFloatingWidget(width: width, height: height, initialX: initialX, initialY: initialY)
        window.rootViewController?.view.addSubview(widget)
        
        var list = self.activeWidgets[pluginId] ?? []
        list.append(widget)
        self.activeWidgets[pluginId] = list
        return widget
    }
    
    public func stopPlugin(id: String) {
        if let widgets = self.activeWidgets[id] {
            for widget in widgets {
                widget.destroy()
            }
            self.activeWidgets.removeValue(forKey: id)
        }
        if self.activeWidgets.isEmpty {
            self.overlayWindow?.isHidden = true
        }
        self.outgoingMessageHooks.removeValue(forKey: id)
        self.commandHooks.removeValue(forKey: id)
        self.motionListeners.removeValue(forKey: id)
        if self.motionListeners.isEmpty {
            self.motionManager?.stopAccelerometerUpdates()
        }
        self.activeContexts.removeValue(forKey: id)
    }
    
    // MARK: - Motion Sensor
    private func ensureMotionUpdates() {
        if self.motionManager == nil {
            self.motionManager = CMMotionManager()
            self.motionManager?.accelerometerUpdateInterval = 1.0 / 30.0
        }
        guard let manager = self.motionManager, !manager.isAccelerometerActive else { return }
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let strongSelf = self, let accel = data?.acceleration else { return }
            
            let tiltX = accel.x
            let tiltY = accel.y
            let mag = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            
            var isShaking = false
            let now = CACurrentMediaTime()
            if mag > 2.4 && (now - strongSelf.lastShakeTime) > 0.8 {
                strongSelf.lastShakeTime = now
                isShaking = true
            }
            
            for (_, callback) in strongSelf.motionListeners {
                callback.call(withArguments: [Double(tiltX), Double(tiltY), isShaking])
            }
        }
    }
    
    // MARK: - Public Plugin Controls
    public func togglePlugin(id: String, enabled: Bool) {
        if let idx = self.plugins.firstIndex(where: { $0.id == id }) {
            self.plugins[idx].isEnabled = enabled
            self.saveToDisk()
            if enabled {
                self.startPlugin(self.plugins[idx])
            } else {
                self.stopPlugin(id: id)
            }
        }
    }
    
    public func deletePlugin(id: String) {
        self.stopPlugin(id: id)
        self.plugins.removeAll(where: { $0.id == id })
        self.saveToDisk()
    }
    
    public func installPlugin(code: String) -> (success: Bool, plugin: WgramPlugin?, error: String?) {
        let meta = self.parseMetadata(from: code)
        guard !meta.id.isEmpty else {
            return (false, nil, "Не удалось определить ID плагина")
        }
        
        let newPlugin = WgramPlugin(
            id: meta.id,
            name: meta.name.isEmpty ? meta.id : meta.name,
            description: meta.description,
            author: meta.author,
            version: meta.version.isEmpty ? "1.0" : meta.version,
            isEnabled: true,
            code: code
        )
        
        // Remove old version if installed
        self.plugins.removeAll(where: { $0.id == newPlugin.id })
        self.plugins.append(newPlugin)
        self.saveToDisk()
        
        self.startPlugin(newPlugin)
        return (true, newPlugin, nil)
    }
    
    // MARK: - Outgoing Message Hook
    public func processOutgoingMessage(peerId: PeerId?, text: String) -> String? {
        var currentText = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check custom commands (.shrug, etc.)
        for (_, cmdMap) in self.commandHooks {
            for (cmdName, handler) in cmdMap {
                if trimmed.lowercased().hasPrefix(cmdName) {
                    let args = String(trimmed.dropFirst(cmdName.count)).trimmingCharacters(in: .whitespaces)
                    let chatIdStr = peerId.flatMap { "\($0.toInt64())" } ?? ""
                    if let result = handler.call(withArguments: [chatIdStr, args]), !result.isUndefined && !result.isNull {
                        return result.toString()
                    }
                }
            }
        }
        
        // 2. Check onSendMessage hooks
        for (_, hook) in self.outgoingMessageHooks {
            let chatIdStr = peerId.flatMap { "\($0.toInt64())" } ?? ""
            if let result = hook.call(withArguments: [chatIdStr, currentText]), !result.isUndefined && !result.isNull {
                currentText = result.toString()
            }
        }
        
        return currentText != text ? currentText : nil
    }
    
    // MARK: - Metadata Parser
    private func parseMetadata(from code: String) -> (id: String, name: String, description: String, author: String, version: String) {
        var id = ""
        var name = ""
        var desc = ""
        var author = ""
        var version = "1.0"
        
        let lines = code.components(separatedBy: "\n")
        for line in lines.prefix(80) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("// @id") || trimmed.hasPrefix("# @id") {
                id = trimmed.replacingOccurrences(of: "// @id", with: "").replacingOccurrences(of: "# @id", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("// @name") || trimmed.hasPrefix("# @name") {
                name = trimmed.replacingOccurrences(of: "// @name", with: "").replacingOccurrences(of: "# @name", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("// @description") || trimmed.hasPrefix("# @description") {
                desc = trimmed.replacingOccurrences(of: "// @description", with: "").replacingOccurrences(of: "# @description", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("// @author") || trimmed.hasPrefix("# @author") {
                author = trimmed.replacingOccurrences(of: "// @author", with: "").replacingOccurrences(of: "# @author", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("// @version") || trimmed.hasPrefix("# @version") {
                version = trimmed.replacingOccurrences(of: "// @version", with: "").replacingOccurrences(of: "# @version", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Fallback to random ID if none declared
        if id.isEmpty {
            id = "plugin_\(Int(Date().timeIntervalSince1970))"
        }
        if name.isEmpty {
            name = id
        }
        return (id, name, desc, author, version)
    }
    
    // MARK: - Toast Alert
    private static func showToastAlert(message: String) {
        let window = WgramPluginEngine.shared.ensureOverlayWindow()
        guard let targetView = window.rootViewController?.view else { return }
        
        let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        container.layer.cornerRadius = 16.0
        container.layer.masksToBounds = true
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.2
        container.layer.shadowRadius = 8.0
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        
        container.contentView.addSubview(label)
        targetView.addSubview(container)
        
        let maxW = min(targetView.bounds.width - 40.0, 300.0)
        let size = label.sizeThatFits(CGSize(width: maxW, height: 100))
        let toastW = size.width + 32.0
        let toastH = max(40.0, size.height + 16.0)
        
        container.frame = CGRect(x: (targetView.bounds.width - toastW) / 2.0, y: targetView.safeAreaInsets.top + 20.0, width: toastW, height: toastH)
        label.frame = container.bounds.insetBy(dx: 16.0, dy: 8.0)
        
        container.alpha = 0
        container.transform = CGAffineTransform(translationX: 0, y: -20.0)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            container.alpha = 1.0
            container.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.2, options: [], animations: {
                container.alpha = 0
                container.transform = CGAffineTransform(translationX: 0, y: -20.0)
            }) { _ in
                container.removeFromSuperview()
            }
        }
    }
}
