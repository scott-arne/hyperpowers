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

The fixture discriminated: the baseline put blocking findings on clean hunks in all ten control trials, 1 to 4 each. So the plan's hardening round, which is owed only when the baseline clears every hunk, did not apply.

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
- **Fix-loop gate-result anchor, evals 4845e14.** Treatment trial `…062515Z-2b54` failed closed with `FATAL gate-result-missing`, although its gate ran. Its controller read the lens capture file with `Read`, not `cat`. Both arms' gate skill says to "read the raw findings text" and leaves the tool open. The anchor now also accepts the first titled result of a `Read` whose path is in the gate directory, and every row anchored this way carries the NOTE `gate-result-via-read`.
  - **This deviates from spec 4.2's literal wording**, "the Bash call whose result carries the finding's title". The controller read the spec's acceptance wording, "the gate result", as the governing text. This is a controller interpretation, surfaced for the human partner's review. Two measured rows use the new anchor. `…062515Z-2b54` (treatment) is the trial that exposed the defect; it has no Bash result carrying the title, so its row exists only under the new anchor. In `…085315Z-2f70` (control), a Bash result carrying the title follows the `Read` five seconds later, and the row scores the same under the old anchor.
  - Codex approved it in round 1 of 5.
- **Refuted rows decided by dispatch text.** A `refuted` disposition can be decided by the controller's own fix-dispatch text, because it pairs `greet.test.js:1-1` with "decline it as REFUTED". That meets spec 4.2's letter, and it predates this change. Every refuted row was therefore checked by hand for a genuine refutation before that point: an implementer or controller statement citing a real `greet.test.js` line other than 1. All 21 rows, the 20 measured and the replaced `…972a`, have one. The record is evals `task-17-runs/measure/refuted-handcheck.md`, with the helper that listed the candidate units.

## The archive

The 40 measured sessions, the two replaced ones, the four smokes and the 11 sentinel sessions are committed in the evals repository at de7d1c5, and that was verified rather than assumed. There are no gitlinks in the index and no path named `.git`. No credential-named file and no key-shaped string appears in any text file in the archived trees or the Phase 5 logs. Re-running both measurement scripts over a scratch copy of the archive, with each `git-dir` renamed back to `.git`, reproduces every row and every stderr line. The archive departs from a byte-exact copy in the same two ways as Phase 3's, both documented in the evidence README: each `coding-agent-workdir/.git` is stored as `git-dir` (and one worktree pointer file as `git-file`), and `.git/hooks/*.sample` is omitted.
