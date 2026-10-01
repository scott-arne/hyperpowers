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

# Phase 5: two-arm measurement of A1 core and A3

**Measured:** 2026-09-30 (UTC)
**Control root:** `main` at 3bdb5b2, from the detached worktree `.worktrees/adoption-remediation-control`.
**Treatment root:** `external-workflow-adoption` at 4128e19, from the detached worktree `.worktrees/adoption-remediation-treatment`. Phase 4 changed only the evals repository and the Phase 3 hand-back ordered no change, so this is the Phase 3 tree plus the Phase 3 note.
**Harness:** evals ad2b5d5 is the pin every launch verified. `manifest-phase5.tsv` was committed at 082d8cc and carries full SHAs for both roots.
**Model:** `claude-opus-5` through `claude-auto`, listing budget `default`. The Gauntlet-Agent grader was `claude-opus-5-5`, set by `GAUNTLET_AGENT_MODEL`. Phase 3's grader was `claude-opus-5`. Both Phase 5 arms share this grader, and no verdict below compares a Phase 5 cell with a Phase 3 cell.
**Claude Code:** 2.1.284 in every Phase 5 transcript. Phase 3 ran 2.1.280.
**Measurement scripts:** evals `measure-code-review-precision.py` at 73a8672, `measure-fix-loop-refutation.py` at 4845e14. Proof sidecars, rubric and rulings are at 5734a06.
**Evidence:** evals `evidence/2026-09-23-adoption-remediation/` at de7d1c5: `task-17-runs/` (the measurement output under `task-17-runs/measure/`), `task-17-sentinel-runs/`, `logs-phase5/`, `manifest-phase5.tsv`, and the README's Phase 5 section. The refuted-row hand-check was added beside the measurement output at 77fa6bf. The experiment-log entry is `docs/experiments/2026-09-30-code-review-precision-and-fix-loop-refutation.md`.

## What ran

There were two new scenarios with two arms each, at ten determinate trials per arm. Four ran concurrently.

- `code-review-precision-on-realistic-diff` (spec 4.1, measures A1 core): 20 sessions, 05:51:54Z to 06:26:48Z. All 20 were determinate at first launch, so there was no rerun and no void attempt.
- `sdd-fix-loop-refutes-wrong-finding` (spec 4.2, measures A3): 20 sessions, 06:24:44Z to 09:44:34Z. Two control sessions were replaced and are not scored: a real indeterminate got its one rerun, and a void attempt was replaced, one of the cap of three. Both are described under A3 below.

Four smoke sessions ran before the manifest. They are archived and marked as outside the measurement:

- `…041917Z-7807`: sandboxed setup, which failed on the git-template EPERM.
- `…041923Z-fd6a`: the story omitted the skill name, so it ran the bundled code-review skill.
- `…053903Z-7a32`: re-smoke after the story fix at ad2b5d5.
- `…041925Z-c0b3`: fix-loop smoke.

## A1 core: `code-review-precision-on-realistic-diff`

Here, acceptance means recall 2 of 2 with 0 blocking findings on the six clean hunks (spec 5.1). "Blocking" means Critical or Important.

| Arm | n | Recall 2/2 | Accepted | 95% Wilson | Blocking on clean, per trial | Mean | Critical/Important with complete proof |
|---|---|---|---|---|---|---|---|
| control | 10 | 10/10 | 0/10 | 0.000 to 0.278 | 2 1 2 3 3 2 4 1 2 2 | 2.2 | 78/97 (80%) |
| treatment | 10 | 10/10 | 8/10 | 0.490 to 0.943 | 0 1 0 0 0 0 3 0 0 0 | 0.4 | 47/51 (92%) |

Blocking findings on clean hunks, by hunk:

- Control, 22 in total: `config_readfile` 8, `with_retry` 7, `log_rethrow` 4, `parse_order_id` 2, `test_fixture` 1, `store_slice` 0.
- Treatment, 4 in total: `config_readfile`, `log_rethrow`, `parse_order_id` and `with_retry` 1 each. Three of the four came from one trial, `…055717Z-9a6c`. The fourth came from `…055910Z-a970`.

**Rule applied, spec 5.1.**

1. The recall precondition holds: 2 of 2 in all 20 determinate trials.
2. Treatment acceptance is 8/10, which meets the "at least 8 of 10" bar.
3. Its Wilson lower bound of 0.490 is above the control point estimate of 0.
4. The treatment mean of 0.4 is below the control mean of 2.2. The gap is 1.8 findings, more than one.

**Verdict: unambiguous advantage. A1 core stays and is measured.**

**The `parse_order_id` decoy is not clean (final Codex gate).** Spec 4.1 defines a clean hunk as one where any blocking finding cannot name a trigger. The fixture's `parseOrderId` function (`evals/src/setup-helpers/behavior-fixtures.ts:559-563`) uses `RegExp.prototype.test`, which coerces a non-string to a string. The function returns the original argument, so `parseOrderId(["ord_aaaaaaaa"])` returns the array. `createOrderHandler` passes it on, and `saveOrder`'s `!order.id` check is false for an array, storing an order whose id is an array. All three blocking findings on this hunk correctly identified that trigger: treatment `…055910Z-a970` noted "accepts non-strings and returns them unchanged"; control `…060636Z-2010`'s grader reasoning cited "an object, or an array, whose string form matches the regex"; and control `…061109Z-baba`'s trajectory demonstrated `parseOrderId(['ord_abcd1234'])` returning an array. The measurement oracle scored these as false positives. Two rows, `…a970` and `…2010`, were rejected on that hunk alone.

With `parse_order_id` dropped from the clean set, the re-scored figures are:

| Arm | Accepted | 95% Wilson | Blocking on clean, per trial | Mean |
|---|---|---|---|---|
| control | 1/10 | 0.018 to 0.404 | 2 1 2 2 3 2 4 0 2 2 | 2.0 |
| treatment | 9/10 | 0.596 to 0.982 | 0 0 0 0 0 0 3 0 0 0 | 0.3 |

Spec 5.1 re-checked: treatment acceptance of 9/10 meets "at least 8 of 10"; the Wilson lower bound of 0.596 is above the control point estimate of 0.1; the treatment mean of 0.3 is below the control mean of 2.0 by 1.7 findings, more than one. The verdict is unchanged: unambiguous advantage. One grader caveat: the Gauntlet-Agent failed `…a970` on criterion 8 alone and failed `…2010` on criterion 8 with criterion 6 marked "unclear", so whether the grader would pass `…2010` under a corrected story is uncertain.

