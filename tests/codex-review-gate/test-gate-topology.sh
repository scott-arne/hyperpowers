#!/usr/bin/env bash
#
# Topology check for the split Codex review gate.
#
# The index is the only router: it must reach every section file, every link
# must resolve, no section file may link to another (the section graph is
# cyclic, so a just-in-time hop can loop), and every caller must have a
# complete route.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE_DIR="$REPO_ROOT/skills/requesting-code-review"
INDEX="$GATE_DIR/codex-review-gate.md"

SIBLINGS="gate-preflight.md gate-setup.md gate-output-schema.md gate-lenses.md
recipe-document.md recipe-code.md gate-findings.md gate-fix-loop.md gate-sweep.md"

# All seven consumers of the gate. Two of them — the SDD final whole-branch
# call and the review sweep — reach the gate without naming the file, so a
# grep for the filename finds five call sites, not seven. Assert against
# this list, never against a grep, or the matrix rots while the test passes.
CALLERS="approach gate
spec gate
plan gate
per-task code gate
final whole-branch gate
ad-hoc code review
review sweep"

failures=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

echo "=== gate topology ==="
echo ""

# 1. Every sibling is linked from the index.
for f in $SIBLINGS; do
    if grep -Fq "($f)" "$INDEX"; then
        pass "index links $f"
    else
        fail "index links $f"
    fi
done

# 2. Every index link resolves.
while IFS= read -r target; do
    if [ -f "$GATE_DIR/$target" ]; then
        pass "index link resolves: $target"
    else
        fail "index link resolves: $target"
    fi
done < <(grep -o '](\([a-z0-9-]*\.md\))' "$INDEX" | sed 's/^](//; s/)$//' | sort -u)

# 3. No section file links to another section file.
for f in $SIBLINGS; do
    if grep -Eq '\]\([a-z0-9-]*\.md\)' "$GATE_DIR/$f"; then
        fail "$f does not link to another section file"
        grep -no '\](\([a-z0-9-]*\.md\))' "$GATE_DIR/$f" | head -3
    else
        pass "$f does not link to another section file"
    fi
done

# Route entries are backticked basenames without the .md suffix. The backtick
# lives in a variable so the pattern reads as a pattern rather than as an
# unterminated quote.
BT='`'

# 4. Every caller has a route, and that route names at least one file. Fed by
#    here-string, not a pipe: a piped `while` runs in a subshell, so every
#    failure it counted would be discarded.
#
#    The row's existence is not the property. An emptied route cell still
#    matches the caller, and check 5 cannot see the loss either — it counts
#    distinct names across the whole table, and every file in an emptied cell
#    is still named by some other row, so the total holds at 9. Measured: with
#    `| approach gate |  |` the old check-4 reported PASS and the suite exited
#    0. Assert on the cell, not the row.
while IFS= read -r caller; do
    row="$(grep -F "| $caller |" "$INDEX" | head -1)"
    if [ -z "$row" ]; then
        fail "route present for: $caller (no row in the matrix)"
        continue
    fi
    cell="${row#*| $caller |}"
    if printf '%s\n' "$cell" | grep -q "${BT}[a-z0-9-]*${BT}"; then
        pass "route present for: $caller"
    else
        fail "route present for: $caller (row exists, route cell names no file)"
    fi
done <<<"$CALLERS"

# 5. Route cells name only files that exist.
routes_seen=0
while IFS= read -r name; do
    routes_seen=$((routes_seen + 1))
    if [ -f "$GATE_DIR/$name.md" ]; then
        pass "route names an existing file: $name"
    else
        fail "route names an existing file: $name"
    fi
done < <(sed -n '/^| Caller /,$p' "$INDEX" | grep -o "${BT}[a-z0-9-]*${BT}" | tr -d "$BT" | sort -u)
# A matrix that parses to zero names would make check 5 a silent no-op.
if [ "$routes_seen" -ge 9 ]; then
    pass "route cells parsed ($routes_seen distinct names)"
else
    fail "route cells parsed (got $routes_seen, expected at least 9)"
fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
