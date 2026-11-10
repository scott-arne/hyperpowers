---
sources: skills/writing-plans skills/brainstorming/SKILL.md skills/subagent-driven-development/SKILL.md docs/hyperpowers/specs/2026-08-09-risk-tiering-prompt-hygiene-design.md
source-digest: d0ea90edc830
---
# writing-plans

`writing-plans` turns an approved spec or set of requirements into a written implementation plan that an engineer with no context could follow task by task.

:::{card} At a glance
**Category:** Process · **Triggers on:** you have a spec or requirements for a multi-step task, before any code is touched · **Hands off to:** {doc}`subagent-driven-development` by default, or {doc}`executing-plans` when you ask for inline execution · **Harness notes:** the Codex plan review runs on Claude Code only
:::

## When it triggers

The skill's description says to use it when you have a spec or requirements for a multi-step task, before touching code. In plain words, it runs once the design is settled and the work is big enough to need more than one step. On the architectural path, {doc}`brainstorming` invokes it after you approve the spec.

Example requests:

- "The spec is approved. Write the implementation plan."
- "Here are the requirements for the billing migration. Plan the work before we start."
- "Break this feature into tasks."

## What it does

The agent announces that it is using the skill and saves the plan to `docs/hyperpowers/plans/YYYY-MM-DD-<feature-name>.md`. The first time a plan or spec lands in a repository, it runs `scripts/docs-allowlist`, which writes `docs/hyperpowers/.gitignore` so that only `specs/`, `plans/`, and `decisions/` are ever committed from that directory.

It writes for an implementer who has zero context for your codebase and, in the skill's words, questionable taste. Before defining tasks it maps which files will be created or modified and what each is responsible for. It also grounds the plan: for each convention the work touches, it finds one real example in the codebase and records its path and line range, or states that no similar code exists. An invented citation counts as a plan failure.

Every plan starts with a header: a pointer to the spec, the goal, the architecture, the tech stack, a Global Constraints section holding the spec's project-wide requirements with exact values, and a Grounding section. Tasks are sized so that each carries its own test cycle and is worth a fresh reviewer's attention. Steps inside a task are single actions of two to five minutes: write the failing test, run it, write the minimal code, run it again, commit.

Each task also declares a `**Depends on:**` line naming the tasks whose completion lines must exist before it may be claimed, `none` when there are none. The line says nothing about files, and the pre-flight scan checks declared independence against file and interface overlap separately. A plan with no such line on any task is read as serial. The Global Constraints section can name merge-expected files, such as a changelog every task touches, so two tasks that share only those are not counted as a conflict. A task without the line is a placeholder failure in the self-review.

Each task also declares a risk tier on the line under its heading:

- **high:** approval-authority code, concurrency or locking, security surfaces, destructive git operations, or durable-record writers.
- **standard:** the default. Multi-file integration, new scripts, behavior-shaping skill or doc changes.
- **low:** single-file mechanical transcription where the plan holds the complete content, doc-reference or typo fixes, and test-needle additions. A low tier needs a written rationale.

The tier decides only one thing at execution time: whether the per-task Codex review runs. The Claude task reviewer and the final whole-branch review never tier off.

The skill forbids placeholders: "TBD", "TODO", "add appropriate error handling", "write tests for the above" without test code, "similar to Task N", and citations that do not resolve. The one allowed unknown names how it will be resolved and before which task. After writing, the agent runs a self-review against the spec: coverage, placeholders, type consistency across tasks, and whether the citations are real.

On Claude Code it then runs the Codex plan review before showing you the plan. Codex checks feasibility, task sizing, missing steps, ordering, signature consistency, spec coverage, and each task's declared tier against the rubric. When the plan has material algorithmic or data-structure choices, the first round also assesses them. If Codex is absent or the review is skipped, the plan's low tiers are marked unreviewed and execute as standard.

The skill then hands off without asking you to pick an execution method. The default is {doc}`subagent-driven-development`: "Plan complete and saved to `<path>`. Executing with Subagent-Driven Development (fresh subagent per task, review between tasks)." If you explicitly asked for inline execution, it uses {doc}`executing-plans` instead.

## Why it exists

An implementer who lacks context fills the gaps with guesses. A plan with exact file paths, complete code, and verification commands removes those gaps, and the grounding requirement stops the plan from inventing conventions the codebase does not have. Risk tiers exist to scale per-task review cost to per-task risk without weakening the final gates; the design is in {source}`docs/hyperpowers/specs/2026-08-09-risk-tiering-prompt-hygiene-design.md`, and the decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- Each task is self-contained, so a fresh subagent can implement it from its own text.
- The dependency lines let several sessions work independent tasks of one plan at the same time.
- Citations to real code keep implementers from imitating patterns that are not in the repository.
- Risk tiers let mechanical tasks skip the per-task Codex review while risky ones keep it.
- The no-placeholder rule and the self-review catch gaps before execution starts, when they are cheapest to fix.
- The plan names its spec, so the execution skill can treat the spec as the tiebreaker when the plan conflicts with itself.

## Cons and costs

- Plans are long. A plan with complete code and exact commands for every step takes real time and tokens to write and to read.
- Writing the plan is itself a stage before any code runs, and the Codex plan review adds rounds on Claude Code.
- A plan written in detail can go stale if the codebase moves before execution, and its citations then point at old line ranges.
- The tier is a judgment call, and a mis-tiered task either gets a review it did not need or skips one it did. The Codex plan review exists partly to catch this.
- For a change small enough to hold in your head, the plan is overhead.

## Skipping or overriding

Tell the agent where to save the plan if you do not want the default `docs/hyperpowers/plans/` location; the skill lets your preference override it. Ask for inline execution if you want {doc}`executing-plans` instead of subagents. Skipping the plan for a one-step change is reasonable, and {doc}`brainstorming` already skips the spec and plan on its bounded and spike paths.

## Works with

- {doc}`brainstorming` invokes this skill after you approve the spec.
- {doc}`subagent-driven-development` is the default handoff.
- {doc}`executing-plans` is the handoff when you ask for inline execution.
- {doc}`requesting-code-review` holds the Codex review gate that checks the plan before you see it.
- {doc}`communication` governs the plan's prose and the handoff message.

## Under the hood

- {source}`skills/writing-plans/SKILL.md` holds the plan header, the risk tier rubric, the task structure, the no-placeholder rules, and the handoff.
- {source}`skills/writing-plans/scripts/docs-allowlist` writes the allowlist `.gitignore` for the planning directory and leaves an existing one alone.
