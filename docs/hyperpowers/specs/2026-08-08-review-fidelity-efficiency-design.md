# Review Fidelity & Efficiency (SP3a) — Design

Date: 2026-08-08
Status: draft (spec gate pending)
Target release: 6.5.0
Predecessors: 6.3.0 (gate reliability hardening), 6.4.0 (gate resilience &
telemetry)

## 1. Problem

The Codex review gates' dominant quality/efficiency pathology is **serial
single-finding discovery**: reviews surface one or two blockers per round,
then find a new, orthogonal defect class the next round. Fleet mining:
plan gates 77% multi-round, spec 58%, code ~55%; doc gates hit their
4-round backstop 24% of the time. This fork's own two recent releases —
executed under full gating — reproduced the pattern exactly: spec gates
approved in 3 and 4 rounds, plan gates ran to the backstop twice, three
per-task code gates ran to the 3-round backstop, and virtually every
round's finding was a *different failure class* (lock protocol, then
state validation, then recipe fidelity). Finding precision is high (81%
real in the mined sample); discovery WIDTH per round is the problem.

Three review-context gaps compound it:

- **Adjudication blindness.** Per-task reviews re-flag behavior the spec
  gate already accepted (documented tradeoffs, declined findings with
  reasoning), burning rounds on decided questions.
- **Doc-gate fetch overhead.** Document reviews receive paths, not
  content: 89% of reviewer tool calls are file reads; median token
  volume ~490K (spec) to ~945K (plan) per session, mostly cold
  whole-file re-reads; five observed git failures from non-repo cwds.
  The code path already inlines the diff, proving the delivery model.
- **Test-evidence gap.** The reviewer sandbox is read-only; 29–35% of
  doc-gate verdicts hedge with "Cannot verify", and at least one bogus
  "tests couldn't run" complaint was observed — while implementer
  reports carry the actual executed test output.

Human-partner priority ordering, binding: correctness and optimal
solutions first, wall-clock second, token cost third.

## 2. Approach (decided via Codex approach gate)

