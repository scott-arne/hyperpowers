# SDD Dispatch Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. A correction added during execution that alters one of the spec's decisions names it: `Correction (<date>), decision <N> (<title>):`.

**Spec:** `docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md`

**Goal:** A Claude Code PreToolUse hook that refuses an SDD controller's background `Agent` dispatch and its `SendMessage` resume of its own subagent outside fork mode, plus the evidence the spec requires.

**Architecture:** `hooks/sdd-dispatch-guard`, a bash wrapper with the shape of `hooks/sdd-stop-guard`, pipes the PreToolUse payload to `hooks/lib/dispatch-guard.mjs`. The module screens the payload, finds the session's ledger with the stop guard's `discover`, reads fork mode and the session's own agent ids from the transcript tail with `linesFromEnd`, and prints a deny or nothing. `hooks/hooks.json` registers it for `Agent|SendMessage`. The evidence lives in hyperpowers-evals: a payload probe, an offline replay over the frozen field corpus, a five-run quorum scenario plus a fork-mode run, and one manual Zed run, all measured against an evidence note in this repo that is committed before the first run.

**Tech Stack:** Node built-ins only (`node --test`), bash, Claude Code hooks. In hyperpowers-evals: Bun and TypeScript (quorum, setup helpers) and node `.mjs` evidence scripts.

## Global Constraints

- Claude Code only. `hooks/hooks-codex.json` and `hooks/hooks-cursor.json` stay unchanged.
- No skill text changes: nothing under `skills/` changes. The stop guard (`hooks/sdd-stop-guard`, `hooks/lib/stop-guard.mjs`, `hooks/lib/stop-guard.test.mjs`) stays byte-identical. The new module imports `discover`, `linesFromEnd`, `appendLine`, `ledgerRecords`, `TAIL_CAP` and `TAIL_CHUNK` from it and copies none of its code; only test fixtures are duplicated.
- Registration: PreToolUse, `"matcher": "Agent|SendMessage"`, command `"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" sdd-dispatch-guard`, `"shell": "bash"`, `"timeout": 10`.
- The hook prints `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<text>"}}` or nothing. No path prints an allow. The wrapper exits 0 on every path.
- Fail open, no refusal cap.
- Log: `${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/dispatch-guard/<session>.jsonl`, fields in this order: `ts`, `session`, `tool`, `tool_use_id` (when the payload has one), `decision`, `reason`, `plan`, `to` (SendMessage only), `detail` (when there is one), `elapsed_ms`. Reasons: `background-agent`, `sendmessage-resume`, `extractor`, `no-plan`, `ambiguous`, `not-own-agent`, `fork-mode`, `transcript-capped`, `hook-error`. Calls that stop at steps 1 and 2 of the decision order are not logged.
- Extractor sentence, verbatim: `You write implementation notes for a list of design decisions`.
- Refusal texts are verbatim from the spec's "Refusal text" section. Task 2 holds them as code and its tests hold an independent copy.
- No heredoc or here-string in any file under `hooks/` (`tests/hooks/test-no-heredocs-in-hooks.sh`), and no here-string in `tests/`. No new file under `hooks/` contains two consecutive `<` characters.
- Docs: every `docs/site` page whose `sources:` include a path a task changes is re-read, corrected and re-digested in that task (`bash tests/docs/docs-check.sh --digest <page>`). Stage new files before computing a digest, because the digest reads `git ls-files`. `bash tests/docs/docs-check.sh` passes at the end of every task that changes this repo.
- Evidence directory: `evidence/2026-11-10-sdd-dispatch-guard/` in hyperpowers-evals, one `task-<N>-...` subdirectory per task that produces artifacts. Evals work happens on branch `sdd-dispatch-guard` in the worktree `/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt`, outside `evals/.worktrees`, created in Task 1. The live evals checkout at `/Users/johnss51/Development/agents/hyperpowers/evals` is not modified.
- Evidence note: `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md`, committed in Task 4, before the first replay or scenario run.
- Treatment root: a detached hp worktree at `/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/hp-treatment`, at the commit Task 6 records as the pin. The replay and every live run load the hook from there, never from the working branch.
- Commits: no `Co-Authored-By` line and no attribution of any kind. Before each commit in either repository, `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` prints `hits: 0`. Nothing is pushed.
- Live runs (`claude`, `bun run quorum run`) start inside the sandbox. Only after a sandbox failure (`Operation not permitted`, or setup dying at `git init` with EPERM) is that one command re-run with the sandbox disabled. Long output goes to a file by redirection, not through `tee` or a pipe: host pipes have held 512 bytes.
- The hp main checkout (`/Users/johnss51/Development/agents/hyperpowers`, branch `sweep-open-findings`, in use by another live session) and its untracked `BACKLOG.md` are not touched. `.worktrees/plugin-install` changes only in Task 10, which restores it.
- **Merge-expected files:** `CHANGELOG.md`, `docs/testing.md`, `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md`

## Grounding

- `hooks/sdd-stop-guard:1-24`: the wrapper shape (stdin read with a 2 s timeout, `record_error` with printf alone, session-id token check, `command -v node`, exit 0 on every path).
- `hooks/lib/stop-guard.mjs:44-48`: `ledgerRecords`, which drops a `#fragment`-fenced line and the empty tail.
- `hooks/lib/stop-guard.mjs:94-155`: `discover({ sessionId, cwd, cacheRoot })`, returning `{kind:'none'}`, `{kind:'ledger', workspace, ledger}`, `{kind:'ambiguous', ...}` or `{kind:'receipt', receipt}`.
- `hooks/lib/stop-guard.mjs:157-160`: `planState`'s header match `^# SDD ledger — plan: (.+)$`.
- `hooks/lib/stop-guard.mjs:363-390`: `appendLine(path, line, { mkdirsUnder })`, O_NOFOLLOW append with fragment fencing; returns false on failure and never throws.
- `hooks/lib/stop-guard.mjs:577-601`: `linesFromEnd(path, capBytes, chunkBytes)`, newest first, yielding `null` when the cap stops the read.
- `hooks/lib/stop-guard.mjs:658-669`: `main`'s payload parse, session-id token check and `cacheRoot` from `XDG_CACHE_HOME` or `HOME/.cache`.
- `hooks/lib/stop-guard.mjs:690-715`: the fault injection after the decision and the CLI entry (realpath of `argv[1]` compared through `pathToFileURL`).
- `hooks/lib/stop-guard.test.mjs:1-38`: test fixtures (`makeRepo`, `env`, `workspaceFor`, `ledger`, `receipt`) and naming (prose test names, `node:test`, `assert/strict`).
- `hooks/lib/stop-guard.test.mjs:717-727`: transcript record builders.
- `hooks/lib/stop-guard.test.mjs:882-915`: the bench test, skipped unless an env var is set, printing `# bench` lines.
- `tests/hooks/test-sdd-stop-guard.sh:1-89`: the wrapper suite (unit matrix with bench, registration via node over `hooks.json`, Codex/Cursor exclusion, shebang, wrapper cases, node absent through a PATH of symlinked tools, fault injection, malformed input, path-character session ids, symlinked hooks dir, `#` and `%` in the plugin root).
- `hooks/hooks.json:1-29`: the registration shape.
- `hooks/run-hook.cmd:1-4`: dispatch by script name; `bash hooks/run-hook.cmd <name>` runs `hooks/<name>`.
- `tests/sdd/test-sdd-contract.sh:14,21-35,639`: the path variables, `assert_contains <file> <needle> <description>` (whitespace-normalized), and the status line.
- `docs/testing.md:23`: the `tests/hooks/` row.
- `CHANGELOG.md:5-11`: the "Unreleased" list, one bold-lead bullet per change.
- `docs/site/advanced/sdd-internals.md:124`: the stop guard's paragraph in "Turn ends and the stop guard", the place the dispatch guard's paragraph goes after.
- `docs/site/advanced/triggering.md:13`: the sentence that says `hooks.json` registers SessionStart and Stop.
- `docs/site/skills/subagent-driven-development.md:10,98`: the harness-notes line and the hooks bullet.
- `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md:1-40`: evidence-note shape and the headless probe command (`env -u ... CLAUDE_CONFIG_DIR=<empty dir> claude -p --plugin-dir ...`).
- Evals `scenarios/sdd-turn-liveness/{setup.sh,checks.sh,story.md}`: scenario shape, the `# claude-env:` directive in the first 21 lines, the Codex-absent pre-checks.
- Evals `src/setup-helpers/sdd-fixtures.ts:569-579`, `src/setup-helpers/registry.ts:36,119`, `test/setup-helpers-sdd.test.ts:36-50`: a fixture helper, its registration and its test.
- Evals `test/scenario-pinning.test.ts:33-41,70-80,103-135`: the pinned-scenario comment, the set, and the directive-window tests.
- Evals `evidence/2026-10-23-sdd-stop-guard/archive-runs.sh:26-92`: run archiving and evidence hygiene.
- Evals `evidence/2026-09-05-gate-calibration/task-3-runs/summarize.mjs`: a node `.mjs` script in an evidence directory (evidence is outside `bun test`'s `test` root and biome's includes).
- Error handling: fail open, as `stop-guard.mjs` does: every read is wrapped and a failure becomes a logged pass, never a throw out of `main` (the injected fault excepted).

## Assumptions

- Assumption: the PreToolUse payload carries `tool_input.run_in_background`, `tool_input.prompt` and `tool_input.to` as the model wrote them, a top-level `tool_use_id` equal to the transcript's `tool_use` id, and `agent_id` on a subagent's call and not on the controller's, validate via Task 1 checks C1 to C3, before Task 2.
- Assumption: Claude Code honours a PreToolUse deny for `Agent` and `SendMessage` and returns `permissionDecisionReason` to the model as the call's result, validate via Task 1 check C4, before Task 2 (and again in Task 9's runs).
- Assumption: a foreground `Agent` result is `toolUseResult.status: "completed"` without `isAsync`, and a background one is `isAsync: true, status: "async_launched"`, validate via Task 1 check C5 and Task 9's fork-mode run, before Task 2.
- Assumption: a foreground dispatch that stops at step 2 adds no noticeable latency, validate via the bench lines in Task 3.
- Assumption: in a quorum run the guard's log and the stop guard's mirror land under `<workspace>/home/.cache/hyperpowers/`, validate via the first run in Task 9 (`tally.mjs` finds them by search, so a different cache root under `home/` still works).

A failed assumption is a plan conflict for your human partner, not a value to guess.

---

### Task 1: Payload probe and the evals worktree

**Risk tier:** high — its checker's findings decide whether Task 2 can start, and its probe hook denies tool calls (a permission surface, in an isolated config dir)

**Depends on:** none

**Files (hyperpowers-evals worktree):**
- Create: `evidence/2026-11-10-sdd-dispatch-guard/README.md`
- Create: `evidence/2026-11-10-sdd-dispatch-guard/task-1-probe/` (probe plugin, prompt, checker, captures, `findings.md`, `commands.txt`)

**Interfaces:**
- Produces: the evals worktree `/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt` on branch `sdd-dispatch-guard`, with `bun install` done; `task-1-probe/findings.md` in the format of Step 7, which Task 4 copies into the evidence note.

**Mirror:** `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md:15-40` (the stop guard's headless probe: empty config dir, `--plugin-dir`, stream-json).

- [ ] **Step 1: Create the evals worktree**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals worktree add -b sdd-dispatch-guard /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt main
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
bun install
```

Expected: the worktree exists on `sdd-dispatch-guard`, and `bun install` ends without errors. If `bun install` is refused by the network filter, re-run it with `registry.npmjs.org` in the call's allowed domains.

- [ ] **Step 2: Write the probe plugin**

Scratch root `P=/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/probe`. Create `$P/work` (an empty directory) and these files.

`$P/plugin/.claude-plugin/plugin.json`:

```json
{"name":"dispatch-probe","version":"0.0.1","description":"PreToolUse payload probe for the SDD dispatch guard plan"}
```

`$P/plugin/hooks/hooks.json`:

```json
{"hooks":{"PreToolUse":[{"matcher":"Agent|SendMessage|Bash","hooks":[{"type":"command","command":"node \"${CLAUDE_PLUGIN_ROOT}/hooks/probe.mjs\"","timeout":10}]}]}}
```

`$P/plugin/hooks/probe.mjs`:

```js
// Payload probe for the SDD dispatch guard plan, Task 1. Appends every
// PreToolUse payload to $P/$PROBE_LOG_NAME, and denies every SendMessage and
// the Agent call described "probe three".
import { appendFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const text = readFileSync(0, 'utf8');
const out = join(dirname(fileURLToPath(import.meta.url)), '..', '..', process.env.PROBE_LOG_NAME || 'payloads.jsonl');
appendFileSync(out, text.trim() + '\n');
let p = {};
try { p = JSON.parse(text); } catch { process.exit(0); }
const deny = (reason) => process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason } }) + '\n');
if (p.tool_name === 'SendMessage') deny('PROBE-DENY sendmessage');
else if (p.tool_name === 'Agent' && p.tool_input?.description === 'probe three') deny('PROBE-DENY probe three');
```

`$P/prompt.txt`:

```text
This is a harness probe. Make exactly these tool calls, one at a time, in this order, and nothing else.
1. Agent: description "probe one", name "probe-one", subagent_type "general-purpose", run_in_background false, prompt "Run the Bash command echo probe-one, then reply with its output only."
2. SendMessage: to the agent id that step 1's result reports (if it reports none, to "probe-one"), message "Reply with the word two."
3. Agent: description "probe three", subagent_type "general-purpose", run_in_background true, prompt "Reply with the word three."
4. Agent: description "probe four", subagent_type "general-purpose", run_in_background true, prompt "Reply with the word four."
Then reply with each tool result's text, verbatim, one per step. If a call is refused, note the refusal text and go on to the next step.
```

- [ ] **Step 3: Write the checker**

`$P/check-probe.mjs`:

```js
// check-probe.mjs <payloads.jsonl> <transcript.jsonl>: prints the probe's
// C1-C5 lines for one probe run (plan Task 1, Step 7 format).
import { readFileSync } from 'node:fs';

const [payloadsPath, transcriptPath] = process.argv.slice(2);
const read = (p) => readFileSync(p, 'utf8').split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
const payloads = read(payloadsPath);
const recs = read(transcriptPath);
const controller = payloads.filter((p) => p.agent_id == null);
const byDesc = (d) => controller.find((p) => p.tool_name === 'Agent' && p.tool_input?.description === d);
const one = byDesc('probe one'); const three = byDesc('probe three'); const four = byDesc('probe four');
const send = controller.find((p) => p.tool_name === 'SendMessage');
const subBash = payloads.find((p) => p.tool_name === 'Bash' && p.agent_id != null);
const dispatchesWithoutAgentId = payloads.filter((p) => p.tool_name !== 'Bash').every((p) => p.agent_id == null);
const resultFor = (id) => recs.find((r) => r.type === 'user' && Array.isArray(r.message?.content) && r.message.content.some((b) => b.type === 'tool_result' && b.tool_use_id === id));
const blockFor = (id) => resultFor(id)?.message.content.find((b) => b.type === 'tool_result' && b.tool_use_id === id);
const textOf = (b) => (typeof b?.content === 'string' ? b.content : Array.isArray(b?.content) ? b.content.map((c) => c.text || '').join('\n') : '');
const useIds = new Set(recs.filter((r) => r.type === 'assistant').flatMap((r) => (r.message?.content || []).filter((b) => b.type === 'tool_use').map((b) => b.id)));
const line = (id, name, ok, detail) => console.log(`${id} ${name}: ${ok ? 'PASS' : 'FAIL'} ${detail}`);

const c1 = [one, three, four].every((p) => p && typeof p.tool_use_id === 'string' && useIds.has(p.tool_use_id) && typeof p.session_id === 'string' && typeof p.transcript_path === 'string' && typeof p.cwd === 'string' && typeof p.tool_input?.prompt === 'string')
  && one.tool_input.run_in_background === false && three.tool_input.run_in_background === true && four.tool_input.run_in_background === true;
line('C1', 'agent-payload', c1, `run_in_background one=${JSON.stringify(one?.tool_input?.run_in_background)} three=${JSON.stringify(three?.tool_input?.run_in_background)} four=${JSON.stringify(four?.tool_input?.run_in_background)}; tool_use_id in transcript: ${[one, three, four].map((p) => useIds.has(p?.tool_use_id)).join(',')}`);
const oneResult = resultFor(one?.tool_use_id)?.toolUseResult;
const oneId = oneResult?.agentId;
const c2 = !!send && typeof send.tool_input?.to === 'string' && (send.tool_input.to === oneId || send.tool_input.to === 'probe-one');
line('C2', 'sendmessage-payload', c2, `to=${JSON.stringify(send?.tool_input?.to)} probe-one agentId=${JSON.stringify(oneId)}`);
const c3 = !!subBash && typeof subBash.agent_id === 'string' && dispatchesWithoutAgentId;
line('C3', 'agent-id', c3, `subagent Bash agent_id=${JSON.stringify(subBash?.agent_id)}; controller dispatches without agent_id: ${dispatchesWithoutAgentId}`);
const threeText = textOf(blockFor(three?.tool_use_id)); const sendText = textOf(blockFor(send?.tool_use_id));
const c4 = threeText.includes('PROBE-DENY probe three') && sendText.includes('PROBE-DENY sendmessage') && !resultFor(three?.tool_use_id)?.toolUseResult?.agentId;
line('C4', 'deny-honored', c4, `probe three result: ${JSON.stringify(threeText.slice(0, 160))}; SendMessage result: ${JSON.stringify(sendText.slice(0, 160))}`);
const fourResult = resultFor(four?.tool_use_id)?.toolUseResult;
const c5 = oneResult?.status === 'completed' && (oneResult.isAsync === undefined || oneResult.isAsync === false) && fourResult?.isAsync === true && fourResult?.status === 'async_launched';
line('C5', 'result-shapes', c5, `probe one ${JSON.stringify({ status: oneResult?.status, isAsync: oneResult?.isAsync })}; probe four ${JSON.stringify({ status: fourResult?.status, isAsync: fourResult?.isAsync })}`);
```

- [ ] **Step 4: Run probe A (fork mode off)**

From `$P/work`, inside the sandbox first:

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/probe/work
env -u CLAUDE_CODE_SESSION_ID -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT CLAUDE_CONFIG_DIR=/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/probe/config-a PROBE_LOG_NAME=payloads-a.jsonl CLAUDE_CODE_FORK_SUBAGENT=0 claude -p --plugin-dir /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/probe/plugin --model claude-sonnet-5-5 --output-format stream-json --verbose --allowedTools 'Bash(echo probe-one),Agent,SendMessage' "$(cat ../prompt.txt)" > ../run-a.jsonl 2> ../run-a.err
```

Expected: `run-a.jsonl` ends with a `result` record; `$P/payloads-a.jsonl` exists. If the run fails with a sandbox signature, re-run this one command with the sandbox disabled and note that in `commands.txt`. The main transcript is `$P/config-a/projects/*/<session_id>.jsonl`, where `<session_id>` is the `session_id` in `payloads-a.jsonl`.

- [ ] **Step 5: Run probe B (fork mode requested)**

The same command with `config-b`, `PROBE_LOG_NAME=payloads-b.jsonl`, `CLAUDE_CODE_FORK_SUBAGENT=1`, and output `../run-b.jsonl` / `../run-b.err`. This run is informational: it records the result shape a fork-mode dispatch gets, if `-p` honours the variable. Task 9's fork-mode run is the run of record for fork mode.

- [ ] **Step 6: Check both runs**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/probe
node check-probe.mjs payloads-a.jsonl config-a/projects/*/"$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("payloads-a.jsonl","utf8").split("\n")[0]).session_id)')".jsonl > check-a.txt
node check-probe.mjs payloads-b.jsonl config-b/projects/*/"$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync("payloads-b.jsonl","utf8").split("\n")[0]).session_id)')".jsonl > check-b.txt
node -e 'const r=require("fs").readFileSync("run-a.jsonl","utf8").split("\n").filter(Boolean).map(l=>{try{return JSON.parse(l)}catch{return null}}).find(r=>r&&r.type==="system"&&r.subtype==="init");console.log("init tools include SendMessage:",!!r&&Array.isArray(r.tools)&&r.tools.includes("SendMessage"))'
```

Expected: `check-a.txt` holds five lines, C1 to C5, each `PASS`. If C2 fails and the last command prints `init tools include SendMessage: false` (the session offered no SendMessage tool), record C2 as `DEFERRED` with that reason; Task 9 then checks the `to` field against its first run's transcript. Any other FAIL is a failed assumption: stop and report BLOCKED with `check-a.txt`.

- [ ] **Step 7: Write findings.md and copy the artifacts**

`$P/findings.md`, in exactly this format (values from `claude --version`, `check-a.txt`, and the C5 line of `check-b.txt`):

```text
claude-code: <claude --version output>
C1 agent-payload: <PASS|FAIL and detail, from check-a.txt>
C2 sendmessage-payload: <PASS|FAIL|DEFERRED and detail>
C3 agent-id: <from check-a.txt>
C4 deny-honored: <from check-a.txt>
C5 result-shapes: <from check-a.txt>
C6 fork-shape (informational): <the detail of check-b.txt's C5 line>
```

`$P/commands.txt`: the two commands as run, and whether each ran inside the sandbox.

Copy into the evals worktree (`EV=/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt/evidence/2026-11-10-sdd-dispatch-guard`):

```bash
mkdir -p "$EV/task-1-probe"
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/probe
cp -R plugin prompt.txt check-probe.mjs commands.txt findings.md check-a.txt check-b.txt payloads-a.jsonl payloads-b.jsonl run-a.jsonl run-a.err run-b.jsonl run-b.err "$EV/task-1-probe/"
mkdir -p "$EV/task-1-probe/transcript-a" "$EV/task-1-probe/transcript-b"
cp -R config-a/projects "$EV/task-1-probe/transcript-a/"
cp -R config-b/projects "$EV/task-1-probe/transcript-b/"
```

Do not copy the config directories otherwise: they hold account state.

- [ ] **Step 8: Write the evidence README**

`evidence/2026-11-10-sdd-dispatch-guard/README.md`:

```markdown
# SDD dispatch guard: evidence

Artifacts for `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md`
in hyperpowers (plan `docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md`).

