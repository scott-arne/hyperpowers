# Release hygiene before 6.16.0: seventeen follow-ups

**Date:** 2026-10-05
**Status:** design approved in chat on 2026-10-05 (items 1 to 17 and the
four decisions below); spec self-reviewed; Codex spec gate round 1 found
fourteen blocking findings across two lenses, round 2 three, round 3 four
and round 4 (the document-gate backstop) four more; all are resolved in
this text (ledger in the gate directory), and the four round-4 fixes are
not re-reviewed by Codex. Awaiting the human partner's review.
**Branch:** hyperpowers `release-hygiene` off `main` at `c80ee21` (the
communication-skill merge); evals `release-hygiene` off evals `main` at
`52eea4f76`. The 6.16.0 release (CHANGELOG date, `vrzn -y bump minor`, tag,
`plugin-install` worktree, `claude plugin update`) runs after both land.
**Provenance:** the follow-ups surfaced while closing item 5 (nine
follow-ups, merged 2026-10-05) and item 4 (review calibration and sentinel
scope, merged 2026-10-04). The human partner asked for them before the
release: "let's have a clean release." The memory note
`item5-followups-2026-10-05` lists them; this spec is their design.

## Problem

Three kinds of defect stand between `main` and a release that can be trusted
on this host.

1. **Plugin code that misbehaves under load or under a sandbox.** The
   brainstorming companion server announces `server-started` before it
   writes `state/server-info`; a reader that acts on the announcement races
   the write, and the harness's own `server.test.js` lost that race three
   times today under load. The same test's `test()` wrapper lets a
   synchronous throw abort the whole run. `stop-server.sh`'s stop loop still
   reads `kill -0` failure as "dead", so a server the shell may not signal
   would be reported stopped while alive. `start-server.sh` kills whatever
   pid `server.pid` names, with no check that it is a brainstorm server.
   `verdict-normalize`, the gate's only approval authority, ignores the
   companion job's status, so a failed job whose stored text carries an
   approve verdict normalizes to approved. Seventy test sites in twelve
   files pipe a shell variable through `printf` or `echo` into `grep -q`;
   under `pipefail`, when the variable is longer than the pipe buffer (512
   bytes on this host under fd pressure), `grep -q`'s early exit kills the
   producer and a successful match reads as a FAIL.
2. **An evals checkout whose `bun run check` is red for reasons that are
   not defects in the code under test.** One test resolves the hyperpowers
   root as `evals/..`, which a nested worktree breaks; one assumes `claude`
   is off `PATH`; five time out at bun's 5 s default because each spawns
   `node` about seventeen times; two test files and one script leak temp
   directories; the focus-arm runner's build assertion has no test; three
   doc defects from the item-4 Codex rounds are still open; the leak-scan
   tool lives in `~/.cache` and rots.
3. **Gaps that make results harder to re-check.** A run records neither the
   evals commit nor the Gauntlet identity that produced it. A focus-arm
   capture records the base it reviewed but not the head, the diff or the
   prompt. Seven brainstorming scenarios seed a Codex stub without the
   `task` subcommand both document gates call, so those sessions run a
   degraded gate path. A cross-repo SDD plan gets two workspaces because
   `sdd-dir` keys on the shell's cwd. Fixture P's requirements state the
   invariant the pathological input violates, so the control that found no
   over-rating may have been helped by that sentence.

## Decisions

Taken by the human partner on 2026-10-05, in chat:

- **Scope:** all three groups before the release (not A alone, not A plus
  B).
- **Leak-scan tool home (item 12):** `~/.claude/scripts/realval-scan.py`,
  named in the private `~/.claude/CLAUDE.md`; not tracked in the public
  repository.
- **Task-less stubs (item 15):** fix all seven in place, including `b1`,
  which is a control of record, with a dated note on the clean-harness
  re-baseline README saying the controls' sessions ran the degraded gate
  path.
- **Fixture P3 (item 17):** build it and run the control arm with real
  Codex, three reviews, in this batch; whether a cap sentence then ships is
  a separate decision.

## Design

Each item names its change, the behaviour that proves it, and what it must
not change. An item is a design unit; the plan turns each into one or more
tasks, and every commit carries one problem. File paths are
repository-relative; "hp" is hyperpowers.

### Group A: plugin code (hp)

