# lemonteaau's Tinycast fork

This is an independently maintained personal fork of
[abue-ammar/tinycast](https://github.com/abue-ammar/tinycast), under the original AGPL-3.0 license.
It accepts `610 aud cny` without requiring `to`. The original explicit syntax still works.
The calculator harness covers the shorthand, expressions, signs, missing rates and ambiguous input.

## Automatic maintenance

[Fork sync, test and release](https://github.com/lemonteaau/tinycast/actions/workflows/fork-maintenance.yml)
runs daily at 19:17 UTC, on pushes to `main`, and via **Run workflow**. GitHub schedules are best-effort.
Public repositories with no repository activity for 60 days can have schedules disabled by GitHub;
re-enable the workflow in Actions if that happens. Failure notifications use your GitHub Actions
notification preferences.

Each run fetches the full upstream `main` and merges it locally, preserving the fork's commits.
The fork owns the entire `.github/workflows` directory: upstream workflow changes are deliberately
excluded from the merge result. This prevents upstream publishing, website and announcement jobs
from being restored, and keeps routine sync within `GITHUB_TOKEN`'s contents permission.
Review upstream build/release workflow changes manually when tooling or packaging requirements change.
There is no stored personal GitHub access token and no force push.

A conflict outside that directory aborts the merge. Tests, lint, a Debug build and a signed Release
build must all pass before a merge is pushed to `main`. The final push also verifies that `main` has
not moved during the build. An unsuccessful run leaves the last published release available.
If publishing fails after the push, rerun the failed workflow; an unpublished commit is built again.
Draft releases are uploaded completely before being published. A commit already released is skipped.

The sync and release happen in the same workflow: a push using `GITHUB_TOKEN` does not need to trigger
another workflow. `Tests/fork-sync-test.sh` exercises successful merges, workflow isolation,
idempotence and conflict rollback in temporary Git repositories.

## Builds and updates

The app's macOS version matches the latest official stable release exactly (currently `0.11.3`).
Fork release tags and download filenames append `-fork.N`, where N is the Actions run number:
`v0.11.3-fork.2` means official version `0.11.3`, fork build 2. The bundle build number matches N,
allowing the in-app updater to distinguish successive fork builds even when upstream does not bump
its version. Each release identifies the upstream commit and exact fork source commit.
Releases contain an Apple silicon (arm64) DMG, updater-compatible ZIP and SHA-256 checksums.
macOS 26 or newer is required. Intel builds are not published by this personal workflow.

The app keeps the `Tinycast.app` name and `com.tinycast.app` bundle identifier to retain existing
settings, clipboard data and shortcuts. Its update feed points to **lemonteaau/tinycast**. Keep the
stable release channel selected; this fork does not publish beta releases. Do not reinstall Tinycast
from the upstream Homebrew cask, which would replace this fork with the official build.

Install the first fork release from the [personal Homebrew tap](https://github.com/lemonteaau/homebrew-tinycast)
or manually by quitting Tinycast and replacing `/Applications/Tinycast.app` with the app from the DMG.
Back up the previous application first. The official app's updater will not install a fork signed by
a different identity. After replacement, Accessibility may need to be granted again in System Settings.
Later fork updates use the normal in-app updater; the tap cask is also refreshed by its own daily Action.

Builds use one dedicated self-signed identity, **Tinycast Fork lemonteaau**, retained in repository
Actions secrets `SIGNING_P12_BASE64` and `SIGNING_P12_PASSWORD`. They do not use the upstream author's
certificate or an Apple Developer ID and are not notarized. For a verified download blocked by
quarantine, clear only this installed app's quarantine with:

```sh
xattr -dr com.apple.quarantine /Applications/Tinycast.app
```

Do not rotate or delete the signing secrets during routine maintenance: the updater checks the
running app's signing certificate against the new one. A new identity requires another manual
installation and permission grant. CI imports the identity into a temporary keychain, verifies both
the app and helper signatures, then deletes the keychain. No private key belongs in Git.

The upstream development and signing documents describe the upstream project; this file and
`fork-maintenance.yml` define this fork's release process. Local development still uses the separate
Debug bundle `Tinycast Dev.app`, or can build unsigned with `CODE_SIGNING_ALLOWED=NO`.
