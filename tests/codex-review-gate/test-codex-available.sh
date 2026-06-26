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

# Create a fake Codex install whose companion script exists on disk, so the
# probe's "record whose companion exists" selection accepts it. Readiness is
# still controlled separately via HYPERPOWERS_CODEX_SETUP_JSON.
make_install() {
  local dir="$1"
  mkdir -p "$dir/scripts"
  : > "$dir/scripts/codex-companion.mjs"
}

# Install a fake companion whose `setup --json` output is driven by env, so the
# retry path can be exercised without a real Codex runtime:
#   PROBE_TEST_MODE    recover|transient|terminal (default recover)
#   PROBE_TEST_COUNTER file path; incremented once per invocation so a test can
#                      assert how many times the probe called the companion.
make_fake_companion() {
  local dir="$1"
  mkdir -p "$dir/scripts"
  cat > "$dir/scripts/codex-companion.mjs" <<'EOF'
import fs from "node:fs";
const counter = process.env.PROBE_TEST_COUNTER;
const mode = process.env.PROBE_TEST_MODE || "recover";
let n = 0;
try { n = parseInt(fs.readFileSync(counter, "utf8"), 10) || 0; } catch (e) {}
try { fs.writeFileSync(counter, String(n + 1)); } catch (e) {}
const transient = { ready: false, auth: { loggedIn: false, detail: "codex app-server exited unexpectedly (exit 1)." } };
const terminal = { ready: false, auth: { loggedIn: false, detail: "Azure OpenAI requires OpenAI authentication" } };
const ok = { ready: true, auth: { loggedIn: true, detail: "Azure OpenAI is configured and does not require OpenAI authentication" } };
let out = ok;
if (mode === "terminal") out = terminal;
else if (mode === "transient") out = transient;
else out = n < 1 ? transient : ok;
process.stdout.write(JSON.stringify(out));
EOF
}

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

# 3. Codex installed (companion present) but not ready -> degrade
make_install "$TMP/codex"
printf '%s' '{"version":2,"plugins":{"codex@openai-codex":[{"installPath":"'"$TMP"'/codex"}]}}' > "$TMP/reg.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/reg.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":false}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "ready:false -> exit 1"
else
  pass "ready:false -> exit 1"
fi

# 4. Codex installed and ready -> exit 0 and print the install path
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

# 6. Codex key present but companion missing (stale install path) -> degrade
printf '%s' '{"version":2,"plugins":{"codex@openai-codex":[{"installPath":"'"$TMP"'/gone"}]}}' > "$TMP/stale.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/stale.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "stale install (no companion) -> exit 1"
else
  pass "stale install (no companion) -> exit 1"
fi

# 7. Multiple records: first is stale (no companion), a later one is valid ->
#    the probe must skip the stale record and select the valid install.
make_install "$TMP/codex2"
printf '%s' '{"version":2,"plugins":{"codex@openai-codex":[{"installPath":"'"$TMP"'/gone"},{"installPath":"'"$TMP"'/codex2"}]}}' > "$TMP/multi.json"
out="$(HYPERPOWERS_PLUGINS_FILE="$TMP/multi.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
        bash "$PROBE" 2>/dev/null)"
rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$TMP/codex2" ]; then
  pass "multi-record skips stale -> picks valid install"
else
  fail "multi-record skips stale -> picks valid install (rc=$rc out=$out)"
fi

# 8. Transient app-server error on the first probe, healthy on retry ->
#    the probe must retry and ultimately succeed (exit 0 + install path).
make_fake_companion "$TMP/codex_retry"
printf '%s' '{"version":2,"plugins":{"codex@openai-codex":[{"installPath":"'"$TMP"'/codex_retry"}]}}' > "$TMP/retry.json"
: > "$TMP/recover_counter"
out="$(HYPERPOWERS_PLUGINS_FILE="$TMP/retry.json" PROBE_TEST_MODE=recover \
        PROBE_TEST_COUNTER="$TMP/recover_counter" HYPERPOWERS_PROBE_RETRY_DELAY=0 \
        bash "$PROBE" 2>/dev/null)"
rc=$?
calls="$(cat "$TMP/recover_counter")"
if [ "$rc" -eq 0 ] && [ "$out" = "$TMP/codex_retry" ] && [ "$calls" -ge 2 ]; then
  pass "transient-then-ready -> retries, exit 0 (calls=$calls)"
else
  fail "transient-then-ready -> retries, exit 0 (rc=$rc out=$out calls=$calls)"
fi

# 9. Persistent transient error -> retries up to the cap, then degrades (exit 1).
#    Default cap is 2 retries (3 attempts total).
: > "$TMP/transient_counter"
if HYPERPOWERS_PLUGINS_FILE="$TMP/retry.json" PROBE_TEST_MODE=transient \
     PROBE_TEST_COUNTER="$TMP/transient_counter" HYPERPOWERS_PROBE_RETRY_DELAY=0 \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "persistent transient -> exit 1"
else
  calls="$(cat "$TMP/transient_counter")"
  if [ "$calls" -eq 3 ]; then
    pass "persistent transient -> exit 1 after cap (calls=$calls)"
  else
    fail "persistent transient -> exit 1 after cap (expected 3 calls, got $calls)"
  fi
fi

# 10. Terminal not-ready reason (not logged in) -> degrade immediately, NO retry.
: > "$TMP/terminal_counter"
if HYPERPOWERS_PLUGINS_FILE="$TMP/retry.json" PROBE_TEST_MODE=terminal \
     PROBE_TEST_COUNTER="$TMP/terminal_counter" HYPERPOWERS_PROBE_RETRY_DELAY=0 \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "terminal not-ready -> exit 1"
else
  calls="$(cat "$TMP/terminal_counter")"
  if [ "$calls" -eq 1 ]; then
    pass "terminal not-ready -> exit 1 without retry (calls=$calls)"
  else
    fail "terminal not-ready -> exit 1 without retry (expected 1 call, got $calls)"
  fi
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "STATUS: FAILED ($FAILURES failure(s))"
  exit 1
fi
echo "STATUS: PASSED"
