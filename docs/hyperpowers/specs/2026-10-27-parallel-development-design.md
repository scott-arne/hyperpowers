# Parallel development on the same machine: dependency-aware claims, merge-back and a waiting board

**Date:** 2026-10-27
**Status:** design approved in chat on 2026-10-27 (seven clarifying answers,
the approach, six design sections); spec self-reviewed; Codex spec gate
rounds 1 to 4 raised two, one, one and zero critical and sixteen, eight,
seven and three high findings; every one is resolved in this revision and
the gate's round ledger records each; the three from round 4, the gate's
last, were resolved after the ceiling without a confirming Codex pass;
user review pending.
**Precondition:** portable SDD dossiers (`2026-10-20-portable-sdd-dossiers-design.md`),
merged to `main` as 5abc925 on 2026-10-27. This design extends that helper
and that skill text; where it names a mechanism without describing it, the
dossier spec is the description.

## Problem

BACKLOG.md asks, under "Parallel development on the same machine", for two
things and a third that follows from them: working on several tasks of one
plan at once when they do not block each other; working on two slices,
which this design defines as two plans under one spec, at once when they do
not block each other; and switching between those parallel pieces of work
to brainstorm, answer questions, or grant permissions.

The dossier design laid the ground and stopped short on purpose. Its second
decision chose one controller session per parallel task as the model to
serve first, each session in its own worktree, with a single controller
fanning out implementers deferred. It delivered the shared ledger on a state
branch, per-task claims with a session id and an atomic publish, a
per-session assigned task list, and a skill rule that a task `held` by
another session means ask, never skip ahead, because "which tasks may run
concurrently is not yet decided".

So today two sessions on one plan can coexist, but neither knows which task
it may take while the other works, their commits have no agreed way to
meet before the whole-branch review, nothing tells you which session is
waiting on you and for what, a second plan under a spec the first plan
already finished meets a frozen spec and a branch the first finish wants
to delete, and two sessions that both reach the end can both run Finish.
This design closes those five gaps with the model decision 2 chose.

## Decisions

- Multi-session first. The unit of parallelism is a Claude session in its
  own worktree, claiming tasks from the shared dossier; a single controller
  fanning out implementers stays deferred, and the dependency statement
  this design adds is written so a later fan-out controller reads it
  unchanged. Decided 2026-10-27 in chat.
- The plan declares task independence and the scan validates it. Every task
  carries a `**Depends on:**` line; the controller's pre-flight scan checks
  declared independence against file and interface overlap and reports a
  contradiction as a plan conflict; the per-session assigned task list
  remains as an override that narrows selection and never bypasses a
  dependency. Rejected: deriving independence from overlap alone (serializes
  most plans and leaves no shared record); the assigned list alone (nothing
  warns when two lists collide). Decided 2026-10-27 in chat.
- One integration branch per plan, merged back per task. Each session
  works on a short task branch off the plan's branch and merges back right
  after the task's gate approves, under the dossier lock, with the merge
  recorded in the ledger; the whole-branch review runs on the one branch.
  Rejected: per-session branches merged once at the end (late conflicts, a
  final review over an unreviewed merge); one shared branch with turns
  under the lock (every commit a critical section). Decided 2026-10-27 in
  chat.
- Switching is served by a waiting board, not a relay. Per-session waiting
  records in the dossier, a subcommand that prints them from any shell or
  session, and skill text that posts and hands back when blocked. A
  cross-session question relay is a follow-up once the board shows what
  blocks sessions; a permission prompt is answerable only in the session
  that raised it. Decided 2026-10-27 in chat.
- The board infers a permission prompt; it does not record one. A prompt
  blocks the very tool call a session would use to post, so the board marks
  a session that holds a claim with no activity for thirty minutes `quiet`
  and names no cause; the clarifying answer that listed a permission among
  the waiting kinds is superseded by this, approved with design section 4,
  and a hook that records a pending tool call is the follow-up that would
  name one. Decided 2026-10-27 in chat.
- A slice is a separate plan under one spec. Each slice is its own plan
  file and workspace run by its own session; plans that share a spec and a
  branch are handled explicitly, including the spec's Outcome line at
  finish and the branch's teardown; no inter-plan dependency field is added
  in this design. Decided 2026-10-27 in chat.
- A held task is ordinary while a frontier remains; an empty frontier is
  the ask. A session that finds a task held by another session takes the
  next claimable task; only when nothing is claimable does it post to the
  board and hand back, and it takes a held task over only on your human
  partner's explicit yes. This refines the dossier skill's "held means ask"
  and supersedes the clarifying answer's shorter wording; approved with
  design section 2. Decided 2026-10-27 in chat.
- The final train is claimed, and whoever finishes last takes it. The
  final whole-branch review, the final Codex gate and Finish run in the
  session that claims `final`, which succeeds only when every task is
  complete and no claim is open; `finish` refuses any other caller. A
  branch-scoped lease taken by the same command serializes the finals of
  plans that share an integration branch. Rejected: a designated finishing
  session; finishing on instruction alone. Decided 2026-10-27 in chat.
- Evidence is fixtures, one live run and one scenario. Deterministic
  two-session fixtures in the state suite for every mechanism, one real
  two-terminal run on a small plan recorded in the evals repository, and
  one hyperpowers-evals scenario with two cases for the skill-text
  behaviour. Decided 2026-10-27 in chat.
- The approach is a materialized dependency graph with atomic claims. Run
  state stays in files the dossier already reads (the ledger, claim
  directories, per-session records) rather than an event log with
  projections or a compiled per-run manifest with merge tickets; the
  Codex approach gate converged on this independently. One detail of the
  manifest approach is kept: merge-back merges exactly the approved
  commit, validated against the current integration head. Decided
  2026-10-27 in chat.
- The authoritative plan is the blob at the plan ref's head in the plan
  repository. Every reader of the dependency graph reads it there, never
  from a worktree's copy, and amendments reach that head through one
  subcommand that validates the whole graph and its overlaps and then
  commits the plan change alone under the lock. When the plan and code
  repositories are one, the plan ref is the integration branch. Decided
  2026-10-27 at the spec gate.
