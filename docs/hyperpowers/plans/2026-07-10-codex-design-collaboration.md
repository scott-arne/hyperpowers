# Codex Design Collaboration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two conditional Codex collaborations to the design pipeline — blind approach generation during brainstorming, and a round-1-only algorithm assessment with ledger lock in the plan gate.

**Architecture:** Feature 1 lives in a new brainstorming companion doc (`codex-approach-gate.md`, the `visual-companion.md` precedent) with three small hooks in `brainstorming/SKILL.md`; Feature 2 extends the shared gate doc's plan recipe (§3) and round-ledger loop (§5) plus one sentence in `writing-plans/SKILL.md`. Both are Claude-Code-only, reuse the gate doc's §1 probe/§2 degrade policy by reference, and degrade to today's behavior when Codex is absent.

**Tech Stack:** Markdown skill/companion docs; `tests/codex-review-gate/test-gate-contract.sh` (bash string-assertion contract test); `bun`/quorum scenarios in `evals/`; `scripts/bump-version.sh`.

**Source spec:** `docs/hyperpowers/specs/2026-07-10-codex-design-collaboration-design.md` (approved, Codex-gated — carries full rationale and the adjudication-ordering contract).

**Branch:** `feat/codex-design-collaboration` (already created off `main` @ 4df3219).

## Global Constraints

Every task's requirements implicitly include this section.

- **Trigger rule (verbatim intent):** the approach gate FIRES when there are ≥2 genuinely different viable architectures/algorithms/data models with materially different tradeoffs, or when your human partner explicitly requests Codex input (any phrasing, even for a trivial-looking task); it SKIPS silently for trivial/mechanical tasks (single obvious implementation, config change, small fix).
- **Blindness:** the approach-gate handoff contains the original idea verbatim, the clarifying Q&A, and codebase *facts* — and explicitly EXCLUDES Claude's own candidate approaches.
- **One-shot:** the approach gate has no fix loop, no ledger, no re-review; incomplete/failed → "no Codex input," noted once, never blocking.
- **Advisory, not blocking:** algorithm suggestions do not map onto the Critical/Important ladder and never drive the fix loop; a genuine correctness defect in an algorithm choice is a normal blocking finding, unchanged.
- **Adjudication ordering:** the round-1 Algorithm Assessment is adjudicated immediately after parsing round-1 output and BEFORE the loop's exit rule. Declines change no content → lock and exit permitted. An accepted alternative → revise the affected task(s), lock, then ONE normal re-review round (assessment omitted, lock line present) — a materially revised plan is never handed off without a confirming Codex pass.
- **Lock wording (exact, as broadened by the user-approved Codex finding 2026-07-10):** locked choices re-open only for "a new blocking (Critical or High) defect in the locked choice" (correctness, feasibility, or fit at stated constraints/scale); advisory preference or optimization alternatives remain locked — subordinate to the existing blocking ladder; only advisory re-litigation is suppressed.
- **Unchanged machinery:** convergence rules, the 4-round document-gate backstop, §4b incomplete-≠-approve, severity mapping — all unchanged.
- **Claude Code only; degrade cleanly:** probe (§1) at most once per skill run, result reused; other harnesses skip silently; the approach gate uses its own notice ("…proceeds without independent Codex approaches"), not §2's review wording.
- **Scratch discipline:** all gate scratch (handoff, prompts) goes in the per-run dir `scripts/codex-review-dir` prints — never `.git/`, never the working tree.
- **Authoring rules:** no `@` links; cross-reference skills/sections by name; voice "your human partner"; companion/reference docs carry no skill frontmatter; match existing gate-doc tone and structure.
- **Doc-commit rule:** do NOT commit the spec or this plan. The eval-evidence doc IS committed (tracked-evidence pattern).
- **Testing terminology:** contract assertions live in `tests/codex-review-gate/test-gate-contract.sh` (add failing assertions FIRST, then author — that is the RED/GREEN cycle for doc contracts). Behavioral "tests" are subagent micro-tests/probes per `skills/writing-skills/SKILL.md` ("Micro-Test Wording"): fresh-context samples, a no-guidance control, 5+ reps per arm, every flagged match read manually. Record only real outcomes.
- **Versioning:** `scripts/bump-version.sh 6.2.0` then `--check` (all six configured manifests agree) and `--audit`; never hand-edit manifests. No README change — the Skills Library enumerates skills, and this feature adds none.

