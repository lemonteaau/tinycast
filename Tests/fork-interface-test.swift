// The fork's separate content scale, kept out of interface-size-test so that file stays upstream's.
import AppKit
import SwiftUI

@main
@MainActor
struct ForkInterfaceTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func expect(_ actual: CGFloat, _ expected: CGFloat, _ message: String) {
        expect(abs(actual - expected) < 0.001, "\(message) — got \(actual), want \(expected)")
    }

    static func main() {
        let large = InterfaceSize.large.metrics
        let larger = InterfaceSize.larger.metrics
        expect(large.size.panelWidth, 825, "Large keeps its existing panel width")
        expect(large.size.panelHeight, 523, "Large keeps its existing panel height")
        expect(large.typography.searchFieldSize, 24, "Large search text is easier to read")
        expect(large.size.rowIcon, 29, "Large launcher icons are easier to see")
        expect(large.size.resultRowIcon, 31, "Large result icons are easier to see")
        expect(
            larger.typography.searchFieldSize > large.typography.searchFieldSize,
            "Larger text still grows beyond Large")
        expect(larger.size.rowIcon > large.size.rowIcon, "Larger icons still grow beyond Large")

        for size in InterfaceSize.allCases {
            expect(
                size.metrics.typography.searchFieldSize
                    == (Theme.Typography.searchFieldSize * size.contentScale).rounded(),
                "the search field follows the content scale at \(size.rawValue)")
        }
        expect(
            InterfaceMetrics(scale: 1.1) == InterfaceMetrics(scale: 1.1, contentScale: 1.1),
            "upstream's one-scale spelling still builds, scaling content with the frame")

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
