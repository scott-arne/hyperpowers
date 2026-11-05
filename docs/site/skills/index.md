# Skills

Skills trigger automatically: the agent matches your request against each skill's description and loads the ones that apply. This page lists the skills by category, with what each does and when it triggers.

## Process

| Skill | What it does | Triggers when |
|---|---|---|
| {doc}`brainstorming` | Classifies the request, asks questions one at a time, and gets your approval of a design before any code is written. | You ask for a feature, a component, or a behavior change. |
| {doc}`writing-plans` | Turns an approved design into bite-sized tasks with exact files, steps, and risk tiers. | You have a spec or requirements for a multi-step task. |
| {doc}`executing-plans` | Works through a written plan in the current session and stops when blocked. | You have a plan to run in a separate session, or subagents are unavailable. |
| {doc}`subagent-driven-development` | Dispatches a fresh implementer subagent per task and reviews each task and the whole branch. | You have a plan with mostly independent tasks to run in the current session. |
| {doc}`dispatching-parallel-agents` | Splits independent problems across subagents that run at the same time, then checks and combines the results. | You face two or more tasks with no shared state or ordering between them. |
| {doc}`using-git-worktrees` | Reuses an isolated workspace or asks where the work happens, runs project setup, and checks that tests pass first. | You start feature work that needs isolation, or are about to execute a plan. |
| {doc}`finishing-a-development-branch` | Records the branch decisions, runs the tests, offers merge, pull request, or keep, and removes the worktree after a merge or a confirmed discard. | Implementation is complete and the tests pass. |
| {doc}`communication` | Writes reports and replies with the answer first, in plain words, without stock phrasing. | The agent writes prose you will read, or you ask it to make text read less like AI. |

## Testing

| Skill | What it does | Triggers when |
|---|---|---|
| {doc}`test-driven-development` | Requires a failing test before any production code, then the least code that passes, and deletes code written before its test. | You implement a feature or a bugfix. |

## Debugging

| Skill | What it does | Triggers when |
|---|---|---|
| {doc}`systematic-debugging` | Finds the root cause before any fix, in four phases, and questions the design after three failed fixes. | You hit a bug, a test failure, or unexpected behavior. |

## Review

| Skill | What it does | Triggers when |
|---|---|---|
| {doc}`requesting-code-review` | Dispatches a reviewer subagent over an exact commit range, and under Claude Code adds an optional Codex review. | You complete a task or a major feature, or are about to merge. |
| {doc}`receiving-code-review` | Checks review feedback against the code before acting, pushes back with evidence, and skips performative agreement. | The agent receives review feedback. |
