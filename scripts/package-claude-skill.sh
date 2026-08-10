#!/usr/bin/env bash
#
# package-claude-skill.sh — build a single uploadable Claude Desktop / claude.ai skill zip
# from this repo's skills tree plus a generated router SKILL.md.
#
# Usage:
#   DIST_DIR=custom/path package-claude-skill.sh   (default: dist/)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist}"
SKILL_TEMPLATE="${SKILL_TEMPLATE:-$REPO_ROOT/scripts/claude-skill-root.md}"
PACKAGE_JSON="$REPO_ROOT/package.json"

# Read version from package.json
VERSION=$(jq -r .version "$PACKAGE_JSON")
if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "error: could not read version from package.json" >&2
  exit 1
fi

# Create dist directory if needed and canonicalize path (fix finding 3)
mkdir -p "$DIST_DIR"
DIST_DIR="$(cd "$DIST_DIR" && pwd)"

# Create temporary staging directory
TMP_STAGE=$(mktemp -d)
trap 'rm -rf "$TMP_STAGE"' EXIT

STAGE="$TMP_STAGE/hyperpowers"
mkdir -p "$STAGE"

echo "Packaging hyperpowers $VERSION for Claude Desktop / claude.ai..."
echo ""

# Generate SKILL.md from template with version substitution
sed "s/{{VERSION}}/$VERSION/g" "$SKILL_TEMPLATE" > "$STAGE/SKILL.md"

# Copy skills tree verbatim
cp -R "$REPO_ROOT/skills" "$STAGE/"

# Copy LICENSE
cp "$REPO_ROOT/LICENSE" "$STAGE/"

echo "Validating package structure..."

# Validation 1: frontmatter contains ONLY name and description keys (fix finding 2)
frontmatter_keys=$(sed -n '/^---$/,/^---$/p' "$STAGE/SKILL.md" | grep -E '^[^ :#]+:' | cut -d: -f1 | sort)
expected_keys=$(printf "description\nname")
if [[ "$frontmatter_keys" != "$expected_keys" ]]; then
  echo "error: SKILL.md frontmatter contains unexpected keys" >&2
  echo "expected: name, description" >&2
  echo "found: $frontmatter_keys" >&2
  exit 1
fi

# Validation 2: name == hyperpowers and ≤64 chars
name=$(sed -n 's/^name: *//p' "$STAGE/SKILL.md")
if [[ "$name" != "hyperpowers" ]]; then
  echo "error: SKILL.md frontmatter name is '$name', expected 'hyperpowers'" >&2
  exit 1
fi
name_len=${#name}
if [[ $name_len -gt 64 ]]; then
  echo "error: SKILL.md frontmatter name is $name_len chars, max 64" >&2
  exit 1
fi

# Validation 3: description ≤200 chars
description=$(sed -n 's/^description: *//p' "$STAGE/SKILL.md")
desc_len=${#description}
if [[ $desc_len -gt 200 ]]; then
  echo "error: SKILL.md frontmatter description is $desc_len chars, max 200" >&2
  exit 1
fi

# Validation 4: every skills/*/SKILL.md in repo is in the stage
repo_skill_count=$(find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" | wc -l | tr -d ' ')
stage_skill_count=$(find "$STAGE/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" | wc -l | tr -d ' ')
if [[ "$repo_skill_count" -ne "$stage_skill_count" ]]; then
  echo "error: skill count mismatch: repo=$repo_skill_count, stage=$stage_skill_count" >&2
  exit 1
fi

# Validation 5: no {{VERSION}} placeholder remains
if grep -q '{{VERSION}}' "$STAGE/SKILL.md"; then
  echo "error: {{VERSION}} placeholder remains in SKILL.md after substitution" >&2
  exit 1
fi

echo "  ✓ Frontmatter keys: name, description"
echo "  ✓ Name: $name ($name_len chars)"
echo "  ✓ Description length: $desc_len chars"
echo "  ✓ Skill count: $stage_skill_count"
echo "  ✓ Version substitution complete"
echo ""

# Create the zip with hyperpowers/ as root entry (fix finding 1)
OUTPUT="$DIST_DIR/hyperpowers-$VERSION.zip"
rm -f "$OUTPUT"
(cd "$TMP_STAGE" && zip -qr "$OUTPUT" hyperpowers)

echo "Verifying zip structure..."

# Verify zip structure: folder at root, SKILL.md present
# Note: capture listing to avoid SIGPIPE from grep -q closing the pipe early
zip_listing=$(unzip -l "$OUTPUT")
if ! echo "$zip_listing" | grep -q "hyperpowers/SKILL.md"; then
  echo "error: hyperpowers/SKILL.md not found in zip" >&2
  exit 1
fi
if echo "$zip_listing" | grep -vE '(Archive:|Length|----| files$)' | grep -vE '^ *[0-9]+ .* hyperpowers/' | grep -E '^ *[0-9]+'; then
  echo "error: zip contains entries outside hyperpowers/ folder" >&2
  exit 1
fi

echo "  ✓ Zip root entry: hyperpowers/"
echo "  ✓ SKILL.md present"
echo ""

echo "Package created: $OUTPUT"
echo ""
echo "Upload via Claude Desktop / claude.ai Settings → Customize → Skills → upload zip"
echo "(Requires code execution enabled)"
