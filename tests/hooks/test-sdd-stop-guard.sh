#!/usr/bin/env bash
# The stop guard: the node unit matrix, then the bash wrapper's own behavior
# (registration, exit 0 everywhere, the hook-error line without node, the
# waiting record, the bash/node key parity) and the benchmark.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/sdd-stop-guard"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
SDD_STATE="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-state"
FAILURES=0
TEST_ROOT=$(mktemp -d); TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P)
trap 'rm -rf "$TEST_ROOT"' EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "=== stop guard: unit matrix ==="
if STOP_GUARD_BENCH=1 node --test "$REPO_ROOT/hooks/lib/stop-guard.test.mjs" > "$TEST_ROOT/node.out" 2>&1; then pass "node --test hooks/lib/stop-guard.test.mjs"; else fail "node --test hooks/lib/stop-guard.test.mjs"; tail -n 40 "$TEST_ROOT/node.out"; fi
grep -E '^# bench' "$TEST_ROOT/node.out" || true

echo "=== stop guard: registration ==="
if node -e 'const h=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).hooks.Stop;if(!Array.isArray(h)||h.length!==1)process.exit(1);const c=h[0].hooks[0];if(!c.command.includes("run-hook.cmd\" sdd-stop-guard")||c.timeout!==30||c.shell!=="bash")process.exit(1)' "$REPO_ROOT/hooks/hooks.json"; then pass "hooks.json registers Stop -> run-hook.cmd sdd-stop-guard with a 30 s timeout"; else fail "hooks.json registers Stop -> run-hook.cmd sdd-stop-guard with a 30 s timeout"; fi
if grep -q '"Stop"' "$REPO_ROOT/hooks/hooks-codex.json" 2>/dev/null || grep -q '"Stop"' "$REPO_ROOT/hooks/hooks-cursor.json" 2>/dev/null; then fail "the Codex and Cursor hook files do not register the guard"; else pass "the Codex and Cursor hook files do not register the guard"; fi
head -n 1 "$HOOK" > "$TEST_ROOT/shebang" 2>/dev/null
if [ -x "$HOOK" ] && grep -q '^#!/usr/bin/env bash$' "$TEST_ROOT/shebang"; then pass "the wrapper is an executable bash script"; else fail "the wrapper is an executable bash script"; fi

