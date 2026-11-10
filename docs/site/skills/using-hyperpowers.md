---
sources: skills/using-hyperpowers hooks/session-start hooks/session-start-codex hooks/hooks.json hooks/hooks-codex.json hooks/hooks-cursor.json hooks/run-hook.cmd .cursor-plugin/plugin.json .codex-plugin/plugin.json skills/executing-plans/SKILL.md skills/subagent-driven-development/SKILL.md skills/writing-skills/SKILL.md skills/requesting-code-review/scripts/ungated-ledger skills/subagent-driven-development/scripts/sdd-common.sh .claude-plugin/plugin.json README.md RELEASE-NOTES.md
source-digest: 5c93e72034c8
---
# using-hyperpowers

`using-hyperpowers` is the bootstrap skill: a session-start hook injects its text (at session start on Claude Code, Codex, and Cursor, and also after `/clear` and after compaction on Claude Code and Codex), and it tells the agent to invoke any skill that might apply before it responds or acts.

:::{card} At a glance
**Category:** Meta · **Triggers on:** session start on Claude Code, Codex, and Cursor (Claude Code and Codex also after `/clear` and compaction), through a session-start hook; the README says Antigravity runs the plugin's session-start hook, and upstream's release notes say Copilot CLI gets the bootstrap at session start · **Hands off to:** {doc}`brainstorming` (build requests), {doc}`systematic-debugging` (bug reports), and {doc}`communication` (prose you will read) · **Harness notes:** Codex runs its own hook, which injects the skill without the notices; Codex, Pi, and Antigravity have reference files with harness-specific instructions
:::

## When it triggers

The skill's description says to use it when starting any conversation. It establishes how to find and use skills, and requires skill invocation before any response, including clarifying questions. You do not invoke it. A session-start hook injects it when a session starts on Claude Code, Codex, or Cursor. On Claude Code and Codex the hook also runs after `/clear` and after compaction.

A subagent that was dispatched to execute a specific task ignores it. The skill opens with a short block saying so.

Example situations:

- You open a session and type "Let's build a todo app". The injected text sends the agent to {doc}`brainstorming` first.
- You paste a failing test and say "fix this". The injected text sends the agent to {doc}`systematic-debugging` first.
- You ask a quick question about the code. The skill's red-flags table lists "this is just a simple question" as a thought that means the agent should check for skills first.

## What it does

**The injection.** The hook `hooks/session-start` serves Claude Code, Cursor, and Copilot CLI, and the Claude Code and Cursor configurations call it through `hooks/run-hook.cmd`. Claude Code's configuration (`hooks/hooks.json`) runs it at session start, after `/clear`, and after compaction (it matches `startup|clear|compact`). Cursor's (`hooks/hooks-cursor.json`, registered in `.cursor-plugin/plugin.json`) sets only `sessionStart`. For Copilot CLI, the upstream release notes ({source}`RELEASE-NOTES.md`) say the hook detects `COPILOT_CLI`, emits a top-level `additionalContext` form, and so gives Copilot CLI the bootstrap at session start. No hooks file here names Copilot CLI. The hook reads this skill's `SKILL.md`, wraps it in a short "You have superpowers" message, and returns it to the harness as session context. The JSON field it uses depends on the harness: one for Cursor, one nested for Claude Code, and a top-level one for Copilot CLI and others. After the skill text, this hook can add one-line notices, each only when it applies. One says that ungated review items are pending in the repository, and one says that a newer marketplace version of the plugin is available than the one the session loaded. The third appears when a session resumes after compaction and the repository has a subagent-driven-development ledger, and it points the agent to that ledger so it does not replay finished tasks. Codex's configuration (`hooks/hooks-codex.json`, registered in `.codex-plugin/plugin.json`) runs `hooks/session-start-codex` through the same launcher on the same three events as Claude Code. It injects the same skill text with a different wrapper sentence and adds no notices.

**The rule.** The agent invokes relevant or requested skills before any response or action, including clarifying questions, codebase exploration, and file checks. The skill states the bar as a 1% chance that a skill applies, and says that if the skill turns out wrong for the situation, the agent does not have to use it. Before entering plan mode, if the agent has not brainstormed yet, it invokes {doc}`brainstorming` first. Then the agent announces "Using [skill] to [purpose]", follows the skill exactly, and creates a todo for each checklist item.

**Priority.** When several skills apply, process skills come first because they set the approach, and implementation skills carry it out. "Let's build X" goes to {doc}`brainstorming`, "fix this bug" goes to {doc}`systematic-debugging`, and writing for you (a summary, a finding, a design, a plan, a recommendation, or any reply longer than a few sentences) goes to {doc}`communication` before the agent writes it.

**Red flags.** A table lists twelve thoughts that mean the agent is rationalizing, among them "I need more context first", "let me explore the codebase first", "the skill is overkill", and "I remember this skill". Each has a one-line answer. For "I remember this skill" the answer is that skills evolve, so the agent reads the current version.

**Platform adaptation.** For Codex, Pi, and Antigravity, the skill points to a reference file with that harness's special instructions.

**Your instructions.** User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, direct requests) take precedence over skills, which in turn override default behavior. The agent skips skill workflows only when you have explicitly said to.

## Why it exists

The skill exists to make skill use automatic. Its table answers each excuse the agent might use to skip a skill, and the answer to "this feels productive" is that undisciplined action wastes time. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- Skills start applying from the first message, with no setup step per session.
- Process skills run before implementation work, so design and diagnosis come first.
- A red-flags table names the excuses for skipping a skill, so the agent can recognize them.
- Your own instructions outrank the skills, so you can always change the workflow.
- Per-harness reference files adapt the instructions to tools that differ from Claude Code's.

## Cons and costs

- The full skill text is injected each time the hook runs, whether or not a skill ends up applying.
- The 1% bar means the agent invokes skills in cases where one turns out not to fit. The skill accepts this and tells the agent it need not follow a skill that does not apply.
- Even a quick question can pick up a skill check before the agent answers.
- The injected text uses forceful wording ("YOU MUST", "not negotiable") that sets a strict tone from the first message.

## Skipping or overriding

You can tell the agent to skip a skill. The skill says user instructions take precedence over skills, and that the agent skips skill workflows only when you have explicitly told it to. Instructions in CLAUDE.md, AGENTS.md, or GEMINI.md also take precedence over skills.

## Works with

- {doc}`brainstorming` is the first stop for "let's build X" and before entering plan mode.
- {doc}`systematic-debugging` is the first stop for "fix this bug".
- {doc}`communication` is invoked before writing a summary, finding, design, plan, recommendation, or any reply longer than a few sentences.
- {doc}`executing-plans` points to this skill's references directory for per-platform tool notes. {doc}`subagent-driven-development` and {doc}`writing-skills` each point to its `codex-tools.md` file.

This skill is the entry point for the rest: it names three skills, and its rule applies to all of them.

## Under the hood

{source}`hooks/session-start` is the hook that injects the skill and adds the notices. {source}`hooks/session-start-codex` is the Codex hook, and {source}`hooks/hooks.json` and {source}`hooks/hooks-codex.json` set the events for Claude Code and Codex. {source}`hooks/hooks-cursor.json` does the same for Cursor, and {source}`hooks/run-hook.cmd` is the launcher all three call. The skill is {source}`skills/using-hyperpowers/SKILL.md`. Its three harness reference files are:

- {source}`skills/using-hyperpowers/references/codex-tools.md`
- {source}`skills/using-hyperpowers/references/pi-tools.md`
- {source}`skills/using-hyperpowers/references/antigravity-tools.md`