**1a. `server.cjs` writes `server-info` before it announces.**
In `onListen` (`skills/brainstorming/scripts/server.cjs`, the block that
builds `info`), the `fs.writeFileSync(path.join(STATE_DIR, 'server-info'),
…)` moves above `console.log(info)`, so by the time a reader sees
`server-started` the file exists. Nothing else in the block moves; the
owner-only mode stays. Proof: `server.test.js` "writes server-info to
state/" passes 3 of 3 consecutive `npm test` chains while `bun test` runs
in another shell (the load that tripped it today); a new case in
`lifecycle.test.js` starts the server, waits for the `server-started` line,
and asserts `server-info` exists on the very next statement, with no
polling.

**1b. `server.test.js` records a synchronous throw as one failure.**
The `test(name, fn)` helper moves out of `runTests` into a shared module,
`tests/brainstorm-server/test-runner.js`, exporting
`makeTestRunner({ log })` that returns `{ test, counts }` with `counts =
{ passed, failed, skipped }`. `test(name, fn)` runs `fn` inside the chain
(`Promise.resolve().then(fn)`), so a synchronous throw lands in the
`.catch`, prints `FAIL: <name>` and the message, increments `failed`, and
resolves; `skip` handling is unchanged. `server.test.js` is the only
production caller in this batch; the other test files keep their own
helpers. Proof: `tests/brainstorm-server/test-runner.test.js` runs a body
that throws synchronously, then a passing body, and asserts
`counts.failed === 1`, `counts.passed === 1`, and the log order; `server.test.js`
still reports 33 of 33 when green.

**2. `stop-server.sh`'s stop loop treats EPERM as alive.**
The three raw `kill -0 "$pid"` reads in the stop loop use the existing
`process_exists`, and `kill`'s stderr is classified by the same rule it
uses: "No such process" means gone, "not permitted" means alive and
unsignalable, anything else means alive. The loop's outcomes become a
state table:

| after the signal attempts | report | exit | files |
|---|---|---|---|
| process gone | `stopped` (as today) | 0 | removed |
| alive, every `kill` returned "not permitted" | `unverified` (the identity path's JSON shape) | 1 | kept |
| alive, `kill` was accepted but the process survived `kill -9` | today's failure path, unchanged | as today | as today |

Proof: a ninth case in `tests/brainstorm-server/stop-server.test.sh`,
under the existing root guard (skip when `kill -0 1` succeeds or `/proc`
is readable), with a session whose pid file names PID 1 and whose command
line the fake `ps` reports as a brainstorm server with the recorded id, so
the identity check passes and the stop loop is what runs: expect
`unverified`, exit 1, both files kept; the existing stale-pid and
stopped cases unchanged.

**3. `start-server.sh` verifies the old pid before killing it.**
The "Kill any existing server" block moves above the instance-id write, so
it reads the previous `server-instance-id`. It kills `old_pid` only when
all three hold: the previous id file is readable and its content matches
`^[A-Za-z0-9_-]{32,64}$` (the format the script itself writes);
`ps -o command= -p "$old_pid"` returns a command line; and that command
line names `server.cjs` and carries exactly
`--brainstorm-server-id=<that id>`, by the same match
`stop-server.sh`'s `command_has_server_id` applies, duplicated as a small
function (the two scripts are installed as independent files). A missing,
unreadable or malformed previous id, or a command line that names
`server.cjs` with another id or no id, is `not-ours`; no command line from
`ps` is `unverified`; in both the process is left alone and the pid file is
removed, matching `stop-server.sh`, which never signals without a valid
matching id. Before launching the server, the shell prints one JSON line of
its own on stdout, in both foreground and background modes:
`{"type":"previous-server","status":"stopped"|"not-ours"|"unverified","pid":<n>}`.
No pid file, no line. `server.cjs` and its `server-started` JSON are
unchanged. Proof: seven cases in
`tests/brainstorm-server/start-server.test.sh`, each asserting the JSON
line's `status`, whether the recorded process survived (a `sleep 600`
stand-in started by the test, checked with `kill -0` afterwards), and
that the pid file is gone: a pid file naming a fake server with the
recorded id (killed; `stopped`); a pid file naming a `sleep` process whose
fake `ps` reports `sleep` (survives; `not-ours`); a fake server whose
command line carries a different id (survives; `not-ours`); the previous
id file absent (survives; `not-ours`); the previous id file holding
`not a valid id!` (malformed; survives; `not-ours`); the previous id file
present with mode `000` (unreadable; survives; `not-ours`; skipped when
the test runs as root); `ps` failing (survives; `unverified`); each in
background mode, and the `stopped` case also in `--foreground` mode
through the existing capture helper.

