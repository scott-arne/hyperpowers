# The finishing skill reaches the lease and the board after its compile has

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 17)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

The finishing skill reaches the lease and the board after its compile
has removed the plan file. `sdd-state lease` alone accepts a plan path
whose file is gone: the plan directory falls back to the nearest
existing ancestor inside the repository, and the workspace name comes
from the repository-relative path as always; every other subcommand
still refuses a missing plan. The skill records the plan repository
(`PLAN_REPO`) before the compile and runs `board --repo "$PLAN_REPO"`.
Rejected: keeping the plan file on disk until the release (an untracked
file through the menu, a refused worktree removal and a changed undo
path in the records writer); deferring to the final review (the live
run would fail at the finish). Decided 2026-11-06 in chat, during Task 9
of the plan.

## What implementation changed

`sdd-state lease` alone accepts a plan path whose file is gone. The plan directory falls back to the nearest existing ancestor inside the repository, and every other subcommand still refuses a missing plan. The finishing skill records `PLAN_REPO` before the compile and runs `board --repo "$PLAN_REPO"`. The `decisions-compile` suite and the contract suite pin this.
