# Skills read-efficiency: splitting the Codex review gate

**Date:** 2026-08-23
**Status:** Design, approved in chat, not yet planned
**Scope:** `skills/requesting-code-review/`, with a follow-on phase touching
`skills/brainstorming/` and `skills/subagent-driven-development/`

## Problem

`skills/requesting-code-review/codex-review-gate.md` is 766 lines / 49,168
bytes. Across 96 real agent sessions (2026-06-26 to 2026-08-23, excluding the
two audit sessions that produced these numbers) it was opened **970 times**,
returning ~2.1M tokens — **66% of all measured skill-document read cost in the
package**.

The pathology is not its size but *how* it is read:

| Read shape | Count | Share |
|---|---|---|
| `sed` range slice | 489 | 50.4% |
| `grep` | 238 | 24.5% |
| `Read` with offset/limit | 103 | 10.6% |
| `Read` whole | 101 | 10.4% |
| `cat`/`wc` | 21 | 2.2% |
| `head`/`tail` | 13 | 1.3% |

**87% of opens are partial reads**, and the most frequent slices are all
head-of-file (`1,80p` ×26, `1,120p` ×22, `1,60p` ×15) — repeated re-orientation
in a long document with no contents listing. About 88% of opens are redundant
re-opens within a single session.

Two second-order costs follow:

1. **Incomplete information.** The Agent Skills guidance warns that partial
   reads yield partial understanding. Callers are told to go read a *specific
   numbered section*, so they slice — and a slice can miss the invariant that
   governs it.
2. **Permission friction.** Navigation commands take the shape
   `SK="${CLAUDE_PLUGIN_ROOT:-...}/skills/requesting-code-review"; sed -n '/## 5/,/## 7/p' "$SK/codex-review-gate.md"`.
   The host sandbox allowlist matches per-subcommand and cannot resolve shell
   variables, so every such navigation raises an interactive approval prompt.

The file is **fork-only** (absent from upstream base `b36e082`), so
restructuring it carries zero merge cost.

## Scope

**In scope — Phase A:** split `codex-review-gate.md`.

**In scope — Phase B (eval-gated):** flatten the brainstorming reference chain;
split `subagent-driven-development/SKILL.md`.

**Explicitly out of scope,** each cut on evidence during design:

- **TOCs on reference files over 100 lines.** Nineteen candidates were measured.
  Fourteen have 0-1 organic opens. The remaining four
  (`task-reviewer-prompt.md` 171 opens, `implementer-prompt.md` 111,
  `code-reviewer.md` 68, `re-review-prompt.md` 23) are read **whole** 69-85% of
  the time — they are prompt files handed to subagents intact, which is correct
  behavior. A TOC would be paid on every whole read to serve a handful of
  slices, and all four are upstream files, so it would create merge-conflict
  surface on every future sync for no measured benefit. **Zero valid targets.**
- **Dropping dead files from the shipped package.** There is no `files` field in
  `package.json` and no `.npmignore`, so nothing short of deletion excludes a
  file. Unread files cost zero context, and the seven candidates are upstream's,
  which the merge policy says not to delete. **No mechanism, no benefit.**
- **Wiring `requesting-code-review` to `receiving-code-review`.** The skill has
  **0 opens** — empirically it never fires. That makes it a coverage gap, not an
  efficiency defect: fixing it would make a dormant 205-line skill start
  running, *increasing* token cost. Tracked separately as a quality fix so a
  token regression cannot hide behind an efficiency banner.

## Merge policy

Data-driven hybrid, chosen by the maintainer:

- Fix fork-only files freely.
- Touch upstream files **only** where the logs show real reads.
- Skip cosmetic edits on upstream files with zero opens.
- Do not delete upstream files.

## Phase A — split the gate

### Approach

