# Recommended settings cover three Claude Code tips

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md (decision 7)
- Recorded: 2026-11-05; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-05-readthedocs-site.md removed at finish

## Decision

**Recommended settings cover three Claude Code tips** (400K auto-compact
window with a 200K floor, one-hour caching, `/clear` before execution).
Model choice, model aliases, Codex gate overhead, and idle compaction are
left out as setup-specific or unmeasured as general tips. The quality
claim names the two skills that re-read after compaction, the measured
re-read rates at a 100K window, that 400K itself was not measured, and
that writing-skills lacks the instruction (spec review correction of the
"every compaction" wording approved in chat).

## What implementation changed

Implemented as written. `docs/site/recommended-settings.md` covers the 400K auto-compact window with its 200K floor, one-hour caching and `/clear` before execution. It leaves out model choice, aliases, Codex gate overhead and idle compaction.
