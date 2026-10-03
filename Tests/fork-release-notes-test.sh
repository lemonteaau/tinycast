#!/bin/bash
set -euo pipefail
script=$(cd "$(dirname "$0")/.." && pwd)/Scripts/fork-release-notes.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

commit() {
    local file; file=$(git branch --show-current)
    echo "$RANDOM" >> "$file"; git add "$file"; git commit -q -m "$1"
}
notes() { VERSION=1.0.0-fork.2 UPSTREAM_VERSION=1.0.0 UPSTREAM=$(git rev-parse upstream) \
    "$script" "$scratch/notes.md" >/dev/null; }
has() { grep -qF -- "$1" "$scratch/notes.md" || { echo "missing: $1" >&2; cat "$scratch/notes.md" >&2; exit 1; }; }
lacks() { ! grep -qF -- "$1" "$scratch/notes.md" || { echo "unexpected: $1" >&2; exit 1; }; }

git init -q -b main "$scratch/repo"
cd "$scratch/repo"
commit 'Old upstream change (#1)'
git branch upstream
commit 'Old fork change'
git tag v1.0.0-fork.1

git checkout -q upstream
commit 'Render <img> tags (#12)'
git checkout -q main
commit "$(printf 'Fix the gateway effort\n\nThe body wraps\nacross lines.\n\n- one item\n\nCo-Authored-By: Bot <b@example.invalid>')"
git merge -q --no-ff -m 'Merge upstream main' upstream

PREVIOUS=v1.0.0-fork.1 notes
has '## Fork changes'
has '- **Fix the gateway effort** (['
has '  The body wraps across lines.'
has '  - one item'
lacks 'Co-Authored-By'
lacks 'Merge upstream main'
has '## Upstream changes'
has '- Render \<img> tags ([#12](https://github.com/abue-ammar/tinycast/pull/12))'
lacks 'Old upstream change'
lacks 'Old fork change'
has 'Full changelog: https://github.com/lemonteaau/tinycast/compare/v1.0.0-fork.1...'
test "$(grep -c '<!-- tinycast:install -->' "$scratch/notes.md")" = 1
has 'Personal Tinycast fork build 1.0.0-fork.2, based on upstream 1.0.0.'

PREVIOUS=v9.9.9-missing notes 2>/dev/null
has 'Old fork change'
lacks '## Upstream changes'
lacks 'Full changelog'

git tag v1.0.0-fork.2
PREVIOUS=v1.0.0-fork.2 notes
has 'Rebuilt for upstream 1.0.0; no source changes since v1.0.0-fork.2.'

echo 'Fork release notes: fork bodies, upstream PR links, escaping and ranges passed.'
