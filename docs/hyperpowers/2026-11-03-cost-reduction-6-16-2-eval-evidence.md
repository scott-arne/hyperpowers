# Re-read After Compaction: Evaluation Evidence

**Change under test:** one added paragraph in each of `skills/subagent-driven-development/SKILL.md` and `skills/brainstorming/SKILL.md` telling the agent to re-read the full skill with the Read tool after an automatic context compaction. Claude Code re-attaches an invoked skill after a compaction, but caps each skill at 20,000 characters and cuts the rest, so a long skill comes back truncated. The paragraph exists so the agent restores the missing text instead of working from the cut version.

**Method:** paired live Claude Code sessions driven by the quorum harness, ten trials per arm per scenario. The control arm loads v6.16.1 and the treatment arm loads the release branch; nothing else differs. A Gauntlet agent plays the human partner and a grader judges the outcome checks. The spec is `docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md` (Testing section, as amended 2026-11-04).

**Environment:** Claude Code 2.1.317. Coding agent and grader both `claude-opus-5-5`. Pins: harness `829fe83b0` (evals repo), control `f1fd935` (v6.16.1), treatment `1478a4a` (release branch, the commit with the two paragraphs). Run artifacts, tallies and logs: `evals/evidence/2026-11-03-cost-reduction-6-16-2/` in hyperpowers-evals.

**Date:** 2026-11-04.

## Scenarios

1. **sdd-compaction-reread** (new). The agent runs the subagent-driven-development skill over a four-task plan of about 27,000 characters. A trial is valid when an automatic compaction lands after task 1's review returns and before the final review is dispatched. Outcome checks cover the work itself (all tasks implemented, reviewed, and finished). The mechanism check asks whether the agent Read the full skill file after the measured compaction and before its next dispatch.
2. **brainstorming-bounded-companion-after-compaction** (existing, gained a mechanism check). The same compaction scenario as before, plus a check that the agent Read the brainstorming skill after the compaction. Its existing outcome checks are unchanged.

Smoke findings that shaped the SDD scenario (`smoke.md` in the evidence directory). At the 100000-token window each run compacts three to five times, and the first compaction lands before any subagent is dispatched, because the fixed pre-dispatch reads (system prompt, the skill, review and gate documents, preflight reading) use nearly all of the headroom whatever the plan size. Shrinking the plan from 64 KB to 27 KB moved that first compaction by almost nothing. A later compaction does land inside the spec's window. In every compaction of every smoke attempt, the re-attached `subagent-driven-development` skill was exactly 20,000 characters and ended with the note `[... skill content truncated for compaction; use Read on the skill path if you need the full text]`, so the truncation the change targets is real.

## RED: control arm (v6.16.1)

| Scenario | Runs | Valid n | Voids | Outcome pass | Mechanism |
| --- | --- | --- | --- | --- | --- |
| sdd-compaction-reread | 10 | 10 | none | 10/10 | 0/10 |
| brainstorming-bounded-companion-after-compaction | 11 | 10 | 1 grader | 10/10 | 0/10 |

The brainstorming control had one grader void (p8). It was replaced by relaunch r1 under the replacement cap, with a row in `sentinel-reruns.tsv`. Without the paragraph, no control run in either scenario re-read the skill after the compaction, and the outcome checks passed regardless, which is why the pass bar needs the mechanism check and not only the outcome.

One control observation worth keeping: the voided p8 run was graded `investigate` by the grader for the phrase "autocompact is thrashing". Claude Code printed that warning in the session and the grader read it as a defect in the agent's behavior. It was an instrument void, not a skill result.

## GREEN: treatment arm (release branch)

| Scenario | Runs | Valid n | Voids | Outcome pass | Mechanism |
| --- | --- | --- | --- | --- | --- |
| sdd-compaction-reread | 10 | 10 | none | 10/10 | 10/10 |
| brainstorming-bounded-companion-after-compaction | 10 | 10 | none | 10/10 | 10/10 |

No replacements were needed. The agent re-read the full skill in 10 of 10 measured compactions for both skills, and outcomes stayed at 10 of 10. All four bars read PASS in `tally.txt`:

- SDD outcome: treatment 10 of 10 valid, at least 8 and at least the control's 10 of 10.
- SDD mechanism: 10 of 10, at least 8.
- Brainstorming outcome: treatment rate equals the control's 10 of 10.
- Brainstorming mechanism: 10 of 10, at least 8.

Who ran what. The RED wave was launched by the subagent that ran Task 8. The GREEN wave was launched by the controller after the human partner approved it, because the permission classifier had denied the launch to the Task 10 subagent. The command was identical to the RED wave's (`launch-all.sh` with the wave's manifest and 14 parallel slots). The evidence staging for the GREEN runs was likewise done by the controller after approval, after the classifier denied it to the subagent. Evals commits: `3c6b76ed3` (RED runs and tally), `28d0fcad1` (treatment pin), `8920e7c2e` (GREEN runs and tally).

## REFACTOR

The skill text did not change after the first measurement; `1478a4a` is the only treatment pin. The tally rules did, twice, during the control wave. Both changes concern how the instrument reads a run, and both were made before any treatment run existed.

1. **Measure at the first compaction inside the spec's window** (evals `0f5841384`). The first plan-level rule voided every smoke run because the first compaction always precedes the first dispatch. The spec's rule is that a compaction lands after task 1's review returns and before the final review is dispatched, so the tally now measures the first automatic compaction inside that window and ignores earlier ones.
2. **Credit a review in flight at the compaction** (evals `b571e39d0`, `503623ac5`, `a3565942b`; spec amendment `c275a8f` in this repository). The first RED tally counted three correct runs as outcome failures because a review dispatched before the compaction returned after it. The human partner decided on 2026-11-04 that such a review counts for the SDD outcome when it returns before the next task's first implementer dispatch. The final commit makes that dispatch the bound wherever the review falls. The RED control was re-tallied under the corrected rule (`4fb34bd04`).

## Not measured

- **writing-skills.** The change to that skill is deferred and has no measurement here.
- **Field cost savings.** The campaign measures behavior after a compaction, not spend. Savings from the settings change are measured in the field two weeks after it takes effect and will be reported separately.
- Only the 100000-token window, one plan size and one model pair were tested.
