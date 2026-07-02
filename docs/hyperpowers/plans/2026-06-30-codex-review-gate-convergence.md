# Codex Review Gate Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Codex⇄Claude review gate converge (round ledger), restructure its cap (convergence stop-rule + per-gate backstops docs=4/code=3), and add an "incomplete ≠ approve" completion contract grounded in the foreground-only `adversarial-review` path.

**Architecture:** All behavior lives in one shared contract file, `skills/requesting-code-review/codex-review-gate.md`; the four caller skills (`brainstorming`, `writing-plans`, `subagent-driven-development`, `requesting-code-review`) reference it and get light touch-ups. Changes are markdown + one bash test file. Verification is the existing doc-contract harness `tests/codex-review-gate/test-gate-contract.sh`, which whitespace-normalizes each file and asserts substring presence/absence. The "test-first" cycle is: add the contract assertion, run the harness, watch it fail, edit the doc, run again, watch it pass, commit.

**Tech Stack:** Markdown skill content; Bash test harness (`assert_contains`/`assert_not_contains`); `shellcheck` for the test script; `scripts/bump-version.sh` + `.version-bump.json` for the release bump.

## Global Constraints

- Source of truth for all decisions: `docs/hyperpowers/specs/2026-06-30-codex-review-gate-convergence-design.md`. Copy values from it verbatim.
- Per-gate backstops: **document gates = 4 rounds, code gates = 3 rounds.** Convergence stop-rule may end the loop earlier.
- Blocking = Critical + Important. Severity map unchanged (critical→Critical, high→Important, medium/low→Minor).
- **No changes to `codex-plugin-cc`** (the companion script). `adversarial-review` is foreground-only; only `task` supports `--background`. `waitTimedOut`/240s belongs to `status --wait`, NOT to the review command. The gate doc must not instruct `--background` for code gates.
- "Incomplete" Codex result is a distinct third outcome — NEVER treated as approval.
- Re-review preamble may raise any genuinely new **blocking (Critical or High)** finding regardless of regression status; excludes only Minor on re-review.
- Preserve the deliberately-tuned voice ("your human partner", Red Flags tables, rationalization lists). Do not reword tuned content beyond what these tasks require.
- The test harness is run directly: `bash tests/codex-review-gate/test-gate-contract.sh`. Expected terminal output on success is `STATUS: PASSED`; on failure `STATUS: FAILED (N failure(s))` with exit 1.
- Do NOT commit the spec or plan documents. Commit only the skill/test/manifest changes the tasks produce.
- Skill-behavior evals are a release gate (see Task 7); they are not a code task here but block release.

---

### Task 1: Rewrite the shared gate §5 — round ledger, convergence stop-rule, per-gate backstops

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§5, currently lines 162-173: "## 5. Fix-and-re-review loop (cap = 2 rounds)")
- Test: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks (first task).
- Produces: a rewritten `## 5.` section whose heading is `## 5. Fix-and-re-review loop (converge, then stop)`, containing a per-gate backstop table, a convergence stop-rule, the prose "Document gates get 4 rounds" / "Code gates get 3 rounds", and a round-ledger subsection titled `### Round ledger (re-review memory)`. Later tasks (2, 4, 5) reference these section/anchor names.

- [ ] **Step 1: Add the failing contract assertions to the harness**

In `tests/codex-review-gate/test-gate-contract.sh`, immediately after the existing block that ends with the `assert_contains "$GATE" "After any code fix, re-run the same Claude reviewer gate before re-running Codex." \` assertion and its description line (the line `"code fix loop requires Claude re-review before Codex re-review"`), add:

```bash
# --- Task 1: convergence loop + per-gate backstops + round ledger ---
assert_contains "$GATE" "### Round ledger (re-review memory)" \
  "gate defines a round ledger for re-review memory"
assert_contains "$GATE" "no new blocking findings" \
  "gate defines a convergence stop-rule"
assert_contains "$GATE" "Document gates get 4 rounds" \
  "gate sets the document-gate backstop to 4 rounds"
assert_contains "$GATE" "Code gates get 3 rounds" \
  "gate sets the code-gate backstop to 3 rounds"
assert_not_contains "$GATE" "## 5. Fix-and-re-review loop (cap = 2 rounds)" \
  "gate no longer uses the single 2-round cap heading"
