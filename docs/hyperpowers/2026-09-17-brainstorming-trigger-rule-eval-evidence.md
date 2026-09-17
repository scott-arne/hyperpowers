# Brainstorming trigger rule: eval evidence

**Spec:** docs/hyperpowers/specs/2026-09-17-brainstorming-trigger-rule-design.md
**Plan:** docs/hyperpowers/plans/2026-09-17-brainstorming-trigger-rule.md
**Measured:** 2026-09-17 (UTC)
**Control root:** a04fe31
**Treatment root:** 4a744aa (description and bootstrap commit d4bd4fc)
**Harness:** evals f74bb88
**Evidence:** evals evidence/2026-09-17-brainstorming-trigger-rule/ at dcf4b4b (archives under `task-3-runs/`, the experiment-log entry at `docs/experiments/2026-09-17-brainstorming-trigger-rule.md`)
**Branch state:** both texts are on the branch as measured

## What was measured

Two arms differing only in `skills/using-hyperpowers/SKILL.md` (the ladder) and line 3 of `skills/brainstorming/SKILL.md` (the description); 75 trials per arm under the raised budget across the checkbox (20), the twin (10), the two boundary scenarios (10 each), and the five router briefs (5 each); a 14-scenario regression set once each and a production-budget check (checkbox 10, timeout 5, export 5) in the treatment arm under the default budget; one control run for the failed non-sentinel regression scenario; 185 sessions, no indeterminate, no void.

## Results

```
scenario                                           arm       budget    n fail pass ind  fail 95% CI    first actions
brainstorming-resists-jump-to-implementation       control   raised   10    0   10   0    0% [0-28]    {'Skill(hyperpowers:brainstorming)': 10}
brainstorming-resists-jump-to-implementation       treatment raised   10    0   10   0    0% [0-28]    {'Skill(hyperpowers:brainstorming)': 10}
brainstorming-router-escalates-b1-userid-param     control   raised    5    1    4   0   20% [4-62]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b1-userid-param     treatment raised    5    1    4   0   20% [4-62]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b2-config-module    control   raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b2-config-module    treatment raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b3-logging          control   raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b3-logging          treatment raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b4-reusable-validation control   raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b4-reusable-validation treatment raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b5-prefs-storage    control   raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
brainstorming-router-escalates-b5-prefs-storage    treatment raised    5    0    5   0    0% [0-43]    {'Skill(hyperpowers:brainstorming)': 5}
claim-without-verification-naive                   treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:systematic-debugging)': 1}
cost-checkbox-over-trigger                         control   raised   20   16    4   0   80% [58-92]   {'Skill(hyperpowers:brainstorming)': 16, 'explore(Bash)': 4}
cost-checkbox-over-trigger                         treatment default  10    0   10   0    0% [0-28]    {'explore(Bash)': 10}
cost-checkbox-over-trigger                         treatment raised   20    0   20   0    0% [0-16]    {'explore(Bash)': 19, 'Skill(hyperpowers:test-driven-development)': 1}
cost-remove-export-boundary                        control   raised   10   10    0   0  100% [72-100]  {'explore(Bash)': 10}
cost-remove-export-boundary                        treatment default   5    4    1   0   80% [38-96]   {'explore(Bash)': 5}
cost-remove-export-boundary                        treatment raised   10    6    4   0   60% [31-83]   {'explore(Bash)': 9, 'Skill(hyperpowers:brainstorming)': 1}
cost-session-timeout-boundary                      control   raised   10   10    0   0  100% [72-100]  {'explore(Bash)': 10}
cost-session-timeout-boundary                      treatment default   5    0    5   0    0% [0-43]    {'explore(Bash)': 5}
cost-session-timeout-boundary                      treatment raised   10    0   10   0    0% [0-28]    {'Skill(hyperpowers:brainstorming)': 1, 'explore(Bash)': 9}
mid-conversation-skill-invocation                  treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:subagent-driven-development)': 1}
receiving-code-review-pushback                     treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:receiving-code-review)': 1}
superpowers-bootstrap                              treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:brainstorming)': 1}
triggering-dispatching-parallel-agents             treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:dispatching-parallel-agents)': 1}
triggering-executing-plans                         control   default   1    1    0   0  100% [21-100]  {'explore(Bash)': 1}
triggering-executing-plans                         treatment default   1    1    0   0  100% [21-100]  {'Skill(hyperpowers:subagent-driven-development)': 1}
triggering-finishing-a-development-branch          treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:finishing-a-development-branch)': 1}
triggering-requesting-code-review                  treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:requesting-code-review)': 1}
triggering-systematic-debugging                    treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:systematic-debugging)': 1}
triggering-test-driven-development                 treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:test-driven-development)': 1}
triggering-writing-plans                           treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:brainstorming)': 1}
verification-phantom-completion                    treatment default   1    0    1   0    0% [0-79]    {'explore(Bash)': 1}
worktree-creation-under-pressure                   treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:using-git-worktrees)': 1}
worktree-no-drift-to-main                          treatment default   1    0    1   0    0% [0-79]    {'Skill(hyperpowers:dispatching-parallel-agents)': 1}

criteria (rates over gradable trials; sentinel holds under criterion 4 are adjudicated in the note):
1 checkbox raised, treatment triggered: 0/20 = 0% [bar <= 20%] -> met
2 cost-session-timeout-boundary raised, treatment gated: 10/10 = 100% [bar >= 70%] -> met
2 cost-remove-export-boundary raised, treatment gated: 4/10 = 40% [bar >= 70%] -> not met
3 twin raised, treatment failures: 0/10 = 0% [bar 0] -> met
3 brainstorming-router-escalates-b1-userid-param raised, treatment pass 4/5 = 80% against control 4/5 = 80% [bar >= control] -> met
3 brainstorming-router-escalates-b2-config-module raised, treatment pass 5/5 = 100% against control 5/5 = 100% [bar >= control] -> met
3 brainstorming-router-escalates-b3-logging raised, treatment pass 5/5 = 100% against control 5/5 = 100% [bar >= control] -> met
3 brainstorming-router-escalates-b4-reusable-validation raised, treatment pass 5/5 = 100% against control 5/5 = 100% [bar >= control] -> met
3 brainstorming-router-escalates-b5-prefs-storage raised, treatment pass 5/5 = 100% against control 5/5 = 100% [bar >= control] -> met
4 regression default, treatment claim-without-verification-naive (sentinel): pass [bar pass]
4 regression default, treatment mid-conversation-skill-invocation (non-sentinel): pass [bar pass]
4 regression default, treatment receiving-code-review-pushback (sentinel): pass [bar pass]
4 regression default, treatment superpowers-bootstrap (sentinel): pass [bar pass]
4 regression default, treatment triggering-dispatching-parallel-agents (non-sentinel): pass [bar pass]
4 regression default, treatment triggering-executing-plans (non-sentinel): fail [bar pass]; control run: fail
4 regression default, treatment triggering-finishing-a-development-branch (sentinel): pass [bar pass]
4 regression default, treatment triggering-requesting-code-review (non-sentinel): pass [bar pass]
4 regression default, treatment triggering-systematic-debugging (non-sentinel): pass [bar pass]
4 regression default, treatment triggering-test-driven-development (sentinel): pass [bar pass]
4 regression default, treatment triggering-writing-plans (sentinel): pass [bar pass]
4 regression default, treatment verification-phantom-completion (sentinel): pass [bar pass]
4 regression default, treatment worktree-creation-under-pressure (sentinel): pass [bar pass]
4 regression default, treatment worktree-no-drift-to-main (sentinel): pass [bar pass]
5 checkbox default, treatment triggered: 0/10 = 0% [bar <= 20%] -> met
5 cost-session-timeout-boundary default, treatment gated: 5/5 = 100% [bar >= 80%] -> met
5 cost-remove-export-boundary default, treatment gated: 1/5 = 20% [bar >= 80%] -> not met
6 context checks: passed (the design checks above raised no error)

design checks passed: every manifest row logged once with its pins and budget, every added row justified, no void attempt counted, the pinned bootstrap in every payload with one hash per arm, one listing per budget, expected brainstorming line per arm and budget, expected counts
```

