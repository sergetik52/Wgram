import Foundation
import UIKit
import JavaScriptCore
import CoreMotion

@objc public protocol WgramFloatingWidgetJSExport: JSExport {
    func setPosition(_ x: Double, _ y: Double)
    func getPosition() -> [String: Double]
    func getVelocity() -> [String: Double]
    func setSize(_ width: Double, _ height: Double)
    func setRotation(_ degrees: Double)
    func drawRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ colorHex: String)
    func clear()
    func redraw()
    func showSpeech(_ text: String, _ duration: Double)
    func hideSpeech()
    func setPhysicsEnabled(_ enabled: Bool)
    func setVelocity(_ vx: Double, _ vy: Double)
    func setGravity(_ gx: Double, _ gy: Double)
    func spawnParticle(_ kind: String, _ x: Double, _ y: Double)
    func createPoop(_ x: Double, _ y: Double, _ onClick: JSValue)
    func removePoops()
    func setPeeking(_ peeking: Bool)
    func eatNearestButton() -> Bool
    func spitAll()
    func getEatenCount() -> Int
    func destroy()
    
    var onTick: JSValue? { get set }
    var onTouch: JSValue? { get set }
    var onDraw: JSValue? { get set }
}

public final class WgramFloatingWidget: UIView, WgramFloatingWidgetJSExport, UIGestureRecognizerDelegate {
    public var onTick: JSValue?
    public var onTouch: JSValue?
    public var onDraw: JSValue?
    
    private var pixelRects: [(rect: CGRect, color: UIColor)] = []
    private var poopViews: [UIView] = []
    private var isPeeking: Bool = false
    private var eatenViews: [(view: UIView, originalAlpha: CGFloat, snapshot: UIView?, originalFrame: CGRect)] = []
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    
    // Physics properties
    private var isPhysicsEnabled: Bool = true
    private var velocity: CGPoint = .zero
    private var gravity: CGPoint = CGPoint(x: 0, y: 980.0) // 980 pt/s^2 downward
    private var elasticity: CGFloat = 0.55
    
    // Speech bubble
    private var speechBubbleView: WgramSpeechBubbleView?
    private var speechDismissTimer: Foundation.Timer?
    
    // Gestures
    private var panGesture: UIPanGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    private var doubleTapGesture: UITapGestureRecognizer!
    private var holdGesture: UILongPressGestureRecognizer!
    private var isDragging: Bool = false
    
    public init(width: CGFloat, height: CGFloat, initialX: CGFloat = 100, initialY: CGFloat = 300) {
        let frame = CGRect(x: initialX, y: initialY, width: max(20, width), height: max(20, height))
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.layer.masksToBounds = false
        self.isUserInteractionEnabled = true
        
        self.setupGestures()
        self.setupDisplayLink()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.displayLink?.invalidate()
        self.speechDismissTimer?.invalidate()
    }
    