- `task-1-probe/`: the PreToolUse payload probe (`findings.md` is the summary).
- `field/`: the frozen replay corpus manifest and the scripts that generated it.
- `replay.mjs`, `replay.test.mjs`: the offline field replay.
- `task-6-replay/`: the replay's output and the hand classification of every refusal.
- `tally.mjs`, `tally.test.mjs`, `archive-runs.sh`, `archive-runs.test.sh`, `launch.sh`: the scenario campaign's tooling.
- `logs/`: one launch log per quorum run, with its `run-id:` and `trials:` lines.
- `task-9-runs/`: the archived scenario runs (`treatment/`, `fork/`) and their tallies.
- `task-10-zed/`: the manual Zed run's logs, transcript and tally.

Run copies follow the hygiene in `archive-runs.sh`: the fixture's `.git` is renamed
`git-dir`, reinstallable host state is removed, `home/.cache/hyperpowers` is kept whole.
Stage `home/.claude` and `gauntlet-agent/results` with `git add -f`: the repository's
`.gitignore` matches `.claude/` and `results/` anywhere.
```

- [ ] **Step 9: Commit in the evals worktree**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
git add -f evidence/2026-11-10-sdd-dispatch-guard
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "evidence(sdd-dispatch-guard): PreToolUse payload probe"
```

Expected: the scan prints `hits: 0` before the commit.

---

### Task 2: The guard module, its unit tests, and the extractor contract

**Risk tier:** high — its deny is acted on by Claude Code for every SDD dispatch, and its fail-open paths are the safety property

**Depends on:** Task 1

**Files:**
- Create: `hooks/lib/dispatch-guard.mjs`
- Create: `hooks/lib/dispatch-guard.test.mjs`
- Modify: `tests/sdd/test-sdd-contract.sh` (a path variable after line 14, one assertion before the final `echo` at line 638)
- Modify: `docs/site/advanced/triggering.md:3` (`source-digest:` only)

**Interfaces:**
- Consumes: from `./stop-guard.mjs`: `discover({ sessionId, cwd, cacheRoot })`, `linesFromEnd(path, capBytes, chunkBytes)`, `appendLine(path, line, { mkdirsUnder })`, `ledgerRecords(text)`, `TAIL_CAP`, `TAIL_CHUNK`, `cloneKey(cwd)` (tests only).
- Produces (all named exports of `hooks/lib/dispatch-guard.mjs`):
  - `EXTRACTOR_SENTENCE: string`
  - `SKILL_PATH: string`, the absolute path of `skills/subagent-driven-development/SKILL.md`
  - `screen(input: object) -> { done: true } | { done: true, log: 'extractor', sessionId, tool } | { done: false, sessionId, tool, toolInput }`
  - `planOf(ledgerPath: string, sessionId: string) -> { plan: string } | { error: string }`
  - `transcriptFacts(linesNewestFirst: Iterable<string|null>) -> { ownIds: Set<string>, sync: boolean, capped: boolean }`
  - `readTranscriptFacts(path: string, { capBytes, chunkBytes }?) -> facts | { error: string }`
  - `gatherFacts({ sessionId, cwd, cacheRoot, transcriptPath }, { discoverFn }?) -> { discovery, plan?, facts? }`
  - `decideDispatch({ tool, toolInput, discovery, plan, facts }) -> { decision: 'deny'|'allow', reason: string, detail?: string }`
  - `refusalText(reason: 'background-agent'|'sendmessage-resume', plan: string, skill?: string) -> string`
  - `main(stdinText: string, env: object, deps?: { gather }) -> { stdout: string, exitCode: 0 }`

**Mirror:** `hooks/lib/stop-guard.mjs:658-715` (payload screen, fault injection after the decision, CLI entry) and `hooks/lib/stop-guard.test.mjs:1-38` (fixtures).

- [ ] **Step 1: Write the failing tests**

`hooks/lib/dispatch-guard.test.mjs`:

```js
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import * as dg from './dispatch-guard.mjs';
import { cloneKey, discover } from './stop-guard.mjs';

// Fixtures in the shape of stop-guard.test.mjs: a repository with a plan, a
// state workspace under its clone key, a ledger that carries the session.
const SID = 'sess-5678';
const PLAN = 'docs/plan.md';
function makeRepo(root) {
  const repo = join(root, 'repo');
  mkdirSync(join(repo, 'docs'), { recursive: true });
  execFileSync('git', ['init', '-q', '-b', 'main', repo]);
  execFileSync('git', ['-C', repo, 'config', 'user.email', 't@example.com']);
  execFileSync('git', ['-C', repo, 'config', 'user.name', 't']);
  writeFileSync(join(repo, 'docs', 'plan.md'), '# Plan\n\n### Task 1: one\n');
  execFileSync('git', ['-C', repo, 'add', 'docs/plan.md']);
  execFileSync('git', ['-C', repo, 'commit', '-q', '-m', 'plan']);
  return repo;
}
function env() { const root = mkdtempSync(join(tmpdir(), 'dg-')); return { root, cache: join(root, 'cache'), repo: makeRepo(root) }; }
function workspaceFor(e, name = 'plan-abcdef12') {
  const ws = join(e.cache, 'hyperpowers', 'state', cloneKey(e.repo), 'plans', name);
  mkdirSync(ws, { recursive: true });
  return ws;
}
function ledger(ws, e, { sid = SID, header = `# SDD ledger — plan: ${PLAN}` } = {}) {
  const p = join(ws, 'progress.md');
  writeFileSync(p, [header, `session ${sid}: mode worktree on main at ${e.repo} started 2026-11-10T00:00:00Z`].join('\n') + '\n');
  return p;
}
function receipt(e, name = 'plan-abcdef12', sid = SID) {
  const r = join(e.cache, 'hyperpowers', 'receipts', name); mkdirSync(r, { recursive: true });
  writeFileSync(join(r, 'progress.md'), `# SDD ledger — plan: ${PLAN}\nsession ${sid}: mode worktree on main at ${e.repo} started x\n`);
}

// Transcript records in the shapes the field transcripts hold.
const T0 = Date.parse('2026-11-10T10:00:00.000Z');
const at = (s) => new Date(T0 + s * 1000).toISOString();
const call = (t, id, name, input, extra = {}) => ({ type: 'assistant', timestamp: at(t), isSidechain: false, message: { role: 'assistant', content: [{ type: 'tool_use', id, name, input }] }, ...extra });
const result = (t, id, toolUseResult, extra = {}) => ({ type: 'user', timestamp: at(t), isSidechain: false, message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id, content: [{ type: 'text', text: 'ok' }] }] }, toolUseResult, ...extra });
const SYNC = (agentId) => ({ status: 'completed', agentId, content: [{ type: 'text', text: 'done' }], totalDurationMs: 1000 });
const ASYNC = (agentId) => ({ isAsync: true, status: 'async_launched', agentId, description: 'reviewer' });
const jsonl = (recs) => recs.map((r) => JSON.stringify(r)).join('\n') + '\n';
const newestFirst = (recs) => recs.map((r) => JSON.stringify(r)).reverse();
function transcript(e, recs, name = 't.jsonl') { const p = join(e.root, name); writeFileSync(p, jsonl(recs)); return p; }
// A foreground implementer that came back synchronously: outside fork mode, owning a1 (named impl-1).
const syncSession = () => [call(1, 'tu1', 'Agent', { description: 'Implement Task 1', prompt: 'brief', run_in_background: false, name: 'impl-1' }), result(2, 'tu1', SYNC('a1'))];
// Fork mode: the dispatch came back async_launched, whatever the call passed.
const forkSession = (bg) => [call(1, 'tu1', 'Agent', { description: 'Implement Task 1', prompt: 'brief', run_in_background: bg }), result(2, 'tu1', ASYNC('a1'))];

const BG = { description: 'Review Task 1', prompt: 'review brief', run_in_background: true };
const RESUME = { to: 'a1', message: 'fix the findings', summary: 'fix round' };
const SILENT_R = { stdout: '', exitCode: 0 };
const payload = (e, tool, toolInput, extra = {}) => JSON.stringify({ session_id: SID, transcript_path: e.transcript, cwd: e.repo, permission_mode: 'default', hook_event_name: 'PreToolUse', tool_name: tool, tool_input: toolInput, tool_use_id: 'toolu_new', ...extra });
function planned(recs = syncSession()) { const e = env(); ledger(workspaceFor(e), e); e.transcript = transcript(e, recs); return e; }
const run = (e, tool, input, extra = {}, deps = {}) => dg.main(payload(e, tool, input, extra), { XDG_CACHE_HOME: e.cache }, deps);
const logOf = (e, sid = SID) => join(e.cache, 'hyperpowers', 'dispatch-guard', `${sid}.jsonl`);
const logLines = (e, sid = SID) => readFileSync(logOf(e, sid), 'utf8').trim().split('\n').map((l) => JSON.parse(l));

// The refusal texts, copied from the spec independently of the module.
const SKILL = fileURLToPath(new URL('../../skills/subagent-driven-development/SKILL.md', import.meta.url));
const BG_TEXT = (plan) => `SDD plan ${plan} is in progress in this session. On this harness every subagent is dispatched in the foreground (run_in_background: false): the turn stays open while it works, which is what the editor shows as the session working. Dispatch this one again with run_in_background: false. If you have not Read ${SKILL} in full since the last compaction, Read it now.`;
const SM_TEXT = (plan) => `SDD plan ${plan} is in progress in this session. On this harness a SendMessage resume runs in the background and the turn ends while the subagent works. Dispatch a fresh subagent in the foreground (run_in_background: false) with the brief path, the report-file path, and what you meant to send; for a fix round, the open findings verbatim on the original implementer's model. The report file records what the earlier subagent did. If you have not Read ${SKILL} in full since the last compaction, Read it now.`;
const deny = (text) => JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: text } });

test('screen: a payload that is not an object, or has no usable session id, is silent', () => {
  for (const input of [null, [], 'x', 3]) assert.deepEqual(dg.screen(input), { done: true });
  for (const session_id of [undefined, '', '../x', 'a/b', 'a b', 7]) assert.deepEqual(dg.screen({ session_id, tool_name: 'SendMessage', tool_input: RESUME }), { done: true });
});
test('screen: a subagent call (agent_id present) is silent', () => {
  assert.deepEqual(dg.screen({ session_id: SID, agent_id: 'a9', tool_name: 'Agent', tool_input: BG }), { done: true });
  assert.deepEqual(dg.screen({ session_id: SID, agent_id: 'a9', tool_name: 'SendMessage', tool_input: RESUME }), { done: true });
});
test('screen: a tool other than Agent or SendMessage is silent', () => {
  for (const tool_name of ['Bash', 'Task', 'Read', undefined]) assert.deepEqual(dg.screen({ session_id: SID, tool_name, tool_input: BG }), { done: true });
});
test('screen: an Agent call whose run_in_background is not true is silent (step 2)', () => {
  for (const v of [false, 'false', undefined, null, 1, 'yes']) assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent', tool_input: { prompt: 'p', run_in_background: v } }), { done: true });
  assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent' }), { done: true });
});
test('screen: an Agent call with run_in_background true or "true" goes on', () => {
  for (const v of [true, 'true']) {
    const toolInput = { prompt: 'p', run_in_background: v };
    assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent', tool_input: toolInput }), { done: false, sessionId: SID, tool: 'Agent', toolInput });
  }
});
test('screen: a background Agent call whose prompt carries the extractor sentence is silent, logged as extractor', () => {
  const prompt = `Decision notes.\n\n    ${dg.EXTRACTOR_SENTENCE}. You do\n    not judge the decisions.`;
  assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'Agent', tool_input: { prompt, run_in_background: true } }), { done: true, log: 'extractor', sessionId: SID, tool: 'Agent' });
});
test('screen: every controller SendMessage goes on, with its tool_input', () => {
  assert.deepEqual(dg.screen({ session_id: SID, tool_name: 'SendMessage', tool_input: RESUME }), { done: false, sessionId: SID, tool: 'SendMessage', toolInput: RESUME });
});
test('the extractor sentence opens the decision-notes template', () => {
  const tpl = readFileSync(fileURLToPath(new URL('../../skills/finishing-a-development-branch/decision-notes-prompt.md', import.meta.url)), 'utf8');
  assert.equal(dg.EXTRACTOR_SENTENCE, 'You write implementation notes for a list of design decisions');
  assert.ok(tpl.includes(dg.EXTRACTOR_SENTENCE));
});

test('planOf: the plan path from the ledger header', () => {
  const e = env();
  assert.deepEqual(dg.planOf(ledger(workspaceFor(e), e), SID), { plan: PLAN });
});
test('planOf: an unreadable ledger is an error naming the cause', () => {
  const e = env();
  assert.deepEqual(dg.planOf(join(e.root, 'missing.md'), SID), { error: 'ledger unreadable: ENOENT' });
  assert.deepEqual(dg.planOf(e.root, SID), { error: 'ledger unreadable: EISDIR' });
});
test('planOf: a missing or malformed header is an error', () => {
  const e = env(); const ws = workspaceFor(e);
  for (const header of ['# SDD ledger - plan: docs/plan.md', 'session x: y', '# SDD ledger — plan: ']) {
    assert.deepEqual(dg.planOf(ledger(ws, e, { header }), SID), { error: 'ledger header missing or malformed' });
  }
});
test('planOf: a ledger that no longer carries this session is an error', () => {
  const e = env();
  assert.deepEqual(dg.planOf(ledger(workspaceFor(e), e, { sid: 'someone-else' }), SID), { error: 'ledger no longer carries this session' });
});

test('transcriptFacts: a synchronous Agent result puts the session outside fork mode and records its id and name', () => {
  const f = dg.transcriptFacts(newestFirst(syncSession()));
  assert.equal(f.sync, true); assert.equal(f.capped, false);
  assert.deepEqual([...f.ownIds].sort(), ['a1', 'impl-1']);
});
test('transcriptFacts: in fork mode no result is synchronous, whatever the calls passed', () => {
  for (const bg of [true, 'true', false, 'false', undefined]) {
    const f = dg.transcriptFacts(newestFirst(forkSession(bg)));
    assert.equal(f.sync, false); assert.deepEqual([...f.ownIds], ['a1']);
  }
});
test('transcriptFacts: a session with no Agent result yet has no facts', () => {
  const f = dg.transcriptFacts(newestFirst([call(1, 'tu1', 'Agent', BG)]));
  assert.equal(f.sync, false); assert.equal(f.ownIds.size, 0);
});
test('transcriptFacts: isAsync false with status completed is synchronous; Task, the older tool name, counts', () => {
  const recs = [call(1, 'tu1', 'Task', { prompt: 'p' }), result(2, 'tu1', { ...SYNC('a2'), isAsync: false })];
  const f = dg.transcriptFacts(newestFirst(recs));
  assert.equal(f.sync, true); assert.deepEqual([...f.ownIds], ['a2']);
});
test('transcriptFacts: sidechain records do not count', () => {
  const f = dg.transcriptFacts(newestFirst(syncSession().map((r) => ({ ...r, isSidechain: true }))));
  assert.equal(f.sync, false); assert.equal(f.ownIds.size, 0);
});
test('transcriptFacts: a result whose call is not an Agent call does not count', () => {
  const recs = [call(1, 'tu1', 'SendMessage', RESUME), result(2, 'tu1', { success: true, message: 'Resuming agent a1', resumedAgentId: 'a1', status: 'completed', agentId: 'a1' })];
  const f = dg.transcriptFacts(newestFirst(recs));
  assert.equal(f.sync, false); assert.equal(f.ownIds.size, 0);
});
test('transcriptFacts: malformed and non-record lines are skipped', () => {
  const f = dg.transcriptFacts(['not json', '[1]', '"s"', '', 'null', ...newestFirst(syncSession())]);
  assert.equal(f.sync, true);
});
test('transcriptFacts: the reader\'s null sentinel marks the tail capped', () => {
  const f = dg.transcriptFacts([...newestFirst(syncSession()), null]);
  assert.equal(f.capped, true); assert.equal(f.sync, true);
});

test('readTranscriptFacts: no path or an absent transcript is an error', () => {
  const e = env();
  assert.deepEqual(dg.readTranscriptFacts(''), { error: 'no transcript path' });
  assert.deepEqual(dg.readTranscriptFacts(join(e.root, 'none.jsonl')), { error: 'transcript unreadable: ENOENT' });
});

const LEDGER = { kind: 'ledger', workspace: '/w', ledger: '/w/progress.md' };
const facts = (ids, sync, capped = false) => ({ ownIds: new Set(ids), sync, capped });
const decide = (tool, toolInput, f, extra = {}) => dg.decideDispatch({ tool, toolInput, discovery: LEDGER, plan: { plan: PLAN }, facts: f, ...extra });

test('decideDispatch: no ledger, a receipt, or an ambiguous match passes', () => {
  assert.deepEqual(dg.decideDispatch({ tool: 'Agent', toolInput: BG, discovery: { kind: 'none' } }), { decision: 'allow', reason: 'no-plan' });
  assert.deepEqual(dg.decideDispatch({ tool: 'Agent', toolInput: BG, discovery: { kind: 'receipt', receipt: '/r' } }), { decision: 'allow', reason: 'no-plan' });
  assert.deepEqual(dg.decideDispatch({ tool: 'SendMessage', toolInput: RESUME, discovery: { kind: 'ambiguous', candidates: 2, matches: [] } }), { decision: 'allow', reason: 'ambiguous' });
  assert.deepEqual(dg.decideDispatch({ tool: 'SendMessage', toolInput: RESUME }), { decision: 'allow', reason: 'no-plan' });
});
test('decideDispatch: a ledger or transcript read error passes as hook-error with its detail', () => {
  assert.deepEqual(decide('Agent', BG, facts(['a1'], true), { plan: { error: 'ledger header missing or malformed' } }), { decision: 'allow', reason: 'hook-error', detail: 'ledger header missing or malformed' });
  assert.deepEqual(decide('Agent', BG, { error: 'transcript unreadable: ENOENT' }), { decision: 'allow', reason: 'hook-error', detail: 'transcript unreadable: ENOENT' });
});
test('decideDispatch: a background Agent call (step 6)', () => {
  assert.deepEqual(decide('Agent', BG, facts(['a1'], true)), { decision: 'deny', reason: 'background-agent' });
  assert.deepEqual(decide('Agent', BG, facts(['a1'], true, true)), { decision: 'deny', reason: 'background-agent' });
  assert.deepEqual(decide('Agent', BG, facts(['a1'], false)), { decision: 'allow', reason: 'fork-mode' });
  assert.deepEqual(decide('Agent', BG, facts([], false)), { decision: 'allow', reason: 'fork-mode' });
  assert.deepEqual(decide('Agent', BG, facts([], false, true)), { decision: 'allow', reason: 'transcript-capped' });
});
test('decideDispatch: a SendMessage, in the spec\'s order (step 7)', () => {
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], true)), { decision: 'deny', reason: 'sendmessage-resume' });
  assert.deepEqual(decide('SendMessage', { to: 'impl-1', message: 'm' }, facts(['a1', 'impl-1'], true)), { decision: 'deny', reason: 'sendmessage-resume' });
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], true, true)), { decision: 'deny', reason: 'sendmessage-resume' });
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], false, true)), { decision: 'allow', reason: 'transcript-capped' });
  assert.deepEqual(decide('SendMessage', { to: 'x', message: 'm' }, facts(['a1'], true, true)), { decision: 'allow', reason: 'transcript-capped' });
  assert.deepEqual(decide('SendMessage', { to: 'x', message: 'm' }, facts(['a1'], true)), { decision: 'allow', reason: 'not-own-agent' });
  assert.deepEqual(decide('SendMessage', { to: 'x', message: 'm' }, facts([], false)), { decision: 'allow', reason: 'not-own-agent' });
  assert.deepEqual(decide('SendMessage', { message: 'm' }, facts(['a1'], true)), { decision: 'allow', reason: 'not-own-agent' });
  assert.deepEqual(decide('SendMessage', RESUME, facts(['a1'], false)), { decision: 'allow', reason: 'fork-mode' });
});
test('a capped tail with the facts inside it refuses; with them outside it, transcript-capped', () => {
  const e = env(); const opts = { capBytes: 64 * 1024, chunkBytes: 16 * 1024 };
  const filler = Array.from({ length: 40 }, (_, i) => call(10 + i, `f${i}`, 'Read', { file_path: 'x'.repeat(4000) }));
  const inside = dg.readTranscriptFacts(transcript(e, [...filler, ...syncSession()], 'inside.jsonl'), opts);
  assert.equal(inside.capped, true); assert.equal(inside.sync, true);
  assert.deepEqual(decide('Agent', BG, inside), { decision: 'deny', reason: 'background-agent' });
  assert.deepEqual(decide('SendMessage', RESUME, inside), { decision: 'deny', reason: 'sendmessage-resume' });
  const outside = dg.readTranscriptFacts(transcript(e, [...syncSession(), ...filler], 'outside.jsonl'), opts);
  assert.equal(outside.capped, true); assert.equal(outside.sync, false);
  assert.deepEqual(decide('Agent', BG, outside), { decision: 'allow', reason: 'transcript-capped' });
  assert.deepEqual(decide('SendMessage', RESUME, outside), { decision: 'allow', reason: 'transcript-capped' });
});

test('refusalText: both texts, verbatim from the spec, naming the absolute SKILL.md path', () => {
  assert.equal(dg.refusalText('background-agent', PLAN), BG_TEXT(PLAN));
  assert.equal(dg.refusalText('sendmessage-resume', PLAN), SM_TEXT(PLAN));
  assert.equal(dg.SKILL_PATH, SKILL); assert.ok(existsSync(dg.SKILL_PATH));
});

