# Compaction Re-read Notice and Compact SDD Controller: Evaluation Evidence

Date: 2026-11-13. Spec: `docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md`, whose section "Revision (2026-11-12): a compact SDD controller" and its "Testing (revised)" govern this campaign. Run artifacts, logs, manifests and tallies: `evals/evidence/2026-11-11-compaction-reread-notice/` in hyperpowers-evals. A run is cited as `evals/evidence/2026-11-11-compaction-reread-notice/task-6-runs/<arm>/<run-id>`.

The revised campaign failed bars 1 to 4 and passed bar 5. The human partner decided that the notice stays off any release. This note records the measured failure.

## The change under test

The slice pin is `d00c689ff2addd5438a09e35f0bd355f7bd83b96`, the integration branch head after Tasks 7 to 10.

### The controller and its step files

`skills/subagent-driven-development/SKILL.md` is a controller that fits inside the 20,000 characters Claude Code re-attaches after a compaction, so it comes back whole. It keeps the overview, Continuous execution, Tracked work only, When to Use, Model Selection, the waiting board and the Risk Tiers pointer. It adds a numbered outline of the process (The Process), the step table (After a compaction: the step table) and the rules that hold in every step (Rules for every step). The step text moved into five files in the same directory. Sizes at the slice pin, in characters and lines:

| File | Holds | Characters | Lines |
| --- | --- | --- | --- |
| `SKILL.md` | the controller | 13,736 | 146 |
| `setup.md` | Setup | 16,920 | 252 |
| `task-loop.md` | the Task Loop's introduction, dispatch and the report | 15,582 | 170 |
| `review-and-complete.md` | the task review and completing the task | 11,123 | 170 |
| `fix-loop.md` | the fix loop | 7,676 | 124 |
| `final-and-finish.md` | Final Review and Finish | 9,680 | 155 |

Released v6.18.1's `SKILL.md` (`7f7c399ca1eef6e931d01fa47c02303eef32f44a`) is one file of 76,174 characters.

### The step table

Verbatim from `SKILL.md` at the slice pin, with the sentence before it:

```markdown
Print the board (`scripts/sdd-state board PLAN_FILE`) and the ledger lines of your task and your Setup (`grep -E '^(Task <N>:|session <sid>: setup complete)' <workspace>/progress.md`, leaving out `Task <N>:` when you hold no task); `scripts/sdd-dir PLAN_FILE` prints the workspace. Do not Read the whole ledger after a compaction: it grows with the plan. A row's newest line is the newest of your task's lines the table names (its branch, base, implementer identity, `report`, `review`, Codex gate round, `approved`, `merged` and `fix round` lines); a line it does not name, such as a deferred minor or the gate directory, leaves your step unchanged. Then Read the step file this table names:

| State | Step file |
|---|---|
| no ledger in the workspace, or no `setup complete` line of this session in it | [setup.md](setup.md) |
| the board shows no task held by this session and a task without a completion line | [task-loop.md](task-loop.md) |
| the held task's newest line is its branch, base, implementer identity or `report` line | [task-loop.md](task-loop.md) |
| its newest line is a `review` or Codex gate line approving it, an `approved` line or a `merged` line | [review-and-complete.md](review-and-complete.md) |
| its newest line is a `fix round` line, or a `review` or Codex gate line with blocking findings | [fix-loop.md](fix-loop.md) |
| this session holds the final claim, or every task has a completion line | [final-and-finish.md](final-and-finish.md) |

A state the table does not cover reads [task-loop.md](task-loop.md), and you record that in the ledger.
```

### The paragraph

Verbatim, line 23 of `SKILL.md` at the slice pin:

```markdown
**After every context compaction:** this file fits within the 20,000 characters Claude Code re-attaches, so the copy you hold is whole. A step file you read before the compaction does not survive it. Before your next action, print the board and the ledger lines the step table names (your task's and your Setup's, never the whole ledger), find your step in the table, and Read that step file in full.
```

### The notice

`hooks/session-start` adds this line on every `compact` run, after the existing notices and before the ledger notice. `<root>` is the plugin root as the hook spells it:

```text
Context was compacted. Each skill you invoked came back cut to 20,000 characters, and a long session can hold an older copy than the one installed. Before your next action, Read in full <root>/skills/<name>/SKILL.md for each hyperpowers skill you are following, then the files it tells you to read after a compaction; if none, skip this.
```

