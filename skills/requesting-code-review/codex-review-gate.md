# Codex Review Gate

A shared stage-gate that asks Codex (via codex-plugin-cc) to review an artifact
**after** Claude has done its own review/refine/fix pass and **before** the user
is re-engaged or the work is declared complete. Referenced by brainstorming,
writing-plans, subagent-driven-development, and requesting-code-review.

**Claude Code only.** Run this gate only under Claude Code. In any other harness,
skip it silently — do not run the preflight, do not emit the notice.

## 1. Preflight availability

Run the preflight by its absolute path inside the installed plugin
(`$CLAUDE_PLUGIN_ROOT` is set by Claude Code to this plugin's install
directory):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/requesting-code-review/scripts/codex-preflight"
```

(When working inside a hyperpowers dev checkout rather than an installed
plugin, `$CLAUDE_PLUGIN_ROOT` is unset; run
`bash skills/requesting-code-review/scripts/codex-preflight` from the repo
root instead. If it is unset in an *installed-plugin* session, resolve the
newest install: `ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1`.)

It prints one JSON line. Branch on `.status`:

- **`"ok"`** — a Codex review can run. Capture `.codexPath` as `CODEX_PATH`
  and `.codexVersion` as `CODEX_VERSION` (report it in the §6 hand-back).
  The JSON field paths in §4b's payloads are verified against codex-plugin-cc
  **1.0.5–1.0.6**; on another version, confirm a field exists in the actual
  payload before relying on it.
- **`"not-installed"`** — emit the **No-Codex notice** (§2) and continue the
  skill unchanged. Do not treat this as an error.
- **`"not-ready"`** — the plugin is installed but Codex is not ready
  (`.reason` says why: not authenticated, CLI missing, transient handshake
  failure that outlasted retries). Tell the user once:
  "Note [status: not-ready]: codex-plugin-cc is installed but not ready (<.reason>), so this review will run without an additional Codex review." Then continue exactly
  as the §2 degrade path.
- **`"stale-broker"`** — the plugin is installed but this repo's companion
  broker is dead (its temp dir was likely purged mid-session; the session-
  start janitor clears these at startup/compact, so this means it died
  since). Tell the user once, quoting `.recovery` verbatim:
  "Note [status: stale-broker]: the Codex companion broker for this repo is stale, so this review will run without a Codex review. To restore Codex for the next gate, run this in a terminal: <.recovery>" — then continue as the §2 degrade path.
  The next gate re-runs preflight and picks the recovery up automatically.
- **Non-zero exit** (internal failure — the preflight tooling itself broke) —
  degrade exactly like §2, but with its own attribution. Tell the user once:
  "Note [status: preflight-error]: the Codex preflight failed (<stderr summary>), so this review will run without an additional Codex review."
  Do not treat this as an error and do not claim Codex is not installed.

**Record every degrade durably.** Whenever a gate proceeds on a degrade
branch (`not-installed`, `not-ready`, `stale-broker`, `preflight-error`),
append a ledger event before continuing — document gates:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class degraded-gate --gate <spec|plan> --status <token> --note "<one line; include the task brief / plan path if one exists — the sweep uses it as a breadcrumb>"
```

Code gates additionally record the exact range that will ship unreviewed:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class degraded-gate --gate <task|final|adhoc> --base <the gate's BASE sha> --head "$(git rev-parse HEAD)" --status <token> --note "<one line; include the task brief / plan path if one exists — the sweep uses it as a breadcrumb>"
```

`--gate-dir` is omitted here on purpose: preflight runs BEFORE §3 creates
`GATE_DIR`, and `gateDir` is a forensic breadcrumb only — class-1 preflight
events legitimately carry `gateDir:null`. If a `GATE_DIR` already exists
for this gate when the degrade occurs, passing `--gate-dir "$GATE_DIR"` is
welcome but never required.

If the append itself fails, say so loudly in the §6 hand-back ("ungated
event could NOT be recorded — note this manually") and continue — a
bookkeeping failure never blocks the gate.

**Re-surface pending work on healthy preflight.** When `.status` is `ok`,
check the backlog once per skill run: `ungated-ledger pending --count .` —
if `.count` > 0, tell the user once:
"N ungated review item(s) pending sweep in this repo — say \"run the review sweep\" (§7) to clear them."
Then proceed with this gate normally; the notice never blocks or delays it.

Preflight at most once per skill run and reuse the result for every gate in
that run. Every degrade notice must name its status (`not-installed`,
`not-ready`, `stale-broker`, or `preflight-error`) so the §6 hand-back — and future transcript
mining — can attribute exactly why a gate ran without Codex.

## 2. No-Codex notice (degrade path)

When preflight returns `not-installed`, tell the user once, at this gate:

```
Note [status: not-installed]: codex-plugin-cc is not available, so this review will run without an additional Codex review. Install it for an extra review gate:
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
resolutions instead of re-reviewing cold. The first round composes the per-lens prompts from the lens fan-out block below instead of this single prompt.

