---
sources: skills/writing-skills CLAUDE.md docs/testing.md
source-digest: cd389d497851
---
# Customizing skills in your own fork

This page covers changing or adding a skill when you maintain your own copy of hyperpowers. It draws on two sources. The `writing-skills` skill says how a skill is written and tested. `CLAUDE.md` holds this repository's contributor rules for changes to it, and those rules are a good template for a fork of your own. The testing method is on {doc}`testing-skills`, and the skill itself is on the {doc}`../skills/writing-skills` page.

## Where a skill lives

A skill is a directory with a `SKILL.md` that has two required frontmatter fields, `name` and `description`. Supporting files sit beside it when the skill needs heavy reference material or a reusable tool. `writing-skills` says personal skills live in your runtime's skills directory (`~/.claude/skills/` on Claude Code), and it points to a reference file for Codex. Codex and Copilot CLI also recognize `~/.agents/skills/`.

## Changing or adding a skill

1. Start with `writing-skills`. Its iron law is that no skill is written or edited without a failing test first. The skill lists no exceptions for a simple addition, a new section, or a documentation update. {doc}`testing-skills` describes the pressure scenarios and the baseline run.
2. Run the baseline without the change and record what the agent does. Make the change, then run the same scenarios again and compare. `CLAUDE.md` asks for adversarial pressure testing across multiple sessions and for the before-and-after evidence to be kept with the change.
3. Write the description as triggering conditions only. It starts with "Use when", is in the third person, and does not summarize the skill's process. `writing-skills` gives the reason: an agent may follow a description that summarizes the workflow and skip the skill body.
4. Leave carefully tuned content alone unless you have evidence. `CLAUDE.md` names the red-flags tables, the rationalization lists, and the "human partner" wording.
5. Keep the change to one problem.

## Keeping the docs page current

`CLAUDE.md` adds a rule for this repository. When a change touches a skill, hook, or script that a page under `docs/site/` lists in its `sources:` front matter, you also re-read that page, fix what is stale, and update its `source-digest:`. The command `bash tests/docs/docs-check.sh --digest <page>` prints the new value. A new skill needs a page of its own. The docs check fails when a page's digest no longer matches its sources, so a stale page shows up as a failing check.

## What to keep out of core skills

`CLAUDE.md` asks that core skills stay general-purpose, so they remain mergeable with upstream Superpowers and useful across projects. It lists two kinds of content to keep out:

- Third-party dependencies. This fork takes targeted ones, the first being the Codex plugin for Claude Code behind the optional Codex review gates. `CLAUDE.md` requires such a dependency to degrade cleanly, with skills fully functional when it is absent, and to stay scoped to the harness where it applies.
- Project-, team-, or domain-specific configuration. A skill or hook that benefits one project or workflow belongs in a separate plugin.

## Relationship to upstream

`CLAUDE.md` describes this repository as a personal fork of Superpowers, maintained so that skills can be customized without colliding with an installed copy of upstream. It tells contributors not to open pull requests to upstream that only sync the fork or push fork-specific rebranding. A general-purpose improvement goes to upstream as a clean branch that follows upstream's own contributor guidelines. The site's {doc}`../superpowers` page covers the relationship from the reader's side.
