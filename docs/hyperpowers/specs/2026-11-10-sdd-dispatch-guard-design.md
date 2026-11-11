# SDD Dispatch Guard: Design

**Outcome:** implemented 2026-11-11; 9 decisions under docs/hyperpowers/decisions/.

Date: 2026-11-10. Status: draft for review. This design follows the
sdd-stop-guard spec (`2026-10-23-sdd-stop-guard-design.md`), whose Z4
contingency put the foreground fix-round rule into the SDD skill. It adds a
hook that enforces the rule; it changes neither the stop guard nor the skill
text.

## Problem

Zed showed an SDD session idle while its implementer ran. In session
ec562ba3 (plan `2026-11-09-sweep-open-findings.md`, plugin v6.17.0, Zed's
claude-agent-acp 0.101.0) the controller dispatched the Task 5 reviewer with
`run_in_background: true` at 17:47Z, sent the Task 5 fix round to the
existing implementer with `SendMessage` at 18:02:30Z, and ended its turn at
18:02:37Z. The stop guard allowed that turn end as `live-agent`, which is
its design. Claude Code runs a `SendMessage` resume in the background, and
Z4 (2026-11-05) already measured that Zed shows no open turn while a
resumed agent works.

The skill forbids both calls on this harness: line 406 of SKILL.md on
`main` puts every implementer, reviewer, fix-round and re-review dispatch in
the foreground, and line 636 makes a fix round on Claude Code a fresh
foreground implementer. The controller no longer had those lines. After a
compaction Claude Code re-attaches an invoked skill cut to its first 20,000
characters; SKILL.md is 75,902 characters on `main` (64,909 at v6.17.0), and
the dispatch rules start at characters 26,705, 36,201 and 44,776 of the
installed copy. The session compacted at 04:08, 07:20 and 16:55Z on
2026-11-10; every re-attached copy was exactly 20,000 characters and none
contained `run_in_background: false`. Before 16:55 every `Agent` dispatch
that day was in the foreground; the day's two `SendMessage` resumes came at
07:22 and 18:02, each among the first dispatches after a compaction.

The paragraph that should cover this case survives the cut: line 23 tells
the controller to Read the whole file after every compaction. The field
does not follow it. Across the 10 SDD sessions with compactions since
2026-11-04 (all in Zed), 63 compactions were followed by a dispatch; the
controller read SKILL.md in full before that dispatch after 16, read part
of it after 13, and did not open it after 34. The 6.16.2 eval measured 98%
(148 of 151) for the same paragraph, so its scenario does not reproduce
long field sessions. Measurement scripts and output:
`~/.cache/hyperpowers/zed-idle-2026-11-10/`.

In the other sessions, the first dispatch after a compaction was a
`SendMessage` resume five times and a background `Agent` call once (go-skz,
the c3 marketing site, predict-before-structure). Whether each fell inside
a plan is for the field replay below to settle.

## Decisions

