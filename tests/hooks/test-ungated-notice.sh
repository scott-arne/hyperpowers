#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"
UL="$REPO_ROOT/skills/requesting-code-review/scripts/ungated-ledger"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/un-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
b="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
h="$(git -C "$repo" rev-parse HEAD)"

run_hook() { (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null); }

echo "ungated notice:"

# zero pending -> no notice, valid JSON
out="$(run_hook)"
printf '%s' "$out" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null \
  && pass "stdout valid JSON (zero pending)" || fail "stdout valid JSON (zero pending)"
printf '%s' "$out" | grep -q 'pending sweep' && fail "no notice at zero" || pass "no notice at zero"

# one pending -> notice present, still valid JSON
bash "$UL" append --class degraded-gate --gate task --base "$b" --head "$h" --status not-ready --note x "$repo" >/dev/null
out="$(run_hook)"
printf '%s' "$out" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null \
  && pass "stdout valid JSON (pending)" || fail "stdout valid JSON (pending)"
printf '%s' "$out" | grep -q '1 ungated review item' && pass "notice present with count" || fail "notice present with count (got no match)"
printf '%s' "$out" | grep -q 'hookSpecificOutput' && pass "bootstrap context intact" || fail "bootstrap context intact"

# non-repo cwd -> hook still works, no notice, no crash
out="$( (cd "$work" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null) )"
printf '%s' "$out" | grep -q 'hookSpecificOutput' && pass "non-repo cwd no-op" || fail "non-repo cwd no-op"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
