---
sources: skills/optimizing-performance skills/profiling-performance/SKILL.md skills/communication/SKILL.md
source-digest: 113146df236e
---
# optimizing-performance

`optimizing-performance` lands speedups one measured candidate at a time, keeps only the changes that clear its correctness, noise, and materiality checks, and reverts the rest.

:::{card} At a glance
**Category:** Performance · **Triggers on:** you intend to make code faster and land the change (a confirmed hot path, a regression, or a concrete speed, memory, or throughput target) · **Hands off to:** {doc}`writing-plans`, {doc}`subagent-driven-development`, {doc}`requesting-code-review`, and {doc}`communication` · **Harness notes:** the Codex code-review gate it relies on runs under Claude Code only and is skipped when Codex is absent
:::

## When it triggers

The skill's description says to use it when you intend to apply performance changes and land them, and not only diagnose the slowness. It names a confirmed hot path, a performance regression, or a concrete speed, memory, or throughput target. The skill also requires a named workload and a metric the agent can benchmark. It separates itself from {doc}`profiling-performance`, which diagnoses only, and this skill applies the candidates and checks each one against the baseline.

Example requests:

- "Profiling showed the tokenizer is the hot path. Optimize it and land the change."
- "Get the report export under our latency target."
- "Reduce memory use in the batch job, with benchmarks to show it worked."

## What it does

The skill's rule is no measurement, no empirical optimization. If measurement cannot run at all (no toolchain, no way to execute the code), the agent stops and hands the work back to you and applies nothing. A missing benchmark or correctness harness is a reason to build a minimal one. You can explicitly ask for advice without measurement. The agent then produces a labeled advisory with the candidates marked as unverified hypotheses, no code applied, and no measured-win claims.

The workflow is a batch run through subagent-driven development, followed by one bounded round of re-profiling:

1. **Baseline and candidates.** The agent takes the measured baseline and ranked candidate list from {doc}`profiling-performance`, invoking that skill first if they do not exist. It saves them in a scratch directory: `baseline.json` (numbers with run-to-run variance, the workload, and the exact benchmark command), the correctness reference with its comparison rule, and an attempts ledger. Every attempt reads this one baseline. It is measured once and not re-measured per attempt, which would make attempts incomparable.
2. **Plan the batch.** The independent, high-confidence candidates become a plan through {doc}`writing-plans`, with one candidate per task. Each task carries all five candidate fields plus the exact benchmark command. Coupled or speculative candidates wait for the re-profile round.
3. **Execute with serialized measurement.** The batch runs through {doc}`subagent-driven-development`. Each implementer gets the performance implementer notes, each reviewer the reviewer notes, and the Codex code-review gate that development already runs applies (Claude Code only). Benchmarks run strictly one at a time, because attempts that share a host contaminate each other's numbers. The skill says not to use {doc}`dispatching-parallel-agents` here.
4. **Keep, revert, or tie-break.** The coordinating agent decides, because it holds the baseline and the view across attempts. Implementers and reviewers supply evidence and do not decide.
5. **Re-profile checkpoint.** After the batch, the agent re-profiles the kept code and reconciles against the bound. It starts at most one more round, and only when meaningful time remains and new candidates above the bar surfaced. The hard cap is two rounds, and the agent states which stop condition applied.
6. **Isolation.** Work stays on the development branch, and reverts happen per task within it. The skill says to use no worktrees, since serialized measurement rules out parallel attempts.

A candidate must pass every gate, in order, to be kept:

1. **Correctness.** The change must match the correctness reference under the agreed rule. A failure is reverted, with no "close enough" and no tuning the check to pass.
2. **Noise.** The measured speedup must be distinguishable from run-to-run noise across several runs. One run does not count.
3. **Representative workload.** The win must hold on the real workload. A speedup that exists only because the benchmark replays identical inputs the change can cache is reverted.
4. **Materiality.** A change that adds meaningful complexity must also clear an improvement bar. The skill sets a default bar and tells the agent to use yours if you set a project bar at the start. Trivial-complexity wins are kept on the noise gate alone.
5. **Tie-break.** Among changes that pass and perform similarly, the agent keeps the simplest.

Anything that does not clearly pay reverts to the original. "Cleaner and probably faster" is not a reason to keep a change, and the skill sends that cleanup to a separate refactor.

The final report has six parts, in order: the headline result on the named workload and metric, what was kept (with measured delta and variance, the bound it addressed, and its complexity cost), what was tried and reverted (with the gate each failed), correctness, bound reconciliation, and reproducibility (the exact commands, build mode, run count, and machine caveats). Its honesty rules limit it to numbers the agent ran this session, label unmeasured reasoning as hypothesis, and require every reverted attempt to appear.

## Why it exists

The skill's core principle is that a speedup exists only when it has been measured, and it calls an unrun number a guess wearing a result's clothes. It adds that violating the letter of the rules violates their spirit, which closes the "I followed the intent" route. The rationalizations table and red-flags list cover estimating a speedup from the diff, a single benchmark run, caching repeated benchmark inputs, and applying a change when no baseline could be measured. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`; none of them concerns this skill.

## Pros

- Every kept change has a measured delta with variance against one shared baseline.
- Correctness is checked first, so a faster wrong answer is reverted.
- Complexity has to pay for itself, so the change set stays small.
- Reverted attempts appear in the final report, so dead ends are not retried.
- The coordinating agent decides keep or revert, which keeps the decision in one place.

## Cons and costs

- It runs the full planning, subagent, and review machinery for each batch, which is heavy for a single small change.
- Benchmarks run strictly one at a time, so a batch takes as long as its attempts added together.
- It needs a runnable benchmark, a correctness reference, and a representative workload. When measurement cannot run, the skill stops and hands the work back.
- Several benchmark runs per candidate add wall-clock time to every attempt.
- The two-round cap can leave known candidates unattempted.
- The Codex review gate it relies on works under Claude Code only.

## Skipping or overriding

The skill gives no way to skip measurement or the gates. Two choices belong to you. You can set the improvement bar for complex changes at the start, and the skill says to use yours in place of its default. You can also ask for advisory-only output without measurement, which produces unverified hypotheses and applies no code. When you only want a diagnosis, ask for {doc}`profiling-performance` and not this skill.

## Works with

- {doc}`profiling-performance` supplies the baseline, the bound, and the ranked candidates, and this skill invokes it first when they are missing.
- {doc}`writing-plans` turns the candidates into a plan, one candidate per task.
- {doc}`subagent-driven-development` executes the batch, with the performance notes handed to implementers and reviewers.
- {doc}`requesting-code-review` is a required sub-skill, together with the Codex code-review gate that subagent-driven development already runs.
- {doc}`communication` is a required sub-skill for the final report.
- {doc}`dispatching-parallel-agents` is named only to say it is not used here.

## Under the hood

{source}`skills/optimizing-performance/SKILL.md` holds the workflow, the gate order, the report format, the honesty rules, and the rationalizations table. Two addenda sit beside it:

- {source}`skills/optimizing-performance/perf-implementer-notes.md` tells an implementer to do exactly one candidate, read the shared baseline, run the exact benchmark command several times, and report evidence without deciding keep or revert.
- {source}`skills/optimizing-performance/perf-reviewer-notes.md` tells a reviewer to check the benchmark method (run count, representative workload, dead-code guards, warmup, comparable conditions), confirm the correctness check ran, and report evidence without deciding keep or revert.