**4. `verdict-normalize` fails closed on a job that did not complete.**
In the JSON path, before the roots loop: when the parsed payload has a
`job` property at all, the result is `incomplete` with reason
`job status <value>` unless `job` is an object whose `status` is the exact
string `completed`; `<value>` is the status string, or `missing` when
`job.status` is absent, null or not a string, or `malformed` when `job` is
not an object. A payload without a `job` property (a bare verdict object,
a `result` root) behaves exactly as today. Proof: cases in
`tests/codex-review-gate/test-verdict-normalize.sh` wrapping an approve
payload in `{"job":{"id":"x","jobClass":"review","status":S},"storedJob":…}`
for S in `failed`, `cancelled`, `running`, `queued` (`incomplete`, reason
`job status S`), `null`, absent, `7` (`incomplete`, `job status missing`),
`"job": "x"` (`incomplete`, `job status malformed`), and `completed`
(`approved`, unchanged); the existing cases unchanged. Risk tier high:
approval authority.

**5. Here-string greps.**
Rule: in a test script under `tests/`, no `grep` whose option cluster
contains `q` (`-q`, `-Fq`, `-qi`, `-Eq`, `-Fqx`, any spelling) may consume
a pipe whose producer is `printf` or `echo` of a shell variable; each such
site becomes `grep <same options and pattern> <<< "$var"`, which has no
writer process to receive SIGPIPE (`<<<` adds a trailing newline, which no
pattern here depends on; a pattern anchored with `-x` or `$` still matches
because the newline terminates the line). The rule covers every script in
`tests/` whether or not it sets `pipefail` itself, since helpers are sourced
by scripts that do. The inventory, by the command below at `c80ee21`: 123
sites in 29 files:
`tests/codex-review-gate/test-codex-broker-sweep.sh` 36,
`test-gate-telemetry.sh` 14, `test-broker-state-dir.sh` 9,
`test-review-dossier.sh` 6, `test-sweep-toolchain.sh` 5,
`test-gate-topology.sh` 4, `test-verdict-normalize.sh` 2,
`test-ungated-ledger.sh` 2, `test-gate-contract.sh` 2, and one each in
`test-gate-round.sh`, `test-codex-preflight.sh`, `test-broker-health.sh`,
`test-base-ref-ok.sh`, `test-assemble-gate.sh` (all under
`tests/codex-review-gate/`); `tests/claude-code/test-delivery-resolution.sh`
9, `test-worktree-native-preference.sh` 5 (a live suite; edited, checked
with `bash -n`, not run), `test-helpers.sh` 2, `test-sdd-dir-path.sh` 1;
`tests/hooks/test-ungated-notice.sh` 4, `test-broker-janitor.sh` 2,
`test-session-start.sh` 1; `tests/brainstorm-server/start-server.test.sh`
2, `windows-lifecycle.test.sh` 2; `tests/packaging/test-skill-frontmatter-rejects.sh`
2, `test-package-skill.sh` 1; `tests/writing-skills/test-render-graphs.sh`
2; `tests/shell-lint/test-lint-shell.sh` 2; `tests/sdd/test-sdd-contract.sh`
2; `tests/systematic-debugging/test-find-polluter.sh` 1. Pipes whose
producer is a command (`unzip -l … | grep -q`, `grep -v … | cut | grep`)
are out of scope: their producers are not variables and their fix is a
different shape. Proof: the residual count is zero:
`grep -rnE '(printf|echo) [^|]*\$[^|]*\| *grep( +-[A-Za-z]+)* +-[A-Za-z]*q' tests | grep -v node_modules | wc -l`
prints `0`; every offline suite in the inventory passes; the live suite is
`bash -n` clean.

### Group B: evals hygiene

**6. `runner-guards` "reaches preflight" controls PATH.**
The test sets `PATH` to `<emptybin>:/usr/bin:/bin` and restores it, as the
neighbouring "claude not on PATH" test does, so the directive gate passes
and the binary preflight, not real provisioning, ends the run. Proof: the
test passes on a host with `claude` installed and still asserts
`final_reason` is not the directive message.

**7. `scenario-brainstorming-tooling-question.test.ts` finds the
hyperpowers root.**
`NORMALIZE` is resolved by `SUPERPOWERS_ROOT` when set, else by walking up
from `import.meta.dir` to the first directory containing
`skills/requesting-code-review/scripts/verdict-normalize`; when neither
resolves the test fails with a message naming both. Proof: the file passes
from the main checkout and from `evals/.worktrees/<any>/`.

