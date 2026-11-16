## The Task Loop

Part of [SKILL.md](SKILL.md); the rules there hold in this step.

**Batch small same-shape work.** When the plan lists several tasks that are
each a small, independent edit of the same kind — the same one-line fix,
constant change, or field addition repeated across files — do not dispatch
one subagent per task. Compose ONE dispatch brief listing every file and
its change, send the whole batch to a single subagent, and review its diff
as one unit. Reserve one-dispatch-per-task for work that needs its own
judgment, its own tests, or its own review surface.
A batch's effective risk tier for the per-task Codex gate is the MAX of the
batched tasks' declared tiers — batching low-tier tasks never manufactures
a gate skip.

Everything you paste into a dispatch prompt — and everything a subagent
prints back — stays resident in your context for the rest of the session
and is re-read on every later turn. Hand artifacts over as files.

**Waiting on subagents and long commands.** SKILL.md (Rules for every step) sets the foreground rule; a tracked job runs this way:

- Allocate a tracked job in the foreground with `scripts/tracked-job new PLAN_FILE <name> --budget-ms <budget>` (the watch budget below; the helper writes the `jobdir=` line in the ledger itself), launch `scripts/tracked-job run <jobdir> -- <command>` through the tracked background option with the budget as its timeout, then watch it in the foreground with repeated `scripts/tracked-job wait <jobdir> --max-ms 600000` calls: `exited code=0` is success; any other `exited` code is a failed command, handled as that command's failure (a failed test is a fix round, a failed covering command a failed task); `running` at the bound means another `wait`; on `lost`, run `tracked-job stop <jobdir>` first and read its answer before you go on: only `stopped` or `not-running` means the survivors are swept and the job can be treated as failed (a process in the job's group that carried no fence is left alone and counted as `skipped` in `<jobdir>/meta.json`, and one that outlived the KILL is counted in `survivors`; report a nonzero `survivors` or `skipped`, or a record you cannot read, to your human partner with the jobdir and pgid before you go on, and never call that job stopped); `busy` means the lock was held and nothing was swept, so run `stop` again; `status=error` means the job directory could not be read, so escalate it to your human partner naming the jobdir and leave the job live; `lost-unswept pgid=<n>` means the sweep needs a shell that can list processes and read their identity (the sandbox cannot), so the job stays live to the stop guard until `tracked-job stop <jobdir>` runs where it can: report it to your human partner with its pgid beside the failure, and expect a reused pid to read as `running` until that sweep. When you need a job's output, write the tail of its `out.log` to `<workspace>/reports/job-<name>.txt` and cite the path; output never goes in the ledger. A background shell you start in a turn without `tracked-job` is live work no job record names: end the turn while one is still running and the stop guard refuses that turn end as `live-shell`. Codex reviews already follow this shape through the recipe's `status <job-id> --wait --json` loop.
- **Watch budget.** The total watch on one job is three times the plan's stated runtime for it, or 60 minutes when the plan states none, capped at the harness's maximum background lifetime (7200000 ms on Claude Code). The watch ends when `wait` reports `exited`, `lost` or `lost-unswept`; a supervisor the harness killed writes no exit file, and `wait` reports it as `lost`. When the budget is spent with the job still running, run `tracked-job stop <jobdir>` and read its answer before you end the turn: `stopped` or `not-running` means the job is over, so write the `out.log` tail to `<workspace>/reports/job-<name>.txt` and report BLOCKED naming that path (a nonzero `survivors` or `skipped` in `<jobdir>/meta.json`, or a record you cannot read, is reported the same way, with the jobdir and pgid, and that job is never called stopped); `busy` means the workspace lock was held and nothing changed, so run `stop` again; `stop-timeout` means the supervisor has not concluded the job, so run `stop` again, three calls in all, and escalate a third one to your human partner as a job still live, naming the jobdir; `status=error` means the job directory could not be read, so escalate it the same way, naming the jobdir; `lost-unswept pgid=<n>` leaves the job live, so report it to your human partner as still live with its pgid, never as stopped.

On a harness whose subagents run asynchronously, never poll a wait interface with short timeouts, and never sit in one silent, open-ended wait either. While you have local work — ledger updates, packaging the next review, reading reports — keep working; child results arrive on their own. When you are genuinely idle, wait in bounded stretches (five to ten minutes, where your platform allows), and between stretches post one line of status and reconcile your live children: list them, and chase any that finished without reporting. A bounded stretch keeps nearly all of a long wait's efficiency while guaranteeing a stuck or lost child is noticed within minutes, not at the end of the session. Codex's `wait_agent` blocks inside the turn; `using-hyperpowers/references/codex-tools.md` maps it.

