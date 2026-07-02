# Codex Review Gate — Convergence, Cap Restructure, and Completion Handling

**Status:** Design (approved in brainstorming; not yet planned)
**Date:** 2026-06-30
**Scope:** The shared Hyperpowers Codex review-gate contract
(`codex-review-gate.md`) plus the four caller skills that reference it
(`brainstorming`, `writing-plans`, `subagent-driven-development`,
`requesting-code-review`) — five gate invocations in total, since SDD owns both
a per-task and a final whole-branch code gate.

## Problem

The Codex⇄Claude review gate is hitting its `2 rounds` cap routinely at the
spec, plan, and code interfaces. An audit of the gate machinery
(`skills/requesting-code-review/codex-review-gate.md` plus its five callers)
found three independent root causes.

### 1. Rounds do not converge

Every round runs Codex cold. Document gates invoke `task --fresh`; code gates
invoke a brand-new `adversarial-review`. The companion (`codex-plugin-cc`)
exposes session resume only for `task` (`--resume-last`); `adversarial-review`
has no resume path (`runAppServerReview` always starts fresh). The gate uses no
resume for any gate.

Consequences, in observed frequency order:

- **Moving target (dominant).** Round 2 is an independent cold review, so it
  surfaces *new* findings it simply did not notice in round 1. This re-trips
  the cap even when every round-1 item was fixed.
- **Self-re-flagging (secondary).** Round 2 does not know round-1 findings were
  fixed, so it re-raises them.
- **Genuine hard problems (rare).** Some findings legitimately need more than
  two passes.

The round prompt is identical every round — it never tells Codex "this is a
re-review; here is what round 1 found and how it was addressed; confirm
resolution and only raise blocking regressions." Declined findings (§2 permits
declining with reasoning) are not carried forward, so Codex re-raises them.

### 2. One arbitrary cap governs five gates with ~10× cost spread

`codex-review-gate.md` §5 defines a single `cap = 2 rounds` referenced by all
five gates: brainstorming spec, writing-plans plan, SDD per-task code, SDD final
whole-branch code, and requesting-code-review. A document round is a text edit
plus a `task` re-run. A code round is a fix subagent + a re-run of the Claude
reviewer + a fresh `adversarial-review`. Capping both at the same number, and
counting raw attempts rather than progress, is arbitrary.

### 3. No "not finished" outcome

