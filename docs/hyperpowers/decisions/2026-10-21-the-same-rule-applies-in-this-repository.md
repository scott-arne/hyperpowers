# The same rule applies in this repository

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 5)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**The same rule applies in this repository.** Its plans are removed at
finish like everyone else's; specs, records and the dated eval-evidence
notes carry the reasoning. The 26 existing plans stay until the human
partner decides on a backfill (Follow-ups).

## What implementation changed

CLAUDE.md in this repository now states that plans leave the tree at finish and that specs, decisions and evidence notes carry the reasoning. The `docs-allowlist` script and `docs/hyperpowers/.gitignore` add `decisions/` to the committed set, and its suite compares the output. The 26 existing plans are untouched. Docs-allowlist text in brainstorming and writing-plans was corrected by the final fix wave.
