# Post-Release Follow-Ups to 6.16.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-10-post-release-follow-ups-design.md` (approved 2026-10-11; Codex spec gate converged at round 3 of 4).

**Goal:** Land the spec's ten items in hyperpowers-evals and hyperpowers: runs record their container image and resolve more Gauntlet shims without guessing, the dashboard trusts a verdict only after its writer exits, the eight brainstorming scenarios share one Codex stub, the offline focus-arm test runs P3, and the hyperpowers scripts and tests stop reading failures as success.

**Architecture:** Two branches, both named `post-release-follow-ups`: evals off evals `main` at `81da2b74b` in `evals/.worktrees/post-release-follow-ups`, hyperpowers off `main` at `37abdbc` in `.worktrees/post-release-follow-ups`. Tasks 1 to 7 change evals (provenance, the container launcher, the run-phase writer, the dashboard reader, the shared stub, the focus-arm test); Tasks 8 to 14 change hyperpowers (two shipped scripts, test fixes, the here-string conversion and its fence, one plan Correction). Every task is one problem with one commit, proven by a test that fails before the change where a failure can be shown.

**Tech Stack:** Bun 1.4 with TypeScript, biome and zod (evals); bash 3.2 (macOS) and bash 5 scripts, Node 24, awk, perl (hyperpowers tests); git; Docker only for the optional manual check after Task 14.

## Global Constraints

- One problem per change; the full diff in chat and the human partner's approval before every commit (the controller presents each task's diff; implementers commit on the branch only after that approval is relayed in their dispatch or fix instructions).
- No attribution lines of any kind in commits or files: no `Co-Authored-By`, no "Generated with" text.
- Nothing is pushed.
- Committed files must not carry the proxy host, the `NO_PROXY` list, the GCP project id or private instruction text; every staged diff is scanned with `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` (expect `hits: 0`). The scan is the controller's, run before each approval.
- No live eval run, live Codex review or live `claude` session runs in this plan, and no test step may launch the real `claude` or `gauntlet`. Live and integration suites are never run; Task 13 names the converted files only they reach and checks them with `bash -n`.
- No evidence directory is named: this plan makes no live run whose artifacts an evidence note would cite.
- Pre-registered records are only appended to, with a dated Correction: Task 14 appends to an executed plan. Living guidance (`evals/docs/scenario-authoring.md`, `docs/testing.md`) is edited in place.
- The controls of record are not re-scored.
- This spec, this plan and Task 14's Correction are committed in hyperpowers under its `CLAUDE.md` section "Planning and Spec Docs Are Tracked Here", each commit only after the human partner approves its diff.
- Worktree paths. Evals: `/Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/post-release-follow-ups` (written EV below). Hyperpowers: `/Users/johnss51/Development/agents/hyperpowers/.worktrees/post-release-follow-ups` (written HP below). A command marked (EV) or (HP) runs from that worktree's root.
- Shell loops added or changed in this work exit non-zero on failure; a loop whose last command is `echo` is the defect Task 14 records.
- bash scripts under `tests/` and `skills/*/scripts/` must run under macOS bash 3.2: an array that may be empty is expanded as `${arr[@]+"${arr[@]}"}` under `set -u`; no associative arrays, no `mapfile`; a regex with braces is held in a variable for `[[ =~ ]]`.
- Shell snippets the controller runs from its zsh tool never assign the names `path`, `status`, `fpath`, `cdpath` or `manpath`; multi-command loops go in bash script files.
- Evals TypeScript is formatted with `bun run format` before `bun run lint` runs: the plan's code is content, and its line wrapping is biome's to decide. Formatting must touch only the task's files; any other file it changes is reported, not committed.
- No emojis anywhere. Comments explain why, not what.

## Grounding

