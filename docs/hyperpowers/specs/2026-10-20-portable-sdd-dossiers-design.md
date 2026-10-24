# Portable SDD dossiers: a state branch per repository

**Date:** 2026-10-20
**Status:** design approved in chat on 2026-10-20 (transport, parallel
model, the approach, and the four design sections); spec self-reviewed;
Codex spec review round 1 raised 14 distinct blocking findings across two
lenses, round 2 five more, and round 3 five more, all confirmed and fixed
(round ledger in the review directory); round 4, the document-gate
ceiling, raised three more (a stale-plan check on arrival, a race between
reconciliation and live writers, a dirty code tree at hand-off), fixed after
the last round and not re-reviewed by Codex; approved by the human partner
on 2026-10-20.
**Branch:** hyperpowers `main` at `16485f4`. The implementation gets its own
branch when the plan is executed.
**Provenance:** the human partner moved an in-flight plan from the laptop to
the workstation (bergen) by pushing and pulling its branch and found no
dossier on arrival. BACKLOG.md "Parallel development on the same machine"
asks for groundwork on parallel tasks and slices; this design lays that
groundwork without finishing it.

## Problem

An SDD run keeps everything except the code outside the repository. The
plan's workspace, which the human partner calls the dossier, holds the
progress ledger, the implementer reports, the task briefs, the review
packages, the dispatch notes, and the tier-skip summary. It lives at

    ${XDG_CACHE_HOME:-~/.cache}/hyperpowers/sdd/<key>/plans/<slug>-<hash8>/

where `<key>` is `git hash-object` over the absolute git directory of the
repository that holds the plan (`skills/subagent-driven-development/scripts/sdd-dir`).
That choice was deliberate: the cache sits outside the working tree, so the
dossier is never committed by accident, never shows in `git status`, and
survives `git clean -fdx`, `git stash`, and `git checkout` in the middle of
a run. It also made the dossier host-bound twice over. Nothing copies
`~/.cache` between machines, and the key hashes a path that differs between
them: the laptop's repositories live under `/Users/johnss51`, bergen's and
inca03's under `/home/johnss51`. A byte-for-byte copy of the cache would not
be found either. The ledger's own first line records the plan path in
whatever form the controller typed it, often absolute, which is a third
host-bound detail.

Work moves between hosts by `git push` and `git pull`. The Unison profiles in
`~/Development/scripts/sync-me` cover `~/Data` only and ignore every
`.cache` directory. In 32 of the 34 local repositories that have a
`docs/hyperpowers/` directory it is listed in the repository's own
`.gitignore`, and one more leaves it untracked, so plans and specs do not
travel either; the human partner's position is that in the repository where
the hand-off failed they should be committed. The hyperpowers repository
already tracks its 64 files under `docs/hyperpowers/`.

The key also splits work on one host. Linked worktrees have distinct git
directories, so each worktree of a clone gets its own key. Release 6.16.0
papered over the common case (a plan in the main checkout driven from a
worktree) with pointer symlinks under the worktree's key. The cache on the
laptop today holds 65 keys; one plan, `2026-10-15-swig-and-deployment`,
was reached from nine different worktrees and left nine pointers. The
`sdd/` root is 174 MB and the Codex gate root `codex-review/` is 682 MB.

Three requirements shape the replacement:

1. Several agents on one repository at once must stay easy.
2. Parallel development on one machine (parallel tasks inside a slice,
   parallel slices of one plan, and switching between them to brainstorm,
   answer questions, or grant permissions) must have a place to grow,
   without being solved here.
3. Working directly on the current branch, on a new feature branch, or in a
   worktree must all be easy, and the dossier must not care which.

## Decisions taken with the human partner

- Git is the transport. Nothing in the design depends on a synchronized
  file system.
- The parallel model to serve first is one controller session per parallel
  task, each session in its own worktree. The shared ledger is designed now;
  a single controller fanning out implementers comes later and must fit the
  same ledger.
- The dossier's durable home is a dedicated state branch of the same
  repository, checked out under the cache. Rejected: a checkpoint committed
  onto the work branch at hand-off (scratch in product history, two copies to
  reconcile, checkpoints landing in master when working on the current
  branch); writing the dossier live into the tracked working tree (each
  worktree gets its own copy, so parallel sessions never share a ledger, and
  partial state rides into implementer commits); a Unison-synced state root
  (conflict and deletion semantics outside git). The Codex approach gate
  independently proposed the state branch and the checkpoint; the Unison root
  was its third.
- The four design sections were approved as presented in chat. The Codex
  spec review then found the shared checkout, the cross-repository case,
  the fallback, and the arrival checks underspecified; the sections below
  carry those corrections.
- The fetch stamp records the remote and the branch it fetched. Creation of
  an orphan branch requires an exact match of remote, branch and a
  fingerprint of the remote's fetch URL, so a changed
  `hyperpowers.stateRemote` or `hyperpowers.stateBranch`, or a repointed
  remote, means a fresh `sync` before any branch is invented; the per-key
  boolean the spec first described would have let a stale stamp vouch for a
  remote it never checked. Decided 2026-10-23 at the hand-back.
