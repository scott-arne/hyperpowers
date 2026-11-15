# The re-read instruction goes in the `session-start` compaction notice

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 2)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**The re-read instruction goes in the `session-start` compaction notice.**
The hook runs from disk on every compaction, so its text is current even
in a session holding old skill text, and its output is injected verbatim
into the resumed context. Rejected: stronger or earlier SKILL.md text,
because a stale session never sees an edited skill file; a plugin
PreCompact hook, because its output feeds the model-written summary and
was dropped on 2026-11-04 for lack of evidence of wrong actions after
compaction.
Reversed by decision 11 (2026-11-13); the notice did not ship.

## What implementation changed

The notice did not ship. `hooks/session-start` carries no re-read notice, and `tests/hooks/test-session-start.sh` asserts that a compact run adds nothing beyond the ledger notice. Decision 11 reversed this; the shipped fix is the compact SDD controller.
