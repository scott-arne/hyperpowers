# The eval adds a `controller` arm against the same control and bars 1-4, without a sentinel

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 13)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**The eval adds a `controller` arm against the same control and bars
1-4, without a sentinel.** Once the notice is off, the treatment the
revised campaign measured is no longer the configuration that ships.
This amends decision 10. Rejected: merging the controller unmeasured,
which the evaluation rule for skill changes forbids; re-running the
sentinel, which measures only the notice.

## What implementation changed

Applied in the evals repository (the `controller` arm, with its pin row in `manifest.tsv`) and recorded in the eval evidence note, not in this tree.
