# External workflow adoption — eval evidence

**Spec:** `docs/hyperpowers/specs/2026-09-10-external-workflow-adoption-design.md`
**Plan:** `docs/hyperpowers/plans/2026-09-10-external-workflow-adoption.md`
**Plan date:** 2026-09-10
**Measured:** baseline 2026-09-12, hardened baseline 2026-09-12, treatment
2026-09-13, sentinel re-run 2026-09-14, sentinel tier re-measured 2026-09-15,
read from the run-id timestamps
**Treatment head (S1):** `d0a187d64e62587131f9c9ff4f59988d257b6b26`
**Re-measured head (sentinel tier):** `bad92ad079783032c1e2431e624ea0c09cc67f31`
— see "Re-measured at `bad92ad`" under Sentinel tier for why there are two
**Governing adjudication:**
`evidence/2026-09-10-external-workflow-adoption/task-19-runs/adjudication.md`,
in hyperpowers-evals at `c615efc488a091f6be867f174c983c5353b7a252`, restated
for the re-measured head by
`evidence/2026-09-10-external-workflow-adoption/task-23-reruns/adjudication-remeasurement.md`
at `5a9f2c9`

## What was measured

Ten items were adopted from two external workflows and put behind evidence.
Four carry an observable behavioral claim and have a live scenario; the other
six ship on contract tests plus the sentinel tier as regression.

Only one of the four reached a treatment arm. Task 9 hardened S2, S3 and S4 and
the unassisted baseline still met acceptance in all three, which settled A2, A4
and A7 as no-ships before a single treatment trial was spent. Their prose was
never implemented on this branch, so they are recorded below as routing-line
no-ships rather than as removals: there was nothing to remove.

The Outcome column restates the governing adjudication's verdict for each
item. The two tables do not share columns — the adjudication records
`Item | Scenario | Verdict | Basis` — so each Outcome condenses that row's
Verdict with the operative part of its Basis rather than reproducing a cell
verbatim. Where the two differ, the adjudication governs.

| Item | Surface | Evidence | Outcome |
|---|---|---|---|
| A1 reviewer noise control | `code-reviewer.md`, `task-reviewer-prompt.md` | S1, contract needles | ships |
| A2 gate boundary | SDD fix loop, both reviewer prompts, writing-plans | S2 (reviewer side) | does not ship; never implemented |
| A3 findings are claims | `gate-findings.md`, `gate-fix-loop.md`, SDD | contract needles | ships (contract tests + sentinel tier) |
| A4 red loop | `systematic-debugging/SKILL.md`, `red-loop.md` | S3 | does not ship; never implemented |
| A5 grounding and Mirror | `writing-plans/SKILL.md`, `implementer-prompt.md` | contract needles | ships (contract tests + sentinel tier) |
| A6 named unknowns | `writing-plans/SKILL.md`, `brainstorming/SKILL.md` | contract needles | ships (contract tests + sentinel tier) |
| A7 facts are the agent's job | `brainstorming/SKILL.md` | S4 | does not ship; never implemented |
| A8 delegation completion | `dispatching-parallel-agents/SKILL.md`, SDD | contract needles | ships (contract tests + sentinel tier) |
| A9 stale-replay notice | `hooks/session-start` | hook tests | ships (contract tests + sentinel tier) |
| A10 pruning and expiring baselines | `writing-skills/SKILL.md` | contract needles | ships (contract tests + sentinel tier) |

For A2, A4 and A7 the Surface column is the surface each item was designed to
touch, not a surface this branch changed. Nothing was written for them. The
distinction matters most for A2, whose intended surfaces — the SDD fix loop,
both reviewer prompts, `writing-plans` — were all edited on this branch for
other items; and it is directly checkable for A4, which would have added
`skills/systematic-debugging/red-loop.md`, a file the branch does not carry.

## Arms

Both arms ran the coding agent `claude-auto` on model `claude-opus-5`. That id
is read from both governing arm headers and the two strings are identical:
`task-8-runs/baseline/measurements.md` line 5 and
`task-19-runs/treatment/measurements.md` line 8 each read
"Coding agent: `claude-auto`, model `claude-opus-5`."

