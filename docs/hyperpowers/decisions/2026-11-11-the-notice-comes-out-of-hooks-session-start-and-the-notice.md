# The notice comes out of `hooks/session-start`, and the notice ceiling returns to 1,200 characters

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 11)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**The notice comes out of `hooks/session-start`, and the notice ceiling
returns to 1,200 characters.** The controller with the notice finished 5
of 10 runs at the 100,000-token window, and all five failures stopped in
the finishing step; the human partner had ruled the notice off any
release (2026-11-12) and chose to remove it and measure the controller
alone (2026-11-13). This amends decisions 2, 3 and 9 and reverses
decision 6. Rejected: keeping the notice on the branch unreleased, which
a merge would ship and the decision records would record as adopted;
keeping the branch unmerged, which leaves the controller's gain over
6.18.1 unused.

## What implementation changed

`hooks/session-start` no longer builds the re-read notice, and the notice ceiling is back at 1,200. A compact-run case in `tests/hooks/test-session-start.sh` asserts the notice text is absent. The shared `spell_path` helper that decision 2's design extracted from the A9 ledger-notice block stayed, with the A9 output unchanged.