1. **A PreToolUse dispatch guard enforces the foreground rule.** A hook
   refuses the two calls that end an SDD turn while a subagent works, at the
   moment the controller makes them, whatever survived the last compaction.
   Rejected: stronger text (the rule repeated in the compaction notice and in
   SKILL.md's first 20,000 characters), because it still depends on the
   controller following text after a compaction, which is the failure the
   field shows, and it is a tuned-skill edit with its own eval; a stop-guard
   refusal of a `live-agent` turn end, because by then the agent already runs
   in the background, the controller has no foreground wait for it, and a
   refusal produces polling up to the refusal cap.

2. **This slice fixes turn liveness; the compaction loss is the next slice.**
   The field re-read rate (16 of 63) means every SKILL.md rule past character
   20,000 is mostly unfollowed after a compaction, not only the dispatch
   rules. That gets its own design, whose first task is an eval that
   reproduces the field rate (human partner, 2026-11-10). Rejected: one
   larger slice, because the Zed symptom has a fix that needs no compliance
   while the re-read problem cannot be measured until its eval exists.

3. **It refuses a background `Agent` call and a resume of the session's own
   subagent, for the whole plan.** The refusal applies while this session has
   a plan ledger, including the final review and its fix wave, until Finish
   leaves a receipt, matching the stop guard's "the guard holds for the whole
   plan, not only its tasks". A `SendMessage` counts only when its `to` names
   an agent id this session's own `Agent` results recorded; a message to
   another session or a teammate passes. Rejected: refusing every
   `SendMessage`, because `SendMessage` also reaches other local sessions,
   which are not subagent resumes.

4. **Fork mode is read from the session's own `Agent` results.** A session
   is outside fork mode when one of its own `Agent` calls in the transcript
   tail came back synchronously: `toolUseResult.status` is `completed` and
   `isAsync` is absent or false (ac2e27de's result at 17:43:58Z in
   ec562ba3). In fork mode every dispatch comes back
   `{"isAsync":true,"status":"async_launched"}`, whatever the call passed,
   so no such result exists. Only outside fork mode is either call refused;
   in fork mode a background flag changes nothing and a `SendMessage` resume
   is the skill's documented route. A session that has made no foreground
   dispatch yet reads as unknown and passes. Rejected: the presence of a
   `run_in_background` key in the session's calls, because a fork-mode
   controller passed it on 15 of 15 dispatches in the turn-liveness smoke
   (plan deviation 9), where the harness ignored it, and on none in T1;
   reading `CLAUDE_CODE_ENTRYPOINT` or `CLAUDE_CODE_FORK_SUBAGENT`, because
   the fork-mode default depends on the Claude Code version and entrypoint
   and the hook would have to track it.
   This does not reverse the stop guard's record "`SendMessage` resumes stay,
   pending Z4": its contingency already moved fix rounds outside fork mode to
   fresh foreground dispatches, and this hook enforces that route; the
   record's "fork mode is documented, not detected" concerns the stop guard,
   which is unchanged.

5. **The decision extractor passes by its template's opening sentence.** The
   extractor is the one background dispatch SDD makes on purpose. Its prompt,
   composed from `skills/finishing-a-development-branch/decision-notes-prompt.md`,
   opens with "You write implementation notes for a list of design
   decisions"; a background `Agent` call whose prompt contains that sentence
   passes, and a contract check keeps the sentence in the template.
   Rejected: matching the `description` (free text the controller writes);
   reading the ledger's `Decision extractor:` line (written after the
   dispatch).

6. **It fails open and has no refusal cap.** Anything it cannot read or
   decide passes and is logged: an unreadable or malformed ledger header, an
   unreadable transcript, and a transcript tail that hit the 16 MB cap before
   the fact the decision needs. The stop guard caps refusals at two because a
   refused turn end can trap a session; a refused dispatch always has an
   allowed substitute (the same dispatch in the foreground, or a fresh
   foreground implementer), so there is no trap to bound. Rejected: a cap of
   two, which would let the third background dispatch through for nothing.

7. **It refuses or stays silent; it never allows.** A PreToolUse `allow`
   decision skips the user's permission prompts, so the hook prints a deny or
   nothing.

8. **It logs to a per-session file in the cache only.** Lines go to
   `${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/dispatch-guard/<session>.jsonl`.
   Rejected: a copy in the SDD workspace, because Finish, `sdd-state` and the
   state branch would then have a new file to carry or skip.

9. **The evidence bar is tests, a field replay, a treatment-only scenario and
   one Zed run, recorded in a preregistered evidence note.** Unit and wrapper
   tests cover every decision; an offline replay over a frozen corpus (every
   `Agent` and `SendMessage` call the 10 field sessions made under v6.17.0,
   counted and hashed in the Testing section), with the plan check forced
   on, lists every call the hook would refuse and must show no refusal of a
   dispatch the skill allows during a plan; a five-run scenario in which
   every counted run contains a `SendMessage` refusal, and at least one run
   a background-`Agent` refusal, must show each refusal followed by a
   foreground dispatch and no turn end with a live agent, 5 of 5; one
   uncounted fork-mode run must refuse nothing; one manual Zed run must show
   the thread working through a `SendMessage` refusal and its re-dispatch. The
   criteria are written into
   `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md` before
   the first run, and the note cites the committed artifacts in
   hyperpowers-evals. Rejected: a control arm, following the stop guard's
   "one treatment arm, unit tests, and the field": the hook is deterministic
   and the control's behaviour is the field data above. Rejected: replay
   plan windows from the stop-guard logs, because a Stop line marks a point
   inside a plan rather than its bounds and three of the ten sessions have
   no stop-guard log.

## Design

### What it refuses

The hook is `sdd-dispatch-guard`, registered in `hooks/hooks.json` as a
PreToolUse hook with matcher `Agent|SendMessage` and a 10-second timeout.
It refuses exactly two calls, both only from the controller (no `agent_id`
in the payload) of a session with a plan ledger:

- `Agent` with `run_in_background: true`, unless its prompt contains the
  extractor sentence.
- `SendMessage` whose `to` is one of this session's own agent ids.