### 1. Dispatch the implementer

Record BASE right after `git switch <branch>` and before dispatching, as the
task branch's fork point from the integration branch:
`git merge-base HEAD refs/heads/<integration branch>` (the full ref name, so
a tag with the branch's name cannot be read instead). On a fresh claim that
is the claim's `from=` commit. On a takeover it is the original claim's base,
or, once the conflict route has merged the integration branch into the task
branch, the integration head merged in; the previous holder's commits stay in
the review package and the fix-round diffs either way, which both need BASE.
A HEAD read before the claim can lag the integration branch while other
sessions merge.

- **Task brief:** before dispatching an implementer, run this skill's
  `scripts/task-brief PLAN_FILE N` — it extracts the task's full text to a
  uniquely named file and prints `wrote <path>: <N> lines`. Take the path
  from that line; do not paste the line itself into a dispatch. Compose the
  dispatch so the
  brief stays the single source of
  requirements. Your dispatch should contain: (1) one line on where this
  task fits in the project; (2) the brief path, introduced as "read this
  first — it is your requirements, with the exact values to use verbatim";
  (3) interfaces and decisions from earlier tasks that the brief cannot
  know; (4) your resolution of any ambiguity you noticed in the brief;
  (5) the report-file path and report contract. Exact values (numbers,
  magic strings, signatures, test cases) appear only in the brief. Never
  make a subagent read the whole plan file.
- **Report file:** name the implementer's report file after the brief
  (brief `…/task-N-brief.md` → report `…/task-N-report.md`) and put it in
  the dispatch prompt. The implementer writes the full report there and
  returns only status, commits, a one-line test summary, and concerns.
- A dispatch prompt describes one task, not the session's history. Do not
  paste accumulated prior-task summaries ("state after Tasks 1-3") into
  later dispatches — a real session's dispatch hit 42k chars of which 99%
  was pasted history. A fresh subagent needs its task, the interfaces it
  touches, and the global constraints. Nothing else.
- The dispatch carries the no-subagents contract (it is in the
  implementer template): the implementer never dispatches subagents —
  not helpers, and never a reviewer. Review arrives from you, after the
  report. In real sessions, every reviewer a worker spawned duplicated
  the task review the controller dispatched anyway — a full extra
  review seat per task.
- Subagents follow hyperpowers:test-driven-development for the task's tests.
- If an earlier task deferred a finding in the area this task touches — a
  Minor in the ledger, or one your human partner decided — carry a pointer
  to that ledger entry in the dispatch.
- Ask what to take: `scripts/sdd-state next PLAN_FILE --session <sid>`.
  `status=next tasks=<list>` names the claimable tasks in plan order, this
  session's own claims first; claim the first:
  `scripts/sdd-state claim PLAN_FILE N --session <sid>`. `claimed` prints the
  task branch and its base: check the branch out (`git switch <branch>`) and
  dispatch on it; `held` with your own session id (`own=1`, a resume after
  compaction) prints the same two fields: check the branch out and proceed,
  unless the task's newest ledger line is its implementer identity, which
  is a dispatch in flight: do not re-dispatch — reconcile that agent first
  (list your live children, chase its report); on a harness without
  `run_in_background` (Claude Code's fork mode among them) resume it by
  the recorded id; only if it cannot be recovered dispatch a takeover,
  recording the takeover's identity beside the original. A newest `report` line means the implementer has finished:
  dispatch nothing, and resume at "2. Handle the report" from the report
  file and the recorded `report` line, with BASE as step 1 sets it.
  `held` with `own=1` and `merged=1` means the task is already merged and its
  branch deleted: check nothing out and resume it at its completion line
  (Complete the task, in [review-and-complete.md](review-and-complete.md)); `claimed` with `takeover=1` and `merged=1`
  means the same after a takeover: the task is already merged, so check
  nothing out, dispatch nothing, and resume it at its completion line (the
  previous holder's task branch may still exist; you do not need it);
  `held` from `claim` after `next` offered the task is a race lost, run
  `next` again; `blocked` means the plan moved under you, run `next` again.
  A task held by another session is ordinary while next offers another: take
  what it offers. When `next` prints `status=none reason=<reason>`:
  `complete` goes to the final train (Finish, in [final-and-finish.md](final-and-finish.md)); `assigned-complete` is
  reported and the session hands back; `held` and `blocked` mean post a
  waiting record (`scripts/sdd-state wait PLAN_FILE --session <sid> --kind
  tasks --note "<the held= and waiting= fields>"`), print
  `scripts/sdd-state board PLAN_FILE`, and hand back with the board's session
  lines in your message. Take a held task over only on your human partner's
  explicit yes to a question that names the holder and the time since
  (`--takeover`), recording the takeover beside the original identity;
  `own-blocked` means an amendment put a prerequisite under your own claim:
  post, print the board, hand back, and let your human partner remove the
  edge or let the prerequisite complete. `done`, `no-workspace` and `error`
  keep their handling: `done`: another session completed the task since you
  read the ledger; read its completion line, mark the task done, and never
  dispatch it. `no-workspace` (exit 2): the workspace is gone (finished or
  pruned elsewhere); stop, run `sync`, and re-read the ledger before
  anything else. `error` (exit 2, the same exit as `no-workspace` and a
  different problem): a read or a write failed, and the claim may already
  have been published; only your own retry of the same claim (which then
  answers `held own=1`) or a takeover clears it. Stop, show the stderr line,
  and retry the same claim once its cause is fixed; `sync` is still not the
  answer. Any other status stops the dispatch until `claim` succeeds; show
  its stderr line.
- Record the implementer's agent identity from the dispatch result in the
  ledger's task entry
  (`Task <N>: implementer <agent-id-or-name> (model <model>, session <sid>, worktree <path>, branch <name>)`) —
  fix-loop rounds 1-3 resume this agent where the harness has no foreground
  dispatch and dispatch on its recorded model where it does, and after compaction the ledger is
  the only place the identity survives once its agent has exited. An
  identity that was never written down forces a fresh takeover where a
  resume was owed.
- When another session may be live on this plan, append ledger lines with a
  quoted heredoc (`cat >> <workspace>/progress.md <<'EOF'`), never with the
  Edit tool, whose read-modify-write drops a line another session appended
  in between.
- Where the Agent tool offers `run_in_background`, dispatch with it false; where it does not (fork mode in an interactive terminal), dispatches run in the background and the stop guard treats them as live work.

Template: [implementer-prompt.md](implementer-prompt.md)

### 2. Handle the report

Append `Task <N>: report <status> <one line>` to the ledger when the report arrives, before acting on it.

**Subagent Reports Are Claims.** Subagent reports are claims, not
evidence. Before acting on any completed-status report (DONE or DONE_WITH_CONCERNS) or a fix report —
dispatching the reviewer, re-running a gate, marking a task complete — the
controller re-runs the named covering test command directly and compares
the output against the report. A misreported result is a failed task:
re-dispatch with the discrepancy named, not a bookkeeping correction.

Every implementer and fix dispatch names either its covering test
command(s) or an explicit `no covering command: <rationale>` line plus the
controller's substitute verification (read the diff against the brief;
render or grep the changed doc). A dispatch naming neither is malformed —
fix the dispatch, not the rule.

A covering command must be able to fail. One that can no-op on the state
under test — a changed-files linter on a clean tree, a test filter that
matches nothing — is not covering evidence, however honestly it exits 0.
Name the files or the test ids explicitly so the command exercises what
the report claims.

Implementer subagents report one of four statuses. Handle each appropriately:

**DONE:** Generate the review package (`scripts/review-package PLAN_FILE BASE HEAD`, from this skill's directory — it prints `wrote <path>: <N> commit(s), <N> bytes`, so take the path from that line; BASE is the commit you recorded before dispatching the implementer — never `HEAD~1`, which silently drops all but the last commit of a multi-commit task). If `review-package` exits non-zero, read its stderr and fix the range before dispatching — exit 2 means bad inputs (wrong argument count, a missing plan file, a ref that does not resolve) or an ancestry check git itself could not answer (a missing or corrupt object); exit 3 means BASE..HEAD is empty or HEAD is not a descendant of BASE, usually a wrong-branch commit; never dispatch a reviewer without a package. Otherwise, dispatch the task reviewer with the path: step 3, in [review-and-complete.md](review-and-complete.md).

**DONE_WITH_CONCERNS:** The implementer completed the work but flagged doubts. Read the concerns before proceeding. If the concerns are about correctness or scope, address them before review. If they're observations (e.g., "this file is getting large"), note them and proceed to review.

**NEEDS_CONTEXT:** The implementer needs information that wasn't provided. Provide the missing context and re-dispatch.

**BLOCKED:** The implementer cannot complete the task. Assess the blocker:
1. If it's a context problem, provide more context and re-dispatch with the same model
2. If the task requires more reasoning, re-dispatch with a more capable model
3. If the task is too large, break it into smaller pieces
4. If the plan itself is wrong, stop and escalate to your human partner — the plan text, what it breaks, and the correction you would make

**Never** ignore an escalation or force the same model to retry without changes. If the implementer said it's stuck, something needs to change.

If the implementer asks questions — before starting or mid-task — answer
clearly and completely, provide additional context if needed, and don't
rush it into implementation.

