# Gate Calibration (Part 2 of 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-09-05-gate-churn-and-skill-hardening-design.md`

**Goal:** Cut Codex gate rounds-to-convergence by fixing the prompt language that makes every re-review a cold re-derivation, and land the two upstream prose ports, each with fork-side before/after evidence.

**Architecture:** Twelve tasks, numbered 0 to 11. Task 0 lands the Part 1 follow-ups the 6.13.0 Codex sweep found (a testing guide that hid two suites, a churn test that never asserted the fleet aggregate, a review-base default that truncates multi-commit ranges) and gives `gate-telemetry` a `--since` bound. Task 1 records the baselines. Tasks 2-5 are the gate arms, each a small prose or script change with its own eval scenario, control runs, and treatment runs. Task 6 gives approved-with-notes verdicts a required path for their notes. Tasks 7-8 are upstream prose ports and Task 9 is the arm that gives 6.13.0's two shipped routing edits their before/after evidence, all with fork-side runs. Task 10 measures the lens count; Task 11 releases. Arms run strictly one at a time because they all move the same metric. An arm that does not beat its control is reverted, and the negative result is recorded rather than buried.

**Tech Stack:** Markdown skill prose, Bash, Node.js. Evals run on Quorum (TypeScript, Bun) in the separate `hyperpowers-evals` clone at `evals/`.

## Global Constraints

- **Part 1 must be released and merged before Task 1 runs.** Part 1's `verdict-normalize` fix changes round-1 convergence on its own. Measuring an arm against a pre-Part-1 control would credit this plan with Part 1's effect. Confirm `git merge-base --is-ancestor v6.13.0 HEAD` succeeds before starting — a tag that merely exists proves nothing about the tree you are measuring.
- **One arm at a time.** Tasks 2 through 5 all move rounds-to-convergence. Do not start an arm's control runs while another arm's change is uncommitted in the tree.
- **An arm that loses is reverted, not kept.** "No measurable difference" is a losing result for a change to tuned prose. Record it in the evidence note and restore the file with `git show HEAD:<path> > <path>`.
- **Live eval runs are trusted-maintainer operations.** They spend real API credit and launch agents in dangerous mode. Never add live evals, API keys, or dangerous-mode launches to public CI.
- **Scenario work is committed in the evals repo, never here.** `evals/` is a separate clone of `hyperpowers-evals`, gitignored in this repository. Commit each scenario there, in its own commit, before the run that uses it.
- **Every new scenario's `story.md` frontmatter needs `status: ready` and `quorum_tier: full`.** A scenario left at `status: draft` is skipped by `quorum run-all` unless `--include-drafts` is passed, so a draft scenario silently produces no runs and an arm looks unmeasured. Sixty-eight of the clone's sixty-nine scenarios are `ready`; match them.
- Zero new third-party dependencies in this repository.
- No emojis in code, documentation, commit messages, or reports.
- No `Co-Authored-By` lines and no text implying AI-generated assistance.
- Never run `git reset --hard`, `git clean`, `git checkout -- <path>`, or any force-push. Restore a tracked file with `git show HEAD:<path> > <path>`.
- Do not push. Committing is expected; pushing is a separate instruction from the human partner.
- Version bumps use `vrzn`. Never hand-edit a version string.
- This repository commits its `docs/hyperpowers/` specs, plans, and eval-evidence notes.

### The losslessness bookkeeping every gate-file edit needs

Four tasks edit a gate section file. Those nine files are covered by a byte-identity proof that reconstructs the pre-split `codex-review-gate.md` from declared tables, so an edit that skips the bookkeeping fails `tests/codex-review-gate/test-gate-split-lossless.sh`. The recipe, once, here:

1. **One line in, one line out.** A replacement rewrites exactly one line. You may make a line arbitrarily long, but you may not insert a line, delete one, or split one in two. Every prose change in this plan is designed around that.
2. **Add a row to `tests/codex-review-gate/gate-post-split-edits.tsv`**, tab-separated, three fields: the source line number in the pinned original, a short kebab-case reason, and the complete replacement line.
3. **Use the source line numbers given in each task.** They were verified against the pinned original `9242d4f6bdcdbf373548a8197b515a2e309de03b` by comparing the section file's line to the original's line byte-for-byte. Do not recompute them from a manifest offset.
4. **A replacement may contain no tab and no backslash.** Both tables are substituted through `awk -v`, which reinterprets backslash escapes identically on each side of the proof, so a mangled replacement would pass unnoticed.
5. **A replacement may not introduce the words "below" or "above".** The positional-reference candidate set was frozen at the pinned SHA; a new positional reference is a pointer no check validates and the references table structurally cannot host one.
6. **Bump the pinned edit count from what the file says now, never from a number in this plan.** `test-gate-split-lossless.sh` asserts `[ "$post_edit_count" -eq N ]` and repeats N in two message strings. In every task that adds rows: read the current N first (`grep -n 'post_edit_count" -eq' tests/codex-review-gate/test-gate-split-lossless.sh`), then set all three occurrences to N plus the number of rows that task appended. A reverted arm restores the previous N, so the sequence a task will see depends on which earlier arms won; a literal copied from a plan would be wrong on every path but one.
7. **Do not target a referent line.** The proof pins at exactly 2 the number of post-split edits landing on a line the references table points at. The referent lines are 156, 177, 188, 203, 225, 233, 280, 357, 443, 450, 615, 645, 648. None of this plan's targets is among them; keep it that way.

---

### Task 0: Part 1 follow-ups from the 6.13.0 Codex sweep

**Risk tier:** standard — three mechanical corrections and one read-only reporter flag, all offline-testable; `gate-telemetry` is a reporter, not approval authority.

**Files:**
- Modify: `docs/testing.md` (the "Plugin tests" section)
- Modify: `skills/requesting-code-review/SKILL.md:27-30` (the `BASE_SHA` block)
- Modify: `tests/codex-review-gate/test-gate-topology.sh` (one regression assertion)
- Modify: `skills/requesting-code-review/scripts/gate-telemetry` (`--since`; churn ignores non-numeric rounds)
- Modify: `tests/codex-review-gate/test-gate-telemetry.sh` (fleet churn assertion, malformed-round case, `--since` cases)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `gate-telemetry --since <ISO-8601>`, which drops every gate run whose run directory is older than the timestamp; usable with or without `--all`; a non-ISO value exits 2. Task 1 reads the post-release cohort through it. `churn()` now ignores non-numeric round records instead of counting them as 0.

**Context the implementer needs.** The Codex sweep of release 6.13.0 (gate `run-vTvF2CDw`, three lenses at xhigh) found four things Part 1 left standing, and the final Claude review had deferred a fifth. (1) `docs/testing.md` says every suite is a standalone bash script and offers a loop that echoes on failure and exits 0; `tests/brainstorm-server` runs through `npm test` and `tests/pi` is a Node file, and both were missing from the release's "36 suites green" evidence. (2) The churn test asserts `repos[0].byGate.task` although Task 13 required `aggregate.byGate.task`, and its markdown check scans the whole `--all` output. (3) `requesting-code-review`'s primary `BASE_SHA` example is still `HEAD~1`, which keeps one commit of a multi-commit change; Part 1 fixed only the alternative. (4) `churn()` coerces a malformed round to 0, which biases the mean this plan measures against. (5) Task 1 needs a way to read a post-release cohort without the history before it.

- [ ] **Step 1: Write the failing tests**

Append the following to `tests/codex-review-gate/test-gate-topology.sh`, immediately before its final status block:

```bash
# The default review base must never be HEAD~1: it silently truncates a
# multi-commit change to its last commit (6.13.0 sweep finding).
if grep -q 'git rev-parse HEAD~1' "$REPO_ROOT/skills/requesting-code-review/SKILL.md"; then
    fail "requesting-code-review offers HEAD~1 as a review base"
else
    pass "requesting-code-review never offers HEAD~1 as a review base"
fi
```

Append the following to `tests/codex-review-gate/test-gate-telemetry.sh`, after the existing churn block and immediately before the final status line. The fixture state at that point is: key `$key` holds one task run at round 2, key2 holds one spec run, and `$cr3` (the churn repo) holds task runs at rounds 1, 1, 3, 3.

```bash
# Fleet churn: the aggregate must carry the derived fields, computed over every
# repository's rounds — task rounds here are [2] (key) and [1,1,3,3] (key3).
fleetjs="$(bash "$GT" --json --all)"
node -e 'const d=JSON.parse(process.argv[1]);const g=d.aggregate.byGate.task;process.exit(g.meanRounds===2&&g.firstRound===2&&g.runs===5?0:1)' "$fleetjs" && pass "fleet churn: aggregate meanRounds=2, firstRound=2 over 5 runs" || fail "fleet churn: aggregate meanRounds=2, firstRound=2 over 5 runs"
fleetmd="$(bash "$GT" --all | sed -n '/Fleet aggregate/,$p')"
expect "$fleetmd" "task: mean 2, first-round 2/5" "fleet markdown churn line, fleet section only"

# A malformed round record is excluded from the mean, not counted as 0.
mkdir -p "$cr3/run-bad"
printf '{"round":"x","ceiling":5,"gate":"task"}\n' > "$cr3/run-bad/gate-round.json"
badjs="$(bash "$GT" "$churnrepo" --json)"
node -e 'const d=JSON.parse(process.argv[1]);const g=d.repos[0].byGate.task;process.exit(g.meanRounds===2&&g.runs===5?0:1)' "$badjs" && pass "churn ignores a non-numeric round" || fail "churn ignores a non-numeric round"

# --since bounds the cohort by run-directory mtime and rejects non-ISO input.
touch -t 202001010000 "$cr3/run-r1a" "$cr3/run-r1b"
sincejs="$(bash "$GT" --since 2025-01-01T00:00:00Z "$churnrepo" --json)"
node -e 'const d=JSON.parse(process.argv[1]);const g=d.repos[0].byGate.task;process.exit(g.runs===3&&g.meanRounds===3?0:1)' "$sincejs" && pass "--since drops runs older than the timestamp" || fail "--since drops runs older than the timestamp"
bash "$GT" --since not-a-date "$churnrepo" >/dev/null 2>&1 && fail "--since rejects a non-ISO value" || pass "--since rejects a non-ISO value"
```

- [ ] **Step 2: Run both suites to verify they fail**

