# Open review-sweep findings: final train, amend, records, hardening, skill text

**Date:** 2026-11-08
**Status:** design approved in chat on 2026-11-08, section by section (final
train and amend; records, board, hardening and single findings; skill text,
stop guard, evidence note and task order). Clarifying answers: the approval
line carries the full commit id; amend refuses in all three event-6 cases;
the skill-text edits are evaluated by contract needles plus a reachability
note; one spec on one branch. The scope is the "base list" the human partner
chose. The Codex approach gate did not run: those answers settled the
material alternatives, and each remaining fix has one shape. Spec
self-reviewed. Codex spec review: round 1 (two lenses) raised twelve
distinct blocking findings, all confirmed and fixed; rounds 2, 3 and 4 each
raised one new blocking finding, all confirmed and fixed. Round 4 was the
last round allowed, so its fix (merge-back reads approval lines through
`ledger_records`) has had no confirming Codex pass; the plan review checks
it next. Ledger in
`~/.cache/hyperpowers/codex-review/193a951fd4f675975a919be372c5015a95aa0491/run-Pl8lWXBd/`.
**Branch:** chosen at execution time through using-git-worktrees.

## Problem

The Codex review sweep of the twelve ungated parallel-development events
(2026-11-07 and 2026-11-08) closed every event, eleven of them blocking. The
records-and-completion group was fixed and merged at e62fdb5. The findings
below are still present on main at e62fdb5; line numbers in this spec are
at that commit. The per-finding triage is scratch
(`~/.cache/hyperpowers/sweep-2026-11-07/triage.md`), so this spec restates
every finding it acts on.

- Final train: a takeover of the final train after a killed finish moves
  the lease of a plan that is still open, and a damaged `closing=` reopens a
  branch in teardown.
- Amend: three paths leave a worktree that has the plan ref checked out
  with the old plan staged against the new head.
- Records and board: a record publish can be swallowed by a directory, a
  plain-backend snapshot can recreate a removed workspace, and fetched file
  names or loose session ids split the board's line grammar.
- Hostile-actor hardening: reviewers can be shown replaced objects, a
  seven-character approval can resolve to the wrong commit, grafts can fake
  ancestry, and a symbolic integration ref moves the branch it points to.
- Single findings in `deps`, `register`, `claim`, the plan parser, `enc`,
  and one test fixture.
- Skill text that contradicts the scripts: the takeover BASE command, the
  meaning of claim's `error`, the finishing compiler "never refuses", the
  sibling-plan menu rule, and the later-session worktree order.
- The stop guard's completion pattern matches anywhere in a line, while
  sdd-state's matches only the marker.

## Goals

- Each finding below is fixed. Each one that changes behavior has a test
  that fails at e62fdb5 and passes after the fix, under the red-run rules in
  Testing.
- The skill text says what the scripts do.
- The stop guard and sdd-state agree on which ledger lines mark a task
  complete.

## Non-goals

- The residuals the human partner left out of scope: register's raw ledger
  read, merge records allowing a stop during conflict resolution, complete's
  `invalid` routing in the skill, the seven older here-strings, the two raw
  `Task N: merged` greps, handoff's split append, sync's check order,
  planless notes credited to the first plan, the label clash, and the
  state-suite runtime.
- Findings the triage marks fixed or not applicable (E6-c among them).
- Shallow-file ancestry and the state branch's own refs: the symbolic-ref
  check covers the integration ref and the plan ref only.
- Any change to using-git-worktrees.
- Live eval runs.

## Global constraints

- No dollar figures in any committed file or commit message.
- No Co-Authored-By line and no AI-attribution line in any commit.
- Before every commit: write `git diff --cached` to a file, run
  `python3 ~/.claude/scripts/realval-scan.py` on it, and expect `hits: 0`.
- Test-driven: every finding that changes behavior has at least one test
  assertion that fails at e62fdb5 because of the defect, run before the fix.
  Red runs use a `git archive e62fdb5` copy in scratch, never `git stash`.
  Testing below says how seam-driven tests run red and which tests are
  exempt.
- No new here-strings in `sdd-state`, `sdd-common.sh`, `hooks/` or
  `tests/` (this host has shown 512-byte pipes).
- Existing statuses and exit codes are reused; the only new outputs are the
  stderr lines this spec quotes.
- A commit that changes a source a `docs/site/` page lists in `sources:`
  re-reads that page, fixes stale text, and refreshes its `source-digest:`
  (`bash tests/docs/docs-check.sh --digest <page>`).
- CHANGELOG.md, Unreleased: one sentence per fix, in the existing bullets,
  in the commit that makes the fix.
