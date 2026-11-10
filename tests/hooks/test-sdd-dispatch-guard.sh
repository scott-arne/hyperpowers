#!/usr/bin/env bash
# The dispatch guard: the node unit matrix with its benchmark, then the bash
# wrapper's own behavior: the registration, both refusals through the wrapper
# and through run-hook.cmd, silence for a foreground or subagent call, and the
# hook-error line when node is missing or the module fails.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/sdd-dispatch-guard"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
FAILURES=0
# Fail closed: an empty TEST_ROOT would aim every later write at the filesystem
# root, and under bash 3.2 `cd ""` succeeds and the EXIT trap would delete the
# current directory.
TEST_ROOT=$(mktemp -d) || { echo "cannot create a temporary directory" >&2; exit 1; }
[ -n "$TEST_ROOT" ] || { echo "mktemp returned an empty path" >&2; exit 1; }
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || { echo "cannot resolve the temporary directory" >&2; exit 1; }
[ -n "$TEST_ROOT" ] || { echo "the resolved temporary directory is empty" >&2; exit 1; }
trap 'rm -rf "$TEST_ROOT"' EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "=== dispatch guard: unit matrix ==="
if DISPATCH_GUARD_BENCH=1 node --test "$REPO_ROOT/hooks/lib/dispatch-guard.test.mjs" > "$TEST_ROOT/node.log" 2>&1; then pass "node --test hooks/lib/dispatch-guard.test.mjs"; else fail "node --test hooks/lib/dispatch-guard.test.mjs"; tail -n 40 "$TEST_ROOT/node.log"; fi
grep -E '^# bench' "$TEST_ROOT/node.log" || true

echo "=== dispatch guard: registration ==="
if node -e 'const h=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).hooks.PreToolUse;if(!Array.isArray(h)||h.length!==1||h[0].matcher!=="Agent|SendMessage")process.exit(1);const c=h[0].hooks;if(!Array.isArray(c)||c.length!==1||c[0].type!=="command"||!c[0].command.includes("run-hook.cmd\" sdd-dispatch-guard")||c[0].timeout!==10||c[0].shell!=="bash")process.exit(1)' "$REPO_ROOT/hooks/hooks.json"; then pass "hooks.json registers PreToolUse Agent|SendMessage -> run-hook.cmd sdd-dispatch-guard with a 10 s timeout"; else fail "hooks.json registers PreToolUse Agent|SendMessage -> run-hook.cmd sdd-dispatch-guard with a 10 s timeout"; fi
if grep -q '"PreToolUse"\|sdd-dispatch-guard' "$REPO_ROOT/hooks/hooks-codex.json" "$REPO_ROOT/hooks/hooks-cursor.json" 2>/dev/null; then fail "the Codex and Cursor hook files do not register the guard"; else pass "the Codex and Cursor hook files do not register the guard"; fi
head -n 1 "$HOOK" > "$TEST_ROOT/shebang" 2>/dev/null
if [ -x "$HOOK" ] && grep -q '^#!/usr/bin/env bash$' "$TEST_ROOT/shebang"; then pass "the wrapper is an executable bash script"; else fail "the wrapper is an executable bash script"; fi

