# SDD Stop Guard: Eval Evidence

Date: 2026-10-23 (spec and plan).
Skill changed: `subagent-driven-development`, which gains a Stop hook (the
stop guard) that finds a session's plan by matching the Stop event's
`session_id` against `session <id>:` lines in the SDD ledger.

Spec: `docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md`.
Plan: `docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md`.

**Where the run artifacts live.** The probe below ran from a throwaway plugin
in the SDD workspace. Its output is quoted in this note; nothing else cites
the workspace.

## Probe

Question: does the Stop event's `session_id` equal `$CLAUDE_CODE_SESSION_ID`
as the session's own Bash tool sees it? The hook's discovery key depends on it.

Command: one headless session with an empty config dir, the probe plugin
(a Stop hook that appends `session_id` beside its own
`$CLAUDE_CODE_SESSION_ID`) and a narrow allowlist:

```
env -u CLAUDE_CODE_SESSION_ID -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT CLAUDE_CONFIG_DIR=<empty dir> \
  claude -p --plugin-dir <probe plugin> --output-format stream-json --verbose \
  --allowedTools='Bash(printenv CLAUDE_CODE_SESSION_ID)' \
  'Run exactly this shell command and reply with its output only: printenv CLAUDE_CODE_SESSION_ID'
```

