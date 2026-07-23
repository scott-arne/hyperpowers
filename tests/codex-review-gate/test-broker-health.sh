#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BH="$REPO_ROOT/skills/requesting-code-review/scripts/broker-health"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# Export pattern for healthy case using pid $$ (bash command)
export HYPERPOWERS_BROKER_CMD_PATTERN='bash|test-broker-health'

# status <json> <expected> <description>
expect_status() {
  local out="$1" want="$2" desc="$3"
  if printf '%s' "$out" | grep -Fq "\"status\":\"$want\""; then
    pass "$desc"
  else
    fail "$desc (got: $out)"
  fi
}

work="$(mktemp -d "${TMPDIR:-/tmp}/bh-test.XXXXXX")"
sleep_pid=""
listener_pid=""
trap 'rm -rf "$work"; [ -n "$sleep_pid" ] && kill "$sleep_pid" 2>/dev/null || true; [ -n "$listener_pid" ] && kill "$listener_pid" 2>/dev/null || true' EXIT

mk_broker() { # <dir> <socket-path> <pid> <session-dir>
  mkdir -p "$1"
  cat > "$1/broker.json" <<EOF
{
  "endpoint": "unix:$2",
  "pidFile": "$4/broker.pid",
  "logFile": "$4/broker.log",
  "sessionDir": "$4",
  "pid": $3
}
EOF
}

echo "broker-health:"

# absent: no broker.json at all
mkdir -p "$work/absent"
expect_status "$(bash "$BH" "$work/absent")" absent "no broker.json -> absent"

# healthy: sessionDir + socket file exist, pid is us (alive)
sdir="$work/live-session"; mkdir -p "$sdir"; touch "$sdir/broker.sock"
mk_broker "$work/healthy" "$sdir/broker.sock" $$ "$sdir"
expect_status "$(bash "$BH" "$work/healthy")" healthy "live socket + live pid -> healthy"

# dead: sessionDir purged (the macOS signature)
mk_broker "$work/purged" "$work/gone/broker.sock" $$ "$work/gone"
expect_status "$(bash "$BH" "$work/purged")" dead "purged sessionDir -> dead"

# dead: sessionDir present, socket missing
sdir2="$work/s2"; mkdir -p "$sdir2"
mk_broker "$work/nosock" "$sdir2/broker.sock" $$ "$sdir2"
expect_status "$(bash "$BH" "$work/nosock")" dead "missing socket -> dead"

# dead: socket present, pid not alive (spawn-and-reap a real pid)
sdir3="$work/s3"; mkdir -p "$sdir3"; touch "$sdir3/broker.sock"
sleep 0.01 & deadpid=$!; wait "$deadpid" 2>/dev/null
mk_broker "$work/deadpid" "$sdir3/broker.sock" "$deadpid" "$sdir3"
expect_status "$(bash "$BH" "$work/deadpid")" dead "dead pid -> dead"

# unknown: malformed JSON
mkdir -p "$work/mal"; echo '{not json' > "$work/mal/broker.json"
expect_status "$(bash "$BH" "$work/mal")" unknown "malformed json -> unknown"

# unknown: schema drift (missing pid)
mkdir -p "$work/drift"
printf '{"endpoint":"unix:/tmp/x.sock","sessionDir":"/tmp"}\n' > "$work/drift/broker.json"
expect_status "$(bash "$BH" "$work/drift")" unknown "missing fields -> unknown"

# pid reused by non-broker process -> dead
# Spawn a background sleep, use its pid, set pattern that won't match
# Skip if ps is unavailable (sandboxed env)
if ps -p $$ -o command= >/dev/null 2>&1; then
  sleep 30 & sleep_pid=$!
  sdir4="$work/s4"; mkdir -p "$sdir4"; touch "$sdir4/broker.sock"
  mk_broker "$work/reused" "$sdir4/broker.sock" "$sleep_pid" "$sdir4"
  HYPERPOWERS_BROKER_CMD_PATTERN='will-never-match-xyzzy' \
    expect_status "$(bash "$BH" "$work/reused")" dead "pid reused by non-broker -> dead"
  kill "$sleep_pid" 2>/dev/null || true
  sleep_pid=""
else
  pass "pid reused by non-broker -> dead (skipped: ps unavailable)"
fi

# live listener -> healthy (probe wins over dead pid)
sdir5="$work/s5"; mkdir -p "$sdir5"
node -e 'require("net").createServer(()=>{}).listen(process.argv[1], ()=>console.log("up"))' "$sdir5/live.sock" >/dev/null 2>&1 & listener_pid=$!
# Wait for socket file to appear (poll up to 2s)
for _ in {1..20}; do
  [ -e "$sdir5/live.sock" ] && break
  sleep 0.1
done
if [ -e "$sdir5/live.sock" ]; then
  # Spawn-and-reap a dead pid
  sleep 0.01 & deadpid2=$!; wait "$deadpid2" 2>/dev/null
  mk_broker "$work/live-probe" "$sdir5/live.sock" "$deadpid2" "$sdir5"
  expect_status "$(bash "$BH" "$work/live-probe")" healthy "live listener -> healthy (probe wins over dead pid)"
  kill "$listener_pid" 2>/dev/null || true
  listener_pid=""
else
  pass "live listener -> healthy (skipped: socket listener failed to bind)"
fi

# socket file exists but nothing listening -> dead
sdir6="$work/s6"; mkdir -p "$sdir6"
# Start listener, wait for socket, kill listener leaving stale socket
node -e 'require("net").createServer(()=>{}).listen(process.argv[1], ()=>console.log("up"))' "$sdir6/stale.sock" >/dev/null 2>&1 & stale_listener=$!
for _ in {1..20}; do
  [ -e "$sdir6/stale.sock" ] && break
  sleep 0.1
done
if [ -e "$sdir6/stale.sock" ]; then
  kill "$stale_listener" 2>/dev/null || true
  # Wait a moment for cleanup, but socket may still be there
  sleep 0.1
  if [ -e "$sdir6/stale.sock" ]; then
    # Socket survived kill - pair with dead pid for robust assertion
    sleep 0.01 & deadpid3=$!; wait "$deadpid3" 2>/dev/null
    mk_broker "$work/stale-probe" "$sdir6/stale.sock" "$deadpid3" "$sdir6"
    expect_status "$(bash "$BH" "$work/stale-probe")" dead "socket exists but no listener -> dead"
  else
    # OS removed socket on close - create plain fixture and dead pid
    touch "$sdir6/stale.sock"
    sleep 0.01 & deadpid3=$!; wait "$deadpid3" 2>/dev/null
    mk_broker "$work/stale-probe" "$sdir6/stale.sock" "$deadpid3" "$sdir6"
    expect_status "$(bash "$BH" "$work/stale-probe")" dead "socket exists but no listener -> dead (via dead pid fallback)"
  fi
else
  pass "socket exists but no listener -> dead (skipped: socket listener failed to bind)"
fi

# determinate answers exit 0
bash "$BH" "$work/absent" >/dev/null; [ $? -eq 0 ] && pass "absent exits 0" || fail "absent exits 0"
# usage error exits non-zero
bash "$BH" >/dev/null 2>&1 && fail "no-arg exits non-zero" || pass "no-arg exits non-zero"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
