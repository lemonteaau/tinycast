# lemonteaau's Tinycast fork

This is an independently maintained personal fork of
[abue-ammar/tinycast](https://github.com/abue-ammar/tinycast), under the original AGPL-3.0 license.
It adds a connector-free currency conversion, a dictionary lookup history, catalogued reasoning
efforts for AI gateways and a larger content scale, and publishes its own signed builds.

**Everything the fork changes is documented in this file.** The rest of `docs/`, `website/` and
`AGENTS.md` are upstream's text, kept identical to upstream so the daily sync cannot conflict in
them. Where one of them disagrees with a section below, the section below is right for this fork.
[Keeping the sync quiet](#keeping-the-sync-quiet) has the rules that follow from that.

## What this fork changes

### Currency conversion without a connector

The calculator also accepts an amount followed by two currencies with no connector: `610 aud cny`,
`10usd cad`, `$10 cad` and `2*5 usd cad`. Both names must resolve to currencies; a bare `usd cad` or
a mixed `10 usd kg` stays a search. Explicit `to`, `in` and `->` retain their meaning. In
[calculator.md](features/calculator.md)'s evaluation order this belongs to step 7, currency
conversion. `fork-calculator-test` covers the shorthand, expressions, signs, missing rates and
ambiguous input.

### Dictionary history

Every completed lookup is saved on this Mac, including terms with no definition. The dictionary screen
shows recent lookups as soon as it opens; select one and press ↵ to look it up again, or ⌘↵ to open it
in Dictionary.app. The standalone **Dictionary History** command remains available for searching the
full list. History waits until typing settles before saving, keeps the newest spelling of each
case-insensitive term, and is capped at 200 entries in the app's Application Support directory. ⌃X
deletes one row; ⌃⇧X clears all entries after confirmation.

Where it reaches past [dictionary.md](features/dictionary.md):

- **Palette.** `.dictionaryHistory` is a `PaletteMode`, rendered by `DictionaryHistoryScreen` over
  `DictionaryHistoryList`. Like every other sub-screen it stays off the Tab ring and ⌘P leaves it
  alone. It is a seventh palette list beside the six [ui.md](ui.md) names, with the same shared
  `SectionHeader` and the same `.thinScrollbar()` + `.hideNativeScrollers()`.
- **Navigation.** The Dictionary screen is dismissed directly by ⌘Space, so closing a definition
  takes one press; that close resets the hidden palette to its root, so the next press always opens
  the launcher, even inside Pop to Root Search's delay. Escape from a directly summoned dictionary
  screen returns to the launcher; opened from a launcher result, it restores that search and
  selection. A non-empty query still clears before Escape leaves the screen.
- **Ownership.** `AppCore` owns `DictionaryHistoryStore` and `DictionarySession` alongside the
  stores and sessions [architecture.md](architecture.md) lists.
- **Commands.** Dictionary History is a command no feature switch governs, so Settings › Commands
  lists it beside Calculator History.
- **Backups.** Dictionary history never travels in a Tinycast backup or a Raycast import, as AI chat
  history does not: looked-up words stay on the Mac that had them.

| Harness | Guards |
| --- | --- |
| `dictionary-session-test` | `DictionarySession.swift` — rapid prefixes coalesce, no-result terms are saved, and reset cancels a pending lookup |
| `dictionary-history-test` | Local lookup-history persistence, case-insensitive deduplication, search, cap, removal and clearing |
| `fork-palette-test` | Escape, Tab and ⌘P on the dictionary screens |

`dictionary-session-test` waits for published lookup results with a bounded deadline. Query bursts
are submitted together so scheduler delays cannot turn a prefix into a settled query; cancellation
is checked while a separate session completes against the same history store.

The manual sweep in [testing.md](testing.md) gains these for the dictionary:

- The dictionary hotkey opens on recent lookups; Enter retries one and ⌘↵ opens Dictionary.app
- Typing `h`, `hy`, `hyp`, `hype` quickly records only `hype` after the query settles
- Escape from a directly summoned, empty dictionary screen returns to the launcher
- A completed lookup appears in Dictionary History, including a term with no definition
- Repeating a term with different letter case moves its single row to the top
- Search filters history; Enter reopens Tinycast's definition and ⌘↵ opens Dictionary.app
- ⌃X deletes one row; ⌃⇧X asks before clearing every lookup

### Reasoning efforts for AI gateways

Upstream shows reasoning efforts for installed routes and for OpenRouter models whose catalog
reports them, and gives a gateway only the synthesized `Default` and `None` pair that
[ai.md](features/ai.md) describes. This fork reads a catalog from any OpenAI-shaped endpoint.

A catalog is a `/models` entry whose `reasoning` lists `supported_efforts`, with an optional
`default_effort` — OpenRouter's contract, which any OpenAI-shaped endpoint, a gateway included, may
publish — or the same pair flattened to `reasoning_supported_efforts` and `reasoning_default_effort`,
as some gateways spell it. The editor keeps it per model for every provider, and refreshes the models
already added each time discovery loads, so a gateway that starts publishing efforts is picked up by
reopening and saving its connection. `AIConnection.httpConfiguration` names only a catalogued effort
— one the catalog no longer lists resolves to its `default_effort` — as OpenRouter's
`reasoning.effort` there and OpenAI's top-level `reasoning_effort` everywhere else. Of the
synthesized pair, still only `None` is ever written.

The chat's model switcher therefore offers efforts for any API model whose catalog reports them; a
gateway with no catalog keeps `Default` and `None`, and other API routes keep their provider default
because their catalogs publish no efforts. `fork-ai-test` covers the catalogued, stale, uncatalogued
and flattened cases.

### Content scale

Upstream's `InterfaceMetrics` stores one scale. Here it stores a frame scale and a content scale:
the content scale drives typography and launcher row icons, the frame scale keeps the panel
dimensions and spacing, so Large and Larger read bigger without the panel growing further.
`InterfaceSize` pairs them as 1 / 1, 1.1 / 1.2 and 1.2 / 1.3. `InterfaceMetrics(scale:)` still
builds and scales content with the frame, so an upstream call site compiles unchanged.
`fork-interface-test` covers the pairing.

### Releases

The fork publishes its own builds and reads its own release feed, so [release.md](release.md) and
the workflows it describes are upstream's and are not active here, and [testing.md](testing.md)'s
"there is no CI" is true of upstream only. [Automatic maintenance](#automatic-maintenance) and
[Builds and updates](#builds-and-updates) describe what runs instead.

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
There is no stored personal GitHub access token and no force push. A dedicated SSH deploy key grants
the final Homebrew job write access to `lemonteaau/homebrew-tinycast` only; it grants no access to other
repositories. It is stored as `HOMEBREW_TAP_DEPLOY_KEY` in this repository's Actions secrets. Tap access
is checked before building. The build/signing job never receives the tap key.

Two conflicts resolve themselves because the right answer is mechanical. `Tinycast.xcodeproj` is
regenerated with XcodeGen from the merged `project.yml`. `Scripts/run-tests.sh` merges as a union,
since both sides append harnesses to one list; if that leaves one harness registered twice, the
merge aborts instead. Any other conflict aborts the merge and lists its files in the run summary:
merge upstream by hand and push to `main`, and that push releases it.
[Keeping the sync quiet](#keeping-the-sync-quiet) is what keeps this rare.

Tests, lint, a Debug build and a signed Release build must all pass before a merge is pushed to
`main`. `Scripts/fork-test.sh` runs the suite and retries each failed harness once on its own: the
runner's few cores starve timing-sensitive harnesses while the others compile. A retried harness
leaves a "Flaky harness" warning on the run, and one that fails alone too fails the run. The final
push verifies that `main` has not moved during the build; if it has, the run ends without releasing
and the run queued by that push releases instead. An unsuccessful run leaves the last published
release available.
If publishing fails after the push, rerun the failed workflow; an unpublished commit is built again.
Draft releases are uploaded completely before being published. An already released commit skips the
build only when its official base version still matches upstream; Homebrew synchronization still runs
to repair an interrupted publication.

The sync and release happen in the same workflow: a push using `GITHUB_TOKEN` does not need to trigger
another workflow. `Tests/fork-sync-test.sh` exercises successful merges, harness-list unions,
project regeneration, workflow isolation, idempotence and conflict rollback in temporary Git
repositories.

## Keeping the sync quiet

Upstream lands several commits a day, so every line the fork edits inside one of upstream's files is
a line the two can collide on. A fork change stays in files the fork owns wherever it can:

- **Documentation goes in this file**, never into upstream's `docs/`, `website/` or `AGENTS.md`. The
  one exception is the banner at the top of `README.md`, which tells a visitor this is a fork.
- **A fork test is a harness of its own**, named `fork-*-test` (the two dictionary harnesses predate
  the prefix). An upstream harness is edited only where it asserts behaviour the fork changed:
  `interface-size-test` follows the content scale in two lines, and `form-input-test` is pinned to
  Dark because its ink scan fails under the Light appearance CI runners use — an upstream defect
  rather than a fork difference.
- **Shipped code adds rather than changes** where it has the choice: a new file, a new case, an
  argument with a default. `InterfaceMetrics(scale:)` keeps building for that reason.

`git diff <upstream> main --stat` is the measure: a path that is upstream's and appears there is
conflict surface.

## Builds and updates

The app's macOS version matches the latest official stable release exactly (currently `0.11.3`).
Fork release tags and download filenames append `-fork.N`, where N is the Actions run number:
`v0.11.3-fork.2` means official version `0.11.3`, fork build 2. The bundle build number matches N,
allowing the in-app updater to distinguish successive fork builds even when upstream does not bump
its version. Beside the shapes [updates.md](features/updates.md) lists, `AppVersion` parses this
fork's stable `MAJOR.MINOR.PATCH-fork.N`: a fork build follows its official triple and precedes a
newer triple, and `fork-updates-test` covers the parsing and ordering. Each release identifies the
upstream commit and exact fork source commit.
`Scripts/fork-release-notes.sh` writes the notes from Git history since the previous published
release: the fork's own commits with their full messages (trailers dropped), then the upstream
commits merged in, linked to their upstream pull requests and capped at 40. Both sit above
`<!-- tinycast:install -->`, so the in-app update window shows them; the build and install details
go below it. `Tests/fork-release-notes-test.sh` covers the ranges, escaping and links.
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
Later fork updates use the normal in-app updater or the named Homebrew upgrade command below.

## Homebrew publication

Release publication immediately calls the tap's reusable workflow, pinned to a reviewed commit. It
downloads the latest stable release's DMG, verifies it against `SHA256SUMS.txt`, updates the cask and
checks the remote result. The caller passes this run's release version: a stale GitHub latest-release
response cannot satisfy a newer release and is retried before failing. The overall release workflow
is green only after this job succeeds.
If the job fails, the app release remains available, but the workflow is red: use **Re-run failed jobs**
to retry just the cask job without rebuilding the app. The tap's **Refresh fork cask → Run workflow**
also repairs the latest release independently. Its daily 21:31 UTC schedule is a fallback, not the
normal delivery path. Repeated runs create no duplicate commits, concurrent push failures retry from
the latest remote state, and version/checksum guards prevent rollback or silent asset replacement.

The tap stays separate so existing installations keep the same name and remote. Merging it into the
source repository would require a tap migration and mix generated catalog commits into upstream
merges. The dedicated deploy key avoids a personal access token or a second account. It does not
expire automatically; if it is revoked (including through deauthorization of the GitHub CLI credential
that created it), the preflight check fails before a new release is built. Replace the tap's public
deploy key and this repository's matching secret together. Never store its private key in Git.

Once the release workflow succeeds, refresh your Mac's local catalog and upgrade explicitly:

```sh
brew update
brew upgrade --cask tinycast-fork
```

`auto_updates true` remains set because the app has its own updater. A plain `brew upgrade` can skip
such casks; explicitly naming `tinycast-fork` is supported. Updating the remote tap cannot force an
already installed Homebrew client to refresh its local catalog or install a new app.

## Signing

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
