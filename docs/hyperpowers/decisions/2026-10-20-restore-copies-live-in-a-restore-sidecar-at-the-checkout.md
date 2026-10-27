# Restore copies live in a `.restore` sidecar at the checkout root

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 10)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

Restore copies live in a `.restore` sidecar at the checkout root. The
sync apply stages them there, never inside a workspace directory, and
removes the sidecar once the apply has emptied it; the whole-tree
refusal, the link checks and the recovery sweep treat it as the third
recovery sidecar, to move with the other two in the later design.
Decided 2026-10-27 at the finish, from the implementation.

## What implementation changed

apply_files in sdd-state writes each restored file to a temporary copy under the checkout-root .restore sidecar and publishes it by one link, refusing to stage through a link at that path; recover_apply refuses a link at .restore and sweeps the sidecar whole; hp_tree_refusal refuses .restore as an exact entry and as a directory when it arrives from the branch, and the apply removes the sidecar once emptied. The state suite covers the link refusals, the write-time check through a seam, and the sidecar's removal.
