# A PreToolUse dispatch guard enforces the foreground rule

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 1)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**A PreToolUse dispatch guard enforces the foreground rule.** A hook
refuses the two calls that end an SDD turn while a subagent works, at the
moment the controller makes them, whatever survived the last compaction.
Rejected: stronger text (the rule repeated in the compaction notice and in
SKILL.md's first 20,000 characters), because it still depends on the
controller following text after a compaction, which is the failure the
field shows, and it is a tuned-skill edit with its own eval; a stop-guard
refusal of a `live-agent` turn end, because by then the agent already runs
in the background, the controller has no foreground wait for it, and a
refusal produces polling up to the refusal cap.

## What implementation changed

Implemented as specified: `hooks/sdd-dispatch-guard` (bash wrapper) and `hooks/lib/dispatch-guard.mjs` are registered in `hooks/hooks.json` as a PreToolUse hook on `Agent|SendMessage`. The module exports `screen`, `planOf`, `transcriptFacts`, `gatherFacts`, `decideDispatch` and `main`, and imports `discover`, `linesFromEnd`, `appendLine` and `ledgerRecords` from `stop-guard.mjs`. The stop guard and the SKILL.md text are unchanged. `hooks/lib/dispatch-guard.test.mjs` and `tests/hooks/test-sdd-dispatch-guard.sh` cover it.