Composite of all four blind-handoff proposals, judged complementary
rather than competing (three independently converged with the
controller's own candidates):

- **Generated review dossier** (Codex + convergent): one structured
  context artifact per gate delivers documents, adjudications, and test
  evidence — closing all three context gaps in one component.
- **Specialist fan-out with fail-closed merge** (Codex + convergent):
  round 1 becomes a logical batch of 2–3 lens reviews over the same
  dossier; approval requires every lens to normalize approved.
- **Breadth-first prompt contract** (Codex + convergent): every lens
  carries an exhaustiveness demand; discovery width is asked for
  explicitly, not implied.
- **Normalizer-enforced coverage floor** (Codex): a required `Coverage:`
  output section, enforced by a flag-gated `verdict-normalize`
  extension — breadth becomes an approval precondition, not a
  suggestion.

Design invariant: these changes widen what a ROUND sees; nothing weakens
what may EXIT the loop. `verdict-normalize` remains the only approval
authority, `gate-round` the only round authority, ledger appends and
backstops unchanged.

## 3. Goals / non-goals

Goals:

1. Round 1 discovers the breadth of blocking findings that today leaks
   into rounds 2–4: measured over subsequent releases as lower
   multi-round and backstop rates via `gate-telemetry` (soft criterion —
   directional, against the July mining numbers and the 6.3.0/6.4.0
   cycle ledgers).
2. Reviewers receive, rather than fetch: document content, adjudicated
   decisions, and executed test evidence arrive in one dossier artifact.
3. A narrow approval cannot slip through: every lens must independently
   normalize `approved`, and an approve without coverage evidence is
   `incomplete`.
4. Everything degrades cleanly: no dossier → today's path-based prompts
   with attribution; a dead lens → an attributed non-approving round,
   never a blocked gate or a silent narrow pass.

Non-goals:

- No companion modifications; no reliance on unverified concurrency
  (serialized fan-out is semantically identical).
- No changes to re-review rounds (single reviewer against the round
  ledger), backstop ceilings, ledger classes, or sweep semantics.
- No SDD prompt hygiene, risk tiering, or skill retirement — that is
  SP3b.
- No new eval scenarios in this release unless the plan finds one cheap
  (candidate noted in §7; contract needles + micro-tests are the bar).
- No automatic telemetry gating of the goals — the before/after
  comparison is evidence for the human partner, not a merge gate.

## 4. Components

All new scripts: bash + node built-ins, `skills/requesting-code-review/
scripts/`, 6.3.0 exit discipline (exit 0 determinate + single-line JSON;
exit 2 usage/internal).

### 4.1 `review-dossier` — one context artifact per gate

```
review-dossier --gate spec|plan|task|final|adhoc --out GATE_DIR
  [--doc PATH]... [--spec PATH] [--adjudications PATH]...
  [--test-evidence PATH]... [--base SHA --head SHA] [repo-dir]
→ {"ok":true,"dossier":"<GATE_DIR>/dossier.md","sections":N,"missing":M}
```

`dossier.md` carries five sections, fixed order, fixed headers, ALWAYS
all present:

1. `## Documents under review` — each `--doc`/`--spec` file inlined via
   `nl -ba`, per-file cap of 4000 lines with an explicit
   `TRUNCATED at line N of M` marker (no silent cuts; the cap exceeds
   every spec/plan in this repo's history by a wide margin). Doc gates inline the artifact under review;
   code gates typically pass none (the diff is companion-assembled).
2. `## Adjudicated decisions` — verbatim inlines of the supplied
   excerpts: the spec's documented-tradeoff sections and the spec/plan
   gate round ledgers' Declined blocks. The CALLER selects the paths
   (the gate doc names which exist at each moment); the script only
   assembles.
3. `## Test evidence` — implementer-report inlines (TDD RED/GREEN
   blocks, suite tallies), same cap/truncation rules.
4. `## Changed surfaces` — `git diff --stat` + `--name-status` for
   `base..head` when both are supplied.
5. `## Review package` — the companion-assembled diff's role stated by
   reference (code gates), or `not applicable` (doc gates).

Absence is two distinct markers, driven by a per-gate expected-inputs
map built into the script (spec/plan gates expect documents +
adjudications, test evidence optional; task/adhoc gates expect
adjudications + test evidence + base/head, documents optional; final
gates expect all): an input the gate type does not expect renders
`NOT APPLICABLE: <why>` (a normal, quiet state — code gates typically
inline no documents, doc gates typically carry no test evidence); an
EXPECTED input that is unsupplied or unreadable renders
`NOT PROVIDED: <flag not passed | file unreadable: path>`. Reviewers are
instructed (§4.2) to treat NOT-PROVIDED as cannot-verify for that axis —
explicit absence, never licence to guess — while NOT-APPLICABLE axes are
answered as such in Coverage without hedging.

### 4.2 Lens sets and prompts

Per-gate lens charters (each one paragraph, failure-class scoped):

- **Spec gate (2):** completeness-and-consistency; feasibility-and-scope.
- **Plan gate (2):** coverage-and-ordering (spec coverage, task sizing,
  sequencing); feasibility-and-contracts (type/signature consistency,
  buildability). **The existing Round-1 Algorithm Assessment attaches to
  the feasibility-and-contracts lens and ONLY that lens**: its prompt
  carries the current assessment block verbatim under the current
  trigger (material algorithmic/data-structure choices), and its output
  appends the existing `Algorithm Assessment (round 1 only)` shape. The
  coverage-and-ordering lens never emits an Assessment — any algorithm
  opinion it volunteers is an ordinary finding (`[out-of-lane]` where
  applicable), so no Assessment merge or dedup can arise by
  construction. The existing adjudication-and-lock rule runs at its
  current point — immediately after parsing round-1 output and BEFORE
  the approval set is evaluated — over the one lens's Assessment;
  round-2 lock-line and assessment-omission semantics are untouched
  (re-review rounds are lens-free, so the current round-2 contract
  applies verbatim). All existing Algorithm Assessment contract needles
  must remain green, plus one new composition needle pinning the
  single-lens attachment.
- **Per-task/adhoc code gates (3):** correctness; contracts-and-
  integration; tests-and-evidence.
- **Final whole-branch (3):** correctness; integration-and-requirements-
  coverage; tests-and-evidence.

Every lens prompt contains, each phrase needle-pinned on one source
line: the dossier path ("read it first — it is your delivered context");
the lens charter; the exhaustiveness demand — `Report every blocking
finding you can identify this round; do not reserve findings for later
rounds.`; the lane rule — findings outside the lens's charter are still
reported, labeled `[out-of-lane]`, never suppressed; the required output
shape INCLUDING a `Coverage:` section with fixed axes (documents read /
adjudicated decisions considered / changed surfaces reviewed / test
evidence inspected — each answered concretely or
`not applicable: <why>`); and the stateless-reviewer line.

### 4.3 Fan-out orchestration (gate-doc §3/§5 amendments)

- **One `gate-round` call per LOGICAL round**, made once before the
  fan-out; the lens batch consumes a single round of the ceiling. A
  needle pins the sentence; `gate-round` itself is code-unchanged.
- **Document gates:** lenses run SEQUENTIALLY in the FOREGROUND (two
  `task --fresh` calls, each with the existing 10-minute timeout). The
  existing "never background a document review" Red Flag stands
  unmodified.
- **Code/final gates:** lenses use the existing detached-launch + watch
  machinery — launch all lens jobs, then watch each via
  `status <id> --wait`; concurrent where the companion permits,
  pipelined where it serializes (a plan-time live check records which;
  correctness is independent of interleaving).
- **Re-review rounds (2+):** single reviewer, existing round-aware
  preamble and ledger contract, plus one added sentence: confirmation
  rounds use no lenses.

### 4.4 Fail-closed merge

The controller captures each lens output to its own file and runs
`verdict-normalize --require-coverage` on each. Round verdict:

- ALL lenses `approved` → round approved (feeds §5's merged success
  condition unchanged).
- ANY lens `incomplete` after per-lens §4b recovery (re-fetch; at most
  one relaunch of that lens if the failure looked transient) → the round
  is incomplete: surviving lenses' blocking findings still enter the
  round ledger as actionable work, but nothing approves.
- Otherwise → blocking; findings dedup into the ONE round ledger
  (prose-governed: same file/section + same defect = one entry), each
  tagged `[lens: <name>]` (and `[out-of-lane]` where applicable).

### 4.5 `verdict-normalize --require-coverage`

Flag-gated extension, callers without the flag byte-identical: with the
flag, EVERY approve path requires coverage evidence before `approved`
can be returned — the text path checks for a `Coverage:` (or
`## Coverage`) heading followed by non-whitespace content in the
document text; the structured-JSON path (code/final gate payloads)
checks the same anchor in the payload's raw review text
(`.storedJob.result.rawOutput` / `.codex.stdout`) BEFORE honoring the
structured approve verdict. Absence or bare heading on either path →
`incomplete` with reason `approve without coverage evidence`.
`blocking`/`needs-attention` outcomes are unaffected by the flag. The
structural-anchor pattern is already proven by the Summary-content
check. Round-1 lens captures are normalized WITH the flag; re-review
rounds and all legacy callers without it. The test matrix covers both
paths: JSON approve-without-coverage → incomplete, JSON
approve-with-coverage → approved, text equivalents, and the without-flag
byte-identical regression.

### 4.6 Gate-doc amendments summary

- §3: dossier assembly step per recipe (which inputs exist at that
  moment: doc gates — the artifact + spec-gate ledger; per-task —
  adjudications + implementer report + base/head; final — plan/spec +
  minor ledger + branch range); lens prompt templates replace the single
  round-1 prompts; the one-gate-round-per-logical-round sentence.
- §4b: per-lens normalization with `--require-coverage`; the all-lenses
  merge rule; per-lens incomplete recovery.
- §5: round-1 composition references the fan-out; re-review rounds
  explicitly lens-free; ledger entries carry lens tags. The merged
  success condition defines the APPROVAL SET explicitly: round 1's
  approval set is every lens capture of that round; a re-review round's
  approval set is its single capture; an EMPTY capture set never
  approves. The reworded condition — and its updated needle — reads
  "every capture required for the latest round" so a single approved
  capture cannot satisfy a fan-out round and a lens-free re-review round
  is neither excluded nor vacuously satisfied.
- §7 sweep: inherits the fan-out automatically via its §3 recipe
  references — no sweep-specific wording changes (sweep reviews are
  round 1 of their own gates and fan out like any other).
- Degrade notes: dossier build failure → path-based prompts +
  attribution; lens loss → attributed non-approving round.
- All existing Red Flags, ledger appends, backstop semantics, sweep
  section, and suppression lines untouched.

## 5. Lifecycle (round 1 of any gate)

1. Preflight (6.3.0) → `gate-round` once for the logical round →
   `review-dossier` assembles the gate's context artifact.
2. Fan out the gate type's lenses over the dossier (sequential
   foreground for doc gates; detached + watched for code gates).
3. Capture each lens; `verdict-normalize --require-coverage` each;
   merge per §4.4; write the round ledger with lens tags.
4. Blocking → existing fix loop; round 2+ single-reviewer against the
   ledger. Approved → existing §5 merged success condition. Incomplete →
   existing §4b handling, per lens first, then round-level.

## 6. Error handling and safety

- Dossier failure never blocks a gate: attributed fallback to
  path-based prompts. Durability, stated deliberately: this is
  hand-back attribution plus the durable artifact trail — NOT an
  ungated-ledger event, because the gate still ran with Codex review
  (the ledger's classes record missing Codex confirmation, which this is
  not). The durable signal is structural: a lens round that ran with a
  dossier leaves `dossier.md` in its `GATE_DIR`; one that fell back does
  not, and `gate-telemetry` gains a dossier-presence count per gate run
  (a one-line addition to its run-dir scan) so fallback frequency is
  fleet-visible without transcript mining.
- Truncation is explicit everywhere (dossier markers; Coverage answers
  name the limit).
- A lens that dies or stays incomplete cannot be silently dropped: the
  round cannot approve without every lens's normalized approve; the
  attributed gap appears in the ledger and hand-back.
- No approval-authority change: `verdict-normalize` outputs remain the
  only exit; the coverage floor only ADDS a way to be incomplete, never
  a way to approve.
- Companion concurrency is never assumed: the contract is written for
  pipelined execution; concurrency is an observed optimization.

## 7. Testing

- **`review-dossier` fixture tests**: all five sections present in
  order; NOT-PROVIDED variants (flag absent vs unreadable file);
  truncation marker with exact line counts; changed-surfaces from a
  fixture repo; JSON contract (sections/missing counts); exit
  discipline.
- **`verdict-normalize` matrix additions**: with `--require-coverage` —
  missing Coverage / bare heading / present-with-content on approve;
  needs-attention unaffected by the flag; without flag — byte-identical
  regression on the full existing matrix.
- **Contract needles**: lens template phrases per gate type, the
  exhaustiveness line, the out-of-lane rule, the
  one-gate-round-per-logical-round sentence, the all-lenses-must-approve
  merge rule, doc-lens sequential-foreground, dossier degrade note — and
  the full pre-existing needle set stays green (92 at last count).
- **Micro-tests** (writing-skills discipline, controller-run): (a) a
  lens rep given its charter + a dossier stimulus stays in its lane AND
  reports an out-of-lane blocker labeled as such; (b) a merge stimulus
  with two lenses reporting the same defect dedupes to one ledger entry
  crediting both; (c) a lens stimulus whose dossier section says
  NOT PROVIDED answers that Coverage axis as cannot-verify rather than
  guessing.
- **Live verification during implementation**: whether the companion
  runs two adversarial-review jobs concurrently for one repo (recorded
  in the plan; both outcomes acceptable).
- **Eval scenario**: one candidate noted, not committed — a stub-
  companion scenario asserting two doc-lens invocations and a merged
  ledger; the plan decides whether it is cheap enough this release.
- **Telemetry (soft acceptance)**: `gate-telemetry --json` snapshots
  before (already captured: the 6.4.0-era baseline plus July mining
  numbers) and after the first release executed under lenses;
  directional targets — multi-round rate and backstop rate down.

## 8. Acceptance criteria

1. `review-dossier` produces the five-section artifact with explicit
   NOT-PROVIDED and truncation semantics, fixture-tested; a doc-gate
   dossier inlines the artifact with line numbers; a task-gate dossier
   carries adjudications and test evidence when supplied.
2. The amended gate doc composes round 1 as: one `gate-round` advance →
   dossier → lens fan-out → per-lens `--require-coverage` normalization
   → all-lenses merge; needles pin each element; no pre-existing needle
   or Red Flag is weakened.
3. `verdict-normalize --require-coverage` returns `incomplete` for an
   approve lacking coverage evidence and is byte-identical without the
   flag (full regression matrix green).
4. Re-review rounds are explicitly lens-free and their contract is
   textually unchanged otherwise.
5. Degrade paths are attributed: dossier-less gates fall back to
   path-based prompts with a named note; a lost lens yields a
   non-approving round with the gap named in ledger and hand-back.
6. All existing suites green (ledger, gate-round, telemetry, notice,
   sweep-toolchain, contract needles, hooks); lint clean; version
   manifests at 6.5.0.
7. Controller micro-tests (a)–(c) recorded PASS in the execution
   ledger.
8. The plan gate's Algorithm Assessment contract survives fan-out
   intact: it is emitted by the feasibility-and-contracts lens only,
   adjudicated and locked before the approval set is evaluated, and
   every pre-existing Assessment needle stays green alongside the new
   single-lens composition needle.

## 9. Risks

- **Lens overlap noise** (same finding from two lenses) — expected and
  cheap: dedup is prose-governed at merge; overlap is corroboration,
  not cost.
- **Coverage schema rigidity** (false incompletes from semantically-
  answered-but-structurally-odd outputs) — mitigated: the floor checks
  for the heading + content only, not per-axis parsing; per-axis
  discipline lives in the prompt contract and micro-tests.
- **Round-1 cost multiplication on gates that would have one-rounded** —
  accepted by explicit priority ordering (correctness > time > cost);
  the mined 55–77% multi-round rates mean the expected-case trade is
  neutral-to-positive.
- **Prompt-size growth from inlined dossiers** — bounded by per-file
  caps with explicit truncation; doc gates trade 500–950K fetch tokens
  for one bounded inline.
- **Agents skipping the fan-out under time pressure** — needles +
  micro-tests + the coverage floor (a single narrow review cannot
  produce all lenses' coverage-bearing approvals); escalation path if
  evals show drift mirrors 6.3.0's recorded wrapper option.
