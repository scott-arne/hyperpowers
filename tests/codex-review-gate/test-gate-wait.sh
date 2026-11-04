#!/usr/bin/env bash
# Tests gate-wait against a fake codex companion. Each job's state file lists
# the statuses successive calls return, one per line; the last line repeats.
# BADJSON makes that call print non-JSON, EXIT3 makes it exit 3. A --wait call
# appends its --timeout-ms value to <id>.timeouts and sleeps FAKE_WAIT_MS.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GW="$REPO_ROOT/skills/requesting-code-review/scripts/gate-wait"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { grep -Fq -- "$2" < <(printf '%s\n' "$1") && pass "$3" || fail "$3 (got: $1)"; }
expect_not() { grep -Fq -- "$2" < <(printf '%s\n' "$1") && fail "$3 (got: $1)" || pass "$3"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/gate-wait-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

CP="$work/codex"
mkdir -p "$CP/scripts"
cat > "$CP/scripts/codex-companion.mjs" <<'EOF'
import fs from "node:fs";
const args = process.argv.slice(2);
const dir = process.env.FAKE_STATE;
const id = args[1];
const file = `${dir}/${id}`;
if (args[0] !== "status" || !id || !fs.existsSync(file)) {
  process.stderr.write(`no such job ${id}\n`);
  process.exit(1);
}
const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
const posFile = `${file}.pos`;
const pos = fs.existsSync(posFile) ? Number(fs.readFileSync(posFile, "utf8")) : 0;
const state = lines[Math.min(pos, lines.length - 1)];
fs.writeFileSync(posFile, String(pos + 1));
const wait = args.includes("--wait");
if (wait) {
  const t = args[args.indexOf("--timeout-ms") + 1];
  fs.appendFileSync(`${file}.timeouts`, `${t}\n`);
  const ms = Math.min(Number(t), Number(process.env.FAKE_WAIT_MS || "200"));
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}
if (state === "BADJSON") { process.stdout.write("not json\n"); process.exit(0); }
if (state === "EXIT3") { process.exit(3); }
process.stdout.write(JSON.stringify({ job: { id, status: state }, waitTimedOut: wait && (state === "running" || state === "queued") }) + "\n");
EOF

# run_gw STATE_DIR [args...]: prints stdout, then a line "rc=<exit>"; stderr to STATE_DIR/err
run_gw() {
  local st="$1"; shift
  local out rc
  out="$(FAKE_STATE="$st" CODEX_PATH="$CP" bash "$GW" "$@" 2>"$st/err")"; rc=$?
  printf '%s\nrc=%s\n' "$out" "$rc"
}
newstate() { local d; d="$(mktemp -d "$work/st.XXXXXX")"; printf '%s' "$d"; }

# 1. every job finishes within the budget
s="$(newstate)"; printf 'running\ncompleted\n' > "$s/A"; printf 'completed\n' > "$s/B"
r="$(run_gw "$s" --budget 20 A B)"
expect "$r" "A completed" "1: A reported completed"
expect "$r" "B completed" "1: B reported completed"
expect "$r" "all-terminal" "1: all-terminal line"
expect "$r" "rc=0" "1: exit 0"

# 2. a job still running at the deadline
s="$(newstate)"; printf 'running\n' > "$s/A"
r="$(run_gw "$s" --budget 2 A)"
expect "$r" "running: A" "2: running line names A"
expect "$r" "rc=2" "2: exit 2"

# 3. a stalled first job does not hide later jobs that finished
s="$(newstate)"; printf 'running\n' > "$s/A"; printf 'running\ncompleted\n' > "$s/B"
r="$(run_gw "$s" --budget 3 A B)"
expect "$r" "B completed" "3: B reported completed despite stalled A"
expect "$r" "running: A" "3: running line names A"
expect_not "$r" "running: A B" "3: B not listed as running"
expect "$r" "rc=2" "3: exit 2"

# 4. a failed job is terminal
s="$(newstate)"; printf 'failed\n' > "$s/A"
r="$(run_gw "$s" A)"
expect "$r" "A failed" "4: failed status printed"
expect "$r" "rc=0" "4: exit 0"

# 5. malformed output for one job: exit 1, id on stderr, other job still listed
s="$(newstate)"; printf 'BADJSON\n' > "$s/A"; printf 'completed\n' > "$s/B"
r="$(run_gw "$s" --budget 5 A B)"
expect "$r" "rc=1" "5: exit 1"
expect "$r" "B completed" "5: other job still listed"
expect "$r" "unreadable: A" "5: unreadable line names A"
expect "$(cat "$s/err")" "gate-wait: A:" "5: stderr names A"

# 6. companion non-zero exit for a job
s="$(newstate)"; printf 'EXIT3\n' > "$s/A"
r="$(run_gw "$s" --budget 5 A)"
expect "$r" "rc=1" "6: exit 1"
expect "$r" "unreadable: A" "6: unreadable line names A"
expect "$(cat "$s/err")" "gate-wait: A: companion exited 3" "6: stderr names A and the code"

# 6a. one unreadable job and one still running
s="$(newstate)"; printf 'BADJSON\n' > "$s/A"; printf 'running\n' > "$s/B"
r="$(run_gw "$s" --budget 2 A B)"
expect "$r" "B running" "6a: running job's status listed"
expect "$r" "running: B" "6a: running line names B"
expect "$r" "unreadable: A" "6a: unreadable line names A"
expect "$r" "rc=1" "6a: exit 1"

# 6b. leading zeros read as decimal; all zeros rejected
s="$(newstate)"; printf 'completed\n' > "$s/A"
r="$(run_gw "$s" --budget 008 A)"; expect "$r" "rc=0" "6b: budget 008 accepted as 8"
r="$(run_gw "$s" --budget 0570 A)"; expect "$r" "rc=0" "6b: budget 0570 accepted as 570"
r="$(run_gw "$s" --budget 000 A)"; expect "$r" "rc=1" "6b: budget 000 rejected"

# 7. usage errors
s="$(newstate)"; printf 'completed\n' > "$s/A"
r="$(FAKE_STATE="$s" env -u CODEX_PATH bash "$GW" A 2>&1; echo "rc=$?")"
expect "$r" "CODEX_PATH" "7: missing CODEX_PATH named"
expect "$r" "rc=1" "7: missing CODEX_PATH exits 1"
r="$(run_gw "$s")"; expect "$r" "rc=1" "7: no job ids exits 1"
for b in 0 571 -5 1.5 abc 99999999999999999999; do
  r="$(run_gw "$s" --budget "$b" A)"; expect "$r" "rc=1" "7: budget '$b' rejected"
done
r="$(run_gw "$s" --budget)"; expect "$r" "rc=1" "7: --budget without a value exits 1"

# 8. the blocking timeout never exceeds the remaining budget
s="$(newstate)"; printf 'running\n' > "$s/A"
run_gw "$s" --budget 2 A >/dev/null
max="$(sort -n "$s/A.timeouts" | tail -n 1)"
[ -n "$max" ] && [ "$max" -le 2000 ] && pass "8: largest timeout $max ms <= 2000" || fail "8: largest timeout '$max' exceeds the 2 s budget"

# 9. a blocking slice is capped at 30 s
s="$(newstate)"; printf 'running\nrunning\ncompleted\n' > "$s/A"
FAKE_WAIT_MS=10 run_gw "$s" --budget 100 A >/dev/null
first="$(head -n 1 "$s/A.timeouts")"
[ "$first" = "30000" ] && pass "9: first slice is 30000 ms" || fail "9: first slice was '$first', expected 30000"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