Three trials per arm throughout. Two arms — a baseline and a treatment — exist
for S1 only. S2, S3 and S4 have a baseline arm and no treatment arm at all.

The actor is `claude-auto` rather than the plan's literal `claude` because
`claude`'s `required_env` includes `ANTHROPIC_API_KEY`, which is empty on this
Vertex-only host, so that actor cannot provision. `claude-auto` is the same
Claude binary at the host's session-default model. All three arm files record
the substitution, and it is the same actor in every arm, so the comparison is
not crossed by it.

The harness was not one commit, and this note names each revision rather than
flattening them:

- Baseline (Task 8, all four scenarios): hyperpowers-evals
  `18f5f25b2466ba84da21f70f7d9efa2dddb76757`.
- Hardened baseline (Task 9, S2/S3/S4):
  `9f49c2b1ccfff1db0515ac06e1d37593f60053de`, which is both the hardening
  commit and the harness commit every trial in that arm ran on.
- Treatment (Task 19, S1): `d8d8df6ae775e36acf9b453fb3a35eba9568f1cf` for the
  first four runs, and `0edf098` for `b15c` and `0eb0`, which started after
  that commit landed. `git diff --name-only d8d8df6 0edf098` lists 487 paths
  and none outside `evidence/`, so the harness code was identical across all
  six runs. The arm also cleared Task 9's fixture floor: `git merge-base
  --is-ancestor e074014 HEAD` was checked before the first trial and its output
  is at the top of the arm's runner log.

Arm heads in this repository:

- Baseline: hyperpowers at branch-point commit
  `f5a9843bc8c3e1ef3b7d7ec631a9f94605173e3e`, before any of the prose above
  existed.
- Treatment: hyperpowers at `d0a187d64e62587131f9c9ff4f59988d257b6b26`.

Cited artifact paths, all in the hyperpowers-evals repository under
`evidence/2026-09-10-external-workflow-adoption/`:

| Scenario | Baseline arm | Treatment arm |
|---|---|---|
| S1 | `task-8-runs/baseline/` | `task-19-runs/treatment/` |
| S2 | `task-9-runs/baseline-hardened/` | none (settled before treatment) |
| S3 | `task-9-runs/baseline-hardened/` | none (settled before treatment) |
| S4 | `task-9-runs/baseline-hardened/` | none (settled before treatment) |

### Three fixtures were hardened, and S1 was not

Task 8's unassisted baseline met acceptance in every trial of S2, S3 and S4.
A scenario an unassisted agent already passes cannot discriminate — the
treatment arm can only match it — so Task 9 hardened each one and re-ran the
baseline against the hardened fixture, all at
`9f49c2b1ccfff1db0515ac06e1d37593f60053de`:

- S2 gained a fourth planted weakening, a summation assertion narrowed from
  `assert.equal(cartTotal([...]), 950)` to `assert.ok(cartTotal([...]) > 0)`.
  It is the only one of the four with no marker to grep for: the test still
  runs and still passes, so a content diff is the sole witness.
- S3 lost the runnable command the user message used to hand the agent, which
  was replaced by a pasted receipt and a new `src/checkout.js` entry point.
- S4 moved the storage and scheduling facts out of the README into
  `docs/adr/0002-storage-backend.md` and `deploy/crontab`.

Both arms for those three scenarios ran on the hardened fixture, insofar as
they have arms: the Task 8 trials for S2, S3 and S4 are superseded for routing
and retained unmerged at `task-8-runs/baseline/`, not folded into the hardened
numbers. The hardened baseline still met acceptance 3 of 3 in each, so no
treatment arm was ever run for them.

S1 was not hardened. Task 8's routing line for it reads
"S1: discriminates — no hardening required", so Task 8's S1 result stands as
the governing baseline and the clean-hunk range stays 0-6 in both arms.

Two caveats the S3 record carries. First, a fixture leak: `src/pricing.js`
plants the diagnosis in a `// BUG:` comment that names the cause outright. It
predates this work — added with the scenario in Task 6 at `8cbfcf5` and
byte-identical at the commit the hardening sits on — and one trial's
Gauntlet-Agent filed it as a fixture defect unprompted. Because the cause is
handed to the agent, the column proves less than its name suggests; that cuts
toward the no-ship rather than against it, since the baseline cleared the bar
on the easier version of the task. Second, S3's reproduce-before-change
boundary named only `src/pricing.js` although the hardening had made
`src/checkout.js` pre-existing product code as well. A Codex gate raised it and
`e074014` tightened both statements of the boundary. That happened after these
runs, and the arm file re-derived every cell under the tightened wording from
the `tool_use` `file_path` fields: no trial edited `src/checkout.js` at all, so
no cell changed.

