#!/usr/bin/env bash
# Drift and content checks for the documentation site in docs/site/.
#
# A page that describes repository behavior lists those paths in a
# `sources:` front-matter line and records a `source-digest:` over them.
# When a listed skill, hook, or script changes, this check fails until
# someone re-reads the page and records the new digest. The rules are in
# docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md ("Drift
# checks").
#
# Usage:
#   docs-check.sh [--root DIR]                  all checks over the site
#   docs-check.sh [--root DIR] --page PAGE ...  per-page checks only
#   docs-check.sh [--root DIR] --digest PAGE    print PAGE's current digest
#
# PAGE is relative to the repository root, e.g.
# docs/site/skills/brainstorming.md. Exit 0 when every check passes, 1 when
# any fails (one "FAIL: <check>: ..." line each), 2 on a usage error.
#
# Positional parameters are written ${1} and awk's whole record $(0): this
# repository's pre-commit scan flags a dollar sign followed by a digit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SITE=docs/site
HEADINGS=(
  "## When it triggers"
  "## What it does"
  "## Why it exists"
  "## Pros"
  "## Cons and costs"
  "## Skipping or overriding"
  "## Works with"
  "## Under the hood"
)

failures=0
fail() { echo "FAIL: ${1}"; failures=$((failures + 1)); }

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    sha256sum | cut -d' ' -f1
  fi
}

# front_matter_value PAGE KEY: print KEY's value from PAGE's leading
# front-matter block, or nothing.
front_matter_value() {
  awk -v key="${2}:" '
    NR == 1 { if ($(0) != "---") exit; next }
    $(0) == "---" { exit }
    index($(0), key) == 1 {
      value = substr($(0), length(key) + 1)
      sub(/^[ \t]+/, "", value)
      sub(/[ \t]+$/, "", value)
      print value
      exit
    }
  ' "$ROOT/${1}"
}

# compute_digest PATH...: one "<sha256>  <path>" line per tracked file under
# the paths, paths sorted bytewise, each line ending in a newline; print the
# first 12 hex digits of the SHA-256 of those lines.
compute_digest() {
  (cd "$ROOT" && git ls-files -z -- "$@") \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' file; do
        [ -f "$ROOT/$file" ] || continue
        printf '%s  %s\n' "$(sha256_stdin < "$ROOT/$file")" "$file"
      done \
    | sha256_stdin | cut -c1-12
}

