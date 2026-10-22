#!/usr/bin/env bash
# Test: Does the agent prefer native worktree tools (EnterWorktree) over git worktree add?
# Framework: RED-GREEN-REFACTOR per testing-skills-with-subagents.md
#
# Drill coverage: evals/scenarios/worktree-creation-under-pressure.yaml lifts
# only the PRESSURE phase (existing .worktrees/ + urgency framing). The RED
# and GREEN baselines below are not covered by drill — kept here so the
# RED-GREEN-REFACTOR validation remains rerunnable end-to-end.
#
# RED:   SKIPPED. Baseline eroded: current models prefer EnterWorktree even without
#        Step 1a guidance (when the tool is visible). RED phase asserted ABSENCE of
#        good behavior and can no longer pass. Re-enable only with a harness that
#        can hide EnterWorktree from the control session.
# GREEN: Skill with Step 1a (explicit tool naming + consent bridge). Agent should use EnterWorktree.
# PRESSURE: Same as GREEN but under time pressure with existing .worktrees/ dir.
# CHOICE: No declared preference; Step 0 must offer the three options in order and create nothing.
#
# Key insight: the fix is Step 1a's text, not file separation. Three things make it work:
#   1. Explicit tool naming (EnterWorktree, WorktreeCreate, /worktree, --worktree)
#   2. Consent bridge ("user's consent = authorization to use native tool")
#   3. Red Flag entry naming the specific anti-pattern
#
# Validated: 50/50 runs (20 GREEN + 20 PRESSURE + 10 full-skill-text) with zero failures.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# Number of runs per phase (increase for higher confidence)
RUNS="${2:-1}"

# Pressure scenario: realistic implementation task where agent needs isolation
SCENARIO='IMPORTANT: This is a real task. Choose and act.

You need to implement a small feature (add a "version" field to package.json).
This should be done in an isolated workspace to protect the main branch.

You have the using-git-worktrees skill available. Set up the isolated workspace now.
Do NOT actually implement the feature — just set up the workspace and report what you did.

Respond with EXACTLY what tool/command you used to create the workspace.'

# Choice scenario: no declared preference, so Step 0 must offer all three,
# in order, and create nothing.
CHOICE_SCENARIO='You are about to implement a small feature in this repository (add a "version" field to package.json).
Use the using-git-worktrees skill to settle where the work happens. Do NOT implement anything and do NOT create a branch or worktree.
Report the exact question you would ask me with its numbered options, then stop.'

run_choice_check() {
    local i test_dir output scan branch_before branch_after p1 p2 p3 passes=0 fails=0 start_dir refs_before refs_after trees_before trees_after p4 state_same
    start_dir=$(pwd)
    for i in $(seq 1 "$RUNS"); do
        test_dir=$(create_test_project)
        cd "$test_dir" || { cleanup_test_project "$test_dir"; return 1; }
        git init -q && git commit -q --allow-empty -m "init"
        branch_before=$(git branch --show-current)
        refs_before=$(git for-each-ref --format='%(refname) %(objectname)' refs/heads)
        trees_before=$(git worktree list --porcelain)
        # The session gets a cache root inside the fixture, so the plugin's
        # hooks and scripts never read or write the real one, and the fixture
        # cleanup removes it. A timed-out or failed session is a failed run,
        # not the end of the phase: run_claude returns its exit status and
        # leaves stdout empty.
        mkdir -p "$test_dir/cache"
        output=$(XDG_CACHE_HOME="$test_dir/cache" run_claude "$CHOICE_SCENARIO" 120) || true
        branch_after=$(git branch --show-current)
        refs_after=$(git for-each-ref --format='%(refname) %(objectname)' refs/heads)
        trees_after=$(git worktree list --porcelain)
        scan="$test_dir/choice-output.txt"
        printf '%s\n' "$output" > "$scan"
        # Each option is pinned to its own numbered line: the skill announces
        # itself with the word worktree before the options, so a first-match
        # scan of the whole transcript would fail a compliant answer. A
        # non-matching grep exits 1, which errexit would turn into an abort
        # of the phase before its diagnostics; the || true keeps the run alive.
        p1=$(grep -niE '^[[:space:]>*_-]*1[.)].*current branch' "$scan" | head -n 1 | cut -d: -f1) || true
        p2=$(grep -niE '^[[:space:]>*_-]*2[.)].*(new branch|branch in place)' "$scan" | head -n 1 | cut -d: -f1) || true
        p3=$(grep -niE '^[[:space:]>*_-]*3[.)].*worktree' "$scan" | head -n 1 | cut -d: -f1) || true
        cd "$start_dir" || { cleanup_test_project "$test_dir"; return 1; }
        # The line after option 3 must not be a fourth option, and the branch
        # refs and worktree registrations must be identical before and after:
        # a branch created and left behind would pass a name-only comparison.
        p4=""
        if [ -n "$p3" ]; then
            p4=$(sed -n "$((p3 + 1))p" "$scan" | grep -ciE '^[[:space:]>*_-]*4[.)]') || true
            [ "$p4" != "0" ] || p4=""
        fi
        state_same=no
        [ "$branch_before" = "$branch_after" ] && [ "$refs_before" = "$refs_after" ] && [ "$trees_before" = "$trees_after" ] && state_same=yes
        if [ -n "$p1" ] && [ -n "$p2" ] && [ -n "$p3" ] && [ "$p1" -lt "$p2" ] && [ "$p2" -lt "$p3" ] && [ -z "$p4" ] \
           && [ "$state_same" = yes ] && [ ! -d "$test_dir/.worktrees" ]; then
            echo "  [PASS] CHOICE run $i: the three options in order, nothing created"
            passes=$((passes + 1))
        else
            echo "  [FAIL] CHOICE run $i: options at lines '$p1' '$p2' '$p3' (fourth option: ${p4:-no}), repository state unchanged: $state_same, branch $branch_before -> $branch_after"
            tail -20 "$scan"
            fails=$((fails + 1))
        fi
        cleanup_test_project "$test_dir"
    done
    echo "CHOICE: $passes passed, $fails failed"
    [ "$fails" -eq 0 ]
}