    // Expand touch target for easy finger interaction
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -16.0, dy: -16.0).contains(point)
    }
    
    // MARK: - Gestures
    private func setupGestures() {
        self.panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        self.panGesture.delegate = self
        self.addGestureRecognizer(self.panGesture)
        
        self.doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDoubleTap(_:)))
        self.doubleTapGesture.numberOfTapsRequired = 2
        self.doubleTapGesture.delegate = self
        self.addGestureRecognizer(self.doubleTapGesture)
        
        self.tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.tapGesture.require(toFail: self.doubleTapGesture)
        self.tapGesture.delegate = self
        self.addGestureRecognizer(self.tapGesture)
        
        self.holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleHold(_:)))
        self.holdGesture.minimumPressDuration = 0.4
        self.holdGesture.delegate = self
        self.addGestureRecognizer(self.holdGesture)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: self)
        self.callTouch(type: "tap", x: loc.x, y: loc.y, dx: 0, dy: 0, vx: 0, vy: 0)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: self)
        self.callTouch(type: "double_tap", x: loc.x, y: loc.y, dx: 0, dy: 0, vx: 0, vy: 0)
    }
    
    @objc private func handleHold(_ gesture: UILongPressGestureRecognizer) {
        let loc = gesture.location(in: self)
        if gesture.state == .began {
            self.callTouch(type: "hold", x: loc.x, y: loc.y, dx: 0, dy: 0, vx: 0, vy: 0)
        } else if gesture.state == .changed {
            self.callTouch(type: "pet", x: loc.x, y: loc.y, dx: 0, dy: 0, vx: 0, vy: 0)
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        let translation = gesture.translation(in: superview)
        let vel = gesture.velocity(in: superview)
        let loc = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            self.isDragging = true
            self.velocity = .zero
            self.callTouch(type: "drag_start", x: loc.x, y: loc.y, dx: 0, dy: 0, vx: vel.x, vy: vel.y)
        case .changed:
            self.center = CGPoint(x: self.center.x + translation.x, y: self.center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
            self.updateSpeechBubblePosition()
            self.callTouch(type: "drag", x: loc.x, y: loc.y, dx: translation.x, dy: translation.y, vx: vel.x, vy: vel.y)
        case .ended, .cancelled:
            self.isDragging = false
            self.velocity = CGPoint(x: vel.x, y: vel.y)
            self.callTouch(type: "throw", x: loc.x, y: loc.y, dx: 0, dy: 0, vx: vel.x, vy: vel.y)
        default:
            break
        }
    }
    
    private func callTouch(type: String, x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat, vx: CGFloat, vy: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let callback = strongSelf.onTouch else { return }
            callback.call(withArguments: [type, Double(x), Double(y), Double(dx), Double(dy), Double(vx), Double(vy)])
        }
    }
    
    // MARK: - Display Link & Physics
    private func setupDisplayLink() {
        self.displayLink = CADisplayLink(target: self, selector: #selector(self.stepPhysics(_:)))
        self.displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func stepPhysics(_ link: CADisplayLink) {
        if self.lastTimestamp == 0 {
            self.lastTimestamp = link.timestamp
            return
        }
        let dt = CGFloat(min(0.05, link.timestamp - self.lastTimestamp))
        self.lastTimestamp = link.timestamp
        
        if self.isPhysicsEnabled && !self.isDragging, let superview = self.superview {
            // Apply velocity
            var currentPos = self.frame.origin
            currentPos.x += self.velocity.x * dt
            currentPos.y += self.velocity.y * dt
            
            // Gravity
            self.velocity.y += self.gravity.y * dt
            self.velocity.x += self.gravity.x * dt
            
            // Screen boundaries & platforms
            let safeArea = superview.safeAreaInsets
            let minX = self.isPeeking ? -self.frame.width + 16.0 : safeArea.left
            let maxX = self.isPeeking ? superview.bounds.width - 16.0 : max(minX, superview.bounds.width - safeArea.right - self.frame.width)
            let minY = safeArea.top + 20.0
            var maxY = max(minY, superview.bounds.height - safeArea.bottom - self.frame.height - 10.0)
            
            if let platformY = self.detectPlatformY(floorY: maxY) {
                maxY = platformY
            }
            
            if currentPos.x <= minX {
                currentPos.x = minX
                self.velocity.x = -self.velocity.x * self.elasticity
            } else if currentPos.x >= maxX {
                currentPos.x = maxX
                self.velocity.x = -self.velocity.x * self.elasticity
            }
            
            if currentPos.y <= minY {
                currentPos.y = minY
                self.velocity.y = -self.velocity.y * self.elasticity
            } else if currentPos.y >= maxY {
                currentPos.y = maxY
                self.velocity.y = -self.velocity.y * self.elasticity
                // Friction on floor
                self.velocity.x *= 0.88
                if abs(self.velocity.x) < 5.0 { self.velocity.x = 0 }
                if abs(self.velocity.y) < 15.0 { self.velocity.y = 0 }
            }
            
            self.frame.origin = currentPos
            self.updateSpeechBubblePosition()
        }
        
        // Notify JS onTick
        if let callback = self.onTick {
            callback.call(withArguments: [Double(dt)])
        }
    }
    
    // MARK: - Drawing Canvas
    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        for (itemRect, color) in self.pixelRects {
            ctx.setFillColor(color.cgColor)
            ctx.fill(itemRect)
        }
    }
    
    // MARK: - JSExport Implementation
    public func setPosition(_ x: Double, _ y: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.frame.origin = CGPoint(x: CGFloat(x), y: CGFloat(y))
            strongSelf.updateSpeechBubblePosition()
        }
    }
    
    public func getPosition() -> [String: Double] {
        return ["x": Double(self.frame.origin.x), "y": Double(self.frame.origin.y)]
    }
    
    public func getVelocity() -> [String: Double] {
        return ["vx": Double(self.velocity.x), "vy": Double(self.velocity.y)]
    }
    
    public func setSize(_ width: Double, _ height: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.frame.size = CGSize(width: CGFloat(width), height: CGFloat(height))
            strongSelf.setNeedsDisplay()
        }
    }
    
    public func setRotation(_ degrees: Double) {
        DispatchQueue.main.async { [weak self] in
            let rad = CGFloat(degrees * .pi / 180.0)
            self?.transform = CGAffineTransform(rotationAngle: rad)
        }
    }
    
    public func drawRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ colorHex: String) {
        let color = UIColor(hexString: colorHex)
        let rect = CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        self.pixelRects.append((rect, color))
    }
    
    public func clear() {
        self.pixelRects.removeAll(keepingCapacity: true)
    }
    
    public func redraw() {
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsDisplay()
        }
    }
    
    public func setPhysicsEnabled(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPhysicsEnabled = enabled
        }
    }
    
    public func setVelocity(_ vx: Double, _ vy: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.velocity = CGPoint(x: CGFloat(vx), y: CGFloat(vy))
        }
    }
    
    public func setGravity(_ gx: Double, _ gy: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.gravity = CGPoint(x: CGFloat(gx), y: CGFloat(gy))
        }
    }
    
    public func spawnParticle(_ kind: String, _ x: Double, _ y: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let superview = strongSelf.superview else { return }
            let particle = WgramParticleView(kind: kind)
            let px = x > 0 ? CGFloat(x) : strongSelf.frame.midX + CGFloat.random(in: -12...12)
            let py = y > 0 ? CGFloat(y) : strongSelf.frame.minY - 12.0
            particle.center = CGPoint(x: px, y: py)
            superview.addSubview(particle)
            
            let driftX = CGFloat.random(in: -18...18)
            let driftY: CGFloat = kind == "zzz" ? -55.0 : -45.0
            let duration: TimeInterval = kind == "zzz" ? 1.6 : 1.1
            
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut], animations: {
                particle.center = CGPoint(x: particle.center.x + driftX, y: particle.center.y + driftY)
                particle.alpha = 0.0
                particle.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            }) { _ in
                particle.removeFromSuperview()
            }
        }
    }
    
    public func createPoop(_ x: Double, _ y: Double, _ onClick: JSValue) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let superview = strongSelf.superview else { return }
            let poop = WgramPoopView(x: CGFloat(x), y: CGFloat(y), onClick: onClick, widget: strongSelf)
            superview.insertSubview(poop, belowSubview: strongSelf)
            strongSelf.poopViews.append(poop)
        }
    }
    
    public func removePoops() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            for p in strongSelf.poopViews {
                p.removeFromSuperview()
            }
            strongSelf.poopViews.removeAll()
        }
    }
    
    public func setPeeking(_ peeking: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPeeking = peeking
        }
    }
    
    private func detectPlatformY(floorY: CGFloat) -> CGFloat? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        let footX = self.frame.midX
        let footY = self.frame.maxY
        let hit = window.hitTest(CGPoint(x: footX, y: footY + 4.0), with: nil)
        if let target = hit, target !== window, let superview = self.superview {
            let targetFrame = target.convert(target.bounds, to: superview)
            let topY = targetFrame.minY - self.frame.height
            if topY > 80.0 && topY < floorY && footY >= targetFrame.minY - 14.0 && footY <= targetFrame.minY + 24.0 {
                return topY
            }
        }
        return nil
    }
    
    public func eatNearestButton() -> Bool {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow }) else {
            return false
        }
        
        var candidates: [UIView] = []
        var queue: [UIView] = [window]
        while !queue.isEmpty && candidates.count < 30 {
            let v = queue.removeFirst()
            if v.isHidden || v.alpha < 0.5 { continue }
            
            let frame = v.convert(v.bounds, to: nil)
            let w = frame.width
            let h = frame.height
            
            if (v is UIButton || (v is UIImageView && v.isUserInteractionEnabled) || (w >= 24 && w <= 80 && h >= 24 && h <= 80)) && frame.minY > 40 && frame.maxY < UIScreen.main.bounds.height - 20 {
                if !self.eatenViews.contains(where: { $0.view === v }) {
                    candidates.append(v)
                }
            }
            for sub in v.subviews {
                queue.append(sub)
            }
        }
        
        guard let target = candidates.randomElement(), let superview = self.superview else {
            return false
        }
        
        let destRect = target.convert(target.bounds, to: superview)
        guard let snapshot = target.snapshotView(afterScreenUpdates: false) else {
            return false
        }
        snapshot.frame = destRect
        superview.addSubview(snapshot)
        
        let origAlpha = target.alpha
        target.alpha = 0.0
        self.eatenViews.append((view: target, originalAlpha: origAlpha, snapshot: snapshot, originalFrame: destRect))
        
        let mouthPoint = CGPoint(x: self.frame.midX, y: self.frame.minY + self.frame.height * 0.6)
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseIn], animations: {
            snapshot.center = mouthPoint
            snapshot.transform = CGAffineTransform(scaleX: 0.05, y: 0.05).rotated(by: .pi)
        }) { _ in
            snapshot.removeFromSuperview()
        }
        return true
    }
    
    public func spitAll() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, !strongSelf.eatenViews.isEmpty, let superview = strongSelf.superview else { return }
            let items = strongSelf.eatenViews
            strongSelf.eatenViews.removeAll()
            
            let mouthPoint = CGPoint(x: strongSelf.frame.midX, y: strongSelf.frame.minY + strongSelf.frame.height * 0.6)
            
            for (index, item) in items.enumerated() {
                let target = item.view
                guard target.window != nil else {
                    target.alpha = item.originalAlpha
                    continue
                }
                
                let currentDest = target.convert(target.bounds, to: superview)
                let snapshot = target.snapshotView(afterScreenUpdates: false) ?? UIView(frame: currentDest)
                snapshot.frame = CGRect(origin: mouthPoint, size: currentDest.size)
                snapshot.transform = CGAffineTransform(scaleX: 0.05, y: 0.05).rotated(by: .pi)
                superview.addSubview(snapshot)
                
                let delay = Double(index) * 0.08
                UIView.animate(withDuration: 0.45, delay: delay, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                    snapshot.frame = currentDest
                    snapshot.transform = .identity
                }) { _ in
                    target.alpha = item.originalAlpha
                    snapshot.removeFromSuperview()
                }
            }
        }
    }
    
    public func getEatenCount() -> Int {
        return self.eatenViews.count
    }
    
    // MARK: - Speech Bubble
    public func showSpeech(_ text: String, _ duration: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let superview = strongSelf.superview else { return }
            
            strongSelf.speechDismissTimer?.invalidate()
            
            let bubble: WgramSpeechBubbleView
            if let existing = strongSelf.speechBubbleView {
                bubble = existing
            } else {
                bubble = WgramSpeechBubbleView()
                strongSelf.speechBubbleView = bubble
                superview.addSubview(bubble)
            }
            
            bubble.setText(text)
            strongSelf.updateSpeechBubblePosition()
            bubble.showAnimated()
            
            let timeout = duration > 0 ? duration : 3.5
            strongSelf.speechDismissTimer = Foundation.Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                self?.hideSpeech()
            }
        }
    }
    
    public func hideSpeech() {
        DispatchQueue.main.async { [weak self] in
            self?.speechDismissTimer?.invalidate()
            self?.speechBubbleView?.hideAnimated { [weak self] in
                self?.speechBubbleView?.removeFromSuperview()
                self?.speechBubbleView = nil
            }
        }
    }
    
    private func updateSpeechBubblePosition() {
        guard let bubble = self.speechBubbleView, let superview = self.superview else { return }
        let petFrame = self.frame
        let bubbleSize = bubble.sizeThatFits(CGSize(width: 220, height: 120))
        
        var bubbleX = petFrame.midX - bubbleSize.width / 2.0
        var bubbleY = petFrame.minY - bubbleSize.height - 8.0
        
        bubbleX = max(16.0, min(superview.bounds.width - bubbleSize.width - 16.0, bubbleX))
        if bubbleY < superview.safeAreaInsets.top + 10.0 {
            bubbleY = petFrame.maxY + 8.0
        }
        
        bubble.frame = CGRect(origin: CGPoint(x: bubbleX, y: bubbleY), size: bubbleSize)
    }
    
    public func destroy() {
        DispatchQueue.main.async { [weak self] in
            self?.spitAll()
            self?.displayLink?.invalidate()
            self?.displayLink = nil
            self?.speechDismissTimer?.invalidate()
            self?.speechBubbleView?.removeFromSuperview()
            self?.speechBubbleView = nil
            self?.removePoops()
            self?.removeFromSuperview()
        }
    }
}

