# Gate Calibration (Part 2 of 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-09-05-gate-churn-and-skill-hardening-design.md`

**Goal:** Cut Codex gate rounds-to-convergence by fixing the prompt language that makes every re-review a cold re-derivation, and land the two upstream prose ports, each with fork-side before/after evidence.

**Architecture:** Eleven tasks, numbered 0 to 10. Task 0 lands the Part 1 follow-ups the 6.13.0 Codex sweep found (a testing guide that hid two suites, a churn test that never asserted the fleet aggregate, a review-base default that truncates multi-commit ranges) and gives `gate-telemetry` a `--since` bound. Task 1 records the baselines. Tasks 2 and 3 are the gate arms: Arm A measures the Codex reviewer directly (the same fixture diff reviewed by real Codex under the control and the treatment focus text, normalized by `verdict-normalize`), because a stub reviewer cannot classify severity; Arm B measures the controller's round-2 composition in Quorum. Task 4 makes `gate-round` derive the SDD task ceiling. Task 5 gives approved-with-notes verdicts a required path for their notes. Tasks 6 and 7 are upstream prose ports and Task 8 is the arm that gives 6.13.0's two shipped routing edits their before/after evidence, all with fork-side runs. Task 9 measures the lens count over the post-release cohort; Task 10 releases. The carried-forward re-review arm the earlier draft called Arm C is dropped: a capture carrying a High finding normalizes to `blocking`, so the loop cannot converge with that finding in the ledger, and the spec's D6-D8 authorize no such policy; a future attempt needs a spec decision and an end-to-end contract first. Arms run strictly one at a time because they all move the same metric. An arm that does not beat its control is reverted, and the negative result is recorded rather than buried.

**Tech Stack:** Markdown skill prose, Bash, Node.js. Evals run on Quorum (TypeScript, Bun) in the separate `hyperpowers-evals` clone at `evals/`.

## Global Constraints

- **Part 1 must be released and merged before Task 1 runs.** Part 1's `verdict-normalize` fix changes round-1 convergence on its own. Measuring an arm against a pre-Part-1 control would credit this plan with Part 1's effect. Confirm `git merge-base --is-ancestor v6.13.0 HEAD` succeeds before starting — a tag that merely exists proves nothing about the tree you are measuring.
- **One arm at a time.** Tasks 2 through 4 all move rounds-to-convergence. Do not start an arm's control runs while another arm's change is uncommitted in the tree.
- **An arm that loses is reverted, not kept.** "No measurable difference" is a losing result for a change to tuned prose. Record it in the evidence note and restore the file with `git show HEAD:<path> > <path>`.
- **Live eval runs are trusted-maintainer operations.** They spend real API credit and launch agents in dangerous mode. Never add live evals, API keys, or dangerous-mode launches to public CI.
- **Scenario work is committed in the evals repo, never here.** `evals/` is a separate clone of `hyperpowers-evals`, gitignored in this repository. Commit each scenario there, in its own commit, before the run that uses it.
- **Every `quorum run` needs `SUPERPOWERS_ROOT`.** The runner refuses to start without it (`evals/coding-agents/claude.yaml`, `evals/src/runner/index.ts`); it is the plugin root the Claude launcher passes as `--plugin-dir`. Treatment runs set it to this checkout, `/Users/johnss51/Development/agents/hyperpowers`; Task 8's control runs set it to the control worktree. Every `quorum run` command in this plan carries it explicitly so no run silently fails setup or, worse, loads a plugin from somewhere else. On this Vertex-backed host the literal `--coding-agent claude` fails at setup on an empty `ANTHROPIC_API_KEY`, so every run command in this plan names `--coding-agent claude-auto` (the same Claude Code under test, provider detected from the environment) and each arm's evidence section records the actor used.
- **Every new scenario's `story.md` frontmatter needs `status: ready` and `quorum_tier: full`.** A scenario left at `status: draft` is skipped by `quorum run-all` unless `--include-drafts` is passed, so a draft scenario silently produces no runs and an arm looks unmeasured. Sixty-eight of the clone's sixty-nine scenarios are `ready`; match them.
- Zero new third-party dependencies in this repository.
- No emojis in code, documentation, commit messages, or reports.
- No `Co-Authored-By` lines and no text implying AI-generated assistance.
- Never run `git reset --hard`, `git clean`, `git checkout -- <path>`, or any force-push. Restore a tracked file with `git show HEAD:<path> > <path>`.
- Do not push. Committing is expected; pushing is a separate instruction from the human partner.
- **How the contributor rule "show the complete diff and get approval before committing" is met here.** The human partner approves this plan before execution and approves the complete branch diff at the finishing step, where the merge decision is theirs; every commit lands on a feature branch and nothing is pushed. Per-commit diff approval is not requested during execution unless the human partner asks for it. This is the same arrangement Part 1 ran under and is recorded so no task re-litigates it.
- Version bumps use `vrzn`. Never hand-edit a version string.
- This repository commits its `docs/hyperpowers/` specs, plans, and eval-evidence notes.

### The losslessness bookkeeping every gate-file edit needs

Three tasks edit a gate section file (Tasks 2, 3, and 5) and Task 4 edits one line of another. Those nine files are covered by a byte-identity proof that reconstructs the pre-split `codex-review-gate.md` from declared tables, so an edit that skips the bookkeeping fails `tests/codex-review-gate/test-gate-split-lossless.sh`. The recipe, once, here:

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
- Produces: `gate-telemetry --since <ISO-8601>`, which drops every gate run whose run directory is older than the timestamp; usable with or without `--all`; the value must match `YYYY-MM-DD` optionally followed by `Thh:mm[:ss[.fff]]` and `Z` or an offset, and anything else (including a parseable non-ISO date or a missing operand) exits 2. Task 1 reads the post-release cohort through it. `churn()` now ignores non-numeric round records instead of counting them as 0.

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

# --since bounds the cohort by run-directory mtime and accepts ISO-8601 only.
touch -t 202001010000 "$cr3/run-r1a" "$cr3/run-r1b"
sincejs="$(bash "$GT" --since 2025-01-01T00:00:00Z "$churnrepo" --json)"
node -e 'const d=JSON.parse(process.argv[1]);const g=d.repos[0].byGate.task;process.exit(g.runs===3&&g.meanRounds===3?0:1)' "$sincejs" && pass "--since drops runs older than the timestamp" || fail "--since drops runs older than the timestamp"
sincedate="$(bash "$GT" --since 2025-01-01 "$churnrepo" --json)"
node -e 'const d=JSON.parse(process.argv[1]);process.exit(d.repos[0].byGate.task.runs===3?0:1)' "$sincedate" && pass "--since accepts a date-only ISO-8601 value" || fail "--since accepts a date-only ISO-8601 value"
for bad in not-a-date 09/05/2026 2026 "2025-01-01 00:00"; do
  if bash "$GT" --since "$bad" "$churnrepo" >/dev/null 2>&1; then fail "--since rejects '$bad'"; else pass "--since rejects '$bad'"; fi
done
bash "$GT" "$churnrepo" --since >/dev/null 2>&1 && fail "--since without an operand exits 2" || pass "--since without an operand exits 2"
```

- [ ] **Step 2: Run both suites to verify they fail**

Run: `bash tests/codex-review-gate/test-gate-topology.sh`

Expected: FAIL on `requesting-code-review offers HEAD~1 as a review base`.

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh`

Expected: FAIL on `churn ignores a non-numeric round` (today the mean is 1.6) and on both positive `--since` cases (an unknown flag exits 2, so the JSON parse fails). The rejection cases pass today for the wrong reason (unknown flag); after Step 4 they must pass for the right one — the diagnostic names `--since`. The two fleet assertions pass already: Part 1 attached the churn fields to the aggregate; the sweep found only that nothing asserted it. They are the fence.

- [ ] **Step 3: Fix the review-base default and commit it on its own**

In `skills/requesting-code-review/SKILL.md`, replace the two-line block

```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or: git merge-base origin/main HEAD
HEAD_SHA=$(git rev-parse HEAD)
```

with this block — valid bash, one active `BASE_SHA` assignment, the other scope commented so the reader picks exactly one:

```bash
HEAD_SHA=$(git rev-parse HEAD)
# Pick the base for the scope you are reviewing. Never HEAD~1: it keeps only
# the last commit of a multi-commit change.
BASE_SHA=$(git merge-base origin/main HEAD)   # whole branch: the branch point
# BASE_SHA=$(git rev-parse "$TASK_BASE")       # one task: the commit recorded before it began
```

Run `bash tests/codex-review-gate/test-gate-topology.sh` (expected `STATUS: PASSED`), then commit this one problem:

```bash
git add skills/requesting-code-review/SKILL.md tests/codex-review-gate/test-gate-topology.sh
git commit -m "fix(requesting-code-review): the default review base kept one commit of a multi-commit change"
```

- [ ] **Step 4: Add `--since`, harden `churn()`, and commit them on their own**

In `skills/requesting-code-review/scripts/gate-telemetry` make exactly these edits. The JavaScript lives inside a single-quoted `node -e` string, so no apostrophe may appear in anything you add.

Header, line 2:

```
# gate-telemetry [--json] [--all] [--since ISO-8601] [repo-dir] — read-only aggregation over
```

After the header comment block (line 6), add:

```
# --since drops gate runs whose run directory is older than the timestamp, so
# a post-release cohort can be read without the history it follows. ISO-8601
# only (YYYY-MM-DD, optionally Thh:mm[:ss[.fff]] and Z or an offset); anything
# else exits 2 rather than silently reporting the whole history.
```

Replace `json=0; all=0; repo="."` with `json=0; all=0; since=""; repo="."` and add this case to the argument loop, before the `-*)` case:

```bash
    --since)
      [ $# -ge 2 ] || { echo "gate-telemetry: --since needs an ISO-8601 timestamp" >&2; exit 2; }
      since="$2"; shift 2 ;;
```

Replace the node argv line at the end of the script, `' "$base" "$json" "${keys[@]}"`, with `' "$base" "$json" "$since" "${keys[@]}"`.

Replace `const [base, jsonOut, ...keys] = process.argv.slice(1);` with:

```js
  const [base, jsonOut, since, ...keys] = process.argv.slice(1);
  // --since bounds the cohort by run-directory mtime. Date.parse accepts many
  // non-ISO forms, so the syntax is checked first; a bad value is a usage
  // error, never a silent no-op over the whole history.
  const ISO = /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$/;
  const sinceMs = since ? Date.parse(since) : NaN;
  if (since && (!ISO.test(since) || !Number.isFinite(sinceMs))) { console.error("gate-telemetry: --since must be an ISO-8601 timestamp, got " + since); process.exit(2); }
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

Run `bash tests/codex-review-gate/test-gate-telemetry.sh` (expected `ALL PASS`), then commit this one problem:

```bash
git add skills/requesting-code-review/scripts/gate-telemetry tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "feat(gate-telemetry): a bounded cohort via --since, a fleet churn assertion, and a mean that ignores malformed rounds"
```

- [ ] **Step 5: Confirm both suites are green together**

Run: `bash tests/codex-review-gate/test-gate-topology.sh` and `bash tests/codex-review-gate/test-gate-telemetry.sh`

Expected: `STATUS: PASSED` and `ALL PASS`.

- [ ] **Step 6: Rewrite the testing guide's Plugin tests section**

In `docs/testing.md`, replace everything from the line `Every suite is a standalone bash script. There is no aggregate runner and no` through the line `part of any automated run.` (the end of the "Plugin tests" section; `## Skill behavior evals` follows) with the text between the tilde fences, exactly. Note the runner column never writes `bash tests/<dir>/test-*.sh`: bash runs the first expansion and passes the rest as arguments, which is exactly the false green the sweep flagged.

~~~markdown
Most suites are standalone bash scripts; two directories are not. There is no
aggregate runner and no CI; run the suites that cover what you changed, one
script per `bash` invocation.

| Directory | Covers | Runner |
|---|---|---|
| `tests/hooks/` | session-start context injection, the ungated notice, the Codex broker janitor, the hooks heredoc fence | each `test-*.sh`, one per `bash` call |
| `tests/codex-review-gate/` | gate scripts (`verdict-normalize`, `gate-round`, `gate-telemetry`, `ungated-ledger`, preflight, broker health), gate topology, and the gate-split losslessness proof | each `test-*.sh`, one per `bash` call |
| `tests/sdd/` | the subagent-driven-development contract | `bash tests/sdd/test-sdd-contract.sh` |
| `tests/claude-code/` | offline: SDD scratch-dir derivation, helper stdout and range guards, delivery resolution, worktree path policy; live: skill tests that spawn the real `claude` CLI | offline: `test-sdd-dir-path.sh`, `test-codex-review-dir-path.sh`, `test-delivery-resolution.sh`, `test-worktree-path-policy.sh`, one per `bash` call; live: `run-skill-tests.sh` |
| `tests/packaging/` | manifest wiring and the orphaned-skill-file guard | each `test-*.sh`, one per `bash` call |
| `tests/brainstorm-server/` | the brainstorm server: JavaScript unit tests plus the start/stop and Windows-lifecycle shell tests | `cd tests/brainstorm-server && npm test` |
| `tests/pi/` | the Pi extension | `node tests/pi/test-pi-extension.mjs` |
| `tests/opencode/`, `tests/kimi/`, `tests/antigravity/` | per-harness plugin loading, bootstrap caching, tool registration | each directory's `run-tests.sh` |
| `tests/writing-skills/`, `tests/systematic-debugging/` | skill-specific structural checks | each `test-*.sh`, one per `bash` call |
| `tests/explicit-skill-requests/` | Haiku-specific, multi-turn, and skill-name-prompted behavior (live) | `tests/explicit-skill-requests/run-all.sh` |
| `tests/shell-lint/` | shellcheck over the repo's shell scripts | `bash tests/shell-lint/test-lint-shell.sh` |

Run one suite directly:

```bash
bash tests/codex-review-gate/test-verdict-normalize.sh
```

Run a directory's worth and fail if any suite fails. A loop that only echoes on
failure exits 0 and reads as green, and `bash tests/hooks/test-*.sh` runs only
the first file:

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

- [ ] **Step 7: Verify the guide, run the two non-bash suites it now names, and commit it on its own**

Run: `grep -n 'Every suite is a standalone bash script' docs/testing.md || echo "false claim removed"`

Expected: `false claim removed`.

Run: `( cd tests/brainstorm-server && npm test ) 2>&1 | tail -3` and `node tests/pi/test-pi-extension.mjs 2>&1 | tail -3`

Expected: both green (on 6.13.0 they were: the JS files plus 4 and 7 shell-side passes, and Pi 6/6). Record the tail lines in your report. Then commit this one problem:

```bash
git add docs/testing.md
git commit -m "docs(testing): the guide hid two suites and its example loop reported green on failure"
```

- [ ] **Step 8: Confirm the three commits and a clean tree**

```bash
git log --oneline -3
git status --short
```

Expected: the three commits from Steps 3, 4, and 7 in that order and nothing left in the tree. Task 0 makes three commits on purpose: the repository's rule is one problem per change, and these are three problems that share a cause (the 6.13.0 sweep), not one problem.

---

---

### Task 1: Establish the post-Part-1 baseline

**Risk tier:** standard — no code changes, but every later task's verdict is measured against the numbers this task records.

