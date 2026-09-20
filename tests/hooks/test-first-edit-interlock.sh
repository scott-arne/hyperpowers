#!/usr/bin/env bash
# Offline suite for hooks/first-edit-interlock and hooks/interlock-lib.cjs: the
# decision table, the wave rule, atomic publication, the mutation classifier's
# vector file, fail-open paths, and session-start's marker pruning. Every case
# runs the hook with env -i, a private HOME and XDG_CACHE_HOME, and a stdin file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/first-edit-interlock"
LIB="$REPO_ROOT/hooks/interlock-lib.cjs"
SESSION_START="$REPO_ROOT/hooks/session-start"
VECTORS="$SCRIPT_DIR/fixtures/mutation-cases.tsv"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# The message the hook must return, verbatim (the spec's text).
MESSAGE='Interlock, once before your first edit: run the ladder from the bootstrap. Rung 1 asks whether the change carries a consequence beyond the lines you touch: security posture, permissions, TLS or certificate checks, data loss or exposure, removing or disabling something that works, an interface others call. If it does: say the consequence to your human partner and stop; retry only after a reply that says yes. Nothing already in the request counts as that yes; "unused", "internal", and "just staging" are claims to confirm. If it does not: retry this call now; no question, no skill. Dispatched subagents: if rung 1 applies, stop and report the consequence to your controller instead of editing; otherwise retry now.'

new_case() { # -> prints a fresh case directory holding home/ and cache/
    # mktemp, not a counter: this runs inside $( ), where a counter would not
    # survive the subshell and every case would share one directory.
    local dir
    dir="$(mktemp -d "$TEST_ROOT/case.XXXXXX")"
    mkdir -p "$dir/home" "$dir/cache"
    printf '%s\n' "$dir"
}

write_transcript() { # <path> <message-id> [<second-message-id>]
    mkdir -p "$(dirname "$1")"
    printf '{"type":"user","uuid":"u1","message":{"role":"user","content":"do it"}}\n' > "$1"
    printf '{"type":"assistant","uuid":"a1","requestId":"req_1","message":{"id":"%s","role":"assistant","content":[{"type":"text","text":"ok"}]}}\n' "$2" >> "$1"
    printf '{"type":"assistant","uuid":"a2","requestId":"req_1","message":{"id":"%s","role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"Edit","input":{}}]}}\n' "$2" >> "$1"
    if [ "$#" -ge 3 ]; then
        printf '{"type":"user","uuid":"u2","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"denied"}]}}\n' >> "$1"
        printf '{"type":"assistant","uuid":"a3","requestId":"req_2","message":{"id":"%s","role":"assistant","content":[{"type":"tool_use","id":"toolu_2","name":"Edit","input":{}}]}}\n' "$3" >> "$1"
    fi
}

write_payload() { # <path> <session-id> <transcript-path> <tool-name> <tool-input-json> [<agent-id>]
    # A subagent's payload carries its CONTROLLER's transcript_path plus an
    # agent_id -- the only shape Claude Code produces (measured 2026-09-19 on
    # 2.1.276). Never synthesize a payload naming a subagent's own transcript:
    # such a vector passes while the real harness never produces that input.
    local extra=""
    if [ "$#" -ge 6 ] && [ -n "$6" ]; then
        extra="$(printf ',"agent_id":"%s","agent_type":"claude"' "$6")"
    fi
    printf '{"session_id":"%s","transcript_path":"%s","cwd":"/tmp","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s%s}' \
        "$2" "$3" "$4" "$5" "$extra" > "$1"
}

json_string() { # <text> -> a JSON string literal (for tool_input.command)
    printf '%s' "$1" | node -e 'process.stdout.write(JSON.stringify(require("fs").readFileSync(0, "utf8")))'
}

run_hook() { # <case-dir> <stdin-path> -> sets OUTPUT and RC
    set +e
    OUTPUT="$(env -i PATH="${PATH:-}" HOME="$1/home" XDG_CACHE_HOME="$1/cache" bash "$HOOK" < "$2" 2>"$1/stderr")"
    RC=$?
    set -e
}

