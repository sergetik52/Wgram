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
    let toggleGhostSend: (Bool) -> Void
    let toggleMarkReadAfterAction: (Bool) -> Void
    let toggleBypassCopyProtection: (Bool) -> Void
    let toggleConfirmVoiceSend: (Bool) -> Void
    let toggleConfirmVideoSend: (Bool) -> Void
    let toggleConfirmStickerSend: (Bool) -> Void
    let toggleAntiDelete: (Bool) -> Void
    let toggleSaveEditHistory: (Bool) -> Void
    let toggleShowPeerIdAndDc: (Bool) -> Void
    let toggleShowMessageSeconds: (Bool) -> Void
    let toggleKeepAlive: (Bool) -> Void
    
    init(
        toggleGhostMode: @escaping (Bool) -> Void,
        toggleDontReadMessages: @escaping (Bool) -> Void,
        toggleDontSendTyping: @escaping (Bool) -> Void,
        toggleDontUpdateOnline: @escaping (Bool) -> Void,
        toggleDontReadStories: @escaping (Bool) -> Void,
        toggleDontReadMedia: @escaping (Bool) -> Void,
        toggleGhostSend: @escaping (Bool) -> Void,
        toggleMarkReadAfterAction: @escaping (Bool) -> Void,
        toggleBypassCopyProtection: @escaping (Bool) -> Void,
        toggleConfirmVoiceSend: @escaping (Bool) -> Void,
        toggleConfirmVideoSend: @escaping (Bool) -> Void,
        toggleConfirmStickerSend: @escaping (Bool) -> Void,
        toggleAntiDelete: @escaping (Bool) -> Void,
        toggleSaveEditHistory: @escaping (Bool) -> Void,
        toggleShowPeerIdAndDc: @escaping (Bool) -> Void,
        toggleShowMessageSeconds: @escaping (Bool) -> Void,
        toggleKeepAlive: @escaping (Bool) -> Void
    ) {
        self.toggleGhostMode = toggleGhostMode
        self.toggleDontReadMessages = toggleDontReadMessages
        self.toggleDontSendTyping = toggleDontSendTyping
        self.toggleDontUpdateOnline = toggleDontUpdateOnline
        self.toggleDontReadStories = toggleDontReadStories
        self.toggleDontReadMedia = toggleDontReadMedia
        self.toggleGhostSend = toggleGhostSend
        self.toggleMarkReadAfterAction = toggleMarkReadAfterAction
        self.toggleBypassCopyProtection = toggleBypassCopyProtection
        self.toggleConfirmVoiceSend = toggleConfirmVoiceSend
        self.toggleConfirmVideoSend = toggleConfirmVideoSend
        self.toggleConfirmStickerSend = toggleConfirmStickerSend
        self.toggleAntiDelete = toggleAntiDelete
        self.toggleSaveEditHistory = toggleSaveEditHistory
        self.toggleShowPeerIdAndDc = toggleShowPeerIdAndDc
        self.toggleShowMessageSeconds = toggleShowMessageSeconds
        self.toggleKeepAlive = toggleKeepAlive
    }
}

private enum WgramSettingsSection: Int32 {
    case ghostMaster
    case ghostDetails
    case copyProtection
    case confirmations
    case historyAndContent
    case uiAndInfo
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
    case ghostSend(Bool, Bool)
    case markReadAfterAction(Bool, Bool)
    case detailsFooter
    
    case copyProtectionHeader
    case bypassCopyProtection(Bool)
    case copyProtectionFooter
    
    case confirmationsHeader
    case confirmVoiceSend(Bool)
    case confirmVideoSend(Bool)
    case confirmStickerSend(Bool)
    case confirmationsFooter
    
    case historyHeader
    case antiDelete(Bool)
    case saveEditHistory(Bool)
    case historyFooter
    
    case uiHeader
    case showPeerIdAndDc(Bool)
    case showMessageSeconds(Bool)
    case uiFooter
    
