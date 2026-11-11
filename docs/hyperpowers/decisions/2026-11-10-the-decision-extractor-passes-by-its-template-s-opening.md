# The decision extractor passes by its template's opening sentence

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 5)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**The decision extractor passes by its template's opening sentence.** The
extractor is the one background dispatch SDD makes on purpose. Its prompt,
composed from `skills/finishing-a-development-branch/decision-notes-prompt.md`,
opens with "You write implementation notes for a list of design
decisions"; a background `Agent` call whose prompt contains that sentence
passes, and a contract check keeps the sentence in the template.
Rejected: matching the `description` (free text the controller writes);
reading the ledger's `Decision extractor:` line (written after the
dispatch).

## What implementation changed

Implemented as specified. `screen` passes a background `Agent` call whose prompt contains `EXTRACTOR_SENTENCE` and logs it as `extractor`. `tests/sdd/test-sdd-contract.sh` asserts the sentence is in `decision-notes-prompt.md`.
