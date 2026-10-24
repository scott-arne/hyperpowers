# SDD Stop Guard: Design

Date: 2026-10-23. Status: draft for review. This design follows the
sdd-turn-liveness spec (`2026-10-19-sdd-turn-liveness-design.md`), whose
campaign failed its P criterion on 2026-10-22; that spec remains the record
of the skill text now on `main` (unreleased) and of the scenario and field
instruments this design extends. Where the two disagree, this one governs.

## Problem

The turn-liveness campaign separated the mechanism and failed on the
outcome. Treatment ran 132 of 132 subagent dispatches in the foreground
(control 99 of 132), ended no turn with work live (control 71), and handled
both slow commands as the rule says in 10 of 10 runs (control 0 of 10).
Premature stops, the outcome the work exists for, read one per arm: control
one in ten runs, treatment one in ten, and the pre-registered P criterion
required strictly fewer than control.

Three things produced that failure.

- The one treatment stop was a recognizer technicality. Run p8 finished the
  plan and merged the work, but its last ledger line read
  `Task 6: soak_long OK (...) ; complete (...)` rather than
  `Task 6: complete`, so the analyzer never saw the plan complete and
  counted the controller's closing report, written after the merge, as a
  stop before the plan was done.
- The rule had no margin at a control base of one. "Strictly lower" against
  one means perfect, and one mis-read line flips the verdict.
- The scenario has almost no power on premature stops. The field runs about
  20 per 100 task boundaries, in long sessions with compactions, errors and
  resumes; a fresh 50 to 75 minute six-task run produced about one per 60
  boundaries in both arms.

The final Codex gates added three defects in the measured text and one in
the field instrument: the long-job protocol never clears or uniquifies
`<out>.exit`, so a rerun with the same output name reads a stale exit and a
failed test can read as green; fix rounds 1 to 3 resume the implementer
with `SendMessage`, which Claude Code runs in the background with no
foreground option; in fork mode (the default for interactive terminal
Claude Code 2.1.302) the Agent tool has no `run_in_background` parameter at
all; and `field.collect` counts a qualifying session's events from the
window's start rather than from the session's first in-window SDD
invocation (a per-session bound would read 1434 boundaries and 296 stops,
20.64 per 100, against the published 1495, 301 and 20.13).

Prose compliance reached its ceiling and still left a stop in twenty runs.
The previous spec's Decision 3 deferred a Claude Code Stop hook until P
failed. It has.

## Decisions