**8. Fix-loop test timeouts.**
The five tests in `scenario-sdd-fix-loop-refutes-wrong-finding.test.ts`
that drive the stub through many spawns pass a 60 s timeout as the third
argument to `test()`, with a comment giving the spawn count. The file ran
5 of 5 at 60 s on this host. Proof: `bun test` of the file passes from the
main checkout with the default `bunfig`.

**9. Temp-dir leaks.**
`runner-context.test.ts` and `runner-guards.test.ts` collect every
`mkdtempSync` path they create (`run-`, `agents-`, `out-`, `scn-`,
`sproot-`, `emptybin-`, `bin-`, and any other prefix a `grep -n mkdtempSync`
of each file lists at implementation time) and remove them in `afterAll`.
`scripts/codex-focus-arm.sh` records each fixture's `work` directory and
removes them in `finish`, on success and on failure. Proof: for the two test
files, a count of matching entries under `$TMPDIR` before and after a run
is unchanged; the focus-arm test asserts the work directories are gone
after a passing arm and after the build-failure arm of item 10.

**10. Focus-arm build-failure test.**
`scripts/codex-focus-arm.test.sh` copies the script to
`$work/copy/scripts/` beside `$work/copy/fixtures/codex-focus-arm/H/` whose
head `lib.js` is the real one plus a line that fails `node --check`; the arm
exits non-zero, its stderr names the syntax error, the stub log has no
`review` line, the broker is shut down and cleared once, and
`runtime-end.txt` exists. Proof: the new case in the existing test.

**11. Docs.**
Evals `CLAUDE.md` actors table: Gauntlet "lives" as "the `gauntlet` on
`PATH` (on this host a shim to the fork checkout); quorum spawns it by
name", replacing `~/Code/prime/gauntlet`. `docs/scenario-authoring.md` §5:
the base-rate table gains a `Gauntlet` column between `harness` and `rate`
(rows 1 and 2 `not recorded`; row 3 `a35607e`, clean state not on record),
and the prose sentence that says a later row records the identity points
at the column. The same subsection's recording procedure for the Gauntlet
identity changes from "tracked files clean" with
`git status --short --untracked-files=no` to item 13's definition:
`git status --porcelain --untracked-files=all` prints nothing (untracked
files count, ignored files do not; the flag is explicit because the bare
command obeys a `status.showUntrackedFiles=no` setting), so a checkout the
table calls clean is one the verdict's provenance also calls clean; row
3's "not on record" stands. `docs/scenario-authoring.md` is the living
authoring guide and is edited in place, as item 4 edited it; the
pre-registered campaign records (evidence READMEs, plan files) are not
touched by this item. The recipe's
`scratch="$(mktemp -d)"` becomes
`scratch="$(mktemp -d "${TMPDIR:-/tmp}/suite-at-commit.XXXXXX")"`. The
original wording of the two item-4 Minors is not on record (that plan's
workspace is gone); these are the defects as the docs stand. Proof: every
row of the table has the same column count as the header; `bun run
quorum check` passes; the recipe block still parses with `bash -n` when
extracted.

**12. The leak-scan tool and the plan Correction.**
`realval-scan.py` is copied from `~/.cache/hyperpowers/item4-grounding/`
to `~/.claude/scripts/realval-scan.py` (host-private; the Write tool, since
the Bash sandbox cannot write there), and `~/.claude/CLAUDE.md` gains a
short "Leak scan" subsection: committed files must not carry the proxy host,
the `NO_PROXY` list or the GCP project id (the scanner's three needles, read
from the settings env block), nor private instruction text (a reading
rule); scan a diff with `python3 ~/.claude/scripts/realval-scan.py` on
stdin and expect `hits: 0`; never derive the needles from the shell's own
proxy variables, which inside the sandbox hold the sandbox proxy's values.
The item-4 plan gets an appended `**Correction (2026-10-05).**` saying its
leak grep read those variables and that the counts-only scanner covered the
gap. This item is done by the controller, not a subagent: it edits the
human partner's private configuration. Proof: `cmp` of the copy against
the cache original succeeds; the copy prints `needles set: True True True`
and `hits: 0` on an empty input; fed one line containing each needle in
turn (taken from the settings env block at run time, never written to a
repository file), it prints `hits: 1` for each; the CLAUDE.md subsection
is present; the Correction is the last paragraph of the plan file.

