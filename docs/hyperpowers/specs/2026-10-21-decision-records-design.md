# Decision records: the why outlives the plan

**Date:** 2026-10-21
**Status:** design approved in chat on 2026-10-21 (five clarifying answers,
the approach choice after a one-shot Codex approach gate, and five design
sections); spec self-reviewed; Codex spec review round 1 (two lenses) raised
sixteen distinct blocking findings, all addressed, and two out-of-lane
findings declined with reasons in the round ledger; round 2 raised seven
more (re-run safety, the skip path, the Outcome count, the review of the
generated content, the serial cost, the unfinished extractor), addressed;
round 3 raised six (the suite gate under SDD, the no-Codex window, the
serial cost again, the `paths:` contract after a failed run, revert after an
amended commit, the Outcome date), addressed; round 4, the ceiling, raised
five (approval before the commit, the freeze point, discovery after the plan
is gone, path transport, supersession fan-in), fixed in this revision after
the last round and therefore not re-reviewed by Codex (ungated-ledger
event recorded); awaiting the human partner's review of this file.
**Branch:** `decision-records`, to be created off hyperpowers `main` at
`d4ea6b5`, the commit that set this line; it contains this spec (`e829db0`),
the planning-directory allowlist change (`7de7dad`: the `docs-allowlist`
script, its test, and the skill lines that run it) and the plugin-install
note (`8197fe2`). This design extends that allowlist. The plan names the
same base.
**Provenance:** the 2026-10-21 session. The rules that kept plans and specs
uncommitted were removed from the global instructions and from brainstorming
and writing-plans. A size assessment then found that plans are 47% of this
repository's tracked bytes (2.9 MB in 26 files, the four largest over 200 KB
holding half), 54 MB in 643 files across the human partner's other
repositories, growing by about 18 MB a month, with a median plan of 50 KB and
a median spec of 16 KB. The human partner's requirement, verbatim: "The only
value for retention is that key design decisions remain known moving
forward. Details, such as references to specific lines of code, will quickly
become outdated. [...] We really want to keep a living understanding of
those design decisions without the cruft", and: "I do not want to add
additional time to the process in keeping the history."

## Problem

A plan is scaffolding. It carries file-by-file steps, exact values and
tests, and dated corrections, and it is read by implementers during one
branch's life. Everything in it that refers to code goes stale within
months. A spec carries the decisions: what was chosen, what was rejected,
why. That is the part a future design session needs, and today it is buried
in a dated file nobody reopens, beside a plan ten times its size.

Other projects separate the two the same way. Proposal documents freeze
once the work ships: PEP 1 calls a finished PEP "a historical document
rather than a living specification"; the Rust RFC process says an accepted
RFC "should not be substantially changed" and that substantial changes are a
new RFC with a note on the old one; a Kubernetes KEP marked implemented is
"no longer actively changed". The living layer is small and refers to things
by name: Nygard's decision records are "one or two pages", immutable, with a
reversal recorded as a new record and the old one "marked as superseded";
matklad's ARCHITECTURE.md names "important files, modules, and types" and
does "not directly link them (links go stale)". OpenSpec archives each
change folder after implementation and folds its deltas into living specs.
Google's experience with design documents is the warning: "in practice we
humans are bad at updating documents", so anything that depends on editing a
living file in place rots.

The constraint that shapes the mechanism is time. Development cycles under
hyperpowers are long on purpose: per-task review, Codex gates, a final
whole-branch review. Keeping the history may not add a serial step to that
cycle. The final review stretch is a window in which the controller waits on
a reviewer, a fix wave, a re-review and a Codex gate while every artifact of
the run still exists; the finishing skill's full test run is a second such
window. Work that fits inside those windows is free. Work that would make
the controller wait is not done.

## Decisions

1. **One file per decision.** A record is a page: status, the spec and
   decision number it comes from, the decision text, and what implementation
   changed. A reversal is a new record that names the old one, and the old
   one's status flips to superseded; nothing else in it is edited. One
   record per shipped spec was rejected because supersession at that grain
   has to point inside another file, and one living file per repository was
   rejected because it is edited in place and conflicts across parallel
   branches.
2. **Records are extracted at finish only, and the spec's Decisions section
   is required.** Nothing new is written at design time. The spec already
   carries the decisions in a numbered or bulleted list in 16 of this
   repository's 24 specs; the rule makes that section mandatory and uniform.
   Drafting records at spec time was rejected because abandoned and reworked
   specs would leave records to retire; collecting decision notes from every
   task report was rejected because it adds a line to every report for what
   the final diff and the plan's corrections already carry.
3. **The plan is removed from the tree at finish.** The commit that adds the
   records removes the plan, on the feature branch before merge. Under a
   merge that preserves branch commits, which the finishing skill's local
   merge does, git history keeps every byte and
   `git log --diff-filter=D -- <path>` finds the removal; a squash merge on
   the pull-request path keeps only the records, and each record names the
   plan path either way. Keeping plans on main was rejected as the status quo
   this design exists to end; keeping plans only on the portable-dossiers
   state branch was rejected because that work is unfinished, covers only
   SDD runs, and hides the plan from a pull-request reviewer.
