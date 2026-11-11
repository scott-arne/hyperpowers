# A damaged `closing=` reads as closing

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 6)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**A damaged `closing=` reads as closing.** Only an exact `0` keeps the
branch open. Rejected: refusing the takeover, because a damaged file would
then leave the final train stuck. Accepted cost: sibling plans wait until
the finish removes the lease.

## What implementation changed

No change. Both takeover sites now read `[ "$lclosing" = 0 ] || lclosing=1`, so only an exact `0` keeps the branch open.
