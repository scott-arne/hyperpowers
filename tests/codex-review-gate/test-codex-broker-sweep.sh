#!/usr/bin/env bash
# codex-broker-sweep reclaims codex-plugin-cc brokers that nothing will use
# again. It runs against other people's live processes, so the safety
# properties matter more than the reclamation: a peer's broker must survive, a
# pid read out of a stale record must never be signalled (pids get reused), a
# state of the world the sweep could not determine must be reported as
# unverifiable rather than acted on, and a broker that is retired must be asked
# to shut down over its own protocol before it is signalled.
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
  local name="$1" sock="${2:-$T/$1.sock}"; shift 2 2>/dev/null || shift
  mkdir -p "$T/$name-cwd"
  ( cd "$T/$name-cwd" && exec node "$FAKE" serve --endpoint "unix:$sock" \
      --pid-file "$T/$name.pid" --shutdown-marker "$T/$name.shutdown" "$@" >/dev/null 2>&1 ) &
  disown 2>/dev/null  # otherwise the SIGKILL in cleanup prints a job notice after the status line
  local i=0
  while [ ! -s "$T/$name.pid" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
  [ -s "$T/$name.pid" ] || { echo "the $name fake broker never started"; exit 1; }
  pids="$pids $(cat "$T/$name.pid")"
}

state="$T/state"
# A live process that is not a broker, standing in for the process that inherits
# a pid recorded in an old broker.json after the original exited.
sleep 600 & bystander=$!; disown 2>/dev/null; pids="$pids $bystander"

# 1. A stale record whose pid now belongs to that bystander.
mkdir -p "$state/stale-1111111111111111"
printf '{"endpoint":"unix:%s/gone.sock","pid":%s,"sessionDir":"%s/gone"}\n' "$T" "$bystander" "$T" > "$state/stale-1111111111111111/broker.json"
# 2. A stale record whose pid is 0 — signalling it would hit a whole process group.
mkdir -p "$state/zero-3333333333333333"
printf '{"endpoint":"unix:%s/gone2.sock","pid":0,"sessionDir":"%s/gone2"}\n' "$T" "$T" > "$state/zero-3333333333333333/broker.json"
# 3. A record that does not parse: a partial concurrent write or a newer schema.
mkdir -p "$state/malformed-4444444444444444"
printf '{"endpoint":"unix:%s/half.sock", "pid"' "$T" > "$state/malformed-4444444444444444/broker.json"
# 4. A live broker whose cwd exists and whose record is present: a peer.
spawn peer
# 5. A live broker whose cwd is removed below: an orphan.
spawn orphan
# 6. An orphan that accepts broker/shutdown and keeps running: the signal fallback.
spawn wedged "$T/wedged.sock" --ignore-shutdown
# 7. A live broker with a living cwd that no record names.
spawn unref
# 8. A live broker whose socket path contains a space: the endpoint cannot be
#    recovered unambiguously from ps output, so the sweep must not act on it.
mkdir -p "$T/spacey dir"
spawn spacey "$T/spacey dir/s.sock"
# 9. A live, healthy broker that carries its own record and whose pid an older
#    stale record ALSO names: the pid was reused after the broker that record
#    described exited. Its endpoint must come from the process, not the record.
spawn reused
peer_pid=$(cat "$T/peer.pid"); orphan_pid=$(cat "$T/orphan.pid"); wedged_pid=$(cat "$T/wedged.pid")
unref_pid=$(cat "$T/unref.pid"); spacey_pid=$(cat "$T/spacey.pid"); reused_pid=$(cat "$T/reused.pid")
mkdir -p "$state/reused-5555555555555555" "$state/stale-6666666666666666"
printf '{"endpoint":"unix:%s/reused.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$reused_pid" "$T" > "$state/reused-5555555555555555/broker.json"
printf '{"endpoint":"unix:%s/gone3.sock","pid":%s,"sessionDir":"%s/gone3"}\n' "$T" "$reused_pid" "$T" > "$state/stale-6666666666666666/broker.json"
rmdir "$T/orphan-cwd" "$T/wedged-cwd" || { echo "cannot remove an orphan's cwd on this host"; exit 1; }
mkdir -p "$state/peer-2222222222222222"
printf '{"endpoint":"unix:%s/peer.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$peer_pid" "$T" > "$state/peer-2222222222222222/broker.json"

