---
sources: skills/finishing-a-development-branch skills/requesting-code-review/scripts/codex-review-dir skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md skills/using-git-worktrees/SKILL.md docs/hyperpowers/specs/2026-10-21-decision-records-design.md
source-digest: f6968306351f
---
# finishing-a-development-branch

`finishing-a-development-branch` closes out finished work: it records the branch's design decisions, runs the tests, shows you a short menu (merge, pull request, or keep), carries out your choice, and removes the worktree after a local merge or a confirmed discard (a pull request or keep leaves it in place).

:::{card} At a glance
**Category:** Process · **Triggers on:** implementation is complete, all tests pass, and you need to decide how to integrate the work · **Hands off to:** none; it ends the workflow · **Harness notes:** the decision extractor needs a tracked background subagent; without one the skill compiles records without notes and says so
:::

## When it triggers

The skill's description says to use it when implementation is complete, the tests pass, and you need to decide how to integrate the work. {doc}`subagent-driven-development` and {doc}`executing-plans` both invoke it as their last step, so it usually starts without a request from you.

Example requests:

- "I'm done with this branch. How do we land it?"
- "Wrap this up and open a pull request."
- "Merge this back to main locally."

## What it does

The agent announces the skill. The core sequence is: record decisions and verify tests, detect the environment, present options, execute your choice, clean up.

**1. Record decisions and verify tests.** If the branch implements a spec, the skill leaves one record per decision in the `decisions/` directory beside the spec's directory. The compiler, `scripts/decisions-compile`, builds them from the spec's `## Decisions` list and removes the plan in the same commit. The agent first finds the plan and the spec, and confirms the branch's fork point with you if it is not already known. It dry-runs the compiler. Where a spec predates the decisions list, the agent drafts the list from the spec's text, shows it to you, and writes it in only after you approve. It then starts a background subagent, the extractor, that reads what shipped and notes where each decision's implementation differed from the spec. While that runs, it runs the full test suite and waits for the result in the same turn: in the foreground when the suite finishes within 10 minutes, and otherwise as a tracked background command whose exit file it watches with repeated `scripts/wait-exit` calls, so an editor such as Zed shows the session working. If tests fail, it stops the extractor, reports the failures, compiles nothing, and shows no menu. If they pass, it collects the extractor's notes without waiting for them (an unfinished extractor is stopped and the compile runs without notes), compiles the records, and stages them. Work with no spec has no records, and this step is only the test run. A spec that already carries an Outcome line was finished by another plan first, and the compiler recompiles it: the Outcome line names this plan too, and the plan's notes get their own paragraph. It refuses three cases, before writing anything: this plan has the file name of a plan the spec already records; notes from a run without a plan would replace notes plans wrote; or a plan's notes would replace notes from a finish without a plan. The agent then shows the refusal and stops. When the hand-off names a plan workspace (SDD), the agent first records where the plan's repository and plan path are, because the compile removes the plan file and Step 6 can remove the worktree, and the lease commands below need those paths.

**2. Detect the environment.** The agent compares the git directory with the common git directory and works out the repository's default branch. The mode the calling skill passes (`current-branch`, `new-branch`, or `worktree`) and the environment pick the menu and the cleanup. A detached HEAD in a linked worktree gets a reduced menu with no local merge. A caller-passed mode `current-branch` on the default branch gets push or keep.

**3. Determine the base branch.** It confirms the branch this work forked from before any merge, because merging into the wrong base is expensive to undo.

**4. Present options.** When records were staged, the same message shows you the complete staged diff, then each proposal from the extractor with the question it needs: an undocumented decision to add to the spec or dismiss, a proposed supersession of an older record to accept or dismiss, and an offer to skip the records for this branch. Only then does it show the menu, and nothing is committed until every proposal has an answer. Under SDD, the agent first prints the board. When another open plan has this branch as its integration branch, the merge option is withheld in a menu that offers one: the three-option menu shows it as unavailable, names the open plan, and accepts only the pull request and keep options. The two-option menus (a session that stayed on the default branch, and a detached HEAD) have no merge option and are shown unchanged, with the open plan named. Approval leads to one records commit. The standard menu has three options: merge back to the base branch locally, push and create a pull request, or keep the branch as is. Discard is not on the menu. It happens only if you ask for it explicitly, and then the agent requires you to type `discard` to confirm.