echo "=== stop guard: wrapper ==="
export XDG_CACHE_HOME="$TEST_ROOT/cache"
repo="$TEST_ROOT/repo"; git init -q -b main "$repo"; git -C "$repo" config user.name t; git -C "$repo" config user.email t@example.com
mkdir -p "$repo/docs"; printf '# Plan\n\n### Task 1: one\n' > "$repo/docs/plan.md"; git -C "$repo" add docs/plan.md; git -C "$repo" commit -q -m plan
input='{"session_id":"s-wrap","transcript_path":"/nonexistent","cwd":"'"$repo"'","hook_event_name":"Stop","stop_hook_active":false}'
out=$(printf '%s' "$input" | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/stop-guard" ]; then pass "a session with no plan: exit 0, no output, nothing written"; else fail "a session with no plan: exit 0, no output, nothing written (rc=$rc: $out)"; fi
key=$(bash -c '. "$1"; hp_key "$2"' _ "$LIB" "$repo")
ws="$XDG_CACHE_HOME/hyperpowers/state/$key/plans/plan-00000000"; mkdir -p "$ws"
printf '# SDD ledger — plan: docs/plan.md\nsession s-wrap: mode worktree on main at %s started x\n' "$repo" > "$ws/progress.md"
printf '%s\n' '{"type":"user","timestamp":"2026-10-23T10:00:00.000Z","isSidechain":false,"origin":{"kind":"human"},"message":{"role":"user","content":"go"}}' '{"type":"assistant","timestamp":"2026-10-23T10:00:05.000Z","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"Moving to Task 1."}]}}' > "$TEST_ROOT/t.jsonl"
input='{"session_id":"s-wrap","transcript_path":"'"$TEST_ROOT/t.jsonl"'","cwd":"'"$repo"'","hook_event_name":"Stop","stop_hook_active":false}'
out=$(printf '%s' "$input" | bash "$HOOK"); rc=$?
printf '%s' "$out" > "$TEST_ROOT/block.out"
if [ "$rc" -eq 0 ] && grep -q '"decision":"block"' "$TEST_ROOT/block.out" && grep -q 'SDD stop guard: plan docs/plan.md is not finished (1 of 1 tasks open; nothing tracked is live)' "$TEST_ROOT/block.out"; then pass "a provable premature stop is refused through the wrapper"; else fail "a provable premature stop is refused through the wrapper (rc=$rc: $out)"; fi
if [ "$(grep -c '"decision":"block"' "$ws/stop-guard.jsonl")" = 1 ] && [ "$(grep -c '"decision":"block"' "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl")" = 1 ]; then pass "the decision is in the plan log and the mirror"; else fail "the decision is in the plan log and the mirror"; fi
# node absent from PATH: hook-error to the mirror, exit 0, nothing in the plan log
nopath="$TEST_ROOT/bin"; mkdir -p "$nopath"
for tool in bash git date mkdir dirname sed head; do ln -s "$(command -v "$tool")" "$nopath/$tool"; done
before=$(wc -l < "$ws/stop-guard.jsonl")
out=$(printf '%s' "$input" | PATH="$nopath" bash "$HOOK"); rc=$?
tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" > "$TEST_ROOT/mirror.last" 2>/dev/null
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"hook-error","detail":"node not found"' "$TEST_ROOT/mirror.last" && [ "$(wc -l < "$ws/stop-guard.jsonl")" = "$before" ]; then pass "without node the wrapper allows and writes hook-error to the mirror"; else fail "without node the wrapper allows and writes hook-error to the mirror (rc=$rc: $out)"; fi
# the module throws: hook-error, exit 0
out=$(printf '%s' "$input" | STOP_GUARD_FAULT=throw bash "$HOOK"); rc=$?
tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" > "$TEST_ROOT/mirror.last" 2>/dev/null
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"hook-error","detail":"module exit 1"' "$TEST_ROOT/mirror.last"; then pass "a module failure allows and writes hook-error"; else fail "a module failure allows and writes hook-error (rc=$rc: $out)"; fi
# the wrapper's line has the documented keys and a parsable timestamp
if node -e 'const l=JSON.parse(require("fs").readFileSync(0,"utf8"));if(l.session!=="s-wrap"||l.decision!=="allow"||isNaN(Date.parse(l.ts)))process.exit(1)' < "$TEST_ROOT/mirror.last"; then pass "the hook-error line is well-formed JSON with ts, session, decision, reason, detail"; else fail "the hook-error line is well-formed JSON"; fi
# malformed stdin, and a session id the mirror path must not take
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass "malformed input exits 0 silently"; else fail "malformed input exits 0 silently (rc=$rc: $out)"; fi
# Node absent, so the bash side composes the mirror path itself: that fallback
# is the only path the wrapper's own grammar check guards, and the cache tree
# before and after proves nothing was created or appended anywhere under it.
snapshot() { ( cd "$XDG_CACHE_HOME" && find . -print | sort | while IFS= read -r f; do if [ -f "$f" ]; then printf '%s %s\n' "$(wc -c < "$f")" "$f"; else printf 'dir %s\n' "$f"; fi; done ); }
# Two ids: the second climbs only into a directory that already exists, so a
# missing guard would really leave a file behind rather than fail on mkdir.
snapshot > "$TEST_ROOT/cache.before"
rc=0; out=""
for sid in '../../etc/x' '../escaped'; do
  o=$(printf '{"session_id":"%s","cwd":"%s"}' "$sid" "$repo" | PATH="$nopath" bash "$HOOK"); r=$?
  [ "$r" -eq 0 ] || rc=$r
  out="$out$o"
done
snapshot > "$TEST_ROOT/cache.after"
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/stop-guard/../../etc" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/escaped.jsonl" ] && cmp -s "$TEST_ROOT/cache.before" "$TEST_ROOT/cache.after"; then pass "a session id with path characters writes nothing"; else fail "a session id with path characters writes nothing (rc=$rc: $(diff "$TEST_ROOT/cache.before" "$TEST_ROOT/cache.after" | tr '\n' ' '))"; fi
# a cap refusal sequence through the real wrapper: the hook-error allows above reset the count, so block, block, allow
out1=$(printf '%s' "$input" | bash "$HOOK"); out2=$(printf '%s' "$input" | bash "$HOOK"); out3=$(printf '%s' "$input" | bash "$HOOK")
printf '%s' "$out1" > "$TEST_ROOT/cap1.out"; printf '%s' "$out2" > "$TEST_ROOT/cap2.out"; tail -n 1 "$ws/stop-guard.jsonl" > "$TEST_ROOT/plan.last" 2>/dev/null
if grep -q '"decision":"block"' "$TEST_ROOT/cap1.out" && grep -q '"decision":"block"' "$TEST_ROOT/cap2.out" && [ -z "$out3" ] && grep -q '"reason":"cap"' "$TEST_ROOT/plan.last"; then pass "after an allow, the third consecutive attempt is allowed as cap through the wrapper"; else fail "after an allow, the third consecutive attempt is allowed as cap through the wrapper ($out1 / $out2 / $out3)"; fi

