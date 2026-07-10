# Codex Design Collaboration — Eval Evidence

Date: 2026-07-10
Branch: `feat/codex-design-collaboration`
Artifacts under test (as committed at the time of testing, verbatim):

- `skills/brainstorming/codex-approach-gate.md` — "When It Fires" trigger section (commit 0057d81 lineage)
- `skills/brainstorming/SKILL.md` — checklist item 4 hook + "Exploring approaches" bullet
- `skills/requesting-code-review/codex-review-gate.md` §3 "Round-1 Algorithm Assessment" and §5 "Algorithm adjudication and lock" (through commit 53666ca, which broadened the lock escape hatch)

## 1. Methodology

Per `skills/writing-skills/SKILL.md` "Micro-Test Wording Before Full Scenarios":
fresh single-shot subagents, **one per rep, no shared history**; two arms per
edge; **6 reps per arm**; every response **read manually**; variance noted.
Rep model: Claude Sonnet (general-purpose subagent, tools forbidden by prompt,
plain-text answer only). Each rep received the guidance excerpt as in-context
"guidance in effect," a stimulus (original idea + answered clarifying Q&A), and
was asked to state its next action and the reason.

**Control-as-baseline rationale.** A classic RED baseline ("watch the agent
fail without the skill") is uninformative for this trigger: without the edit,
Claude trivially never consults Codex during brainstorming — there is nothing
to observe failing in an interesting way. The control arm therefore serves as
the no-guidance baseline: identical brainstorming step text and stimulus with
**all approach-gate content removed**. Its value is demonstrating that the
baseline never consults Codex on its own, so any behavioral difference in the
variant arm is attributable to the gate wording, and that the trivial-edge
variant result (not firing) is a real discrimination rather than the default.

Arms:

- **Variant:** brainstorming checklist item 4 + "Exploring approaches" bullets
  (including the gate hooks) + the companion doc's "When It Fires" section,
  all verbatim.
- **Control:** the same brainstorming text with every mention of the approach
  gate removed. Control reps were asked neutrally to state their next action
  and to name any external tool/agent/reviewer they would consult.

Scoring (manual read of all 36 responses): the decision signal is the stated
next action — "run the Codex approach gate" vs. "proceed with my own
approaches." Trivial edge scores variant **false-fires**; architectural and
explicit-request edges score variant **misses**. Convergence = same decision
AND same cited trigger reason across reps.

## 2. Trigger micro-tests

### 2.1 Trivial edge — config-change brainstorm (gate must NOT fire)

Stimulus: "Rename our CLI flag `--output-dir` to `--out-dir`," with answered
Q&A (deprecated alias for two releases; help text + README update only).

| Arm | Reps | Fired gate / consulted Codex | Score |
|-----|------|------------------------------|-------|
| Variant (gate wording) | 6 | 0 | **0/6 false-fires** |
| Control (no gate content) | 6 | 0 | 0/6 Codex consults (baseline) |

Manual-read notes: all 6 variant reps chose "proceed without the gate" and all
6 cited the same clause — "skip silently when the task is trivial or
mechanical: a single obvious implementation, a config change, a small fix" —
most also noting the absence of an explicit partner request. **Full
convergence** (same decision, same cited reason). Control: 5/6 proceed
directly to proposing approaches; 1/6 would first read the CLI parsing code
(internal codebase inspection, not an external consult). No control rep
mentioned Codex.

### 2.2 Architectural edge — sensor-ingest system (gate MUST fire)

Stimulus: ingest system for ~200 field devices into analytics Postgres, with
answered Q&A establishing genuinely different viable shapes: ~5-minute
freshness (batch feasible), 2M→10M readings/day, devices support either push
webhooks or scheduled polling, two-person team on Postgres + Kubernetes, no
broker today but open to one.

| Arm | Reps | Fired gate / consulted Codex | Score |
|-----|------|------------------------------|-------|
| Variant (gate wording) | 6 | 6 | **0/6 misses** |
| Control (no gate content) | 6 | 0 | 0/6 Codex consults (baseline) |

Manual-read notes: all 6 variant reps chose "run the gate now" and all 6 cited
the same clause — "≥2 genuinely different viable architectures, algorithms, or
data models with materially different tradeoffs — not variations of one
shape." The specific alternatives each rep enumerated varied (push vs. poll,
direct-to-Postgres vs. broker-mediated, batch vs. streaming, one rep added
time-series data-model options), but the decision and the cited trigger were
identical across all six — **converged on decision and reason**, with benign
variation in supporting detail. Control: 5/6 proceed directly ("standard
ingest patterns, constraints clear"); 1/6 would do codebase reconnaissance
first. No control rep consulted or mentioned any external reviewer.

### 2.3 Explicit-request edge — trivial task + partner asks for Codex (gate MUST fire)

Stimulus: the same trivial flag-rename stimulus plus, after the Q&A, the
partner adding: "Before you propose anything, get Codex's take on approaches
too."

| Arm | Reps | Fired gate / consulted Codex | Score |
|-----|------|------------------------------|-------|
| Variant (gate wording) | 6 | 6 | **0/6 misses** |
| Control (no gate content) | 6 | 6 (ad-hoc) | — see note |

Manual-read notes: all 6 variant reps fired the gate and all 6 cited the same
clause — "fire when your human partner explicitly requests Codex input on
approaches (any phrasing), even for a task that looks straightforward" — with
several explicitly stating the request overrides the trivial-skip. **Full
convergence.** Control: all 6 also said they would consult Codex, because a
direct partner instruction is followed by the baseline model regardless of
guidance. However, every control rep improvised the mechanism: hand Codex the
task plus the rep's own context, ask it for approaches, "synthesize" — none
produced the gate's actual contract (blind handoff excluding Claude's own
candidate approaches, one-shot with no fix loop, provenance tags, merit-based
judging), and one guessed at the wrong mechanism ("Codex spec review"). Honest
reading: on this edge the wording's measurable contribution is not the
decision to consult (the baseline already obeys explicit instructions) but the
**procedure** — the variant reps knew to run `codex-approach-gate.md`
specifically, which carries the blind-handoff/one-shot/provenance contract.

