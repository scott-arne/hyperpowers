# Consolidation and 6.19.0 Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. A correction added during execution that alters one of the spec's decisions names it: `Correction (<date>), decision <N> (<title>):`.

**Spec:** none. This plan collects follow-ups that earlier specs, receipts and reviews already recorded. Each task names where its item came from. The 2026-11-15 assessment that produced it is summarized under "Where this plan comes from" below.

**Goal:** Bring local `main` to a releasable 6.19.0. Land the side branch, fix the stale text and two hook bugs found on 2026-11-15, remove the cost figures from the unpushed evals range, and record the rest of the outstanding work in one register.

**Architecture:** Each task is small and independent where it can be: a merge, reference and wording fixes, docs-site sources, two hook fixes with offline tests, a packager fix, an evals history rewrite, housekeeping, and a release task. Pushing, tagging, the plugin-install checkout and host cleanup stay with the controller and the human partner after Finish (see "After Finish").

**Tech Stack:** Bash hooks and scripts, Node ESM (`hooks/lib/*.mjs`, `node --test`), Markdown skills and MyST docs (`docs/site/`), `git filter-repo` for the evals rewrite, `vrzn` for the version bump.

## Where this plan comes from

The assessment ran on 2026-11-15 over local `main` 78041ed5 (27 commits ahead of `origin/main`, unreleased), evals `main` dab6fb1643 (20 ahead), and branch `codex-gate-sandbox-shape` (b69d58be, one commit on `origin/main`). No SDD run is in flight: the state branch's last entry is the compaction-reread-notice finish. An independent review found no release blocker in the SDD split. SKILL.md is 14,167 code points, `tests/sdd/test-sdd-layout.sh` enforces the limits, and the side branch merges with conflicts only on two `source-digest:` lines. The findings this plan fixes are listed in each task. Items that need a design or a measurement first are in the register at the end, with a recommended next step for each.

## Global Constraints

- No dollar figures anywhere in either repository, its history, or its docs; percentages are fine (decision of 2026-11-05).
- No AI-attribution lines in commits, files or tags: no `Co-Authored-By`, no "generated with".
- Before each commit, scan the staged diff: `git diff --cached | python3 ~/.claude/scripts/realval-scan.py`, and expect `hits: 0`.
- Skill-text edits in this plan are evaluated by contract needles plus a reachability note, as decided for the 2026-11-08 sweep (`docs/hyperpowers/decisions/2026-11-08-the-skill-text-edits-are-evaluated-by-contract-needles-and-a.md`). No live eval runs are planned, so no evidence directory is named.
- The offline set is `bash tests/run-offline.sh`. The brainstorm-server npm suite fails six file-watching checks inside the Bash sandbox and passes outside it; that is not a regression.
- Codex companion commands run with the sandbox off, as the whole Bash command (no `cd ... &&`, no assignment prefix).
- Version: 6.19.0 (minor), set with `vrzn bump minor -y`, never by hand.
- After a merge, take docs digests only once the merge commit exists (`docs-check --digest` reads sources through the index, so a digest taken during a conflict is wrong).
- **Merge-expected files:** `CHANGELOG.md`, `docs/testing.md`

## Grounding

- Commit subjects: lower-case `type(scope): sentence` stating the behavior, e.g. `git log --oneline -5` on main (`fix(sdd): a recorded report line resumes at Handle the report, not a new dispatch`).
- Contract needles: `tests/sdd/test-sdd-contract.sh:224-228`, `assert_contains "$SDD_TASK_LOOP" "<verbatim sentence>" "<label>"`.
- Template dispatch-comment needle: `tests/sdd/test-sdd-contract.sh:610-613`, a loop over the five templates.
- Session-start hook payload parsing: `hooks/session-start:76-79` (node one-liner, fail-silent).
- A9 notice ledger choice: `hooks/session-start:216-229` (newest by `-nt` across three roots).
- A9 notice tests: `tests/hooks/test-session-start.sh:451-452` (notice head and tail), `:466-480` (`seed_ledger`, `write_hook_input` with `session_id` `t`), `:531-546` (one case).
- Session-line match in shell: `skills/subagent-driven-development/scripts/sdd-state:3330` (`SID=$sid awk 'BEGIN { p = "session " ENVIRON["SID"] ... } index($0, p) == 1'`).
- Session-line match in Node: `hooks/lib/stop-guard.mjs:91-93` (`l.startsWith(\`session ${sessionId}:\`)`).
- Fence rule the stop guard must mirror: `skills/subagent-driven-development/scripts/sdd-common.sh:301-302` (opens on a run of backticks or tildes, closes on a run of the same character at least as long).
- Stop-guard unit tests: `hooks/lib/stop-guard.test.mjs:87-92` (`planState` with `env()`, `workspaceFor`, `ledger`; the fixture plan has three tasks).
- Packager staging loop: `scripts/package-claude-skill.sh:45-55`. Packaging test shape: `tests/packaging/test-package-skill.sh:40-66` (`pass`/`fail` over the built zip).
- Docs front matter: `docs/site/advanced/decision-records.md:1-4` (`sources:` space-separated paths, directories allowed; `source-digest:` recomputed with `bash tests/docs/docs-check.sh --digest <page>`).
- History-rewrite map format: `docs/hyperpowers/history-rewrite-2026-11-11.tsv:1-5` (comment header, then `old<TAB>new` lines).
- Error handling in hooks: fail-silent subshell, `( set +e ... ) 2>/dev/null` at `hooks/session-start:197-235`.

---

### Task 1: Merge `codex-gate-sandbox-shape` into the plan branch

**Risk tier:** high: the merge brings in a change to `skills/requesting-code-review/scripts/gate-wait`, whose exit status and terminal output the Codex review loop trusts to decide whether a review finished (`recipe-code.md:18-22`), plus two conflicts to resolve across a range that moved since the branch was cut.

**Depends on:** none

**Files:**
- Modify (by merge): the 13 files in `git diff --stat origin/main codex-gate-sandbox-shape`, including `docs/site/advanced/codex-gates.md` and `docs/site/skills/requesting-code-review.md`
- Test: `tests/codex-review-gate/test-gate-contract.sh`, `test-gate-split-lossless.sh`, `test-gate-wait.sh`, `tests/docs/docs-check.sh`

**Interfaces:**
- Produces: `skills/requesting-code-review/scripts/gate-wait --codex-path <path>` on the plan branch, and the sandbox rule at the top of `gate-preflight.md` section 1.

