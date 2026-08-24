## 5. Fix-and-re-review loop (converge, then stop)

After the first Codex review, every later round is a **re-review against known
state**, not a cold re-derivation. The loop ends as soon as the work is actually
done — it does not burn a fixed attempt budget.

### Round ledger (re-review memory)

Before re-running Codex (round 2+), write a small handoff file inside the
per-run `GATE_DIR` from §3 (e.g. `"$GATE_DIR/codex-round-ledger.md"`).
Do not paste it into your own context — hand it over as a file path. For each
completed round it records:

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

If a re-review round returns new Minor (medium/low) findings anyway, they are
out of contract: record them in the round ledger as noted (and in the skill's
Minor ledger, if it keeps one), do not fix them in the loop, do not dispatch a
fix for them, and do not let them delay convergence. Only blocking findings
drive the loop.

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

Ledger entry formats (one entry per assessed choice, so the round-2+ lock line
always has explicit referents):
- `Algorithm locked: <new> (was <old>) — <rationale>`
- `Algorithm locked: <original> — Codex suggested <alt>, declined: <reason>`
- `Algorithm locked: <choice> — assessed appropriate, no alternative suggested`

On plan-gate re-reviews, append this line to the round-aware preamble and omit
the Algorithm Assessment section from the prompt:

> Algorithm choices are locked per the ledger; do not re-open them absent
> a new blocking (Critical or High) defect in the locked choice — correctness,
> feasibility, or fit at the stated constraints and scale. Advisory preference
> or optimization alternatives remain locked.

### The loop

The loop's exit rule is mechanical: a round converges only when
`verdict-normalize` returns `"result":"approved"` for that round's captured
output. `blocking` continues the fix loop; `incomplete` follows §4b recovery
and never converges the loop by itself.

0. Before composing ANY LOGICAL round (round 1 included), advance the
   mechanical counter ONCE with this gate's ceiling from the backstop
   table — a round-1 lens batch is one logical round: one `gate-round`
   call covers composing and launching every lens prompt in the batch:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/gate-round" "$GATE_DIR" --ceiling <4 for document gates, 3 for code gates, the task's remaining shared-cap budget for SDD's per-task gate (5 minus the task's non-gate fix rounds; see hyperpowers:subagent-driven-development)> --gate <spec|plan|task|final|adhoc>
   ```

   `"verdict":"proceed"` composes the round. `"verdict":"backstop"` means the ceiling is already spent: do NOT invoke Codex again for this gate — follow the backstop stop-condition below. A non-zero `gate-round` exit is an internal failure: treat it as `backstop` — do not invoke Codex for this round, and if backstop-round fixes ship, use the full append command written in the Backstop-hit stop-condition below (no `reminder` JSON exists on this path).
1. The approval set is every capture required for the latest round: round 1's set is every lens capture; a re-review round's set is its single capture. An empty capture set never approves. The round converges only when EVERY capture in the set normalized `"result":"approved"`, this round raised no blocking findings, and the round ledger has no still-open blocking findings. If converged → done; go to step 6.
2. Otherwise address each blocking finding: for a document, edit the spec/plan; for
   code, dispatch a fix through the skill's existing fix path (for SDD's per-task
   gate that path resumes the implementer per SDD's fix loop, not a fix subagent).
   You MAY decline a finding with explicit reasoning instead of fixing it.
   Record resolutions, declines, and still-open items in the round ledger.
   After any code fix, re-run the same Claude reviewer gate before re-running Codex.
   For SDD per-task gates, that reviewer gate is SDD's scoped re-review.
3. Re-run the same Codex invocation (with the round-aware preamble and ledger
   path) over the updated artifact once the relevant Claude review gate is clean
   (for SDD per-task gates, once SDD's scoped re-review is clean).
4. **Stop when any holds:**
   - **Approved (converged):** EVERY capture required for the latest round normalized `"result":"approved"`, this round raised no blocking findings, **and** the round ledger has no still-open blocking findings. A round that normalizes to `approved` while the ledger shows an unresolved blocker has not converged (the blocker may predate this round); a round that normalizes to `blocking` has not converged regardless of ledger state — do not exit without a normalized approval.
   - **Backstop hit** — the per-gate round ceiling below is reached. Stop and hand back with any unresolved blocking findings listed; do not loop indefinitely. Fixes applied in the backstop round ship without a confirming Codex pass — flag them in the §6 hand-back as verified by the Claude reviewer and tests only, not re-reviewed by Codex. When backstop-round fixes ship, also record them durably using the `reminder` template from `gate-round`'s backstop output: `bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class backstop-fix --gate <task|final|adhoc> --base <task BASE sha> --head <head sha> --gate-dir "$GATE_DIR" --note "<one line>"` — and name the returned event id in the §6 hand-back.
If any stop condition conflicts with the mechanical exit rule, the mechanical rule governs: no normalized approved, no converged exit.

### Per-gate round backstops

| Gate | Recipe | Backstop |
|------|--------|----------|
| Spec / Plan (document gates) | task | 4 |
| SDD per-task (code gate) | adversarial-review | shares SDD's five-round per-task fix cap (see hyperpowers:subagent-driven-development) — no separate Codex ceiling |
| Final / code-review requests (code gates) | adversarial-review | 3 |

Document gates get 4 rounds (cheap: a text edit + a `task` re-run). Code gates
get 3 rounds (expensive: fix subagent + Claude-reviewer re-run + a fresh
`adversarial-review` per round) — except SDD's per-task gate, which has no
ceiling of its own: its rounds are fix-loop rounds and stop at the task's
shared five-round cap. Convergence usually stops the loop earlier; the
backstop is a true backstop, not the common exit.

> **Red Flag — Never** invoke the companion for a review round without a `proceed` from `gate-round`
> for this `GATE_DIR`. The agent's own round count is not authoritative — the counter file is; a
> backstop verdict means the ceiling is spent no matter what your recollection says.

## 6. Hand back

Summarize concisely before returning to the skill's normal next step:

- Codex verdict, the round count, and whether the loop exited by convergence or
  by hitting the backstop,
- what Codex flagged (by mapped severity),
- what was fixed,
- what was declined and why,
- any unresolved blocking findings if the backstop was hit,
- whether any fixes were applied after the last Codex round (backstop exits) —
  state explicitly that those fixes are not re-reviewed by Codex,
- any Minor findings noted but not fixed, including out-of-contract Minors
  raised on re-review,
- whether an incomplete result occurred and how it was resolved (recovered via
  `status`/`result`, or surfaced to the user),
- the review runtime: the codex-plugin-cc version (`CODEX_VERSION` from the §1
  preflight) and the Codex model and reasoning effort the reviews ran with — read
  `model` and `model_reasoning_effort` from
  `${CODEX_HOME:-$HOME/.codex}/config.toml`; the companion runs reviews at
  these config defaults.

Then continue the skill (present to user / mark complete / finish branch).

