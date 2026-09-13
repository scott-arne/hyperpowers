#!/usr/bin/env bash
# Prose contracts for skills whose behavior-shaping wording has no other
# test: dispatching-parallel-agents' collection contract, writing-skills'
# pruning rules.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DPA="$REPO_ROOT/skills/dispatching-parallel-agents/SKILL.md"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

assert_contains() {
  local file="$1"
  local needle="$2"
  local description="$3"
  local haystack

  haystack="$(tr '\n\t' '  ' <"$file" | sed 's/  */ /g')"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    pass "$description"
  else
    fail "$description"
    echo "    expected to find: $needle"
    echo "    in: $file"
  fi
}

assert_file_exists() {
  local file="$1"
  local description="$2"
  if [ -f "$file" ]; then
    pass "$description"
  else
    fail "$description"
    echo "    missing: $file"
  fi
}

echo "=== skill prose contracts ==="
echo ""

# --- A8 delegation completion contract -----------------------------------
assert_contains "$DPA" "**You own collection.**" \
  "section 4 opens with the collection contract"
assert_contains "$DPA" "A dispatched agent that has not been collected and integrated is not finished work." \
  "an uncollected agent is not finished work"
assert_contains "$DPA" "Never end your turn with children still running" \
  "the turn does not end with children running"
assert_contains "$DPA" "a child that completes after your turn ends has no parent to report to, and its result is orphaned" \
  "a late child's result is orphaned"
assert_contains "$DPA" "Wait, reconcile, then return." \
  "the contract is wait, reconcile, return"
assert_contains "$DPA" 'every child finished, and every result was lost' \
  "the observed failure is recorded"
assert_contains "$DPA" 'spawned children and returned "waiting" as their final answer' \
  "the named failure is returning waiting as the final answer"

echo ""
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
