# Liveness is not judged by the tooling

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 12)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

Liveness is not judged by the tooling. A short-lived helper has no
process whose lifetime matches a controller session, so owner records
carry no pid, the board shows how long a holder has been silent, and
every takeover is your human partner's decision on that evidence.
Decided 2026-10-27 at the spec gate, superseding a round-2 resolution
that proposed a pid rule.

## What implementation changed

Owner records carry no pid. `board` shows how long a holder has been silent, and `claim` offers takeover only as your human partner's decision.
