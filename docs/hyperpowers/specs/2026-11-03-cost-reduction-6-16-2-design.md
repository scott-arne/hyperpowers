# Cost reduction: hyperpowers 6.16.2

**Date:** 2026-11-03
**Status:** design approved in chat on 2026-11-03 (base, scope, and the
design with the opus-alias advice removed); spec self-reviewed; Codex spec
review round 1 raised 13 blocking findings across two lenses, all confirmed
and fixed, one by deferring the writing-skills change (pending the human
partner's confirmation); round 2 raised one more (the eval missed a task in
flight at compaction), fixed; round 3 approved (ledger in
`~/.cache/hyperpowers/codex-review/193a951fd4f675975a919be372c5015a95aa0491/run-PcvKUJMv/`).
**Branch:** built from tag `v6.16.1`, not from `main`. `main` carries 350
unreleased commits, including the turn-liveness change that held 6.17.0;
none of that ships here. The changes are merged forward into `main` after
the release.
**Provenance:** the human partner's October 2026 Claude Code bill (Vertex)
was large, and nearly all of it ran in sessions that used hyperpowers
skills. `~/temp/claude-spend/spend.md` estimated spend per project; this
design rests on a second analysis that re-priced every call from the
transcripts (scripts and reports in
`~/.cache/hyperpowers/cost-investigation/`, matching spend.md to 0.5%).

## Problem

Ninety-one percent of the bill is reading and writing cached context, so
cost tracks how large a session's context is on each call, times the number
of calls. Measured over 2026-10-03 to 2026-11-03 (home transcripts):

- Main threads are 67% of spend, at an average context of 422K tokens.
  Claude Code auto-compacts only near 968K on the 1M-window models, so a
  session that runs brainstorming, spec, plan and SDD for one to three weeks
  spends most of its calls between 500K and 968K. Calls above 500K tokens
  are 64% of main-thread cost.
- A replay simulation of the same calls puts an auto-compact window of 400K
  at 28% below actual, 300K at 32%, 200K at 35%. Below 400K the savings
  flatten while compactions keep multiplying.
- After a compaction, Claude Code re-attaches each skill the session invoked,
  cut to its first 20,000 characters, with the note "skill content truncated
  for compaction; use Read on the skill path if you need the full text".
  Nothing in the skills makes the agent take that Read. In v6.16.1:
  - `subagent-driven-development/SKILL.md` is 40,998 characters; the cut
    falls at 21,538, so a compacted controller loses "3. Review the task",
    the fix loop, task completion, risk tiers, Final Review and Finish.
  - `brainstorming/SKILL.md` is 23,551; it loses "After the Design" (spec
    writing, self-review, the spec review, the user review step).
  - `writing-skills/SKILL.md` is 26,121; it loses the RED-GREEN-REFACTOR
    loop, the anti-patterns and the creation checklist.
  Lowering the compaction window makes this truncation more frequent, so it
  has to be fixed before the window is lowered.
- Waiting on Codex costs main-thread calls at controller-sized contexts:
  2,596 `sleep N; status` polls, 725 bare `status` calls and 1,690
  `status <job> --wait` calls in October main threads. `status --wait`
  defaults to a 240 s deadline, so a review of 10-20 minutes takes several
  calls per lens even when the recipe is followed.
- Measured and ruled out: eval sessions (about 1% of spend), hook output,
  individual tool-result sizes (a few hundred tokens on average). The
  one-hour prompt cache saves money: re-pricing with five-minute caching
  gives 56% more, because main threads paused 5-60 minutes 6,700 times and
  each pause would rewrite the whole context.

## Goals

- Make a lower auto-compact window safe for SDD and brainstorming: after any
  compaction, the agent works from their full text.
- Cut the main-thread calls spent waiting on Codex code reviews.
- Record the recommended Claude Code settings and the measurements behind
  them in the README.
- Ship as 6.16.2 from `v6.16.1` without changing any other behavior.

## Non-goals

