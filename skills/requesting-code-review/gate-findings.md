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

