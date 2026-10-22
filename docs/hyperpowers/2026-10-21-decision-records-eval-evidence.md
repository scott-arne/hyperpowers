# Decision records: evidence

**Spec:** docs/hyperpowers/specs/2026-10-21-decision-records-design.md
**Plan:** docs/hyperpowers/plans/2026-10-21-decision-records.md
**Compiler:** skills/finishing-a-development-branch/scripts/decisions-compile at 56bb8ac (Task 6's d076e53 plus the Task 12 corrections: the title comes from the item's first paragraph, 5f82cb9; trailing punctuation is dropped, cfa5047; a long clause is cut at its last clause boundary and never inside a token, 56bb8ac)

## 1. Parser dry run over this repository's specs

Run on 2026-10-22 from the worktree at 56bb8ac, `decisions-compile --dry-run`
over each
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
| 2026-08-09-risk-tiering-prompt-hygiene-design.md | 0 | 6 | One spec, one release (6.6.0), four items; Tier assignment is plan-time, Codex-plan-gate-reviewed; Tiering dials ONLY the per-task Codex gate; `verification-before-completion` is fully removed; Prompt hygiene = fixer template + SDD contract-test suite + the; Two live eval scenarios |
| 2026-08-17-upstream-sync-design.md | 0 | 7 | Scope; SDD merge depth; Codex gate meshing; Router × approach gate; Eval posture; Packaging; Merge strategy |
| 2026-08-23-skills-read-efficiency-design.md | 2 | 0 | docs/hyperpowers/specs/2026-08-23-skills-read-efficiency-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-05-gate-churn-and-skill-hardening-design.md | 2 | 0 | docs/hyperpowers/specs/2026-09-05-gate-churn-and-skill-hardening-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-10-external-workflow-adoption-design.md | 2 | 0 | docs/hyperpowers/specs/2026-09-10-external-workflow-adoption-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-16-brainstorming-trigger-calibration-design.md | 2 | 0 | docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md: no decisions list (add "## Decisions" with one list item per decision) |
| 2026-09-17-brainstorming-trigger-rule-design.md | 0 | 4 | Scope; Boundary bar; Approach; Standing preference, verbatim |
| 2026-09-17-first-edit-interlock-design.md | 0 | 5 | Bar; Arms; Mechanism; Scenarios; Standing preference, verbatim |
| 2026-09-23-adoption-remediation-design.md | 0 | 9 | Model; Sample size; Criterion 1 for the ladder; Install; Phase 3's baseline *is* the ladder-without-hook measurement; The two new scenarios get their own two-arm runs in Phase 5; The interlock's spec, plan and evidence note stay committed; The release decision is the human partner's, at the end of Phase 5; Evidence directory, named before the first run |
| 2026-10-03-review-calibration-and-sentinel-scope-design.md | 0 | 4 | Fix 1 reach: the Codex focus strings only; Fix 1 form: an added sentence; Fix 2 home: the evals authoring guide plus a hyperpowers pointer; Fix 3 scope: the table update |
| 2026-10-05-release-hygiene-design.md | 0 | 4 | Scope; Leak-scan tool home (item 12); Task-less stubs (item 15); Fixture P3 (item 17) |
| 2026-10-10-post-release-follow-ups-design.md | 0 | 9 | Decomposition; Here-strings; Image identity; Dashboard; Shared stub; Shim parser; gate-telemetry; Organization; Shim operands built from the shim's location |
| 2026-10-13-agent-write-isolation-design.md | 0 | 6 | Threat model: adversarial capability; Mechanism: privilege separation; Scope: container only; Failure is fatal; Verification; One plan across the three repositories |
| 2026-10-13-agent-write-isolation-gate-ledger.md | 0 | 7 | Threat model: adversarial capability; Both environments; Mechanism: privilege separation; Failure is fatal; No host fallback; Verification; One plan across the three repositories |
| 2026-10-14-agent-write-isolation-relocation-design.md | 0 | 5 | Threat model: careless; Move the workspace, not the record; No digest seal; Verification; One repository |
| 2026-10-19-sdd-turn-liveness-design.md | 0 | 3 | Scope: turn-ending rules plus foreground waits; Evidence: a controlled scenario, then a field rerun; Mechanism: skill text |
| 2026-10-20-portable-sdd-dossiers-design.md | 0 | 4 | Git is the transport; The parallel model to serve first is one controller session per parallel task; The dossier's durable home is a dedicated state branch of the same repository; The four design sections were approved as presented in chat |
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
document overlap") and two in decision-records-design ("a slug; there is no
global counter", "after the suite; the human review rides the finishing
menu").

