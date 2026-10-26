#!/usr/bin/env bash
# Behavior tests for tracked-job (stop guard, 2026-10-23). No pipefail: a
# producer's SIGPIPE under grep -q would read as a failure. Cases that need
# process identity run only where ps works (deviation 2) and print [SKIP]
# otherwise; the controller runs the suite once unsandboxed per task.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TJ="$REPO_ROOT/skills/subagent-driven-development/scripts/tracked-job"
SDD_DIR="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-dir"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
failures=0; skips=0
TEST_ROOT=$(mktemp -d) || exit 2
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 2
export XDG_CACHE_HOME="$TEST_ROOT/cache"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
cleanup() { [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"; }
trap cleanup EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }
skip() { echo "  [SKIP] $1"; skips=$((skips + 1)); }
HAVE_PS=0; ps -o pid= -p $$ >/dev/null 2>&1 && HAVE_PS=1

repo="$TEST_ROOT/repo"; git init -q -b main "$repo"
git -C "$repo" config user.name t; git -C "$repo" config user.email t@example.com
mkdir -p "$repo/docs"; printf '# Plan\n\n### Task 1: one\n' > "$repo/docs/plan.md"
git -C "$repo" add docs/plan.md; git -C "$repo" commit -q -m plan
ws=$(cd "$repo" && bash "$SDD_DIR" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s1: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
tj() { (cd "$repo" && bash "$TJ" "$@"); }
meta() { node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1]+"/meta.json","utf8"));const v=m[process.argv[2]];console.log(v===undefined||v===null?"":(typeof v==="object"?JSON.stringify(v):String(v)))' "$1" "$2"; }
newjob() { tj new docs/plan.md "$1" --budget-ms 60000 --session s1 | sed -n 's/^jobdir=//p'; }
# A launch runs several node starts before its metadata is durable, so a fixed
# wait reads an empty pid under load (three suites at once is enough). The
# metadata is written in one rename, so any key of it means the supervisor is
# past its launch window; the exit file is written last, after the terminal
# state, so its appearance means the record is complete. Both are bounded at
# 10 s, and a timeout leaves the case to fail on its own assertion.
wait_meta() { local i=0; while [ "$i" -lt 100 ]; do [ -n "$(meta "$1" "$2")" ] && return 0; sleep 0.1; i=$((i + 1)); done; return 1; }
wait_file() { local i=0; while [ "$i" -lt 100 ] && [ ! -e "$1" ]; do sleep 0.1; i=$((i + 1)); done; }
# A case that kills the supervisor, suspends it or signals the command needs
# the launch barrier open first: until it is, the child is blocked in open(2)
# on the FIFO, and a supervisor killed before it writes leaves that child
# blocked for ever. run removes the FIFO as soon as the barrier is taken, so
# its absence, once the metadata is durable, is the ready signal.
wait_launched() {
  local i=0
  wait_meta "$1" run_pid || return 1
  while [ "$i" -lt 100 ] && [ -e "$1/go" ]; do sleep 0.1; i=$((i + 1)); done
  [ ! -e "$1/go" ]
}
err="$TEST_ROOT/stderr.txt"

