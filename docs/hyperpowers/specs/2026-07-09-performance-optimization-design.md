# Performance-Optimization Skill Family — Design

- **Date:** 2026-07-09
- **Status:** Approved (design); pending spec review → implementation plan
- **Target version:** 6.0.13 → 6.1.0 (minor; two new skills)
- **Scope:** Add a language-agnostic performance capability to hyperpowers as two
  peer skills plus on-demand language packs.

## Summary

Add two peer skills to the flat hyperpowers namespace:

- `profiling-performance` — a language-agnostic methodology for establishing a
  correctness baseline, measuring where time/resources actually go, identifying
  what a hot region is *bound by*, and producing a **ranked list of candidate
  optimizations**. Standalone-useful ("why is this slow?") and also the
  structured input to the fix workflow.
- `optimizing-performance` — an empirical fix workflow that consumes the
  profiling output, executes candidate optimizations through the tuned
  subagent-driven-development (SDD) machinery with Codex review gates, measures
  every attempt against a shared baseline, keeps only changes that pay (with a
  noise gate and a complexity-aware materiality bar), runs a bounded re-profile
  checkpoint, and hands the user a measured summary.

Language-specific knowledge lives in on-demand reference "packs" under
`profiling-performance/references/`. This project ships three packs — C++
(ported from the existing `~/temp/cpp-performance-optimization` draft), Python,
and JS/Node — chosen to span native/compiled, interpreted/GC, and JIT runtimes
so the agnostic core is proven not to leak language assumptions.

## Motivation

Performance work has two dominant failure modes (from the C++ draft, and both
language-independent):

1. **Optimizing the wrong thing** — effort spent off the bottleneck is wasted
   (Amdahl). Guessing from reading code is unreliable.
2. **Silently changing results** — a "faster" version that changes what the code
   computes can invalidate downstream correctness.

The through-line is therefore: *measure first, protect correctness, optimize in
order of payoff, then re-measure and reconcile against the bound.* This is
valuable across every language, not just C++, and it composes naturally with
hyperpowers' existing plan → SDD → review chain.

## Goals

- A genuinely language-agnostic diagnosis/benchmarking skill.
- An empirical fix workflow that reuses SDD + Codex gates rather than
  reinventing orchestration.
- A benchmark-driven keep/revert decision with an explicit, hard-to-rationalize
  tie-break rule.
- A measured, honest final report (including reverted attempts).
- On-demand language packs (C++, Python, JS) behind a validated extension seam.
- Full writing-skills evaluation for the discipline content, plus quorum-harness
  regression scenarios.

## Non-goals (YAGNI)

- Additional language packs (Rust, Go, JVM, …) — deferred to follow-ups via the
  established seam.
- A committed generic benchmark-harness *generator* tool. The skills offer to
  build a *minimal* harness inline; no reusable tool is shipped.
- Heavy toolchain auto-detection (light detect/ask only).
- CI perf-regression dashboards.
- **Explicitly rejected:** parallelizing benchmark measurement (contaminates
  numbers — see the serialized-measurement rule below).

## Key decisions (resolved during brainstorming)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Structure | Two peer skills (not one orchestrator, not three) |
| 2 | Language specifics | Agnostic core + on-demand packs; C++/Python/JS now |
| 3 | Fix-workflow shape | Hybrid: plan-driven SDD batch + bounded re-profile checkpoint |
| 4 | Tie-break rule | Noise gate + complexity-aware materiality bar (overridable defaults) |
| 5 | Evaluation | Full writing-skills RED-GREEN-REFACTOR + wording micro-tests + quorum-harness scenarios |

## Architecture & file layout

```
skills/
  profiling-performance/
    SKILL.md                     # language-agnostic diagnosis + benchmarking spine
    references/
      cpp.md                     # C++ pack (ported; cheminformatics as marked domain notes)
      python.md                  # Python pack
      javascript.md              # JS/Node pack
  optimizing-performance/
    SKILL.md                     # the fix workflow; wires in SDD + Codex
    perf-implementer-notes.md    # perf addendum handed to SDD implementer subagents
    perf-reviewer-notes.md       # perf addendum for the SDD task reviewer
```

Skills are auto-discovered from `skills/<dir>/`; **no manifest entry is
required**. Version metadata is managed by `vrzn` across *all* configured
manifests (`plugin.json`, `marketplace.json`, `package.json`, and the per-harness
plugin manifests) — not just one file.

**Triggering (SDO — "Use when…" triggers only, no workflow summary):**

- `profiling-performance`: *Use when you need to understand or measure why
  something is slow, establish a benchmark/baseline, or find and rank the real
  bottlenecks — before committing to any rewrite.*
- `optimizing-performance`: *Use when you intend to make code faster end-to-end
  and want the change measured, quality-gated, and summarized.* Cross-references
  `profiling-performance` with a **REQUIRED** marker and invokes it if no
  baseline exists.

## `profiling-performance` design

Language-agnostic layer-1 spine (generalized from the C++ draft):

