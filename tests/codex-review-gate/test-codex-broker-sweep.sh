#!/usr/bin/env bash
# codex-broker-sweep reclaims codex-plugin-cc brokers that nothing will use
# again. It runs against other people's live processes, so the safety
# properties matter more than the reclamation: a peer's broker must survive, a
# pid read out of a stale record must never be signalled (pids get reused), a
# state of the world the sweep could not determine must be reported as
# unverifiable rather than acted on, and a broker that is retired must be asked
# to shut down over its own protocol before it is signalled.
#
# It runs against the host's real process table, so every sweep below is fenced
# with --only-pids to the fixtures this file spawned that are still running.
# Any sweep added here needs that fence too: --state-root isolates the records,
# not the processes.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SWEEP="$REPO_ROOT/skills/requesting-code-review/scripts/codex-broker-sweep"
FAKE="$SCRIPT_DIR/fixtures/app-server-broker.mjs"
# Both sides of this suite read the process table, so a host that denies it can
# answer neither. The sweep confirms a signalling target with `ps -o command=`
# and refuses to act on a pid it cannot read, so every record comes back
# unverifiable; `fixture_alive` below identifies this file's own fixtures the
# same way, so the --only-pids fence comes back empty and each fenced call is a
# usage error. Both are the tool and the suite behaving correctly on a host
# neither can inspect, and the resulting failures describe the host rather than
# the sweep. The probe asks about this shell, which is certainly alive: an
# empty answer means the table is unreadable, not that the process is gone.
if [ -z "$(ps -o command= -p $$ 2>/dev/null)" ]; then
    echo "  [SKIP] this host denies process-table access -- ps cannot report on this shell"
    echo "         codex-broker-sweep is process-table-driven; the suite cannot exercise it here"
    exit 0
fi
FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
T="$(mktemp -d "${TMPDIR:-/tmp}/broker-sweep.XXXXXX")"
pids=""
# A pid is not an identity: the kernel hands the number out again, and this
# file retires fixtures while it runs. Every process it starts carries $T in
# its command line -- the fakes through --endpoint and --pid-file, the
# bystander through its argv[0] -- so that, and not membership in $pids, is
# what says the number still belongs to this suite.
fixture_alive() {
  kill -0 "$1" 2>/dev/null || return 1
  ps -o command= -p "$1" 2>/dev/null | grep -Fq -- "$T/"
}
cleanup() { for p in $pids; do fixture_alive "$p" && kill -KILL "$p" 2>/dev/null; done; chmod 755 "$T/locked" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

# The pid list every sweep in this file is fenced to: the fixtures still alive
# now, minus any this call names. Without the fence the scan reaches the whole
# host, and a developer's own broker in a removed worktree is classified
# cwd-missing and retired before anything asks whether a record names it.
# Built at call time, because $pids only grows: a retired fixture's number
# would otherwise stay authorized for every later sweep, and by then it may
# belong to a real broker.
only() {
  local skip=" $* " list="" p
  for p in $pids; do
    case "$skip" in *" $p "*) continue ;; esac
    fixture_alive "$p" || continue
    list="${list:+$list,}$p"
  done
  [ -n "$list" ] || echo "no fixture process is alive: the fence list would be empty" >&2
  printf '%s' "$list"
}
# The sweep waits a minute before it will call an unrecorded broker
# unreferenced. The clock-outs below were written against ten seconds, so pin
# the window rather than make the suite sit through the default.
export CODEX_BROKER_SWEEP_WINDOW_S=10

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
# a pid recorded in an old broker.json after the original exited. Its argv[0]
# names $T so the fence above can tell it from whatever inherits ITS pid.
( exec -a "broker-sweep-bystander $T/bystander" sleep 600 ) &
bystander=$!; disown 2>/dev/null; pids="$pids $bystander"

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
# 9. A broker that has not created its socket yet. The companion writes a state
#    record only after the endpoint answers, so an unrecorded dead endpoint is
#    a broker that is still starting, not one that died.
spawn starting "$T/starting.sock" --no-listen
# 10. The same shape, but a record names its endpoint: it answered once and its
#     socket is gone now, which is a genuine orphan.
spawn recdead "$T/recdead.sock" --no-listen
# 11. A live, healthy broker that carries its own record and whose pid an older
#    stale record ALSO names: the pid was reused after the broker that record
#    described exited. Its endpoint must come from the process, not the record.
spawn reused
# 12. A live broker whose working directory exists but cannot be inspected.
#     existsSync() answers false for a permission error exactly as it does for a
#     deleted directory, and "I was not allowed to look" is not evidence that a
#     workspace was removed. Spawned by hand: spawn() owns its cwd layout.
mkdir -p "$T/locked/lockedcwd-cwd"
( cd "$T/locked/lockedcwd-cwd" && exec node "$FAKE" serve --endpoint "unix:$T/lockedcwd.sock" \
    --pid-file "$T/lockedcwd.pid" --shutdown-marker "$T/lockedcwd.shutdown" >/dev/null 2>&1 ) &
