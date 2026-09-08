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

**Task 2's Codex gates.** After the first implementation (round 1), this task's own three-lens code gate returned four blocking findings and one medium. The human partner amended the spec's D7 and the Part 2 success criteria on 2026-09-07: the arm is judged on classification accuracy over the production round-1 prompt shape. After the round 2 implementation, the gate's second run found one blocking defect: the runner's base-stripping filter tested each line after `trim()` while several alternatives still required leading spaces, so it left the inner closing brace and also left `return Number(body) / 100` in M and O. All three generated bases failed `node --check` (the reviewer reproduced it against the preserved round-2 worktrees). Every one of the 18 round-2 reviews therefore compared against a broken program, not the working pre-change module, invalidating the round 2 result. Round 3 fixed this with checked-in `lib.base.js` files and assertions that both revisions parse and pass tests before reviewing.

**Prompt shape.** Rounds 2 and 3 measured the production round-1 focus: the correctness lens skeleton (dossier line, charter, exhaustiveness demand, required Coverage section) followed by the per-task recipe's complete adversarial-review focus string. Control = the original recipe text without calibration (from commit b015394, recipe-code.md line 53); treatment = with the reworded calibration.

**Fixtures (rounds 2 and 3).** **M**: defect-free implementation of the percent-string branch (trim and NaN on empty body, as required). **H**: crash-and-wrong-result defect (unanchored regex returns wrong values for `-25%`, `.5%`, `1e2%`, and throws on `"%"`). **O**: omitted requirement (parseRate is correct but formatRate is missing, a requirement the task was asked to meet and omits).

**Reviewer.** gpt-5.6-sol at xhigh reasoning effort.

**Decision rule (as amended 2026-09-07 with D7).** The arm wins if treatment H and treatment O each block 3 of 3 AND treatment M is approved in at least 2 of 3; control numbers are recorded beside them.

**Round 3 control arm results** (capture directory: `$TMPDIR/focus-arm-r3/control/`):
- M control 1: approved
- M control 2: approved
- M control 3: approved
- H control 1: approved (defect found, rated non-blocking)
- H control 2: approved (defect found, rated non-blocking)
- H control 3: blocking
- O control 1: blocking
- O control 2: blocking
- O control 3: blocking

**Round 3 treatment arm results** (capture directory: `$TMPDIR/focus-arm-r3/treatment/`):
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

**Files changed.**
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
62 assertions (22 to 84): the derived ceilings for `--consumed` 0, 2, and 5; `consumed` in
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