- [ ] **Step 1: Merge**

```bash
git merge --no-ff codex-gate-sandbox-shape -m "Merge branch 'codex-gate-sandbox-shape'"
```

Expected: conflicts only in the `source-digest:` line of `docs/site/advanced/codex-gates.md` and `docs/site/skills/requesting-code-review.md`.

- [ ] **Step 2: Resolve each conflict by keeping either digest line, then commit the merge**

```bash
git add docs/site/advanced/codex-gates.md docs/site/skills/requesting-code-review.md
git commit --no-edit
```

- [ ] **Step 3: Re-read both pages against their sources, then re-take the digests after the merge commit**

```bash
bash tests/docs/docs-check.sh --digest docs/site/advanced/codex-gates.md
bash tests/docs/docs-check.sh --digest docs/site/skills/requesting-code-review.md
```

Put each printed value on the page's `source-digest:` line. Read each page's text against the merged skill text first. The branch added a sandbox rule to `gate-preflight.md` section 1, and the page should say so if it describes preflight.

- [ ] **Step 4: Run the gate and docs tests (one per call)**

```bash
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-wait.sh
bash tests/docs/docs-check.sh
```

Expected: all pass; `docs-check` prints OK.

- [ ] **Step 5: Commit**

```bash
git add docs/site/advanced/codex-gates.md docs/site/skills/requesting-code-review.md
git commit -m "docs(site): the merged Codex gate pages carry fresh digests"
```

### Task 2: Repoint stale references left by the SDD split

**Risk tier:** standard: reference, comment and docs-table fixes whose replacement text is in this task, with no instruction changes; it spans several files, and two of them (`sdd-state`, `sdd-dir`) are scripts other machinery trusts, so it is not low even though only their comments change.

**Depends on:** none

**Files:**
- Modify: `skills/subagent-driven-development/implementer-prompt.md:10`, `task-reviewer-prompt.md:15`, `re-review-prompt.md:16`, `fix-subagent-prompt.md:15`, `skills/requesting-code-review/code-reviewer.md:10`
- Modify: `skills/subagent-driven-development/final-and-finish.md:26`, `skills/subagent-driven-development/fix-loop.md:51`
- Modify: `hooks/lib/dispatch-guard.mjs:4-6`, `skills/subagent-driven-development/scripts/sdd-state:169-170`, `skills/subagent-driven-development/scripts/sdd-dir:3-4`, `tests/sdd/test-sdd-state.sh:618`, `tests/sdd/test-sdd-state.sh:2960`
- Modify: `docs/testing.md:25`
- Test: `tests/sdd/test-sdd-contract.sh:610-613`

Source: 2026-11-15 consistency review, findings 5, 8, 10, 11; compaction receipt items at `:194` and `:227`.

- [ ] **Step 1: Change the contract needle first, so it fails**

In `tests/sdd/test-sdd-contract.sh`, replace the string inside the loop at lines 610-613:

```bash
  assert_contains "$template" 'run_in_background: false # Claude Code: dispatch in the foreground (task-loop.md "Waiting on subagents and long commands"); omit on harnesses without the flag' \
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash tests/sdd/test-sdd-contract.sh`
Expected: FAIL on the five "dispatch block carries the foreground flag" checks.

- [ ] **Step 3: Repoint the five template comments**

In each of the five templates, replace `(SKILL.md "Waiting on subagents")` with `(task-loop.md "Waiting on subagents and long commands")`. In `skills/requesting-code-review/code-reviewer.md` the comment names another skill's file, so write `(subagent-driven-development task-loop.md "Waiting on subagents and long commands")`, and adjust the needle loop so `$CODEREVW` is checked for that longer form in a separate `assert_contains`.

- [ ] **Step 4: Link Model Selection where the step files name it**

`final-and-finish.md:26`: replace `(see Model Selection)` with `(see [Model Selection](SKILL.md#model-selection))`.
`fix-loop.md:51`: replace `(per Model Selection in SKILL.md)` with `(per [Model Selection](SKILL.md#model-selection))`.

- [ ] **Step 5: Correct the comments that place moved text in SKILL.md**

- `hooks/lib/dispatch-guard.mjs:4-6`: replace "The skill forbids both outside fork mode, in the part of SKILL.md Claude Code re-attaches whole after a compaction;" with "The skill forbids both outside fork mode: SKILL.md, which Claude Code re-attaches whole after a compaction, forbids the background dispatch, and fix-loop.md the SendMessage resume;".
- `sdd-state:169-170`: replace "SKILL.md has a controller whose plan lives in another repository pass --code-repo" with "setup.md has a controller whose plan lives in another repository pass --code-repo".
- `sdd-dir:3-4`: replace "and the SKILL.md ledger guidance." with "and the ledger guidance in SKILL.md and its step files.".
- `tests/sdd/test-sdd-state.sh:618` and `:2960`: where a comment says SKILL.md carries the `--code-repo` text, name `setup.md` instead. Change comments only.

- [ ] **Step 6: Add `test-sdd-layout.sh` to the command column of `docs/testing.md:25`**, matching how the row lists its other scripts.

- [ ] **Step 7: Run the tests (one per call)**

```bash
bash tests/sdd/test-sdd-contract.sh
bash tests/sdd/test-sdd-layout.sh
node --test hooks/lib/dispatch-guard.test.mjs
```

Expected: all pass. `test-sdd-layout.sh` checks that links resolve, so it also covers the two new `SKILL.md#model-selection` links.

- [ ] **Step 8: Commit**

```bash
git add -A skills/subagent-driven-development skills/requesting-code-review/code-reviewer.md hooks/lib/dispatch-guard.mjs tests/sdd docs/testing.md
git commit -m "fix(sdd): references to moved step text name the step file"
```

### Task 3: Align two resume instructions with the dispatch guard, and disclose the unmeasured resume rules

**Risk tier:** standard: behavior-shaping skill text, plus release-note accuracy.

**Depends on:** Task 2

**Files:**
- Modify: `skills/subagent-driven-development/task-loop.md:81-82`
- Modify: `skills/requesting-code-review/gate-fix-loop.md:94`
- Modify: `CHANGELOG.md:8-9`
- Modify: `docs/hyperpowers/2026-11-11-compaction-reread-notice-eval-evidence.md` ("Not measured" list)
- Test: `tests/sdd/test-sdd-contract.sh:225`, plus a new needle for `gate-fix-loop.md` in `tests/codex-review-gate/test-gate-contract.sh`