- Skill-text edits are limited to the sentences section 6 and section 4
  name; the evidence note records their evaluation.
- One problem per commit.
- No live suites; the offline set from `docs/testing.md` runs unsandboxed at
  the end.

## Design

### 1. Final train (`sdd-state`)

**E5-a, a takeover after a killed finish.** `claim final --takeover` with
no ledger goes straight to `claim_final_orphan` (sdd-state:787-788). A
finish killed after its rename-aside leaves the workspace at
`plans/.removing-<ws>-<pid>`, which the other readers treat as an open plan
(sdd-state:395-400, :2057-2062); the orphan takeover then moves the lease of
a plan that is still open.

New behavior: the restore runs inside the loop that settles the plan line
and the locks (sdd-state:775-786), after `recover_apply` and before the
plan line is read again. When the task is `final`, `--takeover` was given,
and `progress.md` is missing, the claim runs finish's copy loop for its own
workspace (sdd-state:1827-1834). With `$WSDIR` free it restores the copy
with `restore_tomb`. The plan line read next is then the restored one, which
differs from the empty line the loop started with, so the loop releases the
lock and settles again with that plan line, the code repository and the
lock pair, as it already does when a plan line appears during a claim. The
claim then continues on the ordinary path: `claim_final`, a takeover of an
open plan, moves the final claim's owner and the lease to the caller. With
`$WSDIR` present (and no ledger in it) the claim prints finish's stderr line
(`a copy from an interrupted removal remains at ...`) and answers
`status=busy` (exit 3). A failed restore answers `status=error` (exit 2).
`claim_final_orphan` runs only when no copy exists.

Test: a workspace whose finish stopped after the rename-aside (a hand-made
`.removing-<ws>-<pid>` copy, or finish's existing crash seam if one sits
there), then `claim final --takeover` from another session: the workspace
is back at its path, the claim answers
`status=claimed task=final lease=<name> takeover=1`, `claims/final/owner`
names the caller, and the branch lease names the caller.

**E5-d, a damaged `closing=`.** Both takeover sites copy the replaced
lease's value with `[ "$lclosing" = 1 ] || lclosing=0` (sdd-state:724,
:769), so a missing or malformed value becomes 0 and reopens a branch whose
closing had begun. New behavior at both sites:
`[ "$lclosing" = 0 ] || lclosing=1`.

Test: a lease with no `closing=` line and one with `closing=yes`, each taken
over through each site: the new lease says `closing=1`, and a sibling
`register` on that branch answers `branch-closing`.

### 2. Amend (`sdd-state`)

Each attempt in `cmd_amend` reads the plan ref's head P, builds the commit,
runs `amend_wt_blocker` (a read-only dry run over every worktree with the
plan ref checked out), writes its record, swaps the ref with
`update-ref ... "$commit" "$P"`, and then runs `amend_refresh "$P" "$commit"`
(sdd-state:2222-2272).

**E6-a, a lost swap.** When another writer moves the ref, the loop re-reads
P and retries (sdd-state:2265-2271). A worktree with the plan ref checked
out was left at the old head by that writer, and `amend_refresh` brings only
the plan path from the new P to the commit, so the other writer's changes
stay staged as reverts there.

New behavior: when an attempt's `update-ref` fails and the ref has moved,
amend lists the worktrees on the plan ref again before it decides. It calls
`amend_ref_worktrees` in its own shell, not inside a command substitution:
`amend_wt_blocker` runs inside `wb=$(...)` (sdd-state:2246), so the list it
fills never reaches the caller. Listing after the failure also catches a
worktree that checked out the plan ref between the attempt's scan and the
swap. When that list (present or missing directories) is non-empty, amend
removes its record, unlocks, prints

    sdd-state: the plan ref <ref> moved during the amendment while <path> has it checked out; bring that worktree to the new head, then run the same amend again

and answers `status=checked-out worktree=<enc path>` (exit 13), naming the
first listed worktree. With the list empty it retries as today. A worktree
that checks out the plan ref after that listing gets the moved head, so the
retry's own scan covers it.

Tests: (a) the `amend-before-swap:<sha>` writer seam with a worktree on the
plan ref: exit 13 naming that worktree, the ref at the seam's commit, no
record left, and the worktree's index unchanged; (b) a test seam that adds
a worktree on the plan ref and then moves the ref, both after the scan and
before the swap: exit 13 naming the added worktree.

**E6-d, a missing worktree directory.** `amend_ref_worktrees` skips a
registered worktree whose directory is gone (sdd-state:2309), and that
worktree comes back later with the old plan staged against the new head.

