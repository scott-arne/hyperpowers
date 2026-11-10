---
sources: skills/subagent-driven-development hooks/sdd-stop-guard hooks/lib/stop-guard.mjs skills/writing-plans/SKILL.md docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md docs/hyperpowers/specs/2026-08-09-risk-tiering-prompt-hygiene-design.md
source-digest: 8017a8e8c099
---
# subagent-driven-development

`subagent-driven-development` (SDD) runs a written plan by dispatching a fresh implementer subagent for each task, or one subagent for a batch of small same-shape tasks, reviewing each task's result, and reviewing the whole branch at the end.

:::{card} At a glance
**Category:** Process · **Triggers on:** executing an implementation plan with independent tasks in the current session · **Hands off to:** {doc}`finishing-a-development-branch` · **Harness notes:** the Codex task and final gates and the stop guard run on Claude Code only; the skill degrades to its Claude reviewers when Codex is absent
:::

## When it triggers

The skill's description says to use it when executing implementation plans with independent tasks in the current session. In plain words, it runs once a plan exists and you want it carried out with subagents. {doc}`writing-plans` hands off to it by default.

Example requests:

- "Plan complete. Go ahead and build it."
- "Execute `docs/hyperpowers/plans/2026-11-05-export-flag.md`."
- "Resume the plan from where the last session stopped."

## What it does

The controller (your main session) coordinates and leaves implementation to subagents, apart from one narrow exception: it may apply a fix fully specified by a finding, of at most three lines in one file with no new logic. Each task goes through the same loop.

**Setup.** The controller settles where the work happens through {doc}`using-git-worktrees`, syncs the plan's state with `scripts/sdd-state sync`, and finds the plan's workspace with `scripts/sdd-dir`. The workspace lives in a per-repository state checkout under your user cache, outside the working tree, so nothing in it can be committed with your code. It holds the plan's ledger (`progress.md`), task briefs, reports, and review packages. The ledger is the recovery map: it records each completed task, so a controller that loses its context to compaction resumes at the first task without a completion line instead of redoing finished work. It also registers the plan's integration branch with `scripts/sdd-state register`, so other sessions can join the same plan. The controller reads the plan and its spec, then scans the plan for conflicts between tasks and asks you about any it finds in one batched question before execution begins.

**Per task.**

1. The controller asks `scripts/sdd-state next` which tasks it may take, claims the first, and checks out the task branch the claim prints. It extracts the task's text into a brief file with `scripts/task-brief`, and dispatches a fresh implementer subagent with the brief path, the relevant interfaces, the global constraints, and a report-file path. The implementer follows {doc}`test-driven-development`, commits, self-reviews, and returns a short status contract. It never dispatches subagents of its own.
2. The controller treats the report as a claim. It re-runs the named covering test command itself and compares the output against the report. A misreported result is a failed task.
3. The controller builds a review package with `scripts/review-package` (commit list, stat, and full diff in one file) and dispatches a task reviewer. The reviewer returns two verdicts: spec compliance and code quality. Both are required.
4. If either verdict has Critical or Important findings, the fix loop starts. It has a cap of five rounds per task. Rounds one to three stay on the original implementer's model: on Claude Code outside fork mode, a fresh implementer on that model, dispatched in the foreground with the brief, the report file, and the findings; elsewhere, the original implementer resumed with the findings. Rounds four and five dispatch a fresh implementer on a more capable model. Every round ends with a scoped re-review of the fix diff only. Minor findings are written to the ledger as deferred and never enter the loop. A finding that conflicts with the plan's text goes to you to decide which governs. When round five still leaves blocking findings, the controller stops and reports the task BLOCKED to you.
5. On Claude Code, after the task reviewer approves, a per-task Codex code review runs unless the task is effective-low. Its blocking findings join the same five-round cap rather than getting a cap of their own.
6. The controller appends an `approved` line for the head the reviewers saw, and `scripts/sdd-state merge-back` merges that commit into the integration branch. The controller detaches, deletes the task branch with `git branch -d`, and runs `scripts/sdd-state complete`, which appends the task's completion line to the ledger and snapshots the workspace to the state branch. It repeats `complete` until it prints `status=complete`.

**Several sessions.** More than one session can run the same plan, or sibling plans of one spec. Each session takes the tasks `next` offers, in its own worktree and on its own task branch, and runs one implementer at a time. Tasks that name prerequisites on a `**Depends on:**` line wait for them, and a plan without those lines runs serially. When a session has nothing to take, or needs you, it posts a waiting record with `scripts/sdd-state wait` and hands back with the board's lines (`scripts/sdd-state board`), which is how you find the session that needs you. {doc}`../advanced/sdd-internals` has the mechanics.

**Risk tiers.** Each plan task declares a tier. A task declared low skips the per-task Codex review only when the plan's own Codex review actually ran and no escalation trigger fired during execution (a fix cycle, a touched file outside the plan's list, concerns about correctness, or something on the high-risk list surfacing). The skip is recorded. The Claude task reviewer and the final review never tier off.

**Final review.** After the last task, one session claims the final train with `scripts/sdd-state claim <plan> final`, which takes a lease on the integration branch and checks it out in that session's worktree. That session dispatches a whole-branch reviewer on the most capable available model, pointed at the ledger's deferred minors. If it returns findings, one fix subagent gets the complete list and one scoped re-review follows. There is no second fix wave. Whatever remains open goes to you. On Claude Code a final Codex review runs after that, with its own three-round backstop. When the plan has a spec, the controller also dispatches a background extractor that drafts notes for the decision records.

