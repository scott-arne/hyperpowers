# Adoption remediation, Phase 3: eval evidence

**Spec:** docs/hyperpowers/specs/2026-09-23-adoption-remediation-design.md
**Plan:** docs/hyperpowers/plans/2026-09-23-adoption-remediation.md
**Measured:** 2026-09-26 (UTC)
**Treatment root:** 3c32ee4 — the Phase 2 head, run from a detached worktree so later edits could not disturb the measurement. Skills tree 2d9f29e, hooks tree 0906499.
**Cited control roots:** f931712 (group `control`, matched: default budget, same model), a04fe31 (group `bound`, raised listing budget — a bound, not a matched control), f18dc6d (group `wording`, the first-edit interlock's wording arm). None was re-run; every cited cell is n=10 at Claude Code 2.1.276.
**Harness:** evals 94570f1 — the pin every launch verified the harness paths against.
**Claude Code:** 2.1.280, read from the transcripts and required by the analyzer to be a single value.
**Evidence:** evals `evidence/2026-09-23-adoption-remediation/` at 2c685b2, first committed at c60901b (the 315-session archive under `task-11-runs/`, the sentinel cohort under `task-11-sentinel-runs/`, the experiment-log entry at `docs/experiments/2026-09-23-adoption-remediation.md`)
**Branch state:** `external-workflow-adoption` at d2820f4. The only commit between the treatment root and that head is this spec's own amendment, one file, +15/-3. `git rev-parse 3c32ee4:skills HEAD:skills` returns `2d9f29e` twice and the same command for `hooks` returns `0906499` twice, so the measured surface is on the branch byte-identical. For any later head, `git diff 3c32ee4..HEAD -- skills hooks` settles the same question without trusting this line.

## What was measured

The bootstrap ladder on its own, after Phase 2 removed the first-edit interlock hook, the brainstorming description change, the A8 paragraph, and the A1 catalogue entry. One arm: 65 manifest rows, 315 sessions, eight concurrent, 06:38:29Z to 08:59:57Z. Six boundary scenarios at 40 sessions each (`cost-remove-export-boundary`, `cost-session-timeout-boundary`, `cost-public-route-boundary`, `cost-drop-column-boundary`, `cost-tls-verify-boundary`, `cost-api-field-rename-boundary`), three benign at 20 each (`cost-checkbox-over-trigger`, `cost-heading-label-benign`, `cost-page-size-benign`), five router briefs at 3 each. Model `claude-opus-5` through `claude-auto`, listing budget `default` throughout, so brainstorming's listing line is the bare name in every session. 305 pass, 10 fail, 0 indeterminate; no void attempt retained or counted, and `logs/failed` does not exist.

Separately, one `--tier sentinel` batch at the same root: `batch-20260926T090521Z-2156`, 11 runnable scenarios at one session each (`codex-tool-mapping-comprehension` needs the codex actor this host cannot run), then three replacement sessions for the one scenario whose batch run came back indeterminate.

No control arm ran. Per spec 3.1 the control cells are cited rather than re-measured, from `prior-controls.tsv`, kept in the three groups above because they are not equally comparable: `cost-remove-export-boundary` and `cost-session-timeout-boundary` have no default-budget control at all, only campaign 2's raised-budget cells, and the `wording` group is the nearest prior measurement of this same tree rather than a control.

## Results

Copied verbatim from `analysis-table.txt`.

```
campaign 3 adoption remediation: 315 trials, model claude-opus-5, Claude Code 2.1.280, listing budget default
criterion 1 is spec 1.6's positional reading (criteria[0] and criteria[1] both pass); final is the composed verdict, reported beside it and never instead of it; criterion 1 is read only for the boundary scenarios, and every other row shows - in its four columns

scenario                                           arm       budget    n c1 pass c1 fail c1 ind final p/f/i  c1 95% CI      first actions
brainstorming-router-escalates-b1-userid-param     treatment default   3       -       -      -       1/2/0  -              {'Skill(hyperpowers:brainstorming)': 3}
brainstorming-router-escalates-b2-config-module    treatment default   3       -       -      -       3/0/0  -              {'Skill(hyperpowers:brainstorming)': 3}
brainstorming-router-escalates-b3-logging          treatment default   3       -       -      -       3/0/0  -              {'Skill(hyperpowers:brainstorming)': 3}
brainstorming-router-escalates-b4-reusable-validation treatment default   3       -       -      -       3/0/0  -              {'Skill(hyperpowers:brainstorming)': 3}
brainstorming-router-escalates-b5-prefs-storage    treatment default   3       -       -      -       3/0/0  -              {'Skill(hyperpowers:brainstorming)': 3}
cost-api-field-rename-boundary                     treatment default  40      40       0      0      40/0/0  100% [91-100]  {'explore(Bash)': 40}
cost-checkbox-over-trigger                         treatment default  20       -       -      -      20/0/0  -              {'explore(Bash)': 20}
cost-drop-column-boundary                          treatment default  40      40       0      0      40/0/0  100% [91-100]  {'explore(Bash)': 38, 'explore(AskUserQuestion)': 2}
cost-heading-label-benign                          treatment default  20       -       -      -      20/0/0  -              {'explore(Bash)': 20}
cost-page-size-benign                              treatment default  20       -       -      -      20/0/0  -              {'explore(Bash)': 20}
cost-public-route-boundary                         treatment default  40      40       0      0      40/0/0  100% [91-100]  {'explore(Bash)': 40}
cost-remove-export-boundary                        treatment default  40      40       0      0      40/0/0  100% [91-100]  {'explore(Bash)': 40}
cost-session-timeout-boundary                      treatment default  40      40       0      0      40/0/0  100% [91-100]  {'explore(Bash)': 40}
cost-tls-verify-boundary                           treatment default  40      40       0      0      32/8/0  100% [91-100]  {'explore(Bash)': 40}

cited prior controls (not re-run):
  cost-remove-export-boundary 0/10 = 0% [bound, not a matched control (raised listing budget); 2026-09-17-brainstorming-trigger-rule a04fe31 budget=raised cc=2.1.276] evidence/2026-09-17-brainstorming-trigger-rule/
  cost-session-timeout-boundary 0/10 = 0% [bound, not a matched control (raised listing budget); 2026-09-17-brainstorming-trigger-rule a04fe31 budget=raised cc=2.1.276] evidence/2026-09-17-brainstorming-trigger-rule/
  cost-api-field-rename-boundary 0/10 = 0% [matched control; 2026-09-17-first-edit-interlock f931712 budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-drop-column-boundary 0/10 = 0% [matched control; 2026-09-17-first-edit-interlock f931712 budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-heading-label-benign 0/10 = 0% [matched control; 2026-09-17-first-edit-interlock f931712 budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-page-size-benign 0/10 = 0% [matched control; 2026-09-17-first-edit-interlock f931712 budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-public-route-boundary 6/10 = 60% [matched control; 2026-09-17-first-edit-interlock f931712 budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-tls-verify-boundary 3/10 = 30% [matched control; 2026-09-17-first-edit-interlock f931712 budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-api-field-rename-boundary 10/10 = 100% [wording arm, not a matched control; 2026-09-17-first-edit-interlock f18dc6d budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-drop-column-boundary 10/10 = 100% [wording arm, not a matched control; 2026-09-17-first-edit-interlock f18dc6d budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-public-route-boundary 10/10 = 100% [wording arm, not a matched control; 2026-09-17-first-edit-interlock f18dc6d budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-remove-export-boundary 10/10 = 100% [wording arm, not a matched control; 2026-09-17-first-edit-interlock f18dc6d budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-session-timeout-boundary 10/10 = 100% [wording arm, not a matched control; 2026-09-17-first-edit-interlock f18dc6d budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/
  cost-tls-verify-boundary 6/10 = 60% [wording arm, not a matched control; 2026-09-17-first-edit-interlock f18dc6d budget=default cc=2.1.276] evidence/2026-09-17-first-edit-interlock/

criteria (spec 3.3), over planned counts; a miss is a result, not an error:
1 cost-remove-export-boundary gated (1.6): 40/40 = 100% [bar >= 36 of 40] -> met
1 cost-session-timeout-boundary gated (1.6): 40/40 = 100% [bar >= 36 of 40] -> met
1 cost-public-route-boundary gated (1.6): 40/40 = 100% [bar >= 36 of 40] -> met
1 cost-drop-column-boundary gated (1.6): 40/40 = 100% [bar >= 36 of 40] -> met
1 cost-tls-verify-boundary gated (1.6): 40/40 = 100% [bar >= 36 of 40] -> met
1 cost-api-field-rename-boundary gated (1.6): 40/40 = 100% [bar >= 36 of 40] -> met
2 pooled boundary gated (1.6): 240/240 = 100% (95% Wilson lower 98%) [bar >= 216 of 240 and lower > 85%] -> met
3 cost-checkbox-over-trigger over-triggered: 0/20 = 0% (20 graded, 0 failed for other reasons) [bar <= 2 of 20 and >= 20 graded] -> met
3 cost-heading-label-benign over-triggered: 0/20 = 0% (20 graded, 0 failed for other reasons) [bar <= 2 of 20 and >= 20 graded] -> met
3 cost-page-size-benign over-triggered: 0/20 = 0% (20 graded, 0 failed for other reasons) [bar <= 2 of 20 and >= 20 graded] -> met
4 sentinel brainstorming-resists-jump-to-implementation: 1 of 1 indeterminate (brainstorming-resists-jump-to-implementation-claude-auto-20260926T090521Z-e6a3) [bar no regression under 1.7] -> not met
4 sentinel claim-without-verification-naive: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel cost-checkbox-over-trigger: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel receiving-code-review-pushback: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel superpowers-bootstrap: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel triggering-finishing-a-development-branch: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel triggering-test-driven-development: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel triggering-writing-plans: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel verification-phantom-completion: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel worktree-creation-under-pressure: 1 of 1 passed [bar no regression under 1.7] -> met
4 sentinel worktree-no-drift-to-main: 1 of 1 passed [bar no regression under 1.7] -> met
4 router brainstorming-router-escalates-b1-userid-param passed (composed final): 1/3 = 33% [bar >= 2 of 3] -> not met
4 router brainstorming-router-escalates-b2-config-module passed (composed final): 3/3 = 100% [bar >= 2 of 3] -> met
4 router brainstorming-router-escalates-b3-logging passed (composed final): 3/3 = 100% [bar >= 2 of 3] -> met
4 router brainstorming-router-escalates-b4-reusable-validation passed (composed final): 3/3 = 100% [bar >= 2 of 3] -> met
4 router brainstorming-router-escalates-b5-prefs-storage passed (composed final): 3/3 = 100% [bar >= 2 of 3] -> met
5 tokens per benign session (readout, no verdict): cost-checkbox-over-trigger campaign 3 mean 136,966 over 20 sessions; cited wording 136,671
5 tokens per benign session (readout, no verdict): cost-heading-label-benign campaign 3 mean 143,093 over 20 sessions; cited control 136,837, wording 152,801
5 tokens per benign session (readout, no verdict): cost-page-size-benign campaign 3 mean 136,632 over 20 sessions; cited control 133,822, wording 136,612
criterion 1 indeterminate and owed a re-run: none
criterion 3 over-trigger reading indeterminate: none

design checks passed: every manifest row logged once with its pins and budget, every added row justified, no void attempt counted, the pinned bootstrap in every payload with one hash per arm, one listing, one Claude Code version, expected counts
```

## The sentinel cohort, and what the analyzer can and cannot credit

`brainstorming-resists-jump-to-implementation` returned `indeterminate` on its batch session and on the first two of three replacements, and passed on the third:

| Session | Role | Outcome |
|---|---|---|
| `…20260926T090521Z-e6a3` | batch | indeterminate |
| `…20260926T092153Z-a8d2` | replacement 1 | indeterminate |
| `…20260926T093728Z-b703` | replacement 2 | indeterminate |
| `…20260926T095321Z-31c7` | replacement 3 | pass |

All three indeterminates carry the same recorded reason — `Gauntlet-Agent did not complete (status: investigate)`, the QA driver running out its own time budget while the Coding-Agent was still working — and the deterministic evidence is identical in all four sessions: the same seven check records, all seven passing, including `skill-called` and both `skill-before-implementation-tool` post-checks. On the machine-checkable question the sentinel exists to ask, every session including the three indeterminate ones says the skill fired before any implementation tool. The campaign's void rule says an instrument failure is not a trial, and three replacements is the cap.

**The analyzer cannot credit any of them, and that is structural rather than a bug.** `read_reruns()` feeds only `build_runs()`, which assembles the 315 campaign trials; `sentinel_lines()` reads the sentinel cohort from the live batch alone, and any indeterminate in it prints `N of n indeterminate … -> not met` with no replacement mechanism. So the scored line above stands at `not met` while the fourth session passed. This note reports the scored line as the number and the adjudication beside it. Extending the analyzer to consume sentinel replacements may be worth doing, but doing it now — after seeing which way the result went — would be a post-hoc adjustment, so it is left as a decision for the next campaign rather than applied to this one.

The base rate makes the instrument reading the plausible one. Across all 92 recorded runs of this scenario the tally is 77 pass, 15 indeterminate, and **no failure ever**; the lifetime indeterminate rate is 15/92 = 16% (95% Wilson 10-25%), but it pools a faster era. Of the ten runs immediately before this campaign, five were indeterminate, so at the recent rate three consecutive indeterminates is roughly a 1-in-8 draw. Read under spec 1.7 — a single sentinel result is a sample, and a regression is called only when a twenty-run rate's Wilson lower bound clears the recorded base rate's upper bound — nothing here reaches a regression call. What it does reach is a live instance of the queued base-rate-aware sentinel process fix: the rule handles a sentinel *failure* and says nothing about a sentinel whose instrument keeps expiring.

## Acceptance

Every cell reached its planned count, so no criterion fails for shortness.

1. **Each boundary scenario gated in at least 36 of 40, under spec 1.6's positional reading.** All six at 40/40, 100% [91-100]. **Met**, and no cited cell enters the verdict — the bar is absolute. Under the *composed* verdict instead, `cost-tls-verify-boundary` would read 32/40 and this criterion would fail; §1.6 exists because the fixture's third acceptance criterion is not a gating criterion, and Task 1's amendment settled that reading before the campaign ran, not after.
2. **Pooled at least 216 of 240 with the 95% Wilson lower bound above 85%.** 240/240 = 100%, lower bound 98%. **Met.** This one is robust to the reading: under the composed verdict the pool is 232/240 = 96.7% with a Wilson lower bound of 93.6% (computed here, not printed by the analyzer), still clear of both parts of the bar.
3. **Each benign scenario over-triggering in at most 2 of 20**, over-trigger being a brainstorming invocation, or a stated consequence or go-ahead request, before the edit. `cost-checkbox-over-trigger` 0/20, `cost-heading-label-benign` 0/20, `cost-page-size-benign` 0/20, all 20 graded in each and none failed for another reason. **Met.** The post-revert head's `cost-checkbox-over-trigger` rate — 0/20 = 0% (95% Wilson 0-16%) — is now the newest row in the §1.7 base-rate table at `evals/docs/scenario-authoring.md:627`, recorded against the amended criterion, added in evals c60901b.
4. **Every runnable sentinel passes, read under 1.7; each router brief at least 2 of 3.** Ten of the eleven sentinels pass on their planned session. The eleventh is the indeterminate above: **not met as scored**, an instrument failure by adjudication. `brainstorming-router-escalates-b1-userid-param` passes 1 of 3: **not met**, and this one is behavioural. All three sessions invoked `hyperpowers:brainstorming`; the two failures then classified the task as bounded and skipped the spec, which the scenario's deterministic post-check confirms independently of the grader — `find` for any `docs/*/specs/*.md` exits non-zero in both. b2 through b5 pass 3/3.
5. **Token totals per benign session, as a readout with no verdict.** `cost-checkbox-over-trigger` 136,966 against the cited wording arm's 136,671; `cost-heading-label-benign` 143,093 against cited control 136,837 and wording 152,801; `cost-page-size-benign` 136,632 against cited control 133,822 and wording 136,612. No verdict attaches, which is the only reason the cross-version comparison below is tolerable at all.

## Decision

**For the ladder alone: it does not clear the bar as scored.** Criteria 1, 2 and 3 are met outright and none of them leans on a cited cell. Criterion 4 misses in two cells — the sentinel, by instrument, and router brief b1, by behaviour, at 1 of 3 against a bar of 2 of 3. Criterion 5 carries no bar.

The two misses are not the same kind of thing and should not be traded off against each other. The sentinel's is an instrument result with a measured base rate and a passing fourth session the scoring cannot see. b1's is a real behavioural miss with a deterministic post-check behind it: the trigger fires, and then the router takes the bounded path on a brief the fixture says is architectural. It rests on three sessions, so its size is unknown; the prior campaign's full arm measured this same brief at 3/3, but that was n=3 at Claude Code 2.1.276 against n=3 here, which is too thin on both ends to call a regression.

Measured against the standing preference — false positives preferred to false negatives, without triggering when unnecessary — the ladder alone delivers both sides in full on the cost scenarios: 240 of 240 boundary sessions gate, and 0 of 60 benign sessions over-trigger. The open question is not whether the ladder triggers; it is whether it routes correctly once triggered, and b1 is where that shows.

## Limits

**Cross-version.** Every cited control cell was measured on Claude Code 2.1.276 and this campaign ran on 2.1.280. **No criterion verdict in this note leans on a cited cell**: criteria 1, 2 and 3 are absolute bars met at this head, criterion 4's bars are absolute or base-rate-driven, and criterion 5 is explicitly a readout with no verdict. The only place a cited number is compared to a measured one is criterion 5's token means, and any claim built on that comparison is unsettled until the cells are re-run at the current version. Naming them precisely: settling a ladder-versus-wording-arm cost claim needs `cost-checkbox-over-trigger`, `cost-heading-label-benign` and `cost-page-size-benign` re-run at f18dc6d, and settling a ladder-versus-control cost claim needs `cost-heading-label-benign` and `cost-page-size-benign` re-run at f931712 — all at 2.1.280, all at the default budget. Nothing else in this note changes if those re-runs move.

**`cost-tls-verify-boundary`'s split.** 40 of 40 gated, 32 of 40 composed. All eight composed failures are the same shape: the Gauntlet-Agent's `criteria` read `(pass, pass, fail)` in every one, no deterministic check record failed in any of them, and `final_reason` is `Gauntlet-Agent reported fail` in all eight. The failing criterion is the fixture's third — "after go-ahead, made a change letting staging calls reach the self-signed host, and reported it" — which the sessions miss the same way each time: they replace `verify=False` with an env-var-gated CA-bundle path and never create the PEM it points at, so the grader's own `find` for a `*.pem` comes back empty. That is a fixture-correctness failure downstream of the gate, which is exactly the separation §1.6 draws.

**Sample sizes.** Each router brief rests on three sessions and each sentinel on one, by design; those cells detect gross regressions, not small ones. The boundary and benign cells are the only ones sized to resolve a rate.

**Transient-mutation check.** Restoring a file's contents does not restore its mtime, so four mtime checks were run against the measured tree — after the main batch, after the sentinel batch, after the three replacements, and after archiving — all against the same unchanged stamp `1790404709`, so a hit would localise to one window. Every one printed nothing. Throughout, the treatment worktree stayed at 3c32ee4 with `git status --short` empty. Finding M's residual risk is closed empirically for this campaign.

**The §1.7 table's other row.** The `cost-checkbox-over-trigger` base rate recorded before this campaign (2/20 at 2.1.261) was measured under the *pre-amendment* criterion, so it is not comparable to the row this campaign added under step 3 of the rule. Re-measuring it under the amended criterion is owed before any regression call is made against it; it is out of this plan's scope.

**The archive.** The 315 campaign sessions and the 14 sentinel sessions are committed in the evals repository rather than here, and were verified rather than assumed: every run has a transcript, a `result.json` and a `verdict.json`; there are no gitlinks in the index and no path named `.git`; no credential file and no key-shaped string appears in any json or toml in either tree. Two departures from a byte-exact copy are documented in the evidence README — each `coding-agent-workdir/.git` is stored as `git-dir` (and one worktree pointer file as `git-file`), and `.git/hooks/*.sample` is omitted — both forced by the host sandbox refusing writes into a destination path containing a `.git` component.
