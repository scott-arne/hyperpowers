# The field rate measured stale skill text; this slice adds a notice and evaluates it

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 1)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish
- Supersedes: docs/hyperpowers/decisions/2026-11-10-this-slice-fixes-turn-liveness-the-compaction-loss-is-the.md

## Decision

**The field rate measured stale skill text; this slice adds a notice and
evaluates it.** In 60 of 77 field compactions the re-attached SDD copy
lacked the re-read paragraph, because the session had loaded a version
without it; with the paragraph present the field re-read the cut text
after 15 of 17 (human partner, 2026-11-11). Rejected: the eval decision 2
asked for, which would reproduce a plugin-version artifact and measure no
compliance problem; closing the slice with no change and re-measuring
after sessions restart, because stale text recurs after every release and
the field shows sessions running for weeks.
Supersedes: docs/hyperpowers/decisions/2026-11-10-this-slice-fixes-turn-liveness-the-compaction-loss-is-the.md

## What implementation changed

No change.
