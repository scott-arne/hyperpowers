# Gate Reliability Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Codex review gate fail-closed and self-healing: dead brokers are quarantined automatically, degraded gates are attributed to a cause, invalid base refs never launch reviews, and a missing verdict can never read as approval.

**Architecture:** Narrow checkers + hook janitor (spec §2): the prose gate flow in `codex-review-gate.md` stays, but each fragile decision point becomes a small contract-tested script whose JSON answer is the only trusted input to that decision. The one unsandboxed responsibility (repairing broker state under `~/.claude/plugins/`) lives in the SessionStart hook.

**Tech Stack:** bash + node built-ins only (node is already required by the companion and used throughout `codex-available.sh`; no jq, no npm packages). Tests are plain bash scripts under `tests/`.

**Source spec:** `docs/hyperpowers/specs/2026-07-22-gate-reliability-hardening-design.md`

## Global Constraints

- Scripts exit 0 for every determinate answer (including negative ones) with single-line JSON on stdout; non-zero exit means the checker itself failed. Exception: `codex-available.sh` keeps its legacy contract (exit 0 + two stdout lines only when ready).
- Never weaken the current probe's readiness bar: `ok` requires `setup --json` ready (spec §4.3).
- Quarantine = rename `broker.json` → `broker.json.stale-<epoch>`; never delete; only on positive evidence of death; `unknown` schemas untouched (spec §4.1/4.2).
- Hyperpowers scripts must NOT read `CLAUDE_PLUGIN_DATA`; state root default is `~/.claude/plugins/data/codex-openai-codex/state/`, overridable via `HYPERPOWERS_CODEX_STATE_ROOT` (spec §4.3).
- Empty-tree hash constant: `4b825dc642cb6eb9a060e54bf8d69288fbee4904`.
- Reviewer bootstrap suppression is PROMPT-LEVEL only (spec §4.6): the standing line "You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills." goes in every review prompt/focus template. Never implement it as an env marker on companion invocations — the persistent per-repo broker inherits and replays the provisioning environment, so a marker set by one review would suppress the bootstrap for later non-review companion sessions in that repo.
- The janitor must never break, slow, or pollute the stdout of `hooks/session-start` (its stdout is parsed as hook JSON).
- Execution cadence: per-task commits on the feature branch follow the SDD skill's task gates (implement → review → Codex gate); the complete branch diff is presented to the user for approval before merge via `finishing-a-development-branch`. This satisfies AGENTS.md's diff-approval requirement at the branch level.
- No AI-attribution lines anywhere; never commit `docs/hyperpowers/` files.
- Version bump to 6.3.0 only in the final task, via `scripts/bump-version.sh`.
- All new scripts live in `skills/requesting-code-review/scripts/` and are `chmod +x`.
- Shell style must pass `bash scripts/lint-shell.sh`.

---

### Task 1: `broker-health` — shared health predicate

**Files:**
- Create: `skills/requesting-code-review/scripts/broker-health`
- Test: `tests/codex-review-gate/test-broker-health.sh`

**Interfaces:**
- Consumes: nothing (leaf utility).
- Produces: `broker-health <state-dir>` → stdout single-line JSON
  `{"status":"healthy|dead|absent|unknown","reason":"..."}`, exit 0 on any
  determinate status; exit 2 on usage/internal error. Tasks 3 and 6 call it
  with a state dir path and match on the `"status":"dead"` prefix.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-broker-health.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-broker-health.sh`
Expected: FAIL lines (script not found / all statuses wrong), non-zero exit.

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/broker-health`:

```bash
#!/usr/bin/env bash
# broker-health <state-dir> — classify one repo's codex-plugin-cc broker record.
#
# stdout: {"status":"healthy|dead|absent|unknown","reason":"..."}
#   healthy - socket path exists AND recorded pid is alive
#   dead    - positive evidence of death: sessionDir gone, socket gone,
#             or pid not alive (safe to quarantine)
#   absent  - no broker.json (normal before first companion call)
#   unknown - unparseable/unexpected schema (hands-off: never quarantined)
#
# Exit 0 for every determinate answer; exit 2 for usage/internal errors.
# Socket presence is an existence check (-e), not -S: a purged or missing
# path is the death signal either way, and plain-file fixtures stay hermetic.
set -uo pipefail

dir="${1:-}"
[ -n "$dir" ] || { echo "usage: broker-health <state-dir>" >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo "broker-health: node not found" >&2; exit 2; }

emit() { printf '{"status":"%s","reason":"%s"}\n' "$1" "$2"; exit 0; }

bj="$dir/broker.json"
[ -f "$bj" ] || emit absent "no broker.json"

# Extract the three fields we need; anything unexpected -> unknown (hands-off).
parsed="$(node -e '
  try {
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const ep = typeof d.endpoint === "string" ? d.endpoint : "";
    const sock = ep.startsWith("unix:") ? ep.slice(5) : "";
    const pid = Number.isInteger(d.pid) && d.pid > 0 ? d.pid : 0;
    const sdir = typeof d.sessionDir === "string" ? d.sessionDir : "";
    if (!sock || !pid || !sdir) process.exit(3);
    process.stdout.write(sock + "\n" + pid + "\n" + sdir);
  } catch (e) { process.exit(3); }
' "$bj" 2>/dev/null)" || emit unknown "unparseable or unexpected broker.json schema"

sock="$(printf '%s\n' "$parsed" | sed -n 1p)"
pid="$(printf '%s\n' "$parsed" | sed -n 2p)"
sdir="$(printf '%s\n' "$parsed" | sed -n 3p)"

[ -d "$sdir" ] || emit dead "sessionDir missing"
[ -e "$sock" ] || emit dead "socket missing"
kill -0 "$pid" 2>/dev/null || emit dead "pid $pid not alive"
emit healthy "socket present and pid $pid alive"
```

Then: `chmod +x skills/requesting-code-review/scripts/broker-health`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-broker-health.sh`
Expected: `ALL PASS`, exit 0. Also run `bash scripts/lint-shell.sh` — no new warnings.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/broker-health tests/codex-review-gate/test-broker-health.sh
git commit -m "feat(gate): add broker-health predicate for codex broker records"
```

---

### Task 2: `broker-state-dir` — locate the current repo's companion state dir

