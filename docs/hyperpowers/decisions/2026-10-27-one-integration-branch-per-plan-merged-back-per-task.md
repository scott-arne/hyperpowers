# One integration branch per plan, merged back per task

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 3)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

One integration branch per plan, merged back per task. Each session
works on a short task branch off the plan's branch and merges back right
after the task's gate approves, under the dossier lock, with the merge
recorded in the ledger; the whole-branch review runs on the one branch.
Rejected: per-session branches merged once at the end (late conflicts, a
final review over an unreviewed merge); one shared branch with turns
under the lock (every commit a critical section). Decided 2026-10-27 in
chat.

## What implementation changed

Each session works on a task branch named `<integration>.<ws8>.task-<N>` and merges back with `sdd-state merge-back` under the dossier lock, with the merge recorded in the ledger. `merge-back` merges exactly the approved commit and validates it against the current integration head. The whole-branch review runs on the one integration branch. In the final gate, `merge-back` was changed to answer `not-approved` and `blocked` separately, so a `blocked` answer leaves the approved line in place, never writes a completion line, and moves on to `next`.