### Group C: features and design

**13. Run provenance.**
A new `src/runner/provenance.ts` exports
`captureProvenance(deps: ProvenanceDeps): Provenance` where
`ProvenanceDeps = { runner: CommandRunner; evalsRoot: string; pathEntries: string[]; readFile: (p: string) => string | null; isExecutable: (p: string) => boolean }`,
so every lookup is injectable, and
`Provenance = { evals_commit: string | null, evals_clean: boolean | null, gauntlet: { path: string | null, checkout: string | null, commit: string | null, clean: boolean | null } }`.
`evals_commit` is `git rev-parse HEAD` in `evalsRoot`; `evals_clean` is
`git status --porcelain --untracked-files=all` in `evalsRoot` printing
nothing (untracked files count as dirty; ignored files do not; the flag is
explicit so a `status.showUntrackedFiles=no` setting cannot hide them);
`gauntlet.path` is the first
`pathEntries` entry whose `gauntlet` is executable; `gauntlet.checkout` is
resolved from that file: when its first line starts with `#!`, the first
whitespace-delimited token that is an absolute path to an existing file or
directory (the host shim's form is `exec bun run <checkout>/src/index.ts
"$@"`; a `cd <abs>` form is also covered) names the checkout: when the
token is a directory, `git -C <token> rev-parse --show-toplevel`; when it
is a file, `git -C <dirname(token)> rev-parse --show-toplevel`; otherwise
the checkout is `git -C <dirname(path)> rev-parse --show-toplevel`;
`commit` and `clean` are then the same two git commands in that checkout.
Any failing step yields `null` for its field and never throws. The runner
calls it once after the run dir is allocated, before setup, writes
`<runDir>/provenance.json`, and carries the object into every verdict it
writes for that run: the verdict schema gains an optional `provenance`
field, the normal writer in `src/runner/index.ts` and the stopped-verdict
writer in `src/runner/stopped.ts` both set it from the captured object,
and a run interrupted before the capture ran writes a verdict without the
field. `quorum show` renders one line from this table, with `<c>` the
first seven characters of a commit:

| commit | clean | renders as |
|---|---|---|
| `<c>` | true | `<c>` |
| `<c>` | false | `<c>+dirty` |
| `<c>` | null | `<c>?` |
| null | any | `unknown` |

as `provenance: evals <evals cell> gauntlet <gauntlet cell>`; a verdict
without the field prints no line. Proof: unit tests through a fake
`CommandRunner` and fake path/file deps: clean; tracked-dirty;
untracked-dirty; ignored-only (clean); git absent (nulls); the host shim
shape; plus one test against a real temporary repository with
`git config status.showUntrackedFiles no` set and an untracked file
present, which must report dirty, and the same repository with only an
ignored file, which must report clean; the host shim
shape with `exec bun run /abs/checkout/src/index.ts "$@"`; a
`cd /abs/checkout` shim whose checkout's parent directory is not a
repository (the directory token itself must be queried); a binary not on
PATH (gauntlet nulls); and the four render rows. The verdict schema test
accepts the field. End to end: the mock-gauntlet runner test
(`runner-e2e.test.ts`) reads `provenance.json` and the emitted
`verdict.json` from the same run and asserts the verdict's `provenance`
deep-equals the file and that `evals_commit` equals `git rev-parse HEAD`
of the checkout under test; the SIGINT test (`cli-run-sigint.test.ts`)
asserts the stopped verdict carries the same `provenance` as the run's
`provenance.json`; and a `quorum show` test renders a verdict with the
field and asserts the exact line
`provenance: evals <c> gauntlet <c>+dirty` for a fixture object.

**14. Focus-arm captures.**
Beside each `<fx>-<arm>-<i>.json`, the arm writes `<fx>-<arm>.base` (the
base commit it passes to `--base`), `<fx>-<arm>.head` (the head commit),
`<fx>-<arm>.diff` (a copy of `review.diff`) and `<fx>-<arm>-<i>.prompt`
(the composed focus). Proof: the focus-arm test asserts, per fixture and
arm, that `.base` equals the `--base` argument the stub recorded for each
of that fixture's three calls; that `.head` equals the `git rev-parse
HEAD` the test's stub companion records from its own working directory on
each call (the arm invokes the companion inside the reviewed repository,
so the stub is an independent observer of the reviewed head); that
`.diff` is byte-identical to the diff the test generates
independently by building the same two-commit repository from the same
fixture files (`git diff <base> <head>` output depends only on file
content, so the two match); and that each `.prompt` equals the stub's
recorded `--json` argument for that call.

**15. The seven task-less stubs.**
The `task` subcommand implementation from
`scenarios/brainstorming-asks-tooling-question/setup.sh` (prompt-file
parsing, the four-way classification, the approaches and document-review
bodies) is ported verbatim into the stubs of
`brainstorming-bounded-fires-approach-gate`,
`brainstorming-router-escalates-b1-userid-param` through `b5`, and
`brainstorming-router-no-downgrade`, keeping each stub's existing
subcommands. `task` is synchronous in the reference: it prints its body and
exits 0 without writing a job record, and that contract is kept. A
`**Note (2026-10-05).**` on
`evidence/2026-10-03-clean-harness-rebaseline/README.md` records that the
b1 control sessions ran the degraded gate path and that sessions after this
change do not. Proof: a test (`test/scenario-codex-stub-task.test.ts`)
extracts each of the seven stubs plus the reference the way
`scenario-brainstorming-tooling-question.test.ts` does, runs
`task --fresh --prompt-file <p>` for four prompts (one per classification:
approaches, plan-review, spec-review, document-review), and asserts each
stub's stdout equals the reference stub's for the same prompt and exit 0;
it also runs each stub's `status --json` and `adversarial-review` once and
asserts those outputs are unchanged from before the port (captured in the
test from the current stub text); `bun run quorum check` passes.

**16. `sdd-dir` keys a plan by its own repository.**
When `PLAN_FILE` is given, the key is the hash of
`git -C "$plan_dir" rev-parse --absolute-git-dir`, and `toplevel` for the
slug comes from the same repository; without a plan argument the cwd keys
as today. A plan whose directory is not inside a git repository fails with
the existing "plan file directory" style message. Proof: a new case in
`tests/claude-code/test-sdd-dir-path.sh` runs `sdd-dir <plan in repo A>`
from inside repo B and expects repo A's key; the existing cases unchanged.
The memory note `sdd-workspace-keyed-per-repo` is updated afterwards by
the controller (host surface, listed under Files).

**17. Fixture P3 and its control.**
`fixtures/codex-focus-arm/P3/` is a copy of P whose `REQUIREMENTS.md`
replaces the two lines

```
Workspace directories are created only by `createWorkspace`, which names them
with twelve lowercase hex digits. Existing behaviour must not change. Tests for
```

with the two lines

```
Workspace directories are created only by `createWorkspace`. Existing
behaviour must not change. Tests for
```

and is otherwise byte-identical; `commit_message` in `codex-focus-arm.sh`
maps `P3` to P's message. The control arm runs P3 three times with real
Codex through the runner (unsandboxed, background shell, as the script's
header prescribes), with the broker, config and runtime records the runner
already enforces; the captures, the item-14 `.head`/`.diff`/`.prompt`
files, the runtime records and the normalize lines go to
`evals/evidence/2026-10-05-release-hygiene/p3-control/`, and
`docs/experiments/2026-10-05-p3-control.md` records the result in the
Hypothesis / Config / Run pointers / Verdict / Limits format. Over-rating
is read as the item-4 note read it: any finding at blocking severity on the
pathological case. Whatever the result, no skill text changes in this
batch. Proof: `diff -r fixtures/codex-focus-arm/P fixtures/codex-focus-arm/P3`
prints exactly the hunk above and nothing else; `runtime-start.txt` equals
`runtime-end.txt` and names the real `codex` binary and version, not a
stub; exactly three captures `P3-control-{1,2,3}.json`, each with
`.job.status` `completed` and a normalize line; the three `.prompt` files
carry the control focus; the entry cites the directory.

## Evaluation

Items 1a to 5 change plugin code and are covered by the suites named in
each item; before merge the offline set (docs/testing.md) runs on the hp
branch, each suite as its own command, and the brainstorm-server chain
runs three times under load for item 1a. Items 6 to 10 and 13 to 15 are
proven by two commands on the merged evals main checkout, both required:
`bun run check` with no failures, and the shell tests `bun run check`
does not reach, each as its own command:
`bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
(the focus directory is that evidence directory, which holds
`focus-control.txt`, `focus-treatment.txt` and `cap-sentence.txt`),
`bash scripts/strip-runs.test.sh`, and
`bash scripts/lens-cohort.test.sh /Users/johnss51/Development/agents/hyperpowers`.
Item 11 is proven by its table and recipe checks; item 12 by its host
checks; item 16 by `tests/claude-code/test-sdd-dir-path.sh`; item 17 is a
measurement with its own entry, and its live run is the only Codex spend
in the batch beyond the spec and plan gates.

No item changes skill prose, so `writing-skills` evaluation does not apply;
`verdict-normalize` (item 4) is approval-authority code and takes the high
risk tier at planning.

## Files

hp: `skills/brainstorming/scripts/server.cjs`, `start-server.sh`,
`stop-server.sh`; `skills/requesting-code-review/scripts/verdict-normalize`;
`skills/subagent-driven-development/scripts/sdd-dir`;
`tests/brainstorm-server/server.test.js`, `lifecycle.test.js`,
`test-runner.js` (new), `test-runner.test.js` (new), `package.json`
(the new test in the chain), `start-server.test.sh`, `stop-server.test.sh`,
`windows-lifecycle.test.sh`;
`tests/codex-review-gate/test-verdict-normalize.sh`,
`test-codex-broker-sweep.sh`, `test-gate-telemetry.sh`,
`test-gate-topology.sh`; `tests/claude-code/test-delivery-resolution.sh`,
`test-worktree-native-preference.sh`, `test-sdd-dir-path.sh`,
`test-helpers.sh`; `tests/hooks/test-ungated-notice.sh`,
`test-broker-janitor.sh`; `tests/packaging/test-package-skill.sh`;
`docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md`
(appended Correction); `CHANGELOG.md` (6.16.0 notes for items 1a to 4).

evals: `CLAUDE.md`; `docs/scenario-authoring.md`; `src/runner/index.ts`,
`src/runner/provenance.ts` (new), `src/contracts/verdict.ts`,
`src/cli/render.ts`; `scripts/codex-focus-arm.sh`, `codex-focus-arm.test.sh`;
`test/runner-guards.test.ts`, `test/scenario-brainstorming-tooling-question.test.ts`,
`test/scenario-sdd-fix-loop-refutes-wrong-finding.test.ts`,
`test/runner-context.test.ts`, `test/runner-provenance.test.ts` (new),
`test/scenario-codex-stub-task.test.ts` (new);
seven `scenarios/brainstorming-*/setup.sh`;
`fixtures/codex-focus-arm/P3/` (new);
`evidence/2026-10-03-clean-harness-rebaseline/README.md` (Note);
`evidence/2026-10-05-release-hygiene/` (new);
`docs/experiments/2026-10-05-p3-control.md` (new).

host: `~/.claude/scripts/realval-scan.py` (new), `~/.claude/CLAUDE.md`
(new subsection), the memory note `sdd-workspace-keyed-per-repo`
(updated after item 16).

## Constraints

- One problem per change; the full diff in chat and the human partner's
  approval before every commit, as the item 4 and item 5 work was done.
- No attribution lines of any kind in commits or files.
- Nothing is pushed; the release sequence waits for both branches to land.
- Committed files must not carry the proxy host, the `NO_PROXY` list, the
  GCP project id or private instruction text; every staged diff is scanned
  with `realval-scan.py` (from its new home once item 12 lands).
- Live runs (item 17) are the human partner's to authorize; they are
  authorized by the item 17 decision above, three reviews, control arm only.
- The clean-harness controls of record are not re-scored. Pre-registered
  campaign records (evidence READMEs, plan files) are only appended to,
  with a dated Note or Correction: item 12 appends to a plan, item 15 to a
  campaign README. Living guidance (`docs/scenario-authoring.md`, evals
  `CLAUDE.md`, the private `~/.claude/CLAUDE.md`) is edited in place:
  items 11 and 12.

## Out of scope

- A cap sentence in `recipe-code.md` after P3 (its own decision).
- Converting the brainstorm tests' remaining fixed waits (`sleep 0.3`,
  `await sleep(300)`, the two `sleep 75`) to condition waits; none flaked in
  five full runs today.
