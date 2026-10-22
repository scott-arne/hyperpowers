# Decision records: evidence

**Spec:** docs/hyperpowers/specs/2026-10-21-decision-records-design.md
**Plan:** docs/hyperpowers/plans/2026-10-21-decision-records.md
**Compiler:** skills/finishing-a-development-branch/scripts/decisions-compile at 5f82cb9 (Task 6's d076e53 plus the Task 12 correction: `title_of` reads the item's first paragraph joined across lines)

## 1. Parser dry run over this repository's specs

Run on 2026-10-22 from the worktree, `decisions-compile --dry-run` over each
file in `docs/hyperpowers/specs/`. The spec predicted 12 parses among the 24
specs that existed when it was written (4 prose-only Decisions sections, 8
specs without one) plus its own.

| Spec | Exit | Items | Titles |
|---|---|---|---|
| 2026-06-17-codex-plugin-cc-required-dependency-design.md | 0 | 6 | Trigger = call the companion script directly; Gate behavior = fix-loop, then summarize; Scope = spec + plan + code, including per-task code review; Relationship to Codex's Stop gate = independent;  document overlap; Absent-Codex behavior = run as today + warning; Claude Code only |
| 2026-06-30-codex-review-gate-convergence-design.md | 2 | 0 | docs/hyperpowers/specs/2026-06-30-codex-review-gate-convergence-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-07-09-performance-optimization-design.md | 2 | 0 | docs/hyperpowers/specs/2026-07-09-performance-optimization-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-07-10-codex-design-collaboration-design.md | 2 | 0 | docs/hyperpowers/specs/2026-07-10-codex-design-collaboration-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-07-22-gate-reliability-hardening-design.md | 2 | 0 | docs/hyperpowers/specs/2026-07-22-gate-reliability-hardening-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-07-23-gate-resilience-telemetry-design.md | 2 | 0 | docs/hyperpowers/specs/2026-07-23-gate-resilience-telemetry-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-08-08-review-fidelity-efficiency-design.md | 2 | 0 | docs/hyperpowers/specs/2026-08-08-review-fidelity-efficiency-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-08-09-risk-tiering-prompt-hygiene-design.md | 0 | 6 | One spec, one release (6.6.0), four items; Tier assignment is plan-time, Codex-plan-gate-reviewed, escalate-only at; Tiering dials ONLY the per-task Codex gate; `verification-before-completion` is fully removed, its load-bearing content; Prompt hygiene = fixer template + SDD contract-test suite + the; Two live eval scenarios |
| 2026-08-17-upstream-sync-design.md | 0 | 7 | Scope; SDD merge depth; Codex gate meshing; Router × approach gate; Eval posture; Packaging; Merge strategy |
| 2026-08-23-skills-read-efficiency-design.md | 2 | 0 | docs/hyperpowers/specs/2026-08-23-skills-read-efficiency-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-05-gate-churn-and-skill-hardening-design.md | 2 | 0 | docs/hyperpowers/specs/2026-09-05-gate-churn-and-skill-hardening-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-10-external-workflow-adoption-design.md | 2 | 0 | docs/hyperpowers/specs/2026-09-10-external-workflow-adoption-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-16-brainstorming-trigger-calibration-design.md | 2 | 0 | docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-17-brainstorming-trigger-rule-design.md | 0 | 4 | Scope; Boundary bar; Approach; Standing preference, verbatim |
| 2026-09-17-first-edit-interlock-design.md | 0 | 5 | Bar; Arms; Mechanism; Scenarios; Standing preference, verbatim |
| 2026-09-23-adoption-remediation-design.md | 0 | 9 | Model; Sample size; Criterion 1 for the ladder; Install; Phase 3's baseline *is* the ladder-without-hook measurement; The two new scenarios get their own two-arm runs in Phase 5, control at `main`; The interlock's spec, plan and evidence note stay committed, per this repo's; The release decision is the human partner's, at the end of Phase 5;  the plan; Evidence directory, named before the first run |
| 2026-10-03-review-calibration-and-sentinel-scope-design.md | 0 | 4 | Fix 1 reach: the Codex focus strings only; Fix 1 form: an added sentence; Fix 2 home: the evals authoring guide plus a hyperpowers pointer; Fix 3 scope: the table update |
| 2026-10-05-release-hygiene-design.md | 0 | 4 | Scope; Leak-scan tool home (item 12); Task-less stubs (item 15); Fixture P3 (item 17) |
| 2026-10-10-post-release-follow-ups-design.md | 0 | 9 | Decomposition; Here-strings; Image identity; Dashboard; Shared stub; Shim parser; gate-telemetry; Organization; Shim operands built from the shim's location |
| 2026-10-13-agent-write-isolation-design.md | 0 | 6 | Threat model: adversarial capability; Mechanism: privilege separation; Scope: container only; Failure is fatal; Verification; One plan across the three repositories |
| 2026-10-13-agent-write-isolation-gate-ledger.md | 0 | 7 | Threat model: adversarial capability; Both environments; Mechanism: privilege separation; Failure is fatal; No host fallback; Verification; One plan across the three repositories |
| 2026-10-14-agent-write-isolation-relocation-design.md | 0 | 5 | Threat model: careless; Move the workspace, not the record; No digest seal; Verification; One repository |
| 2026-10-19-sdd-turn-liveness-design.md | 0 | 3 | Scope: turn-ending rules plus foreground waits; Evidence: a controlled scenario, then a field rerun; Mechanism: skill text |
| 2026-10-20-portable-sdd-dossiers-design.md | 0 | 4 | Git is the transport; The parallel model to serve first is one controller session per parallel task,; The dossier's durable home is a dedicated state branch of the same repository,; The four design sections were approved as presented in chat |
| 2026-10-21-decision-records-design.md | 0 | 12 | One file per decision; Records are extracted at finish only, and the spec's Decisions section is required; The plan is removed from the tree at finish; The spec stays, frozen from the records commit on, with one Outcome line; The same rule applies in this repository; Skeleton plus delta; The delta runs inside existing waits and is never waited for; Names carry a date and a slug;  there is no global counter; The records directory derives from the spec's location; Records are mandatory for a branch that has a spec, and the compiler is the only writer; Evidence bar: offline tests, a parser dry run over real specs, and the first live SDD run; The serial cost is the compiler and one commit, after the suite;  the human review rides the finishing menu |

