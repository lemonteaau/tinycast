#!/bin/bash
set -euo pipefail
source_script=$(cd "$(dirname "$0")/.." && pwd)/Scripts/fork-sync.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
mkdir "$scratch/bin"
printf '#!/bin/bash\n{ echo generated; cat project.yml; } > Tinycast.xcodeproj/project.pbxproj\n' \
    > "$scratch/bin/xcodegen"
chmod +x "$scratch/bin/xcodegen"
export PATH="$scratch/bin:$PATH"

git init -q -b main "$scratch/upstream"
cd "$scratch/upstream"
mkdir -p .github/workflows
echo upstream > .github/workflows/release.yml
echo original > calculator
mkdir Scripts Tinycast.xcodeproj
printf 'run alpha-test a\nrun beta-test b\nrun gamma-test c\nrun omega-test z\n' > Scripts/run-tests.sh
printf 'a: 1\nmiddle\nb: 1\n' > project.yml
echo initial > Tinycast.xcodeproj/project.pbxproj
git add .
git commit -qm initial
git clone -q "$scratch/upstream" "$scratch/fork"
cd "$scratch/fork"
cp "$source_script" Scripts/fork-sync.sh
rm .github/workflows/release.yml
echo fork > .github/workflows/fork-maintenance.yml
echo shorthand > calculator
printf 'run alpha-test a\nrun fork-test f\nrun beta-test b\nrun gamma-test c\nrun omega-test z fz\n' \
    > Scripts/run-tests.sh
printf 'a: fork\nmiddle\nb: 1\n' > project.yml
echo fork > Tinycast.xcodeproj/project.pbxproj
git add .
git commit -qm customization

cd "$scratch/upstream"
echo changed-upstream > .github/workflows/release.yml
echo extra-upstream > .github/workflows/new.yml
echo upstream-fix > unrelated
printf 'run alpha-test a\nrun upstream-test u\nrun beta-test b\nrun gamma-test c\nrun omega-test z\n' \
    > Scripts/run-tests.sh
printf 'a: 1\nmiddle\nb: upstream\n' > project.yml
echo upstream > Tinycast.xcodeproj/project.pbxproj
git add .
git commit -qm upstream-fix
cd "$scratch/fork"
GITHUB_OUTPUT="$scratch/output" bash Scripts/fork-sync.sh "$scratch/upstream"
test "$(cat calculator)" = shorthand
test "$(cat unrelated)" = upstream-fix
grep -qx 'run fork-test f' Scripts/run-tests.sh
grep -qx 'run upstream-test u' Scripts/run-tests.sh
test "$(cat Tinycast.xcodeproj/project.pbxproj)" = "$(printf 'generated\na: fork\nmiddle\nb: upstream')"
test "$(cat .github/workflows/fork-maintenance.yml)" = fork
test ! -e .github/workflows/release.yml
test ! -e .github/workflows/new.yml
git merge-base --is-ancestor "$(git -C "$scratch/upstream" rev-parse HEAD)" HEAD
head=$(git rev-parse HEAD)
bash Scripts/fork-sync.sh "$scratch/upstream"
test "$(git rev-parse HEAD)" = "$head"
test -z "$(git status --porcelain)"

cd "$scratch/upstream"
sed -i '' 's/^run omega-test z$/run omega-test z uz/' Scripts/run-tests.sh
git commit -qam same-harness
cd "$scratch/fork"
if bash Scripts/fork-sync.sh "$scratch/upstream" 2> "$scratch/stderr"; then
    echo 'A harness both sides changed was incorrectly accepted.' >&2
    exit 1
fi
grep -q 'same harness' "$scratch/stderr"
test "$(git rev-parse HEAD)" = "$head"
test -z "$(git status --porcelain)"
git -C "$scratch/upstream" reset -q --hard HEAD~

cd "$scratch/upstream"
echo conflicting-upstream > calculator
echo upstream-again > Tinycast.xcodeproj/project.pbxproj
git add calculator Tinycast.xcodeproj
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
echo 'Fork sync: upstream changes, harness lists, project regeneration, workflow isolation,' \
    'idempotence and conflict rollback passed.'
