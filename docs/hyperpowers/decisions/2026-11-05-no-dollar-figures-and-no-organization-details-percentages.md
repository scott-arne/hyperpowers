# No dollar figures and no organization details; percentages allowed

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md (decision 5)
- Recorded: 2026-11-05; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-05-readthedocs-site.md removed at finish

## Decision

**No dollar figures and no organization details; percentages allowed.**
The human partner's rule (2026-11-05), enforced by the drift test over
`docs/site/`, a dollar-amount scan of every staged diff and commit
message, and a final review of every changed file and commit message for
organization details.

## What implementation changed

Implemented as written. `docs-check.sh` has an amount scan (`check_amounts`) over `docs/site/` that fails on dollar amounts and on amounts spelled as words. The staged-diff and commit-message scans and the organization review were process steps, not code.
