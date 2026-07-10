# Codex Approach Gate

A conditional, **one-shot** Codex consultation during brainstorming's approach exploration. Claude Code only; on any other harness skip silently. One shot means: no fix loop, no round ledger, no re-review — Codex contributes approaches once, then the normal flow owns everything.

## When It Fires

Fire when, while formulating approaches after the clarifying questions are answered, there are **≥2 genuinely different viable architectures, algorithms, or data models with materially different tradeoffs** — not variations of one shape. Fire when your human partner **explicitly requests Codex input** on approaches (any phrasing), even for a task that looks straightforward. Skip silently when the task is trivial or mechanical: a single obvious implementation, a config change, a small fix — the existing flow proceeds unchanged.

## Probe and Degrade

Run the §1 probe from [../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md) (at most once per skill run; reuse the result). If Codex is unavailable, tell your human partner once — "Note: codex-plugin-cc is not available, so this brainstorm proceeds without independent Codex approaches." — followed by the same four install lines §2 uses, then continue exactly as brainstorming works today. An incomplete or failed call is handled the same way: no Codex input, noted once, never blocking, never retried into a loop.

The §2 install instructions from [../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md):

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

## The Blind Handoff

Write `approach-context.md` into the per-run scratch dir from `../requesting-code-review/scripts/codex-review-dir` (invocation below). Contents: (a) the original idea, verbatim; (b) each clarifying question and your human partner's answer; (c) relevant codebase **facts** — paths, constraints, existing patterns. **EXCLUDE Claude's own candidate approaches, preferences, or framings** — Codex's ideas must be independent, not anchored.

Run the scratch dir helper once at gate start and capture its output as `SCRATCH_DIR`:

```bash
SCRATCH_DIR="$(bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/codex-review-dir")"
```

(In a hyperpowers dev checkout `$CLAUDE_PLUGIN_ROOT` is unset; the `:-.` fallback runs `skills/requesting-code-review/scripts/codex-review-dir` from the repo root.)

## Invocation

One foreground call, read-only, with the explicit 600000 ms (10-minute) timeout:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --prompt-file <APPROACH_PROMPT_PATH>
```

The prompt file points Codex at `approach-context.md` and requires this output shape (copy it into the prompt so Codex has the schema in its own context):

```markdown
Approaches (2-3, each genuinely different):
- name: ...
  how-it-works: ...
  tradeoffs: ...
  when-it-wins: ...
  rough-complexity: trivial|moderate|high
```

Read-only: the prompt instructs "Do not edit anything."

## Aggregation

After the call: (a) **dedupe** — where Codex independently converged on an approach you also formed, merge them and label the convergence (independent agreement is a confidence signal); (b) **polish** viable Codex approaches into the house presentation format; (c) **discard** inapplicable ones with a one-line reason that stays visible in the presentation; (d) present the combined shortlist through the existing "propose 2-3 approaches" step with light provenance tags — `(Codex)`, `(both converged)` — and a single recommendation. **Judge approaches on merits, not origin — your own approaches get no home-team advantage.**