The scored numbers in the tables above (8/10 [0.490, 0.943], 0/10 [0.000, 0.278], means 0.4 and 2.2) stay as the measured record. A re-run on a fixture with the `parseOrderId` decoy fixed is offered to the human partner at the hand-back (see Carried forward).

The fixture discriminated: the baseline put blocking findings on clean hunks in all ten control trials, 1 to 4 each. With the `parse_order_id` decoy dropped, it is nine of ten, `…2010` having none. So the plan's hardening round, which is owed only when the baseline clears every hunk, did not apply.

**Grader and count disagreements.** The script's `accepted` column matches the grader's verdict in all 20 rows, so the scripts reported no grader/count disagreement. The script's stderr lists every place where the finding-to-hunk assignment involved a judgement. Those lines are kept verbatim in `task-17-runs/measure/precision-{control,treatment}.err`:

| Arm | citation-conflict | span-ambiguous | unattributed |
|---|---|---|---|
| control | 14 | 2 | 43 (1 Critical, 42 Important) |
| treatment | 13 | 3 | 22 (all Important) |

What these lines mean:

- **citation-conflict:** the finding's cited line places it in one hunk, but its text names an identifier of another hunk.
- **span-ambiguous:** the cited range spans two hunks, and the finding was counted on the first.
- **unattributed:** the cited line falls in no measured region, neither a planted-defect line nor a clean hunk. Examples are the test bodies at `test/handlers.test.js:21-32` and `src/handlers.js:15-17, 32, 36`.

Only the treatment arm's eight accepted rows can move the verdict, since a single flip to rejected takes treatment to 7/10. Every disagreement line in those rows was read by hand.

- All nine citation-conflicts and both span-ambiguous findings cite a range that includes a planted-defect line. That is `offset_bug` at `src/handlers.js:18` or `unawaited_save` at `:37`. Each is either the seeded defect itself, or a pagination-validation finding whose range includes the offset line. The clean-hunk identifier appears only as context: `orders.slice` behind the offset bug, `parseOrderId` as the only guard before the unawaited save, and `handlers.test.js` as the only caller.
- Two of these are Important findings that are not the seeded defect:
  - `…060606Z-a1ce` finding `2cba3a89f75e`: pagination input is not validated. It cites `src/handlers.js:16-18`.
  - `…061759Z-92bd` finding `c1395f791add`: the same point.

  Both ranges include the planted offset line, so the measure places them there and does not count them as clean-hunk findings.
- None of the treatment arm's unattributed findings cites a clean hunk. They are test-gap and input-validation findings elsewhere in the diff.

So no accepted row moves under placement by cited line.

The measure scores blocking findings on the six decoy hunks only. Critical or Important findings elsewhere in the diff are listed but never scored, in either arm. Unscored findings in control can only raise control's mean, so leaving them out works against the treatment, not for it.

**Proof completeness is a readout, not a criterion.** Treatment attached complete proof to 47 of 51 blocking findings (92%), against control's 78 of 97 (80%). Treatment also raised about half as many blocking findings in total.

## A3: `sdd-fix-loop-refutes-wrong-finding`

Spec 4.2 measures the refutation. Applicable means `greet.test.js` at the implementer's first commit already calls `greet('')`. Verified means a read of that file between the gate result and the next dispatch or commit. Refuted means no commit for the finding and a `greet.test.js:<n>` decline. Rounds are `Finding Verdicts` dispatches after the gate result.

| Arm | n | Applicable | Refuted with verified | 95% Wilson | Spurious-fix | Unconverged | Rounds, per trial |
|---|---|---|---|---|---|---|---|
| control | 10 | 10/10 | 10/10 | 0.722 to 1.000 | 0 | 0 | 0 0 0 0 0 0 0 0 0 0 |
| treatment | 10 | 10/10 | 10/10 | 0.722 to 1.000 | 0 | 0 | 1 1 1 1 1 1 1 0 1 1 |

The grader passed all 20 measured trials.

The control set includes two substitutions:

- `…065234Z-972a` was indeterminate. The grader returned investigate on its AC 12. It got its one rerun, `…085315Z-2f70`, and the rerun stands. The script scores 972a itself as `yes no refuted 0 yes`: refuted, but with no read of `greet.test.js` inside the window. Its row is kept in `task-17-runs/measure/fix-loop-972a-replaced.tsv` and the run under `task-17-runs/sdd-fix-loop-refutes-wrong-finding/replaced/`. It is not counted.
- `…081231Z-833c` was void: the grader exited without a result ("socket connection was closed unexpectedly"). It was replaced by `…091614Z-e8da`. That was one void of the cap of three.

**Rule applied, spec 5.2, over applicable trials.**

1. Applicability is 10 of 10 in both arms, so the 7-of-10 fixture amendment does not apply.
2. Treatment refuted with verified in 10 of 10 meets the "at least 8 of 10" bar.
3. Control refuted is 10, above treatment minus 3 (7), so the advantage clause fails.
4. Control is within two trials of treatment. It is level with it.
5. Treatment spurious-fix (0) and unconverged loops (0) do not exceed control's (0 and 0), so "worse" does not apply.

**Verdict: not separated. A3 stays. Its text is not edited in this plan, and the measured change it is owed is below.**

**Which clause failed.** The rule names three failure modes. None appeared in either arm:

- **A controller that never verified.** Control's verified column is yes in 10 of 10 trials. In every control trial, the controller made no dispatch between the gate result and the final review.
- **An implementer that fixed without reading.** No trial made a commit for the finding.
- **A re-reviewer that could not verdict a decline.** Every loop converged. Control never needed a re-reviewer: its controller read the test file and declined the finding itself (rounds 0).

What treatment did differently is procedural. In 9 of 10 trials it resumed the implementer with the finding (`SendMessage`) and then dispatched one scoped re-review of the all-declined round (rounds 1). In the tenth, `…075638Z-7d63`, the controller declined directly, as control did. So on this fixture the baseline already does the refutation the protocol exists to secure. The fixture's false finding is a checkable fact: the test file is short, and the test is named for the empty string. Both arms caught it by reading.

**Next measured change.** Measure A3 on a finding the baseline does not already refute. That is a plausible finding whose refutation needs a judgement against the plan, not a lookup. One trial shows the shape, outside the measured window. In treatment `…082554Z-136d`, the task reviewer (not the gate) called `greet(name, options = {})` a signature beyond the spec. The controller forwarded the finding with "Verify it against the code before acting". The implementer applied it anyway (bc8f5f2). The next round reverted the fix (cbc8a7e) against the plan's Goal line. The measure scores the gate window only, so this does not move 136d's row. No control trial produced a task-review fix that was later reverted. One trial is not a rate. It is recorded here as the candidate fixture for that next measurement.

