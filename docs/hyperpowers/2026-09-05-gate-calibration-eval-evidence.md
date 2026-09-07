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
