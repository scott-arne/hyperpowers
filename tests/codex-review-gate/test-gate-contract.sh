#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE="$REPO_ROOT/skills/requesting-code-review/codex-review-gate.md"
BRAINSTORMING="$REPO_ROOT/skills/brainstorming/SKILL.md"
WRITING_PLANS="$REPO_ROOT/skills/writing-plans/SKILL.md"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
REQUESTING_REVIEW="$REPO_ROOT/skills/requesting-code-review/SKILL.md"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

assert_contains() {
  local file="$1"
  local needle="$2"
  local description="$3"
  local haystack

  haystack="$(tr '\n\t' '  ' <"$file" | sed 's/  */ /g')"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    pass "$description"
  else
    fail "$description"
    echo "    expected to find: $needle"
    echo "    in: $file"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local description="$3"
  local haystack

  haystack="$(tr '\n\t' '  ' <"$file" | sed 's/  */ /g')"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    fail "$description"
    echo "    did not expect to find: $needle"
    echo "    in: $file"
  else
    pass "$description"
  fi
}

echo "Codex review gate contract tests"

assert_contains "$GATE" "## 3. Invoke Codex by artifact type" \
  "shared gate has artifact-specific invocation recipes"
assert_contains "$GATE" "**Spec documents**" \
  "shared gate has a spec document recipe"
assert_contains "$GATE" "**Plan documents**" \
  "shared gate has a plan document recipe"
assert_contains "$GATE" "<SPEC_ABSOLUTE_PATH>" \
  "plan recipe requires the source spec path"
assert_contains "$GATE" "<PLAN_ABSOLUTE_PATH>" \
  "plan recipe requires the plan path"
assert_contains "$GATE" "**Per-task code**" \
  "shared gate has a per-task code recipe"
assert_contains "$GATE" "<TASK_BRIEF_PATH>" \
  "per-task recipe requires task brief context"
assert_contains "$GATE" "<IMPLEMENTER_REPORT_PATH>" \
  "per-task recipe requires implementer report context"
assert_contains "$GATE" "<REVIEW_PACKAGE_PATH>" \
  "per-task recipe requires review package context"
assert_contains "$GATE" "<GLOBAL_CONSTRAINTS_PATH>" \
  "per-task recipe requires global constraints context"
assert_contains "$GATE" "**Final whole-branch code**" \
  "shared gate has a final whole-branch recipe"
assert_contains "$GATE" "<BRANCH_REVIEW_PACKAGE_PATH>" \
  "final recipe requires the branch review package"

assert_contains "$GATE" "### Required document-review output" \
  "document review output is explicitly structured"
assert_contains "$GATE" "Copy the Required document-review output block below into the prompt" \
  "document review prompts include the output schema in Codex context"
assert_contains "$GATE" "Cannot verify" \
  "document review output includes cannot-verify items"
assert_contains "$GATE" "line references" \
  "document review output asks for evidence"

assert_contains "$GATE" "After any code fix, re-run the same Claude reviewer gate before re-running Codex." \
  "code fix loop requires Claude re-review before Codex re-review"

# --- Task 1: convergence loop + per-gate backstops + round ledger ---
assert_contains "$GATE" "### Round ledger (re-review memory)" \
  "gate defines a round ledger for re-review memory"
assert_contains "$GATE" "no new blocking findings" \
  "gate defines a convergence stop-rule"
assert_contains "$GATE" "Document gates get 4 rounds" \
  "gate sets the document-gate backstop to 4 rounds"
assert_contains "$GATE" "Code gates get 3 rounds" \
  "gate sets the code-gate backstop to 3 rounds"
assert_not_contains "$GATE" "## 5. Fix-and-re-review loop (cap = 2 rounds)" \
  "gate no longer uses the single 2-round cap heading"

assert_contains "$SDD" "After any Codex-triggered code fix, re-run the task reviewer before re-running the per-task Codex gate." \
  "SDD per-task loop names Claude re-review order"
assert_contains "$SDD" "After any Codex-triggered final-review fix, re-run the final code-reviewer before re-running the final Codex gate." \
  "SDD final loop names Claude re-review order"
assert_contains "$REQUESTING_REVIEW" "After any Codex-triggered code fix, re-run the Claude code-reviewer before re-running Codex." \
  "requesting-code-review loop names Claude re-review order"

# --- Task 2: completion check (incomplete is not approval) ---
assert_contains "$GATE" "## 4b. Completion check — incomplete is not approval" \
  "gate has a completion-check section"
assert_contains "$GATE" "incomplete is not approval" \
  "gate states incomplete is not approval"
assert_contains "$GATE" "foreground-only" \
  "completion check is grounded in the foreground-only review path"
assert_contains "$GATE" "There is no background path for code gates" \
  "gate states there is no background path for code gates"
assert_contains "$GATE" "600000 ms (10 minutes)" \
  "completion check pins a concrete review timeout"
assert_contains "$GATE" ".storedJob.result.result" \
  "completion check pins the concrete result JSON field"

assert_contains "$BRAINSTORMING" "using the spec recipe" \
  "brainstorming points at the spec-specific recipe"
assert_contains "$WRITING_PLANS" "using the plan recipe" \
  "writing-plans points at the plan-specific recipe"
assert_contains "$WRITING_PLANS" "the source spec path and the plan path" \
  "writing-plans requires both source spec and plan paths"
assert_contains "$SDD" "using the per-task code recipe" \
  "SDD points per-task gates at the per-task recipe"
assert_contains "$SDD" "using the final whole-branch code recipe" \
  "SDD points final gate at the final recipe"
assert_contains "$REQUESTING_REVIEW" "using the code-review recipe" \
  "requesting-code-review points at the code-review recipe"

assert_not_contains "$GATE" "Read Codex's free-form reply and extract its verdict and findings." \
  "document review no longer relies on free-form extraction"

# --- Task 3: §3 references the round-aware preamble; hand-back reports exit reason + incompletion ---
assert_contains "$GATE" "On a re-review (round 2+), prepend the round-aware preamble from §5" \
  "§3 recipes point at the §5 round-aware re-review preamble"
assert_contains "$GATE" "whether the loop exited by convergence or by hitting the backstop" \
  "hand-back reports the loop exit reason"
assert_contains "$GATE" "whether an incomplete result occurred" \
  "hand-back reports incompletion"

# --- Task 4: SDD references new caps + completion Red Flag ---
assert_contains "$SDD" "code-gate backstop of 3 rounds" \
  "SDD names the code-gate backstop of 3 rounds"
assert_contains "$SDD" "Treat an unfinished or \"still verifying\" Codex result as approval" \
  "SDD Red Flags echo the incomplete-is-not-approval rule"

# --- Task 5: caller skills reference the new contract ---
assert_contains "$BRAINSTORMING" "document-gate backstop of 4 rounds" \
  "brainstorming names the document-gate backstop"
assert_contains "$WRITING_PLANS" "document-gate backstop of 4 rounds" \
  "writing-plans names the document-gate backstop"
assert_contains "$REQUESTING_REVIEW" "Incomplete Codex results are never treated as approval" \
  "requesting-code-review names the completion contract"

# --- Final-review fix: convergence forbidden while a blocker is still open ---
assert_contains "$GATE" "only if the round ledger has no still-open blocking findings" \
  "convergence requires the ledger to have no still-open blockers"

if [ "$FAILURES" -gt 0 ]; then
  echo "STATUS: FAILED ($FAILURES failure(s))"
  exit 1
fi

echo "STATUS: PASSED"