disown 2>/dev/null
i=0
while [ ! -s "$T/lockedcwd.pid" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
[ -s "$T/lockedcwd.pid" ] || { echo "the lockedcwd fake broker never started"; exit 1; }
lockedcwd_pid=$(cat "$T/lockedcwd.pid"); pids="$pids $lockedcwd_pid"
chmod 000 "$T/locked"
node -e 'try { require("fs").statSync(process.argv[1]); process.exit(1) } catch (e) { process.exit(e.code === "EACCES" ? 0 : 1) }' \
  "$T/locked/lockedcwd-cwd" || { echo "cannot make a working directory unstattable on this host"; exit 1; }

# 13. A process whose script is NOT the broker but whose command line contains
#     the broker's name as a substring. pgrep's coarse pattern finds it, so the
#     exact identity check is the only thing between it and a signal.
mkdir -p "$T/lookalike-bin" "$T/lookalike-cwd"
cp "$FAKE" "$T/lookalike-bin/not-app-server-broker.mjs"
( cd "$T/lookalike-cwd" && exec node "$T/lookalike-bin/not-app-server-broker.mjs" serve \
    --endpoint "unix:$T/lookalike.sock" --pid-file "$T/lookalike.pid" \
    --shutdown-marker "$T/lookalike.shutdown" >/dev/null 2>&1 ) &
disown 2>/dev/null
i=0
while [ ! -s "$T/lookalike.pid" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
[ -s "$T/lookalike.pid" ] || { echo "the lookalike process never started"; exit 1; }
lookalike_pid=$(cat "$T/lookalike.pid"); pids="$pids $lookalike_pid"
rmdir "$T/lookalike-cwd" || { echo "cannot remove the lookalike's cwd on this host"; exit 1; }
# 14. Two brokers whose endpoints differ only by a suffix, with a record naming
#     the shorter endpoint against the longer broker's pid — fixture 11's
#     pid-reuse shape, but where a prefix match makes the record look confirmed.
#     Acting on the recorded endpoint sends broker/shutdown to the healthy peer
#     that actually owns it.
spawn pfx "$T/pfx.sock"
spawn pfxb "$T/pfx.sock-b"
pfx_pid=$(cat "$T/pfx.pid"); pfxb_pid=$(cat "$T/pfxb.pid")
mkdir -p "$state/prefix-8888888888888888"
printf '{"endpoint":"unix:%s/pfx.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$pfxb_pid" "$T" > "$state/prefix-8888888888888888/broker.json"
rmdir "$T/pfxb-cwd" || { echo "cannot remove the suffixed orphan's cwd on this host"; exit 1; }
# 15. A healthy broker whose record does not exist when the sweep reads the
#     state root, and does exist by the time the sweep decides about its pid.
#     Spawned here so it is comfortably past the age floor when that happens.
spawn late
late_pid=$(cat "$T/late.pid")
# Everything above is now running. The unreferenced sweep refuses to judge a
# broker younger than the companion's registration window, so the blocks that
# expect a verdict wait this clock out rather than racing it.
spawn_epoch=$(date +%s)

peer_pid=$(cat "$T/peer.pid"); orphan_pid=$(cat "$T/orphan.pid"); wedged_pid=$(cat "$T/wedged.pid")
unref_pid=$(cat "$T/unref.pid"); spacey_pid=$(cat "$T/spacey.pid"); reused_pid=$(cat "$T/reused.pid")
starting_pid=$(cat "$T/starting.pid"); recdead_pid=$(cat "$T/recdead.pid")
mkdir -p "$state/recdead-7777777777777777"
printf '{"endpoint":"unix:%s/recdead.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$recdead_pid" "$T" > "$state/recdead-7777777777777777/broker.json"
mkdir -p "$state/reused-5555555555555555" "$state/stale-6666666666666666"
printf '{"endpoint":"unix:%s/reused.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$reused_pid" "$T" > "$state/reused-5555555555555555/broker.json"
printf '{"endpoint":"unix:%s/gone3.sock","pid":%s,"sessionDir":"%s/gone3"}\n' "$T" "$reused_pid" "$T" > "$state/stale-6666666666666666/broker.json"
rmdir "$T/orphan-cwd" "$T/wedged-cwd" || { echo "cannot remove an orphan's cwd on this host"; exit 1; }
mkdir -p "$state/peer-2222222222222222"
printf '{"endpoint":"unix:%s/peer.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$peer_pid" "$T" > "$state/peer-2222222222222222/broker.json"

echo "Dry run"
out="$(bash "$SWEEP" --only-pids "$(only)" --state-root "$state" 2>&1)"; rc=$?
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
printf '%s\n' "$out" | grep -q "orphan-broker pid=$starting_pid" && fail "a broker that no record names yet must not be an orphan for having no socket" || pass "a broker that no record names yet is not an orphan for having no socket"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$starting_pid .*reason=unregistered-endpoint-dead" && pass "a broker with no socket and no record is reported as unverifiable" || fail "starting broker unverifiable: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$recdead_pid .*reason=endpoint-dead" && pass "a recorded broker whose socket is gone is an orphan" || fail "recorded dead-endpoint broker reported: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$lockedcwd_pid" && fail "a working directory that cannot be statted must not read as deleted" || pass "a working directory that cannot be statted does not read as deleted"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$lockedcwd_pid .*reason=cwd-unverifiable" && pass "a working directory that cannot be statted is reported as unverifiable" || fail "unstattable cwd unverifiable: $out"
printf '%s\n' "$out" | grep -q "pid=$lookalike_pid" && fail "a process whose script only resembles the broker must not be classified as one" || pass "a process whose script only resembles the broker is not classified as one"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$pfxb_pid endpoint=unix:$T/pfx.sock-b reason=cwd-missing" && pass "a broker's endpoint is read from its own command line, not from a record that merely prefixes it" || fail "suffixed endpoint classification: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$pfxb_pid endpoint=unix:$T/pfx.sock reason=" && fail "a record whose endpoint is a prefix of the running broker's must not be treated as confirming it" || pass "a record whose endpoint is a prefix of the running broker's does not confirm it"
[ -f "$state/stale-1111111111111111/broker.json" ] && pass "dry run removes nothing" || fail "dry run must not remove records"
kill -0 "$orphan_pid" 2>/dev/null && pass "dry run kills nothing" || fail "dry run must not stop brokers"
[ ! -f "$T/orphan.shutdown" ] && pass "dry run sends no shutdown" || fail "dry run must not send broker/shutdown"

echo "Opt-in unreferenced sweep"
# Against a clean inventory: every record parses, so "no record names this
# endpoint" is information rather than a gap in what the sweep could read.
state_clean="$T/state-clean"
cp -R "$state" "$state_clean"
rm -rf "$state_clean/malformed-4444444444444444"
for _ in $(seq 1 30); do [ $(( $(date +%s) - spawn_epoch )) -ge 11 ] && break; sleep 1; done
out="$(bash "$SWEEP" --only-pids "$(only)" --include-unreferenced --state-root "$state_clean" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "--include-unreferenced exits 0" || fail "--include-unreferenced exits 0 (rc=$rc): $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$unref_pid .*reason=unreferenced" && pass "--include-unreferenced reports the unreferenced broker" || fail "--include-unreferenced must report the unreferenced broker: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$peer_pid" && fail "--include-unreferenced must still leave the referenced peer alone" || pass "--include-unreferenced still leaves the referenced peer alone"

echo "Incomplete process inspection"
mkdir -p "$T/bin"; printf '#!/bin/sh\nexit 1\n' > "$T/bin/ps"; chmod +x "$T/bin/ps"
out="$(PATH="$T/bin:$PATH" bash "$SWEEP" --only-pids "$(only)" --state-root "$state" 2>&1)"; rc=$?
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$orphan_pid .*reason=inspect-failed" && pass "a broker that cannot be inspected is reported, not dropped" || fail "inspect failure reported: $out"
printf '%s\n' "$out" | grep -qi "incomplete" && pass "an incomplete sweep says so" || fail "an incomplete sweep must say so: $out"

echo "Retirement"
out="$(bash "$SWEEP" --only-pids "$(only)" --kill --state-root "$state" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "--kill exits 0 when every retirement succeeds" || fail "--kill exits 0 (rc=$rc): $out"
sleep 1
[ ! -f "$state/stale-1111111111111111/broker.json" ] && pass "--kill clears the stale record" || fail "--kill must clear the stale record"
kill -0 "$bystander" 2>/dev/null && pass "--kill never signals a pid read from a stale record" || fail "--kill signalled the pid from a stale record"
[ -f "$state/malformed-4444444444444444/broker.json" ] && pass "--kill leaves an unparseable record in place" || fail "--kill must not delete a record it could not read"
[ -f "$T/orphan.shutdown" ] && pass "--kill asks the orphan to shut down over broker/shutdown" || fail "--kill must send broker/shutdown before signalling"
kill -0 "$orphan_pid" 2>/dev/null && fail "--kill must stop the orphan" || pass "--kill stops the orphan"
[ -f "$T/wedged.shutdown" ] && pass "--kill asks a wedged orphan to shut down first" || fail "--kill must try broker/shutdown on a wedged orphan"
kill -0 "$wedged_pid" 2>/dev/null && fail "--kill must signal an orphan that ignores shutdown" || pass "--kill signals an orphan that ignores shutdown"
kill -0 "$starting_pid" 2>/dev/null && pass "--kill leaves a broker that may still be starting" || fail "--kill killed a broker that may still be starting"
kill -0 "$recdead_pid" 2>/dev/null && fail "--kill must retire a recorded broker whose socket is gone" || pass "--kill retires a recorded broker whose socket is gone"
[ -z "$(find "$state" -name '*.sweep-*' 2>/dev/null)" ] && pass "--kill leaves no claimed record behind" || fail "--kill left a claimed record temp file behind"
kill -0 "$reused_pid" 2>/dev/null && pass "--kill leaves a healthy broker whose pid a stale record names" || fail "--kill killed the healthy broker whose pid a stale record named"
[ -f "$state/reused-5555555555555555/broker.json" ] && pass "--kill keeps the healthy broker's own record" || fail "--kill must keep the healthy broker's own record"
[ ! -f "$state/stale-6666666666666666/broker.json" ] && pass "--kill clears the stale record that named the reused pid" || fail "--kill must clear the stale record that named the reused pid"
kill -0 "$peer_pid" 2>/dev/null && pass "--kill leaves the peer broker running" || fail "--kill must leave the peer broker running"
kill -0 "$unref_pid" 2>/dev/null && pass "--kill leaves an unreferenced broker running unless asked" || fail "--kill must not stop an unreferenced broker unless asked"
kill -0 "$lockedcwd_pid" 2>/dev/null && pass "--kill leaves a broker whose cwd could not be inspected" || fail "--kill must not stop a broker whose cwd it could not inspect"
kill -0 "$spacey_pid" 2>/dev/null && pass "--kill leaves an unverifiable broker running" || fail "--kill must never stop a broker it could not verify"
kill -0 "$lookalike_pid" 2>/dev/null && pass "--kill leaves a process whose script only resembles the broker" || fail "--kill stopped a process whose script only resembles the broker"
kill -0 "$pfx_pid" 2>/dev/null && pass "--kill leaves the peer that owns the prefixed endpoint" || fail "--kill must not stop the peer that owns the prefixed endpoint"
[ ! -f "$T/pfx.shutdown" ] && pass "--kill sends no shutdown to the peer that owns the prefixed endpoint" || fail "--kill sent broker/shutdown to the peer that owns the prefixed endpoint"
kill -0 "$pfxb_pid" 2>/dev/null && fail "--kill must retire the orphan whose endpoint carries the suffix" || pass "--kill retires the orphan whose endpoint carries the suffix"
[ -f "$state/peer-2222222222222222/broker.json" ] && pass "--kill keeps the peer's record" || fail "--kill must keep the peer's record"
printf '%s\n' "$out" | grep -q "0 failure(s)" && pass "a clean retirement reports no failures" || fail "a clean retirement must report 0 failures: $out"

echo "The fence authorizes only the fixtures that are still alive"
# The block above retired several fixtures. Their numbers stay in $pids, and
# the kernel hands numbers out again, so a fence built from that list would go
# on authorizing pids this suite no longer owns -- on a developer's machine,
# quite possibly a real broker by the time the next --kill runs.
fence=",$(only),"
dead_pids=""; stale_authorized=""; missing_live=""
for p in $pids; do
  if fixture_alive "$p"; then
    case "$fence" in *",$p,"*) : ;; *) missing_live="${missing_live:+$missing_live }$p" ;; esac
  else
    dead_pids="${dead_pids:+$dead_pids }$p"
    case "$fence" in *",$p,"*) stale_authorized="${stale_authorized:+$stale_authorized }$p" ;; esac
  fi
