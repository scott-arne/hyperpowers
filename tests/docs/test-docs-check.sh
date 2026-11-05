#!/usr/bin/env bash
# Proves tests/docs/docs-check.sh catches each defect the documentation spec
# names (docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md,
# "Drift checks") and passes a clean site. Each case builds a one-skill git
# repository, breaks one thing, and expects a FAIL line for that check.
#
# Fixture files are written with printf (heredocs under tests/ can deadlock
# on small macOS pipes). Text that must contain a dollar amount is assembled
# at run time from '$' and a digit, so no amount appears in this file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK="$SCRIPT_DIR/docs-check.sh"

failures=0
TEST_ROOT=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || { echo "no temporary directory" >&2; exit 1; }
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 1
case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) echo "refusing temporary root $TEST_ROOT" >&2; exit 1 ;; esac
cleanup() { case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) return ;; esac; rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] ${1}"; }
fail() { echo "  [FAIL] ${1}"; failures=$((failures + 1)); }

# edit SCRIPT FILE: in-place sed that works with BSD and GNU sed.
edit() { sed -i.bak "${1}" "${2}" && rm -f "${2}.bak"; }

# write_alpha_page DIR DIGEST [SOURCES]
write_alpha_page() {
  local dir="${1}" digest="${2}" sources="${3:-skills/alpha}"
  printf '%s\n' \
    '---' \
    "sources: $sources" \
    "source-digest: $digest" \
    '---' \
    '# alpha' '' 'Does one thing for you.' '' \
    '## When it triggers' '' 'When you test it.' '' \
    '## What it does' '' 'It runs.' '' \
    '## Why it exists' '' 'To be checked.' '' \
    '## Pros' '' '- It is small.' '' \
    '## Cons and costs' '' '- It does little.' '- It exists only for this test.' '' \
    '## Skipping or overriding' '' 'Ask.' '' \
    '## Works with' '' 'Nothing.' '' \
    '## Under the hood' '' 'One helper file.' \
    > "$dir/docs/site/skills/alpha.md"
}

# set_alpha_sources DIR SOURCES: rewrite the page with SOURCES and a matching digest.
set_alpha_sources() {
  local dir="${1}" sources="${2}" digest
  write_alpha_page "$dir" 000000000000 "$sources"
  digest="$(bash "$CHECK" --root "$dir" --digest docs/site/skills/alpha.md)"
  write_alpha_page "$dir" "$digest" "$sources"
}

# make_fixture NAME: print the path of a fresh, clean one-skill repository.
make_fixture() {
  local dir="$TEST_ROOT/${1}"
  mkdir -p "$dir/skills/alpha" "$dir/docs/site/skills" "$dir/docs/site/advanced"
  printf '%s\n' '---' 'name: alpha' 'description: Use when testing the docs check' '---' '# Alpha' > "$dir/skills/alpha/SKILL.md"
  printf 'helper\n' > "$dir/skills/alpha/helper.md"
  printf '%s\n' '# Skills' '' '| Skill | What it does |' '|---|---|' '| {doc}`alpha` | Does one thing. |' > "$dir/docs/site/skills/index.md"
  git init -q "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  git -C "$dir" add -A
  set_alpha_sources "$dir" skills/alpha
  git -C "$dir" add -A
  printf '%s\n' "$dir"
}

# expect_ok LABEL DIR [ARGS...]: the check exits 0.
expect_ok() {
  local label="${1}" dir="${2}" out status=0
  shift 2
  out="$(bash "$CHECK" --root "$dir" "$@" 2>&1)" || status=$?
  if [ "$status" -eq 0 ]; then
    pass "$label"
  else
    fail "$label (exit $status)"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
}

# expect_fail LABEL DIR TAG [ARGS...]: the check exits 1 and prints a line starting "FAIL: TAG".
expect_fail() {
  local label="${1}" dir="${2}" tag="${3}" out status=0 nl='
'
  shift 3
  out="$(bash "$CHECK" --root "$dir" "$@" 2>&1)" || status=$?
  case "$nl$out" in
    *"${nl}FAIL: $tag"*) matched=1 ;;
    *) matched=0 ;;
  esac
  if [ "$status" -eq 1 ] && [ "$matched" -eq 1 ]; then
    pass "$label"
  else
    fail "$label (exit $status, expected a line starting: FAIL: $tag)"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
}

echo "=== docs-check ==="

d="$(make_fixture clean)"
expect_ok "a clean one-skill site passes" "$d"
expect_ok "--page passes a clean skill page" "$d" --page docs/site/skills/alpha.md
digest="$(bash "$CHECK" --root "$d" --digest docs/site/skills/alpha.md)"
case "$digest" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) pass "--digest prints 12 hex digits" ;;
  *) fail "--digest output (got: $digest)" ;;