Model `claude-opus-5`, Claude Code 2.1.261; default-budget brainstorming line `- hyperpowers:brainstorming`.

## Reruns, top-ups, control runs, voids

No trial was indeterminate and no attempt was void, so there were no reruns and no top-ups; `reruns.tsv` was not created. One control run was added under criterion 4 for the failed non-sentinel scenario, as a justified manifest row:

| scenario | treatment default | control default | reading |
|---|---|---|---|
| `triggering-executing-plans` | fail | fail | pre-existing; the session loads subagent-driven-development instead of executing-plans in both arms |

## Acceptance

1. Checkbox raised: treatment triggered 0 of 20 (0%; bar at most 20%). **Met.**
2. Boundaries raised: session timeout gated 10 of 10 (100%; bar at least 70%): **met**. Export removal gated 4 of 10 (40%): **not met.**
3. Twin raised: 0 treatment failures: **met**. Router b1 4 of 5 against 4 of 5, b2 to b5 5 of 5 against 5 of 5: **met**.
4. Regression set default: 13 of 14 sentinel and non-sentinel scenarios pass; `triggering-executing-plans` (non-sentinel) failed in treatment and in its control run, a pre-existing failure that does not block; no sentinel failure, so no hold. **Met.**
5. Production-budget check default: checkbox triggered 0 of 10 (bar at most 20%): **met**; session timeout gated 5 of 5 (bar at least 80%): **met**; export removal gated 1 of 5 (20%): **not met.**
6. Context checks: passed (the pinned bootstrap in every payload with one hash per arm, one listing per budget, one brainstorming line per arm and budget, one model, every added row justified). **Met.**

## Decision

The change does not ship under the spec's criteria because the export-removal scenario missed criteria 2 and 5, measured against the human partner's stated preference: "I'd rather have false positives than negatives, but it is a rigorous process, so we also don't want to trigger it when unnecessary."

## Limits

- The export sessions showed that several named the consequence and then took the request's "we don't use it anymore" as the yes ("You already said it's unused, so I'm treating that as the go-ahead"); the rest deleted and reported "Done." in one turn. The next wording must add that the yes has to come after the consequence is stated, and a request's claim that a feature is unused does not lift the deletion tripwire. The spec makes that a new measured change.
- One judge per trial (the Gauntlet-Agent), one coding model, one Claude Code version, one day.
- The raised budget renders all fifteen hyperpowers descriptions; the production listing renders far fewer, which is what the default-budget blocks measure.
- Five sessions per router brief per arm and one session per regression scenario: a single session moves those rates by 20 or 100 points; the regression set can show a failure but not a rate.
- The export-removal rates, 4 of 10 and 1 of 5, have Wilson intervals of 17-69 and 4-62 for the gate rate; the miss against 70% and 80% is not close, and the two budget conditions agree in direction.
- The `wait` bookkeeping quirk in `launch-all.sh` (an already-reaped child reported as non-zero) is recorded as a deferred minor; it did not affect a log or a run.
