# A tip or incoming commit carrying a symbolic link

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 7)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

A tip or incoming commit carrying a symbolic link, a submodule entry or a
recovery sidecar anywhere is refused whole. The check is absolute and
runs at checkout creation, at apply and at plain materialization; the
helper itself never produces those kinds, so only a hand-made commit
trips it, and such a host wedges every other host's `sync` until the
branch is repaired, with the path named. Scoping the check to the paths
an apply writes was rejected: it reopens the fresh-checkout and
materialization routes. Decided 2026-10-23 at the hand-back.

## What implementation changed

hp_tree_refusal in the library now also covers the .restore sidecar, in its plain and git-quoted forms, alongside .sync-applying and .rewrite, and refuses a tree carrying one before it reaches disk. It matches an exact root entry of those names as well as anything under them, so a root blob is refused too. The check runs at checkout creation, at apply and at plain materialization, and the refusal names the path. In sdd-state the pending scan exempts a dotted leftover only when neither side of the apply tracks the name, and a collision with an incoming tracked path is refused with a repair that moves the copy outside plans/.
