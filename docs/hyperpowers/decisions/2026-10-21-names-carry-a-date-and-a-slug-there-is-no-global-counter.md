# Names carry a date and a slug; there is no global counter

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 8)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**Names carry a date and a slug; there is no global counter.** The
filename is the spec's date plus a slug of the decision title. A record's
identity is its spec path and decision number; a filename collision with
a different identity takes a decision-number suffix (Design §1). Two
branches recording decisions at once never have to agree on a counter.

## What implementation changed

`title_of`, the slug rule and the filename are computed in the compiler as spec date plus a slug of the title (word-boundary and clause cuts at 80 characters, set by the Task 12 corrections). A different-identity collision takes a decision-number suffix, and a third collision is refused. The 12 titles from a dry run over this spec match the decisions list. No counter exists, and the suite covers collisions.
