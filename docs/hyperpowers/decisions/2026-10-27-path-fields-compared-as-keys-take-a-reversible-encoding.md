# Path fields compared as keys take a reversible encoding

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 19)
- Recorded: 2026-11-07; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

Path fields compared as keys take a reversible encoding. The `shares=`
paths that `deps --check` and `amend` print, and a plan line's `spec=`,
go through `enc_spec` (a percent sign becomes `%25` first, then a space
`%20`), so "a b" and "a%20b" stay distinct; every other path-valued
field keeps `enc`, which only turns a space into `%20` and is read,
never compared. This departs from the plan's Global Constraint that
every path-valued field goes through `enc`. Rejected: `enc` for these
fields (a path holding a literal `%20` would compare equal to one
holding a space). Made during execution and accepted at finish on
2026-11-07.

## What implementation changed

Nothing recorded.