1. **The release gates on a mechanism guarantee, stated precisely.** A Stop
   hook refuses a turn end it can prove premature: this session's plan is
   unfinished, the last message hands nothing back, nothing tracked is
   live. The guarantee is: such an attempt is refused, and so is an
   immediate second one; a third consecutive attempt is allowed and logged
   as `cap`, and the count starts again after any allow. For a session that
   has a plan (or a receipt of one), every decision is logged with its
   reason, in the plan's log and the session mirror, or in the mirror alone
   when no plan log applies (`ambiguous`, `log-failed`) or the hook itself
   failed (`hook-error`, written by the bash wrapper without node); the one
   unrecorded decision is an allow whose mirror also cannot be written.
   6.17.0 ships when unit tests prove
   that table, the scenario shows no false refusal and no premature stop
   reaching the user, and the mechanism measures hold; the field confirms
   the rate afterwards and never gates a release by itself. The two
   alternatives, releasing on the field rate (three to six weeks per
   candidate, confounded by Claude Code and model updates) and rebuilding
   the scenario to elicit stops (design risk, no guarantee the elicited
   kind is the field's kind), were declined.
2. **The hook fails open with bounded refusals.** It refuses only on a
   confident read; anything unreadable allows, with its reason logged. The
   cap is on consecutive refusals, two, counted per plan log and reset by
   any allow: a bounded loop, never a disarmed guard for the rest of a long
   session. The fail-closed alternative (an explicit permit
   required for every stop) traps sessions on a stale ledger or a hook bug
   and was declined.
3. **One treatment arm, unit tests, and the field.** Ten runs of the
   scenario with the hook installed; the decision table is proven by unit
   tests over crafted transcripts and ledgers, because one stop attempt per
   ten fresh runs cannot exercise it; the hook's marginal value is read from
   its own logs in real sessions. A paired control was declined: at one
   attempt per ten runs it would read one against zero again.
4. **The ledger stays authoritative; helpers write the machine records.**
   The Codex approach gate (2026-10-23, one shot, blind context) converged
   on this shape. Its event-sourced projection (a per-session journal
   reduced to a state file the hook reads with no discovery) is deferred:
   cleaner on the stop path, but a second store to keep consistent with the
   ledger, and ten runs cannot pay for it. Its obligations-and-permits
   protocol is the declined fail-closed posture; two of its parts survive:
   the one-shot hand-back line as the escape hatch, and a completion
   receipt written outside the workspace before Finish removes it.
5. **The guard holds for the whole plan, not only its tasks.** "Unfinished"
   means the ledger exists: `sdd-state finish` removes it, and until then
   the final review, the Codex final gate and the merge are still owed. The
   refusal message says which state the plan is in (tasks open, or all
   tasks complete with the final review and Finish remaining).
6. **`SendMessage` resumes stay, pending Z4.** They keep the implementer's
   context. The hook treats a resumed agent as live work, and whether Zed
   shows that as working is a release check with a written contingency.
   Fork mode is documented, not detected, and gets one terminal smoke run.

## Design

### 1. The Stop hook

**Files.** `hooks/sdd-stop-guard` (bash, extensionless, no heredocs, exits 0
on every path) hands stdin to `hooks/lib/stop-guard.mjs` (node, no
dependencies), which does the work. `hooks/hooks.json` gains:

```json
"Stop": [
  { "hooks": [ { "type": "command",
      "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" sdd-stop-guard",
      "shell": "bash", "timeout": 30 } ] }
]
```

`hooks-codex.json` and `hooks-cursor.json` are unchanged: the hook is
Claude Code only, and the skill text works without it.

**Input.** The Stop event's JSON on stdin: `session_id`, `transcript_path`,
`cwd`, `hook_event_name`, `stop_hook_active`. `stop_hook_active` is
informational: it is logged and never changes a decision (the refusal
count comes from the authoritative log below). Nothing else is read from
the environment except `XDG_CACHE_HOME` and `HOME`.

**Step A, find this session's plan.** Candidates are
`<cache>/hyperpowers/state/<key>/plans/*/progress.md` and
`<cache>/hyperpowers/sdd/<key>/plans/*/progress.md`, where `<key>` is the
clone key of `cwd` derived exactly as `sdd-common.sh`'s `hp_key` derives it
(the physical common git directory hashed with `git hash-object --stdin`);
a contract test asserts the node and bash derivations agree. When `cwd` is
not inside a repository, the candidates are the same globs over every
`<key>`. A candidate matches when it contains a line beginning
`session <session_id>:`. Exactly one match selects the workspace; zero or
several allow the stop with reason `no-ledger` or `ambiguous`. Discovery is
bounded: at most 64 candidate ledgers are opened (newest by modification
time first); past that the decision is `ambiguous`. An `ambiguous`
decision selects no workspace, so it is logged to the session's mirror
only, with `candidates=<n>` and the matching paths; the unit suite covers
both the several-matches and the overflow case. When no ledger matches,
the hook also looks for a receipt of a finished plan that carried this
session (`<cache>/hyperpowers/receipts/*/progress.md`, same test, same
bound): a match means this session ran a plan to Finish, so the decision
(`no-ledger`, with `receipt=<path>`) is still logged to the session's
mirror; a session with neither writes nothing.

**Step B, read the plan's state.** The ledger's first line names the plan
by repo-relative path; it resolves against the toplevel recorded in this
session's line (`at <toplevel>`), then against `git -C <cwd> rev-parse
--show-toplevel`. Total tasks are the plan's `### Task N:` headings;
completed tasks are ledger lines matching the test `sdd-state` uses,
`(^|[^A-Za-z0-9])Task N: complete`. The plan is unfinished while the ledger
exists (Decision 5); the open and total counts are reported in the log and
in the refusal message. An unreadable plan allows with reason `no-plan`.

**Step C, read the current turn from the transcript tail.** The hook reads
`transcript_path` from its end in 512 KB chunks, parsing JSONL records,
until it finds the turn's human prompt: a `user` record that is not a tool
result, not `isMeta`, not a compaction summary (`isCompactSummary` or
`isVisibleInTranscriptOnly`), whose text does not start with
`<task-notification>` or `[Request interrupted`, and that either carries
`origin.kind` `human` or does not start with `<`. The read stops at 16 MB;
a turn longer than that allows with reason `turn-too-long`. From the turn
it takes:

- the prompt's timestamp (millisecond ISO-8601, as the transcript records
  it) and the last assistant text (the concatenated text blocks of the last
  `assistant` record that has any);
- tracked launches, each keyed by its tool-use id: an `Agent` (or `Task`)
  tool use whose result contains `Async agent launched`; a `Bash` tool use
  with `run_in_background` true or whose result contains
  `Command running in background with ID` or `was moved to the background`;
  a `SendMessage` tool use whose result contains `Resuming agent ` or
  `in the background with your message` (the resumed agent's id is kept as
  metadata only);
- completions: `user` records whose text starts with `<task-notification>`
  and whose `<tool-use-id>` names a launch's tool-use id.

A launch in this turn without its completion is live: an agent or resumed
agent is `live-agent`, a shell is `live-shell`. Independently, every
`<workspace>/jobs/*/meta.json` whose `state` is `running` is a live tracked
shell (section 2; `allocated`, `exited`, `lost` and `stopped` jobs are
not), which catches a job started in an earlier turn.

**Step D, decide.** In order:

| Condition | Decision, reason |
|---|---|
| No single matching ledger | allow, `no-ledger` or `ambiguous` |
| Plan unreadable | allow, `no-plan` |
| Turn longer than the cap | allow, `turn-too-long` |
| A tracked subagent or resumed agent is live | allow, `live-agent` |
| A `handback <sid> <UTC-ms>: ...` ledger line whose timestamp is later than this turn's human prompt | allow, `handback-line` |
| The last assistant text asks or blocks (below) | allow, `handback-text` |
| The authoritative log already holds two consecutive refusals for this session since its last allow | allow, `cap` |
| The decision line cannot be written to the authoritative log | allow, `log-failed` |
| Only tracked shells are live | block, `live-shell` |
| Otherwise | block, `open-tasks` |

