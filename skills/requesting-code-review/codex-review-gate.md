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
from the repo root instead. If it is unset in an *installed-plugin* session —
some shells do not inherit it — resolve the newest install and run the probe
from there: `ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1`.)

- **Exit 0:** a Codex review can run. stdout line 1 is the Codex install path —
  capture it as `CODEX_PATH` for the invocation step. stdout line 2 is the
  installed codex-plugin-cc version — capture it as `CODEX_VERSION` and report
  it in the §6 hand-back. The JSON field paths in §4b are verified against
  codex-plugin-cc **1.0.5**; on another version, confirm a field exists in the
  actual payload before relying on it (fall back to `.storedJob.result.rawOutput`).
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

Write the gate's own scratch files — the prompt files below, the round ledger,
and any handoff — inside a fresh per-run scratch dir. At gate start, run the
helper once and capture its output as `GATE_DIR`:

```bash
GATE_DIR="$(bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/codex-review-dir")"
```

(In a hyperpowers dev checkout `$CLAUDE_PLUGIN_ROOT` is unset; the `:-.` fallback
runs `skills/requesting-code-review/scripts/codex-review-dir` from the repo root.)
The helper prints a unique directory under
`${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/codex-review/`, created for this one
gate invocation. **Use one `GATE_DIR` for the whole gate** — every prompt file
and the round ledger live inside it, and every round reuses the same dir. Because
the dir is unique per invocation, two review gates running at once — even two
Claude Code sessions in the same worktree, or the spec gate and code gate of one
run — never share a ledger or clobber each other's prompt files. Never hand-write
these files under `.git/`, `~/.claude/`, or anywhere outside the working
directory: those paths are protected or out-of-workspace and force an approval
prompt on every write, which is why the helper places them under the user cache.
The reviewed artifact (spec, plan, diff) stays where it lives — only the gate's
transient scratch goes in `GATE_DIR`.

On a re-review (round 2+), prepend the round-aware preamble from §5 (Round
ledger) to the prompt below and pass the ledger path, so Codex confirms prior
resolutions instead of re-reviewing cold. The first round uses the prompt as-is.

Run `task` in the **foreground** — as written below, with no `--background`. The
default `task` mode blocks and returns Codex's result inline when the review
finishes; there is nothing to poll for and nothing to wait on. Never add
`--background` to a document review: it enqueues a detached worker and forces you
into a `status`/`result` polling loop for no benefit. Do not `sleep` and then
poll — the foreground call already returns exactly when Codex is done. Give the
blocking call an explicit command timeout of **600000 ms (10 minutes)**:
document reviews typically finish in 2–5 minutes, but default tool timeouts are
far shorter and an aborted call loses the verdict.

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

**Round-1 Algorithm Assessment (plan gate only).** When BOTH hold — this is
round 1 of the plan gate, AND the plan contains material algorithmic or
data-structure choices (sorting/searching, graph traversal, caching strategies,
concurrency schemes, index/layout choices — not glue code or CRUD wiring) —
append this to the plan prompt:

    Additionally, assess the plan's material algorithm and data-structure choices.
    For each one: is it the right choice for the stated constraints and data
    scale? If not, propose exactly one alternative with justification (complexity,
    tradeoffs, why it wins here). Return this block after the Required output:

    Algorithm Assessment (round 1 only):
    - choice: <algorithm/structure as planned>
      verdict: appropriate | alternative-suggested
      alternative: <name, or None>
      justification: ...

Plans with no material algorithmic content omit this section entirely.
Algorithm suggestions are **advisory input to the controller's decision** —
they do not map onto the Critical/Important severity ladder (§4) and never
drive the fix loop (§5). If Codex separately judges an algorithm choice to be
a genuine correctness defect, that is a normal blocking finding, unchanged.

**Code reviews — launch detached, watch in the foreground.** The three code
recipes below all use `adversarial-review`, which the companion runs as one
long turn (typically 2–5 minutes, sometimes 10+). Never run it as a plain
blocking shell call: if the harness command timeout kills that call, the
companion dies mid-turn and never writes a terminal job state — the job is
orphaned as `running`, `result` refuses it forever, and the verdict is
unrecoverable except by a full re-run. Instead:

1. **Launch in the background.** Run the recipe command with the shell tool's
   run-in-background option (not `nohup`, not a trailing `&`). The detached
   process survives watcher timeouts and always persists a terminal result;
   its captured output also holds the full `--json` payload as a fallback.
2. **Capture the job id.** Immediately run
   `node "$CODEX_PATH/scripts/codex-companion.mjs" status --json` in the
   foreground and take the `id` of the newest `.running[]` entry with
   `jobClass: "review"`; if the job has not registered yet, re-run the status
   call after a couple of seconds.