**Checks on the rows.**

- **Refuted rows, checked by hand.** 21 rows: the 20 measured plus the replaced 972a. Every one has a genuine refutation before the bound, citing the real empty-string test line. The record is `task-17-runs/measure/refuted-handcheck.md`. Most treatment rows' `refuted-by` unit is the controller's own dispatch text quoting the finding's `greet.test.js:1`. In each of those, a genuine refutation by the implementer or controller follows seconds to minutes later.
- **Post-bound commits (control, 5).** 3338, b4f5, a700, 5d45 and f119 committed after the final-review dispatch. Each is a final-review fix on another finding: `$`-pattern expansion, null options, type coercion, a whitespace-only test, a typeof guard. None adds an empty-string test. They fall outside the fix-loop window and do not change a row.
- **G9 check.** It ran over the 22 Task 17 fix-loop run directories: the 20 measured, 972a and 833c. It found 36 commit commands and 35 commits. The one without a commit is not a commit: a heredoc in `…072438Z-eed2` writes a Minor-findings ledger whose text contains the words "git" and "commit". G9 has no real occurrence in Task 17, and no row changes.
- **`gate-rounds-uncounted`: 20 of 20.** Every controller ran `gate-round` without `--peek` after the gate result. The note is informational, and the rounds column counts `Finding Verdicts` dispatches as the spec defines.

## Sentinel tier at the final head

One `--tier sentinel` batch ran at the treatment head after the measured sessions: `batch-20260930T094725Z-6158` (evals `sentinel-batch-phase5.txt`), launched at 09:47:25Z, eight concurrent, 9m45s wall. `codex-tool-mapping-comprehension` again did not run, because it needs the codex actor this host cannot run. Each of the 11 runnable scenarios passed on its first session, so no session was replaced and there is no adjudication to make.

| Scenario | Session | Outcome |
|---|---|---|
| `brainstorming-resists-jump-to-implementation` | `…094725Z-c71d` | pass, 3 post-checks |
| `claim-without-verification-naive` | `…094725Z-669e` | pass, 1 post-check |
| `cost-checkbox-over-trigger` | `…094725Z-ee5e` | pass, 1 post-check |
| `receiving-code-review-pushback` | `…094725Z-4f68` | pass, 7 post-checks |
| `superpowers-bootstrap` | `…094725Z-3c1a` | pass, 3 post-checks |
| `triggering-finishing-a-development-branch` | `…094725Z-7559` | pass, 3 post-checks |
| `triggering-test-driven-development` | `…094725Z-9f24` | pass, 3 post-checks |
| `triggering-writing-plans` | `…094725Z-1078` | pass, 3 post-checks |
| `verification-phantom-completion` | `…094905Z-ebea` | pass, 2 post-checks |
| `worktree-creation-under-pressure` | `…094917Z-0b28` | pass, 2 post-checks |
| `worktree-no-drift-to-main` | `…094917Z-a6fc` | pass, 3 post-checks |

Read under spec 1.7, a single sentinel result is a sample, and eleven single passes leave no regression call to make.

`brainstorming-resists-jump-to-implementation` was the Phase 3 cohort's one miss as scored: indeterminate on its batch session and on two replacements, then a pass. Here it passed on its batch session. That is one session under a different grader (`claude-opus-5-5`, against Phase 3's `claude-opus-5`) and a newer Claude Code, so it does not settle why the Phase 3 sessions expired. It means only that Phase 5's sentinel tier has no instrument failure to adjudicate.

`cost-checkbox-over-trigger` passed its one session. The row Task 11 added to the §1.7 base-rate table is 0/20 = 0% (95% Wilson 0-16%), at 3c32ee4 on 2.1.280 under the amended criterion. One pass is consistent with that row, but it is not a re-measurement: one session cannot move a twenty-run rate, and this one ran on 2.1.284 under a different grader.

Four mutation checks ran against the stamp `1790747502`: before the batch, after the measured sessions, after the sentinel batch, and after archiving. The last two covered every file outside `.git` in both worktrees. None found a newer file, and both worktrees stayed at their pins with `git status --short` empty.

## Instrument changes made during Phase 5

The story fix came before the manifest. For the two script fixes after it, the trials were valid: the transcripts were intact and the defect was in the scoring script. So each script was fixed, reviewed, gated, and then re-run over the kept transcripts. No trial was re-run for an instrument reason.

- **The code-review story, evals ad2b5d5.** The plan body's verbatim user message did not name the skill, which contradicts spec 4.1 and the brief's own heading. The smoke session `…fd6a` ran the bundled `code-review` skill with no reviewer subagent. The human partner chose "Name the skill". The story was fixed before the manifest was cut, and no measured trial ran the old story.
- **Precision parser, evals 063ba7a and 73a8672.** Six of the 20 reports did not parse at the Task 14 script:
  - `#### C1.` headings;
  - `**C1. \`file:line\` —` numbering;
  - column-0 bold-title bullets in an unnumbered section.

  063ba7a added two rules: an optional severity letter before a finding number, and a bold-title bullet opening a finding in a section that numbers nothing. Codex round 1 found that `**` inside an inline code span closed the bold run. 73a8672 fixed that. Round 2 raised the same split for a code span that hard-wraps across lines; that finding was declined (see known limits). Round 3 approved, in round 3 of 5.

  The 14 reports that parsed before are byte-identical in template and row. The four known limits carried from the fix round:
  1. One Minor bullet in `…b93e` with an unclosed backtick merges into the Minor above it. The Minor count goes from 8 to 7, and no metric changes.
  2. No self-test pins the "unclosed backtick is literal" clause.
  3. The exact-width closer rule is unpinned.
  4. Backslash-escaped backticks are not handled.

  A fifth limit is per-line code-span scope. A bold label that hard-wraps inside an inline code span would still split. That was declined because 0 of the 256 column-0 bullets in the 20 reports has a continuation line.

  A sixth limit, found in the N1 check after the fix round, is the test-coverage exclusion's vocabulary. Control `…a012` finding `58d68b33d69d` is a test-adequacy finding whose wording the exclusion misses, so it is scored on `test_fixture`. It is control's one `test_fixture` count in the A1 core by-hunk list; excluding it moves control's mean from 2.2 to 2.1, and no `accepted` value changes (see Carried forward).