**Files:**
- Create: `skills/requesting-code-review/scripts/broker-state-dir`
- Test: `tests/codex-review-gate/test-broker-state-dir.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `broker-state-dir [repo-dir]` → stdout single-line JSON
  `{"status":"found|absent","dir":"<abs path or empty>","reason":"..."}`,
  exit 0 always for determinate answers. Honors
  `HYPERPOWERS_CODEX_STATE_ROOT` (never `CLAUDE_PLUGIN_DATA`). Task 3 calls
  it and, on `found`, runs `broker-health` on `.dir`.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-broker-state-dir.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BSD="$REPO_ROOT/skills/requesting-code-review/scripts/broker-state-dir"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/bsd-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# A fake git repo named "myrepo"
repo="$work/myrepo"
mkdir -p "$repo"; git -C "$repo" init -q
repo_real="$(cd "$repo" && pwd -P)"

# Fake state root
root="$work/state"; mkdir -p "$root"
export HYPERPOWERS_CODEX_STATE_ROOT="$root"

run() { bash "$BSD" "$repo"; }

echo "broker-state-dir:"

# no candidates -> absent
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "empty root -> absent" || fail "empty root -> absent (got $out)"

# one candidate with matching name shape -> found
mkdir -p "$root/myrepo-0123456789abcdef"
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"found"' && pass "single candidate -> found" || fail "single candidate -> found (got $out)"
printf '%s' "$out" | grep -Fq "myrepo-0123456789abcdef" && pass "returns candidate dir" || fail "returns candidate dir (got $out)"

# a dir with a non-hex or wrong-length suffix is not a candidate
mkdir -p "$root/myrepo-notahash" "$root/myrepo-0123"
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"found"' && pass "non-hash dirs ignored" || fail "non-hash dirs ignored (got $out)"

# two candidates, no state.json evidence -> absent (never guess)
mkdir -p "$root/myrepo-fedcba9876543210"
out="$(run)"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "ambiguous -> absent" || fail "ambiguous -> absent (got $out)"

# two candidates, one state.json names this repo's workspaceRoot -> that one wins
cat > "$root/myrepo-fedcba9876543210/state.json" <<EOF
{ "version": 1, "jobs": [ { "id": "t1", "workspaceRoot": "$repo_real" } ] }
EOF
out="$(run)"
printf '%s' "$out" | grep -Fq "myrepo-fedcba9876543210" && pass "state.json disambiguates" || fail "state.json disambiguates (got $out)"

# sanitized basename (space in repo name): the state dir's name does not
# match the raw basename, but state.json evidence still resolves it
srepo="$work/my repo"
mkdir -p "$srepo"; git -C "$srepo" init -q
sreal="$(cd "$srepo" && pwd -P)"
mkdir -p "$root/my-repo-aaaaaaaaaaaaaaaa"
cat > "$root/my-repo-aaaaaaaaaaaaaaaa/state.json" <<EOF
{ "version": 1, "jobs": [ { "id": "t2", "workspaceRoot": "$sreal" } ] }
EOF
out="$(bash "$BSD" "$srepo")"
printf '%s' "$out" | grep -Fq "my-repo-aaaaaaaaaaaaaaaa" && pass "slug-sanitized basename found via evidence" || fail "slug-sanitized basename found via evidence (got $out)"

# not a git repo -> absent
out="$(bash "$BSD" "$work")"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "non-repo -> absent" || fail "non-repo -> absent (got $out)"

# missing state root -> absent
out="$(HYPERPOWERS_CODEX_STATE_ROOT="$work/nope" bash "$BSD" "$repo")"
printf '%s' "$out" | grep -Fq '"status":"absent"' && pass "missing root -> absent" || fail "missing root -> absent (got $out)"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-broker-state-dir.sh`
Expected: FAIL (script missing), non-zero exit.

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/broker-state-dir`:

```bash
#!/usr/bin/env bash
# broker-state-dir [repo-dir] — locate the codex-plugin-cc state dir for a repo.
#
# The companion derives its per-repo key internally (git-root realpath ->
# slug -> hash). Reimplementing that hash would be schema-drift-fragile, so
# this resolves data-driven instead (spec 4.3):
#   1) evidence scan across ALL state dirs: one whose state.json records this
#      repo's git-root realpath as a job workspaceRoot wins (name-independent,
#      so slug-sanitized basenames — spaces, special characters — are found);
#   2) name fallback: a unique <repo-basename>-<16 hex> candidate wins;
#   3) else absent.
# Never guesses: ambiguity -> absent (a repo with no state dir also has no
# broker to recover, so absent is always safe).
#
# stdout: {"status":"found|absent","dir":"...","reason":"..."}   exit 0.
# Root: $HYPERPOWERS_CODEX_STATE_ROOT override, else the fixed default.
# Never reads CLAUDE_PLUGIN_DATA (that names the CALLING plugin's data dir).
set -uo pipefail

repo="${1:-.}"
root="${HYPERPOWERS_CODEX_STATE_ROOT:-${HOME:-}/.claude/plugins/data/codex-openai-codex/state}"

emit() { printf '{"status":"%s","dir":"%s","reason":"%s"}\n' "$1" "$2" "$3"; exit 0; }

[ -d "$root" ] || emit absent "" "state root missing"
gitroot="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || emit absent "" "not a git repo"
gitroot="$(cd "$gitroot" && pwd -P)"
base="$(basename "$gitroot")"

# 1) Evidence scan first (name-independent): the companion's own state.json
# records are authoritative, and this finds repos whose basenames the
# companion sanitizes into a different slug.
evidenced=()
for d in "$root"/*/; do
  d="${d%/}"
  [ -f "$d/state.json" ] || continue
  if grep -Fq "\"workspaceRoot\": \"$gitroot\"" "$d/state.json" 2>/dev/null; then
    evidenced+=("$d")
  fi
done
if [ "${#evidenced[@]}" -eq 1 ]; then
  emit found "${evidenced[0]}" "state.json workspaceRoot match"
fi
if [ "${#evidenced[@]}" -gt 1 ]; then
  emit absent "" "multiple state dirs claim this repo; refusing to guess"
fi

# 2) Name fallback: a unique <basename>-<16 hex> candidate wins.
candidates=()
for d in "$root/$base"-*; do
  [ -d "$d" ] || continue
  suffix="${d##*-}"
  [ "${#suffix}" -eq 16 ] || continue
  case "$suffix" in *[!0-9a-f]*) continue ;; esac
  candidates+=("$d")
done
if [ "${#candidates[@]}" -eq 1 ]; then
  emit found "${candidates[0]}" "unique candidate"
fi
emit absent "" "no unambiguous state dir; refusing to guess"
```

Then: `chmod +x skills/requesting-code-review/scripts/broker-state-dir`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-broker-state-dir.sh`
Expected: `ALL PASS`. Also `bash scripts/lint-shell.sh` clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/broker-state-dir tests/codex-review-gate/test-broker-state-dir.sh
git commit -m "feat(gate): add data-driven broker-state-dir resolution"
```

---

### Task 3: `codex-preflight` + convert `codex-available.sh` to a wrapper

**Files:**
- Create: `skills/requesting-code-review/scripts/codex-preflight`
- Modify: `skills/requesting-code-review/scripts/codex-available.sh` (full rewrite to wrapper; current logic moves into preflight)
- Test: `tests/codex-review-gate/test-codex-preflight.sh`
- Must stay green: `tests/codex-review-gate/test-codex-available.sh`

**Interfaces:**
- Consumes: `broker-state-dir` (Task 2), `broker-health` (Task 1).
- Produces: `codex-preflight [repo-dir]` → single-line JSON
  `{"status":"ok|not-installed|not-ready|stale-broker","codexPath":"...","codexVersion":"...","reason":"...","recovery":"..."}`
  exit 0 for all four statuses; non-zero only for internal failure.
  Test overrides honored (same names as today): `HYPERPOWERS_PLUGINS_FILE`,
  `HYPERPOWERS_CODEX_SETUP_JSON`, `HYPERPOWERS_PROBE_MAX_RETRIES`,
  `HYPERPOWERS_PROBE_RETRY_DELAY`, plus `HYPERPOWERS_CODEX_STATE_ROOT`
  (via Task 2). `codex-available.sh` keeps its exact legacy contract:
  exit 0 + `<path>\n<version>\n` only when preflight says `ok`.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-codex-preflight.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-codex-preflight.sh`
Expected: FAIL (script missing).

- [ ] **Step 3: Write `codex-preflight`**

Create `skills/requesting-code-review/scripts/codex-preflight`. This absorbs
the registry resolution and setup-readiness logic from the current
`codex-available.sh` verbatim (same node snippets, same retry/transient
classification, same test overrides) and adds status attribution:

```bash
#!/usr/bin/env bash
# codex-preflight [repo-dir] — attributed availability check for the Codex gate.
#
# Strictly extends codex-available.sh's readiness semantics (spec 4.3): "ok"
# still requires the companion's `setup --json` to report ready. Adds broker
# staleness attribution, checked BEFORE setup because a dead broker makes the
# setup call itself fail with connect ENOENT.
#
# stdout (single line):
#   {"status":"ok|not-installed|not-ready|stale-broker",
#    "codexPath":"...","codexVersion":"...","reason":"...","recovery":"..."}
# Exit 0 for every determinate status; non-zero only on internal failure.
#
# Test overrides: HYPERPOWERS_PLUGINS_FILE, HYPERPOWERS_CODEX_SETUP_JSON,
# HYPERPOWERS_PROBE_MAX_RETRIES, HYPERPOWERS_PROBE_RETRY_DELAY,
# HYPERPOWERS_CODEX_STATE_ROOT (consumed by broker-state-dir), and
# HYPERPOWERS_BROKER_STATE_DIR_BIN / HYPERPOWERS_BROKER_HEALTH_BIN
# (fault-injection: point at a failing/garbage stub).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
repo="${1:-.}"

command -v node >/dev/null 2>&1 || { echo "codex-preflight: node not found" >&2; exit 2; }

json_escape() { node -e 'process.stdout.write(JSON.stringify(process.argv[1]).slice(1,-1))' "$1"; }
emit() { # status codexPath codexVersion reason recovery
  printf '{"status":"%s","codexPath":"%s","codexVersion":"%s","reason":"%s","recovery":"%s"}\n' \
    "$1" "$(json_escape "$2")" "$(json_escape "$3")" "$(json_escape "$4")" "$(json_escape "$5")"
  exit 0
}

# --- 1. Resolve the install (moved verbatim from codex-available.sh) ---
registry="${HYPERPOWERS_PLUGINS_FILE:-${HOME:-}/.claude/plugins/installed_plugins.json}"
[ -f "$registry" ] || emit not-installed "" "" "plugin registry not found" ""

install_path="$(node -e '
  const fs = require("fs");
  const path = require("path");
  try {
    const reg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const recs = reg && reg.plugins && reg.plugins["codex@openai-codex"];
    if (!Array.isArray(recs)) process.exit(0);
    for (let i = recs.length - 1; i >= 0; i--) {
      const p = recs[i] && recs[i].installPath;
      if (typeof p !== "string" || !p) continue;
      if (fs.existsSync(path.join(p, "scripts", "codex-companion.mjs"))) {
        process.stdout.write(p);
        break;
      }
    }
  } catch (e) { /* degrade */ }
