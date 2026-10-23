# The records directory derives from the spec's location

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 9)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**The records directory derives from the spec's location.** It is the
`decisions/` sibling of the directory that holds the spec, so a user who
relocates specs relocates records with them without a configuration knob.

## What implementation changed

The records directory is computed as the `decisions` sibling of the spec's parent directory. The compiler resolves the spec's physical path, refuses a symlinked spec or records directory, and refuses a records directory outside the repository root. `--reindex` accepts only a directory named `decisions`. The paths block was rewritten in Task 3 to serve both compile and reindex modes.
