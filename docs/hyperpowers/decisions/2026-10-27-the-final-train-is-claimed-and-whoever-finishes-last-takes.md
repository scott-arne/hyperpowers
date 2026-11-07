# The final train is claimed, and whoever finishes last takes it

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 8)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

The final train is claimed, and whoever finishes last takes it. The
final whole-branch review, the final Codex gate and Finish run in the
session that claims `final`, which succeeds only when every task is
complete and no claim is open; `finish` refuses any other caller. A
branch-scoped lease taken by the same command serializes the finals of
plans that share an integration branch. Rejected: a designated finishing
session; finishing on instruction alone. Decided 2026-10-27 in chat.

## What implementation changed

`sdd-state claim final` succeeds only when every task is complete and no claim is open, and `finish` refuses any other caller. `sdd-state lease` takes the branch-scoped lease under the key `<key>.final-<ref12>`, which serializes the finals of plans that share an integration branch. `lease --release` runs recovery first, so an unrecoverable ledger blocks the release (fail closed). The finishing skill's cancel route was reworked in the final gate. Option 1 records the base tip before the merge. A cancel switches to `<base-branch>`, runs `merge --abort`, or resets to the first run's sha only when `refs/heads/<base-branch>` has moved, then releases the lease. A retry keeps the first run's sha. The comparisons use `refs/heads/<base-branch>` so a same-named tag cannot win. The contract suite pins this text.