' "$registry" 2>/dev/null)"
[ -n "$install_path" ] || emit not-installed "" "" "no live codex-plugin-cc install in registry" ""
companion="$install_path/scripts/codex-companion.mjs"

# --- 2. Broker health for the current repo (BEFORE setup; spec 4.3) ---
# Fail-closed (spec 4 error discipline): a helper that fails or prints an
# unrecognizable answer is a preflight INTERNAL failure (exit 2, which §1
# maps to the degrade path) — never silently downgraded to absent/unknown,
# which could let a broken helper produce a spurious "ok".
bsd_bin="${HYPERPOWERS_BROKER_STATE_DIR_BIN:-$SCRIPT_DIR/broker-state-dir}"
bh_bin="${HYPERPOWERS_BROKER_HEALTH_BIN:-$SCRIPT_DIR/broker-health}"
sd_json="$(bash "$bsd_bin" "$repo" 2>/dev/null)" \
  || { echo "codex-preflight: broker-state-dir failed" >&2; exit 2; }
case "$sd_json" in
  '{"status":"'*) : ;;
  *) echo "codex-preflight: unexpected broker-state-dir output" >&2; exit 2 ;;
esac
case "$sd_json" in
  '{"status":"found"'*)
    sd="$(printf '%s' "$sd_json" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));process.stdout.write(d.dir||"")')"
    health="$(bash "$bh_bin" "$sd" 2>/dev/null)" \
      || { echo "codex-preflight: broker-health failed" >&2; exit 2; }
    case "$health" in
      '{"status":"'*) : ;;
      *) echo "codex-preflight: unexpected broker-health output" >&2; exit 2 ;;
    esac
    case "$health" in
      '{"status":"dead"'*)
        emit stale-broker "$install_path" "" \
          "this repo's companion broker is dead (its temp dir was likely purged); every companion call will fail until the record is cleared" \
          "mv '$sd/broker.json' '$sd/broker.json.stale-'\$(date +%s)"
        ;;
    esac
    ;;
esac
# healthy / absent / unknown all fall through (spec 4.3 step 4).

# --- 3. Setup readiness (moved verbatim from codex-available.sh) ---
max_retries="${HYPERPOWERS_PROBE_MAX_RETRIES:-2}"
retry_delay="${HYPERPOWERS_PROBE_RETRY_DELAY:-0.5}"

classify() {
  printf '%s' "$1" | node -e '
    const fs = require("fs");
    let verdict = "no"; let detail = "";
    try {
      const d = JSON.parse(fs.readFileSync(0, "utf8"));
      if (d && d.ready === true) {
        verdict = "yes";
      } else {
        // Name the first failing setup dimension (spec 4.3: CLI missing,
        // not authenticated, ...), not just auth.detail.
        for (const k of ["node", "codex", "auth"]) {
          const dim = d && d[k];
          if (dim && dim.ok === false) {
            detail = (typeof dim.detail === "string" && dim.detail) ? k + ": " + dim.detail : k + ": not ready";
            break;
          }
        }
        if (!detail) detail = (d && d.auth && typeof d.auth.detail === "string") ? d.auth.detail : "";
        const transient = /exited unexpectedly|connection closed|app-server (?:client )?is closed|stdin is not available|broker connection is not connected|Failed to parse codex app-server/i;
        verdict = transient.test(detail) ? "retry" : "no";
      }
    } catch (e) { verdict = "no"; }
    process.stdout.write(verdict + "\t" + detail);
  ' 2>/dev/null
}

attempt=0
while :; do
  if [ -n "${HYPERPOWERS_CODEX_SETUP_JSON:-}" ]; then
    setup_json="$HYPERPOWERS_CODEX_SETUP_JSON"
  else
    setup_json="$(node "$companion" setup --json 2>/dev/null)" || setup_json=""
  fi
  out="$(classify "$setup_json")"
  verdict="${out%%$'\t'*}"; detail="${out#*$'\t'}"
  case "$verdict" in
    yes) break ;;
    retry)
      if [ "$attempt" -lt "$max_retries" ]; then
        attempt=$((attempt + 1)); sleep "$retry_delay"; continue
      fi
      emit not-ready "$install_path" "" "setup not ready after retries: ${detail:-transient handshake failure}" ""
      ;;
    *) emit not-ready "$install_path" "" "setup not ready: ${detail:-no detail from setup --json}" "" ;;
  esac
done

# --- 4. ok, with version (moved verbatim from codex-available.sh) ---
version="$(node -e '
  try {
    const v = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).version;
    if (typeof v === "string" && v) process.stdout.write(v);
  } catch (e) { /* degrade */ }
' "$install_path/.claude-plugin/plugin.json" 2>/dev/null)"
emit ok "$install_path" "${version:-unknown}" "ready" ""
```

Then: `chmod +x skills/requesting-code-review/scripts/codex-preflight`

- [ ] **Step 4: Rewrite `codex-available.sh` as a wrapper**

Replace the entire body of `skills/requesting-code-review/scripts/codex-available.sh` with:

```bash
#!/usr/bin/env bash
# Back-compat probe wrapper over codex-preflight. Contract unchanged:
# on ready, print the Codex install path (line 1) and version (line 2),
# exit 0; on any other status or failure, exit 1 with no stdout.
# All HYPERPOWERS_* test overrides pass through via the environment.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
out="$(bash "$SCRIPT_DIR/codex-preflight" "${1:-.}" 2>/dev/null)" || exit 1
printf '%s' "$out" | node -e '
  try {
    const d = JSON.parse(require("fs").readFileSync(0, "utf8"));
    if (d.status !== "ok") process.exit(1);
    process.stdout.write(d.codexPath + "\n" + (d.codexVersion || "unknown") + "\n");
  } catch (e) { process.exit(1); }
