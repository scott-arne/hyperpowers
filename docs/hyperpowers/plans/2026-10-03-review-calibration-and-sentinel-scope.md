# Review Calibration and Sentinel Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-03-review-calibration-and-sentinel-scope-design.md`

**Goal:** Make the evals sentinel re-measure rule and its base-rate table scope-aware and harness-labelled, and cap pathological-input findings at medium in the three Codex code-review focus strings if a direct-Codex fixture measurement shows the cap works.

**Architecture:** Fixes 2 and 3 are documentation: a rewrite of evals `docs/scenario-authoring.md` §5, one offline hermeticity record, and a one-bullet pointer in hyperpowers `CLAUDE.md`. Fix 1 is measured before it ships. An evals runner reviews fixture diffs with real Codex under a control and a treatment focus file. A control arm runs RED-first on a new pathological fixture, then both arms run on five fixtures. Only a win against the pre-registered decision rule puts the sentence into `recipe-code.md` and pins it in the contract test.

**Tech Stack:** Bash, Node (fixtures, focus checks, the codex-plugin-cc broker library), Bun/TypeScript (evals checks), Python 3 (tally), Markdown.

## Global Constraints

- **Repositories.**
  - hyperpowers: worktree `/Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope`, branch `review-calibration-and-sentinel-scope`, cut from `main` at `5bef46c` (v6.15.0). Every bare hyperpowers path in this plan is relative to that worktree.
  - evals: `/Users/johnss51/Development/agents/hyperpowers/evals` on `main` (HEAD `89a4b361e` when this plan was written). It is a separate clone that hyperpowers gitignores, so the worktree has no `evals/` directory. Every path marked "evals:" is relative to that clone, and every command reaches it by absolute path or `git -C`.
- **Evidence directory**, named here before the first review per the repo `CLAUDE.md`: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/`. It holds `cap-sentence.txt`, `focus-control.txt`, `focus-treatment.txt`, `tally.py`, `tally.txt`, `README.md`, `task-4-runs/` and `task-5-runs/`.
- **The cap sentence**, verbatim (spec "Fix 1"): `A defect reachable only through input that nothing in the code or its callers produces and that only the person running it could supply — a newline or invalid UTF-8 in a file or directory name, a name that starts with a dot — is medium, unless it also breaks the default path or corrupts stored data.`
- **The anchor** it follows is `Naming, style, and speculative hardening are low. `, trailing space included. Treatment text is the anchor, then the cap sentence, then one space.
- **Decision rule** (spec "Decision rule"). The treatment wins if all five hold:
  - P blocks in at most 1 of 3;
  - Pc blocks in at least 2 of 3;
  - H blocks in 3 of 3;
  - O blocks in 3 of 3;
  - M is approved in at least 2 of 3.

  "P" means the validated pathological fixture: P, or P2 if P was revised in Task 4. Control's numbers are reported beside the treatment's. A loss on any line means the sentence does not ship as measured, and the result goes back to the human partner.
- **What counts as blocking and approved.** A review blocks when `verdict-normalize` prints `"result":"blocking"`. It is approved when it prints `"result":"approved"`.
- **Void rule (this plan's rule; the spec is silent).**
  - A capture that `verdict-normalize` reports as `"result":"incomplete"` (no parseable verdict, or `needs-attention` with no findings) is an instrument failure, not a trial.
  - So is a runner invocation that exits non-zero with matching runtime records: a review turn that failed, a normalize that failed, or a fixture that would not build. Every fixture named in that invocation without three readings in its `run.log` is voided, including fixtures the runner never reached.
  - A voided fixture's three reviews in that arm are re-run once, one fixture per invocation, into `<arm dir>-rerun-<fixture>/` beside the original. Both directories are kept, and the re-run's three readings replace the voided cell.
  - A second instrument failure (an incomplete or a failed invocation) for the same fixture and arm stops the plan, and the controller reports it to the human partner.
  - An invocation that exits non-zero without writing `runtime-start.txt` was refused by its usage, focus or config check and ran no review. It is neither a trial nor a void: the controller stops and reports it, because an input the preflight checked has changed.
- **Runtime records** (spec "Runtime record").
  - A runner invocation that passes its usage and focus checks writes `runtime-start.txt` before the broker starts and `runtime-end.txt` on every exit after that, so a failed invocation still leaves both. Each record has six lines: the companion version, the codex binary path, the codex version, the Codex config's top-level `model` and `model_reasoning_effort` lines, and the `verdict-normalize` blob id.
  - The runner exits 1 when the two records differ (drift), when a record cannot be written, or when the Codex config does not set `model` and `model_reasoning_effort` exactly once each at the top level.
  - The reference is `task-4-runs/control-P/runtime-start.txt`. Every run directory under `task-4-runs/` and `task-5-runs/` must hold both records, each byte-identical to the reference. That covers re-runs too.
  - An invocation that drifted, or whose records differ from the reference, is re-run in full under the reference configuration into `<arm dir>-runtime-rerun/`. The original directory stays, its readings are not used, and Task 7's README names it as superseded. If the reference configuration cannot be restored, the plan stops and the controller reports it.
- **Pinned evals paths.** No evals change in this plan touches `src`, `scenarios`, `coding-agents`, `package.json` or `bun.lock` (spec "Constraints").
- **Codex runs.**
  - Plugin root: `/Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6`.
  - Runner invocations run one at a time, never two at once.
  - Each is launched with the Bash tool's background option and watched until it exits, never as a bare foreground call.
  - The companion's broker uses a Unix socket, which the Bash sandbox blocks. Per the global sandbox rule, the controller tries one sandboxed launch per session, then runs unsandboxed after it fails on the sandbox.
- **Commits.**
  - Implementers stage and never commit. The controller shows the human partner the complete staged diff, asks with AskUserQuestion ("Commit as shown (Recommended)" first), and then commits.
  - Nothing is pushed.
  - No `Co-Authored-By` line and no attribution of any kind; no emojis.
- **Leak rules.**
  - No committed file may contain the proxy host, the `NO_PROXY` list or the GCP project id. Before every commit, `git -C <repo> diff --cached | /usr/bin/grep -F -e "${HTTPS_PROXY#*://}" -e "$NO_PROXY" -e "$ANTHROPIC_VERTEX_PROJECT_ID"` must print nothing. If it prints anything, stop and ask the human partner.
  - From the Codex config, only the top-level `model` and `model_reasoning_effort` lines may reach the evidence.
- **SDD workspace.**
  - There is one workspace, keyed by the hyperpowers worktree that holds this plan. Every ledger write passes that workspace's absolute path, and every `review-package` call gives its OUTFILE as the fourth argument. Without that, an evals task opens a second workspace.
  - The ledger's first line must be `# SDD ledger — plan: <path>`.
- **Pre-registration.**
  - The controller commits this plan and its spec on the branch before Task 1 ("Before Task 1" below). Task 4's preflight checks that commit and stops if either file has lost or changed a line since.
  - Pre-registered text is never edited afterward. A correction is appended as `**Correction (YYYY-MM-DD).**`.
- **Evidence handling** (evals `evidence/README.md`): copy, never move; never edit an artifact after it is cited.
- **Fixture files** are written from this plan's text. The stray `.claude/` directory in evals `fixtures/codex-focus-arm/H/` is never copied or committed.
- **Evals checks.**
  - Under the Bash sandbox, `bun run check` reports 1293 pass and 2 fail at evals `89a4b361e`. Both failures are EPERM creating a directory under `$HOME`: `test/agent-copilot.test.ts:752` and `test/agent-gemini.test.ts:889`.
  - Unsandboxed, the same HEAD gives 1295 pass, 0 fail. Run it sandboxed first; after those two EPERM failures, re-run unsandboxed.
  - `bun run quorum check` passes sandboxed.
  - Both checks run in every task that changes evals files (Tasks 1, 3 and 7), after that task's files are final and before it stages.

## Grounding

- evals `docs/scenario-authoring.md:605-639`: §5 "A single sentinel failure is a sample", with its three steps, the 8-column base-rate table and the criterion paragraph. Task 1 replaces this range.
- evals `scripts/codex-focus-arm.sh:1-104`: today's runner. It hardcodes fixtures M/H/O, carries the control and treatment texts inline (lines 55-63) and uses one commit message. Its broker is keyed to the evals checkout (`"$here"`, lines 19-39), and it holds the lens skeleton (lines 41-53) and the parse-and-test assertions. Task 3 rewrites it.
- evals `scripts/lens-cohort.test.sh:1-14`: the evals test-script shape. It uses `set -euo pipefail`, takes the hyperpowers root as a positional argument, makes a `mktemp -d` work dir with an EXIT trap, and builds stub inputs with heredocs and `printf`.
- evals `fixtures/codex-focus-arm/H/`: the fixture shape (`REQUIREMENTS.md`, `lib.base.js`, `lib.js`, `test.js`).
- `skills/requesting-code-review/scripts/verdict-normalize:1-17`: the tri-state output and when it reports `incomplete`.
- `skills/requesting-code-review/recipe-code.md:53,71,81`: the three focus strings, each carrying the anchor once.
- `tests/codex-review-gate/test-gate-contract.sh:310-343`: the `full_cal` count and the per-launch block loop that the cap pin mirrors.
- `tests/codex-review-gate/gate-post-split-edits.tsv` rows 20, 22 and 23 (srclines 326, 344 and 354, reason `severity-calibration`). These post-split replacements carry the same three focus strings. `test-gate-split-lossless.sh` rebuilds the gate from them, so they change together with `recipe-code.md`. Row 21 (srcline 330) carries no anchor.
- `docs/hyperpowers/plans/2026-09-23-adoption-remediation.md:1086-1088`: the controller-run task heading. That plan wrote `controller-run` in the tier slot. SDD reads only `low`, `standard` and `high` (`skills/subagent-driven-development/SKILL.md:566`), so Tasks 4, 5 and 7 here declare a rubric tier, put it directly under the heading, and name controller-run in the rationale.
- evals `evidence/README.md:13-18`: evidence layout and copy rules.
- evals `evidence/2026-10-03-harness-confound-attribution/` (`README.md`, `tally.py`, `tally.txt`): an evidence directory with a README and a tally script.
- evals `docs/experiments/2026-10-03-harness-confound-attribution.md`: the experiment-entry shape (Question, Pre-registration, Config, Results, Limits, Files).
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md:48-128`: the Arm A note for the 2026-09-05 direct-Codex method this plan reuses.
- `CHANGELOG.md:5`: the dated release heading. A heading added on a branch is re-dated at release (hyperpowers `3b815d9`).
- Naming: evals scripts are kebab-case `.sh`, mode 100755, with a sibling `.test.sh` (`scripts/lens-cohort.sh`, `scripts/lens-cohort.test.sh`).
- `none`: no existing tally normalizes raw Codex captures. The attribution `tally.py` reads quorum verdicts. This plan's `tally.py` is new.

## Deviations from the spec, recorded before execution

1. **The runner's broker** is keyed to a fresh `mktemp -d` directory, not the evals checkout. The spec says the broker handling "stays as it is", but the spec also requires that the runner never review through, or stop, a broker it did not start. A Claude session's own Codex review run from the evals checkout keeps a broker recorded for that directory until the session ends, so the old key could hand an arm someone else's broker.
2. **The comparability path set.** The spec calls `src`, `coding-agents`, `package.json`, `bun.lock` and the scenario's directory "the path set the 2026-10-03 re-baseline's launcher pins". In fact `logs/measure-launch.sh:31` pins all of `scenarios`. The doc says the launcher's set narrowed to the scenario's own directory.
3. **Dead commit ids in rows 1 and 2.** The rows cite hyperpowers `c6b69d8`, `7e8ba23` and `3c32ee4`, which the 2026-10-01 history rewrite replaced. Task 1 writes the live ids (`62d8044`, `d6a1681`, `7aff2a7`) in the cells and adds a translation note.
4. **P2 is pre-registered.** The spec says P "is revised once" after a failed RED check. Task 3 commits the revision, P2, before any review, so the revision cannot be tuned to P's result. P2 runs only if P fails the RED check.
5. **"The maintainer".** The evals doc uses neither "human partner" nor "maintainer". The regression-row rule there says "the maintainer", matching the evals `CLAUDE.md`'s "trusted-maintainer".
6. **Runtime records.** The spec says "all four records agree", counting two arms. Because the RED arm runs separately, this plan has six or more records, and all must agree. Each record also carries two lines the spec does not list: the path of the `codex` binary, which `--version` alone does not identify, and the `verdict-normalize` blob id, because every reading passes through that script. The end record is written on every exit after the start record, not only on success, so a failed invocation can still be audited.
7. **Files beyond the spec's list.** The spec's "Files" section omits five things this plan touches:
   - hyperpowers `tests/codex-review-gate/gate-post-split-edits.tsv`. Task 6 must edit it: `test-gate-split-lossless.sh` rebuilds the gate from its rows 20, 22 and 23, which carry the same three focus strings.
   - evals `scripts/codex-focus-arm.test.sh`, the runner's sibling test (the evals naming convention under Grounding).
   - evals `fixtures/codex-focus-arm/P2/` (deviation 4).
   - evals `evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt`, the record behind §5's `clean` row (Task 1). It sits beside the evidence it labels, not in this plan's evidence directory.
   - `cap-sentence.txt`, `tally.py`, `tally.txt` and `README.md` in this plan's evidence directory, beside the two focus files the spec names.

---

### Before Task 1: branch and pre-registration (controller)

The controller does this before SDD dispatches Task 1. It is not an SDD task and has no implementer. Until it is done, the spec and this plan are untracked files in the main checkout.

- [ ] **Step 1: Create the worktree**

Use hyperpowers:using-git-worktrees, with this path, branch and base:

```bash
git -C /Users/johnss51/Development/agents/hyperpowers worktree add -b review-calibration-and-sentinel-scope /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope 5bef46c
```

- [ ] **Step 2: Move the spec and the plan into it**

```bash
mv /Users/johnss51/Development/agents/hyperpowers/docs/hyperpowers/specs/2026-10-03-review-calibration-and-sentinel-scope-design.md /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope/docs/hyperpowers/specs/
mv /Users/johnss51/Development/agents/hyperpowers/docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope/docs/hyperpowers/plans/
```

- [ ] **Step 3: Record the approval in the spec**

In the spec, replace the three status lines (`**Status:** approved design (three sections, approved in chat 2026-10-03),` through `fixes are not re-reviewed by Codex. Awaiting user review.`) with:

```markdown
**Status:** approved by the human partner on 2026-10-03, after the three
design sections were approved in chat the same day and the spec was
self-reviewed. The Codex spec gate ran its four-round backstop; the round-4
fixes are not re-reviewed by Codex.
```

- [ ] **Step 4: Scan, show the diff, and commit**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope add docs/hyperpowers/specs/2026-10-03-review-calibration-and-sentinel-scope-design.md docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope diff --cached | /usr/bin/grep -F -e "${HTTPS_PROXY#*://}" -e "$NO_PROXY" -e "$ANTHROPIC_VERTEX_PROJECT_ID"; echo "grep exit $?"
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope diff --cached --stat
```

