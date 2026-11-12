# Compaction Re-read Notice: Design

Date: 2026-11-11. Status: draft for review. This design is the
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
