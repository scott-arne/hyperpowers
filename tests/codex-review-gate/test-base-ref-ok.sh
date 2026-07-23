#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BRO="$REPO_ROOT/skills/requesting-code-review/scripts/base-ref-ok"
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $1)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/bro-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

repo="$work/repo"; mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
base_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two

echo "base-ref-ok:"

expect "$(bash "$BRO" "$base_sha" "$repo")" '"ok":true'      "valid ancestor sha -> ok"
expect "$(bash "$BRO" "$base_sha" "$repo")" "$base_sha"      "ok carries resolvedBase"
expect "$(bash "$BRO" deadbeef "$repo")"    '"reason":"unresolvable"' "bogus ref -> unresolvable"
expect "$(bash "$BRO" "$EMPTY_TREE" "$repo")" '"reason":"empty-tree"' "empty-tree hash -> empty-tree (before peeling)"
expect "$(bash "$BRO" HEAD "$repo")"        '"reason":"empty-range"'  "HEAD as base -> empty-range"

# orphan branch -> no merge base
git -C "$repo" checkout -q --orphan lonely
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m orphan
expect "$(bash "$BRO" "$base_sha" "$repo")" '"reason":"no-merge-base"' "orphan history -> no-merge-base"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
