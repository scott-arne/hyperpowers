#!/usr/bin/env bash
# Back-compat probe wrapper over codex-preflight. Contract unchanged:
# on ready, print the Codex install path (line 1) and version (line 2),
# exit 0; on any other status or failure, exit 1 with no stdout.
# All HYPERPOWERS_* test overrides pass through via the environment.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
out="$(bash "$SCRIPT_DIR/codex-preflight" "${1:-.}" 2>/dev/null)" || exit 1
printf '%s' "$out" | node -e '
  try {
    const d = JSON.parse(require("fs").readFileSync(0, "utf8"));
    if (d.status !== "ok") process.exit(1);
    process.stdout.write(d.codexPath + "\n" + (d.codexVersion || "unknown") + "\n");
  } catch (e) { process.exit(1); }
' || exit 1
exit 0
