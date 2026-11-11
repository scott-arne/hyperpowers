# Records publish with one `rename(2)`, and the plain snapshot stamps under the plan lock

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 7)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**Records publish with one `rename(2)`, and the plain snapshot stamps
under the plan lock.**

## What implementation changed

No change. `record_publish` publishes with node's `renameSync`, mapping `EISDIR`, `ENOTEMPTY`, `EEXIST` and `ENOTDIR` to the "refusing to replace it" refusal and other errors to return 1, with the pre-check kept for its message. The plain path of `cmd_snapshot` takes `hp_lock "$PLAN_DIR"` before the `progress.md` check and releases it after the stamp.