4. **The spec stays, frozen from the records commit on, with one Outcome
   line.** While its branch is open the spec is a working document: its
   Decisions list may be amended by the controller with the human partner's
   approval, which is how a legacy prose section becomes a list, how a
   Codex-gate fix that reverses a decision is recorded, and how an accepted
   proposal (an undocumented decision, a supersession) enters it. The
   records commit is the freeze: from then on the only line anyone edits is
   the Outcome line the compiler owns, which states when the work was
   implemented and how many records it produced. Supersession is tracked in
   records only; old specs are not re-stated. Deleting specs with plans was
   rejected because records would then have to carry every alternative and
   constraint themselves.
5. **The same rule applies in this repository.** Its plans are removed at
   finish like everyone else's; specs, records and the dated eval-evidence
   notes carry the reasoning. The 26 existing plans stay until the human
   partner decides on a backfill (Follow-ups).
6. **Skeleton plus delta.** A dependency-free script lifts the spec's
   decision items verbatim into records; a background subagent adds only one
   section per record, what implementation changed, plus proposals the
   human partner rules on. The approved spec is the sole source of the why
   and the sole authority for supersession; the model writes only what the
   spec could not know. Independent approach proposals from Codex converged
   on two alternatives and offered a third: a deterministic compiler alone
   (loses implementation-time discoveries unless a correction carries them),
   a model-only extractor (every rationale probabilistic), and a dossier
   event log with a finish-time reducer (the per-task capture rejected in
   decision 2, and dependent on the unfinished dossier work). The skeleton
   ships even when the delta cannot run.
7. **The delta runs inside existing waits and is never waited for.** Under
   SDD the extractor is dispatched in the background once the final
   review's fix wave and its re-review are clean, so its diff includes that
   fix wave; its window is the Codex final gate when Codex is present and,
   on every path, the finishing skill's full test run that follows. Outside
   SDD, finishing-a-development-branch dispatches it in the background
   before the test run. Collection happens in one place, finishing Step 1,
   after the suite has passed: an extractor that has not finished is not
   waited for; it is stopped with the harness's task stop, the skeleton
   compiles without notes, and the hand-back says so. Background dispatch is
   the Agent tool's `run_in_background: true` where the tool offers the
   parameter (print and SDK sessions, which is what Zed runs), and the
   default in Claude Code 2.1.302 interactive sessions, whose fork mode
   runs every subagent in the background and omits the parameter; where a
   harness has no tracked background subagent the skeleton compiles alone
   and there is nothing to stop.
8. **Names carry a date and a slug; there is no global counter.** The
   filename is the spec's date plus a slug of the decision title. A record's
   identity is its spec path and decision number; a filename collision with
   a different identity takes a decision-number suffix (Design §1). Two
   branches recording decisions at once never have to agree on a counter.
9. **The records directory derives from the spec's location.** It is the
   `decisions/` sibling of the directory that holds the spec, so a user who
   relocates specs relocates records with them without a configuration knob.
10. **Records are mandatory for a branch that has a spec, and the compiler
    is the only writer.** A finish with a spec ends with a records commit or
    with the human partner's explicit decision to skip it, recorded in the
    hand-back; it never ends by silently dropping the step. The compiler
    validates all inputs before its first write, writes idempotently, and
    stages last, and every rule in it accepts the state a previous run left
    behind (a target it already superseded, a plan it already removed, an
    Outcome line it already wrote), so a run after a failure, after a
    disposition, or by accident changes nothing it should not. Records are
    compiled and staged only after the full test suite has passed, and
    committed only after the human partner has seen the complete staged
    diff and answered, on every path; a failing suite never leaves an
    implemented Outcome or a removed plan behind, and a skip before the
    commit is the compiler's `--undo`, which restores every compiler-owned
    path to HEAD.
11. **Evidence bar: offline tests, a parser dry run over real specs, and the
    first live SDD run.** This is a workflow addition, not a trigger-wording
    change, so no quorum campaign is planned. The human partner may raise the
    bar in the plan.
12. **The serial cost is the compiler and one commit, after the suite; the
    human review rides the finishing menu.** Compilation cannot run inside
    a wait because it must follow a passing full suite (Decision 10), so the
    compiler (well under a second) and the pathspec commit (a few seconds)
    run in series between the suite and the options menu. The human partner
    reviews the complete staged diff and rules on the extractor's proposals
    in the same message that presents the finishing options, an interaction
    that exists today, so no message is added to the cycle; the commit
    follows their answer and precedes the option they chose, so the records
    ride the branch before any merge or push and the repository's rule that
    the complete diff is approved before a commit is kept. Only when a
    disposition changed the staged set is the new staged diff shown once
    more before the commit. The human partner accepted the serial cost on
    2026-10-21 when asked during the spec gate, in these words: "Accept:
    seconds after the suite are fine".

## Design

### 1. Layout, the record, the index, the spec line

**Directory.** `docs/hyperpowers/decisions/`, beside `specs/` and `plans/`.
The allowlist admits it (Design §7).

**Identity and filename.** A record's identity is the pair (spec path
relative to the repository root, decision number); it is what the `- Spec:`
line states and what re-runs match on. The filename is
`YYYY-MM-DD-<slug>.md`: the date is the leading `YYYY-MM-DD` of the spec's
filename, or the compile date when the spec filename has none; the slug is
the title lowercased, every run of characters outside `a-z0-9` replaced by
one hyphen, leading and trailing hyphens removed, cut to 60 characters at
the last hyphen before the limit when one exists, and `decision-<N>` when
empty. When that filename exists with a different identity, the filename is
`YYYY-MM-DD-<slug>-<N>.md` with this decision's number; when that exists
with a different identity too, the compiler exits 2 asking for a distinct
title. Two decisions in one spec with the same title therefore produce
`<slug>.md` and `<slug>-2.md` (or whichever number the second one carries).

