# Agent Write Isolation by Relocation — Design

**Date:** 2026-10-14
**Status:** spec gate converged on 2026-10-14 after two gates (eight rounds); one final-round fix applied and deferred to the plan gate for confirmation — see Verification item 7; awaiting the human partner's review
**Scope:** `hyperpowers-evals` (quorum) only; this repository's spec and plan.
**Supersedes:** `2026-10-13-agent-write-isolation-design.md`, now shelved.

## Why the threat model changed

The shelved spec assumed an adversarial Coding-Agent and spent seven review
rounds across four mechanisms discovering that, under that assumption, every
confused-deputy path on a shared uid matters. Two pieces of evidence gathered
on 2026-10-14 changed the premise.

**The corpus.** Across all 2,438 normalised trajectories in `evals/results/`,
no Coding-Agent action ever referenced `verdict.json`, `trajectory.json` or the
token-usage file; one run listed its parent directory and saw `phase.json`,
then did nothing with it. In roughly 1,624 of those runs the agent had been
told, through the leaked `AGENTS.md` (fixed in evals `fc42537c5`), that it was
the subject of a graded run and where the verdict lived. None looked. That is
a base rate of zero under the conditions this harness actually runs: ordinary
development tasks with no in-task objective the grade could advance.

**The field.** Established harnesses isolate the grade by *location*, not by
privilege: SWE-bench grades a diff elsewhere; Terminal-Bench keeps tests out of
the build context; METR's protected scoring is a root-owned directory; Harbor's
own catalogue of reward-hacking vectors states the requirement as "verdicts
originate outside agent processes". Documented tampering exists, but under
pressure the harness does not apply: impossible tasks, explicit flag objectives,
task families selected for hackability.

The model adopted is therefore **careless, not adversarial**: the agent will
stumble into what is adjacent and reachable, and it will not go hunting. Under
that model the right move is to remove adjacency and stop handing agent-authored
code things it has no business receiving — not to build a boundary on a shared
uid. The adversarial design stays on the shelf for the day a scenario gives the
agent a reason to want the grade.

## Problem, as it stands

1. The agent's cwd is `<runDir>/coding-agent-workdir`, so the record is one
   `..` away and appears in any parent listing.
2. Post-check inner commands run agent-authored code with quorum's entire
   environment. `runPhase` builds its env from `envSnapshot()`
   (`src/checks/index.ts:63-92`), and `verbCommandSucceeds` spawns `bash -c`
   with no `env` argument (`src/check/fs-verbs.ts:273-296`), so an inner
   command such as `sdd-svelte-todo`'s `npm test`
   (`scenarios/sdd-svelte-todo/checks.sh:14`) runs with the operator's `HOME`,
   every provider key, and the record sink. `npm` reads `~/.npmrc` without
   being asked. This is confirmed by reading the code, not inferred.

## Decisions taken with the human partner

1. **Threat model: careless.** Adjacency removal and hygiene, not a boundary.
2. **Move the workspace, not the record.** Declined: moving the record (~12
   readers, a new citation convention, and Gauntlet's scratch cwd dragged into
   the record tree without a fork change); no relocation at all.
3. **No digest seal.** Nothing writes the record after composition under this
   model, and same-uid storage gives detection no teeth.
4. **Verification:** offline suites plus three live smokes and one paired
   control arm at n=10 per arm.
5. **One repository.** The Gauntlet fork is untouched.

## Design

### Layout

| Tree | Holds |
|---|---|
| `<outRoot>/<run>/` (unchanged) | `verdict.json`, `phase.json`, `trajectory.json`, `coding-agent-token-usage.json`, `provenance.json`, `gauntlet-agent/`, the Antigravity visible-launch record |
| `<outRoot>/workspaces/<run>/` (new) | `coding-agent-workdir/`, `home/`, the package-scope `package.json`, any `coding-agent-workdir-*` sibling setup creates |

`<run>` is the same allocated name in both trees. A run that reaches workspace
setup has both. Only a run that stops *before* it — an agent excluded by the
scenario's `# coding-agents:` directive, or an early guard — has a record and
no workspace. A provisioning failure is not such a case: the workspace and
home are created before `agent.provision()` runs
(`src/runner/index.ts:1102-1143`), so a `ProvisionError` leaves both trees, as
today it leaves a record and a populated workdir.

The runner change is local to `runScenario`. Today
(`src/runner/index.ts:1103-1111`):

```ts
const workdir = join(runDir, 'coding-agent-workdir');
isolateWorkdirPackageScope(runDir);
const runHomeDir = join(runDir, 'home');
```

becomes

```ts
const workspaceDir = join(a.outRoot, 'workspaces', basename(runDir));
mkdirSync(workspaceDir, { recursive: true });
const workdir = join(workspaceDir, 'coding-agent-workdir');
isolateWorkdirPackageScope(workspaceDir);
const runHomeDir = join(workspaceDir, 'home');
```

The sentinel moves with the workspace because its job is to stop Node's and
npm's upward walk before it reaches the evals checkout
(`src/runner/index.ts:834-845`); from the new workdir that walk passes through
`workspaces/` and `results/` before `evals/package.json`, so the workspace root
is where it must stop.

Everything downstream already derives from `workdir` and `runHomeDir`: capture
(`session_log_dir: "${QUORUM_AGENT_HOME}/..."` in `coding-agents/*.yaml`), the
cwd filter's realpath equality, `codex-seed`'s `join(dirname(workdir), 'home')`
(`src/setup-helpers/codex-seed.ts:23`), the sibling-worktree helper
(`src/setup-helpers/worktree.ts:52`), the launch-cwd sentinel
(`src/runner/index.ts:988-1005`), and the Antigravity alias
(`src/agents/antigravity.ts:537-586`). `WORKDIR_SEPARATOR =
'/coding-agent-workdir/'` (`src/detect/implementation.ts:42`) still matches.