Run `task` in the **foreground** — as written below, with no `--background`. The
default `task` mode blocks and returns Codex's result inline when the review
finishes; there is nothing to poll for and nothing to wait on. Never add
`--background` to a document review: it enqueues a detached worker and forces you
into a `status`/`result` polling loop for no benefit. Do not `sleep` and then
poll — the foreground call already returns exactly when Codex is done. Give the
blocking call an explicit command timeout of **600000 ms (10 minutes)**:
document reviews typically finish in 2–5 minutes, but default tool timeouts are
far shorter and an aborted call loses the verdict.

**Count every round — the first included.** Before composing ANY LOGICAL round (round 1 included), run §5 step-0's `gate-round` counter once for this `GATE_DIR`; a round-1 lens batch counts as ONE round — individual lens launches within the batch do NOT advance the counter; only a `"verdict":"proceed"` may launch the batch (or the single re-review).

**Assemble the dossier — reviewers receive, rather than fetch.** Only a
`"verdict":"proceed"` from the logical round's `gate-round` call reaches
this step: on `backstop` or a non-zero exit, stop before assembling
anything (a stopped round leaves no `dossier.md`, keeping the
dossier-presence telemetry signal clean). On proceed, build the gate's
context artifact:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/review-dossier" --gate <spec|plan|task|final|adhoc> --out "$GATE_DIR" <inputs per the table below>
```

| Gate | Inputs to pass |
|------|----------------|
| spec | `--spec <spec path>` plus `--adjudications <path>` for any approved-design/decision context |
| plan | `--doc <plan path> --doc <spec path>` plus `--adjudications <spec-gate round ledger path>` |
| task/adhoc | `--adjudications <spec decision excerpts / spec-gate ledger> --test-evidence <implementer report path> --base <task BASE> --head <head sha>` |
| final | all of the above: plan/spec docs, ledgers, Minor ledger, branch `--base <merge-base> --head <head>` |

The dossier renders every expected-but-missing input as `NOT PROVIDED`
(reviewers treat that axis as cannot-verify) and gate-type-inapplicable
inputs as `NOT APPLICABLE`. If the dossier build itself fails, the gate
falls back to the path-based prompts with the failure named in the §6 hand-back — never blocked,
always attributed. **The fallback keeps the SAME approval contract:**
compose the same lens prompts with the dossier line replaced by the
original path-based context lines (the artifact/brief/report paths the
recipes name), so every fallback lens still carries the lens charter, the
exhaustiveness demand, and the required `Coverage:` section — its axes
answered from what the reviewer fetched — and round-1 fallback captures
are normalized with `verdict-normalize --require-coverage` exactly like
dossier-backed ones. One approval rule everywhere; the only thing a
fallback loses is delivered context.

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
<the existing Required document-review output block, verbatim>
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

**Re-review rounds (2+) use no lenses**: the existing single-reviewer round-aware preamble and ledger contract apply verbatim. The ORIGINAL single-review spec and plan prompt templates are retained below, textually unchanged, and rounds 2+ compose from them exactly as today.

**Re-review prompt (rounds 2+):**

**Spec documents** — use `task`, read-only (no `--write`):

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --prompt-file <SPEC_REVIEW_PROMPT_PATH>
```

`<SPEC_REVIEW_PROMPT_PATH>` should contain a short prompt like this. Copy the
Required document-review output block below into the prompt so Codex has the
schema in its own context.

