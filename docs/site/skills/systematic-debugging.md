---
sources: skills/systematic-debugging skills/using-hyperpowers/SKILL.md
source-digest: 6373f72d49a9
---
# systematic-debugging

`systematic-debugging` stops the agent from guessing at fixes: it has to find the root cause of a bug first, test one hypothesis at a time, and question the design after three failed fixes.

:::{card} At a glance
**Category:** Debugging · **Triggers on:** any bug, test failure, or unexpected behavior, before proposing fixes · **Hands off to:** {doc}`test-driven-development` (the failing test in phase 4) and {doc}`communication` (reporting a root cause or hypothesis) · **Harness notes:** none
:::

## When it triggers

The skill's description says to use it when the agent meets any bug, test failure, or unexpected behavior, before it proposes a fix. Its "When to Use" list is broad: test failures, bugs in production, unexpected behavior, performance problems, build failures, and integration issues. It adds that the skill matters most under time pressure, when a quick fix looks obvious, and after a fix has already failed. The `using-hyperpowers` entry skill points "fix this bug" requests here first.

Example requests:

- "The checkout test started failing after yesterday's merge. Fix it."
- "The export job returns an empty file in CI but works locally."
- "That fix didn't work. Try something else."

## What it does

The skill's iron law is no fixes without root cause investigation first. The agent may not propose a fix until phase 1 is complete, and it completes each phase before the next.

1. **Root cause investigation.** The agent reads the error messages and stack traces in full, reproduces the failure reliably, and checks recent changes (diffs, commits, dependency and config changes). In a system with several components, it adds diagnostic logging at each boundary, runs once, and reads where the data goes wrong before it investigates one component. For an error deep in a call stack, it traces the bad value backward to its source and fixes it there.
2. **Pattern analysis.** The agent finds similar code that works, reads any reference implementation completely, lists every difference between the working and the broken code, and checks the dependencies and assumptions involved.
3. **Hypothesis and testing.** The agent states one hypothesis ("I think X is the root cause because Y"), tests it with the smallest possible change, and changes one variable at a time. If the change did not work, it forms a new hypothesis and does not stack more fixes on top. When it does not understand something, the skill tells it to say so.
4. **Implementation.** The agent creates a failing test case that reproduces the bug, using {doc}`test-driven-development` for a proper test, then makes a single fix for the root cause with no bundled refactoring, and re-runs the original failing command to confirm the failure is gone.

If a fix does not work, the agent counts its attempts. With fewer than three, it returns to phase 1 with the new information. After three failed fixes, it stops and questions the architecture. The skill names the signs: each fix reveals a new problem in a different place, fixes need large refactors, or each fix creates new symptoms elsewhere. The agent discusses this with you before attempting a fourth fix, and the skill calls it a wrong architecture, not a failed hypothesis.

If the investigation finishes and the cause really is environmental, timing dependent, or external, the skill counts the process as complete. The agent documents what it investigated, adds appropriate handling such as a retry, timeout, or clearer error message, and adds monitoring or logging for later.

## Why it exists

The skill opens with its reason: random fixes waste time and create new bugs, and quick patches hide the underlying issue. Its rationalizations table and red-flags list name the thoughts that lead to guessing ("just try changing X", "one more fix attempt" after two failures, "I see the problem, let me fix it") and send the agent back to phase 1. A section on your human partner's signals ("Stop guessing", "Is that not happening?") lists redirections that tell the agent it skipped evidence gathering. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`; none of them concerns this skill.

## Pros

- A root cause is found before a fix, so a fix addresses the cause and does not hide the symptom.
- One hypothesis and one change at a time lets you see what worked.
- Boundary logging in multi-component systems shows which layer fails before anyone edits code.
- The three-failures rule moves a stuck session to a design conversation with you and stops a run of patches.
- A failing test is required before the fix, so the bug has a regression test.

## Cons and costs

- Simple bugs go through the same four phases, so a one-line fix takes more steps than an immediate patch would.
- Diagnostic instrumentation in a multi-component system means adding logging and running the failing scenario once before any fix, which takes time and a runnable reproduction.
- The skill stops the agent after three failed fixes and asks you to discuss the architecture, which interrupts a run you expected to continue unattended.
- Its "no root cause" path ends in handling and monitoring, so an environmental or timing bug gets a workaround, not a fix.
- The supporting techniques are written around code with tests and call stacks, and the bundled example is TypeScript.

## Skipping or overriding

The skill gives no skip option. Its "Don't skip when" list names simple issues, hurry, and a manager who wants it fixed now, and the red-flags table says every shortcut thought means return to phase 1. Your decisions still shape the work. You decide what happens after the three-failures stop, because the skill requires the agent to discuss the architecture with you first.

## Works with

- {doc}`test-driven-development` supplies the failing test the agent writes in phase 4.
- {doc}`communication` is a required sub-skill for reporting a root cause, stating a hypothesis, or bringing a question to you.
- `using-hyperpowers` names this skill as the first stop for "fix this bug" requests, ahead of domain skills.

## Under the hood

{source}`skills/systematic-debugging/SKILL.md` holds the iron law, the four phases, the red flags, and the rationalizations table. Three technique files sit beside it and are listed in the skill as supporting techniques:

- {source}`skills/systematic-debugging/root-cause-tracing.md` traces a bug backward through the call stack to its original trigger. It also points to {source}`skills/systematic-debugging/find-polluter.sh`, a bisection script that finds which test creates unwanted files or state.
- {source}`skills/systematic-debugging/defense-in-depth.md` adds validation at several layers after the root cause is found.
- {source}`skills/systematic-debugging/condition-based-waiting.md` replaces arbitrary timeouts with condition polling, with a worked example in {source}`skills/systematic-debugging/condition-based-waiting-example.ts`.
