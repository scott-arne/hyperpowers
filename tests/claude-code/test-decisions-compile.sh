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

# --- 10. a hand-made file at a record's name is never overwritten -----------------
repo="$TEST_ROOT/handmade"
make_repo "$repo"
write_spec "$repo" 2026-09-09-hand-design.md <<'EOF'
# Hand

## Decisions

- **Taken name.** The record is deleted, then its name is reused by hand.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-09-09-hand-design.md
hand="$repo/docs/hyperpowers/decisions/2026-09-09-taken-name.md"
rm "$hand"
printf '# Other\n\n- Status: accepted\n- Spec: docs/hyperpowers/specs/other.md (decision 1)\n- Recorded: 2026-09-01\n\n## Decision\n\nHand made.\n' > "$hand"
cp "$hand" "$TEST_ROOT/hand.before"
run_compile "$repo" docs/hyperpowers/specs/2026-09-09-hand-design.md
if [ "$RC" -eq 0 ] && [ -f "$repo/docs/hyperpowers/decisions/2026-09-09-taken-name-1.md" ] && cmp -s "$hand" "$TEST_ROOT/hand.before"; then
    pass "a new record never replaces a file that took its name; it gets a suffixed name"
else
    fail "hand-made file collision (rc $RC, err: $ERR, files: $(ls "$repo/docs/hyperpowers/decisions"))"
fi

# --- 11. index, Outcome line, staging, paths -------------------------------
repo="$TEST_ROOT/stage"
make_repo "$repo"
write_spec "$repo" 2026-10-19-alpha-design.md <<'EOF'
# Alpha

**Date:** 2026-10-19

## Decisions

1. **Skill text, not a hook.** The rules live in the skill.
2. **Evidence: a scenario, then a field rerun.** Two sources.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --paths-file "$TEST_ROOT/no-such-dir/x.paths"
if [ "$RC" -eq 2 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "an unwritable --paths-file destination exits 2 before any write"; else fail "paths-file preflight (rc $RC, status: $(git -C "$repo" status --porcelain))"; fi
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --paths-file "$TEST_ROOT/stage.paths"
if [ "$RC" -eq 0 ]; then pass "compile with --paths-file exits 0"; else fail "compile exit (got $RC: $ERR)"; fi
idx="$repo/docs/hyperpowers/decisions/README.md"
if [ -f "$idx" ] && grep -q '^2 current, 0 superseded\.$' "$idx"; then pass "index counts"; else fail "index counts (missing or wrong)"; fi
if grep -q '^| 2026-10-19 | \[Skill text, not a hook\](2026-10-19-skill-text-not-a-hook.md) | \[2026-10-19-alpha-design.md\](../specs/2026-10-19-alpha-design.md) |$' "$idx"; then
    pass "index row links the record and the spec"
else
    fail "index row:"; sed 's/^/        /' "$idx"
fi
if grep -q '^## Superseded' "$idx"; then fail "empty Superseded table rendered"; else pass "Superseded table omitted when empty"; fi
case "$OUT" in *$'\n'"wrote docs/hyperpowers/decisions/README.md"$'\n'*) pass "index verb line" ;; *) fail "index verb line missing" ;; esac
spec="$repo/docs/hyperpowers/specs/2026-10-19-alpha-design.md"
if [ "$(sed -n 3p "$spec")" = "**Outcome:** implemented 2026-10-21; 2 decisions under docs/hyperpowers/decisions/." ]; then
    pass "Outcome line inserted after the title and its blank line"
else
    fail "Outcome line (got line 3: $(sed -n 3p "$spec"))"
fi
case "$OUT" in *"updated docs/hyperpowers/specs/2026-10-19-alpha-design.md (outcome)"*) pass "spec verb line" ;; *) fail "spec verb line missing" ;; esac
staged=$(git -C "$repo" diff --cached --name-only | sort | tr '\n' ' ')
expected="docs/hyperpowers/decisions/2026-10-19-evidence-a-scenario-then-a-field-rerun.md docs/hyperpowers/decisions/2026-10-19-skill-text-not-a-hook.md docs/hyperpowers/decisions/README.md docs/hyperpowers/specs/2026-10-19-alpha-design.md "
if [ "$staged" = "$expected" ]; then pass "records, index and spec are staged"; else fail "staged set (got: $staged)"; fi
if [ "$(git -C "$repo" rev-list --count HEAD)" = "1" ]; then pass "no commit was made"; else fail "the compiler committed"; fi
case "$OUT" in
    *"paths: docs/hyperpowers/decisions/2026-10-19-evidence-a-scenario-then-a-field-rerun.md docs/hyperpowers/decisions/2026-10-19-skill-text-not-a-hook.md docs/hyperpowers/decisions/README.md docs/hyperpowers/specs/2026-10-19-alpha-design.md"*) pass "paths: line lists the staged set" ;;
    *) fail "paths: line (got: $(printf '%s\n' "$OUT" | grep '^paths:'))" ;;