```markdown
Review the spec document at <SPEC_ABSOLUTE_PATH> for completeness, internal consistency, ambiguity, and scope. If original user requirements or approved design notes are available, use them as context: <APPROVED_DESIGN_CONTEXT_PATH>. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything. Return exactly the Required document-review output from the output shape included below.
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
Review the implementation plan at <PLAN_ABSOLUTE_PATH> against the source spec at <SPEC_ABSOLUTE_PATH>. Check feasibility, task sizing, missing steps, ordering, type/signature consistency, and spec coverage. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything. Return exactly the Required document-review output from the output shape included below.
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

Plans with no material algorithmic or data-structure choices omit this section entirely.
Algorithm suggestions are **advisory input to the controller's decision** —
they do not map onto the Critical/Important severity ladder (§4) and never
drive the fix loop (§5). If Codex separately judges an algorithm choice to be
a genuine blocking defect, that is a normal blocking finding, unchanged.

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
4. **Read the verdict.** Once `.job.status` is terminal, run `node "$CODEX_PATH/scripts/codex-companion.mjs" result <job-id> --json`: write the full `result <job-id> --json` output to a file inside `GATE_DIR` and run `verdict-normalize` on it; the raw review text for reading findings remains at `.storedJob.result.rawOutput`.

Cap the watch at **4 consecutive wait cycles** (~16 minutes). If the job is
still not terminal, treat the result as incomplete per §4b — optionally
`cancel <job-id>` to stop a stalled worker — and never read the absence of a
verdict as approval.

**Base validation — required before every `adversarial-review` launch.** Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/base-ref-ok" <BASE_SHA>
```

If it prints `"ok":true`, use `.resolvedBase` as the launch base. If
`"ok":false`, do NOT launch: an invalid base (empty-tree hash, no merge-base,
base==HEAD, unresolvable ref) makes the companion's merge-base fatal mid-job
and orphans the review as `running` forever. Fix the base (common causes:
wrong branch name, an unborn branch, a recorded SHA from a different
worktree) and re-validate; if it cannot be fixed, degrade with the reason —
"Codex review skipped: invalid review base (<reason>)."

**Per-task code** — use `adversarial-review` so Codex sees the diff and the
task-scoped context:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Task-scoped review. Requirements: <TASK_BRIEF_PATH>. Implementer report: <IMPLEMENTER_REPORT_PATH>. Review package: <REVIEW_PACKAGE_PATH>. Global constraints: <GLOBAL_CONSTRAINTS_PATH>. Review for task compliance and code quality. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

`<BASE_SHA>` is the recorded task base from before the implementer was
dispatched. The focus text stays short because the task brief, implementer
report, review package, and global constraints carry the real context.

**Tier applicability (SDD tasks only).** Per-task code gates run for
standard- and high-tier tasks. An SDD task whose EFFECTIVE tier is low —
declared at plan time, reviewed by the plan gate, never lowered at
dispatch, with no escalation trigger fired — skips this gate entirely:
record the skip with `ungated-ledger append --class tier-skip --gate task --base <TASK_BASE> --head <HEAD> --tier-declared low --tier-effective low --note "Task N: <rationale>"` and move on; the Claude task reviewer and the final whole-branch gates never tier off. Ad-hoc code-review requests have no tier and always run.

**Final whole-branch code** — use `adversarial-review` over the branch range and
point Codex at the final-review inputs:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <MERGE_BASE_SHA> --json "Final whole-branch review. Branch review package: <BRANCH_REVIEW_PACKAGE_PATH>. Plan or requirements: <PLAN_OR_REQUIREMENTS_PATH>. Minor findings ledger, if present: <MINOR_LEDGER_PATH>. Tier-skip summary, if any: <TIER_SKIPS_PATH>. Review for correctness, requirements coverage, integration risk, and code quality. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

When any task skipped its per-task gate, pass the tier-skip summary file as <TIER_SKIPS_PATH> AND include it among the final dossier's --adjudications inputs, so both the prompt and the delivered dossier carry it.

**Code-review requests** — use `adversarial-review` over the same range the
Claude reviewer used. If the requirements are a file, pass the file path; if
they are short text, include that text in the focus string.

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Code review. Requirements or review context: <PLAN_OR_REQUIREMENTS_CONTEXT>. Review for correctness, requirements alignment, integration risk, and code quality. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
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