New behavior: `amend_ref_worktrees` also collects those entries (git lists
them as prunable, or locked), and `amend_wt_blocker` returns the first one
as a blocker before it checks any other worktree. Amend answers
`status=checked-out worktree=<enc path>` (exit 13) before the swap, with

    sdd-state: the worktree <path> has the plan ref <ref> checked out but its directory is missing; restore it or run git worktree prune, then run the same amend again

For an entry git lists as locked, which `git worktree prune` leaves alone,
the line instead ends

    ... its directory is missing and the worktree is locked; restore it, or run git worktree unlock <path> and then git worktree prune, then run the same amend again

After the swap, `amend_refresh` treats a directory that disappeared as its
existing refresh error and keeps the record.

Tests: (a) a worktree on the plan ref whose directory is moved away: exit
13 naming it, the ref unmoved; after `git worktree prune`, the same amend
succeeds; (b) the same with the worktree locked first: exit 13 with the
locked line; `git worktree prune` alone leaves the amend refused; after
`git worktree unlock` and `git worktree prune`, it succeeds.

**E6-b, a deletion during the refresh.** `amend_refresh` checks
`amend_wt_plan_clean` and then runs `read-tree -m -u` (sdd-state:2365-2369).
`read-tree -m -u` takes a missing file for an unchanged one, so a deletion
between the two is written back.

New behavior, per worktree in `amend_refresh`, after the stat refresh:

1. Reserve an aside name by creating it exclusively in the plan file's
   directory (`mktemp` with the template `.<file name>.sdd-amend-XXXXXX`),
   then rename the plan file onto it with one `rename(2)`. The rename
   replaces only the empty file this run created, never an earlier run's
   copy. A rename that fails (the file is gone) removes the reserved name
   and is a refresh error naming the worktree.
2. Check the renamed copy against the index's one stage-0 entry for the
   plan path (`amend_wt_index`, "<mode> <blob>"): its type matches the mode
   (a symbolic link for `120000`, a regular file otherwise); a regular
   file's executable bit matches `100755` or `100644`; and its content
   hashes to the entry's blob, where a symbolic link hashes its target text,
   as git stores a link. With `core.fileMode` false the executable bit is
   not compared, as git itself ignores it then. Any mismatch is a refresh
   error.
3. Run `read-tree -m -u "$1" "$2"`. The path is empty, so git writes the
   new plan there.
4. On success, remove the renamed copy. When step 2 or step 3 fails, move
   the copy back with a rename that cannot replace a file (a hard link to
   the path, then removal of the copy) and return the refresh error. If a
   file was created at the path in the meantime, the copy stays, and the
   error names both paths.

The dry run before the swap stays read-only, as it is today.

Tests: (a) the plain refresh still leaves the new plan in the worktree and
no renamed copy behind; (b) a test seam that deletes the plan file just
before the rename: a refresh error, the record kept, and the file still
absent (not written back); (c) a test seam that creates a file at the path
after the rename: a refresh error naming both paths, the created file
untouched, and the copy kept; (d) a test seam that flips the plan file's
executable bit, and one that replaces it with a regular file holding a
symbolic link's target text where the index holds a link, each just before
the rename: a refresh error, and the changed file put back unchanged;
(e) a file already present at an earlier run's aside name stays untouched.

### 3. Records, board and session ids (`sdd-state`)

**E8-a, a directory swallows a record.** `record_publish` checks that the
destination is not a non-regular file and then runs `mv -f` (sdd-state:231-
232). A directory created between the two makes `mv` move the record inside
it and report success. New behavior: publish with node's `renameSync`, the
one-liner claim uses (sdd-state:877). `EISDIR`, `ENOTEMPTY`, `EEXIST` and
`ENOTDIR` give the existing "is not a regular file; refusing to replace it"
refusal; any other error returns 1. The pre-check stays, for its message. A
rename onto a symbolic link replaces the link, where `mv -f` followed a link
to a directory. Test: a test seam that creates a directory at the
destination after the pre-check: the caller answers `status=error`, and
nothing was written inside the directory.

**E8-f, the plain-backend snapshot.** `cmd_snapshot`'s plain path checks
`progress.md` and writes the activity stamp with no lock (sdd-state:440-
443); a finish removing the workspace in between leaves a recreated
`plans/<ws>/activity`. New behavior: the plain path takes
`hp_lock "$PLAN_DIR"` before the check and releases it after the stamp, as
the branch path does (sdd-state:446-453). Test: with the plan lock held by
another process that removes the workspace before it releases the lock, a
plain-backend `snapshot --session <sid>` started meanwhile leaves no
`plans/<ws>` directory behind.

