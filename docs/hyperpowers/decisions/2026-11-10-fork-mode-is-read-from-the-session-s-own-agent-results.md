# Fork mode is read from the session's own `Agent` results

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 4)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**Fork mode is read from the session's own `Agent` results.** A session
is outside fork mode when one of its own `Agent` calls in the transcript
tail came back synchronously: `toolUseResult.status` is `completed` and
`isAsync` is absent or false (ac2e27de's result at 17:43:58Z in
ec562ba3). In fork mode every dispatch comes back
`{"isAsync":true,"status":"async_launched"}`, whatever the call passed,
so no such result exists. Only outside fork mode is either call refused;
in fork mode a background flag changes nothing and a `SendMessage` resume
is the skill's documented route. A session that has made no foreground
dispatch yet reads as unknown and passes. Rejected: the presence of a
`run_in_background` key in the session's calls, because a fork-mode
controller passed it on 15 of 15 dispatches in the turn-liveness smoke
(plan deviation 9), where the harness ignored it, and on none in T1;
reading `CLAUDE_CODE_ENTRYPOINT` or `CLAUDE_CODE_FORK_SUBAGENT`, because
the fork-mode default depends on the Claude Code version and entrypoint
and the hook would have to track it.
This does not reverse the stop guard's record "`SendMessage` resumes stay,
pending Z4": its contingency already moved fix rounds outside fork mode to
fresh foreground dispatches, and this hook enforces that route; the
record's "fork mode is documented, not detected" concerns the stop guard,
which is unchanged.

## What implementation changed

Implemented as specified. `transcriptFacts` reads main-chain records only (sidechain records are skipped) and sets `sync` when an `Agent` result has `status` `completed` with `isAsync` absent or false. `decideDispatch` denies only when `sync` is true. Facts found in a tail that hit the cap still count. A session with no synchronous result passes as `fork-mode`, and the string `"true"` for `run_in_background` is treated like the boolean. Task 1 recorded payload probes C1 to C5 confirming the payload fields, agent_id for subagents, deny handling and result shapes.
