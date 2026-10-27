# A verified import keeps the legacy workspace as a dated copy

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 6)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

A verified import keeps the legacy workspace as a dated copy. The source
is renamed to `<source>.imported-<UTC>-<pid>` beside its physical
location (the pointer's referent when the candidate was a pointer) rather
than deleted: a session on the previous plugin that still holds the legacy
ledger open appends into that copy, where a human can find the line, and
the plain-cache reclaim sets that root aside under a `.reclaiming-` name
once nothing under it is newer than 14 days and deletes it on a later call
after 14 more quiet days, so an append that lands during the first 14 days
buys the copy another 14. Decided 2026-10-23 at the hand-back.

## What implementation changed

The import in sdd-state renames the verified source to its dated imported-copy name beside its physical location, picking a unique suffix when the name is taken; the completion arm and the verify path find the copy through hp_kept_copy_exists, which also looks inside claiming and reclaiming roots. The reclaim in sdd-dir became two-phase: an idle plain root is first claimed (staged, then renamed to a reclaiming name, with pid-checked adoption through hp_pid_gone) and deleted only on a later call after further quiet days, so a late append buys the copy another period. The reclaim publishes a quarantine only after its grace stamp lands, and it and prune treat a failed traversal as not idle rather than as silence. Import now refuses, naming the quarantine and a repair, when a never-imported legacy workspace sits in a root the reclaim staged, quarantined or marked gone, whatever the state of the live root, so a recreated root cannot start a fresh ledger beside the real dossier. A reclaimed root put back under a racing session's recreated root is no longer nested, which added a third value to the HYPERPOWERS_TEST_RECLAIM_RACE seam, and the pointer prune keeps an interrupted import's handle.
