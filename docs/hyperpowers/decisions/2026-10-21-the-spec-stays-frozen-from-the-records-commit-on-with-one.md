# The spec stays, frozen from the records commit on, with one Outcome line

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 4)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**The spec stays, frozen from the records commit on, with one Outcome
line.** While its branch is open the spec is a working document: its
Decisions list may be amended by the controller with the human partner's
approval, which is how a legacy prose section becomes a list, how a
Codex-gate fix that reverses a decision is recorded, and how an accepted
proposal (an undocumented decision, a supersession) enters it. The
records commit is the freeze: from then on the only line anyone edits is
the Outcome line the compiler owns, which states when the work was
implemented and how many records it produced. Supersession is tracked in
records only; old specs are not re-stated. Deleting specs with plans was
rejected because records would then have to carry every alternative and
constraint themselves.

## What implementation changed

The compiler writes the one Outcome line into the spec through `write_if_changed`, and a symlinked spec is refused. Finishing Step 1 requires a committed, clean spec. An accepted proposal is written into the spec, and the compiler is re-run so the spec edit and the Outcome line enter the one records commit together. Correction 2026-10-22 names this the one place the spec changes after the freeze. The brainstorming and writing-plans texts say the Decisions list is append-only once execution starts.
