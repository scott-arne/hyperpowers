# `gate-wait` caps the budget at 570 seconds so one call fits the 600000 ms shell

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md (decision 11)
- Recorded: 2026-11-04; plan docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md removed at finish

## Decision

`gate-wait` caps the budget at 570 seconds so one call fits the 600000 ms
shell timeout, and it must run outside the shell sandbox.

## What implementation changed

Nothing recorded.
