#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GR="$REPO_ROOT/skills/requesting-code-review/scripts/gate-round"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq -- "$2" && pass "$3" || fail "$3 (got: $1)"; }
# A usage error must exit exactly 2, never merely nonzero. Branching on a bare
# command status also accepts 1, 126, 127 and death by signal, so it cannot
# tell the usage contract from a script that died on a typo before it ever
# reached the check.
exit2() {
  e_label="$1"; shift
  e_out="$("$@" 2>&1)"; e_rc=$?
  [ "$e_rc" -eq 2 ] && pass "$e_label" || fail "$e_label (rc=$e_rc out=$e_out)"
}
# A rejected call writes nothing: no counter where there was none, and a counter
# that was already there left byte for byte as it was.
no_state() {
  if [ -f "$2/gate-round.json" ]; then fail "$1 (wrote $(cat "$2/gate-round.json"))"; else pass "$1"; fi
}
same_state() {
  s_now="$(cat "$3/gate-round.json" 2>/dev/null)"
  if [ "$s_now" = "$2" ]; then pass "$1"; else fail "$1 (now: $s_now)"; fi
}
# The counter is only a counter if the next call can read it back.
json_ok() {
  if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$2/gate-round.json" 2>/dev/null
  then pass "$1"; else fail "$1 (unparseable: $(cat "$2/gate-round.json" 2>/dev/null))"; fi
}

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
snap="$(cat "$gd2/gate-round.json")"
exit2 "corrupt state exits 2" bash "$GR" "$gd2" --ceiling 3
exit2 "corrupt state peek exits 2" bash "$GR" "$gd2" --peek
same_state "corrupt state is left as found" "$snap" "$gd2"
rm -f "$gd2/gate-round.json"

# non-numeric ceiling in persisted state fails closed on both advance and peek
gd3="$work/gate3"; mkdir -p "$gd3"
printf '{"round":3,"ceiling":"x","gate":"task"}' > "$gd3/gate-round.json"
snap="$(cat "$gd3/gate-round.json")"
exit2 "non-numeric ceiling advance exits 2" bash "$GR" "$gd3" --ceiling 3
exit2 "non-numeric ceiling peek exits 2" bash "$GR" "$gd3" --peek
same_state "non-numeric ceiling state is left as found" "$snap" "$gd3"

# missing or null round field in persisted state fails closed (damaged state, not round 0)
gd4="$work/gate4"; mkdir -p "$gd4"
printf '{"ceiling":3,"gate":"task"}' > "$gd4/gate-round.json"
exit2 "missing round field exits 2" bash "$GR" "$gd4" --ceiling 3
printf '{"round":null,"ceiling":3}' > "$gd4/gate-round.json"
exit2 "null round peek exits 2" bash "$GR" "$gd4" --peek

# unwritable GATE_DIR -> exit 2, no verdict emitted
ro="$work/ro"; mkdir -p "$ro"; chmod 555 "$ro"
out="$(bash "$GR" "$ro" --ceiling 3 2>/dev/null)"; rc=$?
chmod 755 "$ro"
[ "$rc" -eq 2 ] && pass "unwritable dir exits 2" || fail "unwritable dir exits 2 (rc=$rc out=$out)"
[ -z "$out" ] && pass "no verdict on failed write" || fail "no verdict on failed write (got $out)"

# determinate answers exit 0, missing dir exits 2
bash "$GR" "$gd" --ceiling 3 >/dev/null; [ $? -eq 0 ] && pass "backstop exits 0" || fail "backstop exits 0"
exit2 "missing dir exits 2" bash "$GR" "$work/nope" --ceiling 3
no_state "a rejected missing dir writes no counter" "$work/nope"
exit2 "missing ceiling exits 2" bash "$GR" "$gd"

