# Upstream Sync Design: superpowers v6.0.2 → v6.3.0

Date: 2026-08-17
Status: Approved design, pending user spec review
Fork point: `b62616f` (upstream v6.0.2). Upstream head: `b36e082` (v6.3.0). 79 commits assessed via four parallel investigations comparing `b62616f..b36e082` against fork HEAD.

**Source pin:** every upstream file or hunk this sync takes is read at
`b36e082` (e.g. `git show b36e082:skills/...`), never at the mutable
`upstream/main`. Incorporating anything past `b36e082` requires a new
assessment and spec review.

## Goal

Incorporate the upstream changes worth having into hyperpowers in three staged
releases, without losing fork-specific tuned content (Codex review gates, risk
tiers, cache-based SDD scratch, renames) and without adopting upstream
decisions the fork has deliberately rejected.

## Locked Decisions

1. **Scope:** three batches — clean ports, SDD efficiency, brainstorming
   router. The rulings-not-stalls doctrine is deferred (see Deferred).
2. **SDD merge depth:** full lifecycle restructure onto upstream's
   Setup → Task Loop → Final Review → Finish shape.
3. **Codex gate meshing:** unified fix loop. Codex-gate blocking findings join
   the same per-task fix loop as Claude reviewer findings and count against a
   shared five-round cap; the scoped re-review replaces today's full
   task-reviewer re-run after Codex fixes.
4. **Router × approach gate:** the Codex approach gate keeps its existing
   trigger (real architectural/algorithmic/data-model alternatives) on *any*
   router path; alternatives do not force reclassification.
5. **Eval posture:** targeted fork evals only where the fork's composition is
   novel (restructured SDD + unified loop; router + gates). Upstream's
   documented eval evidence carries the straight ports.
6. **Packaging:** three staged releases, `vrzn bump minor -y` each, focused
   commits within a batch (one problem per change). Nothing pushed or
   committed beyond what the user approves at execution time.
7. **Merge strategy:** hybrid grafting. The two heavily-diverged files
   (`skills/subagent-driven-development/SKILL.md`,
   `skills/brainstorming/SKILL.md`) are rebuilt from upstream's final version
   with a fork-delta inventory (diff fork HEAD vs `b62616f`) ensuring every
   fork-specific block re-lands. All other files apply upstream hunks onto the
   fork base.

## Ordering Rule (subsumption)

Batch 1 must not touch files that Batches 2 or 3 rebuild from upstream-base:

- `skills/subagent-driven-development/*` — all Batch-1-era candidates
  (2173c1c Advantages deletion, 03147d2 Integration fold, no-subagents
  insertion into SDD prompt files) are subsumed by the Batch 2 graft, whose
  upstream source files already contain them.
- `skills/brainstorming/*` — 05d90ac (Key Principles fold) is subsumed by the
  Batch 3 router graft.

## Batch 1 — Clean Ports (release: next minor)

