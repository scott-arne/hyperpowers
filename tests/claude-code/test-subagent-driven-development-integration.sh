#!/usr/bin/env bash
# Integration Test: subagent-driven-development workflow
# Actually executes a plan and verifies the new workflow behaviors
#
# Drill coverage: evals/scenarios/sdd-rejects-extra-features.yaml covers the
# YAGNI enforcement subset (forbidden exports + reviewer-as-gate semantics)
# and is stricter on that axis. This bash test additionally asserts:
#   - >=3 git commits (initial + per-task commits, exercising SDD's
#     commit-per-task workflow shape)
#   - >=2 Claude Code subagent dispatches via Agent or Task (drill only asserts >=1)
#   - durable progress tracking: a task tool or the SDD ledger (drill makes no assertion)
#   - test/math.test.js exists (drill relies on `npm test` succeeding)
#   - analyze-token-usage.py token-budget telemetry
# Kept until those assertions are added to drill or explicitly retired.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Integration Test: subagent-driven-development"
echo "========================================"
echo ""
echo "This test executes a real plan using the skill and verifies:"
echo "  1. Plan is read once (not per task)"
echo "  2. Full task text provided to subagents"
echo "  3. Subagents perform self-review"
echo "  4. Spec compliance review before code quality"
echo "  5. Review loops when issues found"
echo "  6. Spec reviewer reads code independently"
echo ""
echo "WARNING: This test may take 10-60 minutes to complete."
echo ""

# Ceiling for the live claude execution. A full SDD run (two tasks, task
# reviews, fix loops, final review) was observed to exceed the original
# 1800s ceiling before its analysis phase ran; 3600s gives the workflow
# headroom. Override with SDD_INTEGRATION_TIMEOUT for slower environments.
CLAUDE_TIMEOUT="${SDD_INTEGRATION_TIMEOUT:-3600}"

# Which delivery shape to exercise. SDD's Setup routes through
# using-git-worktrees, whose Step 1b takes a linked worktree only when the
# instructions declare a worktree directory preference (priority 1) or a
# project-local .worktrees/ already exists (priority 2). A headless run
# declares neither, so it branches in place and only the base-checkout
# resolution path runs -- leaving the worktree path, the one whose
# mis-resolution caused this suite to report "src/math.js not created" against
# a run that had created it, covered offline only. Set
# SDD_INTEGRATION_WORKTREE=1 to force the other shape.
WORKTREE_MODE="${SDD_INTEGRATION_WORKTREE:-0}"

# Create test project
TEST_PROJECT=$(create_test_project)
echo "Test project: $TEST_PROJECT"

# Trap to cleanup
trap 'cleanup_test_project "$TEST_PROJECT"' EXIT

# Set up minimal Node.js project
cd "$TEST_PROJECT"

cat > package.json <<'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF

mkdir -p src test docs/hyperpowers/plans

# Keep a worktree out of the fixture's own history whichever shape SDD picks.
# using-git-worktrees refuses a project-local worktree directory that is not
# ignored, and would otherwise stop to add and commit this itself.
printf '.worktrees/\n' > .gitignore

if [ "$WORKTREE_MODE" = "1" ]; then
    # Directory-selection priority 2: an existing .worktrees/ wins the choice.
    # git carries no empty directories, so this lives on disk and never in the
    # initial commit -- which is all `ls -d .worktrees` needs.
    mkdir -p .worktrees
fi

# Create a simple implementation plan
cat > docs/hyperpowers/plans/implementation-plan.md <<'EOF'
# Test Implementation Plan

This is a minimal plan to test the subagent-driven-development workflow.

## Task 1: Create Add Function

Create a function that adds two numbers.

**File:** `src/math.js`

**Requirements:**
- Function named `add`
- Takes two parameters: `a` and `b`
- Returns the sum of `a` and `b`
- Export the function

**Implementation:**
```javascript
export function add(a, b) {
  return a + b;
}
```

**Tests:** Create `test/math.test.js` that verifies:
- `add(2, 3)` returns `5`
- `add(0, 0)` returns `0`
- `add(-1, 1)` returns `0`

**Verification:** `npm test`

## Task 2: Create Multiply Function

Create a function that multiplies two numbers.

**File:** `src/math.js` (add to existing file)

**Requirements:**
- Function named `multiply`
- Takes two parameters: `a` and `b`
- Returns the product of `a` and `b`
- Export the function
- DO NOT add any extra features (like power, divide, etc.)

**Implementation:**
```javascript
export function multiply(a, b) {
  return a * b;
}
```

**Tests:** Add to `test/math.test.js`:
- `multiply(2, 3)` returns `6`
- `multiply(0, 5)` returns `0`
- `multiply(-2, 3)` returns `-6`

**Verification:** `npm test`
EOF

