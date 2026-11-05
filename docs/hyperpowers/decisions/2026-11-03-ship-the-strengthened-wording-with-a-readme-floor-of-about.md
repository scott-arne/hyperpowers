# Ship the strengthened wording with a README floor of about 200K for

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md (decision 10)
- Recorded: 2026-11-04; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md removed at finish

## Decision

Ship the strengthened wording with a README floor of about 200K for
autoCompactWindow, recording the SDD outcome of 9 of 10 (one compaction and
re-read loop at the eval's forced 100K window) as a tiny-window artifact
(human partner, 2026-11-04).

## What implementation changed

The README tells readers not to set the window below about 200K, because skills re-read after each compaction and a very small window can loop. The CHANGELOG records SDD at 9 of 10 against the control's 10 of 10, with the one loop run (13 compactions) called a tiny-window artifact, and it also records that treatment compacted 151 times against 38 at the forced window. The 400K field re-measure remains to be done.
