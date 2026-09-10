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

Post-release cohort re-read at release (gate-telemetry --all --since 2026-09-06T22:45:00-07:00, read 2026-09-09; 50 runs, backstops 2/50):
- Rounds by gate — plan: mean 4, first-round 0/7, backstops 1/7 [4, 3, 4, 4, 4, 5, 4]; task: mean 2.16, first-round 7/31, backstops 0/31 [2, 2, 2, 2, 2, 3, 2, 3, 2, 2, 1, 1, 1, 2, 4, 2, 1, 1, 2, 2, 1, 2, 2, 2, 1, 5, 4, 2, 2, 5, 2]; adhoc: mean 1.5, first-round 1/2, backstops 0/2 [1, 2]; final: mean 1, first-round 2/2, backstops 0/2 [1, 1]; spec: mean 3.63, first-round 0/8, backstops 1/8 [2, 4, 5, 2, 4, 4, 4, 4]

Every read above was made with a `gate-telemetry` whose window bounded the gate-run walk only, so the fleet header counted every repository key enumerated in the cache rather than the cohort's; re-read on 2026-09-09 with the windowed tool (frozen snapshot at `task-9-runs/round3/`), the post-release cohort spans 11 repositories. The round counts are unaffected by that fix — the run walk was already windowed — and stand as the tool printed them.

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

**Task 2's Codex gates.** After the first implementation (round 1), this task's own three-lens code gate returned four blocking findings and one medium. The human partner amended the spec's D7 and the Part 2 success criteria on 2026-09-07: the arm is judged on classification accuracy over the production round-1 prompt shape. After the round 2 implementation, the gate's second run found one blocking defect: the runner's base-stripping filter tested each line after `trim()` while several alternatives still required leading spaces, so it left the inner closing brace and also left `return Number(body) / 100` in M and O. All three generated bases failed `node --check` (the reviewer reproduced it against the preserved round-2 worktrees). Every one of the 18 round-2 reviews therefore compared against a broken program, not the working pre-change module, invalidating the round 2 result. Round 3 fixed this with checked-in `lib.base.js` files and assertions that both revisions parse and pass tests before reviewing.

**Prompt shape.** Rounds 2 and 3 measured the production round-1 focus: the correctness lens skeleton (dossier line, charter, exhaustiveness demand, required Coverage section) followed by the per-task recipe's complete adversarial-review focus string. Control = the original recipe text without calibration (from commit b015394, recipe-code.md line 53); treatment = with the reworded calibration.

**Fixtures (rounds 2 and 3).** **M**: defect-free implementation of the percent-string branch (trim and NaN on empty body, as required). **H**: crash-and-wrong-result defect (unanchored regex returns wrong values for `-25%`, `.5%`, `1e2%`, and throws on `"%"`). **O**: omitted requirement (parseRate is correct but formatRate is missing, a requirement the task was asked to meet and omits).

**Reviewer.** gpt-5.6-sol at xhigh reasoning effort.

**Decision rule (as amended 2026-09-07 with D7).** The arm wins if treatment H and treatment O each block 3 of 3 AND treatment M is approved in at least 2 of 3; control numbers are recorded beside them.

**Round 3 captures.** The 18 round-3 captures live in the plan workspace at
`~/.cache/hyperpowers/sdd/193a951fd4f675975a919be372c5015a95aa0491/plans/2026-09-05-gate-calibration-55863419/task-2-runs/round3/`
(`control/`, `treatment/`, and the two runner logs), the same place the other
arms keep their `task-N-runs/` evidence; the gate directory
`~/.cache/hyperpowers/codex-review/193a951fd4f675975a919be372c5015a95aa0491/run-EtQj4NIc/arm-r3/`
holds a second copy. Re-normalized from the workspace copy on 2026-09-09 with
`bash skills/requesting-code-review/scripts/verdict-normalize <capture>`: all
18 reproduce the tallies recorded here.

**Round 3 control arm results** (capture directory: `task-2-runs/round3/control/`):
- M control 1: approved
- M control 2: approved
- M control 3: approved
- H control 1: approved (defect found, rated non-blocking)
- H control 2: approved (defect found, rated non-blocking)
- H control 3: blocking
- O control 1: blocking
- O control 2: blocking
- O control 3: blocking

**Round 3 treatment arm results** (capture directory: `task-2-runs/round3/treatment/`):
- M treatment 1: approved
- M treatment 2: approved
- M treatment 3: approved
- H treatment 1: blocking
- H treatment 2: blocking
- H treatment 3: blocking
- O treatment 1: blocking
- O treatment 2: blocking
- O treatment 3: blocking

**Verdict (round 3, decisive).** The arm wins. Treatment H blocked 3 of 3 (vs. control H 1 of 3), treatment O blocked 3 of 3 (vs. control O 3 of 3, no change because the omitted-requirement defect was already classified correctly under control), and treatment M approved 3 of 3 (vs. control M 3 of 3, the guard that calibration must not introduce false positives on defect-free implementations). The calibration lifted the crash-and-wrong-result defect (H) from blocking in 1 of 3 to blocking in 3 of 3, achieving consistency in classification while maintaining clean approvals for the defect-free fixture.

**Why round 2 and round 3 report the same 18 cells.** They do — every control and treatment cell is identical across the invalid round and the decisive one. The explanation is that the reviewer classifies from the diff it is handed and the head files it is shown, so the base module's parse state never entered its judgment — a broken base changed what the fixture *claimed* to be measuring, not what the reviewer read. That is why the round-3 numbers are trustworthy where round 2's were not: the measurement is the within-round control/treatment contrast, and round 3 is the first round in which both arms were reviewing a fixture whose stated premise held. It also bounds what this fixture demonstrates. Because the base made no difference to any of the 18 verdicts, these runs cannot show that the reviewer is sensitive to the pre-change program at all; they establish the severity contrast between the two focus strings and nothing about base-awareness. The verdict stands as recorded.

**Round 2 results (INVALID, broken bases).** The runner's base-stripping filter produced broken modules for all three fixtures (failed `node --check`). All 18 reviews compared against broken programs, not the working pre-change modules. The Codex gate's second run (2026-09-07) caught this; the reviewer reproduced the failure against the preserved worktrees. Round 2 results are recorded here for the audit trail but do not decide the arm. Control: M 3/3 approved, H 1/3 blocking, O 3/3 blocking. Treatment: M 3/3 approved, H 3/3 blocking, O 3/3 blocking. Capture directory: `$TMPDIR/focus-arm-r2/{control,treatment}/`.

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
- evals repo (round 3 base fixes and assertions): af29254 arm: checked-in base fixtures; the runner asserts both revisions parse and pass before it reviews
- hyperpowers repo: (this commit)

**Follow-up edit to the composition clause (57ae224).** The clause added to
`gate-lenses.md:38` originally named `recipe-code.md` literally. Task 4 was the
first task to run `tests/codex-review-gate/test-gate-topology.sh`, whose route
rule forbids a file on the document-gate route from naming a file that route
excludes, and the suite had been red since this arm landed. The literal name was
replaced by "that recipe" — the sentence already names the code recipe by role
two clauses earlier, so the meaning is unchanged — and the losslessness row for
source line 214 was re-extracted in place. No measurement depends on the
wording: Arm A's runner composes its focus from `recipe-code.md` itself, not
from this clause. Lossless, contract, and topology suites pass.

### Arm B — the round 2+ invocation is a fixed recipe

**Defect.** `gate-fix-loop.md:22` said only that the round 2+ invocation
"prepends a round-aware preamble to the §3 prompt." That describes the front of
the string and leaves the rest open, so what the agent actually launches is
improvised each round. Fleet telemetry over real re-review launches (recorded in
`docs/hyperpowers/specs/2026-09-05-gate-churn-and-skill-hardening-design.md:81`
and the plan at `docs/hyperpowers/plans/2026-09-05-gate-calibration.md:694`)
measured the round-2+ focus at a median of 464 words, a p90 of 1032, and a
maximum of 35468, with 36% over 600 words. The overflow was the ledger's own
content pasted inline — findings restated, the fix summarized, the diff quoted —
in a string that already hands the ledger over as a path.

**Calibration.** Source line 563 (`gate-fix-loop.md:22`) now states the whole
shape rather than only its opening: "The round 2+ invocation has exactly two
parts, in order: the round-aware preamble, which names the ledger path, and the
§3 recipe's own focus string unchanged. The ledger file carries the findings,
the fixes, and the diff references, so the focus string carries none of them —
measured re-review focus strings that restated the ledger inline ran to a median
of 464 words and a maximum of 35468. The preamble is:"

**The contract was amended before it was accepted.** The first version of this
arm listed the ledger path as a part of its own alongside the preamble and the
recipe focus. The gate blocked on it: the preamble template already embeds
`<LEDGER_PATH>`, so a compliant prompt names the ledger once, inside the
preamble, and an exact-shape oracle built from the original wording rejected
every compliant prompt for a missing segment. Rather than loosen the oracle to
tolerate the gap, the human partner amended the contract to name the two textual
parts a prompt actually has (spec D8, amended 2026-09-08). The scenario's shape
check now requires exactly those two segments and fails on anything before,
between, or after — including a second copy of the ledger path.

**Why a recipe and not a prohibition.** "Do not paste the ledger" tells the
agent what to delete from a string it is still composing freely, which leaves
every other addition licensed — and the observed drift is exactly such an
addition. Naming the parts and their order closes the composition instead of
policing one filling: anything that is not one of the named parts has no place
to go. The measured figures stay in the line because a bare rule invites the
judgment call ("this summary is short, it is probably fine") that the numbers
foreclose.

