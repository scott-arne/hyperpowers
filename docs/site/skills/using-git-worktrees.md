---
sources: skills/using-git-worktrees skills/executing-plans/SKILL.md skills/subagent-driven-development/SKILL.md skills/writing-plans/SKILL.md skills/finishing-a-development-branch/SKILL.md
source-digest: 0611dd729cb4
---
# using-git-worktrees

`using-git-worktrees` settles where the work happens before it starts: it reuses an isolated workspace if one exists, otherwise asks you where to work, and then confirms the project's tests pass in that spot.

:::{card} At a glance
**Category:** Process · **Triggers on:** starting feature work that needs isolation from the current workspace, or before executing implementation plans · **Hands off to:** the skill that called it, which records the mode it reports ({doc}`finishing-a-development-branch` later routes on that mode) · **Harness notes:** prefers the harness's native worktree tool; falls back to `git worktree add`
:::

## When it triggers

The skill's description says to use it when you start feature work that needs isolation from the current workspace, or before you execute an implementation plan. In practice {doc}`executing-plans` and {doc}`subagent-driven-development` both call it in their first step, so you meet it at the start of plan execution more often than by asking for it.

Example requests:

- "Set up an isolated workspace for this feature."
- "Work on this in a worktree, not on my current branch."
- Any plan execution, where the executing skill calls it for you.

## What it does

The agent announces that it is using the skill to settle where the work happens, then follows these steps.

1. **Detect existing isolation.** Before it creates anything, it compares the git directory with the common git directory and checks for a submodule, because the two differ inside a submodule too. If it is already in a linked worktree, it reports the path and branch (or a detached HEAD) and skips creation. The mode is `worktree`.
2. **Ask where the work happens.** In a normal checkout, if you have not already declared a choice in an instruction file, the agent asks one question with three options in this order: stay on the current branch, create a new branch in place, or create an isolated worktree. If you declared a choice, it honors it without asking. Choosing the current branch is explicit consent to work there, main or master included. The answer becomes the mode: `current-branch`, `new-branch`, or `worktree`.
3. **Create the worktree, if you chose one.** It prefers the harness's native worktree tool (a tool such as `EnterWorktree`, a `/worktree` command, or a `--worktree` flag), because native tools handle placement, branching, and cleanup. Only when no native tool exists does it run `git worktree add`. For that fallback it uses a directory you named, otherwise an existing `.worktrees/` or `worktrees/` directory, otherwise `.worktrees/` at the project root, and it checks that the directory is ignored by git, adding it to `.gitignore` and committing the change if it is not.
4. **Run project setup.** It detects the project type from files such as `package.json`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, or `go.mod` and runs the matching install or build.
5. **Verify a clean baseline.** It runs the project's tests. If they fail, it reports the failures and asks whether to proceed or investigate. If they pass, it reports ready.

A later session of an SDD plan that is already running does not start on a new branch. It gets a worktree detached at the integration branch's head, named with its session id, because the integration branch is checked out nowhere while sessions work: each claim creates a task branch, and the worktree detaches again after each merge-back. An existing worktree, a native tool's worktree, or work in place gets `git switch --detach` to the integration branch before the session's first claim, and a session that finds itself inside another session's worktree leaves it and creates its own.

The final report names the workspace (or the branch, when no worktree was created), the mode, the passing test count, and the feature it is ready to implement. The mode line is always present, because the calling skill records it.

If a native tool is denied or fails, or `git worktree add` is blocked by the sandbox, the agent does not fall back silently. It asks the three-way question again with only the first two options, and reports the answer as the mode. It never reports `worktree` unless a worktree exists.

## Why it exists

Working directly in your current checkout mixes the agent's changes with whatever else is there, and a failing baseline makes every later failure ambiguous. The skill's rationalizations table gives the reasons for its checks: eyeballing misses harness-created isolation and submodules, bypassing a native tool creates state the harness cannot see or manage, an unignored worktree directory commits the whole tree into the repository, and tests run after the fact cannot say whether a failure was already there. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- Existing isolation is detected first, so the agent never nests a second worktree inside one.
- You get a single, ordered choice (current branch, new branch, worktree) instead of the agent deciding for you, and a declared preference skips the question.
- Using the harness's native tool keeps the harness aware of the worktree it must manage.
- A baseline test run before work starts separates failures that were already there from failures the agent causes.
- The reported mode lets later skills handle the branch correctly when the work finishes.

## Cons and costs

- Setup and the baseline run take time before any real work starts, and a large project install or slow test suite makes that visible.
- The setup step is a short list of common project types. Other build systems get no automatic setup from this skill.
- A failing baseline stops the flow to ask you, which interrupts a plan that was meant to run unattended.
- In a sandboxed harness, creating the worktree can be refused, and you get the fallback question instead of a worktree.
- A worktree is another checkout on disk, and the setup step runs again inside it.

## Skipping or overriding

Tell the agent where to work in an instruction file or in your request ("work on the current branch", "create a new branch `feature-x`"), and it honors that without asking. Choosing the current branch is a legitimate override when you want no isolation; the skill treats it as consent. The baseline run itself always happens. What stays with you is the decision after a failure: the skill reports the failing tests and asks whether to proceed or investigate.

## Works with

- {doc}`executing-plans` calls it as step 1 and passes the mode on to {doc}`finishing-a-development-branch`.
- {doc}`subagent-driven-development` calls it first during setup and records the mode in its ledger.
- {doc}`writing-plans` notes that a worktree should have been created with this skill at execution time.
- {doc}`finishing-a-development-branch` routes on the mode this skill reports and cleans up worktrees under `.worktrees/` or `worktrees/`.

## Under the hood

{source}`skills/using-git-worktrees/SKILL.md` is the whole skill. It has no supporting files or scripts.
