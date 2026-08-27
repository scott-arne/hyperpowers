#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
SDD_MODEL_SELECTION="$REPO_ROOT/skills/subagent-driven-development/model-selection.md"
SDD_RISK_TIERS="$REPO_ROOT/skills/subagent-driven-development/risk-tiers.md"
SDD_RATIONALIZATIONS="$REPO_ROOT/skills/subagent-driven-development/common-rationalizations.md"
IMPL="$REPO_ROOT/skills/subagent-driven-development/implementer-prompt.md"
REVW="$REPO_ROOT/skills/subagent-driven-development/task-reviewer-prompt.md"
FIXP="$REPO_ROOT/skills/subagent-driven-development/fix-subagent-prompt.md"
REREVW="$REPO_ROOT/skills/subagent-driven-development/re-review-prompt.md"
WPLANS="$REPO_ROOT/skills/writing-plans/SKILL.md"

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

echo "SDD prompt-surface contract tests"
# SKILL.md — dispatch discipline
assert_contains "$SDD_MODEL_SELECTION" "Always specify the model explicitly when dispatching a subagent." "explicit model is mandatory"
assert_contains "$SDD" "A dispatch prompt describes one task, not the session's history." "no pasted-history dispatches"
assert_contains "$SDD" "which silently drops all but the last commit" "BASE not HEAD~1 (review package)"
assert_contains "$SDD" "which silently truncates multi-commit tasks" "BASE not HEAD~1 (reviewer handoff)"
# SKILL.md — verify-subagent-claims (6.6.0)
assert_contains "$SDD" "Subagent reports are claims, not evidence" "verify rule exists"
assert_contains "$SDD" "re-runs the named covering test command directly" "controller re-runs covering tests"
assert_contains "$SDD" "no covering command:" "no-test path exists"
assert_contains "$SDD" "fix-subagent-prompt.md" "fix dispatches use the template"
assert_contains "$SDD" "DONE or DONE_WITH_CONCERNS" "concerns status does not bypass the verify rule"
# implementer template
assert_contains "$IMPL" "DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT" "four statuses"
assert_contains "$IMPL" "RED: command run" "TDD red evidence"
assert_contains "$IMPL" "GREEN: command run" "TDD green evidence"
assert_contains "$IMPL" "under 15 lines" "terse return contract"
assert_contains "$IMPL" "Write your full report to" "report-file contract"
assert_contains "$IMPL" "The controller re-runs your covering command" "implementer rerun warning"
assert_contains "$IMPL" "Covering command(s):" "implementer dispatches carry the covering-command slot"
# reviewer template
assert_contains "$REVW" "## Part 1: Spec Compliance" "reviewer spec part"
assert_contains "$REVW" "## Part 2: Code Quality" "reviewer quality part"
assert_contains "$REVW" "Cannot verify from diff" "cannot-verify semantics"
# fixer template
assert_contains "$FIXP" "stage ONLY the files named in this dispatch" "fixer stages only named files"
assert_contains "$FIXP" 'NEVER `git add -A`' "fixer never adds all"
assert_contains "$FIXP" "no covering command:" "fixer no-test path"
assert_contains "$FIXP" "APPEND your fix note" "fixer appends to the task report"
assert_contains "$FIXP" "The controller re-runs your covering command" "fixer rerun warning"
assert_contains "$FIXP" "the final whole-branch review wave" "fixer template serves final waves"
assert_contains "$FIXP" "the exact covering command(s) run with their final output lines" \
  "fix reports carry command plus output"
assert_contains "$FIXP" "run them in a scratch directory" "fixture scripts stay out of real checkouts"
# re-reviewer template
assert_contains "$REREVW" "ADDRESSED" "re-review verdict: addressed"
assert_contains "$REREVW" "NOT ADDRESSED" "re-review verdict: not addressed"
assert_contains "$REREVW" "review-package PLAN_FILE FIX_BASE HEAD" "re-review review-package handoff"
assert_contains "$REREVW" "You Do Not Dispatch Subagents" "re-review no-dispatch discipline"
# tier system (6.6.0)
assert_contains "$WPLANS" '**Risk tier:** low|standard|high — <one-line rationale>' "plans declare a tier per task"
assert_contains "$WPLANS" "approval-authority code" "rubric names the high surface"
assert_contains "$WPLANS" "declared risk tier against the rubric" "plan gate reviews tiers"
assert_contains "$WPLANS" "the reviewer is stateless and cannot load this skill" \
  "rubric is delivered to the plan gate"
