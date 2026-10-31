import Foundation
import UIKit
import Display

public final class WgramStreakBadgeView: UIView {
    private let backgroundLayer = CAGradientLayer()
    private let label = UILabel()
    private(set) var currentStreak: Int = 0
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        
        self.backgroundLayer.colors = [
            UIColor(red: 1.0, green: 0.35, blue: 0.12, alpha: 1.0).cgColor, // Fiery Vermilion
            UIColor(red: 0.98, green: 0.16, blue: 0.35, alpha: 1.0).cgColor  // Hot Pink / Red
        ]
        self.backgroundLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.backgroundLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.backgroundLayer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        self.backgroundLayer.borderWidth = 1.0
        self.layer.addSublayer(self.backgroundLayer)
        
        self.label.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        self.label.textColor = .white
        self.label.textAlignment = .center
        self.addSubview(self.label)
        
        self.layer.shadowColor = UIColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 1.0).cgColor
        self.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        self.layer.shadowRadius = 2.5
        self.layer.shadowOpacity = 0.5
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.backgroundLayer.frame = self.bounds
        self.backgroundLayer.cornerRadius = self.bounds.height / 2.0
        self.label.frame = self.bounds.insetBy(dx: 4.0, dy: 0.0)
    }
    
    @discardableResult
    public func update(streak: Int) -> CGSize {
        self.currentStreak = streak
        guard streak > 0 else {
            self.isHidden = true
            return .zero
        }
        
        self.isHidden = false
        let text = "🔥 \(streak)"
        self.label.text = text
        
        let size = (text as NSString).boundingRect(
            with: CGSize(width: 200.0, height: 20.0),
            options: .usesLineFragmentOrigin,
            attributes: [.font: self.label.font!],
            context: nil
        ).size
        
        let width = max(30.0, ceil(size.width) + 8.0)
        let height: CGFloat = 16.0
        return CGSize(width: width, height: height)
    }
}
