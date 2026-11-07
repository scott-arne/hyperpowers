# Multi-session first

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 1)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

Multi-session first. The unit of parallelism is a Claude session in its
own worktree, claiming tasks from the shared dossier; a single controller
fanning out implementers stays deferred, and the dependency statement
this design adds is written so a later fan-out controller reads it
unchanged. Decided 2026-10-27 in chat.

## What implementation changed

The dossier now supports several sessions, each in its own worktree, claiming tasks through `sdd-state` subcommands (`claim`, `next`, `register`, `merge-back`). The dependency statement is the plan's `**Depends on:**` line, read by `hp_plan_graph` in `sdd-common.sh`, so a later fan-out controller can read it unchanged. No fan-out controller was added.
