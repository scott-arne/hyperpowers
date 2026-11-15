# The notice ceiling rises from 1,200 to 1,400 characters

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 6)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**The notice ceiling rises from 1,200 to 1,400 characters.** The
external workflow adoption spec (2026-09-10, B2) caps the context the
hook adds beyond the `using-hyperpowers` body at 1,200 characters when
every notice fires, and `tests/hooks/test-session-start.sh` measures 861
today. The re-read notice is 275 characters plus the plugin path, which
brings the ceiling case to about 1,186. The notice prints only on
compact runs, and a 14-character margin would fail on the next notice or
a longer test path. Rejected: cutting the notice further, which drops
either the stale-copy reason or the path; keeping 1,200 by shortening
the A9 notice, which is tested text outside this slice.
Reversed by decision 11 (2026-11-13); the notice did not ship.

## What implementation changed

Not applied. The ceiling stays at 1,200 characters in the `hooks/session-start` "Notice budget" comment and in the ceiling case of `tests/hooks/test-session-start.sh`. Decision 11 reversed this.