Source: 2026-11-15 consistency review, findings 2 and 9, and the pre-existing `gate-fix-loop.md:94` note. On Claude Code outside fork mode, the dispatch guard refuses a SendMessage to the session's own subagent, and `fix-loop.md:40-43` keeps resumes for harnesses without `run_in_background`. Two places still tell the controller to resume. A controller that follows them gets refused and loses a round trip.

- [ ] **Step 1: Change the task-loop needle and add the gate-fix-loop needle**

`tests/sdd/test-sdd-contract.sh:225`, the new expected sentence:

```bash
assert_contains "$SDD_TASK_LOOP" "is a dispatch in flight: do not re-dispatch — reconcile that agent first (list your live children, chase its report); on a harness without \`run_in_background\` (Claude Code's fork mode among them) resume it by the recorded id; only if it cannot be recovered dispatch a takeover, recording the takeover's identity beside the original." \
```

In `tests/codex-review-gate/test-gate-contract.sh`, beside the other `gate-fix-loop.md` needles:

```bash
assert_contains "$GATE" "for SDD's per-task gate that path is SDD's fix loop (fix-loop.md), not a separate fix subagent" \
  "the gate fix path defers to SDD's fix loop for how the implementer is reached"
```

`$GATE` is the union of the gate index and its section files, `gate-fix-loop.md` among them, assembled at `test-gate-contract.sh:7-10`; the suite has no per-file variable for `gate-fix-loop.md`.

- [ ] **Step 2: Run both suites and see the two new checks fail**

```bash
bash tests/sdd/test-sdd-contract.sh
bash tests/codex-review-gate/test-gate-contract.sh
```

- [ ] **Step 3: Edit the skill text**

`task-loop.md:81-82`: replace "(list your live children, chase its report), resume it by the recorded id where your harness allows, and only if it cannot be recovered dispatch a takeover," with "(list your live children, chase its report); on a harness without `run_in_background` (Claude Code's fork mode among them) resume it by the recorded id; only if it cannot be recovered dispatch a takeover,". Keep the line wrapping of the surrounding paragraph.

`gate-fix-loop.md:94`: replace "(for SDD's per-task gate that path resumes the implementer per SDD's fix loop, not a fix subagent)" with "(for SDD's per-task gate that path is SDD's fix loop (fix-loop.md), not a separate fix subagent)".

- [ ] **Step 4: Rewrite the CHANGELOG measurement bullet and add the resume-rules bullet**

Replace `CHANGELOG.md:9` (the "Measured on `sdd-compaction-reread`" bullet) with:

```markdown
- Measured on `sdd-compaction-reread` at a 100,000-token window, the controller finished 10 of 10 valid runs. Released 6.18.1 finished 0 of 10, and an unreleased variant with a session-start re-read notice finished 5 of 10. None of the controller's runs ended in Claude Code's "Autocompact is thrashing" stop. It followed 30 of 126 compactions (24%) with the board, its task's ledger lines and the named step file, against a bar of 85%: bars 1, 2 and 4 passed and bar 3 failed (evidence: hyperpowers-evals `evidence/2026-11-11-compaction-reread-notice/` and `docs/hyperpowers/2026-11-11-compaction-reread-notice-eval-evidence.md`).
- **Resume rules after a compaction (not measured).** Added after the campaign: the step table's first row sends a session that already ran `sdd-state finish` to the hand-off; `task-loop.md` reconciles an implementer dispatch still in flight and resumes a recorded `report` line at "2. Handle the report" with BASE as step 1 sets it; `fix-loop.md` resumes a fix round mid-loop; `final-and-finish.md` resumes the hand-off. A resume by agent id is for harnesses without `run_in_background`, which matches what the dispatch guard allows. The campaign above ran before these rules.
```

- [ ] **Step 5: Add the "Not measured" line in the evidence note**

Append to the `## Not measured` list:

```markdown
- The resume rules added after the campaign (commits eb5e7faa, 68f931eb, df16cf74, cc397588, and the 2026-11-15 wording that keeps resumes by id to harnesses without `run_in_background`). No campaign run reached them.
```

