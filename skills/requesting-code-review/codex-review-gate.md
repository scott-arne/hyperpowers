# Codex Review Gate

A shared stage-gate that asks Codex (via codex-plugin-cc) to review an artifact
**after** Claude has done its own review/refine/fix pass and **before** the user
is re-engaged or the work is declared complete. Referenced by brainstorming,
writing-plans, subagent-driven-development, and requesting-code-review.

**Claude Code only.** Run this gate only under Claude Code. In any other harness,
skip it silently — do not run the probe, do not emit the notice.

## 1. Probe availability

Run the probe by its absolute path inside the installed plugin (`$CLAUDE_PLUGIN_ROOT`
is set by Claude Code to this plugin's install directory):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/requesting-code-review/scripts/codex-available.sh"
```

(When working inside a hyperpowers dev checkout rather than an installed plugin,
`$CLAUDE_PLUGIN_ROOT` is unset; run `bash skills/requesting-code-review/scripts/codex-available.sh`
from the repo root instead.)

- **Exit 0:** a Codex review can run. stdout is the Codex install path — capture it
  as `CODEX_PATH` for the invocation step.
- **Non-zero exit:** Codex is unavailable. Emit the **No-Codex notice** (below) at
  this point and continue the skill unchanged. Do not treat this as an error.

Probe at most once per skill run and reuse the result for every gate in that run.

## 2. No-Codex notice (degrade path)

When the probe exits non-zero, tell the user once, at this gate:

```
Note: codex-plugin-cc is not available, so this review will run without an
additional Codex review. Install it for an extra review gate:
  /plugin marketplace add openai/codex-plugin-cc
  /plugin install codex@openai-codex
  /reload-plugins
  /codex:setup
```

Then proceed exactly as the skill would without this gate.

## 3. Invoke Codex by artifact type

Use absolute paths for every file placeholder. Prefer file handoffs over pasted
content; the prompt should point Codex at the source material, not copy it.

**Spec documents** — use `task`, read-only (no `--write`):

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --prompt-file <SPEC_REVIEW_PROMPT_PATH>
```

`<SPEC_REVIEW_PROMPT_PATH>` should contain a short prompt like this. Copy the
Required document-review output block below into the prompt so Codex has the
schema in its own context.

```markdown
Review the spec document at <SPEC_ABSOLUTE_PATH> for completeness, internal
consistency, ambiguity, and scope. If original user requirements or approved
design notes are available, use them as context: <APPROVED_DESIGN_CONTEXT_PATH>.
Do not edit anything. Return exactly the Required document-review output from
the output shape included below.
```

**Plan documents** — use `task`, read-only (no `--write`), and provide both the
source spec and the plan:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --prompt-file <PLAN_REVIEW_PROMPT_PATH>
```

`<PLAN_REVIEW_PROMPT_PATH>` should contain a short prompt like this. Copy the
Required document-review output block below into the prompt so Codex has the
schema in its own context.

```markdown
Review the implementation plan at <PLAN_ABSOLUTE_PATH> against the source spec at
<SPEC_ABSOLUTE_PATH>. Check feasibility, task sizing, missing steps, ordering,
type/signature consistency, and spec coverage. Do not edit anything. Return
exactly the Required document-review output from the output shape included below.
```

**Per-task code** — use `adversarial-review` so Codex sees the diff and the
task-scoped context:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --wait --json "Task-scoped review. Requirements: <TASK_BRIEF_PATH>. Implementer report: <IMPLEMENTER_REPORT_PATH>. Review package: <REVIEW_PACKAGE_PATH>. Global constraints: <GLOBAL_CONSTRAINTS_PATH>. Review for task compliance and code quality. Do not edit anything."
```

`<BASE_SHA>` is the recorded task base from before the implementer was
dispatched. The focus text stays short because the task brief, implementer
report, review package, and global constraints carry the real context.

**Final whole-branch code** — use `adversarial-review` over the branch range and
point Codex at the final-review inputs:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <MERGE_BASE_SHA> --wait --json "Final whole-branch review. Branch review package: <BRANCH_REVIEW_PACKAGE_PATH>. Plan or requirements: <PLAN_OR_REQUIREMENTS_PATH>. Minor findings ledger, if present: <MINOR_LEDGER_PATH>. Review for correctness, requirements coverage, integration risk, and code quality. Do not edit anything."
```

**Code-review requests** — use `adversarial-review` over the same range the
Claude reviewer used. If the requirements are a file, pass the file path; if
they are short text, include that text in the focus string.

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --wait --json "Code review. Requirements or review context: <PLAN_OR_REQUIREMENTS_CONTEXT>. Review for correctness, requirements alignment, integration risk, and code quality. Do not edit anything."
```

### Required document-review output

For spec and plan reviews, require this exact shape so Claude does not have to
infer a verdict from prose:

```markdown
Verdict: approve|needs-attention

Blocking Findings:
- severity: critical|high
  title: ...
  evidence: <file>:<line references>
  issue: ...
  recommendation: ...

Non-blocking Findings:
- severity: medium|low
  title: ...
  evidence: <file>:<line references>
  issue: ...
  recommendation: ...

Cannot verify:
- requirement: ...
  reason: ...
  needed evidence: ...

Summary: ...
```

Every finding should include line references when the artifact has stable line
numbers. If there are no findings in a section, write `None`.

For code recipes, prefer `--json` and read the structured `result` payload when
present. If the companion renders text instead, extract the same verdict,
findings, and severity fields.

## 4. Interpret — severity mapping

Map Codex severities to Hyperpowers' vocabulary:

| Codex | Hyperpowers | Blocking? |
|-------|-------------|-----------|
| critical | Critical | yes |
| high | Important | yes |
| medium / low | Minor | no |

**Blocking = Critical + Important.** Minor findings are noted, not fixed in the loop.

## 5. Fix-and-re-review loop (converge, then stop)

After the first Codex review, every later round is a **re-review against known
state**, not a cold re-derivation. The loop ends as soon as the work is actually
done — it does not burn a fixed attempt budget.

### Round ledger (re-review memory)

Before re-running Codex (round 2+), write a small handoff file next to the other
gate artifacts (e.g. `…/codex-round-ledger.md`). Do not paste it into your own
context — hand it over as a file path. For each completed round it records:

- **Resolved** — each blocking finding and how it was addressed, with the fix
  commit/diff reference (code) or the spec/plan edit (documents).
- **Declined** — each finding you declined, with the explicit reasoning (the
  decision below to decline a finding, carried forward instead of lost).
- **Still open** — any blocking finding not yet resolved, and why.

Each later round appends a new section; the ledger is the cumulative record.

The round 2+ invocation prepends a round-aware preamble to the §3 prompt:

> This is re-review round N. The prior-round findings and how each was resolved
> or declined are in `<LEDGER_PATH>`. Confirm the resolved findings are actually
> fixed. Do not re-raise a finding listed as declined unless you can show the
> stated reasoning is wrong. You may raise any genuinely new **blocking
> (Critical or High)** finding — whether or not it is a regression — provided it
> is not already listed as resolved and not a declined item without a new
> argument. Do not raise new Minor (medium/low) findings on a re-review.

The bar on re-review is "new and blocking," not "new and a regression": a
newly-noticed Critical or High issue is still blocking even if it predates round
1. What is excluded on re-review is Minor noise, not new blocking severity.

### The loop

1. If verdict is `approve` and there are no blocking findings → done; go to step 6.
2. Otherwise address each blocking finding: for a document, edit the spec/plan; for
   code, dispatch a fix through the skill's existing fix path (e.g. SDD's fix
   subagent). You MAY decline a finding with explicit reasoning instead of fixing it.
   Record resolutions, declines, and still-open items in the round ledger.
   After any code fix, re-run the same Claude reviewer gate before re-running Codex.
