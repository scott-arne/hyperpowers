# Post-release follow-ups to 6.16.0: ten items

**Date:** 2026-10-10
**Status:** design approved in chat on 2026-10-10 (the five design sections
and the decisions below); spec self-reviewed; Codex spec gate round 1 found
ten distinct blocking findings across two lenses, round 2 three more (all
proof gaps), and round 3 approved with no findings; every finding is
resolved in this text (ledger in the gate directory), one of them by the
human partner's decision of 2026-10-11. Awaiting the human partner's
review.
**Branch:** hyperpowers `post-release-follow-ups` off `main` at `37abdbc`
(tag `v6.16.0`); evals `post-release-follow-ups` off evals `main` at
`81da2b74b`. No release is part of this work; whether hyperpowers ships a
6.16.1 for items 6 and 7 is asked at Finish.
**Provenance:** the release-hygiene work (spec
`docs/hyperpowers/specs/2026-10-05-release-hygiene-design.md`, released as
6.16.0 on 2026-10-10) left a list of follow-ups the human partner accepted
and then asked to have addressed. They split it in two: this spec covers
the contained fixes plus the dashboard's verdict liveness and the container
image's identity; moving the Coding-Agent out of the run directory (agent
write isolation) gets its own brainstorm later.

## Problem

Four kinds of defect remain after 6.16.0.

1. **A run's record can name the wrong source.** A run inside the evals
   container records the Gauntlet as unknown, because the image copies the
   Gauntlet's `src/` without its `.git`, and nothing records which commit
   the image was built from. On the host, a Gauntlet shim written as
   `cd -P <checkout> && exec /opt/homebrew/bin/bun run src/index.ts`
   resolves to the interpreter's directory, and `/opt/homebrew` is a git
   checkout on this host, so provenance would record Homebrew's commit as
   the Gauntlet's. `cd --`, `pushd` and `cd X;exec` fail the same way.
2. **The dashboard trusts a verdict its writer has not finished.** The
   Coding-Agent can write the run directory. A `verdict.json` that appears
   while the run's process is alive is displayed and cached, and the cache
   never re-reads it, so the real verdict quorum writes at the end is never
   shown.
3. **Test and tooling defects that make results harder to trust.**
   `stop-server.sh` reads any `kill -0` failure other than "not permitted"
   as "gone", so an unrecognized error lets it discard the session files of
   a live server. `gate-telemetry` skips the pointer symlinks `sdd-dir`
   leaves for cross-repo plans, so the executing repository's report shows
   gate runs and none of the plan's tasks. Seven `grep -q` checks read from
   a pipe under `pipefail`: an early match kills the producer with SIGPIPE
   and the `if` reads the match as no match. 135 here-strings in 33 test
   files are written into a pipe before the fork on bash 5.1+, which
   deadlocks when macOS hands out 512-byte pipes. The executed
   release-hygiene plan carries check commands that cannot fail.
4. **Duplication and coverage gaps in evals.** Eight brainstorming scenarios
   each carry a 210-line copy of the same Codex stub in a heredoc, whose
   header still says the stub always approves. The offline focus-arm test
   never runs fixture P3, which the live P3 control used.

## Decisions

Taken by the human partner on 2026-10-10, in chat:

- **Decomposition:** two sub-projects. This one: the eight contained
  fixes, the dashboard liveness fix and the image identity. Later, in its
  own brainstorm: moving the Coding-Agent out of the run directory.
- **Here-strings:** replace every one under `tests/` with process
  substitution (`< <(printf '%s\n' "$var")`) and extend the existing
  no-heredoc fence to ban here-strings in `tests/`.
- **Image identity:** the image records its build source state, baked in
  as build arguments at `scripts/evals-container build`; quorum reads it
  into provenance. A dirty build is recorded, not refused. The approved
  design section extends the record to the Gauntlet's build state (item 1).
- **Dashboard:** a verdict is read and cached only after the run's process
  has exited.
- **Shared stub:** a checked-in `.mjs` fixture plus a copy helper, not an
  inline TypeScript string and not a merge into `seed_codex_plugin_cc`.
- **Shim parser:** cover the four forms; a `cd` or `pushd` whose operand
  does not resolve makes the Gauntlet identity unknown instead of guessing.
- **gate-telemetry:** every report row follows pointers; the fleet
  aggregate counts each workspace once.
- **Organization:** one spec and one plan across both repositories, evals
  tasks first.

Taken on 2026-10-11, after the Codex spec gate's first round found the
draft rule unapproved and too broad:

- **Shim operands built from the shim's location:** "Resolve exactly". A
  `cd` operand of the form `$(dirname "$0")` or
  `$(dirname "${BASH_SOURCE[0]}")` plus an optional literal suffix (empty,
  or beginning with `/`) is resolved against the shim's directory; any
  other variable form is unknown (item 2).

## Design

Each item names its change, the behaviour that proves it, and what it must
not change. An item is a design unit; the plan turns each into one or more
tasks, and every commit carries one problem. File paths are
repository-relative; "hp" is hyperpowers.

### Group A: evals

#### 1. The container image records its build source state

