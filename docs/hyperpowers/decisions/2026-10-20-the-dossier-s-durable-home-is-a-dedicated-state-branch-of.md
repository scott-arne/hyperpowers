# The dossier's durable home is a dedicated state branch of the same repository

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 3)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

The dossier's durable home is a dedicated state branch of the same
repository, checked out under the cache. Rejected: a checkpoint committed
onto the work branch at hand-off (scratch in product history, two copies to
reconcile, checkpoints landing in master when working on the current
branch); writing the dossier live into the tracked working tree (each
worktree gets its own copy, so parallel sessions never share a ledger, and
partial state rides into implementer commits); a Unison-synced state root
(conflict and deletion semantics outside git). The Codex approach gate
independently proposed the state branch and the checkpoint; the Unison root
was its third.

## What implementation changed

No change.