3. **Watch in the foreground — never idle.** Block on
   `node "$CODEX_PATH/scripts/codex-companion.mjs" status <job-id> --wait --json`;
   each call returns the moment the job goes terminal, or after its 240 s
   deadline with `waitTimedOut: true`. If `.job.status` is still
   `queued`/`running`, immediately issue the next `status <job-id> --wait --json`.
   While the review runs, the session must always be inside one of these
   blocking watch calls — never `sleep`, never fire-and-forget and move on.
   This keeps the session visibly working in harness UIs and the wait
   interruptible, while the review itself is immune to any single call being
   killed.
4. **Read the verdict.** Once `.job.status` is terminal, run
   `node "$CODEX_PATH/scripts/codex-companion.mjs" result <job-id> --json`:
   the parsed verdict/findings are at `.storedJob.result.result`, the raw
   review text at `.storedJob.result.rawOutput`.

Cap the watch at **4 consecutive wait cycles** (~16 minutes). If the job is
still not terminal, treat the result as incomplete per §4b — optionally
`cancel <job-id>` to stop a stalled worker — and never read the absence of a
verdict as approval.

**Per-task code** — use `adversarial-review` so Codex sees the diff and the
task-scoped context:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Task-scoped review. Requirements: <TASK_BRIEF_PATH>. Implementer report: <IMPLEMENTER_REPORT_PATH>. Review package: <REVIEW_PACKAGE_PATH>. Global constraints: <GLOBAL_CONSTRAINTS_PATH>. Review for task compliance and code quality. Do not edit anything."
```

`<BASE_SHA>` is the recorded task base from before the implementer was
dispatched. The focus text stays short because the task brief, implementer
report, review package, and global constraints carry the real context.

**Final whole-branch code** — use `adversarial-review` over the branch range and
point Codex at the final-review inputs:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <MERGE_BASE_SHA> --json "Final whole-branch review. Branch review package: <BRANCH_REVIEW_PACKAGE_PATH>. Plan or requirements: <PLAN_OR_REQUIREMENTS_PATH>. Minor findings ledger, if present: <MINOR_LEDGER_PATH>. Review for correctness, requirements coverage, integration risk, and code quality. Do not edit anything."
```

**Code-review requests** — use `adversarial-review` over the same range the
Claude reviewer used. If the requirements are a file, pass the file path; if
they are short text, include that text in the focus string.

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Code review. Requirements or review context: <PLAN_OR_REQUIREMENTS_CONTEXT>. Review for correctness, requirements alignment, integration risk, and code quality. Do not edit anything."
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

**Why this matters (grounding).** Within the companion, `adversarial-review` is
**foreground-only**: `handleReviewCommand` always calls `runForegroundCommand`,
and the review command's own `--wait`/`--background` flags are parsed but
ignored. The background path for code gates therefore comes from the harness
side — the detached launch in §3 — and it is required, not optional. If the
review is instead run as a plain blocking call and the harness command timeout
kills it, the companion process dies mid-turn and never writes a terminal job
state: the job record stays `running` with a dead worker, `status <job-id>
--wait` burns its full deadline, and `result` refuses forever. No recovery can
conjure the verdict in that case; prevention (the detached launch) is the
mitigation. The 240 s `waitTimedOut` deadline belongs to `status --wait` —
hitting it is not a review failure, just the cue to issue the next watch call.

**A review result is incomplete when any hold:**

- the background launch exits non-zero, or its job never appears in
  `status --json`,
- the §3 watch cap is reached with `.job.status` still `queued`/`running`,
- a foreground call (document review) is aborted by the harness command timeout
  before returning, or exits non-zero,
- the `--json` payload has no terminal verdict / no structured `result` payload
  (`.storedJob.result.result` null — check `.storedJob.result.parseError` for a
  schema-compliance failure that still exits 0),