---

## File Structure

**Create:**
- `skills/brainstorming/codex-approach-gate.md` — the approach gate: trigger, handoff, invocation, output shape, aggregation, degradation.
- `docs/hyperpowers/2026-07-10-codex-design-collaboration-eval-evidence.md` — committed eval evidence.
- `evals/scenarios/codex-approach-gate-fires-on-architecture/{story.md,setup.sh,checks.sh}` (separate evals repo)
- `evals/scenarios/codex-plan-gate-algorithm-locked-after-round1/{story.md,setup.sh,checks.sh}` (separate evals repo)

**Modify:**
- `skills/brainstorming/SKILL.md` — checklist item 4, flowchart, "Exploring approaches" subsection.
- `skills/requesting-code-review/codex-review-gate.md` — §3 plan recipe (round-1 Algorithm Assessment), §5 (adjudication ordering + lock line + ledger entry formats).
- `skills/writing-plans/SKILL.md:157-168` — one sentence in the Codex Plan Review Gate section.
- `tests/codex-review-gate/test-gate-contract.sh` — new assertions (Tasks 1 and 2).
- Version manifests via `scripts/bump-version.sh` (6 files).

---

## Task 1: The Codex approach gate (brainstorming)

**Files:**
- Create: `skills/brainstorming/codex-approach-gate.md`
- Modify: `skills/brainstorming/SKILL.md` (checklist line "4. **Propose 2-3 approaches**…", the `digraph brainstorming` flowchart, the "**Exploring approaches:**" bullet list at ~line 78)
- Modify: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: gate doc §1 probe (`scripts/codex-available.sh`), §2 install instructions, `scripts/codex-review-dir` for scratch — all by reference.
- Produces: the companion doc path `codex-approach-gate.md` (linked from SKILL.md); the required approach output shape (name / how-it-works / tradeoffs / when-it-wins / rough-complexity) that Task 3's micro-tests and Task 4's scenario assert against; the approach-specific no-Codex notice string "this brainstorm proceeds without independent Codex approaches".

- [ ] **Step 1: Add failing contract assertions**

Append to `tests/codex-review-gate/test-gate-contract.sh` before the final summary block. **Important mechanics (read the script first):** `assert_contains` takes a **file path** as its first argument (it reads the file itself — do NOT `cat` contents into a variable), and the script's root variable is **`REPO_ROOT`** (not `ROOT`). It already defines path variables for the docs it checks (e.g. `$GATE`); reuse the existing writing-plans path variable if one exists, and define new **path** variables in the same style:

```bash
# --- Approach gate: brainstorming companion doc contract ---
APPROACH="$REPO_ROOT/skills/brainstorming/codex-approach-gate.md"
BRAINSTORM="$REPO_ROOT/skills/brainstorming/SKILL.md"
assert_contains "$APPROACH" "materially different tradeoffs" \
  "approach gate trigger keys on real architectural/algorithmic alternatives"
assert_contains "$APPROACH" "explicitly requests Codex input" \
  "approach gate honors an explicit partner request even for trivial tasks"
assert_contains "$APPROACH" "EXCLUDE" \
  "approach handoff explicitly excludes Claude's own candidate approaches"
assert_contains "$APPROACH" "proceeds without independent Codex approaches" \
  "approach gate carries its own non-review degradation notice"
assert_contains "$APPROACH" "one-shot" \
  "approach gate is one-shot: no fix loop, no re-review"
assert_contains "$BRAINSTORM" "codex-approach-gate.md" \
  "brainstorming SKILL.md links the approach gate companion doc"
```

