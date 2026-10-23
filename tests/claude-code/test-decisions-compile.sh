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
# Each spec's records are committed before the next spec compiles: another
# compile's staged records are a foreign change under the records directory
# (§31), so the collision under test is a committed name, not a staged one.
commit_all "$repo" "one's records"
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
# The spec and the second compile's records are committed, so the refusal
# under test is the collision and neither an uncommitted spec nor a foreign
# change under the records directory.
commit_all "$repo" "third spec and two's records"
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
# The hand-made file is committed, because a foreign change left uncommitted
# under the records directory is refused by the ownership preflight (§31).
repo="$TEST_ROOT/handmade"
make_repo "$repo"
write_spec "$repo" 2026-09-09-hand-design.md <<'EOF'
# Hand

## Decisions

- **Taken name.** The record is deleted, then its name is reused by hand.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-09-09-hand-design.md
commit_all "$repo" "records"
hand="$repo/docs/hyperpowers/decisions/2026-09-09-taken-name.md"
rm "$hand"
printf '# Other\n\n- Status: accepted\n- Spec: docs/hyperpowers/specs/other.md (decision 1)\n- Recorded: 2026-09-01\n\n## Decision\n\nHand made.\n' > "$hand"
commit_all "$repo" "a hand-made file takes the record's name"
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

# An interrupted run can leave the targets reconciled while the records still
# carry their old Supersedes lines; the re-run must finish the job. The state
# is built by hand: decision 1 moves from the hook record to the twenty-run bar.
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

1. **Skill text, not a hook.** Measured no gain from the hook.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
2. **Still no hook.** A second reversal of the same record.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
commit_all "$repo" "fan-in again"
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

1. **Skill text, not a hook.** Measured no gain from the hook.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md
2. **Still no hook.** A second reversal of the same record.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
EOF
commit_all "$repo" "decision 1 retargeted"
twenty="$repo/docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md"
sed 's|^- Status: .*|- Status: superseded by docs/hyperpowers/decisions/2026-08-01-still-no-hook.md|' "$old" > "$TEST_ROOT/old.new" && cp "$TEST_ROOT/old.new" "$old"
sed 's|^- Status: .*|- Status: superseded by docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md|' "$twenty" > "$TEST_ROOT/twenty.new" && cp "$TEST_ROOT/twenty.new" "$twenty"
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
rec1="$repo/docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md"
if [ "$RC" -eq 0 ] && grep -q '^- Supersedes: docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md$' "$rec1"; then pass "the interrupted-run state: the record takes its new Supersedes line"; else fail "interrupted-run state (rc $RC, err: $ERR, got: $(grep '^- Supersedes' "$rec1"))"; fi
if [ "$(grep '^- Status' "$old")" = "- Status: superseded by docs/hyperpowers/decisions/2026-08-01-still-no-hook.md" ]; then pass "the old target is superseded by decision 2 only"; else fail "old target status (got: $(grep '^- Status' "$old"))"; fi
if [ "$(grep '^- Status' "$twenty")" = "- Status: superseded by docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md" ]; then pass "the new target is superseded by decision 1"; else fail "new target status (got: $(grep '^- Status' "$twenty"))"; fi
commit_all "$repo" "interrupted state completed"
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
case "$OUT" in "wrote 0 records, updated 0, superseded 0,"*) out_ok=yes ;; *) out_ok=no ;; esac
if [ "$RC" -eq 0 ] && [ "$out_ok" = yes ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a second run reports nothing changed"; else fail "second run (rc $RC, out: $OUT, status: $(git -C "$repo" status --porcelain))"; fi

# Incremental fan-in: a third decision joins two that already supersede the
# hook record.
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

1. **Skill text, not a hook.** Measured no gain from the hook.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
2. **Still no hook.** A second reversal of the same record.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
commit_all "$repo" "two superseders"
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

1. **Skill text, not a hook.** Measured no gain from the hook.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
2. **Still no hook.** A second reversal of the same record.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
3. **Third reversal.** A third.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
if [ "$RC" -eq 0 ] && [ "$(grep '^- Status' "$old")" = "- Status: superseded by docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md, docs/hyperpowers/decisions/2026-08-01-still-no-hook.md, docs/hyperpowers/decisions/2026-08-01-third-reversal.md" ]; then
    pass "a later decision of the same spec joins an existing fan-in, sorted"
else
    fail "incremental fan-in (rc $RC, err: $ERR, got: $(grep '^- Status' "$old"))"
fi
commit_all "$repo" "three superseders"

# A swap of two decisions' targets, before the freeze.
srepo="$TEST_ROOT/swap"
make_repo "$srepo"
write_spec "$srepo" 2026-07-01-targets-design.md <<'EOF'
# Targets

## Decisions

- **Alpha choice.** A.
- **Beta choice.** B.
EOF
commit_all "$srepo" "targets spec"
run_compile "$srepo" docs/hyperpowers/specs/2026-07-01-targets-design.md
commit_all "$srepo" "targets records"
write_spec "$srepo" 2026-08-01-swap-design.md <<'EOF'
# Swap

## Decisions

1. **Replace A.** Text.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-alpha-choice.md
2. **Replace B.** Text.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-beta-choice.md
EOF
run_compile "$srepo" docs/hyperpowers/specs/2026-08-01-swap-design.md
commit_all "$srepo" "swap records"
write_spec "$srepo" 2026-08-01-swap-design.md <<'EOF'
# Swap

## Decisions

1. **Replace A.** Text.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-beta-choice.md
2. **Replace B.** Text.
   Supersedes: docs/hyperpowers/decisions/2026-07-01-alpha-choice.md
EOF
run_compile "$srepo" docs/hyperpowers/specs/2026-08-01-swap-design.md
if [ "$RC" -eq 0 ] && [ "$(grep '^- Status' "$srepo/docs/hyperpowers/decisions/2026-07-01-alpha-choice.md")" = "- Status: superseded by docs/hyperpowers/decisions/2026-08-01-replace-b.md" ] && [ "$(grep '^- Status' "$srepo/docs/hyperpowers/decisions/2026-07-01-beta-choice.md")" = "- Status: superseded by docs/hyperpowers/decisions/2026-08-01-replace-a.md" ]; then
    pass "swapping two decisions' Supersedes lines swaps the targets' statuses"
else
    fail "swap (rc $RC, err: $ERR)"
fi

# --- 16. --reindex ------------------------------------------------------------
rm "$idx"
run_compile "$repo" --reindex docs/hyperpowers/decisions
if [ "$RC" -eq 0 ] && [ -f "$idx" ] && [ "$(git -C "$repo" status --porcelain | grep -vc README.md)" = 0 ]; then pass "--reindex rewrites only README.md"; else fail "--reindex (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
case "$OUT" in "wrote docs/hyperpowers/decisions/README.md"*) pass "--reindex reports the index it wrote" ;; *) fail "--reindex output (got: $OUT)" ;; esac
commit_all "$repo" "index"
run_compile "$repo" --reindex docs/hyperpowers/decisions
case "$OUT" in "unchanged docs/hyperpowers/decisions/README.md"*) if [ "$RC" -eq 0 ]; then pass "a second --reindex on a clean tree reports unchanged"; else fail "second --reindex rc $RC"; fi ;; *) fail "second --reindex output (got: $OUT)" ;; esac
# A written-but-unstaged index, as left by a failed git add, must be staged on retry.
git -C "$repo" rm --cached -q docs/hyperpowers/decisions/README.md
if [ -n "$(git -C "$repo" status --porcelain)" ]; then pass "fixture: the index is written but unstaged"; else fail "fixture: status is clean after rm --cached"; fi
run_compile "$repo" --reindex docs/hyperpowers/decisions
case "$OUT" in "unchanged docs/hyperpowers/decisions/README.md"*) out_ok=yes ;; *) out_ok=no ;; esac
if [ "$RC" -eq 0 ] && [ "$out_ok" = yes ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "--reindex re-stages an unchanged index"; else fail "--reindex retry (rc $RC, out: $OUT, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
run_compile "$repo" --reindex docs/hyperpowers/decisions --dry-run
if [ "$RC" -eq 2 ]; then pass "--reindex with another option is a usage error"; else fail "--reindex --dry-run (got $RC)"; fi
run_compile "$repo" --reindex docs/hyperpowers/decisions docs/hyperpowers/specs/2026-08-01-new-design.md
if [ "$RC" -eq 2 ]; then pass "--reindex with a spec is a usage error"; else fail "--reindex with spec (got $RC)"; fi
run_compile "$repo" --reindex docs/hyperpowers/specs
if [ "$RC" -eq 2 ] && [ ! -e "$repo/docs/hyperpowers/specs/README.md" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "--reindex refuses a directory not named decisions"; else fail "--reindex of specs (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
case "$ERR" in "docs/hyperpowers/specs: not a records directory (its name must be decisions)") pass "the refusal names the directory rule" ;; *) fail "--reindex specs message (got: $ERR)" ;; esac

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

# --- 18. Supersedes targets are canonical, regular records -------------------
repo="$TEST_ROOT/canon"
make_repo "$repo"
write_spec "$repo" 2026-07-01-old-design.md <<'EOF'
# Old

## Decisions

- **Alpha choice.** A.
- **Beta choice.** B.
EOF
commit_all "$repo" "old spec"
run_compile "$repo" docs/hyperpowers/specs/2026-07-01-old-design.md
commit_all "$repo" "old records"
write_spec "$repo" 2026-08-01-dot-design.md <<'EOF'
# Dot

## Decisions

- **Reverses alpha.** Text.
  Supersedes: docs/hyperpowers/decisions/./2026-07-01-alpha-choice.md
EOF
commit_all "$repo" "dot spec"
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-dot-design.md
case "$ERR" in *"is not a record in docs/hyperpowers/decisions"*) msg_ok=yes ;; *) msg_ok=no ;; esac
if [ "$RC" -eq 2 ] && [ "$msg_ok" = yes ] && [ -z "$(git -C "$repo" status --porcelain)" ] && [ "$(find "$repo/docs/hyperpowers/decisions" -type f | wc -l | tr -d ' ')" = 3 ]; then
    pass "a non-canonical Supersedes spelling exits 2 and writes nothing"
else
    fail "dot spelling (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"
fi
ln -s 2026-07-01-alpha-choice.md "$repo/docs/hyperpowers/decisions/2026-07-01-alias.md"
write_spec "$repo" 2026-08-01-dot-design.md <<'EOF'
# Dot