test('main: a background Agent call outside fork mode is refused with the exact deny and logged', () => {
  const e = planned();
  assert.deepEqual(run(e, 'Agent', BG), { stdout: deny(BG_TEXT(PLAN)), exitCode: 0 });
  const [l] = logLines(e);
  assert.deepEqual(Object.keys(l), ['ts', 'session', 'tool', 'tool_use_id', 'decision', 'reason', 'plan', 'elapsed_ms']);
  assert.equal(l.session, SID); assert.equal(l.tool, 'Agent'); assert.equal(l.tool_use_id, 'toolu_new');
  assert.equal(l.decision, 'deny'); assert.equal(l.reason, 'background-agent'); assert.equal(l.plan, PLAN);
  assert.ok(!Number.isNaN(Date.parse(l.ts))); assert.equal(typeof l.elapsed_ms, 'number');
});
test('main: a SendMessage to the session\'s own subagent is refused and logged with to', () => {
  const e = planned();
  assert.deepEqual(run(e, 'SendMessage', RESUME), { stdout: deny(SM_TEXT(PLAN)), exitCode: 0 });
  const [l] = logLines(e);
  assert.deepEqual(Object.keys(l), ['ts', 'session', 'tool', 'tool_use_id', 'decision', 'reason', 'plan', 'to', 'elapsed_ms']);
  assert.equal(l.to, 'a1'); assert.equal(l.reason, 'sendmessage-resume'); assert.equal(l.decision, 'deny');
});
test('main: a foreground Agent call never reaches the gathering code and writes nothing', () => {
  const e = planned(); let gathered = 0; const gather = () => { gathered++; return {}; };
  for (const input of [{ prompt: 'p', run_in_background: false }, { prompt: 'p' }]) assert.deepEqual(run(e, 'Agent', input, {}, { gather }), SILENT_R);
  assert.equal(gathered, 0);
  assert.equal(existsSync(join(e.cache, 'hyperpowers', 'dispatch-guard')), false);
  run(e, 'SendMessage', RESUME, {}, { gather });
  assert.equal(gathered, 1);
});
test('main: a subagent\'s call is silent and writes nothing', () => {
  const e = planned();
  assert.deepEqual(run(e, 'Agent', BG, { agent_id: 'a9' }), SILENT_R);
  assert.deepEqual(run(e, 'SendMessage', RESUME, { agent_id: 'a9' }), SILENT_R);
  assert.equal(existsSync(logOf(e)), false);
});
test('main: the extractor\'s background dispatch passes, logged as extractor', () => {
  const e = planned();
  assert.deepEqual(run(e, 'Agent', { prompt: `${dg.EXTRACTOR_SENTENCE}. You do not judge.`, run_in_background: true }), SILENT_R);
  const [l] = logLines(e);
  assert.equal(l.decision, 'allow'); assert.equal(l.reason, 'extractor'); assert.equal(l.plan, null);
});
test('main: no ledger, a receipt alone, and two ledgers pass', () => {
  const none = env(); none.transcript = transcript(none, syncSession());
  assert.deepEqual(run(none, 'Agent', BG), SILENT_R); assert.equal(logLines(none)[0].reason, 'no-plan');
  const rec = env(); rec.transcript = transcript(rec, syncSession()); receipt(rec);
  assert.deepEqual(run(rec, 'SendMessage', RESUME), SILENT_R); assert.equal(logLines(rec)[0].reason, 'no-plan');
  const two = env(); two.transcript = transcript(two, syncSession()); ledger(workspaceFor(two, 'a-11111111'), two); ledger(workspaceFor(two, 'b-22222222'), two);
  assert.deepEqual(run(two, 'Agent', BG), SILENT_R); assert.equal(logLines(two)[0].reason, 'ambiguous');
});
test('main: a fork-mode session passes both calls, whatever its calls passed', () => {
  for (const bg of [true, 'true']) {
    const e = planned(forkSession(bg));
    assert.deepEqual(run(e, 'Agent', { ...BG, run_in_background: bg }), SILENT_R);
    assert.deepEqual(run(e, 'SendMessage', RESUME), SILENT_R);
    assert.deepEqual(logLines(e).map((l) => l.reason), ['fork-mode', 'fork-mode']);
  }
});
test('main: a session with no Agent result yet passes both calls', () => {
  const e = planned([call(1, 'tu1', 'Agent', BG)]);
  assert.deepEqual(run(e, 'Agent', BG), SILENT_R);
  assert.deepEqual(run(e, 'SendMessage', RESUME), SILENT_R);
  assert.deepEqual(logLines(e).map((l) => l.reason), ['fork-mode', 'not-own-agent']);
});
test('main: a SendMessage to anything that is not this session\'s subagent passes as not-own-agent', () => {
  const e = planned();
  assert.deepEqual(run(e, 'SendMessage', { to: 'other-session', message: 'hi' }), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'not-own-agent'); assert.equal(l.to, 'other-session');
});
test('main: an unreadable transcript passes as hook-error', () => {
  const e = planned(); e.transcript = join(e.root, 'gone.jsonl');
  assert.deepEqual(run(e, 'Agent', BG), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'hook-error'); assert.equal(l.detail, 'transcript unreadable: ENOENT'); assert.equal(l.plan, PLAN);
});
test('main: a malformed ledger header passes as hook-error', () => {
  const e = env(); ledger(workspaceFor(e), e, { header: '# not a ledger header' }); e.transcript = transcript(e, syncSession());
  assert.deepEqual(run(e, 'Agent', BG), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'hook-error'); assert.equal(l.detail, 'ledger header missing or malformed'); assert.equal(l.plan, null);
});
test('main: a ledger replaced between discovery and the read passes as hook-error', () => {
  const e = planned(); const ws = workspaceFor(e);
  const gather = (args) => dg.gatherFacts(args, { discoverFn: (a) => { const d = discover(a); ledger(ws, e, { sid: 'someone-else' }); return d; } });
  assert.deepEqual(run(e, 'SendMessage', RESUME, {}, { gather }), SILENT_R);
  const [l] = logLines(e); assert.equal(l.reason, 'hook-error'); assert.equal(l.detail, 'ledger no longer carries this session');
});
test('main: malformed stdin is silent', () => {
  assert.deepEqual(dg.main('not json', {}), SILENT_R);
  assert.deepEqual(dg.main('', {}), SILENT_R);
  assert.deepEqual(dg.main('[]', {}), SILENT_R);
});
test('main: no path prints an allow', () => {
  const outs = [];
  const e = planned(); outs.push(run(e, 'Agent', BG).stdout, run(e, 'SendMessage', RESUME).stdout, run(e, 'Agent', { prompt: 'p' }).stdout, run(e, 'SendMessage', { to: 'x', message: 'm' }).stdout);
  const f = planned(forkSession(true)); outs.push(run(f, 'Agent', BG).stdout, run(f, 'SendMessage', RESUME).stdout);
  for (const out of outs) {
    if (out === '') continue;
    assert.equal(JSON.parse(out).hookSpecificOutput.permissionDecision, 'deny');
  }
  assert.equal(outs.filter((o) => o !== '').length, 2);
});
test('main: DISPATCH_GUARD_FAULT=throw throws after the decision', () => {
  const e = planned();
  assert.throws(() => dg.main(payload(e, 'Agent', BG), { XDG_CACHE_HOME: e.cache, DISPATCH_GUARD_FAULT: 'throw' }), /injected fault/);
});
test('main: a symlink at the log path is not followed, and the refusal still prints', () => {
  const e = planned();
  mkdirSync(join(e.cache, 'hyperpowers', 'dispatch-guard'), { recursive: true });
  const target = join(e.root, 'elsewhere.jsonl'); writeFileSync(target, '');
  symlinkSync(target, logOf(e));
  assert.deepEqual(run(e, 'Agent', BG), { stdout: deny(BG_TEXT(PLAN)), exitCode: 0 });
  assert.equal(readFileSync(target, 'utf8'), '');
});
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `node --test hooks/lib/dispatch-guard.test.mjs`
Expected: FAIL, `Cannot find module` for `./dispatch-guard.mjs`.

- [ ] **Step 3: Write the module**

`hooks/lib/dispatch-guard.mjs`:

```js
// The SDD dispatch guard, a PreToolUse hook on Claude Code. It refuses the two
// calls that end an SDD controller's turn while a subagent works: an Agent
// dispatch with run_in_background true, and a SendMessage resume of one of the
// session's own subagents. The skill already forbids both outside fork mode,
// but after a compaction the controller no longer has those lines, and an
// editor such as Zed shows the session idle for as long as the background
// subagent runs. The design is
// docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md.
//
// The hook refuses or stays silent. A PreToolUse allow would skip the user's
// permission prompts, so no path prints one. Anything it cannot read passes,
// and there is no refusal cap: a refused dispatch always has an allowed
// substitute, the same dispatch in the foreground.
import { readFileSync, realpathSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { TAIL_CAP, TAIL_CHUNK, appendLine, discover, ledgerRecords, linesFromEnd } from './stop-guard.mjs';

// The opening sentence of skills/finishing-a-development-branch/
// decision-notes-prompt.md. The decision extractor is the one background
// dispatch SDD makes on purpose; tests/sdd/test-sdd-contract.sh keeps the
// sentence in the template.
export const EXTRACTOR_SENTENCE = 'You write implementation notes for a list of design decisions';
export const SKILL_PATH = fileURLToPath(new URL('../../skills/subagent-driven-development/SKILL.md', import.meta.url));
// The header planState parses in stop-guard.mjs.
const HEADER = /^# SDD ledger — plan: (.+)$/;
// stop-guard.mjs keeps its own set private. Task is the tool's older name,
// which older transcripts still carry.
const AGENT_TOOLS = new Set(['Agent', 'Task']);
const SILENT = Object.freeze({ stdout: '', exitCode: 0 });

// Steps 1 to 3 of the decision order: the payload alone, no file read. Nearly
// every call is a foreground dispatch, so step 2 has to be cheap.
export function screen(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return { done: true };
  const sessionId = typeof input.session_id === 'string' ? input.session_id : '';
  // One token, as the stop guard requires: the log path is built from it.
  if (!sessionId || /[^A-Za-z0-9._-]/.test(sessionId)) return { done: true };
  if (input.agent_id != null) return { done: true };
  const tool = input.tool_name;
  if (tool !== 'Agent' && tool !== 'SendMessage') return { done: true };
  const toolInput = input.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};
  if (tool === 'Agent') {
    // A fork-mode controller has been seen passing the string "true".
    const bg = toolInput.run_in_background;
    if (bg !== true && bg !== 'true') return { done: true };
    if (typeof toolInput.prompt === 'string' && toolInput.prompt.includes(EXTRACTOR_SENTENCE)) return { done: true, log: 'extractor', sessionId, tool };
  }
  return { done: false, sessionId, tool, toolInput };
}

// Step 4's read: the plan path from the ledger header. The session's line is
// checked again because sdd-state can replace the ledger between discovery
// and this read.
export function planOf(ledgerPath, sessionId) {
  let records;
  try { records = ledgerRecords(readFileSync(ledgerPath, 'utf8')); } catch (err) { return { error: `ledger unreadable: ${err?.code || 'error'}` }; }
  const m = (records[0] || '').match(HEADER);
  if (!m) return { error: 'ledger header missing or malformed' };
  if (!records.some((l) => l.startsWith(`session ${sessionId}:`))) return { error: 'ledger no longer carries this session' };
  return { plan: m[1] };
}

// Step 5: from main-chain records, the ids of this session's own subagents
// and whether any Agent call came back synchronously, which is the evidence
// that the session is outside fork mode. A call's `name` input counts only
// with a result, so a refused call registers no name. Lines that do not parse
// are skipped: a fact the tail does not show is a pass, never a refusal.
export function transcriptFacts(linesNewestFirst) {
  const recs = []; let capped = false;
  for (const l of linesNewestFirst) {
    if (l === null) { capped = true; break; }
    if (!l.trim()) continue;
    let rec; try { rec = JSON.parse(l); } catch { continue; }
    if (!rec || typeof rec !== 'object' || Array.isArray(rec) || rec.isSidechain) continue;
    recs.push(rec);
  }
  recs.reverse();
  const agentCalls = new Map();
  const ownIds = new Set(); let sync = false;
  for (const rec of recs) {
    const content = rec.message?.content;
    if (!Array.isArray(content)) continue;
    if (rec.type === 'assistant') {
      for (const b of content) if (b?.type === 'tool_use' && AGENT_TOOLS.has(b.name)) agentCalls.set(b.id, b.input && typeof b.input === 'object' ? b.input : {});
      continue;
    }
    if (rec.type !== 'user') continue;
    for (const b of content) {
      if (b?.type !== 'tool_result' || !agentCalls.has(b.tool_use_id)) continue;
      const r = rec.toolUseResult;
      if (!r || typeof r !== 'object' || typeof r.agentId !== 'string' || !r.agentId) continue;
      ownIds.add(r.agentId);
      const name = agentCalls.get(b.tool_use_id).name;
      if (typeof name === 'string' && name) ownIds.add(name);
      if (r.status === 'completed' && (r.isAsync === undefined || r.isAsync === false)) sync = true;
    }
  }
  return { ownIds, sync, capped };
}

export function readTranscriptFacts(path, { capBytes = TAIL_CAP, chunkBytes = TAIL_CHUNK } = {}) {
  if (!path) return { error: 'no transcript path' };
  try { return transcriptFacts(linesFromEnd(path, capBytes, chunkBytes)); } catch (err) { return { error: `transcript unreadable: ${err?.code || 'error'}` }; }
}

// Steps 4 and 5, each only when the one before it found what it needs.
export function gatherFacts({ sessionId, cwd, cacheRoot, transcriptPath }, { discoverFn = discover } = {}) {
  const discovery = discoverFn({ sessionId, cwd, cacheRoot });
  if (discovery?.kind !== 'ledger') return { discovery };
  const plan = planOf(discovery.ledger, sessionId);
  if (plan.error) return { discovery, plan };
  return { discovery, plan, facts: readTranscriptFacts(transcriptPath) };
}

// Steps 4 to 7 as a pure function of what gatherFacts found.
export function decideDispatch({ tool, toolInput = {}, discovery, plan = null, facts = null }) {
  if (discovery?.kind !== 'ledger') return { decision: 'allow', reason: discovery?.kind === 'ambiguous' ? 'ambiguous' : 'no-plan' };
  if (!plan || plan.error) return { decision: 'allow', reason: 'hook-error', detail: plan?.error || 'plan not read' };
  if (!facts || facts.error) return { decision: 'allow', reason: 'hook-error', detail: facts?.error || 'transcript not read' };
  if (tool === 'Agent') {
    if (facts.sync) return { decision: 'deny', reason: 'background-agent' };
    return { decision: 'allow', reason: facts.capped ? 'transcript-capped' : 'fork-mode' };
  }
  const to = typeof toolInput.to === 'string' ? toolInput.to : '';
  const own = to !== '' && facts.ownIds.has(to);
  if (own && facts.sync) return { decision: 'deny', reason: 'sendmessage-resume' };
  if (facts.capped) return { decision: 'allow', reason: 'transcript-capped' };
  if (!own) return { decision: 'allow', reason: 'not-own-agent' };
  return { decision: 'allow', reason: 'fork-mode' };
}

export function refusalText(reason, plan, skill = SKILL_PATH) {
  const head = `SDD plan ${plan} is in progress in this session.`;
  const reread = `If you have not Read ${skill} in full since the last compaction, Read it now.`;
  if (reason === 'background-agent') return `${head} On this harness every subagent is dispatched in the foreground (run_in_background: false): the turn stays open while it works, which is what the editor shows as the session working. Dispatch this one again with run_in_background: false. ${reread}`;
  return `${head} On this harness a SendMessage resume runs in the background and the turn ends while the subagent works. Dispatch a fresh subagent in the foreground (run_in_background: false) with the brief path, the report-file path, and what you meant to send; for a fix round, the open findings verbatim on the original implementer's model. The report file records what the earlier subagent did. ${reread}`;
}

export function main(stdinText, env = process.env, deps = {}) {
  const started = Date.now();
  let input;
  try { input = JSON.parse(stdinText || '{}'); } catch { return SILENT; }
  const s = screen(input);
  if (s.done && !s.log) return SILENT;
  const cacheRoot = env.XDG_CACHE_HOME || join(env.HOME || '', '.cache');
  let d; let plan = null;
  if (s.done) d = { decision: 'allow', reason: s.log };
  else {
    const gather = deps.gather || gatherFacts;
    const g = gather({
      sessionId: s.sessionId,
      cwd: typeof input.cwd === 'string' && input.cwd ? input.cwd : process.cwd(),
      cacheRoot,
      transcriptPath: typeof input.transcript_path === 'string' ? input.transcript_path : '',
    }) || {};
    plan = g.plan || null;
    d = decideDispatch({ tool: s.tool, toolInput: s.toolInput, discovery: g.discovery, plan: g.plan, facts: g.facts });
  }
  if (env.DISPATCH_GUARD_FAULT === 'throw') throw new Error('injected fault');
  const line = { ts: new Date().toISOString(), session: s.sessionId, tool: s.tool };
  if (typeof input.tool_use_id === 'string' && input.tool_use_id) line.tool_use_id = input.tool_use_id;
  line.decision = d.decision;
  line.reason = d.reason;
  line.plan = plan?.plan ?? null;
  if (s.tool === 'SendMessage') line.to = typeof s.toolInput.to === 'string' ? s.toolInput.to : null;
  if (d.detail) line.detail = d.detail;
  line.elapsed_ms = Date.now() - started;
  // The log is a record, not a condition: a refusal stands when the line
  // could not be written.
  appendLine(join(cacheRoot, 'hyperpowers', 'dispatch-guard', `${s.sessionId}.jsonl`), line, { mkdirsUnder: cacheRoot });
  if (d.decision !== 'deny') return SILENT;
  return { stdout: JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: refusalText(d.reason, plan.plan) } }), exitCode: 0 };
}

// CLI entry, as in stop-guard.mjs: the only place that reads stdin and writes
// stdout. node resolves symlinks for the main module's URL but leaves argv
// alone, so the comparison is on the resolved path, through pathToFileURL. An
// uncaught throw exits 1, which the wrapper turns into a hook-error line.
let mainPath = process.argv[1] || '';
try { if (mainPath) mainPath = realpathSync(mainPath); } catch { /* compare the raw path */ }
if (mainPath && import.meta.url === pathToFileURL(mainPath).href) {
  const text = readFileSync(0, 'utf8');
  const r = main(text, process.env);
  if (r.stdout) process.stdout.write(r.stdout + '\n');
  process.exit(r.exitCode);
}
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `node --test hooks/lib/dispatch-guard.test.mjs`
Expected: PASS, every test.

Run: `node --test hooks/lib/stop-guard.test.mjs`
Expected: PASS (unchanged module, unchanged result).

- [ ] **Step 5: Add the extractor contract check**

In `tests/sdd/test-sdd-contract.sh`, after line 14 (`FIN=...`):

```bash
DNP="$REPO_ROOT/skills/finishing-a-development-branch/decision-notes-prompt.md"
```

Before the final `echo` (line 638):

```bash
assert_contains "$DNP" "You write implementation notes for a list of design decisions" "decision-notes-prompt keeps the opening sentence the dispatch guard recognizes the extractor by"
```

Run: `bash tests/sdd/test-sdd-contract.sh`
Expected: `STATUS: PASSED`, with the new line among the passes.

- [ ] **Step 6: Re-digest the page that sources the hooks directory**

`docs/site/advanced/triggering.md` sources the whole `hooks` directory. Its text stays accurate in this task (registration comes in Task 3), so only its digest changes:

```bash
git add hooks/lib/dispatch-guard.mjs hooks/lib/dispatch-guard.test.mjs
bash tests/docs/docs-check.sh --digest docs/site/advanced/triggering.md
```

Set the page's `source-digest:` line to the printed value. Then:

Run: `bash tests/docs/docs-check.sh`
Expected: exit 0.

Run: `bash tests/hooks/test-no-heredocs-in-hooks.sh`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add hooks/lib/dispatch-guard.mjs hooks/lib/dispatch-guard.test.mjs tests/sdd/test-sdd-contract.sh docs/site/advanced/triggering.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(dispatch-guard): the decision module, its unit matrix, and the extractor contract"
```

---

### Task 3: The wrapper, the registration, the wrapper suite and the docs

**Risk tier:** high — the registration makes the guard live for every Agent and SendMessage call, and the wrapper's exit-0 paths are the fail-open property

**Depends on:** Task 2

**Files:**
- Create: `hooks/sdd-dispatch-guard` (mode 755)
- Create: `tests/hooks/test-sdd-dispatch-guard.sh`
- Modify: `hooks/hooks.json` (a `PreToolUse` entry between `SessionStart` and `Stop`)
- Modify: `hooks/lib/dispatch-guard.test.mjs` (append the bench test)
- Modify: `docs/testing.md:23`
- Modify: `CHANGELOG.md` (one bullet at the top of "Unreleased")
- Modify: `docs/site/advanced/sdd-internals.md` (sources line, a paragraph after line 124)
- Modify: `docs/site/advanced/triggering.md:13`
- Modify: `docs/site/skills/subagent-driven-development.md` (sources line, line 10, a bullet after line 98)
- Modify: `source-digest:` of every page `bash tests/docs/docs-check.sh` names (expected: the three above, `docs/site/skills/using-hyperpowers.md`, `docs/site/advanced/customizing.md`, `docs/site/advanced/testing-skills.md`)

**Interfaces:**
- Consumes: `hooks/lib/dispatch-guard.mjs` (Task 2), `main` and its env knobs `XDG_CACHE_HOME`, `DISPATCH_GUARD_FAULT`.
- Produces: the live hook; `DISPATCH_GUARD_BENCH=1` makes the unit matrix print three `# bench` lines.

**Mirror:** `hooks/sdd-stop-guard:1-24` and `tests/hooks/test-sdd-stop-guard.sh:1-89`.

- [ ] **Step 1: Append the bench test**

Append to `hooks/lib/dispatch-guard.test.mjs` (and add `closeSync`, `openSync`, `rmSync`, `writeSync` to its `node:fs` import):

