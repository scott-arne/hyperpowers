# One file per decision

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 1)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**One file per decision.** A record is a page: status, the spec and
decision number it comes from, the decision text, and what implementation
changed. A reversal is a new record that names the old one, and the old
one's status flips to superseded; nothing else in it is edited. One
record per shipped spec was rejected because supersession at that grain
has to point inside another file, and one living file per repository was
rejected because it is edited in place and conflicts across parallel
branches.

## What implementation changed

The `decisions-compile` script under the finishing skill's scripts directory renders one record file per Decisions item, with status, spec path, decision number, the verbatim decision text and an implementation section. A reversal is a `Supersedes:` line on the new item, and the compiler rewrites only the target record's Status line, through `drop_status` and a status-only ownership check. Record identity is the spec path plus the decision number, and the compiler's suite covers rendering, supersession and re-runs. Targets are reconciled before records are rewritten, so an interrupted run completes on the next run.
