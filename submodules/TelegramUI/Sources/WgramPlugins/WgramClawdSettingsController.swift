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

private final class WgramClawdSettingsArguments {
    let context: AccountContext
    let updateSetting: (String, Any) -> Void
    let selectColor: () -> Void
    let selectSize: () -> Void
    let selectSleep: () -> Void
    let recenterPet: () -> Void
    let spitAll: () -> Void
    let forgetBrain: () -> Void
    let editApiKey: () -> Void
    
    init(
        context: AccountContext,
        updateSetting: @escaping (String, Any) -> Void,
        selectColor: @escaping () -> Void,
        selectSize: @escaping () -> Void,
        selectSleep: @escaping () -> Void,
        recenterPet: @escaping () -> Void,
        spitAll: @escaping () -> Void,
        forgetBrain: @escaping () -> Void,
        editApiKey: @escaping () -> Void
    ) {
        self.context = context
        self.updateSetting = updateSetting
        self.selectColor = selectColor
        self.selectSize = selectSize
        self.selectSleep = selectSleep
        self.recenterPet = recenterPet
        self.spitAll = spitAll
        self.forgetBrain = forgetBrain
        self.editApiKey = editApiKey
    }
}

private enum WgramClawdSection: Int32 {
    case appearance = 0
    case behavior
    case actions
    case brain
    case ai
}

private enum WgramClawdEntry: ItemListNodeEntry {
    case header(Int32, PresentationTheme, String)
    case disclosureItem(Int32, PresentationTheme, String, String, () -> Void)
    case switchItem(Int32, PresentationTheme, String, Bool, (Bool) -> Void)
    case actionItem(Int32, PresentationTheme, String, ItemListActionKind, () -> Void)
    
    var section: ItemListSectionId {
        switch self {
        case let .header(index, _, _): return index / 100
        case let .disclosureItem(index, _, _, _, _): return index / 100
        case let .switchItem(index, _, _, _, _): return index / 100
        case let .actionItem(index, _, _, _, _): return index / 100
        }
    }
    
    var stableId: Int32 {
        switch self {
        case let .header(index, _, _): return index
        case let .disclosureItem(index, _, _, _, _): return index
        case let .switchItem(index, _, _, _, _): return index
        case let .actionItem(index, _, _, _, _): return index
        }
    }
    
    static func ==(lhs: WgramClawdEntry, rhs: WgramClawdEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(i1, t1, text1), .header(i2, t2, text2)):
            return i1 == i2 && t1 === t2 && text1 == text2
        case let (.disclosureItem(i1, t1, title1, val1, _), .disclosureItem(i2, t2, title2, val2, _)):
            return i1 == i2 && t1 === t2 && title1 == title2 && val1 == val2
        case let (.switchItem(i1, t1, title1, val1, _), .switchItem(i2, t2, title2, val2, _)):
            return i1 == i2 && t1 === t2 && title1 == title2 && val1 == val2
        case let (.actionItem(i1, t1, title1, kind1, _), .actionItem(i2, t2, title2, kind2, _)):
            return i1 == i2 && t1 === t2 && title1 == title2 && kind1 == kind2
        default:
            return false
        }
    }
    
    static func <(lhs: WgramClawdEntry, rhs: WgramClawdEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .disclosureItem(_, _, title, value, action):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: action)
        case let .switchItem(_, _, title, value, updated):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: updated)
        case let .actionItem(_, _, title, kind, action):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: kind, alignment: .natural, sectionId: self.section, style: .blocks, action: action)
        }
    }
}