```js
test('benchmark: the step-2 path in-process and through the wrapper; a refusal over a 64 MB transcript', { skip: !process.env.DISPATCH_GUARD_BENCH }, () => {
  const e = planned();
  try {
    // The median of five in-process calls is what a foreground dispatch pays
    // for the decision; the wrapper process adds node start-up and the import,
    // and its bound is a gross-regression check on a shared host.
    const fg = payload(e, 'Agent', { prompt: 'p', run_in_background: false });
    const reps = [];
    for (let i = 0; i < 5; i++) { const t = process.hrtime.bigint(); dg.main(fg, { XDG_CACHE_HOME: e.cache }); reps.push(Number(process.hrtime.bigint() - t) / 1e6); }
    const median = reps.sort((a, b) => a - b)[2];
    console.log(`# bench step-2 in-process ${median.toFixed(2)} ms`); assert.ok(median < 5, `step-2 in-process took ${median} ms`);
    const hook = fileURLToPath(new URL('../sdd-dispatch-guard', import.meta.url));
    const t1 = Date.now();
    const out = execFileSync(hook, [], { input: fg, env: { ...process.env, XDG_CACHE_HOME: e.cache }, encoding: 'utf8' });
    const proc = Date.now() - t1;
    console.log(`# bench step-2 process ${proc} ms`); assert.equal(out, ''); assert.ok(proc < 1000, `step-2 process took ${proc} ms`);
    const big = join(e.root, 'big.jsonl'); const fd = openSync(big, 'w');
    const filler = JSON.stringify(call(5, 'fx', 'Read', { file_path: 'x'.repeat(4000) })) + '\n';
    for (let i = 0; i < Math.ceil(64 * 1024 * 1024 / filler.length); i++) writeSync(fd, filler);
    writeSync(fd, jsonl(syncSession())); closeSync(fd);
    e.transcript = big;
    const t2 = Date.now(); const r = run(e, 'Agent', BG); const capped = Date.now() - t2;
    console.log(`# bench capped-tail refusal ${capped} ms`); assert.equal(r.stdout, deny(BG_TEXT(PLAN))); assert.ok(capped < 2000, `capped-tail refusal took ${capped} ms`);
  } finally { rmSync(e.root, { recursive: true, force: true }); }
});
```

- [ ] **Step 2: Write the wrapper suite (failing)**

`tests/hooks/test-sdd-dispatch-guard.sh`:

```bash
#!/usr/bin/env bash
# The dispatch guard: the node unit matrix with its benchmark, then the bash
# wrapper's own behavior: the registration, both refusals through the wrapper
# and through run-hook.cmd, silence for a foreground or subagent call, and the
# hook-error line when node is missing or the module fails.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/sdd-dispatch-guard"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
FAILURES=0
TEST_ROOT=$(mktemp -d); TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P)
trap 'rm -rf "$TEST_ROOT"' EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "=== dispatch guard: unit matrix ==="
if DISPATCH_GUARD_BENCH=1 node --test "$REPO_ROOT/hooks/lib/dispatch-guard.test.mjs" > "$TEST_ROOT/node.log" 2>&1; then pass "node --test hooks/lib/dispatch-guard.test.mjs"; else fail "node --test hooks/lib/dispatch-guard.test.mjs"; tail -n 40 "$TEST_ROOT/node.log"; fi
grep -E '^# bench' "$TEST_ROOT/node.log" || true

echo "=== dispatch guard: registration ==="
if node -e 'const h=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).hooks.PreToolUse;if(!Array.isArray(h)||h.length!==1||h[0].matcher!=="Agent|SendMessage")process.exit(1);const c=h[0].hooks;if(!Array.isArray(c)||c.length!==1||c[0].type!=="command"||!c[0].command.includes("run-hook.cmd\" sdd-dispatch-guard")||c[0].timeout!==10||c[0].shell!=="bash")process.exit(1)' "$REPO_ROOT/hooks/hooks.json"; then pass "hooks.json registers PreToolUse Agent|SendMessage -> run-hook.cmd sdd-dispatch-guard with a 10 s timeout"; else fail "hooks.json registers PreToolUse Agent|SendMessage -> run-hook.cmd sdd-dispatch-guard with a 10 s timeout"; fi
if grep -q '"PreToolUse"\|sdd-dispatch-guard' "$REPO_ROOT/hooks/hooks-codex.json" "$REPO_ROOT/hooks/hooks-cursor.json" 2>/dev/null; then fail "the Codex and Cursor hook files do not register the guard"; else pass "the Codex and Cursor hook files do not register the guard"; fi
head -n 1 "$HOOK" > "$TEST_ROOT/shebang" 2>/dev/null
if [ -x "$HOOK" ] && grep -q '^#!/usr/bin/env bash$' "$TEST_ROOT/shebang"; then pass "the wrapper is an executable bash script"; else fail "the wrapper is an executable bash script"; fi

echo "=== dispatch guard: wrapper ==="
export XDG_CACHE_HOME="$TEST_ROOT/cache"
repo="$TEST_ROOT/repo"; git init -q -b main "$repo"; git -C "$repo" config user.name t; git -C "$repo" config user.email t@example.com
mkdir -p "$repo/docs"; printf '# Plan\n\n### Task 1: one\n' > "$repo/docs/plan.md"; git -C "$repo" add docs/plan.md; git -C "$repo" commit -q -m plan
key=$(bash -c '. "$1"; hp_key "$2"' _ "$LIB" "$repo")
ws="$XDG_CACHE_HOME/hyperpowers/state/$key/plans/plan-00000000"
printf '%s\n' '{"type":"assistant","timestamp":"2026-11-10T10:00:01.000Z","isSidechain":false,"message":{"role":"assistant","content":[{"type":"tool_use","id":"tu1","name":"Agent","input":{"description":"Implement Task 1","prompt":"brief","run_in_background":false}}]}}' '{"type":"user","timestamp":"2026-11-10T10:00:02.000Z","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu1","content":[{"type":"text","text":"done"}]}]},"toolUseResult":{"status":"completed","agentId":"a1"}}' > "$TEST_ROOT/t.jsonl"
# payload <tool> <tool_input JSON> [<extra fields, each with a leading comma>]
payload() { printf '{"session_id":"s-wrap","transcript_path":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s,"tool_use_id":"toolu_w"%s}' "$TEST_ROOT/t.jsonl" "$repo" "$1" "$2" "${3:-}"; }
LOG="$XDG_CACHE_HOME/hyperpowers/dispatch-guard/s-wrap.jsonl"
out=$(payload Agent '{"prompt":"p","run_in_background":false}' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/dispatch-guard" ]; then pass "a foreground Agent call: exit 0, no output, nothing written"; else fail "a foreground Agent call: exit 0, no output, nothing written (rc=$rc: $out)"; fi
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"no-plan"' "$LOG"; then pass "a background Agent call with no plan passes, logged as no-plan"; else fail "a background Agent call with no plan passes, logged as no-plan (rc=$rc: $out)"; fi
mkdir -p "$ws"; printf '# SDD ledger — plan: docs/plan.md\nsession s-wrap: mode worktree on main at %s started x\n' "$repo" > "$ws/progress.md"
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | bash "$HOOK"); rc=$?
printf '%s' "$out" > "$TEST_ROOT/bg.out"
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/bg.out" && grep -q 'SDD plan docs/plan.md is in progress in this session. On this harness every subagent is dispatched in the foreground' "$TEST_ROOT/bg.out"; then pass "a background Agent call is refused through the wrapper"; else fail "a background Agent call is refused through the wrapper (rc=$rc: $out)"; fi
out=$(payload SendMessage '{"to":"a1","message":"fix it"}' | bash "$REPO_ROOT/hooks/run-hook.cmd" sdd-dispatch-guard); rc=$?
printf '%s' "$out" > "$TEST_ROOT/sm.out"
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/sm.out" && grep -q 'On this harness a SendMessage resume runs in the background' "$TEST_ROOT/sm.out"; then pass "a SendMessage to the session's own subagent is refused through run-hook.cmd"; else fail "a SendMessage to the session's own subagent is refused through run-hook.cmd (rc=$rc: $out)"; fi
if node -e 'const ls=require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").map(JSON.parse).filter(l=>l.decision==="deny");if(ls.length!==2||ls[0].reason!=="background-agent"||ls[1].reason!=="sendmessage-resume"||ls.some(l=>l.tool_use_id!=="toolu_w"||l.plan!=="docs/plan.md"))process.exit(1)' "$LOG"; then pass "both refusals are in the session log with tool_use_id and plan"; else fail "both refusals are in the session log with tool_use_id and plan"; fi
before=$(wc -l < "$LOG")
out=$(payload SendMessage '{"to":"a1","message":"m"}' ',"agent_id":"a9"' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ "$(wc -l < "$LOG")" = "$before" ]; then pass "a subagent's call is silent and unlogged"; else fail "a subagent's call is silent and unlogged (rc=$rc: $out)"; fi
# node absent from PATH: hook-error in the log, exit 0, no output
nopath="$TEST_ROOT/bin"; mkdir -p "$nopath"
for tool in bash date mkdir dirname sed head; do ln -s "$(command -v "$tool")" "$nopath/$tool"; done
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | PATH="$nopath" bash "$HOOK"); rc=$?
tail -n 1 "$LOG" > "$TEST_ROOT/log.last" 2>/dev/null
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"hook-error","detail":"node not found"' "$TEST_ROOT/log.last"; then pass "without node the call passes and hook-error is logged"; else fail "without node the call passes and hook-error is logged (rc=$rc: $out)"; fi
out=$(payload Agent '{"prompt":"p","run_in_background":true}' | DISPATCH_GUARD_FAULT=throw bash "$HOOK"); rc=$?
tail -n 1 "$LOG" > "$TEST_ROOT/log.last" 2>/dev/null
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q '"reason":"hook-error","detail":"module exit 1"' "$TEST_ROOT/log.last"; then pass "a module failure passes and logs hook-error"; else fail "a module failure passes and logs hook-error (rc=$rc: $out)"; fi
if node -e 'const l=JSON.parse(require("fs").readFileSync(0,"utf8"));if(l.session!=="s-wrap"||l.decision!=="allow"||isNaN(Date.parse(l.ts)))process.exit(1)' < "$TEST_ROOT/log.last"; then pass "the hook-error line is well-formed JSON"; else fail "the hook-error line is well-formed JSON"; fi
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass "malformed input exits 0 silently"; else fail "malformed input exits 0 silently (rc=$rc: $out)"; fi
# A session id with path characters, node absent so the bash fallback composes
# the path: the cache tree before and after must be identical.
snapshot() { ( cd "$XDG_CACHE_HOME" && find . -print | sort | while IFS= read -r f; do if [ -f "$f" ]; then printf '%s %s\n' "$(wc -c < "$f")" "$f"; else printf 'dir %s\n' "$f"; fi; done ); }
snapshot > "$TEST_ROOT/cache.before"
rc=0; out=""
for sid in '../../etc/x' '../escaped'; do
  o=$(printf '{"session_id":"%s","cwd":"%s","tool_name":"Agent","tool_input":{"run_in_background":true}}' "$sid" "$repo" | PATH="$nopath" bash "$HOOK"); r=$?
  [ "$r" -eq 0 ] || rc=$r
  out="$out$o"
