# Source links follow the built version

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md (decision 8)
- Recorded: 2026-11-05; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-05-readthedocs-site.md removed at finish

## Decision

**Source links follow the built version.** `{source}` links and the edit
link use Read the Docs' git identifier, falling back to `main`, so a
`stable` page links to the tag it documents. Rejected: hard-coded `main`
links, which would show a tagged page's readers newer source.

## What implementation changed

Implemented with one gap. `conf.py` builds `SOURCE_REF` from `READTHEDOCS_GIT_IDENTIFIER`, falling back to `main`, and uses it for the `{source}` extlink and the theme's `source_branch`. On pull-request builds the identifier is the PR number, so those links would 404. The ledger defers this and suggests `READTHEDOCS_VERSION_TYPE=external` with the commit hash.
