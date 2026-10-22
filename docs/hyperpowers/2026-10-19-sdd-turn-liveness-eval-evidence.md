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
spec in `f3700ea` and amended on `main` through `2266a99` as it ran.

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
window spans 14 Claude Code versions, 2.1.207 to 2.1.300, and six model ids.

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
| Both slow-command measures | 0 of 10 | 8 of 10 |
| Untracked launches | 0 | 0 |
| Successful runs | 8 | 8 |

Against the pre-registered rule: **W1** 1.0 against a 0.9 threshold, PASS;
**W2** 0 live-work turn ends against at most one, PASS; **F** 8 of 10 against
at least nine, FAIL; **U** 0 untracked launches, PASS; **P** measured, since
control has one premature stop, and treatment's 1 is not lower than
control's, FAIL, although 9 of its ten runs have none; **R** 8 successful
runs against at least seven and at least control's 8 minus one, PASS.

**decision: FAIL.**

The behavioral separation the change was written for is large and one-sided:
every treatment dispatch ran in the foreground and no treatment turn ended
with work live, against 33 background dispatches and 71 live-work turn ends
in control. The campaign still fails its own rule. Both F misses are the same
shape: p8 (`…184730Z-c05c`) and p10 (`…184831Z-16ed`) each launched the
twelve-minute test as a tracked background job and watched it in a foreground
call that printed `exit=0` more than 600 s later, p8 through a shell variable
and p10 through a relative path after a `cd`, neither of which the pinned
analyzer pairs to its job. No Correction was made for it: the shape was found
while reading the treatment arm's own results, where changing the instrument
would be post-hoc. The same two runs are treatment's only unsuccessful ones
and the source of its single premature stop, and P in any case rests on one
control event in ten runs, which cannot separate the arms either way.

Four Corrections were made to the pinned analyzers, each recorded in the
campaign README before the tally it affected: the uncapped transport void
(1), the ledger mark written after a literal `printf` newline (2), the
shell's own escape rules together with the rule that a written grader result
stays a capped void (3), and `echo -e` located in the interpreted segment
(4).

## Release

Filled in by plan Task 13, which prepares the 6.17.0 release candidate or
records the hold.

## Zed checks

Filled in by plan Task 14, which runs Z1 and Z2 with the human partner.
