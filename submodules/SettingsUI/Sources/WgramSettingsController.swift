import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import CoreLocation

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
    let toggleBypassViewOnce: (Bool) -> Void
    let toggleHideSponsoredMessages: (Bool) -> Void
    
    let toggleConfirmVoiceSend: (Bool) -> Void
    let toggleConfirmVideoSend: (Bool) -> Void
    let toggleConfirmStickerSend: (Bool) -> Void
    
    let toggleAntiDelete: (Bool) -> Void
    let toggleSaveEditHistory: (Bool) -> Void
    let openHistoryExceptions: () -> Void
    
    let toggleLogEditsAndDeletesToChat: (Bool) -> Void
    let selectLogChatTarget: () -> Void
    let toggleLogPrivateChats: (Bool) -> Void
    let toggleLogGroups: (Bool) -> Void
    let toggleLogChannels: (Bool) -> Void
    let toggleLogDeletedMessages: (Bool) -> Void
    let toggleLogEditedMessages: (Bool) -> Void
    let toggleLogIncludeChatInfo: (Bool) -> Void
    
    let toggleShowPeerIdAndDc: (Bool) -> Void
    let toggleShowChatMessageCount: (Bool) -> Void
    let toggleShowMessageSeconds: (Bool) -> Void
    let selectVideoNoteCamera: () -> Void
    let selectVideoNoteDuration: () -> Void
    let toggleSplitLongVideoNotes: (Bool) -> Void
    
    let toggleKeepAlive: (Bool) -> Void
    let triggerTestNotification: () -> Void
    
    let toggleTgWsProxy: (Bool) -> Void
    let selectTgWsDomain: () -> Void
    let toggleTgWsAutoFallback: (Bool) -> Void
    let toggleTgWsCallsBridge: (Bool) -> Void
    let requestLocationPermission: () -> Void
    let openSystemSettings: () -> Void
    
    let toggleLocalPremium: (Bool) -> Void
    let toggleLocalPremiumCustomEmoji: (Bool) -> Void
    
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
        toggleBypassViewOnce: @escaping (Bool) -> Void,
        toggleHideSponsoredMessages: @escaping (Bool) -> Void,
        toggleConfirmVoiceSend: @escaping (Bool) -> Void,
        toggleConfirmVideoSend: @escaping (Bool) -> Void,
        toggleConfirmStickerSend: @escaping (Bool) -> Void,
        toggleAntiDelete: @escaping (Bool) -> Void,
        toggleSaveEditHistory: @escaping (Bool) -> Void,
        openHistoryExceptions: @escaping () -> Void,
        toggleLogEditsAndDeletesToChat: @escaping (Bool) -> Void,
        selectLogChatTarget: @escaping () -> Void,
        toggleLogPrivateChats: @escaping (Bool) -> Void,
        toggleLogGroups: @escaping (Bool) -> Void,
        toggleLogChannels: @escaping (Bool) -> Void,
        toggleLogDeletedMessages: @escaping (Bool) -> Void,
        toggleLogEditedMessages: @escaping (Bool) -> Void,
        toggleLogIncludeChatInfo: @escaping (Bool) -> Void,
        toggleShowPeerIdAndDc: @escaping (Bool) -> Void,
        toggleShowChatMessageCount: @escaping (Bool) -> Void,
        toggleShowMessageSeconds: @escaping (Bool) -> Void,
        selectVideoNoteCamera: @escaping () -> Void,
        selectVideoNoteDuration: @escaping () -> Void,
        toggleSplitLongVideoNotes: @escaping (Bool) -> Void,
        toggleKeepAlive: @escaping (Bool) -> Void,
        triggerTestNotification: @escaping () -> Void,
        toggleTgWsProxy: @escaping (Bool) -> Void,
        selectTgWsDomain: @escaping () -> Void,
        toggleTgWsAutoFallback: @escaping (Bool) -> Void,
        toggleTgWsCallsBridge: @escaping (Bool) -> Void,
        requestLocationPermission: @escaping () -> Void,
        openSystemSettings: @escaping () -> Void,
        toggleLocalPremium: @escaping (Bool) -> Void,
        toggleLocalPremiumCustomEmoji: @escaping (Bool) -> Void
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
        self.toggleBypassViewOnce = toggleBypassViewOnce
        self.toggleHideSponsoredMessages = toggleHideSponsoredMessages
        self.toggleConfirmVoiceSend = toggleConfirmVoiceSend
        self.toggleConfirmVideoSend = toggleConfirmVideoSend
        self.toggleConfirmStickerSend = toggleConfirmStickerSend
        self.toggleAntiDelete = toggleAntiDelete
        self.toggleSaveEditHistory = toggleSaveEditHistory
        self.openHistoryExceptions = openHistoryExceptions
        self.toggleLogEditsAndDeletesToChat = toggleLogEditsAndDeletesToChat
        self.selectLogChatTarget = selectLogChatTarget
        self.toggleLogPrivateChats = toggleLogPrivateChats
        self.toggleLogGroups = toggleLogGroups
        self.toggleLogChannels = toggleLogChannels
        self.toggleLogDeletedMessages = toggleLogDeletedMessages
        self.toggleLogEditedMessages = toggleLogEditedMessages
        self.toggleLogIncludeChatInfo = toggleLogIncludeChatInfo
        self.toggleShowPeerIdAndDc = toggleShowPeerIdAndDc
        self.toggleShowChatMessageCount = toggleShowChatMessageCount
        self.toggleShowMessageSeconds = toggleShowMessageSeconds
        self.selectVideoNoteCamera = selectVideoNoteCamera
        self.selectVideoNoteDuration = selectVideoNoteDuration
        self.toggleSplitLongVideoNotes = toggleSplitLongVideoNotes
        self.toggleKeepAlive = toggleKeepAlive
        self.triggerTestNotification = triggerTestNotification
        self.toggleTgWsProxy = toggleTgWsProxy
        self.selectTgWsDomain = selectTgWsDomain
        self.toggleTgWsAutoFallback = toggleTgWsAutoFallback
        self.toggleTgWsCallsBridge = toggleTgWsCallsBridge
        self.requestLocationPermission = requestLocationPermission
        self.openSystemSettings = openSystemSettings
        self.toggleLocalPremium = toggleLocalPremium
        self.toggleLocalPremiumCustomEmoji = toggleLocalPremiumCustomEmoji
    }
}