## Decisions

- **Reverses the alias.** Text.
  Supersedes: docs/hyperpowers/decisions/2026-07-01-alias.md
EOF
commit_all "$repo" "alias and spec"
before=$(cksum < "$repo/docs/hyperpowers/decisions/2026-07-01-alpha-choice.md")
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-dot-design.md
case "$ERR" in *"symbolic link"*) msg_ok=yes ;; *) msg_ok=no ;; esac
if [ "$RC" -eq 2 ] && [ "$msg_ok" = yes ] && [ -L "$repo/docs/hyperpowers/decisions/2026-07-01-alias.md" ] && [ "$(cksum < "$repo/docs/hyperpowers/decisions/2026-07-01-alpha-choice.md")" = "$before" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then
    pass "a symbolic link as a Supersedes target exits 2 and leaves link and referent alone"
else
    fail "alias target (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"
fi

# An interrupted run leaves a target naming a record that is not written yet;
# the retry must accept it and finish.
write_spec "$repo" 2026-09-15-fresh-design.md <<'EOF'
# Fresh

## Decisions

- **Fresh reversal.** Text.
  Supersedes: docs/hyperpowers/decisions/2026-07-01-beta-choice.md
EOF
beta="$repo/docs/hyperpowers/decisions/2026-07-01-beta-choice.md"
sed 's|^- Status: .*|- Status: superseded by docs/hyperpowers/decisions/2026-09-15-fresh-reversal.md|' "$beta" > "$TEST_ROOT/beta.new" && cp "$TEST_ROOT/beta.new" "$beta"
commit_all "$repo" "fresh spec, target already marked"
run_compile "$repo" docs/hyperpowers/specs/2026-09-15-fresh-design.md
fresh="$repo/docs/hyperpowers/decisions/2026-09-15-fresh-reversal.md"
if [ "$RC" -eq 0 ] && grep -q '^- Supersedes: docs/hyperpowers/decisions/2026-07-01-beta-choice.md$' "$fresh" && [ "$(grep '^- Status' "$beta")" = "- Status: superseded by docs/hyperpowers/decisions/2026-09-15-fresh-reversal.md" ]; then
    pass "a target already naming this run's unwritten record is accepted and kept"
else
    fail "unwritten superseder (rc $RC, err: $ERR, status: $(grep '^- Status' "$beta"))"
fi
commit_all "$repo" "fresh records"
run_compile "$repo" docs/hyperpowers/specs/2026-09-15-fresh-design.md
case "$OUT" in "wrote 0 records, updated 0, superseded 0,"*) out_ok=yes ;; *) out_ok=no ;; esac
if [ "$RC" -eq 0 ] && [ "$out_ok" = yes ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a second run after the retry changes nothing"; else fail "fresh second run (rc $RC, out: $OUT, status: $(git -C "$repo" status --porcelain))"; fi

# --- 19. notes ----------------------------------------------------------------
repo="$TEST_ROOT/notes"
make_repo "$repo"
write_spec "$repo" 2026-10-19-alpha-design.md <<'EOF'
# Alpha

## Decisions

1. **Skill text, not a hook.** The rules live in the skill.
2. **Evidence: a scenario, then a field rerun.** Two sources.
EOF
commit_all "$repo" "spec"
cat > "$TEST_ROOT/notes-good.md" <<'EOF'
# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md

## Decision 1
The turn-ending rule landed in SKILL.md's "Continuous execution" paragraph
and the Stop hook was never written; test-sdd-contract.sh covers the rule.

## Decision 2
No change.

## Supersessions
- 1 supersedes docs/hyperpowers/decisions/2026-09-17-first-edit-interlock-hook.md

## Undocumented decisions
- The field classifier reads the ledger, not the transcript.
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --notes "$TEST_ROOT/notes-good.md"
if [ "$RC" -eq 0 ]; then pass "notes compile exits 0"; else fail "notes exit (got $RC: $ERR)"; fi
rec1="$repo/docs/hyperpowers/decisions/2026-10-19-skill-text-not-a-hook.md"
rec2="$repo/docs/hyperpowers/decisions/2026-10-19-evidence-a-scenario-then-a-field-rerun.md"
if grep -q '^The turn-ending rule landed' "$rec1" && grep -q '^- Recorded: 2026-10-21; notes from the branch diff by a subagent at finish$' "$rec1"; then pass "a decision with notes gets the body and the Recorded notes part"; else fail "notes body or Recorded part (got: $(grep '^- Recorded' "$rec1"))"; fi
if grep -q '^No change\.$' "$rec2"; then pass "a No change section is recorded as such"; else fail "record 2 body"; fi
case "$OUT" in *"undocumented 1, proposed supersessions 1,"*) pass "proposals are counted" ;; *) fail "proposal counts (got: $(printf '%s\n' "$OUT" | head -n 1))" ;; esac
if grep -q 'first-edit-interlock-hook' "$rec1" || grep -rq 'field classifier' "$repo/docs/hyperpowers/decisions"; then fail "a proposal reached a record"; else pass "proposals are never written to records"; fi
if grep -q '^- Supersedes:' "$rec1"; then fail "a notes supersession was applied"; else pass "a notes supersession is not applied"; fi
commit_all "$repo" "records"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a re-run without notes leaves recorded notes alone"; else fail "re-run without notes (status: $(git -C "$repo" status --porcelain))"; fi
cat > "$TEST_ROOT/notes-partial.md" <<'EOF'
# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md

## Decision 1
Replaced on the second pass.
EOF
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --notes "$TEST_ROOT/notes-partial.md"
case "$OUT" in "wrote 0 records, updated 1,"*) pass "notes for one decision update one record and leave the other alone" ;; *) fail "partial-notes summary (got: $(printf '%s\n' "$OUT" | head -n 1))" ;; esac
if grep -q '^Replaced on the second pass\.$' "$rec1" && grep -q '^No change\.$' "$rec2"; then pass "the mentioned section is replaced, the unmentioned one kept"; else fail "partial notes bodies"; fi
if ! git -C "$repo" diff --cached --name-only | grep -q specs/; then pass "a notes-only re-run does not touch the spec"; else fail "spec staged on a notes-only run"; fi
commit_all "$repo" "records 2"
for f in dup range head heading empty-optional; do
    case "$f" in
        dup) printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md\n\n## Decision 2\nA.\n\n## Decision 2\nB.\n' ;;
        range) printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md\n\n## Decision 7\nOut of range.\n' ;;
        head) printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-other-design.md\n\n## Decision 1\nText.\n' ;;
        heading) printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md\n\n## Decision 1\nText.\n\n## Remarks\nNot allowed.\n' ;;
        empty-optional) printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md\n\n## Decision 1\nText.\n\n## Supersessions\n' ;;
    esac > "$TEST_ROOT/notes-$f.md"
    run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --notes "$TEST_ROOT/notes-$f.md"
    if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "invalid notes ($f) are ignored and the run proceeds unchanged"; else fail "invalid notes $f (rc $RC, status: $(git -C "$repo" status --porcelain))"; fi
    case "$ERR" in "notes ignored: "*) pass "invalid notes ($f) reported as notes ignored" ;; *) fail "notes ignored message for $f (got: $ERR)" ;; esac
done
# Structure is any ATX heading, not only column-zero level-two lines, and the
# optional sections are checked in one pass however long they run.
for f in preamble indented wronglevel tabsup tabdec dupsup longsup; do
    {
        printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md\n\n'
        case "$f" in
            preamble) printf 'Some stray preamble.\n\n## Decision 1\nText.\n' ;;
            indented) printf '   ## Decision 1\nText.\n' ;;
            wronglevel) printf '## Decision 1\nText.\n\n### Supersessions\n- 1 supersedes docs/hyperpowers/decisions/x.md\n' ;;
            tabsup) printf '## Decision 1\nText.\n\n##\tSupersessions\n- 1 supersedes docs/hyperpowers/decisions/x.md\n' ;;
            tabdec) printf '## Decision 1\nText.\n\n##\tDecision 2\nsupersedes docs/hyperpowers/decisions/x.md\n' ;;
            dupsup) printf '## Decision 1\nText.\n\n## Supersessions\n- 1 supersedes docs/hyperpowers/decisions/x.md\n\n## Supersessions\n- 1 supersedes docs/hyperpowers/decisions/y.md\n' ;;
            longsup)
                printf '## Decision 1\nText.\n\n## Supersessions\nnot a proposal\n'
                for ((i = 0; i < 3000; i++)); do printf -- '- 1 supersedes docs/hyperpowers/decisions/x.md\n'; done
                ;;
        esac
    } > "$TEST_ROOT/notes-$f.md"
    run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --notes "$TEST_ROOT/notes-$f.md"
    if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "malformed notes ($f) are ignored and the records stay byte-identical"; else fail "malformed notes $f (rc $RC, status: $(git -C "$repo" status --porcelain))"; fi
    case "$ERR" in "notes ignored: "*) pass "malformed notes ($f) reported as notes ignored" ;; *) fail "notes ignored message for $f (got: $ERR)" ;; esac
    case "$f" in
        tabsup|tabdec) case "$ERR" in "notes ignored: unexpected heading: "*) pass "a tab-separated heading ($f) is an unexpected heading" ;; *) fail "tab heading message for $f (got: $ERR)" ;; esac ;;
    esac
    if grep -rq 'supersedes docs/hyperpowers/decisions/x.md' "$repo/docs/hyperpowers/decisions"; then fail "a proposal reached a record ($f)"; else pass "no proposal text reached a record ($f)"; fi
done
# An unreadable notes file fails open like every other notes defect.
printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-alpha-design.md\n\n## Decision 1\nText.\n' > "$TEST_ROOT/notes-unreadable.md"
chmod 000 "$TEST_ROOT/notes-unreadable.md"
if [ ! -r "$TEST_ROOT/notes-unreadable.md" ]; then
    run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --notes "$TEST_ROOT/notes-unreadable.md"
    case "$ERR" in "notes ignored: cannot read"*) if [ "$RC" -eq 0 ]; then pass "an unreadable notes file is ignored and the run exits 0"; else fail "unreadable notes rc $RC"; fi ;; *) fail "unreadable notes message (rc $RC, got: $ERR)" ;; esac
else
    pass "unreadable-notes check skipped: the file stayed readable after chmod 000"
