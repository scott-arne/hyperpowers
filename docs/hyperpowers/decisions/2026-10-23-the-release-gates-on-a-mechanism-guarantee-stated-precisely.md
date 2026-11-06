# The release gates on a mechanism guarantee, stated precisely

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 1)
- Recorded: 2026-11-06; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**The release gates on a mechanism guarantee, stated precisely.** A Stop
hook refuses a turn end it can prove premature: this session's plan is
unfinished, the last message hands nothing back, nothing tracked is
live. The guarantee is: such an attempt is refused, and so is an
immediate second one; a third consecutive attempt is allowed and logged
as `cap`, and the count starts again after any allow. For a session that
has a plan (or a receipt of one), every decision is logged with its
reason, in the plan's log and the session mirror, or in the mirror alone
when no plan log applies (`ambiguous`, `log-failed`) or the hook itself
failed (`hook-error`, written by the bash wrapper without node); the one
unrecorded decision is an allow whose mirror also cannot be written.
6.17.0 ships when unit tests prove
that table, the scenario shows no false refusal and no premature stop
reaching the user, and the mechanism measures hold; the field confirms
the rate afterwards and never gates a release by itself. The two
alternatives, releasing on the field rate (three to six weeks per
candidate, confounded by Claude Code and model updates) and rebuilding
the scenario to elicit stops (design risk, no guarantee the elicited
kind is the field's kind), were declined.

## What implementation changed

The guarantee is `decideStop` in `hooks/lib/stop-guard.mjs` with `REFUSAL_CAP` 2. Its count comes from `refusalsBefore`, which counts only `block` lines present in the plan's own `stop-guard.jsonl`, orders them by the session mirror's file order with plan-log-only lines inserted by `ts` (`mergedDecisions`), reads the last 200 lines of this session per log (`tailLines`), and resets on an allow from either log; `recordDecision` writes the plan log first and then the mirror, and `hooks/sdd-stop-guard` writes the wrapper's `hook-error` line with `printf`. Beyond the spec, `hook-error` is also the module's own allow, logged to both logs, when a job record, the decision log or the reread ledger cannot be read; the table is pinned by `hooks/lib/stop-guard.test.mjs` (among others "main: block, block, cap, block, block, cap; a hand-back resets" and "main: a mirror-only allow between refusals resets the count"). The scenario half of the gate changed under Correction 9 (human partner, 2026-10-28): H1 became "no off-plan hook line in the plan window", a listed stop found in an AskUserQuestion call answered inside its turn is an in-turn stop owed no allow, and H2's adjudication was widened to `cap` allows and to `log-failed` allows that displaced a refusal, a deviation the evidence note records. All three ten-run campaigns recorded `runs_with_plan_decisions: 0`, so H1 held vacuously, H2's adjudication half and H3 held with no cases, and the only live refusal is Zed run 3's `open-tasks` block. The decision of record became `tally-z4b.txt` (PASS, treatment `36a6255`, Claude Code 2.1.317) after the Z4 contingency's `tally-z4.txt` read FAIL and Correction 12 corrected the F reader before ten fresh runs; the 6.17.0 CHANGELOG entry and the note's Release section state the guarantee in its precise form and the H1 vacuity.