echo "Dry run"
out="$(bash "$SWEEP" --state-root "$state" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "dry run exits 0" || fail "dry run exits 0 (rc=$rc): $out"
printf '%s\n' "$out" | grep -q "stale-record .*stale-1111111111111111" && pass "a record whose endpoint is dead is reported as stale" || fail "stale record reported: $out"
printf '%s\n' "$out" | grep -q "unknown-record .*malformed-4444444444444444" && pass "a record that does not parse is reported as unknown, not stale" || fail "malformed record reported as unknown: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$orphan_pid .*reason=cwd-missing" && pass "a live broker whose cwd is gone is reported as an orphan" || fail "orphan reported: $out"
printf '%s\n' "$out" | grep -q "pid=$peer_pid" && fail "a peer broker with a living cwd must not be reported" || pass "a peer broker with a living cwd is not reported"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$unref_pid" && fail "an unreferenced but healthy broker must not be an orphan by default" || pass "an unreferenced but healthy broker is not an orphan by default"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$spacey_pid" && pass "an endpoint that cannot be recovered from ps is unverifiable" || fail "spacey endpoint unverifiable: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$spacey_pid" && fail "an unrecoverable endpoint must never be an orphan" || pass "an unrecoverable endpoint is never treated as an orphan"
printf '%s\n' "$out" | grep -q "stale-record .*stale-6666666666666666" && pass "a stale record naming a reused pid is still reported as stale" || fail "stale record on a reused pid reported: $out"
printf '%s\n' "$out" | grep -qE "(orphan|unverifiable)-broker pid=$reused_pid" && fail "a healthy broker must not inherit the dead endpoint of a stale record naming its pid" || pass "a healthy broker does not inherit the dead endpoint of a stale record naming its pid"
[ -f "$state/stale-1111111111111111/broker.json" ] && pass "dry run removes nothing" || fail "dry run must not remove records"
kill -0 "$orphan_pid" 2>/dev/null && pass "dry run kills nothing" || fail "dry run must not stop brokers"
[ ! -f "$T/orphan.shutdown" ] && pass "dry run sends no shutdown" || fail "dry run must not send broker/shutdown"

echo "Opt-in unreferenced sweep"
out="$(bash "$SWEEP" --include-unreferenced --state-root "$state" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "--include-unreferenced exits 0" || fail "--include-unreferenced exits 0 (rc=$rc): $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$unref_pid .*reason=unreferenced" && pass "--include-unreferenced reports the unreferenced broker" || fail "--include-unreferenced must report the unreferenced broker: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$peer_pid" && fail "--include-unreferenced must still leave the referenced peer alone" || pass "--include-unreferenced still leaves the referenced peer alone"

echo "Incomplete process inspection"
mkdir -p "$T/bin"; printf '#!/bin/sh\nexit 1\n' > "$T/bin/ps"; chmod +x "$T/bin/ps"
out="$(PATH="$T/bin:$PATH" bash "$SWEEP" --state-root "$state" 2>&1)"; rc=$?
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$orphan_pid .*reason=inspect-failed" && pass "a broker that cannot be inspected is reported, not dropped" || fail "inspect failure reported: $out"
printf '%s\n' "$out" | grep -qi "incomplete" && pass "an incomplete sweep says so" || fail "an incomplete sweep must say so: $out"

echo "Retirement"
out="$(bash "$SWEEP" --kill --state-root "$state" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "--kill exits 0 when every retirement succeeds" || fail "--kill exits 0 (rc=$rc): $out"
sleep 1
[ ! -f "$state/stale-1111111111111111/broker.json" ] && pass "--kill clears the stale record" || fail "--kill must clear the stale record"
kill -0 "$bystander" 2>/dev/null && pass "--kill never signals a pid read from a stale record" || fail "--kill signalled the pid from a stale record"
[ -f "$state/malformed-4444444444444444/broker.json" ] && pass "--kill leaves an unparseable record in place" || fail "--kill must not delete a record it could not read"
[ -f "$T/orphan.shutdown" ] && pass "--kill asks the orphan to shut down over broker/shutdown" || fail "--kill must send broker/shutdown before signalling"
kill -0 "$orphan_pid" 2>/dev/null && fail "--kill must stop the orphan" || pass "--kill stops the orphan"
[ -f "$T/wedged.shutdown" ] && pass "--kill asks a wedged orphan to shut down first" || fail "--kill must try broker/shutdown on a wedged orphan"
kill -0 "$wedged_pid" 2>/dev/null && fail "--kill must signal an orphan that ignores shutdown" || pass "--kill signals an orphan that ignores shutdown"
kill -0 "$reused_pid" 2>/dev/null && pass "--kill leaves a healthy broker whose pid a stale record names" || fail "--kill killed the healthy broker whose pid a stale record named"
[ -f "$state/reused-5555555555555555/broker.json" ] && pass "--kill keeps the healthy broker's own record" || fail "--kill must keep the healthy broker's own record"
[ ! -f "$state/stale-6666666666666666/broker.json" ] && pass "--kill clears the stale record that named the reused pid" || fail "--kill must clear the stale record that named the reused pid"
kill -0 "$peer_pid" 2>/dev/null && pass "--kill leaves the peer broker running" || fail "--kill must leave the peer broker running"
kill -0 "$unref_pid" 2>/dev/null && pass "--kill leaves an unreferenced broker running unless asked" || fail "--kill must not stop an unreferenced broker unless asked"
kill -0 "$spacey_pid" 2>/dev/null && pass "--kill leaves an unverifiable broker running" || fail "--kill must never stop a broker it could not verify"
[ -f "$state/peer-2222222222222222/broker.json" ] && pass "--kill keeps the peer's record" || fail "--kill must keep the peer's record"
printf '%s\n' "$out" | grep -q "0 failure(s)" && pass "a clean retirement reports no failures" || fail "a clean retirement must report 0 failures: $out"

echo "Degenerate inputs"
out="$(bash "$SWEEP" --state-root "$T/does-not-exist" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi 'no state root' && pass "a missing state root is reported, not an error" || fail "missing state root handling (rc=$rc): $out"
out="$(bash "$SWEEP" --nonsense 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && pass "an unknown flag is a usage error" || fail "an unknown flag must exit 2 (rc=$rc)"

echo
if [ "$FAILURES" -eq 0 ]; then echo "STATUS: PASSED"; else echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