fi
chmod 644 "$TEST_ROOT/notes-unreadable.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --notes "$TEST_ROOT/does-not-exist.md"
if [ "$RC" -eq 0 ]; then pass "a missing notes file is not an error"; else fail "missing notes file (rc $RC)"; fi
# An accepted undocumented decision is appended after the last item, so the
# numbering the notes use stays attached to the right records.
printf '3. **Appended at the menu.** An undocumented decision the human partner accepted.\n' >> "$repo/docs/hyperpowers/specs/2026-10-19-alpha-design.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-alpha-design.md --notes "$TEST_ROOT/notes-partial.md"
if grep -q '^Replaced on the second pass\.$' "$rec1" && grep -q '^No change\.$' "$rec2" && grep -q '^Nothing recorded\.$' "$repo/docs/hyperpowers/decisions/2026-10-19-appended-at-the-menu.md"; then
    pass "notes keyed by number stay with their records when a decision is appended"
else
    fail "numbering after append (rec1: $(grep -A2 '^## What' "$rec1" | tail -n 1); rec3: $(ls "$repo/docs/hyperpowers/decisions"))"
fi

# --- 20. persisted Supersedes paths are validated ----------------------------
# Correction (2026-10-22): Task 3's gate found at its cap that a record's own
# Supersedes header fed the reconciliation unvalidated, so a hand-edited or
# merge-conflicted record could name a file outside the records directory;
# the human partner carried the guard and this test into Task 4.
repo="$TEST_ROOT/persisted"
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
EOF
commit_all "$repo" "new spec"
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
commit_all "$repo" "new records"
rec="$repo/docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md"
awk '!r && /^- Supersedes: / { print "- Supersedes: ../hyperpowers/decisions/2026-07-01-hook-based-interlock.md"; r = 1; next } { print }' "$rec" > "$rec.tmp" && mv "$rec.tmp" "$rec"
commit_all "$repo" "hand-edited header: traversal"
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
if [ "$RC" -eq 2 ]; then pass "a persisted traversal path exits 2"; else fail "persisted traversal (got $RC: $ERR)"; fi
case "$ERR" in "docs/hyperpowers/specs/2026-08-01-new-design.md: decision 1: record docs/hyperpowers/decisions/2026-08-01-skill-text-not-a-hook.md names a Supersedes path that is not a record in docs/hyperpowers/decisions: ../hyperpowers/decisions/2026-07-01-hook-based-interlock.md") pass "the persisted-path message names the record and the path" ;; *) fail "persisted-path message (got: $ERR)" ;; esac
if [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "nothing is written for a persisted traversal path"; else fail "persisted traversal wrote (status: $(git -C "$repo" status --porcelain))"; fi
ln -s 2026-07-01-twenty-run-bar.md "$repo/docs/hyperpowers/decisions/alias.md"
awk '!r && /^- Supersedes: / { print "- Supersedes: docs/hyperpowers/decisions/alias.md"; r = 1; next } { print }' "$rec" > "$rec.tmp" && mv "$rec.tmp" "$rec"
commit_all "$repo" "hand-edited header: link"
sum=$(cksum < "$repo/docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md")
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md
if [ "$RC" -eq 2 ] && [ -L "$repo/docs/hyperpowers/decisions/alias.md" ] && [ "$(cksum < "$repo/docs/hyperpowers/decisions/2026-07-01-twenty-run-bar.md")" = "$sum" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then
    pass "a persisted symlinked path exits 2 with the link and its target untouched"
else
    fail "persisted link (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"
fi
case "$ERR" in *"names a Supersedes path that is a symbolic link: docs/hyperpowers/decisions/alias.md") pass "the persisted-link message names the path" ;; *) fail "persisted-link message (got: $ERR)" ;; esac

# --- 21. the plan, the pathspec commit, discovery, re-runs ------------------
repo="$TEST_ROOT/plan"
make_repo "$repo"
write_spec "$repo" "2026-10-19-with space-design.md" <<'EOF'
# Spaced

## Decisions

- **One decision.** Text.
EOF
commit_all "$repo" "spec"
printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-with space-design.md\n\n## Task 1\n' > "$repo/docs/hyperpowers/plans/2026-10-19-with-space.md"
commit_all "$repo" "plan"
plan_sha=$(git -C "$repo" rev-parse HEAD)
printf 'unrelated\n' > "$repo/other.txt"
git -C "$repo" add other.txt
run_compile "$repo" "docs/hyperpowers/specs/2026-10-19-with space-design.md" --plan docs/hyperpowers/plans/2026-10-19-nope.md
if [ "$RC" -eq 2 ] && [ "$(git -C "$repo" status --porcelain)" = "A  other.txt" ]; then pass "a plan that exists nowhere exits 2 before any write"; else fail "missing plan (rc $RC, status: $(git -C "$repo" status --porcelain | tr '\n' ';'))"; fi
run_compile "$repo" "docs/hyperpowers/specs/2026-10-19-with space-design.md" --plan docs/hyperpowers/plans/2026-10-19-with-space.md --paths-file "$TEST_ROOT/plan.paths"
if [ "$RC" -eq 0 ]; then pass "compile with --plan exits 0"; else fail "--plan exit (got $RC: $ERR)"; fi
case "$OUT" in *$'\n'"removed docs/hyperpowers/plans/2026-10-19-with-space.md"*) pass "removed <plan> line" ;; *) fail "removed line missing (got: $OUT)" ;; esac
if git -C "$repo" diff --cached --name-status | grep -q '^D.*2026-10-19-with-space.md$'; then pass "the plan's deletion is staged"; else fail "plan deletion not staged"; fi
rec="$repo/docs/hyperpowers/decisions/2026-10-19-one-decision.md"
if grep -q '^- Recorded: 2026-10-21; plan docs/hyperpowers/plans/2026-10-19-with-space.md removed at finish$' "$rec"; then pass "Recorded carries the plan part"; else fail "Recorded plan part (got: $(grep '^- Recorded' "$rec"))"; fi
if tr '\0' '\n' < "$TEST_ROOT/plan.paths" | grep -q '^docs/hyperpowers/specs/2026-10-19-with space-design.md$'; then pass "the paths file carries a path with a space intact"; else fail "paths file lost the spaced path"; fi
approval=()
while IFS= read -r -d '' pth; do approval+=("$pth"); done < "$TEST_ROOT/plan.paths"
( cd "$repo" && GIT_LITERAL_PATHSPECS=1 git diff --cached --name-only -- "${approval[@]}" > "$TEST_ROOT/approval.txt" )
if grep -q '2026-10-19-with space-design.md' "$TEST_ROOT/approval.txt" && ! grep -q other.txt "$TEST_ROOT/approval.txt"; then pass "the approval diff from the pathspec file covers the spaced path and not the unrelated file"; else fail "approval diff (got: $(tr '\n' ' ' < "$TEST_ROOT/approval.txt"))"; fi
( cd "$repo" && GIT_LITERAL_PATHSPECS=1 git commit -q --pathspec-from-file="$TEST_ROOT/plan.paths" --pathspec-file-nul -m "docs: record decisions for 2026-10-19-with space" )
if git -C "$repo" show --format= --name-only HEAD | grep -q '2026-10-19-with space-design.md' && [ "$(git -C "$repo" diff --cached --name-only)" = "other.txt" ]; then pass "the pathspec commit takes the spaced spec and leaves the unrelated staged file staged"; else fail "pathspec commit (committed: $(git -C "$repo" show --format= --name-only HEAD | tr '\n' ' '); staged: $(git -C "$repo" diff --cached --name-only))"; fi
git -C "$repo" reset -q other.txt && rm "$repo/other.txt"
rec_before=$(grep '^- Recorded' "$rec")
run_compile "$repo" "docs/hyperpowers/specs/2026-10-19-with space-design.md"
if [ "$RC" -eq 0 ] && [ "$(grep '^- Recorded' "$rec")" = "$rec_before" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a re-run without --plan keeps the Recorded plan part byte-identical and changes nothing"; else fail "re-run without --plan (rc $RC, before: $rec_before, after: $(grep '^- Recorded' "$rec"), status: $(git -C "$repo" status --porcelain))"; fi
# Discovery after the committed removal, as finishing Step 1 does it.
found=$(git -C "$repo" log --diff-filter=A --name-only --format= "$(git -C "$repo" rev-list --max-parents=0 HEAD)"..HEAD -- '*/plans/*.md')
if [ "$found" = "docs/hyperpowers/plans/2026-10-19-with-space.md" ]; then pass "history discovery finds the removed plan"; else fail "discovery (got: $found)"; fi
header=$(git -C "$repo" show "$plan_sha:docs/hyperpowers/plans/2026-10-19-with-space.md" | sed -n 's/^\*\*Spec:\*\* //p')
if [ "$header" = "docs/hyperpowers/specs/2026-10-19-with space-design.md" ]; then pass "the Spec header is read from the adding commit"; else fail "Spec header (got: $header)"; fi
run_compile "$repo" "docs/hyperpowers/specs/2026-10-19-with space-design.md" --plan docs/hyperpowers/plans/2026-10-19-with-space.md --paths-file "$TEST_ROOT/plan2.paths"
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ] && [ ! -s "$TEST_ROOT/plan2.paths" ]; then pass "a re-run after the committed removal changes nothing and the pathspec file is empty"; else fail "re-run after committed removal (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
case "$OUT" in *$'\n'"paths:" ) pass "paths: is empty after the committed removal" ;; *"paths:"*) if [ "$(printf '%s\n' "$OUT" | grep '^paths:')" = "paths:" ]; then pass "paths: is empty after the committed removal"; else fail "paths after committed removal (got: $(printf '%s\n' "$OUT" | grep '^paths:'))"; fi ;; *) fail "paths: line missing" ;; esac

# A plan removed, re-added and then deleted in the tree without staging is
# still in the index: its deletion must be staged, not mistaken for history.
repo="$TEST_ROOT/plan3"
make_repo "$repo"
write_spec "$repo" 2026-10-19-delta-design.md <<'EOF'
# Delta

## Decisions

