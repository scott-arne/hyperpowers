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
