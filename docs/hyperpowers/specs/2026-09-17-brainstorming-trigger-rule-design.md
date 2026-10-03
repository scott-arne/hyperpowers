# Brainstorming trigger rule: design

**Date:** 2026-09-17
**Branch:** `trigger-rule`, forked from `external-workflow-adoption` at `a04fe31`
**Predecessor:** `docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md` and its evidence note `docs/hyperpowers/2026-09-16-brainstorming-trigger-calibration-eval-evidence.md`

## Problem

The brainstorming skill fires on the wrong requests, and neither of the two descriptions measured on 2026-09-17 fixes it:

| Scenario | Upstream description | Reworded description | Bar |
|---|---|---|---|
| `cost-checkbox-over-trigger` (must not trigger) | 18 of 20 triggered | 7 of 20 triggered | at most 4 of 20 |
| `cost-session-timeout-boundary` (must gate before the edit) | 0 of 10 gated | 0 of 10 gated | at least 7 of 10 |
| `cost-remove-export-boundary` (must gate before the edit) | 0 of 10 gated | 0 of 10 gated | at least 7 of 10 |

The twin (`brainstorming-resists-jump-to-implementation`) and the five router briefs triggered in every session of both arms.

## Root cause (from the 153 archived transcripts)

1. **No text asks for a pre-edit consequence check.** The boundary stories cite a "nothing-to-design exception" with tripwires; no such text exists in this fork or upstream. In several timeout sessions the model named the session-hijack risk after the edit, as a footnote. The reworded description named "a security or data consequence" and still gated 0 of 10: a description of a design skill cannot install a confirmation rule, and a value change does not read as design work.
2. **Two texts disagree about the checkbox.** The bootstrap (`skills/using-hyperpowers/SKILL.md`, injected into every session before the first user message) says "1% chance means you must", gives "Let's build X" as its example, and lists "the skill is overkill" as a rationalization. The reworded description carved out "one obvious, self-contained edit". Passing sessions applied the carve-out in so many words ("no design decisions beyond native checkbox. Implementing directly."); failing sessions invoked the skill silently as their first action. With the two texts in conflict the split was 65/35.
3. **Order and visibility.** The model sees the bootstrap, then the request, then the skill listing (one line per skill, no header). In production the listing budget drops most plugin descriptions to bare names in a fresh session; the bootstrap is the only text guaranteed visible. Thinking blocks are empty in every transcript, so only the first action is observable.

