# Gate Reliability Hardening (6.3.0) — Eval Evidence

Date: 2026-07-23
Branch: `feat/gate-reliability-hardening` (merged to `main` at `d5c7c67`)
Spec: `docs/hyperpowers/specs/2026-07-22-gate-reliability-hardening-design.md`
Plan: `docs/hyperpowers/plans/2026-07-22-gate-reliability-hardening.md`

## Live-run results (release gate MET)

Scenario `codex-gate-stale-broker-attributed` (evals repo, commit `7d2bd2b`
plus fixes `cb3d7c9`/`42083ed`), run on `claude-vertex` from a real terminal.
Two runs — and both of the spec's core reliability paths were witnessed live:

1. **Run 1** — `codex-gate-stale-broker-attributed-claude-vertex-20260723T160158Z-ddd6`,
   `final = indeterminate`, and diagnostically golden: the session-start
   **janitor quarantined the planted dead broker before the gate ran**
   (`broker.json.stale-1784822547` in the run's state fixture), after which
   preflight correctly reported `ok`. That is spec acceptance criterion 1
   (self-healing) validated end-to-end on real infrastructure —
   accidentally, by a fixture that had not anticipated being healed. The
   run also validated fail-closed verdict handling in passing: the stub
   returned an empty review payload and the agent degraded via
   `verdict-normalize` → `incomplete` without fabricating any approval
   (noted explicitly by the Gauntlet-Agent).
2. **Run 2** — `codex-gate-stale-broker-attributed-claude-vertex-20260723T163110Z-3897`,
   **`final = pass`**, all 10 deterministic checks green, Gauntlet-Agent
   pass on all five criteria: preflight returned `stale-broker`; the agent
   emitted the attributed `Note [status: stale-broker]` notice; quoted the
   `mv broker.json → broker.json.stale-<timestamp>` recovery command
   verbatim; fabricated no Codex verdict; and completed the review skill
   normally with an honest verdict. That is spec acceptance criterion 2
   (attributed mid-session degrade) validated live. Cost: $1.33 total
   (Gauntlet $0.53 + Coding $0.80).

Run dirs are preserved under `evals/results/` as captured evidence.

## Scenario defects found by the live runs (all fixed in the evals repo)

The first live run earned its cost twice over — beyond validating the
janitor, it exposed three scenario-authoring defects that static validation
(`bun run quorum check`, 49/49) cannot catch:

- **Pre-Vertex agent allowlists** (`cb3d7c9`): all four codex-gate scenarios
  restricted `# coding-agents:` to `claude, claude-bedrock, claude-sonnet,
  claude-haiku`, predating this host's move to Vertex. `claude-vertex` and
  `claude-auto` added to all four.
- **Invented check verb** (`42083ed`): `checks.sh` asserted transcript
  content with `content-contains`, which is not in the harness's 13-verb
  trace vocabulary — post-checks crashed with exit 127. The harness has no
  transcript-content verb by design; the attributed-notice judgment moved
  fully to the story's Acceptance Criteria per house convention (the same
  reasoning recorded in the 2026-06-30 evidence doc for the incomplete
  scenario's "didn't fake a pass" judgment).
- **Janitor-vulnerable fixture** (`42083ed`): a dead broker planted before
  session start is healed at session start by the machinery under test.
  The fixture state dir is now read-only, so the janitor's rename fails
  silently (best-effort by contract) — which also mirrors the real observed
  `EPERM ... unlink broker.json` companion symptom — and a new post-check
  asserts `broker.json` survived the session. The fixture also gained
  `state.json` workspaceRoot evidence (name-independent resolution) and a
  realpath-derived state-dir name.

## In-session gate evidence (supporting)

The release's own development exercised the gates it hardened; the full
record is in the SDD ledger (progress ledger, per-task Codex round ledgers).
Highlights:

- Spec gate: approve in 3 rounds (r1: preflight readiness bar + state-dir
  lookup underspecified; r2: `CLAUDE_PLUGIN_DATA` root off by one level —
  refuted with companion source line citations).
- Plan gate: approve in 4 rounds; round 2's standout catch was the
  env-marker suppression design, killed after Codex traced the persistent
  broker's environment replay (that analysis is now spec §4.6 and upstream
  issue 3's rationale).
- Per-task code gates: 8 real defects found and fixed across 11 tasks,
  including two carried verbatim from the plan's own code (shadowable
  verdict regex; wrong state-root formula).
- Two backstop exits, both flagged per the amended §5 rule: Task 8 round 3
  (`19e6ab3`, merged §5 success condition) and the final whole-branch gate
  round 3 (`d5c7c67`, Summary-content anchor). Both fixes were verified by
  the Claude reviewer and tests; the final Claude reviewer (whole-branch,
  reconvened twice) held READY TO MERGE through both.
- Wording micro-tests (writing-skills discipline): the amended §1 branching
  was probed with fresh single-shot, tool-less reps — stale-broker stimulus
  quoted the recovery command verbatim with no retry; not-ready stimulus
  emitted the exact attributed notice and proceeded degraded. Both PASS,
  no wording changes required.

## Test-suite state at merge

- `tests/codex-review-gate/` + `tests/hooks/`: 157/157 at bump, expanded by
  post-merge-gate fixes to 19/19 (verdict-normalize), 77/77 (gate contract),
  janitor and preflight suites green; `scripts/lint-shell.sh` clean.
- `bun run quorum check`: 49/49 scenarios validate (48 prior + the new
  stale-broker scenario).
- Version manifests: all six declared files in sync at 6.3.0
  (`bump-version.sh --audit` clean).

## Remaining evidence hooks

- Upstream issue URLs: to be recorded in the plan's Task 10 section once the
  human partner files the five issues from
  `docs/hyperpowers/2026-07-23-codex-plugin-cc-upstream-issues.md`
  (manual filing by explicit decision).
- The two pre-existing codex-gate eval scenarios were static-validated in
  this cycle; live re-runs on Vertex are now unblocked by the allowlist fix
  if longitudinal confirmation is wanted.
