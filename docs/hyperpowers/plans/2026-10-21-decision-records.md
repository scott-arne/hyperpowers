# Decision Records Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** docs/hyperpowers/specs/2026-10-21-decision-records-design.md

**Goal:** Every shipped spec leaves one short record per decision under `docs/hyperpowers/decisions/`, compiled at finish by a script from the spec's own Decisions list, with a background subagent adding what implementation changed, and the plan removed from the tree in the same commit.

**Architecture:** A dependency-free bash compiler (`decisions-compile`) owns the records, the index and the spec's Outcome line and is re-runnable in every state; a prompt file defines the extractor subagent, dispatched in the background under SDD after the final fix wave and collected, never waited for, by the finishing skill after the full suite passes; the finishing skill stages the result, shows the complete diff inside its existing options message, and commits after the answer. Brainstorming reads the generated index and writes the Decisions list the compiler consumes.

**Tech Stack:** bash (git, awk, sed, date, POSIX coreutils; BSD and GNU, `LC_ALL=C`), markdown skill text, the Claude Code Agent tool's background dispatch, offline bash test suites under `tests/claude-code/`, print-mode Claude Code sessions for the rehearsals.

## Global Constraints

- Spec authority: `docs/hyperpowers/specs/2026-10-21-decision-records-design.md`. Conflicts inside this plan resolve against it; Decision 12 records the human partner's acceptance of the serial cost in their words.
- Base and branch: a worktree branch `decision-records` off `main` at `d4ea6b5`, the base the spec's Branch line names too (a later docs-only commit that amended that line to say so is fine to include; the base named here is the floor). It contains the spec (`e829db0`), the allowlist change (`7de7dad`) and the plugin-install note (`8197fe2`). The in-flight `sdd-turn-liveness` branch edits `skills/subagent-driven-development/SKILL.md` only around its "Continuous execution" paragraph (near line 16) and its "Waiting on dispatched subagents" paragraph (near line 227); no task here touches either.
- The compiler uses git, awk, sed, date and POSIX coreutils only: no Python, no Node, no network, no third-party tool, no `seq`. It sets `LC_ALL=C` for itself so slugs and sort order are the same on every host. Every construct runs identically under macOS BSD userland and GNU: no `sed -i`, no `readlink -f`, no `date -d`, no awk interval expressions (`{n,m}`), no GNU-only awk functions.
- The compiler validates everything before its first write, writes idempotently, stages last with `git add -A` over the paths it owns (so a retry stages what an earlier failed run wrote), and never commits. Exit 0 success; exit 2 input problem with nothing written; exit 3 a git failure after the files were written. Every failure prints one line to stderr beginning with the spec's repository-relative path. Every path crosses an interface either as an argument, one per array element, or NUL-delimited; nothing is word-split from a space-separated string.
- Records and the extractor's notes name modules, functions, tests and invariants, never line numbers.
- Skill text uses "your human partner"; no Red Flags table or rationalization list is reworded; one row is added to the finishing skill's table.
- Tests: `tests/claude-code/test-decisions-compile.sh` grows across Tasks 1 to 6 by appending before its marker line; it runs with one `bash` call, uses `mktemp -d` repositories, and contains no here-string (`tests/hooks/test-no-heredocs-in-hooks.sh` bans them under `tests/`; heredocs are allowed). Every new or changed shell file is `shellcheck -x` clean. Every task that changes a file under `skills/` ends with `bash tests/packaging/test-no-orphan-skill-files.sh` and `bash tests/packaging/test-skill-frontmatter.sh` passing before its commit.
- Commit messages: imperative subject in the repository's style (`feat(finishing): ...`, `test(claude-code): ...`, `docs: ...`), no AI-attribution lines, no `Co-Authored-By`. Stage only the task's files. Branch-level diff approval happens before merge, as every SDD run in this repository does (plan `docs/hyperpowers/plans/2026-07-23-gate-resilience-telemetry.md`, Global Constraints).
- Evidence directory for live artifacts: `evidence/2026-10-21-decision-records/` inside the hyperpowers-evals clone at `evals/` (committed there with `git -C evals add evidence/...`, never here). The evidence note in this repository is `docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md`.
- `DECISIONS_COMPILE_DATE=YYYY-MM-DD` overrides the date the compiler uses for a first write; tests set it to simulate a later day. Nothing else reads it.
- `~/.codex/AGENTS.md` still carries the removed "never commit planning files" rule (lines 7 and 28); it governs Codex sessions only and is the human partner's file. It is not touched by this plan and is named in the hand-off.

## Grounding

- Helper script shape (header comment with Usage and exit codes, `set -euo pipefail`, `SCRIPT_DIR`, usage on wrong arity, `wrote <path>: ...` success line): `skills/subagent-driven-development/scripts/review-package:1-70`.
- Markdown parsing in awk with a fence toggle and a heading match: `skills/subagent-driven-development/scripts/task-brief:32-38`.
- Per-run scratch directory under the user cache: `skills/requesting-code-review/scripts/codex-review-dir:41-51` (prints a fresh `run-XXXXXXXX` directory).
- Offline test suite shape (`failures`, `TEST_ROOT`, `pass`/`fail`, `make_repo` with `git init -q -b main`, `case` assertions, `STATUS: PASSED`): `tests/claude-code/test-sdd-dir-path.sh:1-29` and `:30-120`, final block at its tail.
- Allowlist script and test, the closest sibling to the compiler: `skills/writing-plans/scripts/docs-allowlist:1-59`, `tests/claude-code/test-docs-allowlist.sh:1-136`.
- Prompt-file shape (title, purpose, a fenced `Subagent (general-purpose):` block with `[PLACEHOLDERS]`, a read-only clause, "You Do Not Dispatch Subagents"): `skills/subagent-driven-development/re-review-prompt.md:1-60`.
- Orphan guard: every file under `skills/` other than `SKILL.md` must have its basename mentioned in a tracked file outside `docs/`, `CHANGELOG.md`, `RELEASE-NOTES.md`: `tests/packaging/test-no-orphan-skill-files.sh:1-50`.
- Finishing skill anchors: Step 1 `skills/finishing-a-development-branch/SKILL.md:16-28`; Step 4 menu `:55-85`; rationalization table ends `:226`.
- SDD anchors: process graph `skills/subagent-driven-development/SKILL.md:47-116` (edge at `:112`); Setup's spec paragraph `:167-174`; Final Review `:582-626` (re-review paragraph ends `:608`); Finish `:627-642`; example `skills/subagent-driven-development/example-workflow.md:70-77`.
- Brainstorming anchors: "Understanding the idea" bullet `skills/brainstorming/SKILL.md:211`; Documentation block first bullet `:297-298`.
- writing-plans anchor: the Mirror paragraph ends `skills/writing-plans/SKILL.md:175`.
- Error-message style for scripts: `skills/subagent-driven-development/scripts/sdd-dir:30-42` (`<script>: <reason>: <path>` on stderr, exit 2).
- Headless rehearsal launcher: `evals/evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:1-30` (empty `CLAUDE_CONFIG_DIR`, the `env -u` list, `--plugin-dir`, `--output-format stream-json --verbose`, `--dangerously-skip-permissions`, `--max-budget-usd`, `--model`).
- none: no existing script in this repository writes markdown tables or edits a tracked markdown file in place; the compiler's index and Outcome writers follow the awk style of `task-brief` and nothing else.

---

### Task 1: `decisions-compile` parses the Decisions list and writes records

