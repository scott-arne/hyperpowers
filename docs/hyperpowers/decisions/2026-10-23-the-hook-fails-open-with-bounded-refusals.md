# The hook fails open with bounded refusals

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 2)
- Recorded: 2026-11-06; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**The hook fails open with bounded refusals.** It refuses only on a
confident read; anything unreadable allows, with its reason logged. The
cap is on consecutive refusals, two, counted per plan log and reset by
any allow: a bounded loop, never a disarmed guard for the rest of a long
session. The fail-closed alternative (an explicit permit
required for every stop) traps sessions on a stale ledger or a hook bug
and was declined.

## What implementation changed

Every read the hook cannot complete allows: `discover` answers `ambiguous` (with `detail: unreadable: <paths>`) when any candidate ledger, receipt or directory cannot be read, even beside one readable match, and answers `ambiguous` on more than 64 candidates before any is read. `liveJobs` returns unreadable `meta.json` records, which `decideStop` allows as `hook-error`, and an unreadable or malformed plan log allows as `hook-error` instead of counting zero refusals. `main` writes nothing for a session id that is not one `[A-Za-z0-9._-]` token, and `appendLine` refuses symlinks (`O_NOFOLLOW`), fences a half-written line with the ledger's `#fragment` marker, and treats a short write or a workspace moved or removed under the write as a failed log (`log-failed`). A field defect found under the installed treatment, where plain files beside the clone keys (such as `<key>.backend`) made every Stop from outside a repository `ambiguous`, was fixed in Task 21a (`fea1999`): a plain file in the cache reads as absence, not as an unreadable candidate. The count is per plan log: a block only the mirror holds belongs to another plan of the session and neither counts nor resets. An accepted residual (human partner, 2026-10-26): a decision glued to another writer's fragment makes `tailLines` report the plan log as malformed on every later Stop, so that plan's guard allows as `hook-error` until the line is removed by hand.