- [ ] **Step 6: Write the reachability note into the commit message body** (which sessions reach each edited sentence: a controller resuming after a compaction mid-dispatch on Claude Code; a per-task Codex gate fix round), then run both suites and see them pass.

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/task-loop.md skills/requesting-code-review/gate-fix-loop.md tests/sdd/test-sdd-contract.sh tests/codex-review-gate/test-gate-contract.sh CHANGELOG.md docs/hyperpowers/2026-11-11-compaction-reread-notice-eval-evidence.md
git commit
```

Subject: `fix(sdd): a resume by agent id is for harnesses without run_in_background`.

### Task 4: Docs that describe moved SDD text list the step files, and README matches the shipped compaction behavior

**Risk tier:** standard: docs across 15 files with prose rewrites.

**Depends on:** Task 1, Task 2, Task 3

**Files:**
- Modify front matter: `docs/site/recommended-settings.md`, `docs/site/advanced/triggering.md`, `docs/site/advanced/codex-gates.md`, `docs/site/advanced/decision-records.md`, `docs/site/skills/using-hyperpowers.md`, `communication.md`, `executing-plans.md`, `writing-plans.md`, `finishing-a-development-branch.md`, `test-driven-development.md`, `requesting-code-review.md`, `receiving-code-review.md`, `using-git-worktrees.md` (all under `docs/site/skills/` unless a path is given)
- Modify prose: `README.md:192`, `README.md:198`, `docs/site/recommended-settings.md:28`, `docs/site/recommended-settings.md:40`
- Test: `bash tests/docs/docs-check.sh`, `bash tests/docs/test-docs-skills.sh`

Source: consistency review findings 1, 3, 4; RTD residual D4 (Tip 3).

- [ ] **Step 1: In each of the 13 pages, add the five step files after `skills/subagent-driven-development/SKILL.md` in `sources:`**

```
skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/setup.md skills/subagent-driven-development/task-loop.md skills/subagent-driven-development/review-and-complete.md skills/subagent-driven-development/fix-loop.md skills/subagent-driven-development/final-and-finish.md
```

This names the files that hold the moved text (dry-run in `setup.md`, per-task gate in `review-and-complete.md` and `fix-loop.md`, hand-off and final reviewer in `final-and-finish.md`). Listing the directory would also pull in `scripts/`, which changes often.

- [ ] **Step 2: Run `docs-check` and confirm every edited page now reads as stale**

Run: `bash tests/docs/docs-check.sh`. Expected: the 13 pages are listed stale.

- [ ] **Step 3: README**

`README.md:192`: replace "The skills re-read their full text after each compaction (about 10K tokens for subagent-driven-development)" with "After each compaction, brainstorming re-reads its full text and subagent-driven-development reads one step file of up to about 17,000 characters".

`README.md:198`: replace the sentence that says SDD and brainstorming "tell the agent to Read their full text after every compaction" with: "The brainstorming skill tells the agent to Read its full text after every compaction. subagent-driven-development keeps its `SKILL.md` under 19,000 characters, so it comes back whole, and the agent reads the one step file it needs."

- [ ] **Step 4: `docs/site/recommended-settings.md`**

Line 28: remove the 98% re-read figure attached to subagent-driven-development (it measured the old full-Read paragraph). State the controller's measured rate instead: "In the 100,000-token campaign the controller followed 30 of 126 compactions (24%) with the step-file read, and still finished 10 of 10 runs, because `SKILL.md` itself comes back whole." Keep the brainstorming figure if the page gives one.

Line 40 (Tip 3): add one sentence saying that when Codex is installed, writing-plans runs the optional Codex plan review before the hand-off to subagent-driven-development.

- [ ] **Step 5: Re-read each stale page against its sources, fix any sentence the merged and edited text has made wrong, then re-take every digest**

```bash
bash tests/docs/docs-check.sh --digest <page>
```

Run it once per page (one call each) and write the value to `source-digest:`.

- [ ] **Step 6: Run the docs tests**

```bash
bash tests/docs/docs-check.sh
bash tests/docs/test-docs-skills.sh
```

Expected: OK, PASS.

- [ ] **Step 7: Commit**

```bash
git add README.md docs/site
git commit -m "docs: pages that describe SDD steps list the step files, and README describes the compact controller"
```

### Task 5: The A9 compaction notice names this session's own ledger

**Risk tier:** standard: hook behavior on every compaction, covered by offline tests.

**Depends on:** none

**Files:**
- Modify: `hooks/session-start:186-235` (the A9 block)
- Test: `tests/hooks/test-session-start.sh` (new case after `:546`)

Source: dispatch-guard and compaction specs. The notice picks the newest ledger across every plan of the repo, and on 2026-11-10 it pointed session ec562ba3 at another plan's ledger. The 2026-11-14 notice removal (96edc68e) left this block as it was. Ledgers carry `session <id>: ...` lines (`hooks/lib/stop-guard.mjs:91-93`). Session ids exclude whitespace and colons (decision 2026-11-08).

Behavior: among the candidate ledgers, the newest one carrying a `session <this id>:` line wins. If none carries it, the newest ledger wins, as today. The notice text does not change.

- [ ] **Step 1: Write the failing test** after the case ending at `tests/hooks/test-session-start.sh:546`:

```bash
# Two plans in one repo: the notice names the ledger this session wrote, even
# when another session's ledger is newer. "session tt:" must not match "t".
own_repo="$(make_repo compact-own)"
own_home="$(make_home compact-own)"
own_cache="$TEST_ROOT/compact-own/cache"
own_ledger="$(seed_ledger "$own_cache" "$own_repo" "mine-1111aaaa")"
printf 'session t: mode worktree on main at %s started 2026-11-15T00:00:00Z\n' "$own_repo" >> "$own_ledger"
other_ledger="$(seed_ledger "$own_cache" "$own_repo" "other-2222bbbb")"
printf 'session tt: mode worktree on main at %s started 2026-11-15T00:00:00Z\n' "$own_repo" >> "$other_ledger"
touch -t 202401010000 "$own_ledger"
touch -t 202403010000 "$other_ledger"
own_stdin="$TEST_ROOT/compact-own/stdin.json"
write_hook_input "$own_stdin" compact
HOOK_STDIN="$own_stdin"
assert_command_output \
    "SessionStart names this session's ledger over a newer ledger of another session" \
    "nested" \
    "${NOTICE_HEAD}${own_ledger}${NOTICE_TAIL}" \
    "" \
    "$own_home" \
    XDG_CACHE_HOME="$own_cache" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$own_repo" "$HOOK_UNDER_TEST"
```

- [ ] **Step 2: Run it and see it fail**

Run: `bash tests/hooks/test-session-start.sh`
Expected: the new case fails with the notice naming `other-2222bbbb`. Every existing case passes.

- [ ] **Step 3: Implement**

Inside `if [ "$hook_source" = "compact" ]; then`, before `compaction_notice="$(`, read the session id (only compactions pay for this fork):

```bash
  # The session's own ledger wins over a newer one from another plan. Ids
  # with whitespace or a colon are not session ids, and would also break the
  # "session <id>:" prefix match.
  hook_session=""
  if [ -n "$hook_input" ] && command -v node >/dev/null 2>&1; then
    hook_session="$(printf '%s' "$hook_input" | node -e 'try { const s = JSON.parse(require("fs").readFileSync(0, "utf8")).session_id; process.stdout.write(typeof s === "string" && /^[A-Za-z0-9._-]+$/.test(s) ? s : ""); } catch (e) { /* no session id */ }' 2>/dev/null)" || hook_session=""
  fi
```

In the ledger loop, track the newest ledger carrying the session beside `newest`, and prefer it after the loop:

```bash
      newest=""
      own=""
      for plans in "$cache/state/$key/plans" "$cache/sdd/$key/plans" "$cache/sdd/$legacy/plans"; do
        [ -d "$plans" ] || continue
        for ledger in "$plans"/*/progress.md; do
          [ -f "$ledger" ] || continue
          if [ -z "$newest" ] || [ "$ledger" -nt "$newest" ]; then
            newest="$ledger"
          fi
          if [ -n "$hook_session" ] && SID=$hook_session awk 'BEGIN { p = "session " ENVIRON["SID"] ":" } index($0, p) == 1 { f = 1; exit } END { exit !f }' "$ledger" 2>/dev/null; then
            if [ -z "$own" ] || [ "$ledger" -nt "$own" ]; then
              own="$ledger"
            fi
          fi
        done
      done
      [ -n "$own" ] && newest="$own"
      [ -n "$newest" ] || exit 0
```

Update the comment above the loop ("Newest wins across all three.") to say that this session's newest ledger wins, then the newest overall.

- [ ] **Step 4: Run the suites (one per call)**

