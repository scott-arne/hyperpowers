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
  if [ "$(cat "$jh/exit" 2>/dev/null)" = 143 ] && [ "$(meta "$jh" state)" = stopped ] && [ ! -f "$repo/held-ran.txt" ] && ! kill -0 "$(meta "$jh" pid)" 2>/dev/null; then pass "a stop during the launch cancels the command before it runs"; else fail "a stop during the launch cancels the command before it runs (exit=$(cat "$jh/exit" 2>/dev/null), state=$(meta "$jh" state), ran=$([ -f "$repo/held-ran.txt" ] && echo yes || echo no))"; fi
fi
# the same window, reached by a file rather than a signal: a stop-request that
# already stands when the launch would release the command (Task 4's stop
# writes it), and the abort file the deferring trap drops for the child.
js=$(newjob heldreq)
( HYPERPOWERS_TEST_HOLD_BEFORE_BARRIER="$TEST_ROOT/go-3" tj run "$js" -- bash -c 'echo ran > req-ran.txt; sleep 30' >/dev/null 2>&1 ) &
if ! wait_meta "$js" run_pid; then fail "a stop-request standing at the barrier cancels the command (no run_pid within 10s)"
else
  : > "$js/stop-request"; touch "$TEST_ROOT/go-3"; wait_file "$js/exit"
  if [ "$(cat "$js/exit" 2>/dev/null)" = 143 ] && [ "$(meta "$js" state)" = stopped ] && [ ! -f "$repo/req-ran.txt" ]; then pass "a stop-request standing at the barrier cancels the command"; else fail "a stop-request standing at the barrier cancels the command (exit=$(cat "$js/exit" 2>/dev/null), state=$(meta "$js" state), ran=$([ -f "$repo/req-ran.txt" ] && echo yes || echo no))"; fi
fi
ja=$(newjob heldabort)
( HYPERPOWERS_TEST_HOLD_BEFORE_BARRIER="$TEST_ROOT/go-4" tj run "$ja" -- bash -c 'echo ran > abort-ran.txt; sleep 30' >/dev/null 2>&1 ) &
if ! wait_meta "$ja" run_pid; then fail "an abort standing at the barrier cancels the command (no run_pid within 10s)"
else
  : > "$ja/abort"; touch "$TEST_ROOT/go-4"; wait_file "$ja/exit"
  if [ "$(cat "$ja/exit" 2>/dev/null)" = 143 ] && [ "$(meta "$ja" state)" = stopped ] && [ ! -f "$repo/abort-ran.txt" ] && [ ! -e "$ja/abort" ]; then pass "an abort standing at the barrier cancels the command and is cleaned up"; else fail "an abort standing at the barrier cancels the command and is cleaned up (exit=$(cat "$ja/exit" 2>/dev/null), state=$(meta "$ja" state), ran=$([ -f "$repo/abort-ran.txt" ] && echo yes || echo no))"; fi
fi
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

echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures, $skips skipped)"; exit 1; fi
echo "STATUS: PASSED ($skips skipped)"