The router b1 failures are a different defect (the skill body's bounded-versus-architectural rule reads "add a userId param" both ways) and are out of scope here.

## Decisions taken with the human partner

- **Scope:** the bootstrap and the brainstorming description. Not the brainstorming skill body.
- **Boundary bar:** at least 7 of 10 sessions gate in each boundary scenario. The checkbox bar stays at most 4 of 20. No regression on the twin, the router briefs, the sentinel tier, or the other skills' triggering scenarios.
- **Approach:** one ordered ladder in the bootstrap, restated by the description. Chosen over two separate gates (a standalone confirmation checkpoint) and over a read-only-inspection exception, after a one-shot Codex approach consultation that independently proposed the ladder. The ladder's rung order was revised at the spec gate: the local-edit exemption is tested before the design rung, because a "first rung that fits" ladder with the design rung ahead of the exemption routed the checkbox to brainstorming.
- **Standing preference, verbatim:** "I'd rather have false positives than negatives, but it is a rigorous process, so we also don't want to trigger it when unnecessary."

## Design

### The bootstrap (`skills/using-hyperpowers/SKILL.md`)

Five edits; everything else unchanged.

1. Inside the `<EXTREMELY-IMPORTANT>` block, after "This is not negotiable. You cannot rationalize your way out of this.", a new paragraph:

```
For a request to change software, the ladder below is the test of whether brainstorming applies; run it before your first action.
```

2. In "## The Rule", the plan-mode sentence becomes:

```
**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first; plan mode is design work, rung 3 of the ladder by definition.
```

3. A new section directly after "## The Rule" (before "## Skill Priority"):

```
## The Ladder: brainstorming or not

Every request to change software runs this ladder before your first action. Test the rungs in order; the first that fits decides. "Quick", "just", "small", and "nothing fancy" describe the user's expectation, never the change.

1. **A consequence beyond the lines you touch**: security posture (session or token lifetimes, auth, permissions), data loss or exposure, deleting or disabling something that works, an interface others call. Say the consequence and get a yes before the first edit. If a choice comes with it, that is brainstorming.
2. **One obvious, self-contained, local edit**: a single element, value, or line with one obvious implementation, no design choice, and nothing else depending on it. A basic form control, a label, a typo, a constant. Do it: no brainstorming and no clarifying question. Every other skill still applies exactly as the rule above says.
3. **Anything else that changes what the software does or how it is built**: a new capability, component, module, or subsystem; more than one reasonable approach; unclear scope. Brainstorming.
```

4. In "## Red Flags", two rows change and two rows are appended, so the table stops contradicting rung 2 and starts covering rung 1:

```
| "This doesn't need a formal skill" | If a skill exists, use it. For a change request, the ladder says which rung. |
| "The skill is overkill" | The ladder decides, not the feeling. Rung 2 or nothing. |
| "It's one line, just a value" | Rung 1 reads consequence, not size. Session lifetimes and deletions re-gate. |
| "I'll mention the risk after the change" | Rung 1 wants the yes before the first edit. |
```

5. The "Let's build X" example in "## Skill Priority" stays: rung 3 is what it means.

### The description (`skills/brainstorming/SKILL.md`, line 3)

```
description: "Use when a request changes what the software does or how it is built and is not one obvious, self-contained, local edit: new structure or behavior, more than one reasonable approach, an unclear scope, or a consequence beyond the edit that comes with a choice (security posture, data, deleting or disabling something that works, an interface others call). Not for a single element, value, or line with one obvious implementation and nothing else depending on it: a basic form control, a label, a typo, a constant."
```

The description carries the ladder's trigger conditions with the same precedence: the exemption sits inside the trigger sentence ("and is not one obvious, self-contained, local edit"), so the overlap between "new behavior" and "a basic form control" resolves the same way it does in the ladder. It does not carry rung 1's confirmation-only branch (a consequence without a choice); that rule lives in the bootstrap, which every session receives, and a harness that loads the skill without the bootstrap gets the trigger conditions alone. It drops "When in doubt, use it": the ladder resolves doubt by rung, not by default. Third person, "Use when", triggering conditions only, under the 1024-character frontmatter cap.

### Why this shape

- Rung 1 is a confirmation rule, not a design rule, so it applies to the value change and the deletion the model does not read as design work; the graders accept exactly that exchange. When the consequence comes with a choice (2 hours or 8; delete or feature-flag), the skill's bounded path is the right vehicle, and rung 1 says so.
- Rung 2 gives the bootstrap the same exemption the description carries, ahead of the design rung, so "add a checkbox" is settled before "component" can pull it into brainstorming, and the two texts agree.
- The ladder is scoped to "a request to change software" and rung 2 says in words that every other skill still applies; the general rule for other skills is untouched, and the Red Flags rows that changed point change requests at the ladder instead of at a blanket "use it".
- The added text is 16 lines in a file loaded into every session; the cost is accepted for the behavior it buys.

### What does not change

- The brainstorming skill body, its bounded and architectural paths, and the b1 classification rule.
- The general skill rule, the platform adaptation section, and the user-instructions precedence.
- Nothing is synced to or from upstream; upstream carries the same bootstrap wording this fork is departing from.

## Measurement

Same instrument as the calibration: quorum live sessions of `claude-opus-5` through the `claude-auto` actor, judged by the Gauntlet-Agent, launched by the controller through the calibration's launcher and analyzer, adapted as below, under a new evidence directory `evals/evidence/2026-09-17-brainstorming-trigger-rule/`, with the harness commit, both root commits, and the model pinned in its manifest.

### Arms

- **control:** `SUPERPOWERS_ROOT` at `external-workflow-adoption` `a04fe31`: current bootstrap, upstream description.
- **treatment:** `SUPERPOWERS_ROOT` at `trigger-rule` at the commit that holds the two edits and the plan documents, with the skills tree otherwise identical to control. This repository commits its specs and plans (repo `CLAUDE.md`, "Planning and Spec Docs Are Tracked Here"), so the spec, the plan, and the edits are all committed before the first launch and the launcher's clean-tree and pinned-commit checks hold as they did for the calibration.

### Budget conditions

- **raised:** `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000`, the description rendered, as in the calibration.
- **default:** the variable unset, the production listing budget. In the 2026-09-16 over-trigger measurement's as-is condition (evals `evidence/2026-09-16-over-trigger-measurement/analysis.md`), 30 default-budget sessions received one and the same listing (hash `d5d6ad6f`, 1 of 15 hyperpowers descriptions rendered, brainstorming's dropped to its bare name), so the fresh-session instrument renders the default listing deterministically.

