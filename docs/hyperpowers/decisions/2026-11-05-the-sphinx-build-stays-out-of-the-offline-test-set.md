# The Sphinx build stays out of the offline test set

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md (decision 9)
- Recorded: 2026-11-05; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-05-readthedocs-site.md removed at finish

## Decision

**The Sphinx build stays out of the offline test set.** It downloads
packages on first run; Read the Docs enforces `fail_on_warning` once the
project is live, and the local command is documented.

## What implementation changed

Implemented as written. `tests/run-offline.sh` and `docs/testing.md` add the `tests/docs/test-*.sh` suites and the page checks. The Sphinx build is not in the offline set. `docs/testing.md` documents the local `sphinx-build -W --keep-going` and linkcheck commands, and `.readthedocs.yaml` sets `fail_on_warning: true` with Python 3.13.