' || exit 1
exit 0
```

- [ ] **Step 5: Isolate the legacy probe tests from ambient broker state**

The wrapper now routes through preflight, which checks the REAL repo's
broker before setup — so on a machine with a stale broker for this repo,
the legacy tests' fake registry/setup injections would go non-ok before
their fixtures even apply. Make them broker-neutral: in
`tests/codex-review-gate/test-codex-available.sh`, immediately after its
setup preamble (SCRIPT_DIR/work-dir creation), add:

```bash
# The probe is now a wrapper over codex-preflight, which checks broker
# state before setup; isolate these legacy readiness cases from whatever
# broker state this machine happens to have.
iso_state_root="$(mktemp -d "${TMPDIR:-/tmp}/ca-state.XXXXXX")"
export HYPERPOWERS_CODEX_STATE_ROOT="$iso_state_root"
```

(plus cleanup of `$iso_state_root` in its existing trap). Then add one new
wrapper-level case at the end of that file: point
`HYPERPOWERS_CODEX_STATE_ROOT` at a fixture root containing a dead broker
for the test repo (reuse the Task 1 `mk_broker` shape) and assert the
wrapper exits 1 with no stdout — stale-broker maps to unavailable in the
legacy contract.

- [ ] **Step 6: Run tests to verify both pass**

Run: `bash tests/codex-review-gate/test-codex-preflight.sh`
Expected: `ALL PASS`.
Run: `bash tests/codex-review-gate/test-codex-available.sh`
Expected: `ALL PASS` — every pre-existing case green under the isolated
state root, plus the new stale-broker wrapper case. Beyond the isolation
preamble and the new case, do not weaken existing assertions: if a legacy
case fails, fix the wrapper, not the assertion.
Run: `bash scripts/lint-shell.sh` — clean.

- [ ] **Step 7: Live smoke test on this machine**

Run: `bash skills/requesting-code-review/scripts/codex-preflight`
Expected: `{"status":"ok",...,"codexVersion":"1.0.6",...}` (this machine has a
live install), and `bash skills/requesting-code-review/scripts/codex-available.sh`
prints the install path + `1.0.6` with exit 0.

- [ ] **Step 8: Commit**

```bash
git add skills/requesting-code-review/scripts/codex-preflight skills/requesting-code-review/scripts/codex-available.sh tests/codex-review-gate/test-codex-preflight.sh tests/codex-review-gate/test-codex-available.sh
git commit -m "feat(gate): attributed codex-preflight; codex-available.sh becomes wrapper"
```

---

### Task 4: `base-ref-ok` — pre-launch base validation

**Files:**
- Create: `skills/requesting-code-review/scripts/base-ref-ok`
- Test: `tests/codex-review-gate/test-base-ref-ok.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `base-ref-ok <base-ref> [repo-dir]` → single-line JSON
  `{"ok":true,"resolvedBase":"<sha>"}` or
  `{"ok":false,"reason":"unresolvable|empty-tree|no-merge-base|empty-range"}`.
  Exit 0 for both; exit 2 for usage/internal error. Task 8 makes the gate doc
  require an `"ok":true` result before any `adversarial-review` launch.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-base-ref-ok.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BRO="$REPO_ROOT/skills/requesting-code-review/scripts/base-ref-ok"
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $1)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/bro-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

repo="$work/repo"; mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
base_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two

echo "base-ref-ok:"

expect "$(bash "$BRO" "$base_sha" "$repo")" '"ok":true'      "valid ancestor sha -> ok"
expect "$(bash "$BRO" "$base_sha" "$repo")" "$base_sha"      "ok carries resolvedBase"
expect "$(bash "$BRO" deadbeef "$repo")"    '"reason":"unresolvable"' "bogus ref -> unresolvable"
expect "$(bash "$BRO" "$EMPTY_TREE" "$repo")" '"reason":"empty-tree"' "empty-tree hash -> empty-tree (before peeling)"
expect "$(bash "$BRO" HEAD "$repo")"        '"reason":"empty-range"'  "HEAD as base -> empty-range"

# orphan branch -> no merge base
git -C "$repo" checkout -q --orphan lonely
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m orphan
expect "$(bash "$BRO" "$base_sha" "$repo")" '"reason":"no-merge-base"' "orphan history -> no-merge-base"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-base-ref-ok.sh`
Expected: FAIL (script missing).

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/base-ref-ok`:

```bash
#!/usr/bin/env bash
# base-ref-ok <base-ref> [repo-dir] — validate a review base BEFORE launching
# adversarial-review. A bad base (notably the empty-tree hash) makes the
# companion's merge-base fatal mid-job and orphans the review as "running"
# forever; the only place to stop that is before launch (spec 4.4).
#
# Check order matters: the raw object is compared against the empty-tree hash
# BEFORE ^{commit} peeling, because peeling rejects the empty tree and would
# misreport it as merely unresolvable.
#
# stdout: {"ok":true,"resolvedBase":"<sha>"}
#      or {"ok":false,"reason":"unresolvable|empty-tree|no-merge-base|empty-range"}
# Exit 0 for both; exit 2 on usage error.
set -uo pipefail

EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

base="${1:-}"
repo="${2:-.}"
[ -n "$base" ] || { echo "usage: base-ref-ok <base-ref> [repo-dir]" >&2; exit 2; }

ok()   { printf '{"ok":true,"resolvedBase":"%s"}\n' "$1"; exit 0; }
nope() { printf '{"ok":false,"reason":"%s"}\n' "$1"; exit 0; }

raw="$(git -C "$repo" rev-parse --verify --quiet "$base" 2>/dev/null)" || nope unresolvable
[ "$raw" != "$EMPTY_TREE" ] || nope empty-tree
commit="$(git -C "$repo" rev-parse --verify --quiet "${base}^{commit}" 2>/dev/null)" || nope unresolvable
git -C "$repo" merge-base "$commit" HEAD >/dev/null 2>&1 || nope no-merge-base
head="$(git -C "$repo" rev-parse HEAD 2>/dev/null)" || nope unresolvable
[ "$commit" != "$head" ] || nope empty-range
ok "$commit"
```

Then: `chmod +x skills/requesting-code-review/scripts/base-ref-ok`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-base-ref-ok.sh`
Expected: `ALL PASS`. `bash scripts/lint-shell.sh` clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/base-ref-ok tests/codex-review-gate/test-base-ref-ok.sh
git commit -m "feat(gate): validate review base refs before adversarial-review launch"
```

---

### Task 5: `verdict-normalize` — fail-closed verdict authority

**Files:**
- Create: `skills/requesting-code-review/scripts/verdict-normalize`
- Test: `tests/codex-review-gate/test-verdict-normalize.sh`

**Interfaces:**
- Consumes: a file holding captured companion output — either document-gate
  text (the "Required document-review output" shape) or a code-gate `--json`
  payload (`.storedJob.result.result` verdict object, companion 1.0.5/1.0.6).
- Produces: `verdict-normalize <payload-file>` → single-line JSON
  `{"result":"approved|blocking|incomplete","verdict":"approve|needs-attention|none","blockingCount":N,"reason":"..."}`
  Exit 0 always for determinate answers; exit 2 for usage/internal error.
  Task 8 amends the gate doc so this is the only approval authority.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-verdict-normalize.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VN="$REPO_ROOT/skills/requesting-code-review/scripts/verdict-normalize"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
check() { # <file> <fragment> <desc>
  local out; out="$(bash "$VN" "$1")"
  printf '%s' "$out" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $out)"
}

work="$(mktemp -d "${TMPDIR:-/tmp}/vn-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

echo "verdict-normalize:"

# --- document-gate text shapes ---
cat > "$work/approve.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Non-blocking Findings:
- severity: medium
  title: nit

Summary: fine.
EOF
check "$work/approve.txt" '"result":"approved"' "text approve -> approved"

cat > "$work/needs.txt" <<'EOF'
Verdict: needs-attention

Blocking Findings:
- severity: high
  title: broken thing
- severity: critical
  title: worse thing

Non-blocking Findings:
None

Summary: fix.
EOF
check "$work/needs.txt" '"result":"blocking"' "text needs-attention -> blocking"
check "$work/needs.txt" '"blockingCount":2' "counts blocking findings"

cat > "$work/cutoff.txt" <<'EOF'
I'm formatting the verdict exactly as requested
EOF
check "$work/cutoff.txt" '"result":"incomplete"' "cut-off text -> incomplete"

# contradiction: approve but blocking findings listed -> blocking (conservative)
cat > "$work/contra.txt" <<'EOF'
Verdict: approve

Blocking Findings:
- severity: high
  title: sneaky

Summary: hm.
EOF
check "$work/contra.txt" '"result":"blocking"' "approve+blocking findings -> blocking"

# --- code-gate JSON payloads ---
cat > "$work/approve.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [] },
  "rawOutput": "Verdict: approve" } } }
EOF
check "$work/approve.json" '"result":"approved"' "json approve -> approved"

cat > "$work/blocking.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "needs-attention",
    "findings": [ { "severity": "high", "title": "bug" },
                  { "severity": "low", "title": "nit" } ] },
  "rawOutput": "..." } } }
EOF
check "$work/blocking.json" '"result":"blocking"' "json needs-attention -> blocking"
check "$work/blocking.json" '"blockingCount":1' "json counts only critical/high"

