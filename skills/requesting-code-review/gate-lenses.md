**Round 1 is a lens fan-out.** The lens batch consumes a single logical round: run `gate-round` once, then launch EVERY lens for this gate type over the same dossier. Per-gate lenses:

| Gate | Lenses |
|------|--------|
| spec | completeness-and-consistency; feasibility-and-scope |
| plan | coverage-and-ordering; feasibility-and-contracts |
| task/adhoc | correctness; contracts-and-integration; tests-and-evidence |
| final | correctness; integration-and-requirements-coverage; tests-and-evidence |

Each lens prompt file is composed from this skeleton (one prompt file per lens, `$GATE_DIR/lens-<name>-prompt.md`):

```markdown
Read the review dossier first — it is your delivered context: <GATE_DIR>/dossier.md
Where a dossier section says NOT PROVIDED, answer that Coverage axis exactly `cannot-verify: <reason>` — never `not applicable`; where it says NOT APPLICABLE, answer it `not applicable: <why>` without hedging.
Your lens for this review: <one charter sentence from the table below>.
Report every blocking finding you can identify this round; do not reserve findings for later rounds.
Findings outside your lens are still reported, labeled [out-of-lane] — never suppressed.
You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills.
Do not edit anything. Return exactly the Required document-review output below, adding a Coverage: section before Summary with these axes, each answered concretely or marked not applicable: documents read; adjudicated decisions considered; changed surfaces reviewed; test evidence inspected.
<the Required document-review output block from gate-output-schema.md, verbatim>
```

When your output is the structured review JSON (code and final gates), the schema has no room for extra sections: put the Coverage section inside the `summary` field as a single `Coverage: <axis> — <answer>; …` run — the coverage floor reads it there.

Lens charters:

| Lens | Charter |
|------|---------|
| completeness-and-consistency | Every requirement present, unambiguous, and internally consistent; contradictions and gaps between sections. |
| feasibility-and-scope | Buildable as specified; scope fits one plan; hidden dependencies and unstated assumptions. |
| coverage-and-ordering | Every spec requirement maps to a task; task sizing and sequencing; nothing implemented before its dependency. |
| feasibility-and-contracts | Types, signatures, and interfaces consistent across tasks; each step executable as written. |
| correctness | Does the change do what its requirements say, and only that; logic, edge cases, failure paths. |
| contracts-and-integration | Interfaces honored; call sites, shared state, and cross-component effects of the diff. |
| tests-and-evidence | Do the tests prove the claims; is the executed evidence in the dossier consistent with the diff; gaps between claim and proof. |
| integration-and-requirements-coverage | Whole-branch: requirements coverage against the plan/spec, integration risk across tasks, Minor-ledger triage. |

**Document gates run their lenses sequentially in the foreground** (two `task --fresh` calls, each with the explicit 600000 ms timeout) — the existing Red Flag against backgrounding document reviews stands. **Code and final gates launch lenses ONE AT A TIME**: launch lens A detached, immediately capture its job id from `status --json` (newest running review — unambiguous because no other lens launch has happened yet), record the id-to-lens binding, and only then launch lens B, capture, and so on. Never capture a job id after a subsequent launch has occurred. Once every lens has a recorded id, watch them in any order or concurrently via `status <job-id> --wait --json` — the ids, not recency, bind results to lenses. Each lens's detached launch delivers its lens prompt as the review focus: the `adversarial-review` focus argument composes that lens's `lens-<name>-prompt.md` content (dossier line, charter, exhaustiveness demand, required `Coverage:` section) together with the context paths the code recipes already require — one launch per lens, each carrying its own lens prompt.

**Plan gate only:** the Round-1 Algorithm Assessment attaches to the feasibility-and-contracts lens and ONLY that lens — append the existing assessment block (verbatim, unchanged trigger and output shape) to that lens's prompt; the coverage-and-ordering lens never emits an Assessment, and any algorithm opinion it volunteers is an ordinary finding. Adjudication and lock run at their existing point, before the approval set is evaluated.

**Re-review rounds (2+) use no lenses**: the existing single-reviewer round-aware preamble and ledger contract apply verbatim. The ORIGINAL single-review spec and plan prompt templates are retained in recipe-document.md, textually unchanged, and rounds 2+ compose from them exactly as today.

