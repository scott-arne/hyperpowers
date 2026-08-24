## Risk Tiers (per-task Codex gate applicability)

Each plan task declares `**Risk tier:** low|standard|high — <rationale>`
under its heading; the task brief carries it. The effective tier starts as
the declared tier. You may raise a tier at any point — never lower a
declared tier, whatever the schedule pressure. Escalation triggers (any
one): DONE_WITH_CONCERNS with correctness doubts; any fix cycle (a
reviewer-driven fix that changes files — including a ⚠️-item resolution —
is a fix cycle); files touched outside the plan's Files list; anything on
the high rubric surfacing mid-task (approval-authority code —
verdict-normalize, gate-round, ungated-ledger, or any script whose output
other machinery trusts — concurrency/locking, security surfaces,
destructive git operations, durable-record writers; writing-plans' Risk
Tier Rubric is the authoritative list). Raise to high iff the trigger
itself is a high-rubric criterion; otherwise standard. Record every
escalation or fallback as one progress-ledger line:
`Task N: tier declared <low|standard|high|none> -> effective <standard|high> (<trigger phrase>)`.
A missing or unparseable tier line is `declared none -> effective standard
(missing tier line)` — full train, fail-closed.

The tier changes exactly one thing: an EFFECTIVE-LOW task — no escalation
trigger fired at any point — skips the per-task Codex gate after the task
reviewer approves. A low tier is honored only if the plan's Codex gate
actually reviewed the plan; when that gate was skipped or degraded, or its
outcome is unknown (no plan-gate evidence available), unreviewed low tiers
execute as standard (full train), recorded with the ledger line shape as
`(unreviewed low tier)`. When the skip IS permitted — effective-low, plan-gate-reviewed, no trigger fired — record it immediately (a demoted task runs the full train and records NO tier-skip event):
`bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class tier-skip --gate task --base <TASK_BASE> --head <HEAD> --tier-declared low --tier-effective low --note "Task N: <rationale>"`.
Standard and high tiers run today's full train unchanged; so does every
non-SDD review. The Claude task reviewer always runs.

When any task skipped, write `tier-skips.md` in this plan's workspace — one
line per skip: `Task N: <rationale> (<base>..<head>)` — and hand its path
to the final code-reviewer dispatch (beside the Minor-findings list) and
to the final Codex gate as `<TIER_SKIPS_PATH>` plus a dossier
`--adjudications` input, per the gate doc's final recipe.
