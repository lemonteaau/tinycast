#!/bin/bash
# Compose a fork release body from the commits since the previous fork release.
# Usage: VERSION=… UPSTREAM_VERSION=… UPSTREAM=<sha> [PREVIOUS=<tag>] ./Scripts/fork-release-notes.sh <out.md>
set -euo pipefail

OUT="${1:?usage: fork-release-notes.sh <out.md>}"
VERSION="${VERSION:?VERSION is required, e.g. 0.11.12-fork.33}"
UPSTREAM_VERSION="${UPSTREAM_VERSION:?UPSTREAM_VERSION is required}"
UPSTREAM="$(git rev-parse --verify "${UPSTREAM:?UPSTREAM commit is required}^{commit}")"
PREVIOUS="${PREVIOUS:-}"
REPO="${REPO:-lemonteaau/tinycast}"
UPSTREAM_REPO="${UPSTREAM_REPO:-abue-ammar/tinycast}"
HEAD_SHA="$(git rev-parse HEAD)"

# The update window shows only what is above this; ReleaseNotes.summary is its reader.
MARKER='<!-- tinycast:install -->'
# A first sync after a long gap would otherwise push the fork's own changes off the window.
UPSTREAM_LIMIT=40

if [ -n "$PREVIOUS" ] && ! git rev-parse -q --verify "$PREVIOUS^{commit}" >/dev/null; then
    echo "Previous release $PREVIOUS is not in this clone; listing fork commits only." >&2
    PREVIOUS=''
fi

# A bare `<tag>` in a subject is raw HTML to GitHub and disappears from the page.
escape() { sed 's/</\\</g'; }

# Hard-wrapped body paragraphs become one line each, indented to stay inside their bullet.
render_body() {
    awk '
        function flush() {
            if (text == "") return
            if (kind == "item" && last == "item") printf "  %s\n", text
            else printf "\n  %s\n", text
            last = kind; text = ""
        }
        tolower($0) ~ /^[a-z-]+-by: / { next }
        /^[ \t]*$/ { flush(); last = ""; next }
        /^[ \t]*[-*+] / { flush(); sub(/^[ \t]+/, ""); kind = "item"; text = $0; next }
        { sub(/^[ \t]+/, ""); if (text == "") kind = "para"; text = (text == "" ? $0 : text " " $0) }
        END { flush() }
    '
}

fork_commits="$(git log --no-merges --format=%H HEAD --not "$UPSTREAM" ${PREVIOUS:+"$PREVIOUS"})"
upstream_total=0
if [ -n "$PREVIOUS" ]; then
    upstream_total="$(git rev-list --no-merges --count "$UPSTREAM" --not "$PREVIOUS")"
fi

{
    if [ -n "$fork_commits" ]; then
        printf '## Fork changes\n\n'
        for sha in $fork_commits; do
            subject="$(git show -s --format=%s "$sha" | escape)"
            printf -- '- **%s** ([%s](https://github.com/%s/commit/%s))\n' \
                "$subject" "${sha:0:7}" "$REPO" "$sha"
            git show -s --format=%b "$sha" | escape | render_body
            printf '\n'
        done
    fi

    if [ "$upstream_total" -gt 0 ]; then
        printf '## Upstream changes\n\n'
        git log --no-merges --format=%s -n "$UPSTREAM_LIMIT" "$UPSTREAM" --not "$PREVIOUS" \
            | escape \
            | sed -E "s|\(#([0-9]+)\)|([#\1](https://github.com/$UPSTREAM_REPO/pull/\1))|g; s|^|- |"
        if [ "$upstream_total" -gt "$UPSTREAM_LIMIT" ]; then
            printf -- '- …and %s more in the full changelog.\n' "$((upstream_total - UPSTREAM_LIMIT))"
        fi
        printf '\n'
    fi

    if [ -z "$fork_commits" ] && [ "$upstream_total" -eq 0 ]; then
        printf 'Rebuilt for upstream %s; no source changes%s.\n\n' \
            "$UPSTREAM_VERSION" "${PREVIOUS:+ since $PREVIOUS}"
    fi

    printf '%s\n\n' "$MARKER"
    printf 'Personal Tinycast fork build %s, based on upstream %s.\n\n' "$VERSION" "$UPSTREAM_VERSION"
    printf 'Upstream: https://github.com/%s/commit/%s\n' "$UPSTREAM_REPO" "$UPSTREAM"
    printf 'Source: https://github.com/%s/commit/%s\n' "$REPO" "$HEAD_SHA"
    if [ -n "$PREVIOUS" ]; then
        printf 'Full changelog: https://github.com/%s/compare/%s...%s\n' "$REPO" "$PREVIOUS" "$HEAD_SHA"
    fi
    printf '\nTests, lint, Debug build and signed arm64 Release build passed.\n'
    printf 'macOS 26+, Apple silicon. Independently signed personal fork; not Apple-notarized.\n'
    printf 'First install replaces Tinycast.app and retains its settings. Grant Accessibility again if prompted.\n'
    printf 'Subsequent in-app updates come from this fork and use the same signing identity.\n'
    printf 'See docs/fork.md for installation, signing and sync details.\n'
} > "$OUT"

echo "✓ $OUT"
