# Portable SDD Dossiers Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md` (approved 2026-10-20; the five decisions the human partner took on 2026-10-23 after the plan's hand-back are written into it by Task 1 and bind every later task).

**Goal:** Close the decisions and residuals left by the portable-dossiers hand-back: the fetch stamp binds to the remote and branch it fetched, the import keeps a dated copy of the legacy workspace, every subcommand prints a status line when the state checkout cannot be created, `sdd-dir` stops adding a generic failure line after a specific refusal, the library's messages carry the calling tool's name, the post-ref containment failure says how to repair it, and `prune` lists and removes the copies killed removals left behind.

**Architecture:** Every change is inside the existing helper (`sdd-state`), its library (`sdd-common.sh`) and `sdd-dir`, with the spec amended first so the stdout grammar and the records compiler have their text before any code moves. No new file, no new subcommand, no new seam variable. The `prune` stdout grammar gains one field (`tombs=`) and the fetch stamp file gains content (`<remote> <branch> <fingerprint>`, where it was empty); nothing else observable changes shape.

**Tech Stack:** bash 3.2 (macOS), git 2.56, node (already required by the helper), the repository's bash test suites.

## Global Constraints

- Branch and worktree: hyperpowers branch `portable-sdd-dossiers-follow-ups` in `.worktrees/portable-sdd-dossiers-follow-ups`, from `main` at `d7d6883` or later. No commit lands on `main` during the plan.
- Commit messages state the problem solved. No attribution line of any kind (no `Co-Authored-By`, no tool name). Before every commit: `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` must print `hits: 0`.
- bash 3.2 compatible: no associative arrays, no `${var,,}`, no `mapfile`; BSD `sed -i ''`; BSD `mv` nests a directory into an existing directory of the same name, so every rename checks its destination first. `sdd-dir` runs under `set -euo pipefail`: a command whose failure is handled is written `rc=0; cmd || rc=$?`.
- Quick suites, run from the worktree root, one per `bash` call, each ending `STATUS: PASSED`: `bash tests/sdd/test-sdd-common.sh`, `bash tests/sdd/test-sdd-contract.sh`, `bash tests/claude-code/test-sdd-dir-path.sh`. Lint every changed shell file with `bash scripts/lint-shell.sh <files>` (exit 0, no findings). Never run anything else under `tests/claude-code/`: those suites start real `claude` sessions.
- The state-suite procedure. `tests/sdd/test-sdd-state.sh` takes about 15 minutes and has no section filter, so it is never piped into `grep` (the pipeline's status would be grep's). It runs in the background to a log and is waited for: `bash tests/sdd/test-sdd-state.sh > ~/.cache/hyperpowers/follow-ups-task<N>-<red|green>.log 2>&1; echo "suite rc=$?" >> ~/.cache/hyperpowers/follow-ups-task<N>-<red|green>.log`. GREEN means the log's last line is `suite rc=0`, `grep -c '\[FAIL\]' <log>` prints `0` and `grep -q 'STATUS: PASSED' <log>` succeeds; one GREEN run per task, at its end. RED means the log holds the new assertion's `[FAIL]` line with the reason the step predicts. A RED run may instead use an extracted harness: copy the suite's lines 1-67 (its helpers) plus the section under test into a script under `$TMPDIR`, repoint `REPO_ROOT`, and run that; the report says which form was used. Where a step below says "state suite, needle `<text>`", it means this procedure with that `[PASS]`/`[FAIL]` text.
- Test seams in the helper: `HYPERPOWERS_TEST_CRASH_AT`, `HYPERPOWERS_TEST_PAUSE_AT`, `HYPERPOWERS_TEST_WRITER_AT`, `HYPERPOWERS_TEST_DEST_APPEND`, `HYPERPOWERS_TEST_LATE_APPEND`, `HYPERPOWERS_TEST_LATE_REPLACE`, `HYPERPOWERS_TEST_FAIL_RELINK`, `HYPERPOWERS_TEST_FAIL_WORKTREE_ADD`, `HYPERPOWERS_TEST_SWAP_REF`, `HYPERPOWERS_TEST_RECLAIM_RACE`. No task adds a seam variable. Task 2 adds the value `import-after-set-aside`, Task 6 the value `restore-after-copy` and Task 7 the value `prune-after-stage` to `HYPERPOWERS_TEST_CRASH_AT` (every crash seam exits 99 after `hp_unlock`, as the existing ones do); Task 2 adds the value form `touch:<root>` to `HYPERPOWERS_TEST_RECLAIM_RACE` (touch the root only, no `.importing-*`); the final-review fix wave adds the value form `occupy:<root>` to the same seam (the `.importing-*` race, with `<key>` recreated and holding a file, so the put-back meets an occupied destination); Tasks 4, 6 and 7 add the values `materialize-before-publish:<ws>`, `sync-after-ref-link:<path>`, `sync-after-apply-link:<path>`, `sync-before-restore:<path>`, `prune-after-tomb-rename:<name>`, `prune-reoccupy-tomb:<name>`, `sync-after-fetch-set-url:<url>`, `sync-aba-fetch:<url>` and `sync-shadow-alias:<url>` (Task 8) to `HYPERPOWERS_TEST_WRITER_AT`, each one `case` line at the point it names, in the form of the existing `sync-before-apply:` and `finish-before-remove-link:` values (`sdd-state:634` and `:1054`). The final Codex gate's round-1 fix wave adds `sync-link-restore:<path>` (inside `apply_files`, right before the write-time link check that precedes the restore sidecar's `mkdir`: the sidecar is replaced by a link to `<path>`) and `sync-after-fetch:<sha>` (right after the pinned fetch returns and before the fetched tip is read: `refs/remotes/<remote>/<branch>` is moved to `<sha>`) to `HYPERPOWERS_TEST_WRITER_AT`, and the value form `gone:<quarantine>` to `HYPERPOWERS_TEST_RECLAIM_RACE` (phase two of the reclaim, right after the `.gone-<pid>` rename: the staged tree is touched and `<quarantine>` is recreated holding a file, so the put-back meets an occupied destination). The final gate's round-2 fix adds `sync-after-url-read:<url>` to `HYPERPOWERS_TEST_WRITER_AT` (right after the single read of the remote's URL: the remote is repointed to `<url>`, and back to the captured URL right after the fetch returns). The final gate's authorized fourth round adds `sync-aba-rewrite:<url>` to `HYPERPOWERS_TEST_WRITER_AT` (right after the endpoint probe: `url.<url>.insteadOf` is configured in the repository with the probed endpoint as its value; the entry is removed right after the fetch returns).
- Tests use the suite's own helpers (`pass`, `fail`, `make_repo`, `make_pair`, `run_state`, `run_sdd_dir`, `ensure`, `state_key`, `ws_path`, `TEST_ROOT`, `STATE_ROOT`, `SDD_STATE`) and never touch the real `~/.cache`: `XDG_CACHE_HOME` is pinned by every suite. A new assertion is one `if ... then pass "..."; else fail "... (got: ...)"; fi` line in the suite's style.
- Message prefixes: after Task 5 every message the library prints starts with `$HP_PROG:`; `sdd-state` and `sdd-dir` keep their own literal prefixes for the messages they print themselves.
- The fetch stamp today: `sync` writes an empty `<key>.fetched` and `hp_ensure_checkout` tests its existence only (`sdd-common.sh:503`, `sdd-state:1211-1233`). Decision 1 is therefore new code (Task 8), not a description of what exists; Task 1 writes the spec text it will satisfy.
- No skill text changes: this plan edits no `SKILL.md`; the behaviour it adds is recorded in the spec and the changelog, so the repository's skill-evaluation rule is not engaged. A sentence a task would have liked to add to a skill becomes a hand-back item instead.
- Risk tiers: every code task below is `high`. The rubric puts durable-record writers, locking and recovery logic there, and the tier changes nothing at execution except that no task may skip its Codex gate.
- No live evidence is produced by this plan: every change is covered by the offline suites, so no evals evidence directory is needed. The record of each task is its suite output quoted in the implementer's report.
- Finish: the installed plugin predates decision records, so Finish runs main's compiler by hand from the worktree: `bash skills/finishing-a-development-branch/scripts/decisions-compile docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md --plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md --dry-run` must report nine decisions before the real run; the records commit removes this plan file from the tree (the spec stays). The spec must be committed and clean before the compile.
- Out of this plan, carried to the hand-back: the composition wedge of a journaled ledger rewrite (a writer's line between the two parts) still ends `status=error` with the marker kept and no repair text; its path runs through `ledger_apply`'s retryable `return 5`, so a repair message there would misdiagnose ordinary contention, and the fix needs a recovery-only result code, which belongs with the sidecar relocation design.

## Grounding

- Naming and message style: `skills/subagent-driven-development/scripts/sdd-state:981-983` (a refusal names the path, says what is refused, then what to do) and `skills/subagent-driven-development/scripts/sdd-common.sh:445-456` (`hp_verify_checkout`: one sentence, the remedy in the same line).
- Error handling and stdout grammar: `skills/subagent-driven-development/scripts/sdd-state:93-104` (`cmd_snapshot`: `status=` tokens are the only stdout, `return 2` after `status=error`, `hp_unlock` before every return under the lock).
- Lock discipline: `skills/subagent-driven-development/scripts/sdd-state:686-690` (`cmd_prune` takes the lock before selection with `--apply` and revalidates each candidate before removal).
- Rename-aside, verify, then delete, with the copy restored on any doubt: `skills/subagent-driven-development/scripts/sdd-state:533-592` (`discard_tomb`, `remove_verified`, `restore_tomb`).
- Crash seams and their tests: `skills/subagent-driven-development/scripts/sdd-state:1003` (`recover-after-update-ref`, `hp_unlock; exit 99`) and `tests/sdd/test-sdd-state.sh:925-940` (a `sync` killed by `HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref`, then a plain `sync` recovers).
- Test shape, state suite: `tests/sdd/test-sdd-state.sh:1309-1326` (p11: `make_pair`, `run_state`, `run_sdd_dir`, one `if ... pass/fail` per assertion, stderr captured to `$TEST_ROOT/<name>.err` when a message is asserted).
- Test shape, library suite: `tests/sdd/test-sdd-common.sh:1-40` (sources the library, `pass`/`fail` helpers, `TEST_ROOT`, `make_repo`).
- Test shape, sdd-dir suite: `tests/claude-code/test-sdd-dir-path.sh:1-30` (`set -euo pipefail`, `XDG_CACHE_HOME` pinned, `STATE_ROOT`).
- Prune output assertions to extend: `tests/sdd/test-sdd-state.sh:793-802` (full-string comparisons of `status=listed ...` and `status=pruned ...`).
- Import fixture to mirror: `tests/sdd/test-sdd-state.sh:449-462` (i1: `$i1`, `$wsi`, `$legacy_i1`; the source ledger's first line is the absolute form `# SDD ledger — plan: $i1/docs/plan.md`, the destination's is rewritten to `# SDD ledger — plan: docs/plan.md`; `status=moved from=<path>`; the pointer checked with `-L`).
- Needs-sync fixture to mirror: `tests/sdd/test-sdd-state.sh:106-111` (`make_pair p1`; `ensure "$PAIR_A"` exits 2 with `needs-sync`; line 109 then writes the stamp by hand).
- Liveness of a pid: `skills/requesting-code-review/scripts/broker-health:83-91` (node `process.kill(pid, 0)`; ESRCH is the only death signal, EPERM means the process exists).
- Decisions list grammar the compiler reads: `skills/finishing-a-development-branch/scripts/decisions-compile:647-660` (the first level-two heading containing "decision" opens the list; each top-level bullet is one record; its first sentence becomes the title).
- Spec sections touched: `docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md:70-92` (Decisions), `:148-156` and `:286-292` (the fetch stamp), `:462-476` (import), `:483-490` (prune), `:902-925` (Known limits), `:955-970` (Follow-ups).
- `none: no existing pattern for a per-caller message prefix in the library` (Task 5 introduces `HP_PROG`; the closest precedent is the per-file literal prefix, `sdd-common.sh:208` and `:445`).

---

### Task 1: The spec records the five decisions and the changed behaviour

**Risk tier:** low — single-file documentation edit; every sentence to write is in this task.

**Files:**
- Modify: `docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md:70-92` (Decisions), `:148-156` and `:286-292` (stamp), `:462-476` (import), `:483-490` (prune), `:902-925` (Known limits), `:955-970` (Follow-ups)

**Interfaces:**
- Consumes: nothing.
- Produces: the binding text for Tasks 2, 3, 6, 7 and 8: the import keeps `<source>.imported-<UTC>-<pid>`; `prune` prints `tombs=`; the stamp records `<remote> <branch> <fingerprint>` and creation requires an exact match; the writer race is a known limit.

- [ ] **Step 1: Append the five decisions**

After the last bullet of `## Decisions taken with the human partner` (the one beginning "The four design sections were approved as presented in chat.", which ends at line 92), add these five bullets, each one paragraph. The first sentence of each is the record's title, so keep it as written:

```markdown
- The fetch stamp records the remote and the branch it fetched. Creation of
  an orphan branch requires an exact match, so a changed
  `hyperpowers.stateRemote` or `hyperpowers.stateBranch` means a fresh
  `sync` before any branch is invented; the per-key boolean the spec first
  described would have let a stale stamp vouch for a remote it never
  checked. Decided 2026-10-23 at the hand-back.
- A verified import keeps the legacy workspace as a dated copy. The source
  is renamed to `<source>.imported-<UTC>-<pid>` beside the pointer rather
  than deleted: a session on the previous plugin that still holds the legacy
  ledger open appends into that copy, where a human can find the line, and
  the plain-cache reclaim takes the copy with its root after 14 idle days.
  Decided 2026-10-23 at the hand-back.
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
```

- [ ] **Step 2: The stamp paragraphs**

Replace, at lines 149-151, the sentence fragment `or when `sync` has recorded a fetch outcome for this key (the\nstamp file `<key>.fetched`, written on every outcome except `offline`).` with:

```markdown
or when `sync` has recorded a fetch outcome for this key (the
stamp file `<key>.fetched`, holding the remote and the branch it fetched,
written on every outcome except `offline`; creation requires the stamp to
name the configured `hyperpowers.stateRemote` and `hyperpowers.stateBranch`
exactly, so a changed remote or branch, or an empty stamp from before
6.17.0, means a fresh `sync`).
```

At lines 288-290, replace `writes the\n`<key>.fetched` stamp on every outcome except `offline` and\n`offline-no-state`,` with:

```markdown
writes the
`<key>.fetched` stamp (`<remote> <branch>`) on every outcome except
`offline` and `offline-no-state`,
```

- [ ] **Step 3: The import paragraph**

At lines 470-471 replace `and only after a clean verification remove the source directory\nand put a symlink to the new workspace in its place` with:

```markdown
and only after a clean verification set the source aside as
`<source>.imported-<UTC>-<pid>` beside its own location and then put a
symlink to the new workspace in the source's place (the copy is kept for a
writer of the previous plugin that still holds the old ledger open; the
plain-cache reclaim takes it with its root once nothing under that root is
newer than 14 days; an import interrupted between those two steps leaves the
kept copy and no pointer, and the next import completes the relink and
prints `status=moved`)
```

- [ ] **Step 4: The prune paragraph**

Read lines 483-490 (the paragraph beginning `**`prune [--days N] [--apply] --repo REPO_DIR`.**`). After its sentence ending `(`status=listed ...`).` insert:

```markdown
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
```

- [ ] **Step 5: Known limits and Follow-ups**

Append to `## Known limits` (after the last bullet, line 925):

```markdown
- A controller that opened `progress.md` before `finish`'s rename-aside and
  writes after the verification loses that line. `finish` runs when the
  plan is complete, by the controller that owns it, so this needs a second
  session writing to a finished plan; the lock-sharing write helper that
  would close it is scheduled with the sidecar relocation (Follow-ups).
```

In `## Follow-ups`, replace the whole `BACKLOG "Stale brokers"` bullet (lines 959-965) with:

```markdown
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
```

- [ ] **Step 6: Verify the compiler reads nine decisions and the needles are present**

Run:

```bash
bash skills/finishing-a-development-branch/scripts/decisions-compile docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md --dry-run | head -n 1
grep -c 'imported-<UTC>-<pid>' docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md
grep -c 'tombs=' docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md
grep -c 'quarantined=' docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md
grep -c '<remote> <branch> <fingerprint>' docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md
```

Expected: `dry run: 9 decisions, index docs/hyperpowers/decisions/README.md`; `2`; `2`; `2`; `1`. (The dry run may need the spec committed; if it exits 2 saying so, commit first and re-run.)

- [ ] **Step 7: Commit**

```bash
git add docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(hyperpowers): the dossier spec records the hand-back's five decisions and the behaviour they change"
```

---

### Task 2: A verified import keeps the legacy workspace as a dated copy

**Risk tier:** high — a durable-record path under the lock with a crash boundary; it changes what is left on disk after an import.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state:226-240` (beside `recover_import_backup`: new `set_aside_imported`), `:287-316` (`import_finish` and its comment), `:359-361` (the candidate loop, right after `recover_import_backup` and before `[ -e "$c" ] || continue`), `:378-381` and `:403-406` (the two comments naming the backup)
- Modify: `skills/subagent-driven-development/scripts/sdd-dir:63-85` (`reclaim_plain`)
- Modify: `CHANGELOG.md` (the `## Unreleased` list)
- Test: `tests/sdd/test-sdd-state.sh` (the import section, after the last i1 assertion at line 462, and fixtures i10 and i11 at the end of that section), `tests/claude-code/test-sdd-dir-path.sh` (the reclaim section, lines 266-334)

**Interfaces:**
- Consumes: the spec's import paragraph (Task 1).
- Produces: `set_aside_imported <legacy path>` renames every `<legacy path>.importing-*` directory to `<legacy path>.imported-<YYYYMMDDTHHMMSSZ>-<pid>` (a destination that already exists gets `-1`, `-2`, ... appended until it does not) and returns 0 when none is left, 1 otherwise. `import_finish` calls it on the physical source path (`$3`, beside which the backup was made) after the verification and before the relink, so no `.importing-*` copy ever outlives a published pointer. An import interrupted between the set-aside and the relink leaves the kept copy and an absent legacy path (or a dangling pointer); `cmd_import`'s candidate loop completes the relink when a candidate is absent, the destination holds a ledger, and `<referent>.imported-*` exists, and prints `status=moved from=<candidate>`. Every path involved comes from this repository's own candidates, so another repository's workspace of the same name is never touched. `reclaim_plain` in `sdd-dir` is two-phase: a root under which nothing is newer than 14 days is renamed to a staging name `<key>.claiming-<pid>`, re-checked there with the importer's signals intact (its own old mtime, no `.importing-*`), touched, and renamed to `<key>.reclaiming-<pid>`; nothing is deleted on that pass, and a `.claiming-*` leftover is adopted (touched and renamed) by a later pass; a later call deletes a `.reclaiming-*` root once nothing under it is newer than 14 days, after one more rename-aside and re-check. A kept copy a slower session still appends to is never deleted while it is being written, and a root reclaimed by mistake is recoverable for 14 days under its `.reclaiming-*` name. `sdd-dir`'s dangling-pointer prune keeps a pointer whose referent has `.importing-*` or `.imported-*` beside it, or under its root's `.claiming-*` or `.reclaiming-*` name, so the interrupted-import handle survives a cross-repository call; a `.claiming-*` claim is adopted only when the pid in its name is gone (`hp_pid_gone`); a direct candidate's completion recreates the legacy root's `plans/` directory before relinking. `recover_import_backup` (`sdd-state:231-240`) matches `.importing-*` only, so a kept copy is never put back; `reclaim_plain` (`sdd-dir:63-85`) guards on `plans/*.importing-*` only, so a root holding kept copies is reclaimed after 14 idle days. The seam value `HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside` exits 99 (after `hp_unlock`) between the set-aside and the relink. A legacy workspace the plain-cache reclaim has already set aside is not an absent candidate: for every candidate whose path (a pointer's referent, for a pointer) is `<root>/plans/<ws>` and that holds no `progress.md` (absent, or present and empty: on the plain backend `sdd-dir` recreates the root and the workspace directory before it calls `import`, and its no-argument form recreates the cwd key's root), whatever the state of its root, `import` looks for `<root>.claiming-*/plans/<ws>/progress.md`, `<root>.reclaiming-*/plans/<ws>/progress.md` and `<root>.gone-*/plans/<ws>/progress.md`; a hit ends the import with `status=error` (exit 2) and one stderr line naming the quarantined root and the repair (`mv <quarantined root> <root>`, then `sdd-state import` again), so `sdd-dir` stops instead of starting an empty workspace beside a dossier that waits in quarantine. Fixture: a legacy root renamed to `<root>.reclaiming-<pid>` by hand before the first import; the import refuses and names it; moved back, the next import completes with the ledger. A plain-backend fixture quarantines the root and runs the plan form of `sdd-dir` directly: refused (exit 2, the quarantined root named) until the root is moved back, the ledger in place afterwards.

**Mirror:** `tests/sdd/test-sdd-state.sh:449-462` (i1) for the fixture; `skills/subagent-driven-development/scripts/sdd-state:231-240` (`recover_import_backup`) for the sibling-scan loop shape.

- [ ] **Step 1: Write the failing tests**

After line 462 (the i1 assertion `the legacy location becomes a symlink to the new workspace`) add:

```bash
kept_i1=$(ls -d "$legacy_i1".imported-* 2>/dev/null | head -n 1)
if [ -n "$kept_i1" ] && [ -d "$kept_i1" ] && [ ! -L "$kept_i1" ] && [ "$(head -n 1 "$kept_i1/progress.md")" = "# SDD ledger — plan: $i1/docs/plan.md" ] && cmp -s <(tail -n +2 "$kept_i1/progress.md") <(tail -n +2 "$wsi/progress.md") && [ -f "$kept_i1/task-1-report.md" ] && [ -f "$kept_i1/task-1-brief.md" ] && [ -L "$legacy_i1" ]; then pass "a verified import keeps the legacy workspace as <path>.imported-<UTC>-<pid> beside the pointer, identity line unrewritten"; else fail "a verified import keeps the legacy workspace beside the pointer (kept='$kept_i1')"; fi
if ! ls -d "$legacy_i1".importing-* >/dev/null 2>&1; then pass "no .importing-* copy is left after a complete import"; else fail "no .importing-* copy is left after a complete import"; fi
out=$(run_state "$i1" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none" ] && [ -d "$kept_i1" ]; then pass "the kept copy is not an import candidate: the next import prints status=none and leaves it"; else fail "the kept copy is not an import candidate (rc=$rc: $out)"; fi
```

At the end of the import section (after the last `i9` assertion at line 577 and before the next `echo "=== ... ==="`), add two crash fixtures, one for a direct candidate and one for a pointer candidate whose referent lives under another root (mirror i2 at lines 464-479 for how `$ptr2` is built):

```bash
# An import killed between the relink and the rename leaves the pointer and
# the .importing-<pid> copy; the next import sets the copy aside.
i10="$TEST_ROOT/i10"; make_repo "$i10"
mkdir -p "$i10/docs"; : > "$i10/docs/plan.md"; git -C "$i10" add docs; git -C "$i10" commit -qm plan
wsi10=$(ws_path "$i10" "$i10/docs/plan.md")
legacy_i10="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i10")/plans/$(basename "$wsi10")"
mkdir -p "$legacy_i10"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i10/progress.md"
( cd "$i10" && HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside bash "$SDD_STATE" import docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ ! -e "$legacy_i10" ] && [ ! -L "$legacy_i10" ] && ls -d "$legacy_i10".imported-* >/dev/null 2>&1 && ! ls -d "$legacy_i10".importing-* >/dev/null 2>&1 && [ -f "$wsi10/progress.md" ]; then pass "the crash seam stops after the set-aside with the kept copy present and no pointer yet"; else fail "the crash seam stops after the set-aside (rc=$rc)"; fi
out=$(run_state "$i10" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i10" ] && [ -L "$legacy_i10" ] && [ "$(cd "$legacy_i10" && pwd -P)" = "$(cd "$wsi10" && pwd -P)" ] && ls -d "$legacy_i10".imported-* >/dev/null 2>&1; then pass "the next import completes the relink and prints status=moved"; else fail "the next import completes the relink (rc=$rc: $out)"; fi
out=$(run_state "$i10" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none" ]; then pass "a completed relink is idempotent: status=none after it"; else fail "a completed relink is idempotent (rc=$rc: $out)"; fi
# The same crash when the candidate is a pointer: the copy sits beside the
# pointer's former referent under another root, not beside the pointer.
i11="$TEST_ROOT/i11"; make_repo "$i11"
mkdir -p "$i11/docs"; : > "$i11/docs/plan.md"; git -C "$i11" add docs; git -C "$i11" commit -qm plan
wsi11=$(ws_path "$i11" "$i11/docs/plan.md")
real_i11="$XDG_CACHE_HOME/hyperpowers/sdd/otherroot00000000000000000000000000000000/plans/$(basename "$wsi11")"
mkdir -p "$real_i11"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$real_i11/progress.md"
ptr_i11="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i11")/plans/$(basename "$wsi11")+$(state_key "$i11" | cut -c1-8)"
mkdir -p "$(dirname "$ptr_i11")"; ln -s "$real_i11" "$ptr_i11"
( cd "$i11" && HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside bash "$SDD_STATE" import docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -L "$ptr_i11" ] && [ ! -e "$ptr_i11" ] && ls -d "$real_i11".imported-* >/dev/null 2>&1 && [ -f "$wsi11/progress.md" ]; then pass "a pointer candidate's crash leaves the kept copy beside its former referent and the pointer dangling"; else fail "a pointer candidate's crash leaves the kept copy beside its former referent (rc=$rc)"; fi
out=$(run_state "$i11" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$ptr_i11" ] && [ "$(cd "$ptr_i11" && pwd -P)" = "$(cd "$wsi11" && pwd -P)" ]; then pass "the next import relinks the dangling pointer to the destination"; else fail "the next import relinks the dangling pointer (rc=$rc: $out)"; fi
```

In `tests/claude-code/test-sdd-dir-path.sh`, read the reclaim section (lines 266-334: an idle root is reclaimed on invocation; a root holding an import backup survives) and add, in its style, two roots whose own mtime is old: one holding `plans/<ws>.imported-20240101T000000Z-1/progress.md` touched now (must survive the invocation) and one holding the same with every entry old (must be reclaimed). Name the assertions `an idle root whose kept import copy was written to recently survives` and `an idle root whose kept import copy is old is reclaimed`.

Read i2 (lines 464-479) first: the pointer's name carries the plan repository's key prefix as its suffix, and the fixture above builds it the same way; if i2 derives the suffix differently, copy i2's expression. The i1 assertions and the `.importing-*` check stand unchanged.

- [ ] **Step 2: RED**

State suite (or extracted harness), needles `keeps the legacy workspace`, `no .importing-* copy`, `the crash seam stops after the set-aside`, `completes the relink`, `idempotent`, `beside its former referent`, `relinks the dangling pointer`: all `[FAIL]`; `bash tests/claude-code/test-sdd-dir-path.sh 2>&1 | grep -n 'kept import copy'`: `[FAIL]` for the survivor (reclaimed today) (today the backup is deleted, the seam does not exist so the first import completes with rc 0, and the second prints `status=none` with no `.imported-*`).

- [ ] **Step 3: The rename, its recovery and the seam**

After `recover_import_backup` (line 240) add:

```bash
# <legacy path>: set every <path>.importing-* copy aside as
# <path>.imported-<UTC>-<pid>, the name a complete import leaves. The copy
# stays beside the pointer for a session on the previous plugin that still
# holds the legacy ledger open, and the plain-cache reclaim takes it with its
# root after 14 idle days. `.imported-` is not `.importing-`:
# recover_import_backup and reclaim_plain match the latter only. A name that
# is already taken gets a counter, so BSD mv never nests one copy in another.
# Returns 0 when no .importing-* copy is left, 1 otherwise.
set_aside_imported() {
  local b kept n=0 left=0
  for b in "$1".importing-*; do
    [ -d "$b" ] || continue
    kept="$1.imported-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    while [ -e "$kept" ] || [ -L "$kept" ]; do n=$((n + 1)); kept="$1.imported-$(date -u +%Y%m%dT%H%M%SZ)-$$-$n"; done
    mv "$b" "$kept" 2>/dev/null || { echo "sdd-state: the imported source could not be set aside at $kept; it is still at $b and the next import will try again" >&2; left=1; }
  done
  return "$left"
}
```

In `import_finish`, move the set-aside before the relink: after the verification (`cmp -s ...` and the manifest comparison) and before `if [ -L "$1" ]; then link=$1; else link=$3; fi`, insert

```bash
  # The kept copy is made before the pointer: a crash between the two leaves
  # the destination complete, the copy beside the source's location and no
  # pointer, and the next import completes the relink (cmd_import). A copy
  # that cannot be set aside keeps the import unfinished rather than leaving
  # .importing-* beside a published pointer.
  set_aside_imported "$3" || { import_abort "$1" "$2" "$3" "" "$installed"; return 2; }
  if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = import-after-set-aside ]; then hp_unlock; exit 99; fi
```

and delete the line `rm -rf "$2" || echo "sdd-state: the imported source's backup could not be removed: $2" >&2`. The relink's own failure arm still calls `import_abort "$1" "$2" "$3" "" "$installed"`; read `import_abort` and make it tolerate an absent `$2` (the backup has become the kept copy), restoring from the kept copy named by `ls -d "$3".imported-* | tail -n 1` when `$2` is gone, so a failed relink after the set-aside still leaves the source where it was. In the comment block above the function replace `and remove the backup` with `and set the backup aside as the kept copy (set_aside_imported)`. In the two comments at lines 378-381 and 403-406 that read `14-day reclaim of plain-cache roots does not take the backup with it`, append `A finished import leaves <ref>.imported-<UTC>-<pid>, which the reclaim does take.`

In `cmd_import`'s candidate loop, right after `if recover_import_backup "$c"; then restored=1; else restored=0; fi` and before `[ -e "$c" ] || continue`, add:

```bash
    # A kept copy beside an absent candidate (or beside a dangling pointer's
    # referent) while the destination already holds a ledger is an import
    # interrupted between its set-aside and its relink: finish the relink.
    if [ ! -e "$c" ] && [ -f "$dest/progress.md" ]; then
      if [ -L "$c" ]; then t=$(readlink "$c"); else t=$c; fi
      if ls -d "$t".imported-* >/dev/null 2>&1; then
        if [ -L "$c" ]; then link=$c; else link=$t; fi
        if ln -sfn "$dest" "$link" 2>/dev/null && [ "$(hp_physical_dir "$link" 2>/dev/null)" = "$dest_phys" ]; then
          hp_unlock; echo "status=moved from=$(enc "$c")"; return 0
        fi
        hp_unlock; echo "status=import-failed from=$(enc "$c")"; return 2
      fi
    fi
```

(add `t link` to the function's `local` line if they are not there; every path here comes from this repository's own candidate list, so a workspace of the same name under another repository's root is never touched).

In `sdd-dir`'s `reclaim_plain`, add a newest-descendant check beside each root-mtime check: before the claim, `[ -z "$(find "$r" -mtime -14 2>/dev/null | head -n 1)" ] || continue`, and in the re-check on the claimed root, put the root back when `find "$claimed" -mtime -14 2>/dev/null | head -n 1` prints anything. Update the function's comment: a root is idle only when nothing under it is newer than 14 days, so a kept import copy a slower session still appends to is never taken.

- [ ] **Step 4: GREEN, quick suites, lint**

State suite, needles from Step 2: all `[PASS]`, log GREEN. `bash tests/sdd/test-sdd-contract.sh` and `bash tests/claude-code/test-sdd-dir-path.sh` `STATUS: PASSED`. `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/scripts/sdd-dir tests/sdd/test-sdd-state.sh tests/claude-code/test-sdd-dir-path.sh` exit 0.

- [ ] **Step 5: The changelog**

In `CHANGELOG.md` under `## Unreleased`, after the bullet beginning `- **A live broker is no longer called stale from a sandboxed shell.**`, add:

```markdown
- **An import keeps the legacy workspace.** After a verified import the old plain-cache workspace is set aside as `<path>.imported-<UTC>-<pid>` beside the pointer instead of deleted, so a session still on the previous plugin that appends to the old ledger writes into a copy a human can find; the plain-cache reclaim takes it with its root only once nothing under that root is newer than 14 days, and an import interrupted before the pointer is placed is completed by the next one.
```

- [ ] **Step 6: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/scripts/sdd-dir tests/sdd/test-sdd-state.sh tests/claude-code/test-sdd-dir-path.sh CHANGELOG.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "fix(sdd-state): a verified import deleted the legacy workspace a slower session could still be writing"
```

---

### Task 3: Every subcommand prints a status line when the checkout cannot be created

**Risk tier:** high — the resolver every subcommand shares; its stdout is the contract the skill text acts on.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state:69-76` (`resolve_plan`)
- Test: `tests/sdd/test-sdd-state.sh` (between the needs-sync assertion at line 108 and the stamp write at line 109)

**Interfaces:**
- Consumes: nothing.
- Produces: `snapshot`, `claim`, `import`, `handoff`, `verify` and `finish` print `status=error` (exit 2) when `hp_ensure_checkout` fails, where today they exit 2 with empty stdout; `sync` and `sdd-dir` already print their own lines and are unchanged.

**Mirror:** `tests/sdd/test-sdd-state.sh:106-111` (p1: a clone with a remote and no stamp; `ensure "$PAIR_A"` exits 2 with `needs-sync` on stderr; `run_state` is defined at line 60).

- [ ] **Step 1: Write the failing test**

Between line 108 (the `needs-sync and no checkout` assertion) and line 109 (`: > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"`) add:

```bash
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"
out=$(run_state "$PAIR_A" snapshot docs/plan.md 2>"$TEST_ROOT/ns-snapshot.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'needs-sync' "$TEST_ROOT/ns-snapshot.err"; then pass "snapshot prints status=error when the checkout cannot be created"; else fail "snapshot prints status=error when the checkout cannot be created (rc=$rc: '$out')"; fi
out=$(run_state "$PAIR_A" verify docs/plan.md 2>"$TEST_ROOT/ns-verify.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'needs-sync' "$TEST_ROOT/ns-verify.err"; then pass "verify prints status=error when the checkout cannot be created"; else fail "verify prints status=error when the checkout cannot be created (rc=$rc: '$out')"; fi
```

The plan file is created uncommitted on purpose: `hp_plan_dir` needs an existing regular file and nothing more. Read lines 109-118 first: the later p1 assertions fetch and `ensure`, and do not depend on `docs/` being absent.

- [ ] **Step 2: RED**

State suite (or extracted harness), needles `when the checkout cannot be created`: both `[FAIL]` with `''` as the output.

- [ ] **Step 3: Print the status before exiting**

In `resolve_plan` replace

```bash
  ensure=$(hp_ensure_checkout "$PLAN_DIR") || exit 2
```

with

```bash
  # The grammar is one status line on stdout for every outcome; the library
  # has already said on stderr why the checkout could not be created.
  ensure=$(hp_ensure_checkout "$PLAN_DIR") || { echo "status=error"; exit 2; }
```

- [ ] **Step 4: Confirm the skill text already covers the token**

Run: `grep -n 'status=error' skills/subagent-driven-development/SKILL.md | head -n 5`
Expected: at least one line that pairs `status=error` with exit 2 and a stop. If none does, do not edit `SKILL.md` (this plan changes no skill text); write the missing sentence into the report's concerns as a hand-back item.

- [ ] **Step 5: GREEN, quick suites, lint**

State suite, needles from Step 2: both `[PASS]`, log GREEN. `bash tests/sdd/test-sdd-contract.sh` `STATUS: PASSED`. `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state` exit 0.

- [ ] **Step 6: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "fix(sdd-state): a subcommand whose checkout could not be created exited with no status line"
```

---

### Task 4: `sdd-dir` adds its generic failure line only when nothing specific was said

**Risk tier:** high — a return-code contract between the library and `sdd-dir`, whose stdout and exit every caller trusts.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh:555-640` (`hp_materialize_plain` return codes)
- Modify: `skills/subagent-driven-development/scripts/sdd-dir:134-140` (the plain branch)
- Test: `tests/sdd/test-sdd-state.sh` (the p27 fixture, lines 1881-1912: `PAIR_A` publishes, `PAIR_B` is the plain-backend host, `ws27`, `outside27`, stderr in `$TEST_ROOT/p27.err`)

**Interfaces:**
- Consumes: nothing.
- Produces: `hp_materialize_plain` returns 1 for a failure it did not report (staging directory, archive, tar, an occupied destination, an occupied destination at the rename, a published tree without its ledger at the exact destination) and 2 after printing its own refusal (unreadable tree, hostile tip, a containment refusal, which `hp_contained` prints itself); the backend file is written only after the ledger is verified at the destination. `sdd-dir` prints `could not materialize the branch workspace into the plain cache` only for return 1. The publish is `rename(2)` through node (`fs.renameSync`), which replaces an empty directory atomically and fails with ENOTEMPTY on one that holds anything, so it never nests. The seam value `HYPERPOWERS_TEST_WRITER_AT=materialize-before-publish:<ws>` recreates the destination with a file in it after the last precondition check and immediately before the rename. `sdd-dir`'s node preflight (`sdd-dir: node not found`, exit 2) runs on the plan form only: the no-argument form derives and touches the plain root and runs the reclaim, whose only node use (`hp_pid_gone`) reads a missing node as alive, so that form keeps working without node. Fixture: the no-argument form on a PATH without node prints the root and exits 0.

**Mirror:** `tests/sdd/test-sdd-state.sh:1881-1912` (p27; `PAIR_B` refreshes its remote-tracking ref with an explicit `git fetch`, because `sync` returns `status=plain` before fetching under that backend).

- [ ] **Step 1: Write the failing tests**

In `tests/sdd/test-sdd-state.sh`, after the p27 assertion that checks `grep -q 'symbolic link' "$TEST_ROOT/p27.err"` (line 1909), add:

```bash
if [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27.err")" -eq 1 ]; then pass "a specific refusal is the only sdd-dir line on stderr"; else fail "a specific refusal is the only sdd-dir line on stderr ($(grep -c '^sdd-dir:' "$TEST_ROOT/p27.err") lines)"; fi
```

Then, after the last p27 assertion (the one that materializes the workspace once the link is replaced; read to the end of the p27 block), publish a second plan from `PAIR_A` and add two cases on the plain host: a destination that reappears between the clearing `rm -rf` and the rename (the seam value), and a plain root that cannot take a staging directory. Both are failures the library does not report, so each gets `sdd-dir`'s one generic line and only that line, and neither leaves a nested or partial workspace:

```bash
: > "$PAIR_A/docs/plan2.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan2; git -C "$PAIR_A" push -q origin main 2>/dev/null
wsa27b=$(run_sdd_dir "$PAIR_A" docs/plan2.md); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsa27b/progress.md"
run_state "$PAIR_A" snapshot docs/plan2.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null; git -C "$PAIR_B" fetch -q origin hyperpowers/state 2>/dev/null
plain27="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$PAIR_B")"; ws27b=$(basename "$wsa27b")
# The destination reappears after it was cleared: the publish refuses rather
# than nesting the staged copy inside it, and nothing is recorded.
rc=0; out=$(HYPERPOWERS_TEST_WRITER_AT="materialize-before-publish:$ws27b" run_sdd_dir "$PAIR_B" docs/plan2.md 2> "$TEST_ROOT/p27c.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27c.err")" -eq 1 ] && grep -q 'could not materialize' "$TEST_ROOT/p27c.err" && [ ! -e "$plain27/plans/$ws27b/$ws27b" ] && [ ! -f "$plain27/plans/$ws27b/progress.md" ] && [ -f "$plain27/plans/$ws27b/stray" ] && ! grep -q "source=" "$STATE_ROOT/$(state_key "$PAIR_B").backend"; then pass "a destination that reappears right before the rename is refused, not nested, its contents kept, and nothing recorded"; else fail "a destination that reappears right before the rename is refused (rc=$rc; $(tr '\n' '|' < "$TEST_ROOT/p27c.err"))"; fi
# The occupied destination is never cleared by the helper: a human removes
# it, and the next call materializes.
rm -rf "$plain27/plans/$ws27b"
out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$out/progress.md" ]; then pass "once the occupied destination is cleared the next call materializes the same plan"; else fail "once the occupied destination is cleared the next call materializes (rc=$rc: $out)"; fi
rm -rf "$plain27/plans/$ws27b"; sed -i '' '/^plain source=/d' "$STATE_ROOT/$(state_key "$PAIR_B").backend" 2>/dev/null || true
# A destination that already holds something (no ledger) before the call is
# refused with its contents intact; an empty one is replaced.
mkdir -p "$plain27/plans/$ws27b"; printf 'theirs\n' > "$plain27/plans/$ws27b/notes.txt"
rc=0; out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2> "$TEST_ROOT/p27d.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ "$(cat "$plain27/plans/$ws27b/notes.txt")" = "theirs" ] && [ ! -f "$plain27/plans/$ws27b/progress.md" ] && [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27d.err")" -eq 1 ] && ! grep -q "source=" "$STATE_ROOT/$(state_key "$PAIR_B").backend"; then pass "a destination that already holds files is refused with every byte intact"; else fail "a destination that already holds files is refused with every byte intact (rc=$rc: $out)"; fi
rm -f "$plain27/plans/$ws27b/notes.txt"
out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$out/progress.md" ]; then pass "an empty pre-existing destination is replaced by the publish"; else fail "an empty pre-existing destination is replaced by the publish (rc=$rc: $out)"; fi
rm -rf "$plain27/plans/$ws27b"; sed -i '' '/^plain source=/d' "$STATE_ROOT/$(state_key "$PAIR_B").backend" 2>/dev/null || true
if [ "$(id -u)" -ne 0 ]; then
  mkdir -p "$plain27/plans"; chmod 0555 "$plain27"
  rc=0; out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2> "$TEST_ROOT/p27b.err") || rc=$?
  chmod 0755 "$plain27"
  if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27b.err")" -eq 1 ] && grep -q 'could not materialize' "$TEST_ROOT/p27b.err"; then pass "an unreported materialization failure gets exactly one generic sdd-dir line"; else fail "an unreported materialization failure gets exactly one generic sdd-dir line (rc=$rc; $(tr '\n' '|' < "$TEST_ROOT/p27b.err"))"; fi
else
  pass "an unreported materialization failure gets exactly one generic sdd-dir line (skipped: root ignores directory modes)"
fi
```

`hp_materialize_plain` reaches its staging step only when the tip carries `plans/<ws>/progress.md` for the plan, which is why the second plan is published from `PAIR_A` first; `mkdir -p "$root/plans"` succeeds on the existing directory, `touch "$root"` is allowed to the owner, and `mktemp -d "$root/.materialize.XXXXXX"` fails on the read-only root. Read how the backend file records a plain source before writing the `sed` that resets it; if `hp_write_backend` writes the whole file, replace that line with `printf 'plain\n' > "$STATE_ROOT/$(state_key "$PAIR_B").backend"` so the third call materializes again.

- [ ] **Step 2: RED**

State suite (or extracted harness), needles `only sdd-dir line` (expected `[FAIL]`: the p27 refusal is followed by the generic line today, 2 lines), `reappears right before the rename` (expected `[FAIL]`: the seam does not exist, so the call succeeds) and `exactly one generic sdd-dir line` (it prints the generic line today too, so it may already pass; it is the regression guard for the return-code split, and the report says which way it went).

- [ ] **Step 3: Separate reported from unreported failures**

In `hp_materialize_plain`, change the `return 2` on these lines to `return 1`: the `staging=$(mktemp -d ...) || return 2` line and the `if [ "$archive_rc" -ne 0 ] ... rm -rf "$staging"; return 2; fi` line. Leave every `return 2` that follows an `echo` or an `hp_contained` call as it is. Then replace the publish step

```bash
  rm -rf "$dest"
  if ! mv "$staging/plans/$ws" "$dest"; then rm -rf "$staging"; return 2; fi
```

with

```bash
  # The destination must be clear ground when the staged copy is renamed
  # onto it: BSD mv nests into a directory that reappeared and reports
  # success with the ledger one level too deep, and the backend record
  # would then vouch for a workspace that is not there.
  # Test hook: the destination appears, with content, right before the rename.
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in materialize-before-publish:*) mkdir -p "$root/plans/${HYPERPOWERS_TEST_WRITER_AT#materialize-before-publish:}" && : > "$root/plans/${HYPERPOWERS_TEST_WRITER_AT#materialize-before-publish:}/stray" ;; esac
  # Nothing at the destination is ever cleared by the helper. rename(2)
  # replaces an empty directory atomically and refuses one that holds
  # anything (ENOTEMPTY) or that is not a directory; BSD mv would nest the
  # staged copy inside it. What a human or another tool left there stays
  # for them to remove.
  if ! node -e 'require("fs").renameSync(process.argv[1], process.argv[2])' "$staging/plans/$ws" "$dest" 2>/dev/null; then rm -rf "$staging"; return 1; fi
  if [ ! -f "$dest/progress.md" ] || [ -e "$dest/$ws" ]; then rm -rf "$staging"; return 1; fi
```

(the backend write that follows stays after these checks, so it records only a verified workspace; `node` is already a requirement of the helper, and `sdd-dir` checks for it before any import). Delete the old `rm -rf "$dest"` line: an occupied destination is refused, never cleared. Add to the function's header comment: `Returns 1 for a failure it did not report, 2 after printing its own refusal; the backend is recorded only after the ledger is verified at the destination.`

In `sdd-dir` replace

```bash
    if ! hp_materialize_plain "$plan_dir" "$ws" "$dir"; then
      hp_unlock
      echo "sdd-dir: could not materialize the branch workspace into the plain cache" >&2
      exit 2
    fi
```

with

```bash
    rc=0; hp_materialize_plain "$plan_dir" "$ws" "$dir" || rc=$?
    if [ "$rc" -ne 0 ]; then
      hp_unlock
      # A refusal has already named itself; only a silent failure needs a line.
      [ "$rc" -ne 1 ] || echo "sdd-dir: could not materialize the branch workspace into the plain cache" >&2
      exit 2
    fi
```

(`sdd-dir` runs under `set -e`; the `|| rc=$?` form is what keeps a non-zero return from ending the script before the branch.)

- [ ] **Step 4: GREEN, quick suites, lint**

State suite, needles from Step 2 plus `once the occupied destination is cleared`, `every byte intact` and `empty pre-existing destination`: all `[PASS]`, log GREEN. `bash tests/claude-code/test-sdd-dir-path.sh` `STATUS: PASSED` (a regression check). `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-dir tests/sdd/test-sdd-state.sh` exit 0.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-dir tests/sdd/test-sdd-state.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "fix(sdd-dir): a specific refusal was followed by the generic materialization line"
```

---

### Task 5: Library messages carry the calling tool's name

**Risk tier:** high — fourteen messages in the shared library plus both callers; stderr text other tools and the skill text read.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh:1-12` (header) and the fourteen `echo "sdd-state: ...` / `echo "sdd-dir: ...` lines at `:208, :249, :337, :382, :386, :445, :450, :455, :504, :532, :550, :586, :601, :606`
- Modify: `skills/subagent-driven-development/scripts/sdd-dir:28` and `skills/subagent-driven-development/scripts/sdd-state:28` (set the name before sourcing)
- Test: `tests/sdd/test-sdd-common.sh`, `tests/claude-code/test-sdd-dir-path.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `HP_PROG`, a variable the library reads for every prefix (`${HP_PROG:-${0##*/}}`), set to `sdd-dir` by `sdd-dir` and `sdd-state` by `sdd-state` before the library is sourced. `codex-review-dir`, `ungated-ledger`, `gate-telemetry` and the session-start hook, which also source the library, print under their own basename without a change.

- [ ] **Step 1: Write the failing tests**

In `tests/sdd/test-sdd-common.sh`, after the `# --- key ---` block's assertions, add:

```bash
# --- message prefix ----------------------------------------------------------
# Every message the library prints names the tool that called it.
root_px="$TEST_ROOT/px"; mkdir -p "$root_px/plans"; ln -s "$TEST_ROOT" "$root_px/plans/link"
msg=$(HP_PROG=probe-tool bash -c '. "$1"; hp_contained "$2" plans/link' probe-default "$LIB" "$root_px" 2>&1 >/dev/null)
case "$msg" in "probe-tool: "*) pass "a library message carries HP_PROG as its prefix" ;; *) fail "a library message carries HP_PROG as its prefix (got: $msg)" ;; esac
msg=$(bash -c '. "$1"; hp_contained "$2" plans/link' probe-default "$LIB" "$root_px" 2>&1 >/dev/null)
case "$msg" in "probe-default: "*) pass "without HP_PROG the prefix is the calling script's basename (\$0)" ;; *) fail "without HP_PROG the prefix is the calling script's basename (got: $msg)" ;; esac
```

(With `bash -c '...' probe-default "$LIB" "$root_px"`, the word after the command string is `$0`, so the default prefix reads `probe-default:`; `$1` is the library and `$2` the root.) In `tests/claude-code/test-sdd-dir-path.sh`, find the section headed `Test: a workspace path that is a symbolic link is refused` (line 503 onwards) and its first refusal assertion; make it capture stderr to `$TEST_ROOT/link-ws.err` if it does not already, and add after it:

```bash
if grep -q '^sdd-dir: .* is a symbolic link' "$TEST_ROOT/link-ws.err"; then pass "the containment refusal under sdd-dir is prefixed sdd-dir"; else fail "the containment refusal under sdd-dir is prefixed sdd-dir ($(head -n 2 "$TEST_ROOT/link-ws.err" | tr '\n' '|'))"; fi
```

- [ ] **Step 2: RED**

Run: `bash tests/sdd/test-sdd-common.sh 2>&1 | grep -n 'prefix'` and `bash tests/claude-code/test-sdd-dir-path.sh 2>&1 | grep -n 'prefixed sdd-dir'` (both suites are quick, so a grep over their output is fine here).
Expected: three `[FAIL]` lines (today the messages read `sdd-state:` regardless of the caller).

- [ ] **Step 3: One prefix variable**

In `sdd-common.sh`, after the header comment (after line 11, before `hp_cache_root()`), add:

```bash
# The prefix of every message this library prints: the tool that called it.
# sdd-dir and sdd-state set it before sourcing; any other sourcer prints
# under its own name.
HP_PROG=${HP_PROG:-${0##*/}}
```

Then on each of the fourteen lines listed under Files replace the literal `sdd-state: ` or `sdd-dir: ` at the start of the message with `$HP_PROG: `. Check with `grep -c 'echo "sdd-' skills/subagent-driven-development/scripts/sdd-common.sh` (expected `0`) and `grep -c '"\$HP_PROG: ' skills/subagent-driven-development/scripts/sdd-common.sh` (expected `14`).

In `sdd-dir` and in `sdd-state`, on the line before `. "$SCRIPT_DIR/sdd-common.sh"`, add `HP_PROG=sdd-dir` and `HP_PROG=sdd-state` respectively.

- [ ] **Step 4: GREEN, the sourcers' suites, lint**

Run: `bash tests/sdd/test-sdd-common.sh`, `bash tests/claude-code/test-sdd-dir-path.sh`, `bash tests/sdd/test-sdd-contract.sh`, `bash tests/hooks/test-session-start.sh`, `bash tests/codex-review-gate/test-ungated-ledger.sh`, `bash tests/codex-review-gate/test-gate-telemetry.sh`, `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-dir skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-common.sh tests/claude-code/test-sdd-dir-path.sh`
Expected: every suite `STATUS: PASSED` or `ALL PASS`; lint exit 0. (The hook and the two gate scripts source the library; their suites prove the default prefix breaks nothing they assert.) Then one state-suite GREEN run for this task.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-dir skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-common.sh tests/claude-code/test-sdd-dir-path.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "fix(sdd-common): a library message named sdd-state even when sdd-dir printed it"
```

---

### Task 6: A post-ref containment failure says how to repair it

**Risk tier:** high — recovery logic on the sync path; a distinct return code and the message a human acts on.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state:894-943` (`apply_files`: the two `hp_contained ... || return 2` lines at 898 and 935 return 4), `:1009-1013` (the post-ref failure line in `recover_apply`), `:1152-1175` (`apply_target` after `update-ref`: the seam value, the `case` on the apply result, and the post-apply re-walk), and a small helper beside `recover_apply`
- Test: `tests/sdd/test-sdd-state.sh` (a new fixture after the crash fixture at lines 925-940)

**Interfaces:**
- Consumes: nothing.
- Produces: `apply_files` returns 4 when a path it must write or remove is, or sits under, a symbolic link (both `hp_contained` checks); every other failure keeps its code. Every workspace the apply writes into or removes from comes back whole: after both walks, every path the target tracks under a workspace either walk touched that is still missing is published from the target with its tracked mode (each through `hp_contained` first, so a link there is refused and named like any other), because the diff names only what changed between S and the target, and a directory restored with those files alone would have the next `snapshot_pending` record its unchanged siblings as deletions. The rule covers every touched workspace, not only one the apply created, because an apply that creates the directory and then fails on a later path (a second link, a publish race) leaves it partial, and the next apply, which no longer creates it, must still complete it; that is what makes "remove the link" safe advice for a link at `plans/<ws>` itself. Both walks record the workspace: a deletion-only apply met by a link at the directory must bring the rest back after the repair, and a workspace the target empties (a remote finish) tracks nothing afterwards, so nothing is restored there. Each missing path is published from a temporary copy with one `link(2)`, so a file a writer creates between the check and the publish is theirs and is never overwritten; a ledger a writer creates there is reconciled through `ledger_apply`, never adopted, so neither the writer's lines nor the branch's are lost; the restore's temporary copy lives in the `.restore` sidecar at the checkout root (beside `.rewrite`), never inside a workspace, so a crash between the copy and the publish leaves nothing a snapshot could commit, and `recover_apply` sweeps that sidecar whole (an apply that leaves it empty removes it with `rmdir`, so a copy a crash left behind is the only thing that keeps it); `recover_apply` refuses a link at `$CO/.restore` or at `$CO/plans` the way it refuses one at `.rewrite`, and a branch that tracks `.restore` the way it refuses one tracking `.rewrite`; the ledger's own `progress.md.new.*` sweep looks only inside real workspace directories; the crash value `HYPERPOWERS_TEST_CRASH_AT=restore-after-copy` exits 99 (after `hp_unlock`) between the copy and the publish; a tracked file a writer removed during the interrupted window is put back, which is the module's stance for a missing tracked file (`apply_target`'s pending scan says `put it back`), and no bytes are lost by it. The seam value `HYPERPOWERS_TEST_WRITER_AT=sync-before-restore:<path>` writes `concurrent write` to `$CO/<path>` right before the restore publishes that path. `say_link_repair` prints one sentence to stderr: `sdd-state: a symbolic link sits where sync writes or removes a regular file (named above); remove the link, leave $CO/.sync-applying in place, and run sdd-state sync again: the apply finishes from the branch`. It is printed on all three routes a link can take: `recover_apply` for return 4 (the generic line stays for every other failure), `apply_target`'s result `case` for return 4 on the normal post-ref apply, and `apply_target`'s post-apply re-walk on its own `hp_contained` refusal. Status and exit codes are unchanged (`status=error`, 2, marker kept). The seam value `HYPERPOWERS_TEST_WRITER_AT=sync-after-ref-link:<path>` replaces `$CO/<path>` with a symbolic link to `/dev/null` right after the ref has moved and before the apply; the seam value `HYPERPOWERS_TEST_WRITER_AT=sync-after-apply-link:<path>` does the same after `apply_files` returned 0 and before the post-apply re-walk. `hp_tree_refusal` refuses the three sidecar names as exact entries as well as directories, `.sync-applying`, `.rewrite` and `.restore` beside `.sync-applying/*`, `.rewrite/*` and `.restore/*`, each in its quoted form too: a blob named `.restore` at the root would otherwise pass the whole-tree check, reach disk, and have the next `recover_apply` refuse every publishing subcommand through its tracked-sidecar check. Fixtures: a root blob `.restore` refused at checkout creation, at an existing-checkout apply and at plain materialization.

**Mirror:** `tests/sdd/test-sdd-state.sh:925-940` (a `sync` killed by `HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref` on `PAIR_B`, then a plain `sync` that recovers; `$wsb` is the workspace on B, `$co_b` the checkout).

- [ ] **Step 1: Write the failing test**

After the recovery assertion that follows line 931's crash (read lines 925-940 and place the block after the last assertion of that fixture, re-using its `PAIR_A`, `PAIR_B`, `wsa`, `wsb`, `co_b` and `advance`-style helper if it has one), add:

```bash
# A link planted where the recovery must write a regular file: the marker
# stays, the human is told which repair clears it, and the plain sync that
# follows the repair completes the apply.
printf 'Task 7c: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
victim7c="$TEST_ROOT/victim-7c"; printf 'untouched\n' > "$victim7c"
rm -f "$wsb/progress.md"; ln -s "$victim7c" "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7c.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7c.err" && [ "$(cat "$victim7c")" = "untouched" ]; then pass "a post-ref containment failure keeps the marker, leaves the target untouched and names the repair"; else fail "a post-ref containment failure names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7c.err"))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7c: complete' "$wsb/progress.md"; then pass "after the repair the next sync completes the apply and the ledger comes back from the branch"; else fail "after the repair the next sync completes the apply (rc=$rc: $out)"; fi
# The same link on the normal post-ref apply (no crash): the seam plants it
# after the ref moved, so recover_apply is not the one that meets it.
printf 'Task 7d: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-after-ref-link:plans/$(basename "$wsb")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p7d.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ -L "$wsb/progress.md" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7d.err"; then pass "a link met by the normal post-ref apply keeps the marker and names the repair"; else fail "a link met by the normal post-ref apply names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7d.err"))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7d: complete' "$wsb/progress.md"; then pass "after that repair too the next sync completes the apply"; else fail "after that repair too the next sync completes the apply (rc=$rc: $out)"; fi
# A link at the workspace directory itself, with a report the target leaves
# unchanged: the apply has to recreate the directory, and the workspace must
# come back whole, or the next snapshot would record the report as deleted.
printf 'report\n' > "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'Task 7e: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
moved7e="$TEST_ROOT/ws-7e-moved"; mv "$wsb" "$moved7e"; ln -s "$moved7e" "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7e.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7e.err" && [ "$(cat "$moved7e/task-1-report.md")" = report ]; then pass "a link at the workspace directory keeps the marker and names the repair"; else fail "a link at the workspace directory names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7e.err"))"; fi
rm "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7e: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain -- "plans/$(basename "$wsb")")" ] && [ -n "$(git -C "$co_b" ls-tree --name-only refs/heads/hyperpowers/state -- "plans/$(basename "$wsb")/task-1-report.md")" ]; then pass "with the directory link removed the workspace comes back whole and no deletion is snapshotted"; else fail "with the directory link removed the workspace comes back whole (rc=$rc: $out: $(git -C "$co_b" status --porcelain -- plans/ | tr '\n' '|'))"; fi
# A link where the apply removes a file: the delete walk names the repair.
rm -f "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
victim7f="$TEST_ROOT/victim-7f"; printf 'untouched\n' > "$victim7f"
rm -f "$wsb/task-1-report.md"; ln -s "$victim7f" "$wsb/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7f.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7f.err" && [ "$(cat "$victim7f")" = untouched ]; then pass "a link where the apply removes a file keeps the marker, leaves the target untouched and names the repair"; else fail "a link where the apply removes a file names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7f.err"))"; fi
rm "$wsb/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -e "$wsb/task-1-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- "plans/$(basename "$wsb")")" ]; then pass "after that repair the delete walk completes and the tree is clean"; else fail "after that repair the delete walk completes (rc=$rc: $out)"; fi
# A link planted after the apply succeeded and before the re-walk: the
# re-walk names the repair, and the recovery that follows completes.
printf 'Task 7g: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-after-apply-link:plans/$(basename "$wsb")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p7g.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ -L "$wsb/progress.md" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7g.err"; then pass "a link met by the post-apply re-walk keeps the marker and names the repair"; else fail "a link met by the post-apply re-walk names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7g.err"))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7g: complete' "$wsb/progress.md"; then pass "after that repair too the recovery completes"; else fail "after that repair too the recovery completes (rc=$rc: $out)"; fi
# Two links met by one recovery, a workspace apart: the first apply creates
# the first workspace, publishes its ledger, and fails on the second
# workspace's link, leaving the first partial; the apply that finishes the
# recovery no longer creates that directory and must still complete it.
ws2b="$co_b/plans/$(basename "$ws2a")"
printf 'report\n' > "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'Task 7h: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; printf 'Task 7h-second: complete (commits 1111111..2222222, review clean)\n' >> "$ws2a/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
moved7h="$TEST_ROOT/ws-7h-moved"; mv "$wsb" "$moved7h"; ln -s "$moved7h" "$wsb"
victim7h="$TEST_ROOT/victim-7h"; printf 'untouched\n' > "$victim7h"; rm -f "$ws2b/progress.md"; ln -s "$victim7h" "$ws2b/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7h.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7h.err"; then pass "the first of two links is refused with the marker kept"; else fail "the first of two links is refused with the marker kept (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7h.err"))"; fi
rm "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7h2.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7h2.err" && [ -f "$wsb/progress.md" ] && [ ! -e "$wsb/task-1-report.md" ] && [ "$(cat "$victim7h")" = untouched ]; then pass "the apply that created the first workspace is stopped by the second link, leaving it partial with the marker kept"; else fail "the apply that created the first workspace is stopped by the second link (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7h2.err"))"; fi
rm "$ws2b/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7h: complete' "$wsb/progress.md" && grep -q '^Task 7h-second: complete' "$ws2b/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ] && [ -n "$(git -C "$co_b" ls-tree --name-only refs/heads/hyperpowers/state -- "plans/$(basename "$wsb")/task-1-report.md")" ]; then pass "the apply that finishes the recovery completes the partial workspace and no deletion is snapshotted"; else fail "the apply that finishes the recovery completes the partial workspace (rc=$rc: $out: $(git -C "$co_b" status --porcelain -- plans/ | tr '\n' '|'))"; fi
# A deletion-only apply met by a link at the workspace directory: the
# delete walk records the workspace too, so the recovery that follows the
# repair brings back the ledger and every other tracked file.
printf 'second report\n' > "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
rm -f "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
moved7i="$TEST_ROOT/ws-7i-moved"; mv "$wsb" "$moved7i"; ln -s "$moved7i" "$wsb"; printf 'x\n' > "$moved7i/keep.restore.123"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7i.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7i.err" && [ "$(cat "$moved7i/task-2-report.md")" = "second report" ] && [ -f "$moved7i/keep.restore.123" ]; then pass "a deletion-only apply met by a link at the workspace directory keeps the marker, names the repair, and sweeps nothing through the link"; else fail "a deletion-only apply met by a link at the workspace directory names the repair and sweeps nothing through the link (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7i.err"))"; fi
rm "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7h: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ ! -e "$wsb/task-2-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "after the repair a deletion-only recovery brings the workspace back whole"; else fail "after the repair a deletion-only recovery brings the workspace back whole (rc=$rc: $out: $(git -C "$co_b" status --porcelain -- plans/ | tr '\n' '|'))"; fi
# A tracked file removed while the marker was down is put back by the
# recovery (the module's stance for a missing tracked file), and a file a
# writer creates right before the restore publishes it keeps the writer's
# bytes: the publish is one link(2), never a clobber.
printf 'Task 7j: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7j: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "a tracked file removed while the marker was down is put back by the recovery"; else fail "a tracked file removed while the marker was down is put back by the recovery (rc=$rc: $out)"; fi
printf 'Task 7k: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-restore:plans/$(basename "$wsb")/task-1-report.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7k: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = "concurrent write" ] && ! ls "$wsb"/*.restore.* >/dev/null 2>&1; then pass "a file a writer creates right before the restore publishes it keeps the writer's bytes"; else fail "a file a writer creates right before the restore publishes it keeps the writer's bytes (rc=$rc: $out: $(cat "$wsb/task-1-report.md" 2>/dev/null))"; fi
printf 'report\n' > "$wsb/task-1-report.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
# B pushed last, so A is behind: without this its snapshot below would be
# rejected silently and the remote finish would never reach B.
run_state "$PAIR_A" sync docs/plan.md >/dev/null
# A ledger a writer creates right before the restore publishes it is
# reconciled, never adopted: the branch's ledger stays intact and the sync
# stops with the marker, as for any ledger rewritten locally.
printf 'third report\n' > "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
rm -f "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/progress.md"
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-restore:plans/$(basename "$wsb")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ "$(cat "$wsb/progress.md")" = "concurrent write" ] && git -C "$co_b" show "refs/heads/hyperpowers/state:plans/$(basename "$wsb")/progress.md" | grep -q '^Task 7k: complete'; then pass "a writer's ledger met by the restore is reconciled, never adopted: the branch's ledger is intact and the sync stops"; else fail "a writer's ledger met by the restore is reconciled, never adopted (rc=$rc: $out: $(cat "$wsb/progress.md" 2>/dev/null | head -n 2 | tr '\n' '|'))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7k: complete' "$wsb/progress.md" && [ ! -e "$wsb/task-3-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "with the writer's ledger removed the restore publishes the branch's"; else fail "with the writer's ledger removed the restore publishes the branch's (rc=$rc: $out)"; fi
# A restored file keeps its tracked mode.
printf '#!/bin/sh\nexit 0\n' > "$wsa/run.sh"; chmod 755 "$wsa/run.sh"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'Task 7m: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/run.sh"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && [ -x "$wsb/run.sh" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "a restored file keeps its tracked mode"; else fail "a restored file keeps its tracked mode (rc=$rc: $out: $(ls -l "$wsb/run.sh" 2>&1))"; fi
# A crash between the restore's copy and its publish leaves the copy in
# the .restore sidecar, never inside a workspace: the next sync sweeps it,
# completes the restore, and nothing of it reaches the branch.
printf 'Task 7n: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=restore-after-copy bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && [ -n "$(ls -A "$co_b/.restore" 2>/dev/null)" ] && [ ! -e "$wsb/task-1-report.md" ] && ! ls "$wsb"/*.restore* >/dev/null 2>&1; then pass "the crash seam after the restore's copy leaves the copy in the sidecar and nothing in the workspace"; else fail "the crash seam after the restore's copy leaves the copy in the sidecar (rc=$rc: $(ls -A "$co_b/.restore" 2>&1 | tr '\n' '|'))"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -e "$co_b/.restore" ] && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain)" ] && [ -z "$(git -C "$co_b" ls-tree -r --name-only refs/heads/hyperpowers/state | grep -F '.restore')" ]; then pass "the next sync sweeps the sidecar, completes the restore, and nothing of it reaches the branch"; else fail "the next sync sweeps the sidecar and completes the restore (rc=$rc: $out: $(git -C "$co_b" status --porcelain | tr '\n' '|'))"; fi
# A link at plans/ itself: the recovery refuses before any sweep or walk,
# and a matching file behind the link is untouched.
printf 'Task 7o: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
plansroot7o="$TEST_ROOT/plans-7o-moved"; mv "$co_b/plans" "$plansroot7o"; ln -s "$plansroot7o" "$co_b/plans"
printf 'x\n' > "$plansroot7o/$(basename "$wsb")/progress.md.new.123"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7o.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'plans is a symbolic link' "$TEST_ROOT/p7o.err" && [ -f "$plansroot7o/$(basename "$wsb")/progress.md.new.123" ]; then pass "a link at plans/ itself stops the recovery before any sweep, and the file behind it is untouched"; else fail "a link at plans/ itself stops the recovery before any sweep (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7o.err"))"; fi
rm "$co_b/plans"; mv "$plansroot7o" "$co_b/plans"; rm -f "$wsb/progress.md.new.123"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7o: complete' "$wsb/progress.md" && [ -z "$(git -C "$co_b" status --porcelain)" ]; then pass "with plans/ a real directory again the recovery completes"; else fail "with plans/ a real directory again the recovery completes (rc=$rc: $out)"; fi
```

If that fixture's variables are named differently, use its names; the shape (crash after update-ref, plant the link, sync, repair, sync) is what matters.

- [ ] **Step 2: RED**

State suite (or extracted harness), needles `names the repair` (both the recovery case and the normal post-ref case): `[FAIL]` (today stderr carries `hp_contained`'s line and the generic `repair the working tree under` sentence, never `remove the link, leave`; the seam does not exist yet, so the second case applies cleanly and fails on `status=error`). Needle `comes back whole`: `[FAIL]` (the recovery restores only the diff, and the report is recorded as deleted). Needle `met by the post-apply re-walk`: `[FAIL]` (the seam does not exist, so the sync succeeds). Needle `completes the partial workspace`: `[FAIL]` (a restore keyed to the apply that created the directory does not run on the apply that finishes the recovery, and the report is recorded as deleted). Needle `deletion-only recovery brings the workspace back whole`: `[FAIL]` (only the first walk recorded the workspace, so the recovery leaves it absent). Needle `keeps the writer's bytes`: `[FAIL]` (the seam does not exist, so the branch's copy is restored). The `put back by the recovery` assertion passes as soon as the restore exists; it records the stance. Needle `sweeps nothing through the link`: `[FAIL]` (the sweep's glob expands through the directory link). Needle `never adopted`: `[FAIL]` (the writer's one-line ledger is accepted and the next snapshot truncates the branch's). Needle `keeps its tracked mode`: `[FAIL]` (the copy is written with the umask). Needle `leaves the copy in the sidecar`: `[FAIL]` (the crash value does not exist, so the sync completes with rc 0). Needle `stops the recovery before any sweep`: `[FAIL]` (the sweep's glob expands through the link at `plans/` and removes the file behind it, and nothing refuses the link before the walk). The delete-walk pair passes as soon as the second `hp_contained` check returns 4; it is coverage the gate asked for, not a RED of its own.

- [ ] **Step 3: A distinct code and one repair sentence**

In `apply_files`, change both `hp_contained "$CO" "$path" || return 2` lines (898 and 935) to `hp_contained "$CO" "$path" || return 4`, and add to the function's comment: `Returns 4 when a path it must write or remove sits under a symbolic link; the callers turn that into a repair the human can act on. Every workspace the apply writes into or removes from comes back whole: every path the target tracks under it that is still missing afterwards is published from the target.` Then make the function remember each workspace either walk touches and restore it whole. Its `local` line becomes `local S=$1 target=$2 path dir tmp half ws i last_ws="" touched_ws=()` (`tmp` is already there; `meta` is the `<mode> blob <id>` field `ls-tree -r` prints before the tab, and `n` numbers the copies, so add `meta n=0` to that line too) (`cmd_sync` already has a scalar `created`, so the array avoids that stem; shellcheck's SC2178 reads a scalar and an array of one name as one variable); right after the first walk's `hp_contained ... || return 4` line add:

```bash
    # Every workspace this walk writes into is remembered: the diff names
    # only what changed between S and the target, and a directory an
    # interrupted apply left holding those files alone would have the next
    # snapshot record its unchanged siblings as deletions. git lists paths
    # sorted, so one workspace's paths are contiguous.
    case "$path" in plans/*/*) ws=${path#plans/}; ws=${ws%%/*}; [ "$ws" = "$last_ws" ] || touched_ws[${#touched_ws[@]}]=$ws; last_ws=$ws ;; esac
```

and right after the second walk's `hp_contained ... || return 4` line add:

```bash
    # The delete walk records the workspace too: a deletion-only apply met
    # by a link at the directory must bring the rest back after the repair.
    # A workspace the target empties (a remote finish) tracks nothing
    # afterwards, so the pass below restores nothing there.
    case "$path" in plans/*/*) ws=${path#plans/}; ws=${ws%%/*}; [ "$ws" = "$last_ws" ] || touched_ws[${#touched_ws[@]}]=$ws; last_ws=$ws ;; esac
```

and replace the function's final `return 0` with:

```bash
  # Each workspace this apply wrote into or removed from comes back whole:
  # every path the target tracks under it that is still missing is
  # published from the target, with its tracked mode. A link at such a
  # path is refused and named, never skipped: skipped, the next snapshot
  # would commit it onto the branch. The publish is one link(2) from a
  # temporary copy in the .restore sidecar at the checkout root (never
  # inside a workspace, where a crash would leave it for a snapshot to
  # commit), so a file a writer creates between the check and the publish
  # is theirs; a ledger a writer creates there is reconciled, never
  # adopted.
  i=0
  while [ "$i" -lt "${#touched_ws[@]}" ]; do
    ws=${touched_ws[$i]}; i=$((i + 1))
    while IFS=$'\t' read -r meta path; do
      [ -n "$path" ] || continue
      hp_contained "$CO" "$path" || return 4
      [ ! -e "$CO/$path" ] || continue
      mkdir -p "$(dirname "$CO/$path")" "$CO/.restore" || return 2
      n=$((n + 1)); tmp="$CO/.restore/$$.$n"; rm -f "$tmp"
      git -C "$CO" show "$target:$path" > "$tmp" || { rm -f "$tmp"; return 2; }
      case "$meta" in 100755*) chmod 755 "$tmp" || { rm -f "$tmp"; return 2; } ;; esac
      if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = restore-after-copy ]; then hp_unlock; exit 99; fi
      # Test hook: a writer creates the file right before the publish.
      case "${HYPERPOWERS_TEST_WRITER_AT:-}" in sync-before-restore:*) [ "${HYPERPOWERS_TEST_WRITER_AT#sync-before-restore:}" != "$path" ] || printf 'concurrent write\n' > "$CO/$path" ;; esac
      if ! ln "$tmp" "$CO/$path" 2>/dev/null; then
        rm -f "$tmp"
        [ -e "$CO/$path" ] || return 2
        case "$path" in plans/*/progress.md) [ -f "$CO/$path" ] || return 2; ledger_apply "$path" "$S" "$target" || return $? ;; esac
        continue
      fi
      rm -f "$tmp"
    done < <(git -C "$CO" ls-tree -r "$target" -- "plans/$ws")
  done
  # Emptied, the sidecar goes with the apply that emptied it; a copy a
  # crash left behind keeps it until the next recovery sweeps it.
  rmdir "$CO/.restore" 2>/dev/null
  return 0
```

In `recover_apply`, the recovery must refuse a link at the two roots it walks before it walks them, and must sweep the restore sidecar (add `dir` to the function's `local` line). After the `.sync-applying` link check (`if [ -L "$CO/.sync-applying" ]; then ... fi`) add:

```bash
  if [ -L "$CO/.restore" ]; then
    echo "sdd-state: $CO/.restore is a symbolic link; refusing to sweep restore copies through it" >&2
    return 2
  fi
  # The sweep below and every apply walk under plans/: a link there would
  # take both out of the checkout.
  if [ -L "$CO/plans" ]; then
    echo "sdd-state: $CO/plans is a symbolic link; refusing to run recovery through it" >&2
    return 2
  fi
```

In the tracked-sidecar check that follows, change `git -C "$CO" ls-tree --full-tree HEAD -- .sync-applying .rewrite` to `git -C "$CO" ls-tree --full-tree HEAD -- .sync-applying .rewrite .restore`. Then replace

```bash
  # A new ledger interrupted between its temporary copy and its publish
  # leaves that copy inside a workspace, where a snapshot would commit it.
  rm -f "$CO"/plans/*/progress.md.new.* 2>/dev/null
```

with

```bash
  # A new ledger interrupted between its temporary copy and its publish
  # leaves that copy inside a workspace, where a snapshot would commit it;
  # only real workspace directories are swept, never a link at plans/<ws>.
  # A restored file's copy lives in the .restore sidecar, swept whole.
  for dir in "$CO"/plans/*/; do
    [ -d "$dir" ] && [ ! -L "${dir%/}" ] || continue
    rm -f "$dir"progress.md.new.* 2>/dev/null
  done
  rm -rf "$CO/.restore" 2>/dev/null
```

Beside `recover_apply` (before it) add:

```bash
# One sentence for the one failure a human clears by hand without reading
# code: a link where the apply writes or removes a regular file.
# hp_contained has just named the path.
say_link_repair() {
  echo "sdd-state: a symbolic link sits where sync writes or removes a regular file (named above); remove the link, leave $CO/.sync-applying in place, and run sdd-state sync again: the apply finishes from the branch" >&2
}
```

In `recover_apply` replace

```bash
  if [ "$rc" -ne 0 ]; then
    echo "sdd-state: an interrupted sync left $CO/.sync-applying and finishing it failed (rc=$rc); repair the working tree under $CO and run sdd-state sync again" >&2
    return 2
  fi
```

with

```bash
  if [ "$rc" -eq 4 ]; then say_link_repair; return 2; fi
  if [ "$rc" -ne 0 ]; then
    echo "sdd-state: an interrupted sync left $CO/.sync-applying and finishing it failed (rc=$rc); repair the working tree under $CO and run sdd-state sync again" >&2
    return 2
  fi
```

In `apply_target`, right after `git -C "$CO" reset -q 2>/dev/null` (line 1152, the ref has moved) and before the `for _ in 1 2 3; do` loop, add the seam:

```bash
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in sync-after-ref-link:*) rm -f "$CO/${HYPERPOWERS_TEST_WRITER_AT#sync-after-ref-link:}"; ln -s /dev/null "$CO/${HYPERPOWERS_TEST_WRITER_AT#sync-after-ref-link:}" ;; esac
```

In the `case "$res" in` that follows the loop, add the arm `4) say_link_repair; return 2 ;;` before `5|6) return 7 ;;` (the marker stays, as for every non-zero result), and in the `0)` arm (the post-apply re-walk) replace `hp_contained "$CO" "$path" || return 2` with `hp_contained "$CO" "$path" || { say_link_repair; return 2; }`. At the top of that `0)` arm, before its re-walk loop, add the second seam:

```bash
      # Test hook: a link planted after the apply and before the re-walk.
      case "${HYPERPOWERS_TEST_WRITER_AT:-}" in sync-after-apply-link:*) rm -f "$CO/${HYPERPOWERS_TEST_WRITER_AT#sync-after-apply-link:}"; ln -s /dev/null "$CO/${HYPERPOWERS_TEST_WRITER_AT#sync-after-apply-link:}" ;; esac
```

`cmd_sync` (lines 1277-1287) already turns any result other than 0, 5, 6 and 7 into `status=error` with exit 2, so a 2 from the new arm needs no change there; confirm by reading it.

- [ ] **Step 4: GREEN, quick suites, lint**

State suite, needles from Step 1 (all twenty-four): `[PASS]`, log GREEN. `bash tests/sdd/test-sdd-contract.sh` `STATUS: PASSED`. `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh` exit 0.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "fix(sdd-state): a link under a path the sync apply writes left the human without a repair"
```

---

### Task 7: `prune` lists and removes the copies killed removals left behind

**Risk tier:** high — deletes a directory that may be the only copy of a dossier, under the repository lock, with a stdout grammar change.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh` (new `hp_pid_gone`, beside `hp_utc_now` at line 76)
- Modify: `skills/subagent-driven-development/scripts/sdd-state:659-760` (`cmd_prune`), `:1073` (the apply's pending scan, where `plans/.removing-*` is exempted)
- Modify: `CHANGELOG.md` (the `## Unreleased` list)
- Test: `tests/sdd/test-sdd-state.sh:785-815` (the prune section), `tests/sdd/test-sdd-common.sh`

**Interfaces:**
- Consumes: the spec's prune paragraph (Task 1).
- Produces: `hp_pid_gone <pid>` returns 0 when `kill(pid, 0)` answers ESRCH and 1 otherwise (EPERM is alive). `status=listed plans=<list> checkouts=<list> tombs=<list> quarantined=<list>` and `status=pruned plans=<list> kept=<list> checkouts=<list> tombs=<list> quarantined=<list>`, comma-separated basenames percent-encoded with `enc`: on `listed`, `tombs=` names the `.removing-<ws>-<pid>` copies that qualify for quarantine and `quarantined=` the `.pruned-<ws>-<pid>` copies that qualify for deletion; on `pruned`, `tombs=` names the copies renamed to `.pruned-<ws>-<pid>` this run and `quarantined=` the copies deleted and verified gone this run. Removal is two-phase because a writer that still holds a copy open cannot be excluded: the rename keeps every byte such a writer adds, and the deletion waits until nothing in the quarantined copy is newer than N days. A `find` that fails keeps the copy. The seam value `HYPERPOWERS_TEST_WRITER_AT=prune-after-tomb-rename:<name>` touches the renamed copy's ledger between the rename and the re-check. The apply's pending scan reads `git status --porcelain -z -uall` NUL-delimited, so a path git would otherwise C-quote (a workspace name with a space) is seen plain, and a leftover that is the only entry under `plans/` is listed by its own files instead of the one collapsed `?? plans/` row that no exemption names, so the `.removing-*`, `.pruned-*` and ledger exemptions hold in both shapes; a put-back rename in either phase checks its destination first, and a `touch` that fails after the staging rename is doubt: the copy goes back. Phase one stages the copy at `plans/.quarantining-<ws>-<pid>`, a name neither phase lists, re-checks and touches it there, and only then renames it to `plans/.pruned-<ws>-<pid>`, so a crash anywhere in the transition leaves a copy the next `--apply` puts back to its tomb name (under the lock, before anything is listed), never one it can delete; the crash value `HYPERPOWERS_TEST_CRASH_AT=prune-after-stage` exits 99 (after `hp_unlock`) right after the staging rename, and the seam value `HYPERPOWERS_TEST_WRITER_AT=prune-reoccupy-tomb:<name>` touches the staged copy's ledger and recreates the tomb path, so the put-back meets an occupied destination. The apply's pending scan exempts `plans/.quarantining-*` as it does the other two, and all three exemptions apply only to a dotted entry the branch does not track at S: a pre-release workspace that carries such a name keeps its dirty rows in the scan, so a locally changed report there holds the apply (`status=busy`, the path named) and is never checked out over by a remote change to the same path, while its ledger still passes through the ledger exemption and is reconciled. A quarantine must parse as one (a numeric pid last) and must not be a path the branch tracks; the same tracked check guards the tomb loop and the put-back of staged copies, so a checkout from before this release that tracks a workspace named like a leftover (a dot-led plan name with an all-decimal hash) is never listed, moved or deleted; the publish rename checks its destination at its point of use like every other rename; and `hp_plan_ws_name` never yields a name that starts with a dot (a leading run of dots is dropped from the slug, an empty slug becomes `plan`), so a plan file named like a leftover cannot produce a workspace the loops or the scan would take for one.

**Mirror:** `tests/sdd/test-sdd-state.sh:785-802` (the prune fixture `pr`, `co_pr`, `wso`, `wsn`, the dead checkout `deadkey...`, full-string comparisons of the listing lines); `sdd-state:533-592` (rename aside, re-check, delete, verify, restore on doubt); `sdd-state:1061-1089` (the apply's pending scan: `git status --porcelain -- plans/` with `plans/.removing-*` exempted by name at line 1073; `.pruned-*` must be exempted there too, or every remote apply stays `busy` while a quarantine exists; `snapshot_pending`'s `plans/*/` glob already skips dotted names, and `restore_tombs` iterates `.removing-*` only).

- [ ] **Step 1: Write the failing tests**

In `tests/sdd/test-sdd-common.sh`, after the message-prefix block (Task 5), add:

```bash
# --- pid liveness ------------------------------------------------------------
sleep 0.01 & gone_pid=$!; wait "$gone_pid" 2>/dev/null
if hp_pid_gone "$gone_pid"; then pass "hp_pid_gone: a reaped pid is gone"; else fail "hp_pid_gone: a reaped pid is gone"; fi
if ! hp_pid_gone $$; then pass "hp_pid_gone: our own pid is alive"; else fail "hp_pid_gone: our own pid is alive"; fi
if ! hp_pid_gone 1; then pass "hp_pid_gone: a pid we may not signal (EPERM) is alive"; else fail "hp_pid_gone: a pid we may not signal (EPERM) is alive"; fi
```

In `tests/sdd/test-sdd-state.sh`, update the three full-string prune assertions at lines 793, 795 and 802 so each expected string ends with ` tombs= quarantined=` (both empty) in addition to what it compares today. In the p11 fixture (lines 1319-1324: a tomb left under `plans/` does not stop a fast-forward), add a quarantine beside the tomb before `advance 'line one'`:

```bash
quar_p11="$co_b/plans/.pruned-gone-1234abcd-999"; mkdir -p "$quar_p11"; printf 'quarantined copy\n' > "$quar_p11/progress.md"
# Names with a space: git status quotes such paths, and the scan must still
# see the leftovers for what they are.
tomb_p11s="$co_b/plans/.removing-old plan-1234abcd-999"; mkdir -p "$tomb_p11s"; printf 'orphaned copy\n' > "$tomb_p11s/progress.md"
quar_p11s="$co_b/plans/.pruned-old plan-1234abcd-999"; mkdir -p "$quar_p11s"; printf 'quarantined copy\n' > "$quar_p11s/progress.md"
```

and extend the p11 assertion that follows the sync so it also requires `[ -d "$quar_p11" ] && [ -d "$tomb_p11s" ] && [ -d "$quar_p11s" ]`, with its pass text changed to `a tomb or a quarantine left under plans/ by a removal, with or without a space in its name, does not stop the apply`; remove `$quar_p11`, `$tomb_p11s` and `$quar_p11s` where the fixture removes `$tomb_p11`. After that section's `the next sync after that crash...` assertion, add a workspace the branch tracks under a leftover's name (A commits it straight onto its checkout and pushes; B dirties its report; A changes the same report):

```bash
# A workspace the branch tracks under a leftover's name (a plan file from
# before this release whose name began with a dot): its dirty report holds
# the apply like any other workspace's, and a remote change to the same
# path never overwrites it.
co_a11="$STATE_ROOT/$(state_key "$PAIR_A")"; legacy11=".pruned-legacy-12345678"
mkdir -p "$co_a11/plans/$legacy11"; printf '# SDD ledger — plan: docs/legacy.md\n' > "$co_a11/plans/$legacy11/progress.md"; printf 'report v1\n' > "$co_a11/plans/$legacy11/task-1-report.md"
git -C "$co_a11" add -A plans/ && git -C "$co_a11" commit -qm legacy && git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'local edit\n' > "$co_b/plans/$legacy11/task-1-report.md"
printf 'report v2\n' > "$co_a11/plans/$legacy11/task-1-report.md"; git -C "$co_a11" add -A plans/ && git -C "$co_a11" commit -qm legacy2 && git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p11c.out" 2> "$TEST_ROOT/p11c.err"; rc=$?
out=$(cat "$TEST_ROOT/p11c.out")
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ] && grep -q "plans/$legacy11/task-1-report.md" "$TEST_ROOT/p11c.err" && [ "$(cat "$co_b/plans/$legacy11/task-1-report.md")" = "local edit" ]; then pass "a dirty report in a tracked workspace named like a leftover holds the apply and is not overwritten"; else fail "a dirty report in a tracked workspace named like a leftover holds the apply and is not overwritten (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p11c.err"))"; fi
printf 'report v1\n' > "$co_b/plans/$legacy11/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(cat "$co_b/plans/$legacy11/task-1-report.md")" = "report v2" ]; then pass "with the local edit put back the apply proceeds and the remote change lands"; else fail "with the local edit put back the apply proceeds and the remote change lands (rc=$rc: $out)"; fi
```

Then, at the end of the same `=== leftover entries under plans/ ===` section (after the block above; confirm the section that follows creates its own pair and workspace variables before using them), add a pair whose `plans/` holds no tracked entry when the leftover arrives:

```bash
# A leftover as the only entry under plans/: with no tracked entry there,
# git collapses the directory to one `?? plans/` row, which no exemption
# names and whose advice (move or delete the dossier root) is wrong; the
# scan lists untracked files one by one, so the row is the leftover's own.
make_pair p11b
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
co_b11="$STATE_ROOT/$(state_key "$PAIR_B")"
sole11="$co_b11/plans/.removing-gone-1234abcd-999"; mkdir -p "$sole11"; printf 'orphaned copy\n' > "$sole11/progress.md"
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p11b.out" 2> "$TEST_ROOT/p11b.err"; rc=$?
out=$(cat "$TEST_ROOT/p11b.out")
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ -f "$co_b11/plans/$(basename "$wsa")/progress.md" ] && [ -d "$sole11" ] && ! grep -q 'plans/ is not part of a plan workspace' "$TEST_ROOT/p11b.err"; then pass "a leftover that is the only entry under plans/ does not stop the apply"; else fail "a leftover that is the only entry under plans/ does not stop the apply (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p11b.err"))"; fi
rm -rf "$sole11"
```

(`make_pair` sets `PAIR_A`, `PAIR_B` and `PAIR_REMOTE`; the block reassigns `wsa`, so it must be the section's last fixture.) Then, after line 802's assertions and before the `--days 08` check at line 807, add:

```bash
# Copies killed removals left at plans/.removing-<ws>-<pid>: a gone pid,
# older than N days, and a workspace the branch does not track, is listed,
# quarantined by the first --apply, and deleted by a later one once nothing
# in it is newer than N days; a live pid, a young copy, a tracked workspace,
# or a copy written to after its rename is left alone.
sleep 0.01 & tp=$!; wait "$tp" 2>/dev/null
tomb_old="$co_pr/plans/.removing-gone-0badc0de-$tp"; mkdir -p "$tomb_old"; printf 'orphaned copy\n' > "$tomb_old/progress.md"; touch -t 202401010000 "$tomb_old/progress.md" "$tomb_old"
tomb_live="$co_pr/plans/.removing-live-0badc0de-$$"; mkdir -p "$tomb_live"; printf 'held by a live process\n' > "$tomb_live/progress.md"; touch -t 202401010000 "$tomb_live/progress.md" "$tomb_live"
tomb_young="$co_pr/plans/.removing-young-0badc0de-$tp"; mkdir -p "$tomb_young"; printf 'fresh copy\n' > "$tomb_young/progress.md"
tomb_tracked="$co_pr/plans/.removing-$(basename "$wsn")-$tp"; mkdir -p "$tomb_tracked"; printf 'tracked copy\n' > "$tomb_tracked/progress.md"; touch -t 202401010000 "$tomb_tracked/progress.md" "$tomb_tracked"
quar_old="$co_pr/plans/.pruned-gone-0badc0de-$tp"
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs=$(basename "$tomb_old") quarantined=\$"; then pass "prune lists a gone, idle, untracked tomb and nothing else"; else fail "prune lists a gone, idle, untracked tomb and nothing else (rc=$rc: $out)"; fi
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-after-tomb-rename:$(basename "$tomb_old")" bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$tomb_old" ] && [ ! -e "$quar_old" ]; then pass "a tomb written to after its rename is put back by the re-check"; else fail "a tomb written to after its rename is put back by the re-check (rc=$rc: $out)"; fi
touch -t 202401010000 "$tomb_old/progress.md" "$tomb_old"
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs=$(basename "$tomb_old") quarantined=\$" && [ ! -e "$tomb_old" ] && [ -d "$quar_old" ] && [ "$(cat "$quar_old/progress.md")" = "orphaned copy" ] && [ -d "$tomb_live" ] && [ -d "$tomb_young" ] && [ -d "$tomb_tracked" ]; then pass "the first --apply quarantines only the listed tomb, keeping its bytes"; else fail "the first --apply quarantines only the listed tomb (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$quar_old" ]; then pass "a fresh quarantine is not deleted by the next --apply"; else fail "a fresh quarantine is not deleted by the next --apply (rc=$rc: $out)"; fi
touch -t 202401010000 "$quar_old/progress.md" "$quar_old"
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=$(basename "$quar_old")\$"; then pass "an idle quarantine is listed for deletion"; else fail "an idle quarantine is listed for deletion (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=$(basename "$quar_old")\$" && [ ! -e "$quar_old" ] && ! ls -d "$quar_old".pruning-* >/dev/null 2>&1; then pass "the later --apply deletes the idle quarantine and verifies it is gone"; else fail "the later --apply deletes the idle quarantine (rc=$rc: $out)"; fi
rm -rf "$tomb_live" "$tomb_young" "$tomb_tracked"
# A crash after the staging rename: the copy sits under a name neither
# phase lists, the next --apply puts it back and quarantines it with a
# fresh clock, and the --apply after that does not delete it.
tomb_cr="$co_pr/plans/.removing-crash-0badc0de-$tp"; mkdir -p "$tomb_cr"; printf 'orphaned copy\n' > "$tomb_cr/progress.md"; touch -t 202401010000 "$tomb_cr/progress.md" "$tomb_cr"
( cd "$pr" && HYPERPOWERS_TEST_CRASH_AT=prune-after-stage bash "$SDD_STATE" prune --repo "$pr" --apply >/dev/null 2>&1 ); rc=$?
stage_cr="$co_pr/plans/.quarantining-crash-0badc0de-$tp"; quar_cr="$co_pr/plans/.pruned-crash-0badc0de-$tp"
if [ "$rc" -eq 99 ] && [ -d "$stage_cr" ] && [ ! -e "$tomb_cr" ] && [ ! -e "$quar_cr" ]; then pass "the crash seam after the staging rename leaves the copy under the staging name only"; else fail "the crash seam after the staging rename leaves the copy under the staging name only (rc=$rc)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$stage_cr" ]; then pass "a staged copy is listed by neither phase"; else fail "a staged copy is listed by neither phase (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs=$(basename "$tomb_cr") quarantined=\$" && [ ! -e "$stage_cr" ] && [ ! -e "$tomb_cr" ] && [ -d "$quar_cr" ] && [ "$(cat "$quar_cr/progress.md")" = "orphaned copy" ]; then pass "the next --apply puts the staged copy back and quarantines it"; else fail "the next --apply puts the staged copy back and quarantines it (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$quar_cr" ]; then pass "a quarantine made after a crash keeps its full grace period"; else fail "a quarantine made after a crash keeps its full grace period (rc=$rc: $out)"; fi
rm -rf "$quar_cr"
# A put-back whose destination is occupied again: the copy stays staged and
# is named, never nested into the new occupant.
tomb_oc="$co_pr/plans/.removing-occupied-0badc0de-$tp"; mkdir -p "$tomb_oc"; printf 'orphaned copy\n' > "$tomb_oc/progress.md"; touch -t 202401010000 "$tomb_oc/progress.md" "$tomb_oc"
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-reoccupy-tomb:$(basename "$tomb_oc")" bash "$SDD_STATE" prune --repo "$pr" --apply 2>"$TEST_ROOT/pr-oc.err"); rc=$?
stage_oc="$co_pr/plans/.quarantining-occupied-0badc0de-$tp"
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$stage_oc" ] && [ "$(cat "$stage_oc/progress.md")" = "orphaned copy" ] && [ -d "$tomb_oc" ] && [ ! -e "$tomb_oc/$(basename "$stage_oc")" ] && grep -q 'occupied again' "$TEST_ROOT/pr-oc.err"; then pass "a put-back whose destination is occupied again leaves the staged copy named, not nested"; else fail "a put-back whose destination is occupied again leaves the staged copy named, not nested (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/pr-oc.err"))"; fi
rm -rf "$tomb_oc" "$stage_oc"
# A quarantine whose deletion fails keeps the copy under the aside name and
# says so; nothing is reported as quarantined.
if [ "$(id -u)" -ne 0 ]; then
  quar_ro="$co_pr/plans/.pruned-ro-0badc0de-$tp"; mkdir -p "$quar_ro/sub"; printf 'orphaned copy\n' > "$quar_ro/sub/held"; touch -t 202401010000 "$quar_ro/sub/held" "$quar_ro/sub" "$quar_ro"; chmod 0555 "$quar_ro/sub"
  out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>"$TEST_ROOT/pr-ro.err"); rc=$?
  aside_ro=$(ls -d "$quar_ro".pruning-* 2>/dev/null | head -n 1)
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " quarantined=\$" && [ -n "$aside_ro" ] && [ -f "$aside_ro/sub/held" ] && grep -q 'could not be removed; remove it by hand' "$TEST_ROOT/pr-ro.err"; then pass "a quarantine whose deletion fails is kept under the aside name and named"; else fail "a quarantine whose deletion fails is kept under the aside name and named (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/pr-ro.err"))"; fi
  chmod 0755 "$aside_ro/sub" 2>/dev/null; rm -rf "$quar_ro" "$aside_ro"