**Mechanical normalization — the only approval authority.** Write the
captured result (the foreground `task` stdout, or `result <job-id> --json`
output) to a file inside `GATE_DIR`, then run:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/verdict-normalize" "$GATE_DIR/<captured-output-file>"
```

Round-1 captures (every lens, dossier-backed or fallback) add `--require-coverage` to this command; re-review rounds run it without the flag.

**Round-1 lens captures.** Normalize every round-1 capture with `verdict-normalize --require-coverage` — the coverage floor is part of the approval authority. Capture each lens's output to its own file in `GATE_DIR` and normalize each:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/verdict-normalize" --require-coverage "$GATE_DIR/lens-<name>-capture"
```

The round's verdict merges fail-closed: ALL lenses `approved` → the round is approved. ANY lens
`incomplete` — after per-lens recovery (the bounded re-fetch below, plus at most one relaunch of
THAT lens if the failure looked transient) — → the round is incomplete: surviving lenses' blocking
findings still enter the round ledger as actionable work, but nothing approves. Otherwise → blocking.
Deduplicate findings into the ONE round ledger: same file/section + same defect = ONE merged entry
— never one entry per lens — written once with every reporting lens's tag appended, e.g. `[lens:
correctness] [lens: contracts-and-integration]`; every entry carries its source tag `[lens: <name>]`
(plus `[out-of-lane]` where the lens said so). Re-review rounds normalize their single capture
WITHOUT the flag, exactly as today.

Its tri-state `.result` is the review outcome: `approved`, `blocking`, or
`incomplete`. Only a `verdict-normalize` result of `approved` counts as
approval — never your own reading of the raw output, and never the absence
of output. On `blocking`, read the raw findings text as usual to do the
fixing; normalization gates only the decision. On `incomplete`, follow the
recovery steps below, re-capture, and re-normalize; if it remains
`incomplete`, surface "Codex review did not complete — not an approval."

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

1. Do not interpret an incomplete result as approval, and do not interpret it as findings — `verdict-normalize` returns `incomplete` for exactly this case, and only `approved` exits the gate.
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
   - The authoritative signals everywhere are `.job.status` (`queued`/`running` = not done; `completed`/`failed`/`cancelled` = terminal) for job lifecycle, and the captured result file + `verdict-normalize` for the review outcome. The raw review text for reading findings remains at `.storedJob.result.rawOutput` or `.storedJob.result.codex.stdout`. Do not hand-roll a `sleep`-then-re-query loop; `status <job-id> --wait --json` is the condition-based primitive (2 s interval, 240 s deadline) and returns as soon as Codex is done. A wait cycle is not a review round — it does not consume the §5 convergence/backstop budget.
3. If still incomplete after the bounded recovery, hand back to the user as
   "Codex review did not complete (still running / aborted before verdict)" —
   never silently pass. Like every other gate failure this degrades to "no Codex
   review," not "Codex approved."
   Before continuing past an unrecovered incomplete, record it durably (code
   gates with the range; document gates without):

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class incomplete-review --gate <spec|plan|task|final|adhoc> [--base <BASE sha> --head "$(git rev-parse HEAD)"] --status incomplete --gate-dir "$GATE_DIR" --note "review did not complete"
   ```

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

> **Red Flag — Never** launch `adversarial-review` without a passing `base-ref-ok`
> on the exact base you pass. A bad base does not fail fast — it orphans the
> review as `running` forever with no verdict.

> **Red Flag — Never** derive approval yourself from raw companion output:
> only a `verdict-normalize` result of `approved` counts as approval. If the
> script says `incomplete`, there is no verdict, no matter how finished the
> raw text looks.

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

Ledger entry formats (one entry per assessed choice, so the round-2+ lock line
always has explicit referents):
- `Algorithm locked: <new> (was <old>) — <rationale>`
- `Algorithm locked: <original> — Codex suggested <alt>, declined: <reason>`
- `Algorithm locked: <choice> — assessed appropriate, no alternative suggested`

