# `gate-wait` sweeps every job before each blocking slice and keeps the 16-minute

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md (decision 6)
- Recorded: 2026-11-04; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md removed at finish

## Decision

`gate-wait` sweeps every job before each blocking slice and keeps the
16-minute watch cap; it only reduces the number of model calls inside it.

## What implementation changed

New script skills/requesting-code-review/scripts/gate-wait watches all Codex job ids in one call. It does a full non-blocking status pass over every job before each blocking slice of at most 30 seconds, within a default 480-second budget (maximum 570). Exit 0 means every job is terminal, 2 means the budget ran out with jobs still running, and 1 means a usage error or an unreadable job. recipe-code.md, gate-lenses.md and gate-findings.md now use it, and the 16-minute watch cap is unchanged. tests/codex-review-gate/test-gate-wait.sh covers it, and the gate-contract, split-lossless and post-split-edits tests were updated for the edited docs.