Run: `bash tests/codex-review-gate/test-gate-topology.sh`

Expected: FAIL on `requesting-code-review offers HEAD~1 as a review base`.

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh`

Expected: FAIL on `churn ignores a non-numeric round` (today the mean is 1.6), on `--since drops runs older than the timestamp` (unknown flag exits 2, so the JSON parse fails), and on `--since rejects a non-ISO value` (the unknown flag exits 2 for the wrong reason — that case passes vacuously today; note it and move on). The two fleet assertions pass already: Part 1 attached the churn fields to the aggregate; the sweep found only that nothing asserted it. They are the fence.

- [ ] **Step 3: Fix the review-base default**

In `skills/requesting-code-review/SKILL.md`, replace the two-line block

```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or: git merge-base origin/main HEAD
HEAD_SHA=$(git rev-parse HEAD)
```

with:

```bash
# A task-scoped review starts at the commit recorded before the work began.
# Never HEAD~1: it keeps only the last commit of a multi-commit change.
BASE_SHA=<the pre-change commit you recorded>
# A whole-branch review starts at the branch point.
BASE_SHA=$(git merge-base origin/main HEAD)
HEAD_SHA=$(git rev-parse HEAD)
```

- [ ] **Step 4: Add `--since` and harden `churn()`**

In `skills/requesting-code-review/scripts/gate-telemetry` make exactly these edits. The JavaScript lives inside a single-quoted `node -e` string, so no apostrophe may appear in anything you add.

Header, line 2:

```
# gate-telemetry [--json] [--all] [--since ISO-8601] [repo-dir] — read-only aggregation over
```

After the header comment block (line 6), add:

```
# --since drops gate runs whose run directory is older than the timestamp, so
# a post-release cohort can be read without the history it follows.
```

Replace `json=0; all=0; repo="."` with `json=0; all=0; since=""; repo="."` and add this case to the argument loop, before the `-*)` case:

```bash
    --since) since="$2"; shift 2 ;;
```

Replace the node argv line at the end of the script, `' "$base" "$json" "${keys[@]}"`, with `' "$base" "$json" "$since" "${keys[@]}"`.

Replace `const [base, jsonOut, ...keys] = process.argv.slice(1);` with:

```js
  const [base, jsonOut, since, ...keys] = process.argv.slice(1);
  // --since bounds the cohort by run-directory mtime; an unparseable value is
  // a usage error, never a silent no-op.
  const sinceMs = since ? Date.parse(since) : NaN;
  if (since && !Number.isFinite(sinceMs)) { console.error("gate-telemetry: --since must be an ISO-8601 timestamp"); process.exit(2); }
```

Replace the whole `churn` helper with:

```js
  const churn = (rounds) => {
    // A malformed round record is excluded, not counted as 0: this plan
    // measures against these values.
    const nums = rounds.map(Number).filter(Number.isFinite);
    const n = nums.length;
    if (!n) return { meanRounds: null, firstRound: 0 };
    const sum = nums.reduce((a, b) => a + b, 0);
    return {
      meanRounds: Math.round((sum / n) * 100) / 100,
      firstRound: nums.filter((r) => r === 1).length,
    };
  };
```

In the run walk, immediately after the line `if (!fs.statSync(path.join(cr, run)).isDirectory()) continue;`, insert:

```js
      if (Number.isFinite(sinceMs) && fs.statSync(path.join(cr, run)).mtimeMs < sinceMs) continue;
```

- [ ] **Step 5: Run both suites to verify they pass**

Run: `bash tests/codex-review-gate/test-gate-topology.sh` and `bash tests/codex-review-gate/test-gate-telemetry.sh`

Expected: `STATUS: PASSED` and `ALL PASS`.

- [ ] **Step 6: Rewrite the testing guide's Plugin tests section**

In `docs/testing.md`, replace everything from the line `Every suite is a standalone bash script. There is no aggregate runner and no` through the line `part of any automated run.` (the end of the "Plugin tests" section; `## Skill behavior evals` follows) with the text between the tilde fences, exactly:

~~~markdown
Most suites are standalone bash scripts; two directories are not. There is no
aggregate runner and no CI; run the suites that cover what you changed.

| Directory | Covers | Runner |
|---|---|---|
| `tests/hooks/` | session-start context injection, the ungated notice, the Codex broker janitor, the hooks heredoc fence | `bash tests/hooks/test-*.sh` |
| `tests/codex-review-gate/` | gate scripts (`verdict-normalize`, `gate-round`, `gate-telemetry`, `ungated-ledger`, preflight, broker health), gate topology, and the gate-split losslessness proof | `bash tests/codex-review-gate/test-*.sh` |
| `tests/sdd/` | the subagent-driven-development contract | `bash tests/sdd/test-sdd-contract.sh` |
| `tests/claude-code/` | offline: SDD scratch-dir derivation, helper stdout and range guards, delivery resolution, worktree path policy; live: skill tests that spawn the real `claude` CLI | offline: `test-sdd-dir-path.sh`, `test-codex-review-dir-path.sh`, `test-delivery-resolution.sh`, `test-worktree-path-policy.sh` with `bash`; live: `run-skill-tests.sh` |
| `tests/packaging/` | manifest wiring and the orphaned-skill-file guard | `bash tests/packaging/test-*.sh` |
| `tests/brainstorm-server/` | the brainstorm server: JavaScript unit tests plus the start/stop and Windows-lifecycle shell tests | `cd tests/brainstorm-server && npm test` |
| `tests/pi/` | the Pi extension | `node tests/pi/test-pi-extension.mjs` |
| `tests/opencode/`, `tests/kimi/`, `tests/antigravity/` | per-harness plugin loading, bootstrap caching, tool registration | each directory's `run-tests.sh` |
| `tests/writing-skills/`, `tests/systematic-debugging/` | skill-specific structural checks | `bash tests/<dir>/test-*.sh` |
| `tests/explicit-skill-requests/` | Haiku-specific, multi-turn, and skill-name-prompted behavior (live) | `tests/explicit-skill-requests/run-all.sh` |
| `tests/shell-lint/` | shellcheck over the repo's shell scripts | `bash tests/shell-lint/test-lint-shell.sh` |

Run one suite directly:

```bash
bash tests/codex-review-gate/test-verdict-normalize.sh
```

Run a directory's worth and fail if any suite fails. A loop that only echoes on
failure exits 0 and reads as green:

```bash
fails=0
for t in tests/hooks/test-*.sh; do bash "$t" || { echo "FAILED: $t"; fails=$((fails + 1)); }; done
[ "$fails" -eq 0 ]
```

The offline set is every `test-*.sh` outside `tests/claude-code/` and
`tests/explicit-skill-requests/`, the four offline `tests/claude-code/` suites
named in the table, `npm test` in `tests/brainstorm-server/`, and the Pi Node
file. The live suites spawn the real `claude` CLI: they need credentials, take
minutes, and are not part of any automated run.
~~~

- [ ] **Step 7: Verify the guide and run the two non-bash suites it now names**

Run: `grep -n 'Every suite is a standalone bash script' docs/testing.md || echo "false claim removed"`

Expected: `false claim removed`.

Run: `( cd tests/brainstorm-server && npm test ) 2>&1 | tail -3` and `node tests/pi/test-pi-extension.mjs 2>&1 | tail -3`

Expected: both green (on 6.13.0 they were: 7 and 4 shell-side passes plus the JS files, and Pi 6/6). Record the tail lines in your report.

- [ ] **Step 8: Commit**

```bash
git add docs/testing.md skills/requesting-code-review/SKILL.md skills/requesting-code-review/scripts/gate-telemetry tests/codex-review-gate/test-gate-topology.sh tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "fix(review): the 6.13.0 sweep found a guide that hid two suites, a fleet metric nothing asserted, and a base default that truncates reviews"
```

---

### Task 1: Establish the post-Part-1 baseline

**Risk tier:** standard — no code changes, but every later task's verdict is measured against the numbers this task records.

**Files:**
- Create: `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`

**Interfaces:**
- Consumes: Part 1's released `gate-telemetry` with churn metrics, Task 0's `--since` flag, and Part 1's `verdict-normalize` fix.
- Produces: the evidence note that every later task appends a section to. Its "Baselines" section holds two lines: the historical fleet figures (every cached run predates 6.13.0) and the post-release cohort read through `--since`, which is expected to be small or empty when this task runs and is re-read at release. Arm verdicts rest on each arm's own control and treatment runs, never on these fleet lines.