- Liveness is not judged by the tooling. A short-lived helper has no
  process whose lifetime matches a controller session, so owner records
  carry no pid, the board shows how long a holder has been silent, and
  every takeover is your human partner's decision on that evidence.
  Decided 2026-10-27 at the spec gate, superseding a round-2 resolution
  that proposed a pid rule.
- Registration is one locked operation. A session's first act on a plan
  registers the plan line through a subcommand that, under the locks,
  checks the plan's siblings and the branch's lease and writes the line,
  so two Setups cannot both pass a check and write conflicting lines.
  Decided 2026-10-27 at the spec gate.

## Design

### 0. Names and identities used below

- `<integration>`: the plan's integration branch, the feature branch Setup
  chooses today.
- `<ws8>`: the first eight hex characters of the plan workspace's hash,
  the suffix `sdd-dir` already puts in the workspace name
  (`<plan-slug>-<ws8>`).
- `<code-root>`: the full sha of the code repository's root commit, which
  `verify` already records for `handoff: code`; it names the repository
  that owns the integration branch when the plan lives elsewhere.
- Task branch: `<integration>.<ws8>.task-<N>`, and after a takeover
  `<integration>.<ws8>.task-<N>.<k>` with `k` counting from 2. The dot
  separators keep the names flat beside `<integration>` (a branch named
  `<integration>/x` cannot coexist with `<integration>`).
- `<plan-ref>`: the branch of the plan repository that carries the plan
  file, read at Setup from the plan repository's checkout; when the plan
  and code repositories are the same it is `<integration>`. The plan line
  records it with the plan repository's root commit, and `amend` is its
  only writer while the plan is open.
