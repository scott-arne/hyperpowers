## Setup

Part of [SKILL.md](SKILL.md); the rules there hold in this step.

Read before you settle: run the `sync` and `sdd-dir` steps below and read
the ledger's plan line, if the ledger exists (reading it changes nothing).
Then settle where the work happens: use hyperpowers:using-git-worktrees,
which detects an existing worktree or asks your human partner to choose
between staying on the current branch, a new branch in place, and a
worktree, and reports the mode. When the plan line names an integration
branch, this is a later session of a running plan: hand using-git-worktrees
that branch and your session id. Never start implementation on a main/master
branch unless your human partner chose "stay on the current branch" in that
question; that answer is the consent, and the dossier no longer depends on
the branch.

Track progress in a ledger file, not only in todos: in real sessions,
controllers that lost their place have re-dispatched entire completed task
sequences, the single most expensive failure observed.

- Each plan owns a workspace: at skill start, run `scripts/sdd-state sync PLAN_FILE`
  (it fetches the repository's state branch; outcomes below), then this
  skill's `scripts/sdd-dir PLAN_FILE` — it prints the plan's workspace
  inside the repository's state checkout under the user cache
  (`${XDG_CACHE_HOME:-~/.cache}/hyperpowers/state/<key>/plans/<plan-slug>-<hash8>/`,
  one checkout per clone, shared by every worktree of it), home to every
  artifact for THIS plan: ledger, briefs, reports, review packages, claims,
  tier-skip summary. The ledger, reports, notes and claims are committed to
  the orphan branch `hyperpowers/state` by `scripts/sdd-state snapshot PLAN_FILE`
  and travel between hosts with that branch; briefs and review packages are
  ignored there and regenerate. The cache is off any protected path, so
  writing there never triggers a permission prompt, and it is outside the
  working tree, so it can never be committed with the code. Another plan's
  directory is never yours to read or write. When `sdd-dir` reports
  `backend=plain` on stderr, the state branch is unavailable on this host
  and the dossier will not travel from it: tell your human partner once and
  continue.
- `sdd-state sync` outcomes: `up-to-date`, `fast-forwarded`, `merged`,
  `ahead`, `created`, `absent`, `no-remote`, `assumed-absent`, `plain`:
  continue. `offline` (exit 1): continue on the local checkout and, as soon
  as the ledger exists (the next bullet), append
  `state: sync offline at <time>` to it. `offline-no-state` (exit 1), or
  `needs-sync` from `sdd-dir`: stop; this host has no dossier and cannot
  learn whether the remote holds one. Ask your human partner to get online,
  or to confirm `scripts/sdd-state sync --assume-absent PLAN_FILE` when they
  know no remote dossier exists. `diverged` (exit 3): stop and present both
  tips and the printed `merge=` command as a question in the Deciding
  Together shape; never merge on your own. `busy` (exit 3): retry `sync`
  once after the other session's writes settle, then ask.
  `foreign` (exit 2): the branch at the state name is not a hyperpowers
  state branch; stop, relay the stderr remedy (set git config
  `hyperpowers.stateBranch` to another name), and ask.
  `remote-finished plans=<ws,...>` (exit 3): another host finished a plan
  whose workspace on this host holds ledger lines that are not on the
  branch. When the list names this plan's workspace, stop, show your human
  partner the lines this host added (the ledger's tail beyond the last
  snapshot), and ask whether to snapshot them (then `sync` again, which
  reports `diverged` for their merge) or to discard them. A workspace in
  the list that is not this plan's belongs to another plan: report its
  name and stop without reading or changing it.
  Any other status, `status=error` (exit 2) among them, stops the run until
  `sync` succeeds; show its stderr line.
- Check for this plan's ledger at `<workspace>/progress.md` — this plan's
  workspace only, never a sibling's. The workspace is the plan's identity:
  `scripts/sdd-dir` maps a plan to ONE directory whatever path form you
  hand it, so a ledger sitting in YOUR workspace is this plan's progress
  even when its first line records the path in another form. Compare
  repo-relative paths: reduce the plan you were handed to its path relative
  to the plan repository's toplevel; a line holding an absolute path matches
  when it lies inside this repository and reduces to the same relative path,
  or, when it names a path that does not exist on this host (a ledger
  written on another machine), when it ends with that relative path. Tasks
  with a `Task <N>: complete` line are done (SKILL.md, Rules for every
  step); resume at the first task without one. A
  task whose last line is a fix round is mid-loop: resume the loop at the
  next round. A task whose last line is its implementer identity is a
  dispatch in flight: do not re-dispatch — reconcile that agent first
  (list your live children, chase its report), resume it by the recorded
  id where your harness allows, and only if it cannot be recovered
  dispatch a takeover, recording the takeover's identity beside the
  original. The scan only reads: every action it calls for (a resume, a
  takeover, the next task) waits until `verify` below has returned `ok`.
  A first line that resolves to a genuinely different plan
  file means this workspace is corrupt, not that you wandered into a
  sibling's: stop and surface it to your human partner rather than
  starting fresh on top of another plan's state.
- When there is no ledger, create it with its identity as the first line,
  `# SDD ledger — plan: <repo-relative plan path>` (never an absolute path:
  the ledger travels between hosts), through a no-clobber write so two
  sessions that both saw no ledger cannot overwrite each other:
  `( set -o noclobber; printf '# SDD ledger — plan: %s\n' <repo-relative plan path> > <workspace>/progress.md )`.
  When that write fails because the file now exists, another session
  created it first: continue as if you had found it. Whether you created
  it or found one, append your session line (with `>>`, never a rewrite):
  `session <sid>: mode <current-branch|new-branch|worktree> on <task branch or detached> integrating <integration branch> at <toplevel> started <UTC time>`,
  where `<sid>` is `$CLAUDE_CODE_SESSION_ID` on Claude Code and, on a harness
  without one, a value you generate once as `$(date -u +%s)-$RANDOM$RANDOM`,
  and the mode is what using-git-worktrees reported. Append a fresh session
  line whenever you move to a new task branch or detach; your newest line is
  your location. When your human partner assigned this session specific
  tasks, add `session <sid>: tasks <N,M,...>`. Then, once registered (the
  next bullet), run `scripts/sdd-state verify PLAN_FILE` (on a found ledger
  this is the check that this host holds the code it relies on): `ok` continues;
  anything else stops Setup until `verify` passes again. `code-missing`
  names commits the ledger relies on that this checkout lacks, so ask your
  human partner to pull the named branch; `wrong-repo` names the repository
  the ledger was handed off from, so ask which checkout this work belongs
  in; `plan-stale` names the plan repository branch to pull, and you read
  the plan again after that pull.
- Register the plan before anything else is claimed:
  `scripts/sdd-state register PLAN_FILE --session <sid> --integration <branch>`,
  where `<branch>` is the branch the branch choice produced (the plan's
  integration branch; later sessions read it from the ledger's plan line and
  pass the same). `registered` continues; `wrong-branch` means this plan is
  already running on another integration branch: switch to it or ask;
  `spec-branch-mismatch` means a sibling plan of this spec runs on another
  branch: use that branch; `branch-closing` means the plan's branch is being
  merged and deleted: wait for your human partner; `detached-head` (exit 11)
  means a first registration found the repository the line names on a
  detached HEAD, as a host-managed workspace can be, and the plan ref is
  named after a branch: ask your human partner for the branch to create
  (the integration branch itself when plan and code share one repository),
  create it in place with `git -C <the repository the line names> switch -c <name>`,
  and register again. Any other status stops Setup until `register`
  succeeds; show its stderr line. A later session of a
  running plan starts its worktree detached at the integration head
  (using-git-worktrees says how) and never checks the integration branch
  out; a later session (the ledger already has a plan line naming the
  integration branch) that is not already detached at that branch's head
  runs `git switch --detach <branch>` before `register`, whatever mode
  using-git-worktrees reported (an existing worktree, a native tool's
  worktree, or work in place); a worktree that skill created detached is
  already there. Before that detach, and before any claim, a later session
  compares `git rev-parse --show-toplevel` with the `at <toplevel>` of every
  other session's newest session line: a match means you are inside another
  session's worktree (a native tool can resume one under the same name), so
  do not detach, switch or claim there. Leave it, create your own worktree
  with a name that carries your session id (using-git-worktrees, Detaching a
  later session), append a fresh session line from it, and detach that one.
  When the plan file lives in another repository
  than the code, pass `--code-repo <code toplevel>` to every `sdd-state`
  call; an omitted option means the current repository, and a wrong one is
  `wrong-repo`.
- Quote the graph in the ledger: run `scripts/sdd-state deps PLAN_FILE` and
  append its lines after the scan table. The scan's conflict rows include
  `scripts/sdd-state deps --check PLAN_FILE --ledger <workspace>/progress.md`'s
  lines: each `conflict tasks=A,B ...` is a row for your human partner, settled
  by an amendment (`scripts/sdd-state amend PLAN_FILE --from <edited copy>
  --base <plan= blob> --message <subject>`, with `--accept 'tasks=A,B path=<p>'`
  when they accept the overlap; the edited copy is a file outside the
  checkout's plan path, a copy in the plan's workspace, never the checked-out
  plan file itself, which `amend` refuses) and never by editing the plan in
  the worktree alone, because the plan ref is what every session reads.
- The ledger is your recovery map: the commits it names exist in git even
  when your context no longer remembers creating them.
- The workspace is scratch for the working tree and a record on the branch:
  the Finish step removes the plan's directory through
  `scripts/sdd-state finish PLAN_FILE --session <sid>`, and the branch history keeps it, so
  an evidence note can cite `git show <sha>:plans/<ws>/<file>`. Nothing
  inside the checkout is reclaimed automatically; `scripts/sdd-state prune --repo <dir>`
  lists and removes idle plan directories only when asked. Snapshot the
  workspace (`scripts/sdd-state snapshot PLAN_FILE`) after the pre-flight
  scan table and before the final review; `scripts/sdd-state complete`
  snapshots after every completion line it writes, so a hand-off or a crash
  loses at most the task in flight. The completion's durable record is the
  snapshot `complete` takes, so that helper's status line decides whether
  you go on: `status=complete` continues, `busy` and `error` are retried,
  and every other status stops. A snapshot you run by hand answers
  `snapshot` (or `plain`, where no state branch exists), which continues;
  `none` means what you just wrote is not in the workspace the helper sees,
  and `error` (exit 2) means the commit or the ref update failed; both stop
  until the snapshot succeeds.
  When your human partner asks to
  hand the run to another host, run `scripts/sdd-state handoff PLAN_FILE --push`
  (the only time the state branch is pushed, never on your own initiative),
  report its status line, relay `plan-not-committed` with the commands to
  commit the plan, relay `code-dirty` with the listed paths as a question
  (only an explicit yes passes `--code-dirty-ok`), relay `detached-head`
  by asking for a branch name and creating it in the repository the line
  names (`repo=code` or `repo=plan`: `git -C <that repository> switch -c <name>`)
  before retrying, relay `shallow-source` (exit 12) the same way (a full
  clone, or `git -C <that repository> fetch --unshallow`, since a shallow
  code or plan repository cannot record a root), and stop on `plain`
  (exit 7: this host has no state branch, so there is no dossier to push),
  `scan-failed` (exit 5: the pre-push scan named in `hyperpowers.prePushScan`
  rejected the range; show its output and ask) and `push-failed` (exit 1:
  the remote moved or could not be reached; run `sync` first, then retry):
  none of them is a hand-off, so report nothing as ready to pull.
  `snapshot ... push=none` (exit 0) is no hand-off either: the plan
  repository has no remote, so the record is committed on this host and
  nothing left it; report it as a local snapshot and ask your human partner
  for a remote if the dossier has to travel. On
  `pushed`, list the branches named in `code=` and, when present, `plan=`
  for your human partner to push here and pull there. You push none of
  them unless asked.

Read the plan once, note its context and Global Constraints, and create a
todo per task where your harness surfaces todos — the ledger is the
progress record either way; todos mirror it, never replace it. Read the
plan's `**Spec:**` header and the spec file it names: the spec is the
binding authority the plan argues from, and conflicts inside the plan
resolve against it. A plan whose spec is `none` or unreachable gets a
ledger line saying so — without a spec, a conflict has no tiebreaker but
your human partner.

When the plan has a spec, dry-run the decision compiler over it now:
`bash <finishing skill's directory>/scripts/decisions-compile <spec> --dry-run`
(the finishing-a-development-branch skill, `../finishing-a-development-branch/`
relative to this one). Exit 0 confirms the spec's `## Decisions` list parses;
its numbered listing goes into the ledger under a `Decisions listing:` line
for the extractor's dispatch. Exit 2 for a missing list is the legacy-spec
case: draft the list from the spec's own text, one item per decision it
states, show it to your human partner, and write it into the spec once they
approve it, committing that edit on the branch. Any other exit 2 names what
to fix first (a spec that is not committed, or a `Supersedes:` problem) to
resolve with them the same way. After any repair, run the dry run again
until it exits 0, and only then write its numbered listing into the ledger.
The session is at its start, so this costs no cycle time. When the plan has
no spec (`none`, or unreachable, per the ledger line above), write
`Decisions: none (no spec)` in the ledger and skip the listing, the
extractor and the spec in the hand-off: finishing then takes its test-only
path.

Before dispatching Task 1, scan the plan once for conflicts, writing down
what you checked as you check it:

- tasks that contradict each other or the plan's Global Constraints
- anything the plan explicitly mandates that the review rubric treats as a
  defect (a test that asserts nothing, verbatim duplication of a logic block)

The scan's output is a table, not a verdict. One row for every pair of tasks
that share a file or an interface: the two tasks, what one produces against
what the other consumes, and what you found. One row for every task: whether
its own text agrees with itself — the tests it specifies against the code it
specifies, the files it creates against the files it later touches. "The scan
is clean" without those rows is not a scan you ran.

Write the table to the ledger. Then present everything it surfaced to your
human partner as ONE batched question — each finding beside the plan text
that mandates it, asking which governs — before execution begins, not one
interrupt per discovery mid-plan. Each finding is a decision with
consequences downstream, so it gets the shape the brainstorming skill's
Deciding Together section describes: the conflict and what each resolution
costs in chat, then the selection widget to collect the answers. If the scan
is clean, proceed without comment. The review loop remains the net for
conflicts that only emerge from implementation.

Setup's last action: append `session <sid>: setup complete` to the ledger (a
later session writes its own). The step table in SKILL.md reads it to tell a
compaction during Setup from one after it.