**Context the implementer needs.** The 2026-09-05 analysis measured task gates at mean 2.24 rounds with 27% converging in round 1, over 468 runs. Every run in the telemetry cache still predates 6.13.0, so an unbounded `gate-telemetry --all` reports exactly that pre-fix history and must not be labeled a post-fix baseline (the 6.13.0 sweep flagged precisely this). This task records the history as history, reads the post-release cohort through `--since` (bounded at the release commit's timestamp), and states plainly that the arms are judged by their own control and treatment runs.

- [ ] **Step 1: Confirm Part 1 shipped and is in this tree**

```bash
git merge-base --is-ancestor v6.13.0 HEAD && echo "v6.13.0 is an ancestor of HEAD"
grep '"version"' .claude-plugin/plugin.json
```

Expected: the echo line, and a version of 6.13.0 or later. If either fails, STOP. This plan's measurements are invalid on a tree that does not contain the release.

- [ ] **Step 2: Read both baselines from the shipped tool**

```bash
bash skills/requesting-code-review/scripts/gate-telemetry --all
```

Copy the fleet aggregate's `Rounds by gate` line verbatim; this is the historical line, and every run behind it predates the release. Then read the post-release cohort, bounded at the release commit:

```bash
since="$(git log -1 --format=%cI v6.13.0)"
bash skills/requesting-code-review/scripts/gate-telemetry --all --since "$since"
```

Copy that fleet `Rounds by gate` line too, with the `$since` value. Expect it to be nearly empty: real post-release gate runs accrue only as this plan and later work run. That emptiness is the honest state, not a defect.

- [ ] **Step 3: Verify the eval harness is green**

```bash
cd evals && bun run check
```

Expected: the Biome, TypeScript, and Bun test gate all pass. Then:

```bash
cd evals && bun run quorum check
```

Expected: every scenario directory validates. If either fails, fix the evals clone before proceeding; a broken harness cannot produce trustworthy control runs.

- [ ] **Step 4: Confirm the evals clone is current**

```bash
git -C evals status --short
git -C evals log --oneline -3
```

Expected: a clean tree. Uncommitted scenario work from an earlier session would contaminate the runs.

- [ ] **Step 5: Write the evidence note**

Create `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`. Follow the structure of `docs/hyperpowers/2026-08-28-decision-brief-before-selector-eval-evidence.md`: a title, a `Date:` line, a `Skills changed:` line, a `Scenario:` line, then the argument. Write these sections now and leave the arm sections for later tasks to append:

```markdown
# Gate Calibration — Eval Evidence

Date: 2026-09-05
Skills changed: recorded per arm; see each section.
Scenarios: recorded per arm; see each section (evals repo).

## Why this note has arms

The four gate changes in this plan all move one metric — Codex rounds to
convergence — so a single run cannot attribute a movement to a cause. Each
arm ships alone, against the same baseline, with its own scenario.

## Baselines

Historical fleet (every cached run predates 6.13.0):
<paste the unbounded gate-telemetry fleet "Rounds by gate" line here>

Post-release cohort (gate-telemetry --all --since <the release commit's %cI timestamp>, read <today's date>):
<paste the bounded fleet "Rounds by gate" line here, or "empty" if no run has landed yet>

The historical line is context, not a control: it is the number Part 1 set
out to move. The post-release cohort is re-read at release so the note
carries the fleet state after this plan's arms shipped. Each arm's verdict
rests on its own control and treatment runs, recorded in its section.

## Arms
```

- [ ] **Step 6: Commit**

```bash
git add docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "docs(evals): record the historical fleet churn and the empty post-6.13.0 cohort the calibration arms are judged beside"
```

---

### Task 2: Arm A — severity calibration in the code-gate focus text

**Risk tier:** standard — behavior-shaping prose in a gate section file, with losslessness bookkeeping.

**Files:**
- Modify: `skills/requesting-code-review/recipe-code.md:53`
- Modify: `skills/requesting-code-review/recipe-code.md:57`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (two new rows)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 2)
- Create (evals repo): `evals/scenarios/codex-gate-severity-calibration/`

**Interfaces:**
- Consumes: Task 1's baseline note.
- Produces: an appended `### Arm A` section in the evidence note. No callable interface.

**Context the implementer needs.** codex-plugin-cc's `prompts/adversarial-review.md` wraps our focus text in a template that says "Use `approve` only if you cannot support any substantive adversarial finding" and "Prefer one strong finding over several weak ones." Its schema enumerates severity as critical, high, medium, or low, but never defines them. The reviewer therefore picks a severity with no scope anchor, and 30% of task-gate blocking captures carried nothing critical or high.

That template is a plugin file a future codex-plugin-cc version overwrites, so the calibration cannot live there. The focus string is the only durable channel we own. Part 1 already fixed the downstream consequence — a needs-attention with only medium and low findings now normalizes to approved. This arm attacks the upstream cause: telling the reviewer what the severities mean in this diff's scope.

- [ ] **Step 1: Write the scenario**

In the evals clone, create `evals/scenarios/codex-gate-severity-calibration/` with `setup.sh`, `checks.sh`, and `story.md`, following the shape of `evals/scenarios/codex-gate-lens-fanout-compliance/`. The scenario must:

- Pre-stage a completed SDD task exactly as the fan-out scenario does: a task brief, an implementer report, a review package, a committed diff, and a stub Codex install seeded into the agent's plugin home.
- Plant, in the diff, exactly one genuine medium-severity issue and no critical or high one. A well-named candidate: a new branch with no covering test, where the task brief's requirements do not name that test as a deliverable.
- Assert in `post()` that the launched focus string carries the severity definition, by grepping the recorded launch for the phrase `Severity is scoped to this diff`.
- Assert in `post()` that the gate converged in one round: `gate-round.json` has `round: 1` and the gate's normalized verdict is `approved`.
- Put the judgment calls in the story's Acceptance Criteria: that the reviewer classified the untested path as medium rather than high, and that the agent did not open a fix round for it.
- Restrict to Claude-family agents with the `# coding-agents:` comment, since the gate is Claude Code only.

Then create a **second** scenario, `codex-gate-severity-calibration-still-blocks`,
as a near-copy of the first with one difference: the planted defect is a genuine
high-severity one — a null dereference on a reachable path in the changed lines —
and `post()` asserts the gate **blocked**. This is not an arm. It is the guard
that the calibration teaches the reviewer to scope severity rather than to
under-report it, and the spec's success criterion for this arm is two-sided: a
drop in rounds *without* a drop in real findings caught. It must pass in both the
control and the treatment.

Validate both:

```bash
cd evals && bun run quorum check codex-gate-severity-calibration
```

```bash
cd evals && bun run quorum check codex-gate-severity-calibration-still-blocks
```

- [ ] **Step 2: Commit the scenario in the evals repo**

```bash
git -C evals add scenarios/codex-gate-severity-calibration scenarios/codex-gate-severity-calibration-still-blocks
git -C evals commit -m "scenario: the code gate blocks on a medium finding when severity has no scope anchor"
```

- [ ] **Step 3: Run the control**

With this repository's tree unmodified, run the scenario three times:

```bash
cd evals && bun run quorum run scenarios/codex-gate-severity-calibration --coding-agent claude
```

Record each run's pass or fail and the round count. Expected: the control fails, because nothing tells the reviewer that an untested path is medium.

Then run the guard scenario three times:

```bash
cd evals && bun run quorum run scenarios/codex-gate-severity-calibration-still-blocks --coding-agent claude
```

Expected: the control passes all three. A reviewer with no calibration already blocks on a real high-severity defect. If the guard fails in the control, the scenario is miscalibrated — fix it before measuring anything, because a guard that fails without the change cannot detect harm from the change.

If the control PASSES on all three runs, STOP and report. The defect does not reproduce, the change has no evidence behind it, and per this repository's rules it must not ship. Record the null result in the evidence note and skip to the next task; the scenario stays committed in the evals repo, because a null result is evidence too; the scenario stays committed in the evals repo, because a null result is evidence too.

- [ ] **Step 4: Add the calibration to the focus text**

In `skills/requesting-code-review/recipe-code.md`, replace line 53 in full with this single line:

```
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Task-scoped review. Requirements: <TASK_BRIEF_PATH>. Implementer report: <IMPLEMENTER_REPORT_PATH>. Review package: <REVIEW_PACKAGE_PATH>. Global constraints: <GLOBAL_CONSTRAINTS_PATH>. Review for task compliance and code quality. Severity is scoped to this diff: critical or high means a defect in the changed lines that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

Then replace line 57 in full with:

```
dispatched. Apart from the severity calibration, the focus text stays short because the task brief, implementer
```

- [ ] **Step 5: Add the two losslessness rows**

Each row is three tab-separated fields: the source line number in the pinned
original, the reason, and the complete replacement line. Do not retype the replacement line. Extract it from the file you just
edited, so the table's copy is byte-identical to the file's by construction —
a single drifted character fails the proof.

```bash
printf '%s\t%s\t%s\n' 326 severity-calibration "$(sed -n '53p' skills/requesting-code-review/recipe-code.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
printf '%s\t%s\t%s\n' 330 severity-calibration "$(sed -n '57p' skills/requesting-code-review/recipe-code.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

Confirm both rows landed with exactly two tabs each:

```bash
tail -2 tests/codex-review-gate/gate-post-split-edits.tsv | awk -F'\t' '{print NF, $1, $2}'
```

Expected: `3 326 severity-calibration` and `3 330 severity-calibration`.

- [ ] **Step 6: Bump the pinned edit count**

Read the current pin: `grep -n 'post_edit_count" -eq' tests/codex-review-gate/test-gate-split-lossless.sh`. Call it N. This task appended two rows, so set the `-eq N` test and both adjacent `exactly N declared post-split edits` message strings to N plus 2. Do not copy a number from this plan: N is 10 only if no earlier task has added rows.

- [ ] **Step 7: Prove the edit is lossless**

```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
```

Expected: `STATUS: PASSED` with 28 PASS and 0 SKIP.

```bash
bash tests/codex-review-gate/test-gate-contract.sh
```

Expected: `STATUS: PASSED`.

- [ ] **Step 8: Run the treatment**

Run both scenarios three times each against the modified tree:

```bash
cd evals && bun run quorum run scenarios/codex-gate-severity-calibration --coding-agent claude
```

```bash
cd evals && bun run quorum run scenarios/codex-gate-severity-calibration-still-blocks --coding-agent claude
```

Record each run's pass or fail and round count.

**Decision rule, both sides required.** The arm wins only if the calibration scenario passes at least 2 of 3 while its control passed at most 1 of 3, AND the guard scenario passes all 3 treatment runs. A guard failure means the calibration bought fewer rounds by suppressing real findings, which is a worse outcome than the defect. Treat it as a loss and revert.

- [ ] **Step 9: If the arm lost, revert it**

```bash
git show HEAD:skills/requesting-code-review/recipe-code.md > skills/requesting-code-review/recipe-code.md
git show HEAD:tests/codex-review-gate/gate-post-split-edits.tsv > tests/codex-review-gate/gate-post-split-edits.tsv
git show HEAD:tests/codex-review-gate/test-gate-split-lossless.sh > tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
```

Then write the losing result into the evidence note and skip to Step 11. A reverted arm still gets its section: a measured null is the evidence that stops someone re-proposing it.

- [ ] **Step 10: Append the evidence section**

Add an `### Arm A — severity calibration in the focus text` section to `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` recording: the defect and why the calibration cannot live in codex-plugin-cc's template, both scenario names, the control results run by run for each, the treatment results run by run for each, and the verdict against both sides of the decision rule. State the guard's numbers explicitly even when they are a clean 3 of 3 — an unstated guard is indistinguishable from an unrun one.

- [ ] **Step 11: Commit**

```bash
git add skills/requesting-code-review/recipe-code.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "feat(gate): the reviewer picked severities against a scope nobody had defined"
```

If the arm lost, commit only the evidence note, with the message `docs(evals): severity calibration in the focus text did not beat its control`.

---

### Task 3: Arm B — the round 2+ invocation is a fixed recipe

