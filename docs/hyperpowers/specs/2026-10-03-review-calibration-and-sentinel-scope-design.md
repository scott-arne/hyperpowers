# Review calibration and sentinel scope: three process fixes

**Date:** 2026-10-03
**Status:** approved by the human partner on 2026-10-03, after the three
design sections were approved in chat the same day and the spec was
self-reviewed. The Codex spec gate ran its four-round backstop; the round-4
fixes are not re-reviewed by Codex.
**Branch:** a new branch off `main` at `5bef46c` (v6.15.0), created by the
plan. The evals changes land on evals `main` after `60e69cbc0`.
**Provenance:** three fixes the human partner queued on 2026-09-16 ("Yes,
queue them") after the external-workflow-adoption gates spent their effort on
edge cases: the third-pass final gate ran its three-round ceiling (run
`GVSWGQ3I`), and the sentinel tier was re-run five times for hook edits no
sentinel session executes. The memory note `process-fixes-owed-2026-09` holds
the queue; this spec restates what it rests on.

## Problem

1. **Codex rates pathological-input defects as blocking.** The three
   adversarial-review focus strings in
   `skills/requesting-code-review/recipe-code.md` (lines 53, 71, 81) define
   critical or high as a defect the change introduces "that yields a wrong
   result, a crash, data loss, or a reachable security hole". Nothing in them
   asks whether ordinary use can reach the defect. The third-pass gate's
   blocking findings included:
   - invalid-UTF-8 bytes in a path;
   - a plan directory whose name contains a newline;
   - `printf %q` emitting invalid UTF-8 on bash 3.2;
   - dot-prefixed workspaces skipped by a glob;
   - a C0 byte in a ledger path voiding the payload.

   Each one needs an input that the code never generates and that a person
   would have to construct by hand. Under `gate-findings.md`, critical and
   high map to Critical and Important, and both block, so each finding cost a
   fix round.
2. **The sentinel re-measure rule is file-level.** Step 2 of "A single
   sentinel failure is a sample" (evals `docs/scenario-authoring.md` §5) asks
   for a twenty-run re-measure whenever "the head's `skills/` and `hooks/`
   trees differ from the head the base rate was measured at". The adoption
   plan's Task 23 Step 5 applied the same file-level test. A hook edit
   confined to `hooks/session-start`'s compaction branch therefore re-ran the
   tier, although no sentinel scenario compacts and the hook's startup output
   was unchanged.
3. **The base-rate table has no clean-harness row.** Both rows for
   `cost-checkbox-over-trigger` predate the harness hermeticity fixes (evals
   `74d248245`, `fc42537c5`, `be020f0d0`). The attribution campaign
   (`evidence/2026-10-03-harness-confound-attribution/`, evals `25cb227d5`)
   showed the repository instruction text alone moves that scenario from 10
   of 10 passing to 0 of 10 on Claude Code 2.1.287. A rate measured with the
   leak cannot stand as the base rate for a clean run, and the table does not
   say which rows carried it.

The base-rate rule itself (look up the rate, run twenty, compare Wilson
bounds; a single failure at a rate of 5% or more never holds a release)
already landed with the adoption remediation (plan
`2026-09-23-adoption-remediation.md`, Task 2). Fix 3 is the table, not the
rule.

## Decisions

Taken by the human partner on 2026-10-03:

- **Fix 1 reach: the Codex focus strings only.** The three copies in
  `recipe-code.md` change. The Claude reviewers (`code-reviewer.md`, SDD's
  `task-reviewer-prompt.md`) do not; their "Before You Report a Finding"
  section already treats triggerless edge cases as the primary failure mode.
  Measured with the 2026-09-05 direct-Codex fixture method.
- **Fix 1 form: an added sentence.** The measured calibration sentence stays
  byte-identical; the cap is a new sentence after it. Rewriting the
  critical/high definition to require reachability was rejected: it edits the
  sentence whose H result (blocked 1 of 3 before, 3 of 3 after) was measured
  on 2026-09-05, and it leaves the cap for Codex to infer.
- **Fix 2 home: the evals authoring guide plus a hyperpowers pointer.** The
  rule lives in `docs/scenario-authoring.md` §5 beside the sentinel rule. One
  bullet in hyperpowers `CLAUDE.md` under "Skill Changes Require Evaluation"
  points at it. No live runs.
- **Fix 3 scope: the table update.** A harness column, a clean-harness row
  from existing evidence, and a comparability sentence. No new runs.

## Design

### Fix 1: the pathological-input cap

Insert this sentence into each of the three focus strings in
`skills/requesting-code-review/recipe-code.md`, immediately after "Naming,
style, and speculative hardening are low.":

> A defect reachable only through input that nothing in the code or its
> callers produces and that only the person running it could supply — a
> newline or invalid UTF-8 in a file or directory name, a name that starts
> with a dot — is medium, unless it also breaks the default path or corrupts
> stored data.

What each part does:
- **"nothing in the code or its callers produces"** keeps the sentence from
  covering a defect the code's own output can trigger.
- **"only the person running it could supply"** keeps input from an
  untrusted party out of the cap. A crafted request against a server is
  still a reachable security hole under the existing definition.
- **The examples** are the shapes the third pass blocked on.
- **The two exceptions** are the human partner's 2026-09-16 wording, and
  each keys on an observable outcome.

Under `gate-findings.md`, medium maps to Minor. A capped finding leaves the
fix loop but is still recorded in the round ledger and the Minor ledger.

No other skill file changes. `gate-lenses.md` already requires each lens
launch to carry the recipe's complete focus string verbatim, so the lenses
inherit the sentence.

`tests/codex-review-gate/test-gate-contract.sh` gains a pin beside the
existing `full_cal` count:
- the cap sentence appears exactly three times in the assembled gate;
- each `adversarial-review --base` launch block of `recipe-code.md` contains
  the contiguous text "Naming, style, and speculative hardening are low. "
  followed by the cap sentence, exactly once. That pins the placement as
  well as the count.

### Fix 2: re-measure only what a sentinel session reaches

In evals `docs/scenario-authoring.md` §5, step 2 becomes:

> 2. If none is recorded (no row is comparable with the failing run), or the
>    head under test differs from the head the base rate was measured at in
>    something a session of this scenario loads or runs before its reading
>    is settled (see "What a session reaches"), run the scenario twenty
>    times at the head under test (the existing `--repeat 20` command,
>    unchanged) and add the rate to the table with the head, the evals
>    commit, the model, the Claude Code version, the listing budget, the
>    harness state and its n.

A new subsection, "What a session reaches", follows the table's paragraph:

- **The skill listing reaches every session.** A change to any skill's
  frontmatter description counts.
- **A skill body or supporting file reaches only the sessions that read it.**
  A file a session reads only after its reading is settled does not count.
  For an over-trigger scenario, a body read after the invocation that already
  fails the session is an example.
- **A hook branch reaches a session only on events that session fires.** A
  branch that runs only on compaction does not reach a scenario that never
  compacts. A changed line outside such a branch counts as reached, whatever
  its effect: a file write or a spawned process counts as much as output.
- **The argument is recorded with the result.**
  - For a hook, two parts, both required:
    - Control flow. Every line that differs between the two heads lies
      inside a branch whose condition the scenario's events cannot satisfy.
      The record cites the condition's line and the events the base-rate
      transcripts show the scenario firing.
    - Output, as a check on the control-flow part. The hook's output on the
      scenario's event payload is byte-identical at both heads. The worked
      example is the 2026-10-03 re-baseline's `session-start` check: a
      `startup` payload gave 3484 bytes, sha256 prefix `9eb3db442469`, at
      both roots.
    Identical output alone is not the argument: a changed branch can run and
    still print the same bytes.
  - For a skill body: the base-rate transcripts showing it was not read
    before the reading settled.
  - An argument without that evidence is not made, and the scenario is
    re-measured.

In hyperpowers `CLAUDE.md`, under "Skill Changes Require Evaluation", one
bullet: a single sentinel failure is a sample, and a re-measure is owed only
for a change a sentinel session reaches; follow
`evals/docs/scenario-authoring.md` §5 before holding a release on one.

### Fix 3: the base-rate table

In the same §5 table:

- **A `harness` column and an `evals` column.** Each row records the evals
  commit it was measured at. The harness label is assigned by the first of
  these rules that applies:
  1. `leak-era`: the archived transcripts show either leak. That means a
     session loaded `CLAUDE.md` or `AGENTS.md` text from outside the run
     directory, or carries a mark of the operator's Claude environment (an
     entrypoint other than `cli`, or `TaskCreate` among the deferred tools
     offered).
  2. `clean`: the row was measured at evals `be020f0d0` or a later commit,
     and at that commit the hermeticity tests pass. Those tests landed with
     `74d248245`, `fc42537c5` and `be020f0d0` in `test/agent-claude.test.ts`
     and `test/runner-context.test.ts`. They pin that the launcher drops
     every inherited `CLAUDE*` and `ANTHROPIC*` variable and that the
     `CLAUDE.md` and `AGENTS.md` excludes are in place. The row's evidence
     records the test run. For a row added after its measurement, the tests
     are run at its commit when the row is added (an offline `bun test`, not
     a live run).
  3. `unknown`: every other row. Before `be020f0d0`, the operator's
     environment carried variables that leave no mark in a transcript, such
     as other session variables and the model alias pins. So a transcript
     can show a leak but cannot prove its absence.

  Rows 1 and 2 were measured before `be020f0d0`, so each is `leak-era` or
  `unknown`, depending on its transcripts. Neither remains a base rate.
