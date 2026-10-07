# Release Hygiene Before 6.16.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-05-release-hygiene-design.md`, including its three appended Corrections of 2026-10-05 (item 3 superseded: the dead kill block is removed; item 13's `ProvenanceDeps` interface and label-free `show` line; item 17's capture shape and evidence layout).

**Goal:** Land the seventeen follow-ups the spec designs, in hyperpowers and hyperpowers-evals, so the 6.16.0 release ships plugin code that behaves under load and sandboxes, an evals checkout whose checks are green on this host, and runs whose provenance can be re-checked.

**Architecture:** Two branches, both named `release-hygiene`: hyperpowers off `main` at `c80ee21` in `.worktrees/release-hygiene`, evals off evals `main` at `52eea4f76` in `evals/.worktrees/release-hygiene`. Tasks 1 to 11 change hyperpowers (plugin scripts, their tests, docs); Tasks 12 to 25 change evals (tests, the focus-arm runner, a provenance module wired into the runner, seven scenario stubs, fixture P3 and its control run). Every task is one problem with one commit, proven by a test that fails before the change where a failure can be shown; the controller performs the host-side steps the spec reserves for it (item 12's tool copy and `~/.claude/CLAUDE.md` subsection, item 16's memory note) and launches item 17's live Codex run.

**Tech Stack:** bash 3.2 (macOS) and bash 5 scripts, Node 24 (CommonJS test files under `tests/brainstorm-server/`), Bun 1.4 with TypeScript, biome, zod; git; the codex-plugin-cc companion (1.0.6) for the live run.

## Global Constraints

- One problem per change; the full diff in chat and the human partner's approval before every commit (the controller presents each task's diff; implementers commit on the branch only after that approval is relayed in their dispatch or fix instructions).
- No attribution lines of any kind in commits or files: no `Co-Authored-By`, no "Generated with" text.
- Nothing is pushed; the release sequence waits for both branches to land.
- Committed files must not carry the proxy host, the `NO_PROXY` list, the GCP project id or private instruction text; every staged diff is scanned with `python3 ~/.claude/scripts/realval-scan.py` on stdin (expect `hits: 0`). The scan is the controller's, run before each approval.
- Live runs are the human partner's to authorize; item 17's three control reviews of P3 (Task 24) are authorized; no other live Codex or Claude session runs in this plan, and no test step may launch the real `claude` or `gauntlet`.
- Pre-registered campaign records (evidence READMEs, plan files) are only appended to, with a dated Note or Correction; living guidance (`docs/scenario-authoring.md`, evals `CLAUDE.md`, the private `~/.claude/CLAUDE.md`) is edited in place.
- The clean-harness controls of record are not re-scored.
- Evidence directory for this plan's live run: `evals/evidence/2026-10-05-release-hygiene/task-24-runs/control-P3/`, copied in from a scratch directory after the arm completes (named here before the first run, per the repository rule).
- No emojis anywhere. Comments explain why, not what.
- bash scripts under `tests/` and `skills/*/scripts/` must run under macOS bash 3.2: an array that may be empty is expanded as `${arr[@]+"${arr[@]}"}` under `set -u`; no associative arrays, no `mapfile`.
- Shell snippets the controller runs from its zsh tool never assign the names `path`, `status`, `fpath`, `cdpath` or `manpath`; the scripts and tests in this plan avoid them as well.

## Grounding

- `tests/brainstorm-server/stop-server.test.sh:231-262`: the shell-test shape for the brainstorm scripts (`skip`/`ok`/`bad` helpers, `track_dir`, `new_server_id`, PID 1 as the unsignalable stand-in under a root guard).
- `tests/brainstorm-server/start-server.test.sh:112-160`: a fake `ps` on a prepended `PATH`, a fake `node` that prints captured values, `--foreground` capture, `pass`/`fail` with a two-line failure message.
- `tests/brainstorm-server/lifecycle.test.js:12-55, 143-156`: the Node test shape for the server (`spawn('node', [SERVER], { env })`, wait for `server-started`, `killAndWait`, `fs.rmSync` in `finally`, an async `test()` that awaits `fn` inside `try`).
- `tests/brainstorm-server/server.test.js:125-138, 579-584`: the `test()` wrapper that calls `fn()` outside the promise chain (the defect Task 2 fixes) and the summary line and `finally` teardown that must keep working.
- `tests/brainstorm-server/package.json:5`: the `npm test` chain, one `&&` per file.
- `skills/brainstorming/scripts/server.cjs:684-691`: `info` built, `console.log(info)`, then the `server-info` write (Task 1 swaps the last two).
- `skills/brainstorming/scripts/stop-server.sh:37-41` (`process_exists`), `52-75` (`command_has_server_id`, tri-state), `97` (the `unverified` JSON line), `111-132` (the stop loop Task 3 rewrites).
- `skills/brainstorming/scripts/start-server.sh:114-132` (fresh session directory per start), `141-149` (the id write and the dead kill block Task 4 removes), `174-194` (foreground and background launches).
- `skills/requesting-code-review/scripts/verdict-normalize:30-33` (`out()` writes one JSON line and exits), `101-118` (the JSON path Task 5 guards).
- `tests/codex-review-gate/test-verdict-normalize.sh:8-20, 68-80`: `check <file> <fragment> <desc>` and heredoc payloads.
- `skills/subagent-driven-development/scripts/sdd-dir:23-51`: cwd-keyed key, plan slug from the cwd's toplevel (Task 9 rekeys by the plan's repository).
- `tests/claude-code/test-sdd-dir-path.sh:100-150`: `pass`/`fail`, `repo_a`, `$SDD_DIR_SCRIPT`, expected-path comparison.
- Here-string greps: `none: no existing here-string grep in tests/`; the sites to transform look like `tests/codex-review-gate/test-verdict-normalize.sh:13` (`printf '%s' "$out" | grep -Fq "$2" && pass "$3" || fail "..."`).
- `docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md:1789-1803`: the appended `**Correction (YYYY-MM-DD).**` paragraph form.
- `CHANGELOG.md:18-30` (at `c80ee21`): release-note bullets, bold lead sentence, prose explanation, evidence pointer.
- `evals/test/runner-workdir-scope.test.ts:1-30`: the bun test shape with `mkdtempSync` under a root removed in `afterAll`.
- `evals/test/runner-guards.test.ts:205-222`: the empty-`PATH` preflight pattern (`${emptyBin}:/usr/bin:/bin`, restored in `finally`) Task 12 reuses; `44-72` (`runGuard`).
- `evals/test/runner-context.test.ts:66, 129, 220, 222, 235, 236, 249, 280, 281`: nine `mkdtempSync` calls with no removal.
- `evals/test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts:206, 245, 266, 277, 293`: the five spawn-heavy tests.
- `evals/test/scenario-brainstorming-tooling-question.test.ts:24-60, 144-162`: `resolve(import.meta.dir, '..', '..', 'skills', ...)` (the assumption Task 15 removes) and the test's own `spawnSync`-based helpers.
- `evals/scripts/codex-focus-arm.sh:104-127` (`finish` trap releases the broker and writes the end record), `165-200` (per-fixture build, base/head commits, `review.diff`, three companion calls).
- `evals/scripts/codex-focus-arm.test.sh:41-50` (the stub companion records the `--json` argument per call), `65-72` (`run_arm`), `73` (`count`), `74-100` (assertions over `$work/<name>.log`), `93, 103` (loops over `*.txt` focus files only).
- `evals/src/agents/command-runner.ts:9-30, 56`: the `CommandRunner` seam (`run(command, args, options): CommandResult`) and `defaultCommandRunner`.
- `evals/src/contracts/verdict.ts:61-77`: `FinalVerdictSchema` optional identity fields (the `provenance` field joins them).
- `evals/src/runner/stopped.ts:5-13, 18-39`: `StoppedIdentity`, `buildStoppedVerdict`, `writeStoppedVerdict`; `evals/src/cli/index.ts:160-170` calls it from the SIGINT handler with the run dir.
- `evals/src/runner/index.ts:878` (`allocateRunDir`), `899-910` (the identified verdict and its write), `1080` (`isolateWorkdirPackageScope(runDir)` after the workdir mkdir).
- `evals/src/cli/render.ts:321-336` (`formatHeader` prints `run-dir`, `final`, `reason`), `411` (its one call site).
- `evals/test/runner-e2e.test.ts:24-70, 89-96`: mock-gauntlet end-to-end run (`const { verdict } = await runWithFixture(...)`); `evals/test/cli-run-sigint.test.ts:156-175`: the stopped verdict's identity assertions; `evals/test/cli-show.test.ts`: the `show` renderer tests; `evals/test/runner-stopped.test.ts`: the stopped-verdict unit tests.
- `evals/scenarios/brainstorming-asks-tooling-question/setup.sh:53` (`CALL_LOG`), `58-85` (prompt-file parsing, `classify`, `const kind`), `87-90` (call-log append), `92-139` (`APPROACHES`, `DOC_REVIEW` with their comments), `141-150` (its `setup` branch, which the targets already have), `152-175` (the `task` branch): the reference Task 22 ports.
- `evals/scenarios/brainstorming-bounded-fires-approach-gate/setup.sh:74-92`, the five `brainstorming-router-escalates-b*/setup.sh:86-104`, `brainstorming-router-no-downgrade/setup.sh:85-103`: `const sub`, `JOBS`, the `setup` branch, then the `task-reviewer`/`review`/`adversarial-review` dispatch the port precedes. At `c80ee21` each answers `status --json` with `{"running":[],"latestFinished":null,"recent":[]}`, `adversarial-review --base <40 zeros> --json focus` with `{"verdict":"approve","summary":"Stub: always approve, no findings.","findings":[],"next_steps":[]}` (exit 0, no trailing newline on either), and `task` with `{}` and exit 0.
- `evals/fixtures/codex-focus-arm/P/REQUIREMENTS.md:10-12`: the sentence P3 drops; `evals/scripts/codex-focus-arm.sh:35-41` (`commit_message`).
- `evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P2/P2-control-1.json`: a real foreground capture (keys `codex, context, parseError, rawOutput, reasoningSummary, result, review, target, threadId`; `result.verdict`); `runtime-start.txt` beside it (`companion 1.0.6`, `codex-binary <path>`, `codex-version codex-cli <v>`, `model = ...`, `model_reasoning_effort = ...`, `verdict-normalize <blob>`).
- `evals/docs/experiments/2026-09-30-a1-core-fixed-fixture-rerun.md:1-11`: the Hypothesis / Config / Run pointers / Verdict / Limits entry shape.
- `evals/evidence/README.md:13-18` (layout `evidence/<slug>/task-<N>-runs/<round or arm>/<run>/`, copy never move) and `20-33` (the commit steps).
- `evals/docs/scenario-authoring.md:635` (base-rate table header), `650-655` (Gauntlet identity procedure), `740-752` (the recipe), `evals/CLAUDE.md:17` (the Gauntlet row).
- Memory and host files: `none: no repository pattern; the controller edits ~/.claude/CLAUDE.md and the memory note directly`.

---

## Before Task 1 (controller)

1. Worktrees. In hyperpowers: `git -C /Users/johnss51/Development/agents/hyperpowers worktree add .worktrees/release-hygiene -b release-hygiene main` (base `c80ee21`). In evals: `git -C /Users/johnss51/Development/agents/hyperpowers/evals worktree add .worktrees/release-hygiene -b release-hygiene main` (base `52eea4f76`; the checkout takes several minutes; run it in the background; the worktree needs no `bun install`, bun resolves `evals/node_modules` by walking up).
2. First hyperpowers commit, after the human partner approves its diff. The spec and this plan are untracked files in the main checkout, so they are copied into the worktree first: `cp docs/hyperpowers/specs/2026-10-05-release-hygiene-design.md .worktrees/release-hygiene/docs/hyperpowers/specs/` and `cp docs/hyperpowers/plans/2026-10-05-release-hygiene.md .worktrees/release-hygiene/docs/hyperpowers/plans/`, then the CHANGELOG 6.16.0 edit: `git -C .worktrees/release-hygiene apply /tmp/claude-502/rel-changelog-diff.txt`. Commit message: `docs(hyperpowers): pre-register the release-hygiene spec and plan; CHANGELOG 6.16.0 heading`.
3. SDD workspace: `bash skills/subagent-driven-development/scripts/sdd-dir docs/hyperpowers/plans/2026-10-05-release-hygiene.md` from the hyperpowers worktree; one ledger for both repositories (evals tasks record their commits with the `evals` prefix).
4. Item 12's host steps (controller, Write tool): copy `~/.cache/hyperpowers/item4-grounding/realval-scan.py` to `~/.claude/scripts/realval-scan.py` byte for byte; append a "Leak scan" subsection to `~/.claude/CLAUDE.md` with the spec's wording; verify per the spec's item-12 proof (`cmp`, three needle checks from the settings env block, `hits: 0` on empty input). This happens before Task 1 so every later scan uses the durable copy.

---

### Task 1: `server.cjs` writes `server-info` before it announces

**Risk tier:** high — a readiness race between the server's announcement and a reader; concurrency in plugin runtime code.

**Files:**
- Modify: `skills/brainstorming/scripts/server.cjs:684-691`
- Test: `tests/brainstorm-server/lifecycle.test.js` (new case after the `server-info reports the configured idle_timeout_ms` case, which ends at line 156)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the contract "when `server-started` is printed, `<BRAINSTORM_DIR>/state/server-info` exists"; Task 2's `server.test.js` relies on it.

**Mirror:** `tests/brainstorm-server/lifecycle.test.js:143-156`: spawn the server with `BRAINSTORM_PORT` and `BRAINSTORM_DIR`, wait for `server-started`, assert, then `killAndWait` and `fs.rmSync` in `finally`.

- [ ] **Step 1: Record the race as it stands**

Run, from `tests/brainstorm-server/`, three times while `bun test` runs in another shell against the evals checkout (the controller supplies the load): `npm test > /tmp/claude-502/t1-chain-$i.log 2>&1; echo "rc=$?"`. Record each run's result in the implementer report. Today's record is three misses of `writes server-info to state/` under this load. A run that passes all three times does not block the task: the ordering defect is visible in the source (the write follows the announcement), and Step 2's test states the contract.

- [ ] **Step 2: Write the contract test**

In `tests/brainstorm-server/lifecycle.test.js`, after the first `await test(...)` block (ends line 156), add:

```js
  await test('server-info exists by the time server-started is printed', async () => {
    const dir = fs.mkdtempSync('/tmp/bs-life-');
    // 3409 is unused by the other cases in this file (grep BRAINSTORM_PORT).
    const srv = spawn('node', [SERVER], { env: { ...process.env, BRAINSTORM_PORT: 3409, BRAINSTORM_DIR: dir } });
    let out = ''; srv.stdout.on('data', d => out += d.toString());
    for (let i = 0; i < 60 && !out.includes('server-started'); i++) await sleep(50);
    try {
      assert(out.includes('server-started'), 'server did not start');
      // The announcement is the readiness signal: no polling here on purpose,
      // the file must be there on the very next statement.
      assert(fs.existsSync(path.join(dir, 'state', 'server-info')),
        'state/server-info must exist when server-started is printed');
    } finally {
      await killAndWait(srv);
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
```

- [ ] **Step 3: Run the test file**

Run: `cd tests/brainstorm-server && node lifecycle.test.js`
Expected: the new case passes or fails depending on scheduling (it is a race); every other case passes. Record the result.

