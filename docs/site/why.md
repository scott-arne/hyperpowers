# Why hyperpowers

A coding agent left to itself starts writing code as soon as it sees a request. Hyperpowers adds a method that runs before, during, and after the code, and it makes the agent follow that method without being asked.

## How agents fail without a method

Three failures recur:

- **Code before design.** The agent builds on its first reading of the request, so a wrong assumption surfaces after the work is done. {doc}`skills/brainstorming` makes the agent ask what you are trying to do and get your approval of a design before any code exists.
- **Tests after code, or no tests.** The plan the agent writes for implementers assumes engineers who would skip testing, so it asks for red/green TDD, YAGNI, and DRY. {doc}`skills/test-driven-development` requires a failing test before production code and deletes code written before its test.
- **"Done" without evidence.** The README lists "Evidence over claims" as a principle: verify before declaring success. {doc}`skills/subagent-driven-development` reviews each task and the whole branch, and {doc}`skills/finishing-a-development-branch` runs the tests before it offers to merge.

## Skills are tested like code

A skill is text that shapes what an agent does. A change to that text changes behavior, so {doc}`skills/writing-skills` applies test-driven development to it. You write a pressure scenario for a subagent, watch the agent violate the rule without the skill (the failing test), write the skill, and watch the agent comply. Then you close the loopholes the agent found. The skill's rule is that no skill is written without a failing test first.

## How the skills trigger

You do not name the skills. {doc}`skills/using-hyperpowers` is loaded at session start and tells the agent to invoke any skill that has even a 1% chance of applying, before any response or action, including clarifying questions. Each skill's `description` says when it applies, and the agent matches your request against those descriptions. For example, "Let's build X" goes to {doc}`skills/brainstorming` first. {doc}`install` lists which harnesses load the bootstrap and how.

## What it costs

The method asks more questions and uses more tokens up front than an agent that starts coding. A request to build or change something is classified first. Bounded and architectural work get a design and your approval before work begins. A spike gets a short statement of the question and the probe, and your nod. Architectural work adds a spec, a plan, and reviews. The ceremony shrinks for small requests (a short design in chat for a bounded change), and approval stays on every path. In return you see what will be built before it exists.

For the paths, see {doc}`workflow`. To see them applied to one request, read {doc}`first-session`.
