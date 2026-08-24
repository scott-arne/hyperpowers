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

# Every gate caller loads the same six-file spine and exactly one recipe.
# Naming the spine once states that design instead of copying the matrix row
# by row, so a legitimate route change edits one word here, not seven cells.
SPINE="gate-preflight gate-setup gate-output-schema gate-lenses gate-findings gate-fix-loop"

# All seven consumers of the gate, each with the exact route it must be given.
# Two of them — the SDD final whole-branch call and the review sweep — reach
# the gate without naming the file, so a grep for the filename finds five call
# sites, not seven. Assert against this list, never against a grep, or the
# matrix rots while the test passes.
#
# The field separator is `=` because no caller name and no route basename
# contains one.
ROUTES="approach gate=gate-preflight
spec gate=$SPINE recipe-document
plan gate=$SPINE recipe-document
per-task code gate=$SPINE recipe-code
final whole-branch gate=$SPINE recipe-code
ad-hoc code review=$SPINE recipe-code
review sweep=gate-preflight gate-sweep"

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

# 4. Every caller's route names exactly the files that caller needs — no name
#    missing, no name extra. Fed by here-string, not a pipe: a piped `while`
#    runs in a subshell, so every failure it counted would be discarded.
#
#    Neither a row's existence nor a non-empty cell is the property. Check 5
#    cannot see a partial loss either: it counts distinct names across the
#    whole table, and a name dropped from one row is still supplied by another,
#    so the total holds at 9. Measured — dropping `gate-lenses` from the spec
#    gate row left check 4 PASS, check 5 PASS, and the suite exiting 0.
#    Compare the parsed cell against the expected set in both directions.
#
#    `review sweep` carries conditional prose after its two names. The prose
#    holds no backticks, so it parses to those two names and needs no case of
#    its own.
callers_checked=0
while IFS='=' read -r caller expected; do
    callers_checked=$((callers_checked + 1))
    row="$(sed -n '/^| Caller /,$p' "$INDEX" | grep -F "| $caller |" | head -1)"
    if [ -z "$row" ]; then
        fail "route exact for: $caller (no row in the matrix)"
        continue
    fi
    cell="${row#*| "$caller" |}"
    actual="$(printf '%s\n' "$cell" | grep -o "${BT}[a-z0-9-]*${BT}" | tr -d "$BT" |
        LC_ALL=C sort | tr '\n' ' ')"
    want="$(printf '%s\n' "$expected" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ')"
    if [ "$actual" = "$want" ]; then
        pass "route exact for: $caller"
    else
        fail "route exact for: $caller (want [${want% }], got [${actual% }])"
    fi
done <<<"$ROUTES"

# The loop above is fed by a redirection, and bash backs a here-string with a
# temp file. If that redirection fails the body never runs, `failures` never
# moves, and the suite prints PASSED having checked nothing — Codex hit exactly
# that in a sandbox whose temp dir was unwritable. Check 5 carries this guard
# already; check 4 was missing it.
if [ "$callers_checked" -eq 7 ]; then
    pass "all 7 caller routes checked"
else
    fail "all 7 caller routes checked (ran $callers_checked)"
fi

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
