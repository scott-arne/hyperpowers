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

On a re-review (round 2+), prepend the round-aware preamble from §5 (Round
ledger) to the prompt below and pass the ledger path, so Codex confirms prior
resolutions instead of re-reviewing cold. The first round uses the prompt as-is.

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

## 4b. Completion check — incomplete is not approval

A Codex result has three outcomes, not two: *approve*, *blocking findings*, and
**incomplete**. An incomplete result carries no verdict and must never be read as
approval or as "no findings."

**Why this matters (grounding).** The code recipes call `adversarial-review`,
which runs **foreground-only**: `handleReviewCommand` always calls
`runForegroundCommand`; only the `task` command has a background-launch path. The
companion's 240s `waitTimedOut` deadline belongs to `status --wait`, not to the
review command. On a long review the harness's own command/tool timeout can abort
the blocking call before a verdict arrives, leaving partial trace output and no
terminal result.

**A code-review result is incomplete when any hold:**

- the invocation is aborted by the harness command/tool timeout before returning,
- the process exits non-zero,
- the `--json` payload has no terminal verdict / no structured `result` payload,
- the rendered text reads as in-progress ("still verifying", "continuing to
  review", partial findings with no verdict).

**Required handling:**

1. Do not interpret an incomplete result as approval, and do not interpret it as
   findings. Treat it as "review not yet known."
2. Give the review room, then recover best-effort, bounded:
   - invoke the review under an explicit command timeout of **600000 ms (10
     minutes)** so a normal-length review (typically 2–4 minutes) is not aborted
     mid-flight;
   - if it still returns without a terminal verdict, recover without re-running
     the review — review jobs are tracked on disk. Find the most recent review
     job with `status --json`, whose snapshot exposes `running` (active jobs),
     `latestFinished`, and `recent` (each job carries `id` and
     `jobClass: "review"`) — there is no flat `jobs[]` array. Poll a specific job
     with `status <job-id> --json` and read `.job.status`. Read the stored review
     payload with `result <job-id> --json`: the parsed verdict/findings are at
     `.storedJob.result.result`, and the raw review text at
     `.storedJob.result.rawOutput` or `.storedJob.result.codex.stdout`. The
     authoritative signals are `.job.status` (`queued`/`running` = not done;
     `completed`/`failed`/`cancelled` = terminal) and the
     `.storedJob.result.result` payload;
   - if `.job.status` is still `running`, wait ~30s and re-query, up to **2
     additional poll cycles**. A poll cycle is not a review round — it does not
     consume the §5 convergence/backstop budget.
3. If still incomplete after the bounded recovery, hand back to the user as
   "Codex review did not complete (still running / aborted before verdict)" —
   never silently pass. Like every other gate failure this degrades to "no Codex
   review," not "Codex approved."

There is no background path for code gates: adding background launch to
`adversarial-review` would require changing `codex-plugin-cc`, which is out of
scope. The mitigation for slow reviews is the generous explicit timeout plus the
best-effort recovery above — not `--background`. Synchronous `task` document
gates are short and unaffected.

> **Red Flag — Never** treat an unfinished, timed-out, or "still verifying"
> Codex result as "no findings" / approval. Incomplete is not a pass. Recover via
> `status`/`result` or surface it — do not infer a verdict Codex did not give.

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
   - **Converged** — the round produced **no new blocking findings** (everything
     it raised is already-resolved, confirmed via the ledger, or a
     previously-declined item with no new argument) **and** the round ledger has
     no still-open blocking findings. Converge only if the round ledger has no
     still-open blocking findings — a blocker the latest round merely failed to
     re-mention is still open and still blocks. This is a fixed point; stop even
     if the backstop is not reached. If a still-open blocker remains, do not
     converge: keep looping (fix it or explicitly decline it with reasoning) or
     stop only via the backstop and hand back the unresolved finding.
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

- Codex verdict, the round count, and whether the loop exited by convergence or
  by hitting the backstop,
- what Codex flagged (by mapped severity),
- what was fixed,
- what was declined and why,
- any unresolved blocking findings if the backstop was hit,
- whether an incomplete result occurred and how it was resolved (recovered via
  `status`/`result`, or surfaced to the user).

Then continue the skill (present to user / mark complete / finish branch).
