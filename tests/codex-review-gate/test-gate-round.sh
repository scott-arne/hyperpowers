#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GR="$REPO_ROOT/skills/requesting-code-review/scripts/gate-round"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $1)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/gr-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
gd="$work/gate"; mkdir -p "$gd"

echo "gate-round:"

expect "$(bash "$GR" "$gd" --ceiling 3 --gate task)" '"round":1' "first call -> round 1"
out="$(bash "$GR" "$gd" --peek)"
expect "$out" '"round":1' "peek does not increment"
expect "$out" '"verdict":"proceed"' "peek before ceiling -> proceed"
expect "$(bash "$GR" "$gd" --ceiling 3 --gate task)" '"round":2' "second call -> round 2"
out="$(bash "$GR" "$gd" --ceiling 3 --gate task)"
expect "$out" '"round":3' "third call -> round 3"
expect "$out" '"verdict":"proceed"' "round 3 of 3 still proceeds"
expect "$(bash "$GR" "$gd" --peek)" '"verdict":"backstop"' "peek at spent ceiling -> backstop"
out="$(bash "$GR" "$gd" --ceiling 3 --gate task)"
expect "$out" '"verdict":"backstop"' "round 4 of 3 -> backstop"
expect "$out" 'ungated-ledger append --class backstop-fix' "backstop carries append reminder"
expect "$(cat "$gd/gate-round.json")" '"ceiling":3' "state file records ceiling"
expect "$(cat "$gd/gate-round.json")" '"gate":"task"' "state file records gate type"

# damaged state fails closed (exit 2), never resets the counter
gd2="$work/gate2"; mkdir -p "$gd2"
printf 'not json' > "$gd2/gate-round.json"
bash "$GR" "$gd2" --ceiling 3 >/dev/null 2>&1 && fail "corrupt state exits 2" || pass "corrupt state exits 2"
bash "$GR" "$gd2" --peek >/dev/null 2>&1 && fail "corrupt state peek exits 2" || pass "corrupt state peek exits 2"
rm -f "$gd2/gate-round.json"

# non-numeric ceiling in persisted state fails closed on both advance and peek
gd3="$work/gate3"; mkdir -p "$gd3"
printf '{"round":3,"ceiling":"x","gate":"task"}' > "$gd3/gate-round.json"
bash "$GR" "$gd3" --ceiling 3 >/dev/null 2>&1 && fail "non-numeric ceiling advance exits 2" || pass "non-numeric ceiling advance exits 2"
bash "$GR" "$gd3" --peek >/dev/null 2>&1 && fail "non-numeric ceiling peek exits 2" || pass "non-numeric ceiling peek exits 2"

# missing or null round field in persisted state fails closed (damaged state, not round 0)
gd4="$work/gate4"; mkdir -p "$gd4"
printf '{"ceiling":3,"gate":"task"}' > "$gd4/gate-round.json"
bash "$GR" "$gd4" --ceiling 3 >/dev/null 2>&1 && fail "missing round field exits 2" || pass "missing round field exits 2"
printf '{"round":null,"ceiling":3}' > "$gd4/gate-round.json"
bash "$GR" "$gd4" --peek >/dev/null 2>&1 && fail "null round peek exits 2" || pass "null round peek exits 2"

# unwritable GATE_DIR -> exit 2, no verdict emitted
ro="$work/ro"; mkdir -p "$ro"; chmod 555 "$ro"
out="$(bash "$GR" "$ro" --ceiling 3 2>/dev/null)"; rc=$?
chmod 755 "$ro"
[ "$rc" -ne 0 ] && pass "unwritable dir exits 2" || fail "unwritable dir exits 2 (rc=$rc out=$out)"
[ -z "$out" ] && pass "no verdict on failed write" || fail "no verdict on failed write (got $out)"

# determinate answers exit 0, missing dir exits 2
bash "$GR" "$gd" --ceiling 3 >/dev/null; [ $? -eq 0 ] && pass "backstop exits 0" || fail "backstop exits 0"
bash "$GR" "$work/nope" --ceiling 3 >/dev/null 2>&1 && fail "missing dir exits 2" || pass "missing dir exits 2"
bash "$GR" "$gd" >/dev/null 2>&1 && fail "missing ceiling exits 2" || pass "missing ceiling exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
