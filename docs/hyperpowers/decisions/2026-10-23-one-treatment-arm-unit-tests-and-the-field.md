# One treatment arm, unit tests, and the field

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 3)
- Recorded: 2026-11-06; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**One treatment arm, unit tests, and the field.** Ten runs of the
scenario with the hook installed; the decision table is proven by unit
tests over crafted transcripts and ledgers, because one stop attempt per
ten fresh runs cannot exercise it; the hook's marginal value is read from
its own logs in real sessions. A paired control was declined: at one
attempt per ten runs it would read one against zero again.

## What implementation changed

The decision table is proven by `hooks/lib/stop-guard.test.mjs`, run with `node --test` from `tests/hooks/test-sdd-stop-guard.sh`, including the benchmark (no plan under 100 ms over 50 candidate ledgers, a small last turn on a 300 MB transcript under 1 s) and the clone-key parity with `hp_key`. The scenario ran as three one-arm campaigns, none with a control: `tally.txt` (PASS, treatment `4a4f354`, Claude Code 2.1.302), `tally-z4.txt` (FAIL on H2 and H4, treatment `36a6255`, Claude Code 2.1.317) and `tally-z4b.txt` (PASS, the decision of record), with analyzer changes made as numbered Corrections 9 to 12 in the evals README. No counted run put the guard to a decision under a plan, so its live evidence is T1's 12 `live-agent` allows under fork mode and the six decisions across the three Zed runs. Correction 8 landed in `field.collect` (baseline 1434 boundaries, 296 premature stops, 20.64 per 100), and `field_hook.py` reads the per-session mirrors for the after-window, which is a dated follow-up starting at the `v6.17.0` checkout of `.worktrees/plugin-install`. The three analyzer shapes the Codex final gate found (E1 to E3) stay in the pinned `analyze.py`, recorded as known limits after a check over all 35 archived runs found none of them.
