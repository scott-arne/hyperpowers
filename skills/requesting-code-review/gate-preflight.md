## 1. Preflight availability

Run the preflight by its absolute path inside the installed plugin
(`$CLAUDE_PLUGIN_ROOT` is set by Claude Code to this plugin's install
directory):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/requesting-code-review/scripts/codex-preflight"
```

(When working inside a hyperpowers dev checkout rather than an installed
plugin, `$CLAUDE_PLUGIN_ROOT` is unset; run
`bash skills/requesting-code-review/scripts/codex-preflight` from the repo
root instead. If it is unset in an *installed-plugin* session, resolve the
newest install: `ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1`.)

It prints one JSON line. Branch on `.status`:

- **`"ok"`** — a Codex review can run. Capture `.codexPath` as `CODEX_PATH`
  and `.codexVersion` as `CODEX_VERSION` (report it in the §6 hand-back).
  The JSON field paths in §4b's payloads are verified against codex-plugin-cc
  **1.0.5–1.0.6**; on another version, confirm a field exists in the actual
  payload before relying on it.
- **`"not-installed"`** — emit the **No-Codex notice** (§2) and continue the
  skill unchanged. Do not treat this as an error.
- **`"not-ready"`** — the plugin is installed but Codex is not ready
  (`.reason` says why: not authenticated, CLI missing, transient handshake
  failure that outlasted retries). Tell the user once:
  "Note [status: not-ready]: codex-plugin-cc is installed but not ready (<.reason>), so this review will run without an additional Codex review." Then continue exactly
  as the §2 degrade path.
- **`"stale-broker"`** — the plugin is installed but this repo's companion
  broker is dead (its temp dir was likely purged mid-session; the session-
  start janitor clears these at startup/compact, so this means it died
  since). Tell the user once, quoting `.recovery` verbatim:
  "Note [status: stale-broker]: the Codex companion broker for this repo is stale, so this review will run without a Codex review. To restore Codex for the next gate, run this in a terminal: <.recovery>" — then continue as the §2 degrade path.
  The next gate re-runs preflight and picks the recovery up automatically.
- **Non-zero exit** (internal failure — the preflight tooling itself broke) —
  degrade exactly like §2, but with its own attribution. Tell the user once:
  "Note [status: preflight-error]: the Codex preflight failed (<stderr summary>), so this review will run without an additional Codex review."
  Do not treat this as an error and do not claim Codex is not installed.

**Record every degrade durably.** Whenever a gate proceeds on a degrade
branch (`not-installed`, `not-ready`, `stale-broker`, `preflight-error`),
append a ledger event before continuing — document gates:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class degraded-gate --gate <spec|plan> --status <token> --note "<one line; include the task brief / plan path if one exists — the sweep uses it as a breadcrumb>"
```

Code gates additionally record the exact range that will ship unreviewed:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class degraded-gate --gate <task|final|adhoc> --base <the gate's BASE sha> --head "$(git rev-parse HEAD)" --status <token> --note "<one line; include the task brief / plan path if one exists — the sweep uses it as a breadcrumb>"
```

`--gate-dir` is omitted here on purpose: preflight runs BEFORE §3 creates
`GATE_DIR`, and `gateDir` is a forensic breadcrumb only — class-1 preflight
events legitimately carry `gateDir:null`. If a `GATE_DIR` already exists
for this gate when the degrade occurs, passing `--gate-dir "$GATE_DIR"` is
welcome but never required.

If the append itself fails, say so loudly in the §6 hand-back ("ungated
event could NOT be recorded — note this manually") and continue — a
bookkeeping failure never blocks the gate.

**Re-surface pending work on healthy preflight.** When `.status` is `ok`,
check the backlog once per skill run: `ungated-ledger pending --count .` —
if `.count` > 0, tell the user once:
"N ungated review item(s) pending sweep in this repo — say \"run the review sweep\" (§7) to clear them."
Then proceed with this gate normally; the notice never blocks or delays it.

Preflight at most once per skill run and reuse the result for every gate in
that run. Every degrade notice must name its status (`not-installed`,
`not-ready`, `stale-broker`, or `preflight-error`) so the §6 hand-back — and future transcript
mining — can attribute exactly why a gate ran without Codex.

## 2. No-Codex notice (degrade path)

When preflight returns `not-installed`, tell the user once, at this gate:

```
Note [status: not-installed]: codex-plugin-cc is not available, so this review will run without an additional Codex review. Install it for an extra review gate:
  /plugin marketplace add openai/codex-plugin-cc
  /plugin install codex@openai-codex
  /reload-plugins
  /codex:setup
```

Then proceed exactly as the skill would without this gate.