cat > "$work/novderdict.json" <<'EOF'
{ "storedJob": { "result": { "parseError": "schema mismatch",
  "result": null, "rawOutput": "still verifying the diff" } } }
EOF
check "$work/novderdict.json" '"result":"incomplete"' "null result payload -> incomplete"

# empty file -> incomplete
: > "$work/empty.txt"
check "$work/empty.txt" '"result":"incomplete"' "empty file -> incomplete"

# missing file -> internal error (exit 2)
bash "$VN" "$work/nope.txt" >/dev/null 2>&1 && fail "missing file exits non-zero" || pass "missing file exits non-zero"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh`
Expected: FAIL (script missing).

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/verdict-normalize`:

```bash
#!/usr/bin/env bash
# verdict-normalize <payload-file> — the gate's only approval authority.
#
# Accepts either document-gate text (the Required document-review output
# shape) or a code-gate --json payload, and reduces it to a tri-state
# (spec 4.5). Fail-closed: anything without a parseable verdict is
# "incomplete", and incomplete is never approval. The contradictory
# approve-with-blocking-findings case is "blocking" (conservative).
#
# stdout: {"result":"approved|blocking|incomplete",
#          "verdict":"approve|needs-attention|none",
#          "blockingCount":N,"reason":"..."}
# Exit 0 for every determinate answer; exit 2 on usage/internal error.
set -uo pipefail

file="${1:-}"
[ -n "$file" ] && [ -f "$file" ] || { echo "usage: verdict-normalize <payload-file>" >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo "verdict-normalize: node not found" >&2; exit 2; }

node -e '
  const fs = require("fs");
  const text = fs.readFileSync(process.argv[1], "utf8");

  const out = (result, verdict, blockingCount, reason) => {
    process.stdout.write(JSON.stringify({ result, verdict, blockingCount, reason }) + "\n");
    process.exit(0);
  };

  // Reduce a structured verdict object ({verdict, findings[]}) to the tri-state.
  const fromStructured = (v, source) => {
    if (!v || typeof v.verdict !== "string") return false;
    const findings = Array.isArray(v.findings) ? v.findings : [];
    const blocking = findings.filter(f => f && /^(critical|high)$/i.test(String(f.severity || ""))).length;
    if (v.verdict === "approve" && blocking === 0) out("approved", "approve", 0, source + ": approve, no blocking findings");
    if (v.verdict === "approve") out("blocking", "approve", blocking, source + ": contradictory approve with blocking findings");
    out("blocking", "needs-attention", blocking, source + ": " + v.verdict);
    return true;
  };

  // 1) JSON payload path (code gates, --json).
  try {
    const d = JSON.parse(text);
    // Known roots across companion 1.0.5/1.0.6: storedJob.result.result,
    // result.result, or a bare verdict object.
    const roots = [
      d && d.storedJob && d.storedJob.result && d.storedJob.result.result,
      d && d.result && d.result.result,
      d && d.result,
      d,
    ];
    for (const r of roots) if (fromStructured(r, "json payload")) break;
    // Parsed as JSON but no structured verdict anywhere: try its rawOutput
    // as text below; otherwise incomplete.
    const raw = (d && d.storedJob && d.storedJob.result && d.storedJob.result.rawOutput) || "";
    if (!/^\s*Verdict:\s*(approve|needs-attention)\s*$/im.test(raw)) {
      out("incomplete", "none", 0, "json payload has no terminal verdict");
    }
    parseText(raw, "json rawOutput");
  } catch (e) { /* not JSON: fall through to text */ }

  // 2) Document-gate text path.
  function parseText(t, source) {
    const m = t.match(/^\s*Verdict:\s*(approve|needs-attention)\s*$/im);
    if (!m) out("incomplete", "none", 0, source + ": no terminal Verdict line");
    const verdict = m[1].toLowerCase();
    // Count critical/high entries inside the Blocking Findings section only.
    let blocking = 0;
    const sec = t.split(/^\s*Blocking Findings:\s*$/im)[1];
    if (sec !== undefined) {
      const body = sec.split(/^\s*(?:Non-blocking Findings|Cannot verify|Summary):\s*/im)[0] || "";
      blocking = (body.match(/^\s*-\s*severity:\s*(critical|high)\b/gim) || []).length;
    }
    if (verdict === "approve" && blocking === 0) out("approved", "approve", 0, source + ": approve, no blocking findings");
    if (verdict === "approve") out("blocking", "approve", blocking, source + ": contradictory approve with blocking findings");
    out("blocking", "needs-attention", blocking, source + ": needs-attention");
  }
  parseText(text, "document text");
' "$file"
```

Then: `chmod +x skills/requesting-code-review/scripts/verdict-normalize`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh`
Expected: `ALL PASS`. `bash scripts/lint-shell.sh` clean.

- [ ] **Step 5: Regression-check against a real captured verdict**

Run:
```bash
bash skills/requesting-code-review/scripts/verdict-normalize \
  ~/.cache/hyperpowers/codex-review/193a951fd4f675975a919be372c5015a95aa0491/run-2eZghzLq/spec-gate-r3.out
```
Expected: `{"result":"approved","verdict":"approve","blockingCount":0,...}` —
this is the real round-3 approval from this feature's own spec gate. Also run
it on `spec-gate-r1.out` from the same dir: expected `"result":"blocking"`,
`"blockingCount":2`.

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/scripts/verdict-normalize tests/codex-review-gate/test-verdict-normalize.sh
git commit -m "feat(gate): fail-closed verdict normalization for review results"
```

---

### Task 6: Session-start broker janitor + quarantine GC

**Files:**
- Modify: `hooks/session-start` (insert janitor block after the
  `escape_for_json` function definition, before `using_hyperpowers_escaped=` —
  currently around line 28)
- Test: `tests/hooks/test-broker-janitor.sh`

**Interfaces:**
- Consumes: `broker-health` (Task 1) via `${PLUGIN_ROOT}/skills/requesting-code-review/scripts/broker-health`.
- Produces: side effect only — dead `broker.json` → `broker.json.stale-<epoch>`;
  `broker.json.stale-*` older than 14 days deleted. Honors
  `HYPERPOWERS_CODEX_STATE_ROOT` for tests. Hook stdout JSON is unchanged.

- [ ] **Step 1: Write the failing test**

Create `tests/hooks/test-broker-janitor.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/janitor-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

root="$work/state"

mk_broker() { # <dir> <socket> <pid> <sessiondir>
  mkdir -p "$1"
  printf '{"endpoint":"unix:%s","pidFile":"x","logFile":"x","sessionDir":"%s","pid":%s}\n' \
    "$2" "$4" "$3" > "$1/broker.json"
}

# dead broker (purged sessionDir)
mk_broker "$root/repoA-0000000000000000" "$work/gone/b.sock" $$ "$work/gone"
# healthy broker (live socket file + our own pid)
live="$work/live"; mkdir -p "$live"; touch "$live/b.sock"
mk_broker "$root/repoB-1111111111111111" "$live/b.sock" $$ "$live"
# malformed broker (unknown -> untouched)
mkdir -p "$root/repoC-2222222222222222"; echo '{oops' > "$root/repoC-2222222222222222/broker.json"
# old quarantined file (GC target) and a fresh one (kept)
mkdir -p "$root/repoD-3333333333333333"
touch "$root/repoD-3333333333333333/broker.json.stale-1000000000"
# backdate mtime 20 days
touch -t "$(date -v-20d +%Y%m%d%H%M 2>/dev/null || date -d '20 days ago' +%Y%m%d%H%M)" \
  "$root/repoD-3333333333333333/broker.json.stale-1000000000"
touch "$root/repoD-3333333333333333/broker.json.stale-9999999999"

echo "broker janitor:"

out="$(HYPERPOWERS_CODEX_STATE_ROOT="$root" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null)"

# stdout is still the hook's JSON context (unchanged contract)
printf '%s' "$out" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null \
  && pass "hook stdout is still valid JSON" || fail "hook stdout is still valid JSON"
printf '%s' "$out" | grep -q "hookSpecificOutput" && pass "bootstrap context still emitted" || fail "bootstrap context still emitted"

[ ! -f "$root/repoA-0000000000000000/broker.json" ] && pass "dead broker quarantined" || fail "dead broker quarantined"
ls "$root/repoA-0000000000000000"/broker.json.stale-* >/dev/null 2>&1 && pass "quarantine file created" || fail "quarantine file created"
[ -f "$root/repoB-1111111111111111/broker.json" ] && pass "healthy broker untouched" || fail "healthy broker untouched"
[ -f "$root/repoC-2222222222222222/broker.json" ] && pass "unknown schema untouched" || fail "unknown schema untouched"
[ ! -f "$root/repoD-3333333333333333/broker.json.stale-1000000000" ] && pass "old quarantine GCed" || fail "old quarantine GCed"
[ -f "$root/repoD-3333333333333333/broker.json.stale-9999999999" ] && pass "fresh quarantine kept" || fail "fresh quarantine kept"

# absent state root: hook still works
out2="$(HYPERPOWERS_CODEX_STATE_ROOT="$work/absent" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null)"
printf '%s' "$out2" | grep -q "hookSpecificOutput" && pass "no-op when root absent" || fail "no-op when root absent"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/hooks/test-broker-janitor.sh`
Expected: FAIL on "dead broker quarantined" / GC assertions (janitor not yet present); the stdout-JSON assertions may already pass.

