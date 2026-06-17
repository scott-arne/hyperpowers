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

# Resolve the Codex install path from the first install record for the key.
install_path="$(node -e '
  const fs = require("fs");
  try {
    const reg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const recs = reg && reg.plugins && reg.plugins["codex@openai-codex"];
    const p = Array.isArray(recs) && recs[0] && recs[0].installPath;
    if (typeof p === "string" && p) process.stdout.write(p);
  } catch (e) { /* degrade */ }
' "$registry" 2>/dev/null)"

[ -n "$install_path" ] || exit 1

# Determine readiness. Tests inject the JSON; production runs the companion.
if [ -n "${HYPERPOWERS_CODEX_SETUP_JSON:-}" ]; then
  setup_json="$HYPERPOWERS_CODEX_SETUP_JSON"
else
  companion="$install_path/scripts/codex-companion.mjs"
  [ -f "$companion" ] || exit 1
  setup_json="$(node "$companion" setup --json 2>/dev/null)" || exit 1
fi

ready="$(printf '%s' "$setup_json" | node -e '
  const fs = require("fs");
  try {
    const d = JSON.parse(fs.readFileSync(0, "utf8"));
    process.stdout.write(d && d.ready === true ? "yes" : "no");
  } catch (e) { process.stdout.write("no"); }
' 2>/dev/null)"

[ "$ready" = "yes" ] || exit 1

printf '%s\n' "$install_path"
exit 0