### The dispatch guard sentence

The refusal texts in `hooks/lib/dispatch-guard.mjs` end with this sentence, where `${skill}` is the SDD `SKILL.md` path:

```text
If you have not Read ${skill} and the step file its step table names since the last compaction, Read them now.
```

## The first campaign and the v6.18.1 baseline

The first campaign measured the notice alone, on a branch whose SDD and brainstorming skills had the "After every context compaction" paragraph removed. From `tally.txt` (waves 1 and 2, `python3 tally.py --waves-1-2`):

| Arm | Scenario | Runs | Valid | Voids | Outcome pass | Compactions followed |
| --- | --- | --- | --- | --- | --- | --- |
| control (paragraph removed) | sdd-compaction-reread | 10 | 10 | none | 10/10 | 4 of 93 (4%) |
| treatment (paragraph removed, notice added) | sdd-compaction-reread | 10 | 0 | 10 instrument | none valid | none valid |

Every treatment run ended in Claude Code's "Autocompact is thrashing" stop with no subagent dispatched, 10 of 10. The tally of that time read a run with no dispatch as an `instrument` void, which is why `tally.txt` shows ten voids. In the traced run (`treatment/sdd-compaction-reread-claude-auto-20261112T231620Z-11c2`) the first compaction came during SDD Setup at about 68K tokens; the session then read `SKILL.md` and compacted again 35 to 40 seconds later at about 66K, nine times. The campaign stopped after wave 2, and waves 3 (shipped) and 4 (sentinel) were not run (evidence README, "Outcome (2026-11-12)").

Released v6.18.1, which has the paragraph and no notice, failed the same way on 2026-11-12: 10 of 10 runs ended in the thrash stop. At the 100,000-token window, a full re-read of the 76,174-character skill after a compaction puts the context back at the compaction threshold. That result led to the revision: a controller that comes back whole after a compaction, so a resumed session re-reads one step file instead of the whole skill. The baseline's ten runs are the revised campaign's control arm below.

## Method

Arms, from the evidence README ("Revision (2026-11-12)") and `manifest.tsv`:

- `baseline-6181` (control): released v6.18.1, `7f7c399ca1eef6e931d01fa47c02303eef32f44a`, on `sdd-compaction-reread`. These are the 2026-11-12 baseline runs, launched before the revised launcher existed. Their harness paths at evals `b59b12e16c` are identical to the harness pin, and they ran on the same Claude Code version and models (spec decision 10).
- `slice` (treatment): the slice pin above, on `sdd-compaction-reread` (launch manifest `manifest-revision-a.tsv`).
- `slice` (sentinel): the slice pin on `compaction-no-skill` (`manifest-revision-b.tsv`).

Pins: harness `474ea8c8dff4038337ef759ff410be8b9332b494` (evals; paths `src scenarios coding-agents package.json bun.lock`, checked identical at every launch), Claude Code 2.1.317, controller model `claude-opus-5-5`, Gauntlet-Agent (grader) `claude-opus-5-5`. Both scenarios set `autoCompactWindow` to 100000 in the fixture's `.claude/settings.json`. From each run's token-usage record, the slice SDD subagents ran on `claude-sonnet-5-5` in all 10 runs, and two runs (`...-22a7`, `...-cb7f`) also used `claude-haiku-4-5-20251001`. Nine baseline runs used `claude-opus-5-5` only, since they dispatched no subagent; `...-f82f` also used `claude-sonnet-5-5`.

The slice SDD runs launched 2026-11-13 at 18:18Z and the sentinel runs at 19:07Z, with the one sentinel replacement at 19:12Z.

Validity and outcome (spec, "Testing (revised)"). An SDD run is void when its launch failed a pin check, setup errored, the Gauntlet-Agent gave no pass or fail, a quorum stage after setup errored, or no automatic compaction came after the skill loaded. Every other run is valid. A valid run passes its outcome when the final reading is pass, every post-check passes and it dispatched at least one implementer. A run that ends in the thrash stop, or never dispatches, is valid and fails its outcome. A slice compaction is followed when, before the next governed action, the session read in full the step file the step table names for the state at that compaction and, when a ledger existed, printed the board and grepped its task's and its Setup's ledger lines. The sentinel fails a valid run that, after a compaction, reads a `SKILL.md` of a skill it never invoked.

