#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_UNDER_TEST="$REPO_ROOT/hooks/session-start"
CODEX_HOOK_UNDER_TEST="$REPO_ROOT/hooks/session-start-codex"
WRAPPER_UNDER_TEST="$REPO_ROOT/hooks/run-hook.cmd"

FAILURES=0
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

make_home() {
    local name="$1"
    local home="$TEST_ROOT/$name/home"
    mkdir -p "$home"
    printf '%s\n' "$home"
}

# Stdin for the hook under test. A caller sets HOOK_STDIN to a file
# immediately before its assertion; the helper consumes it and resets to
# /dev/null so no later case inherits it. The default keeps every case that
# does not care about stdin from paying the hook's bounded read.
HOOK_STDIN="/dev/null"

assert_command_output() {
    local description="$1"
    local shape="$2"
    local contains="$3"
    local not_contains="$4"
    local home="$5"
    local stdin_path="$HOOK_STDIN"
    shift 5

    local output
    HOOK_STDIN="/dev/null"
    if ! output="$(env -i PATH="${PATH:-}" HOME="$home" "$@" <"$stdin_path" 2>&1)"; then
        fail "$description"
        echo "    hook exited non-zero"
        echo "$output" | sed 's/^/      /'
        return
    fi

    if printf '%s' "$output" | \
        EXPECT_SHAPE="$shape" \
        EXPECT_CONTAINS="$contains" \
        EXPECT_NOT_CONTAINS="$not_contains" \
        node -e '
const fs = require("fs");

const input = fs.readFileSync(0, "utf8");
let payload;
try {
  payload = JSON.parse(input);
} catch (error) {
  console.error(`invalid JSON: ${error.message}`);
  process.exit(1);
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

const shape = process.env.EXPECT_SHAPE;
let context;

if (shape === "nested") {
  if (!hasOwn(payload, "hookSpecificOutput")) {
    fail("missing hookSpecificOutput");
  }
  if (hasOwn(payload, "additional_context") || hasOwn(payload, "additionalContext")) {
    fail("nested output also included a top-level context field");
  }
  const hookOutput = payload.hookSpecificOutput;
  if (!hookOutput || typeof hookOutput !== "object" || Array.isArray(hookOutput)) {
    fail("hookSpecificOutput is not an object");
  }
  if (hookOutput.hookEventName !== "SessionStart") {
    fail(`unexpected hookEventName: ${hookOutput.hookEventName}`);
  }
  context = hookOutput.additionalContext;
} else if (shape === "cursor") {
  if (hasOwn(payload, "hookSpecificOutput")) {
    fail("cursor output included hookSpecificOutput");
  }
  if (!hasOwn(payload, "additional_context")) {
    fail("cursor output missing additional_context");
  }
  if (hasOwn(payload, "additionalContext")) {
    fail("cursor output included additionalContext");
  }
  context = payload.additional_context;
} else if (shape === "sdk") {
  if (hasOwn(payload, "hookSpecificOutput")) {
    fail("sdk output included hookSpecificOutput");
  }
  if (!hasOwn(payload, "additionalContext")) {
    fail("sdk output missing additionalContext");
  }
  if (hasOwn(payload, "additional_context")) {
    fail("sdk output included additional_context");
  }
  context = payload.additionalContext;
} else {
  fail(`unknown expected shape: ${shape}`);
}

if (typeof context !== "string" || context.trim() === "") {
  fail("injected context was empty");
}

const expectedText = process.env.EXPECT_CONTAINS || "";
if (expectedText && !context.includes(expectedText)) {
  fail(`context did not contain expected text: ${expectedText}`);
}

const forbiddenTexts = (process.env.EXPECT_NOT_CONTAINS || "")
  .split("\u001f")
  .filter(Boolean);
for (const forbiddenText of forbiddenTexts) {
  if (context.includes(forbiddenText)) {
    fail(`context contained forbidden text: ${forbiddenText}`);
  }
}
'; then
        pass "$description"
    else
        fail "$description"
        echo "    output:"
        echo "$output" | sed 's/^/      /'
    fi
}

echo "SessionStart hook output tests"

# Registration shape: the hook must declare shell:"bash" so Claude Code on
# Windows dispatches via Git Bash (or fails with an actionable error) instead
# of PowerShell/cmd.exe, whose parsers break on the quoted command string
# (PowerShell ParserError; cmd.exe quote-stripping on paths with metacharacters).
if node -e '
const hooks = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const entry = hooks.hooks.SessionStart[0].hooks[0];
if (entry.shell !== "bash") {
  console.error(`SessionStart hook shell is ${JSON.stringify(entry.shell)}, expected "bash"`);
  process.exit(1);
}
if (!/run-hook\.cmd" session-start$/.test(entry.command)) {
  console.error(`unexpected SessionStart command shape: ${entry.command}`);
  process.exit(1);
}
' "$REPO_ROOT/hooks/hooks.json"; then
    pass "hooks.json registers SessionStart with shell:bash dispatch"
else
    fail "hooks.json registers SessionStart with shell:bash dispatch"
fi

claude_home="$(make_home claude-code)"
assert_command_output \
    "Claude Code emits nested SessionStart additionalContext" \
    "nested" \
    "" \
    "" \
    "$claude_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

codex_home="$(make_home codex-plugin-hooks)"
codex_data="$TEST_ROOT/codex-plugin-hooks/data"
mkdir -p "$codex_data"
assert_command_output \
    "Codex plugin hooks use dedicated script and emit nested SessionStart additionalContext" \
    "nested" \
    "" \
    "" \
    "$codex_home" \
    PLUGIN_DATA="$codex_data" \
    CLAUDE_PLUGIN_DATA="$codex_data" \
    PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$CODEX_HOOK_UNDER_TEST"

codex_wrapper_home="$(make_home codex-wrapper)"
codex_wrapper_data="$TEST_ROOT/codex-wrapper/data"
mkdir -p "$codex_wrapper_data"
assert_command_output \
    "Codex wrapper path dispatches to dedicated script" \
    "nested" \
    "" \
    "" \
    "$codex_wrapper_home" \
    PLUGIN_DATA="$codex_wrapper_data" \
    CLAUDE_PLUGIN_DATA="$codex_wrapper_data" \
    PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$WRAPPER_UNDER_TEST" session-start-codex

cursor_home="$(make_home cursor)"
assert_command_output \
    "Cursor emits top-level additional_context only" \
    "cursor" \
    "" \
    "" \
    "$cursor_home" \
    CURSOR_PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

copilot_home="$(make_home copilot-cli)"
assert_command_output \
    "Copilot CLI emits top-level additionalContext only" \
    "sdk" \
    "" \
    "" \
    "$copilot_home" \
    COPILOT_CLI=1 \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

legacy_home="$(make_home legacy-warning-removed)"
mkdir -p "$legacy_home/.config/superpowers/skills"
assert_command_output \
    "SessionStart omits obsolete legacy custom-skill warning" \
    "nested" \
    "" \
    "Superpowers now uses"$'\037'"~/.config/superpowers/skills"$'\037'"~/.claude/skills"$'\037'"legacy" \
    "$legacy_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

codex_legacy_home="$(make_home codex-legacy-warning-removed)"
codex_legacy_data="$TEST_ROOT/codex-legacy-warning-removed/data"
mkdir -p "$codex_legacy_home/.config/superpowers/skills" "$codex_legacy_data"
assert_command_output \
    "Codex SessionStart omits obsolete legacy custom-skill warning" \
    "nested" \
    "" \
    "Superpowers now uses"$'\037'"~/.config/superpowers/skills"$'\037'"~/.claude/skills"$'\037'"legacy" \
    "$codex_legacy_home" \
    PLUGIN_DATA="$codex_legacy_data" \
    CLAUDE_PLUGIN_DATA="$codex_legacy_data" \
    PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$CODEX_HOOK_UNDER_TEST"

# --- plugin version staleness notice (spec D4) ------------------------------
# The running version is this repo's .claude-plugin/plugin.json; the test writes
# a marketplace manifest under the sandboxed HOME and varies only its version.
running_version="$(node -e 'console.log(require(process.argv[1]).version)' "$REPO_ROOT/.claude-plugin/plugin.json")"

write_marketplace() { # <home> <version>
    local mdir="$1/.claude/plugins/marketplaces/hyperpowers/.claude-plugin"
    mkdir -p "$mdir"
    printf '{"name":"hyperpowers","owner":{"name":"t"},"plugins":[{"name":"hyperpowers","source":"./","version":"%s"}]}\n' \
        "$2" > "$mdir/marketplace.json"
}

stale_home="$(make_home version-stale)"
write_marketplace "$stale_home" "99.0.0"
assert_command_output \
    "SessionStart announces a strictly newer marketplace version" \
    "nested" \
    "hyperpowers 99.0.0 is available; this session loaded ${running_version}" \
    "" \
    "$stale_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

current_home="$(make_home version-current)"
write_marketplace "$current_home" "$running_version"
assert_command_output \
    "SessionStart is silent when the marketplace version matches" \
    "nested" \
    "" \
    "is available" \
    "$current_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

ahead_home="$(make_home version-ahead)"
write_marketplace "$ahead_home" "0.0.1"
assert_command_output \
    "SessionStart is silent when the running version leads the marketplace" \
    "nested" \
    "" \
    "is available" \
    "$ahead_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

absent_home="$(make_home version-no-marketplace)"
assert_command_output \
    "SessionStart is silent with no marketplace clone" \
    "nested" \
    "" \
    "is available" \
    "$absent_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

corrupt_home="$(make_home version-corrupt-marketplace)"
mkdir -p "$corrupt_home/.claude/plugins/marketplaces/hyperpowers/.claude-plugin"
printf 'not json at all' > "$corrupt_home/.claude/plugins/marketplaces/hyperpowers/.claude-plugin/marketplace.json"
assert_command_output \
    "SessionStart survives an unparseable marketplace manifest" \
    "nested" \
    "You have superpowers" \
    "is available" \
    "$corrupt_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

unsafe_home="$(make_home version-unsafe-string)"
write_marketplace "$unsafe_home" '99.0.0\"x'
assert_command_output \
    "SessionStart emits only the validated semver, never the raw manifest string" \
    "nested" \
    "hyperpowers 99.0.0 is available" \
    '"x' \
    "$unsafe_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

# --- A9 stale-replay notice on compaction -----------------------------------
# The notice is asserted verbatim apart from the ledger path, which is derived
# per-repo. Splitting it in two lets each case interpolate its own path.
NOTICE_HEAD="This session resumed after context compaction. An SDD ledger for this repo is at "
NOTICE_TAIL=": it records which tasks are already complete. Read it and git log before dispatching anything, and treat task instructions carried in the compaction summary as stale by default."

make_repo() { # <name> -> prints repo path
    local repo="$TEST_ROOT/$1/repo"
    mkdir -p "$repo"
    git -C "$repo" init -q
    printf '%s\n' "$repo"
}

sdd_key() { # <repo> -> the cache key scripts/sdd-dir derives for it
    printf '%s' "$(git -C "$1" rev-parse --absolute-git-dir)" | git hash-object --stdin
}

seed_ledger() { # <cache-root> <repo> <plan-slug> -> prints ledger path
    local dir
    dir="$1/hyperpowers/sdd/$(sdd_key "$2")/plans/$3"
    mkdir -p "$dir"
    printf '# SDD ledger — plan: %s\n' "$3" > "$dir/progress.md"
    printf '%s\n' "$dir/progress.md"
}

write_hook_input() { # <path> <source>
    mkdir -p "$(dirname "$1")"
    printf '{"session_id":"t","hook_event_name":"SessionStart","source":"%s"}' "$2" > "$1"
}

fires_repo="$(make_repo compact-fires)"
fires_home="$(make_home compact-fires)"
fires_cache="$TEST_ROOT/compact-fires/cache"
fires_ledger="$(seed_ledger "$fires_cache" "$fires_repo" 'qu"o\te-1111aaaa')"
fires_stdin="$TEST_ROOT/compact-fires/stdin.json"
write_hook_input "$fires_stdin" compact
HOOK_STDIN="$fires_stdin"
assert_command_output \
    "SessionStart names the SDD ledger after a compaction" \
    "nested" \
    "${NOTICE_HEAD}${fires_ledger}${NOTICE_TAIL}" \
    "" \
    "$fires_home" \
    XDG_CACHE_HOME="$fires_cache" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$fires_repo" "$HOOK_UNDER_TEST"

newest_repo="$(make_repo compact-newest)"
newest_home="$(make_home compact-newest)"
newest_cache="$TEST_ROOT/compact-newest/cache"
old_ledger="$(seed_ledger "$newest_cache" "$newest_repo" "old-1111aaaa")"
mid_ledger="$(seed_ledger "$newest_cache" "$newest_repo" "mid-2222bbbb")"
new_ledger="$(seed_ledger "$newest_cache" "$newest_repo" "new-3333cccc")"
touch -t 202401010000 "$old_ledger"
touch -t 202402010000 "$mid_ledger"
touch -t 202403010000 "$new_ledger"
newest_stdin="$TEST_ROOT/compact-newest/stdin.json"
write_hook_input "$newest_stdin" compact
HOOK_STDIN="$newest_stdin"
assert_command_output \
    "SessionStart names the newest ledger when several exist" \
    "nested" \
    "${NOTICE_HEAD}${new_ledger}${NOTICE_TAIL}" \
    "$old_ledger"$'\037'"$mid_ledger" \
    "$newest_home" \
    XDG_CACHE_HOME="$newest_cache" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$newest_repo" "$HOOK_UNDER_TEST"

quiet_repo="$(make_repo compact-quiet)"
quiet_home="$(make_home compact-quiet)"
quiet_cache="$TEST_ROOT/compact-quiet/cache"
seed_ledger "$quiet_cache" "$quiet_repo" "quiet-4444dddd" >/dev/null
for quiet_source in startup resume clear; do
    quiet_stdin="$TEST_ROOT/compact-quiet/stdin-$quiet_source.json"
    write_hook_input "$quiet_stdin" "$quiet_source"
    HOOK_STDIN="$quiet_stdin"
    assert_command_output \
        "SessionStart is silent on $quiet_source with a ledger present" \
        "nested" \
        "" \
        "This session resumed after context compaction" \
        "$quiet_home" \
        XDG_CACHE_HOME="$quiet_cache" \
        CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
        bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$quiet_repo" "$HOOK_UNDER_TEST"
done

noledger_repo="$(make_repo compact-no-ledger)"
noledger_home="$(make_home compact-no-ledger)"
noledger_cache="$TEST_ROOT/compact-no-ledger/cache"
mkdir -p "$noledger_cache"
noledger_stdin="$TEST_ROOT/compact-no-ledger/stdin.json"
write_hook_input "$noledger_stdin" compact
HOOK_STDIN="$noledger_stdin"
assert_command_output \
    "SessionStart is silent on compact with no ledger" \
    "nested" \
    "" \
    "This session resumed after context compaction" \
    "$noledger_home" \
    XDG_CACHE_HOME="$noledger_cache" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$noledger_repo" "$HOOK_UNDER_TEST"

# The outside-a-repository case has to establish its own premise, because a
# sandbox that happened to sit inside a checkout would pass it vacuously.
norepo_dir="$TEST_ROOT/compact-no-repo/dir"
norepo_home="$(make_home compact-no-repo)"
mkdir -p "$norepo_dir"
norepo_stdin="$TEST_ROOT/compact-no-repo/stdin.json"
write_hook_input "$norepo_stdin" compact
if git -C "$norepo_dir" rev-parse --absolute-git-dir >/dev/null 2>&1; then
    fail "the test sandbox is inside a git repository; the outside-a-repo case cannot run"
else
    HOOK_STDIN="$norepo_stdin"
    assert_command_output \
        "SessionStart is silent on compact outside a git repository" \
        "nested" \
        "" \
        "This session resumed after context compaction" \
        "$norepo_home" \
        XDG_CACHE_HOME="$TEST_ROOT/compact-no-repo/cache" \
        CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
        bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$norepo_dir" "$HOOK_UNDER_TEST"
fi

garbage_repo="$(make_repo compact-garbage)"
garbage_home="$(make_home compact-garbage)"
garbage_cache="$TEST_ROOT/compact-garbage/cache"
seed_ledger "$garbage_cache" "$garbage_repo" "garbage-5555eeee" >/dev/null
garbage_stdin="$TEST_ROOT/compact-garbage/stdin.json"
mkdir -p "$(dirname "$garbage_stdin")"
printf 'not json at all' > "$garbage_stdin"
HOOK_STDIN="$garbage_stdin"
assert_command_output \
    "SessionStart survives unparseable hook input on stdin" \
    "nested" \
    "You have superpowers" \
    "This session resumed after context compaction" \
    "$garbage_home" \
    XDG_CACHE_HOME="$garbage_cache" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$garbage_repo" "$HOOK_UNDER_TEST"

codex_compact_repo="$(make_repo compact-codex)"
codex_compact_home="$(make_home compact-codex)"
codex_compact_cache="$TEST_ROOT/compact-codex/cache"
codex_compact_data="$TEST_ROOT/compact-codex/data"
mkdir -p "$codex_compact_data"
seed_ledger "$codex_compact_cache" "$codex_compact_repo" "codex-6666ffff" >/dev/null
codex_compact_stdin="$TEST_ROOT/compact-codex/stdin.json"
write_hook_input "$codex_compact_stdin" compact
HOOK_STDIN="$codex_compact_stdin"
assert_command_output \
    "Codex SessionStart emits no compaction notice" \
    "nested" \
    "You have superpowers" \
    "This session resumed after context compaction" \
    "$codex_compact_home" \
    XDG_CACHE_HOME="$codex_compact_cache" \
    PLUGIN_DATA="$codex_compact_data" \
    CLAUDE_PLUGIN_DATA="$codex_compact_data" \
    PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$codex_compact_repo" "$CODEX_HOOK_UNDER_TEST"

# The watchdog needs timing, so it runs the hook directly rather than through
# the helper. A backgrounded sleep holds the write end of a fifo open and never
# writes; the hook must return anyway.
watchdog_repo="$(make_repo compact-watchdog)"
watchdog_home="$(make_home compact-watchdog)"
watchdog_cache="$TEST_ROOT/compact-watchdog/cache"
seed_ledger "$watchdog_cache" "$watchdog_repo" "watchdog-7777aaaa" >/dev/null
watchdog_fifo="$TEST_ROOT/compact-watchdog/stall.fifo"
mkfifo "$watchdog_fifo"
sleep 30 > "$watchdog_fifo" &
watchdog_writer=$!
watchdog_start=$SECONDS
watchdog_status=0
watchdog_out="$(env -i PATH="${PATH:-}" HOME="$watchdog_home" \
    XDG_CACHE_HOME="$watchdog_cache" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$watchdog_repo" "$HOOK_UNDER_TEST" \
    < "$watchdog_fifo" 2>/dev/null)" || watchdog_status=$?
