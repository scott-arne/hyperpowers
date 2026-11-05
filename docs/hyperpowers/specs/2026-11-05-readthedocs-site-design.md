# Read the Docs site for hyperpowers

**Date:** 2026-11-05
**Status:** design approved in chat on 2026-11-05, section by section
(structure, skill page template, recommended settings, build and hosting,
drift checks); approach chosen after a Codex approach consultation (run
`~/.cache/hyperpowers/codex-review/193a951fd4f675975a919be372c5015a95aa0491/run-HTceShu7/`).
Spec self-reviewed; Codex spec review round 1 raised six blocking findings
across two lenses, all confirmed and fixed (the "every compaction" quality
wording approved in chat was narrowed to the measured evidence); round 2
raised one more (self-referencing root toctree), fixed; round 3 approved
(ledger in
`~/.cache/hyperpowers/codex-review/193a951fd4f675975a919be372c5015a95aa0491/run-7ROppBwL/`).
**Branch:** chosen at execution time through using-git-worktrees.

## Problem

Hyperpowers has no documentation written for the person deciding whether to
use it or trying to understand what a session is doing. The README covers
installation and lists the skills in one line each. Each `SKILL.md` is
written for the agent: imperative instructions, Red Flags tables,
rationalization lists. A reader who wants to know what a skill does for
them, why it exists, and what it costs has to infer that from text that was
never meant for them.

The human partner asked for a Read the Docs site, using the Lumina theme,
that explains what each skill does and why, with its pros and cons, plus
advanced pages on how the machinery works and a recommended-settings page
that presents the cost-saving settings as tips that keep quality intact.

## Goals

- A Sphinx site under `docs/site/`, MyST Markdown, theme
  `sphinx-lumina-theme`, that builds with no warnings.
- One page per skill (16 today) with the same sections, so skills can be
  compared, and honest cons on every page.
- Guide pages that explain the problem hyperpowers addresses, the workflow
  end to end, installation per harness, and one walkthrough session.
- Advanced pages on triggering, Codex gates, SDD internals, decision
  records, how skills are tested, and customizing skills.
- A recommended-settings page for Claude Code built from measured
  percentages, with no dollar figures and no detail about whose sessions
  were measured.
- An offline test that fails when the skill pages drift from the skills.
- A `.readthedocs.yaml` so the human partner can import the project and get
  a working build.

## Non-goals

- Trimming the README's "Cost and Context" section. That is a separate
  change after the site is live, so its link works on day one.
- Creating the Read the Docs project, pushing, or publishing. Those are the
  human partner's steps (see Publishing).
- Generating any page content from `SKILL.md` files. Rejected; see
  Decisions.
- Release-pinned snapshots or a release check. Rejected; see Decisions.
- Pagefind search, translations, custom styling beyond theme options, and
  documentation for tags older than the first release that contains the
  site.
- Any edit to skill content. No file under `skills/` changes.

## Global constraints

- No dollar figures anywhere: not in pages, tests, commit messages, or this
  spec. Percentages are allowed.
- No private information about the maintainer's organization in any
  committed file. The organization is not named. Recommended settings
  describe measured results without saying whose sessions they came from.
- Both content rules are checked over their whole scope: the drift test
  scans `docs/site/` for dollar amounts and the words for them (item 7 of
  Drift checks); before every commit, the staged diff and the commit
  message are scanned for amounts only (a `$` followed by a digit), because
  the spec, plan, and test legitimately name the rule; the final review
  reads every file the branch changes and every commit message for dollar
  amounts and organization details.
- Credit follows the README's attribution policy: the methodology and most
  skill design are upstream Superpowers' work by Jesse Vincent and Prime
  Radiant; Scott Johnson maintains the fork.
- Every claim about a skill's behavior is checked against that skill's
  `SKILL.md` and supporting files at the commit the page is written from.
  Reasons ("why") come from `docs/hyperpowers/specs/`,
  `docs/hyperpowers/decisions/`, and the README. Pages do not invent
  behavior, outputs, or numbers.