**Files:**
- Create: `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`
- Modify: `skills/requesting-code-review/scripts/gate-telemetry` and `tests/codex-review-gate/test-gate-telemetry.sh` (`--until`, the upper bound that makes the historical read disjoint from the cohort; added in this task's fix round after the Codex gate found the unbounded read contaminated)

**Interfaces:**
- Consumes: Part 1's released `gate-telemetry` with churn metrics, Task 0's `--since` flag, and Part 1's `verdict-normalize` fix.
- Produces: `gate-telemetry --until <ISO-8601>`, the mirror of `--since`; together they select the half-open window [since, until), so two reads sharing a boundary are disjoint by construction.
- Produces: the evidence note that every later task appends a section to. Its "Baselines" section holds two lines: the historical fleet figures (every cached run predates 6.13.0) and the post-release cohort read through `--since`, which is expected to be small or empty when this task runs and is re-read at release. Arm verdicts rest on each arm's own control and treatment runs, never on these fleet lines.

**Context the implementer needs.** The 2026-09-05 analysis measured task gates at mean 2.24 rounds with 27% converging in round 1, over 468 runs. Every run in the telemetry cache still predates 6.13.0, so an unbounded `gate-telemetry --all` reports exactly that pre-fix history and must not be labeled a post-fix baseline (the 6.13.0 sweep flagged precisely this). This task records the history as history, reads the post-release cohort through `--since` (bounded at the release commit's timestamp), and states plainly that the arms are judged by their own control and treatment runs.

- [ ] **Step 1: Confirm Part 1 shipped and is in this tree**

```bash
git merge-base --is-ancestor v6.13.0 HEAD && echo "v6.13.0 is an ancestor of HEAD"
grep '"version"' .claude-plugin/plugin.json
```

Expected: the echo line, and a version of 6.13.0 or later. If either fails, STOP. This plan's measurements are invalid on a tree that does not contain the release.

- [ ] **Step 2: Read both baselines from the shipped tool, each bounded at the release commit**

An unbounded `--all` is not history: by the time this task runs, the cache already holds this plan's own gate rounds, so the historical line must be bounded from above and the cohort from below at the same instant.

```bash
since="$(git log -1 --format=%cI v6.13.0)"
bash skills/requesting-code-review/scripts/gate-telemetry --all --until "$since"
```

Copy that fleet `Rounds by gate` line verbatim; it is the historical line, and every run behind it predates the release commit. Then read the post-release cohort:

```bash
bash skills/requesting-code-review/scripts/gate-telemetry --all --since "$since"
```

Copy that fleet line too, with the `$since` value. Expect it to be small: real post-release gate runs accrue only as this plan and later work run. Finally run the unbounded `--all` once and confirm, for the task gate, that the historical run count plus the cohort run count equals the unbounded count; write those three numbers into the note as the disjointness check.

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

The gate changes in this plan all move one metric — Codex rounds to
convergence — so a single run cannot attribute a movement to a cause. Each
arm ships alone, with its own control and treatment runs.

## Baselines

Historical fleet (runs before the 6.13.0 release commit; gate-telemetry --all --until <the release commit's %cI timestamp>):
<paste the bounded historical fleet "Rounds by gate" line here>

Post-release cohort (gate-telemetry --all --since <the release commit's %cI timestamp>, read <today's date>):
<paste the bounded cohort fleet "Rounds by gate" line here, or "empty" if no run has landed yet>

Disjointness verified: task gate historical <n> runs + cohort <m> runs = unbounded <n+m> runs.

The historical line is context, not a control: it is the number Part 1 set
out to move. The post-release cohort is re-read at release so the note
carries the fleet state after this plan's arms shipped. Each arm's verdict
rests on its own control and treatment runs, recorded in its section.

## Task 0 follow-ups (mechanical; no arm)

Task 0 corrected the testing guide, the review-base default, and the fleet
churn assertion, and added `--since`. None changes what an agent writes or
what a reviewer judges; each is checked by an offline assertion named in the
plan. No before/after runs were made for them.

## Arms
```

- [ ] **Step 6: Commit**

```bash
git add docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "docs(evals): record the historical fleet churn and the empty post-6.13.0 cohort the calibration arms are judged beside"
```

---

### Task 2: Arm A — severity calibration in the code-gate focus text

**Risk tier:** standard — behavior-shaping prose in a gate section file, with losslessness bookkeeping; the measurement runs real Codex reviews, not sessions in dangerous mode.

**Files:**
- Modify: `skills/requesting-code-review/recipe-code.md:53` (per-task focus), `:57` (the sentence after it), `:71` (final whole-branch focus), `:81` (code-review-request focus)
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (four new rows)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 4)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (one new assertion)
- Create (evals repo): `evals/scripts/codex-focus-arm.sh`
- Create (evals repo): `evals/fixtures/codex-focus-arm/` (two fixture repos built from checked-in files)

**Interfaces:**
- Consumes: Task 1's evidence note (this task appends a section). Real Codex through codex-plugin-cc: `CODEX_PATH` is derived from the preflight's `.codexPath` in Step 3 (nothing exports it beforehand), the preflight must be `ok`, and a probe must answer; if not, this task is BLOCKED, not degraded.
- Produces: an appended `### Arm A` section. No callable interface.

**Context the implementer needs.** codex-plugin-cc's `prompts/adversarial-review.md` wraps our focus text in a template that never defines the severities its schema enumerates, so the reviewer picks a severity with no scope anchor: 30% of task-gate blocking captures carried nothing critical or high, and — as this arm's own control runs showed on 2026-09-07 — the same reviewer rated one genuine crash-and-wrong-result defect high once and medium twice across three reads. The template is a plugin file a future version overwrites; the focus string is the only durable channel we own. 6.13.0 fixed the downstream consequence in `verdict-normalize`; this arm attacks the cause.

The plan gate rejected measuring this through Quorum: the harness seeds a stub Codex whose verdicts are canned, so it cannot classify severity, and asserting the calibration phrase in the launch made the control fail by construction. This arm therefore measures the reviewer directly: the same fixture diff, reviewed by real Codex three times under the control focus (today's recipe text) and three times under the treatment focus (with the calibration), each capture normalized by `verdict-normalize`. Two fixtures: **M** adds a branch nobody tested and contains no defect — the calibration says medium; **H** adds the same branch with a reachable crash — high under either focus, the guard that the calibration scopes severity rather than suppressing it.

The defect and spec D7 cover every JSON code gate, not only the per-task one, so the same three calibration sentences go into all three code-review focus strings in `recipe-code.md` — per-task (line 53, source line 326), final whole-branch (line 71, source line 344), and code-review request (line 81, source line 354); all three verified byte-for-byte against the pinned original, none a referent. The runner measures the per-task focus; the other two carry identical sentences, and a contract assertion pins all three so none can drift apart.

- [ ] **Step 1: Create the fixtures and the runner in the evals repo**

Create `evals/fixtures/codex-focus-arm/M/` with three files.

`lib.js`:

```js
"use strict";
// Rates arrive as numbers or numeric strings; undefined means "not set".
function parseRate(input) {
  if (input === undefined) return 0;
  if (typeof input === "string" && input.endsWith("%")) {
    return Number(input.slice(0, -1)) / 100;
  }
  return Number(input);
}
module.exports = { parseRate };
```

`test.js`:

```js
"use strict";
const assert = require("node:assert");
const { parseRate } = require("./lib.js");
assert.strictEqual(parseRate(undefined), 0);
assert.strictEqual(parseRate(0.25), 0.25);
assert.strictEqual(parseRate("0.5"), 0.5);
console.log("ok");
```

`REQUIREMENTS.md`:

```markdown
# Task: accept percent strings in parseRate

`parseRate` must accept a string ending in `%` and return the fraction
(`"25%"` -> 0.25). Existing behaviour for numbers, numeric strings, and
`undefined` is unchanged. Tests for the new branch are not part of this task.
```

Create `evals/fixtures/codex-focus-arm/H/` with the same `test.js` and `REQUIREMENTS.md`, and this `lib.js` (the `%` branch reads the first digit run and dereferences the match without checking it, so a bare `"%"` — a reachable malformed input — throws):

```js
"use strict";
// Rates arrive as numbers or numeric strings; undefined means "not set".
function parseRate(input) {
  if (input === undefined) return 0;
  if (typeof input === "string" && input.endsWith("%")) {
    const digits = input.match(/\d+(\.\d+)?/);
    return Number(digits[0]) / 100;
  }
  return Number(input);
}
module.exports = { parseRate };
```

Create `evals/scripts/codex-focus-arm.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# codex-focus-arm.sh <hyperpowers-root> <codex-plugin-root> <control|treatment> <out-dir>
# Reviews fixtures M and H with real Codex three times each under one focus
# text and normalizes every capture with hyperpowers' verdict-normalize.
# Each fixture becomes a two-commit git repo: base = lib.js without the %
# branch, head = the fixture as checked in. Runs are sequential and blocking;
# launch this script with the shell tool's background option and watch its
# log, never a bare foreground call a harness timeout can kill mid-review.
set -uo pipefail
root="${1:?hyperpowers root}"; codex="${2:?codex-plugin-cc root}"; arm="${3:?control|treatment}"; out="${4:?out dir}"
here="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$out"
control_focus() {
  printf '%s' "Task-scoped review. Requirements: $1/REQUIREMENTS.md. Implementer report: $1/REQUIREMENTS.md. Review package: $1/review.diff. Global constraints: $1/REQUIREMENTS.md. Review for task compliance and code quality. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
}
treatment_focus() {
  printf '%s' "Task-scoped review. Requirements: $1/REQUIREMENTS.md. Implementer report: $1/REQUIREMENTS.md. Review package: $1/review.diff. Global constraints: $1/REQUIREMENTS.md. Review for task compliance and code quality. Severity is scoped to this diff: critical or high means a defect in the changed lines that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
}
for fx in M H; do
  work="$(mktemp -d "${TMPDIR:-/tmp}/focus-arm-$fx.XXXXXX")"
  cp "$here/fixtures/codex-focus-arm/$fx/"* "$work/"
  git -C "$work" init -q
  # Base: the same module without the % branch.
  node -e 'const fs=require("fs");const p=process.argv[1];const s=fs.readFileSync(p,"utf8").split("\n").filter(l=>!/endsWith\("%"\)|slice\(0, -1\)|digits|^  }$/.test(l)).join("\n");fs.writeFileSync(p,s)' "$work/lib.js"
  git -C "$work" -c user.email=t@t -c user.name=t add -A && git -C "$work" -c user.email=t@t -c user.name=t commit -qm base
  base="$(git -C "$work" rev-parse HEAD)"
  cp "$here/fixtures/codex-focus-arm/$fx/lib.js" "$work/lib.js"
  git -C "$work" -c user.email=t@t -c user.name=t commit -qam "accept percent strings"
  git -C "$work" diff "$base" HEAD > "$work/review.diff"
  for i in 1 2 3; do
    if [ "$arm" = control ]; then focus="$(control_focus "$work")"; else focus="$(treatment_focus "$work")"; fi
    cap="$out/$fx-$arm-$i.json"
    ( cd "$work" && node "$codex/scripts/codex-companion.mjs" adversarial-review --base "$base" --json "$focus" ) > "$cap" 2>"$cap.err"
    printf '%s %s %s ' "$fx" "$arm" "$i"; bash "$root/skills/requesting-code-review/scripts/verdict-normalize" "$cap"
  done
done
```

Make it executable (`chmod +x evals/scripts/codex-focus-arm.sh`). Before committing, prove the base-stripping line does what the comment says: run it on a copy of each fixture's `lib.js` and confirm the result is the module without the `%` branch and still parses (`node -e 'require(process.argv[1])' <copy>`). If the filter drops a wrong line, fix the regex here rather than in the fixture.

- [ ] **Step 2: Commit the fixtures and runner in the evals repo**

```bash
git -C evals add fixtures/codex-focus-arm scripts/codex-focus-arm.sh
git -C evals commit -m "arm: the code-gate focus text reviewed by real Codex, with and without a severity scope"
```

- [ ] **Step 3: Run the control arm**

Resolve the companion path from the preflight first — `CODEX_PATH` is not set by anything else, and every new shell must re-derive it the same way:

```bash
CODEX_PATH="$(bash skills/requesting-code-review/scripts/codex-preflight | node -e 'const p=JSON.parse(require("fs").readFileSync(0,"utf8"));if(p.status!=="ok"){console.error("preflight: "+p.status+" "+(p.reason||""));process.exit(2)}console.log(p.codexPath)')" && echo "CODEX_PATH=$CODEX_PATH"
node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --json "Reply with the single word ok." | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8"));process.exit(j.status===0?0:1)' && echo "probe ok"
```

Expected: a real path under `~/.claude/plugins/cache/openai-codex/codex/` and `probe ok`. If the preflight is not `ok` or the probe fails, this task is BLOCKED: report and stop; do not substitute the stub. The runner takes `CODEX_PATH` as its second argument, so the block that launches it must run in a shell where this assignment has happened.

Then, with `recipe-code.md` unmodified, run the control arm in the background and watch its log until it prints six normalized lines:

```bash
bash evals/scripts/codex-focus-arm.sh /Users/johnss51/Development/agents/hyperpowers "$CODEX_PATH" control "$TMPDIR/focus-arm/control" > "$TMPDIR/focus-arm/control.log" 2>&1
```

Record the six lines. Expected: fixture M normalizes `blocking` in at least 2 of 3 (the untested branch is called high); fixture H normalizes `blocking` in 3 of 3.

If M normalizes `approved` in 2 or more of 3, the untested-path half of the hypothesis does not reproduce with this reviewer: record that half as null in the arm's section, but do not stop yet, because the guard fixture H is a measurement too. If H normalized `blocking` in fewer than 3 of 3 control runs, the reviewer under-rates a genuine crash-and-wrong-result defect — the mirror of the defect this arm set out to fix, and one the calibration sentence names as high — so proceed to the treatment under the amended rule in Step 8. Only when M is approved (2 or more of 3) AND H is blocked 3 of 3 under control is there nothing left to measure: then append the null result, commit it, and skip to the next task. (Amended 2026-09-07 by the human partner after the control runs showed M approved 3/3 and H blocked 1/3.)

- [ ] **Step 4: Add the calibration to all three focus strings**

In `skills/requesting-code-review/recipe-code.md`, replace line 53 in full with this single line:

```
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Task-scoped review. Requirements: <TASK_BRIEF_PATH>. Implementer report: <IMPLEMENTER_REPORT_PATH>. Review package: <REVIEW_PACKAGE_PATH>. Global constraints: <GLOBAL_CONSTRAINTS_PATH>. Review for task compliance and code quality. Severity is scoped to this diff: critical or high means a defect in the changed lines that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

Replace line 57 in full with:

```
dispatched. Apart from the severity calibration, the focus text stays short because the task brief, implementer
```

Replace line 71 in full with:

```
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <MERGE_BASE_SHA> --json "Final whole-branch review. Branch review package: <BRANCH_REVIEW_PACKAGE_PATH>. Plan or requirements: <PLAN_OR_REQUIREMENTS_PATH>. Minor findings ledger, if present: <MINOR_LEDGER_PATH>. Tier-skip summary, if any: <TIER_SKIPS_PATH>. Review for correctness, requirements coverage, integration risk, and code quality. Severity is scoped to this diff: critical or high means a defect in the changed lines that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

Replace line 81 in full with:

```
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Code review. Requirements or review context: <PLAN_OR_REQUIREMENTS_CONTEXT>. Review for correctness, requirements alignment, integration risk, and code quality. Severity is scoped to this diff: critical or high means a defect in the changed lines that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

Before editing, confirm each target line is what this plan expects (`sed -n '53p;57p;71p;81p'`); if a line has moved, stop and report rather than guess. The treatment focus in `codex-focus-arm.sh` is line 53's text with the placeholders filled; if you change one, change the other in the same commit.

Then add one assertion to `tests/codex-review-gate/test-gate-contract.sh`, immediately before its final status block, so the three copies cannot drift apart:

```bash
n="$(grep -c 'Severity is scoped to this diff' "$GATE")"
if [ "$n" -eq 3 ]; then
  pass "all three code-review focus strings carry the severity calibration"
else
  fail "all three code-review focus strings carry the severity calibration (found $n)"
fi
```

- [ ] **Step 5: Add the four losslessness rows**

Do not retype the replacement lines. Extract them from the file you just edited, so the table's copy is byte-identical to the file's by construction — a single drifted character fails the proof.

```bash
printf '%s\t%s\t%s\n' 326 severity-calibration "$(sed -n '53p' skills/requesting-code-review/recipe-code.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
printf '%s\t%s\t%s\n' 330 severity-calibration "$(sed -n '57p' skills/requesting-code-review/recipe-code.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
printf '%s\t%s\t%s\n' 344 severity-calibration "$(sed -n '71p' skills/requesting-code-review/recipe-code.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

```bash
printf '%s\t%s\t%s\n' 354 severity-calibration "$(sed -n '81p' skills/requesting-code-review/recipe-code.md)" >> tests/codex-review-gate/gate-post-split-edits.tsv
```

Confirm all four rows landed with exactly two tabs each:

```bash
tail -4 tests/codex-review-gate/gate-post-split-edits.tsv | awk -F'\t' '{print NF, $1, $2}'
```

Expected: four rows reading `3 <srcline> severity-calibration` for 326, 330, 344, 354.

- [ ] **Step 6: Bump the pinned edit count**

Read the current pin: `grep -n 'post_edit_count" -eq' tests/codex-review-gate/test-gate-split-lossless.sh`. Call it N. This task appended four rows, so set the `-eq N` test and both adjacent `exactly N declared post-split edits` message strings to N plus 4. Do not copy a number from this plan: N is 10 only if no earlier task has added rows.

- [ ] **Step 7: Prove the edit is lossless**

```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
```

Expected: `STATUS: PASSED` with 28 PASS and 0 SKIP.

```bash
bash tests/codex-review-gate/test-gate-contract.sh
```

Expected: `STATUS: PASSED`, including the new three-copies assertion.

- [ ] **Step 8: Run the treatment arm**

Re-derive `CODEX_PATH` with Step 3's preflight command if this is a new shell, then:

```bash
bash evals/scripts/codex-focus-arm.sh /Users/johnss51/Development/agents/hyperpowers "$CODEX_PATH" treatment "$TMPDIR/focus-arm/treatment" > "$TMPDIR/focus-arm/treatment.log" 2>&1
```

Record the six lines.

**Decision rule (as amended 2026-09-07 with the spec's D7: classification accuracy on the production round-1 prompt shape).** After Task 2's Codex gate, the measurement moved to the production prompt shape — the round-1 lens skeleton plus the recipe's complete focus string — with a defect-free fixture M, the crash fixture H, and an omitted-requirement fixture O, three reviews per fixture per arm. The arm wins if treatment H and treatment O each block 3 of 3 AND treatment M is approved in at least 2 of 3; control numbers are recorded beside them. The earlier text of this rule is kept for the record: the arm wins if either half is measured and won: (a) the over-classification half — control M blocked in at least 2 of 3, treatment M approved in at least 2 of 3, and treatment H blocked 3 of 3; or (b) the under-classification half — control H blocked in fewer than 3 of 3, treatment H blocked 3 of 3, and treatment M still approved in at least 2 of 3 (the calibration must not reintroduce blocking on the untested path). In every other case the arm loses and is reverted. An H approval under treatment means the calibration failed to lift a real defect to high, or worse suppressed it; a treatment M block means it over-corrected. The evidence section states which half was measured and the numbers that decided it.

- [ ] **Step 9: If the arm lost, revert it**

```bash
git show HEAD:skills/requesting-code-review/recipe-code.md > skills/requesting-code-review/recipe-code.md
git show HEAD:tests/codex-review-gate/gate-post-split-edits.tsv > tests/codex-review-gate/gate-post-split-edits.tsv
git show HEAD:tests/codex-review-gate/test-gate-split-lossless.sh > tests/codex-review-gate/test-gate-split-lossless.sh
git show HEAD:tests/codex-review-gate/test-gate-contract.sh > tests/codex-review-gate/test-gate-contract.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
```

Then write the losing result into the evidence note and skip to Step 11. A reverted arm still gets its section: a measured null is the evidence that stops someone re-proposing it.

- [ ] **Step 10: Append the evidence section**

Add an `### Arm A — severity calibration in the focus text` section to `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` recording: the defect and why the calibration cannot live in codex-plugin-cc's template; that the same sentences went into all three code-review focus strings and the contract assertion that pins them; why the measurement is a direct reviewer run rather than a Quorum scenario; the Codex model and reasoning effort the runs used (from `${CODEX_HOME:-$HOME/.codex}/config.toml`); the twelve normalized results, fixture by fixture and arm by arm, with the capture paths; and the verdict against both sides of the decision rule. State H's numbers explicitly even when they are a clean 3 of 3 — an unstated guard is indistinguishable from an unrun one.

- [ ] **Step 11: Commit**

```bash
git add skills/requesting-code-review/recipe-code.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh tests/codex-review-gate/test-gate-contract.sh docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
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
- Assert in `post()` the complete fixed shape, structurally: the recorded focus string, with whitespace normalized, is exactly two parts in this order — the round-aware preamble (`This is re-review round 2.` through `Do not raise new Minor (medium/low) findings on a re-review.`, with the ledger path filled in where the preamble names it) and the §3 per-task focus string verbatim as `recipe-code.md:53` renders it with the paths filled in — and nothing else. Anything before, between, or after those parts is a failure, including a second copy of the ledger path.
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
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run scenarios/codex-gate-re-review-focus-is-fixed --coding-agent claude-auto
```

Record each run's word count and pass or fail. Expected: the control fails, with focus strings well over 250 words.

If all three pass, STOP: append the null result to the evidence note as this arm's section (control passed; no change made), commit that note with the message from this task's last step (adjusted to say the control passed), and skip to the next task; the scenario stays committed in the evals repo, because a null result is evidence too.

- [ ] **Step 4: Replace the line with the recipe**

In `skills/requesting-code-review/gate-fix-loop.md`, replace line 22 in full with this single line:

```
The round 2+ invocation has exactly two parts, in order: the round-aware preamble, which names the ledger path, and the §3 recipe's own focus string unchanged. The ledger file carries the findings, the fixes, and the diff references, so the focus string carries none of them — measured re-review focus strings that restated the ledger inline ran to a median of 464 words and a maximum of 35468. The preamble is:
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
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run scenarios/codex-gate-re-review-focus-is-fixed --coding-agent claude-auto
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

### Task 4: gate-round computes the task ceiling from consumed rounds

**Risk tier:** high — `gate-round` is the gate's round counter and is named in the risk-tier rubric as approval-authority code.

**Files:**
- Modify: `skills/requesting-code-review/scripts/gate-round`
- Modify: `skills/requesting-code-review/gate-fix-loop.md:87`
- Modify: `skills/subagent-driven-development/SKILL.md:491-503`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 1)
- Test: `tests/codex-review-gate/test-gate-round.sh`

**Interfaces:**
- Consumes: Task 1's evidence note (this task appends a section).
- Produces: a new `gate-round` flag, `--consumed <n>`. It sets the ceiling to `5 - n`, the SDD shared per-task cap minus the fix rounds already spent outside this gate. It is mutually exclusive with `--ceiling`; supplying both is a usage error, exit 2. The written state file gains a `consumed` field alongside `round`, `ceiling`, and `gate`. The stdout shape is otherwise unchanged.

**Context the implementer needs.** SDD's per-task Codex gate has no ceiling of its own. Its rounds count against the task's shared five-round fix cap, so the controller must compute `5 - <non-gate fix rounds consumed>` before every `gate-round` call. In real runs (the counter's own state files over the historical window ending 2026-09-06T22:45:00-07:00), 20 task gates recorded ceilings of 1, 2, 6, and 7. Six and seven are impossible: they exceed the cap. The subtraction does not survive contact, so the script should do it.

Two details the implementation must get right:

- **Ceiling zero is now reachable.** With `--consumed 5` the cap is fully spent and the ceiling is 0. The advance path handles that correctly, because `round=1` is greater than `0`. The peek path does not: its verdict expression tests `[ "$c" -gt 0 ]` first, so a zero ceiling short-circuits to `proceed`. Today that is a latent quirk reachable only by passing `--ceiling 0` explicitly; `--consumed` makes it reachable through ordinary use, so fix it in this task.
- **A task ceiling above 5 is impossible.** Reject a task gate with `--ceiling` greater than 5 as a usage error — judged against the effective gate, which is the `--gate` argument or, when a later call omits it, the gate the state file recorded, so an inherited task gate cannot carry a ceiling past the cap. Flag presence is tracked apart from the flag's value: an explicitly empty `--consumed ''` is a supplied value and fails validation, and supplying both `--consumed` and `--ceiling` is rejected even when one of them is empty. That is safe: the gate doc's step 0 already says a non-zero `gate-round` exit is treated as backstop, so the failure mode is fail-closed rather than a stall.

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
12. After `gate-round "$gd" --consumed 2 --gate task` has advanced once, `gate-round "$gd" --ceiling 7` with no `--gate` exits 2 and leaves `gate-round.json` at `"round":1`.
13. `gate-round "$gd" --consumed ''` exits 2, and `gate-round "$gd" --consumed '' --ceiling 3 --gate task` exits 2.
14. Every case that expects exit 2 captures `$?` and compares it to 2 exactly — a bare `command && fail || pass` accepts any failure and does not pin the contract — and, on a fresh directory, asserts that no `gate-round.json` was written.
15. Numeric values are persisted in canonical decimal form: `gate-round "$gd" --consumed 01 --gate task` advanced twice leaves a `gate-round.json` that parses as JSON with `"consumed":1` and `"round":2`, and `gate-round "$gd" --ceiling 03 --gate final` writes `"ceiling":3` and is readable by the next call. A leading-zero token written unquoted is invalid JSON and turns the counter into an unreadable file that every later call rejects.
16. Oversized numeric tokens are rejected before any arithmetic: `gate-round "$gd" --consumed 18446744073709551616 --gate task` and `gate-round "$gd" --ceiling 18446744073709551619 --gate task` each exit 2 and write no state; `gate-round "$gd" --ceiling 18446744073709551619 --gate final` exits 2 as well; `gate-round "$gd" --consumed 05 --gate task` still derives ceiling 0, and `gate-round "$gd" --ceiling 0000003 --gate final` still records `"ceiling":3`. A digit string wider than the machine word wraps under `$(( ))` into the accepted range, so the bound is checked on the zero-stripped string first.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
bash tests/codex-review-gate/test-gate-round.sh
```

Expected: FAIL. `--consumed` is an unknown argument today, so cases 1 through 4, 7, and 8 exit 2 with `gate-round: unknown arg --consumed`. Case 5 reports `proceed` where the test wants `backstop`. Case 9 succeeds where it should fail. Cases 6, 10, and 11 pass already — 6 is a characterization test, so prove it is not vacuous by temporarily making the peek unconditional, watching it fail, and restoring the script with `git show HEAD:skills/requesting-code-review/scripts/gate-round > skills/requesting-code-review/scripts/gate-round`.

- [ ] **Step 3: Add the flag, the validation, and the peek fix**

In `skills/requesting-code-review/scripts/gate-round`, first add the helper every bound relies on. Immediately above the `gd="${1:-}"; shift || true` line, insert:

```bash
# Leading zeros are padding, not magnitude. Stripping them first means the
# bounds below measure the number the caller meant, and leaves a string that is
# already canonical decimal -- so nothing downstream has to convert it.
strip_leading_zeros() {
  local s
  s="${1#"${1%%[!0]*}"}"
  [ -n "$s" ] || s=0
  printf '%s' "$s"
}
```

Then extend the argument loop. Replace:

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
# Presence and value are separate facts. Treating an empty value as an absent
# flag let --consumed '' skip both its own range check and the exclusion with
# --ceiling. Every flag that takes a value also refuses to run off the end of
# the argument list: an unbound $2 under `set -u` dies with a bash diagnostic
# and exit 1, which is not the exit-2 usage contract callers are promised.
ceiling=""; ceiling_set=0; peek=0; gate=""; consumed=""; consumed_set=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ceiling) [ $# -ge 2 ] || { echo "gate-round: --ceiling needs a value" >&2; exit 2; }; ceiling="$2"; ceiling_set=1; shift 2 ;;
    --consumed) [ $# -ge 2 ] || { echo "gate-round: --consumed needs a value" >&2; exit 2; }; consumed="$2"; consumed_set=1; shift 2 ;;
    --gate) [ $# -ge 2 ] || { echo "gate-round: --gate needs a value" >&2; exit 2; }; gate="$2"; shift 2 ;;
    --peek) peek=1; shift ;;
    *) echo "gate-round: unknown arg $1" >&2; exit 2 ;;
  esac
done

# SDD's per-task gate has no ceiling of its own: its rounds count against the
# task's shared five-round fix cap. Making the controller subtract did not
# survive contact — 20 measured task gates recorded ceilings of 1, 2, 6, and 7,
# and 6 and 7 exceed the cap outright. --consumed states the one number the
# controller can read off its ledger and lets the script do the arithmetic.
SDD_TASK_CAP=5
if [ "$consumed_set" -eq 1 ] && [ "$ceiling_set" -eq 1 ]; then
  echo "gate-round: --consumed and --ceiling are mutually exclusive" >&2
  exit 2
fi
# Every number here is printed unquoted into the state file and into the
# verdict, so a token that bash accepts but JSON does not is not a cosmetic
# defect: `--consumed 01` wrote "consumed":01, the call exited 0, and every
# later call exited 2 on a counter nothing could parse.
#
# Digits alone are not a bound, and neither is a numeric comparison, because
# `$(( ))` is fixed-width signed: 18446744073709551616 wraps to 0, sailed past
# `-le 5`, and spent none of the cap. So every bound below is decided on the
# STRING, before arithmetic ever sees the value. For --consumed the whole
# accepted range is a single digit, which a character class settles outright.
# That class and SDD_TASK_CAP state the same bound -- change them together.
if [ "$consumed_set" -eq 1 ]; then
  case "$consumed" in
    ''|*[!0-9]*) echo "gate-round: --consumed must be a non-negative integer (got '$consumed')" >&2; exit 2 ;;
  esac
  consumed="$(strip_leading_zeros "$consumed")"
  case "$consumed" in
    [0-5]) : ;;
    *) echo "gate-round: --consumed $consumed exceeds the shared cap of $SDD_TASK_CAP" >&2; exit 2 ;;
  esac
  ceiling=$((SDD_TASK_CAP - consumed))
