# The stop guard and sdd-state share one completion pattern, held by a parity test

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 11)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**The stop guard and sdd-state share one completion pattern, held by a
parity test.** The guard stops counting mid-line mentions.

## What implementation changed

The shared pattern shipped as decided: `hp_complete_ere` in `sdd-common.sh` and `completePattern` in `stop-guard.mjs`, held equal by the parity table in `tests/hooks/test-sdd-stop-guard.sh`. `ledger_marks_complete` greps under `LC_ALL=C`. `planState` also keeps task ids as the digit strings the plan wrote, instead of mapping them through `Number`, so `01` and `1` are two tasks as in sdd-state; the parity test gained id-level rows for this.