Expected: `grep exit 1`, and the stat lists exactly the two files. Show the human partner the complete staged diff and ask with AskUserQuestion ("Commit as shown (Recommended)" first). After approval, commit with the message `docs(hyperpowers): pre-register the review-calibration and sentinel-scope spec and plan`. That commit is the pre-registration: Task 4's preflight finds it as the commit that added this plan.

---

### Task 1: Rewrite evals §5 for scoped re-measurement and a harness-labelled base-rate table

**Risk tier:** standard — behavior-shaping doc surgery on the rule that decides whether a release is held, plus an offline test record.

**Repository:** evals

**Files:**
- Modify: evals `docs/scenario-authoring.md:605-639`
- Create: evals `evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the §5 headings "#### What a session reaches", "#### Harness labels" and "#### Which row is the base rate". Task 2's `CLAUDE.md` bullet points at §5.

**Mirror:** evals `docs/scenario-authoring.md:605-639`. Keep its voice, its numbered steps and its table style.

- [ ] **Step 1: Record the hermeticity tests at `be020f0d0`**

The table's new row is labelled `clean` on the strength of these tests passing at its commit (spec "Fix 3", rule 2). Run them in a scratch extract, so the checkout stays untouched. The checkout's `node_modules` stands in for `be020f0d0`'s only while `package.json` and `bun.lock` are unchanged since then, so the block checks that first. Run it as one Bash call; it writes the record and removes its scratch:

```bash
evals=/Users/johnss51/Development/agents/hyperpowers/evals
out="$evals/evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/hermeticity.XXXXXX")"
if git -C "$evals" diff --quiet be020f0d0 HEAD -- package.json bun.lock; then
  git -C "$evals" archive be020f0d0 | tar -x -C "$scratch"
  ln -s "$evals/node_modules" "$scratch/node_modules"
  (cd "$scratch" && bun test test/agent-claude.test.ts test/runner-context.test.ts) > "$scratch.out" 2>&1
  rc=$?
  {
    echo "# Hermeticity tests at evals be020f0d0, run $(date +%F) for the base-rate table's clean row (docs/scenario-authoring.md §5)."
    echo "# Method: git archive be020f0d0 into a scratch directory; node_modules linked from the evals checkout at $(git -C "$evals" rev-parse --short=9 HEAD), where package.json and bun.lock are identical to be020f0d0."
    echo "# Command: bun test test/agent-claude.test.ts test/runner-context.test.ts (bun $(bun --version))"
    cat "$scratch.out"
    echo "# Result: exit $rc"
  } > "$out"
  tail -6 "$out"
else
  echo "package.json or bun.lock differs from be020f0d0: stop and report"
fi
rm -rf "$scratch" "$scratch.out"
```

Expected tail (bun 1.4.2): ` 39 pass`, ` 0 fail`, ` 186 expect() calls`, `Ran 39 tests across 2 files.` and `# Result: exit 0`. Any other result, or the "differs" line, stops the task: report it to the controller and do not write §5's `clean` row. The block works under the Bash sandbox.

- [ ] **Step 2: Replace §5 lines 605-639**

Replace from the line `### A single sentinel failure is a sample` through the line `rate is re-measured under the amended criterion.` (line 639) with exactly this text. The `---` and `## 6. Worked examples` that follow stay.

````markdown
### A single sentinel failure is a sample

A sentinel scenario that fails once in a batch is one draw from that
scenario's failure rate at that head, not evidence that the head changed
the rate. Before recording a regression:

1. Look up the most recently measured base-rate row in the table below that
   is comparable with the failing run (see "Which row is the base rate").
2. If none is recorded (no row is comparable with the failing run), or the
   head under test differs from the head the base rate was measured at in
   something a session of this scenario loads or runs before its reading is
   settled (see "What a session reaches"), run the scenario twenty times at
   the head under test
   (`bun run quorum run scenarios/<id> --coding-agent <agent> --repeat 20`)
   and add the rate to the table with the head, the evals commit, the model,
   the Claude Code version, the listing budget, the harness state and its n.
3. Call it a regression only when the twenty-run rate's 95% Wilson lower
   bound exceeds the recorded base rate's 95% Wilson upper bound.

A single failure at a scenario whose recorded base rate is 5% or higher
never holds a release by itself.

| scenario | model | Claude Code | skills tree | evals | budget | criterion | harness | rate (95% Wilson) | evidence |
|---|---|---|---|---|---|---|---|---|---|
| `cost-checkbox-over-trigger` | `claude-opus-5` | 2.1.261 | hyperpowers `62d8044` (skills identical to `d6a1681`) | `b234bbc12` | default | pre-amendment: skill invocation only | leak-era | 2/20 = 10% (3-30%) | `evidence/2026-09-16-over-trigger-measurement/` |
| `cost-checkbox-over-trigger` | `claude-opus-5` | 2.1.280 | hyperpowers `7aff2a7` (skills tree `2d9f29e`) | `eead16855` | default | amended: skill invocation, or a stated consequence or go-ahead request before the edit | leak-era | 0/20 = 0% (0-16%) | `evidence/2026-09-23-adoption-remediation/` |
| `cost-checkbox-over-trigger` | `claude-opus-5-5` | 2.1.287 | hyperpowers `5bef46c` (v6.15.0) | `be020f0d0` | default | amended | clean | 0/10 = 0% (0-28%) | `evidence/2026-10-03-harness-confound-attribution/` (arm A) |

Every row records the criterion its rate was measured under, its evals
commit, its harness label and its n, and a row added later must record its
own. Step 2's twenty is the size of a new measurement at the head under
test; a recorded row may be shorter when it states its n. The third row is
n=10, so its upper bound is 28%, against 16% for 0 of 20: step 3 needs more
failures in a twenty-run measurement before it calls a regression against
it. Ten more runs at `5bef46c` on the clean harness would close the gap.

Rows 1 and 2 were first recorded with commit ids from before the 2026-10-01
history rewrite: hyperpowers `c6b69d8`, `7e8ba23` and `3c32ee4` are now
`62d8044`, `d6a1681` and `7aff2a7`, and evals `94570f1` is now `eead16855`.
The maps are `evidence/history-rewrite-2026-10-01.tsv` here and
`docs/hyperpowers/history-rewrite-2026-10-01.tsv` in hyperpowers.

`cost-checkbox-over-trigger`'s second acceptance criterion was later
broadened to count a go-ahead request or a stated consequence before the
edit as well as the skill invocation, so a rate measured under the amended
criterion can only be greater than or equal to the rate the same sessions
would produce under the pre-amendment one. Step 3 run against the
pre-amendment rate above is therefore biased toward declaring a
regression, and a regression call against it is not sound until that base
rate is re-measured under the amended criterion.

#### What a session reaches

Step 2 asks whether the head under test changed something a session of the
scenario loads or runs before its reading is settled.

- **The skill listing reaches every session.** A change to any skill's
  frontmatter description counts.
- **A skill body or supporting file reaches only the sessions that read
  it.** A file a session reads only after its reading is settled does not
  count. For an over-trigger scenario, a body read after the invocation that
  already fails the session is an example.
- **A hook branch reaches a session only on events that session fires.** A
  branch that runs only on compaction does not reach a scenario that never
  compacts. A changed line outside such a branch counts as reached, whatever
  its effect: a file write or a spawned process counts as much as output.
- **The argument is recorded with the result.**
  - For a hook, two parts, both required:
    - Control flow. Every line that differs between the two heads lies
      inside a branch whose condition the scenario's events cannot satisfy.
      The record cites the condition's line and the events the base-rate
      transcripts show the scenario firing.
    - Output, as a check on the control-flow part. The hook's output on the
      scenario's event payload is byte-identical at both heads. The worked
      example is the 2026-10-03 re-baseline's `session-start` check: a
      `startup` payload gave 3484 bytes, sha256 prefix `9eb3db442469`, at
      both roots (`evidence/2026-10-03-clean-harness-rebaseline/README.md`).

    Identical output alone is not the argument: a changed branch can run and
    still print the same bytes.
  - For a skill body: the base-rate transcripts showing it was not read
    before the reading settled.
  - An argument without that evidence is not made, and the scenario is
    re-measured.

#### Harness labels

Each row's `harness` label is assigned by the first of these rules that
applies:

1. `leak-era`: the archived transcripts show either leak. That means a
   session loaded `CLAUDE.md` or `AGENTS.md` text from outside the run
   directory, or carries a mark of the operator's Claude environment (an
   entrypoint other than `cli`, or `TaskCreate` among the deferred tools
   offered).
2. `clean`: the row was measured at evals `be020f0d0` or a later commit,
   and at that commit the hermeticity tests pass. Those tests landed with
   `74d248245`, `fc42537c5` and `be020f0d0` in `test/agent-claude.test.ts`
   and `test/runner-context.test.ts`. They pin that the launcher drops every
   inherited `CLAUDE*` and `ANTHROPIC*` variable and that the `CLAUDE.md`
   and `AGENTS.md` excludes are in place. The row's evidence records the
   test run. For a row added after its measurement, the tests are run at
   its commit when the row is added (an offline `bun test`, not a live run).
3. `unknown`: every other row. Before `be020f0d0`, the operator's
   environment carried variables that leave no mark in a transcript, such
   as other session variables and the model alias pins. So a transcript can
   show a leak but cannot prove its absence.

The tests run at a row's commit without touching the checkout. When
`package.json` and `bun.lock` are unchanged since that commit, the
checkout's `node_modules` serves:

```bash
git diff --quiet <commit> HEAD -- package.json bun.lock
scratch="$(mktemp -d)"
git archive <commit> | tar -x -C "$scratch"
ln -s "$PWD/node_modules" "$scratch/node_modules"
(cd "$scratch" && bun test test/agent-claude.test.ts test/runner-context.test.ts)
```

Rows 1 and 2 are `leak-era`: every one of their twenty sessions carries the
`sdk-ts` entrypoint, and row 2's sessions also loaded three `CLAUDE.md`
files from outside the run directory. Row 3 is `clean`: its ten sessions
carry the `cli` entrypoint, load no instruction file and are offered no
`TaskCreate`, and the hermeticity tests pass at `be020f0d0`
(`evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt`).
The marks are read from each session's main transcript: its `entrypoint`
field, its `instructions` attachments and its `deferred_tools_delta`
attachments.

#### Which row is the base rate

Step 1 takes the most recently measured base-rate row that is comparable
with the failing run.

- **Regression rows.** A measurement against which step 3 called a
  regression is added with the call recorded. It is not a base-rate row
  until the maintainer accepts the moved rate, which is recorded in the
  row. That way a regression cannot become the baseline that hides it on
  later heads.
- **Comparability.** A row and a failing run are comparable, under step 1
  and step 3 alike, when they share all of these:
  - the criterion;
  - a `clean` harness label. `leak-era` and `unknown` rows stay in the
    table as history and are never a base rate: neither label identifies
    one environment;
  - the model;
  - the listing budget;
  - the evals harness. `src`, `coding-agents`, `package.json`, `bun.lock`
    and the scenario's directory are identical at the row's evals commit
    and the failing run's
    (`git diff --quiet <row> <run> -- src coding-agents package.json bun.lock scenarios/<id>`).
    That is the 2026-10-03 re-baseline launcher's path set, narrowed from
    all of `scenarios` to the scenario's own directory. Alternatively, each
    difference carries a recorded argument, in the form of "What a session
    reaches", that it cannot change the launch, the skill listing, the
    transcript, the grading or the criterion.
- **The Claude Code version** is recorded but is not part of the match. A
  regression call against a row at another version names the version as a
  second difference: the call says the rate moved between the two
  measurements, not that the head moved it.
- **No comparable row.** Step 2's "none is recorded" applies.
````

- [ ] **Step 3: Re-derive the labels and the row commits from the evidence**

The doc's claims about the rows must reproduce, for all three marks that rule 1 names. For every archived run, this reads the session's main transcript and reports its entrypoint, whether a `deferred_tools_delta` attachment offers `TaskCreate`, and the paths of every instruction file loaded (the run directory shown as `<run>`):