# A plugin root reached through a symlink: node realpaths the main module's URL
# but leaves argv alone, so a CLI entry that compared the raw path would never
# run and the guard would allow every stop in silence.
ln -s "$REPO_ROOT/hooks" "$TEST_ROOT/hooks-link"
printf '%s' "$input" | bash "$TEST_ROOT/hooks-link/sdd-stop-guard" > "$TEST_ROOT/symlink.out" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && grep -q '"decision":"block"' "$TEST_ROOT/symlink.out"; then pass "the guard still blocks when the hooks directory is reached through a symlink"; else fail "the guard still blocks when the hooks directory is reached through a symlink (rc=$rc: $(cat "$TEST_ROOT/symlink.out"))"; fi

# A plugin root whose path carries URL-significant characters. The module has
# to live there physically: realpath resolves a symlink's own name away, so
# only a real directory puts a # or a % in the path node compares.
odd="$TEST_ROOT/plug#in %root"; mkdir -p "$odd"; cp -R "$REPO_ROOT/hooks" "$odd/hooks"
printf '%s' "$input" | bash "$odd/hooks/sdd-stop-guard" > "$TEST_ROOT/oddpath.out" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && grep -q '"decision":"block"' "$TEST_ROOT/oddpath.out"; then pass "the guard still blocks from a plugin root whose path carries # and %"; else fail "the guard still blocks from a plugin root whose path carries # and % (rc=$rc: $(cat "$TEST_ROOT/oddpath.out"))"; fi

