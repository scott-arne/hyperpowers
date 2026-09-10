# Gate churn and skill hardening

**Date:** 2026-09-05
**Status:** Design, approved in chat, not yet planned
**Scope:** `skills/requesting-code-review/` (scripts and gate sections),
`hooks/`, `skills/subagent-driven-development/`, `skills/executing-plans/`,
`skills/writing-plans/`, `skills/receiving-code-review/`,
`skills/systematic-debugging/`, `skills/brainstorming/`,
`skills/test-driven-development/`, `tests/`, `docs/testing.md`, plus scenarios
in the separate [hyperpowers-evals](https://github.com/scott-arne/hyperpowers-evals/)
clone.

## Problem

Two investigations on 2026-09-05 produced one shared conclusion: the Codex
review gate asks for far more rounds than its own written contract calls for,
and several skills carry claims that no longer match the code they describe.

### Measured gate churn

Every gate directory on this machine was read: 696 `gate-round.json` records
under `~/.cache/hyperpowers/codex-review`, 3,314 captured Codex outputs
re-normalized through the shipped `verdict-normalize`, and 889 completed
`adversarial-review` jobs with start and completion timestamps in the
companion's own state.

| Gate | n | Mean rounds | Converged round 1 | Backstop |
|---|---|---|---|---|
| task | 468 | 2.24 | 27% | 1% |
| final | 63 | 2.00 | 32% | 2% |
| spec | 47 | 3.11 | 4% | 4% |
| plan | 48 | 3.42 | 0% | 8% |

Convergence did not improve between August (n=642) and September (n=54): mean
2.37 rounds in both. Cost is 71 hours of Codex wall-clock across those 889
reviews at a 4.0-minute median, 50 of those hours in August alone.

Four causes, in measured order of weight.

**1. The approval bar Codex actually applies is "zero findings."** Our lens
prompt is delivered as `User focus` inside codex-plugin-cc's own
`prompts/adversarial-review.md`, which instructs: use `approve` only if you
cannot support any substantive finding; prefer one strong finding over several
weak ones; break confidence in the change. The transcripts show exactly that.
On re-review rounds, 80% of blocking captures carry exactly one finding. Of 244
round-2+ findings on code gates, **zero** resemble an earlier round's title by
word overlap; document gates show 191 round-2+ blocking findings with a 2%
repeat rate, and blocking findings per capture falling 3.84 → 1.31 → 1.18 →
0.97 across rounds. Each round yields one fresh finding, so the loop ends when
the reviewer runs dry or the ceiling arrives — not when the work is done.

**2. `verdict-normalize` blocks on `needs-attention` even with zero
critical/high findings.** `gate-findings.md` states the contract: "Blocking =
Critical + Important. Minor findings are noted, not fixed in the loop", and the
round-aware preamble forbids new Minor findings on re-review. The script does
not implement that. Both its text path and its JSON path end at
`out("blocking", "needs-attention", …)` regardless of `blockingCount`, while
the companion template tells Codex to answer `needs-attention` for *any*
material risk, medium included.

| Gate | Blocking captures | Of those, zero critical/high | Share |
|---|---|---|---|
| task | 1,090 | 327 | 30% |
| final | 123 | 28 | 23% |
| adhoc | 75 | 18 | 24% |

37 task captures carried no findings at all — interim narration such as "I'm
checking whether that gap is already covered elsewhere" — and still blocked.
Document gates are unaffected (0%): their text shape puts medium findings under
`Non-blocking Findings`, which the parser already excludes.

**3. Round 1 is three independent adversarial reviewers, merged fail-closed.**
Per-lens `needs-attention` rates on code gates: correctness 55% (n=402),
contracts-and-integration 59% (n=352), tests-and-evidence 69% (n=401). Any one
blocks the round. Mean findings per lens capture is 0.94, so the exhaustiveness
demand our skeleton adds ("report every blocking finding you can identify this
round") does not survive the companion's "prefer one strong finding".

**4. Re-review prompts drift far from the recipe.** `recipe-code.md` says the
focus text stays short because the brief, report, package, and constraints
carry the context. Measured round-2+ prompts: median 464 words, p90 1,032, max
35,468 (a pasted diff). 36% exceed 600 words.

Not causes, checked and rejected: re-raising of declined findings (2% on
document gates, 0% on code gates), and low-confidence findings driving rounds
(zero blocking captures had all findings below 0.7 confidence).

One accounting defect surfaced alongside: over the historical window ending
2026-09-06T22:45:00-07:00, twenty task gates recorded ceilings of 1, 2, 6, or
7, which the five-round shared cap cannot produce; seven of them (the 6s and
7s) exceed the cap outright. The cap requires the
controller to compute `ceiling = 5 - <non-gate fix rounds>` before *every*
`gate-round` call, in a coordinate system that deliberately excludes the gate's
own rounds because the counter already holds them.

### Skill defects

A structural audit of all 15 skills found no broken links and no frontmatter
violations, but ten defects worth fixing. Verified against the working tree:

- `skills/requesting-code-review/SKILL.md:28` recommends
  `BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main`. SDD forbids exactly this
  at `SKILL.md:308` and `:343` ("never `HEAD~1`, which silently drops all but
  the last commit"), and `origin/main` is a moving ref that renders main's newer
  files as phantom deletions in a two-dot diff.
- `skills/executing-plans/SKILL.md:14` tells the agent to use SDD instead
  whenever subagents are available. `writing-plans/SKILL.md:201` routes to
  `executing-plans` *only* on an explicit inline-execution request, so on Claude
  Code the note always fires and contradicts the human's stated choice.
- `scripts/task-brief:43` prints `wrote <path>: N lines` and
  `scripts/review-package:50` prints `wrote <path>: N commit(s), N bytes`, but
  four places describe them as printing the path
  (`SDD/SKILL.md:246`, `:308`, `task-reviewer-prompt.md:193`, `:203`). Only
  `sdd-dir` prints a bare path.
- `optimizing-performance/SKILL.md:38` persists the baseline to "the path
  `sdd-dir` prints". `sdd-dir` prints a repo-scoped dir with no argument and a
  plan-scoped dir with one, and no plan exists at that step. The plan-scoped
  branch is deleted by SDD's Finish (`SKILL.md:598`, `rm -rf <workspace>`),
  which would destroy the baseline the second bounded round at `:47` needs.
- The reviewer read-only clause exists in three copies and has already
  diverged: `code-reviewer.md:35` carries the `git worktree add` escape hatch;
  `task-reviewer-prompt.md:52` and `re-review-prompt.md:43` do not.
- Seven files ship with zero inbound references from any skill, hook, test, or
  manifest: `brainstorming/spec-document-reviewer-prompt.md`,
  `writing-plans/plan-document-reviewer-prompt.md`, and five
  `systematic-debugging/` artifacts (`test-academic.md`, `test-pressure-1.md`,
  `test-pressure-2.md`, `test-pressure-3.md`, `CREATION-LOG.md`).
- `skills/receiving-code-review/` is referenced by no skill, hook, or test —
  not by `requesting-code-review`, not by SDD's fix loop.
- `writing-plans/SKILL.md:199` still says "two-stage review"; the task reviewer
  has been one reviewer returning two verdicts since 2026-06-10
  (`task-reviewer-prompt.md:3`).
- Six skills have no offline coverage: `dispatching-parallel-agents`,
  `executing-plans`, `optimizing-performance`, `profiling-performance`,
  `receiving-code-review`, `test-driven-development`. Two structural gaps let
  the dead files and the stale stdout claims survive months of green suites:
  nothing asserts that a shipped file has an inbound reference, and nothing
  pins what the two helpers print.

### Releases that never reached a session

Skill-file reads bucketed by plugin version across 173 session transcripts show
6.6.1 and 6.9.2 loading through 2026-08-31 and no 6.10.x or 6.11.x at all. The
gate split, the SDD ledger work, and the harness fixes had zero production
exposure until the marketplace refreshed on 2026-09-05. `hooks/session-start`
performs no version check.

### Upstream

`upstream/main` has not moved since v6.3.0 (`b36e082`, 2026-08-12), the fork's
current sync base; `upstream/dev` differs from it by one file. Unreleased
branch work contains five mechanical fixes that apply cleanly to fork code, and
two evidenced prose additions. Each was verified against this tree:

| Upstream | Defect | Fork site |
|---|---|---|
| `d80fc18` | bash ≥5.1 delivers heredocs via a pre-fork pipe write that deadlocks on macOS under pipe pressure; the wrapper's own heredoc can hang every hook | `hooks/run-hook.cmd:1` |
| `2a500fe` | moving-ref base yields phantom deletions | `requesting-code-review/SKILL.md:28` |
| `99f9f00` | wrong-branch HEAD yields an empty or non-rooted range and still emits a package | `scripts/review-package:26-27` |
| `0be4987` | mode-stripping extractors make sibling helper exec fail rc=126 | `review-package:32`, `task-brief:26` |
| `72ee5bb` | `claude -p` inherits the suite's stdin and can block for the full timeout | `tests/claude-code/test-helpers.sh:30` |
| `a45ede8` | a green run of your own test file is not a green suite | `test-driven-development/SKILL.md` |
| `537d649` | new projects get no tooling question, so lint/test infrastructure is never chosen | `brainstorming/SKILL.md` |

## Decisions

**D1. Two parts, split on evidence requirements, not on subject.** Part 1 is
everything provable by an offline suite: script behavior, hook behavior, dead
files, and prose whose correctness is mechanically checkable against code that
exists. Part 2 is everything that changes what an agent writes or how a
reviewer judges, which this repo's `CLAUDE.md` requires be gated on before/after
eval evidence. Part 1 ships as its own release so Part 2's live runs measure
against a clean baseline.

**D2. `verdict-normalize` approves `needs-attention` with zero blocking
findings, on the JSON path only.** This is the written contract already
(`gate-findings.md`: "Blocking = Critical + Important"), so the script is the
thing out of step, not the rule. The new reason string names the non-blocking
count so a controller reading the JSON can tell this case from an ordinary
approve, and the minor findings are still returned for the round ledger.

The text path is deliberately excluded. In the document shape a finding's
placement under `Blocking Findings:` is an explicit judgment by the reviewer
that it blocks, which a severity field alone should not override; the JSON
schema has no such placement, so severity is the only signal there. The
measurement agrees: 0 of 191 round-2+ document-gate blocking captures had zero
critical/high findings, so excluding the text path costs nothing and keeps the
blast radius inside the shape where the defect was measured. Also unchanged:
any verdict string that is neither `approve` nor `needs-attention` still
normalizes to blocking, so the new path cannot launder an unrecognized verdict
into an approval.

Rejected: a `--strict` flag preserving today's behavior. Two approval semantics
in the gate's only approval authority is exactly the ambiguity the script
exists to remove.

**D3. The zero-finding case stays blocking-adjacent through `incomplete`, not
through `approved`.** 37 task captures had `needs-attention` with an empty
findings array and narration in the summary. Those are not approvals and not
findings; they are unfinished reviews, which `verdict-normalize` already has a
state for. A `needs-attention` verdict with zero findings of any severity
normalizes to `incomplete`, routing to §4b recovery rather than silently
passing. The `--require-coverage` floor applies to the D2 approval exactly as
it applies to an ordinary approve: it remains a way to be incomplete, never a
way to approve.

**D4. Version staleness is a notice, never an action.** `hooks/session-start`
compares the running plugin's version against the marketplace clone's
`marketplace.json` and appends one line to the injected context when they
differ. It never updates anything, never fails the hook, and never speaks when
the versions match or the clone is absent — the same contract the ungated
notice already follows.

**D5. Dead files are deleted, and a guard makes the class visible.** All seven
have zero inbound references; two have been disconnected since 2026-03-24. The
guard asserts every non-`SKILL.md` file under `skills/` has its basename
mentioned by some other tracked file outside `docs/`, `CHANGELOG.md`, and
`RELEASE-NOTES.md` — those three record history, so a mention there is not a
live reference. Of 67 candidate files, exactly these seven fail, so the guard's
allowlist ships empty and any future entry has to argue for itself. Without the
guard the class recurs.

**D6. Part 2 changes are prompt text, measured one at a time.** The severity
calibration (D7) and the fixed round-2+ recipe (D8) both target the same metric
— rounds to convergence — so they ship as separate arms with their own runs.
Ceilings, the five-round cap, and the lens charters do not change.

**D7. Calibration goes in the focus text, because the template is not ours.**
codex-plugin-cc's `prompts/adversarial-review.md` is a plugin file that a
future version overwrites. The focus string is the only durable channel, so the
severity definition lives there: what "high" means for what this diff causes —
in its changed lines, in an unchanged caller it breaks, or in a requirement it
omits — and that an untested path is medium unless testing it was the task's
deliverable. The calibration reaches the reviewer only if the round-1 lens
composition carries the recipe's complete focus string, calibration included,
not merely its context paths.

*Amended 2026-09-07, after Task 2's Codex gate.* Arm A's success is judged on
classification accuracy, not rounds-to-convergence: fixture diffs reviewed by
real Codex through the production round-1 prompt shape, where a genuine defect
(a reachable crash; an omitted requirement) is rated high in 3 of 3 treatment
reviews and a defect-free change is not blocked in at least 2 of 3. One-shot
reviews cannot measure rounds; the post-release cohort read at release carries
that number.

**D8. Round 2+ gets a fixed recipe.** Two textual parts and nothing else: the
round-aware preamble, which names the ledger path, and the short recipe focus
unchanged — the exhaustiveness demand is round-1 language and is dropped from
re-reviews. (Amended 2026-09-08: the ledger path travels inside the preamble;
listing it as a third part made every compliant prompt fail an exact-shape
check, so the contract now names the two textual parts a prompt actually has.)

**D9. `gate-round` carries the consumed-round total.** A new
`--consumed <n>` records non-gate fix rounds in the counter's own state, so the
controller states one number it can read off the ledger instead of performing a
subtraction in a coordinate system it must first reason about. The twenty
out-of-pattern ceilings measured over the historical window ending
2026-09-06T22:45:00-07:00 are the evidence that the subtraction does not
survive contact.

**D10. Upstream prose ports carry fork-side evidence.** Upstream measured both
(TDD 1/12 → 8/12; tooling 0/3 → 3/3), but this repo's rule is fork-side
before/after, so each gets a scenario and a run in Part 2.

## Out of scope

- Reducing the round-1 lens count. It is listed as a Part 2 trial, not a
  decision; the measurement runs before any change.
- Shortening SDD's 1,451-word fix-loop section or any other size reduction.
  Cost was flagged, not diagnosed, and the fix-loop text is exactly the
  behavior-shaping prose the evaluation rule protects.
- Porting `skeleton-alternative`, `exp/loop-econ-*`, `agentic-end-to-end-testing`,
  `diagnosing-superpowers`, or `codex/brainstorming-intent-gates`. All land in
  diverged skills and carry no eval numbers.
- Changing gate ceilings or the five-round shared cap.
- History rewriting for the untracked eval artifacts.

## Success criteria

**Part 1.** Every offline suite green, including new assertions for: the
zero-blocking approve path and the zero-finding incomplete path in
`verdict-normalize`; the version notice present when versions differ and absent
when they match; heredoc-free hooks; `review-package` range guards exiting 3;
helpers working with exec bits stripped; the two helpers' stdout contract; and
the dead-file guard. `docs/testing.md` describes quorum rather than Drill.

**Part 2.** Per arm, a control and treatment run on the same scenario with
distributions reported, kept in a dated evidence note under
`docs/hyperpowers/`. The calibration arm's target is classification accuracy on the
production round-1 prompt shape (real defects rated high 3 of 3; a defect-free
change not blocked in at least 2 of 3), per the D7 amendment of 2026-09-07,
with rounds-to-convergence tracked in the post-release cohort at release; the
fixed-recipe arm's target is re-review prompts back inside the recipe's stated
shape.