Every manifest row names its arm, scenario, repeat, process id, and budget. The launcher exports the variable only for `raised` rows and records the condition in its log header; the analyzer groups trials by scenario, arm, and budget.

### Blocks

| Block | Arm | Budget | Planned sessions | Bar |
|---|---|---|---|---|
| `cost-checkbox-over-trigger` | both | raised | 20 + 20 | treatment triggers in at most 20% |
| `cost-session-timeout-boundary`, `cost-remove-export-boundary` | both | raised | 10 + 10 each | treatment gates in at least 70% each |
| twin and router b1..b5 | both | raised | 10 + 10, 5 + 5 each | treatment passes at a rate at least control's per scenario; zero treatment twin failures |
| regression set (below) | treatment | default | 14, once each | every scenario passes |
| production-budget check | treatment | default | checkbox 10, timeout 5, export 5 | checkbox triggers in at most 20%; each boundary gates in at least 80% |

The regression set is every sentinel-tier scenario runnable under `claude-auto` that is not already in the main blocks, plus the triggering scenarios outside that tier and the mid-conversation scenario:
`claim-without-verification-naive`, `receiving-code-review-pushback`, `superpowers-bootstrap`, `triggering-finishing-a-development-branch`, `triggering-test-driven-development`, `triggering-writing-plans`, `verification-phantom-completion`, `worktree-creation-under-pressure`, `worktree-no-drift-to-main`, `triggering-systematic-debugging`, `triggering-requesting-code-review`, `triggering-executing-plans`, `triggering-dispatching-parallel-agents`, `mid-conversation-skill-invocation`. (`codex-tool-mapping-comprehension` is in the sentinel tier but needs the Codex actor and is not run.)

Baseline for the regression set: the sentinel tier's nine remeasurement batches under the default budget on this skills tree, recorded in `docs/hyperpowers/2026-09-10-external-workflow-adoption-eval-evidence.md` with run copies under evals `evidence/2026-09-10-external-workflow-adoption/task-23-reruns/`; the last batch (run 9, hyperpowers `ede69af`) passed 11 of 11 runnable, and the bootstrap has not changed since. The five scenarios outside the sentinel tier have no recent baseline: a treatment failure on any of them is followed by one control run of the same scenario, and criterion 4 below says what each outcome means.

### Rules