# --consumed states the task's spent non-gate rounds; the script derives the
# ceiling from the shared five-round cap so the caller never subtracts.
gd5="$work/gate5"; mkdir -p "$gd5"
out="$(bash "$GR" "$gd5" --consumed 2 --gate task)"
expect "$out" '"ceiling":3' "--consumed 2 -> ceiling 3"
expect "$out" '"verdict":"proceed"' "--consumed 2 first round -> proceed"
expect "$(cat "$gd5/gate-round.json")" '"round":1' "state file records round with --consumed"
expect "$(cat "$gd5/gate-round.json")" '"ceiling":3' "state file records the derived ceiling"
expect "$(cat "$gd5/gate-round.json")" '"consumed":2' "state file records consumed rounds"

gd6="$work/gate6"; mkdir -p "$gd6"
expect "$(bash "$GR" "$gd6" --consumed 0 --gate task)" '"ceiling":5' "--consumed 0 -> ceiling 5"

# a fully spent cap is ceiling 0, so the very first advance backstops
gd7="$work/gate7"; mkdir -p "$gd7"
out="$(bash "$GR" "$gd7" --consumed 5 --gate task)"
expect "$out" '"ceiling":0' "--consumed 5 -> ceiling 0"
expect "$out" '"verdict":"backstop"' "spent cap backstops on first advance"

# a recorded ceiling of 0 and an unknown ceiling are different answers
gd8="$work/gate8"; mkdir -p "$gd8"
expect "$(bash "$GR" "$gd8" --peek --ceiling 0)" '"verdict":"backstop"' "peek at ceiling 0 -> backstop"
gd9="$work/gate9"; mkdir -p "$gd9"
expect "$(bash "$GR" "$gd9" --peek)" '"verdict":"proceed"' "peek with no ceiling known -> proceed"

# A peek answers with the ceiling THIS call supplies, and falls back to the
# persisted one only when the call supplies none. Preferring what was on disk
# let a peek proceed on a cap a newer --consumed had already spent: round 1
# recorded while the cap was intact, then a peek reporting five rounds spent,
# read back the stale five and said proceed -- the one answer the counter
# exists to refuse.
gd9b="$work/gate9b"; mkdir -p "$gd9b"
expect "$(bash "$GR" "$gd9b" --consumed 0 --gate task)" '"ceiling":5' "--consumed 0 records ceiling 5"
snap="$(cat "$gd9b/gate-round.json")"
out="$(bash "$GR" "$gd9b" --peek --consumed 5 --gate task)"
expect "$out" '"ceiling":0' "a peek answers with the ceiling its own --consumed derives"
expect "$out" '"verdict":"backstop"' "a peek on a cap this call reports spent backstops"
same_state "a peek with a newer --consumed leaves state untouched" "$snap" "$gd9b"
out="$(bash "$GR" "$gd9b" --peek --gate task)"
expect "$out" '"ceiling":5' "a peek that supplies no ceiling still reads the persisted one"
expect "$out" '"verdict":"proceed"' "the persisted ceiling still proceeds at round 1 of 5"

gd9c="$work/gate9c"; mkdir -p "$gd9c"
bash "$GR" "$gd9c" --ceiling 3 --gate task >/dev/null
expect "$(bash "$GR" "$gd9c" --peek --ceiling 1)" '"ceiling":1' "a peek answers with the --ceiling this call supplies"

# --consumed usage errors: exclusive with --ceiling, bounded by the cap, needs a value
gd10="$work/gate10"; mkdir -p "$gd10"
exit2 "--consumed with --ceiling exits 2" bash "$GR" "$gd10" --consumed 2 --ceiling 3
exit2 "--consumed 6 exits 2" bash "$GR" "$gd10" --consumed 6 --gate task
exit2 "--consumed -1 exits 2" bash "$GR" "$gd10" --consumed -1 --gate task
exit2 "--consumed with no value exits 2" bash "$GR" "$gd10" --consumed
# a flag left dangling at the end of the argument list is a usage error too,
# not a bash unbound-variable death
exit2 "--ceiling with no value exits 2" bash "$GR" "$gd10" --ceiling
exit2 "--gate with no value exits 2" bash "$GR" "$gd10" --gate