- Pipes into `grep -q` whose producer is a command rather than a variable
  (item 5's rule names them out).
- A general `quorum rescore` command (closed in the sweep entry).
- The `.claude/.cc-writes` directory: Claude Code's own write-probe, not a
  repository stray.

## Known limits

- Item 2's EPERM path has no known production configuration today (a
  shell that can read the process table but may not signal); the test
  constructs it.
- Item 7 does not fix the general assumption elsewhere that `evals/..` is
  the hyperpowers root; it fixes the one test that failed.
- Item 13 resolves a shim by its first absolute path token; a shim that
  reaches the checkout some other way yields `null`, which renders as
  `unknown`.
- Item 15's test compares the ported stubs with the reference stub; it does
  not run a live gate, so it proves the subcommand exists and answers, not
  that a session's gate converges.
- Item 17's three reviews cannot distinguish a rate below one in three from
  zero; the entry says so.

**Correction (2026-10-05).** Planning found that item 3 hardens dead code. `start-server.sh` builds a new session directory on every start (`SESSION_ID="$$-$(date +%s)"`, lines 114-132 at `c80ee21`), so the "Kill any existing server" block reads `server.pid` from a directory the script has just created; no option reuses a session, and the block can fire only when one shell starts the server twice within one second. The human partner ruled: remove the block rather than guard it. Item 3 now reads: delete the pid-file read and the `kill` (lines 144-149) and leave a comment saying a fresh session directory never holds a previous server's pid file; `start-server.test.sh` gains one case in which a `server.pid` naming a live `sleep` process sits in an older session directory of the same project and the process survives a new start; no `previous-server` JSON line is added and `server.cjs` is unchanged. The Codex spec gate reviewed the superseded text; this correction is not re-reviewed by Codex. The seven-case proof and the `previous-server` line in the Files and Design sections above are superseded by this paragraph.

