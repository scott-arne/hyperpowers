#!/usr/bin/env bash
# The re-read-after-compaction paragraph must exist in SDD and brainstorming
# and must end well inside the first 20,000 characters, which is what Claude
# Code keeps when it re-attaches a skill after a compaction.
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

check "$SDD" "Before resuming work after any compaction, Read this file in full, then the ledger, along with any other skill you are following whose re-attached copy is cut short." "## When to Use" "SDD re-read paragraph present, early, before When to Use"
check "$BRAIN" "Before resuming work after any compaction, Read this file in full, along with any other skill you are following whose re-attached copy is cut short." "## Three Paths" "brainstorming re-read paragraph present, early, before Three Paths"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