```bash
bash tests/hooks/test-session-start.sh
bash tests/hooks/test-no-heredocs-in-hooks.sh
bash tests/shell-lint/test-shell-lint.sh
```

Expected: all pass. If the shell-lint suite has another filename, run every `tests/shell-lint/test-*.sh`.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start tests/hooks/test-session-start.sh
git commit -m "fix(hooks): the compaction notice names the session's own ledger before a newer one"
```

### Task 6: The stop guard skips task headings inside fenced blocks

**Risk tier:** high: the stop guard's allow/block output is trusted to end or hold a turn, and it appends each decision to a durable JSONL record (`hooks/lib/stop-guard.mjs:371-384,685-703`); the change alters what that decision counts.

**Depends on:** none

**Files:**
- Modify: `hooks/lib/stop-guard.mjs:22` (`TASK_HEADING`) and `:187` (its use in `planState`)
- Test: `hooks/lib/stop-guard.test.mjs` (new case after `:92`)

Source: sweep receipt `:159`. `hp_plan_graph` skips fenced blocks (`sdd-common.sh:301-302`) and the stop guard does not. A plan that shows an example `### Task N:` heading in a code block therefore has a task the guard counts as open forever, and the guard refuses turn ends up to its cap on a finished plan.

- [ ] **Step 1: Write the failing test** after the `planState` case ending at `hooks/lib/stop-guard.test.mjs:92`:

```js
test('planState: a task heading inside a fenced block is an example, not a task', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1, 2, 3] });
  const plan = join(e.repo, 'docs', 'plan.md');
  writeFileSync(plan, readFileSync(plan, 'utf8')
    + '\n````markdown\n### Task 9: an example heading\n```\n### Task 10: a shorter run does not close the fence\n````\n'
    + '~~~\n### Task 11: a tilde fence\n~~~\n');
  assert.deepEqual(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }), { plan: 'docs/plan.md', open: 0, total: 3 });
});
```

- [ ] **Step 2: Run it and see it fail**

Run: `node --test hooks/lib/stop-guard.test.mjs`
Expected: FAIL, `total: 6, open: 3` against `total: 3, open: 0`.

- [ ] **Step 3: Implement**

Replace `const TASK_HEADING = /^### Task (\d+):/gm;` with:

```js
// Task ids from "### Task N:" headings outside fenced blocks, read as
// hp_plan_graph reads them (sdd-common.sh): a fence opens on a run of three or
// more backticks or tildes and closes on a run of the same character at least
// as long. A heading shown as an example in a fence is not a task.
export function planTaskIds(planText) {
  const ids = [];
  let fence = '';
  for (const text of planText.split('\n')) {
    const run = text.match(/^(`{3,}|~{3,})/);
    if (run) {
      if (fence === '') fence = run[1];
      else if (run[1][0] === fence[0] && run[1].length >= fence.length) fence = '';
      continue;
    }
    if (fence !== '') continue;
    const m = text.match(/^### Task (\d+):/);
    if (m) ids.push(m[1]);
  }
  return [...new Set(ids)];
}
```

and at `:187` replace `const tasks = [...new Set([...planText.matchAll(TASK_HEADING)].map((x) => x[1]))];` with `const tasks = planTaskIds(planText);`. Keep the comment above it about ids staying strings.

- [ ] **Step 4: Run the suites (one per call)**

```bash
node --test hooks/lib/stop-guard.test.mjs
bash tests/hooks/test-sdd-stop-guard.sh
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/stop-guard.mjs hooks/lib/stop-guard.test.mjs
git commit -m "fix(hooks): the stop guard counts task headings as hp_plan_graph does, outside fences"
```

### Task 7: The claude.ai bundle rewrites links to a renamed SKILL.md

**Risk tier:** standard: changes the packager's staging step.

**Depends on:** none

**Files:**
- Modify: `scripts/package-claude-skill.sh:45-55`
- Test: `tests/packaging/test-package-skill.sh` (new check after `:66`)

Source: consistency review finding 6. The packager renames each `skills/<name>/SKILL.md` to `INSTRUCTIONS.md`, and the five SDD step files are the first files in the repo to link `[SKILL.md](SKILL.md)`. In the bundle those links point at nothing.

- [ ] **Step 1: Write the failing check** after `tests/packaging/test-package-skill.sh:66`, using the extracted tree the script already builds at `:72` (move the check below the extraction if needed):

```bash
# A link to a skill's SKILL.md must follow the rename to INSTRUCTIONS.md.
if grep -rEl '\]\([^)]*SKILL\.md[)#]' "$EXTRACT_DIR/hyperpowers/skills" > "$TEST_ROOT/skill-links.txt" 2>/dev/null; then
  fail "bundled files still link SKILL.md: $(tr '\n' ' ' < "$TEST_ROOT/skill-links.txt")"
else
  pass "no bundled file links a renamed SKILL.md"
fi
```

Use the suite's own scratch-directory variable if it is not `TEST_ROOT`; check the top of the script.

- [ ] **Step 2: Run it and see it fail**

Run: `bash tests/packaging/test-package-skill.sh`
Expected: FAIL naming the five step files.

- [ ] **Step 3: Implement** in the staging loop's `else` branch:

```bash
  elif [[ "$f" == *.md ]]; then
    # The bundle renames each SKILL.md, so a link to one is renamed with it.
    sed -E 's#(\]\([^)]*)SKILL\.md([)#])#\1INSTRUCTIONS.md\2#g' "$REPO_ROOT/$f" > "$STAGE/$f"
  else
    cp "$REPO_ROOT/$f" "$STAGE/$f"
  fi