On plan-gate re-reviews, append this line to the round-aware preamble and omit
the Algorithm Assessment section from the prompt:

> Algorithm choices are locked per the ledger; do not re-open them absent
> a new blocking (Critical or High) defect in the locked choice — correctness,
> feasibility, or fit at the stated constraints and scale. Advisory preference
> or optimization alternatives remain locked.

### The loop

The loop's exit rule is mechanical: a round converges only when
`verdict-normalize` returns `"result":"approved"` for that round's captured
output. `blocking` continues the fix loop; `incomplete` follows §4b recovery
and never converges the loop by itself.

0. Before composing ANY LOGICAL round (round 1 included), advance the
   mechanical counter ONCE with this gate's ceiling from the backstop
   table — a round-1 lens batch is one logical round: one `gate-round`
   call covers composing and launching every lens prompt in the batch:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/gate-round" "$GATE_DIR" --ceiling <4 for document gates, 3 for code gates> --gate <spec|plan|task|final|adhoc>
   ```

   `"verdict":"proceed"` composes the round. `"verdict":"backstop"` means the ceiling is already spent: do NOT invoke Codex again for this gate — follow the backstop stop-condition below. A non-zero `gate-round` exit is an internal failure: treat it as `backstop` — do not invoke Codex for this round, and if backstop-round fixes ship, use the full append command written in the Backstop-hit stop-condition below (no `reminder` JSON exists on this path).
1. The approval set is every capture required for the latest round: round 1's set is every lens capture; a re-review round's set is its single capture. An empty capture set never approves. The round converges only when EVERY capture in the set normalized `"result":"approved"`, this round raised no blocking findings, and the round ledger has no still-open blocking findings. If converged → done; go to step 6.
2. Otherwise address each blocking finding: for a document, edit the spec/plan; for
   code, dispatch a fix through the skill's existing fix path (e.g. SDD's fix
   subagent). You MAY decline a finding with explicit reasoning instead of fixing it.
   Record resolutions, declines, and still-open items in the round ledger.
   After any code fix, re-run the same Claude reviewer gate before re-running Codex.
3. Re-run the same Codex invocation (with the round-aware preamble and ledger
   path) over the updated artifact once the relevant Claude review gate is clean.
4. **Stop when any holds:**
   - **Approved (converged):** EVERY capture required for the latest round normalized `"result":"approved"`, this round raised no blocking findings, **and** the round ledger has no still-open blocking findings. A round that normalizes to `approved` while the ledger shows an unresolved blocker has not converged (the blocker may predate this round); a round that normalizes to `blocking` has not converged regardless of ledger state — do not exit without a normalized approval.
   - **Backstop hit** — the per-gate round ceiling below is reached. Stop and hand back with any unresolved blocking findings listed; do not loop indefinitely. Fixes applied in the backstop round ship without a confirming Codex pass — flag them in the §6 hand-back as verified by the Claude reviewer and tests only, not re-reviewed by Codex. When backstop-round fixes ship, also record them durably using the `reminder` template from `gate-round`'s backstop output: `bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class backstop-fix --gate <task|final|adhoc> --base <task BASE sha> --head <head sha> --gate-dir "$GATE_DIR" --note "<one line>"` — and name the returned event id in the §6 hand-back.
If any stop condition conflicts with the mechanical exit rule, the mechanical rule governs: no normalized approved, no converged exit.

### Per-gate round backstops

| Gate | Recipe | Backstop |
|------|--------|----------|
| Spec / Plan (document gates) | task | 4 |
| Per-task / final / code-review (code gates) | adversarial-review | 3 |

Document gates get 4 rounds (cheap: a text edit + a `task` re-run). Code gates
get 3 rounds (expensive: fix subagent + Claude-reviewer re-run + a fresh
`adversarial-review` per round). Convergence usually stops the loop earlier; the
backstop is a true backstop, not the common exit.

> **Red Flag — Never** invoke the companion for a review round without a `proceed` from `gate-round`
> for this `GATE_DIR`. The agent's own round count is not authoritative — the counter file is; a
> backstop verdict means the ceiling is spent no matter what your recollection says.

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
  preflight) and the Codex model and reasoning effort the reviews ran with — read
  `model` and `model_reasoning_effort` from
  `${CODEX_HOME:-$HOME/.codex}/config.toml`; the companion runs reviews at
  these config defaults.

Then continue the skill (present to user / mark complete / finish branch).

## 7. Review sweep (clearing the ungated backlog)

Runs only on explicit consent from your human partner — never launch a
sweep because the notice appeared. When they consent (any phrasing of "run
the review sweep"):

1. **Anchor to the source repo before anything else.** Repo keys derive
   from the absolute git-dir, and a linked worktree has a DIFFERENT
   git-dir, so nothing key-derived may run cwd-based from inside a
   worktree:

```bash
SWEEP_REPO="$(git rev-parse --show-toplevel)"
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" pending "$SWEEP_REPO"
```

   Pass `"$SWEEP_REPO"` explicitly to EVERY `ungated-ledger` call in this
   section — `pending`, and every `mark-swept`, including `unsweepable`
   closures.

2. **Per pending event, resolve the recorded head first:**
   `git rev-parse --verify <head>^{commit}` — unresolvable (rebased,
   pruned) → close it without launching anything:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" mark-swept --ref <id> --verdict unsweepable --note "recorded head no longer resolves" "$SWEEP_REPO"
```