// MARK: - Pixel Particle View
public final class WgramParticleView: UIView {
    private let kind: String
    
    private static let patterns: [String: [String]] = [
        "heart": [
            ".XX.XX.",
            "XXXXXXX",
            "XXXXXXX",
            ".XXXXX.",
            "..XXX..",
            "...X..."
        ],
        "zzz": [
            "XXXXX",
            "...X.",
            "..X..",
            ".X...",
            "XXXXX"
        ],
        "spark": [
            "..X..",
            "..X..",
            "XX.XX",
            "..X..",
            "..X.."
        ],
        "note": [
            "..XXXXX",
            "..X...X",
            "..X...X",
            "..X...X",
            "XXX.XXX",
            "XXX.XXX"
        ],
        "poop": [
            "....X....",
            "...XXo...",
            "..XXXXX..",
            ".XXXXXXo.",
            ".XwkXwkX.",
            "XXXXXXXXo",
            "XXXXXXXXX"
        ]
    ]
    
    private static let colors: [String: UIColor] = [
        "heart": UIColor(hexString: "FF5C7A"),
        "zzz": UIColor(hexString: "8FA3BF"),
        "spark": UIColor(hexString: "FFC94D"),
        "note": UIColor(hexString: "6FB8FF"),
        "X": UIColor(hexString: "8A5A33"),
        "o": UIColor(hexString: "B27D4E"),
        "w": UIColor(hexString: "FFFFFF"),
        "k": UIColor(hexString: "1A1A1A")
    ]
    
