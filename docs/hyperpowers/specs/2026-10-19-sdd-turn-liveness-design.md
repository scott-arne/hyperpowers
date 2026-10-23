# SDD turn liveness: no mid-plan stops, tracked work only, foreground waits

**Date:** 2026-10-19
**Status:** design approved in chat on 2026-10-19 (scope, evidence source,
approach, and the three design sections below); spec self-reviewed; the
Codex spec review ran its four-round ceiling: round 1 raised ten distinct
blocking findings across two lenses (nine fixed, one declined as the human
partner's approved decision with its consequence narrowed), round 2 three,
round 3 two, all fixed; round 4 raised one (the background job's own
timeout), fixed after the last round and not re-reviewed by Codex. Ledger in
the review directory. Awaiting the human partner's review.
**Branch:** hyperpowers `sdd-turn-liveness` off `main` at `f1fd935` (tag
`v6.16.1`); evals `sdd-turn-liveness` off evals `main` at `882844154`.
**Provenance:** BACKLOG entry of 2026-10-13, "Backgrounding and TODO
Lists": in Zed, SDD often makes the session look as if nothing is happening
(no running indicator), and the human partner types "resume" while, as far
as they can tell, the task is still running. A read-only investigation on
2026-10-19 measured the causes. Its throwaway helpers are local; the
classification rules they applied are restated in Design §3 so the committed
field instrument can be built from this spec alone.

## Problem

Three behaviors of the SDD controller make a session look idle when the
plan is not finished, and Zed's integration hides a fourth.

The investigation classified every user message that was exactly
"Resume", "Proceed" or "continue" in the 14 SDD sessions run from Zed
between July and October 2026 (410 messages), by what preceded each one.
The classes are mutually exclusive; the hand-labelled ones are approximate.

| Preceded by | Count |
|---|---|
| An API error, an interrupt or a request timeout (mostly DNS failures resolving the proxy host, often in several sessions at the same minute) | 243 |
| A session reload (the agent's reply "No response requested.") | 59 |
| A genuine hand-back question from the agent | about 40 |
| A premature stop: a status message announcing the next step, then a turn end with no subagent or background command running | about 33 |
| A wait on work Claude Code was not tracking (one of the five was also cut by a restart) | about 5 |
| A turn end while tracked background work was still live | 10 |
| Unclear on hand-labelling | about 20 |

The premature stops read like this one, from a session on 2026-10-09: the
controller marked a task complete, wrote "Tasks 1 and 2 are done; the
fixtures and the inventory that the remaining ten tasks build on are now
both gate-clean. Moving to Task 3.", and ended its turn
(`stop_reason: end_turn`). Nothing was running. The next message was
"Resume", 161 minutes later; the longest such gap was 9.7 hours. Zed showed
the session as idle, which was correct, and the message said the opposite.

The confirmed untracked wait started a Codex review with a trailing `&`
inside a foreground Bash call, which `recipe-code.md` forbids ("not `nohup`,
not a trailing `&`"), then wrote "Gate round 3 running" and ended its turn.
Claude Code never tracked the process, so no completion notice could wake
the controller; the next message came 7.5 hours later.

Terminal and VS Code SDD sessions over the same period show the same kinds
(185 such messages: 124 after API errors, 11 while work was live, premature
stops at a lower rate), so the controller behaviors are not specific to Zed.

Zed adds the fourth case. Zed 1.24.2 runs Claude Code through
`@agentclientprotocol/claude-agent-acp` 0.93.0 over ACP v1, where the
running indicator is the pending `session/prompt` request. Since adapter
v0.59.0 (2026-07-13) a prompt turn stays open while background subagents
spawned during it are live. A background shell never holds a turn open, and
a model cycle Claude Code starts on its own (to deliver a completion notice
when no prompt is pending) reports no running state on v1. Most of the 10
live-work cases were waits on background shells: test suites and Codex
launches.

The task list is not part of the problem: the adapter renders
`TaskCreate`/`TaskUpdate` as Zed plan entries, and these sessions created
tasks and set them in progress and complete.

## Decisions

1. **Scope: turn-ending rules plus foreground waits.** The controller ends
   a turn only when it should, waits only on work the harness tracks, and
   on Claude Code waits in the foreground so the turn stays open. An
   upstream-only report was rejected because it leaves the premature stops,
   the larger cause.
2. **Evidence: a controlled scenario, then a field rerun.** A new quorum
   scenario provides the before-and-after comparison that releases on; a
   rerun of the field classifier after release confirms the real rate.
3. **Mechanism: skill text.** The rules live in the SDD skill text. A
   Claude Code Stop hook that refuses mid-plan turn ends was considered and
   deferred: it works only in Claude Code, can trap legitimate hand-backs or
   a stale ledger, and this repo's earlier first-edit interlock hook was
   removed on 2026-09-23 because measurement showed no gain over the
   wording that shipped beside it, a 21% to 26% token cost on benign
   scenarios, and whole-transcript reads that slow down on large sessions
   (`docs/hyperpowers/2026-09-17-first-edit-interlock-eval-evidence.md`,
   "Reversion"). It becomes a follow-up only under the conditions in Design
   §2 (P) and Design §3 (field decision rule). A controller-run turn-guard
   script was rejected because the controller would still have to choose to
   run it, which is the choice it gets wrong. Codex's independent approach
   proposals converged on the first two approaches and proposed the third.

## Design

### 1. SDD skill text

All changes are in `skills/subagent-driven-development/SKILL.md` and
`skills/subagent-driven-development/common-rationalizations.md`.

**The turn-ending rule** extends the "Continuous execution" paragraph.
While the plan has tasks left, a turn ends in exactly three cases:

- a BLOCKED status the controller cannot resolve;
- a question only the human partner can answer, asked in that message;
- on a harness that cannot wait in the foreground, tracked work still
  running, named in that message.

A message that names the next step is followed by that step's tool call in
the same turn. "Moving to Task 3." followed by a turn end is the failure
this rule exists for. The existing exits (BLOCKED, ambiguity that genuinely
prevents progress, all tasks complete) are kept; the rule makes explicit
that a status message is never an exit.

**Tracked work only.** Anything that outlives one tool call starts through
the harness's tracked background option (`run_in_background` on Claude
Code). A trailing `&`, `nohup`, `setsid`, `disown`, or a script that
detaches a process is forbidden: the harness never reports on such a
process, so nothing wakes the controller when it ends. `recipe-code.md`
already states this for Codex reviews; SDD states it for every command the
controller composes itself.

**Foreground waits on Claude Code** rewrite the "Waiting on dispatched
subagents" paragraph:

- Implementer, task-reviewer, fix-round, re-review and final-reviewer
  subagents are dispatched with `run_in_background: false`. The
  controller's next step always depends on the result, and a foreground
  call keeps the turn open, which is what an editor such as Zed shows as
  working.
- A covering command expected to finish within 10 minutes runs in the
  foreground with an explicit timeout of at least its expected runtime and
  at most 600000 ms.
- A command that may run past 10 minutes starts as a tracked background job
  and is watched in the foreground. Codex reviews already do this with the
  recipe's `status <job-id> --wait --json` loop. A shell job is launched as
  `<command> > <out> 2>&1; echo "exit=$?" > <out>.exit`, so the exit file
  is written whether the command succeeds or fails, and nothing the command
  prints can be mistaken for it. The controller then waits for that file in
  foreground calls of at most 600000 ms each, each call a
  bounded loop that aborts on a non-zero status (the human partner's
  polling rules).
- **Watch budget.** The total watch on one job is three times the plan's
  stated runtime for it, or 60 minutes when the plan states none, capped
  at the harness's maximum background lifetime (7200000 ms on Claude Code).
  The tracked launch sets the job's background timeout explicitly to the
  watch budget, so the harness's default lifetime (1800000 ms on Claude
  Code) never ends a legitimate job before the budget does. The watch
  ends early when the exit file appears, and also when the harness reports
  the job ended without one (a killed process writes no exit file; the
  controller then reads the output and treats the job as failed). When the
  budget is spent with the job still running, the controller stops the job
  through the harness, records the output tail in the ledger, and reports
  BLOCKED, which is a permitted turn end.
- The bounded-stretch guidance stays, for harnesses whose subagents run
  asynchronously; Codex's `wait_agent` already blocks inside the turn, as
  `skills/using-hyperpowers/references/codex-tools.md` describes.

**Two rows in `common-rationalizations.md`:** one for the announced-step
stop ("I've said what's next; I'll pick it up on the next turn"), one for
the detached launch ("A trailing `&` keeps it out of my way"), each with
what actually happens.

Nothing changes in `recipe-code.md` or the other harnesses' reference
files. The four SDD dispatch templates and
`requesting-code-review/code-reviewer.md` carry `run_in_background: false`
at their dispatch lines (plan deviation 11, approved on 2026-10-21 during
Task 9: the smoke showed a controller dispatching without the flag while
SKILL.md alone stated the rule).

**Cost accepted:** a message the human partner types while a foreground
subagent runs is delivered when that call returns, which can be 10 to 30
minutes later; with background dispatch it reaches the controller at once.

Assumption: a foreground Agent call keeps the ACP prompt pending in Zed for
its whole duration, validate via release prerequisite Z1 (Design §3).

Assumption: interrupting a foreground subagent call (Esc) is recoverable by
the existing NEEDS_CONTEXT/BLOCKED handling without losing ledger state,
validate via release prerequisite Z2 (Design §3).

### 2. Evaluation: a quorum scenario

A new scenario, `sdd-turn-liveness`, in the evals repository, with
`quorum_max_time: 150m` set explicitly in its `story.md` frontmatter (the
default limit is far shorter than one SDD run; `sdd-svelte-todo` uses 90m
for a lighter workload).

**Fixture:** a small repository with a plan of six tasks and a design note,
built on the standard library so no package install runs. Two tasks name a
deliberately slow covering command, exact text and runtime stated in the
plan:

- one takes about four minutes: past the Bash tool's two-minute default
  timeout (inviting a background launch) and under the 10-minute foreground
  maximum, so the rule requires a foreground run;
- one takes about twelve minutes: past the foreground maximum, so the rule
  requires a tracked background launch followed by a foreground watch.

Implementer subagents will run these commands too, inside their own
sessions; those calls are not measured. The measured calls are the
controller's: SDD requires the controller to re-run each task's named
covering command itself before acting on the implementer's report
("Subagent Reports Are Claims"), so every compliant run has one
main-session execution of each slow command, at the point after the
implementer reports and before the task reviewer is dispatched.

**Simulated user (story):** give the go-ahead to execute the plan with
SDD; answer real questions briefly; whenever the agent stops without asking
a question or reporting a blocker, reply exactly "continue"; ask the agent
to merge the finished work into the main checkout.

**Measures, per run, from the transcript.** "Live" below means a tracked
background task whose tool result was "Async agent launched" or "Command
running in background with ID" and whose completion has not yet been
recorded.

- *Premature stops:* main-session turn ends (`stop_reason: end_turn`)
  before the plan's last task is marked complete, with no live task at that
  moment, whose message neither asks a question nor reports BLOCKED. The
  question and BLOCKED test is an acceptance criterion in the run's LLM
  verdict, which lists each such turn end; the deterministic part (timing
  and liveness) is computed by the analyzer. The actor's "continue" replies
  are recorded as a cross-check, not as the measure.
- *Foreground dispatch share:* among main-session Agent calls that dispatch
  an SDD role (implementer, reviewer, fix, re-review, final reviewer), the
  share with `run_in_background: false`.
- *Foreground covering runs:* whether the controller's main-session
  execution of the four-minute command ran in a foreground Bash call with a
  timeout of at least its runtime. A run with no main-session execution of
  it fails this measure.
- *Long-job handling:* whether the controller's main-session execution of
  the twelve-minute command started as a tracked background job (not in a
  foreground call and not detached) with an explicit background timeout of
  at least its runtime, and was then watched in main-session foreground
  calls until it finished. A run with no main-session execution of it fails
  this measure.
- *Live-work turn ends:* main-session turn ends with at least one live task
  that later records its completion; each one's duration until that
  completion is the time Zed would show idle.
- *Untracked launches:* a tripwire for detachment anywhere in the run. It
  flags a trailing `&` (not `&&`), `nohup`, `setsid`, `disown`,
  `start_new_session`, `os.setsid` or `os.fork` in a main-session Bash
  command, or in the final content of any file the session created or
  modified (through Write, Edit, or a heredoc or redirect inside a Bash
  command) that a Bash command then executed. The enforcement of the
  tracked-work rule for the fixture's long work is the long-job measure
  (criterion F): a twelve-minute test detached by any means, spelled or
  not, fails it, because its run is neither a tracked background job nor
  watched to completion.
- *Run success:* every plan task completed, the fixture's tests pass on the
  main checkout (not only on a worktree branch), and the final whole-branch
  review was dispatched.

**Arms and comparability.** Control is the hyperpowers 6.16.1 skills tree
(tag `v6.16.1`); treatment is the branch at a recorded commit. One
campaign-wide pin, written into the evidence note before any run, fixes
every shared field for both arms:

- the evals commit, and `evals_clean` true;
- the Claude Code binary path and version;
- the provider and the model (the model the field sessions used,
  `claude-opus-5-5`), for the Coding-Agent and its subagents;
- the clean harness (the evals guide's clean-harness settings in force);
- the Codex mode: absent, so the per-task and final Codex reviews take
  their degrade path in every run.

The only field that differs by arm is the hyperpowers skills tree the run
loaded: its commit (the arm's) and clean. The analyzer reads each run's
recorded provenance and voids a run with any field missing or different
from the campaign pin or its arm's skills tree. If a shared field must
change mid-campaign (a Claude Code update, say), the campaign restarts both
arms under a new pin. Ten valid runs per arm. A run that dies on an API
error or a harness failure is void too, and void runs are replaced under
the evals guide's void rules.

**Decision rule, written into the evidence note before any run.** The
control arm runs first.

- *W1:* treatment's pooled foreground dispatch share is at least 0.9. The
  rule is behavioral and compliance is probabilistic, so the threshold
  tolerates rare misses; control's share is expected near zero under
  Claude Code's background default, so 0.9 separates the arms, and every
  miss is listed in the evidence note.
- *W2:* treatment has at most one live-work turn end across its ten runs,
  on the same reasoning; each one is listed.
- *F:* the four-minute covering command ran in the foreground, and the
  twelve-minute test followed the long-job handling, in at least nine of
  treatment's ten runs.
- *U:* treatment has no untracked launches.
- *P:* if control has at least one premature stop, treatment's total is
  lower than control's and at least nine of treatment's ten runs have none.
  If control has none, P is unmeasured by this scenario: the evidence note
  says so, the release notes make no claim about premature stops, and the
  question moves to the field decision rule in Design §3.
- *R:* at least seven of treatment's ten runs are successful, and the
  number of successful treatment runs is at least control's number minus
  one.

The scenario passes when W1, W2, F, U and R hold and P holds or is
unmeasured. A failure goes back to design; a P failure opens the Stop-hook
follow-up with these runs as its evidence.

Assumption: premature stops reproduce in a short, fresh session, validate
via the control arm's count before the treatment arm runs.

### 3. Field rerun and release

**The field instrument** is committed in the evals evidence directory with
tests on synthetic transcripts. It reads Claude Code transcript files
(JSONL) and applies these rules:

- *Zed session:* the first record carrying `entrypoint` has the value
  `sdk-ts`. *SDD session:* the transcript invokes the
  `subagent-driven-development` skill. *Version:* the hyperpowers version
  in the install path of the skills it loads
  (`.../plugins/cache/hyperpowers/hyperpowers/<version>/skills/...`).
- *Live task:* as in Design §2; a completion is the queue record carrying
  the task's `<tool-use-id>`. A task that never records a completion is
  *censored*: from its launch until the next session reload or the end of
  the transcript, its liveness is unknown, and every turn end and resume
  message in that interval is counted as censored, outside both the
  premature-stop and the live-work counts, and reported separately.
- *Resume message:* a human message whose whole text is "Resume",
  "Proceed", "continue", "go on" or "keep going", case-insensitive.
- *Task boundary:* a `TaskUpdate` call setting status `completed`.
- *Premature stop:* the Design §2 definition, applied to the session's task
  list in place of the plan: an `end_turn` while a task created with
  `TaskCreate` is not yet completed, with no live task and no censored
  interval open, whose assistant text neither asks a question nor reports
  BLOCKED. The field has no LLM verdict, so this test is a heuristic: the
  text contains no `BLOCKED`, its last sentence does not end in "?", and it
  does not ask for approval or a decision. The heuristic is measured
  against a hand-labelled sample in the instrument's tests. The subset whose
  next human message is a resume message is reported beside the total.
- *Live-work resume:* a resume message sent while a task was live that
  later completed.

Only aggregate counts are committed. Transcripts and the text of any
assistant message stay local; the API-error messages contain the proxy
host, which the leak scan forbids.

**Baseline:** the instrument recomputes the investigation's numbers over
SDD sessions that loaded 6.16.1 or earlier and records them in the evidence
note: premature stops per 100 task boundaries, live-work resumes per 100
task boundaries, and live-work turn ends. The implementation plan ends with
the instrument committed and the baseline recorded.

**After-window, a follow-up outside the plan:** the same measures over SDD
sessions that loaded the released version. The window closes three weeks
after release or at ten SDD sessions, whichever comes later, and never later
than six weeks after release. A window that closes with fewer than 100 task
boundaries is reported as low volume and decides nothing. The report
records the Claude Code versions and models seen in each window, since both
change over the same weeks.

**Field decision rule, written into the evidence note before the window
opens.** With at least 100 task boundaries in the window, the Stop-hook
follow-up opens if the after rate of premature stops is at least half the
baseline rate. Otherwise the field result confirms the change. The field
result is appended to the evidence note and never holds or reverts the
release by itself.

**Release prerequisites,** all before 6.17.0 ships:

- the scenario passes (Design §2);
- *Z1:* in one Zed session on the branch, the human partner runs the
  scenario's fixture plan and confirms the running indicator stays on from
  the go-ahead until the controller hands back, with no "resume" needed;
  the session's transcript shows foreground dispatches and no turn end
  before the hand-back;
- *Z2:* in the same or a second Zed session, the human partner presses Esc
  during a foreground implementer; the controller recovers (resumes or
  re-dispatches the task) and the ledger keeps every completed task;
- both results are recorded in the evidence note, without transcript text.

**Release:** a minor release, 6.17.0, because skill behavior changes. The
CHANGELOG entry states the problem and the measured result, makes claims
only for the measures that passed, and points at the evidence note.

## Evaluation

The scenario in Design §2 and the Zed checks in Design §3 are the release
evidence; the field rerun is the confirmation. Offline suites (the
`docs/testing.md` set) stay green on the branch. If an existing offline
suite pins the SDD sections this work edits, its needles are updated with
the new text.

Run artifacts the evidence note cites are copied into
`evals/evidence/2026-10-19-sdd-turn-liveness/` and committed in the evals
repository.

## Files

**hyperpowers**

- `skills/subagent-driven-development/SKILL.md`: the turn-ending rule in
  "Continuous execution"; the tracked-work rule; the rewritten "Waiting on
  dispatched subagents" with the watch budget.
- `skills/subagent-driven-development/common-rationalizations.md`: two
  rows.
- `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md`: the
  evidence note (pre-registered rules, scenario results, Zed checks, the
  field baseline, later the field result).
- `CHANGELOG.md` and the version files (via `vrzn`), at release.

**evals**

- `scenarios/sdd-turn-liveness/` (`story.md`, `setup.sh`, `checks.sh`) and
  its fixture.
- `evidence/2026-10-19-sdd-turn-liveness/`: the pre-registered decision
  rules, the run analyzer and its tests, the field instrument and its tests,
  campaign records and archived runs.

## Constraints

- Skill changes are evaluated before release (repo `CLAUDE.md`, "Skill
  Changes Require Evaluation"); the "your human partner" voice and the
  existing Red Flags and rationalization rows stay as they are apart from
  the two added rows.
- The foreground-dispatch rule is scoped to Claude Code; the turn-ending
  and tracked-work rules apply on every harness.
- No committed file carries the proxy host, the `NO_PROXY` list or the GCP
  project id; transcripts are never committed.
- Plans, specs and evidence notes under `docs/hyperpowers/` are committed
  in this repository.

## Out of scope

- The API errors and session reloads (243 and 59 of the 410 messages):
  network and editor events outside hyperpowers.
- ACP v2 or any change to Zed or claude-agent-acp.
- The Stop hook (Decision 3), unless the evidence calls for it.
- Turn endings in other skills (executing-plans, dispatching-parallel-agents).

## Known limits

- The rules are behavioral; a controller that backgrounds work anyway still
  shows as idle in Zed.
- The scenario is short and fresh; premature stops in the field came from
  long, compacted sessions and may not reproduce (handled by P's
  unmeasured branch and the field decision rule).
- The untracked-launch tripwire reads commands and the files the session
  created or modified; detachment through a spelling outside its list, or
  through a script that already existed in the repository (the fixture has
  none), would not be seen by it. For the fixture's long work, criterion F
  catches detachment by any means; for other short commands it does not.
- The field rerun is confounded by Claude Code and model updates over the
  same weeks; the report records both.
- Messages typed during a foreground subagent are delayed until it returns.
