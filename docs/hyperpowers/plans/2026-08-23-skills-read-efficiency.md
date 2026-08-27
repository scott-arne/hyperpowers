# Skills Read-Efficiency: Splitting the Codex Review Gate — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-08-23-skills-read-efficiency-design.md`

**Goal:** Turn `skills/requesting-code-review/codex-review-gate.md` (766 lines, 970 opens, 87% partial reads) into a 46-line dispatcher index plus nine sub-150-line section files, with zero caller edits and mechanically-proven losslessness; then, gated on live evals, flatten the brainstorming reference chain and split `subagent-driven-development/SKILL.md`.

**Architecture:** The gate document stays at its current path and becomes a router. Content moves verbatim into siblings in the same directory; the index carries the preamble, a one-line description per sibling, and a complete route per caller. Callers read their whole route as a *set* before acting, so the document's cyclic §-references always resolve in context and no section file ever needs to link to another. Losslessness is proven by reconstructing every destination file from a git-pinned copy of the pre-split original and requiring byte-identity.

**Tech Stack:** Markdown skill documents; bash needle-suite tests (`tests/codex-review-gate/`, `tests/claude-code/`); `git show` for the pinned original; quorum eval scenarios in the `evals/` checkout (Bun).

## Global Constraints

- **Content moves verbatim.** Every non-blank source line lands in exactly one destination file, byte-for-byte, except the eight enumerated positional-reference rewrites in Task 2. No rewording, no consolidation, no incidental edits, no "while I'm here" fixes. The repo rule against retuning behavior-shaping content without evidence applies to every line of this document.
- **Blank separator lines 273 and 356 are untracked** — they may be dropped or recreated as formatting requires. No other line may be added or removed.
- **Section numbers stay in the headings.** `gate-preflight.md` keeps `## 1. Preflight availability`, verbatim. Four callers address sections by number.
- **Section files may not link to each other.** Cross-references stay as §-numbers in prose. The index is the only router. Naming a file the route already delivered is permitted; instructing the agent to go read one is forbidden.
- **`codex-review-gate.md` keeps its exact current path.** All seven call sites depend on it. No caller file is edited in Phase A.
- New files live in `skills/requesting-code-review/` alongside the index. Names exactly: `gate-preflight.md`, `gate-setup.md`, `gate-output-schema.md`, `gate-lenses.md`, `recipe-document.md`, `recipe-code.md`, `gate-findings.md`, `gate-fix-loop.md`, `gate-sweep.md`.
- Every new shell script must pass `scripts/lint-shell.sh` (ShellCheck + `bash -n`).
- Behavior is unchanged: same preflight, same lenses, same severity ladder, same round accounting, same backstops. No change to any of the eleven scripts in `skills/requesting-code-review/scripts/`.
- Never commit anything under `docs/hyperpowers/`. Stage only the named files. No AI-attribution lines in commit messages, no `Co-Authored-By`.
- Do not push. Do not run destructive git commands.
- Version bump happens once, in the final task, via `/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y` — `vrzn` is not on `PATH` here. It updates six manifests (the repo has `vrzn.toml`; do not hand-edit version strings and do not use `scripts/bump-version.sh`).
- **Phase B (Tasks 6-7) does not start until Task 5's eval release gate passes.**

## Accepted trade-off: reference depth

Phase A leaves the nine section files two levels from the caller SKILL.md files — the nesting the authoring guidance warns about. This is deliberate and is not a defect to fix mid-execution. The warning exists because agents partially read nested files, and the measured partial-read rate on the *current* single file is already 87%. Trading "two levels, one 766-line target" for "two levels, sub-150-line targets" is strictly better on the exact axis the guidance cares about, and it costs zero caller edits. Task 6 collapses the approach-gate path to one level.

## Tasks 1-4 and 7 were prototyped before this plan was written

Every script, data file, and command in Tasks 1-4 was run end-to-end against a throwaway git copy of `skills/`, `tests/`, and `scripts/`, in task order, before this plan was finalized; Task 7's extraction was run the same way against a second copy. The line counts, assertion counts, and failure counts quoted in the expected results are measured, not estimated.

Those runs are also why two tasks have a step the earlier drafts did not. Task 3: **two of the 119 contract assertions pin text that lives inside a rewritten line and fail after the split.** Four careful readings — mine and the spec reviewer's — missed it. Task 7: **one contract assertion pins a needle inside an extracted section and fails after the extraction**, and the naive `sed` ranges swallow the blank separator before the next heading. If an expected result does not match what you see, suspect your execution before you suspect the number.

---

### Task 1: Assembled-gate view; retarget both existing tests

Two existing tests read `codex-review-gate.md` directly. After the split they would fail — or worse, pressure an implementer into pasting content back into the index to make a grep pass. Both are retargeted *before* the split so the safety net exists when it is needed. The assembler derives its sibling list from the index's own markdown links, so it yields exactly the current single file today (the gate document contains no markdown links at all — verified) and the index plus all nine siblings after Task 3. This task is green before and after the split.

**Risk tier:** standard — multi-file test-infrastructure change that everything downstream depends on.

**Files:**
- Create: `tests/codex-review-gate/assemble-gate.sh`
- Modify: `tests/codex-review-gate/test-gate-contract.sh:6`
- Modify: `tests/claude-code/test-codex-review-dir-path.sh:20`

**Interfaces:**
- Produces: `assemble-gate.sh <repo-root> <out-file>` — writes the concatenation of `skills/requesting-code-review/codex-review-gate.md` followed by every same-directory `.md` file it links to, in link order, to `<out-file>`. Exits non-zero if the index is missing or a linked sibling does not exist. Tasks 3 and 4 rely on this exact signature.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-assemble-gate.sh`:

```bash
#!/usr/bin/env bash
# Contract for the assembled-gate view used by the gate contract tests.
#
# The gate document is a dispatcher index plus section-file siblings. Tests
# that assert on gate CONTENT must see the whole gate, not just the index.
# This helper produces that view. It must behave correctly both before the
# split (index only, no links) and after (index plus every linked sibling).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASSEMBLE="$SCRIPT_DIR/assemble-gate.sh"

failures=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

TEST_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

echo "=== assemble-gate view test ==="
echo ""

# 1. Real repo: the assembled view is non-empty and starts with the index.
out="$TEST_ROOT/real.md"
if bash "$ASSEMBLE" "$REPO_ROOT" "$out"; then
    pass "assembler succeeds against the real repo"
else
    fail "assembler succeeds against the real repo"
fi
if head -1 "$out" | grep -Fq '# Codex Review Gate'; then
    pass "assembled view starts with the index heading"
else
    fail "assembled view starts with the index heading"
fi

# 2. Synthetic index with siblings: all linked files are concatenated in
#    link order, and the index itself comes first.
synth="$TEST_ROOT/synth/skills/requesting-code-review"
mkdir -p "$synth"
printf '# Codex Review Gate\n\n[gate-preflight.md](gate-preflight.md)\n[gate-sweep.md](gate-sweep.md)\n' \
    >"$synth/codex-review-gate.md"
printf 'PREFLIGHT_NEEDLE\n' >"$synth/gate-preflight.md"
printf 'SWEEP_NEEDLE\n' >"$synth/gate-sweep.md"
synth_out="$TEST_ROOT/synth.md"
bash "$ASSEMBLE" "$TEST_ROOT/synth" "$synth_out"
if grep -Fq 'PREFLIGHT_NEEDLE' "$synth_out" && grep -Fq 'SWEEP_NEEDLE' "$synth_out"; then
    pass "assembled view includes every linked sibling"
else
    fail "assembled view includes every linked sibling"
fi
if [ "$(grep -n 'PREFLIGHT_NEEDLE' "$synth_out" | cut -d: -f1)" -lt \
     "$(grep -n 'SWEEP_NEEDLE' "$synth_out" | cut -d: -f1)" ]; then
    pass "siblings are concatenated in link order"
else
    fail "siblings are concatenated in link order"
fi

# 3. A dangling link is an error, not a silent omission. This is the
#    property that stops a renamed sibling from quietly dropping content
#    out of every content assertion downstream.
printf '# Codex Review Gate\n\n[missing.md](missing.md)\n' >"$synth/codex-review-gate.md"
if bash "$ASSEMBLE" "$TEST_ROOT/synth" "$TEST_ROOT/dangling.md" >/dev/null 2>&1; then
    fail "assembler fails on a dangling sibling link"
else
    pass "assembler fails on a dangling sibling link"
fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-assemble-gate.sh`
Expected: FAIL — `assemble-gate.sh` does not exist yet, so the first assertion fails and later steps error out.

- [ ] **Step 3: Write the assembler**

Create `tests/codex-review-gate/assemble-gate.sh`:

```bash
#!/usr/bin/env bash
#
# assemble-gate.sh — emit the whole Codex review gate as one file.
#
# Usage: assemble-gate.sh <repo-root> <out-file>
#
# The gate is a dispatcher index (codex-review-gate.md) plus section-file
# siblings in the same directory. Content assertions must run against the
# union, not the index; otherwise splitting the document would silently
# empty them out. Siblings are discovered from the index's own markdown
# links, so this stays correct as files are added or renamed, and a
# dangling link is a hard error rather than a silent omission.
set -uo pipefail

