# Performance-Optimization Skill Family Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a language-agnostic performance capability to hyperpowers as two peer skills (`profiling-performance`, `optimizing-performance`) plus on-demand C++/Python/JS language packs, evaluated per writing-skills discipline.

**Architecture:** `profiling-performance` is a technique/reference skill (measure → find the bound → rank candidates). `optimizing-performance` is a discipline/workflow skill that consumes the profiling output and drives an empirical fix loop through the existing subagent-driven-development (SDD) + Codex review-gate machinery, with a benchmark-gated keep/revert/tie-break policy and a bounded re-profile checkpoint. Language specifics live in `profiling-performance/references/<lang>.md`, loaded on demand.

**Tech Stack:** Markdown skill files (no runtime code); the existing hyperpowers skills (SDD, writing-plans, requesting-code-review/Codex gate); `scripts/bump-version.sh` for versioning; `bun`/quorum for eval scenarios in the `evals/` repo.

**Source spec:** `docs/hyperpowers/specs/2026-07-09-performance-optimization-design.md` (approved, Codex-gated). The implementer should read it — it carries the full rationale behind every rule below.

## Global Constraints

Every task's requirements implicitly include this section.

- **Skill authoring IS TDD (Iron Law):** NO SKILL WITHOUT A FAILING TEST FIRST. For the two **skills** (`profiling-performance`, `optimizing-performance`), run the baseline (watch it fail) BEFORE writing skill content (Task 1). The **language packs** are *reference* material: per writing-skills, reference skills are tested by retrieval/application, not by a RED rule-violation baseline — each pack's test compares WITH the pack against a no-pack control to confirm the pack actually changes behavior. Source of truth: `skills/writing-skills/SKILL.md` and `skills/writing-skills/testing-skills-with-subagents.md`.
- **Flat namespace, auto-discovery:** skills live at `skills/<dir>/SKILL.md` and are auto-discovered — no manifest/catalog entry required for discovery.
- **Frontmatter:** exactly `name` + `description`; whole frontmatter ≤ 1024 chars. `name` uses letters/numbers/hyphens only. `description` is third-person, starts with "Use when…", is keyword-rich, and describes ONLY triggering conditions — it MUST NOT summarize the skill's workflow (SDO trap).
- **Cross-references:** reference other skills by name with explicit markers (e.g. `**REQUIRED SUB-SKILL:** Use hyperpowers:profiling-performance`). Never use `@` links (force-load). Link reference files with relative markdown links (e.g. `[cpp.md](references/cpp.md)`) so they load on demand.
- **Voice:** match the tuned Superpowers voice — "your human partner", not "the user". Preserve it.
- **Zero-runtime-dependency / clean degradation:** skills add no third-party dependencies; anything Codex-related degrades cleanly when Codex is absent (the gate already handles this).
- **Serialized measurement:** never parallelize perf benchmark tasks (SDD already runs tasks serially; do not add `dispatching-parallel-agents`). Parallel CPU-heavy benchmarks contaminate numbers.
- **Tie-break policy (verbatim intent):** keep a change only if its speedup is statistically distinguishable from run-to-run noise; a change that materially increases complexity must ALSO clear a materiality bar (default ≥5–10%, overridable per project); among similar-performing variants keep the DRYest/simplest; revert unpaid complexity to the original.
- **Measurement honesty:** report only measured numbers; label anything unmeasured as *hypothesis*; never claim an unmeasured speedup; never hide reverted attempts.
- **Entry safety:** no measured baseline → no empirical optimization (build a harness first; else stop and hand back; optional user-opt-in advisory-only mode with no code applied).
- **Versioning:** bump with the repo-local `scripts/bump-version.sh 6.1.0` (it edits all six configured manifests from `.version-bump.json`; requires `jq`), then `scripts/bump-version.sh --check` (all six agree) and `--audit` (no stray old-version strings). Do NOT hand-edit individual manifests. (`vrzn` is the historical equivalent per `vrzn.toml`, but it is not on PATH in this checkout — use `bump-version.sh`.)
- **Doc-commit rule:** do NOT commit the spec or this plan. The eval-evidence doc under `docs/hyperpowers/` IS committed, following the repo's established tracked-evidence pattern (e.g. `docs/hyperpowers/2026-06-30-codex-gate-convergence-eval-evidence.md`).
- **Testing terminology:** in this plan a "test" is a subagent scenario (application, retrieval, or pressure) per `testing-skills-with-subagents.md` — NOT a unit test. "RED" = run the scenario without the new skill and document the failure/rationalizations; "GREEN" = run it with the skill and confirm the target behavior; "REFACTOR" = close loopholes and re-test.
- **Evidence recording:** every RED/GREEN/retrieval run appends a short, factual entry (what ran, what happened, no invented numbers) to `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md` immediately after the run — not deferred to a later task.