else
  pass "a quarantine whose deletion fails is kept under the aside name and named (skipped: root ignores directory modes)"
fi
```

Then, at the end of the `=== prune ===` section (after the `prune under the plain backend reports plain` assertion and before the blank `echo ""` that precedes `=== sync ===`), add:

```bash
# A plan file named like a leftover: its workspace name never starts with
# a dot, so neither prune's loops nor the apply's scan can take it for one.
: > "$pr/docs/.pruned-demo.md"; git -C "$pr" add docs/.pruned-demo.md; git -C "$pr" commit -qm dotplan
wsd=$(run_sdd_dir "$pr" docs/.pruned-demo.md); printf 'dot plan\n' > "$wsd/progress.md"; run_state "$pr" snapshot docs/.pruned-demo.md >/dev/null
case "$(basename "$wsd")" in pruned-demo-*) pass "a plan file named like a quarantine gets a workspace name without the leading dot" ;; *) fail "a plan file named like a quarantine gets a workspace name without the leading dot (got $(basename "$wsd"))" ;; esac
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -f "$wsd/progress.md" ]; then pass "such a workspace is never listed as a tomb or a quarantine"; else fail "such a workspace is never listed as a tomb or a quarantine (rc=$rc: $out)"; fi
# A checkout from before this release may track a workspace named like a
# leftover (a dot-led plan name with an all-decimal hash): a tracked path
# is never a tomb, a quarantine or a staged copy, whatever its name.
for legacy in .removing-legacy-12345678 .pruned-legacy-12345678 .quarantining-legacy-12345678; do mkdir -p "$co_pr/plans/$legacy"; printf 'legacy dossier\n' > "$co_pr/plans/$legacy/progress.md"; done
git -C "$co_pr" add -A plans/ && git -C "$co_pr" commit -qm legacy
for legacy in .removing-legacy-12345678 .pruned-legacy-12345678 .quarantining-legacy-12345678; do touch -t 202401010000 "$co_pr/plans/$legacy/progress.md" "$co_pr/plans/$legacy"; done
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$"; then pass "tracked paths named like leftovers are listed as neither tomb nor quarantine"; else fail "tracked paths named like leftovers are listed as neither tomb nor quarantine (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$co_pr/plans/.removing-legacy-12345678/progress.md" ] && [ -f "$co_pr/plans/.pruned-legacy-12345678/progress.md" ] && [ -f "$co_pr/plans/.quarantining-legacy-12345678/progress.md" ] && [ -z "$(git -C "$co_pr" status --porcelain -- plans/)" ]; then pass "an --apply leaves tracked paths named like leftovers untouched"; else fail "an --apply leaves tracked paths named like leftovers untouched (rc=$rc: $out: $(git -C "$co_pr" status --porcelain -- plans/ | tr '\n' '|'))"; fi
```

`$co_pr`, `$pr` and `$wsn` are the prune fixture's checkout, repository and the `docs/new.md` workspace, which the branch tracks and which is never pruned (it is fresh). At the insertion point `wso` has already been pruned and `wsn` is kept, so the `plans=` field is empty on both lines and only the `tombs=` tail is asserted. The pid in `tomb_tracked`'s name is gone and the copy is old, so only the tracking rule keeps it.

- [ ] **Step 2: RED**

`bash tests/sdd/test-sdd-common.sh 2>&1 | grep -n 'hp_pid_gone'`: three `[FAIL]` (`command not found`). State suite (or extracted harness), needles `tomb`, `quarantine`, `prune lists the idle plan`, `a workspace writ`, and the two `status=pruned` full-string assertions: `[FAIL]` (no `tombs=` or `quarantined=` field today, no tomb handling); the p11 needle `does not stop the apply`: `[FAIL]` (the apply reports `busy` on the `.pruned-*` entry today, and on the space-named entries, which `git status` quotes so the exemptions never match them); the needle `only entry under plans/`: `[FAIL]` (`status=busy`, the collapsed `?? plans/` row names the dossier root as the stray); the needle `holds the apply and is not overwritten`: `[FAIL]` (the exemption is unconditional today, so the sync fast-forwards and checks the remote report out over the local edit). Needles `staging name only` and `keeps its full grace period`: `[FAIL]` (no staging name and no crash value today: the copy is renamed straight to `.pruned-*` and a crash before the `touch` leaves it eligible). Needle `occupied again leaves the staged copy named`: `[FAIL]` (no such seam value). Needle `deletion fails is kept under the aside name`: may already pass (the phase-two code keeps the copy and names it); it is the fail-closed proof the gate asked for. Needle `without the leading dot`: `[FAIL]` (`hp_plan_ws_name` keeps the dot today, and the listing then takes the workspace for a quarantine). Needle `listed as neither tomb nor quarantine`: `[FAIL]` (the tracked `.removing-legacy-12345678` is listed as a tomb: its pid is numeric and gone, its stamps old, and its derived workspace `legacy` untracked); `leaves tracked paths named like leftovers untouched`: `[FAIL]` (that tomb is quarantined, and the staged one put back over it or named as taken).

- [ ] **Step 3: `hp_pid_gone`**

Task 2's authorized sixth round added this helper to `sdd-common.sh` (after `hp_utc_now()`), with the three `test-sdd-common.sh` assertions below, because the reclaim's adoption branch needed it first. Verify the function and the tests exist exactly as written here; add only what is missing:

```bash
# <pid> -> 0 when the process is gone. kill(2) answers ESRCH for a pid that
# is gone and EPERM for one that exists but may not be signalled (another
# user's process, or any process from a sandboxed shell); only the first is
# death. bash's kill builtin folds both into exit 1, so node asks.
hp_pid_gone() {
  local answer
  answer=$(node -e 'try { process.kill(Number(process.argv[1]), 0); process.stdout.write("alive"); } catch (e) { process.stdout.write(e && e.code === "ESRCH" ? "gone" : "alive"); }' "$1" 2>/dev/null) || answer=alive
  [ "$answer" = gone ]
}
```

- [ ] **Step 4: The listing and the fail-closed removal**

In `cmd_prune`, add `tomb_list="" quar_list="" tomb_name tomb_pid tomb_ws tracked t q quar stage s q_pid` to the first `local` line and `tomb_dead=() quar_idle=()` to the array `local` line. Add two predicates inside the function (beside `idle`):

```bash
  # <tomb dir> <pid> <ws> -> 0 when the copy may be quarantined: its
  # process is gone, nothing in it is newer than N days, and the branch does
  # not track its workspace. A traversal or a tracking lookup that fails
  # (not an empty answer) keeps it.
  tomb_qualifies() {
    local newer
    hp_pid_gone "$2" || return 1
    newer=$(find "$1" -mtime -"$days" 2>/dev/null) || return 1
    [ -z "$newer" ] || return 1
    tracked=$(git -C "$co" ls-tree -d "refs/heads/$br" -- "plans/$3" 2>/dev/null) || return 1
    [ -z "$tracked" ]
  }
  # <quarantined dir> -> 0 when nothing in it is newer than N days: the
  # quarantine touched it when it was made, and a late writer refreshes it,
  # so the clock measures silence since the last of those.
  quarantine_idle() {
    local newer
    newer=$(find "$1" -mtime -"$days" 2>/dev/null) || return 1
    [ -z "$newer" ]
  }
```

Right after the line `if [ "$apply" -eq 1 ]; then CO=$co; BRANCH=$br; recover_apply || { hp_unlock; echo "status=error"; return 2; }; fi`, insert the put-back of staged copies a killed `--apply` left:

```bash
  # A copy a killed --apply left staged at plans/.quarantining-<ws>-<pid>
  # goes back to its tomb name before anything is listed: the lock is held,
  # so no other prune owns it, and neither phase lists the staging name.
  if [ "$apply" -eq 1 ] && [ -e "$co/.git" ]; then
    for s in "$co"/plans/.quarantining-*; do
      [ -d "$s" ] && [ ! -L "$s" ] || continue
      tracked=$(git -C "$co" ls-tree -d "refs/heads/$br" -- "plans/${s##*/}" 2>/dev/null) || continue
      [ -z "$tracked" ] || continue
      t="$co/plans/.removing-${s##*/.quarantining-}"
      if [ -e "$t" ] || [ -L "$t" ]; then echo "sdd-state: a staged copy from an interrupted prune is at $s and its tomb name $t is taken; move it back or delete it by hand" >&2; continue; fi
      mv "$s" "$t" 2>/dev/null || echo "sdd-state: the staged copy at $s could not be put back at $t; move it back by hand" >&2
    done
  fi
```

After the `if [ -e "$co/.git" ]; then ... fi` block that fills `plans` (it ends before the dead-checkout scan), insert:

```bash
  # Copies killed removals left at plans/.removing-<ws>-<pid>, and the ones
  # an earlier --apply quarantined at plans/.pruned-<ws>-<pid>. A tracked
  # workspace's copy comes back through sync's restore and is never listed.
  if [ -e "$co/.git" ]; then
    for t in "$co"/plans/.removing-*; do
      [ -d "$t" ] && [ ! -L "$t" ] || continue
      tomb_name=${t##*/}; tomb_pid=${tomb_name##*-}; tomb_ws=${tomb_name#.removing-}; tomb_ws=${tomb_ws%-*}
      case "$tomb_pid" in ''|*[!0-9]*) continue ;; esac
      # A tracked path under plans/ is a workspace whatever its name: a
      # checkout from before this release may hold one named like a tomb.
      tracked=$(git -C "$co" ls-tree -d "refs/heads/$br" -- "plans/$tomb_name" 2>/dev/null) || continue
      [ -z "$tracked" ] || continue
      tomb_qualifies "$t" "$tomb_pid" "$tomb_ws" || continue
      tomb_dead[${#tomb_dead[@]}]=$t; tomb_list="$tomb_list,$(enc "$tomb_name")"
    done
    for q in "$co"/plans/.pruned-*; do
      [ -d "$q" ] && [ ! -L "$q" ] || continue
      # The name must parse as a quarantine (a numeric pid last), and a
      # path the branch tracks is a workspace, never a quarantine.
      q_pid=${q##*-}; case "$q_pid" in ''|*[!0-9]*) continue ;; esac
      tracked=$(git -C "$co" ls-tree -d "refs/heads/$br" -- "plans/${q##*/}" 2>/dev/null) || continue
      [ -z "$tracked" ] || continue
      quarantine_idle "$q" || continue
      quar_idle[${#quar_idle[@]}]=$q; quar_list="$quar_list,$(enc "${q##*/}")"
    done
  fi
  tomb_list=${tomb_list#,}; quar_list=${quar_list#,}
```

Change the listing line to `echo "status=listed plans=$list checkouts=$dead_list tombs=$tomb_list quarantined=$quar_list"; return 0`.

With `--apply`, after the plans loop and its commit (after the `if [ "${#removed[@]}" -gt 0 ]; then ... fi` block and before `hp_unlock`), insert:

```bash
  # Phase one: a listed copy is staged under a name neither phase lists,
  # re-checked there (a writer with the directory open appends into it,
  # which the mtime check sees), touched so the clock starts again, and
  # only then renamed to its quarantine name; any doubt puts it back, and a
  # crash anywhere in between leaves a staged copy the next --apply puts
  # back. Nothing is deleted here, so a writer that still holds the copy
  # open loses no byte.
  tomb_list=""
  i=0
  while [ "$i" -lt "${#tomb_dead[@]}" ]; do
    t=${tomb_dead[$i]}; i=$((i + 1))
    tomb_name=${t##*/}; tomb_pid=${tomb_name##*-}; tomb_ws=${tomb_name#.removing-}; tomb_ws=${tomb_ws%-*}
    [ -d "$t" ] && [ ! -L "$t" ] || continue
    stage="$co/plans/.quarantining-${tomb_name#.removing-}"; quar="$co/plans/.pruned-${tomb_name#.removing-}"
    [ ! -e "$stage" ] && [ ! -L "$stage" ] && [ ! -e "$quar" ] && [ ! -L "$quar" ] || continue
    mv "$t" "$stage" 2>/dev/null || continue
    if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = prune-after-stage ]; then hp_unlock; exit 99; fi
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
      prune-after-tomb-rename:*) [ "${HYPERPOWERS_TEST_WRITER_AT#prune-after-tomb-rename:}" != "$tomb_name" ] || touch "$stage/progress.md" ;;
      prune-reoccupy-tomb:*) [ "${HYPERPOWERS_TEST_WRITER_AT#prune-reoccupy-tomb:}" != "$tomb_name" ] || { touch "$stage/progress.md"; mkdir -p "$t"; } ;;
    esac
    # A re-check that fails, or a clock that cannot be restarted, is doubt:
    # the copy goes back under its old name, after the same destination
    # check every rename here makes (BSD mv nests into an occupied one).
    if ! tomb_qualifies "$stage" "$tomb_pid" "$tomb_ws" || ! touch "$stage"; then
      if [ -e "$t" ] || [ -L "$t" ]; then echo "sdd-state: the copy renamed to $stage could not be put back at $t, which is occupied again; move it back by hand" >&2; continue; fi
      mv "$stage" "$t" 2>/dev/null || echo "sdd-state: the copy renamed to $stage could not be put back at $t; move it back by hand" >&2
      continue
    fi
    # The clock started on the staged copy, and rename keeps it. The
    # destination is checked here, at the rename, like every other.
    [ ! -e "$quar" ] && [ ! -L "$quar" ] || { echo "sdd-state: $quar appeared while $stage was staged; the next prune puts it back" >&2; continue; }
    mv "$stage" "$quar" 2>/dev/null || { echo "sdd-state: the staged copy at $stage could not be published at $quar; the next prune puts it back" >&2; continue; }
    tomb_list="$tomb_list,$(enc "$tomb_name")"
  done
  tomb_list=${tomb_list#,}
  # Phase two: a quarantined copy that has been silent for N days is
  # renamed aside once more, re-checked, deleted, and verified gone.
  quar_list=""
  i=0
  while [ "$i" -lt "${#quar_idle[@]}" ]; do
    q=${quar_idle[$i]}; i=$((i + 1))
    [ -d "$q" ] && [ ! -L "$q" ] || continue
    [ ! -e "$q.pruning-$$" ] && [ ! -L "$q.pruning-$$" ] || continue
    mv "$q" "$q.pruning-$$" 2>/dev/null || continue
    if ! quarantine_idle "$q.pruning-$$"; then
      if [ -e "$q" ] || [ -L "$q" ]; then echo "sdd-state: the copy renamed aside at $q.pruning-$$ could not be put back at $q, which is occupied again; move it back by hand" >&2; continue; fi
      mv "$q.pruning-$$" "$q" 2>/dev/null || echo "sdd-state: the copy renamed aside at $q.pruning-$$ could not be put back at $q; move it back by hand" >&2
      continue
    fi
    rm -rf "$q.pruning-$$" 2>/dev/null
    if [ -e "$q.pruning-$$" ] || [ -L "$q.pruning-$$" ]; then echo "sdd-state: the copy at $q.pruning-$$ could not be removed; remove it by hand" >&2; continue; fi
    quar_list="$quar_list,$(enc "${q##*/}")"
  done
  quar_list=${quar_list#,}
```

Change the final line to `echo "status=pruned plans=$list kept=$kept_list checkouts=$dead_list tombs=$tomb_list quarantined=$quar_list"`.

In `apply_target`'s pending scan (line 1073), replace `case "$path" in "plans/.removing-"*) continue ;; esac` with

```bash
      case "$path" in
        "plans/.removing-"*|"plans/.pruned-"*|"plans/.quarantining-"*)
          # Only an entry the branch does not track at S is a leftover: a
          # workspace from before this release may carry such a name, and
          # its dirty rows hold the apply like any other's (snapshot_pending
          # skips dotted directories, so nothing else would publish them).
          # A lookup that fails counts as tracked.
          top=${path#plans/}; top=${top%%/*}
          tracked=$(git -C "$CO" ls-tree -d "$S" -- "plans/$top" 2>/dev/null) || tracked=x
          [ -n "$tracked" ] || continue ;;
      esac
```

(add `top tracked` to `apply_target`'s `local` line), and extend the comment above it: a quarantined copy, or one staged on its way there, is as much a removal's leftover as a tomb and holds no apply. The scan must read its rows NUL-delimited, because `git status --porcelain` C-quotes a path with a space (`"plans/.pruned-old plan-..."`), and a quoted row matches none of the exemptions, so a space-named plan's leftover, or its dirty ledger, would hold every sync. Replace

```bash
  pending=$(git -C "$CO" status --porcelain -- plans/ 2>/dev/null)
  if [ -n "$pending" ]; then
    refused=0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      status=${line:0:2}; path=${line:3}
```

with

```bash
  # Rows are read NUL-delimited: the porcelain format C-quotes a path with
  # a space or an unusual byte, and a quoted row would match none of the
  # exemptions below. A rename row carries a second field, consumed here.
  refused=0
  while IFS= read -r -d '' line; do
    [ -n "$line" ] || continue
    status=${line:0:2}; path=${line:3}
    case "$status" in R*|C*) IFS= read -r -d '' _ ;; esac
```

and the loop's tail

```bash
    done < <(printf '%s\n' "$pending")
    if [ "$refused" -eq 1 ]; then NAMED_LEFTOVER=1; return 5; fi
  fi
```

with

```bash
  done < <(git -C "$CO" status --porcelain -z -uall -- plans/ 2>/dev/null)
  if [ "$refused" -eq 1 ]; then NAMED_LEFTOVER=1; return 5; fi
```

(`-uall` lists untracked files one by one: with no tracked entry under `plans/`, git would otherwise collapse the directory to a single `?? plans/` row, which no exemption names, so one leftover there would hold every sync and the advice would name the dossier root; `snapshot_pending` runs before this scan in `cmd_sync`, so a workspace not yet snapshotted is tracked by the time the scan runs and `-uall` cannot refuse it. Extend the comment above the loop with that sentence. The body between them keeps its text; re-indent it one level out, and drop `pending` from the function's `local` line if nothing else reads it). The deletion's last window, between the final `find` and `rm -rf` on a copy that has been silent for N days, is the one the spec already accepts for an idle plan's removal; the quarantine step is what keeps a writer's bytes out of it.

In `sdd-common.sh`'s `hp_plan_ws_name`, after `slug=$(basename "$1"); slug=${slug%.*}` add:

```bash
  # A workspace name never starts with a dot: dotted entries under plans/
  # are the leftovers of removals (.removing-, .quarantining-, .pruned-),
  # and a plan file named like one must not be taken for them. A plan file
  # from an earlier build whose name began with a dot continues in a new
  # workspace from here; its old directory, if the branch tracks one, stays
  # tracked and untouched (every walk skips dotted names, and a tracked
  # path is never taken for a leftover).
  slug=${slug#"${slug%%[!.]*}"}; [ -n "$slug" ] || slug=plan
```

- [ ] **Step 5: The changelog**

In `CHANGELOG.md` under `## Unreleased`, after the import bullet (Task 2), add:

```markdown
- **`prune` reclaims the copies killed removals leave, in two steps.** A `plans/.removing-<ws>-<pid>` whose process is gone, older than `--days`, and for a workspace the branch does not track, is listed as `tombs=`; the first `--apply` renames it to `plans/.pruned-<ws>-<pid>` (a writer that still holds it open loses nothing), and a later `--apply` deletes it once nothing in it is newer than `--days`, listing it as `quarantined=`. Tracked copies still come back through `sync`. The transition is staged under `plans/.quarantining-<ws>-<pid>` so a crash never leaves a copy the next prune could delete, and a plan file whose name starts with a dot gets a workspace name without it, so no new workspace under `plans/` starts with a dot; a tracked path is never taken for a leftover, whatever its name.
```

In the same list's **Upgrade notes** bullet, append the sentence: `A plan file whose name begins with a dot continues in a new workspace; its earlier workspace, if the branch tracks one, stays on the branch under the old name.`

- [ ] **Step 6: GREEN, quick suites, lint**

`bash tests/sdd/test-sdd-common.sh` and `bash tests/sdd/test-sdd-contract.sh` `STATUS: PASSED`. State suite, needles from Step 1: all `[PASS]`, log GREEN (p11's untracked tomb still does not stop `sync`, and a `.pruned-*` entry does not either). `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh tests/sdd/test-sdd-common.sh` exit 0.

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state CHANGELOG.md tests/sdd/test-sdd-state.sh tests/sdd/test-sdd-common.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(sdd-state): prune quarantines and then removes the copies killed removals left under plans/"
```

---

### Task 8: The fetch stamp names the remote and branch it fetched

**Risk tier:** high — a guard on checkout creation plus the writer of the file that guard reads.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh:57` (beside `hp_stamp_path`: new `hp_remote_fingerprint` and `hp_stamp_ok`), `:500-506` (the needs-sync check in `hp_ensure_checkout`; after Task 5 its message starts with `$HP_PROG:`)
- Modify: `skills/subagent-driven-development/scripts/sdd-state:1211-1233` (the four `: > "$stamp"` writes in `cmd_sync`)
- Modify: `CHANGELOG.md` (the `## Unreleased` list)
- Modify: `docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md` (the two stamp paragraphs: one sentence each on the refusal)
- Test: `tests/sdd/test-sdd-common.sh`, `tests/sdd/test-sdd-state.sh:109, 196, 204, 252, 323, 332, 673` (the seven lines that create an empty stamp) and the p1 block at lines 106-118

**Interfaces:**
- Consumes: the spec's stamp paragraphs (Task 1); `$HP_PROG` (Task 5); the `docs/plan.md` Task 3 creates in `PAIR_A`.
- Produces: `hp_remote_fingerprint <repo-dir>` prints the first 12 hex digits of the SHA-256 of `git remote get-url <configured remote>` (computed with node's `crypto`, since node is already a requirement of the helper and the repository's scripts use no other digest tool), or `none` when the remote has no URL. `hp_stamp_ok <repo-dir>` returns 0 when the stamp's first line equals `<hyperpowers.stateRemote or origin> <hyperpowers.stateBranch or hyperpowers/state> <fingerprint>`, so a repointed remote (`git remote set-url`) invalidates the stamp; `cmd_sync` writes that line on `assumed-absent`, `absent` and the fetched outcomes, and removes any stamp on `no-remote` (a repository without a remote creates freely, and a remote added later asks for one `sync` first); an empty or different stamp is `needs-sync` with the difference named. The stamp names the endpoint that was fetched: `cmd_sync` fingerprints the remote before the fetch, re-reads the remote, branch and fingerprint after it, and on any difference removes the stamp, prints `the remote changed during the sync` and ends `status=error` (exit 2) without creating anything; the seam value `HYPERPOWERS_TEST_WRITER_AT=sync-after-fetch-set-url:<url>` repoints the configured remote right after the fetch returns. The URL reaches node on stdin, never in argv (it may carry credentials). A fingerprint that cannot be computed (node missing or failing, output not twelve hex digits) is a failure, not an empty identity: `hp_remote_fingerprint` prints nothing and returns 1, `hp_stamp_ok` returns 1, and `cmd_sync` ends `status=error` with `the remote's URL could not be fingerprinted` and writes no stamp. The fetch itself is pinned to the URL that was fingerprinted: the remote alias is mutable, so `cmd_sync` reads the URL once, fingerprints that string (`hp_url_fingerprint`), and fetches it through a private alias injected in git's environment configuration (`GIT_CONFIG_COUNT`, git 2.31 or newer), so neither a repoint between the fingerprint and the fetch nor one that is undone before the stamp can make the stamp name an endpoint the fetch never contacted, and the URL stays out of argv; the private alias must be unconfigured in the repository (`remote.<name>.url` is multi-valued and git takes the first, so a repository that configures the alias's name could shadow the pin: `cmd_sync` refuses with `status=error` and names it), the caller's own `GIT_CONFIG_*` entries are kept (the pin is appended, never substituted), and `stamp_fetched` repeats the alias check right before it writes, so an alias configured during the fetch refuses the stamp too, and a git older than 2.31, which ignores environment configuration, is refused before the fetch with `status=error` naming the floor; the seam value `HYPERPOWERS_TEST_WRITER_AT=sync-aba-fetch:<url>` repoints the remote to `<url>` right before the fetch and back to the captured URL right after it, and `HYPERPOWERS_TEST_WRITER_AT=sync-shadow-alias:<url>` configures `remote.hp-fetch-<pid>.url` in the repository right before the uniqueness check. The pin is the remote's configured URL as written (the first value of `remote.<remote>.url` from `git config -z --get-all`, since git fetches from a multi-URL remote's first URL and `get-url` reports that one while `--get` returns the last, with `git remote get-url` as the fallback for a remote that has no `url` entry), never its rewritten form: git applies `url.<base>.insteadOf` once to whatever URL a remote carries, so a pin on the rewritten form would have a chained rule rewrite it again and the fetch contact an endpoint the fingerprint never named; the fingerprint is of the captured string's once-rewritten form, the URL the pinned fetch contacts, derived as described below and never by a second read. The fetch lands in a private ref, `refs/hp-fetch/<pid>`, never directly in `refs/remotes/<remote>/<branch>`: the tip is read from the private ref and that sha alone is reconciled; the remote-tracking ref is then updated by compare-and-swap from the value it held before the fetch (a lost swap is left to the fetch that won it); the private ref is deleted on every exit from the fetch, and private refs whose pid is gone are deleted before it. Seam `sync-after-fetch:<sha>` and a chained-`insteadOf` fixture (the remote's URL rewritten by one rule to one repository and that repository's path rewritten by a second rule to another: the sync reconciles the first repository's branch and stamps its fingerprint). The remote's URL is read exactly once per sync, as written (the first value of `remote.<remote>.url` from `git config -z --get-all`, or `git remote get-url` when there is no `url` entry; a two-URL remote, `git remote set-url --add`, is probed, fetched and stamped on its first URL and its second is never contacted); the once-rewritten form the fetch will contact is derived from that captured string, never from a second read of the remote's configuration: the private alias is env-configured to the captured string and probed with `git ls-remote --get-url hp-fetch-<pid>`, which expands a URL without contacting it (`git remote get-url` refuses a remote that only environment configuration defines); git applies `insteadOf` once there, exactly as it will at fetch time, and the URL stays out of argv, that result is fingerprinted, and the fetch pins the same captured string through the same alias; the alias-uniqueness check and the git 2.31 floor run before the probe, since the probe needs both. So a `remote set-url` at any point between the read and the stamp cannot make the fetch contact an endpoint the fingerprint did not name; what remains is a change to the `url.<base>.insteadOf` rules themselves between the probe and the fetch, which `stamp_fetched`'s re-read catches unless it is undone in that interval. Seam `sync-after-url-read:<url>` and a fixture with a second repository holding a valid state branch whose ledger line differs: the sync reconciles the configured repository's branch and stamps its fingerprint. A rule that changes after the probe cannot redirect the fetch either: the alias is pinned to a one-time name, `hp-pin://<nonce>/` with a fresh 128-bit nonce from node's `crypto` for this sync, and a second environment entry, `url.<probed endpoint>.insteadOf=hp-pin://<nonce>/`, maps that name to the probed endpoint. Git rewrites a URL once and prefers the longest matching `insteadOf`, so only a rule whose `insteadOf` is that exact one-time name could compete, and the name exists nowhere a rule could have been written for it; a rewrite that somehow did not apply would fetch an `hp-pin://` URL no transport serves, which fails rather than contacting anything. The probed endpoint, the fingerprint and the endpoint the fetch contacts are therefore one string, and `stamp_fetched`'s re-read remains the check that the configured remote still resolves to it. Seam `sync-aba-rewrite:<url>` and a fixture that, after the probe, adds a repository rule redirecting the probed endpoint to a second repository holding a valid state branch whose ledger line differs, and removes it after the fetch: the sync reconciles the probed repository's branch and stamps its fingerprint.

**Mirror:** `tests/sdd/test-sdd-state.sh:106-111` (p1: `make_pair`, `ensure`, the `needs-sync` needle, the stamp written by hand).

- [ ] **Step 1: Write the failing tests**

Both suites need a helper that prints a repository's fingerprint the way the library does; add to each, beside its other helpers: `fp() { ( . "$LIB"; hp_remote_fingerprint "$1" ); }` (the state suite defines `LIB` at its top as the common suite does; check and reuse the name it has).

In `tests/sdd/test-sdd-common.sh`, after the pid-liveness block (Task 7), add:

```bash
# --- fetch stamp --------------------------------------------------------------
repo_st="$TEST_ROOT/st"; make_repo "$repo_st"
stamp_st=$(hp_stamp_path "$repo_st"); mkdir -p "$(dirname "$stamp_st")"
if ! hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: no stamp is not ok"; else fail "hp_stamp_ok: no stamp is not ok"; fi
: > "$stamp_st"
if ! hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: an empty stamp (a pre-6.17 file) is not ok"; else fail "hp_stamp_ok: an empty stamp is not ok"; fi
if [ "$(hp_remote_fingerprint "$repo_st")" = none ]; then pass "hp_remote_fingerprint: a remote without a URL is none"; else fail "hp_remote_fingerprint: a remote without a URL is none (got: $(hp_remote_fingerprint "$repo_st"))"; fi
printf 'origin hyperpowers/state none\n' > "$stamp_st"
if hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: the configured remote, branch and fingerprint are ok"; else fail "hp_stamp_ok: the configured remote, branch and fingerprint are ok"; fi
printf 'origin hyperpowers/state\n' > "$stamp_st"
if ! hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: a stamp without the fingerprint is not ok"; else fail "hp_stamp_ok: a stamp without the fingerprint is not ok"; fi
git -C "$repo_st" remote add origin "$TEST_ROOT/one.git"
fp_one=$(hp_remote_fingerprint "$repo_st")
if [ "${#fp_one}" -eq 12 ] && [ "$fp_one" != none ]; then pass "hp_remote_fingerprint: a URL gives twelve hex digits"; else fail "hp_remote_fingerprint: a URL gives twelve hex digits (got: $fp_one)"; fi
printf 'origin hyperpowers/state %s\n' "$fp_one" > "$stamp_st"
if hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: the stamp matches the current URL"; else fail "hp_stamp_ok: the stamp matches the current URL"; fi
git -C "$repo_st" remote set-url origin "$TEST_ROOT/two.git"
if ! hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: a repointed remote invalidates the stamp"; else fail "hp_stamp_ok: a repointed remote invalidates the stamp"; fi
git -C "$repo_st" config hyperpowers.stateBranch other/state
printf 'origin other/state %s\n' "$(hp_remote_fingerprint "$repo_st")" > "$stamp_st"
if hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: the stamp follows the configured branch"; else fail "hp_stamp_ok: the stamp follows the configured branch"; fi
```

In `tests/sdd/test-sdd-state.sh`, change each of the seven lines `: > "$STATE_ROOT/<key expression>.fetched"` (lines 109, 196, 204, 252, 323, 332, 673) to `printf 'origin hyperpowers/state %s\n' "$(fp "<the repository the key expression names>")" > "$STATE_ROOT/<the same key expression>.fetched"` (for `$keyA`/`$keyB` at 196 and 204, the repositories those keys were computed from). Then, after the two Task 3 assertions (which sit between line 108 and the stamp write), add:

```bash
printf 'other hyperpowers/state %s\n' "$(fp "$PAIR_A")" > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
err=$(ensure "$PAIR_A" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q "needs-sync" && printf '%s' "$err" | grep -q "names 'other hyperpowers/state" && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ]; then pass "a stamp for another remote is needs-sync and names the difference"; else fail "a stamp for another remote is needs-sync and names the difference (rc=$rc: $err)"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ]; then pass "sync writes the remote, branch and URL fingerprint into the stamp"; else fail "sync writes the remote, branch and URL fingerprint into the stamp (rc=$rc: $out: $(cat "$STATE_ROOT/$(state_key "$PAIR_A").fetched" 2>/dev/null))"; fi
# A repointed remote: the stamp earned against one endpoint must not vouch
# for another once the checkout and the local branch are gone.
git -C "$PAIR_A" worktree remove --force "$STATE_ROOT/$(state_key "$PAIR_A")" >/dev/null 2>&1 || rm -rf "$STATE_ROOT/$(state_key "$PAIR_A")"; git -C "$PAIR_A" worktree prune; git -C "$PAIR_A" branch -D hyperpowers/state >/dev/null 2>&1
url_was=$(git -C "$PAIR_A" remote get-url origin); git -C "$PAIR_A" remote set-url origin "$TEST_ROOT/elsewhere.git"
err=$(ensure "$PAIR_A" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'needs-sync' && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ] && ! git -C "$PAIR_A" rev-parse -q --verify hyperpowers/state >/dev/null; then pass "a repointed remote makes the stamp stale: needs-sync and no branch created"; else fail "a repointed remote makes the stamp stale (rc=$rc: $err)"; fi
git -C "$PAIR_A" remote set-url origin "$url_was"
# A fingerprint that cannot be computed stops the sync: nothing is stamped
# and nothing is created.
mkdir -p "$TEST_ROOT/fakebin"; printf '#!/bin/sh\nexit 9\n' > "$TEST_ROOT/fakebin/node"; chmod 755 "$TEST_ROOT/fakebin/node"
rm -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
out=$(cd "$PAIR_A" && PATH="$TEST_ROOT/fakebin:$PATH" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-node.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'could not be fingerprinted' "$TEST_ROOT/p1-node.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ] && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ]; then pass "a fingerprint that cannot be computed stops the sync with nothing stamped or created"; else fail "a fingerprint that cannot be computed stops the sync (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-node.err"))"; fi
# A remote repointed while the fetch ran: the stamp must name the endpoint
# that was fetched, so the sync refuses to stamp and nothing is created.
race_b="$TEST_ROOT/p1-race.git"; git init -q --bare -b main "$race_b"
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT="sync-after-fetch-set-url:$race_b" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-race.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'changed during the sync' "$TEST_ROOT/p1-race.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ] && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ] && ! git -C "$PAIR_A" rev-parse -q --verify hyperpowers/state >/dev/null; then pass "a remote repointed during the fetch is not stamped and nothing is created"; else fail "a remote repointed during the fetch is not stamped and nothing is created (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-race.err"))"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ]; then pass "the next sync fetches the new endpoint and stamps it"; else fail "the next sync fetches the new endpoint and stamps it (rc=$rc: $out: $(cat "$STATE_ROOT/$(state_key "$PAIR_A").fetched" 2>/dev/null))"; fi
git -C "$PAIR_A" remote set-url origin "$url_was"
# A remote repointed to another endpoint between the fingerprint and the
# fetch, and back before the stamp: the fetch is pinned to the fingerprinted
# URL, so the other endpoint (which holds a branch under the state name) is
# never contacted, the outcome is still absent, and the stamp stays true.
aba_b="$TEST_ROOT/p1-aba.git"; git init -q --bare -b main "$aba_b"; git -C "$PAIR_A" push -q "$aba_b" main:refs/heads/hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT="sync-aba-fetch:$aba_b" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-aba.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ] && ! git -C "$PAIR_A" rev-parse -q --verify refs/remotes/origin/hyperpowers/state >/dev/null && [ "$(git -C "$PAIR_A" remote get-url origin)" = "$url_was" ]; then pass "a repoint away and back around the fetch never reaches the other endpoint: the fetch is pinned to the fingerprinted URL"; else fail "a repoint away and back around the fetch never reaches the other endpoint (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-aba.err"))"; fi
# A repository that configures the pinned fetch's own alias name could
# shadow the pin (remote.<name>.url is multi-valued, git takes the first):
# the sync refuses by name and stamps nothing.
rm -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT="sync-shadow-alias:$aba_b" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-shadow.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'configures a remote named hp-fetch-' "$TEST_ROOT/p1-shadow.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ] && ! git -C "$PAIR_A" rev-parse -q --verify refs/remotes/origin/hyperpowers/state >/dev/null; then pass "a repository that configures the pinned alias's name is refused and nothing is stamped"; else fail "a repository that configures the pinned alias's name is refused (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-shadow.err"))"; fi
for sec in $(git -C "$PAIR_A" config --name-only --get-regexp '^remote\.hp-fetch-' | sed 's/\.url$//'); do git -C "$PAIR_A" config --remove-section "$sec"; done
# A git older than 2.31 ignores environment configuration: the sync says
# so instead of failing as offline. The caller's own GIT_CONFIG_* entries
# survive the pin.
real_git=$(command -v git); mkdir -p "$TEST_ROOT/fakegit"; printf '#!/bin/sh\nif [ "$1" = --version ]; then echo "git version 2.30.2"; exit 0; fi\nexec "%s" "$@"\n' "$real_git" > "$TEST_ROOT/fakegit/git"; chmod 755 "$TEST_ROOT/fakegit/git"
out=$(cd "$PAIR_A" && PATH="$TEST_ROOT/fakegit:$PATH" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-oldgit.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q '2.31 or newer' "$TEST_ROOT/p1-oldgit.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ]; then pass "a git older than 2.31 is refused by name before the fetch"; else fail "a git older than 2.31 is refused by name before the fetch (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-oldgit.err"))"; fi
# The caller's entry is one the fetch depends on: a global policy forbids
# the file transport and only the caller's environment entry allows it, so
# a pin that replaced the caller's entries would end offline (get-url
# expands insteadOf rewrites, so a rewrite cannot play that part).
printf '[protocol "file"]\n\tallow = never\n' > "$TEST_ROOT/p1-global.gitconfig"
out=$(cd "$PAIR_A" && GIT_CONFIG_GLOBAL="$TEST_ROOT/p1-global.gitconfig" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ]; then pass "a caller's own environment configuration survives the pinned fetch"; else fail "a caller's own environment configuration survives the pinned fetch (rc=$rc: $out: $(cat "$STATE_ROOT/$(state_key "$PAIR_A").fetched" 2>/dev/null))"; fi
# Those syncs created the orphan; the checkout, the branch and the stamp go
# again, so the hand-written stamp below is what lets the next creation
# happen.
git -C "$PAIR_A" worktree remove --force "$STATE_ROOT/$(state_key "$PAIR_A")" >/dev/null 2>&1 || rm -rf "${STATE_ROOT:?}/$(state_key "$PAIR_A")"; git -C "$PAIR_A" worktree prune; git -C "$PAIR_A" branch -D hyperpowers/state >/dev/null 2>&1; rm -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
```

(The block ends with the remote restored and A's checkout, branch and stamp removed again, so the stamp written by hand on the next line is what the `the stamp allows the orphan` assertion exercises; the lines that follow in the p1 block, which write the stamp by hand and fetch, continue from there.)

(`PAIR_A`'s origin has no state branch at this point, so `sync` ends `absent` and writes the stamp; line 109's write that follows then rewrites the same content, which is harmless.) Find the existing `--assume-absent` assertion (`grep -n 'assume-absent' tests/sdd/test-sdd-state.sh`) and add after it one line checking that fixture's stamp reads `origin hyperpowers/state $(fp "<that fixture's repository>")`, in the same form as the check above. In the `=== sync ===` section, after the assertion `the second host creates its checkout from the remote` (B's first sync, a fetch that found the branch), add:

```bash
if [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_B").fetched")" = "origin hyperpowers/state $(fp "$PAIR_B")" ]; then pass "a fetch that found the branch writes the remote, branch and URL fingerprint into the stamp"; else fail "a fetch that found the branch writes the remote, branch and URL fingerprint into the stamp (got: $(cat "$STATE_ROOT/$(state_key "$PAIR_B").fetched" 2>/dev/null))"; fi
```

In `tests/sdd/test-sdd-common.sh`, at the end of the `# --- fetch stamp` block, add:

```bash
# A digest that cannot be computed is a failure, never an empty identity.
mkdir -p "$TEST_ROOT/fakebin"; printf '#!/bin/sh\nexit 9\n' > "$TEST_ROOT/fakebin/node"; chmod 755 "$TEST_ROOT/fakebin/node"
fp_fail=$(PATH="$TEST_ROOT/fakebin:$PATH" hp_remote_fingerprint "$repo_st"); rc=$?
if [ "$rc" -eq 1 ] && [ -z "$fp_fail" ]; then pass "hp_remote_fingerprint: a failing node is return 1 with no output"; else fail "hp_remote_fingerprint: a failing node is return 1 with no output (rc=$rc: '$fp_fail')"; fi
if [ "$(hp_url_fingerprint "$TEST_ROOT/one.git")" = "$fp_one" ]; then pass "hp_url_fingerprint: the URL's own digest is the remote's"; else fail "hp_url_fingerprint: the URL's own digest is the remote's"; fi
if ! PATH="$TEST_ROOT/fakebin:$PATH" hp_stamp_ok "$repo_st"; then pass "hp_stamp_ok: a stamp is not ok when the fingerprint cannot be computed"; else fail "hp_stamp_ok: a stamp is not ok when the fingerprint cannot be computed"; fi
```

(`$repo_st` carries a stamp that matches its real fingerprint at that point, so only the failing digest can make the second assertion pass.) Then add, beside the library suite's or the state suite's first no-remote fixture (a `make_repo` repository with no remote; `r3` at line 97 or the `r7` of the plain fixtures, whichever already runs `sync`), a `no-remote` check:

```bash
nr="$TEST_ROOT/nr"; make_repo "$nr"; mkdir -p "$nr/docs"; : > "$nr/docs/plan.md"
out=$(run_state "$nr" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=no-remote" ] && [ ! -e "$STATE_ROOT/$(state_key "$nr").fetched" ]; then pass "a no-remote sync leaves no stamp"; else fail "a no-remote sync leaves no stamp (rc=$rc: $out)"; fi
# The stamp governs creation only: a no-remote sync created a local branch
# here, which is continued, and a remote added later is reconciled by the
# next sync. The creation path is reached only when neither the checkout
# nor the local branch exists, so the fixture removes both before asking.
git -C "$nr" worktree remove --force "$STATE_ROOT/$(state_key "$nr")" >/dev/null 2>&1 || rm -rf "$STATE_ROOT/$(state_key "$nr")"; git -C "$nr" worktree prune; git -C "$nr" branch -D hyperpowers/state >/dev/null 2>&1
git -C "$nr" remote add origin "$TEST_ROOT/nowhere.git"
err=$(ensure "$nr" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'needs-sync' && [ ! -d "$STATE_ROOT/$(state_key "$nr")" ]; then pass "with its branch and checkout gone, a repository that gained a remote after a no-remote sync asks for a sync before any branch is created"; else fail "a repository that gained a remote after a no-remote sync asks for a sync (rc=$rc: $err)"; fi
# The realistic transition keeps the local branch: a remote that already
# holds another dossier is reconciled, never silently replaced or invented.
nr2="$TEST_ROOT/nr2"; make_repo "$nr2"; mkdir -p "$nr2/docs"; : > "$nr2/docs/plan.md"
run_state "$nr2" sync docs/plan.md >/dev/null; wsnr2=$(run_sdd_dir "$nr2" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsnr2/progress.md"; run_state "$nr2" snapshot docs/plan.md >/dev/null
git -C "$nr2" remote add origin "$PAIR_REMOTE"
out=$(run_state "$nr2" sync docs/plan.md 2>/dev/null); rc=$?
if [ "${out%% *}" = "status=diverged" ] && [ -f "$wsnr2/progress.md" ] && grep -q '^Task 1: complete' "$wsnr2/progress.md"; then pass "a remote gained after a no-remote sync is reconciled by the next sync (diverged, nothing invented, the local ledger kept)"; else fail "a remote gained after a no-remote sync is reconciled by the next sync (rc=$rc: $out)"; fi
```

(`ensure` is the suite's helper around `hp_ensure_checkout`; `$PAIR_REMOTE` is the bare origin of the most recent `make_pair`, whose `hyperpowers/state` already holds another plan's dossier, so the two orphan histories are unrelated and `sync` reports `diverged`; if the nearest `make_pair` origin carries no state branch at that point in the suite, run the block after one that does, or push `PAIR_A`'s state first as p11 does.) And an unreachable remote on a fresh clone, which must leave no stamp either:

```bash
ons="$TEST_ROOT/ons"; make_repo "$ons"; mkdir -p "$ons/docs"; : > "$ons/docs/plan.md"; git -C "$ons" remote add origin "$TEST_ROOT/nowhere.git"
out=$(run_state "$ons" sync docs/plan.md 2>/dev/null); rc=$?
if [ "${out%% *}" = "status=offline-no-state" ] && [ ! -e "$STATE_ROOT/$(state_key "$ons").fetched" ]; then pass "an offline sync with no state branch leaves no stamp"; else fail "an offline sync with no state branch leaves no stamp (rc=$rc: $out)"; fi
err=$(ensure "$ons" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'needs-sync'; then pass "after an offline sync creation still asks for a sync"; else fail "after an offline sync creation still asks for a sync (rc=$rc: $err)"; fi
```

(Read `cmd_sync`'s outcome for a failed fetch on a clone with no local state branch before relying on the token; if it is `offline` rather than `offline-no-state` for this shape, assert that token instead and say so in the report; either way no stamp may exist.)

- [ ] **Step 2: RED**

`bash tests/sdd/test-sdd-common.sh 2>&1 | grep -n 'hp_stamp_ok\|hp_remote_fingerprint'`: every new line `[FAIL]` (`command not found`). State suite (or extracted harness), needles `a stamp for another remote` (`[FAIL]`: creation proceeds today on any existing file), `writes the remote, branch and URL fingerprint` (`[FAIL]`: the stamp is empty today), `a repointed remote makes the stamp stale` (`[FAIL]`: any existing file vouches today), `cannot be computed stops the sync` (`[FAIL]`: an empty fingerprint is stamped today), `repointed during the fetch is not stamped` (`[FAIL]`: the seam does not exist and the fingerprint is read after the fetch), `pinned to the fingerprinted URL` (`[FAIL]`: the fetch resolves the alias at fetch time and reaches the other endpoint, so the outcome is `foreign` (rc 2) and a remote-tracking ref appears), `configures the pinned alias's name is refused` (`[FAIL]`: no check and no seam value today), `older than 2.31 is refused by name` (`[FAIL]`: no version check today), `environment configuration survives the pinned fetch` (`[FAIL]` against the replacing form of the pin, `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=... GIT_CONFIG_VALUE_0=...` as a command prefix, under which the caller's `protocol.file.allow=always` is dropped, the global `never` applies, git says `transport 'file' not allowed` and the sync ends `offline-no-state`; take that RED by reverting the fetch's environment lines to the replacing form for one harness run, since the append form is already in the tree), `a fetch that found the branch writes the remote` (`[FAIL]`: the stamp is empty today), the two common-suite `failing node` assertions (`[FAIL]`: an empty digest is accepted today), `a no-remote sync leaves no stamp` (`[FAIL]`: an empty stamp is written today), `gained a remote after a no-remote sync asks for a sync` (`[FAIL]`: the empty stamp vouches today), `reconciled by the next sync` (may already pass; it is the guard that the stamp never affects an existing branch), `an offline sync with no state branch leaves no stamp` and `after an offline sync creation still asks for a sync` (these two may already pass: `offline` outcomes write no stamp today; they are regression guards and the report says which way they went).

- [ ] **Step 3: The guard and the writer**

In `sdd-common.sh`, after `hp_stamp_path` (line 57), add:

```bash
# <repo-dir> -> the first 12 hex digits of the SHA-256 of the configured
# remote's fetch URL, or none when the remote has no URL. The stamp carries
# it so a remote repointed with set-url, which keeps its alias, cannot reuse
# a stamp earned against another endpoint.
# <url> -> the first 12 hex digits of its SHA-256. The URL may carry
# credentials: it reaches node on stdin, never in argv or the environment.
# A digest that cannot be computed is a failure, not an empty identity:
# callers fail closed on return 1.
hp_url_fingerprint() {
  local fp
  fp=$(printf '%s' "$1" | node -e 'const b=[];process.stdin.on("data",c=>{b.push(c)}).on("end",()=>{process.stdout.write(require("crypto").createHash("sha256").update(Buffer.concat(b)).digest("hex").slice(0,12))})' 2>/dev/null) || return 1
  case "$fp" in ????????????) ;; *) return 1 ;; esac
  case "$fp" in *[!0-9a-f]*) return 1 ;; esac
  printf '%s\n' "$fp"
}

hp_remote_fingerprint() {
  local url
  url=$(git -C "$1" remote get-url "$(hp_state_remote "$1")" 2>/dev/null) || { printf 'none\n'; return 0; }
  [ -n "$url" ] || { printf 'none\n'; return 0; }
  hp_url_fingerprint "$url"
}

# <repo-dir> -> 0 when the fetch stamp names the configured remote, branch
# and the remote's current URL fingerprint. A stamp from before 6.17 is an
# empty file; it, or a stamp written for another remote, branch or URL,
# means a sync is owed before any branch is created here.
hp_stamp_ok() {
  local have fp
  have=$(head -n 1 "$(hp_stamp_path "$1")" 2>/dev/null) || return 1
  fp=$(hp_remote_fingerprint "$1") || return 1
  [ "$have" = "$(hp_state_remote "$1") $(hp_state_branch "$1") $fp" ]
}
```

In `hp_ensure_checkout`, replace the block

```bash
    if hp_has_remote "$repo" && [ ! -f "$(hp_stamp_path "$repo")" ]; then
      echo "$HP_PROG: status=needs-sync: this repository has a remote and no state branch here; run sdd-state sync <plan> first (or sdd-state sync --assume-absent <plan>)" >&2
      hp_unlock; return 2
    fi
```

with

```bash
    if hp_has_remote "$repo" && ! hp_stamp_ok "$repo"; then
      have=$(head -n 1 "$(hp_stamp_path "$repo")" 2>/dev/null)
      fp=$(hp_remote_fingerprint "$repo") || fp=unavailable
      if [ -n "$have" ]; then
        echo "$HP_PROG: status=needs-sync: the fetch stamp names '$have' but the configured remote, branch and URL fingerprint are '$remote $br $fp'; run sdd-state sync <plan> first" >&2
      else
        echo "$HP_PROG: status=needs-sync: this repository has a remote and no state branch here; run sdd-state sync <plan> first (or sdd-state sync --assume-absent <plan>)" >&2
      fi
      hp_unlock; return 2
    fi
```

and add `have fp` to the function's `local` line (`remote` and `br` are already its locals).

In `cmd_sync`, the stamp must name the endpoint that was fetched, and a fingerprint that cannot be computed must stop the sync. Add `url_before fp_before fp_after n` to its `local` line. Replace the `no-remote` write (line 1212) with `rm -f "$stamp"` (a stamp written without a fetch would vouch for a remote named later, so a repository without a remote leaves none and creates on the strength of `hp_has_remote` alone), and replace the `assumed-absent` write (line 1211) with

```bash
  if [ "$assume" -eq 1 ]; then
    fp_before=$(hp_remote_fingerprint "$PLAN_DIR") || { echo "sdd-state: the remote's URL could not be fingerprinted (node is required); nothing was stamped. Run sdd-state sync again" >&2; echo "status=error"; return 2; }
    printf '%s %s %s\n' "$REMOTE" "$BRANCH" "$fp_before" > "$stamp"; settle assumed-absent 0; return $?
  fi
```

Replace the fetch line `err=$(GIT_HTTP_LOW_SPEED_LIMIT=1 GIT_HTTP_LOW_SPEED_TIME=30 git -C "$PLAN_DIR" fetch -q "$REMOTE" "+refs/heads/$BRANCH:refs/remotes/$REMOTE/$BRANCH" 2>&1); rc=$?` with the capture, the pinned fetch and the seams:

```bash
  # The stamp names the endpoint that was fetched. The remote alias is
  # mutable, so the URL is read once, fingerprinted as that string, and the
  # fetch is pinned to it through a private alias in git's environment
  # configuration (the URL stays out of argv); the remote, branch and URL
  # are read again after the fetch, and any difference means a repoint
  # raced it, so nothing is stamped.
  url_before=$(git -C "$PLAN_DIR" remote get-url "$REMOTE" 2>/dev/null) || url_before=""
  if [ -n "$url_before" ]; then
    fp_before=$(hp_url_fingerprint "$url_before") || { echo "sdd-state: the remote's URL could not be fingerprinted (node is required); nothing was stamped. Run sdd-state sync again" >&2; echo "status=error"; return 2; }
  else
    fp_before=none
  fi
  # Environment configuration needs git 2.31; an older git ignores it and
  # would fetch nothing, diagnosed as offline, so it is refused by name.
  hp_git_version_at_least 2 31 || { echo "sdd-state: git 2.31 or newer is required to pin the fetch to the fingerprinted URL (found $(git --version)); nothing was stamped" >&2; echo "status=error"; return 2; }
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
    sync-aba-fetch:*) git -C "$PLAN_DIR" remote set-url "$REMOTE" "${HYPERPOWERS_TEST_WRITER_AT#sync-aba-fetch:}" ;;
    sync-shadow-alias:*) git -C "$PLAN_DIR" config "remote.hp-fetch-$$.url" "${HYPERPOWERS_TEST_WRITER_AT#sync-shadow-alias:}" ;;
  esac
  # remote.<name>.url is multi-valued and git takes the first value, so a
  # repository that configures the alias's name would shadow the pin.
  if git -C "$PLAN_DIR" config --get-regexp "^remote\.hp-fetch-$$\." >/dev/null 2>&1; then
    echo "sdd-state: the repository configures a remote named hp-fetch-$$, which the pinned fetch needs for itself; remove that section from its git config and run sdd-state sync again" >&2
    echo "status=error"; return 2
  fi
  # The pin is appended to whatever GIT_CONFIG_* the caller supplied, never
  # substituted for it, and the URL travels in the environment, not argv.
  n=${GIT_CONFIG_COUNT:-0}; case "$n" in ''|*[!0-9]*) n=0 ;; esac
  printf -v "GIT_CONFIG_KEY_$n" '%s' "remote.hp-fetch-$$.url"; printf -v "GIT_CONFIG_VALUE_$n" '%s' "$url_before"
  export "GIT_CONFIG_KEY_$n" "GIT_CONFIG_VALUE_$n"
  err=$(GIT_HTTP_LOW_SPEED_LIMIT=1 GIT_HTTP_LOW_SPEED_TIME=30 GIT_CONFIG_COUNT=$((n + 1)) git -C "$PLAN_DIR" fetch -q "hp-fetch-$$" "+refs/heads/$BRANCH:refs/remotes/$REMOTE/$BRANCH" 2>&1); rc=$?
  unset "GIT_CONFIG_KEY_$n" "GIT_CONFIG_VALUE_$n"
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
    sync-aba-fetch:*) git -C "$PLAN_DIR" remote set-url "$REMOTE" "$url_before" ;;
    sync-after-fetch-set-url:*) git -C "$PLAN_DIR" remote set-url "$REMOTE" "${HYPERPOWERS_TEST_WRITER_AT#sync-after-fetch-set-url:}" ;;
  esac
```

(A remote without a URL makes `url_before` empty: the pinned fetch then fails as `git fetch origin` did, and the `offline` outcomes follow unchanged. The `--assume-absent` arm keeps `hp_remote_fingerprint`, since it fetches nothing.)

Beside `settle`, add the writer both fetched outcomes call:

```bash
  # Writes the stamp for the endpoint the fetch contacted, or refuses.
  stamp_fetched() {
    # The alias check runs again here: a remote named like the alias and
    # configured during the fetch could have shadowed the pin.
    if git -C "$PLAN_DIR" config --get-regexp "^remote\.hp-fetch-$$\." >/dev/null 2>&1; then
      rm -f "$stamp"
      echo "sdd-state: the repository configured a remote named hp-fetch-$$ during the sync; nothing was stamped. Remove that section from its git config and run sdd-state sync again" >&2
      return 1
    fi
    fp_after=$(hp_remote_fingerprint "$PLAN_DIR") || fp_after=unavailable
    if [ "$fp_after" != "$fp_before" ] || [ "$(hp_state_remote "$PLAN_DIR") $(hp_state_branch "$PLAN_DIR")" != "$REMOTE $BRANCH" ]; then
      rm -f "$stamp"
      echo "sdd-state: the remote changed during the sync (remote, branch or URL); nothing was stamped. Run sdd-state sync again" >&2
      return 1
    fi
    printf '%s %s %s\n' "$REMOTE" "$BRANCH" "$fp_before" > "$stamp"
  }
```

and replace the `absent` write (line 1216) with `*"couldn't find remote ref"*) stamp_fetched || { echo "status=error"; return 2; }; settle absent 0; return $? ;;` and the fetched-outcome write (line 1233) with `stamp_fetched || { echo "status=error"; return 2; }`.

In the spec, after the creation paragraph's sentence that ends `means a fresh ``sync``).` (around line 197), add the sentence: `A ``sync`` whose remote, branch or URL changed while its fetch ran, or whose fingerprint cannot be computed (node is required), ends ``status=error`` and stamps nothing, so the stamp always names the endpoint that was fetched (the fetch itself is pinned to that URL through git's environment configuration, which needs git 2.31 or newer; that fetch consults no other ``remote.<name>.*`` setting of the alias, so a per-remote ``proxy`` or ``uploadpack`` does not apply to it, while ``http.*``, ``url.*.insteadOf`` and credential helpers do; the URL is taken after git's ``insteadOf`` rewriting, so the stamp names the effective endpoint and a changed rewrite asks for a ``sync`` like a changed URL).` In the Constraints section (around line 948), change `Core skills depend on bash, git, and node only.` to `Core skills depend on bash, git (2.31 or newer, for the pinned state-branch fetch) and node only.` And in the `sync` entry, after `(which removes any stamp)` (around line 340), add: `; a remote, branch or URL that changed while the fetch ran, or a fingerprint that cannot be computed, ends the sync with ``status=error`` and nothing stamped`.

- [ ] **Step 4: The changelog**

In `CHANGELOG.md` under `## Unreleased`, after the prune bullet (Task 7), add:

```markdown
- **The fetch stamp names its remote, branch and endpoint.** `<key>.fetched` now holds `<remote> <branch> <fingerprint of the fetch URL>`, and a checkout is created only when it names the configured `hyperpowers.stateRemote` and `hyperpowers.stateBranch` and the remote's current URL (a repointed remote asks for a sync); a `no-remote` sync leaves no stamp, so a remote added later asks for one `sync` first; a stamp from an earlier build is empty and asks for one `sdd-state sync`, after which it is current. The stamp names the endpoint the fetch contacted: the fetch is pinned to the URL that was fingerprinted (through git's environment configuration, git 2.31 or newer), a remote changed around the fetch, or a fingerprint that cannot be computed, ends the sync with `status=error` and nothing stamped, so creating a checkout in a repository with a remote now needs `node` (already required by `sdd-state`'s import, claim and recovery paths).
```

- [ ] **Step 5: GREEN, quick suites, lint**

`bash tests/sdd/test-sdd-common.sh`, `bash tests/claude-code/test-sdd-dir-path.sh`, `bash tests/sdd/test-sdd-contract.sh` `STATUS: PASSED`. State suite, needles from Step 2: all `[PASS]`, log GREEN; `the stamp allows the orphan` must reach the creation path (with the checkout, branch and stamp removed, a stamp replaced by `bogus hyperpowers/state deadbeefcafe` makes `ensure` refuse: check that by hand once and report it). `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-common.sh tests/sdd/test-sdd-state.sh` exit 0. (The dir-path suite's needs-sync fixture writes no stamp and still expects `needs-sync`; its later fixtures create their stamps through `sync`, so they pass unchanged.)

- [ ] **Step 6: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-common.sh tests/sdd/test-sdd-state.sh CHANGELOG.md docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "fix(sdd-state): the fetch stamp vouched for whichever remote and branch happened to be configured later"
```
