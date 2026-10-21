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

Filled in by plan Task 12, after the treatment arm runs and the tally decides.

## Release

Filled in by plan Task 13, which prepares the 6.17.0 release candidate or
records the hold.

## Zed checks

Filled in by plan Task 14, which runs Z1 and Z2 with the human partner.