esac
if [ "$(tr '\0' '\n' < "$TEST_ROOT/stage.paths" | sort | tr '\n' ' ')" = "$staged" ]; then pass "--paths-file holds the same set, NUL-delimited"; else fail "paths file (got: $(tr '\0' ' ' < "$TEST_ROOT/stage.paths"))"; fi
commit_all "$repo" "records"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --paths-file "$TEST_ROOT/stage2.paths"
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a second run changes nothing"; else fail "second run (rc $RC, status: $(git -C "$repo" status --porcelain))"; fi
case "$OUT" in
    *$'\n'"paths: "*) fail "paths: line not empty on an unchanged run" ;;
    *"paths:"*) pass "paths: line is empty when nothing changed" ;;
    *) fail "paths: line missing" ;;
esac
if [ ! -s "$TEST_ROOT/stage2.paths" ]; then pass "the paths file is empty when nothing changed"; else fail "paths file not empty"; fi
printf '3. **A third one.** Added later.\n' >> "$spec"
COMPILE_DATE=2026-10-23 run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md
if [ "$(sed -n 3p "$spec")" = "**Outcome:** implemented 2026-10-21; 3 decisions under docs/hyperpowers/decisions/." ]; then pass "the Outcome line keeps its date and takes the new count"; else fail "Outcome after add (got: $(sed -n 3p "$spec"))"; fi
if [ "$(grep -c '^\*\*Outcome:\*\*' "$spec")" = "1" ]; then pass "the Outcome line is not duplicated"; else fail "Outcome line duplicated"; fi
# A retry after a failed first attempt: the files exist unstaged, and the
# next run must stage them even though it changes nothing.
commit_all "$repo" "records 2"
git -C "$repo" rm -q --cached docs/hyperpowers/decisions/2026-10-19-a-third-one.md
git -C "$repo" commit -q -m "simulate: record written but never staged"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md
if git -C "$repo" diff --cached --name-only | grep -q '2026-10-19-a-third-one.md'; then pass "a run stages a compiler-owned file an earlier run wrote but never staged"; else fail "unstaged file not picked up (staged: $(git -C "$repo" diff --cached --name-only | tr '\n' ' '))"; fi
case "$OUT" in *"paths: docs/hyperpowers/decisions/2026-10-19-a-third-one.md"*) pass "paths: carries the inherited staged file" ;; *) fail "paths after inherited staging (got: $(printf '%s\n' "$OUT" | grep '^paths:'))" ;; esac
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --dry-run
case "$OUT" in *"paths: "*"2026-10-19-a-third-one.md"*) pass "dry run prints the paths it would stage" ;; *) fail "dry-run paths (got: $OUT)" ;; esac

# --- 12. index escaping and a spec without a title -------------------------
repo="$TEST_ROOT/escape"
make_repo "$repo"
write_spec "$repo" 2026-06-06-esc-design.md <<'EOF'
No title line here.

## Decisions

- **Pipes | and [brackets] survive.** Text.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-06-06-esc-design.md
if grep -q '\[Pipes \\| and \\\[brackets\\\] survive\]' "$repo/docs/hyperpowers/decisions/README.md"; then pass "index escapes | [ ] in the title"; else fail "index escaping (got: $(grep Pipes "$repo/docs/hyperpowers/decisions/README.md"))"; fi
if [ "$(sed -n 1p "$repo/docs/hyperpowers/specs/2026-06-06-esc-design.md")" = "**Outcome:** implemented 2026-10-21; 1 decisions under docs/hyperpowers/decisions/." ]; then pass "a spec without a title gets the Outcome line first"; else fail "Outcome placement without a title (got: $(sed -n 1p "$repo/docs/hyperpowers/specs/2026-06-06-esc-design.md"))"; fi
run_compile "$repo" docs/hyperpowers/specs/2026-06-06-esc-design.md --dry-run --dry-run
if [ "$RC" -eq 2 ]; then pass "a repeated option is a usage error"; else fail "repeated --dry-run (got $RC)"; fi

