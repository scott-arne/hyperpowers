---
sources: skills/dispatching-parallel-agents
source-digest: fe78ddb515b1
---
# dispatching-parallel-agents

`dispatching-parallel-agents` has the agent split two or more unrelated problems across subagents that work at the same time, then check and combine their results.

:::{card} At a glance
**Category:** Process · **Triggers on:** 2+ independent tasks that can be worked on without shared state or sequential dependencies · **Hands off to:** {doc}`communication` for the final report · **Harness notes:** none; it needs a harness that can dispatch subagents
:::

## When it triggers

The skill's description says to use it when you face two or more independent tasks that need no shared state and have no sequential dependencies. In plain words: several things are broken or need doing, none of them depends on another, and one agent working through them in turn would waste time.

Example requests:

- "Six tests fail across three files after the refactor. Look at them."
- "These two subsystems each have a bug. Find both."
- "Update the three config loaders. They don't touch each other."

## What it does

The skill is a four-step pattern.

1. **Identify independent domains.** The agent groups the problems by what is broken. In the skill's example, one test file covers tool approval, another batch completion, and a third abort handling, and fixing one does not affect the others.
2. **Create focused agent tasks.** Each subagent gets a specific scope (one test file or subsystem), a clear goal, constraints such as "don't change other code", and the output you expect back, usually a summary of what it found and fixed. The prompt is self-contained: the skill says subagents never inherit the session's context, so the agent writes in everything they need, including the error messages and test names.
3. **Dispatch in parallel.** The agent issues all the dispatch calls in one response. Several calls in one response run concurrently; one call per response runs them in sequence.
4. **Review and integrate.** When the subagents return, the agent reads each summary, checks that the fixes do not conflict, runs the full test suite, integrates the changes, and reports the result to you, writing that report with {doc}`communication`. The skill's verification list adds a spot check, because subagents can make systematic errors.

The skill also lists when to leave it alone. If the failures are related, so that fixing one might fix others, the agent investigates them together first. It does the same when understanding the problem needs the whole system, when you do not yet know what is broken, and when subagents would interfere with each other by editing the same files or using the same resources.

## Why it exists

Working through unrelated failures one at a time spends your waiting time on work that has no ordering. The skill also keeps the main agent's context free for coordination, since each subagent carries the detail of its own problem. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- Independent problems run concurrently instead of one after another.
- Each subagent holds one problem's context, so it stays focused and the main agent's context stays small.
- The skill states when not to use it, so related failures get investigated together.
- It requires an integration pass (conflict check, full suite, spot check) before the agent reports.

## Cons and costs

- Every subagent is a separate session with its own context, so parallel work costs more tokens than one agent doing the same fixes in a row.
- The split is the agent's judgment. If it treats related failures as independent, two subagents can fix the same root cause in different ways, and the conflict shows up at integration.
- The skill's only protection against collisions is the agent's judgment that the domains do not overlap. It tells the agent not to dispatch when agents would edit the same files or use the same resources, and it does not describe any isolation beyond that.
- A subagent only knows what its prompt says. A vague prompt gives vague work, and the skill's own "Common Mistakes" list is mostly about prompt quality.
- Subagents can make systematic errors, so the integration pass takes time too.

## Skipping or overriding

To get this behavior, tell the agent the problems are independent and ask for parallel agents. To avoid it, say "investigate these one at a time" or "these are probably related, look at them together." That is reasonable when you suspect a shared root cause, which is the skill's own first exception.

## Works with

- {doc}`communication` is the skill the agent uses for the report to you after integration. The skill marks it as a required sub-skill for that step.

The skill names no other skill in its process.

## Under the hood

{source}`skills/dispatching-parallel-agents/SKILL.md` is the whole skill. It has no supporting files or scripts.