done
[ -n "$dead_pids" ] && pass "the retirement left fixture pids behind for the fence to drop" || fail "no fixture was retired above, so this block proves nothing"
case "$fence" in
  *",$orphan_pid,"*) fail "the fence must drop the retired orphan's pid ($orphan_pid)" ;;
  *) pass "the fence drops the pid of a fixture the sweep retired" ;;
esac
case "$fence" in
  *",$peer_pid,"*) pass "the fence still authorizes a live fixture" ;;
  *) fail "the fence must still authorize the live peer ($peer_pid)" ;;
esac
[ -z "$stale_authorized" ] && pass "no pid this suite no longer owns is authorized" || fail "the fence authorized pids that are gone or reused: $stale_authorized"
[ -z "$missing_live" ] && pass "every live fixture is still authorized" || fail "the fence dropped live fixtures: $missing_live"

echo "Unreferenced retirement requires a complete inventory"
# The companion writes broker.json with a plain writeFileSync, so a record can
# be caught half-written. A record the sweep could not read may be the record
# for the very broker it is about to call unreferenced.
out="$(bash "$SWEEP" --only-pids "$(only)" --include-unreferenced --kill --state-root "$state" 2>&1)"; rc=$?
sleep 1
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$unref_pid .*reason=unreferenced-inventory-incomplete" && pass "an unreadable record fences unreferenced retirement" || fail "unreferenced fence reported: $out"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$unref_pid" && fail "a broker must not be called unreferenced while a record is unreadable" || pass "a broker is not called unreferenced while a record is unreadable"
kill -0 "$unref_pid" 2>/dev/null && pass "--include-unreferenced retires nothing as unreferenced on an incomplete inventory" || fail "--include-unreferenced retired a broker on an incomplete inventory"

