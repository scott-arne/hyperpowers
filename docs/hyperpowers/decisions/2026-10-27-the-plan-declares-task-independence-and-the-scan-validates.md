# The plan declares task independence and the scan validates it

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 2)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

The plan declares task independence and the scan validates it. Every task
carries a `**Depends on:**` line; the controller's pre-flight scan checks
declared independence against file and interface overlap and reports a
contradiction as a plan conflict; the per-session assigned task list
remains as an override that narrows selection and never bypasses a
dependency. Rejected: deriving independence from overlap alone (serializes
most plans and leaves no shared record); the assigned list alone (nothing
warns when two lists collide). Decided 2026-10-27 in chat.

## What implementation changed

Every task carries a `**Depends on:**` line, and `sdd-state deps` reads it through `hp_plan_graph`. It reports a contradiction between declared independence and file or interface overlap as a plan conflict. The writing-plans and subagent-driven-development skill text carries the per-session assigned list as an override that narrows selection and never bypasses a dependency. The state suite pins the conflict reports. Path conflicts keep heading order while interface conflicts sort numerically, and that was left as a deferred minor.
