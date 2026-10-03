# Communication Skill: Evaluation Evidence

**Skill under test:** `communication`, a technique skill for prose a person will read: reports and replies to the human partner, PR descriptions, commit messages, documents, and text someone asks to have made less AI-sounding. `skills/communication/SKILL.md` carries the recipe, the jargon substitution table, the contrast rule, and the check table; `skills/communication/patterns.md` carries the full catalogue with before-and-after pairs, condensed from the humanizer skill (MIT) and Wikipedia's "Signs of AI writing".

**Request:** the human partner asked for a skill that removes AI-writing patterns and improves clarity, with three rules of their own: no jargon metaphors (blast radius, footgun, yak shaving, spine, seams, gate, belt-and-suspenders), no overuse of "load-bearing", and no negative parallelism ("It's not an X, it's a Y").

**Method:** the micro-test form from `skills/writing-skills/SKILL.md`. Fresh single-shot subagents (general-purpose, the session's default subagent model, dispatched through the Agent tool) each wrote one message to a file with the Write tool. The control arm got the task only. The treatment arm got the full SKILL.md text inline as a loaded skill, with the path to `patterns.md`. Three scenarios, five reps per arm per scenario, 30 runs. `score.py` counted candidate matches per tell; every match was then read by hand, and the counts below are the hand-read counts. Run artifacts: `evals/evidence/2026-10-03-communication-skill/` in hyperpowers-evals.

**Date:** 2026-10-03.

## Scenarios

Each prompt placed the agent in a terminal session with its human partner and asked for the message it would send. The notes it was given were written in plain words so that any metaphor in the output was the agent's own.

1. **s1-report.** A two-hour investigation of a nightly job that fails one night in four. The notes contain a module 23 others import (tempts "blast radius", "spine"), a retry default that swallows errors ("footgun"), a 40-minute test-harness detour ("yak shaving"), two identical schema checks ("belt-and-suspenders"), and a CI step that blocks deploy ("gate").
2. **s2-reply.** The partner asks "do we wrap the flaky call in a retry and ship Friday, or fix the ordering thing properly? your call, but tell me why". The notes say the call works correctly and reads an uncommitted row (tempts "it's not flaky, it's a race").
3. **s3-design-review.** The partner pastes a design note for splitting a module into plugins and asks "poke holes in this". The note has a stateless assumption checked on three of nine formats (tempts "load-bearing"), import-time registration, double validation, ignored unknown option keys, and a nine-format rollout behind a flag.

## RED: control arm (no skill)

Counts are runs with at least one instance, out of five per scenario.

| Tell | s1 | s2 | s3 | Total |
|---|---|---|---|---|
| Figurative jargon from the partner's list | 3 ("gate" x3, "blast radius" x1) | 0 | 2 ("gate" x2) | 5/15 |
| "load-bearing" | 0 | 0 | 2 | 2/15 |
| "Not X but Y" in any form | 0 | 4 | 5 | 9/15 |
| Bold label opening a paragraph or list item | 0 | 0 | 5 | 5/15 |
| One-line closer that restates | 0 | 3 | 3 | 6/15 |
| Narrating the message's own layout | 2 | 0 | 0 | 2/15 |
| "surface" as a verb | 2 | 0 | 1 | 3/15 |
| Em or en dash, or markdown heading | 0 | 0 | 0 | 0/15 |
| footgun, yak shaving, spine, seams, belt-and-suspenders | 0 | 0 | 0 | 0/15 |
| Words | 351 to 445 | 263 to 343 | 603 to 926 | |

Verbatim examples:

- s1 r2, r3, r4 each renamed the step the notes described as "a step that blocks deploy": "The CI schema-snapshot gate passed on every failing night."
- s1 r3: "If you would rather take (b) to limit blast radius, I can have that up faster"
- s1 r3: "Root cause found and reproduced; summary first, details after."
- s2 r3: "The question isn't retry vs. proper fix for Friday; it's whether billing needs to change this week at all, and it doesn't." and "That's the fact that decides it."
- s2 r4: "That asymmetry decides it."
- s2 r5: "A few more days of that is fine. What isn't fine is a compressed soak"
- s3 r3: "**1. The stateless assumption is load-bearing and one-third verified.**" (one of eight numbered bold headings in that reply)
- s3 r5: "is the load-bearing assumption for the whole migration" and "the kind of thing that bites a year from now"
- s3 r4: "'Two weeks' is a calendar, not an exit criterion."
- s3 r2: "that split is a behavior change, not a move."

The control arm never used em dashes, markdown headings, or the chatbot wrappers from the humanizer catalogue. The subagent harness already carries instructions against those, so this test could not measure them. The decision questions that ended three s1 reports ("Want me to open the PR for (a) and start the importer check?") name a real decision and were not counted as chatbot residue.

## GREEN: treatment arm (skill loaded)

| Tell | s1 | s2 | s3 | Total |
|---|---|---|---|---|
| Figurative jargon from the partner's list | 0 | 0 | 0 | 0/15 |
| "load-bearing" | 0 | 0 | 0 | 0/15 |
| "Not X but Y" in any form | 0 | 0 | 0 | 0/15 |
| Bold label | 0 | 0 | 0 | 0/15 |
| One-line closer that restates | 0 | 0 | 0 | 0/15 |
| Narrating the message's own layout | 0 | 0 | 0 | 0/15 |
| "surface" as a verb | 0 | 0 | 1 | 1/15 |
| Words | 268 to 341 | 183 to 227 | 540 to 721 | |

What the treatment wrote where the control used a tell:

- Every s1 report named the CI step: "the CI step that blocks deploy on a schema snapshot diff" (r1), "the CI step that blocks deploy on a schema diff" (r4).
- s3 on the stateless assumption: "Six of the nine formats are unchecked for state, and the 'move without changing' claim rests on all nine being stateless." (r1); "Item 4 is only safe if none of the nine modules has module-level state. Three are checked, six are not." (r2)
- s2 replies opened with the decision in every rep ("Fix the ordering properly, and keep it out of Friday's release.") and ended on a fact or a stated next step instead of a closer.
- All five s1 reports ended with a question that names the one open decision: whether to spend the hour on the importer check before or after opening the PR.

The five treatment reps per scenario converge on one shape (answer first, plain paragraphs, no labels), which is the low-variance signal the writing-skills micro-test guidance asks for.

## REFACTOR

One residual: s3 r4 wrote "where errors surface after the split". The skill names "surface" as a verb in its metaphor paragraph, in prose rather than in the table. One instance in fifteen did not justify a wording change that would need its own re-measurement; it is recorded here as the known residual.

No rationalizations appeared, because the failure is one of output shape rather than rule-skipping, which is why the skill uses the recipe-and-table form rather than a prohibition list and a red-flags table.

## Not measured

- **Triggering inside a process skill** is measured below. **Triggering on a standalone reply** (a question answered outside any process skill) is measured below and did not happen in either bootstrap placement tried.
- **`patterns.md`.** No treatment agent read the companion file (two tool calls per run: the Write and the hand-back). The catalogue is unmeasured as a reference; SKILL.md alone produced the result above.
- **Dashes, headings, chatbot wrappers.** Zero in both arms under this harness; the rules stay in the skill at the partner's request and because other harnesses lack the suppression.
- **footgun, yak shaving, spine, seams, belt-and-suspenders.** Never produced by the control arm in these scenarios, so the substitution rows for them are unmeasured. They stay because the partner has seen them in practice.
- **Editing mode.** No scenario asked the agent to rewrite pasted text.
- **Live sessions.** This was a single-shot micro-test, not a quorum campaign. A long session after compaction may behave differently (see `claude-code-compaction-mechanics` in the project memory).

## Triggering (second measurement, 2026-10-03)

**Request:** make the skill fire at the points where hyperpowers talks to the human partner: summaries, brainstorming conversations, presenting a plan, and the like.

**Change under test:** one `**REQUIRED SUB-SKILL:** Use hyperpowers:communication ...` line at the human-facing point of each process skill (brainstorming, writing-plans, subagent-driven-development, executing-plans, finishing-a-development-branch, requesting-code-review, receiving-code-review, systematic-debugging, dispatching-parallel-agents, profiling-performance, optimizing-performance), the same bullet form as the existing cross-references, plus one routing bullet in `using-hyperpowers` Skill Priority ("Writing for your human partner ... → hyperpowers:communication before you write it") mirrored in `scripts/claude-skill-root.md`. The survey of output points that chose the anchors is in the evals evidence directory.

**Method:** live headless Claude Code sessions (`claude -p`, CC 2.1.288, model claude-opus-5-5, `--dangerously-skip-permissions`, `--max-budget-usd 8`) with the worktree loaded through `--plugin-dir` and an empty `CLAUDE_CONFIG_DIR`, so no installed plugin and no host CLAUDE.md was present. Each session ran against a fresh copy of a small fixture (a plain-text notes CLI with a sort-key bug, two tests, and a spec for a tags feature). The control arm ran the worktree before the lines were added; the treatment arm ran it after. Five sessions per scenario per arm. A session counts as a hit when its transcript carries a `Skill` tool call for `hyperpowers:communication`. Launcher, prompts, fixture, transcripts, and final messages: `evals/evidence/2026-10-03-communication-skill/trigger/`.

| Scenario | Prompt | Control | Treatment |
|---|---|---|---|
| brainstorm, two turns | "I want to add tags to notes ... Let's work out the design together before any code." then the partner's answers and "walk me through the design" | 0/5 | 5/5 (turn 1, before the design presentation in turn 2) |
| plan | "Write the implementation plan for docs/spec-tags.md." | 0/5 | 5/5 (before the plan file was written in 4 of 5) |
| debug | "The test suite has one failing test. Find the root cause and report back to me before changing anything." | 0/5 | 4/5 (the last call before the report) |
| trivial | "What does the add command do?" (answers ran 112 to 195 words) | 0/5 | 0/5 |
| oneliner | "Which branch is this repo on?" (answers ran 5 to 35 words) | 0/5 | 0/5 |

Every control and treatment session invoked the expected process skill first (brainstorming, writing-plans, systematic-debugging); the new line never displaced it.

Effect on the prose where the skill was invoked, counted as bold spans in the final human-facing message:

- debug reports: control 3, 3, 4, 2, 5; treatment 0, 0, 4, 0, 0 (the 4 is the session that did not invoke the skill).
- brainstorm turn-2 design presentations: control 5, 6, 5, 5, 5; treatment 4, 0, 4, 5, 0. The skill is invoked a turn before the presentation, and the brainstorming instruction to present "in sections" still pulls toward bold section labels. Two of five came out clean against none in control.
- trivial answers: unchanged, since the skill was never invoked.

**Bootstrap placement.** A second variant moved the routing line into `using-hyperpowers` "The Rule" as its own bold sentence ("Before you write prose your human partner will read ... invoke hyperpowers:communication"). Measured on trivial (0/5), oneliner (0/5), and brainstorm (3/3 invoked brainstorming then communication): identical to the bullet form. The bullet form was kept because it matches the section's existing style and costs the bootstrap less. In print mode, a standalone question does not make the session invoke any skill, so a reply outside a process skill is not covered by either placement. A hook that injects a reminder at prompt submission would be the next lever if that coverage is wanted; it is not part of this change.

**Fixture notes.** The sort-key bug's test data happens to pass, so the debug sessions reported "could not reproduce" and then the real bug; the report to the human still happened, which is what the scenario measures. The spec file was present in every scenario, so the brainstorm sessions read it and classified the work as bounded; the design presentation still happened in turn 2. The plan sessions ran the real Codex review gate and ended on the worktree-consent question from using-git-worktrees.

**Residuals.** One debug session in five did not invoke the skill. The brainstorming presentation effect is partial; tightening it would mean changing how brainstorming describes the presentation, which is a brainstorming change with its own measurement and is left for a follow-up. SDD, executing-plans, finishing-a-development-branch, requesting-code-review, receiving-code-review, dispatching-parallel-agents, and the performance skills carry the same line form but were not exercised by a scenario.
