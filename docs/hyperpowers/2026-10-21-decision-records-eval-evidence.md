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

Six print-mode Claude Code sessions (model claude-opus-5-5, CC 2.1.302):
the two planned runs, an extra re-run of the fast one, a padded run, and two
clean runs against the amended Step 4 that ran three turns; each against a
fixture branch with a two-decision spec and a plan, the decision-records
worktree loaded with `--plugin-dir`, and an empty config dir, which in the
`stop`, `slow-clean` and `slow-clean2` runs also carries a `claudeMdExcludes`
list. Artifacts: `evidence/2026-10-21-decision-records/task-13-runs/` in
hyperpowers-evals (commit b80b7ee4d for the first four runs; commit 8c9ea74e9 for
`slow-clean`, `slow-clean2`, the manifest `runs.md` and the launcher
changes).

| Run | Suite | Extractor at collection | Records staged | Plan deletion staged | Menu message carried the diff | Notes applied | Records commit after "3" | Suite end to menu | Answer to commit |
|---|---|---|---|---|---|---|---|---|---|---|
| fast | instant | finished (stop path not exercised) | yes | yes | yes | yes | e67f0d7 (fixture repo) | 31 s | 25 s |
| slow | 150 s | finished | yes | yes | yes | yes | 38213d3 (fixture repo) | 31 s | 25 s |
| fast2 (extra re-run of fast) | instant | finished, TaskStop sent in the same second | yes | yes | no, summarised | yes | 75e674c (fixture repo) | 28 s | 20 s |
| stop (ancestor CLAUDE.md excluded) | instant, 5,000-line diff | stopped unfinished (TaskStop seen) | yes | yes | yes | no (Nothing recorded.) | 237e440 (fixture repo) | 27 s | 15 s |
| slow-clean (amended Step 4, three turns) | 150 s | finished | yes | yes | yes, literal `diff --git` output | yes | fc91297 (fixture repo; no proposals were open, so the commit came at turn 2, as before) | 28 s | 21 s |
| slow-clean2 (amended Step 4, three turns) | 150 s, undocumented choice in the diff | finished | yes | yes | yes, literal `diff --git` output | yes | 2666c4d (fixture repo; followed the dispositions at turn 3, no commit at turn 2) | 32 s (suite completion event) | 17 s from the turn-3 start |

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

Step 4 was amended after these runs, with three additions, each forced by one
observation. The bare "3" in `slow`, which committed with three proposals
unanswered, forced the rule that an answer naming an option but leaving a
proposal without a disposition is incomplete: ask and wait, write and commit
nothing. The summary in `fast2` forced the sentence that the message carries
the diff command's output verbatim and that no option is accepted until the
diff has been shown. The `Co-Authored-By` trailer in `stop` forced the line
that the records commit message is one line, with no second `-m`, no trailer
and no attribution. The `slow-clean` run (the amended skill, ancestor
CLAUDE.md excluded, a 150 s suite, three turns) showed two of the three: the
turn-1 menu message contained the literal `diff --git` lines for the two
records, the README, the spec and the plan, and the records commit body is
exactly the one subject line. It did not show the first: the extractor
proposed no undocumented decisions this time (the compile output reports
`undocumented 0`), so the bare "3" committed directly and the third turn,
"Dismiss all of them.", met nothing to dismiss; the session said so and
changed nothing. The unanswered-proposal rule is therefore untested in that
run; the extractor's proposals vary run to run. The `slow-clean2` run, whose
launcher option `UNDOCUMENTED=1` adds a case-insensitive tag match the spec
does not mention, exercised it: the extractor proposed four undocumented
decisions, the menu asked add or dismiss for each, the bare "3" drew a
question for the dispositions and no commit, and "Dismiss all of them." drew
the one-line-subject records commit with the four dismissals listed in the
hand-back. Its turn 1 hit the 1200 s timeout (exit 124) after emitting its
result, a hung process rather than a failed turn. The launcher gained
`EXCLUDE_ANCESTORS` (default 1; 0 skips the settings file), an optional third
turn from `prompt-3.txt`, `PAD_LINES`, `UNDOCUMENTED`, and a `config:` first
line in status.txt; `runs.md` in `task-13-runs/` lists every run with its
command and configuration. `fast`, `slow` and `fast2` ran before the
parameter existed, without ancestor excludes (the host CLAUDE.md loaded);
`stop`, `slow-clean` and `slow-clean2` wrote them.