- **A new row** from the attribution campaign's arm A:
  `cost-checkbox-over-trigger` | `claude-opus-5-5` | 2.1.287 | hyperpowers
  `5bef46c` (v6.15.0) | evals `be020f0d0` | default | amended criterion |
  clean | 0/10 = 0% (0-28%) |
  `evidence/2026-10-03-harness-confound-attribution/` (arm A).
  Rows 1 and 2 gain their evals commits from their evidence directories.
  - Its `clean` label rests on the hermeticity tests run at `be020f0d0`,
    recorded beside the attribution evidence when the row is added.
  - It is a recorded base rate under steps 1 and 3, with its own Wilson
    interval. The row states that it is n=10.
  - Step 2's twenty is the size of a new measurement at the head under test,
    and the edited step 2 says so. A recorded row may be shorter when it
    states its n.
  - The cost of the short row: its upper bound is 28%, against 16% for 0 of
    20. So step 3 needs more failures in a twenty-run measurement before it
    calls a regression against this row. Ten more runs at `5bef46c` on the
    clean harness would close the gap; this work does not run them (see
    Decisions, "Fix 3 scope").
- **Which row is the base rate.** Step 1 becomes: look up the most recently
  measured base-rate row that is comparable with the failing run.
  - **Regression rows.** A measurement against which step 3 called a
    regression is added with the call recorded. It is not a base-rate row
    until the human partner accepts the moved rate, which is recorded in the
    row. That way a regression cannot become the baseline that hides it on
    later heads.
  - **Comparability.** The comparability sentence, which step 3 also uses,
    widens from "measured under the same criterion" to a row and a failing
    run that share all of these:
    - the criterion;
    - a `clean` harness label. `leak-era` and `unknown` rows stay in the
      table as history and are never a base rate: neither label identifies
      one environment;
    - the model;
    - the listing budget;
    - the evals harness. `src`, `coding-agents`, `package.json`, `bun.lock`
      and the scenario's directory are identical at the row's evals commit
      and the failing run's (`git diff --quiet <row> <run> -- <paths>`).
      That is the path set the 2026-10-03 re-baseline's launcher pins.
      Alternatively, each difference carries a recorded argument, in the
      form of "What a session reaches", that it cannot change the launch,
      the skill listing, the transcript, the grading or the criterion.
  - **The Claude Code version** is recorded but is not part of the match. A
    regression call against a row at another version names the version as a
    second difference: the call says the rate moved between the two
    measurements, not that the head moved it.
  - **No comparable row.** Step 2's "none is recorded" applies.