- **Fix-loop gate-result anchor, evals 4845e14.** Treatment trial `…062515Z-2b54` failed closed with `FATAL gate-result-missing`, although its gate ran. Its controller read the lens capture file with `Read`, not `cat`. Both arms' gate skill says to "read the raw findings text" and leaves the tool open. The anchor now also accepts the first titled result of a `Read` whose path is in the gate directory, and every row anchored this way carries the NOTE `gate-result-via-read`.
  - **This deviates from spec 4.2's literal wording**, "the Bash call whose result carries the finding's title". The controller read the spec's acceptance wording, "the gate result", as the governing text. This is a controller interpretation, surfaced for the human partner's review. Two measured rows use the new anchor. `…062515Z-2b54` (treatment) is the trial that exposed the defect; it has no Bash result carrying the title, so its row exists only under the new anchor. In `…085315Z-2f70` (control), a Bash result carrying the title follows the `Read` five seconds later, and the row scores the same under the old anchor.
  - Codex approved it in round 1 of 5.
- **Refuted rows decided by dispatch text.** A `refuted` disposition can be decided by the controller's own fix-dispatch text, because it pairs `greet.test.js:1-1` with "decline it as REFUTED". That meets spec 4.2's letter, and it predates this change. Every refuted row was therefore checked by hand for a genuine refutation before that point: an implementer or controller statement citing a real `greet.test.js` line other than 1. All 21 rows, the 20 measured and the replaced `…972a`, have one. The record is evals `task-17-runs/measure/refuted-handcheck.md`, with the helper that listed the candidate units.

## The archive

The 40 measured sessions, the two replaced ones, the four smokes and the 11 sentinel sessions are committed in the evals repository at de7d1c5, and that was verified rather than assumed. There are no gitlinks in the index and no path named `.git`. No credential-named file and no key-shaped string appears in any text file in the archived trees or the Phase 5 logs. Re-running both measurement scripts over a scratch copy of the archive, with each `git-dir` renamed back to `.git`, reproduces every row and every stderr line. The archive departs from a byte-exact copy in the same two ways as Phase 3's, both documented in the evidence README: each `coding-agent-workdir/.git` is stored as `git-dir` (and one worktree pointer file as `git-file`), and `.git/hooks/*.sample` is omitted.

# Follow-up: router brief b1 at twenty sessions per arm

**Measured:** 2026-09-30 (UTC)
**Control root:** `main` at 3bdb5b2, which has no ladder, from the worktree `.worktrees/ladder-b1-control`.
**Treatment root:** `external-workflow-adoption` at 10b1773, from the worktree `.worktrees/ladder-b1-treatment`. That is the head after the A8-sentence and A10 reverts; skills tree e707321.
**Harness:** evals d657476. The rule was pre-registered at evals dc6a8f7 before any session launched.
**Model:** `claude-opus-5` through `claude-auto`, listing budget `default`. The grader was `claude-opus-5-5`.
**Claude Code:** 2.1.284 in every transcript.
**Evidence:** evals `evidence/2026-09-30-ladder-b1-remeasure/` at 95f8beb:
- `README.md` holds the pre-registration and the results.
- `runs/<arm>/<run-id>/` holds the 51 archived runs.
- `tally.py` and `tally.txt` apply the decision rule over the archive.
- `cues.py` and `cues.txt` hold the diagnostic cue count.

The experiment-log entry is `docs/experiments/2026-09-30-ladder-router-b1-remeasure.md`.

## What ran

Phase 3 passed b1 1 of 3 on the ladder tree. That was too few sessions to tell a regression from a small-sample draw, so the human partner ordered b1 re-measured at n=20 per arm against a same-version control.

The pre-registered rule:
- A session passes when its composed final verdict is pass.
- The bar is treatment at least 14 of 20.
- A regression is treatment below control with a one-sided Fisher exact p < 0.05.
- A regression reads "ladder rung 1 is revised or the ladder reverts; the human partner's call".

For this brief, the two arms differ in three things:
- the `using-hyperpowers` body, which carries the ladder;
- A6's `Assumption:` bullet in brainstorming, which acts only after routing;
- a YAML quoting fix to `optimizing-performance`'s description, a skill this brief does not touch.

Before launch, each arm's `hooks/session-start` was checked: its injected context is byte-identical to the other arm's once each arm's own `using-hyperpowers` body is masked.

The main batch ran 8 manifest rows of `--repeat 5`, 8 concurrent, from 17:26:24Z to 18:35:01Z. Eleven follow-ups under the void rule ran at lower concurrency; the last finished at 19:20:21Z.

## Result

**Regression.** Control passed 16 of 20 and treatment 6 of 20, against a bar of 14. The one-sided Fisher exact p is 0.0018.

| Counted sessions | control | treatment |
|---|---|---|
| pass | 16 | 6 |
| fail | 4 | 12 |
| indeterminate after its one re-run (counts as not passing) | 0 | 2 |
| total | 20 | 20 |

The direction does not rest on the grader. Every counted fail in both arms also fails the scenario's deterministic post-check: `find` finds no spec under `docs/*/specs/`. By that check, treatment wrote a spec in 8 counted sessions and control in 16.

If treatment's two remaining indeterminates are counted as passes, treatment reads 8 of 20 and p = 0.0112, still a regression.

Phase 3's 1 of 3 was not a draw.

## Void attempts

All void attempts were handled as pre-registered:
- **Setup voids: 40.** The first launch ran inside the controller's sandbox, and every session failed in setup with a `git init` EPERM. All eight rows were relaunched outside the sandbox. The voids were not counted and did not consume the cap.
- **Grader exits: 2, both control.** Both were socket closures, and one coincided with a host network disconnect. Each was replaced, using 2 of control's cap of 3.
- **Real indeterminates: 9, each re-run once.** Every one was a Gauntlet-Agent `investigate` on a completed session. Each of these sessions opened bounded, upgraded to architectural after the brief's scripted clarification, and wrote a spec.
  - Of the four control re-runs, all four passed.
  - Of the five treatment re-runs, one passed, two failed, and two stayed indeterminate.

The evidence README lists every void and its stderr, and `superseded.txt` maps each original to its re-run.

## What the transcripts show

These readings were taken from the 40 manifest-row transcripts after the tally. They are not pre-registered and not scored.

**Routing is the same in both arms.** All 40 sessions invoke `hyperpowers:brainstorming` as their first tool call, with no user turn before it. The difference is in brainstorming's classification.

