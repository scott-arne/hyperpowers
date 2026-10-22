#!/usr/bin/env bash
# Regression suite for skills/finishing-a-development-branch/scripts/decisions-compile.
#
# The compiler is the only writer of decision records. It lifts a spec's
# Decisions list into one record per decision, regenerates the index, owns
# the spec's Outcome line, and stages the result; it validates before it
# writes, re-runs safely in every state, and never commits. These checks
# lock that contract (spec Design §1 and §2, Verification 1 to 15).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPILE="$REPO_ROOT/skills/finishing-a-development-branch/scripts/decisions-compile"

failures=0
# Physical path: the compiler reports physical paths, and macOS puts mktemp
# output behind a symlink. Each step fails fast and the trap is installed
# last, so a failed mktemp can never leave cleanup pointed at the checkout.
TEST_ROOT=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || { echo "no temporary directory" >&2; exit 1; }
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 1
case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) echo "refusing temporary root $TEST_ROOT" >&2; exit 1 ;; esac
cleanup() { case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) return ;; esac; rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

make_repo() {
    git init -q -b main "$1"
    git -C "$1" config user.name "Test Bot"
    git -C "$1" config user.email "test@example.com"
    mkdir -p "$1/docs/hyperpowers/specs" "$1/docs/hyperpowers/plans"
}

# write_spec REPO NAME <<EOF ... EOF : writes docs/hyperpowers/specs/NAME from stdin.
write_spec() { cat > "$1/docs/hyperpowers/specs/$2"; }

# run_compile REPO ARGS... : runs the compiler from the repository root with
# a fixed date, capturing stdout to $OUT, stderr to $ERR, the exit to $RC.
run_compile() {
    local repo="$1"; shift
    set +e
    OUT=$( cd "$repo" && DECISIONS_COMPILE_DATE="${COMPILE_DATE:-2026-10-21}" bash "$COMPILE" "$@" 2> "$TEST_ROOT/stderr" )
    RC=$?
    set -e
    ERR=$(cat "$TEST_ROOT/stderr")
}

# --allow-empty keeps the suite running in the red phase, when a check's
# preceding run wrote nothing.
commit_all() { git -C "$1" add -A && git -C "$1" commit -q --allow-empty -m "$2"; }

echo "=== decisions-compile ==="
echo ""

# --- 1. parsing: list shapes, titles, nesting, fences ------------------------
repo="$TEST_ROOT/parse"
make_repo "$repo"
write_spec "$repo" 2026-10-19-alpha-design.md <<'EOF'
# Alpha

**Date:** 2026-10-19

## Problem

Prose.

## Decisions

1. **Skill text, not a hook.** The rules live in the skill. A hook was
   rejected because it works only in one harness.
   - a nested bullet that belongs to decision 1
 a continuation line with one space keeps its space
2. **Evidence: a scenario, then a field rerun.** Two sources.
   ```
   ## not a heading
   - not an item
   ```
   ~~~
   1. not an item either
   ~~~
3. Bulleted plain items are titled by their first clause: this text stays. More.

## Design

Not a decision.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --dry-run
if [ "$RC" -eq 0 ]; then pass "dry run exits 0 on a numbered list"; else fail "dry run exit (got $RC: $ERR)"; fi
case "$OUT" in
    "dry run: 3 decisions, index docs/hyperpowers/decisions/README.md"*) pass "dry-run summary names the count and the index" ;;
    *) fail "dry-run summary (got: $(printf '%s\n' "$OUT" | head -n 1))" ;;
esac
case "$OUT" in
    *"would write docs/hyperpowers/decisions/2026-10-19-skill-text-not-a-hook.md (decision 1: Skill text, not a hook)"*) pass "bold title, trailing period dropped, slug and date from the spec" ;;
    *) fail "decision 1 listing (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 2: Evidence: a scenario, then a field rerun)"*) pass "a bold title keeps its inner colon" ;;
    *) fail "decision 2 title (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 3: Bulleted plain items are titled by their first clause)"*) pass "a plain item is titled by its first clause" ;;
    *) fail "decision 3 title (got: $OUT)" ;;
