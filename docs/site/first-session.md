# A first session

This page is illustrative. It describes what the skills do at each step when you send one request, and it quotes no real transcript. Details such as the number of questions depend on your project and your answers.

The request:

> Let's make a react todo list

## 1. Brainstorming classifies and asks

{doc}`skills/brainstorming` loads first and the agent says its classification aloud. A new project has no existing flow to change, so the skill's rule classifies it as architectural, even though a todo list sounds small. You can override the classification.

The agent explores the project context, then asks clarifying questions one per message. If a question is easier to answer when shown, such as where the list and the input go on the page, the agent starts the visual companion and tells you in the same message. On Claude Code, when the design space has real alternatives, the agent can also ask Codex for approaches. It then proposes two or three approaches with a recommendation.

## 2. You approve a design

The agent presents the design in sections and asks after each. It writes the approved design as a spec in `docs/hyperpowers/specs/`, commits it, and checks it for placeholders, contradictions, scope, and ambiguity. On Claude Code it runs the Codex spec review next. Then it asks you to read the spec file. Nothing is implemented before you approve.

## 3. A plan is written

After you approve the spec, the agent invokes {doc}`skills/writing-plans`. The plan goes to `docs/hyperpowers/plans/` as small tasks, each with exact file paths and steps, and emphasizes TDD, YAGNI, and DRY. On Claude Code the plan gets a Codex review before you see it. The skill then announces that it is executing with subagent-driven development, with no question about the execution method.

## 4. Subagents run the tasks

{doc}`skills/subagent-driven-development` first settles where the work happens through {doc}`skills/using-git-worktrees`, which asks whether to stay on the current branch, start a new branch, or use a worktree. The controller keeps a ledger file of progress. For each task it dispatches a fresh implementer subagent. A task reviewer then returns a spec-compliance verdict and a code-quality verdict, and findings go through a fix loop. The controller does not stop between tasks to check in.

When all tasks are done, a whole-branch review runs on the most capable available model, with one fix wave at most.

## 5. The branch is finished

{doc}`skills/finishing-a-development-branch` records the spec's decisions, runs the tests, and offers three outcomes: merge locally, push and open a pull request, or keep the branch. If you ask to discard the work, it asks you to confirm first. It cleans up the worktree after a merge or a confirmed discard.

For the same path as a diagram, see {doc}`workflow`.