fi
# The ceiling gets the same treatment on EVERY gate type. Only the task gate
# validated it before, so `--ceiling 03` and even `--ceiling foo` reached the
# file on the others -- the latter exiting 0 with a proceed verdict after its
# own comparison had errored. The non-task gates have no cap to enforce, so the
# width bound is the only thing standing between them and a wrapped number.
# Measuring the stripped string is safe arithmetic: a length is bounded by the
# argument list, not by what the caller wrote in it.
# A ceiling derived from --consumed skips this -- it is arithmetic on a digit.
GATE_CEILING_MAX_DIGITS=9
if [ "$ceiling_set" -eq 1 ]; then
  case "$ceiling" in
    ''|*[!0-9]*) echo "gate-round: --ceiling must be a non-negative integer (got '$ceiling')" >&2; exit 2 ;;
  esac
  ceiling="$(strip_leading_zeros "$ceiling")"
  [ "${#ceiling}" -le "$GATE_CEILING_MAX_DIGITS" ] || {
    echo "gate-round: --ceiling must be at most $GATE_CEILING_MAX_DIGITS digits (got '$ceiling')" >&2
    exit 2
  }
fi
```

Then, after the state file has been read — immediately after the `fi` that closes `if [ -f "$state" ]; then` and before `if [ "$peek" -eq 1 ]; then` — insert the task-cap check. It reads the EFFECTIVE gate, because a continuation call may omit `--gate` and inherit `task` from the state file:

```bash
# A task-gate ceiling above the shared cap is arithmetically impossible. The
# gate to hold to the cap is the one being counted, which is not always the one
# named on this call: a continuation may omit --gate, inherit task from the
# state file, and be written back as task all the same. So the check reads the
# effective gate, after state is loaded and before anything is written. Exit 2
# is fail-closed here: the gate doc's step 0 treats a non-zero gate-round exit
# as backstop, so a bad ceiling stops the round rather than stalling the loop.
# The ceiling is canonical decimal by this point and no wider than the bound
# above, so only the cap is left -- decided on the string for the same reason
# --consumed is.
if [ "${gate:-$prev_gate}" = "task" ] && [ -n "$ceiling" ]; then
  case "$ceiling" in
    [0-5]) : ;;
    *) echo "gate-round: task-gate ceiling $ceiling exceeds the shared cap of $SDD_TASK_CAP" >&2; exit 2 ;;
  esac
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
  # `expr "$c" + 0` cannot do this job: expr exits 1 whenever the expression
  # evaluates to zero, so it condemned a legitimate ceiling of 0 as unreadable.
  case "$c" in
    '') : ;;
    *[!0-9]*)
      echo "gate-round: state file exists but is unreadable: $state" >&2
      exit 2 ;;
  esac
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

