# Tracked jobs get their own process group through bash job control

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 7)
- Recorded: 2026-11-06; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**Tracked jobs get their own process group through bash job control.**
`tracked-job run` starts the command with `set -m` instead of
`setsid`, so the command and its supervisor stay in the controller's
session (plan deviation 1, approved 2026-10-24).

## What implementation changed

Nothing recorded.