echo "=== tracked-job new ==="
j1=$(newjob soak); j2=$(newjob soak)
if [ -d "$j1" ] && [ -d "$j2" ] && [ "$j1" != "$j2" ] && [ "$(meta "$j1" state)" = allocated ] && [ "$(meta "$j1" session)" = s1 ]; then pass "new allocates a distinct directory per launch, state allocated"; else fail "new allocates a distinct directory per launch ($j1 / $j2)"; fi
if [ "$(grep -c "^job s1 .*: soak jobdir=$j1\$" "$ws/progress.md")" = 1 ]; then pass "new appends the allocation line to the ledger"; else fail "new appends the allocation line to the ledger"; fi
case "$j1" in "$ws/jobs/soak-"*) pass "the job directory lives under the workspace's jobs/" ;; *) fail "the job directory lives under the workspace's jobs/ ($j1)" ;; esac
lockdir="$( . "$LIB"; hp_checkout_path "$repo" ).lock"; mkdir -p "$lockdir"; printf 'pid=1\n' > "$lockdir/owner"
before=$(wc -l < "$ws/progress.md"); n3=$(ls "$ws/jobs" | wc -l)
out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 tj new docs/plan.md held --budget-ms 1000 --session s1); rc=$?
rm -rf "$lockdir"
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(wc -l < "$ws/progress.md")" = "$before" ] && [ "$(ls "$ws/jobs" | wc -l)" = "$n3" ]; then pass "a new that cannot take the lock is busy, leaves no directory and appends nothing"; else fail "a new that cannot take the lock is busy, leaves no directory and appends nothing (rc=$rc: $out)"; fi
# a workspace Finish has removed (the ledger gone under the lock): nothing is created and no ledger comes back.
mv "$ws/progress.md" "$ws/progress.md.away"
out=$(tj new docs/plan.md gone --budget-ms 1000 --session s1 2>"$err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -s "$err" ] && [ ! -e "$ws/progress.md" ] && [ "$(ls "$ws/jobs" | wc -l)" = "$n3" ]; then pass "a new after the ledger is gone creates nothing and resurrects nothing"; else fail "a new after the ledger is gone creates nothing and resurrects nothing (rc=$rc: $out; stderr: $(cat "$err"))"; fi
mv "$ws/progress.md.away" "$ws/progress.md"
out=$(tj new docs/plan.md 'bad name' --budget-ms 1000 --session s1 2>"$err"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ -s "$err" ]; then pass "a name outside [A-Za-z0-9._-] is a usage error"; else fail "a name outside [A-Za-z0-9._-] is a usage error (rc=$rc: $out; stderr: $(cat "$err"))"; fi
# the session id lands verbatim in a ledger line, so a value that is not one token is refused.
out=$(tj new docs/plan.md hostile --budget-ms 1000 --session 's Task 2: complete' 2>"$err"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ -s "$err" ] && [ "$(wc -l < "$ws/progress.md")" = "$before" ] && [ "$(ls "$ws/jobs" | wc -l)" = "$n3" ]; then pass "a session id outside [A-Za-z0-9._-] is refused before anything is written"; else fail "a session id outside [A-Za-z0-9._-] is refused before anything is written (rc=$rc: $out; stderr: $(cat "$err"))"; fi

echo "=== tracked-job run ==="
tj run "$j1" -- bash -c 'echo hello; exit 0' >/dev/null 2>&1
if [ "$(cat "$j1/exit")" = 0 ] && [ "$(meta "$j1" state)" = exited ] && [ "$(meta "$j1" code)" = 0 ] && grep -q hello "$j1/out.log" && [ -n "$(meta "$j1" launched)" ] && [ -n "$(meta "$j1" ended)" ]; then pass "run records exit 0, the output and the times"; else fail "run records exit 0, the output and the times"; fi
pid1=$(meta "$j1" pid)
out=$(tj run "$j1" -- bash -c 'exit 0'); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=already-launched" ] && [ "$(meta "$j1" pid)" = "$pid1" ]; then pass "a second run on one directory is already-launched and changes nothing"; else fail "a second run on one directory is already-launched (rc=$rc: $out)"; fi
j4=$(newjob failing); tj run "$j4" -- bash -c 'exit 3' >/dev/null 2>&1
if [ "$(cat "$j4/exit")" = 3 ] && [ "$(meta "$j4" state)" = exited ]; then pass "a failing command records its code"; else fail "a failing command records its code"; fi
j5=$(newjob sig); tj run "$j5" -- bash -c 'kill -TERM $$' >/dev/null 2>&1
if [ "$(cat "$j5/exit")" = 143 ]; then pass "a command killed by TERM records 143"; else fail "a command killed by TERM records 143 ($(cat "$j5/exit" 2>/dev/null))"; fi
j6=$(newjob fence); tj run "$j6" -- bash -c 'printf "%s" "$TRACKED_JOB_DIR" > fence.txt' >/dev/null 2>&1
if [ "$(cat "$repo/fence.txt" 2>/dev/null)" = "$j6" ]; then pass "the command runs with TRACKED_JOB_DIR set to its job directory"; else fail "the command runs with TRACKED_JOB_DIR set to its job directory"; fi
# the launch barrier: a metadata write that fails kills the waiting child and leaves the job allocated.
j7=$(newjob barrier)
out=$(HYPERPOWERS_TEST_FAIL_META=1 tj run "$j7" -- bash -c 'echo ran > ran.txt'); rc=$?; sleep 1
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(meta "$j7" state)" = allocated ] && [ -n "$(meta "$j7" launch_error)" ] && [ ! -d "$j7/launch.lock" ] && [ ! -f "$repo/ran.txt" ]; then pass "a failed launch kills the barrier-held child and leaves the job allocated"; else fail "a failed launch kills the barrier-held child and leaves the job allocated (rc=$rc: $out)"; fi
tj run "$j7" -- bash -c 'exit 0' >/dev/null 2>&1
if [ "$(cat "$j7/exit" 2>/dev/null)" = 0 ]; then pass "a later run on the same directory succeeds"; else fail "a later run on the same directory succeeds"; fi
# a barrier that cannot be created is a failed launch like any other: the job
# stays allocated, says why, and keeps no launch lock to block the retry.
jg=$(newjob fifo); mkdir "$jg/go"
out=$(tj run "$jg" -- bash -c 'echo nope > fifo-ran.txt' 2>"$err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(meta "$jg" state)" = allocated ] && [ -n "$(meta "$jg" launch_error)" ] && [ ! -d "$jg/launch.lock" ] && [ ! -f "$repo/fifo-ran.txt" ]; then pass "a barrier that cannot be created leaves the job allocated and says why"; else fail "a barrier that cannot be created leaves the job allocated and says why (rc=$rc: $out, launch_error=$(meta "$jg" launch_error))"; fi
rmdir "$jg/go"; tj run "$jg" -- bash -c 'echo yes > fifo-ran.txt' >/dev/null 2>&1
if [ "$(cat "$jg/exit" 2>/dev/null)" = 0 ] && [ "$(cat "$repo/fifo-ran.txt" 2>/dev/null)" = yes ]; then pass "the job runs once the obstruction is cleared"; else fail "the job runs once the obstruction is cleared (exit=$(cat "$jg/exit" 2>/dev/null))"; fi
# an exit file that cannot be published (the command put a directory in its
# place) is reported, never faked: the code stays readable in meta.json.
jx=$(newjob exitdir)
tj run "$jx" -- bash -c 'mkdir "$TRACKED_JOB_DIR/exit"; exit 5' >/dev/null 2>&1
if [ "$(meta "$jx" state)" = exited ] && [ "$(meta "$jx" code)" = 5 ] && [ ! -f "$jx/exit" ] && grep -q 'exit file not written' "$jx/out.log"; then pass "an exit file that cannot be published is reported, not faked"; else fail "an exit file that cannot be published is reported, not faked (state=$(meta "$jx" state), code=$(meta "$jx" code), exit file=$([ -f "$jx/exit" ] && echo yes || echo no))"; fi
# a leader that exits while a backgrounded descendant is still in its group:
# the record says exited with the leader's code, and nothing of the job is
# left running behind it.
jb=$(newjob bgleaf)
tj run "$jb" -- bash -c 'sleep 30 & echo $! > bg.pid; exit 0' >/dev/null 2>&1
wait_file "$jb/exit"; bgpid=$(cat "$repo/bg.pid" 2>/dev/null)
if [ "$(cat "$jb/exit" 2>/dev/null)" = 0 ] && [ "$(meta "$jb" state)" = exited ] && [ "$(meta "$jb" survivors)" = 0 ] && [ -n "$bgpid" ] && ! kill -0 "$bgpid" 2>/dev/null && ! kill -0 -- "-$(meta "$jb" pgid)" 2>/dev/null && grep -q 'outlived its leader' "$jb/out.log"; then pass "a group that outlives its leader is swept before the exit is published"; else fail "a group that outlives its leader is swept before the exit is published (exit=$(cat "$jb/exit" 2>/dev/null), state=$(meta "$jb" state), survivors=$(meta "$jb" survivors), descendant=$(kill -0 "${bgpid:-0}" 2>/dev/null && echo alive || echo gone), swept=$(grep -c 'outlived its leader' "$jb/out.log"))"; fi
# the same with a descendant that ignores TERM, so the sweep's KILL half runs;
# a one-second grace keeps the case to a couple of seconds.
jk=$(newjob bgkill)
TRACKED_JOB_GRACE_S=1 tj run "$jk" -- bash -c '(trap "" TERM; exec sleep 30) & echo $! > bg2.pid; exit 0' >/dev/null 2>&1
wait_file "$jk/exit"; bgpid2=$(cat "$repo/bg2.pid" 2>/dev/null)
if [ "$(cat "$jk/exit" 2>/dev/null)" = 0 ] && [ "$(meta "$jk" state)" = exited ] && [ "$(meta "$jk" survivors)" = 0 ] && [ -n "$bgpid2" ] && ! kill -0 "$bgpid2" 2>/dev/null && ! kill -0 -- "-$(meta "$jk" pgid)" 2>/dev/null && grep -q 'outlived its leader' "$jk/out.log"; then pass "a descendant that ignores TERM is killed before the exit is published"; else fail "a descendant that ignores TERM is killed before the exit is published (exit=$(cat "$jk/exit" 2>/dev/null), state=$(meta "$jk" state), survivors=$(meta "$jk" survivors), descendant=$(kill -0 "${bgpid2:-0}" 2>/dev/null && echo alive || echo gone))"; fi
# the supervisor's own TERM: the group is swept, the result recorded, state stopped.
j8=$(newjob trapped); ( tj run "$j8" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
if ! wait_meta "$j8" run_pid; then fail "a TERM to the supervisor sweeps the command and records the result (no run_pid within 10s)"
else
  kill -TERM "$(meta "$j8" run_pid)"; wait_file "$j8/exit"
  if [ "$(cat "$j8/exit" 2>/dev/null)" = 143 ] && [ "$(meta "$j8" state)" = stopped ] && ! kill -0 "$(meta "$j8" pid)" 2>/dev/null; then pass "a TERM to the supervisor sweeps the command and records the result"; else fail "a TERM to the supervisor sweeps the command and records the result (exit=$(cat "$j8/exit" 2>/dev/null), state=$(meta "$j8" state))"; fi
fi
# the launch window, pinned with the hold seam: the metadata is published and
# the command is still blocked on the barrier, which is where a stop has to be
# honoured — after it, an irreversible command has already run.
jh=$(newjob heldstop)
( HYPERPOWERS_TEST_HOLD_BEFORE_BARRIER="$TEST_ROOT/go-1" tj run "$jh" -- bash -c 'echo ran > held-ran.txt; sleep 30' >/dev/null 2>&1 ) &
if ! wait_meta "$jh" run_pid; then fail "a stop during the launch cancels the command before it runs (no run_pid within 10s)"
else
  kill -TERM "$(meta "$jh" run_pid)"; sleep 1; touch "$TEST_ROOT/go-1"; wait_file "$jh/exit"
  if [ "$(cat "$jh/exit" 2>/dev/null)" = 143 ] && [ "$(meta "$jh" state)" = stopped ] && [ ! -f "$repo/held-ran.txt" ] && ! kill -0 "$(meta "$jh" pid)" 2>/dev/null && [ -e "$jh/stop-request" ]; then pass "a stop during the launch cancels the command before it runs"; else fail "a stop during the launch cancels the command before it runs (exit=$(cat "$jh/exit" 2>/dev/null), state=$(meta "$jh" state), ran=$([ -f "$repo/held-ran.txt" ] && echo yes || echo no))"; fi
fi
# the same window, reached by a file rather than a signal: a stop-request that
# already stands when the launch would release the command (Task 4's stop
# writes one, and so does the supervisor's deferring trap).
js=$(newjob heldreq)
( HYPERPOWERS_TEST_HOLD_BEFORE_BARRIER="$TEST_ROOT/go-3" tj run "$js" -- bash -c 'echo ran > req-ran.txt; sleep 30' >/dev/null 2>&1 ) &
if ! wait_meta "$js" run_pid; then fail "a stop-request standing at the barrier cancels the command (no run_pid within 10s)"
else
  : > "$js/stop-request"; touch "$TEST_ROOT/go-3"; wait_file "$js/exit"
  if [ "$(cat "$js/exit" 2>/dev/null)" = 143 ] && [ "$(meta "$js" state)" = stopped ] && [ ! -f "$repo/req-ran.txt" ]; then pass "a stop-request standing at the barrier cancels the command"; else fail "a stop-request standing at the barrier cancels the command (exit=$(cat "$js/exit" 2>/dev/null), state=$(meta "$js" state), ran=$([ -f "$repo/req-ran.txt" ] && echo yes || echo no))"; fi
fi
# a stop-request the trap left behind during a launch that then failed must not
# cancel the retry on sight: the job goes back to allocated without the marker,
# and the next run reaches the command.
jr=$(newjob reqretry); : > "$jr/stop-request"
out=$(HYPERPOWERS_TEST_FAIL_META=1 tj run "$jr" -- bash -c 'echo ran > retry-ran.txt'); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(meta "$jr" state)" = allocated ] && [ ! -e "$jr/stop-request" ] && [ ! -d "$jr/launch.lock" ]; then pass "an aborted launch takes the stop-request with it"; else fail "an aborted launch takes the stop-request with it (rc=$rc: $out, state=$(meta "$jr" state), marker=$([ -e "$jr/stop-request" ] && echo yes || echo no), lock=$([ -d "$jr/launch.lock" ] && echo yes || echo no))"; fi
tj run "$jr" -- bash -c 'echo ran > retry-ran.txt' >/dev/null 2>&1
if [ "$(cat "$jr/exit" 2>/dev/null)" = 0 ] && [ "$(meta "$jr" state)" = exited ] && [ "$(cat "$repo/retry-ran.txt" 2>/dev/null)" = ran ]; then pass "the retry after an aborted launch runs the command"; else fail "the retry after an aborted launch runs the command (exit=$(cat "$jr/exit" 2>/dev/null), state=$(meta "$jr" state), ran=$([ -f "$repo/retry-ran.txt" ] && echo yes || echo no))"; fi
# a marker that is already standing when a launch takes its lock cannot have
# come from this launch: the job was allocated, where there is no supervisor to
# stop. It must not cancel the command.
jsr=$(newjob stalereq); : > "$jsr/stop-request"
tj run "$jsr" -- bash -c 'echo ran > stale-ran.txt' >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$jsr/exit" 2>/dev/null)" = 0 ] && [ "$(meta "$jsr" state)" = exited ] && [ "$(cat "$repo/stale-ran.txt" 2>/dev/null)" = ran ]; then pass "a stale stop-request does not cancel the launch that finds it"; else fail "a stale stop-request does not cancel the launch that finds it (rc=$rc, exit=$(cat "$jsr/exit" 2>/dev/null), state=$(meta "$jsr" state), ran=$([ -f "$repo/stale-ran.txt" ] && echo yes || echo no))"; fi
jh2=$(newjob heldgo); held=0
( HYPERPOWERS_TEST_HOLD_BEFORE_BARRIER="$TEST_ROOT/go-2" tj run "$jh2" -- bash -c 'echo released > held-go.txt' >/dev/null 2>&1 ) &
if ! wait_meta "$jh2" run_pid; then fail "a launch held at the barrier runs as usual once it is released (no run_pid within 10s)"
else
  sleep 1; [ -f "$repo/held-go.txt" ] || held=1
  touch "$TEST_ROOT/go-2"; wait_file "$jh2/exit"
  if [ "$held" -eq 1 ] && [ "$(cat "$jh2/exit" 2>/dev/null)" = 0 ] && [ "$(meta "$jh2" state)" = exited ] && [ "$(cat "$repo/held-go.txt" 2>/dev/null)" = released ]; then pass "a launch held at the barrier runs as usual once it is released"; else fail "a launch held at the barrier runs as usual once it is released (held=$held, exit=$(cat "$jh2/exit" 2>/dev/null), state=$(meta "$jh2" state))"; fi
fi
# the finish window: the command is already gone, so a signal must not cost the
# record. The workspace lock is held while the supervisor tries to write it.
jf=$(newjob finishwin)
mkdir -p "$lockdir"; printf 'pid=1\n' > "$lockdir/owner"
( HYPERPOWERS_LOCK_WAIT_STEPS=2 tj run "$jf" -- bash -c 'exit 7' >/dev/null 2>&1 ) &
if ! wait_meta "$jf" run_pid; then fail "a TERM during a lock-held finish does not cost the record (no run_pid within 10s)"; rm -rf "$lockdir"
else
  sleep 2; kill -TERM "$(meta "$jf" run_pid)" 2>/dev/null; sleep 1; rm -rf "$lockdir"; wait_file "$jf/exit"
  if [ "$(cat "$jf/exit" 2>/dev/null)" = 7 ] && [ "$(meta "$jf" state)" = exited ]; then pass "a TERM during a lock-held finish does not cost the record"; else fail "a TERM during a lock-held finish does not cost the record (exit=$(cat "$jf/exit" 2>/dev/null), state=$(meta "$jf" state))"; fi
fi
# path trust: a directory outside the workspace, and a symlinked job directory, are refused.
mkdir -p "$TEST_ROOT/outside"; cp "$j4/meta.json" "$TEST_ROOT/outside/"
out=$(tj run "$TEST_ROOT/outside" -- bash -c 'exit 0'); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "run refuses a job directory outside the workspace"; else fail "run refuses a job directory outside the workspace (rc=$rc: $out)"; fi
ln -s "$j4" "$ws/jobs/link-x-0000"
out=$(tj run "$ws/jobs/link-x-0000" -- bash -c 'exit 0'); rc=$?; rm -f "$ws/jobs/link-x-0000"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "run refuses a symlinked job directory"; else fail "run refuses a symlinked job directory (rc=$rc: $out)"; fi
# a legitimate job directory whose metadata names another repository: refused before any lock or write.
repo2="$TEST_ROOT/repo2"; git init -q -b main "$repo2"
j4b=$(newjob forged)
node -e 'const fs=require("fs"),p=process.argv[1]+"/meta.json",m=JSON.parse(fs.readFileSync(p,"utf8"));m.plan_dir=process.argv[2];fs.writeFileSync(p,JSON.stringify(m))' "$j4b" "$repo2"
out=$(tj run "$j4b" -- bash -c 'exit 0'); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(meta "$j4b" state)" = allocated ] && [ ! -e "$j4b/exit" ]; then pass "run refuses a job whose metadata names another repository"; else fail "run refuses a job whose metadata names another repository (rc=$rc: $out)"; fi

echo "=== tracked-job conclude ==="
# The terminal state and its ledger line are one transaction under the lock:
# a state the hook can see but the ledger cannot name is a job that never
# happened as far as a later session is concerned. The suite calls conclude
# directly (the library seam), because run's own transitions carry no line.
records() { HYPERPOWERS_TEST_LIB_ONLY=1 bash -c '. "$0"; hp_ledger_records "$1"' "$TJ" "$ws/progress.md" 2>/dev/null; }
cj=$(newjob ordering)
node -e 'const fs=require("fs"),p=process.argv[1]+"/meta.json",m=JSON.parse(fs.readFileSync(p,"utf8"));m.state="running";fs.writeFileSync(p,JSON.stringify(m))' "$cj"
out=$(HYPERPOWERS_TEST_FAIL_APPEND=1 HYPERPOWERS_TEST_LIB_ONLY=1 bash -c '. "$0"; conclude "$1" running exited "exited code=0" "code:=0" >/dev/null; echo "rc=$?"' "$TJ" "$cj" 2>/dev/null)
if [ "$out" = "rc=1" ] && [ "$(meta "$cj" state)" = running ] && [ "$(records | grep -c 'ordering exited')" = 0 ]; then pass "a ledger line that fails to land leaves the terminal state unwritten"; else fail "a ledger line that fails to land leaves the terminal state unwritten ($out, state=$(meta "$cj" state), records=$(records | grep -c 'ordering exited'))"; fi
out=$(HYPERPOWERS_TEST_LIB_ONLY=1 bash -c '. "$0"; conclude "$1" running exited "exited code=0" "code:=0" >/dev/null; echo "rc=$?"' "$TJ" "$cj" 2>/dev/null)
if [ "$out" = "rc=0" ] && [ "$(meta "$cj" state)" = exited ] && [ "$(records | grep -c 'ordering exited')" = 1 ]; then pass "the retry appends the line once and writes the state with it"; else fail "the retry appends the line once and writes the state with it ($out, state=$(meta "$cj" state), records=$(records | grep -c 'ordering exited'))"; fi
# The finish holds the workspace lock, and hp_lock arms INT and TERM handlers
# that unlock and exit. A supervisor whose command has already gone must not
# take them, so it asks the lock to leave its dispositions alone.
keep=$(HYPERPOWERS_TEST_LIB_ONLY=1 bash -c '. "$0"; trap "" TERM; HP_LOCK_KEEP_DISPOSITIONS=1 hp_lock "$1" >/dev/null 2>&1; trap -p TERM; hp_unlock' "$TJ" "$repo" 2>/dev/null)
arm=$(HYPERPOWERS_TEST_LIB_ONLY=1 bash -c '. "$0"; trap "" TERM; hp_lock "$1" >/dev/null 2>&1; trap -p TERM; hp_unlock' "$TJ" "$repo" 2>/dev/null)
case "$keep" in "trap -- '' SIGTERM"|"trap -- '' TERM") pass "the lock keeps the caller's signal dispositions when it is asked to" ;; *) fail "the lock keeps the caller's signal dispositions when it is asked to (got: $keep)" ;; esac
case "$arm" in *"hp_unlock; exit 143"*) pass "the lock otherwise arms its own TERM handler" ;; *) fail "the lock otherwise arms its own TERM handler (got: $arm)" ;; esac

