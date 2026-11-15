# The eval strips the paragraph from both arms and adds a shipped-config arm and a no-skill sentinel

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 5)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish

## Decision

**The eval strips the paragraph from both arms and adds a shipped-config
arm and a no-skill sentinel.** Control is the branch with the paragraph
removed from SDD and brainstorming; treatment is the same plus the
notice. A treatment-only arm runs the shipped configuration, and a new
scenario checks that a session following no skill does not start reading
skills. Rejected: replacing the plugin's files under a running eval
session to make its loaded text genuinely stale, because the quorum
harness pins one commit per arm and the measured behavior is whether the
Read happens, which the stripped control exercises; running the
brainstorming compaction scenario as well, because the notice is generic
and the SDD scenario measures it at lower cost. Replaced by decision 10.

## What implementation changed

Replaced by decision 10. The stripped-paragraph control and the no-skill sentinel were not what shipped; the eval work lives in the evals repository and the eval evidence note.
