# Decision Notes Prompt Template

Use this template to dispatch the decision extractor: a background subagent
that reads what shipped and writes, for each decision in the spec's
`## Decisions` list, what implementation changed. Its output is prose and
proposals that `scripts/decisions-compile --notes` consumes; the spec stays
the only authority for the decisions themselves, and the compiler never
applies a proposal.

**Purpose:** Capture, while the branch is still open, the gap between each
decision as the spec stated it and what the implementation did, so the
record a future design session reads is true about what shipped.

Dispatch it in the background and never wait for it: the finishing skill
collects it after the full suite, stops it if it has not finished, and
compiles without it. Set `run_in_background: true` where the Agent tool
offers the parameter; in a Claude Code interactive session's fork mode every
dispatch is already asynchronous and the parameter is absent. On a harness
with no tracked background subagent, do not dispatch at all: compile without
notes and say so.

```
Subagent (general-purpose):
  description: "Decision notes for [SPEC_BASENAME]"
  model: [MODEL — the mid-tier floor SDD's Model Selection sets for reviewers;
         an omitted model silently inherits the session's most expensive one]
  run_in_background: true
  prompt: |
    You write implementation notes for a list of design decisions. You do
    not judge the decisions, restate them, or add rationale the spec does
    not contain. You write one file and nothing else.

    ## The decisions

    Read the spec: [SPEC_PATH]
    Its `## Decisions` section is a list; the compiler numbers its items in
    order, and this is the numbering you use:

    [DRY_RUN_LISTING — the `would write ... (decision N: <title>)` lines
    from `decisions-compile --dry-run`, verbatim]

    ## What shipped

    [PLAN_LINE — when the branch has a plan: "Read the plan: <path>. Its
    dated `Correction` paragraphs, and any paragraph that names a decision
    (`decision <N>`), are the record of changes made during execution.";
    otherwise: "This branch has no plan; the diff is the only record."]

    Read the diff: [DIFF_SOURCE — under SDD: "the review package copy at
    <path>"; otherwise: "run `git diff <MERGE_BASE>...HEAD --stat` and
    `git diff <MERGE_BASE>...HEAD`"]

    [LEDGER_LINE — under SDD: "Read the ledger copy at <path> for its
    deferred-minor lines."; otherwise omit this line]

    [INDEX_LINE — when the index exists: "The index of existing records is
    <path>; a supersession you propose must name a record listed there.";
    otherwise omit this line]

    ## What to write

    Write exactly this file and nothing else: [OUTPUT_PATH]

        # Decision notes: [SPEC_PATH]

        ## Decision 1
        <two to six sentences: what the implementation changed relative to
        this decision, naming modules, functions, tests and invariants,
        never line numbers; or the single line: No change.>

        ## Decision 2
        <one section per decision, every decision, in order>

        ## Supersessions
        - <N> supersedes <record path>
        <only when the work knowingly reversed a record the index lists;
        omit the whole section otherwise>

        ## Undocumented decisions
        - <one line: a choice made during implementation that no decision
          item covers>
        <omit the whole section when there is none>

    Rules the compiler enforces: the first line names this spec; every
    level-two heading is `## Decision <N>`, `## Supersessions` or
    `## Undocumented decisions`; no decision number appears twice; no
    section is empty; the two optional sections hold list items only. A
    file that breaks a rule is ignored whole, so follow the shape exactly.

    ## Read-only

    Apart from the output file, do not write, stage or commit anything, and
    do not change the working tree, the index, HEAD or any branch. Read with
    `git show`, `git diff` and `git log`.

    ## You Do Not Dispatch Subagents

    Do all of this yourself. Never spawn a subagent for any part of it.
```