### 2.4 Trigger conclusions

- All three edges bind with the wording **as committed**: 0/6 false-fires on
  trivial, 0/6 misses on architectural, 0/6 misses on explicit-request.
  No wording changes were needed; `tests/codex-review-gate/test-gate-contract.sh`
  passes unchanged (STATUS: PASSED, run 2026-07-10 on this branch).
- Variance was low everywhere it matters: within each variant arm, all six
  reps made the same decision and cited the same clause of "When It Fires."
  The only variation was in illustrative detail (which architectural
  alternatives a rep listed), which does not affect the decision.
- Control arms confirm the baseline: with no gate content, Codex is never
  consulted spontaneously (0/12 across trivial + architectural), so the
  architectural-edge firing is attributable to the wording, and the
  trivial-edge non-firing is a real discrimination by the skip clause rather
  than default inaction.

## 3. Task 1 smoke probe (from the Task 1 report)

Summarized from the Task 1 implementation report (commit f3b97e6): one fresh
subagent was dispatched with the companion doc + SKILL.md hooks and an
architecture-rich scenario, with Codex stubbed absent. Verified by manual
read: (1) the gate fired on ≥2 architectural alternatives; (2) the blind
handoff excluded Claude's own candidate approaches (original request, Q&A,
codebase facts only); (3) on Codex-unavailable it emitted the exact
approach-specific notice ("this brainstorm proceeds without independent Codex
approaches"); (4) it degraded gracefully into the normal 2-3-approaches flow;
(5) one-shot honored — no fix loop, no re-review. RED/GREEN needle evidence:
6 new assertions failed before the docs existed, 62/62 passed after.

## 4. Lock contract probe (§5 "Algorithm adjudication and lock")

Two fresh single-shot subagents (Sonnet, tools forbidden), each given the
current §5 text **verbatim** (including the broadened lock line and the three
ledger formats) plus a synthetic round-1 plan-review result, and asked what
happens next per the doc.

### 4.1 Probe A — `Verdict: approve`, no blocking findings, one `alternative-suggested`

Asked to walk both adjudication branches. All pass criteria met on manual read:

| Criterion | Result |
|-----------|--------|
| Adjudicates BEFORE applying the loop's exit rule | PASS — quoted the "before applying the loop's exit rule / never dropped by an early `approve` exit" clause and stated the assessment must be adjudicated despite the approve verdict |
| Accept branch: revise + lock + exactly one re-review round | PASS — revise affected tasks keeping interfaces/cross-refs consistent, record lock, one normal re-review; quoted "a materially revised plan is never handed off without a confirming Codex pass" |
| Decline branch: lock + exit, NO re-review | PASS — quoted "a decline changes no plan content, so no re-review is needed" |
| Round-2 prompt omits the assessment section | PASS — stated explicitly, citing "assessment omitted" |
| Round-2 prompt carries the lock line verbatim | PASS — reproduced the full lock line word-for-word, appended to the round-aware preamble |
| Ledger entries use the documented formats | PASS — accept branch used `Algorithm locked: <new> (was <old>) — <rationale>`; decline branch used `Algorithm locked: <original> — Codex suggested <alt>, declined: <reason>` |

### 4.2 Probe B — `Verdict: needs-attention`, one High blocking finding, one `alternative-suggested` (normal-loop path)

Scenario instructed: controller accepts the alternative and fixes the blocking
finding. All pass criteria met on manual read:

| Criterion | Result |
|-----------|--------|
| Adjudication timing | PASS — adjudicate immediately after parsing round-1 output, before the exit rule; fix work and lock proceed together per the needs-attention bullet |
| Pre-round-2 actions | PASS — revise plan for the accepted alternative, fix the interface mismatch, write the ledger with both the algorithm lock entry and the resolved-finding entry |
| Ledger entry format | PASS — `Algorithm locked: <new> (was <old>) — <rationale>` format (the old choice's name was lightly abbreviated; format and referents intact) |
| Round-2 prompt composition | PASS — round-aware preamble quoted verbatim, lock line quoted verbatim as the appended line, Algorithm Assessment section explicitly omitted |

### 4.3 Lock probe conclusion

The current §5 text did not mislead either probe: both subagents derived the
adjudicate-before-exit ordering, the asymmetric re-review rule (accept → one
confirming round; decline → none), the correct ledger formats, and a round-2
prompt with the lock line verbatim and the assessment omitted. No §5 wording
changes were needed; contract-test needles are unchanged.

## 5. Honest conclusions and limitations

- **What is established:** the trigger wording discriminates cleanly across
  the three tested edges at N=6 per arm with zero misfires and full
  decision/reason convergence, and the §5 lock contract is executable from the
  text alone by a fresh reader in both the early-exit and normal-loop paths.
- **Explicit-request edge caveat:** the control arm also consults Codex when
  the partner directly asks (6/6) — baseline instruction-following, not the
  wording. The wording's contribution there is routing the request through the
  gate's contract (blind handoff, one shot, provenance) rather than an ad-hoc
  consultation; variant reps named the gate doc, control reps improvised.
- **Scope limits:** these are single-shot micro-tests of the wording at one
  simulated decision point on Sonnet — not full brainstorming sessions, not
  adversarial pressure scenarios, and not run on other model tiers. The
  stimuli are clear exemplars of each category; genuinely borderline cases
  (e.g., a medium task with arguable alternatives) were not probed and the
  micro-tests say nothing about them. Full-scenario behavior is covered
  separately by the Task 1 smoke probe (above) and the Task 4 eval scenarios.
- **No invented numbers:** every count above comes from a manually read
  response; all 36 trigger reps and both lock probes are tallied exactly as
  observed.