- [ ] **Step 3: Add the janitor block to `hooks/session-start`**

Insert after the `escape_for_json()` function (before the
`using_hyperpowers_escaped=` line):

```bash
# --- Codex broker janitor (spec 4.2) --------------------------------------
# Quarantine provably-dead codex-plugin-cc broker records so the companion
# re-provisions instead of failing every call against a purged socket. Runs
# unsandboxed (hooks are ordinary user processes). Best-effort by contract:
# it must never fail, slow, or pollute this hook's stdout JSON.
codex_state_root="${HYPERPOWERS_CODEX_STATE_ROOT:-${HOME:-}/.claude/plugins/data/codex-openai-codex/state}"
if [ -d "$codex_state_root" ]; then
  (
    set +e
    broker_health="${PLUGIN_ROOT}/skills/requesting-code-review/scripts/broker-health"
    for state_dir in "$codex_state_root"/*/; do
      [ -f "${state_dir}broker.json" ] || continue
      health="$(bash "$broker_health" "${state_dir%/}" 2>/dev/null)"
      case "$health" in
        '{"status":"dead"'*)
          mv "${state_dir}broker.json" "${state_dir}broker.json.stale-$(date +%s)" 2>/dev/null
          ;;
      esac
    done
    # GC quarantined records older than 14 days (same policy as sdd-dir GC).
    find "$codex_state_root" -maxdepth 2 -name 'broker.json.stale-*' -mtime +14 -delete 2>/dev/null
  ) >/dev/null 2>&1 || true
fi
# ---------------------------------------------------------------------------
```

Note: the hook runs under `set -euo pipefail`; the janitor subshell sets
`set +e` internally and the whole block is `|| true`-guarded, so no janitor
failure can propagate.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/hooks/test-broker-janitor.sh`
Expected: `ALL PASS`.
Also run the existing hook tests: `for t in tests/hooks/test-*.sh; do bash "$t" || echo "FAILED: $t"; done`
Expected: all previously-passing hook tests still pass.
`bash scripts/lint-shell.sh` clean.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start tests/hooks/test-broker-janitor.sh
git commit -m "feat(hooks): quarantine dead codex brokers at session start"
```

---

### Task 7: Reviewer bootstrap suppression (prompt-level)

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (the two §3 document prompt templates and the three `adversarial-review` focus strings)
- Modify: `skills/brainstorming/codex-approach-gate.md` (Invocation prompt guidance)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (suppression needles)

**Interfaces:**
- Consumes: the exact suppression line from spec §4.6.
- Produces: every reviewer prompt/focus template carries, on one unwrapped
  source line: `You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills.`
  Deliberately NOT an env marker — see Global Constraints (shared-broker
  environment leak).

- [ ] **Step 1: Add the suppression needles (RED)**

In `tests/codex-review-gate/test-gate-contract.sh`, add near the other file
variables at the top:

```bash
APPROACH_GATE="$REPO_ROOT/skills/brainstorming/codex-approach-gate.md"
```

and append with the other assertions:

```bash
echo "Reviewer bootstrap suppression (prompt-level):"
assert_contains "$GATE" "stateless reviewer for this request only" "gate prompts suppress reviewer bootstrap"
assert_contains "$APPROACH_GATE" "stateless reviewer for this request only" "approach gate prompt suppresses reviewer bootstrap"
```

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: both new needles FAIL; every pre-existing needle PASSES.

- [ ] **Step 2: Add the line to the five gate-doc templates**