---

## File Structure

**Create:**
- `skills/profiling-performance/SKILL.md` — agnostic diagnosis + benchmarking spine; links the three packs.
- `skills/profiling-performance/references/cpp.md` — C++ pack (ported/generalized from the draft; cheminformatics as a marked domain example).
- `skills/profiling-performance/references/python.md` — Python pack.
- `skills/profiling-performance/references/javascript.md` — JS/Node pack.
- `skills/optimizing-performance/SKILL.md` — the fix workflow; wires in SDD + Codex.
- `skills/optimizing-performance/perf-implementer-notes.md` — perf addendum for SDD implementer subagents.
- `skills/optimizing-performance/perf-reviewer-notes.md` — perf addendum for the SDD task reviewer.
- `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md` — RED→GREEN→REFACTOR + application/retrieval evidence (committed).
- `evals/scenarios/perf-optimize-measures-and-reverts-unpaid/{story.md,setup.sh,checks.sh}` — discipline scenario (measurement + revert-unpaid-complexity + honesty).
- `evals/scenarios/perf-profile-measures-before-guessing/{story.md,setup.sh,checks.sh}` — technique scenario (baseline + bound + ranked candidates before any rewrite).

**Modify:**
- `README.md` (Skills Library, ~lines 169-184) — add the two skills under a new **Performance** grouping.
- Version manifests via `scripts/bump-version.sh` (6 files): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json`.

**Source material (read-only input):** `~/temp/cpp-performance-optimization/SKILL.md` (the C++ draft to port in Task 3).

---

## Task 1: RED baselines — watch it fail before writing anything

Establishes the Iron-Law baseline for both skills: capture how agents behave on performance work WITHOUT these skills, so the skill content targets real failures rather than hypothetical ones.

**Files:**
- Create: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`

**Interfaces:**
- Consumes: nothing.
- Produces: a committed eval-evidence doc whose **RED Baseline** section lists the verbatim rationalizations/gaps that Tasks 2 and 6 must address. Later tasks append to this same file.

- [ ] **Step 1: Read the testing methodology**

Read `skills/writing-skills/testing-skills-with-subagents.md` (pressure types, how to write scenarios, how to document rationalizations) and the spec's Evaluation section.

- [ ] **Step 2: Run the discipline baseline (optimizing-performance)**

Dispatch a fresh subagent (no new skills present) with a realistic slow-code task that tempts the discipline failures. Prompt shape:

> "Here is a slow function `<paste a plausibly-hot function>` with a benchmark harness. Make it faster and tell me how much faster it is. Be efficient."

Run 3+ reps. Document verbatim which of these occur: (a) claims a speedup without benchmarking, (b) estimates/fabricates numbers, (c) keeps a clever rewrite that didn't measurably help, (d) never establishes a correctness check, (e) reports only wins and hides dead ends, (f) reasons about parallelizing benchmarks.

- [ ] **Step 3: Run the technique baseline (profiling-performance)**

Dispatch a fresh subagent with: "Why is this slow and what should I optimize?" over a small program with a non-obvious bottleneck. Run 3+ reps. Document whether it (a) guesses the bottleneck from reading code instead of measuring, (b) skips establishing what the region is bound by, (c) jumps to micro-optimizations over algorithmic ones, (d) produces no ranked/prioritized candidate list.

