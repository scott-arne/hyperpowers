# The plan is removed from the tree at finish

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 3)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**The plan is removed from the tree at finish.** The commit that adds the
records removes the plan, on the feature branch before merge. Under a
merge that preserves branch commits, which the finishing skill's local
merge does, git history keeps every byte and
`git log --diff-filter=D -- <path>` finds the removal; a squash merge on
the pull-request path keeps only the records, and each record names the
plan path either way. Keeping plans on main was rejected as the status quo
this design exists to end; keeping plans only on the portable-dossiers
state branch was rejected because that work is unfinished, covers only
SDD runs, and hides the plan from a pull-request reviewer.

## What implementation changed

The compiler takes `--plan` and stages the plan's removal with `git rm` in the same staged set as the records. The plan preflight accepts only a `.md` file under a `plans/` component, bound to this spec by an exact Spec-header match, with no staged or working-tree changes. It tolerates a plan whose removal is already staged or committed, so a re-run is idempotent. The finishing skill and the SDD hand-off pass the plan path through, and `--undo` restores it.