1. **Establish a correctness baseline** — reference outputs for representative +
   edge inputs; an explicit comparison rule (bitwise vs. absolute/relative
   tolerance, chosen with the user); the "differs from reference ≠ worse"
   nuance (reassociation can improve accuracy). If no harness exists, offer to
   build a minimal one first.
2. **Find the real bottleneck (measure, don't guess)** — smallest useful
   measurement first; identify what the hot region is *bound by*. The bound axis
   is generalized beyond compute/memory to: compute-bound,
   memory-bandwidth/latency-bound, allocation/GC-bound, I/O- or syscall-bound,
   network/DB-bound, lock-contention-bound. The bound tells you what a fix can
   buy.
3. **Rank candidate optimizations by payoff** (ranking is a diagnosis output, so
   the payoff taxonomy lives here): (a) algorithm & complexity; (b) data
   structures / layout / memory & allocation; (c) leverage the platform
   (compiler/JIT/interpreter flags, build mode, tuned libraries); (d) I/O /
   syscalls / DB / network; (e) concurrency & parallelism; (f) micro-level
   (branch, instruction, hot-path allocation). Each candidate carries:
   hypothesis, why it applies here, expected payoff vs. the bound, confidence,
   and rough complexity cost.
4. **Reconcile against the bound & report honestly** — explain measured wins
   against the bound; label anything unmeasured as *hypothesis*, never as fact.

**Primary output:** bottleneck analysis + ranked candidate list +
validation/measurement plan. The ranked list is the structured hand-off object
`optimizing-performance` consumes.

**Disposition:** measure if the toolchain is available; otherwise reason
statically but flag every speedup as hypothesis-to-verify.

**Packs:** the agnostic `SKILL.md` cross-references `references/<lang>.md`,
loaded on demand (no `@` force-loading). Pack contents:

- **cpp.md** — `-O3 -march=native`, LTO; the `-ffast-math`/`-Ofast` correctness
  caveat; autovectorization + verification (`-Rpass`/`-fopt-info-vec`); the
  explicit-SIMD ladder (autovec → portable `std::simd`/Highway/xsimd →
  intrinsics); modern C++ toolbox (`std::popcount`, `span`/`mdspan`, `jthread`,
  parallel algorithms); branch/ILP tuning. Cheminformatics/OpenEye/RDKit
  material retained as a clearly-labeled **domain example** subsection.
- **python.md** — profilers (`cProfile`, `py-spy`, `scalene`, `memory_profiler`,
  `timeit`); the GIL and true-parallelism limits (multiprocessing / native
  extensions / releasing the GIL); vectorization via NumPy/pandas and pushing
  hot loops into C extensions/Cython/Numba; object & allocation overhead;
  avoiding interpreter-loop hot paths; async/event-loop considerations.
- **javascript.md** — profilers (`node --prof`, `--cpu-prof`, `clinic`, `0x`,
  Chrome DevTools); V8 JIT deopts and hidden-class/shape stability; GC pressure
  and allocation; event-loop/async bottlenecks and blocking the loop; typed
  arrays; worker threads.

## `optimizing-performance` design (hybrid workflow)

1. **Baseline & candidates (entry condition).** Require a measured baseline +
   ranked candidate list from `profiling-performance`; invoke it if absent.
   Persist to the SDD scratch dir (via the `sdd-dir` cache helper — **not**
   `.git/`): `baseline.json` (benchmark numbers + run-to-run variance), the
   correctness reference, and an **attempts ledger**. Every subagent reads the
   same baseline; the baseline is not re-measured per attempt.
2. **Plan the batch.** Filter candidates to the independent, high-confidence
   ones; turn them into a plan via `writing-plans`, one candidate per task
   (carrying hypothesis, expected payoff-vs-bound, and the exact benchmark
   command). Coupled/speculative candidates are held for the re-profile round.
3. **Execute via SDD — with serialized measurement.** Standard SDD (fresh
   implementer per task, task review, Codex code-review gates via existing
   hooks), with two perf addenda:
   - `perf-implementer-notes.md`: implement the change, run the benchmark **N
     times** against the baseline, run the correctness check, report delta +
     variance + a one-line complexity cost.
   - `perf-reviewer-notes.md`: verify benchmark *methodology* (enough runs,
     right workload, anti-dead-code-elimination guards) and code quality.
   - **Serialized measurement (explicit rule).** SDD already runs tasks one at a
     time, and this workflow must *keep* it that way: do **not** parallelize perf
     tasks (e.g., via `dispatching-parallel-agents`). Even though candidates are
     logically independent, parallel CPU-heavy benchmarks on one host contaminate
     each other's numbers, so apply-and-measure steps stay strictly serial.
4. **Keep / revert / tie-break decision** (owned by the **coordinator**, which
   holds the baseline + cross-attempt view; the reviewer verifies methodology
   and flags):
   - **Correctness gate first** — fails the comparison → revert, no exceptions.
   - **Noise gate** — keep only if the speedup is statistically distinguishable
     from run-to-run noise (multiple runs).
   - **Complexity-aware materiality bar** — a change that materially increases
     complexity must *also* clear an improvement bar (default ≥5–10%, overridable
     per project); trivial-complexity real wins are kept on the noise gate alone.
   - **Variant tie** — among changes that pass and perform similarly, keep the
     DRYest / simplest.
   - **Revert unpaid complexity** — anything that doesn't clearly pay reverts to
     the original.
5. **Re-profile checkpoint (bounded adaptivity).** After the batch, re-profile
   the optimized code and reconcile against the bound. If meaningful time
   remains *and* new above-threshold candidates surfaced, spawn **one** more
   bounded round (plan → SDD → decide). Hard cap of **2 rounds** total. Stop
   when the bound is met, no new qualifying candidates appear, or the cap is hit
   — and state which.
6. **Isolation & safety.** Work happens on the SDD branch; reverts are per-task
   within it, so the tree never accumulates rejected attempts. Worktrees are not
   needed (serialized measurement precludes parallel attempts).

### Entry safety: no measurement, no empirical optimization

`optimizing-performance`'s gates (correctness, noise, materiality) are
meaningless without benchmark data, so the skill must not "optimize" on
hypotheses. When a measured baseline cannot be produced:

1. **First try to establish measurement** — build a minimal benchmark +
   correctness harness (the `profiling-performance` skill already offers this). A
   missing harness is a reason to *create* one, not to skip measurement.
2. **If measurement genuinely cannot run** in the environment (no toolchain, no
   way to execute the code), **stop and hand back to the user** — do not apply
   changes and do not report any speedup. Silent hypothesis-only "optimization"
   is prohibited; it is the exact failure mode the empirical gates exist to
   prevent.
3. **Optional advisory-only fallback (explicit user opt-in).** Produce a
   clearly-labeled advisory output: the ranked candidates and recommended changes
   from `profiling-performance`, marked *hypothesis, unverified*, with **no code
   applied** and **no measured-win claims**. The keep/revert/tie-break machinery
   is skipped because it cannot run.

This preserves the core contract: **no measured baseline → no empirical
optimization.**

## Final report (success criteria)

Built from the attempts ledger and presented at the end:

1. **Headline result** — overall improvement on the *named* workload with the
   *named* metric (e.g. "3.1× faster on the 10k-row batch, wall 8.4s → 2.7s;
   correctness within tolerance").
2. **What was kept** — each landed optimization: what it did, measured delta
   (with variance), which bound it addressed, complexity cost.
3. **What was tried and reverted** — attempts that failed the correctness gate,
   noise gate, or materiality bar, with the measured result and why dropped.
4. **Correctness** — the comparison rule used and confirmation every kept change
   stayed within tolerance.
5. **Bound reconciliation** — did we capture what the bound allowed? What limits
   now? Known remaining headroom and whether it was intentionally left.
6. **Reproducibility** — exact benchmark command(s), build mode/flags, run
   count, machine caveats.

**Honesty rules (baked into the skill):** report only measured numbers; label
unmeasured claims as *hypothesis*; never claim an unmeasured speedup; never hide
reverted attempts.

## Evaluation plan

Per writing-skills (Iron Law: no skill without a failing test first) and the
fork's "skill changes require evaluation" mandate:

- **RED baselines** (subagent pressure scenarios, no skill) for the
  `optimizing-performance` discipline failures: faking/estimating numbers
  instead of measuring; claiming a win without re-benchmarking; keeping
  clever-but-unpaid complexity; running benchmarks in parallel and trusting the
  numbers. Document verbatim rationalizations.
- **GREEN** — minimal skill content addressing exactly those failures.
- **REFACTOR** — rationalization table + red-flags list; close loopholes;
  re-test until bulletproof.
- **Wording micro-tests** for the tuned rules (tie-break, materiality bar,
  measurement honesty) against a no-guidance control — 5+ reps, every flagged
  match read manually.
- **Technique-application tests** for `profiling-performance` (fresh slow
  function → does the agent establish a baseline, identify the bound, produce a
  ranked candidate list?) and **retrieval/application tests** for each pack (slow
  Python/JS/C++ function → does the agent pull the right profiler and idioms?).
- **Quorum-harness scenarios** added to the `hyperpowers-evals` repo for both
  skills → ongoing regression coverage.

Evidence is retained with the change per fork guidelines. Eval scenarios
live/commit in the evals repo; this design doc stays uncommitted per the user's
global rules.

## Versioning, registration, cross-references

- Run the configured `vrzn` **minor** bump (6.0.13 → **6.1.0**); it updates all
  configured version locations (`plugin.json`, `marketplace.json`, `package.json`,
  and the per-harness manifests). Verify every location is consistent afterward.
- No manifest/catalog entry needed (auto-discovery).
- Cross-references: `optimizing-performance` → **REQUIRED** `profiling-performance`;
  `optimizing-performance` uses `writing-plans`, `subagent-driven-development`,
  and `requesting-code-review`/Codex gates by name (no `@` links). Add pack links
  from `profiling-performance/SKILL.md`.

## Open items for the user

- **`.gitignore` conflict:** the global rule says gitignore `docs/hyperpowers`,
  but this repo already tracks `docs/hyperpowers/specs`, `plans`, and
  eval-evidence files. Not changed unilaterally — decision deferred to the user.
- **Follow-up packs:** Rust/Go/JVM etc., added later via the validated seam.