- The `opus` model alias. The human partner pins it to `claude-opus-5` on
  purpose (less strict bio safeguards for bio research); the README does not
  advise against it.
- writing-skills. It loses its test loop past the cut too, but the
  repository's evaluation rules ask for a full pressure scenario for a
  writing-skills change, and none exists for compaction. Deferred to its own
  change with that scenario. (Approved in chat as part of the design; this
  spec defers it after the Codex spec review; the human partner confirms at
  spec review.)
- How SDD waits on background subagents and tasks (3,411 bare `sleep` polls
  in October). That is the turn-liveness area held out of a release; it
  stays out.
- Codex gate round ceilings, moving gate orchestration into a subagent, and
  restructuring skills to fit under 20,000 characters.
- Settings changes. They follow the release as a separate step (below) and
  live in the human partner's `~/.claude/settings.json`, not in the plugin.

## Global constraints

- All work on a branch from `v6.16.1` in its own worktree; nothing from
  `main` is cherry-picked in.
- Skill text changes follow `hyperpowers:writing-skills` and carry
  before/after eval evidence from multiple sessions (see Testing). Existing
  lines in the two skills stay as they are; the change adds one paragraph
  per skill.
- Gate doc edits are recorded in `tests/codex-review-gate/gate-post-split-edits.tsv`
  and pass `test-assemble-gate.sh` and `test-gate-contract.sh`.
- New shell passes `scripts/lint-shell.sh`.
- Eval run artifacts cited by the evidence note go to
  `evals/evidence/2026-11-03-cost-reduction-6-16-2/` in the evals repository.
- The README states savings as percentages, never the human partner's dollar
  figures. Every commit's staged diff passes
  `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` with
  `hits: 0`.
- No push, no merge into `main` without the human partner's go-ahead.

## Design

### 1. Re-read after compaction

Each of the two skills gets one paragraph at a named anchor well inside the
first 20,000 characters:

- SDD: after the `**Continuous execution:**` paragraph, before
  `## When to Use` (offset about 1,500 in v6.16.1).
- Brainstorming: after the `**REQUIRED SUB-SKILL:**` line, before
  `## Three Paths` (offset about 1,080).

Wording for SDD:

> **After a context compaction:** a re-attached copy of this skill can be
> cut short (Claude Code keeps its first 20,000 characters, which ends
> partway through the task loop). Before resuming work after any
> compaction, Read this file in full, then the ledger, along with any other
> skill you are following whose re-attached copy is cut short.

Brainstorming gets the same paragraph without the ledger clause and with
"which ends before the spec-writing steps". The wording names Claude Code's
limit as a fact and stays usable on other harnesses: an agent whose copy is
complete loses one Read.

Cost: one Read per affected skill per compaction, about 10K tokens for SDD
and 6K for brainstorming, against compactions that each drop hundreds of
thousands of tokens.

### 2. `gate-wait`

New script `skills/requesting-code-review/scripts/gate-wait` (bash, like its
siblings):

    gate-wait [--budget SECONDS] JOB_ID...

- Requires `CODEX_PATH` (the companion location the recipes already use)
  and at least one job id. `SECONDS` is a positive integer from 1 to 570;
  the default 480 keeps one call under the 600000 ms shell timeout, and two
  calls equal today's 16-minute watch cap.
- The loop, until it exits:
  1. Sweep: for every pending id, run the non-blocking
     `node "$CODEX_PATH/scripts/codex-companion.mjs" status <id> --json`
     and read `.job.status`. `completed`, `failed` and `cancelled` are
     terminal and leave the pending set; `queued` and `running` stay.
  2. If nothing is pending, exit 0. If the deadline has passed, exit 2.
  3. Block on the first pending id with
     `status <id> --wait --timeout-ms <min(remaining, 30) * 1000> --json`,
     then go back to the sweep.
  Every exit follows a sweep, so every printed status is current, and a
  stalled first job cannot hide later jobs that finished. These companion
  calls run inside one shell call and cost no model calls.