**Risk tier:** standard — behavior-shaping prose in a gate section file, with losslessness bookkeeping.

**Files:**
- Modify: `skills/requesting-code-review/gate-fix-loop.md:22`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 1)
- Create (evals repo): `evals/scenarios/codex-gate-re-review-focus-is-fixed/`

**Interfaces:**
- Consumes: Task 1's baseline note.
- Produces: an appended `### Arm B` section in the evidence note.

**Context the implementer needs.** `recipe-code.md` says the focus text stays short. Measured across real re-review launches, the focus string ran to a median of 464 words, a 90th percentile of 1032, and a maximum of 35468, with 36% over 600 words. The overflow is the ledger's content pasted inline: findings restated, the fix summarized, the diff quoted. All of it is already in the file the preamble hands over as a path.

The spec's D8 also says the round-1 exhaustiveness demand is dropped from re-reviews. **That half needs no edit, and the implementer should not go looking for one.** The demand lives in the lens skeleton at `gate-lenses.md:16`, and that file's closing paragraph already states that re-review rounds use no lenses. The code recipe's own focus string does not contain it. The clause is satisfied structurally; adding a second prohibition against it would only reintroduce the form this arm is replacing.

The current text says only that the round 2+ invocation "prepends a round-aware preamble to the §3 prompt", which describes one part and leaves the rest to improvisation. Per `writing-skills`, a wrong-shaped output is fixed with a positive recipe naming the parts in order, not with a prohibition list — prohibitions measurably backfire under a competing incentive, and "make the prompt self-contained" is exactly that incentive.

- [ ] **Step 1: Write the scenario**

Create `evals/scenarios/codex-gate-re-review-focus-is-fixed/`. It must:

- Pre-stage a task gate mid-loop: a `GATE_DIR` holding `gate-round.json` at round 1, a round ledger with two resolved findings and one declined finding, and a committed fix diff.
- Prompt the agent to run re-review round 2.
- Assert in `post()` that the launched focus string is under 250 words, by counting words in the recorded launch argument.
- Assert in `post()` that the focus string contains the ledger path.
- Assert in `post()` that the focus string does not restate a finding title from the ledger, by grepping the launch for a distinctive noun phrase planted in the ledger's first finding.
- Put in the story's Acceptance Criteria that the agent handed the findings over as a file path rather than pasting them.

Validate: `cd evals && bun run quorum check codex-gate-re-review-focus-is-fixed`

- [ ] **Step 2: Commit the scenario in the evals repo**

```bash
git -C evals add scenarios/codex-gate-re-review-focus-is-fixed
git -C evals commit -m "scenario: the re-review focus string restates a ledger it already hands over as a path"
```

- [ ] **Step 3: Run the control**

Run three times against the unmodified tree:

```bash
cd evals && bun run quorum run scenarios/codex-gate-re-review-focus-is-fixed --coding-agent claude
```

Record each run's word count and pass or fail. Expected: the control fails, with focus strings well over 250 words.

If all three pass, STOP, record the null result, and skip to the next task; the scenario stays committed in the evals repo, because a null result is evidence too.

- [ ] **Step 4: Replace the line with the recipe**

In `skills/requesting-code-review/gate-fix-loop.md`, replace line 22 in full with this single line:

```
The round 2+ invocation has exactly three parts, in order: the round-aware preamble, the ledger path, and the §3 recipe's own focus string unchanged. The ledger file carries the findings, the fixes, and the diff references, so the focus string carries none of them — measured re-review focus strings that restated the ledger inline ran to a median of 464 words and a maximum of 35468. The preamble is:
```

- [ ] **Step 5: Add the losslessness row**

Do not retype the replacement line. Extract it from the file you just
edited, so the table's copy is byte-identical to the file's by construction —
a single drifted character fails the proof.

```bash
printf '%s\t%s\t%s\n' 563 fixed-rereview-recipe "$(sed -n '22p' skills/requesting-code-review/gate-fix-loop.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
tail -1 tests/codex-review-gate/gate-post-split-edits.tsv | awk -F'\t' '{print NF, $1, $2}'
```

Expected: `3 563 fixed-rereview-recipe`.

- [ ] **Step 6: Bump the pinned edit count**

Read the current pin (`grep -n 'post_edit_count" -eq' tests/codex-review-gate/test-gate-split-lossless.sh`), call it N, and set the `-eq` test and both `exactly N declared post-split edits` message strings to N plus 1 (this task appended one row). N depends on which earlier arms won; never copy it from this plan.

- [ ] **Step 7: Prove the edit is lossless**

```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-contract.sh
```

Expected: `STATUS: PASSED` from both.

- [ ] **Step 8: Run the treatment**

Three runs against the modified tree:

```bash
cd evals && bun run quorum run scenarios/codex-gate-re-review-focus-is-fixed --coding-agent claude
```

Record word counts and pass or fail.

**Decision rule:** the arm wins if it passes at least 2 of 3 while the control passed at most 1 of 3, AND the treatment's median focus word count is below the control's.

- [ ] **Step 9: If the arm lost, revert it**

```bash
git show HEAD:skills/requesting-code-review/gate-fix-loop.md > skills/requesting-code-review/gate-fix-loop.md
git show HEAD:tests/codex-review-gate/gate-post-split-edits.tsv > tests/codex-review-gate/gate-post-split-edits.tsv
git show HEAD:tests/codex-review-gate/test-gate-split-lossless.sh > tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
```

Then record the loss and skip to Step 11. The revert restores the previous edit count, which is why every count step reads the file rather than this plan.

- [ ] **Step 10: Append the evidence section**

Add `### Arm B — the round 2+ invocation is a fixed recipe` to the evidence note: the measured drift figures, why the form is a recipe rather than a prohibition, the scenario name, control and treatment results run by run, and the verdict.

- [ ] **Step 11: Commit**

```bash
git add skills/requesting-code-review/gate-fix-loop.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "fix(gate): the re-review prompt pasted a ledger it was already handing over as a path"
```

If the arm lost, commit only the evidence note, with the message `docs(evals): a fixed round-2 recipe did not beat its control`.

---

### Task 4: Arm C — pre-existing blocking findings are carried forward, not looped on

**Risk tier:** standard — behavior-shaping prose that changes which findings extend a fix loop; four losslessness rows.

**Files:**
- Modify: `skills/requesting-code-review/gate-fix-loop.md:28`
- Modify: `skills/requesting-code-review/gate-fix-loop.md:32`
- Modify: `skills/requesting-code-review/gate-fix-loop.md:33`
- Modify: `skills/requesting-code-review/gate-fix-loop.md:34`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (four new rows)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 4)
- Create (evals repo): `evals/scenarios/codex-gate-re-review-carries-forward/`

**Interfaces:**
- Consumes: Task 1's baseline note.
- Produces: an appended `### Arm C` section in the evidence note.

**Context the implementer needs.** This is the arm most likely to lose, and the one whose loss matters most, so read the evidence carefully before changing anything.

Across 244 round-2-and-later code-gate findings, not one resembled an earlier round's finding by title (word-Jaccard at or above 0.5). Blocking findings per capture fall 3.84, then 1.31, then 1.18, then 0.97 across rounds — a decay curve, not a convergence. The loops are not closing in on a fixed set of defects. Each round re-derives the whole change and finds different things, so the loop ends when the ceiling runs out.

The current text is the direct cause: "You may raise any genuinely new blocking (Critical or High) finding — whether or not it is a regression", reinforced by a paragraph stating the bar is "new and blocking, not new and a regression." That is an explicit invitation to review code the fix never touched, on every round, forever.

The change routes a pre-existing blocking defect outside the fix diff to the round ledger as carried-forward, where the final whole-branch review adjudicates it. It is not dropped. **The risk is real**: on an ad-hoc code-review request there is no final whole-branch review, so the carried-forward item's only destination is the hand-back. The replacement text says so explicitly, and the scenario must check that path.

- [ ] **Step 1: Write the scenario**

Create `evals/scenarios/codex-gate-re-review-carries-forward/`. It must:

- Pre-stage a task gate at round 2: a round-1 ledger with one resolved finding, a committed fix diff that resolves it cleanly, and — elsewhere in the repo, untouched by the fix — one planted genuine high-severity defect.
- Prompt the agent to run re-review round 2.
- Assert in `post()` that the loop converged rather than opening round 3: `gate-round.json` has `round: 2` and the round's normalized verdict is `approved`.
- Assert in `post()` that the planted pre-existing defect appears in the round ledger, by grepping the ledger for a distinctive identifier planted in that code.
- Put in the story's Acceptance Criteria that the agent recorded the pre-existing defect as carried-forward rather than either fixing it in this loop or silently dropping it. **Dropping it is a scenario failure, not a pass** — the point of the arm is redirection, not suppression.

Validate: `cd evals && bun run quorum check codex-gate-re-review-carries-forward`

- [ ] **Step 2: Commit the scenario in the evals repo**

```bash
git -C evals add scenarios/codex-gate-re-review-carries-forward
git -C evals commit -m "scenario: a pre-existing defect outside the fix diff extends a loop chartered for the fix"
```

- [ ] **Step 3: Run the control**

Run three times against the unmodified tree:

```bash
cd evals && bun run quorum run scenarios/codex-gate-re-review-carries-forward --coding-agent claude
```

Expected: the control fails by opening round 3 to fix the pre-existing defect.

If all three pass, STOP, record the null result, and skip to the next task; the scenario stays committed in the evals repo, because a null result is evidence too.

- [ ] **Step 4: Replace the four lines**

In `skills/requesting-code-review/gate-fix-loop.md`, replace line 28 in full with:

```
> (Critical or High)** finding that the fix diff introduced, or that is a regression the fix caused, provided it
```

Replace line 32 in full with:

```
The bar on re-review is "new and in the fix diff," or a regression the fix caused. A Critical or High issue that predates round 1 and sits outside the fix diff is real but is not this loop's business: record it in the ledger as carried-forward, for the final whole-branch review to adjudicate — or, on a gate with no final review, for the §6 hand-back to name explicitly. Measured across 244 round-2 findings, not one resembled an earlier round's finding: every round re-derived the whole change, so loops ended by exhausting the ceiling rather than by converging. What is
```

Replace line 33 in full with:

```
excluded on re-review is Minor noise and carried-forward pre-existing defects, not new blocking
```

