#!/usr/bin/env bash
# Offline check for the integration test's delivery-directory resolution.
#
# The resolution block decides WHERE test-subagent-driven-development-integration.sh
# looks for the deliverable. Getting it wrong is silent: the suite reported
# "src/math.js not created" for a run that created it in an SDD worktree, and
# passed `npm test` over the empty test/ dir left in the base checkout. That
# failure mode costs a ~25-minute live run to observe, so it is pinned here.
#
# The block under test is EXTRACTED from the integration test rather than
# copied, so this cannot drift away from the code it certifies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="$SCRIPT_DIR/test-subagent-driven-development-integration.sh"
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "  [SKIP] node/npm not available -- cannot exercise the npm-test block"
    exit 0
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

failures=0
passes=0

pass() {
    echo "  [PASS] $1"
    passes=$((passes + 1))
}

fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

BLOCK="$WORK/resolution.sh"
sed -n '/^DELIVERY_DIR="\$TEST_PROJECT"$/,/^done <<<"\$worktree_list"$/p' \
    "$SUBJECT" >"$BLOCK"
if [ ! -s "$BLOCK" ]; then
    echo "  [FAIL] could not extract the resolution block from $(basename "$SUBJECT")"
    echo "         (its anchors changed -- update this test with them)"
    exit 1
fi

# Resolve the block against a fixture. Prints the physical delivery path and
# the match flag, tab-separated. Physical, because `git worktree list` reports
# resolved paths while $TEST_PROJECT may arrive symlinked -- the assertion is
# "points at the right directory", not "produces this exact string".
resolve() {
    TEST_PROJECT="$1" bash -c '
        set -euo pipefail
        source "$1"
        printf "%s\t%s\n" "$(cd "$DELIVERY_DIR" && pwd -P)" "$delivery_found"
    ' _ "$BLOCK"
}

phys() { (cd "$1" && pwd -P); }

# want_dir, want_found, got, label
check() {
    local want="$1	$2" got="$3" label="$4"
    if [ "$got" = "$want" ]; then
        pass "$label"
    else
        fail "$label: got '$got', want '$want'"
    fi
}

