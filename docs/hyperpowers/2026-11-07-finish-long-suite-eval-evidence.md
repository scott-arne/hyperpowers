# Finish Waits for a Long Suite: Evaluation Evidence

**Change under test:** finishing-a-development-branch Step 1 item 3. The old text said to run the full suite "in the foreground", and Claude Code caps a foreground call at 10 minutes. The new text keeps the foreground for a suite expected to finish within 10 minutes; a longer suite starts through the tracked background option with its exit status written to a file, and the session waits with repeated calls to the new `scripts/wait-exit` helper. SDD's `tracked-job` cannot serve here: SDD removes its ledger (`sdd-state finish`) before it hands off to Finish, and `tracked-job new` needs the ledger.

**Field case:** on 2026-11-07 a Zed session in the parallel-development Finish started a 25-minute suite in the background and ended its turn ("When the run is green, I'll compile the records..."). Zed's ACP v1 adapter shows a session working only while a turn is open and never holds a turn for a background shell, so the session showed idle while the suite ran.

**Method:** paired live Claude Code sessions driven by the quorum harness, ten runs per arm, both arms run concurrently. A new scenario, `finish-long-suite`, puts a Python package on a finished branch with no plan and no spec; its full suite takes about 11.7 minutes and its README says so. The driver asks for the finishing skill, answers "main" and picks the local merge, and sends "continue" only after two minutes idle with no question asked. The measure is read from each transcript with the turn-liveness library (`evidence/2026-10-19-sdd-turn-liveness/liveness.py`, unchanged). The pre-registration, analyzer, tally and run logs are in hyperpowers-evals `evidence/2026-11-07-finish-long-suite/`.

**Environment:** Claude Code 2.1.317 in all 20 runs; coding agent and grader `claude-opus-5-5` on Vertex. Pins: harness `8dbdc61c3` (evals repo) plus the new scenario, control `29b3cae` (v6.17.0, loaded from `.worktrees/plugin-install`), treatment `29b3cae` plus `treatment.patch` (sha256 `fe968e5e...`, the branch's working tree).

**Date:** 2026-11-07.

## Results

| Arm | Runs | L: turn ended while the suite ran | S: suite completed | M: merged, checks pass |
| --- | --- | --- | --- | --- |
| control (v6.17.0) | 10 | 10/10 (50 such turn ends, 4 to 6 per run) | 10/10 | 10/10 |
| treatment | 10 | 0/10 | 10/10 | 10/10 |

Two-sided Fisher exact test on L: p = 1.1e-5. Decision under the pre-registered rule: adopt.

Every control session started the suite with `run_in_background` and ended its turn with a promise to report back ("I'll show the menu once the full suite finishes (about 12 minutes)"). Every treatment session wrote the exit file and waited with `wait-exit` until it printed `exited code=0`.

## Deviations and observations

1. The first treatment launch counted its bound in 200 ms polls. On a loaded host a poll costs more than its sleep, and in one run a `--max-ms 540000` call ran past its 600 s tool timeout and was moved to the background (the session waited again and kept its turn). Both treatment processes were stopped, their two in-flight runs voided, the helper changed to read its bound from the clock (an offline test with a slow `tr` shim covers it), and the treatment arm restarted from zero. Control was not touched.
2. The fixture's merge is always a fast-forward. Seven treatment runs re-ran the suite on the merged result (Step 5, Option 1's `<test command>`) and waited for it the same way, each with a fresh exit file; one control run did. Option 1's text names no way to wait on a long suite, so a follow-up campaign (hyperpowers-evals `evidence/2026-11-07-finish-long-suite-merge/`, scenario `finish-long-suite-merge`) measured the committed text on a fixture whose merge makes a merge commit. In 10 of 10 control runs the session ran the full suite again on the merged result through the tracked launch with a fresh exit file and waited for it with `wait-exit`; none ended its turn while it ran or deleted the branch before it finished (two further runs lost the model provider mid-run and were replaced). By that campaign's pre-registered rule, Option 1 needs no pointer to item 3, and its text is unchanged.
3. The control smoke run (not counted) showed the same failure: five turn ends while the suite ran, each answered by the driver's "continue".
