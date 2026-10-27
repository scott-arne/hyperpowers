# Recovery sidecars move out of the tracked checkout in a later design

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 9)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

Recovery sidecars move out of the tracked checkout in a later design.
`.rewrite/` and `.sync-applying` live inside the state checkout today,
which is why three guards refuse them when they arrive from the branch;
relocating them to a sibling directory under the cache key removes the
class and is the natural home for the write protocol. It is scheduled
after 6.17.0, not before. Decided 2026-10-23 at the hand-back.

## What implementation changed

No change to the schedule: the sidecars were not relocated. The shipped work added a third sidecar inside the state checkout, .restore, which sync's apply uses for restore copies; hp_tree_refusal refuses it when it arrives from the branch, apply refuses a link at that path, and the recovery sweep removes it.