- The plan line: the ledger's `plan: integration <integration> code-root
  <code-root sha7> plan-ref <plan-ref> plan-root <plan root sha7> spec
  <relative spec path>`, written once by the first session (section 3).
- The lease key: `<key>.final-<ref12>` where `<ref12>` is the first twelve
  hex characters of the SHA-1 of the full ref name `refs/heads/<integration>`
  (computed with `git hash-object --stdin`, as `hp_key` computes keys), so a
  branch named `feature/foo` makes a file beside the lock and not a path; the
  record inside holds the branch name in clear.
- Session id `<sid>`: the id Setup establishes today.
- The authoritative plan: the blob of the plan file at the head of
  `<plan-ref>` in the plan repository, `git -C <plan repo> show
  <plan-ref>:<plan path>`, identified in outputs as `plan=<blob sha7>`;
  claims and merge-back read the code repository's integration ref, the
  graph readers read the plan repository's plan ref, and the two are the
  same ref when the repositories are one.
- Owner records (task claims, the final claim, the lease) carry `host=`
  beside `session=` and `time=`, for information. No record carries a
  pid and no subcommand judges a holder dead: the board shows the holder,
  its host and how long its activity file has been silent, and a takeover
  is your human partner's decision on that evidence.
- Lock order. A subcommand that must hold the plan repository's lock and
  the code repository's lock takes them through one helper that sorts the
  two by repository key (`hp_key`, a hash, so the order is total and the
  same in every process) and acquires them in that order, whichever role
  each repository plays; a fixture runs two operations with the roles
  swapped through a barrier.
- The lease and every claim live in the plan repository's state root,
  beside that repository's lock file, because the dossier does. The lease
  record's identity is the triple it holds, `plan=<ws>`, `session=<sid>`,
  `branch=<integration>`, under the file named by the lease key. Every
  lease operation takes `PLAN_FILE --session SID [--code-repo DIR]` and
  finds its lease by that identity: the workspace name `<ws>` comes from
  the plan file's path and repository the way `sdd-dir` derives it, with
  or without a workspace on disk, and the operation reads every
  `<key>.final-*` file in the state root and selects the one whose record
  names this `<ws>` and this session. Exactly one is the normal case;
  none is `status=no-lease` (exit 0 for `--release`, so a release after a
  crash that never took the lease is quiet; exit 4 for `--closing`); more
  than one is `status=error` naming the files, a state nothing in this
  design produces. No lease operation takes a branch argument.
- `--code-repo DIR`: the argument `verify` already takes; every subcommand
  below that touches a code ref takes it the same way, defaults it to the
  plan repository, and refuses with `status=wrong-repo expected=<code-root
  sha7>` (exit 9, as `verify` does) when the directory's root commit is not
  the recorded one. Such a subcommand takes the plan repository's lock, and
  the code repository's lock as well when the two differ.

### 1. The dependency line and the scan

**The line.** Directly under a task's `**Risk tier:**` line, writing-plans
writes `**Depends on:** none` or `**Depends on:** Task 1, Task 3`. It means
exactly this: each named task's completion line (`Task <N>: complete`) must
exist in the ledger before this task may be claimed. It says nothing about
files; overlap is checked separately. A plan in which every task has the
line is a dependency plan. A plan in which no task has the line predates
this design and is read as fully serial: task N depends on every task
before it, so existing plans run exactly as they do today. A plan in which
some tasks have the line and some do not is a parse error (below); the
writing-plans placeholder scan reports a missing line beside a missing risk
tier.

**The parser.** `sdd-state deps PLAN_FILE [--code-repo DIR]` reads the
authoritative plan and prints `plan=<blob sha7>` followed by one line per
task, `task=<N> depends=<comma list or none>`, in heading order, the serial
default applied for a legacy plan. It exits 2 with one stderr line naming
the problem for: a cycle (`cycle: 3 -> 5 -> 3`), a dependency on a task
that does not exist, a task that depends on itself, a duplicated heading
number, or mixed annotation (`tasks without a Depends on line: 4, 7`).
`claim`, `next` and `merge-back` call it; the controller runs it once at
Setup and quotes its output in the ledger beside the scan table. A later
single-controller fan-out reads the same lines.

**The overlap check.** `sdd-state deps --check PLAN_FILE [--ledger FILE]`
reads the same plan and, for every pair of tasks, the `Create:`, `Modify:`
and `Test:` paths of their Files blocks and the names in their `Produces:`
and `Consumes:` lines. It prints one line per undeclared overlap: `conflict
tasks=3,5 shares=<path>` when the two share a path and neither depends on
the other directly or through a chain; `conflict tasks=3,5 interface=<name>
direction=consumer-first` when task 5 consumes what task 3 produces and 5
does not depend on 3 (a consumer must follow its producer; the reverse
dependency does not satisfy it). Paths listed under **Merge-expected
files** in the plan's Global Constraints (the CHANGELOG and `docs/testing.md`
in this repository) never produce a conflict line. With `--ledger`, a pair
the ledger records as accepted is suppressed. It exits 0 with no output
when the plan has no undeclared overlap, 1 when it printed any, 2 on a
parse error.

**The scan.** The pre-flight scan keeps its pair table and adds the graph
(`deps` exits 0) and the overlap check. Each conflict line becomes a row
(`Tasks 3 and 5 declared independent, both modify
tests/sdd/test-sdd-state.sh`) in the batched question the scan already
asks, and each is settled one of two ways: the plan is amended to add the
dependency (through `amend`, below), or the overlap is accepted and the
controller appends the parseable line `scan: accepted-overlap tasks=3,5
path=<path>` (or `interface=<name>`) to the ledger, which later checks
read through `--ledger`.

**Amendments.** `sdd-state amend PLAN_FILE --from <edited copy> --base
<blob sha> [--code-repo DIR] [--message <subject>]` commits the plan
change alone on top of the plan ref's head. `--base` is the authoritative
blob the edited copy was taken from (the `plan=` value the controller read
before editing). Under the plan repository's lock the command: reads the
plan ref's head P and the current plan blob; refuses with `status=stale
base=<sha7> current=<sha7>` (exit 14) when the current blob is not the
base, so a concurrent amendment is never overwritten; validates the
candidate first: `deps` on the edited copy, refusing with `status=invalid`
(exit 2) and the parser's line when the graph does not parse, and `deps
--check --ledger` on it, refusing with `status=conflicts` (exit 1) and the
conflict lines when any undeclared overlap is neither in the ledger's
accepted lines nor named by an `--accept tasks=<a>,<b> path=<p>` (or
`interface=<name>`) argument of this call, so an unsafe graph never
becomes authoritative and an acceptance your human partner gave for this
amendment is written with it. The acceptances are made durable before the
ref moves: the command writes an amendment record
`plans/<ws>/amends/<candidate blob sha>` (write beside and rename) holding
`base=`, `blob=`, `commit=<the commit it is about to publish>` and one
`accept=` line per `--accept`, then swaps the ref, then appends the
accepted-overlap ledger lines and `plan: amended ...` and removes the
record. A retry after a crash finds the record: when the plan ref carries
`commit=`, it completes the ledger lines and removes the record
(`status=amended already=1`); when it does not, it recomputes from the
record's base and candidate as if freshly called. `deps --check --ledger`
also honours `accept=` lines in a surviving amendment record, so a window
between the swap and the ledger line never makes an accepted overlap read
as undeclared;
builds a tree equal to P's with the plan path's blob replaced, makes one
commit with that tree and parent P (subject `docs(hyperpowers): amend <plan
basename>: <subject>`), and publishes it with a compare-and-swap of the plan
ref. A lost compare-and-swap re-reads P and retries only while the plan
blob at the new P is still the base (another file moved the ref), three
attempts, then `status=error`; a changed blob is `stale`. It then prints
`status=amended head=<sha7> plan=<blob sha7>` and appends `plan: amended <blob sha7> by <sid>:
<subject>` to the ledger. A session's worktree keeps its own copy of the
plan; the controller takes the amended copy and its blob from the plan ref
before editing again. An amendment refused with `conflicts` goes to your human partner as the
first scan's rows did; the answer is a new edge in the edited copy or an
`--accept` on the retry. A claim already held is never revoked: a new prerequisite
on a claimed task is itself a conflict row, settled by removing the edge or
by the holder completing the prerequisite first; merge-back rechecks the
task's predecessors against the authoritative graph before it publishes,
so a dependent cannot integrate ahead of a prerequisite the plan now
names.

### 2. Claims and what a session takes next

**`claim`.** `sdd-state claim PLAN_FILE N --session SID [--takeover]
[--code-repo DIR]` gains one check before it publishes: with the
authoritative graph, a task with a predecessor lacking its completion line
answers `status=blocked task=<N> waiting=<comma list> plan=<blob sha7>` and
exits 7 without writing anything. `done` (exit 0), `held` (exit 4, or 0
with `own=1` for the session's own claim) and `claimed` (exit 0) keep their
meanings, exits and records, including `--takeover` and `owner.history`.
The branch is part of the claim. Before the atomic rename the command
reads the integration head H under the lock and writes `branch=<ref>` and
`from=<H sha>` into the owner record beside `session=`, `host=`,
`worktree=` and `time=`, so the intended branch is durable the moment the
claim exists. After the rename succeeds it creates the branch at `from`
(`git branch <ref> <from>`), appends `Task <N>: branch <ref> from <sha7>`
to the ledger, writes `activity/<sid>`, and prints `status=claimed
task=<N> branch=<ref> from=<sha7>`. A losing claimant creates no branch,
since creation follows the rename. The owner's retry (`own=1`) completes
whatever a crash left undone, idempotently: the branch is created at
`from` when it is missing, the ledger line is appended when it is
missing, and the output repeats `branch=` and `from=` from the record; an
existing branch whose head is not `from` and not a descendant of it is
reported as `status=error` naming it. Crash seams follow the rename and
the branch creation. On a takeover the record's branch is `task-<N>.<k>`
with the smallest unused `k`, created from the previous task branch's head
when that branch exists and from H otherwise, and the line records both;
the previous branch is left in place, listed by the board as a leftover
until your human partner removes it.

**`next`.** `sdd-state next PLAN_FILE --session SID [--code-repo DIR]`
classifies every task of the authoritative plan that has no completion
line, in heading order. First by assignment: a task outside the session's
assigned list, when the ledger holds a `session <SID>: tasks <list>` line,
is excluded whatever its graph state. Then every allowed task is exactly
one of: claimable (every predecessor complete, no claim or this session's
claim); own-blocked (this session's claim, a predecessor incomplete, which
an amendment that added an edge produces); held (a claim by another
session); or waiting, with the kind of the first incomplete predecessor
chain found in this order: waiting-on-held (a predecessor held or
waiting-on-held), waiting-on-own-blocked (a predecessor own-blocked or
waiting-on-own-blocked), waiting-on-excluded (a predecessor excluded or
waiting-on-excluded), waiting-on-open (every incomplete predecessor is
claimable or waiting-on-open, which only occurs in a race between two
`next` calls). Predecessors are examined transitively, so a task three
edges behind a held one is waiting-on-held. It prints, in this precedence:
`status=next tasks=<claimable, this session's own claims first>
own-blocked=<own-blocked tasks, may be empty> plan=<blob sha7>` when any
task is claimable; `status=none reason=complete` when no task lacks a
completion line; `status=none reason=own-blocked task=<N> waiting=<its
incomplete predecessors, each as M or M@sid when held>` when nothing is
claimable and any task is own-blocked or waiting-on-own-blocked; `status=none reason=assigned-complete
remaining=<open tasks>` when the assigned list's tasks are all complete and
others remain; `status=none reason=held held=<tasks and holders as
N@sid> waiting=<waiting-on-held>` when every open task is held or
waiting-on-held; `status=none reason=blocked waiting=<waiting-on-excluded
and waiting-on-open> excluded=<excluded> held=<held, may be empty>`
otherwise. The classification is total: the assignment split comes first, every
allowed task falls in exactly one of the four classes (the waiting kind
is decided by the fixed order), and the `none` reasons after `complete`
and `own-blocked` are decided by whether any allowed task is
waiting-on-excluded or waiting-on-open (`blocked`) or none is (`held`). On `own-blocked` the controller cannot work the task (merge-back would
refuse it); it posts a `tasks` record naming the predecessors and hands
back, and your human partner either removes the edge through `amend` or
lets the predecessor complete.

**How a session uses them.** Before each dispatch the controller runs
`next`, claims the first task it lists, and dispatches that task on the
branch `claim` printed. A single session on a serial plan gets today's
order exactly. `held` from `claim` (a race lost between `next` and `claim`)
means run `next` again. When `next` returns `none`: `complete` leads to the
final train (section 5); `assigned-complete` is reported and the session
hands back; `held` and `blocked` make the session post a waiting record of
kind `tasks` whose note is the `held=` and `waiting=` fields, print the
board, and hand back with the board in its message. It takes a held task
over only on your human partner's explicit yes to a question that names
the holder and the time since, recording the takeover beside the original
identity. The dossier skill's rule that a held task means ask is replaced
by this one; its exception for an assigned list stays (a session works
only its list and reports `assigned-complete` the same way).

**The session line** gains the branches: `session <sid>: mode
<current-branch|new-branch|worktree> on <task branch or detached> integrating
<integration> at <toplevel> started <UTC>`. A session appends a fresh line
when it moves to a new task branch or detaches, so its newest line is its
current location.

**Activity.** `claim`, `merge-back`, `wait` and `snapshot --session SID`
write one UTC line to `plans/<ws>/activity/<sid>` (write beside and
rename); the board reads it for `quiet` (section 4). `snapshot` gains the
optional `--session` for that purpose only.

### 3. Branches and merge-back

**Registration.** A session's first act on a plan, after the branch
choice, is `sdd-state register PLAN_FILE --session SID --integration
<branch> [--code-repo DIR]`. Under both repositories' locks (in the lock
order of section 0) the command: reads the plan ref and plan root from the
plan repository's checkout and the code root from the code repository;
reads the plan line of every open workspace in the state checkout; refuses
with `status=spec-branch-mismatch expected=<branch> plan=<ws>` (exit 9)
when another open plan names the same spec and a different integration
branch, plan ref or plan root, so every open plan of a spec shares all
three and the branch lease covers the spec; refuses with
`status=branch-closing` (exit 15) when the branch's lease is closing; and
when this plan's ledger already carries a plan line, answers
`status=registered` if it matches and `status=wrong-branch
expected=<integration>` (exit 9) if it does not. Otherwise it appends the
plan line (section 0) and answers `status=registered`. Because the check
and the write happen under the same locks, two Setups cannot both pass the
check and write conflicting lines; a fixture runs two sibling
registrations with different branches through a barrier and exactly one
succeeds. `verify` keeps reporting `wrong-branch` for a later session
whose branch differs from the registered one. No session
commits to the integration branch directly while the plan is open, with
one exception: the holder of the branch lease during the final train
(section 5).

**Worktrees start detached.** Setup creates a later session's worktree
detached at the integration head (`git worktree add --detach <path>
<integration>`); a session that already has a worktree or works in place
detaches it at the integration head (`git switch --detach <integration>`)
before its first claim. From the first claim on, the integration branch is
checked out nowhere until the final train. `claim` creates the task branch
(section 2); the controller then checks it out in the session's worktree
(`git switch <ref>`). A task's commits land on its task branch; the task
reviewer, the task gate and the review package run against it as they run
against the feature branch today, with BASE the `from` sha the claim
recorded.

**Approval is recorded.** After a task's gate approves (or its tier-skip is
recorded), the controller appends `Task <N>: approved <sha7>` with the head
the reviewers saw. Every later approval of the same task (after a conflict
resolution, after a fix round) appends a new line; the newest is the
approved commit.

**Merge-back.** `sdd-state merge-back PLAN_FILE N --session SID --commit
<sha> [--code-repo DIR]` runs after the approval line and before the
completion line. Under the lock, in this order:

1. Preconditions. The session holds the claim for N (`status=not-holder
   owner=<sid>`, exit 4 otherwise); `<sha>` equals the newest `approved`
   sha for N in the ledger (`status=not-approved approved=<sha7 or none>`,
   exit 12 otherwise); every predecessor of N in the authoritative graph
   has a completion line (`status=blocked waiting=<list>`, exit 7
   otherwise); no branch lease is held for `<integration>` and `git
   worktree list --porcelain` shows the integration branch checked out
   nowhere (`status=checked-out worktree=<path or lease holder>`, exit 13
   otherwise); git is 2.38 or newer (`status=error` naming the floor
   otherwise, the shape of the pin's 2.31 refusal).
2. Already published. If `<sha>` is reachable from the integration head H
   (`git merge-base --is-ancestor`), the ref step is done: the published
   commit is read from the merge record (below), and when that record is
   missing it is reconstructed as `<sha>` itself when `<sha>` lies on the
   integration branch's first-parent history (a fast-forward) and
   otherwise as the first-parent-history commit whose second parent is
   `<sha>`; continue at step 5 with `already=1`.
3. Compute. `git merge-tree --write-tree H <sha>`. Conflicts: change no
   ref, write a waiting record of kind `merge` whose note lists the paths,
   print `status=conflict task=<N> paths=<comma list>`, exit 8. Clean: the
   new commit is `<sha>` itself when H is its ancestor (a fast-forward),
   otherwise `commit-tree <tree> -p H -p <sha>` with the subject `Merge
   task <N>: <task title>`.
4. Record, then publish. Write the merge record
   `plans/<ws>/merges/task-<N>` (write beside and rename) with
   `approved=<sha>`, `proposed=<new>`, `base=<H>`, then `git update-ref
   refs/heads/<integration> <new> H`. A lost compare-and-swap (H moved)
   re-reads H and returns to step 2, rewriting the record, three attempts
   at most, then `status=error` naming both heads. After a successful
   swap the record's `proposed` is the published commit, whatever other
   tasks merge later.
5. Bookkeeping, each step idempotent, using the published commit from
   the record. Append `Task <N>: merged <published sha7> into
   <integration> (from <sha7>)` unless the ledger already has it;
   clear a `merge` waiting record; write `activity/<sid>`. The command
   prints `status=merged task=<N> head=<new sha7>` (with `already=1` when
   step 2 fired).

The controller then, in its worktree, detaches at the published head (`git
switch --detach <new sha>`), deletes the task branch (`git branch -D <ref>`,
whose commits are reachable from the integration branch), appends the
completion line, and runs `next`. A crash anywhere leaves a state the
retry recognizes: before the record, nothing changed; after the record
and before the swap, the record names a commit the ref does not carry and
step 2 does not fire, so the retry recomputes and rewrites it; after the
swap, step 2 fires on the retry and only bookkeeping runs, naming the
record's commit even when other tasks have advanced the head since; after the ledger line, the
retry prints `already=1` and the controller's detach and delete are
themselves idempotent (`git branch -D` of a missing branch is reported and
ignored). A claimed task with a `merged` line and no completion line is
resumed by appending the completion line, never redispatched; `next` lists
it first as this session's own claim for that reason.

**Conflict.** On `status=conflict` the controller merges the integration
branch into the task branch in its worktree (`git merge <integration>`),
resolves through one implementer dispatch whose brief names the paths and
both sides, re-runs the task reviewer over the resolution, re-runs the task
gate's re-review lens (always, not only for some files), appends the new
`approved` line, and retries merge-back with that head. Merge-expected
files are resolved by this same route; nothing merges them automatically.

**What is tested where.** A task's tests run on its task branch before the
gate, as today. The merged tree is tested as a whole by the final review's
full suite and by Finish, not after every merge-back. Two tasks that each
pass alone and fail together surface there; the dependency and overlap
checks of section 1 exist to make that rare, and Known limits records it.

### 4. The waiting board

**The record.** One file per session, `plans/<ws>/waiting/<sid>`, with
`key=value` lines: `session`, `task` (the claimed task, `final`, or `none`),
`kind`, `since` (UTC), `note` (one line), `worktree`, `branch`, `host`.
Kinds: `question` (the session needs an answer from your human partner),
`tasks` (its frontier is empty while other sessions hold tasks), `merge` (a
merge-back conflict awaits the resolve route), `gate` (a gate ended
BLOCKED), `handoff` (it stopped by design after a hand-back). A session
writes only its own record, by write-beside-and-rename, with no lock:
`sdd-state wait PLAN_FILE --session SID --kind <kind> [--task N] --note
"<one line>"` creates or replaces it (`status=waiting kind=<kind>`), and
`sdd-state wait PLAN_FILE --session SID --clear` removes it (`status=cleared`,
also when there was none). A note with a newline is refused (`status=error`,
exit 2). The directory is tracked, so records travel with snapshots and a
board on another host fills in after `sync`.

**The board.** `sdd-state board PLAN_FILE [--code-repo DIR]` runs `sync`
first when the repository has a remote, then prints `status=board
sync=<sync status> sessions=<n> waiting=<m> frontier=<comma list or none>`
and, below it, one line per session that has a claim, a waiting record, an
activity file or a session line: the session id; its task and the claim's
`since`; its worktree and branch; its waiting kind, since and note when it
has one; and `quiet since <UTC>` when it holds a claim and its activity
file is older than thirty minutes with no waiting record. Below the
sessions: the frontier as `next` would print it for an unassigned session;
the held tasks with holders; leftover task branches (a `<integration>.<ws8>.task-*`
branch whose task has a completion line or whose claim names another
branch); and the open plans that share this plan's spec or integration
branch (section 5). Every `sync` outcome is handled the same way: the board
prints from local state, the status line carries `sync=<status>` as `sync`
reported it (`up-to-date`, `offline`, `busy`, `diverged`, `foreign`,
`plain`, `no-remote`, `error` and the rest), a non-success outcome's stderr
line is repeated once, and the exit is 0; the board is informational and
never fails because the fetch did. `board --repo DIR` prints the same for
every open plan in the repository's state checkout, grouped by spec and by
integration branch. This subcommand is for a human reader; its output is
the status line followed by the table, and the dossier spec's one-line
output rule gains that exception for `board` alone.

**What `quiet` means.** A permission prompt blocks the very tool call a
session would use to post, so a session cannot announce one. A quiet
session with a live claim is where to look. The board says `quiet`, not
`permission`, because it does not know; the Decisions list records this.

**Skill text.** Before a session asks your human partner a question, hands
back BLOCKED, meets an empty frontier (`held` or `blocked`), or stops on a
merge conflict, it posts its record and includes the board's session lines
in what it writes; when it resumes, it clears the record before its next
dispatch. A session that is brainstorming the next slice needs nothing from
the board; it reads the board to learn which worktrees and branches are
busy. In Zed the board is the same shell command, run from a terminal or
asked of any session.

### 5. Plans that share a spec, and the final train

**Siblings.** A slice is its own plan file with its own workspace. Each
ledger carries the plan line; `board --repo` groups open plans by spec and
by integration branch, and a session starting a slice sees its siblings in
the board Setup prints. Two sibling plans' task branches never collide
because `<ws8>` is in every name. No inter-plan dependency field is added:
slices that do not block each other need none, and a pair that does is
sequenced by your human partner with the board showing both.

**The final claims.** `sdd-state claim PLAN_FILE final --session SID
[--code-repo DIR]` does two things under the lock. It publishes
`claims/final` by the same atomic rename as a task claim, only when every
task has a completion line and no `claims/task-N` exists without one (the
check `finish` already makes); otherwise `status=blocked task=final
waiting=<open tasks>` (exit 7) or `status=held task=final owner=<sid>
since=<UTC>` (exit 4). It then takes the branch lease, the file named by the lease key (section
0) beside the repository's lock file in the state root, holding `session=`,
`host=`, `plan=<ws>`, `branch=<integration>`, `time=`, `closing=0`;
a lease held by another plan's session answers `status=held task=final
lease=<sid> plan=<ws>` (exit 4) and leaves this plan's `claims/final` in
place, so the second finisher waits its turn and retries. While the lease
is held no merge-back and no `amend` on that branch succeeds
(`status=checked-out worktree=lease:<sid>`), and `claim` of a task on a
sibling plan still works (its merge-back waits) until the lease is marked
closing. The lease outlives the workspace: `finish` deletes the dossier
but does not release the lease; the finishing skill holds it through the
branch action it runs and releases it last with `sdd-state lease
PLAN_FILE --release --session SID [--code-repo DIR]`, which also works for
a session that stops before finishing and after `finish` has removed the
workspace (the lease is found by the identity rule of section 0, which
needs no workspace on disk).
The board shows a lease's holder, host and the age of its activity file;
`claim final --takeover` takes a lease over on your human partner's yes,
on that evidence.

**Closing the branch.** When the finishing skill is about to merge the
integration branch into the base and delete it, it runs `sdd-state lease
PLAN_FILE --closing --session SID [--code-repo DIR]`: under the repository
locks the command checks, at that moment and not from an earlier board, that no
other open plan names the branch (`status=sibling-open plan=<ws>`, exit 15,
otherwise), then sets `closing=1` in the lease. From then on a sibling's
Setup refuses to register the branch (`status=branch-closing`), a task
`claim` on any plan naming the branch refuses (`status=branch-closing`,
exit 15), and `amend` on it refuses the same way, so nothing opens between
the check and the deletion; the merge and the deletion follow, and the
release ends it. A finishing skill that keeps the branch or pushes for a
pull request never marks it closing.

**The train.** The holder checks the integration branch out in its own
worktree (`git switch <integration>`), which the lease makes safe, and runs
the final whole-branch review, the final Codex gate and Finish on it
exactly as they run on a single-session branch today; its fix commits land
on the integration branch directly, which the lease permits because the
branch is single-writer for its duration. `finish PLAN_FILE --session SID
[--force] [--code-repo DIR]` refuses a caller whose session does not hold
`claims/final` (`status=not-holder owner=<sid>`, exit 11) and a plan with
no final claim (`status=no-final-claim`, exit 11); `--force` keeps its
inherited meaning and never bypasses either check. When the train ends,
with the finishing skill's branch action done or with a hand-back, the
session detaches its worktree from the integration branch (`git switch
--detach`) and releases the lease, so the branch is checked out nowhere
again. The skill's "More tasks
remain?" step becomes: `next` says `complete`, claim `final`, and on `held`
post a `tasks` record naming the holder, print the board and hand back.

**The spec's Outcome line.** The decisions compiler writes an Outcome line
at a plan's finish and the finishing skill today treats a spec with one as
finished. Under this design a second finish recompiles: the compiler
accepts a spec that has an Outcome line; updates records whose decision
text changed; appends the second plan's notes as a new paragraph under
"What implementation changed", headed by the plan file's name, keeping the
first plan's paragraph as it was; lists the second plan in each record's
`Recorded:` line beside the first; and rewrites the Outcome line to
`implemented <date> (<plan A basename>), <date> (<plan B basename>); <n>
decisions ...`. The finishing skill's precondition changes accordingly: an
Outcome line is not a refusal. Every open plan of a spec shares one
integration branch (Setup enforces it), and the lease serializes the finals
on that branch, so two compiles of one spec never interleave.

**Branch teardown.** The finishing skill offers the merge option
only when `board --repo` lists no other open plan naming the integration
branch, and before merging it marks the lease closing (above), which
re-checks under the locks; a sibling that opened in between turns the
option into `sibling-open` and the menu is shown again without it. Without
the option the menu says which plan is still open, and the choices are
keep as-is or push for a pull request (whose description states that
another plan is still open on the branch). An open plan is one whose
workspace exists in the state checkout; `finish` removes the workspace, so
a finished plan is not open.

### 6. Failure handling

- A session dies holding a task claim: the board shows it `quiet`, the
  claim stays, takeover is your human partner's to grant, and the new
  holder's branch is `task-<N>.<k>` from the old branch's head; the old
  branch is a leftover the board lists until your human partner deletes
  it. Nothing in this design deletes a code branch except the controller's
  own task branch after publication.
- A session dies holding `final` or the lease: the board reports the
  owner `quiet` with the age of its silence; `claim final --takeover`
  takes both over on your human partner's yes.
- A crash inside `claim` after the rename: the owner's retry completes the
  branch and the ledger line from the record.
- A concurrent amendment: the second `amend` is `stale` and its author
  re-edits from the new blob; an invalid graph is refused before it is
  published.
- A sibling tries to open while a branch is closing: `branch-closing`;
  the human partner finishes the teardown or releases the lease.
- A merge-back's compare-and-swap loses: recompute against the new head,
  three attempts, then `status=error` naming both heads; the claim and the
  task branch stay.
- A merge-back finds the lease held or the integration branch checked out:
  refused with the holder or the worktree named; the controller posts a
  `tasks` record and retries after the final ends, or your human partner
  moves the checkout.
- A crash inside merge-back: the retry recognizes each state (section 3);
  nothing is merged twice and no task is redispatched.
- A dependency amended onto a claimed task: the claim stands, the edge is
  a conflict row, and merge-back enforces it.
- Two sessions append completion lines for the same task: impossible while
  claims hold, since the completion line follows a merge-back that checked
  the claim.
- A plan and a code repository that differ: every code-ref subcommand
  takes `--code-repo` and refuses a wrong root; both repositories' locks
  are taken.
- A repository without a remote: claims, `next`, `board`, merge-back,
  `amend` and the final claims all run in the plain cache; none needs the
  network. The branch lease lives beside the plain lock.
- A hand-off to another host: claims, waiting and activity records travel
  with the snapshot as the ledger does; the arriving session's `board`
  shows them; the lease does not travel (it is a per-host file), so a
  final started on one host is finished there or released.

## Verification

### Offline

Every item below is a fixture in `tests/sdd/test-sdd-state.sh` unless it
names another file; two sessions are played from one shell with distinct
`--session` ids, worktrees and task branches, and interleavings use the
existing `HYPERPOWERS_TEST_PAUSE_AT` and `HYPERPOWERS_TEST_CRASH_AT` seams
with a FIFO barrier between two background processes where a race is the
point. The matrix maps each mechanism to its fixtures:

1. `deps`: a dependency plan in heading order; a legacy plan's serial
   default; mixed annotation naming the tasks; a cycle; a missing task; a
   self-dependency; a duplicated heading; the `plan=` blob of the plan
   ref's head rather than the worktree copy (the two differ in the
   fixture), in a plan repository that is the code repository and in one
   that is not.
2. `deps --check`: an undeclared shared `Modify:` path; a shared `Test:`
   path; a declared chain (no line); a merge-expected file (no line); a
   consumer without an edge to its producer; the reverse edge still a
   conflict; an accepted pair suppressed through `--ledger`.
3. `amend`: the commit's tree equals the head's with one blob replaced; the
   ledger line; `conflicts` on an undeclared overlap with nothing
   published, then published with `--accept` and the accepted-overlap line
   written; `stale` on a changed blob; `invalid` on a cycle, nothing
   published; a crash seam after the swap and before the ledger lines,
   with `deps --check` honouring the record's `accept=` in the window and
   the retry completing the lines; a lost compare-and-swap
   retried when the blob is unchanged; refused under a held lease; the
   plan ref in a plan repository that differs from the code repository.
4. `claim`: `blocked` with the waiting list and no claim written; `claimed`
   once the predecessor completes, with the branch created at the recorded
   head and named with `<ws8>`; two sibling plans both claiming Task 1
   create distinct branches; takeover creating `task-N.2` from the old
   head with the old branch left; `held`, `done` unchanged; `own=1`
   completing a missing branch and a missing ledger line after crash seams
   past the rename and past the branch creation; a losing claimant
   creating no branch.
5. `next`: each class and each `none` reason, including
   `assigned-complete`, `own-blocked` after an amendment adds an edge onto
   a claimed task, a permitted descendant of an own-blocked task, an
   excluded task with incomplete predecessors, a mixed frontier (held plus
   excluded), and this session's own claim listed first.
6. `merge-back`: fast-forward; merge commit with the title and both
   parents; `not-approved`; `not-holder`; `blocked` by a predecessor added
   through `amend`; `checked-out` for a worktree and for a lease;
   `conflict` with paths, no ref moved and a `merge` record; the lost
   compare-and-swap through the barrier; a retry after a crash seam past
   the merge record and before the swap recomputing; `already=1` on a
   retry after a crash past the swap, naming the record's commit after
   another task advanced the head; the retry after a crash past the
   ledger line; the git floor refusal with a fake git.
7. `wait`, `activity`: create, replace, clear, newline refused; records
   travel with `snapshot` and appear after `sync`; `activity/<sid>`
   written by the four writers.
8. `board`: the status line's counts and frontier; a `quiet` session
   (activity aged by `touch -t`); every `sync` outcome class the suite can
   produce (`offline` with a dead remote, `diverged`, `plain`,
   `no-remote`), each printing the local board with exit 0; leftover
   branches; `--repo` grouping two plans by spec and branch.
9. The final train: `claim final` blocked while a task is open; held for a
   second session of the same plan; the lease held by a sibling plan's
   session (`lease=`); the lease key for a branch named `feature/foo`;
   `lease --release`; `--takeover` of the final claim and the lease
   succeeding on the explicit flag alone, whatever the holder's host or
   the age of its silence, and refused without the flag; the board showing
   the holder's host and silence age as information; `finish`
   refusing a non-holder, a missing final claim, and `--force` without the
   claim; `finish` succeeding for the holder and leaving the lease held;
   `lease --closing` refusing a sibling claim and a sibling Setup between
   the eligibility check and the deletion (barrier); `sibling-open` when a
   sibling opened first; merge-back and `amend` refused while the lease is
   held; `register`: `spec-branch-mismatch` for a different branch, plan
   ref and plan root, `registered` on a matching re-run, `wrong-branch` on
   a differing one, `branch-closing`, and two sibling registrations
   through a barrier with exactly one succeeding; the lock order with the
   plan and code roles swapped between two operations through a barrier;
   `lease --release` after `finish` removed the workspace, in a plan
   repository that differs from the code repository.
10. Two plans on one branch: both open; the first finishes with the merge
    option withheld and the open sibling named; the second finishes with
    it offered; the Outcome line listing both; the records' two paragraphs
    (`tests/claude-code/test-decisions-compile.sh` for the compiler part).
11. `verify` reports `wrong-branch`; the session line's new shape is parsed
    by the resume check; `wrong-repo` from each code-ref subcommand with
    a foreign `--code-repo`.
12. `tests/shell-lint`, `tests/sdd/test-sdd-common.sh`,
    `tests/sdd/test-sdd-contract.sh` and `tests/claude-code/test-sdd-dir-path.sh`
    stay green; the state suite's runtime stays under 20 minutes.

### Live

One real two-terminal run on a throwaway repository with a three-task plan
(two independent tasks and one that depends on both), recorded under
`evals/evidence/2026-10-27-parallel-development/` in the evals repository:
both sessions' ledgers and session lines, the board at three moments (both
claimed, one merged, the final claimed), the integration branch's history,
and the final suite.

### Scenario

One hyperpowers-evals scenario with two cases for the skill text. Case one:
a plan with one task held by a fixture session and a claimable task
remaining; the session under test must claim and work the claimable task,
neither stopping nor taking the held one. Case two: every remaining task
held by the fixture session; the session under test must post a `tasks`
record and hand back with the board in its message, asking rather than
taking over. Both run against the current skill text as the control,
following `evals/docs/scenario-authoring.md`.

## Files

- `skills/subagent-driven-development/scripts/sdd-state`: `deps`,
  `deps --check`, `amend`, `next`, `wait`, `board`, `merge-back`, the
  `blocked` check and branch creation in `claim`, `claim final` with the
  lease, `--release`, `finish --session`, `snapshot --session`,
  `verify`'s `wrong-branch`, `--code-repo` on every code-ref subcommand.
- `skills/subagent-driven-development/scripts/sdd-common.sh`: the plan
  parser shared by `deps` and the overlap check; the task-branch naming
  helper; the lease helpers beside the lock helpers.
- `skills/subagent-driven-development/SKILL.md`: Setup (the plan line,
  detached worktrees, `deps`, the scan's new rows, the session line), the
  task loop (`next`, claim and checkout, the approval line, merge-back, the
  detach and delete, the conflict route), the waiting-board rule, the
  final train and lease, the hand-back shape.
- `skills/writing-plans/SKILL.md`: the `**Depends on:**` line in the task
  template and the placeholder scan; **Merge-expected files** in Global
  Constraints.
- `skills/finishing-a-development-branch/SKILL.md` and
  `scripts/decisions-compile`: the second finish of a shared spec; branch
  teardown by the board; `finish --session`.
- `skills/using-git-worktrees/SKILL.md`: the detached start and the task
  branch checkout after a claim.
- `tests/sdd/test-sdd-state.sh`, `tests/claude-code/test-decisions-compile.sh`,
  `docs/testing.md`, `CHANGELOG.md`.
- `evals/`: one scenario with two cases and the evidence directory
  (committed in the evals repository).

## Constraints

- Everything above is bash and node, no new dependency; node is already
  required on the state paths.
- `merge-back` and `amend` require git 2.38 (`merge-tree --write-tree`)
  and refuse older gits by name; every other subcommand keeps the dossier's
  2.31 floor and `sync`'s pre-2.38 behaviour is unchanged.
- The dossier's output grammar holds for every subcommand but `board`
  (status line then table), `deps` (status line then one line per task)
  and the refusals of `amend` and `deps --check` (status line then
  conflict lines).
- No subcommand deletes a code branch; the controller deletes its own
  task branch only after merge-back published it.
- Skill text changes carry the scenario named above; the Red Flags tables
  and rationalization lists are untouched.
- The leak scan and the no-attribution rule apply to every commit.
- The evidence directory is named in the plan's Global Constraints before
  the first live run.

## Out of scope

- A single controller fanning out implementers in one session.
- A cross-session question relay, any permission forwarding, and a hook
  that records a pending tool call.
- An inter-plan dependency field.
- Re-testing the merged tree after each merge-back.
- Deleting leftover task branches automatically.
- Relocating recovery sidecars, the reclaim lock and the lock-sharing
  write helper (scheduled after 6.17.0 by the dossier spec).
- Zed-specific indicators.

## Known limits

- Two tasks that pass alone and fail together are found by the final suite,
  not at merge-back.
- The board infers a permission prompt as `quiet`; it cannot name one.
- A session that reads the board on another host sees the state of the last
  snapshot it could fetch; the lease is per host.
- The serial default for plans without `Depends on:` lines means those
  plans gain nothing from a second session until they are amended.
- A takeover leaves the previous task branch for your human partner to
  delete; the board lists it until then.
- A sibling plan's merge-back waits for the whole final train of the plan
  that holds the lease.
- The board cannot tell a dead holder from a silent one; a takeover
  rests on the human partner's reading of the silence.

## Assumptions

- Assumption: a worktree detached at the integration head between tasks is
  acceptable to the controller, validate via the live run's transcript,
  before the plan's live-check task.
- Assumption: no existing subcommand already holds one repository's lock
  when it would need the pair helper, validate via a read of every
  `hp_lock` call site before Task 1 of the plan.

## Follow-ups

- The question relay over Claude Code's cross-session messaging, once the
  board shows how often `question` rather than `quiet` is what blocks a
  session.
- A hook that records a pending tool call, which would let the board name
  a permission prompt.
- A single-controller fan-out that reads `deps` and `next` unchanged.
- An inter-plan dependency line if sequencing slices by hand proves
  error-prone.
