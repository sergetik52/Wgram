import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class WgramChatStatsController: TelegramBaseController {
    private let context: AccountContext
    private let peerId: PeerId
    private var chatTitle: String = "Чат"
    private var currentData: WgramChatStatsData?
    private var selectedPeriod: WgramChatStatsData.Period = .allTime
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let periodSegmentedControl = UISegmentedControl(items: ["7 дней", "30 дней", "1 год", "Всё время"])
    
    private let loadingContainer = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    
    private let cardsStackView = UIStackView()
    
    public init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.title = "Статистика чата"
    }
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public static func open(context: AccountContext, peerId: PeerId, navigationController: NavigationController?) {
        let controller = WgramChatStatsController(context: context, peerId: peerId)
        navigationController?.pushViewController(controller)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let theme = presentationData.theme
        
        self.view.backgroundColor = theme.list.plainBackgroundColor
        
        // Navigation Bar Items
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(bundleImageName: "Chat/Context Menu/Statistics") ?? UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(self.sharePressed)
        )
        
        // Scroll View
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.showsVerticalScrollIndicator = true
        self.view.addSubview(self.scrollView)
        self.scrollView.addSubview(self.contentView)
        
        // Period Segmented Control
        self.periodSegmentedControl.selectedSegmentIndex = 3 // "Всё время"
        self.periodSegmentedControl.addTarget(self, action: #selector(self.periodChanged), for: .valueChanged)
        self.contentView.addSubview(self.periodSegmentedControl)
        
        // Loading View
        self.loadingContainer.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.loadingSpinner.startAnimating()
        self.loadingLabel.text = "📊 Сканирование сообщений..."
        self.loadingLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        self.loadingLabel.textColor = theme.list.itemSecondaryTextColor
        self.loadingLabel.textAlignment = .center
        
        self.loadingContainer.addSubview(self.loadingSpinner)
        self.loadingContainer.addSubview(self.loadingLabel)
        self.contentView.addSubview(self.loadingContainer)
        
        // Cards Stack View
        self.cardsStackView.axis = .vertical
        self.cardsStackView.spacing = 16.0
        self.cardsStackView.alignment = .fill
        self.cardsStackView.distribution = .fill
        self.contentView.addSubview(self.cardsStackView)
        
        // Resolve Peer Title
        let _ = (self.context.account.postbox.transaction { transaction -> String in
            return transaction.getPeer(self.peerId).flatMap({ EnginePeer($0) })?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Чат"
        }
        |> deliverOnMainQueue).start(next: { [weak self] title in
            guard let strongSelf = self else { return }
            strongSelf.chatTitle = title
        })
        
        self.loadData()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navBarHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let bounds = CGRect(origin: CGPoint(x: 0, y: navBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navBarHeight))
        
        self.scrollView.frame = bounds
        self.contentView.frame = CGRect(x: 0, y: 0, width: layout.size.width, height: self.contentView.frame.height)
        
        let horizontalInset: CGFloat = 16.0
        let contentWidth = layout.size.width - horizontalInset * 2.0
        
        self.periodSegmentedControl.frame = CGRect(x: horizontalInset, y: 12.0, width: contentWidth, height: 32.0)
        
        self.loadingContainer.frame = CGRect(x: horizontalInset, y: 70.0, width: contentWidth, height: 80.0)
        self.loadingSpinner.frame = CGRect(x: (contentWidth - 30.0) / 2.0, y: 10.0, width: 30.0, height: 30.0)
        self.loadingLabel.frame = CGRect(x: 0, y: 48.0, width: contentWidth, height: 25.0)
        
        self.cardsStackView.frame = CGRect(x: horizontalInset, y: 60.0, width: contentWidth, height: self.cardsStackView.systemLayoutSizeFitting(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)).height)
        
        self.updateContentHeight()
    }
    
    private func updateContentHeight() {
        let bottomY = self.cardsStackView.isHidden ? self.loadingContainer.frame.maxY : self.cardsStackView.frame.maxY
        let totalHeight = max(bottomY + 40.0, self.scrollView.bounds.height + 1.0)
        self.contentView.frame.size = CGSize(width: self.scrollView.bounds.width, height: totalHeight)
        self.scrollView.contentSize = self.contentView.frame.size
    }
    
    @objc private func periodChanged() {
        let index = self.periodSegmentedControl.selectedSegmentIndex
        let period = WgramChatStatsData.Period(rawValue: index) ?? .allTime
        self.selectedPeriod = period
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        self.loadData()
    }
    
    @objc private func sharePressed() {
        guard let data = self.currentData else { return }
        let image = WgramChatStatsShareCard.generateImage(data: data, chatTitle: self.chatTitle)
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        self.present(activity, animated: true, completion: nil)
    }
    
    private func loadData() {
        self.cardsStackView.isHidden = true
        self.loadingContainer.isHidden = false
        self.loadingSpinner.startAnimating()
        
        WgramChatStatsEngine.shared.scanChat(
            postbox: self.context.account.postbox,
            peerId: self.peerId,
            accountPeerId: self.context.account.peerId,
            period: self.selectedPeriod,
            progress: { [weak self] count, isFinished, data in
                guard let strongSelf = self else { return }
                
                strongSelf.loadingLabel.text = "📊 Сканировано сообщений: \(count)"
                
                if isFinished, let stats = data {
                    strongSelf.currentData = stats
                    strongSelf.loadingContainer.isHidden = true
                    strongSelf.loadingSpinner.stopAnimating()
                    strongSelf.cardsStackView.isHidden = false
                    strongSelf.renderAllCards(data: stats)
                    strongSelf.view.setNeedsLayout()
                }
            }
        )
    }
    
    // MARK: - Render All 11 Blocks
    private func renderAllCards(data: WgramChatStatsData) {
        // Clear previous cards
        for subview in self.cardsStackView.arrangedSubviews {
            self.cardsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let theme = presentationData.theme
        
        // 1. Overview Block
        self.cardsStackView.addArrangedSubview(self.createOverviewCard(data: data, theme: theme))
        
        // 2. Heatmap Block
        self.cardsStackView.addArrangedSubview(self.createHeatmapCard(data: data, theme: theme))
        
        // 3. Time of Day Block
        self.cardsStackView.addArrangedSubview(self.createTimeOfDayCard(data: data, theme: theme))
        
        // 4. Weekdays Block
        self.cardsStackView.addArrangedSubview(self.createWeekdaysCard(data: data, theme: theme))
        
        // 5. Message Types Block
        self.cardsStackView.addArrangedSubview(self.createMessageTypesCard(data: data, theme: theme))
        
        // 6. Reactions Block
        self.cardsStackView.addArrangedSubview(self.createReactionsCard(data: data, theme: theme))
        
        // 7. Words & Linguistics Block
        self.cardsStackView.addArrangedSubview(self.createWordsCard(data: data, theme: theme))
        
        // 8. Response Speed Block
        self.cardsStackView.addArrangedSubview(self.createResponseSpeedCard(data: data, theme: theme))
        
        // 9. Hall of Records Block
        self.cardsStackView.addArrangedSubview(self.createRecordsCard(data: data, theme: theme))
        
        // 10. Monthly Timeline Block
        self.cardsStackView.addArrangedSubview(self.createTimelineCard(data: data, theme: theme))
        
        // 11. On this day Block
        if !data.onThisDayItems.isEmpty {
            self.cardsStackView.addArrangedSubview(self.createOnThisDayCard(data: data, theme: theme))
        }
        
        // Share Button Card
        self.cardsStackView.addArrangedSubview(self.createShareButton(theme: theme))
        
        self.updateContentHeight()
    }
    
    // Helper for Card Base
    private func createCardContainer(theme: PresentationTheme) -> UIView {
        let card = UIView()
        card.backgroundColor = theme.list.itemBlocksBackgroundColor
        card.layer.cornerRadius = 16.0
        card.layer.masksToBounds = true
        return card
    }
    
    private func createCardHeader(title: String, icon: String, theme: PresentationTheme) -> UIView {
        let header = UIView()
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 20.0)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        titleLabel.textColor = theme.list.itemPrimaryTextColor
        
        let stack = UIStackView(arrangedSubviews: [iconLabel, titleLabel])
        stack.axis = .horizontal
        stack.spacing = 8.0
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 14.0),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8.0)
        ])
        return header
    }
    
    // MARK: - 1. Overview Card
    private func createOverviewCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Обзор «Всё время»", icon: "📊", theme: theme)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Date row
        let dateStr: String
        if let firstDate = data.firstMessageDate {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateStyle = .medium
            let years = (Double(Date().timeIntervalSince(firstDate)) / (86400.0 * 365.25) * 10).rounded() / 10
            dateStr = "\(df.string(from: firstDate)) (\(years) года назад)"
        } else {
            dateStr = "—"
        }
        
        let r1 = self.createStatRow(label: "📅 Первое сообщение", value: dateStr, theme: theme)
        let r2 = self.createStatRow(label: "💬 Всего сообщений", value: "\(data.totalMessages)", theme: theme, isBold: true)
        
        // My vs Peer bar
        let authorView = UIView()
        let authorLabel = UILabel()
        authorLabel.text = "📝 Ты: \(data.myMessagesCount)  •  Он: \(data.peerMessagesCount)"
        authorLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        authorLabel.textColor = theme.list.itemPrimaryTextColor
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let bar = UIProgressView(progressViewStyle: .default)
        let myProgress = data.totalMessages > 0 ? Float(data.myMessagesCount) / Float(data.totalMessages) : 0.5
        bar.progress = myProgress
        bar.progressTintColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        bar.trackTintColor = UIColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 0.8)
        bar.layer.cornerRadius = 3.0
        bar.clipsToBounds = true
        bar.translatesAutoresizingMaskIntoConstraints = false
        
        authorView.addSubview(authorLabel)
        authorView.addSubview(bar)
        NSLayoutConstraint.activate([
            authorLabel.topAnchor.constraint(equalTo: authorView.topAnchor),
            authorLabel.leadingAnchor.constraint(equalTo: authorView.leadingAnchor),
            authorLabel.trailingAnchor.constraint(equalTo: authorView.trailingAnchor),
            
            bar.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 6.0),
            bar.leadingAnchor.constraint(equalTo: authorView.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: authorView.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 8.0),
            bar.bottomAnchor.constraint(equalTo: authorView.bottomAnchor)
        ])
        
        let streakStr = data.longestStreakDays > 0 ? "\(data.longestStreakDays) дн без пауз" : "—"
        let r3 = self.createStatRow(label: "🔥 Серия переписки", value: streakStr, theme: theme)
        
        let silenceStr = data.longestSilenceDays > 0 ? "\(data.longestSilenceDays) дн" : "< 1 дня"
        let r4 = self.createStatRow(label: "🤐 Самая долгая тишина", value: silenceStr, theme: theme)
        
        stack.addArrangedSubview(r1)
        stack.addArrangedSubview(r2)
        stack.addArrangedSubview(authorView)
        stack.addArrangedSubview(r3)
        stack.addArrangedSubview(r4)
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 2. Heatmap Card
    private func createHeatmapCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Тепловая карта активности", icon: "🟩", theme: theme)
        
        let subtitle = UILabel()
        subtitle.text = "Как в GitHub: темнее клетка — больше сообщений в этот день"
        subtitle.font = UIFont.systemFont(ofSize: 13.0)
        subtitle.textColor = theme.list.itemSecondaryTextColor
        subtitle.numberOfLines = 2
        
        let heatmapScroll = UIScrollView()
        heatmapScroll.showsHorizontalScrollIndicator = false
        
        let gridContainer = UIView()
        let cellSize: CGFloat = 13.0
        let cellGap: CGFloat = 3.0
        let numWeeks = 30
        let totalWidth = CGFloat(numWeeks) * (cellSize + cellGap)
        let totalHeight = 7.0 * (cellSize + cellGap)
        gridContainer.frame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let maxCount = max(1, data.maxDailyCount)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        for w in 0 ..< numWeeks {
            let weekOffset = numWeeks - 1 - w
            for d in 0 ..< 7 {
                let daysAgo = weekOffset * 7 + (6 - d)
                if let cellDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) {
                    let key = df.string(from: cellDate)
                    let count = data.dailyCounts[key] ?? 0
                    
                    let cell = UIView()
                    cell.frame = CGRect(
                        x: CGFloat(w) * (cellSize + cellGap),
                        y: CGFloat(d) * (cellSize + cellGap),
                        width: cellSize,
                        height: cellSize
                    )
                    cell.layer.cornerRadius = 2.5
                    
                    if count == 0 {
                        cell.backgroundColor = theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.6)
                    } else {
                        let ratio = min(1.0, CGFloat(count) / CGFloat(maxCount))
                        let alpha = 0.35 + ratio * 0.65
                        cell.backgroundColor = UIColor(red: 1.0, green: 0.45, blue: 0.1, alpha: alpha)
                    }
                    gridContainer.addSubview(cell)
                }
            }
        }
        
        heatmapScroll.addSubview(gridContainer)
        heatmapScroll.contentSize = gridContainer.frame.size
        // Scroll to the latest weeks (right edge)
        if totalWidth > 300 {
            heatmapScroll.contentOffset = CGPoint(x: totalWidth - 280, y: 0)
        }
        
        let stack = UIStackView(arrangedSubviews: [subtitle, heatmapScroll])
        stack.axis = .vertical
        stack.spacing = 10.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        heatmapScroll.heightAnchor.constraint(equalToConstant: totalHeight + 4.0).isActive = true
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 3. Time of Day Card
    private func createTimeOfDayCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Время дня (24 часа)", icon: "⏰", theme: theme)
        
        let badge = UILabel()
        badge.text = "Вы чаще всего общаетесь с \(String(format: "%02d:00", data.peakWindowStart)) до \(String(format: "%02d:00", data.peakWindowEnd))"
        badge.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        badge.textColor = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1.0)
        badge.numberOfLines = 2
        
        let barsContainer = UIStackView()
        barsContainer.axis = .horizontal
        barsContainer.distribution = .fillEqually
        barsContainer.spacing = 2.0
        barsContainer.alignment = .bottom
        barsContainer.heightAnchor.constraint(equalToConstant: 80.0).isActive = true
        
        let maxHourCount = max(1, data.hourlyCounts.values.max() ?? 1)
        
        for h in 0 ..< 24 {
            let count = data.hourlyCounts[h] ?? 0
            let ratio = CGFloat(count) / CGFloat(maxHourCount)
            let barH = max(4.0, ratio * 70.0)
            
            let bar = UIView()
            bar.layer.cornerRadius = 2.0
            
            let isPeak = (h >= data.peakWindowStart && h <= data.peakWindowEnd)
            if isPeak {
                bar.backgroundColor = UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1.0)
            } else {
                bar.backgroundColor = theme.list.itemPrimaryTextColor.withAlphaComponent(0.2)
            }
            
            let col = UIStackView(arrangedSubviews: [bar])
            col.axis = .vertical
            col.alignment = .fill
            bar.heightAnchor.constraint(equalToConstant: barH).isActive = true
            barsContainer.addArrangedSubview(col)
        }
        
        let hoursAxis = UIStackView()
        hoursAxis.axis = .horizontal
        hoursAxis.distribution = .equalSpacing
        for labelText in ["00:00", "06:00", "12:00", "18:00", "23:00"] {
            let l = UILabel()
            l.text = labelText
            l.font = UIFont.systemFont(ofSize: 10.0)
            l.textColor = theme.list.itemSecondaryTextColor
            hoursAxis.addArrangedSubview(l)
        }
        
        let stack = UIStackView(arrangedSubviews: [badge, barsContainer, hoursAxis])
        stack.axis = .vertical
        stack.spacing = 8.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 4. Weekdays Card
    private func createWeekdaysCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Дни недели", icon: "📅", theme: theme)
        
        let names = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
        let maxCount = max(1, data.weekdayCounts.values.max() ?? 1)
        
        let topName = names[data.topWeekday]
        let badge = UILabel()
        badge.text = "🎉 \(topName) — ваш самый активный день"
        badge.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        badge.textColor = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1.0)
        
        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 6.0
        
        for i in 0 ..< 7 {
            let count = data.weekdayCounts[i] ?? 0
            let ratio = Float(count) / Float(maxCount)
            
            let row = UIView()
            row.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
            
            let nameL = UILabel()
            nameL.text = String(names[i].prefix(2))
            nameL.font = UIFont.systemFont(ofSize: 12.0, weight: i == data.topWeekday ? .bold : .regular)
            nameL.textColor = i == data.topWeekday ? theme.list.itemPrimaryTextColor : theme.list.itemSecondaryTextColor
            nameL.frame = CGRect(x: 0, y: 0, width: 26, height: 20)
            
            let pBar = UIProgressView(progressViewStyle: .default)
            pBar.progress = ratio
            pBar.layer.cornerRadius = 3.0
            pBar.clipsToBounds = true
            pBar.progressTintColor = (i == data.topWeekday) ? UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1.0) : theme.list.itemPrimaryTextColor.withAlphaComponent(0.25)
            pBar.trackTintColor = theme.list.itemBlocksBackgroundColor
            pBar.frame = CGRect(x: 32, y: 6, width: 180, height: 8)
            
            let countL = UILabel()
            countL.text = "\(count)"
            countL.font = UIFont.systemFont(ofSize: 12.0)
            countL.textColor = theme.list.itemSecondaryTextColor
            countL.textAlignment = .right
            countL.frame = CGRect(x: 220, y: 0, width: 60, height: 20)
            
            row.addSubview(nameL)
            row.addSubview(pBar)
            row.addSubview(countL)
            rowsStack.addArrangedSubview(row)
        }
        
        let stack = UIStackView(arrangedSubviews: [badge, rowsStack])
        stack.axis = .vertical
        stack.spacing = 10.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 5. Message Types Card
    private func createMessageTypesCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Типы сообщений", icon: "📦", theme: theme)
        
        let total = max(1, data.totalMessages)
        func pct(_ count: Int) -> String {
            let p = Int((Double(count) / Double(total) * 100).rounded())
            return "\(count) (\(p)%)"
        }
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        stack.addArrangedSubview(self.createStatRow(label: "💬 Текст", value: pct(data.textCount), theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "🎤 Голосовые", value: pct(data.voiceCount), theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "📹 Кружочки (видео)", value: pct(data.videoNoteCount), theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "📷 Фото", value: pct(data.photoCount), theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "🎬 Видео", value: pct(data.videoCount), theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "🎨 Стикеры", value: pct(data.stickerCount), theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "📎 Файлы", value: pct(data.fileCount), theme: theme))
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 6. Reactions Card
    private func createReactionsCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Реакции", icon: "❤️", theme: theme)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let totalL = self.createStatRow(label: "Всего поставлено реакций", value: "\(data.totalReactions)", theme: theme, isBold: true)
        let myTopStr = data.myTopReaction.flatMap { "\($0) (\(data.myTopReactionCount) раз)" } ?? "—"
        let peerTopStr = data.peerTopReaction.flatMap { "\($0) (\(data.peerTopReactionCount) раз)" } ?? "—"
        
        let r1 = self.createStatRow(label: "Твоя любимая", value: myTopStr, theme: theme)
        let r2 = self.createStatRow(label: "Любимая собеседника", value: peerTopStr, theme: theme)
        
        stack.addArrangedSubview(totalL)
        stack.addArrangedSubview(r1)
        stack.addArrangedSubview(r2)
        
        if !data.topReactions.isEmpty {
            let pillsStack = UIStackView()
            pillsStack.axis = .horizontal
            pillsStack.spacing = 8.0
            pillsStack.distribution = .fillProportionally
            
            for item in data.topReactions.prefix(5) {
                let pill = UILabel()
                pill.text = "\(item.emoji) \(item.total)"
                pill.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
                pill.backgroundColor = theme.list.itemBlocksBackgroundColor
                pill.textColor = theme.list.itemPrimaryTextColor
                pill.textAlignment = .center
                pill.layer.cornerRadius = 12.0
                pill.clipsToBounds = true
                pill.heightAnchor.constraint(equalToConstant: 28.0).isActive = true
                pillsStack.addArrangedSubview(pill)
            }
            stack.addArrangedSubview(pillsStack)
        }
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 7. Words Card
    private func createWordsCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Слова & Лингвистика", icon: "🔤", theme: theme)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let totalW = self.createStatRow(label: "Всего слов написано", value: "\(data.totalWords)", theme: theme, isBold: true)
        let myWordStr = data.myTopWord.flatMap { "«\($0)» (\(data.myTopWordCount))" } ?? "—"
        let peerWordStr = data.peerTopWord.flatMap { "«\($0)» (\(data.peerTopWordCount))" } ?? "—"
        
        let r1 = self.createStatRow(label: "Твое топ слово", value: myWordStr, theme: theme)
        let r2 = self.createStatRow(label: "Топ слово собеседника", value: peerWordStr, theme: theme)
        let r3 = self.createStatRow(label: "Твоя средняя длина сообщения", value: "\(data.myAvgWordsPerMessage) слов", theme: theme)
        let r4 = self.createStatRow(label: "Средняя длина собеседника", value: "\(data.peerAvgWordsPerMessage) слов", theme: theme)
        
        stack.addArrangedSubview(totalW)
        stack.addArrangedSubview(r1)
        stack.addArrangedSubview(r2)
        stack.addArrangedSubview(r3)
        stack.addArrangedSubview(r4)
        
        // Word Cloud Tag Container
        if !data.topWordsCloud.isEmpty {
            let tagsContainer = UIView()
            var curX: CGFloat = 0
            var curY: CGFloat = 0
            let rowH: CGFloat = 28.0
            let tagGap: CGFloat = 6.0
            let maxWidth: CGFloat = 300.0
            
            for item in data.topWordsCloud.prefix(15) {
                let tagText = "\(item.word)"
                let font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
                let strWidth = (tagText as NSString).size(withAttributes: [.font: font]).width + 16.0
                
                if curX + strWidth > maxWidth {
                    curX = 0
                    curY += rowH + tagGap
                }
                
                let tagView = UILabel(frame: CGRect(x: curX, y: curY, width: strWidth, height: rowH))
                tagView.text = tagText
                tagView.font = font
                tagView.textColor = theme.list.itemPrimaryTextColor
                tagView.backgroundColor = theme.list.itemBlocksBackgroundColor
                tagView.textAlignment = .center
                tagView.layer.cornerRadius = 14.0
                tagView.clipsToBounds = true
                tagsContainer.addSubview(tagView)
                
                curX += strWidth + tagGap
            }
            tagsContainer.heightAnchor.constraint(equalToConstant: curY + rowH).isActive = true
            stack.addArrangedSubview(tagsContainer)
        }
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 8. Response Speed Card
    private func createResponseSpeedCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Скорость ответа", icon: "⚡️", theme: theme)
        
        func formatDuration(_ sec: Double) -> String {
            if sec < 60 { return "\(Int(sec)) сек" }
            if sec < 3600 { return "\(Int(sec / 60)) мин" }
            if sec < 86400 { return "\(Int(sec / 3600)) ч \(Int((sec.truncatingRemainder(dividingBy: 3600)) / 60)) мин" }
            return "\(Int(sec / 86400)) дн \(Int((sec.truncatingRemainder(dividingBy: 86400)) / 3600)) ч"
        }
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let myTimeStr = data.myAvgResponseTimeSeconds > 0 ? formatDuration(data.myAvgResponseTimeSeconds) : "—"
        let peerTimeStr = data.peerAvgResponseTimeSeconds > 0 ? formatDuration(data.peerAvgResponseTimeSeconds) : "—"
        let fastStr = data.fastestResponseSeconds > 0 ? formatDuration(data.fastestResponseSeconds) : "—"
        let longStr = data.longestResponseSeconds > 0 ? formatDuration(data.longestResponseSeconds) : "—"
        
        stack.addArrangedSubview(self.createStatRow(label: "Ты обычно отвечаешь через", value: myTimeStr, theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "Он обычно отвечает через", value: peerTimeStr, theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "Самый быстрый ответ", value: fastStr, theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "Самый долгий ответ", value: longStr, theme: theme))
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 9. Hall of Records Card
    private func createRecordsCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Зал рекордов", icon: "🏆", theme: theme)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let df = DateFormatter()
        df.dateStyle = .medium
        
        let dayDateStr = data.longestDayDate.flatMap { df.string(from: $0) } ?? ""
        let dayVal = data.longestDayCount > 0 ? "\(data.longestDayCount) сообщ. (\(dayDateStr))" : "—"
        
        let msgDateStr = data.longestMessageDate.flatMap { df.string(from: $0) } ?? ""
        let msgVal = data.longestMessageLength > 0 ? "\(data.longestMessageLength) симв. (\(msgDateStr))" : "—"
        
        let sprintVal: String
        if data.fastest100MessagesSeconds > 0 {
            let m = Int(data.fastest100MessagesSeconds / 60)
            sprintVal = "за \(m) минут"
        } else {
            sprintVal = "—"
        }
        
        let voiceVal: String
        if data.longestVoiceSeconds > 0 {
            let m = Int(data.longestVoiceSeconds / 60)
            let s = Int(data.longestVoiceSeconds.truncatingRemainder(dividingBy: 60))
            voiceVal = String(format: "%02d:%02d мин", m, s)
        } else {
            voiceVal = "—"
        }
        
        stack.addArrangedSubview(self.createStatRow(label: "Самый активный день", value: dayVal, theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "Самое длинное сообщение", value: msgVal, theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "Спринт 100 сообщений", value: sprintVal, theme: theme))
        stack.addArrangedSubview(self.createStatRow(label: "Самый длинный войс", value: voiceVal, theme: theme))
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 10. Monthly Timeline Card
    private func createTimelineCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "Временная шкала отношений", icon: "📈", theme: theme)
        
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 8.0
        container.alignment = .bottom
        
        let maxCount = max(1, data.monthlyCounts.map { $0.count }.max() ?? 1)
        
        for item in data.monthlyCounts.suffix(24) {
            let ratio = CGFloat(item.count) / CGFloat(maxCount)
            let barH = max(6.0, ratio * 75.0)
            
            let col = UIStackView()
            col.axis = .vertical
            col.alignment = .center
            col.spacing = 4.0
            
            let bar = UIView()
            bar.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 0.85)
            bar.layer.cornerRadius = 3.0
            bar.widthAnchor.constraint(equalToConstant: 18.0).isActive = true
            bar.heightAnchor.constraint(equalToConstant: barH).isActive = true
            
            let label = UILabel()
            label.text = String(item.monthKey.suffix(2))
            label.font = UIFont.systemFont(ofSize: 10.0)
            label.textColor = theme.list.itemSecondaryTextColor
            
            col.addArrangedSubview(bar)
            col.addArrangedSubview(label)
            container.addArrangedSubview(col)
        }
        
        scroll.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scroll.topAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 100.0)
        ])
        scroll.heightAnchor.constraint(equalToConstant: 105.0).isActive = true
        
        card.addSubview(header)
        card.addSubview(scroll)
        header.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - 11. On This Day Card
    private func createOnThisDayCard(data: WgramChatStatsData, theme: PresentationTheme) -> UIView {
        let card = self.createCardContainer(theme: theme)
        let header = self.createCardHeader(title: "В этот день в прошлом", icon: "🕰", theme: theme)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        for item in data.onThisDayItems.prefix(2) {
            let memory = UIView()
            memory.backgroundColor = theme.list.itemBlocksBackgroundColor
            memory.layer.cornerRadius = 10.0
            
            let yearL = UILabel()
            yearL.text = "\(item.yearsAgo) год назад (\(item.isOutgoing ? "Ты" : "Он")):"
            yearL.font = UIFont.systemFont(ofSize: 12.0, weight: .bold)
            yearL.textColor = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1.0)
            
            let quoteL = UILabel()
            quoteL.text = "«\(item.quote)»"
            quoteL.font = UIFont.italicSystemFont(ofSize: 14.0)
            quoteL.textColor = theme.list.itemPrimaryTextColor
            quoteL.numberOfLines = 3
            
            let sub = UIStackView(arrangedSubviews: [yearL, quoteL])
            sub.axis = .vertical
            sub.spacing = 4.0
            sub.translatesAutoresizingMaskIntoConstraints = false
            
            memory.addSubview(sub)
            NSLayoutConstraint.activate([
                sub.topAnchor.constraint(equalTo: memory.topAnchor, constant: 8.0),
                sub.leadingAnchor.constraint(equalTo: memory.leadingAnchor, constant: 10.0),
                sub.trailingAnchor.constraint(equalTo: memory.trailingAnchor, constant: -10.0),
                sub.bottomAnchor.constraint(equalTo: memory.bottomAnchor, constant: -8.0)
            ])
            stack.addArrangedSubview(memory)
        }
        
        card.addSubview(header)
        card.addSubview(stack)
        header.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4.0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16.0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16.0)
        ])
        return card
    }
    
    // MARK: - Share Wrapped Button
    private func createShareButton(theme: PresentationTheme) -> UIView {
        let btn = UIButton(type: .system)
        btn.setTitle("🚀 Поделиться статистикой в Stories", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .bold)
        btn.backgroundColor = UIColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 1.0)
        btn.layer.cornerRadius = 14.0
        btn.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        btn.addTarget(self, action: #selector(self.sharePressed), for: .touchUpInside)
        return btn
    }
    
    // Helper Row
    private func createStatRow(label: String, value: String, theme: PresentationTheme, isBold: Bool = false) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing
        row.alignment = .center
        
        let l = UILabel()
        l.text = label
        l.font = UIFont.systemFont(ofSize: 14.0, weight: isBold ? .bold : .regular)
        l.textColor = theme.list.itemPrimaryTextColor
        
        let v = UILabel()
        v.text = value
        v.font = UIFont.systemFont(ofSize: 14.0, weight: isBold ? .bold : .medium)
        v.textColor = isBold ? theme.list.itemPrimaryTextColor : theme.list.itemSecondaryTextColor
        v.textAlignment = .right
        
        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        return row
    }
}