**Record.** Exactly this shape:

```markdown
# <Title>

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-19-sdd-turn-liveness-design.md (decision 3)
- Recorded: 2026-10-21; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-19-sdd-turn-liveness.md removed at finish
- Supersedes: docs/hyperpowers/decisions/2026-09-17-first-edit-interlock-hook.md

## Decision

<the spec's list item, verbatim, with its list marker removed and its
indentation normalised; nested bullets kept>

## What implementation changed

<the extractor's section for this decision, or the line: Nothing recorded.>
```

The `Recorded:` line is assembled from the parts that apply: the date
always; `notes from the branch diff by a subagent at finish` when notes were
applied; `plan <path> removed at finish` when `--plan` was given. The
`Supersedes:` line appears only when the decision supersedes one or more
records; several paths are comma separated. Status has two values:
`accepted`, and `superseded by <path>[, <path>]` where each path is a record
in the same directory. Paths in records are relative to the repository root.

**Indentation normalisation.** The item's first line loses its list marker
and the whitespace after it; every continuation line loses that many leading
columns when it has them, and is otherwise left as written. Nothing else in
the item changes.

**Title.** The title comes from the item's first paragraph: its lines up to
the first blank line, excluding any `Supersedes:` line, joined with single
spaces. When that paragraph opens with bold text (`**...**`), the title is
that text with one trailing `.` or `:` removed, matched across the joined
paragraph, so a bold title that wraps to a second line is whole. Otherwise
the title is the paragraph's first clause: the text up to the first `. ` or
`: `, or the whole paragraph. A clause longer than 80 characters is cut
inside its first 80: at the last `, ` or `; ` that leaves at least 20
characters, else at the last space, else not at all, so a single token
longer than 80 characters stays whole and no cut lands inside a multibyte
character. Trailing spaces and any trailing `.`, `,`, `;` or `:` left by the
clause or the cut are dropped. A title never begins with `**`. (Corrected
2026-10-22: the dry run over this repository's specs found wrapped bold
titles and first-line fragments.)

**Supersedes in a spec item.** A line inside the item, after any list marker
and whitespace, of the form `Supersedes: <path>[, <path>]`. This line is the
only authority for supersession. The compiler validates each path: it names
an existing record in the records directory; that record's identity is not
this spec's; and that record's status is `accepted`, or is
`superseded by ...` naming this very record (a previous run of this
compile), which counts as already done. Duplicates within one item collapse
to one; several items of one spec may name the same target, in which case
the target's status lists all of them (Design §2 step 5). Any violation
exits 2 with the item number and the path, before anything is written. The
line stays in the verbatim decision text.

**Index.** `docs/hyperpowers/decisions/README.md`, regenerated on every
run from the records in the directory (their H1, `- Status:` and `- Spec:`
lines):

```markdown
# Decisions

Generated by decisions-compile. Do not edit; re-run the compiler.
<N> current, <M> superseded.

## Current

| Date | Decision | Spec |
|---|---|---|
| 2026-10-19 | [Mechanism: skill text, not a Stop hook](2026-10-19-mechanism-skill-text-not-a-stop-hook.md) | [2026-10-19-sdd-turn-liveness-design.md](../specs/2026-10-19-sdd-turn-liveness-design.md) |

## Superseded

| Date | Decision | Superseded by |
|---|---|---|
```

Rows sort by date, newest first, then by title. A date is the record
filename's leading date. The Superseded table is omitted when empty. In a
table cell `|` is written `\|`; in a link label `[` and `]` are written `\[`
and `\]`; titles are otherwise verbatim.

**Outcome line in the spec.** After the first line that begins with `# `
and the blank line that follows it (or as the first line when the spec has
no such title), the compiler inserts:

```markdown
**Outcome:** implemented 2026-10-21; 3 decisions under docs/hyperpowers/decisions/.

```

The compiler owns that line: when one beginning with `**Outcome:**` already
exists in the first 30 lines of the spec it is rewritten with its existing
date and the current count, so a re-run after a decision was added reports
the new count, a re-run on a later day keeps the day the work was
implemented, and an unchanged count leaves the line byte-identical. The
date a run uses when it writes a date for the first time is today's, or the
value of `DECISIONS_COMPILE_DATE` when that environment variable is set,
which is how the tests simulate a later day. The spec is otherwise
untouched by the compiler.

**The Decisions section, going forward.** Brainstorming writes:

```markdown
## Decisions

1. **<Title>.** <what was chosen, what was rejected, why>
   Supersedes: docs/hyperpowers/decisions/<file>.md
2. **<Title>.** ...
```

One top-level list item per decision, opening with a bold title, and only
decisions in the list. The compiler accepts what exists today as well: the
first level-two heading whose text contains `decision` (case-insensitive)
wins; numbered (`1.` or `1)`) or bulleted (`-` or `*`) top-level items are
accepted; a plain item is titled by its first clause. Prose with no list
items is refused, which is the case for 4 of this repository's 16 specs with
such a section; Design §4 and §5 say when and how the list is supplied.

### 2. `decisions-compile`

`skills/finishing-a-development-branch/scripts/decisions-compile`, bash,
using only git, awk, sed, date and POSIX coreutils, portable to BSD and GNU
userlands, shellcheck clean. Like the other helpers it is invoked by its path
under the skill directory with the repository as the working directory;
its arguments resolve from the working directory, never from the plugin's
location.

