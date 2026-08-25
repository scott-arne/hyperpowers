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
#    link order, and the index itself comes first. The links are deliberately
#    NOT in alphabetical order — sweep before preflight — so an assembler
#    that sorted its discoveries would fail here instead of passing by
#    coincidence.
synth="$TEST_ROOT/synth/skills/requesting-code-review"
mkdir -p "$synth"
printf '# Codex Review Gate\n\n[gate-sweep.md](gate-sweep.md)\n[gate-preflight.md](gate-preflight.md)\n' \
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
if [ "$(grep -n 'SWEEP_NEEDLE' "$synth_out" | cut -d: -f1)" -lt \
     "$(grep -n 'PREFLIGHT_NEEDLE' "$synth_out" | cut -d: -f1)" ]; then
    pass "siblings are concatenated in link order (not alphabetical order)"
else
    fail "siblings are concatenated in link order (not alphabetical order)"
fi

# 3. A dangling link is an error, not a silent omission. This is the
#    property that stops a renamed sibling from quietly dropping content
#    out of every content assertion downstream. The diagnostic must name
#    the missing file: a bare non-zero exit could come from any failure
#    path in the script, so exit status alone does not prove this one ran.
printf '# Codex Review Gate\n\n[missing.md](missing.md)\n' >"$synth/codex-review-gate.md"
dangling_err="$(bash "$ASSEMBLE" "$TEST_ROOT/synth" "$TEST_ROOT/dangling.md" 2>&1 >/dev/null)"
dangling_status=$?
if [ "$dangling_status" -ne 0 ]; then
    pass "assembler fails on a dangling sibling link"
else
    fail "assembler fails on a dangling sibling link"
fi
if printf '%s' "$dangling_err" | grep -Fq 'index links a missing sibling: missing.md'; then
    pass "dangling-link failure names the missing sibling"
else
    fail "dangling-link failure names the missing sibling (got: $dangling_err)"
fi

# 3b. A same-directory .md link outside the lowercase-hyphen namespace is an
#     error, not a silent skip: the discovery pattern cannot parse it, so
#     without this guard its content would vanish from the assembled view
#     with the assembler still exiting 0.
printf '# Codex Review Gate\n\n[Bad_Name.md](Bad_Name.md)\n' >"$synth/codex-review-gate.md"
printf 'UNREACHABLE_NEEDLE\n' >"$synth/Bad_Name.md"
if bash "$ASSEMBLE" "$TEST_ROOT/synth" "$TEST_ROOT/badname.md" >/dev/null 2>&1; then
    fail "assembler fails on a link the discovery pattern cannot parse"
else
    pass "assembler fails on a link the discovery pattern cannot parse"
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