**E8-b, fetched names on the board.** `board_entries` prints every entry
name in `waiting/` and `activity/` unvalidated (sdd-state:2678-2685), so a
fetched `waiting/a<LF>b` becomes two phantom sessions. New behavior:
`board_entries` skips a name `sid_ok` refuses; `sid_ok`'s own stderr line
names it with `%q`. Test: a `waiting/` entry named `a<LF>b`: the board
lists neither `a` nor `b` as a session.

**E8-d, session ids.** `sid_ok` refuses only an empty id, `.`, `..`, a slash
and control characters (sdd-state:208-212). An id holding `: mode ` splits
the ledger's session line and the board's parse of it. New behavior:
`sid_ok` also refuses whitespace and `:`, and its message says so:

    sdd-state: a session id must be one path entry without whitespace, a colon or control characters: <id as %q>

Claude Code session ids are UUIDs and the skill's fallback id is
`<epoch>-<digits>`, so no real id changes.
Test: `--session 'a b'` and `--session 'x: mode y'` are refused by
`register` and by `wait` (`status=error`, exit 2).

**E8-g, an empty `--session` on snapshot.** `cmd_snapshot` validates the id
only when it is non-empty (sdd-state:435), so `--session ''` skips the check
and the stamp and succeeds. New behavior: a given `--session` is validated
whatever its value; an empty one answers `status=error` (exit 2). Test:
`snapshot --session ''` exits 2.

**E8-e, the conflict path's stamp.** merge-back's conflict path writes the
waiting record (sdd-state:2510) but no activity stamp, unlike `wait`
(sdd-state:2663-2664). New behavior: `write_activity "$sid"` after
`merge_back_wait`. A failure unlocks, prints

    sdd-state: merging <sha7> into <integration> conflicts in <paths>, and the waiting record was written, but the activity stamp could not be

and answers `status=error` (exit 2). A retry of the same merge-back finds
the same conflict and writes both again. `wait` keeps its current failure
output. Tests: after a conflict, `activity/<sid>` holds a stamp from this
run; with the activity path blocked (a directory where the stamp goes), the
conflict answers `status=error` with that line, and the waiting record
exists.

### 4. Raw objects, symbolic refs and the approval line

**E7-a and E7-c, replace objects and grafts.** `review-package` reads
through replace refs while merge-back does not (only merge-back sets
`GIT_NO_REPLACE_OBJECTS`, sdd-state:2393), so reviewers can be shown a
replacement while the original merges. Neither neutralizes grafts, which can
fake ancestry and turn a divergent merge into a fast-forward that drops
integration-only content. New behavior: `review-package` exports
`GIT_NO_REPLACE_OBJECTS=1` and `GIT_GRAFT_FILE=/dev/null` before its first
git call; `cmd_merge_back` adds `local -x GIT_GRAFT_FILE=/dev/null` beside
its existing replace setting, and the comment there covers both. Tests: a
`git replace` of the task head leaves the review package showing the
original commit's diff; an `info/grafts` entry that gives a task commit a
false parent leaves the review package listing the commits and diff of the
real history, so a package built without the graft setting fails it; an
`info/grafts` entry that grafts the task head onto the integration head
does not turn a divergent merge-back into a fast forward (the published
commit has both parents, and integration-only content is kept).

**E7-b, the approval line.** The controller writes `Task <N>: approved
<sha7>`, and merge-back resolves the seven characters among the objects
present (sdd-state:2439-2460); when the reviewed commit is absent and one
colliding commit is present, merge-back publishes it. New behavior:

- The line is `Task <N>: approved <full id>`, the id the reviewers saw.
- merge-back reads approval lines through `ledger_records`, which drops a
  fragment (`#fragment`) and an unterminated last line, instead of grepping
  the raw ledger as it does today (sdd-state:2439); a ledger that cannot be
  read answers `status=error` (exit 2). An interrupted approval write
  therefore never authorizes a merge.
- merge-back resolves `--commit` to its full id first, and the id width W
  is that id's length (40 in a SHA-1 repository, 64 in a SHA-256 one). It
  takes the newest record matching
  `^Task <N>: approved [0-9a-f]{W}([^0-9a-f]|$)` and compares its id, whole,
  with the full id. A token of the other width matches nothing, so a
  40-digit prefix in a SHA-256 repository reads as no approval. Equal
  merges; unequal answers
  `status=not-approved approved=<first seven of the line's id>` (exit 12);
  no matching line answers `status=not-approved approved=none` (exit 12).