repo_root="${1:?usage: assemble-gate.sh <repo-root> <out-file>}"
out_file="${2:?usage: assemble-gate.sh <repo-root> <out-file>}"

gate_dir="$repo_root/skills/requesting-code-review"
index="$gate_dir/codex-review-gate.md"

if [ ! -f "$index" ]; then
  echo "assemble-gate: index not found: $index" >&2
  exit 1
fi

: >"$out_file"
cat "$index" >>"$out_file"

# Same-directory .md link targets, in the order they appear, deduplicated.
seen=" "
while IFS= read -r target; do
  case "$seen" in *" $target "*) continue ;; esac
  seen="$seen$target "
  sibling="$gate_dir/$target"
  if [ ! -f "$sibling" ]; then
    echo "assemble-gate: index links a missing sibling: $target" >&2
    exit 1
  fi
  cat "$sibling" >>"$out_file"
done < <(grep -o '](\([a-z0-9-]*\.md\))' "$index" | sed 's/^](//; s/)$//')
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-assemble-gate.sh`
Expected: PASS — all five assertions.

- [ ] **Step 5: Retarget the contract test**

In `tests/codex-review-gate/test-gate-contract.sh`, replace line 6:

```bash
GATE="$REPO_ROOT/skills/requesting-code-review/codex-review-gate.md"
```

with:

```bash
# The gate is an index plus section-file siblings; assert against the union.
GATE="$(mktemp)"
trap 'rm -f "$GATE"' EXIT
bash "$SCRIPT_DIR/assemble-gate.sh" "$REPO_ROOT" "$GATE" || exit 1
```

Change nothing else in this file. All 96 assertions stay exactly as written.

- [ ] **Step 6: Retarget the scratch-dir path test**

In `tests/claude-code/test-codex-review-dir-path.sh`, replace line 20:

```bash
GATE="$REPO_ROOT/skills/requesting-code-review/codex-review-gate.md"
```

with:

```bash
# The gate is an index plus section-file siblings; grep the union, not the
# index — otherwise a split would make these greps pressure content back
# into the index just to keep them passing.
GATE="$TEST_ROOT/assembled-gate.md"
bash "$REPO_ROOT/tests/codex-review-gate/assemble-gate.sh" "$REPO_ROOT" "$GATE"
```

Note the ordering constraint: this file already creates `TEST_ROOT` at line 23 and its `cleanup` trap at line 28. Move the two new lines to immediately after the `trap cleanup EXIT` line so `$TEST_ROOT` exists first, and leave `REVIEW_DIR_SCRIPT` at line 19 where it is.

- [ ] **Step 7: Run both retargeted tests**

Run:
```bash
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/claude-code/test-codex-review-dir-path.sh
```
Expected: both `STATUS: PASSED`. The contract test reports **119 passing assertions** (96 of which target `$GATE`; the rest target the caller skills). That count must not change in this task.

- [ ] **Step 8: Lint**

Run: `scripts/lint-shell.sh tests/codex-review-gate/assemble-gate.sh tests/codex-review-gate/test-assemble-gate.sh tests/codex-review-gate/test-gate-contract.sh tests/claude-code/test-codex-review-dir-path.sh`
Expected: clean.

- [ ] **Step 9: Commit**

```bash
git add tests/codex-review-gate/assemble-gate.sh tests/codex-review-gate/test-assemble-gate.sh tests/codex-review-gate/test-gate-contract.sh tests/claude-code/test-codex-review-dir-path.sh
git commit -m "test(gate): assert against the assembled gate view, not the index file

The gate document is about to become a dispatcher index plus section-file
siblings. Both tests that read it directly would fail after the split, and a
failing grep against the index is exactly the pressure that would push content
back into the index to make it pass. Retarget both to the assembled union
first, so the safety net exists before the move."
```

---

### Task 2: Split manifest, positional-reference inventory, and the losslessness verifier

This is the proof machinery, and it is built before the split so the split has something to be checked against. Two manual passes over the positional references each produced a wrong list, so the disposition is *derived* from data rather than asserted: the candidate set is enumerated exhaustively by pattern, each candidate's referent line is recorded, and the verifier computes "rewrite" versus "verbatim" by mapping both through the manifest. The table in the spec is the expected output and a fixture to check against — not a substitute for running the derivation.

Everything in this task is checkable today, against the current unsplit file: the ranges must tile it, the candidate count must match an independent grep, and the reconstruction of all ten slices concatenated must equal the original byte-for-byte.

**Risk tier:** standard — new verification scripts whose output the split task trusts completely.

**Files:**
- Create: `tests/codex-review-gate/gate-split-manifest.tsv`
- Create: `tests/codex-review-gate/gate-split-references.tsv`
- Create: `tests/codex-review-gate/test-gate-split-lossless.sh`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `test-gate-split-lossless.sh`, which Task 3 runs to prove the move. It reads both `.tsv` files and the pinned pre-split original from git. Task 3 relies on the manifest's exact destination filenames and line ranges.

- [ ] **Step 1: Record the pinned pre-split commit**

The verifier needs the original 766-line file forever, so it reads it out of git rather than keeping a copy. Capture the current HEAD — this must be done before Task 3 changes the file:

```bash
git rev-parse HEAD
```

Use that SHA as `ORIGIN_SHA` in Step 4. If Task 1 has already been committed, this SHA is Task 1's commit; that is correct, because Task 1 did not touch the gate document.

- [ ] **Step 2: Write the manifest**

Create `tests/codex-review-gate/gate-split-manifest.tsv`. Tab-separated. Lines 273 and 356 are blank separators and are deliberately absent from every range:

```
# destination	start	end
# Lines 1-10 stay in codex-review-gate.md as the index preamble.
# Blank separators 273 and 356 are untracked and appear in no range.
gate-preflight.md	11	100
gate-setup.md	101	176
gate-lenses.md	177	219
recipe-document.md	220	272
recipe-code.md	274	355
gate-output-schema.md	357	393
gate-findings.md	394	541
gate-fix-loop.md	542	690
gate-sweep.md	691	766
```

Rows are in source order. Note that `gate-output-schema.md` (357-393) sits between `recipe-code.md` and `gate-findings.md` in the source even though the index lists it earlier for reading purposes — source order and route order are different things and the manifest tracks source order.

- [ ] **Step 3: Write the positional-reference table**

Create `tests/codex-review-gate/gate-split-references.tsv`. Columns: source line, referent line, disposition, replacement text (empty for verbatim rows). The `referent` column is the human judgment; the `disposition` column is what the verifier recomputes and checks. A referent of `-` means "not a source-document reference at all" (a prompt literal describing the generated prompt's own layout).

```
# srcline	referent	disposition	replacement
106	188	rewrite	Write the gate's own scratch files — the prompt files named in gate-lenses.md and the recipe files, the round ledger,
130	233	rewrite	ledger) to the recipe prompt for this gate type and pass the ledger path, so Codex confirms prior
131	177	rewrite	resolutions instead of re-reviewing cold. The first round composes the per-lens prompts from the lens fan-out block in gate-lenses.md instead of this single prompt.
133	225	rewrite	Run `task` in the **foreground** — as written in recipe-document.md, with no `--background`. The
153	156	verbatim
161	156	verbatim
191	203	verbatim
195	-	verbatim
196	357	rewrite	<the Required document-review output block from gate-output-schema.md, verbatim>
218	233	rewrite	**Re-review rounds (2+) use no lenses**: the existing single-reviewer round-aware preamble and ledger contract apply verbatim. The ORIGINAL single-review spec and plan prompt templates are retained in recipe-document.md, textually unchanged, and rounds 2+ compose from them exactly as today.
229	357	rewrite	Required document-review output block from gate-output-schema.md into the prompt so Codex has the
233	-	verbatim
244	357	rewrite	Required document-review output block from gate-output-schema.md into the prompt so Codex has the
248	-	verbatim
275	280	verbatim
429	443	verbatim
443	450	verbatim
558	615	verbatim
631	645	verbatim
645	648	verbatim
```

Twenty rows: the nineteen lines matching `below|above`, plus line 196, which contains neither word and is the composer instruction that points at the block moving to `gate-output-schema.md`. Lines 229 and 244 carry byte-identical text, which is why replacement is keyed by line number and never by text match.

Verbatim rows have three fields and no trailing tab — `read -r a b c d` leaves `d` empty when the fourth field is absent, so a trailing tab buys nothing and only creates invisible whitespace that a later editor can strip without noticing.

- [ ] **Step 4: Write the failing verifier test**

Create `tests/codex-review-gate/test-gate-split-lossless.sh`:

```bash
#!/usr/bin/env bash
#
# Losslessness proof for the codex-review-gate.md split.
#
# The gate document was split into a dispatcher index plus nine section
# files. This check proves the move lost nothing. It reads the pre-split
# original out of git at a pinned commit, reconstructs every destination
# file from the declared line ranges plus the declared positional-reference
# rewrites, and requires byte-identity.
#
# The gate contract test cannot do this job: it normalizes whitespace and
# only pins selected substrings, so it would still pass after reordering,
# duplication, or the loss of any line no assertion happens to name.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE_DIR="$REPO_ROOT/skills/requesting-code-review"
MANIFEST="$SCRIPT_DIR/gate-split-manifest.tsv"
REFERENCES="$SCRIPT_DIR/gate-split-references.tsv"