```bash
python3 - <<'EOF'
import collections, json, pathlib
ev = pathlib.Path("/Users/johnss51/Development/agents/hyperpowers/evals/evidence")
rows = ["2026-09-16-over-trigger-measurement/runs-cost-checkbox-over-trigger/as-is",
        "2026-09-23-adoption-remediation/task-11-runs/cost-checkbox-over-trigger/treatment",
        "2026-10-03-harness-confound-attribution/runs/a-clean-6150"]
for d in rows:
    seen = collections.Counter()
    for run in sorted(p for p in (ev / d).iterdir() if p.is_dir()):
        main = sorted((run / "home/.claude/projects").glob("*/*.jsonl"))[0]
        entry, tasks, inst = set(), False, set()
        for line in main.read_text(encoding="utf-8").splitlines():
            e = json.loads(line)
            if e.get("entrypoint"):
                entry.add(e["entrypoint"])
            a = e.get("attachment") or {}
            if a.get("type") == "deferred_tools_delta" and "TaskCreate" in (a.get("addedNames") or []):
                tasks = True
            if a.get("type") == "instructions":
                inst.update(f["path"].replace(str(run), "<run>") for f in a.get("files") or [])
        seen[(",".join(sorted(entry)), tasks, ",".join(sorted(inst)) or "none")] += 1
    for (entry, tasks, inst), n in sorted(seen.items()):
        print(f"{n} entrypoint={entry} TaskCreate={tasks} instructions={inst}")
    print(f"^ {d}")
EOF
```

Expected, one line per row and nothing else:
- `20 entrypoint=sdk-ts TaskCreate=False instructions=none`
- `20 entrypoint=sdk-ts TaskCreate=False instructions=/Users/johnss51/.claude/CLAUDE.md,/Users/johnss51/Development/agents/hyperpowers/CLAUDE.md,/Users/johnss51/Development/agents/hyperpowers/evals/CLAUDE.md`
- `10 entrypoint=cli TaskCreate=False instructions=none`

A second line for any row, or a different row 3 line, means the doc's row sentence does not hold: stop and report it to the controller.

```bash
for c in 62d8044 d6a1681 7aff2a7; do git -C /Users/johnss51/Development/agents/hyperpowers cat-file -t "$c"; done
for c in b234bbc12 eead16855 be020f0d0; do git -C /Users/johnss51/Development/agents/hyperpowers/evals merge-base --is-ancestor "$c" HEAD && echo "$c on main"; done
/usr/bin/grep -E '^(c6b69d8|7e8ba23|3c32ee4)' /Users/johnss51/Development/agents/hyperpowers/docs/hyperpowers/history-rewrite-2026-10-01.tsv | cut -c1-49
```

Expected: `commit` three times; `b234bbc12 on main`, `eead16855 on main`, `be020f0d0 on main`. The map lines pair `c6b69d8…` with `62d8044…`, `7e8ba23…` with `d6a1681…`, and `3c32ee4…` with `7aff2a7…`.

- [ ] **Step 4: Check the table shape**

The doc holds other tables, so the check starts at the base-rate table's header and reads it plus the next four lines (separator and three rows):

```bash
python3 -c '
import sys
lines = open("/Users/johnss51/Development/agents/hyperpowers/evals/docs/scenario-authoring.md", encoding="utf-8").read().split("\n")
heads = [i for i, l in enumerate(lines) if l.startswith("| scenario | model |")]
if len(heads) != 1:
    sys.exit(f"expected one base-rate header, found {len(heads)}")
table = lines[heads[0]:heads[0] + 5]
cells = [l.count("---") if l.startswith("|---") else len(l.strip("|").split(" | ")) for l in table]
print(cells)
ok = cells == [10, 10, 10, 10, 10] and all(l.startswith("| `cost-checkbox-over-trigger`") for l in table[2:])
nxt = lines[heads[0] + 5] if len(lines) > heads[0] + 5 else ""
sys.exit(0 if ok and not nxt.startswith("|") else 1)
'
```

Expected: `[10, 10, 10, 10, 10]`, exit 0. The exit is 1 if any row is missing, has a different cell count, or a fourth row follows.

- [ ] **Step 5: Run the evals checks**

```bash
cd /Users/johnss51/Development/agents/hyperpowers/evals && bun run check
cd /Users/johnss51/Development/agents/hyperpowers/evals && bun run quorum check
```

Expected: `bun run check` gives 1295 pass, 0 fail unsandboxed (sandboxed: 1293 pass and the two EPERM failures named in Global Constraints). `bun run quorum check` exits 0.

- [ ] **Step 6: Confirm the pinned paths are untouched and scan for leaks**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals status --short
git -C /Users/johnss51/Development/agents/hyperpowers/evals diff | /usr/bin/grep -F -e "${HTTPS_PROXY#*://}" -e "$NO_PROXY" -e "$ANTHROPIC_VERTEX_PROJECT_ID"; echo "grep exit $?"
```

Expected: status lists only ` M docs/scenario-authoring.md` and `?? evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt`. Leak grep: `grep exit 1`. Run the leak grep over the new file too: `/usr/bin/grep -F -e "${HTTPS_PROXY#*://}" -e "$NO_PROXY" -e "$ANTHROPIC_VERTEX_PROJECT_ID" <that file>` must also exit 1.

- [ ] **Step 7: Stage (the controller commits)**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals add docs/scenario-authoring.md evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt
```

Commit message the controller uses after approval: `docs(scenario-authoring): re-measure only what a sentinel session reaches; label base-rate rows by harness`.

---

### Task 2: Point hyperpowers contributors at the scoped sentinel rule

**Risk tier:** low — a single-file transcription of one bullet whose complete text is in this plan.

**Repository:** hyperpowers

**Files:**
- Modify: `CLAUDE.md:56` (append one bullet after it)

**Interfaces:**
- Consumes: Task 1's §5 (the pointer's target).
- Produces: nothing other tasks use.

- [ ] **Step 1: Append the bullet**

In `CLAUDE.md`, the "Skill Changes Require Evaluation" list ends at line 56 with `- Do not modify carefully-tuned content (Red Flags tables, rationalization lists, "human partner" language) without evidence the change is an improvement.` Insert this line directly after it, before the blank line:

```markdown
- A single sentinel failure is a sample. A re-measure is owed only for a change a sentinel session reaches; follow `evals/docs/scenario-authoring.md` §5 before holding a release on one.
```

- [ ] **Step 2: Verify**

```bash
/usr/bin/grep -n -A6 '^## Skill Changes Require Evaluation' CLAUDE.md
git diff --stat
```

Expected: the new bullet is the fifth bullet, directly before the blank line that precedes `## Eval harness`. The diff stat shows `CLAUDE.md | 1 +`.

- [ ] **Step 3: Stage (the controller commits)**

```bash
git add CLAUDE.md
```

Commit message: `docs(claude-md): a single sentinel failure is a sample; point at the evals re-measure rule`.

---

### Task 3: Parameterize the focus-arm runner, add fixtures P, Pc and P2, and write the focus files

**Risk tier:** high — the ship decision for Fix 1 trusts this runner's captures, and the runner starts and shuts down a Codex broker process.

**Repository:** evals

**Files:**
- Modify: evals `scripts/codex-focus-arm.sh` (full rewrite)
- Create: evals `scripts/codex-focus-arm.test.sh` (mode 100755)
- Create: evals `fixtures/codex-focus-arm/P/{REQUIREMENTS.md,lib.base.js,lib.js,test.js}`
- Create: evals `fixtures/codex-focus-arm/Pc/{REQUIREMENTS.md,lib.base.js,lib.js,test.js}`
- Create: evals `fixtures/codex-focus-arm/P2/{REQUIREMENTS.md,lib.base.js,lib.js,test.js}`
- Create: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/{cap-sentence.txt,focus-control.txt,focus-treatment.txt}`

**Interfaces:**
- Consumes: hyperpowers `5bef46c:skills/requesting-code-review/recipe-code.md` line 53, and `skills/requesting-code-review/scripts/verdict-normalize` from the hyperpowers root passed as argument 1.
- Produces:
  - Command: `scripts/codex-focus-arm.sh <hyperpowers-root> <codex-plugin-root> <focus-dir> <control|treatment> <out-dir> <fixture>...`, where each fixture is one of `M H O P P2 Pc`.
  - Exit status: 0 on success. 1 for a focus-check failure, a Codex config without exactly one top-level `model` and one `model_reasoning_effort` line, a runtime record that cannot be written, a refused broker, a fixture that fails to parse or test, or runtime drift. 2 for a bad arm, no fixtures, or an unknown fixture. A review turn that fails exits with the companion's own status, after the broker is released and the end record written.
  - Files in `<out-dir>`: `<fx>-<arm>-<i>.json` (the companion's stdout) and `<fx>-<arm>-<i>.json.err` (its stderr) for i in 1..3, plus `broker.txt` and the six-line `runtime-start.txt` and `runtime-end.txt` (Global Constraints, "Runtime records"). An invocation stopped by its usage, focus or config checks writes no runtime record.
  - Stdout: one line per review, `<fx> <arm> <i> ` followed by `verdict-normalize`'s JSON.
  - Focus files that Tasks 4 and 5 pass as `<focus-dir>`.

**Mirror:** evals `scripts/lens-cohort.test.sh:1-14` for the test's shape. The runner keeps today's `scripts/codex-focus-arm.sh` lens skeleton (lines 41-53) and its per-fixture loop.

- [ ] **Step 1: Write fixture P**

The defect fires only on a workspace name the library never creates. A name containing a newline makes `countWorkspaces` miscount, and the report lines become ambiguous. Nothing is stored.

`fixtures/codex-focus-arm/P/REQUIREMENTS.md`:

```markdown
# Task: report and count workspaces

Add `formatWorkspaces(root)` to the exports. It returns one line per workspace
directory under `root`, in `listWorkspaces` order, each line the directory name
followed by a newline; `""` when `root` does not exist.

Add `countWorkspaces(root)` to the exports. It returns the number of workspace
directories under `root`; `0` when `root` does not exist.

Workspace directories are created only by `createWorkspace`, which names them
with twelve lowercase hex digits. Existing behaviour must not change. Tests for
the new functions are not part of this task.
```

`fixtures/codex-focus-arm/P/lib.base.js`:

```javascript
"use strict";
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