3. Re-run the same Codex invocation (with the round-aware preamble and ledger
   path) over the updated artifact once the relevant Claude review gate is clean.
4. **Stop when any holds:**
   - **Approved** — `approve` with no blocking findings.
   - **Converged** — the round produced **no new blocking findings**: everything
     it raised is already-resolved (confirmed via the ledger) or a
     previously-declined item with no new argument. This is a fixed point; stop
     even if the backstop is not reached.
   - **Backstop hit** — the per-gate round ceiling below is reached. Stop and
     hand back with any unresolved blocking findings listed; do not loop
     indefinitely.

### Per-gate round backstops

| Gate | Recipe | Backstop |
|------|--------|----------|
| Spec / Plan (document gates) | task | 4 |
| Per-task / final / code-review (code gates) | adversarial-review | 3 |

Document gates get 4 rounds (cheap: a text edit + a `task` re-run). Code gates
get 3 rounds (expensive: fix subagent + Claude-reviewer re-run + a fresh
`adversarial-review` per round). Convergence usually stops the loop earlier; the
backstop is a true backstop, not the common exit.

## 6. Hand back

Summarize concisely before returning to the skill's normal next step:

- Codex verdict (and round count if it looped),
- what Codex flagged (by mapped severity),
- what was fixed,
- what was declined and why,
- any unresolved blocking findings if the cap was hit.

Then continue the skill (present to user / mark complete / finish branch).
