# It refuses a background `Agent` call and a resume of the session's own subagent, for the whole plan

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 3)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**It refuses a background `Agent` call and a resume of the session's own
subagent, for the whole plan.** The refusal applies while this session has
a plan ledger, including the final review and its fix wave, until Finish
leaves a receipt, matching the stop guard's "the guard holds for the whole
plan, not only its tasks". A `SendMessage` counts only when its `to` names
an agent id this session's own `Agent` results recorded; a message to
another session or a teammate passes. Rejected: refusing every
`SendMessage`, because `SendMessage` also reaches other local sessions,
which are not subagent resumes.

## What implementation changed

Implemented as specified. `decideDispatch` denies a background `Agent` call as `background-agent` and a `SendMessage` whose `to` is in the session's own collected agent ids as `sendmessage-resume`. It applies only to the controller (`screen` passes any payload with an `agent_id`) and only when `discover` finds a plan ledger. A message to any other target passes as `not-own-agent`. One detail beyond the spec text: `transcriptFacts` also treats `Task`, the tool's older name, as an Agent call, and counts a call's `name` input only when that call has a result.
