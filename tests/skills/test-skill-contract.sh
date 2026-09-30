#!/usr/bin/env bash
# Prose contracts for skills whose behavior-shaping wording has no other
# test: writing-skills' pruning rules.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WSKILLS="$REPO_ROOT/skills/writing-skills/SKILL.md"

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

echo "=== skill prose contracts ==="
echo ""

# --- A10 pruning tests and expiring baselines ----------------------------
assert_contains "$WSKILLS" "**The no-op test:** delete a sentence and ask whether the agent's behavior changes." \
  "the no-op test is stated"
assert_contains "$WSKILLS" "If it does not, the sentence was paying load to say nothing." \
  "a no-op sentence is paying load"
assert_contains "$WSKILLS" "Delete the whole sentence, never trim words from it." \
  "the no-op test deletes whole sentences"
assert_contains "$WSKILLS" "The test is model-relative, and it is settled by running the document, not by debate." \
  "the no-op test is settled by running the document"
assert_contains "$WSKILLS" "**Cache, do not restate:**" \
  "the cache rule is stated"
assert_contains "$WSKILLS" 'the environment is a source of truth too: `--help` output, config files, `package.json` scripts, the directory layout.' \
  "the environment is named as a source of truth"
assert_contains "$WSKILLS" "A skill line that restates one of those is a cache that goes stale." \
  "restating the environment is a stale cache"
assert_contains "$WSKILLS" "Write down what the agent cannot find by looking: the unwritten convention, the reason behind a choice, the gotcha no config confesses." \
  "a skill records what the environment cannot answer"
assert_contains "$WSKILLS" "**Baselines expire with the model.**" \
  "baselines expire with the model"
assert_contains "$WSKILLS" "A RED baseline is evidence about the model that produced it." \
  "a baseline is evidence about one model"
assert_contains "$WSKILLS" "Record the model in the evidence note." \
  "the evidence note records the model"
assert_contains "$WSKILLS" "When the default model changes, re-run the baseline" \
  "a model change re-runs the baseline"
assert_contains "$WSKILLS" "if the unassisted model now passes, the skill or section is a deletion candidate, not a keepsake" \
  "a passing baseline makes the section a deletion candidate"

echo ""
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
