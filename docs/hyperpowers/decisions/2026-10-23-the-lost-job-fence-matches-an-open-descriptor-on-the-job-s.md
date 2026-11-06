# The lost-job fence matches an open descriptor on the job's log

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 9)
- Recorded: 2026-11-06; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**The lost-job fence matches an open descriptor on the job's log.**
The identity fence also matches a process holding an open descriptor
on `<jobdir>/out.log`, read through `/proc` or `lsof`, and the `ps -E`
reader was removed; the Design section's text stays as written (human
partner, 2026-10-25).

## What implementation changed

Nothing recorded.
