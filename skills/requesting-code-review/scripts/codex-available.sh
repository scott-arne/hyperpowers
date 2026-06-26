#!/usr/bin/env bash
# Probe whether a Codex review can run right now. Resolves codex-plugin-cc's
# install path from Claude Code's plugin registry, then asks the Codex
# companion whether it is ready (CLI present + authenticated).
#
# On success: print the Codex install path to stdout and exit 0.
# On any failure or uncertainty: exit 1 with no stdout (caller degrades to
# "no Codex review"). This probe never hard-errors a calling skill.
#
# Test overrides:
#   HYPERPOWERS_PLUGINS_FILE      path to installed_plugins.json
#   HYPERPOWERS_CODEX_SETUP_JSON  literal JSON used instead of running setup
set -uo pipefail

registry="${HYPERPOWERS_PLUGINS_FILE:-${HOME:-}/.claude/plugins/installed_plugins.json}"

[ -f "$registry" ] || exit 1
command -v node >/dev/null 2>&1 || exit 1

# Resolve the Codex install path from the registry. The key maps to an array of
# install records; pick the last one whose companion script actually exists on
# disk, so a stale record (uninstalled/old version) is skipped in favor of a
# live install. node does the existence check while it holds the parsed records.
install_path="$(node -e '
  const fs = require("fs");
  const path = require("path");
  try {
    const reg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const recs = reg && reg.plugins && reg.plugins["codex@openai-codex"];
    if (!Array.isArray(recs)) process.exit(0);
    for (let i = recs.length - 1; i >= 0; i--) {
      const p = recs[i] && recs[i].installPath;
      if (typeof p !== "string" || !p) continue;
      if (fs.existsSync(path.join(p, "scripts", "codex-companion.mjs"))) {
        process.stdout.write(p);
        break;
      }
    }
  } catch (e) { /* degrade */ }
' "$registry" 2>/dev/null)"

[ -n "$install_path" ] || exit 1
companion="$install_path/scripts/codex-companion.mjs"

# Determine readiness, retrying transient failures. The companion verifies auth
# by spawning `codex app-server` and doing a live JSON-RPC handshake against the
# shared sqlite state under ~/.codex. That handshake intermittently loses a lock
# race against a concurrently-running Codex session and reports
# "app-server exited unexpectedly", which the probe would otherwise mistake for
# "Codex unavailable". Such transient runtime errors are retried; terminal
# reasons (Codex not installed, genuinely not authenticated) are not.
max_retries="${HYPERPOWERS_PROBE_MAX_RETRIES:-2}"
retry_delay="${HYPERPOWERS_PROBE_RETRY_DELAY:-0.5}"

# Classify one setup report: "yes" (ready), "retry" (transient handshake
# failure, worth another attempt), or "no" (terminal — do not retry).
classify() {
  printf '%s' "$1" | node -e '
    const fs = require("fs");
    let verdict = "no";
    try {
      const d = JSON.parse(fs.readFileSync(0, "utf8"));
      if (d && d.ready === true) {
        verdict = "yes";
      } else {
        const detail = (d && d.auth && typeof d.auth.detail === "string") ? d.auth.detail : "";
        // Live app-server handshake hiccups — retryable under contention.
        const transient = /exited unexpectedly|connection closed|app-server (?:client )?is closed|stdin is not available|broker connection is not connected|Failed to parse codex app-server/i;
        verdict = transient.test(detail) ? "retry" : "no";
      }
    } catch (e) { verdict = "no"; }
    process.stdout.write(verdict);
  ' 2>/dev/null
}

attempt=0
while :; do
  # Tests inject the JSON; production runs the companion.
  if [ -n "${HYPERPOWERS_CODEX_SETUP_JSON:-}" ]; then
    setup_json="$HYPERPOWERS_CODEX_SETUP_JSON"
  else
    setup_json="$(node "$companion" setup --json 2>/dev/null)" || setup_json=""
  fi

  verdict="$(classify "$setup_json")"
  case "$verdict" in
    yes)
      printf '%s\n' "$install_path"
      exit 0
      ;;
    retry)
      if [ "$attempt" -lt "$max_retries" ]; then
        attempt=$((attempt + 1))
        sleep "$retry_delay"
        continue
      fi
      exit 1
      ;;
    *)
      exit 1
      ;;
  esac
done