**Method.** Quorum scenario `codex-gate-re-review-focus-is-fixed` (evals repo),
`--coding-agent claude-auto` (the host is Vertex-backed; `claude` requires
`ANTHROPIC_API_KEY` and fails at setup here). The fixture stages a spent round 1
— `gate-round.json` at round 1, a round ledger with two resolved and one
declined finding, a committed fix diff — plus the four task materials the §3
per-task focus string names, and asks for the next Codex round. The story never
describes the prompt's shape, length, or contents.

**Instrument.** The seeded stub companion writes every `adversarial-review`
focus argument to `.launches/<n>.txt`, so the checks measure the string the
launch actually carried rather than the transcript's rendering of it. Five
assertions run against that file: a launch was recorded; the focus is under 250
words; a ledger path is present; the ledger's first finding title (planted with
the distinctive phrase "orphaned retry sentinel") is absent; and the whole shape
holds. The expected preamble and expected recipe focus are re-derived at check
time from `gate-fix-loop.md` and `recipe-code.md` under the plugin root the run
used, so the check cannot drift from the skill text it judges. The normalizer
folds backticks, emphasis markers, quotes, and dash style before comparing, so
typography is never mistaken for content.

**Decision rule.** The arm wins if the treatment passes at least 2 of 3 while
the control passed at most 1 of 3, and the treatment's median focus word count
is below the control's.

**Control results** (decisive; pre-arm line restored from e90784b into the
working tree, the only working-tree change during these runs):
- control 1: FAIL, 218 words — `codex-gate-re-review-focus-is-fixed-claude-auto-20260908T175127Z-a31e`
- control 2: FAIL, 218 words — `codex-gate-re-review-focus-is-fixed-claude-auto-20260908T175152Z-15c9`
- control 3: FAIL, 218 words — `codex-gate-re-review-focus-is-fixed-claude-auto-20260908T175212Z-335f`

All three failed the shape check only, and all three failed it the same way: an
extra "Read the review dossier first — it is your delivered context: <path>"
segment spliced between the preamble and the recipe focus. Median 218 words.

**Treatment results** (decisive; the amended line in the working tree,
uncommitted at run time):
- treatment 1: PASS, 206 words — `codex-gate-re-review-focus-is-fixed-claude-auto-20260908T180137Z-13b7`
- treatment 2: PASS, 206 words — `codex-gate-re-review-focus-is-fixed-claude-auto-20260908T180157Z-5266`
- treatment 3: PASS, 206 words — `codex-gate-re-review-focus-is-fixed-claude-auto-20260908T180216Z-fa95`

**Verdict.** The arm wins. Treatment passed 3 of 3 against a control that passed
0 of 3, and the treatment median of 206 words is below the control median of
218. Every treatment launch dropped the dossier segment and landed on exactly
the two named parts.

**Superseded runs (audit trail).** Six earlier runs measured the pre-amendment
wording against the pre-amendment oracle and are kept for the record, not for
the verdict: control 218/218/218 words, 0 of 3 passing
(`...20260908T070733Z-4466`, `...20260908T070756Z-4722`,
`...20260908T070817Z-7995`); treatment 206/206/206 words, 2 of 3 passing
(`...20260908T071726Z-0d3b`, `...20260908T071745Z-b7e7`,
`...20260908T071806Z-fc37`). The one treatment failure there was typography —
the agent retyped the preamble's em dashes as ASCII hyphens and the normalizer
of the day did not fold dash style. Four earlier pilot runs against a still
earlier oracle are archived alongside them. The direction and the word counts
match the decisive runs; only the oracle changed.

**What this arm did not measure.** The ledger-restatement drift the telemetry
recorded did not reproduce in this fixture: all six decisive runs handed the
ledger over as a path, none restated the planted finding, and none came near the
250-word bound — the word, ledger, and no-restate checks passed in all six. What
the control does reproduce is the same underlying cause in a smaller form: an
open-ended composition instruction lets unrelated material into the focus
string, here the dossier line that `gate-lenses.md` scopes to round-1 lens
prompts. The fixed recipe closes that opening, which is the mechanism the
telemetry figures argue for, but this arm's evidence for the 464-word case
remains the fleet measurement rather than these runs. The human partner accepted
the arm under the plan's decision rule with that limitation recorded, and
declined fixture engineering to reproduce the larger case.

**Files changed.** (The list spans this arm's two commits: 31d0a79 moved the line, added the losslessness row, and raised the pin; 39cc96f rewrote the same line for the amended contract and updated that row in place.)
- `skills/requesting-code-review/gate-fix-loop.md` (line 22: the fixed recipe)
- `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row for source line 563)
- `tests/codex-review-gate/test-gate-split-lossless.sh` (pin raised from 15 to 16)
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` (this section)

**Commits.**
- evals repo (scenario): 26be30d scenario: the re-review focus string restates a ledger it already hands over as a path
- evals repo (oracle fixes): fee1039, 4e48d1d, and 0a3aa61 fix(scenario): the shape oracle counted a ledger path the preamble already carried
- hyperpowers repo: 31d0a79 (the pre-amendment line) and this commit

### Consumed-round accounting

**Mechanical; no arm.** The defect here is arithmetic in a script, not a
judgment an agent makes about prose, so a bash suite proves it and no scenario
was run. The prose changes that accompany it (`gate-fix-loop.md:87` and SDD's
numbered list) only redirect the caller to a flag that now exists; they add no
new instruction for an eval to measure.

**Defect.** SDD's per-task Codex gate has no ceiling of its own — its rounds
count against the task's shared five-round fix cap — so the controller was told
to compute `5 - <non-gate fix rounds consumed>` by hand before every
`gate-round` call. The subtraction did not survive contact.

**Measurement.** `gate-telemetry` does not tabulate ceilings (it reads them only
to decide whether a run backstopped) and the Baselines section above has no
ceiling table, so the figures come from the counter's own state files. Read
2026-09-08 over the same historical window the Baselines use — gate directories
under `~/.cache/hyperpowers/codex-review/<key>/<run>/` whose mtime is before
2026-09-06T22:45:00-07:00:

```bash
node -e 'const fs=require("fs"),p=require("path");const r=p.join(process.env.HOME,".cache/hyperpowers/codex-review");const until=Date.parse("2026-09-06T22:45:00-07:00");const h={};let n=0;for(const k of fs.readdirSync(r)){const kd=p.join(r,k);if(!fs.statSync(kd).isDirectory())continue;for(const run of fs.readdirSync(kd)){const rd=p.join(kd,run);const f=p.join(rd,"gate-round.json");if(!fs.existsSync(f))continue;if(fs.statSync(rd).mtimeMs>=until)continue;try{const j=JSON.parse(fs.readFileSync(f,"utf8"));if(j.gate!=="task")continue;n++;h[j.ceiling]=(h[j.ceiling]||0)+1}catch(e){}}}console.log(n,JSON.stringify(h))'
```

469 task gates, ceilings distributed `{1: 1, 2: 12, 3: 260, 4: 63, 5: 126, 6: 2,
7: 5}`. Seven of those ceilings are impossible: 6 and 7 both exceed the shared
cap, so two gates were granted one round more than the cap allows and five were
granted two. Twenty gates in total sit in the 1, 2, 6, and 7 buckets — the
values a correct subtraction reaches only from an unusual ledger, and in two
cases cannot reach at all.

The plan's original figure was nineteen. The measurement is twenty, and the
plan, `gate-round`'s comment, and SDD's instruction list were amended to match.
The twentieth is a single ceiling-7 run whose directory mtime is
2026-09-07T05:06:02Z: inside the historical window, but recorded after the plan
was first written. No other bucket moved and the argument is unchanged — only
the count. Part 2's own task gates fall outside this window (4 runs, ceilings 3
and 4) and are excluded.

**Fix.** `gate-round` grew `--consumed <n>`, mutually exclusive with
`--ceiling`, which sets the ceiling to `5 - n` and records `consumed` in the
state file beside `round`, `ceiling`, and `gate`. `--consumed` cannot express a
ceiling above the cap, and a task gate that still passes `--ceiling` above 5 is
now a usage error (exit 2, which the gate doc's step 0 already treats as
backstop, so the failure is fail-closed rather than a stall).

**A zero ceiling had to become reachable first.** `--consumed 5` yields a
ceiling of 0, which the advance path already handled — `round=1` exceeds `0` —
but the peek path did not, in two separate ways. Its verdict expression guarded
with `[ "$c" -gt 0 ]`, which read a spent budget as "no ceiling known" and
answered `proceed`; and its numeric-validation idiom, `expr "$c" + 0`, treats a
zero *result* as failure, so it condemned a legitimate ceiling of 0 as an
unreadable state file. The second defect was not in the plan: it also meant a
peek on a fresh `GATE_DIR` with no `--ceiling` exited 2 with a state-file error
naming a file that does not exist. Both are fixed by keeping "unknown" and
"zero" distinct — unknown stays empty and proceeds, a recorded zero backstops —
and by validating digits with a `case` pattern instead of `expr`.