done
snapshot > "$TEST_ROOT/cache.after"
if [ "$rc" -eq 0 ] && [ -z "$out" ] && cmp -s "$TEST_ROOT/cache.before" "$TEST_ROOT/cache.after"; then pass "a session id with path characters writes nothing"; else fail "a session id with path characters writes nothing (rc=$rc)"; fi
ln -s "$REPO_ROOT/hooks" "$TEST_ROOT/hooks-link"
payload Agent '{"prompt":"p","run_in_background":true}' | bash "$TEST_ROOT/hooks-link/sdd-dispatch-guard" > "$TEST_ROOT/symlink.out" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/symlink.out"; then pass "the guard still refuses when the hooks directory is reached through a symlink"; else fail "the guard still refuses when the hooks directory is reached through a symlink (rc=$rc)"; fi
odd="$TEST_ROOT/plug#in %root"; mkdir -p "$odd"; cp -R "$REPO_ROOT/hooks" "$odd/hooks"
payload Agent '{"prompt":"p","run_in_background":true}' | bash "$odd/hooks/sdd-dispatch-guard" > "$TEST_ROOT/oddpath.out" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' "$TEST_ROOT/oddpath.out"; then pass "the guard still refuses from a plugin root whose path carries # and %"; else fail "the guard still refuses from a plugin root whose path carries # and % (rc=$rc)"; fi
if cat "$TEST_ROOT"/*.out | grep -q '"permissionDecision":"allow"'; then fail "no output in this suite carries an allow"; else pass "no output in this suite carries an allow"; fi

echo ""
if [ "$FAILURES" -gt 0 ]; then echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
echo "STATUS: PASSED"
```

Run: `bash tests/hooks/test-sdd-dispatch-guard.sh`
Expected: FAILED (no wrapper, no registration, the bench test's `execFileSync` fails).

- [ ] **Step 3: Write the wrapper and register it**

`hooks/sdd-dispatch-guard` (then `chmod 755 hooks/sdd-dispatch-guard`):

```bash
#!/usr/bin/env bash
# PreToolUse hook: the SDD dispatch guard. Reads the payload once, hands it to
# the node module, prints the module's output (a deny or nothing), and exits 0
# on every path. When node is missing or the module fails, the call passes and
# a hook-error line goes to the session log, with printf alone and no fencing,
# so that line is best effort.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
input=""
if [ ! -t 0 ]; then IFS= read -r -d '' -t 2 input 2>/dev/null || true; fi
[ -n "$input" ] || exit 0
record_error() { # <detail>
  local sid ts dir
  sid=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$sid" ] || return 0
  case "$sid" in *[!A-Za-z0-9._-]*) return 0 ;; esac
  dir="${XDG_CACHE_HOME:-${HOME:-}/.cache}/hyperpowers/dispatch-guard"
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  mkdir -p "$dir" 2>/dev/null || return 0
  printf '{"ts":"%s","session":"%s","decision":"allow","reason":"hook-error","detail":"%s"}\n' "$ts" "$sid" "$1" >> "$dir/$sid.jsonl" 2>/dev/null || true
}
if ! command -v node >/dev/null 2>&1; then record_error "node not found"; exit 0; fi
out=$(printf '%s' "$input" | node "$SCRIPT_DIR/lib/dispatch-guard.mjs" 2>/dev/null); rc=$?
if [ "$rc" -ne 0 ]; then record_error "module exit $rc"; exit 0; fi
[ -n "$out" ] && printf '%s\n' "$out"
exit 0
```

In `hooks/hooks.json`, between the `SessionStart` array and `"Stop"`:

```json
    "PreToolUse": [
      {
        "matcher": "Agent|SendMessage",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" sdd-dispatch-guard",
            "shell": "bash",
            "timeout": 10
          }
        ]
      }
    ],
```

- [ ] **Step 4: Run the suites**

Run: `bash tests/hooks/test-sdd-dispatch-guard.sh`
Expected: `STATUS: PASSED`, and three `# bench` lines.

Run: `bash tests/hooks/test-sdd-stop-guard.sh`
Expected: `STATUS: PASSED` (its registration check reads only `hooks.Stop`).

Run: `bash tests/hooks/test-no-heredocs-in-hooks.sh`
Expected: PASS.

- [ ] **Step 5: List the suite and the change**

`docs/testing.md:23`: replace `and the bash/node clone-key parity) |` with:

```text
and the bash/node clone-key parity), the SDD dispatch guard (`test-sdd-dispatch-guard.sh` runs `node --test hooks/lib/dispatch-guard.test.mjs` with `DISPATCH_GUARD_BENCH=1`, whose three `# bench` lines it prints (the step-2 decision in-process, the same decision through a real wrapper process, and a refusal over a 64 MB transcript), then the wrapper cases: the registration, both refusals through the wrapper and through `run-hook.cmd`, silence for foreground and subagent calls, and the fail-open paths) |
```

`CHANGELOG.md`, the first bullet under `## Unreleased`:

```markdown
- **The dispatch guard keeps an SDD turn open on Claude Code.** A new PreToolUse hook refuses an SDD controller's `Agent` call with `run_in_background: true`, and its `SendMessage` to one of its own subagents, while the session has a plan ledger, and tells it to dispatch in the foreground instead. Both calls end the turn while the subagent works, so Zed showed the session idle; after a compaction the controller no longer has the skill's foreground rule. The decision extractor's background dispatch passes, a fork-mode session passes, a subagent's own calls pass, and anything the hook cannot read passes. It logs to `~/.cache/hyperpowers/dispatch-guard/<session>.jsonl`.
```

- [ ] **Step 6: Update the docs pages**

`docs/site/advanced/sdd-internals.md`: append ` hooks/sdd-dispatch-guard hooks/lib/dispatch-guard.mjs docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md` to its `sources:` line, and add this paragraph, with a blank line before it, after line 124 (the stop-guard paragraph, which begins "{source}`hooks/hooks.json` registers a `Stop` hook"):

```markdown
{source}`hooks/hooks.json` also registers a `PreToolUse` hook for `Agent` and `SendMessage`, {source}`hooks/sdd-dispatch-guard`, with its logic in {source}`hooks/lib/dispatch-guard.mjs`. It refuses the two calls that end the controller's turn while a subagent works: an `Agent` call with `run_in_background: true`, and a `SendMessage` to one of this session's own subagents, an agent id its own `Agent` results recorded. It refuses only the controller of a session with a plan ledger, and only outside fork mode, which it reads from the session's own `Agent` results: one that came back in the foreground shows the harness honours `run_in_background: false`. The decision extractor's background dispatch passes; the hook recognizes it by the template's opening sentence. The refusal tells the controller to dispatch again in the foreground, or, for a resume, to dispatch a fresh foreground subagent with the brief path, the report-file path and what it meant to send. A subagent's own calls, a session with no plan, a fork-mode session, and anything the hook cannot read pass. There is no refusal cap, because the foreground dispatch is always available. Each decision past the first payload checks is logged to `~/.cache/hyperpowers/dispatch-guard/<session>.jsonl`. The design is in {source}`docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md`.
```

`docs/site/advanced/triggering.md:13`: replace `The same file also registers a `Stop` hook, the SDD stop guard, which plays no part in the bootstrap; {doc}`sdd-internals` covers it.` with:

```markdown
The same file also registers a `Stop` hook, the SDD stop guard, and a `PreToolUse` hook for `Agent` and `SendMessage`, the SDD dispatch guard. Neither plays a part in the bootstrap; {doc}`sdd-internals` covers both.
```

`docs/site/skills/subagent-driven-development.md`: append ` hooks/sdd-dispatch-guard hooks/lib/dispatch-guard.mjs` to its `sources:` line; on line 10 replace `the Codex task and final gates and the stop guard run on Claude Code only` with `the Codex task and final gates, the stop guard and the dispatch guard run on Claude Code only`; after line 98 add:

```markdown
- {source}`hooks/sdd-dispatch-guard` is the Claude Code PreToolUse hook that refuses a background `Agent` dispatch, or a `SendMessage` to one of the session's own subagents, while a plan is in progress outside fork mode, and {source}`hooks/lib/dispatch-guard.mjs` holds its logic.
```

Re-read `docs/site/skills/using-hyperpowers.md`, `docs/site/advanced/customizing.md` and `docs/site/advanced/testing-skills.md` against the changed sources (`hooks/hooks.json`, `docs/testing.md`) and correct any sentence they make false. Then:

```bash
git add hooks/sdd-dispatch-guard tests/hooks/test-sdd-dispatch-guard.sh
bash tests/docs/docs-check.sh
```

For each page it names, `bash tests/docs/docs-check.sh --digest <page>` and set that page's `source-digest:`. Run `bash tests/docs/docs-check.sh` again.
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add hooks/sdd-dispatch-guard hooks/hooks.json hooks/lib/dispatch-guard.test.mjs tests/hooks/test-sdd-dispatch-guard.sh docs/testing.md CHANGELOG.md docs/site
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(dispatch-guard): register the PreToolUse hook, its wrapper and suite, and document it"
```

---

### Task 4: The evidence note, preregistered

**Risk tier:** standard — the criteria every later result is judged by, committed before any run

**Depends on:** Task 1

**Files:**
- Create: `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md`

**Interfaces:**
- Consumes: `task-1-probe/findings.md` and the evals commit that holds it (Task 1).
- Produces: the note whose `## Results` subsections Tasks 6, 9 and 10 fill.

**Mirror:** `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md:1-40`.

- [ ] **Step 1: Write the note**

Fill `<claude-code>`, the seven probe lines (verbatim from `findings.md`) and `<evals commit>` (Task 1's commit, `git -C /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt log -1 --format=%h -- evidence/2026-11-10-sdd-dispatch-guard/task-1-probe`). Everything else is verbatim.

````markdown
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
with `=1`. Artifacts: `task-1-probe/` (evals `<evals commit>`).

```text
<the seven lines of findings.md, verbatim>
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
````

- [ ] **Step 2: Commit**

```bash
git add docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(hyperpowers): preregister the dispatch guard's evidence criteria"
```

---

### Task 5: The field replay tool

**Risk tier:** high — a new evidence script whose output the replay criterion trusts

**Depends on:** Task 2

**Files (hyperpowers-evals worktree, under `evidence/2026-11-10-sdd-dispatch-guard/`):**
- Create: `field/manifest.tsv`, `field/manifest.py`, `field/field_reread.py`
- Create: `replay.mjs`
- Create: `replay.test.mjs`

**Interfaces:**
- Consumes: from the hp module (loaded by path): `screen(input)`, `transcriptFacts(lines)`, `decideDispatch({...})`.
- Produces: `node replay.mjs --module <path> --manifest <tsv> --projects <dir> --out <dir>` writing `calls.tsv`, `refusals.tsv`, `context.tsv`, `summary.txt`; exit 1 on a manifest mismatch, 2 on a usage error.

**Mirror:** `/Users/johnss51/.cache/hyperpowers/zed-idle-2026-11-10/manifest.py` (the hash and count rules this script must reproduce).

- [ ] **Step 1: Freeze the corpus manifest**

```bash
EV=/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt/evidence/2026-11-10-sdd-dispatch-guard
mkdir -p "$EV/field"
cp /Users/johnss51/.cache/hyperpowers/zed-idle-2026-11-10/replay-manifest.tsv "$EV/field/manifest.tsv"
cp /Users/johnss51/.cache/hyperpowers/zed-idle-2026-11-10/manifest.py /Users/johnss51/.cache/hyperpowers/zed-idle-2026-11-10/field_reread.py "$EV/field/"
cut -f2-5 "$EV/field/manifest.tsv"
```

Expected: ten rows whose session, counts and hash equal the spec's table row for row.

- [ ] **Step 2: Write the failing tests**

`replay.test.mjs`:

```js
// Run: HP_MODULE=<hp root>/hooks/lib/dispatch-guard.mjs node --test replay.test.mjs
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { pathToFileURL } from 'node:url';
import { CUTOFF, main, parseManifest, prefixLines, replaySession, scanSession } from './replay.mjs';

if (!process.env.HP_MODULE) throw new Error('set HP_MODULE to hooks/lib/dispatch-guard.mjs in an hp checkout');
const mod = await import(pathToFileURL(process.env.HP_MODULE).href);

const call = (ts, id, name, input, extra = {}) => ({ type: 'assistant', timestamp: ts, isSidechain: false, message: { role: 'assistant', content: [{ type: 'tool_use', id, name, input }] }, ...extra });
const result = (ts, id, toolUseResult) => ({ type: 'user', timestamp: ts, isSidechain: false, message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id, content: [{ type: 'text', text: 'ok' }] }] }, toolUseResult });
const SYNC = (agentId) => ({ status: 'completed', agentId });
const BG = { description: 'Review Task 1', prompt: 'review', run_in_background: true };
// In the window, before the cutoff.
const T = (m) => `2026-11-08T10:${String(m).padStart(2, '0')}:00.000Z`;
const session = () => [
  call(T(0), 'tu0', 'Skill', { skill: 'hyperpowers:subagent-driven-development' }),
  call(T(1), 'tu1', 'Agent', { description: 'Implement Task 1', prompt: 'brief', run_in_background: false }),
  result(T(2), 'tu1', SYNC('a1')),
  call(T(3), 'tu2', 'Agent', BG),
  call(T(4), 'tu3', 'SendMessage', { to: 'a1', message: 'fix' }),
  call(T(5), 'tu4', 'Agent', { prompt: 'You write implementation notes for a list of design decisions. You do not judge.', run_in_background: true }),
  call(T(6), 'tu5', 'Agent', { prompt: 'p', run_in_background: false }, { isSidechain: true }),
];
const toBuf = (lines) => Buffer.from(lines.join('\n') + '\n');
const expectedSha = (rawLines) => { const h = createHash('sha256'); for (const l of rawLines) h.update(l + '\n'); return h.digest('hex').slice(0, 12); };

test('parseManifest reads the five tab-separated columns', () => {
  assert.deepEqual(parseManifest('dir\tsid\t3\t1\tabcdef012345\n\n'), [{ projectDir: 'dir', session: 'sid', agent: 3, send: 1, sha: 'abcdef012345' }]);
});
test('scanSession hashes the parseable lines up to the cutoff and counts main-chain calls in the window', () => {
  const early = JSON.stringify(call('2026-11-05T00:00:00.000Z', 'tz', 'Agent', BG));
  const recs = session().map((r) => JSON.stringify(r));
  const after = JSON.stringify(call('2026-11-10T18:10:01.000Z', 'ty', 'Agent', BG));
  const lines = [early, 'not json', ...recs, after, JSON.stringify(call(T(9), 'tx', 'Agent', BG))];
  const s = scanSession(toBuf(lines));
  assert.equal(s.agent, 3); assert.equal(s.send, 1);
  assert.equal(s.sha, expectedSha([early, ...recs]));
  assert.deepEqual(s.calls.map((c) => c.id), ['tu1', 'tu2', 'tu3', 'tu4']);
});
test('prefixLines yields the call line and earlier lines newest first, then null at the cap', () => {
  const lines = ['{"a":1}', '{"b":22}', '{"c":333}'];
  const buf = toBuf(lines); const s = scanSession(buf);
  assert.deepEqual([...prefixLines(buf, s.all, 2, 1000)], ['{"c":333}', '{"b":22}', '{"a":1}']);
  assert.deepEqual([...prefixLines(buf, s.all, 2, 20)], ['{"c":333}', '{"b":22}', null]);
});
test('replaySession decides each call from the transcript before it', () => {
  const buf = toBuf(session().map((r) => JSON.stringify(r)));
  const s = scanSession(buf);
  const rows = replaySession(mod, { session: 'sid' }, buf, s);
  assert.deepEqual(rows.map((r) => [r.tool_use_id, r.step, r.decision, r.reason]), [
    ['tu1', 'screened', 'allow', 'foreground'],
    ['tu2', 'decided', 'deny', 'background-agent'],
    ['tu3', 'decided', 'deny', 'sendmessage-resume'],
    ['tu4', 'extractor', 'allow', 'extractor'],
  ]);
});
test('a synchronous result after a call does not refuse it', () => {
  const recs = [call(T(1), 'tu2', 'Agent', BG), call(T(2), 'tu1', 'Agent', { prompt: 'p', run_in_background: false }), result(T(3), 'tu1', SYNC('a1'))];
  const buf = toBuf(recs.map((r) => JSON.stringify(r)));
  const rows = replaySession(mod, { session: 'sid' }, buf, scanSession(buf));
  assert.equal(rows[0].reason, 'fork-mode');
});
test('scanSession lists the context a hand classification needs', () => {
  const recs = [...session(), call(T(7), 'tu6', 'Bash', { command: 'bash scripts/sdd-state finish docs/plan.md --session sid' }), { type: 'user', timestamp: T(8), isSidechain: false, isCompactSummary: true, message: { role: 'user', content: 'summary' } }];
  const s = scanSession(toBuf(recs.map((r) => JSON.stringify(r))));
  assert.deepEqual(s.context.map((c) => [c.ts, c.kind]), [[T(0), 'sdd-skill'], [T(7), 'sdd-cmd'], [T(7), 'sdd-finish'], [T(8), 'compaction']]);
});
test('main stops on a manifest mismatch and writes nothing; on a match it writes the four files', async () => {
  const root = mkdtempSync(join(tmpdir(), 'replay-'));
  const projects = join(root, 'projects'); mkdirSync(join(projects, 'dir'), { recursive: true });
  const lines = session().map((r) => JSON.stringify(r));
  writeFileSync(join(projects, 'dir', 'sid.jsonl'), lines.join('\n') + '\n');
  const bad = join(root, 'bad.tsv'); writeFileSync(bad, 'dir\tsid\t9\t1\t000000000000\n');
  const outBad = join(root, 'out-bad');
  assert.equal(await main(['--module', process.env.HP_MODULE, '--manifest', bad, '--projects', projects, '--out', outBad]), 1);
  assert.equal(existsSync(outBad), false);
  const good = join(root, 'good.tsv'); writeFileSync(good, `dir\tsid\t3\t1\t${expectedSha(lines)}\n`);
  const out = join(root, 'out');
  assert.equal(await main(['--module', process.env.HP_MODULE, '--manifest', good, '--projects', projects, '--out', out]), 0);
  const refusals = readFileSync(join(out, 'refusals.tsv'), 'utf8').trim().split('\n');
  assert.equal(refusals[0], 'session\tts\ttool\ttool_use_id\treason\tto\tdescription\tclass\tevidence');
  assert.equal(refusals.length, 3);
  for (const f of ['calls.tsv', 'context.tsv', 'summary.txt']) assert.ok(existsSync(join(out, f)));
  assert.match(readFileSync(join(out, 'summary.txt'), 'utf8'), /^calls 4 \(agent 3, sendmessage 1\)$/m);
});
test('the cutoff is the spec\'s', () => { assert.equal(CUTOFF, '2026-11-10T18:10:00Z'); });
```

Run: `HP_MODULE=/Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard/hooks/lib/dispatch-guard.mjs node --test replay.test.mjs` (from the evidence directory)
Expected: FAIL, `Cannot find module './replay.mjs'`.

- [ ] **Step 3: Write replay.mjs**

```js
#!/usr/bin/env node
// replay.mjs: the dispatch guard's field replay (spec "Field replay", plan
// Task 5). Every main-chain Agent and SendMessage call in the frozen corpus
// runs through the guard's own screen and decideDispatch, with discovery
// forced to a ledger and the transcript facts read from the transcript up to
// that call under the guard's 16 MB cap. The counts and sha256 prefixes in the
// manifest are recomputed first, by field/manifest.py's rules; any
// disagreement stops the replay before a call is decided.
//
// node replay.mjs --module <hp root>/hooks/lib/dispatch-guard.mjs \
//   --manifest field/manifest.tsv --projects ~/.claude/projects --out <dir>
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

export const CUTOFF = '2026-11-10T18:10:00Z';
export const WINDOW_START = '2026-11-06T21:00:00Z';
export const TAIL_CAP = 16 * 1024 * 1024;
const SDD_SKILL = /subagent-driven-development/;
const SDD_CMD = /\b(sdd-state|sdd-dir)\b/;
const FINISH = /\bsdd-state\b[^;&|\n]*\bfinish\b/;

export function parseManifest(text) {
  return text.split('\n').filter((l) => l.trim()).map((l) => {
    const [projectDir, session, agent, send, sha] = l.split('\t');
    return { projectDir, session, agent: Number(agent), send: Number(send), sha };
  });
}

const textOf = (rec) => { const c = rec?.message?.content; if (typeof c === 'string') return c; if (Array.isArray(c)) return c.filter((b) => b?.type === 'text').map((b) => b.text || '').join('\n'); return ''; };

// One pass, as manifest.py reads a transcript: lines split on 0x0a with the
// newline kept; a line that does not parse is skipped and not hashed; the
// scan stops at the first record stamped after the cutoff. `all` keeps every
// line's offsets, parseable or not, because the live reader's cap counts
// every byte.
export function scanSession(buf, { cutoff = CUTOFF, windowStart = WINDOW_START } = {}) {
  const h = createHash('sha256');
  const all = []; const calls = []; const context = [];
  let agent = 0; let send = 0; let start = 0;
  while (start < buf.length) {
    const nl = buf.indexOf(0x0a, start);
    const end = nl === -1 ? buf.length : nl + 1;
    const raw = buf.subarray(start, end);
    let rec; let parsed = true;
    try { rec = JSON.parse(raw.toString('utf8')); } catch { parsed = false; }
    if (parsed) {
      const isRecord = rec !== null && typeof rec === 'object' && !Array.isArray(rec);
      const ts = isRecord ? rec.timestamp : undefined;
      if (ts && ts > cutoff) break;
      h.update(raw);
      const index = all.length;
      all.push({ start, end });
      if (isRecord && !rec.isSidechain) {
        if (rec.isCompactSummary) context.push({ ts: ts || '', kind: 'compaction', detail: '' });
        if (rec.type === 'user' && textOf(rec).includes('subagent-driven-development</command-name>')) context.push({ ts: ts || '', kind: 'sdd-skill', detail: 'slash command' });
        if (rec.type === 'assistant') {
          for (const b of rec.message?.content || []) {
            if (b?.type !== 'tool_use') continue;
            const input = b.input && typeof b.input === 'object' ? b.input : {};
            if (b.name === 'Skill' && SDD_SKILL.test(String(input.skill || ''))) context.push({ ts: ts || '', kind: 'sdd-skill', detail: String(input.skill) });
            if (b.name === 'Bash' && typeof input.command === 'string') {
              const cmd = input.command.replace(/\\\n/g, ' ');
              if (SDD_CMD.test(cmd)) context.push({ ts: ts || '', kind: 'sdd-cmd', detail: cmd.replace(/\s+/g, ' ').slice(0, 160) });
              if (FINISH.test(cmd)) context.push({ ts: ts || '', kind: 'sdd-finish', detail: '' });
            }
            if (!ts || ts < windowStart) continue;
            if (b.name === 'Agent') agent++; else if (b.name === 'SendMessage') send++; else continue;
            calls.push({ index, ts, name: b.name, id: b.id, input });
          }
        }
      }
    } else {
      all.push({ start, end });
    }
    start = end;
  }
  return { agent, send, sha: h.digest('hex').slice(0, 12), all, calls, context };
}

// The transcript up to and including the call's own line, newest first, as
// linesFromEnd yields it: whole lines while they fit under the cap, then null
// when the cap stops the read before the file's start.
export function* prefixLines(buf, all, index, cap = TAIL_CAP) {
  let read = 0;
  for (let i = index; i >= 0; i--) {
    const { start, end } = all[i];
    read += end - start;
    if (read > cap) { yield null; return; }
    yield buf.subarray(start, end).toString('utf8').replace(/\n$/, '');
  }
}

const cell = (v) => String(v ?? '').replace(/[\t\n\r]/g, ' ');

export function replaySession(mod, row, buf, scan, { cap = TAIL_CAP } = {}) {
  const out = [];
  for (const c of scan.calls) {
    const base = {
      session: row.session, ts: c.ts, tool: c.name, tool_use_id: c.id,
      to: typeof c.input.to === 'string' ? c.input.to : '',
      run_in_background: JSON.stringify(c.input.run_in_background ?? null),
      description: cell(c.input.description).slice(0, 80),
    };
    const s = mod.screen({ session_id: row.session, tool_name: c.name, tool_input: c.input });
    if (s.done) { out.push({ ...base, step: s.log ? 'extractor' : 'screened', decision: 'allow', reason: s.log || 'foreground' }); continue; }
    const facts = mod.transcriptFacts(prefixLines(buf, scan.all, c.index, cap));
    const d = mod.decideDispatch({ tool: s.tool, toolInput: s.toolInput, discovery: { kind: 'ledger', workspace: 'replay', ledger: 'replay' }, plan: { plan: 'replay' }, facts });
    out.push({ ...base, step: 'decided', decision: d.decision, reason: d.reason });
  }
  return out;
}

const tsv = (cols, rows) => [cols.join('\t'), ...rows.map((r) => cols.map((c) => cell(r[c])).join('\t'))].join('\n') + '\n';

export async function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[String(argv[i]).replace(/^--/, '')] = argv[i + 1];
  for (const k of ['module', 'manifest', 'projects', 'out']) if (!args[k]) { console.error(`replay: missing --${k}`); return 2; }
  const mod = await import(pathToFileURL(realpathSync(args.module)).href);
  const rows = parseManifest(readFileSync(args.manifest, 'utf8'));
  const pathOf = (row) => join(args.projects, row.projectDir, `${row.session}.jsonl`);
  // Pass 1 verifies the whole corpus, holding one transcript at a time.
  const problems = [];
  for (const row of rows) {
    let buf; try { buf = readFileSync(pathOf(row)); } catch (err) { problems.push(`${row.session}: unreadable (${err.code})`); continue; }
    const s = scanSession(buf);
    if (s.agent !== row.agent || s.send !== row.send || s.sha !== row.sha) problems.push(`${row.session}: manifest ${row.agent}/${row.send}/${row.sha}, recomputed ${s.agent}/${s.send}/${s.sha}`);
  }
  if (problems.length) { for (const p of problems) console.error(`replay: manifest mismatch: ${p}`); return 1; }
  // Pass 2 decides every call.
  const calls = []; const context = [];
  for (const row of rows) {
    const buf = readFileSync(pathOf(row));
    const s = scanSession(buf);
    calls.push(...replaySession(mod, row, buf, s));
    context.push(...s.context.map((c) => ({ session: row.session, ...c })));
  }
  mkdirSync(args.out, { recursive: true });
  writeFileSync(join(args.out, 'calls.tsv'), tsv(['session', 'ts', 'tool', 'tool_use_id', 'step', 'decision', 'reason', 'to', 'run_in_background', 'description'], calls));
  const denies = calls.filter((c) => c.decision === 'deny');
  writeFileSync(join(args.out, 'refusals.tsv'), tsv(['session', 'ts', 'tool', 'tool_use_id', 'reason', 'to', 'description', 'class', 'evidence'], denies.map((c) => ({ ...c, class: '', evidence: '' }))));
  writeFileSync(join(args.out, 'context.tsv'), tsv(['session', 'ts', 'kind', 'detail'], context));
  const byReason = {};
  for (const c of calls) byReason[c.reason] = (byReason[c.reason] || 0) + 1;
  const agentN = calls.filter((c) => c.tool === 'Agent').length;
  const summary = [`calls ${calls.length} (agent ${agentN}, sendmessage ${calls.length - agentN})`, `refusals ${denies.length}`, ...Object.keys(byReason).sort().map((k) => `reason ${k} ${byReason[k]}`)];
  writeFileSync(join(args.out, 'summary.txt'), summary.join('\n') + '\n');
  console.log(summary.join('\n'));
  return 0;
}

let mainPath = process.argv[1] || '';
try { if (mainPath) mainPath = realpathSync(mainPath); } catch { /* compare the raw path */ }
if (mainPath && import.meta.url === pathToFileURL(mainPath).href) process.exitCode = await main(process.argv.slice(2));
```

- [ ] **Step 4: Run the tests**

Run (from the evidence directory): `HP_MODULE=/Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard/hooks/lib/dispatch-guard.mjs node --test replay.test.mjs`
Expected: PASS, every test.

- [ ] **Step 5: Commit in the evals worktree**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
git add evidence/2026-11-10-sdd-dispatch-guard/field evidence/2026-11-10-sdd-dispatch-guard/replay.mjs evidence/2026-11-10-sdd-dispatch-guard/replay.test.mjs
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "evidence(sdd-dispatch-guard): frozen corpus manifest and the field replay tool"
```

---

### Task 6: Run the field replay and classify every refusal

**Risk tier:** standard — hand classification against the transcripts, with a pass criterion fixed in Task 4

**Depends on:** Task 3, Task 4, Task 5

**Files:**
- Create (evals): `evidence/2026-11-10-sdd-dispatch-guard/task-6-replay/{calls.tsv,refusals.tsv,context.tsv,summary.txt,replay.out,pin.txt}`
- Modify (hp): `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md` (`### Field replay`)

**Interfaces:**
- Consumes: `replay.mjs` (Task 5); the hp branch head with Task 3's code.
- Produces: the treatment root at `/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/hp-treatment` and its pin in `task-6-replay/pin.txt`, used by Tasks 9 and 10.

- [ ] **Step 1: Create the treatment root**

```bash
pin=$(git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard rev-parse HEAD)
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard worktree add --detach /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/hp-treatment "$pin"
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard diff --stat "$pin" -- hooks
```

