---
sources: skills/subagent-driven-development
source-digest: dbebf50b8ad4
---
# subagent-driven-development

`subagent-driven-development` (SDD) runs a written plan by dispatching a fresh implementer subagent for each task, reviewing each task's result, and reviewing the whole branch at the end.

:::{card} At a glance
**Category:** Process · **Triggers on:** executing an implementation plan with independent tasks in the current session · **Hands off to:** `finishing-a-development-branch` · **Harness notes:** the Codex task and final gates run on Claude Code only; the skill degrades to its Claude reviewers when Codex is absent
:::

## When it triggers

The skill's description says to use it when executing implementation plans with independent tasks in the current session. In plain words, it runs once a plan exists and you want it carried out with subagents. {doc}`writing-plans` hands off to it by default.

Example requests:

- "Plan complete. Go ahead and build it."
- "Execute `docs/hyperpowers/plans/2026-11-05-export-flag.md`."
- "Resume the plan from where the last session stopped."

## What it does

The controller (your main session) does coordination and never implements. Each task goes through the same loop.

**Setup.** The controller settles where the work happens through `using-git-worktrees`, syncs the plan's state with `scripts/sdd-state sync`, and finds the plan's workspace with `scripts/sdd-dir`. The workspace lives in a per-repository state checkout under your user cache, outside the working tree, so nothing in it can be committed with your code. It holds the plan's ledger (`progress.md`), task briefs, reports, and review packages. The ledger is the recovery map: it records each completed task, so a controller that loses its context to compaction resumes at the first task without a completion line instead of redoing finished work. The controller reads the plan and its spec, then scans the plan for conflicts between tasks and asks you about any it finds in one batched question before execution begins.

**Per task.**

1. The controller claims the task, extracts its text into a brief file with `scripts/task-brief`, and dispatches a fresh implementer subagent with the brief path, the relevant interfaces, the global constraints, and a report-file path. The implementer follows `test-driven-development`, commits, self-reviews, and returns a short status contract. It never dispatches subagents of its own.
2. The controller treats the report as a claim. It re-runs the named covering test command itself and compares the output against the report. A misreported result is a failed task.
3. The controller builds a review package with `scripts/review-package` (commit list, stat, and full diff in one file) and dispatches a task reviewer. The reviewer returns two verdicts: spec compliance and code quality. Both are required.
4. If either verdict has Critical or Important findings, the fix loop starts. It has a cap of five rounds per task. Rounds one to three resume the original implementer. Rounds four and five dispatch a fresh implementer on a more capable model. Every round ends with a scoped re-review of the fix diff only. Minor findings are written to the ledger as deferred and never enter the loop. A finding that conflicts with the plan's text goes to you to decide which governs. When round five still leaves blocking findings, the controller stops and reports the task BLOCKED to you.
5. On Claude Code, after the task reviewer approves, a per-task Codex code review runs unless the task is effective-low. Its blocking findings join the same five-round cap rather than getting a cap of their own.
6. The controller appends a completion line to the ledger and snapshots the workspace to the state branch.

**Risk tiers.** Each plan task declares a tier. A task declared low skips the per-task Codex review only when the plan's own Codex review actually ran and no escalation trigger fired during execution (a fix cycle, a touched file outside the plan's list, concerns about correctness, or something on the high-risk list surfacing). The skip is recorded. The Claude task reviewer and the final review never tier off.

**Final review.** After the last task, the controller dispatches a whole-branch reviewer on the most capable available model, pointed at the ledger's deferred minors. If it returns findings, one fix subagent gets the complete list and one scoped re-review follows. There is no second fix wave. Whatever remains open goes to you. On Claude Code a final Codex review runs after that, with its own three-round backstop. When the plan has a spec, the controller also dispatches a background extractor that drafts notes for the decision records.

**Finish.** The controller removes the plan's workspace with `scripts/sdd-state finish`, verifies it is gone, and invokes `finishing-a-development-branch` with the mode, the plan, and the spec.

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
- The skill is long, and the controller re-reads it in full after every compaction. The README puts that at about 10K tokens each time.
- Tasks run one at a time. The skill forbids dispatching several implementers in parallel, to avoid conflicts.
- The plan must be good. A vague task produces an implementer that guesses, and the review loop then spends rounds on it.
- Setup has moving parts: the workspace, the state branch, and sync outcomes that can stop the run until you answer a question.
- The Codex gates need the Codex plugin and run on Claude Code only.

## Skipping or overriding

If you want one agent to do the work in your session, say "execute inline" and the agent will use {doc}`executing-plans`. If a task is a small same-shape edit repeated across files, the skill batches those into one dispatch on its own. The skill does not let you skip the task review: it says never to skip it, and an implementer's self-review does not replace it.

## Works with

- {doc}`writing-plans` produces the plan and hands off to this skill by default.
- `using-git-worktrees` settles where the work happens during setup.
- `test-driven-development` is what implementer subagents follow for the task's tests.
- `requesting-code-review` supplies the final reviewer prompt and the Codex review gate.
- `finishing-a-development-branch` closes the run and compiles the decision records.
- {doc}`executing-plans` is the inline alternative when you do not want subagents.
- `communication` governs the pre-flight question, escalations, and BLOCKED hand-backs.

## Under the hood

- {source}`skills/subagent-driven-development/SKILL.md` holds the setup, the task loop, the fix loop, the final review, and the finish steps.
- {source}`skills/subagent-driven-development/implementer-prompt.md`, {source}`skills/subagent-driven-development/task-reviewer-prompt.md`, {source}`skills/subagent-driven-development/re-review-prompt.md`, and {source}`skills/subagent-driven-development/fix-subagent-prompt.md` are the dispatch templates.
- {source}`skills/subagent-driven-development/risk-tiers.md` has the escalation triggers and the ledger line shapes.
- {source}`skills/subagent-driven-development/model-selection.md` is the per-role model guidance.
- {source}`skills/subagent-driven-development/common-rationalizations.md` lists the shortcuts that show up mid-run and why they fail.
- {source}`skills/subagent-driven-development/example-workflow.md` is a worked run from dispatch to finish.
- {source}`skills/subagent-driven-development/scripts/task-brief` extracts a task's text, and {source}`skills/subagent-driven-development/scripts/review-package` builds the diff file a reviewer reads.
- {source}`skills/subagent-driven-development/scripts/sdd-dir` prints the plan's workspace path, and {source}`skills/subagent-driven-development/scripts/sdd-state` syncs, claims, snapshots, hands off, and finishes the workspace. `sdd-common.sh` holds their shared code.