- the rendered text reads as in-progress ("still verifying", "continuing to
  review", partial findings with no verdict).

**Required handling:**

1. Do not interpret an incomplete result as approval, and do not interpret it as
   findings. Treat it as "review not yet known."
2. Recover best-effort, bounded:
   - **Code gates:** the §3 watch loop *is* the recovery path — the job id is
     known from launch, and `status <job-id> --wait --json` / `result <job-id>
     --json` return the verdict whenever the detached worker finishes, no matter
     how many individual watch calls timed out along the way. If the watch cap
     passes with `.job.status` still `queued`/`running`, the worker is stalled
     or dead: run `status <job-id> --json` one final time, optionally
     `cancel <job-id>`, and stop — relaunch the review at most once, and only if
     the failure looked transient. If the job id was lost, find it again with
     `status --json`, whose snapshot exposes `running` (active jobs),
     `latestFinished`, and `recent` (each job carries `id` and
     `jobClass: "review"`) — there is no flat `jobs[]` array.
   - **Document gates:** the foreground `task` call returned without a verdict.
     Check `status --json` for a completed job holding the result
     (`result <job-id> --json`); if none, re-run the document review once with
     the §3 explicit 600000 ms (10 minutes) timeout if the failure looked
     transient, otherwise surface it.
   - The authoritative signals everywhere are `.job.status`
     (`queued`/`running` = not done; `completed`/`failed`/`cancelled` =
     terminal) and the `.storedJob.result.result` payload, with the raw review
     text at `.storedJob.result.rawOutput` or `.storedJob.result.codex.stdout`.
     Do not hand-roll a `sleep`-then-re-query loop; `status <job-id> --wait
     --json` is the condition-based primitive (2 s interval, 240 s deadline)
     and returns as soon as Codex is done. A wait cycle is not a review round —
     it does not consume the §5 convergence/backstop budget.
3. If still incomplete after the bounded recovery, hand back to the user as
   "Codex review did not complete (still running / aborted before verdict)" —
   never silently pass. Like every other gate failure this degrades to "no Codex
   review," not "Codex approved."

The companion itself offers no working `--background` for `adversarial-review`;
the detached launch in §3 supplies the background path from the harness side.
A plain blocking call turns any harness timeout into an unrecoverable lost
review — that is why the detached launch is the required form, not an
optimization.

Document gates (spec/plan) need none of this watch machinery: run `task` in
the foreground (§3) with the explicit timeout and it blocks and returns the
verdict inline. Do not add
`--background` and do not poll — backgrounding a document review only replaces a
clean blocking call with a detached worker you then have to chase through
`status`/`result`. If you ever do need a job's terminal state, use
`status <job-id> --wait`, never a blind `sleep`.

> **Red Flag — Never** treat an unfinished, timed-out, or "still verifying"
> Codex result as "no findings" / approval. Incomplete is not a pass. Recover via
> `status`/`result` or surface it — do not infer a verdict Codex did not give.

> **Red Flag — Never** background a document review, and never `sleep`-then-poll
> for any Codex result. Foreground `task` returns the verdict inline; when a job
> genuinely needs awaiting, `status <job-id> --wait` returns the instant it is
> done. A blind wait-then-poll burns wall-clock and risks reading a verdict
> before it exists.

> **Red Flag — Never** launch a code review and move on (or fall idle) while it
> runs. The §3 watch loop keeps a blocking `status <job-id> --wait` call in the
> foreground for the whole review — launch-and-forget hides that work is in
> flight and risks acting before the verdict exists.

## 5. Fix-and-re-review loop (converge, then stop)

After the first Codex review, every later round is a **re-review against known
state**, not a cold re-derivation. The loop ends as soon as the work is actually
done — it does not burn a fixed attempt budget.

### Round ledger (re-review memory)

Before re-running Codex (round 2+), write a small handoff file inside the
per-run `GATE_DIR` from §3 (e.g. `"$GATE_DIR/codex-round-ledger.md"`).
Do not paste it into your own context — hand it over as a file path. For each
completed round it records:

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

If a re-review round returns new Minor (medium/low) findings anyway, they are
out of contract: record them in the round ledger as noted (and in the skill's
Minor ledger, if it keeps one), do not fix them in the loop, do not dispatch a
fix for them, and do not let them delay convergence. Only blocking findings
drive the loop.

### Algorithm adjudication and lock (plan gate)

Adjudicate the round-1 Algorithm Assessment immediately after parsing the
round-1 output and **before applying the loop's exit rule**, so an
`alternative-suggested` entry is never dropped by an early `approve` exit:

- **Approve + no alternatives (or all declined):** record the lock(s), then
  exit as usual. A decline changes no plan content, so no re-review is needed;
  declines appear in the ledger and the §6 hand-back.
- **Accepted alternative:** revise the affected plan task(s) — keeping
  interfaces, steps, and cross-task references consistent — record the lock,
  then run **one normal re-review round** over the revised plan (assessment
  omitted, lock line present). A materially revised plan is never handed off
  without a confirming Codex pass. The loop then converges as usual within
  the existing backstop.
- **Needs-attention:** the normal fix loop runs anyway; adjudicate and lock
  alongside the round-1 blocking fixes.

Ledger entry formats:
- `Algorithm locked: <new> (was <old>) — <rationale>`
- `Algorithm locked: <original> — Codex suggested <alt>, declined: <reason>`

On plan-gate re-reviews, append this line to the round-aware preamble and omit
the Algorithm Assessment section from the prompt:

> Algorithm choices are locked per the ledger; do not re-open them absent
> a new blocking correctness defect (Critical or High) in the locked choice.

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
     indefinitely. Fixes applied in the backstop round ship without a
     confirming Codex pass — flag them in the §6 hand-back as verified by the
     Claude reviewer and tests only, not re-reviewed by Codex.

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
- whether any fixes were applied after the last Codex round (backstop exits) —
  state explicitly that those fixes are not re-reviewed by Codex,
- any Minor findings noted but not fixed, including out-of-contract Minors
  raised on re-review,
- whether an incomplete result occurred and how it was resolved (recovered via
  `status`/`result`, or surfaced to the user),
- the review runtime: the codex-plugin-cc version (`CODEX_VERSION` from the §1
  probe) and the Codex model and reasoning effort the reviews ran with — read
  `model` and `model_reasoning_effort` from
  `${CODEX_HOME:-$HOME/.codex}/config.toml`; the companion runs reviews at
  these config defaults.

Then continue the skill (present to user / mark complete / finish branch).