(Adapt variable names/guards to the script's actual conventions on read — the binding requirement is the assertion needles, not the scaffolding.)

- [ ] **Step 2: Run the contract test — verify the new assertions fail**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: FAIL on the new approach-gate assertions (file missing / strings absent); all pre-existing assertions still pass.

- [ ] **Step 3: Write `skills/brainstorming/codex-approach-gate.md`**

No skill frontmatter (companion doc). Required sections and normative content (transcribe the quoted wording exactly; surrounding prose follows the gate doc's tone):

1. **Title + scope.** "# Codex Approach Gate" — a conditional, **one-shot** Codex consultation during brainstorming's approach exploration. Claude Code only; on any other harness skip silently. One shot means: no fix loop, no round ledger, no re-review — Codex contributes approaches once, then the normal flow owns everything.
2. **When it fires (the trigger rule).** Fire when, while formulating approaches after the clarifying questions are answered, there are **≥2 genuinely different viable architectures, algorithms, or data models with materially different tradeoffs** — not variations of one shape. Fire when your human partner **explicitly requests Codex input** on approaches (any phrasing), even for a task that looks straightforward. Skip silently when the task is trivial or mechanical: a single obvious implementation, a config change, a small fix — the existing flow proceeds unchanged.
3. **Probe and degrade.** Run the §1 probe from `codex-review-gate.md` (at most once per skill run; reuse the result). If Codex is unavailable, tell your human partner once — "Note: codex-plugin-cc is not available, so this brainstorm proceeds without independent Codex approaches." — followed by the same four install lines §2 uses, then continue exactly as brainstorming works today. An incomplete or failed call is handled the same way: no Codex input, noted once, never blocking, never retried into a loop.
4. **The blind handoff.** Write `approach-context.md` into the per-run scratch dir from `scripts/codex-review-dir`. Contents: (a) the original idea, verbatim; (b) each clarifying question and your human partner's answer; (c) relevant codebase **facts** — paths, constraints, existing patterns. **EXCLUDE Claude's own candidate approaches, preferences, or framings** — Codex's ideas must be independent, not anchored.
5. **Invocation.** One foreground call, read-only, with the explicit 600000 ms (10-minute) timeout:
   ```bash
   node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --prompt-file <APPROACH_PROMPT_PATH>
   ```
   The prompt file points Codex at `approach-context.md` and requires this output shape (copy it into the prompt so Codex has the schema in its own context):
   ```markdown
   Approaches (2-3, each genuinely different):
   - name: ...
     how-it-works: ...
     tradeoffs: ...
     when-it-wins: ...
     rough-complexity: trivial|moderate|high
   ```
   Read-only: the prompt instructs "Do not edit anything."
6. **Aggregation.** After the call: (a) **dedupe** — where Codex independently converged on an approach you also formed, merge them and label the convergence (independent agreement is a confidence signal); (b) **polish** viable Codex approaches into the house presentation format; (c) **discard** inapplicable ones with a one-line reason that stays visible in the presentation; (d) present the combined shortlist through the existing "propose 2-3 approaches" step with light provenance tags — `(Codex)`, `(both converged)` — and a single recommendation. **Judge approaches on merits, not origin — your own approaches get no home-team advantage.**

- [ ] **Step 4: Hook the gate into `skills/brainstorming/SKILL.md`**

Three edits:

(a) Checklist item 4 becomes:

```markdown
4. **Propose 2-3 approaches** — with trade-offs and your recommendation. **Codex approach gate (conditional, Claude Code only):** before finalizing your approaches, if the design space has real architectural or algorithmic alternatives — or your human partner asks for Codex input — run [codex-approach-gate.md](codex-approach-gate.md) and fold its approaches into this step with provenance tags. Trivial/mechanical tasks skip it silently.
```

(b) In the `digraph brainstorming` flowchart, replace the edge `"Ask clarifying questions" -> "Propose 2-3 approaches";` with:

```dot
    "Real architectural/algorithmic choices\nor partner requests Codex?" [shape=diamond];
    "Codex approach gate (one-shot)\n(Claude Code; degrade if absent)" [shape=box];
    "Ask clarifying questions" -> "Real architectural/algorithmic choices\nor partner requests Codex?";
    "Real architectural/algorithmic choices\nor partner requests Codex?" -> "Codex approach gate (one-shot)\n(Claude Code; degrade if absent)" [label="yes"];
    "Real architectural/algorithmic choices\nor partner requests Codex?" -> "Propose 2-3 approaches" [label="no - trivial"];
    "Codex approach gate (one-shot)\n(Claude Code; degrade if absent)" -> "Propose 2-3 approaches";
```

(c) In "**Exploring approaches:**" (~line 78), append one bullet:

```markdown
- **Codex approach gate (conditional):** when the design space has real architectural or algorithmic alternatives — or your human partner explicitly asks — get Codex's independent approaches first via [codex-approach-gate.md](codex-approach-gate.md): blind handoff, one shot, approaches folded into this step with provenance tags and judged on merits, not origin.
```

- [ ] **Step 5: Run the contract test — verify it passes**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: PASS (all assertions, old and new).

- [ ] **Step 6: Application smoke probe**

Dispatch one fresh subagent given the companion doc + the three SKILL.md hooks (pasted as its guidance) and an architecture-rich brainstorm setup (an idea + answered Q&A with ≥2 real architectural alternatives, Codex stubbed/absent). Confirm it (a) decides the gate fires, (b) composes the blind handoff WITHOUT its own approaches, and (c) on "Codex unavailable" emits the approach-specific notice and proceeds. Note the outcome for Task 3's evidence doc.

- [ ] **Step 7: Commit**

```bash
git add skills/brainstorming/codex-approach-gate.md skills/brainstorming/SKILL.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(brainstorm): add conditional one-shot Codex approach gate"
```

---

## Task 2: Round-1 Algorithm Assessment + lock (plan gate)

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§3: after the plan-documents prompt block at ~line 128; §5: after the round-aware preamble blockquote at ~line 366)
- Modify: `skills/writing-plans/SKILL.md` (the gate paragraph at lines 157-168)
- Modify: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: the existing plan recipe, round ledger, preamble, and backstop machinery (unchanged).
- Produces: the "Round-1 Algorithm Assessment" §3 block; the output shape (`verdict: appropriate | alternative-suggested`); ledger entry formats `Algorithm locked: <new> (was <old>) — <rationale>` and `Algorithm locked: <original> — Codex suggested <alt>, declined: <reason>`; the lock preamble line. Task 3's contract probe and Task 4's scenario assert against these exact strings.

- [ ] **Step 1: Add failing contract assertions**

Append to `tests/codex-review-gate/test-gate-contract.sh`:

```bash
# --- Round-1 Algorithm Assessment + lock (plan gate) ---
assert_contains "$GATE" "Round-1 Algorithm Assessment" \
  "plan recipe defines the round-1 algorithm assessment"
assert_contains "$GATE" "alternative-suggested" \
  "algorithm assessment output shape carries the alternative-suggested verdict"
assert_contains "$GATE" "advisory input to the controller" \
  "algorithm suggestions are advisory, not blocking"
assert_contains "$GATE" "before applying the loop's exit rule" \
  "algorithm adjudication happens before the approve exit"
assert_contains "$GATE" "Algorithm locked:" \
  "round ledger defines the algorithm lock entry format"
assert_contains "$GATE" "a new blocking correctness defect (Critical or High) in the locked choice" \
  "lock re-opens only for blocking correctness defects, matching the severity ladder"
assert_contains "$REPO_ROOT/skills/writing-plans/SKILL.md" "Algorithm Assessment" \
  "writing-plans points at the round-1 algorithm assessment"
```

(`assert_contains` takes a file path — reuse the script's existing writing-plans path variable if it defines one.)

- [ ] **Step 2: Run the contract test — verify the new assertions fail**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: FAIL on exactly the seven new assertions.

- [ ] **Step 3: Extend §3 — the Round-1 Algorithm Assessment block**

Insert immediately after the plan-documents prompt markdown block (after ~line 128), before "**Code reviews — launch detached…**":

```markdown
**Round-1 Algorithm Assessment (plan gate only).** When BOTH hold — this is
round 1 of the plan gate, AND the plan contains material algorithmic or
data-structure choices (sorting/searching, graph traversal, caching strategies,
concurrency schemes, index/layout choices — not glue code or CRUD wiring) —
append this to the plan prompt:

```markdown
Additionally, assess the plan's material algorithm and data-structure choices.
For each one: is it the right choice for the stated constraints and data
scale? If not, propose exactly one alternative with justification (complexity,
tradeoffs, why it wins here). Return this block after the Required output:

Algorithm Assessment (round 1 only):
- choice: <algorithm/structure as planned>
  verdict: appropriate | alternative-suggested
  alternative: <name, or None>
  justification: ...
```

Plans with no material algorithmic content omit this section entirely.
Algorithm suggestions are **advisory input to the controller's decision** —
they do not map onto the Critical/Important severity ladder (§4) and never
drive the fix loop (§5). If Codex separately judges an algorithm choice to be
a genuine correctness defect, that is a normal blocking finding, unchanged.
```

(Use the file's existing nested-fence conventions if a literal nested fence conflicts — indent the inner block instead, matching how §3 renders other prompt templates.)

- [ ] **Step 4: Extend §5 — adjudication ordering, ledger lock, preamble line**

Insert after the round-aware preamble blockquote and its "bar on re-review" paragraph (~line 370):

```markdown
### Algorithm adjudication and lock (plan gate)

Adjudicate the round-1 Algorithm Assessment immediately after parsing the
round-1 output and **before applying the loop's exit rule**, so an
`alternative-suggested` entry is never dropped by an early `approve` exit:

- **Approve + no alternatives (or all declined):** record the lock(s), then
  exit as usual. A decline changes no plan content, so no re-review is needed;
  declines appear in the ledger and the §6 hand-back.
- **Accepted alternative:** revise the affected plan task(s) — keeping
  interfaces, steps, and cross-task references consistent — record the lock,
  then run **one normal re-review round** over the revised plan (assessment
  omitted, lock line present). A materially revised plan is never handed off
  without a confirming Codex pass. The loop then converges as usual within
  the existing backstop.
- **Needs-attention:** the normal fix loop runs anyway; adjudicate and lock
  alongside the round-1 blocking fixes.

Ledger entry formats:
- `Algorithm locked: <new> (was <old>) — <rationale>`
- `Algorithm locked: <original> — Codex suggested <alt>, declined: <reason>`

On plan-gate re-reviews, append this line to the round-aware preamble and omit
the Algorithm Assessment section from the prompt:

> Algorithm choices are locked per the ledger; do not re-open them absent
> a new blocking correctness defect (Critical or High) in the locked choice.
```

- [ ] **Step 5: One sentence in `skills/writing-plans/SKILL.md`**

In the gate paragraph (lines 157-168), after "type/signature consistency, and spec coverage)," insert:

```markdown
On round 1 the gate also runs the Round-1 Algorithm Assessment when the plan has
material algorithmic choices (advisory; adjudicated before the loop's exit rule
and locked in the round ledger — see the gate doc's §3 and §5).
```

- [ ] **Step 6: Run the contract test — verify it passes**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: PASS (all assertions).

- [ ] **Step 7: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md skills/writing-plans/SKILL.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(plan-gate): add round-1 algorithm assessment with ledger lock"
```

---

## Task 3: Eval — trigger micro-tests, lock contract probe, evidence doc

**Files:**
- Create: `docs/hyperpowers/2026-07-10-codex-design-collaboration-eval-evidence.md`

**Interfaces:**
- Consumes: the trigger rule wording (Task 1) and the §5 adjudication/lock contract (Task 2) — tested as authored, verbatim.
- Produces: the committed evidence doc Task 4's scenarios and the release record reference.

- [ ] **Step 1: Trigger micro-tests (three edges, two arms each)**

Per `skills/writing-skills/SKILL.md` "Micro-Test Wording": fresh single-shot subagents, one per rep, no shared history; ≥6 reps per arm; every response read manually; variance noted. The **control arm is the no-guidance baseline** (brainstorming guidance without any approach-gate content) — this substitutes for a classic RED baseline, which is uninformative here (without the edit, Claude trivially never consults Codex).

Build one brainstorm-context stimulus per edge:
- **Trivial edge:** a config-change brainstorm (e.g. "rename a CLI flag") with answered Q&A. Variant must NOT fire the gate (score: false-fire).
- **Architectural edge:** a brainstorm with ≥2 genuinely different viable architectures (e.g. event-driven vs. batch pipeline for an ingest system) with answered Q&A. Variant must fire (score: miss).
- **Explicit-request edge:** the trivial stimulus plus the partner saying "get Codex's take on approaches." Variant must fire despite triviality (score: miss).

For each rep, the variant arm gets the brainstorming step text + the companion doc's trigger section; ask the subagent to state its next action (fire the gate / proceed without it) and why. Score by manual read. Report per-edge hit counts (variant vs control), convergence, and conclusion. If an edge doesn't bind (misses/false-fires), tighten the trigger wording in `codex-approach-gate.md` minimally and re-test that edge until it binds — then re-run `bash tests/codex-review-gate/test-gate-contract.sh` if any asserted string changed.

- [ ] **Step 2: Lock contract probe**

Dispatch one fresh subagent given the amended gate doc §5 plus a synthetic round-1 plan-review result: `Verdict: approve`, no blocking findings, and an Algorithm Assessment containing one `alternative-suggested`. Ask it to state, per the doc, exactly what happens next. Pass criteria (manual read): (a) it adjudicates BEFORE exiting; (b) on accept it revises + locks + runs one re-review round; (c) on decline it locks + exits with no re-review; (d) the round-2 prompt it composes omits the assessment section and carries the lock line verbatim. Repeat once with `Verdict: needs-attention` to confirm the normal-loop path. If the doc misleads the probe, fix the §5 wording and re-probe.

- [ ] **Step 3: Write and commit the evidence doc**

Create `docs/hyperpowers/2026-07-10-codex-design-collaboration-eval-evidence.md`: methodology note (control-as-baseline rationale), per-edge micro-test tables (arms, reps, manual-read hit counts, variance), the smoke-probe result from Task 1 Step 6, the lock-probe transcripts summary, honest conclusions (state plainly anything inconclusive; no invented numbers).

```bash
git add docs/hyperpowers/2026-07-10-codex-design-collaboration-eval-evidence.md
git commit -m "test(design-collab): record trigger micro-tests and lock contract probe"
```

(If Step 1 or 2 changed skill/gate wording, include those files in this commit with a message noting the tightened wording.)

---

## Task 4: Quorum regression scenarios

**Files:**
- Create: `evals/scenarios/codex-approach-gate-fires-on-architecture/{story.md,setup.sh,checks.sh}` (evals repo)
- Create: `evals/scenarios/codex-plan-gate-algorithm-locked-after-round1/{story.md,setup.sh,checks.sh}` (evals repo)
- Read: `evals/docs/scenario-authoring.md`; templates `evals/scenarios/codex-gate-converges-on-reraise/` and `codex-gate-spec-degrades-without-codex/` (the stub `codex-companion.mjs` pattern — no real Codex/auth/network needed)

**Interfaces:**
- Consumes: the shipped docs (Tasks 1-2) and their exact strings (notice text, `Algorithm locked:`, lock preamble line).
- Produces: two statically-validated scenarios in the `codex-gate-*` family. Live `quorum run` is a trusted-maintainer operation reserved for your human partner.

- [ ] **Step 1: Scaffold**

```bash
cd evals && bun run quorum new codex-approach-gate-fires-on-architecture && bun run quorum new codex-plan-gate-algorithm-locked-after-round1
```

- [ ] **Step 2: Author the approach-gate scenario**

`codex-approach-gate-fires-on-architecture`: `setup.sh` builds a fixture repo (via `$QUORUM_WORKDIR`) plus a stub `codex-companion.mjs` (template: the existing `codex-gate-*` stubs). **Artifact contract (deterministic, workdir-relative — the stub is the producer):** on every `task` call the stub (a) copies the received `--prompt-file` contents to `$QUORUM_WORKDIR/codex-stub-calls/call-<N>.md` (N = call ordinal) before responding, and (b) returns two canned approaches in the required output shape (name / how-it-works / tradeoffs / when-it-wins / rough-complexity). The fixture idea text contains a distinctive marker string (e.g. `FIXTURE-IDEA-7Q4`) so checks can prove the blind handoff carried the raw inputs. The story has the Gauntlet-Agent bring an architecture-rich idea to `hyperpowers:brainstorming` and answer its questions. ACs (evidence-demanding, Gauntlet-graded): the gate fired at the approaches step; the handoff excluded the agent's own candidate approaches; the presented shortlist carried provenance tags (`(Codex)` / `(both converged)`). `checks.sh` `post()` asserts deterministically: `check-transcript skill-called hyperpowers:brainstorming`; `file-exists 'codex-stub-calls/call-1.md'` (the stub was actually invoked); `file-contains 'codex-stub-calls/call-1.md' 'FIXTURE-IDEA-7Q4'` (the handoff carried the verbatim idea). The exclusion-of-own-approaches and provenance judgments stay in the AC prose (Gauntlet-graded) — the check DSL has no deterministic verb for "does not contain approaches the agent invented at runtime"; note this residual reliance in a `checks.sh` comment. Follow the family's conventions exactly (`pre()` uses `requires-tool node`; `checks.sh` not executable).

- [ ] **Step 3: Author the algorithm-lock scenario**

`codex-plan-gate-algorithm-locked-after-round1`: this scenario must **force the accepted-alternative path** so the spec's round-2 coverage is exercised unconditionally — the fixture plan uses an algorithm that is defensibly wrong for its stated scale (e.g. a nested O(n²) scan over an input the plan itself says is millions of rows), and the stub's round-1 response returns `Verdict: approve`, no blocking findings, plus an Algorithm Assessment whose single `alternative-suggested` (e.g. a hash-index lookup) is clearly correct for those constraints, so accepting is the only defensible adjudication; the story's ACs state the agent accepts, revises the plan task, locks, and runs the confirming re-review. **Artifact contract (stub is the producer):** the stub copies every received `--prompt-file` to `$QUORUM_WORKDIR/codex-stub-calls/call-<N>.md`; its round-2+ response is a plain `Verdict: approve` with no findings. `post()` asserts **unconditionally**: `file-exists 'codex-stub-calls/call-2.md'` (a second, confirming Codex round actually ran); `file-contains 'codex-stub-calls/call-2.md' 'locked per the ledger'` (the lock preamble line was carried); `not file-contains 'codex-stub-calls/call-2.md' 'Algorithm Assessment (round 1 only)'` (the assessment ask was omitted on round 2); and the ledger lock exists — the round ledger lives in the per-run home cache, so assert it via `command-succeeds "grep -rq 'Algorithm locked:' \"$HOME/.cache/hyperpowers/codex-review\""` (quorum pins `$HOME` to the run's throwaway home, so this greps only this run's gate scratch). The decline path needs no scenario — it is covered by Task 3's lock contract probe.

- [ ] **Step 4: Validate statically**

```bash
cd evals && bun run quorum check
```
Expected: both scenarios validate `ok`. (Do NOT `quorum run` — trusted-maintainer only.)

- [ ] **Step 5: Commit (in the evals repo)**

```bash
cd evals && git add scenarios/codex-approach-gate-fires-on-architecture scenarios/codex-plan-gate-algorithm-locked-after-round1 && git commit -m "feat(scenarios): add approach-gate and algorithm-lock regression scenarios"
```

- [ ] **Step 6: Flag live-run for your human partner**

State that `bun run quorum run scenarios/<name> --coding-agent claude` is the release-gate confirmation, run from a real terminal with credentials.

---

## Task 5: Version bump

**Files:**
- Modify (via `scripts/bump-version.sh`): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json`

**Interfaces:**
- Consumes: all shipped changes.
- Produces: 6.2.0 across all six configured manifests.

- [ ] **Step 1: Bump and verify**

```bash
scripts/bump-version.sh 6.2.0
scripts/bump-version.sh --check
scripts/bump-version.sh --audit
```
Expected: `--check` reports 6.2.0 at all six locations; `--audit` clean apart from historical references in docs (the configured excludes and tracked evidence/spec docs referencing prior versions as history are expected, not defects).

- [ ] **Step 2: Commit**

```bash
git add package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json
git commit -m "chore: bump 6.1.0 -> 6.2.0 for Codex design collaboration"
```

---

## Notes for the executor

- **Order:** Task 1 → 2 → 3 → 4 → 5. Task 3 tests wording as authored (its control arm is the baseline — see Global Constraints "Testing terminology"); if it tightens wording, contract assertions may need the same commit.
- **Final whole-branch review** is performed by subagent-driven-development at the end (plus the final Codex gate) — not a plan task.
- **Do not commit** the spec or this plan; the eval-evidence doc IS committed. Do not push anything.
