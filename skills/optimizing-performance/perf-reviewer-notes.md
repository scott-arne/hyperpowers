# Perf Reviewer Notes (SDD addendum)

You received these because the task under review is a **performance optimization**. Apply them in addition to your normal task-reviewer prompt (spec compliance + code quality). Your extra job here is to verify the *measurement* is trustworthy and to surface the evidence — not to decide whether the change is kept.

## Verify the benchmark methodology

A measured number is only as good as the method that produced it. Check, and **flag** (do not silently accept) any gap:

- **Enough runs.** N ≥ 5. Flag any single-run or low-N claim.
- **Representative workload.** The benchmark reflects real usage, not an artifact. Watch specifically for a "win" that exists only because the benchmark replays identical inputs the change can cache (or otherwise exploits an incidental benchmark pattern). If the speedup would evaporate on representative, non-repeating data, flag it as a benchmark artifact.
- **Anti-dead-code-elimination guards.** The compiler/runtime did not optimize the timed work away — results are consumed or a `DoNotOptimize`-equivalent (e.g. `benchmark::DoNotOptimize`, a volatile sink, returning/printing the result) is in place.
- **Warmup.** JIT/cache warmup is excluded so steady-state is measured.
- **Timing hygiene.** The timed region is the right region; iteration counts are adequate; no I/O or logging inside the timed loop.

## Confirm correctness actually ran

- The correctness check **ran and passed** against the **correctness reference** — not "looks right," not skipped. Confirm the comparison rule (bitwise, or absolute/relative tolerance) is stated and is the one recorded with the baseline.
- The implementer did **not** re-measure the shared baseline (the baseline is fixed; re-measuring per attempt makes attempts incomparable).

## Review the code

- Standard code-quality review of the change itself.
- Confirm the task implemented **exactly one candidate** with no bundled second optimization or unrelated refactor.

## Surface evidence — the keep/revert decision is the coordinator's

Flag any **unmeasured or single-run claim**, any **estimated number** presented as measured, and any **workload that looks tailored to the change**.

Report the evidence the coordinator needs for the keep / revert / tie-break call: the measured delta, run-to-run variance, complexity cost, and correctness result. State what you can and cannot verify from the diff and the report. **Do not** make the keep/revert decision yourself — the coordinator holds the shared baseline and the cross-attempt view.
