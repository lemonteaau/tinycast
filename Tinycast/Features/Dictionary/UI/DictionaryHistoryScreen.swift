import SwiftUI

/// Search and reopen the words the reader has looked up on this Mac.
struct DictionaryHistoryScreen: PaletteScreen {
    let history: DictionaryHistoryStore
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    var rows: [DictionaryHistoryEntry] { history.search(vm.query) }
    let primaryActionTitle = "Look Up Word"

    private func entry(at selection: Int) -> DictionaryHistoryEntry? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let entry = entry(at: selection) else { return nil }
        return DictionaryHistoryActionsMenu.content(entry: entry, history: history, core: core)
    }

    func activate(at selection: Int) {
        guard let entry = entry(at: selection) else { return }
        core.dictionaryCoordinator.show(term: entry.term)
    }

    func secondary(at selection: Int) -> Bool {
        guard let entry = entry(at: selection) else { return false }
        core.dictionaryCoordinator.openInDictionary(term: entry.term)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        switch shortcut {
        case .commandDelete, .delete:
            guard let entry = entry(at: selection) else { return true }
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
        AnyView(content(selection: selection, scroll: scroll))
    }

    @ViewBuilder
    private func content(selection: Int, scroll: ScrollIntent) -> some View {
        let rows = rows
        if rows.isEmpty {
            EmptyResults(
                text: history.entries.isEmpty ? "No words looked up yet" : "No matching words")
        } else {
            let selected = entry(at: selection)
            DictionaryHistoryList(
                results: rows,
                sectionTitle: nil,
                selectedID: selected?.id,
                scroll: scroll,
                onSelect: { item in vm.selection = rows.firstIndex(of: item) ?? 0 },
                onActivate: { activate(at: vm.selection) },
                onActions: { item in
                    if let index = rows.firstIndex(of: item) { vm.selection = index }
                    openActions()
                })
        }
    }
}

@MainActor
enum DictionaryHistoryActionsMenu {
    static func content(
        entry: DictionaryHistoryEntry, history: DictionaryHistoryStore, core: AppCore
    ) -> PopoverMenuContent {
        PopoverMenuContent(
            header: entry.term,
            items: [
                PopoverMenuItem(title: "Look Up Word", systemImage: "book.closed", shortcut: "↵") {
                    core.dictionaryCoordinator.show(term: entry.term)
                },
                PopoverMenuItem(title: "Open in Dictionary", systemImage: "book", shortcut: "⌘↵") {
                    core.dictionaryCoordinator.openInDictionary(term: entry.term)
                },
                PopoverMenuItem(title: "Copy Word", systemImage: "doc.on.doc") {
                    core.dictionaryCoordinator.copyTerm(entry.term)
                },
                PopoverMenuItem(
                    title: "Delete Entry", systemImage: "trash", startsSection: true, shortcut: "⌃X",
                    isDestructive: true
                ) {
                    history.remove(entry)
                },
                PopoverMenuItem(
                    title: "Delete All Entries", systemImage: "trash", shortcut: "⌃⇧X",
                    isDestructive: true
                ) {
                    Task { await core.dictionaryCoordinator.deleteAllHistory() }
                }
            ])
    }
}