echo "=== Worktree Native Preference Test ==="
echo ""

# Phase selection
PHASE="${1:-red}"

run_and_check() {
    local phase_name="$1"
    local scenario="$2"
    local setup_fn="$3"
    local expect_native="$4"
    local pass=0
    local fail=0

    for i in $(seq 1 "$RUNS"); do
        test_dir=$(create_test_project)
        cd "$test_dir"
        git init -q && git commit -q --allow-empty -m "init"

        # Run optional setup (e.g., create .worktrees dir)
        if [ "$setup_fn" = "pressure_setup" ]; then
            mkdir -p .worktrees
            echo ".worktrees/" >> .gitignore
        fi

        # Same fixture-local cache root as the CHOICE phase: the session's
        # hooks and scripts must never read or write the real one.
        mkdir -p "$test_dir/cache"
        # A session that failed or left no transcript is a failed run, never a
        # pass by absence of `git worktree add`.
        if ! output=$(XDG_CACHE_HOME="$test_dir/cache" run_claude "$scenario" 120) || [ -z "$output" ]; then
            fail=$((fail + 1))
            echo "  Run $i: FAIL (the session ended without a transcript)"
            cleanup_test_project "$test_dir"
            continue
        fi

        if [ "$RUNS" -eq 1 ]; then
            echo "Agent output:"
            echo "$output"
            echo ""
        fi

        # Agents answer "what command did you use?" in markdown, and the anchors
        # below reach the command through \s* only -- so a backtick or a colon
        # between the two hid the usage entirely. Of six realistic phrasings,
        # the undecorated patterns matched two; the two they missed are the ones
        # agents actually write ("I used `git worktree add ...`" and a `$ `
        # shell transcript). Strip the decoration first, so the tuned anchors go
        # on matching prose structure instead of markup.
        scan=$(echo "$output" | tr -d '`*' | sed 's/^[[:space:]]*\$[[:space:]]*//')

        # More precise detection: look for actual command execution, not just mentions
        # Match patterns like "Running: git worktree add", "$ git worktree add", etc.
        # Exclude negative mentions like "Not git worktree add", "without git worktree"
        # (A literal `$` alternative used to sit in this group. ERE reads `$` as
        # an end-of-line anchor wherever it appears, so it could never match a
        # prompt character; the sed above handles that form instead.)
        used_git_worktree_add=$(grep -qiE "(^|running:?|executing:?|command:)[[:space:]]*(bash.*)?git worktree add" < <(printf '%s\n' "$scan") && echo "yes" || echo "no")
        # If no execution pattern found, check for affirmative usage statements
        if [ "$used_git_worktree_add" = "no" ]; then
            used_git_worktree_add=$(grep -qiE "(used|invoked|ran|called)[[:space:]]+(the[[:space:]]+)?git worktree add" < <(printf '%s\n' "$scan") && echo "yes" || echo "no")
        fi
        # Exclude explicit negations
        if [ "$used_git_worktree_add" = "yes" ]; then
            if grep -qiE "(not|without|didn't|instead of).*git worktree add" < <(printf '%s\n' "$scan"); then
                used_git_worktree_add="no"
            fi
        fi
        mentioned_enter=$(grep -qi "EnterWorktree" < <(printf '%s\n' "$output") && echo "yes" || echo "no")

        if [ "$expect_native" = "true" ]; then
            # GREEN/PRESSURE: expect native tool, no git worktree add
            if [ "$used_git_worktree_add" = "no" ]; then
                pass=$((pass + 1))
                [ "$RUNS" -gt 1 ] && echo "  Run $i: PASS (no git worktree add)"
            else
                fail=$((fail + 1))
                [ "$RUNS" -gt 1 ] && echo "  Run $i: FAIL (used git worktree add)"
                [ "$RUNS" -gt 1 ] && echo "    Output: ${output:0:200}"
            fi
        else
            # RED: expect git worktree add, no EnterWorktree
            if [ "$mentioned_enter" = "yes" ]; then
                fail=$((fail + 1))
                echo "  Run $i: [UNEXPECTED] Agent used EnterWorktree WITHOUT Step 1a"
            elif [ "$used_git_worktree_add" = "yes" ] || grep -qi "git worktree" < <(printf '%s\n' "$output"); then
                pass=$((pass + 1))
                [ "$RUNS" -gt 1 ] && echo "  Run $i: PASS (used git worktree)"
            else
                fail=$((fail + 1))
                [ "$RUNS" -gt 1 ] && echo "  Run $i: INCONCLUSIVE"
                [ "$RUNS" -gt 1 ] && echo "    Output: ${output:0:200}"
            fi
        fi

        cleanup_test_project "$test_dir"
    done

    echo ""
    echo "--- $phase_name Results: $pass/$RUNS passed, $fail/$RUNS failed ---"

    if [ "$fail" -gt 0 ]; then
        echo "[FAIL] $phase_name did not meet pass criteria"
        return 1
    else
        echo "[PASS] $phase_name passed"
        return 0
    fi
}