private enum WgramSettingsSection: Int32 {
    case ghostMaster
    case ghostDetails
    case localPremium
    case tgWsProxy
    case copyProtection
    case confirmations
    case historyAndAntiDelete
    case messageLogging
    case uiAndInfo
    case keepAlive
}

private enum WgramSettingsEntry: ItemListNodeEntry {
    case ghostHeader
    case ghostMaster(Bool)
    case ghostFooter
    
    case detailsHeader
    case dontReadMessages(Bool)
    case dontSendTyping(Bool)
    case dontUpdateOnline(Bool)
    case dontReadStories(Bool)
    case dontReadMedia(Bool)
    case ghostSend(Bool)
    case markReadAfterAction(Bool)
    case detailsFooter
    
    case localPremiumHeader
    case localPremiumMaster(Bool)
    case localPremiumCustomEmoji(Bool)
    case localPremiumFooter

    case tgWsProxyHeader
    case tgWsProxyMaster(Bool)
    case tgWsDomainSelector(String)
    case tgWsAutoFallback(Bool)
    case tgWsCallsBridge(Bool)
    case tgWsProxyFooter
    
    case copyProtectionHeader
    case bypassCopyProtection(Bool)
    case bypassViewOnce(Bool)
    case hideSponsoredMessages(Bool)
    case copyProtectionFooter
    
    case confirmationsHeader
    case confirmVoiceSend(Bool)
    case confirmVideoSend(Bool)
    case confirmStickerSend(Bool)
    case confirmationsFooter
    
    case historyHeader
    case antiDelete(Bool)
    case saveEditHistory(Bool)
    case antiDeleteExceptions(Int)
    case historyFooter
    
    case loggingHeader
    case logMaster(Bool)
    case logChatTarget(String)
    case logPrivateChats(Bool)
    case logGroups(Bool)
    case logChannels(Bool)
    case logDeletedMessages(Bool)
    case logEditedMessages(Bool)
    case logIncludeChatInfo(Bool)
    case loggingFooter
    
    case uiHeader
    case showPeerIdAndDc(Bool)
    case showChatMessageCount(Bool)
    case showMessageSeconds(Bool)
    case videoNoteCamera(Bool)
    case videoNoteDuration(Double)
    case splitLongVideoNotes(Bool)
    case uiFooter
    