- Output: one `<id> <status>` line per job, then `all-terminal` (exit 0) or
  `running: <id> ...` (exit 2); on exit 1 for unreadable jobs, a
  `running: <id> ...` line when any are still running, then
  `unreadable: <id> ...`. A budget with leading zeros is read as decimal.
- Exit 0 when every job is terminal, 2 when the budget ran out with jobs
  still running. Exit 1 on a usage error (no `CODEX_PATH`, no ids, a budget
  outside 1-570) or a job it cannot read (companion non-zero exit, or output
  without `.job.status`); for the latter, stderr names the job id and the
  cause, and stdout still lists every other job's last status.
- Like every companion command, it runs outside the shell sandbox.

Agents issue `gate-wait`; `status <job-id> --wait` becomes its internal
primitive. Text changes:

- `recipe-code.md` step 3: block on one `gate-wait` call over the job id,
  shell timeout 600000 ms; on exit 2 issue the next call at once over the
  ids still running. On exit 1 from a usage error, fix the call and re-run.
  On exit 1 for a job it cannot read, run the §4b code-gate recovery for
  that job only (one `status <job-id> --json`; if still unreadable, that
  review is incomplete per §4b, with at most one relaunch if the failure
  looked transient) and keep watching the other ids with `gate-wait`. The
  cap paragraph becomes "2 consecutive `gate-wait` calls (~16 minutes)";
  the incomplete-result handling after the cap is unchanged.
- `gate-lenses.md` line 38: once every lens has a recorded id, one
  `gate-wait` call watches all of them.
- `gate-findings.md`: the code-gate recovery bullet (lines 83-86) names
  `gate-wait` as the watch command, with `result <job-id> --json`
  unchanged; line 99 keeps `status <job-id> --wait --json` as the
  condition-based primitive and says the agent reaches it through
  `gate-wait`; lines 123, 131 and 136 name `gate-wait` where they tell the
  agent what to run. Lines 55-63, which describe companion internals, stay.
- Launch, job-id capture, `result`, `verdict-normalize`, and document gates
  (already sequential foreground calls) are unchanged.

### 3. README: cost and context

A new section after "The Basic Workflow" with:

- What drives cost in a long hyperpowers session (context re-read on every
  call; compaction near 968K by default on 1M-window models).
- Recommended: `"autoCompactWindow": 400000` in `~/.claude/settings.json`
  (or `CLAUDE_CODE_AUTO_COMPACT_WINDOW`), with the simulated savings as
  percentages and why lower values add compactions for little gain.
- Keep `ENABLE_PROMPT_CACHING_1H=1` for long sessions, with the measured
  reason.
- `/clear` between a finished plan and the start of SDD; the spec and plan
  are on disk.
- The 20,000-character re-attach limit and the re-read paragraph.

## Testing

- `gate-wait`: `tests/codex-review-gate/test-gate-wait.sh` against a fake
  companion (a node script that answers `status <id> --json` and
  `status <id> --wait --timeout-ms N --json` from a scripted state file).
  Cases: all jobs finish within the budget (exit 0, `all-terminal`); one job
  still running at the deadline (exit 2, `running:` names only it); the
  first job stalls for the whole budget while later jobs finish (later jobs
  print terminal); a terminal `failed` job (exit 0, status printed);
  malformed JSON and a companion non-zero exit for one job (exit 1, id named
  on stderr, other jobs still listed); missing `CODEX_PATH`, no ids, budgets
  0, 571, -5, 1.5 and `abc` (exit 1); the timeout handed to the blocking
  call never exceeds the remaining budget.
- Gate docs: update the `test-gate-contract.sh` assertion that pins
  "4 consecutive wait cycles", add assertions that pin `gate-wait` in
  recipe-code.md, gate-lenses.md and gate-findings.md, record the edits in
  `gate-post-split-edits.tsv`, and run the offline suite set listed in
  `docs/testing.md`.