# --- 12b. a symlinked records directory is refused (correction 2026-10-22) ----
repo="$TEST_ROOT/symlinked"
make_repo "$repo"
mkdir -p "$TEST_ROOT/outside"
ln -s "$TEST_ROOT/outside" "$repo/docs/hyperpowers/decisions"
write_spec "$repo" 2026-09-09-link-design.md <<'EOF'
# Link

## Decisions

- **Would escape.** The records directory is a link to the outside.
EOF
commit_all "$repo" "spec and link"
run_compile "$repo" docs/hyperpowers/specs/2026-09-09-link-design.md
if [ "$RC" -eq 2 ]; then pass "a symlinked decisions directory exits 2"; else fail "symlinked decisions (rc $RC: $ERR)"; fi
case "$ERR" in "docs/hyperpowers/specs/2026-09-09-link-design.md: docs/hyperpowers/decisions exists but is not a plain directory"*) pass "the symlink message names the spec and the rule" ;; *) fail "symlink message (got: $ERR)" ;; esac
if [ -z "$(ls -A "$TEST_ROOT/outside")" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "nothing is written through the link"; else fail "something was written outside: $(ls -A "$TEST_ROOT/outside")"; fi

# --- 12b-2. a dangling decisions link is refused (fix round 1) ------------------
repo="$TEST_ROOT/dangling"
make_repo "$repo"
ln -s "$TEST_ROOT/no-such-dir" "$repo/docs/hyperpowers/decisions"
write_spec "$repo" 2026-09-10-dangle-design.md <<'EOF'
# Dangle

## Decisions

- **Would fail late.** The records directory is a dangling link.
EOF
commit_all "$repo" "spec and dangling link"
run_compile "$repo" docs/hyperpowers/specs/2026-09-10-dangle-design.md
if [ "$RC" -eq 2 ]; then pass "a dangling decisions link exits 2"; else fail "dangling decisions (rc $RC: $ERR)"; fi
case "$ERR" in "docs/hyperpowers/specs/2026-09-10-dangle-design.md: docs/hyperpowers/decisions exists but is not a plain directory"*) pass "the dangling-link message names the spec and the rule" ;; *) fail "dangling-link message (got: $ERR)" ;; esac
if [ ! -e "$TEST_ROOT/no-such-dir" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "nothing is written for a dangling link"; else fail "dangling link wrote something"; fi

# --- 12c. a --paths-file that is not a safe scratch file is refused -----------
repo="$TEST_ROOT/pathsfile"
make_repo "$repo"
write_spec "$repo" 2026-09-11-pf-design.md <<'EOF'
# Pf

## Decisions

- **One thing.** Text.
EOF
commit_all "$repo" "spec"
pf_spec=docs/hyperpowers/specs/2026-09-11-pf-design.md
mkdir -p "$TEST_ROOT/links"
echo plain > "$TEST_ROOT/links/real"
ln -s "$TEST_ROOT/links/real" "$TEST_ROOT/links/sym.paths"
before=$(cksum < "$repo/$pf_spec")
for case_name in directory symlink inside; do
    case "$case_name" in
        directory) dest="$TEST_ROOT" ;;
        symlink) dest="$TEST_ROOT/links/sym.paths" ;;
        inside) dest="$repo/$pf_spec" ;;
    esac
    run_compile "$repo" "$pf_spec" --paths-file "$dest"
    case "$ERR" in "$pf_spec: "*) msg_ok=yes ;; *) msg_ok=no ;; esac
    if [ "$RC" -eq 2 ] && [ "$msg_ok" = yes ] && [ -z "$(git -C "$repo" status --porcelain)" ] && [ "$(cksum < "$repo/$pf_spec")" = "$before" ]; then
        pass "a $case_name --paths-file exits 2 before any write"
    else
        fail "$case_name --paths-file (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"
    fi
done
if [ "$(cat "$TEST_ROOT/links/real")" = plain ]; then pass "the symlink target is untouched"; else fail "symlink target overwritten"; fi