Both refusals also require the session to be outside fork mode, read from
its own `Agent` results as Decision 4 states. Everything else passes in
silence: a foreground `Agent` call or one without the key, any subagent's
call, a session with no ledger or only a receipt or an ambiguous match, a
message to anything that is not this session's subagent, a fork-mode or
not-yet-known session, and every read that fails.

### Decision order

Cheap checks come first, because nearly every call is a foreground dispatch.
Steps 1 to 3 read only the payload; `main` runs them before it touches any
file, and gathers the step 4 and step 5 facts only for a call that reaches
them. `decideDispatch` takes the payload and those facts and returns the
decision; a test can therefore assert that a step-2 call never reaches the
gathering code.

1. Parse the payload. A session id that is not one `[A-Za-z0-9._-]` token, a
   present `agent_id`, or a tool other than `Agent` or `SendMessage`: silent.
2. `Agent` whose `run_in_background` is not `true` (the boolean, or the
   string `"true"` a fork-mode controller has been seen to pass): silent. No
   file is read.
3. `Agent` whose `tool_input.prompt` contains the extractor sentence:
   silent, logged as `extractor`.
4. `discover({ sessionId, cwd, cacheRoot })` from `stop-guard.mjs`. Any kind
   other than `ledger`: silent, logged as `no-plan` or `ambiguous`. For a
   `ledger`, read the ledger once through `ledgerRecords` and match its first
   record against `^# SDD ledger — plan: (.+)$`, the header `planState`
   parses; the captured path is `<plan>`. An unreadable ledger, a missing or
   malformed header, or a ledger that no longer carries this session's
   `session <id>:` line (replaced between discovery and this read): silent,
   logged as `hook-error` with the cause in `detail`.
5. Read the transcript tail with `linesFromEnd` under the stop guard's 16 MB
   cap. From main-chain records only, collect the `agentId` of every
   `toolUseResult` of an `Agent` call (and the `name` input of an `Agent`
   call when present), and whether any of those results came back
   synchronously (`status` is `completed` and `isAsync` is absent or false).
   Facts found in the tail are used whether or not the cap was reached. A
   transcript that cannot be read: silent, logged as `hook-error`.
