# Switching is served by a waiting board, not a relay

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 4)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

Switching is served by a waiting board, not a relay. Per-session waiting
records in the dossier, a subcommand that prints them from any shell or
session, and skill text that posts and hands back when blocked. A
cross-session question relay is a follow-up once the board shows what
blocks sessions; a permission prompt is answerable only in the session
that raised it. Decided 2026-10-27 in chat.

## What implementation changed

`sdd-state wait` posts a per-session waiting record in the dossier, and `sdd-state board` prints those records from any shell. The SDD skill text posts and hands back when a session is blocked. No question relay was built, and the state suite covers `wait` and `board`.
