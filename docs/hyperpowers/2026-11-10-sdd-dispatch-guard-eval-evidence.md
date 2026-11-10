# SDD Dispatch Guard: Eval Evidence

Date: 2026-11-10 (spec and plan).
Change: a PreToolUse hook on Claude Code, `hooks/sdd-dispatch-guard` with its
logic in `hooks/lib/dispatch-guard.mjs`, refuses an SDD controller's
background `Agent` call and its `SendMessage` to one of its own subagents
while the session has a plan ledger, outside fork mode. No skill text changes.

Spec: `docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md`.
Plan: `docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md`.

**Where the run artifacts live.** Every artifact this note cites is committed
in hyperpowers-evals under `evidence/2026-11-10-sdd-dispatch-guard/`, on its
`sdd-dispatch-guard` branch until that merges. Each result names the evals
commit that holds it.

This note was committed with the criteria below before the first replay or
scenario run. The criteria are the spec's; any later edit to them shows in
this file's history.

## Probe

A headless session (`claude -p`, empty config dir, a probe plugin whose
PreToolUse hook logs every payload and denies every `SendMessage` and one
background `Agent` call), run once with `CLAUDE_CODE_FORK_SUBAGENT=0` and once
with `=1`. Artifacts: `task-1-probe/` (evals `87539f3da`).

```text
claude-code: 2.1.317 (Claude Code)
C1 agent-payload: PASS run_in_background one=false three=true four=true; tool_use_id in transcript: true,true,true
C2 sendmessage-payload: PASS to="a256bf440f8abc822" probe-one agentId="a256bf440f8abc822"
C3 agent-id: PASS subagent Bash agent_id="a256bf440f8abc822"; controller dispatches without agent_id: true
C4 deny-honored: PASS probe three result: "PreToolUse:Agent hook error: PROBE-DENY probe three"; SendMessage result: "PROBE-DENY sendmessage"
C5 result-shapes: PASS probe one {"status":"completed"}; probe four {"status":"async_launched","isAsync":true}
C6 fork-shape (informational): probe one {"status":"async_launched","isAsync":true}; probe four {"status":"async_launched","isAsync":true}
```

## Criteria

**Pairing rule.** The scenario and the field re-scan both use it. A refusal is
the denied call's `tool_result`, matched to the dispatch-guard log line by
`tool_use_id`. A turn end is a Stop: an assistant message that ends its turn,
which the stop guard logs for every session with a plan (an `allow` line; a
`block` line is a turn that continued). A refusal is followed by a foreground
dispatch when the controller's next `Agent` or `SendMessage` call after that
`tool_result`, and before the next turn end, is an `Agent` call with
`run_in_background: false`. The decision extractor's background dispatch is
never refused, so it never enters a pair.

**Field replay.** The corpus is the 10 sessions the re-read measurement
covered, read up to the first record stamped after 2026-11-10T18:10:00Z. The
replayed calls are the main-chain `Agent` and `SendMessage` calls stamped from
2026-11-06T21:00:00Z (v6.17.0 installed) to that cutoff. `sha256` is the first
12 hex digits over the transcript's parseable lines up to the cutoff; the
replay recomputes every count and hash and stops on any disagreement before a
call is decided.

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

Every one of the 286 `Agent` and 43 `SendMessage` calls runs through the
guard's own `screen` and `decideDispatch`, with discovery forced to a ledger
(a superset of what the live hook sees) and the transcript facts read from the
transcript up to that call under the 16 MB cap. Each call it would refuse is
classified by hand, with the transcript evidence: inside a plan and forbidden
by the skill (an expected refusal); inside a plan and allowed by the skill (a
false refusal); or outside a plan (no SDD invocation yet, or after the Finish
receipt), which the live hook passes at discovery. A call that cannot be
classified counts as a false refusal. Pass: zero false refusals, and ec562ba3's
calls at 07:22, 17:47 and 18:02 are among the expected refusals.

**Scenario.** `scenarios/sdd-dispatch-guard` on Claude Code
(`claude-auto`) with `CLAUDE_CODE_FORK_SUBAGENT=0`, plugin loaded from the
treatment root at the pin recorded under Results. A two-task fixture plan
whose first task's plan code misses a design requirement, and an opening
message that asks for task reviewers with `run_in_background: true`, fix
rounds through `SendMessage` to the original implementer, and a `SendMessage`
follow-up to Task 1's implementer. Treatment only. A counted run has at least
one `sendmessage-resume` refusal; a run without one is void and replaced, at
most three times, and a fourth void fails the scenario. A counted run passes
when every refusal in it, of either reason, is followed by a foreground
dispatch under the pairing rule, and the run's stop-guard log has no
`live-agent` line. Pass: 5 of 5 counted runs, and at least one of them also
holds a paired `background-agent` refusal. The denied results of both reasons
are captured. One uncounted run of `scenarios/sdd-dispatch-guard-fork` (fork
mode left on) must log `fork-mode` and refuse nothing; whether its dispatches
passed `run_in_background` is recorded, and either outcome passes.

**Zed run.** One manual SDD run in Zed with a `sendmessage-resume` refusal in
it. Pass: the thread shows the session working through the refusal and the
foreground re-dispatch, and the refusal is paired under the pairing rule.

**Field re-scan after release.** Stop-guard `live-agent` allows during plans
outside fork mode fall to zero, and every refusal in the dispatch-guard logs
is followed by a foreground dispatch under the pairing rule. Owed after the
release that ships the hook; not part of this plan.

## Results

### Field replay

Pending.

### Scenario

Pending.

### Fork-mode run

Pending.

### Zed run

Pending.