make_repo() {
    local dir="$1"
    mkdir -p "$dir/src" "$dir/test"
    git -C "$dir" init --quiet
    git -C "$dir" config user.email test@test.com
    git -C "$dir" config user.name "Test User"
    # Mirror the integration test's fixture, `node --test` script included --
    # without it every npm-test case below fails on "Missing script" and passes
    # or fails for a reason that has nothing to do with the block under test.
    cat >"$dir/package.json" <<'JSON'
{
  "name": "test-project",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
JSON
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "Initial commit"
}

echo "=== Delivery-directory resolution ==="

# Case 1: SDD's actual shape -- work committed in a linked worktree, base
# checkout untouched. This is the case that was silently mis-resolved.
A="$WORK/a"
make_repo "$A"
git -C "$A" worktree add --quiet -b sdd-math "$A/.worktrees/sdd-math"
# git does not carry empty directories, so a fresh worktree has no src/ --
# the implementer creates it. Mirror that rather than assuming it exists.
mkdir -p "$A/.worktrees/sdd-math/src"
echo 'export function add(a, b) { return a + b; }' >"$A/.worktrees/sdd-math/src/math.js"
git -C "$A/.worktrees/sdd-math" add -A
git -C "$A/.worktrees/sdd-math" commit -q -m "feat: add"
check "$(phys "$A/.worktrees/sdd-math")" true "$(resolve "$A")" \
    "resolves to the worktree holding the deliverable"

# Case 2: work done in the base checkout. The main worktree is itself in
# `git worktree list`, so it must win on its own merits, not by fallback.
B="$WORK/b"
make_repo "$B"
echo 'export function add(a, b) { return a + b; }' >"$B/src/math.js"
check "$(phys "$B")" true "$(resolve "$B")" \
    "resolves to the base checkout when the work landed there"

# Case 3: nothing produced anywhere. Must fall back to the base so Test 6
# reports a real "not created" rather than erroring out in resolution.
C="$WORK/c"
make_repo "$C"
git -C "$C" worktree add --quiet -b empty-wt "$C/.worktrees/empty-wt"
check "$(phys "$C")" false "$(resolve "$C")" \
    "falls back to the base checkout, flagged unmatched, when nothing holds it"

# Case 4: a decoy worktree with no deliverable must not shadow the real one,
# whatever order git lists them in.
D="$WORK/d"
make_repo "$D"
git -C "$D" worktree add --quiet -b decoy "$D/.worktrees/aaa-decoy"
git -C "$D" worktree add --quiet -b real "$D/.worktrees/zzz-real"
mkdir -p "$D/.worktrees/zzz-real/src"
echo 'export function add(a, b) { return a + b; }' >"$D/.worktrees/zzz-real/src/math.js"
check "$(phys "$D/.worktrees/zzz-real")" true "$(resolve "$D")" \
    "skips a worktree that does not hold the deliverable"

echo ""
echo "=== npm test is evidence, not exit status ==="

# The companion half of the same defect. `node --test` exits 0 when it finds no
# test files, so an exit-status-only check announced "Tests pass" about a run
# that executed nothing. Extract the real block and confirm it distinguishes
# ran-and-passed from ran-nothing.
NPM_BLOCK="$WORK/npmtest.sh"
sed -n '/^TEST_OUTPUT="\$DELIVERY_DIR\/test-output.txt"$/,/^fi$/p' \
    "$SUBJECT" >"$NPM_BLOCK"
if [ ! -s "$NPM_BLOCK" ]; then
    fail "could not extract the npm-test block (its anchors changed)"
else
    run_npm_block() {
        DELIVERY_DIR="$1" bash -c '
            set -uo pipefail
            FAILED=0
            source "$1"
            printf "FAILED=%s\n" "$FAILED"
        ' _ "$NPM_BLOCK" 2>&1
    }

    # Real tests present: must pass and say how many ran.
    E="$WORK/e"
    make_repo "$E"
    cat >"$E/test/math.test.js" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert';
test('adds', () => { assert.strictEqual(1 + 1, 2); });
test('multiplies', () => { assert.strictEqual(2 * 3, 6); });
JS
    out="$(run_npm_block "$E")"
    if printf '%s' "$out" | grep -q '\[PASS\] Tests pass (2 test(s) ran)' &&
        printf '%s' "$out" | grep -q 'FAILED=0'; then
        pass "reports the executed test count when tests really ran"
    else
        fail "real tests: unexpected output"
        printf '%s\n' "$out" | sed 's/^/        /'
    fi

    # No test files at all: node --test exits 0. This must NOT read as passing.
    F="$WORK/f"
    make_repo "$F"
    out="$(run_npm_block "$F")"
    if printf '%s' "$out" | grep -q 'exited 0 but ran no tests' &&
        printf '%s' "$out" | grep -q 'FAILED=1'; then
        pass "fails a zero-exit run that executed no tests"
    else
        fail "empty suite: should have failed as vacuous"
        printf '%s\n' "$out" | sed 's/^/        /'
    fi

    # A genuinely failing test still fails, through the other branch.
    G="$WORK/g"
    make_repo "$G"
    cat >"$G/test/math.test.js" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert';
test('broken', () => { assert.strictEqual(1, 2); });
JS
    out="$(run_npm_block "$G")"
    if printf '%s' "$out" | grep -q '\[FAIL\] Tests failed' &&
        printf '%s' "$out" | grep -q 'FAILED=1'; then
        pass "fails a suite whose tests ran and failed"
    else
        fail "failing suite: unexpected output"
        printf '%s\n' "$out" | sed 's/^/        /'
    fi
fi

echo ""
echo "=== session transcript resolution ==="

# Third member of the same defect family: the harness looking in one place while
# the artifact is in another. Claude Code names its project directory after the
# session's cwd and re-homes the transcript when the controller cd's into a
# worktree, so a worktree-shaped run leaves the base directory holding an empty
# memory/ dir and nothing else. Observed live: the first run with
# SDD_INTEGRATION_WORKTREE=1 finished every task, both Codex gates and the final
# review, then died on "Could not find session transcript file".
SESSION_BLOCK="$WORK/session.sh"
sed -n '/^SESSION_DIR="\$HOME\/\.claude\/projects\//,/^fi$/p' \
    "$SUBJECT" >"$SESSION_BLOCK"
if [ ! -s "$SESSION_BLOCK" ]; then
    fail "could not extract the session-resolution block (its anchors changed)"
else
    mangle() { printf '%s' "$1" | sed 's|[^a-zA-Z0-9]|-|g'; }

    # Creates <home>/.claude/projects/<mangled project><suffix>/session.jsonl
    # and prints the file path. A suffix mimics the worktree re-home.
    mk_session() {
        local dir
        dir="$1/.claude/projects/$(mangle "$2")$3"
        mkdir -p "$dir"
        printf '{}\n' >"$dir/session.jsonl"
        printf '%s' "$dir/session.jsonl"
    }

    resolve_session() {
        HOME="$1" TEST_PROJECT_REAL="$2" bash -c '
            set -uo pipefail
            source "$1"
            printf "RESOLVED=%s\n" "${SESSION_FILE:-}"
        ' _ "$SESSION_BLOCK" 2>&1
    }

    PROJ="/tmp/proj-one"

    # The live failure: base directory present but transcript-less, real
    # transcript under the worktree-named sibling.
    H="$WORK/h-worktree"
    mkdir -p "$H/.claude/projects/$(mangle "$PROJ")/memory"
    want=$(mk_session "$H" "$PROJ" "--worktrees-math-functions")
    got=$(resolve_session "$H" "$PROJ") || true
    if [ "$got" = "RESOLVED=$want" ]; then
        pass "finds the transcript re-homed under a worktree-named sibling"
    else
        fail "worktree re-home: got '$got', want 'RESOLVED=$want'"
    fi

    # Unconstrained runs still resolve from the base directory.
    H="$WORK/h-base"
    want=$(mk_session "$H" "$PROJ" "")
    got=$(resolve_session "$H" "$PROJ") || true
    if [ "$got" = "RESOLVED=$want" ]; then
        pass "finds the transcript in the base project directory"
    else
        fail "base directory: got '$got', want 'RESOLVED=$want'"
    fi

    # An unrelated project's transcript must not be adopted -- the glob is
    # anchored on this run's unique tmp dir, not on the projects root.
    H="$WORK/h-foreign"
    mkdir -p "$H/.claude/projects/$(mangle "$PROJ")/memory"
    mk_session "$H" "/tmp/other-project" "" >/dev/null
    got=$(resolve_session "$H" "$PROJ") || true
    if printf '%s' "$got" | grep -q 'Could not find session transcript'; then
        pass "ignores a foreign project's transcript"
    else
        fail "foreign transcript: should not have resolved, got '$got'"
    fi

    # Nothing anywhere: the error names both places it looked.
    H="$WORK/h-empty"
    mkdir -p "$H/.claude/projects"
    got=$(resolve_session "$H" "$PROJ") || true
    if printf '%s' "$got" | grep -q 'Could not find session transcript' &&
        printf '%s' "$got" | grep -q 'siblings'; then
        pass "reports both search locations when nothing is found"
    else
        fail "empty case: unexpected output '$got'"
    fi
fi

echo ""
echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