# Pinned pre-split commit. The original file is read from git, so it stays
# available no matter what happens to the working tree.
ORIGIN_SHA="__FILL_IN_FROM_STEP_1__"
ORIGIN_PATH="skills/requesting-code-review/codex-review-gate.md"
ORIGIN_LINES=766
UNTRACKED_BLANKS=(273 356)
TAB="$(printf '\t')"

failures=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

TEST_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

original="$TEST_ROOT/original.md"
if ! git -C "$REPO_ROOT" show "$ORIGIN_SHA:$ORIGIN_PATH" >"$original" 2>/dev/null; then
    echo "  [FAIL] cannot read pinned original $ORIGIN_SHA:$ORIGIN_PATH"
    exit 1
fi

echo "=== gate split losslessness ==="
echo ""

# --- 1. The pinned original is the file we planned against. ---
actual_lines="$(wc -l <"$original" | tr -d ' ')"
if [ "$actual_lines" = "$ORIGIN_LINES" ]; then
    pass "pinned original is $ORIGIN_LINES lines"
else
    fail "pinned original is $ORIGIN_LINES lines (got $actual_lines)"
fi

# --- 2. The declared ranges tile 1..766, gaps only at declared blanks. ---
covered="$TEST_ROOT/covered"
: >"$covered"
overlap=0
while IFS="$TAB" read -r dest start end; do
    case "$dest" in \#* | "") continue ;; esac
    seq "$start" "$end" >>"$covered"
done <"$MANIFEST"
total="$(wc -l <"$covered" | tr -d ' ')"
sort -n "$covered" | uniq >"$covered.sorted"
uniq_total="$(wc -l <"$covered.sorted" | tr -d ' ')"
[ "$total" = "$uniq_total" ] || overlap=1
if [ "$overlap" -eq 0 ]; then
    pass "no line is claimed by two destinations"
else
    fail "no line is claimed by two destinations ($((total - uniq_total)) duplicated)"
fi

expected="$TEST_ROOT/expected"
seq 11 "$ORIGIN_LINES" >"$expected"
for b in "${UNTRACKED_BLANKS[@]}"; do
    grep -vx "$b" "$expected" >"$expected.tmp" && mv "$expected.tmp" "$expected"
done
sort -n "$expected" -o "$expected"
if diff -q "$expected" "$covered.sorted" >/dev/null; then
    pass "ranges tile lines 11-$ORIGIN_LINES exactly (1-10 stay in the index; ${UNTRACKED_BLANKS[*]} untracked)"
else
    fail "ranges tile lines 11-$ORIGIN_LINES exactly"
    diff "$expected" "$covered.sorted" | head -20
fi

# --- 3. The positional-reference candidate set is exhaustive. ---
# Independent enumeration: every line naming a relative position, plus the
# composer instruction that points at the output block without using
# "below". If a future edit adds a positional reference, this fails and the
# table must be updated rather than the count.
grep -n 'below\|above' "$original" | cut -d: -f1 >"$TEST_ROOT/grep-hits"
grep -n '^<the existing .*verbatim>$' "$original" | cut -d: -f1 >>"$TEST_ROOT/grep-hits"
sort -n "$TEST_ROOT/grep-hits" | uniq >"$TEST_ROOT/candidates"
grep -v '^#' "$REFERENCES" | grep -v '^$' | cut -f1 | sort -n >"$TEST_ROOT/tabled"
if diff -q "$TEST_ROOT/candidates" "$TEST_ROOT/tabled" >/dev/null; then
    pass "reference table covers every positional-reference candidate"
else
    fail "reference table covers every positional-reference candidate"
    diff "$TEST_ROOT/candidates" "$TEST_ROOT/tabled"
fi

# --- 4. Disposition is DERIVED, not trusted. ---
# A reference is a rewrite if and only if its referent lands in a different
# destination than the reference itself. Referent "-" means the reference
# describes the generated prompt's own layout, never the source document,
# so it is always verbatim.
dest_of() {
    local line="$1"
    [ "$line" -le 10 ] && { echo "codex-review-gate.md"; return; }
    while IFS="$TAB" read -r d s e; do
        case "$d" in \#* | "") continue ;; esac
        if [ "$line" -ge "$s" ] && [ "$line" -le "$e" ]; then
            echo "$d"
            return
        fi
    done <"$MANIFEST"
    echo "UNMAPPED"
}

bad_disposition=0
while IFS="$TAB" read -r src referent disposition _replacement; do
    case "$src" in \#* | "") continue ;; esac
    if [ "$referent" = "-" ]; then
        derived="verbatim"
    elif [ "$(dest_of "$src")" = "$(dest_of "$referent")" ]; then
        derived="verbatim"
    else
        derived="rewrite"
    fi
    if [ "$derived" != "$disposition" ]; then
        echo "    line $src: table says $disposition, derivation says $derived"
        bad_disposition=$((bad_disposition + 1))
    fi
done <"$REFERENCES"
if [ "$bad_disposition" -eq 0 ]; then
    pass "every disposition matches the derivation from the manifest"
else
    fail "every disposition matches the derivation from the manifest ($bad_disposition wrong)"
fi

rewrite_count="$(grep -v '^#' "$REFERENCES" | grep -c "$(printf '\trewrite\t')")"
if [ "$rewrite_count" -eq 8 ]; then
    pass "exactly 8 cross-file rewrites, as designed"
else
    fail "exactly 8 cross-file rewrites, as designed (got $rewrite_count)"
fi

# awk -v reinterprets backslash escapes in the value it is given, and BOTH the
# split script and this verifier substitute through awk -v — so a mangled
# replacement would appear identically on each side and pass unnoticed. None of
# the eight replacements contains a backslash today; keep it that way.
# shellcheck disable=SC1003  # the literal backslash is the pattern, not an escape
if grep -v '^#' "$REFERENCES" | cut -f4 | grep -qF '\'; then
    fail "no replacement text contains a backslash (awk -v would reinterpret it)"
else
    pass "no replacement text contains a backslash"
fi

# --- 5. Reconstruct each destination from the original plus rewrites. ---
reconstruct() {
    local dest="$1" start="$2" end="$3" out="$4"
    sed -n "${start},${end}p" "$original" >"$out"
    while IFS="$TAB" read -r src _referent disposition replacement; do
        case "$src" in \#* | "") continue ;; esac
        [ "$disposition" = "rewrite" ] || continue
        [ "$src" -ge "$start" ] && [ "$src" -le "$end" ] || continue
        local offset=$((src - start + 1))
        awk -v n="$offset" -v repl="$replacement" \
            'NR==n { print repl; next } { print }' "$out" >"$out.tmp"
        mv "$out.tmp" "$out"
    done <"$REFERENCES"
}

# 5a. Runnable before the split: all reconstructions concatenated in source
#     order must equal the original, modulo untracked blanks and rewrites.
joined="$TEST_ROOT/joined.md"
: >"$joined"
sed -n '1,10p' "$original" >>"$joined"
while IFS="$TAB" read -r dest start end; do
    case "$dest" in \#* | "") continue ;; esac
    reconstruct "$dest" "$start" "$end" "$TEST_ROOT/recon-$dest"
    cat "$TEST_ROOT/recon-$dest" >>"$joined"
done <"$MANIFEST"

baseline="$TEST_ROOT/baseline.md"
cp "$original" "$baseline"
while IFS="$TAB" read -r src _referent disposition replacement; do
    case "$src" in \#* | "") continue ;; esac
    [ "$disposition" = "rewrite" ] || continue
    awk -v n="$src" -v repl="$replacement" \
        'NR==n { print repl; next } { print }' "$baseline" >"$baseline.tmp"
    mv "$baseline.tmp" "$baseline"
done <"$REFERENCES"
# Drop the untracked blank separators, highest line first so earlier
# numbers stay valid. One sed program: "356d;273d".
del="$(printf '%s\n' "${UNTRACKED_BLANKS[@]}" | sort -rn | sed 's/$/d/' | tr '\n' ';')"
sed "$del" "$baseline" >"$baseline.tmp" && mv "$baseline.tmp" "$baseline"

if cmp -s "$joined" "$baseline"; then
    pass "reconstructions concatenate back to the original, byte-for-byte"
else
    fail "reconstructions concatenate back to the original, byte-for-byte"
    diff "$baseline" "$joined" | head -20
fi