**One derivation does not survive relocation.** Kimi takes `dirname(workdir)` as
the run directory and its parent as the *artifact root*, and refuses to write
its mode-0600 runtime env file anywhere inside that root
(`src/agents/kimi.ts:191-198,829-850`). After relocation `dirname(workdir)` is
`<outRoot>/workspaces/<run>` and its parent is `<outRoot>/workspaces`, so a
`TMPDIR` under `<outRoot>` but outside `workspaces/` — the record tree itself —
would pass the guard. The fix is to stop deriving: `RunHome`
(`src/agents/index.ts:29-31`) gains `readonly runDir: string`, the record
directory, and Kimi's artifact root becomes `dirname(home.runDir)` =
`<outRoot>`, which contains both trees. The comment at `kimi.ts:191-196` that
documents the old derivation is rewritten.

Because the field is required and tests are inside `tsc --noEmit`
(`package.json:14-18`), it lands in **one task together with every
construction site**, so the tree typechecks at every commit. There are exactly
three: the runner's shorthand literal (`src/runner/index.ts:1119-1126`); the
shared typed fixture `makeTempHome` (`test/provision-helpers.ts:9-19`), which
gains `runDir` defaulting to a `record` directory under its temp root, distinct
from its workspace paths, **and creates that directory before returning** —
Kimi calls `realpathSync` on it (`src/agents/kimi.ts:838`), so a default that
merely named a path would break every Kimi provisioning test on the shared
fixture; the helper asserts the directory exists and is not a workspace path; and one inline literal passed straight to
`provision()` at `test/agent-codex-plugin-stage.test.ts:132`. Every other
`provision()` call in `test/` passes a `home` from `makeTempHome` and needs no
edit. The four `{ configDir, workdir, … }` literals in
`test/agent-codex-app-server.test.ts` are `ReadHookArgs`, an unrelated type,
and are not touched. `tsc --noEmit` is the completeness check; a
co-occurrence search is not. The plan greps `src/agents`,
`src/setup-helpers` and `src/capture` for `dirname(workdir)` and
`dirname(configDir)` to confirm the other three sites
(`index.ts:385,393`, `worktree.ts:52`, `codex-seed.ts:23`) are sibling-relative
and stay valid; they were checked for this spec and are.

**One scan expects agent content under the run directory.** Copilot's
post-capture branch walks `runDir` for its raw secret value
(`src/runner/index.ts:727`; `src/agents/copilot.ts:445-475`), because today
the workdir and home sit there. After relocation `runDir` holds only records,
so a token written into the workdir or home would go undetected. It is the
only content walk rooted at a run directory in `src/`. `CopilotCascadeArgs`
gains `workspaceDir`; the scan runs over both roots with the same env-file
exclusion; `relIfUnder` reports against whichever root contains the hit.
`test/runner-copilot-cascade.test.ts:24-46` currently plants the leak under
`runDir` and would not notice the loss; it gains two counterfactuals, the token
under `workspaces/<run>/coding-agent-workdir` and under
`workspaces/<run>/home`, each of which must return the capture
`indeterminate`.

**One detector tests containment against the run directory.** The Codex
misplaced-rollout detector classifies a rollout as misplaced when its
`session_meta` cwd is inside `runDir` but not the launch cwd
(`src/capture/index.ts:368-399`, the test at `:396`; called from
`codexMisplacedVerdict`, `src/runner/index.ts:659-676`). After relocation no
rollout is under `runDir`, so the detector would never fire again and a
Gauntlet-Agent that skipped `cd $QUORUM_AGENT_CWD` would no longer be caught.
The containment root must be **both trees, not a replacement of one by the
other**: a Gauntlet-Agent that skips the launcher starts Codex in the pane's
own cwd, `<runDir>/gauntlet-agent/results/<id>/scratch`
(`gauntlet/src/adapters/tui/adapter.ts:121-129`), which is in the *record*
tree; a wrong `cd` inside the workspace lands in the workspace tree. So
`DetectMisplacedCodexRolloutsArgs` gains `workspaceDir` alongside `runDir`,
and a rollout is misplaced when its cwd is inside either root and is not the
launch cwd. The test gains three counterfactuals: a rollout at the real scratch
shape under the record tree (misplaced), one in a wrong subdirectory of the
workspace (misplaced), and one at the launch cwd (not).

Kimi's artifact root, Copilot's scan and this detector are the three places a
derivation assumed agent content under the run directory. A sweep of every
`runDir` comparison in `src/` — `startsWith`, `relative`, `isInside`,
`includes`, resolved equality — finds exactly these three and no fourth; the
plan re-runs that sweep before the layout task closes.

The directory is named `workspaces`, not `.workspaces`: Antigravity rejects
`--add-dir` paths with a hidden component and would fall back to a symlink alias
(`src/agents/antigravity.ts:530-546`). The dashboard ignores the new directory
without a change, because `parseRunDirName('workspaces')` is `null` and the scan
skips unparseable names (`src/dashboard/scan.ts:219-222`). `.gitignore`'s
unanchored `results/` covers it.

`--project-dir <runDir>` to Gauntlet is unchanged, so `gauntlet-agent/` — the
grade, the event stream, the generated launcher and the pane's scratch cwd —
stays in the record tree. The launcher is executed from there read-only, as
today.

What the agent observes changes by one path component: its cwd is
`<outRoot>/workspaces/<run>/coding-agent-workdir` instead of
`<outRoot>/<run>/coding-agent-workdir`. From that cwd, `ls ..` shows
`coding-agent-workdir`, `home`, `package.json`, and whatever
`coding-agent-workdir-*` siblings the scenario's setup created — and no record
file.

This applies to host and container runs identically.

### Post-check environment

Two layers, one module (`src/checks/env-allowlist.ts`) that exports both
projections, with a unit test over the constructed objects.

