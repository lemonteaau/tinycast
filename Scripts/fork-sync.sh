#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

base=$(git rev-parse HEAD)
git diff --quiet
git diff --cached --quiet
git fetch --no-tags "${1:-https://github.com/abue-ammar/tinycast.git}" main
upstream=$(git rev-parse FETCH_HEAD)

if ! git merge-base --is-ancestor "$upstream" HEAD; then
    git merge --no-ff --no-commit "$upstream" || {
        if ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
            echo 'Upstream could not be merged.' >&2
            exit 1
        fi
    }
    # This fork owns its automation; upstream release and announcement jobs must not come back.
    git rm -rf --ignore-unmatch .github/workflows
    git checkout "$base" -- .github/workflows
    if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
        git diff --name-only --diff-filter=U >&2
        git merge --abort
        echo 'Upstream conflict: no branch was pushed and no release was published.' >&2
        exit 1
    fi
    git commit -m "Merge upstream main (${upstream:0:12})"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "base=$base"
        echo "sha=$(git rev-parse HEAD)"
        echo "upstream=$upstream"
    } >> "$GITHUB_OUTPUT"
fi
