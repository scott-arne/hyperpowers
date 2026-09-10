#!/usr/bin/env bash
# codex-broker-sweep: finds the two ways a codex-plugin-cc broker gets left
# behind — a state record whose endpoint no longer answers, and a live broker
# whose working directory is gone — reports them, and with --kill clears the
# record and shuts the broker down through its own protocol. A live broker
# whose working directory still exists is never touched: that is a peer
# session's broker, not a leak. A live broker no record names is reported only
# under --include-unreferenced, because a hand-deleted record leaves a healthy
# peer looking unreferenced.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SWEEP="$REPO_ROOT/skills/requesting-code-review/scripts/codex-broker-sweep"
FAKE="$SCRIPT_DIR/fixtures/app-server-broker.mjs"
FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
T="$(mktemp -d "${TMPDIR:-/tmp}/broker-sweep.XXXXXX")"
pids=""
cleanup() { for p in $pids; do kill -KILL "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT

# The fake broker writes its own pid: `$!` on a backgrounded compound command
# names the intermediate subshell, so the pid the sweep prints would not match.
spawn() {
  local name="$1"
  mkdir -p "$T/$name-cwd"
  ( cd "$T/$name-cwd" && exec node "$FAKE" serve --endpoint "unix:$T/$name.sock" --pid-file "$T/$name.pid" >/dev/null 2>&1 ) &
  disown 2>/dev/null  # otherwise the SIGKILL in cleanup prints a job notice after the status line
  local i=0
  while [ ! -s "$T/$name.pid" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
  [ -s "$T/$name.pid" ] || { echo "the $name fake broker never started"; exit 1; }
  pids="$pids $(cat "$T/$name.pid")"
}

state="$T/state"
# 1. A stale record: the endpoint's socket does not exist.
mkdir -p "$state/stale-1111111111111111"
printf '{"endpoint":"unix:%s/gone.sock","pid":999999,"sessionDir":"%s/gone"}\n' "$T" "$T" > "$state/stale-1111111111111111/broker.json"
# 2. A live fake broker whose working directory still exists (a peer): must be left alone.
spawn peer
# 3. A live fake broker whose working directory has been removed (an orphan): must be reported and shut down.
spawn orphan
# 4. A live fake broker with a living cwd that no record names: safe by default, reported only on request.
spawn unref
peer_pid=$(cat "$T/peer.pid"); orphan_pid=$(cat "$T/orphan.pid"); unref_pid=$(cat "$T/unref.pid")
rmdir "$T/orphan-cwd" || { echo "cannot remove the orphan's cwd on this host"; exit 1; }
mkdir -p "$state/peer-2222222222222222"
printf '{"endpoint":"unix:%s/peer.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$peer_pid" "$T" > "$state/peer-2222222222222222/broker.json"

out="$(bash "$SWEEP" --state-root "$state" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "dry run exits 0" || fail "dry run exits 0 (rc=$rc): $out"
printf '%s\n' "$out" | grep -q "stale-record .*stale-1111111111111111" && pass "a record whose endpoint is dead is reported as stale" || fail "stale record reported: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$orphan_pid .*reason=cwd-missing" && pass "a live broker whose cwd is gone is reported as an orphan" || fail "orphan reported: $out"
printf '%s\n' "$out" | grep -q "pid=$peer_pid" && fail "a peer broker with a living cwd must not be reported" || pass "a peer broker with a living cwd is not reported"
printf '%s\n' "$out" | grep -q "pid=$unref_pid" && fail "an unreferenced but healthy broker must not be reported by default" || pass "an unreferenced but healthy broker is not reported by default"
[ -f "$state/stale-1111111111111111/broker.json" ] && pass "dry run removes nothing" || fail "dry run must not remove records"
kill -0 "$orphan_pid" 2>/dev/null && pass "dry run kills nothing" || fail "dry run must not stop brokers"

out="$(bash "$SWEEP" --include-unreferenced --state-root "$state" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "--include-unreferenced exits 0" || fail "--include-unreferenced exits 0 (rc=$rc): $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$unref_pid .*reason=unreferenced" && pass "--include-unreferenced reports the unreferenced broker" || fail "--include-unreferenced must report the unreferenced broker: $out"
printf '%s\n' "$out" | grep -q "pid=$peer_pid" && fail "--include-unreferenced must still leave the referenced peer alone" || pass "--include-unreferenced still leaves the referenced peer alone"

out="$(bash "$SWEEP" --kill --state-root "$state" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "--kill exits 0" || fail "--kill exits 0 (rc=$rc): $out"
sleep 1
[ ! -f "$state/stale-1111111111111111/broker.json" ] && pass "--kill clears the stale record" || fail "--kill must clear the stale record"
kill -0 "$orphan_pid" 2>/dev/null && fail "--kill must shut the orphan down" || pass "--kill shuts the orphan down through broker/shutdown"
kill -0 "$peer_pid" 2>/dev/null && pass "--kill leaves the peer broker running" || fail "--kill must leave the peer broker running"
kill -0 "$unref_pid" 2>/dev/null && pass "--kill without --include-unreferenced leaves the unreferenced broker running" || fail "--kill must not stop an unreferenced broker unless asked"
[ -f "$state/peer-2222222222222222/broker.json" ] && pass "--kill keeps the peer's record" || fail "--kill must keep the peer's record"

out="$(bash "$SWEEP" --state-root "$T/does-not-exist" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi 'no state root' && pass "a missing state root is reported, not an error" || fail "missing state root handling (rc=$rc): $out"

echo
if [ "$FAILURES" -eq 0 ]; then echo "STATUS: PASSED"; else echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
