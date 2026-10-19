# Agent Write Isolation by Relocation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-14-agent-write-isolation-relocation-design.md` (hyperpowers `bab5914`). The spec is binding; where this plan and the spec disagree, the spec governs and the disagreement is surfaced.

**Goal:** Move the Coding-Agent's workspace out of the run directory, stop post-check inner commands from inheriting the operator's environment, close the two measured trusted-layer code paths (Bun cwd config, git content filters), and prove all of it offline against the recorded corpus before three smokes and one paired control.

**Architecture:** The record stays at `<outRoot>/<run>/`; the agent's tree moves to `<outRoot>/workspaces/<run>/`. A single allowlist module projects two environments — outer (trusted scenario text plus tooling) and inner (agent-authored code) — and a `QUORUM_INNER_ENV` selector lets a counterfactual replay run the legacy and new inner behaviours through one executor, `runPhaseWithEnv`. Three downstream derivations that assumed agent content under the run directory (Kimi, Copilot, the Codex wrong-cwd detector) are re-rooted.

**Tech Stack:** TypeScript on Bun ≥ 1.3 (biome, tsc, bun test), bash 3.2-compatible scripts with `.test.sh` siblings, Python 3 for the campaign analyzer (ruff, mypy, unittest).

## Global Constraints

- Implementation repository: `hyperpowers-evals`; branch `agent-write-isolation-relocation` from `main` at `b6a923a31`. The Gauntlet fork is not touched.
- No change to any absolute path the Coding-Agent observes or records, other than the single `workspaces/` component the design introduces; no change to `coding-agents/*.yaml` or any `coding-agents/*-context/launch-agent`.
- No new runtime dependency.
- Suites run on `/bin/bash` 3.2.57 on a heavily loaded host; no short per-test timeouts (existing suites use 60 s where they need one).
- There is no CI; suites are run by hand, one script per `bash` invocation. `bun run check` (biome ci, tsc --noEmit, bun test) must pass at every commit, so a required field and every construction site land in the same commit.
- Exact names, used identically in every task: `workspaceDir`, `RunHome.runDir`, `RunPhaseArgs.agentHome`, `runPhaseWithEnv`, `QUORUM_AGENT_HOME`, `QUORUM_INNER_ENV` with values `projected` | `legacy`, `src/checks/env-allowlist.ts`, `scripts/replay-post-checks` → `src/cli/replay-post-checks.ts`.
- Bun dispatcher flags, verbatim: `--config="$QUORUM_REPO_ROOT/bunfig.toml" --env-file=/dev/null`. Git hygiene flags, verbatim: `-c core.fsmonitor=false -c core.hooksPath=/dev/null`.
- Evidence directory for every live-run artifact an evidence note cites: `evals/evidence/2026-10-14-agent-write-isolation-relocation/`. Nothing is cited from the SDD workspace.
- Commit messages follow the repository's `type(scope): sentence` style (`fix(runner): …`, `test(checks): …`, `docs: …`); no attribution lines of any kind. Before each commit, the staged diff passes `python3 ~/.claude/scripts/realval-scan.py` with `hits: 0`.
- Every commit in this plan lands in hyperpowers-evals, on the feature branch `agent-write-isolation-relocation` in an isolated worktree, never on `main`. Each task is reviewed by the SDD task reviewer and the per-task Codex gate before the next task starts; the human partner reviews the whole branch at Finish and decides whether it merges. The hyperpowers repository's own diff-approval rule (`CLAUDE.md:13`) governs commits to *that* repository, and this plan makes none there.
- `bun run check` runs immediately before **every** commit, including evidence-only commits and the fixture commits Task 11 may add.
- Biome's `noProcessEnv` is `error` tree-wide and its override is an **exact file list** (`biome.json:98-119`), not `test/**`: a test file that reads or plants `process.env` is added to that list in the same commit and `biome.json` is staged with it (Task 1: `test/checks.test.ts`; Task 4: `test/cli-run-helpers.ts`; Task 10: `test/replay-post-checks.test.ts`). Under `noPropertyAccessFromIndexSignature` (`tsconfig.json`) every `process.env` access is bracketed — `process.env['NAME']`, never dotted. Source and other tests read the environment through `getEnv`/`envSnapshot` (`src/env.ts`).
- Multi-command evidence runs (Tasks 11, 14, 15, 16) are committed bash scripts under the evidence directory and invoked as `bash <script>`: the interactive shell here is zsh, which has no `PIPESTATUS`, so a pipeline and its `${PIPESTATUS[0]}` capture must live together in a bash file.
- The spec's one deferred, Codex-unreviewed item is the quoting migration and its regression (spec, Verification item 7, "Review status"); Task 10 implements it and this plan's gate is its confirming review.

## Grounding

- Naming: kebab-case files under `src/checks/`, `src/check/`; camelCase functions; check verbs exported as `verbX` — `src/check/fs-verbs.ts:273` (`verbCommandSucceeds`).
- Error handling, runner: `RunnerError(message, 'setup')` thrown from the run body (`src/runner/index.ts:996-1001`), caught at `:907-917` where `compose` records `{ stage, message }` as an indeterminate verdict, the stage chosen by `errorStage` at `:950-963`. Provisioning: `ProvisionError` — `src/agents/kimi.ts:846-849`.
- Check outcome shape: `CheckOutcome { passed, detail, broken? }` with `pass()`, `fail()`, `broken()` helpers — `src/check/fs-verbs.ts:25-58`; the dispatcher exits 127 on `broken` — `src/cli/check-tool.ts:70-80`.
- The environment seam: `env.ts` is the only `process.env` reader; `getEnv(key)` and `envSnapshot()` — `src/env.ts:9-16`. `runPhase` builds the child env from `envSnapshot()` — `src/checks/index.ts:74-92`; spawn and exit discipline — `:95-142`; `RunPhaseArgs` — `:20-45`.
- Inner command spawn with no `env` — `src/check/fs-verbs.ts:278-282`. Git helpers `gitOk`/`gitOut` — `:486-495`; the `status --porcelain` spawn — `:380-382`. Verb context from `process.cwd()` — `:46-48`.
- Throwaway-home env, single source of truth: `xdgHomeEnv(homeDir)` — `src/agents/home-env.ts:12-21`.
- Prelude dispatchers, five `bun run` invocations — `src/checks/prelude.sh:20-21,28,31,34`.
- Runner layout derivations — `src/runner/index.ts:1103-1111`; package-scope sentinel — `:834-845`; `home` literal — `:1119-1126`; pre-phase call — `:1159-1167`; post-phase call — `:1524-1533`; Copilot cascade call — `:1486-1494`; detector call — `:1550-1557`; `allocateRunDir` — `:113-140`.
- `RunHome` — `src/agents/index.ts:27-34`. Kimi `runDir = dirname(workdir)` — `src/agents/kimi.ts:191-198`; artifact-root guard — `:829-850`.
- Copilot scan — `src/agents/copilot.ts:445-475`; cascade — `src/runner/index.ts:699-740`.
- Codex misplaced-rollout detector — `src/capture/index.ts:368-399` (containment test at `:396`).
- Dashboard: `parseRunDirName` — `src/dashboard/scan.ts:35`; unparseable names skipped — `:214-224`.
- `quorum check` lint to mirror — `src/scaffold.ts:192-199` (`$QUORUM_WORKDIR`); its test — `test/scaffold.test.ts` "checkScenario flags a $QUORUM_WORKDIR reference".
- `strip-runs`: paths — `scripts/strip-runs:42-52`; candidates and liveness — `:84-113`; strip loop — `:116-131`. Test shape — `scripts/strip-runs.test.sh` (temp results root, `fail()` helper, `PASS:` line).
- Test shapes: layout — `test/runner-workdir-scope.test.ts` (whole file); `runPhase` — `test/checks.test.ts:15-40,277-290`; verbs direct and through the prelude — `test/check-tool.test.ts:1-32`; detector — `test/capture.test.ts` "detectMisplacedCodexRollouts flags rollouts inside run_dir at a wrong cwd"; dashboard — `test/dashboard-scan.test.ts` `writeRun()`; Copilot — `test/runner-copilot-cascade.test.ts:19-46`; Kimi guard — `test/agent-kimi.test.ts:909-950`; shared fixture — `test/provision-helpers.ts:9-26`; direct `RunHome` literal — `test/agent-codex-plugin-stage.test.ts:129-134`; SIGINT enumeration — `test/cli-run-sigint.test.ts:262-280`; TDD oracle — `test/scenario-tdd-project-suite.test.ts:203-213`.
- Python analyzer conventions: rST docstrings, `main() -> int`, `sys.exit(main())` — `evidence/2026-10-03-clean-harness-rebaseline/tally.py:1-36,435-446`; readouts and the `own` path shape — `:156-182`; manipulation exclusion — `:353-363,378-404`. `none: no existing Python test convention in evidence/`; this plan uses `python3 -m unittest`.
- Scripts convention: bash scripts in `scripts/` with a sibling `.test.sh`; `none: no existing scripts/ wrapper over bun run` — Task 9 introduces one, mirroring `scripts/strip-runs`' header style.
- Commit style — `git log --oneline -8` on evals `main` (`fix(container): …`, `test(focus-arm): …`).

---

## Before Task 1

- [ ] Create the worktree with `hyperpowers:using-git-worktrees`: branch `agent-write-isolation-relocation` from `main` at `b6a923a31`, under `evals/.worktrees/`. In that worktree run `bun install` (no network beyond the registry already cached) and `bun run check`; record the baseline result in the SDD ledger. Known: 7 load-timeout failures on a loaded host pass on re-run with `--timeout 60000` (sub-project 1 record).

---

### Task 1: Environment allowlist module and the explicit-environment executor

**Risk tier:** high — the allowlist is the credential boundary for every post-check; `runPhase` feeds the record sink.

**Files:**
- Create: `src/checks/env-allowlist.ts`
- Modify: `src/checks/index.ts:20-45` (`RunPhaseArgs`), `:62-143` (`runPhase` → `runPhaseWithEnv` + wrapper)
- Modify: `src/runner/index.ts:1159-1167` and `:1524-1533` (pass `agentHome: runHomeDir`)
- Modify: `test/checks.test.ts` (fifteen `runPhase({…})` constructions gain `agentHome`)
- Test: `test/env-allowlist.test.ts` (new), `test/checks.test.ts` (two new cases)
- Modify: `biome.json:98-119` (add `test/checks.test.ts` to the `noProcessEnv` override list: Step 7 plants a key through `process.env`)

**Interfaces:**
- Consumes: `xdgHomeEnv(homeDir): Record<string,string>` from `src/agents/home-env.ts`; `envSnapshot()`, `getEnv()` from `src/env.ts`.
- Produces:
  ```ts
  // src/checks/env-allowlist.ts
  export const OUTER_PASSTHROUGH: readonly string[]; // PATH HOME TMPDIR LANG + proxies (6 names)
  export const INNER_REMOVED: readonly string[];     // QUORUM_RECORD_SINK QUORUM_REPO_ROOT QUORUM_TRANSCRIPT_PATH QUORUM_RUN_DIR QUORUM_INNER_ENV
  export type InnerMode = 'projected' | 'legacy';
  export interface OuterEnvArgs {
    readonly repoRoot: string; readonly agentHome: string;
    readonly transcriptPath?: string; readonly runDir?: string;
    readonly configDir?: string; readonly codingAgent?: string;
  }
  export function outerEnv(base: Readonly<Record<string, string | undefined>>, args: OuterEnvArgs): Record<string, string>;
  export function innerMode(lookup: (k: string) => string | undefined): InnerMode;   // absent => 'legacy'
  export function innerEnv(base: Readonly<Record<string, string | undefined>>, agentHome: string): Record<string, string>;
  export function legacyInnerEnv(base: Readonly<Record<string, string | undefined>>): Record<string, string>;
  // src/checks/index.ts
  export interface RunPhaseArgs { …existing…; readonly agentHome: string; }  // now required
  export function runPhaseWithEnv(args: RunPhaseArgs, env: Record<string, string>): Promise<RunPhaseResult>;
  export function runPhase(args: RunPhaseArgs): Promise<RunPhaseResult>; // = runPhaseWithEnv(args, outerEnv(envSnapshot(), …))
  ```
  Semantics fixed here and relied on by Tasks 2, 9, 10: `outerEnv` never carries `QUORUM_RECORD_SINK` — `runPhaseWithEnv` creates the sink and overlays `QUORUM_RECORD_SINK` itself; `outerEnv` sets `QUORUM_INNER_ENV: 'projected'`; `innerEnv` **allowlists its base independently** — it keeps only names in `OUTER_PASSTHROUGH`, names starting `LC_`, and names starting `QUORUM_` — then removes every `INNER_REMOVED` name and overlays all six `xdgHomeEnv(agentHome)` keys, so a dispatcher that is handed an ambient environment (a test, a hand invocation) still drops credentials; `legacyInnerEnv` removes only `QUORUM_INNER_ENV`; both drop `undefined` values. `innerMode` returns `'legacy'` when the selector is absent — production always sets it through `runPhase`, and the absent case exists only for a dispatcher invoked outside `runPhase` (tests, by hand), where inheriting is today's behaviour.

**Mirror:** `src/checks/index.ts:74-92` for how the current env literal is assembled (conditional spreads keep names as object properties, not index-signature reads); `test/checks.test.ts:15-40` for the `runPhase` test shape.

- [ ] **Step 1: Write the failing allowlist tests**

```ts
// test/env-allowlist.test.ts
import { expect, test } from 'bun:test';
import { xdgHomeEnv } from '../src/agents/home-env.ts';
import {
  INNER_REMOVED,
  OUTER_PASSTHROUGH,
  innerEnv,
  innerMode,
  legacyInnerEnv,
  outerEnv,
} from '../src/checks/env-allowlist.ts';

const BASE = {
  PATH: '/usr/bin:/bin',
  HOME: '/Users/operator',
  TMPDIR: '/tmp/op',
  LANG: 'en_US.UTF-8',
  LC_ALL: 'C',
  HTTPS_PROXY: 'http://proxy.example:8080',
  ANTHROPIC_API_KEY: 'sk-planted',
  OPENAI_API_KEY: 'planted',
  AWS_SECRET_ACCESS_KEY: 'planted',
  QUORUM_RECORD_SINK: '/tmp/sink/records.jsonl',
  UNRELATED: 'x',
};
const ARGS = {
  repoRoot: '/repo',
  agentHome: '/out/workspaces/run-1/home',
  transcriptPath: '/out/run-1/trajectory.json',
  runDir: '/out/run-1',
  configDir: '/out/workspaces/run-1/home/.claude',
  codingAgent: 'claude-auto',
};

test('outerEnv passes exactly the passthrough names, LC_*, and the QUORUM contract; nothing else', () => {
  const env = outerEnv(BASE, ARGS);
  for (const k of OUTER_PASSTHROUGH) {
    if (k in BASE) expect(env[k]).toBe(BASE[k as keyof typeof BASE]);
  }
  expect(env['LC_ALL']).toBe('C');
  expect(env['QUORUM_REPO_ROOT']).toBe('/repo');
  expect(env['QUORUM_AGENT_HOME']).toBe(ARGS.agentHome);
  expect(env['QUORUM_TRANSCRIPT_PATH']).toBe(ARGS.transcriptPath);
  expect(env['QUORUM_RUN_DIR']).toBe(ARGS.runDir);
  expect(env['QUORUM_AGENT_CONFIG_DIR']).toBe(ARGS.configDir);
  expect(env['QUORUM_CODING_AGENT']).toBe('claude-auto');
  expect(env['QUORUM_INNER_ENV']).toBe('projected');
  expect(env['ANTHROPIC_API_KEY']).toBeUndefined();
  expect(env['OPENAI_API_KEY']).toBeUndefined();
  expect(env['AWS_SECRET_ACCESS_KEY']).toBeUndefined();
  expect(env['UNRELATED']).toBeUndefined();
  // The sink is the executor's to add, never the allowlist's.
  expect(env['QUORUM_RECORD_SINK']).toBeUndefined();
  // Exactness over the constructed object: nothing else is present.
  expect(Object.keys(env).sort()).toEqual(
    ['HOME', 'HTTPS_PROXY', 'LANG', 'LC_ALL', 'PATH', 'QUORUM_AGENT_CONFIG_DIR', 'QUORUM_AGENT_HOME', 'QUORUM_CODING_AGENT', 'QUORUM_INNER_ENV', 'QUORUM_REPO_ROOT', 'QUORUM_RUN_DIR', 'QUORUM_TRANSCRIPT_PATH', 'TMPDIR'].sort(),
  );
});

test('outerEnv falls back to the system PATH when the parent has none', () => {
  const { PATH: _p, ...noPath } = BASE;
  expect(outerEnv(noPath, ARGS).PATH).toBe('/usr/bin:/bin');
});

test('innerEnv removes the record and tooling names and overlays the agent home, from an ambient base too', () => {
  // Handed the AMBIENT environment (planted key included), not the outer
  // projection: the inner layer must still come out clean.
  const inner = innerEnv({ ...BASE, ...outerEnv(BASE, ARGS), QUORUM_RECORD_SINK: '/tmp/sink/records.jsonl' }, ARGS.agentHome);
  for (const k of INNER_REMOVED) expect(inner[k]).toBeUndefined();
  expect(inner).toMatchObject(xdgHomeEnv(ARGS.agentHome));
  expect(inner['HOME']).toBe(ARGS.agentHome);
  expect(inner['QUORUM_AGENT_HOME']).toBe(ARGS.agentHome);
  expect(inner['QUORUM_AGENT_CONFIG_DIR']).toBe(ARGS.configDir);
  expect(inner['QUORUM_CODING_AGENT']).toBe('claude-auto');
  expect(inner['ANTHROPIC_API_KEY']).toBeUndefined();
  expect(Object.keys(inner).sort()).toEqual(
    ['HOME', 'HTTPS_PROXY', 'LANG', 'LC_ALL', 'PATH', 'QUORUM_AGENT_CONFIG_DIR', 'QUORUM_AGENT_HOME', 'QUORUM_CODING_AGENT', 'TMPDIR', 'XDG_CACHE_HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME'].sort(),
  );
});

test('legacyInnerEnv inherits everything except the selector', () => {
  const legacy = legacyInnerEnv({ ...BASE, QUORUM_INNER_ENV: 'legacy' });
  expect(legacy.QUORUM_INNER_ENV).toBeUndefined();
  expect(legacy.HOME).toBe('/Users/operator');
  expect(legacy.QUORUM_RECORD_SINK).toBe('/tmp/sink/records.jsonl');
  expect(legacy.ANTHROPIC_API_KEY).toBe('sk-planted');
});

test('innerMode reads the selector and treats absence as legacy', () => {
  const lookup = (env: Record<string, string>) => (k: string) => env[k]; // typed: a bare literal cannot be indexed by an arbitrary string under strict TS
  expect(innerMode(lookup({ QUORUM_INNER_ENV: 'projected' }))).toBe('projected');
  expect(innerMode(lookup({ QUORUM_INNER_ENV: 'legacy' }))).toBe('legacy');
  expect(innerMode(() => undefined)).toBe('legacy');
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test test/env-allowlist.test.ts`
Expected: FAIL — `Cannot find module '../src/checks/env-allowlist.ts'`.

- [ ] **Step 3: Write the module**

```ts
// src/checks/env-allowlist.ts
import { xdgHomeEnv } from '../agents/home-env.ts';

// The two environments a check phase runs under (spec, "Post-check
// environment"). The outer layer is trusted scenario text plus the check
// tooling; the inner layer is whatever `command-succeeds` executes, which may
// be code the agent wrote. One module owns both lists so the boundary is read
// in one place.

/** Names copied from the parent into the outer layer when present. */
export const OUTER_PASSTHROUGH: readonly string[] = [
  'PATH',
  'HOME',
  'TMPDIR',
  'LANG',
  'HTTP_PROXY',
  'HTTPS_PROXY',
  'NO_PROXY',
  'http_proxy',
  'https_proxy',
  'no_proxy',
];

/** Names the inner layer never sees: the record's input and the harness
 *  checkout, plus the selector itself. */
export const INNER_REMOVED: readonly string[] = [
  'QUORUM_RECORD_SINK',
  'QUORUM_REPO_ROOT',
  'QUORUM_TRANSCRIPT_PATH',
  'QUORUM_RUN_DIR',
  'QUORUM_INNER_ENV',
];

export type InnerMode = 'projected' | 'legacy';

export interface OuterEnvArgs {
  readonly repoRoot: string;
  readonly agentHome: string;
  readonly transcriptPath?: string;
  readonly runDir?: string;
  readonly configDir?: string;
  readonly codingAgent?: string;
}

type Env = Readonly<Record<string, string | undefined>>;

function defined(env: Env): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(env)) {
    if (v !== undefined) out[k] = v;
  }
  return out;
}

/** The outer-layer environment. Never includes the record sink: the executor
 *  creates the sink and overlays it, so no caller can forget it. */
export function outerEnv(base: Env, args: OuterEnvArgs): Record<string, string> {
  const out: Record<string, string> = {};
  for (const k of OUTER_PASSTHROUGH) {
    const v = base[k];
    if (v !== undefined) out[k] = v;
  }
  for (const [k, v] of Object.entries(base)) {
    if (k.startsWith('LC_') && v !== undefined) out[k] = v;
  }
  out['PATH'] = out['PATH'] ?? '/usr/bin:/bin';
  out['QUORUM_REPO_ROOT'] = args.repoRoot;
  out['QUORUM_AGENT_HOME'] = args.agentHome;
  if (args.transcriptPath !== undefined) out['QUORUM_TRANSCRIPT_PATH'] = args.transcriptPath;
  if (args.runDir !== undefined) out['QUORUM_RUN_DIR'] = args.runDir;
  if (args.configDir !== undefined) out['QUORUM_AGENT_CONFIG_DIR'] = args.configDir;
  if (args.codingAgent !== undefined) out['QUORUM_CODING_AGENT'] = args.codingAgent;
  out['QUORUM_INNER_ENV'] = 'projected';
  return out;
}

/** Which inner construction the dispatcher applies. Absent means legacy:
 *  production always sets the selector through runPhase; a dispatcher run
 *  outside it (tests, by hand) keeps today's inheritance. */
export function innerMode(lookup: (k: string) => string | undefined): InnerMode {
  return lookup('QUORUM_INNER_ENV') === 'projected' ? 'projected' : 'legacy';
}

/** The inner-layer environment. The base is allowlisted here again, not
 *  trusted to be the outer layer already: a dispatcher run outside runPhase
 *  (a test, a hand invocation) hands this the ambient environment, and the
 *  inner layer must never carry a credential whichever way it was reached. */
export function innerEnv(base: Env, agentHome: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(base)) {
    if (v === undefined) continue;
    if (OUTER_PASSTHROUGH.includes(k) || k.startsWith('LC_') || k.startsWith('QUORUM_')) out[k] = v;
  }
  for (const k of INNER_REMOVED) delete out[k];
  return { ...out, ...xdgHomeEnv(agentHome) };
}

/** Today's inheritance, minus the selector so no nested process can see it. */
export function legacyInnerEnv(base: Env): Record<string, string> {
  const out = defined(base);
  delete out['QUORUM_INNER_ENV'];
  return out;
}
```

