#!/usr/bin/env bash
# The after-compaction paragraph must exist in SDD and brainstorming and must
# end well inside the first 20,000 characters, which is what Claude Code keeps
# when it re-attaches a skill after a compaction. SDD's SKILL.md stays whole
# after a compaction, so its paragraph sends the session to the one step file
# its step table names; brainstorming's paragraph still asks for a full Read.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
BRAIN="$REPO_ROOT/skills/brainstorming/SKILL.md"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# check FILE NEEDLE NEXT_HEADING LABEL: needle present, ends before 5,000
# characters, and sits before NEXT_HEADING.
check() {
  local file="$1" needle="$2" next="$3" label="$4" res
  res="$(node -e '
    const fs = require("fs");
    const s = fs.readFileSync(process.argv[1], "utf8");
    const i = s.indexOf(process.argv[2]);
    const h = s.indexOf(process.argv[3]);
    if (i < 0) { console.log("missing"); process.exit(0); }
    const end = i + process.argv[2].length;
    console.log(end <= 5000 && h > end ? "ok" : `bad end=${end} heading=${h}`);
  ' "$file" "$needle" "$next")"
  [ "$res" = "ok" ] && pass "$label" || fail "$label ($res)"
}

check "$SDD" "**After every context compaction:** this file fits within the 20,000 characters Claude Code re-attaches, so the copy you hold is whole. A step file you read before the compaction does not survive it. Before your next action, print the board and the ledger lines the step table names (your task's and your Setup's, never the whole ledger), find your step in the table, and Read that step file in full, along with any other skill you are following whose re-attached copy is cut short." "## When to Use" "SDD re-read paragraph present, early, before When to Use"
check "$BRAIN" "**After every context compaction:** Claude Code re-attaches this skill cut to its first 20,000 characters, which ends before the spec-writing steps, and a full Read you made before the compaction does not survive it. After each compaction, the first and every later one, Read this file in full before your next action (a question to your human partner, a visual-companion step, or writing the spec), along with any other skill you are following whose re-attached copy is cut short." "## Three Paths" "brainstorming re-read paragraph present, early, before Three Paths"

# contains FILE NEEDLE LABEL: fixed-string needle present (whitespace-folded).
contains() {
  local file="$1" needle="$2" label="$3"
  if tr '\n' ' ' < "$file" | tr -s ' ' | grep -qF -- "$needle"; then pass "$label"; else fail "$label"; fi
}
SDD_FIX="$REPO_ROOT/skills/subagent-driven-development/fix-loop.md"
SDD_FINAL="$REPO_ROOT/skills/subagent-driven-development/final-and-finish.md"
contains "$SDD" '| you ran `scripts/sdd-state finish` and it printed `finished`: the workspace is gone, and this row wins over every row below | none: do not run Setup and do not recreate the ledger; continue with hyperpowers:finishing-a-development-branch, from the hand-off message you sent (mode, plan, spec, decision extractor id and notes path, receipt path) |' "step table sends a finished workspace to the branch action, not Setup"
contains "$SDD_FINAL" 'after a compaction, that message is what you resume from' "Finish names the hand-off message as the resume point"
contains "$SDD_FIX" 'A task whose newest line is a `fix round` line, or a blocking `review` line after one, is mid-loop: resume the loop at the next round; a round whose `review` line approves goes on to the gate.' "fix-loop resumes mid-loop at the next round"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
