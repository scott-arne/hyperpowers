# Brainstorming Trigger Calibration — Eval Evidence

**Spec:** `docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md`
**Plan:** `docs/hyperpowers/plans/2026-09-16-brainstorming-trigger-calibration.md`
**Measured:** 2026-09-17
**Control root:** `2e83fd8`
**Treatment root:** `8fbbb42` (description commit `12b5b78`; the treatment worktree carried plan-document commits on top of it, and the skills tree is otherwise identical to control)
**Harness:** evals `4fd69ed` (the manifest's harness pin)
**Evidence:** evals `evidence/2026-09-16-brainstorming-trigger-calibration/` at `acdad9b`

## What was measured

Two arms that differ only in line 3 of `skills/brainstorming/SKILL.md`: control ran the upstream description from `external-workflow-adoption` at `2e83fd8`, treatment ran the reworded description from `brainstorming-trigger` at `8fbbb42` (description commit `12b5b78`), with every other skill byte-identical, as the analysis's listing hash confirmed. Each arm ran 75 live sessions of `claude-opus-5` on Claude Code 2.1.261 across nine scenarios, `cost-checkbox-over-trigger` (20), `brainstorming-resists-jump-to-implementation` (10), `cost-session-timeout-boundary` (10), `cost-remove-export-boundary` (10), and `brainstorming-router-escalates-b1..b5` (5 each), judged by the Gauntlet-Agent, with indeterminate trials re-run once. Both arms set `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000` so the description was rendered in the skill listing; whether a user sees it in production depends on Claude Code's listing budget (context tokens x 3 bytes per token x 1%, bundled skills first, plugin skills by usage), which is outside this fork's control, while the description is in it.

## Results

```
scenario                                           arm          n fail pass ind  fail 95% CI    first actions
brainstorming-resists-jump-to-implementation       control     10    0   10   0    0% [0-28]    {'Skill(hyperpowers:brainstorming)': 10}
brainstorming-resists-jump-to-implementation       treatment   10    0   10   0    0% [0-28]    {'Skill(hyperpowers:brainstorming)': 10}
brainstorming-router-escalates-b1-userid-param     control      5    1    4   0   20% [4-62]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b1-userid-param     treatment    5    2    3   0   40% [12-77]   {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b2-config-module    control      5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b2-config-module    treatment    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b3-logging          control      5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b3-logging          treatment    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b4-reusable-validation control      5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b4-reusable-validation treatment    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b5-prefs-storage    control      5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b5-prefs-storage    treatment    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
cost-checkbox-over-trigger                         control     20   18    2   0   90% [70-97]   {'Skill(hyperpowers:brainstorming)': 18, 'explore(Bash)': 2}
cost-checkbox-over-trigger                         treatment   20    7   13   0   35% [18-57]   {'explore(Bash)': 13, 'Skill(hyperpowers:brainstorming)': 7}
cost-remove-export-boundary                        control     10   10    0   0  100% [72-100]  {'explore(Bash)': 10}
cost-remove-export-boundary                        treatment   10   10    0   0  100% [72-100]  {'explore(Bash)': 10}
cost-session-timeout-boundary                      control     10   10    0   0  100% [72-100]  {'explore(Bash)': 10}
cost-session-timeout-boundary                      treatment   10   10    0   0  100% [72-100]  {'explore(Bash)': 10}

design checks passed: every manifest row logged once with its pins, one payload hash, one listing outside the brainstorming line, expected brainstorming line per arm, expected counts
```

Model `claude-opus-5`, Claude Code 2.1.261, `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000` in both arms.

## Reruns

Three manifest trials were indeterminate, each with
`Gauntlet-Agent did not complete (status: investigate)`: the grader reached
its own budget before the session reached a gradable end, while the coding
agent's transcript exists in every case. Each was re-run once, as the design
allows; no trial was re-run twice.

| original | arm / scenario | replacement | replacement verdict |
|---|---|---|---|
| `...20260917T011540Z-fc25` | control / resists-jump | `...20260917T032211Z-5887` | pass |
| `...20260917T003956Z-7589` | control / resists-jump | `...20260917T032211Z-fa85` | pass |
| `...20260917T023041Z-5318` | treatment / router b1 | `...20260917T032211Z-065a` | pass |

Full names are in `reruns.tsv`; the originals are archived beside the
replacements under `runs-<scenario>/<arm>/` and their contexts passed the
same payload, listing, brainstorming-line, and model checks.

## Acceptance

The spec's criteria, each with numbers:

1. `cost-checkbox-over-trigger` treatment fail rate at most 20%: **35%** (7 of 20; control 90%, 18 of 20; Wilson 95% CI 18-57). Not met.
2. No false-negative regression:
   - `brainstorming-resists-jump-to-implementation` twin: treatment 10 of 10 pass, control 10 of 10 pass, zero treatment failures. Met.
   - `cost-session-timeout-boundary`: treatment 0 of 10 pass, control 0 of 10 pass. Met as an equality at the floor.
   - Router briefs: `brainstorming-router-escalates-b1-userid-param` treatment 3 of 5 pass, control 4 of 5 pass. Not met. `b2-config-module`, `b3-logging`, `b4-reusable-validation`, `b5-prefs-storage`: treatment 5 of 5 pass, control 5 of 5 pass each. Met.
3. `cost-remove-export-boundary` treatment fail rate no higher than control: 100% fail both arms (10 of 10 each). Met at the floor.
4. Context checks (one payload hash across all runs, one listing outside the brainstorming line, each arm's brainstorming line as rendered from its root, one model): confirmed by the design checks.

## Decision

The description does not ship under the spec's criteria, measured against the human partner's stated preference, "I'd rather have false positives than negatives, but it is a rigorous process, so we also don't want to trigger it when unnecessary" (the plan's shorthand: false positives over false negatives, but no trigger where none is needed).

## Limits

- One judge per trial (the Gauntlet-Agent), one coding model (`claude-opus-5`), one Claude Code version (2.1.261), one day.
- The budget override (`SLASH_COMMAND_TOOL_CHAR_BUDGET=20000`) renders all fifteen hyperpowers descriptions, not only brainstorming's. The production listing renders far fewer.
- Router briefs have five sessions per arm: one session moves a rate by 20 points, and b1's failure rates, 2 of 5 in treatment against 1 of 5 in control, have Wilson 95% intervals of 12-77 against 4-62.
- Both boundary scenarios (`cost-session-timeout-boundary`, `cost-remove-export-boundary`) sit at 0% pass in both arms, so they can show neither a regression nor an improvement from a description change. The behaviour they probe is not decided by the description under this model and version.
- The verdict follows the spec's bar, not the direction of the effect: the change cut false positives from 90% to 35% with no false-negative regression on the twin or on four of the five router briefs, and b1's one-session gap is within the noise of five sessions; whether that trade ships outside the bar is the human partner's decision, and the spec says the next candidate wording is a new measured change.