# --- 13. spec names are literal pathspecs (fix round 2) ----------------------
repo="$TEST_ROOT/literal"
make_repo "$repo"
lit_spec='docs/hyperpowers/specs/2026-10-19-a[1]-design.md'
write_spec "$repo" '2026-10-19-a[1]-design.md' <<'EOF'
# Bracketed

## Decisions

1. **First literal.** Text.
2. **Second literal.** Text.
EOF
echo unrelated > "$repo/docs/hyperpowers/specs/2026-10-19-a1-design.md"
commit_all "$repo" "bracketed spec and a lookalike"
echo changed >> "$repo/docs/hyperpowers/specs/2026-10-19-a1-design.md"
run_compile "$repo" "$lit_spec" --paths-file "$TEST_ROOT/literal.paths"
if [ "$RC" -eq 0 ]; then pass "a bracketed spec name compiles"; else fail "bracketed compile (rc $RC: $ERR)"; fi
lit_staged=$(git -C "$repo" diff --cached --name-only)
case "$lit_staged" in *"$lit_spec"*) pass "the bracketed spec is staged" ;; *) fail "bracketed spec not staged (got: $lit_staged)" ;; esac
case "$lit_staged" in *2026-10-19-a1-design.md*) fail "the lookalike file was staged" ;; *) pass "the lookalike file is not staged" ;; esac
lit_paths=$(tr '\0' '\n' < "$TEST_ROOT/literal.paths")
case "$lit_paths" in *"$lit_spec"*) pass "the paths file names the bracketed spec" ;; *) fail "paths file lacks the spec (got: $lit_paths)" ;; esac
case "$lit_paths" in *2026-10-19-a1-design.md*) fail "the paths file names the lookalike" ;; *) pass "the paths file omits the lookalike" ;; esac
case "$(git -C "$repo" status --porcelain)" in *" M docs/hyperpowers/specs/2026-10-19-a1-design.md"*) pass "the lookalike stays modified and unstaged" ;; *) fail "lookalike status (got: $(git -C "$repo" status --porcelain))" ;; esac
run_compile "$repo" "$lit_spec" --dry-run
case "$(printf '%s\n' "$OUT" | grep '^paths:')" in *2026-10-19-a1-design.md*) fail "dry-run paths name the lookalike" ;; *) pass "dry-run paths omit the lookalike" ;; esac

# --- 14. an index destination that is not a regular file is refused (fix round 2) ---
repo="$TEST_ROOT/indexdest"
make_repo "$repo"
write_spec "$repo" 2026-09-12-idx-design.md <<'EOF'
# Idx

## Decisions