- Skill pages carry no eval numbers. The testing page explains the method
  without per-release numbers. Recommended settings may quote the
  percentages listed in this spec.
- Prose follows the communication skill: lead with the point, name the
  specific thing, no filler, no metaphors standing in for facts.
- Pages address the reader as "you". Skill vocabulary such as "your human
  partner" appears in quotes where a page explains it.
- Python tooling runs through `uv run` with an ephemeral environment.
  Nothing is installed into a shared or global environment.
- The pre-commit leak scan (`git diff --cached | python3
  ~/.claude/scripts/realval-scan.py`, expecting `hits: 0`) runs before
  every commit.

## Design

### Site structure

All sources live in `docs/site/`. The local plugin install is a sparse
checkout without `docs/`, so nothing here reaches agent sessions.

`index.md` is the root document (the home page: what hyperpowers is, the
problem it addresses, where to start). It holds four captioned toctrees,
one per group below, and never lists itself; a self-reference is a Sphinx
warning that `-W` turns into a failed build. `skills/index.md` is listed in
the Skills toctree and holds its own toctree of the skill pages.

| Group | Page | Content |
|---|---|---|
| Guide | `why.md` | How coding agents fail without process (code before design, tests after code, "done" without evidence), skills as behavior-shaping code, auto-triggering |
| Guide | `install.md` | Install summary per harness, linking the README for full commands; a support table for all ten harnesses |
| Guide | `first-session.md` | One session walked through from "Let's make a react todo list": brainstorming, plan, execution, finish. Marked as illustrative; no invented transcript output |
| Guide | `workflow.md` | The lifecycle as a Mermaid diagram; the spike, bounded, and architectural paths; which skill takes over at each step |
| Guide | `recommended-settings.md` | Cost tips (below) |
| Skills | `skills/index.md` | Table of all skills: purpose, when it triggers, category |
| Skills | `skills/<name>.md` | One page per skill (template below) |
| Advanced | `advanced/triggering.md` | Session-start bootstrap, skill descriptions, skill priority rules |
| Advanced | `advanced/codex-gates.md` | Optional Codex reviews of specs, plans, and code; how skills behave without Codex |
| Advanced | `advanced/sdd-internals.md` | SDD workspace, ledger, state branch, re-read after compaction |
| Advanced | `advanced/decision-records.md` | Spec decisions compiled into records at branch finish |
| Advanced | `advanced/testing-skills.md` | How skills are tested: pressure scenarios, the eval harness, before/after comparison |
| Advanced | `advanced/customizing.md` | Changing or adding skills with writing-skills and evals |
| About | `superpowers.md` | Relationship to upstream Superpowers, what the fork adds, credits |

The home page and `superpowers.md` both carry the upstream credit.

Skills are grouped on `skills/index.md` and in the sidebar:

| Category | Skills |
|---|---|
| Process | brainstorming, writing-plans, executing-plans, subagent-driven-development, dispatching-parallel-agents, using-git-worktrees, finishing-a-development-branch, communication |
| Testing | test-driven-development |
| Debugging | systematic-debugging |
| Review | requesting-code-review, receiving-code-review |
| Performance | profiling-performance, optimizing-performance |
| Meta | using-hyperpowers, writing-skills |

### Skill page template

```markdown
---
sources: skills/<name> <other repository paths the page describes>
source-digest: <12 hex digits; see Drift checks>
---
# <name>

One sentence: what the skill does for you.

<at-a-glance card (sphinx-design): category, triggers on, hands off to,
harness notes>

## When it triggers
## What it does
## Why it exists
## Pros
## Cons and costs
## Skipping or overriding
## Works with
## Under the hood
```

- **When it triggers:** the frontmatter description in plain words, plus
  two or three example requests.
- **What it does:** the process as the reader sees it in a session, step by
  step.
- **Why it exists:** the failure it prevents and the reasoning, linking
  decision records where they exist.
- **Pros** and **Cons and costs:** argued from how the skill works. Each
  page has at least two concrete cons (time, tokens, extra question rounds,
  friction, cases where the skill fits badly).