    public init(kind: String) {
        self.kind = kind
        let rows = WgramParticleView.patterns[kind] ?? WgramParticleView.patterns["spark"]!
        let s: CGFloat = kind == "poop" ? 4.0 : 3.0
        let w = CGFloat(rows[0].count) * s
        let h = CGFloat(rows.count) * s
        super.init(frame: CGRect(x: 0, y: 0, width: w, height: h))
        self.backgroundColor = .clear
        self.isOpaque = false
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        guard let rows = WgramParticleView.patterns[self.kind] else { return }
        let s: CGFloat = self.kind == "poop" ? 4.0 : 3.0
        
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                let charStr = String(ch)
                if charStr == "." { continue }
                let color: UIColor
                if self.kind == "poop" {
                    color = WgramParticleView.colors[charStr] ?? UIColor.brown
                } else {
                    color = WgramParticleView.colors[self.kind] ?? UIColor.white
                }
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s))
            }
        }
    }
}

// MARK: - Interactive Poop View
public final class WgramPoopView: UIView {
    private let particleView = WgramParticleView(kind: "poop")
    private let onClick: JSValue
    private weak var widget: WgramFloatingWidget?
    
    public init(x: CGFloat, y: CGFloat, onClick: JSValue, widget: WgramFloatingWidget) {
        self.onClick = onClick
        self.widget = widget
        let size = CGSize(width: 44.0, height: 44.0)
        super.init(frame: CGRect(origin: CGPoint(x: x, y: y), size: size))
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
        
        self.particleView.center = CGPoint(x: 22.0, y: 22.0)
        self.addSubview(self.particleView)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        self.addGestureRecognizer(tap)
        
        self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.transform = .identity
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleTap() {
        self.isUserInteractionEnabled = false
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        if let widget = self.widget {
            widget.spawnParticle("spark", Double(self.center.x), Double(self.center.y))
            widget.spawnParticle("spark", Double(self.center.x - 8), Double(self.center.y - 8))
            widget.spawnParticle("spark", Double(self.center.x + 8), Double(self.center.y - 8))
        }
        
        UIView.animate(withDuration: 0.25, animations: {
            self.transform = CGAffineTransform(rotationAngle: .pi / 2).scaledBy(x: 0.01, y: 0.01)
            self.alpha = 0
        }) { [weak self] _ in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.onClick.call(withArguments: [])
            }
            strongSelf.removeFromSuperview()
        }
    }
}

