# The approach is a materialized dependency graph with atomic claims

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 10)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

The approach is a materialized dependency graph with atomic claims. Run
state stays in files the dossier already reads (the ledger, claim
directories, per-session records) rather than an event log with
projections or a compiled per-run manifest with merge tickets; the
Codex approach gate converged on this independently. One detail of the
manifest approach is kept: merge-back merges exactly the approved
commit, validated against the current integration head. Decided
2026-10-27 in chat.

## What implementation changed

Run state stays in the ledger, per-task claim directories and per-session records. No event log or compiled manifest was added. `merge-back` merges exactly the approved commit and validates it against the current integration head, as the decision keeps.