    case keepAliveHeader
    case keepAlive(Bool)
    case keepAliveLocationStatus
    case keepAliveTestNotification
    case keepAliveFooter
    
    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghostMaster, .ghostFooter:
            return WgramSettingsSection.ghostMaster.rawValue
        case .detailsHeader, .dontReadMessages, .dontSendTyping, .dontUpdateOnline, .dontReadStories, .dontReadMedia, .ghostSend, .markReadAfterAction, .detailsFooter:
            return WgramSettingsSection.ghostDetails.rawValue
        case .localPremiumHeader, .localPremiumMaster, .localPremiumCustomEmoji, .localPremiumFooter:
            return WgramSettingsSection.localPremium.rawValue
        case .tgWsProxyHeader, .tgWsProxyMaster, .tgWsDomainSelector, .tgWsAutoFallback, .tgWsCallsBridge, .tgWsProxyFooter:
            return WgramSettingsSection.tgWsProxy.rawValue
        case .copyProtectionHeader, .bypassCopyProtection, .bypassViewOnce, .hideSponsoredMessages, .copyProtectionFooter:
            return WgramSettingsSection.copyProtection.rawValue
        case .confirmationsHeader, .confirmVoiceSend, .confirmVideoSend, .confirmStickerSend, .confirmationsFooter:
            return WgramSettingsSection.confirmations.rawValue
        case .historyHeader, .antiDelete, .saveEditHistory, .antiDeleteExceptions, .historyFooter:
            return WgramSettingsSection.historyAndAntiDelete.rawValue
        case .loggingHeader, .logMaster, .logChatTarget, .logPrivateChats, .logGroups, .logChannels, .logDeletedMessages, .logEditedMessages, .logIncludeChatInfo, .loggingFooter:
            return WgramSettingsSection.messageLogging.rawValue
        case .uiHeader, .showPeerIdAndDc, .showChatMessageCount, .showMessageSeconds, .videoNoteCamera, .videoNoteDuration, .splitLongVideoNotes, .uiFooter:
            return WgramSettingsSection.uiAndInfo.rawValue
        case .keepAliveHeader, .keepAlive, .keepAliveLocationStatus, .keepAliveTestNotification, .keepAliveFooter:
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
        case .localPremiumHeader: return 12
        case .localPremiumMaster: return 13
        case .localPremiumCustomEmoji: return 14
        case .localPremiumFooter: return 15
        case .tgWsProxyHeader: return 16
        case .tgWsProxyMaster: return 17
        case .tgWsDomainSelector: return 18
        case .tgWsAutoFallback: return 19
        case .tgWsCallsBridge: return 20
        case .tgWsProxyFooter: return 21
        case .copyProtectionHeader: return 22
        case .bypassCopyProtection: return 23
        case .bypassViewOnce: return 24
        case .hideSponsoredMessages: return 25
        case .copyProtectionFooter: return 26
        case .confirmationsHeader: return 27
        case .confirmVoiceSend: return 28
        case .confirmVideoSend: return 29
        case .confirmStickerSend: return 30
        case .confirmationsFooter: return 31
        case .historyHeader: return 32
        case .antiDelete: return 33
        case .saveEditHistory: return 34
        case .antiDeleteExceptions: return 35
        case .historyFooter: return 36
        case .loggingHeader: return 37
        case .logMaster: return 38
        case .logChatTarget: return 39
        case .logPrivateChats: return 40
        case .logGroups: return 41
        case .logChannels: return 42
        case .logDeletedMessages: return 43
        case .logEditedMessages: return 44
        case .logIncludeChatInfo: return 45
        case .loggingFooter: return 46
        case .uiHeader: return 47
        case .showPeerIdAndDc: return 48
        case .showChatMessageCount: return 49
        case .showMessageSeconds: return 50
        case .videoNoteCamera: return 51
        case .videoNoteDuration: return 52
        case .splitLongVideoNotes: return 53
        case .uiFooter: return 54
        case .keepAliveHeader: return 55
        case .keepAlive: return 56
        case .keepAliveLocationStatus: return 57
        case .keepAliveTestNotification: return 58
        case .keepAliveFooter: return 59
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
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.security, title: "Режим призрака", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGhostMode(value)
            })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Главный переключатель. При включении скрывает присутствие в сети и прочтение входящих сообщений."), sectionId: self.section)
            
        case .detailsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "НАСТРОЙКИ НЕВИДИМОСТИ", sectionId: self.section)
        case let .dontReadMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.savedMessages, title: "Не читать сообщения", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadMessages(value)
            })
        case let .dontSendTyping(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.emoji, title: "Не отправлять «печатает...»", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontSendTyping(value)
            })
        case let .dontUpdateOnline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.activeSessions, title: "Скрывать статус «В сети»", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontUpdateOnline(value)
            })
        case let .dontReadStories(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.stories, title: "Невидимый просмотр историй", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadStories(value)
            })
        case let .dontReadMedia(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.videos, title: "Не отмечать прослушивание аудио", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleDontReadMedia(value)
            })
        case let .ghostSend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.timer, title: "Ghost Send (Отправка без онлайна)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGhostSend(value)
            })
        case let .markReadAfterAction(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.recentCalls, title: "Читать чат при ответе", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleMarkReadAfterAction(value)
            })
        case .detailsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Ghost Send отправляет сообщения как отложенные (+1 сек), благодаря чему Telegram доставляет их мгновенно, но не переводит ваш аккаунт в онлайн."), sectionId: self.section)
            
        case .localPremiumHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЛОКАЛЬНЫЙ TELEGRAM PREMIUM", sectionId: self.section)
        case let .localPremiumMaster(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.premium, title: "Локальный Premium", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLocalPremium(value)
            })
        case let .localPremiumCustomEmoji(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.stickers, title: "AyuGram кастомные эмодзи", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLocalPremiumCustomEmoji(value)
            })
        case .localPremiumFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Локальный Premium включает премиум-статус для вашего аккаунта внутри клиента: звёздочка у имени, выбор премиум-иконок приложения, расширенные лимиты и эффекты стикеров.\n\nРежим эмодзи AyuGram позволяет отправлять и полноценно видеть кастомные анимированные эмодзи от пользователей AyuGram и Wgram без покупки платной подписки."), sectionId: self.section)
            
        case .tgWsProxyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "TG WS ПРОКСИ (ОБХОД БЛОКИРОВОК)", sectionId: self.section)
        case let .tgWsProxyMaster(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.proxy, title: "Включить TG WS Прокси", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleTgWsProxy(value)
            })
        case let .tgWsDomainSelector(domain):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.dataAndStorage, title: "Зеркало / Сервер", label: domain, sectionId: self.section, style: .blocks, action: {
                arguments.selectTgWsDomain()
            })
        case let .tgWsAutoFallback(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.cellular, title: "Авто-переключение зеркал", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleTgWsAutoFallback(value)
            })
        case let .tgWsCallsBridge(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.calls, title: "Звонки через ТГВС", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleTgWsCallsBridge(value)
            })
        case .tgWsProxyFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Позволяет Telegram и звонкам работать без VPN через WebSocket поверх Cloudflare TLS. Трафик маскируется под обычный веб-сайт и не блокируется провайдерами."), sectionId: self.section)
            
        case .copyProtectionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЗАПРЕТЫ И ОГРАНИЧЕНИЯ", sectionId: self.section)
        case let .bypassCopyProtection(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.lockOrange, title: "Снять запрет копирования (No-Forward)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleBypassCopyProtection(value)
            })
        case let .bypassViewOnce(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.photos, title: "Обход таймера (View-Once)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleBypassViewOnce(value)
            })
        case let .hideSponsoredMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.block, title: "Скрывать рекламу (No Ads)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleHideSponsoredMessages(value)
            })
        case .copyProtectionFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Разрешает сохранение медиа в галерею, пересылку и копирование текста из защищённых каналов, сохраняет одноразовые фото/видео и скрывает рекламу Telegram."), sectionId: self.section)
            
        case .confirmationsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОДТВЕРЖДЕНИЕ ОТПРАВКИ", sectionId: self.section)
        case let .confirmVoiceSend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.notifications, title: "Предпросмотр голосовых", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleConfirmVoiceSend(value)
            })
        case let .confirmVideoSend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.videosBlue, title: "Предпросмотр кружочков", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleConfirmVideoSend(value)
            })
        case let .confirmStickerSend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.stickers, title: "Подтверждение стикеров", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleConfirmStickerSend(value)
            })
        case .confirmationsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("При отпускании кнопки записи войса или кружочка сообщение переходит в режим предпросмотра для проверки перед отправкой."), sectionId: self.section)
            
        case .historyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ИСТОРИЯ И АНТИ-УДАЛЕНИЕ", sectionId: self.section)
        case let .antiDelete(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.chatFolders, title: "Сохранять удалённые сообщения", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleAntiDelete(value)
            })
        case let .saveEditHistory(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.clock, title: "История изменений сообщений", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleSaveEditHistory(value)
            })
        case let .antiDeleteExceptions(count):
            let label = count == 0 ? "Нет" : "\(count)"
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.block, title: "Исключения", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openHistoryExceptions()
            })
        case .historyFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Удалённые собеседником сообщения помечаются иконкой 🗑️. При редактировании текста предыдущие версии сохраняются. В чатах-исключениях сохранение удалённых и изменённых сообщений отключается."), sectionId: self.section)
            
        case .loggingHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЛОГИРОВАНИЕ СООБЩЕНИЙ В ЧАТ", sectionId: self.section)
        case let .logMaster(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.savedMessages, title: "Логировать в отдельный чат", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLogEditsAndDeletesToChat(value)
            })
        case let .logChatTarget(target):
            let label = target.isEmpty ? "Избранное" : target
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.chatFolders, title: "Чат для логов", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.selectLogChatTarget()
            })
        case let .logPrivateChats(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.privateChats, title: "Личные чаты", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLogPrivateChats(value)
            })
        case let .logGroups(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.groups, title: "Группы и супергруппы", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLogGroups(value)
            })
        case let .logChannels(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.channels, title: "Каналы (ТГК)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLogChannels(value)
            })
        case let .logDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.block, title: "Удалённые сообщения", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLogDeletedMessages(value)
            })
        case let .logEditedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.clock, title: "Изменённые сообщения", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLogEditedMessages(value)
            })
        case let .logIncludeChatInfo(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.devices, title: "Указывать название чата", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleLogIncludeChatInfo(value)
            })
        case .loggingFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Логирование отправляет копии удалённых и изменённых сообщений с цитатами оригинального текста. Отправка выполняется в скрытом режиме (Ghost) и никогда не выдает ваш онлайн."), sectionId: self.section)
            
        case .uiHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ИНТЕРФЕЙС И ИНФОРМАЦИЯ", sectionId: self.section)
        case let .showPeerIdAndDc(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.passkeys, title: "Показывать ID и Дата-центр (DC)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleShowPeerIdAndDc(value)
            })
        case let .showChatMessageCount(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.privateChats, title: "Количество сообщений в чате", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleShowChatMessageCount(value)
            })
        case let .showMessageSeconds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.clock, title: "Точное время (с секундами)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleShowMessageSeconds(value)
            })
        case let .videoNoteCamera(isBack):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.devices, title: "Камера для кружочков", label: isBack ? "Задняя (основная)" : "Фронтальная", sectionId: self.section, style: .blocks, action: {
                arguments.selectVideoNoteCamera()
            })
        case let .videoNoteDuration(duration):
            let label: String
            if duration >= 600.0 {
                label = "10 минут"
            } else if duration >= 300.0 {
                label = "5 минут"
            } else if duration >= 180.0 {
                label = "3 минуты"
            } else {
                label = "1 минута"
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.clock, title: "Лимит записи кружочков", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.selectVideoNoteDuration()
            })
        case let .splitLongVideoNotes(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.videosBlue, title: "Разбивать длинные кружочки", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleSplitLongVideoNotes(value)
            })
        case .uiFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("ID, DC и счётчик сообщений отображаются в профиле. Выбор камеры определяет, какая камера включится первой при начале записи кружочка. Лимит длительности позволяет записывать длинные видеосообщения без прерываний. При включённом разбиении кружочки длиннее 1 минуты отправляются последовательными кружками по 60 секунд, сохраняя круглый формат."), sectionId: self.section)
            
        case .keepAliveHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ФОНОВАЯ РАБОТА И УВЕДОМЛЕНИЯ", sectionId: self.section)
        case let .keepAlive(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.powerSaving, title: "Работа в фоне (Keep-Alive)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleKeepAlive(value)
            })
        case .keepAliveLocationStatus:
            let status: CLAuthorizationStatus
            if #available(iOS 14.0, *) {
                status = CLLocationManager().authorizationStatus
            } else {
                status = CLLocationManager.authorizationStatus()
            }
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "✓ Защита от звука других приложений активна", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {})
            } else if status == .denied || status == .restricted {
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "⚠️ Включить геопозицию для музыки", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSystemSettings()
                })
            } else {
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "📍 Разрешить работу при музыке и звуках", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.requestLocationPermission()
                })
            }
        case .keepAliveTestNotification:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "⚡ Проверить пуш в фоне (10 сек)", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.triggerTestNotification()
            })
        case .keepAliveFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Поддерживает постоянное соединение Telegram с сервером при сворачивании приложения и доставляет уведомления без задержек.\n\nЗащита от звука других приложений: при прослушивании музыки (Apple Music, Spotify, YouTube и др.) или видео iOS блокирует фоновый звук сторонних приложений. Разрешение геопозиции позволяет Wgram продолжать работу в фоне даже при активной музыке. Используется пассивный режим вышек связи без включения GPS и без расхода аккумулятора.\n\nНажмите «Проверить пуш в фоне» и сразу заблокируйте телефон — ровно через 10 секунд на экран придёт тестовое уведомление."), sectionId: self.section)
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
    var bypassViewOnce: Bool
    var hideSponsoredMessages: Bool
    
    var confirmVoiceSend: Bool
    var confirmVideoSend: Bool
    var confirmStickerSend: Bool
    
    var antiDelete: Bool
    var saveEditHistory: Bool
    var antiDeleteExceptionsCount: Int
    
    var logEditsAndDeletesToChat: Bool
    var logChatTargetUsername: String
    var logPrivateChats: Bool
    var logGroups: Bool
    var logChannels: Bool
    var logDeletedMessages: Bool
    var logEditedMessages: Bool
    var logIncludeChatInfo: Bool
    
    var showPeerIdAndDc: Bool
    var showChatMessageCount: Bool
    var showMessageSeconds: Bool
    var videoNoteCameraIsBack: Bool
    var maxVideoNoteDuration: Double
    var splitLongVideoNotes: Bool
    var keepAlive: Bool
    
    var tgWsProxyEnabled: Bool
    var tgWsSelectedDomain: String
    var tgWsCustomDomain: String
    var tgWsAutoFallback: Bool
    var tgWsCallsBridgeEnabled: Bool
    
    var localPremiumEnabled: Bool
    var localPremiumCustomEmoji: Bool
    
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
        self.bypassViewOnce = WgramSettings.bypassViewOnce
        self.hideSponsoredMessages = WgramSettings.hideSponsoredMessages
        
        self.confirmVoiceSend = WgramSettings.confirmVoiceSend
        self.confirmVideoSend = WgramSettings.confirmVideoSend
        self.confirmStickerSend = WgramSettings.confirmStickerSend
        
        self.antiDelete = WgramSettings.antiDeleteMessages
        self.saveEditHistory = WgramSettings.saveEditHistory
        self.antiDeleteExceptionsCount = WgramSettings.antiDeleteExcludedPeerIds.count
        
        self.logEditsAndDeletesToChat = WgramSettings.logEditsAndDeletesToChatEnabled
        self.logChatTargetUsername = WgramSettings.logChatTargetUsername
        self.logPrivateChats = WgramSettings.logPrivateChats
        self.logGroups = WgramSettings.logGroups
        self.logChannels = WgramSettings.logChannels
        self.logDeletedMessages = WgramSettings.logDeletedMessages
        self.logEditedMessages = WgramSettings.logEditedMessages
        self.logIncludeChatInfo = WgramSettings.logIncludeChatInfo
        
        self.showPeerIdAndDc = WgramSettings.showPeerIdAndDc
        self.showChatMessageCount = WgramSettings.showChatMessageCount
        self.showMessageSeconds = WgramSettings.showMessageSeconds
        self.videoNoteCameraIsBack = WgramSettings.videoNoteCameraIsBack
        self.maxVideoNoteDuration = WgramSettings.maxVideoNoteDuration
        self.splitLongVideoNotes = WgramSettings.splitLongVideoNotes
        self.keepAlive = WgramSettings.keepAliveInBackground
        
        self.tgWsProxyEnabled = WgramSettings.tgWsProxyEnabled
        self.tgWsSelectedDomain = WgramSettings.tgWsSelectedDomain
        self.tgWsCustomDomain = WgramSettings.tgWsCustomDomain
        self.tgWsAutoFallback = WgramSettings.tgWsAutoFallback
        self.tgWsCallsBridgeEnabled = WgramSettings.tgWsCallsBridgeEnabled
        
        self.localPremiumEnabled = WgramSettings.localPremiumEnabled
        self.localPremiumCustomEmoji = WgramSettings.localPremiumCustomEmoji
    }
}

