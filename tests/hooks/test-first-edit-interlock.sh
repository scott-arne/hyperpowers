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
# The substring the delivered-denial recovery matches. Quote-free on purpose:
# these fixtures embed it in JSON with printf.
OPENING='Interlock, once before your first edit: run the ladder from the bootstrap.'

new_case() { # -> prints a fresh case directory holding home/ and cache/
    # mktemp, not a counter: this runs inside $( ), where a counter would not
    # survive the subshell and every case would share one directory.
    local dir
    dir="$(mktemp -d "$TEST_ROOT/case.XXXXXX")"
    mkdir -p "$dir/home" "$dir/cache"
    printf '%s\n' "$dir"
}

start_transcript() { # <path>
    mkdir -p "$(dirname "$1")"
    printf '{"type":"user","uuid":"u1","message":{"role":"user","content":"go"}}\n' > "$1"
}

append_call() { # <path> <uuid> <message-id-or-empty> <request-id-or-empty> <tool-use-id>
    # One content block of an assistant turn. Claude Code writes a record per
    # block as the turn streams, so the sibling of a denied call shares its
    # message.id and requestId and differs only in uuid. That is why the turn
    # identifier may never be the uuid.
    mkdir -p "$(dirname "$1")"
    local idpart="" reqpart=""
    if [ -n "$3" ]; then idpart="$(printf '"id":"%s",' "$3")"; fi
    if [ -n "$4" ]; then reqpart="$(printf ',"requestId":"%s"' "$4")"; fi
    printf '{"type":"assistant","uuid":"%s"%s,"message":{%s"role":"assistant","content":[{"type":"tool_use","id":"%s","name":"Edit","input":{}}]}}\n' \
        "$2" "$reqpart" "$idpart" "$5" >> "$1"
}

append_text() { # <path> <uuid> <message-id-or-empty> <request-id-or-empty> <text>
    mkdir -p "$(dirname "$1")"
    local idpart="" reqpart=""
    if [ -n "$3" ]; then idpart="$(printf '"id":"%s",' "$3")"; fi
    if [ -n "$4" ]; then reqpart="$(printf ',"requestId":"%s"' "$4")"; fi
    printf '{"type":"assistant","uuid":"%s"%s,"message":{%s"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' \
        "$2" "$reqpart" "$idpart" "$5" >> "$1"
}

append_result() { # <path> <tool-use-id> <text>
    printf '{"type":"user","uuid":"r-%s","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"%s","content":"%s"}]}}\n' \
        "$2" "$2" "$3" >> "$1"
}

blob() { # <bytes> -> that many x characters, for the read-window vectors
    head -c "$1" /dev/zero | tr '\0' 'x'
}

