---
sources: skills/writing-skills skills/using-hyperpowers/SKILL.md skills/test-driven-development/writing-good-tests.md
source-digest: 1ed61c856925
---
# writing-skills

`writing-skills` applies test-driven development to skill documents: the agent watches another agent fail a pressure scenario without the skill, writes the skill to fix those failures, and closes the loopholes it finds.

:::{card} At a glance
**Category:** Meta · **Triggers on:** creating a skill, editing a skill, or verifying that a skill works before deployment · **Hands off to:** {doc}`test-driven-development` (required background for the cycle) · **Harness notes:** personal skills live in your runtime's skills directory (`~/.claude/skills/` on Claude Code); the Codex reference file covers Codex
:::

## When it triggers

The skill's description says to use it when creating new skills, editing existing skills, or verifying skills work before deployment. Editing counts: its iron law covers edits to existing skills as well as new ones.

Example requests:

- "Write a skill that makes the agent run our release checklist."
- "Tighten the wording in the debugging skill, it keeps getting skipped."
- "Check whether this new skill holds up when the agent is under time pressure."

## What it does

The skill maps test-driven development onto documentation. A pressure scenario run with a subagent is the test case, the skill document is the production code, and the agent violating the rule without the skill is the failing test.

1. **Red: baseline.** The agent runs a pressure scenario with a subagent without the skill and records what it did and the rationalizations it used, word for word. Discipline skills get scenarios that combine three or more pressures, such as time, sunk cost, and exhaustion.
2. **Green: write the minimal skill.** The skill addresses those specific failures and adds nothing for hypothetical cases. The agent runs the same scenarios with the skill present and checks that the subagent complies.
3. **Refactor: close loopholes.** New rationalizations get explicit counters, go into a rationalization table, and feed a red-flags list. The agent re-tests until the skill holds.

The iron law is no skill without a failing test first. It applies to new skills and to edits. A skill written before testing is deleted, and an edit without testing is the same violation. The skill lists no exceptions for simple additions, added sections, or documentation updates.

The skill also sets out:

- **Structure.** Each skill has a `SKILL.md` with two required frontmatter fields, `name` and `description`. Supporting files are for heavy reference (100 or more lines) or reusable tools. Everything else stays inline.
- **The description states triggering conditions only.** It starts with "Use when", is written in the third person, and never summarizes the skill's process. The skill gives its reason: when a description summarizes the workflow, an agent may follow the description and skip the skill body.
- **Match the form to the failure.** A rule skipped under pressure gets a prohibition with a rationalization table and red flags. Output with the wrong shape gets a positive recipe. An omitted element gets a required slot in the template. A conditional behavior gets a condition on something observable. The skill says prohibitions can backfire on shaping problems, and tells the agent to micro-test its own case.
- **Micro-tests before full scenarios.** For behavior-shaping guidance, the agent verifies the wording first with one fresh sample per call, a control with no guidance, five or more repetitions per variant, every flagged match read by hand, and variance treated as a signal. The checklist marks this step not applicable to pure reference skills. Micro-tests verify wording and do not replace pressure scenarios for discipline skills.
- **Testing by skill type.** Discipline, technique, pattern, and reference skills each have their own kind of test and success criterion.
- **Other guidance.** Keep frequently loaded skills short, cross-reference other skills by name with `REQUIRED SUB-SKILL` or `REQUIRED BACKGROUND` markers, use flowcharts only for non-obvious decisions, and give one good example and not several mediocre ones.

After writing any skill, the agent stops and completes the deployment checklist before it moves to the next skill. The skill forbids batching several untested skills.

## Why it exists

The core principle is that if you did not watch an agent fail without the skill, you do not know whether the skill teaches the right thing. The skill treats skills as behavior-shaping documents that need tests like code does. Its rationalizations table covers excuses such as "skill is obviously clear", "it's just a reference", and "no time to test". The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- A skill is written against failures that were observed, so its text answers what agents actually do.
- Editing a skill carries the same test requirement as writing one, so the skill does not drift untested.
- The description rule keeps the trigger text from standing in for the skill's body.
- The form table matches the guidance style to the kind of failure.
- Micro-tests give a cheaper way to check wording before running full scenarios.

## Cons and costs

- Every new skill or edit needs baseline runs with subagents before and after, which takes much more time than writing the text.
- The baseline step asks the agent to record each rationalization word for word, which is detailed manual work.
- The skill is long, with several supporting files, and it asks for a todo per checklist item.
- The pressure-scenario method is built around discipline skills. Other skill types use different tests, and the agent has to pick the right kind.
- The iron law has no exception for small edits, so a one-word fix to a skill still needs a test.

## Skipping or overriding

The skill gives no way to skip the test-first rule. Its rationalizations table says every excuse for skipping testing means testing before deployment, with no exceptions. The skill does vary the kind of test by skill type: a reference skill gets retrieval, application, and gap scenarios, and a discipline skill gets pressure scenarios.

## Works with

- {doc}`test-driven-development` is required background. This skill adapts its red-green-refactor cycle to documentation and tells the agent to understand it first. In the other direction, that skill's test-writing guide points here for tests of an agent's behavior, which are tests of skills.
- {doc}`using-hyperpowers` is where the per-harness reference files live. This skill links to its Codex file for where personal skills live on Codex.

## Under the hood

{source}`skills/writing-skills/SKILL.md` holds the method, the iron law, the form table, and the checklist. The main supporting files:

- {source}`skills/writing-skills/testing-skills-with-subagents.md` is the full testing guide: how to write pressure scenarios, the pressure types, and how to plug holes.
- {source}`skills/writing-skills/anthropic-best-practices.md` is the official skill authoring guidance the skill points to.
- {source}`skills/writing-skills/persuasion-principles.md` is the research background on why rationalization-resistant wording works.
- {source}`skills/writing-skills/examples/CLAUDE_MD_TESTING.md` is a worked test campaign for CLAUDE.md variants.
- {source}`skills/writing-skills/graphviz-conventions.dot` and {source}`skills/writing-skills/render-graphs.js` hold flowchart style rules and a script that renders a skill's flowcharts to SVG.
