---
sources: skills/finishing-a-development-branch skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/subagent-driven-development/SKILL.md docs/hyperpowers/specs/2026-10-21-decision-records-design.md
source-digest: c4be2b6ab235
---
# How decision records are made

This page covers how a spec's list of decisions becomes a set of decision records: where the list comes from, what the compiler writes, how a later design reverses an earlier record, and what happens to the plan and the spec at the end of a branch. The finishing skill's menu and questions are on the {doc}`../skills/finishing-a-development-branch` page. This page covers the files behind them.

## Where the decisions come from

The source of every record is the spec. The brainstorming skill requires the spec to carry a `## Decisions` section. The compiler takes the first level-two heading whose text contains the word "decision" as that section. The section holds one top-level list item per decision. Each item opens with a bold title and states what was chosen, what was rejected, and why. Only decisions go in that list.

An item may carry a line `Supersedes: <repository-relative record path>`. That line says this decision reverses an existing record. Brainstorming reads the decisions index when it exists and opens the current records for the area in hand, because each one is a constraint on the new design. A design that reverses a record is architectural work and gets a spec, since bounded work has no spec and cannot supersede.

During execution, a plan paragraph that changes one of the spec's decisions names it as `Correction (<date>), decision <N> (<title>):`. The extractor reads those paragraphs. The numbers stay valid because the list is append-only once execution starts: the finishing skill appends an accepted new decision after the last item and never inserts one.

## What the compiler writes

`decisions-compile` is a bash script in {source}`skills/finishing-a-development-branch/scripts/decisions-compile`. It lifts each decision item from the spec into its own file under the `decisions/` directory beside the spec's directory. For a spec in `docs/hyperpowers/specs/`, the records go to `docs/hyperpowers/decisions/`. Its usage is:

```text
decisions-compile SPEC [--plan PLAN] [--notes FILE] [--paths-file FILE] [--dry-run]
decisions-compile --undo SPEC [--plan PLAN]
decisions-compile --reindex RECORDS_DIR
```

A record's filename is a date and a slug of the decision's title. Its content has these parts:

- A title line and a header with the status (`accepted`, or `superseded by` a record), the spec and decision number it came from, and a `Recorded` line that includes the plan path when a plan was removed.
- A `## Decision` section holding the spec's item text.
- A `## What implementation changed` section holding the extractor's note for that decision, or `Nothing recorded.` when there is none.

The spec is the only source of a record's title and decision text. A re-run refreshes them and keeps the record's filename and recorded date. The compiler validates every input before it writes anything, and it never commits. It stages the records, the index, the spec, and the plan's deletion, and it writes the list of changed paths to the file named by `--paths-file`, which the finishing skill then commits in one records commit. Exit code 2 means an input problem and nothing was written. Exit code 3 means a write or git operation failed after validation, and the finishing skill reports the git failure and runs the same command again once the failure is cleared.

`--dry-run` reports what would be written. Under subagent-driven development, the controller runs it at the start of a run, where the skill says it costs no cycle time, and writes the numbered listing into the ledger for the extractor's later dispatch. `--undo` backs out a compile when you choose to skip the records for a branch.

## The extractor's notes

The spec is the authority for each decision. A background subagent adds one thing, a note per decision on what the implementation changed. It works from the spec, the merge-base diff, and the plan's correction paragraphs, using the template {source}`skills/finishing-a-development-branch/decision-notes-prompt.md`. Its file may also list proposals: an undocumented decision to add to the spec, and a supersession to add as a `Supersedes:` line. The compiler never applies a proposal. The finishing skill puts each one to you, and an accepted proposal goes into the spec before the compiler runs again.

The notes file is checked strictly. If its first line does not name the spec, or a heading is not one of the allowed forms, the compiler prints a `notes ignored:` line and compiles as if no notes were given. Where the harness has no tracked background subagent, or the extractor has not finished when the tests pass, the records are compiled without notes.

## The index

The compiler regenerates `README.md` in the records directory at each compile. It starts with a line saying the file is generated and must not be edited, then a count of current and superseded records, then a Current table of date, decision, and spec. A Superseded table appears when any record is superseded. This repository's index is {source}`docs/hyperpowers/decisions/README.md`. `--reindex` rebuilds it from the records without compiling a spec.

## Supersession

A reversal is a new record. A decision item with a `Supersedes:` line gets a `Supersedes` field in its record, and the compiler changes the older record's status from `accepted` to `superseded by` the new record. It rewrites that status line and nothing else in the older record. Among the cases the compiler refuses are a `Supersedes:` path that is not a record in the same records directory, a symbolic link, a path that does not exist, a record of the same spec, a target whose status is neither `accepted` nor `superseded by`, and a target already superseded by an unrelated record. The index then lists the older record under Superseded.

## What happens to the plan and the spec

The records commit removes the plan from the tree, on the feature branch before any merge. Each record names the plan's path, and git history keeps the plan itself. The spec stays. Until the records commit it is a working document whose decision list you can amend. From that commit on, the only line that changes is a `**Outcome:**` line near the top, which the compiler writes and rewrites. It states the implementation date and the number of records. The design rationale for these rules is in {source}`docs/hyperpowers/specs/2026-10-21-decision-records-design.md`.
