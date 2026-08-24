#!/usr/bin/env bash
# Contract for the assembled-gate view used by the gate contract tests.
#
# The gate document is a dispatcher index plus section-file siblings. Tests
# that assert on gate CONTENT must see the whole gate, not just the index.
# This helper produces that view. It must behave correctly both before the
# split (index only, no links) and after (index plus every linked sibling).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASSEMBLE="$SCRIPT_DIR/assemble-gate.sh"

failures=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

TEST_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

echo "=== assemble-gate view test ==="
echo ""

# 1. Real repo: the assembled view is non-empty and starts with the index.
out="$TEST_ROOT/real.md"
if bash "$ASSEMBLE" "$REPO_ROOT" "$out"; then
    pass "assembler succeeds against the real repo"
else
    fail "assembler succeeds against the real repo"
fi
if head -1 "$out" | grep -Fq '# Codex Review Gate'; then
    pass "assembled view starts with the index heading"
else
    fail "assembled view starts with the index heading"
fi

# 2. Synthetic index with siblings: all linked files are concatenated in
#    link order, and the index itself comes first.
synth="$TEST_ROOT/synth/skills/requesting-code-review"
mkdir -p "$synth"
printf '# Codex Review Gate\n\n[gate-preflight.md](gate-preflight.md)\n[gate-sweep.md](gate-sweep.md)\n' \
    >"$synth/codex-review-gate.md"
printf 'PREFLIGHT_NEEDLE\n' >"$synth/gate-preflight.md"
printf 'SWEEP_NEEDLE\n' >"$synth/gate-sweep.md"
synth_out="$TEST_ROOT/synth.md"
bash "$ASSEMBLE" "$TEST_ROOT/synth" "$synth_out"
if grep -Fq 'PREFLIGHT_NEEDLE' "$synth_out" && grep -Fq 'SWEEP_NEEDLE' "$synth_out"; then
    pass "assembled view includes every linked sibling"
else
    fail "assembled view includes every linked sibling"
fi
if [ "$(grep -n 'PREFLIGHT_NEEDLE' "$synth_out" | cut -d: -f1)" -lt \
     "$(grep -n 'SWEEP_NEEDLE' "$synth_out" | cut -d: -f1)" ]; then
    pass "siblings are concatenated in link order"
else
    fail "siblings are concatenated in link order"
fi

# 3. A dangling link is an error, not a silent omission. This is the
#    property that stops a renamed sibling from quietly dropping content
#    out of every content assertion downstream.
printf '# Codex Review Gate\n\n[missing.md](missing.md)\n' >"$synth/codex-review-gate.md"
if bash "$ASSEMBLE" "$TEST_ROOT/synth" "$TEST_ROOT/dangling.md" >/dev/null 2>&1; then
    fail "assembler fails on a dangling sibling link"
else
    pass "assembler fails on a dangling sibling link"
fi

# 4. A write failure is an error, not a silent success. This helper's whole
#    job is to hand the contract tests a real assembled view; reporting
#    success while producing nothing would disarm every content assertion
#    downstream without failing anything visible.
if bash "$ASSEMBLE" "$REPO_ROOT" "$TEST_ROOT/no-such-dir/out.md" >/dev/null 2>&1; then
    fail "assembler fails when the output cannot be written"
else
    pass "assembler fails when the output cannot be written"
fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
