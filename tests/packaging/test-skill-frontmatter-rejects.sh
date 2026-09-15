#!/usr/bin/env bash
# The frontmatter validator has to REJECT frontmatter no YAML loader accepts.
# Its positive suite only proves the shipped tree passes, which stays true if
# the validator degrades into accepting everything — that is exactly how an
# unterminated quote, a bad escape, and a `: ` mapping separator shipped
# unnoticed. Each case below is a value pyyaml rejects or resolves to a
# non-string, driven through the validator's optional [skills-root] argument.
#
# Usage: test-skill-frontmatter-rejects.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="$REPO_ROOT/tests/packaging/test-skill-frontmatter.sh"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

echo "=== skill frontmatter rejection fixtures ==="
echo ""

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# One fixture root per case: the validator reports every skill beneath the root
# it is given, so a shared root would make one case's exit status unattributable.
# The description line is written with `printf '%s\n'`, which copies its
# argument verbatim — a `\q` in the fixture has to reach the file as a literal
# backslash-q, or the bad-escape case silently becomes a well-formed string.
write_fixture() {
    local dirname="$1"
    local desc_line="$2"
    local root="$TEST_ROOT/$dirname"

    mkdir -p "$root/$dirname"
    {
        echo "---"
        echo "name: $dirname"
        printf '%s\n' "$desc_line"
        echo "---"
        echo ""
        echo "# $dirname"
    } > "$root/$dirname/SKILL.md"
    printf '%s' "$root"
}

# A rejected case must also say WHY: an exit status alone would be satisfied by
# a validator that failed for an unrelated reason, such as a broken fixture.
expect_reject() {
    local dirname="$1"
    local desc_line="$2"
    local needle="$3"
    local root output status

    root="$(write_fixture "$dirname" "$desc_line")"
    output="$(bash "$VALIDATOR" "$root" 2>&1)"
    status=$?

    if [ "$status" -eq 0 ]; then
        fail "$dirname: validator rejects it (exited 0)"
        printf '%s\n' "$output" | sed 's/^/      /'
    elif printf '%s\n' "$output" | grep -Fq -- "$needle"; then
        pass "$dirname: rejected, and the reason names '$needle'"
    else
        fail "$dirname: rejected, but no '$needle' in the reason"
        printf '%s\n' "$output" | sed 's/^/      /'
    fi
}

# Without this control every case above would still pass against a validator
# broken to reject everything.
expect_accept() {
    local dirname="$1"
    local desc_line="$2"
    local root output status

    root="$(write_fixture "$dirname" "$desc_line")"
    output="$(bash "$VALIDATOR" "$root" 2>&1)"
    status=$?

    if [ "$status" -eq 0 ]; then
        pass "$dirname: well-formed frontmatter is accepted"
    else
        fail "$dirname: well-formed frontmatter is accepted (exited $status)"
        printf '%s\n' "$output" | sed 's/^/      /'
    fi
}

# An inline comment ends a plain scalar, so the loader resolves what precedes
# it: None and True, not the strings they look like.
expect_reject "null-with-comment" \
    'description: null # explanation' \
    "resolves to a non-string"
expect_reject "bool-with-comment" \
    'description: true # comment' \
    "resolves to a non-string"

# A quoted scalar must close, and may carry only escapes YAML defines.
expect_reject "unterminated-quote" \
    'description: "unterminated' \
    "never closed"
expect_reject "bad-escape" \
    'description: "has a bad escape \q here"' \
    "escape YAML does not define"

# A `: ` inside a plain scalar is a mapping separator: it makes the whole
# document unscannable, which is what shipped in optimizing-performance.
expect_reject "plain-mapping-colon" \
    'description: Use when something. Keywords: optimize, speed up' \
    "mapping separator"

expect_accept "well-formed" \
    'description: Use when a thing happens and another thing is true'

echo ""
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