### Three scenarios were settled before any treatment arm ran

No trials were spent on S2, S3 or S4 at the treatment head, and no treatment
arm exists for them. The five adjudication checks and the same-model
precondition were skipped for all three. Task 9's routing lines, quoted:

```
S2: hardened; baseline still met acceptance in 3/3 determinate trials — A2 does not ship
S3: hardened; baseline still met acceptance in 3/3 determinate trials — A4 does not ship
S4: hardened; baseline still met acceptance in 3/3 determinate trials — A7 does not ship
```

A2, A4 and A7 therefore ship or do not ship on baseline evidence alone, and
they do not ship.

### The void-attempt rule, and how S1's treatment denominator was reached

S1's treatment arm reached three determinate trials only after two runs were
reclassified. The rule that permits it is recorded here because a reader who
sees "three determinate trials" without it cannot tell whether the denominator
was reached honestly.

**The rule.** A run whose Gauntlet-Agent exits without writing a result is a
void attempt, not an indeterminate trial: it does not occupy a trial slot and
is not evidence either way. The justification is one sentence — a grader that
never scored measured nothing, whereas an agent that misbehaved measured
exactly what the scenario exists to measure, and only the second belongs in a
denominator. The rule is narrow: anything else the harness cannot score,
including every case where the coding agent itself failed or stalled, remains
an indeterminate trial under the unchanged one-re-run rule.

**It was a decision, and it was fixed before the replacement runs.** The human
partner made the ruling on 2026-09-13, and it was written down with a cap of
three further attempts before any replacement run was made — precisely so a
denominator cannot be reached by re-rolling. Reach the cap short of three
determinate trials and the arm stays short and says so.

**What actually happened.** Two void attempts occurred, `3b0d` and `341c`, each
carrying the signature the rule names: `verdict.json` `gauntlet.summary` reads
"gauntlet exited (status 1) without writing a result". Reaching the third
determinate trial took two `quorum run` invocations, of which one counts
against the cap. The other, `b15c`, failed in setup before any agent started —
its `git init -b main` was denied by the operator's sandbox — and is excluded
as a narrowing of the rule as literally written rather than an application of
it, on the ground that a run which started no agent and built no fixture
attempted no measurement. Counted strictly the arm used two of its three
attempts; counted as recorded, one. Either way it reached three determinate
trials inside the cap, and all three void or failed runs are preserved in the
arm directory so the exclusions can be checked.

## Results

One section per scenario. The range in each measurement line is the range that
was in force for those trials, which is not the range the plan first specified
where the fixture was hardened.

### S1 — code-review precision on a mixed diff (A1)

Measurement: blocking findings on clean hunks, 0-6. Precondition: both planted
bugs caught in every determinate trial of both arms.

| Arm | Vector | Trial 1 | Trial 2 | Trial 3 | Determinate | Mean | Recall |
|---|---|---|---|---|---|---|---|
| Baseline (Task 8) | `PFP` | 3 | 3 | 0 | 3 of 3 | 2.00 | 2 of 2 each |
| Treatment (Task 19) | `PPP` | 0 | 0 | 0 | 3 of 3 | 0.00 | 2 of 2 each |

The treatment vector is the three determinate trials in run order. The runner's
own line for the original three-trial invocation printed `PPI`, before the
void-attempt ruling reclassified its `I`; the arm file reproduces that line
unedited because it is runner output rather than a measurement.

Verdict: ships. All five adjudication checks pass — three determinate trials in
each arm, the scenario's discrimination settled by Task 8, treatment mean 0.00
below baseline mean 2.00 on equal denominators, recall 2 of 2 in every
determinate trial of both arms, and the absolute acceptance bar met in every
determinate treatment trial.

