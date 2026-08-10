#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_SCRIPT="$REPO_ROOT/scripts/package-claude-skill.sh"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "Claude skill packaging tests"

# Create temp dist directory
TEST_DIST=$(mktemp -d)
trap 'rm -rf "$TEST_DIST"' EXIT

# Run the packaging script
export DIST_DIR="$TEST_DIST"
if ! bash "$PACKAGE_SCRIPT" > /dev/null 2>&1; then
  fail "package-claude-skill.sh exited non-zero"
  echo
  echo "STATUS: FAILED (1)"
  exit 1
else
  pass "package-claude-skill.sh exited 0"
fi

# Read version from package.json
VERSION=$(jq -r .version "$REPO_ROOT/package.json")
EXPECTED_ZIP="$TEST_DIST/hyperpowers-$VERSION.zip"

# Test 1: zip exists and is named with package.json version
if [[ -f "$EXPECTED_ZIP" ]]; then
  pass "zip exists at expected path (hyperpowers-$VERSION.zip)"
else
  fail "zip not found at $EXPECTED_ZIP"
fi

# Test 2: unzip -l layout (folder at root, SKILL.md present)
# Capture listing to avoid SIGPIPE from grep -q with set -o pipefail
zip_listing=$(unzip -l "$EXPECTED_ZIP")
if echo "$zip_listing" | grep -q "hyperpowers/SKILL.md"; then
  pass "hyperpowers/SKILL.md present in zip"
else
  fail "hyperpowers/SKILL.md not found in zip"
fi

if echo "$zip_listing" | grep -vE '(Archive:|Length|----| files$)' | grep -vE '^ *[0-9]+ .* hyperpowers/' | grep -qE '^ *[0-9]+'; then
  fail "zip contains entries outside hyperpowers/ folder"
else
  pass "all zip entries under hyperpowers/ folder"
fi

# Extract zip for further tests
EXTRACT_DIR="$TEST_DIST/extracted"
mkdir -p "$EXTRACT_DIR"
unzip -q "$EXPECTED_ZIP" -d "$EXTRACT_DIR"

SKILL_MD="$EXTRACT_DIR/hyperpowers/SKILL.md"

# Test 3: frontmatter has exactly name+description, name==hyperpowers (fix finding 2)
frontmatter_keys=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -E '^[^ :#]+:' | cut -d: -f1 | sort)
expected_keys=$(printf "description\nname")
if [[ "$frontmatter_keys" == "$expected_keys" ]]; then
  pass "frontmatter contains exactly name and description keys"
else
  fail "frontmatter keys mismatch (expected: name, description; found: $(echo $frontmatter_keys | tr '\n' ' '))"
fi

name=$(sed -n 's/^name: *//p' "$SKILL_MD")
if [[ "$name" == "hyperpowers" ]]; then
  pass "frontmatter name == hyperpowers"
else
  fail "frontmatter name is '$name', expected 'hyperpowers'"
fi

# Test 4: description length ≤195
description=$(sed -n 's/^description: *//p' "$SKILL_MD")
desc_len=${#description}
if [[ $desc_len -le 195 ]]; then
  pass "description length $desc_len ≤ 195"
else
  fail "description length $desc_len > 195"
fi

# Test 5: version string appears in body
if grep -q "Hyperpowers $VERSION" "$SKILL_MD"; then
  pass "version string $VERSION appears in SKILL.md body"
else
  fail "version string $VERSION not found in SKILL.md body"
fi

# Test 6: skill count in zip equals repo skill count
repo_skill_count=$(find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" | wc -l | tr -d ' ')
zip_skill_count=$(find "$EXTRACT_DIR/hyperpowers/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" | wc -l | tr -d ' ')
if [[ "$repo_skill_count" -eq "$zip_skill_count" ]]; then
  pass "skill count matches repo ($repo_skill_count)"
else
  fail "skill count mismatch: repo=$repo_skill_count, zip=$zip_skill_count"
fi

# Test 7: LICENSE present
if [[ -f "$EXTRACT_DIR/hyperpowers/LICENSE" ]]; then
  pass "LICENSE present"
else
  fail "LICENSE not found"
fi

# Test 8: NO hooks/, tests/, docs/, .claude-plugin/ paths inside zip
if unzip -l "$EXPECTED_ZIP" | grep -qE 'hyperpowers/(hooks|tests|docs|\.claude-plugin)/'; then
  fail "zip contains unwanted paths (hooks/, tests/, docs/, .claude-plugin/)"
else
  pass "no hooks/, tests/, docs/, or .claude-plugin/ in zip"
fi

# Test 9: Red Flags table first row present (verbatim check)
red_flag_row_first='"This is just a simple question" | Questions are tasks. Check for skills.'
if grep -Fq "$red_flag_row_first" "$SKILL_MD"; then
  pass "Red Flags table present (verified first row)"
else
  fail "Red Flags table first row not found"
fi

# Test 10: Red Flags table last row present (verbatim check)
red_flag_row_last='"I know what that means" | Knowing the concept ≠ using the skill. Invoke it.'
if grep -Fq "$red_flag_row_last" "$SKILL_MD"; then
  pass "Red Flags table last row verified (verbatim)"
else
  fail "Red Flags table last row not found or text differs"
fi

# Test 11 (regression finding 1): rebuild removes stale zip entries
TEST_DIST_STALE=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf $TEST_DIST_STALE" EXIT
STALE_ZIP="$TEST_DIST_STALE/hyperpowers-$VERSION.zip"
(cd "$TEST_DIST_STALE" && mkdir -p hyperpowers && echo "stale" > hyperpowers/STALE.md && zip -qr "hyperpowers-$VERSION.zip" hyperpowers)
export DIST_DIR="$TEST_DIST_STALE"
bash "$PACKAGE_SCRIPT" > /dev/null 2>&1
if unzip -l "$STALE_ZIP" | grep -q "hyperpowers/STALE.md"; then
  fail "rebuild did not remove stale zip entry (hyperpowers/STALE.md still present)"
else
  pass "rebuild removes stale zip entries"
fi

# Test 12 (regression finding 2): frontmatter guard rejects non-lowercase/drifted keys
TEST_TEMPLATE=$(mktemp)
cat "$REPO_ROOT/scripts/claude-skill-root.md" > "$TEST_TEMPLATE"
sed -i.bak '/^---$/,/^---$/ s/^description:/allowed-tools: read\ndescription:/' "$TEST_TEMPLATE"
TEST_DIST_GUARD=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf $TEST_DIST_GUARD $TEST_TEMPLATE ${TEST_TEMPLATE}.bak" EXIT
export DIST_DIR="$TEST_DIST_GUARD"
export SKILL_TEMPLATE="$TEST_TEMPLATE"
if bash "$PACKAGE_SCRIPT" > /dev/null 2>&1; then
  fail "frontmatter guard did not reject added allowed-tools key"
else
  pass "frontmatter guard rejects drifted template keys"
fi
unset SKILL_TEMPLATE

# Test 13 (regression finding 3): relative DIST_DIR resolves from caller cwd
TEST_CWD=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf $TEST_CWD" EXIT
(cd "$TEST_CWD" && DIST_DIR=relout bash "$PACKAGE_SCRIPT" > /dev/null 2>&1)
RELOUT_ZIP="$TEST_CWD/relout/hyperpowers-$VERSION.zip"
if [[ -f "$RELOUT_ZIP" ]]; then
  pass "relative DIST_DIR resolves from caller cwd"
else
  fail "relative DIST_DIR did not create zip at <caller cwd>/relout/"
fi

echo
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
