## Example Workflow

```
You: I'm using Subagent-Driven Development to execute this plan.

[Setup: worktree verified]
[Read plan file once: docs/hyperpowers/plans/feature-plan.md, and the spec its **Spec:** header names]
[Resolve workspace: scripts/sdd-dir docs/hyperpowers/plans/feature-plan.md — no ledger inside, fresh start]
[Ledger: # SDD ledger — plan: docs/hyperpowers/plans/feature-plan.md]
[Create todos for all tasks]

Task 1: Hook installation script (declared low)

[Run task-brief for Task 1; dispatch implementer with brief + report paths + context]
[Ledger: Task 1: implementer subagent-01f3 — recorded for fix-round resumes]

Implementer: "Before I begin - should the hook be installed at user or system level?"

You: "User level (~/.config/hyperpowers/hooks/)"

Implementer: [Later]
  - Implemented install-hook command
  - Added tests, 5/5 passing
  - Self-review: Found I missed --force flag, added it
  - Committed

[Re-run the covering command myself: 5/5 — matches the report]
[Run review-package PLAN_FILE BASE HEAD; dispatch task reviewer with the printed path]
Task reviewer: Spec ✅ - all requirements met, nothing extra.
  Strengths: Good test coverage, clean. Issues: None. Task quality: Approved.

[Effective tier still low, plan gate reviewed the plan, no trigger fired: record the tier-skip event, skip the Codex task gate]
[Ledger: Task 1: complete (commits a1b2c3d..d4e5f6a, review clean)]

Task 2: Recovery modes (declared standard)

[Run task-brief for Task 2; dispatch implementer with brief + report paths + context]
[Ledger: Task 2: implementer subagent-7c42 — recorded for fix-round resumes]

Implementer: [No questions]
  - Added verify/repair modes
  - 8/8 tests passing
  - Committed

[Run review-package PLAN_FILE BASE HEAD; dispatch task reviewer with the printed path]
Task reviewer: Spec ❌:
  - Missing: Progress reporting (spec says "report every 100 items")
  Issues (Important): Magic number (100)

[Fix round 1: resume the implementer with both findings]
Implementer: Added progress reporting, extracted PROGRESS_INTERVAL constant.
  Re-ran test/recovery.test.js — 10/10 passing. Fix report appended.

[Run review-package PLAN_FILE FIX_BASE HEAD; dispatch scoped re-review]
Re-reviewer: Missing progress reporting — ADDRESSED (src/recovery.js:41).
  Magic number — ADDRESSED (src/recovery.js:7). New breakage: none.
  Verdict: all findings addressed.

[Ledger: Task 2: fix round 1/5 (2 addressed, 0 open; commits d4e5f6a..b7c8d9e)]
[Codex per-task gate over d4e5f6a..b7c8d9e — approved; that would have been round 2 of the same five]
[Ledger: Task 2: complete (commits d4e5f6a..b7c8d9e, review clean)]

...

[After all tasks]
[Run review-package PLAN_FILE MERGE_BASE HEAD; dispatch final code-reviewer, most capable model]
Final reviewer: All requirements met. Deferred minors triaged: none block merge.
[Codex final code gate over the branch range — approved]

[Delete this plan's workspace — the record now lives in git]

Done! Using hyperpowers:finishing-a-development-branch.
```
