# Codex Design Collaboration — Design

- **Date:** 2026-07-10
- **Status:** Approved (design); pending spec review → implementation plan
- **Target version:** 6.1.0 → 6.2.0 (minor; feature additions to existing skills — assumes the
  `feat/performance-optimization-skills` branch lands at 6.1.0 first)
- **Scope:** Leverage the Codex reviewer model's architecture/algorithm strength at two
  points in the design pipeline: independent approach generation during brainstorming, and a
  one-time algorithm assessment in the writing-plans review gate.

## Summary

Two conditional, cleanly-degrading additions:

1. **Codex approach gate (brainstorming).** When a design problem has genuine architectural
   or algorithmic alternatives — or the user explicitly asks — Codex is given the same raw
   inputs the user gave Claude (idea, Q&A, codebase facts; *not* Claude's candidate
   approaches) and asked, blind, for its own 2–3 approaches. Claude aggregates both sets,
   polishes, and presents one combined shortlist with light provenance through the existing
   "propose approaches" step. One shot — no iteration, no re-review.
2. **Round-1 algorithm assessment (plan gate).** When a plan contains material
   algorithmic/data-structure choices, the *first* Codex plan review also assesses each
   choice: appropriate, or alternative-suggested with justification. Claude adjudicates
   once, the decision is locked in the round ledger, and rounds 2+ proceed exactly as the
   gate does today with a lock line preventing re-opening.

## Key decisions (resolved during brainstorming)

| # | Decision | Choice |
|---|----------|--------|
| 1 | When the approach gate fires | Conditional: real architectural/algorithmic choices → fire; trivial/mechanical → skip; explicit user request → fire even if trivial |
| 2 | How algorithm review attaches to the plan gate | Folded into the round-1 plan-review prompt (one Codex call per round); locked via the round ledger |
| 3 | User-facing surfacing of approaches | Transparent shortlist through the existing approaches step, light provenance tags, one recommendation |
| 4 | Evaluation | Adapted writing-skills treatment (trigger micro-tests + lock contract probe) plus two quorum scenarios |
| 5 | Structure | Companion file in brainstorming + plan-recipe extension in the shared gate doc (no new skill, no gate-doc grafting of generative flows) |

## Architecture & file changes

```
skills/brainstorming/
  SKILL.md                    # MODIFY: conditional step in "Exploring approaches",
                              #   checklist mention, flowchart node
  codex-approach-gate.md      # CREATE: companion doc (visual-companion.md precedent)
skills/writing-plans/
  SKILL.md                    # MODIFY: one sentence in the Codex Plan Review Gate section
skills/requesting-code-review/
  codex-review-gate.md        # MODIFY: §3 plan recipe (round-1 Algorithm Assessment block),
                              #   §5 ledger (algorithm-lock entry + round-2+ preamble line)
docs/hyperpowers/
  2026-07-10-codex-design-collaboration-eval-evidence.md   # CREATE: committed evidence
evals/scenarios/  (separate repo)
  codex-approach-gate-fires-on-architecture/                # CREATE
  codex-plan-gate-algorithm-locked-after-round1/            # CREATE
```

No new skills; no manifest changes beyond the version bump. Both features are
Claude-Code-only and reuse the gate doc's §1 probe (once per skill run) and §2 no-Codex
notice by reference — conventions are cross-referenced, never duplicated.

## Feature 1: Codex approach gate (brainstorming)

### Trigger rule

Worded as an observable predicate (it is micro-tested):

- **Fire** when, while formulating approaches after the clarifying questions are answered,
  there are ≥2 genuinely different viable architectures, algorithms, or data models with
  materially different tradeoffs — not variations of one shape.
- **Fire** when the user explicitly requests Codex input on approaches (any phrasing),
  even for a task that looks straightforward.
- **Skip** (silently) when the task is trivial or mechanical: a single obvious
  implementation, a config change, a small fix. The existing flow proceeds unchanged.

### Timing and blindness