```
decisions-compile SPEC [--plan PLAN] [--notes FILE] [--paths-file FILE] [--dry-run]
decisions-compile --undo SPEC [--plan PLAN]
decisions-compile --reindex RECORDS_DIR
```

**Inputs.** `SPEC` is the spec path. The repository root is
`git rev-parse --show-toplevel` from the spec's directory; the records
directory is `<dirname(dirname SPEC)>/decisions`, created when missing.
`--plan` names the plan to remove. `--notes` names the extractor's output
(Design §3). `--paths-file` names a file the compiler writes with the
NUL-delimited staged paths of step 9, the transport the commit uses.
`--dry-run` prints what a run would do and writes nothing. `--undo`
restores every compiler-owned path with a staged difference from HEAD
(the records directory, the spec, the plan) to its HEAD state, deleting
paths HEAD does not have, and leaves every other staged change alone; it
is the skip before the commit. `--reindex` regenerates only the index of a
records directory, for conflict recovery (Known limits).

**Steps, in order.** Steps 1 to 3 validate; nothing is written before step 4.

1. Read the spec. Find the Decisions section (Design §1). Split it into
   items: a line matching `^[0-9]+[.)] ` or `^[-*] ` starts an item; every
   following line until the next such line or the next `## ` heading belongs
   to it; lines before the first item are ignored; trailing blank lines are
   trimmed. Zero items: exit 2 with
   `<spec>: no decisions list (add "## Decisions" with one list item per decision)`.
2. For each item compute title, slug and filename (Design §1), and collect
   and validate its `Supersedes:` paths. Any violation: exit 2 naming the
   item number and the path.
3. Read the notes file when given and check it against the grammar in
   Design §3. A malformed notes file, or a `## Decision N` with N outside
   1..items, makes the notes invalid: the compiler prints
   `notes ignored: <reason>` to stderr and continues as if `--notes` had not
   been given. Notes are never a reason to fail. Its `## Supersessions` and
   `## Undocumented decisions` lines are counted for the summary and never
   applied or written.
4. Write each record. When a record with this identity already exists
   (same `- Spec:` line), keep its filename and the date on its
   `Recorded:` line, refresh its title and decision text from the spec (the
   spec is the authority until the freeze, and an amended item must reach
   the record verbatim), replace its `What implementation changed` section
   when notes for this decision were given (an absent or invalid notes file
   leaves an existing section alone), and rewrite the notes and plan parts
   of its `Recorded:` line and its `Supersedes:` line. Otherwise create it.
5. Group the validated supersessions by target. For each target, the new
   status lists every superseding record path, the ones its status already
   named and the ones this run adds, sorted, comma separated, written once;
   a target whose status already lists exactly that set is left alone.
