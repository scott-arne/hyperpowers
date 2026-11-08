---
sources: skills/writing-skills docs/testing.md CLAUDE.md
source-digest: effad544b7d9
---
# How skills are tested

This page covers the two kinds of test this project uses and the method for testing a skill's wording and behavior. The offline plugin tests check the code around the skills. Behavior tests check what an agent does in a real session. A skill is behavior-shaping text, so a change to one needs evidence from the second kind. The steps for writing a skill are on the {doc}`../skills/writing-skills` page, and {doc}`customizing` covers changing a skill in your own fork.

## Two kinds of tests in two repositories

{source}`docs/testing.md` separates them:

- `tests/` in this repository holds tests of the plugin's non-LLM code: the hooks, the Codex review gate scripts, the subagent-driven-development helpers, the decision compiler, and each harness integration. They are bash, node, and python scripts and run offline.
- Skill-behavior evals live in a separate repository, [hyperpowers-evals](https://github.com/scott-arne/hyperpowers-evals/). It is a separate clone and the main repository gitignores it. Its harness, quorum, drives real Claude Code and Codex CLI sessions and judges skill compliance with an LLM verifier. A scenario is a directory with a `setup.sh`, a `checks.sh` with `pre()` and `post()` functions, and a `story.md`. Scenario and harness work is committed in that repository.

Live eval runs consume API credit and run agents in dangerous mode, so the testing guide limits them to trusted maintainers and keeps them out of public CI. They take minutes to tens of minutes each.

## The offline tests

`bash tests/run-offline.sh` runs the documented offline set, one script per `bash` invocation. The table in `docs/testing.md` lists each directory under `tests/` and what it covers. The repository has no CI, so you run the suites that cover what you changed. A few suites under `tests/claude-code/` and `tests/explicit-skill-requests/` spawn the real `claude` CLI and are outside that set. Skill-specific structural checks sit in `tests/writing-skills/` and `tests/systematic-debugging/`.

## Pressure scenarios

The `writing-skills` skill treats a skill as documentation that is tested the way code is, in a red, green, refactor cycle. Its supporting file `testing-skills-with-subagents.md` gives the format of the test. A pressure scenario is a realistic task given to a subagent that tempts it to break the rule under test.

- Time, sunk cost, authority, economic, exhaustion, social, and pragmatic pressures are the types the file lists. For a skill that enforces discipline, the best scenarios combine three or more.
- A good scenario offers concrete options (A, B, or C), states real constraints, uses real file paths, and asks "What do you do?" It leaves no easy way out through "I would ask my human partner".
- The test setup tells the agent the scenario is real work.

Which test to use depends on the skill type. A discipline skill gets pressure scenarios and academic questions about the rules. A technique skill gets application, variation, and missing-information scenarios. A pattern skill gets recognition, application, and counter-example scenarios. A reference skill gets retrieval, application, and gap scenarios. For reference skills the two files differ. `SKILL.md` lists "It's just a reference" among the excuses for skipping tests and answers "Test retrieval", and its iron law has no exception for documentation. The "When to Use" list in `testing-skills-with-subagents.md` names pure reference skills (API docs, syntax guides) among the skills not to test with its pressure-scenario method.

## Baseline versus treatment

Each change starts from a baseline. The agent runs the scenario without the skill and records what the subagent chose and the rationalizations it used, word for word. It then writes the minimal skill that answers those failures and runs the same scenarios with the skill present. New rationalizations found along the way get explicit counters, a place in the rationalization table, and a red-flags entry. The agent re-tests until the skill holds.

When a run with the skill still fails, the testing file describes meta-testing: ask the agent how the skill could have been written to make the right answer unmistakable. The three outcomes it names are that the skill was clear and the agent ignored it (add a stronger foundational principle), that the skill should have said something else (add the agent's suggestion), and that the agent missed a section (make it more prominent).

## Micro-tests for wording

Full scenarios are slow, so `writing-skills` has a cheaper step for behavior-shaping wording. Its five rules:

1. One fresh-context sample per call, with the realistic context for the guidance as the system prompt and a task that tempts the failure as the user message.
2. A control without the guidance. If the control does not show the failure, there is nothing to fix.
3. Five or more repetitions per variant.
4. Every flagged match is read by hand, because template echoes and quoted counter-examples look like hits.
5. Variance counts as a result. If five repetitions give five different interpretations, the wording does not bind yet.

Micro-tests verify wording and do not replace pressure scenarios for discipline skills.

## Why a skill change needs evidence

`CLAUDE.md` states this repository's rule for changes to it. Skills are treated as code that shapes agent behavior, so a change goes through `writing-skills`, adversarial pressure testing across multiple sessions, and a before-and-after comparison whose evidence is kept with the change. Carefully tuned content such as red-flags tables and rationalization lists is not reworded without evidence that the change helps. `docs/testing.md` says the evals are the required evidence for a change to behavior-shaping skill prose.

When a plan preserves run artifacts that an evidence note will cite, `CLAUDE.md` has them copied into an evidence directory in the evals repository and cited by that path. The scratch workspace of a subagent-driven run is deleted when the run finishes, so a citation into it would stop resolving. The dated evidence notes in `docs/hyperpowers/` are committed alongside the work they describe.
