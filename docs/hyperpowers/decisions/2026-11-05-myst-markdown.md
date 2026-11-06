# MyST Markdown

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md (decision 3)
- Recorded: 2026-11-05; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-05-readthedocs-site.md removed at finish

## Decision

**MyST Markdown.** Matches the rest of the repository and the theme's own
docs. Rejected: reStructuredText, a second format for every contributor.

## What implementation changed

Implemented as written. Every page under `docs/site/` is MyST Markdown, and `conf.py` loads `myst_parser`.
