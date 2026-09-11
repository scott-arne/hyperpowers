#!/usr/bin/env bash
# Every skills/<dir>/SKILL.md must carry parseable frontmatter: a name matching
# its directory, a single-line description, and a block within the 1024-char
# limit the skill spec sets. A "Use when" prefix is recommended by
# writing-skills but deliberately NOT required here — several shipped skills
# open differently, and a recommendation is not a gate.
#
# Usage: test-skill-frontmatter.sh [skills-root]   (default: <repo>/skills)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_ROOT="${1:-$REPO_ROOT/skills}"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

echo "=== skill frontmatter ==="
echo ""

checked=0
for skill in "$SKILLS_ROOT"/*/SKILL.md; do
    [ -f "$skill" ] || continue
    checked=$((checked + 1))
    dir="$(basename "$(dirname "$skill")")"

    if [ "$(sed -n '1p' "$skill")" != "---" ]; then
        fail "$dir: SKILL.md opens with a frontmatter delimiter"
        continue
    fi

    # Body of the frontmatter block: everything after line 1 up to, but not
    # including, the next bare "---".
    block="$(awk 'NR==1 {next} /^---$/ {exit} {print}' "$skill")"
    # Check for closing delimiter (avoids sed|grep pipeline SIGPIPE issue).
    if ! awk 'NR >= 2 && /^---$/ {found=1; exit} END {exit !found}' "$skill"; then
        fail "$dir: frontmatter block is closed"
        continue
    fi
    pass "$dir: frontmatter block is delimited"

    name_line="$(printf '%s\n' "$block" | grep -m1 '^name:')"
    name_value="${name_line#name:}"
    # Trim leading spaces without a bashism that macOS bash 3.2 lacks.
    name_value="$(printf '%s' "$name_value" | sed 's/^ *//; s/ *$//')"
    if [ -z "$name_line" ]; then
        fail "$dir: frontmatter declares a name"
    elif [ "$name_value" != "$dir" ]; then
        fail "$dir: name matches the directory (got '$name_value')"
    else
        pass "$dir: name matches the directory"
    fi

    desc_line="$(printf '%s\n' "$block" | grep -m1 '^description:')"
    desc_value="$(printf '%s' "${desc_line#description:}" | sed 's/^ *//')"
    if [ -z "$desc_line" ]; then
        fail "$dir: frontmatter declares a description"
    elif [ -z "$desc_value" ]; then
        fail "$dir: description has a value on the same line"
    else
        case "$desc_value" in
            '|'* | '>'*)
                fail "$dir: description is a plain scalar, not a block scalar"
                ;;
            *)
                # Check for continuation line after description.
                desc_line_num="$(printf '%s\n' "$block" | grep -n '^description:' | head -1 | cut -d: -f1)"
                next_line_num=$((desc_line_num + 1))
                next_line="$(printf '%s\n' "$block" | sed -n "${next_line_num}p")"
                if [ -n "$next_line" ] && ! printf '%s\n' "$next_line" | grep -q '^[A-Za-z_][A-Za-z0-9_.-]*:'; then
                    fail "$dir: description is on a single line (continuation follows)"
                else
                    pass "$dir: description is a single-line plain scalar"
                fi
                ;;
        esac
    fi

    chars="$(awk 'NR==1 {next} /^---$/ {exit} {print}' "$skill" | wc -m | tr -d ' ')"
    if [ "$chars" -le 1024 ]; then
        pass "$dir: frontmatter is within 1024 characters ($chars)"
    else
        fail "$dir: frontmatter is within 1024 characters (got $chars)"
    fi
done

if [ "$checked" -eq 0 ]; then
    fail "found at least one SKILL.md under $SKILLS_ROOT"
fi

echo ""
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