6. Regenerate the index.
7. Insert the Outcome line into the spec (Design §1).
8. Stage: `git add` the records written or updated, the index and the
   spec; with `--plan`, remove the plan last: when the file is in the
   working tree, `git rm --quiet <plan>`; when it is absent and its deletion
   is staged, nothing to do and the path stays in `paths:`; when it is absent
   from the tree and the index (a previous run's commit removed it), nothing
   to do and the path is omitted from `paths:`. Never commit.
9. Print the summary, then one line per record, then the paths line:

   ```
   wrote <W> records, updated <U>, superseded <S>, undocumented <D>, proposed supersessions <P>, index <path>
   wrote <path> (decision <N>: <title>)
   updated <path> (decision <N>: <title>)
   updated <path> (superseded by <path>)
   wrote|updated <index path>
   updated <spec path> (outcome)
   removed <plan path>
   paths: <space-separated repository-relative paths of every file staged, the plan included>
   ```

   A verb line is printed only when this run changed that file. The
   `paths:` line is different: it is computed after staging as every
   compiler-owned path whose staged content differs from HEAD (the records
   this run wrote or re-ran, the supersession targets it rewrote, the index,
   the spec and the plan; a staged change under the records directory that
   this run does not own is refused before the first write), so it
   also carries what a failed earlier run staged and this run found already
   in place. A run that changes nothing on a clean index prints the summary
   and an empty `paths:` line; a run that changes nothing after a failed
   run prints the earlier run's staged paths, and the pathspec commit then
   commits them all. The `paths:` line is for reading; the same set is
   written NUL-delimited to the `--paths-file` when given
   (`git diff --cached --name-only -z`), and that file is the only form the
   commit consumes, so a path with a space or a newline survives.

   With `--dry-run`, the verbs read `would write` and `would update`, the
   `paths:` line lists what would be staged, and steps 4 to 8 perform no
   writes. The numbered listing is what the extractor's dispatch quotes.

**Failure behaviour.** Exit 0 on success. Exit 2 for an input problem (spec
missing or unreadable, no decisions list, a Supersedes violation, a filename
collision that the suffix rule cannot resolve); nothing has been written.
Exit 3 when a git operation in step 8 fails: every file of steps 4 to 7 has
been written and nothing is staged beyond what succeeded; the plan has not
been removed unless `git rm` was the operation that succeeded last. Because
steps 4 to 7 are idempotent and step 8 accepts an already-removed plan,
running the same command again completes the staging. Every failure prints
one line to stderr beginning with the spec path.

**The commit.** After the human partner's approval (Design §5), the
controller commits with the pathspec file:

```bash
GIT_LITERAL_PATHSPECS=1 git commit --pathspec-from-file=<paths file> --pathspec-file-nul -m "docs: record decisions for <spec filename without -design.md>"
```

A pathspec commit records those paths and leaves any other staged change
staged, so a dirty index is not swept into the records commit. The entries
are literal pathspecs, as the compiler's own git calls treat them, so a
bracket, star or question mark in a spec name matches only itself. An empty
pathspec file means nothing to commit. There is one records commit per
branch: every disposition is applied, and the compiler re-run, before it.
A skip before the commit is `decisions-compile --undo <spec> --plan <plan>`;
the hand-back records the skip in the human partner's words. No attribution
lines.

### 3. The extractor

**Prompt file.** `skills/finishing-a-development-branch/decision-notes-prompt.md`,
composed into an Agent dispatch by the controller. The dispatch names, in
this order: the spec path and the numbered listing from
`decisions-compile --dry-run` so the numbering is not re-derived; the plan
path, with the note that dated `Correction` paragraphs are the record of
changes made during execution; the diff to read (under SDD the copy of the
latest final-review package, elsewhere `git diff <merge-base>...HEAD` with
the merge base given); the index path, so a proposed supersession can name
an existing record; under SDD, the copy of the ledger for its
deferred-minor lines; and the output path.

**Output grammar.** One markdown file:

```markdown
# Decision notes: <spec path>

## Decision 1
<two to six sentences: what implementation changed relative to this
decision, naming modules, functions, tests and invariants, never line
numbers; or the single line: No change.>

## Decision 2
...

## Supersessions
- 3 supersedes docs/hyperpowers/decisions/<file>.md

## Undocumented decisions
- <one line each: a choice made during implementation that no decision item covers>
```

The file is valid when: its first line is `# Decision notes: <spec path>`;
every level-two heading is `## Decision <N>` with N a positive integer, or
`## Supersessions`, or `## Undocumented decisions`; no `## Decision <N>`
appears twice; every `## Decision <N>` has a non-empty body; the two optional
sections contain only list items, a supersession item being
`- <N> supersedes <path>`. Anything else makes the file malformed, which
Design §2 step 3 turns into a warning and a compile without notes. Every
decision gets a section. `Supersessions` and `Undocumented decisions` are
proposals for the human partner (Design §4 step 3); the compiler never
applies them.

The extractor may not restate a decision, add rationale the spec does not
contain, write to any file but the output, or propose a record. It is
dispatched read-only apart from that file.

**Model and mode.** The mid-tier floor the SDD model-selection rule sets for
reviewers. Under Claude Code the dispatch is background work: the prompt
template sets `run_in_background: true`, and when the Agent tool has no
such parameter (fork mode in 2.1.302 interactive sessions, where every
dispatch is already asynchronous and a passed value is ignored) the
dispatch is background by default; the controller's next step never
depends on it either way. Its inputs and its output
live outside the SDD workspace, because Finish deletes that workspace while
the extractor may still be running: the controller takes a fresh directory
from the requesting-code-review skill's `scripts/codex-review-dir` helper
(a per-run directory under the user cache, chosen over the host's temp
directory, which has been emptied mid-session before), copies the review
package and the ledger into it under SDD, and names the copies and
`<dir>/decision-notes.md` in the dispatch. The extractor reads the
repository and that directory only. Nothing in it is committed.

**Collection.** At the collection point, finishing Step 1 after the suite
has passed (Design §5 step 4), the controller checks whether the extractor
has reported. If it has, the notes
file is passed to the compiler. If it has not, the controller stops it with
the harness's task stop (Claude Code's `TaskStop`), so that nothing still
reads the worktree or writes into the workspace when Finish deletes that
workspace or the finishing skill removes the worktree; then the compiler
runs without `--notes`, the records read "Nothing recorded.", and the
hand-back says the extractor was stopped unfinished. The controller does not
wait at any point. A finished extractor whose file is missing or malformed
is handled by the compiler (Design §2 step 3) and named in the hand-back the
same way.

### 4. Flow under subagent-driven-development

In `skills/subagent-driven-development/SKILL.md`:

**Setup** gains one check beside "read plan and spec": run
`decisions-compile --dry-run <spec>` from the finishing skill's `scripts/`
directory. Exit 0 confirms the spec's decisions parse, and the listing is
kept for the extractor's dispatch. Exit 2 for a missing list is the
legacy-spec case: draft the `## Decisions` list from the spec's own text,
one item per decision it states, show it to your human partner, and write it
into the spec once they approve it; any other exit 2 names a Supersedes
problem to resolve with them the same way. The session is at its start, so
this question costs no cycle time.

**Final Review** gains a dispatch rule. Once the final code-reviewer's
fix wave and its scoped re-review are clean (or the final review returned
no findings), and before the Codex final gate when there is one, take a
scratch directory from `codex-review-dir`, copy the latest review package
and the ledger into it, and dispatch the decision extractor in the
background, composed from the finishing skill's `decision-notes-prompt.md`,
with those copies, the plan, the spec, the dry-run listing, the index when
it exists, and `<dir>/decision-notes.md` as the output path. Record the
dispatch's task id and the output path in the ledger, so the finishing skill
can collect them. The Codex final gate proceeds unchanged; with or without
Codex, the extractor keeps running through the finishing skill's full test
run. This is consistent with the turn-liveness rules: the extractor is
tracked work started through the harness's background option, and the
controller's foreground waits stay on the reviewers, the gate and the
suite.