Expected: the worktree exists; the diff is empty (the pin holds Task 3's hook code). Write `$pin` and the output of `git -C /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/hp-treatment log -1 --format='%H %s'` to `task-6-replay/pin.txt`.

- [ ] **Step 2: Run the replay**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt/evidence/2026-11-10-sdd-dispatch-guard
node --max-old-space-size=8192 replay.mjs --module /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/hp-treatment/hooks/lib/dispatch-guard.mjs --manifest field/manifest.tsv --projects /Users/johnss51/.claude/projects --out task-6-replay > task-6-replay/replay.out 2>&1
echo "exit $?"
```

Expected: `exit 0`, and `summary.txt` starts `calls 329 (agent 286, sendmessage 43)`. Exit 1 is a manifest mismatch, and the manifest is never edited. First compare `scanSession`'s reading rule with `field/manifest.py` (line splitting, which lines are skipped, the cutoff test, the count rule) on the session `replay.out` names: a difference there is a `replay.mjs` defect, fixed with a test in `replay.test.mjs` and committed before the replay is run again. If the two rules agree, the corpus changed: report BLOCKED with `replay.out`.

Correction (2026-11-10): the replay runs on a frozen copy of the corpus. Task 5's Codex gate found manifest row 8 (ae183251) no longer matching its live transcript: the transcript's first 14231 lines still hash to `8f47c39aad88`, but a resume at 22:12Z appended a timestamp-less `tools-used` record before the first post-cutoff record, and the manifest's stop rule stops only at a timestamped record. Your human partner chose to freeze a copy over re-freezing the corpus or stopping. Task 5's fix round 1 added `freeze.mjs`, which cuts each transcript at the first line where the manifest rule's hash and both counts equal its row, and refuses a row when no line matches or when a dropped line carries a timestamp. Before Step 2, run from the evidence directory:

```bash
node --max-old-space-size=8192 freeze.mjs --manifest field/manifest.tsv --projects /Users/johnss51/.claude/projects --out /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/corpus > task-6-replay/freeze.out 2>&1
echo "exit $?"
cp /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/corpus/freeze.tsv task-6-replay/freeze.tsv
```

Expected: `exit 0`, and `freeze.tsv` shows row 8 dropping one `tools-used` line (a session resumed since may drop further timestamp-less lines; record them). A nonzero exit is BLOCKED with `freeze.out`. Then run Step 2 with `--projects /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/corpus` in place of `/Users/johnss51/.claude/projects`. The copies hold private transcripts and are never committed; `freeze.tsv` is, with each copy's full sha256. Step 4's result adds one sentence after its first line: `Run on a frozen copy of the corpus (task-6-replay/freeze.tsv): <the lines each row dropped, by session and type>.`

- [ ] **Step 3: Classify every refusal**

For each row of `refusals.tsv`, fill `class` and `evidence`. Use `context.tsv` (the session's SDD skill invocations, `sdd-state`/`sdd-dir` commands, Finish calls and compactions) and the transcript itself (read by line number or timestamp with a streaming script; never grep a 290 MB transcript with long context).

- `outside`: the call precedes the session's first `sdd-skill` event, or a `sdd-finish` event lies between the most recent `sdd-skill` event and the call. Evidence: the two timestamps.
- `expected`: inside a plan, and the call is a background `Agent` dispatch (forbidden by SKILL.md line 505 on main, line 434 at v6.17.0: "Where the Agent tool offers `run_in_background`, dispatch with it false") or a `SendMessage` resume of the session's own subagent (forbidden by line 406 and lines 636-644 on main, lines 356 and 565-573 at v6.17.0). Evidence: the `sdd-skill` timestamp, the role of the dispatch (description or the resumed agent's original description), and the line it breaks.
- `false`: inside a plan, and the skill allows the call: the decision extractor whose prompt lost the template sentence, or any call the two `expected` rules do not cover. Also `false`: any row the evidence cannot place.

Then check: no `false` row, and rows for ec562ba3 at 07:22, 17:47 and 18:02 on 2026-11-10 are present and `expected`.

If a `false` row exists, or one of the three ec562ba3 calls is missing (for example because it read `transcript-capped`), stop and report BLOCKED with the rows: either outcome is a plan conflict for your human partner.

- [ ] **Step 4: Record the result**

Replace `Pending.` under `### Field replay` in the hp evidence note with the text below, leaving the literal `EVALS_COMMIT` for Step 5 to replace once the evals commit exists:

```markdown
Date <date>; pin `<short pin>`; evals `EVALS_COMMIT`; artifacts `task-6-replay/`.
<calls line from summary.txt>; <N> refusals: <n_expected> expected, <n_outside> outside a plan, 0 false. ec562ba3's 07:22, 17:47 and 18:02 calls are expected refusals (<their reasons>). Pass.
```

- [ ] **Step 5: Commit both repositories**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
git add evidence/2026-11-10-sdd-dispatch-guard/task-6-replay
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "evidence(sdd-dispatch-guard): field replay over the frozen corpus, refusals classified"
ec=$(git rev-parse --short HEAD)
cd /Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard
sed -i '' "s/EVALS_COMMIT/$ec/g" docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
grep -c EVALS_COMMIT docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
git add docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(hyperpowers): dispatch guard field replay result"
```

Expected: the evals commit exists before the note names it; the `grep -c` prints `0`; both scans print `hits: 0`. Nothing is amended.

---

### Task 7: The scenarios

**Risk tier:** high — the scenario's checks feed quorum's verdict and its fixture decides whether the refusals are provoked at all

**Depends on:** Task 1

**Files (hyperpowers-evals worktree):**
- Create: `fixtures/sdd-dispatch-guard/{design.md,plan.md,textstats/__init__.py,tests/__init__.py}`
- Modify: `src/setup-helpers/sdd-fixtures.ts` (a helper after `scaffoldSddTurnLiveness`, line 579)
- Modify: `src/setup-helpers/registry.ts:36,119`
- Modify: `test/setup-helpers-sdd.test.ts` (one test after the `scaffoldSddTurnLiveness` test)
- Create: `scenarios/sdd-dispatch-guard/{story.md,setup.sh,checks.sh}`
- Create: `scenarios/sdd-dispatch-guard-fork/{story.md,setup.sh,checks.sh}`
- Modify: `test/scenario-pinning.test.ts` (comment, set, two window tests)

**Interfaces:**
- Produces: setup helper `scaffold_sdd_dispatch_guard`; scenarios `sdd-dispatch-guard` (fork mode off) and `sdd-dispatch-guard-fork` (fork mode left on).

**Mirror:** evals `scenarios/sdd-turn-liveness/*`, `src/setup-helpers/sdd-fixtures.ts:569-579`, `test/scenario-pinning.test.ts:103-135`.

- [ ] **Step 1: Write the failing helper and pinning tests**

In `test/setup-helpers-sdd.test.ts`, add `scaffoldSddDispatchGuard,` to the `../src/setup-helpers/sdd-fixtures.ts` import on the line after `scaffoldSddBrokenPlan,` and, after the `scaffoldSddTurnLiveness` test (which starts at line 36):

```ts
  test('scaffoldSddDispatchGuard copies the tree and commits it', () => {
    const dir = tmp();
    try {
      scaffoldSddDispatchGuard({ workdir: dir } as never);
      expect(runGit(['log', '--format=%s'], dir).trim()).toBe(
        'initial: design, plan and package skeleton',
      );
      for (const f of [
        'design.md',
        'plan.md',
        'textstats/__init__.py',
        'tests/__init__.py',
      ]) {
        expect(existsSync(join(dir, f))).toBe(true);
      }
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
```

In `test/scenario-pinning.test.ts`, add these lines to the comment block above `INTENTIONAL_PINNED_SCENARIOS`, after the line `// same Claude Code behavior.` (which ends the `sdd-turn-liveness-fork` sentences):

```ts
// `sdd-dispatch-guard` measures what the SDD dispatch guard, a Claude Code
// PreToolUse hook, refuses during SDD and what the controller does next, and
// asserts on Claude Code's `Agent` dispatch tool; `sdd-dispatch-guard-fork`
// is the same scenario with fork subagent mode left on, where the guard must
// refuse nothing. Both measure Claude Code behavior only.
```

Add `'sdd-dispatch-guard',` and `'sdd-dispatch-guard-fork',` to `INTENTIONAL_PINNED_SCENARIOS` after `'sdd-de-minimis-carveout',`, and at the end of the file:

```ts
// The dispatch guard's scenario must run with fork mode off and the task
// tools on, as the field's SDK sessions do; a directive pushed out of the
// 21-line window would run it in fork mode, where the guard refuses nothing.
test('the sdd-dispatch-guard claude-env directive is read inside the window', () => {
  const checksSh = join(repoRoot(), 'scenarios', 'sdd-dispatch-guard', 'checks.sh');
  expect(parseClaudeEnvDirective(checksSh)).toEqual({
    CLAUDE_CODE_ENABLE_TODO_TOOLS: '1',
    CLAUDE_CODE_FORK_SUBAGENT: '0',
  });
});

// The fork copy leaves fork mode on by design, so its directive sets the task
// tools alone.
test('the sdd-dispatch-guard-fork claude-env directive is read inside the window', () => {
  const checksSh = join(repoRoot(), 'scenarios', 'sdd-dispatch-guard-fork', 'checks.sh');
  expect(parseClaudeEnvDirective(checksSh)).toEqual({
    CLAUDE_CODE_ENABLE_TODO_TOOLS: '1',
  });
});
```

Run: `bun test test/setup-helpers-sdd.test.ts test/scenario-pinning.test.ts`
Expected: FAIL (no helper export, no scenarios).

- [ ] **Step 2: Write the fixture**

`fixtures/sdd-dispatch-guard/textstats/__init__.py` and `fixtures/sdd-dispatch-guard/tests/__init__.py`: empty files.

`fixtures/sdd-dispatch-guard/design.md`:

```markdown
# textstats: Design

`textstats` counts words and lines in a piece of text, for a command-line
report the docs team runs on draft chapters.

## Requirements

1. `count_words(text)` returns the number of words in `text`. A word is a
   maximal run of non-whitespace characters, so spaces, tabs and newlines all
   separate words, and a run of whitespace counts once. Empty or
   whitespace-only text has 0 words.
2. `report(text)` returns a dict `{"words": <int>, "lines": <int>}`, where
   `lines` is the number of lines `str.splitlines()` finds.
3. Standard library only. Tests use `unittest` and run with
   `python3 -m unittest discover -s tests`.
```

`fixtures/sdd-dispatch-guard/plan.md` (Task 1's code splits on single spaces, which misses requirement 1; the task reviewer is meant to find it):

````markdown
# textstats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** design.md

**Goal:** A `textstats` package with a word counter and a report.

**Architecture:** Two modules in `textstats/`: `count.py` holds `count_words`, and `report.py` builds the report from it.

**Tech Stack:** Python 3 standard library, `unittest`.

## Global Constraints

- Standard library only.
- Tests run with `python3 -m unittest discover -s tests`.

## Grounding

- none: the package is new; `textstats/__init__.py` and `tests/__init__.py` are empty.

---

### Task 1: count_words

**Risk tier:** standard — a new module and a new test file

**Files:**
- Create: `textstats/count.py`
- Test: `tests/test_count.py`

- [ ] **Step 1: Write the failing test**

```python
import unittest

from textstats.count import count_words


class CountWordsTest(unittest.TestCase):
    def test_counts_words_separated_by_spaces(self):
        self.assertEqual(count_words("the quick brown fox"), 4)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 -m unittest discover -s tests`
Expected: FAIL with `ModuleNotFoundError: No module named 'textstats.count'`

- [ ] **Step 3: Implement**

```python
def count_words(text):
    return len(text.split(" "))
```

- [ ] **Step 4: Run the tests**

Run: `python3 -m unittest discover -s tests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add textstats/count.py tests/test_count.py
git commit -m "feat: count_words"
```

### Task 2: report

**Risk tier:** standard — a new module and a new test file

**Files:**
- Create: `textstats/report.py`
- Test: `tests/test_report.py`

- [ ] **Step 1: Write the failing test**

```python
import unittest

from textstats.report import report


class ReportTest(unittest.TestCase):
    def test_reports_words_and_lines(self):
        self.assertEqual(report("one two\nthree four"), {"words": 4, "lines": 2})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 -m unittest discover -s tests`
Expected: FAIL with `ModuleNotFoundError: No module named 'textstats.report'`

- [ ] **Step 3: Implement**

```python
from textstats.count import count_words


def report(text):
    return {"words": count_words(text), "lines": len(text.splitlines())}
```

- [ ] **Step 4: Run the tests**

Run: `python3 -m unittest discover -s tests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add textstats/report.py tests/test_report.py
git commit -m "feat: report"
```
````

- [ ] **Step 3: Write the helper and register it**

In `src/setup-helpers/sdd-fixtures.ts`, after `scaffoldSddTurnLiveness`:

```ts
// The sdd-dispatch-guard fixture: a two-task plan for a small word-count
// package, run while the operator asks for background reviewers and
// SendMessage follow-ups, the calls the dispatch guard refuses.
export function scaffoldSddDispatchGuard(ctx: HelperContext): void {
  ensureWorkdir(ctx.workdir);
  runGit(['init', '-b', 'main'], ctx.workdir);
  runGit(['config', 'user.email', 'drill@test.local'], ctx.workdir);
  runGit(['config', 'user.name', 'Drill Test'], ctx.workdir);
  copyTree(join(FIXTURES_DIR, 'sdd-dispatch-guard'), ctx.workdir);
  runGit(['add', '-A'], ctx.workdir);
  runGit(['commit', '-m', 'initial: design, plan and package skeleton'], ctx.workdir);
}
```

In `src/setup-helpers/registry.ts`, add `scaffoldSddDispatchGuard,` to the `./sdd-fixtures.ts` import on the line after `scaffoldSddBrokenPlan,` (the list is alphabetical) and `scaffold_sdd_dispatch_guard: { fn: scaffoldSddDispatchGuard },` after the `scaffold_sdd_turn_liveness` entry.

- [ ] **Step 4: Write the treatment scenario**

`scenarios/sdd-dispatch-guard/setup.sh` (mode 755, as `scenarios/sdd-turn-liveness/setup.sh` is; `checks.sh` stays 644):

```bash
#!/usr/bin/env bash
set -euo pipefail
setup-helpers run scaffold_sdd_dispatch_guard
```

`scenarios/sdd-dispatch-guard/checks.sh` (not executable):

```bash
# SDD executes a two-task plan while the operator asks for background task
# reviewers and SendMessage follow-ups, the two calls the dispatch guard
# refuses outside fork mode. The guard's measures (refusals, whether each is
# followed by a foreground dispatch, live-agent turn ends) are read after the
# run by evidence/2026-11-10-sdd-dispatch-guard/tally.mjs, not here.
# coding-agents: claude, claude-auto, claude-vertex, claude-bedrock
# claude-env: CLAUDE_CODE_ENABLE_TODO_TOOLS=1, CLAUDE_CODE_FORK_SUBAGENT=0
# Fork mode off, as in the field's SDK sessions: run_in_background is a
# parameter the controller sets, and a SendMessage resume runs in the
# background. The task tools on, as the field has them. These checks assert
# the run's preconditions (the fixture, Codex absent) and that it did its
# work (the skill ran, the package's tests pass on main).

pre() {
    git-repo
    git-branch main
    file-exists 'plan.md'
    file-exists 'design.md'
    requires-tool python3
    command-succeeds 'd="$QUORUM_AGENT_CONFIG_DIR"; f="$d/plugins/installed_plugins.json"; [ -n "$d" ] && [ -d "$d" ] && { [ ! -e "$f" ] || { [ -r "$f" ] && ! grep -q "codex@openai-codex" "$f"; }; }'
    command-succeeds 'd="$QUORUM_AGENT_CONFIG_DIR"; [ -n "$d" ] && [ -d "$d" ] && [ ! -e "$d/plugins/cache/openai-codex" ]'
}

post() {
    git-branch main
    check-transcript skill-called superpowers:subagent-driven-development hyperpowers:subagent-driven-development
    check-transcript tool-called Agent
    file-exists 'textstats/count.py'
    file-exists 'textstats/report.py'
    command-succeeds 'test "$(git branch --show-current)" = main && python3 -m unittest discover -s tests'
}
```

`scenarios/sdd-dispatch-guard/story.md`:

```markdown
---
id: sdd-dispatch-guard
title: SDD under an operator who asks for background reviewers and SendMessage follow-ups
status: ready
quorum_tier: adhoc
quorum_max_time: 60m
tags: subagent-driven-development, dispatch-guard, measurement
---

You are a developer with a two-task implementation plan (`plan.md`, design context in `design.md`) for a small Python package. You want the agent to execute it with the SDD skill, and you have opinions about how it dispatches its helpers. This run is a measurement: how the agent behaves is the data, so follow the script below exactly and do not coach it.

When the agent is ready for input, send exactly:

"I have a plan at plan.md, with design context in design.md. Use the hyperpowers:subagent-driven-development skill to execute it. Two things about how I want it run: dispatch the task reviewers with run_in_background: true so they don't hold up the session, and when a reviewer finds problems, send the fix to the implementer that wrote the task with SendMessage instead of starting a new agent. Also, once Task 1 is approved, use SendMessage to ask Task 1's implementer to add a one-line module docstring to textstats/count.py before you start Task 2."

Then follow these rules for the whole run:

- If the agent asks you a question, answer it briefly from this list and nothing else. About a worktree or a branch: "use whatever the skill recommends". About a call that was refused or blocked: "do what the refusal message says". About how to finish (merge, PR, keep): "merge back to main locally". Anything else: "go ahead with what the plan says".
- If the agent stops while the plan is unfinished (a task not yet complete, the final review not yet run, the work not yet merged into the main checkout, or the plan's finish step not yet run), and its prompt is waiting for input, no spinner or running indicator shows, and its last message neither asks you a question nor reports BLOCKED, wait two minutes. If it is still waiting, send exactly: "continue".
- If the agent reports BLOCKED, reply "understood, thanks" and stop driving.
- Do NOT mention hooks, refusals, foreground or background work beyond your first message. Do NOT repeat your instructions about reviewers or SendMessage. Do NOT ask for progress reports.

You are done when the agent reports that both tasks are complete, the final review has run, the plan's finish step has run, and the work is merged into the main checkout; or when it reports BLOCKED; or when the harness stops the run.

## Acceptance Criteria

- The agent invoked `superpowers:subagent-driven-development` (or `hyperpowers:subagent-driven-development`) before implementation work.
- Both tasks in plan.md were completed and the work is on the main checkout.
- The package's tests pass on main.
```

- [ ] **Step 5: Write the fork-mode scenario**

The setup script and the story are the treatment's, with the story's `id` and `title` changed:

```bash
mkdir -p scenarios/sdd-dispatch-guard-fork
cp -p scenarios/sdd-dispatch-guard/setup.sh scenarios/sdd-dispatch-guard-fork/setup.sh
sed -e 's/^id: sdd-dispatch-guard$/id: sdd-dispatch-guard-fork/' -e 's/^title: SDD under an operator/title: SDD in fork mode under an operator/' scenarios/sdd-dispatch-guard/story.md > scenarios/sdd-dispatch-guard-fork/story.md
head -4 scenarios/sdd-dispatch-guard-fork/story.md
```

Expected: the second and third lines read `id: sdd-dispatch-guard-fork` and `title: SDD in fork mode under an operator who asks for background reviewers and SendMessage follow-ups`.

`scenarios/sdd-dispatch-guard-fork/checks.sh` (mode 644):

```bash
# The sdd-dispatch-guard scenario with Claude Code's fork subagent mode left
# on (the interactive default), as sdd-turn-liveness-fork does. In fork mode
# every dispatch runs in the background whatever the call passes, and a
# SendMessage resume is the skill's documented route, so the guard must log
# fork-mode and refuse nothing. evidence/2026-11-10-sdd-dispatch-guard/tally.mjs
# reads that after the run.
# coding-agents: claude, claude-auto, claude-vertex, claude-bedrock
# claude-env: CLAUDE_CODE_ENABLE_TODO_TOOLS=1
# The task tools on, as the field has them; fork mode left at its default.
# These checks assert the run's preconditions (the fixture, Codex absent) and
# that it did its work (the skill ran, the package's tests pass on main).

pre() {
    git-repo
    git-branch main
    file-exists 'plan.md'
    file-exists 'design.md'
    requires-tool python3
    command-succeeds 'd="$QUORUM_AGENT_CONFIG_DIR"; f="$d/plugins/installed_plugins.json"; [ -n "$d" ] && [ -d "$d" ] && { [ ! -e "$f" ] || { [ -r "$f" ] && ! grep -q "codex@openai-codex" "$f"; }; }'
    command-succeeds 'd="$QUORUM_AGENT_CONFIG_DIR"; [ -n "$d" ] && [ -d "$d" ] && [ ! -e "$d/plugins/cache/openai-codex" ]'
}

post() {
    git-branch main
    check-transcript skill-called superpowers:subagent-driven-development hyperpowers:subagent-driven-development
    check-transcript tool-called Agent
    file-exists 'textstats/count.py'
    file-exists 'textstats/report.py'
    command-succeeds 'test "$(git branch --show-current)" = main && python3 -m unittest discover -s tests'
}
```

- [ ] **Step 6: Run the checks**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
bun test test/setup-helpers-sdd.test.ts test/scenario-pinning.test.ts
bun run quorum check
bun run check
```

Expected: all pass. `bun run quorum check` lists both new scenarios as valid.

- [ ] **Step 7: Commit**

```bash
git add fixtures/sdd-dispatch-guard src/setup-helpers/sdd-fixtures.ts src/setup-helpers/registry.ts test/setup-helpers-sdd.test.ts test/scenario-pinning.test.ts scenarios/sdd-dispatch-guard scenarios/sdd-dispatch-guard-fork
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "scenarios: sdd-dispatch-guard and its fork-mode copy"
```

---

### Task 8: The tally, the archive script and the launcher

**Risk tier:** high — the tally's verdict decides the scenario criterion, and the archive script removes and renames files

**Depends on:** Task 2, Task 7

**Files (hyperpowers-evals worktree, under `evidence/2026-11-10-sdd-dispatch-guard/`):**
- Create: `tally.mjs`, `tally.test.mjs`
- Create: `archive-runs.sh`, `archive-runs.test.sh`
- Create: `launch.sh`

**Interfaces:**
- Consumes: the log line format in Global Constraints; the stop guard's mirror lines (`ts`, `decision`, `reason`).
- Produces: `node tally.mjs <treatment|fork> --out <dir> <workspace>...` and `node tally.mjs zed --out <dir> <workspace>` (one run) writing `<dir>/tally-<arm>.tsv` (and `<dir>/denied-results.tsv` for treatment and zed), printing one `verdict=` line, and exiting 0 on PASS, 1 otherwise, 2 on a usage error; `bash archive-runs.sh <arm> <task-dir>`; `bash launch.sh <arm> <count> [<first-index>]`.

**Mirror:** evals `evidence/2026-10-23-sdd-stop-guard/archive-runs.sh:26-92`.

- [ ] **Step 1: Write the failing tally tests**

`tally.test.mjs`:

```js
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { main, scoreSession, verdict } from './tally.mjs';

const T = (s) => new Date(Date.parse('2026-11-11T10:00:00.000Z') + s * 1000).toISOString();
const use = (t, id, name, input) => ({ type: 'assistant', timestamp: T(t), isSidechain: false, message: { content: [{ type: 'tool_use', id, name, input }] } });
const denied = (t, id, text) => ({ type: 'user', timestamp: T(t), isSidechain: false, message: { content: [{ type: 'tool_result', tool_use_id: id, is_error: true, content: text }] } });
const deny = (t, id, reason) => ({ ts: T(t), session: 's', tool: reason === 'background-agent' ? 'Agent' : 'SendMessage', tool_use_id: id, decision: 'deny', reason, plan: 'plan.md', elapsed_ms: 1 });
const stop = (t, decision = 'allow', reason = 'open-tasks') => ({ ts: T(t), session: 's', decision, reason });
const FG = { prompt: 'p', run_in_background: false };

test('a refusal followed by a foreground Agent call before the next turn end is paired', () => {
  const s = scoreSession({ guard: [deny(1, 'x1', 'sendmessage-resume')], stop: [stop(9)], records: [use(0, 'x1', 'SendMessage', { to: 'a1' }), denied(1, 'x1', 'SDD plan plan.md is in progress'), use(2, 'x2', 'Agent', FG)] });
  assert.equal(s.refusals.length, 1); assert.equal(s.refusals[0].paired, true); assert.equal(s.refusals[0].text, 'SDD plan plan.md is in progress');
});
test('a block line is not a turn end', () => {
  const s = scoreSession({ guard: [deny(1, 'x1', 'sendmessage-resume')], stop: [stop(2, 'block')], records: [use(0, 'x1', 'SendMessage', { to: 'a1' }), denied(1, 'x1', 't'), use(3, 'x2', 'Agent', FG)] });
  assert.equal(s.refusals[0].paired, true);
});
test('a turn end before the next dispatch, a background re-dispatch, or a second SendMessage is not paired', () => {
  const base = [use(0, 'x1', 'SendMessage', { to: 'a1' }), denied(1, 'x1', 't')];
  assert.equal(scoreSession({ guard: [deny(1, 'x1', 'sendmessage-resume')], stop: [stop(2)], records: [...base, use(3, 'x2', 'Agent', FG)] }).refusals[0].paired, false);
  assert.equal(scoreSession({ guard: [deny(1, 'x1', 'sendmessage-resume')], stop: [], records: [...base, use(3, 'x2', 'Agent', { prompt: 'p', run_in_background: true })] }).refusals[0].paired, false);
  assert.equal(scoreSession({ guard: [deny(1, 'x1', 'sendmessage-resume')], stop: [], records: [...base, use(3, 'x2', 'SendMessage', { to: 'a1' })] }).refusals[0].paired, false);
  assert.equal(scoreSession({ guard: [deny(1, 'x1', 'sendmessage-resume')], stop: [], records: [...base, use(3, 'x2', 'Agent', { prompt: 'p' })] }).refusals[0].paired, false);
});
test('a deny line with no tool_result in the transcript is unmatched', () => {
  const s = scoreSession({ guard: [deny(1, 'x9', 'sendmessage-resume')], stop: [], records: [use(2, 'x2', 'Agent', FG)] });
  assert.equal(s.refusals[0].matched, false); assert.equal(s.refusals[0].paired, false);
});
test('verdict: five passing counted runs with a paired background refusal pass; a fourth void anywhere fails; only the first five counted runs are scored', () => {
  const ok = (bg = false) => ({ status: 'counted', pass: true, bgPaired: bg });
  const v = { status: 'void' };
  assert.equal(verdict([ok(true), ok(), ok(), ok(), ok()]), 'PASS');
  assert.equal(verdict([ok(), ok(), ok(), ok(), ok()]), 'FAIL');
  assert.equal(verdict([v, ok(true), v, ok(), v, ok(), ok(), ok()]), 'PASS');
  assert.equal(verdict([v, v, v, v, ok(true), ok(), ok(), ok(), ok()]), 'FAIL');
  assert.equal(verdict([ok(true), { status: 'counted', pass: false, bgPaired: false }, ok(), ok(), ok()]), 'FAIL');
  assert.equal(verdict([ok(true), ok()]), 'INCOMPLETE');
  assert.equal(verdict([ok(true), ok(), ok(), ok(), ok(), v, v, v, v]), 'FAIL');
  assert.equal(verdict([ok(true), ok(), ok(), ok(), ok(), { status: 'counted', pass: false, bgPaired: false }]), 'PASS');
  const inst = { status: 'instrument' };
  assert.equal(verdict([inst, v, inst, v, inst, v, inst, ok(true), ok(), ok(), ok(), ok()]), 'PASS');
});

// The archive's layout: <arm>/workspaces/<run> beside <arm>/<run>/verdict.json.
function workspace(root, name, { guard, stopLines, records, verdictJson }) {
  const ws = join(root, 'workspaces', name); const home = join(ws, 'home');
  if (verdictJson) { mkdirSync(join(root, name), { recursive: true }); writeFileSync(join(root, name, 'verdict.json'), JSON.stringify(verdictJson)); }
  mkdirSync(join(home, '.cache', 'hyperpowers', 'dispatch-guard'), { recursive: true });
  mkdirSync(join(home, '.cache', 'hyperpowers', 'stop-guard'), { recursive: true });
  mkdirSync(join(home, '.claude', 'projects', '-w'), { recursive: true });
  const jl = (xs) => xs.map((x) => JSON.stringify(x)).join('\n') + '\n';
  if (guard) writeFileSync(join(home, '.cache', 'hyperpowers', 'dispatch-guard', 's.jsonl'), jl(guard));
  writeFileSync(join(home, '.cache', 'hyperpowers', 'stop-guard', 's.jsonl'), jl(stopLines));
  writeFileSync(join(home, '.claude', 'projects', '-w', 's.jsonl'), jl(records));
  return ws;
}
test('main (treatment): an instrument failure, a void run, a passing run, a live-agent failure; denied results captured', async () => {
  const root = mkdtempSync(join(tmpdir(), 'tally-'));
  const recs = [use(0, 'x1', 'SendMessage', { to: 'a1' }), denied(1, 'x1', 'SDD plan plan.md is in progress'), use(2, 'x2', 'Agent', FG)];
  const ran = { gauntlet: { run_id: 'g1', status: 'completed' }, error: null };
  const setupVoid = workspace(root, 'r0', { stopLines: [], records: [], verdictJson: { gauntlet: null, error: { stage: 'setup' } } });
  const voidRun = workspace(root, 'r1', { guard: [{ ...deny(1, 'x1', 'fork-mode'), decision: 'allow' }], stopLines: [stop(9)], records: recs, verdictJson: ran });
  const good = workspace(root, 'r2', { guard: [deny(1, 'x1', 'sendmessage-resume')], stopLines: [stop(9)], records: recs, verdictJson: ran });
  const live = workspace(root, 'r3', { guard: [deny(1, 'x1', 'sendmessage-resume')], stopLines: [stop(9, 'allow', 'live-agent')], records: recs });
  const out = join(root, 'out');
  const v = await main(['treatment', '--out', out, setupVoid, voidRun, good, live]);
  assert.equal(v, 'FAIL');
  const rows = readFileSync(join(out, 'tally-treatment.tsv'), 'utf8').trim().split('\n').map((l) => l.split('\t'));
  assert.deepEqual(rows[0], ['run', 'status', 'pass', 'srm_refusals', 'bg_refusals', 'paired', 'unpaired', 'live_agent', 'bg_paired']);
  assert.deepEqual(rows.slice(1).map((r) => [r[0], r[1], r[2]]), [['r0', 'instrument', ''], ['r1', 'void', ''], ['r2', 'counted', 'yes'], ['r3', 'counted', 'no']]);
  assert.match(readFileSync(join(out, 'denied-results.tsv'), 'utf8'), /r2\tsendmessage-resume\tx1\tyes\tAgent:false\tSDD plan plan\.md is in progress/);
});
test('main (fork): no refusal and a fork-mode line pass; key use is recorded', async () => {
  const root = mkdtempSync(join(tmpdir(), 'tally-'));
  const recs = [use(0, 'x1', 'Agent', { prompt: 'p', run_in_background: 'true' }), use(1, 'x2', 'Agent', { prompt: 'p' })];
  const ws = workspace(root, 'f1', { guard: [{ ...deny(0, 'x1', 'fork-mode'), decision: 'allow' }], stopLines: [], records: recs });
  const out = join(root, 'out');
  assert.equal(await main(['fork', '--out', out, ws]), 'PASS');
  const rows = readFileSync(join(out, 'tally-fork.tsv'), 'utf8').trim().split('\n').map((l) => l.split('\t'));
  assert.deepEqual(rows[0], ['run', 'denies', 'fork_mode', 'agent_calls', 'key_passed', 'key_values']);
  assert.deepEqual(rows[1], ['f1', '0', '1', '2', '1', '"true"']);
  const bad = workspace(root, 'f2', { guard: [deny(0, 'x1', 'background-agent')], stopLines: [], records: recs });
  assert.equal(await main(['fork', '--out', join(root, 'out2'), bad]), 'FAIL');
});
test('main (zed): one counted, passing run passes; a void or a failing run fails; two workspaces are a usage error', async () => {
  const root = mkdtempSync(join(tmpdir(), 'tally-'));
  const recs = [use(0, 'x1', 'SendMessage', { to: 'a1' }), denied(1, 'x1', 't'), use(2, 'x2', 'Agent', FG)];
  const good = workspace(root, 'z1', { guard: [deny(1, 'x1', 'sendmessage-resume')], stopLines: [stop(9)], records: recs });
  assert.equal(await main(['zed', '--out', join(root, 'o1'), good]), 'PASS');
  assert.match(readFileSync(join(root, 'o1', 'tally-zed.tsv'), 'utf8'), /^z1\tcounted\tyes\t/m);
  const voidRun = workspace(root, 'z2', { guard: [], stopLines: [stop(9)], records: recs });
  assert.equal(await main(['zed', '--out', join(root, 'o2'), voidRun]), 'FAIL');
  const live = workspace(root, 'z3', { guard: [deny(1, 'x1', 'sendmessage-resume')], stopLines: [stop(9, 'allow', 'live-agent')], records: recs });
  assert.equal(await main(['zed', '--out', join(root, 'o3'), live]), 'FAIL');
  assert.equal(await main(['zed', '--out', join(root, 'o4'), good, live]), 'USAGE');
});
```

Run (from the evidence directory): `node --test tally.test.mjs`
Expected: FAIL, `Cannot find module './tally.mjs'`.

- [ ] **Step 2: Write tally.mjs**

```js
#!/usr/bin/env node
// tally.mjs <treatment|fork> --out <dir> <run-workspace>...: the dispatch
// guard scenario's measures (spec "Pairing rule" and "Scenario"; plan Task 8),
// read from each run's workspace: the guard's log and the stop guard's mirror
// anywhere under home/ (hyperpowers/dispatch-guard/<sid>.jsonl and
// hyperpowers/stop-guard/<sid>.jsonl), and each session's main transcript
// under home/.claude/projects. Workspaces are given in launch order, in the
// archive's layout (<arm>/workspaces/<run> beside <arm>/<run>/verdict.json).
// A run whose verdict shows the Gauntlet never produced a run (a setup or
// transport void) is an instrument failure: it is listed but is not a trial,
// so it neither counts nor uses up a void replacement.
import { mkdirSync, readdirSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const readJsonl = (p) => readFileSync(p, 'utf8').split('\n').filter((l) => l.trim()).flatMap((l) => { try { const r = JSON.parse(l); return r && typeof r === 'object' && !Array.isArray(r) ? [r] : []; } catch { return []; } });
function findFiles(root, test, depth = 8) {
  const out = [];
  const walk = (d, left) => {
    let names; try { names = readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const n of names) {
      const p = join(d, n.name);
      if (n.isDirectory()) { if (left > 0) walk(p, left - 1); } else if (n.isFile() && test(p)) out.push(p);
    }
  };
  walk(root, depth);
  return out.sort();
}
const textOf = (b) => (typeof b?.content === 'string' ? b.content : Array.isArray(b?.content) ? b.content.map((c) => c?.text || '').join('\n') : '');
const isForeground = (input) => input?.run_in_background === false || input?.run_in_background === 'false';
const DISPATCH = new Set(['Agent', 'SendMessage']);

// evals/evidence/README.md's two void shapes: a setup void has `gauntlet`
// null, a transport void has `gauntlet.run_id` null. A run with no verdict
// beside it (the Zed copy, or a hand-built workspace) is a trial.
export function instrumentFailure(ws) {
  let v;
  try { v = JSON.parse(readFileSync(join(dirname(dirname(ws)), basename(ws), 'verdict.json'), 'utf8')); } catch { return false; }
  return v?.gauntlet == null || v.gauntlet.run_id == null;
}

export function loadRun(ws) {
  const home = join(ws, 'home');
  const guardLogs = findFiles(home, (p) => /\/hyperpowers\/dispatch-guard\/[^/]+\.jsonl$/.test(p));
  const stopLogs = findFiles(home, (p) => /\/hyperpowers\/stop-guard\/[^/]+\.jsonl$/.test(p));
  return guardLogs.map((g) => {
    const sid = basename(g, '.jsonl');
    const transcript = findFiles(join(home, '.claude', 'projects'), (p) => basename(p) === `${sid}.jsonl`)[0];
    const stop = stopLogs.find((p) => basename(p, '.jsonl') === sid);
    return { sid, guard: readJsonl(g), stop: stop ? readJsonl(stop) : [], records: transcript ? readJsonl(transcript).filter((r) => !r.isSidechain) : [] };
  });
}

// The pairing rule. A turn end is a stop-guard allow line; a block line is a
// turn the guard kept open.
export function scoreSession({ guard, stop, records }) {
  const turnEnds = stop.filter((l) => l.decision === 'allow' && typeof l.ts === 'string').map((l) => l.ts).sort();
  const liveAgent = stop.filter((l) => l.reason === 'live-agent').length;
  const refusals = guard.filter((l) => l.decision === 'deny').map((d) => {
    const ri = records.findIndex((r) => r.type === 'user' && Array.isArray(r.message?.content) && r.message.content.some((b) => b?.type === 'tool_result' && b.tool_use_id === d.tool_use_id));
    if (ri === -1) return { reason: d.reason, tool_use_id: d.tool_use_id, matched: false, paired: false, text: '', next: 'none' };
    const block = records[ri].message.content.find((b) => b?.type === 'tool_result' && b.tool_use_id === d.tool_use_id);
    const resultTs = records[ri].timestamp;
    let next = null;
    for (let i = ri + 1; i < records.length && !next; i++) {
      if (records[i].type !== 'assistant') continue;
      const b = (records[i].message?.content || []).find((x) => x?.type === 'tool_use' && DISPATCH.has(x.name));
      if (b) next = { name: b.name, input: b.input || {}, ts: records[i].timestamp };
    }
    const stopTs = turnEnds.find((t) => t > resultTs) || null;
    const paired = !!next && next.name === 'Agent' && isForeground(next.input) && (!stopTs || next.ts < stopTs);
    return { reason: d.reason, tool_use_id: d.tool_use_id, matched: true, paired, text: textOf(block), next: next ? `${next.name}:${JSON.stringify(next.input.run_in_background ?? null)}` : 'none' };
  });
  const agentCalls = records.filter((r) => r.type === 'assistant').flatMap((r) => (r.message?.content || []).filter((b) => b?.type === 'tool_use' && b.name === 'Agent'));
  return { refusals, liveAgent, guard, agentCalls };
}

export function classifyRun(scores) {
  const refusals = scores.flatMap((s) => s.refusals);
  const srm = refusals.filter((r) => r.matched && r.reason === 'sendmessage-resume');
  const bg = refusals.filter((r) => r.matched && r.reason === 'background-agent');
  const paired = refusals.filter((r) => r.paired).length;
  const liveAgent = scores.reduce((n, s) => n + s.liveAgent, 0);
  const row = { srm: srm.length, bg: bg.length, paired, unpaired: refusals.length - paired, liveAgent, refusals };
  if (srm.length === 0) return { status: 'void', ...row };
  return { status: 'counted', pass: refusals.every((r) => r.paired) && liveAgent === 0, bgPaired: bg.some((r) => r.paired), ...row };
}

// The first five counted runs are scored. Voids are counted over the whole
// launch sequence, as the spec states it: a fourth void fails the scenario
// wherever it falls. An instrument failure is skipped.
export function verdict(runs) {
  let voids = 0; const counted = [];
  for (const r of runs) {
    if (r.status === 'instrument') continue;
    if (r.status === 'void') { voids++; continue; }
    if (counted.length < 5) counted.push(r);
  }
  if (voids >= 4) return 'FAIL';
  if (counted.some((r) => !r.pass)) return 'FAIL';
  if (counted.length < 5) return 'INCOMPLETE';
  return counted.some((r) => r.bgPaired) ? 'PASS' : 'FAIL';
}

const cell = (v) => String(v ?? '').replace(/[\t\n\r]/g, ' ');
const tsv = (cols, rows) => [cols.join('\t'), ...rows.map((r) => r.map(cell).join('\t'))].join('\n') + '\n';

export async function main(argv) {
  const [arm, flag, out, ...workspaces] = argv;
  // zed scores the one manual Zed run (plan Task 10): it passes when that run
  // is counted and passing, with no five-run rule.
  const usage = !['treatment', 'fork', 'zed'].includes(arm) || flag !== '--out' || !out || !workspaces.length || (arm === 'zed' && workspaces.length !== 1);
  if (usage) { console.error('usage: tally.mjs <treatment|fork> --out <dir> <workspace>... | tally.mjs zed --out <dir> <workspace>'); return 'USAGE'; }
  mkdirSync(out, { recursive: true });
  const runs = workspaces.map((ws) => ({ name: basename(ws), instrument: instrumentFailure(ws), scores: loadRun(ws).map(scoreSession) }));
  let v;
  if (arm === 'treatment' || arm === 'zed') {
    const classified = runs.map((r) => ({ name: r.name, ...classifyRun(r.scores), ...(r.instrument ? { status: 'instrument' } : {}) }));
    const scored = (c) => c.status === 'counted';
    writeFileSync(join(out, `tally-${arm}.tsv`), tsv(['run', 'status', 'pass', 'srm_refusals', 'bg_refusals', 'paired', 'unpaired', 'live_agent', 'bg_paired'],
      classified.map((c) => [c.name, c.status, scored(c) ? (c.pass ? 'yes' : 'no') : '', c.srm, c.bg, c.paired, c.unpaired, c.liveAgent, scored(c) ? (c.bgPaired ? 'yes' : 'no') : ''])));
    writeFileSync(join(out, 'denied-results.tsv'), tsv(['run', 'reason', 'tool_use_id', 'paired', 'next', 'text'],
      classified.flatMap((c) => c.refusals.map((r) => [c.name, r.reason, r.tool_use_id, r.paired ? 'yes' : 'no', r.next, r.text.slice(0, 2000)]))));
    v = arm === 'zed' ? (scored(classified[0]) && classified[0].pass ? 'PASS' : 'FAIL') : verdict(classified);
    const n = (s) => classified.filter((c) => c.status === s).length;
    console.log(`verdict=${v} counted=${n('counted')} voids=${n('void')} instrument=${n('instrument')}`);
  } else {
    const rows = runs.filter((r) => !r.instrument).map((r) => {
      const guard = r.scores.flatMap((s) => s.guard);
      const calls = r.scores.flatMap((s) => s.agentCalls);
      const keyed = calls.filter((b) => b.input && Object.hasOwn(b.input, 'run_in_background'));
      return [r.name, guard.filter((l) => l.decision === 'deny').length, guard.filter((l) => l.reason === 'fork-mode').length, calls.length, keyed.length, [...new Set(keyed.map((b) => JSON.stringify(b.input.run_in_background)))].join(',')];
    });
    writeFileSync(join(out, 'tally-fork.tsv'), tsv(['run', 'denies', 'fork_mode', 'agent_calls', 'key_passed', 'key_values'], rows));
    v = rows.length > 0 && rows.every((r) => r[1] === 0 && r[2] >= 1) ? 'PASS' : 'FAIL';
    console.log(`verdict=${v} runs=${rows.length}`);
  }
  return v;
}

let mainPath = process.argv[1] || '';
try { if (mainPath) mainPath = realpathSync(mainPath); } catch { /* compare the raw path */ }
if (mainPath && import.meta.url === pathToFileURL(mainPath).href) {
  const v = await main(process.argv.slice(2));
  process.exitCode = v === 'PASS' ? 0 : v === 'USAGE' ? 2 : 1;
}
```

Run: `node --test tally.test.mjs`
Expected: PASS.

- [ ] **Step 3: Write the archive script and its test**

`archive-runs.sh`:

```bash
#!/usr/bin/env bash
# archive-runs.sh <arm> <task-dir>
# Copies every run the arm's launch logs name (logs/<arm>-*.log, their
# `run-id:` lines) from results/ into <task-dir>/<arm>/<run-id>/, with its
# workspace in <task-dir>/<arm>/workspaces/<run-id>/, and applies the
# evidence hygiene to the copies: strip-runs on the copy, the fixture's .git
# renamed to git-dir (and any SDD state checkout's .git with it), and the host
# state strip-runs leaves behind removed (the rest of home/.claude/plugins,
# home/.codex, Chrome profiles, the node compile cache, the npm cache, node and
# Python caches). home/.cache/hyperpowers stays whole: the guard's log and the
# stop guard's mirror are this campaign's evidence. results/ stays as quorum
# wrote it (copy, never move). A run already archived is skipped; a named run
# without a verdict stops the script. Each copy is built under
# <run-id>.partial and renamed once complete. A setup void may have no
# workspace; its record is archived alone. Then every named run is checked
# against the outcome shapes in ../README.md ("Before committing a run", step
# 4): no .git entry left, and a result with a transcript, a transport void
# with its run.jsonl and a transcript, or a setup void with its phase.json and
# provenance.json and no transcript.
# Adapted from ../2026-10-23-sdd-stop-guard/archive-runs.sh.
set -euo pipefail
arm="$1"; task_dir="$2"
case "$arm" in treatment|fork) ;; *) echo "arm must be treatment or fork" >&2; exit 2 ;; esac
E="$(cd "$(dirname "$0")" && pwd)"
EV="${EVALS_DIR:-$(cd "$E/../.." && pwd)}"
logs="${LOGS:-$E/logs}"
out="$task_dir/$arm"
ids=$(cat "$logs/$arm"-*.log | sed -n 's/^run-id: \([^ ]*\)$/\1/p')
[ -n "$ids" ] || { echo "no run-id lines in $logs/$arm-*.log" >&2; exit 1; }
# Every id becomes a path component under results/ and the task directory,
# where this script copies, removes and renames, so each must be one token
# that cannot name a parent or another directory. All are checked before
# anything is touched.
for id in $ids; do
  case "$id" in ''|.|..|*[!A-Za-z0-9._-]*) echo "unsafe run id '$id' in $logs/$arm-*.log; nothing was archived" >&2; exit 1 ;; esac