Replace line 34 in full with:

```
severity in the fix itself.
```

Read lines 26 through 35 back afterward and confirm the paragraph is grammatical end to end. The four replacements are designed to flow into the untouched lines around them.

- [ ] **Step 5: Add the four losslessness rows**

Do not retype the replacement line. Extract it from the file you just
edited, so the table's copy is byte-identical to the file's by construction —
a single drifted character fails the proof.

The four source lines map to the four file lines in order: 569 to line 28, 573 to line 32, 574 to line 33, 575 to line 34.

```bash
printf '%s\t%s\t%s\n' 569 carry-forward-bar "$(sed -n '28p' skills/requesting-code-review/gate-fix-loop.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
printf '%s\t%s\t%s\n' 573 carry-forward-bar "$(sed -n '32p' skills/requesting-code-review/gate-fix-loop.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
printf '%s\t%s\t%s\n' 574 carry-forward-bar "$(sed -n '33p' skills/requesting-code-review/gate-fix-loop.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
printf '%s\t%s\t%s\n' 575 carry-forward-bar "$(sed -n '34p' skills/requesting-code-review/gate-fix-loop.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
tail -4 tests/codex-review-gate/gate-post-split-edits.tsv | awk -F'\t' '{print NF, $1, $2}'
```

Expected: four rows, each reading `3 <srcline> carry-forward-bar`.

- [ ] **Step 6: Bump the pinned edit count**

Read the current pin (`grep -n 'post_edit_count" -eq' tests/codex-review-gate/test-gate-split-lossless.sh`), call it N, and set the `-eq` test and both `exactly N declared post-split edits` message strings to N plus 4 (this task appended four rows). N depends on which earlier arms won; never copy it from this plan.

- [ ] **Step 7: Prove the edit is lossless**

```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-contract.sh
```

Expected: `STATUS: PASSED` from both.

- [ ] **Step 8: Run the treatment**

Three runs against the modified tree:

```bash
cd evals && bun run quorum run scenarios/codex-gate-re-review-carries-forward --coding-agent claude
```

Record for each: the round the loop ended on, whether the planted defect reached the ledger, and pass or fail.

**Decision rule:** the arm wins only if it passes at least 2 of 3 while the control passed at most 1 of 3, AND the planted defect reached the ledger in every treatment run that passed. A run that converged by dropping the defect is a failure for this arm even if the round count improved.

- [ ] **Step 9: If the arm lost, revert it**

```bash
git show HEAD:skills/requesting-code-review/gate-fix-loop.md > skills/requesting-code-review/gate-fix-loop.md
git show HEAD:tests/codex-review-gate/gate-post-split-edits.tsv > tests/codex-review-gate/gate-post-split-edits.tsv
git show HEAD:tests/codex-review-gate/test-gate-split-lossless.sh > tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
```

Then record the loss and skip to Step 11.

- [ ] **Step 10: Append the evidence section**

Add `### Arm C — pre-existing blocking findings are carried forward` to the evidence note: the 244-finding measurement, the per-round decay curve, the ad-hoc-gate risk and how the text addresses it, the scenario name, control and treatment results run by run including where each planted defect ended up, and the verdict.

- [ ] **Step 11: Commit**

```bash
git add skills/requesting-code-review/gate-fix-loop.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "fix(gate): every re-review round re-derived the whole change instead of checking the fix"
```

If the arm lost, commit only the evidence note, with the message `docs(evals): carrying pre-existing findings forward did not beat its control`.

---

### Task 5: gate-round computes the task ceiling from consumed rounds

**Risk tier:** high — `gate-round` is the gate's round counter and is named in the risk-tier rubric as approval-authority code.

**Files:**
- Modify: `skills/requesting-code-review/scripts/gate-round`
- Modify: `skills/requesting-code-review/gate-fix-loop.md:87`
- Modify: `skills/subagent-driven-development/SKILL.md:491-503`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 1)
- Test: `tests/codex-review-gate/test-gate-round.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a new `gate-round` flag, `--consumed <n>`. It sets the ceiling to `5 - n`, the SDD shared per-task cap minus the fix rounds already spent outside this gate. It is mutually exclusive with `--ceiling`; supplying both is a usage error, exit 2. The written state file gains a `consumed` field alongside `round`, `ceiling`, and `gate`. The stdout shape is otherwise unchanged.

**Context the implementer needs.** SDD's per-task Codex gate has no ceiling of its own. Its rounds count against the task's shared five-round fix cap, so the controller must compute `5 - <non-gate fix rounds consumed>` before every `gate-round` call. In real runs, 19 task gates recorded ceilings of 1, 2, 6, and 7. Six and seven are impossible: they exceed the cap. The subtraction does not survive contact, so the script should do it.

Two details the implementation must get right:

- **Ceiling zero is now reachable.** With `--consumed 5` the cap is fully spent and the ceiling is 0. The advance path handles that correctly, because `round=1` is greater than `0`. The peek path does not: its verdict expression tests `[ "$c" -gt 0 ]` first, so a zero ceiling short-circuits to `proceed`. Today that is a latent quirk reachable only by passing `--ceiling 0` explicitly; `--consumed` makes it reachable through ordinary use, so fix it in this task.
- **A task ceiling above 5 is impossible.** Reject `--gate task` with `--ceiling` greater than 5 as a usage error. That is safe: the gate doc's step 0 already says a non-zero `gate-round` exit is treated as backstop, so the failure mode is fail-closed rather than a stall.

This task's evidence is mechanical, not an eval. The defect is arithmetic in a script, and a bash suite proves the arithmetic. No scenario is required.

- [ ] **Step 1: Write the failing tests**

Read `tests/codex-review-gate/test-gate-round.sh` first to learn its fixture helpers and assertion style. Then append cases, before the final status block, that assert:

1. `gate-round "$gd" --consumed 2 --gate task` returns `"ceiling":3` and `"verdict":"proceed"` on a fresh state directory.
2. The written `gate-round.json` records `"consumed":2` alongside `"round":1` and `"ceiling":3`.
3. `gate-round "$gd" --consumed 0 --gate task` yields `"ceiling":5`.
4. `gate-round "$gd" --consumed 5 --gate task` yields `"ceiling":0` and `"verdict":"backstop"` on its first advance.
5. `gate-round "$gd" --peek --ceiling 0` returns `"verdict":"backstop"`, not `proceed`.
6. `gate-round "$gd" --peek` on a fresh directory with no `--ceiling` still returns `"verdict":"proceed"`. This pins the case the peek fix deliberately leaves alone; without it, a later simplification silently stops gates before round 1.
7. Supplying both `--consumed 2` and `--ceiling 3` exits 2.
8. `--consumed 6` exits 2, and `--consumed -1` exits 2.
9. `gate-round "$gd" --ceiling 7 --gate task` exits 2.
10. `gate-round "$gd" --ceiling 7 --gate final` still succeeds — the cap applies to the task gate only.
11. Every pre-existing `--ceiling` behavior is unchanged for the spec, plan, final, and adhoc gates.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
bash tests/codex-review-gate/test-gate-round.sh
```

Expected: FAIL. `--consumed` is an unknown argument today, so cases 1 through 4, 7, and 8 exit 2 with `gate-round: unknown arg --consumed`. Case 5 reports `proceed` where the test wants `backstop`. Case 9 succeeds where it should fail. Cases 6, 10, and 11 pass already — 6 is a characterization test, so prove it is not vacuous by temporarily making the peek unconditional, watching it fail, and restoring the script with `git show HEAD:skills/requesting-code-review/scripts/gate-round > skills/requesting-code-review/scripts/gate-round`.

- [ ] **Step 3: Add the flag, the validation, and the peek fix**

In `skills/requesting-code-review/scripts/gate-round`, extend the argument loop. Replace:

```bash
ceiling=""; peek=0; gate=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ceiling) ceiling="$2"; shift 2 ;;
    --gate) gate="$2"; shift 2 ;;
    --peek) peek=1; shift ;;
    *) echo "gate-round: unknown arg $1" >&2; exit 2 ;;
  esac
done
```

with:

```bash
ceiling=""; peek=0; gate=""; consumed=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ceiling) ceiling="$2"; shift 2 ;;
    --consumed) consumed="$2"; shift 2 ;;
    --gate) gate="$2"; shift 2 ;;
    --peek) peek=1; shift ;;
    *) echo "gate-round: unknown arg $1" >&2; exit 2 ;;
  esac
done

# SDD's per-task gate has no ceiling of its own: its rounds count against the
# task's shared five-round fix cap. Making the controller subtract did not
# survive contact — 19 measured task gates recorded ceilings of 1, 2, 6, and 7,
# and 6 and 7 exceed the cap outright. --consumed states the one number the
# controller can read off its ledger and lets the script do the arithmetic.
SDD_TASK_CAP=5
if [ -n "$consumed" ]; then
  [ -z "$ceiling" ] || { echo "gate-round: --consumed and --ceiling are mutually exclusive" >&2; exit 2; }
  case "$consumed" in
    ''|*[!0-9]*) echo "gate-round: --consumed must be a non-negative integer (got '$consumed')" >&2; exit 2 ;;
  esac
  [ "$consumed" -le "$SDD_TASK_CAP" ] || { echo "gate-round: --consumed $consumed exceeds the shared cap of $SDD_TASK_CAP" >&2; exit 2; }
  ceiling=$((SDD_TASK_CAP - consumed))
fi
# A task-gate ceiling above the shared cap is arithmetically impossible. Exit 2
# is fail-closed here: the gate doc's step 0 treats a non-zero gate-round exit
# as backstop, so a bad ceiling stops the round rather than stalling the loop.
if [ "${gate:-}" = "task" ] && [ -n "$ceiling" ]; then
  case "$ceiling" in
    ''|*[!0-9]*) echo "gate-round: --ceiling must be a non-negative integer (got '$ceiling')" >&2; exit 2 ;;
  esac
  [ "$ceiling" -le "$SDD_TASK_CAP" ] || { echo "gate-round: task-gate ceiling $ceiling exceeds the shared cap of $SDD_TASK_CAP" >&2; exit 2; }
fi
```