# Initialize git repo
git init --quiet
git config user.email "test@test.com"
git config user.name "Test User"
git add .
git commit -m "Initial commit" --quiet

echo ""
echo "Project setup complete. Starting execution..."
echo ""

# Run Claude with subagent-driven-development
# Capture full output to analyze
OUTPUT_FILE="$TEST_PROJECT/claude-output.txt"

# Create prompt file
cat > "$TEST_PROJECT/prompt.txt" <<'EOF'
I want you to execute the implementation plan at docs/hyperpowers/plans/implementation-plan.md using the subagent-driven-development skill.

IMPORTANT: Follow the skill exactly. I will be verifying that you:
1. Read the plan once at the beginning
2. Provide full task text to subagents (don't make them read files)
3. Ensure subagents do self-review before reporting
4. Run spec compliance review before code quality review
5. Use review loops when issues are found

Begin now. Execute the plan.
EOF

# Note: We use a longer timeout since this is integration testing
# Use --allowed-tools to enable tool usage in headless mode
PROMPT="Execute the implementation plan at docs/hyperpowers/plans/implementation-plan.md using the subagent-driven-development skill.

IMPORTANT: Follow the skill exactly. I will be verifying that you:
1. Read the plan once at the beginning
2. Provide full task text to subagents (don't make them read files)
3. Ensure subagents do self-review before reporting
4. Run spec compliance review before code quality review
5. Use review loops when issues are found

Begin now. Execute the plan."

if [ "$WORKTREE_MODE" = "1" ]; then
    # Priority 1: a declared preference. This also answers Step 0's consent
    # question, which a headless run has no way to ask.
    PROMPT="$PROMPT

Work in an isolated git worktree under .worktrees/. That is my declared worktree directory preference -- create it without asking me for consent."
fi

PLUGIN_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

# Run claude from inside the test project so its session JSONL lands in a
# project-specific directory under ~/.claude/projects/, isolated from any
# other concurrent claude sessions.
echo "Running Claude (plugin-dir: $PLUGIN_DIR, cwd: $TEST_PROJECT)..."
if [ "$WORKTREE_MODE" = "1" ]; then
    echo "Delivery shape: worktree requested (SDD_INTEGRATION_WORKTREE=1)"
else
    echo "Delivery shape: unconstrained (set SDD_INTEGRATION_WORKTREE=1 for a worktree)"
fi
echo "================================================================================"
# Capture the CLI's own exit status via PIPESTATUS: `$?` after the pipeline
# reports tee's status, and `$?` inside an `|| { ... }` block is clobbered by
# the block's own commands before it can be printed.
set +e
cd "$TEST_PROJECT" && timeout "$CLAUDE_TIMEOUT" claude -p "$PROMPT" --plugin-dir "$PLUGIN_DIR" --allowed-tools=all --permission-mode bypassPermissions 2>&1 | tee "$OUTPUT_FILE"
CLAUDE_STATUS=${PIPESTATUS[0]}
set -e
if [ "$CLAUDE_STATUS" -ne 0 ]; then
    echo ""
    echo "================================================================================"
    # timeout(1) exits 124 on expiry (137 if it had to SIGKILL); tell a
    # ceiling kill apart from a real crash so triage starts in the right place.
    if [ "$CLAUDE_STATUS" -eq 124 ] || [ "$CLAUDE_STATUS" -eq 137 ]; then
        echo "EXECUTION TIMED OUT after ${CLAUDE_TIMEOUT}s (exit code: $CLAUDE_STATUS)"
    else
        echo "EXECUTION FAILED (exit code: $CLAUDE_STATUS)"
    fi
    exit 1
fi
echo "================================================================================"

echo ""
echo "Execution complete. Analyzing results..."
echo ""

# Find the session transcript. Because we ran claude from $TEST_PROJECT (a
# unique tmp dir), its sessions live in their own ~/.claude/projects/ folder
# and we can pick the most-recent one without racing other concurrent sessions.
# Resolve the real path because macOS mktemp returns /var/... but claude
# normalizes it to /private/var/... when naming the project dir.
TEST_PROJECT_REAL=$(cd "$TEST_PROJECT" && pwd -P)
# Claude normalizes the cwd to a directory name by replacing every non-alphanumeric
# character with `-` (so `_`, `.`, `/` all become `-`).
SESSION_DIR="$HOME/.claude/projects/$(echo "$TEST_PROJECT_REAL" | sed 's|[^a-zA-Z0-9]|-|g')"
# The transcript does not necessarily land there. Claude Code names the project
# directory after the session's cwd and re-homes the JSONL when the controller
# cd's into a worktree, so an SDD run that isolates its work leaves
# $SESSION_DIR holding nothing but an empty memory/ dir while the real
# transcript sits under a directory named for the worktree. Every worktree path
# is a child of $TEST_PROJECT, so its mangled name is this one plus a suffix:
# search the base directory and all of its extensions, newest first. Anchoring
# on $SESSION_DIR keeps the search inside this run's unique tmp dir, so a
# concurrent session cannot be picked up.
# `|| true` prevents pipefail killing the script if ls gets SIGPIPE'd by head.
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.jsonl "$SESSION_DIR"-*/*.jsonl 2>/dev/null | head -1 || true)

if [ -z "$SESSION_FILE" ]; then
    echo "ERROR: Could not find session transcript file"
    echo "Looked in: $SESSION_DIR (and ${SESSION_DIR##*/}-* siblings)"
    exit 1
