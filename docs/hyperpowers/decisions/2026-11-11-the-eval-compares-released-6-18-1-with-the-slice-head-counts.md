# The eval compares released 6.18.1 with the slice head, counts a thrash or a run with no dispatch as a failure, and reuses the 2026-11-12 baseline as its control

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 10)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**The eval compares released 6.18.1 with the slice head, counts a
thrash or a run with no dispatch as a failure, and reuses the 2026-11-12
baseline as its control.** This replaces decision 5. The baseline ran
the v6.18.1 tree on the same scenario, Claude Code version and model;
it stands as the control once its harness paths are shown identical to
the pin, and otherwise the control is run again. Rejected: the
stripped-paragraph control, which finished 10 of 10 by never re-reading
and does not stand for the release users run; voiding runs with no
dispatch, which hid all 20 failing runs on 2026-11-12; a shipped arm
beside the treatment, since the treatment now is the shipped
configuration.

## What implementation changed

Applied in the evals repository and recorded in the eval evidence note, not in this tree. `tests/sdd/test-compaction-reread.sh` was adjusted for the controller.