```

- [ ] **Step 2: Run the harness to verify the new assertions fail**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: FAIL — `STATUS: FAILED (5 failure(s))` (the four new `assert_contains` fail because the strings are absent; the `assert_not_contains` fails because the old heading is still present). Exit code 1.

- [ ] **Step 3: Replace §5 in the gate doc**

In `skills/requesting-code-review/codex-review-gate.md`, replace the entire section from the line `## 5. Fix-and-re-review loop (cap = 2 rounds)` through the line ending `do not loop indefinitely.` (current lines 162-173) with:

```markdown
## 5. Fix-and-re-review loop (converge, then stop)

After the first Codex review, every later round is a **re-review against known
state**, not a cold re-derivation. The loop ends as soon as the work is actually
done — it does not burn a fixed attempt budget.

### Round ledger (re-review memory)

Before re-running Codex (round 2+), write a small handoff file next to the other
gate artifacts (e.g. `…/codex-round-ledger.md`). Do not paste it into your own
context — hand it over as a file path. For each completed round it records:

- **Resolved** — each blocking finding and how it was addressed, with the fix
  commit/diff reference (code) or the spec/plan edit (documents).
- **Declined** — each finding you declined, with the explicit reasoning (the
  decision below to decline a finding, carried forward instead of lost).
- **Still open** — any blocking finding not yet resolved, and why.

Each later round appends a new section; the ledger is the cumulative record.

The round 2+ invocation prepends a round-aware preamble to the §3 prompt:

> This is re-review round N. The prior-round findings and how each was resolved
> or declined are in `<LEDGER_PATH>`. Confirm the resolved findings are actually
> fixed. Do not re-raise a finding listed as declined unless you can show the
> stated reasoning is wrong. You may raise any genuinely new **blocking
> (Critical or High)** finding — whether or not it is a regression — provided it
> is not already listed as resolved and not a declined item without a new
> argument. Do not raise new Minor (medium/low) findings on a re-review.

The bar on re-review is "new and blocking," not "new and a regression": a
newly-noticed Critical or High issue is still blocking even if it predates round
1. What is excluded on re-review is Minor noise, not new blocking severity.

### The loop

1. If verdict is `approve` and there are no blocking findings → done; go to step 6.
2. Otherwise address each blocking finding: for a document, edit the spec/plan; for
   code, dispatch a fix through the skill's existing fix path (e.g. SDD's fix
   subagent). You MAY decline a finding with explicit reasoning instead of fixing it.
   Record resolutions, declines, and still-open items in the round ledger.
   After any code fix, re-run the same Claude reviewer gate before re-running Codex.
3. Re-run the same Codex invocation (with the round-aware preamble and ledger
   path) over the updated artifact once the relevant Claude review gate is clean.
4. **Stop when any holds:**
   - **Approved** — `approve` with no blocking findings.
   - **Converged** — the round produced **no new blocking findings**: everything
     it raised is already-resolved (confirmed via the ledger) or a
     previously-declined item with no new argument. This is a fixed point; stop
     even if the backstop is not reached.
   - **Backstop hit** — the per-gate round ceiling below is reached. Stop and
     hand back with any unresolved blocking findings listed; do not loop
     indefinitely.

### Per-gate round backstops

| Gate | Recipe | Backstop |
|------|--------|----------|
| Spec / Plan (document gates) | task | 4 |
| Per-task / final / code-review (code gates) | adversarial-review | 3 |

Document gates get 4 rounds (cheap: a text edit + a `task` re-run). Code gates
get 3 rounds (expensive: fix subagent + Claude-reviewer re-run + a fresh
`adversarial-review` per round). Convergence usually stops the loop earlier; the
backstop is a true backstop, not the common exit.
```

- [ ] **Step 4: Run the harness to verify these assertions pass**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the five Task-1 assertions now PASS. (Other assertions unaffected. If unrelated assertions fail, they belong to a later task — do not "fix" them here.)

- [ ] **Step 5: Lint the test script**

Run: `shellcheck tests/codex-review-gate/test-gate-contract.sh`
Expected: no errors (exit 0).

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "Add convergence loop and per-gate backstops to Codex review gate"
```

---

### Task 2: Add the "incomplete ≠ approve" completion contract to the shared gate

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (insert a new section between §4 "Interpret — severity mapping" and the rewritten §5 from Task 1)
- Test: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: the §5 structure produced by Task 1 (the new section sits directly before §5).
- Produces: a section heading `## 4b. Completion check — incomplete is not approval` containing the literal phrases `incomplete is not approval`, `foreground`, `status`, and `result`, plus a Red Flag line. Task 4 (SDD) and Task 5 (manifests) do not depend on this; Task 3 (caller skills) references it by name.