echo "=== stop guard: waiting record ==="
# A controller that has to wait on another session posts its waiting record
# (sdd-state wait, or merge-back on a conflict) and hands back; the turn that
# posted it may end. The workspace is made through the library, as sdd-state
# makes it, so the record sdd-state wait publishes lands where the guard reads.
wrepo="$TEST_ROOT/wrepo"; git init -q -b main "$wrepo"; git -C "$wrepo" config user.name t; git -C "$wrepo" config user.email t@example.com
mkdir -p "$wrepo/docs"; printf '# Plan\n\n### Task 1: one\n\n### Task 2: two\n' > "$wrepo/docs/plan.md"; git -C "$wrepo" add docs/plan.md; git -C "$wrepo" commit -q -m plan
wws=$(bash -c '. "$1"; e=$(hp_ensure_checkout "$2") || exit 2; printf "%s/plans/%s\n" "${e#* }" "$(hp_plan_ws_name "$3")"' _ "$LIB" "$wrepo" "$wrepo/docs/plan.md")
mkdir -p "$wws"
printf '# SDD ledger — plan: docs/plan.md\nsession s-wait: mode worktree on main at %s started x\nsession s-e2e: mode worktree on main at %s started x\n' "$wrepo" "$wrepo" > "$wws/progress.md"
wrec="$wws/waiting/s-wait"
# wait_decide <prompt ts> [<record text>]: decideStop for s-wait, with
# discovery, plan, jobs and refusals read the way main reads them and the
# record text injected when given, printed as "<decision> <reason>" and then
# the detail, if any.
wait_decide() {
  STOP_GUARD_MODULE="$REPO_ROOT/hooks/lib/stop-guard.mjs" node -e '
    const [cwd, cacheRoot, promptTs, ...inject] = process.argv.slice(1);
    import(process.env.STOP_GUARD_MODULE).then((g) => {
      const sessionId = "s-wait";
      const discovery = g.discover({ sessionId, cwd, cacheRoot });
      const ws = discovery.workspace || "";
      const plan = g.planState({ workspace: ws, cwd, sessionId });
      const jobs = g.liveJobs(ws, sessionId);
      const read = g.refusalsBefore({ workspaceLog: ws + "/stop-guard.jsonl", mirrorLog: cacheRoot + "/hyperpowers/stop-guard/s-wait.jsonl", sessionId });
      const turn = { ok: true, tooLong: false, promptTs, lastAssistantText: "Task 1 is held by another session; waiting on it.", liveAgents: [], liveShells: [] };
      const d = g.decideStop({ discovery, plan, turn, jobs: jobs.live, jobsUnreadable: jobs.unreadable, refusals: read.refusals, refusalsUnreadable: read.unreadable, sessionId, ...(inject.length ? { waitingText: inject[0] } : {}) });
      process.stdout.write([d.decision, d.reason, d.detail].filter(Boolean).join(" "));
    });' "$wrepo" "$XDG_CACHE_HOME" "$@"
}
# wait_case <description> <expected> <prompt ts> [<record text>]
wait_case() { local d=$1 want=$2 got; shift 2; got=$(wait_decide "$@"); if [ "$got" = "$want" ]; then pass "$d"; else fail "$d (got: $got)"; fi; }
# wait_record <line>...: s-wait's record, one line per argument. wait_fields
# <since> [<session>]: the fields sdd-state wait writes, in its order.
wait_record() { rm -rf "$wrec"; mkdir -p "$wws/waiting"; printf '%s\n' "$@" > "$wrec"; }
wait_fields() { wait_record "session=${2:-s-wait}" task=none kind=tasks "since=$1" "note=held: 1@s2" "worktree=$wrepo" branch=main host=h; }
P=2026-11-07T15:09:12.400Z
wait_case "no waiting directory: the decision is unchanged (block open-tasks)" "block open-tasks" "$P"
mkdir -p "$wws/waiting"
wait_case "an empty waiting directory: the decision is unchanged (block open-tasks)" "block open-tasks" "$P"
wait_fields 2026-11-07T15:09:30Z
wait_case "this session's record posted after the prompt allows as waiting-record, tasks open" "allow waiting-record" "$P"
wait_fields 2026-11-07T15:09:12Z
wait_case "a record posted in the prompt's own second counts: the prompt is truncated to whole seconds" "allow waiting-record" "$P"
wait_fields 2026-11-07T15:09:11Z
wait_case "a record from before the prompt's second is an earlier turn's (block open-tasks)" "block open-tasks" "$P"
wait_record session=s-wait since=2026-11-07T15:09:11Z since=2026-11-07T15:09:30Z
wait_case "the first since= line is the one read, as the board reads it" "block open-tasks" "$P"
wait_fields 2026-11-07T15:09:30Z s-other
wait_case "a record whose session= names another session does not count" "block open-tasks" "$P"
wait_record session=s-other session=s-wait since=2026-11-07T15:09:30Z
wait_case "the first session= line is the one read, as the board reads it" "block open-tasks" "$P"
rm -f "$wrec"; printf 'session=s-other\nsince=2026-11-07T15:09:30Z\n' > "$wws/waiting/s-other"
wait_case "another session's record does not count for this one" "block open-tasks" "$P"
rm -f "$wws/waiting/s-other"
# 2099 is a date Date.parse accepts, and a later one than the prompt.
for since in '' yesterday 2099 2026-11-07T15:09:30; do
  wait_fields "$since"
  wait_case "a record with since=$since does not count" "block open-tasks" "$P"