**Turn ends.** While the plan has tasks left, the controller ends its turn only for a BLOCKED status it cannot resolve, a question only you can answer, or, on a harness that cannot wait in the foreground, tracked work still running. It records a question, a BLOCKED report, or your request to stop with `scripts/sdd-state handback`. On Claude Code it waits for subagents and commands in the foreground, and it runs a command that may take longer than 10 minutes as a tracked job through `scripts/tracked-job`. A Stop hook, the SDD stop guard, refuses a turn end it can prove is premature, at most twice in a row per plan. It allows the end of a turn in which the session posted its own waiting record. {doc}`../advanced/sdd-internals` describes the guard.

**Finish.** The controller removes the plan's workspace with `scripts/sdd-state finish`, which only the holder of the final train may run, verifies it is gone, and invokes {doc}`finishing-a-development-branch` with the mode, the plan, and the spec. Finish refuses while a tracked job is still live, and it leaves the branch lease for {doc}`finishing-a-development-branch` to release. It leaves a receipt under your user cache, a copy of the ledger, the stop guard's log, and the job records, and the controller names its path in the closing message.

**Model selection.** The controller names a model for every dispatch, because an omitted model inherits the session's, usually the most expensive. A mid-tier model is the floor for reviewers and for implementers working from prose. The cheapest tier is for transcription, where the task text carries the complete code. The final review takes the most capable model. {source}`skills/subagent-driven-development/model-selection.md` has the per-role guidance.

**After compaction.** Claude Code re-attaches the skill cut to its first 20,000 characters, which ends before the task loop. The skill tells the controller to re-read its full text after every compaction, then the ledger, before its next action.

## Why it exists

Controllers that lost their place after a compaction have re-dispatched whole completed task sequences, which the skill calls the most expensive failure it has observed. The ledger, the claims, and the re-read paragraph exist to prevent that. Fresh subagents keep each task's context small and focused, and they keep the controller's context free for coordination. Per-task review catches problems while they are cheap to fix, and the five-round cap stops a loop that is not converging. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`. The state branch that carries the ledger between machines is explained in {source}`docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md`, and the risk-tier design is in {source}`docs/hyperpowers/specs/2026-08-09-risk-tiering-prompt-hygiene-design.md`.

## Pros

- Each implementer starts with only its task, so context does not pile up across tasks.
- Every task gets a spec verdict and a quality verdict from a reviewer who did not write the code.
- The ledger lets a run survive compaction and, through the state branch, move between hosts.
- The controller re-runs covering tests instead of trusting reports.
- The fix loop is bounded, and an unresolved task surfaces to you instead of continuing silently.
- Risk tiers spend the per-task Codex review where the risk is.

## Cons and costs

- A run is many subagent dispatches: an implementer, a task reviewer, and often fix rounds and a Codex gate per task. It costs more tokens and wall-clock time than doing the work in one session.
- The skill is long, and the controller re-reads it in full after every compaction.
- Within one session, tasks run one at a time: the skill forbids dispatching two implementers at once. Parallel work means more sessions, each with its own worktree and task branch, and that adds setup, merge-backs, and the chance of a merge conflict.
- The plan must be good. A vague task produces an implementer that guesses, and the review loop then spends rounds on it.
- Setup has moving parts: the workspace, the state branch, and sync outcomes that can stop the run until you answer a question.
- The Codex gates need the Codex plugin and run on Claude Code only.

## Skipping or overriding

If you want one agent to do the work in your session, say "execute inline" and the agent will use {doc}`executing-plans`. If a task is a small same-shape edit repeated across files, the skill batches those into one dispatch on its own. The skill does not let you skip the task review: it says never to skip it, and an implementer's self-review does not replace it.

## Works with

- {doc}`writing-plans` produces the plan and hands off to this skill by default.
- {doc}`using-git-worktrees` settles where the work happens during setup.
- {doc}`test-driven-development` is what implementer subagents follow for the task's tests.
- {doc}`requesting-code-review` supplies the final reviewer prompt and the Codex review gate.
- {doc}`finishing-a-development-branch` closes the run and compiles the decision records.
- {doc}`executing-plans` is the inline alternative when you do not want subagents.
- {doc}`communication` governs the pre-flight question, escalations, and BLOCKED hand-backs.

## Under the hood

- {source}`skills/subagent-driven-development/SKILL.md` holds the setup, the task loop, the fix loop, the final review, and the finish steps.
- {source}`skills/subagent-driven-development/implementer-prompt.md`, {source}`skills/subagent-driven-development/task-reviewer-prompt.md`, {source}`skills/subagent-driven-development/re-review-prompt.md`, and {source}`skills/subagent-driven-development/fix-subagent-prompt.md` are the dispatch templates.
- {source}`skills/subagent-driven-development/risk-tiers.md` has the escalation triggers and the ledger line shapes.
- {source}`skills/subagent-driven-development/model-selection.md` is the per-role model guidance.
- {source}`skills/subagent-driven-development/common-rationalizations.md` lists the shortcuts that show up mid-run and why they fail.
- {source}`skills/subagent-driven-development/example-workflow.md` is a worked run from dispatch to finish.
- {source}`skills/subagent-driven-development/scripts/task-brief` extracts a task's text, and {source}`skills/subagent-driven-development/scripts/review-package` builds the diff file a reviewer reads.
- {source}`skills/subagent-driven-development/scripts/sdd-dir` prints the plan's workspace path, and {source}`skills/subagent-driven-development/scripts/sdd-state` syncs, registers, offers and claims tasks, merges them back, records completions, hand-backs and waiting records, prints the board, amends the plan, snapshots, hands off, and finishes the workspace. {source}`skills/subagent-driven-development/scripts/tracked-job` allocates, runs, watches, and stops tracked jobs. `sdd-common.sh` holds their shared code.
- {source}`hooks/sdd-stop-guard` is the Claude Code Stop hook, and {source}`hooks/lib/stop-guard.mjs` holds its logic.