// Workspace directories are created only here, named with the first twelve
// hex digits of the sha256 of the plan path.
function createWorkspace(root, planPath) {
  const name = crypto.createHash("sha256").update(planPath).digest("hex").slice(0, 12);
  const dir = path.join(root, name);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// Names of the workspace directories under root, sorted; [] when root is absent.
function listWorkspaces(root) {
  if (!fs.existsSync(root)) return [];
  return fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

module.exports = { createWorkspace, listWorkspaces };
```

`fixtures/codex-focus-arm/P/lib.js`:

```javascript
"use strict";
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

// Workspace directories are created only here, named with the first twelve
// hex digits of the sha256 of the plan path.
function createWorkspace(root, planPath) {
  const name = crypto.createHash("sha256").update(planPath).digest("hex").slice(0, 12);
  const dir = path.join(root, name);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// Names of the workspace directories under root, sorted; [] when root is absent.
function listWorkspaces(root) {
  if (!fs.existsSync(root)) return [];
  return fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

// The workspace report: one name per line, in listWorkspaces order.
function formatWorkspaces(root) {
  return listWorkspaces(root)
    .map((name) => `${name}\n`)
    .join("");
}

function countWorkspaces(root) {
  return formatWorkspaces(root)
    .split("\n")
    .filter((line) => line !== "").length;
}

module.exports = { createWorkspace, listWorkspaces, formatWorkspaces, countWorkspaces };
```

`fixtures/codex-focus-arm/P/test.js`:

```javascript
"use strict";
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createWorkspace, listWorkspaces } = require("./lib.js");

const root = fs.mkdtempSync(path.join(os.tmpdir(), "ws-"));
assert.deepStrictEqual(listWorkspaces(path.join(root, "absent")), []);
const dir = createWorkspace(root, "/plans/a.md");
assert.match(path.basename(dir), /^[0-9a-f]{12}$/);
assert.strictEqual(createWorkspace(root, "/plans/a.md"), dir);
createWorkspace(root, "/plans/b.md");
assert.strictEqual(listWorkspaces(root).length, 2);
fs.rmSync(root, { recursive: true, force: true });
console.log("ok");
```

- [ ] **Step 2: Write fixture Pc**

This is the same kind of input, but here a name containing a newline corrupts the appended `events.log`, so later reads misattribute events. The "corrupts stored data" exception keeps it blocking.

`fixtures/codex-focus-arm/Pc/REQUIREMENTS.md`:

```markdown
# Task: mark every workspace paused or resumed

Add `markAll(root, kind)` to the exports. `kind` is `"paused"` or `"resumed"`;
any other value throws. It appends one event per workspace directory under
`root` to `<root>/events.log`, in the format `eventsFor` reads, and returns the
number of events appended. When `root` does not exist or holds no workspace
directories, it appends nothing and returns `0`.

Workspace directories are created only by `createWorkspace`, which names them
with twelve lowercase hex digits. Existing behaviour must not change. Tests for
the new function are not part of this task.
```

`fixtures/codex-focus-arm/Pc/lib.base.js`:

```javascript
"use strict";
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

// Workspace directories are created only here, named with the first twelve
// hex digits of the sha256 of the plan path.
function createWorkspace(root, planPath) {
  const name = crypto.createHash("sha256").update(planPath).digest("hex").slice(0, 12);
  const dir = path.join(root, name);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// Names of the workspace directories under root, sorted; [] when root is absent.
function listWorkspaces(root) {
  if (!fs.existsSync(root)) return [];
  return fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

// events.log holds one "<workspace name>\t<kind>" line per recorded event.
function eventsFor(root, name) {
  const file = path.join(root, "events.log");
  if (!fs.existsSync(file)) return [];
  return fs
    .readFileSync(file, "utf8")
    .split("\n")
    .filter((line) => line !== "")
    .map((line) => line.split("\t"))
    .filter(([workspace]) => workspace === name)
    .map(([, kind]) => kind);
}

module.exports = { createWorkspace, listWorkspaces, eventsFor };
```

`fixtures/codex-focus-arm/Pc/lib.js`:

```javascript
"use strict";
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

// Workspace directories are created only here, named with the first twelve
// hex digits of the sha256 of the plan path.
function createWorkspace(root, planPath) {
  const name = crypto.createHash("sha256").update(planPath).digest("hex").slice(0, 12);
  const dir = path.join(root, name);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// Names of the workspace directories under root, sorted; [] when root is absent.
function listWorkspaces(root) {
  if (!fs.existsSync(root)) return [];
  return fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

// events.log holds one "<workspace name>\t<kind>" line per recorded event.
function eventsFor(root, name) {
  const file = path.join(root, "events.log");
  if (!fs.existsSync(file)) return [];
  return fs
    .readFileSync(file, "utf8")
    .split("\n")
    .filter((line) => line !== "")
    .map((line) => line.split("\t"))
    .filter(([workspace]) => workspace === name)
    .map(([, kind]) => kind);
}

const KINDS = new Set(["paused", "resumed"]);

// Appends one `kind` event for every workspace directory under root.
function markAll(root, kind) {
  if (!KINDS.has(kind)) throw new Error(`unknown event kind: ${kind}`);
  const names = listWorkspaces(root);
  if (names.length === 0) return 0;
  fs.appendFileSync(
    path.join(root, "events.log"),
    names.map((name) => `${name}\t${kind}\n`).join(""),
  );
  return names.length;
}

module.exports = { createWorkspace, listWorkspaces, eventsFor, markAll };
```

`fixtures/codex-focus-arm/Pc/test.js`:

```javascript
"use strict";
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createWorkspace, listWorkspaces, eventsFor } = require("./lib.js");

const root = fs.mkdtempSync(path.join(os.tmpdir(), "ws-"));
assert.deepStrictEqual(listWorkspaces(path.join(root, "absent")), []);
const name = path.basename(createWorkspace(root, "/plans/a.md"));
assert.match(name, /^[0-9a-f]{12}$/);
assert.deepStrictEqual(eventsFor(root, name), []);
fs.writeFileSync(path.join(root, "events.log"), `${name}\tpaused\nffffffffffff\tresumed\n${name}\tresumed\n`);
assert.deepStrictEqual(eventsFor(root, name), ["paused", "resumed"]);
fs.rmSync(root, { recursive: true, force: true });
console.log("ok");
```

- [ ] **Step 3: Write fixture P2, the pre-registered revision of P**

P2 runs only if control fails to block P in at least 2 of 3 (Task 4). The defect is the same kind of hand-made-name hazard, but it is a crash: a name that does not match the twelve-hex pattern makes `match()` return `null`.

Copy P's base and test byte-for-byte:

```bash
mkdir -p /Users/johnss51/Development/agents/hyperpowers/evals/fixtures/codex-focus-arm/P2
cp /Users/johnss51/Development/agents/hyperpowers/evals/fixtures/codex-focus-arm/P/lib.base.js /Users/johnss51/Development/agents/hyperpowers/evals/fixtures/codex-focus-arm/P2/lib.base.js
cp /Users/johnss51/Development/agents/hyperpowers/evals/fixtures/codex-focus-arm/P/test.js /Users/johnss51/Development/agents/hyperpowers/evals/fixtures/codex-focus-arm/P2/test.js
```

`fixtures/codex-focus-arm/P2/REQUIREMENTS.md`:

```markdown
# Task: report and count workspaces

Add `formatWorkspaces(root)` to the exports. It returns one line per workspace
directory under `root`, in `listWorkspaces` order, each line the first seven
characters of the directory name followed by a newline; `""` when `root` does
not exist.

Add `countWorkspaces(root)` to the exports. It returns the number of workspace
directories under `root`; `0` when `root` does not exist.

Workspace directories are created only by `createWorkspace`, which names them
with twelve lowercase hex digits. Existing behaviour must not change. Tests for
the new functions are not part of this task.
```

`fixtures/codex-focus-arm/P2/lib.js`:

```javascript
"use strict";
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

// Workspace directories are created only here, named with the first twelve
// hex digits of the sha256 of the plan path.
function createWorkspace(root, planPath) {
  const name = crypto.createHash("sha256").update(planPath).digest("hex").slice(0, 12);
  const dir = path.join(root, name);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// Names of the workspace directories under root, sorted; [] when root is absent.
function listWorkspaces(root) {
  if (!fs.existsSync(root)) return [];
  return fs
    .readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

// The workspace report: the first seven characters of each workspace name, one
// per line, in listWorkspaces order.
function formatWorkspaces(root) {
  return listWorkspaces(root)
    .map((name) => `${name.match(/^[0-9a-f]{12}$/)[0].slice(0, 7)}\n`)
    .join("");
}

function countWorkspaces(root) {
  return listWorkspaces(root).length;
}

module.exports = { createWorkspace, listWorkspaces, formatWorkspaces, countWorkspaces };
```

- [ ] **Step 4: Generate the focus files and check their hashes**

The control file is `recipe-code.md` line 53's focus string at `5bef46c`, with its four path placeholders replaced. The treatment file inserts the cap sentence and one space after the anchor (spec "Arms").

```bash
mkdir -p /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope
node --input-type=module -e '
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
const [root, dir] = process.argv.slice(1);
const cap = "A defect reachable only through input that nothing in the code or its callers produces and that only the person running it could supply — a newline or invalid UTF-8 in a file or directory name, a name that starts with a dot — is medium, unless it also breaks the default path or corrupts stored data.";
const anchor = "Naming, style, and speculative hardening are low. ";
const line = execFileSync("git", ["-C", root, "show", "5bef46c:skills/requesting-code-review/recipe-code.md"], { encoding: "utf8" }).split("\n")[52];
const start = line.indexOf("--json \"");
if (start < 0 || !line.endsWith("\"")) throw new Error("line 53 is not a --json launch");
const control = line.slice(start + 8, -1)
  .replace("<TASK_BRIEF_PATH>", () => "$1/REQUIREMENTS.md")
  .replace("<IMPLEMENTER_REPORT_PATH>", () => "$1/REQUIREMENTS.md")
  .replace("<REVIEW_PACKAGE_PATH>", () => "$1/review.diff")
  .replace("<GLOBAL_CONSTRAINTS_PATH>", () => "$1/REQUIREMENTS.md");
if (control.split(anchor).length !== 2) throw new Error("anchor must appear once");
writeFileSync(`${dir}/cap-sentence.txt`, `${cap}\n`);
writeFileSync(`${dir}/focus-control.txt`, control);
writeFileSync(`${dir}/focus-treatment.txt`, control.replace(anchor, () => `${anchor}${cap} `));
' /Users/johnss51/Development/agents/hyperpowers /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope
shasum -a 256 /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/*.txt
```

Expected (the order follows the file names):

```text
0fd022844d9f0cd2d393859a1a228b62f173024cba2e84f395289afd63310931  .../cap-sentence.txt
b8395f171057708d822046e449b0119dfcb726c0112335c98c8e6e8fd06ad2e3  .../focus-control.txt
c8a0a3b8dd94d8624578436b28d329965dd45d538dae93f77e1750a6e119a976  .../focus-treatment.txt
```

A different hash means the cap sentence or the generator was mistranscribed. Stop and compare with this plan's Global Constraints.

- [ ] **Step 5: Write the failing test**

`scripts/codex-focus-arm.test.sh` (then `chmod 755` it):

```bash
#!/usr/bin/env bash
# Proves codex-focus-arm.sh against a stub companion, a stub codex binary and a
# stub Codex config: the focus check refuses altered focus files before any
# broker or review, each arm reviews every named fixture three times with its
# own focus text, the runtime record is written at both ends and a change
# between them fails the arm, a failed review keeps its exit status and still
# releases the broker and writes the end record, a config without one
# top-level model and effort line is refused, and an already-recorded broker
# is refused.
# Needs a hyperpowers checkout (arg 1) for verdict-normalize and for
# recipe-code.md at 5bef46c, and the focus directory (arg 2).
set -euo pipefail
root="${1:?hyperpowers root}"; focus="${2:?focus dir}"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/codex-focus-arm-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $1"; exit 1; }
cap="$(cat "$focus/cap-sentence.txt")"
anchor="Naming, style, and speculative hardening are low. "

plugin="$work/plugin"
mkdir -p "$plugin/.claude-plugin" "$plugin/scripts/lib" "$work/bin" "$work/codex-home"
printf '{"name":"codex","version":"9.9.9-stub"}\n' > "$plugin/.claude-plugin/plugin.json"
cat > "$plugin/scripts/lib/broker-lifecycle.mjs" <<'EOF'
import { appendFileSync } from "node:fs";
const log = (line) => appendFileSync(process.env.STUB_LOG, `${line}\n`);
export function loadBrokerSession() {
  return process.env.STUB_EXISTING_BROKER ? { endpoint: "unix:/stub/existing" } : null;
}
export async function ensureBrokerSession(cwd) {
  log(`ensure ${cwd}`);
  return { endpoint: "unix:/stub/broker" };
}
export async function sendBrokerShutdown(endpoint) {
  log(`shutdown ${endpoint}`);
}
export function clearBrokerSession(cwd) {
  log(`clear ${cwd}`);
}
EOF
cat > "$plugin/scripts/codex-companion.mjs" <<'EOF'
import { appendFileSync, readdirSync, writeFileSync } from "node:fs";
const args = process.argv.slice(2);
const dir = process.env.STUB_FOCUS_DIR;
const call = readdirSync(dir).length + 1;
writeFileSync(`${dir}/${call}.txt`, args[args.indexOf("--json") + 1]);
appendFileSync(process.env.STUB_LOG, `review ${process.env.CODEX_COMPANION_APP_SERVER_ENDPOINT}\n`);
if (String(call) === process.env.STUB_COMPANION_FAIL) { console.error("stub: the turn failed"); process.exit(3); }
console.log(JSON.stringify({ review: "Adversarial Review", result: { verdict: "approve", summary: "stub", findings: [], next_steps: [] }, rawOutput: "", parseError: null }));
EOF
cat > "$work/bin/codex" <<'EOF'
#!/usr/bin/env bash
# A counter file makes each call report a newer version.
if [ -n "${STUB_CODEX_COUNTER:-}" ]; then
  n=$(( $(cat "$STUB_CODEX_COUNTER" 2>/dev/null || echo 0) + 1 ))
  echo "$n" > "$STUB_CODEX_COUNTER"
  echo "codex-cli 0.0.$n"
else
  echo "codex-cli 0.0.1"
fi
EOF
chmod +x "$work/bin/codex"
printf 'model = "stub-model"\nmodel_reasoning_effort = "low"\n\n[profiles.decoy]\nmodel = "decoy-model"\n' > "$work/codex-home/config.toml"

run_arm() { # <name> <focus-dir> <arm> <fixture>... ; leaves $work/<name>{,.log,.focus,.stdout,.stderr}
  local name="$1" fdir="$2" arm="$3"; shift 3
  mkdir -p "$work/$name.focus"
  : > "$work/$name.log"
  PATH="$work/bin:$PATH" CODEX_HOME="${STUB_HOME:-$work/codex-home}" STUB_LOG="$work/$name.log" STUB_FOCUS_DIR="$work/$name.focus" \
    bash "$here/codex-focus-arm.sh" "$root" "$plugin" "$fdir" "$arm" "$work/$name" "$@" \
    > "$work/$name.stdout" 2> "$work/$name.stderr"
}
count() { grep -c -- "$1" "$2" || true; }

# Treatment on all six fixtures.
run_arm treat "$focus" treatment M H O P P2 Pc || fail "treatment arm exited $? ($(cat "$work/treat.stderr"))"
[ "$(find "$work/treat" -name '*-treatment-*.json' | grep -c .)" -eq 18 ] || fail "treatment must leave 18 captures"
[ "$(count '"result":"approved"' "$work/treat.stdout")" -eq 18 ] || fail "every capture must normalize to approved"
for fx in M H O P P2 Pc; do for i in 1 2 3; do
  grep -q "^$fx treatment $i " "$work/treat.stdout" || fail "no normalize line for $fx treatment $i"
done; done
blob="$(git hash-object "$root/skills/requesting-code-review/scripts/verdict-normalize")"
expected="$(printf 'companion 9.9.9-stub\ncodex-binary %s\ncodex-version codex-cli 0.0.1\nmodel = "stub-model"\nmodel_reasoning_effort = "low"\nverdict-normalize %s' "$work/bin/codex" "$blob")"
[ "$(cat "$work/treat/runtime-start.txt")" = "$expected" ] || fail "runtime record: $(cat "$work/treat/runtime-start.txt")"
cmp -s "$work/treat/runtime-start.txt" "$work/treat/runtime-end.txt" || fail "start and end records must match"
[ "$(count '^ensure ' "$work/treat.log")" -eq 1 ] || fail "one broker per arm"
[ "$(count '^shutdown unix:/stub/broker$' "$work/treat.log")" -eq 1 ] || fail "the arm shuts down its own broker once"
[ "$(count '^clear ' "$work/treat.log")" -eq 1 ] || fail "the arm clears its broker record once"
[ "$(count '^review unix:/stub/broker$' "$work/treat.log")" -eq 18 ] || fail "every review goes through the arm's broker"
broker_dir="$(sed -n 's/^broker-dir //p' "$work/treat/broker.txt")"
grep -q "^ensure $broker_dir$" "$work/treat.log" || fail "the broker is keyed to the recorded directory"
[ ! -e "$broker_dir" ] || fail "the broker directory is removed on exit"
for f in "$work/treat.focus"/*.txt; do
  [ "$(grep -F -o -- "$cap" "$f" | grep -c .)" -eq 1 ] || fail "treatment focus must carry the cap sentence once: $f"
  # shellcheck disable=SC2016 # the literal placeholder
  ! grep -Fq -- '$1' "$f" || fail "treatment focus still holds a \$1 placeholder: $f"
  grep -Eq 'Review package: /.+/review\.diff\.' "$f" || fail "treatment focus must name the work directory's review.diff: $f"
done

# Control on one fixture: no cap, and the anchor runs straight into the next sentence.
run_arm ctl "$focus" control H || fail "control arm exited $? ($(cat "$work/ctl.stderr"))"
[ "$(find "$work/ctl" -name 'H-control-*.json' | grep -c .)" -eq 3 ] || fail "control must leave 3 captures"
for f in "$work/ctl.focus"/*.txt; do
  ! grep -Fq -- "$cap" "$f" || fail "control focus must not carry the cap sentence: $f"
  grep -Fq -- "${anchor}You are a stateless reviewer" "$f" || fail "control focus must be the 5bef46c text: $f"
done

# An altered cap in the treatment file fails before any broker or review.
cp -R "$focus" "$work/bad-treatment"
sed 's/is medium, unless/is low, unless/' "$focus/focus-treatment.txt" > "$work/bad-treatment/focus-treatment.txt"
if run_arm badt "$work/bad-treatment" treatment H; then fail "an altered treatment file must fail the arm"; fi
grep -q 'focus check' "$work/badt.stderr" || fail "the treatment refusal names the focus check"
[ ! -s "$work/badt.log" ] || fail "no broker or review before the focus check passes"

# A control file that no longer matches line 53 fails, even when the treatment
# file is changed to match it.
cp -R "$focus" "$work/bad-control"
sed 's/Do not edit anything\./Do not edit files./' "$focus/focus-control.txt" > "$work/bad-control/focus-control.txt"
sed 's/Do not edit anything\./Do not edit files./' "$focus/focus-treatment.txt" > "$work/bad-control/focus-treatment.txt"
if run_arm badc "$work/bad-control" control H; then fail "a control file that is not line 53 must fail the arm"; fi
grep -q 'not recipe-code.md line 53' "$work/badc.stderr" || fail "the control refusal names line 53"
[ ! -s "$work/badc.log" ] || fail "no broker or review before the focus check passes"

# A broker already recorded for the arm's directory is refused, never reused.
if STUB_EXISTING_BROKER=1 run_arm busy "$focus" control H; then fail "a recorded broker must stop the arm"; fi
grep -q 'already recorded' "$work/busy.stderr" || fail "the refusal names the recorded broker"
[ "$(count '^ensure ' "$work/busy.log")" -eq 0 ] || fail "a recorded broker must not be ensured"
[ "$(count '^shutdown ' "$work/busy.log")" -eq 0 ] || fail "a broker the arm did not start must not be shut down"
[ -z "$(find "$work/busy" -name '*.json')" ] || fail "no captures when the broker is refused"

# Unknown fixtures and arms are usage errors.
rc=0; run_arm unknown "$focus" control Z || rc=$?
[ "$rc" -eq 2 ] || fail "an unknown fixture must exit 2, got $rc"
rc=0; run_arm badarm "$focus" both H || rc=$?
[ "$rc" -eq 2 ] || fail "an unknown arm must exit 2, got $rc"

# A runtime change between the start and the end of an arm fails it.
if STUB_CODEX_COUNTER="$work/counter" run_arm drift "$focus" control M; then fail "a runtime change must fail the arm"; fi
grep -q 'runtime changed during the arm' "$work/drift.stderr" || fail "the drift failure names the runtime record"
! cmp -s "$work/drift/runtime-start.txt" "$work/drift/runtime-end.txt" || fail "drift records must differ"

# A review that fails mid-arm keeps its exit status, and the arm still releases
# its broker and writes an end record that matches the start.
rc=0; STUB_COMPANION_FAIL=2 run_arm crash "$focus" control M H || rc=$?
[ "$rc" -eq 3 ] || fail "a failed review must keep its exit status 3, got $rc"
[ "$(count '^M control ' "$work/crash.stdout")" -eq 1 ] || fail "the arm stops at the failed review"
[ -z "$(find "$work/crash" -name 'H-*')" ] || fail "no fixture after the failed review is reviewed"
cmp -s "$work/crash/runtime-start.txt" "$work/crash/runtime-end.txt" || fail "a failed arm still writes a matching end record"
[ "$(count '^shutdown unix:/stub/broker$' "$work/crash.log")" -eq 1 ] || fail "a failed arm shuts down its broker once"
[ "$(count '^clear ' "$work/crash.log")" -eq 1 ] || fail "a failed arm clears its broker record once"

# A Codex config without exactly one top-level model and effort line is
# refused before the broker starts, and leaves no runtime record.
mkdir -p "$work/no-effort" "$work/two-models"
printf 'model = "stub-model"\n' > "$work/no-effort/config.toml"
printf 'model = "a"\nmodel = "b"\nmodel_reasoning_effort = "low"\n' > "$work/two-models/config.toml"
for home in no-effort two-models; do
  rc=0; STUB_HOME="$work/$home" run_arm "$home" "$focus" control H || rc=$?
  [ "$rc" -eq 1 ] || fail "a $home config must exit 1, got $rc"
  grep -q 'model and model_reasoning_effort once each' "$work/$home.stderr" || fail "the $home refusal names the config rule"
  [ ! -s "$work/$home.log" ] || fail "no broker or review with a $home config"
  [ ! -e "$work/$home/runtime-start.txt" ] || fail "no runtime record from a $home config"
done

echo "PASS: codex-focus-arm checks its focus files and Codex config first, reviews each fixture three times per arm through one broker it owns, refuses a recorded broker, releases its broker and writes the end record on every exit, and fails on runtime drift"
```

- [ ] **Step 6: Run the test against today's runner to verify it fails**

Every Codex call in the test goes through the stubs, so this step spends nothing. The hyperpowers root is this plan's worktree, the checkout every live run uses too.

Run: `bash /Users/johnss51/Development/agents/hyperpowers/evals/scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope`

Expected: exit 1, with output beginning `FAIL: treatment arm exited 1`. Today's runner takes four arguments, so it reads the focus directory as the arm and `treatment` as the output directory, and it fails writing its first capture.

- [ ] **Step 7: Write the runner**

Replace `scripts/codex-focus-arm.sh` entirely (keep mode 100755):

```bash
#!/usr/bin/env bash
# codex-focus-arm.sh <hyperpowers-root> <codex-plugin-root> <focus-dir> <control|treatment> <out-dir> <fixture>...
# Reviews each named fixture with real Codex three times under one arm's focus
# text and normalizes every capture with hyperpowers' verdict-normalize.
# <focus-dir> holds focus-control.txt, focus-treatment.txt and cap-sentence.txt.
# The arm's file is the recipe focus, composed after the correctness-lens
# skeleton. Before any review the script proves that the treatment file is the
# control file plus the cap sentence, and that the control file is
# recipe-code.md line 53 at 5bef46c with its four path placeholders filled in.
# Each fixture becomes a two-commit git repo: base = checked-in lib.base.js,
# head = the fixture's lib.js. Asserts both parse and pass tests before reviewing.
# The companion version, the codex binary and version, the configured model and
# reasoning effort, and the verdict-normalize blob are recorded before the
# broker starts and again on every exit after that; the arm fails if the two
# records differ, and a failed arm keeps its own exit status.
# Runs are sequential and blocking; launch this script with the shell tool's
# background option and watch its log, never a bare foreground call a harness
# timeout can kill mid-review.
#
# Round 3 change: uses checked-in lib.base.js instead of filtering (round 2's
# filter left lines after trim, producing broken bases). Asserts both revisions
# parse and test before reviewing.
set -euo pipefail
root="${1:?hyperpowers root}"; codex="${2:?codex-plugin-cc root}"; focus_dir="${3:?focus dir}"; arm="${4:?control|treatment}"; out="${5:?out dir}"
shift 5
here="$(cd "$(dirname "$0")/.." && pwd)"

case "$arm" in
  control|treatment) ;;
  *) echo "arm must be control or treatment, got: $arm" >&2; exit 2 ;;
esac
[ "$#" -gt 0 ] || { echo "name at least one fixture" >&2; exit 2; }

# The head commit's message, as the 09-05 rounds used for M, H and O.
commit_message() {
  case "$1" in
    M|H|O) printf '%s' "accept percent strings" ;;
    P|P2) printf '%s' "report and count workspaces" ;;
    Pc) printf '%s' "mark every workspace paused or resumed" ;;
    *) echo "no commit message for fixture: $1" >&2; return 1 ;;
  esac
}
for fx in "$@"; do
  commit_message "$fx" >/dev/null || exit 2
  [ -f "$here/fixtures/codex-focus-arm/$fx/lib.base.js" ] || { echo "no fixture at fixtures/codex-focus-arm/$fx" >&2; exit 2; }
done

# shellcheck disable=SC2016 # node source, not shell
node --input-type=module -e '
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
const [root, dir] = process.argv.slice(1);
const fail = (why) => { console.error(`focus check: ${why}`); process.exit(1); };
const control = readFileSync(`${dir}/focus-control.txt`, "utf8");
const treatment = readFileSync(`${dir}/focus-treatment.txt`, "utf8");
const cap = readFileSync(`${dir}/cap-sentence.txt`, "utf8").replace(/\n$/, "");
const anchor = "Naming, style, and speculative hardening are low. ";
const capped = `${anchor}${cap} `;
if (control.split(anchor).length !== 2) fail("the control file must carry the calibration anchor exactly once");
if (treatment.split(capped).length !== 2) fail("the treatment file must carry the cap sentence once, right after the anchor");
if (treatment.replace(capped, () => anchor) !== control) fail("the treatment file without the cap sentence is not the control file");
const line = execFileSync("git", ["-C", root, "show", "5bef46c:skills/requesting-code-review/recipe-code.md"], { encoding: "utf8" }).split("\n")[52];
const start = line.indexOf("--json \"");
if (start < 0 || !line.endsWith("\"")) fail("recipe-code.md line 53 at 5bef46c is not a --json launch");
const reversed = control
  .replace("Requirements: $1/REQUIREMENTS.md.", () => "Requirements: <TASK_BRIEF_PATH>.")
  .replace("Implementer report: $1/REQUIREMENTS.md.", () => "Implementer report: <IMPLEMENTER_REPORT_PATH>.")
  .replace("Review package: $1/review.diff.", () => "Review package: <REVIEW_PACKAGE_PATH>.")
  .replace("Global constraints: $1/REQUIREMENTS.md.", () => "Global constraints: <GLOBAL_CONSTRAINTS_PATH>.");
if (reversed !== line.slice(start + 8, -1)) fail("the control file is not recipe-code.md line 53 at 5bef46c");
' "$root" "$focus_dir"
recipe_template="$(cat "$focus_dir/focus-$arm.txt")"

mkdir -p "$out"
# Each step returns on failure itself: the finish trap calls this in a
# condition, where set -e does not apply.
runtime_record() {
  local companion binary version settings normalizer
  companion="$(node -p 'require(process.argv[1]).version' "$codex/.claude-plugin/plugin.json")" || return 1
  binary="$(command -v codex)" || return 1
  version="$(codex --version)" || return 1
  # Top-level keys only: a profile section can carry its own model line.
  settings="$(awk '
    /^\[/ { exit }
    /^(model|model_reasoning_effort)[[:space:]]*=/ { print; key = $0; sub(/[[:space:]]*=.*/, "", key); seen[key]++ }
    END {
      if (seen["model"] != 1 || seen["model_reasoning_effort"] != 1) {
        print "the Codex config must set model and model_reasoning_effort once each at the top level" > "/dev/stderr"
        exit 1
      }
    }' "${CODEX_HOME:-$HOME/.codex}/config.toml")" || return 1
  normalizer="$(git hash-object "$root/skills/requesting-code-review/scripts/verdict-normalize")" || return 1
  printf 'companion %s\ncodex-binary %s\ncodex-version %s\n%s\nverdict-normalize %s\n' "$companion" "$binary" "$version" "$settings" "$normalizer"
}
if ! runtime_record > "$out/runtime-start.txt"; then
  rm -f "$out/runtime-start.txt"
  echo "cannot write the runtime record; no review ran" >&2
  exit 1
fi

# From here every exit releases the broker if one was started and writes the
# end record, so a failed arm still leaves both records for the audit.
broker_dir=""
broker_endpoint=""
finish() {
  local rc=$?
  if [ -n "$broker_endpoint" ]; then
    # shellcheck disable=SC2016 # node source, not shell
    node --input-type=module -e '
const [lib, endpoint, dir] = process.argv.slice(1);
const { sendBrokerShutdown, clearBrokerSession } = await import(lib);
await sendBrokerShutdown(endpoint);
clearBrokerSession(dir);
' "$codex/scripts/lib/broker-lifecycle.mjs" "$broker_endpoint" "$broker_dir" || echo "warning: could not release the broker at $broker_endpoint" >&2
  fi
  [ -z "$broker_dir" ] || rm -rf "$broker_dir"
  if ! runtime_record > "$out/runtime-end.txt"; then
    echo "cannot write $out/runtime-end.txt" >&2
    [ "$rc" -ne 0 ] || rc=1
  elif ! cmp -s "$out/runtime-start.txt" "$out/runtime-end.txt"; then
    echo "runtime changed during the arm; see $out/runtime-start.txt and $out/runtime-end.txt" >&2
    [ "$rc" -ne 0 ] || rc=1
  fi
  exit "$rc"
}
trap finish EXIT

# One broker for the whole arm, released when the script exits. The companion
# otherwise starts a broker per workspace root, and every fixture below runs in
# its own temporary directory: a 3x3 arm left 26 brokers alive, holding their
# sockets after the temp copies were gone, because no SessionEnd hook fires for
# a script. Pointing every review at one endpoint removes the per-fixture
# broker entirely.
# The broker is keyed to a fresh directory, not this checkout: a Claude
# session's own Codex review run from the evals checkout keeps its broker
# recorded until that session ends, and an arm must neither review through nor
# shut down a broker it did not start.
broker_dir="$(mktemp -d "${TMPDIR:-/tmp}/focus-arm-broker.XXXXXX")"
# shellcheck disable=SC2016 # node source, not shell
broker_endpoint="$(node --input-type=module -e '
const [lib, dir] = process.argv.slice(1);
const { loadBrokerSession, ensureBrokerSession } = await import(lib);
if (loadBrokerSession(dir)) { console.error(`a broker is already recorded for ${dir}`); process.exit(1); }
const session = await ensureBrokerSession(dir);
if (!session || !session.endpoint) { console.error("no broker endpoint"); process.exit(1); }
console.log(session.endpoint);
' "$codex/scripts/lib/broker-lifecycle.mjs" "$broker_dir")"
export CODEX_COMPANION_APP_SERVER_ENDPOINT="$broker_endpoint"
printf 'broker-dir %s\nendpoint %s\n' "$broker_dir" "$broker_endpoint" > "$out/broker.txt"

# Lens skeleton for correctness lens (task/adhoc gate, round 1)
lens_skeleton() {
  cat <<'EOF'
Read the review dossier first — it is your delivered context: $1/review.diff
Where a dossier section says NOT PROVIDED, answer that Coverage axis exactly `cannot-verify: <reason>` — never `not applicable`; where it says NOT APPLICABLE, answer it `not applicable: <why>` without hedging.
Your lens for this review: Does the change do what its requirements say, and only that; logic, edge cases, failure paths.
Report every blocking finding you can identify this round; do not reserve findings for later rounds.
Findings outside your lens are still reported, labeled [out-of-lane] — never suppressed.
You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills.
Do not edit anything. Return exactly the structured JSON output format required for code reviews, adding a Coverage: section inside the summary field with these axes (each answered concretely or marked not applicable): documents read (review.diff); adjudicated decisions considered (none); changed surfaces reviewed (from review.diff); test evidence inspected (from REQUIREMENTS.md).

EOF
}

for fx in "$@"; do
  work="$(mktemp -d "${TMPDIR:-/tmp}/focus-arm-$fx.XXXXXX")"
  cp "$here/fixtures/codex-focus-arm/$fx/"* "$work/"
  git -C "$work" init -q

  # Base: checked-in lib.base.js
  cp "$here/fixtures/codex-focus-arm/$fx/lib.base.js" "$work/lib.js"

  # Assert base parses and tests pass
  node --check "$work/lib.js"
  ( cd "$work" && node test.js > /dev/null )

  git -C "$work" -c user.email=t@t -c user.name=t add -A && git -C "$work" -c user.email=t@t -c user.name=t commit -qm base
  base="$(git -C "$work" rev-parse HEAD)"

  # Head: fixture's lib.js
  cp "$here/fixtures/codex-focus-arm/$fx/lib.js" "$work/lib.js"

  # Assert head parses and tests pass
  node --check "$work/lib.js"
  ( cd "$work" && node test.js > /dev/null )

  git -C "$work" -c user.email=t@t -c user.name=t commit -qam "$(commit_message "$fx")"
  git -C "$work" diff "$base" HEAD > "$work/review.diff"

  for i in 1 2 3; do
    # Compose production round-1 focus: lens skeleton + recipe focus
    skeleton="$(lens_skeleton | sed "s|\\\$1|$work|g")"
    recipe="$(printf '%s' "$recipe_template" | sed "s|\\\$1|$work|g")"
    focus="$skeleton$recipe"

    cap="$out/$fx-$arm-$i.json"
    ( cd "$work" && node "$codex/scripts/codex-companion.mjs" adversarial-review --base "$base" --json "$focus" ) > "$cap" 2>"$cap.err"
    printf '%s %s %s ' "$fx" "$arm" "$i"; bash "$root/skills/requesting-code-review/scripts/verdict-normalize" "$cap"
  done
done
```

The skeleton and recipe are concatenated with no separator. The skeleton's heredoc ends in a blank line, so after command substitution strips trailing newlines, the skeleton's last line runs straight into the recipe text. Keep it that way: it is the composition the 2026-09-05 rounds measured.

- [ ] **Step 8: Run the test to verify it passes**

Run: `bash /Users/johnss51/Development/agents/hyperpowers/evals/scripts/codex-focus-arm.test.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope`

Expected: exit 0 and the final line `PASS: codex-focus-arm checks its focus files and Codex config first, reviews each fixture three times per arm through one broker it owns, refuses a recorded broker, releases its broker and writes the end record on every exit, and fails on runtime drift`.

The treatment case runs all six fixtures, P2 included, through the runner's argument check, commit message, focus composition and capture naming. It also runs every fixture's base and head through `node --check` and `node test.js` in a temporary copy, so a PASS proves that P, Pc and P2 parse and pass. Never run a fixture's `test.js` in place: evals `package.json` declares `"type": "module"`, and `require` fails under it.

- [ ] **Step 9: Lint both scripts**

```bash
shellcheck /Users/johnss51/Development/agents/hyperpowers/evals/scripts/codex-focus-arm.sh /Users/johnss51/Development/agents/hyperpowers/evals/scripts/codex-focus-arm.test.sh
```

Expected: no output, exit 0.

- [ ] **Step 10: Run the evals checks**

The runner, its test, the fixtures and the focus files are final now.

```bash
cd /Users/johnss51/Development/agents/hyperpowers/evals && bun run check
cd /Users/johnss51/Development/agents/hyperpowers/evals && bun run quorum check
```

Expected: `bun run check` gives 1295 pass, 0 fail unsandboxed (sandboxed: 1293 pass and the two EPERM failures named in Global Constraints). `bun run quorum check` exits 0.

- [ ] **Step 11: Confirm the change set and stage**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals status --short --untracked-files=all
```

Expected entries:
- ` M scripts/codex-focus-arm.sh`;
- `??` for `scripts/codex-focus-arm.test.sh`;
- the twelve files under `fixtures/codex-focus-arm/{P,Pc,P2}/`;
- the three `.txt` files under `evidence/2026-10-03-review-calibration-and-sentinel-scope/`.

Nothing under `src`, `scenarios`, `coding-agents`, `package.json`, `bun.lock` or `fixtures/codex-focus-arm/H/.claude`. Task 1's files may also appear if they are not yet committed.

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals add scripts/codex-focus-arm.sh scripts/codex-focus-arm.test.sh fixtures/codex-focus-arm/P fixtures/codex-focus-arm/Pc fixtures/codex-focus-arm/P2 evidence/2026-10-03-review-calibration-and-sentinel-scope/cap-sentence.txt evidence/2026-10-03-review-calibration-and-sentinel-scope/focus-control.txt evidence/2026-10-03-review-calibration-and-sentinel-scope/focus-treatment.txt
git -C /Users/johnss51/Development/agents/hyperpowers/evals diff --cached | /usr/bin/grep -F -e "${HTTPS_PROXY#*://}" -e "$NO_PROXY" -e "$ANTHROPIC_VERTEX_PROJECT_ID"; echo "grep exit $?"
```

Expected: `grep exit 1`. Commit message: `feat(codex-focus-arm): fixture list, focus files, runtime record and an owned broker; add fixtures P, Pc and P2`.

---

### Task 4: Reproduce the over-rating on P under control (RED)

**Risk tier:** high — controller-run, no implementer subagent: three to nine live Codex reviews whose captures are durable evidence and whose reading decides whether Task 5 runs. Nothing is committed in this task; its evidence lands in Task 7's evals commit, which goes through the review train.

**Repository:** evals

**Files:**
- Create: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.py`
- Create: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P/` (and, by the rules below, `control-P-rerun-P/`, `control-P2/`, `control-P2-rerun-P2/` or a `-runtime-rerun/` directory)
- Create (Stop path only): evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.txt`

**Interfaces:**
- Consumes: Task 3's runner, fixtures and focus files; the pre-registration commit of this plan.
- Produces: the validated fixture name (`P` or `P2`) that Task 5's treatment arm runs; the reference runtime record `task-4-runs/control-P/runtime-start.txt`.

- [ ] **Step 1: Preflight**

Run it as one Bash call:

```bash
hp=/Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope
evals=/Users/johnss51/Development/agents/hyperpowers/evals
ev=evidence/2026-10-03-review-calibration-and-sentinel-scope
spec=docs/hyperpowers/specs/2026-10-03-review-calibration-and-sentinel-scope-design.md
plan=docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md
prereg="$(git -C "$hp" log --diff-filter=A --format=%h -- "$plan")"
echo "pre-registration commit: ${prereg:-none}"
# A ticked checkbox or an appended correction only adds lines. A line removed
# or changed since the pre-registration shows up as a "<" line.
untick() { sed 's/^\([[:space:]]*\)- \[x\]/\1- [ ]/'; }
for f in "$spec" "$plan"; do
  if [ -n "$prereg" ] && git -C "$hp" show "$prereg:$f" | untick | diff - <(untick < "$hp/$f") | /usr/bin/grep -q '^<'; then echo "CHANGED SINCE PRE-REGISTRATION: $f"; fi
done
git -C "$hp" status --porcelain -- "$spec" "$plan"
git -C "$evals" status --porcelain --untracked-files=all -- scripts/codex-focus-arm.sh scripts/codex-focus-arm.test.sh fixtures/codex-focus-arm "$ev/cap-sentence.txt" "$ev/focus-control.txt" "$ev/focus-treatment.txt"
git -C "$evals" log --oneline -3 -- scripts/codex-focus-arm.sh
echo "verdict-normalize: worktree $(git -C "$hp" hash-object skills/requesting-code-review/scripts/verdict-normalize), 5bef46c $(git -C "$hp" rev-parse 5bef46c:skills/requesting-code-review/scripts/verdict-normalize)"
command -v codex
codex --version
/bin/ls /Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6/scripts/codex-companion.mjs
```

Expected:
- `pre-registration commit: <id>`, not `none`, and no `CHANGED SINCE PRE-REGISTRATION` line;
- both `status --porcelain` commands print nothing: the spec, the plan and every file Task 3 wrote are committed and unmodified (the stray `fixtures/codex-focus-arm/H/.claude/` is gitignored and does not show);
- Task 3's commit is the newest runner commit;
- the two `verdict-normalize` ids are equal, so the worktree's normalizer is the one at `5bef46c`;
- `codex` resolves and the companion exists.

Any other result: do not start. Report it to the human partner.

- [ ] **Step 2: Save the tally script**

`evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.py`:

```python
"""Tally the normalized verdict of every focus-arm capture, per run directory and fixture.

Refuses to run unless the normalizer is the blob the reference runtime record
names, so every reading comes from the script the reviews were recorded under.

Usage: tally.py <hyperpowers-root> <evidence-dir>
"""
import collections
import json
import pathlib
import subprocess
import sys

hp, evidence = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
normalize = hp / "skills/requesting-code-review/scripts/verdict-normalize"
reference = (evidence / "task-4-runs/control-P/runtime-start.txt").read_text(encoding="utf-8").splitlines()
recorded = [line.split(" ", 1)[1] for line in reference if line.startswith("verdict-normalize ")]
blob = subprocess.run(["git", "hash-object", str(normalize)], capture_output=True, text=True, check=True).stdout.strip()
if recorded != [blob]:
    sys.exit(f"{normalize} is blob {blob}; the reference runtime record names {recorded}")
cells: dict[tuple[str, str, str], collections.Counter[str]] = collections.defaultdict(collections.Counter)
for capture in sorted(evidence.glob("task-*-runs/*/*.json")):
    fixture, _arm, _index = capture.stem.rsplit("-", 2)
    out = subprocess.run(["bash", str(normalize), str(capture)], capture_output=True, text=True, check=True).stdout
    cells[(capture.parent.parent.name, capture.parent.name, fixture)][json.loads(out)["result"]] += 1
for (task, run, fixture), counts in sorted(cells.items()):
    n = sum(counts.values())
    print(f"{task}\t{run}\t{fixture}\tblocking {counts['blocking']}/{n}\tapproved {counts['approved']}/{n}\tincomplete {counts['incomplete']}/{n}")
```

Check it: `ruff check` and `mypy --strict` on the file. Both must be clean. It reads its reference from the first control-P record, so it runs only after Step 3, and it exits non-zero with both blob ids if the normalizer has changed since that record was written.

- [ ] **Step 3: Run control on P**

```bash
mkdir -p /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P
bash /Users/johnss51/Development/agents/hyperpowers/evals/scripts/codex-focus-arm.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6 /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope control /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P P > /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P/run.log 2> /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-4-runs/control-P/run.err
```

Launch it with the Bash tool's background option (Global Constraints, "Codex runs"), and wait for the completion notification. Expected: exit 0; `run.log` holds three lines beginning `P control 1 `, `P control 2 ` and `P control 3 `; `run.err` is empty; `runtime-start.txt` and `runtime-end.txt` are identical and six lines long. Note the exit status: Step 4's first rule reads it.

- [ ] **Step 4: Tally and decide**

```bash
python3 /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.py /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope
```

If Step 3's two runtime records differ, apply the runtime rule first and read the `control-P-runtime-rerun` line in place of `control-P`. Read the `task-4-runs	control-P	P` line and apply the first rule that matches:
1. **Any incomplete, or the invocation exited non-zero with matching runtime records:** void rule. Re-run Step 3 with the output directory `task-4-runs/control-P-rerun-P` and its own `run.log`/`run.err`, then decide on the re-run's three readings. A second instrument failure stops the plan.
2. **Blocking at least 2 of 3:** P is validated. Task 5's treatment arm runs on `P`.
3. **Blocking at most 1 of 3:** run Step 3 again with fixture `P2` and output directory `task-4-runs/control-P2`. Tally it, applying the void rule as in rule 1, with re-run directory `task-4-runs/control-P2-rerun-P2`.
   - If P2 blocks at least 2 of 3, P2 is validated, and Task 5's treatment arm runs on `P2`.
   - If not, this is the Stop path. No over-rating was reproduced, so no sentence ships. Write the tally now, run Step 5, skip Tasks 5 and 6, and go to Task 7 on its Stop path:

     ```bash
     python3 /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.py /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope > /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.txt
     ```

An instrument stop (a second instrument failure, a refused invocation, or a runtime that cannot be restored) is not the Stop path: it measured nothing. The controller reports it to the human partner. Task 7 runs only if they choose to record it, naming the reason.

- [ ] **Step 5: Check the runtime records**

```bash
ev=/Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope
ref="$ev/task-4-runs/control-P/runtime-start.txt"
[ "$(wc -l < "$ref" | tr -d ' ')" -eq 6 ] || echo "REFERENCE IS NOT SIX LINES"
for d in "$ev"/task-4-runs/*/; do for f in runtime-start.txt runtime-end.txt; do cmp -s "$ref" "$d$f" || echo "DIFFERS OR MISSING: $d$f"; done; done
```

Expected: no output. A run directory whose records are missing or differ follows the runtime rule in Global Constraints; the only lines allowed to remain are those for a directory superseded by its `-runtime-rerun/`, which Task 7's README names.

- [ ] **Step 6: Report**

Tell the human partner the control-P reading, and the P2 reading if it ran. Name the validated fixture, or say that the plan stopped.

---

### Task 5: Run both arms on the five fixtures and apply the decision rule

**Risk tier:** high — controller-run, no implementer subagent: 27 live Codex reviews, plus re-runs under the void rule, and the ship decision. Nothing is committed in this task; its evidence and tally land in Task 7's evals commit, which goes through the review train.

**Repository:** evals

**Files:**
- Create: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/control/`
- Create: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/treatment/` (and `<arm>-rerun-<fixture>/` directories under the void rule)
- Create: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.txt`

**Interfaces:**
- Consumes: Task 4's validated fixture (`P` or `P2`) and reference runtime record.
- Produces: a win or a loss under the decision rule. Task 6 runs only on a win.

- [ ] **Step 1: Run control on Pc, H, O and M**

```bash
mkdir -p /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/control
bash /Users/johnss51/Development/agents/hyperpowers/evals/scripts/codex-focus-arm.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6 /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope control /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/control Pc H O M > /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/control/run.log 2> /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/control/run.err
```

Run it in the background and wait for it to exit. Expected: exit 0, 12 lines in `run.log` and an empty `run.err`. Tally it (Task 4 Step 4's command). Apply the void rule to any cell with an incomplete, and, if the invocation exited non-zero with matching runtime records, to every fixture without three readings in `run.log`. Each re-run takes only its fixture, writing to `task-5-runs/control-rerun-<fixture>`. If the records differ, apply the runtime rule instead.

- [ ] **Step 2: Run treatment on the validated P, Pc, H, O and M**

Use `P` or `P2`, as Task 4 decided, for `<validated>`:

```bash
mkdir -p /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/treatment
bash /Users/johnss51/Development/agents/hyperpowers/evals/scripts/codex-focus-arm.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6 /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope treatment /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/treatment <validated> Pc H O M > /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/treatment/run.log 2> /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/task-5-runs/treatment/run.err
```

Run it in the background and wait for it to exit. Expected: exit 0, 15 lines in `run.log` and an empty `run.err`. Tally it and apply the void rule as in Step 1, incompletes and failed invocations alike, with re-runs writing to `task-5-runs/treatment-rerun-<fixture>`. If the records differ, apply the runtime rule instead.

- [ ] **Step 3: Check every runtime record against the reference**

```bash
ev=/Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope
ref="$ev/task-4-runs/control-P/runtime-start.txt"
[ "$(wc -l < "$ref" | tr -d ' ')" -eq 6 ] || echo "REFERENCE IS NOT SIX LINES"
for d in "$ev"/task-*-runs/*/; do for f in runtime-start.txt runtime-end.txt; do cmp -s "$ref" "$d$f" || echo "DIFFERS OR MISSING: $d$f"; done; done
```

Expected: no output, other than lines for directories superseded by their `-runtime-rerun/`, which Task 7's README names. Otherwise follow the runtime rule. The comparison stands only once every record in use agrees.

- [ ] **Step 4: Record the tally**

```bash
python3 /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.py /Users/johnss51/Development/agents/hyperpowers/.worktrees/review-calibration-and-sentinel-scope /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope > /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/tally.txt
```

- [ ] **Step 5: Apply the decision rule**

Take each treatment cell from `task-5-runs/treatment`, or from its `-rerun-<fixture>` or `-runtime-rerun` replacement, and each control cell the same way from `task-5-runs/control`. Check the five lines of the decision rule in Global Constraints, and write the readings down as a table with columns `fixture | control blocks | treatment blocks | rule | holds`. Control's P cell comes from Task 4's validated directory.
- **Win (all five lines hold):** go to Task 6.
- **Loss (any line fails):** skip Task 6 and go to Task 7 on its Loss path. Name the failing line or lines.

Report the table to the human partner either way.

---

### Task 6: Ship the cap in the three focus strings and pin its placement (win only)

**Risk tier:** standard — behavior-shaping skill-text surgery across a recipe, its split-edit table and its contract test. It runs only after Task 5's win.

**Repository:** hyperpowers

**Files:**
- Modify: `skills/requesting-code-review/recipe-code.md:53,71,81`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (rows 20, 22, 23)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (insert after line 343)

**Interfaces:**
- Consumes: Task 5's win; evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/focus-treatment.txt` (the measured treatment text).
- Produces: the shipped focus strings, whose line 53 equals the measured treatment text.

**Mirror:** `tests/codex-review-gate/test-gate-contract.sh:310-343` (the `full_cal` count and the per-launch block loop).

- [ ] **Step 1: Write the failing pin**

In `tests/codex-review-gate/test-gate-contract.sh`, the block that checks `launches -eq 3` ends at line 343 with `fi`, and line 344 is blank. Insert this after line 344, followed by one blank line, so it sits before the comment `# The calibration reaches a lens launch...`:

```bash
# The cap sentence carries its own placement: it must follow the calibration
# anchor inside each launch, not merely appear three times somewhere. Both
# counts are occurrences, not lines: a cap repeated on one launch line is a
# defect that a line count would miss.
cap='A defect reachable only through input that nothing in the code or its callers produces and that only the person running it could supply — a newline or invalid UTF-8 in a file or directory name, a name that starts with a dot — is medium, unless it also breaks the default path or corrupts stored data.'
n="$(grep -F -o -- "$cap" "$GATE" | grep -c .)"
if [ "$n" -eq 3 ]; then
  pass "all three code-review focus strings carry the pathological-input cap"
else
  fail "all three code-review focus strings carry the pathological-input cap (found $n)"
fi
capped="Naming, style, and speculative hardening are low. $cap"
launches=0
for block in "$BLOCKS"/*; do
  grep -Fq -- "adversarial-review --base" "$block" || continue
  launches=$((launches + 1))
  bare="$(grep -F -o -- "$cap" "$block" | grep -c .)"
  hits="$(grep -F -o -- "$capped" "$block" | grep -c .)"
  if [ "$bare" -eq 1 ] && [ "$hits" -eq 1 ]; then
    pass "code recipe launch $launches carries the cap once, right after the calibration"
  else
    fail "code recipe launch $launches carries the cap once, right after the calibration (cap $bare, after the calibration $hits)"
    echo "    in the block beginning: $(head -n 1 "$block")"
  fi
done
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`

Expected: exit 1, with these four failures and every other check passing as before:

```text
  [FAIL] all three code-review focus strings carry the pathological-input cap (found 0)
  [FAIL] code recipe launch 1 carries the cap once, right after the calibration (cap 0, after the calibration 0)
  [FAIL] code recipe launch 2 carries the cap once, right after the calibration (cap 0, after the calibration 0)
  [FAIL] code recipe launch 3 carries the cap once, right after the calibration (cap 0, after the calibration 0)
```

The last line is `STATUS: FAILED (4 failure(s))`.

- [ ] **Step 3: Insert the cap into the recipe and the split-edit table**

```bash
python3 - <<'EOF'
import pathlib
cap = "A defect reachable only through input that nothing in the code or its callers produces and that only the person running it could supply — a newline or invalid UTF-8 in a file or directory name, a name that starts with a dot — is medium, unless it also breaks the default path or corrupts stored data."
anchor = "Naming, style, and speculative hardening are low. "
for name in ["skills/requesting-code-review/recipe-code.md", "tests/codex-review-gate/gate-post-split-edits.tsv"]:
    path = pathlib.Path(name)
    text = path.read_text(encoding="utf-8")
    assert text.count(anchor) == 3, (name, text.count(anchor))
    assert cap not in text, name
    path.write_text(text.replace(anchor, anchor + cap + " "), encoding="utf-8")
    print(name, "updated")
EOF
```

Expected: two `updated` lines. The TSV forbids tabs and backslashes in a replacement, and the cap contains neither.

- [ ] **Step 4: Verify that the shipped line 53 is the measured treatment text**

```bash
node -e '
const fs = require("node:fs");
const line = fs.readFileSync("skills/requesting-code-review/recipe-code.md", "utf8").split("\n")[52];
const start = line.indexOf("--json \"");
const shipped = line.slice(start + 8, -1)
  .replace("<TASK_BRIEF_PATH>", () => "$1/REQUIREMENTS.md")
  .replace("<IMPLEMENTER_REPORT_PATH>", () => "$1/REQUIREMENTS.md")
  .replace("<REVIEW_PACKAGE_PATH>", () => "$1/review.diff")
  .replace("<GLOBAL_CONSTRAINTS_PATH>", () => "$1/REQUIREMENTS.md");
const measured = fs.readFileSync("/Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/focus-treatment.txt", "utf8");
console.log(shipped === measured ? "line 53 matches the measured treatment" : "MISMATCH");
process.exit(shipped === measured ? 0 : 1);
'
```

Expected: `line 53 matches the measured treatment`.

- [ ] **Step 5: Run the gate suites**

Run each separately:
- `bash tests/codex-review-gate/test-gate-contract.sh`
- `bash tests/codex-review-gate/test-gate-split-lossless.sh`
- then every other `tests/codex-review-gate/test-*.sh`, one per command.

Expected: every suite exits 0. `test-gate-contract.sh` now passes the four new cap checks, and `test-gate-split-lossless.sh` rebuilds the gate from the edited TSV without loss.

- [ ] **Step 6: Prove the pin catches a cap repeated on one line**

The pin counts occurrences, not lines. Check that on a scratch copy, never on the worktree:

```bash
scratch="$(mktemp -d "${TMPDIR:-/tmp}/cap-pin-mutation.XXXXXX")"
cp -R skills tests "$scratch/"
python3 - "$scratch/skills/requesting-code-review/recipe-code.md" <<'EOF'
import pathlib
import sys
cap = "A defect reachable only through input that nothing in the code or its callers produces and that only the person running it could supply — a newline or invalid UTF-8 in a file or directory name, a name that starts with a dot — is medium, unless it also breaks the default path or corrupts stored data."
path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").split("\n")
assert lines[52].count(cap) == 1, lines[52].count(cap)
lines[52] = lines[52].replace(cap, cap + " " + cap)
path.write_text("\n".join(lines), encoding="utf-8")
EOF
bash "$scratch/tests/codex-review-gate/test-gate-contract.sh"; echo "exit $?"
rm -rf "${scratch:?}"
```

Expected: `exit 1` and `STATUS: FAILED (2 failure(s))`, with exactly these two failures; launches 2 and 3 pass:

```text
  [FAIL] all three code-review focus strings carry the pathological-input cap (found 4)
  [FAIL] code recipe launch 1 carries the cap once, right after the calibration (cap 2, after the calibration 1)
```

- [ ] **Step 7: Confirm the change set and stage**

```bash
git status --short
git diff --stat
```

Expected: only the three files. In `recipe-code.md` and the TSV, every changed line differs from its old version only by the inserted sentence and one space.

```bash
git add skills/requesting-code-review/recipe-code.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-contract.sh
```

Commit message: `feat(requesting-code-review): Codex rates a defect only hand-made input reaches as medium`.

---

### Task 7: Record the evidence, write the notes and run the offline suites

**Risk tier:** standard — controller-run, no implementer subagent: multi-file documentation of a measured result across both repositories, plus the offline suites. No script and no approval-authority code changes here.

**Repository:** both

**Files:**
- Create: evals `evidence/2026-10-03-review-calibration-and-sentinel-scope/README.md`
- Create: evals `docs/experiments/2026-10-03-review-calibration-and-sentinel-scope.md`
- Create: `docs/hyperpowers/2026-10-03-review-calibration-and-sentinel-scope-eval-evidence.md`
- Modify (win only): `CHANGELOG.md` (new section above `## 6.15.0 (2026-10-03)`)

**Interfaces:**
- Consumes: Task 4's evidence and decision; on the Win and Loss paths, Task 5's evidence and decision; on a win, Task 6's commit.
- Produces: the committed evidence and notes.

**Outcome paths.** Task 7 runs on exactly one of these, and every step below says what it writes on each:
- **Win:** Task 5's five lines all held, and Task 6 shipped the sentence.
- **Loss:** Task 5 ran and at least one line failed. Nothing ships.
- **Stop:** Task 4 reproduced no over-rating on P or on P2 under control, so Tasks 5 and 6 did not run. Nothing ships.
- An instrument stop (Task 4 Step 4's last paragraph) is none of these. Task 7 runs for it only if the human partner chooses, and then it is recorded as a Stop that names the instrument failure as its reason.

- [ ] **Step 1: Write the evidence README**

Mirror `evidence/2026-10-03-harness-confound-attribution/README.md`. Sections, in order:
- **Purpose:** Fix 1 of the spec, with the spec and plan paths and the plan's pre-registration commit id.
- **Instrument:** the runner's evals commit; the runtime record's six lines quoted from `task-4-runs/control-P/runtime-start.txt`; the three focus files with their sha256 values.
- **Fixtures:** one line each for M, H, O, P, Pc and P2, stating the defect each carries.
- **Layout:** each run directory and what it holds.
- **Results:**
  - Win or Loss: Task 5 Step 5's table, plus the Task 4 readings.
  - Stop: the Task 4 readings for P and P2, the line "Treatment did not run.", and no decision table. The result line reads, for example, "No over-rating reproduced on P or P2 under control; no sentence ships."
- **Voids and re-runs:** every `-rerun-` directory and the instrument failure it replaced, or "none".
- **Runtime records:** on Win or Loss, the Task 5 Step 3 check and its result; on Stop, the Task 4 Step 5 check and its result. Name every directory superseded by a `-runtime-rerun/` and the difference that superseded it, or write "none".
- **Deviations:** the seven from this plan, plus any that arose during execution.

- [ ] **Step 2: Write the experiment entry**

`docs/experiments/2026-10-03-review-calibration-and-sentinel-scope.md`, in the shape of `docs/experiments/2026-10-03-harness-confound-attribution.md`:
- **Question:** does the cap sentence move a pathological-input defect from blocking to medium, without moving a defect that corrupts stored data, an ordinary-input crash, an omitted requirement, or a clean diff?
- **Pre-registration:** the decision rule, quoted from this plan's Global Constraints, with the plan's commit id.
- **Config:** Codex model and effort from the runtime record; the companion version; three reviews per cell; the correctness-lens skeleton.
- **Results:** on Win or Loss, every cell for both arms, including Task 4's. On Stop, the Task 4 control cells only, with "treatment did not run" in place of the treatment column.
- **Limits:** the spec's "Known limits" (production shape, untested boundaries, one Codex model, three reviews per cell).
- **Files:** the evidence directory and the evals commits.

A loss or a stop is recorded at equal billing with a win (evals `CLAUDE.md`, "Experiment Log").

- [ ] **Step 3: Write the hyperpowers eval-evidence note**

`docs/hyperpowers/2026-10-03-review-calibration-and-sentinel-scope-eval-evidence.md`, modeled on Arm A of `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`:
- **Fix 1:** defect, sentence, method, fixtures, reviewer, decision rule, results, decision. Cite every capture through `evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/`.
  - Win: the results table and Task 6's commit id.
  - Loss: the results table and the failing line or lines.
  - Stop: the Task 4 readings, "treatment did not run", and the reason (no over-rating reproduced, or the instrument failure the human partner chose to record).
- **Fix 2 and Fix 3:** no live runs. Record the evals commit for Task 1, the hermeticity record, and the check results from Task 1 Step 5.
- **Deviations:** the seven from this plan.

- [ ] **Step 4: CHANGELOG (win only)**

Insert above `## 6.15.0 (2026-10-03)`, filling the per-fixture counts from Task 5 Step 5's table:

```markdown
## 6.16.0 (2026-10-03)

Codex blocked on defects that only hand-made input could reach.

- **Codex code reviews rate a defect only hand-made input reaches as medium.** The three adversarial-review focus strings in `requesting-code-review/recipe-code.md` gain one sentence after the severity calibration: a defect reachable only through input that nothing in the code or its callers produces, and that only the person running it could supply, is medium unless it also breaks the default path or corrupts stored data. Measured with direct Codex reviews, three per fixture per arm. Pathological input (P) blocked <control>/3 under control and <treatment>/3 with the sentence; the stored-data case (Pc) <c>/3 and <t>/3; an ordinary crash (H) <c>/3 and <t>/3; an omitted requirement (O) <c>/3 and <t>/3; the clean diff (M) was approved <c>/3 and <t>/3. Evidence: `docs/hyperpowers/2026-10-03-review-calibration-and-sentinel-scope-eval-evidence.md`.
```

Each `<c>` and `<t>` is that fixture's count from the table, blocking for P, Pc, H and O and approved for M. If P2 was the validated fixture, write "Pathological input (P2)". The release step re-dates the heading and bumps the version with `vrzn`; this step never edits a version string.

On the Loss and Stop paths, CHANGELOG is unchanged: nothing ships in the skills.

- [ ] **Step 5: Run the offline hyperpowers suites**

From the worktree, run the offline set that `docs/testing.md:51-57` defines, one suite per command:
- every `test-*.sh` outside `tests/claude-code/` and `tests/explicit-skill-requests/`, excluding `tests/opencode/test-tools.sh` and `tests/opencode/test-priority.sh`;
- the four offline `tests/claude-code/` suites named in that file's table;
- `npm test` in `tests/brainstorm-server/`;
- `windows-lifecycle.test.sh`;
- the Pi Node file.

Expected: all green. Two known issues are tracked as separate follow-ups and are not fixed here:
- `windows-lifecycle.test.sh` and `stop-server.sh` fail on `ps` under the sandbox. Re-run them unsandboxed after the sandbox failure.
- The brainstorm-server tests leave orphan server processes. Note any you see, but do not kill processes this plan did not start.

Report every suite's result. Never run the live suites.

- [ ] **Step 6: Commit the evals evidence and docs**

Run the evals checks first, each as its own command, from `/Users/johnss51/Development/agents/hyperpowers/evals`: `bun run check`, then `bun run quorum check`. Expected as in Global Constraints, "Evals checks": 1295 pass and 0 fail unsandboxed (after the two known sandbox EPERM failures), and `quorum check` passing. Any other result: do not stage; report it.

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals add evidence/2026-10-03-review-calibration-and-sentinel-scope docs/experiments/2026-10-03-review-calibration-and-sentinel-scope.md
git -C /Users/johnss51/Development/agents/hyperpowers/evals status --short
git -C /Users/johnss51/Development/agents/hyperpowers/evals diff --cached | /usr/bin/grep -F -e "${HTTPS_PROXY#*://}" -e "$NO_PROXY" -e "$ANTHROPIC_VERTEX_PROJECT_ID"; echo "grep exit $?"
```

Expected: only the evidence directory and the experiment entry are staged; `grep exit 1`. Show the human partner the staged diff and ask, then commit with `evidence(review-calibration-and-sentinel-scope): <one-line result>`. The result line is the decision: on a win, for example, "the cap holds P at medium and keeps Pc, H and O blocking"; on a loss, the failing line; on a stop, "no over-rating reproduced on P or P2 under control".

- [ ] **Step 7: Commit the hyperpowers note (and CHANGELOG on a win)**

```bash
git add docs/hyperpowers/2026-10-03-review-calibration-and-sentinel-scope-eval-evidence.md
git status --short
```

On a win, also stage `CHANGELOG.md`. Show the human partner the diff, ask, and commit with `docs: eval evidence for the review calibration and sentinel scope fixes`. Nothing is pushed.

**Correction (2026-10-04).** Task 1's per-task Codex gate (round 1) found four defects in the evals `docs/scenario-authoring.md` text that Task 1 Step 2 mandates, and the human partner ruled on them. Evals `93777fbbf` departs from Step 2's text in three places, and Task 1's checks are read against the corrected text:

- The hermeticity recipe under "Harness labels" runs inside `if git diff --quiet <commit> HEAD -- package.json bun.lock; then … else … fi`, removes its scratch directory and prints `# Result: exit <rc>`. As Step 2 wrote it, a dependency mismatch did not stop the test run, so a pass could certify `clean` from another commit's dependencies.
- Comparability matches "the models" where Step 2 said "the model": the Gauntlet-Agent model (`economics.gauntlet.model` in each run's `verdict.json`) and every model the Coding-Agent ran, subagents included (`economics.coding_agent.models`). The grader judges part of the amended criterion, and provisioning writes the host's alias pins (`ANTHROPIC_DEFAULT_*`) into each run's `.claude-env` after the launcher drops inherited `ANTHROPIC*` variables, so a `clean` label does not fix a subagent's model. The table's model cells name the grader, step 2 records "the models" and an evals commit "clean at launch", and the paragraph after the table lists the models among what every row records.
- The evals-harness bullet requires the failing run's evals commit, and a clean `git status` for the compared paths when it launched, to be on record. `quorum run` records neither, so a failing run without that record has no comparable row. Row 3's record is the mutation check in its evidence README.

The models were read from each row's `verdict.json` files: rows 1 and 2 are `claude-opus-5` for both in 20 of 20 runs, row 3 is `claude-opus-5-5` for both in 10 of 10. Step 4's table check is unchanged and still passes, because the header still starts `| scenario | model |`.

**Correction (2026-10-04).** Task 1's per-task Codex gate (round 2) found the guard in the correction above incomplete, and the human partner ruled on it. `git diff --quiet <commit> HEAD -- package.json bun.lock` compares two commits, so uncommitted edits to the checkout's `package.json` or `bun.lock`, whose `node_modules` the recipe links, pass it. Evals `81b24c0b1` runs the recipe inside `if git diff --quiet <commit> -- package.json bun.lock; then … else … fi`, which compares the commit with the working tree, and its else message names the checkout. The rest of the correction above stands.

**Correction (2026-10-04).** Task 1's per-task Codex gate (round 3) found that the recipe exited 0 when its tests failed and when it ran nothing, because both branches ended with a successful `echo`. Evals `9a53cb272` ends the then branch with `[ "$rc" -eq 0 ]` and the else branch with `false`, so the recipe exits 0 only when the tests ran and passed, and it still prints `# Result: exit <rc>`. The corrections above stand.

**Correction (2026-10-04).** Task 1's per-task Codex gate (round 4) found that comparability pinned the evals code and the models but not Gauntlet, which quorum spawns from `PATH` and which drives and grades every run, and the human partner ruled on it. Evals `ed220c9cc` treats the Gauntlet identity like the Claude Code version: step 2 records it, a row added after row 3 records the commit of the Gauntlet checkout that the `gauntlet` on `PATH` runs and whether its tracked files were clean at launch, and a regression call against a row at another or an unrecorded Gauntlet identity names it as a second difference. It is not part of the match, so row 3 stays comparable; its Gauntlet commit, `a35607e`, comes from the checkout's reflog, and whether its tracked files were clean at launch is not on record. Making the identity a match condition was considered and not chosen: row 3 has no launch-time record, so it would stop being a base rate over a checkout whose HEAD has not moved since 2026-07-10. Step 4's table check is unchanged. The corrections above stand.

**Correction (2026-10-04).** Task 7's per-task Codex gate (round 1) found two gaps in the evidence, and the human partner ruled on both. First, Step 5 expects the offline suites all green, and the note reported them without a record of each suite's result. The human partner waived "all green" for this plan and read Step 5 as "report every suite's result". Evals `da58801a5` commits `task-7-offline-suites.txt` to the evidence directory: one row per suite from one complete pass at `5ee2ee0`, each suite run as its own command, with the logs and a file-watcher probe under `task-7-runs/`. 46 of 48 suites exit 0. The two that fail, the brainstorm server's `server.test.js` (5 of 33) and `lifecycle.test.js` (1 of 13), write a file, wait a fixed time, and assert on what the server's `fs.watch` callback did. The probe shows this host delivering those events late, under another file's name, or not at all, and `server.test.js` failed 6, 6, 7, 3 and 5 of 33 across this task's passes. The branch changes nothing under `skills`, `tests`, `hooks` or `scripts`, so these are main's results on this host. `npm test` chains its nine files with `&&` and stops at the first failure, so the pass ran each file separately. Making those tests tolerate a slow watcher is a separate follow-up and is not done here. Second, a capture records the base commit Codex reviewed but not the head, the diff or the prompt. The same evals commit adds `base-provenance.py`, which rebuilds both control runs' bases from the fixture files committed in `fd1b5c701` and reproduces each captured base. The head, the diff and the prompt can be rebuilt from `fd1b5c701` but are not on record. Re-running the controls with a runner that records them was considered and not chosen. The corrections above stand.

**Correction (2026-10-05).** The leak grep in Global Constraints and in Task 1 Step 6, Task 2 Step 5 and Task 3 Step 5 builds its needles from the shell's own `HTTPS_PROXY`, `NO_PROXY` and `ANTHROPIC_VERTEX_PROJECT_ID`. Inside the Bash sandbox those variables hold the sandbox proxy's values, not the host's, so a grep run there scanned for the wrong strings. The evidence note records that every staged diff was also scanned for the host's values by a counts-only scanner, which found nothing. The scanner now lives at `~/.claude/scripts/realval-scan.py` and reads its needles from the settings env block; plans written after this date name it instead of the shell variables.
