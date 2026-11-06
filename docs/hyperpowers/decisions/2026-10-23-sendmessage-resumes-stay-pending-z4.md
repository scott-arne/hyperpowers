# `SendMessage` resumes stay, pending Z4

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 6)
- Recorded: 2026-11-06; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**`SendMessage` resumes stay, pending Z4.** They keep the implementer's
context. The hook treats a resumed agent as live work, and whether Zed
shows that as working is a release check with a written contingency.
Fork mode is documented, not detected, and gets one terminal smoke run.

## What implementation changed

Release check Z4 failed in Zed runs 1 and 2 (2026-11-05): a `SendMessage` resume for a fix round ran in the background, the hook allowed the turn end as `live-agent`, and no turn was open for 4 min 12 s and 19 s. The decision's written contingency shipped in `777a2b3` to `36a6255`: on Claude Code outside fork mode, rounds 1 to 3 dispatch a fresh foreground implementer (`run_in_background: false`) on the original implementer's recorded model with the brief path, the report path and the findings, and the `SendMessage` resume remains for harnesses without the option, fork mode among them; the task-loop graph, `fix-subagent-prompt.md` and `implementer-prompt.md` follow, and `tests/sdd/test-sdd-contract.sh` moved its needle to "a fix round on Claude Code dispatches a fresh foreground implementer; a SendMessage resume is for harnesses without the option" and added the fork-mode needle. The hook still reads a `SendMessage` resume as live work by its tool-use id (`readTurn`, test "a resumed agent is matched by the SendMessage tool-use id, not the agent id"). The contingency was re-measured twice (`tally-z4.txt` FAIL, `tally-z4b.txt` PASS), but no counted run needed a fix round, so Zed run 3's 11 s foreground fix round is the route's only live case. T1 ran the fork-mode scenario once, uncounted: 13 background dispatches, all 13 completions matched by tool-use id, and 12 `live-agent` allows.