# 5b. Runs once the split has happened: each destination file on disk equals
#     its reconstruction. Gated on the index no longer carrying section
#     bodies, so a pre-split run reports SKIP rather than a vacuous pass.
if grep -Fq '## 1. Preflight availability' "$GATE_DIR/codex-review-gate.md"; then
    echo "  [SKIP] per-file byte-identity (pre-split: index still holds section bodies)"
else
    # The index preamble is the one destination with no manifest row, so the
    # loop below would never see it and check 5a compares it against itself
    # (both sides read lines 1-10 from the pinned original). Without this,
    # silently rewording the preamble during the split passes every check.
    if cmp -s <(sed -n '1,10p' "$original") <(sed -n '1,10p' "$GATE_DIR/codex-review-gate.md"); then
        pass "index preamble is byte-identical to source lines 1-10"
    else
        fail "index preamble is byte-identical to source lines 1-10"
        diff <(sed -n '1,10p' "$original") <(sed -n '1,10p' "$GATE_DIR/codex-review-gate.md")
    fi
    while IFS="$TAB" read -r dest start end; do
        case "$dest" in \#* | "") continue ;; esac
        if [ ! -f "$GATE_DIR/$dest" ]; then
            fail "$dest exists"
            continue
        fi
        if cmp -s "$TEST_ROOT/recon-$dest" "$GATE_DIR/$dest"; then
            pass "$dest is byte-identical to source lines $start-$end"
        else
            fail "$dest is byte-identical to source lines $start-$end"
            diff "$TEST_ROOT/recon-$dest" "$GATE_DIR/$dest" | head -10
        fi
    done <"$MANIFEST"
fi

# --- 6. Audit trail for the two contract needles the rewrites touch. ---
# Two of the 119 assertions in test-gate-contract.sh pin text that the
# declared rewrites change, so Task 3 edits those two needles. This check is
# what makes that edit auditable: both retired strings must be absent and
# both replacements present in the reconstruction, which is derived from the
# pinned original plus the declared replacements and nothing else. Check 5
# already proves no other line moved. Together they mean a quiet rewording
# cannot hide behind "an intentional test edit".
#
# Matching uses the same normalization as the contract test, because the
# needles span line breaks in the source.
normalized="$TEST_ROOT/joined.normalized"
tr '\n\t' '  ' <"$joined" | sed 's/  */ /g' >"$normalized"

RETIRED_1="Copy the Required document-review output block below into the prompt"
RETIRED_2="composes the per-lens prompts from the lens fan-out block below"
REPLACEMENT_1="Copy the Required document-review output block from gate-output-schema.md into the prompt"
REPLACEMENT_2="composes the per-lens prompts from the lens fan-out block in gate-lenses.md"

for needle in "$RETIRED_1" "$RETIRED_2"; do
    if grep -Fq "$needle" "$normalized"; then
        fail "retired contract needle is gone: \"$needle\""
    else
        pass "retired contract needle is gone: \"$needle\""
    fi
done
for needle in "$REPLACEMENT_1" "$REPLACEMENT_2"; do
    if grep -Fq "$needle" "$normalized"; then
        pass "replacement contract needle is present: \"$needle\""
    else
        fail "replacement contract needle is present: \"$needle\""
    fi
done

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
```

- [ ] **Step 5: Fill in the pinned SHA and run**

Replace `__FILL_IN_FROM_STEP_1__` with the SHA from Step 1.

Run: `bash tests/codex-review-gate/test-gate-split-lossless.sh`
Expected: `STATUS: PASSED` — twelve `[PASS]` lines (checks 1 through 5a, then check 6's four needle assertions) and one `[SKIP] per-file byte-identity (pre-split: ...)` line for 5b. If the tiling or reconstruction assertions fail, the manifest or the reference table is wrong — fix the data, never the assertion.

- [ ] **Step 6: Lint**

Run: `scripts/lint-shell.sh tests/codex-review-gate/test-gate-split-lossless.sh`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add tests/codex-review-gate/gate-split-manifest.tsv tests/codex-review-gate/gate-split-references.tsv tests/codex-review-gate/test-gate-split-lossless.sh
git commit -m "test(gate): line-accounting proof for the pending gate split

Declares the destination line ranges and the positional references whose
referents cross a file boundary, then proves both against the pre-split
original read from a pinned commit: the ranges tile the document exactly, the
reference table matches an independent enumeration, and every disposition is
recomputed from the manifest rather than taken on trust. Two manual passes over
those references each produced a wrong list, so the classification is derived.

The per-file identity check skips until the split lands."
```

---

### Task 3: Perform the split

The mechanical move. Placement assertions are written first so the split has to actually distribute content rather than dump it in one file, and Task 2's per-file identity check activates the moment the index stops carrying section bodies. The index written here is provisional: preamble plus a linked description table, enough for the assembler and the contract test. Task 4 adds the routing matrix.

**Risk tier:** standard — behavior-shaping document surgery across ten files. Not low: the content being moved governs every review gate in the package.

**Files:**
- Create: `skills/requesting-code-review/gate-preflight.md`, `gate-setup.md`, `gate-lenses.md`, `recipe-document.md`, `recipe-code.md`, `gate-output-schema.md`, `gate-findings.md`, `gate-fix-loop.md`, `gate-sweep.md`
- Modify: `skills/requesting-code-review/codex-review-gate.md` (766 lines → 23)
- Modify: `tests/codex-review-gate/test-gate-contract.sh:82,277` (two needles, Step 7)
- Create: `tests/codex-review-gate/test-gate-placement.sh`

**Interfaces:**
- Consumes: `assemble-gate.sh` (Task 1); `gate-split-manifest.tsv` and `test-gate-split-lossless.sh` (Task 2).
- Produces: the nine section files at the exact names in the manifest. Task 4 links them from the routing matrix.

- [ ] **Step 1: Write the failing placement test**

Concatenation alone would pass if every line were dumped into one sibling. One distinctive needle per file pins the split actually happened.

Create `tests/codex-review-gate/test-gate-placement.sh`:

```bash
#!/usr/bin/env bash
#
# Placement check for the split Codex review gate.
#
# test-gate-split-lossless.sh proves nothing was lost; this proves the
# content went to the right places. Without it, dumping all nine sections
# into one sibling would still pass every other check.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE_DIR="$REPO_ROOT/skills/requesting-code-review"

failures=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

assert_in() {
    local file="$1" needle="$2" description="$3"
    if [ ! -f "$GATE_DIR/$file" ]; then
        fail "$description (missing file: $file)"
        return
    fi
    if grep -Fq -- "$needle" "$GATE_DIR/$file"; then
        pass "$description"
    else
        fail "$description"
        echo "    expected in $file: $needle"
    fi
}

echo "=== gate section placement ==="
echo ""

assert_in gate-preflight.md '## 1. Preflight availability' 'preflight section lives in gate-preflight.md'
assert_in gate-preflight.md '## 2. No-Codex notice' 'no-Codex notice lives in gate-preflight.md'
assert_in gate-setup.md 'scripts/codex-review-dir' 'GATE_DIR helper lives in gate-setup.md'
assert_in gate-setup.md 'scripts/review-dossier' 'dossier assembly lives in gate-setup.md'
assert_in gate-lenses.md 'Round 1 is a lens fan-out' 'lens fan-out lives in gate-lenses.md'
assert_in gate-lenses.md 'Lens charters:' 'lens charter table lives in gate-lenses.md'
assert_in recipe-document.md 'Round-1 Algorithm Assessment (plan gate only)' 'algorithm assessment lives in recipe-document.md'
assert_in recipe-code.md 'launch detached, watch in the foreground' 'detached-launch discipline lives in recipe-code.md'
assert_in gate-output-schema.md '### Required document-review output' 'output schema lives in gate-output-schema.md'
assert_in gate-findings.md '## 4. Interpret — severity mapping' 'severity ladder lives in gate-findings.md'
assert_in gate-findings.md '## 4b. Completion check' 'completion check lives in gate-findings.md'
assert_in gate-fix-loop.md '## 5. Fix-and-re-review loop' 'fix loop lives in gate-fix-loop.md'
assert_in gate-fix-loop.md '## 6. Hand back' 'hand-back lives in gate-fix-loop.md'
assert_in gate-sweep.md '## 7. Review sweep' 'review sweep lives in gate-sweep.md'

# The index is a router, not a container: no section body may remain in it.
index="$GATE_DIR/codex-review-gate.md"
for needle in \
    '## 1. Preflight availability' \
    '## 3. Invoke Codex by artifact type' \
    '## 4. Interpret — severity mapping' \
    '## 5. Fix-and-re-review loop' \
    '## 7. Review sweep'; do
    if grep -Fq -- "$needle" "$index"; then
        fail "index no longer carries section bodies (found: $needle)"
    else
        pass "index no longer carries: $needle"
    fi
done

# Nothing over 150 lines — the whole point of the exercise.
for f in gate-preflight.md gate-setup.md gate-lenses.md recipe-document.md \
    recipe-code.md gate-output-schema.md gate-findings.md gate-fix-loop.md \
    gate-sweep.md; do
    if [ ! -f "$GATE_DIR/$f" ]; then
        fail "$f is under 150 lines (missing)"
        continue
    fi
    n="$(wc -l <"$GATE_DIR/$f" | tr -d ' ')"
    if [ "$n" -le 150 ]; then
        pass "$f is $n lines (<= 150)"
    else
        fail "$f is $n lines (> 150)"
    fi
done

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-placement.sh`
Expected: FAIL — every sibling is missing and the index still carries all section bodies.

