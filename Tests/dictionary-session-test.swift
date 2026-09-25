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

    static func waitForLookup(_ session: DictionarySession, term: String) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while session.lookup?.term != term, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        check(session.lookup?.term == term, "lookup completes before the timeout: \(term)")
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
        }
        check(history.entries.isEmpty, "typing a word's prefixes does not create history rows")

        await waitForLookup(session, term: "hype")
        check(history.entries.map(\.term) == ["hype"], "the settled query is recorded once")
        check(
            session.lookup?.term == "hype" && session.lookup?.entry == nil,
            "a settled query with no definition still completes")

        session.lookUp("abandoned")
        session.reset()
        check(session.lookup == nil, "reset clears the displayed lookup")
        let nextSession = DictionarySession(
            history: history, debounce: .milliseconds(180), lookup: { _ in nil })
        nextSession.lookUp("resumed")
        await waitForLookup(nextSession, term: "resumed")
        check(
            history.entries.map(\.term) == ["resumed", "hype"] && session.lookup == nil,
            "reset cancels an unfinished query while subsequent lookups still complete")

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
