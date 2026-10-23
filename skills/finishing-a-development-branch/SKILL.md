---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

**Core principle:** Record decisions and verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

**REQUIRED SUB-SKILL:** Use hyperpowers:communication for the test-failure report and the PR description. The option menus below are presented exactly as written.

## Step 1: Record Decisions and Verify Tests

A branch that implements a spec leaves one record per decision in the
`decisions/` directory beside the spec's directory, compiled by
`scripts/decisions-compile` in this skill's directory from the spec's
`## Decisions` list, with the plan removed in the same commit. The records
ride the branch before any merge or push, so they are staged here and
committed in Step 4 once your human partner has seen them. Work with no spec
has no records: for it, this step is the test run alone.

1. **Find the plan and the spec.** Start from the repository root:

   ```bash
   cd "$(git rev-parse --show-toplevel)"
   ```

   Run this step and Step 4 from the repository root; every path below is
   repository-relative, as the compiler and the pathspec file expect. Then
   fix the fork point, in every case, because the steps below diff and
   search from it (the base branch is whatever this work forked from,
   usually named in the plan, the conversation, or the branch's upstream;
   when it is not already known, ask now, before anything below runs: "This
   branch split from <your best guess> - is that correct?"):

   ```bash
   MERGE_BASE=$(git merge-base <base-branch> HEAD)
   ```

   The subagent-driven-development hand-off names both. Otherwise read the
   branch's history, not its tree, so a plan an earlier records commit
   removed is still found:

   ```bash
   git log --diff-filter=A --name-only --format= "$MERGE_BASE"..HEAD -- '*/plans/*.md'
   ```

   Exactly one plan is the plan; read its `**Spec:**` header from the commit
   that added it (`git show <sha>:<path>`). More than one: ask your human
   partner which applies. A plan without a Spec header, or with `none`: ask
   the same way. No plan: when the branch's history added or changed a spec
   (`git log --diff-filter=AM --name-only --format= "$MERGE_BASE"..HEAD -- '*/specs/*.md'`),
   ask whether records are wanted for it, and if so there is a spec and no
   plan; when it did neither, the work is bounded: there is no spec, skip
   the extractor and go to the test run in item 3.
2. **Take a scratch directory and dry-run the compiler.** The directory
   comes from `../requesting-code-review/scripts/codex-review-dir` (one per
   finish; the extractor's output and the pathspec file `records.paths` live
   in it, whether or not an extractor is dispatched). Then
   `bash <this skill's directory>/scripts/decisions-compile <spec> --dry-run`,
   with `--plan <plan>` added when a plan was found.
   Exit 2 for a missing decisions list is the legacy-spec case: draft the
   `## Decisions` list from the spec's own text, one item per decision it
   states, show it to your human partner, and write it into the spec once
   they approve it, and commit that edit on the branch before going on (a
   docs commit of the spec alone; the compiler requires a committed spec,
   and a skip restores the spec from HEAD). Any other exit 2 names what to fix first (a spec that is
   not committed, a plan that is not a tracked and clean markdown file under
   `plans/` whose Spec header names this spec, or a `Supersedes:` problem):
   resolve it with them before going on. Keep the numbered listing for the
   extractor.
3. **Dispatch the extractor, then run the suite.** Skip the dispatch when the
   branch has no spec, when the hand-off already names an extractor (a task
   id and an output path), when the branch already carries this spec's
   records commit (`git log "$MERGE_BASE"..HEAD --fixed-strings --grep="docs: record decisions for <spec filename without -design.md>"`,
   the subject Step 4's commit uses for this spec), or
   when your harness has no tracked background subagent (then say so when
   you hand back). Otherwise compose the dispatch from
   [decision-notes-prompt.md](decision-notes-prompt.md) with the merge-base
   diff and `<dir>/decision-notes.md` as its output path, and start it in
   the background. Then run the project's full test suite in the
   foreground (`npm test` / `cargo test` / `pytest` / `go test ./...`).
4. **If tests fail**, stop a still-running extractor (TaskStop), report the
   failures and stop — the menu comes after a green suite. Nothing is
   compiled; the plan stays.

   ```
   Tests failing (<N> failures). Must fix before completing:

   [Show failures]
   ```

5. **If tests pass** and the branch has a spec, collect the extractor without
   waiting: finished, its file is the `--notes`; unfinished, stop it
   (TaskStop), compile without notes, and say so when you hand back. The spec
   must be clean before the compile (no uncommitted edits; commit or stash
   them), because a skip restores it from HEAD. Run
   `bash <this skill's directory>/scripts/decisions-compile <spec> --plan <plan> --notes <file> --paths-file <dir>/records.paths`,
   omitting `--plan` when the branch has no plan and `--notes` when there is
   no notes file. A `notes ignored:` line on its stderr is repeated verbatim
   when you hand back. On exit 2, resolve the named problem and re-run; on
   exit 3, report the git failure and re-run once it is cleared. Nothing is
   committed here; the staged set waits for Step 4. Continue to Step 2.

## Step 2: Detect Environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# Capture now, while still inside the workspace — Step 5 changes directory
# before cleanup (Step 6) needs this value
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 3 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 3 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 2 options (no merge) | Externally managed — leave in place |

## Step 3: Determine Base Branch

The base branch is the one Step 1 confirmed; when Step 1 had no spec and did
not ask, confirm it here the same way (ask "This branch split from <your
best guess> - is that correct?"). Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**When Step 1 staged records,** the message that presents the options, from
the repository root as in Step 1, opens
with the complete staged diff over the pathspec file's paths (`git diff` has
no pathspec-file option, so the NUL-delimited file is read into an array; a
path with a space survives, and the variable makes the entries literal, as
the compiler's own git calls are, so a bracket or star in a spec name
matches only itself):

```bash
PATHS_FILE=<dir>/records.paths
paths=(); while IFS= read -r -d '' p; do paths+=("$p"); done < "$PATHS_FILE"
GIT_LITERAL_PATHSPECS=1 git diff --cached -- "${paths[@]}"
```

The message carries that command's output itself, verbatim; a summary, a
list of paths or a pointer to a tool result is not the diff, and no option is
accepted until the diff has been shown. Then the extractor's proposals from
its notes file, each with the question
it needs: an undocumented decision (add it to the spec's `## Decisions`
list, or dismiss it); a proposed supersession (add a
`Supersedes: <record path>` line to the item that reverses that record, or
dismiss it); then one line offering to skip the records for this branch; and
only then the menu text exactly as written below. Your human partner answers
once. An answer that names an option but leaves any proposal without a
disposition is incomplete: ask for the missing dispositions and wait; nothing
is written or committed until every proposal has one. A skip is settled
before any accepted proposal is written: an answer that both accepts a
proposal and skips is incomplete, so ask which they mean. Unless they chose
the skip, before executing their option: write each accepted proposal into the spec (an accepted undocumented
decision is appended after the list's last item, never inserted, so the
numbers the notes use stay with their records; an accepted supersession is a
`Supersedes:` line on the item it belongs to),
then re-run the compiler with the same arguments (it stages the spec,
carrying the proposal and the Outcome line, with the records and the index),
and because the staged set
changed, show the new complete staged diff and ask only for its approval,
not the dispositions again; record a dismissal in the hand-back in their
words. An approval leads to the one records commit below, which takes the
spec too through the pathspec file; a withheld approval commits nothing,
keeps the staged set and the spec edit in place, and asks what to change (the
skip was settled before any proposal was written, so `--undo` is not this
path's tool). If they change their mind to a skip at that point, first take
the accepted proposal back out of the spec and record its text in the
hand-back, so `--undo` does not discard their words silently; then follow the
skip path. A skip ends the records for this branch:
run `bash <this skill's directory>/scripts/decisions-compile --undo <spec> --plan <plan>` (without `--plan` when there
is none), record it in their words, make no commit, and run the option they
chose. Otherwise commit:

```bash
GIT_LITERAL_PATHSPECS=1 git commit --pathspec-from-file=<dir>/records.paths --pathspec-file-nul -m "docs: record decisions for <spec filename without -design.md>"
```

The message is that one line and nothing else: no second `-m`, no trailer, no
attribution or `Co-Authored-By` line, whatever the harness suggests. An empty
pathspec file means there is nothing to commit (the branch already carries
its records): skip the commit and run the chosen option.

The option runs only after that commit succeeds. If it fails (a hook, an
index conflict, anything), show the failure, stop, and run the same commit
again once the cause is cleared; nothing is merged or pushed while the
records and the plan's deletion are merely staged.

Then run the option they chose. A branch with no records shows the menu as it
always did.

**Normal repo and named-branch worktree — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?
```

**Detached HEAD — present exactly these 2 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Present the menu exactly as written — concise, with every option coming
from the list above. Discarding the work happens only in response to your
human partner explicitly asking for it (see "If your human partner asks to
discard the work" below). Wait for their answer; the integration decision
is theirs.

## Step 5: Execute Choice

### Option 1: Merge Locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the worktree and branch in
place, and investigate — nothing has been pushed, so the merge is local
and recoverable.

Once the merged result is green: clean up the worktree (Step 6), then
delete the branch:

```bash
git branch -d <feature-branch>
```

### Option 2: Push and Create PR

```bash
git push -u origin <feature-branch>
# From a detached HEAD, name the new branch on the remote:
# git push origin HEAD:refs/heads/<new-branch>
```

Then create the pull/merge request against <base-branch> with the forge's
tooling — its CLI if one is available, or the creation URL most forges
print when you push — following the repo's PR template and conventions if
present, and report the URL to your human partner.

Keep the worktree — your human partner iterates on PR feedback there.

### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then clean up the worktree (Step 6) and force-delete the branch:

```bash
git branch -D <feature-branch>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always
preserve the worktree. Both callers have already changed directory to the
main repo root — worktree removal must run from outside the worktree —
and use the `GIT_DIR`/`GIT_COMMON`/`WORKTREE_PATH` values captured in
Step 2, from before that directory change.

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** Superpowers
created this worktree — we own cleanup:

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**If removal is refused** (`contains modified or untracked files`): the
worktree holds files that exist nowhere else — uncommitted plans, notes,
or scratch work. Never `--force` on your own initiative. Show your human
partner what is at stake and ask:

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

```
Worktree removal refused — these files were never committed:

<file list>

1. Commit them to <branch> before cleanup
2. Move them into <main repo root>
3. Delete them (unrecoverable)

Which?
```

Carry out the choice, then remove the worktree.

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (force) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature — I'll offer to discard it" | The menu is complete as written. Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the worktree is clutter now" | PR feedback gets fixed in that worktree. It stays until the work lands. |
| "This other worktree looks stale — I'll clean it too" | Clean up only worktrees under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "Removal refused — `--force` is just finishing the cleanup" | The refusal means files exist only in that worktree. `--force` destroys them permanently. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Branch and worktree stay put while you investigate. |
| "The base branch is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
| "I'll record the decisions after the merge" | The records ride the branch. After the merge the plan is gone from the tree and the diff review is over. Record first, then present the menu. |