| # | Item | Upstream source | Fork action |
|---|------|-----------------|-------------|
| 1 | `skills/writing-skills/render-graphs.js` | b36e082 (13-line fix) + `tests/writing-skills/test-render-graphs.sh` | Take upstream version (ES imports, `execFileSync`, `dot -V` probe). Fixes live, reproduced `ReferenceError` in repo and installed plugin. Port test as-is. |
| 2 | `skills/systematic-debugging/find-polluter.sh` | 6015d37 + c8921b5 + `tests/systematic-debugging/test-find-polluter.sh` | Take upstream final script (./-prefix matching, empty-result count, `**/` top-level collapse). Port test dir. |
| 3 | `skills/finishing-a-development-branch/SKILL.md` | `b36e082` wholesale (0b47219, 9dff1a9, bcfe798, fbb6dba, v6.3.0 refused-removal guard) | Replace file; zero fork-specific content exists in it. Brings worktree-path capture fix, no-discard menu, forge-agnostic PRs, refused-removal guard (never `--force`; show untracked files, offer commit/move/delete). |
| 4 | Bootstrap compression | 777cc2f, e7ddc25, d238a48, a868631 | Compress `skills/using-hyperpowers/SKILL.md` (~790 → ~480 words; saves 400+ tokens per session via `hooks/session-start`). Keep `hyperpowers:` prefixes, Red Flags table verbatim, fork harness list (no Hermes; Gemini already absent). Take upstream post-prune `codex-tools.md`, `pi-tools.md`, `antigravity-tools.md` (rename-normalized); delete `claude-code-tools.md` and `copilot-tools.md`; fix dead references in `skills/writing-skills/SKILL.md:12` (no Gemini clause) and `docs/porting-to-a-new-harness.md`. |
| 5 | TDD rewrite | e74961c..caa1826 chain + b9e75dd | Swap in upstream `skills/test-driven-development/SKILL.md` and new `writing-good-tests.md` (rename `superpowers:` → `hyperpowers:`); delete `testing-anti-patterns.md` (referenced only from TDD SKILL.md). |
| 6 | No-subagents contract (partial) | T1 / PR #2059 | Apply the clean +9 hunk to `skills/requesting-code-review/code-reviewer.md` only. SDD prompt files get their sections via the Batch 2 graft. |
| 7 | Compression refactors | 3fb7597, 153d618, 1e14b23, bc86802, cfb6281, 09fc6e0, 03147d2 (executing-plans half), c74782e, af67e03, 6dbbdda | Mechanical section deletions/folds. Adapts: writing-plans "Remember" deletion also rewords the line-20 cross-reference it orphans; systematic-debugging Related-skills fold uses the fork's own "re-run the original failing command" wording (fork has no verification-before-completion skill). Excludes SDD and brainstorming files per the ordering rule. |
| 8 | Test harness fixes | 0e13ad8, a60dc2f (adapted) | Timeout 600→900 + stale help text; case-insensitive `assert_*` helpers (preserve fork's `docs/hyperpowers` path divergence); widened SDD test patterns; pi test scoped to table rows keeping the fork's token list. |
| 9 | Portability nits | 4572974, 5151e7a, 52f649e | `.codex-plugin/plugin.json` category "Coding" → "Developer Tools"; `hooks/hooks.json` SessionStart gains `"shell": "bash"` + test assertion in `tests/hooks/test-session-start.sh`; port `docs/windows/polyglot-hooks.md` update. All no-ops on macOS. |

**Batch 1 verification (ordered):** repo test suite including the two new
ported test files → refresh the installed plugin **from the candidate working
tree** (pre-release, so the smoke exercises the candidate, not the previous
release) → acceptance smoke: fresh Claude Code session, "Let's make a react
todo list" auto-triggers brainstorming (proves the compressed bootstrap still
loads and binds) → `vrzn` bump and release commit → post-release refresh
re-aligns the installed version.

## Batch 2 — SDD Restructure and Efficiency (release: next minor + 1)

### Merge mechanics

1. Produce the fork-delta inventory:
   `git diff b62616f HEAD -- skills/subagent-driven-development/` enumerated
   into a checklist of fork-specific blocks: Risk Tiers + rubric + tier-skips,
   per-task Codex gate sections, ungated-ledger wiring, "Subagent Reports Are
   Claims", `fix-subagent-prompt.md`, renames.
2. Rebuild `SKILL.md` from the `b36e082` version (lifecycle shape,
   rationalization table, no Advantages/Integration sections). Re-hang every
   inventory block in its lifecycle-appropriate place; check each off.
3. Prompt files: take upstream's `implementer-prompt.md`,
   `task-reviewer-prompt.md`, and new `re-review-prompt.md` (rename-normalized;
   they carry the no-subagents sections, resume-round "After Review Findings"
   rewrite, batch file-list reconciliation, and evidence re-read rule);
   re-apply the fork's deltas from the inventory. `review-package` gains the
   upstream `PLAN_FILE`/`FIX_BASE` signature.

### Unified fix loop (behavior spec)

- Task review produces blocking findings → **rounds 1–3 resume the original
  implementer** with findings verbatim (Claude Code supports resume natively);
  **rounds 4–5 dispatch a fresh takeover implementer** on a more capable model.
  Minor findings never enter the loop; they go to the ledger.
- Every fix round is verified by a **scoped re-review**
  (`re-review-prompt.md`): fix-diff only (`FIX_BASE` = head the previous
  review saw), per-finding verdict ADDRESSED / NOT ADDRESSED, new breakage
  flagged in the fix diff only, out-of-scope observations to the ledger.
- **Codex-gate blocking findings enter the same loop** and count against the
  same five-round cap. The scoped re-review replaces the current "re-run the
  task reviewer before re-running the per-task Codex gate" rule.
