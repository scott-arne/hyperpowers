#!/usr/bin/env bash
# The stop guard: the node unit matrix, then the bash wrapper's own behavior
# (registration, exit 0 everywhere, the hook-error line without node, the
# bash/node key parity) and the benchmark.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/sdd-stop-guard"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
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
if [ -x "$HOOK" ] && head -n 1 "$HOOK" | grep -q '^#!/usr/bin/env bash$'; then pass "the wrapper is an executable bash script"; else fail "the wrapper is an executable bash script"; fi

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
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"decision":"block"' && printf '%s' "$out" | grep -q 'SDD stop guard: plan docs/plan.md is not finished (1 of 1 tasks open; nothing tracked is live)'; then pass "a provable premature stop is refused through the wrapper"; else fail "a provable premature stop is refused through the wrapper (rc=$rc: $out)"; fi
if [ "$(grep -c '"decision":"block"' "$ws/stop-guard.jsonl")" = 1 ] && [ "$(grep -c '"decision":"block"' "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl")" = 1 ]; then pass "the decision is in the plan log and the mirror"; else fail "the decision is in the plan log and the mirror"; fi
# node absent from PATH: hook-error to the mirror, exit 0, nothing in the plan log
nopath="$TEST_ROOT/bin"; mkdir -p "$nopath"
for tool in bash git date mkdir dirname sed head; do ln -s "$(command -v "$tool")" "$nopath/$tool"; done
before=$(wc -l < "$ws/stop-guard.jsonl")
out=$(printf '%s' "$input" | PATH="$nopath" bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" | grep -q '"reason":"hook-error","detail":"node not found"' && [ "$(wc -l < "$ws/stop-guard.jsonl")" = "$before" ]; then pass "without node the wrapper allows and writes hook-error to the mirror"; else fail "without node the wrapper allows and writes hook-error to the mirror (rc=$rc: $out)"; fi
# the module throws: hook-error, exit 0
out=$(printf '%s' "$input" | STOP_GUARD_FAULT=throw bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" | grep -q '"reason":"hook-error","detail":"module exit 1"'; then pass "a module failure allows and writes hook-error"; else fail "a module failure allows and writes hook-error (rc=$rc: $out)"; fi
# the wrapper's line has the documented keys and a parsable timestamp
if tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" | node -e 'const l=JSON.parse(require("fs").readFileSync(0,"utf8"));if(l.session!=="s-wrap"||l.decision!=="allow"||isNaN(Date.parse(l.ts)))process.exit(1)'; then pass "the hook-error line is well-formed JSON with ts, session, decision, reason, detail"; else fail "the hook-error line is well-formed JSON"; fi
# malformed stdin, and a session id the mirror path must not take
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass "malformed input exits 0 silently"; else fail "malformed input exits 0 silently (rc=$rc: $out)"; fi
out=$(printf '{"session_id":"../../etc/x","cwd":"%s"}' "$repo" | STOP_GUARD_FAULT=throw bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/stop-guard/../../etc" ]; then pass "a session id with path characters writes nothing"; else fail "a session id with path characters writes nothing (rc=$rc)"; fi
# a cap refusal sequence through the real wrapper: the hook-error allows above reset the count, so block, block, allow
out1=$(printf '%s' "$input" | bash "$HOOK"); out2=$(printf '%s' "$input" | bash "$HOOK"); out3=$(printf '%s' "$input" | bash "$HOOK")
if printf '%s' "$out1" | grep -q '"decision":"block"' && printf '%s' "$out2" | grep -q '"decision":"block"' && [ -z "$out3" ] && tail -n 1 "$ws/stop-guard.jsonl" | grep -q '"reason":"cap"'; then pass "after an allow, the third consecutive attempt is allowed as cap through the wrapper"; else fail "after an allow, the third consecutive attempt is allowed as cap through the wrapper ($out1 / $out2 / $out3)"; fi

echo "=== stop guard: key parity ==="
# The module path travels in the environment: as argv[1] it would look like the
# main script to the module's CLI entry, which would read stdin and exit before
# the import callback ran (and block outright on a terminal).
nodekey=$(STOP_GUARD_MODULE="$REPO_ROOT/hooks/lib/stop-guard.mjs" node -e 'import(process.env.STOP_GUARD_MODULE).then(m=>process.stdout.write(m.cloneKey(process.argv[1])||""))' "$repo")
if [ -n "$key" ] && [ "$key" = "$nodekey" ]; then pass "cloneKey agrees with hp_key"; else fail "cloneKey agrees with hp_key ($key vs $nodekey)"; fi

echo ""
if [ "$FAILURES" -gt 0 ]; then echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
echo "STATUS: PASSED"