- [ ] **Step 4: Update the script's header and usage contracts**

Replace the runtime usage message on line 11 of the same file, `usage: gate-round GATE_DIR --ceiling N [--gate T] [--peek]`, with `usage: gate-round GATE_DIR (--ceiling N | --consumed N) [--gate T] [--peek]`, and add one test to Step 1's list: `gate-round "$gd" --consumed` with no value exits 2.

Replace line 2 of the same file:

```
# gate-round GATE_DIR --ceiling N [--peek] — mechanical round counter for
```

with:

```
# gate-round GATE_DIR (--ceiling N | --consumed N) [--gate T] [--peek] —
# mechanical round counter for
```

and append these two lines to the header comment block, immediately above `set -uo pipefail`:

```
# A ceiling is at most 9 digits wide once leading zeros are stripped; wider is a
# usage error, because bash arithmetic is fixed-width and a wider number wraps.
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
bash tests/codex-review-gate/test-gate-round.sh
```

Expected: `ALL PASS`.

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
     `--ceiling` for a task gate — that is how twenty measured task gates
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

Add `### Consumed-round accounting` to the evidence note recording: the 20 out-of-pattern task-gate ceilings (values 1, 2, 6, and 7; seven of them above the cap) with the window and the command that counted them, why the fix is arithmetic in the script rather than an eval-gated prose change, and the test cases that now pin it.

- [ ] **Step 11: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-round skills/requesting-code-review/gate-fix-loop.md skills/subagent-driven-development/SKILL.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh tests/codex-review-gate/test-gate-round.sh docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "fix(gate): task gates recorded ceilings the shared cap makes impossible"
```

---

### Task 5: An approved-with-notes verdict keeps its notes

**Risk tier:** standard — one gate section line with losslessness bookkeeping, plus a contract assertion; it changes what the controller records, not what the reviewer judges.

**Files:**
- Modify: `skills/requesting-code-review/gate-findings.md:48`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh` (edit count plus 1)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (one new assertion)