`scripts/evals-container build` reads four values before it calls
`docker build`:

- `QUORUM_IMAGE_EVALS_COMMIT`: `git -C <evals_root> rev-parse HEAD`.
- `QUORUM_IMAGE_CONTAINER_CLEAN`: `true` when `git -C <evals_root> status
  --porcelain --untracked-files=all -- container` prints nothing, `false`
  when it prints anything. `container/` is the only evals content the image
  holds (the Dockerfile and `container/bin/`); the rest of the checkout is
  bind-mounted at run time and already covered by `evals_commit` and
  `evals_clean`.
- `QUORUM_IMAGE_GAUNTLET_COMMIT`: `git -C <gauntlet_root> rev-parse HEAD`.
- `QUORUM_IMAGE_GAUNTLET_CLEAN`: the same status test over the whole
  Gauntlet checkout, the definition provenance already uses for the
  Gauntlet.

A value the launcher cannot read is passed as the empty string: a failing
`rev-parse` gives an empty commit, and a failing `status` gives an empty
clean flag, never `true`. Neither failure stops the build; the launcher
runs under `set -euo pipefail`, so each read is written to tolerate its own
failure. The launcher passes each as `--build-arg NAME=value`.
`container/Dockerfile` declares the four as `ARG` with an empty default and
re-exports each as `ENV NAME=$NAME`, placed after its last `RUN` line, so a
new commit invalidates only the final metadata layers and none of the
install layers.

`ProvenanceDeps` gains `env(name: string): string | undefined`;
`defaultProvenanceDeps` supplies it from the process environment.
`captureProvenance` adds `container_image`:

- `null` when `env("QUORUM_IMAGE_EVALS_COMMIT")` returns `undefined` (the
  variable is unset: a host run).
- Otherwise, including when it returns the empty string, `{ evals_commit,
  container_clean, gauntlet_commit, gauntlet_clean }`. Presence is tested
  against `undefined`, never by truthiness, because an image built without
  the launcher sets all four to the empty string. A commit is kept only
  when it matches
  `^[0-9a-f]{40}$` and a clean flag maps `true` and `false` to booleans;
  anything else becomes `null`. An image built by a bare `docker build`
  therefore records four nulls, which still says the run was in a
  container.

`ProvenanceSchema` in `src/contracts/verdict.ts` gains `container_image` as
a nullable object with those four fields, optional so verdicts written
before this change still parse. `renderProvenanceLine` appends
` image <evals cell> gauntlet <gauntlet cell>` when `container_image` is an
object, using the existing `cell()` rendering (`abc1234`, `abc1234+dirty`,
`abc1234?`, `unknown`); a host run's line is unchanged. The stopped verdict
carries the same provenance object it already receives from the runner, so
it needs no change of its own.

`docs/scenario-authoring.md` §5 changes in two places, both living
guidance edited in place:

- Where it describes the Gauntlet identity: inside the container
  `gauntlet.commit` and `gauntlet.clean` are `null` because the image
  copies the Gauntlet without `.git`, and the identity of record for a
  container run is `container_image.gauntlet_commit` and
  `container_image.gauntlet_clean`, the state of the checkout the image was
  built from.
- In "Which row is the base rate", the comparability bullet's sentence
  "For a container run, that covers the checkout's `container/`, not the
  image the run used, which may have been built from another state; the
  image is not recorded" is replaced. For a container run, the `container`
  path is compared at `container_image.evals_commit`, the commit the image
  was built from, not at the checkout's commit, and it is settled only when
  `container_image.container_clean` is `true`. A container run whose
  `container_image` fields are `null` (an image built without the launcher)
  leaves `container` open, so it needs a recorded argument like any other
  open path. Every other path in the set is still compared at
  `evals_commit`, because the checkout is bind-mounted at run time.

Proof: `test/runner-provenance.test.ts` covers `env()` returning
`undefined` for all four (field `null`, host line unchanged); all four set
to the empty string (an object with four `null` fields, rendered
` image unknown gauntlet unknown`); valid values (rendered with the
`cell()` forms, dirty and clean); and malformed values (each field
`null`).
`test/evals-container.test.ts`'s build cases assert the four
`--build-arg` values the fake `docker` receives, and that the build runs in
each case: with a fake `git` first on `PATH`, a clean checkout (the commit
and `true`), a dirty `container/` (`false`), a failing `rev-parse` (empty
commit) and a failing `status` (empty clean flag); with the real `git`, a
Gauntlet root that is not a repository (the harness's plain directory)
gives empty Gauntlet values. A test reads `container/Dockerfile` and
asserts the four `ARG` and `ENV` lines come after its last `RUN`. If Docker
is available at the end, a real `scripts/evals-container build` and a
container run's `quorum show` line are checked by hand and the outcome
reported either way.

Must not change: host-run provenance values and the host `show` line.

Amended during the task's review gate (the human partner's decisions of
2026-10-11). The build records the source state, so a source that changes
while the build runs would bake a commit the image does not hold: `build`
re-reads the commit and the clean flag after the build and dies naming what
changed, and `up` refuses an env file that mentions `QUORUM_IMAGE_*` rather
than let a caller forge the identity the image reports. Inside the
container, `container/bin/quorum` saves those four variables with
`declare -p` before sourcing the environment and restores them afterwards,
so nothing the environment sets can overwrite what the build baked in.
Accepted risk (the human partner, 2026-10-11): the post-build re-read
compares endpoints, so a source that moves A to B and back to A during the
build-context snapshot is not detected. Declined with evidence
(2026-10-11): setting `QUORUM_IMAGE_*` in the credentials file cannot change
the identity the run reports, because the restore runs after the sourcing. A
sourced file that instead names the shim's own save variable does reach it,
which is not a narrower hole than sourcing arbitrary shell already is. Known limit: after a failed
post-build re-read the image tag already points at the new image rather
than being untagged. `container/bin/quorum` belongs to this item's file set.