Title judgement. Every title names its decision except one, accepted as the
rule's limit. A plain item is cut at its last clause boundary inside 80
characters, and three titles that earlier rules left as fragments now read
whole: risk-tiering's "Tier assignment is plan-time, Codex-plan-gate-reviewed,
escalate-only at" is "Tier assignment is plan-time, Codex-plan-gate-reviewed",
"`verification-before-completion` is fully removed, its load-bearing content"
is "`verification-before-completion` is fully removed", and
adoption-remediation's "The interlock's spec, plan and evidence note stay
committed, per this repo's" is "The interlock's spec, plan and evidence note
stay committed". One legacy title remains a fragment, "Prompt hygiene = fixer
template + SDD contract-test suite + the", because no clause boundary falls
inside its first 80 characters; the human partner accepted it, at the Codex
gate, as the 80-character rule's limit for a legacy plain item, and the record
body carries the full text. The brainstorming skill now requires bold titles,
so the plain path serves legacy material only. The comma that ended
portable-sdd-dossiers items 2 and 3 was a compiler defect, fixed in cfa5047.
Short author-chosen titles such as "Scope", "Verification" and "Standing
preference, verbatim" are recognisable with the spec beside them.
portable-sdd-dossiers item 4, "The four design sections were approved as
presented in chat", is a status note rather than a decision; it is spec
content, and the rule is that the spec is never edited to fit the parser, so
the human partner accepted it as is, by a decision at the same gate. The
plan's Task 12 acceptance criterion was amended by a dated correction to
match. The tree was clean after the run.

## 2. Finishing-path rehearsal

Two print-mode Claude Code sessions (model claude-opus-5-5, CC 2.1.302)
against a fixture branch with a two-decision spec and a plan, the
decision-records worktree loaded with `--plugin-dir`, an empty config dir.
Artifacts: `evidence/2026-10-21-decision-records/task-13-runs/` in
hyperpowers-evals (commit pending in hyperpowers-evals).

| Run | Suite | Extractor at collection | Records staged | Plan deletion staged | Menu message carried the diff | Notes applied | Records commit after "3" | Suite end to menu | Answer to commit |
|---|---|---|---|---|---|---|---|---|---|
| fast | instant | finished (stop path not exercised) | yes | yes | yes | yes | e67f0d7 (fixture repo) | 31 s | 25 s |
| slow | 150 s | finished | yes | yes | yes | yes | 38213d3 (fixture repo) | 31 s | 25 s |
| fast2 (extra re-run of fast) | instant | finished, TaskStop sent a second too late | yes | yes | no, summarised | yes | 75e674c (fixture repo) | 28 s | 20 s |
| stop (ancestor CLAUDE.md excluded) | instant, 5,000-line diff | stopped unfinished (TaskStop seen) | yes | yes | yes | no (Nothing recorded.) | 237e440 (fixture repo) | 27 s | 15 s |

Intervals: suite end to menu is the suite's tool result (fast, fast2) or its
completion event (slow, where the suite outran the Bash 120 s timeout and the
tool result at 69 s before the menu was only the moved-to-background notice);
answer to commit runs from the turn-2 start, read at one-second resolution, to
the records commit's `%cI`. The fast runs leave the extractor too little to do
for the stop to be reproducible: it wrote its notes within about seven seconds
of dispatch, before the instant suite's result, in `fast`; in `fast2` the
session found no notes file at collection, called TaskStop, and the extractor
completed in the same second, so TaskStop answered "not running". The instant-suite premise failed
because the fixture's diff is a few lines, which a Sonnet extractor reads and
summarises in seconds. The `stop` run pads the implementation commit with a
5,000-line `data/sample.txt` (`PAD_LINES=5000` in `run-finishing.sh`, the
device Task 14's brief prescribes for the same purpose), and the extractor was
still running when the suite returned: the session found no notes file, said
so, called TaskStop after the suite's result, and got "Successfully stopped";
the agent's only notification has status "stopped" and follows the call. Both
records read "Nothing recorded." under what implementation changed, the
hand-back says the extractor was stopped and the records have no notes, and
the menu message opened with the complete diff. The stop at collection is
demonstrated by that run alone.

Beyond the skill text: in `fast2` the menu message summarised the staged diff
in four bullets instead of opening with it, a deviation from Step 4 (the
diff was read in a tool result, not shown to the human partner). In `slow` the
extractor reported three undocumented decisions, the menu put them to the
human partner, and after the bare answer "3" the session committed the records
without them and said so; Step 4 does not cover an unanswered proposal. The
three earlier runs (fast, slow, fast2) behaved as if the host user-level
CLAUDE.md were loaded despite the empty config dir: turn 2 ran the host leak
scan (a Bash call containing `realval-scan`) and the hand-backs cite a
Co-Authored-By rule from it. The `stop` run's config dir carried a
`claudeMdExcludes` list covering every ancestor's CLAUDE.md and AGENTS.md
(built as quorum builds it), and both signs are absent there: no Bash call
containing `realval-scan`, no assistant text mentioning Co-Authored-By. Its
turn-2 commit command did append Claude Code's built-in attribution trailer,
which the host rule had suppressed in the earlier runs.

## 3. SDD-path rehearsal

(Task 14 appends this section.)

## 4. Post-landing checks still owed

The spec's Live section also asks for one session in Zed, which only the
human partner can run; record it here with the branch, the records commit,
and whether the background dispatch was collected.
