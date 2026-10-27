# The parallel model to serve first is one controller session per parallel task

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 2)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

The parallel model to serve first is one controller session per parallel
task, each session in its own worktree. The shared ledger is designed now;
a single controller fanning out implementers comes later and must fit the
same ledger.

## What implementation changed

No change.