- [ ] **Step 1: Add the failing contract assertions to the harness**

In `tests/codex-review-gate/test-gate-contract.sh`, immediately after the Task-1 block you added, add:

```bash
# --- Task 2: completion check (incomplete is not approval) ---
assert_contains "$GATE" "## 4b. Completion check — incomplete is not approval" \
  "gate has a completion-check section"
assert_contains "$GATE" "incomplete is not approval" \
  "gate states incomplete is not approval"
assert_contains "$GATE" "foreground-only" \
  "completion check is grounded in the foreground-only review path"
assert_contains "$GATE" "There is no background path for code gates" \
  "gate states there is no background path for code gates"
assert_contains "$GATE" "600000 ms (10 minutes)" \
  "completion check pins a concrete review timeout"
assert_contains "$GATE" ".storedJob.result.result" \
  "completion check pins the concrete result JSON field"
```

- [ ] **Step 2: Run the harness to verify the new assertions fail**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: FAIL — all six new `assert_contains` fail (strings absent). Net: 6 new failures.

- [ ] **Step 3: Insert the completion-check section**

In `skills/requesting-code-review/codex-review-gate.md`, after the line `**Blocking = Critical + Important.** Minor findings are noted, not fixed in the loop.` (end of §4, current line 160) and before the §5 heading, insert:

```markdown
## 4b. Completion check — incomplete is not approval

A Codex result has three outcomes, not two: *approve*, *blocking findings*, and
**incomplete**. An incomplete result carries no verdict and must never be read as
approval or as "no findings."

**Why this matters (grounding).** The code recipes call `adversarial-review`,
which runs **foreground-only**: `handleReviewCommand` always calls
`runForegroundCommand`; only the `task` command has a background-launch path. The
companion's 240s `waitTimedOut` deadline belongs to `status --wait`, not to the
review command. On a long review the harness's own command/tool timeout can abort
the blocking call before a verdict arrives, leaving partial trace output and no
terminal result.

**A code-review result is incomplete when any hold:**

- the invocation is aborted by the harness command/tool timeout before returning,
- the process exits non-zero,
- the `--json` payload has no terminal verdict / no structured `result` payload,
- the rendered text reads as in-progress ("still verifying", "continuing to
  review", partial findings with no verdict).

**Required handling:**

1. Do not interpret an incomplete result as approval, and do not interpret it as
   findings. Treat it as "review not yet known."
2. Give the review room, then recover best-effort, bounded:
   - invoke the review under an explicit command timeout of **600000 ms (10
     minutes)** so a normal-length review (typically 2–4 minutes) is not aborted
     mid-flight;
   - if it still returns without a terminal verdict, recover without re-running
     the review — review jobs are tracked on disk. Find the most recent review
     job with `status --json`, whose snapshot exposes `running` (active jobs),
     `latestFinished`, and `recent` (each job carries `id` and
     `jobClass: "review"`) — there is no flat `jobs[]` array. Poll a specific job
     with `status <job-id> --json` and read `.job.status`. Read the stored review
     payload with `result <job-id> --json`: the parsed verdict/findings are at
     `.storedJob.result.result`, and the raw review text at
     `.storedJob.result.rawOutput` or `.storedJob.result.codex.stdout`. The
     authoritative signals are `.job.status` (`queued`/`running` = not done;
     `completed`/`failed`/`cancelled` = terminal) and the
     `.storedJob.result.result` payload;
   - if `.job.status` is still `running`, wait ~30s and re-query, up to **2
     additional poll cycles**. A poll cycle is not a review round — it does not
     consume the §5 convergence/backstop budget.
3. If still incomplete after the bounded recovery, hand back to the user as
   "Codex review did not complete (still running / aborted before verdict)" —
   never silently pass. Like every other gate failure this degrades to "no Codex
   review," not "Codex approved."

There is no background path for code gates: adding background launch to
`adversarial-review` would require changing `codex-plugin-cc`, which is out of
scope. The mitigation for slow reviews is the generous explicit timeout plus the
best-effort recovery above — not `--background`. Synchronous `task` document
gates are short and unaffected.

> **Red Flag — Never** treat an unfinished, timed-out, or "still verifying"
> Codex result as "no findings" / approval. Incomplete is not a pass. Recover via
> `status`/`result` or surface it — do not infer a verdict Codex did not give.
```