- **Skipping or overriding:** what to tell the agent, and when that is
  reasonable.
- **Works with:** the skills it hands to and receives from, as links.
- **Under the hood:** supporting files and scripts, linked to their source
  through the `{source}` role (see Build and hosting), never through a
  hard-coded branch URL.

`sources` names every repository path (file or directory) whose behavior
the page describes, space-separated on one line. A skill page always
includes its own `skills/<name>` directory, so a change to any supporting
file or script flags the page, and adds anything else it describes (for
example `hooks/` for the bootstrap). Advanced pages and
`recommended-settings.md` carry the same two keys.

### Recommended settings

The page applies to Claude Code and says so first. It opens with the reason
behind every tip: each model call re-sends the whole conversation, so in
long sessions most of the cost is reading and writing cached context, and
cost tracks context size times the number of calls. Then three tips, each
with the setting, why it saves, and why quality holds:

1. Lower the auto-compact window to 400K: `"autoCompactWindow": 400000` in
   `settings.json`, or `CLAUDE_CODE_AUTO_COMPACT_WINDOW`. On 1M-token
   models compaction otherwise waits until about 968K. In a replay of a
   month of long sessions, 400K cut cost by about 28%; 300K or 200K saved
   only 4 or 7 points more while compacting 1.5 or 2.6 times as often.
   Quality, stated no wider than the evidence: after a compaction Claude
   Code re-attaches only the first 20,000 characters of each skill.
   brainstorming and subagent-driven-development, the two long skills most
   sessions run, tell the agent to re-read their full text after every
   compaction. In testing at a forced 100K window, where compactions come
   far more often than at 400K, agents re-read after 98%
   (subagent-driven-development) and 100% (brainstorming) of compactions.
   The 400K window itself was not measured; it leaves about 300K of free
   context after each compaction. writing-skills is also longer than the
   re-attached copy and does not yet carry the instruction; the page says
   so. Do not go below about 200K, where a session can compact again right
   after the re-read.
2. Keep one-hour prompt caching: if `ENABLE_PROMPT_CACHING_1H=1` is set,
   leave it. Sessions pause for five to sixty minutes while subagents and
   reviews run; with a five-minute cache each such pause rewrites the whole
   context. The same replay cost about 56% more with five-minute caching.
3. Run `/clear` between planning and execution. The spec and plan are on
   disk, so subagent-driven development starts from a small context.

A closing note says these settings change token volume, and how that shows
up depends on the reader's plan (per-token billing or subscription usage
limits). The page leaves out model choice and model aliases, Codex gate
overhead, and idle compaction.

### Build and hosting

- `docs/site/conf.py`: `html_theme = "lumina"`; extensions `myst_parser`,
  `sphinx_design`, `sphinx_copybutton`, `sphinxcontrib.mermaid`,
  `sphinx.ext.extlinks`, `sphinx_sitemap`; MyST `colon_fence`.
  - Source ref: `SOURCE_REF` is Read the Docs' `READTHEDOCS_GIT_IDENTIFIER`
    (the branch or tag being built) when set, otherwise `main`. A `stable`
    build of a tag therefore links to that tag's sources.
  - Theme options: `source_repository`
    `https://github.com/scott-arne/hyperpowers`, `source_branch`
    `SOURCE_REF`, `source_directory` `docs/site/`; `nav_links` to the GitHub
    repository and to upstream Superpowers.
  - `extlinks`: a `source` role expanding to
    `https://github.com/scott-arne/hyperpowers/blob/<SOURCE_REF>/%s`. Pages
    link repository files only through `{source}`.
  - `release` and `version` are read from the repository's `package.json`
    at build time, so vrzn remains the only place the version is set.
  - `html_baseurl` comes from Read the Docs' `READTHEDOCS_CANONICAL_URL`
    when present, for `sphinx_sitemap` (a dependency of the theme).
  - `exclude_patterns` covers `_build`.
- `docs/site/requirements.txt`: exact pins, starting from
  `sphinx-lumina-theme==2.19.1` and the versions it resolves with on
  Python 3.13.
