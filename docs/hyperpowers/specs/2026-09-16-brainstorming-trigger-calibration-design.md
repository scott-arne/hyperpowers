# Brainstorming trigger calibration — design

**Date:** 2026-09-16
**Status:** approved in chat by the human partner (bounded change; design recorded here so the plan has a binding authority)
**Branch:** `brainstorming-trigger` off `external-workflow-adoption`

## Problem

The `brainstorming` skill over-triggers on requests that need no design.
Measured on 2026-09-16 (hyperpowers-evals
`evidence/2026-09-16-over-trigger-measurement/`, 61 runs, one pinned skills
tree, `claude-opus-5`, identical SessionStart payload in every run):

| scenario | listing shows the description? | n | over-trigger (fail) |
|---|---|---|---|
| `cost-checkbox-over-trigger` ("basic checkbox, nothing fancy") | no (Claude Code's 6000-char skill-listing budget drops it) | 20 | 2 (10%) |
| `cost-checkbox-over-trigger` | yes (`SLASH_COMMAND_TOOL_CHAR_BUDGET=20000`) | 21 | 17 (81%) |
| `brainstorming-resists-jump-to-implementation` (should trigger) | no | 10 | 0 fail (2 indeterminate) |
| `brainstorming-resists-jump-to-implementation` | yes | 10 | 0 fail (1 indeterminate) |

Seventeen of seventeen failures with the description visible called
`Skill(hyperpowers:brainstorming)` as the session's first action. The
description is therefore the over-trigger when it reaches the model, and it
adds nothing to the wanted trigger. Its current text is upstream's:

> You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.

It names no exclusion, and "building components" lexically matches the
checkbox request. It also violates this fork's own description guidance
(`skills/writing-skills/SKILL.md`, Skill Discovery Optimization): third
person, "Use when ...", triggering conditions only.

Whether a user sees the description depends on Claude Code's listing budget
(context tokens x 3 bytes/token x 1%, bundled skills first, plugin skills
by usage), so behaviour differs by installed plugins, model and history.
That mechanism is out of this fork's control; the description is in it.

## The needle

The human partner's preference: false positives over false negatives, but
the process is rigorous, so no trigger where none is needed. The eval suite
already draws the line by content, not by the user's framing:

- must NOT trigger: `cost-checkbox-over-trigger` (one basic checkbox),
  `cost-remove-export-boundary` (delete a dead button and handler);
- MUST trigger despite "nothing fancy" framing: `cost-session-timeout-boundary`
  (a one-line config bump with a security consequence),
  `brainstorming-router-escalates-b1..b5` (a userId parameter that changes
  a public interface; config moved into a module; logging as a new
  subsystem; validation made reusable; preferences storage),
  `brainstorming-resists-jump-to-implementation` (a notifications system).

The discriminator: one obvious, self-contained edit with no design choice
and no consequence beyond it, versus anything that changes what the software
does or how it is built, changes an interface others call, adds a component
or subsystem, has a security or data consequence, has more than one
reasonable approach, or has an unclear scope.

## Change

Only the `description` in `skills/brainstorming/SKILL.md`'s frontmatter
changes. New text, verbatim (kept double-quoted; it contains a colon):

> Use when a request changes what the software does or how it is built: a new feature or behavior, a new component, module, or subsystem, a change to an interface others call, a security or data consequence, more than one reasonable approach, or an unclear scope, however small it sounds. Not for a change whose whole scope is one obvious, self-contained edit with no design choice and no consequence beyond it (a typo, a label, a value nothing else depends on). When in doubt, use it.

Not changed: the `using-hyperpowers` bootstrap (its invoke-first rule and
Red Flags), and the brainstorming body (Three Paths, the approval gate, the
"Too Simple To Need Approval" anti-pattern). The description decides
invocation; the body governs what happens once invoked. The description
names no eval fixture (no "checkbox", no "export button") so the
measurement below is not trained to its own test.

## Measurement (the evidence the change ships behind)

Two arms at ONE harness commit, both with `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000`
in the runner's environment so the description is in the model's context
(the only condition in which the description can act; without it the two
arms are byte-identical to the model). Nothing from the earlier measurement
is reused: its runs were taken at a different harness commit, and the arms
must share one. The earlier numbers stand as the motivating observation
only.

- control: `SUPERPOWERS_ROOT` at the `external-workflow-adoption` head
  (`2e83fd8`), current description;
- treatment: `SUPERPOWERS_ROOT` at the `brainstorming-trigger` head after
  the change;
- harness: the hyperpowers-evals commit recorded in `manifest.tsv`; every
  launch refuses to run unless both roots are at their recorded commits with
  clean trees and the evals clone's harness paths (`src`, `scenarios`,
  `coding-agents`, `package.json`, `bun.lock`) are byte-identical to that
  commit with no uncommitted changes. Evidence commits may follow the pin;
  harness changes may not, so "one harness" is checked as a fact about the
  code every run saw rather than as a HEAD equality the evidence commits
  themselves would break.

| scenario | control | treatment |
|---|---|---|
| `cost-checkbox-over-trigger` | 20 | 20 |
| `brainstorming-resists-jump-to-implementation` | 10 | 10 |
| `cost-session-timeout-boundary` | 10 | 10 |
| `cost-remove-export-boundary` | 10 | 10 |
| `brainstorming-router-escalates-b1-userid-param` | 5 | 5 |
| `brainstorming-router-escalates-b2-config-module` | 5 | 5 |
| `brainstorming-router-escalates-b3-logging` | 5 | 5 |
| `brainstorming-router-escalates-b4-reusable-validation` | 5 | 5 |
| `brainstorming-router-escalates-b5-prefs-storage` | 5 | 5 |

150 live sessions. Each run records: `final`, the session's first tool call
(`Skill(hyperpowers:brainstorming)` / exploration / direct edit), token
total, the SessionStart payload hash, the hash of the skill listing with the
brainstorming line removed, and the brainstorming line itself. The analysis
fails closed: it refuses to produce a table unless every declared trial is
present exactly once with a verdict and a transcript, every payload hash is
the same, every listing-minus-brainstorming hash is the same, and each arm's
brainstorming line equals the line rendered from that arm's
`skills/brainstorming/SKILL.md` description.

Indeterminate trials (grader `investigate` at its wall with every
deterministic check passing) are re-run once each; the replacement is
recorded in `reruns.tsv` against the trial it replaces and stands in for it,
so a trial contributes one outcome; a trial indeterminate twice stays
indeterminate and is excluded from the rate (the void-attempt rule). A
failure is a trial.

## Acceptance

- `cost-checkbox-over-trigger` treatment fail rate at most 20% (control 81%).
- No false-negative regression: `brainstorming-resists-jump-to-implementation`
  and `cost-session-timeout-boundary` and each `brainstorming-router-escalates`
  scenario pass at least as often in treatment as in control, with zero
  treatment failures on the notifications twin.
- `cost-remove-export-boundary` treatment fail rate no higher than control.
- The two arms' payload hashes are identical, their listings are identical
  once the brainstorming line is removed, and each arm's brainstorming
  line is the one its root renders.

If the treatment misses a criterion, the description does not ship; the
plan's evidence note records the numbers and the next candidate wording is a
new measured change, not an edit to this one.

## Out of scope (queued as follow-on work)

- The bootstrap's invoke-first rule and its Red Flags table.
- A compact routing list in the bootstrap to make triggering independent of
  the listing budget.
- The three process fixes queued on 2026-09-16 (severity cap for
  pathological-input findings; re-measurement scoped to exercised surfaces;
  base-rate-aware sentinel failure rule).