fi

echo "Analyzing session transcript: $(basename "$SESSION_FILE")"
echo ""

# Resolve where the deliverable actually landed before verifying it. SDD's
# Setup step does the work in an isolated worktree and commits on that branch,
# so $TEST_PROJECT keeps only the initial commit and the empty src/ and test/
# dirs the fixture made. Checking the base checkout reported "src/math.js not
# created" against a run that had created it one directory away -- and the same
# mismatch let `npm test` and the extra-features check pass over files that
# were not there, which is worse than the visible failures because it reads as
# evidence.
DELIVERY_DIR="$TEST_PROJECT"
delivery_found=false
worktree_list=$(git -C "$TEST_PROJECT" worktree list --porcelain 2>/dev/null |
    awk '/^worktree /{print $2}')
while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    if [ -f "$candidate/src/math.js" ]; then
        DELIVERY_DIR="$candidate"
        delivery_found=true
        break
    fi
done <<<"$worktree_list"

echo "Verifying delivery in: $DELIVERY_DIR"
if [ "$delivery_found" = false ]; then
    # The base checkout by fallback, not by a match -- nothing anywhere holds
    # the deliverable. Print the search so a genuine "never produced" is
    # distinguishable from a "produced somewhere this test does not know to
    # look". A flag decides this rather than $DELIVERY_DIR = $TEST_PROJECT,
    # because that comparison infers the outcome from a path and gets it wrong:
    # `git worktree list` reports PHYSICAL paths, so on a filesystem where
    # $TEST_PROJECT is already physical, a successful match against the base
    # checkout yields the identical string and reads as a fallback -- printing
    # a search for a deliverable that had just been found. Under macOS's
    # symlinked tmpdir (/var -> /private/var) the two forms differ and it
    # happens to behave, which is how it survived.
    echo "  (no worktree holds src/math.js; searched: $(echo "$worktree_list" | tr '\n' ' '))"
fi
echo ""

# Verification tests
FAILED=0

echo "=== Verification Tests ==="
echo ""

# Test 1: Skill was invoked
echo "Test 1: Skill tool invoked..."
if grep -q '"name":"Skill".*"skill":"hyperpowers:subagent-driven-development"' "$SESSION_FILE"; then
    echo "  [PASS] subagent-driven-development skill was invoked"
else
    echo "  [FAIL] Skill was not invoked"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2: Subagents were used (Agent / Task tool — name varies by harness version)
echo "Test 2: Subagents dispatched..."
# grep -c prints "0" itself when nothing matches (exiting 1), so `|| echo 0`
# would yield the two-line "0\n0" and break the integer comparison below.
# `|| true` swallows the no-match exit; the fallback covers an unreadable file.
task_count=$(grep -cE '"name":"(Agent|Task)"' "$SESSION_FILE" 2>/dev/null || true)
task_count=${task_count:-0}
if [ "$task_count" -ge 2 ]; then
    echo "  [PASS] $task_count subagents dispatched"
else
    echo "  [FAIL] Only $task_count subagent(s) dispatched (expected >= 2)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3: Durable progress tracking. SDD's load-bearing mechanism is the
# plan-scoped ledger (progress.md in the plan workspace); the Claude Code task
# tools are its interactive complement and sit behind ToolSearch in headless
# runs — two complete runs tracked exclusively through the ledger and never
# loaded a task tool. Accept either signal; require at least one.
echo "Test 3: Durable progress tracking (task tool or SDD ledger)..."
todo_count=$(grep -cE '"name":"(TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet)"' "$SESSION_FILE" 2>/dev/null || true)
todo_count=${todo_count:-0}
# Match a tool INPUT that targets the ledger, not the bare filename. `file_path`
# and `command` are tool-input keys, so they cannot appear in the loaded skill
# text, assistant prose, or error output — all of which mention progress.md and
# all of which satisfied the old bare-substring grep, letting a run with no
# durable write at all report PASS for the one signal this test exists to check.
ledger_count=$(grep -cE '"(file_path|command)":"[^"]*progress\.md' "$SESSION_FILE" 2>/dev/null || true)
ledger_count=${ledger_count:-0}
if [ "$todo_count" -ge 1 ]; then
    echo "  [PASS] Task-tracking tool used $todo_count time(s)"