Nothing is compiled or committed under SDD. When the Codex final gate is
clean, Finish runs as today (the extractor does not read the workspace, so
deleting it is safe), and the hand-off to finishing-a-development-branch
names the spec, the plan, the extractor's task id and its output path, and
one more thing: if a Codex-gate fix changed a decision, the controller
writes that change into the spec's Decisions item before handing off (the
spec is not yet frozen, Decision 4) and commits that edit on the branch as
an ordinary change, so the records describe what ships. The finishing skill compiles and commits
after its full suite passes (Design §5). The process-flow graph gains one
node, "Dispatch decision extractor (background)", after the final fix
wave; `example-workflow.md` gains the matching lines.

### 5. Flow in finishing-a-development-branch

Step 1 becomes **Record decisions and verify tests**:

1. Determine the plan and spec. SDD's hand-off names both; otherwise
   discover them from the branch's history, not its tree, so a plan the
   records commit already removed is still found:
   `git log --diff-filter=A --name-only --format= <merge-base>..HEAD -- '*/plans/*.md'`.
   Exactly one plan is the plan, and its `**Spec:**` header is read from
   the commit that added it (`git show <sha>:<path>`); more than one, ask
   your human partner which applies; a plan without a Spec header, or with
   `none`, is asked about the same way. No plan in the branch's history:
   when the branch's history added or changed a spec
   (`--diff-filter=AM -- '*/specs/*.md'`), ask whether records are wanted
   for it; when it did neither, the work is bounded, skip to the test run.
2. Run `decisions-compile --dry-run <spec>`. Exit 2 for a missing list is
   the legacy-spec case: draft the list from the spec's own text, get your
   human partner's approval, write it. Any other exit 2 is resolved with them
   before going on.
3. If SDD handed over an extractor (a task id and an output path), there is
   nothing to dispatch. Otherwise, unless the branch already carries this
   spec's records commit
   (`git log <merge-base>..HEAD --grep='^docs: record decisions for '` names
   it), take a scratch directory from `codex-review-dir` and dispatch the
   extractor in the background with the merge-base diff and
   `<dir>/decision-notes.md` as the output path. Then run the full test
   suite in the foreground as today.
4. If the suite fails, report the failures and stop, as today; nothing is
   compiled and the plan stays (an extractor still running is stopped). If
   it passes, collect without waiting (Design §3) and run
   `decisions-compile <spec> --plan <plan> [--notes <file>]`. On exit 2,
   resolve the named problem and re-run; on exit 3, report the git failure
   and re-run once it is cleared. The compiler is idempotent, so a branch
   that already has records gets its notes refreshed or nothing changed.
   Pass `--paths-file <scratch dir>/records.paths`. Nothing is committed
   here; the staged set waits for Step 4.
5. Continue with Step 2 exactly as today.

**Step 4** (the options menu) gains a preface when Step 1 staged records:
the message that presents the options opens with the complete staged diff
(`GIT_LITERAL_PATHSPECS=1 git diff --cached -- <paths>`), then the extractor's proposals, each with
the question it needs (an undocumented decision: add it to the spec's
Decisions list, or dismiss; a proposed supersession: add a `Supersedes:`
line to the item that reverses the record, or dismiss), then a line
offering to skip the records for this branch, and only then the menu text
exactly as written today. Your human partner answers once. Before executing
their option: an accepted proposal is written into the spec and the
compiler re-run, and because the staged set changed, the new complete
staged diff is shown once more and their approval asked once more; a
dismissal is recorded in the hand-back in their words; a skip is
`decisions-compile --undo`, recorded in their words. Then the records
commit is made (Design §2, "The commit"), and the chosen option runs as
today.

The records commit therefore follows the human partner's approval of its
complete diff and precedes any merge or push, so merge, pull request and
keep-as-is all carry it. The Common Rationalizations table gains one row:

| "I'll record the decisions after the merge" | The records ride the branch. After the merge the plan is gone from the tree and the diff review is over. Record first, then present the menu. |

### 6. Skill text changes

- **brainstorming**, `skills/brainstorming/SKILL.md`. Under "Understanding
  the idea", after "Check out the current project state first": read the
  decisions index at the `decisions/README.md` sibling of the specs
  directory this session will write to (`docs/hyperpowers/decisions/README.md`
  by default) when it exists, and treat each current decision as a
  constraint; a design that reverses one says so in its spec item with a
  `Supersedes:` line. Under "After the Design", Documentation: the spec
  carries a `## Decisions` section in the shape of Design §1, required.
- **writing-plans**, `skills/writing-plans/SKILL.md`. One sentence beside the
  existing grounding rule: a correction paragraph added during execution
  that alters a decision names it, `Correction (<date>), decision <N>
  (<title>):`.
- **subagent-driven-development**: Design §4.
- **finishing-a-development-branch**: Design §5, plus the new `scripts/` and
  prompt file.
- **executing-plans**: no change; it ends in finishing-a-development-branch.

Voice and tuned content: the additions use "your human partner"; no Red
Flags table or rationalization list is reworded, one row is added to the
finishing skill's table.

### 7. Allowlist and repository text

- `skills/writing-plans/scripts/docs-allowlist` writes `!/decisions/` after
  `!/plans/`; its test asserts `decisions/x.md` is not ignored.
- `docs/hyperpowers/.gitignore` in this repository gains `!/decisions/`.
- `CLAUDE.md`, "Planning and Spec Docs Are Tracked Here": specs are
  committed and content-frozen with an Outcome line; decisions live under
  `docs/hyperpowers/decisions/` and are the first thing a design session
  reads; plans are committed while the work is in flight and removed at
  finish; the allowlist sentence names the three directories.