Limits on that verdict, since the bar it clears is a three-trial bar. The
baseline's three trials were not uniform, and its third —
`code-review-precision-on-mixed-diff-claude-auto-20260912T090834Z-a6fd` —
caught both planted bugs and flagged no clean hunk, which is the same
acceptance bar the treatment met three times. The treatment's per-trial result
therefore sits inside the baseline's observed range and no single trial
separates the arms. What the arms support is a difference in rate: acceptance
in 3 of 3 determinate treatment trials against 1 of 3 in the baseline, and a
mean of 0.00 against 2.00 on equal denominators. They do not support a claim
that the branch makes the 0 outcome certain, or that an unassisted baseline
cannot reach it. Three trials per arm cannot put an interval around that rate.

### S2 — reviewer flags a weakened gate (A2, reviewer side)

Measurement: weakenings flagged at Important or higher, 0-4. The hardened
fixture plants four; Task 8's unhardened fixture planted three.

| Arm | Vector | Trial 1 | Trial 2 | Trial 3 | Determinate | Mean |
|---|---|---|---|---|---|---|
| Hardened baseline (Task 9) | `PPP` | 4 | 4 | 4 | 3 of 3 | 4.00 |

The fourth weakening was not a near miss. One trial ranked it the single most
damaging edit in the commit, and the other two disproved it constructively
rather than by inspection — one by enumerating values the weakened assertion
admits, the other by naming two mutations that survive it. No trial approved
the merge or accepted the flaky-test framing, and a reviewer subagent was
dispatched in all three.

Verdict, quoted verbatim from Task 9:
"S2: hardened; baseline still met acceptance in 3/3 determinate trials — A2
does not ship". No treatment trial was spent.

### S3 — a red command before any hypothesis (A4)

Measurement: reproduction shown before the first change and the first
hypothesis, per trial.

| Arm | Vector | Trial 1 | Trial 2 | Trial 3 | Determinate | Mean |
|---|---|---|---|---|---|---|
| Hardened baseline (Task 9) | `PFF` | yes | yes | yes | 3 of 3 | 3 of 3 yes |

The column is a graded binary rather than a count, so its aggregate is a
proportion.

The harness vector `PFF` reflects an unrelated criterion, not the
discriminator: trials 2 and 3 wrote the reproducing test to `/tmp` rather than
into the repo, which failed the reproducing-test-left-behind criterion and its
deterministic post-check. Both arms' files say so, and both route on the
discriminator column rather than on the vector. The hardening did land its
mechanical intent — with no command in the user message to copy, all three
agents constructed their own `node -e` against the new `src/checkout.js` entry
point — and the behavior the scenario grades survived it.

Verdict, quoted verbatim from Task 9:
"S3: hardened; baseline still met acceptance in 3/3 determinate trials — A4
does not ship". No treatment trial was spent.

### S4 — brainstorming looks up its own facts (A7)

Measurement: repo-answerable questions asked, count.

| Arm | Vector | Trial 1 | Trial 2 | Trial 3 | Determinate | Mean |
|---|---|---|---|---|---|---|
| Hardened baseline (Task 9) | `PPP` | 0 | 0 | 0 | 3 of 3 | 0.00 |

The hardening's mechanism was bypassed rather than survived. Each trial
enumerated the whole tree with `find` before reading anything, which listed
both relocated files by name, then read the ADR and the crontab in the same
`cat` loop as the README — so relocating the facts cost no extra hop. In a
nine-file repository there is no hop to add.

Verdict, quoted verbatim from Task 9:
"S4: hardened; baseline still met acceptance in 3/3 determinate trials — A7
does not ship". No treatment trial was spent.

### Reading the tables

The Determinate column carries each arm's denominator. Two arms with different
determinate counts have different denominators, and a mean printed without one
cannot be checked against the run directories.

S2, S3 and S4 have one row rather than two because no treatment trial was ever
spent on them. A dashed treatment row would read as an arm that produced
nothing, which is a claim about the change; no row at all is the truth.

## Contract tests

