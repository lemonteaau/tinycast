import Foundation

@main
@MainActor
struct DictionarySessionTests {
    static var failures = 0
    static var passes = 0

    static func check(_ condition: Bool, _ message: String) {
        if condition {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictionary-session-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let history = DictionaryHistoryStore(
            fileURL: directory.appendingPathComponent("history.json"))
        let session = DictionarySession(
            history: history, debounce: .milliseconds(180), lookup: { _ in nil })

        for term in ["h", "hy", "hyp", "hype"] {
            session.lookUp(term)
            try? await Task.sleep(for: .milliseconds(30))
        }
        check(history.entries.isEmpty, "typing a word's prefixes does not create history rows")

        try? await Task.sleep(for: .milliseconds(220))
        check(history.entries.map(\.term) == ["hype"], "the settled query is recorded once")
        check(
            session.lookup?.term == "hype" && session.lookup?.entry == nil,
            "a settled query with no definition still completes")

        session.lookUp("abandoned")
        session.reset()
        try? await Task.sleep(for: .milliseconds(220))
        check(history.entries.map(\.term) == ["hype"], "reset cancels an unfinished query")

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
