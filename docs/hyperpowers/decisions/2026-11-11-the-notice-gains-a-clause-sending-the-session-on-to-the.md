# The notice gains a clause sending the session on to the files the skill names after a compaction, and its ceiling follows a measurement

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 9)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**The notice gains a clause sending the session on to the files the
skill names after a compaction, and its ceiling follows a measurement.**
This amends decision 6: the plan measures the ceiling case with the new
text and raises the ceiling only by what that measurement needs.
Rejected: dropping the notice, which leaves sessions on stale skill text
with no pointer to the installed copy; keeping its old text, which names
only SKILL.md while the step text now lives beside it.
Reversed by decision 11 (2026-11-13); the notice did not ship.

## What implementation changed

Not applied. No notice clause was added, and the notice text was removed under decision 11.
