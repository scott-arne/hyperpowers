#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BSD="$REPO_ROOT/skills/requesting-code-review/scripts/broker-state-dir"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/bsd-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# A fake git repo named "myrepo"
repo="$work/myrepo"
mkdir -p "$repo"; git -C "$repo" init -q
repo_real="$(cd "$repo" && pwd -P)"

# Fake state root
root="$work/state"; mkdir -p "$root"
export HYPERPOWERS_CODEX_STATE_ROOT="$root"

run() { bash "$BSD" "$repo"; }

echo "broker-state-dir:"

# no candidates -> absent
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "empty root -> absent" || fail "empty root -> absent (got $out)"

# one candidate with matching name shape -> found
mkdir -p "$root/myrepo-0123456789abcdef"
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"found"' && pass "single candidate -> found" || fail "single candidate -> found (got $out)"
printf '%s' "$out" | grep -Fq "myrepo-0123456789abcdef" && pass "returns candidate dir" || fail "returns candidate dir (got $out)"

# a dir with a non-hex or wrong-length suffix is not a candidate
mkdir -p "$root/myrepo-notahash" "$root/myrepo-0123"
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"found"' && pass "non-hash dirs ignored" || fail "non-hash dirs ignored (got $out)"

# two candidates, no state.json evidence -> absent (never guess)
mkdir -p "$root/myrepo-fedcba9876543210"
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "ambiguous -> absent" || fail "ambiguous -> absent (got $out)"

# two candidates, one state.json names this repo's workspaceRoot -> that one wins
cat > "$root/myrepo-fedcba9876543210/state.json" <<EOF
{ "version": 1, "jobs": [ { "id": "t1", "workspaceRoot": "$repo_real" } ] }
EOF
out="$(run)"
printf '%s' "$out" | grep -Fq "myrepo-fedcba9876543210" && pass "state.json disambiguates" || fail "state.json disambiguates (got $out)"

# sanitized basename (space in repo name): the state dir's name does not
# match the raw basename, but state.json evidence still resolves it
srepo="$work/my repo"
mkdir -p "$srepo"; git -C "$srepo" init -q
sreal="$(cd "$srepo" && pwd -P)"
mkdir -p "$root/my-repo-aaaaaaaaaaaaaaaa"
cat > "$root/my-repo-aaaaaaaaaaaaaaaa/state.json" <<EOF
{ "version": 1, "jobs": [ { "id": "t2", "workspaceRoot": "$sreal" } ] }
EOF
out="$(bash "$BSD" "$srepo")"
printf '%s' "$out" | grep -Fq "my-repo-aaaaaaaaaaaaaaaa" && pass "slug-sanitized basename found via evidence" || fail "slug-sanitized basename found via evidence (got $out)"

# not a git repo -> absent
out="$(bash "$BSD" "$work")"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "non-repo -> absent" || fail "non-repo -> absent (got $out)"

# missing state root -> absent
out="$(HYPERPOWERS_CODEX_STATE_ROOT="$work/nope" bash "$BSD" "$repo")"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "missing root -> absent" || fail "missing root -> absent (got $out)"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