A section library behind a dispatcher index. `codex-review-gate.md` **stays at
its current path** and becomes a ~40-line index; the content moves to nine
siblings. Because the path is unchanged, **every inbound reference keeps
working with zero caller edits** — five markdown links across five skill files,
plus two prose call sites that name no path — which is what keeps Phase A behavior-neutral
and free of any *new* eval authoring. (Two existing scenarios are still re-run
as a release gate — see Verification.)

Two other shapes were considered and rejected: per-call-site capsules (best
ergonomics, but duplicates the fix loop, severity mapping, and completion check
across five files — the exact invariants that 6.9.1 shipped fixes for), and
generated views from canonical fragments (solves drift, but adds build
machinery to a dependency-light repo and creates a generated-vs-hand-edited
contributor trap).

### File layout

| New file | Source lines | Approx. lines |
|---|---|---|
| `codex-review-gate.md` (index) | 1-10 preamble + new routing table | ~40 |
| `gate-preflight.md` | 11-100 (§1, §2) | ~90 |
| `gate-setup.md` | 101-176 (§3 shared) | ~76 |
| `gate-output-schema.md` | 357-393 (§3 required output shape) | ~37 |
| `gate-lenses.md` | 177-219 (§3 lens fan-out) | ~43 |
| `recipe-document.md` | 220-272 (§3 spec/plan recipes) | ~53 |
| `recipe-code.md` | 274-355 (§3 code discipline + recipes) | ~82 |
| `gate-findings.md` | 394-541 (§4, §4b) | ~148 |
| `gate-fix-loop.md` | 542-690 (§5, §6) | ~149 |
| `gate-sweep.md` | 691-766 (§7) | ~76 |

Nothing lands over 150 lines. No single file is self-sufficient — completeness
is a property of the *route*, not of one file (see Index contract).

### Why these seams

**§3 splits document-vs-code, not five ways.** The text already carries that
seam: line 359 reads "For spec and plan reviews, require this exact shape"
(spec and plan share the output block) and line 274 reads "The three code
recipes below all use `adversarial-review`" (task, final, and ad-hoc share the
entire detached-launch and watch discipline). A five-way split by call site
would copy that discipline into five files, reintroducing the duplication risk
that ruled out the capsule approach.

**The output schema is its own file because three consumers share it.** The
"Required document-review output" block (357-393) is not document-only despite
its heading: `gate-lenses.md` embeds it verbatim in every lens prompt
(line 196), the lens skeleton routes code and final gates to it as a `summary`
field (line 199), and its own closing paragraph (390-392) is a *code*-recipe
instruction — "For code recipes, prefer `--json` and read the structured
`result` payload." Filing it under `recipe-document.md` would strand a code
instruction in the document file and force a cross-file hop from the lens
skeleton. As its own early-read file it serves all three consumers with no hop.

**Small sections merge with their consumer.** §2 (14 lines) joins §1 because
`codex-approach-gate.md` uses them as a unit — that caller's entire need becomes
one file. §4 (12 lines) joins §4b because the completion check is what consumes
the severity ladder. §6 (24 lines) joins §5 because hand-back is the loop's
terminal step.

**The preamble stays in the index.** Lines 1-10 carry the gate's framing and the
**Claude Code only** precondition. Every caller needs that before anything else,
so it belongs in the file every caller still reaches first.

### Index contract

The index is a dispatcher, not just a table of contents. It carries:

1. The preamble and the Claude Code-only rule, verbatim.
2. A one-line description of each sibling file.
3. **A complete route per caller.** Not an example — the full matrix:

| Caller | Route (files, read as a set) |
|---|---|
| approach gate (`codex-approach-gate.md`) | `gate-preflight` |
| spec gate (`brainstorming/SKILL.md:286`) | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-document`, `gate-findings`, `gate-fix-loop` |
| plan gate (`writing-plans/SKILL.md:181`) | same as spec gate |
| per-task gate (`subagent-driven-development/SKILL.md:450`) | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-code`, `gate-findings`, `gate-fix-loop` |
| final whole-branch gate (`subagent-driven-development/SKILL.md:584`) | same as per-task gate |
| ad-hoc code review (`requesting-code-review/SKILL.md:52`) | same as per-task gate |
| review sweep (`hooks/session-start:73`) | `gate-preflight`, `gate-sweep`, plus the route for the gate type each queued event records |

