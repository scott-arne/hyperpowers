# Codex Review Gate

A shared stage-gate that asks Codex (via codex-plugin-cc) to review an artifact
**after** Claude has done its own review/refine/fix pass and **before** the user
is re-engaged or the work is declared complete. Referenced by brainstorming,
writing-plans, subagent-driven-development, and requesting-code-review.

**Claude Code only.** Run this gate only under Claude Code. In any other harness,
skip it silently — do not run the probe, do not emit the notice.

## 1. Probe availability

Run the probe by its absolute path inside the installed plugin (`$CLAUDE_PLUGIN_ROOT`
is set by Claude Code to this plugin's install directory):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/requesting-code-review/scripts/codex-available.sh"
```

(When working inside a hyperpowers dev checkout rather than an installed plugin,
`$CLAUDE_PLUGIN_ROOT` is unset; run `bash skills/requesting-code-review/scripts/codex-available.sh`
from the repo root instead.)

- **Exit 0:** a Codex review can run. stdout is the Codex install path — capture it
  as `CODEX_PATH` for the invocation step.
- **Non-zero exit:** Codex is unavailable. Emit the **No-Codex notice** (below) at
  this point and continue the skill unchanged. Do not treat this as an error.

Probe at most once per skill run and reuse the result for every gate in that run.

## 2. No-Codex notice (degrade path)

When the probe exits non-zero, tell the user once, at this gate:

```
Note: codex-plugin-cc is not available, so this review will run without an
additional Codex review. Install it for an extra review gate:
  /plugin marketplace add openai/codex-plugin-cc
  /plugin install codex@openai-codex
  /reload-plugins
  /codex:setup
```

Then proceed exactly as the skill would without this gate.

## 3. Invoke Codex

**Documents (spec, plan)** — use `task`, read-only (no `--write`):

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task "Review the document at <ABSOLUTE_PATH> for completeness, internal consistency, ambiguity, and scope. Do not edit anything. Give a verdict of 'approve' or 'needs-attention', then list findings, each with a severity of critical, high, medium, or low, a short title, and a recommendation."
```

Read Codex's free-form reply and extract its verdict and findings.

**Code (diff range)** — use `review`:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" review --base <BASE_SHA> --wait
```

`<BASE_SHA>` is the range start: the recorded task base for a per-task review, or
the branch merge-base for a final whole-branch review. `review` returns JSON with
`verdict` (`approve` | `needs-attention`) and `findings[]` (each carrying
`severity` of `critical|high|medium|low`, `title`, `body`, `file`, `line_start`,
`line_end`, `recommendation`).

## 4. Interpret — severity mapping

Map Codex severities to Hyperpowers' vocabulary:

| Codex | Hyperpowers | Blocking? |
|-------|-------------|-----------|
| critical | Critical | yes |
| high | Important | yes |
| medium / low | Minor | no |

**Blocking = Critical + Important.** Minor findings are noted, not fixed in the loop.

## 5. Fix-and-re-review loop (cap = 2 rounds)

1. If verdict is `approve` and there are no blocking findings → done; go to step 6.
2. Otherwise address each blocking finding: for a document, edit the spec/plan; for
   code, dispatch a fix through the skill's existing fix path (e.g. SDD's fix
   subagent). You MAY decline a finding with explicit reasoning instead of fixing it.
3. Re-run the same Codex invocation over the updated artifact.
4. Repeat until `approve`/no blocking findings, or **2 rounds** have run. On reaching
   the cap with unresolved blocking findings, stop looping and hand back with them
   listed — do not loop indefinitely.

## 6. Hand back

Summarize concisely before returning to the skill's normal next step:

- Codex verdict (and round count if it looped),
- what Codex flagged (by mapped severity),
- what was fixed,
- what was declined and why,
- any unresolved blocking findings if the cap was hit.

Then continue the skill (present to user / mark complete / finish branch).
