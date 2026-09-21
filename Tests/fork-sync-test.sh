#!/bin/bash
set -euo pipefail
source_script=$(cd "$(dirname "$0")/.." && pwd)/Scripts/fork-sync.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

git init -q -b main "$scratch/upstream"
cd "$scratch/upstream"
mkdir -p .github/workflows
echo upstream > .github/workflows/release.yml
echo original > calculator
git add .
git commit -qm initial
git clone -q "$scratch/upstream" "$scratch/fork"
cd "$scratch/fork"
mkdir Scripts
cp "$source_script" Scripts/fork-sync.sh
rm .github/workflows/release.yml
echo fork > .github/workflows/fork-maintenance.yml
echo shorthand > calculator
git add .
git commit -qm customization

cd "$scratch/upstream"
echo changed-upstream > .github/workflows/release.yml
echo extra-upstream > .github/workflows/new.yml
echo upstream-fix > unrelated
git add .
git commit -qm upstream-fix
cd "$scratch/fork"
GITHUB_OUTPUT="$scratch/output" bash Scripts/fork-sync.sh "$scratch/upstream"
test "$(cat calculator)" = shorthand
test "$(cat unrelated)" = upstream-fix
test "$(cat .github/workflows/fork-maintenance.yml)" = fork
test ! -e .github/workflows/release.yml
test ! -e .github/workflows/new.yml
git merge-base --is-ancestor "$(git -C "$scratch/upstream" rev-parse HEAD)" HEAD
head=$(git rev-parse HEAD)
bash Scripts/fork-sync.sh "$scratch/upstream"
test "$(git rev-parse HEAD)" = "$head"
test -z "$(git status --porcelain)"

cd "$scratch/upstream"
echo conflicting-upstream > calculator
git add calculator
git commit -qm conflict
cd "$scratch/fork"
if bash Scripts/fork-sync.sh "$scratch/upstream"; then
    echo 'Conflict was incorrectly accepted.' >&2
    exit 1
fi
test "$(git rev-parse HEAD)" = "$head"
test "$(cat calculator)" = shorthand
test -z "$(git status --porcelain)"
if git rev-parse -q --verify MERGE_HEAD; then
    echo 'Conflict left a merge in progress.' >&2
    exit 1
fi
echo 'Fork sync: upstream changes, workflow isolation, idempotence and conflict rollback passed.'