The approach gate's route is a single file — that caller's entire need is §1+§2,
which is why they were merged. The sweep's route is deliberately conditional:
it dispatches by recorded gate type, so it inherits that type's route.

**Two callers reach the gate without a markdown link, and the matrix must not
lose them.** `subagent-driven-development/SKILL.md:584` invokes the final
whole-branch gate in prose ("run the gate using the final whole-branch code
recipe"), relying on the linked reference at :450 earlier in the same file. The
review sweep has no skill link at all: its entry point is the session-start
hook's "say `run the review sweep`" prompt, and the agent reaches §7 by opening
the gate document directly. Both still land on the unchanged index path, so both
keep working — but a `grep` for the filename finds five sites, not seven. The
topology test asserts against the seven-row matrix, not against a grep.

**Completeness, not ordering, is what removes the hops.** The document's
internal §-reference graph is cyclic — §3 references §5's round counter and
§4b's recovery path, while §4b references §3's watch loop in six places and §5
references §3's prompt and `GATE_DIR` — so no topological read order exists. A
route is therefore specified as a *set* read up front, with a suggested
sequence for readability only. Because every file in a caller's route is loaded
before the caller acts, each §-reference resolves against content already in
context, and no file ever has to send the agent somewhere to continue.

This is also why section files may not *link* to each other: a link invites a
just-in-time hop, and the cycles guarantee some of those hops would be circular.
Naming a file that the route already delivered is not a hop and is permitted;
instructing the agent to go read one is forbidden.

### Invariants of the move

- **Content is moved verbatim, with one enumerated class of exception.** Every
  non-blank source line lands in exactly one destination file, byte-for-byte,
  except the cross-file positional references defined below. No other
  rewording, no consolidation, no incidental edits. The repo rule against
  retuning behavior-shaping content without evidence applies.
- **Blank separator lines are not tracked.** Source lines 273 and 356 are blank
  separators between sections and are dropped or recreated as formatting
  requires. The line-accounting check (below) covers non-blank lines only.
- **Section numbers stay in the headings.** `gate-preflight.md` keeps
  `## 1. Preflight availability`. Four inbound callers address sections by
  number (`codex-approach-gate.md:11` says "Run the §1 preflight"); keeping the
  labels means those instructions read correctly both today via the index and
  after Phase B repoints them.
- **Section files may not link to each other.** Cross-references stay as
  §-numbers in prose. The index is the only router.

#### Positional references

**The rule:** a reference is rewritten to name its destination file if and only
if its referent lands in a *different* file. Everything else stays byte-exact.
A rewritten reference names a file the route already delivered; it never
instructs the agent to go read one.

**Three classes exist, and the middle one is easy to get wrong.** The source
contains 19 lines using "below"/"above":

| Class | Lines | Disposition |
|---|---|---|
| Referent crosses into another file | 106, 130, 131, 133, 218, 229, 244 | **rewrite** |
| Referent stays in the same file | 153, 161, 191, 275, 429, 443, 558, 631 (×2), 645 | verbatim |
| Prompt literal — "below" describes the *generated prompt's* layout, not the source document | 195, 233, 248 | verbatim |

The prompt-literal class matters because those lines look like breakage and are
not. Line 195 tells Codex "Return exactly the Required document-review output
below", and line 196 pastes that block directly beneath it *inside the generated
prompt*. The reference is correct in the artifact that actually gets sent.

**One breaking reference contains no "below" at all.** Line 196,
`<the existing Required document-review output block, verbatim>`, is a composer
instruction pointing at content that moves to `gate-output-schema.md`. It is the
eighth rewrite, and it is the reason the inventory cannot be built by grepping
for "below" alone.

**The inventory is derived, not asserted.** Two manual passes over this file
each produced a wrong list — the first omitted lines 153, 161, 233, and 248; the
second misclassified 195 as breaking and missed 196 entirely. The plan therefore
generates the inventory mechanically as its first implementation task: for each
reference, resolve the referent's source line, map it through the file-layout
table, and flag it when the destination differs. The table above is the expected
output of that generation and a fixture to check it against — not a substitute
for running it.

The line-accounting check treats exactly the generated rewrite set as permitted
deviations and requires a byte-exact match everywhere else.

### Accepted trade-off: reference depth

In Phase A the section files sit two levels from SKILL.md, which is the nesting
the authoring guidance warns about. This is deliberate. The warning exists
because agents partially read nested files — and the measured partial-read rate
on the current single file is already 87%. Trading "two levels, 766-line target"
for "two levels, sub-150-line targets" is strictly better on the exact axis the
guidance cares about, and it costs no caller edits. Phase B item 4 repoints
callers at the section files and collapses this to one level.

## Verification

### Losslessness — line accounting (the actual proof)

A new check, run once against the pre-split file captured at a pinned commit:

1. **The declared source ranges tile the original exactly.** Ranges from the
   file-layout table must cover lines 1-766 with no gaps and no overlaps, blank
   separators excepted.
2. **Each destination matches its declared slice byte-for-byte**, except the
   eight enumerated positional-reference lines, which are compared against
   their specified rewrites.

This is what proves losslessness. It catches dropped lines, reordering,
duplication, and silent rewording — none of which the contract test can see.

### Behavior pinning (contract test)

`tests/codex-review-gate/test-gate-contract.sh` holds **96 golden-text
assertions** against the gate document (89 `assert_contains`, 7
`assert_not_contains`) pinning preflight statuses, the incomplete-is-not-approval
rule, severity mapping, round accounting, and backstop language. `$GATE` becomes
a temp file built by concatenating the index plus all nine siblings, and all 96
assertions run unchanged. `assert_not_contains` holds under concatenation:
absent from every part means absent from the whole.

**This is a behavior guard, not a losslessness proof, and the distinction
matters.** `assert_contains` collapses newlines, tabs, and repeated spaces
before matching selected substrings (`test-gate-contract.sh:18-31`). It would
still pass after whitespace changes, section reordering, content duplication, or
the loss of any line no assertion happens to pin. Line accounting above is what
proves the move; these 96 assertions prove the invariants that matter most are
still stated somewhere in the gate.

Retargeting the 96 assertions by hand is explicitly rejected — it is
error-prone, and it would let a reworded line pass as an intentional test edit.

### Second existing test in the blast radius

`tests/claude-code/test-codex-review-dir-path.sh:20` also targets
`codex-review-gate.md` directly and greps it for `scripts/codex-review-dir`.
That text moves to `gate-setup.md`, so the test would fail — or worse, pressure
an implementer into duplicating the line back into the index to make it pass.
It is retargeted to the same assembled-gate temp file as the contract test.

Both test files are in scope for Phase A. There is no third: a repo-wide grep
confirms these two are the only tests referencing the document.

### Placement (mechanical)

Concatenation alone would also pass if all content were dumped into one sibling.
Nine new assertions — one per sibling — pin a distinctive string to its file
(preflight statuses in `gate-preflight.md`, the severity ladder in
`gate-findings.md`, the detached-launch discipline in `recipe-code.md`, and so
on). Together the two sets prove nothing was lost *and* that the split happened.

### Topology (mechanical)

A new test asserts:

- Every sibling file is linked from the index.
- Every index link resolves to an existing file.
- No section file links to another section file.
- **Every route in the index's caller matrix names only existing files**, and
  all seven callers have a named route. This is what stops the matrix from
  silently going stale when a file is added or renamed. Assert against the
  seven-row list, not against a filename grep — two of the seven call sites name
  no path, so a grep-derived expectation would under-count to five and pass
  while the matrix rots.

### Live evals (required, but no new authoring)

Two existing scenarios run before and after as a release gate:
`codex-gate-lens-fanout-compliance` and `codex-gate-incomplete-not-approval`.
Pass criterion is unchanged verdicts across the pair.

To be unambiguous about the acceptance bar: **Phase A authors no new eval
scenarios, and it is not exempt from evals.** Earlier framing called Phase A
"eval-free," which conflated those two things.

### Post-release measurement (cannot gate)

Codex's "agents keep slicing out of habit" risk is only observable in
production. After real use, re-run the read-shape measurement and confirm:

- Partial-read rate on the new files is well below the current 87%.
- No `sed -n '/## /,/## /p'` or equivalent section-slice patterns against the
  new filenames.

This is a follow-up measurement recorded in the plan, not a merge gate.

### Risks not mitigated, and why

Codex flagged invariant divergence across split files. That risk arises from
**duplication**, and Phase A duplicates no gate content — every non-blank line
lands in exactly one file. The only new duplication is the index's routing
knowledge, covered by the topology test. No further mitigation is imported for a
risk that is not present.

One duplication pressure is worth naming because it is how this invariant would
actually break: a failing test that greps the index for text now living in a
sibling invites an implementer to paste the line back into the index. Both
known instances are handled by retargeting the tests to the assembled-gate view
rather than by duplicating content, and the line-accounting check would fail if
anyone did the latter.

## Phase B — eval-gated

Ordered by cost. Both items are gated by live evals per the maintainer's
instruction.

### Item 4 — flatten the reference chain (do first)

Phase A makes this nearly free. `codex-approach-gate.md` is **fork-only**, and
after the split its only dependency is `gate-preflight.md` — exactly the §1+§2
content it already cites. Repointing it collapses the chain
`brainstorming/SKILL.md -> codex-approach-gate.md -> codex-review-gate.md` from
three levels to two, and shrinks its terminal target from 766 lines to ~90.

The second edit, `brainstorming/SKILL.md:286`, is a one-line link change on an
upstream file: minimal conflict surface, and justified because the link is on
the live path regardless of manual-read counts.

**Eval gates:** `codex-approach-gate-fires-on-architecture`,
`codex-gate-spec-degrades-without-codex`.

### Item 6 — split `subagent-driven-development/SKILL.md`

706 lines, upstream, **71 manual re-reads** at roughly 7.5k tokens each. Because
SKILL.md content is injected by the harness on skill trigger rather than read as
a file, those 71 opens are cases where the agent already had the content and
went back for it anyway — a sharper signal than a plain read count, and it
clears the policy bar for touching an upstream file.

This is the highest merge-conflict surface in the program and must go last.

`## The Task Loop` is 295 of the 706 lines and **stays inline** — it is the core
of the skill. Extraction candidates, sized to bring SKILL.md under the 500-line
guidance: `## Model Selection`, `## Risk Tiers`, `## Example Workflow`,
`## Common Rationalizations`. `## Common Rationalizations` is tuned
behavior-shaping content; if it moves, it moves verbatim.

**Eval gates:** `sdd-unified-fix-loop`, `sdd-plan-scoped-scratch`,
`sdd-rejects-extra-features`.

## Measurement caveats

- SKILL.md open counts are **manual re-reads only**; harness injection on skill
  trigger is not a file read and is not counted.
- All counts exclude the two audit sessions that produced this analysis.
  Including them inflates `codex-review-gate.md` from 970 to 993 opens and gives
  several zero-open files a spurious count of 1-2.
- Token figures are character-count/4 approximations from `tool_result` payloads
  matched to their originating `tool_use` id, not billed token counts.

## Non-goals

- Rewording, tightening, or otherwise improving any gate content. This program
  moves text and changes routing.
- Changing gate behavior: same preflight, same lenses, same severity ladder,
  same round accounting, same backstops.
- Any change to the eleven helper scripts in
  `skills/requesting-code-review/scripts/`.
- Upstream contribution. The primary artifact is fork-only.
