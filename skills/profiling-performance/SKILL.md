---
name: profiling-performance
description: Use when code is slower than expected, latency or throughput has regressed, memory/allocation use is unexplained, a hot loop is suspected, a throughput ceiling is hit, or optimization is being considered without measured bottleneck evidence. Use before any performance rewrite.
---

# Profiling Performance

## Overview

Random guesses waste effort on non-bottlenecks. Optimizations that change results invalidate correctness.

**Core principle:** Measure first, protect correctness, optimize in payoff order, then re-measure.

**The two failure modes this skill prevents:**
1. **Optimizing the wrong thing** — effort spent off the bottleneck is wasted (Amdahl's Law).
2. **Silently changing results** — a "faster" version that computes different answers can invalidate downstream correctness.

## When to Use

Use when:
- Code is slower than expected
- You need to understand where time/memory/resources go
- Performance regressed and you don't know why
- You're asked to "make it faster" without specific guidance
- About to optimize based on code inspection alone
- Need to establish a baseline before refactoring

**Use this BEFORE proposing optimizations.** Measurement reveals the real bottleneck; guessing from code is unreliable.

## Establish a Correctness Baseline

**BEFORE changing anything:**

1. **Capture reference outputs** for representative inputs and edge cases
   - Run the current code
   - Save results (return values, side effects, logs)
   - Include edge cases: empty inputs, boundary conditions, error paths

2. **Choose an explicit comparison rule** (with your human partner)
   - **Bitwise identical** — when exact match matters (cryptography, checksums, deterministic simulation)
   - **Absolute + relative tolerance** — when floating-point or numerics involved (e.g., `|new - ref| < ε_abs OR |new - ref| / |ref| < ε_rel`)
   - Document the chosen rule

3. **Understand "differs from reference ≠ worse"**
   - Floating-point reassociation can improve accuracy (different rounding)
   - If new output differs but is *more accurate* than reference, that's a win
   - Always verify against ground truth when results differ

4. **Build a minimal harness if none exists**
   - Offer to create a simple test that runs the code and compares output
   - Must be runnable, automated, fast enough to iterate
   - No harness → no safe optimization

## Find the Real Bottleneck (Measure, Don't Guess)

**Smallest useful measurement first:**

1. **Run the program with representative input**
   - Real workload, not toy data
   - Measure total runtime first (baseline)

2. **Profile to find where time actually goes**
   - Use appropriate profiler for the language (see Language Packs below)
   - Identify hot functions/loops
   - Check if result matches your intuition (often surprising)

3. **Identify what the hot region is BOUND BY**

   This is critical — the bound tells you what a fix can buy.

   **Generalized bound axis:**
   - **Compute-bound** — CPU saturated doing arithmetic/logic
   - **Memory-bandwidth-bound** — saturating RAM throughput (streaming data)
   - **Memory-latency-bound** — cache misses, random access patterns
   - **Allocation/GC-bound** — time spent allocating or garbage collecting
   - **I/O or syscall-bound** — disk, file operations
   - **Network/DB-bound** — remote calls, queries
   - **Lock-contention-bound** — threads waiting on locks

   **How to identify:**
   - CPU at 100%, low cache misses → compute-bound
   - High memory bandwidth saturation, streaming access → memory-bandwidth-bound
   - High cache miss rate, random access pattern → memory-latency-bound
   - Frequent allocations, GC pauses → allocation/GC-bound
   - Low CPU, waiting on I/O → I/O-bound
   - Low CPU, threads blocked → lock-contention-bound

4. **The bound determines what you can improve**
   - If compute-bound: better algorithm, SIMD, compiler flags help
   - If memory-bandwidth-bound: compression, smaller data types, reduce data movement help
   - If memory-latency-bound: cache-friendly layout, prefetch, data structure changes help
   - If allocation-bound: object reuse, arena allocation help
   - If I/O-bound: batching, async, caching help

## Rank Candidate Optimizations by Payoff

**Produce a ranked list from highest-leverage to lowest.**

Each candidate records five fields:
1. **hypothesis** — what specific change to make
2. **why-it-applies** — evidence this applies here (profile data, measurement)
3. **expected-payoff-vs-bound** — how much this addresses the identified bound
4. **confidence** — high/medium/low (based on measurement vs. theory)
5. **complexity-cost** — rough implementation cost (trivial / moderate / high)

**Candidate optimization families** (unordered checklist — rank by the identified bound):

### (a) Algorithm & Complexity
- Change O(n²) to O(n log n) or O(n)
- Replace linear scan with hash lookup
- Eliminate redundant work

**When it applies:** If profiling shows compute-bound hot loop doing repeated/redundant work.

### (b) Data Structures / Layout / Memory & Allocation
- Use contiguous arrays instead of linked structures
- Improve cache locality (struct-of-arrays vs. array-of-structs)
- Reduce allocation/GC pressure (reuse objects, arena allocators)

**When it applies:** If memory-latency-bound, allocation/GC-bound, or high cache miss rate.

### (c) Leverage the Platform
- Enable the optimizing build/JIT mode
- Build mode (release vs. debug)
- Use a tuned native numeric library or specialized codec

**When it applies:** Often a quick win with low complexity cost; try first if not already at max optimization level.

### (d) I/O / Syscalls / DB / Network
- Batch operations
- Use async/non-blocking I/O
- Add caching/memoization
- Reduce round-trips

**When it applies:** If I/O-bound or network/DB-bound.

### (e) Concurrency & Parallelism
- Parallelize independent work
- Use thread pools, worker threads
- Leverage SIMD/vectorization
- Work around the runtime's global-lock / true-parallelism limits

**When it applies:** If compute-bound and work is parallelizable; also if single-threaded on multi-core.

### (f) Micro-Level (Branch, Instruction, Hot-Path Allocation)
- Branch prediction hints
- Loop unrolling
- Inline hot functions
- Eliminate hot-path allocations

**When it applies:** After higher-level wins exhausted; requires measurement to verify.

**Final ranking is DERIVED from:** the measured bound + expected-payoff-vs-bound + confidence + complexity-cost — NOT from the list order above.

**Output this ranked list** as the primary deliverable. The `hyperpowers:optimizing-performance` skill consumes this list.

## Reconcile Against the Bound & Report Honestly

**After measurement (or if no measurement possible):**

1. **Measured wins** — explain improvement in context of the identified bound
   - "Cut memory-bandwidth 40% by switching to SoA layout"
   - "Reduced allocation rate 10× with object pooling"

2. **Hypothesis vs. fact**
   - **Measured** — you ran the benchmark and have numbers
   - **Hypothesis** — you reasoned statically but didn't measure
   - **NEVER claim a speedup without measurement**

3. **Label unmeasured claims clearly**
   - "Hypothesis: this should reduce allocations (not measured)"
   - Do NOT say "this is faster" without a benchmark

4. **If you cannot measure** (no toolchain, cannot run code)
   - State that clearly
   - Provide ranked candidates as *hypothesis to verify*
   - Do NOT apply changes and claim wins

## Output

**Primary deliverable:**
- **Bottleneck analysis** — what the code is bound by, where time goes
- **Ranked candidate list** — with the five fields per candidate
- **Validation/measurement plan** — how to verify correctness and measure improvements

This is the structured input for `hyperpowers:optimizing-performance`.

## Disposition

**When toolchain available:**
- Run profiler
- Measure baseline
- Identify bound with data

**When toolchain unavailable:**
- Reason statically about likely bound
- Flag every speedup claim as *hypothesis*
- Recommend measurement before changes

## Language Packs

Language-specific profilers, idioms, and tooling are in the reference packs. Load the matching pack on demand:

- **C++:** [cpp.md](references/cpp.md) — compiler flags, autovectorization, SIMD, modern performance idioms
- **Python:** [python.md](references/python.md) — profilers, runtime parallelism limits, numeric libraries, object/allocation overhead
- **JavaScript/Node:** [javascript.md](references/javascript.md) — runtime profiling, JIT deoptimization triggers, event loop, typed arrays

**Packs are loaded on demand** — only read the pack for the language you're optimizing.

## Red Flags

**STOP if you catch yourself:**
- "This looks slow, let me optimize it" (without measuring)
- "I'll just try X and see if it's faster" (no baseline)
- Changing code without a correctness check
- Claiming a speedup without re-benchmarking
- Optimizing micro-details before measuring the bound
- Guessing bottleneck from code inspection alone

**ALL of these mean: STOP. Measure first.**

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Obvious bottleneck from code" | Profiler often disagrees; measure to confirm |
| "Quick optimization, don't need baseline" | Without baseline you can't verify it worked or stayed correct |
| "This micro-optimization will help" | Maybe 0.1% if you're lucky; find the real bottleneck first |
| "No time to profile" | Profiling is faster than guessing wrong and rewriting twice |
| "I'll optimize everything" | Optimizing non-bottlenecks wastes time and adds bugs |
