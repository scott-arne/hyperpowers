# `enc` escapes control characters and leaves `%` alone

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 10)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**`enc` escapes control characters and leaves `%` alone.** Rejected: a
reversible encoding that escapes `%` first, because it would change
existing outputs that hold `%`; these fields are displayed, not compared
as keys, which is what the reversible-encoding record covers.

## What implementation changed

No change. `enc` escapes bytes 0x01-0x1F and 0x7F as `%XX` and the space as `%20`, and leaves `%` and every other byte alone. It runs in a `LC_ALL=C` subshell and takes a fast path for values with no control character.