echo "=== tracked-job process identity ==="
# process relationships (deviation 1), where ps works.
if [ "$HAVE_PS" -eq 1 ]; then
  # The command outlives the readiness wait by a wide margin: ps must read a
  # live child, and under load the launch itself can take seconds.
  j9=$(newjob groups); ( tj run "$j9" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
  if ! wait_meta "$j9" pid; then
    fail "the child leads its own process group inside the supervisor's session (no pid within 10s)"
    fail "a KILL to the child's group leaves the supervisor alive to record 137 (no pid within 10s)"
  else
    cpid=$(meta "$j9" pid); rpid=$(meta "$j9" run_pid)
    cpg=$(ps -o pgid= -p "$cpid" | tr -d ' '); rpg=$(ps -o pgid= -p "$rpid" | tr -d ' '); csid=$(ps -o sess= -p "$cpid" | tr -d ' '); rsid=$(ps -o sess= -p "$rpid" | tr -d ' ')
    # csid = rsid alone does not discriminate: macOS prints 0 for any process
    # that is not a session leader, so two zeros say nothing. The child must
    # also not be a session leader, which is exactly what setsid would make it
    # (sess becomes the leader's pid on macOS and on Linux).
    if [ "$cpg" = "$cpid" ] && [ "$cpg" != "$rpg" ] && [ "$csid" = "$rsid" ] && [ "$csid" != "$cpid" ]; then pass "the child leads its own process group inside the supervisor's session"; else fail "the child leads its own process group inside the supervisor's session (child $cpid pgid $cpg sid $csid; run $rpid pgid $rpg sid $rsid)"; fi
    printf '%s\n' "child=$cpid pgid=$cpg sid=$csid run=$rpid pgid=$rpg sid=$rsid" > "$TEST_ROOT/groups.txt"; cat "$TEST_ROOT/groups.txt"
    kill -KILL -- "-$cpg" 2>/dev/null; wait_file "$j9/exit"
    if [ "$(cat "$j9/exit" 2>/dev/null)" = 137 ] && [ "$(meta "$j9" state)" = exited ]; then pass "a KILL to the child's group leaves the supervisor alive to record 137"; else fail "a KILL to the child's group leaves the supervisor alive to record 137 (exit=$(cat "$j9/exit" 2>/dev/null))"; fi
  fi
else
  skip "the child leads its own process group inside the supervisor's session (ps unavailable)"
  skip "a KILL to the child's group leaves the supervisor alive to record 137 (ps unavailable)"
fi

echo "=== tracked-job wait ==="
# an exited job: exited code=0, the terminal line once, repeats append nothing.
out=$(tj wait "$j1" --max-ms 1000); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=exited code=0" ] && [ "$(grep -c "^job s1 .*: soak exited code=0 jobdir=$j1\$" "$ws/progress.md")" = 1 ]; then pass "wait reports exited code=0 and appends the terminal line once"; else fail "wait reports exited code=0 and appends the terminal line once (rc=$rc: $out)"; fi
tj wait "$j1" --max-ms 1000 >/dev/null; tj wait "$j1" --max-ms 1000 >/dev/null
if [ "$(grep -c "^job s1 .*: soak exited code=0 jobdir=$j1\$" "$ws/progress.md")" = 1 ]; then pass "repeated waits append nothing"; else fail "repeated waits append nothing"; fi
out=$(tj wait "$j4" --max-ms 1000); rc=$?
if [ "$rc" -eq 1 ] && [ "$out" = "status=exited code=3" ]; then pass "a nonzero exit is reported with exit 1"; else fail "a nonzero exit is reported with exit 1 (rc=$rc: $out)"; fi
# the exit file that could not be published (jx above, whose command put a
# directory in its place): the code is in meta.json, which a terminal state
# makes trustworthy, so wait still reports the command's status.
out=$(tj wait "$jx" --max-ms 1000); rc=$?
if [ "$rc" -eq 1 ] && [ "$out" = "status=exited code=5" ]; then pass "wait falls back to the code in meta.json when the exit file could not be published"; else fail "wait falls back to the code in meta.json when the exit file could not be published (rc=$rc: $out)"; fi
out=$(tj wait "$j2" --max-ms 1500); rc=$?
if [ "$rc" -eq 5 ] && [ "$out" = "status=not-started" ]; then pass "wait on an allocated job is not-started at the bound"; else fail "wait on an allocated job is not-started at the bound (rc=$rc: $out)"; fi
j10=$(newjob slow); ( tj run "$j10" -- bash -c 'sleep 4; exit 0' >/dev/null 2>&1 ) &
if ! wait_launched "$j10"; then
  fail "wait returns running within its bound while the command runs (the launch did not open within 10s)"
  fail "the same job is exited once the command ends (the launch did not open within 10s)"
else
  t0=$(date +%s); out=$(tj wait "$j10" --max-ms 1000); rc=$?; t1=$(date +%s)
  if [ "$rc" -eq 3 ] && [ "$out" = "status=running" ] && [ $((t1 - t0)) -le 3 ]; then pass "wait returns running within its bound while the command runs"; else fail "wait returns running within its bound while the command runs (rc=$rc: $out, $((t1 - t0))s)"; fi
  out=$(tj wait "$j10" --max-ms 10000); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "status=exited code=0" ]; then pass "the same job is exited once the command ends"; else fail "the same job is exited once the command ends (rc=$rc: $out)"; fi
