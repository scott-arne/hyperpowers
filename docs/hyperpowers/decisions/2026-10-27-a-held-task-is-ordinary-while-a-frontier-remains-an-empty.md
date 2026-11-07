# A held task is ordinary while a frontier remains; an empty frontier is the ask

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 7)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

A held task is ordinary while a frontier remains; an empty frontier is
the ask. A session that finds a task held by another session takes the
next claimable task; only when nothing is claimable does it post to the
board and hand back, and it takes a held task over only on your human
partner's explicit yes. This refines the dossier skill's "held means ask"
and supersedes the clarifying answer's shorter wording; approved with
design section 2. Decided 2026-10-27 in chat.

## What implementation changed

The SDD skill text now says a session that finds a task held takes the next claimable task. It posts to the board and hands back only when nothing is claimable, and it takes over a held task only on your human partner's explicit yes. `claim` answers `held` for an existing claim, and the takeover path uses branches named `.task-<N>.<k>`. The final gate fixed a takeover of a merged but uncompleted task, which now answers `claimed takeover=1 branch=none merged=1`, makes no ref, and does not redispatch the task.