- **Gate-doc reconciliation (exact surfaces, same commit as the loop
  change):** in `skills/requesting-code-review/codex-review-gate.md`, the §5
  per-gate backstop table and §3 tier-applicability text change so that
  **SDD per-task** gates defer to SDD's shared five-round cap (the per-task
  3-round backstop is subsumed); **final whole-branch and ad-hoc code gates
  keep their existing 3-round backstop** (they sit outside the per-task
  loop), and **document gates (spec/plan) keep 4**. The SDD SKILL.md gate
  sections and `codex-review-gate.md` must land in one commit. Verification:
  after the commit, no text anywhere describes a per-task Codex round budget
  other than the shared cap (checked by grep for the old backstop wording),
  and the final/adhoc/document backstops are unchanged.
- **Five-round breaker resolves fork-style:** surface unresolved findings to
  the human via the existing BLOCKED path. This deliberately diverges from
  upstream's park-with-ruling ending because rulings-not-stalls is deferred;
  fail-closed behavior is preserved.
- `fix-subagent-prompt.md` shrinks to its upstream role: the single
  final-review fix wave (one wave + exactly one scoped re-review, no second
  wave), then breaker rules above.

### Plan-scoped scratch

- Cache key gains a plan segment:
  `${XDG_CACHE_HOME:-~/.cache}/hyperpowers/sdd/<git-dir-hash>/plans/<plan-slug>/`,
  where `<plan-slug>` is the plan file's basename without extension **plus**
  an 8-character truncation of `git hash-object` over the normalized
  repo-relative plan path (`<basename>-<hash8>`). The dedicated `plans/`
  subdirectory exists so plan-level GC can only ever touch known plan
  workspaces, never non-plan cache content stored under the repo dir by
  no-arg `sdd-dir` callers. Basename alone is
  collision-prone: two plans named `plan.md` in different directories must
  not share a workspace. `tests/claude-code/test-sdd-dir-path.sh` gains a
  case asserting same-basename plans in different directories resolve to
  distinct workspaces. The working-tree `.superpowers/sdd` location remains
  rejected.
- `scripts/sdd-dir` accepts an optional `PLAN_FILE` argument; no-arg mode is
  preserved because `skills/optimizing-performance/SKILL.md` uses it as a
  generic cache helper. `task-brief` and `review-package` pass the plan
  through.
- Ledger self-identifies: first line `# SDD ledger — plan: <plan file path>`.
  Start-of-skill ledger check reads only the plan's own workspace.
- Workspace is deleted when the final review is clean (delete-at-finish);
  the 14-day idle GC remains as backstop.
- `skills/requesting-code-review/scripts/ungated-ledger` is untouched: the
  git-dir-hash derivation itself does not change.
- Update `tests/claude-code/test-sdd-dir-path.sh`.

### Additional Batch 2 items

- **Wait discipline:** upstream's "Waiting on dispatched subagents" block
  (work while children run; bounded 5–10 minute waits when idle; status line;
  reconcile live children). Composes with the gate doc's detached launch.
- **Spec travels with the plan:** `skills/writing-plans/SKILL.md` plan header
  gains `**Spec:** [path]`; SDD Setup reads the spec as binding authority and
  ledgers its absence. Also feeds Codex gates' `--doc` inputs.
- **Batching:** small same-shape tasks may share one dispatch brief listing
  every file/change; reviewer verifies every listed file has a hunk. Fork
  rule: a batch's effective Codex-gate risk tier is the max of its members'
  tiers.
- **Preflight evidence table (portable form):** the pre-flight conflict scan
  emits one ledger row per task pair sharing a file/interface plus one
  self-consistency row per task. The fork's batched-questions-to-human step is
  retained (rulings deferred).

### Batch 2 eval gate (must pass before release)

Run in the hyperpowers-evals harness:

1. **Fix-loop convergence:** seeded reviewer findings across rounds; assert
   scoped re-review used after round 1 (no full-diff re-review), resume vs
   takeover round structure honored, Codex-origin findings counted against
   the shared cap, breaker surfaces to human at round 5.
2. **Plan scoping:** two back-to-back plans in one repo; assert the second
   plan's controller never reads the first plan's ledger (no cross-plan
   forensics) and the finished plan's workspace is gone.

## Batch 3 — Brainstorming Three-Path Router (release: next minor + 2)

### Merge mechanics

Upstream-base rebuild of `skills/brainstorming/SKILL.md` (source:
`b36e082`) with fork-delta inventory. Upstream brings: spike / bounded / architectural router with
announced classification and user override; artifact scales, approval never
does; one-way complexity ratchet; per-path checklists; new Red Flags table;
reworded HARD-GATE; "After the Design" scoped to the architectural path.

