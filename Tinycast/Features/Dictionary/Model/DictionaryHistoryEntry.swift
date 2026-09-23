import Foundation

/// One locally remembered dictionary query.
struct DictionaryHistoryEntry: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let term: String
    let createdAt: Date
}