"Asks or blocks" is the field instrument's heuristic, ported verbatim from
`liveness.asks_or_blocks`: the text contains `BLOCKED`; or its last
sentence, after trailing ` *_`)"'` are stripped, ends in `?`; or its last
three sentences match the approval pattern (`say the word`, `let me know`,
`your call`, `which option`, `do you want`, `would you like`, `shall i`,
`should i`, `want me to`, `approve`, `for your review`, `when you're ready`,
`your go-ahead`, `decision is yours` and the other alternatives of the
instrument's regular expression, case-insensitive). The hook and the
instrument carry the same hand-labelled sample as a test.

A live tracked subagent allows because Zed holds the prompt for background
subagents spawned in the turn (claude-agent-acp 0.59.0 and later) and
Claude Code resumes the controller when the agent ends. A live tracked
shell blocks because a background shell holds nothing in Zed and the skill
says to watch it in the foreground.

**Output.** A block prints `{"decision":"block","reason":"<text>"}` on
stdout and exits 0; the reason is:

> SDD stop guard: plan `<plan path>` is not finished (<state>; nothing
> tracked is live). Take the next step now, in this turn. If you are
> handing back to your human partner (a question only they can answer, a
> BLOCKED report, or they asked you to stop), run
> `scripts/sdd-state handback PLAN_FILE --session <sid> --reason "<why>"`
> and end the turn with that message.

where `<state>` is `<open> of <total> tasks open` or `all <total> tasks
complete; the final review and Finish remain`. For `live-shell` the second
sentence reads "Job(s) `<names>` are still running: watch them in the
foreground with `tracked-job wait`." An allow prints nothing and exits 0.
Any internal error allows, and is recorded without node: when node is
missing, or the module exits non-zero or throws, the bash wrapper appends
one line `{"ts","session","decision":"allow","reason":"hook-error","detail"}`
to the session mirror with `printf` (the session id read from the stdin
JSON by a bash pattern, the time from `date -u`), then exits 0. A session
whose mirror cannot be written either has that allow unrecorded, the same
gap Decision 1 accepts for the double log failure.

**The log and the cap.** `<workspace>/stop-guard.jsonl` is the authoritative
record; each decision is one JSON line appended with a single write in
append mode (the line is built in memory first, so a line is either whole
or absent):
`{"ts","session","decision","reason","plan","open","total","live":[...],`
`"refusals","stop_hook_active","elapsed_ms"}`. `refusals` is the number of
consecutive refusals for this session after this line, and it is zero on
every allow. The cap test merges the trailing lines of the authoritative
log and of the session mirror by timestamp and counts consecutive
refusals from the end, so an allow that exists only in the mirror
(`ambiguous`, `log-failed`, `hook-error`) resets the count like any other;
an unreadable mirror leaves the authoritative log alone to answer. The
count is per plan log (a second plan in the same session has its own) and
resets after any allow, whatever its reason. The hook writes the
authoritative line first, then the same line to the
per-session mirror `<cache>/hyperpowers/stop-guard/<session_id>.jsonl`
(created on first write, never removed by Finish); a failed mirror write
is noted in the next line's `mirror_failed` field and changes nothing
else. If the authoritative line cannot be written, the decision is
`allow`, reason `log-failed`, and the hook tries to write that line to the
mirror; when the mirror write fails too, the allow stands and nothing is
recorded, the one unrecorded decision the design accepts. A session whose
`no-ledger` decision found a receipt logs to the mirror only. Sessions
with neither a ledger nor a receipt write nothing, by design: they are not
SDD sessions.

**Cost bounds** (benchmarked by the unit suite on a fixture of five clone
keys with ten ledgers each, none matching, and one matching ledger; the
measuring host and its numbers are recorded in the evidence note): a
session with no plan decides in under 100 ms; a session with a plan and a
300 MB transcript whose last turn is small decides in under one second.
The hook never opens more than 64 candidate ledgers, never reads more than
16 MB of the transcript, and never reads `out.log` files.

**Assumptions.**
Assumption: the Stop event's `session_id` equals `$CLAUDE_CODE_SESSION_ID`
seen by the controller's shell (the ledger's session line), validate via a
probe hook in a `claude -p` session that prints both, before the hook is
written.
Assumption: Stop hooks fire in Zed (sdk-ts) sessions and a block keeps the
ACP prompt pending, validate via release check Z3.

### 2. The ledger contract and the helpers

The ledger keeps its format and its append-only discipline. Every new kind
of line has one owning helper that writes it under the workspace lock
(`hp_lock`, the same lock `claim` and `finish` hold), a fixed shape, a
status line for every outcome, and a defined failure. Three kinds exist:

| Line | Shape | Writer | On failure |
|---|---|---|---|
| completion | `Task N: complete (commits <base7>..<head7>, review clean)` | `sdd-state complete` | `busy` (exit 3) or `error` (exit 2) with nothing appended; a line appended before a failed snapshot stands and the retry is idempotent |
| hand-back | `handback <sid> <UTC-ms>: <text>` | `sdd-state handback` | `busy` or `error`, nothing appended; the controller retries, and without the line the hook falls back to the text heuristic |
| job, allocation | `job <sid> <UTC-ms>: <name> jobdir=<path>` | `tracked-job new` | the half-made directory is removed, `status=error` (exit 2), nothing appended; a retry allocates a fresh directory |
| job, terminal | `job <sid> <UTC-ms>: <name> exited code=<n>` (or `lost`, `stopped`) | `tracked-job wait`, `tracked-job stop`, once per job (a marker file in the job directory) | the status line is still printed; the ledger append is retried on the next `wait` or `stop` call |

Every helper that writes a line takes `--session SID`; on Claude Code the
flag may be omitted and `hp_session_id` supplies the value.

`<UTC-ms>` is ISO-8601 with milliseconds, produced by node (`new
Date().toISOString()`), because `date` on macOS has no sub-second field;
`<sid>` is `$CLAUDE_CODE_SESSION_ID` on Claude Code and, on a harness
without one, the id the controller generated at Setup and passes as
`--session` (`hp_session_id` supplies the Claude Code value when
`--session` is omitted).

**`scripts/sdd-state complete PLAN_FILE N --commits <base7>..<head7>`** is
idempotent: under the lock it refuses a task number the plan has no
heading for (`status=unknown-task task=N tasks=T`, exit 2), appends the
completion line if no line for task N exists yet, then runs the snapshot,
and prints `status=complete task=N appended=<1|0> snapshot=<sha|plain>`
(exit 0). A failed snapshot prints `status=error` (exit 2) and leaves the
appended line in place; the retry appends nothing and snapshots again, so
the loop "repeat until `status=complete`" always terminates once the
snapshot succeeds. `busy` (exit 3) and `no-workspace` (exit 2) follow the
other subcommands. Ledgers written before this change match the same test.

**`scripts/sdd-state handback PLAN_FILE --reason "<text>" [--session SID]`**
appends the hand-back line under the lock, prints `status=handback`, and
needs no snapshot. The hook honours the line for the current turn only
(its timestamp later than the turn's human prompt, both at millisecond
resolution).

