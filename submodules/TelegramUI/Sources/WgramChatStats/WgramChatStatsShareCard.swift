import Foundation
import UIKit
import TelegramCore

public final class WgramChatStatsShareCard {
    public static func generateImage(data: WgramChatStatsData, chatTitle: String) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // 1. Dark Gradient Background
            let colors = [
                UIColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1.0).cgColor,
                UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0).cgColor,
                UIColor(red: 0.18, green: 0.10, blue: 0.22, alpha: 1.0).cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.5, 1.0]) {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1080, y: 1920), options: [])
            }
            
            // 2. Ambient glowing orbs
            ctx.saveGState()
            let orbColors = [
                UIColor(red: 1.0, green: 0.35, blue: 0.15, alpha: 0.25).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            if let orbGrad = CGGradient(colorsSpace: colorSpace, colors: orbColors, locations: [0.0, 1.0]) {
                ctx.drawRadialGradient(orbGrad, startCenter: CGPoint(x: 900, y: 300), startRadius: 0, endCenter: CGPoint(x: 900, y: 300), endRadius: 500, options: [])
                ctx.drawRadialGradient(orbGrad, startCenter: CGPoint(x: 150, y: 1600), startRadius: 0, endCenter: CGPoint(x: 150, y: 1600), endRadius: 600, options: [])
            }
            ctx.restoreGState()
            
            // Text Attributes helper
            func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = alignment
                paragraphStyle.lineBreakMode = .byTruncatingTail
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle
                ]
                (text as NSString).draw(in: rect, withAttributes: attrs)
            }
            
            // 3. Header: Brand & Title
            drawText("WGRAM CHAT WRAPPED", in: CGRect(x: 80, y: 120, width: 920, height: 40), font: UIFont.systemFont(ofSize: 28, weight: .black), color: UIColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0))
            drawText(chatTitle, in: CGRect(x: 80, y: 170, width: 920, height: 90), font: UIFont.systemFont(ofSize: 64, weight: .heavy), color: .white)
            
            let periodStr = data.period.title.uppercased()
            drawText("СТАТИСТИКА ЗА \(periodStr)", in: CGRect(x: 80, y: 265, width: 920, height: 40), font: UIFont.systemFont(ofSize: 22, weight: .bold), color: UIColor(white: 0.6, alpha: 1.0))
            
            // 4. Streak Banner
            if data.currentStreakDays > 0 {
                let streakRect = CGRect(x: 80, y: 330, width: 920, height: 110)
                let streakPath = UIBezierPath(roundedRect: streakRect, cornerRadius: 28)
                UIColor(red: 1.0, green: 0.35, blue: 0.12, alpha: 0.25).setFill()
                streakPath.fill()
                UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 0.6).setStroke()
                streakPath.lineWidth = 3
                streakPath.stroke()
                
                drawText("🔥 СЕРИЯ ПЕРЕПИСКИ: \(data.currentStreakDays) ДНЕЙ ПОДРЯД", in: CGRect(x: 120, y: 365, width: 840, height: 50), font: UIFont.systemFont(ofSize: 34, weight: .heavy), color: .white, alignment: .center)
            }
            
            // Helper for glass cards
            func drawGlassCard(in rect: CGRect, title: String, value: String, subtitle: String? = nil, icon: String) {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 32)
                UIColor(white: 1.0, alpha: 0.08).setFill()
                path.fill()
                UIColor(white: 1.0, alpha: 0.15).setStroke()
                path.lineWidth = 2
                path.stroke()
                
                drawText(icon, in: CGRect(x: rect.minX + 35, y: rect.minY + 30, width: 60, height: 60), font: UIFont.systemFont(ofSize: 42), color: .white)
                drawText(title.uppercased(), in: CGRect(x: rect.minX + 105, y: rect.minY + 38, width: rect.width - 140, height: 35), font: UIFont.systemFont(ofSize: 22, weight: .bold), color: UIColor(white: 0.65, alpha: 1.0))
                drawText(value, in: CGRect(x: rect.minX + 35, y: rect.minY + 95, width: rect.width - 70, height: 75), font: UIFont.systemFont(ofSize: 56, weight: .heavy), color: .white)
                if let sub = subtitle {
                    drawText(sub, in: CGRect(x: rect.minX + 35, y: rect.minY + 175, width: rect.width - 70, height: 40), font: UIFont.systemFont(ofSize: 22, weight: .medium), color: UIColor(white: 0.7, alpha: 1.0))
                }
            }
            
            // 5. Grid of Cards
            let topY: CGFloat = data.currentStreakDays > 0 ? 470 : 360
            let cardW: CGFloat = 445
            let cardH: CGFloat = 230
            let gap: CGFloat = 30
            let leftX: CGFloat = 80
            let rightX: CGFloat = leftX + cardW + gap
            
            // Row 1
            drawGlassCard(in: CGRect(x: leftX, y: topY, width: cardW, height: cardH), title: "Всего сообщений", value: "\(data.totalMessages)", subtitle: "Ты: \(data.myMessagesCount) | Он: \(data.peerMessagesCount)", icon: "💬")
            
            var silenceStr = "\(data.longestSilenceDays) дн"
            if data.longestSilenceDays == 0 { silenceStr = "< 1 дня" }
            drawGlassCard(in: CGRect(x: rightX, y: topY, width: cardW, height: cardH), title: "Тишина (рекорд)", value: silenceStr, subtitle: "Макс. пауза без общения", icon: "🤐")
            
            // Row 2
            let row2Y = topY + cardH + gap
            let peakStr = String(format: "%02d:00 – %02d:00", data.peakWindowStart, data.peakWindowEnd)
            drawGlassCard(in: CGRect(x: leftX, y: row2Y, width: cardW, height: cardH), title: "Пиковые часы", value: peakStr, subtitle: "Самое активное время", icon: "🌙")
            
            let daysOfWeek = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
            let topDayName = (data.topWeekday >= 0 && data.topWeekday < 7) ? daysOfWeek[data.topWeekday] : "Пт"
            drawGlassCard(in: CGRect(x: rightX, y: row2Y, width: cardW, height: cardH), title: "Топ день недели", value: topDayName, subtitle: "Самый разговорчивый день", icon: "🎉")
            
            // Row 3
            let row3Y = row2Y + cardH + gap
            let myWord = data.myTopWord ?? "—"
            let peerWord = data.peerTopWord ?? "—"
            drawGlassCard(in: CGRect(x: leftX, y: row3Y, width: cardW, height: cardH), title: "Твое топ слово", value: "«\(myWord)»", subtitle: "Собеседник: «\(peerWord)»", icon: "🔤")
            
            let recDay = data.longestDayCount > 0 ? "\(data.longestDayCount) сообщ." : "—"
            drawGlassCard(in: CGRect(x: rightX, y: row3Y, width: cardW, height: cardH), title: "Рекорд дня", value: recDay, subtitle: "Максимум за 24 часа", icon: "⚡️")
            
            // 6. Wide Card: Reactions & Media
            let row4Y = row3Y + cardH + gap
            let wideRect = CGRect(x: leftX, y: row4Y, width: 920, height: 260)
            let widePath = UIBezierPath(roundedRect: wideRect, cornerRadius: 32)
            UIColor(white: 1.0, alpha: 0.08).setFill()
            widePath.fill()
            UIColor(white: 1.0, alpha: 0.15).setStroke()
            widePath.lineWidth = 2
            widePath.stroke()
            
            drawText("❤️ ТОП РЕАКЦИИ И МЕДИА", in: CGRect(x: wideRect.minX + 35, y: wideRect.minY + 30, width: wideRect.width - 70, height: 35), font: UIFont.systemFont(ofSize: 22, weight: .bold), color: UIColor(white: 0.65, alpha: 1.0))
            
            var emojiRow = ""
            for r in data.topReactions.prefix(5) {
                emojiRow += "\(r.emoji) \(r.total)   "
            }
            if emojiRow.isEmpty { emojiRow = "Пока нет реакций" }
            drawText(emojiRow, in: CGRect(x: wideRect.minX + 35, y: wideRect.minY + 80, width: wideRect.width - 70, height: 60), font: UIFont.systemFont(ofSize: 42, weight: .bold), color: .white)
            
            let mediaSummary = "Текст: \(data.textCount)  •  Голосовые: \(data.voiceCount)  •  Кружочки: \(data.videoNoteCount)  •  Фото/Видео: \(data.photoCount + data.videoCount)"
            drawText(mediaSummary, in: CGRect(x: wideRect.minX + 35, y: wideRect.minY + 160, width: wideRect.width - 70, height: 70), font: UIFont.systemFont(ofSize: 26, weight: .medium), color: UIColor(white: 0.8, alpha: 1.0))
            
            // 7. Footer
            let footerY: CGFloat = 1790
            drawText("Wgram iOS • Персональная аналитика чата", in: CGRect(x: 80, y: footerY, width: 920, height: 40), font: UIFont.systemFont(ofSize: 24, weight: .semibold), color: UIColor(white: 0.5, alpha: 1.0), alignment: .center)
        }
    }
}
