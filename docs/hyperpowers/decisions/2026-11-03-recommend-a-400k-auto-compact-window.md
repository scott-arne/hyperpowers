# Recommend a 400K auto-compact window

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md (decision 3)
- Recorded: 2026-11-04; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md removed at finish

## Decision

Recommend a 400K auto-compact window; 300K and 200K add 1.5x and 2.6x the
extra compactions for 4 and 7 more points of savings.

## What implementation changed

The README gained a "Cost and Context" section recommending `"autoCompactWindow": 400000` (or `CLAUDE_CODE_AUTO_COMPACT_WINDOW`), with the replay result of about 28% savings and the 300K and 200K tradeoff stated. The 6.16.2 CHANGELOG entry repeats the recommendation. No skill or hook enforces the window.
