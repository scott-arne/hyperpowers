# Unlocked concurrent appends stay unserialized

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 10)
- Recorded: 2026-11-06; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**Unlocked concurrent appends stay unserialized.** A machine line
glued to another writer's fragment, a hook decision glued in the plan
log, and a line appended during Finish's final receipt copy are
accepted residuals (human partner, 2026-10-25 and 2026-10-26; Codex
final gate disposition, 2026-11-06).

## What implementation changed

Nothing recorded.
