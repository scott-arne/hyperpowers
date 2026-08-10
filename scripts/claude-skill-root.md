---
name: hyperpowers
description: Software-engineering workflow skills - brainstorm designs, write specs and plans, TDD, systematic debugging, and code review. Use when starting any coding, design, planning, debugging, or review task.
---

# Hyperpowers {{VERSION}} (bundled for Claude Desktop / claude.ai)

Hyperpowers is a complete software development methodology for coding agents. It provides composable skills that guide you through brainstorming, spec writing, implementation planning, test-driven development, systematic debugging, and code review.

## Skill Catalog

The skills bundled in this package:

- **brainstorming** — Use before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation. → `skills/brainstorming/SKILL.md`
- **dispatching-parallel-agents** — Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies. → `skills/dispatching-parallel-agents/SKILL.md`
- **executing-plans** — Use when you have a written implementation plan to execute in a separate session with review checkpoints. → `skills/executing-plans/SKILL.md`
- **finishing-a-development-branch** — Use when implementation is complete, all tests pass, and you need to decide how to integrate the work. Guides completion of development work by presenting structured options for merge, PR, or cleanup. → `skills/finishing-a-development-branch/SKILL.md`
- **optimizing-performance** — Use when you intend to actually make code faster and land the change. A confirmed hot path, a performance regression, or a concrete speed/memory/throughput target, not just diagnose it. → `skills/optimizing-performance/SKILL.md`
- **profiling-performance** — Use when code is slower than expected, latency or throughput has regressed, memory/allocation use is unexplained, a hot loop is suspected, a throughput ceiling is hit, or optimization is being considered. → `skills/profiling-performance/SKILL.md`
- **receiving-code-review** — Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable. Requires technical rigor and verification, not performative compliance. → `skills/receiving-code-review/SKILL.md`
- **requesting-code-review** — Use when completing tasks, implementing major features, or before merging to verify work meets requirements. → `skills/requesting-code-review/SKILL.md`
- **subagent-driven-development** — Use when executing implementation plans with independent tasks in the current session. → `skills/subagent-driven-development/SKILL.md`
- **systematic-debugging** — Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes. → `skills/systematic-debugging/SKILL.md`
- **test-driven-development** — Use when implementing any feature or bugfix, before writing implementation code. → `skills/test-driven-development/SKILL.md`
- **using-git-worktrees** — Use when starting feature work that needs isolation from current workspace or before executing implementation plans. Ensures an isolated workspace exists via native tools or git worktree fallback. → `skills/using-git-worktrees/SKILL.md`
- **using-hyperpowers** — Use when starting any conversation. Establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions. → `skills/using-hyperpowers/SKILL.md`
- **writing-plans** — Use when you have a spec or requirements for a multi-step task, before touching code. → `skills/writing-plans/SKILL.md`
- **writing-skills** — Use when creating new skills, editing existing skills, or verifying skills work before deployment. → `skills/writing-skills/SKILL.md`

## The Rule

**Before ANY response—including clarifying questions—check whether a skill applies.** Even a 1% chance means you should read the skill's file fully and follow it.

In this bundled environment, you load skills by **reading their full `skills/<name>/SKILL.md` file directly**. Reading the file replaces the `Skill` tool you would use in Claude Code or other harnesses. When a skill applies:

1. Read the complete `skills/<name>/SKILL.md` file.
2. Follow its instructions exactly.
3. Do not rationalize or skip steps.

If the skill turns out not to apply after reading it, that's fine—continue with the task.

## Instruction Priority

These skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, direct requests) — highest priority
2. **Hyperpowers skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

If user instructions say "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

## Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, systematic-debugging) — these determine HOW to approach the task
2. **Implementation skills second** (test-driven-development, writing-plans) — these guide execution

"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → systematic-debugging first, then domain-specific skills.

## Environment Adaptations

This bundle runs in Claude Desktop / claude.ai, where some Claude Code-specific infrastructure is unavailable:

- **Codex review gates:** Every skill that mentions a "Codex review gate" (specs, plans, code) has a documented fallback path for when codex-plugin-cc is not available. In this environment, Codex gates CANNOT run. When a skill reaches a Codex gate step, emit the notice "Codex review gate unavailable in this environment; proceeding per skill's no-Codex path" ONCE (the first time you encounter a gate), then follow the skill's documented fallback. **Never fabricate a Codex verdict.** The skills work fully without Codex—the gates are optional second-opinions.

- **Helper scripts and plugin infrastructure:** Skills may reference helper scripts under `${CLAUDE_PLUGIN_ROOT}`, session hooks, git-keyed scratch directories, or plugin cache paths. These are Claude Code-specific mechanisms. When a skill's helper script cannot run, follow the skill's prose contract manually and keep any durable notes it would have written in the working directory instead (e.g., markdown files for plans, specs, or review reports).

- **Subagent dispatches:** Skills that dispatch subagents assume a dispatch tool is available. When no dispatch tool exists in this environment, execute the work sequentially in the current conversation instead. Treat each "dispatch" instruction as "do this work now, in-conversation."

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Read it. |

## Getting Started

Read `skills/using-hyperpowers/SKILL.md` now to understand the full skill-invocation discipline, then check the catalog above for the skill that matches your current task.
