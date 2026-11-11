# A later session reads the plan line before it settles its worktree; using-git-worktrees does not change

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 12)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**A later session reads the plan line before it settles its worktree;
using-git-worktrees does not change.** Rejected: editing
using-git-worktrees, which two sentinel scenarios read.

## What implementation changed

No change. The SDD SKILL.md Setup paragraph says to run the `sync` and `sdd-dir` steps and read the ledger's plan line before settling the worktree, and to hand using-git-worktrees the integration branch and the session id when the plan line names one. The diff holds no change to `using-git-worktrees/SKILL.md`. The process graph's Setup node was reworded to match.