- [ ] **Step 4: Move the write above the announcement**

In `skills/brainstorming/scripts/server.cjs`, replace lines 689-691:

```js
    console.log(info);
    // server-info embeds the key — keep it owner-only.
    fs.writeFileSync(path.join(STATE_DIR, 'server-info'), info + '\n', { mode: 0o600 });
```

with:

```js
    // server-info embeds the key — keep it owner-only. It is written before the
    // announcement so a reader that acts on server-started finds it in place.
    fs.writeFileSync(path.join(STATE_DIR, 'server-info'), info + '\n', { mode: 0o600 });
    console.log(info);
```

- [ ] **Step 5: Run the suites**

Run: `cd tests/brainstorm-server && node lifecycle.test.js && node server.test.js`
Expected: both report `0 failed`.

Run three times under the same load as Step 1: `npm test`
Expected: `rc=0` each time; `writes server-info to state/` passes in all three.

- [ ] **Step 6: Commit**

```bash
git add skills/brainstorming/scripts/server.cjs tests/brainstorm-server/lifecycle.test.js
git commit -m "fix(brainstorm-server): write server-info before announcing server-started"
```

---

### Task 2: `server.test.js` records a synchronous throw as one failure

**Risk tier:** standard — a test-helper extraction used by the plugin's own test chain.

**Files:**
- Create: `tests/brainstorm-server/test-runner.js`
- Create: `tests/brainstorm-server/test-runner.test.js`
- Modify: `tests/brainstorm-server/server.test.js:120-138` (the counters and `test()`), `579-581` (the summary)
- Modify: `tests/brainstorm-server/package.json:5`

**Interfaces:**
- Produces: `makeTestRunner({ log }) -> { test(name, fn): Promise<void>, counts: { passed, failed, skipped } }` in `test-runner.js`, CommonJS (`module.exports = { makeTestRunner }`).

**Mirror:** `tests/brainstorm-server/lifecycle.test.js:143-147`: the async `test()` whose `await fn()` sits inside `try`, which is the behaviour the shared helper gives `server.test.js`.

- [ ] **Step 1: Write the failing test**

Create `tests/brainstorm-server/test-runner.test.js`:

```js
// A test() wrapper must record a body that throws synchronously as one
// failure and keep going; server.test.js's wrapper aborted the whole run
// instead, which is how a load-sensitive assertion took every later test
// and the teardown with it.
const assert = require('assert');
const { makeTestRunner } = require('./test-runner');

(async () => {
  const lines = [];
  const { test, counts } = makeTestRunner({ log: (l) => lines.push(l) });
  await test('throws synchronously', () => { throw new Error('sync boom'); });
  await test('passes', () => Promise.resolve());
  await test('skips', () => { const e = new Error('no symlinks here'); e.skip = true; throw e; });
  assert.deepStrictEqual(counts, { passed: 1, failed: 1, skipped: 1 });
  assert.deepStrictEqual(lines, [
    '  FAIL: throws synchronously',
    '    sync boom',
    '  PASS: passes',
    '  SKIP: skips',
    '    no symlinks here',
  ]);
  console.log('--- Results: 1 passed, 0 failed ---');
})().catch((e) => {
  console.log(`  FAIL: ${e.message}`);
  console.log('--- Results: 0 passed, 1 failed ---');
  process.exitCode = 1;
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd tests/brainstorm-server && node test-runner.test.js`
Expected: `Cannot find module './test-runner'`, exit 1.

- [ ] **Step 3: Write the helper**

Create `tests/brainstorm-server/test-runner.js`:

```js
'use strict';
// fn runs inside the promise chain, so a synchronous throw lands in .catch
// exactly like a rejected promise: one FAIL is recorded and the caller's loop
// continues to the next test and to its teardown. An error carrying `skip`
// records a SKIP instead.
function makeTestRunner({ log = console.log } = {}) {
  const counts = { passed: 0, failed: 0, skipped: 0 };
  function test(name, fn) {
    return Promise.resolve()
      .then(fn)
      .then(() => {
        log(`  PASS: ${name}`);
        counts.passed++;
      })
      .catch((e) => {
        if (e && e.skip) {
          log(`  SKIP: ${name}`);
          log(`    ${e.message}`);
          counts.skipped++;
          return;
        }
        log(`  FAIL: ${name}`);
        log(`    ${e && e.message}`);
        counts.failed++;
      });
  }
  return { test, counts };
}

module.exports = { makeTestRunner };
```

- [ ] **Step 4: Run the new test**

Run: `cd tests/brainstorm-server && node test-runner.test.js`
Expected: `--- Results: 1 passed, 0 failed ---`, exit 0.

- [ ] **Step 5: Use it in `server.test.js`**

Add near the other `require` lines at the top of `server.test.js`:

```js
const { makeTestRunner } = require('./test-runner');
```

Replace lines 121-138 (`let passed = 0; let failed = 0; let skipped = 0;` and the local `function test(name, fn) {...}`) with:

```js
  const { test, counts } = makeTestRunner();
```

Replace lines 579-581:

```js
    console.log(`\n--- Results: ${passed} passed, ${failed} failed, ${skipped} skipped ---`);
    // process.exit() here would skip the finally block and orphan the server.
    if (failed > 0) process.exitCode = 1;
```

with:

```js
    console.log(`\n--- Results: ${counts.passed} passed, ${counts.failed} failed, ${counts.skipped} skipped ---`);
    // process.exit() here would skip the finally block and orphan the server.
    if (counts.failed > 0) process.exitCode = 1;
```

Any other reference to `passed`, `failed` or `skipped` inside `runTests` (search the function) becomes the `counts.` form.

- [ ] **Step 6: Add the new test to the chain**

In `tests/brainstorm-server/package.json`, in the `test` script, insert `node test-runner.test.js && ` immediately before `node server.test.js`.

- [ ] **Step 7: Run the chain**

Run: `cd tests/brainstorm-server && npm test`
Expected: rc 0; `server.test.js` reports `33 passed, 0 failed, 0 skipped`; the new file reports `1 passed`.

- [ ] **Step 8: Commit**

```bash
git add tests/brainstorm-server/test-runner.js tests/brainstorm-server/test-runner.test.js tests/brainstorm-server/server.test.js tests/brainstorm-server/package.json
git commit -m "test(brainstorm-server): a synchronous throw in a test body is one failure, not the end of the run"
```

---

### Task 3: `stop-server.sh`'s stop loop treats EPERM as alive

**Risk tier:** high — the script decides whether to signal and whether to delete a live server's handle; a process-permission surface.

**Files:**
- Modify: `skills/brainstorming/scripts/stop-server.sh:110-132`
- Test: `tests/brainstorm-server/stop-server.test.sh` (Test 9, inserted before the `--- Results:` line at 261)

**Interfaces:**
- Consumes: `process_exists` (`stop-server.sh:37-41`) and the `unverified` JSON shape at line 97.

**Mirror:** `tests/brainstorm-server/stop-server.test.sh:231-259` (Test 8): the root guard, PID 1 as the stand-in, a fake `ps` on a prepended `PATH`, `ok`/`bad` with the files checked afterwards.

- [ ] **Step 1: Write the failing test**

Insert before line 261 (`echo "--- Results: ..."`):

```bash
# --- Test 9: a live server this shell may not signal is reported unverified, not stopped ---
# With the identity confirmed (the fake ps names our server with the recorded
# id), the stop loop runs. Its signals are refused with EPERM, which the old
# loop read as "already dead" and reported stopped while the server lived.
if [[ -r "/proc/$$/cmdline" ]]; then
  skip "unsignalable server reports unverified from the stop loop" "/proc supplies the command line, so ps is never run"
elif kill -0 1 2>/dev/null; then
  skip "unsignalable server reports unverified from the stop loop" "this shell may signal PID 1, so PID 1 cannot stand in for an unsignalable server"
else
  SESS="$(mktemp -d)"; track_dir "$SESS"; mkdir -p "$SESS/state"
  SID="$(new_server_id)"
  printf '%s\n' "$SID" > "$SESS/state/server-instance-id"
  printf '%s\n' '{"type":"server-started"}' > "$SESS/state/server-info"
  echo 1 > "$SESS/state/server.pid"
  OURS_PS="$(mktemp -d)"; track_dir "$OURS_PS"
  printf '#!/bin/sh\necho "node server.cjs --brainstorm-server-id=%s"\n' "$SID" > "$OURS_PS/ps"
  chmod +x "$OURS_PS/ps"
  OUT="$(PATH="$OURS_PS:$PATH" "$STOP" "$SESS")"; RC=$?
  if [[ "$OUT" != *unverified* || "$RC" -eq 0 ]]; then
    bad "unsignalable server: expected unverified and a non-zero exit" "rc=$RC $OUT"
  elif [[ ! -f "$SESS/state/server.pid" || ! -f "$SESS/state/server-instance-id" || -f "$SESS/state/server-stopped" ]]; then
    bad "unverified stop must keep server.pid and server-instance-id" "$(ls "$SESS/state")"
  else
    ok "unsignalable server reports unverified from the stop loop and keeps the session files"
  fi
fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/brainstorm-server/stop-server.test.sh`
Expected: Test 9 prints `bad ... expected unverified and a non-zero exit` with `rc=0 {"status": "stopped"...}` (the current loop deletes the files and reports stopped); earlier tests pass.

- [ ] **Step 3: Rewrite the stop loop**

Replace `stop-server.sh` lines 110-132 (from the comment `# Try to stop gracefully...` through the `if kill -0 "$pid" ...; then echo '{"status": "failed"...' exit 1 fi` block) with:

```bash
  # Try to stop gracefully, then force. A kill refused with "not permitted" is
  # a live process this shell may not signal (a sandbox refuses signals to
  # processes it did not start), not a dead one: when every attempt is refused
  # and the process is still there, the stop is unverified and the session
  # files stay, exactly as the identity path reports it.
  unsignalable="true"
  if err="$(LC_ALL=C; kill "$pid" 2>&1)"; then
    unsignalable="false"
  elif [[ "$err" != *"not permitted"* ]]; then
    unsignalable="false"
  fi

  # Wait for graceful shutdown (up to ~2s)
  for _ in {1..20}; do
    process_exists "$pid" || break
    sleep 0.1
  done

  # If still running, escalate to SIGKILL
  if process_exists "$pid"; then
    if err="$(LC_ALL=C; kill -9 "$pid" 2>&1)"; then
      unsignalable="false"
    elif [[ "$err" != *"not permitted"* ]]; then
      unsignalable="false"
    fi
    sleep 0.1
  fi

  if process_exists "$pid"; then
    if [[ "$unsignalable" == "true" ]]; then
      echo '{"status": "unverified", "error": "this shell may not signal the server; session files kept"}'
      exit 1
    fi
    echo '{"status": "failed", "error": "process still running"}'
    exit 1
  fi
```

The state table this implements: process gone -> `stopped` as today; alive and every `kill` refused -> `unverified`, exit 1, files kept; alive after an accepted `kill -9` -> `failed`, exit 1, as today.

- [ ] **Step 4: Run the suite**

Run: `bash tests/brainstorm-server/stop-server.test.sh`
Expected: `--- Results: N passed, 0 failed, S skipped ---` with Test 9 `ok` on this host (unsandboxed, non-root) and the stale-pid, stopped and Test 8 cases unchanged.

Run: `bash tests/brainstorm-server/windows-lifecycle.test.sh`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/scripts/stop-server.sh tests/brainstorm-server/stop-server.test.sh
git commit -m "fix(brainstorm-server): the stop loop reports a server it may not signal as unverified, not stopped"
```

---

### Task 4: `start-server.sh` no longer kills a recorded pid

**Risk tier:** high — removes a destructive operation (a `kill` by recorded pid) from plugin script behaviour.

**Files:**
- Modify: `skills/brainstorming/scripts/start-server.sh:144-149`
- Test: `tests/brainstorm-server/start-server.test.sh` (new section before the final `--- Results:` block at 171)

**Interfaces:**
- Consumes: the spec's Correction (2026-10-05): the block is dead code because every start creates a fresh session directory (`start-server.sh:114-132`).

**Mirror:** `tests/brainstorm-server/start-server.test.sh:112-160`: a dedicated fake bin on `PATH`, `--foreground` with a fake `node` so the script finishes immediately, `pass`/`fail` with a two-line failure.

- [ ] **Step 1: Write the test**

Insert before line 171 (`echo ""` then `echo "--- Results: ..."`):

```bash
echo ""
echo "--- start-server.sh leaves other sessions' pid files alone ---"