- [ ] **Step 4: Write the RED Baseline section**

Create the eval-evidence doc with a header and a `## RED Baseline (pre-skill)` section recording, verbatim, the rationalizations and gaps from Steps 2–3, grouped by skill. This is the target list for GREEN.

- [ ] **Step 5: Commit**

```bash
git add docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "test(perf): capture RED baseline for performance skills"
```

---

## Task 2: `profiling-performance/SKILL.md` (GREEN — technique skill)

The language-agnostic spine plus on-demand pack links.

**Files:**
- Create: `skills/profiling-performance/SKILL.md`
- Modify: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`

**Interfaces:**
- Consumes: RED gaps from Task 1 (technique failures).
- Produces:
  - skill name `profiling-performance` (invoked `hyperpowers:profiling-performance`).
  - the **ranked candidate list** as the documented hand-off object Task 6 consumes: each candidate carries `hypothesis`, `why-it-applies`, `expected-payoff-vs-bound`, `confidence`, `complexity-cost`.
  - pack link paths `references/cpp.md`, `references/python.md`, `references/javascript.md` (files created in Tasks 3–5).

- [ ] **Step 1: Write frontmatter**

```markdown
---
name: profiling-performance
description: Use when you need to find out why code is slow — a hot loop, high latency, heavy memory/allocation use, a throughput ceiling, or a performance regression — or to establish a benchmark/baseline and rank the real bottlenecks before committing to any rewrite. Covers profiling, measurement, and diagnosis across languages.
---
```

(Verify: ≤1024-char frontmatter, third person, "Use when…", keyword-rich, no workflow summary.)

- [ ] **Step 2: Write the agnostic spine sections**

Required sections and their must-include content:

1. **Overview / core principle** — "measure first, protect correctness, then optimize in payoff order — and re-measure." Name the two failure modes (optimizing the wrong thing; silently changing results).
2. **Establish a correctness baseline** — reference outputs incl. edge cases; explicit comparison rule (bitwise vs absolute+relative tolerance, chosen with your human partner); the "differs from reference ≠ worse" nuance; offer to build a minimal harness if none exists.
3. **Find the real bottleneck (measure, don't guess)** — smallest useful measurement first; identify what the region is *bound by*, using the generalized axis: compute / memory-bandwidth / memory-latency / allocation-GC / I/O-syscall / network-DB / lock-contention. The bound tells you what a fix can buy.
4. **Rank candidate optimizations by payoff** — the taxonomy, highest-leverage first: (a) algorithm & complexity; (b) data structures / layout / memory & allocation; (c) leverage the platform (compiler/JIT/interpreter flags, build mode, tuned libraries); (d) I/O / syscalls / DB / network; (e) concurrency & parallelism; (f) micro-level (branch, instruction, hot-path allocation). Each candidate records the five fields listed in Interfaces.
5. **Reconcile against the bound & report honestly** — explain measured wins against the bound; label anything unmeasured as *hypothesis*.
6. **Output** — the primary deliverable: bottleneck analysis + ranked candidate list + validation/measurement plan.
7. **Disposition** — measure if the toolchain allows; else reason statically but flag every speedup as hypothesis-to-verify.
8. **Language packs** — a short section linking `[cpp.md](references/cpp.md)`, `[python.md](references/python.md)`, `[javascript.md](references/javascript.md)`, told to load the matching pack on demand.

- [ ] **Step 3: Self-check against the writing-skills checklist**

Verify: SDO description (no workflow summary), no `@` links, "your human partner" voice, concise (technique skill — aim to keep tight), flowcharts only if a decision is non-obvious.

- [ ] **Step 4: GREEN application test + record evidence**

Dispatch a fresh subagent WITH this skill available and the same technique scenario as Task 1 Step 3. Confirm it now: establishes a baseline, measures, identifies the bound, and produces a ranked candidate list (not a guess, not micro-first). Append a factual GREEN entry to the evidence doc. If it still fails a Task-1 gap, revise the skill and re-run.

- [ ] **Step 5: Commit**

```bash
git add skills/profiling-performance/SKILL.md docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "feat(perf): add profiling-performance skill (agnostic spine)"
```

---

## Task 3: `references/cpp.md` (C++ pack — port + generalize-split)

**Files:**
- Create: `skills/profiling-performance/references/cpp.md`
- Modify: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`
- Read: `~/temp/cpp-performance-optimization/SKILL.md`