- [ ] **Step 3: Extract the nine section files**

Do this mechanically from the manifest, not by hand. From the repo root:

```bash
GATE=skills/requesting-code-review/codex-review-gate.md
while IFS=$'\t' read -r dest start end; do
  case "$dest" in \#*|"") continue ;; esac
  sed -n "${start},${end}p" "$GATE" > "skills/requesting-code-review/$dest"
done < tests/codex-review-gate/gate-split-manifest.tsv
```

- [ ] **Step 4: Apply the eight rewrites**

Also mechanical, keyed by source line number — lines 229 and 244 are byte-identical, so text matching would corrupt one of them:

```bash
while IFS=$'\t' read -r src referent disposition replacement; do
  case "$src" in \#*|"") continue ;; esac
  [ "$disposition" = "rewrite" ] || continue
  while IFS=$'\t' read -r dest start end; do
    case "$dest" in \#*|"") continue ;; esac
    if [ "$src" -ge "$start" ] && [ "$src" -le "$end" ]; then
      offset=$((src - start + 1))
      awk -v n="$offset" -v repl="$replacement" \
        'NR==n { print repl; next } { print }' \
        "skills/requesting-code-review/$dest" > "$TMPDIR/gate-rewrite.$$" \
        && mv "$TMPDIR/gate-rewrite.$$" "skills/requesting-code-review/$dest"
    fi
  done < tests/codex-review-gate/gate-split-manifest.tsv
done < tests/codex-review-gate/gate-split-references.tsv
```

This uses the same `awk -v` substitution the verifier uses, which is what makes Task 2's byte-identity check meaningful — and also why the verifier asserts no replacement contains a backslash.

- [ ] **Step 5: Write the provisional index**

Replace the entire contents of `skills/requesting-code-review/codex-review-gate.md` with exactly this. Lines 1-9 are the original preamble, unchanged:

```markdown
# Codex Review Gate

A shared stage-gate that asks Codex (via codex-plugin-cc) to review an artifact
**after** Claude has done its own review/refine/fix pass and **before** the user
is re-engaged or the work is declared complete. Referenced by brainstorming,
writing-plans, subagent-driven-development, and requesting-code-review.

**Claude Code only.** Run this gate only under Claude Code. In any other harness,
skip it silently — do not run the preflight, do not emit the notice.

## Sections

| File | Contents |
|------|----------|
| [gate-preflight.md](gate-preflight.md) | §1 preflight availability; §2 no-Codex notice |
| [gate-setup.md](gate-setup.md) | §3 shared setup: `GATE_DIR`, dossier assembly, the foreground rule |
| [gate-output-schema.md](gate-output-schema.md) | §3 the Required document-review output block |
| [gate-lenses.md](gate-lenses.md) | §3 round-1 lens fan-out, charters, launch discipline |
| [recipe-document.md](recipe-document.md) | §3 spec and plan recipes; Round-1 Algorithm Assessment |
| [recipe-code.md](recipe-code.md) | §3 task, final, and ad-hoc code recipes |
| [gate-findings.md](gate-findings.md) | §4 severity mapping; §4b completion check |
| [gate-fix-loop.md](gate-fix-loop.md) | §5 fix-and-re-review loop and backstops; §6 hand back |
| [gate-sweep.md](gate-sweep.md) | §7 review sweep |
```

- [ ] **Step 6: Verify placement and losslessness**

Run:
```bash
bash tests/codex-review-gate/test-gate-placement.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
```
Expected: both `STATUS: PASSED`. The losslessness run now executes the per-file byte-identity block instead of skipping it — confirm you see `index preamble is byte-identical to source lines 1-10` plus nine `is byte-identical to source lines <start>-<end>` PASS lines, and no `[SKIP]`. That is 22 `[PASS]` lines in total (the twelve from the pre-split run, plus these ten).

The placement test prints each section file's line count as it checks the 150-line limit; `wc -l` the index yourself. These are the values the split produces, so a mismatch means Step 3 or Step 4 went wrong, not that the limit needs raising:

| File | Lines |
|------|-------|
| `codex-review-gate.md` (index) | 23 |
| `gate-preflight.md` | 90 |
| `gate-setup.md` | 76 |
| `gate-lenses.md` | 43 |
| `recipe-document.md` | 53 |
| `recipe-code.md` | 82 |
| `gate-output-schema.md` | 37 |
| `gate-findings.md` | 148 |
| `gate-fix-loop.md` | 149 |
| `gate-sweep.md` | 76 |

Task 4 grows the index to 46 lines when it adds the routing matrix. Nothing else changes size again.

- [ ] **Step 7: Update the two contract assertions the rewrites invalidate**

Two of the 119 assertions in `test-gate-contract.sh` pin text that lives inside a rewritten line, so they fail after Step 4. This was determined by running the split, not by reading — a careful reading missed it. Both needles are substrings of declared, proven rewrites, which is what makes editing them legitimate rather than the ad-hoc retargeting this plan otherwise forbids: Task 2's check 5 proves no line other than the eight moved, and its check 6 pins both the retired and the replacement strings.

Line numbers below are post-Task-1: Task 1 replaced line 6 with four lines, so everything after it shifted by three. Match on the needle text if the numbers have drifted further.

Edit `tests/codex-review-gate/test-gate-contract.sh:82`:

```bash
assert_contains "$GATE" "Copy the Required document-review output block from gate-output-schema.md into the prompt" \
  "document review prompts include the output schema in Codex context"
```

Edit `tests/codex-review-gate/test-gate-contract.sh:277`:

```bash
assert_contains "$GATE" "composes the per-lens prompts from the lens fan-out block in gate-lenses.md" \
  "doc-gate round 1 routes to the fan-out"
```

The descriptions are unchanged — the assertions still check the same two behaviors. Only the wording they match moved.

**These are the only two assertions that may change in this task.** If a third fails, the move dropped or altered content: fix the content, never the assertion.

- [ ] **Step 8: Verify behavior pinning still holds**

Run:
```bash
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/claude-code/test-codex-review-dir-path.sh
bash tests/codex-review-gate/test-assemble-gate.sh
```
Expected: all `STATUS: PASSED`, with the contract test reporting **119 passing assertions** — the same count as the Task 1 baseline.

- [ ] **Step 9: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md skills/requesting-code-review/gate-preflight.md skills/requesting-code-review/gate-setup.md skills/requesting-code-review/gate-lenses.md skills/requesting-code-review/recipe-document.md skills/requesting-code-review/recipe-code.md skills/requesting-code-review/gate-output-schema.md skills/requesting-code-review/gate-findings.md skills/requesting-code-review/gate-fix-loop.md skills/requesting-code-review/gate-sweep.md tests/codex-review-gate/test-gate-placement.sh tests/codex-review-gate/test-gate-contract.sh
git commit -m "refactor(gate): split codex-review-gate.md into a section library

766 lines, opened 970 times across 96 sessions, 87% of those opens partial —
mostly repeated head-of-file re-orientation in a document with no contents
listing. The size was not the problem; navigating it was.

The document keeps its path and becomes an index over nine section files, none
over 150 lines, so every caller still resolves and no caller changes. Content
moved verbatim except eight positional references whose referents crossed a
file boundary. Line accounting against the pre-split original proves the move.

Two of the 119 contract assertions pinned text inside a rewritten line and now
match the rewritten wording; the losslessness check pins both the retired and
the replacement strings so the edit stays auditable."
```

---

### Task 4: Routing matrix and topology test

The index is currently a contents listing. What removes the re-orientation reads is telling each caller exactly which files to load before it starts. The routes are *sets*, not sequences: the document's §-reference graph is cyclic (§3 references §5's round counter and §4b's recovery path; §4b references §3's watch loop in six places; §5 references §3's prompt and `GATE_DIR`), so no read order exists in which every reference points backwards. Loading the whole set up front is what makes that irrelevant.

**Risk tier:** standard — the routing table is the only new duplicated knowledge in the design, and a stale route sends a caller into a gate with missing context.

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md`
- Create: `tests/codex-review-gate/test-gate-topology.sh`

**Interfaces:**
- Consumes: the nine section files from Task 3.
- Produces: the seven-row caller matrix that Phase B Task 6 repoints against.

- [ ] **Step 1: Write the failing topology test**

Create `tests/codex-review-gate/test-gate-topology.sh`:

```bash
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

# 4. Every caller has a route. Fed by here-string, not a pipe: a piped `while`
#    runs in a subshell, so every failure it counted would be discarded.
while IFS= read -r caller; do
    if grep -Fq "| $caller |" "$INDEX"; then
        pass "route present for: $caller"
    else
        fail "route present for: $caller"
    fi
done <<<"$CALLERS"

# 5. Route cells name only files that exist. Route entries are backticked
#    basenames without the .md suffix. The backtick lives in a variable so
#    the pattern reads as a pattern rather than as an unterminated quote.
BT='`'
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-topology.sh`
Expected: `STATUS: FAILED (8 failures)` — checks 1-3 pass (Task 3 already satisfied them), check 4 fails once per caller (7), and check 5 adds `route cells parsed (got 0, expected at least 9)`. That last guard exists so an unparseable matrix can never make check 5 a silent no-op.

- [ ] **Step 3: Add the routing matrix to the index**

Append to `skills/requesting-code-review/codex-review-gate.md`, after the Sections table, separated from it by one blank line:

```markdown
## Routes

**Read your whole route before you start.** A route is a *set*, not a sequence.
The gate's §-references point in both directions — §3 names §5's round counter
and §4b's recovery path, §4b names §3's watch loop, §5 names §3's prompt and
`GATE_DIR` — so there is no order in which every reference points backwards.
Load the whole set first and every reference resolves against context you
already hold. Section files never send you to another file.

| Caller | Route |
|--------|-------|
| approach gate | `gate-preflight` |
| spec gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-document`, `gate-findings`, `gate-fix-loop` |
| plan gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-document`, `gate-findings`, `gate-fix-loop` |
| per-task code gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-code`, `gate-findings`, `gate-fix-loop` |
| final whole-branch gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-code`, `gate-findings`, `gate-fix-loop` |
| ad-hoc code review | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-code`, `gate-findings`, `gate-fix-loop` |
| review sweep | `gate-preflight`, `gate-sweep`, plus the route for the gate type each queued event records |

The approach gate's route is one file: its entire need is §1 and §2, which is
why they share a file. The sweep's route is conditional by design — it
dispatches by recorded gate type and inherits that type's route.
```

Routes are written out in full rather than as "same as spec gate" so the test can check every cell and a caller can read one row.

- [ ] **Step 4: Run the topology test to verify it passes**

Run: `bash tests/codex-review-gate/test-gate-topology.sh`
Expected: `STATUS: PASSED`, ending with `route cells parsed (9 distinct names)`. The index is now 46 lines. That is its final size.

- [ ] **Step 5: Re-run the full gate suite**

Run:
```bash
for t in tests/codex-review-gate/test-assemble-gate.sh \
         tests/codex-review-gate/test-gate-split-lossless.sh \
         tests/codex-review-gate/test-gate-placement.sh \
         tests/codex-review-gate/test-gate-topology.sh \
         tests/codex-review-gate/test-gate-contract.sh \
         tests/claude-code/test-codex-review-dir-path.sh; do
  echo "--- $t"; bash "$t" | tail -3
done
```
Expected: six `STATUS: PASSED`.

- [ ] **Step 6: Lint**

Run: `scripts/lint-shell.sh tests/codex-review-gate/test-gate-placement.sh tests/codex-review-gate/test-gate-topology.sh`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-topology.sh
git commit -m "feat(gate): give every caller a complete route from the index

A contents listing still leaves the agent deciding what to open, which is how
the head-of-file re-reading started. Each of the seven callers now gets a named
set of files to load before it acts. Sets, not sequences: the section graph is
cyclic, so no read order makes every reference point backwards.

The topology test asserts against the seven-caller list rather than a filename
grep — two callers reach the gate without naming it, so a grep-derived
expectation would under-count to five and pass while the matrix went stale."
```

---

### Task 5: Phase A release gate — live evals and read-shape baseline

Phase A authors no new eval scenarios and is not exempt from evals. Two existing scenarios run before and after; the pass criterion is unchanged verdicts across the pair.

**Risk tier:** standard — no code changes, but this is the gate that authorizes Phase B.

**Controller-run.** Live `quorum run` invocations launch agent CLIs in permissive modes and capture transcripts; per `evals/CLAUDE.md` they are trusted-maintainer operations. Do not delegate this task to a subagent — the controller runs it and records the result.

**Files:**
- No repository files change. Results are recorded in the execution ledger.

**Interfaces:**
- Consumes: the completed split (Tasks 3-4).
- Produces: a pass/fail decision that gates Tasks 6-7.

**`SUPERPOWERS_ROOT` is the entire difference between the two runs.** The commands below are otherwise identical, and that is not an oversight to correct — it is the mechanism. `evals/` is gitignored (`.gitignore:15`) and tracks zero files in this repo, so the baseline worktree will not contain an `evals/` tree at all. Both runs are therefore launched from the *same* `evals/` checkout, and the only thing that decides which plugin tree is under test is `SUPERPOWERS_ROOT`. Quorum does not auto-discover it (`evals/CLAUDE.md:139`); it is `required_env` in `evals/coding-agents/claude.yaml`, and every `needsSuperpowersRoot` setup-helper throws `setup-helpers: SUPERPOWERS_ROOT is not set` when it is missing (`evals/src/setup-helpers/cli.ts:51`). Export it explicitly in each step. If it is inherited from the ambient shell instead, both runs silently test the same tree and the gate proves nothing.

- [ ] **Step 1: Capture the pre-split baseline**

The baseline must come from the tree as it was before Task 3. Use a scratch worktree at the pinned SHA from Task 2 Step 1 rather than mutating the current tree:

```bash
git worktree add /tmp/gate-baseline <ORIGIN_SHA>
```

Then run both scenarios with `SUPERPOWERS_ROOT` pointed at that worktree, recording each verdict:

```bash
cd evals
export SUPERPOWERS_ROOT=/tmp/gate-baseline
echo "$SUPERPOWERS_ROOT"                      # must print /tmp/gate-baseline
test -d "$SUPERPOWERS_ROOT/.claude-plugin" || echo "NOT A PLUGIN ROOT — stop"
bun run quorum run scenarios/codex-gate-lens-fanout-compliance --coding-agent claude
bun run quorum run scenarios/codex-gate-incomplete-not-approval --coding-agent claude
```

Record both verdicts verbatim. If the harness cannot be run in this environment, say so explicitly and stop — do not infer or invent verdicts.

Two environment notes for the controller, both of which have wasted a run before. `claude.yaml` also lists `ANTHROPIC_API_KEY` in `required_env`; on a host authenticated through Vertex or Bedrock instead, use `--coding-agent claude-auto`, which detects the provider from the environment. And live runs launched from Claude Code's sandboxed shell die in scenario `setup.sh` at `git init` — launch these from a real terminal, or unsandboxed.

- [ ] **Step 2: Run the same two scenarios against the split tree**

Same commands, `SUPERPOWERS_ROOT` repointed at the working repo. Resolve the root **before** `cd evals` — `evals/` is a separate clone with its own `.git`, so `git rev-parse --show-toplevel` run from inside it returns `<repo>/evals`, which is not a plugin root and would fail every bootstrap check:

```bash
export SUPERPOWERS_ROOT="$(git rev-parse --show-toplevel)"   # from the repo root
echo "$SUPERPOWERS_ROOT"                      # must print the hyperpowers repo root, NOT .../evals and NOT /tmp/gate-baseline
cd evals
bun run quorum run scenarios/codex-gate-lens-fanout-compliance --coding-agent claude
bun run quorum run scenarios/codex-gate-incomplete-not-approval --coding-agent claude
```

- [ ] **Step 3: Compare and decide**

Pass criterion: both scenarios return the same verdict before and after. Any verdict change is a Phase A regression — stop, diagnose, and do not proceed to Phase B.

- [ ] **Step 4: Clean up the baseline worktree**

```bash
git worktree remove /tmp/gate-baseline
```

- [ ] **Step 5: Record the post-release measurement obligation**

This one cannot gate the merge — the risk it covers (agents slicing the new files out of habit) is only observable in production. Record it as follow-up work: after real use, re-run the read-shape measurement and confirm that the partial-read rate on the new files is well below the current 87%, and that no `sed -n '/## /,/## /p'`-style section slicing appears against the new filenames. Note it in the execution ledger; there is nothing to commit.

---

### Task 6: Phase B item 4 — flatten the brainstorming reference chain

Phase A makes this nearly free. `codex-approach-gate.md` is fork-only, and after the split its only dependency is `gate-preflight.md` — exactly the §1+§2 content it already cites. Repointing collapses `brainstorming/SKILL.md` → `codex-approach-gate.md` → `codex-review-gate.md` from three levels to two and shrinks the terminal target from 766 lines to ~90.

**Do not start until Task 5 passed.**

**Deviation from the spec, recorded deliberately.** The spec calls for a second edit — "`brainstorming/SKILL.md:286`, a one-line link change on an upstream file." That edit is **not performed**, because there is no correct target for it. Line 286 is the spec gate's link to the gate document, and the spec gate's route (Task 4's matrix) is seven files: `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-document`, `gate-findings`, `gate-fix-loop`. Repointing the link at any single section file would break the spec gate, and spelling the route out in the caller would duplicate the index's routing knowledge — the one thing Task 4's topology test exists to keep in exactly one place. The index at the unchanged path already *is* that route, so the link is already correct.

The chain still collapses for the path item 4 was measured on: the approach gate's terminal read drops from 766 lines to ~90. Only that edit ships.

**Risk tier:** standard — behavior-shaping skill edits on the live approach-gate path.

**Files:**
- Modify: `skills/brainstorming/codex-approach-gate.md:11`

**Interfaces:**
- Consumes: `gate-preflight.md` from Task 3.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Repoint the approach gate**

In `skills/brainstorming/codex-approach-gate.md`, line 11 currently reads:

> Run the §1 preflight from [../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md) (at most once per skill run; reuse the result). When preflight status is not `ok`, first emit the §1 per-status notice from codex-review-gate.md (which carries the status token, reason, and recovery command where applicable) — so this brainstorm proceeds without independent Codex approaches. For the `not-installed` case, add the §2 install lines from [../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md):

Replace all three occurrences of the gate document with `gate-preflight.md`:

> Run the §1 preflight from [../requesting-code-review/gate-preflight.md](../requesting-code-review/gate-preflight.md) (at most once per skill run; reuse the result). When preflight status is not `ok`, first emit the §1 per-status notice from gate-preflight.md (which carries the status token, reason, and recovery command where applicable) — so this brainstorm proceeds without independent Codex approaches. For the `not-installed` case, add the §2 install lines from [../requesting-code-review/gate-preflight.md](../requesting-code-review/gate-preflight.md):

Nothing else on the line changes. The §-numbers stay, which is why Task 3 kept them in the headings.

- [ ] **Step 2: Verify the section numbers still resolve**

Run: `grep -n '## 1\. Preflight availability\|## 2\. No-Codex notice' skills/requesting-code-review/gate-preflight.md`
Expected: both headings present, so "the §1 preflight" and "the §2 install lines" both land in the newly-named file.

- [ ] **Step 3: Run the affected tests**

Run:
```bash
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/codex-review-gate/test-gate-topology.sh
```
Expected: both PASS. The contract test reads `$APPROACH_GATE` for several assertions — if any fail, the repoint changed text it pins.

- [ ] **Step 4: Eval gate**

Controller-run, same constraints as Task 5 — including `SUPERPOWERS_ROOT`, which quorum never infers. Resolve it before `cd evals`, because `evals/` is a separate clone whose own `git rev-parse --show-toplevel` returns the wrong directory:

```bash
export SUPERPOWERS_ROOT="$(git rev-parse --show-toplevel)"   # from the repo root
echo "$SUPERPOWERS_ROOT"                      # must print the hyperpowers repo root
cd evals
bun run quorum run scenarios/codex-approach-gate-fires-on-architecture --coding-agent claude
bun run quorum run scenarios/codex-gate-spec-degrades-without-codex --coding-agent claude
```

If Task 5's baseline export is still live in this shell, these would run against `/tmp/gate-baseline` — a tree that predates every change in this plan — and pass while testing nothing. Check the `echo` before trusting the result.

Both must pass. A failure here means the repoint changed behavior — revert the step rather than adjusting the scenario.

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/codex-approach-gate.md
git commit -m "refactor(brainstorming): point the approach gate at gate-preflight.md

The approach gate needed only §1 and §2, and reached them through the whole
766-line gate document. After the split those two sections are one ~90-line
file, so the chain drops from three levels to two and the terminal read shrinks
by 88%. Section numbers are unchanged, so the prose still reads correctly."
```