Then fix the peek verdict. **Read this paragraph before editing.** The naive
fix breaks a case the tests do not cover. Today line 46 reads
`c="${prev_ceiling:-${ceiling:-0}}"`, which collapses two different states into
the same value: a recorded ceiling of zero, and no ceiling known at all. The
`-gt 0` guard then makes both answer `proceed`. Simply deleting that guard
would flip a peek on a fresh `GATE_DIR` with no `--ceiling` from `proceed` to
`backstop` — a gate stopped before round 1 ever ran. Keep the two states
distinct instead. Replace the whole block from line 46 through line 54:

```bash
  c="${prev_ceiling:-${ceiling:-0}}"
  # Defend against non-numeric ceiling in fallback (should not happen given sentinel,
  # but fail closed if it does).
  if ! expr "$c" + 0 >/dev/null 2>&1; then
    echo "gate-round: state file exists but is unreadable: $state" >&2
    exit 2
  fi
  next=$((round + 1))
  verdict=$([ -n "$c" ] && [ "$c" -gt 0 ] && [ "$next" -gt "$c" ] && echo backstop || echo proceed)
```

with:

```bash
  # An unknown ceiling and a recorded ceiling of zero are different answers.
  # The old form defaulted unknown to 0 and then had to guard with `-gt 0`,
  # which swallowed a real zero along with it. Leave unknown empty: unknown
  # proceeds, and a recorded zero means the budget is spent and backstops.
  # A real zero was unreachable until --consumed 5 made it ordinary.
  c="${prev_ceiling:-$ceiling}"
  # Defend against a non-numeric ceiling that slipped past the sentinel.
  if [ -n "$c" ] && ! expr "$c" + 0 >/dev/null 2>&1; then
    echo "gate-round: state file exists but is unreadable: $state" >&2
    exit 2
  fi
  next=$((round + 1))
  if [ -n "$c" ] && [ "$next" -gt "$c" ]; then verdict=backstop; else verdict=proceed; fi
```

The `printf` on the next line already renders `"${c:-0}"`, so an unknown
ceiling still reports as 0 in the output. Leave it alone.

Finally, record `consumed` in the state file. Replace:

```bash
printf '{"round":%s,"ceiling":%s,"gate":"%s"}\n' "$round" "$ceiling" "$g" > "$state" || {
```

with:

```bash
printf '{"round":%s,"ceiling":%s,"gate":"%s","consumed":%s}\n' "$round" "$ceiling" "$g" "${consumed:-null}" > "$state" || {
```

- [ ] **Step 4: Update the script's header contract**

Replace line 2 of the same file:

```
# gate-round GATE_DIR --ceiling N [--peek] — mechanical round counter for
```

with:

```
# gate-round GATE_DIR (--ceiling N | --consumed N) [--gate T] [--peek] —
# mechanical round counter for
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
bash tests/codex-review-gate/test-gate-round.sh
```

Expected: `STATUS: PASSED`.

- [ ] **Step 6: Point the gate doc at the new flag**

In `skills/requesting-code-review/gate-fix-loop.md`, replace line 87 in full with:

```
   bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/gate-round" "$GATE_DIR" --ceiling <4 for document gates, 3 for final and code-review-request gates> --gate <spec|plan|final|adhoc>   # SDD per-task gate instead: --consumed <the task's non-gate fix rounds so far, read off the ledger> --gate task
```

- [ ] **Step 7: Update the SDD instructions that mandate the hand-computed ceiling**

`skills/subagent-driven-development/SKILL.md` tells the controller to do the
subtraction by hand, in the numbered list starting at line 491. That is the
instruction this task replaces, so it changes here too. This file is **not** a
gate section file, so it needs no losslessness bookkeeping.

Replace item 2 in full — lines 491 through 499, running from `2. **State the ceiling in the counter's own coordinates.**` through `call: non-gate rounds may land between gate rounds.` — with:

```markdown
  2. **Let the counter do the arithmetic.** `gate-round` compares its LOCAL
     count — gate rounds only, monotonic within the `GATE_DIR` — against a
     ceiling, so the ceiling must leave gate rounds out; they are already in
     that count. Pass `--consumed <NON-gate fix rounds this task has consumed
     so far>` (all fix/re-review rounds, whatever the finding's origin — the
     gate's own invocation rounds are excluded only because `gate-round`'s
     counter already holds them) and the script derives the ceiling from the
     shared five-round cap itself. Recompute the consumed count at each call:
     non-gate rounds may land between gate rounds. Do not hand-compute
     `--ceiling` for a task gate — that is how nineteen measured task gates
     recorded ceilings of 1, 2, 6, and 7, two of which the cap makes
     impossible. `--consumed` cannot express them.
```

Then replace item 3 in full — lines 500 through 503, running from `3. **Check the shared cap before calling.**` through `below and surface the task as BLOCKED.` — with:

```markdown
  3. **A spent cap is BLOCKED, not a gate round.** When the task's consumed
     rounds already total five, `--consumed 5` yields a ceiling of zero and
     the gate backstops on its first call. That is the fail-closed floor, not
     the intended path: check before calling, and when the cap is spent follow
     the breaker below and surface the task as BLOCKED rather than spending a
     gate invocation to learn it.
```

Read lines 488 through 512 back afterward and confirm the list numbering and the closing invariant paragraph still read correctly.

- [ ] **Step 8: Add the losslessness row and bump the count**

Do not retype the replacement line. Extract it from the file you just
edited, so the table's copy is byte-identical to the file's by construction —
a single drifted character fails the proof.

```bash
printf '%s\t%s\t%s\n' 628 consumed-ceiling "$(sed -n '87p' skills/requesting-code-review/gate-fix-loop.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
tail -1 tests/codex-review-gate/gate-post-split-edits.tsv | awk -F'\t' '{print NF, $1, $2}'
```

Expected: `3 628 consumed-ceiling`.

Read the current pin (`grep -n 'post_edit_count" -eq' tests/codex-review-gate/test-gate-split-lossless.sh`), call it N, and set the `-eq` test and both `exactly N declared post-split edits` message strings to N plus 1 (this task appended one row). N depends on which earlier arms won; never copy it from this plan.

- [ ] **Step 9: Prove the edit is lossless and the gate still contracts**

```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/codex-review-gate/test-gate-topology.sh
```

Expected: `STATUS: PASSED` from all three.

- [ ] **Step 10: Append the evidence section**

Add `### Consumed-round accounting` to the evidence note recording: the 19 impossible ceilings and their values, why the fix is arithmetic in the script rather than an eval-gated prose change, and the test cases that now pin it.

- [ ] **Step 11: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-round skills/requesting-code-review/gate-fix-loop.md skills/subagent-driven-development/SKILL.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh tests/codex-review-gate/test-gate-round.sh docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "fix(gate): nineteen task gates recorded ceilings the shared cap makes impossible"
```

---

### Task 6: An approved-with-notes verdict keeps its notes

**Risk tier:** standard — one gate section line with losslessness bookkeeping, plus a contract assertion; it changes what the controller records, not what the reviewer judges.

**Files:**
- Modify: `skills/requesting-code-review/gate-findings.md:48`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 1)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (one new assertion)

**Interfaces:**
- Consumes: 6.13.0's `verdict-normalize`, whose JSON path now returns `{"result":"approved","verdict":"needs-attention",...}` for a capture with only medium/low findings.
- Produces: nothing callable. The gate's completion-check prose now names what a controller does with that capture.

**Context the implementer needs.** The 6.13.0 sweep's correctness lens raised this as a medium finding, and the sweep itself then demonstrated it: the release-commit review converged through exactly this path, and its two medium notes reached a ledger only because the controller chose to write them down. `gate-findings.md` tells the controller to read raw findings only on `blocking`, so an approved-with-notes capture can converge with its notes unread, contrary to spec D2's claim that the findings still travel to the round ledger. The fix is one sentence in the completion check. The line is `gate-findings.md:48`, which is source line 441 of the pinned original (verified byte-for-byte); it is not a referent line. Line 49 begins `fixing; normalization gates only the decision.`, so the replacement must end with `read the raw findings text as usual to do the` exactly as the current line does, or the paragraph breaks.

No eval arm: this instruction is bookkeeping the controller performs after the reviewer has spoken, and its presence is what the contract suite can check. If the plan gate disagrees, it says so before this task runs.

- [ ] **Step 1: Write the failing assertion**

In `tests/codex-review-gate/test-gate-contract.sh`, immediately before the final status block, add:

```bash
assert_contains "$GATE" "the capture carries medium/low notes: read them and record each in the round ledger" \
  "approved-with-notes findings are recorded, not dropped"
