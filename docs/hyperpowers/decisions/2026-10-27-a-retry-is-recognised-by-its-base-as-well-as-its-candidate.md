# A retry is recognised by its base as well as its candidate

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 15)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

A retry is recognised by its base as well as its candidate. A published
amendment record answers `already=1` only when its `base=` is this
call's base; a call for the same candidate from another base finishes
that record's ledger lines and then publishes as a fresh amendment, so
amending B, crashing, amending to C and back to B republishes B instead
of reporting it published. Decided 2026-11-04 in chat, during Task 6 of
the plan.

## What implementation changed

An amendment record answers `already=1` only when its `base=` is this call's base. A call for the same candidate from another base finishes the record's ledger lines and publishes as a fresh amendment, so amending B, crashing, amending to C and back to B republishes B. The state suite has a fixture for this, including a deterministic ambiguous base.