assert_deny() { # <description>
    if [ "$RC" -ne 0 ]; then fail "$1 (hook exited $RC)"; return; fi
    if printf '%s' "$OUTPUT" | EXPECT_MESSAGE="$MESSAGE" node -e '
const input = require("fs").readFileSync(0, "utf8");
let p; try { p = JSON.parse(input); } catch (e) { console.error("invalid JSON: " + e.message); process.exit(1); }
const h = p.hookSpecificOutput;
if (!h || h.hookEventName !== "PreToolUse") { console.error("missing PreToolUse hookSpecificOutput"); process.exit(1); }
if (h.permissionDecision !== "deny") { console.error("decision " + h.permissionDecision); process.exit(1); }
if (h.permissionDecisionReason !== process.env.EXPECT_MESSAGE) { console.error("reason differs from the message"); process.exit(1); }
if (/[\x00-\x1f]/.test(h.permissionDecisionReason)) { console.error("raw control character in reason"); process.exit(1); }
' 2>"$TEST_ROOT/assert-err"; then
        pass "$1"
    else
        fail "$1 ($(cat "$TEST_ROOT/assert-err"))"
        printf '%s\n' "$OUTPUT" | sed 's/^/      /' | head -5
    fi
}

assert_allow() { # <description>
    if [ "$RC" -eq 0 ] && [ -z "$OUTPUT" ]; then pass "$1"; else fail "$1 (rc=$RC output=$(printf '%s' "$OUTPUT" | head -c 120))"; fi
}

marker_dir() { # <case-dir> <session-id> <agent>
    printf '%s' "$1/cache/hyperpowers/interlock/$2/$3"
}

echo "=== first-edit interlock ==="
echo ""

# --- 1. The first Edit is denied; the marker records the wave ---------------
c="$(new_case)"; t="$c/home/proj/sess-a.jsonl"; write_transcript "$t" "msg_one"
write_payload "$c/in" "sess-a" "$t" "Edit" '{"file_path":"/tmp/x","old_string":"a","new_string":"b"}'
run_hook "$c" "$c/in"
assert_deny "first Edit in a context is denied with the message"
if [ -f "$(marker_dir "$c" sess-a sess-a)/wave" ] && [ "$(cat "$(marker_dir "$c" sess-a sess-a)/wave")" = "msg_one" ]; then
    pass "the marker holds the last assistant message id"
else
    fail "the marker holds the last assistant message id"
fi

# --- 2. Same wave: denied again; later turn: allowed -------------------------
run_hook "$c" "$c/in"
assert_deny "a second attempt in the same wave is denied"
write_transcript "$t" "msg_one" "msg_two"
run_hook "$c" "$c/in"
assert_allow "an attempt in a later turn is allowed"
run_hook "$c" "$c/in"
assert_allow "and stays allowed"

# --- 3. A different session and a different agent are interlocked separately -
c="$(new_case)"; t="$c/home/proj/sess-b.jsonl"; write_transcript "$t" "msg_b"
write_payload "$c/in" "sess-b" "$t" "Write" '{"file_path":"/tmp/x","content":"hi"}'
run_hook "$c" "$c/in"; assert_deny "Write denies when unarmed"
# The controller's transcript is written once here and never rewritten: every
# subagent verdict below has to come from the subagent's own transcript.
sub="$c/home/proj/sess-b/subagents/agent-1234abcd.jsonl"; write_transcript "$sub" "msg_sub"
write_payload "$c/in2" "sess-b" "$t" "MultiEdit" '{"file_path":"/tmp/x","edits":[]}' "1234abcd"
run_hook "$c" "$c/in2"; assert_deny "a subagent context of the same session is denied at its own first attempt"
if [ -d "$(marker_dir "$c" sess-b sess-b)" ] && [ -d "$(marker_dir "$c" sess-b agent-1234abcd)" ]; then
    pass "two contexts of one session hold two markers"
else
    fail "two contexts of one session hold two markers"
fi
sub_wave="$(cat "$(marker_dir "$c" sess-b agent-1234abcd)/wave" 2>/dev/null || true)"
if [ "$sub_wave" = "msg_sub" ]; then
    pass "the subagent's wave is read from its own transcript, not the controller's"
else
    fail "the subagent's wave is read from its own transcript, not the controller's (got '$sub_wave')"
