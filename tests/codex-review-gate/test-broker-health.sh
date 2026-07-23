#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BH="$REPO_ROOT/skills/requesting-code-review/scripts/broker-health"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

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
trap 'rm -rf "$work"' EXIT

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

# determinate answers exit 0
bash "$BH" "$work/absent" >/dev/null; [ $? -eq 0 ] && pass "absent exits 0" || fail "absent exits 0"
# usage error exits non-zero
bash "$BH" >/dev/null 2>&1 && fail "no-arg exits non-zero" || pass "no-arg exits non-zero"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
