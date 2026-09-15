#!/usr/bin/env bash
# The frontmatter validator has to REJECT frontmatter no YAML loader accepts.
# Its positive suite only proves the shipped tree passes, which stays true if
# the validator degrades into accepting everything — that is exactly how an
# unterminated quote, a bad escape, and a `: ` mapping separator shipped
# unnoticed. Each case below is frontmatter a reference loader (PyYAML or Ruby
# Psych) refuses — a value it resolves to a non-string, a byte it will not read
# at all, bytes that are not UTF-8, or a value under any top-level key that no
# loader can scan — driven through the validator's optional [skills-root]
# argument.
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
# The root is minted with `mktemp -d` rather than named after the case, because
# macOS is case-insensitive by default: `hex-u-escape` and `hex-U-escape` would
# otherwise be one directory, and the second case would inherit the first's
# directory name and report a spurious name/directory mismatch.
# The description line is written with `printf '%s\n'`, which copies its
# argument verbatim — a `\q` in the fixture has to reach the file as a literal
# backslash-q, or the bad-escape case silently becomes a well-formed string.
write_fixture() {
    local dirname="$1"
    local desc_line="$2"
    local after_name_line="${3:-}"
    local root

    root="$(mktemp -d "$TEST_ROOT/case-XXXXXX")"
    mkdir -p "$root/$dirname"
    {
        echo "---"
        echo "name: $dirname"
        if [ -n "$after_name_line" ]; then
            printf '%s\n' "$after_name_line"
        fi
        printf '%s\n' "$desc_line"
        echo "---"
        echo ""
        echo "# $dirname"
    } > "$root/$dirname/SKILL.md"
    printf '%s' "$root"
}

# Like write_fixture, but the description line is a printf FORMAT, so a case
# can place any byte in the file — a shell variable cannot carry NUL.
write_fixture_raw() {
    local dirname="$1"
    local desc_format="$2"
    local root
    root="$(mktemp -d "$TEST_ROOT/case-XXXXXX")"
    mkdir -p "$root/$dirname"
    {
        echo "---"
        echo "name: $dirname"
        # shellcheck disable=SC2059  # the format is the point of this helper
        printf "description: $desc_format\n"
        echo "---"
        echo ""
        echo "# $dirname"
    } > "$root/$dirname/SKILL.md"
    printf '%s' "$root"
}