**Interfaces:**
- Consumes: Task 1's evidence note (this task appends a section), and 6.13.0's `verdict-normalize`, whose JSON path now returns `{"result":"approved","verdict":"needs-attention",...}` for a capture with only medium/low findings.
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

### Task 6: Upstream port — the project's suite defines green

**Risk tier:** standard — behavior-shaping prose in a frequently-loaded skill, requiring fork-side evidence.

**Files:**
- Modify: `skills/test-driven-development/SKILL.md:183`
- Create (evals repo): `evals/scenarios/tdd-runs-the-project-suite/`

**Interfaces:**
- Consumes: Task 1's evidence note (this task appends a section).
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

- [ ] **Step 2b: Add the Vertex Sonnet actor**

The `claude-sonnet` actor requires a direct `ANTHROPIC_API_KEY`, which this host does not have; Sonnet runs through Vertex instead. Create `evals/coding-agents/claude-sonnet-vertex.yaml` by copying `evals/coding-agents/claude-vertex.yaml`, then set `name: claude-sonnet-vertex` and `model:` to the Vertex publisher id of the Sonnet model enabled on this project. Before committing, prove the id works with a one-shot call under the host's Vertex environment (`claude --model <id> -p 'reply with the single word ok'`); if no Sonnet id answers, record that in the evidence section and run the matrix without it.

```bash
git -C evals add coding-agents/claude-sonnet-vertex.yaml
git -C evals commit -m "actor: Sonnet on Vertex, for hosts without a direct Anthropic key"
```

- [ ] **Step 3: Run the control**

One run per available agent against the unmodified tree — Opus through `claude-auto`, Sonnet through `claude-sonnet-vertex` (Step 2b), and Codex — so a result that is really one model's quirk cannot pass as a fleet effect. Kimi is not installed on this host and the direct-API `claude-sonnet` actor cannot start without an Anthropic key, so neither is in the matrix. An agent that fails at the setup stage is dropped from BOTH arms and the failure is recorded in the evidence section:

```bash
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run-all --scenarios tdd-runs-the-project-suite --coding-agents claude-auto,claude-sonnet-vertex,codex --jobs 2
```

Record each result. Expected: most fail.

If every agent that ran passes in the control, STOP: append the null result to the evidence note as this arm's section, commit it, and skip to the next task. Upstream's measurement does not license shipping into this fork without fork-side evidence.

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

One run per agent that ran in the control, against the modified tree:

```bash
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run-all --scenarios tdd-runs-the-project-suite --coding-agents claude-auto,claude-sonnet-vertex,codex --jobs 2
```

Record each result.

**Decision rule:** let N be the number of agents that completed BOTH arms. The arm wins if treatment passes minus control passes is at least half of N, rounded up: N = 3 requires a difference of at least 2 (0 to 2, 0 to 3, or 1 to 3); N = 2 requires a difference of at least 1 (0 to 1, 0 to 2, or 1 to 2). A control in which every agent passed is the null result of Step 3, not a loss. N below 2 is also a null result: record it and do not ship the port.

- [ ] **Step 6: If the arm lost, revert it**

```bash
git show HEAD:skills/test-driven-development/SKILL.md > skills/test-driven-development/SKILL.md
```

Then record the loss and skip to Step 8.

- [ ] **Step 7: Append the evidence section**

Add `### Upstream port — the project's suite defines green` to the evidence note: upstream's commit and its measurement, this fork's scenario, control and treatment results run by run and by agent, which model families the runs covered, any actor dropped at setup with the reason, and the verdict.

- [ ] **Step 8: Commit**

```bash
git add skills/test-driven-development/SKILL.md docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "feat(tdd): a green run of one test file was being reported as a green suite"
```

If the arm lost, commit only the evidence note, with the message `docs(evals): the upstream project-suite bullet did not reproduce a fork-side win`.

---

### Task 7: Upstream port — the tooling question in a new project's design

**Risk tier:** standard — behavior-shaping prose in a frequently-loaded skill, requiring fork-side evidence.

**Files:**
- Modify: `skills/brainstorming/SKILL.md:228`
- Create (evals repo): `evals/scenarios/brainstorming-asks-tooling-question/`

**Interfaces:**
- Consumes: Task 1's evidence note (this task appends a section).
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
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run scenarios/brainstorming-asks-tooling-question --coding-agent claude-auto
```

Record each result. Expected: all three fail.

If all three pass, STOP: append the null result to the evidence note as this arm's section, commit it, and skip to the next task.

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
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run scenarios/brainstorming-asks-tooling-question --coding-agent claude-auto
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

### Task 8: Arm D — evidence for the two routing edits 6.13.0 shipped

**Risk tier:** standard — no new prose; this arm measures prose that already shipped and reverts it if the measurement says so. The control worktree is restored to HEAD before an ordinary `git worktree remove`; no force removal or other destructive git operation occurs.

**Files:**
- Create (evals repo): `evals/scenarios/executing-plans-keeps-inline-request/`
- Create (evals repo): `evals/scenarios/requesting-code-review-hands-off-to-receiving/`
- Conditionally modify: `skills/executing-plans/SKILL.md:14`, `skills/requesting-code-review/SKILL.md` step 3, and `tests/codex-review-gate/test-gate-topology.sh` (only if a scenario loses)

**Interfaces:**
- Consumes: Task 1's evidence note (this task appends a section).
- Produces: an appended `### Arm D` section. If an edit loses, a revert commit restoring that block's 6.12.0 text.

**Context the implementer needs.** 6.13.0 shipped two routing edits as "mechanically checkable contradictions": `executing-plans/SKILL.md:14` now says the skill is the inline path by request and must not re-open the choice, and `requesting-code-review` step 3 now carries a REQUIRED SUB-SKILL pointer to `receiving-code-review`. The 6.13.0 Codex sweep held that both are behavior-shaping and shipped without the before/after evidence this repository requires. This arm supplies it after the fact.

How the control is built matters, and the plan gate corrected the first draft: Quorum's Claude launcher passes the plugin root at process level (`--plugin-dir "$SUPERPOWERS_ROOT"`, see `evals/coding-agents/claude-context/launch-agent` and the runner's provisioning in `evals/src/runner/index.ts`), so a scenario's `setup.sh` cannot swap the plugin text. The control is therefore a second checkout: a detached worktree of this repository at HEAD in which only the two routing blocks are restored to their 6.12.0 text, used as `SUPERPOWERS_ROOT` for the control runs. Everything else in that worktree — including Task 0's `BASE_SHA` change — is identical to the treatment tree, so the pair isolates the two edits. The treatment runs use this checkout as is. Read those two launcher files first and confirm the variable name and how the runner passes it through; if the harness has grown a per-run plugin-root option since, use that instead and say so in the evidence note.

Because the treatment already shipped, "the arm loses" means a revert of that block, with the loss recorded in the evidence note.

- [ ] **Step 1: Write the two scenarios**

`executing-plans-keeps-inline-request`: stage a small repo with a two-task plan under `docs/hyperpowers/plans/`; the prompt asks for the plan to be executed "inline, in this session, without subagents". Assert in `post()` that `hyperpowers:executing-plans` was invoked, that `hyperpowers:subagent-driven-development` was not, and that no subagent was dispatched. Acceptance criteria: the agent executes inline and never proposes switching to SDD.

`requesting-code-review-hands-off-to-receiving`: stage a small repo with a committed change and a prompt asking for a code review of it. Assert in `post()` that `hyperpowers:requesting-code-review` was invoked and that `hyperpowers:receiving-code-review` was invoked after the review result arrived and before any fix was applied. Acceptance criteria: findings were treated as claims to evaluate, with at least one explicitly weighed rather than executed.

Set `status: ready` and `quorum_tier: full` in both `story.md` files; restrict to Claude-family agents. Validate both with `cd evals && bun run quorum check <name>`.

- [ ] **Step 2: Commit the scenarios in the evals repo**

```bash
git -C evals add scenarios/executing-plans-keeps-inline-request scenarios/requesting-code-review-hands-off-to-receiving
git -C evals commit -m "scenario: the two routing edits 6.13.0 shipped, each with an inline-request or review fixture"
```

- [ ] **Step 3: Build the control checkout**

```bash
git worktree add --detach "$TMPDIR/arm-d-control" HEAD
git show v6.12.0:skills/executing-plans/SKILL.md > "$TMPDIR/arm-d-control/skills/executing-plans/SKILL.md"
```

Then, in `$TMPDIR/arm-d-control/skills/requesting-code-review/SKILL.md`, restore only the step 3 block to its 6.12.0 form: delete the paragraph beginning `**REQUIRED SUB-SKILL:** Use hyperpowers:receiving-code-review.` and the blank line after it, so step 3 is the heading followed directly by its four bullets. Confirm with `diff <(git show v6.12.0:skills/requesting-code-review/SKILL.md | sed -n '/^\*\*3\. Act on feedback/,/^$/p') <(sed -n '/^\*\*3\. Act on feedback/,/^$/p' "$TMPDIR/arm-d-control/skills/requesting-code-review/SKILL.md")` printing nothing. Leave every other file in that worktree untouched.

- [ ] **Step 4: Run the controls**

Three runs of each scenario with the control checkout as the plugin root:

```bash
cd evals && SUPERPOWERS_ROOT="$TMPDIR/arm-d-control" bun run quorum run scenarios/executing-plans-keeps-inline-request --coding-agent claude-auto
```

```bash
cd evals && SUPERPOWERS_ROOT="$TMPDIR/arm-d-control" bun run quorum run scenarios/requesting-code-review-hands-off-to-receiving --coding-agent claude-auto
```

Confirm from each run's session log that the plugin loaded from `$TMPDIR/arm-d-control` (the launcher records the plugin dir); a control that silently loaded the treatment tree is not a control. Record each run. Expected: the controls fail — the 6.12.0 text pushed inline sessions toward SDD and never routed to `receiving-code-review`. If a control passes all three, that edit had no defect to fix: it is unsupported (Step 6).

- [ ] **Step 5: Run the treatments**

Three runs of each scenario against this checkout:

```bash
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run scenarios/executing-plans-keeps-inline-request --coding-agent claude-auto
```