- **Delta one.** Text.
EOF
printf '# Plan v1\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-delta-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-delta.md"
commit_all "$repo" "spec and plan"
git -C "$repo" rm -q docs/hyperpowers/plans/2026-10-19-delta.md && git -C "$repo" commit -q -m "remove plan"
mkdir -p "$repo/docs/hyperpowers/plans"
printf '# Plan v2\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-delta-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-delta.md"
commit_all "$repo" "re-add plan"
rm "$repo/docs/hyperpowers/plans/2026-10-19-delta.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-delta-design.md --plan docs/hyperpowers/plans/2026-10-19-delta.md
if [ "$RC" -eq 0 ] && git -C "$repo" diff --cached --name-status | grep -q '^D.*2026-10-19-delta.md$'; then pass "an index-tracked plan deleted in the tree gets its deletion staged"; else fail "unstaged deletion of a re-added plan (rc $RC, staged: $(git -C "$repo" diff --cached --name-status | tr '\n' ' '))"; fi

# A staged (uncommitted) deletion survives a re-run and stays in paths:.
repo="$TEST_ROOT/plan2"
make_repo "$repo"
write_spec "$repo" 2026-10-19-beta-design.md <<'EOF'
# Beta

## Decisions

- **Only one.** Text.
EOF
printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-beta-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-beta.md"
commit_all "$repo" "spec and plan"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-beta-design.md --plan docs/hyperpowers/plans/2026-10-19-beta.md
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-beta-design.md --plan docs/hyperpowers/plans/2026-10-19-beta.md
if [ "$RC" -eq 0 ]; then pass "a re-run while the deletion is staged succeeds"; else fail "re-run with staged deletion (rc $RC: $ERR)"; fi
case "$OUT" in *"docs/hyperpowers/plans/2026-10-19-beta.md"*) pass "the staged deletion stays in paths:" ;; *) fail "plan missing from paths: (got: $(printf '%s\n' "$OUT" | grep '^paths:'))" ;; esac

# A plan the compiler cannot remove, or cannot place, is refused before any
# write: git rm would refuse it on every retry, and a path with . or ..
# components is not canonical.
repo="$TEST_ROOT/planguard"
make_repo "$repo"
write_spec "$repo" 2026-10-19-eps-design.md <<'EOF'
# Eps

## Decisions

- **Eps one.** Text.
EOF
printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-eps-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-eps.md"
commit_all "$repo" "spec and plan"
mkdir -p "$TEST_ROOT/elsewhere"
printf '# Plan\n' > "$TEST_ROOT/elsewhere/plan.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-eps-design.md --plan "$TEST_ROOT/elsewhere/plan.md"
case "$ERR" in *"plan is outside the repository"*) outside_msg=1 ;; *) outside_msg=0 ;; esac
if [ "$RC" -eq 2 ] && [ "$outside_msg" = 1 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a plan outside the repository exits 2 with nothing written"; else fail "outside plan (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
rm -rf "$repo/docs/hyperpowers/plans"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-eps-design.md --plan docs/hyperpowers/plans/../plans/2026-10-19-eps.md
case "$ERR" in *"plan path must be canonical"*) dots_msg=1 ;; *) dots_msg=0 ;; esac
if [ "$RC" -eq 2 ] && [ "$dots_msg" = 1 ] && [ "$(git -C "$repo" status --porcelain)" = " D docs/hyperpowers/plans/2026-10-19-eps.md" ]; then pass "a plan path with .. components under a pruned directory exits 2 with nothing written"; else fail "dotted plan (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-eps-design.md --plan docs/hyperpowers/plans/../../../../etc/x.md
case "$ERR" in *"plan path must be canonical"*) dots_msg=1 ;; *) dots_msg=0 ;; esac
if [ "$RC" -eq 2 ] && [ "$dots_msg" = 1 ]; then pass "an escaping .. path under a pruned directory gets the canonical-path message"; else fail "escaping plan (rc $RC, err: $ERR)"; fi
mkdir -p "$repo/docs/hyperpowers/plans"
git -C "$repo" checkout -q -- docs/hyperpowers/plans/2026-10-19-eps.md
printf '# Plan edited\n' > "$repo/docs/hyperpowers/plans/2026-10-19-eps.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-eps-design.md --plan docs/hyperpowers/plans/2026-10-19-eps.md
case "$ERR" in *"plan has uncommitted changes"*) dirty_msg=1 ;; *) dirty_msg=0 ;; esac
if [ "$RC" -eq 2 ] && [ "$dirty_msg" = 1 ] && [ "$(git -C "$repo" status --porcelain)" = " M docs/hyperpowers/plans/2026-10-19-eps.md" ]; then pass "a modified plan exits 2 before any write"; else fail "modified plan (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-eps-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-eps.md"
printf '# New\n' > "$repo/docs/hyperpowers/plans/2026-10-19-fresh.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-eps-design.md --plan docs/hyperpowers/plans/2026-10-19-fresh.md
case "$ERR" in *"plan is not tracked by git"*) untracked_msg=1 ;; *) untracked_msg=0 ;; esac
if [ "$RC" -eq 2 ] && [ "$untracked_msg" = 1 ] && [ "$(git -C "$repo" status --porcelain)" = "?? docs/hyperpowers/plans/2026-10-19-fresh.md" ]; then pass "an untracked plan exits 2 before any write"; else fail "untracked plan (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi

# A path that is not a plain tracked plan of this spec is refused before any
# write, whatever git would accept.
repo="$TEST_ROOT/planshape"
make_repo "$repo"
write_spec "$repo" 2026-10-19-zeta-design.md <<'EOF'
# Zeta

## Decisions

- **Zeta one.** Text.
EOF
zeta_spec=docs/hyperpowers/specs/2026-10-19-zeta-design.md
plans_dir="$repo/docs/hyperpowers/plans"
printf '# Plan\n\n**Spec:** %s\n' "$zeta_spec" > "$plans_dir/good.md"
printf '# Plan\n\n**Spec:** %s\n' "$zeta_spec" > "$plans_dir/staged.md"
printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-other-design.md\n' > "$plans_dir/other-spec.md"
printf '# Plan\n\n**Spec:** %s\n' "$zeta_spec" > "$plans_dir/a; plan b.md"
bt=$(printf '\140')
printf '# Plan\n\n**Spec:** %s%s%s\n' "$bt" "$zeta_spec" "$bt" > "$plans_dir/hdr-backtick.md"
printf '# Plan\n\n**Spec:** [%s](../specs/2026-10-19-zeta-design.md) — read it before starting.\n' "$zeta_spec" > "$plans_dir/hdr-link.md"
printf '# Plan\n\n**Spec:** %s — read it first\n' "$zeta_spec" > "$plans_dir/hdr-prose.md"
printf '# Plan\n\n**Spec:** %sdocs/hyperpowers/specs/2026-10-19-other-design.md%s\n' "$bt" "$bt" > "$plans_dir/hdr-backtick-other.md"
printf '# Claude\n' > "$repo/CLAUDE.md"
mkdir -p "$plans_dir/dir.md"
printf 'inner\n' > "$plans_dir/dir.md/inner.txt"
ln -s good.md "$plans_dir/link.md"
commit_all "$repo" "spec and plans"
run_compile "$repo" "$zeta_spec"
commit_all "$repo" "records"
# refuse_plan LABEL MESSAGE-FRAGMENT PLAN: exit 2, the fragment on stderr, and
# git status exactly as it was before the run.
refuse_plan() {
    local before after
    before=$(git -C "$repo" status --porcelain)
    run_compile "$repo" "$zeta_spec" --plan "$3"
    after=$(git -C "$repo" status --porcelain)
    case "$ERR" in "$zeta_spec: "*"$2"*) msg_ok=1 ;; *) msg_ok=0 ;; esac
    if [ "$RC" -eq 2 ] && [ "$msg_ok" = 1 ] && [ "$before" = "$after" ]; then pass "$1"; else fail "$1 (rc $RC, err: $ERR, status before: $before, after: $after)"; fi
}
printf '# Plan edited\n' > "$plans_dir/staged.md"
git -C "$repo" add docs/hyperpowers/plans/staged.md
rm "$plans_dir/staged.md"
if [ "$(git -C "$repo" status --porcelain)" = "MD docs/hyperpowers/plans/staged.md" ]; then pass "fixture: staged edit with the working copy deleted is MD"; else fail "fixture MD (got: $(git -C "$repo" status --porcelain))"; fi
refuse_plan "a staged edit with the working-tree copy deleted is refused as uncommitted" "plan has uncommitted changes" docs/hyperpowers/plans/staged.md
git -C "$repo" reset -q -- docs/hyperpowers/plans/staged.md
git -C "$repo" checkout -q -- docs/hyperpowers/plans/staged.md
refuse_plan "a tracked directory as the plan is refused for its shape" "plan must be a markdown file under a plans/ directory" docs/hyperpowers/plans
refuse_plan "a tracked directory named dir.md is not a regular file" "plan is not a regular file" docs/hyperpowers/plans/dir.md
refuse_plan "a tracked file outside plans/ is refused for its shape" "plan must be a markdown file under a plans/ directory" CLAUDE.md
refuse_plan "a symbolic link at the plan path is not a regular file" "plan is not a regular file" docs/hyperpowers/plans/link.md
if [ -L "$plans_dir/link.md" ] && [ -f "$plans_dir/good.md" ]; then pass "the link and its target are intact"; else fail "link or target damaged"; fi
refuse_plan "a plan whose Spec header names another spec is refused" "plan names a different spec: docs/hyperpowers/specs/2026-10-19-other-design.md" docs/hyperpowers/plans/other-spec.md
refuse_plan "a plan path with the reserved text is refused" "plan path contains a newline or the reserved text" "docs/hyperpowers/plans/a; plan b.md"
refuse_plan "the spec itself is not a plan" "plan overlaps a compiler-owned path" "$zeta_spec"
refuse_plan "a path under the records directory is not a plan" "plan overlaps a compiler-owned path" docs/hyperpowers/decisions/x.md
run_compile "$repo" "$zeta_spec" --plan docs/hyperpowers/plans/good.md
if [ "$RC" -eq 0 ] && git -C "$repo" diff --cached --name-status | grep -q '^D.*plans/good.md$'; then pass "a plan whose Spec header names this spec passes the binding check"; else fail "bound plan (rc $RC, err: $ERR)"; fi
refuse_plan "a backtick-wrapped header naming another spec is still refused" "plan names a different spec: docs/hyperpowers/specs/2026-10-19-other-design.md" docs/hyperpowers/plans/hdr-backtick-other.md
for hdr in backtick link prose; do
    run_compile "$repo" "$zeta_spec" --plan "docs/hyperpowers/plans/hdr-$hdr.md"
    case "$OUT" in *$'\n'"removed docs/hyperpowers/plans/hdr-$hdr.md"*) removed_ok=1 ;; *) removed_ok=0 ;; esac
    if [ "$RC" -eq 0 ] && [ "$removed_ok" = 1 ]; then pass "a $hdr-form Spec header binds to this spec"; else fail "$hdr header (rc $RC, err: $ERR)"; fi
