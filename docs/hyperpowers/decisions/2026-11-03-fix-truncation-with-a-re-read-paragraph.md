# Fix truncation with a re-read paragraph

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md (decision 4)
- Recorded: 2026-11-04; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md removed at finish

## Decision

Fix truncation with a re-read paragraph, not by restructuring skills under
20,000 characters; restructuring rewrites tuned content and is not needed
for the read to happen.

## What implementation changed

The skills were not restructured. The `subagent-driven-development` and `brainstorming` SKILL.md files each gained one "After every context compaction" paragraph telling the agent to Read the full skill file again. A new offline suite, tests/sdd/test-compaction-reread.sh, checks the paragraphs, and docs/testing.md lists it. The eval tally and the per-compaction measurement live in the evals repository, with the results in the dated eval-evidence note.