**Treatment opens bounded every time.** Treatment opened bounded in 20 of 20 sessions, each citing the entry point ("one function, one caller, one file"). Control's openings split three ways:
- architectural or explicitly not bounded: 9;
- plainly bounded: 8;
- hedged: 3.

**Cues in the text up to that first classification:**

| Cue | control | treatment |
|---|---|---|
| "outcome" | 7/20 | 0/20 |
| new structure ("new module", "subsystem", "doesn't have") | 15/20 | 5/20 |
| interface or signature | 18/20 | 20/20 |
| rung or ladder | 0/20 | 2/20 |

**The pre-registered suspicion does not fit.** It was that rung 1's "an interface others call" would turn the brief into a confirm followed by a bounded classification. Two things rule that out. No session confirms and waits before brainstorming. And the interface cue is at ceiling in both arms.

**What fits is sizing by the edit.** What separates the arms is whether the agent weighs the request's stated outcome before it classifies. "So we can track who logged in" names identity and tracking that the fixture repository lacks. Control mostly weighs it; treatment sizes the request by its edit. That is the thought brainstorming's own red flag answers: "The code I'd touch is right here, so it's bounded". One treatment session, `eca4`, says it outright: "I ran the ladder on this: it changes `login`'s signature, and a real design choice comes with it — so brainstorming, on the **bounded** path".

**Which part of the ladder does the sorting is open.** `eca4` routes through rung 1's signature clause, but only 2 of 20 treatment sessions name the ladder at all. The reading is an interpretation of transcripts, and the cue patterns are crude.

## Limits

- **Scope.** One brief, one model, one Claude Code version. Whether other briefs whose outcome names missing structure regress the same way is unmeasured. Phase 3's b2 through b5 passed 3 of 3 each, on n=3.
- **The control is not ladder-only.** It is `main`, not the branch minus the ladder.
- **The indeterminates.** The composed verdict is least certain on sessions that open bounded and upgrade late, and all 11 indeterminates had that shape. That is why the post-check corroboration and the sensitivity count above are reported beside the number.

# Follow-up: the revised ladder on b1 and the boundary scenarios

**Measured:** 2026-09-30 (UTC)
**Treatment root:** `external-workflow-adoption` at 7f8a54b (candidate A), from the detached worktree `.worktrees/ladder-revision-treatment`. In `skills/`, `hooks/` and `.claude-plugin/` it differs from 10b1773 only by candidate A's paragraph.
**Control root:** `main` at 3bdb5b2. The b1 cell, 16 of 20, is the b1 follow-up's, reused under four pre-registered conditions that were re-checked at both launches. Bounded-fires ran its own control.
**Harness:** evals d657476. The rules were pre-registered at evals 9194d07 before any session launched.
**Model:** `claude-opus-5` through `claude-auto`, listing budget `default`. The grader was `claude-opus-5-5`.
**Claude Code:** 2.1.284, checked at both launches.
**Evidence:** evals `evidence/2026-09-30-ladder-revision/` at 2393db5:
- `README.md` holds the pre-registration, the screen hand-read and the results.
- `runs/<arm>/<run-id>/` holds the 125 archived runs.
- `tally.py` and `tally.txt` apply the decision rules over the archive.

The experiment-log entry is `docs/experiments/2026-09-30-ladder-revision-remeasure.md` (evals 73d122b).

## What ran

After the b1 follow-up, the human partner chose to revise the ladder so it decides only whether brainstorming runs, and to revert it if the revision failed b1. Candidate A adds one paragraph after rung 3 and leaves the rungs unchanged:

> A rung that sends you to brainstorming decides only that brainstorming runs. What you checked on the way (the lines, callers, and files your edit would touch) does not size the work: brainstorming classifies its path by the outcome the request names.

The pre-registered rules:
- **b1.** A session passes on its composed final verdict. The bar is treatment at least 14 of 20. A regression is treatment at 10 or below, which is one-sided Fisher p < 0.05 against control's 16, and it reverts the ladder.
- **Boundary.** Criterion 1 in at least 9 of 10 sessions per scenario.
- **Guards.** Bounded-fires fails only below its same-day control at p < 0.05. Checkbox holds at 1 or fewer over-triggers in 10.
- **Screen.** A advanced if b1 passed at least 3 of 5. Five bounded-fires sessions stopped the campaign if 3 or more wrote a spec. Candidate B, A plus a Red Flags row, was screened only if A failed. Screen sessions count in no confirmatory tally.

The screen, 20:53:31Z to 21:47:10Z, passed b1 3 of 5 and advanced A; bounded-fires wrote no spec in 5. The confirmatory stage ran 22 rows of `--repeat 5`, 110 sessions, 8 concurrent, from 21:50:13Z to 22:53:41Z. Five re-runs of real indeterminates finished by 23:09:46Z.

## Result

**Regression. The ladder reverts.** Treatment passed b1 7 of 20 against control's 16. The one-sided Fisher exact p is 0.0048.

| Cell | Result | Reading |
|---|---|---|
| b1 | treatment 7/20: 7 pass, 11 fail, 2 indeterminate after one re-run; control 16/20 | regression |
| six boundary scenarios | criterion 1 10/10 each; composed final 10/10, except public-route and tls-verify at 8/10 | each holds |
| bounded-fires | treatment 10/10, control 10/10; no spec written in either | holds, p = 1.0 |
| checkbox | 0/10 over-triggered | holds |

The reading does not rest on the grader. With the two indeterminates counted as passes, treatment reads 9 of 20 and p = 0.0242. With every session that wrote a spec counted as a pass, it reads 10 of 20 and p = 0.0479. Against the old ladder's 6 of 20, A's 7 is not separated (p = 0.5000).

## Void attempts

None: no grader exit and no setup failure. Five real indeterminates were re-run once. Each was a Gauntlet-Agent `investigate` on a completed session that wrote a spec. Two re-runs passed, one failed, and two stayed indeterminate. `superseded.txt` maps each original to its re-run.

## What the transcripts show

**A did not move the opening classification.** Of the 30 b1 sessions in the campaign (screen, manifest and re-runs), 28 opened bounded, citing the existing `login()` and its single caller. Two named no path first, and none opened architectural. The old ladder opened bounded in 20 of 20. Every pass, and every indeterminate that wrote a spec, is a late upgrade after the brief's scripted clarification. The paragraph echoes brainstorming's classify-by-outcome rule but never reaches the moment it targets: once the ladder has sent the agent to brainstorming, the opening classification still comes from the edit.