**Interfaces:**
- Consumes: `profiling-performance` spine (Task 2) — this pack is layer-2/3 detail under it.
- Produces: `references/cpp.md` reachable from the Task 2 pack-links section.

- [ ] **Step 1: Port the C++ specifics**

Copy the draft's layer-2 material into `cpp.md`: `-O3 -march=native`/LTO; the `-ffast-math`/`-Ofast` correctness caveat (do not enable globally for validated work; apply surgically; re-run the baseline); autovectorization + verification (`-Rpass=loop-vectorize`/`-fopt-info-vec`); the explicit-SIMD ladder (autovec → portable `std::simd`/Highway/xsimd → intrinsics behind runtime dispatch); the modern C++ toolbox (`std::popcount`, `span`/`mdspan`, `jthread`, parallel algorithms); branch/ILP tuning (`cmov`/if-conversion first).

- [ ] **Step 2: Mark the cheminformatics content as a domain example**

Move the OpenEye/RDKit molecular-kernel patterns (atom/bond iteration, coordinate/geometry kernels, fingerprints/Tanimoto, SMARTS matching, cached perception, streaming I/O) into a clearly-labeled `## Domain example: cheminformatics C++ (OpenEye/RDKit-style)` subsection, so the pattern reads as "language pack, optionally with domain notes."

- [ ] **Step 3: Strip skill-ness**

This is a reference file, not a skill: remove the draft's skill frontmatter/`description`; open with a one-line note that it's the C++ pack for `profiling-performance`. Do not duplicate the agnostic spine — reference it.

- [ ] **Step 4: Retrieval test (with no-pack control) + record evidence**

Dispatch a fresh subagent WITH `profiling-performance` + this pack and a slow C++ kernel; and a control WITHOUT the pack. Confirm the pack version pulls the right C++ levers (measures, checks vectorization, flags the `-ffast-math` correctness tradeoff) where the control gives generic advice. Append a factual entry to the evidence doc.

- [ ] **Step 5: Commit**

```bash
git add skills/profiling-performance/references/cpp.md docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "feat(perf): add C++ language pack for profiling-performance"
```

---

## Task 4: `references/python.md` (Python pack)

**Files:**
- Create: `skills/profiling-performance/references/python.md`
- Modify: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`

**Interfaces:**
- Consumes: `profiling-performance` spine.
- Produces: `references/python.md` reachable from the Task 2 pack-links section.

- [ ] **Step 1: Write the Python pack**

One-line "Python pack for profiling-performance" note, then required content:
- **Profilers:** `cProfile`/`pstats`, `py-spy` (sampling, no code change), `scalene` (CPU+memory+GPU), `line_profiler`, `memory_profiler`, `timeit` for microbenchmarks.
- **The GIL:** CPU-bound Python doesn't scale on threads; use `multiprocessing`, native extensions, or release the GIL (NumPy/C-extensions). I/O-bound work does benefit from threads/async.
- **Vectorize / push down:** move hot loops into NumPy/pandas vectorized ops, or into C/Cython/Numba; avoid per-element Python-level loops on large data.
- **Allocation & object overhead:** attribute access, boxing, temporary lists; `__slots__`, generators, and avoiding needless copies.
- **Interpreter-loop hot paths:** hoist attribute/global lookups, prefer builtins/comprehensions, avoid recomputation.
- **Async/event-loop:** blocking calls in `asyncio`, and when concurrency ≠ parallelism.

- [ ] **Step 2: Retrieval test (with no-pack control) + record evidence**

Fresh subagent WITH `profiling-performance` + this pack and a slow Python function; and a no-pack control. Confirm the pack version reaches for the right profiler (e.g. `py-spy`/`scalene`) and the right lever (vectorize / drop to native / GIL-aware) where the control is generic. Append a factual entry to the evidence doc.

- [ ] **Step 3: Commit**

```bash
git add skills/profiling-performance/references/python.md docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "feat(perf): add Python language pack for profiling-performance"
```

---

## Task 5: `references/javascript.md` (JS/Node pack)

**Files:**
- Create: `skills/profiling-performance/references/javascript.md`
- Modify: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`

