# Codex Review Stage-Gate for Hyperpowers on Claude Code — Design

**Date:** 2026-06-17
**Status:** Design (rewritten after first draft missed the core feature) — awaiting
user review before planning.

## Summary

Wire [`codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) into Hyperpowers
as an **active review stage-gate** when running under Claude Code. At defined points
in the skills, after Claude has done its own review/refine/fix pass and **before**
the user is re-engaged or work is declared complete, Claude invokes Codex to review
the artifact — **specs** (brainstorming), **plans** (writing-plans), and **code**
(subagent-driven-development per-task and final, plus requesting-code-review).

If Codex is available, this is an additional, last-before-handback gate: Claude
addresses Codex's findings in a fix-and-re-review loop, then hands back with a
summary. If Codex is **not** available, the skills behave exactly as today, except
they emit a warning that **no Codex review will occur**.

Scope is **Claude Code only.** codex-plugin-cc is a Claude Code plugin and its
runtime is Claude-Code-specific.

## What changed from the first draft

The first draft modeled only a session-start "install this dependency" banner —
the *plumbing*, not the feature, and even mis-scoped the plumbing. This rewrite
models the real feature: Codex as a review gate embedded in the skills. Install
detection is **repurposed**, not discarded: instead of a session-start banner, each
gate performs a run-time availability check that decides "run the Codex gate" vs.
"emit the no-Codex-review warning and continue."

## Background: how codex-plugin-cc actually works

Verified by inspecting the installed plugin (`codex@openai-codex`, v1.0.4):

- **Slash commands are not callable by Claude.** `/codex:review` and
  `/codex:adversarial-review` are marked `disable-model-invocation: true` — they are
  user-triggered only. A skill cannot invoke them.
- **The companion script is the integration surface.** The slash commands internally
  run `node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" <subcommand> …`.
  Hyperpowers will call this script directly via Bash, resolving Codex's install
  path from the plugin registry (see Detection).
  - `review` / `adversarial-review` — Codex code review over git state
    (`--scope auto|working-tree|branch`, `--base <ref>`, `--wait|--background`).
  - `task` — arbitrary Codex prompt. This is the lever for **document** review
    (spec/plan): pass the artifact and a review instruction.
  - `setup --json` — readiness probe (see Detection).
- **Structured review output.** `review` returns JSON matching
  `schemas/review-output.schema.json`:
  - `verdict`: `approve` | `needs-attention`
  - `findings[]`: each has `severity` (`critical` | `high` | `medium` | `low`),
    `title`, `body`, `file`, `line_start`, `line_end`, `confidence`, `recommendation`
  - `summary`, `next_steps[]`
  This gives the fix-loop a machine-readable verdict and severities.
- **Codex ships its own optional Stop-time review gate** (`stop-review-gate-hook.mjs`,
  enabled via `/codex:setup --enable-review-gate`) that adversarially reviews the
  previous turn's code changes and can BLOCK. It is code-only, turn-based, and global.
  Hyperpowers does **not** touch or depend on it (see Relationship below).

## Decisions (locked with maintainer)

1. **Trigger = call the companion script directly** via Bash
   (`codex-companion.mjs review|task`), resolving Codex's install path at run time.
2. **Gate behavior = fix-loop, then summarize.** Claude addresses Codex's blocking
   findings, re-reviews until clean or a round cap, then hands back with a summary of
   what Codex flagged and what changed. Claude may push back on findings it disagrees
   with, with reasoning (consistent with existing requesting-code-review guidance).
3. **Scope = spec + plan + code, including per-task code review.** Gates at:
   brainstorming (spec), writing-plans (plan), subagent-driven-development
   (**per-task** review and **final** whole-branch review), and requesting-code-review.
4. **Relationship to Codex's Stop gate = independent; document overlap.** Hyperpowers
   gates are self-contained and do not enable/disable/require Codex's Stop gate. Docs
   warn that enabling both yields double code review at stop time.
5. **Absent-Codex behavior = run as today + warning.** Skills are fully functional
   without codex-plugin-cc; they emit a one-line notice that Codex review is being
   skipped. No blocking, no session-start banner.
6. **Claude Code only.** No behavior change in any other harness.

## Availability detection (run-time, per gate)

A gate must answer "can a Codex review actually run *right now*?" — which is stronger
than "is the plugin installed?" Codex can be installed but its CLI missing or
unauthenticated.

**Primary probe.** Resolve Codex's install path, then run
`node <codex-path>/scripts/codex-companion.mjs setup --json`. The JSON includes a
top-level `ready` boolean (`node available && codex CLI available && authenticated`).
`ready: true` → run the gate. `ready: false` or probe fails → degrade (warn, skip).

**Resolving the Codex install path.** Read Claude Code's plugin registry,
`$HOME/.claude/plugins/installed_plugins.json`, find the `codex@openai-codex` entry,
and use its `installPath`. If `$HOME` is unresolvable, the file is missing, or the
key is absent → Codex is not installed → degrade. (No `jq`; the registry is read with
a small, robust parse — exact technique decided in planning, but it must not add a
runtime dependency.)

**Caching within a run.** The probe should run at most once per skill invocation
(not per task) to avoid repeated process spawns; subsequent gates in the same skill
reuse the result. Exact caching mechanism deferred to planning.

**Fail-safe direction.** On *any* uncertainty (probe error, timeout, unexpected
output), degrade to the no-Codex path. A gate must never hard-fail a skill because
Codex misbehaved; the worst case is "no Codex review this run," matching the
absent-Codex experience.

## Gate placements

Each placement runs **after** Claude's existing self-review/refine step and **before**
the existing handback/user-engagement/completion step — an inserted stage, not a
replacement for Claude's own review.

### 1. Brainstorming — spec gate
- **Skill:** `skills/brainstorming/SKILL.md`
- **Existing flow:** write spec → spec self-review (fix inline) → **user reviews spec**.
- **Insert:** after spec self-review, before the user-review gate, run a Codex
  **document** review of the spec file (via `task` with a spec-review prompt).
- **Loop:** Claude addresses blocking findings, updates the spec, re-reviews until
  clean or cap, then proceeds to the user-review gate with a summary of Codex's input.

### 2. Writing-plans — plan gate
- **Skill:** `skills/writing-plans/SKILL.md`
- **Existing flow:** draft plan → present plan to user.
- **Insert:** after the plan is drafted and before it is presented, run a Codex
  **document** review of the plan file (via `task` with a plan-review prompt focused
  on feasibility, task sizing, missing steps, and spec coverage).
- **Loop:** address blocking findings, re-review until clean or cap, then present the
  plan with a summary of Codex's input.

### 3. Subagent-driven development — per-task and final code gates
- **Skill:** `skills/subagent-driven-development/SKILL.md`
- **Per-task:** today, after the implementer self-reviews, a task-reviewer subagent
  gates spec compliance + quality, with a fix-subagent loop until clean. **Insert** a
  Codex `review` of that task's diff (`--base <recorded task base SHA>`) after the
  task-reviewer approves and before the task is marked complete. Findings feed the
  same fix loop.
- **Final:** today, after all tasks, a final whole-branch code-reviewer runs before
  finishing-a-development-branch. **Insert** a Codex `review` of the whole branch
  (`--base <branch base>`) after Claude's final review and before handing to
  finishing-a-development-branch.
- **Cost note:** per-task Codex review is explicitly in scope (maintainer decision)
  and adds a Codex run per task. The availability probe is cached per skill run; each
  task review should default to background where the existing flow allows, to limit
  wall-clock cost. Final tuning deferred to planning.

### 4. Requesting-code-review — code gate
- **Skill:** `skills/requesting-code-review/SKILL.md`
- **Existing flow:** dispatch code-reviewer subagent → act on feedback.
- **Insert:** after the Claude code-reviewer subagent returns and Claude addresses
  its feedback, run a Codex `review` over the same range, feeding findings into the
  same act-on-feedback loop before completion.

## Gate behavior contract (shared)

All gates follow one contract, parameterized by artifact type:

1. **Probe** availability (cached). Not ready → emit the no-Codex-review notice and
   continue the skill unchanged.
2. **Invoke** Codex: `task` for documents (spec/plan), `review` for code (diff range).
3. **Interpret** the result:
   - Code: use the structured `verdict`/`findings`. **Blocking** = `critical` + `high`
     (mapped to hyperpowers' Critical/Important); `medium`/`low` = noted, non-blocking.
   - Document (`task`): prompt asks Codex for the same verdict/severity vocabulary so
     interpretation is uniform; if free-form, Claude extracts blocking items.
4. **Fix loop:** Claude addresses blocking findings (editing the spec/plan, or
   dispatching a fix for code per the skill's existing fix path), then **re-reviews**.
   Repeat until `approve`/no blocking findings or a **round cap** (default small,
   e.g. 2–3; exact value in planning). On hitting the cap with unresolved blocking
   findings, hand back with them clearly listed rather than looping forever.
5. **Push-back:** Claude may decline a finding with explicit reasoning instead of
   fixing, consistent with requesting-code-review's "push back if reviewer is wrong."
6. **Hand back** with a concise summary: Codex's verdict, what was flagged, what was
   fixed, what was declined and why.

### Severity reconciliation
Codex code-review severities are `critical|high|medium|low`; hyperpowers reviewer
prose uses `Critical|Important|Minor`. The gate maps `critical→Critical`,
`high→Important`, `medium|low→Minor`. Document-review prompts instruct Codex to use
this same mapping so all gates speak one vocabulary.

## No-Codex-review warning

When a gate degrades, it emits a single, plain notice at that skill point, e.g.:

```
Note: codex-plugin-cc is not available, so this <spec|plan|code> review will run
without an additional Codex review. Install it for an extra review gate:
  /plugin marketplace add openai/codex-plugin-cc
  /plugin install codex@openai-codex
  /reload-plugins
  /codex:setup
```

This is per-skill and contextual — not a session-start banner. Exact wording finalized
in implementation; it must name codex-plugin-cc, state that the Codex review is being
skipped, and give the install commands.

## Shared implementation surface

To avoid copy-pasting gate logic into five skills, factor the common pieces into a
shared reference the skills point at (mirroring how the repo already shares reviewer
prompt templates):

- **Availability probe + path resolution** — one documented procedure.
- **Invocation recipes** — the exact `codex-companion.mjs review` / `task` call
  shapes, argument conventions, and how to read the JSON.
- **Gate contract** — the fix-loop, severity mapping, and handback summary.
- **No-Codex notice** — the canonical warning text.

Likely a new shared doc (e.g. `skills/<shared>/codex-review-gate.md`) plus per-skill
references that say "at this point, run the Codex review gate (see <shared>) over
<artifact>." Exact location/structure decided in planning. This is **skill content**
(behavior-shaping), so changes follow the writing-skills discipline in CLAUDE.md.

## Documentation changes

- **README** "Claude Code" section: codex-plugin-cc is a prerequisite for the Codex
  review gates; without it the skills work but skip Codex review. Include install
  block and the Node/CLI/auth requirements.
- **CLAUDE.md**: reconcile the inherited upstream "zero-dependency by design" /
  "third-party dependencies belong in their own plugin" language with this fork's
  deliberate dependency policy (codex-plugin-cc is the first such dependency).
- **Overlap note:** document that codex-plugin-cc's own `/codex:setup
  --enable-review-gate` Stop gate overlaps the hyperpowers code gates; enabling both
  yields double code review at stop time.

## Testing

Two layers:

1. **Plumbing (shell, hermetic)** — extend the established test patterns under
   `tests/`. The availability probe and path resolution must accept an env override
   for the registry/codex path (e.g. `HYPERPOWERS_CODEX_PROBE`/`_PLUGINS_FILE`) so
   tests never touch the real `~/.claude` or spawn real Codex. Cases:
   - Codex registry key present + a stubbed `setup --json` returning `ready:true`
     → gate path selected.
   - Key present + `ready:false` (CLI missing / unauthenticated) → degrade + notice.
   - Key absent / `$HOME` unresolvable / probe error/timeout → degrade + notice.
   - Claude-Code-only: non-Claude context never selects the gate.
2. **Skill behavior (evals)** — per CLAUDE.md, skill-content changes need adversarial
   evaluation across sessions in the eval harness. New gate behavior (gate fires after
   self-review and before handback; degrades cleanly; honors the round cap; speaks one
   severity vocabulary) is validated there before/after. Capture evidence with the
   change.

## Out of scope (YAGNI)

- Hard blocking a skill when Codex is unavailable, or auto-installing codex-plugin-cc.
- Enabling/disabling/depending on Codex's own Stop review gate.
- Any non-Claude-Code harness.
- Reviewing artifacts beyond spec/plan/code (e.g. brainstorming questions, commit
  messages).
- A user-facing toggle to disable the gate per session (revisit only if the gate
  proves too costly in practice; degradation already gives an off-switch by not
  installing/authenticating Codex).

## Risks and mitigations

- **Coupling to codex-plugin-cc internals** (script path, CLI flags, output schema).
  Mitigation: resolve the path dynamically; centralize all invocation in the shared
  surface so a Codex update is a one-place fix; fail-safe to degrade on any unexpected
  output; tests stub the contract.
- **Per-task cost/latency.** Mitigation: cache the probe per skill run; prefer
  background review where the flow allows; round cap bounds fix-loop iterations.
- **Infinite fix-loop / thrash.** Mitigation: hard round cap, then hand back with
  unresolved findings listed.
- **Severity vocabulary mismatch.** Mitigation: explicit mapping + document-review
  prompts that request the mapped vocabulary.
- **Skill-content regression** (these are tuned behavior-shaping files). Mitigation:
  follow writing-skills; keep gate logic in a shared reference to minimize edits to
  each tuned SKILL.md; eval before/after.
```
