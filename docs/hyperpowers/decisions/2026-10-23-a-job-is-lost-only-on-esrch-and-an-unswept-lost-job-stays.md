# A job is lost only on ESRCH, and an unswept lost job stays live

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 8)
- Recorded: 2026-11-06; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**A job is lost only on ESRCH, and an unswept lost job stays live.**
`tracked-job wait` declares `lost` only when `kill -0` on the
supervisor answers ESRCH and no `exit` appears within the grace;
`stop` on a lost job it cannot sweep writes `lost-unswept` (exit 7),
which the hook counts as a live tracked shell (plan deviation 2,
approved 2026-10-24).

## What implementation changed

Nothing recorded.
