# Session ids exclude whitespace and colons, and the board skips names that are not session ids

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 8)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**Session ids exclude whitespace and colons, and the board skips names
that are not session ids.**

## What implementation changed

No change. `sid_ok` refuses whitespace and `:` with the quoted message, `cmd_register` validates its session id, `cmd_snapshot` validates a given `--session` whatever its value (`sid_given`), and `board_entries` skips any name `sid_ok` refuses.
