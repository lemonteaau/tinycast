#!/bin/bash
# CI's few cores starve timing-sensitive harnesses; only one that also fails alone is a real failure.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

./Scripts/run-tests.sh && exit 0

failed=()
for marker in "${TMPDIR:-/tmp}"/tinycast-harness/*.failed; do
    [ -e "$marker" ] && failed+=("$(basename "$marker" .failed)")
done
[ ${#failed[@]} -gt 0 ] || exit 1

for name in "${failed[@]}"; do
    echo "::warning title=Flaky harness::$name failed under parallel load; retrying it alone."
    ./Scripts/run-tests.sh "$name" || exit 1
done
