# Evidence bar: offline tests, a parser dry run over real specs, and the first live SDD run

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 11)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**Evidence bar: offline tests, a parser dry run over real specs, and the
first live SDD run.** This is a workflow addition, not a trigger-wording
change, so no quorum campaign is planned. The human partner may raise the
bar in the plan.

## What implementation changed

The evidence is the offline suites (compiler, docs-allowlist and SDD contract, plus packaging), the dry run over the real specs recorded in `2026-10-21-decision-records-eval-evidence.md`, and the live SDD runs under the evals repository (fast, fast2, slow-clean, stop, stop3). The runs found gaps that were fixed in the finishing and SDD skills: an incomplete-answer rule, verbatim diff output, an unattributed commit message and the ledger-line step. The note records the voided attempts. The bar was not raised, and the accepted-proposal path got a live rehearsal only after the final review owed one.
