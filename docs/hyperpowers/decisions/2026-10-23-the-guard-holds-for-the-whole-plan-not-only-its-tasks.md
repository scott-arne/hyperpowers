# The guard holds for the whole plan, not only its tasks

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (decision 5)
- Recorded: 2026-11-06; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md removed at finish

## Decision

**The guard holds for the whole plan, not only its tasks.** "Unfinished"
means the ledger exists: `sdd-state finish` removes it, and until then
the final review, the Codex final gate and the merge are still owed. The
refusal message says which state the plan is in (tasks open, or all
tasks complete with the final review and Finish remaining).

## What implementation changed

`planState` reads open and total from the plan's `### Task N:` headings and the ledger's completion marks, but `decideStop` refuses whenever exactly one ledger matches and nothing allows, so a plan with every task complete is refused until `sdd-state finish` removes the ledger, with the state `all N tasks complete; the final review and Finish remain` (test "all tasks complete with the ledger present: block, the final-review state"). The `live-shell` refusal departs from the spec's first sentence: `liveShellMessage` names the live jobs in place of "nothing tracked is live" and tells the controller to report a `lost-unswept` job with its pgid. SKILL.md says that completing the last task opens the final whole-branch review and that the plan ends only after Finish. After Finish the hook answers `no-ledger`, logged to the mirror when a receipt carries the session; in the Z4 contingency campaign the one `neither` stop was a report made after Finish had removed the ledger, which the guard answered `no-ledger`, and the human partner kept H2 as written (2026-11-05).
