# It logs to a per-session file in the cache only

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 8)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**It logs to a per-session file in the cache only.** Lines go to
`${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/dispatch-guard/<session>.jsonl`.
Rejected: a copy in the SDD workspace, because Finish, `sdd-state` and the
state branch would then have a new file to carry or skip.

## What implementation changed

Implemented as specified. `main` calls `appendLine` for `<cache>/hyperpowers/dispatch-guard/<session>.jsonl` only. The log write cannot undo a refusal. Nothing is written to the SDD workspace.