- `evals/src/runner/provenance.ts:15-23` (`ProvenanceDeps`, every lookup injected), `34-39` (`commitOf`, 40-hex or null), `96-124` (`shimTarget` and its comment), `126-163` (`captureProvenance`, the probe-directory choice at `139-146`), `165-198` (`defaultProvenanceDeps`), `200-210` (`cell`, `renderProvenanceLine`).
- `evals/src/contracts/verdict.ts:63-73`: `ProvenanceSchema`; `94`: `provenance: ProvenanceSchema.optional()` on the verdict.
- `evals/src/env.ts:5-10`: `getEnv`, the only sanctioned `process.env` read (biome `noProcessEnv`).
- `evals/test/runner-provenance.test.ts:27-70` (`fakeGit` keyed by cwd, `deps()` over a fake filesystem map), `77-105` (a full `toEqual` on the capture), `179-229` (the `/opt/homebrew` trap shape), `333-361` (the in-repo mock shim), `424-447` (render tests).
- `evals/scripts/evals-container:17-20` (`die`), `181-191` (`resolve_gauntlet_root`), `389-397` (the `build` case); `container/Dockerfile:145-150` (the last `RUN`, then `WORKDIR` and `CMD`).
- `evals/test/evals-container.test.ts:20-150` (`FAKE_DOCKER` logging argv as JSON), `152-186` (`makeHarness`, a `bin` dir first on `PATH`), `203-213` (`runWrapper`), `229-233` (`dockerCommand`), `343-363` (the build test).
- `evals/docs/scenario-authoring.md:650-672` (the Gauntlet identity paragraph), `801-836` (the comparability bullet's evals-harness clause, with the sentence "For a container run, ... the image is not recorded" at `825-828`).
- `evals/src/runner/phase.ts:1-20` (`writePhase`); `evals/test/runner-phase.test.ts:1-15`.
- `evals/src/dashboard/scan.ts:62-72` (`pidAlive`), `74-95` (the verdict cache and `readDashboardVerdict`), `108-126` (`readPhase`), `136-199` (`scanResults`); `evals/src/dashboard/contracts.ts:38-45` (`DashboardVerdictSchema` comment), `72-76` (`RunningRun`); `evals/src/dashboard/server.ts:240-244` (the cost lookup on `cell_finished`).
- `evals/test/dashboard-scan.test.ts:68-107` (`readDashboardVerdict` tests, `writeRun`), `173-223` (running, authority and abandoned cases).
- `evals/src/setup-helpers/codex-seed.ts:17-24` (`agentHomeFromWorkdir`), `208-230` (`registryJson`), `232-259` (`seedCodexPluginCc`); `registry.ts:120-135` (entries and the count comment); `sdd-fixtures.ts:7-14` (`join(repoRoot(), 'fixtures')`); `src/paths.ts:12-15` (`repoRoot`); `context.ts:7-12` (`HelperContext`).
- `evals/test/setup-helpers-codex-seed.test.ts:16-42` (an unused runner, `makeRun`, `ctx`); `evals/test/provision-helpers.ts:1-30` (a non-test helper module under `test/`); `evals/test/fixtures/` (test data files).
- The eight stub blocks run from the `# Seed stub codex-plugin-cc` comment to the end of each file: `scenarios/brainstorming-asks-tooling-question/setup.sh:21-270`, `brainstorming-bounded-fires-approach-gate/setup.sh:56-299`, the five `brainstorming-router-escalates-b*/setup.sh:69-311`, `brainstorming-router-no-downgrade/setup.sh:67-310`. The seven ported heredocs are byte-identical (sha prefix `febb24244d`); the reference differs only in comments and in logging `setup`.
- `evals/test/scenario-codex-stub-task.test.ts:1-149` (rewritten by Task 6); `evals/test/scenario-brainstorming-tooling-question.test.ts:70-81` (`stubSource()` reads the heredoc), `97-115` (`newWorkdir`).
- `evals/scripts/codex-focus-arm.test.sh:60-86` (`run_arm`, `count`), `92-122` (`check_captures`), `139-175` (the treatment and control arms).
- `skills/brainstorming/scripts/stop-server.sh:34-41` (`process_exists`), `81-86` (`is_brainstorm_server`), `88-108` (identity and `stale_pid`), `110-145` (the stop loop); `tests/brainstorm-server/stop-server.test.sh:39-46` (helpers), `259-287` (Test 9's fake `ps` and the results line).
- `skills/requesting-code-review/scripts/gate-telemetry:104-153` (rows and the SDD walk), `228-253` (fleet aggregate), `254-257` (JSON), `276-287` (fleet text); `tests/codex-review-gate/test-gate-telemetry.sh:10-13` (`pass`/`fail`/`expect`), `268-303` (plan workspaces `wsA`, `wsB`, key5), `364-365` (the end).
- `tests/packaging/test-package-skill.sh:40-53, 112-117, 135-147, 177-207`; `tests/codex-review-gate/test-gate-split-lossless.sh:65-67` (`TEST_ROOT`, trap), `185-194`, `333-342`.
- `tests/hooks/test-no-heredocs-in-hooks.sh:1-57`; `docs/testing.md:23` (the hooks row), `44-50` (the counting loop).
- `tests/claude-code/test-delivery-resolution.sh:36-43, 49-55` (the `sed` extraction and the `source` of the block); `tests/claude-code/test-subagent-driven-development-integration.sh:273-283` (the block's last line).
- `docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md:1789-1803`: the appended `**Correction (date).**` paragraph form.
- Here-string conversion: `none: no existing perl conversion helper`; the rule and its dry run are in Before Task 1, step 4.

---

## Before Task 1 (controller)

1. Worktrees. Hyperpowers: `git -C /Users/johnss51/Development/agents/hyperpowers worktree add .worktrees/post-release-follow-ups -b post-release-follow-ups main` (base `37abdbc`). Evals: `git -C /Users/johnss51/Development/agents/hyperpowers/evals worktree add .worktrees/post-release-follow-ups -b post-release-follow-ups main` (base `81da2b74b`; the checkout takes several minutes, so run it in the background; the worktree needs no `bun install`, bun resolves `evals/node_modules` by walking up).
2. First hyperpowers commit, after the human partner approves its diff. The spec and this plan are untracked files in the main checkout, so copy them into HP first: `cp docs/hyperpowers/specs/2026-10-10-post-release-follow-ups-design.md .worktrees/post-release-follow-ups/docs/hyperpowers/specs/` and `cp docs/hyperpowers/plans/2026-10-11-post-release-follow-ups.md .worktrees/post-release-follow-ups/docs/hyperpowers/plans/`. Commit message: `docs(hyperpowers): pre-register the post-release follow-ups spec and plan`.
3. SDD workspace: `bash skills/subagent-driven-development/scripts/sdd-dir docs/hyperpowers/plans/2026-10-11-post-release-follow-ups.md` from HP; one ledger for both repositories (evals tasks record their commits with the `evals` prefix).
4. Helper scripts, in `/Users/johnss51/.cache/hyperpowers/post-release-follow-ups/` (durable scratch; `/tmp` is not). `herestring.pl`, exactly:

   ```perl
   # cmd <<< "$var"  ->  cmd < <(printf '%s\n' "$var"), on code lines only.
   # Run as: perl -p -i herestring.pl FILE...
   next if /^\s*#/;
   s/<<<\s*("\$(?:\{[A-Za-z_]\w*\}|[A-Za-z_]\w*|[0-9])")/< <(printf '%s\\n' $1)/g;
   ```

   A dry run over a copy of `tests/` at `37abdbc` converted 135 redirections in 34 files, left exactly four `<<<` lines (`test-delivery-resolution.sh:37`, `test-no-heredocs-in-hooks.sh:6`, `24` and `48`), and every converted file passed `bash -n`.

   `run-suites.sh`, exactly:

   ```bash
   #!/usr/bin/env bash
   # run-suites.sh <suite>... : runs each suite as its own bash process, logs
   # each to logs/<name>.log beside this script, prints one line per suite and
   # exits non-zero when any suite fails.
   set -u
   here="$(cd "$(dirname "$0")" && pwd)"
   mkdir -p "$here/logs"
   fails=0
   for t in "$@"; do
     if bash "$t" > "$here/logs/$(basename "$t").log" 2>&1; then
       echo "ok   $t"
     else
       echo "FAIL $t"
       fails=$((fails + 1))
     fi
   done
   echo "fails=$fails"
   [ "$fails" -eq 0 ]
   ```

---

### Task 1 (evals): Provenance records the container image's build source

**Risk tier:** high — changes what every verdict's `provenance` record holds.

**Files:**
- Modify: `evals/src/runner/provenance.ts:1-23, 126-163, 165-198, 208-210`
- Modify: `evals/src/contracts/verdict.ts:63-73`
- Test: `evals/test/runner-provenance.test.ts`

**Interfaces:**
- Produces: `ProvenanceDeps.env: (name: string) => string | undefined`; `Provenance.container_image?: { evals_commit: string | null; container_clean: boolean | null; gauntlet_commit: string | null; gauntlet_clean: boolean | null } | null` (always set by `captureProvenance`: `null` on the host); the environment variable names `QUORUM_IMAGE_EVALS_COMMIT`, `QUORUM_IMAGE_CONTAINER_CLEAN`, `QUORUM_IMAGE_GAUNTLET_COMMIT`, `QUORUM_IMAGE_GAUNTLET_CLEAN` (Task 2 bakes them into the image).
- Consumes: nothing new.

**Mirror:** `evals/test/runner-provenance.test.ts:77-105` (a whole-object `toEqual` plus a schema round trip) and `424-447` (render cases).

- [ ] **Step 1: Write the failing tests**

In `evals/test/runner-provenance.test.ts`, add `env: () => undefined,` to the object `deps()` returns, after `isExecutable` and before `...over`. In the two whole-object assertions, add `container_image: null` as the last key: the `toEqual` in 'clean evals checkout, host shim shape' (lines 94-103) and the one in 'git absent and gauntlet off PATH yield nulls, never a throw' (lines 370-374).

Append this `describe` block after the `captureProvenance` block (before `describe('renderProvenanceLine'`):

```ts
describe('container image identity', () => {
  const NAMES = [
    'QUORUM_IMAGE_EVALS_COMMIT',
    'QUORUM_IMAGE_CONTAINER_CLEAN',
    'QUORUM_IMAGE_GAUNTLET_COMMIT',
    'QUORUM_IMAGE_GAUNTLET_CLEAN',
  ] as const;
  const capture = (values: Partial<Record<(typeof NAMES)[number], string>>) =>
    captureProvenance(
      deps(
        {
          runner: fakeGit({ '/repos/evals': { head: A, status: '' } }),
          env: (name) => values[name as (typeof NAMES)[number]],
        },
        {},
      ),
    );

  test('a host run, with the variables unset, records container_image null and keeps the host line', () => {
    const p = capture({});
    expect(p.container_image).toBeNull();
    expect(renderProvenanceLine(p)).toBe('provenance: evals aaaaaaa gauntlet unknown');
    expect(ProvenanceSchema.parse(p)).toEqual(p);
  });

  test('an image built without the launcher (four empty strings) is still a container run, with four nulls', () => {
    const p = capture({
      QUORUM_IMAGE_EVALS_COMMIT: '',
      QUORUM_IMAGE_CONTAINER_CLEAN: '',
      QUORUM_IMAGE_GAUNTLET_COMMIT: '',
      QUORUM_IMAGE_GAUNTLET_CLEAN: '',
    });
    expect(p.container_image).toEqual({
      evals_commit: null,
      container_clean: null,
      gauntlet_commit: null,
      gauntlet_clean: null,
    });
    expect(renderProvenanceLine(p)).toBe(
      'provenance: evals aaaaaaa gauntlet unknown image unknown gauntlet unknown',
    );
    expect(ProvenanceSchema.parse(p)).toEqual(p);
  });

  test('valid values are recorded and rendered with the cell forms', () => {
    const p = capture({
      QUORUM_IMAGE_EVALS_COMMIT: A,
      QUORUM_IMAGE_CONTAINER_CLEAN: 'false',
      QUORUM_IMAGE_GAUNTLET_COMMIT: B,
      QUORUM_IMAGE_GAUNTLET_CLEAN: 'true',
    });
    expect(p.container_image).toEqual({
      evals_commit: A,
      container_clean: false,
      gauntlet_commit: B,
      gauntlet_clean: true,
    });
    expect(renderProvenanceLine(p)).toBe(
      'provenance: evals aaaaaaa gauntlet unknown image aaaaaaa+dirty gauntlet bbbbbbb',
    );
  });

  test('malformed values become null field by field', () => {
    const p = capture({
      QUORUM_IMAGE_EVALS_COMMIT: 'HEAD',
      QUORUM_IMAGE_CONTAINER_CLEAN: 'yes',
      QUORUM_IMAGE_GAUNTLET_COMMIT: `${B}\n`,
      QUORUM_IMAGE_GAUNTLET_CLEAN: 'TRUE',
    });
    expect(p.container_image).toEqual({
      evals_commit: null,
      container_clean: null,
      gauntlet_commit: null,
      gauntlet_clean: null,
    });
  });

  test('a verdict written before the field existed still parses, and renders without image cells', () => {
    const old = {
      evals_commit: A,
      evals_clean: true,
      gauntlet: { path: null, checkout: null, commit: null, clean: null },
    };
    expect(ProvenanceSchema.parse(old)).toEqual(old);
    expect(renderProvenanceLine(old)).toBe('provenance: evals aaaaaaa gauntlet unknown');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (EV): `bun test test/runner-provenance.test.ts`
Expected: FAIL. The two edited `toEqual` cases fail on the missing `container_image` key, and the new cases fail because `container_image` is `undefined` and the image cells are absent from the rendered line.

- [ ] **Step 3: Implement**

In `evals/src/runner/provenance.ts`, add the import after the existing type imports:

```ts
import { getEnv } from '../env.ts';
```

Add the `env` member to `ProvenanceDeps` and extend its comment:

```ts
// Every lookup is injected so the module is testable without a real PATH,
// filesystem, git or environment: the runner for git, the path entries for the
// gauntlet lookup, three filesystem predicates, and the environment read that
// finds a container image's build source.
export interface ProvenanceDeps {
  readonly runner: CommandRunner;
  readonly evalsRoot: string;
  readonly pathEntries: readonly string[];
  readonly readFile: (p: string) => string | null;
  readonly exists: (p: string) => boolean;
  readonly isDirectory: (p: string) => boolean;
  readonly isExecutable: (p: string) => boolean;
  readonly env: (name: string) => string | undefined;
}
```

Add this function directly above `captureProvenance`:

```ts
// What `scripts/evals-container build` baked into the image: container/Dockerfile
// re-exports its four build args as ENV. A host run has none of them. Presence
// is tested against undefined, never by truthiness: an image built by a bare
// `docker build` sets all four to the empty string, and a run in it is still a
// container run whose image identity is unknown.
function containerImageOf(
  env: ProvenanceDeps['env'],
): Provenance['container_image'] {
  const evalsCommit = env('QUORUM_IMAGE_EVALS_COMMIT');
  if (evalsCommit === undefined) return null;
  const commit = (v: string | undefined) =>
    v !== undefined && /^[0-9a-f]{40}$/.test(v) ? v : null;
  const flag = (v: string | undefined) =>
    v === 'true' ? true : v === 'false' ? false : null;
  return {
    evals_commit: commit(evalsCommit),
    container_clean: flag(env('QUORUM_IMAGE_CONTAINER_CLEAN')),
    gauntlet_commit: commit(env('QUORUM_IMAGE_GAUNTLET_COMMIT')),
    gauntlet_clean: flag(env('QUORUM_IMAGE_GAUNTLET_CLEAN')),
  };
}
```

Change the last line of `captureProvenance` to:

```ts
  return {
    evals_commit: evalsCommit,
    evals_clean: evalsClean,
    gauntlet,
    container_image: containerImageOf(deps.env),
  };
```

In `defaultProvenanceDeps`, add `env: getEnv,` after `isExecutable`.

Replace `renderProvenanceLine` with:

```ts
export function renderProvenanceLine(p: Provenance): string {
  const host = `provenance: evals ${cell(p.evals_commit, p.evals_clean)} gauntlet ${cell(p.gauntlet.commit, p.gauntlet.clean)}`;
  const image = p.container_image;
  if (image === null || image === undefined) return host;
  return `${host} image ${cell(image.evals_commit, image.container_clean)} gauntlet ${cell(image.gauntlet_commit, image.gauntlet_clean)}`;
}
```

In `evals/src/contracts/verdict.ts`, add the field to `ProvenanceSchema` after `gauntlet`:

```ts
  // The image's build source, for a run inside the evals container; null on
  // the host, absent from verdicts written before it was recorded.
  container_image: z
    .object({
      evals_commit: z.string().nullable(),
      container_clean: z.boolean().nullable(),
      gauntlet_commit: z.string().nullable(),
      gauntlet_clean: z.boolean().nullable(),
    })
    .nullable()
    .optional(),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (EV), each as its own command: `bun test test/runner-provenance.test.ts test/cli-show.test.ts test/runner-stopped.test.ts test/runner-e2e.test.ts test/cli-run-sigint.test.ts`, then `bun run typecheck`, then `bun run format`, then `git status --short` (only this task's files changed), then `bun run lint`.
Expected: all pass; typecheck and lint clean.

- [ ] **Step 5: Commit**

```bash
git add src/runner/provenance.ts src/contracts/verdict.ts test/runner-provenance.test.ts
git commit -m "feat(provenance): record the container image's build source in each run"
```

---

### Task 2 (evals): The container build bakes its source state into the image

**Risk tier:** standard — a launcher change with a fake-`docker`/fake-`git` test, a Dockerfile metadata block, and living guidance.

**Files:**
- Modify: `evals/scripts/evals-container:181-191` (new functions after `resolve_gauntlet_root`), `389-397` (the `build` case)
- Modify: `evals/container/Dockerfile:145-150`
- Modify: `evals/docs/scenario-authoring.md:650-672, 825-828`
- Test: `evals/test/evals-container.test.ts`

**Interfaces:**
- Consumes: the four variable names from Task 1.
- Produces: an image whose environment carries the four variables.

**Mirror:** `evals/test/evals-container.test.ts:343-363` (build test over the fake `docker` log).

- [ ] **Step 1: Write the failing tests**

In `evals/test/evals-container.test.ts`, add after `FAKE_DOCKER`:

```ts
// Answers the launcher's two build-source reads and logs every call, so a test
// can pin the values and the pathspecs; any other git call fails loudly.
const FAKE_GIT = `#!/usr/bin/env bash
printf '%s\\n' "$*" >> "\${FAKE_GIT_LOG:?}"
case "\${3:-}" in
  rev-parse)
    [[ "\${FAKE_GIT_REVPARSE:-ok}" == fail ]] && exit 128
    printf '%s\\n' "\${FAKE_GIT_HEAD:?}"
    ;;
  status)
    [[ "\${FAKE_GIT_STATUS:-clean}" == fail ]] && exit 128
    [[ "\${FAKE_GIT_STATUS:-clean}" == dirty ]] && printf ' M container/Dockerfile\\n'
    exit 0
    ;;
  *)
    echo "fake git: unexpected $*" >&2
    exit 1
    ;;
esac
`;

const IMAGE_ARGS = [
  'QUORUM_IMAGE_EVALS_COMMIT',
  'QUORUM_IMAGE_CONTAINER_CLEAN',
  'QUORUM_IMAGE_GAUNTLET_COMMIT',
  'QUORUM_IMAGE_GAUNTLET_CLEAN',
];

function writeFakeGit(
  harness: ReturnType<typeof makeHarness>,
  env: Record<string, string>,
): string {
  const git = join(harness.root, 'bin', 'git');
  writeFileSync(git, FAKE_GIT);
  chmodSync(git, 0o755);
  const log = join(harness.root, 'git.log');
  Object.assign(harness.env, { FAKE_GIT_LOG: log, ...env });
  return log;
}

function buildArgs(args: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--build-arg') {
      const value = args[i + 1] ?? '';
      const eq = value.indexOf('=');
      out[value.slice(0, eq)] = value.slice(eq + 1);
    }
  }
  return out;
}
```

Inside `describe('scripts/evals-container', ...)`, after the existing build test, add:

```ts
  test('build passes the build source as four build args, read with the real git', () => {
    const harness = makeHarness();
    // The Gauntlet root is a plain directory; the ceiling keeps git from
    // finding a repository above it.
    harness.env.GIT_CEILING_DIRECTORIES = harness.root;
    try {
      const proc = runWrapper(harness, ['build']);
      expect(proc.status).toBe(0);
      const got = buildArgs(dockerCommand(harness.dockerLog, 'build'));
      expect(Object.keys(got).sort()).toEqual([...IMAGE_ARGS].sort());
      const head = spawnSync('git', ['-C', REPO, 'rev-parse', 'HEAD'], {
        encoding: 'utf8',
      }).stdout.trim();
      const containerStatus = spawnSync(
        'git',
        ['-C', REPO, 'status', '--porcelain', '--untracked-files=all', '--', 'container'],
        { encoding: 'utf8' },
      ).stdout;
      expect(got.QUORUM_IMAGE_EVALS_COMMIT).toBe(head);
      expect(got.QUORUM_IMAGE_CONTAINER_CLEAN).toBe(
        containerStatus.trim() === '' ? 'true' : 'false',
      );
      expect(got.QUORUM_IMAGE_GAUNTLET_COMMIT).toBe('');
      expect(got.QUORUM_IMAGE_GAUNTLET_CLEAN).toBe('');
    } finally {
      rmSync(harness.root, { recursive: true, force: true });
    }
  });

  test('build reads the commit and container/ (evals) and the whole checkout (Gauntlet)', () => {
    const harness = makeHarness();
    const log = writeFakeGit(harness, { FAKE_GIT_HEAD: 'a'.repeat(40) });
    try {
      expect(runWrapper(harness, ['build']).status).toBe(0);
      expect(buildArgs(dockerCommand(harness.dockerLog, 'build'))).toEqual({
        QUORUM_IMAGE_EVALS_COMMIT: 'a'.repeat(40),
        QUORUM_IMAGE_CONTAINER_CLEAN: 'true',
        QUORUM_IMAGE_GAUNTLET_COMMIT: 'a'.repeat(40),
        QUORUM_IMAGE_GAUNTLET_CLEAN: 'true',
      });
      const calls = readFileSync(log, 'utf8');
      expect(calls).toContain(
        `-C ${REPO} status --porcelain --untracked-files=all -- container\n`,
      );
      expect(calls).toContain(
        `-C ${realpathSync(harness.gauntletRoot)} status --porcelain --untracked-files=all -- .\n`,
      );
    } finally {
      rmSync(harness.root, { recursive: true, force: true });
    }
  });

  test('build records a dirty checkout as false', () => {
    const harness = makeHarness();
    writeFakeGit(harness, { FAKE_GIT_HEAD: 'a'.repeat(40), FAKE_GIT_STATUS: 'dirty' });
    try {
      expect(runWrapper(harness, ['build']).status).toBe(0);
      const got = buildArgs(dockerCommand(harness.dockerLog, 'build'));
      expect(got.QUORUM_IMAGE_CONTAINER_CLEAN).toBe('false');
      expect(got.QUORUM_IMAGE_GAUNTLET_CLEAN).toBe('false');
    } finally {
      rmSync(harness.root, { recursive: true, force: true });
    }
  });

  test('a failing rev-parse passes empty commits and the build still runs', () => {
    const harness = makeHarness();
    writeFakeGit(harness, { FAKE_GIT_HEAD: 'a'.repeat(40), FAKE_GIT_REVPARSE: 'fail' });
    try {
      expect(runWrapper(harness, ['build']).status).toBe(0);
      const got = buildArgs(dockerCommand(harness.dockerLog, 'build'));
      expect(got.QUORUM_IMAGE_EVALS_COMMIT).toBe('');
      expect(got.QUORUM_IMAGE_GAUNTLET_COMMIT).toBe('');
      expect(got.QUORUM_IMAGE_CONTAINER_CLEAN).toBe('true');
    } finally {
      rmSync(harness.root, { recursive: true, force: true });
    }
  });

  test('a failing status passes empty clean flags, never true, and the build still runs', () => {
    const harness = makeHarness();
    writeFakeGit(harness, { FAKE_GIT_HEAD: 'a'.repeat(40), FAKE_GIT_STATUS: 'fail' });
    try {
      expect(runWrapper(harness, ['build']).status).toBe(0);
      const got = buildArgs(dockerCommand(harness.dockerLog, 'build'));
      expect(got.QUORUM_IMAGE_CONTAINER_CLEAN).toBe('');
      expect(got.QUORUM_IMAGE_GAUNTLET_CLEAN).toBe('');
      expect(got.QUORUM_IMAGE_EVALS_COMMIT).toBe('a'.repeat(40));
    } finally {
      rmSync(harness.root, { recursive: true, force: true });
    }
  });

  test('the Dockerfile declares the build source after its last RUN', () => {
    const lines = readFileSync(join(REPO, 'container', 'Dockerfile'), 'utf8').split('\n');
    const lastRun = lines.reduce((last, line, i) => (line.startsWith('RUN ') ? i : last), -1);
    for (const name of IMAGE_ARGS) {
      const arg = lines.indexOf(`ARG ${name}=`);
      const env = lines.indexOf(`ENV ${name}=$${name}`);
      expect(arg).toBeGreaterThan(lastRun);
      expect(env).toBeGreaterThan(arg);
    }
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (EV): `bun test test/evals-container.test.ts`
Expected: FAIL in the six new tests (no `--build-arg` in the logged build command; no `ARG` lines in the Dockerfile). The existing tests pass.

- [ ] **Step 3: Implement**

In `evals/scripts/evals-container`, add after the closing brace of `resolve_gauntlet_root`:

```bash
# The image's build source, baked into its environment (container/Dockerfile
# re-exports these build args) so a run inside the container records what it
# runs on. A value git cannot give is passed empty, never as a clean flag, and
# a failed read does not stop the build: this script runs under set -e, so
# each read tolerates its own failure.
build_source_commit() { # <dir>
  local out
  if out=$(git -C "$1" rev-parse HEAD 2>/dev/null); then
    printf '%s' "$out"
  fi
}

build_source_clean() { # <dir> <pathspec>
  local out
  if out=$(git -C "$1" status --porcelain --untracked-files=all -- "$2" 2>/dev/null); then
    if [[ -z "$out" ]]; then printf 'true'; else printf 'false'; fi
  fi
}
```

Replace the `build)` case with:

```bash
  build)
    resolve_gauntlet_root
    docker build \
      --build-context "gauntlet=$gauntlet_root" \
      --build-arg "QUORUM_IMAGE_EVALS_COMMIT=$(build_source_commit "$evals_root")" \
      --build-arg "QUORUM_IMAGE_CONTAINER_CLEAN=$(build_source_clean "$evals_root" container)" \
      --build-arg "QUORUM_IMAGE_GAUNTLET_COMMIT=$(build_source_commit "$gauntlet_root")" \
      --build-arg "QUORUM_IMAGE_GAUNTLET_CLEAN=$(build_source_clean "$gauntlet_root" .)" \
      -t "$image_tag" \
      -f "$evals_root/container/Dockerfile" \
      "$evals_root"
    ;;
```

In `evals/container/Dockerfile`, insert between the `RUN chmod +x /usr/local/bin/quorum /usr/local/bin/evals-tool-versions` line and `WORKDIR /workspace/evals`:

```dockerfile