```bash
cd evals && SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers bun run quorum run scenarios/requesting-code-review-hands-off-to-receiving --coding-agent claude-auto
```

**Decision rule, per edit:** the edit is supported if its treatment passes at least 2 of 3 while its control passed at most 1 of 3. Each edit is judged on its own pair.

- [ ] **Step 6: Revert any edit the measurement does not support**

For the inline-path note:

```bash
git show v6.12.0:skills/executing-plans/SKILL.md > skills/executing-plans/SKILL.md
git commit -am "revert(executing-plans): the inline-path note did not beat its control"
```

For the routing pointer: delete the `**REQUIRED SUB-SKILL:** Use hyperpowers:receiving-code-review.` paragraph from `skills/requesting-code-review/SKILL.md` step 3 by hand (the file also carries Task 0's `BASE_SHA` change, which stays), remove the `requesting-code-review routes to receiving-code-review` assertion from `tests/codex-review-gate/test-gate-topology.sh`, run that suite to `STATUS: PASSED`, and commit both files with the message `revert(requesting-code-review): the receiving-code-review pointer did not beat its control`.

- [ ] **Step 7: Restore and remove the control checkout**

Put the two edited files back to HEAD inside the control worktree so that an ordinary, non-force removal suffices — no destructive git operation is needed or permitted here:

```bash
git -C "$TMPDIR/arm-d-control" show HEAD:skills/executing-plans/SKILL.md > "$TMPDIR/arm-d-control/skills/executing-plans/SKILL.md"
git -C "$TMPDIR/arm-d-control" show HEAD:skills/requesting-code-review/SKILL.md > "$TMPDIR/arm-d-control/skills/requesting-code-review/SKILL.md"
git -C "$TMPDIR/arm-d-control" status --short
```

Expected: empty status. Then:

```bash
git worktree remove "$TMPDIR/arm-d-control"
git worktree prune
```

If removal is refused because the worktree is not clean, stop and report which files differ; never add `--force`.

- [ ] **Step 8: Append the evidence section**

Add `### Arm D — the routing edits 6.13.0 shipped` to the evidence note: why the arm exists (the sweep finding), how the control checkout was built and how each run's plugin dir was confirmed, control and treatment results run by run per edit, and the verdict per edit.

- [ ] **Step 9: Commit**

```bash
git add docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "docs(evals): before/after evidence for the two routing edits 6.13.0 shipped without it"
```

---

### Task 9: Lens-count measurement and decision

**Risk tier:** standard — the deliverable is a measurement over a bounded cohort and a recorded decision; nothing in the gate changes in this task.

**Files:**
- Create (evals repo): `evals/scripts/lens-cohort.sh`
- Modify: `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`

**Interfaces:**
- Consumes: Task 0's `--since`, Task 1's baselines, and whichever of Tasks 2 and 3 won.
- Produces: an appended `### Lens count` section in the evidence note, and a reusable extractor for the per-lens rates and within-batch overlap.

**Context the implementer needs.** Round 1 of a code gate fans out to three lenses whose historical needs-attention rates were 55%, 59%, and 69%, at 0.94 findings per lens capture. A round converges only when every capture approves, so three independent lenses at those rates make round-1 convergence structurally unlikely. The plan gate rejected the first draft of this task because it scanned the whole cache: historical captures predate Part 1 and every winning arm, so re-normalizing them measures nothing about the gate as it now runs. This task measures the post-release cohort only, and states a minimum sample below which the honest answer is "insufficient data."

**Decision rule, stated before looking:** a lens is a merge candidate only if, over the cohort, its blocking rate (captures normalizing to `blocking` divided by captures normalizing to `blocking` or `approved`; `incomplete` captures are reported but excluded) is at or above 60% AND at least 80% of its blocking findings are duplicated by another lens in the same round-1 batch (same `GATE_DIR`, word-Jaccard of titles at or above 0.5). Minimum sample: 30 complete round-1 batches in the cohort. Below that, the section records the counts and the conclusion "insufficient post-release data" and the task ends.

- [ ] **Step 1: Write the extractor and its test in the evals repo**

Create `evals/scripts/lens-cohort.sh` with exactly this content. Traversal and the timestamp filter live in Node (`fs.statSync().mtimeMs`), because macOS `find` rejects `-newermt "@epoch"`; the script is `set -euo pipefail` so a traversal failure is fatal rather than an empty, false "no captures" answer.

```bash
#!/usr/bin/env bash
# lens-cohort.sh <hyperpowers-root> <since-ISO-8601> [cache-root]
# Walks every codex-review run directory whose mtime is at or after <since>,
# normalizes each round-1 lens capture with verdict-normalize, and prints
# per-lens outcome counts plus the share of each lens's blocking findings
# that another lens in the same batch also raised (title word-Jaccard >= 0.5).
# Read-only. Any failure is fatal: an empty answer must mean an empty cohort.
set -euo pipefail
root="${1:?hyperpowers root}"; since="${2:?ISO-8601}"
base="${3:-${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/codex-review}"
[ -d "$base" ] || { echo "lens-cohort: no cache root at $base" >&2; exit 2; }
node - "$root" "$since" "$base" <<'JS'
const fs = require("fs"), path = require("path"), cp = require("child_process");
const [root, since, base] = process.argv.slice(2);
const sinceMs = Date.parse(since);
if (!Number.isFinite(sinceMs)) { console.error("lens-cohort: bad since: " + since); process.exit(2); }
const normalize = root + "/skills/requesting-code-review/scripts/verdict-normalize";
const rows = [];
for (const key of fs.readdirSync(base)) {
  const kd = path.join(base, key);
  if (!fs.statSync(kd).isDirectory()) continue;
  for (const run of fs.readdirSync(kd)) {
    const rd = path.join(kd, run);
    const st = fs.statSync(rd);
    if (!st.isDirectory() || !run.startsWith("run-") || st.mtimeMs < sinceMs) continue;
    for (const f of fs.readdirSync(rd)) {
      const m = /^lens-(.+)-capture$/.exec(f);
      if (!m) continue;
      const cap = path.join(rd, f);
      let res = "incomplete";
      try { res = JSON.parse(cp.execFileSync("bash", [normalize, "--require-coverage", cap], { encoding: "utf8" })).result; } catch (e) { res = "incomplete"; }
      let titles = [];
      // A capture is either the companion's result envelope or the bare review payload (its rawOutput); both carry verdict and findings.
      try { const j = JSON.parse(fs.readFileSync(cap, "utf8")); const r = (j.storedJob && j.storedJob.result && j.storedJob.result.result) || j; titles = (r.findings || []).filter(x => /^(critical|high)$/i.test(String(x.severity))).map(x => String(x.title)); } catch (e) { titles = []; }
      rows.push({ run: rd, lens: m[1], res, titles });
    }
  }
}
if (!rows.length) { console.log("no round-1 lens captures at or after " + since); process.exit(0); }
const byRun = {}; for (const r of rows) (byRun[r.run] = byRun[r.run] || []).push(r);
const canonical = new Set(["correctness", "contracts-and-integration", "tests-and-evidence"]);
const allBatches = Object.entries(byRun).filter(([_, b]) => b.length >= 3);
const batches = [], excluded = [];
for (const [run, b] of allBatches) {
  const lenses = new Set(b.map(r => r.lens));
  if (lenses.size === canonical.size && [...canonical].every(x => lenses.has(x))) batches.push(b);
  else excluded.push({ run, lenses: [...lenses].sort() });
}
const words = t => new Set(String(t).toLowerCase().split(/[^a-z0-9]+/).filter(Boolean));
const jac = (a, b) => { const A = words(a), B = words(b); const i = [...A].filter(x => B.has(x)).length; const u = new Set([...A, ...B]).size; return u ? i / u : 0; };
const per = {};
for (const b of batches) for (const r of b) {
  const p = per[r.lens] = per[r.lens] || { approved: 0, blocking: 0, incomplete: 0, findings: 0, dup: 0 };
  p[r.res] = (p[r.res] || 0) + 1;
  for (const t of r.titles) { p.findings++; if (b.some(o => o.lens !== r.lens && o.titles.some(u => jac(t, u) >= 0.5))) p.dup++; }
}
console.log("complete round-1 batches: " + batches.length);
if (excluded.length) console.log("excluded batches: " + excluded.length + " — " + excluded.map(e => path.basename(e.run) + ": [" + e.lenses.join(", ") + "]").join("; "));
for (const [lens, p] of Object.entries(per)) {
  const decided = p.approved + p.blocking; const rate = decided ? (100 * p.blocking / decided).toFixed(1) : null; const dup = p.findings ? (100 * p.dup / p.findings).toFixed(1) : null;
  const blockingFlag = decided && p.blocking * 100 >= 60 * decided ? "meets-60%-threshold" : "below-60%-threshold";
  const dupFlag = p.findings && p.dup * 100 >= 80 * p.findings ? "meets-80%-threshold" : "below-80%-threshold";
  console.log(lens + ": approved " + p.approved + ", blocking " + p.blocking + ", incomplete " + p.incomplete + "; blocking rate " + p.blocking + "/" + decided + " = " + (rate === null ? "-" : rate + "%") + " (" + blockingFlag + "); blocking findings " + p.findings + ", duplicated by another lens " + p.dup + "/" + p.findings + " = " + (dup === null ? "-" : dup + "%") + " (" + dupFlag + ")");
}
JS
```

Create `evals/scripts/lens-cohort.test.sh` with exactly this content — it proves old/new run selection on this host with a synthetic cache root, that both capture shapes are read, that non-canonical batches are excluded and reported, and that the threshold flags are exact:

```bash
#!/usr/bin/env bash
# Proves lens-cohort.sh selects runs by mtime on this host: one batch older
# than the cutoff must vanish, one newer must count. Needs a hyperpowers
# checkout (arg 1) for verdict-normalize.
set -euo pipefail
root="${1:?hyperpowers root}"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/lens-cohort-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cache="$work/codex-review/key1"
mk() { # <run-name> <verdict> <title>
  mkdir -p "$cache/$1"
  for lens in correctness contracts-and-integration tests-and-evidence; do
    printf '{"storedJob":{"result":{"parseError":null,"result":{"verdict":"%s","findings":[%s],"summary":"Coverage: documents read - d; adjudicated decisions considered - none; changed surfaces reviewed - all; test evidence inspected - yes"},"rawOutput":"x"}}}\n' \
      "$2" "$( [ "$2" = needs-attention ] && printf '{"severity":"high","title":"%s"}' "$3" )" > "$cache/$1/lens-$lens-capture"
  done
}
mkbare() { # <run-name> <verdict> <title> -- the bare payload shape the code gates store
  mkdir -p "$cache/$1"
  for lens in correctness contracts-and-integration tests-and-evidence; do
    printf '{"verdict":"%s","findings":[%s],"summary":"Coverage: all"}\n' \
      "$2" "$( [ "$2" = needs-attention ] && printf '{"severity":"high","title":"%s"}' "$3" )" > "$cache/$1/lens-$lens-capture"
  done
}
mkfinal() { # final-gate batch: correctness, integration-and-requirements-coverage, tests-and-evidence
  mkdir -p "$cache/run-final"
  for lens in correctness integration-and-requirements-coverage tests-and-evidence; do
    printf '{"verdict":"approve","findings":[],"summary":"Coverage: all"}\n' > "$cache/run-final/lens-$lens-capture"
  done
}
mkalias() { # alias batch: contracts, correctness, tests
  mkdir -p "$cache/run-alias"
  for lens in contracts correctness tests; do
    printf '{"verdict":"approve","findings":[],"summary":"Coverage: all"}\n' > "$cache/run-alias/lens-$lens-capture"
  done
}
mk run-old approve ""
mk run-new needs-attention "null dereference in parseRate"
mkbare run-bare needs-attention "null dereference in parseRate"
mkfinal
mkalias
# Build below-threshold case: 23 synthetic blocking + run-new + run-bare = 25 blocking, 17 approved = 42 total.
# 25/42 = 59.52% rounds to 60%, but 25*100 < 60*42 so it's below threshold.
for i in $(seq 1 23); do
  mkdir -p "$cache/run-below-$i"
  for lens in correctness contracts-and-integration tests-and-evidence; do
    printf '{"verdict":"needs-attention","findings":[{"severity":"high","title":"finding %d"}],"summary":"Coverage: all"}\n' "$i" > "$cache/run-below-$i/lens-$lens-capture"
  done
done
for i in $(seq 24 40); do
  mkdir -p "$cache/run-below-$i"
  for lens in correctness contracts-and-integration tests-and-evidence; do
    printf '{"verdict":"approve","findings":[],"summary":"Coverage: all"}\n' > "$cache/run-below-$i/lens-$lens-capture"
  done
done
# Build meets-threshold case: add one more blocking batch so 26/43 = 60.47% meets threshold (26*100 >= 60*43).
mkdir -p "$cache/run-meets-1"
for lens in correctness contracts-and-integration tests-and-evidence; do
  printf '{"verdict":"needs-attention","findings":[{"severity":"high","title":"meets finding"}],"summary":"Coverage: all"}\n' > "$cache/run-meets-1/lens-$lens-capture"
done
touch -t 202001010000 "$cache/run-old"
out="$(bash "$here/lens-cohort.sh" "$root" 2025-01-01T00:00:00Z "$work/codex-review")"
printf '%s\n' "$out"
printf '%s' "$out" | grep -q 'complete round-1 batches: 43' || { echo "FAIL: expected 43 canonical batches (2 original + 40 below + 1 meets)"; exit 1; }
printf '%s' "$out" | grep -q 'excluded batches: 2' || { echo "FAIL: expected 2 excluded batches (final-gate and alias)"; exit 1; }
printf '%s' "$out" | grep -q 'run-final: \[correctness, integration-and-requirements-coverage, tests-and-evidence\]' || { echo "FAIL: final-gate batch must be reported as excluded"; exit 1; }
printf '%s' "$out" | grep -q 'run-alias: \[contracts, correctness, tests\]' || { echo "FAIL: alias batch must be reported as excluded"; exit 1; }
printf '%s' "$out" | grep -q 'correctness: approved 17, blocking 26' || { echo "FAIL: both capture shapes and threshold batches must count"; exit 1; }
printf '%s' "$out" | grep -q 'blocking rate 26/43 = 60.5% (meets-60%-threshold)' || { echo "FAIL: exact rate with meets threshold flag must be shown"; exit 1; }
printf '%s' "$out" | grep -q 'duplicated by another lens 26/26 = 100.0% (meets-80%-threshold)' || { echo "FAIL: exact duplication rate with threshold flag must be shown"; exit 1; }
# Test the below-threshold case by making run-meets-1 old so it's excluded from the 2025 cutoff
touch -t 202001010000 "$cache/run-meets-1"
out_below="$(bash "$here/lens-cohort.sh" "$root" 2025-01-01T00:00:00Z "$work/codex-review")"
printf '\n--- Below-threshold test ---\n%s\n' "$out_below"
printf '%s' "$out_below" | grep -q 'complete round-1 batches: 42' || { echo "FAIL: expected 42 canonical batches (2 original + 40 below)"; exit 1; }
printf '%s' "$out_below" | grep -q 'blocking rate 25/42 = 59.5% (below-60%-threshold)' || { echo "FAIL: exact rate with below threshold flag must be shown"; exit 1; }
out2="$(bash "$here/lens-cohort.sh" "$root" 2000-01-01T00:00:00Z "$work/codex-review")"
printf '%s' "$out2" | grep -q 'complete round-1 batches: 44' || { echo "FAIL: an early cutoff must include all 44 canonical batches (including run-old and run-meets-1)"; exit 1; }
printf '%s' "$out2" | grep -q 'excluded batches: 2' || { echo "FAIL: excluded count must be consistent"; exit 1; }
echo "PASS: lens-cohort selects by mtime, reads both capture shapes, scores overlap, excludes non-canonical batches, and shows exact threshold flags"
```

Make both executable, run `bash evals/scripts/lens-cohort.test.sh /Users/johnss51/Development/agents/hyperpowers` (expected: the PASS line), then commit both in the evals repo: `git -C evals add scripts/lens-cohort.sh scripts/lens-cohort.test.sh && git -C evals commit -m "tool: per-lens outcomes and within-batch overlap over a bounded cohort, with an mtime-selection test"`.

- [ ] **Step 2: Run it over the post-release cohort**

```bash
since="$(git log -1 --format=%cI v6.13.0)"
bash evals/scripts/lens-cohort.sh /Users/johnss51/Development/agents/hyperpowers "$since"
```

Also record `bash skills/requesting-code-review/scripts/gate-telemetry --all --since "$since"` for the same cohort, so the section carries the round counts beside the lens rates.

- [ ] **Step 3: Apply the decision rule**

If the extractor reports fewer than 30 complete round-1 batches, write the `### Lens count` section with the counts and the conclusion "insufficient post-release data; the historical rates (55/59/69%) are pre-Part-1 and do not license a change", and go to Step 5. Otherwise, apply the rule lens by lens.

- [ ] **Step 4: Record the outcome without changing the gate**

If no lens qualifies, record the table and the conclusion that the three-lens fan-out is carrying its cost. If a lens qualifies, record the numbers and the specific merge proposal and state that it needs its own scenario and arm: merging a lens removes a review seat, which this plan's remaining budget cannot measure honestly after other arms have already moved the same metric. Either way, no gate file changes in this task.

- [ ] **Step 5: Commit**

```bash
git add docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "docs(evals): measure the three-lens fan-out over the post-6.13.0 cohort, not the history before it"
```

---

### Task 10: Release

**Risk tier:** standard — publishes every arm that won.

**Files:**
- Modify: `CHANGELOG.md`
- Modify (by `vrzn`): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json`

**Interfaces:**
- Consumes: every preceding task's commits.
- Produces: a `v6.14.0` tag. Before tagging, Task 1's post-release cohort line is re-read and appended to the evidence note.

**Context the implementer needs.** This task runs last. `vrzn` owns every version string. The bump is `minor` because Task 4 adds a flag. If every arm lost and only Tasks 0, 4, and 5 and the evidence note shipped, the bump is still `minor` for that flag.

Do not push.

- [ ] **Step 1: Close the evidence note, then confirm a clean tree and green suites**

Re-read the post-release cohort and append it to the evidence note's Baselines section as the closing line, then commit that note on its own so the release commit never carries evidence edits:

```bash
since="$(git log -1 --format=%cI v6.13.0)"
bash skills/requesting-code-review/scripts/gate-telemetry --all --since "$since"
```

```bash
git add docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md
git commit -m "docs(evals): the post-6.13.0 cohort at release time"
```

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



- [ ] **Step 2: Verify the evidence note covers every change**

```bash
git log --oneline v6.13.0..HEAD
```

Every commit touching a skill file must have a matching section in `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`. A behavior-shaping change with no evidence section violates this repository's rule and must not ship — revert it or write the section.

- [ ] **Step 3: Write the changelog entry**

Add a 6.14.0 section at the top of `CHANGELOG.md`, matching the format of the 6.13.0 entry. Cover only what actually shipped. For each arm, state the control and treatment results in one clause. For each arm that lost, say nothing in the changelog — the evidence note is its record.

Always covered, since Tasks 0, 4, and 5 are not eval-gated:

- The testing guide names the two non-bash suites and its directory loop fails when a suite fails; `gate-telemetry --since` bounds a cohort; `churn()` ignores malformed rounds; the fleet churn fields are asserted; `requesting-code-review` no longer offers `HEAD~1` as a review base (all from the 6.13.0 Codex sweep).
- An approval reached through a `needs-attention` verdict now has a stated rule: its medium/low notes are read and recorded before the round converges.
- Arm D: the two routing edits 6.13.0 shipped now carry before/after evidence (or a revert, if the measurement said so).

- `gate-round --consumed <n>` computes the SDD per-task ceiling from the shared five-round cap, replacing a subtraction the controller performed by hand. Twenty measured task gates recorded out-of-pattern ceilings (1, 2, 6, or 7), seven of them above the cap.
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

Run `git status --short` once more after tagging (expected: empty), then report the release commit SHA, the tag, which arms won and which were reverted with their run counts, and the fact that nothing has been pushed. Also report the evals repository's commits, which are separate and also unpushed.
