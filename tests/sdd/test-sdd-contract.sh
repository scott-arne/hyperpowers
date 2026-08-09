#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
IMPL="$REPO_ROOT/skills/subagent-driven-development/implementer-prompt.md"
REVW="$REPO_ROOT/skills/subagent-driven-development/task-reviewer-prompt.md"
FIXP="$REPO_ROOT/skills/subagent-driven-development/fix-subagent-prompt.md"
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
assert_contains "$SDD" "Always specify the model explicitly when dispatching a subagent." "explicit model is mandatory"
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
assert_contains "$IMPL" "the controller re-runs your covering command" "implementer rerun warning"
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
assert_contains "$FIXP" "the controller re-runs your covering command" "fixer rerun warning"
assert_contains "$FIXP" "the final whole-branch review wave" "fixer template serves final waves"
assert_contains "$FIXP" "the exact covering command(s) run with their final output lines" \
  "fix reports carry command plus output"
# tier system (6.6.0)
assert_contains "$WPLANS" '**Risk tier:** low|standard|high — <one-line rationale>' "plans declare a tier per task"
assert_contains "$WPLANS" "approval-authority code" "rubric names the high surface"
assert_contains "$WPLANS" "declared risk tier against the rubric" "plan gate reviews tiers"
assert_contains "$SDD" "may raise a tier" "escalation is expressible"
assert_contains "$SDD" "never lower a declared tier" "lowering is not expressible"
assert_contains "$SDD" "tier declared" "escalation record line format"
assert_contains "$SDD" "--class tier-skip" "skip appends the durable record"
assert_contains "$SDD" "tier-skips.md" "final review receives the skip list"
assert_contains "$SDD" "no escalation trigger fired" "skip precondition is explicit"
assert_contains "$SDD" "missing tier line" "fail-closed default is pinned"

echo
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