In `codex-review-gate.md` §3, append this sentence to the spec prompt
template and the plan prompt template (immediately before "Do not edit
anything."), and to each of the three `adversarial-review` focus strings
(immediately before "Do not edit anything."), keeping it on one unwrapped
source line in the markdown:

```
You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills.
```

Do NOT add any env variable to the invocation lines — see Global
Constraints (a marker would leak into the persistent per-repo broker
environment and suppress the bootstrap for later non-review sessions).

- [ ] **Step 3: Add the line to the approach-gate prompt guidance**

In `skills/brainstorming/codex-approach-gate.md` (Invocation section), after
the sentence about the prompt file pointing Codex at `approach-context.md`,
add:

```
The prompt file also carries, on one line: "You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills."
```

- [ ] **Step 4: Run the contract test (GREEN)**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the two suppression needles PASS; no pre-existing needle broke.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md skills/brainstorming/codex-approach-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(gate): prompt-level bootstrap suppression for stateless reviewer sessions"
```

---

### Task 8: Gate-doc amendments + contract-test needles

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§1, §3, §4b, §5, Red Flags)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (new needles)
- Verify unchanged: `skills/brainstorming/codex-approach-gate.md` (inherits §1 by reference — read it and confirm no contradiction; edit only if it names removed §1 specifics)

**Interfaces:**
- Consumes: script names and JSON contracts from Tasks 3, 4, 5 exactly as specified there.
- Produces: the amended prose contract that eval scenarios (Task 9) and live gates run against.

- [ ] **Step 1: Add the new contract needles (RED)**

Append to `tests/codex-review-gate/test-gate-contract.sh`, before the final
summary/exit lines, following the file's existing `assert_contains` style:

```bash
echo "Gate reliability hardening (6.3.0):"
assert_contains "$GATE" "scripts/codex-preflight" "gate uses codex-preflight"
assert_contains "$GATE" '"stale-broker"' "gate handles stale-broker status"
assert_contains "$GATE" '"not-ready"' "gate handles not-ready status"
assert_contains "$GATE" "base-ref-ok" "gate requires base-ref-ok before launch"
assert_contains "$GATE" "verdict-normalize" "gate uses verdict-normalize"
assert_contains "$GATE" 'launch `adversarial-review` without a passing `base-ref-ok`' "red flag: base validation"
assert_contains "$GATE" 'a `verdict-normalize` result of `approved` counts as approval' "red flag: verdict authority"
```

Also in this step, update the **existing** needles that pin the old verdict
authority, in `test-gate-contract.sh`:

- The version-pin needle (search for `1.0.5`): Task 8 Step 2 rewrites that
  §1 sentence, so change the expected string to the exact new phrase
  `codex-plugin-cc **1.0.5–1.0.6**` (note the en dash).
- Any needle asserting `.storedJob.result.result` (or the old field-path
  sentence) **as the place to read the verdict**: verdict extraction moves
  into `verdict-normalize` (its 1.0.5/1.0.6 payload fixtures in
  `test-verdict-normalize.sh` carry the field-path coverage now). Replace
  each such needle with `assert_contains "$GATE" "Write the captured result"
  "verdict read via capture + verdict-normalize"`. Leave `.job.status`
  watch/recovery needles unchanged — status polling is job-lifecycle
  guidance, not verdict authority.

**Needle rule for Steps 2–5:** every needle above must be a substring of a
single source line in the amended doc — when inserting the texts below, keep
each needle phrase unwrapped on one line (the contract test collapses
newlines to spaces, which would inject stray `>` from wrapped blockquotes).

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the 7 new needles FAIL, and the updated version-pin needle FAILS
(it now asserts the §1 text that lands in Step 2); all other pre-existing
needles PASS (including Task 7's suppression needles).

- [ ] **Step 2: Amend §1 (probe → preflight)**

In `codex-review-gate.md`, replace the §1 body (keep the section number and
the dev-checkout fallback note pattern). New §1 text:

```markdown
## 1. Preflight availability

Run the preflight by its absolute path inside the installed plugin
(`$CLAUDE_PLUGIN_ROOT` is set by Claude Code to this plugin's install
directory):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/requesting-code-review/scripts/codex-preflight"
```

(When working inside a hyperpowers dev checkout rather than an installed
plugin, `$CLAUDE_PLUGIN_ROOT` is unset; run
`bash skills/requesting-code-review/scripts/codex-preflight` from the repo
root instead. If it is unset in an *installed-plugin* session, resolve the
newest install: `ls -d ~/.claude/plugins/cache/hyperpowers/hyperpowers/*/ | sort -V | tail -1`.)

It prints one JSON line. Branch on `.status`:

- **`"ok"`** — a Codex review can run. Capture `.codexPath` as `CODEX_PATH`
  and `.codexVersion` as `CODEX_VERSION` (report it in the §6 hand-back).
  The JSON field paths in §4b's payloads are verified against codex-plugin-cc
  **1.0.5–1.0.6**; on another version, confirm a field exists in the actual
  payload before relying on it.
- **`"not-installed"`** — emit the **No-Codex notice** (§2) and continue the
  skill unchanged. Do not treat this as an error.
- **`"not-ready"`** — the plugin is installed but Codex is not ready
  (`.reason` says why: not authenticated, CLI missing, transient handshake
  failure that outlasted retries). Tell the user once:
  "Note: codex-plugin-cc is installed but not ready (<.reason>), so this
  review will run without an additional Codex review." Then continue exactly
  as the §2 degrade path.
- **`"stale-broker"`** — the plugin is installed but this repo's companion
  broker is dead (its temp dir was likely purged mid-session; the session-
  start janitor clears these at startup/compact, so this means it died
  since). Tell the user once, quoting `.recovery` verbatim:
  "Note: the Codex companion broker for this repo is stale, so this review
  will run without a Codex review. To restore Codex for the next gate, run
  this in a terminal: <.recovery>" — then continue as the §2 degrade path.
  The next gate re-runs preflight and picks the recovery up automatically.
- **Non-zero exit** (internal failure) — treat exactly as `not-installed`:
  §2 notice, degrade, never an error.

Preflight at most once per skill run and reuse the result for every gate in
that run. Every degrade notice must name its status (`not-installed`,
`not-ready`, or `stale-broker`) so the §6 hand-back — and future transcript
mining — can attribute exactly why a gate ran without Codex.
```

Keep §2 (the install-lines notice) unchanged.

- [ ] **Step 3: Amend §3 (base validation + env marker)**

Three edits in §3:

(a) Before the "**Per-task code**" recipe, insert:

```markdown
**Base validation — required before every `adversarial-review` launch.** Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/base-ref-ok" <BASE_SHA>
```

If it prints `"ok":true`, use `.resolvedBase` as the launch base. If
`"ok":false`, do NOT launch: an invalid base (empty-tree hash, no merge-base,
base==HEAD, unresolvable ref) makes the companion's merge-base fatal mid-job
and orphans the review as `running` forever. Fix the base (common causes:
wrong branch name, an unborn branch, a recorded SHA from a different
worktree) and re-validate; if it cannot be fixed, degrade with the reason —
"Codex review skipped: invalid review base (<reason>)."
```

(b) Do NOT add any env variable to the invocation lines. Reviewer bootstrap
suppression is the prompt-level line Task 7 added to each template; an env
marker would leak into the persistent per-repo broker environment (Global
Constraints). Verify Task 7's lines survived this task's §3 edits intact.

- [ ] **Step 4: Amend §4b (verdict-normalize as sole authority)**

In §4b, after the "A Codex result has three outcomes" paragraph, insert:

```markdown
**Mechanical normalization — the only approval authority.** Write the
captured result (the foreground `task` stdout, or `result <job-id> --json`
output) to a file inside `GATE_DIR`, then run:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/verdict-normalize" "$GATE_DIR/<captured-output-file>"
```

Its tri-state `.result` is the review outcome: `approved`, `blocking`, or
`incomplete`. Only a `verdict-normalize` result of `approved` counts as
approval — never your own reading of the raw output, and never the absence
of output. On `blocking`, read the raw findings text as usual to do the
fixing; normalization gates only the decision. On `incomplete`, follow the
recovery steps below, re-capture, and re-normalize; if it remains
`incomplete`, surface "Codex review did not complete — not an approval."
```

And in the existing "Required handling" list, point item 1 at the tri-state:
replace "Do not interpret an incomplete result as approval, and do not
interpret it as findings." with "Do not interpret an incomplete result as
approval, and do not interpret it as findings — `verdict-normalize` returns
`incomplete` for exactly this case, and only `approved` exits the gate."

Then remove raw payload paths as *verdict* guidance wherever the doc offers
them (spec §4.7: field-path knowledge lives in the script now):

- §3 code-recipe step 4 ("Read the verdict"): replace "the parsed
  verdict/findings are at `.storedJob.result.result`, the raw review text at
  `.storedJob.result.rawOutput`" with "write the full `result <job-id>
  --json` output to a file inside `GATE_DIR` and run `verdict-normalize` on
  it; the raw review text for reading findings remains at
  `.storedJob.result.rawOutput`".
- §4b's authoritative-signals sentence: keep `.job.status` as the job
  lifecycle signal, but point the verdict itself at the captured-file +
  `verdict-normalize` flow instead of naming result payload paths.

- [ ] **Step 5: Amend §5 (exit rule) and add two Red Flags**

In §5, in the loop-exit description, state the exit condition mechanically:

```markdown
The loop's exit rule is mechanical: a round converges only when
`verdict-normalize` returns `"result":"approved"` for that round's captured
output. `blocking` continues the fix loop; `incomplete` follows §4b recovery
and never converges the loop by itself.
```

Add two Red Flags alongside the existing ones at the end of §4b/§3:

```markdown
> **Red Flag — Never** launch `adversarial-review` without a passing `base-ref-ok`
> on the exact base you pass. A bad base does not fail fast — it orphans the
> review as `running` forever with no verdict.

> **Red Flag — Never** derive approval yourself from raw companion output:
> only a `verdict-normalize` result of `approved` counts as approval. If the
> script says `incomplete`, there is no verdict, no matter how finished the
> raw text looks.
```

- [ ] **Step 6: Verify approach-gate inheritance**

Read `skills/brainstorming/codex-approach-gate.md` §"Probe and Degrade". It
says "Run the §1 probe from ../requesting-code-review/codex-review-gate.md" —
update the word "probe" to "preflight" if present, and confirm its degrade
notice remains valid (it emits its own approach-specific notice; the
per-status §1 notices apply when it delegates). No other edit unless it names
`codex-available.sh` directly (if it does, leave it — the wrapper still works).

- [ ] **Step 7: Run contract tests to verify GREEN**

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: all needles pass — the 7 new ones, the updated version-pin needle,
Task 7's suppression needles, and every untouched pre-existing one (if an
untouched needle broke, the amendment deleted contract text it shouldn't
have — restore that text).

- [ ] **Step 8: Micro-test the reworded §1 branching (writing-skills discipline)**

Dispatch 2 fresh single-shot subagents (no shared history, tools forbidden,
plain-text answer). Each gets: the new §1 text verbatim, plus one stimulus —
(a) preflight printed `{"status":"stale-broker","recovery":"mv '/x/broker.json' ..."}`;
(b) preflight printed `{"status":"not-ready","reason":"not authenticated"}`.
Ask: "State your next action and the exact notice you emit."
PASS bar: (a) quotes the recovery command in the notice and continues
degraded without treating it as an error or retrying; (b) names not-ready
with the reason and continues degraded. Record both responses in the task
report. If either misreads, tighten the §1 wording and re-probe once.

- [ ] **Step 9: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md skills/brainstorming/codex-approach-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(gate): preflight statuses, base validation, and mechanical verdict authority in gate doc"
```

---

### Task 9: Eval scenario — stale-broker attributed degrade

**Files:**
- Create: `evals/scenarios/codex-gate-stale-broker-attributed/` (in the
  separate `hyperpowers-evals` clone at `evals/` — commits there, not in this
  repo)
- Verify: existing scenarios `codex-gate-incomplete-not-approval` and
  `codex-gate-converges-on-reraise` still validate.

**Interfaces:**
- Consumes: the amended gate doc semantics from Task 8 (`codex-preflight`
  statuses) and the preflight test overrides from Task 3.
- Produces: a `bun run quorum check`-passing scenario asserting attributed
  degrade behavior.

- [ ] **Step 1: Study the sibling scenario's exact layout**

Read every file in `evals/scenarios/codex-gate-incomplete-not-approval/`
(scenario definition, stub `codex-companion.mjs`, checks, AC prose). The new
scenario mirrors that structure exactly — same file names, same registration
mechanism, no TypeScript/registry changes.

- [ ] **Step 2: Author the scenario**

Behavior under test: the agent runs the gate in a repo whose preflight
reports `stale-broker`, and must (1) emit the attributed notice naming
stale-broker, (2) surface the recovery command verbatim, (3) proceed degraded
without fabricating any Codex verdict, and (4) not treat it as an error.

Environment (set via the scenario's setup, using the Task 3 overrides so no
real Codex/auth/network is needed):
- A fixture state root with a dead broker for the scenario repo:
  `HYPERPOWERS_CODEX_STATE_ROOT` pointing at a dir containing
  `<repo-basename>-0123456789abcdef/broker.json` whose `sessionDir` does not
  exist (exact shape from the Task 1 test's `mk_broker`).
- `HYPERPOWERS_PLUGINS_FILE` pointing at a fixture registry whose
  `installPath` contains a stub `scripts/codex-companion.mjs` (so preflight
  reaches the broker check and returns `stale-broker` — the stub companion is
  never invoked, and its body can be the sibling scenario's stub with all
  responses unused).
- `HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}'` (proves the broker check
  fires before setup).

Deterministic checks (mirroring the sibling's checks style): the
`requesting-code-review` skill was invoked; `Bash` invoked `codex-preflight`;
the transcript contains `stale-broker` and `broker.json.stale-`. AC prose:
the notice attributes the degrade and quotes the recovery command; no Codex
verdict is claimed anywhere.

- [ ] **Step 3: Validate**

Run (from `evals/`): `bun run quorum check`
Expected: full suite validates, including the new scenario (sibling count + 1).
The two existing codex-gate scenarios must still validate unchanged.

- [ ] **Step 4: Live run (real terminal — sandbox blocks `git init` under `evals/results/`)**

From a real terminal, per `evals/README.md` auth setup:

```bash
cd evals
bun run quorum run scenarios/codex-gate-stale-broker-attributed --coding-agent claude
bun run quorum show
```

Expected: `final = pass`. If the sandbox blocks the in-session attempt,
record the exact command for the user and mark this step as requiring a
manual terminal run (this is the established boundary from the 2026-06-30
eval evidence — do not fake the result).

- [ ] **Step 5: Commit (in `evals/` — its own repo)**

```bash
cd evals && git add scenarios/codex-gate-stale-broker-attributed && git commit -m "test: stale-broker attributed degrade scenario for the codex gate"
```

---

### Task 10: Upstream issue drafts (file only with user approval)

**Files:**
- Create: drafts in the SDD scratch dir (not in the repo — never commit issue drafts)

**Interfaces:**
- Consumes: evidence numbers from the spec §1 and mining summary.
- Produces: five ready-to-file issue bodies presented to the user; filed
  via `gh` against `openai/codex-plugin-cc` only after explicit approval
  (outward-facing action); filed URLs recorded in this plan document.

- [ ] **Step 1: Draft the four issues**

Write five short issue bodies (title + problem + observed evidence + minimal
proposal, each ≤ 25 lines, no AI-attribution, no internal paths — describe
mechanisms generically). These mirror spec §4.8 exactly:

1. **Broker self-heal on stale state** — `broker.json` survives macOS temp-dir
   purges; every subsequent call fails `connect ENOENT <sock>`. Proposal: on
   connect-ENOENT, validate `sessionDir`/pid and re-provision instead of
   failing terminally.
2. **Guarantee a terminal verdict record** — review turns can end without a
   parseable verdict (observed: long-running review truncated mid-verdict;
   `result` then has `result: null` with exit 0). Proposal: mark such jobs
   `incomplete` explicitly rather than leaving a null-verdict success shape.
3. **Per-request flag to skip skill bootstraps in launched review sessions** —
   stateless reviewer sessions re-read harness bootstrap context every round.
   Proposal: a documented per-request flag on `task`/`review` launch that
   starts the child session bootstrap-free. Note in the issue why a caller-
   side env var cannot work: the persistent broker inherits and replays the
   provisioning environment across later, unrelated sessions.
4. **SessionEnd `EPERM ... unlink broker.json`** — the companion's session-end
   cleanup intermittently fails to unlink its own broker record, leaving the
   stale-broker state behind. Proposal: diagnose the permission/ordering
   issue and make cleanup best-effort-with-retry rather than silently
   leaving the record.
5. **`merge-base` failure with invalid `--base` orphans jobs as `running`** —
   an empty-tree/invalid base fatals mid-job and the job never reaches a
   terminal state; `status --wait` burns its deadline forever. Proposal:
   validate the base before starting the worker and record `failed` on git
   fatals.

- [ ] **Step 2: Present to the user for filing approval**

Show all five drafts. Ask explicitly whether to file them via
`gh issue create --repo openai/codex-plugin-cc` (needs the proxy env from
CLAUDE.md for network). File only the ones approved. Record the filed issue
URLs by appending a `**Filed:**` list to THIS plan document at the end of
this task section (acceptance criterion 7 requires the URLs recorded in the
plan's upstream task section). If the user declines, note "not filed by
user decision" there instead and stop.

**Filed:** (2026-07-23) The human partner is filing all five manually — by
explicit decision, to keep AI attribution out of the filed issues. The
ready-to-file document is
`docs/hyperpowers/2026-07-23-codex-plugin-cc-upstream-issues.md` (Issue 3's
"Observed" section was corrected during preparation: the broker-environment
analysis moved from Observed to the Proposal rationale, and an untested env
variable name was removed). Record the issue URLs below once filed:

- Issue 1 (stale-socket self-heal): _pending_
- Issue 2 (null-result verdict truncation): _pending_
- Issue 3 (per-request bootstrap skip): _pending_
- Issue 4 (EPERM on broker.json unlink): _pending_
- Issue 5 (invalid --base orphans job): _pending_

---

### Task 11: Version bump, full sweep, and release notes

**Files:**
- Modify: version-declared files via `scripts/bump-version.sh` (driven by `.version-bump.json`)

**Interfaces:**
- Consumes: all prior tasks merged.
- Produces: 6.3.0 across all declared files; full test suite green.

- [ ] **Step 1: Full test sweep**

Run:
```bash
for t in tests/codex-review-gate/test-*.sh tests/hooks/test-*.sh; do
  echo "== $t"; bash "$t" || echo "FAILED: $t"
done
bash scripts/lint-shell.sh
```
Expected: every script prints `ALL PASS` (or its own pass marker); lint clean.
Any failure blocks the bump — fix first.

- [ ] **Step 2: Bump**

Run: `bash scripts/bump-version.sh 6.3.0`
Then: `bash scripts/bump-version.sh --audit`
Expected: audit reports no stale `6.2.x` strings in declared files.

- [ ] **Step 3: Commit**

```bash
git add -A ':!docs/hyperpowers'
git commit -m "chore: bump 6.2.x -> 6.3.0 for gate reliability hardening"
```

- [ ] **Step 4: Verify working tree**

Run: `git status --short`
Expected: only `docs/hyperpowers/` spec/plan files remain modified/untracked —
per repo convention they are committed only when the user explicitly asks.
(Memory note: this repo intentionally tracks `docs/hyperpowers/`; ask the
user whether to commit the spec + plan for this feature as a final step.)