## Evaluation

### Fix 1 (skill text; writing-skills applies)

The method is the 2026-09-05 direct-Codex review of fixture diffs. Each
fixture is reviewed three times per arm, and every capture is normalized by
`skills/requesting-code-review/scripts/verdict-normalize`. A review "blocks"
when the normalized verdict carries a critical or high finding.

**Runner.** Today evals `scripts/codex-focus-arm.sh` hardcodes fixtures
M/H/O, the pre-calibration control text and one commit message. It gains:
- a fixture list;
- a focus text per arm, read from a file;
- a commit message per fixture;
- the assertions and the runtime record below.

Its broker handling and parse-and-test assertions stay as they are.

**Arms.** Each arm's recipe focus is a file in the evidence directory,
written before the first review:
- **Control** (`focus-control.txt`): `recipe-code.md` line 53's focus
  string at `5bef46c`, byte-for-byte. Its four path placeholders are replaced
  as in the 09-05 runs' treatment text:
  - `<TASK_BRIEF_PATH>`, `<IMPLEMENTER_REPORT_PATH>` and
    `<GLOBAL_CONSTRAINTS_PATH>` become `$1/REQUIREMENTS.md`;
  - `<REVIEW_PACKAGE_PATH>` becomes `$1/review.diff`.

  The runner substitutes `$1` with the fixture's work directory.