- A seven-character line matches nothing, so it reads as no approval. The
  skill's existing `not-approved` route appends the full-id line. A ledger
  in flight at upgrade costs one re-append per open task; the CHANGELOG
  says so.
- The `--disambiguate` loop and its "cannot be resolved" error go.

Tests: a seven-character line gives `approved=none`; the commit's full id
merges; another commit's full id gives `approved=<its seven>`; a 41-digit
token gives `approved=none`; in a repository made with
`git init --object-format=sha256`, a 40-digit prefix of the commit's id
gives `approved=none` and the 64-digit id merges; a full-id approval line
that is the ledger's unterminated last line, and one that ends in a
`#fragment` marker, each give `approved=none`. The existing seven-character resolution tests
(the ambiguous-token and ref-shadow cases, tests/sdd/test-sdd-state.sh near
:4600-4630) are replaced by these, and every fixture that writes an approval
line writes a full id.

Skill text in the same commit, so the text and the script never disagree on
any commit: the SDD SKILL.md bullet at :790-796 says to append
`Task <N>: approved <full id>` written with `git rev-parse <head>`, that
every later approval appends a new line and the newest merges, and that
merge-back compares the whole id, so a shortened id reads as no approval;
the `cut -c1-7` instruction goes. The `not-approved approved=<sha7|none>`
sentence at :806 keeps its form. `example-workflow.md` (:40, :78) shows
full-length ids. `docs/site/advanced/sdd-internals.md` (:43, :61) says
`approved <full id>`. `tests/sdd/test-sdd-contract.sh:471` pins the new
line and a needle for "a shortened id reads as no approval".

**E7-d, symbolic refs.** `update-ref` dereferences a symbolic ref, so a
symbolic integration ref makes merge-back move the branch it points to; the
same holds for amend's plan ref. New behavior: `cmd_merge_back`, under its
locks and before any write, refuses when
`git -C "$code" symbolic-ref -q refs/heads/<integration>` succeeds:

    sdd-state: the integration branch <integration> is a symbolic ref; merge-back writes only a branch that holds a commit

and `status=error` (exit 2). `cmd_amend` refuses the same way for the plan
ref in the plan repository (`... the plan ref <ref> is a symbolic ref; amend
writes only a branch that holds a commit`). Both `update-ref` calls
(sdd-state:2257, :2526) gain `--no-deref`, so a ref made symbolic after the
check is overwritten as itself and the branch it pointed to never moves.
The check runs in each attempt, before that attempt's swap.

Tests: (a) a symbolic integration ref pointing at another branch makes
merge-back exit 2 and leaves that branch unmoved, and the same for amend's
plan ref; (b) test seams `merge-back-symref-before-swap:<branch>` and
`amend-symref-before-swap:<branch>` turn the ref into a symbolic ref to
`<branch>`, after the check and before the swap, where `<branch>` holds the
swap's expected old commit (so the compare-and-swap's old-value test
passes): after the call, `<branch>` is unmoved.

### 5. Single findings

**E1, `deps --from`.** `cmd_deps` hashes the caller's file and then parses
it again for the graph and the overlaps (sdd-state:292-307), so a concurrent
edit pairs one `plan=` with another graph or a false `clean`. New behavior:
copy `--from` once to a private temporary file, hash and parse only that
copy, and remove it on every exit. Test: a test seam that rewrites `--from`
after the copy: the output's `plan=` and graph both describe the copied
text.

**E2, register's code root.** `register` records `code_root` from the code
checkout's HEAD (`root_of "$code"`, sdd-state:349; `root_of` at :4082). A
checkout on an unrelated-root history records the wrong root, and later
calls answer `wrong-repo`. New behavior: `root_of` takes an optional
revision (HEAD by default), and `register` passes
`refs/heads/<integration>` when that ref resolves in the code repository,
HEAD otherwise. Test: a code repository with two unrelated roots, the
checkout on the unrelated-root branch, `register --integration <branch>`:
the plan line records the integration branch's root, and `verify` from a
checkout of the integration branch answers `ok`.

**E3-c, the claim's code repository.** `claim_take_locks` runs
`code_repo_arg` only when there is a plan line or a `--code-repo`
(sdd-state:535-547). New behavior: it runs `code_repo_arg` on every path, so
a claim without a plan line checks the current directory's repository as
other subcommands do. Test: a claim in a workspace with no plan line, from a
directory outside any repository and without `--code-repo`, answers what
`next` answers there (same status and exit).

