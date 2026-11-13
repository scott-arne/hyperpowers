## Final Review

Part of [SKILL.md](SKILL.md); the rules there hold in this step.

The final train is claimed. When `next` says `complete`, run
`scripts/sdd-state claim PLAN_FILE final --session <sid>`: `claimed` means
this session runs the final review, the final gate and Finish; `blocked`
names tasks still open (claims without completion lines elsewhere: wait or
ask); `held` with your own session id (`own=1`, a resume after compaction)
means this session already holds the train: continue as its holder; `held`
names the session that holds it, or `lease=<sid> plan=<ws>`
when a sibling plan's final holds the branch: post a `tasks` record naming
the holder, print the board, and hand back. The holder checks the
integration branch out in its own worktree (`git switch <integration>`), the
one time a session does so, and runs the review package, the final
reviewer, the fix wave and the final Codex gate on it; its fix commits land
on the integration branch directly, which the lease makes safe.

Once you hold the train and have checked the integration branch out, the
final whole-branch review gets a package too: run
`scripts/review-package PLAN_FILE MERGE_BASE HEAD` (MERGE_BASE = the commit the
branch started from, e.g. `git merge-base main HEAD`) — take the path from the
`wrote <path>: ...` line and include it in the final review dispatch, so the
final reviewer reads one file instead of re-deriving the branch diff with git
commands. Dispatch
on the most capable available model (see Model Selection), using
hyperpowers:requesting-code-review's
[code-reviewer.md](../requesting-code-review/code-reviewer.md). Point it at
the ledger's deferred-minor lines — and at `tier-skips.md`, if any task
skipped its per-task gate — so it can triage which must be fixed before
merge.

If the final whole-branch review returns findings, dispatch ONE fix subagent
with the complete findings list — not one fixer per finding. Compose the
dispatch from [fix-subagent-prompt.md](fix-subagent-prompt.md).
Per-finding fixers each rebuild context and re-run suites; a real
session's final-review fix wave cost more than all its tasks combined.
Then run exactly one scoped re-review of the fix wave
(`scripts/review-package PLAN_FILE FIX_BASE HEAD` over the fix range,
[re-review-prompt.md](re-review-prompt.md) using its Final-wave usage note).
There is no second fix wave: anything the re-review leaves open — and any
finding that conflicts with the plan's text — goes to your human partner
with the evidence, as BLOCKED, when finishing-a-development-branch presents
the options.

**Dispatch the decision extractor.** When the ledger has a `Decisions listing:`
line (and otherwise nothing), once the fix wave and its re-review are
clean (or the final review returned no findings), take a scratch directory
from `../requesting-code-review/scripts/codex-review-dir`, regenerate the
full-branch package (`scripts/review-package PLAN_FILE MERGE_BASE HEAD`, so a
fix wave's commits are in it) and copy it and `<workspace>/progress.md` into
it, and dispatch the
extractor in the background, composed from
`../finishing-a-development-branch/decision-notes-prompt.md` with those two
copies, the plan, the spec, the `Decisions listing:` from the ledger, the
index (`decisions/README.md` beside the spec's directory) when it exists, and
`<dir>/decision-notes.md` as its output path. Record it in the ledger:
`Decision extractor: <task id> -> <dir>/decision-notes.md`. The dispatch is
complete only when that line is in the ledger: write it before any other tool
call, because after a compaction it is the only record of the task id and the
notes path, and without it a resumed controller can neither collect nor stop
the extractor. The extractor reads nothing inside the workspace, so Finish may
delete the workspace while it runs;
finishing-a-development-branch collects it after the full suite and never
waits for it, and neither do you. On a harness with no tracked background
subagent, skip the dispatch and note it in the ledger. If a Codex final-gate
fix changes code after the dispatch: stop the extractor (TaskStop); when the
fix altered one of the spec's decisions, settle that first (show your human
partner the change you would write into the `## Decisions` item, write and
commit it on the branch with their approval; without it the item stands and
the change is raised again at the menu); re-run the dry run and replace the
ledger's `Decisions listing:`; regenerate the full-branch package and copy
it, with the current `<workspace>/progress.md`, into the scratch directory,
replacing the earlier copies; compose the replacement dispatch from those
copies; then dispatch the extractor again and replace the
`Decision extractor:` line.

**Codex Review Gate — final whole-branch (Claude Code only).** After the final code-reviewer
subagent and its fix wave, and before hyperpowers:finishing-a-development-branch,
run the gate using the final whole-branch code recipe with `--base <branch
merge-base, e.g. git merge-base main HEAD>`. Provide the branch
review-package path, plan or requirements path, the Minor findings ledger if
present, and the tier-skip summary if any task skipped. The final dossier passes the plan's `**Spec:**` file as a `--doc` input beside the plan, and carries the tier-skip summary among its `--adjudications`. Resolve blocking
findings with one fix subagent carrying the complete list, per this
section's existing guidance, before finishing. After any Codex-triggered
final-review fix, re-run the final code-reviewer before re-running the final
Codex gate.

Unlike the per-task gate, the final gate keeps a ceiling of its own: the
gate's convergence stop-rule and per-gate backstop bound this loop (code
gates use a code-gate backstop of 3 rounds). If the backstop is hit with
unresolved blocking findings, surface them to your human partner rather than
looping.

