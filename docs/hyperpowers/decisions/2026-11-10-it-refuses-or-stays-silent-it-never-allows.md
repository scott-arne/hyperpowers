# It refuses or stays silent; it never allows

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 7)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**It refuses or stays silent; it never allows.** A PreToolUse `allow`
decision skips the user's permission prompts, so the hook prints a deny or
nothing.

## What implementation changed

Implemented as specified. `main` returns either silence or a deny JSON built from `refusalText`, and the unit tests assert that no path prints an allow. Pass-through decisions return the frozen `SILENT` result.