Result: 15 parsed, 10 exit 2. The prediction was 13 parses and 12 exit 2.
The difference is the heading rule, which admits any level-two heading whose
text contains `decision`: `## Decisions (locked with maintainer)`
(codex-plugin-cc), `## Locked Decisions` (upstream-sync), `## 2. Locked
decisions (from brainstorming)` (risk-tiering), and `## Decisions taken with
the human partner` (brainstorming-trigger-rule, first-edit-interlock,
agent-write-isolation, its relocation spec, portable-sdd-dossiers) all parse,
as does the gate-ledger file, which is not a design spec but sits in `specs/`.
Of the 10 exit-2 specs, 6 have no decisions heading at all
(codex-review-gate-convergence, gate-reliability-hardening,
gate-resilience-telemetry, review-fidelity-efficiency, skills-read-efficiency,
brainstorming-trigger-calibration) and 4 have a heading with prose only
(performance-optimization and codex-design-collaboration under `## Key
decisions (resolved during brainstorming)`, gate-churn-and-skill-hardening and
external-workflow-adoption under `## Decisions`). The compiler prints the same
message for both cases, so the split was read from the headings in the specs.

The table script joins titles with `; `, so a title that itself contains a
semicolon displays as two entries. Affected: codex-plugin-cc ("independent;
document overlap"), adoption-remediation ("at the end of Phase 5; the plan"),
and two in decision-records-design ("a slug; there is no global counter",
"after the suite; the human review rides the finishing menu").

Title judgement. Every title names its decision except these, accepted as
borderline. Plain items with no clause break are cut at a word boundary near
80 characters and read as clipped phrases (risk-tiering items 2, 4, 5;
adoption-remediation's "per this repo's"; portable-sdd-dossiers items 2 and 3
ending in a comma); each is still recognisable from its words and the record
body carries the full text. Short author-chosen titles such as "Scope",
"Verification" and "Standing preference, verbatim" are recognisable with the
spec beside them. portable-sdd-dossiers item 4, "The four design sections were
approved as presented in chat", is a status note rather than a decision; it is
spec content, and the rule is that the spec is never edited to fit the
parser, so it is accepted as is. The tree was clean after the run.

## 2. Finishing-path rehearsal

(Task 13 appends this section.)

## 3. SDD-path rehearsal

(Task 14 appends this section.)

## 4. Post-landing checks still owed

The spec's Live section also asks for one session in Zed, which only the
human partner can run; record it here with the branch, the records commit,
and whether the background dispatch was collected.