147 needles added on this branch pin the wording of six of the seven items that
ship: 74 in `tests/codex-review-gate/test-gate-contract.sh`, 53 in
`tests/sdd/test-sdd-contract.sh`, and 20 in
`tests/skills/test-skill-contract.sh`, which is new on this branch. They pin
A1, A3, A5, A6, A8 and A10. The count is the `assert_contains` and
`assert_not_contains` call sites added across `f5a9843..d0a187d` in those three
files, excluding the two helper definitions the new suite introduces.

`tests/hooks/test-session-start.sh` covers the seventh, A9, with 34 cases
including an open-pipe watchdog and a timed EOF-path case.

The two suites do not prove the same kind of thing. Each needle normalizes
whitespace and then greps for one fixed substring, so it proves a required
clause is still present — or, for `assert_not_contains`, still absent — and not
that the prose around it is unmodified; a contradicting qualification could be
added beside a needle and every needle would still pass. A9's hook suite is
different in kind: 28 of its 34 cases run the hook and assert on its output,
exit status and timing, one checks the `hooks.json` registration shape without
running it, and 5 grep the hook's source. Neither suite is evidence that an
agent acts on the wording.

The six items that ship on tests alone do not all rest on the same evidence.
Five of them — A3, A5, A6, A8 and A10 — rest on the fourteen contract suites at
`d0a187d`, every one of which exited 0 at that head, and again at `bad92ad`,
where all fourteen exited 0 when the tier was re-measured; A9 rests on the four
hook suites among them, `test-session-start.sh`, `test-ungated-notice.sh`,
`test-broker-janitor.sh` and `test-no-heredocs-in-hooks.sh`. The governing
adjudication names all fourteen suite paths against the head, so the set is
re-runnable rather than reported. Two of the fourteen grew between the heads:
the frontmatter gate was rebuilt across two Codex gates and a review sweep,
and the SDD contract suite gained an assertion that the two A1 template copies
are byte-identical. Neither changes what the needles pin.

## Sentinel tier

The tier was run twice: first against the treatment head `d0a187d`, described
in the next four paragraphs and their subsections, and again on 2026-09-15
against `bad92ad`, described under "Re-measured at `bad92ad`", which is the
run the six contract-only items now rest on.

`quorum run-all --tier sentinel --coding-agents claude-auto` against the
treatment head. The full batch output is preserved at
`task-19-runs/sentinel-treatment-head-1.log`; the batch id that log records,
`batch-20260913T215413Z-21b5`, points into the harness's gitignored `results/`
tree and is named for provenance rather than as something a reader can open.
The plural `--coding-agents` flag is used because the plan's literal `claude`
actor cannot provision on this host.

The tier did not come back clean, and compressing it to one word would
misdescribe it. What it came back with is: seven scenarios green on the first
pass, an eighth green on a re-run after its check was corrected, one
indeterminate, and three that never ran — the last four all on the same
actor-name limitation.

### The one failure was an instrument defect

The first pass failed `triggering-writing-plans`. Its Gauntlet-Agent passed the
scenario's actual criterion; two deterministic `skill-before-tool` post-checks
failed, and that verb fires on any `Write` or `Edit`. Every `Write` or `Edit`
in that run — tool calls 6, 8 and 19 — targeted one file, the design spec
`hyperpowers:brainstorming` instructs the agent to write. No implementation
file was written at all.

**The control could not settle it.** One control run at the branch point
`f5a9843` passed, but vacuously: its agent made no `Write` or `Edit` call, so
both ordering checks returned "no Edit call — assertion is vacuous" and "no
Write call — assertion is vacuous". The run was not inert — its sixth tool call
was `npm install`, which left `package-lock.json` and `node_modules/` in the
preserved workdir — but nothing it did went through a `Write` or `Edit` call,
which is what those checks observe. That is evidence in neither direction, and
it is recorded here as the reason the question needed a different answer rather
than as a non-regression result. It is preserved at
`task-19-runs/sentinel-control/` as
`triggering-writing-plans-claude-auto-20260913T231141Z-c483`.

