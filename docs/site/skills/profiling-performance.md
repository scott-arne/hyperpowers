---
sources: skills/profiling-performance skills/optimizing-performance/SKILL.md skills/communication/SKILL.md
source-digest: 270b8a4d981c
---
# profiling-performance

`profiling-performance` makes the agent measure where time or memory goes, and protect the program's results, before it proposes any speedup, then hands you a ranked list of candidate fixes.

:::{card} At a glance
**Category:** Performance · **Triggers on:** code slower than expected, a latency or throughput regression, unexplained memory use, a suspected hot loop, or optimization proposed without measured evidence · **Hands off to:** {doc}`optimizing-performance` (the ranked candidate list) and {doc}`communication` (the deliverable you read) · **Harness notes:** none
:::

## When it triggers

The skill's description says to use it when code is slower than expected, latency or throughput has regressed, memory or allocation use is unexplained, a hot loop is suspected, a throughput ceiling is hit, or someone wants to optimize without measured bottleneck evidence. It adds that it comes before any performance rewrite.

Example requests:

- "The nightly import takes three times as long as last month. Find out why."
- "Make this parser faster."
- "Memory use keeps climbing during the batch run and I don't know what holds it."

## What it does

The skill diagnoses and does not apply changes. Its output is a bottleneck analysis, a ranked candidate list, and a plan for validating and measuring each improvement.

1. **Correctness baseline.** Before anything changes, the agent captures reference outputs for representative inputs and edge cases (empty inputs, boundaries, error paths). With you, it picks an explicit comparison rule: bitwise identical when an exact match matters, or absolute plus relative tolerance for floating-point work. The skill points out that a result that differs from the reference is not automatically worse, since reassociated floating-point math can be more accurate, so differences are checked against ground truth. If no test harness exists, the agent offers to build a minimal one, and the skill says no harness means no safe optimization.
2. **Measure and find the bottleneck.** The agent runs the program on a representative workload (the skill says real workload, not toy data), records total runtime, and profiles with a tool suited to the language. It then names what the hot region is bound by: compute, memory bandwidth, memory latency, allocation or garbage collection, I/O or syscalls, network or database, or lock contention. The bound determines which fixes can pay off.
3. **Rank candidates by payoff.** Each candidate gets five fields: hypothesis, why it applies, expected payoff against the bound, confidence, and complexity cost. The candidates come from six families: algorithm and complexity, data layout and allocation, leveraging the platform (such as build mode or a tuned library), I/O and network, concurrency, and micro-level changes. The final order comes from the measured bound, payoff, confidence, and cost. The order of the families in the skill does not set it.
4. **Reconcile and report honestly.** The agent separates measured claims from hypotheses and labels the second kind. If it cannot measure (no toolchain, code cannot run), it says so, gives the ranked candidates as hypotheses to verify, and does not apply changes or claim wins.

The language packs hold profilers and idioms for C++, Python, and JavaScript or Node. The agent loads only the pack for the language it is working in.

## Why it exists

The skill names two failures. Effort spent away from the real bottleneck is wasted, and a faster version that computes different answers can invalidate everything downstream. Its red-flags list and rationalizations table cover the thoughts that skip measurement, such as "this looks slow, let me optimize it", "no time to profile", and claiming a speedup without re-benchmarking. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`; none of them concerns this skill.

## Pros

- The agent finds the bound before choosing a fix, so the fix matches what limits the program.
- Reference outputs and an agreed comparison rule catch a speedup that changes results.
- Each candidate carries its evidence, confidence, and cost, so you can see why the first one is first.
- Unmeasured claims are labeled as hypotheses, and the skill forbids reporting a speedup without a benchmark.
- Language packs supply concrete profilers for C++, Python, and JavaScript.

## Cons and costs

- Setup comes before any speedup: reference outputs, a comparison rule, and possibly a new harness. A quick, obvious tweak waits for all of it.
- It needs code that can run with a representative workload. Without a toolchain, the result is a list of hypotheses.
- The skill stops at diagnosis. Landing a change takes a second skill.
- The language packs cover three languages. For other languages, the general method applies without a pack.
- Choosing the comparison rule takes your input on how much numeric difference is acceptable.

## Skipping or overriding

The skill gives no skip option. Its red-flags list says every shortcut thought means stop and measure first. You still shape the work through the comparison rule it asks you to agree on, and by telling the agent whether you want diagnosis only or the fix as well. For the fix, the agent moves to {doc}`optimizing-performance`.

## Works with

- {doc}`optimizing-performance` consumes the ranked candidate list, baseline, and bound. That skill names this one as a required sub-skill and invokes it first when no baseline and candidate list exist.
- {doc}`communication` is a required sub-skill for writing the deliverable you read.

## Under the hood

{source}`skills/profiling-performance/SKILL.md` holds the baseline rules, the bound axis, the five candidate fields, the six candidate families, the red flags, and the rationalizations table. Three language packs sit under {source}`skills/profiling-performance/references/`:

- {source}`skills/profiling-performance/references/cpp.md`
- {source}`skills/profiling-performance/references/python.md`
- {source}`skills/profiling-performance/references/javascript.md`