- **Treatment** (`focus-treatment.txt`): the control file with the cap
  sentence and one space inserted after "Naming, style, and speculative
  hardening are low. ".

Before any review, the runner asserts:
- removing that one inserted span from the treatment file yields the control
  file byte-for-byte;
- the control file, with the four replacements reversed, equals line 53's
  quoted focus string at `5bef46c`.

Both arms are composed with the correctness-lens skeleton, as in the 09-05
runs.

**Runtime record.** The runner writes these at the start and at the end of
each arm:
- the companion version;
- `codex --version`, for the binary the broker spawns as `codex app-server`;
- `model` and `model_reasoning_effort` from
  `${CODEX_HOME:-$HOME/.codex}/config.toml`.

The runner refuses to start when a broker session is already recorded for
its working directory. Each arm's app server is then one the runner spawned
itself, from the recorded binary. The runner never stops a broker it did not
start. If an arm's start and end records
differ, that arm is re-run. If the two arms' records differ, the later arm is
re-run under the earlier arm's configuration. The comparison stands only when
all four records agree.

**Fixtures** (JavaScript, in the existing `fixtures/codex-focus-arm/` shape:
`REQUIREMENTS.md`, `lib.base.js`, `lib.js`, `test.js`; base and head both
parse and pass):
- **P (new).** The diff's only defect is a crash or a wrong result that
  occurs only for a name the code never generates. For example, workspace
  names are created by the library as hex digests, and the defect fires only
  on a hand-made name with a leading dot or a newline. No stored data is
  written. P should drop to medium.
- **Pc (new).** A name containing a newline corrupts an appended record
  file, so later reads misattribute records. It is pathological input, but
  the "corrupts stored data" exception applies, so it must stay blocking.
- **H (2026-09-05).** A crash or wrong result on ordinary input; a regression
  check, which must still block.
- **O (2026-09-05).** A requirement the task was asked to meet and omits; a
  regression check on the calibration sentence's omission clause, which must
  still block. It blocked 3 of 3 in both 09-05 arms.
- **M (2026-09-05).** Defect-free; a regression check, which must still be
  approved.