- [ ] **Step 4: Run the harness to verify these assertions pass**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the six Task-2 assertions PASS. The `There is no background path for code gates` assertion is the harness guard that the gate never instructs `--background` for code gates; `600000 ms (10 minutes)` and `.storedJob.result` guard the concrete recovery contract. Other assertions unaffected.

- [ ] **Step 5: Lint the test script**

Run: `shellcheck tests/codex-review-gate/test-gate-contract.sh`
Expected: no errors (exit 0).

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "Add incomplete-is-not-approval completion contract to Codex review gate"
```

---

### Task 3: Update §6 hand-back and the §3 re-review prompt cross-reference

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§6, current lines 175-185; and the §3 document-recipe prompt blocks)
- Test: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: §5 round-ledger naming (Task 1) and §4b completion outcome (Task 2).
- Produces: a §3 cross-reference pointing the recipes at the §5 round-aware preamble, and a §6 hand-back reporting the loop exit reason (`convergence` or `backstop`) and any incompletion. No new section headings.

- [ ] **Step 1: Add the failing contract assertions to the harness**

After the Task-2 block, add:

```bash
# --- Task 3: §3 references the round-aware preamble; hand-back reports exit reason + incompletion ---
assert_contains "$GATE" "On a re-review (round 2+), prepend the round-aware preamble from §5" \
  "§3 recipes point at the §5 round-aware re-review preamble"
assert_contains "$GATE" "whether the loop exited by convergence or by hitting the backstop" \
  "hand-back reports the loop exit reason"
assert_contains "$GATE" "whether an incomplete result occurred" \
  "hand-back reports incompletion"
```

- [ ] **Step 2: Run the harness to verify failure**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: FAIL — 3 new failures (strings absent).

- [ ] **Step 3: Add the §3 cross-reference to the round-aware preamble**

In `skills/requesting-code-review/codex-review-gate.md`, after the §3 intro
paragraph (current lines 48-49, ending `...not copy it.`) and before the
`**Spec documents**` recipe heading, insert this paragraph:

```markdown
On a re-review (round 2+), prepend the round-aware preamble from §5 (Round
ledger) to the prompt below and pass the ledger path, so Codex confirms prior
resolutions instead of re-reviewing cold. The first round uses the prompt as-is.
```

- [ ] **Step 4: Update §6 hand-back**

In `skills/requesting-code-review/codex-review-gate.md`, replace the §6 bullet list (the lines from `- Codex verdict (and round count if it looped),` through `- any unresolved blocking findings if the cap was hit.`) with:

```markdown
- Codex verdict, the round count, and whether the loop exited by convergence or
  by hitting the backstop,
- what Codex flagged (by mapped severity),
- what was fixed,
- what was declined and why,
- any unresolved blocking findings if the backstop was hit,
- whether an incomplete result occurred and how it was resolved (recovered via
  `status`/`result`, or surfaced to the user).
```

- [ ] **Step 5: Run the harness to verify pass**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the three Task-3 assertions PASS. Note: the old string `cap was hit` is replaced by `backstop was hit`; confirm no other assertion depended on `cap was hit` (none does in the current harness).

- [ ] **Step 6: Lint the test script**

Run: `shellcheck tests/codex-review-gate/test-gate-contract.sh`
Expected: no errors (exit 0).

- [ ] **Step 7: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "Report loop exit reason and incompletion in Codex gate hand-back"
```

---

### Task 4: Update SDD — caps, completion Red Flag, continue-between-tasks interaction

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (§"Codex Review Gate", current lines 223-248; and Red Flags `**Never:**` list, current lines 400-420)
- Test: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: the §5 backstop terms (Task 1) and the §4b Red Flag (Task 2).
- Produces: SDD text naming `code gates = 3` and echoing the incomplete-≠-approve Red Flag.

- [ ] **Step 1: Add the failing contract assertions to the harness**

After the Task-3 block, add:

```bash
# --- Task 4: SDD references new caps + completion Red Flag ---
assert_contains "$SDD" "code-gate backstop of 3 rounds" \
  "SDD names the code-gate backstop of 3 rounds"
assert_contains "$SDD" "Treat an unfinished or \"still verifying\" Codex result as approval" \
  "SDD Red Flags echo the incomplete-is-not-approval rule"
```

- [ ] **Step 2: Run the harness to verify failure**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: FAIL — 2 new failures.

- [ ] **Step 3: Update the SDD Codex section's closing paragraph**

In `skills/subagent-driven-development/SKILL.md`, replace the paragraph (current lines 247-248):