Two things changed after the runs were in.

1. The tally as first written read the five slice SDD runs that ended in the thrash stop as grader voids, because the Gauntlet-Agent returned status `investigate` for each and gave no pass or fail. The spec counts a thrash run as a valid failure. `tally.py` was fixed to read a thrash stop as a valid failure even under a grader void (evals `db70c8d345`, with tests), and the five runs count as valid outcome failures. None was replaced.
2. No dollar figure is kept in either repository. The archived runs carried cost keys and quorum's dollar column, so the 2026-11-11 history rewrite's two rules were applied to the new archive and to 27 files the waves 1-2 commit had already committed (evals `54bf447b9b`): quorum's dollar column is dropped, and `costUSD`, `totalCostUSD`, `lastCost`, `est_cost_usd`, `total_cost_usd`, `total_est_cost_usd` and `cost_usd` are set to null. A null cost value in an archived run comes from this scrub, not from capture. The tally output was byte-identical before and after the scrub.

The revised runs and tally are evals `ac33ae7709`. `tally-revision.txt` is the output of `python3 tally.py` in the evidence directory.

## Results

### sdd-compaction-reread

| Arm | Runs | Valid | Voids | Outcome pass | Thrash stops | Compactions | Median compactions per run |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `baseline-6181` | 10 | 10 | none | 0/10 | 10 | 49 | 4 |
| `slice` | 10 | 10 | none | 5/10 | 5 | 208 | 19 |

Nine baseline runs dispatched no subagent. The tenth, p5 (`baseline-6181/sdd-compaction-reread-claude-auto-20261112T233736Z-f82f`), dispatched one implementer. Every slice run dispatched four implementers, four task reviews and at least one final review.

### compaction-no-skill (sentinel, slice only)

| Arm | Runs | Valid | Voids | Failed |
| --- | --- | --- | --- | --- |
| `slice` | 11 | 10 | 1 grader | 0 |

The void is p9 (`slice/compaction-no-skill-claude-auto-20261113T190718Z-c178`): the Gauntlet-Agent returned `investigate`, and its summary says no compaction happened. It was replaced by r1 (`slice/compaction-no-skill-claude-auto-20261113T191201Z-3b39`), recorded in `sentinel-reruns.tsv`. No valid sentinel run read a skill file after a compaction (`reads=-` on all ten).

### Per compaction, slice SDD

Columns from each run's line in `tally-revision.txt`: compactions after the SDD skill event; followed (the named step file read in full, plus the board and the ledger grep when a ledger existed); any step file read; board and grep both credited; SDD `SKILL.md` read.

| Run | Outcome | Thrash | Compactions | Followed | Any step file | Board and grep | SKILL.md read |
| --- | --- | --- | --- | --- | --- | --- | --- |
| p1 `sdd-compaction-reread-claude-auto-20261113T181816Z-e9a8` | pass | 0 | 23 | 7 | 9 | 17 | 18 |
| p2 `sdd-compaction-reread-claude-auto-20261113T181816Z-c9f8` | pass | 0 | 16 | 4 | 7 | 10 | 8 |
| p3 `sdd-compaction-reread-claude-auto-20261113T181816Z-55cf` | pass | 0 | 18 | 5 | 7 | 15 | 12 |
| p4 `sdd-compaction-reread-claude-auto-20261113T181816Z-cb7f` | fail | 1 | 30 | 5 | 11 | 20 | 24 |
| p5 `sdd-compaction-reread-claude-auto-20261113T181816Z-22a7` | fail | 1 | 30 | 0 | 5 | 9 | 26 |
| p6 `sdd-compaction-reread-claude-auto-20261113T181816Z-7ec4` | fail | 1 | 24 | 8 | 11 | 18 | 18 |
| p7 `sdd-compaction-reread-claude-auto-20261113T181816Z-df5c` | pass | 0 | 18 | 7 | 9 | 14 | 9 |
| p8 `sdd-compaction-reread-claude-auto-20261113T181816Z-8440` | pass | 0 | 11 | 4 | 4 | 9 | 7 |
| p9 `sdd-compaction-reread-claude-auto-20261113T181816Z-54ce` | fail | 1 | 18 | 9 | 9 | 15 | 14 |
| p10 `sdd-compaction-reread-claude-auto-20261113T181816Z-9a78` | fail | 1 | 20 | 0 | 5 | 2 | 5 |
| pooled, valid runs | 5/10 | 5 | 208 | 49 (24%) | 77 | 129 | 141 |

