import Foundation

/// The dictionary's action surface: open the screen on a term, and act on the entry it shows.
@MainActor
final class DictionaryCoordinator {
    private let history: DictionaryHistoryStore
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore

    init(history: DictionaryHistoryStore, paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.history = history
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// `term` is the fallback row's query, so the screen opens already showing its entry.
    func show(term: String = "") {
        paletteCoordinator.togglePalette(mode: .dictionary, seeding: term.isEmpty ? nil : term)
    }

    func showHistory() {
        paletteCoordinator.togglePalette(mode: .dictionaryHistory)
    }

    /// Clearing learned input is destructive, so every route asks first.
    func deleteAllHistory() async {
        guard
            await core.confirm(
                title: "Clear dictionary history?",
                message: "Every looked-up word goes. This can't be undone.",
                symbol: PaletteMode.dictionaryHistory.systemImage, confirmTitle: "Clear History")
        else { return }
        history.clearAll()
    }

    func copy(_ entry: DictionaryEntry) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.copyPlainText(entry.text)
    }

    /// Dictionary.app shows the full entry, with every dictionary the reader has enabled.
    func openInDictionary(_ entry: DictionaryEntry) {
        openInDictionary(term: entry.term)
    }

    func openInDictionary(term: String) {
        guard let term = term.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
            let url = URL(string: "dict://" + term)
        else { return }
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.open(url)
    }

    func copyTerm(_ term: String) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.copyPlainText(term)
    }
}
