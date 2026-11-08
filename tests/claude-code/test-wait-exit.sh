#!/usr/bin/env bash
# Regression check for skills/finishing-a-development-branch/scripts/wait-exit.
#
# Finish runs the full suite after the SDD ledger is gone, so a suite longer
# than one foreground tool call cannot use tracked-job. It runs in the
# harness's tracked background option and writes its exit status to a file;
# the session waits on that file in the foreground with this helper, which
# keeps the turn open (an editor such as Zed shows the session working).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WAIT_EXIT="$REPO_ROOT/skills/finishing-a-development-branch/scripts/wait-exit"

failures=0
TEST_ROOT=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || { echo "no temporary directory" >&2; exit 1; }
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 1
case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) echo "refusing temporary root $TEST_ROOT" >&2; exit 1 ;; esac
cleanup() { case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) return ;; esac; rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

# run <args...>: sets out and rc without tripping errexit.
run() { rc=0; out=$(bash "$WAIT_EXIT" "$@" 2>/dev/null) || rc=$?; }

echo "=== wait-exit ==="

run
if [ "$rc" -eq 2 ]; then pass "no arguments is a usage error (exit 2)"; else fail "no arguments (rc=$rc out=$out)"; fi
run "$TEST_ROOT/x"
if [ "$rc" -eq 2 ]; then pass "a missing --max-ms is a usage error"; else fail "missing --max-ms (rc=$rc out=$out)"; fi
for bad in 0 -5 abc 1.5 ""; do
    run "$TEST_ROOT/x" --max-ms "$bad"
    if [ "$rc" -eq 2 ]; then pass "--max-ms '$bad' is a usage error"; else fail "--max-ms '$bad' (rc=$rc out=$out)"; fi
done

f="$TEST_ROOT/zero.exit"; printf '0\n' > "$f"
run "$f" --max-ms 1000
if [ "$rc" -eq 0 ] && [ "$out" = "exited code=0" ]; then pass "an exit file holding 0 prints 'exited code=0', exit 0"; else fail "zero (rc=$rc out=$out)"; fi

f="$TEST_ROOT/three.exit"; printf '3' > "$f"
run "$f" --max-ms 1000
if [ "$rc" -eq 1 ] && [ "$out" = "exited code=3" ]; then pass "an exit file holding 3 prints 'exited code=3', exit 1"; else fail "three (rc=$rc out=$out)"; fi

f="$TEST_ROOT/spaced.exit"; printf '  7 \n\n' > "$f"
run "$f" --max-ms 1000
if [ "$rc" -eq 1 ] && [ "$out" = "exited code=7" ]; then pass "surrounding whitespace is ignored"; else fail "spaced (rc=$rc out=$out)"; fi

start=$(date +%s)
run "$TEST_ROOT/absent.exit" --max-ms 600
elapsed=$(( $(date +%s) - start ))
if [ "$rc" -eq 3 ] && [ "$out" = "running" ]; then pass "no exit file by the bound prints 'running', exit 3"; else fail "absent (rc=$rc out=$out)"; fi
if [ "$elapsed" -le 3 ]; then pass "returns at the bound (${elapsed}s for 600 ms)"; else fail "took ${elapsed}s for a 600 ms bound"; fi

# A loaded host makes each poll cost more than its sleep. The bound is the
# clock's, so a slow poll cannot push the wait past the caller's tool timeout
# (a 540000 ms bound counted in polls ran past 600 s in a live session).
shim="$TEST_ROOT/slow-bin"; mkdir -p "$shim"
printf '#!/bin/sh\nsleep 0.5\nexec /usr/bin/tr "$@"\n' > "$shim/tr"; chmod +x "$shim/tr"
f="$TEST_ROOT/slow.exit"; : > "$f"
start=$(date +%s)
rc=0; out=$(PATH="$shim:$PATH" bash "$WAIT_EXIT" "$f" --max-ms 2000 2>/dev/null) || rc=$?
elapsed=$(( $(date +%s) - start ))
if [ "$rc" -eq 3 ] && [ "$out" = "running" ]; then pass "slow polls still end in 'running'"; else fail "slow (rc=$rc out=$out)"; fi
if [ "$elapsed" -le 4 ]; then pass "slow polls stay within the bound (${elapsed}s for 2000 ms)"; else fail "slow polls took ${elapsed}s for a 2000 ms bound"; fi

f="$TEST_ROOT/empty.exit"; : > "$f"
run "$f" --max-ms 400
if [ "$rc" -eq 3 ] && [ "$out" = "running" ]; then pass "an empty exit file (write in progress) reads as running"; else fail "empty (rc=$rc out=$out)"; fi

f="$TEST_ROOT/late.exit"
( sleep 1; printf '0\n' > "$f.tmp" && mv "$f.tmp" "$f" ) &
writer=$!
start=$(date +%s)
run "$f" --max-ms 20000
elapsed=$(( $(date +%s) - start ))
wait "$writer" || true
if [ "$rc" -eq 0 ] && [ "$out" = "exited code=0" ]; then pass "an exit file written mid-wait ends the wait"; else fail "late (rc=$rc out=$out)"; fi
if [ "$elapsed" -le 5 ]; then pass "returns soon after the write (${elapsed}s)"; else fail "took ${elapsed}s after a 1s write"; fi

echo
if [ "$failures" -eq 0 ]; then echo "PASSED"; else echo "FAILED ($failures)"; exit 1; fi
