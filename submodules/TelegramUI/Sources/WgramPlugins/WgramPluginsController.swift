import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import UniformTypeIdentifiers

public final class WgramPluginsController: ViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var tableView: UITableView!
    private var emptyStateView: UIView!
    private var plugins: [WgramPlugin] = []
    
    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.title = "Плагины"
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        // Navigation buttons
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addPressed))
        
        // Table View
        self.tableView = UITableView(frame: self.view.bounds, style: .insetGrouped)
        self.tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.separatorColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        self.view.addSubview(self.tableView)
        
        // Empty State View
        self.setupEmptyStateView()
        
        // Observers
        self.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: WgramPluginEngine.pluginsChangedNotification, object: nil)
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self else { return }
            strongSelf.presentationData = presentationData
            strongSelf.view.backgroundColor = presentationData.theme.list.blocksBackgroundColor
            strongSelf.tableView.backgroundColor = presentationData.theme.list.blocksBackgroundColor
            strongSelf.tableView.separatorColor = presentationData.theme.list.itemBlocksSeparatorColor
            strongSelf.tableView.reloadData()
        })
    }
    
    private func setupEmptyStateView() {
        self.emptyStateView = UIView()
        self.emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.emptyStateView)
        
        NSLayoutConstraint.activate([
            self.emptyStateView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.emptyStateView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -30.0),
            self.emptyStateView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 32.0),
            self.emptyStateView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -32.0)
        ])
        
        let iconLabel = UILabel()
        iconLabel.text = "🧩"
        iconLabel.font = UIFont.systemFont(ofSize: 64.0)
        iconLabel.textAlignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = "Нет плагинов"
        titleLabel.font = UIFont.systemFont(ofSize: 20.0, weight: .bold)
        titleLabel.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        titleLabel.textAlignment = .center
        
        let descLabel = UILabel()
        descLabel.text = "Вы можете устанавливать JavaScript-скрипты для расширения функционала Wgram."
        descLabel.font = UIFont.systemFont(ofSize: 15.0)
        descLabel.textColor = self.presentationData.theme.list.itemSecondaryTextColor
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        
        let addBtn = UIButton(type: .system)
        addBtn.setTitle("Добавить плагин", for: .normal)
        addBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        addBtn.backgroundColor = self.presentationData.theme.list.itemAccentColor
        addBtn.setTitleColor(.white, for: .normal)
        addBtn.layer.cornerRadius = 12.0
        addBtn.addTarget(self, action: #selector(self.addPressed), for: .touchUpInside)
        addBtn.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
        
        let stack = UIStackView(arrangedSubviews: [iconLabel, titleLabel, descLabel, addBtn])
        stack.axis = .vertical
        stack.spacing = 16.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.emptyStateView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.emptyStateView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: self.emptyStateView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.emptyStateView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: self.emptyStateView.bottomAnchor)
        ])
    }
    
    @objc private func reloadData() {
        self.plugins = WgramPluginEngine.shared.installedPlugins
        self.emptyStateView.isHidden = !self.plugins.isEmpty
        self.tableView.isHidden = self.plugins.isEmpty
        self.tableView.reloadData()
    }
    
    @objc private func addPressed() {
        let alert = UIAlertController(title: "Добавить плагин", message: "Выберите источник скрипта", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Вставить из буфера обмена", style: .default, handler: { [weak self] _ in
            self?.installFromClipboard()
        }))
        
        alert.addAction(UIAlertAction(title: "Выбрать файл (.js)", style: .default, handler: { [weak self] _ in
            self?.openDocumentPicker()
        }))
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = self.navigationItem.rightBarButtonItem
        }
        self.present(alert, animated: true)
    }
    
    private func installFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let errorAlert = UIAlertController(title: "Буфер пуст", message: "Скопируйте код плагина и повторите попытку.", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(errorAlert, animated: true)
            return
        }
        
        self.tryInstallCode(text)
    }
    
    private func openDocumentPicker() {
        let types: [UTType] = [.text, .plainText, .data, .item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        self.present(picker, animated: true)
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
            self.tryInstallCode(text)
        } else {
            let alert = UIAlertController(title: "Ошибка", message: "Не удалось прочитать выбранный файл.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    private func tryInstallCode(_ code: String) {
        let result = WgramPluginEngine.shared.installPlugin(code: code)
        if result.success, let plugin = result.plugin {
            let successAlert = UIAlertController(title: "Плагин установлен! 🎉", message: "«\(plugin.name)» v\(plugin.version) успешно активирован.", preferredStyle: .alert)
            successAlert.addAction(UIAlertAction(title: "Отлично", style: .default))
            self.present(successAlert, animated: true)
            self.reloadData()
        } else {
            let errAlert = UIAlertController(title: "Ошибка установки", message: result.error ?? "Некорректный код плагина.", preferredStyle: .alert)
            errAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(errAlert, animated: true)
        }
    }
    
    // MARK: - Table View
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.plugins.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "PluginCell")
        cell.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        cell.selectionStyle = .default
        
        let plugin = self.plugins[indexPath.row]
        
        cell.textLabel?.text = "🧩 \(plugin.name)"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        cell.textLabel?.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        
        var subtitle = "v\(plugin.version)"
        if !plugin.author.isEmpty {
            subtitle += " • \(plugin.author)"
        }
        if !plugin.description.isEmpty {
            subtitle += "\n\(plugin.description)"
        }
        cell.detailTextLabel?.text = subtitle
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 13.0)
        cell.detailTextLabel?.textColor = self.presentationData.theme.list.itemSecondaryTextColor
        cell.detailTextLabel?.numberOfLines = 2
        
        let toggle = UISwitch()
        toggle.isOn = plugin.isEnabled
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(self.switchToggled(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let plugin = self.plugins[indexPath.row]
        
        let sheet = UIAlertController(title: plugin.name, message: "\(plugin.description)\n\nВерсия: \(plugin.version)\nАвтор: \(plugin.author.isEmpty ? "Не указан" : plugin.author)", preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Удалить плагин", style: .destructive, handler: { [weak self] _ in
            WgramPluginEngine.shared.deletePlugin(id: plugin.id)
            self?.reloadData()
        }))
        
        sheet.addAction(UIAlertAction(title: "Закрыть", style: .cancel))
        self.present(sheet, animated: true)
    }
    
    @objc private func switchToggled(_ sender: UISwitch) {
        let plugin = self.plugins[sender.tag]
        WgramPluginEngine.shared.togglePlugin(id: plugin.id, enabled: sender.isOn)
        
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
}

public func wgramPluginsController(context: AccountContext) -> ViewController {
    return WgramPluginsController(context: context)
}
