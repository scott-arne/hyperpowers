#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROBE="$REPO_ROOT/skills/requesting-code-review/scripts/codex-available.sh"

FAILURES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "codex-available probe tests"

# 1. Missing registry -> degrade (exit 1)
if HYPERPOWERS_PLUGINS_FILE="$TMP/nope.json" bash "$PROBE" >/dev/null 2>&1; then
  fail "missing registry -> exit 1"
else
  pass "missing registry -> exit 1"
fi

# 2. Registry without the codex key -> degrade even if 'ready'
printf '%s' '{"version":2,"plugins":{"superpowers@x":[{"installPath":"/p"}]}}' > "$TMP/nocodex.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/nocodex.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "no codex key -> exit 1"
else
  pass "no codex key -> exit 1"
fi

# 3. Codex present but not ready -> degrade
printf '%s' '{"version":2,"plugins":{"codex@openai-codex":[{"installPath":"'"$TMP"'/codex"}]}}' > "$TMP/reg.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/reg.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":false}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "ready:false -> exit 1"
else
  pass "ready:false -> exit 1"
fi

# 4. Codex present and ready -> exit 0 and print the install path
out="$(HYPERPOWERS_PLUGINS_FILE="$TMP/reg.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
        bash "$PROBE" 2>/dev/null)"
rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$TMP/codex" ]; then
  pass "ready:true -> exit 0 + install path"
else
  fail "ready:true -> exit 0 + install path (rc=$rc out=$out)"
fi

# 5. Malformed registry JSON -> degrade
printf '%s' 'not json{' > "$TMP/bad.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/bad.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "malformed registry -> exit 1"
else
  pass "malformed registry -> exit 1"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "STATUS: FAILED ($FAILURES failure(s))"
  exit 1
fi
echo "STATUS: PASSED"