- `docs/testing.md`: the new suite in the `tests/claude-code/` row and the
  offline-set count.

### 8. Harness scope

Background dispatch exists on Claude Code in both of its subagent modes:
with the `run_in_background` parameter (print and SDK sessions, Zed) and
without it (fork mode, where every subagent is asynchronous). The task stop
exists in both. On a harness without a tracked background subagent, SDD and
the finishing skill run the compiler without notes and say so in the
hand-back; no foreground extraction is run anywhere, because the human
partner's constraint is no added time. The compiler and the record format
are harness-independent.

## Verification

### Offline (all numbered items are the gate)

`tests/claude-code/test-decisions-compile.sh`, one `bash` call, temp
repositories, no network:

1. Numbered items with bold titles produce one record each with the bold
   text as title; bulleted items with bold labels likewise; plain bulleted
   items are titled by their first clause.
2. Each heading variant seen in the field is found, and the first match
   wins when two headings qualify: `## Decisions`, `## 2. Decisions`,
   `## Key decisions (resolved during brainstorming)`,
   `## Decisions taken with the human partner`, `## 2. Locked decisions`.
3. Nested bullets stay inside their parent item's decision text, with the
   indentation normalisation of Design §1.
4. A section with prose and no list items exits 2 with the documented
   message and writes nothing.
5. A record's content matches a golden file byte for byte, including the
   `Recorded:` line in each of its three forms.
6. A valid `Supersedes:` in an item flips the named record's status; a path
   that does not exist, a record already superseded by an unrelated record,
   and a record of the same spec each exit 2 and no file in the directory
   changes; duplicates in one item collapse; two items of one spec naming
   the same target leave that target's status listing both, sorted, after
   one run.
7. Notes are matched by decision number; a decision without notes reads
   "Nothing recorded."; a notes file with a duplicate section, a bad
   heading, or an out-of-range number is reported as `notes ignored:` on
   stderr and the run succeeds without notes; undocumented lines and
   proposed supersessions are counted in the summary and absent from
   records.
8. A second run with the same inputs changes nothing and prints an empty
   `paths:` line; this holds for a spec with a `Supersedes:` line (the
   target already superseded by this record passes validation) and after
   the first run's plan removal was committed (`git rm` is not attempted and
   the plan is absent from `paths:`); a second run with new notes changes
   only the notes sections and `Recorded:` lines; a second run without notes
   leaves recorded notes alone; a run after a decision item was added writes
   the new record and rewrites the Outcome count; a run after an existing
   item's text changed refreshes that record's title and decision body and
   keeps its filename and `Recorded:` date.
9. Two decisions in one spec with the same title produce `<slug>.md` and
   `<slug>-<N>.md`; two specs with the same date and title likewise; a third
   collision exits 2.
10. The index lists current records newest first, counts match, the
    Superseded table appears only when non-empty, and a title containing
    `|`, `[` and `]` renders escaped.
11. The Outcome line is inserted once, after the title, and a second run
    does not duplicate it; a spec without a title gets it as its first line.
12. With `--plan`, the plan's removal is staged; records, index and spec are
    staged; `git log` shows no new commit; a commit from the `--paths-file`
    leaves an unrelated staged change staged and includes a record whose
    spec path contains a space; a re-run while that deletion is staged
    succeeds and keeps the plan in `paths:`.
12a. `--undo` after a staged run restores the spec and the plan, deletes the
    new records and the new index, restores a superseded record's status,
    and leaves an unrelated staged change staged; the tree and index equal
    their pre-run state.
13. With git made to fail at each operation of step 8 in turn, the exit is
    3, the written files are present, a second run completes the staging,
    and its `paths:` line carries every file the failed run had already
    staged, so the pathspec commit commits them all.
13a. A run on a later day (`DECISIONS_COMPILE_DATE` advanced) after an
    unchanged spec changes nothing; after an added decision it rewrites the
    count and keeps the original Outcome date and every record's original
    `Recorded:` date.
13b. The finishing flow re-run after a committed plan removal: discovery
    through `git log --diff-filter=A` still finds the plan and its Spec
    header, the compiler changes nothing, and the pathspec file is empty.
14. `--dry-run` leaves the tree hash unchanged and prints the numbered
    listing and the `paths:` line.
15. `--reindex` rewrites only `README.md`.
16. `tests/claude-code/test-docs-allowlist.sh` asserts `decisions/x.md` is
    not ignored and `git add -A` stages it.
17. `shellcheck -x` over the compiler and both tests is clean; the packaging
    suites (frontmatter, orphaned files) pass, so the new prompt file has an
    inbound reference.

### Parser dry run

`decisions-compile --dry-run` over each of this repository's 16 specs with a
Decisions section, before the skill text ships. Recorded as a table (spec,
items found, titles) in the evidence note; the 4 prose-only specs are
expected to exit 2. Any title that reads wrong is a parser fix, not a spec
edit.

### Live

The first SDD run after this lands, in Claude Code: the dry run at Setup,
the extractor dispatched in the background at its Final Review point,
Finish deleting the workspace while it runs, the finishing suite, the
collection without a wait, the compiler, the records commit, and the
finishing menu message carrying the diff and the proposals. A second
run with the extractor deliberately slowed (a prompt that asks it to read
the whole plan twice) exercises the stop at collection and a Finish that
deletes the workspace afterwards. The branch's commit list and the records are
the evidence, noted in
`docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md` with the
elapsed time between the Codex gate's end and the records commit. One
finishing-skill path (a branch without SDD) is exercised the same way. One
run in Zed confirms the background dispatch is collected there.