3. **Establish the review checkout, THEN validate the base against it** —
   `base-ref-ok` judges merge-base and empty-range against the checkout's
   own HEAD, so it must run where HEAD is the recorded head:
   - Current `HEAD` equals the recorded head → `base-ref-ok <base>` in
     place; on ok, route by the event's recorded gate type and run the appropriate §3 recipe with
     `--base <base>` from here.
   - Otherwise → throwaway detached worktree:

```bash
SWEEP_WT="$(mktemp -d "${TMPDIR:-/tmp}/sweep-wt.XXXXXX")" && git worktree add --detach "$SWEEP_WT" <head>
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/base-ref-ok" <base> "$SWEEP_WT"
```

     On ok, route by the event's recorded gate type and run the appropriate §3 recipe from `"$SWEEP_WT"` with the same `--base`.
     Afterwards — success, failed validation, or failed review alike:
     `git worktree remove --force "$SWEEP_WT"; git worktree prune`.
   Route by the event's recorded gate type: `task` events run §3's per-task code recipe; `adhoc` events run §3's code-review-requests recipe; `final` events run §3's final whole-branch recipe with its full inputs (branch review package over the recorded range, plan or requirements path, and the Minor findings ledger if one exists). When an event's original inputs are gone (scratch GC'd, brief paths stale), do not skip the sweep: run the range through §3's code-review-requests recipe with a focus string quoting the event's gate, class, status, and note — a correctness review of the recorded range never depends on the original briefs.
   The review is always of exactly the recorded `base..head`, never `base..current-HEAD`.
   A failed `base-ref-ok` closes the event `unsweepable` with the checker's
   reason (same `mark-swept` shape as step 2).

4. **Normal loop, normal authority.** Each pending event gets a FRESH `GATE_DIR` — create it from the source repo at the start of that event's review:

```bash
GATE_DIR="$(bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/codex-review-dir")"
```

   (Run from `"$SWEEP_REPO"` — the `codex-review-dir` helper captures it internally.)

   The sweep review runs the §5 loop with THIS EVENT's `GATE_DIR` and `gate-round` at the code-gate ceiling — a shared sweep-wide dir would let the first event's rounds spend the ceiling for every later event. `verdict-normalize` is the only approval authority. Close the event with the loop's outcome:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" mark-swept --ref <id> --verdict <approved|blocking|incomplete> --note "<one line>" "$SWEEP_REPO"
```

   Blocking findings from a sweep are surfaced to your human partner like
   any review findings; fixing them is ordinary follow-up work they direct.

5. **Hand back** per §6, listing each event id → verdict, plus anything
   closed `unsweepable` and why.

Document-gate events are recorded `sweepable:false` and never appear in
`pending` — by sweep time the artifact has evolved or shipped, and its
content is covered by the code gates that followed. They exist for
telemetry.

> **Red Flag — Never** run a sweep review without consent, and never close an event under a
> worktree's own key: every `ungated-ledger` call in a sweep carries `"$SWEEP_REPO"` explicitly.