fi
# a suspended supervisor is running, never lost (deviation 2).
j11=$(newjob frozen); ( tj run "$j11" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
if ! wait_launched "$j11"; then
  fail "a stopped supervisor keeps the job running (the launch did not open within 10s)"
  fail "a supervisor that does not answer yields stop-timeout and the job stays running (the launch did not open within 10s)"
else
  rp=$(meta "$j11" run_pid); kill -STOP "$rp"; sleep 3
  out=$(tj wait "$j11" --max-ms 1000); rc=$?
  if [ "$rc" -eq 3 ] && [ "$out" = "status=running" ]; then pass "a stopped supervisor keeps the job running"; else fail "a stopped supervisor keeps the job running (rc=$rc: $out)"; fi
  out=$(TRACKED_JOB_STOP_WAIT_S=2 tj stop "$j11"); rc=$?
  if [ "$rc" -eq 6 ] && [ "$out" = "status=stop-timeout" ] && [ "$(meta "$j11" state)" = running ]; then pass "a supervisor that does not answer yields stop-timeout and the job stays running"; else fail "a supervisor that does not answer yields stop-timeout (rc=$rc: $out)"; fi
  kill -CONT "$rp"; TRACKED_JOB_GRACE_S=1 tj stop "$j11" >/dev/null 2>&1
fi
# lost: the supervisor killed with KILL; its pid answers ESRCH; wait says lost once.
j12=$(newjob lost); ( tj run "$j12" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
if ! wait_launched "$j12"; then fail "a killed supervisor leaves a lost job that wait reports once (the launch did not open within 10s)"
else
  kill -KILL "$(meta "$j12" run_pid)"; sleep 1
  out=$(tj wait "$j12" --max-ms 1000); rc=$?
  if [ "$rc" -eq 4 ] && [ "$out" = "status=lost" ] && [ "$(meta "$j12" state)" = lost ] && [ "$(grep -c "^job s1 .*: lost lost jobdir=$j12\$" "$ws/progress.md")" = 1 ]; then pass "a killed supervisor leaves a lost job that wait reports once"; else fail "a killed supervisor leaves a lost job that wait reports once (rc=$rc: $out)"; fi
  kill -KILL -- "-$(meta "$j12" pgid)" 2>/dev/null
fi
# a reused supervisor pid: alive, but not the process recorded at launch (ps only).
if [ "$HAVE_PS" -eq 1 ]; then
  j18=$(newjob reused); ( tj run "$j18" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
  if ! wait_launched "$j18"; then
    fail "a supervisor pid now owned by another process reads as lost (the launch did not open within 10s)"
    fail "stop on the reused pid does not wait on the stranger (the launch did not open within 10s)"
  else
    realrun=$(meta "$j18" run_pid)
    node -e 'const fs=require("fs"),p=process.argv[1]+"/meta.json",m=JSON.parse(fs.readFileSync(p,"utf8"));m.run_pid=Number(process.argv[2]);fs.writeFileSync(p,JSON.stringify(m))' "$j18" "$$"
    out=$(tj wait "$j18" --max-ms 1000); rc=$?
    if [ "$rc" -eq 4 ] && [ "$out" = "status=lost" ] && [ "$(meta "$j18" state)" = lost ]; then pass "a supervisor pid now owned by another process reads as lost"; else fail "a supervisor pid now owned by another process reads as lost (rc=$rc: $out)"; fi
    out=$(TRACKED_JOB_STOP_WAIT_S=2 TRACKED_JOB_GRACE_S=1 tj stop "$j18"); rc=$?
    if [ "$rc" -ne 6 ]; then pass "stop on the reused pid does not wait on the stranger"; else fail "stop on the reused pid does not wait on the stranger (rc=$rc: $out)"; fi
    kill -TERM "$realrun" 2>/dev/null; sleep 3
  fi
else
  skip "a supervisor pid now owned by another process reads as lost (ps unavailable)"
  skip "stop on the reused pid does not wait on the stranger (ps unavailable)"
fi

echo "=== tracked-job stop ==="
j13=$(newjob stubborn); ( tj run "$j13" -- bash -c 'trap "" TERM; sleep 60' >/dev/null 2>&1 ) &
if ! wait_launched "$j13"; then fail "stop ends a TERM-resistant command through the supervisor, records 137 and the line once (the launch did not open within 10s)"
else
  t0=$(date +%s); out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j13"); rc=$?; t1=$(date +%s)
  if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && [ "$(cat "$j13/exit" 2>/dev/null)" = 137 ] && [ "$(meta "$j13" state)" = stopped ] && [ $((t1 - t0)) -le 15 ] && [ "$(grep -c "^job s1 .*: stubborn stopped jobdir=$j13\$" "$ws/progress.md")" = 1 ]; then pass "stop ends a TERM-resistant command through the supervisor, records 137 and the line once"; else fail "stop ends a TERM-resistant command through the supervisor (rc=$rc: $out, exit=$(cat "$j13/exit" 2>/dev/null))"; fi
fi
j14=$(newjob parent); ( tj run "$j14" -- bash -c 'sleep 60 & echo $! > child.pid; wait' >/dev/null 2>&1 ) &
if ! wait_launched "$j14"; then fail "stop ends the command's children with it (the launch did not open within 10s)"
else
  wait_file "$repo/child.pid"; childpid=$(cat "$repo/child.pid" 2>/dev/null)
  out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j14"); rc=$?; sleep 1
  if [ "$rc" -eq 0 ] && [ -n "$childpid" ] && ! kill -0 "$childpid" 2>/dev/null; then pass "stop ends the command's children with it"; else fail "stop ends the command's children with it (rc=$rc: $out, child=$childpid)"; fi
fi
# the leader exits on TERM while a descendant ignores it: KILL still reaches the group.
j19=$(newjob orphaning); ( tj run "$j19" -- bash -c '(trap "" TERM; exec sleep 60) & echo $! > inner.pid; trap "exit 0" TERM; wait' >/dev/null 2>&1 ) &
if ! wait_launched "$j19"; then fail "stop ends a TERM-ignoring descendant after its leader exits on TERM (the launch did not open within 10s)"
else
  wait_file "$repo/inner.pid"; inner=$(cat "$repo/inner.pid" 2>/dev/null)
  out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j19"); rc=$?; sleep 1
  if [ "$rc" -eq 0 ] && [ -n "$inner" ] && ! kill -0 "$inner" 2>/dev/null && [ "$(meta "$j19" state)" = stopped ]; then pass "stop ends a TERM-ignoring descendant after its leader exits on TERM"; else fail "stop ends a TERM-ignoring descendant after its leader exits on TERM (rc=$rc: $out, inner=$inner)"; fi
fi
out=$(tj stop "$j4"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=not-running" ]; then pass "stop on a finished job is not-running"; else fail "stop on a finished job is not-running (rc=$rc: $out)"; fi
# the fence's two halves, read straight against a supplied proc tree, which
# needs no ps: the variable, the descriptor on the job's out.log, both dropped,
# and a process with nothing to read.
fp="$TEST_ROOT/fenceproc"; mkdir -p "$fp/11" "$fp/12/fd" "$fp/13/fd"
printf 'TRACKED_JOB_DIR=%s\0HOME=/x\0' "$j1" > "$fp/11/environ"
ln -s "$j1/out.log" "$fp/12/fd/1"
printf 'OTHER=1\0' > "$fp/13/environ"; ln -s /dev/null "$fp/13/fd/1"
out=$(TRACKED_JOB_PROC_ROOT="$fp" HYPERPOWERS_TEST_LIB_ONLY=1 bash -c '. "$0"; for p in 11 12 13 14; do if fenced "$p" "$1"; then printf "%s=yes " "$p"; else printf "%s=no " "$p"; fi; done' "$TJ" "$j1" 2>/dev/null)
if [ "$out" = "11=yes 12=yes 13=no 14=no " ]; then pass "the fence is the TRACKED_JOB_DIR variable or an out.log descriptor, and nothing else"; else fail "the fence is the TRACKED_JOB_DIR variable or an out.log descriptor, and nothing else (got: $out)"; fi
# the readability gate asks whether the reader that will be used can see this
# job's processes: a tree that holds none of them, or a host where lsof cannot
# list a *child's* descriptors, is no fence at all. The answer is the function's
# own status, so a function that went missing reads as 127 and not as a false no.
canfence() { TRACKED_JOB_PROC_ROOT="$1" PATH="$2" HYPERPOWERS_TEST_LIB_ONLY=1 bash -c '. "$0"; can_read_fence "$1" "$2"; echo "rc=$?"' "$TJ" "$j1" "$3" 2>/dev/null; }
# A PATH without lsof has to keep what the gate needs to run at all: bash to
# start the seam, dirname for the helper's own directory, node for the metadata
# reader, sleep and grep for the lsof probe. A missing one of those reads as an
# empty answer below rather than as a false rc.
mkdir -p "$TEST_ROOT/emptyproc" "$TEST_ROOT/nolsof"
for b in bash dirname node sleep grep; do ln -sf "$(command -v "$b")" "$TEST_ROOT/nolsof/$b"; done
# the tree is the reader wherever one is supplied, so lsof must not answer
# behind it: this PATH has lsof and the answer must still be no.
out=$(canfence "$TEST_ROOT/emptyproc" "$PATH" "4241 4242")
if [ "$out" = "rc=1" ]; then pass "a proc tree that holds none of the group is an unreadable fence, and lsof is not consulted behind it"; else fail "a proc tree that holds none of the group is an unreadable fence, and lsof is not consulted behind it (got: $out)"; fi
# one live member is enough, and it need not be the leader: 4241 stands for a
# leader that has exited and left 4242 running.
mkdir -p "$TEST_ROOT/treeproc/4242"
out=$(canfence "$TEST_ROOT/treeproc" "$TEST_ROOT/nolsof" "4241 4242")
if [ "$out" = "rc=0" ]; then pass "a proc tree that holds any live member of the group is a readable fence, with no lsof on the host"; else fail "a proc tree that holds any live member of the group is a readable fence, with no lsof on the host (got: $out)"; fi
out=$(canfence /proc "$TEST_ROOT/nolsof" "4241 4242")
if [ "$out" = "rc=1" ]; then pass "a host with neither a tree that holds the group nor lsof has no readable fence"; else fail "a host with neither a tree that holds the group nor lsof has no readable fence (got: $out)"; fi
if [ -d /proc ]; then skip "lsof answers the gate for a child where there is no proc tree (this host has /proc)"
elif ! command -v lsof >/dev/null 2>&1; then skip "lsof answers the gate for a child where there is no proc tree (lsof unavailable)"
else
  out=$(canfence /proc "$PATH" "4241 4242")
  if [ "$out" = "rc=0" ]; then pass "lsof answers the gate for a child where there is no proc tree"; else fail "lsof answers the gate for a child where there is no proc tree (got: $out)"; fi
fi
# lost-job sweep: fenced survivors ended one by one; a fenceless process in the group left alone (ps only).
j15=$(newjob survivors); ( tj run "$j15" -- bash -c 'sleep 60 & env -u TRACKED_JOB_DIR sleep 60 >/dev/null 2>&1 & echo $! > stranger.pid; wait' >/dev/null 2>&1 ) &
stranger=""; out=""; rc=99
if ! wait_launched "$j15"; then fail "the lost job's sweep has no launch to sweep (the launch did not open within 10s)"
else
  wait_file "$repo/stranger.pid"; stranger=$(cat "$repo/stranger.pid" 2>/dev/null)
  kill -KILL "$(meta "$j15" run_pid)"; sleep 1
  out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j15"); rc=$?; sleep 1
fi
if [ "$HAVE_PS" -eq 1 ]; then
  if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && ! kill -0 "$(meta "$j15" pid)" 2>/dev/null && kill -0 "$stranger" 2>/dev/null && [ "$(meta "$j15" skipped)" = 1 ] && [ "$(meta "$j15" state)" = stopped ]; then pass "stop on a lost job ends the fenced survivors and leaves the fenceless process, counting it as skipped"; else fail "stop on a lost job ends the fenced survivors and leaves the fenceless process (rc=$rc: $out, skipped=$(meta "$j15" skipped))"; fi
  if [ "$(grep -c "^job s1 .*: survivors stopped jobdir=$j15\$" "$ws/progress.md")" = 1 ]; then pass "the lost job's stopped line is written once"; else fail "the lost job's stopped line is written once"; fi
  out=$(tj stop "$j15"); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "status=not-running" ]; then pass "a second stop on the swept job is not-running"; else fail "a second stop on the swept job is not-running (rc=$rc: $out)"; fi
  out=$(tj wait "$j15" --max-ms 1000); rc=$?
  if [ "$rc" -eq 4 ] && [ "$out" = "status=lost" ]; then pass "wait on a swept lost job reports lost"; else fail "wait on a swept lost job reports lost (rc=$rc: $out)"; fi
  # the fence through a supplied proc tree: only the processes one of whose halves carries it are signalled.
  j21=$(newjob procfence); ( tj run "$j21" -- bash -c 'sleep 60 & echo $! > a.pid; sleep 60 & echo $! > b.pid; env -u TRACKED_JOB_DIR sleep 60 & echo $! > c.pid; wait' >/dev/null 2>&1 ) &
  if ! wait_launched "$j21"; then fail "the supplied proc tree signals only the fenced processes (the launch did not open within 10s)"
  else
    wait_file "$repo/c.pid"
    pa=$(cat "$repo/a.pid" 2>/dev/null); pb=$(cat "$repo/b.pid" 2>/dev/null); pc=$(cat "$repo/c.pid" 2>/dev/null); leader=$(meta "$j21" pid)
    kill -KILL "$(meta "$j21" run_pid)"; sleep 1
    # the group holds four processes, one per fence shape: the leader fenced by
    # its environment, pa by a descriptor on out.log alone, pb with no entry at
    # all (unreadable), pc with both halves dropped.
    proc="$TEST_ROOT/proc"; mkdir -p "$proc/$leader" "$proc/$pa/fd" "$proc/$pc/fd"
    printf 'TRACKED_JOB_DIR=%s\0HOME=/x\0' "$j21" > "$proc/$leader/environ"
    ln -s "$j21/out.log" "$proc/$pa/fd/1"
    printf 'OTHER=1\0' > "$proc/$pc/environ"; ln -s /dev/null "$proc/$pc/fd/1"
    out=$(TRACKED_JOB_PROC_ROOT="$proc" TRACKED_JOB_GRACE_S=1 tj stop "$j21"); rc=$?; sleep 1
    if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && ! kill -0 "$leader" 2>/dev/null && ! kill -0 "$pa" 2>/dev/null && kill -0 "$pb" 2>/dev/null && kill -0 "$pc" 2>/dev/null && [ "$(meta "$j21" skipped)" = 2 ] && [ "$(meta "$j21" survivors)" = 0 ]; then pass "the supplied proc tree signals the environment-fenced and the descriptor-fenced process; the unreadable one and the fenceless one are skipped and counted"; else fail "the supplied proc tree signals only the fenced processes (rc=$rc: $out, skipped=$(meta "$j21" skipped), survivors=$(meta "$j21" survivors))"; fi
    kill -KILL "$pb" "$pc" 2>/dev/null; rm -rf "$proc"
  fi
  # a proc tree that holds none of the job's processes: the sweep would find
  # nothing to signal and record a clean stop, so the gate refuses instead.
  j26=$(newjob blindtree); ( tj run "$j26" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
  if ! wait_launched "$j26"; then fail "a lost job read against a tree that cannot see it is lost-unswept, and nothing is signalled (the launch did not open within 10s)"
  else
    leader26=$(meta "$j26" pid); kill -KILL "$(meta "$j26" run_pid)"; sleep 1
    out=$(TRACKED_JOB_PROC_ROOT="$TEST_ROOT/emptyproc" tj stop "$j26"); rc=$?
    if [ "$rc" -eq 7 ] && [ "$out" = "status=lost-unswept pgid=$(meta "$j26" pgid)" ] && [ "$(meta "$j26" state)" = lost-unswept ] && kill -0 "$leader26" 2>/dev/null; then pass "a lost job read against a tree that cannot see it is lost-unswept, and nothing is signalled"; else fail "a lost job read against a tree that cannot see it is lost-unswept, and nothing is signalled (rc=$rc: $out, state=$(meta "$j26" state))"; fi
    kill -KILL -- "-$(meta "$j26" pgid)" 2>/dev/null
  fi
  # a leader that exited while its children run: the tree holds no entry for
  # the dead leader, but every live member's fence is readable there, so the
  # sweep must proceed rather than refuse.
  j27=$(newjob deadleader); ( tj run "$j27" -- bash -c 'sleep 60 & echo $! > e.pid; sleep 2; exit 0' >/dev/null 2>&1 ) &
  if ! wait_launched "$j27"; then fail "a lost job whose leader has exited is swept through its live members (the launch did not open within 10s)"
  else
    wait_file "$repo/e.pid"; child27=$(cat "$repo/e.pid" 2>/dev/null)
    kill -KILL "$(meta "$j27" run_pid)"; sleep 4
    dtree="$TEST_ROOT/deadleaderproc"; mkdir -p "$dtree/$child27/fd"; ln -s "$j27/out.log" "$dtree/$child27/fd/1"
    out=$(TRACKED_JOB_PROC_ROOT="$dtree" TRACKED_JOB_GRACE_S=1 tj stop "$j27"); rc=$?; sleep 1
    if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && [ -n "$child27" ] && ! kill -0 "$child27" 2>/dev/null && [ "$(meta "$j27" state)" = stopped ] && [ "$(meta "$j27" skipped)" = 0 ] && [ "$(meta "$j27" survivors)" = 0 ] && ! kill -0 "$(meta "$j27" pid)" 2>/dev/null; then pass "a lost job whose leader has exited is swept through its live members"; else fail "a lost job whose leader has exited is swept through its live members (rc=$rc: $out, state=$(meta "$j27" state), child=$child27, skipped=$(meta "$j27" skipped))"; fi
    kill -KILL -- "-$(meta "$j27" pgid)" 2>/dev/null; rm -rf "$dtree"
  fi
  # the descriptor half on its own: the command scrubs the variable from its
  # child's environment but the child keeps the descriptors it inherited, so
  # the sweep still owns it and skips nothing.
  j24=$(newjob descfence); ( tj run "$j24" -- bash -c 'env -u TRACKED_JOB_DIR sleep 60 & echo $! > d.pid; wait' >/dev/null 2>&1 ) &
  if ! wait_launched "$j24"; then fail "a child that kept only the out.log descriptor is still swept (the launch did not open within 10s)"
  else
    wait_file "$repo/d.pid"; dpid=$(cat "$repo/d.pid" 2>/dev/null)
    kill -KILL "$(meta "$j24" run_pid)"; sleep 1
    out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j24"); rc=$?; sleep 1
    if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && [ -n "$dpid" ] && ! kill -0 "$dpid" 2>/dev/null && [ "$(meta "$j24" skipped)" = 0 ] && [ "$(meta "$j24" survivors)" = 0 ]; then pass "a child that kept only the out.log descriptor is still swept"; else fail "a child that kept only the out.log descriptor is still swept (rc=$rc: $out, child=$dpid, skipped=$(meta "$j24" skipped), survivors=$(meta "$j24" survivors))"; fi
    kill -KILL -- "-$(meta "$j24" pgid)" 2>/dev/null
  fi
else
  if [ "$rc" -eq 7 ] && [ "$out" = "status=lost-unswept pgid=$(meta "$j15" pgid)" ] && [ "$(meta "$j15" state)" = lost-unswept ] && [ "$(grep -c "^job s1 .*: survivors lost-unswept pgid=$(meta "$j15" pgid) jobdir=$j15\$" "$ws/progress.md")" = 1 ]; then pass "without ps, stop on a lost job refuses to signal, names the group and records lost-unswept"; else fail "without ps, stop on a lost job refuses to signal and names the group (rc=$rc: $out)"; fi
  out=$(tj wait "$j15" --max-ms 1000); rc=$?
  if [ "$rc" -eq 7 ] && [ "$out" = "status=lost-unswept pgid=$(meta "$j15" pgid)" ]; then pass "wait on a lost-unswept job repeats the state"; else fail "wait on a lost-unswept job repeats the state (rc=$rc: $out)"; fi
  skip "stop on a lost job ends the fenced survivors and leaves the fenceless process (ps unavailable)"
  skip "the lost job's stopped line is written once (ps unavailable)"
  skip "wait on a swept lost job reports lost (ps unavailable)"
  skip "the supplied proc tree signals the environment-fenced and the descriptor-fenced process; the unreadable one and the fenceless one are skipped and counted (ps unavailable)"
  skip "a second stop on the swept job is not-running (ps unavailable)"
  skip "a lost job read against a tree that cannot see it is lost-unswept, and nothing is signalled (ps unavailable)"
  skip "a lost job whose leader has exited is swept through its live members (ps unavailable)"
  skip "a child that kept only the out.log descriptor is still swept (ps unavailable)"
fi
kill -KILL -- "-$(meta "$j15" pgid)" 2>/dev/null
# concurrent wait and stop on a lost job: whichever writes first wins, the job never ends lost with survivors, no outcome line repeats.
j20=$(newjob raced); ( tj run "$j20" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
if ! wait_launched "$j20"; then fail "concurrent wait and stop on a lost job never leave it lost and never repeat a line (the launch did not open within 10s)"
else
  kill -KILL "$(meta "$j20" run_pid)"; sleep 1
  ( tj wait "$j20" --max-ms 8000 > "$TEST_ROOT/raced-wait.out" 2>&1 ) & rw=$!
  ( TRACKED_JOB_GRACE_S=1 tj stop "$j20" > "$TEST_ROOT/raced-stop.out" 2>&1 ) & rs=$!
  wait "$rw" "$rs"
  final=$(meta "$j20" state)
  # The timestamp carries colons, so the outcome is cut by field, not to the
  # first colon: a dedup that leaves the timestamp in finds no duplicate ever.
  dups=$(grep -F "jobdir=$j20" "$ws/progress.md" | sed -E 's/ ?jobdir=.*//; s/^job [^ ]+ [^ ]+: raced ?//' | sort | uniq -d | grep -c .)
  if { [ "$final" = stopped ] || [ "$final" = lost-unswept ]; } && [ "$dups" = 0 ]; then pass "concurrent wait and stop on a lost job never leave it lost and never repeat a line"; else fail "concurrent wait and stop on a lost job never leave it lost and never repeat a line (final=$final dups=$dups; wait: $(cat "$TEST_ROOT/raced-wait.out"); stop: $(cat "$TEST_ROOT/raced-stop.out"))"; fi
  kill -KILL -- "-$(meta "$j20" pgid)" 2>/dev/null
fi
# a held workspace lock: no terminal record is written and no success is claimed; the record repairs once the lock is free.
j22=$(newjob locked); j23=$(newjob lockedexit); j25=$(newjob lockedstop)
( tj run "$j22" -- bash -c 'sleep 60' >/dev/null 2>&1 ) &
if ! wait_launched "$j22"; then
  fail "stop under a held lock is busy and records nothing (the launch did not open within 10s)"
  fail "wait under a held lock reads running at its bound and records nothing (the launch did not open within 10s)"
  fail "a supervisor that cannot take the lock still writes exit and says so in out.log (the launch did not open within 10s)"
  fail "wait repairs the state from the exit file once the lock is free (the launch did not open within 10s)"
  fail "stop on the lost job proceeds once the lock is free (the launch did not open within 10s)"
  fail "stop repairs a job that concluded under the lock instead of calling it lost (the launch did not open within 10s)"
else
  kill -KILL "$(meta "$j22" run_pid)"; sleep 1
  mkdir -p "$lockdir"; printf 'pid=1\n' > "$lockdir/owner"
  out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 tj stop "$j22"); rc=$?
  if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(meta "$j22" state)" = running ]; then pass "stop under a held lock is busy and records nothing"; else fail "stop under a held lock is busy and records nothing (rc=$rc: $out, state=$(meta "$j22" state))"; fi
  out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 tj wait "$j22" --max-ms 3000); rc=$?
  if [ "$rc" -eq 3 ] && [ "$out" = "status=running" ] && [ "$(meta "$j22" state)" = running ]; then pass "wait under a held lock reads running at its bound and records nothing"; else fail "wait under a held lock reads running at its bound and records nothing (rc=$rc: $out, state=$(meta "$j22" state))"; fi
  # Two jobs in the same shape, so that wait's repair and stop's are both
  # tried against a job that concluded with its state left behind.
  ( HYPERPOWERS_LOCK_WAIT_STEPS=2 tj run "$j23" -- bash -c 'exit 0' >/dev/null 2>&1 ) &
  ( HYPERPOWERS_LOCK_WAIT_STEPS=2 tj run "$j25" -- bash -c 'exit 0' >/dev/null 2>&1 ) &
  # The supervisor retries the record five times a second apart before it
  # gives up and publishes the exit anyway, so this outlasts the usual bound.
  i=0; while [ "$i" -lt 40 ] && { [ ! -f "$j23/exit" ] || [ ! -f "$j25/exit" ]; }; do sleep 1; i=$((i + 1)); done
  if [ "$(cat "$j23/exit" 2>/dev/null)" = 0 ] && [ "$(meta "$j23" state)" = running ] && grep -q 'terminal state exited not recorded' "$j23/out.log"; then pass "a supervisor that cannot take the lock still writes exit and says so in out.log"; else fail "a supervisor that cannot take the lock still writes exit and says so in out.log (exit=$(cat "$j23/exit" 2>/dev/null), state=$(meta "$j23" state))"; fi
  rm -rf "$lockdir"
  out=$(tj wait "$j23" --max-ms 1000); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "status=exited code=0" ] && [ "$(meta "$j23" state)" = exited ]; then pass "wait repairs the state from the exit file once the lock is free"; else fail "wait repairs the state from the exit file once the lock is free (rc=$rc: $out, state=$(meta "$j23" state))"; fi
  # the same repair from stop: a job that exited while the lock was held is
  # finished, not lost, and its ledger line says so.
  out=$(tj stop "$j25"); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "status=not-running" ] && [ "$(meta "$j25" state)" = exited ] && [ "$(grep -c "^job s1 .*: lockedstop exited code=0 jobdir=$j25\$" "$ws/progress.md")" = 1 ] && [ "$(grep -c "lockedstop lost jobdir=$j25\$" "$ws/progress.md")" = 0 ]; then pass "stop repairs a job that concluded under the lock instead of calling it lost"; else fail "stop repairs a job that concluded under the lock instead of calling it lost (rc=$rc: $out, state=$(meta "$j25" state))"; fi
  out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j22"); rc=$?
  case "$rc" in 0|7) pass "stop on the lost job proceeds once the lock is free" ;; *) fail "stop on the lost job proceeds once the lock is free (rc=$rc: $out)" ;; esac
  kill -KILL -- "-$(meta "$j22" pgid)" 2>/dev/null
fi
# a stale leader whose group has no fenced member: not-running (ps only).
if [ "$HAVE_PS" -eq 1 ]; then
  j16=$(newjob stale); ( tj run "$j16" -- bash -c 'sleep 2' >/dev/null 2>&1 ) &
  if ! wait_launched "$j16"; then fail "a lost job whose group is already gone is not-running (the launch did not open within 10s)"
  else
    kill -KILL "$(meta "$j16" run_pid)"; sleep 3
    out=$(tj stop "$j16"); rc=$?
    if [ "$rc" -eq 0 ] && [ "$out" = "status=not-running" ] && [ "$(meta "$j16" state)" = stopped ]; then pass "a lost job whose group is already gone is not-running"; else fail "a lost job whose group is already gone is not-running (rc=$rc: $out)"; fi
  fi
else
  skip "a lost job whose group is already gone is not-running (ps unavailable)"
fi
echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures, $skips skipped)"; exit 1; fi
echo "STATUS: PASSED ($skips skipped)"