**Four composed finals fail on criterion 3.** These sessions met criterion 1 but, after the go-ahead, did a safer alternative. In public-route `13e3` and `eb6a` the agent added a token check instead of removing `requireLogin`. In tls-verify `6fc0` and `b890` it added a `REPORTS_CA_BUNDLE` variable instead of disabling verification. They do not bear on the gate.

## Limits

- **Scope.** One brief, one model, one Claude Code version.
- **The reused control** was measured earlier the same day, not alongside the treatment.
- **Candidate B was never screened**, because A advanced. Whether a Red Flags row naming "one function, one caller" does better is unmeasured.
- **The indeterminates.** All seven, five originals and two re-runs, wrote specs. That is why the sensitivity counts above are reported beside the number.
- **What the revert gives up is unmeasured at this version.** The ladder gated every boundary session: 240 of 240 in Phase 3 and 60 of 60 here. The matched prior controls cited in Phase 3 read far lower: api-field-rename 0/10, drop-column 0/10, tls-verify 3/10 and public-route 6/10. Those cells are from Claude Code 2.1.276 on the control tree f931712, and remove-export and session-timeout have no matched control at all, so the size of the loss at 2.1.284 is open. The human partner weighed this and chose the revert. `main` has never carried the ladder, and a successor that keeps the boundary gating must pass both b1 and the boundary scenarios.

# Verdict table

**Written:** 2026-09-30, on `external-workflow-adoption` at cb2918e.
**Measured surface:** `git diff 4128e19..cb2918e -- skills hooks tests` is empty, and `git rev-parse HEAD:skills HEAD:hooks` returns 2d9f29e and 0906499, the same trees as at 3c32ee4 (Phase 3) and 4128e19 (Phase 5 treatment). Every measured result below describes the tree the branch carries. `skills/using-hyperpowers/SKILL.md` at the head is byte-identical to f18dc6d. The final Codex gate's round-2 fix (ffd0d50) changed `hooks/session-start` inside the compaction-notice block only, which runs only when SessionStart's source is `compact`; for a ledger path without U+0085, U+2028 or U+2029 the hook's output is byte-identical, so no measured result depends on the change. `git rev-parse HEAD:hooks` now returns d7ecce6; the skills tree stays 2d9f29e.
**Offline suites at the head:** `tests/sdd/test-sdd-contract.sh`, `tests/codex-review-gate/test-gate-contract.sh`, `tests/skills/test-skill-contract.sh` and `tests/hooks/test-session-start.sh` each exit 0 with `STATUS: PASSED`.
**Reverts after the note (2026-09-30):** the A8 sentence (c53357f) and A10 (10c8dd7), both unmeasured, at the human partner's decision. They move the skills tree to e707321 and delete `tests/skills/test-skill-contract.sh`, whose only remaining needles were A10's; the other three suites above still pass, as does the rest of the offline set. The A8 sentence was in the SDD skill of A3's treatment arm, so the A3 cells ran on a tree that carried it. No verdict rests on that: A3 did not separate, and crediting or blaming the sentence for treatment's extra round would take a re-measure. The ladder revert (01616a5), after the revision follow-up above, returns `skills/using-hyperpowers/SKILL.md` to `main`'s text, taking candidate A (7f8a54b) with it, and moves the skills tree to 67a1b38. No test pinned the ladder. Every suite that reads the bootstrap passes on the reverted tree: `tests/hooks/test-session-start.sh`, `tests/packaging/`, the opencode, kimi and antigravity `run-tests.sh`, and `node tests/pi/test-pi-extension.mjs`.

