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
3. **Watch in the foreground — never idle.** Block on one shell call (timeout 600000 ms) that watches every job id at once:
   `bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/gate-wait" <job-id>...` with `CODEX_PATH` exported;
   it re-reads every job without blocking, waits on one at a time in slices of at most 30 s, and returns when all are terminal (exit 0, last line `all-terminal`) or after its 480 s budget (exit 2, last line `running: <ids>`).
   On exit 2, immediately issue the next `gate-wait` over the ids still running. On exit 1 from a usage error, fix the call and re-run; on exit 1 for a job it could not read (last line `unreadable: <ids>`, stderr names the cause), run the §4b code-gate recovery for that job only and keep watching the ids still running with `gate-wait`.
   Never call `status <job-id> --wait` yourself; it is the primitive `gate-wait` runs for you.
   While the review runs, the session must always be inside one of these
   blocking watch calls — never `sleep`, never fire-and-forget and move on.
   This keeps the session visibly working in harness UIs and the wait
   interruptible, while the review itself is immune to any single call being
   killed.
4. **Read the verdict.** Once `.job.status` is terminal, run `node "$CODEX_PATH/scripts/codex-companion.mjs" result <job-id> --json`: write the full `result <job-id> --json` output to a file inside `GATE_DIR` and run `verdict-normalize` on it; the raw review text for reading findings remains at `.storedJob.result.rawOutput`.

Cap the watch at **2 consecutive `gate-wait` calls** (~16 minutes). If the job is
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
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Task-scoped review. Requirements: <TASK_BRIEF_PATH>. Implementer report: <IMPLEMENTER_REPORT_PATH>. Review package: <REVIEW_PACKAGE_PATH>. Global constraints: <GLOBAL_CONSTRAINTS_PATH>. Review for task compliance and code quality. Severity is scoped to what this diff causes: critical or high means a defect the change introduces — in its changed lines, in an unchanged caller it breaks, or in a requirement it was asked to meet and omits — that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

`<BASE_SHA>` is the recorded task base from before the implementer was
dispatched. Apart from the severity calibration, the focus text stays short because the task brief, implementer
report, review package, and global constraints carry the real context.

**Tier applicability (SDD tasks only).** Per-task code gates run for
standard- and high-tier tasks. An SDD task whose EFFECTIVE tier is low —
declared at plan time, reviewed by the plan gate, never lowered at
dispatch, with no escalation trigger fired — skips this gate entirely:
record the skip with `bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class tier-skip --gate task --base <TASK_BASE> --head <HEAD> --tier-declared low --tier-effective low --note "Task N: <rationale>"` and move on; the Claude task reviewer and the final whole-branch gates never tier off. Ad-hoc code-review requests have no tier and always run.
Within SDD's per-task loop, gate rounds count against the task's shared five-round fix cap; the scoped re-review (not a full task-reviewer re-run) precedes each Codex re-round.

**Final whole-branch code** — use `adversarial-review` over the branch range and
point Codex at the final-review inputs:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <MERGE_BASE_SHA> --json "Final whole-branch review. Branch review package: <BRANCH_REVIEW_PACKAGE_PATH>. Plan or requirements: <PLAN_OR_REQUIREMENTS_PATH>. Minor findings ledger, if present: <MINOR_LEDGER_PATH>. Tier-skip summary, if any: <TIER_SKIPS_PATH>. Review for correctness, requirements coverage, integration risk, and code quality. Severity is scoped to what this diff causes: critical or high means a defect the change introduces — in its changed lines, in an unchanged caller it breaks, or in a requirement it was asked to meet and omits — that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```

When any task skipped its per-task gate, pass the tier-skip summary file as <TIER_SKIPS_PATH> AND include it among the final dossier's --adjudications inputs, so both the prompt and the delivered dossier carry it.

**Code-review requests** — use `adversarial-review` over the same range the
Claude reviewer used. If the requirements are a file, pass the file path; if
they are short text, include that text in the focus string.

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" adversarial-review --base <BASE_SHA> --json "Code review. Requirements or review context: <PLAN_OR_REQUIREMENTS_CONTEXT>. Review for correctness, requirements alignment, integration risk, and code quality. Severity is scoped to what this diff causes: critical or high means a defect the change introduces — in its changed lines, in an unchanged caller it breaks, or in a requirement it was asked to meet and omits — that yields a wrong result, a crash, data loss, or a reachable security hole. An untested path is medium unless the requirements named that test as a deliverable. Naming, style, and speculative hardening are low. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything."
```