**Interfaces:**
- Consumes: `profiling-performance` spine.
- Produces: `references/javascript.md` reachable from the Task 2 pack-links section.

- [ ] **Step 1: Write the JS/Node pack**

One-line "JS/Node pack for profiling-performance" note, then required content:
- **Profilers:** `node --prof` + `--prof-process`, `--cpu-prof`/`--heap-prof`, `clinic` (doctor/flame/bubbleprof), `0x` flamegraphs, Chrome DevTools/`--inspect`, `performance.now()`/`perf_hooks` for microbenchmarks.
- **V8 JIT:** avoid deopts and megamorphic call sites; keep object shapes/hidden classes stable (consistent property order, no delete-in-hot-path); monomorphic functions.
- **GC pressure:** short-lived allocations in hot paths, closures capturing large scopes; reuse buffers; typed arrays for numeric work.
- **Event loop / async:** don't block the loop (sync FS/CPU work), batch microtasks, offload CPU-bound work to `worker_threads`; measure loop lag.
- **Note:** many Node bottlenecks are I/O- or event-loop-bound, not compute-bound — apply the spine's bound axis first.

- [ ] **Step 2: Retrieval test (with no-pack control) + record evidence**

Fresh subagent WITH `profiling-performance` + this pack and a slow Node function; and a no-pack control. Confirm the pack version identifies the bound (event-loop vs compute), reaches for the right profiler (`clinic`/`--cpu-prof`/`0x`), and cites V8/GC/event-loop levers where the control is generic. Append a factual entry to the evidence doc.

- [ ] **Step 3: Commit**

```bash
git add skills/profiling-performance/references/javascript.md docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "feat(perf): add JS/Node language pack for profiling-performance"
```

---

## Task 6: `optimizing-performance` skill + SDD addenda (GREEN — discipline/workflow skill)

The empirical fix workflow AND the two SDD addenda it hands to subagents, authored together so the GREEN test exercises the complete shipped workflow. This is the discipline skill; write it to defeat the exact rationalizations captured in Task 1 Step 2.