- [ ] **Step 4: Run the allowlist tests**

Run: `bun test test/env-allowlist.test.ts`
Expected: PASS (5 tests).

- [ ] **Step 5: Split the executor and make `agentHome` required**

In `src/checks/index.ts`: add `readonly agentHome: string;` to `RunPhaseArgs` with the doc comment `/** The agent's throwaway home; exported as QUORUM_AGENT_HOME and the root the inner projection overlays HOME/XDG/TMPDIR from. */`. Replace the body of `runPhase` so that:

```ts
import { envSnapshot } from '../env.ts';
import { outerEnv } from './env-allowlist.ts';

/** Run one phase under an explicit environment. The sink is created here and
 *  overlaid as QUORUM_RECORD_SINK, so a caller cannot forget it. Production
 *  calls runPhase; the corpus replay calls this twice with two environments. */
export async function runPhaseWithEnv(
  args: RunPhaseArgs,
  env: Record<string, string>,
): Promise<RunPhaseResult> {
  const sinkDir = mkdtempSync(join(tmpdir(), 'sink-'));
  const sink = join(sinkDir, 'records.jsonl');
  const prelude = join(args.repoRoot, 'src', 'checks', 'prelude.sh');
  const childEnv: Record<string, string> = { ...env, QUORUM_RECORD_SINK: sink };
  try {
    // …the existing spawnSync / readRecords / signal / rc block, unchanged,
    // with `env: childEnv` in place of `env`…
  } finally {
    rmSync(sinkDir, { recursive: true, force: true });
  }
}

export async function runPhase(args: RunPhaseArgs): Promise<RunPhaseResult> {
  return runPhaseWithEnv(
    args,
    outerEnv(envSnapshot(), {
      repoRoot: args.repoRoot,
      agentHome: args.agentHome,
      ...(args.transcriptPath !== undefined ? { transcriptPath: args.transcriptPath } : {}),
      ...(args.runDir !== undefined ? { runDir: args.runDir } : {}),
      ...(args.configDir !== undefined ? { configDir: args.configDir } : {}),
      ...(args.codingAgent !== undefined ? { codingAgent: args.codingAgent } : {}),
    }),
  );
}
```

Delete the old inline env literal (`:74-92`) and its comment; keep the spawn, record-read and exit-code discipline byte-identical otherwise.

- [ ] **Step 6: Thread `agentHome` through both production calls and the test file**

`src/runner/index.ts:1159-1167` (pre) and `:1524-1533` (post): add `agentHome: runHomeDir,` to each argument literal. Nothing else in either literal changes: production passes `runDir` to **both** phases and `transcriptPath` only to post, and that is the contract Task 10's replay mirrors and Task 12's table documents. `test/checks.test.ts`: add `agentHome: workdir,` (or any existing temp dir the test already creates) to each of the fifteen `runPhase({…})` literals — `tsc --noEmit` lists every one that is missing.

- [ ] **Step 7: Witness the outer bash environment, exactly, in both phases**

The outer shell is where `checks.sh` itself runs. Dump its environment from
inside `pre()` and `post()` — not through `command-succeeds`, which is the
inner layer — and assert the exact key set, ignoring only what bash creates
(`PWD`, `OLDPWD`, `SHLVL`, `_`). The calls use the two production argument shapes, so the dump is also the witness that `QUORUM_TRANSCRIPT_PATH` is post-only and `QUORUM_RUN_DIR` is present in both phases. Append to `test/checks.test.ts`:

```ts
const BASH_CREATED = new Set(['PWD', 'OLDPWD', 'SHLVL', '_']);
const OUTER_KEYS = ['PATH', 'HOME', 'QUORUM_REPO_ROOT', 'QUORUM_RECORD_SINK', 'QUORUM_AGENT_HOME', 'QUORUM_INNER_ENV'];

function keysOfDump(path: string): string[] {
  return readFileSync(path, 'utf8').split('\n').filter((l) => l.includes('=')).map((l) => l.slice(0, l.indexOf('='))).filter((k) => !BASH_CREATED.has(k)).sort();
}

for (const phase of ['pre', 'post'] as const) {
  test(`the outer bash in ${phase} sees exactly the allowlist plus the sink, and no planted key`, async () => {
    const workdir = mkdtempSync(join(tmpdir(), 'wd-'));
    const home = mkdtempSync(join(tmpdir(), 'home-'));
    const dump = join(home, `outer-${phase}.txt`);
    const body = `env | sort > '${dump}'\n  file-exists present.txt`;
    writeFileSync(join(workdir, 'present.txt'), '');
    const checksSh = checksShWith(phase === 'pre' ? `pre() {\n  ${body}\n}\npost() { :; }\n` : `pre() { :; }\npost() {\n  ${body}\n}\n`);
    const prev = process.env['ANTHROPIC_API_KEY'];
    process.env['ANTHROPIC_API_KEY'] = 'sk-planted';
    try {
      // Production shapes (src/runner/index.ts:1159-1167, 1524-1533): pre carries
      // the run dir but no transcript; post carries both.
      const runDir = mkdtempSync(join(tmpdir(), 'run-'));
      const transcript = join(runDir, 'trajectory.json');
      writeFileSync(transcript, '[]');
      const base = { checksSh, workdir, repoRoot: REPO, runDir, configDir: join(home, '.claude'), codingAgent: 'claude', agentHome: home };
      const { exitCode } = await runPhase(phase === 'pre' ? { ...base, phase } : { ...base, phase, transcriptPath: transcript });
      expect(exitCode).toBe(0);
    } finally {
      if (prev === undefined) delete process.env['ANTHROPIC_API_KEY']; else process.env['ANTHROPIC_API_KEY'] = prev;
    }
    const phaseKeys = ['QUORUM_RUN_DIR', 'QUORUM_AGENT_CONFIG_DIR', 'QUORUM_CODING_AGENT', ...(phase === 'post' ? ['QUORUM_TRANSCRIPT_PATH'] : [])];
    const expected = [...OUTER_KEYS, ...phaseKeys, ...Object.keys(process.env).filter((k) => k === 'TMPDIR' || k === 'LANG' || k.startsWith('LC_') || /^(https?|no)_proxy$/i.test(k))].sort();
    expect(keysOfDump(dump)).toEqual([...new Set(expected)].sort());
  });
}
```

(These tests plant and read `process.env` directly. Biome's `noProcessEnv`
override is an exact file list (`biome.json:98-119`) that does not include
`test/checks.test.ts`: add it there in this task, or `bun run lint` fails.
Access is bracketed, `process.env['NAME']`, under `noPropertyAccessFromIndexSignature`.) These pass with Task 1 alone: they look at the
outer shell, which Task 1 delivers.

- [ ] **Step 8: Run the gate**

Run: `bun run check`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/checks/env-allowlist.ts src/checks/index.ts src/runner/index.ts test/env-allowlist.test.ts test/checks.test.ts biome.json
git commit -m "feat(checks): one allowlist projects the outer and inner check environments, and runPhase takes its environment explicitly"
```

---

### Task 2: The inner projection in `command-succeeds` and the harness's git spawns

**Risk tier:** high — this is where agent-authored code loses the operator's environment; the git change closes a measured code path.

**Files:**
- Modify: `src/check/fs-verbs.ts:273-296` (`verbCommandSucceeds`), `:486-495` (`gitOk`, `gitOut`), `:380-382` (status spawn)
- Test: `test/check-tool.test.ts` (six new cases), `test/checks.test.ts` (two new cases)

**Interfaces:**
- Consumes: `innerMode`, `innerEnv`, `legacyInnerEnv` from Task 1; `envSnapshot`, `getEnv` from `src/env.ts`; `broken()` from `fs-verbs.ts:56`.
- Produces: a private `nestedEnv(ctx): Record<string,string> | { broken: string }` used by `verbCommandSucceeds`, `gitOk`, `gitOut` and the status spawn; the constant `GIT_HYGIENE = ['-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null']`.

**Mirror:** `src/check/fs-verbs.ts:273-296` (keep the 500-byte detail rule); `test/check-tool.test.ts` "command-succeeds: exit 0 passes" for the direct-call shape. Note `ctxFor(cwd, env)` (`test/check-tool.test.ts:39-41`) takes an explicit env map and does not read `process.env`: the selector and the agent home go through that map; the ambient base the projection filters is planted through `process.env` (`envSnapshot()`).

- [ ] **Step 1: Write the failing tests**

Append to `test/check-tool.test.ts`:

```ts
// Every verb these tests call is already in the file's import list
// (test/check-tool.test.ts:15-26); add only `existsSync` to its node:fs import.

function withEnv<T>(vars: Record<string, string | undefined>, fn: () => T): T {
  const saved: Record<string, string | undefined> = {};
  for (const [k, v] of Object.entries(vars)) {
    saved[k] = process.env[k];
    if (v === undefined) delete process.env[k]; else process.env[k] = v;
  }
  try { return fn(); } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k]; else process.env[k] = v;
    }
  }
}

test('command-succeeds under QUORUM_INNER_ENV=projected: agent home, no sink, no selector, no planted key', () => {
  const wd = workdir();
  const home = mkdtempSync(join(tmpdir(), 'agent-home-'));
  // Selector and agent home arrive through the context; the ambient base
  // (what envSnapshot() returns) carries the sink and a planted key.
  const ctx = ctxFor(wd, { QUORUM_INNER_ENV: 'projected', QUORUM_AGENT_HOME: home });
  const out = withEnv(
    { QUORUM_RECORD_SINK: '/tmp/planted-sink', ANTHROPIC_API_KEY: 'sk-planted', QUORUM_AGENT_HOME: home },
    () => verbCommandSucceeds(
      [`test "$HOME" = "${home}" && test -z "\${QUORUM_RECORD_SINK:-}" && test -z "\${QUORUM_INNER_ENV:-}" && test -z "\${ANTHROPIC_API_KEY:-}" && test "$QUORUM_AGENT_HOME" = "${home}"`],
      ctx,
    ),
  );
  expect(out.passed).toBe(true);
});

test('command-succeeds under QUORUM_INNER_ENV=legacy: inherits, selector stripped', () => {
  const wd = workdir();
  const out = withEnv(
    { QUORUM_INNER_ENV: 'legacy', QUORUM_RECORD_SINK: '/tmp/planted-sink' },
    () => verbCommandSucceeds(
      ['test "$QUORUM_RECORD_SINK" = /tmp/planted-sink && test -z "${QUORUM_INNER_ENV:-}"'],
      ctxFor(wd, { QUORUM_INNER_ENV: 'legacy' }),
    ),
  );
  expect(out.passed).toBe(true);
});

test('command-succeeds: projected without QUORUM_AGENT_HOME is a broken check, not a silent inherit', () => {
  const wd = workdir();
  const out = verbCommandSucceeds(['true'], ctxFor(wd, { QUORUM_INNER_ENV: 'projected' }));
  expect(out.broken).toBe(true);
  expect(out.detail).toContain('QUORUM_AGENT_HOME');
});

function gitRepoWith(configure: (git: (args: string[]) => void, wd: string) => void): string {
  const wd = workdir();
  const git = (args: string[]) => { const r = spawnSync('git', args, { cwd: wd, encoding: 'utf8' }); if (r.status !== 0) throw new Error(r.stderr); };
  git(['init', '-q']); git(['config', 'user.email', 'a@b']); git(['config', 'user.name', 't']);
  writeFile(wd, 'a.txt', 'hello\n');
  git(['add', '-A']); git(['commit', '-qm', 'init']);
  configure(git, wd); // after the commit, so no setup command ever runs the hook or filter under test
  return wd;
}

test('git verbs: projected mode without QUORUM_AGENT_HOME is a broken check, never a pass', () => {
  const wd = gitRepoWith(() => {});
  const clean = verbGitClean([], ctxFor(wd, { QUORUM_INNER_ENV: 'projected' }));
  expect(clean.broken).toBe(true);
  expect(clean.passed).toBe(false);
  // gitOut returning '' here would have made `git-branch detached` pass.
  const detached = verbGitBranch(['detached'], ctxFor(wd, { QUORUM_INNER_ENV: 'projected' }));
  expect(detached.broken).toBe(true);
});

test('git-clean: a configured core.fsmonitor does not run under a harness git verb', () => {
  const mark = join(mkdtempSync(join(tmpdir(), 'mark-')), 'seen');
  const hook = join(mkdtempSync(join(tmpdir(), 'fsm-')), 'fsmonitor.sh');
  writeFileSync(hook, `#!/bin/sh\nprintf 'ran\\n' >> "${mark}"\nprintf '/'\n`);
  spawnSync('chmod', ['+x', hook]);
  const wd = gitRepoWith((git) => git(['config', 'core.fsmonitor', hook]));
  writeFile(wd, 'a.txt', 'hellp\n');
  expect(existsSync(mark)).toBe(false); // precondition: fixture setup never ran the hook
  const out = verbGitClean([], ctxFor(wd, { QUORUM_INNER_ENV: 'legacy' }));
  expect(out.passed).toBe(false); // dirty tree; the point is the marker
  expect(existsSync(mark)).toBe(false);
});

test('git-clean: a configured clean filter runs under the inner projection, not the dispatcher environment', () => {
  // Measured during design: `git status --porcelain` with the hygiene flags
  // still invokes filter.<driver>.clean on a same-size change and on a
  // stat-dirty unmodified file. The filter must therefore see the agent home
  // and no record sink.
  const home = mkdtempSync(join(tmpdir(), 'agent-home-'));
  const mark = join(mkdtempSync(join(tmpdir(), 'mark-')), 'seen');
  const filter = join(mkdtempSync(join(tmpdir(), 'flt-')), 'clean.sh');
  writeFileSync(filter, `#!/bin/sh\nprintf 'HOME=%s SINK=%s\\n' "$HOME" "\${QUORUM_RECORD_SINK:-unset}" >> "${mark}"\ncat\n`);
  spawnSync('chmod', ['+x', filter]);
  const wd = gitRepoWith((git, d) => { git(['config', 'filter.probe.clean', filter]); writeFile(d, '.gitattributes', '*.txt filter=probe\n'); });
  writeFile(wd, 'a.txt', 'hellp\n'); // same size: status must re-hash through the filter
  writeFileSync(mark, '');
  const out = withEnv(
    { QUORUM_RECORD_SINK: '/tmp/planted-sink', QUORUM_AGENT_HOME: home },
    () => verbGitClean([], ctxFor(wd, { QUORUM_INNER_ENV: 'projected', QUORUM_AGENT_HOME: home })),
  );
  expect(out.passed).toBe(false); // the tree is dirty; that is not the point
  const seen = readFileSync(mark, 'utf8');
  expect(seen).toContain(`HOME=${home}`);
  expect(seen).toContain('SINK=unset');
});
```

(`workdir()`, `ctxFor()`, `writeFile()` are the file's existing helpers at `test/check-tool.test.ts:35-48`; `existsSync` joins the import list.)

- [ ] **Step 2: Run to verify they fail**

Run: `bun test test/check-tool.test.ts -t "QUORUM_INNER_ENV|clean filter|broken check"`
Expected: FAIL — the projected case sees the operator HOME; the broken case passes instead of breaking; the filter sees `SINK=/tmp/planted-sink`.

- [ ] **Step 3: Implement the nested environment and apply it**

In `src/check/fs-verbs.ts`:

```ts
import { envSnapshot } from '../env.ts';
import { innerEnv, innerMode, legacyInnerEnv } from '../checks/env-allowlist.ts';

const GIT_HYGIENE = ['-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null'];

// The environment every process below the dispatcher gets: an inner command,
// or a git subprocess whose repository may configure a content filter. Under
// `projected` it is the inner projection; under `legacy` (or no selector) it is
// the dispatcher's own environment minus the selector. A projected dispatcher
// with no agent home is a configuration error, surfaced as a broken check.
function nestedEnv(
  ctx: CheckContext,
): { env: Record<string, string> } | { broken: string } {
  const base = envSnapshot();
  if (innerMode(ctx.env) === 'legacy') return { env: legacyInnerEnv(base) };
  const home = ctx.env('QUORUM_AGENT_HOME');
  if (home === undefined || home === '') {
    return { broken: 'QUORUM_INNER_ENV=projected but QUORUM_AGENT_HOME is unset' };
  }
  return { env: innerEnv(base, home) };
}
```

`verbCommandSucceeds`: before the spawn, `const nested = nestedEnv(ctx); if ('broken' in nested) return broken(nested.broken);` then pass `env: nested.env` to `spawnSync`. Every git verb — `verbGitRepo` (`:300`), `verbGitBranch` (`:311`), `verbGitClean` (`:326`), `verbGitCount` (`:349,352`) and `verbAssertCheckoutClean` (`:377,380,394,398`) — begins with the same two lines as `verbCommandSucceeds`: `const nested = nestedEnv(ctx); if ('broken' in nested) return broken(nested.broken);`. `gitOk(cwd, gitArgs, env)` and `gitOut(cwd, gitArgs, env)` take the resolved env as a third parameter, prepend `GIT_HYGIENE` to `gitArgs` and pass `env` to `spawnSync`; the status spawn at `:380` gets the same flags and env. A broken projection therefore surfaces as a broken check from every git verb — never as `false`/`''`, which would let `git-clean`, `git-branch detached` or a zero `git-count` pass by accident. The git verbs do not change semantics: the flags only suppress hook and fsmonitor execution, and the env only decides what a filter sees.

- [ ] **Step 4: The inner layer through `runPhase`, both phases**

Append to `test/checks.test.ts` — the production path, outer allowlist and inner projection together:

```ts
for (const phase of ['pre', 'post'] as const) {
  test(`in ${phase}, an inner command runs under the agent home with no sink, selector or planted key`, async () => {
    const workdir = mkdtempSync(join(tmpdir(), 'wd-'));
    const home = mkdtempSync(join(tmpdir(), 'home-'));
    const cmd = 'command-succeeds \'test "$HOME" = "$QUORUM_AGENT_HOME" && test -z "${QUORUM_RECORD_SINK:-}" && test -z "${QUORUM_INNER_ENV:-}" && test -z "${ANTHROPIC_API_KEY:-}" && test -z "${QUORUM_RUN_DIR:-}"\'';
    const checksSh = checksShWith(phase === 'pre' ? `pre() {\n  ${cmd}\n}\npost() { :; }\n` : `pre() { :; }\npost() {\n  ${cmd}\n}\n`);
    const prev = process.env['ANTHROPIC_API_KEY'];
    process.env['ANTHROPIC_API_KEY'] = 'sk-planted';
    try {
      const { records, exitCode } = await runPhase({ checksSh, phase, workdir, repoRoot: REPO, agentHome: home, runDir: '/record/run' });
      expect(exitCode).toBe(0);
      expect(records[0]).toMatchObject({ check: 'command-succeeds', passed: true });
    } finally {
      if (prev === undefined) delete process.env['ANTHROPIC_API_KEY']; else process.env['ANTHROPIC_API_KEY'] = prev;
    }
  });
}
```

Run: `bun test test/check-tool.test.ts test/checks.test.ts`
Expected: PASS.

- [ ] **Step 5: Gate and commit**

Run: `bun run check` — Expected: PASS.

```bash
git add src/check/fs-verbs.ts test/check-tool.test.ts test/checks.test.ts
git commit -m "fix(checks): inner commands and the harness's git spawns run under the inner projection, selected by QUORUM_INNER_ENV"
```

---

### Task 3: Prelude dispatcher hardening — five Bun invocations

**Risk tier:** high — measured defect in the trusted layer: a workdir `bunfig.toml` preload executes and a workdir `.env` loads on every dispatcher call today.

**Files:**
- Modify: `src/checks/prelude.sh:20-21,28,31,34`
- Test: `test/prelude-dispatcher-config.test.ts` (new)

**Interfaces:**
- Consumes: nothing new.
- Produces: every `bun run` in the prelude reads `--config="$QUORUM_REPO_ROOT/bunfig.toml" --env-file=/dev/null`. The repository's `bunfig.toml` (`[test] root = "test"`) is the trusted configuration.

**Mirror:** `test/check-tool.test.ts:3-6` describes the end-to-end shape (source the prelude, call a verb function, assert the record); `test/prelude-record-equality.test.ts` is an existing prelude-sourcing test to imitate for the bash invocation.

- [ ] **Step 1: Write the failing test**

```ts
// test/prelude-dispatcher-config.test.ts
import { expect, test } from 'bun:test';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { getEnv } from '../src/env.ts';

const REPO = resolve(import.meta.dir, '..');
const PRELUDE = resolve(REPO, 'src', 'checks', 'prelude.sh');

// Measured during design on Bun 1.4.2: a plain `bun run <abs script>` from a
// workdir holding a bunfig.toml preload executes the preload and loads the
// workdir .env. Every prelude dispatcher runs with cwd = the agent workdir.
function plantedWorkdir(): { wd: string; mark: string } {
  const wd = mkdtempSync(join(tmpdir(), 'planted-wd-'));
  const mark = join(wd, 'preload-ran');
  writeFileSync(join(wd, 'bunfig.toml'), 'preload = ["./p.ts"]\n');
  writeFileSync(join(wd, 'p.ts'), `require("node:fs").writeFileSync(${JSON.stringify(mark)}, "ran\\n");\n`);
  writeFileSync(join(wd, '.env'), 'QUORUM_PROBE_DOTENV=leaked\n');
  return { wd, mark };
}

