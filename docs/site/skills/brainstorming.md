---
sources: skills/brainstorming skills/requesting-code-review/codex-review-gate.md skills/using-hyperpowers/SKILL.md
source-digest: ad72f3d9e9f2
---
# brainstorming

Before the agent writes any code, `brainstorming` classifies your request, works out what you want through questions, and gets your approval of a design.

:::{card} At a glance
**Category:** Process · **Triggers on:** any request to create a feature, build a component, add functionality, or change behavior · **Hands off to:** {doc}`writing-plans` (architectural path only) · **Harness notes:** the Codex approach consultation and spec review run on Claude Code only; the visual companion needs a browser
:::

## When it triggers

The skill's description says the agent must use it before any creative work: creating features, building components, adding functionality, or modifying behavior. In plain words, any request that would change what the code does starts here, however small.

Example requests:

- "Let's make a React todo list."
- "Add a `--dry-run` flag to the export command."
- "Can we cache the search results? Quick and dirty is fine."

## What it does

The agent starts by classifying the request and saying the classification aloud, so you can override it. There are three paths:

- **Spike.** A feasibility question ("can we...", "is it possible..."). The agent states the question and what it will try in two or three sentences, waits for your nod, investigates as cheaply as correctness allows, and reports a recommendation. Anything it built stays labeled throwaway. No spec file.
- **Bounded.** A well-scoped change to code that already exists in the repository, such as a new flag or a one-file fix. The agent asks the clarifying questions that matter, presents a short design in chat, and stops. It implements only after you say yes. No spec file and no plan document.
- **Architectural.** A new project, a new subsystem, or a change that restructures how components fit or alters interfaces others depend on. A request that names structure the repository does not have (a new module, a logging subsystem, reuse across components that do not exist yet) is architectural even when the first edit is small.

When the agent is unsure between two paths it takes the heavier one. If hidden complexity turns up mid-task, it stops, says so, and steps up a path. It never steps down.

Every path ends with your approval before implementation. The skill states this as a hard gate: no implementation skill, no code, no scaffolding until you have been told what the agent intends and have approved it. The ceremony scales with the task, and the approval does not.

On the bounded and architectural paths the agent reads the project's current state, including the decisions index when one exists, and asks questions one per message. When the options differ in what happens afterward (an interface, a stored format, a default, a dependency, work that would be redone), it first posts a comparison in chat: the fork in one sentence, one line per option with what it buys and costs, and a recommendation. Then it asks you to choose. The skill calls this "Deciding Together".

Two optional steps can fire on any path:

- **Visual companion.** When a question would be clearer shown than described (a layout, a diagram, side-by-side options), the agent starts a local server and opens a browser tab, telling you in the same message. It decides per question: text questions stay in the terminal. The agent warns that the companion is token-intensive and drops it if you ask.
- **Codex approach consultation.** On Claude Code, when the design space has real architectural, algorithmic, or data-model alternatives, or when you ask for Codex input, the agent gives Codex your idea, your answers, and codebase facts, but not its own candidate approaches. Codex proposes two or three approaches once, and the agent merges them into its own with provenance tags such as `(Codex)` and `(both converged)`. If the Codex plugin is absent, the agent says so once and continues.

On the architectural path the agent then proposes two or three approaches with a recommendation, presents the design in sections and asks after each, and writes a spec to `docs/hyperpowers/specs/YYYY-MM-DD-<topic>-design.md`. The spec has a `## Decisions` section with one list item per decision. The agent commits the spec, checks it for placeholders, contradictions, scope, and ambiguity, runs the Codex spec review on Claude Code, and then asks you to review the written spec. After you approve, it invokes {doc}`writing-plans`. That is the only skill it invokes next.

After a context compaction, Claude Code re-attaches the skill cut to its first 20,000 characters, which ends before the spec-writing steps. The skill tells the agent to re-read its full text after every compaction before its next action.

## Why it exists

A coding agent given a request tends to start writing code, and the cost of unexamined assumptions lands in rework. The skill makes the agent ask what you are trying to do first, and it scales the effort to the request so a one-line fix does not get a design document. The spec's `## Decisions` list feeds the decision records the finishing skill compiles; the records are indexed in {source}`docs/hyperpowers/decisions/README.md`. The approach consultation comes from {source}`docs/hyperpowers/specs/2026-07-10-codex-design-collaboration-design.md`, which has Codex propose approaches blind so that its ideas are not anchored on the agent's.

## Pros

- You approve what will be built before any code exists, on every path.
- The agent says how much process it is applying, so you can ask for more or less.
- Questions come one at a time, with a written comparison before any choice that is costly to reverse.
- Architectural work leaves a committed spec that records what was decided and why.
- The Codex consultation and spec review give a second model's view, and the skill continues without them when Codex is absent.

## Cons and costs

- Every request, even a small one, adds a round trip before work starts: a classification, a design, and your yes.
- The architectural path is long: questions, approaches, sectioned design, spec, self-review, Codex review, your review, then planning. Expect many turns before code.
- The visual companion is token-intensive, and it opens a browser tab on your machine.
- The Codex steps need the Codex plugin and run on Claude Code only. Other harnesses skip them.
- The classification is a judgment call. The agent can pick a path that feels wrong to you, and you have to say so.

## Skipping or overriding

Tell the agent the path you want: "treat this as a spike", "skip the spec, a short design in chat is enough", or "stay text-only, no visual companion". The agent announces its classification so that you can do this. You cannot skip the approval itself while the skill is active, because the skill treats approval as mandatory on every path. On a small change, the way to keep it cheap is a two-sentence design in chat and a quick yes.

## Works with

- `using-hyperpowers` loads this skill when your request looks like creative work.
- {doc}`writing-plans` is the next step on the architectural path.
- `communication` governs everything you read from the agent during brainstorming: the questions, the comparison, the design, and the spec.
- `requesting-code-review` holds the Codex review gate that checks the spec before you see it.

## Under the hood

- {source}`skills/brainstorming/SKILL.md` holds the three paths, the checklists, and the spec steps.
- {source}`skills/brainstorming/codex-approach-gate.md` defines the one-shot Codex consultation: when it fires, the blind handoff, and how approaches are merged.
- {source}`skills/brainstorming/visual-companion.md` is the guide the agent reads before opening the companion.
- {source}`skills/brainstorming/scripts/start-server.sh` and {source}`skills/brainstorming/scripts/stop-server.sh` start and stop the companion's local server; `server.cjs`, `helper.js`, and `frame-template.html` in the same directory serve the pages.
- {source}`skills/requesting-code-review/codex-review-gate.md` is the shared Codex gate the spec review follows.