echo "=== dispatch guard: wrapper ==="
export XDG_CACHE_HOME="$TEST_ROOT/cache"
repo="$TEST_ROOT/repo"; git init -q -b main "$repo"; git -C "$repo" config user.name t; git -C "$repo" config user.email t@example.com
mkdir -p "$repo/docs"; printf '# Plan\n\n### Task 1: one\n' > "$repo/docs/plan.md"; git -C "$repo" add docs/plan.md; git -C "$repo" commit -q -m plan
key=$(bash -c '. "$1"; hp_key "$2"' _ "$LIB" "$repo")
ws="$XDG_CACHE_HOME/hyperpowers/state/$key/plans/plan-00000000"
printf '%s\n' '{"type":"assistant","timestamp":"2026-11-10T10:00:01.000Z","isSidechain":false,"message":{"role":"assistant","content":[{"type":"tool_use","id":"tu1","name":"Agent","input":{"description":"Implement Task 1","prompt":"brief","run_in_background":false}}]}}' '{"type":"user","timestamp":"2026-11-10T10:00:02.000Z","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu1","content":[{"type":"text","text":"done"}]}]},"toolUseResult":{"status":"completed","agentId":"a1"}}' > "$TEST_ROOT/t.jsonl"
# payload <tool> <tool_input JSON> [<extra fields, each with a leading comma>]
payload() { printf '{"session_id":"s-wrap","transcript_path":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s,"tool_use_id":"toolu_w"%s}' "$TEST_ROOT/t.jsonl" "$repo" "$1" "$2" "${3:-}"; }
LOG="$XDG_CACHE_HOME/hyperpowers/dispatch-guard/s-wrap.jsonl"
out=$(payload Agent '{"prompt":"p","run_in_background":false}' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/dispatch-guard" ]; then pass "a foreground Agent call: exit 0, no output, nothing written"; else fail "a foreground Agent call: exit 0, no output, nothing written (rc=$rc: $out)"; fi
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"no-plan"' "$LOG"; then pass "a background Agent call with no plan passes, logged as no-plan"; else fail "a background Agent call with no plan passes, logged as no-plan (rc=$rc: $out)"; fi
mkdir -p "$ws"; printf '# SDD ledger — plan: docs/plan.md\nsession s-wrap: mode worktree on main at %s started x\n' "$repo" > "$ws/progress.md"
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | bash "$HOOK"); rc=$?
printf '%s' "$out" > "$TEST_ROOT/bg.out"
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/bg.out" && grep -q 'SDD plan docs/plan.md is in progress in this session. On this harness every subagent is dispatched in the foreground' "$TEST_ROOT/bg.out"; then pass "a background Agent call is refused through the wrapper"; else fail "a background Agent call is refused through the wrapper (rc=$rc: $out)"; fi
out=$(payload SendMessage '{"to":"a1","message":"fix it"}' | bash "$REPO_ROOT/hooks/run-hook.cmd" sdd-dispatch-guard); rc=$?
printf '%s' "$out" > "$TEST_ROOT/sm.out"
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/sm.out" && grep -q 'On this harness a SendMessage resume runs in the background' "$TEST_ROOT/sm.out"; then pass "a SendMessage to the session's own subagent is refused through run-hook.cmd"; else fail "a SendMessage to the session's own subagent is refused through run-hook.cmd (rc=$rc: $out)"; fi
if node -e 'const ls=require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").map(JSON.parse).filter(l=>l.decision==="deny");if(ls.length!==2||ls[0].reason!=="background-agent"||ls[1].reason!=="sendmessage-resume"||ls.some(l=>l.tool_use_id!=="toolu_w"||l.plan!=="docs/plan.md"))process.exit(1)' "$LOG"; then pass "both refusals are in the session log with tool_use_id and plan"; else fail "both refusals are in the session log with tool_use_id and plan"; fi
before=$(wc -l < "$LOG")
out=$(payload SendMessage '{"to":"a1","message":"m"}' ',"agent_id":"a9"' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ "$(wc -l < "$LOG")" = "$before" ]; then pass "a subagent's call is silent and unlogged"; else fail "a subagent's call is silent and unlogged (rc=$rc: $out)"; fi
# node absent from PATH: hook-error in the log, exit 0, no output
nopath="$TEST_ROOT/bin"; mkdir -p "$nopath"
for tool in bash date mkdir dirname sed head; do ln -s "$(command -v "$tool")" "$nopath/$tool"; done
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | PATH="$nopath" bash "$HOOK"); rc=$?
tail -n 1 "$LOG" > "$TEST_ROOT/log.last" 2>/dev/null
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"hook-error","detail":"node not found"' "$TEST_ROOT/log.last"; then pass "without node the call passes and hook-error is logged"; else fail "without node the call passes and hook-error is logged (rc=$rc: $out)"; fi
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | DISPATCH_GUARD_FAULT=throw bash "$HOOK"); rc=$?
tail -n 1 "$LOG" > "$TEST_ROOT/log.last" 2>/dev/null
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"hook-error","detail":"module exit 1"' "$TEST_ROOT/log.last"; then pass "a module failure passes and logs hook-error"; else fail "a module failure passes and logs hook-error (rc=$rc: $out)"; fi
if node -e 'const l=JSON.parse(require("fs").readFileSync(0,"utf8"));if(l.session!=="s-wrap"||l.decision!=="allow"||isNaN(Date.parse(l.ts)))process.exit(1)' < "$TEST_ROOT/log.last"; then pass "the hook-error line is well-formed JSON"; else fail "the hook-error line is well-formed JSON"; fi
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass "malformed input exits 0 silently"; else fail "malformed input exits 0 silently (rc=$rc: $out)"; fi
# A session id with path characters, node absent so the bash fallback composes
# the path: the cache tree before and after must be identical.
snapshot() { ( cd "$XDG_CACHE_HOME" && find . -print | sort | while IFS= read -r f; do if [ -f "$f" ]; then printf '%s %s\n' "$(wc -c < "$f")" "$f"; else printf 'dir %s\n' "$f"; fi; done ); }
snapshot > "$TEST_ROOT/cache.before"
rc=0; out=""
for sid in '../../etc/x' '../escaped'; do
  o=$(printf '{"session_id":"%s","cwd":"%s","tool_name":"Agent","tool_input":{"run_in_background":true}}' "$sid" "$repo" | PATH="$nopath" bash "$HOOK"); r=$?
  [ "$r" -eq 0 ] || rc=$r
  out="$out$o"