6. `Agent`: a synchronous result was seen, refuse as `background-agent`;
   the cap was reached (the reader's sentinel) without one, silent, logged
   as `transcript-capped`; otherwise silent, logged as `fork-mode`.
7. `SendMessage`, in order: `to` is a collected id and a synchronous result
   was seen, refuse as `sendmessage-resume`; the cap was reached and either
   fact is still missing, silent, logged as `transcript-capped`; `to` is not
   a collected id, silent, logged as `not-own-agent`; no synchronous result
   was seen, silent, logged as `fork-mode`.

### Refusal text

The deny is
`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<text>"}}`.
`<plan>` is the path step 4 captured from the ledger header and `<skill>`
is the absolute path of
`skills/subagent-driven-development/SKILL.md` resolved from the module's own
location.

For `background-agent`:

> SDD plan <plan> is in progress in this session. On this harness every
> subagent is dispatched in the foreground (run_in_background: false): the
> turn stays open while it works, which is what the editor shows as the
> session working. Dispatch this one again with run_in_background: false. If
> you have not Read <skill> in full since the last compaction, Read it now.

For `sendmessage-resume`:

> SDD plan <plan> is in progress in this session. On this harness a
> SendMessage resume runs in the background and the turn ends while the
> subagent works. Dispatch a fresh subagent in the foreground
> (run_in_background: false) with the brief path, the report-file path, and
> what you meant to send; for a fix round, the open findings verbatim on the
> original implementer's model. The report file records what the earlier
> subagent did. If you have not Read <skill> in full since the last
> compaction, Read it now.

### Components

- `hooks/sdd-dispatch-guard`: the bash wrapper, the same shape as
  `hooks/sdd-stop-guard`. It reads the payload, runs the module, prints its
  output, and exits 0 on every path; when node is missing or the module
  exits non-zero it appends a `hook-error` line to the session log with
  `printf` alone. That fallback line is best effort, exactly as in the stop
  guard's wrapper: a plain `>>` append that follows no fencing and may be
  lost. The `appendLine` conventions below apply to the module's lines.
- `hooks/lib/dispatch-guard.mjs`: `decideDispatch()` as a pure function of
  the payload, the discovery result and the transcript facts, and
  `main(stdinText, env)` that gathers them. It imports `discover`,
  `linesFromEnd`, `appendLine` and `ledgerRecords` from `stop-guard.mjs`;
  nothing is copied.
- `hooks/hooks.json`: the PreToolUse entry. `hooks-codex.json` and
  `hooks-cursor.json` are unchanged.

### Log

Every call that reaches step 3 appends one JSON line: `ts`, `session`,
`tool`, `tool_use_id` (from the payload, when present), `decision` (`deny`
or `allow`), `reason` (`background-agent`, `sendmessage-resume`,
`extractor`, `no-plan`, `ambiguous`, `not-own-agent`, `fork-mode`,
`transcript-capped`, `hook-error`), `plan`, `to` (for `SendMessage`),
`detail` (when there is one) and `elapsed_ms`. Calls that stop at steps 1
and 2 are not logged. The module's lines use `appendLine`'s conventions: no
symlink is followed, and a torn line is fenced with the ledger's
`#fragment` marker.

### Assumptions

- Assumption: Claude Code honours a PreToolUse deny for `Agent` and
  `SendMessage` and returns `permissionDecisionReason` to the model as the
  call's result, validate via the scenario runs and the Zed run.
- Assumption: the PreToolUse payload's `tool_input` carries `run_in_background`,
  `prompt` and `to` as the model wrote them, and carries `agent_id` for a
  subagent's call, validate via a payload capture in the first plan task.
- Assumption: the `Agent` result shapes hold on every harness the guard runs
  under (`status: completed` without `isAsync` for a synchronous dispatch;
  `isAsync: true, status: async_launched` for a background or fork-mode
  one), as observed in the Zed transcripts above, validate via the same
  payload capture plus the scenario's and the fork-mode run's transcripts.
- Assumption: a foreground dispatch that stops at step 2 adds no noticeable
  latency, validate via the wrapper suite's bench line.

## Testing and Evidence

Run artifacts go to `evals/evidence/2026-11-10-sdd-dispatch-guard/` in
hyperpowers-evals.

The evidence note `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md`
is committed with the criteria below before the first scenario or replay
run, and later records each result with the evals commit that holds its
artifacts.

**Pairing rule.** The scenario and the field re-scan both use it. A refusal
is the denied call's `tool_result`, matched to the dispatch-guard log line
by `tool_use_id`. A turn end is a Stop: an assistant message that ends its
turn, which the stop guard logs for every session with a plan. A refusal is
followed by a foreground dispatch when the controller's next `Agent` or
`SendMessage` call after that `tool_result`, and before the next Stop, is
an `Agent` call with `run_in_background: false`. The decision extractor's
background dispatch is never refused, so it never enters a pair.

- **Unit tests.** `hooks/lib/dispatch-guard.test.mjs` under `node --test`,
  with the stop guard's temp-cache, ledger and transcript fixtures: each
  step of the decision order; that a step-2 call never reaches the
  gathering code; the extractor sentence; for both refusals, a session with
  a synchronous `Agent` result against a fork-mode session whose every
  result is `async_launched` although its calls passed
  `run_in_background` (boolean and string), which must pass, and a session
  with no `Agent` result yet, which must pass; own and foreign `to`;
  `agent_id`; a malformed payload; an unreadable ledger, a
  ledger with a malformed header, and a ledger replaced after discovery; a
  receipt-only session; an unreadable transcript; a transcript past the cap
  with the needed facts inside the tail (refuse) and outside it
  (`transcript-capped`); the exact deny JSON for both reasons; the log
  line; and that no path prints an allow.
- **Wrapper suite.** `tests/hooks/test-sdd-dispatch-guard.sh` runs the unit
  matrix and the wrapper cases: the registration in `hooks.json`, node
  missing, a module failure, and a bench line for the step-2 path.
  `docs/testing.md` lists it.
- **Contract check.** `tests/sdd/test-sdd-contract.sh` asserts that
  `decision-notes-prompt.md` contains the extractor sentence.
- **Field replay.** The corpus is frozen here. It is the 10 sessions the
  re-read measurement covered, read up to the first record stamped after
  the cutoff 2026-11-10T18:10:00Z, and the replayed calls are the
  main-chain `Agent` and `SendMessage` calls stamped from
  2026-11-06T21:00:00Z (v6.17.0 installed, so the foreground rule was in
  the skill) to the cutoff. `sha256` is the first 12 hex digits over the
  transcript's lines up to the cutoff; the replay recomputes every count and
  hash, and any disagreement fails it before a call is classified.
  Generator: `~/.cache/hyperpowers/zed-idle-2026-11-10/manifest.py`.

  | Project directory (suffix) | Session | Agent | SendMessage | sha256 |
  |---|---|---|---|---|
  | agents-hyperpowers | 1fad2389-8d3f-4993-82c1-0d3f1a62521c | 0 | 0 | 6ddb2115106c |
  | agents-hyperpowers | 90d55be9-1d1e-4bc7-b240-b923565cae11 | 0 | 0 | bfe30f2b0609 |
  | agents-hyperpowers | d3ad24eb-b039-443b-81ea-cf62ddcffe5f | 0 | 0 | 93f24a50d52f |
  | agents-hyperpowers | ec562ba3-23b9-4cc9-abad-014f867d8ff8 | 49 | 4 | f29de343a00b |
  | cpp-oeviz | 0d60d899-fbca-4735-b103-a5cfd8e16c12 | 0 | 0 | 4e2586fc26f2 |
  | go-skz | db6a4097-9b63-4a02-906d-b51024fbb242 | 0 | 0 | c76d10b71339 |
  | python-bms-chem | 15809a43-6638-4672-b5e0-50577c88ffb5 | 52 | 0 | 0c3c8c6a3d3f |
  | meridian-moon c3-marketing-site | ae183251-44a1-472e-8b45-7e8da75a2509 | 109 | 16 | 8f47c39aad88 |
  | predict-before-structure | 37d62a37-7ddf-4c89-93d4-bc49c069bb99 | 76 | 23 | 278308bdd4a0 |
  | predict-before-structure | c793faa6-850b-428b-b91d-ad5b1a563657 | 0 | 0 | 207de8ffe914 |

  Every one of those 286 `Agent` and 43 `SendMessage` calls runs through
  `decideDispatch` with discovery forced to a ledger (a superset of what the
  live hook sees) and with the step-5 facts computed from the transcript up
  to that call under the same 16 MB cap.
  Each call it would refuse is classified by hand, with the transcript
  evidence for the class: inside a plan and forbidden by the skill (an
  expected refusal); inside a plan and allowed by the skill (a false
  refusal); or outside a plan (no SDD invocation yet, or after the Finish
  receipt), which the live hook passes at step 4. A call that cannot be
  classified counts as a false refusal. Pass: zero false refusals. Expected
  refusals include ec562ba3's 07:22, 17:47 and 18:02 calls.
- **Scenario.** A quorum scenario on Claude Code with
  `CLAUDE_CODE_FORK_SUBAGENT=0`: a small fixture plan whose first task fails
  review, and a prompt that pushes the controller to dispatch the task
  reviewer with `run_in_background: true` and to resume the implementer with
  `SendMessage` for the fix round. Treatment only. A counted run has at
  least one `sendmessage-resume` refusal; a run without one is void and
  replaced, at most three times, and a fourth void fails the scenario
  because its prompt does not provoke the call. A counted run passes when
  every refusal in it, of either reason, is followed by a foreground
  dispatch under the pairing rule and the run's stop-guard log has no
  `live-agent` line. Pass: 5 of 5 counted runs, and at least one of them
  also holds a paired `background-agent` refusal; if none does, the
  scenario fails, because one deny path went unexercised live. The denied
  results of both reasons are captured into the evidence directory. One
  uncounted run in fork mode must log `fork-mode` and refuse nothing; the
  evidence note records whether its dispatches passed `run_in_background`,
  since either outcome must pass.
- **Zed run.** One manual SDD run in Zed with a `sendmessage-resume`
  refusal in it, the call the field failure made. Pass: the thread shows the
  session working through the refusal and the foreground re-dispatch.
- **Field re-scan after release.** Stop-guard `live-agent` allows during
  plans outside fork mode should fall to zero, and every refusal in the
  dispatch-guard logs should be followed by a foreground dispatch under the
  pairing rule.

Every `docs/site` page whose `sources:` include a changed path is re-read,
corrected and re-digested in the same change; `bash tests/docs/docs-check.sh`
names them. That includes `docs/site/advanced/triggering.md`, which sources
the whole `hooks` directory and says `hooks.json` registers only the
SessionStart and Stop hooks, and `docs/site/advanced/sdd-internals.md`. A
page that describes the guard adds `hooks/sdd-dispatch-guard` and
`hooks/lib/dispatch-guard.mjs` to its sources.

## Out of Scope

- The compaction loss itself (Decision 2), the next slice.
- The compaction notice in `hooks/session-start` that pointed ec562ba3 at
  another plan's ledger at 16:55Z
  (`2026-11-10-cramer-v1-v2-carbohydrate-b7cd2bf8+987db445`), a separate
  defect.
- claude-agent-acp not holding a turn open for a `SendMessage` resume (Z4),
  an upstream adapter question.
- The stop guard, which is unchanged.
