# The merged task branch is deleted with `git branch -d`, never `-D`

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 18)
- Recorded: 2026-11-07; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

The merged task branch is deleted with `git branch -d`, never `-D`.
After merge-back the SDD skill detaches at the merged head and runs
`git branch -d <task branch>`, which checks the reachability section 3
relies on; a refusal means the branch holds commits that were never
approved or merged, so the session keeps it, does not force the delete,
and hands back with git's output. This departs from section 3's
`git branch -D <ref>`. Rejected: keeping `-D` (it deletes commits made
on the task branch after its approved head without a message). Decided
2026-11-06 in chat, at the final Codex gate.

## What implementation changed

Nothing recorded.