```

Run: `bash tests/codex-review-gate/test-gate-contract.sh`

Expected: FAIL on that one assertion.

- [ ] **Step 2: Replace the line**

In `skills/requesting-code-review/gate-findings.md`, replace line 48 in full with this single line:

```
of output. On `approved` reached through a `needs-attention` verdict, the capture carries medium/low notes: read them and record each in the round ledger (and in the skill's Minor ledger, if it keeps one) before treating the round as converged. On `blocking`, read the raw findings text as usual to do the
```

Read lines 46-50 back and confirm the paragraph flows into line 49.

- [ ] **Step 3: Add the losslessness row and bump the count**

Do not retype the line; extract it so the table's copy is byte-identical:

```bash
printf '%s\t%s\t%s\n' 441 approved-with-notes "$(sed -n '48p' skills/requesting-code-review/gate-findings.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
tail -1 tests/codex-review-gate/gate-post-split-edits.tsv | awk -F'\t' '{print NF, $1, $2}'
```

Expected: `3 441 approved-with-notes`.

Read the current pin (`grep -n 'post_edit_count" -eq' tests/codex-review-gate/test-gate-split-lossless.sh`), call it N, and set the `-eq` test and both `exactly N declared post-split edits` message strings to N plus 1.

- [ ] **Step 4: Prove the edit is lossless and the contract holds**

```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-contract.sh
```

Expected: `STATUS: PASSED` from both.

- [ ] **Step 5: Append the evidence section**

Add `### Approved-with-notes bookkeeping` to `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`: the sweep finding, the release-commit review that exercised the path, and why no arm was run.

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/gate-findings.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh tests/codex-review-gate/test-gate-contract.sh docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "fix(gate): an approval that carried notes had no rule saying anyone reads them"
```

---

### Task 7: Upstream port — the project's suite defines green

**Risk tier:** standard — behavior-shaping prose in a frequently-loaded skill, requiring fork-side evidence.

**Files:**
- Modify: `skills/test-driven-development/SKILL.md:183`
- Create (evals repo): `evals/scenarios/tdd-runs-the-project-suite/`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: an appended `### Upstream port — project suite` section in the evidence note.

**Context the implementer needs.** Port of upstream commit `a45ede8`. Upstream measured 1 of 12 controls passing against 8 of 12 with the change, across three model families (sonnet 4/4, kimi 3/4, glm 1/4). This repository's rule is fork-side before/after evidence regardless of what upstream measured, so this task runs its own control and treatment.

The defect: an agent finishing a TDD cycle runs the one test file its task named, sees green, and reports done. The project's suite is never run, and a failure it would have shown goes unmentioned.

- [ ] **Step 1: Write the scenario**

Create `evals/scenarios/tdd-runs-the-project-suite/`. It must:

- Set up a small project with a working test runner and several test files.
- Plant a pre-existing failure in a test file the task does not name.
- Give the agent a TDD task scoped explicitly to one other test file.
- Assert in `post()` that the agent executed the project's bare test command, not only the single-file invocation, by checking the shell history or a wrapper script the setup installs.
- Put in the story's Acceptance Criteria that the agent's report names the pre-existing failure. A report that omits it fails, even if the agent ran the suite.

Validate: `cd evals && bun run quorum check tdd-runs-the-project-suite`

- [ ] **Step 2: Commit the scenario in the evals repo**

```bash
git -C evals add scenarios/tdd-runs-the-project-suite
git -C evals commit -m "scenario: a green single-file test run reported as a green suite"
```

- [ ] **Step 3: Run the control**

Four runs against the unmodified tree, one per agent, so a result that is really one model's quirk cannot pass as a fleet effect:

```bash
cd evals && bun run quorum run-all --scenarios tdd-runs-the-project-suite --coding-agents claude,claude-sonnet,codex,kimi --jobs 2
```

Record each result. Expected: most fail.

If all four pass, STOP and record the null result. Upstream's measurement does not license shipping into this fork without fork-side evidence.

- [ ] **Step 4: Add the guidance**

In `skills/test-driven-development/SKILL.md`, find line 183:

```markdown
**Other tests fail?** Fix now.
```

Insert immediately after it, preceded by a blank line:

```markdown
**"Other tests" means the project's suite, not just your file.** A
green run of the test you wrote is not a green suite. Before you call
the change done, run the project's test command (bare `pytest`,
`npm test`, `cargo test` — whatever the repo uses) even when your task
named only one test file. A scope statement in your task bounds the
deliverable, not your verification. Any failure that run shows —
including one you didn't cause — goes in your report by name; a red
test you watched scroll past and didn't mention is a report falsified
by omission.
```

- [ ] **Step 5: Run the treatment**

Four runs against the modified tree, same four agents as the control:

```bash
cd evals && bun run quorum run-all --scenarios tdd-runs-the-project-suite --coding-agents claude,claude-sonnet,codex,kimi --jobs 2
```

Record each result.

**Decision rule:** the arm wins if the treatment's pass rate exceeds the control's by at least half the runs — with four runs, a control of at most 1 and a treatment of at least 3.

- [ ] **Step 6: If the arm lost, revert it**

```bash
git show HEAD:skills/test-driven-development/SKILL.md > skills/test-driven-development/SKILL.md
```

Then record the loss and skip to Step 8.

- [ ] **Step 7: Append the evidence section**

Add `### Upstream port — the project's suite defines green` to the evidence note: upstream's commit and its measurement, this fork's scenario, control and treatment results run by run and by agent, and the verdict.

- [ ] **Step 8: Commit**

```bash
git add skills/test-driven-development/SKILL.md docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "feat(tdd): a green run of one test file was being reported as a green suite"
```

If the arm lost, commit only the evidence note, with the message `docs(evals): the upstream project-suite bullet did not reproduce a fork-side win`.

---

### Task 8: Upstream port — the tooling question in a new project's design

**Risk tier:** standard — behavior-shaping prose in a frequently-loaded skill, requiring fork-side evidence.

**Files:**
- Modify: `skills/brainstorming/SKILL.md:228`
- Create (evals repo): `evals/scenarios/brainstorming-asks-tooling-question/`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: an appended `### Upstream port — tooling question` section in the evidence note.

**Context the implementer needs.** Port of upstream commit `537d649`, which measured 0 of 3 controls against 3 of 3 with the change. Fork-side evidence is still required.

The defect: a new project's design presentation covers architecture, components, data flow, error handling, and testing, but never asks which tooling to stand up. Linting, formatting, and test infrastructure are cheapest to add before any code exists and most expensive to retrofit, and the moment to decide passes silently.

- [ ] **Step 1: Write the scenario**

Create `evals/scenarios/brainstorming-asks-tooling-question/`. It must:

- Set up an empty directory with no configured tooling — no linter config, no test runner, no `package.json` or `pyproject.toml`.
- Send a new-project request that routes to the architectural path.
- Assert in `post()` that the written spec's Global Constraints section names at least one tooling selection.
- Put in the story's Acceptance Criteria that the design presentation asked the tooling question alongside the architecture, and that the user's answer landed in the spec rather than only in chat.

Validate: `cd evals && bun run quorum check brainstorming-asks-tooling-question`

- [ ] **Step 2: Commit the scenario in the evals repo**

```bash
git -C evals add scenarios/brainstorming-asks-tooling-question
git -C evals commit -m "scenario: a new project's design never asks which tooling to stand up"
```

- [ ] **Step 3: Run the control**

Run three times against the unmodified tree:

```bash
cd evals && bun run quorum run scenarios/brainstorming-asks-tooling-question --coding-agent claude
```

Record each result. Expected: all three fail.

If all three pass, STOP and record the null result.

- [ ] **Step 4: Add the bullet**

In `skills/brainstorming/SKILL.md`, find line 228:

```markdown
- Cover: architecture, components, data flow, error handling, testing
```

Insert immediately after it, as the next bullet:

```markdown
- For a new project (or one with no configured tooling), the design presentation includes a short tooling question alongside the architecture: which of these to set up from the start — cheapest before any code exists: aggressive linting + auto-formatting (the stack's standard, e.g. ruff+format / eslint+prettier / clippy+rustfmt); unit-test infrastructure (runner, layout, a first passing fixture); end-to-end test infrastructure; fuzz or mutation testing where the stack supports it. The user's selections land in the spec's Global Constraints so every later plan and task inherits them.
```

- [ ] **Step 5: Run the treatment**

Three runs against the modified tree, same agent as the control:

```bash
cd evals && bun run quorum run scenarios/brainstorming-asks-tooling-question --coding-agent claude
```

Record each result.

**Decision rule:** the arm wins if it passes at least 2 of 3 while the control passed at most 1 of 3.

- [ ] **Step 6: If the arm lost, revert it**

```bash
git show HEAD:skills/brainstorming/SKILL.md > skills/brainstorming/SKILL.md
```

Then record the loss and skip to Step 8.

- [ ] **Step 7: Append the evidence section**

Add `### Upstream port — the tooling question` to the evidence note: upstream's commit and measurement, this fork's scenario, control and treatment results run by run, and the verdict.

- [ ] **Step 8: Commit**

```bash
git add skills/brainstorming/SKILL.md docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "feat(brainstorming): the cheapest moment to choose tooling passed without the question being asked"
```

If the arm lost, commit only the evidence note, with the message `docs(evals): the upstream tooling-question bullet did not reproduce a fork-side win`.

---

### Task 9: Arm D — evidence for the two routing edits 6.13.0 shipped

**Risk tier:** standard — no new prose; this arm measures prose that already shipped and reverts it if the measurement says so.

**Files:**
- Create (evals repo): `evals/scenarios/executing-plans-keeps-inline-request/`
- Create (evals repo): `evals/scenarios/executing-plans-keeps-inline-request-control/`
- Create (evals repo): `evals/scenarios/requesting-code-review-hands-off-to-receiving/`
- Create (evals repo): `evals/scenarios/requesting-code-review-hands-off-to-receiving-control/`
- Conditionally modify: `skills/executing-plans/SKILL.md:14` and `skills/requesting-code-review/SKILL.md` step 3 (only if a scenario loses)

**Interfaces:**
- Consumes: Task 1's evidence note.
- Produces: an appended `### Arm D` section. If a scenario loses, a revert commit restoring that file's 6.12.0 text.

**Context the implementer needs.** 6.13.0 shipped two routing edits as "mechanically checkable contradictions": `executing-plans/SKILL.md:14` now says the skill is the inline path by request and must not re-open the choice, and `requesting-code-review` step 3 now carries a REQUIRED SUB-SKILL pointer to `receiving-code-review`. The 6.13.0 Codex sweep held that both are behavior-shaping and shipped without the before/after evidence this repository requires. This arm supplies it after the fact. The treatment is the tree as it is. The control is the 6.12.0 text of the same file, which the control scenario's `setup.sh` writes over the staged plugin copy before the session starts — read how the harness stages the plugin from the parent checkout (see `evals/README.md`, "stages the local Superpowers plugin under the isolated home", and the setup helpers under `evals/src/`) and obtain the old text with `git show v6.12.0:skills/executing-plans/SKILL.md` (and `git show v6.12.0:skills/requesting-code-review/SKILL.md`) from the hyperpowers checkout the harness mounts.

Because the treatment already shipped, "the arm loses" means a revert: a follow-up commit restoring that file's 6.12.0 text, with the loss recorded in the evidence note.

- [ ] **Step 1: Write the two scenario pairs**

`executing-plans-keeps-inline-request`: stage a small repo with a two-task plan under `docs/hyperpowers/plans/`; the prompt asks for the plan to be executed "inline, in this session, without subagents". Assert in `post()` that `hyperpowers:executing-plans` was invoked, that `hyperpowers:subagent-driven-development` was not, and that no subagent was dispatched. Acceptance criteria: the agent executes inline and never proposes switching to SDD. The `-control` twin is identical except its `setup.sh` overwrites the staged `skills/executing-plans/SKILL.md` with the `v6.12.0` text.

`requesting-code-review-hands-off-to-receiving`: stage a small repo with a committed change and a prompt asking for a code review of it. Assert in `post()` that `hyperpowers:requesting-code-review` was invoked and that `hyperpowers:receiving-code-review` was invoked after the review result arrived and before any fix was applied. Acceptance criteria: findings were treated as claims to evaluate, with at least one explicitly weighed rather than executed. The `-control` twin overwrites the staged `skills/requesting-code-review/SKILL.md` with the `v6.12.0` text.

Set `status: ready` and `quorum_tier: full` in every `story.md`; restrict to Claude-family agents. Validate all four with `cd evals && bun run quorum check <name>`.

- [ ] **Step 2: Commit the scenarios in the evals repo**

```bash
git -C evals add scenarios/executing-plans-keeps-inline-request scenarios/executing-plans-keeps-inline-request-control scenarios/requesting-code-review-hands-off-to-receiving scenarios/requesting-code-review-hands-off-to-receiving-control
git -C evals commit -m "scenario: before/after pairs for the two routing edits 6.13.0 shipped"
```

- [ ] **Step 3: Run the controls**

Three runs of each `-control` scenario:

```bash
cd evals && bun run quorum run scenarios/executing-plans-keeps-inline-request-control --coding-agent claude
```

```bash
cd evals && bun run quorum run scenarios/requesting-code-review-hands-off-to-receiving-control --coding-agent claude
```

Record each run. Expected: the controls fail — the 6.12.0 text pushed inline sessions toward SDD and never routed to `receiving-code-review`. If a control passes all three, that edit had no defect to fix: record the null result and treat that edit as unsupported (see Step 5).

- [ ] **Step 4: Run the treatments**

Three runs of each treatment scenario against the unmodified tree:

```bash
cd evals && bun run quorum run scenarios/executing-plans-keeps-inline-request --coding-agent claude
```

```bash
cd evals && bun run quorum run scenarios/requesting-code-review-hands-off-to-receiving --coding-agent claude
```

**Decision rule, per edit:** the edit is supported if its treatment passes at least 2 of 3 while its control passed at most 1 of 3. Each edit is judged on its own pair.

- [ ] **Step 5: Revert any edit the measurement does not support**

For an unsupported edit, restore the 6.12.0 text of that file and commit:

```bash
git show v6.12.0:skills/executing-plans/SKILL.md > skills/executing-plans/SKILL.md
git commit -am "revert(executing-plans): the inline-path note did not beat its control"
```

or, for the other edit, the same with `skills/requesting-code-review/SKILL.md` — but that file also carries Task 0's `BASE_SHA` change, so restore only the step 3 block by hand to its 6.12.0 four bullets rather than overwriting the file. Then run `bash tests/codex-review-gate/test-gate-topology.sh`: the routing assertion 6.13.0 added will fail, and the revert commit must remove that assertion too, naming the measurement in its message.

- [ ] **Step 6: Append the evidence section**

Add `### Arm D — the routing edits 6.13.0 shipped` to the evidence note: why the arm exists (the sweep finding), the four scenario names, control and treatment results run by run per edit, and the verdict per edit.

- [ ] **Step 7: Commit**

```bash
git add docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "docs(evals): before/after evidence for the two routing edits 6.13.0 shipped without it"
```

---

### Task 10: Lens-count measurement and decision

**Risk tier:** standard — the deliverable is a measurement and a recorded decision; a change ships only if the measurement supports one.

**Files:**
- Modify: `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`
- Conditionally modify: `skills/requesting-code-review/gate-lenses.md` and the losslessness tables, only if the measurement supports a change

**Interfaces:**
- Consumes: Task 1's baselines, and whichever of Tasks 2 through 5 won.
- Produces: an appended `### Lens count` section in the evidence note.

**Context the implementer needs.** Round 1 of a code gate fans out to three lenses. Their measured needs-attention rates are correctness 55% over 402 captures, contracts-and-integration 59% over 352, and tests-and-evidence 69% over 401, at a mean of 0.94 findings per lens capture. The round converges only when every capture in the set approves, so three independent lenses at those rates make a round-1 convergence structurally unlikely. That is one mechanical explanation for the 27% first-round convergence rate.

**This task exists to find out whether that explanation survives Part 1 and the winning arms, not to reduce the lens count.** Part 1's `verdict-normalize` fix removes exactly the captures that blocked on nothing critical or high, which is likely to raise every one of those three rates' effective approval share. The honest sequence is measure first, decide after.

State the decision rule before looking at the numbers: a lens is a candidate for merging only if, after Part 1 and the winning arms, its needs-attention rate is at or above 60% AND its findings are at least 80% duplicated by another lens in the same batch. Rate alone is not evidence of noise; a lens that catches real defects should have a high rate.

- [ ] **Step 1: Re-measure the per-lens rates**

```bash
bash skills/requesting-code-review/scripts/gate-telemetry --all
```

Then walk the gate cache directly for per-lens outcomes. The lens captures are written as `lens-<name>-capture` inside each `GATE_DIR`. Normalize each one:

```bash
find "${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/codex-review" -name 'lens-*-capture' -print0 | xargs -0 -I{} sh -c 'printf "%s\t" "$(basename {})"; bash skills/requesting-code-review/scripts/verdict-normalize {}'
```

Tabulate, per lens name: total captures, count normalizing to `approved`, count normalizing to `blocking`, and count normalizing to `incomplete`.

- [ ] **Step 2: Measure finding overlap between lenses**

For each `GATE_DIR` with a full three-lens round-1 batch, extract each lens's finding titles from its capture and compute pairwise word-Jaccard between titles across lenses. Count a finding as duplicated when its best cross-lens match scores at or above 0.5, the same threshold the round-churn analysis used.

Report, per lens: the share of its findings duplicated by at least one other lens in the same batch.

- [ ] **Step 3: Apply the decision rule**

A lens is a merge candidate only if both conditions hold: needs-attention rate at or above 60%, and at least 80% of its findings duplicated by another lens in the batch.

- [ ] **Step 4: If no lens qualifies, record that and stop**

Write the `### Lens count` section reporting the measured table and the conclusion that the three-lens fan-out is carrying its cost. Then go to Step 6. **This is a legitimate and likely outcome.** Do not manufacture a change to justify the task.

- [ ] **Step 5: If a lens qualifies, do not change it in this plan**

Record the finding, the numbers, and the specific merge proposal in the evidence note, and state that it needs its own scenario and its own arm. Merging a lens removes a review seat, which is a larger change than this plan's remaining budget can measure honestly after three other arms have already moved the same metric. Note it as follow-up work and go to Step 6.

- [ ] **Step 6: Commit**

```bash
git add docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "docs(evals): measure whether the three-lens fan-out still explains round-1 non-convergence"
```

---

### Task 11: Release

**Risk tier:** standard — publishes every arm that won.

**Files:**
- Modify: `CHANGELOG.md`
- Modify (by `vrzn`): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json`

**Interfaces:**
- Consumes: every preceding task's commits.
- Produces: a `v6.14.0` tag. Before tagging, Task 1's post-release cohort line is re-read and appended to the evidence note.

**Context the implementer needs.** This task runs last. `vrzn` owns every version string. The bump is `minor` because Task 5 adds a flag. If every arm lost and only Task 5 and the evidence note shipped, the bump is still `minor` for that flag.

Do not push.

- [ ] **Step 1: Confirm the tree is clean and every suite is green**

```bash
git status --short
```

Expected: empty.

```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-round.sh
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/codex-review-gate/test-gate-topology.sh
bash tests/codex-review-gate/test-verdict-normalize.sh
bash tests/codex-review-gate/test-gate-telemetry.sh
bash tests/packaging/test-no-orphan-skill-files.sh
bash tests/sdd/test-sdd-contract.sh
( cd tests/brainstorm-server && npm test )
node tests/pi/test-pi-extension.mjs
```

Expected: every bash suite prints `STATUS: PASSED` or `ALL PASS`, `npm test` and the Pi file end green. If any fails, STOP and report. Do not release over a red suite.

Then re-read the post-release cohort and append it to the evidence note's Baselines section as the closing line:

```bash
since="$(git log -1 --format=%cI v6.13.0)"
bash skills/requesting-code-review/scripts/gate-telemetry --all --since "$since"
```

- [ ] **Step 2: Verify the evidence note covers every change**

```bash
git log --oneline v6.13.0..HEAD
```

Every commit touching a skill file must have a matching section in `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`. A behavior-shaping change with no evidence section violates this repository's rule and must not ship — revert it or write the section.

- [ ] **Step 3: Write the changelog entry**

Add a 6.14.0 section at the top of `CHANGELOG.md`, matching the format of the 6.13.0 entry. Cover only what actually shipped. For each arm, state the control and treatment results in one clause. For each arm that lost, say nothing in the changelog — the evidence note is its record.

Always covered, since Tasks 0, 5, and 6 are not eval-gated:

- The testing guide names the two non-bash suites and its directory loop fails when a suite fails; `gate-telemetry --since` bounds a cohort; `churn()` ignores malformed rounds; the fleet churn fields are asserted; `requesting-code-review` no longer offers `HEAD~1` as a review base (all from the 6.13.0 Codex sweep).
- An approval reached through a `needs-attention` verdict now has a stated rule: its medium/low notes are read and recorded before the round converges.
- Arm D: the two routing edits 6.13.0 shipped now carry before/after evidence (or a revert, if the measurement said so).

- `gate-round --consumed <n>` computes the SDD per-task ceiling from the shared five-round cap, replacing a subtraction the controller performed by hand. Nineteen measured task gates recorded impossible ceilings.
- `gate-round --peek` reports backstop for a spent ceiling of zero, which `--consumed 5` makes reachable.
- A task-gate ceiling above five is now a usage error.

- [ ] **Step 4: Bump the version**

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y
```

- [ ] **Step 5: Verify every manifest moved together**

```bash
git diff --stat
grep -rh '"version"' package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json | sort -u
```

Expected: a single distinct version line, `6.14.0`.

- [ ] **Step 6: Commit and tag**

```bash
git add CHANGELOG.md package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json
git commit -m "Release 6.14.0: the gate re-derived the whole change on every round"
git tag -a v6.14.0 -m "Release v6.14.0"
```

- [ ] **Step 7: Report, do not push**

Report the release commit SHA, the tag, which arms won and which were reverted with their run counts, and the fact that nothing has been pushed. Also report the evals repository's commits, which are separate and also unpushed.