requires_sources() {
  case "${1}" in
    "$SITE/skills/index.md") return 1 ;;
    "$SITE"/skills/*.md | "$SITE"/advanced/*.md | "$SITE/recommended-settings.md") return 0 ;;
    *) return 1 ;;
  esac
}

is_skill_page() {
  case "${1}" in
    "$SITE/skills/index.md") return 1 ;;
    "$SITE"/skills/*.md) return 0 ;;
    *) return 1 ;;
  esac
}

check_structure() {
  local page="${1}" i=0 line cons
  while IFS= read -r line; do
    if [ "$i" -lt "${#HEADINGS[@]}" ] && [ "$line" = "${HEADINGS[$i]}" ]; then
      i=$((i + 1))
    fi
  done < <(awk '/^```/ { fence = !fence; next } !fence && /^## / { print }' "$ROOT/$page")
  if [ "$i" -lt "${#HEADINGS[@]}" ]; then
    fail "structure: $page is missing \"${HEADINGS[$i]}\" or has it out of order"
  fi
  cons="$(awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { in_cons = ($(0) == "## Cons and costs"); next }
    in_cons && /^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]/ { n++ }
    END { print n + 0 }
  ' "$ROOT/$page")"
  if [ "$cons" -lt 2 ]; then
    fail "structure: $page has $cons list item(s) under \"## Cons and costs\"; at least 2 are required"
  fi
}

# check_amounts FILE...: dollar amounts and the words for them.
check_amounts() {
  local file rel hit
  for file in "$@"; do
    rel="${file#"$ROOT"/}"
    while IFS= read -r hit; do
      if [ -n "$hit" ]; then
        fail "dollar: $rel:$hit"
      fi
    done < <(grep -n -I -E '\$[0-9]' "$file" || true; grep -n -I -i -w -E 'usd|dollars?' "$file" || true)
  done
}

check_page() {
  local page="${1}" sources digest expected path name
  if [ ! -f "$ROOT/$page" ]; then
    fail "coverage: $page does not exist"
    return
  fi
  sources="$(front_matter_value "$page" sources)"
  digest="$(front_matter_value "$page" source-digest)"
  if requires_sources "$page" && { [ -z "$sources" ] || [ -z "$digest" ]; }; then
    fail "sources: $page needs both a sources: and a source-digest: front-matter line"
  fi
  if [ -n "$sources" ]; then
    # shellcheck disable=SC2086 # sources is a space-separated path list by design
    set -- $sources
    for path in "$@"; do
      if [ -z "$(cd "$ROOT" && git ls-files -- "$path" | head -n 1)" ]; then
        fail "sources: $page lists $path, which matches no tracked file"
      fi
    done
    if is_skill_page "$page"; then
      name="$(basename "$page" .md)"
      case " $sources " in
        *" skills/$name "* | *" skills/$name/ "*) ;;
        *) fail "sources: $page must list skills/$name" ;;
      esac
    fi
    expected="$(compute_digest "$@")"
    if [ -n "$digest" ] && [ "$digest" != "$expected" ]; then
      fail "digest: $page records $digest but its sources ($sources) now give $expected; re-read the page against the changed sources, fix what is stale, then set source-digest: $expected"
    fi
  fi
  if is_skill_page "$page"; then
    check_structure "$page"
  fi
}

full_check() {
  local skill name page index="$ROOT/$SITE/skills/index.md" files=()
  if [ ! -f "$index" ]; then
    fail "index: $SITE/skills/index.md does not exist"
  fi
  for skill in "$ROOT"/skills/*/SKILL.md; do
    [ -f "$skill" ] || continue
    name="$(basename "$(dirname "$skill")")"
    if [ ! -f "$ROOT/$SITE/skills/$name.md" ]; then
      fail "coverage: skills/$name has no page $SITE/skills/$name.md"
    fi
    if [ -f "$index" ] && ! grep -qF -- "{doc}\`${name}\`" "$index"; then
      fail "index: $SITE/skills/index.md does not link $name (expected {doc}\`${name}\`)"
    fi
  done
  for page in "$ROOT/$SITE"/skills/*.md; do
    [ -f "$page" ] || continue
    name="$(basename "$page" .md)"
    if [ "$name" != index ] && [ ! -f "$ROOT/skills/$name/SKILL.md" ]; then
      fail "orphan: $SITE/skills/$name.md has no skills/$name/SKILL.md"
    fi
  done
  while IFS= read -r -d '' page; do
    case "$page" in
      *.md) check_page "${page#"$ROOT"/}" ;;
    esac
    files+=("$page")
  done < <(find "$ROOT/$SITE" -path "$ROOT/$SITE/_build" -prune -o -type f -print0)
  if [ "${#files[@]}" -gt 0 ]; then
    check_amounts "${files[@]}"
  fi
}

mode=full
pages=()
while [ "$#" -gt 0 ]; do
  case "${1}" in
    --root)
      [ "$#" -ge 2 ] || { echo "docs-check: --root needs a directory" >&2; exit 2; }
      ROOT="$(cd "${2}" && pwd)"
      shift 2
      ;;
    --page)
      [ "$#" -ge 2 ] || { echo "docs-check: --page needs a path" >&2; exit 2; }
      mode=page
      pages+=("${2}")
      shift 2
      ;;
    --digest)
      [ "$#" -ge 2 ] || { echo "docs-check: --digest needs a path" >&2; exit 2; }
      mode=digest
      pages=("${2}")
      shift 2
      ;;
    *)
      echo "docs-check: unknown argument ${1}" >&2
      exit 2
      ;;
  esac
done

case "$mode" in
  digest)
    page="${pages[0]}"
    [ -f "$ROOT/$page" ] || { echo "docs-check: $page does not exist" >&2; exit 2; }
    sources="$(front_matter_value "$page" sources)"
    [ -n "$sources" ] || { echo "docs-check: $page has no sources: line" >&2; exit 2; }
    # shellcheck disable=SC2086 # sources is a space-separated path list by design
    compute_digest $sources
    exit 0
    ;;
  page)
    for page in "${pages[@]}"; do
      check_page "$page"
      if [ -f "$ROOT/$page" ]; then
        check_amounts "$ROOT/$page"
      fi
    done
    ;;
  full)
    full_check
    ;;
esac

if [ "$failures" -gt 0 ]; then
  echo "docs-check: $failures failure(s)"
  exit 1
fi
echo "docs-check: OK"