**Files:**
- Create: `skills/optimizing-performance/SKILL.md`
- Create: `skills/optimizing-performance/perf-implementer-notes.md`
- Create: `skills/optimizing-performance/perf-reviewer-notes.md`
- Modify: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`

**Interfaces:**
- Consumes: RED discipline gaps (Task 1); `profiling-performance` (REQUIRED cross-ref) for the baseline + ranked candidates; the spec's optimizing-performance design for the artifact/field contract (`baseline.json`, attempts ledger, the tie-break gates).
- Produces: skill name `optimizing-performance`; the two notes files referenced by name from the SKILL.md; the final-report format Task 8/scenarios assert against.

- [ ] **Step 1: Write frontmatter**

```markdown
---
name: optimizing-performance
description: Use when you intend to actually make code faster and land the change — a confirmed hot path, a performance regression, or a concrete speed/memory/throughput target — not just diagnose it. Keywords: optimize, speed up, reduce latency, benchmark-driven, performance fix, make it faster.
---
```

(Verify SDO: triggers only, no workflow summary; ≤1024-char frontmatter.)

- [ ] **Step 2: Write the workflow + policy sections**

Required sections and must-include content:

1. **Overview / core principle** — empirical: measure the baseline, change one thing, re-measure, keep only what pays. **REQUIRED SUB-SKILL:** Use hyperpowers:profiling-performance for the baseline + ranked candidates (invoke it if none exists). Also uses `hyperpowers:writing-plans`, `hyperpowers:subagent-driven-development`, and `hyperpowers:requesting-code-review` / the Codex review gate — all named explicitly, no `@` links.
2. **When to use** — vs `profiling-performance` (diagnose only): this skill applies changes and verifies them.
3. **Entry safety: no measurement, no empirical optimization** — build a harness first; if measurement genuinely can't run, STOP and hand back (no silent hypothesis-only optimizing); optional user-opt-in advisory-only output with no code applied and no measured-win claims.
4. **The workflow (hybrid):**
   - (1) Baseline & candidates from `profiling-performance`; persist `baseline.json` (numbers + variance), the correctness reference, and an **attempts ledger** to the SDD scratch dir via the `sdd-dir` cache helper (NOT `.git/`). Every subagent reads the same baseline.
   - (2) Plan the batch: filter to independent, high-confidence candidates; one candidate per task via `writing-plans` (each carries hypothesis, expected payoff-vs-bound, exact benchmark command).
   - (3) Execute via SDD with **serialized measurement** — hand implementers `perf-implementer-notes.md`, reviewers `perf-reviewer-notes.md`; Codex code-review gate via existing hooks; never parallelize benchmark tasks.
   - (4) Keep/revert/tie-break decision (owned by the coordinator; see policy below).
   - (5) Re-profile checkpoint: re-profile the optimized code, reconcile against the bound; spawn at most ONE more bounded round; hard cap of 2 rounds; state why you stopped.
   - (6) Isolation: work on the SDD branch; per-task reverts; no worktrees (serialized measurement precludes parallel attempts).
5. **Keep / revert / tie-break policy** — correctness gate first (fail → revert, no exceptions); noise gate (keep only if speedup exceeds run-to-run noise); complexity-aware materiality bar (material complexity must also clear ≥5–10% default, overridable); variant tie → keep DRYest/simplest; revert unpaid complexity.
6. **Final report** — the six-part format: headline result (named workload + metric), what was kept (delta+variance+bound+complexity), what was tried and reverted (with measured result + why), correctness (rule + confirmation), bound reconciliation, reproducibility (commands/flags/run count/machine).
7. **Honesty rules** — measured numbers only; unmeasured = hypothesis; never claim an unmeasured speedup; never hide reverted attempts.
8. **Rationalization table** — seed rows from Task 1's captured excuses, e.g.:

   | Excuse | Reality |
   |--------|---------|
   | "It's obviously faster, no need to benchmark" | "Obvious" perf intuitions are wrong constantly. One run is 30s. Measure. |
   | "One run showed it's faster" | One run is noise. Distinguish from run-to-run variance or it doesn't count. |
   | "This rewrite is cleaner AND I'll assume faster" | Assumption ≠ measurement. If it doesn't clear the bar, revert the complexity. |
   | "I'll estimate the speedup from the diff" | Estimated numbers are fabricated numbers. Report only what you measured. |
   | "The reverted attempts aren't worth mentioning" | Dead ends are results. Hiding them invites re-trying them. |

9. **Red Flags — STOP** — a self-check list, e.g.: reporting a speedup you didn't run; a single benchmark run; keeping a clever change that didn't beat the bar; optimizing with no correctness check; running benchmarks in parallel; "I'll just estimate it."

- [ ] **Step 3: Write `perf-implementer-notes.md`**

Content: implement exactly the one candidate; run the benchmark **N times** (state a default, e.g. ≥5) against the shared `baseline.json`; run the correctness check against the reference; report a structured result — measured delta, run-to-run variance, and a one-line complexity cost; do NOT decide keep/revert (that's the coordinator's call); do NOT re-measure the baseline.

- [ ] **Step 4: Write `perf-reviewer-notes.md`**

Content: verify benchmark *methodology* (enough runs, representative workload, anti-dead-code-elimination guards e.g. `DoNotOptimize`-equivalents, warmup) and code quality; confirm the correctness check actually ran and passed; flag (do not silently accept) any unmeasured or single-run claim; the keep/revert/tie-break decision is the coordinator's, but the reviewer surfaces the evidence for it.

- [ ] **Step 5: Consistency + writing-skills self-check**

Re-read all three files together: confirm the notes use the SAME artifact names and gate definitions as the SKILL.md (no `clearLayers()`-vs-`clearFullLayers()` drift). Verify SDO description, cross-ref markers (REQUIRED), no `@` links, "your human partner" voice, form matches failure (recipe for the report shape; prohibition+table+red-flags for the discipline rules). Fix inline.

- [ ] **Step 6: GREEN pressure test + record evidence**

Dispatch a fresh subagent WITH this skill (and `profiling-performance`) on the Task 1 Step 2 discipline scenario, under pressure ("be quick", "it's obviously faster"). Confirm it measures before AND after, applies the noise+materiality gates, reverts unpaid complexity, and reports reverted attempts honestly. Append a factual GREEN entry to the evidence doc. If a Task-1 rationalization survives, that's a REFACTOR item for Task 7.

- [ ] **Step 7: Commit**

```bash
git add skills/optimizing-performance/ docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "feat(perf): add optimizing-performance workflow skill + SDD addenda"
```

---

## Task 7: REFACTOR — close loopholes + wording micro-tests

Harden the discipline skill against the rationalizations that survived Task 6, and verify the tuned rules' wording.

**Files:**
- Modify: `skills/optimizing-performance/SKILL.md`
- Modify: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`

