#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/janitor-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

root="$work/state"

mk_broker() { # <dir> <socket> <pid> <sessiondir>
  mkdir -p "$1"
  printf '{"endpoint":"unix:%s","pidFile":"x","logFile":"x","sessionDir":"%s","pid":%s}\n' \
    "$2" "$4" "$3" > "$1/broker.json"
}

# dead broker (purged sessionDir)
mk_broker "$root/repoA-0000000000000000" "$work/gone/b.sock" $$ "$work/gone"
# healthy broker (live socket file + our own pid)
live="$work/live"; mkdir -p "$live"; touch "$live/b.sock"
mk_broker "$root/repoB-1111111111111111" "$live/b.sock" $$ "$live"
# malformed broker (unknown -> untouched)
mkdir -p "$root/repoC-2222222222222222"; echo '{oops' > "$root/repoC-2222222222222222/broker.json"
# old quarantined file (GC target) and a fresh one (kept)
mkdir -p "$root/repoD-3333333333333333"
touch "$root/repoD-3333333333333333/broker.json.stale-1000000000"
# backdate mtime 20 days
touch -t "$(date -v-20d +%Y%m%d%H%M 2>/dev/null || date -d '20 days ago' +%Y%m%d%H%M)" \
  "$root/repoD-3333333333333333/broker.json.stale-1000000000"
touch "$root/repoD-3333333333333333/broker.json.stale-9999999999"

echo "broker janitor:"

export HYPERPOWERS_BROKER_CMD_PATTERN='bash|test-broker-janitor'
out="$(HYPERPOWERS_CODEX_STATE_ROOT="$root" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null)"

# stdout is still the hook's JSON context (unchanged contract)
printf '%s' "$out" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null \
  && pass "hook stdout is still valid JSON" || fail "hook stdout is still valid JSON"
printf '%s' "$out" | grep -q "hookSpecificOutput" && pass "bootstrap context still emitted" || fail "bootstrap context still emitted"

[ ! -f "$root/repoA-0000000000000000/broker.json" ] && pass "dead broker quarantined" || fail "dead broker quarantined"
ls "$root/repoA-0000000000000000"/broker.json.stale-* >/dev/null 2>&1 && pass "quarantine file created" || fail "quarantine file created"
[ -f "$root/repoB-1111111111111111/broker.json" ] && pass "healthy broker untouched" || fail "healthy broker untouched"
[ -f "$root/repoC-2222222222222222/broker.json" ] && pass "unknown schema untouched" || fail "unknown schema untouched"
[ ! -f "$root/repoD-3333333333333333/broker.json.stale-1000000000" ] && pass "old quarantine GCed" || fail "old quarantine GCed"
[ -f "$root/repoD-3333333333333333/broker.json.stale-9999999999" ] && pass "fresh quarantine kept" || fail "fresh quarantine kept"

# absent state root: hook still works
out2="$(HYPERPOWERS_CODEX_STATE_ROOT="$work/absent" HYPERPOWERS_BROKER_CMD_PATTERN='bash|test-broker-janitor' CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null)"
printf '%s' "$out2" | grep -q "hookSpecificOutput" && pass "no-op when root absent" || fail "no-op when root absent"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