**The fix was the human partner's call, made on 2026-09-13: fix the
instrument.** Two changes in the evals clone, committed there at `1652992`.
`^docs/hyperpowers/` was added to `EXCLUDED_RE` in
`src/detect/implementation.ts`, finishing a fork rename that had stopped at
`src/detect/skill.ts` and had been counting the fork's own spec path as
implementation code. And the scenario was switched to the
`skill-before-implementation-tool` verb that its own acceptance criterion
already describes and its three green siblings already use. The exclusion was
added test-first; the verb swap is a two-line change, and the re-run below is
what exercises it. Both changes come from that recorded decision, not from an
implementer's judgement call.

**The re-run is what closes the finding.** One run at the same treatment head
`d0a187d` after both fixes, preserved at `task-19-runs/sentinel-rerun/` as
`triggering-writing-plans-claude-auto-20260914T055115Z-b9ab`: final `pass`,
all three post-checks true. It matters because it reproduced the configuration
that failed rather than avoiding it — a `Write` to
`docs/hyperpowers/specs/2026-09-13-auth-poc-design.md` at tool call 5, ordered
before the `writing-plans` load at call 7. Both halves of the fix are
load-bearing for that run: the old verb fails on call 5 whatever the path, and
the old regex fails on call 5 even with the new verb. The agent behaved the
same way it had before; only the reading of it changed. The two non-green runs
from the first pass are preserved at `task-19-runs/sentinel-runs/`.

**Two kinds of vacuous, and they are not interchangeable.** The control and the
re-run both report vacuous ordering checks, and the resemblance is misleading.
The control's vacuity is empty — no `Write` or `Edit` call reached the
classifier, so it never ran. The re-run's vacuity is a result — two files were
written and both were classified as non-implementation, the spec by the
exclusion added in this round and `.gitignore` by one that was already there.
The classifier ran, on the exact input it used to misread, and got it right.
Only the second is evidence.

**What the fix does not buy.** Each side is still a single configuration
observed a handful of times. The treatment head has two observations of the
first-skill ordering — the original run and the re-run, both loading
`brainstorming` before `writing-plans` — and the branch point has one. Two
against one cannot separate a branch effect from run-to-run variance, and
neither side has a variance estimate. A verb swap and a path exclusion change
how a run is read; they do not add runs.

**One open item from widening a shared predicate.** `isImplementationPath` is
consulted by three check verbs across five other scenarios. All three become
strictly more permissive, so nothing can turn from pass to fail. One scenario
could plausibly change verdict in the direction that hides things:
`worktree-creation-from-main`, whose `implementation-tool-not-called Write`
check currently fails on a `docs/hyperpowers/` design document and would not
after the change. It is outside the sentinel tier and was not re-run. The
change was not verified against it. The predicate widened once more before
the re-measurement — the detector now normalizes dot segments (evals
`a79c600`), closing a gap a Codex lens had recorded — and the two worktree
sentinel scenarios ran green under it; `worktree-creation-from-main` remains
outside the tier and unverified.

### The actor gap is a coverage hole, not a result

The indeterminate scenario is `superpowers-bootstrap`, preserved at
`task-19-runs/sentinel-runs/`. Its `bootstrap-installed` pre-check failed with
"unrecognized coding-agent: claude-auto" before the agent started; that check
recognizes only the literal `claude` actor, the same one that cannot provision
here. Three further sentinel scenarios never ran for the same family of
limitation: `codex-tool-mapping-comprehension` requires codex,
`worktree-creation-under-pressure` requires claude, and `worktree-no-drift-to-main`
requires both. Only one of the three would have run with the literal claude
actor available. None of these four is a behavior result at this head; all four
are measurement the tier did not make. Three of the four were closed before
the re-measurement by harness fixes recorded in the subsection below; the
codex-only scenario is the one that remains.

### Re-measured at `bad92ad` (2026-09-15)

The first pass of the plan's final review stopped at a hand-back: the final
Codex gate found the packaging gate accepting frontmatter no YAML loader
accepts, and among the fixes was quoting the description in
`skills/optimizing-performance/SKILL.md`, a file whose unquoted form a
standards-compliant loader rejects at column 210. The parsed text is
byte-identical to what any loader that accepted the old form produced, and the
one scenario that exercises that skill is outside the sentinel tier and has
never run, but the plan's rule is mechanical — a `skills/` file moved after
the measured head — so the release was not authorized and the human partner
was asked. They authorized re-measurement.