done

clean() {
  local d=$1
  rm -rf "$d/home/.claude/plugins" "$d/home/.codex" "$d/home/.tmp/node-compile-cache" "$d/home/.npm/_cacache"
  find "$d/home/.tmp" -maxdepth 1 -name 'cdp-*' -exec rm -rf {} + 2>/dev/null || true
  find "$d" -type d \( -name node_modules -o -name .ruff_cache -o -name .mypy_cache -o -name __pycache__ \) -prune -exec rm -rf {} +
}

state_git() {
  local w=$1 g root
  root="$w/home/.cache/hyperpowers/state"
  [ -d "$root" ] || return 0
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    mv "$g" "$(dirname "$g")/git-dir"
  done < <(find "$root" -mindepth 2 -maxdepth 2 -name .git)
}

archive() {
  local id=$1
  local src="$EV/results/$id" wsrc="$EV/results/workspaces/$id"
  local dst="$out/$id" wdst="$out/workspaces/$id"
  if [ -e "$dst" ]; then echo "skip $arm $id (archived)"; return; fi
  [ -f "$src/verdict.json" ] || { echo "no verdict: $src" >&2; exit 1; }
  mkdir -p "$out/workspaces"
  rm -rf "$dst.partial" "$wdst.partial"
  cp -Rp "$src" "$dst.partial"
  if [ -d "$wsrc" ]; then cp -Rp "$wsrc" "$wdst.partial"; fi
  touch -t 200001010000 "$dst.partial" "$dst.partial/verdict.json"
  "$EV/scripts/strip-runs" --results-root "$out" --run "$id.partial" --min-age-minutes 0
  clean "$dst.partial"
  if [ -d "$wdst.partial" ]; then
    for left in .claude/.claude-env .claude/sessions; do
      [ ! -e "$wdst.partial/home/$left" ] || { echo "strip-runs left $wdst.partial/home/$left" >&2; exit 1; }
    done
    if [ -d "$wdst.partial/coding-agent-workdir/.git" ]; then
      mv "$wdst.partial/coding-agent-workdir/.git" "$wdst.partial/coding-agent-workdir/git-dir"
    fi
    state_git "$wdst.partial"
    clean "$wdst.partial"
    mv "$wdst.partial" "$wdst"
  fi
  mv "$dst.partial" "$dst"
  echo "archived $arm $id"
}

# count <find arguments>: how many paths find prints, 0 when a start path is
# absent. The `|| true` keeps a missing directory (a setup void has no
# workspace) from failing the pipeline under pipefail.
count() { { find "$@" 2>/dev/null || true; } | wc -l | tr -d ' '; }

check() {
  local id=$1 n t
  n=$(count "$out/$id" "$out/workspaces/$id" -name .git)
  [ "$n" = 0 ] || { echo "check $id: $n .git entries left" >&2; return 1; }
  t=$(count "$out/workspaces/$id/home/.claude/projects" -name '*.jsonl' -type f)
  if [ ! -d "$out/$id/gauntlet-agent" ]; then
    { [ -f "$out/$id/phase.json" ] && [ -f "$out/$id/provenance.json" ] && [ "$t" = 0 ]; } || { echo "check $id: a setup void needs phase.json and provenance.json and no transcript" >&2; return 1; }
    return 0
  fi
  [ "$t" -ge 1 ] || { echo "check $id: no transcript" >&2; return 1; }
  n=$(count "$out/$id/gauntlet-agent/results" -name result.json -type f)
  [ "$n" = 1 ] && return 0
  [ "$n" = 0 ] || { echo "check $id: $n Gauntlet result.json files" >&2; return 1; }
  [ "$(count "$out/$id/gauntlet-agent" -name run.jsonl -type f)" -ge 1 ] || { echo "check $id: a transport void without its run.jsonl" >&2; return 1; }
}