Fork blocks re-grafted:

- **Codex approach gate** — carries its own trigger (real
  architectural/algorithmic/data-model alternatives, or explicit user
  request) on any path. On the bounded path its approaches fold into the
  short in-chat design; ceremony does not escalate. On the spike path the
  gate does not normally fire (feasibility probes rarely present committed
  design alternatives), but the trigger still governs: an explicit user
  request, or genuinely material alternatives, fire it there too. The Batch 3
  eval covers the bounded-path case only; spike-path non-coverage rationale:
  the trigger text is identical across paths, so the bounded case exercises
  the same conditional.
- **Codex spec gate** — unchanged, attached to spec writing; runs only on the
  architectural path because only that path produces a spec file.
- Both digraph nodes; spec-not-committed policy; the fork's "just use it"
  visual-companion semantics (upstream's "offer" wording is not adopted).

`skills/brainstorming/visual-companion.md`: take upstream's corrected Copilot
CLI backgrounding text.

### Batch 3 eval gate (must pass before release)

1. Ambiguous-brief escalation battery (upstream's scenarios) with fork gates
   present: ≥4/5 escalate to the architectural path.
2. No-downgrade: 5/5 architectural tasks are never reclassified downward.
3. Fork-specific: a bounded task with genuine algorithmic alternatives fires
   the approach gate without escalating ceremony (no spec doc produced).

## Deferred and Skipped

**Deferred — rulings-not-stalls** (revisit after all three batches land).
Evidence for it: donated session dormant 8h48m on a decidable question; 3/3
no-stall vs 3/3 control stall; 5/5 catastrophic-action guard held. Against:
deletes human checkpoints; tensions with the fork's fail-closed gate
philosophy. If adopted later, reconcile: breaker ending, gate-backstop
hand-back, preflight questions step, finish-time "Rulings I made" roll-up.

**Skipped:**

- Working-tree `.superpowers/sdd` workspace (fork's cache decision stands;
  upstream's own eval showed blind stale-ledger adoption never reproduced).
- Devin CLI and Hermes Agent support (cleanly separable; unused harnesses).
- Gemini removal/revert (upstream net zero; fork removed independently —
  permanent divergence, expected conflict zone in future syncs).
- Codex portal packaging pipeline (fork has its own packaging; resume re-fire
  fix already landed independently as `hooks-codex.json` matcher). Landmine
  recorded: if `.codex-plugin/plugin.json` ever drops its `hooks` field it
  must become exactly `"hooks": {}` — absent or `[]` re-triggers auto-discovery
  of the Claude Code hook.
- a80b7b6 / 28b96af test realignments (tied to unported pruning shape or to
  Codex hooks the fork deliberately keeps).

## Divergence Registry (for future syncs)

1. Five-round breaker surfaces to the human (BLOCKED path), not
   park-with-ruling.
2. Codex approach gate rides its trigger on any router path, not the
   architectural path only.
3. SDD scratch is cache-based and now plan-scoped:
   `~/.cache/hyperpowers/sdd/<git-dir-hash>/plans/<plan-slug>/`.
4. Visual companion uses "just use it" semantics, not upstream's offer-first.
5. Gemini support removed in fork, alive upstream.
6. Fork keeps `hooks-codex.json` + `session-start-codex` (upstream deleted
   theirs).

## Release Mechanics

One implementation plan covers all three batches as strictly ordered phases;
each batch ends in a release checkpoint task.

Per batch: focused commits → repo tests → (Batches 2–3) eval gate → `vrzn
bump minor -y` → release commit → refresh the installed plugin copy (no
mid-stream hand-patching of the plugin cache; Batch 1 additionally refreshes
from the candidate working tree pre-release for its acceptance smoke, per its
ordered verification). No pushes and no spec/plan commits unless explicitly
requested.

## Risks

- **Tuned-content loss in the two grafts** — mitigated by fork-delta
  inventories carried into the implementation plan as explicit per-block
  checklists, and by the targeted evals.
- **Eval flakiness** — mitigated by landing Batch 1's test-harness fixes
  (timeouts, case-insensitive asserts) before any eval-gated batch.
- **Unified loop changes Codex gate semantics** — the gate doc's language must
  be reconciled in the same commit that changes SDD's loop, or the two
  documents contradict each other mid-batch; fail-closed behavior is
  preserved at the breaker.