esac
if [ "$(printf '%s\n' "$OUT" | grep -c '^would write')" = "3" ]; then pass "nested bullets and fenced markers do not become decisions"; else fail "item count (got: $(printf '%s\n' "$OUT" | grep -c '^would write'))"; fi
if [ -d "$repo/docs/hyperpowers/decisions" ]; then fail "dry run wrote the records directory"; else pass "dry run writes nothing"; fi

# --- 2. heading variants; the first matching heading wins ------------------
for heading in "## Decisions" "## 2. Decisions" "## Key decisions (resolved during brainstorming)" "## Decisions taken with the human partner" "## 2. Locked decisions"; do
    r="$TEST_ROOT/heading-$(printf '%s' "$heading" | tr -c 'a-zA-Z0-9' '_')"
    make_repo "$r"
    printf '# Spec\n\n%s\n\n- **First.** Text one.\n- **Second.** Text two.\n\n## Later decisions appendix\n\n- one\n- two\n- three\n' "$heading" > "$r/docs/hyperpowers/specs/2026-01-02-x-design.md"
    commit_all "$r" "spec"
    run_compile "$r" docs/hyperpowers/specs/2026-01-02-x-design.md --dry-run
    if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^would write')" = "2" ]; then
        pass "heading variant found, first match wins: $heading"
    else
        fail "heading variant: $heading (rc $RC, out: $OUT, err: $ERR)"
    fi
done

# --- 3. a prose-only section fails closed ---------------------------------
repo="$TEST_ROOT/prose"
make_repo "$repo"
write_spec "$repo" 2026-03-03-prose-design.md <<'EOF'
# Prose

## Decisions

We decided several things, in paragraphs, with no list at all.

## Design
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-03-03-prose-design.md
if [ "$RC" -eq 2 ]; then pass "prose-only section exits 2"; else fail "prose-only exit (got $RC)"; fi
case "$ERR" in
    "docs/hyperpowers/specs/2026-03-03-prose-design.md: no decisions list"*) pass "exit 2 names the spec and the missing list" ;;
    *) fail "exit 2 message (got: $ERR)" ;;
esac
if [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a failed validation writes nothing"; else fail "tree dirty after exit 2"; fi

# --- 4. records: the golden file, indentation, refresh on re-run -------------
repo="$TEST_ROOT/write"
make_repo "$repo"
write_spec "$repo" 2026-10-19-alpha-design.md <<'EOF'
# Alpha

**Date:** 2026-10-19

## Decisions

1. **Skill text, not a hook.** The rules live in the skill. A hook was
   rejected because it works only in one harness.
   - a nested bullet that belongs to decision 1
 a continuation line with one space keeps its space
2. **Evidence: a scenario, then a field rerun.** Two sources.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md
if [ "$RC" -eq 0 ]; then pass "compile exits 0"; else fail "compile exit (got $RC: $ERR)"; fi
case "$OUT" in
    "wrote 2 records, updated 0, superseded 0, undocumented 0, proposed supersessions 0, index docs/hyperpowers/decisions/README.md"*) pass "summary line" ;;
    *) fail "summary line (got: $(printf '%s\n' "$OUT" | head -n 1))" ;;
esac
case "$OUT" in
    *$'\n'"wrote docs/hyperpowers/decisions/2026-10-19-skill-text-not-a-hook.md (decision 1: Skill text, not a hook)"$'\n'*) pass "verb line per record" ;;
    *) fail "verb line (got: $OUT)" ;;
esac
rec="$repo/docs/hyperpowers/decisions/2026-10-19-skill-text-not-a-hook.md"
cat > "$TEST_ROOT/golden-1.md" <<'EOF'
# Skill text, not a hook

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-19-alpha-design.md (decision 1)
- Recorded: 2026-10-21

## Decision

**Skill text, not a hook.** The rules live in the skill. A hook was
rejected because it works only in one harness.
- a nested bullet that belongs to decision 1
 a continuation line with one space keeps its space

## What implementation changed

Nothing recorded.
EOF
if diff -u "$TEST_ROOT/golden-1.md" "$rec" > "$TEST_ROOT/golden.diff"; then
    pass "record 1 matches the golden file byte for byte (indentation stripped only where the full width is present)"
else
    fail "record 1 golden diff:"; sed 's/^/        /' "$TEST_ROOT/golden.diff"