Each run directory is under `evals/evidence/2026-11-11-compaction-reread-notice/task-6-runs/slice/`.

### Where the five thrash runs stopped

Each of the five Gauntlet summaries (`verdict.json`, `gauntlet.summary`, status `investigate`) says the run implemented and reviewed all four tasks, ran the final whole-branch review and loaded finishing-a-development-branch, and that Claude Code then stopped with "Autocompact is thrashing" before the session offered the merge, push, keep or discard choice. p10 (`...-9a78`) had also run `sdd-state finish`. p4's summary (`...-cb7f`) adds one fix wave and a re-review after the final review. p9's summary (`...-54ce`) says the stop came while the agent was re-reading skill files after a compaction. The summaries report the test suite passing in p4, p5, p6 and p10 (48 of 48, 32 of 32, 77 of 77 and 70 of 70). The records say nothing more about why the stop came at the finishing step.

### Bars

Copied from `tally-revision.txt`:

```text
bar 1, slice SDD outcome (at least 8 of 10 valid, and more than baseline-6181's): FAIL
bar 2, slice SDD thrash (no valid run with thrash=1): FAIL
bar 3, slice SDD compactions followed (at least 85%, valid runs pooled): FAIL
bar 4, slice SDD median compactions per run (at most 16): FAIL
bar 5, sentinel failures (at most 1 of 10): PASS
```

The slice finished 5 of 10 valid runs against the baseline's 0 of 10, and 5 slice runs ended in the thrash stop against the baseline's 10. It followed 49 of 208 compactions (24%) against the bar of 85%, and its median of 19 compactions per run is above the bar of 16.

## Task 1 smoke run

One live smoke of the new `compaction-no-skill` scenario ran on 2026-11-12 before the campaign, against evals `474ea8c8df` with the plugin root set to the slice worktree of that time: run `compaction-no-skill-claude-auto-20261112T071537Z-f939`. The ledger records quorum exit 0, two automatic compactions (after file 4 and after file 8), both before the final reply, and no Skill call. It is not a trial and enters no tally. It was not archived in the evidence directory; its run directory is in the evals clone's `results/`, which git ignores.

## Assumptions

- Marketplace installs keep each version in its own cache directory. In `~/.claude/plugins/installed_plugins.json`, `codex@openai-codex` records version `1.0.6` with `installPath` `/Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6`, a directory named for the version.
- A hook edited on disk takes effect in a running session. Inconclusive. Session `ec562ba3` loaded its plugin on 2026-10-21 (6.16.1 skill text) and compacted at 2026-11-10T16:55:22.743Z, after `plugin-install` had moved to v6.17.0 on 2026-11-06. The SessionStart `compact` hook output recorded with that `compact_boundary` names the ledger `/Users/johnss51/.cache/hyperpowers/sdd/193a951fd4f675975a919be372c5015a95aa0491/plans/2026-11-10-cramer-v1-v2-carbohydrate-b7cd2bf8+987db445/progress.md`, under `sdd/`. The search of the `state/` checkout came in `77648a99` ("fix(hooks): the compaction notice looks in the state checkout first", first released in v6.17.0). That hook takes the newest ledger across `state/<key>/plans`, `sdd/<key>/plans` and the legacy key, and v6.16.1 prints the same sentence, so an `sdd/` path does not tell which hook ran.
- One task's ledger lines stay under about 15,000 characters, so the recovery read (SKILL.md, one step file, the board and the task's lines) stays under about 52,000 characters. Measured 2026-11-12 over seven ledgers on this host: the largest one task's lines reach 11,932 characters. Not re-measured for this note.

## Not measured

- The brainstorming compaction scenario.
- Plans longer than four tasks. The campaign ran one four-task plan.
- The check of a current long-lived session's compaction output after a release, which the hook-reach assumption above still needs.
- The field re-measure of the re-read rate, owed on or after 2026-11-18 with the cost re-scan.
