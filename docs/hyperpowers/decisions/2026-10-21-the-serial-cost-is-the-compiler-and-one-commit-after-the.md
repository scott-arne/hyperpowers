# The serial cost is the compiler and one commit, after the suite; the human review rides the finishing menu

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 12)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**The serial cost is the compiler and one commit, after the suite; the
human review rides the finishing menu.** Compilation cannot run inside
a wait because it must follow a passing full suite (Decision 10), so the
compiler (well under a second) and the pathspec commit (a few seconds)
run in series between the suite and the options menu. The human partner
reviews the complete staged diff and rules on the extractor's proposals
in the same message that presents the finishing options, an interaction
that exists today, so no message is added to the cycle; the commit
follows their answer and precedes the option they chose, so the records
ride the branch before any merge or push and the repository's rule that
the complete diff is approved before a commit is kept. Only when a
disposition changed the staged set is the new staged diff shown once
more before the commit. The human partner accepted the serial cost on
2026-10-21 when asked during the spec gate, in these words: "Accept:
seconds after the suite are fine".

## What implementation changed

The compiler plus one records commit run in series after the suite, as written. Correction 2026-10-22 withdrew an intermediate second commit for an accepted proposal, so the proposal, the Outcome line and the records land in the single commit. The human partner's approval of the complete staged diff and the proposal dispositions rides the Step 4 menu message, and an answer that leaves a proposal without a disposition is incomplete and asks again. A withheld approval commits nothing.
