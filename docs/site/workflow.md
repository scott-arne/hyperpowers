# The workflow

Every request that changes behavior starts in {doc}`skills/brainstorming`, which classifies it into one of three paths. The path sets how much process follows. Your approval before implementation applies on all three.

```{mermaid}
flowchart LR
  A[Request] --> B{brainstorming:<br/>classify}
  B -->|spike| C[Answer, nothing kept]
  B -->|bounded| D[Short design in chat] --> G[Implement with TDD]
  B -->|architectural| E[Spec] --> F[writing-plans] --> H[subagent-driven-development]
  H --> I[finishing-a-development-branch]
  G --> I
```

## The three paths

| Path | Request looks like | What it produces |
|---|---|---|
| Spike | A feasibility question: "can we...", "is it possible...", "quick and dirty is fine" | An answer and a recommendation. Anything built stays labeled throwaway, and no spec file is written. |
| Bounded | A well-scoped change to code that already exists in the repository, such as a new flag or a one-file fix | A short design in chat. After you say yes, implementation goes through the normal development workflow with TDD. There is no spec file and no plan document. |
| Architectural | A new project, a new subsystem, or a change that restructures how components fit or alters interfaces others depend on | A spec in `docs/hyperpowers/specs/`, then a plan from {doc}`skills/writing-plans`, then execution with {doc}`skills/subagent-driven-development`. |

When the agent is unsure between two paths it takes the heavier one. If hidden complexity turns up during the work, it stops and steps up a path. It never steps down.

## Which skill takes over

| Step | Skill | What it does |
|---|---|---|
| Classify and design | {doc}`skills/brainstorming` | Announces the path, asks questions one at a time, gets your approval. On the architectural path it also writes and commits the spec. |
| Choose where the work happens | {doc}`skills/using-git-worktrees` | Detects an existing worktree or asks whether to stay on the current branch, use a new branch, or use a worktree. Subagent-driven development invokes it during setup. |
| Plan | {doc}`skills/writing-plans` | Breaks an approved spec into tasks with exact files and steps, then hands off to execution. |
| Execute | {doc}`skills/subagent-driven-development` | Dispatches a fresh subagent per task (or per batch of small same-shape tasks), reviews each task, and reviews the whole branch at the end. {doc}`skills/executing-plans` is the alternative when you ask for inline execution. |
| Implement | {doc}`skills/test-driven-development` | Requires a failing test before production code. |
| Review | {doc}`skills/requesting-code-review` | Holds the code reviewer prompt that the final whole-branch review uses. |
| Finish | {doc}`skills/finishing-a-development-branch` | Records decisions, runs the tests, offers merge, pull request, or keep (and discard when you ask), and cleans up. |

The README's Basic Workflow list shows worktrees as the second step after design approval. The skill text places the worktree choice in subagent-driven development's setup, and this page follows the skill text.

All skills are listed in {doc}`skills/index`.