function bashInWorkdir(wd: string, script: string, sink: string) {
  return spawnSync('bash', ['-c', `source '${PRELUDE}'; ${script}`], {
    cwd: wd,
    encoding: 'utf8',
    env: { PATH: getEnv('PATH') ?? '/usr/bin:/bin', HOME: getEnv('HOME') ?? '/tmp', QUORUM_REPO_ROOT: REPO, QUORUM_RECORD_SINK: sink, QUORUM_INNER_ENV: 'legacy' }, // getEnv from '../src/env.ts': this file is not in the noProcessEnv override
  });
}

test('sourcing the prelude from a planted workdir runs no preload', () => {
  const { wd, mark } = plantedWorkdir();
  const sink = join(mkdtempSync(join(tmpdir(), 'sink-')), 'records.jsonl');
  const r = bashInWorkdir(wd, 'true', sink);
  expect(r.status).toBe(0);
  expect(existsSync(mark)).toBe(false);
});

test('a verb run through the prelude from a planted workdir runs no preload and sees no .env', () => {
  const { wd, mark } = plantedWorkdir();
  const sink = join(mkdtempSync(join(tmpdir(), 'sink-')), 'records.jsonl');
  // The dispatcher's own view of the environment: a verb that reads it.
  const r = bashInWorkdir(wd, 'command-succeeds \'test -z "${QUORUM_PROBE_DOTENV:-}"\'', sink);
  expect(existsSync(mark)).toBe(false);
  expect(r.status).toBe(0);
  expect(readFileSync(sink, 'utf8')).toContain('"passed":true');
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `bun test test/prelude-dispatcher-config.test.ts`
Expected: FAIL — `preload-ran` exists after sourcing; the dotenv probe is visible.

- [ ] **Step 3: Add the flags to all five invocations**

In `src/checks/prelude.sh`, define once near the top (after the header comment):

```bash
# Bun reads bunfig.toml and .env from its cwd, and every dispatcher below runs
# with cwd = the agent's workdir. Pin the configuration to the repository's own
# bunfig.toml and disable dotenv loading so a workdir preload or .env can never
# run inside, or shadow a variable of, the trusted check tooling.
__quorum_bun() { bun run --config="$QUORUM_REPO_ROOT/bunfig.toml" --env-file=/dev/null "$@"; }
```

and replace `bun run` with `__quorum_bun` at `:20` (the `list-check-verbs.ts` source-time call), inside the `eval` string at `:21`, and at `:28`, `:31`, `:34`. Do not use `--cwd`: the verbs take their working directory from `process.cwd()` (`src/check/fs-verbs.ts:47`).

- [ ] **Step 4: Run the test and the existing prelude suites**

Run: `bun test test/prelude-dispatcher-config.test.ts test/prelude-record-equality.test.ts test/check-tool.test.ts test/checks.test.ts`
Expected: PASS.

- [ ] **Step 5: Gate and commit**

Run: `bun run check` — Expected: PASS.

```bash
git add src/checks/prelude.sh test/prelude-dispatcher-config.test.ts
git commit -m "fix(checks): every prelude dispatcher pins Bun to the repository bunfig and disables dotenv, so a workdir preload cannot run in the trusted layer"
```

---

### Task 4: Relocate the workspace; `RunHome.runDir`; every layout-pinning test

**Risk tier:** high — moves where every agent-written byte lands; a mistake here silently changes what the harness measures.

**Files:**
- Modify: `src/runner/index.ts:1103-1111` (derivations), `:1119-1126` (`home` literal), plus a new exported `allocateWorkspace`
- Modify: `src/agents/index.ts:27-34` (`RunHome.runDir`)
- Modify: `test/provision-helpers.ts:9-26`, `test/agent-codex-plugin-stage.test.ts:129-134`
- Modify: `test/runner-workdir-scope.test.ts` (fixture depth), `test/cli-run-sigint.test.ts:262-280`
- Modify: `test/runner-context.test.ts:35-64,122-129` (home under a workspace root)
- Test: `test/runner-layout.test.ts` (new, the helpers), `test/cli-run-layout.test.ts` (new, the production path under the mock Gauntlet)
- Create: `test/cli-run-helpers.ts` (the `scenario`/`runCli`/`CliOptions` helpers moved out of `test/cli-run.test.ts`); Modify: `test/cli-run.test.ts:12-95` (imports them)
- Modify: `biome.json:98-119` (add `test/cli-run-helpers.ts` to the `noProcessEnv` override: `runCli` spreads and reads `process.env`)

**Interfaces:**
- Consumes: `isolateWorkdirPackageScope(dir)` (`src/runner/index.ts:843`), `scanResults(root, agents)` and `parseRunDirName(name, agents)` (`src/dashboard/scan.ts`), the mock Gauntlet scaffold in `test/cli-run.test.ts:1-70` (`runCli` with `--coding-agent claude --coding-agents-dir <real> --out-root <tmp>`).
- Produces:
  ```ts
  // src/runner/index.ts
  export interface RunWorkspace { readonly workspaceDir: string; readonly workdir: string; readonly runHomeDir: string; }
  export function allocateWorkspace(outRoot: string, runDir: string): RunWorkspace;
  export function buildRunHome(configDir: string, workdir: string, runDir: string, skeletonRoot: string | undefined): RunHome;  // the runner's `home` literal, as a function
  // src/agents/index.ts
  export interface RunHome { configDir; workdir; skeletonRoot; readonly runDir: string; }  // runDir = the record directory
  ```
  Later tasks rely on `workspaceDir` being `join(outRoot, 'workspaces', basename(runDir))` and on `home.runDir` being the record directory `<outRoot>/<run>`.

**Mirror:** `test/runner-workdir-scope.test.ts` for the helper test shape; `test/dashboard-scan.test.ts` `writeRun()` for seeding a record; `test/cli-run.test.ts:35-70` (`runCli`) for driving the real CLI under the mock Gauntlet.

- [ ] **Step 1: Write the failing layout test**

```ts
// test/runner-layout.test.ts
import { afterAll, expect, test } from 'bun:test';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join } from 'node:path';
import { scanResults } from '../src/dashboard/scan.ts';
import { allocateWorkspace, buildRunHome } from '../src/runner/index.ts';

const outRoot = mkdtempSync(join(tmpdir(), 'out-'));
afterAll(() => rmSync(outRoot, { recursive: true, force: true }));

const RUN = 'brainstorming-smoke-claude-auto-20260101T000000Z-abcd';

test('the workspace lives beside the record under workspaces/<run>, with the sentinel at its root', () => {
  const runDir = join(outRoot, RUN);
  mkdirSync(runDir, { recursive: true });
  const ws = allocateWorkspace(outRoot, runDir);
  expect(ws.workspaceDir).toBe(join(outRoot, 'workspaces', basename(runDir)));
  expect(ws.workdir).toBe(join(ws.workspaceDir, 'coding-agent-workdir'));
  expect(ws.runHomeDir).toBe(join(ws.workspaceDir, 'home'));
  expect(existsSync(ws.workdir)).toBe(true);
  expect(existsSync(ws.runHomeDir)).toBe(true);
  const pkg = JSON.parse(readFileSync(join(ws.workspaceDir, 'package.json'), 'utf8'));
  expect(pkg.private).toBe(true);
  expect(existsSync(join(runDir, 'package.json'))).toBe(false);
  expect(existsSync(join(ws.workdir, 'package.json'))).toBe(false);
});

test('buildRunHome names the record directory as runDir', () => {
  const home = buildRunHome('/ws/home/.claude', '/ws/coding-agent-workdir', '/out/run-1', undefined);
  expect(home.runDir).toBe('/out/run-1');
  expect(home.workdir).toBe('/ws/coding-agent-workdir');
});

test('the dashboard scan ignores the workspaces directory', () => {
  writeFileSync(join(outRoot, RUN, 'verdict.json'), JSON.stringify({ schema: 1, final: 'pass' }));
  const grid = scanResults(outRoot, ['claude-auto']);
  expect(grid.cells.size).toBe(1);
  for (const key of grid.cells.keys()) expect(key).not.toContain('workspaces');
});
```

- [ ] **Step 2: The production-path witness, failing first**

`test/cli-run-layout.test.ts` needs `scenario()`, `CliOptions` and `runCli()`, which are module-private in `test/cli-run.test.ts:21-95` with their constants `CLI`, `MOCK`, `REAL_CODING_AGENTS` (`:12-19`). Do not copy them — the human partner chose extraction over duplication at pre-flight. Move those three definitions and the three constants, unchanged, into a new `test/cli-run-helpers.ts` that exports `scenario`, `runCli` and the `CliOptions` type (`import.meta.dir` is still `test/`, so `REAL_CODING_AGENTS`, `CLI` and `MOCK` resolve exactly as before), and make `test/cli-run.test.ts` import them (`import { runCli, scenario } from './cli-run-helpers.ts';`), deleting its local copies; its tests do not change, and `bun test test/cli-run.test.ts` must pass after the move with the same test count. `runCli(fixture)` takes a **mock-gauntlet fixture name** (`test/mock-gauntlet/fixtures/{pass,fail-no-usage}`) and builds its own scenario. The helper spreads `process.env` and reads `process.env['PATH']`, so add `test/cli-run-helpers.ts` to the `noProcessEnv` override list (`biome.json:98-119`) in this task and stage `biome.json` (`test/cli-run-layout.test.ts` itself touches no `process.env`). The new test file's imports are `import { expect, test } from 'bun:test'; import { existsSync, readFileSync } from 'node:fs'; import { join } from 'node:path'; import { runCli } from './cli-run-helpers.ts';`:

```ts
test('quorum run writes the record under <out>/<run> and the workspace under <out>/workspaces/<run>', () => {
  const { status, stdout, outRoot } = runCli('pass');
  expect(status).toBe(0);
  const runId = /^run-id: (\S+)$/m.exec(stdout)?.[1] as string;
  const runDir = join(outRoot, runId);
  const ws = join(outRoot, 'workspaces', runId);
  expect(existsSync(join(runDir, 'verdict.json'))).toBe(true);
  expect(existsSync(join(runDir, 'coding-agent-workdir'))).toBe(false);
  expect(existsSync(join(runDir, 'home'))).toBe(false);
  expect(existsSync(join(ws, 'coding-agent-workdir'))).toBe(true);
  expect(existsSync(join(ws, 'home'))).toBe(true);
  expect(JSON.parse(readFileSync(join(ws, 'package.json'), 'utf8')).private).toBe(true);
  // The generated launcher names the relocated cwd and home.
  const launcher = readFileSync(join(runDir, 'gauntlet-agent', 'context', 'launch-agent'), 'utf8');
  expect(launcher).toContain(join(ws, 'coding-agent-workdir'));
  expect(launcher).toContain(`HOME='${join(ws, 'home')}'`);
});
```

Run: `bun test test/runner-layout.test.ts test/cli-run-layout.test.ts`
Expected: FAIL — `allocateWorkspace` and `buildRunHome` are not exported; the CLI still writes the workdir under the run directory.

- [ ] **Step 3: Implement the relocation**

In `src/runner/index.ts`, next to `isolateWorkdirPackageScope`:

```ts
export interface RunWorkspace {
  readonly workspaceDir: string;
  readonly workdir: string;
  readonly runHomeDir: string;
}

// The agent's tree lives beside the record, not inside it, so nothing the
// agent lists from its cwd is a record file (spec, "Layout"). The sentinel
// moves with it: from the new workdir the upward package.json walk passes
// workspaces/ and results/ before evals/package.json, so the workspace root
// is where it must stop.
export function allocateWorkspace(outRoot: string, runDir: string): RunWorkspace {
  const workspaceDir = join(outRoot, 'workspaces', basename(runDir));
  const workdir = join(workspaceDir, 'coding-agent-workdir');
  const runHomeDir = join(workspaceDir, 'home');
  mkdirSync(workdir, { recursive: true });
  for (const dir of [runHomeDir, ...xdgHomeSubdirs(runHomeDir)]) {
    mkdirSync(dir, { recursive: true });
  }
  isolateWorkdirPackageScope(workspaceDir);
  return { workspaceDir, workdir, runHomeDir };
}
```

Replace `:1103-1113` (the `workdir` mkdir, the sentinel call, the `runHomeDir` loop) with `const { workspaceDir, workdir, runHomeDir } = allocateWorkspace(a.outRoot, runDir);` and keep the comments that explain the throwaway home. Replace the `home` literal at `:1119-1126` with `const home = buildRunHome(configDir, workdir, runDir, a.skeletonRoot ?? a.codingAgentsDir);` where

```ts
export function buildRunHome(configDir: string, workdir: string, runDir: string, skeletonRoot: string | undefined): RunHome {
  return { configDir, workdir, runDir, skeletonRoot };
}
```

keeps the existing comment about `skeletonRoot` above the call. `workspaceDir` is consumed by Task 6; until then it is referenced nowhere else — prefix it `_workspaceDir`? No: keep the name and let Task 6 use it; biome's unused-variable rule does not fire on a destructured binding that is later read in the same function once Task 6 lands, so in this task add the single consumer early: pass `workspaceDir` into nothing, but assign `void workspaceDir;` with the comment `// consumed by the Copilot cascade and the misplaced-rollout detector (next task)` — and remove that line in Task 6.

`src/agents/index.ts:27-34`: add

```ts
  /** The run's record directory (<outRoot>/<run>), distinct from the workspace
   *  that holds configDir and workdir. Kimi roots its artifact-root guard here. */
  readonly runDir: string;
```

- [ ] **Step 4: Every `RunHome` construction site, same commit**

`test/provision-helpers.ts:14-19`:

```ts
  const record = join(root, 'record');
  mkdirSync(record, { recursive: true });
  const home: RunHome = {
    configDir: join(root, 'coding-agent-config'),
    workdir: join(root, 'coding-agent-workdir'),
    runDir: record,
    skeletonRoot: undefined,
    ...overrides,
  };
  // The spec's two invariants for the shared fixture: the record directory is
  // real, and it is never a workspace path (an override could make it one).
  const refuse = (why: string): never => {
    rmSync(root, { recursive: true, force: true }); // never leak the fixture root on refusal
    throw new Error(`makeTempHome: ${why}`);
  };
  for (const ws of [home.workdir, home.configDir]) {
    if (home.runDir === ws || home.runDir.startsWith(ws + sep)) refuse(`runDir ${home.runDir} lies inside workspace path ${ws}`);
  }
  if (!existsSync(home.runDir)) refuse(`runDir ${home.runDir} does not exist`);
```

(`mkdirSync`, `existsSync` and `sep` imports added; the record directory must exist because Kimi `realpath`s it — Task 5.) Pin the invariants in `test/runner-layout.test.ts` (import `makeTempHome` from `./provision-helpers.ts`):

```ts
test('makeTempHome refuses a runDir inside a workspace path and a runDir that does not exist', () => {
  // makeTempHome returns { home, cleanup } (test/provision-helpers.ts:9-12). The
  // invariant is per invocation, so the override must place runDir under the
  // SAME invocation's workdir: pass both.
  const ws = mkdtempSync(join(tmpdir(), 'ws-'));
  expect(() => makeTempHome({ workdir: ws, runDir: join(ws, 'x') })).toThrow(/inside workspace path/);
  expect(() => makeTempHome({ runDir: join(tmpdir(), 'no-such-record-dir') })).toThrow(/does not exist/);
  const ok = makeTempHome();
  expect(existsSync(ok.home.runDir)).toBe(true);
  ok.cleanup();
  rmSync(ws, { recursive: true, force: true });
});
``` `test/agent-codex-plugin-stage.test.ts:132`: `const home = { configDir, workdir, runDir: join(root, 'evals', 'run'), skeletonRoot: undefined };`. Run `bun run typecheck`; it reports any construction site this list missed — there should be none (the `agent-codex-app-server` literals are `ReadHookArgs`, not `RunHome`).

- [ ] **Step 5: Update the two tests that pin the old depth or enumerate the out-root**

`test/runner-workdir-scope.test.ts` `makeRun`: `const workspaceDir = join(root, 'results', 'workspaces', name); const workdir = join(workspaceDir, 'coding-agent-workdir');` and return `{ workspaceDir, workdir }`; the three tests call `isolateWorkdirPackageScope(workspaceDir)` and assert the sentinel at `workspaceDir`. The root-level `package.json` still stands in for `evals/package.json`, now three levels up, which is the real distance.

`test/runner-context.test.ts:35-64,122-129`: the fixture builds the launcher substitutions with `join(runDir, 'home')` and asserts `HOME='<runDir>/home'`. Introduce `const workspaceDir = join(outRoot, 'workspaces', basename(runDir))` in the fixture (its `runDir` already sits under a temp out-root; if not, add one), pass `join(workspaceDir, 'home')` wherever `join(runDir, 'home')` was used, and assert `HOME='<workspaceDir>/home'` at `:125`. The launcher path itself (`<runDir>/gauntlet-agent/context/launch-agent`) is unchanged.

`test/cli-run-sigint.test.ts:262-264`:

```ts
import { parseRunDirName } from '../src/dashboard/scan.ts';
// …
const runDirs = readdirSync(outRoot).filter((n) => parseRunDirName(n, [AGENT]) !== null);
expect(runDirs).toHaveLength(2);
```

where `AGENT` is the coding-agent name the test already passes to `quorum run` (read it from the test's spawn arguments and lift it to a constant).

- [ ] **Step 6: Run the touched suites, then record the two sweeps**

Run: `bun test test/runner-layout.test.ts test/cli-run-layout.test.ts test/runner-workdir-scope.test.ts test/cli-run-sigint.test.ts test/runner-context.test.ts test/setup-helpers-codex-seed.test.ts test/agent-codex-plugin-stage.test.ts`
Expected: PASS. `setup-helpers-codex-seed` derives the home as the workdir's sibling and needs no change.

Record in the ledger the output of the two sweeps the spec requires, with the expected result beside each:
`rg -n "dirname\(workdir\)|dirname\(configDir\)" src` → exactly ten lines, recorded at `b6a923a31`: `agents/kimi.ts:197` (the derivation Task 5 fixes) and `agents/kimi.ts:196` (its comment); `agents/index.ts:385,393` (`dirname(configDir)` is the agent home, inside the workspace in both layouts); `setup-helpers/worktree.ts:52` (a sibling worktree beside the workdir); `setup-helpers/codex-seed.ts:23` with its comment at `:19` and the three matching expectations in `setup-helpers/codex-seed.test.ts:18,32,72` (`dirname(workdir)/home` is the workspace home, valid in both layouts). A line not in this list is a new derivation to classify before the task closes;
`rg -n "readdirSync\(" src test --type ts` → the only site that treated every out-root child as a run was `cli-run-sigint.test.ts:263`, fixed above.

- [ ] **Step 7: Gate and commit**

Run: `bun run check` — Expected: PASS.

```bash
git add src/runner/index.ts src/agents/index.ts test/provision-helpers.ts test/agent-codex-plugin-stage.test.ts test/runner-workdir-scope.test.ts test/runner-context.test.ts test/cli-run-sigint.test.ts test/runner-layout.test.ts test/cli-run-layout.test.ts test/cli-run-helpers.ts test/cli-run.test.ts biome.json
git commit -m "feat(runner): the agent's workspace lives at results/workspaces/<run>, beside the record rather than inside it"
```

---

### Task 5: Kimi's artifact-root guard roots at the record directory

**Risk tier:** high — the guard decides where a mode-0600 credential file may be written.

**Files:**
- Modify: `src/agents/kimi.ts:128` (destructure `runDir`), `:191-198` (derivation and comment)
- Test: `test/agent-kimi.test.ts:909-950` (rewrite the two guard tests on an explicit fixture)

**Interfaces:**
- Consumes: `RunHome.runDir` (Task 4); `writeKimiRuntimeEnvFile(env, { runDir, tmpDirOverride? })` and `kimiRuntimeEnvTempParent(runDir, tmpDirOverride?)` (`src/agents/kimi.ts:829-850`), unchanged.
- Produces: nothing new; the artifact root becomes `dirname(home.runDir)` = `<outRoot>`.

**Mirror:** `test/agent-kimi.test.ts:909-950` for the assertions (exists, `0o600`, `quorum-kimi-env-` prefix, not under the artifact root).

- [ ] **Step 1: Rewrite the two guard tests on a relocated fixture (failing first)**

Replace the two tests at `:909-950` with:

```ts
function relocatedLayout(): { out: string; runDir: string; cleanup: () => void } {
  const out = mkdtempSync(join(tmpdir(), 'out-'));
  const runDir = join(out, 'kimi-run');
  const ws = join(out, 'workspaces', 'kimi-run');
  mkdirSync(runDir, { recursive: true });
  mkdirSync(join(ws, 'home', '.kimi-code'), { recursive: true });
  mkdirSync(join(ws, 'coding-agent-workdir'), { recursive: true });
  return { out, runDir, cleanup: () => rmSync(out, { recursive: true, force: true }) };
}

test('writeKimiRuntimeEnvFile keeps the secret outside the whole out-root under the relocated layout', () => {
  const { out, runDir, cleanup } = relocatedLayout();
  try {
    const path = writeKimiRuntimeEnvFile({ KIMI_MODEL_API_KEY: API_KEY, KIMI_DISABLE_TELEMETRY: '1' }, { runDir });
    expect(existsSync(path)).toBe(true);
    expect(statSync(path).mode & 0o777).toBe(0o600);
    expect(path).toContain('quorum-kimi-env-');
    expect(path.startsWith(`${realpathSync(out)}/`)).toBe(false);
  } finally { cleanup(); }
});

test('a TMPDIR inside the out-root but outside workspaces/ is walked out of the artifact root', () => {
  const { out, runDir, cleanup } = relocatedLayout();
  try {
    const insideTmp = join(out, 'tmp-inside');
    mkdirSync(insideTmp, { recursive: true });
    const path = writeKimiRuntimeEnvFile({ KIMI_MODEL_API_KEY: API_KEY }, { runDir, tmpDirOverride: insideTmp });
    expect(path.startsWith(`${realpathSync(insideTmp)}/`)).toBe(false);
    expect(path.startsWith(`${realpathSync(out)}/`)).toBe(false);
  } finally { cleanup(); }
});
```

Run: `bun test test/agent-kimi.test.ts -t "relocated layout|walked out"` — Expected: both PASS already for the pure writer (the guard takes `runDir` directly); they are the specification the provisioning path must now satisfy. The failing assertion is the provisioning one below.

- [ ] **Step 2: Add the provisioning assertion (fails until the derivation changes)**

```ts
// Extend the file's existing import: `import { ProvisionError, type RunHome } from '../src/agents/index.ts';`
test('provision roots the artifact guard at home.runDir, not at the workspace parent', () => {
  const { out, runDir, cleanup } = relocatedLayout();
  const home: RunHome = {
    configDir: join(out, 'workspaces', 'kimi-run', 'home', '.kimi-code'),
    workdir: join(out, 'workspaces', 'kimi-run', 'coding-agent-workdir'),
    runDir,
    skeletonRoot: undefined,
  };
  const spRoot = join(out, 'superpowers-src');
  mkdirSync(spRoot, { recursive: true });
  stageSuperpowers(spRoot);
  try {
    withEnv({ SUPERPOWERS_ROOT: spRoot, KIMI_MODEL_API_KEY: API_KEY, TMPDIR: join(out, 'tmp-inside'), KIMI_MODEL_NAME: undefined }, () => {
      mkdirSync(join(out, 'tmp-inside'), { recursive: true });
      const env = new KimiAgent(KIMI_CONFIG).provision(home, new FakeCommandRunner(happyResponder));
      const file = env['KIMI_ENV_FILE'] as string;
      expect(file.startsWith(`${realpathSync(out)}/`)).toBe(false);
    });
  } finally { cleanup(); }
});
```

(`KIMI_ENV_FILE` is the launcher substitution the provision returns — confirm the exact key name at `src/agents/kimi.ts:200-212` and use it verbatim.) Run: Expected: FAIL — with `dirname(workdir)` as the run dir, the artifact root is `out/workspaces`, so `out/tmp-inside` is accepted and the file lands under `out`.

- [ ] **Step 3: Change the derivation**

`src/agents/kimi.ts:128`: `const { configDir, workdir, runDir } = home;`. Replace `:191-198` with:

```ts
    // Write the mode-0600 secret file of sorted shell assignments OUTSIDE the
    // run artifact root, so capture never snapshots it. The artifact root is
    // the parent of the record directory — the out-root — which contains both
    // the record and the workspace. It is taken from home.runDir, never
    // derived from workdir: the workspace lives at <outRoot>/workspaces/<run>,
    // so a derivation from it would name <outRoot>/workspaces as the root and
    // accept a TMPDIR beside the record.
    const envFilePath = writeKimiRuntimeEnvFile(runtimeEnv, { runDir });
```

- [ ] **Step 4: Run and commit**

Run: `bun test test/agent-kimi.test.ts` — Expected: PASS. Run: `bun run check` — Expected: PASS.

```bash
git add src/agents/kimi.ts test/agent-kimi.test.ts
git commit -m "fix(kimi): the credential-file guard roots at the record directory's parent, which still contains the relocated workspace"
```

---

### Task 6: Copilot's leak scan and the Codex wrong-cwd detector cover both trees

**Risk tier:** high — a secret-leak scan and a misconfiguration detector, both of which relocation would silently disable.

**Files:**
- Modify: `src/runner/index.ts:699-740` (`CopilotCascadeArgs`, `copilotCascadeVerdict`), `:1486-1494` (call), `:650-676` (`CodexMisplacedArgs`, `codexMisplacedVerdict`), `:1550-1557` (call); remove the `void workspaceDir;` line from Task 4
- Modify: `src/capture/index.ts:368-399` (`DetectMisplacedCodexRolloutsArgs.workspaceDir`, the containment test)
- Test: `test/runner-copilot-cascade.test.ts` (two cases), `test/capture.test.ts` (one case)

**Interfaces:**
- Consumes: `workspaceDir` from Task 4; `scanCopilotSecretLeaks(root, secrets, excluded)` (`src/agents/copilot.ts:445`).
- Produces: `CopilotCascadeArgs.workspaceDir: string`; `CodexMisplacedArgs.workspaceDir: string`; `DetectMisplacedCodexRolloutsArgs.workspaceDir: string`.

**Mirror:** `test/runner-copilot-cascade.test.ts:24-46` (the leak case) and `test/capture.test.ts` "detectMisplacedCodexRollouts flags rollouts inside run_dir at a wrong cwd" (the rollout writer and `snapshotDir` usage).

- [ ] **Step 1: Failing tests**

`test/runner-copilot-cascade.test.ts`, after the existing leak test:

```ts
function relocated(): { runDir: string; workspaceDir: string } {
  const out = mkdtempSync(join(tmpdir(), 'out-'));
  const runDir = join(out, 'run-1');
  const workspaceDir = join(out, 'workspaces', 'run-1');
  mkdirSync(join(runDir, 'session-state', 'sess-1'), { recursive: true });
  mkdirSync(join(workspaceDir, 'coding-agent-workdir'), { recursive: true });
  mkdirSync(join(workspaceDir, 'home'), { recursive: true });
  writeFileSync(join(runDir, 'session-state', 'sess-1', 'events.jsonl'), '{}');
  return { runDir, workspaceDir };
}

for (const where of ['coding-agent-workdir/leak.txt', 'home/leak.txt'] as const) {
  test(`secret-leak scan: a secret under workspaces/<run>/${where.split('/')[0]} is still caught`, () => {
    const { runDir, workspaceDir } = relocated();
    writeFileSync(join(workspaceDir, where), 'token=ghp_SECRETVALUE123');
    const expectedLog = join(runDir, 'session-state', 'sess-1', 'events.jsonl');
    const v = copilotCascadeVerdict({
      runDir, workspaceDir, sessionLogDir: join(runDir, 'session-state'), expectedEventsLog: expectedLog,
      envFile: join(runDir, '.copilot-env'), secretValues: ['ghp_SECRETVALUE123'], sourceLogs: [expectedLog],
      gauntlet: GAUNTLET, preRecords: [],
    });
    expect(v?.final).toBe('indeterminate');
    expect(v?.final_reason).toContain(where);
  });
}
```

Also add `workspaceDir: runDir` to the existing tests' argument literals so they typecheck (they plant the leak under `runDir`).

`test/capture.test.ts`, after the existing detector test, mirroring its rollout writer:

```ts
// Extend the file's existing node:path import to `import { basename, join } from 'node:path';`
test('detectMisplacedCodexRollouts: record-tree scratch and a wrong workspace subdir are misplaced; the launch cwd is not', () => {
  const logDir = mkdtempSync(join(tmpdir(), 'codex-logs-'));
  const out = mkdtempSync(join(tmpdir(), 'out-'));
  const runDir = join(out, 'run-1');
  const workspaceDir = join(out, 'workspaces', 'run-1');
  const launchCwd = join(workspaceDir, 'coding-agent-workdir');
  const scratch = join(runDir, 'gauntlet-agent', 'results', 'g1', 'scratch'); // where the pane's shell starts
  const wrongInWorkspace = join(workspaceDir, 'somewhere-else');
  for (const d of [launchCwd, scratch, wrongInWorkspace]) mkdirSync(d, { recursive: true });
  const snap = snapshotDir(logDir, '**/*.jsonl');
  writeRollout(join(logDir, 'scratch.jsonl'), scratch);          // the existing test's helper shape
  writeRollout(join(logDir, 'wrong.jsonl'), wrongInWorkspace);
  writeRollout(join(logDir, 'ok.jsonl'), launchCwd);
  const misplaced = detectMisplacedCodexRollouts({ logDir, logGlob: '**/*.jsonl', snapshot: snap, runDir, workspaceDir, launchCwd });
  expect(misplaced.map((p) => basename(p)).sort()).toEqual(['scratch.jsonl', 'wrong.jsonl']);
});
```

If the existing test writes its rollout inline rather than through a helper, lift that write into a `writeRollout(path, cwd)` helper first and use it in both tests. Add `workspaceDir: runDir` to the existing detector test's argument literal.

- [ ] **Step 2: Run to verify failure**

Run: `bun test test/runner-copilot-cascade.test.ts test/capture.test.ts` — Expected: FAIL to compile on the missing field, then FAIL on the new assertions once added.

- [ ] **Step 3: Implement**

`src/capture/index.ts:368-399`: add `readonly workspaceDir: string;` to the args; compute `const workspaceReal = realPath(args.workspaceDir);` and replace the containment with

```ts
    const inside = (root: string): boolean => cwdReal === root || cwdReal.startsWith(root + sep);
    // Both trees: a launcher-skipping Codex starts in the pane's scratch cwd,
    // which is in the record tree; a wrong `cd` lands in the workspace tree.
    if ((inside(runDirReal) || inside(workspaceReal)) && cwdReal !== launchCwdReal) {
```

Update the doc comment ("inside runDir" → "inside the record tree or the workspace tree"). `src/runner/index.ts`: `CodexMisplacedArgs.workspaceDir`, pass it through to `detectMisplacedCodexRollouts`; at `:1550-1557` add `workspaceDir,`. `CopilotCascadeArgs.workspaceDir`; in `copilotCascadeVerdict`:

```ts
  const leaks = [
    ...scanCopilotSecretLeaks(a.runDir, a.secretValues, [a.envFile]),
    ...scanCopilotSecretLeaks(a.workspaceDir, a.secretValues, [a.envFile]),
  ];
  if (leaks.length > 0) {
    const rel = leaks.map((p) => relIfUnder(a.runDir, p) === p ? relIfUnder(a.workspaceDir, p) : relIfUnder(a.runDir, p));
```

and at `:1486-1494` add `workspaceDir,`. Remove Task 4's `void workspaceDir;`.

- [ ] **Step 4: Run and commit**

Run: `bun test test/runner-copilot-cascade.test.ts test/capture.test.ts` then `bun run check` — Expected: PASS.

```bash
git add src/runner/index.ts src/capture/index.ts test/runner-copilot-cascade.test.ts test/capture.test.ts
git commit -m "fix(runner): the Copilot leak scan and the Codex wrong-cwd detector cover the workspace tree as well as the record tree"
```

---

### Task 7: `QUORUM_AGENT_HOME` migrations and the `$QUORUM_RUN_DIR` lint

**Risk tier:** high — the migrations move four checks across the outer/inner credential boundary, and the lint is what keeps record-tree paths out of agent-authored inner commands: a security surface under the rubric.

**Files:**
- Modify: `scenarios/codex-approach-gate-fires-on-architecture/checks.sh:20`, `scenarios/codex-plan-gate-algorithm-locked-after-round1/checks.sh:23`, `scenarios/codex-gate-stale-broker-attributed/checks.sh:49`, `scenarios/tdd-runs-the-project-suite/checks.sh:53`
- Modify: `src/scaffold.ts:192-199` (add the lint after the `$QUORUM_WORKDIR` one)
- Modify: `test/scenario-tdd-project-suite.test.ts:203-213` and every other `QUORUM_RUN_DIR` in that file
- Test: `test/scaffold.test.ts` (one case)

**Interfaces:**
- Consumes: `QUORUM_AGENT_HOME` exported at both layers (Task 1).
- Produces: `checkScenario` reports `checks.sh:<n>: $QUORUM_RUN_DIR is outer-only; expand it with double quotes or use $QUORUM_AGENT_HOME` for a single-quoted `command-succeeds` that references it.

**Mirror:** `src/scaffold.ts:192-199` and the `test/scaffold.test.ts` test "checkScenario flags a $QUORUM_WORKDIR reference".

- [ ] **Step 1: The lint test, failing**

```ts
test('checkScenario flags $QUORUM_RUN_DIR inside a single-quoted command-succeeds', () => {
  const root = scenariosRoot();
  const dir = scenario(root, 's');
  writeFileSync(join(dir, 'checks.sh'), 'pre() {\n  :\n}\npost() {\n  command-succeeds \'test -f "$QUORUM_RUN_DIR/x"\'\n}\n');
  const problems = checkScenario(dir);
  expect(problems).toContain('checks.sh:5: $QUORUM_RUN_DIR is outer-only; expand it with double quotes or use $QUORUM_AGENT_HOME');
  rmSync(root, { recursive: true, force: true });
});

test('checkScenario accepts $QUORUM_RUN_DIR expanded at the outer layer', () => {
  const root = scenariosRoot();
  const dir = scenario(root, 's');
  writeFileSync(join(dir, 'checks.sh'), 'pre() {\n  :\n}\npost() {\n  command-succeeds "test -f $QUORUM_RUN_DIR/gauntlet-agent/x"\n}\n');
  expect(checkScenario(dir).some((p) => p.includes('QUORUM_RUN_DIR'))).toBe(false);
  rmSync(root, { recursive: true, force: true });
});
```

Run: `bun test test/scaffold.test.ts -t "QUORUM_RUN_DIR"` — Expected: the first FAILS.

- [ ] **Step 2: The lint**

After the `$QUORUM_WORKDIR` block in `src/scaffold.ts`:

```ts
    // $QUORUM_RUN_DIR reaches the outer layer only. Inside a single-quoted
    // command-succeeds it would expand in the nested shell, which never
    // receives it (spec, "Post-check environment").
    if (/command-succeeds\s+'[^']*\$\{?QUORUM_RUN_DIR\b/.test(line)) {
      problems.push(
        `checks.sh:${i + 1}: $QUORUM_RUN_DIR is outer-only; expand it with double quotes or use $QUORUM_AGENT_HOME`,
      );
    }
```

- [ ] **Step 3: The four migrations, exact text**

`codex-approach-gate-fires-on-architecture/checks.sh:20` →
`    command-succeeds 'grep -rq "FIXTURE-IDEA-7Q4" "$QUORUM_AGENT_HOME/.cache/hyperpowers/codex-review"'`

`codex-plan-gate-algorithm-locked-after-round1/checks.sh:23` →
`    command-succeeds 'grep -rq "Algorithm locked:" "$QUORUM_AGENT_HOME/.cache/hyperpowers/codex-review"'`

`codex-gate-stale-broker-attributed/checks.sh:49`: replace `"$QUORUM_RUN_DIR/home/.cache/hyperpowers/ungated"` with `"$QUORUM_AGENT_HOME/.cache/hyperpowers/ungated"`, leaving the rest of the single-quoted command as it is.

`tdd-runs-the-project-suite/checks.sh:53`: replace `process.env.QUORUM_RUN_DIR + \"/home\"` with `process.env.QUORUM_AGENT_HOME`. Update the comment at `:42` that explains the home path to say `$QUORUM_AGENT_HOME`.

The first two switch from an outer double quote to an outer single quote on purpose: the dispatcher records the command it receives as the record's `args`, so an outer-expanded absolute path would make the replay's two arms (Task 10) emit different records even when both pass.

- [ ] **Step 4: The TDD test**

`test/scenario-tdd-project-suite.test.ts:203-213`: `env: { ...envSnapshot(), QUORUM_AGENT_HOME: p.agentHome, QUORUM_INNER_ENV: 'legacy' }` (the oracle spawns the dispatcher directly, outside `runPhase`, so it names the mode it wants). Grep the file for every other `QUORUM_RUN_DIR` and migrate each the same way.

- [ ] **Step 5: Run the scenario validation and the suites**

Run: `bun run quorum check` — Expected: every scenario passes; in particular no `$QUORUM_RUN_DIR` lint fires (the four migrations removed the only single-quoted uses). Run: `bun test test/scaffold.test.ts test/scenario-tdd-project-suite.test.ts` — Expected: PASS. Run: `bun run check` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scenarios/codex-approach-gate-fires-on-architecture/checks.sh scenarios/codex-plan-gate-algorithm-locked-after-round1/checks.sh scenarios/codex-gate-stale-broker-attributed/checks.sh scenarios/tdd-runs-the-project-suite/checks.sh src/scaffold.ts test/scaffold.test.ts test/scenario-tdd-project-suite.test.ts
git commit -m "fix(scenarios): post-checks reach the agent's home through QUORUM_AGENT_HOME, and quorum check rejects an inner-shell QUORUM_RUN_DIR"
```

---

### Task 8: `strip-runs` handles both layouts and takes liveness from the record

**Risk tier:** high — it deletes files under run directories; a wrong liveness rule strips a run mid-flight.

**Files:**
- Modify: `scripts/strip-runs:84-93` (candidates), `:100-113` (home and liveness), `:116-131` (strip targets)
- Test: `scripts/strip-runs.test.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces: `strip-runs` semantics — strips `<root>/workspaces/<name>/home` when present else `<root>/<name>/home`; a run is strippable only when `<root>/<name>/verdict.json` exists and neither the record directory nor the verdict is newer than the age threshold; the `workspaces` entry is never a candidate.

**Mirror:** `scripts/strip-runs.test.sh` (whole file) for the fixture and `fail()` style; keep bash 3.2 compatibility (no associative arrays, no `mapfile`).

- [ ] **Step 1: Extend the test, failing first**

The existing fixture has no `verdict.json`, so under the new rule it would be skipped as in-flight: add `printf '{}\n' > "$run/verdict.json"` beside its `trajectory.json`, and extend the existing `touch -t 202001010000 "$run"` to `touch -t 202001010000 "$run" "$run/verdict.json"` — the new liveness rule reads the newer of the two mtimes, so a fresh verdict would keep the legacy run "recent". Then append three cases to the same script, each with its own run name under `$work/results`:

```bash
# Case 2: a new-layout run, verdict present, old — its home under workspaces/ is stripped.
new="$work/results/scenario-claude-auto-20260102T000000Z-bcde"
newws="$work/results/workspaces/scenario-claude-auto-20260102T000000Z-bcde"
mkdir -p "$new" "$newws/home/.npm/_cacache" "$newws/coding-agent-workdir"
printf '{}\n' > "$new/verdict.json"; printf 'npm\n' > "$newws/home/.npm/_cacache/index"
touch -t 202001010000 "$new" "$new/verdict.json" "$newws"
# Case 3: a new-layout run with an OLD workspace mtime but NO verdict — in flight, must be skipped.
live="$work/results/scenario-claude-auto-20260103T000000Z-cdef"
livews="$work/results/workspaces/scenario-claude-auto-20260103T000000Z-cdef"
mkdir -p "$live" "$livews/home/.npm/_cacache"
printf 'npm\n' > "$livews/home/.npm/_cacache/index"
touch -t 202001010000 "$livews"
bash "$here/strip-runs" --results-root "$work/results" > "$work/out2.txt"
cat "$work/out2.txt"
[ ! -e "$newws/home/.npm/_cacache" ] || fail "new-layout home/.npm/_cacache must be removed"
[ -f "$livews/home/.npm/_cacache/index" ] || fail "a run without a verdict is in flight and must not be stripped"
grep -q "skip .*workspaces" "$work/out2.txt" && fail "the workspaces directory must not be a candidate"
echo "PASS: strip-runs handles both layouts and never strips a run that has no verdict"
```

Run: `bash scripts/strip-runs.test.sh` — Expected: FAIL at the new-layout assertion.

- [ ] **Step 2: Implement**

In `scripts/strip-runs`: `candidates()` adds `! -name 'workspaces'` to the `find`. Replace the `home/` existence check and the age check (`:102-113`) with:

```bash
  # Two layouts: a run recorded before the relocation keeps home/ beside its
  # record; a later run keeps it under workspaces/<name>/. Either way the
  # record directory is <root>/<name>.
  if [ -d "$RESULTS_ROOT/workspaces/$name/home" ]; then
    tree="$RESULTS_ROOT/workspaces/$name"
  elif [ -d "$run/home" ]; then
    tree="$run"
  else
    skipped_empty=$((skipped_empty + 1)); continue
  fi
  # Liveness comes from the record, not the workspace: writes beneath home/ do
  # not refresh the workspace mtime, while the record directory is written at
  # every phase boundary. A run without a verdict is still running.
  if [ ! -f "$run/verdict.json" ]; then
    printf 'skip %-70s (no verdict yet: in flight)\n' "$name"
    skipped_recent=$((skipped_recent + 1)); continue
  fi
  if [ -n "$(find "$run" "$run/verdict.json" -maxdepth 0 -mmin -"$MIN_AGE_MINUTES" 2>/dev/null)" ]; then
    printf 'skip %-70s (touched within %s min)\n' "$name" "$MIN_AGE_MINUTES"
    skipped_recent=$((skipped_recent + 1)); continue
  fi
```

and in the strip loop use `target="$tree/$rel"` and `run_before=$(disk_kb "$tree")`. Update the header comment (`:1-12`) to name both layouts and the verdict rule.

- [ ] **Step 3: Run and commit**

Run: `bash scripts/strip-runs.test.sh` — Expected: both `PASS:` lines. Run: `bash scripts/strip-runs --dry-run` against the real `results/` — Expected: it lists legacy runs as before and reports the new liveness skips for any run without a verdict; no error. Run: `bun run check` — Expected: PASS.

```bash
git add scripts/strip-runs scripts/strip-runs.test.sh
git commit -m "fix(strip-runs): strip either layout's home and take liveness from the record's verdict, not the workspace mtime"
```

---

### Task 9: The corpus replay, part one — eligibility, isolated cloning, pointer validation

**Risk tier:** high — the replay is the offline instrument the allowlist's compatibility claim rests on; a clone that touches the source corrupts retained evidence.

**Files:**
- Create: `src/cli/replay-post-checks.ts`, `scripts/replay-post-checks`
- Test: `test/replay-post-checks.test.ts` (new)

**Interfaces:**
- Consumes: `parseRunDirName` (`src/dashboard/scan.ts:35`); `FinalVerdictSchema` (`src/contracts/verdict.ts`).
- Produces (exported for tests and for Task 10):
  ```ts
  export interface EligibleRun { scenario: string; runId: string; runDir: string; workspaceRoot: string; layout: 'legacy' | 'relocated'; }
  export interface Ineligible { scenario: string; reason: 'no-run' | 'setup-stage-verdict' | 'no-post-records' | 'stripped-workspace'; runId?: string; }
  export function eligibleRuns(resultsRoot: string, scenariosRoot: string, knownAgents: readonly string[]): { eligible: EligibleRun[]; ineligible: Ineligible[] };
  // scenariosRoot lists the scenarios (so 'no-run' can be reported); knownAgents is what parseRunDirName needs — the CLI passes the basenames of coding-agents/*.yaml.
  export interface PointerReport { gitPointers: string[]; rewrittenSymlinks: string[]; externalReferences: string[]; }
  export function cloneWorkspace(run: EligibleRun, dest: string): PointerReport;   // git pointers and rewritten intra-source links must resolve inside dest (throws otherwise); external references stay as they are and are listed; no pointer of any class may resolve into the source
  export function hashTree(root: string): string;                                  // sha256 over sorted (relative path, content) pairs; symlinks hashed by target
  ```
  Eligibility: per scenario, candidates are its runs under `resultsRoot` newest-first by `started_at` then nonce; the first whose `verdict.json` parses against `FinalVerdictSchema`, has no `error.stage === 'setup'`, holds at least one `phase: "post"` check record, and whose workspace (`<run>/coding-agent-workdir` or `workspaces/<run>/coding-agent-workdir`) exists is eligible. Demotion reasons are reported in that order — `setup-stage-verdict`, `no-post-records`, `stripped-workspace` — for the newest candidate when none qualifies, and `no-run` when the scenario has no run at all. `workspaceRoot` is `<run>` for legacy and `workspaces/<run>` for relocated.

**Mirror:** `scripts/strip-runs:1-20` for the script header; `src/cli/index.ts` for a CLI that uses `process.stdout.write` and exits non-zero on error; `test/runner-workdir-scope.test.ts` for a test that builds a real tree and shells out.

- [ ] **Step 1: The isolation test, failing first (disposable fixture, never the corpus)**

```ts
// test/replay-post-checks.test.ts
import { afterAll, expect, test } from 'bun:test';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, readlinkSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { CheckRecord, FinalVerdict } from '../src/contracts/verdict.ts';
import { cloneWorkspace, eligibleRuns, hashTree } from '../src/cli/replay-post-checks.ts';

const root = mkdtempSync(join(tmpdir(), 'replay-'));
afterAll(() => rmSync(root, { recursive: true, force: true }));
const git = (cwd: string, args: string[]) => { const r = spawnSync('git', args, { cwd, encoding: 'utf8' }); if (r.status !== 0) throw new Error(r.stderr); return r.stdout; };
const AGENTS = ['claude-auto'];

// Schema-valid verdict fixtures: FinalVerdictSchema requires schema, final,
// final_reason, gauntlet, checks, error, economics; each check record needs
// detail and phase.
function record(check: string, passed: boolean, phase: 'pre' | 'post', args: string[] = []): CheckRecord {
  return { check, args, negated: false, passed, detail: null, phase };
}
function verdictFixture(over: Partial<FinalVerdict>): FinalVerdict {
  return { schema: 1, final: 'pass', final_reason: 'fixture', gauntlet: null, checks: [], error: null, economics: null, ...over };
}
function scenariosRootWith(...names: string[]): string {
  const dir = mkdtempSync(join(tmpdir(), 'scenarios-'));
  for (const n of names) { mkdirSync(join(dir, n)); writeFileSync(join(dir, n, 'story.md'), '---\nid: x\n---\n'); }
  return dir;
}

// A legacy-layout run whose workspace has a linked worktree sibling, an
// intra-source absolute symlink, and an external absolute symlink — the three
// pointer classes the clone must handle.
function recordedWorktreeRun(): { resultsRoot: string; runDir: string; external: string } {
  const resultsRoot = join(root, 'results');
  const runDir = join(resultsRoot, 'worktree-no-drift-to-main-claude-auto-20260101T000000Z-aaaa');
  const wd = join(runDir, 'coding-agent-workdir');
  mkdirSync(wd, { recursive: true });
  git(wd, ['init', '-q', '-b', 'main']); git(wd, ['config', 'user.email', 'a@b']); git(wd, ['config', 'user.name', 't']);
  writeFileSync(join(wd, 'f.txt'), 'x\n'); git(wd, ['add', '-A']); git(wd, ['commit', '-qm', 'init']);
  git(wd, ['worktree', 'add', '-q', join(runDir, 'coding-agent-workdir-existing-worktree'), '-b', 'feature']);
  mkdirSync(join(runDir, 'home', '.local', 'bin'), { recursive: true });
  mkdirSync(join(runDir, 'home', '.local', 'share', 'claude', 'versions', '1.0'), { recursive: true });
  symlinkSync(join(runDir, 'home', '.local', 'share', 'claude', 'versions', '1.0'), join(runDir, 'home', '.local', 'bin', 'claude'));
  const external = mkdtempSync(join(tmpdir(), 'external-'));
  symlinkSync(external, join(runDir, 'home', 'external-link'));
  writeFileSync(join(runDir, 'verdict.json'), JSON.stringify(verdictFixture({ checks: [record('git-repo', true, 'post')] })));
  return { resultsRoot, runDir, external };
}

test('cloneWorkspace repairs worktree pointers inside the arm and leaves the source untouched', () => {
  const { resultsRoot, runDir, external } = recordedWorktreeRun();
  const before = hashTree(runDir);
  const { eligible } = eligibleRuns(resultsRoot, scenariosRootWith('worktree-no-drift-to-main'), AGENTS);
  expect(eligible).toHaveLength(1);
  const dest = join(root, 'armL');
  const report = cloneWorkspace(eligible[0]!, dest);
  // Git pointers resolve inside the arm, in both directions.
  const gitdir = readFileSync(join(dest, 'coding-agent-workdir', '.git', 'worktrees', 'coding-agent-workdir-existing-worktree', 'gitdir'), 'utf8').trim();
  expect(gitdir.startsWith(realpathSync(dest))).toBe(true);
  const dotgit = readFileSync(join(dest, 'coding-agent-workdir-existing-worktree', '.git'), 'utf8').trim();
  expect(dotgit.replace(/^gitdir: /, '').startsWith(realpathSync(dest))).toBe(true);
  // The intra-source symlink was rewritten to the arm; the external one kept and listed.
  expect(readlinkSync(join(dest, 'home', '.local', 'bin', 'claude')).startsWith(realpathSync(dest))).toBe(true);
  expect(readlinkSync(join(dest, 'home', 'external-link'))).toBe(external);
  expect(report.externalReferences).toContain(join(dest, 'home', 'external-link'));
  expect(report.rewrittenSymlinks).toHaveLength(1);
  // The source is byte-identical, pointers included.
  expect(hashTree(runDir)).toBe(before);
  expect(git(join(dest, 'coding-agent-workdir'), ['worktree', 'list'])).toContain(realpathSync(dest));
});

test('eligibleRuns demotes a setup-stage verdict, a stripped workspace and a scenario with no run, each with its reason', () => {
  const resultsRoot = join(root, 'results2');
  const a = join(resultsRoot, 'alpha-claude-auto-20260101T000000Z-0001');
  mkdirSync(join(a, 'coding-agent-workdir'), { recursive: true });
  writeFileSync(join(a, 'verdict.json'), JSON.stringify(verdictFixture({ final: 'indeterminate', error: { stage: 'setup', message: 'x' } })));
  const b = join(resultsRoot, 'beta-claude-auto-20260101T000000Z-0002');
  mkdirSync(b, { recursive: true }); // no workdir at all
  writeFileSync(join(b, 'verdict.json'), JSON.stringify(verdictFixture({ checks: [record('file-exists', true, 'post', ['x'])] })));
  const { eligible, ineligible } = eligibleRuns(resultsRoot, scenariosRootWith('alpha', 'beta', 'gamma'), AGENTS);
  expect(eligible).toHaveLength(0);
  expect(ineligible.map((i) => [i.scenario, i.reason])).toEqual(expect.arrayContaining([['alpha', 'setup-stage-verdict'], ['beta', 'stripped-workspace'], ['gamma', 'no-run']]));
});

test('eligibleRuns: a newest run without post records yields to an older eligible run; a scenario with only such runs demotes as no-post-records', () => {
  const resultsRoot = join(root, 'results4');
  const newer = join(resultsRoot, 'delta-claude-auto-20260102T000000Z-0005');
  const older = join(resultsRoot, 'delta-claude-auto-20260101T000000Z-0004');
  for (const d of [newer, older]) mkdirSync(join(d, 'coding-agent-workdir'), { recursive: true });
  writeFileSync(join(newer, 'verdict.json'), JSON.stringify(verdictFixture({ checks: [record('file-exists', true, 'pre', ['x'])] })));
  writeFileSync(join(older, 'verdict.json'), JSON.stringify(verdictFixture({ checks: [record('file-exists', true, 'post', ['x'])] })));
  const only = join(resultsRoot, 'epsilon-claude-auto-20260101T000000Z-0006');
  mkdirSync(join(only, 'coding-agent-workdir'), { recursive: true });
  writeFileSync(join(only, 'verdict.json'), JSON.stringify(verdictFixture({ checks: [] })));
  const { eligible, ineligible } = eligibleRuns(resultsRoot, scenariosRootWith('delta', 'epsilon'), AGENTS);
  expect(eligible.map((e) => e.runId)).toEqual(['delta-claude-auto-20260101T000000Z-0004']);
  expect(ineligible.map((i) => [i.scenario, i.reason])).toEqual([['epsilon', 'no-post-records']]);
});
```

Run: `bun test test/replay-post-checks.test.ts` — Expected: FAIL (module missing).

- [ ] **Step 2: Implement part one**

`src/cli/replay-post-checks.ts` (CLI `main` is Task 10; this task exports the three functions). The load-bearing pieces:

```ts
export function cloneWorkspace(run: EligibleRun, dest: string): PointerReport {
  const srcRoot = realpathSync(run.workspaceRoot);
  // Every workspace entry: the workdir, its coding-agent-workdir-* siblings,
  // the home, and the sentinel; never the record files.
  mkdirSync(dest, { recursive: true });
  for (const name of readdirSync(srcRoot)) {
    if (run.layout === 'legacy' && !(name === 'home' || name === 'package.json' || name.startsWith('coding-agent-workdir'))) continue;
    cpSync(join(srcRoot, name), join(dest, name), { recursive: true, verbatimSymlinks: true, errorOnExist: true, force: false });
  }
  const destReal = realpathSync(dest);
  const report: PointerReport = { gitPointers: [], rewrittenSymlinks: [], externalReferences: [] };
  // Rewrite intra-source absolute symlinks to the arm; classify the rest.
  for (const link of walkSymlinks(destReal)) {
    const target = readlinkSync(link);
    if (!isAbsolute(target)) continue;
    if (target === srcRoot || target.startsWith(srcRoot + sep)) {
      const rewritten = join(destReal, relative(srcRoot, target));
      unlinkSync(link); symlinkSync(rewritten, link); report.rewrittenSymlinks.push(link);
    } else {
      report.externalReferences.push(link);
    }
  }
  // Worktree repair, with every cloned linked worktree named: without the
  // arguments, repair follows the copied gitdir pointer into the SOURCE and
  // rewrites it. Assert that precondition before running it.
  const main = join(destReal, 'coding-agent-workdir');
  if (existsSync(join(main, '.git', 'worktrees'))) {
    const linked = readdirSync(destReal).filter((n) => n.startsWith('coding-agent-workdir-')).map((n) => join(destReal, n));
    for (const wt of readdirSync(join(main, '.git', 'worktrees'))) {
      const gitdir = readFileSync(join(main, '.git', 'worktrees', wt, 'gitdir'), 'utf8').trim();
      if (gitdir.startsWith(destReal + sep)) continue; // already inside; nothing to repair
      if (!(gitdir.startsWith(srcRoot + sep))) throw new Error(`unexpected gitdir pointer ${gitdir}`);
    }
    const r = spawnSync('git', ['-C', main, 'worktree', 'repair', ...linked], { encoding: 'utf8' });
    if (r.status !== 0) throw new Error(`git worktree repair failed: ${r.stderr}`);
  }
  // Validate: every .git file and gitdir file resolves inside the arm; no
  // pointer of any class resolves into the source.
  for (const p of walkFiles(destReal, (f) => basename(f) === '.git' || basename(f) === 'gitdir')) {
    const v = readFileSync(p, 'utf8').trim().replace(/^gitdir: /, '');
    if (!v.startsWith(destReal + sep)) throw new Error(`${p} points outside the arm: ${v}`);
    report.gitPointers.push(p);
  }
  for (const link of walkSymlinks(destReal)) {
    const t = readlinkSync(link);
    if (isAbsolute(t) && (t === srcRoot || t.startsWith(srcRoot + sep))) throw new Error(`${link} still points into the source`);
  }
  return report;
}
```

with `walkSymlinks`, `walkFiles(root, predicate)`, `hashTree` (sha256 over sorted relative paths; regular files by content, symlinks by target string, directories by name) and `eligibleRuns` (list `scenariosRoot`'s directories holding a `story.md`; group `parseRunDirName(name, knownAgents)`-parseable children of `resultsRoot` by scenario; sort newest-first by `started_at` then nonce; take the first candidate passing all four tests; otherwise report the newest candidate's first failing reason in the declared order, or `no-run`) written beside it. Import only what each file uses; Biome rejects unused imports. `scripts/replay-post-checks`:

```bash
#!/usr/bin/env bash
# Counterfactual replay of every eligible recorded run's checks under the
# legacy and the new post-check environment (spec, Verification item 7).
# A thin wrapper so the replay sits beside strip-runs; the logic is TypeScript.
set -euo pipefail
exec bun run "$(cd "$(dirname "$0")/.." && pwd)/src/cli/replay-post-checks.ts" "$@"
```

- [ ] **Step 3: Run and commit**

Run: `bun test test/replay-post-checks.test.ts` — Expected: PASS. Run: `bun run check` — Expected: PASS.

```bash
git add src/cli/replay-post-checks.ts scripts/replay-post-checks test/replay-post-checks.test.ts
git commit -m "feat(replay): clone a recorded workspace into an isolated arm with repaired worktree pointers, and classify which runs are replayable"
```

---

### Task 10: The corpus replay, part two — two arms, comparison, anti-vacuity, coverage, synthetic fixtures

**Risk tier:** high — this is the gate's instrument; a comparison that can pass vacuously proves nothing.

**Files:**
- Modify: `src/cli/replay-post-checks.ts` (add the arms, comparison, prerequisite, coverage floor, synthetic-fixture mode, `main`)
- Create: `test/fixtures/replay-synthetic/tdd-history-json/`, `test/fixtures/replay-synthetic/migrated-grep-shape/`, `test/fixtures/replay-synthetic/seam-dumper/` (each: `checks.sh`, `workspace/` seed files)
- Test: `test/replay-post-checks.test.ts` (nine new cases)
- Modify: `biome.json:98-119` (add `test/replay-post-checks.test.ts` to the `noProcessEnv` override: the seam-dumper test plants a key and the corpus test reads `QUORUM_CORPUS_ROOT`)

**Interfaces:**
- Consumes: `runPhaseWithEnv`, `outerEnv` (Task 1); `cloneWorkspace`, `eligibleRuns`, `hashTree` (Task 9); `agentConfigDir(cfg, runHomeDir)` and `AgentConfigSchema` from `src/contracts/agent-config.ts:21-50` — **not** `loadAgentConfig` (`:64-110`), which validates `required_env` against the live environment (`claude-auto` requires `SUPERPOWERS_ROOT`, `coding-agents/claude-auto.yaml:16`) and would make an offline replay depend on provider credentials; `parseRunDirName`.
- Produces:
  ```ts
  export interface ArmRecord { phase: 'pre' | 'post'; check: string; args: string[]; negated: boolean; passed: boolean; }
  export interface ArmResult { raw: ArmRecord[]; canonical: ArmRecord[]; exitCodes: { pre: number; post: number }; rewrites: number; home: string; root: string; }  // raw as emitted; canonical with this arm's root replaced by <ARM>; home/root = this arm's clone
  export interface ReplayOptions { repoRoot: string; scenariosRoot?: string; codingAgent?: string; agentsDir?: string; scratch: () => string; checksFile?: string; }
  // scenariosRoot defaults to join(repoRoot, 'scenarios'); agentsDir to join(repoRoot, 'coding-agents'); checksFile to 'checks.sh'.
  // A corpus run's checks file is join(scenariosRoot, run.scenario, checksFile); a fixture's is join(fixtureDir, checksFile).
  export interface ReplayResult {
    scenario: string; runId: string | null;            // null for a synthetic fixture
    status: 'equal' | 'diverged' | 'degraded-archive';
    firstDivergence?: string; degradedCheck?: string;
    preDivergencesFromHistory: string[];               // listed, never demoting
    unmatchedHistory: string[];                        // historical post passes whose current text changed or vanished; listed, never demoting
    unparsedLines: string[];                           // post() lines the static scan could not read as a check; listed
    tools: string[];                                   // leading tokens of post-phase command-succeeds inner commands
    armL: ArmResult; armN: ArmResult; externalReferences: string[];
  }
  export function legacyOuterEnv(args: OuterEnvArgs): Record<string, string>;      // today's construction + QUORUM_AGENT_HOME + QUORUM_INNER_ENV=legacy
  export function canonicalize(records: ArmRecord[], armRoot: string): { records: ArmRecord[]; rewrites: number };
  export function compareArms(l: ArmResult, n: ArmResult): { equal: boolean; firstDivergence?: string };   // compares canonical records and exit codes
  export function replayRun(run: EligibleRun, opts: ReplayOptions): Promise<ReplayResult>;                  // async: runPhaseWithEnv is async
  export function replayFixture(fixtureDir: string, opts: ReplayOptions & { armLMutate?: (env: Record<string,string>) => Record<string,string> }): Promise<ReplayResult>;
  export const INNER_COMMAND_TOOLS: readonly string[]; // grep test node git find npm awk ls npx go pytest python3
  export function coverage(results: ReplayResult[], eligibleCount: number): { ok: boolean; replayable: number; floor: number; uncoveredTools: string[]; migratedUncovered: string[] };
  // replayable counts CORPUS results only (runId !== null); synthetic fixtures count toward uncoveredTools and migratedUncovered, never toward the floor.
  export function offlineAgentConfig(agentsDir: string, name: string): AgentConfig;  // AgentConfigSchema.parse(parseYaml(readFileSync(join(agentsDir, `${name}.yaml`)))) — schema only, no required_env check: the replay needs home_config_subdir and nothing live
  export interface SourceRoots { runDir: string; workspaceRoot: string; agentHome: string; configDir: string; }
  export function expectedPostChecks(checksShText: string, roots: SourceRoots): { expected: Set<string>; unparsedLines: string[] };  // static scan of post(); keys are JSON.stringify([check, canonicalArgs, negated])
  ```
  `main` arguments: `--results <root>` (default `results`), `--scenarios <root>` (default `scenarios`; passed to `eligibleRuns` and used to locate each run's `checks.sh`), `--agents-dir <dir>` (default `coding-agents`; its `*.yaml` basenames are `knownAgents`), `--report <dir>` (writes `replay.json` and `replay.md`), `--synthetic <dir>` (repeatable; a fixture directory), `--only <scenario>` (repeatable). Exit 0 when every replayable run is `equal` and `coverage().ok`; 1 otherwise; **2 when `--results` holds no eligible run at all** (an empty or wrong root is an instrument error, not a result); the report is written either way.

**Mirror:** `src/checks/index.ts` `runPhaseWithEnv` call shape (Task 1); `test/check-tool.test.ts` for a test that plants a workdir and reads a sink.

- [ ] **Step 1: The synthetic fixtures (data, not code)**

`test/fixtures/replay-synthetic/<name>/checks.sh` is a normal scenario `checks.sh`; `workspace/` is copied into each arm's `coding-agent-workdir` (and `workspace-home/` into its `home`) before the arms run.

`tdd-history-json/checks.sh`:
```bash
pre() { :; }
post() {
    command-succeeds 'expected=$(node -e "process.stdout.write(JSON.stringify({argc:0,args:[],home:process.env.QUORUM_AGENT_HOME}))") && grep -qxF "$expected" .test-history.log'
}
```
with `workspace/.test-history.log` **written by the replay at arm time** (the home path is per arm): the fixture's `workspace/.test-history.log.tmpl` contains `{"argc":0,"args":[],"home":"__AGENT_HOME__"}` and `replayFixture` substitutes each arm's home before copying. This is the migrated TDD check in its exact current shape (`scenarios/tdd-runs-the-project-suite/checks.sh:53` after Task 7), in the JSON format every recorded log lacks.

`migrated-grep-shape/checks.sh` (the exact shape of `codex-approach-gate-fires-on-architecture/checks.sh:20` after Task 7), with `workspace-home/.cache/hyperpowers/codex-review/round1.md` containing `FIXTURE-IDEA-7Q4`:
```bash
pre() { :; }
post() {
    command-succeeds 'grep -rq "FIXTURE-IDEA-7Q4" "$QUORUM_AGENT_HOME/.cache/hyperpowers/codex-review"'
}
```
and `migrated-grep-shape/checks.double-quoted.sh`, the pre-migration form, used only by the regression:
```bash
pre() { :; }
post() {
    command-succeeds "grep -rq 'FIXTURE-IDEA-7Q4' \"$QUORUM_AGENT_HOME/.cache/hyperpowers/codex-review\""
}
```

`seam-dumper/checks.sh`:
```bash
pre() { :; }
post() {
    command-succeeds 'env | sort > "$QUORUM_AGENT_HOME/dump.txt"'
}
```

- [ ] **Step 2: The failing tests**

Extend `test/replay-post-checks.test.ts` (Task 9's file). Grow its existing import statements rather than adding new ones — one statement per module, or Biome's import organizer fails `bun run check` — so the three affected lines read:

```ts
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readlinkSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { cloneWorkspace, compareArms, coverage, eligibleRuns, expectedPostChecks, hashTree, replayFixture, replayRun } from '../src/cli/replay-post-checks.ts';
```

Then append, after the file's existing helpers:

```ts
const REPO = resolve(import.meta.dir, '..');
const FIX = join(REPO, 'test', 'fixtures', 'replay-synthetic');
const OPTS = { repoRoot: REPO, codingAgent: 'claude-auto', scratch: () => mkdtempSync(join(tmpdir(), 'arms-')) };

// results/ is gitignored (evals/.gitignore:1), so a feature worktree has no corpus of its
// own: the retained corpus is the primary checkout's results/, found through the common git
// dir (<primary>/.git for a linked worktree), unless QUORUM_CORPUS_ROOT names another.
function primaryCheckout(repo: string): string {
  const r = spawnSync('git', ['-C', repo, 'rev-parse', '--git-common-dir'], { encoding: 'utf8' });
  if (r.status !== 0) throw new Error(r.stderr);
  return realpathSync(join(resolve(repo, r.stdout.trim()), '..'));
}
const CORPUS_ROOT = process.env['QUORUM_CORPUS_ROOT'] ?? join(primaryCheckout(REPO), 'results');

test('migrated grep shape: both arms pass with byte-identical raw records and zero rewrites', async () => {
  const r = await replayFixture(join(FIX, 'migrated-grep-shape'), OPTS);
  expect(r.status).toBe('equal');
  expect(r.armL.raw.find((x) => x.phase === 'post')?.passed).toBe(true);
  expect(r.armN.raw.find((x) => x.phase === 'post')?.passed).toBe(true);
  expect(JSON.stringify(r.armL.raw)).toBe(JSON.stringify(r.armN.raw));
  expect(r.armL.rewrites + r.armN.rewrites).toBe(0);
}, 60_000);

test('the pre-migration double-quoted form expands per arm: raw records differ, the canonicalizer rewrites, canonical records then agree', async () => {
  const r = await replayFixture(join(FIX, 'migrated-grep-shape'), { ...OPTS, checksFile: 'checks.double-quoted.sh' });
  const rawL = r.armL.raw.find((x) => x.phase === 'post')?.args.join(' ');
  const rawN = r.armN.raw.find((x) => x.phase === 'post')?.args.join(' ');
  expect(rawL).not.toBe(rawN);                       // each arm's own clone root is in its args
  expect(r.armL.rewrites + r.armN.rewrites).toBeGreaterThan(0);
  expect(r.status).toBe('equal');                    // after canonicalization — which is why the migration, not the canonicalizer, is the fix
}, 60_000);

test('synthetic TDD fixture: equal with both arms passing; Arm L without QUORUM_AGENT_HOME diverges', async () => {
  const ok = await replayFixture(join(FIX, 'tdd-history-json'), OPTS);
  expect(ok.status).toBe('equal');
  expect(ok.armN.raw.find((x) => x.phase === 'post')?.passed).toBe(true);
  const mutated = await replayFixture(join(FIX, 'tdd-history-json'), {
    ...OPTS,
    armLMutate: (env) => { const { QUORUM_AGENT_HOME: _h, ...rest } = env; return rest; },
  });
  expect(mutated.status).toBe('diverged');
}, 60_000);

test('seam dumper: Arm L inherits the operator HOME and the sink; Arm N has the agent home and neither', async () => {
  const prevKey = process.env['ANTHROPIC_API_KEY']; process.env['ANTHROPIC_API_KEY'] = 'sk-planted';
  try {
    const r = await replayFixture(join(FIX, 'seam-dumper'), OPTS);
    expect(r.status).toBe('equal'); // the check passes in both arms; the dumps are what differ
    const dumpL = readFileSync(join(r.armL.home, 'dump.txt'), 'utf8');
    const dumpN = readFileSync(join(r.armN.home, 'dump.txt'), 'utf8');
    expect(dumpL).toContain(`HOME=${process.env['HOME']}`);
    expect(dumpL).toContain('QUORUM_RECORD_SINK=');
    expect(dumpL).toContain('ANTHROPIC_API_KEY=sk-planted');
    expect(dumpL).not.toContain('QUORUM_INNER_ENV=');
    expect(dumpN).toContain(`HOME=${r.armN.home}`);
    expect(dumpN).not.toContain('QUORUM_RECORD_SINK=');
    expect(dumpN).not.toContain('ANTHROPIC_API_KEY=');
    expect(dumpN).not.toContain('QUORUM_INNER_ENV=');
  } finally { if (prevKey === undefined) delete process.env['ANTHROPIC_API_KEY']; else process.env['ANTHROPIC_API_KEY'] = prevKey; }
}, 60_000);

test('compareArms includes exit codes; coverage counts corpus runs only toward the floor', () => {
  const rec = { phase: 'post' as const, check: 'file-exists', args: ['x'], negated: false, passed: true };
  const a = { raw: [rec], canonical: [rec], exitCodes: { pre: 0, post: 0 }, rewrites: 0, home: '', root: '' };
  expect(compareArms(a, { ...a, exitCodes: { pre: 0, post: 1 } }).equal).toBe(false);
  // Raw records that differ only by arm root compare equal through canonical; a canonical difference is named.
  const rawL = { ...rec, args: ['/arms/L/coding-agent-workdir/x'] };
  const rawN = { ...rec, args: ['/arms/N/coding-agent-workdir/x'] };
  const canon = { ...rec, args: ['<ARM>/coding-agent-workdir/x'] };
  const L = { ...a, raw: [rawL], canonical: [canon], root: '/arms/L' };
  const N = { ...a, raw: [rawN], canonical: [canon], root: '/arms/N' };
  expect(compareArms(L, N).equal).toBe(true);
  expect(compareArms(L, { ...N, canonical: [{ ...canon, passed: false }] }).firstDivergence).toContain('record 0');
  const base = { status: 'equal' as const, tools: ['node', 'grep'], preDivergencesFromHistory: [], unmatchedHistory: [], unparsedLines: [], armL: a, armN: a, externalReferences: [] };
  const synthetic = { ...base, scenario: 'tdd-runs-the-project-suite', runId: null };
  const corpus = { ...base, scenario: 'some-scenario', runId: 'some-scenario-claude-auto-20260101T000000Z-aaaa' };
  const c = coverage([synthetic, corpus], 61);
  expect(c.floor).toBe(41);
  expect(c.replayable).toBe(1);              // the synthetic did not count
  expect(c.ok).toBe(false);
  expect(c.uncoveredTools).toEqual(expect.arrayContaining(['go', 'pytest', 'python3']));
  expect(c.migratedUncovered).toEqual(expect.arrayContaining(['codex-approach-gate-fires-on-architecture']));
});

test('expectedPostChecks: continuations fold, quoted shell syntax is argument text, unquoted expansion and keywords are unparsed', () => {
  // The first four post lines are scenarios/worktree-no-drift-to-main/checks.sh:10-14 verbatim.
  const body = [
    'pre() { :; }',
    'post() {',
    '    check-transcript tool-count Agent gte 2',
    '    assert-checkout-clean .',
    '    # --branches (not --all): stash refs must not count as landed work.',
    '    command-succeeds \'test "$(git rev-list --count --branches --not main)" -ge 1\'',
    '    not file-exists "$QUORUM_AGENT_HOME/.claude/settings.json"',
    // codex-gate-backstop-finding-forces-choice/checks.sh:31-33 verbatim: a continuation.
    '    check-transcript tool-arg-match Bash \\',
    "        --matches 'command=gate-round' \\",
    "        --matches 'command=--ceiling 3'",
    '    file-exists "$(pwd)/x"',
    '    for f in a b; do file-exists "$f"; done',
    '}',
  ].join('\n');
  const roots = { runDir: '/src/run', workspaceRoot: '/src/run', agentHome: '/src/run/home', configDir: '/src/run/home/.claude' };
  const { expected, unparsedLines } = expectedPostChecks(body, roots);
  expect([...expected].sort()).toEqual([
    JSON.stringify(['assert-checkout-clean', ['.'], false]),
    JSON.stringify(['command-succeeds', ['test "$(git rev-list --count --branches --not main)" -ge 1'], false]),
    JSON.stringify(['file-exists', ['<ARM>/home/.claude/settings.json'], true]),
    JSON.stringify(['tool-arg-match', ['Bash', '--matches', 'command=gate-round', '--matches', 'command=--ceiling 3'], false]),
    JSON.stringify(['tool-count', ['Agent', 'gte', '2'], false]),
  ].sort());
  expect(unparsedLines).toEqual(['file-exists "$(pwd)/x"', 'for f in a b; do file-exists "$f"; done']);
});

test('anti-vacuity: an unchanged historical post check that emits no record because the phase aborted early is a degraded archive', async () => {
  // A fabricated corpus run: the recorded verdict passed two post checks; the
  // current checks.sh aborts between them. runPhase runs the phase as
  // `bash -c "source prelude; source checks.sh; post"` with no `set -e`
  // (src/checks/index.ts:94), so a failing command inside post() would NOT
  // stop it — only an explicit exit does. `exit 127` ends the bash process in
  // the crash band (src/checks/index.ts:136), so the second check never emits
  // a record in either arm. Both arms crash identically: equality alone would
  // call that a pass.
  const resultsRoot = join(root, 'results3');
  const runDir = join(resultsRoot, 'abort-claude-auto-20260101T000000Z-0003');
  mkdirSync(join(runDir, 'coding-agent-workdir'), { recursive: true });
  mkdirSync(join(runDir, 'home'), { recursive: true });
  writeFileSync(join(runDir, 'coding-agent-workdir', 'a.txt'), '');
  writeFileSync(join(runDir, 'coding-agent-workdir', 'b.txt'), '');
  writeFileSync(join(runDir, 'verdict.json'), JSON.stringify(verdictFixture({ checks: [record('file-exists', true, 'post', ['a.txt']), record('file-exists', true, 'post', ['b.txt'])] })));
  const scenarios = scenariosRootWith('abort');
  writeFileSync(join(scenarios, 'abort', 'checks.sh'), 'pre() { :; }\npost() {\n  file-exists a.txt\n  exit 127\n  file-exists b.txt\n}\n');
  const { eligible } = eligibleRuns(resultsRoot, scenarios, AGENTS);
  const r = await replayRun(eligible[0]!, { ...OPTS, scenariosRoot: scenarios });
  expect(r.armL.exitCodes.post).toBe(127);
  expect(r.armN.exitCodes.post).toBe(127);
  expect(r.status).toBe('degraded-archive');
  expect(r.degradedCheck).toContain('b.txt');
}, 60_000);

test('anti-vacuity: a historical post pass whose text is no longer in checks.sh is listed as unmatched history and never demotes', async () => {
  // The migrated scenarios of Task 7 produce exactly this: the recorded args name the
  // old path, the current text names the new one, and the run must stay replayable.
  const resultsRoot = join(root, 'results5');
  const runDir = join(resultsRoot, 'moved-claude-auto-20260101T000000Z-0007');
  mkdirSync(join(runDir, 'coding-agent-workdir'), { recursive: true });
  mkdirSync(join(runDir, 'home'), { recursive: true });
  writeFileSync(join(runDir, 'coding-agent-workdir', 'a.txt'), '');
  writeFileSync(join(runDir, 'verdict.json'), JSON.stringify(verdictFixture({ checks: [record('file-exists', true, 'post', ['a.txt']), record('file-exists', true, 'post', ['z.txt'])] })));
  const scenarios = scenariosRootWith('moved');
  writeFileSync(join(scenarios, 'moved', 'checks.sh'), 'pre() { :; }\npost() {\n  file-exists a.txt\n}\n');
  const { eligible } = eligibleRuns(resultsRoot, scenarios, AGENTS);
  const r = await replayRun(eligible[0]!, { ...OPTS, scenariosRoot: scenarios });
  expect(r.status).toBe('equal');
  expect(r.unmatchedHistory).toHaveLength(1);
  expect(r.unmatchedHistory[0]).toContain('z.txt');
  expect(r.unparsedLines).toEqual([]);
}, 60_000);

test.skipIf(!existsSync(CORPUS_ROOT))('corpus worktree run: replay leaves the retained record and workspace byte-identical and keeps each arm out of the other', async () => {
  // The spec names this run. A host with no corpus root at all skips (bun reports the
  // skip, and Task 10's acceptance requires zero skips on this host); a corpus root
  // without this run is a failure, not a skip.
  const corpus = CORPUS_ROOT;
  const runId = 'worktree-no-drift-to-main-claude-auto-20261003T112456Z-f670';
  expect(existsSync(join(corpus, runId, 'coding-agent-workdir'))).toBe(true);
  const before = hashTree(join(corpus, runId));
  const { eligible } = eligibleRuns(corpus, resolve(REPO, 'scenarios'), ['claude-auto']);
  const run = eligible.find((e) => e.runId === runId);
  expect(run).toBeDefined();
  const r = await replayRun(run!, { ...OPTS, scenariosRoot: resolve(REPO, 'scenarios') });
  expect(hashTree(join(corpus, runId))).toBe(before);
  expect(r.externalReferences.length).toBeGreaterThan(0); // the Claude URL-handler symlink
  expect(r.armL.root).not.toBe(r.armN.root);
  expect(r.status).toBe('equal');
  expect(r.unparsedLines).toEqual([]);     // the quoted-$( check parses as one argument
  expect(r.unmatchedHistory).toEqual([]);  // nothing in this scenario's text has changed
  // That check is load-bearing: abort the phase just before it and the run must degrade.
  const mutated = scenariosRootWith('worktree-no-drift-to-main');
  const text = readFileSync(join(REPO, 'scenarios', 'worktree-no-drift-to-main', 'checks.sh'), 'utf8');
  const aborted = text.replace("    command-succeeds 'test", "    exit 127\n    command-succeeds 'test");
  expect(aborted).not.toBe(text);
  writeFileSync(join(mutated, 'worktree-no-drift-to-main', 'checks.sh'), aborted);
  const d = await replayRun(run!, { ...OPTS, scenariosRoot: mutated });
  expect(d.status).toBe('degraded-archive');
  expect(d.degradedCheck).toContain('rev-list');
  expect(hashTree(join(corpus, runId))).toBe(before);
}, 300_000);
```

Run: `bun test test/replay-post-checks.test.ts` — Expected: FAIL on the missing exports.

- [ ] **Step 3: Implement part two**

Key functions in `src/cli/replay-post-checks.ts`:

```ts
export function legacyOuterEnv(a: OuterEnvArgs): Record<string, string> {
  // Today's runPhase construction, reproduced here and only here: the whole
  // ambient environment plus the QUORUM contract, plus the one variable the
  // migrated checks need, plus the selector that makes the dispatcher inherit.
  const base = envSnapshot();
  const env: Record<string, string | undefined> = {
    ...base,
    PATH: base['PATH'] ?? '/usr/bin:/bin',
    QUORUM_REPO_ROOT: a.repoRoot,
    QUORUM_AGENT_HOME: a.agentHome,
    QUORUM_INNER_ENV: 'legacy',
    ...(a.transcriptPath !== undefined ? { QUORUM_TRANSCRIPT_PATH: a.transcriptPath } : {}),
    ...(a.runDir !== undefined ? { QUORUM_RUN_DIR: a.runDir } : {}),
    ...(a.configDir !== undefined ? { QUORUM_AGENT_CONFIG_DIR: a.configDir } : {}),
    ...(a.codingAgent !== undefined ? { QUORUM_CODING_AGENT: a.codingAgent } : {}),
  };
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(env)) if (v !== undefined) out[k] = v;
  return out;
}

export function canonicalize(records: ArmRecord[], armRoot: string): { records: ArmRecord[]; rewrites: number } {
  let rewrites = 0;
  const real = realpathSync(armRoot);
  const out = records.map((r) => {
    const args = r.args.map((s) => s.split(real).join('<ARM>').split(armRoot).join('<ARM>'));
    if (args.some((s, i) => s !== r.args[i])) rewrites += 1;
    return { ...r, args };
  });
  return { records: out, rewrites };
}

export function compareArms(l: ArmResult, n: ArmResult): { equal: boolean; firstDivergence?: string } {
  if (l.exitCodes.pre !== n.exitCodes.pre || l.exitCodes.post !== n.exitCodes.post) {
    return { equal: false, firstDivergence: `exit codes L=${JSON.stringify(l.exitCodes)} N=${JSON.stringify(n.exitCodes)}` };
  }
  const key = (r: ArmRecord) => JSON.stringify([r.phase, r.check, r.args, r.negated, r.passed]);
  const max = Math.max(l.canonical.length, n.canonical.length);
  for (let i = 0; i < max; i++) {
    const a = l.canonical[i], b = n.canonical[i];
    if (a === undefined || b === undefined || key(a) !== key(b)) {
      return { equal: false, firstDivergence: `record ${i}: L=${a ? key(a) : 'absent'} N=${b ? key(b) : 'absent'}` };
    }
  }
  return { equal: true };
}
```

`async runArm(mode, armRoot, phases)` where `phases = { pre: RunPhaseArgs; post: RunPhaseArgs }` mirrors the two production call sites exactly (`src/runner/index.ts:1159-1167, 1524-1533`): `pre = { checksSh, phase: 'pre', workdir, repoRoot, runDir, configDir, codingAgent, agentHome }` and `post = { ...pre, phase: 'post', transcriptPath }` (`transcriptPath` set only when `<run>/trajectory.json` exists); for each phase separately it builds `env = mode === 'legacy' ? legacyOuterEnv(args) : outerEnv(envSnapshot(), args)`, applies `armLMutate` for Arm L when given, and awaits `runPhaseWithEnv(args, env)` — so `QUORUM_TRANSCRIPT_PATH` exists only in the post environment, as in production; it tags records with the phase, keeps them as `raw`, computes `canonical` and `rewrites` with `canonicalize(raw, armRoot)`, and returns `ArmResult` with `home` and `root`. `compareArms` compares `canonical` and the exit codes. `async replayRun`: **hash the source first** — `hashTree(run.runDir)` and `hashTree(run.workspaceRoot)` — then clone Arm L via `cloneWorkspace` into `opts.scratch()`, re-hash the source and assert unchanged, clone Arm N, re-hash and assert again; after both arms have run, re-hash a third time and assert, and walk each arm's pointers asserting none resolves into the source or into the other arm's root (throw otherwise — a run whose replay touched retained evidence is a failure of the instrument, not a result). Derive `configDir = agentConfigDir(offlineAgentConfig(agentsDir, agent), join(arm, 'home'))` with the agent from `parseRunDirName`, `checksSh = join(opts.scenariosRoot ?? join(opts.repoRoot, 'scenarios'), run.scenario, opts.checksFile ?? 'checks.sh')`, run both arms, then the **anti-vacuity prerequisite**, whose expected set is built from the *current* `checks.sh` text, independently of anything either arm emitted. `expectedPostChecks(text, roots)` takes the `post()` body (from the line `post() {` to its closing `}` at column 0), first **folds bash continuations** — a line ending in an unquoted backslash joins the next, so `scenarios/codex-gate-backstop-finding-forces-choice/checks.sh:31-33` is one logical line and one `tool-arg-match` record with five args, as the corpus recorded it — and reads each non-blank, non-comment logical line with a **quote-aware** shell-words tokenizer: single quotes are literal to the closing quote, double quotes and backslashes follow bash, and quoted text is opaque — a `$(…)`, backtick or `|` *inside quotes* is just characters of the argument, exactly as bash hands it to the check (the named corpus run's `command-succeeds 'test "$(git rev-list --count --branches --not main)" -ge 1'` is one verb and one argument). A line is **not a check line** — it goes to `unparsedLines`, trimmed — only when the shell would do something the scan cannot reproduce: an unquoted or double-quoted `$(` or backtick; an unquoted `|`, `;`, `&`, `<`, `>`, `(` or `)`; a `$NAME`/`${NAME}` other than the three below outside single quotes; or a first token that is a bash keyword (`for`, `while`, `if`, `case`, `{`, `}`, `fi`, `done`) rather than verb-shaped (`^[a-z][a-z0-9-]*$`). Otherwise it drops a leading `not` (setting `negated`) and a leading `check-transcript`, takes the first remaining token as the check name and the rest as args, expands `$QUORUM_AGENT_HOME`/`${QUORUM_AGENT_HOME}`, `$QUORUM_RUN_DIR` and `$QUORUM_AGENT_CONFIG_DIR` (bare or double-quoted) from `roots` (`agentHome = join(workspaceRoot, 'home')`, `configDir = agentConfigDir(cfg, agentHome)`), canonicalizes the args against the source roots (`runDir`, `workspaceRoot` → `<ARM>`) and adds `JSON.stringify([check, args, negated])` to `expected`. **An unparsed line is never silently non-load-bearing:** its leading verb-shaped tokens (after `not`/`check-transcript`) name a candidate check, and if any historical passing post record with that check name is left unmatched after the expected set is applied, the run is `degraded-archive` with `degradedCheck = 'unparsed: <line>'` — the instrument cannot tell an unchanged check from a changed one there, so it does not count the run. Then, for each recorded `verdict.json` check with `phase === 'post' && passed === true`, canonicalize its args the same way and form its key: a key **not in `expected`** is a changed or removed check — pushed to `unmatchedHistory`, listed, never demoting (the four migrated scenarios land here by design); a key **in `expected`** must have a current Arm L post record with the same key **and** `passed === true` — none present, or present and failed, → `status: 'degraded-archive'` with `degradedCheck` naming it (an absent record is how an early abort hides a check). Only then compare arms. `preDivergencesFromHistory` = recorded pre passes with a same-text Arm L pre record that failed. `tools` = leading tokens of post-phase `command-succeeds` args after stripping `!`, assignments and `$(` (the spec's survey rule). `replayFixture` does the same without a recorded verdict (no prerequisite; `preDivergencesFromHistory`, `unmatchedHistory` and `unparsedLines` empty), seeding `workspace/` and `workspace-home/` and substituting `__AGENT_HOME__` in any `*.tmpl`. `coverage`: `floor = Math.ceil(eligibleCount * 2 / 3)`; `replayable = results.filter(r => r.runId !== null && r.status !== 'degraded-archive').length` — corpus runs only; `uncoveredTools = INNER_COMMAND_TOOLS − ∪ tools of replayable results`; `migratedUncovered = the four names − scenarios present among replayable results (corpus or synthetic)`; `ok = replayable >= floor && uncoveredTools.length === 0 && migratedUncovered.length === 0 && every replayable is 'equal'`. `main` writes `replay.json` (all `ReplayResult`s plus `ineligible` and `coverage`) and `replay.md` (one row per scenario: run id, layout, pre/post record counts, status, first divergence or degraded check, external references, pre divergences, unmatched history, unparsed lines) and exits per the contract above.

- [ ] **Step 4: Run and commit**

Run: `bun test test/replay-post-checks.test.ts` — Expected: PASS, twelve tests, **0 skipped**: on this host the corpus test must run (bun prints a skip count otherwise; a skip here means `CORPUS_ROOT` resolved wrongly and is a task failure, not a pass). Run: `bun run check` — Expected: PASS.

```bash
git add src/cli/replay-post-checks.ts test/replay-post-checks.test.ts test/fixtures/replay-synthetic biome.json
git commit -m "feat(replay): run every recorded check under the legacy and the new environment and require identical records, with an anti-vacuity prerequisite and a coverage floor"
```

---

### Task 11: Run the corpus replay and resolve what it finds

**Risk tier:** high — it produces the trusted compatibility evidence the release rests on, and a divergence it surfaces may demand a change to the credential allowlist (made in a separate high task after the human partner's decision, never here).

**Files:**
- Create: `evidence/2026-10-14-agent-write-isolation-relocation/replay/run-replay.sh` (the command of record), `replay/replay.json`, `replay.md`, `stdout.txt`, `README.md` (the replay section of the evidence note)
- Possibly create: `test/fixtures/replay-synthetic/*` (new counterfactuals)
- Never modifies `src/checks/env-allowlist.ts`: an allowlist change is a spec change, decided by the human partner and executed as its own high-tier task appended to this plan.
- Never modifies `scenarios/`: a scenario repair is its own task (Step 2, item 1).

**Interfaces:**
- Consumes: `scripts/replay-post-checks` (Tasks 9–10).
- Produces: the retained report; this task is the validation named by the spec's first Assumption.

- [ ] **Step 1: Run it over the corpus**

Write the command of record as a bash script — the interactive shell is zsh, which has no `PIPESTATUS`, so the pipeline and its status capture live together in one bash file — `evidence/2026-10-14-agent-write-isolation-relocation/replay/run-replay.sh`:

```bash
#!/usr/bin/env bash
# The corpus replay of record. Invoke as `bash <this file>` from anywhere.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"            # evidence/<dir>/replay
repo="$(cd "$here/../../.." && pwd -P)"              # the worktree
# results/ is gitignored: the retained corpus lives in the primary checkout, which
# `--git-common-dir` names (relative for the primary checkout, absolute for a worktree).
common="$(git -C "$repo" rev-parse --git-common-dir)"
case "$common" in /*) ;; *) common="$repo/$common" ;; esac
corpus="$(cd "$common/.." && pwd -P)/results"
test -d "$corpus/worktree-no-drift-to-main-claude-auto-20261003T112456Z-f670" || { echo "corpus root wrong: $corpus" >&2; exit 2; }
cd "$repo"
bash scripts/replay-post-checks --results "$corpus" --scenarios "$repo/scenarios" --report "$here" \
  --synthetic test/fixtures/replay-synthetic/tdd-history-json \
  --synthetic test/fixtures/replay-synthetic/migrated-grep-shape 2>&1 | tee "$here/stdout.txt"
rc=${PIPESTATUS[0]}
echo "replay exit: $rc (corpus: $corpus)" | tee -a "$here/stdout.txt"
exit "$rc"
```

Run, from anywhere, with the host otherwise idle of live evals: `bash evidence/2026-10-14-agent-write-isolation-relocation/replay/run-replay.sh`. Each `--synthetic` fixture Step 2 adds is appended to the script, so the script always reproduces the retained report.

Expected: the report is written; the recorded exit is whatever the corpus earns (a `2` means the corpus root is wrong — fix the root, not the plan). Record the corpus path the script printed, the coverage line (`replayable N of eligible M, floor F`), the uncovered tools, and the migrated scenarios not covered.

- [ ] **Step 2: Resolve each class of outcome, in this order**

1. **A `diverged` run.** Read `firstDivergence`. If Arm N failed a check Arm L passed because an inner command needed a variable the allowlist does not carry, that is a **spec-level change**: stop and surface it to your human partner with the check, the variable and the tool, per the spec ("added deliberately"); do not add it on your own. If they approve, append a new high-tier task to this plan that changes `src/checks/env-allowlist.ts` and `test/env-allowlist.test.ts`, executed and reviewed on its own before this task resumes. If Arm N passed where Arm L failed, the check depended on the operator's home: that is a defect in the check. **Stop; do not edit `scenarios/` in this task.** The repair is its own standard-tier task appended to this plan — the `checks.sh` change plus a regression (a synthetic replay fixture in the check's exact shape, or the scenario's existing `test/scenario-*.test.ts`), with its own `bun run check`, review and commit — and this task re-runs that scenario with `--only` only after that task is on the branch.
2. **Uncovered tools.** For each tool in `uncoveredTools`, add a synthetic fixture under `test/fixtures/replay-synthetic/tool-<name>/` whose post phase runs that tool in a one-line `command-succeeds` (for example `command-succeeds 'awk "BEGIN{exit 0}"'`, `command-succeeds 'python3 -c "import sys; sys.exit(0)"'`), and pass it with `--synthetic`. Commit the fixtures.
3. **Migrated scenarios not covered by a corpus run.** The two synthetic fixtures already cover `tdd-runs-the-project-suite` and the `codex-approach-gate` shape; if `codex-plan-gate-algorithm-locked-after-round1` or `codex-gate-stale-broker-attributed` is uncovered, add a fixture in its exact migrated shape the same way.
4. **`preDivergencesFromHistory`.** Classify each distinct command shape once, in `README.md`: *state-dependent* (`git-clean`, `git-branch`, `file-exists` on agent-created paths) or *degraded* (a missing artifact). For every degraded shape, add a synthetic counterfactual fixture as in item 2.
5. **`degraded-archive` runs** are listed with their `degradedCheck`; nothing else to do unless a migrated scenario depends on one (item 3).

Re-run until the recorded exit is 0, committing fixtures as they are added — `bun run check` before each of those commits.

- [ ] **Step 3: Record and commit**

`evidence/2026-10-14-agent-write-isolation-relocation/README.md` gets a "Replay" section: the command, the coverage line, the table (link to `replay.md`), the classification of pre divergences, and every decision taken under Step 2 with its reason. Run: `bun run check` — Expected: PASS.

```bash
git add evidence/2026-10-14-agent-write-isolation-relocation test/fixtures/replay-synthetic
git commit -m "test(replay): the corpus replay passes under the new environment; the report and the counterfactual fixtures are retained"
```

---

### Task 12: Documentation and the evidence procedure

**Risk tier:** standard — nine files; each edit is specified, but they are prose in nine places.

**Files:**
- Modify: `CLAUDE.md:19,46-47,125,139`; `README.md:48,203,255,291`; `evidence/README.md:20-33`; `docs/scenario-authoring.md:499-516,606,981`; `docs/coding-agent-care-and-feeding.md` (24 `<run>/home` references); `docs/adding-a-coding-agent.md:80,109`; `docs/superpowers/skills/profiling-run-economics.md:90,101`; `docs/superpowers/reference/porting-harbor-converters.md:385`
- Modify: `docs/manual-testing.md` (one clarifying sentence, below — it is one of the spec's nine).
- Leave: historical `docs/experiments`, `docs/baselines`, `docs/audits`, plans and specs.

- [ ] **Step 1: Define the shorthand once, then apply it**

In `docs/coding-agent-care-and-feeding.md`, immediately after its title, add: `Paths: \`<run>\` is the record directory \`results/<run>/\`; \`<workspace>\` is the agent's tree \`results/workspaces/<run>/\`, which holds \`coding-agent-workdir/\` and \`home/\`.` Then replace every `<run>/home` in that file with `<workspace>/home` (24 occurrences; `grep -c '<run>/home'` must read 0 afterwards and `grep -c '<workspace>/home'` 24).

- [ ] **Step 2: The cited lines, before → after**

- `README.md:48`: `` to a throwaway per-run home at `<run>/home` `` → `` to a throwaway per-run home at `results/workspaces/<run>/home` ``.
- `README.md:255` (the layout block): keep the record lines and add, after the block, a second block headed `results/workspaces/<run>/` with `|-- coding-agent-workdir/   files the Coding-Agent produced` and `|-- home/                   the Coding-Agent's throwaway $HOME`; remove both `|-- coding-agent-workdir/` and `|-- home/` from the record block, so it lists exactly `verdict.json`, `gauntlet-agent/`, `trajectory.json` and `coding-agent-token-usage.json` (the last with `` `-- ``).
- `README.md:291`: `` (`<run>/home`) `` → `` (`results/workspaces/<run>/home`) ``.
- `README.md:203` (the actor table's Coding-Agent row): every `<run>/home/…` → `<run-workspace>/home/…` and `<run>/coding-agent-workdir/` → `<run-workspace>/coding-agent-workdir/`, with the same one-sentence definition of `<run-workspace>` under the table as in `CLAUDE.md:19`.
- `docs/manual-testing.md`, after the "Verdict file" heading's path: add `This is the manual-verdict scheme, separate from quorum's run tree, where the record lives at \`results/<run>/\` and the agent's workspace at \`results/workspaces/<run>/\`.` — the file's `results/<scenario>/codex-app/…` paths are not run directories and do not move.
- `CLAUDE.md:19` (actor table, Coding-Agent row): `` `<run>/home/<agent-config-subdir>/...` `` → `` `<run-workspace>/home/<agent-config-subdir>/...` `` and `` `<run>/coding-agent-workdir/` `` → `` `<run-workspace>/coding-agent-workdir/` ``, with a sentence under the table: `` `<run-workspace>` is `results/workspaces/<run>/`; the record stays at `results/<run>/`. ``
- `CLAUDE.md:46-47`: `` `<runDir>/home/.claude` / `<runDir>/home/.codex` `` → `` `<workspace>/home/.claude` / `<workspace>/home/.codex` (`<workspace>` = `results/workspaces/<run>`) ``.
- `CLAUDE.md:125`: `` under `<run>/home/` `` → `` under `results/workspaces/<run>/home/` ``. `CLAUDE.md:139`: add `, which now live under \`results/workspaces/<run>/\`` after `coding-agent-workdir/`.
- `docs/scenario-authoring.md:606`: `` `coding-agent-workdir/` (the files the agent wrote); `` → `` `workspaces/<run>/coding-agent-workdir/` (the files the agent wrote, beside the record rather than inside it); ``. `:981`: no path change needed (relative `../coding-agent-workdir-existing-worktree` still holds); add `(under results/workspaces/<run>/)` after the first mention.
- `docs/scenario-authoring.md:499-516`: replace the environment table with:

```markdown
`runPhase` builds the child env from one allowlist (`src/checks/env-allowlist.ts`).
There are two layers: the **outer** shell that sources the prelude and
`checks.sh`, and the **inner** shell `command-succeeds` spawns, which may run
code the agent wrote. Checks see:

| Var | Layer | When | Use |
|---|---|---|---|
| `QUORUM_REPO_ROOT` | outer | always | the prelude resolves the dispatchers from it |
| `QUORUM_RECORD_SINK` | outer | always | where records are appended; never reaches an inner command |
| `QUORUM_AGENT_CONFIG_DIR` | outer, inner | always | the Coding-Agent's isolated config dir (bootstrap verbs) |
| `QUORUM_AGENT_HOME` | outer, inner | always | the Coding-Agent's throwaway home; also the inner shell's `HOME` |
| `QUORUM_CODING_AGENT` | outer, inner | always | the coding-agent config name, for per-agent dispatch |
| `QUORUM_TRANSCRIPT_PATH` | outer | **post only** | the captured `trajectory.json` (transcript verbs load it) |
| `QUORUM_RUN_DIR` | outer | pre and post | the record directory (the runner passes it to both phases, `src/runner/index.ts:1159-1167, 1524-1533`; the table's former "post only" did not match production); **outer-only** — expand it with double quotes if an inner command needs a record path. A single-quoted `$QUORUM_RUN_DIR` inside `command-succeeds` is a hard `quorum check` failure |
| `$QUORUM_WORKDIR` | — | **never** | checks run with **cwd = the workdir**; use workdir-relative paths. Referencing it is a hard `quorum check` failure. |

The inner shell runs under the agent's throwaway home (`HOME`, `XDG_*`,
`TMPDIR` from `QUORUM_AGENT_HOME`), not the operator's, and receives no
provider credentials. For the agent's home in a post-check, use
`$QUORUM_AGENT_HOME`; do not guess a relative path up out of the workdir.
```

- `docs/adding-a-coding-agent.md:80,109`: `` `<run>/home` `` → `` `results/workspaces/<run>/home` `` (both lines).
- `docs/superpowers/skills/profiling-run-economics.md:90`: `cd results/<run>/coding-agent-workdir` → `cd results/workspaces/<run>/coding-agent-workdir`; `:101`: add `(under results/workspaces/<run>/)` after `coding-agent-workdir`s.
- `docs/superpowers/reference/porting-harbor-converters.md:385`: `` `results/<run>/home/...` `` → `` `results/workspaces/<run>/home/...` ``.
- `evidence/README.md:20-33`, the four steps:
  1. unchanged;
  2. `Rename \`<workspace>/coding-agent-workdir/.git\` to \`git-dir\`, where \`<workspace>\` is \`results/workspaces/<run>/\` for a relocated run and \`results/<run>/\` itself for a legacy run (the baseline arm of a paired control is legacy). Left alone, the fixture repository commits as a gitlink and its contents are lost.`;
  3. `Stage \`<run>/gauntlet-agent/results/\` and \`<workspace>/home/.claude/\` with \`git add -f\`. The repository's \`results/\` and \`.claude/\` ignore patterns are unanchored, so they match those directories at any depth. A committed copy mirrors that run's live layout: a relocated run's \`<run>/\` beside \`workspaces/<run>/\`; a legacy run's single \`<run>/\`.`;
  4. `Post-check the staged tree across both layouts: every run has at least one transcript and one \`result.json\`, and there are no gitlinks.`

- [ ] **Step 3: Verify the inventory and commit**

Run the spec's full inventory: `rg -n '<run>/home|<run>/coding-agent-workdir|<runDir>/home|results/<' docs README.md CLAUDE.md evidence/README.md | grep -v 'docs/experiments\|docs/baselines\|docs/audits\|docs/superpowers/plans\|docs/superpowers/specs'` — Expected: no `<run>/home`, `<run>/coding-agent-workdir` or `<runDir>/home` line at all, and every remaining `results/<` line names the record tree (`results/<run>/`, `results/<scenario>-…/`, the run lookup at `docs/scenario-authoring.md:541`), Gauntlet's own `results/<runId>` inside `gauntlet-agent/` (`:608`), or the manual-verdict scheme (`docs/manual-testing.md:14,68`). Mechanically: the same pipeline followed by `| grep 'results/<[^ ]*/\(home\|coding-agent-workdir\|\.claude\)'` — Expected: no output. Paste the classified list into the ledger. Run: `sed -n '/^results\/<scenario>-<coding-agent>-<timestamp>-<nonce>\/$/,/^```$/p' README.md | grep -c 'home/\|coding-agent-workdir/'` — Expected: `0` (the record block no longer lists either). Run: `bun run quorum check` and `bun run check` — Expected: PASS.

```bash
git add CLAUDE.md README.md evidence/README.md docs/scenario-authoring.md docs/coding-agent-care-and-feeding.md docs/adding-a-coding-agent.md docs/manual-testing.md docs/superpowers/skills/profiling-run-economics.md docs/superpowers/reference/porting-harbor-converters.md
git commit -m "docs: the run tree is two trees, and checks have an outer and an inner environment"
```

---

### Task 13: The campaign analyzer

**Risk tier:** high — its output is the release decision for the paired control; it must fail closed.

**Files:**
- Create: `evidence/2026-10-14-agent-write-isolation-relocation/tally.py`, `test_tally.py`, `fixtures/baseline-layout/…`, `fixtures/relocated-layout/…`, `fixtures/verdicts/{pass,fail,void-grader-exit,void-harness-setup,qa-agent-misconfigured,stalled-agent}.json` (one `verdict.json` per kind, plus `result.json` for the two readable ones — the launcher's fake quorum copies these, so launcher and analyzer agree by construction)

**Interfaces:**
- Consumes: `evidence/2026-10-03-clean-harness-rebaseline/tally.py` as the starting copy (`readouts`, `counted`, `report`, the Fisher helper).
- Produces: `python3 tally.py --records <root> --workspaces <root> --baseline-logs <dir> --new-logs <dir> --plugin-root <path> --model <id> --cc-version <v> [--scenario cost-api-field-rename-boundary]`, exit codes: 0 proceed; 2 manipulation mismatch (stop); 3 fewer than ten qualifying sessions in an arm after replacements (stop); 4 new-arm failure signature absent from baseline (stop); 5 `p_b - p_n > 2` (human decision). `--baseline-logs` and `--new-logs` are **separate directories**, each holding one arm's logs in the re-baseline's naming — `control-<scenario>-p<n>.log`, `r<n>` for a replacement — which `LOG_NAME` (`tally.py:40`) and `collect()`'s glob (`:314`) already accept; `collect()` runs once per directory, so an arm is never read twice or merged with the other. Public functions: `Config` (a frozen dataclass: `records: Path`, `workspaces: Path`, `plugin_root: str`, `model: str`, `cc_version: str`, `scenario: str` — built once in `main()` from the arguments and threaded through everything that used to read a module global), `classify(verdict, result) -> str` (the one verdict-to-kind classifier, below), `collect(logs: Path, cfg: Config) -> tuple[list[dict[str, Any]], int]` (rows for `cfg.scenario` from one arm's directory, and the count of named runs without a verdict; the re-baseline's `collect` with `cfg` replacing its globals, `tally.py:295-351`), `readouts(cfg, run_id)`, `own_roots(cfg, run_id) -> tuple[str, str]`, `manipulation_failures(row, cfg)`, `failure_signature(verdict) -> tuple[str, str, tuple[str, ...]]`, `decide(baseline_rows, new_rows) -> Decision`. A second CLI form, `python3 tally.py classify <verdict.json> [<result.json>]`, prints `classify`'s kind and exits 0: the launcher (Task 15) calls it so both tools classify identically. `classify`, in order: `error.stage == 'setup'` → `void-harness-setup` (the re-baseline's `void-setup`, `tally.py:84-100`, whose `final_reason` test `quorum error (setup)` is what `compose` writes for that stage, `src/composer.ts:55`); `error.stage == 'qa-agent-misconfigured'` → `qa-agent-misconfigured` (`final_reason` is derived from the stage there too, so the stage is the only field to read); `gauntlet.status == 'investigate'` with `without writing a result` in `gauntlet.summary` → `void-grader-exit` (the re-baseline's `void-grader`); otherwise `criterion_one(result)` — `pass`, `fail` or `indeterminate` — so a stalled or errored agent (`gauntlet.status` `errored`, `final_reason` `Gauntlet-Agent did not complete (status: errored)`) is `indeterminate`: a real trial that counts and is never a pass.

**Mirror:** `evidence/2026-10-03-clean-harness-rebaseline/tally.py:156-182` (readouts), `:353-363` (counted), `:435-446` (main). Keep its docstring style; `ruff` and `mypy` clean.

- [ ] **Step 1: Write the failing tests**

`test_tally.py` (`unittest`), building two fixture trees under `tempfile.mkdtemp()`:
- `baseline-layout`: `records/<run>/{verdict.json, gauntlet-agent/{context/launch-agent, results/g1/result.json}, home/.claude/projects/p/s.jsonl}` where `result.json` carries **three** `criteria` entries each with a `verdict` of `pass` or `fail` (the shape `criterion_one` reads, `tally.py:126-140`: criterion 1 passes when entries `[0]` and `[1]` are both `pass`), a launch record naming `--plugin-dir <plugin-root>` and `--model <id>`, and a transcript whose instruction paths all lie under `/records/<run>/`;
- `relocated-layout`: the same, but the transcript at `workspaces/<run>/home/.claude/projects/p/s.jsonl` and instruction paths under `/workspaces/<run>/`.

Cases:
1. `readouts` finds the transcript in both layouts and `own_roots` classifies the instruction paths as own, so `foreign_instructions == []` in both.
2. criterion 1 is read from `result.json` (`criteria[0]` and `criteria[1]` both passing) — the observable, not the composed final.
3. each of the six manipulation checks — plugin root, model, CLI version, entrypoint, a foreign instruction path, task-tool use — mismatched in turn, in **both** layout fixtures → `manipulation_failures` names it → `decide` returns `stop:'manipulation'` (exit 2); twelve cases.
4. nine qualifying sessions in one arm → `stop:'insufficient'` (exit 3); a `void-grader-exit` row plus a replacement row → ten qualifying (the void does not count, the replacement does); a **fourth** grader-exit void in one arm → `stop:'void-cap'` (exit 3), the cap being three replacements per arm; a `void-harness-setup` row does not consume the cap.
5. **immediate stops:** a new-arm row whose `kind` is `void-harness-setup` or `qa-agent-misconfigured` → `stop:'new-arm-setup'` (exit 2) regardless of counts — the spec's first automatic stop; the same kinds in the **baseline** arm are a relaunch (`void-harness-setup`) or a manipulation-class stop recorded as such, never silently dropped.
6. `failure_signature` of a verdict `{final:'fail', error:null, checks:[{check:'file-exists', passed:false}, …]}` is `('fail','none',('file-exists',))`; signatures are computed over rows whose **`verdict.final != 'pass'`** (verdict-level, not the criterion kind); a new-arm signature `('indeterminate','capture',())` absent from baseline → `stop:'novel-failure'` (exit 4); the same signature present in both arms proceeds.
7. `p_b=5, p_n=4` → proceed (0); `p_b=5, p_n=2` → `stop:'threshold'` (5).
8. `collect(dir, cfg)` over a directory holding `control-cost-api-field-rename-boundary-p1.log` (one `run-id:` line) and a foreign `baseline-p1.log` → one row, from `p1`; the foreign file is ignored. `collect` over the baseline and new directories of the two layout fixtures, with `cfg.records`/`cfg.workspaces` pointing at each fixture tree → every row comes from its own arm's directory, its readouts came from the right layout, and no run id appears in both arms.
9. `classify` on the six `fixtures/verdicts/*` → `pass`, `fail`, `void-grader-exit`, `void-harness-setup`, `qa-agent-misconfigured`, `indeterminate` (the stalled agent) respectively; `python3 tally.py classify <file> [<result.json>]` prints the same six strings (one `subprocess.run` per fixture).

Run: `python3 -m unittest evidence/2026-10-14-agent-write-isolation-relocation/test_tally.py` — Expected: FAIL (module missing).

- [ ] **Step 2: Implement**

Copy `tally.py`. Delete the module globals `ARM`, `ROOT`, `MODEL_ID`, `CC_VERSION`, `EVALS`-relative `run_dir` and the `own = f"/results/{run_id}/"` line; introduce `Config` and pass it explicitly — `run_dir(cfg, run_id) = cfg.records / run_id`, `readouts(cfg, run_id)` globbing `cfg.workspaces/<run>/home/.claude/projects/*/*.jsonl` first and `cfg.records/<run>/…` otherwise, `own_roots(cfg, run_id)`, `manipulation_failures(row, cfg)` comparing against `cfg.plugin_root`, `cfg.model`, `cfg.cc_version`, and `collect(logs, cfg)` for the one scenario `cfg.scenario`. Replace `void_kind` + `final_reading`/`criterion_one` selection with the single `classify(verdict, result)` above (kinds renamed from the re-baseline's `void-setup`/`void-grader` to `void-harness-setup`/`void-grader-exit`; this is the only place a kind string is produced). `main()` parses the arguments into a `Config`, calls `collect` once per arm directory, and replaces the "excluded by manipulation check … provisional" path with the fail-closed `decide()`; the `classify` subcommand is dispatched before argument parsing on `sys.argv[1] == 'classify'`:

```python
def decide(baseline: list[dict[str, Any]], new: list[dict[str, Any]]) -> Decision:
    """Apply the predeclared rule to two arms of qualifying rows.

    :param baseline: Rows of the pre-change arm.
    :param new: Rows of the relocated arm.
    :returns: The decision and its reason; never silently excludes a row.
    """
    for arm, rows in (("baseline", baseline), ("new", new)):
        bad = [(r["run_id"], r["manip"]) for r in rows if r["manip"]]
        if bad:
            return Decision("stop", "manipulation", f"{arm}: {bad}")
        voids = sum(r["kind"] == "void-grader-exit" for r in rows)
        if voids > 3:
            return Decision("stop", "void-cap", f"{arm}: {voids} grader-exit voids, cap 3")
    for r in new:
        if r["kind"] in ("void-harness-setup", "qa-agent-misconfigured"):
            return Decision("stop", "new-arm-setup", r["run_id"])
    qb, qn = qualifying(baseline), qualifying(new)
    if len(qb) != 10 or len(qn) != 10:
        return Decision("stop", "insufficient", f"baseline={len(qb)} new={len(qn)}")
    novel = {failure_signature(r["verdict"]) for r in qn if r["verdict"].get("final") != "pass"} - {
        failure_signature(r["verdict"]) for r in qb if r["verdict"].get("final") != "pass"
    }
    if novel:
        return Decision("stop", "novel-failure", str(sorted(novel)))
    pb, pn = sum(r["kind"] == "pass" for r in qb), sum(r["kind"] == "pass" for r in qn)
    if pb - pn > 2:
        return Decision("stop", "threshold", f"p_b={pb} p_n={pn}")
    return Decision("proceed", "threshold", f"p_b={pb} p_n={pn}")
```

with `qualifying(rows)` = rows whose `kind` is `pass`, `fail` or `indeterminate` (voids and superseded excluded, replacements included) and `main()` mapping `Decision` to the exit codes above and printing the full table either way.

- [ ] **Step 3: Run and commit**

Run: `python3 -m unittest evidence/2026-10-14-agent-write-isolation-relocation/test_tally.py` — Expected: PASS. Run: `ruff check evidence/2026-10-14-agent-write-isolation-relocation/ && mypy evidence/2026-10-14-agent-write-isolation-relocation/tally.py evidence/2026-10-14-agent-write-isolation-relocation/test_tally.py` — Expected: clean. Run: `bun run check` — Expected: PASS (unchanged by this task, but every commit carries it).

```bash
git add evidence/2026-10-14-agent-write-isolation-relocation/tally.py evidence/2026-10-14-agent-write-isolation-relocation/test_tally.py evidence/2026-10-14-agent-write-isolation-relocation/fixtures
git commit -m "test(evidence): a campaign analyzer that reads both layouts, fails closed on a manipulation mismatch, and applies the predeclared rule"
```

---

### Task 14: Three live smokes

**Risk tier:** standard — live runs; the acceptance is predeclared and recorded. This task validates the spec's second Assumption (no CLI inspects the workdir path beyond Antigravity's hidden-component rule) and the inner-home overlay's live behaviour.

**Files:**
- Create: `evidence/2026-10-14-agent-write-isolation-relocation/smokes/run-smoke.sh` (the command of record), `smokes/<agent>/` (verdict, `provenance.json`, the capture's source-log list, `quorum show` output)

- [ ] **Step 1: Run, one at a time, from the worktree**

Write `evidence/2026-10-14-agent-write-isolation-relocation/smokes/run-smoke.sh` (bash, for the same `PIPESTATUS` reason as Task 11's script):

```bash
#!/usr/bin/env bash
# One live smoke of record: `bash <this file> <agent>`.
set -uo pipefail
agent="$1"
here="$(cd "$(dirname "$0")" && pwd -P)"            # evidence/<dir>/smokes
repo="$(cd "$here/../../.." && pwd -P)"              # the worktree
out="$here/$agent"; mkdir -p "$out"
cd "$repo"
bun run quorum run scenarios/00-quorum-smoke-hello-world --coding-agent "$agent" 2>&1 | tee "$out/stdout.txt"
run_rc=${PIPESTATUS[0]}; echo "run exit: $run_rc" | tee -a "$out/stdout.txt"
run_id="$(sed -n 's/^run-id: //p' "$out/stdout.txt" | tail -1)"
bun run quorum show "$run_id" 2>&1 | tee "$out/show.txt"
show_rc=${PIPESTATUS[0]}; echo "show exit: $show_rc" | tee -a "$out/show.txt"
echo "$agent: run exit $run_rc, show exit $show_rc, run-id $run_id"
```

Then, one at a time: `bash evidence/2026-10-14-agent-write-isolation-relocation/smokes/run-smoke.sh claude-auto`, then `codex`, then `antigravity`. Each status is captured on the line after its own pipeline.

- [ ] **Step 2: Acceptance, per smoke**

Each must satisfy all of: `run exit` is 0 or 1 (`quorum run` exits 0 for pass, 1 for fail, 2 for indeterminate — `src/cli/trials.ts:35-40`); `show exit` is 0; `final` is not `indeterminate` with `error.stage` `setup` or `qa-agent-misconfigured`; `verdict.json` sits at `results/<run>/`; the workspace sits at `results/workspaces/<run>/` with the agent's transcript under its `home/`; `trajectory.json` has at least one tool call; for Antigravity, the visible-launch record (if any) names a path under `results/workspaces/`. A smoke that fails stops the work: surface it to your human partner with the verdict and the capture detail; do not re-run into a pass.

- [ ] **Step 3: Record and commit**

Copy `verdict.json`, `provenance.json` and the transcript list per smoke into the evidence directory; add a "Smokes" section to its `README.md` with the three run ids and the installed Claude Code version (`claude --version`). Run: `bun run check` — Expected: PASS.

```bash
git add evidence/2026-10-14-agent-write-isolation-relocation/smokes evidence/2026-10-14-agent-write-isolation-relocation/README.md
git commit -m "test(evidence): three live smokes under the relocated layout"
```

---

### Task 15: The campaign launcher

**Risk tier:** high — it decides which sessions exist and in what order; a launcher that mis-sequences arms, loses an exit status or silently swallows a void makes the control's tally wrong while looking valid.

**Files:**
- Create: `evidence/2026-10-14-agent-write-isolation-relocation/control/launch-all.sh`, `control/fake-quorum.sh` (the test's stand-in for `quorum run`), `control/launch-all.test.sh`

**Interfaces:**
- Consumes: `python3 tally.py classify <verdict.json> [<result.json>]` and `fixtures/verdicts/*` (Task 13).
- Produces: `bash launch-all.sh <campaign-root> <baseline-worktree> <new-worktree>`. Environment: `QUORUM_RUN_CMD` (default `bun run quorum run`; the test sets it to the fake), `TALLY` (default `$here/../tally.py`), `SCENARIO` (default `cost-api-field-rename-boundary`), `OUT_DIR` (default `$here`, the script's own directory; the test points it at a temp directory so no fixture row can ever land beside the campaign's logs). Writes `$OUT_DIR/logs/<arm>/control-<scenario>-<proc>.log` per launch and `$OUT_DIR/manifest.tsv` (`seq	arm	proc	run_id	exit	kind	note`, header first). Exit: 0 when both arms hold ten qualifying rows; 1 on a launch the tally cannot read (no `run-id:` line, unreadable verdict, `classify` failure); 2 on a new-arm immediate stop; 3 when a void cap or the relaunch bound is exceeded. On any stop the last manifest line is `stop	<reason>` and nothing further is launched.

**Mirror:** `scripts/strip-runs.test.sh` (the `PASS:`/`FAIL:` shell-test shape); `evidence/2026-10-03-clean-harness-rebaseline/launch-all.sh:15-24` (argument validation and fail-closed exits — not its concurrency: that campaign ran a manifest in parallel; this one is a sequential, alternating state machine).

- [ ] **Step 1: The fake and the failing test**

`control/fake-quorum.sh`, invoked exactly as `quorum run` would be (`fake-quorum.sh run scenarios/<s> --coding-agent claude-auto --out-root <root>`): reads the next line of `$FAKE_SCRIPT` (a counter file beside it tracks the position), where each line is a kind from `fixtures/verdicts/` or `no-run-id`; mints `run_id="$SCENARIO-claude-auto-$(date -u +%Y%m%dT%H%M%SZ)-$(printf '%04x' "$n")"`, copies `fixtures/verdicts/<kind>.json` to `<root>/<run_id>/verdict.json` and, for `pass`/`fail`, the matching `result.json` to `<root>/<run_id>/gauntlet-agent/results/g1/result.json`; prints `run-id: <run_id>`; exits 0 for `pass`, 1 for `fail`, 2 otherwise (`src/cli/trials.ts:35-40`). `no-run-id` prints nothing and exits 1.

`control/launch-all.test.sh` builds, per case, a temp campaign root, two empty "worktree" directories and a temp `OUT_DIR`; points `QUORUM_RUN_CMD` at the fake and `TALLY` at the real `tally.py`; runs the launcher as `/bin/bash launch-all.sh …`; and asserts, one `PASS:`/`FAIL:` line each (every case also asserts that nothing was written under `control/` itself and that each void row's `kind` column equals the scripted kind — `classify` was called without a `result.json` for it):
1. twenty `pass` lines → exit 0; the manifest's arm column alternates `baseline,new` ten times with procs `p1…p10`; each arm's log directory holds exactly `control-cost-api-field-rename-boundary-p1.log` … `p10.log`; every exit column is `0`.
2. row 3 of the baseline arm `fail` → that manifest row's exit is `1`, kind `fail`; the launcher still exits 0 (a failure is a trial).
3. baseline p2 `void-grader-exit`, then `pass` → the row after it is `baseline r1` (before `new p2`), the launcher exits 0 and each arm ends with ten qualifying rows.
4. four baseline `void-grader-exit` lines → exit 3, last line `stop	void-cap baseline`, and no row follows the fourth void.
5. baseline p1 `void-harness-setup`, then `pass`, then three `void-grader-exit` later in that arm → exit 0: the setup relaunch (`r1`) did not consume the cap.
6. new p1 `void-harness-setup` → exit 2, last line `stop	new-arm-setup <run_id>`, no later rows; likewise for `qa-agent-misconfigured`.
7. a `no-run-id` line → exit 1, last line `stop	no run-id in <log>`.

Run: `bash evidence/2026-10-14-agent-write-isolation-relocation/control/launch-all.test.sh` — Expected: every case FAIL (no launcher).

- [ ] **Step 2: The launcher**

```bash
#!/usr/bin/env bash
# launch-all.sh <campaign-root> <baseline-worktree> <new-worktree>
# Sequential, alternating: B p1, N p1, B p2, N p2, ... Each launch is classified
# by tally.py so the launcher and the analyzer can never disagree on a kind.
# Plain bash 3.2 (macOS /bin/bash is the only bash on this host): per-arm state
# lives in scalar variables addressed by name (${!name} to read, printf -v to
# write, both bash 3.1+), never in associative arrays. Counters are mutated in
# the current shell, never inside $(...), where the change would be lost.
set -uo pipefail
root="$1"; tree_baseline="$2"; tree_new="$3"
here="$(cd "$(dirname "$0")" && pwd -P)"
out="${OUT_DIR:-$here}"                      # manifest.tsv and logs/ go here; tests use a temp dir
tally="${TALLY:-$here/../tally.py}"; scenario="${SCENARIO:-cost-api-field-rename-boundary}"
run_cmd="${QUORUM_RUN_CMD:-bun run quorum run}"
manifest="$out/manifest.tsv"; printf 'seq\tarm\tproc\trun_id\texit\tkind\tnote\n' > "$manifest"
q_baseline=0; q_new=0; gv_baseline=0; gv_new=0; rl_baseline=0; rl_new=0; rn_baseline=0; rn_new=0; seq=0
get() { local v="$1_$2"; printf '%s' "${!v}"; }                           # get <prefix> <arm>
bump() { local v="$1_$2"; printf -v "$v" '%s' "$(( ${!v} + 1 ))"; }        # bump <prefix> <arm>, in this shell
stop() { printf 'stop\t%s\n' "$2" >> "$manifest"; echo "stop: $2" >&2; exit "$1"; }
launch() {  # launch <arm> <proc> <note>
  local arm="$1" proc="$2" note="$3" log rc run_id kind
  mkdir -p "$out/logs/$arm"; log="$out/logs/$arm/control-$scenario-$proc.log"
  (cd "$(get tree "$arm")" && $run_cmd "scenarios/$scenario" --coding-agent claude-auto --out-root "$root") > "$log" 2>&1; rc=$?
  run_id="$(sed -n 's/^run-id: //p' "$log" | tail -1)"
  [ -n "$run_id" ] || stop 1 "no run-id in $log"
  # A void run has no result.json; bash 3.2 would pass an unmatched glob as a
  # literal path, so resolve it first and omit the optional argument when absent.
  res="$(ls "$root/$run_id"/gauntlet-agent/results/*/result.json 2>/dev/null | head -1)"
  if [ -n "$res" ]; then kind="$(python3 "$tally" classify "$root/$run_id/verdict.json" "$res" 2>>"$log")"; else kind="$(python3 "$tally" classify "$root/$run_id/verdict.json" 2>>"$log")"; fi || stop 1 "classify failed for $run_id"
  seq=$((seq + 1)); printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$seq" "$arm" "$proc" "$run_id" "$rc" "$kind" "$note" >> "$manifest"
  case "$arm:$kind" in
    new:void-harness-setup|new:qa-agent-misconfigured) stop 2 "new-arm-setup $run_id" ;;
    baseline:void-harness-setup)
      bump rl "$arm"; [ "$(get rl "$arm")" -le 3 ] || stop 3 "relaunch bound $arm"
      bump rn "$arm"; launch "$arm" "r$(get rn "$arm")" "relaunch of $proc (setup void, cap untouched)" ;;
    *:void-grader-exit)
      bump gv "$arm"; [ "$(get gv "$arm")" -le 3 ] || stop 3 "void-cap $arm"
      bump rn "$arm"; launch "$arm" "r$(get rn "$arm")" "replaces $proc (grader-exit void $(get gv "$arm")/3)" ;;
    *) bump q "$arm" ;;
  esac
}
for i in 1 2 3 4 5 6 7 8 9 10; do launch baseline "p$i" ""; launch new "p$i" ""; done
[ "$(get q baseline)" -eq 10 ] && [ "$(get q new)" -eq 10 ] || stop 3 "qualifying baseline=$(get q baseline) new=$(get q new)"
echo "complete: 10 qualifying per arm; manifest $manifest"
```

(The test invokes the launcher as `/bin/bash launch-all.sh …` explicitly, so it is proven on bash 3.2, the only bash this host has — `bash --version` reports 3.2.57 and `which -a bash` lists `/bin/bash` alone.) `qa-agent-misconfigured` in the **baseline** arm falls through to the qualifying count deliberately: the analyzer's manipulation/signature checks are where it stops, with the row on record.

Run: `bash evidence/2026-10-14-agent-write-isolation-relocation/control/launch-all.test.sh` — Expected: seven `PASS:` lines. Run: `bun run check` — Expected: PASS (unchanged by this task, but every commit carries it).

- [ ] **Step 3: Commit**

```bash
git add evidence/2026-10-14-agent-write-isolation-relocation/control/launch-all.sh evidence/2026-10-14-agent-write-isolation-relocation/control/fake-quorum.sh evidence/2026-10-14-agent-write-isolation-relocation/control/launch-all.test.sh
git commit -m "test(evidence): the paired-control launcher alternates arms, keeps every exit status and applies the void rule, under a fake-quorum test"
```

---

### Task 16: The paired control, and the evidence note

**Risk tier:** high — the release decision.

**Files:**
- Create: `evidence/2026-10-14-agent-write-isolation-relocation/control/{tally.sh, manifest.tsv, logs/baseline/, logs/new/, tally.txt}` (`launch-all.sh` exists from Task 15); extend `README.md`. Every `control/…` path in this task is under `EVIDENCE_DIR=$PWD/evidence/2026-10-14-agent-write-isolation-relocation` (the worktree); the two scripts anchor on their own location and run from anywhere.
- Create: `.worktrees/baseline-b6a923a31` (a second worktree at the pre-change revision, created from the evals checkout)

**Interfaces:**
- Consumes: `tally.py` and its `classify` subcommand (Task 13); `control/launch-all.sh` (Task 15).

- [ ] **Step 1: Pre-register, before any run**

Write `$EVIDENCE_DIR/control/README.md` (or the section in the top-level `README.md`) stating, before launch: scenario `cost-api-field-rename-boundary`; agent `claude-auto`, model `claude-opus-5-5`, Gauntlet-Agent `claude-opus-5-5`; the plugin root both arms use; the installed Claude Code version; the observable (criterion 1, `criteria[0]` and `criteria[1]`); the rule (`p_b - p_n <= 2` proceeds; a larger gap stops for a human decision); the automatic stops; the void rule with its cap of three per arm; `n = 10` per arm; interleaving order `B1 N1 B2 N2 …`.

- [ ] **Step 2: The baseline worktree**

From the evals checkout: `git worktree add .worktrees/baseline-b6a923a31 b6a923a31` (outside the sandbox if `worktree add` is refused inside it); `bun install` there. `quorum run` defaults `--out-root` to `results` **relative to the worktree it runs from**, so a shared tree needs one explicit absolute root. Predeclare `CAMPAIGN_ROOT="$(pwd)/results"` in the evals checkout and pass `--out-root "$CAMPAIGN_ROOT"` to **every** launch in both arms; the baseline arm writes legacy-layout runs and the new arm relocated runs under that one root, and `tally.py --records "$CAMPAIGN_ROOT" --workspaces "$CAMPAIGN_ROOT/workspaces"` reads both. Before the launch, `$EVIDENCE_DIR/control/manifest.tsv` must not exist and `$EVIDENCE_DIR/control/logs/` must be absent or hold no files (`find "$EVIDENCE_DIR/control/logs" -type f 2>/dev/null | wc -l` → `0`): the analyzer globs every `p<n>`/`r<n>` log it finds, so a stale row from anywhere else would enter the tally. Task 15's tests write only to their temp `OUT_DIR`; the launcher creates `logs/<arm>/` itself.

- [ ] **Step 3: Launch, interleaved**

Run the Task 15 launcher once, from the evals checkout, with the baseline worktree and the feature worktree as its two arms: `OUT_DIR="$EVIDENCE_DIR/control" bash "$EVIDENCE_DIR/control/launch-all.sh" "$CAMPAIGN_ROOT" "$EVALS/.worktrees/baseline-b6a923a31" "$EVALS/.worktrees/agent-write-isolation-relocation"` (`EVALS` is the evals checkout's absolute path). It alternates `baseline p1, new p1, baseline p2, …`, writes each row's log to `$EVIDENCE_DIR/control/logs/<arm>/control-cost-api-field-rename-boundary-<proc>.log` and the ordered `manifest.tsv` with every exit status and kind, applies the void rule (grader-exit voids replaced as `r<n>`, three per arm; a baseline setup void relaunched without consuming the cap; a new-arm setup void or `qa-agent-misconfigured` an immediate stop). Its exit status is recorded in the README; a non-zero exit is a **stop** — bring the manifest to your human partner.

- [ ] **Step 4: Tally and decide**

`$EVIDENCE_DIR/control/tally.sh`:

```bash
#!/usr/bin/env bash
# `bash <this file> <campaign-root> <plugin-root> <installed-cc-version>`
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"            # evidence/<dir>/control
campaign_root="$1"; plugin_root="$2"; cc_version="$3"
python3 "$here/../tally.py" --records "$campaign_root" --workspaces "$campaign_root/workspaces" \
  --baseline-logs "$here/logs/baseline" --new-logs "$here/logs/new" \
  --plugin-root "$plugin_root" --model claude-opus-5-5 --cc-version "$cc_version" \
  --scenario cost-api-field-rename-boundary | tee "$here/tally.txt"
rc=${PIPESTATUS[0]}; echo "tally exit: $rc" | tee -a "$here/tally.txt"; exit "$rc"
```

Run: `bash "$EVIDENCE_DIR/control/tally.sh" "$CAMPAIGN_ROOT" <plugin-root> <installed-cc-version>`.

Exit 0 proceeds. Any other exit is a **stop**: bring the table and the reason to your human partner; do not relaunch to change the answer.

- [ ] **Step 5: The evidence note and the archive**

Archive each counted run per `evidence/README.md`'s four steps (Task 12's wording), applying the **legacy** branch of steps 2–3 to the baseline arm's runs (`results/<run>/coding-agent-workdir`, `results/<run>/home`) and the **relocated** branch to the new arm's (`results/workspaces/<run>/…`); the copied tree under `runs/<arm>/` mirrors each run's own layout. Complete `README.md`: replay (Task 11), smokes (Task 14), the control's pre-registration, table, signatures, decision; and the two Assumptions with where each was validated. Run: `bun run check` — Expected: PASS. Commit.

```bash
git add evidence/2026-10-14-agent-write-isolation-relocation
git commit -m "test(evidence): the paired control on cost-api-field-rename-boundary under the predeclared rule"
```

---

## Unknowns and assumptions carried by this plan

- **Assumption:** running inner commands under the agent's throwaway home rather than the operator's does not change the outcome of any shipped check. *Validate via* Task 11 (the corpus replay, both phases, every replayable scenario), before Task 12; a divergence that needs a new allowlist variable is surfaced to your human partner as a spec change, not added silently.
- **Assumption:** no agent CLI inspects the absolute workdir path beyond Antigravity's hidden-component rule. *Validate via* Task 14 (the three smokes), before Task 16.
- **Assumption:** the `evals` worktree's `bun install` needs no network beyond what the host already has cached. *Validate via* the "Before Task 1" baseline; if it fails on the registry, the proxy variables are already in the environment and the failure is reported, not worked around.