**Outer layer** — the `bash` that `runPhase` spawns to source the prelude and
`checks.sh`. This is trusted scenario text plus the check tooling. It receives,
in place of `...envSnapshot()`:

- `PATH` (with today's `/usr/bin:/bin` fallback), `HOME`, `TMPDIR`, `LANG`, and
  every `LC_*` variable present — `HOME` stays the operator's, as today; no
  shipped check reads it as a value (the three `$HOME` occurrences in
  `scenarios/*/checks.sh` are comments) and `bun` wants it for its cache;
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` and their lowercase forms;
- `QUORUM_REPO_ROOT`, `QUORUM_RECORD_SINK`, `QUORUM_TRANSCRIPT_PATH`,
  `QUORUM_RUN_DIR`, `QUORUM_AGENT_CONFIG_DIR`, `QUORUM_CODING_AGENT`, and the
  new `QUORUM_AGENT_HOME`.

**Inner layer** — the `bash -c` that `verbCommandSucceeds` spawns. This may
execute agent-authored code. It receives the outer list with two changes:

- **Removed:** `QUORUM_RECORD_SINK`, `QUORUM_REPO_ROOT`,
  `QUORUM_TRANSCRIPT_PATH` and `QUORUM_RUN_DIR`. The last three all name the
  record tree or the harness checkout; the sink is the record's input. The verb
  still writes its record from the exit status it observes (`src/check/record.ts`
  is the sole emitter), so nothing the inner command does can forge one.
  `QUORUM_CODING_AGENT` is **kept**: it is the agent's name, a shipped test
  asserts it inside an inner command (`test/checks.test.ts:277-290`), and it
  discloses nothing.
- **Overlaid:** `HOME`, the four `XDG_*` variables and `TMPDIR` from
  `xdgHomeEnv(runHomeDir)` (`src/agents/home-env.ts:12-21`) — the same function
  the launcher uses, so an inner `npm test` runs under the throwaway home the
  agent itself ran under, not the operator's. This is the existing
  throwaway-home contract extended to post-checks, from its single source of
  truth.

The inner layer therefore still knows the agent's own home and config
directory, which hold the agent's own tokens. That is deliberate and is not an
exposure: the agent held those same tokens, as the same uid, for the whole agent
phase. A post-check learning their path adds no capability the subject did not
already have. The `QUORUM_AGENT_CONFIG_DIR` path is also referenced by 73
shipped inner commands across 23 scenarios, so removing it would mean rewriting
every bootstrap check as a typed verb — a reasonable long-term direction, out of
scope here.

**`QUORUM_RUN_DIR` becomes outer-only.** No shipped inner command needs it
after the migration below. A scenario that must hand a record-tree path to an
inner command expands it at the outer layer with double quotes —
`command-succeeds "test -f $QUORUM_RUN_DIR/gauntlet-agent/..."` — so the literal
path, not the variable, enters the inner shell. `quorum check` gains a lint
that fails a single-quoted `$QUORUM_RUN_DIR` inside `command-succeeds`, the same
hard failure it already applies to `$QUORUM_WORKDIR`
(`docs/scenario-authoring.md:510`).

**`QUORUM_AGENT_HOME`** is added to `RunPhaseArgs` as a **required**
`agentHome`, passed as `runHomeDir` by **both** production calls — the
pre-phase call at `src/runner/index.ts:1159` as well as the post-phase call at
`:1524` — and exported at both layers. It is required rather than optional so
that no caller can silently run a phase whose inner projection has no home to
overlay. The only test-side constructions are the fifteen inline `runPhase({…})`
calls in `test/checks.test.ts`, which gain the field; `tsc --noEmit` enforces
completeness.
The four scenarios that spell `$QUORUM_RUN_DIR/home` migrate to it:
`codex-approach-gate-fires-on-architecture` (`checks.sh:20`),
`codex-plan-gate-algorithm-locked-after-round1` (`:23`),
`codex-gate-stale-broker-attributed` (`:49`), `tdd-runs-the-project-suite`
(`:53`). The first two are the only `command-succeeds` calls in the scenario
set whose **outer** quote is a double quote around a `QUORUM_` path (eight
inner commands are outer-double-quoted; six are `awk` over relative paths);
they migrate to the single-quoted form the other two already use —
`command-succeeds 'grep -rq … "$QUORUM_AGENT_HOME/…"'` — so the variable
reaches the nested shell unexpanded. This is not only convention: the
dispatcher records the command it receives as the record's `args`
(`src/check/record.ts:30-37`), so an outer-expanded absolute path makes two
replay arms with different clone roots emit different records even when both
pass. The grounded inventory of what shipped checks reference externally is:
`QUORUM_AGENT_CONFIG_DIR` (73 occurrences), `QUORUM_RUN_DIR` (4) and `HOME`
(3, all comments); every other `$VAR` in those files is local.

**Git hygiene.** The harness's own read-only git calls — `gitOut`, `gitOk`
(`src/check/fs-verbs.ts:487-492`) and the `status --porcelain` call (`:380`) —
gain `-c core.fsmonitor=false -c core.hooksPath=/dev/null` **and run under the
inner projection**, not the dispatcher's environment. The flags alone are not
enough, and this was measured rather than argued: with both flags set,
`git status --porcelain` invoked a repository-configured
`filter.<driver>.clean` on a same-size content change and again on a merely
stat-dirty unmodified file, and the filter received `HOME=/Users/johnss51`
and the record sink. Content filters are an ordinary project feature
(`git-lfs` is one), so a check such as `git-clean` or `assert-checkout-clean`
runs project-controlled code. Under the inner projection that code sees the
agent's throwaway home and no record path. The probe is kept as a test.

**The dispatchers themselves.** Every prelude verb is `bun run
"$QUORUM_REPO_ROOT/src/cli/check-tool.ts" …` executed with cwd set to the
agent's workdir (`src/checks/prelude.sh:20-21,28,31,34`; `runPhase` spawns with
`cwd: args.workdir`). Bun reads `bunfig.toml` and `.env` from its cwd. This
was measured during design on Bun 1.4.2 with a workdir holding a
`bunfig.toml` `preload` that writes a marker and a `.env` setting a probe
variable, running a script from a *different* directory:

| invocation | preload | `.env` |
|---|---|---|
| `bun run <abs script>` | **executed** | **loaded** |
| `--config=<trusted bunfig>` | not run | loaded |
| `--env-file=/dev/null` | executed | absent |
| both flags | not run | absent |
| `--cwd=<trusted dir>` | not run | absent |

So today an ordinary Bun project that legitimately configures a preload runs
agent code inside the trusted outer layer, with the operator's `HOME` and the
record sink, and its `.env` can shadow any variable the dispatcher reads —
`QUORUM_RECORD_SINK` included. The prelude holds **five** `bun run`
invocations, not four: the four dispatcher functions and the source-time
`list-check-verbs.ts` call at `prelude.sh:20`, whose stdout is fed to `eval`
to define the verb functions. All five gain
`--config="$QUORUM_REPO_ROOT/bunfig.toml" --env-file=/dev/null`; the
source-time one matters most, since merely sourcing the prelude from the
workdir would otherwise run the preload before any verb is called. The
repository's `bunfig.toml` is the trusted configuration (it holds only
`[test] root = "test"`). `--cwd` is not used, because the verbs take their
working directory from `process.cwd()` (`src/check/fs-verbs.ts:47`) and must
keep evaluating relative paths against the workdir. Nothing legitimate is
lost: the dispatchers have never run from the repository root, so they never
loaded a repository `.env`.

**The phase executor takes its environment as an argument.** `runPhase`
today constructs its env internally (`src/checks/index.ts:62-100`). It is split
into `runPhaseWithEnv(args, env)` — the primitive that creates the sink, spawns
`bash`, parses the records and applies the exit-code discipline — and
`runPhase(args)`, which is `runPhaseWithEnv(args, outerEnv(args))`. The sink
path is created by the primitive and overlaid onto whatever env it is handed,
so a caller cannot forget it. Production calls `runPhase`; the replay below
calls the primitive twice with two environments. One execution path, no
duplicate executor.

The outer environment alone cannot select the *inner* behaviour, because
`verbCommandSucceeds` runs inside the dispatcher subprocess and builds the
inner projection from its own environment. So the outer environment carries
one more variable, **`QUORUM_INNER_ENV`**, read by the dispatcher and never
passed to the nested command: `projected` makes `verbCommandSucceeds` apply
the inner projection described above; `legacy` makes it inherit the
dispatcher's environment **minus the selector itself**, which is otherwise
what it does today. In both modes the selector is stripped before the nested
command or git subprocess is spawned, so no process below the dispatcher can
observe it; the environment-dumper and git-filter tests assert its absence in
both modes. `runPhase` always sets
`projected`. The only caller that ever sets `legacy` is the replay's Arm L.
The same variable governs the harness's git spawns (below).

**Not changed:** the Gauntlet launch environment (`spawnGauntlet`,
`src/runner/index.ts:322-330`), a separate seam that legitimately carries the
subject's credentials.

The proxy variables carry no credential in this environment. An operator whose
proxy URL embeds one would be passing it to inner commands; the allowlist lives
in one module so that decision is visible.

### Compatibility

**`scripts/strip-runs`.** Today it targets `<run>/home` only and takes liveness
from the run directory's mtime (`scripts/strip-runs:84-113`). Two things
change. It strips `<root>/workspaces/<name>/home` when that exists and
`<root>/<name>/home` otherwise, so the 2,506 legacy runs keep working. And its
liveness rule changes, because the workspace directory's mtime is not
refreshed by writes beneath `home/`, while the record directory is written at
every phase boundary: a run is strippable only when `<root>/<name>/verdict.json`
exists **and** the newer of the record directory's and the verdict's mtime is
older than the age threshold. An in-flight run has no verdict, so it is never
touched, whatever its workspace's mtime says. This is stronger than today's
rule and applies to both layouts. The `workspaces` entry itself is excluded
from the candidate list by name, as `_*` entries already are.

**`evidence/README.md`.** Every step that names a path moves with the tree it
belongs to: step 1 runs `strip-runs` as before; step 2 renames
`workspaces/<run>/coding-agent-workdir/.git` to `git-dir`; step 3 stages
`<run>/gauntlet-agent/results/` and `workspaces/<run>/home/.claude/` with
`git add -f`; step 4's gitlink check walks both trees. A committed evidence copy
mirrors the live layout, `<run>/` beside `workspaces/<run>/`.

**Docs.** The active documents that describe the run tree, found by
`rg -l '<run>/home|<run>/coding-agent-workdir|<runDir>/home|results/<' docs
README.md CLAUDE.md evidence/README.md` minus `docs/experiments`,
`docs/baselines`, `docs/audits` and the plan and spec directories, are nine:
`CLAUDE.md`, `README.md`, `evidence/README.md`, `docs/scenario-authoring.md`,
`docs/coding-agent-care-and-feeding.md`, `docs/manual-testing.md`,
`docs/adding-a-coding-agent.md`,
`docs/superpowers/skills/profiling-run-economics.md`, and
`docs/superpowers/reference/porting-harbor-converters.md`. Each is updated to
say which tree a path lives in. The environment table in
`docs/scenario-authoring.md:501-513` is rewritten with a layer column, gains
`QUORUM_AGENT_HOME`, marks `QUORUM_RUN_DIR` as outer-only with the
double-quote rule, and replaces "for sibling run artifacts use
`$QUORUM_RUN_DIR`" with "for the agent's home use `$QUORUM_AGENT_HOME`".
Historical baselines, audits and experiment notes are left as written; the plan
runs the same `rg` to confirm nothing active was missed.

**Readers of the record** — `quorum show`, `costs`, the dashboard, batch
rendering, `run-all`, `economics` — do not change, so no existing citation
breaks. Every place that enumerates the out-root's children was checked for
what it does with a new `workspaces` entry: `resolve-target.ts:26` keeps only
children holding a `verdict.json`, so `workspaces/` can never be the "newest
run"; the dashboard parses names; `strip-runs` is handled above; the remaining
`readdirSync` sites walk other roots or filter by a marker. Exactly one site is
affected, in a test, below.

**Tests.** `test/runner-home.test.ts`, `test/runner-workdir-scope.test.ts`,
`test/runner-context.test.ts` and `test/setup-helpers-codex-seed.test.ts` build
a layout from a run directory and change their fixture paths.
`test/scenario-tdd-project-suite.test.ts` injects `QUORUM_RUN_DIR` into the
migrated command (`:203-213`) and moves to `QUORUM_AGENT_HOME` with a split
fixture. `test/cli-run-sigint.test.ts:263` asserts `readdirSync(outRoot)` has
exactly two entries and then opens `verdict.json` in whichever is not the
interrupted trial; with `workspaces` present it would count three and could
pick the wrong one, so it enumerates record directories by `parseRunDirName`
instead. `test/checks.test.ts` gains `agentHome` on its fifteen `runPhase`
constructions. `test/agent-kimi.test.ts:906-950` currently derives `runDir` as the config
directory's parent, which under the new layout would be the workspace `home/`
— the wrong boundary. Its two guard tests are rewritten on an explicit fixture:
a temp out-root `O`, the record directory `O/<run>`, the workspace
`O/workspaces/<run>` holding `home/.kimi-code` (the config dir) and
`coding-agent-workdir`, and `home.runDir = O/<run>`. Assertions: the OS tmpdir
is accepted and the written file is not under `O`; a `TMPDIR` of
`O/tmp-inside` — inside the out-root, outside `workspaces/` — is walked out and
the file is still not under `O`. `test/checks.test.ts:277` is
unchanged by design. Tests that only need the `/coding-agent-workdir/` segment
in a path string do not change.

### What this is not

The record is not behind a boundary. The agent runs as the same uid and can
reach `../../../<run>/verdict.json` by name. What changes is that nothing in
the task, the cwd, a parent listing or the post-check environment points
there, and that agent-authored code no longer receives the operator's home or
credentials. The spec says this so that nobody later reads "isolation" as
"enforcement".

## Verification

### Offline — all numbered items are the gate

1. **Layout test:** after `runScenario` allocates, the workspace exists at
   `<outRoot>/workspaces/<run>/` with the sentinel, the record files are under
   `<outRoot>/<run>/`, `home.runDir` names the record directory, and
   `scanResults` over that out-root yields one cell with no entry for
   `workspaces`.
2. **Allowlist test**, in two parts. A unit test over `env-allowlist.ts`
   asserts the two constructed objects exactly: every expected key present,
   with the inner `HOME`/`XDG_*`/`TMPDIR` values equal to `xdgHomeEnv(home)`,
   and a planted `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and `AWS_SECRET_ACCESS_KEY`
   absent from both. A `bash`-level test runs an environment dumper through
   `command-succeeds` and through the outer `bash`, ignores the variables bash
   itself creates (`PWD`, `OLDPWD`, `SHLVL`, `_`), and asserts the same
   inclusions and exclusions on what remains, plus the absence of
   `QUORUM_RUN_DIR` and `QUORUM_RECORD_SINK` from the inner dump — run once
   through a `pre` phase and once through a `post` phase, so the pre-phase
   projection is asserted and not assumed.
3. **Dispatcher test:** a fixture workdir with a `bunfig.toml` `preload` that
   writes a marker and a `.env` setting a probe variable; **sourcing the
   prelude alone** from that workdir leaves no marker, and a verb run through
   it leaves no marker and does not see the variable. The sourcing half is
   what covers the fifth invocation.
4. **Git hygiene test:** a fixture repository with `core.fsmonitor` set to a
   marker-writing script leaves no marker under a harness `git-*` verb; and a
   fixture with a configured `filter.<driver>.clean` that records its
   environment, exercised through `git-clean` on a same-size change, shows
   the agent home and no record sink — the measured probe, kept.
5. **Kimi guard test:** the relocated layout accepts the OS tmpdir and rejects
   a `TMPDIR` inside `<outRoot>` but outside `workspaces/`.
6. **`scripts/strip-runs.test.sh`** gains: a legacy-layout run; a new-layout
   run; a root holding both; and a new-layout run whose workspace mtime is old
   but which has no `verdict.json`, which must be skipped.
7. **Counterfactual replay over the corpus, both phases.** The oracle is not
   the recorded verdict — the current `checks.sh` files have already drifted
   from the newest recorded runs, and this design rewrites four more — but the
   **legacy environment**. A new `scripts/replay-post-checks <run-dir>...`:
   - **Eligibility:** for each scenario, the newest run whose `verdict.json`
     `checks` array holds at least one `phase: "post"` record and whose
     workspace still exists (legacy `<run>/coding-agent-workdir` or
     `workspaces/<run>/coding-agent-workdir`). A scenario with no such run is
     listed as not replayable with the reason (no run, setup-stage verdict,
     stripped workspace). At spec time 61 of 98 scenarios have a recorded run.
     **Eligibility is not sufficient on its own, because arm equality is
     satisfied by two identical failures.** `strip-runs` deletes
     `home/.claude/plugins/cache` from finished runs (`scripts/strip-runs:42-46`),
     and a recorded `code-review-of-a-committed-change` run's
     `installed_plugins.json` still names a stub under that deleted cache,
     which the current pre-check dereferences and executes
     (`scenarios/code-review-of-a-committed-change/checks.sh:40-47`); both
     arms would fail identically and the run would "pass" the replay without
     the legacy arm ever exercising the check. So each eligible run must also
     pass an **anti-vacuity prerequisite**, and the prerequisite is
     **phase-correct**: it applies to **post-phase** records only. Every
     post-phase check that the recorded verdict shows as passed, and whose
     current text (name and arguments) is unchanged from the recorded record,
     must pass in Arm L; the archived final state is exactly the state those
     checks ran against historically, so a failure means the archive is
     degraded. A run that fails this is demoted to **non-replayable: degraded
     archive**, with the first such check named, and is not counted toward
     coverage. Pre-phase records are **excluded from the prerequisite** on
     purpose: `pre()` is replayed against the post-agent state, so a pre-check
     such as `git-clean` that passed on the fresh fixture legitimately fails
     once the agent has created a file (a healthy
     `brainstorming-asks-tooling-question` run has an agent-written design doc
     untracked in its final workspace). Instead, every pre-check that passed
     historically and fails in Arm L is **listed**, and the plan classifies
     each listed shape once — *state-dependent* (expected after the agent
     phase) or *degraded* (a missing artifact, such as the stripped stub cache
     above) — and builds a synthetic counterfactual fixture for every degraded
     command shape. The recorded verdict is used here only as a filter on
     archive integrity, never as the equality oracle.
     Absolute paths stored inside regular files — registries, lockfiles,
     launch records — are **not rewritten**; a read through one lands on the
     source run, which is hashed before and after to prove it is untouched,
     and a path that no longer exists fails identically in both arms, which is
     exactly what the prerequisite demotes.
   - **Cloning:** the **whole workspace** is copied into a temp tree per arm —
     for a legacy run, every `coding-agent-workdir*` entry, `home`, and the
     sentinel; for a new-layout run, `workspaces/<run>/` entire — because
     scenario-created siblings are linked worktrees whose git metadata points
     *absolutely* back into the source run in both directions
     (`results/worktree-no-drift-to-main-claude-auto-20261003T112456Z-f670`:
     the main repo's `.git/worktrees/<sibling>/gitdir` names the sibling's
     `.git`, and the sibling's `.git` file names the main repo's `worktrees/`
     entry). After copying, each cloned main repository is repaired with **every cloned
     linked worktree named as an argument** —
     `git -C <arm>/coding-agent-workdir worktree repair <arm>/coding-agent-workdir-<suffix>…`
     (git 2.56.0 on this host). The arguments are not optional: with none,
     `repair` follows the copied `gitdir` pointer, which still names the
     *source* linked worktree, and rewrites the source's `.git` file — the
     after-hash would catch that, but after the damage. Before invoking it the
     script asserts that each copied `gitdir` pointer names a path outside the
     arm, which is the condition under which the arguments are required, and
     the repair is first exercised on a disposable fixture built for the test,
     never on the retained corpus run. Pointers are then classified and
     checked: **git pointers** — every `.git` file and `gitdir` file — must
     resolve inside the arm; **intra-source symlinks** — absolute links whose
     target lies inside the source workspace, such as `home/.local/bin/claude`
     → the run's own `versions/…` — are rewritten to the arm and must then
     resolve inside it; **external references** — absolute links to anywhere
     else, such as the fixture's
     `home/Applications/Claude Code URL Handler.app/Contents/MacOS/claude` →
     `~/.local/share/claude/versions/2.1.287` — are left as they are and
     listed in the artifact. The invariant asserted is that **no pointer of
     any class resolves into the source run or into the opposite arm**. The
     source run is hashed before and after and must be unchanged.
   - **Arms, and the exact difference between them.** Both arms run the
     *current* scenario's `checks.sh`, `pre` then `post`, through
     `runPhaseWithEnv`, with the agent read from the run-dir name, the config
     dir from that agent's `home_config_subdir`, `QUORUM_AGENT_HOME` set to the
     clone's home, and `QUORUM_TRANSCRIPT_PATH` set when `<run>/trajectory.json`
     exists. **Arm L** is the legacy construction reproduced in the script —
     the ambient `envSnapshot()` plus the `QUORUM_*` values exactly as
     `runPhase` builds them today — **plus `QUORUM_AGENT_HOME`**, because the
     four migrated checks reference it and would otherwise fail in that arm for
     a reason unrelated to hygiene, and with `QUORUM_INNER_ENV=legacy`.
     **Arm N** is `outerEnv(args)`, which carries `QUORUM_INNER_ENV=projected`.
     The per-arm difference is therefore exactly, and only: the outer allowlist
     in place of the ambient environment; and, inside `command-succeeds` and
     the harness's git spawns, the inner projection — `HOME`/`XDG_*`/`TMPDIR`
     overlaid from the agent home and `QUORUM_RECORD_SINK`,
     `QUORUM_REPO_ROOT`, `QUORUM_TRANSCRIPT_PATH`, `QUORUM_RUN_DIR` absent.
     Nothing else varies.
   - **Comparison:** the ordered sequence of `(phase, check, args, negated,
     passed)` and each phase's exit code must be identical between arms, with
     each arm's clone root replaced by the placeholder `<ARM>` in `args` before
     comparing. After the two migrations above no shipped check expands an
     arm-specific path at the outer layer, so this canonicalization is a guard
     against a future one, not a load-bearing step; the replay reports how many
     records it rewrote, which should be zero. `pre()` runs against the
     post-agent state in both arms, so its records may differ from the
     historical pre records; only arm-to-arm equality is asserted, which is
     exactly the environment effect this item exists to isolate.
   - **Acceptance, with a predeclared coverage floor.** Every replayable run
     is equal across arms, and all three of the following hold, else the gate
     fails rather than passing on a shrunken set: (i) the replayable set is at
     least two-thirds of the eligible set (eligible is 61 scenarios at spec
     time, so at least 41); (ii) every tool the shipped inner commands invoke
     — at spec time `grep`, `test`, `node`, `git`, `find`, `npm`, `awk`, `ls`,
     `npx`, `go`, `pytest`, `python3`, 26 scenarios running a runtime or
     package tool — is exercised in the post phase by at least one replayable
     run or by a synthetic counterfactual; (iii) each of the four migrated
     scenarios is covered either by a replayable corpus run or, where its
     archive is degraded, by a synthetic fixture in the current check format,
     the `tdd-runs-the-project-suite` fixture below being the first. The
     replayable, demoted and listed sets are all reported with reasons. A divergence
     names the check and the first differing record; the cause is either a
     variable the allowlist must carry, added deliberately, or a check that
     depended on the operator's home, which is a latent defect fixed in the
     check. The table — scenario, run id, pre and post record counts, equal or
     first divergence, external references — is retained in the evidence note.
   - **The script's own tests.** (i) A replay over the recorded worktree run
     above, asserting the source and opposite-arm trees unchanged and the
     pointer invariant. (ii) A planted environment dumper as an inner command:
     Arm L's dump shows the operator's `HOME` and the sink, Arm N's shows the
     agent home and neither — proving the seam selects. (iii) A **synthetic**
     migrated-scenario fixture, not a corpus run: every recorded
     `tdd-runs-the-project-suite` log is in the old `args=… home=…` text form
     while the current check expects a JSON line, so a corpus run fails in both
     arms and proves nothing. The fixture writes one `.test-history.log` line
     in the current format with the clone's agent home, asserts arm equality
     with both passing, then a **mutation**: Arm L without `QUORUM_AGENT_HOME`
     must diverge — which is what proves the contract variable is load-bearing
     rather than decorative. (iv) A second synthetic fixture in the exact shape
     of the migrated `codex-approach-gate-fires-on-architecture` check — a
     single-quoted `grep -rq` over `"$QUORUM_AGENT_HOME/.cache/…"` with a
     planted match — asserting both arms pass **and emit byte-identical raw
     records** with zero canonicalization rewrites; and the same command in its
     pre-migration double-quoted form, asserting the records differ, which is
     what the migration exists to prevent.
     **Review status of (iv) and the quoting migration:** these were added in
     the final round of the second spec gate, after that gate's ceiling, under
     the human partner's "fix and defer" disposition; they are the one part of
     this document not confirmed by a Codex spec-review pass, and the plan
     gate — which reads this spec and the concrete replay task — is the
     confirming review.
8. The four migrated scenarios and the new lint pass `quorum check`;
   `bun run check` passes.
9. **Detector test:** the three misplaced-rollout counterfactuals under
   Layout — record-tree scratch, wrong workspace subdirectory, launch cwd.

### Live

- **Three smokes**, each `quorum run scenarios/00-quorum-smoke-hello-world
  --coding-agent <agent>` for `claude-auto`, `codex` and `antigravity` — a
  scenario with no `# coding-agents:` restriction and a two-line post-check,
  so a failure is attributable to the layout and not the task; Antigravity
  because its `--add-dir` rules are the one place the path shape is inspected.
  Each must reach a verdict that is neither `qa-agent-misconfigured` nor a setup
  `indeterminate`, with capture finding transcripts under the new home. A smoke
  failure stops the work.
- **Paired control** on `cost-api-field-rename-boundary`, n=10 per arm; the
  baseline arm from a checkout pinned to evals `b6a923a31`, the new arm from the
  branch head; arms interleaved. **Agent configuration, predeclared:**
  `claude-auto` with model `claude-opus-5-5`, the configuration the re-baseline
  measured (`docs/experiments/2026-10-03-clean-harness-rebaseline.md:22-32`);
  the Gauntlet-Agent on `claude-opus-5-5`; the same hyperpowers plugin root in
  both arms; the Claude Code version is whatever is installed when the campaign
  starts, recorded by the analyzer and required equal across arms (the
  re-baseline's 2.1.288 is not assumed to still be current).
  **The observable is criterion 1**, exactly as the re-baseline defines it: a
  session passes when `criteria[0]` and `criteria[1]` of the Gauntlet-Agent's
  `result.json` both pass (`docs/experiments/2026-09-30-main-boundary-gating.md:7`),
  extracted by a campaign analyzer derived from the re-baseline's `tally.py`.
  That script cannot be used as is: it hardcodes its campaign and globs
  transcripts at `home/.claude/projects/*/*.jsonl` beneath the run path
  (`evidence/2026-10-03-clean-harness-rebaseline/tally.py:180`), so it would
  find no transcripts for the relocated arm and exclude every new-arm session
  from its version and entrypoint checks. The campaign copy takes `--records`
  and `--workspaces` roots **and the manipulation-check expectations as
  parameters** — `--plugin-root`, `--model`, `--cc-version` — in place of the
  constants the re-baseline hardcoded (`tally.py:38-46`: plugin root, model id,
  CLI version, entrypoint `cli`, no foreign instruction paths, no task-tool
  use). Its own-run containment check, which classifies an instruction path as
  foreign when it lies outside the run, recognises both `<records>/<run>/` and
  `<workspaces>/<run>/` as the run. It reads `result.json` from the record tree
  and transcripts from whichever layout the run has, and is unit-tested on one
  baseline-layout fixture and one relocated-layout fixture, each exercising
  every manipulation check, before either arm runs. **Manipulation mismatches fail closed.** The re-baseline's analyzer silently
  excludes a session that fails a manipulation check and marks the reduced
  sample provisional (`tally.py:353-363,380-403`); the campaign copy does not
  inherit that. Any mismatch in either arm — plugin root, model, CLI version,
  entrypoint, a foreign instruction path, task-tool use — is an **automatic
  stop**, because it means the campaign configuration or the layout
  contaminated the session, which is the one thing this control exists to
  detect. The pass-count threshold is applied only when each arm holds
  **exactly ten qualifying sessions**. A session is replaced only under the
  project's existing void rule (`docs/scenario-authoring.md:863-868`): a
  grader-exit void is replaced, capped at three replacements per arm; a
  harness-setup void is relaunched and does not consume the cap; an agent that
  failed or stalled is a real trial and counts. If either arm has fewer than
  ten qualifying sessions after that, the analyzer exits non-zero and no
  threshold is applied. The analyzer's fixtures include a manipulation
  mismatch (must stop) and a replaced void (must still reach ten). The clean
  baseline on that observable is 5/10 (`docs/experiments/2026-10-03-clean-harness-rebaseline.md:56`)
  — the cell nearest 50%, so the most sensitive to a shift. The composed final
  is **not** the observable; on this cell it is 1/10 and would say something
  different. **Acceptance, predeclared:** with `p_b` and `p_n` the criterion-1
  pass counts of the baseline and new arms and indeterminates never counted as
  passes, `p_b - p_n <= 2` proceeds; a larger gap stops for a human decision.
  Two automatic stops: immediately, on any new-arm run that is
  `qa-agent-misconfigured` or a setup `indeterminate`; and after both arms
  complete, on any new-arm **failure signature** absent from the baseline arm.
  A failure signature is the normalized tuple
  `(verdict.final, verdict.error.stage or "none", sorted names of failed
  checks)` — defined so it is computable from `verdict.json` alone and does not
  depend on free-text reasons. The campaign analyzer computes the set of
  signatures per arm and stops when the new arm's set has a member the
  baseline's lacks; its fixtures prove that a signature present in both arms
  proceeds and that a new `checks`, `capture` or `setup` signature stops. Stated
  plainly: n=10 separates only a large shift, and a large shift is the only
  kind that would matter here.

Artifacts the evidence note cites go to
`evals/evidence/2026-10-14-agent-write-isolation-relocation/`.

## Files

**`hyperpowers-evals`**
- `src/runner/index.ts` — the workspace derivation; `runDir` into `RunHome`;
  `agentHome` into **both** `runPhase` calls; `workspaceDir` into the Copilot
  cascade and the misplaced-rollout detector.
- `src/agents/copilot.ts` — the leak scan over both roots.
- `src/capture/index.ts` — the detector's second containment root.
- `evidence/2026-10-14-agent-write-isolation-relocation/tally.py` — the
  campaign analyzer and its two layout fixtures.
- `src/agents/index.ts` — `RunHome.runDir`.
- `src/agents/kimi.ts` — artifact root from `home.runDir`; the comment.
- `src/checks/env-allowlist.ts` (new) — the list and the two projections.
- `src/checks/index.ts` — `RunPhaseArgs.agentHome` (required);
  `runPhaseWithEnv` as the executor; `runPhase` as its production wrapper over
  the outer allowlist.
- `test/checks.test.ts` and `test/cli-run-sigint.test.ts`.
- `src/check/fs-verbs.ts` — the inner projection in `verbCommandSucceeds`,
  selected by `QUORUM_INNER_ENV`; the git flags and the inner projection in the
  three git spawns.
- `src/checks/prelude.sh` — `--config` and `--env-file=/dev/null` on all five
  `bun run` invocations.
- `test/provision-helpers.ts` and `test/agent-codex-plugin-stage.test.ts`, the
  two test-side `RunHome` construction sites; `test/runner-copilot-cascade.test.ts`.
- `src/scaffold.ts` — the `$QUORUM_RUN_DIR`-in-single-quotes lint.
- `scripts/replay-post-checks` (new), the two-arm replay, and its test.
- `scenarios/{codex-approach-gate-fires-on-architecture,
  codex-plan-gate-algorithm-locked-after-round1,
  codex-gate-stale-broker-attributed,tdd-runs-the-project-suite}/checks.sh`.
- `scripts/strip-runs` and `scripts/strip-runs.test.sh`.
- The nine documents named under Compatibility.
- Tests named under Compatibility, plus the new ones in items 1–5 and 7.

**`hyperpowers`** — this spec and the plan; the shelved spec's status line.

## Constraints

- No change to `coding-agents/*.yaml`, the launchers, or the Gauntlet fork.
- No new runtime dependency.
- Suites run on `/bin/bash` 3.2.57 on a heavily loaded host; no short per-test
  timeouts.
- There is no CI; suites are run by hand, one script per `bash` invocation.

## Out of scope

- **The pane's scratch cwd beside `result.json`.** The Coding-Agent sits there
  only when the Gauntlet-Agent ignores the launcher, and that run is already
  void as `qa-agent-misconfigured`. Moving it needs a Gauntlet fork change and
  is deferred with that reason recorded.
- The agent launch environment.
- Rewriting the 73 config-dir bootstrap checks as typed verbs so the inner
  layer need not know the agent's config path. Reasonable, separate.
- Host or container isolation of the agent (the codex host-skill confound in
  `docs/eval-harness-portfolio.md:80`), a separate question with `stockyard`
  as its documented primitive.
- Privilege separation. The shelved spec remains the design for an adversarial
  scenario, should one be added.

## Known limits

- Same uid, no boundary; see "What this is not".
- Evidence copies and `strip-runs` carry two layouts for as long as legacy runs
  are kept.
- The one-component cwd change is measured, not assumed neutral, and the
  measurement has the power n=10 affords.

## Assumptions

**Assumption:** running inner commands under the agent's throwaway home rather
than the operator's does not change the outcome of any shipped check. The
replay in offline item 7 is how this is tested against every scenario with a
recorded run, before the allowlist lands; the smokes then confirm it live.

**Assumption:** no agent CLI inspects the absolute workdir path beyond
Antigravity's hidden-component rule.
*Validate by:* the three smokes, before the paired control.