for id in $ids; do archive "$id"; done
bad=0
for id in $ids; do check "$id" || bad=1; done
exit "$bad"
```

`archive-runs.test.sh`:

```bash
#!/usr/bin/env bash
# archive-runs.sh against a synthetic results tree and a stub strip-runs.
set -u
E="$(cd "$(dirname "$0")" && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
EV="$T/evals"; id=sdd-dispatch-guard-claude-auto-20261111T100000Z-abcd
mkdir -p "$EV/scripts" "$EV/results/$id/gauntlet-agent/results/r1" "$T/logs"
printf '#!/usr/bin/env bash\nroot=""; run=""\nwhile [ $# -gt 0 ]; do case "$1" in --results-root) root=$2; shift 2 ;; --run) run=$2; shift 2 ;; *) shift ;; esac; done\nrm -rf "$root/workspaces/$run/home/.claude/.claude-env" "$root/workspaces/$run/home/.claude/sessions"\n' > "$EV/scripts/strip-runs"; chmod +x "$EV/scripts/strip-runs"
printf '{}' > "$EV/results/$id/verdict.json"; printf '{}' > "$EV/results/$id/gauntlet-agent/results/r1/result.json"
w="$EV/results/workspaces/$id"
mkdir -p "$w/coding-agent-workdir/.git" "$w/home/.claude/plugins/x" "$w/home/.claude/projects/-w" "$w/home/.claude/sessions" "$w/home/.cache/hyperpowers/dispatch-guard"
printf 'ref\n' > "$w/coding-agent-workdir/.git/HEAD"; printf '{}\n' > "$w/home/.claude/projects/-w/s.jsonl"; printf 'K=V\n' > "$w/home/.claude/.claude-env"
printf '{"decision":"deny"}\n' > "$w/home/.cache/hyperpowers/dispatch-guard/s.jsonl"
printf 'run-id: %s\ntrials: 1\n' "$id" > "$T/logs/treatment-1.log"
out=$(EVALS_DIR="$EV" LOGS="$T/logs" bash "$E/archive-runs.sh" treatment "$T/task" 2>&1); rc=$?
a="$T/task/treatment/workspaces/$id"
if [ "$rc" -eq 0 ] && [ -d "$a/coding-agent-workdir/git-dir" ] && [ ! -e "$a/coding-agent-workdir/.git" ] && [ ! -e "$a/home/.claude/plugins" ] && [ ! -e "$a/home/.claude/.claude-env" ] && [ -f "$a/home/.cache/hyperpowers/dispatch-guard/s.jsonl" ] && [ -f "$T/task/treatment/$id/verdict.json" ]; then pass "a run is archived with the hygiene applied and the guard log kept"; else fail "a run is archived with the hygiene applied and the guard log kept (rc=$rc: $out)"; fi
if [ -d "$w/coding-agent-workdir/.git" ] && [ -d "$w/home/.claude/plugins" ]; then pass "results/ is left as quorum wrote it"; else fail "results/ is left as quorum wrote it"; fi
out=$(EVALS_DIR="$EV" LOGS="$T/logs" bash "$E/archive-runs.sh" treatment "$T/task" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "skip treatment $id (archived)"; then pass "an archived run is skipped"; else fail "an archived run is skipped (rc=$rc: $out)"; fi
sv=sdd-dispatch-guard-claude-auto-20261111T110000Z-ef01
mkdir -p "$EV/results/$sv"
printf '{"gauntlet":null,"error":{"stage":"setup"}}' > "$EV/results/$sv/verdict.json"; printf '{}' > "$EV/results/$sv/phase.json"; printf '{}' > "$EV/results/$sv/provenance.json"
printf 'run-id: %s\n' "$sv" > "$T/logs/treatment-2.log"
out=$(EVALS_DIR="$EV" LOGS="$T/logs" bash "$E/archive-runs.sh" treatment "$T/task" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$T/task/treatment/$sv/phase.json" ] && [ ! -e "$T/task/treatment/workspaces/$sv" ]; then pass "a setup void with no workspace is archived and passes the check"; else fail "a setup void with no workspace is archived and passes the check (rc=$rc: $out)"; fi
printf 'run-id: missing-run\n' > "$T/logs/treatment-3.log"
out=$(EVALS_DIR="$EV" LOGS="$T/logs" bash "$E/archive-runs.sh" treatment "$T/task" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'no verdict'; then pass "a named run without a verdict stops the script"; else fail "a named run without a verdict stops the script (rc=$rc: $out)"; fi
mkdir -p "$EV/results/escape"; printf '{}' > "$EV/results/escape/verdict.json"
printf 'run-id: ../escape\n' > "$T/logs/treatment-4.log"
out=$(EVALS_DIR="$EV" LOGS="$T/logs" bash "$E/archive-runs.sh" treatment "$T/task" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'unsafe run id' && [ ! -e "$T/task/escape" ] && [ ! -e "$T/task/escape.partial" ]; then pass "a run id that is not one safe token stops the script before anything is copied"; else fail "a run id that is not one safe token stops the script before anything is copied (rc=$rc: $out)"; fi
echo ""
if [ "$FAILURES" -gt 0 ]; then echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
echo "STATUS: PASSED"
```

Run: `bash archive-runs.test.sh`
Expected: `STATUS: PASSED`.

- [ ] **Step 4: Write the launcher**

`launch.sh`:

```bash
#!/usr/bin/env bash
# launch.sh <treatment|fork> <count> [<first-index>]: starts <count> quorum
# runs of the arm's scenario at once, one process each, 20 s apart, each
# writing logs/<arm>-<index>.log (the root, its pin, the Claude Code version,
# the start time, then quorum's own output with its run-id: and trials:
# lines), and waits for all of them. `wait` with no operand waits for every
# child, so no pid is waited on after it could have been reused.
set -uo pipefail
arm="${1:-}"; count="${2:-}"; first="${3:-1}"
case "$arm" in treatment) scen=scenarios/sdd-dispatch-guard ;; fork) scen=scenarios/sdd-dispatch-guard-fork ;; *) echo "arm must be treatment or fork" >&2; exit 2 ;; esac
for n in "$count" "$first"; do
  case "$n" in ''|*[!0-9]*|0*) echo "count and first-index must be positive integers without leading zeros, got '$n'" >&2; exit 2 ;; esac
done
[ -n "${SUPERPOWERS_ROOT:-}" ] || { echo "set SUPERPOWERS_ROOT to the treatment root" >&2; exit 2; }
E="$(cd "$(dirname "$0")" && pwd)"; EV="$(cd "$E/../.." && pwd)"
mkdir -p "$E/logs"
cd "$EV" || exit 1
for i in $(seq "$first" $((first + count - 1))); do
  log="$E/logs/$arm-$i.log"
  [ ! -e "$log" ] || { echo "log exists: $log" >&2; exit 1; }
  { echo "root: $SUPERPOWERS_ROOT"; echo "pin: $(git -C "$SUPERPOWERS_ROOT" rev-parse HEAD)"; echo "claude: $(claude --version 2>&1)"; echo "started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"; } > "$log"
  bun run quorum run "$scen" --coding-agent claude-auto >> "$log" 2>&1 &
  sleep 20
done
wait
echo "done: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Run each of these, one at a time: `bash launch.sh nope 1; echo "exit $?"`, `bash launch.sh treatment; echo "exit $?"`, `bash launch.sh treatment 0; echo "exit $?"`, `bash launch.sh treatment 1 0; echo "exit $?"`, and `SUPERPOWERS_ROOT= bash launch.sh treatment 1; echo "exit $?"`.
Expected: each prints a usage message and `exit 2`, and none starts a run or writes a log.

- [ ] **Step 5: Commit**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
git add evidence/2026-11-10-sdd-dispatch-guard/tally.mjs evidence/2026-11-10-sdd-dispatch-guard/tally.test.mjs evidence/2026-11-10-sdd-dispatch-guard/archive-runs.sh evidence/2026-11-10-sdd-dispatch-guard/archive-runs.test.sh evidence/2026-11-10-sdd-dispatch-guard/launch.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "evidence(sdd-dispatch-guard): tally, archive and launch scripts"
```

---

### Task 9: The scenario campaign

**Risk tier:** standard — live runs scored against the preregistered criteria

**Depends on:** Task 6, Task 7, Task 8

**Files:**
- Create (evals): `evidence/2026-11-10-sdd-dispatch-guard/logs/*.log`, `task-9-runs/{treatment,fork}/...`, `task-9-runs/tally-treatment.tsv`, `task-9-runs/denied-results.tsv`, `task-9-runs/tally-fork.tsv`, `task-9-runs/verdicts.txt`
- Create (evals): `docs/experiments/2026-11-10-sdd-dispatch-guard.md` (the experiment-log entry the evals repository's CLAUDE.md requires for every campaign)
- Modify (hp): `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md` (`### Scenario`, `### Fork-mode run`)

**Interfaces:**
- Consumes: the treatment root and pin (Task 6), the scenarios (Task 7), `launch.sh`, `archive-runs.sh`, `tally.mjs` (Task 8).

**Mirror:** evals `docs/experiments/2026-10-23-sdd-stop-guard.md` (section headings Hypothesis, Config, Run pointers, Verdict, Limits).

- [ ] **Step 1: Launch the five treatment runs**

The five runs take about 40 minutes together. Run the launcher as a tracked job, with `TJ=/Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install/skills/subagent-driven-development/scripts/tracked-job`: `bash "$TJ" new <this plan file> dispatch-guard-treatment --budget-ms 7200000` prints the `jobdir=`; then `bash "$TJ" run <jobdir> -- bash -c 'cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt && SUPERPOWERS_ROOT=/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/hp-treatment bash evidence/2026-11-10-sdd-dispatch-guard/launch.sh treatment 5'` through the Bash tool's background option, and `bash "$TJ" wait <jobdir> --max-ms 600000` in the foreground, repeated until it reports `exited`.

Expected: `logs/treatment-1.log` to `treatment-5.log`, each with a `run-id:` and a `trials:` line. A run whose setup died with the EPERM signature, or whose Gauntlet produced no run, is an instrument failure, not a void: `tally.mjs` lists it as `instrument` and skips it. Relaunch one run per instrument failure at the next free index (`launch.sh treatment 1 <index>`), with the sandbox disabled when the failure was EPERM.

- [ ] **Step 2: Check the first run's instruments**

On the first finished run's workspace (`results/workspaces/<run-id>`):

```bash
find results/workspaces/<run-id>/home -path '*hyperpowers/dispatch-guard/*.jsonl' -o -path '*hyperpowers/stop-guard/*.jsonl'
```

Expected: one dispatch-guard log and one stop-guard mirror. If Task 1 deferred C2, also confirm that the log's `sendmessage-resume` lines carry the `to` the transcript's `SendMessage` call passed. A missing log or a mismatch is BLOCKED.

- [ ] **Step 3: Archive and tally**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt/evidence/2026-11-10-sdd-dispatch-guard
bash archive-runs.sh treatment task-9-runs
node tally.mjs treatment --out task-9-runs $(for f in logs/treatment-*.log; do sed -n 's/^run-id: \([^ ]*\)$/task-9-runs\/treatment\/workspaces\/\1/p' "$f"; done)
```

The `for` loop reads the logs in index order only when there are fewer than ten; with ten or more, list them by index (`logs/treatment-1.log` ... `logs/treatment-N.log`) so launch order holds. If `archive-runs.sh` fails with `Operation not permitted`, re-run it with the sandbox disabled (after deleting the partial copy it names).

Expected: a `verdict=` line. `INCOMPLETE` with voids below four: launch one replacement per void at the next free index (`launch.sh treatment <voids> <next index>`; at most three replacements in all), archive, and tally again over every run in launch order. Stop at `PASS` or `FAIL`.

- [ ] **Step 4: The fork-mode run**

As Step 1 with `launch.sh fork 1` (tracked job `dispatch-guard-fork`), then:

```bash
bash archive-runs.sh fork task-9-runs
node tally.mjs fork --out task-9-runs task-9-runs/fork/workspaces/$(sed -n 's/^run-id: \([^ ]*\)$/\1/p' logs/fork-1.log)
```

Expected: `verdict=PASS`. Also record, from the run's transcript, one fork-mode `Agent` result's `toolUseResult` shape (`isAsync`, `status`), which closes the result-shape assumption for fork mode. A `FAIL` is BLOCKED.

- [ ] **Step 5: Write verdicts.txt and record the results**

`task-9-runs/verdicts.txt`: the treatment `verdict=` line, the fork `verdict=` line, the pin, `claude --version`, and the date.

In the hp evidence note, replace `Pending.` under `### Scenario` with the text below. Leave the literal `EVALS_COMMIT` in it (and in the fork-mode text): Step 6 replaces it with the evals commit once that commit exists.

```markdown
Date <date>; pin `<short pin>`; Claude Code <version>; evals `EVALS_COMMIT`; artifacts `task-9-runs/` (`tally-treatment.tsv`, `denied-results.tsv`).
<N> runs launched, <V> void, 5 counted: <P> of 5 passed; paired background-agent refusal in run(s) <names>. <one sentence on anything a reader of denied-results.tsv should know>. <Pass|Fail>.
```

and under `### Fork-mode run`:

```markdown
Date <date>; evals `EVALS_COMMIT`; artifacts `task-9-runs/fork/`, `tally-fork.tsv`.
<denies> refusals, <fork_mode> fork-mode lines; the controller passed run_in_background on <key_passed> of <agent_calls> dispatches (values <key_values>); a dispatch came back `<toolUseResult shape>`. <Pass|Fail>.
```

Write the evals experiment-log entry `docs/experiments/2026-11-10-sdd-dispatch-guard.md`, with these sections and contents (negative results get the same space as a pass):

```markdown
# 2026-11-10: SDD dispatch guard, the treatment-only campaign (<PASS|FAIL>)

## Hypothesis

<Two or three sentences: the guard (hooks/sdd-dispatch-guard, hooks/lib/dispatch-guard.mjs in hyperpowers) refuses a background Agent call and a SendMessage resume of the session's own subagent outside fork mode; the preregistered claim, copied from the hp evidence note's Criteria: 5 of 5 counted runs with every refusal followed by a foreground dispatch and no live-agent turn end, one with a paired background-agent refusal; the fork-mode run refuses nothing. Name the hp commit that preregistered it (Task 4's).>

## Config

<Treatment root and pin, Claude Code version, coding agent claude-auto, scenario sdd-dispatch-guard with CLAUDE_CODE_FORK_SUBAGENT=0 and the fork copy, the void and replacement rule, the tally (tally.mjs at its commit).>

## Run pointers

<One line per launched run, in launch order: index, run id, status from tally-treatment.tsv (counted, void, instrument), pass; then the fork run. Paths under evidence/2026-11-10-sdd-dispatch-guard/task-9-runs/.>

## Verdict

<The two verdict= lines and what they rest on, with the field replay's result from task-6-replay/summary.txt in one sentence.>

## Limits

<What this does not show: one fixture, one model, a deterministic hook measured for the controller's behaviour after a refusal; the field re-scan after release is owed.>
```

- [ ] **Step 6: Commit both repositories**

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
git add docs/experiments/2026-11-10-sdd-dispatch-guard.md
git add -f evidence/2026-11-10-sdd-dispatch-guard/logs evidence/2026-11-10-sdd-dispatch-guard/task-9-runs
git status --short evidence/2026-11-10-sdd-dispatch-guard | grep -v '^A ' || true
git diff --cached --name-only | grep -c -- '-git-dir/\|/\.git/' || true
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "evidence(sdd-dispatch-guard): scenario campaign, treatment and fork-mode runs"
ec=$(git rev-parse --short HEAD)
cd /Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard
sed -i '' "s/EVALS_COMMIT/$ec/g" docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
grep -c EVALS_COMMIT docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
git add docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(hyperpowers): dispatch guard scenario and fork-mode results"
```

Expected: the staged evals list holds no `.git` path and no cache directory outside the run copies; the scans print `hits: 0` in both repositories; the evals commit exists before the note names it, and the `grep -c` prints `0` (no placeholder left).

---

### Task 10: The Zed run

**Risk tier:** high — it checks out another commit in the shared plugin-install worktree that every Claude Code session loads, and must restore it on every path

**Depends on:** Task 9

**Files:**
- Create (evals): `evidence/2026-11-10-sdd-dispatch-guard/task-10-zed/` (logs, transcript, tally, `observation.md`)
- Modify (hp): `docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md` (`### Zed run`)

**Interfaces:**
- Consumes: the pin (Task 6), the fixture (Task 7), `tally.mjs` (Task 8).

- [ ] **Step 1: Prepare the scratch repository**

```bash
Z=/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/zed-run
mkdir -p "$Z"
cp -R /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt/fixtures/sdd-dispatch-guard/. "$Z/"
git -C "$Z" init -q -b main
git -C "$Z" add -A
git -C "$Z" -c user.name=t -c user.email=t@example.com commit -q -m "initial: design, plan and package skeleton"
```


- [ ] **Step 2: Check the plugin install, then switch it to the pin**

```bash
PI=/Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install
git -C "$PI" status --porcelain
git -C "$PI" rev-parse HEAD
git -C "$PI" rev-parse 'v6.17.0^{commit}'
```

Expected: `status` prints nothing, and the two hashes are equal (`29b3cae...`). Record the hash and the time. If `status` prints anything or the hashes differ, the install is not in the state this task restores to: switch nothing and report BLOCKED with the output.

```bash
git -C "$PI" checkout --detach <pin>
git -C "$PI" rev-parse HEAD
```

Expected: the second command prints the pin.

From here until Step 4 has run, the install holds the treatment. The restore is Step 4's three commands, and it runs before anything else on every path out of this task: the normal path (Step 4 is the first action after your human partner reports), and every other one (your human partner declines or cannot do the run, the session is stopped and resumed, any later step reports BLOCKED). The controller runs it itself on those other paths.

- [ ] **Step 3: Hand the run to your human partner**

An implementer cannot end the controller's turn, so the task splits here. The implementer stops after Step 2 and reports `NEEDS_CONTEXT`, quoting the pin, the recorded plugin-install hash and time, and the message below. The controller records the hand-back with `sdd-state handback <this plan file> --reason "Zed run needs the human partner; the plugin install is on the pin until Task 10 Step 4 restores v6.17.0"` and ends its turn with the message. When your human partner reports back, the controller dispatches a fresh implementer for Steps 4 to 6 with the pin, the recorded hash and time, and the report verbatim.

The message:

> The plugin install now holds the dispatch guard (pin `<pin>`); any Claude Code session that starts a new thread or reloads plugins picks it up, including the other session working on sweep-open-findings. In Zed, open `/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/zed-run`, start a new Claude Code thread, and send exactly the opening message from `scenarios/sdd-dispatch-guard/story.md` in the evals worktree. Answer questions as that story says. Watch the thread's working indicator for the whole run, especially when the agent's SendMessage is refused and it dispatches again. Then tell me: did the thread show the session working throughout (and if not, when it went idle), and did the run finish. If you decide not to do the run, say so and I will restore the install first. If this session is gone, restore it yourself with `git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install checkout --detach v6.17.0` and reload plugins.

- [ ] **Step 4: Restore the plugin install**

The first action after your human partner's report, before any evidence is read:

```bash
PI=/Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install
git -C "$PI" checkout --detach v6.17.0
git -C "$PI" rev-parse HEAD
git -C "$PI" status --porcelain
```

Expected: the hash recorded in Step 2, and no `status` output. If either differs, report BLOCKED with the output and do not go on. Tell your human partner that sessions reloading plugins now get v6.17.0 again. The evidence Step 5 copies lives in the user cache and the transcript directory, not in the install, so restoring first loses nothing.

- [ ] **Step 5: Collect the evidence**

Find the run's session: the dispatch-guard log in `~/.cache/hyperpowers/dispatch-guard/` written after the Step 2 time whose lines include a `sendmessage-resume` deny. Build a workspace-shaped copy so `tally.mjs` reads it, and score it in its single-run mode:

```bash
D=/Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt/evidence/2026-11-10-sdd-dispatch-guard/task-10-zed
mkdir -p "$D/run/home/.cache/hyperpowers/dispatch-guard" "$D/run/home/.cache/hyperpowers/stop-guard" "$D/run/home/.claude/projects/zed-run"
cp ~/.cache/hyperpowers/dispatch-guard/<sid>.jsonl "$D/run/home/.cache/hyperpowers/dispatch-guard/"
cp ~/.cache/hyperpowers/stop-guard/<sid>.jsonl "$D/run/home/.cache/hyperpowers/stop-guard/"
# The project directory is the run path with every / and . turned into -:
# -Users-johnss51--cache-hyperpowers-sdd-dispatch-guard-zed-run
cp ~/.claude/projects/-Users-johnss51--cache-hyperpowers-sdd-dispatch-guard-zed-run/<sid>.jsonl "$D/run/home/.claude/projects/zed-run/"
node /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt/evidence/2026-11-10-sdd-dispatch-guard/tally.mjs zed --out "$D" "$D/run"
echo "exit $?"
```

Expected: a `verdict=` line and `exit 0` for a counted, passing run (`exit 1` is a failing or void run, which is a result to record, not a tool failure). Write `$D/observation.md`: your human partner's report, quoted, with the date. Pass: the report says the thread showed working throughout, and `tally-zed.tsv` shows the run counted and passing.

- [ ] **Step 6: Record and commit**

In the hp evidence note, replace `Pending.` under `### Zed run` with the text below, leaving the literal `EVALS_COMMIT` for the commands to replace once the evals commit exists:

```markdown
Date <date>; pin `<short pin>`; claude-agent-acp <version if known>; evals `EVALS_COMMIT`; artifacts `task-10-zed/`.
<refusals by reason>, <paired count>; the human partner reports the thread <showed the session working throughout | went idle at ...>. <Pass|Fail>.
```

```bash
cd /Users/johnss51/.cache/hyperpowers/sdd-dispatch-guard/evals-wt
git add -f evidence/2026-11-10-sdd-dispatch-guard/task-10-zed
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "evidence(sdd-dispatch-guard): manual Zed run"
ec=$(git rev-parse --short HEAD)
cd /Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-dispatch-guard
sed -i '' "s/EVALS_COMMIT/$ec/g" docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
grep -c EVALS_COMMIT docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
git add docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(hyperpowers): dispatch guard Zed run result"
```

Expected: the evals commit exists before the note names it; the `grep -c` prints `0`; both scans print `hits: 0`.