## Files

- `skills/finishing-a-development-branch/scripts/decisions-compile` (new)
- `skills/finishing-a-development-branch/decision-notes-prompt.md` (new)
- `skills/finishing-a-development-branch/SKILL.md` (Step 1, the Step 4
  preface, one table row)
- `skills/subagent-driven-development/SKILL.md` (Setup check, Final Review
  dispatch rule, the hand-off to finishing, one graph node)
- `skills/subagent-driven-development/example-workflow.md`
- `skills/brainstorming/SKILL.md` (two additions)
- `skills/writing-plans/SKILL.md` (one sentence)
- `skills/writing-plans/scripts/docs-allowlist` and
  `tests/claude-code/test-docs-allowlist.sh`
- `tests/claude-code/test-decisions-compile.sh` (new)
- `docs/hyperpowers/.gitignore`, `CLAUDE.md`, `docs/testing.md`
- `docs/hyperpowers/2026-10-21-decision-records-eval-evidence.md` (new, at
  the end)

## Constraints

- The compiler uses git, awk, sed, date and POSIX coreutils only; no
  Python, no Node, no network, no third-party tool. BSD and GNU variants
  behave the same for everything it uses.
- The compiler validates everything before its first write, writes
  idempotently, stages last, and never commits.
- The extractor writes exactly one file and never line numbers.
- Nothing waits on the extractor.
- Skill voice is "your human partner"; no tuned table is reworded.
- No AI-attribution lines in any commit, including the records commit.
- The allowlist change already in the working tree is committed before this
  branch is created.
- Nothing here depends on the portable-dossiers work or changes the SDD
  workspace layout.

## Out of scope

- Backfilling records for existing specs and removing existing plans
  (Follow-ups; the compiler makes it a one-shot job when wanted).
- A plan-length ceiling in writing-plans (postponed by the human partner).
- Moving plans to the dossier state branch.
- Removing the existing `docs/hyperpowers` ignore entries in other
  repositories.
- Excluding `tests/` from the plugin install worktree.
- Provenance of individual edits (the DeltaDB problem).

## Known limits

- Notes describe the diff as it stood when the extractor started, which
  under SDD is after the final review's fix wave and before the Codex final
  gate; a change made by a Codex-gate fix is not in them. Such fixes answer
  gate findings; when one reverses a decision the controller writes the
  change into the spec's item before the hand-off (Design §4).
- Two branches that both regenerate `README.md` conflict on merge: resolve
  with either side and run `decisions-compile --reindex <dir>`. Two branches
  that create the same record filename for different identities conflict as
  add/add: keep both files, rename one with its decision-number suffix,
  reindex.
- A squash merge keeps only the records; the plan's history is gone with the
  branch (Decision 3).
- Bounded work has no spec and leaves no records; a branch that changed a
  spec without adding a plan gets records only if the human partner says
  so when asked.
- An extractor stopped at collection has done its reading for nothing; the
  records carry "Nothing recorded." and the human partner can add notes by
  hand to the record before the menu, since a record is an ordinary file
  until it is committed.
- A decision the spec never listed reaches a record only through the
  human partner's disposition of an "Undocumented decisions" proposal.
- The compiler is deterministic over the list it finds; a legacy Decisions
  section whose items mix decisions with status notes produces records for
  the notes too unless the list is cleaned at the Setup check.
- The Outcome line and the one-time legacy list are the only edits the
  design makes to a spec; a spec whose title is not its first line gets the
  Outcome line as its first line.

## Assumptions

- Assumption: a background subagent's completion is delivered while the
  controller is in a foreground wait on another subagent or a Codex gate,
  and its result is readable afterwards; validate via the live SDD run.
- Assumption: Zed's ACP front end runs and collects a `run_in_background`
  subagent the same way the terminal's fork mode collects its default
  asynchronous dispatch, and the task stop ends an unfinished extractor in
  both; validate via the Zed run and the slowed-extractor run in the Live
  section. The two modes were established on 2026-10-21 (Claude Code
  2.1.302: interactive sessions omit the parameter, SDK sessions honor it,
  `CLAUDE_CODE_FORK_SUBAGENT=0` restores it); this design works in either,
  since it only ever wants the background.
- Assumption: the 12 list-shaped Decisions sections in this repository
  parse into titles a reader would accept; validate via the parser dry run.
- Assumption: a mid-tier model produces usable implementation notes from
  the review package and the plan's corrections within one Codex-gate
  round; validate via the live run (the elapsed time recorded there), and
  escalate the tier in the prompt's dispatch guidance if it does not.

## Follow-ups

- Backfill: run the compiler over this repository's 12 parseable specs in
  one commit, write lists for the 4 prose-only ones, and remove their
  plans. Human partner's call after the live run.
- Other repositories: opting in means removing the ignore entry and running
  `docs-allowlist`; the existing uncommitted plan directories there (643
  plans) are untouched until then.
- `~/.codex/AGENTS.md` still carries the removed no-commit rule on two
  lines; Codex reviews read it.
- `tests/` out of the plugin install worktree, and the three stale plugin
  cache copies under `~/.claude/plugins/cache`.
- A plan-length ceiling, when the human partner reopens it.
