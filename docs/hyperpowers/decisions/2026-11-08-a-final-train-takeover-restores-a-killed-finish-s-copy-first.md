# A final-train takeover restores a killed finish's copy first

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 5)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**A final-train takeover restores a killed finish's copy first.** The
takeover then runs as one of an open plan. Rejected: refusing, because the
session taking over cannot run finish without the train.

## What implementation changed

The implementation is broader than the spec text, and the plan's decision-5 correction records it. `restore_removed_copy` is shared by finish and by every final-train takeover (not only when `progress.md` is missing). Its occupancy check runs first: any entry at the workspace path (a directory, and in takeover mode a file or link too) with a copy beside it prints finish's stderr line and answers `status=busy` (exit 3), whether or not the copy would be restored. Only then does a takeover skip a copy that lacks `progress.md` or, on the branch backend, that the state branch no longer tracks, so a copy whose removal was committed is not resurrected; such a copy is left and the claim takes the orphan path. A takeover never moves a workspace aside: it publishes the copy with one `renameSync`, so a non-empty directory, file or link that takes the path after the occupancy check answers `busy` with the copy untouched, while an empty directory that appears in that window is replaced and the takeover proceeds. The plan's wording that a copy beside any workspace answers `busy` therefore holds for the occupancy check but not for an empty directory created after it. A failed restore answers `status=error` (exit 2), and the claim loop settles again on the restored plan line.