fi
run_hook "$c" "$c/in2"; assert_deny "a second subagent attempt in the same wave is denied"
write_transcript "$sub" "msg_sub" "msg_sub2"
run_hook "$c" "$c/in2"; assert_allow "the subagent's retry is allowed once its own transcript advances"
run_hook "$c" "$c/in"; assert_deny "the controller's own wave is unaffected by the subagent's state"
# The controller has moved on by the time it dispatches its second subagent.
# Under the refuted per-transcript model that alone waved the second subagent
# through: the shared marker's wave no longer matched, so nothing gated it.
write_transcript "$t" "msg_b" "msg_b2"
sub2="$c/home/proj/sess-b/subagents/agent-5678efab.jsonl"; write_transcript "$sub2" "msg_sub_b"
write_payload "$c/in3" "sess-b" "$t" "Write" '{"file_path":"/tmp/y","content":"hi"}' "5678efab"
run_hook "$c" "$c/in3"; assert_deny "a second subagent in the same session is interlocked at its own first attempt"
c="$(new_case)"; t="$c/home/proj/sess-c.jsonl"; write_transcript "$t" "msg_c"
write_payload "$c/in" "sess-c" "$t" "NotebookEdit" '{"notebook_path":"/tmp/n.ipynb","new_source":"x"}'
run_hook "$c" "$c/in"; assert_deny "NotebookEdit denies when unarmed"

# --- 3b. agent_id that names no transcript, and agent_id with a bad character -
c="$(new_case)"; t="$c/home/proj/sess-m.jsonl"; write_transcript "$t" "msg_m"
write_payload "$c/in" "sess-m" "$t" "Edit" '{}' "nosuchagent"
run_hook "$c" "$c/in"; assert_deny "a subagent whose transcript cannot be read is denied once"
if [ "$(cat "$(marker_dir "$c" sess-m agent-nosuchagent)/wave" 2>/dev/null || true)" = "unknown" ]; then
    pass "and records its wave as unknown"
else
    fail "and records its wave as unknown"
fi
run_hook "$c" "$c/in"; assert_allow "so that subagent is stopped once and never trapped"
write_payload "$c/in2" "sess-m" "$t" "Edit" '{}' "bad/id"
run_hook "$c" "$c/in2"; assert_allow "an agent_id outside A-Za-z0-9._- allows"
if [ "$(ls "$c/cache/hyperpowers/interlock/sess-m" | wc -l | tr -d ' ')" = "1" ]; then
    pass "and leaves no marker of its own"
else
    fail "and leaves no marker of its own ($(ls "$c/cache/hyperpowers/interlock/sess-m" | tr '\n' ' '))"
fi

# --- 4. Bash: the classifier decides; read-only calls leave no marker --------
c="$(new_case)"; t="$c/home/proj/sess-d.jsonl"; write_transcript "$t" "msg_d"
write_payload "$c/in" "sess-d" "$t" "Bash" "{\"command\":$(json_string 'git status && ls -la')}"
run_hook "$c" "$c/in"; assert_allow "a read-only Bash command is allowed"
if [ ! -d "$(marker_dir "$c" sess-d sess-d)" ]; then pass "a read-only call creates no marker"; else fail "a read-only call creates no marker"; fi
write_payload "$c/in" "sess-d" "$t" "Bash" "{\"command\":$(json_string 'rm -rf build')}"
run_hook "$c" "$c/in"; assert_deny "a destructive Bash command is the first attempt and is denied"
write_payload "$c/in" "sess-d" "$t" "Read" '{"file_path":"/tmp/x"}'
run_hook "$c" "$c/in"; assert_allow "a Read call is never an attempt"