    case keepAliveHeader
    case keepAlive(Bool)
    case keepAliveFooter
    
    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghostMaster, .ghostFooter:
            return WgramSettingsSection.ghostMaster.rawValue
        case .detailsHeader, .dontReadMessages, .dontSendTyping, .dontUpdateOnline, .dontReadStories, .dontReadMedia, .ghostSend, .markReadAfterAction, .detailsFooter:
            return WgramSettingsSection.ghostDetails.rawValue
        case .copyProtectionHeader, .bypassCopyProtection, .copyProtectionFooter:
            return WgramSettingsSection.copyProtection.rawValue
        case .confirmationsHeader, .confirmVoiceSend, .confirmVideoSend, .confirmStickerSend, .confirmationsFooter:
            return WgramSettingsSection.confirmations.rawValue
        case .historyHeader, .antiDelete, .saveEditHistory, .historyFooter:
            return WgramSettingsSection.historyAndContent.rawValue
        case .uiHeader, .showPeerIdAndDc, .showMessageSeconds, .uiFooter:
            return WgramSettingsSection.uiAndInfo.rawValue
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
        case .ghostSend: return 9
        case .markReadAfterAction: return 10
        case .detailsFooter: return 11
        case .copyProtectionHeader: return 12
        case .bypassCopyProtection: return 13
        case .copyProtectionFooter: return 14
        case .confirmationsHeader: return 15
        case .confirmVoiceSend: return 16
        case .confirmVideoSend: return 17
        case .confirmStickerSend: return 18
        case .confirmationsFooter: return 19
        case .historyHeader: return 20
        case .antiDelete: return 21
        case .saveEditHistory: return 22
        case .historyFooter: return 23
        case .uiHeader: return 24
        case .showPeerIdAndDc: return 25
        case .showMessageSeconds: return 26
        case .uiFooter: return 27
        case .keepAliveHeader: return 28
        case .keepAlive: return 29
        case .keepAliveFooter: return 30
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
            return ItemListSwitchItem(presentationData: presentationData, title: "👻 Режим призрака", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGhostMode(value)
            })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Главный переключатель. При выключении все функции невидимости деактивируются."), sectionId: self.section)
            
        case .detailsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "НАСТРОЙКИ НЕВИДИМОСТИ", sectionId: self.section)
        case let .dontReadMessages(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: "Не читать сообщения", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadMessages(value)
            })
        case let .dontSendTyping(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: "Не отправлять «печатает...»", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontSendTyping(value)
            })
        case let .dontUpdateOnline(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: "Скрывать статус «В сети»", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontUpdateOnline(value)
            })
        case let .dontReadStories(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: "Невидимый просмотр историй", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadStories(value)
            })
        case let .dontReadMedia(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: "Не отмечать прослушивание аудио", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadMedia(value)
            })
        case let .ghostSend(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: "Ghost Send (Отправка без онлайна)", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGhostSend(value)
            })
        case let .markReadAfterAction(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: "Читать чат при ответе", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleMarkReadAfterAction(value)
            })
        case .detailsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Ghost Send отправляет сообщения как отложенные (+1 сек), благодаря чему Telegram доставляет их мгновенно, но не переводит ваш аккаунт в онлайн."), sectionId: self.section)
            
        case .copyProtectionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЗАПРЕТЫ И ОГРАНИЧЕНИЯ", sectionId: self.section)
        case let .bypassCopyProtection(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Снять запрет копирования (No-Forward)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleBypassCopyProtection(value)
            })
        case .copyProtectionFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Разрешает сохранение медиа в галерею, пересылку и копирование текста из защищённых каналов и чатов."), sectionId: self.section)
            
        case .confirmationsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЗАЩИТА ОТ СЛУЧАЙНЫХ ДЕЙСТВИЙ (EXTERAGRAM)", sectionId: self.section)
        case let .confirmVoiceSend(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Предпросмотр голосовых", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleConfirmVoiceSend(value)
            })
        case let .confirmVideoSend(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Предпросмотр кружочков", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleConfirmVideoSend(value)
            })
        case let .confirmStickerSend(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Подтверждение отправки стикеров", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleConfirmStickerSend(value)
            })
        case .confirmationsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("При отпускании кнопки записи войса или кружочка сообщение переходит в режим предпросмотра для проверки перед отправкой."), sectionId: self.section)
            
        case .historyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ИСТОРИЯ И УДАЛЁННЫЕ СООБЩЕНИЯ", sectionId: self.section)
        case let .antiDelete(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Сохранять удалённые сообщения", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleAntiDelete(value)
            })
        case let .saveEditHistory(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "История изменений сообщений", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleSaveEditHistory(value)
            })
        case .historyFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Удалённые сообщения помечаются иконкой 🗑️. При редактировании текста предыдущие версии сохраняются и доступны через меню сообщения."), sectionId: self.section)
            
        case .uiHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ИНТЕРФЕЙС И ИНФОРМАЦИЯ", sectionId: self.section)
        case let .showPeerIdAndDc(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Показывать ID и Дата-центр (DC)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleShowPeerIdAndDc(value)
            })
        case let .showMessageSeconds(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Точное время (с секундами)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleShowMessageSeconds(value)
            })
        case .uiFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("ID и DC отображаются в профиле пользователя или канала (тап копирует ID). Время сообщений выводится в формате ЧЧ:ММ:СС."), sectionId: self.section)
            
        case .keepAliveHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ФОНОВАЯ РАБОТА", sectionId: self.section)
        case let .keepAlive(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Работа в фоне (Keep-Alive)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleKeepAlive(value)
            })
        case .keepAliveFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Поддерживает постоянное соединение Telegram с сервером при сворачивании приложения."), sectionId: self.section)
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
    var ghostSend: Bool
    var markReadAfterAction: Bool
    var bypassCopyProtection: Bool
    var confirmVoiceSend: Bool
    var confirmVideoSend: Bool
    var confirmStickerSend: Bool
    var antiDelete: Bool
    var saveEditHistory: Bool
    var showPeerIdAndDc: Bool
    var showMessageSeconds: Bool
    var keepAlive: Bool
    
    init() {
        self.ghostModeEnabled = WgramSettings.ghostModeEnabled
        self.dontReadMessages = WgramSettings.dontReadMessages
        self.dontSendTyping = WgramSettings.dontSendTyping
        self.dontUpdateOnline = WgramSettings.dontUpdateOnline
        self.dontReadStories = WgramSettings.dontReadStories
        self.dontReadMedia = WgramSettings.dontReadMedia
        self.ghostSend = WgramSettings.ghostSend
        self.markReadAfterAction = WgramSettings.markReadAfterAction
        self.bypassCopyProtection = WgramSettings.bypassCopyProtection
        self.confirmVoiceSend = WgramSettings.confirmVoiceSend
        self.confirmVideoSend = WgramSettings.confirmVideoSend
        self.confirmStickerSend = WgramSettings.confirmStickerSend
        self.antiDelete = WgramSettings.antiDeleteMessages
        self.saveEditHistory = WgramSettings.saveEditHistory
        self.showPeerIdAndDc = WgramSettings.showPeerIdAndDc
        self.showMessageSeconds = WgramSettings.showMessageSeconds
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
    entries.append(.ghostSend(state.ghostSend, state.ghostModeEnabled))
    entries.append(.markReadAfterAction(state.markReadAfterAction, state.ghostModeEnabled))
    entries.append(.detailsFooter)
    
    entries.append(.copyProtectionHeader)
    entries.append(.bypassCopyProtection(state.bypassCopyProtection))
    entries.append(.copyProtectionFooter)
    
    entries.append(.confirmationsHeader)
    entries.append(.confirmVoiceSend(state.confirmVoiceSend))
    entries.append(.confirmVideoSend(state.confirmVideoSend))
    entries.append(.confirmStickerSend(state.confirmStickerSend))
    entries.append(.confirmationsFooter)
    
    entries.append(.historyHeader)
    entries.append(.antiDelete(state.antiDelete))
    entries.append(.saveEditHistory(state.saveEditHistory))
    entries.append(.historyFooter)
    
    entries.append(.uiHeader)
    entries.append(.showPeerIdAndDc(state.showPeerIdAndDc))
    entries.append(.showMessageSeconds(state.showMessageSeconds))
    entries.append(.uiFooter)
    
    entries.append(.keepAliveHeader)
    entries.append(.keepAlive(state.keepAlive))
    entries.append(.keepAliveFooter)
    
    return entries
}