# The build source, passed by scripts/evals-container build; quorum records it
# in each run's provenance. Declared after the last RUN, so a new commit
# rebuilds only these metadata layers and none of the install layers.
ARG QUORUM_IMAGE_EVALS_COMMIT=
ARG QUORUM_IMAGE_CONTAINER_CLEAN=
ARG QUORUM_IMAGE_GAUNTLET_COMMIT=
ARG QUORUM_IMAGE_GAUNTLET_CLEAN=
ENV QUORUM_IMAGE_EVALS_COMMIT=$QUORUM_IMAGE_EVALS_COMMIT
ENV QUORUM_IMAGE_CONTAINER_CLEAN=$QUORUM_IMAGE_CONTAINER_CLEAN
ENV QUORUM_IMAGE_GAUNTLET_COMMIT=$QUORUM_IMAGE_GAUNTLET_COMMIT
ENV QUORUM_IMAGE_GAUNTLET_CLEAN=$QUORUM_IMAGE_GAUNTLET_CLEAN
```

In `evals/docs/scenario-authoring.md`, two edits (reflow the paragraph to the file's line width after each):

1. In the Gauntlet identity paragraph, after the sentence that ends "`quorum show` prints them on its `provenance:` line." insert:

   > Inside the evals container, `gauntlet.commit` and `gauntlet.clean` are `null`: the image copies the Gauntlet's `src/` without its `.git`. The identity of record for a container run is the image's, `container_image.gauntlet_commit` and `container_image.gauntlet_clean` in the same `provenance` field: the state of the Gauntlet checkout `scripts/evals-container build` built the image from. `quorum show` appends it to the `provenance:` line as `image <evals> gauntlet <gauntlet>`.

2. In the comparability bullet, replace the sentence "For a container run, that covers the checkout's `container/`, not the image the run used, which may have been built from another state; the image is not recorded." with:

   > For a container run, `container` is the exception: the image holds the `container/` it was built from, so that path is compared at `container_image.evals_commit`, the commit `scripts/evals-container build` recorded, and it is settled only when `container_image.container_clean` is `true`. A container run whose `container_image` fields are `null` (an image built without the launcher) leaves `container` open, so it needs a recorded argument. Every other path is still compared at `evals_commit`, because the checkout is bind-mounted into the container at run time.

- [ ] **Step 4: Run the tests to verify they pass**

Run (EV), each as its own command: `bun test test/evals-container.test.ts`, then `bun run format`, then `git status --short` (only this task's files changed), then `bun run lint`, then `if grep -q 'the image is not recorded' docs/scenario-authoring.md; then echo still-there; else echo gone; fi`.
Expected: all tests pass; lint clean; the last command prints `gone`.

- [ ] **Step 5: Commit**

```bash
git add scripts/evals-container container/Dockerfile docs/scenario-authoring.md test/evals-container.test.ts
git commit -m "feat(container): bake the build source into the image for provenance"
```

---

### Task 3 (evals): The shim parser covers `cd -P`, `cd --`, `pushd` and `cd X;exec`, and never guesses

**Risk tier:** high — decides which checkout a run's Gauntlet identity names.

**Files:**
- Modify: `evals/src/runner/provenance.ts:96-124, 135-160`
- Test: `evals/test/runner-provenance.test.ts`

**Interfaces:**
- Consumes: `ProvenanceDeps` with `env` (Task 1).
- Produces: `export type ShimTarget = { readonly kind: 'target'; readonly path: string } | { readonly kind: 'unresolved' } | null;` and `shimTarget(file: string, deps: ProvenanceDeps): ShimTarget`.

**Mirror:** `evals/test/runner-provenance.test.ts:205-229` (the `/opt/homebrew` trap with a full `gauntlet` `toEqual`).

- [ ] **Step 1: Write the failing tests**

Append to `evals/test/runner-provenance.test.ts` (after the `container image identity` block):

```ts
describe('shim forms', () => {
  const C = 'c'.repeat(40);
  const D = 'd'.repeat(40);
  // /opt/homebrew and /opt are repositories here, so any fallback to the last
  // absolute token, or to the shim's own directory, records the wrong commit.
  const runner = fakeGit({
    '/repos/evals': { head: A, status: '' },
    '/repos/gauntlet': { head: B, status: '' },
    '/repos/tools': { head: D, status: '' },
    '/opt/homebrew': { head: C, status: '' },
    '/opt': { head: C, status: '' },
  });
  const shimAt = (file: string, body: string, extra: Record<string, string | 'dir'> = {}) =>
    captureProvenance(
      deps(
        { runner, pathEntries: [file.slice(0, file.lastIndexOf('/'))] },
        {
          [file]: `#!/bin/sh\n${body}\n`,
          '/repos/gauntlet': 'dir',
          '/opt/homebrew/bin/bun': 'x',
          ...extra,
        },
      ),
    ).gauntlet;
  const resolved = (path: string) => ({
    path,
    checkout: '/repos/gauntlet',
    commit: B,
    clean: true,
  });
  const unresolved = (path: string) => ({ path, checkout: null, commit: null, clean: null });
  const trap = ' && exec /opt/homebrew/bin/bun run src/index.ts "$@"';

  test.each([
    ['cd -P', `cd -P /repos/gauntlet${trap}`],
    ['cd -L -P', `cd -L -P /repos/gauntlet${trap}`],
    ['cd --', `cd -- /repos/gauntlet${trap}`],
    ['pushd', `pushd /repos/gauntlet${trap}`],
    ['cd X;exec', 'cd /repos/gauntlet;exec /opt/homebrew/bin/bun run src/index.ts "$@"'],
  ])('%s names the checkout', (_label, body) => {
    expect(shimAt('/opt/bin/gauntlet', body)).toEqual(resolved('/opt/bin/gauntlet'));
  });

  test.each([
    ['the parent through /..', '/repos/gauntlet/bin/gauntlet', `cd "$(dirname "$0")/.."${trap}`],
    ['the empty suffix', '/repos/gauntlet/bin/gauntlet', `cd "$(dirname "$0")"${trap}`],
    ['BASH_SOURCE', '/repos/gauntlet/bin/gauntlet', `cd "$(dirname "\${BASH_SOURCE[0]}")/.."${trap}`],
    ['the unquoted form', '/repos/gauntlet/bin/gauntlet', `cd $(dirname "$0")/..${trap}`],
    ['another repository', '/repos/tools/bin/gauntlet', `cd "$(dirname "$0")/../../gauntlet"${trap}`],
  ])('a cd built from the shim location resolves exactly: %s', (_label, file, body) => {
    expect(
      shimAt(file, body, { '/repos/gauntlet/bin': 'dir', '/repos/tools/bin': 'dir' }),
    ).toEqual(resolved(file));
  });

  test.each([
    ['a variable', `cd "$HOME/gauntlet"${trap}`],
    ['a relative operand', `cd gauntlet${trap}`],
    ['cd -', `cd -${trap}`],
    ['pushd -n', `pushd -n /repos/gauntlet${trap}`],
    ['a variable suffix', `cd "$(dirname "$0")/$SUB"${trap}`],
    ['a suffix without a leading slash', `cd "$(dirname "$0")suffix"${trap}`],
    ['a nested substitution', `cd "$(dirname "$(readlink -f "$0")")"${trap}`],
  ])('an unresolved cd records no checkout: %s', (_label, body) => {
    expect(shimAt('/opt/bin/gauntlet', body)).toEqual(unresolved('/opt/bin/gauntlet'));
  });
});
```

In the 'empty suffix' case the operand resolves to `/repos/gauntlet/bin`, a directory inside the checkout, so the probe reaches `/repos/gauntlet` through `rev-parse --show-toplevel`; the fake git matches by prefix.

- [ ] **Step 2: Run the tests to verify they fail**

Run (EV): `bun test test/runner-provenance.test.ts`
Expected: FAIL. `cd -P`, `cd -L -P`, `cd --` and `pushd` record the Homebrew commit `ccc…`; `cd X;exec` and the `dirname` forms record `ccc…` or `/opt`; the unresolved cases record `ccc…` instead of nulls.

- [ ] **Step 3: Implement**

In `evals/src/runner/provenance.ts`, add `normalize` to the `node:path` import (`import { dirname, join, normalize } from 'node:path';`) and replace the `shimTarget` comment and function with:

```ts
// A shim's target. On the first line after the shebang (comment lines skipped)
// that holds a cd or pushd segment, or an absolute path token that exists, the
// line decides. Segments split at ; && || and |. A cd's operand skips cd's
// options (-L -P -e -@) up to --; a pushd's operand skips only --, so
// `pushd -n`, which does not change directory, is unresolved. An existing
// absolute operand is the target. An operand built from the shim's own
// location, $(dirname "$0") or $(dirname "${BASH_SOURCE[0]}") with or without
// outer double quotes, plus a suffix that is empty or a literal path starting
// with /, is resolved against the directory of the path found on PATH, which is
// what $0 holds when the shim runs. Any other operand leaves the shim
// unresolved: it records no checkout rather than guess, because a fallback to
// the last absolute token picks up an interpreter such as
// /opt/homebrew/bin/bun, whose directory is itself a git checkout. A line with
// no cd or pushd keeps the older rule: its last existing absolute token. null
// is a file without a shebang (a binary), or a script with neither, and both
// are probed through the file's own directory.
export type ShimTarget =
  | { readonly kind: 'target'; readonly path: string }
  | { readonly kind: 'unresolved' }
  | null;

const CD_OPTIONS = new Set(['-L', '-P', '-e', '-@']);
const SELF_DIR =
  /^("?)\$\(dirname "(?:\$0|\$\{BASH_SOURCE\[0\]\})"\)(\/[^$`'"\s]*)?\1$/;

