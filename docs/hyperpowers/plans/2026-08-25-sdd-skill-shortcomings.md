# SDD Skill Shortcomings (6.10.0 Attribution) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** none — the requirements derive from the 6.10.0 release train's attribution analysis (2026-08-25). The evidence is restated in full under Context below so no task depends on session memory.

**Goal:** Close the four SDD skill shortcomings the 6.10.0 train exposed — todo-vs-ledger drift, unanchored implementer identity, the mispriced controller-fix rule, and vacuous covering commands — with eval-gated text changes that keep every existing behavior green.

**Architecture:** Three text edits to `skills/subagent-driven-development/SKILL.md` plus one to `common-rationalizations.md`, each pinned by new `test-sdd-contract.sh` needles; then a controller-run live eval gate (the three SDD behaviors that could regress) with an explicit revert protocol and an experiment-log entry.

**Tech Stack:** Markdown skill text, bash test suites (`tests/sdd/test-sdd-contract.sh`), quorum live evals (`evals/`), live bash suite (`tests/claude-code/`).

## Context — the evidence each change rests on

1. **Todo-vs-ledger drift.** `SKILL.md:160-161` says "create a todo per task", but the Setup section (`:122-125`) makes the ledger the compaction-surviving tracker. Two complete headless runs of the live integration test (2026-08-25, both at commit `89c7c62`'s HEAD-equivalent tree) tracked exclusively through the ledger — 11 and 20 `progress.md` tool calls, zero task-tool calls — while executing the skill correctly end to end. In headless harnesses the task tools sit behind ToolSearch. The text mandates a UX complement agents demonstrably skip; the load-bearing mechanism is the ledger.
2. **Implementer identity not anchored.** `SKILL.md:265-266` says "Record the implementer's agent identity from the dispatch result" but not where. In the 6.10.0 train this identity was lost to compaction twice (Tasks 4 and 7), forcing fresh takeover dispatches where the R≤3 rule wanted resumes — both disclosed as deviations. The skill's own compaction doctrine ("trust the ledger and git log over your own recollection") names the fix: the identity belongs in the ledger.
3. **Controller-fix rule mispriced at the de-minimis end.** "Never fix findings yourself" (`SKILL.md:420-421`) was deviated from three times in one train (`348d632`; Task 3-R fix round 1; part of Task 4 fix round 2) — each a fully-specified, few-line fix; each disclosed, validated before commit, and cleared by its scoped re-review. Three disclosed recurrences with zero bad outcomes is evidence the rule's cost-benefit is wrong for fixes with no judgment left in them, and that the deviation-disclosure channel is functioning as an ad-hoc carve-out. This plan codifies the narrow version with guardrails, eval-gated; if the evals show it swallowing real fix rounds, it is reverted (Task 3 protocol).
4. **Vacuous covering commands.** The Subagent-Reports-Are-Claims rule requires a named covering command but not that it can fail: a bare `scripts/lint-shell.sh` on a clean tree collects zero files, prints "No shell files found." and exits 0 — an earlier release evidence record shipped exactly that vacuous pass, caught only by the final whole-branch review (its Minor 7).

Baseline already in hand (do not re-purchase; the experiment log exists so disproofs are not re-bought):
- `sdd-unified-fix-loop` **pass** — run `…20260825T171208Z-0cf8`, 5/5 post-checks, resume + scoped re-review verified from `trajectory.json`.
- Live integration test **STATUS: PASSED** (2026-08-25, ~23 min run).
- `test-subagent-driven-development.sh` **15/15** (at `1e506fc`).
- `tests/sdd/test-sdd-contract.sh` **68 PASS / 0 FAIL** offline.

## Global Constraints

- Branch: `sdd-skill-fixes` off `gate-split` HEAD (`aa2417a`). Work in an isolated worktree via hyperpowers:using-git-worktrees.
- Skill text is tuned content: make exactly the edits specified here, verbatim; no rewording of surrounding lines, no drive-by cleanups.
- `tests/sdd/test-sdd-contract.sh` must exit 0 after every task; needle changes only as this plan specifies.
- Every commit: no attribution lines, no Co-Authored-By, no emojis.
- Live evals are trusted-maintainer operations; run them exactly as Task 3 specifies (`SUPERPOWERS_ROOT` exported, `--coding-agent claude-auto`, sequential). Never add them to CI.
- No version bump and no CHANGELOG entry in this plan — these changes ship with the next release train.
- The plan document itself is never committed.

---

### Task 1: Anchor the ledger — todo mirror, identity line, vacuity clause

**Risk tier:** standard — behavior-shaping skill/doc surgery on SKILL.md.

Three shortcomings, three cycles, three commits — one commit per shortcoming so
Task 3's revert protocol can target exactly the regressed change. They stay one
task because all three are same-file, same-shape text surgery on SKILL.md
(SDD's batch rule), reviewed as one diff.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:160-161`, `:265-266`, `:284` (after the covering-command paragraph), `:493`
- Test: `tests/sdd/test-sdd-contract.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the exact SKILL.md sentences Task 3's live gate observes; four new contract needles Task 2 must keep green; three commits Task 3's revert protocol names (todo-mirror, identity, vacuity).

Red-phase verification in this plan always uses this form — the suite's own
exit status and the FAIL count are read separately (a `suite | grep -c` pipe
reports grep's status, which is 0 exactly when FAILs are found):

```bash
out="$(bash tests/sdd/test-sdd-contract.sh 2>&1)"; rc=$?
echo "$out" | grep -c '\[FAIL\]'   # the expected new-needle count
echo "rc=$rc"                      # expected: rc=1 while red, rc=0 when green
```

**Cycle A — todo mirror**

- [ ] **Step A1: Add the failing needle**

Append to `tests/sdd/test-sdd-contract.sh` immediately after the line `assert_contains "$SDD_RATIONALIZATIONS" "Silent discards are forbidden." \` and its description line:

```bash
# Ledger-anchoring needles (2026-08-25 attribution fixes). The ledger is the
# canonical tracker; todos mirror it where the harness surfaces them, the
# implementer identity is written into the ledger so compaction cannot orphan
# fix-round resumes, and a covering command that cannot fail is not evidence.
assert_contains "$SDD" "todos mirror it, never replace it" "ledger is canonical; todos are the mirror"
```

- [ ] **Step A2: Verify red** — the form above; expected FAIL count `1`, `rc=1`.

- [ ] **Step A3: Edit SKILL.md — todo instruction (lines 160-161)**

Replace:

```
Read the plan once, note its context and Global Constraints, and create a
todo per task. Read the plan's `**Spec:**` header and the spec file it
```

with:

```
Read the plan once, note its context and Global Constraints, and create a
todo per task where your harness surfaces todos — the ledger is the
progress record either way; todos mirror it, never replace it. Read the
plan's `**Spec:**` header and the spec file it
```

- [ ] **Step A4: Edit SKILL.md — completion line (line 493, shifts with the insertion above; locate by quoted text)**

Replace:

```
Then mark the todo complete and move on. Never move to the next task while
```

with:

```
Then mark the task's todo complete, where you keep todos, and move on.
Never move to the next task while
```

- [ ] **Step A5: Verify green** — expected `STATUS: PASSED`, 69 PASS / 0 FAIL, `rc=0`.

- [ ] **Step A6: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md tests/sdd/test-sdd-contract.sh
git commit -m "fix(sdd): the ledger is the progress record; todos mirror it where surfaced"
```

**Cycle B — implementer identity anchored to the ledger**

- [ ] **Step B1: Add the failing needles** (append directly after Cycle A's needle)

```bash
assert_contains "$SDD" "in the ledger's task entry" "implementer identity anchored to the ledger"
assert_contains "$SDD" "after compaction the ledger is the only place the identity survives" "identity survives compaction via the ledger"
```

- [ ] **Step B2: Verify red** — expected FAIL count `2`, `rc=1`.

- [ ] **Step B3: Edit SKILL.md — identity line (lines 265-266)**

Replace:

```
- Record the implementer's agent identity from the dispatch result —
  fix-loop rounds 1-3 resume this agent.
```

with:

```
- Record the implementer's agent identity from the dispatch result in the
  ledger's task entry (`Task <N>: implementer <agent-id-or-name>`) —
  fix-loop rounds 1-3 resume this agent, and after compaction the ledger is
  the only place the identity survives. An identity that was never written
  down forces a fresh takeover where a resume was owed.
```

- [ ] **Step B4: Verify green** — expected `STATUS: PASSED`, 71 PASS / 0 FAIL, `rc=0`.

- [ ] **Step B5: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md tests/sdd/test-sdd-contract.sh
git commit -m "fix(sdd): implementer identity is written into the ledger, not conversation memory"
```

**Cycle C — falsifiable covering commands**

- [ ] **Step C1: Add the failing needle** (append directly after Cycle B's needles)

```bash
assert_contains "$SDD" "A covering command must be able to fail." "vacuous covering commands are not evidence"
```

- [ ] **Step C2: Verify red** — expected FAIL count `1`, `rc=1`.

- [ ] **Step C3: Edit SKILL.md — vacuity clause (after the covering-command paragraph)**

The paragraph ending `A dispatch naming neither is malformed — fix the dispatch, not the rule.` gains a new paragraph directly after it:

```
A covering command must be able to fail. One that can no-op on the state
under test — a changed-files linter on a clean tree, a test filter that
matches nothing — is not covering evidence, however honestly it exits 0.
Name the files or the test ids explicitly so the command exercises what
the report claims.
```

- [ ] **Step C4: Verify green** — expected `STATUS: PASSED`, 72 PASS / 0 FAIL, `rc=0`.

- [ ] **Step C5: Verify no other suite regressed**

Run: `bash tests/codex-review-gate/test-gate-contract.sh 2>&1 | tail -1` and `bash tests/claude-code/test-sdd-dir-path.sh 2>&1 | tail -1`
Expected: both PASSED.

- [ ] **Step C6: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md tests/sdd/test-sdd-contract.sh
git commit -m "fix(sdd): a covering command that cannot fail is not evidence"
```

### Task 2: De-minimis controller-fix carve-out

**Risk tier:** standard — surgery on tuned fix-loop content and a rationalization row; the eval gate in Task 3 is the evidence requirement.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:420-421` (the "Never fix findings yourself" paragraph; line numbers shifted by Task 1's insertions — locate by the quoted text)
- Modify: `skills/subagent-driven-development/common-rationalizations.md` (the "I'll fix it myself" row)
- Test: `tests/sdd/test-sdd-contract.sh`

**Interfaces:**
- Consumes: Task 1's needle block location (appends directly after it).
- Produces: the carve-out sentences Task 3's live gate adversarially probes.

- [ ] **Step 1: Add the failing contract needles**

Append to `tests/sdd/test-sdd-contract.sh` directly after Task 1's needle block:

```bash
# De-minimis carve-out (2026-08-25). The exception must carry all three
# guardrails in text: the full-specification bound, the mandatory disclosure
# ledger line, and the two-strike escape back to a real dispatch. The
# rationalization row must scope itself to the exception rather than being
# silently weakened.
assert_contains "$SDD" "fully specified by the finding itself" "carve-out requires a fully-specified fix"
assert_contains "$SDD" "controller-applied (de minimis)" "carve-out requires the disclosure ledger line"
assert_contains "$SDD" "consumes a fix round and ends in the same scoped re-review" "carve-out waives neither the round nor the re-review"
assert_contains "$SDD" "Reaching for it twice in the same task means the findings are not de minimis" "carve-out two-strike rule"
assert_contains "$SDD_RATIONALIZATIONS" "Outside the de-minimis exception" "rationalization row scoped to the exception"
assert_contains "$SDD_RATIONALIZATIONS" "Resume the implementer." "rationalization row still lands on resume"
```

- [ ] **Step 2: Verify red** — Task 1's red-phase form (suite rc and FAIL count read separately); expected FAIL count `6`, `rc=1`.

- [ ] **Step 3: Edit SKILL.md — the carve-out paragraph**

Replace:

```
Never fix findings yourself in the controller session — your context stays
clean for coordination, and controller fixes skip review.
```

with:

```
Never fix findings yourself in the controller session — your context stays
clean for coordination, and controller fixes skip review. One narrow
exception: a fix fully specified by the finding itself — exact file, exact
lines, exact replacement, no judgment left — touching at most 3 lines in
one file with no new logic, may be controller-applied. The exception
waives nothing else: it consumes a fix round and ends in the same scoped
re-review, and its ledger line must read
`Task <N>: fix round <R>/5 controller-applied (de minimis) — <finding>`.
Reaching for it twice in the same task means the findings are not de
minimis — resume the implementer.
```

- [ ] **Step 4: Edit common-rationalizations.md — scope the row**

Replace the row:

```
| "I'll fix it myself, dispatching is overhead" | Controller fixes pollute your context and skip review. Resume the implementer. |
```

with:

```
| "I'll fix it myself, dispatching is overhead" | Controller fixes pollute your context and skip review. Outside the de-minimis exception (at most 3 fully-specified lines, one file, disclosed in the ledger, re-review still runs), that is rationalization. Resume the implementer. |
```

- [ ] **Step 5: Run the suite to verify all needles pass**

Run: `bash tests/sdd/test-sdd-contract.sh 2>&1 | tail -1`
Expected: `STATUS: PASSED` (78 PASS, 0 FAIL).

- [ ] **Step 6: Sanity-check the untouched neighbors**

Run: `grep -c 'Silent discards are forbidden' skills/subagent-driven-development/common-rationalizations.md`
Expected: `1` (the adjacent tuned rows are byte-identical; only the one row changed). `git diff --stat` against the Task 1 head shows exactly 3 files: `SKILL.md`, `common-rationalizations.md`, `test-sdd-contract.sh`.

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/common-rationalizations.md tests/sdd/test-sdd-contract.sh
git commit -m "feat(sdd): de-minimis controller-fix carve-out with disclosure, round cost, and two-strike escape"
```

### Task 3: Eval gate — prove no behavior regressed (CONTROLLER-RUN)

**Risk tier:** standard — no code changes; live-agent evidence collection with a revert protocol. The controller runs this task directly; do NOT dispatch an implementer subagent for it (live evals need the maintainer seat).

**Files:**
- Create: `evals/docs/experiments/2026-08-25-sdd-ledger-and-carveout.md` (committed in the `evals/` repo, not this one)
- Modify (only if the revert criterion fires): revert of Task 1/Task 2 commits.

**Interfaces:**
- Consumes: Tasks 1-2 committed on the branch.
- Produces: the pass/fail evidence and the experiment-log entry; the branch's readiness verdict.

- [ ] **Step 1: Offline sweep at the branch head**

```bash
pass=0; fail=0; failed=""
for t in $(find tests -name 'test-*.sh' | sort); do
  case "$t" in
  *test-subagent-driven-development.sh|*test-subagent-driven-development-integration.sh|*test-helpers.sh) continue ;;
  esac
  if timeout 120 bash "$t" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); failed="$failed $t"; fi
done
echo "PASS=$pass FAIL=$fail FAILED:$failed"
```

Expected: `PASS=34 FAIL=0`. Record the line in the execution ledger.

- [ ] **Step 2: Live eval — the fix-loop scenario (the carve-out's adversarial probe)**

`SUPERPOWERS_ROOT` must point at the WORKTREE (the tree carrying Tasks 1-2), not the main checkout — otherwise the eval provisions the unedited skills and proves nothing. The `evals/` clone lives only in the main checkout (it is untracked, so worktrees do not carry it); run quorum from there while rooting the skills at the worktree:

```bash
export SUPERPOWERS_ROOT=<absolute path to the sdd-skill-fixes worktree>
cd /Users/johnss51/Development/agents/hyperpowers/evals
bun run quorum run scenarios/sdd-unified-fix-loop --coding-agent claude-auto
```

Expected: verdict `pass`, all 5 post-checks green. Then verify from the run's `trajectory.json`, not the Gauntlet's word: the seeded `greet.js`/`src/utils.js` duplication fix was applied by a RESUMED implementer (SendMessage to the original agent id), NOT controller-applied. The seeded fix is multi-line reconciliation with judgment — above the carve-out's bound — so a controller-applied fix here means the carve-out over-reaches: the revert criterion fires for Task 2.

- [ ] **Step 3: Live bash suite (from the worktree, so `--plugin-dir` resolves to the edited skills)**

Run: `bash <worktree>/tests/claude-code/test-subagent-driven-development.sh`
Expected: 15/15 PASS. A failure in a todo-related assertion (if any) triages against Task 1's edit first.

- [ ] **Step 4: Live integration test (from the worktree, same reason)**

Run: `bash <worktree>/tests/claude-code/test-subagent-driven-development-integration.sh`
Expected: `STATUS: PASSED` within the 3600s ceiling. Test 3 passes on either signal; the run also demonstrates the todo-mirror text does not stop headless completion.

- [ ] **Step 5: Revert protocol (only on failure)**

If Step 2's transcript shows a controller-applied fix for the seeded finding, or any live run fails on behavior traceable to a text edit: `git revert` exactly the commit that carries the regressed change — Task 2's single commit for carve-out overreach; Task 1's todo-mirror commit for tracking regressions; Task 1's identity commit for resume regressions; Task 1's vacuity commit for evidence-rule regressions — then re-run the failed eval to confirm recovery, and record the disproof in the experiment log at equal billing. Infrastructure failures (socket drops, Gauntlet budget) are re-runs, not reverts — attribute before acting.

- [ ] **Step 6: Write the experiment-log entry (absolute path — the worktree has no `evals/`)**

Create `/Users/johnss51/Development/agents/hyperpowers/evals/docs/experiments/2026-08-25-sdd-ledger-and-carveout.md` recording: the four hypotheses (one per shortcoming), the exact edits (the four commit shas), baseline run pointers (`…0cf8`, the 2026-08-25 integration pass, 15/15 at `1e506fc`), the post-edit run pointers from Steps 2-4, verdicts, and any negative results at equal billing. Commit it in the `evals/` repository:

```bash
EVALS_ROOT=/Users/johnss51/Development/agents/hyperpowers/evals
cd "$EVALS_ROOT"
git add docs/experiments/2026-08-25-sdd-ledger-and-carveout.md
git commit -m "experiment: SDD ledger-anchoring and de-minimis carve-out gate"
```

- [ ] **Step 7: Record the gate verdict in the execution ledger**

Append the pass/fail table and run directories to the plan workspace's `progress.md`. All three live gates green = the plan's acceptance criterion. Any red that survives one attributed re-run = BLOCKED, surfaced to the human partner with the revert already applied.

## Verification Summary

| Check | Command | Expected |
|---|---|---|
| Contract needles | `bash tests/sdd/test-sdd-contract.sh` | 78 PASS / 0 FAIL |
| Offline sweep | 34 suites under timeout 120 | 34 / 0 |
| Fix-loop live | `quorum run scenarios/sdd-unified-fix-loop` | pass; resume verified in trajectory; no controller-applied seeded fix |
| Live bash suite | `test-subagent-driven-development.sh` | 15/15 |
| Integration | `test-subagent-driven-development-integration.sh` | STATUS: PASSED |

All five must hold. The carve-out ships only if the fix-loop scenario's resume evidence survives it.