```markdown
The gate's round cap bounds the loop; if it is hit with unresolved blocking
findings, surface them rather than looping.
```

with:

```markdown
The gate's convergence stop-rule and per-gate backstop bound the loop (code
gates use a code-gate backstop of 3 rounds); if the backstop is hit with
unresolved blocking findings, surface them rather than looping. A per-task gate
that hits its backstop with unresolved blocking findings follows the existing
hand-back rule — it does not silently continue: route it through the same
BLOCKED-escalation path that governs whether execution pauses between tasks.
```

- [ ] **Step 4: Add the completion Red Flag to SDD's Never list**

In the `**Never:**` list under `## Red Flags`, after the line `- Re-dispatch a task the progress ledger already marks complete — check` and its continuation `  the ledger (and \`git log\`) after any compaction or resume`, add:

```markdown
- Treat an unfinished or "still verifying" Codex result as approval — incomplete
  is not a pass; recover via `status`/`result` or surface it
```

- [ ] **Step 5: Run the harness to verify pass**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the Task-4 assertions PASS.

- [ ] **Step 6: Lint and commit**

Run: `shellcheck tests/codex-review-gate/test-gate-contract.sh`
Expected: no errors.

```bash
git add skills/subagent-driven-development/SKILL.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "Point SDD gates at new caps and completion Red Flag"
```

---

### Task 5: Light touch-ups in brainstorming, writing-plans, requesting-code-review

**Files:**
- Modify: `skills/brainstorming/SKILL.md` (Codex Spec Review Gate, current lines 124-133)
- Modify: `skills/writing-plans/SKILL.md` (Codex Plan Review Gate, current lines 157-167)
- Modify: `skills/requesting-code-review/SKILL.md` (Codex review gate section, current lines 48-56)
- Test: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: the shared-gate behavior (Tasks 1-3). These callers defer to the gate doc; they only need to name the document backstop / completion handling so a reader of the skill knows it applies.
- Produces: each caller references the new contract. No new shared interfaces.

- [ ] **Step 1: Add the failing contract assertions to the harness**

After the Task-4 block, add:

```bash
# --- Task 5: caller skills reference the new contract ---
assert_contains "$BRAINSTORMING" "document-gate backstop of 4 rounds" \
  "brainstorming names the document-gate backstop"
assert_contains "$WRITING_PLANS" "document-gate backstop of 4 rounds" \
  "writing-plans names the document-gate backstop"
assert_contains "$REQUESTING_REVIEW" "Incomplete Codex results are never treated as approval" \
  "requesting-code-review names the completion contract"
```

- [ ] **Step 2: Run the harness to verify failure**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: FAIL — 3 new failures.

- [ ] **Step 3: Touch up brainstorming**

In `skills/brainstorming/SKILL.md`, in the Codex Spec Review Gate paragraph, change the sentence ending `...before the user review; if Codex is absent, emit the` so the clause reads (replace `resolve blocking findings in the fix loop before the user review`):

```markdown
resolve blocking findings in the convergence fix loop (document-gate backstop of
4 rounds) before the user review
```

- [ ] **Step 4: Touch up writing-plans**

In `skills/writing-plans/SKILL.md`, in the Codex Plan Review Gate paragraph, replace `and resolve blocking findings in\nthe fix loop before the execution handoff` with:

```markdown
and resolve blocking findings in the convergence fix loop (document-gate backstop
of 4 rounds) before the execution handoff
```

- [ ] **Step 5: Touch up requesting-code-review**

In `skills/requesting-code-review/SKILL.md`, in the `**4. Codex review gate (Claude Code only):**` paragraph, after the sentence that ends `...then resolve Codex blocking findings in the fix loop.` add:

```markdown
Incomplete Codex results are never treated as approval — recover or surface them
per the gate's completion check.
```

The harness uses case-sensitive `grep -F`; the inserted sentence must begin with a capital `I` to match the Step-1 needle `Incomplete Codex results are never treated as approval` exactly.

- [ ] **Step 6: Run the harness to verify pass**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the Task-5 assertions PASS. The existing assertions `assert_contains "$BRAINSTORMING" "using the spec recipe"` and `assert_contains "$WRITING_PLANS" "using the plan recipe"` must still PASS — do not remove those phrases when editing.

- [ ] **Step 7: Lint and commit**

Run: `shellcheck tests/codex-review-gate/test-gate-contract.sh`
Expected: no errors.