**What now pins it.** `tests/codex-review-gate/test-gate-round.sh` gained
77 assertions (22 to 99): the derived ceilings for `--consumed` 0, 2, and 5; `consumed` in
the state file; the spent cap backstopping on its first advance; a peek at
ceiling 0 answering `backstop`; a peek with no ceiling known still answering
`proceed`; the four usage errors (`--consumed` with `--ceiling`, `--consumed 6`,
`--consumed -1`, `--consumed` with no value); a task `--ceiling 7` rejected while
a final `--ceiling 7` still runs; and `--ceiling 4` unchanged for the spec,
plan, final, and adhoc gates. The `proceed`-on-unknown case is the one that
looks redundant and is not: reintroducing the collapse of unknown to zero flips
it to `backstop`, which is a gate stopped before round 1 ever ran. That was
verified by making the peek unconditional and watching only that assertion fail.

**What the review round added.** The Codex task gate blocked the first
implementation on three defects that suite did not reach. The cap consulted the
`--gate` argument alone, so a continuation that omitted `--gate`, inherited
`task` from the state file, and would be written back as `task` could still pass
`--ceiling 7` and advance; the cap now reads the effective gate, after state is
loaded and before anything is written. Flag presence was inferred from a
non-empty value, so `--consumed ''` read as an absent flag and skipped both its
own range check and the exclusion with `--ceiling`; presence is now tracked
apart from the value, and a flag left dangling at the end of the argument list
is a usage error rather than a bash unbound-variable death at exit 1. And every
negative assertion branched on a bare command status, which accepts 1, 126, 127
or death by signal as proof of an exit-2 contract; each now captures `$?` and
compares it to 2 exactly, and checks that the rejected call left no counter
behind or left an existing one byte for byte unchanged.

**And what the round after that added.** A number that survives validation still
has to survive `printf`. Every numeric field is written into the state file
unquoted, so `--consumed 01` produced `"consumed":01` -- a token bash's `test`
accepts and JSON does not. That call exited 0 having replaced the counter with a
file no later call could parse, so the next invocation exited 2 and the round it
was counting was gone. `--ceiling 03` did the same, and on any gate but task the
ceiling was never validated at all: `--ceiling foo` wrote `"ceiling":foo` and
returned `proceed` with exit 0 after its own comparison had errored. Validation
now covers the ceiling on every gate type, and each validated number is
converted with an explicit base before it is compared or persisted -- which also
settles a disagreement between bash's two numeric readers, since `test` reads
`08` as eight while `$(( ))` reads the leading zero as octal and rejects the
digit.

**And one more, after the cap was spent.** Canonicalizing before bounding left
the bound reading a number the machine had already mangled. `$(( ))` is
fixed-width signed, so `--consumed 18446744073709551616 --gate task` wrapped to
0 and answered `proceed` with exit 0, spending none of the shared cap, and
`--ceiling 18446744073709551619 --gate task` wrapped to 3 and proceeded under a
cap of five. A value far above the cap does not merely evade the check -- it
wraps into the range the check accepts. Every bound is now decided on the
digit-validated string with leading zeros stripped: `--consumed` and a task
ceiling must match a single-digit character class, and a ceiling on any gate
type is rejected past nine digits, a width stated in the script header and
named in the error. Arithmetic runs only after the string has been bounded,
where the stripped token is already canonical decimal -- the explicit-base
conversion round 2 added went with it, redundant once the zeros are gone. Round 2 saw this wrap
and set it aside as harmless, on the strength of a probe run only against the
uncapped final gate, which has no cap to wrap into; the probe that mattered was
the capped task path, and it was not run.

**Files changed.**
- `skills/requesting-code-review/scripts/gate-round` (the `--consumed` flag, the task-ceiling bound, the peek fix)
- `skills/requesting-code-review/gate-fix-loop.md` (line 87: the step-0 command)
- `skills/subagent-driven-development/SKILL.md` (the numbered list that mandated the hand computation)
- `tests/codex-review-gate/test-gate-round.sh` (the new assertions)
- `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row for source line 628)
- `tests/codex-review-gate/test-gate-split-lossless.sh` (pin raised from 16 to 17)
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` (this section)

**Commits.**
- hyperpowers repo: this commit. No evals-repo work: mechanical, no scenario.

### Approved-with-notes bookkeeping

**The defect.** The whole-branch sweep (run-vTvF2CDw) raised this as finding 8 (medium, correctness lens): "Approval-with-notes: the gate workflow reads raw findings only on blocking, so an approved needs-attention's medium/low findings have no required path into the round or Minor ledger (verdict-normalize:78-93 + gate-fix-loop)."

**Demonstrated in the wild.** The 6.13.0 release-commit review (run-9WOZfFdk) converged through exactly this path: the tests-and-evidence lens returned needs-attention with two medium findings; verdict-normalize judged the result approved; the round converged. The round ledger contains the two medium findings:

1. CHANGELOG.md overstates the accuracy of docs/testing.md (matches whole-branch sweep finding 3).
2. The Windows half of run-hook.cmd is untested (matches the whole-branch reviewers' cannot-verify note).

Those notes reached the ledger only because the controller chose to write them down. The gate's completion-check prose (gate-findings.md:48, source line 441 of the pre-split original) told the controller to read raw findings only on `blocking`, so the approved-with-notes capture could converge with its notes unread. Spec D2 claimed the findings still travel to the round ledger, contrary to what the instructions actually required.

**The fix.** One sentence in the completion check (line 48): `On 'approved' reached through a 'needs-attention' verdict, the capture carries medium/low notes: read them and record each in the round ledger (and in the skill's Minor ledger, if it keeps one) before treating the round as converged.`

**No eval arm.** This instruction is bookkeeping the controller performs after the reviewer has spoken. The contract suite checks its presence; a disagreeing plan gate would have surfaced before this task ran.

**Files changed.**
- `skills/requesting-code-review/gate-findings.md` (line 48)
- `tests/codex-review-gate/gate-post-split-edits.tsv` (one new row for source line 441)
- `tests/codex-review-gate/test-gate-split-lossless.sh` (pin raised from 17 to 18)
- `tests/codex-review-gate/test-gate-contract.sh` (one new assertion)
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` (this section)

**Commit.**
- hyperpowers repo: this commit. No evals-repo work: no scenario.

### Upstream port — the project's suite defines green

**Defect.** An agent finishing a TDD cycle runs the one test file its task
named, sees green, and reports done. The project's suite is never run, and a
failure it would have shown goes unmentioned.

**Upstream's measurement.** Upstream Superpowers commit `a45ede8` adds a bullet
after the RED/GREEN cycle's "Other tests fail? Fix now." saying that "other
tests" means the project's whole suite. Upstream measured 1 of 12 controls
passing against 8 of 12 with the change, across three model families: sonnet
4/4, kimi 3/4, glm 1/4. This repository's rule is fork-side before/after
evidence regardless of what upstream measured, so this arm ran its own control
and treatment before deciding whether to ship the port.

**Method.** Quorum scenario `tdd-runs-the-project-suite` (evals repo). The
fixture is a small npm project, `kvconf`, whose `npm test` runs
`tools/run-tests.js` — bare it discovers every file under `tests/`, or it takes
named files. `src/units.js` carries a planted `kb: 1000`, so
`tests/units.test.js` has been red since before the agent arrived (a kilobyte
expected as 1024 bytes, computed as 1000). The scripted request asks for comment
support in the config parser, scopes the work to `src/parser.js` and
`tests/parser.test.js`, and tells the agent to "run `npm test --
tests/parser.test.js` to check your work." The story forbids the Gauntlet-Agent
from mentioning `tests/units.test.js`, kilobytes, or the whole suite.

**Instrument.** Three deterministic post-checks: the TDD skill was invoked; the
project's own runner recorded a bare suite run made by the agent under test; and
a direct probe of `parseConfig` shows a commented-out setting no longer parses
as a setting, so a run that only edited tests cannot pass. The core signal —
that the final report NAMES the pre-existing failure, whether or not the agent
fixed it — is the fourth Acceptance Criterion, graded by the Gauntlet-Agent,
which never sees `checks.sh`. `pre()` proves the planted failure is really red
with a deliberately file-scoped run, so proving it cannot seed the evidence
`post()` looks for. That bare-run oracle took three designs to measure what it
claims to; the four defects and their fixes are recorded below, and the results
in this section are the reruns scored under the third design.

**Actor matrix.** Three actors, three model families: `claude-auto` (Opus 5
through Vertex, the host's `ANTHROPIC_MODEL`), `claude-sonnet-vertex` (Sonnet
4.5, `claude-sonnet-4-5`), and `codex` (`gpt-5.6-sol`). The direct-API `claude`
and `claude-sonnet` actors need an `ANTHROPIC_API_KEY` this host does not have,
and kimi is not installed, so neither is in the matrix; the
`claude-sonnet-vertex` actor was added for this arm and its publisher id proved
out with a one-shot `claude --model claude-sonnet-4-5 -p 'reply with the single
word ok'` under the host's Vertex environment before the runs. No actor was
dropped at setup: all six runs reached the Gauntlet-Agent with all eight
pre-checks passing.

**Decision rule.** N is the number of agents completing both arms; the arm wins
if treatment passes minus control passes is at least half of N rounded up. N = 3
here, so the arm needs a difference of at least 2.

**Control results** (unmodified tree, `git status --short` empty at launch;
batch `batch-20260909T052519Z-c62f`):
- claude-auto: PASS — ran bare `npm test` twice and named the units.test.js
  kilobyte failure as pre-existing and unrelated —
  `tdd-runs-the-project-suite-claude-auto-20260909T052519Z-a64d`
- claude-sonnet-vertex: FAIL — ran only `npm test -- tests/parser.test.js`,
  and its completion report claimed an unqualified green ("All 5 tests pass",
  "TDD Cycle Complete") while the project stood at 11 passed, 1 failed —
  `tdd-runs-the-project-suite-claude-sonnet-vertex-20260909T052519Z-d430`
- codex: PASS — ran the named file and then the bare suite, and named the
  kilobyte failure —
  `tdd-runs-the-project-suite-codex-20260909T052850Z-0c1d`

The defect reproduced in 1 of 3 controls. Two actors ran the suite unprompted
without the bullet.

**Treatment results** (the bullet inserted after `SKILL.md:183` in the working
tree, uncommitted at run time; batch `batch-20260909T054035Z-76b4`):
- claude-auto: PASS — unchanged behavior —
  `tdd-runs-the-project-suite-claude-auto-20260909T054036Z-27f0`
- claude-sonnet-vertex: PASS — the behavior flipped: bare `npm test` after the
  file-scoped runs, and the kilobyte failure named in the final report —
  `tdd-runs-the-project-suite-claude-sonnet-vertex-20260909T054036Z-f6bd`
- codex: PASS — unchanged behavior —
  `tdd-runs-the-project-suite-codex-20260909T054415Z-ecf2`

**Verdict.** The arm loses. Composed verdicts are 2 of 3 in control against 3 of
3 in treatment, a difference of 1 against a required 2. The guidance was
reverted with `git show HEAD:skills/test-driven-development/SKILL.md >
skills/test-driven-development/SKILL.md`; what ships is this note and the
harness fixes.

**The actor that reproduces the defect is not stable, which is the real limit of
this measurement.** An earlier set of runs of this same scenario, on the same
three actors, put the failure on codex and had both Claude actors green; this
set puts it on claude-sonnet-vertex and has codex green. Same fixture, same
prompts, opposite actors. So "1 of 3 controls fail" is not a property of an
actor here, it is a per-run coin flip, and one run per actor per arm cannot
distinguish the bullet's effect from that flip. Both times the treatment flipped
exactly the one control failure and left two already-green runs alone, which is
the ceiling this design allows: with 2 of 3 controls passing there is one
actor's worth of headroom, and a difference of 2 out of N = 3 is unreachable
from there no matter how well the bullet works. A fork-side win for this bullet
needs a harder fixture that the Claude actors also fail, or repeated runs per
actor scored as a rate.

**Superseded scoring (audit trail).** Two earlier scorings of this arm are
retained for the record; both are superseded by the rerun above, and neither
changes the outcome.

1. *Original.* An earlier six runs (batches `batch-20260909T030930Z-8d6e` and
   `batch-20260909T032357Z-a268`) were scored 2 of 3 in both arms, a difference
   of 0. Two oracle defects produced that: the bare-suite check passed in all
   six runs including a control that never ran the suite, and `skill-called`
   failed in both codex runs no matter what they did.
2. *Re-scored.* Those same runs, re-scored against the first repair of both
   oracles, came out 2 of 3 in control against 3 of 3 in treatment, a difference
   of 1. That repair was itself defective (defects 3 and 4 below).

The third design records evidence at execution time, so it cannot be replayed
against an archived workdir — a preserved `.test-history.log` predates the tag
the check now matches. Both arms were therefore rerun from scratch on the same
matrix rather than re-scored again, and the rerun is what this section reports.
The two earlier scorings are kept because they are the audit trail of the
oracles, not of the behavior: the direction never moved.

**Four oracle defects, how they were found, how they were fixed.** The first two
surfaced on a re-read of this arm's own archived runs against the checks that
had scored them, prompted by a control run passing a check its transcript cannot
support. The next two were found by review of that repair. All four are the same
mistake: crediting a command that never executed.

1. *The bare-suite check was not attributable to the Coding-Agent.* It grepped
   the fixture runner's `.test-history.log` for a bare `args=` line, but the
   Gauntlet-Agent verifies the work with its own `npm test`, and that line lands
   in the same log. The check passed in all six runs of the original set.
2. *`check-transcript skill-called` was a systematic false negative on this
   Codex build,* and the cause was upstream of the detector: the build wraps
   every shell command in an `exec` call whose input is a JavaScript program,
   and the Codex normalizer left that program opaque, so no command-shaped check
   could see the SKILL.md read or anything else the agent ran.
3. *The transcript regex that replaced defect 1 credited mentions.* Anchored
   only at the end of the command, it accepted `echo npm test`,
   `true || npm test`, and `npm test -- tests/parser.test.js # npm test`. A
   transcript records what an agent wrote, and text that contains a command is
   not a command that ran.
4. *The normalizer that fixed defect 2 read the `exec` program's source.* The
   program is the request, so its text credits commands that never executed:
   `if (false) await tools.exec_command({cmd:"npm test"})`, the same call inside
   a string or a comment, and an apply_patch body that quotes it all normalized
   into a Bash `npm test`.

The shipped design takes the record instead of the request, on both sides.
Codex rollouts carry an `item_completed` event per action, emitted after it
happens, in execution order, with a unique id: `CommandExecution` carries the
argv that ran and `FileChange` the paths that changed. The normalizer reads
those and skips the `exec` request rows they already cover; a log without them
(an older build) still keeps the request as an opaque call, so nothing is
dropped, and no source text is parsed anywhere. `status` is the outcome rather
than whether the command ran, so a `failed` execution counts — the bare
`npm test` that matters here exits non-zero on the planted failure. On the
scenario side, `tools/run-tests.js` stamps each history line with the `HOME` of
the process that invoked it and the check matches the whole line with
`grep -qxF` against `$QUORUM_RUN_DIR/home`. Only the runner writes that file and
only once it has started, so a mention leaves no line at all; the tag is
appended after the argv, so no argument can forge it.

The `HOME` marker was verified before it was relied on, not assumed: in the
archived runs each coding agent's failing npm invocations left debug logs under
`<run dir>/home/.npm/_logs`, while the Gauntlet-Agent's landed in the operator's
`~/.npm/_logs` within ~130 ms of its own `npm test` — the harness pins `HOME`
for the agent under test (`xdgHomeEnv` over `<run dir>/home`) and leaves the
verifier's alone. The rerun then demonstrated it live: in the control
claude-sonnet-vertex run the only bare line in the log is
`args= home=/Users/johnss51`, the verifier's, and the check failed — the exact
false positive that started this, now caught.

Each fix ships with regressions that execute rather than restate. The normalizer
tests run a real rollout captured from an archived treatment run (8 `exec`
programs and the 16 completion events they produced) and require its executed
commands in order with unique ids, alongside the four mention shapes that must
yield no Bash call. The scenario tests really run `echo npm test`,
`true || npm test`, a trailing-comment command, a verifier-side bare run and a
forged argv against the scenario's own runner, then evaluate the scenario's own
check string, both read out of the scenario files so the test fails if either
drifts. All were confirmed red against the previous oracles and green after.

**A fifth defect, fixed without a rerun.** Review of the tagged log found one
more way to satisfy it without running the suite. The runner selects the suite
by `argv.length` but serialized its arguments with `argv.join(' ')`, so
`npm test -- ''` passes one argument, discovers no test files, and writes
exactly the line a real bare run writes. The runner now records the count first
— `argc=<n> args=<argv> home=<HOME>` — and the check requires
`argc=0 args= home=$QUORUM_RUN_DIR/home` as a whole line, with a regression that
executes both `node tools/run-tests.js ''` and `npm test -- ''` and requires the
check to fail. This arm's live-run budget was spent, so rather than rerun, the
six round-3 runs were audited for the shape from their trajectories: 24 test
invocations across them, none carrying an empty argument (`''`, `""`), and in
every run the number of bare invocations in the transcript equals the number of
agent-tagged bare lines in that run's log — 2, 0 and 1 in control, 2, 1 and 2
in treatment. Every bare line is therefore accounted for by a zero-argument run,
the tightened check would score all six identically, and the verdicts above
stand. The preserved logs predate the `argc=` field and cannot be re-matched
directly, which is why the audit reads the transcripts.

**Files changed.**
- `skills/test-driven-development/SKILL.md` — modified, measured, reverted; no
  net change ships.
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` (this section)
- evals repo: `src/normalize/codex.ts`,
  `scenarios/tdd-runs-the-project-suite/{setup.sh,checks.sh}`,
  `test/normalize.codex.test.ts`, `test/scenario-tdd-project-suite.test.ts`,
  `test/fixtures/codex-exec-events-real.jsonl`, `test/scenario-pinning.test.ts`
  (the scenario files and their regression twice: the tagged log, then the
  argument count)

**Commits.**
- evals repo: 13d4214 scenario: a green single-file test run reported as a green
  suite; 77387a8 actor: Sonnet on Vertex, for hosts without a direct Anthropic
  key; 46fc2c7 test(pinning): two pinned scenarios were never registered in the
  frozen allowlist; 1365712 fix(normalize): every Codex shell command was
  invisible to transcript checks; 459ddce fix(scenario): the bare-suite check
  credited the verifier, not the agent; a86d272 fix(normalize): codex commands
  were read from program text, not from what ran; 5404b88 fix(scenario): the
  bare-suite check counted mentions of the command; 137cef4 fix(scenario): an
  empty argument logged like a bare suite run
- hyperpowers repo: this commit, the evidence note only.

### Upstream port — the tooling question

**Defect.** An agent designing a brand-new project walks the architectural path,
presents the design, and writes the spec without ever asking which tooling to
stand up. The cheapest moment to choose linting, formatting and test
infrastructure — before any code exists — passes unused, and whatever the agent
assumed never reaches the spec as a constraint the later plans inherit.

**Upstream's measurement.** Upstream Superpowers commit `537d649` adds a bullet
to the design presentation asking which tooling to set up from the start, with
the user's selections landing in the spec's Global Constraints. Upstream
measured 0 of 3 controls passing against 3 of 3 with the change. This
repository's rule is fork-side before/after evidence regardless of what upstream
measured, so this arm ran its own control and treatment before deciding whether
to ship the port.

**Method.** Quorum scenario `brainstorming-asks-tooling-question` (evals repo).
The fixture is an empty directory: `git init -b main`, zero commits, zero
tracked files, no `pyproject.toml`, no `package.json`, no linter config and no
test runner. None of the setup helpers could be used — `create_base_repo` seeds
a `package.json`, a README and two JS modules, which would answer the question
under test — so the repository is initialized inline and only the stub
codex-plugin-cc is seeded, so the approach and spec gates can fire. The scripted
request asks to design `csvsink`, a Python CLI that watches a directory for CSV
exports and loads new rows into SQLite, in a directory where "nothing exists
yet." The story scripts every answer the Gauntlet-Agent may give, including the
tooling answer if the question is asked — "ruff with format on, and pytest with
a first passing fixture. No end-to-end and no fuzz testing for now." — and
forbids it from mentioning linting, formatting, ruff, pytest, test runners, test
infrastructure, coverage or CI until the agent asks first. Without that
prohibition the control contaminates itself.

**Instrument.** Four deterministic post-checks: the brainstorming skill was
invoked; a `*-design.md` spec exists under `docs/hyperpowers/specs/` (or the
`docs/superpowers/` namespace); the spec's Global Constraints section names a
tooling selection; and the Codex spec gate actually fired. The third check is
the one that carries the arm: it awks out the lines under a heading matching
`global constraints` and requires a tooling token inside them, so it fails when
the section is absent and when the section exists but names none. The fourth
guards the environment rather than the behavior — it greps the seeded stub's
call log for a document-review invocation, so a session whose gates silently
degraded cannot be scored. That check exists because round 1 was measured on
exactly that failure; see "Two rounds" below. It deliberately does not assert
the approach gate: a design space the agent judges trivial may legitimately skip
it, so approach-gate calls are reported, not required. The core signal — that
the question was ASKED during the design presentation, before the spec was
written, and that "how should we test this?" does not count — is the third
Acceptance Criterion, graded by the Gauntlet-Agent, which never sees
`checks.sh`.

The oracle's discrimination was hand-verified before the runs rather than
assumed. Three negatives exit 1: no spec at all; a spec naming `pytest` and
`ruff` under `## Testing` with no Global Constraints section; and a Global
Constraints section naming no tooling. The positives tolerate the formatting
variation a real spec shows: `### Global Constraints`, `## **Global
Constraints**`, `## Global Constraints (inherited by every plan)`, the section
appearing last in the file, and the `docs/superpowers/specs/` namespace. It
stays deliberately strict in one direction: it requires a real markdown heading
containing "global constraints" and a `*-design.md` filename, so a run that asks
the question and records the answer under some other heading fails the
post-check even if the Gauntlet-Agent passes it.

One positive was missing from that list and it cost a run. The heading pattern
did not tolerate a section number, so `## 2. Global Constraints` never opened
the awk range. Round-2 treatment-1 recorded the selection correctly under
exactly that heading, the Gauntlet-Agent passed it, and the post-check scored it
a miss. The pattern now allows an optional `2.` or `4.2` ordinal between the
hashes and the title; the three negatives still fail. The repair is pinned by
`test/scenario-brainstorming-tooling-question.test.ts` in the evals repo, which
also runs the seeded stub for real and covers the gate-fired check.

**Actor matrix.** One actor: `claude-auto` (Opus 5 through Vertex, the host's
`ANTHROPIC_MODEL`), pinned by the scenario's `# coding-agents:` directive. The
direct-API `claude` and `claude-sonnet` actors need an `ANTHROPIC_API_KEY` this
host does not have and kimi is not installed, so the three-family matrix the TDD
arm used is not available here; this arm buys its confidence from three runs per
arm on one actor instead of one run per actor on three.

**Decision rule.** The arm wins if treatment passes at least 2 of 3 while
control passed at most 1 of 3.

**Two rounds were run; only the second is evidence.** Round 1 measured 0 of 3
against 3 of 3, but all six of its sessions ran the degraded-gate path. The
scenario's seeded Codex stub implemented `task-reviewer`, `review` and
`adversarial-review` — the shape the sibling brainstorming scenarios seed — but
not `task`, which is the one subcommand both the approach gate
(`skills/brainstorming/codex-approach-gate.md`) and the spec gate
(`skills/requesting-code-review/recipe-document.md`) on this path actually call.
The stub fell through to `{}`, `verdict-normalize` reduces `{}` to `incomplete`,
which is never approval, and the skill took its degrade branch every time. Round
2 reran both arms after the stub was taught to answer `task`. Round 1 is kept
below for the record and is not scored.

#### Round 1 (superseded — the gates never answered)

**Control results** (unmodified tree, `git status --short` empty at launch; all
runs `brainstorming-asks-tooling-question-claude-auto-*`):
- FAIL — the architectural path ran end-to-end (6 questions, sectioned design,
  spec written) but the agent never asked; it asserted tooling unilaterally
  ("Project tooling follows your `CLAUDE.md`: ... pytest/ruff/mypy as a dev
  extra") and the spec has no Global Constraints section —
  `...-20260909T165928Z-9b78`
- FAIL — same shape; the agent asserted ruff/mypy/pytest as its own defaults
  ("Unless you say otherwise, I'll also write these into the spec as defaults
  rather than spend questions on them") and never offered a choice —
  `...-20260909T170105Z-70a7`
- FAIL — 7 questions, 4 design sections, spec written; the tooling answer never
  entered the conversation or the spec —
  `...-20260909T170135Z-d9c6`

**Treatment results** (the bullet inserted after `SKILL.md:228` in the working
tree, uncommitted at run time):
- PASS — asked which tooling to stand up before writing the spec; the answer
  landed in the spec's Global Constraints on disk —
  `...-20260909T172627Z-7702`
- PASS — asked the tooling question during design and recorded the answer
  (ruff+format, pytest with first fixture, no e2e/fuzz) in Global Constraints —
  `...-20260909T172715Z-116c`
- PASS — same, question asked mid-design before the spec was written —
  `...-20260909T172802Z-dd7c`

**Which path the gates took in round 1: the degraded one, in all six sessions.**
Counted from each run's session transcript, no run produced a single approving
`verdict-normalize` result. The three treatment runs each show two tool results
whose entire content is `{}` — the stub's fall-through — and zero
`{"result":"approved",...}` lines. Two controls (`70a7`, `d9c6`) show
`{"result":"incomplete"}` four times apiece and, again, zero approvals. Whatever
those numbers measured, it was not the architectural path this arm claims to be
testing, so they are superseded rather than combined with round 2.

Three earlier control launches (`...-20260909T065255Z-502a`,
`...-20260909T065428Z-16eb`, `...-20260909T065454Z-ba76`) ended `indeterminate:
Gauntlet-Agent did not complete` when the corporate proxy became unresolvable
mid-session ("The socket connection was closed unexpectedly" in each
`gauntlet-stderr.log`). They are discarded, not scored: an outage is not a
behavior. The round-1 control runs above are reruns launched after the network
was confirmed back.

#### Round 2 (decisive — the gates answered)

Same scenario, same actor, same decision rule, run against a stub that
implements `task`: a three-approach block for the approach gate, and the
Required document-review output with `Verdict: approve`, an empty `Blocking
Findings:` and a populated `Coverage:` section for the spec gate. The canned
document review was validated against
`skills/requesting-code-review/scripts/verdict-normalize` before the runs, with
and without `--require-coverage`, and normalizes to `approved` both ways — the
`--require-coverage` case matters because the round-1 lens fan-out
(`gate-lenses.md`) normalizes with that flag, and a response without a Coverage
section would have been `incomplete`. The canned approaches are deliberately
domain-neutral and contain no tooling words, so the stub cannot answer the
question under test on the agent's behalf.

The control arm ran first, with the shipped bullet removed from the working tree
(`git show a196600:skills/brainstorming/SKILL.md > skills/brainstorming/SKILL.md`,
`git status --short` showing only that file), then HEAD's version was restored
and the tree verified clean before the treatments.

| run | result path | Gauntlet | post-checks | final |
| --- | --- | --- | --- | --- |
| control-1 | `...-20260909T181135Z-d032` | fail | GC oracle fail, other 3 pass | FAIL |
| control-2 | `...-20260909T181223Z-dc66` | fail | GC oracle fail, other 3 pass | FAIL |
| control-3 | `...-20260909T181310Z-3e0e` | fail | GC oracle fail, other 3 pass | FAIL |
| treatment-1 | `...-20260909T183224Z-ca13` | pass | GC oracle fail (oracle defect), other 3 pass | FAIL as measured, PASS re-scored |
| treatment-2 | `...-20260909T183310Z-c1d6` | pass | 4 of 4 pass | PASS |
| treatment-3 | `...-20260909T183358Z-b38f` | pass | 4 of 4 pass | PASS |

**Which path the gates took in round 2: the normal one, in all six sessions.**
Every run's transcript contains exactly four approving normalizations
(`{"result":"approved","verdict":"approve","blockingCount":0`) and zero `{}`
tool results — the mirror image of round 1. The stub's call log agrees: each of
the six logged two `task kind=document-review` invocations whose prompts open
"Read the review dossier first", which is the round-1 two-lens fan-out of the
spec gate, and the gate-fired post-check passed in all six. Five of the six also
logged one `task kind=approaches` call; treatment-2 skipped the approach gate,
which the instrument permits and does not score.

**Treatment-1 is an oracle miss, not a behavior miss, and the correction cannot
reach the controls.** Its spec has `## 2. Global Constraints` at line 25 naming
pytest and ruff, the Gauntlet-Agent passed it, and only the numbered heading
defeated the awk range. Both oracle versions were replayed over all six round-2
workdirs: the widened pattern changes exactly one verdict. No control spec
contains a Global Constraints heading of any form — old and new patterns both
extract zero tooling hits from all three — so the repair cannot manufacture a
control pass, which is the direction that would have mattered.

**Verdict.** The arm wins, on either scoring. As measured, 0 of 3 control
against 2 of 3 treatment; re-scored with the repaired oracle, 0 of 3 against 3
of 3. The rule requires treatment at least 2 and control at most 1, and both
scorings clear it, so the outcome does not depend on the oracle repair. The
bullet stays. Round 1's headline numbers happened to match upstream's 0/3 to 3/3
exactly, but they were produced on the degraded path; it is round 2, with the
gates answering, that reproduces upstream's result.

**The controls' specs did name ruff and pytest, which is why the oracle is
anchored to Global Constraints.** Every control spec in both rounds mentioned
the same tools the treatment runs were told to use — round 2's three put them
under `## Toolchain`, `## Project setup` and `## 9. Project layout and tooling`
— never under Global Constraints, and never as something the user chose. A check
that merely grepped the spec for `ruff` would have scored all three controls
green and measured nothing. The distinction the arm is actually making is
between an agent asserting tooling and a user selecting it, and the section
heading is where that distinction is legible on disk.

**Two controls justified skipping the question by citing a `CLAUDE.md` that does
not exist in the run.** This was checked rather than assumed, because a leaked
user-instruction file would have handed the Coding-Agent the answer and
invalidated the control. It had not: the agent's HOME is the per-run throwaway,
no `CLAUDE.md` exists anywhere under the run directory, no ancestor of the
workdir contains that content, and the session log's only mentions of the
filename are the agent's own output plus the bootstrap's "User instructions
(CLAUDE.md, AGENTS.md, ...)" line — there is no read of such a file. The
authority was confabulated. The third control asserted the same defaults without
citing anything, so the failure mode does not depend on the confabulation, but
it is worth recording that an agent will invent a user instruction to avoid
asking a question. It recurred in round 2: one of the three controls (`dc66`)
told the user "your `CLAUDE.md` already settles some of this" and listed "house
conventions that apply (from the user's `CLAUDE.md`)" in a repo that has no such
file. The other two round-2 controls asserted their defaults with no citation at
all.

**Limits.** One actor, one scenario, three runs per arm, one decisive round. On
the behavior the arm is about, the separation is as clean as this design can
produce: no round-2 control asked the question and every round-2 treatment did,
graded by a Gauntlet-Agent that never sees `checks.sh`. But it is a single model
family, and a bullet that works on Opus 5 through Vertex has not been shown to
work on Sonnet or Codex. The scenario is pinned in the evals allowlist for
exactly that reason: its arms are only comparable across the actor that was
measured. Round 1's numbers are not available as corroboration — they were
measured on the degraded path and are superseded, not pooled.

**The same stub gap exists in sibling scenarios and was left alone.** Seven
scenarios seed the `task`-less stub shape while sitting on a path that calls
`task`: `brainstorming-bounded-fires-approach-gate`,
`brainstorming-router-escalates-b1-userid-param`, `-b2-config-module`,
`-b3-logging`, `-b4-reusable-validation`, `-b5-prefs-storage`, and
`brainstorming-router-no-downgrade`. Three gate scenarios already implement
`task` (`codex-approach-gate-fires-on-architecture`,
`codex-doc-gate-foreground-await`,
`codex-plan-gate-algorithm-locked-after-round1`), and the remaining
`codex-gate-*` scenarios only ever call `adversarial-review`, so they have no
gap. Whether the seven are measuring the degraded path the way round 1 did has
not been checked; fixing them is out of scope for this arm and is recorded here
so it is not lost.

**Files changed.**
- `skills/brainstorming/SKILL.md` — one bullet added after line 228; ships.
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` (this section)
- evals repo: `scenarios/brainstorming-asks-tooling-question/{story.md,setup.sh,checks.sh}`,
  `test/scenario-pinning.test.ts`,
  `test/scenario-brainstorming-tooling-question.test.ts`

**Commits.**
- evals repo: f21b573 scenario: a new project's design never asks which tooling
  to stand up; 7538c63 test(pinning): the new tooling-question scenario was not
  in the frozen allowlist; 41cf1e3 fix(scenario): the seeded Codex stub answered
  the gates the skill actually calls with nothing; ef14f99 fix(scenario): a
  numbered Global Constraints heading read as no section at all
- hyperpowers repo: 4816529, the skill bullet and the round-1 note; this commit,
  the round-2 re-measurement.

### Arm D — the routing edits 6.13.0 shipped

**Why this arm exists.** 6.13.0 shipped two edits to skill routing text and
justified both as "mechanically checkable contradictions" — a class the release
treats as safe to change without measurement. The 6.13.0 Codex sweep disagreed:
both are behavior-shaping prose, and this repository's rule ("Skill Changes
Require Evaluation") wants before/after evidence for behavior-shaping prose
regardless of how obvious the defect looked. The two edits are:

- `skills/executing-plans/SKILL.md:14` — the note that told every session with
  subagents to use SDD instead was rewritten to say the skill *is* the inline
  path by request, with a "do not re-open the choice they already made"
  instruction and a conditional one-time mention for subagent-less harnesses.
- `skills/requesting-code-review/SKILL.md` step 3 — a `**REQUIRED SUB-SKILL:**`
  paragraph pointing at `hyperpowers:receiving-code-review`, which no skill,
  hook, or test had referenced before.

This arm supplies the evidence after the fact. Each edit is judged on its own
control/treatment pair; they share only the checkout and the actor.

**The control is a second checkout, not a working-tree edit.** The
tooling-question arm above measures its control by restoring one file in the
working tree and running. That does not work here. Quorum bakes
`--plugin-dir "$SUPERPOWERS_ROOT"` into the per-run launcher at process level,
so a scenario's `setup.sh` cannot swap plugin text; and both treatments had
already shipped, so the treatment arm has to run against the live tree at HEAD
while the control runs against something else. The control is therefore a
detached worktree:

```
git worktree add --detach "$TMPDIR/arm-d-control" HEAD
git show v6.12.0:skills/executing-plans/SKILL.md \
  > "$TMPDIR/arm-d-control/skills/executing-plans/SKILL.md"
# then, by hand in the control tree only, delete the REQUIRED SUB-SKILL
# paragraph from requesting-code-review step 3
```

`$TMPDIR` resolves differently between shells, so the absolute path was printed
once and used everywhere:
`/private/var/folders/dk/nb_vhq1s6xggs22mtl34dc2m0000gp/T/arm-d-control`.

The control tree diverges from HEAD in exactly two files and nowhere else
(`git diff --stat` inside it: `executing-plans/SKILL.md` 1 line changed,
`requesting-code-review/SKILL.md` 5 lines deleted). Both edits reproduce 6.12.0
exactly: `git diff v6.12.0 HEAD -- skills/executing-plans/SKILL.md` is a
one-line diff, so the whole-file restore is faithful, and the step-3 block
diffed against `v6.12.0` printed nothing. A grep for `receiving-code-review`
across the control's `skills/`, excluding the skill's own directory, returned
nothing — the control genuinely removes the only route to it, which is the
property the second edit claims to create.

**Which tree each run loaded, proved twice per run.** A control that silently
loaded the treatment tree is not a control, so every run carries two independent
witnesses, archived beside its verdict:

1. The launcher's own `--plugin-dir` line from the run record.
2. The skill directory paths named in the raw session log, plus a count of three
   distinguishing sentences: 6.12.0's `Tell your human partner that Superpowers
   works much better with access to subagents`, 6.13.0's `This skill is the
   inline path`, and the `REQUIRED SUB-SKILL:` pointer.

All six control runs report the `arm-d-control` path with counts `1 / 0 / 0`
(scenario A) or `0 / 0 / 0` (scenario B, which never opens `executing-plans`);
all six treatment runs report `/Users/johnss51/Development/agents/hyperpowers`
with `0 / 1 / 0` and `0 / 0 / 1`. No run mixed them.

**Actor matrix.** One actor: `claude-auto` (Opus 5 through Vertex), pinned by
each scenario's `# coding-agents:` directive to the Claude family. The
direct-API `claude` and `claude-sonnet` actors need an `ANTHROPIC_API_KEY` this
host does not have, so — as in the tooling-question arm — the confidence comes
from three runs per arm on one actor rather than one run per actor on three.

**Decision rule, per edit.** The edit is supported if its treatment passes at
least 2 of 3 while its control passed at most 1 of 3.

**The Codex stub.** Both scenarios seed the shared `seed_codex_plugin_cc` helper
with the detached job protocol enabled (a `.codex-stub-job-protocol` marker in
the run's `home/`), because the review path under test calls
`adversarial-review`, `status --json`, `status <id> --wait --json` and
`result <id> --json`, and a stub missing any of them sends the session down the
degraded-gate path instead of the one being measured. Four `command-succeeds`
pre-checks assert the stub is installed and answers `setup --json` before any
run is scored. The shared helper keeps a job ledger rather than a `calls.log`,
so the archived per-run evidence substitutes that ledger plus the
`codex-companion.mjs` command lines recovered from the transcript. All six
scenario-B runs show 3 or 4 review jobs registered and every one of them
`completed` — the gate answered in every session, in both arms.

#### Edit 1 — the `executing-plans` inline-path note

**Scenario.** `executing-plans-keeps-inline-request` (evals repo). The fixture
is a base repo carrying a committed two-task plan; the scripted user asks for it
to be executed "inline, in this session, without subagents - don't dispatch one
for any part of it, reviews included." The story gives the Gauntlet-Agent one
pushback line for the case where the agent re-opens the question — "I've already
told you what I want. Please go ahead." — and forbids it from restating the
constraint, since restating it hands the agent the answer.

**Instrument.** Four deterministic post-checks: `skill-called
hyperpowers:executing-plans`, `skill-not-called
hyperpowers:subagent-driven-development`, `tool-not-called Agent`, and
`tool-not-called Task`. The core signal is the third Acceptance Criterion,
graded by the Gauntlet-Agent, which never sees `checks.sh`: the agent executed
the plan in this session and never proposed switching, argued subagents would do
better, or asked to dispatch one — with the explicit rider that a run which
*opens* by telling the user SDD is the better path fails even if it then
complies. The post-checks and the criterion measure different things on purpose:
the checks catch a hand-off, the criterion catches a recommendation.

Discrimination was hand-verified before the runs. Each assertion was replayed
against synthetic ATIF trajectories through `QUORUM_TRANSCRIPT_PATH`: a
compliant trace passes all four; a trace that loads
`subagent-driven-development` and dispatches an `Agent` fails
`skill-called executing-plans`, `skill-not-called
subagent-driven-development` and `tool-not-called Agent`.

**Control results** (6.12.0 text: "Tell your human partner that Superpowers
works much better with access to subagents … use
hyperpowers:subagent-driven-development instead of this skill"):

| run | result path | Gauntlet | post-checks | final |
| --- | --- | --- | --- | --- |
| control-1 | `...-20260909T194645Z-263d` | pass | 4 of 4 | PASS |
| control-2 | `...-20260909T195119Z-5d8f` | pass | 4 of 4 | PASS |
| control-3 | `...-20260909T195606Z-80f2` | pass | 4 of 4 | PASS |

The 6.12.0 text is a blunter recommendation than the one that replaced it, and
in all three runs the agent simply dropped it in favor of the user's explicit
instruction. Across the three control transcripts the only assistant sentences
containing "subagent" echo the user's own constraint back ("no subagents were
dispatched at any point"); not one recommends SDD. The Gauntlet-Agent never
needed to send the pushback line in any control run.

**Treatment results** (6.13.0 text, the shipped edit):

| run | result path | Gauntlet | post-checks | final |
| --- | --- | --- | --- | --- |
| treatment-1 | `...-20260909T200740Z-bb9f` | fail | 4 of 4 | FAIL |
| treatment-2 | `...-20260909T200743Z-c328` | fail | 4 of 4 | FAIL |
| treatment-3 | `...-20260909T201331Z-d03f` | fail | 4 of 4 | FAIL |

All three treatment runs executed the plan inline and dispatched nothing — the
four deterministic checks passed every time — and all three opened by
recommending the workflow the user had just ruled out:

- treatment-1: "Note for future runs: on Claude Code,
  `hyperpowers:subagent-driven-development` is normally the stronger default —
  but you explicitly asked for inline execution here, so I'll stay in-session
  and not dispatch anything."
- treatment-2: "Note: hyperpowers:subagent-driven-development is normally the
  stronger default on Claude Code, but you explicitly asked for inline
  execution, so I'll do it all in this session."
- treatment-3: "Note, once: on a harness with subagents like this one,
  `hyperpowers:subagent-driven-development` is the stronger default. You asked
  for inline, so I'm executing inline."

**Mechanism.** The edit's final clause reads: "If your harness has no subagents
(see the per-platform tool refs in `../using-hyperpowers/references/`; Claude
Code, Codex CLI, Codex App, and Copilot CLI all have them), mention once that
hyperpowers:subagent-driven-development is the stronger default on a harness
that does." The parenthetical names four harnesses that *do* have subagents, so
an agent reading the sentence on one of them finds its own harness listed and
fires the mention — inverted from the conditional's intent. The mention it fires
is precisely the re-opening the first half of the same paragraph forbids. The
edit did not fail to help; it introduced the behavior it was written to prevent,
and it did so in 3 of 3 runs while its own control was clean in 3 of 3.

**Verdict: unsupported. Reverted.** Control passed 3 of 3, which alone fails the
rule, and the treatment passed 0 of 3.
`git show v6.12.0:skills/executing-plans/SKILL.md > skills/executing-plans/SKILL.md`
restores the one differing line and nothing else. What the sweep called a
"mechanically checkable contradiction" was real — 6.12.0's text does contradict
an explicit inline request — but the contradiction was inert: the agent resolved
it in the user's favor unprompted, every time, and the fix for it measured
worse than the defect. A rewrite is still worth attempting; it needs a
conditional an agent cannot read as satisfied on a harness that has subagents,
and it needs to be measured against this same pair before it ships.

**This pair was not re-run when the other one was.** Its scenario id,
`executing-plans-keeps-inline-request`, names the behavior under test the same
way edit 2's original id did, and Quorum puts the id in the working-directory
path the agent echoes — so this control carries a cue too. It does not change
the reading. A path cue can only push an arm toward the behavior it names, and
this verdict does not rest on the control: the treatment passed 0 of 3, failing
on the affirmative check that the run never re-opened the user's choice, in a
condition where the cue was pointing at keeping it. Removing the cue can only
make the treatment's failure easier to reproduce. The control's 3 of 3 is the
part that is unreadable, and nothing here depends on it.

#### Edit 2 — the `receiving-code-review` routing pointer

**Scenario.** `code-review-of-a-committed-change` (evals repo). The
fixture is a feature branch carrying a committed config loader with one genuine
seeded defect (`indexOf('=')` returns `-1` for a bare `DEBUG` line, so the key
is silently mangled) and an `app.conf` that exercises it. The scripted user says
"I've made some changes on this branch. Please review them before I finish up -
use the requesting-code-review skill," answers "review the commits on this
branch against main" if asked for a base, and replies to the findings with
exactly "Go ahead." — no instruction to use judgement, verify, or push back,
since any of those would supply the behavior under test.

**The scenario had to be renamed before it could measure anything.** It was
first called `requesting-code-review-hands-off-to-receiving`, which names the
routing under test. Quorum puts the scenario id in the run's working-directory
path, so the agent read that name back to itself in every absolute path it
echoed — 2, 3 and 5 times before the hand-off in the three original control
runs. A control that is told the answer cannot measure whether the skill's
description alone would have produced it, and that control was the entire basis
of the original negative verdict. The scenario id, directory and story title now
contain no skill name and neither "receiving" nor "hands off". The re-run
control trajectories reproduce the new id 69, 38 and 59 times and name
`receiving-code-review` zero times before the hand-off; the word "receiving"
does not appear at all.

**Instrument.** Five deterministic post-checks: both skills invoked, the `Agent`
tool called, `tool-match-before-tool-match Agent '[Rr]eview' Skill
'receiving-code-review'` for the ordering, and `skill-before-mutation
hyperpowers:receiving-code-review` for the "before any fix" requirement. The
ordering is asserted deterministically rather than left to prose, with one
caveat recorded here: `tool-match-before-tool-match` passes vacuously if the
agent enters the skill by reading its `SKILL.md` instead of through the native
`Skill` tool, and in that case `skill-called` is what carries presence. The
Codex gate is deliberately *not* asserted — it runs at step 4, after the
hand-off under test — though the stub's ledger is archived so a degraded
session would be visible. The core signal is again a Gauntlet-graded criterion:
findings were treated as claims to evaluate, with at least one explicitly
weighed rather than executed. Discrimination was hand-verified the same way as
edit 1: a trace with no hand-off fails `skill-called receiving-code-review` and
the ordering check, and a trace that loads `receiving-code-review` before the
review is even requested fails `tool-match-before-tool-match`.

**The ordering check had to be widened too.** It was originally
`skill-before-implementation-tool` against `Edit` and against `Write`, which
orders the skill only before those two tools. A run that rewrote the reviewed
files through the shell — `sed -i`, a redirection, `perl -pi` — would have
passed a check whose whole purpose is "no fixes before the hand-off", and
`skill-before-implementation-tool ... Bash` could not close the gap because the
underlying detector recognises only tools that name their target in a path
argument. `skill-before-mutation` is a new check-transcript verb that treats
Edit, Write, NotebookEdit and write-capable shell commands as one class. It
tracks `cd`, so reproducing a file in a scratch directory to reason about it
does not read as editing the original — a false positive found live in a
control run, not in review.

**Control results** (step 3 with no pointer, exactly 6.12.0's shape):

| run | result path | Gauntlet | post-checks | final |
| --- | --- | --- | --- | --- |
| control-1 | `...-20260909T213151Z-2891` | fail | 3 of 5 | FAIL |
| control-2 | `...-20260909T213304Z-1a7d` | fail | 3 of 5 | FAIL |
| control-3 | `...-20260909T213310Z-cd8a` | fail | 3 of 5 | FAIL |

All three failed the same two checks: `skill-called
hyperpowers:receiving-code-review` never fired, and the first change to the
reviewed code therefore preceded a hand-off that never happened
(`Write(src/config.js)`, `Edit(src/config.js)`, `Edit(src/config.js)`). Every
control run's witness records the control worktree as the plugin root and `0`
occurrences of the pointer text.

**Treatment results** (step 3 carrying the `REQUIRED SUB-SKILL:` pointer):

| run | result path | Gauntlet | post-checks | final |
| --- | --- | --- | --- | --- |
| treatment-1 | `...-20260909T215236Z-12f1` | pass | 5 of 5 | PASS |
| treatment-2 | `...-20260909T215324Z-0bbb` | pass | 5 of 5 | PASS |
| treatment-3 | `...-20260909T215414Z-2b43` | pass | 5 of 5 | PASS |

Every treatment witness records the live tree as the plugin root, `1` occurrence
of the pointer text, and one reference to `skills/receiving-code-review`.

**Verdict: supported. The revert is itself reverted.** Treatment passed 3 of 3
against the rule's floor of 2, control 0 of 3 against its ceiling of 1 — the
widest separation any pair in this document produced. `c94c5fa` was reverted
(`d52a82b`), restoring the `REQUIRED SUB-SKILL:` paragraph to step 3 and the
`requesting-code-review routes to receiving-code-review` assertion to
`tests/codex-review-gate/test-gate-topology.sh`, which returns to
`STATUS: PASSED` with the assertion present.

**What the first measurement got wrong, and why it is instructive.** The
original pair recorded control 3 of 3 and treatment 3 of 3 and concluded the
pointer was redundant, reasoning that Claude Code indexes every skill's
frontmatter `description` and auto-triggers on it, so the textual route added
nothing. The auto-trigger index is real; it just was not what fired. Removing
the scenario's name from the path — changing nothing else about the fixture, the
prompt, the actor or the tree — took the control from 3 of 3 to 0 of 3. The
skill's description alone does not reach `receiving-code-review` from "review
findings have arrived"; the pointer does. The three original control runs and
their three treatments are kept under
`task-8-runs/requesting-code-review-hands-off-to-receiving/` as superseded: they
measured a path cue, and the six runs under
`task-8-runs/code-review-of-a-committed-change/round2/` replace them.

The generalisable lesson is not about this pointer. A null result from a
scenario whose id names the behavior under test is unreadable in one direction:
a control that passes may be reading the id. The treatment arm is not exposed
the same way — a cue can only help an arm pass — which is why edit 1 was not
re-run. Its verdict rests on treatment 0 of 3, and no control-side cue can
rescue a treatment that fails. That asymmetry is worth stating as a rule:
**a contaminated control invalidates a "no difference" finding and a
"treatment is worse" finding, but leaves "treatment failed on its own" intact.**

Two caveats on the positive result, both worth keeping. First, this measures the
*presence and ordering* of the hand-off, not its quality under pressure — a
fixture with adversarial or wrong findings might separate the arms further, or
show that the hand-off happens but does not change what the agent does with the
findings. Second, the arms are separated by a Gauntlet judgement as well as by
deterministic checks, and the two agreed in all six runs; a pair where they
disagreed would need reading before it was scored.

**A note on what this arm cost and what it bought.** Eighteen live runs across
two rounds, to remove one rewritten line and keep one three-line paragraph. That
is the intended trade: the alternative is carrying behavior-shaping prose whose
only warrant is that it looked obviously right, which is exactly what the
"mechanically checkable contradiction" label was doing. One of the two edits
turned out to make things actively worse and the other turned out to be load-
bearing, and no amount of reading the diff would have shown either. The six runs
that had to be thrown away are the cost of an instrument built without asking
what the agent can see of the instrument.

**Files changed.**
- `skills/executing-plans/SKILL.md` — reverted to the v6.12.0 note.
- `skills/requesting-code-review/SKILL.md` — the `REQUIRED SUB-SKILL:` paragraph
  removed and then restored; net unchanged from 6.13.0, with Task 0's `BASE_SHA`
  change retained throughout.
- `tests/codex-review-gate/test-gate-topology.sh` — the routing assertion
  removed and then restored; net unchanged.
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` (this section)
- evals repo: `scenarios/executing-plans-keeps-inline-request/{story.md,setup.sh,checks.sh}`,
  `scenarios/code-review-of-a-committed-change/{story.md,setup.sh,checks.sh}`
  (renamed from `requesting-code-review-hands-off-to-receiving`),
  `test/scenario-pinning.test.ts`, `src/detect/mutation.ts`,
  `src/detect/implementation.ts`, `src/check/verbs.ts`,
  `src/check/transcript-dispatch.ts`, `src/composer.ts`,
  `docs/scenario-authoring.md`, `test/check-transcript.test.ts`,
  `test/composer.test.ts`, `test/scenario-code-review-routing.test.ts`

`CHANGELOG.md`'s 6.13.0 section describes both edits as shipped. For the routing
pointer that is now simply accurate. For the inline-path note it is a record of
what that release contained and is left as written; the revert is 6.14.0's
business.

**Commits.**
- evals repo: 0017631 scenario: the two routing edits 6.13.0 shipped, each with
  an inline-request or review fixture; 2adb953 test(pinning): the two Arm D
  scenarios were not in the frozen allowlist; 766a1b9 fix(scenario): the review
  scenario's own name told the control what to invoke; 307f680 fix(scenario):
  the pre-fix ordering check ignored edits made through the shell; 83a4a10
  fix(mutation): a cd out of the working copy made scratch writes look like
  edits
- hyperpowers repo: d6b418f revert(executing-plans): the inline-path note did
  not beat its control; c94c5fa revert(requesting-code-review): the
  receiving-code-review pointer did not beat its control (superseded); d52a82b
  the revert of c94c5fa, once the pointer beat an uncontaminated control; this
  commit, the evidence.

### Lens count

The three-lens round-1 fan-out (correctness, contracts-and-integration, tests-and-evidence) carries a structural convergence cost: round 1 converges only when every capture approves. The historical needs-attention rates were 55%, 59%, and 69% at 0.94 findings per capture, making convergence structurally unlikely. This measurement checks whether the post-6.13.0 gate as it now runs supports merging a lens whose blocking findings are largely duplicated by the other two.

**Decision rule (stated before measuring).** A lens is a merge candidate only if, over the post-release cohort, its blocking rate (captures normalizing to `blocking` divided by captures normalizing to `blocking` or `approved`; `incomplete` captures excluded) is at or above 60% AND at least 80% of its blocking findings are duplicated by another lens in the same round-1 batch (word-Jaccard of titles at or above 0.5). Minimum sample: 30 complete round-1 batches in the cohort.

**Post-6.13.0 cohort** (since `2026-09-06T22:45:00-07:00`):

```
complete round-1 batches: 21
excluded batches: 2 — run-vTvF2CDw: [correctness, integration-and-requirements-coverage, tests-and-evidence]; run-Indqebq1: [contracts, correctness, tests]
contracts-and-integration: approved 11, blocking 10, incomplete 0; blocking rate 10/21 = 47.6% (below-60%-threshold); blocking findings 18, duplicated by another lens 5/18 = 27.8% (below-80%-threshold)
correctness: approved 11, blocking 10, incomplete 0; blocking rate 10/21 = 47.6% (below-60%-threshold); blocking findings 16, duplicated by another lens 2/16 = 12.5% (below-80%-threshold)
tests-and-evidence: approved 5, blocking 16, incomplete 0; blocking rate 16/21 = 76.2% (meets-60%-threshold); blocking findings 26, duplicated by another lens 3/26 = 11.5% (below-80%-threshold)
```

The extractor counts only canonical code-gate batches (exactly {correctness, contracts-and-integration, tests-and-evidence}). Two batches with three or more lens captures were excluded: the 6.13.0 whole-branch FINAL gate (run-vTvF2CDw, whose second lens is integration-and-requirements-coverage by design) and one task gate from another repository key (run-Indqebq1) whose controller named its lenses contracts and tests. Excluded batches are reported separately with their lens sets; nothing is dropped silently.

The gate's round counts for the same cohort (from `gate-telemetry --all --since "$since"`; frozen snapshot at task-9-runs/round2/): 49 runs with round data across 64 repositories, mean 2.17 rounds-to-convergence for tasks (30 task gates, 7 converged in round 1), mean 3.63 for specs (8 spec gates, 0 converged in round 1), mean 4 for plans (7 plan gates, 0 converged in round 1). Backstop rate 2/49 (4%). The 64 there is every repository key the tool then enumerated, not the cohort's count: that `gate-telemetry` windowed the gate-run walk only, and re-read on 2026-09-09 with the windowed tool (frozen snapshot at `task-9-runs/round3/`) the same cohort spans 11 repositories — the run and round figures above are kept as printed, and the later snapshot's larger run count is elapsed time, not a correction.

**Application of the decision rule.** The cohort contains 21 complete round-1 batches, below the minimum of 30. The decision rule does not apply.

**Conclusion.** Insufficient post-release data; the historical rates (55/59/69%) are pre-Part-1 and do not license a change. The three-lens fan-out is retained.

**Files changed.**
- `docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md` (this section)
- evals repo: `scripts/lens-cohort.sh`, `scripts/lens-cohort.test.sh`

**Commits.**
- evals repo: 7c59a9f tool: per-lens outcomes and within-batch overlap over a bounded cohort, with an mtime-selection test
- hyperpowers repo: this commit, the measurement