assert_contains "$SDD_RISK_TIERS" "may raise a tier" "escalation is expressible"
assert_contains "$SDD_RISK_TIERS" "never lower a declared tier" "lowering is not expressible"
assert_contains "$SDD_RISK_TIERS" "tier declared" "escalation record line format"
assert_contains "$SDD_RISK_TIERS" "--class tier-skip" "skip appends the durable record"
assert_contains "$SDD" "tier-skips.md" "final review receives the skip list"
assert_contains "$SDD" "no escalation trigger fired" "skip precondition is explicit"
assert_contains "$SDD" "plan-gate-reviewed; no escalation trigger fired" "diagram skip path carries the full precondition"
assert_contains "$SDD_RISK_TIERS" "missing tier line" "fail-closed default is pinned"
assert_contains "$SDD" "gate dir:" "GATE_DIR is persisted in ledger"
assert_contains "$WPLANS" "unreviewed low tiers execute as standard" \
  "plan-gate skip demotes low tiers (authoring side)"
assert_contains "$SDD_RISK_TIERS" "unreviewed low tiers execute as standard" \
  "plan-gate skip demotes low tiers (dispatch side)"
assert_contains "$SDD_RISK_TIERS" "a demoted task runs the full train and records NO tier-skip event" \
  "demote path never writes a skip record"
assert_contains "$SDD" "Record tier-skip (ungated-ledger), skip Codex task gate" \
  "process diagram carries the skip path"
assert_contains "$WPLANS" "no escalation trigger fired at any point during execution" \
  "authoring rubric carries the strong escalation window"
# Finish section (6.6.0 deletion fix)
assert_contains "$SDD" "INCOMPLETE finish" "finish section labels incomplete finish"
assert_contains "$SDD" 'test ! -d' "real deletion assertion not vacuous ls"
assert_contains "$SDD_RATIONALIZATIONS" "stale-forensics trap" "rationalization names forensics trap"
# Stubs left behind by the 6.x reference-file extraction must keep the
# operative rules on the main path, not only behind the link.
assert_contains "$SDD" "A task skips the per-task Codex gate only when all three hold: declared low, the plan's own Codex gate actually reviewed the plan, and no escalation trigger fired at any point during execution." \
  "risk-tier stub pins all three skip preconditions, including plan-gate-reviewed"
assert_contains "$SDD" "That skip is recorded durably." \
  "risk-tier stub keeps the durable-record requirement"
assert_contains "$SDD" "An unreviewed low tier — plan gate skipped, degraded, or outcome unknown — executes as standard, and a task demoted that way runs the full train and records NO tier-skip event." \
  "risk-tier stub pins the demotion rule and that a demoted task records no tier-skip event"
assert_contains "$SDD" 'write `tier-skips.md` in this plan' \
  "risk-tier stub names the tier-skips.md producer that Final Review consumes"
assert_contains "$SDD" "The Claude task reviewer and the final whole-branch train never tier off." \
  "risk-tier stub pins that the Claude reviewer and final train never tier off"
assert_contains "$SDD" "read it before dispatching any task declared low" \
  "risk-tier stub routes low-tier dispatches to risk-tiers.md"
assert_contains "$SDD" "Read it the moment you catch yourself justifying a shortcut." \
  "rationalizations stub tells the agent when to read the reference"
assert_contains "$SDD" "always specify the model explicitly when dispatching a subagent" \
  "model-selection stub keeps the explicit-model rule on the main path"
assert_contains "$SDD" "a mid-tier model is the floor for reviewers" \
  "model-selection stub keeps the reviewer floor on the main path"
assert_contains "$SDD" "the floor for reviewers and for implementers working from prose descriptions" \
  "model-selection stub keeps the prose-implementer floor on the main path"
assert_contains "$SDD" "The cheapest tier is for transcription, where the task's own text carries the complete code to write, and for single-file mechanical fixes." \
  "model-selection stub keeps the cheap-tier exemption that pairs with the floor"

# The reference files the stubs point at must actually exist and carry their
# content. Without these, example-workflow.md or common-rationalizations.md
# could be deleted with every suite still green — the stubs in SKILL.md would
# keep asserting fine while pointing at nothing.
SDD_EXAMPLE_WORKFLOW="$REPO_ROOT/skills/subagent-driven-development/example-workflow.md"
if [ -f "$SDD_EXAMPLE_WORKFLOW" ]; then
  pass "example-workflow.md exists where its stub points"
else
  fail "example-workflow.md exists where its stub points"
