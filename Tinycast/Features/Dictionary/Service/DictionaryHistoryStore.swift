import Foundation
import Observation

/// Recent lookup terms, newest first, kept on this Mac.
@MainActor
@Observable
final class DictionaryHistoryStore {
    private static let cap = 200

    private let fileURL: URL
    private(set) var entries: [DictionaryHistoryEntry]
    @ObservationIgnored var onPersistenceFailure: (() -> Void)?

    init(
        fileURL: URL = AppPaths.applicationSupport().appendingPathComponent("dictionary-history.json")
    ) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([DictionaryHistoryEntry].self, from: data)
        {
            entries = Array(decoded.prefix(Self.cap))
        } else {
            entries = []
        }
    }

    func record(_ term: String) {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        entries.removeAll { $0.term.compare(term, options: .caseInsensitive) == .orderedSame }
        entries.insert(
            DictionaryHistoryEntry(id: UUID(), term: term, createdAt: Date()), at: 0)
        if entries.count > Self.cap { entries.removeLast(entries.count - Self.cap) }
        persist()
    }

    func remove(_ entry: DictionaryHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clearAll() {
        entries = []
        persist()
    }

    func search(_ query: String) -> [DictionaryHistoryEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.term.localizedCaseInsensitiveContains(query) }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            onPersistenceFailure?()
        }
    }
}
