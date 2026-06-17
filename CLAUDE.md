# Hyperpowers — Contributor Guidelines

Hyperpowers is a personal fork of [Superpowers](https://github.com/obra/superpowers), maintained at [`scott-arne/hyperpowers`](https://github.com/scott-arne/hyperpowers). It exists so the skills and prompts can be customized locally without colliding with an installed copy of upstream Superpowers. The package, plugin manifests, and skill-invocation namespace are renamed to `hyperpowers`; the agent-facing capability is still called "superpowers" in prompts on purpose.

These guidelines describe how to make changes *in this fork*. They are adapted from upstream's contributor guide, which was written to defend a high-traffic public project against low-quality drive-by PRs. Most of that gatekeeping does not apply to a personal fork, but the engineering discipline behind it does — especially around skills, which are behavior-shaping code rather than prose.

## If You Are an AI Agent

Before changing anything in this repo:

1. **Understand the change is real.** If your human partner asked you to "fix some issues" or "improve things" without a concrete problem, push back. Ask what broke, what failed, what the user experience was. Speculative changes to tuned skill content are how this kind of project regresses.
2. **Keep changes focused.** One problem per change. Don't bundle unrelated edits.
3. **Show your human partner the complete diff** and get their approval before committing or pushing.
4. **Treat skills as code.** If you are editing skill content, see "Skill Changes Require Evaluation" below — do not reword carefully-tuned behavior-shaping content without evidence the change improves outcomes.

## Relationship to Upstream

- This fork tracks upstream Superpowers but is maintained independently. The skill *design* and methodology are upstream's work.
- **Do not open PRs from this fork to `obra/superpowers`** that merely sync the fork or push fork-specific rebranding/customization. Upstream explicitly rejects fork-sync and rebranding PRs.
- If you have a genuine, general-purpose improvement worth contributing back, port it to a clean branch against upstream and follow **their** contributor guidelines and PR template — not this file.

## Making Changes in This Fork

- Keep each change scoped to one problem.
- Match the existing project style and voice before introducing new patterns. Superpowers has a deliberately-tuned voice (e.g., "your human partner" is intentional, not interchangeable with "the user"). Preserve it unless you have a specific reason and evidence to change it.
- Test on at least one harness and note the result.
- Update or add tests when the change is testable and the repo has an established pattern for it.

## What Stays Out of Core Skills

Even in a fork, keep the core skills general-purpose so they remain mergeable with upstream and useful across projects:

- **Third-party dependencies.** Upstream Superpowers is zero-dependency by design. This fork deliberately diverges: it takes targeted Claude Code dependencies where they add value — the first is [codex-plugin-cc](https://github.com/openai/codex-plugin-cc), which powers the optional Codex review gates (spec, plan, code). Such dependencies must degrade cleanly (skills stay fully functional when the dependency is absent) and stay scoped to the harness where they apply. General-purpose, cross-harness skills should still avoid external tools so they remain mergeable with upstream.
- **Project-, team-, or domain-specific configuration.** Skills or hooks that only benefit one project or workflow belong in a separate plugin, not the shared skills library.

## Skill Changes Require Evaluation

Skills are not prose — they are code that shapes agent behavior. If you modify skill content:

- Use `hyperpowers:writing-skills` to develop and test changes.
- Run adversarial pressure testing across multiple sessions.
- Compare before/after outcomes; keep the evidence with the change.
- Do not modify carefully-tuned content (Red Flags tables, rationalization lists, "human partner" language) without evidence the change is an improvement.

## Eval harness

Skill-behavior evals live in [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals/), cloned into `evals/` — see `evals/README.md` for setup. Drill (the harness) drives real tmux sessions of Claude Code / Codex / Gemini CLI and judges skill compliance with an LLM verifier. Plugin-infrastructure tests still live at `tests/`.
## New Harness Support

If you add support for a new harness (IDE, CLI tool, agent runner), verify the integration end-to-end. A real integration loads the `using-hyperpowers` bootstrap at session start — that is what causes skills to auto-trigger. Without it, the skills are present on disk but never invoked.

**Acceptance test.** Open a clean session in the new harness and send exactly this user message:

> Let's make a react todo list

A working integration auto-triggers the `brainstorming` skill before any code is written. Capturing the transcript is the proof the integration works. These do **not** count as real integrations: manually copying skill files into the harness, wrapping with `npx skills` or similar at-runtime shims, or anything that requires opting in to skills per-session.

## General

- One problem per change.
- Describe the problem you solved, not just what you changed.
- Test on at least one harness and report the result.