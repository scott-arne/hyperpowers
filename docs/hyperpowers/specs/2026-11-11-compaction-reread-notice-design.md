# Compaction Re-read Notice: Design

Date: 2026-11-11, revised 2026-11-12. Status: revised after the campaign
stopped; the section "Revision (2026-11-12): a compact SDD controller"
governs wherever it differs from the Design and Testing sections. This
design is the
compaction-loss slice that decision 2 of the SDD dispatch guard spec
(`2026-11-10-sdd-dispatch-guard-design.md`) deferred. A new measurement
changes its premise, so it supersedes that decision and changes the plan:
the slice adds one notice to `hooks/session-start` and evaluates it, instead
of building an eval that reproduces the field rate.

## Problem

After a compaction, Claude Code re-attaches each invoked skill cut to its
first 20,000 characters. SDD's SKILL.md is 76,445 characters on `main`;
brainstorming (25,789), finishing-a-development-branch (29,579) and
writing-skills (26,221) are also over the cap. Since 6.16.2, SDD and
brainstorming carry a paragraph near the top ("After every context
compaction") telling the agent to Read the whole file after every
compaction. The 6.16.2 eval measured it at 148 of 151 compactions for SDD.

The dispatch guard spec reported the field rate as 16 of 63: across the SDD
sessions with compactions since 2026-11-04, the controller read SKILL.md in
full before its next dispatch after 16 compactions, part of it after 13, and
not at all after 34. Its decision 2 read that as "every SKILL.md rule past
character 20,000 is mostly unfollowed after a compaction" and asked for an
eval that reproduces the rate.

A per-compaction scan of the same transcripts on 2026-11-11
(`~/.cache/hyperpowers/zed-idle-2026-11-10/characterize.py`, 77 compactions
since 2026-11-04 followed by a dispatch, window extended to 2026-11-12) finds
that the paragraph was missing from most of them:

- In 60 of the 77, the re-attached SDD copy has no re-read paragraph. Only
  13 of those 60 got a full re-read.
- With the paragraph present (17 compactions, in sessions `10a3c85d`,
  `15809a43` and `37d62a37`), the controller made 13 full reads and 2 reads
  from line 150 or 200 to the end, which restore the cut text and which the
  6.16.2 eval credited. It made no read in 2 cases, both in `15809a43`, 94
  and 150 turns before the next dispatch. That is 15 of 17, against the
  eval's 148 of 151.

The paragraph was missing for two reasons:

- A Claude Code session keeps the skill text it loaded at process start,
  across later Skill invocations and plugin checkouts. Session `ec562ba3`
  loaded SDD on 2026-10-21 under 6.16.1, which has no paragraph. It invoked
  SDD again on 2026-11-10, while `plugin-install` was on v6.17.0, and every
  re-attached copy through 2026-11-11 was still the 6.16.1 text.
- `plugin-install` sat on two `sdd-stop-guard` branch commits without the
  paragraph (`4a4f354c`, `36a62559`) from 2026-11-04 18:58 to 2026-11-06
  12:38 local time. Sessions `db6a4097` and `37d62a37` loaded SDD then.

So the low field rate measures stale skill text, and an eval that reproduced
it would reproduce a plugin-version artifact. The real problem is narrower
and is not specific to SDD: a long-lived session, as Zed sessions routinely
are (`ec562ba3` ran for three weeks), works from skill text that can be
several releases old, and no change to a skill file reaches it.

Hook scripts are the exception. Claude Code runs a hook command from disk on
every event, so a session that loaded old skill text still runs the current
`hooks/session-start`. The existing compaction notice in that hook (spec A9
of the portable dossiers design) reached `ec562ba3` at 16:55Z on 2026-11-10.

## Decisions

1. **The field rate measured stale skill text; this slice adds a notice and
   evaluates it.** In 60 of 77 field compactions the re-attached SDD copy
   lacked the re-read paragraph, because the session had loaded a version
   without it; with the paragraph present the field re-read the cut text
   after 15 of 17 (human partner, 2026-11-11). Rejected: the eval decision 2
   asked for, which would reproduce a plugin-version artifact and measure no
   compliance problem; closing the slice with no change and re-measuring
   after sessions restart, because stale text recurs after every release and
   the field shows sessions running for weeks.
   Supersedes: docs/hyperpowers/decisions/2026-11-10-this-slice-fixes-turn-liveness-the-compaction-loss-is-the.md

2. **The re-read instruction goes in the `session-start` compaction notice.**
   The hook runs from disk on every compaction, so its text is current even
   in a session holding old skill text, and its output is injected verbatim
   into the resumed context. Rejected: stronger or earlier SKILL.md text,
   because a stale session never sees an edited skill file; a plugin
   PreCompact hook, because its output feeds the model-written summary and
   was dropped on 2026-11-04 for lack of evidence of wrong actions after
   compaction.

3. **The notice prints on every compaction, conditional in its text on
   following a skill.** It does not depend on an SDD ledger or a git
   repository. Brainstorming and finishing sessions are cut short too, and
   stale text affects every hyperpowers skill a long session loaded
   (human partner, 2026-11-11). Rejected: appending it to the ledger notice
   only, which covers SDD and leaves stale brainstorming and finishing
   copies without help.

4. **The re-read paragraphs in SDD and brainstorming stay unchanged.** They
   are tuned text, the 6.16.2 eval measured them, and they still serve a
   harness that does not run the hook. Rejected: removing them as redundant,
   which has no evidence behind it and drops coverage on other harnesses.

5. **The eval strips the paragraph from both arms and adds a shipped-config
   arm and a no-skill sentinel.** Control is the branch with the paragraph
   removed from SDD and brainstorming; treatment is the same plus the
   notice. A treatment-only arm runs the shipped configuration, and a new
   scenario checks that a session following no skill does not start reading
   skills. Rejected: replacing the plugin's files under a running eval
   session to make its loaded text genuinely stale, because the quorum
   harness pins one commit per arm and the measured behavior is whether the
   Read happens, which the stripped control exercises; running the
   brainstorming compaction scenario as well, because the notice is generic
   and the SDD scenario measures it at lower cost.

6. **The notice ceiling rises from 1,200 to 1,400 characters.** The
   external workflow adoption spec (2026-09-10, B2) caps the context the
   hook adds beyond the `using-hyperpowers` body at 1,200 characters when
   every notice fires, and `tests/hooks/test-session-start.sh` measures 861
   today. The re-read notice is 275 characters plus the plugin path, which
   brings the ceiling case to about 1,186. The notice prints only on
   compact runs, and a 14-character margin would fail on the next notice or
   a longer test path. Rejected: cutting the notice further, which drops
   either the stale-copy reason or the path; keeping 1,200 by shortening
   the A9 notice, which is tested text outside this slice.

7. **SDD's SKILL.md becomes a controller under 19,000 characters, and its
   step text moves into five sibling files.** At the 100,000-token
   window released 6.18.1 failed 10 of 10 runs of `sdd-compaction-reread`
   with Claude Code's "Autocompact is thrashing" stop, and so did the notice
   arm: a full re-read of the 76,445-character skill (41,751 when 6.16.2
   measured the paragraph) costs about 27,000 tokens, needs two Reads, and
   puts the context back at the threshold. A controller that fits Claude
   Code's 20,000-character re-attachment comes back whole, so only the
   current step's file is re-read. The human partner set the 100,000-token
   floor as the window SDD must work at (2026-11-12). Rejected: phase
   modules with the current phase recorded in the ledger, which add state
   that can go stale; a short recovery document holding the rules the cut
   drops, a second copy that drifts and summarizes 56,000 characters of
   loop rules lossily; re-reading only the text past the cut, about 15,000
   tokens and growing with every addition to the skill, where offline size
   checks cap the controller and one step file near 10,000 tokens; supporting only windows of 200,000
   or more.
   Supersedes: docs/hyperpowers/decisions/2026-11-03-fix-truncation-with-a-re-read-paragraph.md

8. **SDD's re-read paragraph sends the session to the board, the ledger
   lines of the task it holds, and the step file a table in the
   controller names for that state.** This amends decision 4 for SDD; the
   brainstorming paragraph is unchanged, since that skill re-reads in one
   Read for about 7,000 tokens and passed 10 of 10 in 6.16.2. Rejected:
   keeping the full-file re-read, which loops at 100,000 (measured).

9. **The notice gains a clause sending the session on to the files the
   skill names after a compaction, and its ceiling follows a measurement.**
   This amends decision 6: the plan measures the ceiling case with the new
   text and raises the ceiling only by what that measurement needs.
   Rejected: dropping the notice, which leaves sessions on stale skill text
   with no pointer to the installed copy; keeping its old text, which names
   only SKILL.md while the step text now lives beside it.

10. **The eval compares released 6.18.1 with the slice head, counts a
    thrash or a run with no dispatch as a failure, and reuses the 2026-11-12
    baseline as its control.** This replaces decision 5. The baseline ran
    the v6.18.1 tree on the same scenario, Claude Code version and model;
    it stands as the control once its harness paths are shown identical to
    the pin, and otherwise the control is run again. Rejected: the
    stripped-paragraph control, which finished 10 of 10 by never re-reading
    and does not stand for the release users run; voiding runs with no
    dispatch, which hid all 20 failing runs on 2026-11-12; a shipped arm
    beside the treatment, since the treatment now is the shipped
    configuration.

## Design

### The notice

`hooks/session-start` gains a second notice, `reread_notice`, built when
`hook_source` is `compact` and appended to `session_context` before the
existing ledger notice. Its text, with `<root>` the hook's `PLUGIN_ROOT`
passed through `escape_for_json`:

> Context was compacted. Each skill you invoked came back cut to 20,000
> characters, and a long session can hold an older copy than the one
> installed. Before your next action, Read in full
> `<root>/skills/<name>/SKILL.md` for each hyperpowers skill you are
> following; if none, skip this.

The text is one line, carries no quote, backslash or newline of its own,
and is 275 characters before `<root>` is substituted.

`<root>/skills/<name>` is the same path the re-attached copy's "Base
directory for this skill" line names, so a read returns the installed text.
Building the notice needs no git repository and no ledger. It does depend on
node the way the A9 notice does: the hook reads `source` from its payload
with node, so without node `hook_source` stays empty and neither notice
prints. Formatting the notice itself is a `printf` of a fixed string and the
spelled root. It is fail-silent like the notices above it: if building it
fails, the hook prints what it would have printed without it. On `startup`,
`resume` and `clear` runs nothing changes.

The root is spelled exactly as the A9 notice spells the ledger path, so the
notice stays one line for any legal install path: a root that is not valid
UTF-8 (where `iconv` is present to check) suppresses the re-read notice; a
root whose JSON spelling differs from its bytes (a quote, a backslash or a
C0 byte), or that carries U+0085, U+2028 or U+2029, is shown as a JSON
string literal with its escapes visible; any other root is shown verbatim.
That logic moves out of the A9 block into one helper both notices call,
with A9's output unchanged and its existing tests passing.

Order on a compact run: the bootstrap context, the existing notices, then
the re-read notice, then the ledger notice when a ledger exists. The re-read
comes before the ledger because SDD's own paragraph orders them that way
("Read this file in full ... then the ledger").

### Components

In this repository:

- `hooks/session-start`: the new notice beside the A9 block, the path
  spelling helper shared with A9, and the "Notice budget" comment's figure
  changed to 1,400.
- `tests/hooks/test-session-start.sh`: cases for a compact run with and
  without a ledger (both notices present, re-read first), outside a git
  repository (re-read notice alone), and `startup`, `resume` and `clear`
  runs (no re-read notice). Root spelling cases run the hook from a copy of
  the plugin under a directory whose name carries a quote, a backslash, a
  newline, U+0085, U+2028 and U+2029, one case each, and assert that the
  decoded notice is one line naming the root as a JSON literal; a plain
  root is named verbatim. The ceiling case also requires the re-read marker
  and asserts under 1,400 (Decision 6). Existing A9 assertions keep
  passing.
- `docs/site/` pages that list `hooks/session-start` in `sources:`
  (`advanced/triggering.md`, `advanced/sdd-internals.md`,
  `advanced/codex-gates.md`, `skills/using-hyperpowers.md`): re-read, fix
  what is stale, update `source-digest:`.
- `CHANGELOG.md`: one entry.

In hyperpowers-evals (committed there, never here):

- `scenarios/compaction-no-skill/`: `story.md`, `setup.sh`, `checks.sh`,
  following `scenarios/sdd-compaction-reread/`. The fixture is a git repo
  with `.claude/settings.json` setting `autoCompactWindow` to 100000 and
  eight generated text files of about 8,000 tokens each, one of which holds
  a unique sentence; the story asks which file holds it and why, which
  takes reading every file. `checks.sh` pins `# coding-agents: claude-auto`,
  because the scenario measures Claude Code's compaction and SessionStart
  hook. Deterministic checks: the repo is unchanged and the transcript
  holds at least one Read call. Whether a compaction landed and what was
  read after it are tallied from the transcript, as in the 6.16.2 campaign.
- `test/scenario-pinning.test.ts`: `compaction-no-skill` added to
  `INTENTIONAL_PINNED_SCENARIOS` with a comment giving the reason, as every
  pinned scenario has.
- `evidence/2026-11-11-compaction-reread-notice/`: manifests, `launch-all.sh`
  copied from the 6.16.2 evidence directory, and `tally.py` adapted from
  its `tally.py` with tests: arms `control`, `treatment` and `shipped`, the
  per-compaction count for every SDD run, and the sentinel classification
  below.

Order: the evals scenario, tally and tests are committed first; then the
three plugin commits (B, treatment, shipped) exist on the slice branch; the
manifest records all three pins and the evals harness revision before the
first run, as the 6.16.2 manifests do.

### Assumptions

- Assumption: a hook script edited on disk takes effect in a running Claude
  Code session at its next event, validate via the field record that
  `ec562ba3` printed the A9 notice on 2026-11-10 while holding 6.16.1 skill
  text, and by checking one current long-lived session's compaction output
  after the release.
- Assumption: the hook reaches stale sessions only when the plugin loads
  from a fixed path, as this fork's `plugin-install` worktree does. A
  marketplace install keeps each version in its own cache directory and a
  session resolves the hook path at load, so a stale session there runs its
  old hook (or none, if the directory was removed); validate via reading
  the hooks configuration Claude Code records for a cache-installed plugin.
  This limits the reach of the fix, not its correctness.
- Assumption: a session whose re-attached copy lacks the paragraph behaves
  like the field's stale sessions, validate via the control arm matching
  the 6.16.1 RED result (0 of 10 re-reads).

## Testing and Evidence

Offline: `tests/hooks/test-session-start.sh` and the rest of the offline set
in `docs/testing.md`.

Live: paired quorum campaigns on Claude Code with `claude-opus-5-5` as
controller and grader, ten valid runs per arm per scenario. Voids follow
`evals/docs/scenario-authoring.md`: an instrument failure is not a trial, a
void is replaced under the replacement cap and recorded in
`sentinel-reruns.tsv`, and an invalid run (its validity condition below not
met) is a void. Run artifacts and tallies go to
`evals/evidence/2026-11-11-compaction-reread-notice/` in hyperpowers-evals.

Pins: Shipped is the slice commit that adds the notice on top of `main`,
with the paragraph. B is a pin-only commit on a side branch from `main`
that removes the "After every context compaction" paragraph from SDD and
brainstorming; Treatment is B plus the same notice change. Control is B.
The side branch is never merged.

A re-read is counted as the 6.16.2 tally counts it: a successful Read (or
`cat`) of SDD's SKILL.md after a compaction and before the next dispatch.
Whole-file reads and reads from an offset that covers the cut text are both
counted, and reported separately.

1. **sdd-compaction-reread** (existing), control and treatment. Validity: a
   compaction lands after task 1's review returns and before the final
   review is dispatched (the 6.16.2 rule). Bars:
   - treatment mechanism (a re-read after the first compaction in that
     window) at least 8 of 10;
   - treatment per-compaction rate (re-reads over every compaction after
     the skill load, all valid runs pooled) at least 85%;
   - treatment outcome at least the control's outcome.
   The control mechanism is expected near 0, as the 6.16.1 control's 0 of
   10. A control above 3 of 10 means the stripped base does not stand in
   for stale text, and the campaign stops for a decision.
2. **sdd-compaction-reread**, shipped only, same validity. Bars: outcome at
   least 9 of 10 (the 6.16.2 wave-2 result); per-compaction rate at least
   90% (wave 2: 148 of 151); median compactions per run at most 16 (wave
   2's median, from `evals/evidence/2026-11-03-cost-reduction-6-16-2/tally.txt`).
   The last bar checks that the paragraph and the notice together do not
   cause re-read loops at the 100,000-token window.
3. **compaction-no-skill** (new), treatment only. Validity: at least one
   automatic compaction lands before the session's final answer, and the
   session invokes no skill before that compaction. A valid run fails if,
   after a compaction, it Reads (or `cat`s) any path ending
   `/skills/<name>/SKILL.md` for a skill it never invoked;
   `using-hyperpowers` is exempt, because the bootstrap injects it. Bar: at
   most 1 of 10 valid runs fail.

## Revision (2026-11-12): a compact SDD controller

### What the campaign found

Wave 1 (control, the paragraph stripped) gave 10 valid runs, all finishing
the plan, with 4 of 93 compactions followed by a re-read. Wave 2 (the
notice, paragraph stripped) gave 10 runs that each ended in Claude Code's
"Autocompact is thrashing" stop without dispatching a subagent. In the
traced run the first compaction came during SDD Setup at about 68,000
tokens; the session then read SKILL.md (a truncated view, then the rest
from line 824) and compacted again 35 to 40 seconds later at about 66,000,
nine times. A baseline of released v6.18.1, which has the paragraph and no
notice, failed the same way in 10 of 10 runs (9 with no dispatch, 1 with
one). Evidence: hyperpowers-evals `b59b12e16c` and
`evidence/2026-11-11-compaction-reread-notice/README.md`, "Outcome"; the
baseline logs are `logs/baseline-6181-p<n>.log` there. The cause is SDD's
size together with any instruction to re-read it whole; the notice only
added a second such instruction.

### The SDD layout

`skills/subagent-driven-development/SKILL.md` stays under 19,000
characters, below the 20,000 Claude Code re-attaches with room to grow. It
keeps the overview, the narration and communication lines, Continuous
execution, Tracked work only, When to Use and Model Selection as they are,
and the rewritten compaction paragraph below, plus:

- a numbered outline of the plan's steps in place of the dot graph in The
  Process, each line naming the step, its decision points, and its file;
- the step table below, which names one step file for each ledger state;
- the rules that hold in every step: tasks with a completion line are never
  dispatched again, and the ledger and `git log` outrank memory; subagents
  and covering commands are waited on in the foreground, one implementer at
  a time; the controller never fixes code itself outside the de-minimis
  exception; the shared five-round cap and its breaker; when a turn may end
  and the handback line; a step file read before a compaction is gone and
  is read again;
- the waiting board and the Risk Tiers pointer.

Each rule in that list is stated once, in SKILL.md. Moving the step text
deletes the sentences that state the same rule (the plan lists each
deletion) and otherwise moves it verbatim; the step text keeps the
mechanics of carrying a rule out. Where a step file and SKILL.md differ on
a rule, SKILL.md governs. An offline check finds each rule's sentence
exactly once across SKILL.md and the step files.

The step files, in the same directory:

| File | Holds | Size today |
|---|---|---|
| `setup.md` | Setup | 16,660 |
| `task-loop.md` | The Task Loop's introduction, step 1 (dispatch) and step 2 (the report) | 15,886 |
| `review-and-complete.md` | Step 3 (the task review) and step 5 (completing the task) | 6,482 |
| `fix-loop.md` | Step 4, the fix loop | 11,581 |
| `final-and-finish.md` | Final Review and Finish | 9,590 |

Every link from the moved text to another sibling file keeps working from
its new place. Offline checks hold SKILL.md under 19,000 characters and
each step file under 17,000, so SKILL.md and any one step file together
stay under 36,000 characters, about 10,000 tokens.

Recovery reads the ledger in two bounded parts, not whole: the board
(`scripts/sdd-state board PLAN_FILE`, a few lines naming the task this
session holds) and the lines of that task and of this session's Setup
(`grep -E '^(Task <N>:|session <sid>: setup complete)' <workspace>/progress.md`,
with `Task <N>:` left out when no task is held). Whole ledgers on this host
reach 105,391 characters for a 13-task plan; the largest one task's lines
reach 11,932 (seven ledgers measured 2026-11-12). The step table:

| State | Step file |
|---|---|
| no ledger in the workspace `scripts/sdd-dir PLAN_FILE` prints, or no `setup complete` line of this session in it | `setup.md` |
| the board shows no task held by this session and a task without a completion line | `task-loop.md` |
| the held task's newest line is its branch, base, implementer identity or `report` line | `task-loop.md` |
| its newest line is a `review` or Codex gate line approving it, an `approved` line or a `merged` line | `review-and-complete.md` |
| its newest line is a `fix round` line, or a `review` or Codex gate line with blocking findings | `fix-loop.md` |
| this session holds the final claim, or every task has a completion line | `final-and-finish.md` |

Three ledger lines become mandatory so the table can be read: at the end
of Setup, `session <sid>: setup complete`; after a report,
`Task <N>: report <status> ...`; after a review or a Codex gate round,
`Task <N>: review <approved|blocking> ...` and
`Task <N>: codex gate round <R> <approved|blocking> ...`. A state the table
does not cover reads `task-loop.md`, and the session records that in the
ledger.

### The paragraph and the notice

SDD's paragraph becomes:

> **After every context compaction:** this file fits within the 20,000
> characters Claude Code re-attaches, so the copy you hold is whole. A step
> file you read before the compaction does not survive it. Before your next
> action, print the board and the ledger lines the step table names (your
> task's and your Setup's, never the whole ledger), find your step in the
> table, and Read that step file in full.

The notice keeps its trigger, order and root spelling; its text becomes:

> Context was compacted. Each skill you invoked came back cut to 20,000
> characters, and a long session can hold an older copy than the one
> installed. Before your next action, Read in full
> `<root>/skills/<name>/SKILL.md` for each hyperpowers skill you are
> following, then the files it tells you to read after a compaction; if
> none, skip this.

A session on stale 6.18 text is pointed at the installed controller, about
5,500 tokens. A current session re-reads a SKILL.md it already holds whole,
the same cost, accepted because the hook cannot tell the two apart.

The dispatch guard's refusal texts (`hooks/lib/dispatch-guard.mjs`) end
"If you have not Read <skill> in full since the last compaction, Read it
now." That becomes "If you have not Read <skill> and the step file its step
table names since the last compaction, Read them now.", and the module's
opening comment no longer says a compaction removes the foreground rule,
since SKILL.md now always holds it.

### Components (revised)

In this repository: the SDD SKILL.md and the five step files; every
offline test that looks for SDD text, pointed at the file the text moved
to (`tests/sdd/` and the other suites listed in `docs/testing.md`); new
offline checks for the size bounds and the once-only rule sentences;
`hooks/session-start` and `tests/hooks/test-session-start.sh` for the
notice text and the measured ceiling; `hooks/lib/dispatch-guard.mjs` and
`hooks/lib/dispatch-guard.test.mjs` for the refusal texts; the
`docs/site/` pages whose `sources:` list SDD, the hook or the dispatch
guard; `CHANGELOG.md`.

In hyperpowers-evals: `tally.py` and its tests for the arms and rules
below, the manifest and README in the evidence directory. The scenario,
the sentinel scenario and the launchers stay.

### Testing (revised)

Arms, ten valid runs each, the harness pin, Claude Code 2.1.317 and
`claude-opus-5-5` as controller and grader:

- control: released v6.18.1 on `sdd-compaction-reread` (decision 10);
- treatment: the slice head on `sdd-compaction-reread`;
- sentinel: the slice head on `compaction-no-skill`, with the validity and
  failure rules of the Testing section above, unchanged.

Validity for the two SDD arms replaces the earlier window rule. A run is a
void when the launch failed its pin checks (`launch`), setup errored
(`setup`), the Gauntlet-Agent gave no pass or fail (`grader`), a quorum
stage after setup errored (`instrument`), or no compaction came after the
skill loaded (`no-compaction`). Every other run is valid, a run that ends in
the thrash stop or never dispatches among them, and counts as an outcome
failure. Voids are replaced under the replacement cap and recorded in
`sentinel-reruns.tsv` as before.

A treatment compaction is followed when, after it and before the session's
next governed action (an Agent dispatch, a ledger write, or a
`sdd-state` call other than `board`), the session reads in full the step
file the step table names for the state at the compaction, and, when a
ledger existed then, prints the board and the ledger lines the step table
names. The tally
reads the state from the ledger writes and `sdd-state` output in the
transcript before the compaction; a state it cannot read counts the
compaction as not followed. A read in full is a Read with no truncation
banner, or Reads that together cover the file; persisted Bash output earns
no credit. The tally also reports, separately, compactions followed by any
step file, by the board and task lines, and by SKILL.md, so a session that
reads the wrong step file, only SKILL.md, or skips the ledger parts shows
in its own count; the tally's tests cover each of those cases, the
no-ledger case, and every row of the step table (a gate line approving and
one blocking among them).

Bars:

1. Treatment outcome (plan finished, every post-check passing) in at least
   8 of 10 valid runs, and more than the control's.
2. No treatment run ends in the thrash stop.
3. At least 85% of treatment compactions after the skill load, valid runs
   pooled, are followed.
4. Median treatment compactions per run at most 16.
5. Sentinel failures at most 1 of 10.

Assumption: moving the step text keeps SDD's behavior in the steps it
governs, validate via bar 1 and the existing offline SDD suites.
Assumption: one task's ledger lines stay under about 15,000 characters
(largest measured 11,932), so the whole recovery read, SKILL.md, one step
file, the board and the task lines, stays under about 52,000 characters,
about 14,000 tokens, validate via the same measurement over the state
checkouts on this host when the plan is written. The campaign measures one
four-task plan; longer plans rely on reading one task's lines, which does
not grow with the plan.

Out of scope for the revision: brainstorming, finishing-a-development-branch
and writing-skills, also over the cut but each re-read in one Read of about
7,000 to 8,000 tokens.

## Out of Scope

- The brainstorming compaction scenario, unmeasured here (Decision 5).
- Reaching stale sessions of marketplace installs (Assumptions).
- The two field compactions with the paragraph present and no read, both in
  `15809a43`; at 2 of 17 they do not differ measurably from the eval's 3 of
  151.
- The A9 notice pointing `ec562ba3` at another plan's ledger at 16:55Z on
  2026-11-10, a separate defect listed by the dispatch guard spec.
- A field re-measure of the re-read rate after the release, which joins the
  cost re-scan owed on or after 2026-11-18.
