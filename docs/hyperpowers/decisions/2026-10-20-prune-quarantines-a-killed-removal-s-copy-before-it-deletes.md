# `prune` quarantines a killed removal's copy before it deletes it

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 11)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

`prune` quarantines a killed removal's copy before it deletes it. The
copies such removals leave under `plans/` are listed in a `tombs=`
field on its stdout lines, moved to a quarantine on one pass and
removed on a later one after quiet days, so a copy that may be the only
one of a dossier is never deleted on the pass that finds it. Decided
2026-10-27 at the finish, from the implementation.

## What implementation changed

prune in sdd-state lists killed removals' copies under plans/ in a tombs= field, stages one at plans/.quarantining-<name>-<pid> and publishes it as a dated plans/.pruned-* quarantine on one --apply, and removes a quarantine on a later --apply only after a re-check that it stayed quiet; a failed traversal keeps the copy and says so, a put-back checks its destination, and the pending scan exempts the dotted leftovers only while neither side of an apply tracks them. The state suite covers the two phases, the re-occupied destinations, the unreadable copy and the tracked-name collision.
