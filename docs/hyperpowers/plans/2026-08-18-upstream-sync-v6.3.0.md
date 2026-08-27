# Upstream Sync v6.0.2 → v6.3.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-08-17-upstream-sync-design.md`

**Goal:** Incorporate the assessed upstream superpowers changes (fork point `b62616f` through pinned head `b36e082`) into hyperpowers in three staged releases without losing fork-specific content.

**Architecture:** Three strictly ordered batches, each ending in a release checkpoint: (1) clean ports and token wins, (2) SDD lifecycle restructure with a unified five-round fix loop and plan-scoped scratch, (3) brainstorming three-path router. Heavily-diverged files are rebuilt from the pinned upstream version with a fork-delta inventory; everything else applies upstream content onto the fork base.

**Tech Stack:** Bash scripts + Markdown skills; repo test suite under `tests/`; hyperpowers-evals harness under `evals/`; `vrzn` for version bumps.

## Global Constraints

- **Source pin:** every upstream file/hunk is read at `b36e082` (`git show b36e082:<path>`), never at `upstream/main`. Going past `b36e082` requires a new assessment and spec review.
- **PORT-NORMALIZE recipe** (apply to every ported file):
  ```bash
  sed -e 's/superpowers:/hyperpowers:/g' \
      -e 's/using-superpowers/using-hyperpowers/g' \
      -e 's|docs/superpowers|docs/hyperpowers|g'
  ```
  Do NOT rename standalone "Superpowers"/"superpowers" prose words (deliberate fork voice: the capability is still called superpowers in prompts). Upstream `.superpowers/sdd` workspace paths must never land — SDD content is adapted to the fork's cache scratch, not transcribed.
- **Rulings-not-stalls is deferred:** any upstream text implementing controller self-rulings, the four hard-stop classes, or the "Rulings I made" roll-up is stripped during grafts; the fork keeps stop-on-BLOCKED and batched preflight questions to the human.
- Commit messages: no `Co-Authored-By`, no AI attribution. Never push. This plan file and the spec stay uncommitted.
- Each batch's final task is its release checkpoint; do not start a batch before the prior batch's checkpoint completes.
- Run `bash scripts/lint-shell.sh` before committing any task that changes a shell script.

---

## Batch 1 — Clean Ports

### Task 1: Port render-graphs.js fix and its test

**Risk tier:** standard — multi-file (script rewrite + new test file); transcription, but a new-script surface.

**Files:**
- Modify: `skills/writing-skills/render-graphs.js`
- Create: `tests/writing-skills/test-render-graphs.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks rely on.

- [ ] **Step 1: Reproduce the live breakage (RED)**

```bash
node skills/writing-skills/render-graphs.js skills/brainstorming 2>&1 | head -3
```
Expected: `ReferenceError: require is not defined in ES module scope` (repo `package.json` declares `"type": "module"`).

- [ ] **Step 2: Take the upstream files at the pin**

```bash
git show b36e082:skills/writing-skills/render-graphs.js > skills/writing-skills/render-graphs.js
mkdir -p tests/writing-skills
git show b36e082:tests/writing-skills/test-render-graphs.sh > tests/writing-skills/test-render-graphs.sh
chmod +x tests/writing-skills/test-render-graphs.sh
grep -n "superpowers" skills/writing-skills/render-graphs.js tests/writing-skills/test-render-graphs.sh || echo "no rename needed"
```
Expected: no `superpowers:`/`using-superpowers`/`docs/superpowers` occurrences (script and test are path-generic). If any appear, apply PORT-NORMALIZE.

- [ ] **Step 3: Run the ported test (GREEN)**

```bash
bash tests/writing-skills/test-render-graphs.sh
```
Expected: PASS lines for missing-graphviz exit, ES-module regression, real render; exit 0. (If `dot` is not installed the test's graphviz-missing branch documents the expected skip output — record whichever branch ran.)

- [ ] **Step 4: Commit**

```bash
git add skills/writing-skills/render-graphs.js tests/writing-skills/test-render-graphs.sh
git commit -m "fix(writing-skills): render-graphs works under type:module; port its test"
```

### Task 2: Port find-polluter.sh fixes and test

**Risk tier:** standard — multi-file (script + new test dir); transcription, but a new-script surface.

**Files:**
- Modify: `skills/systematic-debugging/find-polluter.sh`
- Create: `tests/systematic-debugging/test-find-polluter.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Take upstream files at the pin**

```bash
git show b36e082:skills/systematic-debugging/find-polluter.sh > skills/systematic-debugging/find-polluter.sh
mkdir -p tests/systematic-debugging
git show b36e082:tests/systematic-debugging/test-find-polluter.sh > tests/systematic-debugging/test-find-polluter.sh
chmod +x skills/systematic-debugging/find-polluter.sh tests/systematic-debugging/test-find-polluter.sh
```

- [ ] **Step 2: Verify the three fixes landed**

```bash
grep -n 'find . -path "./' skills/systematic-debugging/find-polluter.sh
grep -n 'TEST_FILES' skills/systematic-debugging/find-polluter.sh | head -5
```
Expected: `./`-prefixed `-path` matching present; empty-result guard present (count 0 when `$TEST_FILES` empty).

- [ ] **Step 3: Run the test**

```bash
bash tests/systematic-debugging/test-find-polluter.sh
```
Expected: all cases PASS (stubbed `npm`; covers ./-prefix, caller-supplied ./, `**/` top-level collapse), exit 0.

- [ ] **Step 4: Lint and commit**

```bash
bash scripts/lint-shell.sh
git add skills/systematic-debugging/find-polluter.sh tests/systematic-debugging/test-find-polluter.sh
git commit -m "fix(systematic-debugging): find-polluter matches ./-prefixed and top-level tests; port test suite"
```

### Task 3: Replace finishing-a-development-branch wholesale

**Risk tier:** low — wholesale replacement from the pinned commit of a file with zero fork-specific content; plan gives the exact producing command and verification greps.

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Confirm the fork file is unchanged from the merge base**

