#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PF="$REPO_ROOT/skills/requesting-code-review/scripts/codex-preflight"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { # <out> <fragment> <desc>
  printf '%s' "$1" | grep -Fq "$2" && pass "$3" || { fail "$3 (got: $1)"; }
}

work="$(mktemp -d "${TMPDIR:-/tmp}/pf-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# Fake plugin install: registry + install dir with companion + manifest
install="$work/install"; mkdir -p "$install/scripts" "$install/.claude-plugin"
touch "$install/scripts/codex-companion.mjs"
printf '{"version":"9.9.9"}\n' > "$install/.claude-plugin/plugin.json"
registry="$work/installed_plugins.json"
cat > "$registry" <<EOF
{ "plugins": { "codex@openai-codex": [ { "installPath": "$install" } ] } }
EOF

# Fake repo + state root with a DEAD broker (purged sessionDir)
repo="$work/myrepo"; mkdir -p "$repo"; git -C "$repo" init -q
root="$work/state"; sd="$root/myrepo-0123456789abcdef"; mkdir -p "$sd"
cat > "$sd/broker.json" <<EOF
{ "endpoint": "unix:$work/gone/broker.sock", "pidFile": "x", "logFile": "x",
  "sessionDir": "$work/gone", "pid": $$ }
EOF

READY='{"ready":true}'
NOTREADY='{"ready":false,"auth":{"detail":"not authenticated"}}'

run() { # <setup-json> [state-root]
  HYPERPOWERS_PLUGINS_FILE="$registry" \
  HYPERPOWERS_CODEX_SETUP_JSON="$1" \
  HYPERPOWERS_CODEX_STATE_ROOT="${2:-$root}" \
  HYPERPOWERS_PROBE_MAX_RETRIES=0 \
  bash "$PF" "$repo"
}

echo "codex-preflight:"

# stale broker beats setup (checked first; setup json ready is irrelevant here)
out="$(run "$READY")"
expect "$out" '"status":"stale-broker"' "dead broker -> stale-broker"
expect "$out" 'broker.json.stale-' "stale-broker carries recovery command"
expect "$out" "$sd/broker.json" "recovery names the repo state dir"

# healthy path: remove broker record entirely (absent is ok), ready -> ok
rm "$sd/broker.json"
out="$(run "$READY")"
expect "$out" '"status":"ok"' "ready + no broker -> ok"
expect "$out" "\"codexPath\":\"$install\"" "ok carries codexPath"
expect "$out" '"codexVersion":"9.9.9"' "ok carries codexVersion"

# not ready -> not-ready with reason
out="$(run "$NOTREADY")"
expect "$out" '"status":"not-ready"' "ready:false -> not-ready"
expect "$out" 'not authenticated' "not-ready carries reason"

# CLI missing -> not-ready naming the failing dimension
CLIMISSING='{"ready":false,"codex":{"ok":false,"detail":"codex CLI not found"}}'
out="$(run "$CLIMISSING")"
expect "$out" '"status":"not-ready"' "cli missing -> not-ready"
expect "$out" 'codex CLI not found' "not-ready names the failing dimension"

# a failing helper is a preflight INTERNAL failure (non-zero), never ok
failing="$work/failing-helper"; printf '#!/usr/bin/env bash\nexit 1\n' > "$failing"; chmod +x "$failing"
HYPERPOWERS_PLUGINS_FILE="$registry" HYPERPOWERS_CODEX_SETUP_JSON="$READY" \
HYPERPOWERS_BROKER_STATE_DIR_BIN="$failing" \
bash "$PF" "$repo" >/dev/null 2>&1 && fail "failing helper -> non-zero exit" || pass "failing helper -> non-zero exit"

# garbage helper output is an internal failure too
garbage="$work/garbage-helper"; printf '#!/usr/bin/env bash\necho not-json\n' > "$garbage"; chmod +x "$garbage"
HYPERPOWERS_PLUGINS_FILE="$registry" HYPERPOWERS_CODEX_SETUP_JSON="$READY" \
HYPERPOWERS_BROKER_STATE_DIR_BIN="$garbage" \
bash "$PF" "$repo" >/dev/null 2>&1 && fail "garbage helper -> non-zero exit" || pass "garbage helper -> non-zero exit"

# not installed -> not-installed
out="$(HYPERPOWERS_PLUGINS_FILE="$work/nope.json" HYPERPOWERS_CODEX_SETUP_JSON="$READY" bash "$PF" "$repo")"
expect "$out" '"status":"not-installed"' "missing registry -> not-installed"

# every determinate status exits 0
run "$NOTREADY" >/dev/null; [ $? -eq 0 ] && pass "not-ready exits 0" || fail "not-ready exits 0"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