done
snapshot > "$TEST_ROOT/cache.after"
if [ "$rc" -eq 0 ] && [ -z "$out" ] && cmp -s "$TEST_ROOT/cache.before" "$TEST_ROOT/cache.after"; then pass "a session id with path characters writes nothing"; else fail "a session id with path characters writes nothing (rc=$rc)"; fi
ln -s "$REPO_ROOT/hooks" "$TEST_ROOT/hooks-link"
payload Agent '{"prompt":"p","run_in_background":true}' | bash "$TEST_ROOT/hooks-link/sdd-dispatch-guard" > "$TEST_ROOT/symlink.out" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/symlink.out"; then pass "the guard still refuses when the hooks directory is reached through a symlink"; else fail "the guard still refuses when the hooks directory is reached through a symlink (rc=$rc)"; fi
odd="$TEST_ROOT/plug#in %root"; mkdir -p "$odd"; cp -R "$REPO_ROOT/hooks" "$odd/hooks"
payload Agent '{"prompt":"p","run_in_background":true}' | bash "$odd/hooks/sdd-dispatch-guard" > "$TEST_ROOT/oddpath.out" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/oddpath.out"; then pass "the guard still refuses from a plugin root whose path carries # and %"; else fail "the guard still refuses from a plugin root whose path carries # and % (rc=$rc)"; fi
if cat "$TEST_ROOT"/*.out | grep -q '"permissionDecision":"allow"'; then fail "no output in this suite carries an allow"; else pass "no output in this suite carries an allow"; fi

# The inner run must stop before any check runs. A shim stands in for mktemp
# because macOS mktemp falls back to its own directory when TMPDIR is unusable.
# DISPATCH_GUARD_NO_MKTEMP_CHECK keeps a broken guard from recursing.
if [ -z "${DISPATCH_GUARD_NO_MKTEMP_CHECK:-}" ]; then
  mkdir -p "$TEST_ROOT/failing-mktemp"
  printf '#!/bin/sh\nexit 1\n' > "$TEST_ROOT/failing-mktemp/mktemp"; chmod +x "$TEST_ROOT/failing-mktemp/mktemp"
  DISPATCH_GUARD_NO_MKTEMP_CHECK=1 PATH="$TEST_ROOT/failing-mktemp:$PATH" bash "$0" > "$TEST_ROOT/mktemp-fail.out" 2>&1; rc=$?
  if [ "$rc" -ne 0 ] && ! grep -q '\[PASS\]' "$TEST_ROOT/mktemp-fail.out"; then pass "the suite exits before any check when mktemp fails"; else fail "the suite exits before any check when mktemp fails (rc=$rc)"; fi
fi

echo ""
if [ "$FAILURES" -gt 0 ]; then echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
echo "STATUS: PASSED"