done

# --- 22. git failure at each staging operation --------------------------------
mkdir -p "$TEST_ROOT/bin"
REAL_GIT=$(command -v git)
cat > "$TEST_ROOT/bin/git" <<'EOF'
#!/usr/bin/env bash
# A git that refuses the one subcommand named in FAKE_GIT_FAIL and passes
# everything else to the real git, so a failure can be placed at one step.
for a in "$@"; do
    if [ "$a" = "${FAKE_GIT_FAIL:-}" ]; then echo "fake git: refusing $a" >&2; exit 128; fi
done
exec "$REAL_GIT" "$@"
EOF
chmod +x "$TEST_ROOT/bin/git"
for failing in add rm; do
    repo="$TEST_ROOT/gitfail-$failing"
    make_repo "$repo"
    write_spec "$repo" 2026-10-19-gamma-design.md <<'EOF'
# Gamma

## Decisions

- **Gamma one.** Text.
EOF
    printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-gamma-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-gamma.md"
    commit_all "$repo" "spec and plan"
    PATH="$TEST_ROOT/bin:$PATH" FAKE_GIT_FAIL="$failing" REAL_GIT="$REAL_GIT" run_compile "$repo" docs/hyperpowers/specs/2026-10-19-gamma-design.md --plan docs/hyperpowers/plans/2026-10-19-gamma.md
    if [ "$RC" -eq 3 ]; then pass "a failing git $failing exits 3"; else fail "git $failing failure exit (got $RC: $ERR)"; fi
    if [ -f "$repo/docs/hyperpowers/decisions/2026-10-19-gamma-one.md" ] && [ -f "$repo/docs/hyperpowers/decisions/README.md" ]; then pass "files are written before the failed $failing"; else fail "files missing after failed $failing"; fi
    if [ -f "$repo/docs/hyperpowers/plans/2026-10-19-gamma.md" ]; then pass "the plan is still present after a failed $failing"; else fail "plan removed despite failed $failing"; fi
    run_compile "$repo" docs/hyperpowers/specs/2026-10-19-gamma-design.md --plan docs/hyperpowers/plans/2026-10-19-gamma.md --paths-file "$TEST_ROOT/gitfail.paths"
    expected="docs/hyperpowers/decisions/2026-10-19-gamma-one.md docs/hyperpowers/decisions/README.md docs/hyperpowers/plans/2026-10-19-gamma.md docs/hyperpowers/specs/2026-10-19-gamma-design.md"
    if [ "$RC" -eq 0 ] && [ "$(tr '\0' '\n' < "$TEST_ROOT/gitfail.paths" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')" = "$expected" ]; then
        pass "the retry completes the staging and the pathspec file carries everything ($failing)"
    else
        fail "retry after failed $failing (rc $RC, paths: $(tr '\0' ' ' < "$TEST_ROOT/gitfail.paths"))"
    fi
done

# --- 23. Setext headings in notes are headings ------------------------------
# Correction (2026-10-22): Task 4's gate found at its cap that a line underlined
# with --- or === is a Markdown heading the notes grammar forbids but the pass
# did not recognise; the human partner carried the rule and this test into
# Task 5.
repo="$TEST_ROOT/setext"
make_repo "$repo"
write_spec "$repo" 2026-10-19-setext-design.md <<'EOF'
# Setext

## Decisions

1. **First.** One.
2. **Second.** Two.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-setext-design.md
commit_all "$repo" "records"
printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-setext-design.md\n\n## Decision 1\nChanged the parser.\n\nSupersessions\n---\n- 1 supersedes docs/hyperpowers/decisions/x.md\n' > "$TEST_ROOT/notes-setext.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-setext-design.md --notes "$TEST_ROOT/notes-setext.md"
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a Setext heading makes the notes malformed and the run proceeds unchanged"; else fail "setext notes (rc $RC, status: $(git -C "$repo" status --porcelain))"; fi
case "$ERR" in "notes ignored: unexpected heading: Supersessions"*) pass "the Setext heading is reported as an unexpected heading" ;; *) fail "setext message (got: $ERR)" ;; esac
if ! grep -rq 'supersedes docs/hyperpowers/decisions/x.md' "$repo/docs/hyperpowers/decisions"; then pass "no record carries the proposal under a Setext heading"; else fail "a proposal under a Setext heading reached a record"; fi
printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-setext-design.md\n\n## Decision 1\nChanged the parser.\n\nDecision 2\n===\nSmuggled.\n' > "$TEST_ROOT/notes-setext2.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-setext-design.md --notes "$TEST_ROOT/notes-setext2.md"
case "$ERR" in "notes ignored: unexpected heading: Decision 2"*) pass "an = underline is a heading too" ;; *) fail "setext = message (got: $ERR)" ;; esac
printf '# Decision notes: docs/hyperpowers/specs/2026-10-19-setext-design.md\n\n## Decision 1\nChanged the parser.\n\n---\n\nAnd the tests.\n' > "$TEST_ROOT/notes-rule.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-setext-design.md --notes "$TEST_ROOT/notes-rule.md"
if [ "$RC" -eq 0 ] && [ -z "$ERR" ] && grep -q '^And the tests\.$' "$repo/docs/hyperpowers/decisions/2026-10-19-first.md"; then pass "a thematic break after a blank line is body text, not a heading"; else fail "thematic break (rc $RC, err: $ERR)"; fi

# --- 24. --undo, with a superseded target ---------------------------------
repo="$TEST_ROOT/undo"
make_repo "$repo"
write_spec "$repo" 2026-07-01-old-design.md <<'EOF'
# Old

## Decisions

- **Hook-based interlock.** A hook gates the first edit.
EOF
commit_all "$repo" "old spec"
run_compile "$repo" docs/hyperpowers/specs/2026-07-01-old-design.md
commit_all "$repo" "old records"
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

- **Skill text, not a hook.** Measured no gain from the hook.
  Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
EOF
printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-08-01-new-design.md\n' > "$repo/docs/hyperpowers/plans/2026-08-01-new.md"
commit_all "$repo" "new spec and plan"
before=$(git -C "$repo" write-tree)
spec_sum=$(cksum < "$repo/docs/hyperpowers/specs/2026-08-01-new-design.md")
printf 'unrelated\n' > "$repo/other.txt"
git -C "$repo" add other.txt
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md --plan docs/hyperpowers/plans/2026-08-01-new.md
if grep -q '^- Status: superseded by' "$repo/docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md"; then pass "undo fixture: the target is superseded before undo"; else fail "undo fixture did not supersede"; fi
run_compile "$repo" --undo docs/hyperpowers/specs/2026-08-01-new-design.md --plan docs/hyperpowers/plans/2026-08-01-new.md
if [ "$RC" -eq 0 ] && [ "$(git -C "$repo" status --porcelain)" = "A  other.txt" ]; then pass "--undo restores spec, plan and the superseded record, removes the new record, keeps the unrelated staged file"; else fail "--undo (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain | tr '\n' ';'))"; fi
if grep -q '^- Status: accepted$' "$repo/docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md"; then pass "--undo restores the target's accepted status"; else fail "target status after undo: $(grep '^- Status' "$repo/docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md")"; fi
git -C "$repo" reset -q other.txt && rm "$repo/other.txt"
if [ "$(git -C "$repo" write-tree)" = "$before" ]; then pass "--undo returns the index to its pre-run tree"; else fail "index differs from the pre-run tree"; fi
if [ "$(cksum < "$repo/docs/hyperpowers/specs/2026-08-01-new-design.md")" = "$spec_sum" ]; then pass "--undo restores the spec byte for byte"; else fail "spec differs after undo"; fi
case "$OUT" in *"restored docs/hyperpowers/plans/2026-08-01-new.md"*) pass "--undo reports what it restored" ;; *) fail "undo output (got: $OUT)" ;; esac
# A records directory emptied by undo disappears.
repo="$TEST_ROOT/undo2"
make_repo "$repo"
write_spec "$repo" 2026-10-19-beta-design.md <<'EOF'
# Beta

## Decisions

- **Only one.** Text.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-beta-design.md
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-beta-design.md
if [ "$RC" -eq 0 ] && [ ! -d "$repo/docs/hyperpowers/decisions" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "--undo removes an emptied records directory"; else fail "undo2 (rc $RC, status: $(git -C "$repo" status --porcelain), dir: $(ls "$repo/docs/hyperpowers/decisions" 2>/dev/null))"; fi

# An untracked spec is refused in compile and undo modes: the Outcome line
# would stay behind with the records gone, or the only copy would be deleted.
repo="$TEST_ROOT/undo3"
make_repo "$repo"
write_spec "$repo" 2026-10-19-delta-design.md <<'EOF'
# Delta

## Decisions

- **Only one.** Text.
EOF
before_status=$(git -C "$repo" status --porcelain -uall)
for mode_args in "" "--undo"; do
    # shellcheck disable=SC2086
    run_compile "$repo" $mode_args docs/hyperpowers/specs/2026-10-19-delta-design.md
    if [ "$RC" -eq 2 ] && [ "$(git -C "$repo" status --porcelain -uall)" = "$before_status" ] && [ ! -d "$repo/docs/hyperpowers/decisions" ]; then pass "an untracked spec exits 2 and writes nothing${mode_args:+ ($mode_args)}"; else fail "untracked spec ${mode_args:-compile} (rc $RC, err: $ERR)"; fi
    case "$ERR" in *"docs/hyperpowers/specs/2026-10-19-delta-design.md: spec is not committed; commit it before the records compile"*) pass "the untracked-spec message names the spec${mode_args:+ ($mode_args)}" ;; *) fail "untracked message (got: $ERR)" ;; esac