- SDD, new eval scenario `sdd-compaction-reread` (evals repository): an SDD
  run over a plan of four small tasks, fixture `.claude/settings.json` with
  `autoCompactWindow: 100000`. A trial is valid when a compaction lands
  after task 1's task review returns and before the final review is
  dispatched; otherwise it is void (instrument failure, per the eval
  void-attempt rule). Outcome checks: every task whose task review had not
  returned when the compaction landed (including a task whose implementer
  was already dispatched or had just returned) gets a task-review dispatch
  after the compaction; the final review and Finish run; no task whose
  review returned before the compaction is dispatched again. Mechanism check: the controller Reads
  `subagent-driven-development/SKILL.md` after the compaction and before its
  next dispatch. Control on `v6.16.1`, treatment on the release branch, 10
  valid trials each unless `evals/docs/scenario-authoring.md` §5 sets a
  different count. Pass bar: the treatment passes all outcome checks in at
  least 8 of 10 valid trials and at least as often as the control, and shows
  the mechanism in at least 8 of 10.
- Brainstorming: the existing `brainstorming-bounded-companion-after-compaction`
  scenario gains a mechanism check (a Read of `brainstorming/SKILL.md` after
  the compaction and before the next question to the human partner). Control
  on `v6.16.1`, treatment on the release branch, 10 valid trials each. Pass
  bar: the treatment's existing outcome checks pass at least as often as the
  control's, and the mechanism shows in at least 8 of 10.
- An evidence note in `docs/hyperpowers/` records both campaigns and cites
  the evals evidence directory.

## Release

1. Worktree on a branch from `v6.16.1`; implement, test, evals.
2. Add a `## 6.16.2 (<date>)` entry to `CHANGELOG.md` describing the three
   changes and the eval results.
3. `/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump patch`
   as a dry run first, then with `-y`; confirm every file vrzn manages reads
   6.16.2; commit.
4. Tag `v6.16.2` locally; check it out in `.worktrees/plugin-install`;
   reload plugins.
5. v6.16.1 predates `decisions-compile`, so the release branch commits its
   spec and plan as v6.16.1's conventions did. When the branch merges
   forward into `main` (where SDD has grown to 58,280 characters and the same
   paragraph goes in after its opening), the merge runs `main`'s
   `decisions-compile` for this spec and removes the plan, as `main`'s
   finishing workflow does. Merging and pushing both wait for the human
   partner's go-ahead.

## After the release

With the human partner's standing approval from 2026-11-03:

- Add `"autoCompactWindow": 400000` to `~/.claude/settings.json`.
- Leave `ENABLE_PROMPT_CACHING_1H=1` and the model pins as they are.
- About two weeks later, re-run the cost scripts over the new window and
  compare against these baselines.

## Decisions

- Base the release on `v6.16.1`, because `main` carries held, unmeasured
  work.
- Keep the one-hour prompt cache; five-minute caching re-prices 56% higher.
- Recommend a 400K auto-compact window; 300K and 200K add 1.5x and 2.6x the
  extra compactions for 4 and 7 more points of savings.
- Fix truncation with a re-read paragraph, not by restructuring skills under
  20,000 characters; restructuring rewrites tuned content and is not needed
  for the read to happen.
- Defer writing-skills until a compaction pressure scenario exists for it.
- `gate-wait` sweeps every job before each blocking slice and keeps the
  16-minute watch cap; it only reduces the number of model calls inside it.
- The opus alias is out of scope by the human partner's choice.

## Assumptions

- Assumption: Claude Code 2.1.317 still re-attaches skills cut at 20,000
  characters (observed on 2.1.300), validate via the compaction attachments
  in the first eval smoke run's transcript.
- Assumption: `autoCompactWindow: 100000` makes a compaction land between
  task 1's review and the final review in a four-task SDD run, validate via
  the first smoke run; if it lands too late, add tasks or larger task
  briefs.
- Assumption: the replay simulation's savings carry over to future use,
  validate via re-running the cost scripts two weeks after the settings
  change.