fi
assert_contains "$SDD_EXAMPLE_WORKFLOW" "## Example Workflow" "example workflow carries its section header"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "Using hyperpowers:finishing-a-development-branch." \
  "example workflow runs through to the finishing handoff"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "implementer subagent-01f3 — recorded for fix-round resumes" \
  "example workflow records the implementer identity in the ledger"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "Task 2: implementer subagent-7c42 — recorded for fix-round resumes" \
  "example workflow records the identity on the task that enters the fix loop"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "Re-run the covering command myself: 8/8 — matches the report" \
  "example fix-loop task re-runs the covering command before review"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "Re-run the fix's covering command myself: 10/10 — matches the fix report" \
  "example fix report is re-run before the scoped re-review"
assert_contains "$SDD" "is a dispatch in flight: do not re-dispatch" \
  "resume rules consume the implementer-identity ledger state"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "Write tier-skips.md in this plan's workspace" \
  "example's low-tier skip writes the tier-skip summary"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "most capable model, with tier-skips.md" \
  "example hands tier-skips.md to the final review surfaces"
if [ -f "$SDD_RATIONALIZATIONS" ]; then
  pass "common-rationalizations.md exists where its stub points"
else
  fail "common-rationalizations.md exists where its stub points"
fi
assert_contains "$SDD_RATIONALIZATIONS" "Silent discards are forbidden." \
  "rationalizations reference keeps the no-silent-discard row"

# Ledger-anchoring needles (2026-08-25 attribution fixes). The ledger is the
# canonical tracker; todos mirror it where the harness surfaces them, the
# implementer identity is written into the ledger so compaction cannot orphan
# fix-round resumes, and a covering command that cannot fail is not evidence.
assert_contains "$SDD" "todos mirror it, never replace it" "ledger is canonical; todos are the mirror"
assert_contains "$SDD" "in the ledger's task entry" "implementer identity anchored to the ledger"
assert_contains "$SDD" "after compaction the ledger is the only place the identity survives" "identity survives compaction via the ledger"
assert_contains "$SDD" "A covering command must be able to fail." "vacuous covering commands are not evidence"

# De-minimis carve-out (2026-08-25). The exception must carry all three
# guardrails in text: the full-specification bound, the mandatory disclosure
# ledger line, and the two-strike escape back to a real dispatch. The
# rationalization row must scope itself to the exception rather than being
# silently weakened.
assert_contains "$SDD" "fully specified by the finding itself" "carve-out requires a fully-specified fix"
assert_contains "$SDD" "controller-applied (de minimis)" "carve-out requires the disclosure ledger line"
assert_contains "$SDD" "consumes a fix round and ends in the same scoped re-review" "carve-out waives neither the round nor the re-review"
assert_contains "$SDD" "Reaching for it twice in the same task means the findings are not de minimis" "carve-out two-strike rule"
assert_contains "$SDD" "applies the edit and runs the fix's covering command FIRST" \
  "carve-out verifies before committing"
assert_contains "$SDD" "controller-applied (de minimis) (<X> addressed, <Y> open" \
  "carve-out ledger line keeps the fix-round schema"
assert_contains "$SDD" "touching at most 3 lines in one file with no new logic" \
  "carve-out numeric and scope bounds are pinned"
assert_contains "$SDD" "one finding per reach; a round holding two such findings is not de minimis" \
  "carve-out forbids per-round multiplication"
assert_contains "$SDD" "then commits the verified fix" \
  "carve-out commits only a verified fix"
# The failure branch is the half the successful-commit needles cannot see: a
# failed covering command exits the exception, so it must revert, cost nothing,
# and hand control back round-aware — not unconditionally to the implementer
# the round-4/5 takeover rule has already replaced.
assert_contains "$SDD" "revert the edit, spend no round, and go back to the round's own rule" \
  "carve-out failure path reverts, spends no round, and defers to the round's rule"
assert_contains "$SDD" "resume the implementer at rounds 1-3, dispatch the takeover at rounds 4-5" \
  "carve-out two-strike escape respects the round-4 takeover rule"
assert_contains "$SDD" "or one controller-applied de-minimis fix" \
  "fix-round definition counts controller-applied fixes"
assert_contains "$SDD" "where you keep todos" \
  "completion line keeps todos conditional"
assert_contains "$SDD" "mark todo complete (where kept)" \
  "digraph todo node stays conditional"
assert_contains "$SDD_RATIONALIZATIONS" "Outside the de-minimis exception" "rationalization row scoped to the exception"
assert_contains "$SDD_RATIONALIZATIONS" "Resume the implementer at rounds 1-3; dispatch the takeover at rounds 4-5." "rationalization row defers to the round's own rule"

echo
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