# a task-gate ceiling above the shared cap is arithmetically impossible
exit2 "task ceiling above the cap exits 2" bash "$GR" "$gd10" --ceiling 7 --gate task
no_state "rejected calls leave gate10 with no counter" "$gd10"
# the cap belongs to the task gate alone
gd11="$work/gate11"; mkdir -p "$gd11"
expect "$(bash "$GR" "$gd11" --ceiling 7 --gate final)" '"verdict":"proceed"' "final gate keeps a ceiling of 7"

# The cap belongs to the gate being counted, and that is not always the gate
# named on this call: a continuation may omit --gate and inherit task from the
# state file, which is the gate the write would persist all the same.
gd12="$work/gate12"; mkdir -p "$gd12"
bash "$GR" "$gd12" --consumed 2 --gate task >/dev/null
snap="$(cat "$gd12/gate-round.json")"
exit2 "resumed task gate rejects an over-cap ceiling" bash "$GR" "$gd12" --ceiling 7
expect "$(cat "$gd12/gate-round.json")" '"round":1' "rejected continuation leaves the counter at round 1"
same_state "rejected continuation leaves state untouched" "$snap" "$gd12"
exit2 "peek on a resumed task gate rejects an over-cap ceiling" bash "$GR" "$gd12" --peek --ceiling 7
same_state "rejected peek leaves state untouched" "$snap" "$gd12"
# an inherited gate that is not the task gate carries no cap
gd12b="$work/gate12b"; mkdir -p "$gd12b"
bash "$GR" "$gd12b" --ceiling 3 --gate final >/dev/null
expect "$(bash "$GR" "$gd12b" --ceiling 7)" '"verdict":"proceed"' "resumed final gate keeps a ceiling of 7"

# An explicitly empty --consumed is a value the caller supplied, not a flag the
# caller omitted; reading it as absent skips both the range check and the
# mutual exclusion.
gd13="$work/gate13"; mkdir -p "$gd13"
exit2 "empty --consumed exits 2" bash "$GR" "$gd13" --consumed ''
expect "$(bash "$GR" "$gd13" --consumed '' 2>&1)" "--consumed must be a non-negative integer" "empty --consumed is rejected as invalid, not read as absent"
exit2 "empty --consumed with --ceiling exits 2" bash "$GR" "$gd13" --consumed '' --ceiling 3 --gate task
exit2 "empty --consumed with --ceiling peeks no further" bash "$GR" "$gd13" --consumed '' --ceiling 3 --gate task --peek
no_state "a rejected empty --consumed writes no counter" "$gd13"
exit2 "empty --ceiling exits 2" bash "$GR" "$gd13" --ceiling ''
expect "$(bash "$GR" "$gd13" --ceiling '' 2>&1)" "--ceiling must be a non-negative integer" "empty --ceiling is rejected as invalid, not read as absent"

# printf writes every number into the state file unquoted, so a token bash
# accepts but JSON does not replaces the counter with a file nothing can read
# back: the call that wrote it exits 0, and every call after it exits 2 with the
# round it was counting gone.
gd15="$work/gate15"; mkdir -p "$gd15"
bash "$GR" "$gd15" --consumed 01 --gate task >/dev/null 2>&1
out="$(bash "$GR" "$gd15" --consumed 01 --gate task 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass "a leading-zero --consumed does not poison the next call" || fail "a leading-zero --consumed does not poison the next call (rc=$rc out=$out)"
json_ok "leading-zero --consumed leaves parseable state" "$gd15"
expect "$(cat "$gd15/gate-round.json")" '"consumed":1' "--consumed 01 is recorded as 1"
expect "$(cat "$gd15/gate-round.json")" '"round":2' "the second advance under --consumed 01 reached round 2"
expect "$out" '"ceiling":4' "--consumed 01 derives the ceiling --consumed 1 derives"

