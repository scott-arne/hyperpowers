#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UL="$REPO_ROOT/skills/requesting-code-review/scripts/ungated-ledger"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $1)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/ul-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
base_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
head_sha="$(git -C "$repo" rev-parse HEAD)"

echo "ungated-ledger:"

# append a sweepable code-gate event
out="$(bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status stale-broker --note 'gate ran degraded' "$repo")"
expect "$out" '"ok":true' "code-gate append ok"
id1="$(printf '%s' "$out" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"

# ledger file exists under the sdd-dir-compatible key
key="$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)"
[ -f "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" ] && pass "ledger at derived key path" || fail "ledger at derived key path"
[ ! -d "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.lock" ] && pass "lock released after append" || fail "lock released after append"

# doc-gate append: sweepable false, no base/head required
out="$(bash "$UL" append --class degraded-gate --gate spec --status not-ready --note 'doc gate degraded' "$repo")"
expect "$out" '"ok":true' "doc-gate append ok"
grep -q '"sweepable":false' "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" && pass "doc event sweepable:false" || fail "doc event sweepable:false"

# sweepable gate without base/head -> usage error (exit 2)
bash "$UL" append --class backstop-fix --gate task --note x "$repo" >/dev/null 2>&1 && fail "missing base/head exits 2" || pass "missing base/head exits 2"

# pending: only the sweepable event counts
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":1' "pending count excludes unsweepable"
expect "$out" '"skipped":0' "skipped is zero on clean ledger"
out="$(bash "$UL" pending "$repo")"
expect "$out" "$id1" "pending list carries the event id"
expect "$out" '"status":"stale-broker"' "pending carries status token"

# mark-swept closes it
out="$(bash "$UL" mark-swept --ref "$id1" --verdict approved --note 'sweep clean' "$repo")"
expect "$out" '"ok":true' "mark-swept ok"
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":0' "pending zero after sweep"
[ ! -d "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.lock" ] && pass "lock released after mark-swept" || fail "lock released after mark-swept"

# corrupt line tolerance: skipped counted, count still right
out="$(bash "$UL" append --class incomplete-review --gate final --base "$base_sha" --head "$head_sha" --note 'incomplete' "$repo")"
expect "$out" '"ok":true' "third append ok"
echo '{not json' >> "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl"
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":1' "count correct despite corrupt line"
expect "$out" '"skipped":1' "corrupt line reported in skipped"

# concurrent appends: both events present, file stays valid JSONL (+1 corrupt)
( bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status not-ready --note A "$repo" >/dev/null ) &
( bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status not-ready --note B "$repo" >/dev/null ) &
wait
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":3' "concurrent appends both recorded"

# stale lock takeover: pre-create an old lockdir with a foreign owner, append must still succeed
lock="$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.lock"
mkdir -p "$lock"
printf 'foreign-token' > "$lock/owner"
touch -t "$(date -v-1H +%Y%m%d%H%M 2>/dev/null || date -d '1 hour ago' +%Y%m%d%H%M)" "$lock"
out="$(bash "$UL" append --class degraded-gate --gate plan --status not-installed --note stale-lock-case "$repo")"
expect "$out" '"ok":true' "append succeeds via stale-lock takeover"
grep -q 'lock takeover' "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" && pass "takeover noted in event" || fail "takeover noted in event"

# paused-owner release guard: create a foreign-owned lock, run a reader, verify lock untouched
lockpath="$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.lock"
mkdir -p "$lockpath"
printf 'other-writer' > "$lockpath/owner"
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":' "reader succeeds despite foreign lock"
[ -d "$lockpath" ] && pass "foreign lock untouched by reader" || fail "foreign lock untouched by reader"
[ "$(cat "$lockpath/owner" 2>/dev/null)" = "other-writer" ] && pass "foreign owner token intact" || fail "foreign owner token intact"
rm -rf "$lockpath"

# worktree anchoring (spec 4.4 / acceptance 4 substrate): a linked worktree
# derives a DIFFERENT key, so sweep closures must pass the source repo
# explicitly. Prove: explicit-repo mark-swept closes the source entry and
# creates nothing under the worktree's key.
out="$(bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status not-ready --note wt-case "$repo")"
idw="$(printf '%s' "$out" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
wt="$work/wt"; git -C "$repo" worktree add --detach "$wt" >/dev/null 2>&1
wkey="$(printf '%s' "$(git -C "$wt" rev-parse --absolute-git-dir)" | git -C "$wt" hash-object --stdin)"
[ "$wkey" != "$key" ] && pass "worktree derives a different key" || fail "worktree derives a different key"
before="$(bash "$UL" pending --count "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
( cd "$wt" && bash "$UL" mark-swept --ref "$idw" --verdict approved --note swept-from-worktree "$repo" >/dev/null )
after="$(bash "$UL" pending --count "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
[ "$after" -eq $((before - 1)) ] && pass "explicit repo-dir closes the SOURCE entry from worktree cwd" || fail "explicit repo-dir closes the SOURCE entry (before=$before after=$after)"
[ ! -e "$XDG_CACHE_HOME/hyperpowers/ungated/$wkey" ] && pass "nothing created under the worktree key" || fail "nothing created under the worktree key"
git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || true

# not a git repo -> exit 2
bash "$UL" pending --count "$work" >/dev/null 2>&1 && fail "non-repo exits 2" || pass "non-repo exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