The allowlist is there because the `-p` permission layer refuses a command
that contains a variable ("A variable in this command can't be checked before
it runs"), so the first attempt, which ran `printf` with
`$CLAUDE_CODE_SESSION_ID`, never produced a shell id. That attempt did show the
Stop hook firing under `-p` (hook and env ids equal) while the shell command
was refused.

Claude Code: 2.1.302. Date: 2026-10-24. This is the run of record: it ran
outside the Bash sandbox, the environment a real hook runs in. The same
command inside the sandbox gave `efa38fbc-b7dd-49ec-ba78-b8d99400143f` for all
three ids as well.

| Id | Value |
|----|-------|
| hook (`session_id` in the Stop payload) | `72cc3565-6224-4818-baa9-5be5404b7993` |
| env (`$CLAUDE_CODE_SESSION_ID` in the hook process) | `72cc3565-6224-4818-baa9-5be5404b7993` |
| shell (the Bash tool's `tool_result`) | `72cc3565-6224-4818-baa9-5be5404b7993` |

All three are equal, so the assumption holds: discovery matches
`session <session_id>:`.

## Process groups (Task 3, deviation 1)

`tracked-job run` gives the command its own process group through bash job
control and keeps the supervisor outside it; `setsid` is not used, so both
stay in the controller's session. The line below is what
`tests/sdd/test-tracked-job.sh` printed on 2026-10-25 when the controller ran
it outside the Bash sandbox (inside it, `ps` is refused and the two
process-identity cases skip): the child leads its own group, the supervisor
sits in another, and `ps -o sess=` reports 0 for both on this host (macOS
prints 0 for a process that is not a session leader).

```
child=51098 pgid=51098 sid=0 run=50973 pgid=34374 sid=0
```

Result: `STATUS: PASSED (0 skipped)`, 20 cases; inside the sandbox,
`STATUS: PASSED (2 skipped)`. That run was at 422d539. The task's fix rounds
added cases and a discriminating assertion (the child is not a session
leader: its `sess` differs from its pid, which fails under `setsid`); the run
at the task's final helper, a9a7396, printed:

```
child=48276 pgid=48276 sid=0 run=48226 pgid=32250 sid=0
```

Result: `STATUS: PASSED (0 skipped)`, 36 cases; inside the sandbox,
`STATUS: PASSED (2 skipped)`.

## The fence on macOS (Task 4, a deviation from Design 2)

The spec names `ps -E` as the reader of another process's environment where
`/proc` is absent. On this host (macOS, Darwin 25.6) it is not one: `ps -E`
prints the environment of the calling process only. Controller probes
outside the Bash sandbox on 2026-10-25, all against a direct child of the
shell with the same uid, returned the child's command line without its
environment under `ps -E -o command= -p`, `ps -eE`, `ps -axE`, with `-ww`,
and for a child started with a two-variable `env -i` environment. The first
unsandboxed run of Task 4's suite failed its lost-job sweep for that reason:
the fenced survivor and the fenceless stranger both counted as skipped.

The human partner chose to keep the sweep working here. A process now
carries a job's fence when its environment holds `TRACKED_JOB_DIR=<jobdir>`
or one of its open descriptors resolves to `<jobdir>/out.log` (every process
of the command's tree inherits stdout and stderr on that file); the readers
are `/proc` (`environ` and `fd/`) where it exists and `lsof -p PID -Fn`
otherwise, the `ps -E` reader is gone, and `can_read_fence` probes a real
child instead of the supervisor's own pid. A process that drops both halves
is fenceless and skipped; a host with neither `/proc` nor lsof degrades a
lost job to `lost-unswept`. The spec text stays as written; this note and the
decision records carry the deviation.

The suite's last unsandboxed run at Task 4's final helper, f560544, printed:

```
child=11280 pgid=11280 sid=0 run=11148 pgid=81830 sid=0
```

Result: `STATUS: PASSED (0 skipped)`, 79 cases; inside the sandbox,
`STATUS: PASSED (16 skipped)`.

## Pre-registered rules

The campaign's rule was fixed before its first counted run, in
`evidence/2026-10-23-sdd-stop-guard/README.md` in hyperpowers-evals (branch
`sdd-stop-guard`). That file carries the criteria verbatim, the measure
definitions as the committed analyzer implements them, the void rules, the
adjudication procedure, the analyzer and hook pins, and the field decision
rule. The thresholds, restated:

- H1 (Correction 9), no off-plan hook line in the plan window, which a run
  whose hook never judged the plan also meets: every valid run's decision
  record holds at least one line, the session's ledger line gives the plan's
  start, and every line from that start until the transcript records
  Finish's result names the plan (`h1`).
- H2, nothing reached the user: the Gauntlet's STOP list has no `neither`
  entry in any valid run, and every allow whose reason is `handback-text`,
  `handback-line` or `cap`, and every `log-failed` allow that displaced one of
  those or a refusal (`open-tasks`, `live-shell`), is adjudicated a genuine
  hand-back.
- H3, no false refusal: every `block` line is adjudicated as not a legitimate
  hand-back, with no exceptions across the ten runs.
- H4, the mechanism holds: pooled foreground dispatch share at least 0.9, no
  untracked launch, both slow commands handled as the rule says in at least
  nine of the ten runs, and no turn end with only a tracked shell live.
- R: at least seven successful runs.

Correction 9 (2026-10-28) restated H1 as above and stopped owing an allow to a
question answered with AskUserQuestion inside its turn; it is recorded under
"Corrections" in the campaign README. The fixture's batched question, asked
that way, writes no decision, so H2's adjudication half and H3 get live cases
only from the turn ends a run takes mid-plan, and may get none. Correction 10
(2026-10-28) times a listed entry that quotes the lead-in Claude Code showed
before an answered AskUserQuestion call as that call's in-turn stop when no
turn end or question quotes it, matching without the markdown the terminal
hides; it was made after the counted runs
were archived and read, moves only the void classification, and is recorded
under "Corrections" in the campaign README.

Adjudicating the `cap` allows, and the `log-failed` allows that displaced a
refusal or a release, is a recorded deviation from the spec, in the direction
of its intent. The spec's H2 names the Gauntlet's STOP list and the hand-back
allows, but that list ends at a done condition the agent's own report
controls. A `cap` allow, the guard giving up after two refusals, is by
construction a stop that reached the human partner, and so is a `log-failed`
allow that displaced `open-tasks`, `live-shell` or `cap`: there the guard had
decided to refuse, or to give up, and the hook's fail-open path released the
stop because the authoritative plan log could not be written. Reading them
from the transcript rather than from the list makes H2 independent of the
driver there, which is stricter than the letter of the spec.

The scenario passes when H1 to H4 and R hold. The ten counted runs are one
arm under one pin; there is no control. Setup, transport and instrument voids
are uncapped, every other void is capped at three, and a Claude Code version
other than the pin restarts the campaign.

The pin that every launch checks is `manifest.tsv` beside that README: the
evals harness at `33523dad5`, the treatment at `4a4f354`, its detached
worktree root, model `claude-opus-5-5` on Vertex, Claude Code 2.1.302 at a
fixed path, the allowed subagent model set, Codex absent, and the task tools
on.

## Benchmark

`tests/hooks/test-sdd-stop-guard.sh` prints four benchmark lines when
`STOP_GUARD_BENCH` is set, each over a fixture of 50 candidate ledgers. The
controller's covering runs of the committed suite printed
`# bench no-plan cold 25 ms`, `# bench no-plan 14 ms`,
`# bench no-plan process 120 ms` and `# bench with-plan 24 ms`. Task 9's runs
on the same host, under load averages 11 to 13, printed cold 163 to 254 ms,
warm 15 to 19 ms and with-plan 21 to 43 ms; its wider sampling put the cold
call anywhere from 24 to 430 ms, the process line at 112 to 371 ms and the
with-plan decision at 26 to 265 ms.

Each line answers a different claim. `# bench no-plan` is the decision itself,
the median of five calls after the first, and it is the number the spec's
100 ms bound is about: 14 ms on the covering run, 15 to 19 ms under load.
`# bench no-plan process` is what a Stop pays end to end, the real wrapper
spawned once with the no-plan payload on stdin, node start-up and module
import included: 120 ms on the covering run. `# bench no-plan cold` is the
first call's cost in a fresh process, the first `cloneKey` git spawn, the JIT
and the first touch of the fifty ledgers; it is the most load-sensitive
reading and is bounded loosely at 1 s. `# bench with-plan` is the decision
that reads a turn from a 300 MB transcript, bounded at 1 s: 24 ms on the
covering run.

## Field baseline

The field rule compares the after-window against the baseline the previous
campaign recorded, re-recorded under Correction 8, which bounds each
qualifying session at its first in-window SDD invocation instead of at the
window's start. The window is 2026-07-01T00:00:00+00:00 to
2026-10-20T00:00:00+00:00 over the host's Zed SDD sessions, and its end is
also the observation cutoff, so records appended later cannot change these
numbers. The column of record is the second one, as
`evals/evidence/2026-10-19-sdd-turn-liveness/field/baseline.txt` records it.

| Measure | Baseline | Before Correction 8 |
|---|---|---|
| Sessions | 14 | 14 |
| Task boundaries | 1434 | 1495 |
| Premature stops | 296, 20.64 per 100 boundaries | 301, 20.13 per 100 boundaries |
| Premature stops followed by a resume message | 21 | 21 |
| Live-work turn ends | 2211 | 2228 |
| Live-work resumes | 9, 0.63 per 100 boundaries | 9, 0.6 per 100 boundaries |
| Censored stops, censored resumes | 1423, 144 | 1424, 144 |
| Excluded turn ends | error 373, interrupt 17, killed 2, reload 69 | error 383, interrupt 20, killed 2, reload 71 |

The after-window gets two measures: the transcript measure as before, and the
hook's own record read by `field_hook.py` over the same cohort. With at least
100 boundaries in the window, the follow-up opens if the after rate of
premature stops reaching the user is at least half 20.64 per 100. The field
result is appended to this note and never holds or reverts the release by
itself.

## Scenario results

The campaign passes its rule, and the ten counted runs never put the guard to
a decision under a plan. `tally.py` prints `decision: PASS` with H1 to H4 and
R true. In every counted run the session ran its plan from the first prompt
to Finish's result inside one turn, both of its turn ends came after Finish
had removed the ledger, and the hook's whole record is two `no-ledger` allows
in the session mirror. `plan_decisions` is 0 in all ten runs, and no receipt
holds a plan log.

The record of these results is in hyperpowers-evals (branch
`sdd-stop-guard`): the campaign README's "Results" section, `tally.txt`, the
eleven attempts archived under
`evidence/2026-10-23-sdd-stop-guard/task-20-runs/treatment/`, and the
experiment entry `docs/experiments/2026-10-23-sdd-stop-guard.md`.

The controller launched eleven attempts on 2026-10-28. The first `p1` ran
inside the command sandbox and is a `void-setup` attempt (quorum's
`git init` refused with "Operation not permitted"), replaced by `r1`. The ten
counted runs (`p2` to `p10` and `r1`) ran outside it from 01:40:44Z to
03:42:46Z, at the pin, and each has quorum's final status and the Gauntlet's
status `pass`. All ten passed the archive's post-check with `finish=yes`, one
receipt, one mirror and the last task's mark. Correction 10 was made after
these runs were archived and read; under the Correction 9 analyzer, six of
them would have read `void-instrument` and been relaunched.

| Criterion | Threshold | Reading | Holds |
|---|---|---|---|
| H1 (Correction 9): no off-plan hook line in the plan window | `h1` in every counted run | `plan_decisions` 0 in 10 of 10; no hook line fell in any run's plan window; `h1` 10 of 10 | yes, with no decision under a plan |
| H2 | no `neither` entry; no allow owing a label labelled `neither` or left unlabelled | 0 of 22 listed entries; no allow owing a label in any run | yes, its adjudication half with no cases |
| H3 | no false or unadjudicated block | no block in any run | yes, with no cases |
| H4 | foreground share at least 0.9; no untracked launch; both slow commands handled in at least 9 runs; no live-shell turn end | 1.0 (132 of 132); 0; 9; 0 | yes |
| R | at least 7 successful runs | 10 | yes |

The runs show that no stop reached the human partner as a `neither` stop on
the Gauntlet's list, and that the mechanism held. Every SDD dispatch ran in the
foreground, every run watched the long soak through `tracked-job wait` to
`status=exited code=0`, no turn ended with only a tracked shell live, and all
ten plans completed with a receipt and a final review. The hook ran at all
twenty turn ends, within a second of each, and answered `no-ledger` after
Finish, which is correct.

The runs do not show any decision the guard makes about a plan. The
refusal of a premature stop (`open-tasks`), the refusal while a tracked shell
is live (`live-shell`), the hand-back allows, the cap, `live-agent` and the
fail-open `log-failed` path did not run in any counted run. H2's adjudication
half and H3 held with no cases, `adjudications.tsv` gained no row, and H1
holds because no hook line fell inside its window. The absence of a premature
stop here belongs to sessions that ran their plans in one turn and cannot be
credited to the hook. Read with H1 as the spec first wrote it
(`plan_decisions >= 1`), all ten runs fail H1 and the campaign is FAIL on H1;
Correction 9 restated H1 after the smoke and after these runs were launched,
before any was archived or tallied.

Every legitimate hand-back in these runs was an AskUserQuestion call answered
inside its turn, which no Stop hook sees. Before Task 1, six runs asked a
separate workspace question and then a combined call carrying the fixture's
`DEFAULT_WINDOW_SECONDS` question, and four asked one combined call with the
workspace or branch question folded in beside it: 16 pre-flight calls, of
which the Gauntlet listed eleven, in seven runs, as in-turn stops. `cc92`
made a third call after its final review, with the ledger live. The
Gauntlet's list omitted the pre-flight questions in three runs that
asked them; nothing on any list was labelled `neither`. F is 9 of 10 because
in `82f7` the first call that names the short soak redirected into a
directory that did not exist yet and never started the soak; the session
reran it in the foreground for 241.8 s, and the rule, which counts every
execution, was applied as written. The uncounted T1 (below) is the only run
of the campaign in which the hook judged a plan. The field rule over the
after-window is where the guard's decisions under a plan will first be
measured.

## T1

T1 is the uncounted run of the `sdd-turn-liveness-fork` copy of the
scenario, with Claude Code's fork mode on, under the campaign pin. No H
criterion is applied to it. The run of record is
`sdd-turn-liveness-fork-claude-auto-20261028T010948Z-93d7`, archived in
hyperpowers-evals at
`evidence/2026-10-23-sdd-stop-guard/task-19-runs/t1/`, and its reading is in
`smoke.md` beside it. The first attempt (`...010556Z-f352`) was launched inside
the command sandbox and is a setup void. The run of record finished, and the
Gauntlet passed it.

None of the 13 SDD dispatches passed `run_in_background`, and every one came
back as an async launch. Fork mode's Agent tool has no such parameter, as the
previous campaign's smoke recorded. Each of the 12 turn ends with work live
drew a `live-agent` allow within a second.

| Count | Value |
|---|---|
| Background dispatches, foreground dispatches | 13, 0 |
| Background dispatches with a completion matched by tool-use id | 13 of 13 |
| `live-agent` allows in the hook log | 12 |
| `live-agent` allows whose tool-use ids name a background agent live at the allow, with a recorded completion | 12 of 12 |
| Other decisions | 2 `no-ledger` allows after Finish's result, no block |

The allow at 01:30:50Z also names the tracked long soak, launched through
`tracked-job run` in a background Bash call. The controller watched it to
`status=exited code=0` in the foreground. The run reads `h1` true, `short_ok`
and `long_ok` true, and `success` true.

One of the Gauntlet's three STOP entries could not be timed under Correction 9.
It quotes the narration Claude Code showed before the pre-flight question (a
`thinking` block), not the AskUserQuestion call's own text. In a counted run,
that entry would have voided the run as an instrument failure; under
Correction 10 it is that call's in-turn stop.

## Zed checks

To be filled in by Task 21.

## Release

To be filled in by Task 22.
