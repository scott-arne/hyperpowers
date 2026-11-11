# The refresh moves the plan file aside before it checks and writes it

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 4)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**The refresh moves the plan file aside before it checks and writes it.**
A deletion then either fails the rename or finds no file. Rejected:
documenting the window; holding the worktree's index lock across the
check, because `read-tree` takes that lock itself.

## What implementation changed

The refresh moves the plan file aside as decided: `amend_refresh_one` reserves a name with `mktemp` and renames the plan onto it with one `renameSync`, checks the copy through `amend_aside_matches`, runs `read-tree -m -u`, and restores a failed copy with `ln -P` so it never replaces a file created at the path. Implementation went beyond the spec in the recovery machinery: a per-worktree journal in the worktree's git directory (`sdd-amend-asides`, written before the rename) and `amend_settle_asides`, which settle a copy that a crash left aside before the next refresh starts. The copy is also re-checked after `read-tree` and before it is removed, so a write through a descriptor opened before the rename is not lost. The branch where the index already holds the new plan re-checks the file after `read-tree` instead of using an aside.