---

### Task 7: Phase B item 6 — split `subagent-driven-development/SKILL.md`

706 lines, upstream, with 71 manual re-reads at roughly 7.5k tokens each. Those re-reads are the sharp signal: SKILL.md content is injected by the harness on skill trigger, so each one is a case where the agent already had the content and went back for it anyway. This is the highest merge-conflict surface in the program, which is why it goes last.

**Do not start until Tasks 5 and 6 passed.**

**Deviation from the spec, recorded deliberately.** The spec says these four extractions bring SKILL.md "under the 500-line guidance." They do not. The four section bodies total 160 lines (Model Selection 188-223, Risk Tiers 520-555, Common Rationalizations 618-634, Example Workflow 636-706) and the four stubs add 23, so SKILL.md lands at **569** lines. Measured, not estimated: the extraction was run against the real file.

Extracting `## Setup` (115-186, 72 lines) as well would give 569 − 72 + 5 = 502 — still over, and it would put a hop on a section every run needs. There is no version of this task that reaches 500 without gutting the main path, so take the 569 and record the miss. The guidance is a guideline; a hop on the main path is a real cost.

**Risk tier:** high — `## Risk Tiers (per-task Codex gate applicability)` is the text that authorizes skipping the per-task Codex gate. Relocating it wrongly would let tasks skip gates they should not.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (one assertion retargeted — see Step 4)
- Create: `skills/subagent-driven-development/model-selection.md`, `risk-tiers.md`, `common-rationalizations.md`, `example-workflow.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Extract the four sections verbatim**

From the repo root, working bottom-up so earlier line numbers stay valid:

```bash
SDD=skills/subagent-driven-development/SKILL.md
sed -n '636,706p' "$SDD" > skills/subagent-driven-development/example-workflow.md
sed -n '618,634p' "$SDD" > skills/subagent-driven-development/common-rationalizations.md
sed -n '520,555p' "$SDD" > skills/subagent-driven-development/risk-tiers.md
sed -n '188,223p' "$SDD" > skills/subagent-driven-development/model-selection.md
```

Each range stops one line short of the next `## ` heading: lines 224, 556, and 635 are the blank separators before `## The Task Loop`, `## Final Review`, and `## Example Workflow`. Leaving them in SKILL.md is what keeps the stubs from butting up against the following heading, and it keeps the reference files free of a stray trailing blank.

`## Common Rationalizations` is tuned behavior-shaping content. It moves verbatim — not reworded, not reformatted, not retitled.

- [ ] **Step 2: Replace each section with a stub**

Two of these are consulted on the main path, so their stubs carry the operative fact inline and the detail in the reference — otherwise the extraction just converts a re-read into a hop.

Work bottom-up here too, and replace exactly the ranges given — the same ranges that were extracted, so the separator blanks stay put.

Replace lines 636-706 with:

```markdown
## Example Workflow

A complete worked run, dispatch through finish:
[example-workflow.md](example-workflow.md).
```

Replace lines 618-634 with:

```markdown
## Common Rationalizations

The excuses that show up mid-run and what is actually true:
[common-rationalizations.md](common-rationalizations.md). Read it the moment you
catch yourself justifying a shortcut.
```

Replace lines 520-555 with:

```markdown
## Risk Tiers (per-task Codex gate applicability)

Tiers are `low`, `standard`, `high`, declared per task in the plan. Only an
EFFECTIVE-low task — declared low with no escalation trigger fired at any point
during execution — skips the per-task Codex gate, and the skip is recorded
durably. The Claude task reviewer and the final whole-branch train never tier
off. The escalation triggers, the fallback rules, and the exact ledger line
shape are in [risk-tiers.md](risk-tiers.md) — read it before dispatching any
task declared low.
```

Replace lines 188-223 with:

```markdown
## Model Selection

Match the model to the task's difficulty rather than defaulting; the per-role
guidance and the escalation rule are in
[model-selection.md](model-selection.md).
```

- [ ] **Step 3: Verify the line count and that nothing was lost**

Run:
```bash
wc -l skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/*.md
```
Expected, measured against the real file:

| File | Lines |
|------|-------|
| `SKILL.md` | 569 |
| `model-selection.md` | 36 |
| `risk-tiers.md` | 36 |
| `common-rationalizations.md` | 17 |
| `example-workflow.md` | 71 |

Also confirm each stub is followed by a blank line and then the next `## ` heading — `grep -n '^## ' skills/subagent-driven-development/SKILL.md` should list the same ten headings as before, at lines 19, 45, 115, 188, 194, 489, 499, 543, 560, 566.

Verify the extraction was verbatim by diffing each against the pre-edit file:

```bash
git show HEAD:skills/subagent-driven-development/SKILL.md > "$TMPDIR/sdd-before.md"
diff <(sed -n '636,706p' "$TMPDIR/sdd-before.md") skills/subagent-driven-development/example-workflow.md
diff <(sed -n '618,634p' "$TMPDIR/sdd-before.md") skills/subagent-driven-development/common-rationalizations.md
diff <(sed -n '520,555p' "$TMPDIR/sdd-before.md") skills/subagent-driven-development/risk-tiers.md
diff <(sed -n '188,223p' "$TMPDIR/sdd-before.md") skills/subagent-driven-development/model-selection.md
```
Expected: four empty diffs.

- [ ] **Step 4: Retarget the one contract assertion this extraction breaks**

Measured against the real file, not predicted: run `bash tests/codex-review-gate/test-gate-contract.sh` after Step 2 and it reports `STATUS: FAILED (1 failure(s))` — `[FAIL] SDD Red Flags echo the incomplete-is-not-approval rule`. Six of the suite's assertions target `$SDD`; exactly one of their needles sits inside an extracted range.

