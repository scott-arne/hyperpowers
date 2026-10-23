# SDD Turn Liveness: Eval Evidence

Date: 2026-10-19 (spec and plan). Pre-registered 2026-10-21, before the first
counted run; the commit that adds this file and the hyperpowers-evals commit
that adds the pre-registration are the record.
Skill changed: `subagent-driven-development`. Its SKILL.md gains a turn-end
rule for continuous execution, a tracked-work rule, and foreground waiting
rules for subagents and long commands; four of its dispatch templates and
`requesting-code-review/code-reviewer.md` gain
`run_in_background: false`; its rationalization list gains two entries.
Treatment is `c353fc7`; control is `f1fd935`, tag v6.16.1.
Scenario: `sdd-turn-liveness` (hyperpowers-evals), ten valid runs per arm,
control first.

Spec: `docs/hyperpowers/specs/2026-10-19-sdd-turn-liveness-design.md`.
Plan: `docs/hyperpowers/plans/2026-10-19-sdd-turn-liveness.md`, added with the
spec in `f3700ea` and amended on `main` through `5cbd271`.

**Where the run artifacts live.** Every run, log, manifest and tally this
note cites resolves under the hyperpowers-evals evidence tree,
`evals/evidence/2026-10-19-sdd-turn-liveness/` (branch `sdd-turn-liveness`;
the pre-registration is commit `8fc5d0c93`). Nothing in this note
cites the SDD workspace.

## The pre-registered rules

The verbatim text of both rules, the measure definitions, the void rules and
the adjudication procedure are in that directory's `README.md`, written
before the first counted run. The thresholds, restated:

- **W1:** treatment's pooled foreground dispatch share is at least 0.9.
- **W2:** treatment has at most one live-work turn end across its ten runs.
- **F:** the four-minute covering command ran in the foreground and the
  twelve-minute test was launched as a tracked background job and watched to
  `exit=0`, in at least nine of treatment's ten runs.
- **U:** treatment has no untracked launches.
- **P:** if control has at least one premature stop, treatment's total is
  lower than control's and at least nine of treatment's ten runs have none.
  If control has none, P is unmeasured: the release notes then make no claim
  about premature stops and the question moves to the field rule below.
- **R:** at least seven of treatment's ten runs are successful, and no more
  than one fewer than control's.

The scenario passes when W1, W2, F, U and R hold and P holds or is
unmeasured.

**The field rule.** With at least 100 task boundaries in the after-window,
the Stop-hook follow-up opens if the after rate of premature stops is at
least half the baseline rate; otherwise the field result confirms the change.
The field result is appended to this note and never holds or reverts the
release by itself. The after-window is attributed by time, from the
`plugin-install` worktree's reflog, because the install path carries no
version (plan deviation 1).

The campaign pin that every launch checks is `manifest.tsv` in the same
directory: the evals commit, both arms' commits and roots, model
`claude-opus-5-5` on Vertex, Claude Code 2.1.302 at a fixed path, the allowed
subagent model set, Codex absent, and the task tools on.

## The field baseline

`field/baseline.json`, over the host's Zed SDD sessions from
2026-07-01T00:00:00+00:00 to 2026-10-20T00:00:00+00:00. The window's end is
also the observation cutoff, so records appended later cannot change these
numbers.

| Measure | Baseline |
|---|---|
| Sessions | 14 |
| Task boundaries | 1495 |
| Premature stops | 301, 20.13 per 100 boundaries |
| Premature stops followed by a resume message | 21 |
| Live-work turn ends | 2228 |
| Live-work resumes | 9, 0.6 per 100 boundaries |
| Censored stops, censored resumes | 1424, 144 |
| Excluded turn ends | error 383, interrupt 20, killed 2, reload 71 |

A task boundary is a successful `TaskUpdate` completion, timestamped at its
result. The two `killed` exclusions are turn ends cut by the observation
window, not process kills. Part of the premature count is stops made after
task-list items were left open and never closed later in the session. The
window spans 14 Claude Code versions, 2.1.207 to 2.1.300, and its records
carry five model ids and the `<synthetic>` bucket.

## Scenario results

Both arms ran on 2026-10-22, control first (03:34Z to 06:49Z), treatment
second (17:53Z to 19:42Z), ten valid runs each. Every number here is read
from `evals/evidence/2026-10-19-sdd-turn-liveness/tally.txt`; the full table,
the per-measure verdicts and the limits are that directory's `README.md`
under "Results", and the archived runs are `task-11-runs/control/` (sixteen
run records: ten counted, one capped void, five transport voids) and
`task-12-runs/treatment/` (ten, no voids).

