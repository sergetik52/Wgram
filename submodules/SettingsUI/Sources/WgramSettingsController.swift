import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class WgramSettingsControllerArguments {
    let toggleGhostMode: (Bool) -> Void
    let toggleDontReadMessages: (Bool) -> Void
    let toggleDontSendTyping: (Bool) -> Void
    let toggleDontUpdateOnline: (Bool) -> Void
    let toggleDontReadStories: (Bool) -> Void
    let toggleDontReadMedia: (Bool) -> Void
    let toggleKeepAlive: (Bool) -> Void
    
    init(
        toggleGhostMode: @escaping (Bool) -> Void,
        toggleDontReadMessages: @escaping (Bool) -> Void,
        toggleDontSendTyping: @escaping (Bool) -> Void,
        toggleDontUpdateOnline: @escaping (Bool) -> Void,
        toggleDontReadStories: @escaping (Bool) -> Void,
        toggleDontReadMedia: @escaping (Bool) -> Void,
        toggleKeepAlive: @escaping (Bool) -> Void
    ) {
        self.toggleGhostMode = toggleGhostMode
        self.toggleDontReadMessages = toggleDontReadMessages
        self.toggleDontSendTyping = toggleDontSendTyping
        self.toggleDontUpdateOnline = toggleDontUpdateOnline
        self.toggleDontReadStories = toggleDontReadStories
        self.toggleDontReadMedia = toggleDontReadMedia
        self.toggleKeepAlive = toggleKeepAlive
    }
}

private enum WgramSettingsSection: Int32 {
    case ghostMaster
    case ghostDetails
    case keepAlive
}

private enum WgramSettingsEntry: ItemListNodeEntry {
    case ghostHeader
    case ghostMaster(Bool)
    case ghostFooter
    
    case detailsHeader
    case dontReadMessages(Bool, Bool)
    case dontSendTyping(Bool, Bool)
    case dontUpdateOnline(Bool, Bool)
    case dontReadStories(Bool, Bool)
    case dontReadMedia(Bool, Bool)
    case detailsFooter
    
    case keepAliveHeader
    case keepAlive(Bool)
    case keepAliveFooter
    
    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghostMaster, .ghostFooter:
            return WgramSettingsSection.ghostMaster.rawValue
        case .detailsHeader, .dontReadMessages, .dontSendTyping, .dontUpdateOnline, .dontReadStories, .dontReadMedia, .detailsFooter:
            return WgramSettingsSection.ghostDetails.rawValue
        case .keepAliveHeader, .keepAlive, .keepAliveFooter:
            return WgramSettingsSection.keepAlive.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .ghostHeader: return 0
        case .ghostMaster: return 1
        case .ghostFooter: return 2
        case .detailsHeader: return 3
        case .dontReadMessages: return 4
        case .dontSendTyping: return 5
        case .dontUpdateOnline: return 6
        case .dontReadStories: return 7
        case .dontReadMedia: return 8
        case .detailsFooter: return 9
        case .keepAliveHeader: return 10
        case .keepAlive: return 11
        case .keepAliveFooter: return 12
        }
    }
    
    static func <(lhs: WgramSettingsEntry, rhs: WgramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! WgramSettingsControllerArguments
        switch self {
        case .ghostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "РЕЖИМ ПРИЗРАКА", sectionId: self.section)
        case let .ghostMaster(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Режим призрака", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGhostMode(value)
            })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Включает полную невидимость: скрывает прочтение сообщений, набор текста, онлайн, просмотр историй и прослушивание аудио."), sectionId: self.section)
            
        case .detailsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ДЕТАЛЬНАЯ НАСТРОЙКА", sectionId: self.section)
        case let .dontReadMessages(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не читать сообщения", text: "Собеседник видит одну галочку", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadMessages(value)
            })
        case let .dontSendTyping(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скрывать набор текста", text: "Собеседник не видит «печатает...»", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontSendTyping(value)
            })
        case let .dontUpdateOnline(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скрывать статус «В сети»", text: "Не обновляет время последнего визита", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontUpdateOnline(value)
            })
        case let .dontReadStories(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Анонимные истории", text: "Вас не будет в списке просмотров", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadStories(value)
            })
        case let .dontReadMedia(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скрывать прослушивание аудио", text: "Зеленая точка у собеседника не гаснет", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadMedia(value)
            })
        case .detailsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Вы можете индивидуально включить или отключить отдельные функции режима призрака."), sectionId: self.section)
            
        case .keepAliveHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ФОНОВАЯ РАБОТА", sectionId: self.section)
        case let .keepAlive(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Работа в фоне 24/7", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleKeepAlive(value)
            })
        case .keepAliveFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Предотвращает усыпление Wgram при блокировке экрана. Позволяет мгновенно перехватывать удаленные сообщения даже когда телефон в кармане."), sectionId: self.section)
        }
    }
}

