# Hand-written pages with drift checks

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md (decision 1)
- Recorded: 2026-11-05; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-05-readthedocs-site.md removed at finish

## Decision

**Hand-written pages with drift checks.** Every page is authored MyST; an
offline test fails on a missing or orphan skill page, an unlisted page, a
skill page missing a template section, or a page whose declared sources
(the whole skill directory, plus anything else it describes) no longer
match its recorded digest. A digest of `SKILL.md` alone was rejected in
the spec review: supporting files and scripts change behavior too.
Rejected: generating
each skill's facts from `SKILL.md` with written companion pages, because
sixteen skills do not justify a parser and the generated text would be
agent-facing; release-pinned snapshots behind a release check, because
there is no CI and releases are tagged by hand. Taken from the snapshot
approach: the default Read the Docs version becomes `stable` once a
release contains the site.

## What implementation changed

Implemented as written. `tests/docs/docs-check.sh` checks for missing or orphan skill pages, pages absent from the index, skill pages missing a template section, and a page whose `sources:` digest differs from its recorded `source-digest:`; `--digest <page>` prints the new value. `tests/docs/test-docs-check.sh` and `tests/docs/test-docs-skills.sh` cover it. The project CLAUDE.md gained the rule that a change to a listed source re-reads its page and updates the digest. Sources are whole skill directories plus other files each page describes. The default Read the Docs version becoming `stable` waits on a release that contains the site and is not part of this branch.
