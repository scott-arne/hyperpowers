# The board infers a permission prompt; it does not record one

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-27-parallel-development-design.md (decision 5)
- Recorded: 2026-11-07; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-27-parallel-development.md removed at finish

## Decision

The board infers a permission prompt; it does not record one. A prompt
blocks the very tool call a session would use to post, so the board marks
a session that holds a claim with no activity for thirty minutes `quiet`
and names no cause; the clarifying answer that listed a permission among
the waiting kinds is superseded by this, approved with design section 4,
and a hook that records a pending tool call is the follow-up that would
name one. Decided 2026-10-27 in chat.

## What implementation changed

`board` marks a session that holds a claim and has shown no activity for thirty minutes as `quiet`, and it names no cause. Nothing records a pending permission prompt. No hook was added.