- **One thing.** Text.
EOF
commit_all "$repo" "spec"
idx_spec=docs/hyperpowers/specs/2026-09-12-idx-design.md
mkdir -p "$repo/docs/hyperpowers/decisions/README.md"
run_compile "$repo" "$idx_spec"
case "$ERR" in "$idx_spec: docs/hyperpowers/decisions/README.md exists but is not a regular file"*) msg_ok=yes ;; *) msg_ok=no ;; esac
if [ "$RC" -eq 2 ] && [ "$msg_ok" = yes ] && [ "$(ls -A "$repo/docs/hyperpowers/decisions")" = README.md ] && [ -z "$(ls -A "$repo/docs/hyperpowers/decisions/README.md")" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then
    pass "a directory at the index path exits 2 and writes nothing"
else
    fail "directory index (rc $RC, err: $ERR, files: $(ls -A "$repo/docs/hyperpowers/decisions"))"
fi
rmdir "$repo/docs/hyperpowers/decisions/README.md"
mkdir -p "$TEST_ROOT/outside-index"
ln -s "$TEST_ROOT/outside-index" "$repo/docs/hyperpowers/decisions/README.md"
commit_all "$repo" "index link"
run_compile "$repo" "$idx_spec"
case "$ERR" in "$idx_spec: docs/hyperpowers/decisions/README.md exists but is not a regular file"*) msg_ok=yes ;; *) msg_ok=no ;; esac
if [ "$RC" -eq 2 ] && [ "$msg_ok" = yes ] && [ -z "$(ls -A "$TEST_ROOT/outside-index")" ] && [ "$(ls -A "$repo/docs/hyperpowers/decisions")" = README.md ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then
    pass "a symlinked index path exits 2 and writes nothing"
else
    fail "symlink index (rc $RC, err: $ERR, outside: $(ls -A "$TEST_ROOT/outside-index"))"
fi
rm "$repo/docs/hyperpowers/decisions/README.md"

# --- 15. supersession --------------------------------------------------------
repo="$TEST_ROOT/supersede"
make_repo "$repo"
write_spec "$repo" 2026-07-01-old-design.md <<'EOF'
# Old

## Decisions

- **Hook-based interlock.** A hook gates the first edit.
- **Twenty-run bar.** Forty sessions per scenario.
EOF
commit_all "$repo" "old spec"
run_compile "$repo" docs/hyperpowers/specs/2026-07-01-old-design.md
commit_all "$repo" "old records"
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

1. **Skill text, not a hook.** Measured no gain from the hook.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
2. **Still no hook.** A second reversal of the same record.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md, docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
EOF
commit_all "$repo" "new spec"
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
if [ "$RC" -eq 0 ]; then pass "supersession compile exits 0"; else fail "supersession exit (got $RC: $ERR)"; fi
old="$repo/docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md"
if grep -q '^- Status: superseded by docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md, docs/hyperpowers/decisions/2026-08-01-still-no-hook.md$' "$old"; then
    pass "two new decisions superseding one record list both, sorted, in one status line"
else
    fail "fan-in status (got: $(grep '^- Status' "$old"))"
fi
case "$OUT" in *"superseded 1,"*) pass "summary counts one superseded target" ;; *) fail "superseded count (got: $(printf '%s\n' "$OUT" | head -n 1))" ;; esac
case "$OUT" in *"updated docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md (superseded by "*) pass "the target's verb line" ;; *) fail "target verb line missing" ;; esac
if grep -q '^- Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md$' "$repo/docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md"; then
    pass "the new record carries its Supersedes line (duplicates collapsed)"
else
    fail "Supersedes line (got: $(grep '^- Supersedes' "$repo/docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md"))"
fi
idx="$repo/docs/hyperpowers/decisions/README.md"
if grep -q '^3 current, 1 superseded\.$' "$idx" && grep -q '^## Superseded' "$idx" && [ "$(grep -c '^| 2026-0[78]-01 | \[' "$idx")" = "4" ]; then
    pass "index: three current rows, one superseded row, both tables"
else
    fail "index after supersession:"; sed 's/^/        /' "$idx"
fi
commit_all "$repo" "new records"
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a re-run with Supersedes lines changes nothing"; else fail "supersession re-run (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
# Before the freeze a Supersedes line can be removed or retargeted; the old
# target must follow.
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

1. **Skill text, not a hook.** Measured no gain from the hook.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md
2. **Still no hook.** A second reversal, no longer superseding anything.
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
if grep -q '^- Status: accepted$' "$old"; then pass "a target nothing names any more returns to accepted"; else fail "stale supersession left on the old target: $(grep '^- Status' "$old")"; fi
if grep -q '^- Status: superseded by docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md$' "$repo/docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md"; then pass "a retargeted Supersedes line supersedes the new target"; else fail "retarget (got: $(grep '^- Status' "$repo/docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md"))"; fi
if ! grep -q '^- Supersedes:' "$repo/docs/hyperpowers/decisions/2026-08-01-still-no-hook.md"; then pass "the record whose line was removed loses its Supersedes line"; else fail "Supersedes line not removed from record 2"; fi
case "$OUT" in *"superseded 2,"*) pass "both status changes are counted" ;; *) fail "reconciliation count (got: $(printf '%s\n' "$OUT" | head -n 1))" ;; esac
commit_all "$repo" "retargeted"
for bad in "docs/hyperpowers/decisions/2026-07-01-nope.md" "docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md"; do
    write_spec "$repo" 2026-09-01-bad-design.md <<EOF
# Bad

## Decisions

- **Reverses something.** Text.
  Supersedes: $bad
EOF
    run_compile "$repo" docs/hyperpowers/specs/2026-09-01-bad-design.md
    if [ "$RC" -eq 2 ] && [ "$(git -C "$repo" status --porcelain | grep -vc 'bad-design')" = 0 ]; then
        pass "Supersedes violation exits 2 and writes nothing ($bad: missing, or already superseded by an unrelated record)"
    else
        fail "violation $bad (rc $RC, err: $ERR)"
    fi