**`scripts/tracked-job`** (in the SDD skill's `scripts/`) owns long
commands. A job's `meta.json` carries an explicit `state`, one of
`allocated`, `running`, `exited`, `lost`, `stopped`; every state change is
an atomic rewrite of `meta.json` (write a temporary file, rename), and the
helper that concludes a job (`run` on exit, `wait` on `lost`, `stop`)
writes the terminal state, so the hook and the analyzer read liveness from
the state, never from the presence of a file. The command runs with
`TRACKED_JOB_DIR=<jobdir>` in its environment, the identity fence the
lost-job path uses. Two steps start a job, so the controller knows the job
before it starts:

- `tracked-job new PLAN_FILE <name> --budget-ms N [--session SID]` runs in
  the foreground. It builds the job directory under a temporary name,
  writes `meta.json` (`name`, `cwd`, `created`, `budget_ms`, `deadline`,
  `session`, `state: allocated`), renames it to
  `<workspace>/jobs/<name>-<UTC>-<rand4>/`, appends the allocation line to
  the ledger under the lock, and prints `jobdir=<path>`. Any failure
  removes the temporary directory and prints `status=error` (exit 2) with
  nothing appended; a retry allocates a fresh directory. A job that stays
  `allocated` (its `run` never started) is not live to the hook, and
  `wait` on it reports `status=not-started` (exit 5) when its bound passes.
- `tracked-job run <jobdir> -- <command...>` is the command the controller
  launches through the harness's tracked background option with the budget
  as its timeout. It is the supervisor and stays outside the command's
  process group. Its launch is a barrier: it claims the job (an atomic
  `mkdir <jobdir>/launch.lock`; a second `run` on the same directory prints
  `status=already-launched`, exit 2, and does nothing), creates a FIFO
  `<jobdir>/go`, starts the child in a new session (`setsid`, so the child
  is the leader of its own process group, whose id is the child's pid)
  where the child's first act is to block reading the FIFO, records the
  child's `pid`, `pgid`, start time (`ps -o lstart=`), `command` and
  `state: running` in `meta.json` atomically, and only then opens the FIFO
  for writing, which lets the child `exec` the command with
  `TRACKED_JOB_DIR=<jobdir>` in its environment. If anything fails before
  the FIFO is opened, `run` sends KILL to the child's group (the command
  never ran), removes `launch.lock`, records `launch_error: <reason>` in
  `meta.json` with the state left `allocated`, prints `status=error` (exit
  2), and a later `run` on the same directory may try again. Once running,
  `run` sends output to `out.log`, polls once a second for a `stop-request`
  file while it waits for the child, and writes the exit status to `exit`
  by writing `exit.tmp` and renaming, whatever the status (a child killed
  by a signal records 128 plus the signal number), then rewrites
  `meta.json` with `state: exited`. On a `stop-request`, or on TERM, INT or
  HUP, `run` signals the child's group (`kill -TERM -<pgid>`), waits five
  seconds, signals KILL, reaps the child, and writes `exit` with the
  signal's status and `state: stopped`; members of the group that survive
  KILL (uninterruptible sleep) are counted in `meta.json` as `survivors`.
  Because `run` is not in that group, it survives its own KILL and records
  the result. Only when `run` itself is killed with KILL is no `exit`
  written.
- `tracked-job wait <jobdir> --max-ms N` (N at most 600000) returns
  `status=exited code=0` (exit 0) on success; `status=exited code=<n>`
  with exit 1 for any other code, so a bounded watch loop aborts on it;
  `status=running` (exit 3) when the bound passes first; `status=lost`
  (exit 4) when `meta.json` is `running`, its pid is not running (or is
  running with a different start time: a reused pid) and no `exit` file
  exists after a two-second grace, in which case `wait` also writes
  `state: lost`; and `status=not-started` (exit 5) for an `allocated` job
  at the bound. On a terminal outcome it appends the job's terminal line to
  the ledger once (a marker file in the job directory makes repeats no-ops
  and a failed append is retried by the next call). It reads files first
  and the process table second (`kill -0`, where EPERM counts as running).
- `tracked-job stop <jobdir>` stops a `running` job through its
  supervisor: it creates `<jobdir>/stop-request` and waits up to ten
  seconds for `exit`; `status=stopped` (exit 0) when it appears,
  `status=stop-timeout` (exit 6) when it does not, leaving the job
  `running` for the controller to retry `stop` or let `wait` decide `lost`.
  While `run` lives, nothing but `run` signals the child's group, and a
  group id cannot be reused while any member of the group lives. On a
  `lost` job (`run` dead, children possibly alive) `stop` cleans up by
  identity, one process at a time, never by group: it lists the processes
  of the recorded `pgid`, and for each one, immediately before TERM and
  again immediately before KILL (five seconds later), reads its environment
  (`ps -E` on macOS, `/proc/<pid>/environ` on Linux) and signals only when
  it carries `TRACKED_JOB_DIR=<this jobdir>`; a process whose environment
  cannot be read, or that lacks the fence, is left alone and counted in
  `skipped`. The residual risk is a pid replaced by an unrelated process
  carrying the same fence value between that read and the signal, a
  window of microseconds and a value no other process sets. It writes
  `state: stopped` with `survivors` and `skipped`, prints `status=stopped`
  or `status=not-running`, and appends the `stopped` job line once. The
  skill requires `stop` after every `lost`, so a lost job's survivors are
  always swept before the failure is handled.

Codex reviews keep the companion's own `status --wait --json` loop and do
not use `tracked-job`.

**Snapshots and the receipt.** `sdd-state snapshot` commits
`stop-guard.jsonl`, `jobs/*/meta.json` and `jobs/*/exit` beside the ledger,
reports and claims; `out.log` is ignored like briefs and packages. Before
`sdd-state finish` removes the workspace it writes the receipt,
`<cache>/hyperpowers/receipts/<workspace name>-<UTC>/`: `progress.md` is
required; `stop-guard.jsonl` and every `jobs/*/meta.json` and `jobs/*/exit`
are copied when they exist and are simply absent otherwise (a session with
the hook disabled, a plan that reached Finish without a Stop event, a job
only allocated, a lost job with no `exit`). The receipt is built under a
temporary name and renamed into place, so a partial receipt never exists;
`finish` prints `receipt=<path>` beside `last=`. A finish whose receipt
cannot be built (the ledger missing or unreadable, an existing file that
fails to copy, the rename refused) stops with `status=error` before
anything is removed. The receipt is the durable completion record the
analyzer and the field read; it is never removed automatically, and
`sdd-state prune --receipts --days N` lists and removes old receipts only
when asked.

### 3. The skill text

All edits are in `skills/subagent-driven-development/SKILL.md` and
`common-rationalizations.md`. The dispatch templates,
`requesting-code-review/code-reviewer.md`, `recipe-code.md` and the other
harness references are unchanged.

- **Complete the task** (section 5 of The Task Loop) replaces "append the
  completion line ... then snapshot" with: run
  `scripts/sdd-state complete PLAN_FILE N --commits <base7>..<head7>` and
  repeat it until it prints `status=complete`; that line is the
  completion's durable record. The Setup paragraph that names the snapshot
  cadence points at this.
- **Continuous execution** keeps the three permitted turn ends and adds the
  record: each of them, and "your human partner asked you to stop", is
  written with `scripts/sdd-state handback PLAN_FILE --reason "<why>"`
  (with `--session <sid>` on a harness without `CLAUDE_CODE_SESSION_ID`) in
  the same message that ends the turn. It quotes the hook's refusal
  message and says what it means: on Claude Code the SDD stop guard refuses
  a turn end it can prove is premature, two consecutive attempts per plan,
  the count resetting after any allow; when you meet that message, take
  the next step; writing a question you do not need
  answered to get past it is the stop it exists to prevent, and the log
  records it.
- **Waiting on subagents and long commands** rewrites the long-command
  bullet around the helper: allocate the job in the foreground with
  `scripts/tracked-job new PLAN_FILE <name> --budget-ms <budget>`, launch
  `scripts/tracked-job run <jobdir> -- <command>` through the tracked
  background option with the budget as its timeout, then watch it in the
  foreground with repeated `scripts/tracked-job wait <jobdir> --max-ms 600000`
  calls: `exited code=0` is success; any other `exited` code is a failed
  command, handled as that command's failure (a failed test is a fix round,
  a failed covering command a failed task); on `lost`, run
  `tracked-job stop <jobdir>` first, so the job's survivors are swept, then
  treat the job as failed; a spent budget runs `tracked-job stop`, records
  the `out.log` tail, and reports BLOCKED. The watch-budget arithmetic
  (three times the plan's stated
  runtime, 60 minutes when none, capped at 7200000 ms) is unchanged.
