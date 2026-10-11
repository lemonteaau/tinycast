// How the fork's dictionary screens answer Escape, Tab and ⌘P, kept out of upstream's palette tests.
import Foundation

@main
@MainActor
struct ForkPaletteTests {
    static var failures = 0
    static var passes = 0

    static func expect<Action: Equatable>(_ actual: Action, _ expected: Action, _ message: String) {
        if actual == expected {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message) — got \(actual), want \(expected)")
        }
    }

    static func escape(mode: PaletteMode, canGoBack: Bool = false) -> PaletteEscapeAction {
        PaletteEscapeAction.resolve(
            menuOpen: false, menuQuery: "", argumentFocused: false, query: "", mode: mode,
            canGoBack: canGoBack, behavior: .navigateBackOrClose)
    }

    static func main() {
        expect(
            escape(mode: .dictionary), .goToLauncher,
            "Escape from the summoned dictionary returns to the launcher")
        expect(
            escape(mode: .dictionary, canGoBack: true), .goBack,
            "a dictionary opened from the launcher returns to its caller")

        expect(
            PaletteTabAction.resolve(
                mode: .dictionaryHistory, aiEnabled: true, clipboardEnabled: true),
            .carryQuery(.launcher),
            "dictionary history is a sub-screen, so Tab exits to the launcher")

        for mode in [PaletteMode.dictionary, .dictionaryHistory] {
            for accessory in [false, true] {
                expect(
                    PaletteFilterAction.resolve(
                        collapsed: false, mode: mode, commandHasAccessory: accessory),
                    .ignored,
                    "\(mode.rawValue) has no header filter, so ⌘P stays with the field")
            }
        }

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