# Every start creates a fresh session directory, so a server.pid in an older
# session of the same project is never this start's business. The script used
# to carry a kill of "the existing server" that could only ever find a pid
# file on a same-second restart in one shell; the kill is gone, and a pid file
# elsewhere must never be signalled.
mkdir -p "$TEST_DIR/stale-bin"
cat > "$TEST_DIR/stale-bin/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TEST_DIR/stale-bin/node"
rm -rf "$TEST_DIR/project"/*
mkdir -p "$TEST_DIR/project/.hyperpowers/brainstorm/1-1/state"
sleep 600 &
STALE_PID=$!
echo "$STALE_PID" > "$TEST_DIR/project/.hyperpowers/brainstorm/1-1/state/server.pid"

PATH="$TEST_DIR/stale-bin:$PATH" MSYSTEM="" \
  bash "$START_SCRIPT" --project-dir "$TEST_DIR/project" --foreground >/dev/null 2>&1 || true

if kill -0 "$STALE_PID" 2>/dev/null; then
  pass "a server.pid in another session directory is never signalled"
else
  fail "a server.pid in another session directory is never signalled" \
       "the process named by the stale pid file is gone"
fi
kill "$STALE_PID" 2>/dev/null || true
if grep -q 'Kill any existing server' "$START_SCRIPT"; then
  fail "start-server.sh carries no kill of a recorded pid" "the removed block is still present"
else
  pass "start-server.sh carries no kill of a recorded pid"
fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/brainstorm-server/start-server.test.sh`
Expected: the first new case passes (the stale pid file is in another session directory, which the current block never reads either), the second prints `FAIL: start-server.sh carries no kill of a recorded pid`; earlier cases pass. The second case is the one that turns green with the change; the first is the contract.

- [ ] **Step 3: Remove the block**

In `start-server.sh`, replace lines 144-149:

```bash
# Kill any existing server
if [[ -f "$PID_FILE" ]]; then
  old_pid=$(cat "$PID_FILE")
  kill "$old_pid" 2>/dev/null
  rm -f "$PID_FILE"
fi
```

with:

```bash
# No previous server to stop here: SESSION_DIR is created fresh for this
# start, so its pid file cannot name an earlier server. Stopping a server is
# stop-server.sh's job, with the identity check that script carries.
```

- [ ] **Step 4: Run the suites**

Run: `bash tests/brainstorm-server/start-server.test.sh && bash tests/brainstorm-server/windows-lifecycle.test.sh`
Expected: both `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/scripts/start-server.sh tests/brainstorm-server/start-server.test.sh
git commit -m "fix(brainstorm-server): drop the dead kill of a recorded pid from start-server.sh"
```

---

### Task 5: `verdict-normalize` fails closed on a job that did not complete

**Risk tier:** high — approval-authority code.

**Files:**
- Modify: `skills/requesting-code-review/scripts/verdict-normalize:101-104`
- Test: `tests/codex-review-gate/test-verdict-normalize.sh` (new cases after the existing JSON cases)

**Interfaces:**
- Consumes: `out(result, verdict, blockingCount, reason)` at `verdict-normalize:30-33` (writes one JSON line and exits 0).
- Produces: the rule "a payload with a `job` property normalizes to `incomplete` unless `job.status === "completed"`", reasons `job status <s>`, `job status missing`, `job status malformed`.

**Mirror:** `tests/codex-review-gate/test-verdict-normalize.sh:68-80`: a heredoc payload per case and `check <file> <fragment> <desc>`.

- [ ] **Step 1: Write the failing tests**

After the existing JSON-payload cases (find the last `check "$work/..." ... "json ..."` line in the `--- code-gate JSON payloads ---` section), add:

```bash
# --- job lifecycle: anything but a completed job is incomplete ---
# The companion's status/result JSON carries .job.status; a failed or
# cancelled job can still hold an earlier approve verdict in its stored text.
job_case() { # <name> <job-json-fragment> <fragment> <desc>
  cat > "$work/job-$1.json" <<EOF
{ "job": $2,
  "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [] },
  "rawOutput": "Verdict: approve" } } }
EOF
  check "$work/job-$1.json" "$3" "$4"
}
job_case failed    '{"id":"x","jobClass":"review","status":"failed"}'    '"result":"incomplete"'            "job status failed -> incomplete"
job_case failed    '{"id":"x","jobClass":"review","status":"failed"}'    '"reason":"job status failed"'     "job status failed names the status"
job_case cancelled '{"id":"x","jobClass":"review","status":"cancelled"}' '"result":"incomplete"'            "job status cancelled -> incomplete"
job_case running   '{"id":"x","jobClass":"review","status":"running"}'   '"result":"incomplete"'            "job status running -> incomplete"
job_case queued    '{"id":"x","jobClass":"review","status":"queued"}'    '"result":"incomplete"'            "job status queued -> incomplete"
job_case nullstat  '{"id":"x","jobClass":"review","status":null}'        '"reason":"job status missing"'    "null job status -> incomplete, missing"
job_case nostat    '{"id":"x","jobClass":"review"}'                      '"reason":"job status missing"'    "absent job status -> incomplete, missing"
job_case numstat   '{"id":"x","jobClass":"review","status":7}'           '"reason":"job status missing"'    "non-string job status -> incomplete, missing"
job_case malformed '"x"'                                                  '"reason":"job status malformed"'  "job that is not an object -> incomplete, malformed"
job_case completed '{"id":"x","jobClass":"review","status":"completed"}' '"result":"approved"'              "job status completed -> approved as before"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh`
Expected: the nine non-`completed` cases print `[FAIL]` with `(got: {"result":"approved"...)`; `completed` and every existing case pass.

- [ ] **Step 3: Add the guard**

In `verdict-normalize`, immediately after line 101 (`const d = JSON.parse(text);`) and before the `// Known roots ...` comment, insert:

```js
    // A payload that names its job carries the job's lifecycle: anything but
    // a completed job is incomplete, whatever text the record holds. A payload
    // without a job property (a bare verdict object, a result root) is read
    // exactly as before.
    if (d && typeof d === "object" && Object.prototype.hasOwnProperty.call(d, "job")) {
      const job = d.job;
      if (!job || typeof job !== "object") out("incomplete", "none", 0, "job status malformed");
      if (typeof job.status !== "string") out("incomplete", "none", 0, "job status missing");
      if (job.status !== "completed") out("incomplete", "none", 0, "job status " + job.status);
    }
```

- [ ] **Step 4: Run the suite**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh`
Expected: every case `[PASS]`, exit 0.

Run the gate suites that exercise the normalizer indirectly: `for t in tests/codex-review-gate/test-gate-contract.sh tests/codex-review-gate/test-sweep-toolchain.sh tests/codex-review-gate/test-gate-telemetry.sh; do bash "$t" || echo "FAILED $t"; done`
Expected: no `FAILED` line.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/verdict-normalize tests/codex-review-gate/test-verdict-normalize.sh
git commit -m "fix(verdict-normalize): a job that did not complete never normalizes to approved"
```

---

### Task 6: Here-string greps in `tests/codex-review-gate/`

**Risk tier:** standard — a rule-driven edit across fourteen files, each proven by its own suite.

**Files:**
- Modify: `tests/codex-review-gate/test-codex-broker-sweep.sh` (36 sites), `test-gate-telemetry.sh` (14), `test-broker-state-dir.sh` (9), `test-review-dossier.sh` (6), `test-sweep-toolchain.sh` (5), `test-gate-topology.sh` (4), `test-verdict-normalize.sh` (2), `test-ungated-ledger.sh` (2), `test-gate-contract.sh` (2), `test-gate-round.sh` (1), `test-codex-preflight.sh` (1), `test-broker-health.sh` (1), `test-base-ref-ok.sh` (1), `test-assemble-gate.sh` (1)

**Interfaces:**
- Produces: the transformation rule Tasks 7 and 8 apply to the other directories.

**Mirror:** none: no here-string grep exists in `tests/` yet; the forms to transform are listed below.

- [ ] **Step 1: Inventory the directory**

Run: `grep -rnE '(printf|echo) [^|]*\$[^|]*\| *grep( +-[A-Za-z]+)* +-[A-Za-z]*q' tests/codex-review-gate | wc -l`
Expected: `85` at the branch base (the fourteen per-file counts above sum to 85; with Task 7's 24 and Task 8's 14 the tree holds 123). Save the full listing: `... > /tmp/claude-502/t6-sites.txt`.

- [ ] **Step 2: Transform every site**

The rule: a `printf '%s' "$var" | grep <opts> <pattern>` or `printf '%s\n' "$var" | grep <opts> <pattern>` or `echo "$var" | grep <opts> <pattern>` whose `<opts>` contain `q` becomes `grep <opts> <pattern> <<< "$var"`, with everything else on the line unchanged. The three shapes present and their results:

```bash
# an if condition
if printf '%s' "$dangling_err" | grep -Fq 'index links a missing sibling: missing.md'; then
# becomes
if grep -Fq 'index links a missing sibling: missing.md' <<< "$dangling_err"; then

# a one-line expectation helper
expect() { printf '%s' "$1" | grep -Fq -- "$2" && pass "$3" || fail "$3 (got: $1)"; }
# becomes
expect() { grep -Fq -- "$2" <<< "$1" && pass "$3" || fail "$3 (got: $1)"; }

# an inline pass/fail chain with printf '%s\n'
printf '%s\n' "$out" | grep -q "stale-record .*s" && pass "..." || fail "..."
# becomes
grep -q "stale-record .*s" <<< "$out" && pass "..." || fail "..."
```

`<<<` appends one newline, which is what `printf '%s\n'` and `echo` already supplied and what `printf '%s'` lacked; no pattern in this directory depends on the absence of a trailing newline (`-x` patterns match a whole line, which the newline terminates). Edit each site by hand or with an editor's regex; do not change patterns, options or the surrounding chain.

- [ ] **Step 3: Verify the residual count and the syntax**

Run: `grep -rnE '(printf|echo) [^|]*\$[^|]*\| *grep( +-[A-Za-z]+)* +-[A-Za-z]*q' tests/codex-review-gate | wc -l`
Expected: `0`.

Run: `for f in tests/codex-review-gate/test-*.sh; do bash -n "$f" || echo "SYNTAX $f"; done`
Expected: no `SYNTAX` line.

- [ ] **Step 4: Run every suite in the directory**

Run: `fails=0; for t in tests/codex-review-gate/test-*.sh; do bash "$t" > "/tmp/claude-502/t6-$(basename "$t").log" 2>&1 || { echo "FAILED: $t"; fails=$((fails + 1)); }; done; echo "fails=$fails"`
Expected: `fails=0`. (`test-codex-broker-sweep.sh` and `test-codex-preflight.sh` touch the real companion broker state on this host; run them from the hyperpowers worktree root as the other suites.)

- [ ] **Step 5: Commit**

```bash
git add tests/codex-review-gate
git commit -m "test(codex-review-gate): grep variables through here-strings, not pipes, so grep -q cannot SIGPIPE the producer"
```

---

### Task 7: Here-string greps in `tests/claude-code/` and `tests/hooks/`

**Risk tier:** standard — the Task 6 rule over seven files.

**Files:**
- Modify: `tests/claude-code/test-delivery-resolution.sh` (9), `test-worktree-native-preference.sh` (5; a live suite, edited and syntax-checked, not run), `test-helpers.sh` (2), `test-sdd-dir-path.sh` (1), `tests/hooks/test-ungated-notice.sh` (4), `test-broker-janitor.sh` (2), `test-session-start.sh` (1)

**Interfaces:**
- Consumes: the Task 6 transformation rule.

**Mirror:** Task 6's three shapes; `test-helpers.sh:52` is the `echo "$output" | grep -qi "$pattern"` shape, which becomes `grep -qi "$pattern" <<< "$output"`.

- [ ] **Step 1: Inventory**

Run: `grep -rnE '(printf|echo) [^|]*\$[^|]*\| *grep( +-[A-Za-z]+)* +-[A-Za-z]*q' tests/claude-code tests/hooks | wc -l`
Expected: `24`.

- [ ] **Step 2: Transform every site** by the Task 6 rule.

- [ ] **Step 3: Verify**

Run: `grep -rnE '(printf|echo) [^|]*\$[^|]*\| *grep( +-[A-Za-z]+)* +-[A-Za-z]*q' tests/claude-code tests/hooks | wc -l`
Expected: `0`.

Run: `for f in tests/claude-code/*.sh tests/hooks/test-*.sh; do bash -n "$f" || echo "SYNTAX $f"; done`
Expected: no `SYNTAX` line.

- [ ] **Step 4: Run the offline suites**

Run: `fails=0; for t in tests/hooks/test-*.sh tests/claude-code/test-sdd-dir-path.sh tests/claude-code/test-codex-review-dir-path.sh tests/claude-code/test-delivery-resolution.sh tests/claude-code/test-worktree-path-policy.sh; do bash "$t" > "/tmp/claude-502/t7-$(basename "$t").log" 2>&1 || { echo "FAILED: $t"; fails=$((fails + 1)); }; done; echo "fails=$fails"`
Expected: `fails=0`. `test-worktree-native-preference.sh` spawns the real `claude` CLI and is not run; its `bash -n` in Step 3 is its check.

- [ ] **Step 5: Commit**

```bash
git add tests/claude-code tests/hooks
git commit -m "test(claude-code, hooks): grep variables through here-strings, not pipes"
```

---

### Task 8: Here-string greps in the remaining test directories, and the repository-wide check

**Risk tier:** standard — the Task 6 rule over eight files plus the residual proof.

**Files:**
- Modify: `tests/brainstorm-server/start-server.test.sh` (2), `windows-lifecycle.test.sh` (2), `tests/packaging/test-skill-frontmatter-rejects.sh` (2), `test-package-skill.sh` (1), `tests/writing-skills/test-render-graphs.sh` (2), `tests/shell-lint/test-lint-shell.sh` (2), `tests/sdd/test-sdd-contract.sh` (2), `tests/systematic-debugging/test-find-polluter.sh` (1)

**Interfaces:**
- Consumes: the Task 6 rule. Produces: the residual count of zero over all of `tests/`.

**Mirror:** Task 6's shapes; `start-server.test.sh:70` is `echo "$captured" | grep -Eq '^CAPTURED_ARGV=...$'`, which becomes `grep -Eq '^CAPTURED_ARGV=...$' <<< "$captured"` (the anchors still match: the here-string's newline ends the line).

- [ ] **Step 1: Inventory**

Run: `grep -rnE '(printf|echo) [^|]*\$[^|]*\| *grep( +-[A-Za-z]+)* +-[A-Za-z]*q' tests/brainstorm-server tests/packaging tests/writing-skills tests/shell-lint tests/sdd tests/systematic-debugging | wc -l`
Expected: `14` (the two cases Task 4 added in `start-server.test.sh` use `grep -q ... "$START_SCRIPT"` on a file, not a pipe, and do not count; if the count differs, list the sites and transform every one that matches the rule).

- [ ] **Step 2: Transform every site** by the Task 6 rule.

- [ ] **Step 3: Verify across the whole tree**

Run: `grep -rnE '(printf|echo) [^|]*\$[^|]*\| *grep( +-[A-Za-z]+)* +-[A-Za-z]*q' tests | grep -v node_modules | wc -l`
Expected: `0`.

Run: `for f in $(git ls-files 'tests/**/*.sh'); do bash -n "$f" || echo "SYNTAX $f"; done`
Expected: no `SYNTAX` line.

- [ ] **Step 4: Run the suites**

Run: `fails=0; for t in tests/packaging/test-*.sh tests/writing-skills/test-*.sh tests/shell-lint/test-*.sh tests/sdd/test-*.sh tests/systematic-debugging/test-*.sh tests/brainstorm-server/start-server.test.sh tests/brainstorm-server/windows-lifecycle.test.sh; do bash "$t" > "/tmp/claude-502/t8-$(basename "$t").log" 2>&1 || { echo "FAILED: $t"; fails=$((fails + 1)); }; done; echo "fails=$fails"`
Expected: `fails=0`.

- [ ] **Step 5: Commit**

```bash
git add tests/brainstorm-server tests/packaging tests/writing-skills tests/shell-lint tests/sdd tests/systematic-debugging
git commit -m "test: grep variables through here-strings everywhere under tests/"
```

---

### Task 9: `sdd-dir` keys a plan by its own repository

**Risk tier:** high — the script's output is trusted by every SDD helper (task-brief, review-package, the ledger location).

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-dir:23-46`
- Test: `tests/claude-code/test-sdd-dir-path.sh` (new cases after case 10a, which ends at line 150)

**Interfaces:**
- Produces: `sdd-dir <plan>` run from any cwd prints the workspace keyed by the plan's repository; `sdd-dir` with no argument keys by the cwd as before.

**Mirror:** `tests/claude-code/test-sdd-dir-path.sh:100-150`: `pass`/`fail`, `repo_a`, `$SDD_DIR_SCRIPT`, path comparison.

- [ ] **Step 1: Write the failing test**

After case 10a (line 150), add:

```bash
# 11. A plan is keyed by its own repository, whatever the cwd. A cross-repo
# plan used to get one workspace per repository it was invoked from.
repo_b="$TEST_ROOT/repo-b"
mkdir -p "$repo_b"
git -C "$repo_b" init -q
from_a=$(cd "$repo_a" && bash "$SDD_DIR_SCRIPT" plan.md)
from_b=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT" "$repo_a/plan.md")
if [ "$from_a" = "$from_b" ]; then
    pass "sdd-dir keys a plan by the plan's repository, not the cwd"
else
    fail "sdd-dir keys a plan by the plan's repository, not the cwd (from A: $from_a, from B: $from_b)"
fi
# 12. Without a plan argument the cwd still keys, and the two repos differ.
bare_a=$(cd "$repo_a" && bash "$SDD_DIR_SCRIPT")
bare_b=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT")
if [ "$bare_a" != "$bare_b" ]; then
    pass "sdd-dir without a plan keys by the cwd's repository"
else
    fail "sdd-dir without a plan keys by the cwd's repository (both: $bare_a)"
