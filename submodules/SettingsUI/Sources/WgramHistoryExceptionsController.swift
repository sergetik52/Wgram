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
import ItemListPeerItem
import ItemListPeerActionItem

private final class WgramHistoryExceptionsControllerArguments {
    let context: AccountContext
    let addChat: () -> Void
    let removePeer: (EnginePeer.Id) -> Void
    let openPeer: (EnginePeer) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void

    init(
        context: AccountContext,
        addChat: @escaping () -> Void,
        removePeer: @escaping (EnginePeer.Id) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void
    ) {
        self.context = context
        self.addChat = addChat
        self.removePeer = removePeer
        self.openPeer = openPeer
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
    }
}

private enum WgramHistoryExceptionsSection: Int32 {
    case add = 0
    case peers = 1
}

private enum WgramHistoryExceptionsEntryStableId: Hashable {
    case add
    case peer(EnginePeer.Id)
    case footer
}

private enum WgramHistoryExceptionsEntry: ItemListNodeEntry {
    case add(PresentationTheme, String)
    case peerItem(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, EnginePeer, ItemListPeerItemEditing, Bool)
    case footer(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .add:
            return WgramHistoryExceptionsSection.add.rawValue
        case .peerItem, .footer:
            return WgramHistoryExceptionsSection.peers.rawValue
        }
    }

    var stableId: WgramHistoryExceptionsEntryStableId {
        switch self {
        case .add:
            return .add
        case let .peerItem(_, _, _, _, _, peer, _, _):
            return .peer(peer.id)
        case .footer:
            return .footer
        }
    }

    static func ==(lhs: WgramHistoryExceptionsEntry, rhs: WgramHistoryExceptionsEntry) -> Bool {
        switch lhs {
        case let .add(lhsTheme, lhsText):
            if case let .add(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        case let .peerItem(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsPeer, lhsEditing, lhsEnabled):
            if case let .peerItem(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                return lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsDateTimeFormat == rhsDateTimeFormat && lhsNameOrder == rhsNameOrder && lhsPeer == rhsPeer && lhsEditing == rhsEditing && lhsEnabled == rhsEnabled
            }
            return false
        case let .footer(lhsTheme, lhsText):
            if case let .footer(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        }
    }

    static func <(lhs: WgramHistoryExceptionsEntry, rhs: WgramHistoryExceptionsEntry) -> Bool {
        switch lhs {
        case .add:
            if case .add = rhs {
                return false
            } else {
                return true
            }
        case let .peerItem(index, _, _, _, _, _, _, _):
            switch rhs {
            case .add:
                return false
            case let .peerItem(rhsIndex, _, _, _, _, _, _, _):
                return index < rhsIndex
            case .footer:
                return true
            }
        case .footer:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! WgramHistoryExceptionsControllerArguments
        switch self {
        case let .add(theme, text):
            return ItemListPeerActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: PresentationResourcesItemList.addPersonIcon(theme),
                title: text,
                sectionId: self.section,
                editing: false,
                action: {
                    arguments.addChat()
                }
            )
        case let .peerItem(_, _, strings, dateTimeFormat, nameDisplayOrder, peer, editing, enabled):
            let revealOptions = ItemListPeerItemRevealOptions(options: [
                ItemListPeerItemRevealOption(type: .destructive, title: strings.Common_Delete, action: {
                    arguments.removePeer(peer.id)
                })
            ])
            return ItemListPeerItem(
                presentationData: presentationData,
                systemStyle: .glass,
                dateTimeFormat: dateTimeFormat,
                nameDisplayOrder: nameDisplayOrder,
                context: arguments.context,
                peer: peer,
                presence: nil,
                text: .none,
                label: .none,
                editing: editing,
                revealOptions: revealOptions,
                switchValue: nil,
                enabled: enabled,
                selectable: true,
                sectionId: self.section,
                action: {
                    arguments.openPeer(peer)
                },
                setPeerIdWithRevealedOptions: { previousId, currentId in
                    arguments.setPeerIdWithRevealedOptions(previousId, currentId)
                },
                removePeer: { id in
                    arguments.removePeer(id)
                }
            )
        case let .footer(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct WgramHistoryExceptionsControllerState: Equatable {
    var peerIdWithRevealedOptions: EnginePeer.Id?
    var editing: Bool = false

    init(peerIdWithRevealedOptions: EnginePeer.Id? = nil, editing: Bool = false) {
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.editing = editing
    }
}

private func wgramHistoryExceptionsEntries(
    presentationData: PresentationData,
    state: WgramHistoryExceptionsControllerState,
    peers: [EnginePeer]
) -> [WgramHistoryExceptionsEntry] {
    var entries: [WgramHistoryExceptionsEntry] = []

    entries.append(.add(presentationData.theme, "Добавить чат..."))

    var index: Int32 = 0
    for peer in peers {
        let isRevealed = state.peerIdWithRevealedOptions == peer.id
        entries.append(.peerItem(
            index,
            presentationData.theme,
            presentationData.strings,
            presentationData.dateTimeFormat,
            presentationData.nameDisplayOrder,
            peer,
            ItemListPeerItemEditing(editable: true, editing: state.editing, revealed: isRevealed),
            true
        ))
        index += 1
    }

    entries.append(.footer(presentationData.theme, "В выбранных чатах удалённые сообщения не будут сохраняться (удаляются безвозвратно), а история изменений текста не будет отслеживаться."))

    return entries
}

public func wgramHistoryExceptionsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(WgramHistoryExceptionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: WgramHistoryExceptionsControllerState())
    let updateState: ((WgramHistoryExceptionsControllerState) -> WgramHistoryExceptionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var pushControllerImpl: ((ViewController) -> Void)?

    let reloadTrigger = ValuePromise<Bool>(true, ignoreRepeated: false)

    let wgramSettingsSignal = Signal<Void, NoError> { subscriber in
        subscriber.putNext(())
        let observer = NotificationCenter.default.addObserver(
            forName: WgramSettings.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            subscriber.putNext(())
        }
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    let peersSignal: Signal<[EnginePeer], NoError> = combineLatest(
        reloadTrigger.get(),
        wgramSettingsSignal
    )
    |> mapToSignal { _ -> Signal<[EnginePeer], NoError> in
        let rawIds = WgramSettings.antiDeleteExcludedPeerIds
        return context.account.postbox.transaction { transaction -> [EnginePeer] in
            var peers: [EnginePeer] = []
            var migratedIds: [Int64] = []
            var needsMigration = false

            for rawId in rawIds {
                let directPeerId = PeerId(rawId)
                if let peer = transaction.getPeer(directPeerId) {
                    peers.append(EnginePeer(peer))
                    migratedIds.append(peer.id.toInt64())
                    if peer.id.toInt64() != rawId {
                        needsMigration = true
                    }
                } else {
                    var found = false
                    for ns in [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel, Namespaces.Peer.SecretChat] {
                        let candidateId = PeerId(namespace: ns, id: PeerId.Id._internalFromInt64Value(rawId))
                        if let peer = transaction.getPeer(candidateId) {
                            peers.append(EnginePeer(peer))
                            migratedIds.append(peer.id.toInt64())
                            found = true
                            needsMigration = true
                            break
                        }
                    }
                    if !found {
                        migratedIds.append(rawId)
                    }
                }
            }

            if needsMigration {
                DispatchQueue.main.async {
                    WgramSettings.antiDeleteExcludedPeerIds = migratedIds
                }
            }

            return peers
        }
    }

    let arguments = WgramHistoryExceptionsControllerArguments(
        context: context,
        addChat: {
            let controller = context.sharedContext.makePeerSelectionController(
                PeerSelectionControllerParams(
                    context: context,
                    filter: [.excludeSavedMessages, .removeSearchHeader],
                    hasContactSelector: false,
                    title: "Исключить чат"
                )
            )
            controller.peerSelected = { [weak controller] peer, _ in
                controller?.dismiss()
                WgramSettings.addAntiDeleteExcluded(peerId: peer.id)
                reloadTrigger.set(true)
            }
            pushControllerImpl?(controller)
        },
        removePeer: { peerId in
            WgramSettings.removeAntiDeleteExcluded(peerId: peerId)
            reloadTrigger.set(true)
        },
        openPeer: { peer in
            if let controller = context.sharedContext.makePeerInfoController(
                context: context,
                updatedPresentationData: nil,
                peer: peer,
                mode: .generic,
                avatarInitiallyExpanded: false,
                fromChat: false,
                requestsContext: nil
            ) {
                pushControllerImpl?(controller)
            }
        },
        setPeerIdWithRevealedOptions: { peerId, fromPeerId in
            updateState { state in
                if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                    var updated = state
                    updated.peerIdWithRevealedOptions = peerId
                    return updated
                } else {
                    return state
                }
            }
        }
    )

    let signal: Signal<(ItemListControllerState, (ItemListNodeState, WgramHistoryExceptionsControllerArguments)), NoError> = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        peersSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, peers in
        var rightNavigationButton: ItemListNavigationButton?
        if !peers.isEmpty {
            if state.editing {
                rightNavigationButton = ItemListNavigationButton(
                    content: .text(presentationData.strings.Common_Done),
                    style: .bold,
                    enabled: true,
                    action: {
                        updateState { state in
                            var updated = state
                            updated.editing = false
                            return updated
                        }
                    }
                )
            } else {
                rightNavigationButton = ItemListNavigationButton(
                    content: .text(presentationData.strings.Common_Edit),
                    style: .regular,
                    enabled: true,
                    action: {
                        updateState { state in
                            var updated = state
                            updated.editing = true
                            return updated
                        }
                    }
                )
            }
        }

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Исключения"),
            leftNavigationButton: nil,
            rightNavigationButton: rightNavigationButton,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )

        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: wgramHistoryExceptionsEntries(presentationData: presentationData, state: state, peers: peers),
            style: .blocks
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }

    return controller
}