private func wgramSettingsEntries(presentationData: PresentationData, state: WgramSettingsState) -> [WgramSettingsEntry] {
    var entries: [WgramSettingsEntry] = []
    
    // Ghost Mode
    entries.append(.ghostHeader)
    entries.append(.ghostMaster(state.ghostModeEnabled))
    entries.append(.ghostFooter)
    
    if state.ghostModeEnabled {
        entries.append(.detailsHeader)
        entries.append(.dontReadMessages(state.dontReadMessages))
        entries.append(.dontSendTyping(state.dontSendTyping))
        entries.append(.dontUpdateOnline(state.dontUpdateOnline))
        entries.append(.dontReadStories(state.dontReadStories))
        entries.append(.dontReadMedia(state.dontReadMedia))
        entries.append(.ghostSend(state.ghostSend))
        entries.append(.markReadAfterAction(state.markReadAfterAction))
        entries.append(.detailsFooter)
    }
    
    // Local Premium
    entries.append(.localPremiumHeader)
    entries.append(.localPremiumMaster(state.localPremiumEnabled))
    if state.localPremiumEnabled {
        entries.append(.localPremiumCustomEmoji(state.localPremiumCustomEmoji))
    }
    entries.append(.localPremiumFooter)
    
    // TG WS Proxy
    entries.append(.tgWsProxyHeader)
    entries.append(.tgWsProxyMaster(state.tgWsProxyEnabled))
    if state.tgWsProxyEnabled {
        let domainLabel: String
        if state.tgWsSelectedDomain == "custom" {
            domainLabel = state.tgWsCustomDomain.isEmpty ? "Свой домен" : state.tgWsCustomDomain
        } else {
            domainLabel = state.tgWsSelectedDomain
        }
        entries.append(.tgWsDomainSelector(domainLabel))
        entries.append(.tgWsAutoFallback(state.tgWsAutoFallback))
        entries.append(.tgWsCallsBridge(state.tgWsCallsBridgeEnabled))
    }
    entries.append(.tgWsProxyFooter)
    
    // Copy Protection Bypass & Ads
    entries.append(.copyProtectionHeader)
    entries.append(.bypassCopyProtection(state.bypassCopyProtection))
    entries.append(.bypassViewOnce(state.bypassViewOnce))
    entries.append(.hideSponsoredMessages(state.hideSponsoredMessages))
    entries.append(.copyProtectionFooter)
    
    // Send Confirmation Protection
    entries.append(.confirmationsHeader)
    entries.append(.confirmVoiceSend(state.confirmVoiceSend))
    entries.append(.confirmVideoSend(state.confirmVideoSend))
    entries.append(.confirmStickerSend(state.confirmStickerSend))
    entries.append(.confirmationsFooter)
    
    // History & Anti-Delete
    entries.append(.historyHeader)
    entries.append(.antiDelete(state.antiDelete))
    entries.append(.saveEditHistory(state.saveEditHistory))
    entries.append(.antiDeleteExceptions(state.antiDeleteExceptionsCount))
    entries.append(.historyFooter)
    
    // Message Logging to Chat
    entries.append(.loggingHeader)
    entries.append(.logMaster(state.logEditsAndDeletesToChat))
    if state.logEditsAndDeletesToChat {
        entries.append(.logChatTarget(state.logChatTargetUsername))
        entries.append(.logPrivateChats(state.logPrivateChats))
        entries.append(.logGroups(state.logGroups))
        entries.append(.logChannels(state.logChannels))
        entries.append(.logDeletedMessages(state.logDeletedMessages))
        entries.append(.logEditedMessages(state.logEditedMessages))
        entries.append(.logIncludeChatInfo(state.logIncludeChatInfo))
    }
    entries.append(.loggingFooter)
    
    // UI & Info
    entries.append(.uiHeader)
    entries.append(.showPeerIdAndDc(state.showPeerIdAndDc))
    entries.append(.showChatMessageCount(state.showChatMessageCount))
    entries.append(.showMessageSeconds(state.showMessageSeconds))
    entries.append(.videoNoteCamera(state.videoNoteCameraIsBack))
    entries.append(.videoNoteDuration(state.maxVideoNoteDuration))
    entries.append(.splitLongVideoNotes(state.splitLongVideoNotes))
    entries.append(.uiFooter)
    
    // Keep Alive
    entries.append(.keepAliveHeader)
    entries.append(.keepAlive(state.keepAlive))
    if state.keepAlive {
        entries.append(.keepAliveLocationStatus)
        entries.append(.keepAliveTestNotification)
    }
    entries.append(.keepAliveFooter)
    
    return entries
}

