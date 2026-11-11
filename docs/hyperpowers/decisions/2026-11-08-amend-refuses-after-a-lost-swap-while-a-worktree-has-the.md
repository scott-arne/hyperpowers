# Amend refuses after a lost swap while a worktree has the plan ref checked out

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 2)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**Amend refuses after a lost swap while a worktree has the plan ref
checked out.** Rejected: reconciling that worktree from its pre-race head,
because amend would then write paths outside the plan on another writer's
behalf; documenting the race as a limit.

## What implementation changed

No change. `cmd_amend` calls `amend_ref_worktrees` in its own shell after a failed `update-ref` and, when any worktree has the plan ref checked out, removes its record, unlocks and answers `status=checked-out` (exit 13) with the quoted stderr line; an empty list retries. The seams `amend-wt-before-swap` and `amend-gone-before-swap` drive the tests.
