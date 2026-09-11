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

    # The block must be a YAML mapping: one `key: value` per line. A colon with
    # no separator whitespace is not a mapping separator, so `name:x` makes the
    # whole block parse as one plain scalar and no key is reachable at all.
    # Indented lines are continuations of the entry above; full-line comments
    # and blank lines are legal YAML.
    bad_line="$(awk '
        NR == 1 { next }
        /^---$/ { exit }
        /^[[:space:]]*$/ { next }
        /^[[:space:]]/ { next }
        /^#/ { next }
        /^[A-Za-z_][A-Za-z0-9_.-]*:[[:space:]]/ { next }
        /^[A-Za-z_][A-Za-z0-9_.-]*:$/ { next }
        { print; exit }
    ' "$skill")"
    if [ -n "$bad_line" ]; then
        fail "$dir: frontmatter is a key: value mapping (got '$bad_line')"
    else
        pass "$dir: frontmatter is a key: value mapping"
    fi

    # A YAML loader resolves a duplicate key to its LAST occurrence (or
    # rejects the document); every check below reads the FIRST. A block with
    # two `name:` lines therefore certifies a name no loader will return.
    dup_key="$(awk '
        NR == 1 { next }
        /^---$/ { exit }
        /^[[:space:]]/ { next }
        /^#/ { next }
        match($0, /^[A-Za-z_][A-Za-z0-9_.-]*:/) {
            k = substr($0, 1, RLENGTH - 1)
            if (k in seen) { print k; exit }
            seen[k] = 1
        }
    ' "$skill")"
    if [ -n "$dup_key" ]; then
        fail "$dir: frontmatter has no duplicate keys (got '$dup_key' twice)"
    else
        pass "$dir: frontmatter has no duplicate keys"
    fi

    # Last match, not first: a YAML loader resolves a duplicate key to its
    # last occurrence, so reading the first would print a true-looking PASS
    # for a name no loader returns. The duplicate-key check above already
    # fails the run; this keeps every line it prints honest as well.
    name_line="$(printf '%s\n' "$block" | grep -E '^name:([[:space:]]|$)' | tail -1)"
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

    desc_line="$(printf '%s\n' "$block" | grep -E '^description:([[:space:]]|$)' | tail -1)"
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
            '#'*)
                # A value that opens a YAML comment leaves the key null.
                fail "$dir: description value is a comment, so the key is null"
                ;;
            '['* | '{'* | '&'* | '*'* | '!'* | '%'* | '@'* | '`'*)
                # A flow collection, anchor, alias, tag, or reserved
                # indicator — none of which load as a string.
                fail "$dir: description is a plain or quoted scalar (got '$desc_value')"
                ;;
            *)
                # YAML resolves an UNQUOTED scalar by its token shape, so a
                # value can be present, single-line, and still reach a loader
                # as null, a boolean, or a number rather than a string.
                # Quoted values never reach this test: they start with a quote
                # and are strings whatever they spell.
                if awk -v v="$desc_value" 'BEGIN { exit !(v ~ /^(~|null|Null|NULL|true|True|TRUE|false|False|FALSE|yes|Yes|YES|no|No|NO|on|On|ON|off|Off|OFF|[+-]?[0-9][0-9_]*(\.[0-9_]*)?([eE][+-]?[0-9]+)?|[+-]?\.[0-9_]+([eE][+-]?[0-9]+)?|[+-]?\.(inf|Inf|INF|nan|NaN|NAN)|0x[0-9a-fA-F_]+|0o[0-7_]+)$/) }'; then
                    fail "$dir: description resolves to a non-string YAML scalar (got '$desc_value')"
                else
                    # A plain scalar continues across blank lines, so scan past
                    # them to the next top-level key or the closing delimiter.
                    continuation="$(awk '
                        NR == 1 { next }
                        /^---$/ { exit }
                        seen && /^[A-Za-z_][A-Za-z0-9_.-]*:/ { exit }
                        seen && /^[[:space:]]*$/ { next }
                        seen { print; exit }
                        /^description:[[:space:]]/ { seen = 1 }
                    ' "$skill")"
                    if [ -n "$continuation" ]; then
                        fail "$dir: description is on a single line (continuation follows)"
                    else
                        pass "$dir: description is a single-line plain scalar"
                    fi
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
