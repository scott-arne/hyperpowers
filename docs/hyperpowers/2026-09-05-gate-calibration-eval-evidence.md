# Gate Calibration — Eval Evidence

Date: 2026-09-05
Skills changed: recorded per arm; see each section.
Scenarios: recorded per arm; see each section (evals repo).

## Why this note has arms

The gate changes in this plan all move one metric — Codex rounds to
convergence — so a single run cannot attribute a movement to a cause. Each
arm ships alone, with its own control and treatment runs.

## Baselines

Historical fleet (runs before the 6.13.0 release commit; gate-telemetry --all --until 2026-09-06T22:45:00-07:00):
- Rounds by gate — task: mean 2.24, first-round 129/469, backstops 7/469 [2, 1, 1, 1, 3, 3, 2, 1, 3, 1, 3, 2, 2, 2, 1, 2, 2, 2, 1, 2, 1, 2, 3, 1, 2, 3, 3, 2, 1, 2, 3, 2, 2, 2, 1, 1, 1, 2, 3, 2, 2, 1, 2, 1, 2, 1, 2, 3, 3, 1, 3, 3, 4, 3, 3, 1, 1, 1, 3, 3, 2, 1, 3, 3, 3, 3, 1, 1, 1, 2, 1, 1, 1, 1, 3, 2, 1, 3, 3, 3, 4, 1, 1, 1, 2, 2, 1, 1, 2, 3, 1, 2, 3, 2, 1, 2, 2, 3, 1, 2, 3, 1, 1, 2, 3, 2, 5, 1, 2, 2, 5, 3, 1, 2, 1, 1, 4, 1, 1, 2, 1, 2, 3, 2, 2, 2, 2, 3, 2, 2, 3, 2, 2, 1, 3, 3, 2, 2, 3, 3, 1, 1, 2, 2, 3, 1, 2, 3, 3, 1, 2, 1, 1, 1, 1, 1, 1, 2, 3, 3, 1, 7, 2, 2, 7, 4, 1, 3, 1, 2, 3, 3, 2, 3, 1, 1, 4, 3, 2, 7, 3, 2, 3, 6, 2, 2, 2, 2, 3, 4, 3, 3, 2, 3, 2, 4, 2, 2, 4, 4, 5, 2, 1, 1, 1, 3, 3, 1, 3, 2, 1, 2, 5, 5, 2, 5, 1, 2, 2, 3, 3, 3, 3, 2, 4, 3, 3, 2, 2, 5, 3, 2, 4, 4, 2, 3, 2, 1, 1, 1, 1, 1, 2, 3, 2, 2, 1, 3, 3, 2, 2, 2, 2, 2, 1, 2, 2, 4, 3, 2, 3, 2, 5, 3, 3, 3, 3, 3, 2, 4, 4, 1, 4, 2, 2, 5, 2, 2, 1, 1, 1, 3, 1, 3, 3, 2, 1, 3, 4, 1, 1, 3, 3, 4, 3, 1, 2, 2, 2, 3, 3, 1, 1, 2, 1, 1, 1, 2, 3, 1, 7, 3, 2, 2, 4, 2, 3, 2, 3, 3, 2, 5, 2, 4, 2, 1, 4, 1, 2, 1, 2, 1, 1, 3, 3, 2, 1, 1, 2, 2, 2, 2, 3, 1, 3, 1, 3, 1, 1, 3, 1, 2, 3, 3, 3, 3, 7, 3, 3, 1, 2, 2, 3, 3, 2, 2, 1, 2, 2, 3, 1, 2, 2, 1, 1, 3, 2, 1, 3, 3, 3, 2, 1, 1, 2, 2, 2, 3, 2, 2, 1, 2, 3, 1, 2, 1, 1, 2, 2, 2, 2, 2, 4, 2, 3, 1, 1, 2, 2, 2, 2, 1, 3, 2, 2, 2, 1, 1, 3, 2, 2, 2, 1, 1, 3, 2, 2, 3, 3, 6, 3, 3, 2, 3, 6, 3, 2, 1, 2, 2, 1, 1, 1, 5, 2, 2, 3, 1, 2, 2, 2, 2, 2, 3, 2, 2, 2, 1, 3, 1, 2, 3, 3, 3, 3, 2, 3, 2, 1]; final: mean 2, first-round 20/63, backstops 1/63 [2, 3, 3, 2, 2, 1, 2, 2, 2, 1, 1, 1, 1, 1, 2, 3, 1, 2, 4, 1, 1, 1, 3, 2, 1, 3, 1, 2, 3, 2, 1, 1, 1, 3, 3, 3, 2, 2, 3, 1, 2, 2, 2, 1, 2, 2, 3, 3, 2, 3, 2, 3, 3, 2, 1, 2, 2, 1, 2, 3, 1, 3, 3]; spec: mean 3.11, first-round 2/47, backstops 2/47 [2, 2, 4, 4, 3, 4, 3, 3, 1, 3, 3, 4, 2, 3, 2, 4, 4, 4, 3, 4, 4, 1, 7, 2, 2, 4, 2, 5, 5, 4, 3, 4, 3, 2, 2, 2, 2, 3, 2, 4, 2, 2, 4, 3, 4, 2, 4]; plan: mean 3.42, first-round 0/48, backstops 4/48 [4, 4, 2, 4, 3, 2, 2, 2, 4, 2, 4, 4, 3, 3, 3, 3, 3, 3, 2, 3, 4, 4, 4, 5, 4, 5, 4, 4, 5, 4, 4, 3, 4, 5, 2, 4, 3, 3, 4, 4, 4, 4, 2, 4, 3, 3, 3, 2]; adhoc: mean 2.19, first-round 8/21, backstops 2/21 [1, 1, 1, 1, 3, 3, 1, 1, 3, 3, 2, 1, 2, 3, 4, 1, 2, 4, 3, 4, 2]; unknown: mean 2.43, first-round 9/51, backstops 0/51 [2, 2, 3, 3, 2, 5, 6, 2, 5, 2, 2, 3, 2, 3, 2, 2, 2, 2, 1, 2, 2, 2, 2, 3, 1, 3, 2, 5, 2, 2, 2, 2, 2, 5, 2, 1, 4, 2, 5, 3, 2, 4, 1, 3, 1, 1, 2, 1, 2, 1, 1]