done
wait_record session=s-wait task=none kind=tasks note=x
wait_case "a record without a since= line does not count" "block open-tasks" "$P"
rm -f "$wrec"; mkdir "$wrec"
wait_case "a directory at the record path allows as hook-error, naming it" "allow hook-error waiting record unreadable: $wrec" "$P"
wait_case "an injected record is read instead of the file, as ledgerText is" "allow waiting-record" "$P" "$(printf 'session=s-wait\nsince=2026-11-07T15:09:30Z')"
rmdir "$wrec"
wait_fields 2026-11-07T15:09:30Z; chmod 000 "$wrec"
wait_case "a record that cannot be read allows as hook-error, naming it" "allow hook-error waiting record unreadable: $wrec" "$P"
chmod 600 "$wrec"; rm -f "$wrec"
# A writer holds the fifo for five seconds and never writes: a guard that read
# it would wait it out and then find no record.
mkfifo "$wrec"; sleep 5 > "$wrec" & writer=$!
wait_case "a fifo at the record path is not read: hook-error, naming it" "allow hook-error waiting record unreadable: $wrec" "$P"
kill "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; rm -f "$wrec"
printf 'Task 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' >> "$wws/progress.md"
wait_case "every task complete and no record: unchanged (block open-tasks)" "block open-tasks" "$P"
wait_fields 2026-11-07T15:09:30Z
wait_case "every task complete (the final held elsewhere): this turn's record allows as waiting-record" "allow waiting-record" "$P"
rm -f "$wrec"
# End to end: the record sdd-state wait publishes, through the wrapper and main.
wait_turn() { printf '{"ok":true,"tooLong":false,"promptTs":"%s","lastAssistantText":"Task 1 is held by another session; waiting on it.","liveAgents":[],"liveShells":[]}' "$1"; }
winput='{"session_id":"s-e2e","transcript_path":"/nonexistent","cwd":"'"$wrepo"'","hook_event_name":"Stop","stop_hook_active":false}'
pts=$(node -e 'process.stdout.write(new Date().toISOString())')
out0=$(printf '%s' "$winput" | STOP_GUARD_TURN="$(wait_turn "$pts")" bash "$HOOK")
wout=$(cd "$wrepo" && bash "$SDD_STATE" wait docs/plan.md --session s-e2e --kind tasks --note "final held by s-wait" 2>&1)
out1=$(printf '%s' "$winput" | STOP_GUARD_TURN="$(wait_turn "$pts")" bash "$HOOK")
tail -n 1 "$wws/stop-guard.jsonl" > "$TEST_ROOT/wait.last" 2>/dev/null
wsince=$(sed -n 's/^since=//p' "$wws/waiting/s-e2e" 2>/dev/null | head -n 1)
next=$(node -e 'process.stdout.write(new Date(Date.parse(process.argv[1]) + 1000).toISOString())' "$wsince")
out2=$(printf '%s' "$winput" | STOP_GUARD_TURN="$(wait_turn "$next")" bash "$HOOK")
printf '%s' "$out0" > "$TEST_ROOT/wait0.out"; printf '%s' "$out2" > "$TEST_ROOT/wait2.out"
if grep -q '"decision":"block"' "$TEST_ROOT/wait0.out" && [ "$wout" = "status=waiting kind=tasks" ] && [ -z "$out1" ] && grep -q '"session":"s-e2e","decision":"allow","reason":"waiting-record"' "$TEST_ROOT/wait.last"; then pass "main: refused before sdd-state wait, then the record it published allows as waiting-record in the plan log"; else fail "main: refused before sdd-state wait, then the record it published allows as waiting-record in the plan log ($out0 / $wout / $out1 / $(cat "$TEST_ROOT/wait.last"))"; fi
if grep -q '"decision":"block"' "$TEST_ROOT/wait2.out"; then pass "main: the next turn's prompt, after the record, is refused again"; else fail "main: the next turn's prompt, after the record, is refused again ($out2)"; fi

echo "=== stop guard: key parity ==="
# The module path travels in the environment: as argv[1] it would look like the
# main script to the module's CLI entry, which would read stdin and exit before
# the import callback ran (and block outright on a terminal).
nodekey=$(STOP_GUARD_MODULE="$REPO_ROOT/hooks/lib/stop-guard.mjs" node -e 'import(process.env.STOP_GUARD_MODULE).then(m=>process.stdout.write(m.cloneKey(process.argv[1])||""))' "$repo")
if [ -n "$key" ] && [ "$key" = "$nodekey" ]; then pass "cloneKey agrees with hp_key"; else fail "cloneKey agrees with hp_key ($key vs $nodekey)"; fi

echo ""
if [ "$FAILURES" -gt 0 ]; then echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
echo "STATUS: PASSED"