| Measure | Control (v6.16.1) | Treatment (c353fc7) |
|---|---|---|
| Valid runs | 10 | 10 |
| Dispatches, foreground / background | 99 / 33 | 132 / 0 |
| Foreground share | 0.75 | 1.0 |
| Live-work turn ends | 71 | 0 |
| Premature stops (runs with none) | 1 (9) | 1 (9) |
| Both slow-command measures | 0 of 10 | 10 of 10 |
| Untracked launches | 0 | 0 |
| Successful runs | 8 | 9 |

Against the pre-registered rule: **W1** 1.0 against a 0.9 threshold, PASS;
**W2** 0 live-work turn ends against at most one, PASS; **F** 10 of 10
against at least nine, PASS; **U** 0 untracked launches, PASS; **P**
measured, since control has one premature stop, and treatment's 1 is not
lower than control's, FAIL, although 9 of its ten runs have none; **R** 9
successful runs against at least seven and at least control's 8 minus one,
PASS.

**decision: FAIL**, on P alone.

The behavioral separation the change was written for is large and one-sided:
every treatment dispatch ran in the foreground, no treatment turn ended with
work live, and every treatment run ran the four-minute command in the
foreground and watched the twelve-minute one to `exit=0`, against 33
background dispatches and 71 live-work turn ends in control. P still fails,
because the rule needs a strictly lower premature total than a control base
of one and the arms tie at one each. Treatment's single stop is p8
(`…184730Z-c05c`), a run that completed and merged the work but wrote its
last ledger line as `Task 6: soak_long OK (…) ; complete (…)` rather than
the canonical `Task 6: complete`, so its closing report after the merge
counts as a stop before the plan completes and was adjudicated `neither`.
The pre-registered rule was kept rather than relabeled once the decision was
visible. By the spec, the failure goes back to design and the P failure opens
the Stop-hook follow-up with these runs as its evidence.

One limit on that separation: the foreground rule covers dispatches, not the
`SendMessage` resumes a fix round sends, which Claude Code runs in the
background with no foreground option, and only 2 of the 26 archived runs used
one, so W2's zero was measured on an arm that barely exercised that path (the
campaign README's Limits).

Six Corrections were made to the pinned analyzers, each recorded in the
campaign README before the tally it affected: the uncapped transport void
(1), the ledger mark written after a literal `printf` newline (2), the
shell's own escape rules together with the rule that a written grader result
stays a capped void (3), `echo -e` located in the interpreted segment (4),
watch and ledger paths resolved through `cd` and shell variables (5), and the
control flow and segment binding those recognizers needed, which changed no
row in either arm (6).
Correction 5 is why F reads 10 of 10 rather than the first tally's 8: p8 and
p10 had both watched their tracked background job to `exit=0`, p8 naming the
exit file through a shell variable and p10 by name after a `cd`, and the
earlier matcher saw only literal absolute paths. No run was repeated; every
number is recomputed from the archive.

## Release

Release held. The decision of record is FAIL, so 6.17.0 is held. The arms ran
on 2026-10-22 and the hold is recorded on 2026-10-22.

Five criteria passed. W1 passed with a foreground share of 1.0. W2 passed with
0 live-work turn ends in the treatment arm. F passed with 10 treatment runs
that followed the foreground-wait rule. U passed with 0 untracked launches in
the treatment arm. R passed with 8 successful control runs and 9 successful
treatment runs.

P failed. The pre-registered rule requires the treatment arm's premature-stop
total to be lower than the control arm's when control has at least one, and
both arms have one: premature_control is 1 and premature_treatment is 1, with
9 clean treatment runs. The failure rests on one treatment run, p8
(`sdd-turn-liveness-claude-auto-20261022T184730Z-c05c`), whose controller wrote
a non-canonical Task 6 ledger line and whose last turn end came after the
finishing question and the merge. It was adjudicated `neither`. The
pre-registered rule is kept rather than relabeled after the decision was
visible; the campaign README's Results and Limits carry the detail.

By the spec a failure goes back to design, and a P failure opens the Stop-hook
follow-up with these runs as its evidence. The skill text change itself is not
released, and the installed plugin stays at 6.16.1, until that follow-up or a
redesign passes the rule.

## Zed checks

Z1 and Z2 were not run. The release is held on the P failure, and both remain
open prerequisites for 6.17.0 (spec Design §3).
