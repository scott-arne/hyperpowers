---
name: optimizing-performance
description: Use when you intend to actually make code faster and land the change — a confirmed hot path, a performance regression, or a concrete speed/memory/throughput target — not just diagnose it. Keywords: optimize, speed up, reduce latency, benchmark-driven, performance fix, make it faster.
---

# Optimizing Performance

## Overview

This is the empirical fix workflow: **measure the baseline, change one thing, re-measure, keep only what measurably pays, revert everything else.** You consume a ranked candidate list from diagnosis and land the wins through the tuned subagent machinery, with every attempt measured against one shared baseline.

**Core principle:** A speedup exists only when you have measured it. A number you did not run is a guess wearing a result's clothes.

**Violating the letter of these rules is violating the spirit of these rules.** "I followed the intent, just faster" is how unmeasured claims and benchmark artifacts ship.

**REQUIRED SUB-SKILL:** Use hyperpowers:profiling-performance for the baseline, the bound, and the ranked candidates. If no baseline and candidate list exist yet, invoke it first — do not start optimizing without them.

**REQUIRED SUB-SKILLS** (this workflow runs on them, in order — do not improvise an ad-hoc substitute): **hyperpowers:writing-plans** (turn candidates into a batch), **hyperpowers:subagent-driven-development** (execute the batch), and **hyperpowers:requesting-code-review** together with the Codex code-review gate that subagent-driven-development already runs (Claude Code only; degrades cleanly when Codex is absent). Do **not** reach for hyperpowers:dispatching-parallel-agents — benchmark measurement stays serial (see the workflow below).

## When to Use

- You intend to **apply** performance changes and land them, not just find out why something is slow.
- You have (or will produce via profiling-performance) a measured baseline and ranked candidates.
- There is a named workload and metric you can benchmark.

**vs. hyperpowers:profiling-performance:** that skill *diagnoses only* — it measures, identifies the bound, and ranks candidates. This skill *applies* the candidates and *verifies* each one against the baseline. Diagnose there; land changes here.

## Entry Safety: No Measurement, No Empirical Optimization

The correctness, noise, and materiality gates below are meaningless without benchmark data. So this skill never "optimizes" on hypotheses.

1. **First, establish measurement.** A missing benchmark or correctness harness is a reason to *build* a minimal one (profiling-performance offers this), not a reason to skip measuring.
2. **If measurement genuinely cannot run** (no toolchain, no way to execute the code): **STOP and hand back to your human partner.** Do not apply changes. Do not report any speedup. Silent hypothesis-only "optimization" is exactly the failure these gates exist to prevent.
3. **Optional advisory-only mode (explicit opt-in only).** If your human partner asks for advice without measurement, produce a clearly-labeled advisory: the ranked candidates marked *hypothesis, unverified*, with **no code applied** and **no measured-win claims**. The keep/revert machinery is skipped because it cannot run — say so.

## The Workflow (Hybrid: SDD batch + bounded re-profile)