watchdog_elapsed=$((SECONDS - watchdog_start))
kill "$watchdog_writer" 2>/dev/null || true
wait "$watchdog_writer" 2>/dev/null || true

if [ "$watchdog_status" -eq 0 ]; then
    pass "SessionStart exits 0 with a stalled stdin pipe"
else
    fail "SessionStart exits 0 with a stalled stdin pipe (exit $watchdog_status)"
fi
if [ "$watchdog_elapsed" -lt 5 ]; then
    pass "SessionStart returns within five seconds with a stalled stdin pipe"
else
    fail "SessionStart returns within five seconds with a stalled stdin pipe (${watchdog_elapsed}s)"
fi
if printf '%s' "$watchdog_out" | grep -Fq 'This session resumed after context compaction'; then
    fail "SessionStart is silent when the source never arrives"
else
    pass "SessionStart is silent when the source never arrives"
fi

# The ceiling. Every notice must actually fire, or the measurement is vacuous,
# so the check asserts all three markers before it measures.
ceiling_repo="$(make_repo compact-ceiling)"
ceiling_home="$(make_home compact-ceiling)"
ceiling_cache="$TEST_ROOT/compact-ceiling/cache"
seed_ledger "$ceiling_cache" "$ceiling_repo" "ceiling-8888bbbb" >/dev/null
write_marketplace "$ceiling_home" "99.0.0"
git -C "$ceiling_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
ceiling_base="$(git -C "$ceiling_repo" rev-parse HEAD)"
git -C "$ceiling_repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
ceiling_head="$(git -C "$ceiling_repo" rev-parse HEAD)"
XDG_CACHE_HOME="$ceiling_cache" bash "$REPO_ROOT/skills/requesting-code-review/scripts/ungated-ledger" \
    append --class degraded-gate --gate task --base "$ceiling_base" --head "$ceiling_head" \
    --status not-ready --note x "$ceiling_repo" >/dev/null