echo "Identity revalidation before signalling"
# The pid could be reused between the ps snapshot and the signal. A ps that
# reports a different command on the second call stands in for that window.
spawn swapped "$T/swapped.sock" --ignore-shutdown
swapped_pid=$(cat "$T/swapped.pid")
rmdir "$T/swapped-cwd" || { echo "cannot remove the swapped orphan's cwd"; exit 1; }
mkdir -p "$T/bin2"
cat > "$T/bin2/ps" <<PSEOF
#!/bin/sh
case " \$* " in
  *" command= "*" $swapped_pid "*)
    n=0; [ -f "$T/pscount" ] && n=\$(cat "$T/pscount"); n=\$((n + 1)); echo "\$n" > "$T/pscount"
    if [ "\$n" -ge 2 ]; then echo "/usr/bin/some-other-process --unrelated"; exit 0; fi ;;
esac
exec /bin/ps "\$@"
PSEOF
chmod +x "$T/bin2/ps"
out="$(PATH="$T/bin2:$PATH" bash "$SWEEP" --only-pids "$(only)" --kill --state-root "$state" 2>&1)"; rc=$?
sleep 1
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$swapped_pid .*reason=identity-changed" && pass "a pid whose command no longer looks like a broker is not signalled" || fail "identity change reported: $out"
kill -0 "$swapped_pid" 2>/dev/null && pass "--kill leaves a pid that stopped looking like a broker" || fail "--kill signalled a pid that no longer looked like a broker"
[ "$rc" -eq 0 ] && pass "declining to signal an ambiguous pid is not a failure" || fail "declining to signal must not be an error (rc=$rc)"

