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

# YAML resolves an UNQUOTED scalar by its token shape, so a value can be
# present, single-line, and still reach a loader as null, a boolean, or a
# number rather than the string it looks like. Quoted values never reach this
# test: they start with a quote and are strings whatever they spell.
resolves_to_non_string() {
    awk -v v="$1" 'BEGIN { exit !(v ~ /^(~|null|Null|NULL|true|True|TRUE|false|False|FALSE|yes|Yes|YES|no|No|NO|on|On|ON|off|Off|OFF|[+-]?[0-9][0-9_]*(\.[0-9_]*)?([eE][+-]?[0-9]+)?|[+-]?\.[0-9_]+([eE][+-]?[0-9]+)?|[+-]?\.(inf|Inf|INF|nan|NaN|NAN)|0x[0-9a-fA-F_]+|0o[0-7_]+)$/) }'
}

# A plain YAML scalar ends at an unquoted " #"; everything after is a comment.
# Classifying the raw value instead lets `null # explanation` masquerade as a
# string when a loader resolves it to None.
strip_plain_comment() {
    printf '%s' "$1" | sed 's/[[:space:]]#.*$//; s/[[:space:]]*$//'
}

# Why a frontmatter value is not a loadable single-line string, or nothing if
# it is one. A quoted scalar must close and may carry only escapes YAML
# defines; a plain scalar must not contain a `: ` mapping separator, which
# makes the whole document unscannable. The value arrives through the
# environment, not `awk -v`: `-v` performs its own backslash processing and
# would eat the very escapes this is here to inspect.
scalar_defect() {
    SCALAR="$1" awk '
    function walk_double(  n, i, c, e, rest) {
        n = length(s); i = 2
        while (i <= n) {
            c = substr(s, i, 1)
            if (c == "\\") {
                e = substr(s, i + 1, 1)
                if (e == "") return "double-quoted value ends in a dangling escape"
                if (index(LEGAL, e) == 0)
                    return "double-quoted value carries an escape YAML does not define (\\" e ")"
                i += 2; continue
            }
            if (c == "\"") {
                rest = substr(s, i + 1)
                sub(/^[ \t]+/, "", rest)
                if (rest != "" && substr(rest, 1, 1) != "#")
                    return "double-quoted value has trailing content after its closing quote"
                return ""
            }
            i++
        }
        return "double-quoted value is never closed"
    }
    function walk_single(  n, i, c, rest) {
        n = length(s); i = 2
        while (i <= n) {
            c = substr(s, i, 1)
            if (c == "'\''") {
                if (substr(s, i + 1, 1) == "'\''") { i += 2; continue }
                rest = substr(s, i + 1)
                sub(/^[ \t]+/, "", rest)
                if (rest != "" && substr(rest, 1, 1) != "#")
                    return "single-quoted value has trailing content after its closing quote"
                return ""
            }
            i++
        }
        return "single-quoted value is never closed"
    }
    BEGIN {
        s = ENVIRON["SCALAR"]
        LEGAL = "0abtnvfre\"/\\N_LP xuU\t"
        first = substr(s, 1, 1)
        if (first == "\"") { print walk_double(); exit }
        if (first == "'\''") { print walk_single(); exit }
        if (s ~ /: / || s ~ /:$/)
            print "plain value contains a `: ` mapping separator, so YAML cannot scan it"
    }'
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
    name_body="$(strip_plain_comment "$name_value")"
    if [ -z "$name_line" ]; then
        fail "$dir: frontmatter declares a name"
    elif resolves_to_non_string "$name_body"; then
        # A directory named `null`, `on`, or `123` would otherwise compare
        # equal as raw text while a loader returns None, True, or an int.
        fail "$dir: name resolves to a non-string YAML scalar (got '$name_value')"
    elif [ "$name_body" != "$dir" ]; then
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
        desc_defect=""
        case "$desc_value" in
            '|'* | '>'*)
                desc_defect="description is a plain scalar, not a block scalar" ;;
            '#'*)
                # A value that opens a YAML comment leaves the key null.
                desc_defect="description value is a comment, so the key is null" ;;
            '['* | '{'* | '&'* | '*'* | '!'* | '%'* | '@'* | '`'*)
                # A flow collection, anchor, alias, tag, or reserved
                # indicator — none of which load as a string.
                desc_defect="description is a plain or quoted scalar (got '$desc_value')" ;;
            *)
                syntax="$(scalar_defect "$desc_value")"
                if [ -n "$syntax" ]; then
                    desc_defect="description is loadable YAML ($syntax)"
                else
                    case "$desc_value" in
                        '"'* | "'"*) ;;   # quoted values are strings whatever they spell
                        *)
                            if resolves_to_non_string "$(strip_plain_comment "$desc_value")"; then
                                desc_defect="description resolves to a non-string YAML scalar (got '$desc_value')"
                            fi ;;
                    esac
                fi ;;
        esac
        if [ -n "$desc_defect" ]; then
            fail "$dir: $desc_defect"
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
