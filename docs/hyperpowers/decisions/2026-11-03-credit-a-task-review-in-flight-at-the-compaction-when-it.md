# Credit a task review in flight at the compaction when it returns after it and

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md (decision 8)
- Recorded: 2026-11-04; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md removed at finish

## Decision

Credit a task review in flight at the compaction when it returns after it
and before the next task starts (human partner, 2026-11-04, after the RED
tally: the literal wording counted three correct control runs as failures).

## What implementation changed

This was a change to the eval tally used for the campaign, in the evals repository, not in the hyperpowers tag range. The tally credits a task review in flight at the compaction when it returns after it and before the next task starts. Its tests and the re-measure appear in the evidence note.
