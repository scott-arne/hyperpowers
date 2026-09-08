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

**Defect.** codex-plugin-cc's `prompts/adversarial-review.md` template wraps our focus text in a schema that enumerates severities (critical, high, medium, low, informational) without defining their scope, so the reviewer picks a severity with no anchor. Historical captures showed 30% of task-gate blocking runs carried nothing critical or high — findings were over-classified (untested branches called high) or under-classified (genuine defects called medium). The template is a plugin file a future version overwrites; the focus string is the only durable channel we own.

**Calibration.** Three sentences added to all three code-review focus strings in `skills/requesting-code-review/recipe-code.md` (per-task source line 326, final whole-branch line 344, code-review-request line 354): "Severity is scoped to what this diff causes: critical or high means a defect the change introduces — in its changed lines, in an unchanged caller it breaks, or in a requirement it was asked to meet and omits — that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low." A contract assertion in `test-gate-contract.sh` pins all three copies (checking the complete three-sentence text with `grep -F -c`) so none can drift apart. The lens-composition clause in `gate-lenses.md:214` was amended to require lens focuses carry "the code recipe's complete adversarial-review focus string for that gate type — its context paths and its severity calibration sentences, verbatim from recipe-code.md; a lens focus that carries the paths without the calibration is the defect this clause exists to prevent."

**Method.** Direct Codex review of fixture diffs, each reviewed three times per arm and normalized by `verdict-normalize`. This arm uses a direct reviewer run rather than a Quorum scenario because the harness seeds a stub Codex whose verdicts are canned — it cannot classify severity — and asserting the calibration phrase in the launch made the control fail by construction.

**Task 2's Codex gate.** After the first implementation (round 1), this task's own three-lens code gate returned four blocking findings and one medium. The human partner amended the spec's D7 and the Part 2 success criteria on 2026-09-07: the arm is judged on classification accuracy over the production round-1 prompt shape. Key findings: (1) round-1 code reviews never received the calibration because the lens-composition clause said only "context paths the code recipes already require," not the complete focus string; (2) the calibration's "in the changed lines" scope excluded wholly omitted requirements and failures at unchanged consumers; (3) fixture M's % branch turned `"%"` and whitespace-only inputs from NaN into 0, so it was not defect-free; (4) measurement must use the production round-1 focus shape (lens skeleton + recipe focus) for both arms; (5) the contract assertion counted only the opening phrase, not the complete calibration text.

**Prompt shape.** Round 2 measured the production round-1 focus: the correctness lens skeleton (dossier line, charter, exhaustiveness demand, required Coverage section) followed by the per-task recipe's complete adversarial-review focus string. Control = the original recipe text without calibration (from commit b015394, recipe-code.md line 53); treatment = with the reworded calibration.

**Fixtures (round 2).** **M**: defect-free implementation of the percent-string branch (trim and NaN on empty body, as required). **H**: crash-and-wrong-result defect (unanchored regex returns wrong values for `-25%`, `.5%`, `1e2%`, and throws on `"%"`). **O**: omitted requirement (parseRate is correct but formatRate is missing, a requirement the task was asked to meet and omits).

**Reviewer.** gpt-5.6-sol at xhigh reasoning effort.

**Decision rule (as amended 2026-09-07 with D7).** The arm wins if treatment H and treatment O each block 3 of 3 AND treatment M is approved in at least 2 of 3; control numbers are recorded beside them.

**Round 2 control arm results** (capture directory: `$TMPDIR/focus-arm-r2/control/`):
- M control 1: approved
- M control 2: approved
- M control 3: approved
- H control 1: blocking
- H control 2: approved (defect found, rated non-blocking)
- H control 3: approved (defect found, rated non-blocking)
- O control 1: blocking
- O control 2: blocking
- O control 3: blocking

**Round 2 treatment arm results** (capture directory: `$TMPDIR/focus-arm-r2/treatment/`):
- M treatment 1: approved
- M treatment 2: approved
- M treatment 3: approved
- H treatment 1: blocking
- H treatment 2: blocking
- H treatment 3: blocking
- O treatment 1: blocking
- O treatment 2: blocking
- O treatment 3: blocking

**Verdict (round 2).** The arm wins. Treatment H blocked 3 of 3 (vs. control H 1 of 3), treatment O blocked 3 of 3 (vs. control O 3 of 3, no change because the omitted-requirement defect was already classified correctly under control), and treatment M approved 3 of 3 (vs. control M 3 of 3, the guard that calibration must not introduce false positives on defect-free implementations). The calibration lifted the crash-and-wrong-result defect (H) from blocking in 1 of 3 to blocking in 3 of 3, achieving consistency in classification while maintaining clean approvals for the defect-free fixture.

**Round 1 results (historical, non-production prompt shape).** Round 1 measured a bare recipe focus (no lens skeleton) on two fixtures (M with the NaN defect, H with the crash) using the original calibration wording ("in the changed lines" instead of "what this diff causes"). Control arm (capture directory: `$TMPDIR/focus-arm/control/`): M 3/3 approved, H 1/3 blocking (all three found the defect, one rated high, two rated medium). Treatment arm (capture directory: `$TMPDIR/focus-arm/treatment/`): M 2/3 approved + 1/3 blocking, H 3/3 blocking. Those numbers informed the round 2 design but do not decide the arm because the prompt shape did not match production.

**Files changed.**
- `skills/requesting-code-review/recipe-code.md` (three focus strings at source lines 326, 330, 344, 354, with reworded calibration)
- `skills/requesting-code-review/gate-lenses.md` (line 214: lens-composition clause amended to require calibration in lens focuses)
- `tests/codex-review-gate/gate-post-split-edits.tsv` (five rows: four updated for 326/330/344/354, one new for 214)
- `tests/codex-review-gate/test-gate-split-lossless.sh` (pin raised from 10 to 15)
- `tests/codex-review-gate/test-gate-contract.sh` (assertion checks complete three-sentence calibration text occurs exactly 3 times)

**Commits.**
- evals repo (round 1 fixtures and runner): 0614bc7 arm: the code-gate focus text reviewed by real Codex, with and without a severity scope
- evals repo (round 2 fixtures and runner): 6bfce16 arm: production round-1 focus shape (lens + recipe) on M (fixed), H, and O (omitted requirement)
- hyperpowers repo: (this commit)
