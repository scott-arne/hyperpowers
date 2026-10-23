# Records are extracted at finish only, and the spec's Decisions section is required

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 2)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**Records are extracted at finish only, and the spec's Decisions section
is required.** Nothing new is written at design time. The spec already
carries the decisions in a numbered or bulleted list in 16 of this
repository's 24 specs; the rule makes that section mandatory and uniform.
Drafting records at spec time was rejected because abandoned and reworked
specs would leave records to retire; collecting decision notes from every
task report was rejected because it adds a line to every report for what
the final diff and the plan's corrections already carry.

## What implementation changed

The compiler refuses a spec with no decisions list (exit 2) before any write, and the Decisions section is located by the first level-two heading containing "decision". The brainstorming and writing-plans skills now require the `## Decisions` list, and the plan header template carries the correction phrase. Extraction runs only in finishing Step 1 and Step 4, and nothing is written at design time. Legacy prose-only specs are refused, and the evidence note records the real-spec dry run with a split of 15 exit 0 and 10 exit 2.
