# The site lives in `docs/site/`

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md (decision 4)
- Recorded: 2026-11-05; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-05-readthedocs-site.md removed at finish

## Decision

**The site lives in `docs/site/`.** Keeps it apart from the specs, records,
and evidence notes in `docs/hyperpowers/`, and outside the plugin install.

## What implementation changed

Implemented as written. The site is under `docs/site/` (`conf.py`, `requirements.txt`, `skills/`, `advanced/`), with `.readthedocs.yaml` at the repository root and `docs/site/_build/` added to `.gitignore`. The drift check does not watch `docs/hyperpowers/` records, so pages avoid claims about what the records contain.