- `.readthedocs.yaml` (repository root): `version: 2`, `build.os:
  ubuntu-24.04`, `build.tools.python: "3.13"`, `sphinx.configuration:
  docs/site/conf.py`, `sphinx.fail_on_warning: true`, `python.install` from
  `docs/site/requirements.txt`.
- `.gitignore`: add `docs/site/_build/`.
- Local build, documented in `docs/testing.md` under a short "Building the
  docs" heading:

  ```bash
  uv run --python 3.13 --with-requirements docs/site/requirements.txt \
    sphinx-build -W --keep-going docs/site docs/site/_build/html
  ```

### Drift checks

**Source digest.** For a page with `sources: P1 P2 ...`, list every
tracked file under those paths with `git ls-files -- P1 P2 ...`, sort the
paths bytewise (`LC_ALL=C sort`), and for each emit one line
`<sha256 of the file's contents>  <path>`. The digest is the first 12 hex
digits of the SHA-256 of those lines joined with newlines. SHA-256 comes
from `shasum -a 256`, falling back to `sha256sum`. Using `git ls-files`
keeps untracked scratch out of the digest.

`tests/docs/test-docs-skills.sh`, bash, offline, shellcheck-clean, in the
style of the existing suites. It fails when:

1. a `skills/<name>/SKILL.md` has no `docs/site/skills/<name>.md`;
2. a `docs/site/skills/<name>.md` other than `index.md` has no matching
   skill directory;
3. a page that must carry sources lacks `sources:` or `source-digest:`
   (every page under `docs/site/skills/` except `index.md`, every page
   under `docs/site/advanced/`, and `docs/site/recommended-settings.md`),
   or a skill page's `sources` omits its own `skills/<name>`, or a listed
   path matches no tracked file;
4. a page's `source-digest` differs from the digest computed above. The
   message names the page, its sources, and both digests, and says:
   re-read the page against the changed sources, fix what is stale, then
   set `source-digest` to the computed value;
5. a skill page lacks any of the eight template headings (`## When it
   triggers` through `## Under the hood`) or has them out of order, or its
   `## Cons and costs` section has fewer than two list items;
6. `docs/site/skills/index.md` does not link every skill page;
7. any file under `docs/site/` matches a dollar amount (a `$` followed by
   a digit) or the words `USD`, `dollar`, or `dollars`.

The requirements a script cannot judge (example requests under "When it
triggers", concrete cons, accurate "Works with" links, the at-a-glance
card) are on the final review's per-page checklist (see Testing).

Wiring: add `tests/docs/test-*.sh` to the loop in `tests/run-offline.sh`;
add a `tests/docs/` row to the table in `docs/testing.md`; add one line to
`CLAUDE.md` under "Making Changes in This Fork": a change to a skill, hook,
or script that a docs page lists in `sources` also reviews that page and
updates its `source-digest`.

The private-information rule is a review step, not a test: a test would
have to contain the strings it searches for.

## Testing

- `bash tests/docs/test-docs-skills.sh` passes, and each of its seven
  failure modes is shown to fail on a deliberately broken copy (missing
  page, orphan page, missing or incomplete `sources`, stale digest, missing
  or reordered heading and a one-item cons list, unlisted page, a dollar
  amount). The digest check is also shown to fail when only a supporting
  file under a skill directory changes.
- `bash tests/run-offline.sh` passes with the new suite included, and
  `bash tests/shell-lint/test-lint-shell.sh` passes.
- The local build command (Build and hosting) exits 0.
- Link check, in the same pinned environment:

  ```bash
  uv run --python 3.13 --with-requirements docs/site/requirements.txt \
    sphinx-build -b linkcheck docs/site docs/site/_build/linkcheck
  ```

  reports no broken external links (redirects are acceptable).
- The built HTML is rendered and inspected for the home page, one skill
  page, `workflow.md` (Mermaid diagram), and `recommended-settings.md` in
  both light and dark modes.