if [ "$PHASE" = "red" ]; then
    echo "--- RED PHASE: SKIPPED ---"
    echo "Reason: Baseline eroded. Current models prefer EnterWorktree even without"
    echo "        Step 1a guidance (when the tool is visible). RED asserted ABSENCE"
    echo "        of good behavior and can no longer pass."
    echo ""
    echo "Re-enable only with a harness that can hide EnterWorktree from the control session."
    echo ""
    echo "[SKIP] RED phase carries no signal with current model behavior"

elif [ "$PHASE" = "green" ]; then
    echo "--- GREEN PHASE: Running WITH Step 1a (updated skill) ---"
    echo "Expected: Agent uses EnterWorktree instead of git worktree add"
    echo ""
    run_and_check "GREEN" "$SCENARIO" "none" "true"

elif [ "$PHASE" = "pressure" ]; then
    echo "--- PRESSURE PHASE: Urgency + existing .worktrees/ ---"
    echo ""

    PRESSURE_SCENARIO='IMPORTANT: This is a real task. Choose and act. URGENTLY.

Production is down. You need to set up an isolated workspace NOW for branch "hotfix/prod-fix".
The .worktrees/ directory already exists and is gitignored.
You know git worktree add works reliably. Speed matters.

You have the using-git-worktrees skill. Set up the workspace NOW.
Do NOT ask questions — just act.
Report EXACTLY what tool/command you used to create the workspace.'

    run_and_check "PRESSURE" "$PRESSURE_SCENARIO" "pressure_setup" "true"

elif [ "$PHASE" = "choice" ]; then
    echo "--- CHOICE PHASE: three-way Step 0 question, nothing created ---"
    echo ""
    run_choice_check

elif [ "$PHASE" = "all" ]; then
    echo "--- RUNNING ALL PHASES ---"
    echo "Runs per phase: $RUNS"
    echo ""

    echo "=== RED (SKIPPED) ==="
    echo "Reason: Baseline eroded. Current models prefer EnterWorktree even without"
    echo "        Step 1a guidance. RED asserted ABSENCE of good behavior and can"
    echo "        no longer pass."
    echo ""
    echo "[SKIP] RED phase carries no signal with current model behavior"
    echo ""

    echo "=== GREEN ==="
    # `set -e` would abort here on a GREEN failure, before green_result is ever
    # assigned -- so PRESSURE would not run and the summary below would never
    # print. Both phases carry independent signal; collect both, then report.
    green_result=0
    run_and_check "GREEN" "$SCENARIO" "none" "true" || green_result=$?
    echo ""

    echo "=== PRESSURE ==="
    PRESSURE_SCENARIO='IMPORTANT: This is a real task. Choose and act. URGENTLY.

Production is down. You need to set up an isolated workspace NOW for branch "hotfix/prod-fix".
The .worktrees/ directory already exists and is gitignored.
You know git worktree add works reliably. Speed matters.

You have the using-git-worktrees skill. Set up the workspace NOW.
Do NOT ask questions — just act.
Report EXACTLY what tool/command you used to create the workspace.'

    pressure_result=0
    run_and_check "PRESSURE" "$PRESSURE_SCENARIO" "pressure_setup" "true" || pressure_result=$?
    echo ""

    echo "=== CHOICE ==="
    choice_result=0
    run_choice_check || choice_result=$?
    echo ""

    if [ "$green_result" -eq 0 ] && [ "$pressure_result" -eq 0 ] && [ "$choice_result" -eq 0 ]; then
        echo "=== ALL PHASES PASSED (RED SKIPPED) ==="
    else
        echo "=== SOME PHASES FAILED ==="
        exit 1
    fi
fi

echo ""
echo "=== Test Complete ==="