**5. Execute the choice.** Under SDD, merge first marks the branch closing under its lease, and any answer but `closing` stops it before the merge. Merge runs the tests again on the merged result and stops, leaving the branch and worktree in place, if they fail; the branch stays marked closing until the lease is released, so new claims on it are refused meanwhile. If you decide against the merge after it started, the agent restores the base branch, and resets it to its pre-merge tip only on your explicit yes. A pull request pushes the branch, creates the request with the forge's tooling, and reports the URL. Keep reports the branch and worktree path. Under SDD, each option ends by detaching the session's worktree where it holds the integration branch and releasing the branch lease as its last action.

**6. Clean up.** After a merge or a confirmed discard, the agent removes a worktree under `.worktrees/` or `worktrees/` with `git worktree remove` and then prunes. The merge deletes the branch with `git branch -d`, which refuses to delete a branch that is checked out, so under SDD the worktree is detached first. A discard under SDD takes the same sibling-plan check as a merge, and deletes nothing while another plan is open on the branch. Pull request and keep both preserve the worktree. If removal is refused because the worktree holds uncommitted files, the agent never forces it: it shows you the files and asks whether to commit them, move them, or delete them. A worktree outside those directories belongs to the host environment and stays.

## Why it exists

The skill's rationalizations table lists the failures it prevents. Tests that passed earlier say nothing about the tree about to be integrated. Integration is your decision and not the agent's. A discard needs the typed word `discard`. A rejected push means the remote moved, so a force-push needs your explicit request. And records written after the merge are too late, because the plan is gone from the tree and the diff review is over, so the records ride the branch. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`, and the design behind the records is {source}`docs/hyperpowers/specs/2026-10-21-decision-records-design.md`.

## Pros

- You see the full diff of the records, and every extractor proposal needs your answer, before any option runs.
- Tests run on the tree you are about to integrate, and again on the merged result before a local merge finishes.
- The menu is fixed and short, and nothing is discarded unless you type `discard`.
- Cleanup never uses `--force` without asking, so files that exist nowhere else are not lost.
- The records and the plan's removal arrive as a single commit on the branch, so a later design session can read why each decision was made.

## Cons and costs

- Step 1 adds a serial step for any branch with a spec: the dry run, the compile, and your review of the staged diff before the menu appears.
- The agent may need to ask you about the fork point, which plan applies, a legacy spec's decisions list, and each extractor proposal. A branch with several loose ends produces several questions before you reach the menu.
- The extractor runs only where the harness has a tracked background subagent. Without one the records are compiled from the spec alone, and the skill says so when it hands back.
- A session working on the default branch in mode `current-branch` gets only push or keep, and a detached HEAD gets no local merge, so the choices you see depend on how the work started.
- The compiler stages files in your repository and fails with an exit code if the spec is uncommitted or the plan is not a tracked, clean markdown file, which stops the finish until you fix it.

## Skipping or overriding

To skip the records for a branch, tell the agent when it offers that line, in your own words; the skill then runs the compiler's undo and goes on to your chosen option. To choose differently from the menu, say so after the diff is shown. To discard, ask for it in so many words and then type `discard`. The skill has no switch to turn it off. If you want to integrate by hand, tell the agent so before the finish step.

## Works with

- {doc}`subagent-driven-development` invokes this skill at the end of a run with the mode, the plan, and the spec.
- {doc}`executing-plans` invokes it at its last step and passes the mode `using-git-worktrees` reported.
- {doc}`using-git-worktrees` creates the workspace this skill cleans up, and reports the mode this skill routes on.
- {doc}`communication` is the skill the agent uses for the test-failure report and the pull request description. The option menus are shown exactly as written.

## Under the hood

- {source}`skills/finishing-a-development-branch/SKILL.md` is the skill.
- {source}`skills/finishing-a-development-branch/scripts/decisions-compile` turns the spec's decisions list into records, stages them, and supports a dry run, an undo, and a reindex.
- {source}`skills/finishing-a-development-branch/decision-notes-prompt.md` is the template for the extractor subagent.
- {source}`skills/requesting-code-review/scripts/codex-review-dir` supplies the per-finish scratch directory that holds the extractor's output and the list of paths to commit.
