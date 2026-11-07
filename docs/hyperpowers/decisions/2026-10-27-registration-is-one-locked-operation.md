# Registration is one locked operation

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 13)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

Registration is one locked operation. A session's first act on a plan
registers the plan line through a subcommand that, under the locks,
checks the plan's siblings and the branch's lease and writes the line,
so two Setups cannot both pass a check and write conflicting lines.
Decided 2026-10-27 at the spec gate.

## What implementation changed

`sdd-state register` takes the locks, checks same-spec siblings and the branch lease, and writes the plan line in one operation. It exits 15 on a closing branch. Its lock-order fixture derives the lock order with the same comparator as the code. The SDD skill's Setup runs the detach before `register`, which amends the brief's "before its first claim". An ordering needle pins this.