**Interfaces:**
- Consumes: surviving rationalizations from Task 6 Step 6.
- Produces: hardened rules + a `## Micro-tests` section in the evidence doc.

- [ ] **Step 1: Micro-test the tuned rules**

For each tuned rule (tie-break, materiality bar, measurement honesty), run wording micro-tests per `writing-skills` "Micro-Test Wording": one fresh-context sample per call, a no-guidance control, 5+ reps per variant, read every flagged match manually (template echoes masquerade as hits), treat variance as a metric. If the control doesn't exhibit the failure, drop that guidance.

- [ ] **Step 2: Close loopholes**

For each surviving rationalization from Task 6 / new one from Step 1, add an explicit counter (rationalization-table row and/or red-flag). Re-run the specific pressure scenario until compliant. Keep edits minimal and bulletproofing-focused.

- [ ] **Step 3: Record REFACTOR evidence**

Append a `## REFACTOR (loopholes closed)` and `## Micro-tests` section to the evidence doc: which rationalizations were closed and how, and the micro-test variant/rep/hit counts with the manual-read conclusion.

- [ ] **Step 4: Commit**

```bash
git add skills/optimizing-performance/SKILL.md docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "refactor(perf): close optimizing-performance loopholes; record micro-tests"
```

---

## Task 8: Finalize eval-evidence doc (coverage cross-check)

Confirm the writing-skills evidence the fork requires is complete and honest.

**Files:**
- Modify: `docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md`

**Interfaces:**
- Consumes: entries appended by Tasks 1–7.
- Produces: a complete before/after evidence record.

- [ ] **Step 1: Add a summary + coverage section**

Add a `## Summary` that ties RED → GREEN → REFACTOR for `optimizing-performance`, the before/after for `profiling-performance`, and the three pack retrieval results (all already appended by earlier tasks). Keep it factual (no invented numbers).

- [ ] **Step 2: Cross-check coverage**

Confirm every RED item from Task 1 has a corresponding GREEN outcome (fixed / partially fixed / deferred). List any gaps explicitly rather than implying full coverage.

- [ ] **Step 3: Commit**

```bash
git add docs/hyperpowers/2026-07-09-performance-optimization-eval-evidence.md
git commit -m "test(perf): finalize performance-skills eval evidence"
```

---

## Task 9: Quorum regression scenarios

Add durable regression scenarios to the `evals/` repo (separate git repo, gitignored by the main repo).

**Files:**
- Create: `evals/scenarios/perf-optimize-measures-and-reverts-unpaid/{story.md,setup.sh,checks.sh}`
- Create: `evals/scenarios/perf-profile-measures-before-guessing/{story.md,setup.sh,checks.sh}`
- Read: `evals/docs/scenario-authoring.md`; template `evals/scenarios/sdd-rejects-extra-features/`

