# The ledger stays authoritative; helpers write the machine records

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 4)
- Recorded: 2026-11-06; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**The ledger stays authoritative; helpers write the machine records.**
The Codex approach gate (2026-10-23, one shot, blind context) converged
on this shape. Its event-sourced projection (a per-session journal
reduced to a state file the hook reads with no discovery) is deferred:
cleaner on the stop path, but a second store to keep consistent with the
ledger, and ten runs cannot pay for it. Its obligations-and-permits
protocol is the declined fail-closed posture; two of its parts survive:
the one-shot hand-back line as the escape hatch, and a completion
receipt written outside the workspace before Finish removes it.

## What implementation changed

`sdd-state complete` and `sdd-state handback` (`cmd_complete`, `cmd_handback`) append under the workspace lock through `hp_ledger_append` in `sdd-common.sh`, which terminates a partial line with a `#fragment` marker and verifies its own tail, and every completion reader (`ledger_records` behind the completion marks and `verify`, the hook's `ledgerRecords`) skips fragments; `handback` refuses a reason carrying a completion mark and a session id that is not one token. `scripts/tracked-job` writes its allocation and terminal job lines itself, and a terminal line carries `jobdir=<path>` so the writer appends it once by checking the ledger under the lock rather than a marker file in the job directory (plan deviation 3). `sdd-state finish` builds the receipt in two phases (`stage_receipt` under a `.staging-` name, renamed at the end, marked `FINISHED` when the final rename fails, which `discover` accepts as a receipt), copies `stop-guard.jsonl` and the jobs' `meta.json` and `exit`, and prints `receipt=<path>`; `snapshot` commits the same records and leaves `out.log` and other job scratch out. Since `64ad574`, `finish` refuses with `status=live-jobs` (exit 13, not bypassed by `--force`) through `live_jobs` while a job is `running` or `lost-unswept` without an `exit` file or has an unreadable record, and `tracked-job new` rejects a name starting with a dot, which `liveJobs` and the receipt glob skip. The event-sourced projection was not built.