**Correction (2026-10-05, second).** The plan's Codex gate found item 13's `ProvenanceDeps` under-specified against the module the plan writes. The interface is `{ runner: CommandRunner; evalsRoot: string; pathEntries: readonly string[]; readFile(p: string): string | null; exists(p: string): boolean; isDirectory(p: string): boolean; isExecutable(p: string): boolean }`: `exists` and `isDirectory` are needed to tell a shim's directory token (`cd <checkout>`) from a file token (`<checkout>/src/index.ts`), which the round-4 fix to item 13 requires. The `quorum show` line is rendered without a label prefix, so the whole output line equals `provenance: evals <cell> gauntlet <cell>`. Item 13's other text stands. This correction is not re-reviewed by the spec gate; the plan gate reviews the plan that carries it.

**Correction (2026-10-05, third).** Item 17's proof says each capture has `.job.status` `completed`. A foreground `adversarial-review --json` capture carries no job object; its top-level keys are `codex`, `context`, `parseError`, `rawOutput`, `reasoningSummary`, `result`, `review`, `target` and `threadId` (read from `evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P2/P2-control-1.json`). The completion check is therefore: exactly three captures, each with `parseError` null and `result.verdict` one of `approve` or `needs-attention`, and one normalize line per capture in the arm log. The arm runs into a scratch directory and its artifacts are copied unchanged into `evidence/2026-10-05-release-hygiene/task-24-runs/control-P3/`, the layout `evidence/README.md` prescribes and the item-4 campaign used. Item 17's other text stands.

