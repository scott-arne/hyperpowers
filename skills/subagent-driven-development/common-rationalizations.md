## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Close enough on spec compliance" | Reviewer found spec gaps = not done. Fix it, or hit the cap and hand it back — those are the only exits. |
| "I'll fix it myself, dispatching is overhead" | Controller fixes pollute your context and skip review. Outside the de-minimis exception (one finding: at most 3 fully-specified lines in one file, no new logic — and it still costs a fix round, still runs the covering command with the fix report appended, disclosed in the ledger, re-review still runs), that is rationalization. Resume the implementer at rounds 1-3; dispatch the takeover at rounds 4-5. |
| "One more round will converge" | Past the cap, rounds don't converge — the failure is structural. It goes to your human partner as BLOCKED. |
| "The reviewer will just find something new anyway" | Scoped re-reviews verify fixes; they cannot wander. New findings on untouched code go to the ledger, not the loop. |
| "This finding is obviously wrong, I'll drop it" | A finding you disagree with goes to your human partner with the plan text beside it. Silent discards are forbidden. |
| "The fix was small, skip the re-review" | Unreviewed fixes are how regressions land. Every round ends with a scoped re-review. |
| "Reviews slow the loop down" | The loop without reviews is just unverified churn. Reviews are the loop's brakes and steering. |
| "Ledger bookkeeping is overhead" | The ledger is what survives compaction. Controllers without one have re-dispatched entire completed task sequences. |
| "The implementer spawned its own reviewer — free extra assurance" | It's a duplicate seat reviewing the same diff; the task review is the gate. A worker-spawned reviewer is a defect to flag, not rigor. |
| "The Codex gate gets its own rounds" | One task, one five-round cap. Gate rounds are fix-loop rounds, and the scoped re-review — not a task-reviewer re-run — precedes each one. |
| "Codex is still verifying, that's basically a pass" | Treat an unfinished or "still verifying" Codex result as approval and the gate never happened. Incomplete is not a pass: recover via `status`/`result`, or surface it. |
| "Batching these small tasks lets the gate go" | A batch's tier is the MAX of its members' declared tiers. Batching never manufactures a gate skip. |
| "I'll keep the workspace for reference" | The repo's commits are the record. Delete it — an undeleted clean-finish workspace becomes a stale-forensics trap for the next plan. |
