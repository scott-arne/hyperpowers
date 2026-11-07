# Evidence is fixtures, one live run and one scenario

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 9)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

Evidence is fixtures, one live run and one scenario. Deterministic
two-session fixtures in the state suite for every mechanism, one real
two-terminal run on a small plan recorded in the evals repository, and
one hyperpowers-evals scenario with two cases for the skill-text
behaviour. Decided 2026-10-27 in chat.

## What implementation changed

The state suite `tests/sdd/test-sdd-state.sh` has deterministic two-session fixtures for each mechanism, and `test-sdd-contract.sh` pins the skill text. The two-terminal live run and the hyperpowers-evals scenario with two cases are Tasks 13 and 14 of the plan. The scenario's README states what its checks prove and do not prove. The final verdict also needs the grader's acceptance-criteria verdict, and your human partner chose to keep the checks and add that proof. The state suite's runtime reached about 20 minutes and is now run as a tracked job. The skill-text changes have no live behavioural eval beyond that scenario, which the ledger lists as a residual.