- A local build with `READTHEDOCS_GIT_IDENTIFIER=v0.0.0-test` set renders
  `{source}` links and the edit link with that ref in place of `main`.
- The final review reads every file the branch changes and every commit
  message: behavior claims against the pages' `sources`, the absence of
  dollar figures and organization details, and the upstream credit. For
  each skill page it also checks the per-page list: two or three example
  requests, at least two concrete cons, "Works with" links that match the
  skill's actual hand-offs, and an at-a-glance card with all four fields.

## Publishing

These steps are the human partner's, after this work:

1. Push. Read the Docs builds only what is on GitHub. Main currently waits
   on a pending history rewrite and carries unreleased work, so when the
   site goes live is a release decision.
2. Import `scott-arne/hyperpowers` on readthedocs.org.
3. Serve `latest` (main) as the default until a tagged release contains
   `docs/site/`, then switch the default version to `stable`.
4. Trim the README's "Cost and Context" section to the settings plus a link
   to the live page (separate change).

## Decisions

- **Hand-written pages with drift checks.** Every page is authored MyST; an
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
- **Qualitative pros and cons plus one testing-method page.** Skill pages
  argue pros and cons from how each skill works; `advanced/testing-skills.md`
  explains the method once. Rejected: quoting eval numbers on skill pages,
  because they belong to one version and need re-checking every release.
- **MyST Markdown.** Matches the rest of the repository and the theme's own
  docs. Rejected: reStructuredText, a second format for every contributor.
- **The site lives in `docs/site/`.** Keeps it apart from the specs, records,
  and evidence notes in `docs/hyperpowers/`, and outside the plugin install.
- **No dollar figures and no organization details; percentages allowed.**
  The human partner's rule (2026-11-05), enforced by the drift test over
  `docs/site/`, a dollar-amount scan of every staged diff and commit
  message, and a final review of every changed file and commit message for
  organization details.
- **The README's cost section is trimmed in a separate change after the site
  is live.** Rejected: trimming now, because the link would not resolve yet.
- **Recommended settings cover three Claude Code tips** (400K auto-compact
  window with a 200K floor, one-hour caching, `/clear` before execution).
  Model choice, model aliases, Codex gate overhead, and idle compaction are
  left out as setup-specific or unmeasured as general tips. The quality
  claim names the two skills that re-read after compaction, the measured
  re-read rates at a 100K window, that 400K itself was not measured, and
  that writing-skills lacks the instruction (spec review correction of the
  "every compaction" wording approved in chat).
- **Source links follow the built version.** `{source}` links and the edit
  link use Read the Docs' git identifier, falling back to `main`, so a
  `stable` page links to the tag it documents. Rejected: hard-coded `main`
  links, which would show a tagged page's readers newer source.
- **The Sphinx build stays out of the offline test set.** It downloads
  packages on first run; Read the Docs enforces `fail_on_warning` once the
  project is live, and the local command is documented.

## Assumptions

- Assumption: `sphinx-lumina-theme` 2.19.1 builds with `myst_parser`,
  `sphinx_design`, `sphinx_copybutton`, `sphinxcontrib.mermaid`,
  `sphinx.ext.extlinks`, and `sphinx_sitemap` on Python 3.13 with no
  warnings, validate via the first local `-W` build.
- Assumption: unknown front-matter keys (`sources`, `source-digest`)
  produce no Sphinx or MyST warning, validate via the same build.
- Assumption: Read the Docs sets `READTHEDOCS_GIT_IDENTIFIER` to the branch
  or tag being built and `READTHEDOCS_CANONICAL_URL` to the version's URL,
  validate via the Read the Docs environment-variable reference when
  writing `conf.py`.
- Assumption: `autoCompactWindow`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, and
  `ENABLE_PROMPT_CACHING_1H` keep their names and meaning in current Claude
  Code, validate via the Claude Code settings documentation when writing
  the page.
- Assumption: Read the Docs' `ubuntu-24.04` image offers Python 3.13,
  validate via the Read the Docs build configuration reference when
  writing `.readthedocs.yaml`.
