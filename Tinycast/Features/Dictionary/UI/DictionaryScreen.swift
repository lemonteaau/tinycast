import SwiftUI

/// The search field is the term; the entry fills the palette instead of competing with a list.
struct DictionaryScreen: PaletteScreen {
    let session: DictionarySession
    let history: DictionaryHistoryStore
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    private var term: String { vm.query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The page on screen: it stays up while the next term resolves, and ↵ acts on what is shown.
    private var entry: DictionaryEntry? { session.lookup?.entry }

    enum Row: Identifiable {
        case definition(DictionaryEntry)
        case history(DictionaryHistoryEntry)

        var id: String {
            switch self {
            case .definition(let entry): "definition-\(entry.id)"
            case .history(let entry): "history-\(entry.id.uuidString)"
            }
        }
    }

    var rows: [Row] {
        if term.isEmpty { return history.entries.map(Row.history) }
        return entry.map { [.definition($0)] } ?? []
    }

    var primaryActionTitle: String { term.isEmpty ? "Look Up Word" : "Copy Definition" }

    private func row(at selection: Int) -> Row? {
        let currentRows = rows
        return currentRows.indices.contains(selection) ? currentRows[selection] : nil
    }

    private func historyEntry(at selection: Int) -> DictionaryHistoryEntry? {
        guard case .history(let entry) = row(at: selection) else { return nil }
        return entry
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        switch row(at: selection) {
        case .definition(let entry):
            return PopoverMenuContent(
                header: entry.term,
                items: [
                    PopoverMenuItem(
                        title: "Copy Definition", systemImage: "doc.on.doc", shortcut: "↵"
                    ) {
                        core.dictionaryCoordinator.copy(entry)
                    },
                    PopoverMenuItem(
                        title: "Open in Dictionary", systemImage: "book", shortcut: "⌘↵"
                    ) {
                        core.dictionaryCoordinator.openInDictionary(entry)
                    }
                ])
        case .history(let entry):
            return DictionaryHistoryActionsMenu.content(
                entry: entry, history: history, core: core)
        case nil:
            return nil
        }
    }

    func activate(at selection: Int) {
        switch row(at: selection) {
        case .definition(let entry): core.dictionaryCoordinator.copy(entry)
        case .history(let entry): vm.query = entry.term
        case nil: break
        }
    }

    func secondary(at selection: Int) -> Bool {
        switch row(at: selection) {
        case .definition(let entry):
            core.dictionaryCoordinator.openInDictionary(entry)
            return true
        case .history(let entry):
            core.dictionaryCoordinator.openInDictionary(term: entry.term)
            return true
        case nil:
            return false
        }
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard let entry = historyEntry(at: selection) else { return false }
        switch shortcut {
        case .commandDelete, .delete:
            history.remove(entry)
            return true
        case .deleteAll:
            Task { await core.dictionaryCoordinator.deleteAllHistory() }
            return true
        default:
            return false
        }
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        if term.isEmpty {
            guard !history.entries.isEmpty else {
                return AnyView(EmptyResults(text: "Type a word to define"))
            }
            let selected = historyEntry(at: selection)
            return AnyView(
                DictionaryHistoryList(
                    results: history.entries,
                    sectionTitle: "Recent Lookups",
                    selectedID: selected?.id,
                    scroll: scroll,
                    onSelect: { item in
                        vm.selection = history.entries.firstIndex(of: item) ?? 0
                    },
                    onActivate: { activate(at: vm.selection) },
                    onActions: { item in
                        if let index = history.entries.firstIndex(of: item) {
                            vm.selection = index
                        }
                        openActions()
                    }))
        }
        if let entry { return AnyView(DictionaryEntryView(entry: entry)) }
        if session.lookup?.term == term { return AnyView(EmptyResults(text: "No definition found")) }
        return AnyView(Color.clear)
    }
}