public func wgramClawdSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let getPref = { (key: String, defVal: String) -> String in
        if let val = UserDefaults.standard.object(forKey: "wgram_plugin_clawd_pet_\(key)") {
            return "\(val)"
        }
        return defVal
    }
    let getBoolPref = { (key: String, defVal: Bool) -> Bool in
        if let val = UserDefaults.standard.object(forKey: "wgram_plugin_clawd_pet_\(key)") {
            if let b = val as? Bool { return b }
            if let s = val as? String { return s == "true" }
            if let n = val as? NSNumber { return n.boolValue }
        }
        return defVal
    }
    let setPref = { (key: String, val: Any) in
        if let boolVal = val as? Bool {
            UserDefaults.standard.set(boolVal ? "true" : "false", forKey: "wgram_plugin_clawd_pet_\(key)")
        } else {
            UserDefaults.standard.set("\(val)", forKey: "wgram_plugin_clawd_pet_\(key)")
        }
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: NSNotification.Name("WgramClawdSettingsUpdated"), object: nil)
        statePromise.set(Int.random(in: 1...100000))
    }
    
    let palettes = ["Claude", "Мятный", "Лавандовый", "Небесный", "Розовый", "Графит"]
    let sizes = ["Маленький", "Средний", "Большой"]
    let sleeps = ["Через 1 мин", "Через 3 мин", "Через 10 мин", "Никогда"]
    
    let arguments = WgramClawdSettingsArguments(
        context: context,
        updateSetting: { key, val in
            setPref(key, val)
        },
        selectColor: {
            let current = Int(getPref("color", "0")) ?? 0
            let actionSheet = ActionSheetController(presentationData: context.sharedContext.currentPresentationData.with { $0 })
            var items: [ActionSheetItem] = [ActionSheetTextItem(title: "Выберите окрас питомца")]
            for (idx, name) in palettes.enumerated() {
                let check = idx == current ? " ✓" : ""
                items.append(ActionSheetButtonItem(title: "\(name)\(check)", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    setPref("color", "\(idx)")
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Отмена", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet, nil)
        },
        selectSize: {
            let current = Int(getPref("size", "1")) ?? 1
            let actionSheet = ActionSheetController(presentationData: context.sharedContext.currentPresentationData.with { $0 })
            var items: [ActionSheetItem] = [ActionSheetTextItem(title: "Выберите размер питомца")]
            for (idx, name) in sizes.enumerated() {
                let check = idx == current ? " ✓" : ""
                items.append(ActionSheetButtonItem(title: "\(name)\(check)", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    setPref("size", "\(idx)")
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Отмена", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet, nil)
        },
        selectSleep: {
            let current = Int(getPref("sleep", "1")) ?? 1
            let actionSheet = ActionSheetController(presentationData: context.sharedContext.currentPresentationData.with { $0 })
            var items: [ActionSheetItem] = [ActionSheetTextItem(title: "Время до засыпания")]
            for (idx, name) in sleeps.enumerated() {
                let check = idx == current ? " ✓" : ""
                items.append(ActionSheetButtonItem(title: "\(name)\(check)", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    setPref("sleep", "\(idx)")
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Отмена", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet, nil)
        },
        recenterPet: {
            NotificationCenter.default.post(name: NSNotification.Name("WgramClawdRecenter"), object: nil)
            let alert = UIAlertController(title: "Клод вернулся! 🐾", message: "Питомец перемещён в центр экрана.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Отлично", style: .default))
            context.sharedContext.applicationBindings.presentNativeController(alert)
        },
        spitAll: {
            NotificationCenter.default.post(name: NSNotification.Name("WgramClawdSpitAll"), object: nil)
            let alert = UIAlertController(title: "Кнопки возвращены", message: "Все съеденные элементы интерфейса возвращены на свои места.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            context.sharedContext.applicationBindings.presentNativeController(alert)
        },
        forgetBrain: {
            let actionSheet = ActionSheetController(presentationData: context.sharedContext.currentPresentationData.with { $0 })
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "Вы действительно хотите сбросить долговременную память Клода?"),
                    ActionSheetButtonItem(title: "Забыть всё", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        setPref("clawd_brain", "")
                        NotificationCenter.default.post(name: NSNotification.Name("WgramClawdResetBrain"), object: nil)
                        let alert = UIAlertController(title: "Память сброшена", message: "Клод теперь считает вас новым знакомым.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        context.sharedContext.applicationBindings.presentNativeController(alert)
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Отмена", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet, nil)
        },
        editApiKey: {
            let current = getPref("ai_key", "")
            let alert = UIAlertController(title: "Google Gemini API Key", message: "Бесплатный ключ можно получить на aistudio.google.com/apikey", preferredStyle: .alert)
            alert.addTextField { tf in
                tf.placeholder = "Вставьте ваш ключ API"
                tf.text = current
                tf.isSecureTextEntry = true
            }
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
                let key = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                setPref("ai_key", key)
                setPref("ai_enabled", !key.isEmpty)
            }))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            context.sharedContext.applicationBindings.presentNativeController(alert)
        }
    )
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, WgramClawdSettingsArguments)) in
        var entries: [WgramClawdEntry] = []
        
        let colorIdx = Int(getPref("color", "0")) ?? 0
        let colorName = (colorIdx >= 0 && colorIdx < palettes.count) ? palettes[colorIdx] : "Claude"
        
        let sizeIdx = Int(getPref("size", "1")) ?? 1
        let sizeName = (sizeIdx >= 0 && sizeIdx < sizes.count) ? sizes[sizeIdx] : "Средний"
        
        let sleepIdx = Int(getPref("sleep", "1")) ?? 1
        let sleepName = (sleepIdx >= 0 && sleepIdx < sleeps.count) ? sleeps[sleepIdx] : "Через 3 мин"
        
        var index: Int32 = 0
        
        // 1. ВНЕШНИЙ ВИД (section 0)
        index = 0
        entries.append(.header(index, presentationData.theme, "ВНЕШНИЙ ВИД")); index += 1
        entries.append(.disclosureItem(index, presentationData.theme, "Окрас", colorName, {
            arguments.selectColor()
        })); index += 1
        entries.append(.disclosureItem(index, presentationData.theme, "Размер", sizeName, {
            arguments.selectSize()
        })); index += 1
        
        // 2. ПОВЕДЕНИЕ (section 1: 100+)
        index = 100
        entries.append(.header(index, presentationData.theme, "ПОВЕДЕНИЕ")); index += 1
        entries.append(.switchItem(index, presentationData.theme, "Гравитация", getBoolPref("gravity", false), { val in
            arguments.updateSetting("gravity", val)
        })); index += 1
        entries.append(.switchItem(index, presentationData.theme, "Гуляет сам", getBoolPref("wander", true), { val in
            arguments.updateSetting("wander", val)
        })); index += 1
        entries.append(.switchItem(index, presentationData.theme, "Разговаривает", getBoolPref("phrases", true), { val in
            arguments.updateSetting("phrases", val)
        })); index += 1
        entries.append(.switchItem(index, presentationData.theme, "Ест кнопки интерфейса", getBoolPref("eat", true), { val in
            arguments.updateSetting("eat", val)
        })); index += 1
        entries.append(.switchItem(index, presentationData.theme, "Оставляет кучки", getBoolPref("poop", true), { val in
            arguments.updateSetting("poop", val)
        })); index += 1
        entries.append(.switchItem(index, presentationData.theme, "Чувствует тряску", getBoolPref("shake", true), { val in
            arguments.updateSetting("shake", val)
        })); index += 1
        entries.append(.disclosureItem(index, presentationData.theme, "Засыпает", sleepName, {
            arguments.selectSleep()
        })); index += 1
        
        // 3. УПРАВЛЕНИЕ (section 2: 200+)
        index = 200
        entries.append(.header(index, presentationData.theme, "УПРАВЛЕНИЕ")); index += 1
        entries.append(.actionItem(index, presentationData.theme, "Позвать в центр экрана", .generic, {
            arguments.recenterPet()
        })); index += 1
        entries.append(.actionItem(index, presentationData.theme, "Вернуть все съеденные кнопки", .generic, {
            arguments.spitAll()
        })); index += 1
        
        // 4. ИИ-РЕПЛИКИ (section 3: 300+)
        index = 300
        entries.append(.header(index, presentationData.theme, "ИИ-РЕПЛИКИ")); index += 1
        let aiEnabled = getBoolPref("ai_enabled", false)
        entries.append(.switchItem(index, presentationData.theme, "Отвечать через ИИ", aiEnabled, { val in
            arguments.updateSetting("ai_enabled", val)
        })); index += 1
        let keyMask = getPref("ai_key", "").isEmpty ? "Не задан" : "••••••••"
        entries.append(.disclosureItem(index, presentationData.theme, "API-ключ Gemini", keyMask, {
            arguments.editApiKey()
        })); index += 1
        
        // 5. МОЗГ И ПАМЯТЬ (section 4: 400+)
        index = 400
        entries.append(.header(index, presentationData.theme, "МОЗГ И ПАМЯТЬ")); index += 1
        entries.append(.actionItem(index, presentationData.theme, "Забыть всё", .destructive, {
            arguments.forgetBrain()
        })); index += 1
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Настройки Clawd Pet"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
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
    return controller
}