expect_reject_raw() {
    local dirname="$1"
    local desc_format="$2"
    local needle="$3"
    local root output status

    root="$(write_fixture_raw "$dirname" "$desc_format")"
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

# A rejected case must also say WHY: an exit status alone would be satisfied by
# a validator that failed for an unrelated reason, such as a broken fixture.
expect_reject() {
    local dirname="$1"
    local desc_line="$2"
    local needle="$3"
    local after_name_line="${4:-}"
    local root output status

    root="$(write_fixture "$dirname" "$desc_line" "$after_name_line")"
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
    local after_name_line="${3:-}"
    local root output status

    root="$(write_fixture "$dirname" "$desc_line" "$after_name_line")"
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

# An escape introducer is not an escape: \x, \u and \U owe 2, 4 and 8
# hexadecimal digits, and \U must stay within Unicode.
expect_reject "hex-x-escape" \
    'description: "bad \xZZ escape"' \
    "hexadecimal digits"
expect_reject "hex-u-escape" \
    'description: "bad \u12Q4 escape"' \
    "hexadecimal digits"
expect_reject "hex-U-escape" \
    'description: "bad \U0000ZZZZ escape"' \
    "hexadecimal digits"
expect_reject "codepoint-above-max" \
    'description: "\UFFFFFFFF"' \
    "above U+10FFFF"

# A plain scalar that does not begin with a letter can resolve to a date,
# an integer in any base, or a sexagesimal; the rule rejects the shape
# rather than enumerating every loader's grammar.
expect_reject "date-scalar" \
    'description: 2026-09-14' \
    "begins with a letter"
expect_reject "binary-scalar" \
    'description: 0b101' \
    "begins with a letter"
expect_reject "sexagesimal-scalar" \
    'description: 1:20' \
    "begins with a letter"

# YAML 1.1 reads y and n as booleans (PyYAML happens not to; the gate follows
# the specification).
expect_reject "yaml11-bool-word" \
    'description: y' \
    "resolves to a non-string"

# A string, but not a description.
expect_reject "empty-quoted" \
    'description: ""' \
    "empty string"

# The loader folds an indented next line into name, so a first line that
# matches the directory proves nothing.
expect_reject "name-continuation" \
    'description: Use when the name runs onto a second line' \
    "name is on a single line" \
    "  continued"

# A name that no loader can scan never gets to be compared with the directory.
expect_reject "a: b" \
    'description: Use when fine' \
    "mapping separator"
expect_reject "foo:" \
    'description: Use when fine' \
    "mapping separator"

# A lone UTF-16 surrogate is not a scalar value: Psych refuses the document
# (PyYAML happens to construct it, which is why a PyYAML-only probe missed it).
expect_reject "surrogate-u-escape" \
    'description: "Use when \uD800 appears"' \
    "UTF-16 surrogate"
expect_reject "surrogate-U-escape" \
    'description: "Use when \U0000DFFF appears"' \
    "UTF-16 surrogate"

# The value indicator is a colon followed by ANY separation white space, so a
# tab after the colon splits the plain scalar exactly as a space does; and
# PyYAML refuses a tab anywhere inside an unquoted scalar.
expect_reject "colon-tab" \
    $'description: Use when foo:\tbar' \
    "mapping separator"
expect_reject "plain-tab" \
    $'description: Use when ready\t# comment' \
    "contains a tab"

# A control character anywhere in the document — plain or quoted, C0 or C1,
# NUL included — makes a loader refuse the whole file. The gate counts the
# block's bytes, so even a NUL the shell cannot hold is seen.
expect_reject_raw "control-bel-plain" \
    'Use when\007here' \
    "control characters"
expect_reject_raw "control-bel-quoted" \
    '"Use when\007here"' \
    "control characters"
expect_reject_raw "control-cr-plain" \
    'Use when\rhere' \
    "control characters"
expect_reject_raw "control-del" \
    'Use when\177here' \
    "control characters"
expect_reject_raw "control-esc-quoted" \
    '"Use when\033[0m here"' \
    "control characters"
expect_reject_raw "control-nul" \
    'Use when\000here' \
    "control characters"
expect_reject_raw "control-c1" \
    'Use when\302\200here' \
    "control characters"
expect_reject_raw "control-nel" \
    'Use when\302\205here' \
    "control characters"
expect_reject_raw "control-fffe" \
    'Use when\357\277\276here' \
    "control characters"

# The block must be UTF-8 as RFC 3629 defines it. A loader refuses the file
# for a stray continuation byte, an overlong form, an encoded surrogate, a
# code point above U+10FFFF, or a truncated sequence — none of which is a
# control character, so the byte-count check alone never saw them.
expect_reject_raw "utf8-lone-continuation" \
    '"Use when \200 here"' \
    "valid UTF-8"
expect_reject_raw "utf8-overlong-two-byte" \
    'Use when \300\201 here' \
    "valid UTF-8"
expect_reject_raw "utf8-overlong-three-byte" \
    'Use when \340\200\200 here' \
    "valid UTF-8"
expect_reject_raw "utf8-encoded-surrogate" \
    'Use when \355\240\200 here' \
    "valid UTF-8"
expect_reject_raw "utf8-above-max-code-point" \
    'Use when \364\220\200\200 here' \
    "valid UTF-8"
expect_reject_raw "utf8-invalid-lead-byte" \
    'Use when \365\200\200\200 here' \
    "valid UTF-8"
expect_reject_raw "utf8-truncated-sequence" \
    'Use when \303 here' \
    "valid UTF-8"

# TAB is illegal as indentation everywhere in YAML, and PyYAML refuses it as
# separation after a colon; a stray byte in a comment breaks the file just as
# surely as one in a value.
expect_reject "tab-indented-continuation" \
    'description: Use when fine' \
    "control characters" \
    $'extra: okay\n\tbad'
expect_reject "tab-after-colon-on-extra-key" \
    'description: Use when fine' \
    "control characters" \
    $'extra:\tval'
expect_reject "utf8-invalid-byte-in-comment" \
    'description: Use when fine' \
    "valid UTF-8" \
    $'# comment with \xff byte'

# Every top-level value gets description's scalar rules. Each of these loads
# in no standards-compliant loader, whichever key carries it.
expect_reject "extra-key-unterminated-flow" \
    'description: Use when fine' \
    "plain or quoted scalar" \
    'extra: [unterminated'
expect_reject "extra-key-alias" \
    'description: Use when fine' \
    "plain or quoted scalar" \
    'extra: *missing'
expect_reject "extra-key-unterminated-quote" \
    'description: Use when fine' \
    "never closed" \
    'extra: "unterminated'
expect_reject "extra-key-sequence-entry" \
    'description: Use when fine' \
    "begins with a letter" \
    'extra: - item'
expect_reject "extra-key-mapping-colon" \
    'description: Use when fine' \
    "mapping separator" \
    'extra: a: b'
expect_reject "extra-key-flow-indicator" \
    'description: Use when fine' \
    "begins with a letter" \
    'extra: ]x'

# Loaders accept these, but the gate admits only single-line plain or quoted
# scalars under any key; quote the value if a string is meant.
expect_reject "extra-key-empty-value" \
    'description: Use when fine' \
    "has a value on its line" \
    'extra:'
expect_reject "extra-key-block-scalar" \
    'description: Use when fine' \
    "not a block scalar" \
    'extra: |'
expect_reject "extra-key-bare-number" \
    'description: Use when fine' \
    "begins with a letter" \
    'version: 1.2'

# A key that is a YAML boolean or null word loads as True, False, or None,
# so no reader finds it by name.
expect_reject "extra-key-boolean-word" \
    'description: Use when fine' \
    "is a string key" \
    'true: okay'
expect_reject "extra-key-null-word" \
    'description: Use when fine' \
    "is a string key" \
    'null: okay'

# The frontmatter is a flat mapping of single-line scalars: an indented line
# continues or nests the entry above, which the gate does not support, however
# legal the YAML.
expect_reject "space-indented-continuation-on-extra-key" \
    'description: Use when fine' \
    "key: value mapping" \
    $'extra: okay\n  more'

# YAML permits a TAB inside a quoted scalar, but the gate admits no TAB
# anywhere in frontmatter (see the validator): tracking the exact positions
# where a TAB is legal is how the earlier gaps arose, and no skill needs one.
expect_reject "colon-tab-quoted" \
    $'description: "Use when foo:\tbar"' \
    "control characters"
expect_reject "single-quoted-tab" \
    $'description: \'Use when foo\tbar\'' \
    "control characters"

expect_accept "well-formed" \
    'description: Use when a thing happens and another thing is true'
expect_accept "valid-hex-escapes" \
    'description: "Use when \x41é\U0001F600 appears in the input"'
expect_accept "url-in-plain-scalar" \
    'description: Use when http://example.com is down'
expect_accept "hash-without-space" \
    'description: Use when x#y is set'
expect_accept "surrogate-range-edges" \
    'description: "Use when \uD7FF and \uE000 appear"'
expect_accept "bom-mid-string" \
    $'description: Use when \xef\xbb\xbf here'
expect_accept "non-ascii-text" \
    'description: Use when é happens and ü follows'
expect_accept "utf8-four-byte-character" \
    $'description: Use when \xf0\x9f\x98\x80 appears'
expect_accept "utf8-max-code-point" \
    $'description: Use when \xf4\x8f\xbf\xbf appears'
expect_accept "utf8-cjk-text" \
    $'description: Use when \xe4\xb8\xad\xe6\x96\x87 appears'
expect_accept "extra-key-plain" \
    'description: Use when fine' \
    'license: MIT'
expect_accept "extra-key-quoted-colon" \
    'description: Use when fine' \
    'extra: "with: colon"'
expect_accept "extra-key-with-comment" \
    'description: Use when fine' \
    'extra: okay # note'
expect_accept "two-extra-keys" \
    'description: Use when fine' \
    $'license: MIT\ncompatibility: Claude Code'

echo ""
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