fi
# 13. A plan outside any repository is refused.
plan_nowhere="$TEST_ROOT/nowhere/plan.md"
mkdir -p "$(dirname "$plan_nowhere")"
: > "$plan_nowhere"
if (cd "$repo_b" && bash "$SDD_DIR_SCRIPT" "$plan_nowhere" >/dev/null 2>&1); then
    fail "sdd-dir refuses a plan whose directory is not inside a git repository"
else
    pass "sdd-dir refuses a plan whose directory is not inside a git repository"
fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`
Expected: case 11 `FAIL` (the two paths differ), 12 pass, 13 `FAIL` (today the plan's directory is only checked for existence); earlier cases pass.

- [ ] **Step 3: Rekey by the plan's repository**

Replace `sdd-dir` lines 23-46 (from `git rev-parse --git-dir >/dev/null 2>&1 || {` through `rel=${abs#"$toplevel"/}`) with:

```bash
# The repository that owns the plan keys the workspace when a plan is given,
# so a plan invoked from another repository's checkout (a cross-repo plan)
# still maps to one workspace. Without a plan argument the cwd's repository
# keys, as before.
plan_dir=""
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
  plan=$1
  plan_dir=$(cd "$(dirname "$plan")" 2>/dev/null && pwd -P) || {
    echo "sdd-dir: plan file directory does not exist: $plan" >&2
    exit 2
  }
  git -C "$plan_dir" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "sdd-dir: plan file directory is not inside a git repository: $plan" >&2
    exit 2
  }
else
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "sdd-dir: not inside a git repository" >&2
    exit 2
  }
fi
repo_git() {
  if [ -n "$plan_dir" ]; then git -C "$plan_dir" "$@"; else git "$@"; fi
}

key=$(printf '%s' "$(repo_git rev-parse --absolute-git-dir)" | git hash-object --stdin)
base="${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/sdd"
dir="${base}/${key}"

# Optional PLAN_FILE argument scopes the workspace to one plan. The slug is
# the plan basename plus an 8-char hash of the normalized repo-relative
# path: basename alone collides (two plans named plan.md in different
# directories must not share a ledger). No-arg mode is unchanged — it is
# the repo-instance dir other skills use as a generic cache root.
repo_dir="$dir"
if [ -n "$plan_dir" ]; then
  abs="${plan_dir}/$(basename "$plan")"
  toplevel=$(repo_git rev-parse --show-toplevel)
  rel=${abs#"$toplevel"/}
```

Leave the rest of the block (`slug=`, `hash8=`, `plans_root=`, `dir=`, `fi`) as it is; the old `if [ $# -ge 1 ] ...` opening line and its `plan=$1 ... pwd -P) || {...}` lines are replaced by the block above, so the `fi` that closed them now closes `if [ -n "$plan_dir" ]; then`.

- [ ] **Step 4: Run the suite**

Run: `bash tests/claude-code/test-sdd-dir-path.sh && bash tests/claude-code/test-codex-review-dir-path.sh && bash tests/sdd/test-sdd-contract.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-dir tests/claude-code/test-sdd-dir-path.sh
git commit -m "fix(sdd-dir): key a plan's workspace by the plan's repository, not the shell's cwd"
```

---

### Task 10: The item-4 plan's leak-grep Correction

**Risk tier:** standard — an append to a pre-registered record; the text is given in full, but the file is a durable campaign record.

**Files:**
- Modify: `docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md` (append after the last Correction, line 1803)

**Interfaces:**
- Consumes: the controller's item-12 step (the tool's new home is named in the text).

**Mirror:** `docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md:1789-1803` (Correction paragraphs).

- [ ] **Step 1: Append the Correction**

Append to the plan file:

```markdown

**Correction (2026-10-05).** The leak grep in Global Constraints, in the pre-Task-1 Step 4, and in Task 1 Step 6, Task 3 Step 11 and Task 7 Step 6 builds its needles from the shell's own `HTTPS_PROXY`, `NO_PROXY` and `ANTHROPIC_VERTEX_PROJECT_ID`. Inside the Bash sandbox those variables hold the sandbox proxy's values, not the host's, so a grep run there scanned for the wrong strings. The evidence note records that every staged diff was also scanned for the host's values by a counts-only scanner, which found nothing. The scanner now lives at `~/.claude/scripts/realval-scan.py` and reads its needles from the settings env block; plans written after this date name it instead of the shell variables.
```

- [ ] **Step 2: Check**

Run: `grep -c '^\*\*Correction (2026-10-05)' docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md && tail -c 120 docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md`
Expected: `1`, and the tail is the end of the new paragraph.

- [ ] **Step 3: Commit**

```bash
git add docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md
git commit -m "docs(hyperpowers): the item-4 plan records that its leak grep read the sandbox proxy's values"
```

---

### Task 11: The 6.16.0 release notes for Tasks 1 to 5 and 9

**Risk tier:** standard — release-facing documentation across six changes; the text is given in full.

**Files:**
- Modify: `CHANGELOG.md` (the `## 6.16.0 (2026-10-05)` section, after the "A single sentinel failure" bullet)

**Interfaces:**
- Consumes: the commits of Tasks 1 to 5 and 9 (their messages are the facts the notes state).

**Mirror:** `CHANGELOG.md:18-30` (bullet form).

- [ ] **Step 1: Add the release notes**

In `CHANGELOG.md`, after the bullet that begins `- **A single sentinel failure no longer holds a release by itself.**`, add:

```markdown
- **The companion server's `server-started` line means its `server-info` file exists.** `server.cjs` wrote `state/server-info` after printing the announcement, so a reader that acted on the announcement could find no file; the harness's own test lost that race under load. The write now precedes the announcement. The `server.test.js` wrapper also recorded a synchronous assertion failure by aborting the run; it now records one failure and continues to teardown.
- **`stop-server.sh` never reports a server it could not signal as stopped.** The stop loop read a refused `kill` as a dead process. When every signal is refused with "not permitted" and the process is still there, it reports `unverified`, exits 1 and keeps the session files, as the identity path already did.
- **`start-server.sh` no longer kills a recorded pid.** Every start creates a fresh session directory, so the "kill any existing server" block could only ever act on a same-second restart in one shell; it is gone, and stopping a server is `stop-server.sh`'s job, with its identity check.
- **`verdict-normalize` fails closed on an unfinished job.** A companion payload whose `.job.status` is anything but `completed` (failed, cancelled, running, queued, missing or malformed) normalizes to `incomplete` whatever verdict text the record holds; payloads without a `job` property are read as before.
- **`sdd-dir` keys a plan by the plan's repository.** A cross-repository plan invoked from the other checkout used to get a second workspace and a split ledger; the key now comes from the directory that holds the plan, and the no-argument form still keys by the cwd.
```

- [ ] **Step 2: Check**

Run: `grep -c '^## 6.16.0' CHANGELOG.md && grep -c '^- \*\*' CHANGELOG.md`
Expected: `1`, and the bullet count is the previous count plus five.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: the 6.16.0 notes for the brainstorm, normalizer and sdd-dir fixes"
```

---

### Task 12: `runner-guards` "reaches preflight" controls PATH

**Risk tier:** standard — one test's environment control.

**Files:**
- Modify: `evals/test/runner-guards.test.ts:185-194`

**Interfaces:**
- Consumes: nothing. Produces: nothing other tasks use.

**Mirror:** `evals/test/runner-guards.test.ts:205-222` (the empty-`PATH` preflight pattern).

- [ ] **Step 1: Establish the defect without running it**

Do not run the test on a host with `claude` on `PATH`: as written it proceeds into real provisioning, which would launch an agent this plan does not authorize. The defect is on record: on 2026-10-05 the test timed out at 5000 ms in three full-suite runs on this host (Claude Code 2.1.289 on `PATH`), and its comment at line 187-189 states the assumption ("PATH lacks claude here"). Quote that in the implementer report as the RED evidence.

- [ ] **Step 2: Control PATH**

Replace the test body at `runner-guards.test.ts:185-194` with:

```ts
test('A-coding-agents-directive: included agent passes the gate (reaches preflight)', async () => {
  // claude is in the allowlist; the directive gate must NOT short-circuit. The
  // next guard (binary preflight) fires because PATH is pointed at an empty
  // dir here, as the preflight test below does, so a host with claude
  // installed does not run real provisioning. The final_reason must NOT be
  // the directive message.
  const scenarioDir = makeScenarioDir({
    checksContent: '# coding-agents: claude\npre() { :; }\npost() { :; }\n',
  });
  const emptyBin = mkdtempSync(join(tmpdir(), 'emptybin-'));
  const prevPath = process.env['PATH'];
  process.env['PATH'] = `${emptyBin}:/usr/bin:/bin`;
  try {
    const { verdict } = await runGuard({ scenarioDir, codingAgent: 'claude' });
    expect(verdict.final_reason).not.toBe('requires coding-agents: claude');
    expect(verdict.final_reason).toContain('not on PATH');
  } finally {
    if (prevPath === undefined) delete process.env['PATH'];
    else process.env['PATH'] = prevPath;
  }
});
```

- [ ] **Step 3: Run the file**

Run: `bun test test/runner-guards.test.ts && bun x biome check test/runner-guards.test.ts`
Expected: every test passes within its timeout; no lint errors.

- [ ] **Step 4: Commit**

```bash
git add test/runner-guards.test.ts
git commit -m "test(runner-guards): the preflight test controls PATH instead of assuming claude is absent"
```

---

### Task 13: Temp-directory cleanup in `runner-guards.test.ts` and `runner-context.test.ts`

**Risk tier:** standard — test-only edits of one kind in two files.

**Files:**
- Modify: `evals/test/runner-guards.test.ts` (every `mkdtempSync` call, including the one Task 12 added; a new `afterAll`)
- Modify: `evals/test/runner-context.test.ts` (nine `mkdtempSync` calls at 66, 129, 220, 222, 235, 236, 249, 280, 281; a new `afterAll`)

**Interfaces:**
- Produces: a `tmp(prefix)` helper per file that records its directories for `afterAll`.

**Mirror:** `evals/test/runner-workdir-scope.test.ts:21-22` (`afterAll(() => rmSync(root, { recursive: true, force: true }))`).

- [ ] **Step 1: Measure the leak**

Run: `before=$(ls "${TMPDIR:-/tmp}" | grep -cE '^(run|agents|out|scn|sproot|emptybin|bin)-'); bun test test/runner-guards.test.ts test/runner-context.test.ts > /dev/null 2>&1; after=$(ls "${TMPDIR:-/tmp}" | grep -cE '^(run|agents|out|scn|sproot|emptybin|bin)-'); echo "before=$before after=$after"`
Expected (RED): `after` is greater than `before`.

- [ ] **Step 2: Track and remove**

In each file, add near the imports (adding `afterAll` to the `bun:test` import and `rmSync` to the `node:fs` import where missing):

```ts
// Every temp dir a test here creates is removed when the file finishes; a
// suite that left run-*, scn-*, agents-* and friends under $TMPDIR on every
// run was the leak this fixes.
const created: string[] = [];
function tmp(prefix: string): string {
  const dir = mkdtempSync(join(tmpdir(), prefix));
  created.push(dir);
  return dir;
}
afterAll(() => {
  for (const dir of created) rmSync(dir, { recursive: true, force: true });
});
```

Then replace every `mkdtempSync(join(tmpdir(), '<prefix>'))` in the file with `tmp('<prefix>')`. Prefixes present: `runner-guards.test.ts`: `agents-`, `bin-`, `emptybin-`, `out-`, `scn-`, `sproot-`; `runner-context.test.ts`: `run-`, `agents-`. Confirm with `grep -n mkdtempSync <file>` that only the `tmp` helper's own call remains.

- [ ] **Step 3: Re-measure**

Run the Step 1 command again.
Expected: `after` equals `before`; both files `0 fail`.

Run: `bun x biome check test/runner-guards.test.ts test/runner-context.test.ts`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add test/runner-guards.test.ts test/runner-context.test.ts
git commit -m "test: runner-guards and runner-context remove the temp directories they create"
```

---

### Task 14: Fix-loop test timeouts

**Risk tier:** standard — a timeout argument on five tests.

**Files:**
- Modify: `evals/test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts:206, 245, 266, 277, 293`

**Mirror:** bun's `test(name, fn, timeoutMs)` third argument; no existing use in this file.

- [ ] **Step 1: Reproduce**

Run: `bun test test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts`
Expected (RED on this host): the five tests time out at 5000 ms (`stub failed:` with an empty stderr is the consequence of the kill, not a stub defect; the stub answers in about 100 ms standalone).

- [ ] **Step 2: Set the timeout**

Each of the five `test('...', () => {` / `async () => {` calls gets a third argument `60_000` after its closing `}`; above the first of them add:

```ts
// Each of these drives the stub through roughly seventeen node spawns; at
// about 120 ms a spawn on this host that passes bun's 5 s default under load.
```

- [ ] **Step 3: Run**

Run: `bun test test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts && bun x biome check test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts`
Expected: 5 of 5 pass; no lint errors.

- [ ] **Step 4: Commit**

```bash
git add test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts
git commit -m "test(fix-loop): give the spawn-heavy stub tests a 60 s timeout"
```

---

### Task 15: `scenario-brainstorming-tooling-question.test.ts` finds the hyperpowers root

**Risk tier:** standard — test infrastructure with a behaviour change.

**Files:**
- Modify: `evals/test/scenario-brainstorming-tooling-question.test.ts:144-153` (`NORMALIZE`)

**Interfaces:**
- Produces: `hyperpowersRoot(): string` local to the test file.

**Mirror:** `evals/test/runner-e2e.test.ts:46-52` (reading `process.env['...']` with bracket access, the form biome's config accepts in tests).

- [ ] **Step 1: Reproduce the failure**

Run from the nested worktree (`evals/.worktrees/release-hygiene`): `bun test test/scenario-brainstorming-tooling-question.test.ts`
Expected (RED): two failures `verdict-normalize failed: bash: .../evals/.worktrees/skills/requesting-code-review/scripts/verdict-normalize: No such file or directory`.

- [ ] **Step 2: Resolve the root by walking up**

Replace lines 144-153 (`/** The gate's approval authority... */ const NORMALIZE = resolve(import.meta.dir, '..', '..', 'skills', ...)`) with:

```ts
/**
 * The hyperpowers checkout that owns this evals clone. SUPERPOWERS_ROOT wins
 * when it is set and holds the script; otherwise the first ancestor of this
 * file that does, which covers both the main checkout (evals/..) and a
 * worktree under evals/.worktrees/<branch>/ (three levels up).
 */
const NORMALIZE_REL = join('skills', 'requesting-code-review', 'scripts', 'verdict-normalize');
function hyperpowersRoot(): string {
  const fromEnv = process.env['SUPERPOWERS_ROOT'];
  if (fromEnv !== undefined && existsSync(join(fromEnv, NORMALIZE_REL))) return fromEnv;
  let dir = import.meta.dir;
  for (;;) {
    if (existsSync(join(dir, NORMALIZE_REL))) return dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  throw new Error(
    `cannot find the hyperpowers root: SUPERPOWERS_ROOT=${fromEnv ?? '(unset)'} and no ancestor of ${import.meta.dir} holds ${NORMALIZE_REL}`,
  );
}
/** The gate's approval authority, from the hyperpowers checkout above this one. */
const NORMALIZE = join(hyperpowersRoot(), NORMALIZE_REL);
```

Add `existsSync` to the `node:fs` import and `dirname` to the `node:path` import.

- [ ] **Step 3: Run from the worktree**

Run: `bun test test/scenario-brainstorming-tooling-question.test.ts && bun x biome check test/scenario-brainstorming-tooling-question.test.ts`
Expected: `0 fail`; no lint errors. (The main-checkout path is exercised by the post-merge `bun run check` in "After Task 24".)

- [ ] **Step 4: Commit**

```bash
git add test/scenario-brainstorming-tooling-question.test.ts
git commit -m "test(tooling-question): find the hyperpowers root by walking up, not by assuming evals/.."
```

---

### Task 16: The focus-arm runner removes its work directories on every exit

**Risk tier:** standard — a cleanup path in a script with a shell test.

**Files:**
- Modify: `evals/scripts/codex-focus-arm.sh:104-127` (`finish`), `165-166` (the fixture loop's `work=` line)
- Modify: `evals/scripts/codex-focus-arm.test.sh` (one assertion after the treatment arm)

**Interfaces:**
- Produces: `work_dirs` (an array of per-fixture work directories) removed in `finish`; Task 18's failing arm relies on it.

**Mirror:** `evals/scripts/codex-focus-arm.sh:116` (`[ -z "$broker_dir" ] || rm -rf "$broker_dir"` in `finish`).

- [ ] **Step 1: Write the failing assertion**

In `codex-focus-arm.test.sh`, immediately before `run_arm treat "$focus" treatment M H O P P2 Pc || fail ...` (line 79), add:

```bash
work_dirs_before=$(ls "${TMPDIR:-/tmp}" | grep -c '^focus-arm-' || true)
```

and immediately after that `run_arm treat ...` line add:

```bash
# Every per-fixture work directory the arm created is gone when it exits.
work_dirs_after=$(ls "${TMPDIR:-/tmp}" | grep -c '^focus-arm-' || true)
[ "$work_dirs_after" -eq "$work_dirs_before" ] || fail "the arm must remove its per-fixture work directories (before=$work_dirs_before after=$work_dirs_after)"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: `FAIL: the arm must remove its per-fixture work directories (before=N after=N+6)`.

- [ ] **Step 3: Track and remove the work directories**

In `codex-focus-arm.sh`, after `broker_endpoint=""` (line 105) add `work_dirs=()`. In `finish`, after `[ -z "$broker_dir" ] || rm -rf "$broker_dir"` add:

```bash
  # Each fixture's work directory is scratch; a failed arm used to leave them.
  for d in ${work_dirs[@]+"${work_dirs[@]}"}; do rm -rf "$d"; done
```

In the fixture loop, right after `work="$(mktemp -d "${TMPDIR:-/tmp}/focus-arm-$fx.XXXXXX")"` add `work_dirs+=("$work")`.

- [ ] **Step 4: Run the test**

Run: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: `PASS:` line, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/codex-focus-arm.sh scripts/codex-focus-arm.test.sh
git commit -m "fix(codex-focus-arm): remove the per-fixture work directories on every exit"
```

---

### Task 17: The focus-arm runner records base, head, diff and prompt per review

**Risk tier:** high — writes the durable evidence records Task 24 archives and the experiments entry cites.

**Files:**
- Modify: `evals/scripts/codex-focus-arm.sh` (the fixture loop after `git -C "$work" diff "$base" HEAD > "$work/review.diff"`, and inside `for i in 1 2 3` after `focus="$skeleton$recipe"`)
- Modify: `evals/scripts/codex-focus-arm.test.sh:41-50` (the stub companion), plus assertions after the treatment and control arms

**Interfaces:**
- Produces: per fixture and arm `<fx>-<arm>.base`, `<fx>-<arm>.head`, `<fx>-<arm>.diff`; per call `<fx>-<arm>-<i>.prompt`. Task 24 reads them.

**Mirror:** `evals/scripts/codex-focus-arm.test.sh:41-50` (the stub companion records the `--json` argument per call), `93-100` (loops over `treat.focus/*.txt`).

- [ ] **Step 1: Extend the stub and write the failing assertions**

Replace the stub companion heredoc (lines 41-50) with one that also records the reviewed head and the base it was given:

```bash
cat > "$plugin/scripts/codex-companion.mjs" <<'EOF'
import { appendFileSync, readdirSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
const args = process.argv.slice(2);
const dir = process.env.STUB_FOCUS_DIR;
// Calls are numbered by their .txt files; the .head and .base sidecars below
// must not advance the count.
const call = readdirSync(dir).filter((f) => f.endsWith(".txt")).length + 1;
writeFileSync(`${dir}/${call}.txt`, args[args.indexOf("--json") + 1]);
// The arm runs the companion inside the reviewed repository, so the stub is
// an independent witness of the head it reviewed and the base it was given.
const head = execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
writeFileSync(`${dir}/${call}.head`, head);
writeFileSync(`${dir}/${call}.base`, args[args.indexOf("--base") + 1]);
appendFileSync(process.env.STUB_LOG, `review ${process.env.CODEX_COMPANION_APP_SERVER_ENDPOINT}\n`);
if (String(call) === process.env.STUB_COMPANION_FAIL) { console.error("stub: the turn failed"); process.exit(3); }
console.log(JSON.stringify({ review: "Adversarial Review", result: { verdict: "approve", summary: "stub", findings: [], next_steps: [] }, rawOutput: "", parseError: null }));
EOF
```

Add a helper after `count()` (line 73):

```bash
# Captured provenance for one arm: for every fixture, .base equals the --base
# the stub received on each of its three calls, .head equals the HEAD the stub
# saw, .prompt equals the stub's recorded --json argument, and .diff is
# byte-identical to an independent two-commit build of the same fixture files
# (git diff output depends only on content).
check_captures() { # <name> <arm> <fixture>...
  local name="$1" arm="$2"; shift 2
  local k=0 fx i n indep b
  indep="$(mktemp -d "${TMPDIR:-/tmp}/focus-arm-indep.XXXXXX")"
  for fx in "$@"; do
    [ -f "$work/$name/$fx-$arm.base" ] || fail "no .base for $fx ($arm)"
    [ -f "$work/$name/$fx-$arm.head" ] || fail "no .head for $fx ($arm)"
    [ -f "$work/$name/$fx-$arm.diff" ] || fail "no .diff for $fx ($arm)"
    for i in 1 2 3; do
      n=$((k * 3 + i))
      [ "$(cat "$work/$name.focus/$n.base")" = "$(cat "$work/$name/$fx-$arm.base")" ] || fail ".base for $fx ($arm) call $i must equal the --base the stub received"
      [ "$(cat "$work/$name.focus/$n.head")" = "$(cat "$work/$name/$fx-$arm.head")" ] || fail ".head for $fx ($arm) must equal the HEAD the stub saw on call $i"
      cmp -s "$work/$name.focus/$n.txt" "$work/$name/$fx-$arm-$i.prompt" || fail ".prompt for $fx ($arm) call $i must equal the stub's recorded --json argument"
    done
    mkdir -p "$indep/$fx"
    cp "$here/fixtures/codex-focus-arm/$fx/"* "$indep/$fx/"
    git -C "$indep/$fx" init -q
    cp "$here/fixtures/codex-focus-arm/$fx/lib.base.js" "$indep/$fx/lib.js"
    git -C "$indep/$fx" -c user.email=t@t -c user.name=t add -A
    git -C "$indep/$fx" -c user.email=t@t -c user.name=t commit -qm base
    b="$(git -C "$indep/$fx" rev-parse HEAD)"
    cp "$here/fixtures/codex-focus-arm/$fx/lib.js" "$indep/$fx/lib.js"
    git -C "$indep/$fx" -c user.email=t@t -c user.name=t commit -qam head
    git -C "$indep/$fx" diff "$b" HEAD > "$indep/$fx.diff"
    cmp -s "$indep/$fx.diff" "$work/$name/$fx-$arm.diff" || fail ".diff for $fx ($arm) must be byte-identical to an independent base-to-head diff"
    k=$((k + 1))
  done
  rm -rf "$indep"
}
```

After the treatment-arm assertions (the block ending with the `$1` placeholder and `review.diff` checks) add `check_captures treat treatment M H O P P2 Pc`; after the control-arm assertions (the block that follows `run_arm ctl "$focus" control H`) add `check_captures ctl control H`. Extend the final `PASS:` sentence with `, and records base, head, diff and prompt per review for both arms`.

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: `FAIL: no .base for M (treatment)`.

- [ ] **Step 3: Write the records**

In `codex-focus-arm.sh`, after `git -C "$work" diff "$base" HEAD > "$work/review.diff"` add:

```bash
  # Provenance beside the captures: what was reviewed, as the controls' audit
  # found missing (the capture names only the base).
  printf '%s\n' "$base" > "$out/$fx-$arm.base"
  git -C "$work" rev-parse HEAD > "$out/$fx-$arm.head"
  cp "$work/review.diff" "$out/$fx-$arm.diff"
```

Inside the `for i in 1 2 3` loop, after `focus="$skeleton$recipe"` add:

```bash
    printf '%s' "$focus" > "$out/$fx-$arm-$i.prompt"
```

- [ ] **Step 4: Run the test**

Run: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: `PASS:` line, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/codex-focus-arm.sh scripts/codex-focus-arm.test.sh
git commit -m "feat(codex-focus-arm): record base, head, diff and prompt beside every capture"
```

---

### Task 18: The focus-arm build-failure test

**Risk tier:** standard — a test case over existing behaviour (`set -e` plus the `finish` trap).

**Files:**
- Modify: `evals/scripts/codex-focus-arm.test.sh` (a new case before the final `echo "PASS: ..."`)

**Interfaces:**
- Consumes: Task 16's work-dir cleanup (the failing arm must leave none).

**Mirror:** `evals/scripts/codex-focus-arm.test.sh:46-50` at `c80ee21` (the altered-treatment refusal case: `cp -R`, a failing `run_arm`, assertions on stderr and the log).

- [ ] **Step 1: Write the case**

Before the final `echo "PASS: ..."` line add:

```bash
# A fixture whose head does not parse stops the arm before any review, and
# the arm still releases its broker, writes the end record and removes its
# work directory. The script resolves fixtures beside itself, so a copy of the
# script beside a broken copy of H exercises it.
mkdir -p "$work/copy/scripts" "$work/copy/fixtures/codex-focus-arm/H"
cp "$here/codex-focus-arm.sh" "$work/copy/scripts/codex-focus-arm.sh"
cp "$here/fixtures/codex-focus-arm/H/"* "$work/copy/fixtures/codex-focus-arm/H/"
printf '\nthis line does not parse ((\n' >> "$work/copy/fixtures/codex-focus-arm/H/lib.js"
mkdir -p "$work/broken.focus"
work_dirs_before=$(ls "${TMPDIR:-/tmp}" | grep -c '^focus-arm-' || true)
rc=0
PATH="$work/bin:$PATH" CODEX_HOME="$work/codex-home" STUB_LOG="$work/broken.log" STUB_FOCUS_DIR="$work/broken.focus" \
  bash "$work/copy/scripts/codex-focus-arm.sh" "$root" "$plugin" "$focus" treatment "$work/broken" H > "$work/broken.stdout" 2> "$work/broken.stderr" || rc=$?
[ "$rc" -ne 0 ] || fail "a head that does not parse must fail the arm"
grep -q 'SyntaxError' "$work/broken.stderr" || fail "the build failure names the syntax error: $(cat "$work/broken.stderr")"
[ "$(count '^review ' "$work/broken.log")" -eq 0 ] || fail "no review runs when the fixture does not build"
[ "$(count '^shutdown ' "$work/broken.log")" -eq 1 ] || fail "the broker is shut down after a build failure"
[ "$(count '^clear ' "$work/broken.log")" -eq 1 ] || fail "the broker record is cleared after a build failure"
[ -f "$work/broken/runtime-end.txt" ] || fail "the end record is written after a build failure"
work_dirs_after=$(ls "${TMPDIR:-/tmp}" | grep -c '^focus-arm-' || true)
[ "$work_dirs_after" -eq "$work_dirs_before" ] || fail "the work directory is removed after a build failure"
```

Extend the final `PASS:` sentence with `, and stops before any review on a fixture that does not build`.

- [ ] **Step 2: Run the test**

Run: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: `PASS:` line, exit 0. This case documents behaviour `set -euo pipefail` and the `finish` trap already give the script; it has no RED state against the current script, and the report says so. To see it bite, run it once with `set -e` commented out in the copied script: the arm continues into reviews and the `no review runs` assertion fails; restore the copy afterwards (the copy is scratch).

- [ ] **Step 3: Commit**

```bash
git add scripts/codex-focus-arm.test.sh
git commit -m "test(codex-focus-arm): a fixture that does not build stops the arm before any review"
```

---

### Task 19: evals docs: the Gauntlet row, the base-rate table's Gauntlet column, the identity procedure, the recipe

**Risk tier:** standard — living guidance in two files; the text is given in full.

**Files:**
- Modify: `evals/CLAUDE.md:17`
- Modify: `evals/docs/scenario-authoring.md:635-638` (table), `650-655` (procedure), `742` (recipe)

**Mirror:** the table and prose as they stand at the lines named.

- [ ] **Step 1: The Gauntlet row in `CLAUDE.md`**

Replace, in line 17, the cell ``repo `~/Code/prime/gauntlet`; on `PATH` as `gauntlet` `` with ``the `gauntlet` on `PATH` (on this host a shim to the fork checkout); quorum spawns it by name``.

- [ ] **Step 2: The table column**

In `docs/scenario-authoring.md`, the header line 635 gains `| Gauntlet ` between `| harness ` and `| rate (95% Wilson) `, and the separator line gains one more `|---`. Row 1 and row 2 gain the cell `not recorded`; row 3 gains `` `a35607e`, clean state not on record `` in the same position. The sentence beginning "A row added after row 3 also records its Gauntlet identity" (line 650) becomes: "The `Gauntlet` column records the identity: the commit of the Gauntlet checkout that the `gauntlet` on `PATH` runs, and whether that checkout was clean at launch."

- [ ] **Step 3: The identity procedure**

Replace, at lines 652-655, "`git rev-parse HEAD` prints the commit, and `git status --short --untracked-files=no` prints nothing when the tracked files are clean." with: "`git rev-parse HEAD` prints the commit, and `git status --porcelain --untracked-files=all` prints nothing when the checkout is clean (untracked files count, ignored files do not; the flag is explicit because the bare command obeys a `status.showUntrackedFiles=no` setting), the same definition a run's `provenance.json` uses."

- [ ] **Step 4: The recipe**

Replace line 742 `  scratch="$(mktemp -d)"` with `  scratch="$(mktemp -d "${TMPDIR:-/tmp}/suite-at-commit.XXXXXX")"`.

- [ ] **Step 5: Check**

Run: `awk -F'|' 'NR>=635 && NR<=640 && /^\|/ {print NF}' docs/scenario-authoring.md | sort -u`
Expected: a single number (every table line has the same field count).

Run: `sed -n '/^```bash$/,/^```$/p' docs/scenario-authoring.md | sed -n '/git diff --quiet <commit>/,/^fi$/p' | sed 's/<commit>/HEAD/g' | bash -n && echo syntax-ok`
Expected: `syntax-ok`.

Run: `bun run quorum check | tail -2`
Expected: no failing scenario.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md docs/scenario-authoring.md
git commit -m "docs: name Gauntlet by its PATH entry, give the base-rate table a Gauntlet column, align the clean definition, template the recipe's mktemp"
```

---

### Task 20: The provenance module

**Risk tier:** standard — a new module with injected dependencies and unit tests; no runner change yet.

**Files:**
- Create: `evals/src/runner/provenance.ts`
- Modify: `evals/src/contracts/verdict.ts` (add `ProvenanceSchema`, `Provenance`, and the optional `provenance` field)
- Create: `evals/test/runner-provenance.test.ts`

**Interfaces:**
- Produces, in `src/contracts/verdict.ts`:
  - `ProvenanceSchema` (zod) and `type Provenance = { evals_commit: string | null; evals_clean: boolean | null; gauntlet: { path: string | null; checkout: string | null; commit: string | null; clean: boolean | null } }`
  - `FinalVerdictSchema` gains `provenance: ProvenanceSchema.optional()`.
- Produces, in `src/runner/provenance.ts`:
  - `interface ProvenanceDeps { runner: CommandRunner; evalsRoot: string; pathEntries: readonly string[]; readFile(p: string): string | null; exists(p: string): boolean; isDirectory(p: string): boolean; isExecutable(p: string): boolean }` (the spec's second Correction)
  - `captureProvenance(deps: ProvenanceDeps): Provenance`
  - `defaultProvenanceDeps(runner: CommandRunner, evalsRoot: string, pathVar: string): ProvenanceDeps`
  - `renderProvenanceLine(p: Provenance): string` returning `provenance: evals <cell> gauntlet <cell>`.
  Task 21 consumes all of these.

**Mirror:** `evals/src/agents/command-runner.ts:25-30` (the seam), `evals/test/runner-home.test.ts:1-40` (describe/test shape).

- [ ] **Step 1: Write the failing tests**

Create `evals/test/runner-provenance.test.ts`:

```ts
import { afterAll, describe, expect, test } from 'bun:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { CommandResult, CommandRunner } from '../src/agents/command-runner.ts';
import { defaultCommandRunner } from '../src/agents/command-runner.ts';
import { ProvenanceSchema } from '../src/contracts/verdict.ts';
import {
  captureProvenance,
  defaultProvenanceDeps,
  renderProvenanceLine,
  type ProvenanceDeps,
} from '../src/runner/provenance.ts';

// A run records the evals commit and the Gauntlet identity that produced it,
// so a verdict can be re-checked against the exact harness. Every lookup is
// injected: git through the CommandRunner seam, PATH and the filesystem
// through plain functions.

const A = 'a'.repeat(40);
const B = 'b'.repeat(40);

/** A git stand-in keyed by cwd: HEAD, status output, and toplevel per repo. */
function fakeGit(repos: Record<string, { head: string; status: string }>): CommandRunner {
  return {
    run(command, args): CommandResult {
      if (command !== 'git') return { status: 127, stdout: '', stderr: 'not found' };
      const cwd = args[1] as string;
      const repo = Object.entries(repos).find(([root]) => cwd === root || cwd.startsWith(`${root}/`));
      if (repo === undefined) return { status: 128, stdout: '', stderr: 'not a git repository' };
      const [root, r] = repo;
      const sub = args.slice(2).join(' ');
      if (sub === 'rev-parse HEAD') return { status: 0, stdout: `${r.head}\n`, stderr: '' };
      if (sub === 'status --porcelain --untracked-files=all') return { status: 0, stdout: r.status, stderr: '' };
      if (sub === 'rev-parse --show-toplevel') return { status: 0, stdout: `${root}\n`, stderr: '' };
      return { status: 1, stdout: '', stderr: `unexpected: ${sub}` };
    },
  };
}

function deps(over: Partial<ProvenanceDeps>, files: Record<string, string | 'dir'>): ProvenanceDeps {
  return {
    runner: fakeGit({}),
    evalsRoot: '/repos/evals',
    pathEntries: ['/opt/bin'],
    readFile: (p) => (typeof files[p] === 'string' ? (files[p] as string) : null),
    exists: (p) => p in files,
    isDirectory: (p) => files[p] === 'dir',
    isExecutable: (p) => typeof files[p] === 'string' && p.endsWith('/gauntlet'),
    ...over,
  };
}

const realRepos: string[] = [];
afterAll(() => {
  for (const dir of realRepos) rmSync(dir, { recursive: true, force: true });
});

describe('captureProvenance', () => {
  test('clean evals checkout, host shim shape: exec bun run <checkout>/src/index.ts', () => {
    const runner = fakeGit({ '/repos/evals': { head: A, status: '' }, '/repos/gauntlet': { head: B, status: '' } });
    const p = captureProvenance(deps({ runner }, {
      '/opt/bin/gauntlet': '#!/usr/bin/env bash\n# the fork\nexec bun run /repos/gauntlet/src/index.ts "$@"\n',
      '/repos/gauntlet/src/index.ts': 'x',
      '/repos/gauntlet': 'dir',
    }));
    expect(p).toEqual({
      evals_commit: A, evals_clean: true,
      gauntlet: { path: '/opt/bin/gauntlet', checkout: '/repos/gauntlet', commit: B, clean: true },
    });
    expect(ProvenanceSchema.parse(p)).toEqual(p);
  });

  test('tracked-dirty and untracked-dirty both report dirty; the shebang line is never a path token', () => {
    const runner = fakeGit({ '/repos/evals': { head: A, status: ' M src/x.ts\n' }, '/repos/gauntlet': { head: B, status: '?? new.ts\n' } });
    const p = captureProvenance(deps({ runner }, {
      '/opt/bin/gauntlet': '#!/usr/bin/env bash\nexec bun run /repos/gauntlet/src/index.ts "$@"\n',
      '/usr/bin/env': 'x',
      '/repos/gauntlet/src/index.ts': 'x',
    }));
    expect(p.evals_clean).toBe(false);
    expect(p.gauntlet.clean).toBe(false);
    expect(p.gauntlet.checkout).toBe('/repos/gauntlet');
  });

  test('a cd <abs> shim queries the directory itself, whose parent is not a repository', () => {
    const runner = fakeGit({ '/repos/evals': { head: A, status: '' }, '/elsewhere/checkout': { head: B, status: '' } });
    const p = captureProvenance(deps({ runner }, {
      '/opt/bin/gauntlet': '#!/bin/sh\ncd /elsewhere/checkout && exec bun run src/index.ts "$@"\n',
      '/elsewhere/checkout': 'dir',
    }));
    expect(p.gauntlet.checkout).toBe('/elsewhere/checkout');
    expect(p.gauntlet.commit).toBe(B);
  });

  test('a real binary (no shebang) resolves through its own directory', () => {
    const runner = fakeGit({ '/repos/evals': { head: A, status: '' }, '/repos/gauntlet': { head: B, status: '' } });
    const p = captureProvenance(deps({ runner }, { '/repos/gauntlet/bin/gauntlet': '\u007fELF', '/repos/gauntlet': 'dir' }));
    expect(p.gauntlet.path).toBeNull();
    const p2 = captureProvenance(deps({ runner, pathEntries: ['/repos/gauntlet/bin'] }, { '/repos/gauntlet/bin/gauntlet': '\u007fELF', '/repos/gauntlet': 'dir' }));
    expect(p2.gauntlet).toEqual({ path: '/repos/gauntlet/bin/gauntlet', checkout: '/repos/gauntlet', commit: B, clean: true });
  });

  test('git absent and gauntlet off PATH yield nulls, never a throw', () => {
    const runner: CommandRunner = { run: () => ({ status: null, stdout: '', stderr: 'spawn git ENOENT' }) };
    const p = captureProvenance(deps({ runner, pathEntries: ['/nowhere', ''] }, {}));
    expect(p).toEqual({ evals_commit: null, evals_clean: null, gauntlet: { path: null, checkout: null, commit: null, clean: null } });
  });

  test('ignored-only is clean and status.showUntrackedFiles=no cannot hide an untracked file (real git)', () => {
    const repo = mkdtempSync(join(tmpdir(), 'prov-'));
    realRepos.push(repo);
    const g = (...args: string[]) => spawnSync('git', ['-C', repo, ...args], { encoding: 'utf8' });
    g('init', '-q');
    g('config', 'user.email', 't@t');
    g('config', 'user.name', 't');
    g('config', 'status.showUntrackedFiles', 'no');
    writeFileSync(join(repo, '.gitignore'), 'ignored.txt\n');
    g('add', '.gitignore');
    g('commit', '-qm', 'init');
    const real = defaultProvenanceDeps(defaultCommandRunner, repo, '');
    writeFileSync(join(repo, 'ignored.txt'), 'x');
    expect(captureProvenance(real).evals_clean).toBe(true);
    writeFileSync(join(repo, 'untracked.txt'), 'x');
    expect(captureProvenance(real).evals_clean).toBe(false);
  });
});

describe('renderProvenanceLine', () => {
  const g = (commit: string | null, clean: boolean | null) => ({ path: null, checkout: null, commit, clean });
  test('the four cells', () => {
    expect(renderProvenanceLine({ evals_commit: A, evals_clean: true, gauntlet: g(B, false) })).toBe('provenance: evals aaaaaaa gauntlet bbbbbbb+dirty');
    expect(renderProvenanceLine({ evals_commit: A, evals_clean: null, gauntlet: g(null, null) })).toBe('provenance: evals aaaaaaa? gauntlet unknown');
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bun test test/runner-provenance.test.ts`
Expected: `Export named 'ProvenanceSchema' not found` or `Cannot find module '../src/runner/provenance.ts'`.

- [ ] **Step 3: Add the schema**

In `src/contracts/verdict.ts`, before `FinalVerdictSchema`:

```ts
// What produced a run: the evals commit and the Gauntlet identity, captured
// at setup so a verdict can be re-checked against the exact harness. Every
// field is null when its lookup failed; the runner never fails a run over it.
export const ProvenanceSchema = z.object({
  evals_commit: z.string().nullable(),
  evals_clean: z.boolean().nullable(),
  gauntlet: z.object({
    path: z.string().nullable(),
    checkout: z.string().nullable(),
    commit: z.string().nullable(),
    clean: z.boolean().nullable(),
  }),
});
export type Provenance = z.infer<typeof ProvenanceSchema>;
```

and inside `FinalVerdictSchema`, after `trial: TrialSchema.optional(),`:

```ts
  // Harness provenance (Task 20 of the 2026-10-05 release-hygiene plan).
  // Optional: verdicts written before it existed, and runs interrupted
  // before setup captured it, carry no field.
  provenance: ProvenanceSchema.optional(),
```

- [ ] **Step 4: Write the module**

Create `src/runner/provenance.ts`:

```ts
import { accessSync, constants, existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import type { CommandRunner } from '../agents/command-runner.ts';
import type { Provenance } from '../contracts/verdict.ts';

// Every lookup is injected so the module is testable without a real PATH,
// filesystem or git: the runner for git, the path entries for the gauntlet
// lookup, and three filesystem predicates.
export interface ProvenanceDeps {
  readonly runner: CommandRunner;
  readonly evalsRoot: string;
  readonly pathEntries: readonly string[];
  readonly readFile: (p: string) => string | null;
  readonly exists: (p: string) => boolean;
  readonly isDirectory: (p: string) => boolean;
  readonly isExecutable: (p: string) => boolean;
}

function gitOut(runner: CommandRunner, cwd: string, args: readonly string[]): string | null {
  const r = runner.run('git', ['-C', cwd, ...args]);
  return r.status === 0 ? r.stdout : null;
}

function commitOf(runner: CommandRunner, cwd: string): string | null {
  const out = gitOut(runner, cwd, ['rev-parse', 'HEAD']);
  if (out === null) return null;
  const c = out.trim();
  return /^[0-9a-f]{40}$/.test(c) ? c : null;
}

// Clean means `git status --porcelain --untracked-files=all` prints nothing:
// untracked files count, ignored files do not, and the explicit flag keeps a
// status.showUntrackedFiles=no setting from hiding them.
function cleanOf(runner: CommandRunner, cwd: string): boolean | null {
  const out = gitOut(runner, cwd, ['status', '--porcelain', '--untracked-files=all']);
  return out === null ? null : out.trim() === '';
}

function toplevelOf(runner: CommandRunner, cwd: string): string | null {
  const out = gitOut(runner, cwd, ['rev-parse', '--show-toplevel']);
  return out === null ? null : out.trim() || null;
}

export function resolveOnPath(name: string, deps: ProvenanceDeps): string | null {
  for (const dir of deps.pathEntries) {
    if (dir === '') continue;
    const candidate = join(dir, name);
    if (deps.isExecutable(candidate)) return candidate;
  }
  return null;
}

// A shell shim names its target somewhere in its body: the host's is
// `exec bun run <checkout>/src/index.ts "$@"`, a `cd <checkout> && ...` form
// is the other common one. The first absolute path token that exists, read
// after the shebang line and skipping comment lines, is the target. A file
// without a shebang is the binary itself and resolves through its own dir.
export function shimTarget(file: string, deps: ProvenanceDeps): string | null {
  const text = deps.readFile(file);
  if (text === null || !text.startsWith('#!')) return null;
  const lines = text.split('\n').slice(1);
  for (const line of lines) {
    if (line.trimStart().startsWith('#')) continue;
    for (const raw of line.split(/\s+/)) {
      const token = raw.replace(/^["']+|["']+$/g, '');
      if (token.startsWith('/') && deps.exists(token)) return token;
    }
  }
  return null;
}

export function captureProvenance(deps: ProvenanceDeps): Provenance {
  const gauntlet: Provenance['gauntlet'] = { path: null, checkout: null, commit: null, clean: null };
  const found = resolveOnPath('gauntlet', deps);
  if (found !== null) {
    gauntlet.path = found;
    const target = shimTarget(found, deps);
    // A directory token (cd <checkout>) is queried itself; a file token or
    // the binary itself through its directory.
    const probeDir =
      target === null ? dirname(found) : deps.isDirectory(target) ? target : dirname(target);
    const checkout = toplevelOf(deps.runner, probeDir);
    if (checkout !== null) {
      gauntlet.checkout = checkout;
      gauntlet.commit = commitOf(deps.runner, checkout);
      gauntlet.clean = cleanOf(deps.runner, checkout);
    }
  }
  return {
    evals_commit: commitOf(deps.runner, deps.evalsRoot),
    evals_clean: cleanOf(deps.runner, deps.evalsRoot),
    gauntlet,
  };
}

export function defaultProvenanceDeps(
  runner: CommandRunner,
  evalsRoot: string,
  pathVar: string,
): ProvenanceDeps {
  return {
    runner,
    evalsRoot,
    pathEntries: pathVar.split(':'),
    readFile: (p) => {
      try {
        return readFileSync(p, 'utf8');
      } catch {
        return null;
      }
    },
    exists: (p) => existsSync(p),
    isDirectory: (p) => {
      try {
        return statSync(p).isDirectory();
      } catch {
        return false;
      }
    },
    isExecutable: (p) => {
      try {
        accessSync(p, constants.X_OK);
        return statSync(p).isFile();
      } catch {
        return false;
      }
    },
  };
}

function cell(commit: string | null, clean: boolean | null): string {
  if (commit === null) return 'unknown';
  const c = commit.slice(0, 7);
  if (clean === true) return c;
  if (clean === false) return `${c}+dirty`;
  return `${c}?`;
}

export function renderProvenanceLine(p: Provenance): string {
  return `provenance: evals ${cell(p.evals_commit, p.evals_clean)} gauntlet ${cell(p.gauntlet.commit, p.gauntlet.clean)}`;
}
```

- [ ] **Step 5: Run the tests, lint and typecheck**

Run: `bun test test/runner-provenance.test.ts && bun x biome check src/runner/provenance.ts src/contracts/verdict.ts test/runner-provenance.test.ts && bun run typecheck`
Expected: all tests pass; no biome errors; `tsc --noEmit` clean. (If biome's formatter wants different line breaks, apply them; behaviour does not change.)

- [ ] **Step 6: Commit**

```bash
git add src/runner/provenance.ts src/contracts/verdict.ts test/runner-provenance.test.ts
git commit -m "feat(runner): a provenance module records the evals commit and the Gauntlet identity"
```

---

### Task 21: Wire provenance into the runner, the stopped verdict and `quorum show`

**Risk tier:** high — changes the verdict writers, the durable record every cell reads.

**Files:**
- Modify: `evals/src/runner/index.ts` (after line 878; the `identified` object at 899-905)
- Modify: `evals/src/runner/stopped.ts:1-3, 18-39`
- Modify: `evals/src/cli/render.ts:321-336` (`formatHeader`)
- Modify: `evals/test/runner-e2e.test.ts` (the pass-run test at 89-96), `evals/test/cli-run-sigint.test.ts:156-175`, `evals/test/cli-show.test.ts` (one new test), `evals/test/runner-stopped.test.ts` (two new cases)

**Interfaces:**
- Consumes: `captureProvenance`, `defaultProvenanceDeps`, `renderProvenanceLine`, `ProvenanceSchema`, `Provenance` from Task 20; `defaultCommandRunner` (`src/agents/command-runner.ts:56`); `repoRoot()` and `getEnv()` already imported in `index.ts`.
- Produces: `<runDir>/provenance.json`; `verdict.provenance` on every verdict the run writes after capture; the `provenance:` line in `quorum show`.

**Mirror:** `evals/src/runner/index.ts:899-910` (how identity fields join the verdict); `evals/test/cli-run-sigint.test.ts:156-175` (reading the stopped verdict).

Assumption: the renderer `cli-show.test.ts` drives is the function at `render.ts:405-415` that calls `formatHeader` (line 411); validate via `grep -n 'formatHeader(' src/cli/render.ts` and the test's import, before this task's Step 1.

- [ ] **Step 1: Write the failing assertions**

In `test/runner-e2e.test.ts`, in the test `mock-gauntlet drives a full pass run to a parity verdict`, change its first line from `const { verdict } = await runWithFixture(...)` to `const { runDir, verdict } = await runWithFixture(...)` and after the existing verdict assertions add:

```ts
  // Provenance is written once at setup and carried into the verdict.
  const written = JSON.parse(readFileSync(join(runDir, 'provenance.json'), 'utf8'));
  expect(verdict.provenance).toEqual(written);
  const head = spawnSync('git', ['-C', resolve(import.meta.dir, '..'), 'rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout.trim();
  expect(written.evals_commit).toBe(head);
```

(add `spawnSync` from `node:child_process`, `readFileSync` from `node:fs`, `resolve` from `node:path` to the imports where missing).

In `test/cli-run-sigint.test.ts`, after the identity assertions (line 175) add:

```ts
    // The stopped verdict carries the provenance the run captured at setup.
    const written = JSON.parse(readFileSync(join(runDir, 'provenance.json'), 'utf8'));
    expect(verdict.provenance).toEqual(written);
```

In `test/runner-stopped.test.ts`, add two cases over `writeStoppedVerdict(runDir, identity)` with a fresh `mkdtempSync` run dir and the identity `{ scenario: 'scn', codingAgent: 'claude', startedAt: '2026-10-05T00:00:00.000Z' }` (imports as the file already has them, plus `writeFileSync` where missing; nothing else is added, biome's `noUnusedImports` is an error):

```ts
test('a stopped verdict written before provenance.json exists carries no provenance field', () => {
  const runDir = mkdtempSync(join(tmpdir(), 'stopped-'));
  writeStoppedVerdict(runDir, { scenario: 'scn', codingAgent: 'claude', startedAt: '2026-10-05T00:00:00.000Z' });
  const verdict = JSON.parse(readFileSync(join(runDir, 'verdict.json'), 'utf8'));
  expect(verdict.final).toBe('indeterminate');
  expect('provenance' in verdict).toBe(false);
});

test('a stopped verdict written after provenance.json exists carries it', () => {
  const runDir = mkdtempSync(join(tmpdir(), 'stopped-'));
  const provenance = { evals_commit: 'a'.repeat(40), evals_clean: true, gauntlet: { path: null, checkout: null, commit: null, clean: null } };
  writeFileSync(join(runDir, 'provenance.json'), JSON.stringify(provenance));
  writeStoppedVerdict(runDir, { scenario: 'scn', codingAgent: 'claude', startedAt: '2026-10-05T00:00:00.000Z' });
  const verdict = JSON.parse(readFileSync(join(runDir, 'verdict.json'), 'utf8'));
  expect(verdict.provenance).toEqual(provenance);
});
```

In `test/cli-show.test.ts`, add a test that renders a verdict fixture carrying
`provenance: { evals_commit: 'a'.repeat(40), evals_clean: true, gauntlet: { path: '/opt/bin/gauntlet', checkout: '/repos/g', commit: 'b'.repeat(40), clean: false } }` through the same renderer the file's other tests call, splits the output on `\n`, and asserts `toContain('provenance: evals aaaaaaa gauntlet bbbbbbb+dirty')` on the array of lines (whole-line equality); and a second assertion that a verdict without the field yields no line starting with `provenance:`.

- [ ] **Step 2: Run them to verify they fail**

Run: `bun test test/runner-e2e.test.ts test/cli-run-sigint.test.ts test/cli-show.test.ts test/runner-stopped.test.ts`
Expected: the e2e and SIGINT assertions fail (`ENOENT provenance.json`, `undefined`), the show test fails (missing line), the first stopped case passes already and the second fails (`undefined`); everything else passes.

- [ ] **Step 3: Capture at setup and carry into both writers**

In `src/runner/index.ts`, the `a.onRunDir?.(runDir)` call stays exactly where it is, immediately after `const runDir = allocateRunDir(a.outRoot, scenario, a.codingAgent);` (line 878): the SIGINT handler must own the run dir from the first instant, and a SIGINT that lands between that call and the provenance write produces a stopped verdict without the optional field (the `readProvenance` branch below). Immediately after the `onRunDir` call, add:

```ts
  // Captured before setup and written before anything else in the run dir,
  // so every later writer, the SIGINT handler's included, finds it there.
  const provenance = captureProvenance(
    defaultProvenanceDeps(defaultCommandRunner, repoRoot(), getEnv('PATH') ?? ''),
  );
  writeFileSync(join(runDir, 'provenance.json'), `${JSON.stringify(provenance, null, 2)}\n`);
```

and in the `identified` object (899-905) add `provenance,` after `started_at: startedAt,`. Import `captureProvenance` and `defaultProvenanceDeps` from `./provenance.ts`.

In `src/runner/stopped.ts`, change the imports to `import { existsSync, readFileSync, writeFileSync } from 'node:fs';` and `import { ProvenanceSchema } from '../contracts/verdict.ts'; import type { FinalVerdict, Provenance, Trial } from '../contracts/verdict.ts';`; make `buildStoppedVerdict(id: StoppedIdentity, provenance?: Provenance): FinalVerdict` spread `...(provenance !== undefined ? { provenance } : {})` after the `trial` spread; and make `writeStoppedVerdict` read the file the runner wrote:

```ts
// The runner writes provenance.json before anything else in the run dir, so a
// stopped verdict can carry it; a run interrupted even earlier writes none.
function readProvenance(runDir: string): Provenance | undefined {
  const file = join(runDir, 'provenance.json');
  if (!existsSync(file)) return undefined;
  const parsed = ProvenanceSchema.safeParse(JSON.parse(readFileSync(file, 'utf8')));
  return parsed.success ? parsed.data : undefined;
}

export function writeStoppedVerdict(runDir: string, id: StoppedIdentity): void {
  writeFileSync(
    join(runDir, 'verdict.json'),
    `${JSON.stringify(buildStoppedVerdict(id, readProvenance(runDir)), null, 2)}\n`,
  );
}
```

In `src/cli/render.ts`, `formatHeader` (lines 321-336) returns one more line when the field is present, with no label prefix so the whole output line is the `renderProvenanceLine` text; replace its `return (` expression with:

```ts
  const provenance =
    verdict.provenance === undefined
      ? ''
      : `${renderProvenanceLine(verdict.provenance)}\n`;
  return (
    `${label('run-dir  ', color)} ${runDir}\n` +
    `${label('final    ', color)} ${finalStyled}\n` +
    `${label('reason   ', color)} ${verdict.final_reason}\n` +
    provenance
  );
```

Import `renderProvenanceLine` from `../runner/provenance.ts`.

- [ ] **Step 4: Run the suites, lint and typecheck**

Run: `bun test test/runner-e2e.test.ts test/cli-run-sigint.test.ts test/cli-show.test.ts test/runner-provenance.test.ts test/runner-stopped.test.ts && bun x biome check src/runner/index.ts src/runner/stopped.ts src/cli/render.ts test/runner-e2e.test.ts test/cli-run-sigint.test.ts test/cli-show.test.ts test/runner-stopped.test.ts && bun run typecheck`
Expected: all pass, no lint errors, tsc clean.

- [ ] **Step 5: Commit**

```bash
git add src/runner/index.ts src/runner/stopped.ts src/cli/render.ts test/runner-e2e.test.ts test/cli-run-sigint.test.ts test/cli-show.test.ts test/runner-stopped.test.ts
git commit -m "feat(runner): write provenance.json at setup, carry it into every verdict, and show it"
```

---

### Task 22: The seven task-less Codex stubs

**Risk tier:** high — the stubs' output is what the approach and spec gates consume in those scenarios.

**Files:**
- Modify: `evals/scenarios/brainstorming-bounded-fires-approach-gate/setup.sh` (insert before line 92), `brainstorming-router-escalates-b1-userid-param/setup.sh`, `b2-config-module`, `b3-logging`, `b4-reusable-validation`, `b5-prefs-storage` (each: insert before line 104), `brainstorming-router-no-downgrade/setup.sh` (insert before line 103)
- Create: `evals/test/scenario-codex-stub-task.test.ts`

**Interfaces:**
- Consumes: the reference `task` implementation at `scenarios/brainstorming-asks-tooling-question/setup.sh`: `CALL_LOG` (line 53), the prompt-file parsing and `classify` block through `const kind = classify(promptText);` (58-85), the call-log append (87-90), `APPROACHES` and `DOC_REVIEW` with their comments (92-139), and the `task` branch (152-175). The reference's `setup` branch (141-150) is not copied: the targets already have their own.

**Mirror:** `evals/test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts:36-46` (`stubSource()` extracts the heredoc with a regex) and `141-149` (`run` via `spawnSync('node', [stub, ...])`).

- [ ] **Step 1: Write the failing test**

Create `evals/test/scenario-codex-stub-task.test.ts`:

```ts
import { afterAll, expect, test } from 'bun:test';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

// Seven brainstorming scenarios seed a Codex companion stub for the approach
// and spec gates, which call the companion's `task` subcommand; the stubs
// answered task-reviewer/review/adversarial-review only (and `{}` to task),
// so those gates ran a degraded path. Each stub must now answer `task`
// exactly as the reference stub (brainstorming-asks-tooling-question) does,
// for every classification, and its other subcommands must be unchanged.

const SCENARIOS = resolve(import.meta.dir, '..', 'scenarios');
const REFERENCE = 'brainstorming-asks-tooling-question';
const PORTED = [
  'brainstorming-bounded-fires-approach-gate',
  'brainstorming-router-escalates-b1-userid-param',
  'brainstorming-router-escalates-b2-config-module',
  'brainstorming-router-escalates-b3-logging',
  'brainstorming-router-escalates-b4-reusable-validation',
  'brainstorming-router-escalates-b5-prefs-storage',
  'brainstorming-router-no-downgrade',
];
// One prompt per branch of the reference's classify(): approaches wins on
// approach-context.md, plan-review on "implementation plan", spec-review on
// "-design.md", anything else is document-review.
const PROMPTS: Record<string, string> = {
  approaches: 'Read approach-context.md and return Approaches (2-3, each genuinely different).',
  'plan-review': 'Review the implementation plan at /tmp/x/plan.md against the spec.',
  'spec-review': 'Review the spec document at /tmp/x/2026-01-01-foo-design.md for completeness.',
  'document-review': 'Review the document at /tmp/x/notes.md and report.',
};
// Outputs at the base commit (recorded 2026-10-05, identical across the
// seven), written without a trailing newline. The port must not change them.
const STATUS_BEFORE = '{"running":[],"latestFinished":null,"recent":[]}';
const REVIEW_BEFORE = '{"verdict":"approve","summary":"Stub: always approve, no findings.","findings":[],"next_steps":[]}';

const root = mkdtempSync(join(tmpdir(), 'stub-task-'));
afterAll(() => rmSync(root, { recursive: true, force: true }));

function stubSource(scenario: string): string {
  const setup = readFileSync(join(SCENARIOS, scenario, 'setup.sh'), 'utf8');
  const m = /codex-companion\.mjs" <<'STUB'\n([\s\S]*?)\nSTUB\n/.exec(setup);
  if (m === null) throw new Error(`${scenario}: no codex-companion.mjs heredoc`);
  return m[1] as string;
}

function installStub(scenario: string, tag: string): string {
  const dir = join(root, `${scenario}-${tag}`);
  mkdirSync(dir, { recursive: true });
  const stub = join(dir, 'codex-companion.mjs');
  writeFileSync(stub, `${stubSource(scenario)}\n`);
  return stub;
}

function run(stub: string, args: string[]): { status: number | null; stdout: string } {
  const r = spawnSync('node', [stub, ...args], { encoding: 'utf8' });
  return { status: r.status, stdout: r.stdout };
}

function promptFile(kind: string): string {
  const file = join(root, `${kind}.prompt.md`);
  writeFileSync(file, PROMPTS[kind] as string);
  return file;
}

for (const kind of Object.keys(PROMPTS)) {
  test(`every ported stub answers task (${kind}) exactly as the reference`, () => {
    const want = run(installStub(REFERENCE, kind), ['task', '--fresh', '--prompt-file', promptFile(kind)]);
    expect(want.status).toBe(0);
    expect(want.stdout.length).toBeGreaterThan(2);
    const wantJson = run(installStub(REFERENCE, `${kind}-json`), ['task', '--fresh', '--prompt-file', promptFile(kind), '--json']);
    for (const scenario of PORTED) {
      const got = run(installStub(scenario, kind), ['task', '--fresh', '--prompt-file', promptFile(kind)]);
      expect(got).toEqual(want);
      const gotJson = run(installStub(scenario, `${kind}-json`), ['task', '--fresh', '--prompt-file', promptFile(kind), '--json']);
      expect(gotJson).toEqual(wantJson);
    }
  });
}

test('the other subcommands are unchanged by the port', () => {
  for (const scenario of PORTED) {
    expect(run(installStub(scenario, 'status'), ['status', '--json'])).toEqual({ status: 0, stdout: STATUS_BEFORE });
    expect(run(installStub(scenario, 'review'), ['adversarial-review', '--base', '0'.repeat(40), '--json', 'focus'])).toEqual({ status: 0, stdout: REVIEW_BEFORE });
  }
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bun test test/scenario-codex-stub-task.test.ts`
Expected: the four `task` tests fail (each ported stub prints `{}` with exit 0 for `task`, which differs from the reference's body); the unchanged-subcommands test passes at the base commit. If it does not, the base has moved: re-record `STATUS_BEFORE` and `REVIEW_BEFORE` from the stubs before any port, never after.

- [ ] **Step 3: Port the task implementation**

For each of the seven `setup.sh` files, inside the `codex-companion.mjs` heredoc, insert before the line `if (sub === "task-reviewer" || sub === "review" || sub === "adversarial-review") {` the following, copied verbatim from `scenarios/brainstorming-asks-tooling-question/setup.sh` and located by construct (line numbers as at `c80ee21`): `const CALL_LOG = path.join(HERE, "calls.log");` (line 53); the block from the comment `// The prompt arrives as` through `const kind = classify(promptText);` (58-85); the `firstLine` constant and the guarded `fs.appendFileSync(CALL_LOG, ...)` try block (87-90); the block from the comment `// The approach gate's output shape` through the closing backtick-semicolon of `DOC_REVIEW` (92-139); and the `if (sub === "task") { ... }` block (152-175). Nothing between `DOC_REVIEW` and the `task` branch is copied (that is the reference's own `setup` branch, which every target already has). Do not change the targets' existing lines.

- [ ] **Step 4: Run the test and the scenario validator**

Run: `bun test test/scenario-codex-stub-task.test.ts && bun run quorum check | tail -3`
Expected: all tests pass; every scenario `ok`.

- [ ] **Step 5: Commit**

```bash
git add scenarios/brainstorming-bounded-fires-approach-gate/setup.sh scenarios/brainstorming-router-escalates-b1-userid-param/setup.sh scenarios/brainstorming-router-escalates-b2-config-module/setup.sh scenarios/brainstorming-router-escalates-b3-logging/setup.sh scenarios/brainstorming-router-escalates-b4-reusable-validation/setup.sh scenarios/brainstorming-router-escalates-b5-prefs-storage/setup.sh scenarios/brainstorming-router-no-downgrade/setup.sh test/scenario-codex-stub-task.test.ts
git commit -m "fix(scenarios): the seven brainstorming Codex stubs answer the task subcommand the document gates call"
```

---

### Task 23: Fixture P3

**Risk tier:** standard — a fixture, a one-line mapping, and an assertion in the focus-arm test.

**Files:**
- Create: `evals/fixtures/codex-focus-arm/P3/` (copies of P's `lib.base.js`, `lib.js`, `test.js`; an edited `REQUIREMENTS.md`)
- Modify: `evals/scripts/codex-focus-arm.sh:38` (`P|P2)` becomes `P|P2|P3)`)
- Modify: `evals/scripts/codex-focus-arm.test.sh` (one assertion)

**Interfaces:**
- Produces: fixture `P3`, accepted by the runner; Task 24 runs it.

**Mirror:** `evals/fixtures/codex-focus-arm/P/REQUIREMENTS.md:10-12`.

- [ ] **Step 1: Write the failing assertion**

In `codex-focus-arm.test.sh`, before the treatment-arm `run_arm`, add:

```bash
# P3 is P with the twelve-hex-digit invariant sentence dropped from its
# requirements, and nothing else: the control that found no over-rating on P
# may have been helped by that sentence.
expected_p3_diff="$(printf '%s\n' \
  'diff -r fixtures/codex-focus-arm/P/REQUIREMENTS.md fixtures/codex-focus-arm/P3/REQUIREMENTS.md' \
  '10,11c10,11' \
  '< Workspace directories are created only by `createWorkspace`, which names them' \
  '< with twelve lowercase hex digits. Existing behaviour must not change. Tests for' \
  '---' \
  '> Workspace directories are created only by `createWorkspace`. Existing' \
  '> behaviour must not change. Tests for')"
actual_p3_diff="$(cd "$here" && diff -r fixtures/codex-focus-arm/P fixtures/codex-focus-arm/P3 || true)"
[ "$actual_p3_diff" = "$expected_p3_diff" ] || fail "P3 must differ from P only by the declared REQUIREMENTS.md hunk; got: $actual_p3_diff"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: `FAIL: P3 must differ from P only by the declared REQUIREMENTS.md hunk` (P3 does not exist: `diff` reports `Only in`).

- [ ] **Step 3: Create P3 and the mapping**

```bash
cp -R fixtures/codex-focus-arm/P fixtures/codex-focus-arm/P3
```

In `fixtures/codex-focus-arm/P3/REQUIREMENTS.md` replace lines 10-11:

```
Workspace directories are created only by `createWorkspace`, which names them
with twelve lowercase hex digits. Existing behaviour must not change. Tests for
```

with:

```
Workspace directories are created only by `createWorkspace`. Existing
behaviour must not change. Tests for
```

In `codex-focus-arm.sh` line 38, `P|P2) printf '%s' "report and count workspaces" ;;` becomes `P|P2|P3) printf '%s' "report and count workspaces" ;;`.

- [ ] **Step 4: Run the test**

Run: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: `PASS:` line, exit 0. Also `cd fixtures/codex-focus-arm/P3 && node --check lib.js && node test.js` exits 0.

- [ ] **Step 5: Commit**

```bash
git add fixtures/codex-focus-arm/P3 scripts/codex-focus-arm.sh scripts/codex-focus-arm.test.sh
git commit -m "feat(fixtures): P3, fixture P without the invariant sentence in its requirements"
```

---

### Task 24: The P3 control run and its record

**Risk tier:** high — produces the durable evidence records and the experiments entry a later decision reads.

**Files:**
- Create: `evals/evidence/2026-10-05-release-hygiene/README.md`
- Create: `evals/evidence/2026-10-05-release-hygiene/task-24-runs/control-P3/` (the arm's output directory, copied in from scratch)
- Create: `evals/docs/experiments/2026-10-05-p3-control.md`

**Interfaces:**
- Consumes: Task 17's `.base`/`.head`/`.diff`/`.prompt` files, Task 16's cleanup, Task 23's fixture; the item-4 focus directory `evidence/2026-10-03-review-calibration-and-sentinel-scope/` (`focus-control.txt`, `focus-treatment.txt`, `cap-sentence.txt`); codex-plugin-cc at `/Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6`.

**Mirror:** `evals/docs/experiments/2026-09-30-a1-core-fixed-fixture-rerun.md:1-11` (entry shape); `evals/evidence/README.md:13-33` (layout and the commit steps); `evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P2/` (an archived arm).

- [ ] **Step 1 (controller): Launch the control arm into scratch**

From the evals worktree, in an unsandboxed background shell with a 40-minute timeout, exactly:

```bash
scratch="$(mktemp -d "${TMPDIR:-/tmp}/p3-control.XXXXXX")"; echo "$scratch" > /tmp/claude-502/p3-control-scratch.txt
bash scripts/codex-focus-arm.sh /Users/johnss51/Development/agents/hyperpowers /Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6 "$(pwd)/evidence/2026-10-03-review-calibration-and-sentinel-scope" control "$scratch" P3 > "$scratch/arm.log" 2>&1; echo "arm rc=$?" >> "$scratch/arm.log"
```

Wait for it (the shell's completion notification; three real reviews, several minutes). Then copy, never move: `mkdir -p evidence/2026-10-05-release-hygiene/task-24-runs && cp -R "$scratch" evidence/2026-10-05-release-hygiene/task-24-runs/control-P3`.

- [ ] **Step 2 (implementer): Verify the artifacts**

Run, from `evidence/2026-10-05-release-hygiene/task-24-runs/control-P3`:

```bash
set -e
tail -1 arm.log | grep -qx 'arm rc=0'
cmp runtime-start.txt runtime-end.txt
grep -q '^companion 1\.0\.6$' runtime-start.txt
grep -q '^codex-binary /' runtime-start.txt
grep -q '^codex-version codex-cli ' runtime-start.txt
! grep -q stub runtime-start.txt
[ "$(ls P3-control-*.json | wc -l | tr -d ' ')" = "3" ]
[ "$(ls P3-control-*.prompt | wc -l | tr -d ' ')" = "3" ]
[ "$(grep -cE '^P3 control [123] \{"result":' arm.log)" = "3" ]
for i in 1 2 3; do
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["parseError"] is None, d["parseError"]; assert d["result"]["verdict"] in ("approve","needs-attention"), d["result"]' "P3-control-$i.json"
  grep -qF 'Naming, style, and speculative hardening are low. ' "P3-control-$i.prompt"
  ! grep -qF -- "$(cat ../../../2026-10-03-review-calibration-and-sentinel-scope/cap-sentence.txt)" "P3-control-$i.prompt"
  grep -qE 'Review package: /.+/review\.diff\.' "P3-control-$i.prompt"
done
grep -qE '^[0-9a-f]{40}$' P3-control.base
grep -qE '^[0-9a-f]{40}$' P3-control.head
[ -s P3-control.diff ]
echo artifacts-ok
```

Expected: `artifacts-ok`.

- [ ] **Step 3: Write the entry**

Create `docs/experiments/2026-10-05-p3-control.md`:

```markdown
# 2026-10-05: P3, the pathological-input control without the invariant sentence

**Hypothesis.** The 2026-10-03 control on P and P2 found no over-rating (0 of 6 reviews raised the pathological case at blocking severity), so no cap sentence shipped. Both fixtures' requirements stated the twelve-lowercase-hex-digit invariant the pathological input violates; whether that sentence kept the reviews from raising the case was untested. P3 is P with that sentence dropped and nothing else (`fixtures/codex-focus-arm/P3`; the declared hunk is asserted by `scripts/codex-focus-arm.test.sh`). If over-rating appears on P3, the sentence was doing the work; if not, the earlier stop stands on firmer ground. Over-rating is read as the 2026-10-03 note read it: any finding at blocking severity (critical or high) on the pathological case. Three reviews cannot distinguish a rate below one in three from zero.

**Config.** Control arm only (the 5bef46c `recipe-code.md` line 53 focus, no cap sentence), three reviews, real Codex through `scripts/codex-focus-arm.sh` with its own broker; companion 1.0.6, codex binary and version, model and reasoning effort as `runtime-start.txt` records (identical to `runtime-end.txt`); hyperpowers at <hp commit>, evals at <evals commit>. Each review's prompt, the base and head commits and the diff are beside its capture (`.prompt`, `.base`, `.head`, `.diff`), as the 2026-10-03 note asked for.

**Run pointers.** `evidence/2026-10-05-release-hygiene/task-24-runs/control-P3/` (`arm.log`, `runtime-start.txt`, `runtime-end.txt`, `P3-control-{1,2,3}.json`, `.prompt`, `P3-control.base`, `.head`, `.diff`).

**Verdict.** <for each of the three captures: the normalize result from arm.log and the highest-severity finding whose title or body names the pathological input, with its severity; then one sentence: "over-rating reproduced in N of 3" or "no over-rating in 3 of 3". The cap decision is separate and not taken here.>

**Limits.** Three reviews; one fixture; the control focus only; a blocking finding on the pathological case is read from the normalize result and the capture's findings list, not by hand re-scoring. No skill text changes with this entry.
```

The three angle-bracket fields are the measurement's outputs: fill them from `runtime-start.txt`, the two repositories' `git rev-parse HEAD` at the time of the run, and the captures; the Verdict names the capture files it reads.

- [ ] **Step 4: Write the evidence README**

Create `evidence/2026-10-05-release-hygiene/README.md`:

```markdown
# 2026-10-05 release hygiene

Run artifacts the plan `docs/hyperpowers/plans/2026-10-05-release-hygiene.md` (hyperpowers) and the entry `docs/experiments/2026-10-05-p3-control.md` cite.

- `task-24-runs/control-P3/`: the control arm over fixture P3, three real Codex reviews through `scripts/codex-focus-arm.sh`, copied unchanged from the scratch directory the arm ran in: captures, prompts, base, head, diff, runtime records and the arm log.
```

The arm writes no `home/` or `.git/`, so the strip and rename steps of `evidence/README.md` do not apply; stage with a plain `git add`.

- [ ] **Step 5: Commit**

```bash
git add evidence/2026-10-05-release-hygiene docs/experiments/2026-10-05-p3-control.md
git commit -m "evidence: the P3 control, three real Codex reviews without the invariant sentence"
```

---

### Task 25: The clean-harness Note for the b1 controls

**Risk tier:** standard — an append to a pre-registered evidence record; the text is given in full and cites a commit that exists once Task 22 has landed.

**Files:**
- Modify: `evals/evidence/2026-10-03-clean-harness-rebaseline/README.md` (append a Note)

**Interfaces:**
- Consumes: Task 22's commit id (read from `git log` on the branch).

**Mirror:** `evals/evidence/2026-10-03-clean-harness-rebaseline/README.md` (the `**Note (2026-10-05).**` paragraph the item-5 work appended at its end, same form).

- [ ] **Step 1: Append the Note**

Append, with `<commit>` replaced by Task 22's short commit id:

```markdown

**Note (2026-10-05).** The `brainstorming-router-escalates-b1-userid-param` sessions in this campaign ran with a Codex companion stub that answered `task-reviewer`, `review` and `adversarial-review` but not `task`, the subcommand the approach gate and the spec gate call, so any session that reached those gates ran the degraded path (`{}` results, never an approving verdict). Evals commit `<commit>` ports the `task` implementation from `brainstorming-asks-tooling-question` into that stub and six siblings; sessions after it see a working gate. The b1 cells above are not re-scored.
```

- [ ] **Step 2: Check**

Run: `git log --oneline -1 --grep='seven brainstorming Codex stubs' | cut -c1-9` and confirm the id appears in the appended paragraph: `tail -c 600 evidence/2026-10-03-clean-harness-rebaseline/README.md | grep -c "$(git log --format=%h -1 --grep='seven brainstorming Codex stubs')"`
Expected: `1`.

- [ ] **Step 3: Commit**

```bash
git add evidence/2026-10-03-clean-harness-rebaseline/README.md
git commit -m "docs(evidence): note that the b1 controls ran a degraded gate path"
```

---

## After Task 25 (controller)

1. Item 16's memory note: update `sdd-workspace-keyed-per-repo.md` to say the key follows the plan's repository from hyperpowers Task 9's commit; index line in `MEMORY.md`.
2. Finishing, evals first (its tests must run on merged main and hyperpowers' CHANGELOG cites nothing from it): `hyperpowers:finishing-a-development-branch` on the evals branch with its merged-result verification being, on the merged main checkout, `bun run check` with no failures, then the three shell tests each as its own command: `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`, `bash scripts/strip-runs.test.sh`, `bash scripts/lens-cohort.test.sh /Users/johnss51/Development/agents/hyperpowers`. The worktree removal uses `rm -rf` plus `git worktree prune` after the human partner's approval, as on 2026-10-05.
3. Finishing, hyperpowers: the offline set (docs/testing.md) on the branch, each suite as its own command, with the brainstorm-server chain run three times under load; then the finishing skill.
4. The release sequence from the spec's Branch line, with the CHANGELOG heading's date set to the day it runs.