The code recipes call `adversarial-review --wait`, which runs as a **foreground**
tracked job (`handleReviewCommand` → `runForegroundCommand` → `runAppServerReview`)
that blocks until Codex returns a verdict, errors, or the calling process is
killed. On a long review the harness's own Bash/tool timeout aborts that blocking
call before a verdict arrives, leaving Claude with partial trace output and no
terminal result. (The companion's own 240s `waitTimedOut` poll deadline,
`DEFAULT_STATUS_WAIT_TIMEOUT_MS`, belongs to `status --wait`, *not* to the review
command — so it is not the trigger here.) The gate models only two outcomes —
*approve* or *blocking findings* — so an aborted or partial result is unmodeled.
Claude fills the gap by rationalizing it as "no findings → continue." A slow
review silently reads as a clean review. (Observed verbatim: *"I'll accept the
Codex partial result as effectively 'no findings reported' and continue."*)

## Goals

- Make review rounds **converge** so the loop ends when the work is actually
  done, not by exhausting an attempt counter (fixes #1).
- Restructure the cap so it counts **progress** and reflects per-gate cost
  (fixes #2).
- Make an unfinished Codex result a **first-class outcome that is never an
  approval** (fixes #3).

## Non-Goals

- No changes to `codex-plugin-cc` (the companion script, the 240s wait timeout,
  and the absence of `adversarial-review` resume are fixed external
  constraints). All changes are to hyperpowers-owned skill markdown and prompt
  files.
- No change to what counts as blocking (Critical + Important).
- No change to the severity mapping (critical→Critical, high→Important,
  medium/low→Minor).
- No change to the degrade-when-Codex-absent behavior (probe once, emit the
  no-Codex notice, run gates as no-ops).
- No new external dependencies.

## Design

### A. Round ledger (convergence mechanism)

Make every round after the first a *re-review against known state* instead of a
cold re-derivation.

**Artifact.** Before re-running Codex (round 2+), Claude writes a small handoff
file per gate invocation, named alongside the other gate artifacts (e.g.
`…/codex-round-ledger.md`). It is a file handoff (consistent with the
file-over-paste discipline already established in the gate doc), so it does not
bloat Claude's own context. For each completed round it records:

- **Resolved** — each blocking finding and how it was addressed, with the fix
  commit/diff reference (code) or the spec/plan edit (documents).
- **Declined** — each finding Claude declined, with the explicit reasoning
  (the §2 "MAY decline" decision, now carried forward instead of lost).
- **Still open** — any blocking finding not yet resolved, and why.

Each subsequent round appends a new section; the ledger is the cumulative record
across the loop.

**Re-review prompt preamble.** Round 2+ invocations prepend a round-aware
preamble to the existing per-artifact prompts in §3, changing Codex's job from
"review cold" to "confirm + regression":

> This is re-review round N. The prior-round findings and how each was resolved
> or declined are in `<LEDGER_PATH>`. Confirm the resolved findings are actually
> fixed. Do not re-raise a finding listed as declined unless you can show the
> stated reasoning is wrong. You may raise any genuinely new **blocking
> (Critical or High)** finding — whether or not it is a regression — provided it
> is not already listed as resolved and not a declined item without a new
> argument. Do not raise new Minor (medium/low) findings on a re-review.

The bar on re-review is "new and blocking," not "new and a regression." A
newly-noticed Critical or High issue is still blocking even if it existed all
along — narrowing the preamble to regressions-only would let a real
High/Important finding be silently dropped, manufacturing false convergence (the
exact "declare done when not done" failure this spec exists to prevent). What is
excluded on re-review is *Minor* noise, not new blocking severity.

**Why it converges.** Round 2 can now *agree* ("resolved findings confirmed,
nothing new blocking"), which fires the convergence stop-rule (§B). It stops
re-raising declined items (kills self-re-flagging). It raises the bar for *new*
findings to **blocking severity** on re-review (Critical/High still count;
Minor noise does not), damping the moving target without suppressing genuine
blocking issues. Minor items on a re-review are captured as they
are today (noted, not looped).

**Degrade.** Round 1 is unchanged (no ledger exists yet). If Codex is absent,
none of this runs. The ledger is an uncommitted working file, like the review
package.

### B. Cap restructure (convergence stop-rule + per-gate backstops)

Replace §5's single `cap = 2 rounds` with a rule that counts progress.

**Stop-rule.** The loop ends when *any* of these is true:

1. **Approved** — Codex returns `approve` with no blocking findings. (unchanged)
2. **Converged** — a round produces **no *new* blocking findings**: everything
   it raises is already-resolved (confirmed via the ledger) or a
   previously-declined item with no new argument. This is a fixed point — stop,
   even if the backstop is not hit.
3. **Backstop hit** — the per-gate round ceiling is reached. Stop and hand back
   with any unresolved blocking findings listed.

**Per-gate backstops:**

| Gate | Recipe | Backstop |
|------|--------|----------|
| Spec (brainstorming) | `task` | 4 |
| Plan (writing-plans) | `task` | 4 |
| Per-task code (SDD) | `adversarial-review` | 3 |
| Final whole-branch code (SDD) | `adversarial-review` | 3 |
| Code-review request (requesting-code-review) | `adversarial-review` | 3 |

Document gates get 4 (cheap: text edit + `task` re-run). Code gates get 3
(expensive: fix subagent + Claude-reviewer re-run + fresh Codex review per
round). Both exceed today's 2 because convergence usually stops them earlier;
the backstop is now a true backstop, not the common exit.

**Preserved.** Severity map; blocking = Critical + Important; "MAY decline with
reasoning"; the existing rule that after a *code* fix the Claude reviewer re-runs
before Codex re-runs.

**SDD interaction.** If a per-task code gate hits its backstop with unresolved
blocking findings, the existing SDD contract governs: hand back with the
findings listed; SDD's "BLOCKED → surface to human" path decides whether
execution pauses. This change does not alter SDD's continue-between-tasks
policy.

### C. Completion handling (incomplete ≠ approve)

Add a third outcome to §4/§5, distinct from both *approve* and
*blocking-findings*: **incomplete**.

**Grounding in actual companion behavior.** The code recipes call
`adversarial-review --wait --json`, which runs as a **foreground** tracked job
(`handleReviewCommand` → `runForegroundCommand` → `runAppServerReview`). It
blocks until the review finishes, errors, or the calling process is killed. The
`waitTimedOut`/240s deadline (`DEFAULT_STATUS_WAIT_TIMEOUT_MS`) belongs to
`status --wait`, **not** to `adversarial-review`, and must not be used to define
"incomplete" for the review recipes. The real-world incompletion the user
observed is the **harness's own Bash/tool timeout aborting the blocking
foreground call** before Codex returns a verdict.

**A code-review result is incomplete when any hold:**

- the companion invocation is aborted by the harness command/tool timeout before
  it returns (no terminal payload reaches Claude), or
- the process returns a non-zero exit status, or
- the `--json` payload carries no terminal verdict / no structured `result`
  payload, or
- the rendered text reads as in-progress ("still verifying", "continuing to
  review", partial findings with no verdict).

(Document gates via `task` are synchronous and short; the same "no terminal
verdict / partial text" tests apply, but timeout-abort is not expected there.)

**Required handling (new sub-step in the gate doc):**

1. **Do not interpret an incomplete result as approval, and do not interpret it
   as findings.** It carries no verdict. Treat it as "review not yet known."
2. **Give the review room to finish, then recover best-effort, bounded.** The
   installed companion runs `adversarial-review` **foreground only** —
   `handleReviewCommand` parses a `background` flag but always calls
   `runForegroundCommand`; only `task` has a background-launch path. So the gate
   cannot rely on a job id returned up front. Instead:
   a. Invoke the review under an **explicit, generous harness command timeout**
      (well above the default) so a normal-length review is not aborted
      mid-flight. The plan sets the concrete value.
   b. If the call still returns without a terminal verdict, attempt **best-effort
      recovery** without re-running the review: review jobs are tracked
      (`createCompanionJob`/`runTrackedJob` persist job state to disk), so query
      the most recent review job with `status --json` / `status <job-id> --json`
      and read any stored verdict/findings via `result <job-id> --json`. The
      authoritative signals are the job **status** (`queued`/`running` = not
      done; terminal otherwise) and the stored **`result`** payload. The plan
      pins the exact job-discovery command and JSON field names against the
      installed companion.
   c. If recovery shows the job is still `running`, wait and re-query up to **2
      additional poll cycles** by default. A poll cycle is **not** a review round
      — it does not consume the convergence/backstop budget from §B. Rounds count
      review *content* iterations; polls count waiting for *one* review to
      finish.
3. **If still incomplete after the bounded recovery, hand back to the user** as
   "Codex review did not complete (still running / aborted before verdict)" —
   never silently pass. The user decides: wait longer, skip this gate, or
   proceed without it. Like every other gate failure this degrades to "no Codex
   review," not "Codex approved."

**No background path for code gates (constraint, not a recommendation).** Adding
true background launch to `adversarial-review` would require changing
`codex-plugin-cc`, which is a Non-Goal (the fork does not own the companion). The
mitigation for slow reviews is therefore the generous explicit timeout in step
2a plus the best-effort recovery in 2b/2c — *not* `--background`. If a future
companion version adds review background support, the gate can adopt the
job-id-up-front recovery then; until it does, the gate doc must not instruct
`--background` for code gates. Synchronous `task` document gates are short and
unaffected.

**New Red Flag** (added to the gate doc and echoed in SDD's Red Flags):

> **Never** treat an unfinished, timed-out, or "still verifying" Codex result as
> "no findings" / approval. Incomplete is not a pass. Poll to completion or
> surface it — do not infer a verdict Codex did not give.

### D. Hand-back (§6 update)

The hand-back summary additionally reports: round count and whether the loop
exited by **convergence** or **backstop**, plus whether an **incompletion**
occurred and how it was resolved (polled to completion / surfaced to user).

## File-Level Change Map

All changes are to hyperpowers-owned markdown. Most logic lives in the single
shared gate doc; the skill files mostly inherit it, keeping the change focused
and avoiding drift.

| File | Change |
|------|--------|
| `skills/requesting-code-review/codex-review-gate.md` | Core. §3: round-aware re-review preamble + ledger reference per recipe. New section: round-ledger spec (Resolved/Declined/Still-open). §4/§5 rewrite: **incomplete** outcome + bounded poll; convergence stop-rule; per-gate backstop table. New Red Flag (incomplete ≠ approve). §6: report round count, convergence-vs-backstop exit, and any incompletion. |
| `skills/subagent-driven-development/SKILL.md` | Update both gate references (per-task, final) to the new caps; echo the incomplete-≠-approve Red Flag; confirm backstop-with-unresolved interaction with continue-between-tasks. |
| `skills/brainstorming/SKILL.md` | Spec gate: note doc backstop = 4 and ledger/convergence behavior (light touch; logic inherited from gate doc). |
| `skills/writing-plans/SKILL.md` | Plan gate: same light touch as brainstorming. |
| `skills/requesting-code-review/SKILL.md` | Code-review gate: reference new caps + completion handling (light touch; already defers to gate doc). |

## Testing

- **Doc-contract assertions.** Extend `tests/codex-review-gate/test-gate-contract.sh`
  to assert the gate doc contains the new contract elements: the **incomplete**
  outcome, the convergence stop-rule, the per-gate backstop numbers, the new Red
  Flag, and the round-ledger section. Matches how that test already works.
- **Skill-behavior evals (release gate).** These are behavior-shaping changes to
  tuned content. Per the contributor guide ("Skill Changes Require Evaluation":
  adversarial pressure-testing, before/after evidence kept with the change),
  passing these evals — or recording the equivalent evidence below — is an
  **acceptance condition for release**, not optional follow-up:
  - a scenario reproducing the transcript (a slow/partial/aborted Codex result)
    confirming Claude no longer rationalizes it as a pass;
  - a moving-target scenario confirming the convergence stop-rule ends the loop;
  - before/after comparison of round counts on a re-review that previously hit
    the cap.
  These run in `hyperpowers-evals/` from a real terminal (the REPL sandbox
  cannot complete live quorum runs). **Acceptable substitute when live quorum
  runs cannot be completed in the implementation environment:** documented
  manual transcripts on at least one harness demonstrating each scenario's
  expected behavior, committed with the change as the before/after evidence the
  contributor guide requires. Release does not proceed without one or the other.

## Release

Per the fork's convention, every gate change bumps the version across all
declared manifests. The manifests are **already at `6.0.5`** (bumped by the most
recent gate-handoff change), so this change bumps **`6.0.5 → 6.0.6`**. The plan
must read the current manifest version before bumping rather than hard-coding a
target — do not assume `6.0.5` is still the baseline at implementation time. The
bump covers every path listed in `.version-bump.json`. Nothing is committed
without explicit user approval.