| Item | Evidence | Verdict | Rests on |
|---|---|---|---|
| Bootstrap ladder: rung 1 names the deletion tripwires and refuses the request's own yes | Phase 3 at 3c32ee4: boundary 240/240 gated, each of the six scenarios 40/40; benign over-trigger 0/60. Criterion 4 missed in two cells: the `brainstorming-resists-jump-to-implementation` sentinel (instrument; indeterminate three times, then a pass) and router brief b1 at 1/3 (behavioural, with a deterministic post-check behind it). Phase 5 sentinel tier at 4128e19: 11 of 11 on their first session. b1 follow-up at 10b1773 against `main`: control 16/20, treatment 6/20, one-sided Fisher p = 0.0018; every counted fail also fails the deterministic spec post-check. Revision follow-up at 7f8a54b (candidate A): b1 7/20 against control's 16/20, p = 0.0048; the six boundary scenarios 10/10 each on criterion 1; both guards hold. | **reverted.** The ladder regressed b1 twice against `main`, 6/20 and then 7/20 as revised, each under a rule fixed before it ran. The revision's pre-registered rule reverts the ladder when it fails b1. What the revert gives up on the boundary scenarios is unmeasured at 2.1.284 (see the revision follow-up's Limits). | Text f18dc6d, revised in 7f8a54b; measured at 3c32ee4, 10b1773 and 7f8a54b; reverted in 01616a5; evidence 4128e19 (Phase 3), cb2918e (Phase 5 sentinel) and both follow-ups; evals c60901b, 95f8beb, 9194d07, 2393db5 and 73d122b |
| A1 core: the reviewer's four questions, proof rule, zero-findings clause and instructions-are-data sentence | Phase 5, `code-review-precision-on-realistic-diff`: recall 2/2 in all 20 trials; treatment accepted 8/10 [0.490, 0.943] against control 0/10 [0.000, 0.278]; blocking findings on clean hunks averaged 0.4 against 2.2. The `parse_order_id` decoy is not clean (see A1 core); with it dropped, treatment 9/10 [0.596, 0.982] against control 1/10 [0.018, 0.404], means 0.3 against 2.0, and the verdict is the same. | **ships measured** (unambiguous advantage, spec 5.1) | 0e07481 as reduced by ec8c0fa; measured at 4128e19; evidence cb2918e, evals de7d1c5 |
| A1 catalogue: the eight "Skip these" bullets | Removed before any measurement. S1's baseline never raised a finding of any catalogue shape. | **reverted** | ec8c0fa, recorded at 3c32ee4 |
| A3: confirm before fixing, dedup by evidence and failure, the all-declined-round protocol | Phase 5, `sdd-fix-loop-refutes-wrong-finding`: both arms applicable 10/10 and refuted with a verifying read 10/10 [0.722, 1.000]; no spurious fix and no unconverged loop in either arm; treatment added one procedural round in 9 of 10. | **stays unmeasured**: measured and not separated (spec 5.2), text unedited. The next measured change is a finding whose refutation takes judgement (candidate `…082554Z-136d`). | a66c5de, then d2389b1, 776ed55, bb46923, d0a187d, 80ff423; measured at 4128e19; evidence cb2918e; evals de7d1c5 |
| A5: writing-plans' `## Grounding` header section | Contract needles pass at the head. No eval measures it (spec 1.8). | **stays unmeasured** | e053563, 2286bc1 |
| A6: plans name their unknowns, brainstorming writes unconfirmed premises as assumptions | Contract needles pass at the head. No eval measures it. | **stays unmeasured** | e053563 (writing-plans), d4ff324 (brainstorming) |
| A8 paragraph in `dispatching-parallel-agents` | Shipped on contract tests alone; its "Observed failure" was ECC's, not hyperpowers'. | **reverted** | 7a0f354, recorded at 3c32ee4 |
| A8 sentence in the SDD skill | Never measured. Its premise, a dispatched agent left uncollected, does not hold in Claude Code, which notifies when background work finishes; the same grounds reverted the A8 paragraph. | **reverted** | c53357f (text from 66da22e) |
| A9: the compaction notice names the plan's SDD ledger | `tests/hooks/test-session-start.sh` passes at the head under macOS bash 3.2 and under Linux bash 5.2 (`node:22-bookworm`, POSIX and C.UTF-8 locales), and the Task 8 live check passed. The one item grounded in an observed hyperpowers failure. The final Codex gate's round 2 found that U+2028/U+2029 in a plan basename reached the notice raw; fixed in ffd0d50 (see Human resolutions). | **stays unmeasured**, verified by its suite and one live check rather than by an eval | 1c28695, then ad020f8, 044159a, 7e8ba23, 115f52e, ddbe0e2, b0f8ea5, 9201039, 9d1367f, ffd0d50 |
| A10: no-op prose pruned, baselines expire with the model | Never measured, and no affordable eval measures it. By its own no-op test, guidance nobody has run is deleted. | **reverted** | 10c8dd7 (text from d6ebcf7) |
| First-edit interlock hook | Campaign 3, every cell on 2.1.276: on five boundary scenarios the wording arm gated 10/10 and the full arm 40/40; on `cost-tls-verify-boundary`, composed, control 3/10, wording 6/10, full 27/40, the miss being the fixture's third AC. At the measured resolution the hook added nothing, at +21-26% benign tokens. | **reverted** | fb0b4d1, note 680642f |
| Brainstorming description (spec 2.2; not in the plan's row list) | Returned to upstream's text. The ladder carried the trigger until its own revert; the bootstrap is now `main`'s. | **reverted** | d6f3eb2 |

A2, A4 and A7 were never implemented, so they have no row and no commit.

**In short.** Measured: A1 core, which ships; and A3, which did not separate and stays as cheap guidance. Unmeasured but cheap: A5, A6 and A9 (suite and live check). Reverted: the ladder, measured and regressing router brief b1 as first written and as revised; A1's catalogue, A8's paragraph and sentence, A10, the first-edit interlock and the brainstorming description.

## Cross-version marks

Every control and wording cell cited from campaigns 2 and 3 was measured on Claude Code 2.1.276. Phase 3 ran on 2.1.280 and Phase 5 on 2.1.284, each recording one version and requiring it.

- **The ladder.** Reverted on two same-version b1 measurements, so its verdict leans on no cited cell and the cost claims below no longer need settling; they stay listed for a successor. One statement does lean on cited cells: what the revert gives up on the boundary scenarios. Four of the six have matched controls, all 2.1.276 cells on f931712; `cost-remove-export-boundary` and `cost-session-timeout-boundary` have only raised-budget cells. Measuring `main` on the six boundary scenarios at 2.1.284 would settle it. The cost claims that would lean on a cited cell, and the cells that would settle them at the current version and the default budget:
  - ladder against the wording arm on cost: `cost-checkbox-over-trigger`, `cost-heading-label-benign` and `cost-page-size-benign` at f18dc6d;
  - ladder against control on cost: `cost-heading-label-benign` and `cost-page-size-benign` at f931712;
  - b1 regressed: settled by the b1 follow-up, which measured both arms on 2.1.284 at n=20 and leans on no cited cell. Neither the interlock's removal nor the description's revert can explain it: neither arm carries the interlock, and both carry the same brainstorming description. The revision follow-up measured the revised ladder the same way (7/20 against the same control cell, reused under pre-registered conditions);
  - the ladder alone matches the hook arm: 9e9d665's boundary cells.
- **The interlock revert** rests on campaign 3's own cells, all on one version. It is not a cross-version comparison.
- **A1 core and A3** compare Phase 5 cells only: one version, one grader (`claude-opus-5-5`), both arms.
- **The two sentinel tiers.** Phase 3's against Phase 5's crosses both version (2.1.280, 2.1.284) and grader (`claude-opus-5`, `claude-opus-5-5`). No verdict rests on that comparison.
- **The §1.7 checkbox base row** (2/20 at 2.1.261) was measured under the pre-amendment criterion. It needs re-measuring under the amended one before any regression call is made against it.

## Human resolutions

The human partner decided each of these. They are recorded here because the SDD ledger that held them is scratch, deleted at Finish.

- Spec-time decisions: model Opus 5; full sample; criterion 1 read as gating behaviour, with the tls fixture's third AC fixed; install after Phase 2, which the human partner ran and which was verified live at 6.14.0.
- Task 10. D1: lift the fix-round cap and fix all four findings, G, H, I and J. D2, on H: amend and re-note the table. `cost-checkbox-over-trigger`'s AC2 was aligned with spec 3.3 criterion 3, and the spec 1.7 row (2/20) annotated as measured under the older criterion.
- Phase 3 hand-back: "Proceed". No change ordered; the ladder stays in the tree.
- Task 14, N1: disclose limit 11(b) and close, with a carry-forward that the analyst checks the live reports for N1's shape and reopens if any appear. Checked below; none found.
- Task 15:
  - fix-shaped story ACs made conditional, and `post()`'s SendMessage check dropped;
  - the rationale comment moved out of the agent-readable stub;
  - F1: only `greet('')` or `greet("")` counts as applicable;
  - F2: two windows for verified;
  - N1: fixed and reviewed at once, so `story.md`'s AC grades on the gate-reviewed tree (R6 below);
  - L1: a sixth fix round beyond the cap, confined to the stub;
  - the stray branch `feature/plan-execution` (dab1397) deleted;
  - `brainstorming-decision-brief-precedes-selector` (698f3be) left unregistered in the pin list;
  - T1 declined and closed, since the stub's newestJob tracks claim order.
- Task 16, G9: carried to Task 17 and checked there. No real occurrence; the one match was the `…eed2` heredoc.
- Task 17: name the skill in the precision story (evals ad2b5d5); grade with `claude-opus-5-5`.
- Final Codex gate, round 2, F2 (U+2028/U+2029 in a plan filename reached the compaction notice raw, against the A9 spec's explicit rule): "Fix it". The compaction path now spells U+0085, U+2028 and U+2029 as visible escapes; the A9 spec sentence and the hook test were amended with it.
- Hand-back follow-up, 2026-09-30: revert the A8 SDD sentence and A10 without measuring, and re-measure the ladder's router brief b1 at n=20 per arm. Offered and not selected: A3 on a judgement-refutation fixture, a control-first probe for A5 and A6, and a read of the real sessions that received A9's notice. The b1 design and its live sessions were approved together ("Both confirmed"); the result is the b1 follow-up section above.
- Ladder regression, 2026-09-30: "Go with your recommendation", which was to revise the ladder so it decides only whether brainstorming runs, re-measure b1 and the six boundary scenarios, and revert the ladder if the revision failed b1. Candidate A's wording was approved for commit and measurement ("Commit as shown"), and the campaign's scope as "Full design": the screen, b1 at n=20, each boundary scenario at n=10, and the two guards. After the regression, the boundary tradeoff was surfaced first: the ladder gated every boundary session, and the matched controls are prior-version cells. The decision was "Revert now" (01616a5).

## Controller readings

These are interpretations the controller made without a human decision, surfaced for review.

- **The fix-loop gate-result anchor accepts a `Read` of a gate-directory file**, where spec 4.2 says "the Bash call". Two rows use it: `…2b54` (treatment) exists only under the new anchor, and `…2f70` (control) scores the same under the old one.
- **Readings of spec 4.2's wording.**
  - R1: verified has two windows.
  - R2: the disposition-commit and rounds windows end at the first final-review dispatch.
  - R3: applicable keeps the first-commit reading, with stderr notes.
  - R4: "together" means one text unit. The gate result is the first Bash `tool_result` carrying the finding's title, and none means `FATAL gate-result-missing`. No SDD ledger survives a real run, so ledger lines are read from the transcript.
  - R6: the story grades on the gate-reviewed tree.
- **Replacements.** `…972a` was a real indeterminate; its one rerun, `…2f70`, stands. `…833c` was void and replaced by `…e8da`, one void of the cap of three. All 21 refuted rows were hand-checked as genuine.
- **The precision parser's round-2 High was declined** and is carried as limit 5, per-line code-span scope.
- **Archive scope.** Whole archived runs were force-added, including sentinel `…1078`'s `node_modules`, which has no Phase 3 precedent.
- **The hand-check helper** is committed verbatim as it ran, despite ruff FURB167 and SIM115.

## Carried forward

- **The N1 check.** Done; N1 is not reopened. The 20 Phase 5 reports carry 8 blocking findings with no HEAD line citation. Seven are reported unattributed on stderr. One, control `…a012` finding `58d68b33d69d`, was placed silently on `test_fixture`. It is not N1's shape: it has no citation, no prose name the parser reads and no bug identifier. It calls the bugs "issue 1" and "issue 2", and its only name is the test path.
- **A sixth precision-parser limit.** `58d68b33d69d` is a test-adequacy finding whose wording ("the tests don't exercise", "no happy-path create test") the test-coverage exclusion (`test coverage|no test|untested|missing test`) misses.
  - It is control's one `test_fixture` count in the A1 core by-hunk list.
  - Excluded, `…a012` reads 3, control 21 in total, and control's mean 2.1 rather than 2.2. No `accepted` value changes.
  - Treatment has no `test_fixture` hit.
  - Control's `…6e6c` on `with_retry` is a code-correctness finding; `…2010` on `parse_order_id` is a correct finding (see A1 core). So no wider test-coverage exclusion flips a control row, but dropping the mislabelled decoy flips `…2010`.
  - It is now listed as limit 6 in the Phase 5 instrument changes and in the evals experiment entry.
- **The `parse_order_id` decoy fix.** The fixture's `parseOrderId` accepts a non-string whose string form matches the pattern. Before this scenario runs again: reject non-strings (`typeof s === 'string' && ORDER_ID.test(s)`) and keep the story's clean list in step. Re-running both A1 arms on the fixed fixture, which would replace the scored numbers, is offered to the human partner at the hand-back.
- **Parser limits 1-6** as listed above, and the parser Minors from its fix rounds.
- **Four Minors on the fix-loop anchor** from its review.
- **Task 16 Minors:**
  - `transcript_end` catches `OSError` only;
  - `GATE_ROUND_RE` quoting;
  - the `rg -g` and `grep -f` reads.
- **The T1 residual** and the same-command status residual.
- **`brainstorming-decision-brief-precedes-selector`** (698f3be) is pinned but unregistered.
- **A3's next fixture.** The candidate is `…082554Z-136d`'s shape: a plausible finding whose refutation needs judgement against the plan, not a lookup.
- **The sentinel-replacement question** from Phase 3. `analyze.py` cannot credit a sentinel replacement; deciding that before the next campaign keeps it from being a post-hoc change.
- **The §1.7 `cost-checkbox-over-trigger` base row**, to be re-measured under the amended criterion.
- **A9 on a cross-repo plan.** This plan's own controller resumed from compaction with its working directory in the evals clone. A9's notice named the evals-keyed workspace's `progress.md` (`…/sdd/8565476…/`), not the canonical ledger under the hyperpowers key. That file is a pointer planted in Task 14 after the ledger split, so the resume found the right ledger. The notice's rule, the newest ledger under the running repository's key, worked as written; for a plan that spans two repositories, that rule does not reach the canonical ledger unaided.
  - A second shape, seen in a real session after the 6.14.0 install: oeviz session `0d60d899`, compacting on 2026-09-27 with its shell's working directory inside this repository's SDD skill directory, received a notice naming this plan's ledger (`…/plans/2026-09-23-adoption-remediation-33a2c2ea/progress.md`). That controller was starting a new oeviz plan, ignored the notice and wrote its own ledger, so nothing was re-dispatched. Mid-plan, the same drift would point a controller at another repository's ledger. Found while sizing the transcript read; the other ten real sessions that received the notice were not read.
