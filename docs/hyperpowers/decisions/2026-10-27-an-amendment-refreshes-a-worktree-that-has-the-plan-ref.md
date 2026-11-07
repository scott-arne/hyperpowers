# An amendment refreshes a worktree that has the plan ref checked out

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 14)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

An amendment refreshes a worktree that has the plan ref checked out.
Moving a checked-out branch with `update-ref` leaves that worktree's
index holding the old plan as a staged revert that a later commit or a
switch to a task branch would carry forward. Before the swap, `amend`
refuses with `status=checked-out worktree=<path>` (exit 13) when such a
worktree's index entry or file for the plan path is not the base blob;
after the swap it rewrites that worktree's index entry and file to the
new blob, the way git's `updateInstead` updates a pushed-to checkout.
Rejected: refusing whenever the plan ref is checked out, as merge-back
does (a plan kept in another repository would need that checkout moved
off its branch before every amendment); documenting a refresh command
only (the staged revert stays silent). Decided 2026-11-04 in chat, during
Task 6 of the plan.

## What implementation changed

`amend` refuses with `status=checked-out worktree=<path>` (exit 13) when a worktree that has the plan ref checked out holds an index entry or file for the plan path that is not the base blob. A dry run, `read-tree -m -u -n`, runs before the swap. It also refuses a worktree in the middle of a conflicted merge or one with a held index lock, and reports both as checked-out. After the swap, `amend` rewrites that worktree's index entry and file to the new blob. The state suite has fixtures for the refresh, the failed refresh, the split layout and a worktree with an edited plan copy. Departure fixtures are committed.