echo "Identity revalidation before the fallback signal"
# This orphan ignores broker/shutdown and SIGTERM, so the sweep reaches SIGKILL.
# A ps that reports the broker for the classification and the pre-SIGTERM check
# and a stranger afterwards stands in for a pid reused inside that wait.
spawn swapkill "$T/swapkill.sock" --ignore-shutdown
swapkill_pid=$(cat "$T/swapkill.pid")
rmdir "$T/swapkill-cwd" || { echo "cannot remove the swapkill orphan's cwd"; exit 1; }
mkdir -p "$T/bin3"
cat > "$T/bin3/ps" <<PSEOF
#!/bin/sh
case " \$* " in
  *" command= "*" $swapkill_pid "*)
    n=0; [ -f "$T/pscount3" ] && n=\$(cat "$T/pscount3"); n=\$((n + 1)); echo "\$n" > "$T/pscount3"
    if [ "\$n" -ge 3 ]; then echo "/usr/bin/some-other-process --unrelated"; exit 0; fi ;;
esac
exec /bin/ps "\$@"
PSEOF
chmod +x "$T/bin3/ps"
out="$(PATH="$T/bin3:$PATH" bash "$SWEEP" --only-pids "$(only)" --kill --state-root "$state" 2>&1)"; rc=$?
sleep 1
kill -0 "$swapkill_pid" 2>/dev/null && pass "the fallback signal is withheld from a pid that stopped looking like a broker" || fail "--kill sent the fallback signal to a pid that no longer looked like a broker"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$swapkill_pid .*reason=identity-changed" && pass "an identity change between signals is reported" || fail "identity change between signals reported: $out"
[ "$rc" -eq 0 ] && pass "withholding the fallback signal is not a failure" || fail "withholding the fallback signal must not be an error (rc=$rc)"

