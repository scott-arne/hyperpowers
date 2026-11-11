# The skill-text edits are evaluated by contract needles and a reachability note

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 13)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**The skill-text edits are evaluated by contract needles and a
reachability note.** Rejected: a new later-session scenario run live
against main and the branch; writing-skills pressure tests for every edit.
Four of the edits make the text match what the scripts already enforce,
and a misreading meets a script refusal.

## What implementation changed

No change. The contract needles are in `tests/sdd/test-sdd-contract.sh`, the contradicted phrases are asserted absent, and `docs/hyperpowers/2026-11-08-sweep-fixes-skill-text-reachability.md` records each edit with its file, line and needle and the sentinel scenarios read against evals commit `8dbdc61c3`. It states that no live runs were made. A later correction extended the same pattern to `example-workflow.md`.
