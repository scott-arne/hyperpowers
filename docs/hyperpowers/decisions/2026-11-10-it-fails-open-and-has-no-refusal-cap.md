# It fails open and has no refusal cap

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 6)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**It fails open and has no refusal cap.** Anything it cannot read or
decide passes and is logged: an unreadable or malformed ledger header, an
unreadable transcript, and a transcript tail that hit the 16 MB cap before
the fact the decision needs. The stop guard caps refusals at two because a
refused turn end can trap a session; a refused dispatch always has an
allowed substitute (the same dispatch in the foreground, or a fresh
foreground implementer), so there is no trap to bound. Rejected: a cap of
two, which would let the third background dispatch through for nothing.

## What implementation changed

Implemented as specified. `planOf` and `readTranscriptFacts` return errors that `decideDispatch` turns into an allow logged as `hook-error`, with the cause in `detail`. A capped tail with no deciding fact passes as `transcript-capped`. There is no refusal counter. The wrapper appends a best-effort `hook-error` line when node is missing or the module exits non-zero, and `DISPATCH_GUARD_FAULT=throw` is a test hook for that path.