public func wgramSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<WgramSettingsState>(WgramSettingsState(), ignoreRepeated: true)
    let stateValue = Atomic<WgramSettingsState>(value: WgramSettingsState())
    
    let updateState: ((inout WgramSettingsState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { state in
            var updated = state
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
                state.ghostSend = WgramSettings.ghostSend
                state.markReadAfterAction = WgramSettings.markReadAfterAction
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
        toggleGhostSend: { value in
            WgramSettings.ghostSend = value
            updateState { $0.ghostSend = value }
        },
        toggleMarkReadAfterAction: { value in
            WgramSettings.markReadAfterAction = value
            updateState { $0.markReadAfterAction = value }
        },
        toggleBypassCopyProtection: { value in
            WgramSettings.bypassCopyProtection = value
            updateState { $0.bypassCopyProtection = value }
        },
        toggleConfirmVoiceSend: { value in
            WgramSettings.confirmVoiceSend = value
            updateState { $0.confirmVoiceSend = value }
        },
        toggleConfirmVideoSend: { value in
            WgramSettings.confirmVideoSend = value
            updateState { $0.confirmVideoSend = value }
        },
        toggleConfirmStickerSend: { value in
            WgramSettings.confirmStickerSend = value
            updateState { $0.confirmStickerSend = value }
        },
        toggleAntiDelete: { value in
            WgramSettings.antiDeleteMessages = value
            updateState { $0.antiDelete = value }
        },
        toggleSaveEditHistory: { value in
            WgramSettings.saveEditHistory = value
            updateState { $0.saveEditHistory = value }
        },
        toggleShowPeerIdAndDc: { value in
            WgramSettings.showPeerIdAndDc = value
            updateState { $0.showPeerIdAndDc = value }
        },
        toggleShowMessageSeconds: { value in
            WgramSettings.showMessageSeconds = value
            updateState { $0.showMessageSeconds = value }
        },
        toggleKeepAlive: { value in
            WgramSettings.keepAliveInBackground = value
            updateState { $0.keepAlive = value }
            NotificationCenter.default.post(name: NSNotification.Name("WgramKeepAliveChanged"), object: nil)
        }
    )
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Wgram Настройки"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: wgramSettingsEntries(presentationData: presentationData, state: state), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    
    return ItemListController(context: context, state: signal)
}