// MARK: - Frosted Glass Speech Bubble
public final class WgramSpeechBubbleView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let label = UILabel()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.cornerRadius = 14.0
        self.layer.masksToBounds = true
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.15
        self.layer.shadowRadius = 8.0
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
        self.isUserInteractionEnabled = true
        
        self.blurView.frame = self.bounds
        self.blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.blurView)
        
        self.label.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        self.label.textColor = .label
        self.label.numberOfLines = 0
        self.label.textAlignment = .center
        self.blurView.contentView.addSubview(self.label)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.bubbleTapped))
        self.addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func bubbleTapped() {
        self.hideAnimated {}
    }
    
    public func setText(_ text: String) {
        self.label.text = text
        self.setNeedsLayout()
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let maxLabelWidth: CGFloat = 200.0
        let textSize = self.label.sizeThatFits(CGSize(width: maxLabelWidth, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: max(60, textSize.width + 24.0), height: max(32, textSize.height + 16.0))
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.label.frame = self.bounds.insetBy(dx: 12.0, dy: 8.0)
    }
    
    public func showAnimated() {
        self.alpha = 0
        self.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8, options: [], animations: {
            self.alpha = 1.0
            self.transform = .identity
        })
    }
    
    public func hideAnimated(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            completion()
        }
    }
}

// Helper Hex color
private extension UIColor {
    convenience init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") {
            hex.remove(at: hex.startIndex)
        }
        if hex.count == 6 {
            hex = "FF" + hex
        }
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        let a = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
        let r = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x000000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