## 3. SDD-path rehearsal

Six counted print-mode Claude Code sessions (model claude-opus-5-5, CC
2.1.302) executing a one-task plan in the fixture with the decision-records
worktree as the plugin (HEAD 3f9aca9 for `slow`, `fast` and `fast2`; HEAD
2db0cf0, which adds the SDD text's ledger sentence, for `stop`, `stop2` and `stop3`). Every session
ran with `XDG_CACHE_HOME` set to a per-run directory (so the SDD workspace,
ledger and review dirs are visible), `HYPERPOWERS_PLUGINS_FILE=/nonexistent`
(the Codex preflight finds no plugin, so the gates degrade) and the
`claudeMdExcludes` file for every ancestor of the working copy. Artifacts:
`evidence/2026-10-21-decision-records/task-14-runs/` in hyperpowers-evals
(commit 5d7c69311 for `slow`, `fast`, `fast2` and the void attempts; commit
060e7a33d for `stop`, `stop2`, `stop3`, the delay hook, the launcher's
`EXTRACTOR_DELAY` parameter and the manifest).

| Check | slow (120 s suite) | fast (instant suite) | fast2 (instant, 10,000-line padding) | stop (instant, extractor delayed 180 s by a Read hook) | stop2 (instant, hook revised to Read, Bash and Grep for subagents) | stop3 (instant, extractor's notes Write delayed 240 s by a hook) |
|---|---|---|---|---|---|---|
| dry run at Setup | yes | yes | yes | yes | yes | yes |
| extractor dispatched after the final review, in the background | yes | yes | yes | yes | yes | yes |
| `Decision extractor:` ledger line written | yes | no | yes | yes (the call right after the dispatch) | yes (the call right after the dispatch) | yes (the call right after the dispatch) |
| workspace deleted while the extractor ran | yes (listing: the repo key dir; `plans/` under it empty on disk) | yes (same listing) | yes (same listing) | yes (same listing; deleted 6 s after the dispatch) | yes (same listing; deleted 6 s after the dispatch) | yes (same listing; deleted 5 s after the dispatch) |
| extractor at collection | finished | finished (no TaskStop) | finished (no TaskStop) | stopped unfinished (TaskStop seen, notification status `stopped`) | finished (no TaskStop); the hook delayed the two reviewers, not the extractor | stopped unfinished (TaskStop seen, notification status `stopped`) |
| compile after the suite, records and plan deletion staged | yes | yes | yes | yes | yes | yes |
| menu message carried the diff | yes | yes | yes | yes | yes | yes |
| notes applied | yes (two undocumented proposals) | yes (three proposals) | yes (three proposals) | no (Nothing recorded.) | yes (three proposals) | no (Nothing recorded.) |
| turn 2 ("3") asked and did not commit | yes | yes | yes | not applicable: no proposals, "3" committed | yes | not applicable: no proposals, "3" committed |
| records commit | 42ab9f5 (turn 3) | d7ebf3b (turn 3) | 835ac8f (turn 3) | f1773a8 (turn 2) | af9e6d9 (turn 3) | c9d2d10 (turn 2) |
| suite result to menu | 52.6 s | 35.7 s (compound call) | 38.4 s (compound call) | 30.6 s (compound call) | 37.2 s (compound call) | 41.5 s (single call) |
| answer to commit | 23 s (turn 3) | 20 s (turn 3) | 22 s (turn 3) | 10 s (turn 2) | 13 s (turn 3) | 8 s (turn 2) |

The stopped-unfinished path was reached in `stop`, in the SDD-specific order
the transcript timestamps give: dispatch 00:37:41Z, the `Decision extractor:`
ledger line and the workspace `rm -rf` in the next call (00:37:48Z), suite
result 00:37:57Z (15 s after the dispatch), `TaskStop` 00:38:01Z, compile
00:38:06Z, hand-back 00:38:27Z. No completion notification for the extractor
came before the `TaskStop`; its notification carried status `stopped`; both
records read `Nothing recorded.`; the hand-back said the decision-notes agent
was stopped before it finished and the records were compiled without notes;
the menu carried the literal `diff --git` lines for both records, the README,
the spec and the plan; the records commit body is one line. It was a race, not
the delay: the first hook, on Read only, never fired, because the extractor
read the package with Bash `cat`; the extractor wrote its notes file at
00:37:59Z, 2 s before the `TaskStop`, and was stopped before its final message.
The review package's size did not hold the extractor open in `fast` and `fast2`
either: its completion notification follows the suite call and precedes the
compile call there (the suite's result came 18 s and 21 s after the dispatch;
notification lines carry no timestamp), at both paddings.
`stop2` revised the hook to match Read, Bash and Grep, only on a subagent's
payload, and to log each delay. The log shows two delays of 180 s, for the task
reviewer and the final reviewer, and none for the extractor: it reached the
package through a shell variable and a glob, so the literal package name never
appeared in its tool input, and it finished before collection (notes written
00:52:22Z, completion notification between the suite call and the compile
call, no `TaskStop`). Both earlier hooks therefore missed for the same reason:
they matched what the extractor reads, and the extractor's reads are not
predictable. `stop3` holds it at its one unavoidable step instead. The
transcripts of `stop` and `stop2` show the extractor writes `decision-notes.md`
with a Bash heredoc, never the Write tool, so the hook matches Write, Edit,
MultiEdit and Bash on a subagent payload that names `decision-notes.md` (the
controller's own mentions of the path are not delayed) and sleeps 240 s. In
`stop3` the log has one delay line, tool Bash and agent a1e9354187035a191, the
extractor's task id, at 01:03:14Z. The SDD-specific order from the timestamps:
dispatch 01:03:02Z, the `Decision extractor:` ledger line and the workspace
`rm -rf` in the next call (01:03:08Z), suite result 01:03:15Z, `TaskStop`
01:03:24Z, compile 01:03:28Z, hand-back 01:03:57Z. The `TaskStop` falls
inside the delay window (01:03:14Z to 01:07:14Z), so the extractor was
mid-work, inside its held notes write, when stopped; no `decision-notes.md`
exists in the scratch directory at collection or after. Its only notification
carried status `stopped`, with no completion notification before the
`TaskStop`; both records read `Nothing recorded.`; the hand-back said the
extractor was stopped unfinished; the menu carried the literal `diff --git`
lines; the records commit body is one line, and turn 2's "3" committed it
(no proposals, since the compile ran without notes).
The SDD text gained one sentence after `fast` skipped the `Decision
extractor:` ledger line: the dispatch is complete only when that line is in
the ledger, written before any other tool call, because after a compaction it
is the only record of the task id and the notes path. One of the three earlier
runs skipped the line and two wrote it; `stop`, `stop2` and `stop3`, run on the
amended text, wrote it in the call right after the dispatch. Three sessions
cannot show
that the sentence makes the line always appear.
Deviations: the first line of `prompt-1.txt` carries one added sentence ("Work
in place on the current branch; do not create a worktree.") so the session does
not stop at a worktree-consent question. Two earlier `slow` attempts are kept as
`slow-void1` and `slow-void2`: both were fixture defects (the plan's sample
file was read by nothing; then the plan's own code carried a missing-file bug
and a circular assertion that the final review rightly raised), and the plan
was revised twice. Because the extractor proposed undocumented decisions in
each of the three finished-extractor runs, the bare "3" never committed there,
as the Step 4 amendment requires, and the third turn, "Dismiss all of them.",
drew the one-line records commit. The implementer subagents' commits carry a
`Co-Authored-By` trailer that is not in the skills' text. `run-sdd.sh`, the
delay hook, the fixture, `analyze.py` and `runs.md` are in `task-14-runs/`.

## 4. Post-landing checks still owed

The spec's Live section also asks for one session in Zed, which only the
human partner can run; record it here with the branch, the records commit,
and whether the background dispatch was collected.

Every rehearsal above was a print-mode session, where `run_in_background: true`
is honored; Claude Code 2.1.302 interactive fork mode, which hides that option,
is covered by Decision 7's reasoning but by no transcript, so the first
interactive finish should confirm the extractor still dispatches in the
background.