done
# A staged-only spec is not in HEAD either: undo would delete the only copy.
git -C "$repo" add docs/hyperpowers/specs/2026-10-19-delta-design.md
before_status=$(git -C "$repo" status --porcelain -uall)
for mode_args in "" "--undo"; do
    # shellcheck disable=SC2086
    run_compile "$repo" $mode_args docs/hyperpowers/specs/2026-10-19-delta-design.md
    if [ "$RC" -eq 2 ] && [ "$(git -C "$repo" status --porcelain -uall)" = "$before_status" ] && [ "$before_status" = "A  docs/hyperpowers/specs/2026-10-19-delta-design.md" ] && [ ! -d "$repo/docs/hyperpowers/decisions" ]; then pass "a staged-only spec exits 2 and writes nothing${mode_args:+ ($mode_args)}"; else fail "staged-only spec ${mode_args:-compile} (rc $RC, err: $ERR, status: $before_status)"; fi
    case "$ERR" in *"delta-design.md: spec is not committed; commit it before the records compile"*) pass "the staged-only message says not committed${mode_args:+ ($mode_args)}" ;; *) fail "staged-only message (got: $ERR)" ;; esac
done
# Nothing staged: undo is a no-op.
repo="$TEST_ROOT/undo4"
make_repo "$repo"
write_spec "$repo" 2026-10-19-eps-design.md <<'EOF'
# Eps

## Decisions

- **Only one.** Text.
EOF
commit_all "$repo" "spec"
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-eps-design.md
if [ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "--undo with nothing staged prints nothing and changes nothing"; else fail "undo4 (rc $RC, out: $OUT, status: $(git -C "$repo" status --porcelain))"; fi

# A failed deletion leaves the staged entry, so the retry completes the undo.
repo="$TEST_ROOT/undo5"
make_repo "$repo"
write_spec "$repo" 2026-10-19-zeta-design.md <<'EOF'
# Zeta

## Decisions

- **Only one.** Text.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-zeta-design.md
chmod 555 "$repo/docs/hyperpowers/decisions"
if [ -w "$repo/docs/hyperpowers/decisions" ]; then
    chmod 755 "$repo/docs/hyperpowers/decisions"
    pass "directory stays writable for this user; the failed-deletion retry check is skipped"
else
    run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-zeta-design.md
    chmod 755 "$repo/docs/hyperpowers/decisions"
    if [ "$RC" -eq 3 ] && [ -n "$(git -C "$repo" ls-files -- docs/hyperpowers/decisions)" ]; then pass "a failed deletion exits 3 and keeps the record's index entry"; else fail "undo5 first (rc $RC, err: $ERR)"; fi
    case "$ERR" in "docs/hyperpowers/specs/2026-10-19-zeta-design.md: cannot delete "*"; run the same command again to complete the undo") pass "the failed-deletion message names the spec and the remedy" ;; *) fail "undo5 message (got: $ERR)" ;; esac
    run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-zeta-design.md
    if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -uall)" ]; then pass "the retried --undo completes and leaves the tree clean"; else fail "undo5 retry (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
fi

# A plan deletion that git would pair with a similar record addition as a
# rename is still listed and still restored (git diff --no-renames).
scratch="$TEST_ROOT/rename-scratch"
make_repo "$scratch"
write_spec "$scratch" 2026-10-19-ren-design.md <<'EOF'
# Ren

## Decisions

- **Only one.** Text.
EOF
commit_all "$scratch" "spec"
run_compile "$scratch" docs/hyperpowers/specs/2026-10-19-ren-design.md
repo="$TEST_ROOT/rename"
make_repo "$repo"
write_spec "$repo" 2026-10-19-ren-design.md <<'EOF'
# Ren

## Decisions

- **Only one.** Text.
EOF
{ printf '**Spec:** docs/hyperpowers/specs/2026-10-19-ren-design.md\n'; cat "$scratch/docs/hyperpowers/decisions/2026-10-19-only-one.md"; } > "$repo/docs/hyperpowers/plans/2026-10-19-ren.md"
commit_all "$repo" "spec and a plan that resembles its record"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-ren-design.md --plan docs/hyperpowers/plans/2026-10-19-ren.md --paths-file "$TEST_ROOT/ren.z"
pathlist=$(tr '\0' '\n' < "$TEST_ROOT/ren.z")
case "$pathlist" in
    *"docs/hyperpowers/plans/2026-10-19-ren.md"*"docs/hyperpowers/decisions/2026-10-19-only-one.md"*|*"docs/hyperpowers/decisions/2026-10-19-only-one.md"*"docs/hyperpowers/plans/2026-10-19-ren.md"*) pass "the pathspec file lists both the deleted plan and the similar new record" ;;
    *) fail "rename fold (rc $RC, paths: $pathlist)" ;;
esac
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-ren-design.md --plan docs/hyperpowers/plans/2026-10-19-ren.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -uall)" ]; then pass "--undo restores a plan that git would pair with a record as a rename"; else fail "rename undo (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi

# Two compiles staged at once. The records directory is shared, so undoing
# one spec while the other's Outcome line stays staged would leave that spec
# pointing at records that are gone. Until one of them is committed each
# blocks the other's undo, so the operator commits or undoes in order.
repo="$TEST_ROOT/undo6"
make_repo "$repo"
write_spec "$repo" 2026-10-19-one-design.md <<'EOF'
# One

## Decisions

- **Alpha choice.** Text.
EOF
write_spec "$repo" 2026-10-19-two-design.md <<'EOF'
# Two

## Decisions

- **Beta choice.** Text.
EOF
commit_all "$repo" "two specs"
# The second compile would refuse the first's staged records as a foreign
# change (§31), so the state is built by committing the first compile and
# taking the commit back once the second has run: the index and the working
# tree are what two compiles in a row used to leave.
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-one-design.md
commit_all "$repo" "one's records"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-two-design.md
git -C "$repo" reset -q --soft HEAD^
before_status=$(git -C "$repo" status --porcelain -uall)
sum_one=$(cksum < "$repo/docs/hyperpowers/decisions/2026-10-19-alpha-choice.md")
sum_two=$(cksum < "$repo/docs/hyperpowers/decisions/2026-10-19-beta-choice.md")
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-two-design.md
if [ "$RC" -eq 2 ] && [ "$(git -C "$repo" status --porcelain -uall)" = "$before_status" ] && [ "$(cksum < "$repo/docs/hyperpowers/decisions/2026-10-19-alpha-choice.md")" = "$sum_one" ] && [ "$(cksum < "$repo/docs/hyperpowers/decisions/2026-10-19-beta-choice.md")" = "$sum_two" ]; then pass "--undo refuses while another spec's compile is staged, and writes nothing"; else fail "undo6 (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
case "$ERR" in *"--undo refused: docs/hyperpowers/decisions/2026-10-19-alpha-choice.md is staged but belongs to another compile; commit or undo it first"*) pass "the refusal names the other compile's record" ;; *) fail "undo6 message (got: $ERR)" ;; esac
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-one-design.md
if [ "$RC" -eq 2 ] && [ "$(git -C "$repo" status --porcelain -uall)" = "$before_status" ]; then pass "the first spec's --undo is refused the same way, writing nothing"; else fail "undo6 reverse (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
case "$ERR" in *"--undo refused: docs/hyperpowers/decisions/2026-10-19-beta-choice.md is staged but belongs to another compile"*) pass "the reverse refusal names the second compile's record" ;; *) fail "undo6 reverse message (got: $ERR)" ;; esac
git -C "$repo" commit -q -m "one" -- docs/hyperpowers/decisions/2026-10-19-alpha-choice.md docs/hyperpowers/decisions/README.md docs/hyperpowers/specs/2026-10-19-one-design.md
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-two-design.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -uall)" ] && [ ! -e "$repo/docs/hyperpowers/decisions/2026-10-19-beta-choice.md" ] && [ -f "$repo/docs/hyperpowers/decisions/2026-10-19-alpha-choice.md" ]; then pass "once the other compile is committed the undo runs and leaves its records alone"; else fail "undo6 after commit (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi

# An edit made after the compile is not the compile's text; the restore would
# discard it without a trace.
repo="$TEST_ROOT/undo7"
make_repo "$repo"
write_spec "$repo" 2026-10-19-eta-design.md <<'EOF'
# Eta

## Decisions

- **Only one.** Text.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-eta-design.md
printf 'A line your human partner added.\n' >> "$repo/docs/hyperpowers/decisions/2026-10-19-only-one.md"
before_status=$(git -C "$repo" status --porcelain -uall)
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-eta-design.md
if [ "$RC" -eq 2 ] && [ "$(git -C "$repo" status --porcelain -uall)" = "$before_status" ]; then pass "--undo refuses when a record was edited after the compile, and writes nothing"; else fail "undo7 (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
case "$before_status" in *"AM docs/hyperpowers/decisions/2026-10-19-only-one.md"*) pass "the edited record stays staged-added and modified across the refusal" ;; *) fail "undo7 fixture status (got: $before_status)" ;; esac
case "$ERR" in *"--undo refused: docs/hyperpowers/decisions/2026-10-19-only-one.md was edited after the compile; commit or stash the edit first"*) pass "the refusal names the edited record" ;; *) fail "undo7 message (got: $ERR)" ;; esac
git -C "$repo" add docs/hyperpowers/decisions/2026-10-19-only-one.md
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-eta-design.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -uall)" ]; then pass "a staged edit is part of the run again, so --undo completes and leaves the tree clean"; else fail "undo7 staged edit (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi

# A file recreated at the path of a staged deletion is untracked relative to
# the index, so the edit check says nothing about it while the restore would
# overwrite it with HEAD's copy. At the plan's path the plan preflight gets
# there first, with its own message; every other path is the new check's.
repo="$TEST_ROOT/undo8"
make_repo "$repo"
write_spec "$repo" 2026-10-19-theta-design.md <<'EOF'
# Theta

## Decisions

- **Only one.** Text.
EOF
printf '# Plan\n\n**Spec:** docs/hyperpowers/specs/2026-10-19-theta-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-theta.md"
commit_all "$repo" "spec and plan"
plan_head_sum=$(cksum < "$repo/docs/hyperpowers/plans/2026-10-19-theta.md")
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-theta-design.md --plan docs/hyperpowers/plans/2026-10-19-theta.md
# git prunes the plans directory when its last file goes.
mkdir -p "$repo/docs/hyperpowers/plans"
printf 'recreated\n' > "$repo/docs/hyperpowers/plans/2026-10-19-theta.md"
plan_sum=$(cksum < "$repo/docs/hyperpowers/plans/2026-10-19-theta.md")
before_status=$(git -C "$repo" status --porcelain -uall)
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-theta-design.md --plan docs/hyperpowers/plans/2026-10-19-theta.md
if [ "$RC" -eq 2 ] && [ "$(cksum < "$repo/docs/hyperpowers/plans/2026-10-19-theta.md")" = "$plan_sum" ] && [ "$(git -C "$repo" status --porcelain -uall)" = "$before_status" ]; then pass "--undo refuses while a recreated plan sits at the staged deletion's path, and writes nothing"; else fail "undo8 plan (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
case "$before_status" in *"D  docs/hyperpowers/plans/2026-10-19-theta.md"*"?? docs/hyperpowers/plans/2026-10-19-theta.md"*) pass "the recreated plan is a staged deletion with an untracked file at its path" ;; *) fail "undo8 fixture status (got: $(printf '%s' "$before_status" | tr '\n' ';'))" ;; esac
case "$ERR" in *"plan is not tracked by git; commit it before the records compile: docs/hyperpowers/plans/2026-10-19-theta.md"*) pass "the plan preflight refuses the recreated plan before the undo block" ;; *) fail "undo8 plan message (got: $ERR)" ;; esac
mv "$repo/docs/hyperpowers/plans/2026-10-19-theta.md" "$TEST_ROOT/theta-recreated.md"
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-theta-design.md --plan docs/hyperpowers/plans/2026-10-19-theta.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -uall)" ] && [ "$(cksum < "$repo/docs/hyperpowers/plans/2026-10-19-theta.md")" = "$plan_head_sum" ]; then pass "once the recreation is moved aside --undo restores HEAD's plan"; else fail "undo8 after mv (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
# A record, whose path no preflight looks at, reaches the new check.
repo="$TEST_ROOT/undo9"
make_repo "$repo"
write_spec "$repo" 2026-10-19-iota-design.md <<'EOF'
# Iota

