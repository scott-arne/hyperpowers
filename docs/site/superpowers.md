# Relationship to Superpowers

Hyperpowers is a fork of [Superpowers](https://github.com/obra/superpowers), built by Jesse Vincent and Prime Radiant. Superpowers is a software development methodology for coding agents, made of composable skills and initial instructions that make the agent use them.

## What is upstream's

The methodology, the skill design, and most of the prose are the upstream project's work, and credit for the approach belongs there. The fork is maintained independently, so it can change skills and prompts locally without colliding with an installed copy of Superpowers. To get the original, install Superpowers from its own repository.

## The word "superpowers"

The package, the plugin manifests, and the skill-invocation namespace are renamed to `hyperpowers`. Agent-facing prompts still call the capability "superpowers", on purpose. The fork keeps that word in skill bodies when it merges upstream changes.

## What this fork adds

The README, the contributor guidelines in {source}`CLAUDE.md`, and the {source}`CHANGELOG.md` (which records only this fork's releases) describe these additions:

- **Codex review gates.** Spec, plan, and code reviews that ask Codex through codex-plugin-cc, on Claude Code only. This is the fork's first dependency on a third-party tool, and the skills work without it.
- **Decision records.** The repository commits specs and decision records compiled from each spec's `## Decisions` list when work finishes. The index is {source}`docs/hyperpowers/decisions/README.md`.
- **The communication and performance skills.** {doc}`skills/communication`, {doc}`skills/profiling-performance`, and {doc}`skills/optimizing-performance` are listed in the README's skills library.
- **The re-read after compaction.** {doc}`skills/subagent-driven-development` and {doc}`skills/brainstorming` tell the agent to read their full text after every context compaction, because Claude Code re-attaches skills cut to their first 20,000 characters.
- **The SDD workspace.** Subagent-driven development keeps a ledger and per-task records for a plan in a workspace, managed by the `sdd-state` script, and removes it at finish.
- **An eval harness.** Skill behavior is tested with the quorum harness from the hyperpowers-evals repository, itself a fork of the upstream evals.

## How the fork tracks upstream

The fork keeps upstream as a read-only `upstream` remote and merges releases tag to tag, or cherry-picks single improvements. Git's `rerere` replays the resolutions for the rename conflicts that recur on every sync. The last merged upstream release is recorded in {source}`.upstream-version.json` and in the README. The fork's own version numbers are independent of upstream's.

## Credits

Jesse Vincent and [Prime Radiant](https://primeradiant.com) built Superpowers, and package `author` fields credit Jesse Vincent. Scott Johnson maintains this fork. Issues for the fork go to [its issue tracker](https://github.com/scott-arne/hyperpowers/issues).
