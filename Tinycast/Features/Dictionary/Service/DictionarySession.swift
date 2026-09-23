import Foundation

/// The dictionary screen's lookup: one term in flight, answered off the main actor.
@MainActor
@Observable
final class DictionarySession {
    struct Lookup: Equatable {
        let term: String
        /// Nil when no enabled dictionary knows the term.
        let entry: DictionaryEntry?
    }

    /// The last answered lookup; it stays up while the next term resolves, so typing never blanks.
    private(set) var lookup: Lookup?
    private let history: DictionaryHistoryStore
    private let lookupEntry: @Sendable (String) -> DictionaryEntry?
    private let debounce: Duration
    @ObservationIgnored private var term = ""
    @ObservationIgnored private var task: Task<Void, Never>?

    init(
        history: DictionaryHistoryStore,
        debounce: Duration = .milliseconds(350),
        lookup: @escaping @Sendable (String) -> DictionaryEntry?
    ) {
        self.history = history
        self.debounce = debounce
        lookupEntry = lookup
    }

    func lookUp(_ query: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term != self.term else { return }
        self.term = term
        task?.cancel()
        guard !term.isEmpty else {
            lookup = nil
            return
        }
        let debounce = self.debounce
        let lookupEntry = self.lookupEntry
        task = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let entry = await Task.detached(priority: .userInitiated) {
                lookupEntry(term)
            }.value
            guard !Task.isCancelled else { return }
            guard let self else { return }
            history.record(term)
            self.lookup = Lookup(term: term, entry: entry)
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        term = ""
        lookup = nil
    }
}
