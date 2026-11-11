# A registered worktree with a missing directory blocks an amendment

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 3)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**A registered worktree with a missing directory blocks an amendment.**
The refusal says to restore it or prune it. Rejected: skipping it, because
it comes back with the old plan staged against the new head. Accepted
cost: a stale registration blocks amend until it is pruned.

## What implementation changed

No change. `amend_ref_worktrees` now keeps registered worktrees whose directory is gone, with an `AMEND_WT_GONE` state of 1 (missing) or 2 (missing and locked), and `amend_wt_blocker` returns the first such entry before it checks any other worktree, with the restore-or-prune line or the unlock-and-prune line. After the swap, `amend_refresh` treats a worktree that vanished as its existing refresh error and keeps the record.