The gate fires after clarifying questions are answered and **before** Claude finalizes its
own approaches. Codex works blind from a handoff file written to the per-run gate scratch
dir (the `codex-review-dir` helper — never `.git/`, never the working tree) containing:

- the original idea, verbatim;
- the clarifying Q&A (each question and the user's answer);
- relevant codebase **facts** (paths, constraints, existing patterns).

Claude's own candidate approaches are **excluded** from the handoff so Codex's ideas are
independent, not anchored.

### Invocation

One foreground `task --fresh --prompt-file <path>` call, read-only (no `--write`), with the
explicit 600000 ms (10-minute) command timeout — the same conventions as the document
gates. The prompt requires a structured output shape so aggregation is mechanical: 2–3
approaches, each with **name, how it works, tradeoffs, when it wins, rough complexity**.

### One-shot semantics

No fix loop, no round ledger, no re-review. An incomplete or failed call degrades to "no
Codex input" — noted once to the user, never blocking. Codex absent at probe →
brainstorming proceeds exactly as today after an **approach-specific notice**: the gate
reuses §1's probe and §2's degrade *policy* and install instructions, but not §2's
review-specific wording (which would inaccurately say a "review" is being skipped). The
companion doc carries its own one-line notice, e.g. "Codex is unavailable, so this
brainstorm proceeds without independent Codex approaches."

### Aggregation and surfacing

Claude then:

1. **Dedupes** — where Codex independently converged on an approach Claude also had, merge
   them and label the convergence (independent agreement is a confidence signal).
2. **Polishes** viable Codex approaches into the house presentation format.
3. **Discards** inapplicable Codex approaches with a one-line reason (kept in the
   presentation, so the user sees what was considered).
4. Presents the combined shortlist through the **existing** "propose 2-3 approaches" step
   with light provenance tags — `(Codex)`, `(both converged)` — and a single
   recommendation.

Explicit mandate in the companion doc: approaches are judged on merits, not origin —
Claude's own approaches get no home-team advantage.

## Feature 2: Round-1 algorithm assessment + lock (plan gate)

### Round-1 prompt extension (conditional)

In `codex-review-gate.md` §3, the plan recipe's prompt gains an **Algorithm Assessment**
section included only when **both** hold:

- this is round 1 of the plan gate, and
- the plan contains material algorithmic or data-structure choices (sorting/searching,
  graph traversal, caching strategies, concurrency schemes, index/layout choices — not glue
  code or CRUD wiring).

The section asks: for each material algorithm/data-structure choice in the plan, is it the
right one for the stated constraints and data scale? If not, propose **one** alternative
with justification (complexity, tradeoffs, why it wins here). The required document-review
output gains a matching round-1-only block:

```markdown
Algorithm Assessment (round 1 only):
- choice: <algorithm/structure as planned>
  verdict: appropriate | alternative-suggested
  alternative: <name, or None>
  justification: ...
```

Plans with no material algorithmic content omit the section entirely; the gate runs exactly
as it does today.

### Severity semantics: advisory, not blocking

Algorithm suggestions are **advisory input to Claude's decision** — they do not map onto
the Critical/Important blocking ladder and do not drive the fix loop. If Codex separately
judges an algorithm choice to be a genuine correctness defect, that is a normal blocking
finding through the existing loop, unchanged.

### Adjudication and lock

Claude adjudicates each suggestion exactly once, at the point defined in "Adjudication
ordering" below (after parsing round-1 output, before the loop's exit rule):

- **Accept** → revise the affected plan task(s); ledger entry:
  `Algorithm locked: <new> (was <old>) — <rationale>`.
- **Decline** → ledger entry:
  `Algorithm locked: <original> — Codex suggested <alt>, declined: <reason>`.

### Adjudication ordering — including the approve-on-round-1 path

Adjudication of the Algorithm Assessment happens **immediately after parsing the round-1
output and before applying the loop's exit rule**, so an `alternative-suggested` entry is
never dropped by an early `approve` exit:

- **Round 1 = approve, no blocking findings, no alternatives suggested (or all declined):**
  lock per the ledger, exit the loop as today. A decline changes no plan content, so no
  re-review is needed; the declines appear in the ledger and the §6 hand-back.
- **Round 1 suggests an alternative and Claude accepts:** Claude revises the affected plan
  task(s) — keeping interfaces, steps, and cross-task references consistent — records the
  lock, and runs **one normal re-review round** over the revised plan (algorithm section
  omitted, lock line present). A materially revised plan is never handed off without a
  confirming Codex pass. The loop then converges as usual within the existing 4-round
  backstop.
- **Round 1 = needs-attention:** the normal fix loop runs anyway; algorithm adjudication
  and lock happen alongside the round-1 blocking fixes, and rounds 2+ proceed as below.

### Rounds 2+

The round-aware preamble gains one line: *algorithm choices are locked per the ledger; do
not re-open them absent a new **blocking (Critical or High/Important) defect** in the
locked choice — correctness, feasibility, or fit at the stated constraints and scale;
advisory preference or optimization alternatives remain locked.* This keeps the lock
subordinate to the gate's existing blocking semantics — a genuine Critical/High defect in
the locked choice is always in-contract on re-review; only advisory re-litigation of the
locked choice is suppressed. (Wording broadened from "correctness defect" per an accepted
Codex execution-gate finding, approved by the user 2026-07-10: "correctness" was narrower
than this paragraph's own subordination principle.) The Algorithm
Assessment section is omitted from round-2+ prompts. Convergence rules and the 4-round
document-gate backstop are unchanged.

## Degradation

- Both features are Claude-Code-only, like the existing gates; on other harnesses they are
  skipped silently (no probe, no notice).
- The §1 probe runs at most once per skill run and its result is reused by every gate in
  that run, including the approach gate.
- Codex absent or a call incomplete → the flows proceed as they do today; incomplete is
  never read as input/approval (§4b discipline applies).

## Evaluation plan

Per the fork's "skill changes require evaluation," adapted to this change's actual risk
surface (calibration and contract, not classic rule-breaking discipline):

- **Trigger micro-tests** (writing-skills methodology: fresh-context samples, no-guidance
  control, 5+ reps per arm, every flagged match read manually, variance as a metric) on the
  three edges: trivial task → gate skipped; real architectural alternatives → gate fired;
  explicit user request on a trivial task → gate fired.
- **Lock contract probe:** verify the round-2+ plan-gate prompt carries the lock line and
  omits the Algorithm Assessment section, and that the ledger holds the locked entry.
- **Two quorum scenarios** in the hyperpowers-evals repo, joining the `codex-gate-*`
  family (stub `codex-companion.mjs` pattern; no TypeScript/registry changes):
  - `codex-approach-gate-fires-on-architecture` — an architecture-rich brainstorm fires the
    gate, the handoff excludes Claude's approaches, and the presented shortlist carries
    provenance.
  - `codex-plan-gate-algorithm-locked-after-round1` — round 1 includes the assessment ask,
    Claude locks a decision in the ledger, and round 2's prompt omits the ask and carries
    the lock line.
- Evidence recorded in `docs/hyperpowers/2026-07-10-codex-design-collaboration-eval-evidence.md`
  (committed, tracked-evidence pattern). Live `quorum run` remains a trusted-maintainer
  operation for the human partner.

## Versioning and sequencing

- Bump with `scripts/bump-version.sh 6.2.0` + `--check` + `--audit` (all six configured
  manifests; do not hand-edit).
- **Sequencing dependency:** this work branches from `main` after the
  `feat/performance-optimization-skills` branch (6.1.0) is landed or otherwise resolved.

## Non-goals (YAGNI)

- No approach gate inside writing-plans itself.
- No multi-round approach debate or approach re-review with Codex.
- No Codex participation in the user Q&A phase.
- No configuration knobs (thresholds, model pins); model/effort remain governed by
  `~/.codex/config.toml`.
- No changes to the spec or code review recipes beyond the round-1 plan block.