## Decisions

- **Only one.** Text.
EOF
commit_all "$repo" "spec"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-iota-design.md
commit_all "$repo" "records"
git -C "$repo" rm -q docs/hyperpowers/decisions/2026-10-19-only-one.md
printf 'recreated by hand\n' > "$repo/docs/hyperpowers/decisions/2026-10-19-only-one.md"
rec_sum=$(cksum < "$repo/docs/hyperpowers/decisions/2026-10-19-only-one.md")
before_status=$(git -C "$repo" status --porcelain -uall)
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-iota-design.md
if [ "$RC" -eq 2 ] && [ "$(cksum < "$repo/docs/hyperpowers/decisions/2026-10-19-only-one.md")" = "$rec_sum" ] && [ "$(git -C "$repo" status --porcelain -uall)" = "$before_status" ]; then pass "--undo refuses when a record was recreated after its deletion was staged, and writes nothing"; else fail "undo9 (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
case "$ERR" in *"--undo refused: docs/hyperpowers/decisions/2026-10-19-only-one.md was recreated after the compile; move it aside or stage it first"*) pass "the refusal names the recreated record" ;; *) fail "undo9 message (got: $ERR)" ;; esac
mv "$repo/docs/hyperpowers/decisions/2026-10-19-only-one.md" "$TEST_ROOT/iota-recreated.md"
run_compile "$repo" --undo docs/hyperpowers/specs/2026-10-19-iota-design.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -uall)" ]; then pass "once the recreation is moved aside the record's staged deletion is undone"; else fail "undo9 after mv (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi

# --- 25. a later day with an unchanged spec --------------------------------
repo="$TEST_ROOT/gitfail-rm"
commit_all "$repo" "records"
COMPILE_DATE=2026-11-30 run_compile "$repo" docs/hyperpowers/specs/2026-10-19-gamma-design.md --plan docs/hyperpowers/plans/2026-10-19-gamma.md
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a later-day re-run on an unchanged spec changes nothing"; else fail "later-day re-run (status: $(git -C "$repo" status --porcelain))"; fi

# --- 26. the mode table ----------------------------------------------------
repo="$TEST_ROOT/undo2"
for args in "--undo docs/hyperpowers/specs/2026-10-19-beta-design.md --notes x" "--undo docs/hyperpowers/specs/2026-10-19-beta-design.md --dry-run" "--undo docs/hyperpowers/specs/2026-10-19-beta-design.md --paths-file x" "--undo --reindex docs/hyperpowers/decisions" "--reindex docs/hyperpowers/decisions --plan x" "--reindex docs/hyperpowers/decisions --notes x" "docs/hyperpowers/specs/2026-10-19-beta-design.md --plan a --plan b" "docs/hyperpowers/specs/2026-10-19-beta-design.md --notes a --notes b"; do
    # shellcheck disable=SC2086
    run_compile "$repo" $args
    if [ "$RC" -eq 2 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "usage error, nothing written: $args"; else fail "mode table: $args (rc $RC)"; fi
done

# --- 27. the plan binding is exact ---------------------------------------------
# Correction (2026-10-22): Task 5's gate found at its cap that the Spec-header
# binding's basename arms were suffix matches, so a plan written for a
# same-named spec in another directory passed; the human partner carried the
# exact-match rule and this test into Task 6.
repo="$TEST_ROOT/twin"
make_repo "$repo"
mkdir -p "$repo/docs/other/specs" "$repo/docs/other/plans"
write_spec "$repo" 2026-10-19-twin-design.md <<'EOF'
# Twin

## Decisions

- **One.** Text.
EOF
printf '# Twin elsewhere\n\n## Decisions\n\n- **Other.** Text.\n' > "$repo/docs/other/specs/2026-10-19-twin-design.md"
printf '# Plan\n\n**Spec:** docs/other/specs/2026-10-19-twin-design.md\n' > "$repo/docs/other/plans/2026-10-19-twin.md"
printf '# Plan\n\n**Spec:** 2026-10-19-twin-design.md\n' > "$repo/docs/hyperpowers/plans/2026-10-19-twin.md"
commit_all "$repo" "twins"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-twin-design.md --plan docs/other/plans/2026-10-19-twin.md
if [ "$RC" -eq 2 ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then pass "a plan naming a same-named spec in another directory is refused before any write"; else fail "twin plan (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
case "$ERR" in *"plan names a different spec: docs/other/specs/2026-10-19-twin-design.md"*) pass "the twin refusal names the header's path" ;; *) fail "twin message (got: $ERR)" ;; esac
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-twin-design.md --plan docs/hyperpowers/plans/2026-10-19-twin.md
if [ "$RC" -eq 0 ]; then pass "a bare-basename header still binds"; else fail "bare basename (rc $RC: $ERR)"; fi
case "$OUT" in *"removed docs/hyperpowers/plans/2026-10-19-twin.md"*) pass "the bare-basename plan is removed" ;; *) fail "bare-basename removal line missing" ;; esac

# --- 28. titles come from the first paragraph, across lines ------------------
# Real specs wrap a bold title or a plain first clause onto a second line;
# reading line 1 alone left a raw `**` and a mid-phrase cut.
repo="$TEST_ROOT/wrap"
make_repo "$repo"
write_spec "$repo" 2026-07-01-old-design.md <<'EOS'
# Old

## Decisions

- **Hook-based interlock.** A hook gates the first edit.
EOS
commit_all "$repo" "old spec"
run_compile "$repo" docs/hyperpowers/specs/2026-07-01-old-design.md
commit_all "$repo" "old records"
write_spec "$repo" 2026-10-22-wrap-design.md <<'EOS'
# Wrap

## Decisions

- **Records are extracted at finish only, and the spec's Decisions
  section stays the authority.** Body text.
- The spec is the only source of a record's title and
  decision text. A re-run refreshes them.
- Plain clause words repeat until the first clause passes eighty characters in total length without a stop. Tail.
- **Wrapped title that is superseding something.**
  Supersedes: docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md
  Body.
EOS
commit_all "$repo" "wrap"
run_compile "$repo" docs/hyperpowers/specs/2026-10-22-wrap-design.md --dry-run
if [ "$RC" -eq 0 ]; then pass "wrapped titles: dry run exits 0"; else fail "wrapped titles exit (got $RC: $ERR)"; fi
case "$OUT" in
    *"(decision 1: Records are extracted at finish only, and the spec's Decisions section stays the authority)"*) pass "a bold title wrapping onto line 2 is whole and unmarked" ;;
    *) fail "wrapped bold title (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 2: The spec is the only source of a record's title and decision text)"*) pass "a plain first clause ending on line 2 is whole" ;;
    *) fail "wrapped plain title (got: $OUT)" ;;
esac
long=$(printf '%s\n' "$OUT" | grep '(decision 3: ' | sed 's/.*(decision 3: //; s/)$//' || true)
if [ -n "$long" ] && [ ${#long} -le 80 ] && [ "$long" = "Plain clause words repeat until the first clause passes eighty characters in" ]; then
    pass "a long plain clause is cut at a word boundary, at most 80 characters"
else
    fail "long plain title (got: $long)"
fi
case "$OUT" in
    *"(decision 4: Wrapped title that is superseding something)"*) pass "a Supersedes line after the title does not leak into it" ;;
    *) fail "supersedes title (got: $OUT)" ;;
esac
case "$OUT" in *"(decision "[0-9]": **"*) fail "a title begins with ** (got: $OUT)" ;; *) pass "no title begins with **" ;; esac
run_compile "$repo" docs/hyperpowers/specs/2026-10-22-wrap-design.md
if [ "$RC" -eq 0 ] && grep -q "^# Records are extracted at finish only, and the spec's Decisions section stays the authority$" "$repo"/docs/hyperpowers/decisions/2026-10-22-records-are-extracted-at-finish-only-and-the-spec-s*.md; then
    pass "the record's heading carries the whole wrapped title"
else
    fail "wrapped record heading (rc $RC: $ERR; files: $(ls "$repo/docs/hyperpowers/decisions"))"
fi

# --- 29. title edges: exact 80, unclosed bold, trailing punctuation ----------
repo="$TEST_ROOT/edges"
make_repo "$repo"
exact80="abcdefghi abcdefghi abcdefghi abcdefghi abcdefghi abcdefghi abcdefghi abcdefghij"
write_spec "$repo" 2026-10-22-edges-design.md <<EOS
# Edges

## Decisions