# the same exposure on a gate type that never validated its ceiling at all
gd15b="$work/gate15b"; mkdir -p "$gd15b"
expect "$(bash "$GR" "$gd15b" --ceiling 03 --gate final)" '"ceiling":3' "--ceiling 03 answers with 3"
json_ok "leading-zero --ceiling leaves parseable state" "$gd15b"
expect "$(cat "$gd15b/gate-round.json")" '"ceiling":3' "--ceiling 03 is recorded as 3"
expect "$(bash "$GR" "$gd15b" --ceiling 03 --gate final)" '"round":2' "the next call reads the state a leading zero used to break"

# a ceiling that is not a number at all used to reach the file on any gate but task
gd15c="$work/gate15c"; mkdir -p "$gd15c"
exit2 "non-numeric --ceiling exits 2 on a non-task gate" bash "$GR" "$gd15c" --ceiling foo --gate final
no_state "a rejected non-numeric --ceiling writes no counter" "$gd15c"

# Digits are not a bound. `$(( ))` is fixed-width signed, so a token wider than
# the machine word wraps -- and it wraps INTO the accepted range on the one path
# that has a range to enforce, spending none of the shared cap.
gd16="$work/gate16"; mkdir -p "$gd16"
exit2 "a --consumed wider than the machine word exits 2" bash "$GR" "$gd16" --consumed 18446744073709551616 --gate task
no_state "a wrapped --consumed writes no counter" "$gd16"
gd16b="$work/gate16b"; mkdir -p "$gd16b"
exit2 "a task --ceiling wider than the machine word exits 2" bash "$GR" "$gd16b" --ceiling 18446744073709551619 --gate task
no_state "a wrapped task --ceiling writes no counter" "$gd16b"
# the untapped gates have no cap to wrap into, so the width bound is their only guard
gd16c="$work/gate16c"; mkdir -p "$gd16c"
exit2 "an over-wide --ceiling exits 2 on a non-task gate" bash "$GR" "$gd16c" --ceiling 18446744073709551619 --gate final
no_state "an over-wide --ceiling writes no counter" "$gd16c"
expect "$(bash "$GR" "$gd16c" --ceiling 18446744073709551619 --gate final 2>&1)" "at most 9 digits" "the width bound names itself in the error"
expect "$(bash "$GR" "$gd16c" --ceiling 1234567890 --gate final 2>&1)" "at most 9 digits" "ten digits is over the bound"
expect "$(bash "$GR" "$gd16c" --ceiling 999999999 --gate final)" '"ceiling":999999999' "nine digits is within the bound"
json_ok "a nine-digit ceiling leaves parseable state" "$gd16c"

# padding is not width: a stripped token is measured, so leading zeros neither
# inflate the count nor survive into the file
gd16d="$work/gate16d"; mkdir -p "$gd16d"
out="$(bash "$GR" "$gd16d" --consumed 05 --gate task)"
expect "$out" '"ceiling":0' "--consumed 05 derives ceiling 0"
expect "$out" '"verdict":"backstop"' "--consumed 05 backstops on the first advance"
gd16e="$work/gate16e"; mkdir -p "$gd16e"
expect "$(bash "$GR" "$gd16e" --ceiling 0000003 --gate final)" '"ceiling":3' "--ceiling 0000003 answers with 3"
expect "$(cat "$gd16e/gate-round.json")" '"ceiling":3' "--ceiling 0000003 is recorded as 3"
expect "$(bash "$GR" "$gd16e" --ceiling 0000000000000003 --gate final)" '"round":2' "a token wide only in padding is within the bound"

# every pre-existing --ceiling behavior is unchanged for the other gate types
for g in spec plan final adhoc; do
  gdg="$work/gate-$g"; mkdir -p "$gdg"
  out="$(bash "$GR" "$gdg" --ceiling 4 --gate "$g")"
  expect "$out" '"round":1' "$g gate --ceiling 4 -> round 1"
  expect "$out" '"ceiling":4' "$g gate --ceiling 4 -> ceiling 4"
  expect "$out" '"verdict":"proceed"' "$g gate round 1 of 4 -> proceed"
  expect "$(cat "$gdg/gate-round.json")" "\"gate\":\"$g\"" "$g gate recorded in state"
done

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