echo "Identity revalidation rejects a lookalike command"
# A pid reused by a process whose command line merely contains the broker's name
# as a substring. `serve` and the endpoint are both present on that line, so only
# an exact match on the script token tells the two apart.
spawn swapname "$T/swapname.sock" --ignore-shutdown
swapname_pid=$(cat "$T/swapname.pid")
rmdir "$T/swapname-cwd" || { echo "cannot remove the swapname orphan's cwd"; exit 1; }
mkdir -p "$T/bin4"
cat > "$T/bin4/ps" <<PSEOF
#!/bin/sh
case " \$* " in
  *" command= "*" $swapname_pid "*)
    n=0; [ -f "$T/pscount4" ] && n=\$(cat "$T/pscount4"); n=\$((n + 1)); echo "\$n" > "$T/pscount4"
    if [ "\$n" -ge 2 ]; then echo "node /opt/not-app-server-broker.mjs serve --endpoint unix:$T/swapname.sock"; exit 0; fi ;;
esac
exec /bin/ps "\$@"
PSEOF
chmod +x "$T/bin4/ps"
out="$(PATH="$T/bin4:$PATH" bash "$SWEEP" --only-pids "$(only)" --kill --state-root "$state" 2>&1)"; rc=$?
sleep 1
kill -0 "$swapname_pid" 2>/dev/null && pass "a pid running a lookalike script name is not signalled" || fail "--kill signalled a pid whose script name only resembles the broker"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$swapname_pid .*reason=identity-changed" && pass "a lookalike script name at signal time is an identity change" || fail "lookalike identity change reported: $out"
[ "$rc" -eq 0 ] && pass "declining to signal a lookalike is not a failure" || fail "declining to signal a lookalike must not be an error (rc=$rc)"

echo "Identity revalidation rejects an endpoint prefix"
# The replacement broker's endpoint has the classified one as a strict prefix, so
# a substring test cannot tell them apart and the fallback signal hits the
# newcomer. This one switches before SIGKILL, the lookalike above before SIGTERM.
spawn swapep "$T/swapep.sock" --ignore-shutdown
swapep_pid=$(cat "$T/swapep.pid")
rmdir "$T/swapep-cwd" || { echo "cannot remove the swapep orphan's cwd"; exit 1; }
mkdir -p "$T/bin5"
cat > "$T/bin5/ps" <<PSEOF
#!/bin/sh
case " \$* " in
  *" command= "*" $swapep_pid "*)
    n=0; [ -f "$T/pscount5" ] && n=\$(cat "$T/pscount5"); n=\$((n + 1)); echo "\$n" > "$T/pscount5"
    if [ "\$n" -ge 3 ]; then echo "node /opt/app-server-broker.mjs serve --endpoint unix:$T/swapep.sock-new"; exit 0; fi ;;
esac
exec /bin/ps "\$@"
PSEOF
chmod +x "$T/bin5/ps"
out="$(PATH="$T/bin5:$PATH" bash "$SWEEP" --only-pids "$(only)" --kill --state-root "$state" 2>&1)"; rc=$?
sleep 1
kill -0 "$swapep_pid" 2>/dev/null && pass "the fallback signal is withheld when only an endpoint prefix matches" || fail "--kill signalled a pid whose endpoint merely shares a prefix with the classified one"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$swapep_pid .*reason=identity-changed" && pass "an endpoint-prefix-only match between signals is an identity change" || fail "endpoint prefix identity change reported: $out"
[ "$rc" -eq 0 ] && pass "declining to signal an endpoint-prefix match is not a failure" || fail "declining an endpoint-prefix match must not be an error (rc=$rc)"

