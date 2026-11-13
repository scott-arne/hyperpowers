#!/usr/bin/env bash
# SDD's step text lives in five files beside SKILL.md. Each must stay small
# enough to re-read whole in one Read after a compaction, SKILL.md must link
# each one, and every relative link in the skill's files must resolve from
# the file that holds it.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD_DIR="$REPO_ROOT/skills/subagent-driven-development"
STEPS="setup.md task-loop.md review-and-complete.md fix-loop.md final-and-finish.md"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# chars FILE: length in characters (code points), the unit of Claude Code's
# 20,000-character re-attach cut.
chars() { node -e 'console.log([...require("fs").readFileSync(process.argv[1], "utf8")].length)' "$1"; }

for f in $STEPS; do
  p="$SDD_DIR/$f"
  if [ ! -f "$p" ]; then fail "$f exists"; continue; fi
  n="$(chars "$p")"
  if [ "$n" -lt 17000 ]; then pass "$f is under 17,000 characters ($n)"; else fail "$f is under 17,000 characters ($n)"; fi
  if grep -Fq "]($f)" "$SDD_DIR/SKILL.md"; then pass "SKILL.md links $f"; else fail "SKILL.md links $f"; fi
done

for f in SKILL.md $STEPS; do
  p="$SDD_DIR/$f"
  [ -f "$p" ] || continue
  missing="$(node -e '
    const fs = require("fs"), path = require("path");
    const file = process.argv[1], dir = path.dirname(file);
    const bad = [];
    for (const m of fs.readFileSync(file, "utf8").matchAll(/\]\(([^)\s#]+)(#[^)]*)?\)/g)) {
      if (/^[a-z]+:/i.test(m[1])) continue;
      if (!fs.existsSync(path.resolve(dir, m[1]))) bad.push(m[1]);
    }
    console.log(bad.join(" "));
  ' "$p")"
  if [ -z "$missing" ]; then pass "$f links resolve"; else fail "$f links resolve (missing: $missing)"; fi
done

echo
if [ "$FAILURES" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "$FAILURES FAILURES"; exit 1; fi