#### 2. The shim parser covers `cd -P`, `cd --`, `pushd` and `cd X;exec`

`shimTarget` in `src/runner/provenance.ts` splits each line after the
shebang (comment lines still skipped) into segments at `;`, `&&`, `||` and
`|`, then tokenizes each segment on whitespace with surrounding quotes
stripped, as it does today.

- A segment whose first token is `cd` takes as its operand the first later
  token that is not one of `cd`'s options `-L`, `-P`, `-e`, `-@`, after
  which `--` ends the options. A segment whose first token is `pushd` takes
  its first later token, skipping only `--`; `pushd -n` (which does not
  change directory) therefore has the operand `-n` and is unresolved.
  - An operand that starts with `/` and exists is the target.
  - An operand written as `$(dirname "$0")` or
    `$(dirname "${BASH_SOURCE[0]}")`, with or without double quotes around
    the whole operand, followed by an optional literal suffix, is resolved
    against the directory of the path quorum found on `PATH`, which is what
    `$0` holds when the shim runs. The suffix is either empty (the operand
    names that directory) or begins with `/` and contains no `$`,
    `` ` ``, quote or whitespace after that; it is appended to the
    directory and the result normalized, as the shell's concatenation
    would produce. A suffix that does not begin with `/` leaves the shim
    unresolved. A resolved path that exists is the target. So
    `cd "$(dirname "$0")/.."` targets the shim's parent directory and
    `cd "$(dirname "$0")/../other-repo"` targets `other-repo`, not the
    shim's own repository. Because the operand spans several whitespace
    tokens, this match runs on the segment's text after the command word
    and its options.
  - Any other operand, including `-`, a relative path, another variable
    form, or a nested command substitution, leaves the shim unresolved.
- A line with no `cd` or `pushd` segment keeps today's rule: the last
  existing absolute token on the first line that holds one.

`shimTarget`'s result distinguishes three cases: a target path; unresolved;
and today's `null`, for a file without a shebang or a script with no `cd`
or `pushd` segment and no existing absolute token, both probed through the
file's own directory as today. An unresolved shim records `gauntlet.path`
and leaves `checkout`, `commit` and `clean` `null`; it never falls back to
probing the shim's directory, which is how the Homebrew misattribution
would happen.

Proof: new cases in `test/runner-provenance.test.ts`:

- `cd -P <dir>`, `cd -L -P <dir>`, `cd -- <dir>`, `pushd <dir>` and
  `cd <dir>;exec`, each with `/opt/homebrew/bin/bun` later on the same line
  so a fallback to the last token would pick the wrong directory;
- resolved through the shim's directory: `cd "$(dirname "$0")/.."` (the
  shim's parent), `cd "$(dirname "$0")/../other-repo"` (`other-repo`),
  `cd "$(dirname "$0")"` (empty suffix: the shim's own directory),
  `cd "$(dirname "${BASH_SOURCE[0]}")/.."`, and the unquoted
  `cd $(dirname "$0")/..`, each followed by
  `&& exec /opt/homebrew/bin/bun run src/index.ts` so a fallback to the
  last token would pick the wrong directory;
- unresolved, each yielding `checkout`, `commit` and `clean` `null` with
  `path` set: `cd "$HOME/gauntlet"`, `cd gauntlet` (relative), `cd -`,
  `pushd -n <dir>`, `cd "$(dirname "$0")/$SUB"`,
  `cd "$(dirname "$0")suffix"` (a suffix without a leading `/`), and
  `cd "$(dirname "$(readlink -f "$0")")"`.

Every existing case passes unchanged, including the mock at
`test/runner-provenance.test.ts:349`
(`exec bun "$(dirname "$0")/mock-gauntlet.ts"`), which has no `cd` and no
absolute token and so keeps today's probe of its own directory.

Must not change: the result for any shim form the existing tests cover.

Amended during the task's review gates (the human partner's decisions of
2026-10-11 and 2026-10-12), because the whitespace split and the quote
stripping above still guessed. A word is read with its quotes only when
that is certain: a bare word, or one whole single- or double-quoted word
with no escape or expansion inside. Uncertain quoting is unresolved, never
stripped into a fragment. A script holding any cd-like word (`cd`, `pushd`
or `popd` in any quoting, or glued to `(`, `{`, a redirection or a
separator) resolves only through its single unconditional leading `cd`:
every line and segment before it is prelude (`set`, `export`, `unset`,
`readonly`, `umask`, `shopt`, or nothing but assignments), only prelude,
`exec` or `exit` follow it, it is not piped, and its operand is the
segment's last word and an existing directory. The last of `-L` and `-P`
decides how a `..` is read: logical normalizes it, physical leaves the path
for the operating system to resolve. Anything else is unresolved. A script
with no cd-like word keeps the older rule.

#### 3. The dashboard trusts a verdict only after its writer exits

`readDashboardVerdict` in `src/dashboard/scan.ts` is the one reader for
both callers (`scanResults` and the server's cost lookup on
`cell_finished`). Its order becomes:

1. A cached verdict is returned as is. Only verdicts read after their
   writer exited are ever cached, so a cached verdict is final.
2. If `phase.json` exists but does not parse as a phase with a pid, return
   `null` without reading `verdict.json` and without caching anything. A
   phase file that exists and cannot be read is never taken as "the run is
   over".
3. If `phase.json` holds a pid that `pidAlive` reports alive, return `null`
   the same way.
4. Otherwise (no `phase.json`, or a dead pid) read and parse
   `verdict.json`; a present, parseable verdict is cached and returned,
   anything else returns `null` uncached.

`writePhase` in `src/runner/phase.ts` writes today with `writeFileSync`,
which truncates the file and then writes it, so a scan can read an empty or
partial `phase.json` during a phase change. It changes to write a
temporary file in the run directory (`phase.json.tmp-<pid>`) and rename it
over `phase.json`, so a reader sees either the old phase or the new one.
It never writes `phase.json` directly. If the rename fails, it removes the
temporary file (best effort) and rethrows, leaving the previous
`phase.json` as it was; a failing write throws today too. `writePhase`
takes an optional third parameter carrying `writeFileSync`, `renameSync`
and `rmSync`, defaulting to `node:fs`, so a test can observe the operations
and inject a failure. Step 2 covers any unreadable phase file that
remains, whatever wrote it.

The authority rule becomes: a live pid, or a phase file that exists and
cannot be read, means the verdict is not trusted yet; otherwise a present
verdict means a RunRecord; otherwise the run is abandoned. `scanResults`
keeps its shape: a `null` from the reader falls through to the existing
phase check, which reports a live pid as running and an unreadable phase
file as abandoned until a later scan reads it. The comments that state the
old rule are rewritten to say a verdict is trusted only once its writer
has exited: the cache and authority-rule comments in `scan.ts`, and in
`src/dashboard/contracts.ts` the `DashboardVerdictSchema` comment ("once
verdict.json exists, phase.json is ignored for that dir") and the
`RunningRun` comment ("a dir with phase.json + a live pid and no verdict
yet"), which becomes a dir whose phase file names a live pid, whatever
else it holds.

Accepted costs: a finished run shows as running for up to one scan between
quorum writing its verdict and the child exiting; a pid reused by an
unrelated process before the first read keeps a finished run shown as
running until that process exits, the same exposure an abandoned run has
today.

Proof: new cases in `test/dashboard-scan.test.ts`: a verdict beside a
`phase.json` naming the test's own pid reads `null` and is not cached; the
same directory, after `phase.json` is rewritten to name a dead pid and
`verdict.json` is replaced, returns the replacement (the fake-then-real
sequence); a verdict beside an empty `phase.json`, and beside one holding
`{"phase":"agent"` (truncated), reads `null` and is not cached, and after
the phase file is rewritten whole with a dead pid the verdict reads; a
verdict with no `phase.json` still reads (run directories from before the
phase file). New cases in `test/runner-phase.test.ts`: with recording
operations injected, `writePhase` writes only `phase.json.tmp-<pid>` and
then renames it to `phase.json`, and never writes `phase.json` itself
(today's direct write fails this case); with the real filesystem and a
`renameSync` that throws, a previously written valid `phase.json` is
unchanged, no `phase.json.tmp-*` file remains, and the error propagates;
with the real filesystem and no injection, the result parses and no
temporary file remains.

Must not change: the display of finished and abandoned runs.

Not addressed here: a fake verdict followed by a run that crashes before
quorum writes its own. That needs the agent out of the run directory, the
second sub-project.

Amended during the task's review gate (the human partner's decision of
2026-10-12). Two changes. First, the reader checks the phase again after
it parses a verdict and caches the verdict only if the phase still allows
it, so a run that starts between the two reads cannot leave a forged
verdict cached. Second, `writePhase` records the writer's host
(`os.hostname()`, which inside a container is the container's), and the
live-pid rule applies only to a phase written on the dashboard's own host,
or to one with no `host` (written before this change). Container runs
write the results directory the host dashboard scans, and their pid
belongs to the container's namespace, so probing it on the host proves
nothing: a finished container run would show as running whenever its pid
matched a live host process. A phase from another host keeps the old rule:
its verdict is the record.

#### 4. One shared Codex approve-stub for the eight brainstorming scenarios

The stub moves to `fixtures/codex-stubs/approve-companion.mjs`. Its body is
the seven ported stubs' body verbatim (the reference
`brainstorming-asks-tooling-question` differs from them only in comments
and in logging `setup` calls). Its header comment is rewritten to say what
the stub does: `setup` reports ready; `task` returns a canned answer for
each classification (approaches, plan-review, spec-review,
document-review) and exits 2 when no prompt arrived; `task-reviewer`,
`review` and `adversarial-review` approve with no findings; `status` and
`result` answer for the job protocol; every call except `setup` is
appended to `calls.log` beside the stub.

The fixture is plain JavaScript that runs as is, but it is not added to
biome's `files.includes`: biome's formatter would rewrite the moved body's
quote style (`quoteStyle: "single"`), which this design moves verbatim. The
test checks its syntax with `node --check` and its behaviour by running it.

A new helper, `src/setup-helpers/codex-approve-stub.ts`, exports
`seedCodexApproveStub(ctx: HelperContext): void`, registered in
`src/setup-helpers/registry.ts` as `seed_codex_approve_stub`. It copies the
fixture to
`<home>/.claude/plugins/cache/openai-codex/codex/stub/scripts/codex-companion.mjs`
with mode 0755, writes `.claude-plugin/plugin.json` and
`installed_plugins.json` with the content the heredoc tail writes today,
locates `fixtures/` the way `src/setup-helpers/sdd-fixtures.ts` does, and
shares `codex-seed.ts`'s home derivation and registry writer instead of
duplicating them.

Each of the eight `scenarios/brainstorming-*/setup.sh` files replaces its
stub comment, heredoc and tail with one `setup-helpers run
seed_codex_approve_stub` line under a short comment. Scenario-specific
fixture code is untouched. The eight are
`brainstorming-asks-tooling-question`,
`brainstorming-bounded-fires-approach-gate`,
`brainstorming-router-escalates-b1-userid-param`, `-b2-config-module`,
`-b3-logging`, `-b4-reusable-validation`, `-b5-prefs-storage`, and
`brainstorming-router-no-downgrade`.

Proof: before any heredoc is removed, the current ported stub's behaviour
is recorded as golden values in `test/scenario-codex-stub-task.test.ts`.
For each case the record holds stdout, stderr, exit code, the `calls.log`
line it appends (or none), and any job file it writes under `.jobs/`:

- `setup --json`;
- `task --fresh --prompt-file <file>` for each of the four classifications
  (approaches, plan-review, spec-review, document-review), with and
  without `--json`;
- `task` with a missing prompt file, an empty one, and none (stdout empty,
  exit 2, the stderr line);
- `task-reviewer`, `review` and `adversarial-review` (each writes the job
  record `cxc-stub-1.json`);
- `status --json`; `status <id> --json` after a review and for an unknown
  id; `result <id> --json` after a review and for an unknown id;
- an unknown subcommand (`{}`, exit 0).

The rewritten test asserts the fixture reproduces every recorded value;
that the installed companion has mode 0755; that the helper writes
`plugin.json` and `installed_plugins.json` with the expected content; and
that each of the eight `setup.sh` files calls the helper and holds no
`codex-companion` heredoc. `bun run quorum check` passes.

Re-measurement argument (scenario-authoring §5, "What a session reaches"):
for the seven scenarios that include the controls of record, the stub's
stdout, exit codes and `calls.log` writes are unchanged; only its comment
text differs, which a session sees only by reading the stub's source. No
re-measure is owed. The reference scenario's `calls.log` stops listing
`setup` calls; its only `calls.log` check matches `task kind=` lines.

Must not change: any stub output or exit code, and any scenario's fixture
other than the stub install.

#### 5. The offline focus-arm test runs fixture P3

In `scripts/codex-focus-arm.test.sh` the treatment arm runs
`M H O P P2 P3 Pc`: the capture count goes from 18 to 21, and the
normalize-line loop and `check_captures` include P3. The control arm runs
`H P3`: 6 captures instead of 3, with its focus and capture checks applied
to both, because the live record ran P3 under the control arm.

Proof: the test passes with
`bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`.

Must not change: the runner script itself.

### Group B: hyperpowers

#### 6. `stop-server.sh` treats only "No such process" as gone

`process_exists` in `skills/brainstorming/scripts/stop-server.sh` first
rejects an argument that is not an integer from 1 to 2147483647 (return 1:
not a process), then runs `kill -0`. Success means alive; a failure whose
message contains "No such process" means gone; any other failure, EPERM or
a message nobody listed, means alive. Its comment is rewritten to say so.

The shape check keeps today's handling of bad pid files. Under bash 3.2,
`kill -0` on `abc`, an empty string, `2147483648` or `99999999999` fails
with a usage error, not ESRCH, so without the check `process_exists` would
report them alive. It also fixes a case that is wrong today: `kill -0 0`
succeeds (it signals the process group), so a pid file holding `0` reads as
alive.

The kill-refusal branches of the stop loop (the `kill` and `kill -9`
attempts that set `unsignalable`) stay keyed on "not permitted": they
classify a refused signal, not whether the process exists.

Proof: new cases in `tests/brainstorm-server/stop-server.test.sh`: with a
live process carrying this session's server id and an exported `kill`
function that fails every call with a message containing neither "No such
process" nor "not permitted", the session files are kept and the status is
neither `stopped` nor `stale_pid`; pid files holding `garbage`, an empty
line, `-5`, `0`, `2147483648` and `99999999999` each end `stale_pid` with
the files removed (without the shape check, `process_exists` would report
`0`, `2147483648` and `99999999999` alive: the first because `kill -0 0`
succeeds, the other two because bash rejects them with a usage error, not
ESRCH); a pid file holding `2147483647`, a
well-formed pid no process holds, also ends `stale_pid`, reached through
"No such process".

Must not change: the existing cases' results.

#### 7. `gate-telemetry` follows SDD pointers and counts each workspace once in the fleet total

In `skills/requesting-code-review/scripts/gate-telemetry`'s workspace walk,
a `plans/` entry is a workspace when it is a directory or a symbolic link
that resolves to a directory (`fs.statSync` follows the link); a dangling
pointer is skipped. Each workspace is identified by its real path
(`fs.realpathSync`).

- Every per-repository row, in a single-repository report and under
  `--all`, counts every workspace it reaches, through pointers included.
  Task identity within a row is (real path, task number).
- The fleet aggregate computes tasks and fix briefs over the union of all
  rows' (real path, task number) sets, so a workspace reached from two keys
  counts once. The other aggregate fields come from the codex-review and
  ungated directories, which pointers do not touch, and are unchanged.
- When a workspace is reached from more than one key, the text fleet
  section prints `- Shared workspaces: N (counted once in the aggregate)`
  and the JSON fleet object gains `sharedWorkspaces: N`. The line is
  omitted when N is 0; the JSON field is always present.

The windowing rule is unchanged: a task is in the cohort when its brief's
mtime is in the window, read through the link.

Proof: new cases in `tests/codex-review-gate/test-gate-telemetry.sh`: a key
whose `plans/` holds only a pointer reports the tasks and fix briefs of the
workspace it points to; a dangling pointer is ignored without error; under
`--all`, a workspace reached from its own key and through a pointer from a
second key appears in both rows, once in the fleet task count, and
`sharedWorkspaces` is 1.

Must not change: any report over a cache with no pointers.

#### 8. Piped `grep -q` checks read from files

A `grep -q` reading a pipe under `pipefail` can exit on its first match
while its producer is still writing; the producer dies of SIGPIPE, the
pipeline fails, and the `if` reads the match as no match. Every site where
the producer's output can exceed one line is changed so the producer writes
to a file in the test's temporary directory and `grep` reads the file. The
producer's own exit status is checked when it writes the file: a producer
that fails (an `unzip -l` on a missing archive, a failing filter) fails the
check with its own message, so a negative assertion cannot pass on an empty
file. Neither suite runs under `set -e`, so the check is explicit. The
sites:

- `tests/packaging/test-package-skill.sh` lines 49, 113, 143, 195 and 203
  (the `unzip -l` listings and the filtered listing at 49);
- `tests/codex-review-gate/test-gate-split-lossless.sh` lines 190 and 338.

The here-string at `tests/packaging/test-package-skill.sh:43` reads the
same listing and is converted in this item, not item 9.

The remaining piped `grep -q` sites under `tests/`
(`test-assemble-gate.sh:36` reads `head -1`, `test-codex-broker-sweep.sh:45`
reads one `ps` line) have single-line producers and are left as they are.
This supersedes the release-hygiene spec's out-of-scope line for pipes
whose producer is a command.

Proof: both suites pass; each changed check is shown to fail when its
condition holds, by a one-off run against a planted archive or table that
the plan names; and a producer failure (a missing archive) is shown to fail
its check instead of passing it.

Must not change: what each check asserts.

#### 9. Here-strings in `tests/` become process substitution, and the fence covers `tests/`

At `37abdbc`, 139 lines in 34 shell files under `tests/` contain `<<<`:

- 135 are here-string redirections, in 33 files. Item 8 converts the one
  at `tests/packaging/test-package-skill.sh:43`; this item converts the
  other 134, in 32 files. Each `cmd <<< "$var"` becomes
  `cmd < <(printf '%s\n' "$var")`. Both forms feed the value plus one
  trailing newline, and a `while read` loop fed this way still runs in the
  current shell, so variables it sets survive.
- 2 hold `<<<` as text, not as a redirection:
  `tests/claude-code/test-delivery-resolution.sh:37` (a `sed` pattern) and
  `tests/hooks/test-no-heredocs-in-hooks.sh:48` (the fence's probe). Both
  are rewritten, as described below.
- 2 are comments in `tests/hooks/test-no-heredocs-in-hooks.sh` (lines 6
  and 24), which the fence allows.

The `sed` pattern is half of a coupled pair.
`tests/claude-code/test-delivery-resolution.sh` extracts its test block
from `tests/claude-code/test-subagent-driven-development-integration.sh`
with a `sed` range that ends at the literal line
`done <<<"$worktree_list"` (line 283 there). The two change together.

**Note (2026-10-13).** The sentence that followed claimed the extraction's
existing empty-block failure proves the new end pattern matches. It does
not: a `sed` range whose end pattern never matches prints through end of
file, which is non-empty, so that check proves only the start anchor. On
the converted subject the stale pattern yields 201 lines against the
intended 12, and both pass an emptiness test. Task 12 added the real guard,
which requires the extracted block's last line to match the end anchor.

`tests/hooks/test-no-heredocs-in-hooks.sh` gains a second check: no line in
a tracked shell file under `tests/` (a `.sh` name or a `sh`/`bash`
shebang) contains `<<<` unless the line's first non-blank character is
`#`. Its probes are a file with a here-string, which must be flagged, and a
file that mentions `<<<` only in a comment, which must not be. The fence
file builds its probe text so the literal `<<<` never appears in its own
code (today line 48 contains one). Its header comment is updated to say
here-strings are banned in `tests/` as well as `hooks/`, and heredocs in
`hooks/` only.

Two facts bound what this proves. This host's `bash` is `/bin/bash` 3.2,
which always delivers here-strings through temporary files, so the
deadlock cannot be reproduced here; the evidence is the fence plus the
suites passing. Heredocs under `tests/` (80 sites in 25 files) have the
same bash 5.1+ exposure and are out of scope (see below).

Proof: the fence passes and its probes behave as stated. Every converted
file in the `docs/testing.md` offline set passes, run as its own command.
Five converted files run only in live or integration suites, which this
work does not run (they spawn the real `claude` CLI or need an installed
OpenCode and credentials): `tests/claude-code/test-helpers.sh` (sourced
only by live suites), `test-subagent-driven-development-integration.sh`,
`test-worktree-native-preference.sh`, `tests/opencode/test-priority.sh`
and `tests/opencode/test-tools.sh`. Each passes `bash -n`, and its
converted lines are read in the diff; the integration suite's resolution
block is still run, offline, by `test-delivery-resolution.sh`.

Must not change: what any converted check asserts.

#### 10. A Correction on the release-hygiene plan's checks that cannot fail

`docs/hyperpowers/plans/2026-10-05-release-hygiene.md` gets an appended
Correction paragraph, dated the day it is written, following the form at
`docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md:1789-1803`.
It names:

- the suite loops at lines 584, 641, 646, 682, 687, 723 and 728, whose last
  command is `echo` or whose failures are caught by `|| echo`, so each
  exits 0 whatever the suites did (the loops print each failure, so the
  failures were visible in the output but not in the exit status);
- Task 24 Step 2's `! grep` lines (2159 and 2166): bash's `set -e` ignores
  a command negated with `!`, so a match never stopped the step.

It gives the working forms: count failures and end with `exit` non-zero
when the count is above zero; `if grep -q ...; then exit 1; fi` for a
negated check. It records the result of re-running the two Task 24 checks
in working form against the committed evidence in
`evals/evidence/2026-10-05-release-hygiene/task-24-runs/control-P3/`, and
claims nothing else about those steps beyond what is on record.

Proof: the paragraph is present once at the end of the plan, and the two
re-run checks' output is quoted in it.

## Evaluation

Items 1 to 5 are proven on the merged evals `main` by, each as its own
command: `bun run check` with no failures; `bun run quorum check`; and
`bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`.
Item 1's real image build is a manual check at the end, run if Docker is
available, and reported either way.

Items 6 to 9 are proven by the suites named in each item and, before merge,
by the offline set in `docs/testing.md` on the hp branch, each suite as its
own command, with the brainstorm-server chain run three times. No live
suite runs; item 9 names the five converted files that only live or
integration suites reach, and how each is checked instead. Item 10 is
proven by its own check.

No item changes skill prose. Items 6 and 7 change scripts that ship inside
skills, and their suites cover them, so `writing-skills` evaluation does
not apply. No item needs a live eval run, so no evidence directory is
named; the only Codex spend is the spec, plan and code gates.

## Files

evals: `scripts/evals-container`; `container/Dockerfile`;
`src/runner/provenance.ts`; `src/runner/phase.ts`;
`src/contracts/verdict.ts`; `src/dashboard/scan.ts`,
`src/dashboard/contracts.ts` (comments);
`src/setup-helpers/codex-approve-stub.ts` (new),
`src/setup-helpers/codex-seed.ts` (shared helpers exported),
`src/setup-helpers/registry.ts`; `fixtures/codex-stubs/approve-companion.mjs`
(new); the eight `scenarios/brainstorming-*/setup.sh` files listed in
item 4; `scripts/codex-focus-arm.test.sh`; `docs/scenario-authoring.md`;
`test/runner-provenance.test.ts`, `test/evals-container.test.ts`,
`test/dashboard-scan.test.ts`, `test/runner-phase.test.ts`,
`test/scenario-codex-stub-task.test.ts`.

hp: `skills/brainstorming/scripts/stop-server.sh`;
`skills/requesting-code-review/scripts/gate-telemetry`;
`tests/brainstorm-server/stop-server.test.sh`;
`tests/codex-review-gate/test-gate-telemetry.sh`,
`test-gate-split-lossless.sh`; `tests/packaging/test-package-skill.sh`;
`tests/hooks/test-no-heredocs-in-hooks.sh`; the 33 test files holding
here-string redirections at `37abdbc`, plus
`tests/claude-code/test-delivery-resolution.sh`'s `sed` pattern;
`docs/hyperpowers/plans/2026-10-05-release-hygiene.md` (appended
Correction); this spec and its plan.

## Constraints

- One problem per change; the full diff in chat and the human partner's
  approval before every commit.
- This spec, its plan and item 10's Correction are committed in
  hyperpowers, under that repository's `CLAUDE.md` section "Planning and
  Spec Docs Are Tracked Here", each commit only after the human partner
  approves its diff.
- No attribution lines of any kind in commits or files.
- Nothing is pushed.
- Committed files must not carry the proxy host, the `NO_PROXY` list, the
  GCP project id or private instruction text; every staged diff is scanned
  with `~/.claude/scripts/realval-scan.py` and must report `hits: 0`.
- Pre-registered records are only appended to, with a dated Note or
  Correction: item 10 appends to an executed plan. Living guidance
  (`docs/scenario-authoring.md`) is edited in place: item 1.
- The controls of record are not re-scored.
- New and changed shell loops in this work exit non-zero on failure (the
  defect item 10 records is not repeated).

## Out of scope

- Moving the Coding-Agent out of the run directory, including a fake
  verdict followed by a crashed run and a forged `phase.json`: the second
  sub-project.
- Heredocs under `tests/` (80 sites in 25 files): the same bash 5.1+
  exposure as here-strings, but a different rewrite (they write files), so
  a follow-up of its own.
- Shims that reach the checkout through variables, `builtin cd`,
  `command cd`, or a relative `cd` operand.
- Guidance in `writing-plans` against check commands that cannot fail: a
  skill prose change, which needs its own evaluation.
- The stop loop's kill-refusal classification.
- Pipes into `grep -c` and `wc -l`, which read their whole input.
- A release.

## Known limits

- Item 1 records the state at build time. A container started from an
  image older than the bind-mounted checkout shows both commits on its
  `show` line, which is the intended signal, but the record cannot say what
  was dirty in a dirty build.
- Item 2 still probes the shim's own directory for a script with no `cd`
  and no absolute token, as today; a script in a shared bin directory
  written that way resolves to whatever repository holds that directory.
- Item 2 reads a subset of shell, so a shim outside it can still record a
  wrong checkout instead of unknown. The task's follow-on review
  (2026-10-12) named five such shapes: `set -P` or `set -o physical` before
  the `cd`; a backslash-newline that splits the word `cd`; a `PATH` change
  before a `$(dirname "$0")` operand, or the unquoted form when the shim's
  path holds whitespace; a quoted absolute path containing whitespace under
  the older rule, which then falls to an absolute interpreter; and an
  `exec env -C`, an absolute entrypoint in another checkout, or a branch
  after a failed `cd`. The rule that a `cd` operand is the Gauntlet
  checkout is itself a heuristic: nothing in the shim's text says which of
  two absolute paths is the checkout. The human partner accepted these on
  2026-10-12 rather than extend the parser further.
- Item 3 cannot tell a reused pid from the run's own process. A run whose
  phase file cannot be read is shown as abandoned until a scan reads it.
- Item 3 protects host runs only. A container run's verdict is trusted as
  soon as it appears, so a forged verdict there is caught only by the
  second sub-project; and a container run still in flight is probed
  against the host's pid table for the running display, as before. A host
  whose name changes during a run (macOS can rename itself on a network
  change) reads that run's phase as foreign, so its verdict is trusted as
  before this item. The `host` field is as forgeable as the pid: an agent
  that rewrites `phase.json` can name another host just as it could
  already name a dead pid; both wait for the second sub-project.
- Item 7's rows can add up to more than the fleet total when workspaces are
  shared; the shared-workspace line says so.
- Item 9 cannot demonstrate the deadlock on this host.
- Item 3's live-pid rule broke one display the item promised not to change:
  `quorum run --repeat N` runs every trial in one process, so each finished
  trial's verdict was refused until the whole invocation exited, not for the
  one scan the accepted costs describe. Fixed on the human partner's
  decision of 2026-10-13 rather than accepted: a trial writes the phase
  `done` after its verdict, and a `done` phase is trusted whatever its pid
  or host, because it is the runner's own statement that it has finished
  that run directory. A `done` phase with no readable verdict reads as
  abandoned. The SIGINT path writes no `done`: its caller exits immediately,
  so the pid is dead and the existing rule already trusts that verdict.
- Item 3 cannot tell which host wrote a `phase.json` from before the `host`
  field, so such a file is probed against this host's pid table. On this
  machine 33 of 2501 such files name a live pid, two of them in a displayed
  window, so a finished run of that age can read as running.
- Item 1's `container_image` is null for a container run started from an
  image built before this work, which is what a host run also records. The
  field appears only once `scripts/evals-container build` has been re-run.