**Interfaces:**
- Consumes: the shipped skills.
- Produces: two validated scenarios (static `quorum check`). NOTE: live `quorum run` is a trusted-maintainer terminal operation (permissive agent CLIs, real API cost) — flagged for the human partner, not run by a subagent.

- [ ] **Step 1: Scaffold**

```bash
cd evals && bun run quorum new perf-optimize-measures-and-reverts-unpaid && bun run quorum new perf-profile-measures-before-guessing
```

- [ ] **Step 2: Author the discipline scenario**

`perf-optimize-measures-and-reverts-unpaid`: `setup.sh` writes a fixture inline via `$QUORUM_WORKDIR` (a slow function + a benchmark harness where the "obvious" rewrite does NOT beat the noise+materiality bar). `story.md` frontmatter tags `optimizing-performance`, briefs the Gauntlet-Agent to ask for an optimization, and gives evidence-demanding ACs. `checks.sh` `pre()` uses `requires-tool` for the fixture's runtime; `post()` asserts: skill invoked (`check-transcript skill-called hyperpowers:optimizing-performance`), the benchmark actually ran, and the final code reverted the unpaid-complexity change (or kept it only with a measured ≥bar win) — and did not fabricate a speedup.

- [ ] **Step 3: Author the technique scenario**

`perf-profile-measures-before-guessing`: fixture with a non-obvious bottleneck; ACs require the agent to measure/establish the bound and produce a ranked candidate list before proposing a rewrite. `post()` asserts `hyperpowers:profiling-performance` invoked and evidence of measurement in the transcript.

- [ ] **Step 4: Validate (static)**

```bash
cd evals && bun run quorum check
```
Expected: both new scenarios validate; no TypeScript/registry changes needed.

- [ ] **Step 5: Commit (in the evals repo)**

```bash
cd evals && git add scenarios/perf-optimize-measures-and-reverts-unpaid scenarios/perf-profile-measures-before-guessing && git commit -m "feat(scenarios): add performance-optimization regression scenarios"
```

- [ ] **Step 6: Flag live-run for the human partner**

State that a trusted-maintainer live run (`bun run quorum run scenarios/<name> --coding-agent claude`) is the release-gate confirmation and must be run from a real terminal with credentials — not by an automated subagent.

---

## Task 10: Release finalization — README + version bump

**Files:**
- Modify: `README.md` (Skills Library, ~lines 169-184)
- Modify (via `scripts/bump-version.sh`): the 6 version manifests.

**Interfaces:**
- Consumes: all shipped skills.
- Produces: version 6.1.0 across all manifests; README lists the two skills.

- [ ] **Step 1: Update the README Skills Library**

Add a new **Performance** grouping to the Skills Library in `README.md` (after the **Collaboration** group), containing:
```markdown
- **profiling-performance** - Measure, find the bound, and rank bottlenecks before optimizing (language packs: C++, Python, JS)
- **optimizing-performance** - Benchmark-driven fix workflow with keep/revert tie-break, via SDD + Codex gates
```

- [ ] **Step 2: Bump the version**

```bash
scripts/bump-version.sh 6.1.0
scripts/bump-version.sh --check
scripts/bump-version.sh --audit
```
Expected: `--check` reports 6.1.0 for all six configured locations; `--audit` reports no stray old-version strings (outside the configured excludes). (Requires `jq` on PATH.)

- [ ] **Step 3: Commit**

```bash
git add README.md package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json
git commit -m "chore: add performance skills to README; bump 6.0.13 -> 6.1.0"
```

---

## Notes for the executor

- **Final whole-branch review** is performed by `subagent-driven-development` at the end of execution (spec-compliance + code-quality + Codex final gate) — it is not a plan task.
- **Order matters for the Iron Law:** Task 1 (RED) must precede Tasks 2 and 6. Tasks 3–5 (packs) depend on Task 2. Task 7 (REFACTOR) depends on Task 6. Tasks 8–10 come last, in order.
- **Do not commit** the spec or this plan. The eval-evidence doc IS committed.