**E3-f, the takeover crash seam.** The fresh claim path has a
`claim-after-rename` crash seam (sdd-state:880); the takeover path's owner
rename (sdd-state:863) has none. New behavior: a
`HYPERPOWERS_TEST_CRASH_AT=claim-takeover-after-rename` seam right after
that rename. Test: session B, with a `tasks` waiting record posted, takes
over task 2 from A and crashes at the seam (exit 99); the record is still
there; B's retry answers `status=held ... own=1` and the record is gone.

**E4, a word for a task number.** The plan parser rejects digit headings at
the wrong level or spacing (sdd-common.sh:278-279), but a level-3 heading
`### Task One:` is ignored, so the task silently drops out of the graph, and
so are `### Task:` and a bare `### Task`. New behavior: a level-3 heading
that is `### Task` followed by the line end, by optional whitespace and a
colon, or by whitespace and a character that is not a digit
(`/^### Task([ \t]*(:|$)|[ \t]+[^0-9 \t])/`) is a malformed task heading,
exit 2, and `deps` answers `status=invalid`. Tests: `### Task One: x`,
`### Task: x` and `### Task` each give `status=invalid`; `### Tasks overview`
and `### Task-runner notes` still parse.

**`enc`, one-line output.** `enc` escapes only the space (sdd-state:126), so
a worktree path with a newline breaks the one-line status it appears in.
New behavior: `enc` escapes bytes 0x01-0x1F and 0x7F as `%XX` (uppercase
hex) and the space as `%20`, and leaves `%` and every other byte unchanged,
so every value without a control character prints exactly as today. Test:
a worktree path holding a newline appears in its status line as `%0A` and
the line stays one line; a path with a space still shows `%20`; a path with
`%` is unchanged.

**E12 medium, the takeover fixture.** The fixture at
tests/sdd/test-sdd-state.sh:3510-3511 asserts that the task branch's
merge-base with the integration branch is the claim's `from=`. After the
conflict route merges the integration branch into the task branch, the
merge-base is the integration head merged in. New: a conflict-route variant
asserts that merge-base and that `BASE..HEAD` still lists the previous
holder's commit.

### 6. Skill text, stop guard and the evidence note

Each edit below is pinned by a needle in `tests/sdd/test-sdd-contract.sh`
(it covers both skills), and the contradicted phrase is asserted absent
("never refuses it", the unqualified `git merge-base HEAD <integration
branch>`, "so the task is not claimed").

- SDD SKILL.md:417, BASE: `git merge-base HEAD refs/heads/<integration
  branch>`, so a tag with the branch's name cannot be read instead. The
  takeover sentence adds that after the conflict route merged the
  integration branch in, BASE is that merged head; the previous holder's
  commits stay in the review package either way.
- SDD SKILL.md:487-489, claim's `error`: a read or a write failed, and the
  claim may already have been published; only your own retry of the same
  claim (which then answers `held own=1`) or a takeover clears it. Stop,
  show the stderr line, and retry the same claim once its cause is fixed.
  `sync` is still not the answer.
- SDD SKILL.md Setup, the opening paragraph at :133-139 (E11-b): its first
  sentence, "Settle where the work happens first: use
  hyperpowers:using-git-worktrees, ...", is rewritten so one read comes
  before it: run the `sync` and `sdd-dir` steps below and read the ledger's
  plan line, which only reads, then settle where the work happens with
  using-git-worktrees. When the plan line names an integration branch, this
  is a later session, and you hand using-git-worktrees that branch and your
  session id. The rest of the paragraph (the main/master consent rule) is
  unchanged. using-git-worktrees' manual fallback already names that case
  (using-git-worktrees/SKILL.md:112-123), so that skill does not change.
  The ledger bullet below keeps creating the ledger and appending the
  session line after the worktree is settled, since the session line
  carries the mode using-git-worktrees reports.
- Finishing SKILL.md:101-104, Step 1 item 5: "and never refuses it" becomes
  the compiler's three refusals for a spec another plan finished first:
  this plan has the file name of a plan the spec already records; notes
  from a finish without a plan would replace notes plans wrote; this plan's
  notes would replace notes a finish without a plan wrote. Each exits 2 and
  writes nothing; show the stderr line and stop.
- Finishing SKILL.md:268-277, plans that share the integration branch: the
  withheld-merge line replaces option 1 only in a menu that offers a merge.
  The two-option menus (mode `current-branch` on the default branch, and a
  detached HEAD) have no merge option and are shown unchanged; a pull
  request's description still says another plan is open on the branch.