```

- [ ] **Step 4: Run the packaging suites (one per call)**

```bash
bash tests/packaging/test-package-skill.sh
bash tests/packaging/test-no-orphan-skill-files.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/package-claude-skill.sh tests/packaging/test-package-skill.sh
git commit -m "fix(packaging): links to a skill's SKILL.md follow its rename in the bundle"
```

### Task 8: Remove the cost figures from the unpushed evals range

**Risk tier:** high: rewrites git history in hyperpowers-evals.

**Depends on:** Task 3

**Files:**
- Rewrite: hyperpowers-evals commits `b59b12e16c^..main` (13 commits, linear, none pushed)
- Create: `evals/evidence/history-rewrite-2026-11-15.tsv`
- Modify: evals `evidence/2026-11-11-compaction-reread-notice/README.md`, evals `docs/experiments/2026-11-11-compaction-reread-notice.md` (old ids to new)
- Modify: hp `docs/hyperpowers/2026-11-11-compaction-reread-notice-eval-evidence.md` (old ids to new)

Source: compaction memory and receipt `:324`; audit of 2026-11-15. b59b12e16c adds 74 lines with cost figures (72 numeric cost-key values and 2 quorum `$` column rows). 54bf447b9b sets them to null, and the HEAD tree has none. The rest of the range has only shell positionals such as `$1`. The hp range has no cost figures. The hp spec `2026-11-11-compaction-reread-notice-design.md` cites b59b12e16c, but it is frozen, so the map covers that citation.

Because nothing in the range is pushed, this rewrite needs no force-push.

- [ ] **Step 1: Back up evals and record the old ids before anything else**

```bash
mkdir -p /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15
git -C /Users/johnss51/Development/agents/hyperpowers/evals bundle create /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-pre.bundle --all
git -C /Users/johnss51/Development/agents/hyperpowers/evals bundle verify /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-pre.bundle
git -C /Users/johnss51/Development/agents/hyperpowers/evals rev-parse main > /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-main-pre.txt
git -C /Users/johnss51/Development/agents/hyperpowers/evals rev-list b59b12e16c^..main > /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/old-range-commits.txt
git -C /Users/johnss51/Development/agents/hyperpowers/evals for-each-ref --contains b59b12e16c --format='%(refname)'
```

Expected: `bundle verify` prints `... is okay` (if it does not, stop before anything else runs), `old-range-commits.txt` has 13 lines, and the last command prints only `refs/heads/main` (checked 2026-11-15; no other branch, tag or stash holds the range). Any other ref in that output: stop and hand back.

- [ ] **Step 2: Build the allowlist and the callback, then rewrite in a mirror, never in the working clone.** The allowlist is every blob a range commit adds or modifies. The range is linear fork work with no merges, so no upstream blob is on it.

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals log --format= --raw --no-abbrev --diff-filter=AM b59b12e16c^..main | awk '{print $4}' | sort -u > /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-target-blobs.txt
sed -e 's/KEYS/costUSD|totalCostUSD|lastCost|est_cost_usd|total_cost_usd/' -e 's#history-rewrite-2026-11-11/evals-target-blobs.txt#history-rewrite-2026-11-15/evals-target-blobs.txt#' /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-11/evals-blob-callback.py > /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/blob-callback.py
/usr/bin/grep -c 'KEYS\|history-rewrite-2026-11-11' /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/blob-callback.py
/usr/bin/grep -c 'history-rewrite-2026-11-15/evals-target-blobs.txt' /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/blob-callback.py
```

Expected: `evals-target-blobs.txt` is non-empty and holds every blob `git -C evals diff-tree -r --no-commit-id --diff-filter=AM b59b12e16c` lists; the first count prints `0` and the second `1`. The 2026-11-11 template (`evals-blob-callback.py:7,11`) carries the literal `KEYS` placeholder and the old allowlist path, which is why both substitutions are checked.

```bash
git clone --mirror /Users/johnss51/Development/agents/hyperpowers/evals /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git
git -C /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git filter-repo --force --refs b59b12e16c^..main --blob-callback "$(cat /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/blob-callback.py)"
```

`--force` is safe here because the mirror is a fresh scratch clone; the 2026-11-11 script (`rewrite-evals.sh:26`) used it the same way. filter-repo writes `filter-repo/commit-map` inside the mirror; Step 4 reads it.

- [ ] **Step 3: Verify the mirror, then move the working clone, then verify the clone.** All checks before the move run against the mirror (`M` below is `/Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git`; type it out in each command). Stop and hand back if any check fails; the working clone is untouched until 3b.

3a, against the mirror:

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals rev-parse "$(cat /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-main-pre.txt)^{tree}"
git -C /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git rev-parse 'main^{tree}'
git -C /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git rev-list --count refs/remotes/origin/main..main
git -C /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git rev-list main | /usr/bin/grep -cxFf /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/old-range-commits.txt
git -C /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git log -p refs/remotes/origin/main..main | /usr/bin/grep -cE '"(costUSD|totalCostUSD|lastCost|est_cost_usd|total_cost_usd)\\*"? *: *-?[0-9]'
git -C /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git log -p refs/remotes/origin/main..main | /usr/bin/grep -cE '^\+.*\$[0-9]+\.[0-9]{2}'
git -C /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git log -p refs/remotes/origin/main..main | python3 ~/.claude/scripts/realval-scan.py
```

Expected, in order: the two tree ids are equal (the old tip already carried no figures, so content is unchanged); `20`; `0` (no old range commit survives on the new `main`); `0`; `0`; `hits: 0`. `log -p` prints every commit's diff in the range, so the two `grep -c` lines are the per-commit scan, not a tip-only check.

3b, move the working clone with the old id as the expected value, so the update fails if `main` moved meanwhile:

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals fetch /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-mirror.git main
git -C /Users/johnss51/Development/agents/hyperpowers/evals update-ref refs/heads/main FETCH_HEAD "$(cat /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/evals-main-pre.txt)"
git -C /Users/johnss51/Development/agents/hyperpowers/evals diff --quiet HEAD && echo index-matches
```

`main` is checked out in the clone; `update-ref` moves the branch without touching the index or working tree, and because the trees are equal the last line prints `index-matches`.

