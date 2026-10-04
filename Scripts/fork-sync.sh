#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

project=Tinycast.xcodeproj/project.pbxproj
harnesses=Scripts/run-tests.sh

base=$(git rev-parse HEAD)
git diff --quiet
git diff --cached --quiet
git fetch --no-tags "${1:-https://github.com/abue-ammar/tinycast.git}" main
upstream=$(git rev-parse FETCH_HEAD)

abort() {
    git merge --abort
    echo "$1" >&2
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        printf '### %s\n\n%s\n' "$1" "${2:-}" >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 1
}

if ! git merge-base --is-ancestor "$upstream" HEAD; then
    # Both sides append harnesses to the same list, so keeping both is the resolution.
    attributes=$(mktemp)
    trap 'rm -f "$attributes"' EXIT
    echo "$harnesses merge=union" > "$attributes"
    git -c core.attributesFile="$attributes" merge --no-ff --no-commit "$upstream" || {
        if ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
            echo 'Upstream could not be merged.' >&2
            exit 1
        fi
    }
    # This fork owns its automation; upstream release and announcement jobs must not come back.
    git rm -rf --ignore-unmatch .github/workflows
    git checkout "$base" -- .github/workflows
    # The project is generated from project.yml, so regenerating it is always the right merge.
    unmerged=$(git diff --name-only --diff-filter=U)
    if grep -qxF "$project" <<< "$unmerged" && ! grep -qxF project.yml <<< "$unmerged"; then
        xcodegen generate --quiet || abort 'XcodeGen could not regenerate the merged project.'
        git add "$project"
    fi
    conflicts=$(git diff --name-only --diff-filter=U)
    if [ -n "$conflicts" ]; then
        echo "$conflicts" >&2
        abort 'Upstream conflict: no branch was pushed and no release was published.' \
            "Merge \`$upstream\` by hand and push to \`main\`. Conflicting files:
$(sed 's/^/- `/; s/$/`/' <<< "$conflicts")"
    fi
    duplicates=$(sed -nE 's/^run( (slow|-O|index))* ([^ ]+).*/\3/p' "$harnesses" | sort | uniq -d)
    if [ -n "$duplicates" ]; then
        abort 'Upstream and the fork both changed the same harness.' \
            "Resolve these entries in \`$harnesses\` by hand: $(tr '\n' ' ' <<< "$duplicates")"
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