write_payload() { # <path> <session-id> <transcript-path> <tool-name> <tool-input-json> <tool-use-id-or-empty> [<agent-id>]
    # A subagent's payload carries its CONTROLLER's transcript_path plus an
    # agent_id -- the only shape Claude Code produces (measured 2026-09-19 on
    # 2.1.276). Never synthesize a payload naming a subagent's own transcript:
    # such a vector passes while the real harness never produces that input.
    local extra=""
    if [ -n "$6" ]; then extra="$(printf ',"tool_use_id":"%s"' "$6")"; fi
    if [ "$#" -ge 7 ] && [ -n "$7" ]; then
        extra="${extra}$(printf ',"agent_id":"%s","agent_type":"claude"' "$7")"
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

now_ms() { node -e 'process.stdout.write(String(Date.now()))'; }

echo "=== first-edit interlock ==="
echo ""

# --- 1. The first Edit is denied; the marker records the denied call ---------
c="$(new_case)"; t="$c/home/proj/sess-a.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
write_payload "$c/in" "sess-a" "$t" "Edit" '{"file_path":"/tmp/x","old_string":"a","new_string":"b"}' "toolu_1"
run_hook "$c" "$c/in"
assert_deny "first Edit in a context is denied with the message"
if [ "$(cat "$(marker_dir "$c" sess-a sess-a)/call" 2>/dev/null || true)" = "toolu_1" ]; then
    pass "the marker holds the denied call's tool_use_id"
else
    fail "the marker holds the denied call's tool_use_id (got '$(cat "$(marker_dir "$c" sess-a sess-a)/call" 2>/dev/null || true)')"
fi

# --- 2. The sibling vector, which the 2026-09-20 campaign proved the ---------
# pre-amendment hook got wrong. Both records are in the fixture before either
# verdict is taken, so neither verdict depends on when a record was written.
append_call "$t" a2 msg_one req_1 toolu_sib
append_result "$t" toolu_1 "denied"
append_call "$t" a3 msg_two req_2 toolu_later
write_payload "$c/in2" "sess-a" "$t" "Edit" '{}' "toolu_sib"
run_hook "$c" "$c/in2"; assert_deny "a sibling of the denied call, in the same assistant turn, is denied"
write_payload "$c/in3" "sess-a" "$t" "Edit" '{}' "toolu_later"
run_hook "$c" "$c/in3"; assert_allow "a call in a later assistant turn is allowed"
run_hook "$c" "$c/in3"; assert_allow "and stays allowed"

# --- 3. The step-8 fallback: this call's own id is nowhere in the file -------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
write_payload "$c/in" "sess-fb" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
write_payload "$c/in2" "sess-fb" "$t" "Edit" '{}' "toolu_missing"
run_hook "$c" "$c/in2"; assert_deny "a call whose own record is nowhere denies while the denied turn is still last"
append_call "$t" a2 msg_two req_2 toolu_other
run_hook "$c" "$c/in2"; assert_allow "and allows once a later assistant record is appended"

# --- 4. The step-7 poll on the calling side ----------------------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
write_payload "$c/in" "sess-p1" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
append_call "$t" a2 msg_two req_2 toolu_other
# Absent: step 7 polls its whole budget, then step 8 reads a later turn.
write_payload "$c/in2" "sess-p1" "$t" "Edit" '{}' "toolu_absent"
start_ms="$(now_ms)"; run_hook "$c" "$c/in2"; absent_ms="$(( $(now_ms) - start_ms ))"
assert_allow "a call whose own record never lands falls through to step 8 and allows on a later turn"
# Present: the same work with no polling. The two paths run the same number of
# node invocations, so the difference between them is the poll and nothing else.
write_payload "$c/in3" "sess-p1" "$t" "Edit" '{}' "toolu_other"
start_ms="$(now_ms)"; run_hook "$c" "$c/in3"; present_ms="$(( $(now_ms) - start_ms ))"
assert_allow "a call whose own record is already present allows"
if [ "$((present_ms + 200))" -lt "$absent_ms" ]; then
    pass "and does not poll when the record is present (${present_ms} ms against ${absent_ms} ms)"
else
    fail "step 7 polled with the record present (${present_ms} ms against ${absent_ms} ms)"
fi
if [ "$absent_ms" -lt 2000 ]; then pass "the polling path still returns inside its budget (${absent_ms} ms)"; else fail "the polling path did not return inside its budget (${absent_ms} ms)"; fi
# A record that lands partway through the poll is seen without waiting it out.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
write_payload "$c/in" "sess-p1b" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
write_payload "$c/in2" "sess-p1b" "$t" "Edit" '{}' "toolu_late"
( sleep 0.15; append_call "$t" a2 msg_two req_2 toolu_late ) &
writer=$!
run_hook "$c" "$c/in2"
wait "$writer" || true
assert_allow "a record that lands 150 ms into the poll, in a later turn, allows"
# The poll budget is an argument, and 0 makes the lookup a single read. The live
# probe needs to ask whether a record was on disk at one moment; the polling
# default answers a different question, "did it arrive within 400 ms".
start_ms="$(now_ms)"; zero_out="$(node "$LIB" --resolve "$t" toolu_nowhere 0)"; zero_ms="$(( $(now_ms) - start_ms ))"
if [ "$zero_out" = "absent" ]; then pass "a zero budget reports an absent record instead of waiting for it"; else fail "a zero budget printed '$zero_out'"; fi
start_ms="$(now_ms)"; deflt_out="$(node "$LIB" --resolve "$t" toolu_nowhere)"; deflt_ms="$(( $(now_ms) - start_ms ))"
if [ "$deflt_out" = "absent" ]; then pass "the default budget reports the same absent record"; else fail "the default budget printed '$deflt_out'"; fi
start_ms="$(now_ms)"; bogus_out="$(node "$LIB" --resolve "$t" toolu_nowhere zzz)"; bogus_ms="$(( $(now_ms) - start_ms ))"
if [ "$bogus_out" = "absent" ]; then pass "a budget that is not a number reports the same absent record"; else fail "a non-numeric budget printed '$bogus_out'"; fi
if [ "$(node "$LIB" --resolve "$t" toolu_1 0)" = "$(printf 'id\tmsg_one')" ]; then pass "a zero budget still resolves a record that is already present"; else fail "a zero budget did not resolve a present record"; fi
if [ "$((zero_ms + 200))" -lt "$deflt_ms" ]; then
    pass "and the zero budget does not poll (${zero_ms} ms against the default's ${deflt_ms} ms)"
else
    fail "the zero budget polled (${zero_ms} ms against the default's ${deflt_ms} ms)"
fi
if [ "$((zero_ms + 200))" -lt "$bogus_ms" ]; then
    pass "a budget that is not a number falls back to the default rather than to no poll (${bogus_ms} ms)"
else
    fail "a non-numeric budget skipped the poll (${bogus_ms} ms against the zero budget's ${zero_ms} ms)"
fi

# --- 4b. The probe trace ------------------------------------------------------
# Two things have to hold: the trace says what the library's reads actually saw,
# and it changes nothing on stdout. The live probe runs the real hook, so a
# trace that altered the library's answer would alter the behaviour measured.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
trc="$c/trace"; : > "$trc"
untraced="$(node "$LIB" --resolve "$t" toolu_1 0)"
traced="$(INTERLOCK_PROBE_TRACE="$trc" node "$LIB" --resolve "$t" toolu_1 0)"
if [ "$traced" = "$untraced" ]; then pass "the trace leaves --resolve's stdout byte-identical"; else fail "tracing changed --resolve's stdout from '$untraced' to '$traced'"; fi
if [ "$(cat "$trc")" = "$(printf 'resolve\ttoolu_1\treads=1\tfirst=present\tresult=present')" ]; then pass "a present record traces one read that saw it"; else fail "the present trace was '$(cat "$trc")'"; fi
: > "$trc"; INTERLOCK_PROBE_TRACE="$trc" node "$LIB" --resolve "$t" toolu_nowhere 0 >/dev/null
if [ "$(cat "$trc")" = "$(printf 'resolve\ttoolu_nowhere\treads=1\tfirst=absent\tresult=absent')" ]; then pass "a zero-budget absent record traces one read"; else fail "the zero-budget absent trace was '$(cat "$trc")'"; fi
: > "$trc"; INTERLOCK_PROBE_TRACE="$trc" node "$LIB" --resolve "$t" toolu_nowhere >/dev/null
polled_reads="$(cut -f3 < "$trc")"
if [ "$(cut -f4 < "$trc")" = "first=absent" ] && [ "$polled_reads" != "reads=1" ]; then pass "a polled absent record traces first=absent and more than one read (${polled_reads})"; else fail "the polled absent trace was '$(cat "$trc")'"; fi
# first= is the field that makes the probe honest: a record the poll eventually
# found was still missing at the moment the hook reached step 7, and only the
# library itself can say so.
( sleep 0.15; append_call "$t" a3 msg_three req_3 toolu_slow ) &
writer=$!
: > "$trc"; slow_out="$(INTERLOCK_PROBE_TRACE="$trc" node "$LIB" --resolve "$t" toolu_slow)"
wait "$writer" || true
if [ "$slow_out" = "$(printf 'id\tmsg_three')" ] && [ "$(cut -f4 < "$trc")" = "first=absent" ] && [ "$(cut -f5 < "$trc")" = "result=present" ]; then pass "a record that lands mid-poll traces first=absent result=present"; else fail "the mid-poll trace was '$(cat "$trc")' for output '$slow_out'"; fi
: > "$trc"; INTERLOCK_PROBE_TRACE="$trc" node "$LIB" --last "$t" >/dev/null
if [ "$(cat "$trc")" = "$(printf 'last\tresult=id')" ]; then pass "--last traces the step-8 fallback, which is how the probe counts it"; else fail "the --last trace was '$(cat "$trc")'"; fi
: > "$trc"; node "$LIB" --resolve "$t" toolu_1 0 >/dev/null; node "$LIB" --last "$t" >/dev/null
if [ ! -s "$trc" ]; then pass "an unset INTERLOCK_PROBE_TRACE writes no trace at all"; else fail "the library traced without being asked: '$(cat "$trc")'"; fi

# --- 5. The step-6 poll: the denied call's own record lands late -------------
# The loser of a concurrent first wave reads the marker before either record is
# on disk. It must deny, and it must still deny when the records arrive.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-p2" "$t" "Edit" '{}' "toolu_win"
run_hook "$c" "$c/in"; assert_deny "the winner of a concurrent wave is denied with no record on disk"
write_payload "$c/in2" "sess-p2" "$t" "Edit" '{}' "toolu_lose"
( sleep 0.15; append_call "$t" a1 msg_one req_1 toolu_win; append_call "$t" a2 msg_one req_1 toolu_lose ) &
writer=$!
run_hook "$c" "$c/in2"
wait "$writer" || true
assert_deny "the loser denies when both records land 150 ms into the step-6 poll"

# --- 6. The denied call's record names no turn: deny-once --------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 "" "" toolu_1
write_payload "$c/in" "sess-n1" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "a first attempt whose record names no turn is denied"
append_call "$t" a2 "" "" toolu_sib
write_payload "$c/in2" "sess-n1" "$t" "Edit" '{}' "toolu_sib"
run_hook "$c" "$c/in2"; assert_allow "its same-turn sibling is allowed -- deny-once, not a context held on a comparison the hook cannot make"
run_hook "$c" "$c/in"; assert_allow "and the denied call's own retry is allowed too"

# --- 6b. A record identified by requestId alone ------------------------------
# turnIdOf reads message.id and falls back to requestId, and a record can carry
# the second without the first. The fallback is load-bearing: without it such a
# record resolves to no turn at all, step 6 answers noid, and every sibling of
# the denied call runs.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 "" req_1 toolu_1
write_payload "$c/in" "sess-req" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "a first attempt whose record carries a requestId and no message.id is denied"
append_call "$t" a2 "" req_1 toolu_sib
write_payload "$c/in2" "sess-req" "$t" "Edit" '{}' "toolu_sib"
run_hook "$c" "$c/in2"; assert_deny "its same-turn sibling, identified by requestId alone, is denied"
append_call "$t" a3 "" req_2 toolu_later
write_payload "$c/in3" "sess-req" "$t" "Edit" '{}' "toolu_later"
run_hook "$c" "$c/in3"; assert_allow "a later turn, identified by requestId alone, is allowed"
if [ "$(node "$LIB" --resolve "$t" toolu_1 0)" = "$(printf 'id\treq_1')" ]; then pass "--resolve names that turn by its requestId"; else fail "--resolve named the requestId-only turn '$(node "$LIB" --resolve "$t" toolu_1 0)'"; fi

# --- 7. The wave resolves but this call's own record names no turn -----------
# Step 8 must skip that record and read the last one that does carry an
# identifier. Reading the trailing record as a different turn would allow a
# same-turn sibling, which is the whole point of the wave rule.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
write_payload "$c/in" "sess-n2" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
append_call "$t" a2 "" "" toolu_sib
write_payload "$c/in2" "sess-n2" "$t" "Edit" '{}' "toolu_sib"
run_hook "$c" "$c/in2"; assert_deny "a later call whose own record names no turn, and is last, is denied"
append_call "$t" a3 msg_two req_2 toolu_next
run_hook "$c" "$c/in2"; assert_allow "and is allowed once a later record carrying an identifier is appended"

# --- 7b. The wave resolves and THIS call carries no tool_use_id of its own ---
# The other half of step 7's fallthrough. Section 7 covers a call whose own
# record names no turn; here the payload names no call at all, so there is
# nothing to resolve and step 8 has to place it. Allowing such a call outright
# would release a mutation from inside the denied wave, and the marker here
# holds a resolvable call, so the wave is known.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
write_payload "$c/in" "sess-own" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
if [ "$(cat "$(marker_dir "$c" sess-own s)/call" 2>/dev/null || true)" = "toolu_1" ]; then pass "the marker holds a resolvable call"; else fail "the marker holds a resolvable call (got '$(cat "$(marker_dir "$c" sess-own s)/call" 2>/dev/null || true)')"; fi
write_payload "$c/in2" "sess-own" "$t" "Edit" '{}' ""
run_hook "$c" "$c/in2"; assert_deny "a payload carrying no tool_use_id is denied while the denied turn is still the last one"
append_call "$t" a2 msg_two req_2 toolu_other
run_hook "$c" "$c/in2"; assert_allow "and is allowed once a later assistant record is appended"

# --- 8. Degraded markers all allow -------------------------------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
mkdir -p "$(marker_dir "$c" sess-d1 s)"
write_payload "$c/in" "sess-d1" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_allow "a marker directory with no call file allows"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
mkdir -p "$(marker_dir "$c" sess-d2 s)"; printf 'unknown\n' > "$(marker_dir "$c" sess-d2 s)/call"
write_payload "$c/in" "sess-d2" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_allow "a marker whose call is unknown allows"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
mkdir -p "$(marker_dir "$c" sess-d3 s)"; printf 'm1\n' > "$(marker_dir "$c" sess-d3 s)/wave"
write_payload "$c/in" "sess-d3" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_allow "a pre-amendment marker (a wave file and no call) allows"

# --- 9. A payload carrying no tool_use_id ------------------------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
write_payload "$c/in" "sess-noid" "$t" "Edit" '{}' ""
run_hook "$c" "$c/in"; assert_deny "a payload with no tool_use_id is denied at its first attempt"
if [ "$(cat "$(marker_dir "$c" sess-noid s)/call" 2>/dev/null || true)" = "unknown" ]; then
    pass "and records its call as unknown"
else
    fail "and records its call as unknown (got '$(cat "$(marker_dir "$c" sess-noid s)/call" 2>/dev/null || true)')"
fi
run_hook "$c" "$c/in"; assert_allow "so that context is stopped once and never trapped"

# --- 10. The other mutating tools --------------------------------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-w" "$t" "Write" '{"file_path":"/tmp/x","content":"hi"}' "toolu_w"
run_hook "$c" "$c/in"; assert_deny "Write denies when unarmed"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-me" "$t" "MultiEdit" '{"file_path":"/tmp/x","edits":[]}' "toolu_m"
run_hook "$c" "$c/in"; assert_deny "MultiEdit denies when unarmed"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-ne" "$t" "NotebookEdit" '{"notebook_path":"/tmp/n.ipynb","new_source":"x"}' "toolu_n"
run_hook "$c" "$c/in"; assert_deny "NotebookEdit denies when unarmed"

# --- 11. Bash: the classifier decides; read-only calls leave no marker -------
c="$(new_case)"; t="$c/home/proj/sess-d.jsonl"; start_transcript "$t"; append_call "$t" a1 msg_d req_d toolu_1
write_payload "$c/in" "sess-d" "$t" "Bash" "{\"command\":$(json_string 'git status && ls -la')}" "toolu_r"
run_hook "$c" "$c/in"; assert_allow "a read-only Bash command is allowed"
if [ ! -d "$(marker_dir "$c" sess-d sess-d)" ]; then pass "a read-only call creates no marker"; else fail "a read-only call creates no marker"; fi
write_payload "$c/in" "sess-d" "$t" "Bash" "{\"command\":$(json_string 'rm -rf build')}" "toolu_1"
run_hook "$c" "$c/in"; assert_deny "a destructive Bash command is the first attempt and is denied"
write_payload "$c/in" "sess-d" "$t" "Read" '{"file_path":"/tmp/x"}' "toolu_read"
run_hook "$c" "$c/in"; assert_allow "a Read call is never an attempt"

# --- 12. Every vector: mutations deny when unarmed, read-only allow ----------
vec_n=0; vec_bad=0
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    expected="${line##*	}"
    command_text="${line%	*}"
    command_text="$(printf '%s' "$command_text" | node -e 'process.stdout.write(require("fs").readFileSync(0,"utf8").replace(/\\n/g, "\n"))')"
    vec_n=$((vec_n + 1))
    c="$(new_case)"; t="$c/home/proj/v.jsonl"; start_transcript "$t"
    write_payload "$c/in" "vec-$vec_n" "$t" "Bash" "{\"command\":$(json_string "$command_text")}" "toolu_v"
    run_hook "$c" "$c/in"
    if [ "$expected" = "mutation" ]; then
        if [ "$RC" -ne 0 ] || ! printf '%s' "$OUTPUT" | grep -q '"permissionDecision":"deny"'; then vec_bad=$((vec_bad + 1)); echo "    vector not denied: $command_text"; fi
    else
        if [ "$RC" -ne 0 ] || [ -n "$OUTPUT" ] || [ -d "$(marker_dir "$c" "vec-$vec_n" v)" ]; then vec_bad=$((vec_bad + 1)); echo "    vector not allowed cleanly: $command_text"; fi
    fi
done < "$VECTORS"
if [ "$vec_bad" -eq 0 ] && [ "$vec_n" -gt 100 ]; then pass "every vector ($vec_n) classifies through the hook as the file says"; else fail "vectors through the hook: $vec_bad of $vec_n wrong"; fi
if out="$(node "$LIB" --vectors "$VECTORS" 2>&1)" && printf '%s' "$out" | grep -q '^ok '; then pass "interlock-lib.cjs --vectors agrees ($out)"; else fail "interlock-lib.cjs --vectors: $out"; fi

# --- 13. Fail-open inputs -----------------------------------------------------
c="$(new_case)"; : > "$c/empty"
run_hook "$c" "$c/empty"; assert_allow "empty stdin allows"
printf 'not json' > "$c/bad"; run_hook "$c" "$c/bad"; assert_allow "non-JSON stdin allows"
t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
printf '{"transcript_path":"%s","tool_name":"Edit","tool_input":{},"tool_use_id":"toolu_1"}' "$t" > "$c/nosid"; run_hook "$c" "$c/nosid"; assert_allow "a payload without session_id allows"
write_payload "$c/slash" "bad/id" "$t" "Edit" '{}' "toolu_1"; run_hook "$c" "$c/slash"; assert_allow "a session_id with a slash allows"
write_payload "$c/notp" "sess-e" "" "Edit" '{}' "toolu_1"; run_hook "$c" "$c/notp"; assert_allow "a payload without a transcript path allows"
if [ -z "$(ls -A "$c/cache" 2>/dev/null)" ]; then pass "fail-open paths create no state"; else fail "fail-open paths create no state"; fi

# --- 14. An unwritable cache root, and a transcript that disappears ----------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
mkdir -p "$c/cache/hyperpowers/interlock"; chmod 500 "$c/cache/hyperpowers/interlock"
write_payload "$c/in" "sess-f" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_allow "an unwritable cache root allows"
chmod 700 "$c/cache/hyperpowers/interlock"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
write_payload "$c/in" "sess-h" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "first attempt denied before the transcript disappears"
rm -f "$t"
run_hook "$c" "$c/in"; assert_allow "a context transcript unreadable after the denial allows"

# --- 15. The whole-file read: a tail window would have allowed these ---------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_call "$t" a1 msg_one req_1 toolu_1
i=0
while [ "$i" -lt 12 ]; do
    append_text "$t" "filler-$i" msg_one req_1 "$(blob 100000)"
    i=$((i + 1))
done
append_call "$t" a2 msg_one req_1 toolu_sib
write_payload "$c/in" "sess-big1" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
write_payload "$c/in2" "sess-big1" "$t" "Edit" '{}' "toolu_sib"
run_hook "$c" "$c/in2"; assert_deny "a sibling whose denied call sits behind a megabyte of its own turn is denied"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
printf '{"type":"assistant","uuid":"a1","requestId":"req_1","message":{"id":"msg_one","role":"assistant","content":[{"type":"text","text":"%s"},{"type":"tool_use","id":"toolu_1","name":"Edit","input":{}}]}}\n' "$(blob 1200000)" >> "$t"
append_call "$t" a2 msg_one req_1 toolu_sib
write_payload "$c/in" "sess-big2" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
write_payload "$c/in2" "sess-big2" "$t" "Edit" '{}' "toolu_sib"
run_hook "$c" "$c/in2"; assert_deny "a denied call carried in one record over a megabyte still resolves, and its sibling is denied"

# --- 16. No clock: an absent denied call denies whatever the marker's age ----
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-clock" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied with no record on disk"
write_payload "$c/in2" "sess-clock" "$t" "Edit" '{}' "toolu_2"
run_hook "$c" "$c/in2"; assert_deny "a stored call that appears nowhere, with no delivered result, denies"
touch -t 202601010000 "$(marker_dir "$c" sess-clock s)"
run_hook "$c" "$c/in2"; assert_deny "and denies again with the marker aged well past any plausible interval -- the rule has no threshold to outlast"

# --- 17. The recovery, and its binding to the call ---------------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-rec" "$t" "Edit" '{}' "toolu_gone"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
append_result "$t" toolu_gone "$OPENING"
write_payload "$c/in2" "sess-rec" "$t" "Edit" '{}' "toolu_next"
run_hook "$c" "$c/in2"; assert_allow "a delivered denial bound to the stored call releases a context whose log lost the record"
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
append_result "$t" toolu_unrelated "$OPENING"
write_payload "$c/in" "sess-rec2" "$t" "Edit" '{}' "toolu_gone"
run_hook "$c" "$c/in"; assert_deny "the first attempt is denied"
write_payload "$c/in2" "sess-rec2" "$t" "Edit" '{}' "toolu_next"
run_hook "$c" "$c/in2"; assert_deny "the same text under a different tool_use_id -- what a cat or an rg of this repository prints -- does not release the sibling"

# --- 17b. The recovery may not act on a record its own snapshot can see ------
# Step 6 and the recovery run as separate processes, so each takes its own
# snapshot. If the denied call's record and its denial result both land between
# them, a recovery that looks only for the result releases a caller the wave
# rule never cleared -- a pre-composed sibling of the denied call among them.
# The design's safety argument, that a result carrying an id is appended after
# the record carrying it and the record has just been found absent, holds only
# inside ONE snapshot; the recovery therefore re-checks the record in its own.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-gap" "$t" "Edit" '{}' "toolu_win"
run_hook "$c" "$c/in"; assert_deny "the winner of a concurrent wave is denied with no record on disk"
append_call "$t" a1 msg_one req_1 toolu_win
append_result "$t" toolu_win "$OPENING"
set +e; node "$LIB" --delivered "$t" toolu_win >/dev/null 2>&1; d_rc=$?; set -e
if [ "$d_rc" -ne 0 ]; then pass "--delivered refuses a delivered denial whose record its own snapshot carries (exit $d_rc)"; else fail "--delivered accepted a delivered denial whose record its own snapshot carries"; fi

# The same rule through the hook, with both records landing in the window
# between step 6's last read and the recovery's read. The probe trace is
# appended after --resolve's final read, so a writer that waits for it puts the
# append exactly in that window and leaves step 6's answer deterministically
# absent.
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in" "sess-gap2" "$t" "Edit" '{}' "toolu_win"
run_hook "$c" "$c/in"; assert_deny "the winner of a second concurrent wave is denied with no record on disk"
write_payload "$c/in2" "sess-gap2" "$t" "Edit" '{}' "toolu_sib"
trc="$c/trace"; : > "$trc"
( i=0
  while [ "$i" -lt 400 ] && [ ! -s "$trc" ]; do sleep 0.01; i=$((i + 1)); done
  append_call "$t" a1 msg_one req_1 toolu_win
  append_result "$t" toolu_win "$OPENING" ) &
writer=$!
set +e
OUTPUT="$(env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" INTERLOCK_PROBE_TRACE="$trc" bash "$HOOK" < "$c/in2" 2>/dev/null)"
RC=$?
set -e
wait "$writer" || true
assert_deny "a denial delivered in the gap between step 6 and the recovery does not release a same-wave sibling"