That is 5 fixtures, 3 reviews per arm each: 30 reviews, or 33 if P is
revised once (below).

**Order (RED first).**
1. Run the control arm on P before the sentence is written into
   `recipe-code.md`.
2. If control blocks P in at most 1 of 3, P is revised once and re-run. Both
   versions of P and both results are kept in the evidence.
3. If it still does not block in at least 2 of 3, the plan stops and reports
   to the human partner. No sentence ships without a reproduced
   over-rating.
4. The treatment arm runs only after P is validated.

**Decision rule.** The treatment wins if:
- P blocks in at most 1 of 3;
- Pc blocks in at least 2 of 3;
- H blocks in 3 of 3;
- O blocks in 3 of 3;
- M is approved in at least 2 of 3.

Control's numbers are reported beside them. A loss on any line means the
sentence does not ship as measured, and the result comes back to the human
partner.

**Evidence.**
- Captures go to evals
  `evidence/2026-10-03-review-calibration-and-sentinel-scope/task-<N>-runs/`,
  per the repo `CLAUDE.md` convention. The directory is named in the plan's
  Global Constraints before the first review.
- A dated eval-evidence note goes in `docs/hyperpowers/`.
- An entry goes in the next release's CHANGELOG section.

### Fixes 2 and 3 (documentation)

No live runs. In evals, `bun run check` and `bun run quorum check` stay
green. In hyperpowers, the offline suites listed in `docs/testing.md` stay
green, including `test-gate-contract.sh` with its new pin.

## Files

- hyperpowers:
  - `skills/requesting-code-review/recipe-code.md`
  - `tests/codex-review-gate/test-gate-contract.sh`
  - `CLAUDE.md`
  - `CHANGELOG.md`
  - this spec, its plan, and the evidence note
- evals:
  - `docs/scenario-authoring.md`
  - `scripts/codex-focus-arm.sh`
  - `fixtures/codex-focus-arm/P/`, `fixtures/codex-focus-arm/Pc/`
  - `evidence/2026-10-03-review-calibration-and-sentinel-scope/`, holding
    `focus-control.txt`, `focus-treatment.txt` and the `task-<N>-runs/`
    captures
  - a `docs/experiments/` entry for the fixture arm

## Constraints

- **Leave the running re-baseline's pinned paths alone.** No evals change in
  this work touches `src`, `scenarios`, `coding-agents`, `package.json` or
  `bun.lock` while the 2026-10-03 clean-harness re-baseline has rows or
  replacements pending. Its `measure-launch.sh` refuses to launch on any
  difference there. Every evals path above is outside that set.
- **Commits.** The hyperpowers `CLAUDE.md` diff and every commit are shown to
  the human partner before committing. Nothing is pushed without an explicit
  request.

## Out of scope

- The Claude reviewers' prompts.
- New runs of `cost-checkbox-over-trigger` to bring the clean row to twenty.
- Editing the historical plans' Step 5 bucket rules; they are records.
- A quorum scenario for the cap. The direct-Codex method measures the focus
  text without a session around it.

## Known limits

- **Production shape.** As in the 2026-09-05 runs, the fixture's
  `review.diff` stands in the dossier slot instead of a real review dossier.
- **Boundaries tested.** Pc tests the "corrupts stored data" exception. Two
  boundaries have no fixture and stay unverified:
  - the "breaks the default path" exception;
  - input from an untrusted party, which the cap's "only the person running
    it could supply" clause leaves blocking.
- **Claude Code version drift.** Base-rate rows match without regard to the
  Claude Code version. A version change can still move a rate, for example
  through how the skill listing renders, and a regression call across
  versions names it but cannot separate it from the head.
- **Scope.** One Codex model, one lens skeleton, three reviews per cell, so
  a single review can move a cell's reading.
- **Fix 2 is judgment.** The rule asks for recorded evidence, but whether a
  session "reads" a body before its reading settles is still argued from
  transcripts. Without evidence, the rule defaults to re-measuring.