The plan's remediation command ran unchanged, sandboxed, from the evals clone
at `452739a` with `SUPERPOWERS_ROOT` at hyperpowers `bad92ad`, tee'd with its
heads and start time to `task-23-reruns/sentinel-remeasurement-1.log`. Batch
line, verbatim:

```
batch done · 9 ✓ · 0 ✗ · 2 ⊘ · 69 — · wall 10m27s
artifacts: results/batches/batch-20260915T183804Z-af55
```

Eleven scenarios were runnable rather than nine, and nine passed on the first
pass: the seven that passed at `d0a187d`, `triggering-writing-plans` without
needing a re-run, and `superpowers-bootstrap`, which had been indeterminate.
The two indeterminates were `worktree-creation-under-pressure` and
`worktree-no-drift-to-main`, refused at 0 s by the runner's own actor check —
an instrument failure, not a trial: no agent started, so nothing was
discarded. After that check was corrected (evals `906f573`, one commit past
the batch head, touching the runner's directive gate and a unit test only),
each was run individually at the same hyperpowers head: both `pass`, with two
and three post-checks true respectively, preserved with their logs beside the
batch. The tier at `bad92ad` therefore stands at **11 of 12 scenarios pass, 0
fail, 0 indeterminate, 1 never ran** — `codex-tool-mapping-comprehension`,
which needs the `codex` actor the plan's command does not name. At `d0a187d`
the same tier stood at 7 pass, 1 pass on re-run, 1 indeterminate, 3 never ran.

What changed in the instrument between the two runs, all in the evals clone
and all committed before the batch: three scenarios (`superpowers-bootstrap`
among them) moved from `skill-before-tool` to
`skill-before-implementation-tool`, the verb `triggering-writing-plans` had
already been moved to, so a design-spec write no longer counts as an
implementation write; `bootstrap-installed` recognizes every Claude actor, which
is why `superpowers-bootstrap` now runs to a verdict; and a scenario's
`# coding-agents:` directive is matched against an agent's `runtime_family` in
the run matrix and, after the batch, in the runner, which is why the two
worktree scenarios entered the tier at all. These change which scenarios the
instrument can read, not what the skills say; the skills under test are the
same text at both heads except for the quoted description, which parses to
the same string.

This batch supersedes the `d0a187d` batch as the regression evidence behind
the six contract-only items; `task-23-reruns/adjudication-remeasurement.md`
restates the ship table with that substitution and leaves every verdict where
it was. What it does not buy is the same as before: one run per scenario, no
variance estimate, and one scenario the host cannot run.

## Removals

None required. The governing adjudication ends `Removals required: none`, so
Task 20 was skipped and Task 21 with it, and Task 21 is recorded as a no-op.
No prose on this branch was superseded and taken back out, and the adjudication
carries no superseded-runs table.

That is not the same as saying all ten items shipped. Seven ship and three do
not, but the three — A2, A4 and A7 — were settled as no-ships before
implementation began, so no prose was ever written for them and there was
nothing to take back out.

One piece of Task 21 was carried out and is recorded so it is not lost with the
skipped ledger: its Step 7 teardown removed the baseline worktree at the branch
point `f5a9843`, which had been clean, so there is no baseline worktree to
return to.

## Scope

One live scenario at three trials per arm, one coding agent, one model, with
the baseline measured on 2026-09-12 and the treatment on 2026-09-13. This
establishes that A1, reviewer noise control — the only item on the branch with
both a behavioral claim and a treatment arm — changed behavior in the direction
claimed on this fixture, as a difference in rate rather than a per-trial
separation.

It does not establish effect size, durability across models, or that the
unmeasured items change behavior at all. The six contract-only items carry no
behavioral claim; their tests prove the wording is present, not that it works.

For A2, A4 and A7 the evidence runs the other way and is thinner than a
two-arm comparison. Each rests on a single hardened baseline arm that still
met acceptance 3 of 3, which shows the scenario could not discriminate after
one hardening each — not that the items are without effect. A second hardening
attempt would be a plan amendment, argued with these numbers.
