# Base the release on `v6.16.1`, because `main` carries held, unmeasured work

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md (decision 1)
- Recorded: 2026-11-04; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md removed at finish

## Decision

Base the release on `v6.16.1`, because `main` carries held, unmeasured
work.

## What implementation changed

The release was built on tag v6.16.1 and tagged v6.16.2, and the version strings in the plugin manifests and package.json were bumped there. Main's held work is not in the tag range; main received the release by a later merge.