- A verified import keeps the legacy workspace as a dated copy. The source
  is renamed to `<source>.imported-<UTC>-<pid>` beside its physical
  location (the pointer's referent when the candidate was a pointer) rather
  than deleted: a session on the previous plugin that still holds the legacy
  ledger open appends into that copy, where a human can find the line, and
  the plain-cache reclaim sets that root aside under a `.reclaiming-` name
  once nothing under it is newer than 14 days and deletes it on a later call
  after 14 more quiet days, so an append that lands during the first 14 days
  buys the copy another 14. Decided 2026-10-23 at the hand-back.
- A tip or incoming commit carrying a symbolic link, a submodule entry or a
  recovery sidecar anywhere is refused whole. The check is absolute and
  runs at checkout creation, at apply and at plain materialization; the
  helper itself never produces those kinds, so only a hand-made commit
  trips it, and such a host wedges every other host's `sync` until the
  branch is repaired, with the path named. Scoping the check to the paths
  an apply writes was rejected: it reopens the fresh-checkout and
  materialization routes. Decided 2026-10-23 at the hand-back.
- The pre-opened-writer race at finish is a documented limit, not a
  protocol change yet. A controller that opened the ledger before
  `finish`'s rename and writes after the verification loses that line;
  `finish` runs when the plan is complete, by the controller that owns it,
  so the writer in question is a second session on the same plan, which
  claims already discourage. The lock-sharing write helper that would close
  it goes with the sidecar relocation below. Decided 2026-10-23 at the
  hand-back.
- Recovery sidecars move out of the tracked checkout in a later design.
  `.rewrite/` and `.sync-applying` live inside the state checkout today,
  which is why three guards refuse them when they arrive from the branch;
  relocating them to a sibling directory under the cache key removes the
  class and is the natural home for the write protocol. It is scheduled
  after 6.17.0, not before. Decided 2026-10-23 at the hand-back.

## Design

### 1. Layout and keying

**State branch.** One per repository, default name `hyperpowers/state`. The
git config key `hyperpowers.stateBranch` in the plan's repository overrides
the name; `hyperpowers.stateRemote` overrides the remote, default `origin`.
The branch is an orphan: it shares no history with any code branch and is
never merged into one.

**Checkout.** On each host, one linked worktree of the state branch per
clone, at

    ${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/state/<key>/

where `<key>` is `git hash-object --stdin` over the physical absolute common
git directory (`git rev-parse --path-format=absolute --git-common-dir`,
resolved with `pwd -P`; on git older than 2.31, `cd "$(git rev-parse
--git-common-dir)" && pwd -P`). Every linked worktree of a clone, including
the ones Claude Code's EnterWorktree tool creates under `.claude/worktrees/`,
shares the common directory and therefore the checkout. Two clones of one
repository on one host get two checkouts tracking one branch.

Beside the checkout live three small items the helper owns:
`<key>.backend`, holding `branch` or `plain` (section 2, backend), the lock
directory `<key>.lock/` (section 2, lock), and the fetch stamp
`<key>.fetched` (creation, below).

**Creation** is one operation, `ensure_checkout` in `sdd-common.sh`, invoked
by `sync` after its fetch and by `sdd-dir` when `sync` has not yet run on
this host. It owns the lock, the atomic creation below, its recovery, and the
backend file, so no caller can leave the backend unrecorded. It never
involves the network:

- local branch exists: `git worktree add <path> <branch>`;
- only the remote-tracking branch exists (a previous `sdd-state sync`
  fetched it): `git worktree add --track -b <branch> <path> <remote>/<branch>`;
- neither exists: `git worktree add --orphan -b <branch> <path>` on git 2.42
  or newer, otherwise `git worktree add --detach <path> HEAD` followed by
  `git -C <path> switch --orphan <branch>`. The environment variable
  `HYPERPOWERS_FORCE_LEGACY_ORPHAN=1` forces the fallback so a test can cover
  it on a modern git.

The worktree is added at a temporary sibling path `<key>.tmp-<random>` and
moved to its final path with `git worktree move` only after the root files
below exist and are committed. Recovery is part of creation: after taking
the lock and finding no checkout at the final path, `sdd-dir` runs
`git worktree prune` and inspects `git worktree list --porcelain` for a
registration at a `<key>.tmp-*` path. A registration whose HEAD commit
contains the sentinel file is complete and is moved into place; any other
is removed with `git worktree remove --force`, and the state branch is
deleted when it does not resolve to a commit containing the sentinel, so
the next attempt starts clean. The test override `HYPERPOWERS_TEST_CRASH_AT`
(values `after-worktree-add`, `after-initial-commit`) makes the helper exit
99 at that point so the recovery is exercised.

An orphan branch is created only when the repository has no remote
configured, or when `sync` has recorded a fetch outcome for this key (the
stamp file `<key>.fetched`, holding the remote, the branch and a
fingerprint of the remote's fetch URL,
written on `assumed-absent` and on every outcome in which the fetch ran,
never on `offline`, `offline-no-state` or `no-remote` (a `no-remote` sync
removes any stamp); creation requires the stamp to name the configured
`hyperpowers.stateRemote` and `hyperpowers.stateBranch` exactly and to
carry the fingerprint of that remote's current fetch URL, so a changed
remote, branch or URL, an empty stamp from before 6.17.0, or a remote
added after a `no-remote` sync means a fresh `sync`). The stamp governs
creation only: a state branch that already exists here is continued, and the
next `sync` reconciles it with whatever the remote holds.
Without either, `sdd-dir` exits 2 with `status=needs-sync`: a fresh host
that is offline must not invent an empty dossier while a remote one may
exist. `sync --assume-absent PLAN` writes the stamp without fetching, for
the human partner who knows no remote dossier exists.

A new branch gets one initial commit carrying four root files:

- `.hyperpowers-state`, containing exactly the line `hyperpowers-state 1`.
  This is the ownership sentinel: a branch at the state name whose root lacks
  this file with this exact content is a foreign branch, and `sdd-dir` exits
  2 naming `hyperpowers.stateBranch` as the key to set. It never reuses a
  foreign branch and never writes to one.
- `.gitignore`, so the regenerable bulk never leaves the host:

      # Regenerable on any host: briefs come from task-brief, packages from review-package.
      plans/*/task-*-brief.md
      plans/*/review-*.diff
      # A copy an import left beside an entry it could not install: local to that host, for a human to merge.
      plans/*/*.from-import

- `.gitattributes`: `plans/*/progress.md merge=union`, so two hosts that both
  appended to one ledger merge without conflict markers.
- `README.md`, four lines: what the branch is, that hyperpowers maintains
  it, that it is never merged into a code branch, and where the design lives.

**Plan workspace.** `<checkout>/plans/<slug>-<hash8>/`, with the slug and
the eight-character hash derived exactly as today from the plan's basename
and repo-relative path, so the workspace name is the same on every host.
Tracked contents: `progress.md`, `task-N-report.md`, `task-N-dispatch-notes.md`,
`task-N-review-focus.md`, `tier-skips.md`, `claims/`. Ignored contents:
`task-N-brief.md`, `review-<base7>..<head7>.diff`.

**Ledger identity is repo-relative.** The ledger's first line becomes
`# SDD ledger — plan: <repo-relative plan path>` for every ledger created
from this release on. The resume check in the SDD skill compares
repo-relative paths: the plan as handed to the controller is reduced to its
path relative to the plan repository's toplevel and compared with the line's
path. A legacy line holding an absolute path is accepted when it lies inside
the plan repository on this host and reduces to the same relative path, or,
when it names a path that does not exist on this host, when it ends with the
same relative path (the workspace name already carries the hash of that
path, so this is the identity the workspace was built from). `import`
(section 2) rewrites such a line to the relative form when it moves a
legacy workspace. A line that reduces to a genuinely different relative path
still means a corrupt workspace, as today.

**`sdd-dir` contract.** `sdd-dir PLAN_FILE` prints `<checkout>/plans/<ws>`
and exits 2 on the same errors as today. It ensures the checkout, writes the
root files when the branch is new, runs `sdd-state import` for the plan, and
prints. It no longer touches or reclaims anything inside the checkout.
`task-brief` and `review-package` call it as before and need no change.

`sdd-dir` with no argument prints `${cache}/hyperpowers/sdd/<key>` with the
common-directory key: the repository-level root that optimizing-performance
uses for baselines stays in the plain cache, shared across worktrees from now
on, and keeps its 14-day idle reclaim of sibling roots.

**Cross-repository pointers.** When the cwd's repository differs from the
plan's, `sdd-dir` leaves a symlink
`${cache}/hyperpowers/sdd/<cwd-key>/plans/<ws>+<plan-key8>` to the workspace,
in the plain cache rather than in a checkout, so a session whose cwd is the
other repository can find the ledger after compaction without a state branch
being created in a repository that merely hosts the session. Dangling pointers
are pruned on the next call as today. Every `sdd-state` subcommand that takes
`PLAN_FILE` resolves the repository from the plan file's directory exactly as
`sdd-dir` does, never from the cwd, so a cross-repository run never creates
or synchronizes state in the hosting repository.

**Unchanged.** Codex gate directories stay at
`codex-review/<key>/run-XXXXXXXX` in the plain cache, keyed by the common
directory from now on for consistency only; the gate's rule for a missing
directory ("treat as cache purged, rebuild the consumed-round count from the
ledger's fix-round lines") already covers a host change. The ungated ledger
stays in the plain cache (section 7).

### 2. The `sdd-state` helper

`skills/subagent-driven-development/scripts/sdd-state <subcommand> [args]`.
The key derivation, branch and remote resolution, checkout path, backend
file, and lock live in one sourced file,
`skills/subagent-driven-development/scripts/sdd-common.sh`, used by
`sdd-dir`, `sdd-state`, the three requesting-code-review scripts that key by
repository, and (read-only) by `hooks/session-start`. Each script locates it
relative to its own directory, so invocation by absolute path from an
installed plugin keeps working.

**Backend.** `<key>.backend` is written by `ensure_checkout`, atomically
(write to a temporary file, then rename): `branch` when the checkout was
created, `plain` when `git worktree add` failed (the sandbox fallback). Under
`plain`, the workspace is `${cache}/hyperpowers/sdd/<key>/plans/<ws>` and
every subcommand below behaves as the table in each entry states; nothing
ever assumes a checkout that the backend file says does not exist. When the
fallback is taken but a state branch for the repository exists (local or
remote-tracking) and holds `plans/<ws>` for the plan at hand, the fallback
first materializes that workspace into the plain cache with
`git archive <tip> plans/<ws> | tar -x` and records `source=<tip sha>` in
the backend file; a plain fallback never starts an empty ledger while branch
state for the plan exists. Deleting the backend file makes the next call try
the branch backend again. `sdd-dir` prints the fallback path and one stderr
line naming the failure; the SDD skill tells the human partner once that the
dossier came from the branch read-only, if it did, and will not travel from
this host.

**Lock.** Every operation that creates the checkout or changes its files,
index, or refs runs inside `mkdir <key>.lock`, which is atomic. The lock
holds an `owner` file (session id, pid, host, time). Acquisition retries
every 200 ms for up to 30 s and then exits 2 with the owner shown. A lock
older than 10 minutes whose pid is not alive on this host, or whose liveness
cannot be checked, is taken over, and the takeover is appended to
`<key>.lock-history`. A trap releases the lock on exit, interrupt, and
termination. Readers (`sdd-dir` after creation, the hook, telemetry) never
take it. Locked operations: creation and root-file commit, `snapshot`,
`finish`, `import`, `prune --apply`, and the reconciliation inside `sync`.
`claim` publishes with one atomic rename and needs no lock.

**Commits use a private index.** Every commit the helper makes goes through
`GIT_INDEX_FILE` pointing at a temporary index: read the branch tip's tree,
add or remove only `plans/<ws>` of the plan at hand, write the tree, create
the commit with the tip as parent, and update the branch ref with the
expected old value. The shared index of the checkout is never used for a
commit, so another session's staged or half-written files are never
included, and a ref update that loses a race is retried from the new tip.
Commits pass `--no-verify` semantics by construction (plumbing runs no
hooks) and `--no-gpg-sign` (the ref update is unsigned), because hooks and
signing settings live in the common directory and would otherwise run on
ledger commits. Author and committer come from the repository's `user.name`
and `user.email` when both are set, otherwise both fields are the dedicated
identity `hyperpowers <hyperpowers@localhost>`.

**Output grammar.** Every subcommand prints exactly one stdout line of
space-separated `key=value` pairs, the first pair always `status=`, except
that `sync` on divergence prints a second line `merge=<command>`. Exit 2 is
usage or internal error throughout; other exits are listed per subcommand.

**`sync PLAN_FILE [--assume-absent]`** (or `sync --repo REPO_DIR` for
callers without a plan). Fetches
`<remote> +refs/heads/<branch>:refs/remotes/<remote>/<branch>`, writes the
`<key>.fetched` stamp (`<remote> <branch> <fingerprint>`, the fingerprint
being the first 12 hex digits of the SHA-256 of the remote's fetch URL, or
`none` when the remote has no URL) on every outcome except
`offline`, `offline-no-state` and `no-remote` (which removes any stamp), runs `ensure_checkout`, and reconciles under the lock.
Reconciliation starts by snapshotting every plan directory with pending
tracked changes, so the working tree equals the local tip S and no local
edit can be lost, then compares S with the fetched tip R:

| Outcome | `status=` | Exit |
|---|---|---|
| S equals R | `up-to-date` | 0 |
| R descends from S: `git reset -q` (index only), then `merge --ff-only` | `fast-forwarded` | 0 |
| S descends from R (unpushed local snapshots): nothing to do, nothing pushed | `ahead` | 0 |
| neither descends from the other and the mechanical merge has no conflict | `merged` | 0 |
| no local branch, checkout created from the remote | `created` | 0 |
| no remote configured, or remote has no such branch | `no-remote` or `absent` | 0 |
| `--assume-absent`: no fetch, stamp written | `assumed-absent` | 0 |
| backend is `plain` | `plain` | 0 |
| fetch failed (offline, proxy, auth), local state branch exists | `offline` | 1 |
| fetch failed and no local state branch exists | `offline-no-state` | 1 |
| a live writer kept changing files during reconciliation (three attempts) | `busy` | 3 |
| neither descends from the other and the merge has a conflict, or git is older than 2.38 | `diverged` | 3 |

The mechanical merge is `git merge-tree --write-tree S R` (git 2.38 or
newer), which computes the merged tree without touching the working tree
and reports conflicts. With no conflict, the merge commit is created with
`commit-tree <tree> -p S -p R`, the ref is updated with the expected old
value, and the index and the paths that differ are set to the merged tree
under the live-writer rule below. The union attribute
makes two appended ledgers merge without conflict markers, and distinct
task files never conflict, so the common two-host case ends `merged`. A
conflict, which takes two sides editing the same report file, ends
`diverged` with nothing changed and a second stdout line
`merge=git -C <checkout> merge <remote>/<branch>`; the human partner
resolves it. `sync` never resolves a conflict, never rebases, and never
pushes. The line also carries `local=<sha7|none> remote=<sha7|none>
age=<seconds since the newer tip>`. `--assume-absent` exists for an offline
fresh host whose human partner knows no remote dossier exists.

The branch is content from other hosts, so a tree is inspected whole before
any of it reaches disk: a tip or an incoming commit that carries a symbolic
link, a submodule entry, or a recovery sidecar (`.sync-applying`, anything
under `.rewrite/`) anywhere in its tree is refused entire, both when the
checkout is created from it and when a commit is applied to an existing
one, and `sdd-dir` refuses a workspace that holds a symbolic link rather
than printing a path the writers would follow out of the cache.

Controllers and subagents write ledger and report files without the lock,
so reconciliation treats the working tree as live. After computing the
target tree (fast-forward or merge) and before touching any file, it
re-reads `git status --porcelain -- plans/` under the lock. If nothing
changed since the snapshot, it updates only the paths that differ between S
and the target (`git checkout <target> -- <paths>`, then the index refresh),
never the rest of the tree. If a plan's `progress.md` gained lines since the
snapshot, those lines are re-appended after the checkout: the ledger is
append-only, so the tail since S is the whole local change. If any other
file changed, it snapshots again and recomputes, up to three times, then
reports `busy`. Before the ref moves, `busy` means nothing changed. The
three attempts that follow the ref update are the other case: the branch is
already at the target, so the sync marker stays on disk and the next
publishing call finishes the apply from it before it does anything else —
`busy` there means the apply is incomplete, not that nothing happened.
What remains is the duration of one
`git checkout` of a few files; the test override
`HYPERPOWERS_TEST_PAUSE_AT=sync-before-apply` holds reconciliation at that
point so a test can append a ledger line and assert it survives.

For http remotes it sets `GIT_HTTP_LOW_SPEED_LIMIT=1` and
`GIT_HTTP_LOW_SPEED_TIME=30` so a dead proxy fails in half a minute rather
than hanging; for ssh remotes it leaves `GIT_SSH_COMMAND` alone.

**`verify PLAN_FILE [--code-repo DIR]`.** Local only. The dossier belongs
to the plan repository; the commits belong to the code repository, which is
the repository the session runs in (the cwd's toplevel, or `--code-repo`),
and for a cross-repository plan the two differ. `verify` reads the ledger
from the dossier and checks the code side in the code repository. First its
identity: the code repository's root commit (`git rev-list --max-parents=0
HEAD`, stable across clones and hosts) must equal the `root=` of the newest
`handoff: code` line, else `status=wrong-repo expected=<root sha7>` exit 9.
Then every commit named by a `Task <N>: complete (commits <base7>..<head7>,
...)` line and by that `handoff:` line must exist (`git cat-file -e`) and be
an ancestor of the code repository's `HEAD`, else `status=code-missing
missing=<sha7,...> branch=<name>` exit 9, naming the branch the human
partner has to pull or switch to. An ambiguous short sha counts as missing.
With no `handoff:` line the identity check is skipped and only completion
commits are checked. When the newest `handoff: plan` line exists, the plan
repository (the directory of `PLAN_FILE`) is checked the same way: its root
commit must equal that line's `root=`, else `wrong-repo` naming the plan
repository, and the recorded plan commit must exist there and be an ancestor
of its `HEAD`, else `status=plan-stale sha=<sha7> branch=<name>` exit 9: the
destination holds an older plan than the one the ledger was written against,
and resuming would read stale task text. `status=ok tasks=<n>` on success.
Under `plain` the check runs the same way.

**`snapshot PLAN_FILE [-m MSG]`.** Private-index commit of `plans/<ws>` (the
ignore file keeps briefs and packages out). `status=snapshot sha=<sha7>
files=<n>` or `status=none`. Default message
`sdd <slug>: snapshot <UTC timestamp>`. Under `plain`: `status=plain`, exit 0.

**`handoff PLAN_FILE [--push] [--plan-untracked-ok] [--code-dirty-ok]
[--code-repo DIR]`.** Preconditions, in order:

1. The plan file is tracked and unmodified in the plan repository
   (`git ls-files --error-unmatch` and `git diff --quiet HEAD -- <plan>`);
   otherwise `status=plan-not-committed`, exit 8, with the file named. The
   flag `--plan-untracked-ok` waives this for repositories that keep plans out
   of git; the human partner then moves the plan by hand.
2. The code repository is clean: `git status --porcelain` there (staged,
   unstaged, and untracked files that are not ignored) is empty; otherwise
   `status=code-dirty paths=<first few>` exit 10. `--code-dirty-ok` waives
   it; the SDD skill passes that flag only after the human partner has seen
   the list and said the in-flight work stays behind on purpose.
3. Backend is `branch`; under `plain`, `status=plain`, exit 7: the dossier
   cannot travel from this host.
4. Neither repository is on a detached HEAD: there would be no branch for
   the destination to pull. `status=detached-head repo=<code|plan>`,
   exit 11, and the human partner creates a branch there first.
5. Neither repository is shallow: its oldest commit is a fetch boundary,
   not the root a full clone computes, so the identity recorded would
   mislead `verify` at the destination. `status=shallow-source
   repo=<code|plan>`, exit 12.

Then it appends `handoff: code root=<root commit full sha> <branch>@<full
sha> at <UTC time> from <host>` to the ledger (identity, branch, and head of
the code repository: the repository the session runs in, or `--code-repo`,
which for a cross-repository plan is not the plan repository). When the plan
repository differs from the code repository it appends a second line,
`handoff: plan root=<plan repository root commit> <branch>@<full sha>`,
because the destination needs that branch too. The status line carries
`code=<branch>@<sha7>` and, when distinct, `plan=<branch>@<sha7>`, so the
hand-off report names every branch the destination must pull. It then runs
`snapshot`, and:

- without `--push`: `status=snapshot sha=<sha7> push=<remote>/<branch>`,
  exit 0, and `push=none` when the plan repository has no remote — the
  record is committed here and nothing left the host;
- with `--push`: the remote tip is pinned first, with
  `git ls-remote <remote> refs/heads/<branch>`. A remote that cannot be
  read, or a pinned tip that is not an ancestor of the snapshot (the remote
  moved since the last sync), is `status=push-failed` exit 1 with the
  remedy on stderr. If `hyperpowers.prePushScan` is set in the plan
  repository's git config, the scan runs next (below) over exactly the
  commits this push publishes; then
  `git -C <checkout> push --force-with-lease=refs/heads/<branch>:<pinned
  tip> <remote> <sha>:refs/heads/<branch>`. The lease is the point: a
  remote that moved between the scan and the push is refused, never
  overwritten with history the scanner never saw. `status=pushed
  sha=<sha7>`, or `status=push-failed` exit 1 with git's message on stderr.

The scan covers every object the push would publish, including content
added and later deleted: the range is `<pinned tip>..<sha>` when the remote
has the branch and `<sha>` read with `--root` when it does not; the content
is `git log --root -p --format= --no-color -m --text <range> -- .` — the
root commit's own patch, every commit the range reaches on any parent line,
a merge as its diff against each parent, binary content as bytes — written
to a file first. A git failure writing it is `status=scan-failed
reason=git` exit 5 before the scanner runs. The file is then piped into
`sh -c "$prePushScan"` with the checkout as cwd and `HYPERPOWERS_SCAN_RANGE`
in the environment; a non-zero exit is `status=scan-failed reason=scanner`
exit 5 with the command's output shown. `--push`
is passed only when the human partner asked for a hand-off; no skill text
passes it on its own initiative.

**`finish PLAN_FILE [--force]`.** Refuses with `status=open-claims
tasks=<n,...>` exit 6 when any `claims/task-N` exists without a
`Task N: complete` line in the ledger, unless `--force`. Otherwise records
`last=<full sha of the tip before removal>`, removes `plans/<ws>` through a
private-index commit `sdd <slug>: finish`, deletes the directory, verifies
with `test ! -d`, and prints `status=finished sha=<sha7> last=<full sha>
push=<remote>/<branch>`. The branch history keeps the dossier at `last`, so
an evidence note cites it as `git show <last full sha>:plans/<ws>/<file>`
and the citation does not rot. Under `plain`: `rm -rf` of the plain
workspace, `status=finished backend=plain`.

**`import PLAN_FILE`.** Candidates, in order: the legacy workspace under the
plan repository's old git-directory key, the same under the cwd's old key,
any pointer `<ws>+*` under either, and the plain-cache location under the new
common-directory key (a sandbox-fallback run). Each candidate is resolved to
its physical referent first (`pwd -P` for a directory, `readlink` chains for
a symlink), and duplicates are dropped. For the first referent that is a real
directory holding a `progress.md`: if the checkout workspace has no
`progress.md`, copy the referent's contents with `cp -a <src>/. <dst>/`,
verify by comparing the recursive file list and byte sizes of source and
destination, and only after a clean verification set the source aside as
`<source>.imported-<UTC>-<pid>` beside its own location and then put a
symlink to the new workspace in the source's place (the copy is kept for a
writer of the previous plugin that still holds the old ledger open; the
plain-cache reclaim sets that root aside under a `.reclaiming-` name once
nothing under it is newer than 14 days and deletes it on a later call after
14 more quiet days; an import interrupted between those two steps leaves the
kept copy and no pointer, and the next import completes the relink and
prints `status=moved`) (a pointer candidate is
relinked to the new workspace instead); a failed verification leaves the
source untouched and exits 2 with `status=import-failed`. The copied
ledger's first line is rewritten to the repo-relative form when it holds an
absolute path inside the plan repository. If the checkout already has a
ledger, the candidate is left alone: `status=skipped reason=ledger-exists
path=<candidate>`. Otherwise `status=moved from=<path>`, with `conflicts=<n>` appended when `n` destination entries differed from their legacy copies and were kept (the legacy copy of a report or review sits beside it as `<name>.from-import`, ignored by the branch, for a human to merge; a conflicting brief or review package regenerates and is not copied), or `status=none`.
Idempotent: a second call prints `status=none`. Under `plain` the
destination is the plain-cache workspace, the state branch is the first
candidate when it holds `plans/<ws>` (materialized with `git archive`), and
the same rules apply.

**`prune [--days N] [--apply] --repo REPO_DIR`.** Default 30 days. Lists
plan directories whose last commit (`git log -1 --format=%ct -- plans/<ws>`)
and newest file are both older than N days, and checkouts under
`${cache}/hyperpowers/state/` whose `.git` file points at a directory that no
longer exists. Without `--apply` it only lists (`status=listed ...`).
The listing also names, as `tombs=<comma-separated names>`, every copy a
killed removal left at `plans/.removing-<ws>-<pid>` whose process is gone,
whose newest file is older than N days, and whose workspace the branch does
not track (a tracked one comes back through `sync`'s restore and is never
listed; a copy whose tracking cannot be read is kept), and as
`quarantined=<names>` every copy an earlier `--apply` set aside at
`plans/.pruned-<ws>-<pid>` whose newest entry is older than N days. Removal
is two-phase, because a writer that still holds the copy open cannot be
excluded: the first `--apply` renames a listed tomb to `plans/.pruned-<ws>-<pid>`
under the lock after re-checking it, and touches it so the clock restarts
(a late append moves into the renamed copy and refreshes its time); a later
`--apply`, once nothing in the quarantined copy is newer than N days,
deletes it and verifies it is gone. The `status=pruned` line prints the
names renamed this run as `tombs=` and the names deleted this run as
`quarantined=`; a copy that fails any re-check is kept where it is.
With
`--apply` it removes the listed plan directories in one private-index commit
`sdd: prune <slugs>` and `rm -rf`s the dead checkouts together with their
backend and lock files. Nothing calls `prune` implicitly. Under `plain`:
`status=plain`; plain workspaces are left to the plain cache's own 14-day
reclaim.

**`claim PLAN_FILE N --session SID [--takeover]`.** Prepares
`plans/<ws>/claims/.tmp-<random>/owner` with the complete record below, then
publishes it as `plans/<ws>/claims/task-N` with one `rename(2)` of the
directory, through node's `fs.renameSync` (a shell `mv` on macOS moves a
directory into an existing target instead of failing). The rename is atomic
and fails when the target exists, so a loser never observes a claim without
its record. `owner` holds one `key=value` per line:
`session=<SID>`, `worktree=<the cwd's toplevel>`, `branch=<git branch
--show-current, or detached@sha7>`, `host`, `time` (UTC). `status=claimed
task=N`, exit 0. When the claim exists: `status=held task=N owner=<session>
since=<time> worktree=<path>`, exit 4 (exit 0 when `owner=` equals the given
SID, since a resumed session re-claiming its own task is not a conflict).
`--takeover` appends the previous owner to `owner.history`, rewrites
`owner` (write beside, then rename), and exits 0. Claims are tracked files and travel with snapshots.
`--session` is required; the controller passes the session id the SDD skill
established at Setup (section 4).

### 3. Hand-off and arrival

**Leaving a host.** The human partner asks for a hand-off ("hand off to
bergen", or any phrasing). The controller runs
`sdd-state handoff PLAN --push`, reports the result line, on exit 8
relays the plan-file precondition with the commands to commit the plan, and
on exit 10 shows the dirty paths and asks whether that work stays behind;
only an explicit yes passes `--code-dirty-ok`. It
then lists, from the status line, the branches to push here and pull on the
other side: the code branch, and the plan repository's branch when the plan
lives in another repository. The controller pushes none of them unless asked
(the human partner's standing rule). A destination that lacks the plan file
cannot start Setup, and the report says so. With no remote, `handoff` snapshots and reports
`push=none`.

**Arriving.** The human partner starts SDD on the plan as usual. Setup order
becomes: branch choice (section 5); `sdd-state sync PLAN`; `sdd-dir PLAN`;
the ledger check exactly as today, creating the ledger with its identity
line when there is none; the session line (section 4); then
`sdd-state verify PLAN`. On `diverged` the controller stops and
presents both tips and the merge command as a question in the Deciding
Together shape; it never merges on its own. On `offline` it continues on the
local checkout and appends `state: sync offline at <time>` to the ledger so
the record shows the run may have started from a stale snapshot. On
`offline-no-state` from `sync`, or `needs-sync` from `sdd-dir`, it stops:
this host has no dossier and cannot learn whether the remote holds one, so
it tells the human partner to get online or, when they know no remote
dossier exists, to confirm `sync --assume-absent`. On `wrong-repo` it
stops and names the repository the ledger was handed off from. On
`plan-stale` it stops and names the plan repository branch to pull. On
`busy` it retries `sync` once after the other session's writes settle and
then asks the human partner. On
`code-missing` it stops: the completed tasks' commits are not in this
checkout, so resuming would redo or misplace work; it tells the human
partner which branch to pull and resumes only after `verify` passes.
`sync` also prints the age of the tip it found, so a forgotten hand-off is
visible at a glance.

**Regeneration on arrival.** Briefs are rebuilt by `task-brief` before each
dispatch, which is already when they are written. Review packages are rebuilt
by `review-package` from the base and head the ledger records per task. Gate
directories start fresh under the existing rule. Nothing in the fix loop or
the final review needs a file that stayed on the other host.

**Snapshot cadence.** After the pre-flight scan table is written; after every
`Task <N>: complete` ledger line (where the skill already commits code);
at `finish`; and inside `handoff`. A controller that lost its context has one
more recovery source: `git -C <checkout> log --oneline -- plans/<ws>`.

**Network discipline.** Only `sync` and `handoff --push` touch a remote.
`sdd-dir`, `verify`, the hooks, `task-brief`, and `review-package` never do.

### 4. Parallel sessions: the shared ledger

The checkout is the coordination point. Any two controller sessions on a
host, in any two worktrees of the clone, read and write the same
`progress.md` per plan in real time, which is the property the deferred
parallel work needs and the old per-worktree key could not provide. Four
rules enter the SDD skill now, scoped so a single-session run reads as it
does today.

**Session identity.** At Setup the controller establishes its session id:
`$CLAUDE_CODE_SESSION_ID` on Claude Code; on a harness without one, a value
it generates once (`uuidgen`, or `<UTC epoch>-<random>`). It appends one
ledger line once the ledger exists and its identity line has been checked
(the Setup order in section 3):

    session <sid>: mode <current-branch|new-branch|worktree> on <branch> at <toplevel> started <UTC time>

The line is per session, so several sessions, hosts, and branches each have
their own record and an imported legacy ledger simply gains one. On Claude
Code the id survives compaction because the environment does; on a harness
where the controller cannot recover which line is its own after compaction,
it treats every claim as foreign and the ask rule below applies.

**Claim before dispatch.** Before dispatching Task N, run
`sdd-state claim PLAN N --session <sid>`:

- `claimed`, or `held` by this session's own id (a resume after
  compaction): proceed under the existing in-flight rule.
- `held` by another session: do not take the next task on your own
  initiative; which tasks may run concurrently is the deferred spec's
  question, and skipping ahead would answer it by accident. Stop and tell
  the human partner who holds the task and since when. Ask whether to take
  it over; take over (`--takeover`) only on their explicit yes to that
  question, and record the takeover beside the original identity. If they
  say the other session is still working, wait for their instruction. The
  one exception: when the human partner assigned this session a task list
  at the start, recorded as `session <sid>: tasks <N,M,...>`, the session
  works only those tasks and reports a held task in its list the same way.

**Identity line.** `Task <N>: implementer <agent-id> (session <sid>,
worktree <path>, branch <name>)`. The parenthesized part is new.

**Append discipline.** When any other session may be live on the plan,
ledger lines are appended with a quoted heredoc
(`cat >> <workspace>/progress.md <<'EOF'`), never with the Edit tool,
whose read-modify-write drops a line another session appended in between.

**Completion barrier.** Final review and `finish` require a `Task <N>:
complete` line for every task of the plan, as today, and `finish` refuses
while any claim lacks one (section 2); a session that reaches the end of its
own task list while other sessions' tasks are open reports that and stops
rather than finishing the plan.

Deferred to a follow-up spec, in this order: which tasks of a plan may run
concurrently (writing-plans needs a dependency or slice annotation); how a
slice maps to a branch and merges back; the single-controller fan-out; and
switching between sessions, which is Claude Code's user interface and not
something hyperpowers can perform.

### 5. Branch choice at the start of a run

using-git-worktrees Step 0 keeps its isolation detection. A session already
inside a linked worktree still skips straight to project setup. Otherwise,
after checking the instruction files for a declared preference (which still
wins without asking), it asks one question with three options instead of
the yes-or-no worktree question:

1. stay on the current branch;
2. create a branch in place (`git switch -c <name>`, the name from the plan
   slug unless the human partner gives one);
3. create a worktree (the native tool first, then the `.worktrees/` fallback,
   as today).

On Claude Code the question uses the selection widget; elsewhere it is a
plain question. The answer is announced and becomes the `mode` of the
session line (section 4).

SDD Setup's rule "never start implementation on a main/master branch without
your human partner's explicit consent" is reworded so that choosing "stay on
the current branch" is that consent. The dossier no longer depends on the
branch, so resuming a run on master is as safe as anywhere else once
`verify` has passed.

finishing-a-development-branch gains one optional input from its caller: the
mode of the finishing session. SDD reads its own session line from the
ledger before `sdd-state finish` deletes the workspace and passes the mode
when it invokes the finishing skill; a caller that passes nothing gets
today's `GIT_DIR`/`GIT_COMMON` detection. Mode `current-branch` on the
repository's default branch offers two options, push and keep, because there
is nothing to merge and no branch to delete. Mode `current-branch` on any
other branch, `new-branch`, and `worktree` keep today's menus.

executing-plans is outside this design except for the branch question, which
it already reaches through using-git-worktrees in its Step 1. It keeps no
ledger and gets no dossier lifecycle here; giving it one is listed under Out
of scope.

### 6. Finish, pruning, migration

**Finish.** Step 1 of the SDD Finish section becomes: read this session's
mode from the ledger, then `sdd-state finish PLAN`; step 2's `test ! -d`
stays as the controller's own verification. Finish prints the push line and
pushes only if the human partner asks. "A clean finish that leaves the
workspace behind is an INCOMPLETE finish" stays true of the working tree; the
branch history keeping the dossier is the point.

**Pruning.** No automatic reclaim runs inside a checkout: a plan idle on this
host may be active on another. `sdd-state prune` is the only remover. The
plain cache keeps today's 14-day reclaim for legacy workspaces, the
no-argument roots, pointers, and gate directories. Because `import` leaves a
symlink where a legacy workspace was, a legacy `<key>` directory that holds
only symlinks ages out as a whole.

**Migration.** The first `sdd-dir PLAN` after the upgrade imports the plan's
legacy workspace (section 2, `import`). No manual step. Two caveats go in the
release note: both hosts must run a plugin version with the state branch,
because an older plugin on the arriving host writes to the legacy cache and
splits the ledger; and baselines that optimizing-performance stored under a
worktree's old key are not moved (the no-argument root is keyed by the common
directory from now on).

**Version.** Minor bump. Install on each host from the release tag per the
plugin-install procedure.

### 7. Readers that change

- `hooks/session-start`, compaction notice: read-only lookup, in order, of
  `state/<common-key>/plans/*/progress.md`, then
  `sdd/<common-key>/plans/*/progress.md` (pointers followed), then the
  legacy `sdd/<git-dir-key>/plans/*/progress.md`; newest by mtime across
  all three; creates nothing; fails silent as today. The key derivation
  comes from `sdd-common.sh`, sourced, so the hook and the scripts cannot
  drift.
- `scripts/gate-telemetry`: the SDD walk covers `state/<key>/plans/` and the
  plain-cache `sdd/<key>/plans/`, deduplicating by real path as it does now;
  the symlink following for 6.16.0 pointers stays for the plain cache.
- `scripts/ungated-ledger`: `append` writes under the common-directory key;
  `pending` reads the common-directory key and the legacy git-directory key
  for one release so unswept entries stay visible. The ledger stays in the
  plain cache; moving it onto the state branch is a follow-up.
- `scripts/codex-review-dir`: common-directory key, no behavior change.

### 8. Skill text changes

Each site, so the plan can name tasks against it:

- `skills/subagent-driven-development/SKILL.md`, Setup: the workspace
  bullet (new path form; the order branch choice, `sdd-state sync PLAN`,
  `sdd-dir PLAN`, ledger check, session line, `sdd-state verify PLAN`; the
  repo-relative identity rule; the session line; snapshot cadence; the
  offline, offline-no-state, needs-sync, diverged, busy, wrong-repo,
  plan-stale, and code-missing outcomes; the plain backend notice; the
  hand-off report with its code-dirty and plan-file questions). Dispatch: the claim bullet and its ask rule, the identity
  line, the append-discipline sentence. Final review: the completion
  barrier sentence. Finish: read the mode, then `sdd-state finish`. Red
  Flags and Common Rationalizations unchanged.
- `skills/subagent-driven-development/example-workflow.md`: paths, the
  session line, and the new commands where the worked run touches them.
- `skills/using-git-worktrees/SKILL.md`: Step 0's question, the Quick
  Reference rows, one rationalization row for "they said current branch, so
  the consent rule does not apply to me" (it does apply; the answer is the
  consent).
- `skills/finishing-a-development-branch/SKILL.md`: the optional mode input,
  the environment table row for `current-branch` on the default branch.
- `skills/optimizing-performance/SKILL.md` and `perf-implementer-notes.md`:
  one sentence that the repository-level root is shared across worktrees.
- `README.md`, `CHANGELOG.md`, `docs/testing.md`.

## Verification

### Offline (all numbered items are the gate)

Every suite runs under a temporary `XDG_CACHE_HOME`, with throwaway
repositories made by the existing `make_repo` pattern and a bare repository
standing in for `origin`. Two clones of one bare repository at different
absolute paths stand in for two hosts.

1. `tests/claude-code/test-sdd-dir-path.sh`, updated: two worktrees of one
   clone print the same workspace; two clones print different checkouts;
   the printed path is inside the state checkout and the checkout is a
   linked worktree on the state branch; `task-brief` and `review-package`
   stdout contracts hold; briefs and packages are ignored by the checkout's
   `.gitignore`; the no-argument form stays in the plain cache under the
   common-directory key; a branch at the state name without the exact
   sentinel exits 2 with the config key in the message; the plain backend
   is selected and persisted when `git worktree add` is made to fail, a
   later call honors the backend file, and when a state branch already holds
   the plan's workspace the fallback materializes it from the branch with
   `source=` recorded instead of starting an empty ledger; a cross-repository call leaves the
   pointer in the plain cache and creates no checkout in the cwd's
   repository; a clone with a remote but no fetch stamp gets `needs-sync`,
   a repository with no remote gets its orphan branch without one; creation
   recovers from a crash injected after the worktree add and after the
   initial commit, leaving one registration and one branch.
2. `tests/sdd/test-sdd-state.sh`, new:
   - creation writes the four root files in one commit on both the
     `--orphan` path and the forced legacy path, and two concurrent first
     calls (two subshells) produce one checkout and one initial commit;
   - `snapshot` commits tracked files, skips ignored ones, succeeds with a
     failing `pre-commit` hook installed, with `user.name` unset, and with
     `user.email` unset; two concurrent snapshots of two plans in one
     checkout both land, each containing only its own plan directory, while
     a third session holds unrelated files staged in the shared index;
   - `finish` refuses with exit 6 on an open claim, succeeds with `--force`
     and after the completion line, commits, leaves no directory, and the
     printed `last` sha shows the removed files with `git show`;
   - `import` moves a legacy workspace, verifies before removing, leaves a
     symlink, rewrites an absolute identity line to the relative form,
     relinks a pointer candidate, skips when a ledger exists, is
     idempotent, and leaves the source intact when verification is made to
     fail;
   - `handoff` exits 8 for an untracked and for a modified plan file, passes
     with `--plan-untracked-ok`, exits 10 for a code repository with staged,
     unstaged, or untracked changes and passes with `--code-dirty-ok`, appends the `handoff:` line, leaves the
     bare remote's refs unchanged without `--push`, updates them with
     `--push`, exits 7 under the plain backend; a `prePushScan` command that
     exits non-zero blocks the push with exit 5; a scanner that matches a
     string present only in a commit that was added and later deleted
     blocks the first push and a later push alike;
   - `sync PLAN` on the second clone creates its checkout from the remote;
     fast-forwards when behind, including after private-index commits left
     the shared index stale; reports `ahead` after an unpushed snapshot;
     when the local tip is behind and had pending ledger edits, ends
     `merged` with every line of both ledgers present and no conflict
     markers, and the commit graph shows the merge with S and R as parents;
     reports `diverged` with exit 3 and changes nothing when both sides
     edited the same report file; reports `offline` with exit 1 against an
     unreachable remote and `offline-no-state` on a fresh clone; writes the
     stamp with `--assume-absent`; preserves a ledger line appended while
     reconciliation is held at the pause point and reports `busy` when a
     report file keeps changing across three attempts; and resolves the plan
     repository from the plan file when the cwd is another repository;
   - merging the diverged ledgers with the union driver yields every line
     from both;
   - `verify` passes after the code branch is pulled into the second clone,
     exits 9 with `code-missing` naming the branch before it is, and exits 9
     with `wrong-repo` when run from a repository whose root commit differs
     from the recorded one, and exits 9 with `plan-stale` when the
     destination's plan repository lacks the recorded plan commit; a cross-repository hand-off and arrival (plan in
     repository P, code in repository C) records C's identity and P's
     branch, and a destination built from clean clones of P and C that pull
     exactly the branches the hand-off status line names starts Setup and
     verifies against C;
   - the second clone, at a different absolute path, resumes a ledger whose
     identity line is relative and one whose line is an absolute path from
     the first clone;
   - `prune` lists without `--apply` and removes with it;
   - `claim` from two concurrent subshells yields exactly one `claimed` and
     one `held` whose line carries the winner's complete owner record; a
     prepared but unpublished `.tmp-*` directory is invisible to a second
     claimant, which wins; re-claiming with the owner's own session exits
     0; `--takeover` records the history;
   - a stale lock older than the threshold with a dead pid is taken over
     and recorded; a fresh lock makes the second caller wait and then
     succeed when it is released.
3. `tests/hooks/test-session-start.sh`: the compaction notice names the
   checkout's ledger, falls back to the plain cache and the legacy key in
   that order, and creates nothing.
4. `tests/codex-review-gate/test-gate-telemetry.sh` and
   `tests/codex-review-gate/test-ungated-ledger.sh`: the new keying, and
   `pending` reading both keys.
5. `tests/sdd/test-sdd-contract.sh`: the new SKILL sentences pinned, the
   stale ones fenced.
6. `scripts/lint-shell.sh` clean over `sdd-dir`, `sdd-state`,
   `sdd-common.sh`, and the hook.
7. The offline set listed in `docs/testing.md` still passes in full, run by
   that list (never by a blanket `find tests`, which launches live sessions).

### Live

8. Two-clone rehearsal on this machine, two clones of a scratch repository
   with a bare origin standing in for two hosts: run a two-task plan in
   clone A through Task 1 with the real SDD skill in a `claude -p
   --plugin-dir` session, hand off with `--push`, push the code branch, pull
   it in clone B, start SDD on the plan in clone B, and confirm from B's
   transcript and ledger that `verify` passed and it resumed at Task 2
   without re-dispatching Task 1. A second pass skips the code pull and
   confirms the controller stopped on `code-missing`. Artifacts under
   `evals/evidence/2026-10-20-portable-sdd-dossiers/rehearsal/`.
9. The quorum scenario `sdd-plan-scoped-scratch` passes on the new layout.
   Its checks and the evals analyzers read the old cache path today, so a
   small evals change (accept both layouts) is a prerequisite and is named
   in the plan before this gate.
10. `tests/claude-code/test-worktree-native-preference.sh`, updated for the
    three-way question, passes once live.

## Files

Scripts:
- `skills/subagent-driven-development/scripts/sdd-dir` (rewrite of the
  keying and creation; same stdout contract)
- `skills/subagent-driven-development/scripts/sdd-state` (new)
- `skills/subagent-driven-development/scripts/sdd-common.sh` (new)
- `skills/requesting-code-review/scripts/codex-review-dir`,
  `gate-telemetry`, `ungated-ledger` (keying)
- `hooks/session-start` (compaction lookup)

Skill text: the sites in Design section 8.

Tests: items 1 to 5 above, plus the `docs/testing.md` coverage table.

Docs: `README.md`, `CHANGELOG.md`, `docs/testing.md`.

## Constraints

- Skill changes are evaluated before release (repository `CLAUDE.md`, "Skill
  Changes Require Evaluation"). The "your human partner" voice, the Red
  Flags tables, and the rationalization lists stay as they are apart from
  the one added row in using-git-worktrees.
- Core skills depend on bash, git, and node only. No network access from
  hooks, from `sdd-dir`, or from `verify`.
- No skill pushes to a remote except `sdd-state handoff --push`, and that
  flag is passed only on the human partner's explicit hand-off request.
  Finish prints the push command and does not run it.
- No attribution lines in commits or files. The staged diff passes the leak
  scan before every commit in this repository.
- Plans, specs, and evidence notes are committed in this repository (its
  `CLAUDE.md` exception); live-run artifacts an evidence note cites go under
  `evals/evidence/2026-10-20-portable-sdd-dossiers/`, named here so no
  citation points into the SDD workspace.
- The effective git floor does not rise: every command used past git 2.23
  has a fallback (`--path-format`, `--orphan`; `merge-tree --write-tree` is
  2.38 and degrades to `diverged`; `worktree move` is 2.17).

## Out of scope

- Parallel dispatch rules, slice annotations in plans, the single-controller
  fan-out, and switching between sessions (follow-up spec).
- A dossier lifecycle for executing-plans (ledger, snapshots, hand-off,
  finish). It keeps today's flow and gains only the branch question.
- Moving the ungated ledger or the Codex gate directories onto the state
  branch.
- Changes in the evals repository beyond the layout prerequisite named in
  Verification item 9.
- The legacy `.git/sdd` allow rules and the `allow-sdd-writes.sh` hook in
  the human partner's `~/.claude/settings.json`; they are inert and theirs.
- Synchronizing `~/.cache` between hosts by any other means.
- Edits to BACKLOG.md.

## Known limits

- Two clones of one repository on one host share a branch but not a live
  ledger; `sync` detects their divergence and the human partner merges.
- The state branch is as public as its repository. Implementer reports carry
  command output. The pre-push scan is opt-in through git config; without
  it, `handoff --push` publishes whatever the reports contain.
- A hand-off that was never requested reproduces today's failure, bounded by
  the last task-completion snapshot and visible in the age `sync` prints.
- `handoff` can check that the plan file is committed; it cannot check that
  the code branch was pushed. `verify` on arrival catches a missing code
  branch before any work is redone.
- Git keeps the checkout's metadata in the clone's `.git/worktrees/`;
  deleting the clone orphans the checkout until `prune --apply` removes it.
- The compaction notice names one ledger; with several active plans it
  names the newest, as today.
- A claim is advisory. A controller that skips `claim` can still dispatch a
  held task; the skill text, not the file system, enforces the step.
- The lock serializes the helper's own operations. A human running git by
  hand inside the checkout is outside it.
- `sync` merges only what git merges without conflict. The union driver
  covers the ledger; two hosts editing the same report file is a conflict
  the human partner resolves.
- A controller that opened `progress.md` before `finish`'s rename-aside and
  writes after the verification loses that line. `finish` runs when the
  plan is complete, by the controller that owns it, so this needs a second
  session writing to a finished plan; the lock-sharing write helper that
  would close it is scheduled with the sidecar relocation (Follow-ups).

## Assumptions

**Assumption:** Claude Code's Edit and Write tools treat files under
`~/.cache/hyperpowers/state/<key>/` the way they treat today's cache
workspace, with no additional prompt. Validate via Verification item 8 in the
default permission mode; if a prompt appears, the plain backend is the
interim and the finding goes to the release note.

**Assumption:** both hosts run git 2.42 or newer. Validate via `git
--version` on bergen before release; the fallback is implemented and tested
regardless (Verification item 2).

**Assumption:** the remotes in use accept a new branch named
`hyperpowers/state`. Validate via `git push --dry-run origin
hyperpowers/state` against the hyperpowers GitHub remote and one work
repository's remote before release; a rejection is handled by setting
`hyperpowers.stateBranch`, and the release note says so.

**Assumption:** `CLAUDE_CODE_SESSION_ID` is present in Bash tool calls on
both hosts and stable across compaction within one session (observed present
on the laptop under Claude Code 2.1.287). Validate via `env` on bergen and a
compaction in Verification item 8; if it is absent or changes, the generated
id path of section 4 applies and claims are treated as foreign after
compaction.

**Assumption:** two quoted-heredoc appends of one ledger line each, from two
sessions, never interleave within a line on APFS and ext4 (`O_APPEND`, writes
far below 4 KB). Validate via the concurrency cases in Verification item 2.

## Follow-ups

- The parallel development spec (BACKLOG "Parallel development on the same
  machine"), built on the shared checkout, claims, session lines, and the
  task-list assignment.
- BACKLOG "Stale brokers": resolved on 2026-10-23 (hyperpowers `main`
  d7d6883). The sandboxed preflight's `stale-broker` was `broker-health`
  reading an EPERM from `kill -0` as a dead pid; only ESRCH is death now,
  and the gate's index says the preflight and every companion command run
  outside the sandbox, because a companion that cannot connect tears down
  the live broker's socket and record.
- Recovery sidecars out of the tracked checkout, with the lock-sharing
  write helper for ledger appends and a recovery-only result for the
  journaled rewrite's composition case: one design, after 6.17.0
  (Decisions).
- Evals: analyzers and scenario checks for the new layout.
- The ungated ledger onto the state branch, so unswept entries follow the
  work between hosts.
- A dossier lifecycle for executing-plans, if inline execution is still used
  once the state branch exists.