fi
if [ "$(git -C "$repo" rev-list --count HEAD)" = "1" ]; then pass "no commit was made"; else fail "the compiler committed"; fi
commit_all "$repo" "records"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -- docs/hyperpowers/decisions/2026-10-19-*)" ]; then pass "a second run leaves the records unchanged"; else fail "second run changed records (rc $RC, status: $(git -C "$repo" status --porcelain))"; fi
case "$OUT" in "wrote 0 records, updated 0,"*) pass "a second run reports nothing written" ;; *) fail "second-run summary (got: $(printf '%s\n' "$OUT" | head -n 1))" ;; esac
printf '3. **A third one.** Added after the first finish.\n' >> "$repo/docs/hyperpowers/specs/2026-10-19-alpha-design.md"
sed 's/^1\. \*\*Skill text, not a hook\.\*\* The rules live in the skill\./1. **Skill text, not a hook.** The rules live in the skill text./' "$repo/docs/hyperpowers/specs/2026-10-19-alpha-design.md" > "$TEST_ROOT/spec.tmp" && mv "$TEST_ROOT/spec.tmp" "$repo/docs/hyperpowers/specs/2026-10-19-alpha-design.md"
COMPILE_DATE=2026-10-23 run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md
case "$OUT" in
    "wrote 1 records, updated 1,"*) pass "a run after an added and an edited item writes one and updates one" ;;
    *) fail "add+edit summary (got: $(printf '%s\n' "$OUT" | head -n 1))" ;;
esac
if grep -q 'live in the skill text\.' "$rec"; then pass "an edited item refreshes the record's decision text"; else fail "decision text not refreshed"; fi
if grep -q '^- Recorded: 2026-10-21$' "$rec"; then pass "the Recorded date survives a later-day re-run"; else fail "Recorded date changed: $(grep '^- Recorded:' "$rec")"; fi
if [ -f "$repo/docs/hyperpowers/decisions/2026-10-19-a-third-one.md" ]; then pass "the added decision gets its own record"; else fail "third record missing"; fi

# --- 5. filename collisions --------------------------------------------------
repo="$TEST_ROOT/collide"
make_repo "$repo"
write_spec "$repo" 2026-05-05-one-design.md <<'EOF'
# One

## Decisions

- **Same title.** First of two in one spec.
- **Same title.** Second of two in one spec.
EOF
write_spec "$repo" 2026-05-05-two-design.md <<'EOF'
# Two

## Decisions

- **Same title.** A third from another spec with the same date.
EOF
commit_all "$repo" "specs"
run_compile "$repo" docs/hyperpowers/specs/2026-05-05-one-design.md
if [ -f "$repo/docs/hyperpowers/decisions/2026-05-05-same-title.md" ] && [ -f "$repo/docs/hyperpowers/decisions/2026-05-05-same-title-2.md" ]; then
    pass "two decisions of one spec with one title get <slug>.md and <slug>-2.md"
else
    fail "same-spec collision (got: $(ls "$repo/docs/hyperpowers/decisions"))"
fi
run_compile "$repo" docs/hyperpowers/specs/2026-05-05-two-design.md
if [ "$RC" -eq 0 ] && [ -f "$repo/docs/hyperpowers/decisions/2026-05-05-same-title-1.md" ]; then
    pass "another spec's same-date same-title decision takes its own number suffix"
else
    fail "cross-spec collision (rc $RC, err: $ERR, files: $(ls "$repo/docs/hyperpowers/decisions"))"
fi
write_spec "$repo" 2026-05-05-three-design.md <<'EOF'
# Three

## Decisions

- **Same title.** A fourth whose suffixed name is taken too.
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-05-05-three-design.md
if [ "$RC" -eq 2 ]; then pass "a third collision exits 2 asking for a distinct title"; else fail "third collision (rc $RC)"; fi
case "$ERR" in *"distinct title"*) pass "collision message names the remedy" ;; *) fail "collision message (got: $ERR)" ;; esac

# --- 6. locale independence and usage errors ---------------------------------
repo="$TEST_ROOT/locale"
make_repo "$repo"
write_spec "$repo" 2026-06-06-loc-design.md <<'EOF'
# Locale

## Decisions

