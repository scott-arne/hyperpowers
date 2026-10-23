# The delta runs inside existing waits and is never waited for

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 7)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**The delta runs inside existing waits and is never waited for.** Under
SDD the extractor is dispatched in the background once the final
review's fix wave and its re-review are clean, so its diff includes that
fix wave; its window is the Codex final gate when Codex is present and,
on every path, the finishing skill's full test run that follows. Outside
SDD, finishing-a-development-branch dispatches it in the background
before the test run. Collection happens in one place, finishing Step 1,
after the suite has passed: an extractor that has not finished is not
waited for; it is stopped with the harness's task stop, the skeleton
compiles without notes, and the hand-back says so. Background dispatch is
the Agent tool's `run_in_background: true` where the tool offers the
parameter (print and SDK sessions, which is what Zed runs), and the
default in Claude Code 2.1.302 interactive sessions, whose fork mode
runs every subagent in the background and omits the parameter; where a
harness has no tracked background subagent the skeleton compiles alone
and there is nothing to stop.

## What implementation changed

The SDD skill dispatches the extractor in the background after the final review's fix wave is clean, and writes a `Decision extractor:` ledger line as the dispatch's completion step. The finishing skill dispatches its own extractor when none is named and collects only in Step 1 after the suite, stopping an unfinished one with TaskStop and compiling without notes. The extractor reads a regenerated full-branch package, and a Codex final-gate fix stops and re-dispatches it. Fork-mode and `run_in_background` handling are documented, and the SDD contract suite and live runs in the evals repository exercise the stop path.