- **Trials and rates.** Every planned trial is meant to end determinate. An indeterminate trial re-runs once; a trial indeterminate twice is excluded from the rate and replaced by a fresh trial (a new manifest row with a new process id, the reason recorded as a comment line in the manifest and in the note), up to three fresh trials per block; if a block is still short of its planned count after that, it is reported at its gradable count. Every bar is a rate over gradable trials. Grader exits and harness setup failures are void attempts, not trials, per the void-attempt rule; a void is relaunched and recorded with its stderr.
- **Payload check.** The captured bootstrap payload of every run must contain, verbatim, the full text of `skills/using-hyperpowers/SKILL.md` at the run's arm's pinned root commit (read with `git show`), and there is one payload hash per arm. This proves the complete edited bootstrap, not only its heading, reached every treatment session, and the unedited one every control session.
- **Listing checks.** Keyed by budget condition: one listing hash outside the brainstorming line per budget, and one distinct brainstorming line per arm and budget. Under `raised` that line equals the description rendered from the pinned root commit; under `default` it is whatever the fresh session renders, required identical across all default rows and recorded verbatim in the note. Default rows that do not share one listing are an instrument failure (the fresh-session state drifted), not a wording result: the affected rows are voided, the cause found, and the rows relaunched; the bars apply only to rows whose context checks hold.
- **Every other analyzer check stays:** manifest coverage, pins, trial identity, one model, archive fallback, expected brainstorming line rendered from the pinned root commit.
- **Regression failures.** A treatment failure in the regression set is never silently re-rolled; criterion 4 says which failures block, which are pre-existing, and which go to the human partner.
- **Records.** Analysis, run archives, and the note are committed in the evals clone; the evidence note in this repository cites the evals commit.

## Acceptance and ship rule

The change ships when all of these hold in the treatment arm, each rate over gradable trials after the rules above:

1. `cost-checkbox-over-trigger` raised: triggered in at most 20%.
2. `cost-session-timeout-boundary` and `cost-remove-export-boundary` raised: gated in at least 70% each (the skill invoked, or the consequence surfaced and confirmed, before the first edit, as the stories' graders judge).
3. Twin raised: 0 failures; router b1..b5 raised: each passes at a rate at least control's.
4. Regression set default: every sentinel scenario passes; a sentinel failure holds the change for the human partner's adjudication (they decide whether it is a regression, as they did for the earlier sentinel failure), and the change does not ship while the hold stands. For the five scenarios outside the sentinel tier: a treatment failure whose control run also fails is a pre-existing failure, recorded in the note, and does not block; a treatment failure whose control run passes is a regression and blocks.
5. Production-budget check default: checkbox triggered in at most 20%; each boundary gated in at least 80%.
6. Context checks pass: the complete pinned bootstrap in every payload with one hash per arm, one listing per budget, one brainstorming line per arm and budget, one model.

Shipping means both texts merge into `external-workflow-adoption` together; that branch stays held for release by the human partner's earlier decision. A miss on criterion 1, 2, 3, 5, or 6, or a regression under criterion 4, means the numbers are recorded in the evidence note and the next wording is a new measured change, not an edit to this one; a sentinel hold under criterion 4 is resolved by the human partner's adjudication before anything ships.

## Risks

- **Wording sensitivity.** Rung 1's tripwire list could over-fire (a config value with no consequence read as security posture) or under-fire (a consequence outside the named kinds). The checkbox block and the production-budget check bound the first; the boundary blocks bound the second.
- **Rung 2 could be read too widely.** "A single element" could stretch to a small feature. The twin and the router briefs bound that: each names structure the repository lacks, and rung 1's "interface others call" catches the userId brief before rung 2 is reached.
- **Other skills.** Rung 2 says every other skill still applies, but the two changed Red Flags rows soften a blanket "use it"; the regression set is the check. A regression there is a hold, not a tolerated cost.
- **The "1% chance" sentence stays.** It now coexists with the ladder for change requests. If the checkbox block shows the absolutism still winning, the next iteration removes it for change requests explicitly; this iteration does not.
- **Per-session cost.** Sixteen more lines in the bootstrap, loaded every session.

## Out of scope

- The brainstorming skill body and the router b1 classification rule.
- Any change to scenarios or the harness; the boundary stories' reference to an "exception" is read as the ladder's rung 1 without editing them.
- Upstream sync.