echo "Unreferenced retirement re-checks the inventory at the moment of decision"
# broker-lifecycle.mjs makes a broker visible to pgrep and listening for up to
# two seconds before it writes broker.json, and a sweep of a busy host spends
# far longer than that probing endpoints. Both windows leave a healthy broker
# absent from the record snapshot the sweep started with. `young` is inside the
# first window; `late` covers the second — the ps stub writes its record when
# the sweep inspects that pid, which is after the record pass and before the
# decision, exactly where a re-read has to look. `unref` stands in for a pid
# whose age cannot be read at all, and `starting` is the control that a genuine
# leak is still retired.
state_race="$T/state-race"
cp -R "$state_clean" "$state_race"
# This is the one block whose inventory is complete AND whose retirement is
# armed, so before --only-pids existed it was the one that could reach past the
# fixtures: the scan found every broker on the machine, and none of the
# developer's own are named by a record under a throwaway state root. The fence
# on the scan is what keeps them out of it now.
spawn young
young_pid=$(cat "$T/young.pid")
mkdir -p "$T/bin6"
cat > "$T/bin6/ps" <<PSEOF
#!/bin/sh
case " \$* " in
  *" command= "*" $late_pid "*)
    mkdir -p "$state_race/late-aaaaaaaaaaaaaaaa"
    printf '{"endpoint":"unix:%s/late.sock","pid":%s,"sessionDir":"%s"}\n' "$T" "$late_pid" "$T" \
      > "$state_race/late-aaaaaaaaaaaaaaaa/broker.json" ;;
  *" etime= "*" $unref_pid "*) exit 1 ;;
esac
exec /bin/ps "\$@"
PSEOF
chmod +x "$T/bin6/ps"
out="$(PATH="$T/bin6:$PATH" bash "$SWEEP" --only-pids "$(only)" --include-unreferenced --kill --state-root "$state_race" 2>&1)"; rc=$?
sleep 1
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$late_pid .*reason=unreferenced-record-appeared" && pass "a record written after the inventory snapshot fences unreferenced retirement" || fail "late record fence reported: $out"
kill -0 "$late_pid" 2>/dev/null && pass "--kill leaves a broker whose record appeared during the sweep" || fail "--kill retired a broker whose record appeared during the sweep"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$young_pid .*reason=unreferenced-too-young" && pass "a broker inside its registration window is too young to call unreferenced" || fail "young broker fence reported: $out"
kill -0 "$young_pid" 2>/dev/null && pass "--kill leaves a broker still inside its registration window" || fail "--kill retired a broker still inside its registration window"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$unref_pid .*reason=unreferenced-age-unknown" && pass "a broker whose age cannot be read is not called unreferenced" || fail "unreadable age fence reported: $out"
kill -0 "$unref_pid" 2>/dev/null && pass "--kill leaves a broker whose age it could not read" || fail "--kill retired a broker whose age it could not read"
printf '%s\n' "$out" | grep -q "orphan-broker pid=$starting_pid .*reason=unreferenced" && pass "the re-check still reports a genuinely unreferenced broker" || fail "genuine unreferenced broker reported: $out"
kill -0 "$starting_pid" 2>/dev/null && fail "--include-unreferenced must still retire a genuinely unreferenced broker" || pass "--include-unreferenced still retires a genuinely unreferenced broker"
[ "$rc" -eq 0 ] && pass "fencing an ambiguous unreferenced broker is not a failure" || fail "fencing an unreferenced broker must not be an error (rc=$rc)"

