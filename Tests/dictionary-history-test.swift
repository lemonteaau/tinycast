import Foundation

@main
@MainActor
struct DictionaryHistoryTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: Bool, _ message: String) {
        if condition {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("history.json")
        let history = DictionaryHistoryStore(fileURL: fileURL)
        history.record("  Apple  ")
        history.record("banana")
        history.record("APPLE")
        history.record(" \n ")

        expect(
            history.entries.map(\.term) == ["APPLE", "banana"], "recent terms are trimmed and deduplicated")
        expect(history.search("BAN").map(\.term) == ["banana"], "search ignores letter case")

        let reopened = DictionaryHistoryStore(fileURL: fileURL)
        expect(reopened.entries.map(\.term) == ["APPLE", "banana"], "terms survive reopening the store")

        for index in 0..<205 { reopened.record("word-\(index)") }
        expect(reopened.entries.count == 200, "history stays capped at 200 terms")
        expect(reopened.entries.first?.term == "word-204", "the newest term stays first")

        if let first = reopened.entries.first { reopened.remove(first) }
        expect(reopened.entries.count == 199, "one entry can be removed")
        reopened.clearAll()
        expect(reopened.entries.isEmpty, "history can be cleared")
        expect(DictionaryHistoryStore(fileURL: fileURL).entries.isEmpty, "clearing persists")

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
