# Hyperpowers

Hyperpowers is a set of skills and a session-start bootstrap that give a coding agent a working method: design before code, tests before implementation, review before "done". It runs in ten agent harnesses, including Claude Code, Codex, and Cursor, plus seven more.

Left alone, a coding agent starts writing code as soon as it sees a request. Hyperpowers has it classify how much process the request needs (a feasibility spike, a bounded change, or architectural work) and ask what you are trying to do first. The ceremony scales with that classification. The approval gate before implementation applies every time. After you sign off on the design, the agent writes a plan and works through it task by task with subagents, reviewing each one.

## Where to start

- If you are new, read the guide pages.
- To choose skills, use the skills reference.
- To lower cost, read the recommended settings.

## Credit

Hyperpowers is a fork of [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent and Prime Radiant, who designed the methodology and most of the skills. This fork adds Codex review gates, decision records, and other changes. Scott Johnson maintains it.

Full installation commands are in the {source}`README.md`.

```{toctree}
:caption: Guide
:hidden:

why
install
first-session
workflow
```

```{toctree}
:caption: Skills
:hidden:

skills/index
```

```{toctree}
:caption: Process skills
:hidden:

skills/brainstorming
skills/writing-plans
skills/executing-plans
skills/subagent-driven-development
skills/dispatching-parallel-agents
skills/using-git-worktrees
skills/finishing-a-development-branch
skills/communication
```

```{toctree}
:caption: Testing skills
:hidden:

skills/test-driven-development
```

```{toctree}
:caption: Debugging skills
:hidden:

skills/systematic-debugging
```

```{toctree}
:caption: Review skills
:hidden:

skills/requesting-code-review
skills/receiving-code-review
```

```{toctree}
:caption: Performance skills
:hidden:

skills/profiling-performance
skills/optimizing-performance
```

```{toctree}
:caption: Meta skills
:hidden:

skills/using-hyperpowers
skills/writing-skills
```

```{toctree}
:caption: Advanced
:hidden:

advanced/triggering
advanced/codex-gates
advanced/sdd-internals
advanced/decision-records
advanced/testing-skills
advanced/customizing
```

```{toctree}
:caption: About
:hidden:

superpowers
```