# --- 5. Every vector: mutations deny when unarmed, read-only allow ----------
vec_n=0; vec_bad=0
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    expected="${line##*	}"
    command_text="${line%	*}"
    command_text="$(printf '%s' "$command_text" | node -e 'process.stdout.write(require("fs").readFileSync(0,"utf8").replace(/\\n/g, "\n"))')"
    vec_n=$((vec_n + 1))
    c="$(new_case)"; t="$c/home/proj/v.jsonl"; write_transcript "$t" "msg_v"
    write_payload "$c/in" "vec-$vec_n" "$t" "Bash" "{\"command\":$(json_string "$command_text")}"
    run_hook "$c" "$c/in"
    if [ "$expected" = "mutation" ]; then
        if [ "$RC" -ne 0 ] || ! printf '%s' "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then vec_bad=$((vec_bad + 1)); echo "    vector not denied: $command_text"; fi
    else
        if [ "$RC" -ne 0 ] || [ -n "$OUTPUT" ] || [ -d "$(marker_dir "$c" "vec-$vec_n" v)" ]; then vec_bad=$((vec_bad + 1)); echo "    vector not allowed cleanly: $command_text"; fi
    fi
done < "$VECTORS"
if [ "$vec_bad" -eq 0 ] && [ "$vec_n" -gt 100 ]; then pass "every vector ($vec_n) classifies through the hook as the file says"; else fail "vectors through the hook: $vec_bad of $vec_n wrong"; fi
if out="$(node "$LIB" --vectors "$VECTORS" 2>&1)" && printf '%s' "$out" | grep -q '^ok '; then pass "interlock-lib.cjs --vectors agrees ($out)"; else fail "interlock-lib.cjs --vectors: $out"; fi

# --- 6. Fail-open inputs -----------------------------------------------------
c="$(new_case)"; : > "$c/empty"
run_hook "$c" "$c/empty"; assert_allow "empty stdin allows"
printf 'not json' > "$c/bad"; run_hook "$c" "$c/bad"; assert_allow "non-JSON stdin allows"
t="$c/home/proj/s.jsonl"; write_transcript "$t" "m"
printf '{"transcript_path":"%s","tool_name":"Edit","tool_input":{}}' "$t" > "$c/nosid"; run_hook "$c" "$c/nosid"; assert_allow "a payload without session_id allows"
write_payload "$c/slash" "bad/id" "$t" "Edit" '{}'; run_hook "$c" "$c/slash"; assert_allow "a session_id with a slash allows"
write_payload "$c/notp" "sess-e" "" "Edit" '{}'; run_hook "$c" "$c/notp"; assert_allow "a payload without a transcript path allows"
if [ -z "$(ls -A "$c/cache" 2>/dev/null)" ]; then pass "fail-open paths create no state"; else fail "fail-open paths create no state"; fi

# --- 7. An unwritable cache root allows -------------------------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; write_transcript "$t" "m"
mkdir -p "$c/cache/hyperpowers/interlock"; chmod 500 "$c/cache/hyperpowers/interlock"
write_payload "$c/in" "sess-f" "$t" "Edit" '{}'
run_hook "$c" "$c/in"; assert_allow "an unwritable cache root allows"
chmod 700 "$c/cache/hyperpowers/interlock"

# --- 8. Transcript problems --------------------------------------------------
c="$(new_case)"; write_payload "$c/in" "sess-g" "$c/home/proj/missing.jsonl" "Edit" '{}'
run_hook "$c" "$c/in"; assert_deny "a first attempt with an unreadable transcript is still denied"
if [ "$(cat "$(marker_dir "$c" sess-g missing)/wave")" = "unknown" ]; then pass "and its wave is recorded as unknown"; else fail "and its wave is recorded as unknown"; fi
run_hook "$c" "$c/in"; assert_allow "a wave of unknown degrades to deny-once: the next attempt is allowed"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; write_transcript "$t" "m1"
write_payload "$c/in" "sess-h" "$t" "Edit" '{}'
run_hook "$c" "$c/in"; assert_deny "first attempt denied before the transcript disappears"
rm -f "$t"
run_hook "$c" "$c/in"; assert_allow "a transcript unreadable after a recorded wave allows"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; write_transcript "$t" "m1"
mkdir -p "$(marker_dir "$c" sess-i s)"
write_payload "$c/in" "sess-i" "$t" "Edit" '{}'
run_hook "$c" "$c/in"; assert_allow "a marker without wave (foreign or damaged) allows"