## Finish

When the final whole-branch review is clean and its fixes are merged:

1. **Read your session line** from the ledger (its `mode`), and copy the
   ledger's `Decisions listing:` and `Decision extractor:` lines (or its
   skip reason) into the hand-off message you are about to send: the next
   step removes the ledger from the working tree, and
   hyperpowers:finishing-a-development-branch takes the mode, the plan, the
   spec and the extractor's task id and output path as its input.
2. **Finish the workspace** with `scripts/sdd-state finish PLAN_FILE --session <sid>`:
   it refuses with `open-claims` while any claimed task lacks a completion line
   (that is a plan not finished, not a reason for `--force`), and with
   `busy` (exit 3) when another session is writing the workspace or a copy
   from an interrupted removal sits beside it (report the stderr line, wait
   for the other session or ask your human partner about the copy, then run
   `finish` again); it also refuses with `live-jobs` while a tracked job it
   names is still live (run `tracked-job wait` on it, or `tracked-job stop`
   when the job is no longer wanted, then run `finish` again). `not-holder`
   or `no-final-claim` (exit 11): this session does not hold the final
   train; stop and hand back. Otherwise it
   removes the plan's directory, commits the removal to the state branch,
   and prints `last=<sha>`, the commit that still holds the dossier,
   `push=<remote>/<branch>` and `receipt=<path>`, the durable copy of the
   ledger, the guard's log and the job records; record the receipt path in
   your closing message. A line reading `receipt=none staging=<path>` means
   the record exists only under that staging path: name the path to your
   human partner in the closing message. A space in either path prints as
   `%20`, so decode it before you name the path. On the plain backend it
   prints `backend=plain` instead of `last=` and `push=`, and there is
   nothing to push. `none` means there was no workspace to remove, and
   `error` (exit 2) that the removal or its commit failed: any status other
   than `finished` stops Finish until the command
   succeeds; show its stderr line.
3. **Verify deletion** with `test ! -d "<workspace>"` to confirm it is gone.
   The push command is `git -C <checkout> push <remote> <branch>`, the
   checkout being the parent of the `plans/` directory `sdd-dir` printed;
   run it only if your human partner asks.
4. **Keep the lease through the branch action.** `finish` leaves the branch
   lease in place; hyperpowers:finishing-a-development-branch marks the
   branch closing before a merge and releases the lease after whichever
   option your human partner chose. Hand it the plan path and your session
   id for that. When the final ends with a hand-back instead, detach your
   worktree first (`git switch --detach`) and then release the lease
   yourself, as the last action:
   `scripts/sdd-state lease PLAN_FILE --release --session <sid>`.

A clean finish that leaves the workspace behind is an INCOMPLETE finish —
"keeping it for reference" is not an option; the repo's commits are the
durable record. Sibling directories belong to other plans; leave them
alone. `scripts/sdd-state prune --repo <dir>` is the only other remover, and it
runs only when asked.

Use hyperpowers:finishing-a-development-branch, passing the mode from your
session line. Hand it the plan and the spec, and the extractor's task id
and output path when one was dispatched; when the dispatch was skipped,
hand over the ledger's reason instead and say so, and finishing compiles
without notes; when the plan has no spec, say that, and finishing runs its
test-only path. A decision a Codex-gate fix altered was settled in Final
Review before the re-dispatch.