The assertion is `tests/codex-review-gate/test-gate-contract.sh:171-172`:

```bash
assert_contains "$SDD" "Treat an unfinished or \"still verifying\" Codex result as approval" \
  "SDD Red Flags echo the incomplete-is-not-approval rule"
```

Despite the description saying "Red Flags", the needle is a row of the `## Common Rationalizations` table (SKILL.md:632), which Step 1 moved to `common-rationalizations.md`. Point the assertion at the file that now holds the text. Add a path variable alongside the others at the top of the file, after line 9 (`SDD=...`):

```bash
SDD_RATIONALIZATIONS="$REPO_ROOT/skills/subagent-driven-development/common-rationalizations.md"
```

and change that one assertion's first argument from `"$SDD"` to `"$SDD_RATIONALIZATIONS"`. Leave the description string alone; it names the rule, not the file.

**Not an assembled view, and that is deliberate.** Task 1 built one for the gate because the gate index and its nine section files are a single document split apart, so the union is the document. `subagent-driven-development/SKILL.md` also links four prompt templates (`implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`, `fix-subagent-prompt.md`) that were never part of any split, so an assembled SDD would be a strictly larger and different union — and `test-gate-contract.sh:103` asserts *absence* against `$SDD`, which is exactly the kind of assertion whose meaning a wider union silently changes. One moved needle, one retarget.

**This is the only assertion that may change in this task.** If a second one fails, the extraction dropped or altered content: fix the content, never the assertion.

- [ ] **Step 5: Run the offline tests**

Run:
```bash
bash tests/claude-code/test-sdd-dir-path.sh
bash tests/codex-review-gate/test-gate-contract.sh
```
Expected: both `STATUS: PASSED`.

`tests/claude-code/test-subagent-driven-development.sh` and `test-subagent-driven-development-integration.sh` are deliberately **not** in this step. Both source `test-helpers.sh` and call `run_claude`, which launches a live Claude CLI session; the integration one drives a whole plan and runs for many minutes. They belong with the controller-run gate in the next step, not in a subagent's offline verification.

- [ ] **Step 6: Eval gate and live-agent tests**

Controller-run, same constraints as Task 5 — including `SUPERPOWERS_ROOT`, resolved before `cd evals` for the same reason:

```bash
export SUPERPOWERS_ROOT="$(git rev-parse --show-toplevel)"   # from the repo root
echo "$SUPERPOWERS_ROOT"                      # must print the hyperpowers repo root, not /tmp/gate-baseline
cd evals
bun run quorum run scenarios/sdd-unified-fix-loop --coding-agent claude
bun run quorum run scenarios/sdd-plan-scoped-scratch --coding-agent claude
bun run quorum run scenarios/sdd-rejects-extra-features --coding-agent claude
```

All three must pass. Watch specifically for tier-discipline regressions: if a run skips a gate it should not have, the `risk-tiers.md` stub is under-specified and the operative rules must come back inline.

Then the two live-agent bash tests deferred from Step 5, in the same controller session:

```bash
bash tests/claude-code/test-subagent-driven-development.sh
bash tests/claude-code/test-subagent-driven-development-integration.sh
```

Both launch real Claude CLI sessions and are slow; run them one at a time and wait, do not background them. The first string-matches the agent's verbal description of the skill against keywords like "self-review", "skeptical", "worktree", "Step 1", "loop" — it is the direct check on whether the four stubs still let an agent describe the skill correctly. The second executes a plan end-to-end.

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/model-selection.md skills/subagent-driven-development/risk-tiers.md skills/subagent-driven-development/common-rationalizations.md skills/subagent-driven-development/example-workflow.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "refactor(sdd): extract four reference sections from SKILL.md

706 lines with 71 manual re-reads. Because SKILL.md is injected on skill
trigger, every one of those is the agent going back for content it already had
— the sharpest available signal that the document is hard to navigate.

Model Selection, Risk Tiers, Common Rationalizations, and Example Workflow move
out verbatim. The Task Loop stays inline; it is the core of the skill. The two
stubs on the main path carry their operative rule inline so the extraction does
not trade a re-read for a hop. Lands at 569 lines rather than under 500: even
also extracting Setup would only reach 502, and Setup is needed every run."
```

---

### Task 8: Release

**Risk tier:** standard — the rubric's `low` is for single-file mechanical transcription where the plan carries the complete content to write. This touches six manifests plus `CHANGELOG.md`, and Step 3 asks the implementer to compose changelog prose the plan does not spell out.

**Files:**
- Modify: the six version manifests (via `vrzn`): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: all prior tasks.

- [ ] **Step 1: Confirm the whole offline suite is green**

Run:
```bash
for t in tests/codex-review-gate/test-*.sh \
         tests/claude-code/test-codex-review-dir-path.sh \
         tests/claude-code/test-sdd-dir-path.sh \
         tests/claude-code/test-worktree-path-policy.sh; do
  if bash "$t" >/dev/null 2>&1; then echo "PASS  $t"; else echo "FAIL  $t"; fi
done
```
Expected: 19 `PASS` lines and no `FAIL` — the 12 pre-existing `tests/codex-review-gate/test-*.sh` suites, the four this plan adds (`test-assemble-gate.sh`, `test-gate-split-lossless.sh`, `test-gate-placement.sh`, `test-gate-topology.sh`), and the three offline suites under `tests/claude-code/`. All 15 pre-existing ones were measured green on `main` before this plan was written, so any `FAIL` here is this branch's doing.

Two things about that loop are load-bearing, both learned by running the naive version:

- **`test-*.sh`, not `*.sh`.** A bare `tests/codex-review-gate/*.sh` glob picks up `assemble-gate.sh`, which exits non-zero when called with no arguments. On the `tests/claude-code/` side a bare glob is worse: it picks up `test-helpers.sh`, a sourced helper that exits 0 without asserting anything (a vacuous pass), plus `run-skill-tests.sh`, `test-subagent-driven-development.sh`, `test-subagent-driven-development-integration.sh`, and `test-worktree-native-preference.sh` — all four launch live agent CLI sessions and will hang an offline run.
- **Exit status, not output text.** There is no single success string to grep for. Nine of the nineteen print `STATUS: PASSED` — `test-codex-available`, `test-gate-contract`, `test-codex-review-dir-path`, `test-sdd-dir-path`, `test-worktree-path-policy`, and this plan's four new suites. The other ten print `ALL PASS`. Every suite sets its exit code correctly, so that is the uniform signal.

The live-agent tests are not part of this step. They ran under Task 7 Step 6; if that gate was skipped, say so in the release notes rather than quietly treating this step as full coverage.

- [ ] **Step 2: Bump the version**

`vrzn` is not on `PATH` in this environment; call it by absolute path.

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn get
```
Expected: a six-row table, every row reporting the same new version (6.9.2 → 6.10.0), ending in `All version numbers are consistent.` Do not hand-edit any version string.

`vrzn.toml`'s header comment says "Seven manifests" and `.version-bump.json` lists six; the config's own `[[locations]]` blocks are the authority and there are **six**. Do not go looking for a seventh, and do not "fix" the stale comment here — that is an unrelated edit.

- [ ] **Step 3: Add the changelog entry**

Follow the existing `CHANGELOG.md` format. Describe the problem solved, not just the change: the gate document was opened 970 times across 96 sessions with 87% partial reads, and it is now an index over nine sub-150-line section files with a route per caller.

- [ ] **Step 4: Commit**

Global Constraint: stage only the named files. `git add -u` would sweep in anything else the working tree happens to be carrying.

```bash
git add package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json CHANGELOG.md
git commit -m "Release <version>: route the Codex gate instead of re-reading it"
```

Run `git status --short` afterward. Anything still unstaged should be either untracked scratch or the uncommitted `docs/hyperpowers/` plan and spec, which are never committed.

---

## Verification summary

| Check | File | Proves |
|---|---|---|
| Line accounting | `test-gate-split-lossless.sh` | Nothing lost, nothing duplicated, nothing silently reworded |
| Placement | `test-gate-placement.sh` | The split actually distributed content; nothing over 150 lines |
| Topology | `test-gate-topology.sh` | Index reaches everything; no section-to-section links; all seven routes valid |
| Behavior pinning | `test-gate-contract.sh` (96 of its 119 assertions target the gate) | The invariants that matter are still stated somewhere in the gate |
| Assembler correctness | `test-assemble-gate.sh` | The view the two grep-based suites read is the real union, and a dangling link is a hard error rather than a silent omission |
| Scratch-dir regression | `test-codex-review-dir-path.sh` | The `codex-review-dir` helper contract survived the move |
| Live evals | quorum, Tasks 5-7 | Verdicts unchanged before and after |

The contract test is a behavior guard, not a losslessness proof: `assert_contains` collapses newlines, tabs, and repeated spaces before matching selected substrings (`test-gate-contract.sh:18-31`), so it would still pass after whitespace changes, reordering, duplication, or the loss of any line no assertion pins. Line accounting is what proves the move.