ceiling_stdin="$TEST_ROOT/compact-ceiling/stdin.json"
write_hook_input "$ceiling_stdin" compact
skill_chars="$(node -e 'process.stdout.write(String(require("fs").readFileSync(process.argv[1],"utf8").length))' \
    "$REPO_ROOT/skills/using-hyperpowers/SKILL.md")"
ceiling_out="$(env -i PATH="${PATH:-}" HOME="$ceiling_home" \
    XDG_CACHE_HOME="$ceiling_cache" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$ceiling_repo" "$HOOK_UNDER_TEST" \
    < "$ceiling_stdin" 2>/dev/null)"
if printf '%s' "$ceiling_out" | SKILL_CHARS="$skill_chars" node -e '
const payload = JSON.parse(require("fs").readFileSync(0, "utf8"));
const context = payload.hookSpecificOutput.additionalContext;
const required = [
  "This session resumed after context compaction",
  "is available; this session loaded",
  "ungated review item(s) pending sweep",
];
for (const marker of required) {
  if (!context.includes(marker)) {
    console.error(`ceiling case did not fire every notice; missing: ${marker}`);
    process.exit(1);
  }
}
const overhead = context.length - Number(process.env.SKILL_CHARS);
if (!(overhead < 1200)) {
  console.error(`notice overhead is ${overhead} characters, ceiling is 1200`);
  process.exit(1);
}
'; then
    pass "every notice fires and the context overhead stays under 1200 characters"
else
    fail "every notice fires and the context overhead stays under 1200 characters"
fi

# The four constraints below live only as comments in the hook. Nothing the
# hook emits can carry them, so no behavioral case can catch their deletion.
# Every other rule in those comment blocks is already pinned by an assertion
# above; these four are not, which is why they are pinned as text.
if grep -Fq 'Every notice appended to session_context is ONE line.' "$HOOK_UNDER_TEST"; then
    pass "session-start records the one-line notice budget"
else
    fail "session-start records the one-line notice budget"
fi

if grep -Fq 'the same cache key as scripts/sdd-dir but never calls it' "$HOOK_UNDER_TEST"; then
    pass "session-start records that it never calls sdd-dir"
else
    fail "session-start records that it never calls sdd-dir"
fi

if grep -Fq "janitor: that subshell's children inherit this descriptor and would consume" "$HOOK_UNDER_TEST"; then
    pass "session-start records why the stdin read sits above the janitor"
else
    fail "session-start records why the stdin read sits above the janitor"
fi

if grep -Fq 'A terminal stdin means no payload at all.' "$HOOK_UNDER_TEST"; then
    pass "session-start records that a terminal stdin carries no payload"
else
    fail "session-start records that a terminal stdin carries no payload"
fi

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
