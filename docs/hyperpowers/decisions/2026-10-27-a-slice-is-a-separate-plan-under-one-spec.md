# A slice is a separate plan under one spec

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 6)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

A slice is a separate plan under one spec. Each slice is its own plan
file and workspace run by its own session; plans that share a spec and a
branch are handled explicitly, including the spec's Outcome line at
finish and the branch's teardown; no inter-plan dependency field is added
in this design. Decided 2026-10-27 in chat.

## What implementation changed

Each slice is its own plan file with its own workspace, and `register` checks same-spec siblings. `decisions-compile` was changed so a shared spec's Outcome line appends each finishing plan and date, and keeps an older bare date as the first entry. It also refuses, with exit 2 and no writes, a second plan that has the same file name as a recorded plan. No inter-plan dependency field was added. The final gate also made `register` compare a same-spec sibling dossier left in a removal tomb at `plans/.removing-<ws>-<pid>`, which the first scan of `plans/*/` missed.