public func wgramSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<WgramSettingsState>(WgramSettingsState(), ignoreRepeated: true)
    let stateValue = Atomic<WgramSettingsState>(value: WgramSettingsState())
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
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
        toggleBypassViewOnce: { value in
            WgramSettings.bypassViewOnce = value
            updateState { $0.bypassViewOnce = value }
        },
        toggleHideSponsoredMessages: { value in
            WgramSettings.hideSponsoredMessages = value
            updateState { $0.hideSponsoredMessages = value }
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
        openHistoryExceptions: {
            pushControllerImpl?(wgramHistoryExceptionsController(context: context))
        },
        toggleLogEditsAndDeletesToChat: { value in
            WgramSettings.logEditsAndDeletesToChatEnabled = value
            updateState { $0.logEditsAndDeletesToChat = value }
        },
        selectLogChatTarget: {
            let alert = UIAlertController(
                title: "Чат для логов",
                message: "Укажите @username или ID пользователя/канала, куда будут отправляться удалённые и изменённые сообщения.\nОставьте пустым для сохранения в «Избранное».",
                preferredStyle: .alert
            )
            alert.addTextField { textField in
                textField.placeholder = "@username или пусто для Избранного"
                textField.text = WgramSettings.logChatTargetUsername
                textField.autocapitalizationType = .none
                textField.autocorrectionType = .no
            }
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { _ in
                let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                WgramSettings.logChatTargetUsername = text
                WgramSettings.logChatTargetPeerId = 0
                
                let cleaned = text.replacingOccurrences(of: "@", with: "")
                if !cleaned.isEmpty {
                    let _ = (context.engine.peers.resolvePeerByName(name: cleaned, referrer: nil)
                    |> deliverOnMainQueue).start(next: { result in
                        if case let .result(peer) = result, let peer = peer {
                            WgramSettings.logChatTargetPeerId = peer.id.toInt64()
                        }
                    })
                }
                
                updateState {
                    $0.logChatTargetUsername = text
                }
            }))
            context.sharedContext.applicationBindings.presentNativeController(alert)
        },
        toggleLogPrivateChats: { value in
            WgramSettings.logPrivateChats = value
            updateState { $0.logPrivateChats = value }
        },
        toggleLogGroups: { value in
            WgramSettings.logGroups = value
            updateState { $0.logGroups = value }
        },
        toggleLogChannels: { value in
            WgramSettings.logChannels = value
            updateState { $0.logChannels = value }
        },
        toggleLogDeletedMessages: { value in
            WgramSettings.logDeletedMessages = value
            updateState { $0.logDeletedMessages = value }
        },
        toggleLogEditedMessages: { value in
            WgramSettings.logEditedMessages = value
            updateState { $0.logEditedMessages = value }
        },
        toggleLogIncludeChatInfo: { value in
            WgramSettings.logIncludeChatInfo = value
            updateState { $0.logIncludeChatInfo = value }
        },
        toggleShowPeerIdAndDc: { value in
            WgramSettings.showPeerIdAndDc = value
            updateState { $0.showPeerIdAndDc = value }
        },
        toggleShowChatMessageCount: { value in
            WgramSettings.showChatMessageCount = value
            updateState { $0.showChatMessageCount = value }
        },
        toggleShowMessageSeconds: { value in
            WgramSettings.showMessageSeconds = value
            updateState { $0.showMessageSeconds = value }
        },
        selectVideoNoteCamera: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            items.append(ActionSheetTextItem(title: "Камера для кружочков"))
            items.append(ActionSheetButtonItem(title: "Фронтальная камера (селфи)", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                WgramSettings.videoNoteCameraIsBack = false
                updateState { $0.videoNoteCameraIsBack = false }
            }))
            items.append(ActionSheetButtonItem(title: "Основная камера (задняя)", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                WgramSettings.videoNoteCameraIsBack = true
                updateState { $0.videoNoteCameraIsBack = true }
            }))
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            context.sharedContext.mainWindow?.present(actionSheet, on: .root)
        },
        selectVideoNoteDuration: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            items.append(ActionSheetTextItem(title: "Максимальная длительность кружочков"))
            let options: [(Double, String)] = [
                (600.0, "10 минут (рекомендуется)"),
                (300.0, "5 минут"),
                (180.0, "3 минуты"),
                (60.0, "1 минута (стандарт)")
            ]
            for (duration, label) in options {
                items.append(ActionSheetButtonItem(title: label, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    WgramSettings.maxVideoNoteDuration = duration
                    updateState { $0.maxVideoNoteDuration = duration }
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            context.sharedContext.mainWindow?.present(actionSheet, on: .root)
        },
        toggleSplitLongVideoNotes: { value in
            WgramSettings.splitLongVideoNotes = value
            updateState { $0.splitLongVideoNotes = value }
        },
        toggleKeepAlive: { value in
            WgramSettings.keepAliveInBackground = value
            if value {
                NotificationCenter.default.post(name: NSNotification.Name("WgramRequestLocationPermission"), object: nil)
            }
            updateState { $0.keepAlive = value }
            NotificationCenter.default.post(name: NSNotification.Name("WgramKeepAliveChanged"), object: nil)
        },
        triggerTestNotification: {
            NotificationCenter.default.post(name: NSNotification.Name("WgramTestKeepAliveNotification"), object: nil)
            let alert = UIAlertController(
                title: "⚡ Тест запущен",
                message: "Сверните Telegram или заблокируйте экран прямо сейчас.\nРовно через 10 секунд на экран придёт пуш-уведомление.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Понятно", style: .default))
            context.sharedContext.applicationBindings.presentNativeController(alert)
        },
        toggleTgWsProxy: { value in
            WgramSettings.tgWsProxyEnabled = value
            updateState { $0.tgWsProxyEnabled = value }
        },
        selectTgWsDomain: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            items.append(ActionSheetTextItem(title: "Выберите зеркало TG WS"))
            let domains = [
                ("noskomnadzor.co.uk", "noskomnadzor.co.uk (Cloudflare)"),
                ("cakeisalie.co.uk", "cakeisalie.co.uk (Cloudflare)"),
                ("kartoshka.co.uk", "kartoshka.co.uk (Cloudflare)"),
                ("pclead.co.uk", "pclead.co.uk (Cloudflare)"),
                ("pomogite.co.uk", "pomogite.co.uk (Cloudflare)"),
                ("web.telegram.org", "web.telegram.org (Прямое WSS)"),
                ("custom", "Свой воркер / домен...")
            ]
            for (key, label) in domains {
                items.append(ActionSheetButtonItem(title: label, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if key == "custom" {
                        let alert = UIAlertController(title: "Свой домен", message: "Введите домен Cloudflare Worker или прокси:", preferredStyle: .alert)
                        alert.addTextField { textField in
                            textField.placeholder = "example.workers.dev"
                            textField.text = WgramSettings.tgWsCustomDomain
                        }
                        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
                        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { _ in
                            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            WgramSettings.tgWsCustomDomain = text
                            WgramSettings.tgWsSelectedDomain = "custom"
                            updateState {
                                $0.tgWsCustomDomain = text
                                $0.tgWsSelectedDomain = "custom"
                            }
                        }))
                        context.sharedContext.applicationBindings.presentNativeController(alert)
                    } else {
                        WgramSettings.tgWsSelectedDomain = key
                        updateState {
                            $0.tgWsSelectedDomain = key
                        }
                    }
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            context.sharedContext.mainWindow?.present(actionSheet, on: .root)
        },
        toggleTgWsAutoFallback: { value in
            WgramSettings.tgWsAutoFallback = value
            updateState { $0.tgWsAutoFallback = value }
        },
        toggleTgWsCallsBridge: { value in
            WgramSettings.tgWsCallsBridgeEnabled = value
            updateState { $0.tgWsCallsBridgeEnabled = value }
        },
        requestLocationPermission: {
            NotificationCenter.default.post(name: NSNotification.Name("WgramRequestLocationPermission"), object: nil)
        },
        openSystemSettings: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        },
        toggleLocalPremium: { value in
            WgramSettings.localPremiumEnabled = value
            updateState { $0.localPremiumEnabled = value }
        },
        toggleLocalPremiumCustomEmoji: { value in
            WgramSettings.localPremiumCustomEmoji = value
            updateState { $0.localPremiumCustomEmoji = value }
        }
    )
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, WgramSettingsControllerArguments)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Настройки Wgram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: wgramSettingsEntries(presentationData: presentationData, state: state), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    
    let _ = NotificationCenter.default.addObserver(forName: WgramSettings.didChangeNotification, object: nil, queue: .main) { _ in
        updateState { state in
            state.antiDeleteExceptionsCount = WgramSettings.antiDeleteExcludedPeerIds.count
        }
    }
    
    return controller
}