3c, drop the old tip from the clone's reflogs, then re-run the 3a checks against the clone. The clone has `core.logallrefupdates = true`, so after 3b the old commits are still reachable through the `main` and `HEAD` reflogs.

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals reflog expire --expire-unreachable=now --all
git -C /Users/johnss51/Development/agents/hyperpowers/evals rev-list --all --reflog | /usr/bin/grep -cxFf /Users/johnss51/.cache/hyperpowers/history-rewrite-2026-11-15/old-range-commits.txt
```

Expected: `0`. Then repeat the 3a count, both `grep -c` scans and the leak scan with `git -C /Users/johnss51/Development/agents/hyperpowers/evals` and `origin/main..main`, expecting `20`, `0`, `0`, `hits: 0`. The old objects stay in the object store as unreachable until a later `gc`, which this task does not run: no ref or reflog reaches them, so no push carries them, and the bundle from Step 1 is the only intended copy.

- [ ] **Step 4: Write the map** `evals/evidence/history-rewrite-2026-11-15.tsv` with a header in the format of `docs/hyperpowers/history-rewrite-2026-11-11.tsv:1-5` (what was removed, how many ids changed) and one `old<TAB>new` line per rewritten commit, using 10-character ids. Take the pairs from the mirror's `filter-repo/commit-map` (one `old new` pair per line, 40-character ids, a header line first), keeping only the 13 old ids in `old-range-commits.txt`.

- [ ] **Step 5: Update citations** of rewritten ids in the evals README and experiments doc and in the hp evidence note. Leave run archives (`verdict.json`, `provenance` fields, logs) as they are: they are records, and the map resolves them. Commit in evals (`evidence: map for the 2026-11-15 rewrite of the compaction range`) and in hp (`docs(hyperpowers): compaction evidence cites the rewritten evals ids`).

### Task 9: The evals corpus replay test stops asserting a host-specific symlink

**Risk tier:** standard: test change in the evals harness.

**Depends on:** Task 8

**Files:**
- Modify: evals `test/replay-post-checks.test.ts:2203` (inside the `corpus worktree run` case at `:2183-2230`)

Source: finish-long-suite memory; audit of 2026-11-15 (66 pass, 1 fail on evals `main`). The case already skips when the corpus root is absent (`test.skipIf(!existsSync(CORPUS_ROOT))` at `:2183`), and its comment makes a corpus root without the named run a failure on purpose; keep both. The run `worktree-no-drift-to-main-claude-auto-20261003T112456Z-f670` is present on this host, but `find <run> -type l` prints nothing: the Claude URL-handler symlink that `:2203` (`expect(r.externalReferences.length).toBeGreaterThan(0)`) expects is gone from the host copy. That assertion depends on host data, so it goes.

The rule it stood for, which links and pointers count as external references, is covered by corpus-independent fixtures in the same file: `:172` (an external link kept and listed beside a rewritten intra-source one), `:454` (a link that climbs out of the source), `:488` (an absolute target that detours through a sibling run but lands back in the source, rewritten rather than reported) and `:1170` (an alternates entry outside the run). Production resolves targets through `resolveThrough` (`src/cli/replay-post-checks.ts:381-399`) against the run's workspace root and also reports git alternates (`:1147`), so a test-side recount would have to copy that logic. Do not re-derive the count in the test; delete the assertion and point at the fixtures.

Do not skip the case: its byte-identity, separate-arm, `equal` and degraded-archive checks come after `:2203` and are worth keeping. Whether they pass on this corpus is unverified, because the failing assertion stops the case first; Step 3 finds out.

- [ ] **Step 1: Confirm the failure.** From `evals/`, run `bun test test/replay-post-checks.test.ts -t 'corpus worktree run'`. Expected: FAIL at `expect(r.externalReferences.length).toBeGreaterThan(0)`.

- [ ] **Step 2: Replace that one line** with this comment, and change nothing else in the case:

```ts
    // No count of external references here: the Claude URL-handler symlink
    // this once expected is host data, and some corpus copies no longer carry
    // it. The classification rule is pinned by the fixture cases above
    // (external link kept, climb out of the source, detour back into the
    // source, alternates outside the run).
```

- [ ] **Step 3: Run the case and the file.** `bun test test/replay-post-checks.test.ts -t 'corpus worktree run'` passes. Then `bun test test/replay-post-checks.test.ts` reports 67 pass, 0 fail. If the case fails at a later assertion, stop and hand back with that output: a second host-data dependence is a plan conflict, not something to loosen.

- [ ] **Step 4: Commit in evals:** `test(replay): the corpus case no longer asserts a host-specific symlink`.

### Task 10: Remove the six finished October plans from the tree

**Risk tier:** standard: deletes six plan files across one commit and may touch a docs page's sources and digest, so it is not single-file; the deletion is an ordinary revertible commit, not a history rewrite.

**Depends on:** none

**Files:**
- Delete: `docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md`, `2026-10-05-release-hygiene.md`, `2026-10-11-post-release-follow-ups.md`, `2026-10-14-agent-write-isolation-relocation.md`, `2026-10-19-sdd-turn-liveness.md`, `2026-10-20-portable-sdd-dossiers.md`

Source: audit of 2026-11-15. Each plan's work merged: review-calibration closed 2026-10-04; release-hygiene shipped in v6.16.0; post-release-follow-ups merged 2026-10-13; the relocation merged 2026-10-19; turn-liveness finished 2026-10-23 and its text shipped in 6.17.0; portable dossiers merged 2026-10-23. Since 2026-10-21 a plan leaves the tree at Finish. These six predate that convention or missed it. The twenty pre-October plans stay until the human partner decides on the decision-record backfill (register item 4).

- [ ] **Step 1: Check that no file outside `docs/hyperpowers/` links any of the six** (`git grep -n '<basename>' -- ':!docs/hyperpowers'`). Expected: none. If a docs page lists one in `sources:`, drop it there and re-take that page's digest.

- [ ] **Step 2: Delete and commit**

```bash
git rm docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md docs/hyperpowers/plans/2026-10-05-release-hygiene.md docs/hyperpowers/plans/2026-10-11-post-release-follow-ups.md docs/hyperpowers/plans/2026-10-14-agent-write-isolation-relocation.md docs/hyperpowers/plans/2026-10-19-sdd-turn-liveness.md docs/hyperpowers/plans/2026-10-20-portable-sdd-dossiers.md
git commit -m "docs(hyperpowers): six finished October plans leave the tree"
```

### Task 11: Prepare the 6.19.0 release commit

**Risk tier:** standard: version files, changelog and docs digests.

**Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 10

Resolved 2026-11-15: the human partner ships 6.19.0 now, with the unmeasured resume rules disclosed (Task 3). The 400K-window controller wave (register item 1) follows the release.

**Files:**
- Modify: version files `vrzn` manages (`vrzn.toml` lists them: `package.json` and the plugin manifests)
- Modify: `CHANGELOG.md` (Unreleased becomes `## 6.19.0 (<date>)`, with entries for Tasks 1, 5, 6 and 7)
- Modify: `docs/testing.md` (a release step)
- Modify: `source-digest:` of every page `docs-check` reports stale, including `docs/site/install.md`, `docs/site/skills/using-hyperpowers.md` and `docs/site/advanced/triggering.md`, which list the manifests

Source: RTD memory (manifest digests after every bump, with no checklist line).

- [ ] **Step 1: Bump**

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y
```

- [ ] **Step 2: CHANGELOG.** Rename `## Unreleased` to `## 6.19.0 (<today>)`. Add one bullet each for: companion calls kept out of the Bash sandbox and `gate-wait --codex-path` (Task 1); the compaction notice naming the session's own ledger (Task 5); the stop guard skipping fenced task headings (Task 6); bundle links following the SKILL.md rename (Task 7).