**Correction (2026-10-09).** Execution changed item 13 in three places, each by the human partner's ruling. First, the shim token: on the first line after the shebang that holds an existing absolute path token, the operand of a `cd` names the checkout, and failing that the last such token does. The first token names an interpreter's repository for `exec /opt/homebrew/bin/bun run <checkout>/src/index.ts`, and the last token names it for `cd <checkout> && exec /opt/homebrew/bin/bun run src/index.ts`. Second, `evals_clean` is `git status --porcelain --untracked-files=all -- src coding-agents package.json bun.lock scenarios` in `evalsRoot` printing nothing: the harness path set that `evals/docs/scenario-authoring.md` §5 compares. The whole-tree form took 9.04 s per run in the sandbox (the evals tree tracks 228,369 files, 227,632 of them under `evidence/`) against 0.18 s for the path set, and it timed out 18 runner and CLI tests. Third, a `gauntlet` whose checkout is the evals repository itself takes `evals_commit` and `evals_clean` as its `commit` and `clean` instead of walking that tree a second time; the test suite's mock gauntlet is that case. The Gauntlet `clean` of any other checkout is still the whole-checkout status. The same change rewrites the two `scenario-authoring.md` sentences that said quorum records neither commit. Item 13's other text stands. This correction is not re-reviewed by the spec gate; the per-task and final Codex gates review the code that carries it.
