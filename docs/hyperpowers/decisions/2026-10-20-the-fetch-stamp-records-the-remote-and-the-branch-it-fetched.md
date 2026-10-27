# The fetch stamp records the remote and the branch it fetched

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md (decision 5)
- Recorded: 2026-10-27; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-23-portable-sdd-dossiers-follow-ups.md removed at finish

## Decision

The fetch stamp records the remote and the branch it fetched. Creation of
an orphan branch requires an exact match of remote, branch and a
fingerprint of the remote's fetch URL, so a changed
`hyperpowers.stateRemote` or `hyperpowers.stateBranch`, or a repointed
remote, means a fresh `sync` before any branch is invented; the per-key
boolean the spec first described would have let a stale stamp vouch for a
remote it never checked. Decided 2026-10-23 at the hand-back.

## What implementation changed

The stamp file, previously empty and tested for existence only, now carries remote, branch and a fingerprint of the remote's fetch URL. The library's hp_remote_fingerprint computes the digest with node over the whole of stdin and fails closed when none is available, and hp_stamp_ok requires an exact match of all three before hp_ensure_checkout may create an orphan branch; a mismatch yields a needs-sync status naming the stale stamp. In sdd-state, sync reads the remote's URL once as written (the first value of a multi-URL remote, the one git fetches from), derives its once-rewritten form by expanding the environment-configured alias, and pins the fetch to a one-time hp-pin name the environment maps to that endpoint, so a chained or late-added rewrite rule cannot move it; it refuses a remote section that shadows the pin and an old git, keeps the caller's environment configuration, and writes no stamp when there is no remote or the fetch fails. The fetch lands in a private per-process ref under refs/hp-fetch, which is published to the remote-tracking ref by compare-and-swap, and a repository's first local state branch is created from the fetched tip, not from the shared ref a racing fetch may have moved. The stamp governs creation only; an existing state branch is continued and reconciled.