```bash
git add skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/requesting-code-review/SKILL.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "Reference convergence caps and completion contract in caller skills"
```

---

### Task 6: Version bump 6.0.5 → 6.0.6

**Files:**
- Modify (via script): all paths in `.version-bump.json` (`package.json`, `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.kimi-plugin/plugin.json`, `.claude-plugin/marketplace.json` field `plugins.0.version`, `gemini-extension.json`)

**Interfaces:**
- Consumes: nothing. Run last so the bump reflects the completed change.
- Produces: version `6.0.6` across all manifests.

- [ ] **Step 1: Confirm the current baseline version**

Run: `bash scripts/bump-version.sh --check`
Expected: every declared file reports `6.0.5` with no drift. If a file reports something else, STOP and reconcile before bumping — do not hard-code `6.0.5`; the real baseline is whatever `--check` reports.

- [ ] **Step 2: Bump to the next patch version**

Run: `bash scripts/bump-version.sh 6.0.6`
Expected: each declared file updated from `6.0.5` to `6.0.6`.

- [ ] **Step 3: Audit for stragglers**

Run: `bash scripts/bump-version.sh --audit`
Expected: `--check` shows all declared files at `6.0.6` with no drift. Note: `--audit` greps the repo for the *current* version string (`6.0.6` after the bump) to find undeclared files that mention it — it does NOT scan for the old `6.0.5`. Treat its output as a check that no undeclared file is still pinned to a version; it is not a stale-version sweep.

- [ ] **Step 3b: Explicitly sweep for the stale version**

Run: `grep -rn "6\.0\.5" . --include='*.json' --include='*.md' --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=evals --exclude-dir=docs`
Expected: no matches outside intentional history references (`CHANGELOG.md`, `RELEASE-NOTES.md`, `.upstream-version.json` may legitimately reference older versions — inspect any hit before editing). The spec and plan under `docs/` are excluded because they reference `6.0.5` as the documented baseline. If any *declared* manifest still shows `6.0.5`, the bump in Step 2 was incomplete — re-run it.

- [ ] **Step 4: Run the full gate-contract test once more**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: `STATUS: PASSED`.

- [ ] **Step 5: Commit**

```bash
git add package.json .claude-plugin/plugin.json .cursor-plugin/plugin.json .codex-plugin/plugin.json .kimi-plugin/plugin.json .claude-plugin/marketplace.json gemini-extension.json
git commit -m "Bump version 6.0.5 -> 6.0.6"
```

---

### Task 7: Skill-behavior eval evidence (release gate — not a code commit)

**Files:**
- Reference: `evals/` (hyperpowers-evals harness) and/or manual transcripts kept with the change.

**Interfaces:**
- Consumes: the completed skill changes (Tasks 1-5).
- Produces: before/after evidence required by the contributor guide ("Skill Changes Require Evaluation"). This task gates *release*, not the implementation commits.

- [ ] **Step 1: Run (or document) the slow/partial-result scenario**

Run the eval (or a manual harness session from a real terminal — the REPL sandbox cannot complete live quorum runs) where Codex returns a partial/aborted result.
Expected: Claude treats it as incomplete (recovers via `status`/`result` or surfaces it), and does NOT record it as approval. Capture the transcript.

- [ ] **Step 2: Run (or document) the moving-target scenario**

Run a scenario where round 2 surfaces only already-resolved/declined findings.
Expected: the convergence stop-rule ends the loop (no needless extra rounds). Capture the transcript.

- [ ] **Step 3: Capture before/after round-count evidence**

For a re-review that previously hit the 2-round cap, record the round count before and after this change.
Expected: documented improvement (fewer wasted rounds / clean convergence).

- [ ] **Step 4: Record the evidence with the change**

Save the transcripts/results as the before/after evidence the contributor guide requires. If live quorum runs cannot be completed in the implementation environment, the documented manual transcripts on at least one harness are the acceptable substitute. **Release does not proceed without one or the other.**

---

## Notes for the executor

- This plan edits behavior-shaping skill content. Do NOT reword tuned content (Red Flags, "human partner" language, rationalization tables) beyond the specific edits each task names.
- The doc-contract harness is intentionally substring-based and whitespace-normalized. When an assertion's needle spans lines in the doc, the harness collapses whitespace, so multi-line prose still matches a single-line needle — but match the exact words and case.
- After every doc edit, the matching harness run is the proof. Never mark a step done without the expected harness output.
- The spec and plan files themselves are not committed.