# --- 18. Concurrency: one context, two calls; then two contexts --------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"
write_payload "$c/in1" "sess-j" "$t" "Edit" '{}' "toolu_a"
write_payload "$c/in2" "sess-j" "$t" "Edit" '{}' "toolu_b"
( env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$HOOK" < "$c/in1" > "$c/out1" 2>/dev/null ) &
p1=$!
( env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$HOOK" < "$c/in2" > "$c/out2" 2>/dev/null ) &
p2=$!
wait "$p1" || true; wait "$p2" || true
if grep -q '"permissionDecision":"deny"' "$c/out1" && grep -q '"permissionDecision":"deny"' "$c/out2"; then pass "two concurrent first attempts with no record of either call are both denied"; else fail "two concurrent first attempts with no record of either call are both denied"; fi
if [ "$(ls -d "$c/cache/hyperpowers/interlock/sess-j"/* | wc -l | tr -d ' ')" = "1" ]; then pass "they leave one marker and no temporary directory"; else fail "they leave one marker and no temporary directory ($(ls "$c/cache/hyperpowers/interlock/sess-j"))"; fi
c="$(new_case)"; t1="$c/home/proj/s.jsonl"; t2="$c/home/proj/s/subagents/agent-x.jsonl"
start_transcript "$t1"; append_call "$t1" a1 m1 r1 toolu_c
start_transcript "$t2"; append_call "$t2" b1 m9 r9 toolu_s
# Both payloads name the same transcript_path; only agent_id separates them.
write_payload "$c/in1" "sess-k" "$t1" "Edit" '{}' "toolu_c"; write_payload "$c/in2" "sess-k" "$t1" "Edit" '{}' "toolu_s" "x"
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
append_call "$t2" b2 m10 r10 toolu_s2
write_payload "$c/in3" "sess-k" "$t1" "Edit" '{}' "toolu_s2" "x"
run_hook "$c" "$c/in3"; assert_allow "the subagent's later-turn retry is allowed"
write_payload "$c/in4" "sess-k" "$t1" "Edit" '{}' "toolu_c"
run_hook "$c" "$c/in4"; assert_deny "and the controller's own interlock is unaffected by it"

# --- 19. The subagent shape end to end ---------------------------------------
# The controller transcript is written once here and never touched again: every
# subagent verdict below has to come from the subagent's own transcript.
c="$(new_case)"; t="$c/home/proj/sess-b.jsonl"; start_transcript "$t"; append_call "$t" a1 msg_b req_b toolu_ctl
sub="$c/home/proj/sess-b/subagents/agent-1234abcd.jsonl"; start_transcript "$sub"
append_call "$sub" s1 msg_sub req_sub toolu_s1
write_payload "$c/in" "sess-b" "$t" "MultiEdit" '{"file_path":"/tmp/x","edits":[]}' "toolu_s1" "1234abcd"
run_hook "$c" "$c/in"; assert_deny "a subagent context is denied at its own first attempt"
if [ "$(cat "$(marker_dir "$c" sess-b agent-1234abcd)/call" 2>/dev/null || true)" = "toolu_s1" ]; then
    pass "its marker is keyed agent-<agent_id> and records its own tool_use_id"
else
    fail "its marker is keyed agent-<agent_id> and records its own tool_use_id"
fi
append_call "$sub" s2 msg_sub req_sub toolu_s2
write_payload "$c/in2" "sess-b" "$t" "Edit" '{}' "toolu_s2" "1234abcd"
run_hook "$c" "$c/in2"; assert_deny "a second attempt in the same subagent turn is denied"
append_call "$sub" s3 msg_sub2 req_sub2 toolu_s3
write_payload "$c/in3" "sess-b" "$t" "Edit" '{}' "toolu_s3" "1234abcd"
run_hook "$c" "$c/in3"; assert_allow "a third in a later subagent turn is allowed, with the controller transcript never changing"
write_payload "$c/in4" "sess-b" "$t" "Edit" '{}' "toolu_ctl"
run_hook "$c" "$c/in4"; assert_deny "the controller is interlocked separately, at its own first attempt"
if [ -d "$(marker_dir "$c" sess-b sess-b)" ] && [ -d "$(marker_dir "$c" sess-b agent-1234abcd)" ]; then
    pass "a controller payload and a subagent payload never share a marker directory"
else
    fail "a controller payload and a subagent payload never share a marker directory"
fi

# --- 20. agent_id that names no transcript, and agent_id with a bad character -
c="$(new_case)"; t="$c/home/proj/sess-m.jsonl"; start_transcript "$t"; append_call "$t" a1 msg_m req_m toolu_1
write_payload "$c/in" "sess-m" "$t" "Edit" '{}' "toolu_1" "nosuchagent"
run_hook "$c" "$c/in"; assert_deny "a subagent whose derived transcript cannot be read is denied once"
run_hook "$c" "$c/in"; assert_allow "and allowed after that -- an unreadable transcript is step 6's first branch, not its lookup"
write_payload "$c/in2" "sess-m" "$t" "Edit" '{}' "toolu_1" "bad/id"
run_hook "$c" "$c/in2"; assert_allow "an agent_id outside A-Za-z0-9._- allows"
if [ "$(ls "$c/cache/hyperpowers/interlock/sess-m" | wc -l | tr -d ' ')" = "1" ]; then
    pass "and leaves no marker of its own"
else
    fail "and leaves no marker of its own ($(ls "$c/cache/hyperpowers/interlock/sess-m" | tr '\n' ' '))"
fi

# --- 21. An abandoned initializer never blocks a context ---------------------
c="$(new_case)"; t="$c/home/proj/s.jsonl"; start_transcript "$t"; append_call "$t" a1 m1 r1 toolu_1
mkdir -p "$c/cache/hyperpowers/interlock/sess-l/s.tmp.99999"; printf 'toolu_dead\n' > "$c/cache/hyperpowers/interlock/sess-l/s.tmp.99999/call"
write_payload "$c/in" "sess-l" "$t" "Edit" '{}' "toolu_1"
run_hook "$c" "$c/in"; assert_deny "after an abandoned initializer the next attempt publishes its own marker and is denied once"
append_call "$t" a2 m2 r2 toolu_2
write_payload "$c/in2" "sess-l" "$t" "Edit" '{}' "toolu_2"
run_hook "$c" "$c/in2"; assert_allow "and a later-turn retry is allowed"

# --- 22. session-start prunes old state --------------------------------------
c="$(new_case)"; root="$c/cache/hyperpowers/interlock"
mkdir -p "$root/old-sess/agent-old" "$root/old-sess/agent-old.tmp.1" "$root/fresh-sess/agent-fresh" "$root/empty-sess"
printf 'toolu_o\n' > "$root/old-sess/agent-old/call"; printf 'toolu_f\n' > "$root/fresh-sess/agent-fresh/call"
touch -t 202601010000 "$root/old-sess/agent-old" "$root/old-sess/agent-old.tmp.1"
printf '{"session_id":"t","hook_event_name":"SessionStart","source":"startup"}' > "$c/ss-in"
env -i PATH="${PATH:-}" HOME="$c/home" XDG_CACHE_HOME="$c/cache" bash "$SESSION_START" < "$c/ss-in" > /dev/null 2>&1 || true
if [ ! -d "$root/old-sess/agent-old" ] && [ ! -d "$root/old-sess/agent-old.tmp.1" ] && [ ! -d "$root/old-sess" ]; then pass "session-start removes a marker older than three days, an old temporary directory, and the emptied session"; else fail "session-start removes old state ($(cd "$root" && find . | tr '\n' ' '))"; fi
if [ -d "$root/fresh-sess/agent-fresh" ] && [ ! -d "$root/empty-sess" ]; then pass "session-start keeps a fresh marker and drops an empty session directory"; else fail "session-start keeps a fresh marker and drops an empty session directory"; fi

# --- 23. The hook file keeps the rules its comments claim --------------------
if ! grep -Eq '(^|[^<])<<' "$HOOK" "$LIB"; then pass "the hook and its helper open no heredoc or here-string"; else fail "the hook and its helper open no heredoc or here-string"; fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi
echo "STATUS: PASSED"