- **Ärger über Zebra.** Non-ASCII letters become hyphens, whatever the host locale.
- **apple before Zebra.** Sorting is bytewise.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-06-06-loc-design.md --dry-run
first=$OUT
OUT=$( cd "$repo" && LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 DECISIONS_COMPILE_DATE=2026-10-21 bash "$COMPILE" docs/hyperpowers/specs/2026-06-06-loc-design.md --dry-run 2>/dev/null )
if [ "$first" = "$OUT" ] && printf '%s' "$first" | grep -q 'decisions/2026-06-06-rger-ber-zebra.md'; then
    pass "slugs are the same under a UTF-8 locale (the compiler sets LC_ALL=C for itself)"
else
    fail "locale-dependent output (C: $first | UTF-8: $OUT)"
fi
run_compile "$repo"
if [ "$RC" -eq 2 ]; then pass "no arguments is a usage error"; else fail "no-arg exit (got $RC)"; fi
run_compile "$repo" docs/hyperpowers/specs/missing.md
if [ "$RC" -eq 2 ]; then pass "a missing spec exits 2"; else fail "missing spec exit (got $RC)"; fi
run_compile "$repo" docs/hyperpowers/specs/2026-06-06-loc-design.md docs/hyperpowers/specs/2026-06-06-loc-design.md
if [ "$RC" -eq 2 ]; then pass "two positional arguments are a usage error"; else fail "two specs (got $RC)"; fi

# --- 7. a quoted identity line in a body selects nothing ----------------------
repo="$TEST_ROOT/quote"
make_repo "$repo"
write_spec "$repo" 2026-07-07-quote-design.md <<'EOF'
# Quote

## Decisions

1. **First one.** Plain.
2. **Second one.** It quotes a record header:
   - Spec: docs/hyperpowers/specs/2026-07-07-quote-design.md (decision 1)
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-07-07-quote-design.md
commit_all "$repo" "records"
run_compile "$repo" docs/hyperpowers/specs/2026-07-07-quote-design.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ] && [ "$(head -n 1 "$repo/docs/hyperpowers/decisions/2026-07-07-first-one.md")" = "# First one" ] && [ "$(head -n 1 "$repo/docs/hyperpowers/decisions/2026-07-07-second-one.md")" = "# Second one" ]; then
    pass "a decision body quoting another record's Spec line cannot select or overwrite it"
else
    fail "quoted identity (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"
fi

# --- 8. a failed write exits 3 with the spec's path ---------------------------
repo="$TEST_ROOT/unwritable"
make_repo "$repo"
write_spec "$repo" 2026-08-08-fail-design.md <<'EOF'
# Fail

## Decisions

- **Cannot land.** The records directory refuses writes.
EOF
commit_all "$repo" "spec"
mkdir -p "$repo/docs/hyperpowers/decisions"
chmod 555 "$repo/docs/hyperpowers/decisions"
run_compile "$repo" docs/hyperpowers/specs/2026-08-08-fail-design.md
chmod 755 "$repo/docs/hyperpowers/decisions"
if [ "$RC" -eq 3 ]; then pass "an unwritable records directory exits 3"; else fail "write failure exit (got $RC: $ERR)"; fi
case "$ERR" in "docs/hyperpowers/specs/2026-08-08-fail-design.md: "*) pass "the write failure line begins with the spec's path" ;; *) fail "write failure message (got: $ERR)" ;; esac
if [ -z "$(find "$repo/docs/hyperpowers/decisions" -type f)" ]; then pass "a failed write leaves no partial or temporary file"; else fail "files left behind: $(ls "$repo/docs/hyperpowers/decisions")"; fi

# --- 9. a spec at the repository root is refused ----------------------------------
repo="$TEST_ROOT/rootspec"
make_repo "$repo"
cat > "$repo/root-design.md" <<'EOF'
# Root

## Decisions

- **At the root.** Its records would land outside the repository.
EOF
commit_all "$repo" "spec"
run_compile "$repo" root-design.md
if [ "$RC" -eq 2 ]; then pass "a root-level spec exits 2"; else fail "root-level spec exit (got $RC)"; fi
case "$ERR" in "root-design.md: the spec must live in a subdirectory of the repository"*) pass "the root-level message names the spec and the rule" ;; *) fail "root-level message (got: $ERR)" ;; esac
if [ ! -e "$TEST_ROOT/decisions" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a root-level spec writes nothing"; else fail "root-level spec wrote something"; fi

# >>> later tasks append their checks above this line <<<

if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
