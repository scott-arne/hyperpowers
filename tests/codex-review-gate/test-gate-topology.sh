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

# 6. Bare cross-file references respect route boundaries.
#
# A section file may name a sibling (e.g., "the watch loop in recipe-code.md")
# for orientation, but only if every route that delivers the mentioning file
# also delivers the mentioned file. The seven known exceptions are pinned here;
# a reference outside this list violates the route-aware property, and a stale
# exception (one whose reference no longer exists) must also fail.
#
# Exception format: <mentioning-file>:<line>:<mentioned-file>
# Each is scoped to the other gate type, with the reading caller's equivalent
# stated adjacent.
EXCEPTIONS="gate-findings.md:57:recipe-code.md
gate-findings.md:70:recipe-code.md
gate-findings.md:83:recipe-code.md
gate-findings.md:112:recipe-code.md
gate-findings.md:136:recipe-code.md
gate-setup.md:33:recipe-document.md
gate-lenses.md:42:recipe-document.md"

# Find all bare .md references to section files (not inside markdown links).
violations=""
for f in $SIBLINGS; do
    # For each section file, look for mentions of other section files.
    for target in $SIBLINGS; do
        [ "$target" = "$f" ] && continue

        # Find all mentions of this target file in the current file.
        # grep -Fn finds the exact string with line numbers.
        mentions="$(grep -Fn "$target" "$GATE_DIR/$f" 2>/dev/null || true)"

        while IFS=: read -r line rest; do
            [ -z "$line" ] && continue

            # Skip if this mention is inside a markdown link: ](<target>)
            if printf '%s' "$rest" | grep -Fq "]($target)"; then
                continue
            fi

            # Check if this is an allowed exception.
            exception_key="$f:$line:$target"
            if printf '%s\n' "$EXCEPTIONS" | grep -Fqx "$exception_key"; then
                continue
            fi

            # Extract basename without .md for route checking.
            mentioned_base="${target%.md}"
            mentioning_base="${f%.md}"

            # For each route that includes the mentioning file, verify it also
            # includes the mentioned file.
            route_violation=""
            while IFS='=' read -r caller route_files; do
                # Check if this route includes the mentioning file.
                if ! printf '%s\n' "$route_files" | grep -qw "$mentioning_base"; then
                    continue
                fi

                # This route includes the mentioning file. Does it include the mentioned?
                if ! printf '%s\n' "$route_files" | grep -qw "$mentioned_base"; then
                    route_violation="$caller"
                    break
                fi
            done <<<"$ROUTES"

            if [ -n "$route_violation" ]; then
                violations="${violations}${f}:${line} mentions ${target} (route '$route_violation' excludes it)
"
            fi
        done <<<"$mentions"
    done
done

if [ -n "$violations" ]; then
    fail "bare cross-file references respect routes"
    printf '%s' "$violations" | head -5
else
    pass "bare cross-file references respect routes"
fi

# Check for stale exceptions (references that no longer exist).
stale=""
while IFS= read -r exception; do
    [ -z "$exception" ] && continue

    exc_file="${exception%%:*}"
    rest="${exception#*:}"
    exc_line="${rest%%:*}"
    exc_mentioned="${rest#*:}"

    # Verify this exact reference exists.
    if ! grep -Fq "$exc_mentioned" "$GATE_DIR/$exc_file" 2>/dev/null; then
        stale="${stale}${exception} (reference no longer exists)
"
    else
        # Verify it's at the expected line.
        actual_line="$(grep -n "$exc_mentioned" "$GATE_DIR/$exc_file" | grep "^${exc_line}:" || true)"
        if [ -z "$actual_line" ]; then
            stale="${stale}${exception} (not at line $exc_line)
"
        fi
    fi
done <<<"$EXCEPTIONS"

if [ -n "$stale" ]; then
    fail "exception list current (no stale entries)"
    printf '%s' "$stale"
else
    pass "exception list current (no stale entries)"
fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
