// The fork's `-fork.N` release versions, kept out of updates-test so that file stays upstream's.
import Foundation

@main
@MainActor
struct ForkUpdatesTests {
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

    static func main() {
        parsesForkVersions()
        ordersForkVersions()
        keepsForkReleasesOnStable()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func parsesForkVersions() {
        expect(
            AppVersion("v0.11.3-fork.12")?.description == "0.11.3-fork.12",
            "fork tag keeps upstream version")
        expect(
            AppVersion("0.11.3", forkRevision: 12) == AppVersion("v0.11.3-fork.12"),
            "the bundle version identifies the matching fork release")
        expect(AppVersion("0.11.3-fork.12")?.isPrerelease == false, "fork builds stay on stable")
        expect(
            AppVersion("0.11.3-fork.12")?.upstreamVersion == "0.11.3", "bundle uses official version")
        expect(AppVersion("0.11.3-fork.x") == nil, "rejects an invalid fork revision")
        expect(
            AppVersion("0.11.3-fork.1", forkRevision: 2) == nil,
            "rejects conflicting fork revisions")
    }

    static func ordersForkVersions() {
        func version(_ text: String) -> AppVersion {
            guard let parsed = AppVersion(text) else {
                fatalError("the ordering cases must all parse — \(text) did not")
            }
            return parsed
        }
        expect(
            version("0.11.3-fork.12") > version("0.11.3-fork.2"), "fork revisions order numerically")
        expect(
            version("0.11.3-fork.1") > version("0.11.3"), "a fork revision follows its upstream base")
        expect(version("0.11.4") > version("0.11.3-fork.999"), "a newer upstream release wins")
    }

    static func keepsForkReleasesOnStable() {
        let feed = Data(
            """
            [{"tag_name":"v0.11.3-fork.3","prerelease":false,"draft":false,
              "body":"Notes.","published_at":"2026-01-05T12:00:00Z",
              "assets":[{"name":"Tinycast-x.zip","size":1024,
                         "browser_download_url":"https://example.invalid/Tinycast-x.zip"}]}]
            """.utf8)
        let fork = ReleaseFeed.newest(from: feed, channel: .stable, architecture: .appleSilicon)
        expect(fork?.version == AppVersion("0.11.3-fork.3"), "fork release stays on the stable feed")
    }
}