```bash
git diff --stat b62616f HEAD -- skills/finishing-a-development-branch/
```
Expected: empty output. (If not empty, STOP and report — the spec's zero-fork-content premise is violated.)

- [ ] **Step 2: Replace from the pin and normalize**

```bash
git show b36e082:skills/finishing-a-development-branch/SKILL.md \
  | sed -e 's/superpowers:/hyperpowers:/g' \
        -e 's/using-superpowers/using-hyperpowers/g' \
        -e 's|docs/superpowers|docs/hyperpowers|g' \
  > skills/finishing-a-development-branch/SKILL.md
```

- [ ] **Step 3: Verify the five changes are present**

```bash
grep -n "WORKTREE_PATH" skills/finishing-a-development-branch/SKILL.md | head -4
grep -n "status --porcelain -uall" skills/finishing-a-development-branch/SKILL.md
grep -ni "discard" skills/finishing-a-development-branch/SKILL.md | head -5
grep -n "superpowers:" skills/finishing-a-development-branch/SKILL.md || echo "namespace clean"
```
Expected: `WORKTREE_PATH` captured early (Step 2) and consumed later (no recompute after cd); the refused-removal `git -C "$WORKTREE_PATH" status --porcelain -uall` flow present; discard appears only as explicit-request-only (not a menu option); namespace clean.

- [ ] **Step 4: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(finishing-a-development-branch): adopt upstream v6.3.0 skill (path capture, refusal guard, no discard menu)"
```

### Task 4: TDD writing-good-tests rewrite

**Risk tier:** standard — multi-file behavior-shaping skill swap (two files replaced, one deleted), even though the content is pinned transcription.

**Files:**
- Modify: `skills/test-driven-development/SKILL.md`
- Create: `skills/test-driven-development/writing-good-tests.md`
- Delete: `skills/test-driven-development/testing-anti-patterns.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Swap in the pinned upstream files, normalized**

```bash
git show b36e082:skills/test-driven-development/SKILL.md \
  | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
  > skills/test-driven-development/SKILL.md
git show b36e082:skills/test-driven-development/writing-good-tests.md \
  | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
  > skills/test-driven-development/writing-good-tests.md
git rm -q skills/test-driven-development/testing-anti-patterns.md
```

- [ ] **Step 2: Verify no dangling references**

```bash
grep -rn "testing-anti-patterns" skills/ tests/ docs/porting-to-a-new-harness.md 2>/dev/null || echo "clean"
grep -n "writing-good-tests" skills/test-driven-development/SKILL.md | head -3
grep -n "superpowers:" skills/test-driven-development/*.md || echo "namespace clean"
```
Expected: no `testing-anti-patterns` references anywhere; SKILL.md points at `writing-good-tests.md`; namespace clean.

- [ ] **Step 3: Commit**

```bash
git add skills/test-driven-development/
git commit -m "feat(test-driven-development): adopt writing-good-tests rewrite (falsifiability, mutation check)"
```

### Task 5: Bootstrap compression and reference prune

**Risk tier:** standard — multi-file behavior-shaping surgery on the every-session bootstrap; adaptation required, not pure transcription.

**Files:**
- Modify: `skills/using-hyperpowers/SKILL.md`
- Modify: `skills/using-hyperpowers/references/codex-tools.md`
- Modify: `skills/using-hyperpowers/references/pi-tools.md`
- Modify: `skills/using-hyperpowers/references/antigravity-tools.md`
- Delete: `skills/using-hyperpowers/references/claude-code-tools.md`
- Delete: `skills/using-hyperpowers/references/copilot-tools.md`
- Modify: `skills/writing-skills/SKILL.md` (line 12 dead reference)
- Modify: `docs/porting-to-a-new-harness.md` (reference-integration table)
- Modify: `tests/pi/test-pi-extension.mjs`
- Modify: `tests/antigravity/test-antigravity-tools.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the compressed bootstrap other skills' cross-references must still resolve against (`references/codex-tools.md`, `references/pi-tools.md`, `references/antigravity-tools.md` remain; the two deleted files must have zero surviving referrers).

- [ ] **Step 1: Build the compressed bootstrap**

Read at the pin, then strip Hermes (the fork does not support Hermes):

```bash
git show b36e082:skills/using-superpowers/SKILL.md \
  | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
  > skills/using-hyperpowers/SKILL.md
```

Then hand-apply four fork adaptations:
1. Delete every Hermes reference (the Platform Adaptation mention of `hermes-tools.md` and any Hermes harness line). Verify: `grep -ni hermes skills/using-hyperpowers/SKILL.md` → no matches.
2. Frontmatter `name: using-hyperpowers` (the sed handles the body; fix the frontmatter name manually if the sed missed it — it has no colon-suffix form).
3. No Gemini references (fork removed Gemini — confirm none survived).
4. Platform Adaptation paragraph lists exactly the three surviving reference files (codex, pi, antigravity).

- [ ] **Step 2: Verify the compression and the tuned table survived**

```bash
wc -w skills/using-hyperpowers/SKILL.md
grep -c "|" skills/using-hyperpowers/SKILL.md
grep -n "This is just a simple question" skills/using-hyperpowers/SKILL.md
```
Expected: word count ≤ 500 (upstream post-compression is ~481); the Red Flags table rows present verbatim (the grep for its first row hits).

- [ ] **Step 3: Prune the reference files**

```bash
for f in codex-tools pi-tools antigravity-tools; do
  git show b36e082:skills/using-superpowers/references/$f.md \
    | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
    > skills/using-hyperpowers/references/$f.md
done
git rm -q skills/using-hyperpowers/references/claude-code-tools.md skills/using-hyperpowers/references/copilot-tools.md
grep -rni "hermes" skills/using-hyperpowers/references/ && echo "STRIP HERMES REFS" || echo "hermes clean"
grep -n "close_agent" skills/using-hyperpowers/references/codex-tools.md | head -3
```

Do NOT create `hermes-tools.md`. The `b36e082` codex-tools.md additionally carries upstream's source-verified V2 corrections (no `close_agent`, resume semantics, spawn routing) — a bonus within the spec's "post-prune" instruction; the `close_agent` grep should hit only in a "V2 has no close_agent"-style correction context, never in a tool table. If any of the three files mentions Hermes, delete that line.

- [ ] **Step 4: Fix the two dead references**

In `skills/writing-skills/SKILL.md` line 12 (the "Personal skills live in..." paragraph): replace the four-file reference list with:

```markdown
**Personal skills live in your runtime's skills directory** (`~/.claude/skills/` on Claude Code) — see [codex-tools.md](../using-hyperpowers/references/codex-tools.md) for Codex. Codex and Copilot CLI also recognize `~/.agents/skills/` as a cross-runtime alias.
```

In `docs/porting-to-a-new-harness.md`: update the reference-integration table rows that name `claude-code-tools.md` or `copilot-tools.md` to state those harnesses need no reference file (tool mapping is native); keep the codex/pi/antigravity rows pointing at the surviving files.

- [ ] **Step 5: Realign the reference-file tests (full fork rebrand, not just path sed)**

The upstream pi test also asserts the extension filename and package name
(`.pi/extensions/superpowers.ts`, `pkg.name === "superpowers"`), which are
`hyperpowers` in this fork. Take the pinned tests, then rebrand ALL fork
identifiers:

```bash
git show b36e082:tests/pi/test-pi-extension.mjs \
  | sed -e 's/using-superpowers/using-hyperpowers/g' \
        -e 's/superpowers\.ts/hyperpowers.ts/g' \
        -e 's/"superpowers"/"hyperpowers"/g' \
        -e "s/'superpowers'/'hyperpowers'/g" \
  > tests/pi/test-pi-extension.mjs
git show b36e082:tests/antigravity/test-antigravity-tools.sh \
  | sed -e 's/using-superpowers/using-hyperpowers/g' > tests/antigravity/test-antigravity-tools.sh
```

Then diff each against the fork's previous version (`git diff -- tests/pi tests/antigravity`) and re-apply any remaining fork-specific assertion the sed did not cover (compare identifiers against the fork's actual `.pi/extensions/` filename and `package.json` name before running). Run:

```bash
node tests/pi/test-pi-extension.mjs && bash tests/antigravity/test-antigravity-tools.sh
```
Expected: both pass against the pruned reference files and the fork's real extension/package names (upstream's `a60dc2f`/`a80b7b6` realignments are contained in the `b36e082` versions).

- [ ] **Step 6: Sweep for survivors and commit**

```bash
grep -rn "claude-code-tools\|copilot-tools" skills/ tests/ docs/ hooks/ 2>/dev/null | grep -v "porting-to-a-new-harness" || echo "clean"
git add -A skills/using-hyperpowers skills/writing-skills/SKILL.md docs/porting-to-a-new-harness.md tests/pi tests/antigravity
git commit -m "feat(bootstrap): compress using-hyperpowers bootstrap and prune per-harness references"
```
Expected: only historical docs (RELEASE-NOTES, old specs) may still mention the deleted files.

### Task 6: No-subagents contract in code-reviewer.md

**Risk tier:** low — single-file wholesale take from the pin; fork file is byte-identical to the upstream pre-change version.

**Files:**
- Modify: `skills/requesting-code-review/code-reviewer.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the "You Do Not Dispatch Subagents" section wording later reused by Batch 2's prompt-file grafts (Task 13 takes the same wording from the same pin).

- [ ] **Step 1: Confirm clean-apply premise, then take the pinned file**

```bash
git diff --stat b62616f HEAD -- skills/requesting-code-review/code-reviewer.md
git show b36e082:skills/requesting-code-review/code-reviewer.md \
  | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' \
  > skills/requesting-code-review/code-reviewer.md
grep -n "You Do Not Dispatch Subagents" skills/requesting-code-review/code-reviewer.md
```
Expected: empty diff first (else STOP and hand-merge instead); section heading present after the take.

- [ ] **Step 2: Commit**

```bash
git add skills/requesting-code-review/code-reviewer.md
git commit -m "feat(requesting-code-review): reviewers do not dispatch subagents"
```

### Task 7: Mechanical compression refactors

**Risk tier:** standard — multi-file skill/doc surgery; two files need fork-aware adaptation.

**Files:**
- Modify: `skills/receiving-code-review/SKILL.md`
- Modify: `skills/writing-skills/SKILL.md`
- Modify: `skills/writing-plans/SKILL.md`
- Modify: `skills/using-git-worktrees/SKILL.md`
- Modify: `skills/requesting-code-review/SKILL.md`
- Modify: `skills/executing-plans/SKILL.md`
- Modify: `skills/systematic-debugging/SKILL.md`
- Modify: `skills/dispatching-parallel-agents/SKILL.md`

(Per the spec's ordering rule, this task must NOT touch `skills/subagent-driven-development/` or `skills/brainstorming/` — Batches 2/3 rebuild those.)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Wholesale takes for the three fork-identical files**

```bash
for f in receiving-code-review using-git-worktrees dispatching-parallel-agents; do
  git diff --stat b62616f HEAD -- skills/$f/SKILL.md   # expect empty
  git show b36e082:skills/$f/SKILL.md \
    | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
    > skills/$f/SKILL.md
done
```
Expected: each pre-diff empty (verified fork-identical). If any is non-empty, fall back to the targeted deletion for that file: remove only the section upstream removed (receiving-code-review "## The Bottom Line"; using-git-worktrees "Common Mistakes"+"Red Flags" → the 5-row rationalization table from `git show b36e082:skills/using-git-worktrees/SKILL.md`; dispatching-parallel-agents "Time saved"/"Key Benefits"/"Real-World Impact" lines).

- [ ] **Step 2: Targeted deletions in the diverged files**

Each edit deletes a section verbatim-present in the fork file (verify with grep first; if a heading is absent, STOP and re-check against `git diff b62616f HEAD -- <file>`):

1. `skills/writing-skills/SKILL.md`: delete the `## The Bottom Line` section (heading through end of its paragraph block, at file end).
2. `skills/writing-plans/SKILL.md`: delete the `## Remember` section (4 bullets + heading). Then reword the earlier cross-reference (line ~20) `(The "frequent commits" guidance below is about the implementation task steps the plan describes, not the plan file itself.)` → `(Frequent commits applies to the implementation task steps the plan describes, not the plan file itself.)`
3. `skills/requesting-code-review/SKILL.md`: apply upstream `cfb6281`'s two edits — trim the intro sentence and replace the `## Integration with Workflows` section with the 2-row rationalization table exactly as in `git show b36e082:skills/requesting-code-review/SKILL.md` (copy that section text, PORT-NORMALIZEd). Do not touch the fork's Codex gate step.
4. `skills/executing-plans/SKILL.md`: delete the `## Integration` section entirely (fork's extra third entry, finishing-a-development-branch, is already referenced inline at Step 3); trim the quality-claim sentence from the subagent Note per upstream `09fc6e0` (delete the sentence beginning "This produces..." in the Note at line ~14, keeping the fork's "Superpowers" wording in what remains).
5. `skills/systematic-debugging/SKILL.md`: delete the `## Real-World Impact` section; delete the Related-skills block (line ~286) and fold into Phase 4 a single line: `Verification: re-run the original failing command and confirm the failure is gone before claiming the fix.` (fork wording — do NOT adopt upstream's verification-before-completion pointer; that skill does not exist in the fork).

- [ ] **Step 3: Verify and commit**

```bash
grep -rn "## The Bottom Line\|## Remember$\|## Integration with Workflows\|## Real-World Impact" \
  skills/receiving-code-review skills/writing-skills skills/writing-plans skills/using-git-worktrees \
  skills/requesting-code-review skills/executing-plans skills/systematic-debugging skills/dispatching-parallel-agents \
  || echo "sections gone"
grep -rn "verification-before-completion" skills/systematic-debugging/ || echo "no dangling pointer"
git add skills/receiving-code-review skills/writing-skills skills/writing-plans skills/using-git-worktrees \
  skills/requesting-code-review skills/executing-plans skills/systematic-debugging skills/dispatching-parallel-agents
git commit -m "refactor(skills): adopt upstream compression sweep (drop recap sections, rationalization tables)"
```

### Task 8: Test harness fixes

**Risk tier:** standard — multi-file test-infrastructure edits with one fork divergence to preserve.

**Files:**
- Modify: `tests/claude-code/run-skill-tests.sh`
- Modify: `tests/claude-code/test-helpers.sh`
- Modify: `tests/claude-code/test-subagent-driven-development.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: case-insensitive `assert_contains`/`assert_not_contains`/`assert_count`/`assert_order` used by Batch 2/3 eval-adjacent test runs.

- [ ] **Step 1: Apply the timeout and helper fixes**

In `tests/claude-code/run-skill-tests.sh`: change `TIMEOUT=600` (line ~28) to `TIMEOUT=900`; fix the help text (line ~55) `default: 300` → `default: 900`.

In `tests/claude-code/test-helpers.sh`: make the four assert helpers case-insensitive exactly as upstream `0e13ad8` does — take the upstream helper bodies:

```bash
git show b36e082:tests/claude-code/test-helpers.sh > /tmp/claude/upstream-helpers.sh
diff /tmp/claude/upstream-helpers.sh tests/claude-code/test-helpers.sh
```

Expected diff: ONLY the fork's `docs/hyperpowers` path line (~146) plus any rename lines. Merge by taking the upstream file and re-applying the fork's `docs/hyperpowers` path line:

```bash
sed -e 's|docs/superpowers|docs/hyperpowers|g' /tmp/claude/upstream-helpers.sh > tests/claude-code/test-helpers.sh
```

In `tests/claude-code/test-subagent-driven-development.sh`: widen the two Test 5 patterns (lines ~99/105) to the upstream `b36e082` versions (copy those two lines verbatim from `git show b36e082:tests/claude-code/test-subagent-driven-development.sh`, PORT-NORMALIZEd).

- [ ] **Step 2: Sanity-run and commit**

```bash
bash -n tests/claude-code/run-skill-tests.sh tests/claude-code/test-helpers.sh tests/claude-code/test-subagent-driven-development.sh
bash tests/claude-code/test-sdd-dir-path.sh
git add tests/claude-code/
git commit -m "fix(tests): raise skill-test timeout, case-insensitive asserts, widen SDD patterns"
```
Expected: syntax-check clean; the sdd-dir test (which sources helpers) still passes.

### Task 9: Portability nits

**Risk tier:** standard — multi-file, and it changes SessionStart hook execution configuration (behavior-shaping harness config; not approval-authority code, so not high).

**Files:**
- Modify: `.codex-plugin/plugin.json`
- Modify: `hooks/hooks.json`
- Modify: `tests/hooks/test-session-start.sh`
- Modify: `docs/windows/polyglot-hooks.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Category fix**

In `.codex-plugin/plugin.json` line ~30: `"category": "Coding"` → `"category": "Developer Tools"`.

- [ ] **Step 2: SessionStart shell dispatch**

In `hooks/hooks.json`, add `"shell": "bash"` to the SessionStart hook entry (same JSON object as its `command`), matching upstream `5151e7a`. Port the registration-shape assertion block from `git show b36e082:tests/hooks/test-session-start.sh` into `tests/hooks/test-session-start.sh` (copy the `shell` assertion test verbatim; do NOT take the upstream file wholesale — the fork's Codex-hook test cases at lines ~157-230 must survive).

- [ ] **Step 3: Docs, verify, commit**

```bash
git show b36e082:docs/windows/polyglot-hooks.md > docs/windows/polyglot-hooks.md
python3 -c "import json;json.load(open('hooks/hooks.json'));json.load(open('.codex-plugin/plugin.json'))" && echo "json ok"
bash tests/hooks/test-session-start.sh
git add .codex-plugin/plugin.json hooks/hooks.json tests/hooks/test-session-start.sh docs/windows/polyglot-hooks.md
git commit -m "fix(hooks): Git Bash dispatch on Windows; Codex plugin category"
```
Expected: `json ok`; session-start test passes including the new shell assertion and the retained Codex cases.

### Task 23: Fix pre-existing brainstorm-server branding test failures

(Numbered 23 to avoid renumbering; **executes between Task 9 and Task 10** — the Batch 1 gate depends on it. Added by user decision 2026-08-18 after the baseline run found 3 pre-existing failures.)

**Risk tier:** standard — requires judgment about intent (test vs code defect) across test and server files.

**Files:**
- Modify: `tests/brainstorm-server/` (branding test file(s)) and/or the brainstorm-server rendering source under `skills/brainstorming/` — whichever side diverged from intent
- Baseline evidence: `npm test` in `tests/brainstorm-server` currently fails 3 "Visual Companion Branding" cases, each with "visible logo should appear before the Superpowers version text"

**Interfaces:**
- Consumes: nothing.
- Produces: a fully green brainstorm-server suite for Task 10's gate.

- [ ] **Step 1: Reproduce and localize**

```bash
cd tests/brainstorm-server && npm test 2>&1 | grep -B2 -A4 "FAIL:"
```
Read the failing assertions and the rendering code they exercise. Determine which side diverged: (a) the fork intentionally rebranded the visual companion (then the TESTS must assert the fork's actual branding/order), or (b) a fork change regressed the logo-before-version rendering (then the CODE must be fixed). Check `git log --oneline -- <server source>` for the rebranding history to establish intent.

- [ ] **Step 2: Fix the diverged side**

Apply the fix on whichever side Step 1 identified. Do not change both sides. Keep the telemetry-opt-out behavior (the 4 passing cases) intact.

- [ ] **Step 3: Verify and commit**

```bash
cd tests/brainstorm-server && npm test
```
Expected: 0 failed across all result groups.

```bash
git add -A tests/brainstorm-server skills/brainstorming
git commit -m "fix(brainstorm-server): align visual-companion branding tests with fork intent"
```

### Task 10: Batch 1 release checkpoint

**Risk tier:** standard — release mechanics; ordered verification per spec.

(Depends on Task 23 — the brainstorm-server suite must be fully green first. `tests/brainstorm-server/windows-lifecycle.test.sh` passes but takes over 2 minutes: run it with a 10-minute timeout, never a default 120 s one.)

**Files:**
- Modify: version manifests (via `vrzn`)

**Interfaces:**
- Consumes: all Batch 1 tasks committed.
- Produces: released Batch 1; installed plugin refreshed.

- [ ] **Step 1: Full repo test suite (per docs/testing.md)**

```bash
set -e
# Every bash test across the plugin test dirs (antigravity, claude-code,
# codex-review-gate, hooks, kimi, opencode, packaging, pi, sdd, shell-lint,
# plus the two dirs this sync added), excluding LLM-session drivers.
for t in tests/*/test-*.sh; do
  case "$t" in *run-skill-tests*) continue;; esac
  echo "== $t"; bash "$t"
done
# Aggregate no-arg runners, named explicitly — never a blanket glob: several
# run-*.sh files are argument-requiring helpers or LLM-session drivers
# (tests/explicit-skill-requests/run-test.sh & friends exit 1 without args).
for r in tests/antigravity/run-tests.sh tests/kimi/run-tests.sh tests/opencode/run-tests.sh; do
  echo "== $r"; bash "$r"
done
# Node suites.
(cd tests/brainstorm-server && npm test)
# windows-lifecycle.test.sh matches neither the test-*.sh glob nor the
# brainstorm-server npm test script — run it explicitly.
bash tests/brainstorm-server/windows-lifecycle.test.sh
node tests/pi/test-pi-extension.mjs
bash scripts/lint-shell.sh
```
Expected: all pass. The LLM-session tests are exercised separately and intentionally: run `bash tests/claude-code/run-skill-tests.sh` and `bash tests/explicit-skill-requests/run-all.sh` once here (slow — real sessions; Task 8 raised the skill-test timeout) and record both results; a failure blocks the release like any other. The per-case helpers in `tests/explicit-skill-requests/` (`run-test.sh`, `run-haiku-test.sh`, `run-multiturn-test.sh`, `run-extended-multiturn-test.sh`) are invoked by `run-all.sh`, never directly by the gate.

- [ ] **Step 2: Pre-release refresh from the candidate working tree**

```bash
INSTALL_DIR=$(ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1)
rsync -a --delete skills/ "$INSTALL_DIR/skills/"
rsync -a hooks/ "$INSTALL_DIR/hooks/"
```

- [ ] **Step 3: Acceptance smoke against the candidate**

```bash
claude -p "Let's make a react todo list" --max-turns 4 2>&1 | tee /tmp/claude/smoke.txt | grep -i "brainstorm"
```
Expected: output shows the brainstorming skill invoked before any code (per the repo's acceptance test). If it does not, STOP — the compressed bootstrap broke auto-triggering; report with `/tmp/claude/smoke.txt`.

- [ ] **Step 4: Release**

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y
git add -A ':!docs/hyperpowers'
git commit -m "Release: upstream sync batch 1 — clean ports and bootstrap compression"
INSTALL_NEW=$(ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1)
rsync -a --delete skills/ "$INSTALL_NEW/skills/"; rsync -a hooks/ "$INSTALL_NEW/hooks/"
```
Expected: version manifests bumped by one minor; commit excludes `docs/hyperpowers/` (spec/plan stay uncommitted); installed copy re-aligned.

---

## Batch 2 — SDD Restructure and Efficiency

### Task 11: Plan-scoped sdd-dir with collision-resistant slug

**Risk tier:** high — `sdd-dir`'s output is trusted by task-brief, review-package, and the SKILL.md ledger contract (a script whose output other machinery trusts), and it deletes directories (GC).

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-dir`
- Modify: `tests/claude-code/test-sdd-dir-path.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `sdd-dir [PLAN_FILE]` — no-arg prints the repo-instance dir (unchanged, still used by `skills/optimizing-performance/SKILL.md:38`); with `PLAN_FILE` prints `<repo-dir>/<basename-noext>-<hash8>` where `hash8 = git hash-object over the normalized repo-relative plan path, first 8 chars`. Tasks 12–14 call it with the plan argument.

- [ ] **Step 1: Write the failing test**

Append to `tests/claude-code/test-sdd-dir-path.sh` (before the final summary/exit block, matching the file's `pass`/`fail` style):

```bash
echo "Test: plan-scoped workspaces are distinct for same-basename plans"
make_repo "$TEST_ROOT/repo-plan"
mkdir -p "$TEST_ROOT/repo-plan/docs/a" "$TEST_ROOT/repo-plan/docs/b"
echo plan > "$TEST_ROOT/repo-plan/docs/a/plan.md"
echo plan > "$TEST_ROOT/repo-plan/docs/b/plan.md"
noarg=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT")
da=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
db=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/b/plan.md)
if [ "$da" != "$db" ]; then pass "same basename, different dirs -> distinct workspaces"; else fail "collision: $da == $db"; fi
case "$da" in "$noarg"/plans/plan-*) pass "plan dir nests under repo plans/ subdir with slug prefix";; *) fail "unexpected plan dir shape: $da (repo dir: $noarg)";; esac
dabs=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" "$TEST_ROOT/repo-plan/docs/a/plan.md")
if [ "$da" = "$dabs" ]; then pass "relative and absolute plan paths agree"; else fail "path-form sensitivity: $da vs $dabs"; fi
```

- [ ] **Step 2: Run to verify it fails**

```bash
bash tests/claude-code/test-sdd-dir-path.sh
```
Expected: new cases FAIL (current script ignores arguments — `da == db == noarg`).

- [ ] **Step 3: Implement plan scoping in sdd-dir**

Insert after the existing `dir="${base}/${key}"` line and before `mkdir -p "$dir"`:

```bash
# Optional PLAN_FILE argument scopes the workspace to one plan. The slug is
# the plan basename plus an 8-char hash of the normalized repo-relative
# path: basename alone collides (two plans named plan.md in different
# directories must not share a ledger). No-arg mode is unchanged — it is
# the repo-instance dir other skills use as a generic cache root.
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
  plan=$1
  plan_dir=$(cd "$(dirname "$plan")" 2>/dev/null && pwd) || {
    echo "sdd-dir: plan file directory does not exist: $plan" >&2
    exit 2
  }
  abs="${plan_dir}/$(basename "$plan")"
  toplevel=$(git rev-parse --show-toplevel)
  rel=${abs#"$toplevel"/}
  slug=$(basename "$plan")
  slug=${slug%.*}
  hash8=$(printf '%s' "$rel" | git hash-object --stdin | cut -c1-8)
  plans_root="${dir}/plans"
  dir="${plans_root}/${slug}-${hash8}"
fi
```

Plan workspaces live under a dedicated `plans/` subdirectory of the repo dir
so the plan-level GC can never touch non-plan content that other machinery
(e.g. `optimizing-performance` via no-arg `sdd-dir`) stores directly under
the repo cache root. After the existing repo-level GC `find`, add (delete-at-finish
is the primary cleanup; this backstops abandoned plans):

```bash
# Plan-level GC backstop: stale sibling plan workspaces are pruned on the
# same 14-idle-day rule. Scoped to the plans/ subdir only — never non-plan
# cache content under the repo dir — and never the current plan's dir.
if [ -n "${plans_root:-}" ]; then
  find "$plans_root" -mindepth 1 -maxdepth 1 -type d ! -name "$(basename "$dir")" -mtime +14 \
    -exec rm -rf {} + 2>/dev/null || true
fi
```

- [ ] **Step 3b: Extend the test for the plan-level GC**

Append to the same test file (after Step 1's cases):

```bash
echo "Test: stale sibling plan workspaces pruned; fresh and non-plan content kept"
stale="$noarg/plans/old-plan-deadbeef"
freshdir="$noarg/plans/fresh-plan-cafef00d"
nonplan="$noarg/perf-cache-notaplan"
mkdir -p "$stale" "$freshdir" "$nonplan"
OLDSTAMP="$(date -v-20d +%Y%m%d%H%M 2>/dev/null || date -d '20 days ago' +%Y%m%d%H%M)"
touch -mt "$OLDSTAMP" "$stale" "$nonplan"
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ ! -d "$stale" ]; then pass "stale sibling plan dir pruned"; else fail "stale plan dir survived"; fi
if [ -d "$freshdir" ]; then pass "fresh sibling plan dir kept"; else fail "fresh plan dir wrongly pruned"; fi
if [ -d "$nonplan" ]; then pass "stale NON-plan sibling under repo root preserved"; else fail "GC deleted non-plan cache content"; fi
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash tests/claude-code/test-sdd-dir-path.sh && bash scripts/lint-shell.sh
```
Expected: all cases pass, including the pre-existing no-arg/GC/worktree cases (no-arg behavior unchanged).

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-dir tests/claude-code/test-sdd-dir-path.sh
git commit -m "feat(sdd): plan-scoped scratch workspaces with collision-resistant slugs"
```

### Task 12: Thread the plan through task-brief and review-package

**Risk tier:** high — both scripts produce artifacts (briefs, review packages) that reviewer machinery trusts; a wrong-dir write silently severs the review chain.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/task-brief`
- Modify: `skills/subagent-driven-development/scripts/review-package`
- Modify: `tests/claude-code/test-sdd-dir-path.sh` (it exercises both scripts)

**Interfaces:**
- Consumes: `sdd-dir [PLAN_FILE]` from Task 11.
- Produces: `task-brief PLAN_FILE TASK_NUMBER [OUTFILE]` (signature unchanged; default OUTFILE now lands in the plan-scoped dir) and `review-package PLAN_FILE BASE HEAD [OUTFILE]` (signature CHANGED — plan path is now the first argument). Tasks 13–14 write these invocations into prompts/SKILL.md.

- [ ] **Step 1: task-brief — derive the plan-scoped dir**

`task-brief` already receives `PLAN_FILE` as `$1` (kept in `$plan`). Change its default-OUTFILE derivation to pass the plan to sdd-dir: replace the existing `"$SCRIPT_DIR/sdd-dir"` invocation with `"$SCRIPT_DIR/sdd-dir" "$plan"`. Update the header comment's default-OUTFILE line to `<sdd-dir PLAN_FILE>/task-<N>-brief.md — unique per plan`.

- [ ] **Step 2: review-package — new first argument**

Change usage to `review-package PLAN_FILE BASE HEAD [OUTFILE]`:
- arg validation: `[ $# -lt 3 ] || [ $# -gt 4 ]` → usage error `usage: review-package PLAN_FILE BASE HEAD [OUTFILE]`
- `plan=$1; base=$2; head=$3; out=${4:-}`
- default-OUTFILE derivation passes the plan: `"$SCRIPT_DIR/sdd-dir" "$plan"`
- header comment updated to the new usage line.

- [ ] **Step 3: Update the scripts' callers in tests, run, commit**

```bash
grep -rn "review-package\b" tests/ skills/ | grep -v subagent-driven-development/SKILL.md | grep -v prompt
```
Update every call site found in `tests/claude-code/test-sdd-dir-path.sh` to the new `PLAN_FILE BASE HEAD` order (create a dummy plan file in the test repo where needed). SKILL.md/prompt call sites are Batch 2 Tasks 13–14, not this task.

```bash
bash tests/claude-code/test-sdd-dir-path.sh && bash scripts/lint-shell.sh
git add skills/subagent-driven-development/scripts/ tests/claude-code/test-sdd-dir-path.sh
git commit -m "feat(sdd): task-brief and review-package write into the plan-scoped workspace"
```

### Task 13: Rebuild the SDD prompt files from the pin

**Risk tier:** standard — behavior-shaping prompt surgery across four files with fork deltas to re-apply.

**Files:**
- Modify: `skills/subagent-driven-development/implementer-prompt.md`
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md`
- Create: `skills/subagent-driven-development/re-review-prompt.md`
- Modify: `skills/subagent-driven-development/fix-subagent-prompt.md`

**Interfaces:**
- Consumes: `review-package PLAN_FILE BASE HEAD [OUTFILE]` (Task 12).
- Produces: the four prompt templates Task 15's SKILL.md references by exact filename; `re-review-prompt.md` verdicts per finding as `ADDRESSED` / `NOT ADDRESSED`.

- [ ] **Step 1: Record the fork delta (the graft inventory)**

```bash
git diff b62616f HEAD -- skills/subagent-driven-development/implementer-prompt.md \
  skills/subagent-driven-development/task-reviewer-prompt.md > /tmp/claude/sdd-prompt-delta.diff
wc -l /tmp/claude/sdd-prompt-delta.diff
```
Expected: a small delta (assessment: ~7 lines on task-reviewer). Every `-`/`+` hunk in this file must be accounted for in Step 3.

- [ ] **Step 2: Take the pinned upstream versions**

```bash
for f in implementer-prompt task-reviewer-prompt re-review-prompt; do
  git show b36e082:skills/subagent-driven-development/$f.md \
    | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
    > skills/subagent-driven-development/$f.md
done
grep -rn "\.superpowers/sdd" skills/subagent-driven-development/*.md && echo "ADAPT NEEDED" || echo "workspace paths clean"
```
If `ADAPT NEEDED`: replace every upstream `.superpowers/sdd/<plan>` workspace reference with the fork's scratch contract — the dir printed by `scripts/sdd-dir PLAN_FILE` (reference it as "the plan's scratch dir (from `scripts/sdd-dir <plan>`)", never a literal path).

- [ ] **Step 3: Re-apply fork deltas from Step 1's inventory**

For each fork-specific hunk in `/tmp/claude/sdd-prompt-delta.diff` (expected: the `docs/hyperpowers` plan-path examples and the fork's `review-package` invocation lines), re-apply it to the new file, updating any `review-package BASE HEAD` example to `review-package PLAN_FILE BASE HEAD`. Confirm the upstream files carry the "You Do Not Dispatch Subagents" section in all three (they do at the pin).

- [ ] **Step 4: Shrink fix-subagent-prompt.md to the final-review wave**

Replace the prompt's opening scope paragraph with:

```markdown
You are dispatched for the FINAL-REVIEW fix wave only: the per-task fix loop
resumes the original implementer (rounds 1-3) or dispatches a takeover
implementer (rounds 4-5) — it never uses this prompt. You fix the final
review's blocking findings in one wave; exactly one scoped re-review follows.
```

Keep the rest of the fork prompt (finding list format, constraints) unchanged.

- [ ] **Step 5: Verify and commit**

```bash
grep -l "You Do Not Dispatch Subagents" skills/subagent-driven-development/*.md
grep -n "ADDRESSED" skills/subagent-driven-development/re-review-prompt.md | head -3
grep -rn "superpowers:" skills/subagent-driven-development/*.md || echo "namespace clean"
git add skills/subagent-driven-development/*.md
git commit -m "feat(sdd): resume-based fix-round prompts, scoped re-review template, no-subagents contract"
```

### Task 14: writing-plans Spec header

**Risk tier:** low — single-file template addition with the complete content given below.

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the `**Spec:**` header line SDD Setup (Task 15) reads.

- [ ] **Step 1: Add the Spec field to the plan header template**

In the Plan Document Header template (after the `> **For agentic workers:**` line, before `**Goal:**`), insert:

```markdown
**Spec:** [path to the spec/design doc this plan implements — SDD reads it as binding authority; write "none" only if no spec exists]
```

- [ ] **Step 2: Verify against upstream intent, commit**

```bash
git show b36e082:skills/writing-plans/SKILL.md | sed -n '65,73p'
grep -n "Spec:" skills/writing-plans/SKILL.md | head -3
git add skills/writing-plans/SKILL.md
git commit -m "feat(writing-plans): plans carry a Spec header for execution-time authority"
```

### Task 15: SDD SKILL.md lifecycle restructure + unified fix loop + gate-doc reconciliation

**Risk tier:** high — this task rewrites the SDD control loop AND the Codex gate document in one commit; the gate doc's round-budget language is trusted by every future gated run.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (full rebuild)
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§3 tier text, §5 backstop table)

**Interfaces:**
- Consumes: `sdd-dir PLAN_FILE` (Task 11), `task-brief`/`review-package` signatures (Task 12), prompt files incl. `re-review-prompt.md` (Task 13), the `**Spec:**` plan-header field (Task 14).
- Produces: the restructured lifecycle every later eval asserts against; ledger first line `# SDD ledger — plan: <plan file path>`.

- [ ] **Step 1: Produce the fork-delta inventory (graft checklist)**

```bash
git diff b62616f HEAD -- skills/subagent-driven-development/SKILL.md > /tmp/claude/sdd-skill-delta.diff
```

Fork blocks that MUST re-land (destination in the upstream shape `Setup → Model Selection → The Task Loop (1 Dispatch / 2 Handle report / 3 Review / 4 Fix loop / 5 Complete) → Final Review → Finish → Common Rationalizations → Example Workflow`):

| Fork block (fork HEAD lines) | Destination |
|---|---|
| Risk Tiers + rubric + tier-skips file (246-282) | Own section after The Task Loop, referenced from step 3 |
| Codex Review Gate sections (283-313) | Step 4 (per-task gate) + Final Review (branch gate) |
| ungated-ledger wiring (within 283-313) | Stays with the gate text |
| Subagent Reports Are Claims (168-182) | Into "2. Handle the report" |
| Constructing Reviewer Prompts fork additions (183-245) | Into "3. Review the task" |
| File Handoffs (314-342, fork scratch contract) | Setup (workspace paragraph) — cache-based wording, NOT upstream's `.superpowers/sdd` |
| Durable Progress (343-371) | Setup — rewritten (Step 3 below) |
| Continuous execution note (line 17) | Overview |

Upstream blocks to STRIP during the rebuild (rulings deferred): "rule and continue" doctrine, the four hard-stop classes as replacements for BLOCKED, `Ruling:` ledger token, "Rulings I made" finish roll-up. KEEP upstream's: wait-discipline block, batching block, preflight evidence table (but keep the fork's batched-questions-to-human step), evidence re-read rule (it lives in task-reviewer-prompt, Task 13), five-round fix loop, scoped re-review, Setup-reads-spec. ADD to the batching block this fork rule (spec-mandated): `A batch's effective risk tier for the per-task Codex gate is the MAX of the batched tasks' declared tiers — batching low-tier tasks never manufactures a gate skip.`

- [ ] **Step 2: Rebuild the file**

```bash
git show b36e082:skills/subagent-driven-development/SKILL.md \
  | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
  > skills/subagent-driven-development/SKILL.md
```

Then edit per the Step 1 checklist: strip the rulings blocks, graft each fork block at its destination, and adapt all workspace references to the fork scratch contract (`scripts/sdd-dir <plan>`; ledger at `<dir>/progress.md`).

- [ ] **Step 3: Write the unified fix loop and durable-progress text**

The fix-loop section ("4. The fix loop") must state, in this order (adapt upstream's wording, preserving these exact rules):

1. Blocking findings from the Claude task reviewer AND from the per-task Codex gate enter ONE loop with ONE shared cap of five rounds per task.
2. Rounds 1–3: resume the original implementer with the findings verbatim. Rounds 4–5: dispatch a fresh takeover implementer on a more capable model.
3. Every round is verified by the scoped re-review (`re-review-prompt.md`, over `review-package PLAN_FILE FIX_BASE HEAD` where `FIX_BASE` = the head the previous review saw) — never a full task-reviewer re-run.
4. Codex-origin findings re-enter the Codex gate only after the scoped re-review confirms ADDRESSED; the gate's own rounds count against the same five-round cap.
5. At round 5 unresolved: STOP fork-style — surface the findings to your human partner via BLOCKED. (No park-with-ruling.)
6. Minor findings never enter the loop; they go to the ledger.

Durable Progress (in Setup) must state: workspace = `scripts/sdd-dir <plan>`; ledger first line is `# SDD ledger — plan: <plan file path>`; the start-of-skill ledger check reads only this plan's workspace; the Finish step deletes the plan workspace when the final review is clean (the 14-day GC remains as backstop); Setup reads the plan's `**Spec:**` header and the spec file it names — the spec is binding authority; its absence is ledgered.

- [ ] **Step 4: Reconcile codex-review-gate.md in the same commit**

In `skills/requesting-code-review/codex-review-gate.md`:

1. §5 backstop table: replace the code-gate row with two rows:

```markdown
| SDD per-task (code gate) | adversarial-review | shares SDD's five-round per-task fix cap (see hyperpowers:subagent-driven-development) — no separate Codex ceiling |
| Final / code-review requests (code gates) | adversarial-review | 3 |
```

2. §3 tier-applicability paragraph: after the existing tier text, add: `Within SDD's per-task loop, gate rounds count against the task's shared five-round fix cap; the scoped re-review (not a full task-reviewer re-run) precedes each Codex re-round.`
3. Spec feeds the gates (spec-mandated): in the rebuilt SDD SKILL.md's gate text, the per-task gate's dossier `--adjudications` inputs include the plan's `**Spec:**` file path, and the final gate's dossier passes it as a `--doc` input. Verification: `grep -n "Spec" skills/subagent-driven-development/SKILL.md | grep -i "adjudications\|--doc"` hits both.
4. Document gates stay at 4 — verify no other text changes.

- [ ] **Step 5: Verify (greps per spec) and commit**

```bash
grep -n "five-round\|five round" skills/subagent-driven-development/SKILL.md skills/requesting-code-review/codex-review-gate.md | head
grep -n "re-run the task reviewer before re-running the per-task Codex gate" skills/subagent-driven-development/SKILL.md skills/requesting-code-review/codex-review-gate.md || echo "old rule gone"
grep -n "Ruling:" skills/subagent-driven-development/SKILL.md || echo "rulings stripped"
grep -n "SDD ledger — plan:" skills/subagent-driven-development/SKILL.md
grep -n "\.superpowers/sdd" skills/subagent-driven-development/SKILL.md || echo "workspace adapted"
grep -n "Waiting on dispatched subagents\|Batch small same-shape" skills/subagent-driven-development/SKILL.md
bash tests/claude-code/test-subagent-driven-development.sh
git add skills/subagent-driven-development/SKILL.md skills/requesting-code-review/codex-review-gate.md
git commit -m "feat(sdd): lifecycle restructure with unified five-round fix loop; gate doc reconciled"
```
Expected: old per-task re-run rule absent everywhere; rulings absent; ledger identity line, wait discipline, and batching present; every Step 1 inventory row checked off (verify each block's needle appears: "Risk tier", "Codex Review Gate", "Subagent Reports Are Claims", "ungated-ledger", tier-skips); SDD skill test passes.

### Task 16: Batch 2 eval — fix-loop convergence

**Risk tier:** standard — new eval scenario; assertions must encode the unified-loop contract.

**Files:**
- Create: `evals/scenarios/sdd-unified-fix-loop/` (scenario dir per harness convention)

**Interfaces:**
- Consumes: the restructured SKILL.md (Task 15) as the behavior under test.
- Produces: the Batch 2 release-gating eval.

- [ ] **Step 1: Copy the harness conventions from the closest existing scenario**

```bash
ls evals/scenarios/codex-gate-converges-on-reraise/
cat evals/README.md | head -60
```
Use that scenario's file layout (prompt, fixture repo, verifier config) as the template.

- [ ] **Step 2: Author the scenario**

Fixture: a small repo with a 2-task plan (with `**Spec:**` header) and a seeded defect the reviewer will flag. Scenario must assert ALL of:
1. After round 1 findings, the controller resumes the original implementer (transcript shows resume/SendMessage, not a fresh fix-subagent dispatch); if the scenario reaches round 4, a fresh takeover implementer is dispatched instead of another resume.
2. The re-review is scoped: `re-review-prompt` used, `review-package` called with `PLAN_FILE FIX_BASE HEAD` (FIX_BASE ≠ task BASE).
3. No full task-reviewer re-run occurs after a fix round.
4. Codex-gate rounds (when the gate runs) are counted against the same five-round cap as reviewer rounds — the transcript never shows a sixth fix round of either origin.
5. The ledger's first line matches `# SDD ledger — plan: .*` and the run never reads another plan's ledger.
6. If findings survive five rounds (verifier may seed an unfixable finding variant), the controller surfaces BLOCKED to the human — no self-ruling.

- [ ] **Step 3: Run per the harness README and record results**

Run the scenario per `evals/README.md` quorum instructions. Expected: pass at the harness's default quorum threshold. Record the results path under `evals/results/` in the task report. Do not commit anything in `evals/` to the hyperpowers repo (it is a separate clone); commit the scenario inside the evals repo per its own conventions.

### Task 17: Batch 2 eval — plan-scoped workspace

**Risk tier:** standard — new eval scenario.

**Files:**
- Create: `evals/scenarios/sdd-plan-scoped-scratch/`

**Interfaces:**
- Consumes: Tasks 11–14 behavior.
- Produces: the second Batch 2 release-gating eval.

- [ ] **Step 1: Author the scenario**

Same conventions as Task 16. Fixture: a repo where plan A ran to completion earlier (pre-seeded completed ledger in plan A's scratch dir, built by the fixture setup calling `scripts/sdd-dir <planA>`), and the agent is asked to execute plan B. Assert ALL of:
1. Plan B's controller never opens plan A's ledger (no cross-plan forensics tool calls).
2. Plan B's ledger lands under `plans/planB-*`, a slug dir distinct from plan A's.
3. On clean finish, plan B's workspace dir is deleted; plan A's untouched dir remains (GC is not the mechanism).

- [ ] **Step 2: Run and record**

Run per `evals/README.md`; expected pass at default quorum. Record results path.

### Task 18: Batch 2 release checkpoint

**Risk tier:** standard — release mechanics gated on evals.

**Files:**
- Modify: version manifests (via `vrzn`)

**Interfaces:**
- Consumes: Tasks 11–17 complete; both evals passing.
- Produces: released Batch 2; installed plugin refreshed.

- [ ] **Step 1: Gate on tests and evals**

```bash
bash tests/claude-code/test-sdd-dir-path.sh
bash tests/claude-code/test-subagent-driven-development.sh
bash scripts/lint-shell.sh
```
Both Task 16 and Task 17 evals must have recorded passing runs. If either fails, fix and re-run before proceeding — do not release.

- [ ] **Step 2: Release**

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y
git add -A ':!docs/hyperpowers'
git commit -m "Release: upstream sync batch 2 — SDD lifecycle restructure and unified fix loop"
INSTALL_NEW=$(ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1)
rsync -a --delete skills/ "$INSTALL_NEW/skills/"; rsync -a hooks/ "$INSTALL_NEW/hooks/"
```

---

## Batch 3 — Brainstorming Three-Path Router

### Task 19: Rebuild brainstorming SKILL.md with the router

**Risk tier:** standard — behavior-shaping rebuild of tuned content with fork gates re-hung.

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

**Interfaces:**
- Consumes: nothing from Batch 2.
- Produces: the router behavior Batch 3's evals assert against.

- [ ] **Step 1: Produce the fork-delta inventory**

```bash
git diff b62616f HEAD -- skills/brainstorming/SKILL.md > /tmp/claude/brainstorm-delta.diff
```

Fork blocks that MUST re-land (fork HEAD anchors), against the upstream shape (`Three Paths → Anti-Pattern → Red Flags → Checklist → Process Flow → The Process → After the Design (architectural path) → Visual Companion`):

| Fork block | Destination in upstream shape |
|---|---|
| Checklist step 4 Codex approach gate + "Exploring approaches" gate text | Architectural-path checklist + The Process, with the any-path trigger text (Step 3 below) |
| Checklist step 8 Codex spec gate + "Codex Spec Review Gate" section | After the Design (architectural path) — spec gate runs only where a spec file exists |
| Two codex digraph nodes | Process Flow digraph (union with the router nodes) |
| Spec-not-committed policy lines | After the Design |
| Visual companion "just use it" semantics (fork Checklist step 2 + section wording) | Checklist + Visual Companion section — keep fork wording, discard upstream "offer" wording |

- [ ] **Step 2: Rebuild from the pin and graft**

```bash
git show b36e082:skills/brainstorming/SKILL.md \
  | sed -e 's/superpowers:/hyperpowers:/g' -e 's/using-superpowers/using-hyperpowers/g' -e 's|docs/superpowers|docs/hyperpowers|g' \
  > skills/brainstorming/SKILL.md
```
Then graft each inventory row. Renumber the architectural-path checklist so the two gate steps slot in at their fork positions (approach gate before "Propose 2-3 approaches"; spec gate after spec self-review).

- [ ] **Step 3: Write the any-path gate trigger text**

Where the approach gate is introduced, use exactly this rule (spec-approved wording):

```markdown
**Codex approach gate (conditional, Claude Code only):** the gate's trigger is
path-independent — real architectural, algorithmic, or data-model
alternatives, or your human partner asking for Codex input, fire it on any
path. On the bounded path its approaches fold into the short in-chat design;
ceremony does not escalate. On the spike path it does not normally fire
(feasibility probes rarely present committed design alternatives), but an
explicit request or genuinely material alternatives still fire it.
Trivial/mechanical tasks skip it silently.
```

- [ ] **Step 4: Verify and commit**

```bash
grep -n "Spike\|Bounded\|Architectural" skills/brainstorming/SKILL.md | head -8
grep -n "one-way\|ratchet" skills/brainstorming/SKILL.md
grep -n "codex-approach-gate.md\|codex-review-gate.md" skills/brainstorming/SKILL.md
grep -n "Do NOT commit the design document" skills/brainstorming/SKILL.md
grep -ni "offer" skills/brainstorming/SKILL.md | grep -i companion || echo "companion offer-wording absent"
grep -n "superpowers:" skills/brainstorming/SKILL.md || echo "namespace clean"
bash tests/claude-code/run-skill-tests.sh 2>/dev/null | head -5 || true
git add skills/brainstorming/SKILL.md
git commit -m "feat(brainstorming): three-path router with fork Codex gates re-hung"
```
Expected: router sections present; ratchet present; both gate references intact; spec-not-committed intact; no offer-first companion wording.

### Task 20: visual-companion.md Copilot fix (fork-aware hand merge)

**Risk tier:** low — single-file, one-hunk replacement whose source and destination anchors are given below.

**Files:**
- Modify: `skills/brainstorming/visual-companion.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

The fork file is NOT identical to upstream's pre-change version — it carries
fork deltas (`.hyperpowers/brainstorm` storage paths, fork companion
semantics). Do NOT take the upstream file wholesale.

- [ ] **Step 1: Extract the upstream fix hunk**

```bash
git diff b62616f b36e082 -- skills/brainstorming/visual-companion.md
```
Expected: a small diff whose substantive hunk replaces the Copilot CLI
backgrounding paragraph (the fork's copy of the old text sits at lines
~77-83).

- [ ] **Step 2: Apply only that hunk**

In `skills/brainstorming/visual-companion.md`, replace the fork's Copilot
backgrounding paragraph with the corrected paragraph from the diff (PORT-NORMALIZEd
if it names any `superpowers:`/`using-superpowers` identifiers). Touch
nothing else.

- [ ] **Step 3: Verify fork content survived, commit**

```bash
grep -n ".hyperpowers/brainstorm" skills/brainstorming/visual-companion.md | head -3
git diff --stat -- skills/brainstorming/visual-companion.md
git add skills/brainstorming/visual-companion.md
git commit -m "fix(brainstorming): correct Copilot CLI backgrounding guidance in visual companion"
```
Expected: fork storage paths still present; the diff stat shows only the one
paragraph changed.

### Task 21: Batch 3 eval battery

**Risk tier:** standard — three scenarios encoding the router contract with fork gates present.

**Files:**
- Create: `evals/scenarios/brainstorming-router-escalates-ambiguous/`
- Create: `evals/scenarios/brainstorming-router-no-downgrade/`
- Create: `evals/scenarios/brainstorming-bounded-fires-approach-gate/`

**Interfaces:**
- Consumes: Task 19 behavior.
- Produces: the Batch 3 release-gating evals.

- [ ] **Step 1: Author the three scenarios** (conventions per Task 16 Step 1)

1. `brainstorming-router-escalates-ambiguous`: adversarially ambiguous briefs (adapt upstream's battery cases named in its T4 design doc, `git show b36e082:docs/superpowers/specs/2026-07-30-codex-efficiency-fixes-design.md`); assert escalation to the architectural path in ≥4/5 reps.
2. `brainstorming-router-no-downgrade`: clearly architectural briefs; assert 5/5 never classified spike/bounded, and classification is announced.
3. `brainstorming-bounded-fires-approach-gate`: a bounded brief with two genuine algorithmic alternatives; assert the approach gate fires AND no spec file is produced (ceremony did not escalate).

- [ ] **Step 2: Run and record**

Run per `evals/README.md`; expected: thresholds met exactly as stated per scenario. Record results paths.

### Task 22: Batch 3 release checkpoint

**Risk tier:** standard — release mechanics gated on evals.

**Files:**
- Modify: version manifests (via `vrzn`)

**Interfaces:**
- Consumes: Tasks 19–21 complete; all three evals passing.
- Produces: released Batch 3; sync complete.

- [ ] **Step 1: Gate, release, refresh**

```bash
bash scripts/lint-shell.sh
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y
git add -A ':!docs/hyperpowers'
git commit -m "Release: upstream sync batch 3 — brainstorming three-path router"
INSTALL_NEW=$(ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1)
rsync -a --delete skills/ "$INSTALL_NEW/skills/"; rsync -a hooks/ "$INSTALL_NEW/hooks/"
```
All three Task 21 evals must have recorded passing runs before the bump; if any fails, fix and re-run first.
