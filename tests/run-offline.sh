#!/usr/bin/env bash
# The documented offline set (docs/testing.md, "Plugin tests"), one suite per
# bash call. Prints FAILED lines and a count; exit 0 only when everything
# passed. Logs go to $OUT (default: a fresh temporary directory). Never runs
# the live suites: those spawn the real claude CLI.
set -u
cd "$(dirname "$0")/.." || exit 2
OUT=${OUT:-$(mktemp -d "${TMPDIR:-/tmp}/offline-logs.XXXXXX")}
fails=0
run() {
  local name
  name=$(printf '%s' "$1" | tr '/' '_')
  if ! bash "$1" > "$OUT/$name.log" 2>&1; then echo "FAILED: $1 (log: $OUT/$name.log)"; fails=$((fails + 1)); fi
}
for t in tests/hooks/test-*.sh tests/codex-review-gate/test-*.sh tests/sdd/test-*.sh tests/packaging/test-*.sh tests/writing-skills/test-*.sh tests/systematic-debugging/test-*.sh tests/shell-lint/test-*.sh tests/opencode/test-*.sh tests/kimi/test-*.sh tests/antigravity/test-*.sh; do
  case "$t" in tests/opencode/test-tools.sh|tests/opencode/test-priority.sh) continue ;; esac
  [ -f "$t" ] && run "$t"
done
for t in tests/claude-code/test-sdd-dir-path.sh tests/claude-code/test-codex-review-dir-path.sh tests/claude-code/test-delivery-resolution.sh tests/claude-code/test-worktree-path-policy.sh; do run "$t"; done
( cd tests/brainstorm-server && npm test > "$OUT/brainstorm-npm.log" 2>&1 ) || { echo "FAILED: tests/brainstorm-server npm test (log: $OUT/brainstorm-npm.log)"; fails=$((fails + 1)); }
run tests/brainstorm-server/windows-lifecycle.test.sh
node tests/pi/test-pi-extension.mjs > "$OUT/pi.log" 2>&1 || { echo "FAILED: tests/pi/test-pi-extension.mjs (log: $OUT/pi.log)"; fails=$((fails + 1)); }
echo "offline set: $fails failed (logs: $OUT)"
[ "$fails" -eq 0 ]