echo "The scan considers only the pids it was given"
# --state-root isolates the records, not the process table, and a broker whose
# working directory has been deleted is retired for that alone -- before
# anything asks whether a record names it. `inside` is the control that this
# run still does its job; `outside` is spawned exactly like it, left off the
# list, and must come through untouched.
spawn inside
spawn outside
inside_pid=$(cat "$T/inside.pid"); outside_pid=$(cat "$T/outside.pid")
rmdir "$T/inside-cwd" "$T/outside-cwd" || { echo "cannot remove the fence fixtures' cwds on this host"; exit 1; }
out="$(bash "$SWEEP" --kill --only-pids "$(only "$outside_pid")" --state-root "$state" 2>&1)"; rc=$?
sleep 1
printf '%s\n' "$out" | grep -qE "orphan-broker pid=$inside_pid .*reason=cwd-missing" && pass "a listed broker whose cwd is gone is still classified" || fail "a fenced sweep must still classify the pids it was given: $out"
kill -0 "$inside_pid" 2>/dev/null && fail "--kill must retire a listed broker whose cwd is gone" || pass "--kill retires a listed broker whose cwd is gone"
printf '%s\n' "$out" | grep -qE "pid=$outside_pid( |$)" && fail "a pid outside --only-pids must not be classified at all" || pass "a pid outside --only-pids is not classified at all"
kill -0 "$outside_pid" 2>/dev/null && pass "--kill leaves a broker outside --only-pids running" || fail "--kill retired a broker outside --only-pids"
[ "$rc" -eq 0 ] && pass "a fenced retirement exits 0" || fail "a fenced retirement must exit 0 (rc=$rc): $out"

echo "Degenerate inputs"
out="$(bash "$SWEEP" --only-pids "$(only)" --state-root "$T/does-not-exist" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi 'no state root' && pass "a missing state root is reported, not an error" || fail "missing state root handling (rc=$rc): $out"
out="$(bash "$SWEEP" --only-pids "$(only)" --nonsense 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && pass "an unknown flag is a usage error" || fail "an unknown flag must exit 2 (rc=$rc)"
out="$(CODEX_BROKER_SWEEP_WINDOW_S=nope bash "$SWEEP" --only-pids "$(only)" --state-root "$T/does-not-exist" 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && pass "a registration window that is not a number is a usage error" || fail "a bad CODEX_BROKER_SWEEP_WINDOW_S must exit 2 (rc=$rc): $out"
# A window of zero is not a small window, it is no window: every broker the
# records do not name is instantly old enough to retire, including one that is
# still registering. `00` is that value wearing padding, and an empty value is
# a caller's unset variable rather than a request for the default. At the other
# end a twenty-digit value is a magnitude no elapsed time reaches, so nothing is
# ever old enough and the sweep reclaims nothing. Each of these must be refused,
# not interpreted.
for bad in 0 00 000 '' abc -5 1.5 ' 60' 99999999999999999999; do
  out="$(CODEX_BROKER_SWEEP_WINDOW_S="$bad" bash "$SWEEP" --only-pids "$(only)" --state-root "$T/does-not-exist" 2>&1)"; rc=$?
  [ "$rc" -eq 2 ] && pass "a registration window of '$bad' is a usage error" || fail "CODEX_BROKER_SWEEP_WINDOW_S='$bad' must exit 2 (rc=$rc): $out"
done
# Padding is not a defect: 060 is sixty. The only ways this fixture does not
# survive are a rejected value (rc 2) or a window that canonicalised to zero,
# which would call a broker spawned seconds ago unreferenced and retire it.
spawn padded
padded_pid=$(cat "$T/padded.pid")
out="$(CODEX_BROKER_SWEEP_WINDOW_S=060 bash "$SWEEP" --only-pids "$padded_pid" --include-unreferenced --kill --state-root "$state_clean" 2>&1)"; rc=$?
sleep 1
[ "$rc" -eq 0 ] && pass "a zero-padded registration window is accepted" || fail "CODEX_BROKER_SWEEP_WINDOW_S=060 must be accepted (rc=$rc): $out"
printf '%s\n' "$out" | grep -q "unverifiable-broker pid=$padded_pid .*reason=unreferenced-too-young" && pass "a padded window of 060 reads as sixty seconds" || fail "060 must fence a broker younger than sixty seconds: $out"
kill -0 "$padded_pid" 2>/dev/null && pass "--kill leaves a broker inside the padded window" || fail "--kill retired a broker inside the padded sixty-second window"
out="$(bash "$SWEEP" --only-pids 'not,pids' --state-root "$T/does-not-exist" 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && pass "a --only-pids list that is not pids is a usage error" || fail "a malformed --only-pids must exit 2 (rc=$rc): $out"
# The window the suite pins above is not the one the sweep ships with. The
# default answers an unset variable only -- an empty one is refused above.
grep -q 'CODEX_BROKER_SWEEP_WINDOW_S-60' "$SWEEP" && pass "the registration window defaults to sixty seconds when unset" || fail "the sweep's default registration window must be 60 seconds for an unset variable"

echo
if [ "$FAILURES" -eq 0 ]; then echo "STATUS: PASSED"; else echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