- $exact80 tail words without a stop
- **No closing stars here. Body.
- The parallel model to serve first is one controller session per parallel task, and the rest
- A plain item ending in a period.
EOS
commit_all "$repo" "edges"
run_compile "$repo" docs/hyperpowers/specs/2026-10-22-edges-design.md --dry-run
if [ "$RC" -eq 0 ]; then pass "title edges: dry run exits 0"; else fail "title edges exit (got $RC: $ERR)"; fi
case "$OUT" in
    *"(decision 1: $exact80)"*) pass "80 characters followed by a space are kept whole" ;;
    *) fail "exact 80 title (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 2: No closing stars here)"*) pass "an unclosed ** is dropped and the text is a plain clause" ;;
    *) fail "unclosed bold title (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 3: The parallel model to serve first is one controller session per parallel task)"*) pass "a cut that leaves a trailing comma drops it" ;;
    *) fail "trailing comma title (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 4: A plain item ending in a period)"*) pass "a whole-paragraph plain title loses its final period" ;;
    *) fail "trailing period title (got: $OUT)" ;;
esac

# --- 30. a long plain clause is cut at a clause boundary, never inside a token ---
repo="$TEST_ROOT/clause"
make_repo "$repo"
token="https://example.org/$(printf '%80s' '' | tr ' ' x)"
write_spec "$repo" 2026-10-22-clause-design.md <<EOS
# Clause

## Decisions

- Aaaa bbbb cccc dddd eeee ffff gggg hhhh, iiii jjjj kkkk llll mmmm nnnn oooo pppp qqqq rrrr ssss
- Aaaa bbbb, cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn oooo ppppp qqqq
- $token
- Aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn oooo abcdé tail words
EOS
commit_all "$repo" "clause"
run_compile "$repo" docs/hyperpowers/specs/2026-10-22-clause-design.md --dry-run
if [ "$RC" -eq 0 ]; then pass "clause cuts: dry run exits 0"; else fail "clause cuts exit (got $RC: $ERR)"; fi
case "$OUT" in
    *"(decision 1: Aaaa bbbb cccc dddd eeee ffff gggg hhhh)"*) pass "a long clause is cut at its last comma, with no trailing comma" ;;
    *) fail "comma cut (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 2: Aaaa bbbb, cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn oooo)"*) pass "a comma leaving fewer than 20 characters is skipped for the last space" ;;
    *) fail "early comma title (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 3: $token)"*) pass "a single token longer than 80 characters stays whole" ;;
    *) fail "long token title (got: $OUT)" ;;
esac
case "$OUT" in
    *"(decision 4: Aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn oooo)"*) pass "a multibyte word straddling the limit is dropped whole, no byte split" ;;
    *) fail "multibyte title (got: $OUT)" ;;
esac

# --- 31. a foreign change under the records directory is refused -------------
# Correction (2026-10-22): the final whole-branch gate found that the staging
# and the approval diff covered the whole records directory, so a change this
# compile does not own rode into its records commit. The directory is shared:
# only the records this compile writes, the targets whose Status line it
# rewrites and the index are its own.
repo="$TEST_ROOT/foreign"
make_repo "$repo"
write_spec "$repo" 2026-07-01-old-design.md <<'EOF'
# Old

## Decisions

- **Alpha choice.** A.
- **Beta choice.** B.
EOF
commit_all "$repo" "old spec"
run_compile "$repo" docs/hyperpowers/specs/2026-07-01-old-design.md
commit_all "$repo" "old records"
write_spec "$repo" 2026-08-01-new-design.md <<'EOF'
# New

## Decisions

- **Fresh choice.** Text.
EOF
commit_all "$repo" "new spec"
new_spec=docs/hyperpowers/specs/2026-08-01-new-design.md
alpha=docs/hyperpowers/decisions/2026-07-01-alpha-choice.md
beta=docs/hyperpowers/decisions/2026-07-01-beta-choice.md
# refuse_foreign LABEL PATH: the compile exits 2 naming PATH, and git status
# is exactly what it was before the run.
refuse_foreign() {
    local before after msg_ok
    before=$(git -C "$repo" status --porcelain -uall)
    run_compile "$repo" "$new_spec"
    after=$(git -C "$repo" status --porcelain -uall)
    case "$ERR" in "$new_spec: $2 is changed under docs/hyperpowers/decisions but is not this compile's to write; commit, stash or discard it before the records compile") msg_ok=1 ;; *) msg_ok=0 ;; esac
    if [ "$RC" -eq 2 ] && [ "$msg_ok" = 1 ] && [ "$before" = "$after" ]; then pass "$1"; else fail "$1 (rc $RC, err: $ERR, status before: $before, after: $after)"; fi
}
printf 'a line nobody compiled\n' >> "$repo/$alpha"
refuse_foreign "a foreign modified record is refused before any write" "$alpha"
git -C "$repo" restore --staged --worktree -- "$alpha"
rm "$repo/$beta"
refuse_foreign "a foreign deleted record is refused" "$beta"
git -C "$repo" restore --staged --worktree -- "$beta"
printf 'scratch\n' > "$repo/docs/hyperpowers/decisions/scratch.md"
refuse_foreign "a foreign untracked file under decisions/ is refused" docs/hyperpowers/decisions/scratch.md
rm -f "$repo/docs/hyperpowers/decisions/scratch.md"
printf 'a separately staged edit\n' >> "$repo/$alpha"
git -C "$repo" add -- "$alpha"
refuse_foreign "a foreign record staged separately is refused" "$alpha"
git -C "$repo" restore --staged --worktree -- "$alpha"
if [ -z "$(git -C "$repo" status --porcelain -uall)" ]; then pass "fixture: the four foreign changes are undone"; else fail "foreign fixture (status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi
run_compile "$repo" "$new_spec"
staged=$(git -C "$repo" diff --cached --name-only | sort | tr '\n' ' ')
expected="docs/hyperpowers/decisions/2026-08-01-fresh-choice.md docs/hyperpowers/decisions/README.md docs/hyperpowers/specs/2026-08-01-new-design.md "
if [ "$RC" -eq 0 ] && [ "$staged" = "$expected" ]; then pass "with the directory clean the compile stages its own record, the index and the spec"; else fail "clean compile (rc $RC, err: $ERR, staged: $staged)"; fi
# A record this compile owns, left unstaged by a failed earlier run, is not
# foreign: the retry stages it.
git -C "$repo" reset -q -- docs/hyperpowers/decisions/2026-08-01-fresh-choice.md
run_compile "$repo" "$new_spec"
if [ "$RC" -eq 0 ] && git -C "$repo" diff --cached --name-only | grep -q '2026-08-01-fresh-choice.md'; then pass "an own record left unstaged by an earlier run is staged by the retry, not refused"; else fail "own unstaged record (rc $RC, err: $ERR, staged: $(git -C "$repo" diff --cached --name-only | tr '\n' ' '))"; fi
# The index is the compiler's own file however it was left: a hand edit is
# rewritten, not refused.
commit_all "$repo" "new records"
printf 'drift\n' >> "$repo/docs/hyperpowers/decisions/README.md"
run_compile "$repo" "$new_spec"
if [ "$RC" -eq 0 ] && [ -z "$(git -C "$repo" status --porcelain -uall)" ]; then pass "a hand-edited index is this compile's to rewrite"; else fail "index ownership (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain -uall | tr '\n' ';'))"; fi

# --- 32. notes are bound to the spec by its repository path ------------------
# Correction (2026-10-22): the final whole-branch gate found that the notes
# file's first line was matched to the spec by basename, so notes written for
# a same-named spec in another directory were applied by decision number.
repo="$TEST_ROOT/notes-twin"
make_repo "$repo"
mkdir -p "$repo/docs/other/specs"
write_spec "$repo" 2026-10-19-twin-design.md <<'EOF'
# Twin here

## Decisions

- **One here.** Text.
EOF
printf '# Twin elsewhere\n\n## Decisions\n\n- **One elsewhere.** Text.\n' > "$repo/docs/other/specs/2026-10-19-twin-design.md"
commit_all "$repo" "two same-named specs"
printf '# Decision notes: docs/other/specs/2026-10-19-twin-design.md\n\n## Decision 1\nNotes for the other twin.\n' > "$TEST_ROOT/notes-twin.md"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-twin-design.md --notes "$TEST_ROOT/notes-twin.md"
case "$ERR" in "notes ignored: first line names docs/other/specs/2026-10-19-twin-design.md, not docs/hyperpowers/specs/2026-10-19-twin-design.md") msg_ok=1 ;; *) msg_ok=0 ;; esac
if [ "$RC" -eq 0 ] && [ "$msg_ok" = 1 ]; then pass "notes naming a same-named spec in another directory are ignored, both paths named"; else fail "twin notes (rc $RC, err: $ERR)"; fi
if grep -q '^Nothing recorded\.$' "$repo/docs/hyperpowers/decisions/2026-10-19-one-here.md"; then pass "the compiled spec's record keeps Nothing recorded"; else fail "twin record body (got: $(sed -n '/^## What/,$p' "$repo/docs/hyperpowers/decisions/2026-10-19-one-here.md" | tr '\n' ' '))"; fi
if grep -rq 'Notes for the other twin' "$repo/docs"; then fail "the other twin's notes reached a record"; else pass "no part of the other twin's notes reached a record"; fi
commit_all "$repo" "records here"
run_compile "$repo" docs/other/specs/2026-10-19-twin-design.md --notes "$TEST_ROOT/notes-twin.md"
if [ "$RC" -eq 0 ] && [ -z "$ERR" ] && grep -q '^Notes for the other twin\.$' "$repo/docs/other/decisions/2026-10-19-one-elsewhere.md"; then pass "the same notes file applies to the spec its first line names"; else fail "other twin notes (rc $RC, err: $ERR, files: $(ls "$repo/docs/other/decisions" 2>/dev/null))"; fi
printf '# Decision notes: %s/docs/other/specs/2026-10-19-twin-design.md\n\n## Decision 1\nAbsolute spelling.\n' "$repo" > "$TEST_ROOT/notes-abs.md"
run_compile "$repo" docs/other/specs/2026-10-19-twin-design.md --notes "$TEST_ROOT/notes-abs.md"
if [ "$RC" -eq 0 ] && [ -z "$ERR" ] && grep -q '^Absolute spelling\.$' "$repo/docs/other/decisions/2026-10-19-one-elsewhere.md"; then pass "an absolute header path under the repository root still binds"; else fail "absolute header (rc $RC, err: $ERR)"; fi

# >>> later tasks append their checks above this line <<<

if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
