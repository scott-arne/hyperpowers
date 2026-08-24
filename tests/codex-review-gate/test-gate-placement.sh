#!/usr/bin/env bash
#
# Placement check for the split Codex review gate.
#
# test-gate-split-lossless.sh proves nothing was lost; this proves the
# content went to the right places. Without it, dumping all nine sections
# into one sibling would still pass every other check.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE_DIR="$REPO_ROOT/skills/requesting-code-review"

failures=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

assert_in() {
    local file="$1" needle="$2" description="$3"
    if [ ! -f "$GATE_DIR/$file" ]; then
        fail "$description (missing file: $file)"
        return
    fi
    if grep -Fq -- "$needle" "$GATE_DIR/$file"; then
        pass "$description"
    else
        fail "$description"
        echo "    expected in $file: $needle"
    fi
}

echo "=== gate section placement ==="
echo ""

assert_in gate-preflight.md '## 1. Preflight availability' 'preflight section lives in gate-preflight.md'
assert_in gate-preflight.md '## 2. No-Codex notice' 'no-Codex notice lives in gate-preflight.md'
assert_in gate-setup.md 'scripts/codex-review-dir' 'GATE_DIR helper lives in gate-setup.md'
assert_in gate-setup.md 'scripts/review-dossier' 'dossier assembly lives in gate-setup.md'
assert_in gate-lenses.md 'Round 1 is a lens fan-out' 'lens fan-out lives in gate-lenses.md'
assert_in gate-lenses.md 'Lens charters:' 'lens charter table lives in gate-lenses.md'
assert_in recipe-document.md 'Round-1 Algorithm Assessment (plan gate only)' 'algorithm assessment lives in recipe-document.md'
assert_in recipe-code.md 'launch detached, watch in the foreground' 'detached-launch discipline lives in recipe-code.md'
assert_in gate-output-schema.md '### Required document-review output' 'output schema lives in gate-output-schema.md'
assert_in gate-findings.md '## 4. Interpret — severity mapping' 'severity ladder lives in gate-findings.md'
assert_in gate-findings.md '## 4b. Completion check' 'completion check lives in gate-findings.md'
assert_in gate-fix-loop.md '## 5. Fix-and-re-review loop' 'fix loop lives in gate-fix-loop.md'
assert_in gate-fix-loop.md '## 6. Hand back' 'hand-back lives in gate-fix-loop.md'
assert_in gate-sweep.md '## 7. Review sweep' 'review sweep lives in gate-sweep.md'

# The index is a router, not a container: no section body may remain in it.
index="$GATE_DIR/codex-review-gate.md"
for needle in \
    '## 1. Preflight availability' \
    '## 3. Invoke Codex by artifact type' \
    '## 4. Interpret — severity mapping' \
    '## 5. Fix-and-re-review loop' \
    '## 7. Review sweep'; do
    if grep -Fq -- "$needle" "$index"; then
        fail "index no longer carries section bodies (found: $needle)"
    else
        pass "index no longer carries: $needle"
    fi
done

# Nothing over 150 lines — the whole point of the exercise.
for f in gate-preflight.md gate-setup.md gate-lenses.md recipe-document.md \
    recipe-code.md gate-output-schema.md gate-findings.md gate-fix-loop.md \
    gate-sweep.md; do
    if [ ! -f "$GATE_DIR/$f" ]; then
        fail "$f is under 150 lines (missing)"
        continue
    fi
    n="$(wc -l <"$GATE_DIR/$f" | tr -d ' ')"
    if [ "$n" -le 150 ]; then
        pass "$f is $n lines (<= 150)"
    else
        fail "$f is $n lines (> 150)"
    fi
done

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
