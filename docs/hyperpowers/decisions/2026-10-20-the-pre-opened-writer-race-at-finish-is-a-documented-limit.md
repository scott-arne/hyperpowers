# The pre-opened-writer race at finish is a documented limit

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 8)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

The pre-opened-writer race at finish is a documented limit, not a
protocol change yet. A controller that opened the ledger before
`finish`'s rename and writes after the verification loses that line;
`finish` runs when the plan is complete, by the controller that owns it,
so the writer in question is a second session on the same plan, which
claims already discourage. The lock-sharing write helper that would close
it goes with the sidecar relocation below. Decided 2026-10-23 at the
hand-back.

## What implementation changed

No change.
