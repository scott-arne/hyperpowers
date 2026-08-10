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
OUTPUT_TMP=""
trap 'rm -rf "$TMP_STAGE" "$OUTPUT_TMP"' EXIT

STAGE="$TMP_STAGE/hyperpowers"
mkdir -p "$STAGE"

# Progress goes to stderr: a consumer closing stdout (e.g. | head) must never kill the build.
echo "Packaging hyperpowers $VERSION for Claude Desktop / claude.ai..." >&2
echo "" >&2

# Generate SKILL.md from template with version substitution
sed "s/{{VERSION}}/$VERSION/g" "$SKILL_TEMPLATE" > "$STAGE/SKILL.md"

# Stage ONLY git-tracked files from skills/ tree, EXCEPT skills/using-hyperpowers/SKILL.md
# (the router supersedes that file; references/ kept for cross-skill dependencies)
# Rename skills/*/SKILL.md → skills/*/INSTRUCTIONS.md at stage time (upload format allows only one SKILL.md)
git -C "$REPO_ROOT" ls-files -z -- skills/ | while IFS= read -r -d '' f; do
  [[ "$f" == "skills/using-hyperpowers/SKILL.md" ]] && continue
  mkdir -p "$STAGE/$(dirname "$f")"
  if [[ "$f" =~ ^skills/[^/]+/SKILL\.md$ ]]; then
    # Rename per-skill SKILL.md to INSTRUCTIONS.md
    cp "$REPO_ROOT/$f" "$STAGE/$(dirname "$f")/INSTRUCTIONS.md"
  else
    cp "$REPO_ROOT/$f" "$STAGE/$f"
  fi
done

# Copy LICENSE
cp "$REPO_ROOT/LICENSE" "$STAGE/"

echo "Validating package structure..." >&2

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

# Validation 4: staged skill count = tracked count minus using-hyperpowers (router supersedes it)
# Skills are renamed to INSTRUCTIONS.md during staging
repo_skill_count=$(git -C "$REPO_ROOT" ls-files -- 'skills/*/SKILL.md' | wc -l | tr -d ' ')
expected_stage_count=$((repo_skill_count - 1))
stage_skill_count=$(find "$STAGE/skills" -mindepth 2 -maxdepth 2 -name "INSTRUCTIONS.md" | wc -l | tr -d ' ')
if [[ "$expected_stage_count" -ne "$stage_skill_count" ]]; then
  echo "error: skill count mismatch: expected $expected_stage_count (repo $repo_skill_count - 1), got $stage_skill_count INSTRUCTIONS.md files" >&2
  exit 1
fi

# Validation 5: no {{VERSION}} placeholder remains
if grep -q '{{VERSION}}' "$STAGE/SKILL.md"; then
  echo "error: {{VERSION}} placeholder remains in SKILL.md after substitution" >&2
  exit 1
fi

echo "  ✓ Frontmatter keys: name, description" >&2
echo "  ✓ Name: $name ($name_len chars)" >&2
echo "  ✓ Description length: $desc_len chars" >&2
echo "  ✓ Skill count: $stage_skill_count" >&2
echo "  ✓ Version substitution complete" >&2
echo "" >&2

# Create the zip with hyperpowers/ as root entry, atomic write-then-rename
OUTPUT="$DIST_DIR/hyperpowers-$VERSION.zip"
OUTPUT_TMP="$OUTPUT.tmp.$$"
# Fresh temp even under PID reuse: zip updates existing archives in place.
rm -f "$OUTPUT_TMP"
(cd "$TMP_STAGE" && zip -qr "$OUTPUT_TMP" hyperpowers)

echo "Verifying zip structure..." >&2

# Verify zip structure: folder at root, SKILL.md present
# Note: capture listing to avoid SIGPIPE from grep -q closing the pipe early
zip_listing=$(unzip -l "$OUTPUT_TMP")
if ! echo "$zip_listing" | grep -q "hyperpowers/SKILL.md"; then
  echo "error: hyperpowers/SKILL.md not found in zip" >&2
  exit 1
fi
if echo "$zip_listing" | grep -vE '(Archive:|Length|----| files$)' | grep -vE '^ *[0-9]+ .* hyperpowers/' | grep -E '^ *[0-9]+'; then
  echo "error: zip contains entries outside hyperpowers/ folder" >&2
  exit 1
fi

# Fail-closed check: upload format allows EXACTLY ONE file named SKILL.md in the entire bundle
skill_md_count=$(echo "$zip_listing" | grep -cE '^ *[0-9]+ .*/SKILL\.md$' || true)
if [[ "$skill_md_count" -ne 1 ]]; then
  echo "error: zip contains $skill_md_count files with basename SKILL.md (upload format requires exactly 1)" >&2
  exit 1
fi

echo "  ✓ Zip root entry: hyperpowers/" >&2
echo "  ✓ SKILL.md present" >&2
echo "  ✓ Exactly one SKILL.md basename (upload format requirement)" >&2
echo "" >&2

# Atomically move validated zip to final path
mv -f "$OUTPUT_TMP" "$OUTPUT"
OUTPUT_TMP=""

# Final artifact path goes to stdout only; nothing else
echo "$OUTPUT"