**Risk tier:** high — a durable-record writer; other machinery (the extractor's numbering, the finishing commit) trusts its output.

**Files:**
- Create: `skills/finishing-a-development-branch/scripts/decisions-compile`
- Create: `tests/claude-code/test-decisions-compile.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `decisions-compile SPEC [--dry-run]`; exit 0/2 as in Global Constraints; stdout: the summary line `wrote <W> records, updated <U>, superseded 0, undocumented 0, proposed supersessions 0, index <records>/README.md` then one verb line per record `wrote|updated <path> (decision <N>: <title>)`; with `--dry-run`, `dry run: <count> decisions, index <path>` then `would write|would update ...` lines and nothing written. The record format of spec Design §1 without the `Supersedes:` line. Functions later tasks extend: `title_of`, `slug_of`, `identity_of`, `find_existing`, `existing_field`, `existing_notes`, `render_record`, `write_if_changed`; arrays `titles`, `files`, `existing`, `verb_lines`; scalars `count`, `root`, `spec_rel`, `records_dir`, `records_rel`, `index_rel`, `today`, `spec_date`, `tmp`. The test's helpers `make_repo`, `write_spec`, `run_compile`, `commit_all` and its marker line.

**Mirror:** `skills/subagent-driven-development/scripts/review-package:1-30` for the header, arity check and stderr style; `tests/claude-code/test-docs-allowlist.sh:1-40` for the test preamble.

- [ ] **Step 1: Write the test file with the first checks**

Create `tests/claude-code/test-decisions-compile.sh`:

```bash
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
# output behind a symlink.
TEST_ROOT="$(cd "$(mktemp -d)" && pwd -P)"
cleanup() { rm -rf "$TEST_ROOT"; }
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

# >>> later tasks append their checks above this line <<<

if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: `STATUS: FAILED`; every `run_compile` reports exit 127 (the script does not exist) and the content checks fail.

- [ ] **Step 3: Write the compiler**

Create `skills/finishing-a-development-branch/scripts/decisions-compile` and `chmod +x` it:

```bash
#!/usr/bin/env bash
# decisions-compile: lift a spec's Decisions list into one record per
# decision under the decisions/ sibling of the spec's directory.
#
# The spec is the only source of a record's title and decision text; a
# re-run refreshes them and keeps the record's filename and Recorded date.
# Nothing is written before every input has been validated, and nothing is
# ever committed. Design: docs/hyperpowers/specs/2026-10-21-decision-records-design.md.
#
# Usage: decisions-compile SPEC [--dry-run]
# Exit 2: an input problem (no spec, no decisions list, an unresolvable
# filename collision); nothing has been written.
set -euo pipefail
# Slugs, sorting and character classes must not depend on the host locale.
export LC_ALL=C

usage() {
  echo "usage: decisions-compile SPEC [--dry-run]" >&2
  exit 2
}

mode=compile
spec=""
dry_run=false
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) if $dry_run; then usage; fi; dry_run=true; shift ;;
    -*) usage ;;
    *) [ -z "$spec" ] || usage; spec=$1; shift ;;
  esac
done
[ -n "$spec" ] || usage

die2() { echo "$1" >&2; exit 2; }
die3() { echo "$1" >&2; exit 3; }

# --- paths ------------------------------------------------------------------
[ -f "$spec" ] || die2 "$spec: no such spec file"
spec_dir=$(cd "$(dirname "$spec")" && pwd -P)
spec_abs="$spec_dir/$(basename "$spec")"
root=$(git -C "$spec_dir" rev-parse --show-toplevel 2>/dev/null) || die2 "$spec: not inside a git repository"
root=$(cd "$root" && pwd -P)
spec_rel=${spec_abs#"$root"/}
records_dir="$(dirname "$spec_dir")/decisions"
records_rel=${records_dir#"$root"/}
index_rel="$records_rel/README.md"
today=${DECISIONS_COMPILE_DATE:-$(date +%F)}
spec_base=$(basename "$spec_abs")
case "$spec_base" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) spec_date=${spec_base:0:10} ;;
  *) spec_date=$today ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- helpers ----------------------------------------------------------------
trim_blank() {  # drop trailing blank lines of a file, in place, BSD and GNU alike
  awk '{ lines[NR] = $0 } END { n = NR; while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }' "$1" > "$1.t" && mv "$1.t" "$1"
}

title_of() {  # item file -> title (bold text, or the first clause of line 1)
  local first t
  first=$(head -n 1 "$1")
  if [[ $first =~ ^\*\*([^*]+)\*\* ]]; then
    t=${BASH_REMATCH[1]}
    case "$t" in *.|*:) t=${t%?} ;; esac
    printf '%s\n' "$t"
  else
    printf '%s\n' "$first" | awk '{ s = $0; i = index(s, ". "); j = index(s, ": "); k = i; if (j > 0 && (k == 0 || j < k)) k = j; if (k > 0) s = substr(s, 1, k - 1); print substr(s, 1, 80) }'
  fi
}

slug_of() {  # title -> filename slug, at most 60 characters, cut at a hyphen
  local s next
  s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  if [ ${#s} -gt 60 ]; then
    next=${s:60:1}
    s=${s:0:60}
    if [ "$next" != "-" ]; then case "$s" in *-*) s=${s%-*} ;; esac; fi
    s=${s%-}
  fi
  printf '%s\n' "$s"
}

identity_of() { printf -- '- Spec: %s (decision %s)\n' "$spec_rel" "$1"; }

find_existing() {  # identity line -> the record carrying it, or nothing
  [ -d "$records_dir" ] || return 0
  grep -lxF -e "$1" "$records_dir"/*.md 2>/dev/null | head -n 1 || true
}

existing_field() { sed -n "s/^- $2: //p" "$1" | head -n 1; }

existing_notes() {  # record -> body of its "What implementation changed" section
  awk 'f { print } /^## What implementation changed$/ { f = 1 }' "$1" | awk 'NR == 1 && /^$/ { next } { print }' > "$tmp/notes-body"
  trim_blank "$tmp/notes-body"
  cat "$tmp/notes-body"
}

# write_if_changed FILE CONTENT-FILE: returns 0 when FILE changed, 1 when it
# was already identical.
write_if_changed() {
  if [ -f "$1" ] && cmp -s "$1" "$2"; then return 1; fi
  mkdir -p "$(dirname "$1")"
  cp "$2" "$1"
  return 0
}

render_record() {  # N -> the record text
  local n=$1 target status rec_date recorded notes_body
  target="$records_dir/${files[n]}"
  if [ "${existing[n]}" = 1 ]; then
    status=$(existing_field "$target" Status)
    rec_date=$(existing_field "$target" Recorded | cut -c1-10)
    notes_body=$(existing_notes "$target")
  fi
  [ -n "${status:-}" ] || status=accepted
  [ -n "${rec_date:-}" ] || rec_date=$today
  [ -n "${notes_body:-}" ] || notes_body="Nothing recorded."
  recorded=$rec_date
  if [ "$notes_body" != "Nothing recorded." ]; then
    recorded="$recorded; notes from the branch diff by a subagent at finish"
  fi
  printf '# %s\n\n- Status: %s\n' "${titles[n]}" "$status"
  identity_of "$n"
  printf -- '- Recorded: %s\n' "$recorded"
  printf '\n## Decision\n\n'
  cat "$tmp/item-$n.txt"
  printf '\n## What implementation changed\n\n%s\n' "$notes_body"
}

# --- 1. the Decisions list --------------------------------------------------
# The first level-two heading whose text contains "decision" opens the
# section; the next level-two heading closes it for good. A top-level list
# marker starts an item; everything until the next marker or the closing
# heading belongs to that item. A continuation line loses the marker's width
# of leading spaces when it has at least that many, and is otherwise kept as
# written. A fence (``` or ~~~, up to three spaces of indentation, closed by
# the same character) neither opens nor closes anything and starts no item;
# its lines are ordinary item text.
awk -v out="$tmp" '
  function fence_mark(s,   m) {
    if (match(s, /^ ? ? ?(```+|~~~+)/)) { m = substr(s, RSTART, RLENGTH); sub(/^ */, "", m); return substr(m, 1, 1) }
    return ""
  }
  {
    fm = fence_mark($0)
    if (!fence && fm != "") { fence = 1; fch = fm; code = 1 }
    else if (fence && fm != "" && fm == fch) { fence = 0; code = 1 }
    else code = fence
  }
  !code && /^## / {
    if (insec == 1) { insec = 2 }
    else if (insec == 0 && tolower($0) ~ /decision/) { insec = 1; next }
  }
  insec != 1 { next }
  !code && match($0, /^([0-9]+[.)]|[-*]) +/) {
    n++; cur = out "/item-" n ".txt"; width = RLENGTH
    print substr($0, RLENGTH + 1) > cur
    next
  }
  n > 0 {
    i = 0
    while (i < width && substr($0, i + 1, 1) == " ") i++
    if (i == width) print substr($0, width + 1) > cur
    else print > cur
  }
' "$spec_abs"
count=$(find "$tmp" -name 'item-*.txt' | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || die2 "$spec_rel: no decisions list (add \"## Decisions\" with one list item per decision)"

# --- 2. titles, slugs, filenames (nothing written yet) ----------------------
declare -a titles files existing
planned=" "
for ((n = 1; n <= count; n++)); do
  item="$tmp/item-$n.txt"
  trim_blank "$item"
  titles[n]=$(title_of "$item")
  slug=$(slug_of "${titles[n]}")
  [ -n "$slug" ] || slug="decision-$n"
  ex=$(find_existing "$(identity_of "$n")")
  if [ -n "$ex" ]; then
    files[n]=$(basename "$ex")
    existing[n]=1
  else
    existing[n]=0
    f="$spec_date-$slug.md"
    if [ -e "$records_dir/$f" ] || [[ $planned == *" $f "* ]]; then
      f="$spec_date-$slug-$n.md"
      if [ -e "$records_dir/$f" ] || [[ $planned == *" $f "* ]]; then
        die2 "$spec_rel: decision $n: filename $f is taken by another record; give the decision a distinct title"
      fi
    fi
    files[n]=$f
  fi
  planned="$planned${files[n]} "
done

# --- 3. dry run ---------------------------------------------------------------
verb_lines=()
if $dry_run; then
  echo "dry run: $count decisions, index $index_rel"
  for ((n = 1; n <= count; n++)); do
    if [ "${existing[n]}" = 1 ]; then v="would update"; else v="would write"; fi
    echo "$v $records_rel/${files[n]} (decision $n: ${titles[n]})"
  done
  exit 0
fi

# --- 4. records ---------------------------------------------------------------
wrote=0; updated=0; superseded=0; undocumented=0; proposed=0
mkdir -p "$records_dir"
for ((n = 1; n <= count; n++)); do
  target="$records_dir/${files[n]}"
  render_record "$n" > "$tmp/render"
  if [ "${existing[n]}" = 1 ]; then
    if write_if_changed "$target" "$tmp/render"; then
      updated=$((updated + 1))
      verb_lines+=("updated $records_rel/${files[n]} (decision $n: ${titles[n]})")
    fi
  else
    write_if_changed "$target" "$tmp/render" || true
    wrote=$((wrote + 1))
    verb_lines+=("wrote $records_rel/${files[n]} (decision $n: ${titles[n]})")
  fi
done

# --- 5. report --------------------------------------------------------------
echo "wrote $wrote records, updated $updated, superseded $superseded, undocumented $undocumented, proposed supersessions $proposed, index $index_rel"
if [ ${#verb_lines[@]} -gt 0 ]; then printf '%s\n' "${verb_lines[@]}"; fi
```

- [ ] **Step 4: Run the suite, shellcheck, and the packaging suites**

Run: `bash tests/claude-code/test-decisions-compile.sh`, then `shellcheck -x skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh`, then `bash tests/packaging/test-no-orphan-skill-files.sh` and `bash tests/packaging/test-skill-frontmatter.sh`.
Expected: `STATUS: PASSED` three times, shellcheck silent (the script's basename appears in the test file, which satisfies the orphan guard). If shellcheck flags an array expansion (SC2207, SC2086), fix the expansion; never disable the warning. If `[[ $first =~ ... ]]` misbehaves on the host bash, assign the pattern to a variable first (`re='^\*\*([^*]+)\*\*'; [[ $first =~ $re ]]`).

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh
git commit -m "feat(finishing): decisions-compile lifts a spec's Decisions list into one record per decision"
```

---

### Task 2: The index, the Outcome line, staging and the paths contract

**Risk tier:** high — edits a tracked spec in place, stages git changes, and produces the pathspec the finishing commit consumes.

**Files:**
- Modify: `skills/finishing-a-development-branch/scripts/decisions-compile` (Usage, the argument loop, a `--paths-file` preflight, new functions `escape_cell`, `render_index`, `outcome_line`, `render_spec`, `emit_paths`, new sections after the records loop, the report)
- Modify: `tests/claude-code/test-decisions-compile.sh` (append before the marker)

**Interfaces:**
- Consumes: Task 1's functions and arrays.
- Produces: `decisions-compile SPEC [--paths-file FILE] [--dry-run]`; the index of spec Design §1 at `<records>/README.md`; the spec's `**Outcome:**` line; staging by `git add -A` over the records directory and the spec; the `paths:` line and the NUL-delimited `--paths-file`; exit 3 on a failed git operation; functions `render_index` (used by Task 3's `--reindex`) and `emit_paths` (extended by Task 5 with the plan).

**Mirror:** Task 1's `render_record` and `write_if_changed`.

- [ ] **Step 1: Append the failing checks**

Insert before the line `# >>> later tasks append their checks above this line <<<`:

```bash
# --- 7. index, Outcome line, staging, paths -------------------------------
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

# --- 8. index escaping and a spec without a title -------------------------
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

# --- 8b. a symlinked records directory is refused (correction 2026-10-22) ----
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
```

- [ ] **Step 2: Run to see check 7 and 8 fail**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: checks 1 to 6 pass; `--paths-file` is a usage error and no index, Outcome line or staging exists, so 7 and 8 fail.

- [ ] **Step 3: Extend the compiler**

(a) Header `# Usage:` and `usage()` read `decisions-compile SPEC [--paths-file FILE] [--dry-run]`; add to the header: `Exit 3: a git operation failed after the files were written; running the same command again completes the staging.`

(b) Argument loop: add `paths_file=""` beside `dry_run=false` and the arm, before `-*) usage ;;`:

```bash
    --paths-file) [ $# -ge 2 ] || usage; [ -z "$paths_file" ] || usage; paths_file=$2; shift 2 ;;
```

(c) After the `# --- paths ---` block (after `esac` of `spec_date`), preflight the destination:

```bash
if [ -n "$paths_file" ]; then
  paths_dir=$(dirname "$paths_file")
  { [ -d "$paths_dir" ] && [ -w "$paths_dir" ]; } || die2 "$spec_rel: --paths-file directory is not writable: $paths_dir"
fi
```

(d) Add these functions after `render_record` in the helpers block:

```bash
escape_cell() { printf '%s' "$1" | sed 's/|/\\|/g; s/\[/\\[/g; s/\]/\\]/g'; }

render_index() {  # records dir -> the README text
  local d=$1 f title status specp date link cur=0 sup=0 tab fname
  tab=$(printf '\t')
  : > "$tmp/rows"
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = README.md ] && continue
    title=$(sed -n '1s/^# //p' "$f")
    status=$(existing_field "$f" Status)
    specp=$(existing_field "$f" Spec | sed 's/ (decision [0-9]*)$//')
    date=$(basename "$f" | cut -c1-10)
    printf '%s\t%s\t%s\t%s\t%s\n' "$date" "$title" "$status" "$specp" "$(basename "$f")" >> "$tmp/rows"
  done
  sort -t "$tab" -k1,1r -k2,2 "$tmp/rows" > "$tmp/rows.sorted"
  : > "$tmp/cur"; : > "$tmp/sup"
  while IFS="$tab" read -r date title status specp fname; do
    case "$specp" in
      "$(dirname "$records_rel")"/*) link="../${specp#"$(dirname "$records_rel")"/}" ;;
      *) link="/$specp" ;;
    esac
    if [ "$status" = accepted ]; then
      cur=$((cur + 1))
      printf '| %s | [%s](%s) | [%s](%s) |\n' "$date" "$(escape_cell "$title")" "$fname" "$(escape_cell "$(basename "$specp")")" "$link" >> "$tmp/cur"
    else
      sup=$((sup + 1))
      printf '| %s | [%s](%s) | %s |\n' "$date" "$(escape_cell "$title")" "$fname" "$(escape_cell "${status#superseded by }")" >> "$tmp/sup"
    fi
  done < "$tmp/rows.sorted"
  printf '# Decisions\n\nGenerated by decisions-compile. Do not edit; re-run the compiler.\n%s current, %s superseded.\n\n## Current\n\n| Date | Decision | Spec |\n|---|---|---|\n' "$cur" "$sup"
  cat "$tmp/cur"
  if [ "$sup" -gt 0 ]; then
    printf '\n## Superseded\n\n| Date | Decision | Superseded by |\n|---|---|---|\n'
    cat "$tmp/sup"
  fi
}

outcome_line() { printf '**Outcome:** implemented %s; %s decisions under %s/.' "$1" "$count" "$records_rel"; }

render_spec() {  # the spec text with its Outcome line written or rewritten
  local current odate line
  current=$(head -n 30 "$spec_abs" | grep -m 1 '^\*\*Outcome:\*\*' || true)
  if [ -n "$current" ]; then
    odate=$(printf '%s' "$current" | sed -n 's/.*implemented \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\);.*/\1/p')
    [ -n "$odate" ] || odate=$today
    line=$(outcome_line "$odate")
    awk -v line="$line" 'NR <= 30 && !r && /^\*\*Outcome:\*\*/ { print line; r = 1; next } { print }' "$spec_abs"
  else
    line=$(outcome_line "$today")
    awk -v line="$line" '
      NR == 1 && /^# / { print; if ((getline nxt) > 0) { if (nxt ~ /^$/) { print ""; print line; print "" } else { print ""; print line; print ""; print nxt } } else { print ""; print line; print "" }; next }
      NR == 1 { print line; print ""; print; next }
      { print }
    ' "$spec_abs"
  fi
}

# stage_owned: everything under the records directory plus the spec, so a
# retry after a failed run stages what that run wrote and never staged.
stage_owned() {
  git -C "$root" add -A -- "$records_rel" "$spec_rel" || die3 "$spec_rel: git add failed; run the same command again to complete the staging"
}

# emit_paths: the compiler-owned paths whose staged content differs from
# HEAD, NUL-delimited into --paths-file and space-joined on stdout.
emit_paths() {
  git -C "$root" diff --cached --name-only -z -- "$records_rel" "$spec_rel" > "$tmp/paths.z" || die3 "$spec_rel: git diff --cached failed"
  if [ -n "$paths_file" ]; then cp "$tmp/paths.z" "$paths_file" || die3 "$spec_rel: cannot write $paths_file"; fi
  tr '\0' ' ' < "$tmp/paths.z" | sed 's/ $//'
}
```

(e) In the dry-run block, after the `would write` loop and before `exit 0`, add the would-stage list:

```bash
  {
    git -C "$root" diff --cached --name-only -- "$records_rel" "$spec_rel"
    git -C "$root" ls-files --others --exclude-standard -- "$records_rel"
    for ((n = 1; n <= count; n++)); do echo "$records_rel/${files[n]}"; done
    echo "$index_rel"; echo "$spec_rel"
  } | sort -u > "$tmp/would-stage"
  echo "paths: $(tr '\n' ' ' < "$tmp/would-stage" | sed 's/ $//')"
```

(f) After the records loop (section 4) and before `# --- 5. report ---`, add:

```bash
# --- 4b. the index and the spec ----------------------------------------------
render_index "$records_dir" > "$tmp/index"
if [ -f "$records_dir/README.md" ]; then idx_verb=updated; else idx_verb=wrote; fi
if write_if_changed "$records_dir/README.md" "$tmp/index"; then verb_lines+=("$idx_verb $index_rel"); fi

render_spec > "$tmp/spec"
if write_if_changed "$spec_abs" "$tmp/spec"; then verb_lines+=("updated $spec_rel (outcome)"); fi

# --- 4c. stage ----------------------------------------------------------------
stage_owned
```

(g) Replace the report section with:

```bash
# --- 5. report --------------------------------------------------------------
echo "wrote $wrote records, updated $updated, superseded $superseded, undocumented $undocumented, proposed supersessions $proposed, index $index_rel"
if [ ${#verb_lines[@]} -gt 0 ]; then printf '%s\n' "${verb_lines[@]}"; fi
paths=$(emit_paths)
if [ -n "$paths" ]; then echo "paths: $paths"; else echo "paths:"; fi
```

(h) **Correction (2026-10-22), carried from Task 1's Codex gate at its cap.** The containment guard Task 1 added (`case "$records_dir" in "$root"/*)`) checks a string, so a `decisions` entry that is a symbolic link to a directory outside the repository passes it and the records land outside the repository. `spec_dir` is already physical (`pwd -P`), so the only way out is the `decisions` entry itself. Directly after that `case`, add:

```bash
# An existing decisions entry must be a plain directory: a symbolic link
# would carry the records outside the repository that spec_dir's physical
# path keeps them in.
if [ -e "$records_dir" ] && { [ -L "$records_dir" ] || [ ! -d "$records_dir" ]; }; then
  die2 "$spec_rel: $records_rel exists but is not a plain directory"
fi
```

Task 1's finding 10 (gate round 3) is closed by this step; Task 1's ledger entry defers it here.

- [ ] **Step 4: Run the suite, shellcheck, packaging**

Run: `bash tests/claude-code/test-decisions-compile.sh && shellcheck -x skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh && bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh`
Expected: `STATUS: PASSED` three times, shellcheck silent. If the `getline nxt` branch misbehaves on the host awk, replace `render_spec`'s insertion with a bash two-pass: `head -n 1`, then the line, then `tail -n +2`, with the blank-line cases handled by `sed -n 2p`.

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh
git commit -m "feat(finishing): decisions-compile writes the index and the spec's Outcome line, stages its paths, and hands the commit a NUL-delimited pathspec"
```

---

### Task 3: Supersession and `--reindex`

**Risk tier:** high — rewrites the status of existing records (durable history) and must accept its own prior run.

**Files:**
- Modify: `skills/finishing-a-development-branch/scripts/decisions-compile` (Usage, the argument loop and mode checks, the paths block, section 2, `render_record`, a new section 4a, a `--reindex` branch)
- Modify: `tests/claude-code/test-decisions-compile.sh` (append before the marker)

**Interfaces:**
- Consumes: Task 1's arrays and `existing_field`; Task 2's `render_index`, `write_if_changed`, `stage_owned`.
- Produces: `Supersedes:` lines in items are validated (an existing record in the records directory, not this spec's, status `accepted` or already naming this record) and rendered as `- Supersedes: <paths>`; each superseded target's status is written once with the full sorted set; `decisions-compile --reindex RECORDS_DIR`, which accepts no other option; the `superseded <S>` count; the array `sup_of` (newline-delimited paths per decision) Task 6's undo test relies on indirectly.

**Mirror:** Task 1's section 2 loop for where validation lives before any write.

- [ ] **Step 1: Append the failing checks**

Insert before the marker line:

Correction (2026-10-22): the task review and the Codex gate added checks the suite carries beyond this listing, and the suite is the authority for their text: section 15 gains an interrupted-run state (targets updated, record not yet rewritten) that the next run completes, incremental fan-in after a compile, a swap of two decisions' targets, and a target whose status already names a record this run has yet to write; section 16 gains a second `--reindex` reporting `unchanged`, a `rm --cached` index that is re-staged, and `--reindex docs/hyperpowers/specs` refused; a section 18 refuses a `./` spelling and a symlinked record as Supersedes targets.

```bash
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
    if [ "$RC" -eq 2 ] && [ -z "$(git -C "$repo" status --porcelain | grep -v 'bad-design')" ]; then
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
if [ "$RC" -eq 0 ] && [ -f "$idx" ] && [ -z "$(git -C "$repo" status --porcelain | grep -v README.md)" ]; then pass "--reindex rewrites only README.md"; else fail "--reindex (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain))"; fi
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
```

- [ ] **Step 2: Run to see sections 15, 16 and 17 fail**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: sections 1 to 14 pass (Task 2's rounds added 11 to 14); 15 fails (no Supersedes handling), 16 fails (`--reindex` is a usage error) and 17 fails (the link is accepted).

- [ ] **Step 3: Add supersession and reindex**

(a) Header `# Usage:` and `usage()` gain a second line, `decisions-compile --reindex RECORDS_DIR`.

(b) Argument loop: add `reindex_dir=""` beside `paths_file=""`, the arm (before `-*) usage ;;`):

```bash
    --reindex) [ $# -ge 2 ] || usage; [ "$mode" = compile ] || usage; mode=reindex; reindex_dir=$2; shift 2 ;;
```

and replace `[ -n "$spec" ] || usage` with the mode checks:

```bash
case "$mode" in
  reindex) if [ -n "$spec" ] || [ -n "$paths_file" ] || $dry_run; then usage; fi ;;
  *) [ -n "$spec" ] || usage ;;
esac
```

(c) Replace the `# --- paths ---` block (through the `spec_date` `esac`) with a version that serves both modes; the `--paths-file` preflight and `tmp`, `trap` follow it unchanged. Correction (2026-10-22): the block keeps the guards Task 2's gate rounds added (the containment check, the plain records directory, the regular index file) and adds the symlinked-spec guard Task 2's gate found at its cap, which the human partner carried into this task; a reindex of the repository root is refused the same way a root-level spec is:

```bash
# --- paths ------------------------------------------------------------------
if [ "$mode" = reindex ]; then
  [ -d "$reindex_dir" ] || die2 "$reindex_dir: no such records directory"
  records_dir=$(cd "$reindex_dir" && pwd -P)
  # Correction (2026-10-22): any other directory would have its .md files
  # rendered as records and its README.md replaced (Task 3 gate round 1).
  [ "$(basename "$records_dir")" = decisions ] || die2 "$reindex_dir: not a records directory (its name must be decisions)"
  root=$(git -C "$records_dir" rev-parse --show-toplevel 2>/dev/null) || die2 "$reindex_dir: not inside a git repository"
  root=$(cd "$root" && pwd -P)
  case "$records_dir" in
    "$root"/*) ;;
    *) die2 "$reindex_dir: the records directory must be a subdirectory of the repository" ;;
  esac
  records_rel=${records_dir#"$root"/}
  spec_rel="$records_rel"
  spec_abs=""
  count=0
else
  [ -f "$spec" ] || die2 "$spec: no such spec file"
  # A link at the spec path would be replaced by the Outcome write, leaving
  # its target without the line.
  [ ! -L "$spec" ] || die2 "$spec: the spec must be a regular file, not a symbolic link"
  spec_dir=$(cd "$(dirname "$spec")" && pwd -P)
  spec_abs="$spec_dir/$(basename "$spec")"
  root=$(git -C "$spec_dir" rev-parse --show-toplevel 2>/dev/null) || die2 "$spec: not inside a git repository"
  root=$(cd "$root" && pwd -P)
  spec_rel=${spec_abs#"$root"/}
  records_dir="$(dirname "$spec_dir")/decisions"
  records_rel=${records_dir#"$root"/}
  case "$records_dir" in
    "$root"/*) ;;
    *) die2 "$spec_rel: the spec must live in a subdirectory of the repository (its records go to the sibling decisions/ of that directory)" ;;
  esac
  # An existing decisions entry must be a plain directory: a symbolic link
  # would carry the records outside the repository that spec_dir's physical
  # path keeps them in.
  if [ -L "$records_dir" ] || { [ -e "$records_dir" ] && [ ! -d "$records_dir" ]; }; then
    die2 "$spec_rel: $records_rel exists but is not a plain directory"
  fi
fi
index_rel="$records_rel/README.md"
# A directory or a link at the index path would receive the index by rename
# instead of being replaced.
if [ -L "$records_dir/README.md" ] || { [ -e "$records_dir/README.md" ] && [ ! -f "$records_dir/README.md" ]; }; then
  die2 "$spec_rel: $index_rel exists but is not a regular file"
fi
today=${DECISIONS_COMPILE_DATE:-$(date +%F)}
spec_base=$(basename "${spec_abs:-x}")
case "$spec_base" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) spec_date=${spec_base:0:10} ;;
  *) spec_date=$today ;;
esac
```

(d) After the helpers block (after `emit_paths`) and before `# --- 1. the Decisions list ---`, add the reindex branch:

```bash
# --- reindex ------------------------------------------------------------------
if [ "$mode" = reindex ]; then
  render_index "$records_dir" > "$tmp/index"
  if [ -f "$records_dir/README.md" ]; then v=updated; else v=wrote; fi
  if write_if_changed "$records_dir/README.md" "$tmp/index"; then changed=true; else changed=false; fi
  # Correction (2026-10-22): staged even when unchanged, so a retry after a
  # failed add completes it (the task review found the original printed
  # `unchanged` without staging).
  git -C "$root" add -- "$index_rel" || die3 "$records_rel: git add failed; run the same command again to complete the staging"
  if $changed; then echo "$v $index_rel"; else echo "unchanged $index_rel"; fi
  exit 0
fi
```

(e) In section 2: add `sup_of` and `prev_sup` to the declaration (`declare -a titles files existing sup_of prev_sup`). In the `if [ -n "$ex" ]` branch, after `existing[n]=1`, remember what the existing record superseded, so a line removed or retargeted since can be reconciled:

```bash
    prev_sup[n]=$(existing_field "$ex" Supersedes | tr ',' '\n' | sed 's/^ *//')
```

and in the `else` branch add `prev_sup[n]=""`. Then, after `trim_blank "$item"` and before `titles[n]=`, collect and validate the item's Supersedes paths; `sup_of[n]` holds them one per line:

```bash
  sup_of[n]=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$(printf '\n%s\n' "${sup_of[n]}")" in *"
$p
"*) continue ;; esac
    # Correction (2026-10-22): exactly one spelling per record, and no link,
    # so deduplication and the reconciliation compare paths as plain strings
    # and a status rewrite never replaces a link with a copy (gate round 1).
    [ "$p" = "$records_rel/${p##*/}" ] || die2 "$spec_rel: decision $n: Supersedes path is not a record in $records_rel: $p"
    [ ! -L "$root/$p" ] || die2 "$spec_rel: decision $n: Supersedes path is a symbolic link, not a record: $p"
    [ -f "$root/$p" ] || die2 "$spec_rel: decision $n: Supersedes path does not exist: $p"
    case "$(existing_field "$root/$p" Spec)" in "$spec_rel (decision "*) die2 "$spec_rel: decision $n: cannot supersede a record of this spec: $p" ;; esac
    sup_of[n]="${sup_of[n]:+${sup_of[n]}
}$p"
  done < <(sed -n 's/^[[:space:]]*Supersedes:[[:space:]]*//p' "$item" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
```

and, after the loop's `done` (still in section 2, before the dry run), the status check. Correction (2026-10-22): it runs once every planned filename is known, and a listed superseder passes when it is a record this run plans (written yet or not: an interrupted run may have updated the target first) or an on-disk record of this spec (fan-in and swaps before the freeze), so only an unrelated record refuses; `mine` is built here and section 4a reuses it:

```bash
# A target's status may already name a record this run is about to write (an
# earlier run was interrupted after the targets were updated), so every planned
# record counts as a legitimate superseder, written yet or not.
mine=" "
for ((n = 1; n <= count; n++)); do
  mine="$mine$records_rel/${files[n]} "
done
for ((n = 1; n <= count; n++)); do
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    st=$(existing_field "$root/$p" Status)
    case "$st" in
      accepted) ;;
      "superseded by "*)
        # Other records of this spec may already list themselves (fan-in, or a
        # swap of two decisions' targets); the reconciliation settles those.
        while IFS= read -r q; do
          [ -n "$q" ] || continue
          case "$mine" in *" $q "*) continue ;; esac
          if [ -f "$root/$q" ]; then
            case "$(existing_field "$root/$q" Spec)" in "$spec_rel (decision "*) continue ;; esac
          fi
          die2 "$spec_rel: decision $n: $p is already superseded by an unrelated record: $q"
        done < <(printf '%s\n' "${st#superseded by }" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        ;;
      *) die2 "$spec_rel: decision $n: $p has status \"$st\"" ;;
    esac
  done < <(printf '%s\n' "${sup_of[n]}")
done
```

(f) In `render_record`, after `printf -- '- Recorded: %s\n' "$recorded"`, add:

```bash
  if [ -n "${sup_of[n]:-}" ]; then
    printf -- '- Supersedes: %s\n' "$(printf '%s\n' "${sup_of[n]}" | paste -sd, - | sed 's/,/, /g')"
  fi
```

(g) Correction (2026-10-22): before the records loop (section 4), directly after its counters line `wrote=0; updated=0; superseded=0; undocumented=0; proposed=0`, add the reconciliation; targets are reconciled before the records are rewritten, so an interrupted run leaves the targets updated and the old records intact, and the next run reads those records' previous Supersedes lines and finishes the job (gate round 1). `mine` comes from (e). Every target this spec names now, or named in a previous run, gets one status line: what it already listed minus every record of this spec, plus this spec's records that name it now; a target nothing names any more returns to `accepted`. The `superseded <S>` count is the number of target status lines this run changed, restorations included.

```bash
# --- 4a. superseded targets ----------------------------------------------------
# Targets are reconciled before the records are rewritten: an interrupted run
# then leaves the targets updated and the old records intact, and the next run
# reads those records' previous Supersedes lines and finishes the job.
: > "$tmp/targets"
for ((n = 1; n <= count; n++)); do
  while IFS= read -r p; do
    [ -n "$p" ] && printf '%s\tnow\t%s\n' "$p" "$records_rel/${files[n]}" >> "$tmp/targets"
  done < <(printf '%s\n' "${sup_of[n]:-}")
  while IFS= read -r p; do
    [ -n "$p" ] && printf '%s\tprev\t%s\n' "$p" "$records_rel/${files[n]}" >> "$tmp/targets"
  done < <(printf '%s\n' "${prev_sup[n]:-}")
done
if [ -s "$tmp/targets" ]; then
  cut -f1 "$tmp/targets" | sort -u > "$tmp/target-list"
  while IFS= read -r p; do
    [ -f "$root/$p" ] || continue
    st=$(existing_field "$root/$p" Status)
    case "$st" in
      "superseded by "*) printf '%s\n' "${st#superseded by }" | tr ',' '\n' | sed 's/^ *//' | grep -v '^$' > "$tmp/listed" ;;
      *) : > "$tmp/listed" ;;
    esac
    : > "$tmp/set"
    while IFS= read -r q; do
      case "$mine" in *" $q "*) ;; *) printf '%s\n' "$q" >> "$tmp/set" ;; esac
    done < "$tmp/listed"
    awk -F '\t' -v t="$p" '$1 == t && $2 == "now" { print $3 }' "$tmp/targets" >> "$tmp/set"
    sort -u "$tmp/set" > "$tmp/set.sorted"
    if [ -s "$tmp/set.sorted" ]; then new="superseded by $(paste -sd, - < "$tmp/set.sorted" | sed 's/,/, /g')"; else new=accepted; fi
    if [ "$st" != "$new" ]; then
      awk -v s="$new" '!r && /^- Status: / { print "- Status: " s; r = 1; next } { print }' "$root/$p" > "$tmp/target"
      # Correction (2026-10-22): through write_if_changed (temporary file, then
      # rename), never cp onto a record; Task 1's gate found the in-place copy
      # could truncate a durable record. It returns 1 only for "unchanged",
      # which cannot happen here, and exits 3 on a failed write.
      write_if_changed "$root/$p" "$tmp/target" || true
      superseded=$((superseded + 1))
      verb_lines+=("updated $p ($new)")
    fi
  done < "$tmp/target-list"
fi
```

- [ ] **Step 4: Run the suite, shellcheck, packaging**

Run: `bash tests/claude-code/test-decisions-compile.sh && shellcheck -x skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh && bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh`
Expected: `STATUS: PASSED` three times, shellcheck silent.

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh
git commit -m "feat(finishing): decisions-compile validates Supersedes lines, rewrites each superseded record once, and regenerates an index with --reindex"
```

---

### Task 4: Notes from the extractor

**Risk tier:** high — model-written text enters durable records; the validation decides what is written and what is ignored.

**Files:**
- Modify: `skills/finishing-a-development-branch/scripts/decisions-compile` (Usage, the argument loop and mode checks, a `load_notes` function, `render_record`)
- Modify: `tests/claude-code/test-decisions-compile.sh` (append before the marker)

**Interfaces:**
- Consumes: Task 1's `render_record`, `existing_notes`, `trim_blank`, `count`, `$tmp`.
- Produces: `--notes FILE` per spec Design §3's grammar: valid when the first line is `# Decision notes: <path>` whose basename is the spec's basename, every level-two heading is `## Decision <N>` (N in range, each once, non-empty body), `## Supersessions` or `## Undocumented decisions`, and each optional section present holds at least one list item and nothing but list items. Anything else is reported on stderr as `notes ignored: <reason>` and the run proceeds without the file. Per-decision bodies replace the record's "What implementation changed" section and add the notes part to `Recorded:`; a decision the file does not mention keeps its existing section or reads "Nothing recorded." (spec Verification 7). The `undocumented <D>` and `proposed supersessions <P>` counts.

**Mirror:** Task 3's validation loop for the shape; the notes path fails open where Task 3 fails closed.

- [ ] **Step 1: Append the failing checks**

Insert before the marker line:

```bash
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
```

- [ ] **Step 2: Run to see sections 19 and 20 fail**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: sections 1 to 18 pass (Task 3's rounds added 15 to 18); `--notes` is a usage error so 19 fails, and 20 fails because a persisted Supersedes path is not yet validated.

- [ ] **Step 3: Add notes**

(a) Header `# Usage:` and `usage()` first line read `decisions-compile SPEC [--notes FILE] [--paths-file FILE] [--dry-run]`.

(b) Argument loop: `notes=""` beside `paths_file=""`; the arm:

```bash
    --notes) [ $# -ge 2 ] || usage; [ -z "$notes" ] || usage; notes=$2; shift 2 ;;
```

and in the mode checks, the `reindex)` arm also refuses `[ -n "$notes" ]`.

(c) After `render_record` in the helpers, add the notes loader. Correction (2026-10-22): the gate's first round found the original pass recognised only column-zero `## ` lines (a preamble was dropped, an indented or wrong-level heading was copied into a record body with any proposal list under it) and that the optional-section `grep -v | grep -qv` checks returned 141 under `pipefail` on a long malformed section; the function below is one pass with explicit state over every ATX heading and optional-section line, counts the items itself, and both reads fail open:

```bash
# --- notes ------------------------------------------------------------------
# The extractor's file is prose and proposals, never authority: anything
# malformed is reported once and the compile proceeds as if --notes had not
# been given. A decision the file does not mention keeps its section.
notes_valid=false
load_notes() {
  local f=$1 n reason="" first
  [ -f "$f" ] || { echo "notes ignored: no such file: $f" >&2; return 0; }
  first=$(head -n 1 "$f" 2>/dev/null) || { echo "notes ignored: cannot read $f" >&2; return 0; }
  case "$first" in
    "# Decision notes: "*) ;;
    *) echo "notes ignored: first line is not \"# Decision notes: <spec path>\"" >&2; return 0 ;;
  esac
  if [ "$(basename "${first#\# Decision notes: }")" != "$(basename "$spec_abs")" ]; then
    echo "notes ignored: first line names $(basename "${first#\# Decision notes: }"), not $(basename "$spec_abs")" >&2; return 0
  fi
  rm -f "$tmp"/note-*.txt "$tmp/notes-bad" "$tmp/notes-counts"
  # One pass over the whole file with explicit state and no early exit, so a
  # malformed line is found however much valid text follows it. Any ATX
  # heading is structural; only three exact forms open a section.
  awk -v out="$tmp" -v max="$count" '
    function bad(msg) { if (!reason) { reason = msg; print msg > (out "/notes-bad") } }
    NR == 1 { next }
    {
      t = $0; sub(/^ ? ? ?/, "", t)
      if (match(t, /^#+/) && RLENGTH <= 6 && (length(t) == RLENGTH || substr(t, RLENGTH + 1, 1) == " " || substr(t, RLENGTH + 1, 1) == "\t")) {
        mode = ""
        if ($0 ~ /^## Decision [0-9]+$/) {
          n = $3 + 0
          if (n < 1 || n > max) bad("decision " n " is out of range 1.." max)
          else if (seen[n]++) bad("duplicate section: " $0)
          else { mode = "dec"; cur = out "/note-" n ".txt"; printf "" > cur }
        } else if ($0 == "## Supersessions" || $0 == "## Undocumented decisions") {
          if (seen[$0]++) bad("duplicate section: " $0)
          else mode = ($0 == "## Supersessions") ? "sup" : "undoc"
        } else bad("unexpected heading: " $0)
        next
      }
      if (mode == "dec") { print > cur; next }
      if ($0 ~ /^[[:space:]]*$/) next
      if (mode == "sup") {
        if ($0 ~ /^- [0-9]+ supersedes ./) nsup++
        else bad("a Supersessions line is not \"- <N> supersedes <path>\"")
      } else if (mode == "undoc") {
        if ($0 ~ /^- ./) nundoc++
        else bad("an Undocumented decisions line is not a list item")
      } else bad("text before the first section")
    }
    END {
      if (("## Supersessions" in seen) && !nsup) bad("Supersessions has no \"- <N> supersedes <path>\" line")
      if (("## Undocumented decisions" in seen) && !nundoc) bad("Undocumented decisions has no list item")
      print nsup + 0, nundoc + 0 > (out "/notes-counts")
    }
  ' "$f" 2>/dev/null || {
    rm -f "$tmp"/note-*.txt "$tmp/notes-bad" "$tmp/notes-counts"
    echo "notes ignored: cannot read $f" >&2; return 0
  }
  [ -f "$tmp/notes-bad" ] && reason=$(head -n 1 "$tmp/notes-bad")
  if [ -z "$reason" ]; then
    for ((n = 1; n <= count; n++)); do
      [ -f "$tmp/note-$n.txt" ] || continue
      trim_blank "$tmp/note-$n.txt"
      awk 'NR == 1 && /^$/ { next } { print }' "$tmp/note-$n.txt" > "$tmp/note-$n.t" && mv "$tmp/note-$n.t" "$tmp/note-$n.txt"
      [ -s "$tmp/note-$n.txt" ] || { reason="empty body for decision $n"; break; }
    done
  fi
  if [ -n "$reason" ]; then
    echo "notes ignored: $reason" >&2
    rm -f "$tmp"/note-*.txt
    return 0
  fi
  notes_valid=true
  read -r proposed undocumented < "$tmp/notes-counts"
  return 0
}
```

(d) Move the line `wrote=0; updated=0; superseded=0; undocumented=0; proposed=0` from section 4 to just before `# --- 1. the Decisions list ---` (so `load_notes` can set the two counts), and after section 2's loop add:

```bash
[ -z "$notes" ] || load_notes "$notes"
```

(e) In `render_record`, replace `[ -n "${notes_body:-}" ] || notes_body="Nothing recorded."` with:

```bash
  if $notes_valid && [ -f "$tmp/note-$n.txt" ]; then notes_body=$(cat "$tmp/note-$n.txt"); fi
  [ -n "${notes_body:-}" ] || notes_body="Nothing recorded."
```

(f) Correction (2026-10-22): Task 3's gate found at its cap that the persisted `Supersedes:` header of an existing record feeds section 4a unvalidated, so a hand-edited or merge-conflicted record naming `../x.md` or a link could have that file's Status line rewritten; the human partner carried the guard here. In section 2's `if [ -n "$ex" ]` branch, directly after `prev_sup[n]=$(existing_field "$ex" Supersedes | tr ',' '\n' | sed 's/^ *//')`, validate every persisted entry with the spelling and link checks the spec's own lines get (a missing file is tolerated: section 4a skips it):

```bash
    # A persisted header is only as trustworthy as the last hand that touched
    # it: the same spelling and link rules as the spec's own lines, before any
    # write.
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      [ "$p" = "$records_rel/${p##*/}" ] || die2 "$spec_rel: decision $n: record ${ex#"$root"/} names a Supersedes path that is not a record in $records_rel: $p"
      [ ! -L "$root/$p" ] || die2 "$spec_rel: decision $n: record ${ex#"$root"/} names a Supersedes path that is a symbolic link: $p"
    done < <(printf '%s\n' "${prev_sup[n]}")
```

- [ ] **Step 4: Run the suite, shellcheck, packaging**

Run: `bash tests/claude-code/test-decisions-compile.sh && shellcheck -x skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh && bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh`
Expected: `STATUS: PASSED` three times, shellcheck silent.

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh
git commit -m "feat(finishing): decisions-compile takes the extractor's notes, validates them whole, and never lets a proposal reach a record"
```

---

### Task 5: Plan removal and recovery after a failed git operation

**Risk tier:** high — stages a deletion and defines the retry after a failed git step.

**Files:**
- Modify: `skills/finishing-a-development-branch/scripts/decisions-compile` (Usage, the argument loop and mode checks, plan resolution and validation, `render_record`'s Recorded line, a plan step after `stage_owned`, `emit_paths`, the dry-run list)
- Modify: `tests/claude-code/test-decisions-compile.sh` (append before the marker)

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces: `--plan PLAN`, validated before any write as present in the tree, or absent with its deletion staged, or absent with a committed removal in history (otherwise exit 2); the three states of spec Design §2 step 8; the `removed <plan>` verb line; `; plan <path> removed at finish` on `Recorded:`; the plan in `paths:` and the pathspec file while its deletion is staged.

**Mirror:** Task 2's `stage_owned` and `emit_paths`.

- [ ] **Step 1: Append the failing checks**

Insert before the marker line:

```bash
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
printf '# Plan v1\n' > "$repo/docs/hyperpowers/plans/2026-10-19-delta.md"
commit_all "$repo" "spec and plan"
git -C "$repo" rm -q docs/hyperpowers/plans/2026-10-19-delta.md && git -C "$repo" commit -q -m "remove plan"
printf '# Plan v2\n' > "$repo/docs/hyperpowers/plans/2026-10-19-delta.md"
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
printf '# Plan\n' > "$repo/docs/hyperpowers/plans/2026-10-19-beta.md"
commit_all "$repo" "spec and plan"
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-beta-design.md --plan docs/hyperpowers/plans/2026-10-19-beta.md
run_compile "$repo" docs/hyperpowers/specs/2026-10-19-beta-design.md --plan docs/hyperpowers/plans/2026-10-19-beta.md
if [ "$RC" -eq 0 ]; then pass "a re-run while the deletion is staged succeeds"; else fail "re-run with staged deletion (rc $RC: $ERR)"; fi
case "$OUT" in *"docs/hyperpowers/plans/2026-10-19-beta.md"*) pass "the staged deletion stays in paths:" ;; *) fail "plan missing from paths: (got: $(printf '%s\n' "$OUT" | grep '^paths:'))" ;; esac

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
    printf '# Plan\n' > "$repo/docs/hyperpowers/plans/2026-10-19-gamma.md"
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
```

- [ ] **Step 2: Run to see sections 21, 22 and 23 fail**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: `--plan` is a usage error, so 21 and 22 fail; 23 fails because a Setext underline is not yet recognised; sections 1 to 20 pass.

- [ ] **Step 3: Add the plan and the recovery**

(a) Header `# Usage:` and `usage()` first line read `decisions-compile SPEC [--plan PLAN] [--notes FILE] [--paths-file FILE] [--dry-run]`.

(b) Argument loop: `plan=""` beside `notes=""`; the arm:

```bash
    --plan) [ $# -ge 2 ] || usage; [ -z "$plan" ] || usage; plan=$2; shift 2 ;;
```

and the `reindex)` mode check also refuses `[ -n "$plan" ]`.

(c) After the `--paths-file` preflight, resolve and validate the plan; a plan is acceptable when it is in the tree, or absent with its deletion staged, or absent with a committed removal in history. Correction (2026-10-22): the task review and the Codex gate reshaped this block: the plan's directory may have been pruned by git after a committed removal, so the nearest existing ancestor is resolved and the missing components re-appended with no `.` or `..` among them; the plan must not be the spec or lie under the records directory; it must be a `.md` file under a `plans/` component with no CR, LF or `; plan ` in its path; when it exists it must be a regular non-symlink file; it must have exactly one index entry equal to its path, with no staged or working-tree changes (checked whether or not the file exists); and its `**Spec:**` header (from the tree, from HEAD when the deletion is staged, or from the adding commit after a committed removal; a backticked path, a link or trailing prose are unwrapped) must name this spec. Every refusal exits 2 before any write, so `git rm` can never be the first thing to fail:

```bash
plan_rel=""
plan_state=""
if [ -n "$plan" ]; then
  # A committed removal leaves no plan and often no plans directory (git
  # prunes it when it empties), so resolve the nearest existing ancestor and
  # re-append the missing components.
  plan_dir=$(dirname "$plan")
  plan_missing=""
  while [ ! -d "$plan_dir" ] && [ "$plan_dir" != / ] && [ "$plan_dir" != . ]; do
    plan_missing="/$(basename "$plan_dir")$plan_missing"
    plan_dir=$(dirname "$plan_dir")
  done
  plan_abs_dir="$(cd "$plan_dir" && pwd -P)$plan_missing"
  plan_abs="$plan_abs_dir/$(basename "$plan")"
  case "$plan_abs" in
    "$root"/*) plan_rel=${plan_abs#"$root"/} ;;
    *) die2 "$spec_rel: plan is outside the repository: $plan" ;;
  esac
  # The missing part of the path was never normalised, so a . or .. there
  # could point outside the repository while still matching "$root"/*.
  case "/$plan_rel/" in
    */./*|*/../*) die2 "$spec_rel: plan path must be canonical (no . or .. components): $plan" ;;
  esac
  # The plan is deleted and named in every record, so it must not be a path
  # the compiler owns, must have the shape finishing's discovery glob
  # (*/plans/*.md) finds, and must survive the Recorded line, which is split
  # on the last "; plan ".
  if [ "$plan_rel" = "$spec_rel" ] || [ "$plan_rel" = "$index_rel" ]; then
    die2 "$spec_rel: plan overlaps a compiler-owned path: $plan"
  fi
  case "$plan_rel" in
    "$records_rel"/*) die2 "$spec_rel: plan overlaps a compiler-owned path: $plan" ;;
  esac
  case "/$plan_rel" in
    */plans/*.md) ;;
    *) die2 "$spec_rel: plan must be a markdown file under a plans/ directory: $plan" ;;
  esac
  case "$plan_rel" in
    *"; plan "*|*$'\n'*|*$'\r'*) die2 "$spec_rel: plan path contains a newline or the reserved text \"; plan \": $plan" ;;
  esac
  # Exactly one index entry equal to the path: a plain ls-files test also
  # matches a tracked directory's descendants.
  plan_in_index() { [ "$(git -C "$root" ls-files -z -- "$plan_rel" | tr '\0' '\n')" = "$plan_rel" ]; }
  if [ -e "$plan_abs" ] || [ -L "$plan_abs" ] || plan_in_index; then
    # In the tree, or deleted in the tree but still in the index: git rm
    # stages the deletion in both cases. The plan must be a tracked regular
    # file with no uncommitted changes, because git rm refuses otherwise and
    # the retry would fail the same way after the records were written.
    if [ -e "$plan_abs" ] || [ -L "$plan_abs" ]; then
      { [ ! -L "$plan_abs" ] && [ -f "$plan_abs" ]; } || die2 "$spec_rel: plan is not a regular file: $plan"
      plan_in_index || die2 "$spec_rel: plan is not tracked by git; commit it before the records compile: $plan"
      git -C "$root" diff --quiet -- "$plan_rel" || die2 "$spec_rel: plan has uncommitted changes; commit or discard them before the records compile: $plan"
    fi
    git -C "$root" diff --cached --quiet -- "$plan_rel" || die2 "$spec_rel: plan has uncommitted changes; commit or discard them before the records compile: $plan"
    plan_state=present
  elif [ -n "$(git -C "$root" diff --cached --name-only --diff-filter=D -- "$plan_rel")" ]; then
    plan_state=staged-deletion
  elif ! git -C "$root" cat-file -e "HEAD:$plan_rel" 2>/dev/null && [ -n "$(git -C "$root" log --diff-filter=D --format=%h -1 -- "$plan_rel")" ]; then
    plan_state=removed
  else
    die2 "$spec_rel: no such plan (not in the tree or index, no staged deletion, never removed in history): $plan"
  fi
  # The state decides where the plan's text comes from. Not read through a
  # pipe that exits early, so git is never killed by SIGPIPE under pipefail.
  case "$plan_state" in
    present)
      if [ -e "$plan_abs" ]; then plan_text=$(cat "$plan_abs"); else plan_text=$(git -C "$root" show ":$plan_rel" 2>/dev/null || true); fi ;;
    staged-deletion) plan_text=$(git -C "$root" show "HEAD:$plan_rel" 2>/dev/null || true) ;;
    *)
      plan_added=$(git -C "$root" log --diff-filter=A --format=%H -1 -- "$plan_rel")
      plan_text=""
      if [ -n "$plan_added" ]; then plan_text=$(git -C "$root" show "$plan_added:$plan_rel" 2>/dev/null || true); fi ;;
  esac
  plan_header=$(printf '%s\n' "$plan_text" | awk '!d && index($0, "**Spec:** ") == 1 { print substr($0, 11); d = 1 }' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # Plans write the header as a bare path, a backticked path or a link, often
  # followed by prose; compare the path alone.
  case "$plan_header" in
    '`'*) plan_header=${plan_header#'`'}; plan_header=${plan_header%%'`'*} ;;
    '['*) plan_header=${plan_header#'['}; plan_header=${plan_header%%']'*} ;;
  esac
  plan_spec_base=$(basename "$spec_rel")
  case "$plan_header" in
    "$spec_rel"|"$spec_rel "*|*"$plan_spec_base"|*"$plan_spec_base "*) ;;
    *) die2 "$spec_rel: plan names a different spec: ${plan_header:-none}: $plan" ;;
  esac
fi
```

(d) In `render_record`, replace the block from `recorded=$rec_date` through the closing `fi` of the notes-part condition (four lines) with:

```bash
  recorded=$rec_date
  if [ "$notes_body" != "Nothing recorded." ]; then
    recorded="$recorded; notes from the branch diff by a subagent at finish"
  fi
  if [ -n "$plan_rel" ]; then
    recorded="$recorded; plan $plan_rel removed at finish"
  elif [ "${existing[n]}" = 1 ]; then
    rec_full=$(existing_field "$target" Recorded)
    case "$rec_full" in *"; plan "*) recorded="$recorded; plan ${rec_full##*; plan }" ;; esac
  fi
```

(e) In section 4c, after `stage_owned`, add the plan's states:

```bash
# The plan is removed last. Present: git rm. Absent with its deletion staged:
# nothing to do, and it stays in paths:. Removed by an earlier commit:
# nothing to do, and it is not in paths:.
if [ "$plan_state" = present ]; then
  git -C "$root" rm --quiet -- "$plan_rel" || die3 "$spec_rel: git rm failed for $plan_rel; run the same command again to complete the staging"
  verb_lines+=("removed $plan_rel")
fi
```

(f) In `emit_paths`, extend the pathspec to `-- "$records_rel" "$spec_rel" ${plan_rel:+"$plan_rel"}`. In the dry-run block, extend the first `git diff --cached` the same way and add `[ "$plan_state" = present ] && echo "$plan_rel"` inside the braces (after the `ls-files` line) so a present plan appears in the would-stage list.

(g) Correction (2026-10-22): Task 4's gate found at its cap that `load_notes`' pass recognises ATX headings only, while a line underlined with `---` or `===` is a Markdown heading the grammar forbids; the human partner carried the rule here. In the awk pass, as the first statements of the main action block (before `t = $0`), treat an underline directly after a non-blank line as a heading, and remember the previous line:

```awk
      # A Setext underline (only = or -, up to three leading spaces) directly
      # after a non-blank line makes that line a heading the grammar forbids.
      if (prev != "" && $0 ~ /^ ? ? ?(=+|-+)[ \t]*$/) { bad("unexpected heading: " prev); prev = ""; next }
      prev = ($0 ~ /^[[:space:]]*$/) ? "" : $0
```

and set `prev = ""` before the `next` that ends the structural-heading branch, so `---` directly after an ATX heading stays a thematic break. A blank line resets `prev`, so a thematic break after a blank line stays body text.

- [ ] **Step 4: Run the suite, shellcheck, packaging**

Run: `bash tests/claude-code/test-decisions-compile.sh && shellcheck -x skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh && bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh`
Expected: `STATUS: PASSED` three times, shellcheck silent. The `${plan_rel:+"$plan_rel"}` form is the standard optional-argument idiom; if shellcheck reports SC2086 on it, quote as shown, which it already is.

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh
git commit -m "feat(finishing): decisions-compile removes a validated plan in every state and recovers from a failed git step on re-run"
```

---

### Task 6: `--undo`, the later day, and the mode table

**Risk tier:** high — restores the tree on skip, including a superseded record's status.

**Files:**
- Modify: `skills/finishing-a-development-branch/scripts/decisions-compile` (Usage, the argument loop and mode checks, an `--undo` branch)
- Modify: `tests/claude-code/test-decisions-compile.sh` (append before the marker)

**Interfaces:**
- Consumes: everything above.
- Produces: `decisions-compile --undo SPEC [--plan PLAN]`, which restores every compiler-owned path with a staged difference from HEAD to its HEAD state, deletes those HEAD does not have, removes an emptied records directory, and leaves other staged changes alone; the complete usage the skills quote.

**Mirror:** Task 3's `--reindex` branch for a mode that exits before section 1.

- [ ] **Step 1: Append the failing checks**

Insert before the marker line:

```bash
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
printf '# Plan\n' > "$repo/docs/hyperpowers/plans/2026-08-01-new.md"
commit_all "$repo" "new spec and plan"
before=$(git -C "$repo" write-tree)
printf 'unrelated\n' > "$repo/other.txt"
git -C "$repo" add other.txt
run_compile "$repo" docs/hyperpowers/specs/2026-08-01-new-design.md --plan docs/hyperpowers/plans/2026-08-01-new.md
if grep -q '^- Status: superseded by' "$repo/docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md"; then pass "undo fixture: the target is superseded before undo"; else fail "undo fixture did not supersede"; fi
run_compile "$repo" --undo docs/hyperpowers/specs/2026-08-01-new-design.md --plan docs/hyperpowers/plans/2026-08-01-new.md
if [ "$RC" -eq 0 ] && [ "$(git -C "$repo" status --porcelain)" = "A  other.txt" ]; then pass "--undo restores spec, plan and the superseded record, removes the new record, keeps the unrelated staged file"; else fail "--undo (rc $RC, err: $ERR, status: $(git -C "$repo" status --porcelain | tr '\n' ';'))"; fi
if grep -q '^- Status: accepted$' "$repo/docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md"; then pass "--undo restores the target's accepted status"; else fail "target status after undo: $(grep '^- Status' "$repo/docs/hyperpowers/decisions/2026-07-01-hook-based-interlock.md")"; fi
git -C "$repo" reset -q other.txt && rm "$repo/other.txt"
if [ "$(git -C "$repo" write-tree)" = "$before" ]; then pass "--undo returns the index to its pre-run tree"; else fail "index differs from the pre-run tree"; fi
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
```

(The `SC2086` disable is deliberate: `$args` is a test-controlled list of space-free tokens that must split.)

- [ ] **Step 2: Run to see sections 24, 26 and 27 fail**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: `--undo` is a usage error, so 24 fails; 25 passes already or fails only on the earlier fixture; 26 fails on the `--undo` rows; 27 fails on the twin refusal (the suffix match accepts it).

- [ ] **Step 3: Add undo and the mode table**

(a) Header `# Usage:` and `usage()` become:

```bash
# Usage: decisions-compile SPEC [--plan PLAN] [--notes FILE] [--paths-file FILE] [--dry-run]
#        decisions-compile --undo SPEC [--plan PLAN]
#        decisions-compile --reindex RECORDS_DIR
```

```bash
usage() {
  echo "usage: decisions-compile SPEC [--plan PLAN] [--notes FILE] [--paths-file FILE] [--dry-run]" >&2
  echo "       decisions-compile --undo SPEC [--plan PLAN]" >&2
  echo "       decisions-compile --reindex RECORDS_DIR" >&2
  exit 2
}
```

(b) Argument loop: the arm `--undo) [ "$mode" = compile ] || usage; mode=undo; shift ;;`. The mode checks become the full table:

```bash
case "$mode" in
  reindex) if [ -n "$spec" ] || [ -n "$plan" ] || [ -n "$notes" ] || [ -n "$paths_file" ] || $dry_run; then usage; fi ;;
  undo) if [ -z "$spec" ] || [ -n "$notes" ] || [ -n "$paths_file" ] || $dry_run; then usage; fi ;;
  compile) [ -n "$spec" ] || usage ;;
esac
```

(c) After the `# --- reindex ---` block, add the undo block. Correction (2026-10-22): the task review and the Codex gate reshaped it: the working-tree file is deleted before its index entry, with a checked exit 3, so a failed deletion is retried; the three `git diff --cached --name-only` listings (here, in `emit_paths` and in the dry run) take `--no-renames`, so a plan deletion is never folded into a similar record addition; and because undo deletes every path HEAD lacks, the paths block now requires the spec to exist in HEAD before any write (an untracked or staged-only spec would otherwise be left falsely marked implemented or lost):

```bash
  # The Outcome line is written into the spec, and undo deletes whatever HEAD
  # lacks; a spec that is untracked or only staged would be lost. Checked
  # against HEAD, not the index, and safe on an unborn HEAD.
  git -C "$root" cat-file -e "HEAD:$spec_rel" 2>/dev/null || die2 "$spec_rel: spec is not committed; commit it before the records compile"
```

```bash
# --- undo -------------------------------------------------------------------
# The skip before the commit: every compiler-owned path with a staged
# difference from HEAD goes back to HEAD, and a path HEAD does not have is
# deleted. Anything else staged is left alone.
if [ "$mode" = undo ]; then
  git -C "$root" diff --cached --name-only --no-renames -z -- "$records_rel" "$spec_rel" ${plan_rel:+"$plan_rel"} > "$tmp/undo.z" || die3 "$spec_rel: git diff --cached failed"
  undo_blob() { git -C "$root" show "$1" > "$2" 2>/dev/null; }
  is_my_record() {  # a record copy -> 0 when its identity names this spec
    case "$(existing_field "$1" Spec)" in "$spec_rel (decision "*) return 0 ;; esac
    return 1
  }
  drop_status() {  # a record copy -> the same text without its first Status line
    awk '!r && index($0, "- Status: ") == 1 { r = 1; next } { print }' "$1" > "$2"
  }
  names_my_record() {  # a Status value -> 0 when it lists a record of this spec
    local st=$1 q
    case "$st" in "superseded by "*) ;; *) return 1 ;; esac
    printf '%s\n' "${st#superseded by }" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | awk 'length' > "$tmp/undo-named"
    while IFS= read -r q; do
      if undo_blob ":$q" "$tmp/undo-q" || undo_blob "HEAD:$q" "$tmp/undo-q"; then
        if is_my_record "$tmp/undo-q"; then return 0; fi
      fi
    done < "$tmp/undo-named"
    return 1
  }
  # The records directory is shared, so a staged path under it is not
  # necessarily this compile's work. A second spec compiled before the commit
  # would be restored or deleted here while its own staged Outcome line stayed
  # behind, pointing at records that are gone. Every staged record must be
  # attributable to this spec first: either it carries this spec's identity,
  # or it is a target this compile superseded, whose staged change is the
  # Status line alone and whose Status names a record of this spec.
  while IFS= read -r -d '' p; do
    case "$p" in "$records_rel"/*) ;; *) continue ;; esac
    if [ "$p" = "$index_rel" ]; then continue; fi
    have_idx=false; have_head=false
    if undo_blob ":$p" "$tmp/undo-idx"; then have_idx=true; fi
    if undo_blob "HEAD:$p" "$tmp/undo-head"; then have_head=true; fi
    # A staged deletion has no index copy; its identity comes from HEAD.
    ident=""
    if $have_idx; then ident="$tmp/undo-idx"; elif $have_head; then ident="$tmp/undo-head"; fi
    owned=false
    if [ -n "$ident" ] && is_my_record "$ident"; then
      owned=true
    elif $have_idx && $have_head; then
      drop_status "$tmp/undo-idx" "$tmp/undo-idx.body"
      drop_status "$tmp/undo-head" "$tmp/undo-head.body"
      if cmp -s "$tmp/undo-idx.body" "$tmp/undo-head.body"; then
        if names_my_record "$(existing_field "$tmp/undo-idx" Status)" || names_my_record "$(existing_field "$tmp/undo-head" Status)"; then owned=true; fi
      fi
    fi
    $owned || die2 "$spec_rel: --undo refused: $p is staged but belongs to another compile; commit or undo it first"
  done < "$tmp/undo.z"
  # An edit made after the compile is not this compile's text, and the restore
  # below would discard it without a trace.
  while IFS= read -r -d '' p; do
    if [ ! -e "$root/$p" ]; then continue; fi
    # A path whose deletion is staged and that exists again is untracked
    # relative to the index, so git diff says nothing about it while the
    # restore below would overwrite it with HEAD's copy.
    if [ -z "$(git -C "$root" ls-files -z -- "$p" | tr '\0' '\n')" ]; then
      die2 "$spec_rel: --undo refused: $p was recreated after the compile; move it aside or stage it first"
    fi
    git -C "$root" diff --quiet -- "$p" || die2 "$spec_rel: --undo refused: $p was edited after the compile; commit or stash the edit first"
  done < "$tmp/undo.z"
  while IFS= read -r -d '' p; do
    if git -C "$root" cat-file -e "HEAD:$p" 2>/dev/null; then
      git -C "$root" restore --staged --worktree -- "$p" || die3 "$spec_rel: git restore failed for $p"
    else
      # The file goes first, so a failed deletion leaves the staged entry for
      # the retry to find.
      rm -f "$root/$p" 2>/dev/null || die3 "$spec_rel: cannot delete $p; run the same command again to complete the undo"
      git -C "$root" rm --cached --quiet -- "$p" || die3 "$spec_rel: git rm --cached failed for $p"
    fi
    echo "restored $p"
  done < "$tmp/undo.z"
  rmdir "$records_dir" 2>/dev/null || true
  exit 0
fi
```

The suite's section 24 also carries, from those rounds, an untracked and a staged-only spec refused with nothing written, undo on a tracked spec restoring it byte for byte, undo with nothing staged printing nothing, a failed deletion exiting 3 and succeeding on retry, and a plan whose content matches its record so that rename detection would have folded the deletion; section 5's third-collision fixture commits its spec.

Undo needs the plan resolved but not validated against the three states (a plan whose deletion is staged is exactly the undo case, and one that exists is fine too); the Task 5 validation already accepts both, and a plan that exists nowhere exits 2, which is right for undo as well.

(d) Correction (2026-10-22): Task 5's gate found at its cap that the Spec-header binding's basename arms (`*"$plan_spec_base"|*"$plan_spec_base "*`) were suffix matches, so a plan written for a same-named spec in another directory passed and would have been staged for deletion; the human partner carried the exact-match rule here. In the binding `case` of the plan preflight, replace those two arms with `"$plan_spec_base"|"$plan_spec_base "*`, so only the exact repository-relative path or the exact bare basename, each optionally followed by a space and prose, binds; update the comment above the `case` if it describes the rule.

- [ ] **Step 4: Run the suite, shellcheck, packaging, and the sibling suites**

Run: `bash tests/claude-code/test-decisions-compile.sh && shellcheck -x skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh && bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh && bash tests/claude-code/test-docs-allowlist.sh && bash tests/claude-code/test-sdd-dir-path.sh`
Expected: `STATUS: PASSED` five times, shellcheck silent.

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/scripts/decisions-compile tests/claude-code/test-decisions-compile.sh
git commit -m "feat(finishing): decisions-compile undoes a staged run, keeps its dates across days, and refuses incompatible options"
```

---

### Task 7: The allowlist admits `decisions/`

**Risk tier:** high — the script writes the `.gitignore` git trusts in every repository that adopts it; the rubric's "any script whose output other machinery trusts".

**Files:**
- Modify: `skills/writing-plans/scripts/docs-allowlist:38-44` (the printf that writes the allowlist)
- Modify: `tests/claude-code/test-docs-allowlist.sh:50-70` (the ignore checks and the `git add -A` check)
- Modify: `docs/hyperpowers/.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: a fresh `docs/hyperpowers/.gitignore` with `!/decisions/`; this repository's own allowlist admits `decisions/`.

**Mirror:** the existing `!/plans/` line and its checks in the same two files.

- [ ] **Step 1: Extend the test (it fails: `decisions/x.md` is ignored)**

In `tests/claude-code/test-docs-allowlist.sh`, change the first `for p in` list to:

```bash
for p in docs/hyperpowers/specs/a.md docs/hyperpowers/plans/b.md \
         docs/hyperpowers/plans/nested/c.md docs/hyperpowers/decisions/d.md \
         docs/hyperpowers/decisions/README.md docs/hyperpowers/.gitignore; do
```

In the end-to-end block, add `"$repo/docs/hyperpowers/decisions"` to the `mkdir -p` line, add `echo d > "$repo/docs/hyperpowers/decisions/d.md"` after the `plans/b.md` line, and change `expected=` to:

```bash
expected="docs/hyperpowers/.gitignore docs/hyperpowers/decisions/d.md docs/hyperpowers/plans/b.md docs/hyperpowers/specs/a.md "
```

and the pass message to `"git add -A stages only the ignore file, specs/, plans/ and decisions/"`.

**Correction (2026-10-22).** The same file's temporary root, `TEST_ROOT="$(cd "$(mktemp -d)" && pwd -P)"`, falls back to the checkout when `mktemp` fails (`cd ""` succeeds in place), and its EXIT trap would then delete the checkout; Task 1's Codex gate found the pattern in the compiler suite. Replace that line and the `cleanup` definition with the fail-fast form Task 1's fix uses:

```bash
TEST_ROOT=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || { echo "no temporary directory" >&2; exit 1; }
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 1
case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) echo "refusing temporary root $TEST_ROOT" >&2; exit 1 ;; esac
cleanup() { case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) return ;; esac; rm -rf "$TEST_ROOT"; }
trap cleanup EXIT
```

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/claude-code/test-docs-allowlist.sh`
Expected: `STATUS: FAILED` on the two `decisions/` checks and the staged set.

- [ ] **Step 3: Admit the directory**

In `skills/writing-plans/scripts/docs-allowlist`, change the printf to:

```bash
  printf '%s\n' \
    '# Only specs/, plans/ and decisions/ are committed from this directory. Anything' \
    '# else the workflow produces (run captures, probes, review output, ledgers)' \
    '# belongs in the SDD workspace or an evidence repository, not here.' \
    '/*' \
    '!/.gitignore' \
    '!/specs/' \
    '!/plans/' \
    '!/decisions/' > "$target"
```

and update the header comment line `# specs/, plans/ and the ignore file itself)` to read `# specs/, plans/, decisions/ and the ignore file itself)`.

In `docs/hyperpowers/.gitignore`, change the first comment line to `# Only specs/, plans/ and decisions/ are committed from this directory, plus the dated` and add `!/decisions/` after `!/plans/`.

- [ ] **Step 4: Run the test, shellcheck, the repository check, packaging**

Run: `bash tests/claude-code/test-docs-allowlist.sh && shellcheck -x skills/writing-plans/scripts/docs-allowlist && bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh`, then `git check-ignore -q --no-index docs/hyperpowers/decisions/x.md; echo "ignored rc=$? (expect 1)"`.
Expected: `STATUS: PASSED` three times, shellcheck silent, `ignored rc=1`.

- [ ] **Step 5: Commit**

```bash
git add skills/writing-plans/scripts/docs-allowlist tests/claude-code/test-docs-allowlist.sh docs/hyperpowers/.gitignore
git commit -m "feat(writing-plans): the planning-directory allowlist admits decisions/"
```

---

### Task 8: finishing-a-development-branch records, stages, shows and commits; the extractor prompt

**Risk tier:** standard — behavior-shaping skill surgery in one skill plus a new prompt file; the rubric lists "behavior-shaping skill/doc surgery" under standard, and the background lifecycle it describes is the harness's, not code this task writes.

**Files:**
- Create: `skills/finishing-a-development-branch/decision-notes-prompt.md`
- Modify: `skills/finishing-a-development-branch/SKILL.md:16-28` (Step 1), `:55-57` (before the Step 4 menu), `:226` (the table's last row)

**Interfaces:**
- Consumes: `decisions-compile` (Tasks 1 to 6) by its documented usage; `../requesting-code-review/scripts/codex-review-dir`.
- Produces: the prompt template Task 9 references by filename; the finishing flow SDD's hand-off targets: Step 1 accepts "the plan, the spec, the extractor's task id and output path".

**Mirror:** `skills/subagent-driven-development/re-review-prompt.md:1-60` for the prompt file; the existing Step 1 and Step 4 text for voice and the fenced message blocks.

- [ ] **Step 1: Write the prompt file**

Create `skills/finishing-a-development-branch/decision-notes-prompt.md`:

````markdown
# Decision Notes Prompt Template

Use this template to dispatch the decision extractor: a background subagent
that reads what shipped and writes, for each decision in the spec's
`## Decisions` list, what implementation changed. Its output is prose and
proposals that `scripts/decisions-compile --notes` consumes; the spec stays
the only authority for the decisions themselves, and the compiler never
applies a proposal.

**Purpose:** Capture, while the branch is still open, the gap between each
decision as the spec stated it and what the implementation did, so the
record a future design session reads is true about what shipped.

Dispatch it in the background and never wait for it: the finishing skill
collects it after the full suite, stops it if it has not finished, and
compiles without it. Set `run_in_background: true` where the Agent tool
offers the parameter; in a Claude Code interactive session's fork mode every
dispatch is already asynchronous and the parameter is absent. On a harness
with no tracked background subagent, do not dispatch at all: compile without
notes and say so.

```
Subagent (general-purpose):
  description: "Decision notes for [SPEC_BASENAME]"
  model: [MODEL — the mid-tier floor SDD's Model Selection sets for reviewers;
         an omitted model silently inherits the session's most expensive one]
  run_in_background: true
  prompt: |
    You write implementation notes for a list of design decisions. You do
    not judge the decisions, restate them, or add rationale the spec does
    not contain. You write one file and nothing else.

    ## The decisions

    Read the spec: [SPEC_PATH]
    Its `## Decisions` section is a list; the compiler numbers its items in
    order, and this is the numbering you use:

    [DRY_RUN_LISTING — the `would write ... (decision N: <title>)` lines
    from `decisions-compile --dry-run`, verbatim]

    ## What shipped

    [PLAN_LINE — when the branch has a plan: "Read the plan: <path>. Its
    dated `Correction` paragraphs, and any paragraph that names a decision
    (`decision <N>`), are the record of changes made during execution.";
    otherwise: "This branch has no plan; the diff is the only record."]

    Read the diff: [DIFF_SOURCE — under SDD: "the review package copy at
    <path>"; otherwise: "run `git diff <MERGE_BASE>...HEAD --stat` and
    `git diff <MERGE_BASE>...HEAD`"]

    [LEDGER_LINE — under SDD: "Read the ledger copy at <path> for its
    deferred-minor lines."; otherwise omit this line]

    [INDEX_LINE — when the index exists: "The index of existing records is
    <path>; a supersession you propose must name a record listed there.";
    otherwise omit this line]

    ## What to write

    Write exactly this file and nothing else: [OUTPUT_PATH]

        # Decision notes: [SPEC_PATH]

        ## Decision 1
        <two to six sentences: what the implementation changed relative to
        this decision, naming modules, functions, tests and invariants,
        never line numbers; or the single line: No change.>

        ## Decision 2
        <one section per decision, every decision, in order>

        ## Supersessions
        - <N> supersedes <record path>
        <only when the work knowingly reversed a record the index lists;
        omit the whole section otherwise>

        ## Undocumented decisions
        - <one line: a choice made during implementation that no decision
          item covers>
        <omit the whole section when there is none>

    Rules the compiler enforces: the first line names this spec; every
    level-two heading is `## Decision <N>`, `## Supersessions` or
    `## Undocumented decisions`; no decision number appears twice; no
    section is empty; the two optional sections hold list items only. A
    file that breaks a rule is ignored whole, so follow the shape exactly.

    ## Read-only

    Apart from the output file, do not write, stage or commit anything, and
    do not change the working tree, the index, HEAD or any branch. Read with
    `git show`, `git diff` and `git log`.

    ## You Do Not Dispatch Subagents

    Do all of this yourself. Never spawn a subagent for any part of it.
```
````

- [ ] **Step 2: Replace Step 1**

Replace the section from `## Step 1: Verify Tests` through `**If tests pass:** continue to Step 2.` with the text below. Correction (2026-10-22): the task review and the Codex gate reshaped it: the step runs from the repository root, confirms the base branch before computing the merge base it uses everywhere, requires a committed and clean spec (the approved legacy list is committed before the compile), scopes the already-recorded check to this spec's commit subject, and names every exit-2 cause:

````markdown
## Step 1: Record Decisions and Verify Tests

A branch that implements a spec leaves one record per decision in the
`decisions/` directory beside the spec's directory, compiled by
`scripts/decisions-compile` in this skill's directory from the spec's
`## Decisions` list, with the plan removed in the same commit. The records
ride the branch before any merge or push, so they are staged here and
committed in Step 4 once your human partner has seen them. Work with no spec
has no records: for it, this step is the test run alone.

1. **Find the plan and the spec.** Start from the repository root:

   ```bash
   cd "$(git rev-parse --show-toplevel)"
   ```

   Run this step and Step 4 from the repository root; every path below is
   repository-relative, as the compiler and the pathspec file expect. Then
   fix the fork point, in every case, because the steps below diff and
   search from it (the base branch is whatever this work forked from,
   usually named in the plan, the conversation, or the branch's upstream;
   when it is not already known, ask now, before anything below runs: "This
   branch split from <your best guess> - is that correct?"):

   ```bash
   MERGE_BASE=$(git merge-base <base-branch> HEAD)
   ```

   The subagent-driven-development hand-off names both. Otherwise read the
   branch's history, not its tree, so a plan an earlier records commit
   removed is still found:

   ```bash
   git log --diff-filter=A --name-only --format= "$MERGE_BASE"..HEAD -- '*/plans/*.md'
   ```

   Exactly one plan is the plan; read its `**Spec:**` header from the commit
   that added it (`git show <sha>:<path>`). More than one: ask your human
   partner which applies. A plan without a Spec header, or with `none`: ask
   the same way. No plan: when the branch's history added or changed a spec
   (`git log --diff-filter=AM --name-only --format= "$MERGE_BASE"..HEAD -- '*/specs/*.md'`),
   ask whether records are wanted for it, and if so there is a spec and no
   plan; when it did neither, the work is bounded: there is no spec, skip
   the extractor and go to the test run in item 3.
2. **Take a scratch directory and dry-run the compiler.** The directory
   comes from `../requesting-code-review/scripts/codex-review-dir` (one per
   finish; the extractor's output and the pathspec file `records.paths` live
   in it, whether or not an extractor is dispatched). Then
   `bash <this skill's directory>/scripts/decisions-compile <spec> --dry-run`.
   Exit 2 for a missing decisions list is the legacy-spec case: draft the
   `## Decisions` list from the spec's own text, one item per decision it
   states, show it to your human partner, and write it into the spec once
   they approve it, and commit that edit on the branch before going on (a
   docs commit of the spec alone; the compiler requires a committed spec,
   and a skip restores the spec from HEAD). Any other exit 2 names what to fix first (a spec that is
   not committed, a plan that is not a tracked and clean markdown file under
   `plans/` whose Spec header names this spec, or a `Supersedes:` problem):
   resolve it with them before going on. Keep the numbered listing for the
   extractor.
3. **Dispatch the extractor, then run the suite.** Skip the dispatch when the
   branch has no spec, when the hand-off already names an extractor (a task
   id and an output path), when the branch already carries this spec's
   records commit (`git log "$MERGE_BASE"..HEAD --fixed-strings --grep="docs: record decisions for <spec filename without -design.md>"`,
   the subject Step 4's commit uses for this spec), or
   when your harness has no tracked background subagent (then say so when
   you hand back). Otherwise compose the dispatch from
   [decision-notes-prompt.md](decision-notes-prompt.md) with the merge-base
   diff and `<dir>/decision-notes.md` as its output path, and start it in
   the background. Then run the project's full test suite in the
   foreground (`npm test` / `cargo test` / `pytest` / `go test ./...`).
4. **If tests fail**, stop a still-running extractor (TaskStop), report the
   failures and stop — the menu comes after a green suite. Nothing is
   compiled; the plan stays.

   ```
   Tests failing (<N> failures). Must fix before completing:

   [Show failures]
   ```

5. **If tests pass** and the branch has a spec, collect the extractor without
   waiting: finished, its file is the `--notes`; unfinished, stop it
   (TaskStop), compile without notes, and say so when you hand back. The spec
   must be clean before the compile (no uncommitted edits; commit or stash
   them), because a skip restores it from HEAD. Run
   `bash <this skill's directory>/scripts/decisions-compile <spec> --plan <plan> --notes <file> --paths-file <dir>/records.paths`,
   omitting `--plan` when the branch has no plan and `--notes` when there is
   no notes file. A `notes ignored:` line on its stderr is repeated verbatim
   when you hand back. On exit 2, resolve the named problem and re-run; on
   exit 3, report the git failure and re-run once it is cleared. Nothing is
   committed here; the staged set waits for Step 4. Continue to Step 2.
````

- [ ] **Step 3: Add the Step 4 preface**

Correction (2026-10-22, after Task 13's Codex gate): Step 4 gained three sentences the rehearsal forced (b2a2bd0): an answer that names an option but leaves a proposal without a disposition is incomplete and the session asks before writing or committing (a bare "3" had committed with three proposals open); the menu message carries the diff command's output itself, verbatim (one session summarised the paths); the records commit message is the one given line with no trailer or attribution line (the host-isolated run's commit carried Claude Code's built-in trailer).

Insert directly after the line `## Step 4: Present Options` and its blank line, before `**Normal repo and named-branch worktree — present exactly these 3 options:**`. Correction (2026-10-22): the preface runs from the repository root, commits an accepted proposal's spec edit before the re-run and before a skip's `--undo`, prefixes the undo command with the script path, and runs the chosen option only after the records commit succeeds:

````markdown
**When Step 1 staged records,** the message that presents the options, from
the repository root as in Step 1, opens
with the complete staged diff over the pathspec file's paths (`git diff` has
no pathspec-file option, so the NUL-delimited file is read into an array; a
path with a space survives, and the variable makes the entries literal, as
the compiler's own git calls are, so a bracket or star in a spec name
matches only itself):

```bash
paths=(); while IFS= read -r -d '' p; do paths+=("$p"); done < <dir>/records.paths
GIT_LITERAL_PATHSPECS=1 git diff --cached -- "${paths[@]}"
```

then the extractor's proposals from its notes file, each with the question
it needs: an undocumented decision (add it to the spec's `## Decisions`
list, or dismiss it); a proposed supersession (add a
`Supersedes: <record path>` line to the item that reverses that record, or
dismiss it); then one line offering to skip the records for this branch; and
only then the menu text exactly as written below. Your human partner answers
once. Before executing their option: write each accepted proposal into the
spec (an accepted undocumented decision is appended after the list's last
item, never inserted, so the numbers the notes use stay with their records;
an accepted supersession is a `Supersedes:` line on the item it belongs to),
commit that spec edit first (`git commit -m "docs: <spec filename without -design.md> accepts a decision from the finish" -- <spec>`, a pathspec commit, so the staged records stay staged), then re-run
the compiler with the same arguments, and because the staged set
changed, show the new complete staged diff and ask only for its approval,
not the dispositions again; record a dismissal in the hand-back in their
words. A skip ends the records for this branch: with the spec committed as
above, run `bash <this skill's directory>/scripts/decisions-compile --undo <spec> --plan <plan>` (without `--plan` when there
is none), record it in their words, make no commit, and run the option they
chose. Otherwise commit:

```bash
GIT_LITERAL_PATHSPECS=1 git commit --pathspec-from-file=<dir>/records.paths --pathspec-file-nul -m "docs: record decisions for <spec filename without -design.md>"
```

The option runs only after that commit succeeds. If it fails (a hook, an
index conflict, anything), show the failure, stop, and run the same commit
again once the cause is cleared; nothing is merged or pushed while the
records and the plan's deletion are merely staged.

Then run the option they chose. A branch with no records shows the menu as it
always did.
````

- [ ] **Step 4: Add the table row**

Append after the table's last row (`| "The base branch is obviously main" | ... |`):

```markdown
| "I'll record the decisions after the merge" | The records ride the branch. After the merge the plan is gone from the tree and the diff review is over. Record first, then present the menu. |
```

- [ ] **Step 4b: Step 3 reuses the confirmed base (correction, 2026-10-22)**

Because Step 1 now confirms the base branch before it computes the merge base, `## Step 3: Determine Base Branch` reads:

````markdown
## Step 3: Determine Base Branch

The base branch is the one Step 1 confirmed; when Step 1 had no spec and did
not ask, confirm it here the same way (ask "This branch split from <your
best guess> - is that correct?"). Confirm before merging: merging into the wrong base is expensive to undo.
````

- [ ] **Step 5: Check**

Run: `grep -c "decisions-compile" skills/finishing-a-development-branch/SKILL.md` (at least 3), `grep -c "decision-notes-prompt.md" skills/finishing-a-development-branch/SKILL.md` (at least 1), then `bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh`.
Expected: both suites `STATUS: PASSED`.

- [ ] **Step 6: Commit**

```bash
git add skills/finishing-a-development-branch/decision-notes-prompt.md skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(finishing): Step 1 records decisions after the suite, Step 4 shows the staged records before the menu, and the extractor prompt"
```

---

### Task 9: subagent-driven-development dispatches the extractor and hands off

**Risk tier:** standard — behavior-shaping skill surgery in the SDD skill and its example; the rubric's standard.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:112` (graph edge), `:174` (end of Setup's spec paragraph), `:608` (after the re-review paragraph in Final Review), `:642` (after `Use hyperpowers:finishing-a-development-branch.` in Finish)
- Modify: `skills/subagent-driven-development/example-workflow.md:72-77`

**Interfaces:**
- Consumes: Task 8's Step 1 contract (the hand-off names the plan, the spec, the extractor's task id and output path) and its prompt file; `decisions-compile --dry-run`.
- Produces: the ledger lines `Decisions listing:` and `Decision extractor: <task id> -> <path>` that the hand-off reads.

**Mirror:** the Final Review paragraphs in the same file for voice; `example-workflow.md:70-77` for the bracketed narration style.

- [ ] **Step 1: The graph**

In the `digraph process` block, add after the line `"Final findings? ONE fix dispatch, one scoped re-review, surface residuals" [shape=box];`:

```dot
    "Dispatch decision extractor (background)" [shape=box];
```

and replace the edge

```dot
    "Final findings? ONE fix dispatch, one scoped re-review, surface residuals" -> "Codex final code gate\n(Claude Code; degrade if absent)";
```

with

```dot
    "Final findings? ONE fix dispatch, one scoped re-review, surface residuals" -> "Dispatch decision extractor (background)";
    "Dispatch decision extractor (background)" -> "Codex final code gate\n(Claude Code; degrade if absent)";
```

- [ ] **Step 2: Setup**

After the Setup paragraph that ends `without a spec, a conflict has no tiebreaker but your human partner.`, add the text below. Correction (2026-10-22): the Codex gate reshaped it: the dry run, the listing, the extractor and the spec hand-off are guarded on a resolved spec (a plan without one gets a ledger line and the test-only finishing path), the dry run is re-run after any repair until it exits 0, and every exit-2 cause is named:

```markdown
When the plan has a spec, dry-run the decision compiler over it now:
`bash <finishing skill's directory>/scripts/decisions-compile <spec> --dry-run`
(the finishing-a-development-branch skill, `../finishing-a-development-branch/`
relative to this one). Exit 0 confirms the spec's `## Decisions` list parses;
its numbered listing goes into the ledger under a `Decisions listing:` line
for the extractor's dispatch. Exit 2 for a missing list is the legacy-spec
case: draft the list from the spec's own text, one item per decision it
states, show it to your human partner, and write it into the spec once they
approve it, committing that edit on the branch. Any other exit 2 names what
to fix first (a spec that is not committed, or a `Supersedes:` problem) to
resolve with them the same way. After any repair, run the dry run again
until it exits 0, and only then write its numbered listing into the ledger.
The session is at its start, so this costs no cycle time. When the plan has
no spec (`none`, or unreachable, per the ledger line above), write
`Decisions: none (no spec)` in the ledger and skip the listing, the
extractor and the spec in the hand-off: finishing then takes its test-only
path.
```

- [ ] **Step 3: Final Review**

After the paragraph that ends `with the evidence, as BLOCKED, when finishing-a-development-branch presents the options.` and before `**Codex Review Gate — final whole-branch (Claude Code only).**`, add the text below. Correction (2026-10-22): the extractor reads a regenerated full-branch package, not a fix wave's scoped one; a Codex final-gate fix after the dispatch stops the extractor, settles any altered decision first, refreshes the listing and the package, and re-dispatches:

```markdown
**Dispatch the decision extractor.** When the ledger has a `Decisions listing:`
line (and otherwise nothing), once the fix wave and its re-review are
clean (or the final review returned no findings), take a scratch directory
from `../requesting-code-review/scripts/codex-review-dir`, regenerate the
full-branch package (`scripts/review-package PLAN_FILE MERGE_BASE HEAD`, so a
fix wave's commits are in it) and copy it and `<workspace>/progress.md` into
it, and dispatch the
extractor in the background, composed from
`../finishing-a-development-branch/decision-notes-prompt.md` with those two
copies, the plan, the spec, the `Decisions listing:` from the ledger, the
index (`decisions/README.md` beside the spec's directory) when it exists, and
`<dir>/decision-notes.md` as its output path. Record it in the ledger:
`Decision extractor: <task id> -> <dir>/decision-notes.md`. It reads nothing
inside the workspace, so Finish may delete the workspace while it runs;
finishing-a-development-branch collects it after the full suite and never
waits for it, and neither do you. On a harness with no tracked background
subagent, skip the dispatch and note it in the ledger. If a Codex final-gate
fix changes code after the dispatch: stop the extractor (TaskStop); when the
fix altered one of the spec's decisions, settle that first (show your human
partner the change you would write into the `## Decisions` item, write and
commit it on the branch with their approval; without it the item stands and
the change is raised again at the menu); re-run the dry run and replace the
ledger's `Decisions listing:`; regenerate the full-branch package and copy
it, with the current `<workspace>/progress.md`, into the scratch directory,
replacing the earlier copies; compose the replacement dispatch from those
copies; then dispatch the extractor again and replace the
`Decision extractor:` line.
```

- [ ] **Step 4: Finish**

After the line `Use hyperpowers:finishing-a-development-branch.`, add the text below. Correction (2026-10-22): the hand-off is conditional (task id and path when an extractor was dispatched, the ledger's reason when the dispatch was skipped, the test-only path when the plan has no spec), the ledger lines are copied into the hand-off before the workspace is deleted, and a Codex-altered decision is settled in Final Review before the re-dispatch:

```markdown
Hand it the plan and the spec, and the extractor's task id and output path
when one was dispatched; when the dispatch was skipped, hand over the
ledger's reason instead and say so, and finishing compiles without notes;
when the plan has no spec, say that, and finishing runs its test-only path.
A decision a Codex-gate fix altered was settled in Final Review before the
re-dispatch.
```

- [ ] **Step 5: The example**

In `example-workflow.md`, after the line `Final reviewer: All requirements met. Deferred minors triaged: none block merge.`, insert:

```
[Dispatch the decision extractor in the background: review package and ledger copied to a codex-review-dir scratch dir]
[Ledger: Decision extractor: task-9f2a -> <dir>/decision-notes.md]
```

and replace the last line `Done! Using hyperpowers:finishing-a-development-branch.` with:

```
Done! Using hyperpowers:finishing-a-development-branch — plan, spec, and extractor task-9f2a with its notes path handed over.
```

- [ ] **Step 6: Check**

Run: `bash tests/sdd/test-sdd-contract.sh && bash tests/packaging/test-no-orphan-skill-files.sh && bash tests/packaging/test-skill-frontmatter.sh`
Expected: all `STATUS: PASSED`. If `test-sdd-contract.sh` names the replaced edge by its text, update that expectation to the two new edges and say so in the commit message; adjust nothing else in the test.

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/example-workflow.md
git commit -m "feat(sdd): dry-run the decision compiler at setup, dispatch the extractor after the final fix wave, hand it to finishing"
```

---

### Task 10: brainstorming reads the index and writes the list; writing-plans names decisions in corrections

**Risk tier:** standard — two short additions to tuned skills, no tuned table touched.

**Files:**
- Modify: `skills/brainstorming/SKILL.md:211` (after the first "Understanding the idea" bullet), `:297-298` (after the Documentation block's first bullet and its sub-bullet)
- Modify: `skills/writing-plans/SKILL.md:175` (after the Mirror paragraph)

**Interfaces:**
- Consumes: the record format and index of Task 2; the `Supersedes:` semantics of Task 3.
- Produces: specs whose `## Decisions` list the compiler parses without the legacy path.

**Mirror:** the neighbouring bullets in each file.

Correction (2026-10-22): the Codex gate reshaped the three texts (the records the index links are opened, a reversal is never bounded work, the `## Decisions` heading is the first level-two heading containing "decision", the correction phrase names number and title and the list is append-only once execution starts); the texts below are the skills' as built.

- [ ] **Step 1: brainstorming, understanding the idea**

After the bullet `- Check out the current project state first (files, docs, recent commits)`, add:

```markdown
- Read the decisions index when it exists: `decisions/README.md` beside the specs directory this session writes to (`docs/hyperpowers/decisions/README.md` by default). Open the current records it links for the area in hand, not only the index: each is a constraint on the design. A design that reverses one is architectural work and gets a spec, never the bounded path (bounded work has no spec and cannot supersede), and it says so in its spec item with a `Supersedes:` line naming the record.
```

- [ ] **Step 2: brainstorming, documentation**

After the sub-bullet `  - (User preferences for spec location override this default)` under "Write the validated design (spec) to ...", add:

```markdown
- The spec carries a `## Decisions` section, required: its heading is the first level-two heading in the spec whose text contains the word decision (the compiler takes the first such heading), and it holds one top-level list item per decision, each opening with a bold title and stating what was chosen, what was rejected and why, with an optional `Supersedes: <repository-relative record path>` (`docs/hyperpowers/decisions/<file>.md` by default: the record filename the index links, with its directory) line inside the item. Only decisions go in that list; the finishing skill compiles it into one record per item.
```

- [ ] **Step 3: writing-plans**

After the paragraph that ends `names rather than imitating whatever now sits at those lines.`, add:

```markdown
A correction paragraph added to a plan during execution that alters one of
the spec's decisions names it by number and bold title, `Correction (<date>), decision <N> (<title>):`; the
decision records compiled at finish read those paragraphs. Numbers hold because the list is append-only once execution starts (the finishing skill appends an accepted decision after the last item, never inserts one).
```

- [ ] **Step 3b: writing-plans, the plan header template (correction, 2026-10-22)**

The rule must reach the sessions that write corrections, so the `## Plan Document Header` template's agentic-workers line carries it; it reads:

```markdown
> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. A correction added during execution that alters one of the spec's decisions names it: `Correction (<date>), decision <N> (<title>):`.
```

- [ ] **Step 4: Check**

Run: `bash tests/packaging/test-skill-frontmatter.sh && bash tests/packaging/test-no-orphan-skill-files.sh`
Expected: `STATUS: PASSED` twice.

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md
git commit -m "feat(brainstorming,writing-plans): read the decisions index, require the Decisions list, name decisions in corrections"
```

---

### Task 11: Repository text and the offline run

**Risk tier:** standard — repository policy text across two files, then the existing suites.

**Files:**
- Modify: `CLAUDE.md:29-38` ("Planning and Spec Docs Are Tracked Here")
- Modify: `docs/testing.md:26` (the `tests/claude-code/` row) and `:51-53` (the offline-set paragraph)

**Interfaces:**
- Consumes: the names of Tasks 1 to 7.
- Produces: nothing other tasks consume.

**Mirror:** the current section text in `CLAUDE.md:29-38`.

- [ ] **Step 1: Rewrite the planning section**

Replace the section from `## Planning and Spec Docs Are Tracked Here` through the `evals/` bullet with:

```markdown
## Planning and Spec Docs Are Tracked Here

**This repo commits its `docs/hyperpowers/` specs, decision records, and eval-evidence notes alongside the work they describe, and its plans while the work is in flight.** The skills are the product here, and the reasoning behind each one is part of it. `docs/hyperpowers/specs/` records why a skill is shaped the way it is; `docs/hyperpowers/decisions/` holds one record per decision, compiled from each spec's `## Decisions` list when the work finishes, and its `README.md` is the first thing a design session reads; the dated eval-evidence notes record what was measured. Losing that leaves behavior-shaping prose with no argument attached, which is exactly what "Skill Changes Require Evaluation" below is trying to prevent.

Practical consequences:

- Commit new specs and plans alongside the work they describe, or in their own docs commit. They are not scratch.
- A plan leaves the tree at finish, in the same commit that adds its records (git history keeps it); a spec stays, frozen from that commit on, with the Outcome line the compiler owns. The finishing skill does both; do not hand-edit records or the index, re-run `decisions-compile`.
- `docs/hyperpowers/.gitignore` is an allowlist: only `specs/`, `plans/`, `decisions/`, and the top-level evidence notes (`*.md`, `*.tsv`) are committed from that directory. Run artifacts, probes, and review output go to the evals repository (see "Eval harness" below) or the SDD workspace, never here.
- **`evals/` is a different story.** It is gitignored here because it is a separate clone of [hyperpowers-evals](https://github.com/scott-arne/hyperpowers-evals/), not a submodule. Scenario and harness work gets committed *in that repo*, never in this one. See "Eval harness" below.
```

- [ ] **Step 2: Update the testing map**

In `docs/testing.md`, in the `tests/claude-code/` row, change `delivery resolution, worktree path policy, the planning-directory allowlist;` to `delivery resolution, worktree path policy, the planning-directory allowlist, the decision compiler;` and change ``test-docs-allowlist.sh`, one per `bash` call`` to ``test-docs-allowlist.sh`, `test-decisions-compile.sh`, one per `bash` call``. In the offline-set paragraph change `the five offline` to `the six offline`.

- [ ] **Step 3: Run the offline suites this plan touches**

Run, one per `bash` call:

```bash
bash tests/claude-code/test-decisions-compile.sh
bash tests/claude-code/test-docs-allowlist.sh
bash tests/claude-code/test-sdd-dir-path.sh
bash tests/sdd/test-sdd-contract.sh
bash tests/packaging/test-no-orphan-skill-files.sh
bash tests/packaging/test-skill-frontmatter.sh
bash tests/packaging/test-package-skill.sh
bash tests/hooks/test-no-heredocs-in-hooks.sh
bash tests/shell-lint/test-lint-shell.sh
```

Expected: every suite prints `STATUS: PASSED`. After staging, `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` reports `hits: 0`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/testing.md
git commit -m "docs: plans leave the tree at finish, decisions live under docs/hyperpowers/decisions, the compiler suite joins the offline set"
```

---

### Task 12: Parser dry run over this repository's specs, and the evidence note

**Risk tier:** standard — reads real material and may surface a parser defect; writes the evidence note.

**Files:**
- Create: `docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md`

**Interfaces:**
- Consumes: `decisions-compile --dry-run` (Task 1) over `docs/hyperpowers/specs/*.md`.
- Produces: the evidence note Tasks 13 and 14 append to.

**Mirror:** `docs/hyperpowers/2026-10-03-communication-skill-eval-evidence.md:1-30` for the note's header shape.

- [ ] **Step 1: Run the dry run over every spec and tabulate**

Correction (2026-10-22): the first run reported BLOCKED as this step provides for. `title_of` read an item's first line only, so a bold title that wrapped to line 2 kept a raw `**` and was cut at 80 characters, and a plain item without a clause stop on line 1 gave a mid-phrase fragment. The compiler now reads the item's first paragraph joined across lines, Supersedes lines excluded, with bold matched across the join and a plain clause cut at a word boundary (commit 5f82cb9, section 28 of its suite), and the spec's Title paragraph in Design section 1 says so. Two more specs parse than the prediction counted, because their lists sit under headings the heading rule admits, such as `## 2. Locked decisions (from brainstorming)`; the split is 15 exit 0 and 10 exit 2, and the evidence note records it.

Correction (2026-10-22, the human partner's decisions at the Codex gate): the 80-character word-boundary cut left prose fragments on legacy plain items, so a clause longer than 80 characters is now cut at the last `, ` or `; ` inside its first 80 characters that leaves at least 20, else at the last space, else not at all (commit 56bb8ac, section 30 of the suite; the spec's Title paragraph says so). The acceptance rule above is amended: a legacy plain title that this cut still leaves as a fragment, and a status-note item that is spec content, do not block the task; the note records each with its reason. The spec is still never edited to fit the parser.

```bash
cd <the worktree>
{
  printf '| Spec | Exit | Items | Titles |\n|---|---|---|---|\n'
  for f in docs/hyperpowers/specs/*.md; do
    out=$(bash skills/finishing-a-development-branch/scripts/decisions-compile "$f" --dry-run 2>&1); rc=$?
    if [ "$rc" -eq 0 ]; then
      n=$(printf '%s\n' "$out" | grep -c '^would write')
      titles=$(printf '%s\n' "$out" | sed -n 's/^would write .* (decision [0-9]*: \(.*\))$/\1/p' | paste -sd ';' - | sed 's/;/; /g; s/|/\\|/g')
    else
      n=0; titles=$(printf '%s' "$out" | head -n 1 | sed 's/|/\\|/g')
    fi
    printf '| %s | %s | %s | %s |\n' "$(basename "$f")" "$rc" "$n" "$titles"
  done
} > "$TMPDIR/dry-run-table.md"
git status --porcelain
```

Expected: 25 rows (the 24 specs that existed when the plan was written plus this design's own spec); 13 with exit 0 and 12 with exit 2 (4 whose section is prose, 8 with no such section); `git status --porcelain` prints nothing. Read every title. A title is acceptable when a reader of the index would recognise the decision from it; a prose fragment, a status note, or an empty string is not. An unacceptable title is a compiler defect: stop and report BLOCKED with the spec, the item, the title and the parser rule you would add, so the controller can correct Task 1's parser (and its test) and re-run this task. The spec itself is never edited to fit the parser.

- [ ] **Step 2: Write the evidence note**

Create `docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md`:

```markdown
# Decision records: evidence

**Spec:** docs/hyperpowers/specs/2026-10-21-decision-records-design.md
**Plan:** docs/hyperpowers/plans/2026-10-21-decision-records.md
**Compiler:** skills/finishing-a-development-branch/scripts/decisions-compile at <commit sha of Task 6>

## 1. Parser dry run over this repository's specs

Run on <date> from the worktree, `decisions-compile --dry-run` over each
file in `docs/hyperpowers/specs/`. The spec predicted 12 parses among the 24
specs that existed when it was written (4 prose-only Decisions sections, 8
specs without one) plus its own.

<the table from Step 1>

Result: <N> parsed, <M> exit 2. <Any title judged borderline, and why it was
accepted; or "Every title names its decision."> The tree was clean after the
run.

## 2. Finishing-path rehearsal

(Task 13 appends this section.)

## 3. SDD-path rehearsal

(Task 14 appends this section.)

## 4. Post-landing checks still owed

The spec's Live section also asks for one session in Zed, which only the
human partner can run; record it here with the branch, the records commit,
and whether the background dispatch was collected.
```

- [ ] **Step 3: Commit**

```bash
git add docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md
git commit -m "docs(hyperpowers): decision records evidence: the parser dry run over this repository's specs"
```

---

### Task 13: Headless rehearsal of the finishing path

**Risk tier:** standard — live sessions against a fixture; evidence, not product code.

**Files:**
- Create (evals clone, committed there): `evidence/2026-10-21-decision-records/task-13-runs/` with `fixture/`, `prompt-1.txt`, `prompt-2.txt`, `run-finishing.sh`, and one directory per run (`fast/`, `slow/`) holding `turn1.jsonl`, `turn2.jsonl`, their `.err` files, `status.txt`, `fixture-state-1.txt`, `fixture-state-2.txt`
- Modify: `docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md` (section 2)

**Interfaces:**
- Consumes: Tasks 1 to 11 through the worktree loaded as the plugin.
- Produces: the evidence the spec's Live section asks for on the finishing path, including the unfinished-extractor stop.

**Mirror:** `evals/evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:1-30` for the launch.

- [ ] **Step 1: Build the fixture**

Correction (2026-10-22, after this task's Codex gate): the instant-suite premise failed (a Sonnet extractor summarises a few-line diff in seconds), so the launcher takes `PAD_LINES` (a `data/sample.txt` of that many lines in the implementation commit, the device Task 14 prescribes) and the stop at collection is shown by the padded run; the sessions loaded the host's user-level CLAUDE.md despite the empty config dir, so the launcher writes a `claudeMdExcludes` settings file for every ancestor of the work dir (`EXCLUDE_ANCESTORS`, default on; the three first runs ran without it, as `runs.md` beside them records); an optional third turn carries the proposal dispositions after a bare "3". The rehearsal found three gaps in the finishing skill's Step 4, fixed in b2a2bd0 and recorded under Task 8.

Under `evals/evidence/2026-10-21-decision-records/task-13-runs/fixture/` create a small project: `package.json` with `{"name":"notes-cli","version":"1.0.0","scripts":{"test":"bash test.sh"}}`; `notes.sh`, a bash CLI that appends a line to `notes.txt` and lists them; `test.sh`, which runs the CLI twice, asserts two lines, sleeps `"${SUITE_SLEEP:-0}"` seconds, and exits 0; `docs/hyperpowers/specs/2026-10-20-tags-design.md` with a `## Decisions` list of two bold-titled items (one choosing a `#tag` suffix syntax over a separate tags file, one choosing to filter in the CLI rather than in a library); `docs/hyperpowers/plans/2026-10-20-tags.md` with the plan header naming that spec and one task; and `docs/hyperpowers/.gitignore` written by `bash <worktree>/skills/writing-plans/scripts/docs-allowlist` from the fixture root. Write `run-finishing.sh` beside it, adapted from the mirror: it copies the fixture to `$RUN/work`, initialises git on `main` with the CLI, tests, spec and `.gitignore` in the first commit, creates `feature/tags` with the plan added in its first commit and a tags implementation (edit `notes.sh` and `test.sh`) in a second commit, then launches two print-mode turns exactly as the mirror does (the second with `--resume <session id>` read from the first turn's jsonl), passing `SUITE_SLEEP` through the environment, and writes `fixture-state-N.txt` after each turn from `git -C "$RUN/work" diff --cached --name-status`, `git -C "$RUN/work" log --format='%h %cI %s' -5` and `git -C "$RUN/work" status --porcelain`. `prompt-1.txt`:

```
Use hyperpowers:finishing-a-development-branch to finish this branch. The base branch is main and the plan is docs/hyperpowers/plans/2026-10-20-tags.md. Do not merge or push.
```

`prompt-2.txt` is the one line `3` (keep the branch as-is), the non-destructive option, which makes the session commit the records before it runs the option. `PLUGIN_DIR` is the decision-records worktree. Runs are written under the evidence directory, so nothing is copied from `~/.cache`.

- [ ] **Step 2: Run twice and check the transcripts**

Run `SUITE_SLEEP=0 bash run-finishing.sh fast` (the extractor cannot finish before an instant suite: the stop at collection) and `SUITE_SLEEP=150 bash run-finishing.sh slow` (the extractor finishes: notes applied). For each run check, and write the answers into `status.txt`:

1. `fixture-state-1.txt` shows `A docs/hyperpowers/decisions/2026-10-20-<slug>.md` twice, `A docs/hyperpowers/decisions/README.md`, `M docs/hyperpowers/specs/2026-10-20-tags-design.md`, `D docs/hyperpowers/plans/2026-10-20-tags.md`, and no new commit after turn 1 (the log's top line is the tags implementation).
2. `grep -c '"name":"Agent"' turn1.jsonl` is at least 1 and the dispatch's input contains `Decision notes for` and `decision-notes.md` and `"run_in_background":true`.
3. The last assistant text in `turn1.jsonl` contains `## Decision`, `Merge back to main locally`, and both records' titles; in `slow`, a notes body other than `Nothing recorded.`; in `fast`, the hand-back says the extractor was stopped unfinished, and the jsonl shows the Agent dispatch before the suite call, a `TaskStop` call after the suite's result, and no completion notification for that agent before the `TaskStop`.
4. `fixture-state-2.txt` shows the top commit `docs: record decisions for 2026-10-20-tags`, an empty staged set, a clean status, the plan absent, and the branch still `feature/tags` (option 3 ran).
5. `turn1.err` and `turn2.err` carry no `budget` or `error` line other than the final usage summary.
6. Two intervals written into `status.txt`: the test-suite tool result to the menu message (turn 1), and the turn-2 start to the records commit's `%cI` (the commit list and the interval the spec's Live section asks for; the human partner's answer, instant here, sits between the two).

Extract the last assistant text with the mirror's `extract.py` pattern (iterate the jsonl, keep the last `assistant` message's text blocks). A run that fails check 2 or 3 because the session did not follow the skill is a finding about the skill text, not something to patch here: report it BLOCKED with the transcript path and the exact deviation. A run that fails on an API error is re-run once.

- [ ] **Step 3: Record the evidence**

In the evals clone: `git -C evals add evidence/2026-10-21-decision-records && git -C evals commit -m "evidence(decision-records): finishing-path rehearsals, fast and slow suite"`. Then append to section 2 of the evidence note in this repository:

```markdown
Two print-mode Claude Code sessions (model <model>, CC <version>) against a
fixture branch with a two-decision spec and a plan, the decision-records
worktree loaded with `--plugin-dir`, an empty config dir. Artifacts:
`evidence/2026-10-21-decision-records/task-13-runs/` in hyperpowers-evals
(commit <sha>).

| Run | Suite | Extractor at collection | Records staged | Plan deletion staged | Menu message carried the diff | Notes applied | Records commit after "3" | Suite end to menu | Answer to commit |
|---|---|---|---|---|---|---|---|---|---|
| fast | instant | <stopped unfinished / finished> | <yes/no> | <yes/no> | <yes/no> | <yes/no> | <sha> | <seconds> | <seconds> |
| slow | 150 s | <finished> | <yes/no> | <yes/no> | <yes/no> | <yes/no> | <sha> | <seconds> | <seconds> |

<One paragraph on anything the sessions did that the skill text did not ask
for, or "Both sessions followed Step 1 and Step 4 as written.">
```

- [ ] **Step 4: Commit the note**

```bash
git add docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md
git commit -m "docs(hyperpowers): decision records evidence: finishing-path rehearsals"
```

---

### Task 14: Headless rehearsal of the SDD path

**Risk tier:** standard — one long live session against a fixture; evidence, not product code.

**Files:**
- Create (evals clone, committed there): `evidence/2026-10-21-decision-records/task-14-runs/` with `fixture/`, `prompt-1.txt`, `prompt-2.txt`, `run-sdd.sh`, and one directory per run (`slow/`, `fast/`) holding `turn1.jsonl`, `turn2.jsonl`, their `.err` files, `status.txt`, `fixture-state-1.txt`, `fixture-state-2.txt`
- Modify: `docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md` (section 3)

**Interfaces:**
- Consumes: Tasks 1 to 11 through the worktree loaded as the plugin; Task 13's launcher as the template.
- Produces: the evidence the spec's Live section asks for on the SDD path: the dry run at Setup, the extractor dispatched after the final fix wave, Finish deleting the workspace while it runs, collection in finishing after the suite (once with the extractor finished, once with it stopped unfinished), the staged records and the menu message.

**Mirror:** Task 13's `run-finishing.sh`.

- [ ] **Step 1: Build the fixture**

Create `evidence/2026-10-21-decision-records/task-14-runs/fixture/` from Task 13's `package.json`, `notes.sh`, `test.sh` and `docs/hyperpowers/.gitignore`, plus its own design and plan: `docs/hyperpowers/specs/2026-10-20-count-design.md`, a spec for a `--count` flag with a `## Decisions` list of two bold-titled items (a `--count` flag over a separate `count` subcommand; counting the lines of `notes.txt` in the CLI itself rather than through a library), and `docs/hyperpowers/plans/2026-10-20-count.md`, whose header reads `**Spec:** docs/hyperpowers/specs/2026-10-20-count-design.md` and whose single task, declared `low`, carries the complete code: the `--count` branch in `notes.sh`, its assertion in `test.sh`, and a generated `data/sample.txt` of 5,000 numbered lines (`seq` is fine in the fixture) committed with the implementation so the review package the extractor reads is large. `main` holds the CLI, the tests, the spec and `.gitignore`; `feature/count` starts with only the plan added. `run-sdd.sh` is Task 13's two-turn launcher with the prompts below, `timeout 3600`, `--max-budget-usd 20`, and the fixture-state capture extended with `ls <the run's HOME or XDG_CACHE_HOME>/.cache/hyperpowers/sdd 2>/dev/null` so the workspace deletion is visible. `prompt-1.txt`:

```
Use hyperpowers:subagent-driven-development to execute docs/hyperpowers/plans/2026-10-20-count.md. The base branch is main. Do not merge or push.
```

`prompt-2.txt` is the one line `3`.

- [ ] **Step 2: Run twice and check the transcripts**

Run `SUITE_SLEEP=120 bash run-sdd.sh slow` (the extractor has its window and finishes) and `SUITE_SLEEP=0 bash run-sdd.sh fast` (the suite is instant and the review package carries the 5,000-line file, so collection comes before the handed-over extractor can finish, after Finish deleted the workspace). The `fast` run's state is proved from the transcript, not assumed: the Agent dispatch's timestamp, the suite's result timestamp, the `TaskStop` call, and the absence of a completion notification for that agent before the `TaskStop`. If the extractor nonetheless finished first, the run is labelled `finished`, the padding is doubled to 10,000 lines, and the run is repeated once. For each run check, and write into its `status.txt`:

1. A Bash tool call runs `decisions-compile ... --dry-run` before the first implementer dispatch (Setup).
2. After the final reviewer's result and before any Codex final gate or finishing call, an Agent dispatch whose input contains `Decision notes for` and `"run_in_background":true`; a ledger write containing `Decision extractor:`.
3. A Bash call removing the SDD workspace (`rm -rf` of a path under `hyperpowers/sdd/`) occurs before the finishing skill's test run; `fixture-state-1.txt` shows the workspace root empty or absent afterwards.
4. The finishing skill's compile call occurs after the test-suite call; `fixture-state-1.txt` shows the two records, the index, the spec modification and the plan deletion staged, no new commit after the task's commits.
5. The last assistant text of turn 1 contains `## Decision` and `Merge back to main locally`; in `slow`, a notes body other than `Nothing recorded.`; in `fast`, a `TaskStop` tool call after the suite's result and before the compile call, records reading `Nothing recorded.`, and a hand-back line saying the extractor was stopped unfinished.
6. `fixture-state-2.txt` shows the top commit `docs: record decisions for 2026-10-20-count`, an empty staged set, a clean status, the plan absent, and the branch still `feature/count`.
7. Two intervals: the test-suite tool result to the menu message (turn 1), and the turn-2 start to the records commit's `%cI`.

The same BLOCKED rule as Task 13 applies to a session that did not follow the skill; one re-run on an API error. The per-task and final Codex gates degrade in the fixture's empty config dir (no codex plugin), which is the documented no-Codex path; the extractor's dispatch point is then still after the final fix wave, and its window is the finishing suite.

- [ ] **Step 3: Record the evidence**

`git -C evals add evidence/2026-10-21-decision-records && git -C evals commit -m "evidence(decision-records): SDD-path rehearsals, finished and stopped extractor"`. Append to section 3 of the evidence note:

```markdown
Two print-mode Claude Code sessions (model <model>, CC <version>) executing a
one-task plan in the fixture with the decision-records worktree as the
plugin, no Codex plugin in its config dir. Artifacts:
`evidence/2026-10-21-decision-records/task-14-runs/` in hyperpowers-evals
(commit <sha>).

| Check | slow (120 s suite) | fast (instant suite) |
|---|---|---|
| dry run at Setup | <yes/no> | <yes/no> |
| extractor dispatched after the final review, in the background | <yes/no> | <yes/no> |
| workspace deleted while the extractor ran | <yes/no> | <yes/no> |
| extractor at collection | finished | stopped unfinished (TaskStop seen) |
| compile after the suite, records and plan deletion staged | <yes/no> | <yes/no> |
| menu message carried the diff | <yes/no> | <yes/no> |
| notes applied | <yes/no> | no (Nothing recorded.) |
| records commit after "3" | <sha> | <sha> |
| suite end to menu | <seconds> | <seconds> |
| answer to commit | <seconds> | <seconds> |

<One paragraph on deviations, or "The session followed the SDD and finishing text as written.">
```

- [ ] **Step 4: Commit the note**

```bash
git add docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md
git commit -m "docs(hyperpowers): decision records evidence: SDD-path rehearsal"
```

---

## Execution notes

- Tasks 1 to 6 build one script in order; each later task names the exact
  functions and sections of the earlier one it extends. Read the current
  file before editing: the structure described is the file at the end of the
  previous task.
- Task 7 is independent of Tasks 1 to 6; Task 8 needs the compiler's final
  usage (Task 6); Task 9 needs Task 8's hand-off contract and prompt file;
  Task 10 is independent; Task 11 needs Task 7; Task 12 needs Task 6;
  Tasks 13 and 14 need everything before them.
- No release task: the version bump, CHANGELOG entry and the plugin-install
  worktree checkout happen in the release that ships this, as they did for
  6.16.1.