private struct WgramSettingsState: Equatable {
    var ghostModeEnabled: Bool
    var dontReadMessages: Bool
    var dontSendTyping: Bool
    var dontUpdateOnline: Bool
    var dontReadStories: Bool
    var dontReadMedia: Bool
    var keepAlive: Bool
    
    init() {
        self.ghostModeEnabled = WgramSettings.ghostModeEnabled
        self.dontReadMessages = WgramSettings.dontReadMessages
        self.dontSendTyping = WgramSettings.dontSendTyping
        self.dontUpdateOnline = WgramSettings.dontUpdateOnline
        self.dontReadStories = WgramSettings.dontReadStories
        self.dontReadMedia = WgramSettings.dontReadMedia
        self.keepAlive = WgramSettings.keepAliveInBackground
    }
}

private func wgramSettingsEntries(presentationData: PresentationData, state: WgramSettingsState) -> [WgramSettingsEntry] {
    var entries: [WgramSettingsEntry] = []
    
    entries.append(.ghostHeader)
    entries.append(.ghostMaster(state.ghostModeEnabled))
    entries.append(.ghostFooter)
    
    entries.append(.detailsHeader)
    entries.append(.dontReadMessages(state.dontReadMessages, state.ghostModeEnabled))
    entries.append(.dontSendTyping(state.dontSendTyping, state.ghostModeEnabled))
    entries.append(.dontUpdateOnline(state.dontUpdateOnline, state.ghostModeEnabled))
    entries.append(.dontReadStories(state.dontReadStories, state.ghostModeEnabled))
    entries.append(.dontReadMedia(state.dontReadMedia, state.ghostModeEnabled))
    entries.append(.detailsFooter)
    
    entries.append(.keepAliveHeader)
    entries.append(.keepAlive(state.keepAlive))
    entries.append(.keepAliveFooter)
    
    return entries
}

public func wgramSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<WgramSettingsState>(WgramSettingsState(), ignoreRepeated: true)
    let stateValue = Atomic<WgramSettingsState>(value: WgramSettingsState())
    
    let updateState: ((inout WgramSettingsState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            var updated = current
            f(&updated)
            return updated
        })
    }
    
    let arguments = WgramSettingsControllerArguments(
        toggleGhostMode: { value in
            WgramSettings.ghostModeEnabled = value
            updateState { state in
                state.ghostModeEnabled = value
                state.dontReadMessages = WgramSettings.dontReadMessages
                state.dontSendTyping = WgramSettings.dontSendTyping
                state.dontUpdateOnline = WgramSettings.dontUpdateOnline
                state.dontReadStories = WgramSettings.dontReadStories
                state.dontReadMedia = WgramSettings.dontReadMedia
            }
        },
        toggleDontReadMessages: { value in
            WgramSettings.dontReadMessages = value
            updateState { $0.dontReadMessages = value }
        },
        toggleDontSendTyping: { value in
            WgramSettings.dontSendTyping = value
            updateState { $0.dontSendTyping = value }
        },
        toggleDontUpdateOnline: { value in
            WgramSettings.dontUpdateOnline = value
            updateState { $0.dontUpdateOnline = value }
        },
        toggleDontReadStories: { value in
            WgramSettings.dontReadStories = value
            updateState { $0.dontReadStories = value }
        },
        toggleDontReadMedia: { value in
            WgramSettings.dontReadMedia = value
            updateState { $0.dontReadMedia = value }
        },
        toggleKeepAlive: { value in
            WgramSettings.keepAliveInBackground = value
            NotificationCenter.default.post(name: NSNotification.Name("WgramUpdateKeepAlive"), object: nil)
            updateState { $0.keepAlive = value }
        }
    )
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Настройки Wgram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: wgramSettingsEntries(
            presentationData: presentationData,
            state: state
        ), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    
    return ItemListController(context: context, state: signal)
}