# --- 9. Concurrency: one wave, two callers; two contexts ----------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; write_transcript "$t" "m1"
write_payload "$c/in" "sess-j" "$t" "Edit" '{}'
( env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$HOOK" < "$c/in" > "$c/out1" 2>/dev/null ) &
p1=$!
( env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$HOOK" < "$c/in" > "$c/out2" 2>/dev/null ) &
p2=$!
wait "$p1" || true; wait "$p2" || true
if grep -q '"permissionDecision":"deny"' "$c/out1" && grep -q '"permissionDecision":"deny"' "$c/out2"; then pass "two concurrent first attempts are both denied"; else fail "two concurrent first attempts are both denied"; fi
if [ "$(ls -d "$c/cache/hyperpowers/interlock/sess-j"/* | wc -l | tr -d ' ')" = "1" ]; then pass "they leave one marker and no temporary directory"; else fail "they leave one marker and no temporary directory ($(ls "$c/cache/hyperpowers/interlock/sess-j"))"; fi
c="$(new_case)"; t1="$c/home/proj/s.jsonl"; t2="$c/home/proj/s/subagents/agent-x.jsonl"; write_transcript "$t1" "m1"; write_transcript "$t2" "m9"
# Both payloads name the same transcript_path; only agent_id separates them.
write_payload "$c/in1" "sess-k" "$t1" "Edit" '{}'; write_payload "$c/in2" "sess-k" "$t1" "Edit" '{}' "x"
( env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$HOOK" < "$c/in1" > "$c/out1" 2>/dev/null ) &
p1=$!
( env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$HOOK" < "$c/in2" > "$c/out2" 2>/dev/null ) &
p2=$!
wait "$p1" || true; wait "$p2" || true
if grep -q '"permissionDecision":"deny"' "$c/out1" && grep -q '"permissionDecision":"deny"' "$c/out2" && [ -d "$(marker_dir "$c" sess-k s)" ] && [ -d "$(marker_dir "$c" sess-k agent-x)" ]; then
    pass "concurrent first attempts from two contexts are both denied with two markers"
else
    fail "concurrent first attempts from two contexts are both denied with two markers"
fi

# --- 10. An abandoned initializer never blocks a context ---------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; write_transcript "$t" "m1"
mkdir -p "$c/cache/hyperpowers/interlock/sess-l/s.tmp.99999"; printf 'm0\n' > "$c/cache/hyperpowers/interlock/sess-l/s.tmp.99999/wave"
write_payload "$c/in" "sess-l" "$t" "Edit" '{}'
run_hook "$c" "$c/in"; assert_deny "after an abandoned initializer the next attempt publishes and is denied once"
write_transcript "$t" "m1" "m2"
run_hook "$c" "$c/in"; assert_allow "and a later-turn retry is allowed"

# --- 11. session-start prunes old state --------------------------------------
c="$(new_case)"; root="$c/cache/hyperpowers/interlock"
mkdir -p "$root/old-sess/agent-old" "$root/old-sess/agent-old.tmp.1" "$root/fresh-sess/agent-fresh" "$root/empty-sess"
printf 'm\n' > "$root/old-sess/agent-old/wave"; printf 'm\n' > "$root/fresh-sess/agent-fresh/wave"
touch -t 202601010000 "$root/old-sess/agent-old" "$root/old-sess/agent-old.tmp.1"
printf '{"session_id":"t","hook_event_name":"SessionStart","source":"startup"}' > "$c/ss-in"
env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$SESSION_START" < "$c/ss-in" > /dev/null 2>&1 || true
if [ ! -d "$root/old-sess/agent-old" ] && [ ! -d "$root/old-sess/agent-old.tmp.1" ] && [ ! -d "$root/old-sess" ]; then pass "session-start removes a marker older than three days, an old temporary directory, and the emptied session"; else fail "session-start removes old state ($(cd "$root" && find . | tr '\n' ' '))"; fi
if [ -d "$root/fresh-sess/agent-fresh" ] && [ ! -d "$root/empty-sess" ]; then pass "session-start keeps a fresh marker and drops an empty session directory"; else fail "session-start keeps a fresh marker and drops an empty session directory"; fi

# --- 12. The hook file keeps the rules its comments claim --------------------
if ! grep -Eq '(^|[^<])<<' "$HOOK" "$LIB"; then pass "the hook and its helper open no heredoc or here-string"; else fail "the hook and its helper open no heredoc or here-string"; fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi
echo "STATUS: PASSED"
