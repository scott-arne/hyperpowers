# This slice fixes turn liveness; the compaction loss is the next slice

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 2)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**This slice fixes turn liveness; the compaction loss is the next slice.**
The field re-read rate (16 of 63) means every SKILL.md rule past character
20,000 is mostly unfollowed after a compaction, not only the dispatch
rules. That gets its own design, whose first task is an eval that
reproduces the field rate (human partner, 2026-11-10). Rejected: one
larger slice, because the Zed symptom has a fix that needs no compliance
while the re-read problem cannot be measured until its eval exists.

## What implementation changed

No change.
