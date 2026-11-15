# SDD's re-read paragraph sends the session to the board, the ledger lines of the task it holds, and the step file a table in the controller names for that state

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 8)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**SDD's re-read paragraph sends the session to the board, the ledger
lines of the task it holds, and the step file a table in the
controller names for that state.** This amends decision 4 for SDD; the
brainstorming paragraph is unchanged, since that skill re-reads in one
Read for about 7,000 tokens and passed 10 of 10 in 6.16.2. Rejected:
keeping the full-file re-read, which loops at 100,000 (measured).

## What implementation changed

The SDD "After every context compaction" paragraph now sends the session to the board, the ledger lines of its task and a step table in the controller. A dated Correction (2026-11-13) made the table read only the newest line it names and ignore other lines, made `fix-loop.md` write the `review` line after the `fix round` line, and made `setup.md`'s resume rule match; `tests/sdd/test-sdd-layout.sh` checks both. `hooks/lib/dispatch-guard.mjs` `refusalText` and its test now name SKILL.md and the step file its step table names.