- **Rounds 1 to 3** keep the `SendMessage` resume and add: on Claude Code
  the resumed agent runs in the background, the stop guard treats it as
  live work, and your turn may end while it runs; its completion notice
  resumes you.
- **Dispatch** gains one sentence: where the Agent tool offers
  `run_in_background`, dispatch with it false; where it does not (fork mode
  in an interactive terminal), dispatches run in the background and the
  stop guard treats them as live work.
- **Finish** records the `receipt=<path>` line `sdd-state finish` prints
  beside `last=`.
- **`common-rationalizations.md`** gains one row: "The hook blocked me, so
  I'll ask a question to get out" against "A question you do not need
  answered is a premature stop with extra steps; the log records every
  allow and the field reads it."

`tests/sdd/test-sdd-contract.sh` pins the helper invocations (`complete`,
`handback`, `new`, `run`, `wait`, `stop`), the `code=0` success rule, the
`lost` cleanup sentence, the quoted refusal message, the cap wording ("two
consecutive attempts per plan, the count resetting after any allow"), the
fork-mode sentence and the new row, and drops the two needles for the
hand-written exit-file protocol.

### 4. Evaluation

**Unit tests, the decision table.** `hooks/lib/stop-guard.test.mjs` (run by
`tests/hooks/test-sdd-stop-guard.sh` with `node --test`) builds ledgers,
plans, receipts and transcript files in a temporary cache root and asserts
decision, reason and log line for: no ledger and no receipt (allow,
nothing written anywhere); two ledgers carrying the session; 65 candidate
ledgers (`ambiguous`); a receipt only (`no-ledger`, logged to the mirror
only); open tasks with a status message ("Moving to
Task 3."); with a question; with BLOCKED; with a hand-back line written
after the prompt; with a hand-back line written before it, including one
in the same second; all tasks complete, ledger present (block, the
"final review and Finish remain" state); a live tracked subagent; a live
`SendMessage` resume whose completion notice names the `SendMessage`
tool-use id (not live after it); a live tracked shell in the transcript; a
live job seen only through `jobs/*/meta.json`; a job with an `exit` file
(not live); the first and second refusals (block) and the third attempt
(`cap`), with `stop_hook_active` true on the second and third; the
sequence block, block, cap, block, block, cap (the count resets after the
cap); block, then a hand-back allow, then block, block (the count resets
after the hand-back); two plans in one session, each with its own count;
an unwritable authoritative log (`log-failed`, written to the mirror); an
unwritable authoritative log and mirror together (allow, nothing
recorded); a failed mirror write alone (`mirror_failed` on the next
line); block, block, then a mirror-only allow (`ambiguous`, and separately
`log-failed`), then block (a refusal, not `cap`); node absent from `PATH`
(the wrapper writes `hook-error` to the mirror and exits 0); the module
made to throw through a fault-injection variable (`hook-error`, exit 0);
an unreadable plan; a turn past the
16 MB cap; a transcript whose last human prompt carries `origin.kind`
`human` and starts with `<`. The hand-labelled sample behind
`asks_or_blocks` runs against the port. The benchmark fixture of section 1
asserts the two latency bounds and records the host. The key derivation is
compared with `hp_key` on a temporary repository.

**Helper tests.** `tests/sdd/test-tracked-job.sh`: two `new` calls under one
name make two directories; a `new` whose ledger append fails (the lock
held by another process past the wait) leaves no directory and appends
nothing; a second `run` on one directory is `already-launched` and
changes `meta.json` not at all; a `run` whose metadata write fails
(fault-injected before the barrier opens) kills the waiting child, leaves
the state `allocated` with `launch_error`, removes the launch lock, and a
later `run` succeeds; a TERM-resistant command (one that traps TERM) is
ended by the KILL escalation and `run` records `exit` 137 and
`state: stopped` while `run` itself survives; `stop` on a job whose
supervisor does not answer within ten seconds reports `stop-timeout` and
leaves the state `running`; a failing command writes `exit` with its
code and `wait` exits 1 with `code=<n>`; a command killed by a signal
records 128 plus the signal; `wait` returns `running` within its bound
while the command runs and `exited code=0` after, and `not-started` for a
job never run; `run` killed with KILL yields `lost`; a reused pid (a
different start time) yields `lost`; `stop` on a live job goes through the
supervisor and ends the command and its children (a command that spawns a
sleeping child); `stop` on a lost job whose recorded leader has a
different start time sends nothing and prints `not-running`; `stop` on a
lost job whose `run` was killed with KILL finds the surviving child by its
`TRACKED_JOB_DIR` fence and ends it, and leaves a process in the recorded
group without the fence alone; `wait` writes `state: lost` and the hook
then reads the job as not live; `stop` on a finished job is `not-running`;
the job lines appear in the ledger exactly once even when `wait` is called
repeatedly. `tests/sdd/test-sdd-state-finish-receipt.sh` also covers a
finish with no hook log and no jobs, and one with an allocated and a lost
job. `tests/sdd/test-sdd-state-complete.sh`: the canonical
line, `appended=1` then `appended=0`, the snapshot, `unknown-task`, a
fault-injected snapshot failure followed by a successful retry, and
`handback`'s line shape with a millisecond timestamp.
`tests/sdd/test-sdd-state-finish-receipt.sh`: `finish` writes the receipt
before removing the workspace and stops on a failed copy.
`tests/hooks/test-no-heredocs-in-hooks.sh` covers the new hook file.

**The scenario.** `sdd-turn-liveness` runs with one fixture change: the
plan carries one deliberate conflict between two tasks' values for the
same constant, so the pre-flight scan must surface it as the batched
question, and the story gains the scripted answer naming which task
governs. Every run therefore contains one legitimate mid-plan hand-back,
which exercises the allow path live and gives H2 and H3 a real case per
run. `# claude-env:` stays (task tools on, fork mode off). One smoke, then
ten valid runs with the plugin at the treatment commit, under the previous
campaign's void rules, pin keys and adjudication procedure. Pre-registered
in the evals README before the first counted run:

The decision record of a run is the union of the receipt's
`stop-guard.jsonl` (authoritative for every decision taken while the plan
existed, where all refusals happen) and the per-session mirror (the only
record of decisions after Finish), keyed by timestamp and session; a line
present in one and not the other is kept, and `mirror_failed` marks are
reported. The record is reconciled against the Gauntlet's STOP list:
every listed mid-plan stop must correspond to an `allow` decision within
its minute; a listed stop with no decision means the instrument lost a
line, and that run is `void-instrument`, outside the cap like a setup void,
and relaunched.

- **H1, the hook ran:** every valid run's decision record holds at least
  one line for the plan (the pre-flight question guarantees one before
  Finish).
- **H2, nothing reached the user:** the Gauntlet's STOP list has no
  `neither` entry in any valid run, and every `allow` whose reason is
  `handback-text` or `handback-line` is adjudicated a genuine hand-back
  (the hand labels in `adjudications.tsv`, as before).
- **H3, no false refusal:** every `block` line in the receipt's log is
  adjudicated as not a legitimate hand-back; zero exceptions across the
  ten runs.
- **H4, the mechanism holds:** pooled foreground dispatch share at least
  0.9; no untracked launch; both slow commands handled as the rule says in
  at least nine runs (the short one in the foreground, the long one through
  `tracked-job` and watched to `exited code=0`); no turn end with only a
  tracked shell live.
- **R:** at least seven successful runs.

The scenario passes when H1 to H4 and R hold. The analyzer reads
completion and jobs from the run's receipt (or, for a run that never
reached Finish, from the archived workspace), decisions from the union
above, and the transcript only for dispatches and launches; the
shell-command recognizers for ledger marks retire. Its tests include a
run whose mirror lost a middle line and one whose mirror lost its final
line (both recovered from the receipt), a post-Finish decision present in
the mirror only, and a listed stop with no decision (`void-instrument`).
Analyzer pins and the Corrections convention carry over.

**Terminal fork-mode smoke (T1), one uncounted run before release:** the
scenario launched with fork mode on (no `CLAUDE_CODE_FORK_SUBAGENT=0`), to
see real fork-mode launch and completion records: dispatches run in the
background, the hook logs `live-agent` allows, and completions are
correlated by tool-use id. Its record goes in the evidence directory.

**Zed checks, manual, before release:** Z1, a foreground Agent call keeps
the prompt pending for its whole duration; Z2, Esc on a foreground
subagent is recoverable through NEEDS_CONTEXT/BLOCKED without ledger loss;
Z3, the Stop hook fires in a Zed session and a block keeps the prompt
pending and the controller continuing; Z4, a `SendMessage`-resumed agent
keeps the prompt pending. **Contingency for Z4:** if it fails, rounds 1 to
3 dispatch a fresh implementer with `run_in_background: false` on Claude
Code (the brief path, the report path and the findings; the takeover path
that already exists), the contract test needle moves, and the ten runs are
repeated at the new commit before release.

### 5. The field

**Correction 8, before any after-window.** `field.collect` bounds each
qualifying session's measurement at its first in-window SDD invocation,
keeping earlier records for state reconstruction, with a regression test
(a session with task events before its first in-window invocation
contributes nothing from them). The baseline is re-recorded under that
instrument with `run-baseline.sh`'s two-run agreement check; the expected
reading is 14 sessions, 1434 boundaries, 296 premature stops, 20.64 per
100, 21 followed by a resume, 2211 live-work turn ends, 9 live-work
resumes. The campaign README's Corrections list, baseline table and
Question section, the experiment entry and the hyperpowers note's table
change together, with the superseded numbers kept beside them.

**Two measures over the after-window.** The transcript measure as before
(premature stops per 100 boundaries, live-work resumes, Claude Code
versions and models seen), and the hook's record read from
`<cache>/hyperpowers/stop-guard/<sid>.jsonl` for the same sessions:
blocks per 100 boundaries, allows by reason, and `cap` and `log-failed`
events. The decision rule keeps its shape: with at least 100 boundaries,
the follow-up opens if the after rate of premature stops reaching the user
is at least half the corrected baseline; `cap` events and heuristic allows
that the transcript measure scores as premature are listed beside it as the
hook's misses. The window is attributed by the plugin-install reflog as
before.

### 6. Release

6.17.0 ships when: the unit and helper suites pass; the contract suite
passes; the scenario passes H1 to H4 and R; T1 ran; Z1 to Z4 pass (or Z4's
contingency has shipped and been re-measured). The release notes claim the
mechanism (foreground waits, tracked work) and the guard in its precise
form: on Claude Code, a turn that would end mid-plan with nothing tracked
live is refused, and so is an immediate second attempt; a third
consecutive attempt is allowed and logged; every decision for a session
with a plan is logged with its reason unless the log itself cannot be
written; each claim carries the number that backs it. The hyperpowers
evidence note is pre-registered before the first counted run; run
artifacts live in hyperpowers-evals under `evidence/2026-10-23-sdd-stop-guard/`.

## Files

hyperpowers: `hooks/hooks.json`, `hooks/sdd-stop-guard`,
`hooks/lib/stop-guard.mjs`, `hooks/lib/stop-guard.test.mjs`,
`skills/subagent-driven-development/SKILL.md`,
`skills/subagent-driven-development/common-rationalizations.md`,
`skills/subagent-driven-development/scripts/sdd-state` (`complete`,
`handback`, the snapshot set, `finish`'s receipt, `prune --receipts`),
`skills/subagent-driven-development/scripts/tracked-job`,
`tests/hooks/test-sdd-stop-guard.sh`, `tests/sdd/test-tracked-job.sh`,
`tests/sdd/test-sdd-state-complete.sh`,
`tests/sdd/test-sdd-state-finish-receipt.sh`, `tests/sdd/test-sdd-contract.sh`,
`docs/testing.md`, `CHANGELOG.md` and the version files at release, the
evidence note `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md`.

hyperpowers-evals: `evidence/2026-10-23-sdd-stop-guard/` (README with the
pre-registration, analyzers adapted from the 2026-10-19 directory, launch
tooling, archives, tally), `scenarios/sdd-turn-liveness/story.md` and the
fixture plan (the deliberate conflict and its scripted answer),
`evidence/2026-10-19-sdd-turn-liveness/field.py` and its tests and README
(Correction 8), `docs/experiments/` entry.

## Constraints

- Hooks: bash wrapper plus node module, no third-party packages, no
  heredocs, exit 0 on every path, explicit 30 s timeout, no whole-transcript
  reads (16 MB cap), at most 64 candidate ledgers, no reads of `out.log`.
- Claude Code only for the hook; every skill path works with the hook
  absent or disabled.
- The ledger format is unchanged; new lines are appended by their owning
  helpers under the workspace lock; `finish`'s `open-claims` test is
  unchanged.
- Measurement is pre-registered before the first counted run; analyzer
  changes after that are numbered Corrections recorded before the tally
  they affect; archives are post-checked at their task; nothing is pushed
  without the human partner's request; merges of the evals branch are never
  squashed.
- Skill text changes carry evidence: the unit matrix, the ten runs, T1 and
  the Zed checks.

## Out of scope

- Turn endings in other skills (executing-plans,
  dispatching-parallel-agents).
- `SubagentStop`; hooks for Codex, Cursor or other harnesses.
- ACP v2 or changes to Zed or claude-agent-acp.
- API errors and session reloads.
- The event-sourced projection (Decision 4), unless the field logs argue
  for policy the ledger read cannot carry.

## Known limits

- The guarantee is two consecutive refusals, then an allow logged as
  `cap`, and the count resets after any allow; a controller that stops
  three times in a row with nothing live gets through, visibly, and can do
  so again later in the session, each time visibly.
- A session whose plan log and mirror both cannot be written, or whose
  hook failed and whose mirror cannot be written, has that allow
  unrecorded; the next writable decision carries `mirror_failed` only for
  the mirror, so a lost line is inferred from the gap.
- When `run` has been killed with KILL, `stop` sweeps the recorded group's
  processes one at a time by the `TRACKED_JOB_DIR` fence, re-read before
  each signal; a pid replaced by a process carrying the same fence value
  inside that window is the residual risk, confined to jobs already in the
  `lost` state; processes whose environment cannot be read are skipped and
  counted.
- The hook reads the current turn only; a tracked agent launched in an
  earlier turn and still live is not seen through the transcript (a job is,
  through `jobs/`), so a stop that waits on such an agent needs the
  hand-back line, which the refusal message names.
- The hand-back heuristic can be satisfied by a question the controller
  does not need answered; the log records it and the field counts it.
- An SDD session that never wrote its session line is invisible to the
  hook (Setup requires the line; the contract test pins it).
- Fork-mode terminal sessions end turns with live background subagents and
  show the terminal's own indicator, not a held turn.
- Messages typed during a foreground subagent are delayed until it returns.
- The field measure is confounded by Claude Code and model updates over the
  window; both are recorded.
