import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import UniformTypeIdentifiers

private final class WgramPluginsControllerArguments {
    let context: AccountContext
    let togglePlugin: (String, Bool) -> Void
    let openPluginDetails: (WgramPlugin) -> Void
    let addPlugin: () -> Void
    
    init(
        context: AccountContext,
        togglePlugin: @escaping (String, Bool) -> Void,
        openPluginDetails: @escaping (WgramPlugin) -> Void,
        addPlugin: @escaping () -> Void
    ) {
        self.context = context
        self.togglePlugin = togglePlugin
        self.openPluginDetails = openPluginDetails
        self.addPlugin = addPlugin
    }
}

private enum WgramPluginsSection: Int32 {
    case plugins = 0
}

private enum WgramPluginsEntryStableId: Hashable {
    case header
    case plugin(String)
    case empty
    case footer
}

private enum WgramPluginsEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
    case pluginItem(Int32, PresentationTheme, PresentationStrings, WgramPlugin)
    case empty(PresentationTheme, String)
    case footer(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return WgramPluginsSection.plugins.rawValue
    }
    
    var stableId: WgramPluginsEntryStableId {
        switch self {
        case .header:
            return .header
        case let .pluginItem(_, _, _, plugin):
            return .plugin(plugin.id)
        case .empty:
            return .empty
        case .footer:
            return .footer
        }
    }
    
    static func ==(lhs: WgramPluginsEntry, rhs: WgramPluginsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(lhsTheme, lhsText), .header(rhsTheme, rhsText)):
            return lhsTheme === rhsTheme && lhsText == rhsText
        case let (.pluginItem(lhsIndex, lhsTheme, _, lhsPlugin), .pluginItem(rhsIndex, rhsTheme, _, rhsPlugin)):
            return lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsPlugin == rhsPlugin
        case let (.empty(lhsTheme, lhsText), .empty(rhsTheme, rhsText)):
            return lhsTheme === rhsTheme && lhsText == rhsText
        case let (.footer(lhsTheme, lhsText), .footer(rhsTheme, rhsText)):
            return lhsTheme === rhsTheme && lhsText == rhsText
        default:
            return false
        }
    }
    
    static func <(lhs: WgramPluginsEntry, rhs: WgramPluginsEntry) -> Bool {
        switch (lhs, rhs) {
        case (.header, _):
            return true
        case (_, .header):
            return false
        case let (.pluginItem(lhsIndex, _, _, _), .pluginItem(rhsIndex, _, _, _)):
            return lhsIndex < rhsIndex
        case (.pluginItem, .empty):
            return true
        case (.empty, .pluginItem):
            return false
        case (.pluginItem, .footer), (.empty, .footer):
            return true
        case (.footer, _):
            return false
        case (.empty, .empty):
            return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! WgramPluginsControllerArguments
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .pluginItem(_, _, _, plugin):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: PresentationResourcesSettings.stickers,
                title: plugin.name,
                value: plugin.isEnabled,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.togglePlugin(plugin.id, value)
                },
                action: {
                    arguments.openPluginDetails(plugin)
                }
            )
        case let .empty(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .footer(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct WgramPluginsState: Equatable {
    var plugins: [WgramPlugin]
}

private func wgramPluginsEntries(presentationData: PresentationData, state: WgramPluginsState) -> [WgramPluginsEntry] {
    var entries: [WgramPluginsEntry] = []
    
    entries.append(.header(presentationData.theme, "УСТАНОВЛЕННЫЕ ПЛАГИНЫ"))
    
    if state.plugins.isEmpty {
        entries.append(.empty(presentationData.theme, "Нет установленных плагинов. Нажмите «+» в правом верхнем углу, чтобы установить скрипт из буфера обмена или файла .js."))
    } else {
        var index: Int32 = 0
        for plugin in state.plugins {
            entries.append(.pluginItem(index, presentationData.theme, presentationData.strings, plugin))
            index += 1
        }
    }
    
    entries.append(.footer(presentationData.theme, "Нажмите на плагин для просмотра описания или удаления. Переключатель справа включает или выключает плагин на лету."))
    
    return entries
}

public func wgramPluginsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<WgramPluginsState>(WgramPluginsState(plugins: WgramPluginEngine.shared.installedPlugins), ignoreRepeated: true)
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    final class DocPickerDelegate: NSObject, UIDocumentPickerDelegate {
        var onPick: ((String) -> Void)?
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                self.onPick?(text)
            }
        }
    }
    
    let docDelegate = DocPickerDelegate()
    
    let arguments = WgramPluginsControllerArguments(
        context: context,
        togglePlugin: { id, enabled in
            WgramPluginEngine.shared.togglePlugin(id: id, enabled: enabled)
            statePromise.set(WgramPluginsState(plugins: WgramPluginEngine.shared.installedPlugins))
        },
        openPluginDetails: { plugin in
            let actionSheet = ActionSheetController(presentationData: context.sharedContext.currentPresentationData.with { $0 })
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "\(plugin.name) v\(plugin.version)\n\n\(plugin.description)\n\nАвтор: \(plugin.author.isEmpty ? "Не указан" : plugin.author)"),
                    ActionSheetButtonItem(title: "Удалить плагин", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        WgramPluginEngine.shared.deletePlugin(id: plugin.id)
                        statePromise.set(WgramPluginsState(plugins: WgramPluginEngine.shared.installedPlugins))
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Закрыть", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet, nil)
        },
        addPlugin: {
            let actionSheet = ActionSheetController(presentationData: context.sharedContext.currentPresentationData.with { $0 })
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "Добавить плагин"),
                    ActionSheetButtonItem(title: "Вставить из буфера обмена", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            let alert = UIAlertController(title: "Буфер пуст", message: "Скопируйте код плагина и повторите попытку.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            context.sharedContext.applicationBindings.presentNativeController(alert)
                            return
                        }
                        let res = WgramPluginEngine.shared.installPlugin(code: text)
                        if res.success, let p = res.plugin {
                            statePromise.set(WgramPluginsState(plugins: WgramPluginEngine.shared.installedPlugins))
                            let alert = UIAlertController(title: "Плагин установлен! 🎉", message: "«\(p.name)» успешно добавлен и активирован.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Отлично", style: .default))
                            context.sharedContext.applicationBindings.presentNativeController(alert)
                        } else {
                            let alert = UIAlertController(title: "Ошибка", message: res.error ?? "Не удалось установить плагин.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            context.sharedContext.applicationBindings.presentNativeController(alert)
                        }
                    }),
                    ActionSheetButtonItem(title: "Выбрать файл (.js)", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        docDelegate.onPick = { code in
                            let res = WgramPluginEngine.shared.installPlugin(code: code)
                            if res.success, let p = res.plugin {
                                statePromise.set(WgramPluginsState(plugins: WgramPluginEngine.shared.installedPlugins))
                                let alert = UIAlertController(title: "Плагин установлен! 🎉", message: "«\(p.name)» успешно добавлен и активирован.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "Отлично", style: .default))
                                context.sharedContext.applicationBindings.presentNativeController(alert)
                            } else {
                                let alert = UIAlertController(title: "Ошибка", message: res.error ?? "Не удалось установить плагин.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default))
                                context.sharedContext.applicationBindings.presentNativeController(alert)
                            }
                        }
                        let types: [UTType] = [.text, .plainText, .data, .item]
                        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
                        picker.delegate = docDelegate
                        picker.allowsMultipleSelection = false
                        context.sharedContext.applicationBindings.presentNativeController(picker)
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Отмена", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet, nil)
        }
    )
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, WgramPluginsControllerArguments)) in
        let rightButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
            arguments.addPlugin()
        })
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Плагины Wgram"),
            leftNavigationButton: nil,
            rightNavigationButton: rightButton,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: wgramPluginsEntries(presentationData: presentationData, state: state),
            style: .blocks,
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p as? ViewControllerPresentationArguments)
        }
    }
    
    let _ = NotificationCenter.default.addObserver(forName: WgramPluginEngine.pluginsChangedNotification, object: nil, queue: .main) { _ in
        statePromise.set(WgramPluginsState(plugins: WgramPluginEngine.shared.installedPlugins))
    }
    
    return controller
}
