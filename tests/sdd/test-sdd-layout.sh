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

n="$(chars "$SDD_DIR/SKILL.md")"
if [ "$n" -lt 19000 ]; then pass "SKILL.md is under 19,000 characters ($n)"; else fail "SKILL.md is under 19,000 characters ($n)"; fi

# count FILE NEEDLE: occurrences of NEEDLE in FILE, whitespace-normalized.
count() {
  node -e '
    const fs = require("fs"), norm = (s) => s.replace(/\s+/g, " ");
    console.log(norm(fs.readFileSync(process.argv[1], "utf8")).split(norm(process.argv[2])).length - 1);
  ' "$1" "$2"
}

# Each rule that holds in every step is stated once, in SKILL.md, so a step
# file and the controller cannot drift apart.
while IFS= read -r rule; do
  [ -n "$rule" ] || continue
  total=0
  for f in SKILL.md $STEPS; do total=$((total + $(count "$SDD_DIR/$f" "$rule"))); done
  here="$(count "$SDD_DIR/SKILL.md" "$rule")"
  if [ "$total" -eq 1 ] && [ "$here" -eq 1 ]; then pass "rule stated once, in SKILL.md: $rule"; else fail "rule stated once, in SKILL.md: $rule (total=$total, SKILL.md=$here)"; fi
done < <(printf '%s\n' \
  'DONE — do not re-dispatch them' \
  'Conversation memory does not survive compaction.' \
  'trust the ledger and `git log` over your own recollection' \
  'Dispatch implementer, task-reviewer, fix-round, re-review and final-reviewer subagents with `run_in_background: false`.' \
  'Run a covering command expected to finish within 10 minutes in the foreground' \
  'A command that may run past 10 minutes is a tracked job' \
  'One implementer at a time in this session' \
  'Never fix findings yourself in the controller session' \
  'ONE shared cap of **five rounds per task**' \
  'still leaves blocking findings open, stop dispatching')

for f in $STEPS; do
  if grep -Fq "| [$f]($f) |" "$SDD_DIR/SKILL.md"; then pass "step table names $f"; else fail "step table names $f"; fi
done

if grep -Fq 'session <sid>: setup complete' "$SDD_DIR/setup.md"; then pass "setup.md writes the setup complete line"; else fail "setup.md writes the setup complete line"; fi
if grep -Fq 'Task <N>: report <status>' "$SDD_DIR/task-loop.md"; then pass "task-loop.md writes the report line"; else fail "task-loop.md writes the report line"; fi
if grep -Fq 'Task <N>: review <approved|blocking>' "$SDD_DIR/review-and-complete.md"; then pass "review-and-complete.md writes the review line"; else fail "review-and-complete.md writes the review line"; fi
if grep -Fq 'Task <N>: codex gate round <R> <approved|blocking>' "$SDD_DIR/review-and-complete.md"; then pass "review-and-complete.md writes the gate line"; else fail "review-and-complete.md writes the gate line"; fi
if grep -Fq 'a line it does not name, such as a deferred minor or the gate directory, leaves your step unchanged' "$SDD_DIR/SKILL.md"; then pass "the step table reads only the lines it names"; else fail "the step table reads only the lines it names"; fi
if grep -Fq "line (SKILL.md's ledger lines) after the round's \`fix round\` line" "$SDD_DIR/fix-loop.md"; then pass "fix-loop.md writes the review line after the fix round line"; else fail "fix-loop.md writes the review line after the fix round line"; fi

echo
if [ "$FAILURES" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "$FAILURES FAILURES"; exit 1; fi