esac

d="$(make_fixture missing-page)"
rm "$d/docs/site/skills/alpha.md"
expect_fail "a skill without a page fails" "$d" "coverage: skills/alpha has no page"

d="$(make_fixture orphan)"
cp "$d/docs/site/skills/alpha.md" "$d/docs/site/skills/beta.md"
expect_fail "a page without a skill fails" "$d" "orphan: docs/site/skills/beta.md"

d="$(make_fixture no-sources)"
edit '/^sources:/d' "$d/docs/site/skills/alpha.md"
expect_fail "a skill page without sources fails" "$d" "sources: docs/site/skills/alpha.md needs"

d="$(make_fixture own-dir)"
set_alpha_sources "$d" skills/alpha/helper.md
expect_fail "a skill page whose sources omit its own directory fails" "$d" "sources: docs/site/skills/alpha.md must list skills/alpha"

d="$(make_fixture untracked-source)"
set_alpha_sources "$d" "skills/alpha nosuch/path"
expect_fail "a source that matches no tracked file fails" "$d" "sources: docs/site/skills/alpha.md lists nosuch/path"

d="$(make_fixture advanced-no-sources)"
printf '%s\n' '# Triggering' '' 'Text.' > "$d/docs/site/advanced/triggering.md"
expect_fail "an advanced page without sources fails" "$d" "sources: docs/site/advanced/triggering.md needs"

d="$(make_fixture stale-skill)"
printf 'changed\n' >> "$d/skills/alpha/SKILL.md"
expect_fail "editing SKILL.md fails the digest" "$d" "digest: docs/site/skills/alpha.md"

d="$(make_fixture stale-helper)"
printf 'changed\n' >> "$d/skills/alpha/helper.md"
expect_fail "editing only a supporting file fails the digest" "$d" "digest: docs/site/skills/alpha.md"

d="$(make_fixture new-helper)"
printf 'new\n' > "$d/skills/alpha/extra.md"
git -C "$d" add skills/alpha/extra.md
expect_fail "adding a tracked file under the skill fails the digest" "$d" "digest: docs/site/skills/alpha.md"

d="$(make_fixture untracked-scratch)"
printf 'scratch\n' > "$d/skills/alpha/scratch.tmp"
expect_ok "an untracked file under the skill leaves the digest alone" "$d"

d="$(make_fixture missing-heading)"
edit '/^## Pros$/d' "$d/docs/site/skills/alpha.md"
expect_fail "a missing template heading fails" "$d" "structure: docs/site/skills/alpha.md is missing \"## Pros\""

d="$(make_fixture reordered)"
edit 's/^## Why it exists$/## TMP/; s/^## Pros$/## Why it exists/; s/^## TMP$/## Pros/' "$d/docs/site/skills/alpha.md"
expect_fail "reordered template headings fail" "$d" "structure: docs/site/skills/alpha.md is missing"

d="$(make_fixture fenced-heading)"
edit 's/^## Pros$/```/; s/^- It is small\.$/## Pros/' "$d/docs/site/skills/alpha.md"
printf '%s\n' '```' >> "$d/docs/site/skills/alpha.md"
expect_fail "a heading inside a code fence does not count" "$d" "structure: docs/site/skills/alpha.md is missing \"## Pros\""

d="$(make_fixture one-con)"
edit '/^- It exists only for this test\.$/d' "$d/docs/site/skills/alpha.md"
expect_fail "a single cons item fails" "$d" "structure: docs/site/skills/alpha.md has 1 list item(s)"

d="$(make_fixture unlisted)"
edit '/{doc}`alpha`/d' "$d/docs/site/skills/index.md"
expect_fail "an index that does not link the skill fails" "$d" "index: docs/site/skills/index.md does not link alpha"

d="$(make_fixture amount)"
printf 'It costs %s5 a run.\n' '$' >> "$d/docs/site/skills/alpha.md"
expect_fail "a dollar amount in a page fails" "$d" "dollar: docs/site/skills/alpha.md"
expect_fail "--page also catches the amount" "$d" "dollar: docs/site/skills/alpha.md" --page docs/site/skills/alpha.md

d="$(make_fixture word)"
printf '%s\n' 'project = "priced in USD"' > "$d/docs/site/conf.py"
expect_fail "the word USD in any site file fails" "$d" "dollar: docs/site/conf.py"

d="$(make_fixture build-output)"
mkdir -p "$d/docs/site/_build"
printf 'USD\n' > "$d/docs/site/_build/page.html"
expect_ok "build output is not scanned" "$d"

echo
if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures"
  exit 1
fi
echo "All docs-check tests passed"