Post-release cohort (gate-telemetry --all --since 2026-09-06T22:45:00-07:00, read 2026-09-07):
- Rounds by gate — plan: mean 4, first-round 0/1, backstops 0/1 [4]; task: mean 1.5, first-round 1/2, backstops 0/2 [1, 2]; adhoc: mean 1, first-round 1/1, backstops 0/1 [1]; final: mean 1, first-round 1/1, backstops 0/1 [1]; spec: mean 4, first-round 0/2, backstops 0/2 [4, 4]

Disjointness verified: task gate historical 469 runs + cohort 2 runs = unbounded 471 runs.

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
### Arm A — severity calibration in the focus text

**Defect.** codex-plugin-cc's `prompts/adversarial-review.md` template wraps our focus text in a schema that enumerates severities (critical, high, medium, low, informational) without defining their scope, so the reviewer picks a severity with no anchor. Historical captures showed 30% of task-gate blocking runs carried nothing critical or high — the untested-branch finding was classified as high when it should have been medium, causing unnecessary rounds. The template is a plugin file a future version overwrites; the focus string is the only durable channel we own.

**Calibration.** Add three sentences to all three code-review focus strings in `skills/requesting-code-review/recipe-code.md` (per-task line 326, final whole-branch line 344, code-review-request line 354): "Severity is scoped to this diff: critical or high means a defect in the changed lines that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low." A contract assertion pins all three copies so none can drift apart.

**Method.** Direct Codex review of two fixture diffs, each reviewed three times under the control focus (today's recipe text) and three times under the treatment focus (with the calibration). This arm uses a direct reviewer run rather than a Quorum scenario because the harness seeds a stub Codex whose verdicts are canned — it cannot classify severity — and asserting the calibration phrase in the launch made the control fail by construction. Fixtures: **M** adds a branch nobody tested and contains no defect (the calibration says medium); **H** adds the same branch with a reachable crash (high under either focus, the guard that the calibration scopes severity rather than suppressing it). Each capture normalized by `verdict-normalize`.

**Reviewer.** gpt-5.6-sol at xhigh reasoning effort.

**Control arm results** (capture directory: `$TMPDIR/focus-arm/control/`):
- M control 1: approved
- M control 2: approved
- M control 3: approved
- H control 1: blocking
- H control 2: approved
- H control 3: approved

**Verdict.** The defect does not reproduce with this reviewer. Fixture M normalized `approved` in 3 of 3 control runs, meaning the untested-branch finding was not classified as high by this model configuration. Without the defect manifesting in the control, the calibration cannot be measured. Treatment arm not run.

**Files changed.** None (arm not applied).

**Commits.**
- evals repo: 0614bc7 arm: the code-gate focus text reviewed by real Codex, with and without a severity scope