function unquote(raw: string): string {
  return raw.replace(/^["']+|["']+$/g, '');
}

function cdTarget(
  command: string,
  rest: string,
  shimDir: string,
  deps: ProvenanceDeps,
): ShimTarget {
  let text = rest.trim();
  for (;;) {
    const m = /^(\S+)\s*/.exec(text);
    if (m === null) break;
    const token = m[1] as string;
    if (token === '--') {
      text = text.slice(m[0].length);
      break;
    }
    if (command === 'cd' && CD_OPTIONS.has(token)) {
      text = text.slice(m[0].length);
      continue;
    }
    break;
  }
  text = text.trim();
  const self = SELF_DIR.exec(text);
  if (self !== null) {
    const p = normalize(join(shimDir, self[2] ?? ''));
    return deps.exists(p) ? { kind: 'target', path: p } : { kind: 'unresolved' };
  }
  const operand = unquote(text.split(/\s+/)[0] ?? '');
  if (operand.startsWith('/') && deps.exists(operand)) {
    return { kind: 'target', path: operand };
  }
  return { kind: 'unresolved' };
}

export function shimTarget(file: string, deps: ProvenanceDeps): ShimTarget {
  const text = deps.readFile(file);
  if (text === null || !text.startsWith('#!')) return null;
  for (const line of text.split('\n').slice(1)) {
    if (line.trimStart().startsWith('#')) continue;
    let last: string | null = null;
    for (const segment of line.split(/&&|\|\||;|\|/)) {
      const cd = /^\s*(cd|pushd)(?:\s+(.*))?$/.exec(segment);
      if (cd !== null) {
        return cdTarget(cd[1] as string, cd[2] ?? '', dirname(file), deps);
      }
      for (const raw of segment.split(/\s+/)) {
        const token = unquote(raw);
        if (token.startsWith('/') && deps.exists(token)) last = token;
      }
    }
    if (last !== null) return { kind: 'target', path: last };
  }
  return null;
}
```

In `captureProvenance`, replace the block from `const target = shimTarget(found, deps);` through the end of the `if (checkout !== null) { ... }` block with:

```ts
    const target = shimTarget(found, deps);
    // An unresolved shim records its path and nothing else: probing its own
    // directory instead is how an interpreter's checkout gets recorded.
    if (target === null || target.kind === 'target') {
      // A directory token (cd <checkout>) is queried itself; a file token or
      // the binary itself through its directory.
      const probeDir =
        target === null
          ? dirname(found)
          : deps.isDirectory(target.path)
            ? target.path
            : dirname(target.path);
      const checkout = toplevelOf(deps.runner, probeDir);
      if (checkout !== null) {
        gauntlet.checkout = checkout;
        // A gauntlet inside the evals repository (the test suite's mock is one)
        // carries the evals values: a second, whole-tree walk of the same
        // repository is the cost HARNESS_PATHS exists to avoid.
        if (checkout === toplevelOf(deps.runner, deps.evalsRoot)) {
          gauntlet.commit = evalsCommit;
          gauntlet.clean = evalsClean;
        } else {
          gauntlet.commit = commitOf(deps.runner, checkout);
          gauntlet.clean = cleanOf(deps.runner, checkout);
        }
      }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (EV), each as its own command: `bun test test/runner-provenance.test.ts`, `bun run typecheck`, `bun run format`, `git status --short` (only this task's files changed), `bun run lint`.
Expected: all pass, including every pre-existing case (the in-repo mock at line 349 still resolves to `/repos/evals`).

- [ ] **Step 5: Commit**

```bash
git add src/runner/provenance.ts test/runner-provenance.test.ts
git commit -m "fix(provenance): resolve more shim forms and record unknown instead of guessing"
```

---

### Task 4 (evals): `writePhase` replaces `phase.json` atomically

**Risk tier:** high — concurrency between the runner's writer and the dashboard's reader.

**Files:**
- Modify: `evals/src/runner/phase.ts:1-20`
- Test: `evals/test/runner-phase.test.ts`

**Interfaces:**
- Produces: `export interface PhaseFs { readonly writeFileSync: (path: string, data: string) => void; readonly renameSync: (from: string, to: string) => void; readonly rmSync: (path: string, options: { force: boolean }) => void; }` and `writePhase(runDir: string, phase: RunPhase, fs?: PhaseFs): void`.

**Mirror:** `evals/test/runner-phase.test.ts:7-15`.

- [ ] **Step 1: Write the failing tests**

Replace the imports of `evals/test/runner-phase.test.ts`, add `expect(readdirSync(dir).filter((n) => n.startsWith('phase.json.tmp-'))).toEqual([]);` as the last line of the existing test (the plain real-filesystem case), and add two tests after it:

```ts
import { expect, test } from 'bun:test';
import {
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join } from 'node:path';
import { type PhaseFs, writePhase } from '../src/runner/phase.ts';
```

```ts
test('writePhase writes a temporary file and renames it over phase.json, never writing phase.json itself', () => {
  const dir = mkdtempSync(join(tmpdir(), 'phase-'));
  try {
    const ops: string[] = [];
    const recording: PhaseFs = {
      writeFileSync: (p, data) => {
        ops.push(`write ${basename(p)}`);
        writeFileSync(p, data);
      },
      renameSync: (from, to) => {
        ops.push(`rename ${basename(from)} ${basename(to)}`);
        renameSync(from, to);
      },
      rmSync: (p, options) => {
        ops.push(`rm ${basename(p)}`);
        rmSync(p, options);
      },
    };
    writePhase(dir, 'checks', recording);
    const tmp = `phase.json.tmp-${process.pid}`;
    expect(ops).toEqual([`write ${tmp}`, `rename ${tmp} phase.json`]);
    expect(JSON.parse(readFileSync(join(dir, 'phase.json'), 'utf8')).phase).toBe('checks');
    expect(readdirSync(dir).filter((n) => n.startsWith('phase.json.tmp-'))).toEqual([]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a failed rename leaves the previous phase.json, removes the temporary file and rethrows', () => {
  const dir = mkdtempSync(join(tmpdir(), 'phase-'));
  try {
    writePhase(dir, 'agent');
    const before = readFileSync(join(dir, 'phase.json'), 'utf8');
    const failing: PhaseFs = {
      writeFileSync,
      renameSync: () => {
        throw new Error('rename failed');
      },
      rmSync,
    };
    expect(() => writePhase(dir, 'checks', failing)).toThrow('rename failed');
    expect(readFileSync(join(dir, 'phase.json'), 'utf8')).toBe(before);
    expect(readdirSync(dir).filter((n) => n.startsWith('phase.json.tmp-'))).toEqual([]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (EV): `bun test test/runner-phase.test.ts`
Expected: FAIL. `PhaseFs` is not exported (typecheck error under bun's transpile is silent, so the failure is at runtime): the recording case sees no operations because `writePhase` ignores its third argument and writes `phase.json` directly, and the failing-rename case does not throw.

- [ ] **Step 3: Implement**

Replace `evals/src/runner/phase.ts` with:

```ts
import { renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// The live phase vocabulary the runner owns. `grade` is intentionally absent
// (build spec: the gauntlet event stream carries no grade-start marker; done is
// signalled by verdict.json appearing, not a phase).
export type RunPhase = 'setup' | 'agent' | 'checks';

// The three filesystem calls writePhase makes, injectable so a test can watch
// the order and fail the rename.
export interface PhaseFs {
  readonly writeFileSync: (path: string, data: string) => void;
  readonly renameSync: (from: string, to: string) => void;
  readonly rmSync: (path: string, options: { force: boolean }) => void;
}

const NODE_FS: PhaseFs = { writeFileSync, renameSync, rmSync };

// Write <runDir>/phase.json at a boundary the runner owns. `pid` is the
// `quorum run` process id; the dashboard uses it for liveness (phase mtime is
// not a liveness signal — a phase can last tens of minutes). The file stops
// updating once verdict.json is written (verdict.json is the done signal).
// The new phase goes to a temporary file that is renamed over phase.json: a
// direct write truncates first, and the dashboard reading that empty or
// partial file took the run for finished. A failed rename leaves the previous
// phase in place and rethrows, as a failed write always did.
export function writePhase(
  runDir: string,
  phase: RunPhase,
  fs: PhaseFs = NODE_FS,
): void {
  const body = {
    phase,
    updated_at: new Date().toISOString(),
    pid: process.pid,
  };
  const target = join(runDir, 'phase.json');
  const tmp = join(runDir, `phase.json.tmp-${process.pid}`);
  fs.writeFileSync(tmp, `${JSON.stringify(body)}\n`);
  try {
    fs.renameSync(tmp, target);
  } catch (err: unknown) {
    try {
      fs.rmSync(tmp, { force: true });
    } catch {
      // Best effort: the rename's error is the one worth reporting.
    }
    throw err;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (EV), each as its own command: `bun test test/runner-phase.test.ts test/dashboard-server.test.ts`, `bun run typecheck`, `bun run format`, `git status --short` (only this task's files changed), `bun run lint`.
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/runner/phase.ts test/runner-phase.test.ts
git commit -m "fix(runner): replace phase.json atomically so a reader never sees a partial file"
```

---

### Task 5 (evals): The dashboard trusts a verdict only after its writer exits

**Risk tier:** high — the read-side authority rule over the run directory, concurrent with the runner.

**Files:**
- Modify: `evals/src/dashboard/scan.ts:74-126, 136-141`
- Modify: `evals/src/dashboard/contracts.ts:38-45, 72`
- Test: `evals/test/dashboard-scan.test.ts:68-90, 194-204`

**Interfaces:**
- Consumes: `pidAlive` (unchanged), `PhaseJsonSchema` (unchanged).
- Produces: `readDashboardVerdict(runDir: string): DashboardVerdict | null` with the new rule (signature unchanged).

**Mirror:** `evals/test/dashboard-scan.test.ts:194-214` (authority and abandoned cases over `writeRun`).

- [ ] **Step 1: Write the failing tests**

In `evals/test/dashboard-scan.test.ts`, after 'readDashboardVerdict returns null for unparseable JSON', add:

```ts
test('readDashboardVerdict: a verdict beside a live pid reads null and is not cached; the one on disk after the writer exits is what reads', () => {
  const dir = mkdtempSync(join(tmpdir(), 'verdict-'));
  writeFileSync(
    join(dir, 'phase.json'),
    JSON.stringify({ phase: 'agent', updated_at: 'x', pid: process.pid }),
  );
  writeFileSync(join(dir, 'verdict.json'), JSON.stringify({ final: 'pass' }));
  expect(readDashboardVerdict(dir)).toBeNull();
  writeFileSync(
    join(dir, 'phase.json'),
    JSON.stringify({ phase: 'checks', updated_at: 'x', pid: 2147483646 }),
  );
  writeFileSync(join(dir, 'verdict.json'), JSON.stringify({ final: 'fail' }));
  expect(readDashboardVerdict(dir)?.final).toBe('fail');
});

test('readDashboardVerdict: a phase file that exists but cannot be read is never taken as a finished run', () => {
  for (const body of ['', '{"phase":"agent"']) {
    const dir = mkdtempSync(join(tmpdir(), 'verdict-'));
    writeFileSync(join(dir, 'phase.json'), body);
    writeFileSync(join(dir, 'verdict.json'), JSON.stringify({ final: 'pass' }));
    expect(readDashboardVerdict(dir)).toBeNull();
    writeFileSync(
      join(dir, 'phase.json'),
      JSON.stringify({ phase: 'checks', updated_at: 'x', pid: 2147483646 }),
    );
    expect(readDashboardVerdict(dir)?.final).toBe('pass');
  }
});
```

Replace the test 'AUTHORITY RULE: verdict present means phase.json is ignored (not running)' (lines 194-204) with:

```ts
test('AUTHORITY RULE: a verdict beside a live pid is not trusted; the run shows as running', () => {
  const root = mkdtempSync(join(tmpdir(), 'res-'));
  writeRun(root, 's-claude-20260612T000000Z-aaaa', {
    verdict: { final: 'pass', economics: { total_est_cost_usd: 1 } },
    phase: { phase: 'agent', updated_at: 'x', pid: process.pid },
  });
  const cell = scanResults(root, AGENTS).cells.get(cellKey('s', 'claude'));
  expect(cell?.running?.phase).toBe('agent');
  expect(cell?.window.length).toBe(0);
});

test('AUTHORITY RULE: once the phase pid is dead, the verdict is the record', () => {
  const root = mkdtempSync(join(tmpdir(), 'res-'));
  writeRun(root, 's-claude-20260612T000000Z-aaaa', {
    verdict: { final: 'pass', economics: { total_est_cost_usd: 1 } },
    phase: { phase: 'checks', updated_at: 'x', pid: 2147483646 },
  });
  const cell = scanResults(root, AGENTS).cells.get(cellKey('s', 'claude'));
  expect(cell?.running).toBeNull();
  expect(cell?.window.length).toBe(1);
  expect(cell?.window[0]?.final).toBe('pass');
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (EV): `bun test test/dashboard-scan.test.ts`
Expected: FAIL. The live-pid verdict reads `pass` (and is cached, so the second read also returns `pass`, not `fail`); the unreadable-phase verdict reads `pass`; the first AUTHORITY RULE case shows a record and no running run.

- [ ] **Step 3: Implement**

In `evals/src/dashboard/scan.ts`, replace lines 74-126 (the cache comment through the end of `readPhase`) with:

```ts
// A verdict is trusted only once the process that writes it has exited: the
// Coding-Agent can write the run dir, so a verdict.json that appears while
// phase.json names a live pid may not be quorum's. A verdict read after that is
// final, so a path-keyed cache of it never has to invalidate. Absence is
// transient (a live dir has no trusted verdict yet), so a miss is never cached;
// caching null would pin a live dir as verdict-less forever and break the
// running -> done transition the scanner drives.
const _verdictCache = new Map<string, DashboardVerdict>();

// Cached read of <runDir>/verdict.json narrowed to the read-side view. Returns
// null while the run may still be writing it (phase.json names a live pid, or
// exists and cannot be read) and when the file is missing, unreadable or
// unparseable; only a returned verdict is cached.
export function readDashboardVerdict(runDir: string): DashboardVerdict | null {
  const cached = _verdictCache.get(runDir);
  if (cached !== undefined) {
    return cached;
  }
  const phase = readPhaseFile(runDir);
  if (phase.kind === 'unreadable') {
    return null;
  }
  if (phase.kind === 'phase' && pidAlive(phase.pid)) {
    return null;
  }
  const result = parseDashboardVerdict(join(runDir, 'verdict.json'));
  if (result !== null) {
    _verdictCache.set(runDir, result);
  }
  return result;
}

function parseDashboardVerdict(path: string): DashboardVerdict | null {
  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return null;
  }
  const parsed = DashboardVerdictSchema.safeParse(raw);
  return parsed.success ? parsed.data : null;
}

// A run dir's phase.json: absent, present but unreadable (bad JSON, a missing
// pid, a file caught mid-write), or a phase with its writer's pid. Absent and
// unreadable differ for the verdict: a run dir from before the phase file has
// none, while an unreadable one may belong to a run still in flight.
type PhaseRead =
  | { readonly kind: 'absent' }
  | { readonly kind: 'unreadable' }
  | { readonly kind: 'phase'; readonly phase: string; readonly pid: number };

function readPhaseFile(runDir: string): PhaseRead {
  const path = join(runDir, 'phase.json');
  if (!existsSync(path)) {
    return { kind: 'absent' };
  }
  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return { kind: 'unreadable' };
  }
  const parsed = PhaseJsonSchema.safeParse(raw);
  return parsed.success
    ? { kind: 'phase', phase: parsed.data.phase, pid: parsed.data.pid }
    : { kind: 'unreadable' };
}

// A run dir's live phase.json, narrowed, or null when missing or unreadable;
// the caller treats null as no live phase (abandoned).
function readPhase(runDir: string): { phase: string; pid: number } | null {
  const read = readPhaseFile(runDir);
  return read.kind === 'phase' ? { phase: read.phase, pid: read.pid } : null;
}
```

Replace the `scanResults` header comment (lines 136-141) with:

```ts
// Enumerate results/, skip batches/, bucket by (scenario, agent), window to the
// 5 newest by (started_at, nonce) (newest rightmost). For each windowed dir: a
// trusted verdict ⇒ a RunRecord (readDashboardVerdict trusts one only after
// phase.json's pid has exited); otherwise a live pid ⇒ the cell's `running`
// (only the newest live dir wins); otherwise abandoned (excluded). Cells with
// no displayable run are omitted from the Grid.
```

In `evals/src/dashboard/contracts.ts`, replace the `DashboardVerdictSchema` comment (lines 38-45) with:

```ts
// The narrow read-side view of verdict.json — only the fields the grid needs.
// Every field is `.catch`-guarded so a single wrong-typed field never sinks the
// whole parse: a malformed/legacy/externally-edited verdict still reads as a
// PRESENT verdict once its run is over (scan.ts trusts a verdict only after the
// process phase.json names has exited). A non-string `final` degrades to
// undefined (the read-side then collapses it to 'unknown'); a non-number cost
// degrades to null (rendered "cost unknown", never $0).
```

and the `RunningRun` comment (line 72) with:

```ts
// An in-flight run: a dir whose phase.json names a live pid, whatever else it
// holds; a verdict there is not trusted until that process exits.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (EV), each as its own command: `bun test test/dashboard-scan.test.ts test/dashboard-server.test.ts`, `bun run typecheck`, `bun run format`, `git status --short` (only this task's files changed), `bun run lint`.
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/dashboard/scan.ts src/dashboard/contracts.ts test/dashboard-scan.test.ts
git commit -m "fix(dashboard): trust a verdict only after the run's process has exited"
```

---

### Task 6 (evals): One shared Codex approve-stub for the eight brainstorming scenarios

**Risk tier:** high — the stub's output is what the approach and spec gates consume in eight scenarios, seven of them controls of record.

**Files:**
- Create: `evals/fixtures/codex-stubs/approve-companion.mjs`
- Create: `evals/src/setup-helpers/codex-approve-stub.ts`
- Create: `evals/test/codex-stub-cases.ts`
- Create: `evals/test/fixtures/codex-approve-stub-golden.json` (recorded, Step 2)
- Modify: `evals/src/setup-helpers/codex-seed.ts:22, 211` (export two helpers)
- Modify: `evals/src/setup-helpers/registry.ts:120-135`
- Modify: the eight `evals/scenarios/brainstorming-*/setup.sh` files named in Grounding
- Modify: `evals/test/scenario-brainstorming-tooling-question.test.ts:18-23, 70-81` (the spec's file list missed this test: it reads the stub out of the tooling-question `setup.sh` heredoc)
- Rewrite: `evals/test/scenario-codex-stub-task.test.ts`

**Interfaces:**
- Produces: `seedCodexApproveStub(ctx: HelperContext): void` (registry name `seed_codex_approve_stub`); `export function agentHomeFromWorkdir(workdir: string): string` and `export function registryJson(installPath: string): string` from `codex-seed.ts`; `runStubCases(stubFile: string): StubCase[]` and `interface StubCase { name: string; status: number | null; stdout: string; stderr: string; log: string; jobs: Record<string, string> }` from `test/codex-stub-cases.ts`.
- Consumes: `repoRoot()` from `src/paths.ts`.

**Mirror:** `evals/src/setup-helpers/codex-seed.ts:232-259` (helper shape), `evals/test/setup-helpers-codex-seed.test.ts:16-42` (helper test), `evals/test/provision-helpers.ts:1-30` (a helper module under `test/`).

- [ ] **Step 1: Write the case runner**

Create `evals/test/codex-stub-cases.ts`:

```ts
import { spawnSync } from 'node:child_process';
import {
  copyFileSync,
  existsSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// One observation of the approve-stub: what its last call printed and exited
// with, and what the case's calls left beside it (calls.log and .jobs/). The
// golden file records these for the stub as it stood in the eight setup.sh
// heredocs; the shared fixture must reproduce every one. Each case runs in its
// own directory, whose path is replaced by <DIR> so the record is portable.
export interface StubCase {
  readonly name: string;
  readonly status: number | null;
  readonly stdout: string;
  readonly stderr: string;
  readonly log: string;
  readonly jobs: Record<string, string>;
}

// One prompt per branch of the stub's classify().
const PROMPTS = {
  approaches:
    'Read approach-context.md and return Approaches (2-3, each genuinely different).',
  'plan-review': 'Review the implementation plan at /tmp/x/plan.md against the spec.',
  'spec-review':
    'Review the spec document at /tmp/x/2026-01-01-foo-design.md for completeness.',
  'document-review': 'Review the document at /tmp/x/notes.md and report.',
} as const;
type Kind = keyof typeof PROMPTS;

function promptFile(dir: string, kind: Kind): string {
  const file = join(dir, `${kind}.prompt.md`);
  writeFileSync(file, PROMPTS[kind]);
  return file;
}

function emptyFile(dir: string): string {
  const file = join(dir, 'empty.prompt.md');
  writeFileSync(file, '');
  return file;
}

const ZEROS = '0'.repeat(40);
const CASES: ReadonlyArray<{
  readonly name: string;
  readonly calls: (dir: string) => string[][];
}> = [
  { name: 'setup --json', calls: () => [['setup', '--json']] },
  ...(Object.keys(PROMPTS) as Kind[]).flatMap((kind) => [
    {
      name: `task ${kind}`,
      calls: (d: string) => [['task', '--fresh', '--prompt-file', promptFile(d, kind)]],
    },
    {
      name: `task ${kind} --json`,
      calls: (d: string) => [
        ['task', '--fresh', '--prompt-file', promptFile(d, kind), '--json'],
      ],
    },
  ]),
  {
    name: 'task with a missing prompt file',
    calls: (d) => [['task', '--fresh', '--prompt-file', join(d, 'missing.prompt.md')]],
  },
  {
    name: 'task with an empty prompt file',
    calls: (d) => [['task', '--fresh', '--prompt-file', emptyFile(d)]],
  },
  { name: 'task with no prompt', calls: () => [['task', '--fresh']] },
  { name: 'task-reviewer', calls: () => [['task-reviewer', '--json']] },
  { name: 'review', calls: () => [['review', '--json']] },
  {
    name: 'adversarial-review',
    calls: () => [['adversarial-review', '--base', ZEROS, '--json', 'focus']],
  },
  { name: 'status --json', calls: () => [['status', '--json']] },
  {
    name: 'status <id> after a review',
    calls: () => [
      ['adversarial-review', '--base', ZEROS, '--json', 'focus'],
      ['status', 'cxc-stub-1', '--json'],
    ],
  },
  { name: 'status <unknown id>', calls: () => [['status', 'cxc-stub-9', '--json']] },
  {
    name: 'result <id> after a review',
    calls: () => [
      ['adversarial-review', '--base', ZEROS, '--json', 'focus'],
      ['result', 'cxc-stub-1', '--json'],
    ],
  },
  { name: 'result <unknown id>', calls: () => [['result', 'cxc-stub-9', '--json']] },
  { name: 'an unknown subcommand', calls: () => [['frobnicate']] },
];

export function runStubCases(stubFile: string): StubCase[] {
  return CASES.map((c) => {
    const dir = mkdtempSync(join(tmpdir(), 'codex-stub-case-'));
    try {
      const stub = join(dir, 'codex-companion.mjs');
      copyFileSync(stubFile, stub);
      let last = { status: null as number | null, stdout: '', stderr: '' };
      for (const args of c.calls(dir)) {
        const r = spawnSync('node', [stub, ...args], { encoding: 'utf8' });
        last = { status: r.status, stdout: r.stdout, stderr: r.stderr };
      }
      // The stub may see its own path through the real path (macOS /private).
      const portable = (s: string) =>
        s.split(realpathSync(dir)).join('<DIR>').split(dir).join('<DIR>');
      const logFile = join(dir, 'calls.log');
      const jobsDir = join(dir, '.jobs');
      const jobs: Record<string, string> = {};
      if (existsSync(jobsDir)) {
        for (const f of readdirSync(jobsDir).sort()) {
          jobs[f] = portable(readFileSync(join(jobsDir, f), 'utf8'));
        }
      }
      return {
        name: c.name,
        status: last.status,
        stdout: portable(last.stdout),
        stderr: portable(last.stderr),
        log: existsSync(logFile) ? portable(readFileSync(logFile, 'utf8')) : '',
        jobs,
      };
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}
```

- [ ] **Step 2: Record the golden values from the stub as it stands**

Confirm the seven ported heredocs are byte-identical, then record from one of them. Write `/Users/johnss51/.cache/hyperpowers/post-release-follow-ups/record-golden.sh`:

```bash
#!/usr/bin/env bash
# Extracts each ported heredoc stub, requires all seven to match, and records
# the golden behaviour from that one stub.
set -euo pipefail
ev=/Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/post-release-follow-ups
out=/Users/johnss51/.cache/hyperpowers/post-release-follow-ups
for s in brainstorming-bounded-fires-approach-gate brainstorming-router-escalates-b1-userid-param \
         brainstorming-router-escalates-b2-config-module brainstorming-router-escalates-b3-logging \
         brainstorming-router-escalates-b4-reusable-validation brainstorming-router-escalates-b5-prefs-storage \
         brainstorming-router-no-downgrade; do
  awk '/codex-companion\.mjs" <<.STUB.$/{f=1;next} /^STUB$/{f=0} f' "$ev/scenarios/$s/setup.sh" > "$out/heredoc-$s.mjs"
done
distinct="$(shasum "$out"/heredoc-*.mjs | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"
[ "$distinct" = 1 ] || { echo "the seven ported stubs differ ($distinct distinct)"; exit 1; }
cp "$out/heredoc-brainstorming-router-no-downgrade.mjs" "$out/heredoc-stub.mjs"
cat > "$out/record-golden.ts" <<EOF
import { writeFileSync } from 'node:fs';
import { runStubCases } from '$ev/test/codex-stub-cases.ts';
writeFileSync('$ev/test/fixtures/codex-approve-stub-golden.json', \`\${JSON.stringify(runStubCases('$out/heredoc-stub.mjs'), null, 2)}\n\`);
EOF
bun run "$out/record-golden.ts"
echo "recorded"
```

Run: `bash /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/record-golden.sh`
Expected: `recorded`, and `test/fixtures/codex-approve-stub-golden.json` exists in EV with 21 cases. Check: `node -e 'const g=require(process.argv[1]);console.log(g.length, g.find(c=>c.name==="task with no prompt").status, JSON.stringify(g.find(c=>c.name==="setup --json").log))' "$PWD/test/fixtures/codex-approve-stub-golden.json"` prints `21 2 ""`.

- [ ] **Step 3: Write the failing tests**

Replace `evals/test/scenario-codex-stub-task.test.ts` with:

```ts
import { expect, test } from 'bun:test';
import { spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { seedCodexApproveStub } from '../src/setup-helpers/codex-approve-stub.ts';
import { runStubCases, type StubCase } from './codex-stub-cases.ts';

// Eight brainstorming scenarios install one Codex companion stub,
// fixtures/codex-stubs/approve-companion.mjs, through the
// seed_codex_approve_stub setup-helper. Before, each carried its own 210-line
// heredoc copy. The golden file records every behaviour of the copy the seven
// ported scenarios shared; the fixture must reproduce each one, so moving the
// stub changed nothing a session can observe.

const EVALS = resolve(import.meta.dir, '..');
const FIXTURE = join(EVALS, 'fixtures', 'codex-stubs', 'approve-companion.mjs');
const GOLDEN = join(import.meta.dir, 'fixtures', 'codex-approve-stub-golden.json');
const SCENARIOS = [
  'brainstorming-asks-tooling-question',
  'brainstorming-bounded-fires-approach-gate',
  'brainstorming-router-escalates-b1-userid-param',
  'brainstorming-router-escalates-b2-config-module',
  'brainstorming-router-escalates-b3-logging',
  'brainstorming-router-escalates-b4-reusable-validation',
  'brainstorming-router-escalates-b5-prefs-storage',
  'brainstorming-router-no-downgrade',
];

const observed = runStubCases(FIXTURE);
const byName = new Map(observed.map((c) => [c.name, c]));

test('the shared stub is valid JavaScript', () => {
  const r = spawnSync('node', ['--check', FIXTURE], { encoding: 'utf8' });
  expect(r.stderr).toBe('');
  expect(r.status).toBe(0);
});

test('the shared stub reproduces every recorded behaviour of the stub it replaced', () => {
  const golden = JSON.parse(readFileSync(GOLDEN, 'utf8')) as StubCase[];
  expect(golden.length).toBe(21);
  expect(observed).toEqual(golden);
});

test('a task call without a prompt fails instead of approving, and setup is never logged', () => {
  for (const name of [
    'task with a missing prompt file',
    'task with an empty prompt file',
    'task with no prompt',
  ]) {
    expect(byName.get(name)?.status).toBe(2);
    expect(byName.get(name)?.stdout).toBe('');
    expect(byName.get(name)?.log).toContain(' kind=no-prompt ');
  }
  expect(byName.get('setup --json')?.log).toBe('');
  expect(byName.get('task approaches')?.log).toContain('task kind=approaches ');
  expect(byName.get('task spec-review')?.log).toContain('task kind=spec-review ');
});

test('seed_codex_approve_stub installs the fixture, the manifest and the registry under the agent home', () => {
  const runDir = mkdtempSync(join(tmpdir(), 'approve-stub-'));
  try {
    const workdir = join(runDir, 'coding-agent-workdir');
    const home = join(runDir, 'home');
    mkdirSync(workdir, { recursive: true });
    mkdirSync(home, { recursive: true });
    seedCodexApproveStub({
      workdir,
      templateDir: undefined,
      superpowersRoot: undefined,
      run: { run: () => ({ status: 0, stdout: '', stderr: '' }) },
    });
    const install = join(home, '.claude', 'plugins', 'cache', 'openai-codex', 'codex', 'stub');
    const companion = join(install, 'scripts', 'codex-companion.mjs');
    expect(readFileSync(companion, 'utf8')).toBe(readFileSync(FIXTURE, 'utf8'));
    expect(statSync(companion).mode & 0o777).toBe(0o755);
    expect(readFileSync(join(install, '.claude-plugin', 'plugin.json'), 'utf8')).toBe(
      '{ "name": "codex", "version": "0.0.0-stub" }\n',
    );
    expect(readFileSync(join(home, '.claude', 'plugins', 'installed_plugins.json'), 'utf8')).toBe(
      `${JSON.stringify(
        {
          version: 2,
          plugins: {
            'codex@openai-codex': [
              {
                scope: 'user',
                installPath: install,
                version: 'stub',
                installedAt: '2026-01-01T00:00:00.000Z',
                lastUpdated: '2026-01-01T00:00:00.000Z',
              },
            ],
          },
        },
        null,
        2,
      )}\n`,
    );
  } finally {
    rmSync(runDir, { recursive: true, force: true });
  }
});

test('each of the eight scenarios installs the shared stub through the helper and carries no copy of it', () => {
  for (const s of SCENARIOS) {
    const setup = readFileSync(join(EVALS, 'scenarios', s, 'setup.sh'), 'utf8');
    expect(setup).toContain('setup-helpers run seed_codex_approve_stub');
    expect(setup).not.toContain('codex-companion.mjs');
  }
});
```

- [ ] **Step 4: Run the tests to verify they fail**

Run (EV): `bun test test/scenario-codex-stub-task.test.ts`
Expected: FAIL to load: `src/setup-helpers/codex-approve-stub.ts` and the fixture do not exist yet.

- [ ] **Step 5: Create the fixture**

Copy the recorded heredoc stub: `cp /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/heredoc-stub.mjs fixtures/codex-stubs/approve-companion.mjs` (EV; `mkdir -p fixtures/codex-stubs` first). Then change exactly two comment blocks.

Replace lines 2-6 (the header, from `// Deterministic stub: task-reviewer and Codex gate always APPROVE (no findings).` through `// Seeded by hyperpowers-evals brainstorming-router scenarios.`) with:

```js
// Deterministic stub of codex-plugin-cc's codex-companion.mjs for the
// brainstorming scenarios, installed by the seed_codex_approve_stub
// setup-helper. Real Codex is never invoked.
//   setup                     -> ready
//   task                      -> the approach, spec and plan gates' call: a
//                                canned Approaches block or an approving
//                                document review, chosen from the prompt;
//                                exit 2 when no prompt arrived
//   task-reviewer, review,
//   adversarial-review        -> approve with no findings, and a completed
//                                job record under .jobs/
//   status, result            -> the job protocol over .jobs/
// Every call except `setup` is appended to calls.log beside this file, so a
// check can prove which gates fired.
```

Replace the five comment lines above `const APPROACHES` (from `// The approach gate's output shape, from skills/brainstorming/codex-approach-gate.md.` through `// not one about its own domain, so a session may discard these approaches.`) with:

```js
// The approach gate's output shape, from skills/brainstorming/codex-approach-gate.md.
// Domain-neutral on purpose: a scenario needs a well-formed gate answer, not
// one about its own domain, so a session may discard these approaches.
```

The rest of the file stays byte for byte; the spec's "body verbatim" covers its code, and these two comments described the eight-copy arrangement this task removes. Verify that only comment lines changed (EV):

```bash
diff <(grep -v '^[[:space:]]*//' /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/heredoc-stub.mjs) <(grep -v '^[[:space:]]*//' fixtures/codex-stubs/approve-companion.mjs) && echo code-identical
```

Expected: `code-identical`.

- [ ] **Step 6: Implement the helper and register it**

In `evals/src/setup-helpers/codex-seed.ts`, export the two helpers: change `function agentHomeFromWorkdir(` to `export function agentHomeFromWorkdir(` and `function registryJson(` to `export function registryJson(`.

Create `evals/src/setup-helpers/codex-approve-stub.ts`:

```ts
// Install the shared Codex approve-stub (fixtures/codex-stubs/approve-companion.mjs)
// into the coding agent's throwaway home, for the brainstorming scenarios whose
// approach and spec gates call the companion's `task` subcommand. The stub
// lived as a heredoc copy in each of eight setup.sh files; one fixture keeps
// the copies from drifting. Same install layout and registry as
// seed_codex_plugin_cc (codex-seed.ts), whose stub answers code-review gates
// instead.
import { chmodSync, copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { repoRoot } from '../paths.ts';
import { agentHomeFromWorkdir, registryJson } from './codex-seed.ts';
import type { HelperContext } from './context.ts';

const STUB = join(repoRoot(), 'fixtures', 'codex-stubs', 'approve-companion.mjs');

// Dispatchable as `setup-helpers run seed_codex_approve_stub`. Layers onto an
// existing fixture (home-relative writes only; no git init).
export function seedCodexApproveStub(ctx: HelperContext): void {
  const pluginsDir = join(agentHomeFromWorkdir(ctx.workdir), '.claude', 'plugins');
  const installPath = join(pluginsDir, 'cache', 'openai-codex', 'codex', 'stub');
  const scriptsDir = join(installPath, 'scripts');
  mkdirSync(scriptsDir, { recursive: true });
  const companion = join(scriptsDir, 'codex-companion.mjs');
  copyFileSync(STUB, companion);
  chmodSync(companion, 0o755);
  mkdirSync(join(installPath, '.claude-plugin'), { recursive: true });
  writeFileSync(
    join(installPath, '.claude-plugin', 'plugin.json'),
    '{ "name": "codex", "version": "0.0.0-stub" }\n',
    'utf8',
  );
  writeFileSync(join(pluginsDir, 'installed_plugins.json'), registryJson(installPath), 'utf8');
}
```

In `evals/src/setup-helpers/registry.ts`, import it next to the `seedCodexPluginCc` import (`import { seedCodexApproveStub } from './codex-approve-stub.ts';`), add the entry after `seed_codex_plugin_cc: { fn: seedCodexPluginCc },`:

```ts
  seed_codex_approve_stub: { fn: seedCodexApproveStub },
```

and update both count comments, which already disagree with the table before this change: in the header comment (lines 1-5), `Holds only the 36` becomes `Holds only the 37` and `full 38-name set` becomes `full 39-name set`; in the comment above `KNOWN_HELPER_NAMES`, `(37) — the 35 dispatchable plus the` becomes `(39) — the 37 dispatchable plus the`.

- [ ] **Step 7: Point the eight scenarios at the helper**

In each of the eight `setup.sh` files, delete from the `# Seed stub codex-plugin-cc` line to the end of the file (the ranges in Grounding) and append:

```bash
# Seed the stub codex-plugin-cc (fixtures/codex-stubs/approve-companion.mjs) so
# the approach and spec gates can fire if the agent reaches them.
setup-helpers run seed_codex_approve_stub
```

- [ ] **Step 8: Point the tooling-question oracle at the fixture**

In `evals/test/scenario-brainstorming-tooling-question.test.ts`, replace `stubSource()` (lines 70-81) with:

```ts
/**
 * The seeded Codex stub: the fixture the scenario's setup.sh installs through
 * seed_codex_approve_stub. Failing when setup.sh stops naming the helper keeps
 * this oracle tied to what the scenario actually installs.
 */
function stubSource(): string {
  const setup = readFileSync(join(SCENARIO, 'setup.sh'), 'utf8');
  if (!setup.includes('setup-helpers run seed_codex_approve_stub')) {
    throw new Error('setup.sh no longer installs the shared Codex stub');
  }
  return readFileSync(
    resolve(import.meta.dir, '..', 'fixtures', 'codex-stubs', 'approve-companion.mjs'),
    'utf8',
  );
}
```

and in the header comment (lines 18-23) replace "Every case below runs the scenario's own stub and evaluates the scenario's own check strings, both read out of the scenario files rather than restated here, so this test fails if either drifts." with "Every case below runs the stub the scenario installs and evaluates the scenario's own check strings, both read from the files the scenario uses rather than restated here, so this test fails if either drifts."

- [ ] **Step 9: Run the tests to verify they pass**

Run (EV), each as its own command: `bun test test/scenario-codex-stub-task.test.ts test/scenario-brainstorming-tooling-question.test.ts test/setup-helpers-codex-seed.test.ts test/setup-helpers-registry.test.ts`, `bun run quorum check`, `bun run typecheck`, `bun run format`, `git status --short` (only this task's files changed; biome does not format the `.mjs` fixture, which sits outside its `files.includes`), `bun run lint`.
Expected: all pass; `quorum check` reports every scenario valid.

- [ ] **Step 10: Commit**

```bash
git add fixtures/codex-stubs/approve-companion.mjs src/setup-helpers/codex-approve-stub.ts src/setup-helpers/codex-seed.ts src/setup-helpers/registry.ts test/codex-stub-cases.ts test/fixtures/codex-approve-stub-golden.json test/scenario-codex-stub-task.test.ts test/scenario-brainstorming-tooling-question.test.ts scenarios/brainstorming-asks-tooling-question/setup.sh scenarios/brainstorming-bounded-fires-approach-gate/setup.sh scenarios/brainstorming-router-escalates-b1-userid-param/setup.sh scenarios/brainstorming-router-escalates-b2-config-module/setup.sh scenarios/brainstorming-router-escalates-b3-logging/setup.sh scenarios/brainstorming-router-escalates-b4-reusable-validation/setup.sh scenarios/brainstorming-router-escalates-b5-prefs-storage/setup.sh scenarios/brainstorming-router-no-downgrade/setup.sh
git commit -m "refactor(scenarios): install one shared Codex approve-stub through a setup-helper"
```

---

### Task 7 (evals): The offline focus-arm test runs fixture P3

**Risk tier:** low — single-file mechanical transcription: every replacement line is given in full in Step 1.

**Files:**
- Modify: `evals/scripts/codex-focus-arm.test.sh:139-175`

**Interfaces:** none.

**Mirror:** `evals/scripts/codex-focus-arm.test.sh:139-175` itself.

- [ ] **Step 1: Edit the arms**

In `evals/scripts/codex-focus-arm.test.sh`:

- Line 139: `# Treatment on all six fixtures.` becomes `# Treatment on all seven fixtures.`
- Line 140: `run_arm treat "$focus" treatment M H O P P2 Pc ||` becomes `run_arm treat "$focus" treatment M H O P P2 P3 Pc ||`.
- Line 144: `-eq 18 ] || fail "treatment must leave 18 captures"` becomes `-eq 21 ] || fail "treatment must leave 21 captures"`.
- Line 145: `-eq 18 ] || fail "every capture must normalize to approved"` becomes `-eq 21 ] || fail "every capture must normalize to approved"`.
- Line 146: `for fx in M H O P P2 Pc; do` becomes `for fx in M H O P P2 P3 Pc; do`.
- Line 156: `-eq 18 ] || fail "every review goes through the arm's broker"` becomes `-eq 21 ] || fail "every review goes through the arm's broker"`.
- Line 166: `check_captures treat treatment M H O P P2 Pc` becomes `check_captures treat treatment M H O P P2 P3 Pc`.
- Replace lines 168-175 (the control arm) with:

```bash
# Control on H and on P3, the fixture the live P3 control ran: no cap, and the
# anchor runs straight into the next sentence.
run_arm ctl "$focus" control H P3 || fail "control arm exited $? ($(cat "$work/ctl.stderr"))"
[ "$(find "$work/ctl" -name '*-control-*.json' | grep -c .)" -eq 6 ] || fail "control must leave 6 captures"
for fx in H P3; do
  [ "$(find "$work/ctl" -name "$fx-control-*.json" | grep -c .)" -eq 3 ] || fail "control must leave 3 captures for $fx"
  for i in 1 2 3; do
    grep -q "^$fx control $i " "$work/ctl.stdout" || fail "no normalize line for $fx control $i"
  done
done
for f in "$work/ctl.focus"/*.txt; do
  ! grep -Fq -- "$cap" "$f" || fail "control focus must not carry the cap sentence: $f"
  grep -Fq -- "${anchor}You are a stateless reviewer" "$f" || fail "control focus must be the 5bef46c text: $f"
done
check_captures ctl control H P3
```

- [ ] **Step 2: Run the test**

Run (EV): `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`
Expected: exit 0 (the script prints `FAIL: <reason>` and exits 1 on any failed check). A run before Step 1 with only line 140 changed fails with `FAIL: treatment must leave 18 captures`, which shows the counts are live.

- [ ] **Step 3: Commit**

```bash
git add scripts/codex-focus-arm.test.sh
git commit -m "test(focus-arm): run fixture P3 in both offline arms"
```

---

### Task 8 (hp): `stop-server.sh` treats only "No such process" as gone

**Risk tier:** high — the script decides whether to signal a process and whether to delete a live server's handle.

**Files:**
- Modify: `skills/brainstorming/scripts/stop-server.sh:34-41`
- Test: `tests/brainstorm-server/stop-server.test.sh` (new cases before the results line, 286)

**Interfaces:** `process_exists <pid>` keeps its contract (0 = exists); it now returns 1 for a non-pid argument.

**Mirror:** `tests/brainstorm-server/stop-server.test.sh:259-284` (Test 9: fake `ps`, `/proc` guard, files-kept assertions).

- [ ] **Step 1: Write the failing tests**

In `tests/brainstorm-server/stop-server.test.sh`, insert before `echo "--- Results: ...`:

```bash
# --- Test 10: a kill -0 failure nobody listed means alive, not gone ---
# Only "No such process" means the server is gone. Reading any other failure
# as gone discarded the session files, the only handle on a server that may
# still run. A fake ps confirms the identity so the stop loop runs; kill is an
# exported function, which bash runs in place of the builtin.
if [[ -r "/proc/$$/cmdline" ]]; then
  skip "an unrecognized kill -0 failure keeps the session files" "/proc supplies the command line, so the fake ps is never run"
else
  SESS="$(mktemp -d)"; track_dir "$SESS"; mkdir -p "$SESS/state"
  SID="$(new_server_id)"
  printf '%s\n' "$SID" > "$SESS/state/server-instance-id"
  printf '%s\n' '{"type":"server-started"}' > "$SESS/state/server-info"
  ( exec -a "node server.cjs --brainstorm-server-id=$SID" sleep 600 ) &
  ODD=$!
  track_pid "$ODD"
  disown "$ODD" 2>/dev/null || true
  echo "$ODD" > "$SESS/state/server.pid"
  OURS_PS="$(mktemp -d)"; track_dir "$OURS_PS"
  printf '#!/bin/sh\necho "node server.cjs --brainstorm-server-id=%s"\n' "$SID" > "$OURS_PS/ps"
  chmod +x "$OURS_PS/ps"
  OUT="$(
    kill() { echo "kill: ($*) - Unknown error: 999" >&2; return 1; }
    export -f kill
    PATH="$OURS_PS:$PATH" "$STOP" "$SESS"
  )"; RC=$?
  if [[ "$OUT" == *stale_pid* || "$OUT" == *'"stopped"'* || "$RC" -eq 0 ]]; then
    bad "an unrecognized kill -0 failure must not read as gone" "rc=$RC $OUT"
  elif [[ ! -f "$SESS/state/server.pid" || ! -f "$SESS/state/server-instance-id" \
          || ! -f "$SESS/state/server-info" || -f "$SESS/state/server-stopped" ]]; then
    bad "an unrecognized kill -0 failure must keep the session files" "$(ls "$SESS/state")"
  else
    ok "an unrecognized kill -0 failure keeps the session files"
  fi
fi

# --- Test 11: a pid file that does not hold a pid is stale ---
# kill -0 rejects garbage, an empty string and the out-of-range numbers with a
# usage error, not ESRCH, and `kill -0 0` succeeds by signalling this shell's
# own process group; none names a server. 2147483647 is a well-formed pid no
# process holds, so it reaches kill -0 and fails with "No such process".
for BAD_PID in garbage "" -5 0 2147483648 99999999999 2147483647; do
  SESS="$(mktemp -d)"; track_dir "$SESS"; mkdir -p "$SESS/state"
  printf '%s\n' "$(new_server_id)" > "$SESS/state/server-instance-id"
  printf '%s\n' "$BAD_PID" > "$SESS/state/server.pid"
  OUT="$("$STOP" "$SESS")"; RC=$?
  if [[ "$OUT" != *stale_pid* || "$RC" -ne 0 ]]; then
    bad "pid file holding '$BAD_PID' ends stale_pid" "rc=$RC $OUT"
  elif [[ -f "$SESS/state/server.pid" || -f "$SESS/state/server-instance-id" ]] \
       || ! grep -q '"reason":"stale_pid"' "$SESS/state/server-stopped"; then
    bad "pid file holding '$BAD_PID' removes the pid files and records stale_pid" "$(ls "$SESS/state")"
  else
    ok "pid file holding '$BAD_PID' ends stale_pid"
  fi
done
```

- [ ] **Step 2: Run the test to verify it fails**

Run (HP): `bash tests/brainstorm-server/stop-server.test.sh`
Expected: exit 1 with `FAIL: an unrecognized kill -0 failure must not read as gone` (the old rule reads the unknown message as gone and ends `stale_pid`). Where `ps` cannot run (a sandbox), the `0` case also fails, ending `unverified`.

- [ ] **Step 3: Implement**

In `skills/brainstorming/scripts/stop-server.sh`, replace lines 34-41 with:

```bash
# A pid file holds a positive decimal pid; anything else is not a process.
# bash rejects garbage, an empty string or an out-of-range number with a usage
# error rather than ESRCH, and `kill -0 0` succeeds by signalling the caller's
# own process group. Of kill -0's failures only "No such process" means gone:
# EPERM is a live process this shell may not signal (a sandbox refuses signals
# to processes it did not start), and a failure nobody listed is taken as
# alive too, so the session files are never discarded on a guess.
process_exists() {
  local err pid_re='^[1-9][0-9]{0,9}$'
  [[ "$1" =~ $pid_re ]] || return 1
  (( 10#$1 <= 2147483647 )) || return 1
  err="$(LC_ALL=C; kill -0 "$1" 2>&1)" && return 0
  [[ "$err" != *"No such process"* ]]
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (HP), each as its own command: `bash tests/brainstorm-server/stop-server.test.sh`, `bash tests/brainstorm-server/start-server.test.sh`, `bash tests/shell-lint/test-lint-shell.sh`.
Expected: each exits 0 (stop-server reports `0 failed`; skips are allowed only for the documented host conditions). If shellcheck flags Test 10's exported `kill` function (it is called only indirectly), add a narrow `# shellcheck disable=<code>` on that line with the reason.

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/scripts/stop-server.sh tests/brainstorm-server/stop-server.test.sh
git commit -m "fix(brainstorming): stop-server treats only 'No such process' as gone"
```

---

### Task 9 (hp): `gate-telemetry` follows SDD pointers and counts each workspace once in the fleet total

**Risk tier:** standard — a read-only report; nothing stores or gates on its output.

**Files:**
- Modify: `skills/requesting-code-review/scripts/gate-telemetry:104-153, 228-253, 282`
- Test: `tests/codex-review-gate/test-gate-telemetry.sh` (new cases before line 364)

**Interfaces:** the JSON `aggregate` object gains `sharedWorkspaces: number` (always present).

**Mirror:** `tests/codex-review-gate/test-gate-telemetry.sh:268-303` (plan workspaces with `node -e` assertions over `--json`).

- [ ] **Step 1: Write the failing tests**

In `tests/codex-review-gate/test-gate-telemetry.sh`, insert before the final `echo` (line 364):

```bash
# --- A cross-repo plan's pointer: rows follow it, the fleet total counts once ---
# sdd-dir keeps a cross-repo plan's one workspace under the plan repository's
# key and leaves a symlink under the executing repository's key. That row
# counts the tasks behind the pointer; under --all the workspace sits in both
# rows and once in the fleet total.
pre_all="$(bash "$GT" --all --json)"
node -e 'const a=JSON.parse(process.argv[1]).aggregate;process.exit(a.sharedWorkspaces===0?0:1)' "$pre_all" \
  && pass "a cache with no pointers reports sharedWorkspaces 0" || fail "a cache with no pointers reports sharedWorkspaces 0"
pre_md="$(bash "$GT" --all)"
if grep -Fq 'Shared workspaces' < <(printf '%s\n' "$pre_md"); then
  fail "no shared-workspace line without pointers"
else
  pass "no shared-workspace line without pointers"
fi
xrepo="$work/xrepo"; mkdir -p "$xrepo"; git -C "$xrepo" init -q
git -C "$xrepo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
key9="$(printf '%s' "$(git -C "$xrepo" rev-parse --absolute-git-dir)" | git -C "$xrepo" hash-object --stdin)"
xplans="$XDG_CACHE_HOME/hyperpowers/sdd/$key9/plans"; mkdir -p "$xplans"
# A shared workspace with no task brief yet still counts as shared: the spec
# counts workspaces reached from more than one key.
wsE="$sddp/plans/2026-09-05-empty-f6a7b8c9"; mkdir -p "$wsE"
ln -s "$wsA" "$xplans/2026-09-05-alpha-a1b2c3d4+${key5:0:8}"
ln -s "$wsE" "$xplans/2026-09-05-empty-f6a7b8c9+${key5:0:8}"
ln -s "$work/no-such-workspace" "$xplans/2026-09-05-gone-e5f6a7b8+${key5:0:8}"
if xjs="$(bash "$GT" "$xrepo" --json)"; then
  pass "a dangling pointer does not fail the report"
else
  fail "a dangling pointer does not fail the report"
fi
node -e 'const r=JSON.parse(process.argv[1]).repos[0];process.exit(r.tasks===4&&r.fixBriefs===3?0:1)' "$xjs" \
  && pass "a pointer-only key reports the tasks of the workspace it points to (3/4)" || fail "a pointer-only key reports the tasks of the workspace it points to (3/4)"
xall="$(bash "$GT" --all --json)"
node -e 'const j=JSON.parse(process.argv[1]);const t=(k)=>(j.repos.find((r)=>r.key===k)||{tasks:-1}).tasks;const sum=j.repos.reduce((a,r)=>a+r.tasks,0);process.exit(t(process.argv[2])===6&&t(process.argv[3])===4&&j.aggregate.tasks===sum-4&&j.aggregate.sharedWorkspaces===2?0:1)' "$xall" "$key5" "$key9" \
  && pass "--all lists the shared workspaces in both rows, counts their tasks once, and counts the empty one as shared" || fail "--all lists the shared workspaces in both rows, counts their tasks once, and counts the empty one as shared"
xmd="$(bash "$GT" --all)"
if grep -Fq 'Shared workspaces: 2 (counted once in the aggregate)' < <(printf '%s\n' "$xmd"); then
  pass "the fleet section names the shared workspaces"
else
  fail "the fleet section names the shared workspaces"
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run (HP): `bash tests/codex-review-gate/test-gate-telemetry.sh`
Expected: exit 1. FAIL lines for `sharedWorkspaces 0` (the field is absent), the pointer-only key (0/0 tasks), the fleet total, and the shared-workspace line.

- [ ] **Step 3: Implement**

In `skills/requesting-code-review/scripts/gate-telemetry` (the whole node program is single-quoted in the shell, so the new code uses no single quote):

Add before `const repos = [];` (line 104):

```js
  // Each row's task identities, kept beside the report (never in it), for the
  // fleet aggregate to de-duplicate on.
  const sddSets = new Map();
```

Replace lines 119-126 (from `const sdd = path.join(base, "sdd", key);` through the closing brace of `if (fs.existsSync(sdd)) {`) with:

```js
    // A plan run from another repository's checkout keeps its one workspace
    // under the plan repository's key and leaves a symlink under the executing
    // repository's key (subagent-driven-development/scripts/sdd-dir). statSync
    // follows the link, so this row counts the tasks its runs touched; a
    // dangling pointer throws and is skipped. A workspace is identified by its
    // real path, which the fleet aggregate de-duplicates on.
    const sdd = path.join(base, "sdd", key);
    const workspaces = [];
    if (fs.existsSync(sdd)) {
      workspaces.push(sdd);
      let plans = [];
      try { plans = fs.readdirSync(path.join(sdd, "plans")); } catch (e) { plans = []; }
      for (const name of plans) {
        const p = path.join(sdd, "plans", name);
        try { if (fs.statSync(p).isDirectory()) workspaces.push(p); } catch (e) { /* dangling pointer */ }
      }
    }
```

Replace lines 136-153 (from `const cohort = new Set(), fixed = new Set();` through `for (const id of fixed) if (cohort.has(id)) r.fixBriefs++;`) with:

```js
    // reached holds every workspace this row resolved, empty or not, so the
    // fleet's shared-workspace count is about reach, not about task briefs.
    const cohort = new Set(), fixed = new Set(), reached = new Set();
    for (const ws of workspaces) {
      let real;
      try { real = fs.realpathSync(ws); } catch (e) { continue; }
      let files = [];
      try { files = fs.readdirSync(ws); } catch (e) { continue; }
      reached.add(real);
      for (const f of files) {
        const brief = f.match(/^task-(\d+)-brief\.md$/);
        const m = f.match(/^task-(\d+)-.*codex-fix-brief/);
        if (!brief && !m) continue;
        if (windowed) {
          let st; try { st = fs.statSync(path.join(ws, f)); } catch (e) { continue; }
          if (!inWindow(st.mtimeMs)) continue;
        }
        if (brief) { r.tasks++; cohort.add(real + "\u0000" + brief[1]); }
        if (m) fixed.add(real + "\u0000" + m[1]);
        observed++;
      }
    }
    for (const id of fixed) if (cohort.has(id)) r.fixBriefs++;
    sddSets.set(r, { cohort, fixed, reached });
```

In the aggregate literal (line 229-231), add `sharedWorkspaces: 0` after `dossiers: 0`. In the aggregate loop (line 233), delete `agg.tasks += r.tasks; agg.fixBriefs += r.fixBriefs; ` so the line starts `agg.runs += r.runs;`. After the loop's closing brace (before `// Attach the derived metrics`), add:

```js
  // Tasks and fix briefs are counted over the union of the rows' task sets,
  // so a workspace two rows reach (its own key, and a pointer from another)
  // counts once; a workspace reached from more than one row is shared,
  // whether or not it holds a task brief yet. The other aggregate fields come
  // from codex-review and ungated, which pointers do not touch.
  const allCohort = new Set(), allFixed = new Set(), rowsPerWs = new Map();
  for (const r of repos) {
    const s = sddSets.get(r);
    for (const id of s.cohort) allCohort.add(id);
    for (const id of s.fixed) allFixed.add(id);
    for (const ws of s.reached) rowsPerWs.set(ws, (rowsPerWs.get(ws) || 0) + 1);
  }
  agg.tasks = allCohort.size;
  for (const id of allFixed) if (allCohort.has(id)) agg.fixBriefs++;
  for (const n of rowsPerWs.values()) if (n > 1) agg.sharedWorkspaces++;
```

After the fleet line `console.log(\`- Fix-cycle rate: ${agg.fixBriefs}/${agg.tasks} tasks\`);` (line 282), add:

```js
    if (agg.sharedWorkspaces) console.log(`- Shared workspaces: ${agg.sharedWorkspaces} (counted once in the aggregate)`);
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (HP), each as its own command: `bash tests/codex-review-gate/test-gate-telemetry.sh`, `bash tests/shell-lint/test-lint-shell.sh`.
Expected: `ALL PASS`, and shell-lint exits 0.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-telemetry tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "fix(gate-telemetry): follow SDD pointers and count each workspace once in the fleet total"
```

---

### Task 10 (hp): Piped `grep -q` checks read from files and check their producers

**Risk tier:** standard — test-only edits of one kind in two files.

**Files:**
- Modify: `tests/packaging/test-package-skill.sh:40-53, 112-117, 135-147, 177-207`
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh:185-194, 333-342`

**Interfaces:** none.

**Mirror:** `tests/packaging/test-package-skill.sh:187-199` (an explicit producer check before inspecting its output).

- [ ] **Step 1: Rewrite the package-skill checks**

In `tests/packaging/test-package-skill.sh`, replace lines 40-53 with:

```bash
# Test 2: unzip -l layout (folder at root, SKILL.md present)
# Every listing is written to a file before it is searched. A producer piped
# into `grep -q` dies of SIGPIPE when grep exits on its first match, and under
# pipefail the `if` then reads the match as no match. A producer that fails is
# a FAIL of its own, never an empty file a negative check would pass on.
ZIP_LISTING="$TEST_DIST/zip-listing.txt"
ZIP_LISTED=0
if unzip -l "$EXPECTED_ZIP" > "$ZIP_LISTING" 2>&1; then
  ZIP_LISTED=1
fi
if [[ "$ZIP_LISTED" -ne 1 ]]; then
  fail "unzip -l failed on the built zip $EXPECTED_ZIP: $(head -n 1 "$ZIP_LISTING")"
elif grep -q "hyperpowers/SKILL.md" "$ZIP_LISTING"; then
  pass "hyperpowers/SKILL.md present in zip"
else
  fail "hyperpowers/SKILL.md not found in zip"
fi

OUTSIDE_ENTRIES="$TEST_DIST/outside-entries.txt"
if [[ "$ZIP_LISTED" -ne 1 ]]; then
  fail "no listing of $EXPECTED_ZIP to check for entries outside hyperpowers/"
elif ! awk '!/(Archive:|Length|----| files$)/ && !/^ *[0-9]+ .* hyperpowers\// && /^ *[0-9]+/' "$ZIP_LISTING" > "$OUTSIDE_ENTRIES"; then
  fail "could not filter the listing of $EXPECTED_ZIP"
elif [[ -s "$OUTSIDE_ENTRIES" ]]; then
  fail "zip contains entries outside hyperpowers/ folder"
else
  pass "all zip entries under hyperpowers/ folder"
fi
```

Replace lines 112-117 (Test 8) with:

```bash
# Test 8: NO hooks/, tests/, docs/, .claude-plugin/ paths inside zip
if [[ "$ZIP_LISTED" -ne 1 ]]; then
  fail "no listing of $EXPECTED_ZIP to check for unwanted paths"
elif grep -qE 'hyperpowers/(hooks|tests|docs|\.claude-plugin)/' "$ZIP_LISTING"; then
  fail "zip contains unwanted paths (hooks/, tests/, docs/, .claude-plugin/)"
else
  pass "no hooks/, tests/, docs/, or .claude-plugin/ in zip"
fi
```

Replace lines 143-147 (the Test 11 check) with:

```bash
STALE_LISTING="$TEST_DIST_STALE/listing.txt"
if ! unzip -l "$STALE_ZIP" > "$STALE_LISTING" 2>&1; then
  fail "unzip -l failed on the rebuilt stale zip $STALE_ZIP: $(head -n 1 "$STALE_LISTING")"
elif grep -q "hyperpowers/STALE.md" "$STALE_LISTING"; then
  fail "rebuild did not remove stale zip entry (hyperpowers/STALE.md still present)"
else
  pass "rebuild removes stale zip entries"
fi
```

Replace lines 195-199 (the canary check's last two branches) with:

```bash
elif ! unzip -l "$CANARY_ZIP" > "$TEST_DIST_CANARY/listing.txt" 2>&1; then
  fail "unzip -l failed on the canary zip $CANARY_ZIP: $(head -n 1 "$TEST_DIST_CANARY/listing.txt")"
elif grep -q ".tmp-untracked-canary" "$TEST_DIST_CANARY/listing.txt"; then
  fail "untracked canary file was included in zip"
else
  pass "untracked files NOT staged (canary absent)"
fi
```

Replace lines 202-207 (Test 15) with:

```bash
# Test 15: using-hyperpowers/SKILL.md excluded but references/ kept
if [[ "$ZIP_LISTED" -ne 1 ]]; then
  fail "no listing of $EXPECTED_ZIP to check the using-hyperpowers exclusion"
elif grep -q "hyperpowers/skills/using-hyperpowers/SKILL.md" "$ZIP_LISTING"; then
  fail "using-hyperpowers/SKILL.md present (should be excluded, router supersedes it)"
else
  pass "using-hyperpowers/SKILL.md excluded (router supersedes)"
fi
```

- [ ] **Step 2: Rewrite the split-lossless checks**

In `tests/codex-review-gate/test-gate-split-lossless.sh`, replace lines 189-194 (from `# shellcheck disable=SC1003` through the `fi` of the references check) with:

```bash
# The replacements are written to a file before they are searched: a producer
# piped into `grep -q` dies of SIGPIPE on an early match, and under pipefail
# the `if` read the match as no match. A failed read is a FAIL of its own.
ref_replacements="$TEST_ROOT/reference-replacements.txt"
# shellcheck disable=SC1003  # the literal backslash is the pattern, not an escape
if ! grep -v '^#' "$REFERENCES" | cut -f4- > "$ref_replacements"; then
    fail "the reference replacements could not be read out of $REFERENCES"
elif grep -qF '\' "$ref_replacements"; then
    fail "no replacement text contains a backslash (awk -v would reinterpret it)"
else
    pass "no replacement text contains a backslash"
fi
```

Replace lines 337-342 (from `# shellcheck disable=SC1003` through the `fi` of the post-edits check) with:

```bash
post_replacements="$TEST_ROOT/post-split-replacements.txt"
# shellcheck disable=SC1003  # the literal backslash is the pattern, not an escape
if ! grep -v '^#' "$POST_EDITS" | cut -f3- > "$post_replacements"; then
    fail "the post-split replacements could not be read out of $POST_EDITS"
elif grep -qF '\' "$post_replacements"; then
    fail "no post-split replacement contains a backslash (awk -v would reinterpret it)"
else
    pass "no post-split replacement contains a backslash"
fi
```

- [ ] **Step 3: Show every changed check can fail, in the real suites**

The two suites run unmodified, four times, with a fake `unzip` or a fake `cut` first on `PATH`. The fakes pass every call through to the real tool except the ones the changed checks make, which they either plant (an extra entry or a backslash line) or fail (a producer failure). The packaging script's own `unzip -l` reads a temporary archive named `*.tmp.<pid>`, so the fake leaves it alone and the build runs normally. Write `/Users/johnss51/.cache/hyperpowers/post-release-follow-ups/demo-task10.sh` and run it with `bash` from HP:

```bash
#!/usr/bin/env bash
# Runs test-package-skill.sh and test-gate-split-lossless.sh as they are, with
# planted inputs and with failing producers, and requires each changed check
# to report its FAIL. Exits non-zero when any expected FAIL line is missing.
set -u
fake="$(mktemp -d)"; trap 'rm -rf "$fake"' EXIT
REAL_UNZIP="$(command -v unzip)"; REAL_CUT="$(command -v cut)"; export REAL_UNZIP REAL_CUT
cat > "$fake/unzip" <<'EOF'
#!/usr/bin/env bash
# Plants or fails only `unzip -l <x>.zip`; every other call is the real unzip.
if [ "$1" = "-l" ] && [[ "${2:-}" == *.zip ]]; then
  case "${FAKE_UNZIP_MODE:-}" in
    fail) echo "unzip:  cannot find or open $2" >&2; exit 9 ;;
    plant)
      "$REAL_UNZIP" "$@" || exit $?
      for e in stray.txt hyperpowers/hooks/x.sh hyperpowers/STALE.md \
               hyperpowers/skills/.tmp-untracked-canary hyperpowers/skills/using-hyperpowers/SKILL.md; do
        printf '       10  01-01-2026 00:00   %s\n' "$e"
      done
      exit 0 ;;
  esac
fi
exec "$REAL_UNZIP" "$@"
EOF
cat > "$fake/cut" <<'EOF'
#!/usr/bin/env bash
# Plants or fails only `cut -f4-` and `cut -f3-`; every other call is the real cut.
if [ "${1:-}" = "-f4-" ] || [ "${1:-}" = "-f3-" ]; then
  case "${FAKE_CUT_MODE:-}" in
    fail) exit 1 ;;
    plant) "$REAL_CUT" "$@" || exit $?; printf 'x\\y\n'; exit 0 ;;
  esac
fi
exec "$REAL_CUT" "$@"
EOF
chmod +x "$fake/unzip" "$fake/cut"
fails=0
expect_fail_lines() { # <label> <log> <rc> <needle>...
  local label="$1" log="$2" rc="$3" n; shift 3
  if [ "$rc" -eq 0 ]; then echo "WRONG: $label: the suite exited 0"; fails=$((fails + 1)); fi
  for n in "$@"; do
    if awk -v n="$n" 'index($0, "[FAIL]") && index($0, n) { f = 1 } END { exit !f }' "$log"; then
      echo "ok: $label: $n"
    else
      echo "WRONG: $label: no FAIL line naming: $n"; fails=$((fails + 1))
    fi
  done
}
PATH="$fake:$PATH" FAKE_UNZIP_MODE=plant bash tests/packaging/test-package-skill.sh > "$fake/pkg-plant.log" 2>&1
expect_fail_lines "package-skill, planted entries" "$fake/pkg-plant.log" $? \
  "zip contains entries outside hyperpowers/ folder" \
  "zip contains unwanted paths" \
  "rebuild did not remove stale zip entry" \
  "untracked canary file was included in zip" \
  "using-hyperpowers/SKILL.md present"
PATH="$fake:$PATH" FAKE_UNZIP_MODE=fail bash tests/packaging/test-package-skill.sh > "$fake/pkg-fail.log" 2>&1
expect_fail_lines "package-skill, failing unzip -l" "$fake/pkg-fail.log" $? \
  "unzip -l failed on the built zip" \
  "to check for entries outside hyperpowers/" \
  "to check for unwanted paths" \
  "unzip -l failed on the rebuilt stale zip" \
  "unzip -l failed on the canary zip" \
  "to check the using-hyperpowers exclusion"
PATH="$fake:$PATH" FAKE_CUT_MODE=plant bash tests/codex-review-gate/test-gate-split-lossless.sh > "$fake/split-plant.log" 2>&1
expect_fail_lines "split-lossless, planted backslash" "$fake/split-plant.log" $? \
  "no replacement text contains a backslash" \
  "no post-split replacement contains a backslash"
PATH="$fake:$PATH" FAKE_CUT_MODE=fail bash tests/codex-review-gate/test-gate-split-lossless.sh > "$fake/split-fail.log" 2>&1
expect_fail_lines "split-lossless, failing cut" "$fake/split-fail.log" $? \
  "the reference replacements could not be read" \
  "the post-split replacements could not be read"
echo "fails=$fails"
[ "$fails" -eq 0 ]
```

Expected: fifteen `ok:` lines, `fails=0`, exit 0. Before Steps 1 and 2 the same script reports `WRONG` lines (the old checks have no producer-failure messages), which shows it measures the new code.

- [ ] **Step 4: Run the suites**

Run (HP), each as its own command: `bash tests/packaging/test-package-skill.sh`, `bash tests/codex-review-gate/test-gate-split-lossless.sh`, `bash tests/shell-lint/test-lint-shell.sh`.
Expected: each exits 0.

- [ ] **Step 5: Commit**

```bash
git add tests/packaging/test-package-skill.sh tests/codex-review-gate/test-gate-split-lossless.sh
git commit -m "test: piped grep -q checks read from files and check their producers"
```

---

### Task 11 (hp): Here-strings in `tests/codex-review-gate/` become process substitution

**Risk tier:** standard — a rule-driven edit across fourteen files, each proven by its own suite.

**Files:**
- Modify: `tests/codex-review-gate/test-assemble-gate.sh`, `test-base-ref-ok.sh`, `test-broker-health.sh`, `test-broker-state-dir.sh`, `test-codex-broker-sweep.sh`, `test-codex-preflight.sh`, `test-gate-contract.sh`, `test-gate-round.sh`, `test-gate-telemetry.sh`, `test-gate-topology.sh`, `test-review-dossier.sh`, `test-sweep-toolchain.sh`, `test-ungated-ledger.sh`, `test-verdict-normalize.sh` (89 sites)

**Interfaces:** none.

**Mirror:** the converted form `grep -q x < <(printf '%s\n' "$var")`, as Task 9's new test lines use it.

- [ ] **Step 1: Convert**

Run (HP):

```bash
perl -p -i /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/herestring.pl tests/codex-review-gate/test-assemble-gate.sh tests/codex-review-gate/test-base-ref-ok.sh tests/codex-review-gate/test-broker-health.sh tests/codex-review-gate/test-broker-state-dir.sh tests/codex-review-gate/test-codex-broker-sweep.sh tests/codex-review-gate/test-codex-preflight.sh tests/codex-review-gate/test-gate-contract.sh tests/codex-review-gate/test-gate-round.sh tests/codex-review-gate/test-gate-telemetry.sh tests/codex-review-gate/test-gate-topology.sh tests/codex-review-gate/test-review-dossier.sh tests/codex-review-gate/test-sweep-toolchain.sh tests/codex-review-gate/test-ungated-ledger.sh tests/codex-review-gate/test-verdict-normalize.sh
```

- [ ] **Step 2: Verify the conversion**

Run (HP), each as its own command:
- `grep -c '<<<' tests/codex-review-gate/*.sh | grep -v ':0$'` — expected: no output (exit 1).
- `git diff --numstat -- tests/codex-review-gate | awk '{a+=$1; d+=$2} END {print a, d}'` — expected: `89 89`.
- `for f in tests/codex-review-gate/test-*.sh; do bash -n "$f" || exit 1; done && echo syntax-ok` — expected: `syntax-ok`.

- [ ] **Step 3: Run the fourteen suites**

Run (HP): `bash /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/run-suites.sh tests/codex-review-gate/test-assemble-gate.sh tests/codex-review-gate/test-base-ref-ok.sh tests/codex-review-gate/test-broker-health.sh tests/codex-review-gate/test-broker-state-dir.sh tests/codex-review-gate/test-codex-broker-sweep.sh tests/codex-review-gate/test-codex-preflight.sh tests/codex-review-gate/test-gate-contract.sh tests/codex-review-gate/test-gate-round.sh tests/codex-review-gate/test-gate-telemetry.sh tests/codex-review-gate/test-gate-topology.sh tests/codex-review-gate/test-review-dossier.sh tests/codex-review-gate/test-sweep-toolchain.sh tests/codex-review-gate/test-ungated-ledger.sh tests/codex-review-gate/test-verdict-normalize.sh`
Expected: fourteen `ok` lines, `fails=0`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/codex-review-gate
git commit -m "test(codex-review-gate): replace here-strings with process substitution"
```

---

### Task 12 (hp): Here-strings in the other test directories become process substitution

**Risk tier:** standard — the Task 11 rule over eighteen files, plus one coupled `sed` pattern.

**Files:**
- Modify: `tests/brainstorm-server/start-server.test.sh`, `windows-lifecycle.test.sh`; `tests/claude-code/test-delivery-resolution.sh` (including line 37), `test-helpers.sh`, `test-sdd-dir-path.sh`, `test-subagent-driven-development-integration.sh`, `test-worktree-native-preference.sh`; `tests/hooks/test-broker-janitor.sh`, `test-session-start.sh`, `test-ungated-notice.sh`; `tests/opencode/test-priority.sh`, `test-tools.sh`; `tests/packaging/test-skill-frontmatter-rejects.sh`, `test-skill-frontmatter.sh`; `tests/sdd/test-sdd-contract.sh`; `tests/shell-lint/test-lint-shell.sh`; `tests/systematic-debugging/test-find-polluter.sh`; `tests/writing-skills/test-render-graphs.sh` (45 sites)

**Interfaces:** none.

**Mirror:** Task 11.

- [ ] **Step 1: Convert**

Run (HP):

```bash
perl -p -i /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/herestring.pl tests/brainstorm-server/start-server.test.sh tests/brainstorm-server/windows-lifecycle.test.sh tests/claude-code/test-delivery-resolution.sh tests/claude-code/test-helpers.sh tests/claude-code/test-sdd-dir-path.sh tests/claude-code/test-subagent-driven-development-integration.sh tests/claude-code/test-worktree-native-preference.sh tests/hooks/test-broker-janitor.sh tests/hooks/test-session-start.sh tests/hooks/test-ungated-notice.sh tests/opencode/test-priority.sh tests/opencode/test-tools.sh tests/packaging/test-skill-frontmatter-rejects.sh tests/packaging/test-skill-frontmatter.sh tests/sdd/test-sdd-contract.sh tests/shell-lint/test-lint-shell.sh tests/systematic-debugging/test-find-polluter.sh tests/writing-skills/test-render-graphs.sh
```

- [ ] **Step 2: Update the coupled `sed` pattern**

`test-subagent-driven-development-integration.sh:283` now reads `done < <(printf '%s\n' "$worktree_list")`, so the extraction in `tests/claude-code/test-delivery-resolution.sh:37` must end at that line. Replace line 37:

```bash
sed -n '/^DELIVERY_DIR="\$TEST_PROJECT"$/,/^done <<<"\$worktree_list"$/p' \
```

with:

```bash
sed -n '/^DELIVERY_DIR="\$TEST_PROJECT"$/,/^done < <(printf .*"\$worktree_list")$/p' \
```

The `.*` stands for the quoted format string, which a single-quoted `sed` script cannot spell without escaping its quotes. The test's existing empty-block failure (lines 39-43) proves the new end pattern matches.

- [ ] **Step 3: Verify the conversion**

Run (HP), each as its own command:
- `grep -rn '<<<' tests --include='*.sh' | grep -v ':[[:space:]]*#'` — expected: exactly one line, `tests/hooks/test-no-heredocs-in-hooks.sh:48:...` (Task 13 rewrites it).
- `git diff --numstat -- tests | awk '{a+=$1; d+=$2} END {print a, d}'` — expected: `46 46` (45 conversions plus the `sed` line).
- `git diff --name-only -- tests | while IFS= read -r f; do bash -n "$f" || exit 1; done && echo syntax-ok` — expected: `syntax-ok`.

- [ ] **Step 4: Run the suites**

Offline-set files, run (HP): `bash /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/run-suites.sh tests/brainstorm-server/start-server.test.sh tests/brainstorm-server/windows-lifecycle.test.sh tests/claude-code/test-delivery-resolution.sh tests/claude-code/test-sdd-dir-path.sh tests/hooks/test-broker-janitor.sh tests/hooks/test-session-start.sh tests/hooks/test-ungated-notice.sh tests/packaging/test-skill-frontmatter-rejects.sh tests/packaging/test-skill-frontmatter.sh tests/sdd/test-sdd-contract.sh tests/shell-lint/test-lint-shell.sh tests/systematic-debugging/test-find-polluter.sh tests/writing-skills/test-render-graphs.sh`
Expected: thirteen `ok` lines, `fails=0`, exit 0.

Then (HP): `cd tests/brainstorm-server && npm test` — expected: exit 0.

The five files only live or integration suites reach are not run (they spawn the real `claude` CLI or need an installed OpenCode): `tests/claude-code/test-helpers.sh`, `test-subagent-driven-development-integration.sh`, `test-worktree-native-preference.sh`, `tests/opencode/test-priority.sh`, `tests/opencode/test-tools.sh`. Their check is the `bash -n` in Step 3 plus reading their converted lines in the diff; the integration suite's resolution block runs offline through `test-delivery-resolution.sh` above.

- [ ] **Step 5: Commit**

```bash
git add tests
git commit -m "test: replace the remaining here-strings with process substitution"
```

---

### Task 13 (hp): The fence bans here-strings in `tests/`

**Risk tier:** standard — a test fence plus one coverage-table line.

**Files:**
- Modify: `tests/hooks/test-no-heredocs-in-hooks.sh:1-7, 20-57`
- Modify: `docs/testing.md:23`

**Interfaces:** none.

**Mirror:** `tests/hooks/test-no-heredocs-in-hooks.sh:41-57` (probe files that prove the fence flags what it should and nothing else).

- [ ] **Step 1: Edit the fence**

In `tests/hooks/test-no-heredocs-in-hooks.sh`, replace lines 1-7 with:

```bash
#!/usr/bin/env bash
# Heredocs and here-strings are banned in hooks/ executables, and here-strings
# in the shell files under tests/. bash 5.1+ delivers a heredoc or a here-string
# through a pipe it writes before forking; under macOS pipe pressure the kernel
# hands out 512-byte pipes and that write deadlocks, hanging every hook in the
# session (https://github.com/obra/superpowers/issues/571) or a suite run under
# a contributor's bash. printf replaces them in hooks; process substitution,
# `< <(printf '%s\n' "$var")`, in tests. Heredocs under tests/ are a known gap
# tracked separately.
```

After `fail() { ... }` (line 15), add:

```bash
# The here-string token, assembled so this file never contains the form it bans.
hs='<<''<'
```

Replace line 48 with:

```bash
printf '#!/usr/bin/env bash\ncat %s "x"\n' "$hs" > "$probe/hs-hook"
```

After the `fi` that closes the probe check (line 57), add:

```bash

# --- tests/: no here-strings ---
# A line whose first non-blank character is # is a comment and may name the form.
herestring_offenders() { # <file>... -> "<file>:<line>" for each offending line
    awk -v hs="$hs" 'index($0, hs) > 0 && $0 !~ /^[[:space:]]*#/ { print FILENAME ":" FNR }' "$@"
}
tests_shell_files() { # every tracked shell file under tests/: a .sh name or a sh/bash shebang
    local f first shebang_re='^#!.*(/|[[:space:]])(ba)?sh([[:space:]]|$)'
    while IFS= read -r f; do
        case "$f" in
            *.sh) printf '%s\n' "$REPO_ROOT/$f" ;;
            *)
                first=""
                IFS= read -r first < "$REPO_ROOT/$f" 2>/dev/null || true
                if [[ "$first" =~ $shebang_re ]]; then
                    printf '%s\n' "$REPO_ROOT/$f"
                fi
                ;;
        esac
    done < <(git -C "$REPO_ROOT" ls-files -- tests)
}

test_files=()
while IFS= read -r f; do test_files+=("$f"); done < <(tests_shell_files)
tests_offenders=""
if [ "${#test_files[@]}" -gt 0 ]; then
    tests_offenders="$(herestring_offenders "${test_files[@]}")"
fi
if [ "${#test_files[@]}" -eq 0 ]; then
    fail "no shell files found under tests/"
elif [ -z "$tests_offenders" ]; then
    pass "no shell file under tests/ uses a here-string (${#test_files[@]} files)"
else
    fail "here-string found under tests/: $(printf '%s' "$tests_offenders" | tr '\n' ' ')"
fi

printf '#!/usr/bin/env bash\ngrep -q x %s "$y"\n' "$hs" > "$probe/hs-test.sh"
printf '#!/usr/bin/env bash\n# a comment may name %s\necho ok\n' "$hs" > "$probe/comment-test.sh"
probe_test_offenders="$(herestring_offenders "$probe/hs-test.sh" "$probe/comment-test.sh")"
if [ "$probe_test_offenders" = "$probe/hs-test.sh:2" ]; then
    pass "the tests/ fence flags a here-string and not a comment naming one"
else
    fail "the tests/ fence flags a here-string and not a comment naming one (got: ${probe_test_offenders:-<empty>})"
fi
```

- [ ] **Step 2: Update the coverage table**

In `docs/testing.md:23`, replace `the hooks heredoc fence` with `the heredoc fence (no heredoc or here-string in \`hooks/\`, no here-string in \`tests/\`)`.

- [ ] **Step 3: Run the fence and prove it can fail**

Run (HP): `bash tests/hooks/test-no-heredocs-in-hooks.sh`
Expected: `STATUS: PASSED`, including `no shell file under tests/ uses a here-string` and the two probe passes.

Then plant a here-string in a tracked file (the fence reads `git ls-files`, so an untracked plant would not be seen) and confirm the fence fails, restoring the file from a copy rather than through git. Write `/Users/johnss51/.cache/hyperpowers/post-release-follow-ups/plant-herestring.sh` and run it with `bash` from HP:

```bash
#!/usr/bin/env bash
# Plants a here-string in a tracked test file, runs the fence, restores the
# file from a copy, and exits 0 only when the fence failed and the file is back.
set -u
target=tests/sdd/test-sdd-contract.sh
backup="$(mktemp)"
cp "$target" "$backup"
printf 'grep -q x %s "$y"\n' '<<''<' >> "$target"
out="$(bash tests/hooks/test-no-heredocs-in-hooks.sh 2>&1)"; rc=$?
cp "$backup" "$target"; rm -f "$backup"
git diff --quiet -- "$target" || { echo "NOT RESTORED: $target"; exit 1; }
printf '%s\n' "$out" | tail -n 3
if [ "$rc" -ne 0 ] && grep -Fq "$target" < <(printf '%s\n' "$out"); then
  echo "fence-fails-as-it-should"
else
  echo "WRONG: the fence did not flag the planted here-string (rc=$rc)"
  exit 1
fi
```

Expected: the fence's last lines end `STATUS: FAILED`, then `fence-fails-as-it-should`, exit 0.

Then (HP): `grep -c '<<<' tests/hooks/test-no-heredocs-in-hooks.sh` — expected: `1` (the comment inside `heredoc_offenders`; the new header and the probe no longer spell the token).

- [ ] **Step 4: Commit**

```bash
git add tests/hooks/test-no-heredocs-in-hooks.sh docs/testing.md
git commit -m "test(hooks): the heredoc fence bans here-strings under tests/"
```

---

### Task 14 (hp): A Correction on the release-hygiene plan's checks that cannot fail

**Risk tier:** low — a single-file documentation correction whose full text Step 2 supplies.

**Files:**
- Modify: `docs/hyperpowers/plans/2026-10-05-release-hygiene.md` (append at the end, after line 2260)

**Interfaces:** none.

**Mirror:** `docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md:1789-1803` (appended Correction paragraphs).

- [ ] **Step 1: Re-run the two Task 24 checks in working form**

Write `/Users/johnss51/.cache/hyperpowers/post-release-follow-ups/t24-recheck.sh`:

```bash
#!/usr/bin/env bash
# Task 24 Step 2's two negated checks, in a form set -e cannot skip, against
# the committed evidence.
set -u
cd /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-05-release-hygiene/task-24-runs/control-P3 || exit 2
fails=0
if grep -q stub runtime-start.txt; then echo "FAIL: runtime-start.txt mentions stub"; fails=$((fails + 1)); else echo "ok: runtime-start.txt does not mention stub"; fi
cap="$(cat ../../../2026-10-03-review-calibration-and-sentinel-scope/cap-sentence.txt)"
for i in 1 2 3; do
  if grep -qF -- "$cap" "P3-control-$i.prompt"; then echo "FAIL: P3-control-$i.prompt carries the cap sentence"; fails=$((fails + 1)); else echo "ok: P3-control-$i.prompt does not carry the cap sentence"; fi
done
echo "fails=$fails"
[ "$fails" -eq 0 ]
```

Run: `bash /Users/johnss51/.cache/hyperpowers/post-release-follow-ups/t24-recheck.sh`
Expected (as run on 2026-10-11 against evals `81da2b74b`):

```
ok: runtime-start.txt does not mention stub
ok: P3-control-1.prompt does not carry the cap sentence
ok: P3-control-2.prompt does not carry the cap sentence
ok: P3-control-3.prompt does not carry the cap sentence
fails=0
```

If the output differs, stop: that is a finding about Task 24's record, surfaced to the human partner, not text to write around.

- [ ] **Step 2: Append the Correction**

Append to `docs/hyperpowers/plans/2026-10-05-release-hygiene.md`, after a blank line, with `DATE` replaced by the day of the commit (`date +%F`):

```markdown
**Correction (DATE).** Two kinds of check in this plan cannot fail. The suite loops at lines 584, 641, 646, 682, 687, 723 and 728 run each suite and print each failure (`FAILED <file>`, `SYNTAX <file>`, or a `fails=<n>` count), but each ends with `echo` or catches a failure with `|| echo`, so the command exits 0 whatever the suites did: a failure was visible in the output and absent from the exit status. Task 24 Step 2 runs under `set -e`, which does not apply to a command negated with `!`, so its two `! grep` lines (2159 and 2166) would not have stopped the step on a match. The working forms are a loop that counts failures and ends with `[ "$fails" -eq 0 ]` (`docs/testing.md` gives one) and `if grep -q …; then exit 1; fi` for a negated check. Re-run on DATE in that form against the committed evidence in `evals/evidence/2026-10-05-release-hygiene/task-24-runs/control-P3/`, the two Task 24 checks print `ok: runtime-start.txt does not mention stub`, `ok: P3-control-1.prompt does not carry the cap sentence`, the same for `P3-control-2.prompt` and `P3-control-3.prompt`, and `fails=0`. Nothing else is claimed about those steps beyond what their output recorded at the time.
```

- [ ] **Step 3: Verify**

Run (HP), each as its own command: `grep -c '^\*\*Correction (' docs/hyperpowers/plans/2026-10-05-release-hygiene.md` (expected: `2`; the plan already carries one Correction, in Task 10's body at line 874), and `tail -n 1 docs/hyperpowers/plans/2026-10-05-release-hygiene.md | cut -c1-15` (expected: `**Correction (2`, the new paragraph is the file's last line).

- [ ] **Step 4: Commit**

```bash
git add docs/hyperpowers/plans/2026-10-05-release-hygiene.md
git commit -m "docs(hyperpowers): correct the release-hygiene plan's checks that cannot fail"
```

---

## After Task 14 (controller)

1. Final whole-branch reviews and final Codex gates per SDD, evals first.
2. Finishing, evals first: `hyperpowers:finishing-a-development-branch` on the evals branch, with its merged-result verification being, on the merged main checkout, each as its own command: `bun run check` with no failures (run outside the sandbox: two home-directory tests fail with EPERM inside it), `bun run quorum check`, and `bash scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers evidence/2026-10-03-review-calibration-and-sentinel-scope`. The worktree removal uses `rm -rf` plus `git worktree prune` after the human partner's approval.
3. Item 1's manual image check, only if Docker is available, reported either way: `scripts/evals-container build` on merged evals main, then `docker image inspect superpowers-evals:local --format '{{json .Config.Env}}'` must show the four `QUORUM_IMAGE_*` values (the commit and `true` for a clean checkout). If `scripts/evals-container up` succeeds, `scripts/evals-container exec bun -e "import { captureProvenance, defaultProvenanceDeps, renderProvenanceLine } from './src/runner/provenance.ts'; import { defaultCommandRunner } from './src/agents/command-runner.ts'; console.log(renderProvenanceLine(captureProvenance(defaultProvenanceDeps(defaultCommandRunner, process.cwd(), process.env.PATH ?? ''))));"` prints the `provenance:` line a run started there would show, with its `image` cells; a full container run would be a live eval, which this plan does not run. A build that fails (network, proxy) is reported with its error and does not block the merge.
4. Finishing, hyperpowers: the offline set (`docs/testing.md`) on the branch, each suite as its own command through `run-suites.sh`, with the brainstorm-server chain (`cd tests/brainstorm-server && npm test`) run three times; then the finishing skill.
5. Memory: update `release-hygiene-6-16-0.md` with the merged commits, and record that sub-project 2 (agent write isolation) and the `tests/` heredocs remain.
6. Ask the human partner whether hyperpowers ships 6.16.1 for Tasks 8 and 9.

**Correction (2026-10-13).** Two of this plan's own claims were wrong, and
execution caught both. Task 12 Step 2 says the test's existing empty-block
failure (lines 39-43 of `test-delivery-resolution.sh`) proves the new `sed`
end pattern matches. It does not: a range whose end pattern never matches
prints through end of file, which is non-empty, so that check proves only the
start anchor. On the converted subject the stale pattern yields 201 lines
against the intended 12, and an emptiness test cannot tell them apart; Task 12
added a guard requiring the extracted block's last line to match the end
anchor, and a mutant with the stale pattern fails it. Task 9's implementation
block puts apostrophes inside comment text in a single-quoted `node -e`
program (plan lines 1895, 1903-1905, 1926 and 1954); pasted verbatim that ends
the quoting and is a bash syntax error, so the implementer reworded those
comments and kept the code as written. Neither error reached the shipped code.
