# Perf Implementer Notes (SDD addendum)

You received these because your task is a **performance optimization**. Follow them in addition to your normal implementer prompt. Their job is to keep every attempt comparable against one shared baseline and honest about what was measured.

## Your task is exactly one candidate

- Implement **exactly the one candidate** named in your task brief. The brief carries the candidate's five profiling fields — use `why-it-applies` as the rationale, and keep `expected-payoff-vs-bound`, `confidence`, and the producer's `complexity-cost` in view to sanity-check your result. Do not bundle a second optimization, and do not fold in an unrelated "while I'm here" refactor — a mixed change cannot be attributed to a measured delta.
- If the change needs a cleanup to be readable, that is fine, but it must be part of *this* candidate and counted in its complexity cost, not a separate improvement.

## Use the shared baseline — do not re-measure it

- Read `baseline.json` and the correctness reference from the SDD scratch dir (the path `scripts/sdd-dir` prints, under the user cache — **not** `.git/`, not the working tree). The coordinator hands you this path.
- The baseline is **fixed and shared**. Do **not** re-measure the baseline yourself — re-measuring per attempt makes attempts incomparable. Measure only your optimized variant and compare against the recorded baseline numbers.

## Measure the optimized variant honestly

- Run the **exact benchmark command** from your task brief — the same command and the **same workload** the baseline used. Do not shrink, simplify, or reshape the workload to flatter the change. A workload the change happens to cache (e.g. replaying identical inputs) is a benchmark artifact, not a real win; keep the workload representative.
- Run the benchmark **N times (default ≥5)**, not once. One run is noise.
- Guard the measurement: exclude warmup (JIT/cache), keep I/O and logging out of the timed region, and make sure the compiler/runtime cannot dead-code-eliminate the work you are timing (consume the result / use the language's `DoNotOptimize`-equivalent).

## Run the correctness check

- Compare your variant's output against the correctness reference using the **agreed comparison rule** (bitwise, or absolute/relative tolerance) recorded with the baseline.
- If it fails, report **FAIL** with the discrepancy. Do **not** loosen the rule or tune the check to pass.

## Report structured evidence — do NOT decide keep/revert

Report (write the detail to your report file, per the normal contract):

- **Measured delta** — optimized vs. the recorded baseline (mean, and % change).
- **Run-to-run variance** — the spread across your N runs (stddev, or min/max).
- **Correctness** — pass/fail against the reference, and the rule used.
- **One-line complexity cost** — added LOC / new dependency / readability impact, stated against the candidate's original `complexity-cost` estimate from the brief (flag a large divergence).
- **Reproducibility** — the exact command and the run count N.

Then stop. The **keep / revert / tie-break decision is the coordinator's** — they hold the baseline and the cross-attempt view. Report evidence, not a verdict.

## Honesty (non-negotiable)

- Report only numbers you **actually ran**. Never estimate or extrapolate a number and present it as measured.
- If your attempt did not help — or made things worse — **report it as-is.** Do not delete, hide, or quietly abandon a failed attempt; a reverted attempt is a result the coordinator records in the attempts ledger.