done
rm -f "$repo/docs/hyperpowers/specs/2026-09-01-bad-design.md"
write_spec "$repo" 2026-09-02-self-design.md <<'EOF'
# Self

## Decisions

- **First.** Text.
- **Second.** Text.
EOF
commit_all "$repo" "self spec"
run_compile "$repo" docs/hyperpowers/specs/2026-09-02-self-design.md
commit_all "$repo" "self records"
tree_before=$(git -C "$repo" write-tree)
write_spec "$repo" 2026-09-02-self-design.md <<'EOF'
# Self

## Decisions

- **First.** Text.
- **Second.** Text.
  Supersedes: docs/hyperpowers/decisions/2026-09-02-first.md
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-09-02-self-design.md
if [ "$RC" -eq 2 ]; then pass "a record of the same spec cannot be superseded"; else fail "same-spec supersession (rc $RC)"; fi
case "$ERR" in *"cannot supersede a record of this spec"*) pass "the same-spec rule is the one that fired" ;; *) fail "same-spec message (got: $ERR)" ;; esac
git -C "$repo" add -A docs/hyperpowers/decisions
if [ "$(git -C "$repo" write-tree)" = "$tree_before" ] || [ -z "$(git -C "$repo" status --porcelain -- docs/hyperpowers/decisions)" ]; then pass "the records directory is byte-identical after the refused run"; else fail "records changed by a refused run"; fi
git -C "$repo" checkout -q -- docs/hyperpowers/specs/2026-09-02-self-design.md

# --- 16. --reindex ------------------------------------------------------------
rm "$idx"
run_compile "$repo" --reindex docs/hyperpowers/decisions
if [ "$RC" -eq 0 ] && [ -f "$idx" ] && [ "$(git -C "$repo" status --porcelain | grep -vc README.md)" = 0 ]; then pass "--reindex rewrites only README.md"; else fail "--reindex (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
case "$OUT" in "wrote docs/hyperpowers/decisions/README.md"*) pass "--reindex reports the index it wrote" ;; *) fail "--reindex output (got: $OUT)" ;; esac
run_compile "$repo" --reindex docs/hyperpowers/decisions --dry-run
if [ "$RC" -eq 2 ]; then pass "--reindex with another option is a usage error"; else fail "--reindex --dry-run (got $RC)"; fi
run_compile "$repo" --reindex docs/hyperpowers/decisions docs/hyperpowers/specs/2026-08-01-new-design.md
if [ "$RC" -eq 2 ]; then pass "--reindex with a spec is a usage error"; else fail "--reindex with spec (got $RC)"; fi

# --- 17. a symlinked spec is refused -----------------------------------------
# Correction (2026-10-22): Task 2's gate found at its cap that a spec which is
# itself a symbolic link passes -f and is replaced by a regular file when the
# Outcome line is written, leaving its target without the line; the human
# partner carried the guard and this test into Task 3.
repo="$TEST_ROOT/linkspec"
make_repo "$repo"
write_spec "$repo" 2026-09-01-real-design.md <<'EOF'
# Real

## Decisions

- **One decision.** A decision.
EOF
ln -s 2026-09-01-real-design.md "$repo/docs/hyperpowers/specs/2026-09-01-link-design.md"
commit_all "$repo" "spec and link"
before=$(cksum < "$repo/docs/hyperpowers/specs/2026-09-01-real-design.md")
run_compile "$repo" docs/hyperpowers/specs/2026-09-01-link-design.md
if [ "$RC" -eq 2 ]; then pass "a symlinked spec exits 2"; else fail "symlinked spec (got $RC: $ERR)"; fi
case "$ERR" in "docs/hyperpowers/specs/2026-09-01-link-design.md: "*) pass "the symlinked-spec message begins with the spec path" ;; *) fail "symlinked-spec message (got: $ERR)" ;; esac
if [ -L "$repo/docs/hyperpowers/specs/2026-09-01-link-design.md" ] && [ "$(cksum < "$repo/docs/hyperpowers/specs/2026-09-01-real-design.md")" = "$before" ] && [ ! -e "$repo/docs/hyperpowers/decisions" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then
    pass "the link, its target and the tree are unchanged"
else
    fail "a symlinked spec changed the tree (status: $(git -C "$repo" status --porcelain))"
fi

# >>> later tasks append their checks above this line <<<

if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
