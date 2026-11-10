---
sources: skills/test-driven-development skills/systematic-debugging/SKILL.md skills/subagent-driven-development/SKILL.md skills/writing-skills/SKILL.md
source-digest: 26397535fa49
---
# test-driven-development

`test-driven-development` makes the agent write a failing test before any production code, watch it fail, write the least code that passes, and watch it pass.

:::{card} At a glance
**Category:** Testing · **Triggers on:** implementing any feature or bugfix, before writing implementation code · **Hands off to:** none; its `writing-good-tests.md` reference loads when tests are written or changed · **Harness notes:** none
:::

## When it triggers

The skill's description says to use it when you implement any feature or bugfix, before the agent writes implementation code. The skill's own "When to Use" list names new features, bug fixes, refactoring, and behavior changes.

Example requests:

- "Add retry logic to the upload client."
- "Fix the bug where an empty email is accepted."
- "Refactor the parser to handle nested lists."

The skill lists three exceptions to ask you about: throwaway prototypes, generated code, and configuration files.

## What it does

The skill states one rule, its iron law: no production code without a failing test first. The agent then works in a loop.

1. **Red.** It writes one minimal test for one behavior, with a clear name, using real code and no mocks unless they are unavoidable.
2. **Verify red.** It runs the test and confirms the test fails (an error does not count), that the failure message is the expected one, and that the test fails because the feature is missing and not because of a typo. A test that passes immediately is testing existing behavior and gets fixed. This step is marked mandatory.
3. **Green.** It writes the simplest code that passes the test, with no extra options or features.
4. **Verify green.** It runs the test again and confirms it passes, that other tests still pass, and that the output has no errors or warnings. If the test fails, the agent fixes the code and leaves the test alone.
5. **Refactor.** Only once everything is green, it removes duplication, improves names, and extracts helpers, without adding behavior.
6. **Repeat** with the next failing test.

If the agent wrote code before its test, the skill says to delete that code and start over. It may not keep the code as "reference", adapt it while writing tests, or look at it.

For test quality, the skill sets short rules (a test is minimal, clear, and shows intent; "and" in a test name means split it) and points to a supporting file, `writing-good-tests.md`, for writing or changing any test. That file asks the agent to name the production change that would make a test fail before writing it, to derive expected values by hand and never from the code under test, to assert on real behavior and never on mock behavior, to keep test-only code in test utilities, and to run a mutation check before finishing: mentally mutate the production code and confirm a test fails for each realistic mutation.

Before it calls work complete, the agent runs the skill's verification checklist. Every new function has a test, each test was watched failing for the expected reason, minimal code made each pass, all tests pass with pristine output, tests use real code, and edge cases and errors are covered. If a box cannot be checked, the skill says the agent skipped TDD and should start over.

For a bug, the skill says to write a failing test that reproduces it and follow the same cycle, and never to fix a bug without a test.

## Why it exists

The skill's core principle is that a test you never watched fail does not prove it tests the right thing. A test written after the code passes immediately, so it cannot show that it would catch the bug, and it tends to verify the cases the agent already remembered. The skill's rationalizations table answers the usual excuses for skipping the cycle ("I'll test after", "already manually tested", "deleting hours of work is wasteful"), and its red-flags list tells the agent to stop and start over when it catches itself thinking them. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- Each test has been seen failing, so it is known to be able to catch the behavior it names.
- The agent writes only the code a test requires, which keeps additions small.
- A bug fix leaves a regression test behind.
- The mutation check and the mirror-assertion warning in `writing-good-tests.md` catch tests that cannot fail.
- The verification checklist gives a concrete bar for "done".

## Cons and costs

- Every behavior takes at least two test runs (one red, one green), which is slower per change than writing code and testing afterward.
- The delete-and-restart rule discards code that already works if it was written before its test.
- The rules are strict: the skill treats "just this once" as rationalization, so you will see the agent push back on shortcuts you may have wanted.
- The skill's code samples are TypeScript and shell, so for another language the agent has to translate the pattern.

## Skipping or overriding

The skill lists throwaway prototypes, generated code, and configuration files as exceptions, and says to ask you about them. Its final rule is "no exceptions without your human partner's permission". So you can tell the agent a change is a prototype, or that you accept untested code for a given change, and the skill treats your say-so as the permission it asks for. If you give no such permission, the agent starts over whenever it catches code before its test.

## Works with

- {doc}`subagent-driven-development` tells its implementer subagents to follow this skill for the task's tests.
- {doc}`systematic-debugging` sends the agent here in its implementation phase, to write the failing test that reproduces the bug.
- {doc}`writing-skills` names this skill as required background, because it adapts the red-green-refactor cycle to documentation.

## Under the hood

{source}`skills/test-driven-development/SKILL.md` holds the iron law, the cycle, the rationalizations and red-flags tables, and the verification checklist. {source}`skills/test-driven-development/writing-good-tests.md` is the reference the agent loads when it writes or changes tests: naming the break a test catches, exercising the real thing, the mutation check, and warning signs. There are no scripts.
