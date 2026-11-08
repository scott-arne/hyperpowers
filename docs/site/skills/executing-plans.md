---
sources: skills/executing-plans skills/writing-plans/SKILL.md skills/subagent-driven-development/SKILL.md
source-digest: cb8b257cea8d
---
# executing-plans

`executing-plans` has one agent load a written plan, check it for problems, work through every task in order, and report when the work is complete.

:::{card} At a glance
**Category:** Process · **Triggers on:** you have a written implementation plan to execute in a separate session with review checkpoints · **Hands off to:** {doc}`finishing-a-development-branch` · **Harness notes:** none; the skill itself tells the agent to prefer {doc}`subagent-driven-development` where subagents exist
:::

## When it triggers

The skill's description says to use it when you have a written implementation plan to execute in a separate session with review checkpoints. In plain words, it is the inline way to run a plan: one agent does the tasks itself instead of dispatching a subagent per task.

Example requests:

- "Execute this plan inline, in this session."
- "Run `docs/hyperpowers/plans/2026-11-05-export-flag.md` without subagents."
- "I have a plan written. Work through it and check in with me when you hit a problem."

## What it does

The agent announces that it is using the skill, then tells you something the skill requires it to say: Superpowers works much better with access to subagents. Claude Code, Codex CLI, Codex App, and Copilot CLI all have them. If subagents are available, the skill directs the agent to use {doc}`subagent-driven-development` instead.

The process has three steps.

1. **Load and review the plan.** The agent settles where the work happens through {doc}`using-git-worktrees`, which detects an existing worktree or asks you to choose between the current branch, a new branch in place, and a worktree. It reads the plan and reviews it critically. If it has concerns, it raises them with you before starting. If not, it creates todos for the plan items and proceeds.
2. **Execute the tasks.** For each task it marks the task in progress, follows each step exactly, runs the verifications the plan specifies, reviews after each task or at natural checkpoints using {doc}`requesting-code-review`, and marks the task completed.
3. **Complete the development.** It announces {doc}`finishing-a-development-branch`, passes along the mode {doc}`using-git-worktrees` reported, and follows that skill to verify tests and present your options.

The skill lists when to stop immediately and ask: a blocker such as a missing dependency, a failing test, or an unclear instruction; critical gaps in the plan; an instruction the agent does not understand; or verification that fails repeatedly. It says to ask rather than guess. It sends the agent back to the review step when you update the plan or when the approach needs rethinking. It never starts implementation on main or master without your explicit consent.

## Why it exists

Not every harness or situation allows subagents, and some people want one agent to do the work in one place. This skill is the fallback for those cases, and it keeps the same discipline: review the plan before starting, follow the steps as written, verify, and stop when blocked. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- The process is short and easy to follow: load, review, execute, finish.
- It works where subagents do not exist.
- The agent raises plan concerns with you before it starts, not after it has built on a bad assumption.
- You can watch the work happen in one session.

## Cons and costs

- One agent holds the whole plan and all the implementation work in a single context, so long plans grow that context and the cost of every later call.
- The skill asks for review "after each task or at natural checkpoints", so how often review happens depends on the agent's judgment. {doc}`subagent-driven-development` runs a task review after every task and a whole-branch review at the end.
- There is no fresh-context isolation between tasks, so earlier mistakes and assumptions carry into later tasks.
- The skill has no ledger. {doc}`subagent-driven-development` records progress in a ledger file so a session can recover after a context compaction, and this skill leaves recovery to the agent's todos.
- The skill itself says subagent-driven execution works much better where subagents are available.

## Skipping or overriding

To use this skill, ask for inline execution or execution in this session without subagents. To avoid it, do nothing: {doc}`writing-plans` hands off to {doc}`subagent-driven-development` by default. If the agent flags a concern about the plan, answering it before work starts is the point of the first step, so a quick "go ahead" after you have read the concern is the normal override.

## Works with

- {doc}`writing-plans` produces the plan this skill executes and names this skill as the inline option.
- {doc}`subagent-driven-development` is what the skill tells the agent to use instead when subagents are available.
- {doc}`using-git-worktrees` settles where the work happens in step 1.
- {doc}`requesting-code-review` is the review the agent runs after tasks or at checkpoints.
- {doc}`finishing-a-development-branch` closes out the work in step 3.
- {doc}`communication` governs the concerns the agent raises before starting and the completion report.

## Under the hood

{source}`skills/executing-plans/SKILL.md` is the whole skill. It has no supporting files or scripts.
