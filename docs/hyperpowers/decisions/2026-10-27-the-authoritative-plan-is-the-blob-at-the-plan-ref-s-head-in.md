# The authoritative plan is the blob at the plan ref's head in the plan repository

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 11)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

The authoritative plan is the blob at the plan ref's head in the plan
repository. Every reader of the dependency graph reads it there, never
from a worktree's copy, and amendments reach that head through one
subcommand that validates the whole graph and its overlaps and then
commits the plan change alone under the lock. When the plan and code
repositories are one, the plan ref is the integration branch. Decided
2026-10-27 at the spec gate.

## What implementation changed

Every graph reader, including `deps`, `next`, `claim` and `merge-back`, resolves the plan through `authoritative_plan_blob` as the blob at `<plan-ref>:<plan path>` in the plan repository. The plan line in the ledger records the plan-ref and the plan root. `sdd-state amend` is the only writer while the plan is open. It validates the graph and overlaps and commits the plan change alone under the lock. The plan-line branch of `authoritative_plan_blob` and the split-layout case have fixtures.