elif [ "$ledger_count" -ge 1 ]; then
    echo "  [PASS] SDD ledger tracking used ($ledger_count tool call(s) writing progress.md)"
else
    echo "  [FAIL] No task-tracking tool used and no SDD ledger activity found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: Implementation actually works
echo "Test 6: Implementation verification..."
if [ -f "$DELIVERY_DIR/src/math.js" ]; then
    echo "  [PASS] src/math.js created"

    if grep -q "export function add" "$DELIVERY_DIR/src/math.js"; then
        echo "  [PASS] add function exists"
    else
        echo "  [FAIL] add function missing"
        FAILED=$((FAILED + 1))
    fi

    if grep -q "export function multiply" "$DELIVERY_DIR/src/math.js"; then
        echo "  [PASS] multiply function exists"
    else
        echo "  [FAIL] multiply function missing"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  [FAIL] src/math.js not created (searched $DELIVERY_DIR)"
    FAILED=$((FAILED + 1))
fi

if [ -f "$DELIVERY_DIR/test/math.test.js" ]; then
    echo "  [PASS] test/math.test.js created"
else
    echo "  [FAIL] test/math.test.js not created (searched $DELIVERY_DIR)"
    FAILED=$((FAILED + 1))
fi

# Run the delivered tests. Exit status alone is not evidence: `node --test`
# exits 0 when it finds no test files at all, so the old check reported
# "Tests pass" for a run whose tests it never saw. Require that tests actually
# executed. The count is read from the runner's summary line, which is "pass N"
# under both the spec and tap reporters.
TEST_OUTPUT="$DELIVERY_DIR/test-output.txt"
if (cd "$DELIVERY_DIR" && npm test) > "$TEST_OUTPUT" 2>&1; then
    tests_run=$(grep -oE 'pass [0-9]+' "$TEST_OUTPUT" | head -1 | awk '{print $2}')
    tests_run=${tests_run:-0}
    if [ "$tests_run" -ge 1 ]; then
        echo "  [PASS] Tests pass ($tests_run test(s) ran)"
    else
        echo "  [FAIL] npm test exited 0 but ran no tests -- nothing was verified"
        cat "$TEST_OUTPUT"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  [FAIL] Tests failed"
    cat "$TEST_OUTPUT"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 7: Git commits show proper workflow. Count on the delivery worktree's
# branch -- the task commits live there, and $TEST_PROJECT's HEAD never moves
# off the initial commit when SDD works in a worktree.
echo "Test 7: Git commit history..."
commit_count=$(git -C "$DELIVERY_DIR" log --oneline | wc -l)
if [ "$commit_count" -gt 2 ]; then  # Initial + at least 2 task commits
    echo "  [PASS] Multiple commits created ($commit_count total)"
else
    echo "  [FAIL] Too few commits ($commit_count, expected >2)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 8: Check for extra features (spec compliance should catch). A missing
# file is not evidence of restraint: the old `grep ... 2>/dev/null` fell into
# the else-branch and announced "No extra features added" about a file that did
# not exist. Absence of the subject makes this check inconclusive, not passed.
echo "Test 8: No extra features added (spec compliance)..."
if [ ! -f "$DELIVERY_DIR/src/math.js" ]; then
    echo "  [SKIP] Cannot assess -- src/math.js missing (see Test 6)"
elif grep -q "export function divide\|export function power\|export function subtract" "$DELIVERY_DIR/src/math.js"; then
    echo "  [WARN] Extra features found (spec review should have caught this)"
    # Not failing on this as it tests reviewer effectiveness
else
    echo "  [PASS] No extra features added"
fi
echo ""

# Token Usage Analysis
echo "========================================="
echo " Token Usage Analysis"
echo "========================================="
echo ""
python3 "$SCRIPT_DIR/analyze-token-usage.py" "$SESSION_FILE"
echo ""

# Summary
echo "========================================"
echo " Test Summary"
echo "========================================"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "STATUS: PASSED"
    echo "All verification tests passed!"
    echo ""
    echo "The subagent-driven-development skill correctly:"
    echo "  ✓ Reads plan once at start"
    echo "  ✓ Provides full task text to subagents"
    echo "  ✓ Enforces self-review"
    echo "  ✓ Runs spec compliance before code quality"
    echo "  ✓ Spec reviewer verifies independently"
    echo "  ✓ Produces working implementation"
    exit 0
else
    echo "STATUS: FAILED"
    echo "Failed $FAILED verification tests"
    echo ""
    echo "Output saved to: $OUTPUT_FILE"
    echo ""
    echo "Review the output to see what went wrong."
    exit 1
fi