- [ ] **Step 3: Add the release step to `docs/testing.md`**, in the section that describes `docs-check`:

```markdown
After a version bump, run `bash tests/docs/docs-check.sh`: `vrzn` rewrites the plugin manifests, which are sources of the install, using-hyperpowers and triggering pages, so their digests must be re-taken (`--digest <page>`) before the release commit.
```

- [ ] **Step 4: Run `bash tests/docs/docs-check.sh`, re-read each stale page, re-take its digest, and run the full offline set**

```bash
bash tests/run-offline.sh
```

Expected: `offline set: 0 failed` (outside the sandbox for the brainstorm-server suite).

- [ ] **Step 5: Commit** `chore: bump version to 6.19.0`. Do not tag here: tagging and pushing are in "After Finish".

---

## After Finish (controller and human partner)

These steps change shared refs or the host, so they stay out of task branches:

1. Tag the campaign pins so the evals evidence keeps resolving: `git tag -a campaign/2026-11-11-compaction-reread-notice-pins compaction-reread-notice-pins -m "Campaign arm pins c149134f (control) and cff25286 (treatment) cited by hyperpowers-evals evidence"`. The two commits exist only on that local branch.
2. Tag `v6.19.0` (annotated) on the release commit.
3. Push, after the human partner says to: evals `main` first (HTTPS, works sandboxed), then hp `main`, `v6.19.0` and the campaign tag (SSH, sandbox off).
4. Check out `v6.19.0` in `.worktrees/plugin-install` and reload plugins.
5. Remove the ten campaign worktrees: `compaction-reread-notice/arms/{control,controller,shipped,slice,treatment,v6181}`, `parallel-development/hp-{control,treatment}`, `sdd-turn-liveness/hp-{control,treatment}`. Every commit they hold is reachable from `main`, a release tag, or the campaign tag from step 1. Run `git worktree prune` with the sandbox off. Remove the assessment worktree `~/.cache/hyperpowers/assessment-2026-11-15/main` too.
6. Delete the merged `post-release-follow-ups` branch in both repos (`git branch -d`). The evals `attr/*` and `review/*` branches are unmerged review-only branches; keep or delete them at the human partner's word.
7. The human partner removes the stale plugin cache copy `~/.claude/plugins/cache/hyperpowers/hyperpowers/6.16.1` (the sandbox denies writes under `~/.claude/plugins`).
8. Update `BACKLOG.md` (untracked): Zed idle is fixed (6.17.0 to 6.18.1); stale brokers is answered (do not allow the rename, because renaming a live record orphans its broker and jobs; 1669b4a3 and Task 1 remove the cause); parallel development part 2 shipped in 6.18.0; the question indicator stays open (register item 2).

## Register: outstanding work that needs a design or a measurement first

Each line gives the item, its source, and the recommended next step. None of these is a task in this plan.

1. **Compaction follow-through** (one brainstorm). A 400K-window controller wave, since bar 3 failed at 100K (compaction receipt `:467`). G6: the final train writes no ledger milestones (`final-and-finish.md:57`). G7: no durable Finish marker outside the workspace (`SKILL.md:68`). `setup.md` sits at 16,940 of its 17,000-character cap, so its next edit needs a move first. finishing-a-development-branch (29,579 characters) and writing-skills (26,221) carry no re-read paragraph when used on their own. The brainstorming compaction scenario has never been measured. Recommended: run the 400K wave first. Its result decides whether G6 and G7 are worth their skill text.
2. **Zed question indicator and question relay** (one brainstorm). BACKLOG 2026-11-12: when hyperpowers asks a question in Zed, the session looks busy instead of showing the message dot. This overlaps the parallel-development spec's deferred items (question relay, pending-tool-call hook, single-controller fan-out; spec `:963-972`) and BACKLOG part 1. Start with a transcript diagnosis, as the 2026-11-10 Zed work did.
3. **State and records hardening** (a sweep spec in the 2026-11-08 shape). Merge-back and finish `not-holder` write no waiting record (`review-and-complete.md:150-153`, `final-and-finish.md:113-115`). `restore_tomb` moves then checks under the lock (`sdd-state:1672-1686`). The dossier follow-ups: sidecars still at `$CO/.rewrite` and `$CO/.restore`, `reclaim_plain` takes no lock (`sdd-dir:81`), ungated ledger not on the state branch, executing-plans has no dossier lifecycle. The sweep's 24 accepted known limits and its non-goals. The state suite takes 21 to 56 minutes against a 20-minute budget. The dossier hand-back list (`~/.cache/hyperpowers/follow-ups-handback/final-handback-notes.md`) needs re-verification item by item first.
4. **Decision records.** Backfill records for pre-2026-10-21 specs and remove the twenty older plans with it (the human partner's call). A rule for whole-file deletion hunks in the Finish menu diff. CLAUDE.md naming `--reindex`. Four reversed decisions of the 2026-11-11 spec show as Current in the index, because the compiler refuses supersession within one spec (`decisions-compile:803`); an index marker for "reversed within its spec" would fix that.
5. **Evals harness.** Two ungated backstop events from the 6.16.2 tally are pending (20261104T183031Z-96940-15714 and 20261104T211309Z-36949-29108); they close when the human partner says "run the review sweep". `src/cli/replay-post-checks.ts` is one 3,046-line module. About 25 deferred minors on the dispatch-guard and compaction tally scripts. The agent-write-isolation wording minors.
6. **Measurements that come due.** The field re-scan on or after 2026-11-18: cost (`~/.cache/hyperpowers/cost-investigation/scan.py`, `analyze.py` against `report-home.txt`), the dispatch-guard field rate, and the re-read rate, read only from sessions whose loaded skill text carries the current paragraph. The turn-liveness `field.py` per-session bound Correction, owed only if an after-window runs. The Zed live check and an interactive fork-mode finish for decision records. Whether Claude Code still refuses Bash commands containing `complete` in a native-worktree session (it blocked `sdd-state complete` on 2.1.322).
7. **Docs site.** The Read the Docs import is the human partner's step. README "Cost and Context" trims after the site is live (decision 2026-11-05). PR preview builds need `READTHEDOCS_VERSION_TYPE=external` handling in `docs/site/conf.py:21` before previews are enabled.
8. **Severity-cap sentence.** The P3 control showed no over-rating in 3 of 3. Recommended: close it with no sentence.