**Stop guard.** `COMPLETE` in hooks/lib/stop-guard.mjs:15 matches
`(^|[^A-Za-z0-9])Task N: complete` anywhere in a line. New behavior: the
guard exports `completePattern(n)`, the JS form of sdd-state's pattern:

    ^[ \t\v\f\r]*([-*][ \t\v\f\r]+)?(\*\*|__|\*|_)?Task N: complete(\*\*|__|\*|_)?([ \t\v\f\r(.,]|$)

The shell pattern moves into sdd-common.sh as `hp_complete_ere N` (it
prints the ERE); `ledger_marks_complete` uses it and runs its grep under
`LC_ALL=C`, so `[[:space:]]` means the ASCII set the JS class lists. A
parity test in tests/hooks/test-sdd-stop-guard.sh runs both over the same
lines for task 1 and asserts each matches the expected column:

| line | counts |
|---|---|
| `Task 1: complete (commits 1111111..2222222, review clean)` | yes |
| `- Task 1: complete (commits 1111111..2222222, review clean)` | yes |
| `* Task 1: complete` | yes |
| `**Task 1: complete**` | yes |
| `__Task 1: complete__` | yes |
| `*Task 1: complete*` | yes |
| `_Task 1: complete_` | yes |
| `Task 1: complete.` | yes |
| `Task 1: complete,` | yes |
| `Task 1: complete` followed by a tab and `(x)` | yes |
| `Task 1: complete` followed by a carriage return | yes |
| a vertical tab, then `Task 1: complete` | yes |
| a form feed, then `Task 1: complete` | yes |
| `-Task 1: complete` | no |
| `> Task 1: complete (quoted)` | no |
| `Task 1: complete-not-yet` | no |
| `Task 1: completed` | no |
| `Task 10: complete` | no |
| `see Task 1: complete` | no |

The guard stops counting a mention in the middle of a line, which it counts
today.

**Evidence note.** `docs/hyperpowers/2026-11-08-sweep-fixes-skill-text-reachability.md`
lists each skill-text edit with its file, line and needle. It lists the
sentinel scenarios (`quorum_tier: sentinel`) at the evals commit it was
written against and, for each, whether its story or setup leads a session to
read SDD SKILL.md or finishing SKILL.md before its reading settles, citing
the story lines. `triggering-finishing-a-development-branch` settles at the
skill invocation, before the body is read, by its acceptance criteria. The
worktree sentinels read only using-git-worktrees, which does not change.
The note cites no run transcripts: the repository rule requires a cited
transcript to be copied into hyperpowers-evals' `evidence/` first, and no
runs are made. It says plainly that the transcript evidence
`evals/docs/scenario-authoring.md` §5 asks for is therefore not on file, so
a sentinel failure in these scenarios after this change is re-measured, not
argued away. The note states that no live runs were made, by decision.

## Testing

- Red runs: every finding that changes behavior has at least one assertion
  that fails at e62fdb5 because of the defect, and the red run is reported
  with the task. A test that drives a test seam this work adds
  (`HYPERPOWERS_TEST_WRITER_AT`, `HYPERPOWERS_TEST_CRASH_AT` or another
  hook) runs red against the e62fdb5 copy with only the seam's lines
  applied, the same lines the fix keeps, and nothing else. Each seam-driven
  test asserts that its seam fired (the seam leaves a marker the test
  checks), so a seam that never ran cannot pass or fail a test by accident.
  Exempt from the red requirement: positive controls (a canonical
  completion line still counts, `### Tasks overview` still parses, a plain
  refresh still writes the new plan, a full id still merges) and test-only
  changes (the E12 conflict-route fixture, and the E3-f seam's own test,
  whose subject is the new seam). The task report names each exempt test
  and its reason.
- Per task: the new tests and their neighbours as state-suite slices. The
  plan supplies a slice runner that takes both the test body
  (`tests/sdd/test-sdd-state.sh`) and the scripts from the tree under test:
  the branch worktree for green runs, the `git archive e62fdb5` copy for
  red runs (with the new test bodies copied in). The earlier runner at
  `~/.cache/hyperpowers/merge-minors/probes/run-slices.sh` reads its test
  body from a fixed checkout that no longer exists, and is not used. Also
  per task:
  `tests/sdd/test-sdd-contract.sh`, `tests/hooks/test-sdd-stop-guard.sh`,
  `tests/hooks/test-no-heredocs-in-hooks.sh`, `tests/docs/docs-check.sh`,
  `bash -n` on each changed script, and `tests/shell-lint/test-*.sh` where
  present. Suites write to log files, never into a pipe.
- At the end, the offline set from `docs/testing.md`, unsandboxed, the full
  state suite included.
- No live suites and no live eval runs.

Tasks, in order:

1. Final train (section 1). Risk tier high: concurrency and the lease.
2. Amend (section 2). High: concurrency and worktree writes.
3. Records, board and session ids (section 3). High: record writers and
   locking.
4. Raw objects, symbolic refs and the approval line (section 4), code and
   skill text together. High: approval-authority code.
5. Single findings (section 5). High: claim and register are concurrency
   code.
6. The remaining skill text, the stop guard and the evidence note (section
   6). Standard.

## Decisions

- **The approval line carries the full commit id.** merge-back compares the
  whole id, and a shortened id reads as no approval. Rejected: resolving the
  seven characters only among the task branch's commits, because a planted
  collision on the branch stays possible; an `sdd-state approve` helper,
  because it adds a subcommand for a line the controller already writes and
  the skill text changes either way. Accepted cost: a ledger in flight at
  upgrade re-appends one line per open task.
- **Amend refuses after a lost swap while a worktree has the plan ref
  checked out.** Rejected: reconciling that worktree from its pre-race head,
  because amend would then write paths outside the plan on another writer's
  behalf; documenting the race as a limit.
- **A registered worktree with a missing directory blocks an amendment.**
  The refusal says to restore it or prune it. Rejected: skipping it, because
  it comes back with the old plan staged against the new head. Accepted
  cost: a stale registration blocks amend until it is pruned.
- **The refresh moves the plan file aside before it checks and writes it.**
  A deletion then either fails the rename or finds no file. Rejected:
  documenting the window; holding the worktree's index lock across the
  check, because `read-tree` takes that lock itself.
- **A final-train takeover restores a killed finish's copy first.** The
  takeover then runs as one of an open plan. Rejected: refusing, because the
  session taking over cannot run finish without the train.
- **A damaged `closing=` reads as closing.** Only an exact `0` keeps the
  branch open. Rejected: refusing the takeover, because a damaged file would
  then leave the final train stuck. Accepted cost: sibling plans wait until
  the finish removes the lease.
- **Records publish with one `rename(2)`, and the plain snapshot stamps
  under the plan lock.**
- **Session ids exclude whitespace and colons, and the board skips names
  that are not session ids.**
- **Reviewers and merge-back read raw objects without grafts, and symbolic
  integration and plan refs are refused.** The careless-model framing of
  2026-10-14 still holds; these checks are cheap and close paths the
  reviewers found.
- **`enc` escapes control characters and leaves `%` alone.** Rejected: a
  reversible encoding that escapes `%` first, because it would change
  existing outputs that hold `%`; these fields are displayed, not compared
  as keys, which is what the reversible-encoding record covers.
- **The stop guard and sdd-state share one completion pattern, held by a
  parity test.** The guard stops counting mid-line mentions.
- **A later session reads the plan line before it settles its worktree;
  using-git-worktrees does not change.** Rejected: editing
  using-git-worktrees, which two sentinel scenarios read.
- **The skill-text edits are evaluated by contract needles and a
  reachability note.** Rejected: a new later-session scenario run live
  against main and the branch; writing-skills pressure tests for every edit.
  Four of the edits make the text match what the scripts already enforce,
  and a misreading meets a script refusal.
- **One spec, one branch, six tasks.** Rejected: a code spec followed by a
  skill-text spec; one branch per group.

## Assumptions

- Assumption: `GIT_GRAFT_FILE=/dev/null` makes git ignore `info/grafts`.
  Probed 2026-11-08 with git 2.56.0: a grafted commit's real parents came
  back. Validate via the graft test in task 4.
- Assumption: `update-ref --no-deref` on a symbolic ref replaces the
  symbolic ref and leaves its target. Probed 2026-11-08 with git 2.56.0.
  Validate via the symbolic-ref test in task 4.
- Assumption: node's `renameSync` of a file onto a directory fails with
  `EISDIR` (node 26.13.0, macOS). Validate via the record test in task 3.
- Assumption: `read-tree -m -u` writes the new blob into a tracked path
  whose file is missing and whose index entry is the old blob (the comment
  at sdd-state:2341-2343 says it does). Validate via the refresh test in
  task 2.
- Assumption: `git worktree list --porcelain -z` keeps listing a worktree
  whose directory is gone. Validate via the missing-directory test in
  task 2.
- Assumption: no ledger on this host carries a session id with whitespace
  or a colon. Validate via a grep of the session lines under
  `~/.cache/hyperpowers/state/` before task 3.