1. **Baseline & candidates.** Take the measured baseline + ranked candidate list from profiling-performance. Persist to the SDD scratch dir via the `sdd-dir` cache helper (the path `subagent-driven-development`'s `scripts/sdd-dir` prints — **never** `.git/`, never the working tree):
   - `baseline.json` — benchmark numbers **plus run-to-run variance**, the named workload, and the exact benchmark command.
   - the **correctness reference** — reference outputs + the agreed comparison rule (bitwise, or absolute/relative tolerance).
   - an **attempts ledger** — one row per candidate tried, its measured result, and the keep/revert decision.

   Every subagent reads this **same** baseline. The baseline is measured once and never re-measured per attempt (re-measuring makes attempts incomparable).
2. **Plan the batch.** Filter the candidates to the independent, high-confidence ones. Turn them into a plan with hyperpowers:writing-plans, **one candidate per task**, each task carrying **all five candidate fields from profiling-performance** (hypothesis, why-it-applies, expected-payoff-vs-bound, confidence, complexity-cost) plus the *exact* benchmark command and workload as execution metadata. Preserving all five keeps the producer's rationale and cost estimate available to the implementer and reviewer. Coupled or speculative candidates wait for the re-profile round.
3. **Execute via SDD with serialized measurement.** Run the batch through hyperpowers:subagent-driven-development. Hand each implementer `perf-implementer-notes.md` and each task reviewer `perf-reviewer-notes.md` (both in this skill's directory) in addition to the normal prompts. The Codex code-review gate runs through SDD's existing hook (degrades cleanly when absent). **Never parallelize benchmark tasks** — even logically independent candidates contaminate each other's numbers when their benchmarks share a host. Apply-and-measure stays strictly serial. Do not reach for hyperpowers:dispatching-parallel-agents here.
4. **Keep / revert / tie-break decision.** *You*, the coordinator, decide — you hold the baseline and the cross-attempt view. The implementer and reviewer supply evidence; they do not decide. Apply the policy below.
5. **Re-profile checkpoint (bounded).** After the batch, re-profile the kept code and reconcile against the bound. Spawn **at most one** more bounded round (plan → SDD → decide) — and only if meaningful time remains *and* new above-bar candidates surfaced. **Hard cap: 2 rounds total.** Stop when the bound is met, no new qualifying candidate appears, or the cap is hit — and state which.
6. **Isolation.** Work on the SDD branch; reverts are per-task within it, so the tree never accumulates rejected attempts. No worktrees — serialized measurement precludes parallel attempts.

## Keep / Revert / Tie-Break Policy

Apply the gates in order. A candidate must pass every gate to be kept.

1. **Correctness gate (first, no exceptions).** The change must match the correctness reference under the agreed rule. Fails → **revert.** A faster wrong answer is not an optimization. No "close enough," no tuning the check to pass.
2. **Noise gate.** Keep only if the measured speedup is distinguishable from run-to-run noise across the N runs. One run is not a measurement. If the delta sits inside the variance, it did not happen → revert.
3. **Representative-workload gate.** The win must be on the *real* workload, not a benchmark artifact. If a "speedup" exists only because the benchmark replays identical inputs the change can cache (or otherwise exploits an incidental benchmark pattern) and evaporates on representative, non-repeating data, it is not a real win → **revert.**
4. **Complexity-aware materiality bar.** A change that materially increases complexity must *also* clear an improvement bar. **Default: ≥5–10%.** If your human partner set a project bar at the start, use theirs. Trivial-complexity real wins are kept on the noise gate alone. Complexity that does not clearly pay → revert.
5. **Variant tie-break.** Among changes that pass and perform similarly, keep the **DRYest / simplest** one.

**Revert unpaid complexity.** Anything that does not clearly pay reverts to the original. "Cleaner and probably faster" is not a keep reason — if it did not clear the bar, the cleanup belongs in a separate refactor, not a perf claim.

## Final Report

Built from the attempts ledger, presented at the end. Exactly these six parts, in order:

1. **Headline result** — overall improvement on the *named* workload with the *named* metric (e.g. "3.1× faster on the 10k-row batch, wall 8.4s → 2.7s; correct within tolerance").
2. **What was kept** — each landed change: what it did, measured delta *with variance*, which bound it addressed, and its complexity cost.
3. **What was tried and reverted** — every attempt that failed a gate, with its measured result and which gate it failed. Dead ends are results; they belong here.
4. **Correctness** — the comparison rule used and confirmation every kept change stayed within it.
5. **Bound reconciliation** — did you capture what the bound allowed? What limits now, and what headroom was intentionally left.
6. **Reproducibility** — exact benchmark command(s), build mode/flags, run count (N), and machine caveats.

## Honesty Rules

- Report only numbers you actually ran **this session**.
- Unmeasured reasoning is a **hypothesis** — label it as such; never present it as a speedup.
- **Never** claim a speedup you did not benchmark before *and* after.
- **Never** estimate or extrapolate a number and present it as measured.
- **Never** hide or omit a reverted attempt — dead ends go in the report.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "It's obviously faster, no need to benchmark" | "Obvious" perf intuitions are wrong constantly. One benchmark run is ~30 seconds. Measure before AND after. |
| "One run showed it's faster" | One run is noise. Run it N≥5 times and clear the run-to-run variance, or it does not count. |
| "This rewrite is cleaner and surely faster" | Assumption ≠ measurement. If the measured delta misses the materiality bar, revert the complexity; cleaner is a separate refactor, not a perf claim. |
| "I'll estimate the speedup from the diff" | Estimated numbers are fabricated numbers. Report only what you ran. An un-run number is a lie. |
| "The reverted attempts aren't worth mentioning" | Dead ends are results. Hiding them invites the next agent to re-try them and wastes the finding. |
| "Caching the repeated inputs made it 10× faster" | That is the benchmark's artifact, not a real win — production will not replay identical inputs. If the speedup vanishes on representative data, revert it. |
| "The output looks right, I don't need a correctness check" | "Looks right" is not a check. Optimizations silently change results; without the reference comparison you are shipping a faster wrong answer. |
| "Deadline — skip the baseline, just apply it" | No baseline = no way to prove or disprove the win, and no way to revert cleanly. The baseline is the cheapest step; skipping it makes every later number meaningless. |
| "I can't run the benchmark here, but the change is sound, so I'll apply it" | No measurement → no empirical optimization. Build a harness or STOP and hand back. Do not apply and claim a win. |

## Red Flags — STOP

- Reporting a speedup you did not run this session
- A single benchmark run (N=1), or no variance reported
- Keeping a clever/complex change that did not beat the materiality bar
- Optimizing with no correctness check established
- A "win" that only appears because the benchmark replays identical inputs
- Running benchmarks in parallel (contaminated numbers)
- "I'll just estimate it from the diff"
- Hiding or omitting a reverted attempt from the report
- Applying changes when no baseline could be measured

**All of these mean: STOP. Measure honestly, gate the result, or hand back.**
