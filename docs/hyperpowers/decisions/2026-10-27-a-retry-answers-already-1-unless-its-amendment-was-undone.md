# A retry answers `already=1` unless its amendment was undone

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 16)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

A retry answers `already=1` unless its amendment was undone. A record
whose commit is on the plan ref and whose base is this call's base
answers `already=1` while the ref's plan is anything but that base, a
later amendment's blob included; a plan back at exactly the base
finishes the record's ledger lines and publishes the amendment again,
and a ref that no longer carries the plan answers `status=error`. An
undo that also edits the plan still answers `already=1`, an accepted
gap. Rejected: `already=1` only while the plan is still the record's
blob (a retry after a later amendment would answer `stale` although its
change is in force); the literal rule, `already=1` whenever the commit
is in the ref's history (it reports an undone amendment as published).
Decided 2026-11-05 in chat, during Task 6 of the plan.

## What implementation changed

The implementation follows the rule in the decision, called decision B in the ledger. A record whose commit is on the plan ref and whose base is this call's base answers `already=1` while the plan is anything but that base. A plan back at exactly the base finishes the record's ledger lines and publishes again. A ref without the plan answers `status=error`. The brief's "w twice" fixture was restored. Deferred minors are that an amendment identical to its base, such as one that only records an `--accept`, is never `already=1` on retry, and that a commit which later deletes the plan file leaves the current plan empty. A spec docs commit added the undo and deleted-plan exceptions.
