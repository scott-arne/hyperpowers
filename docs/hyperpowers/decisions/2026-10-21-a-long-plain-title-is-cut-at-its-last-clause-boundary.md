# A long plain title is cut at its last clause boundary

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 13)
- Recorded: 2026-10-22; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**A long plain title is cut at its last clause boundary.** A decision
item without a bold title takes its first clause as its record title;
a clause longer than 80 characters is cut inside its first 80 at the
last `, ` or `; ` that leaves at least 20 characters, else at the last
space, else not at all, and the spec is never edited to fit the parser.
Chosen at Task 12's Codex gate, in the human partner's words "Clause
boundary (Recommended)", over dropping the cap (legacy headings of 150
characters) and over the plain word-boundary cut, which left fragments
such as "...its load-bearing content". New specs carry bold titles, so
the rule serves legacy material.

## What implementation changed

Nothing recorded.
