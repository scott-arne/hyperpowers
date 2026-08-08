# Gate Resilience & Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ungated work durable and sweepable, round ceilings mechanical, and gate health measurable from scratch dirs.

**Architecture:** Cache-native repo ledger (spec §2): three new narrow checker scripts (`ungated-ledger`, `gate-round`, `gate-telemetry`) plus a session-start notice and gate-doc amendments wiring three append moments, a consent-gated sweep (§7), and mechanical round counting into the existing prose flow.

**Tech Stack:** bash + node built-ins only (no jq). Tests are bash scripts under `tests/`.

**Source spec:** `docs/hyperpowers/specs/2026-07-23-gate-resilience-telemetry-design.md`

## Global Constraints

- Repo key derivation MUST be byte-identical to `sdd-dir`: `key=$(printf '%s' "$(git rev-parse --absolute-git-dir)" | git hash-object --stdin)`. Never shasum (platform-variant) and never a different input.
- Ledger root: `${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/ungated/<key>/ledger.jsonl` — a NEW tree outside `sdd/`; nothing GCs it. All three tools honor `XDG_CACHE_HOME` (tests set it for hermetic fixtures; no extra override env vars).
- Script contract (6.3.0 discipline): exit 0 for every determinate answer with single-line JSON on stdout; exit 2 only for usage/internal errors. `chmod +x` every new script; `bash scripts/lint-shell.sh` stays clean.
- Event schema `v:1` exactly as spec §4.1; `sweepable` derived from `--gate` (`spec|plan` → false; `task|final|adhoc` → true and `--base`/`--head` required, else exit 2). `pending --count` returns exactly `{"count":N,"skipped":M}`.
- Ledger classes: `degraded-gate` | `backstop-fix` | `incomplete-review`. Preflight internal failure gets its own token `preflight-error` (notice AND ledger).
- Lock: mkdir lockdir `ledger.lock/` beside the ledger; stale takeover after 30s; takeover recorded in the event's `note`. Readers never lock.
- The session-start notice must never break, slow, or pollute `hooks/session-start` stdout (janitor bar: guarded subshell, swallowed failures, instant no-op when the root is absent).
- Sweep (§7): review exactly the recorded `base..head`, never `base..current-HEAD`; source-repo anchoring — capture `SWEEP_REPO` before any worktree, `GATE_DIR` created from the source repo, `"$SWEEP_REPO"` passed to EVERY `ungated-ledger` call; consent required before any sweep review launches.
- Needle rule: every new contract-test needle must be a substring of ONE source line in the amended docs.
- No AI-attribution lines anywhere; never commit `docs/hyperpowers/` files; per-task commits per SDD cadence with branch-level diff approval before merge (AGENTS.md satisfied at branch level).
- Version bump to 6.4.0 only in the final task via `scripts/bump-version.sh`.

---

### Task 1: `ungated-ledger` — durable ungated-work record

**Files:**
- Create: `skills/requesting-code-review/scripts/ungated-ledger`
- Test: `tests/codex-review-gate/test-ungated-ledger.sh`

**Interfaces:**
- Consumes: nothing (leaf utility).
- Produces (later tasks rely on these exact contracts):
  - `ungated-ledger append --class C --gate G [--base SHA --head SHA] [--status TOKEN] [--gate-dir P] [--note S] [repo-dir]` → `{"ok":true,"id":"<id>"}`
  - `ungated-ledger pending [--count] [repo-dir]` → JSON array of pending ungated events, or `{"count":N,"skipped":M}`
  - `ungated-ledger mark-swept --ref ID --verdict approved|blocking|incomplete|unsweepable [--note S] [repo-dir]` → `{"ok":true}`

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-ungated-ledger.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UL="$REPO_ROOT/skills/requesting-code-review/scripts/ungated-ledger"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $1)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/ul-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
base_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
head_sha="$(git -C "$repo" rev-parse HEAD)"

echo "ungated-ledger:"

# append a sweepable code-gate event
out="$(bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status stale-broker --note 'gate ran degraded' "$repo")"
expect "$out" '"ok":true' "code-gate append ok"
id1="$(printf '%s' "$out" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"

# ledger file exists under the sdd-dir-compatible key
key="$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)"
[ -f "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" ] && pass "ledger at derived key path" || fail "ledger at derived key path"

# doc-gate append: sweepable false, no base/head required
out="$(bash "$UL" append --class degraded-gate --gate spec --status not-ready --note 'doc gate degraded' "$repo")"
expect "$out" '"ok":true' "doc-gate append ok"
grep -q '"sweepable":false' "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" && pass "doc event sweepable:false" || fail "doc event sweepable:false"

# sweepable gate without base/head -> usage error (exit 2)
bash "$UL" append --class backstop-fix --gate task --note x "$repo" >/dev/null 2>&1 && fail "missing base/head exits 2" || pass "missing base/head exits 2"

# pending: only the sweepable event counts
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":1' "pending count excludes unsweepable"
expect "$out" '"skipped":0' "skipped is zero on clean ledger"
out="$(bash "$UL" pending "$repo")"
expect "$out" "$id1" "pending list carries the event id"
expect "$out" '"status":"stale-broker"' "pending carries status token"

# mark-swept closes it
out="$(bash "$UL" mark-swept --ref "$id1" --verdict approved --note 'sweep clean' "$repo")"
expect "$out" '"ok":true' "mark-swept ok"
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":0' "pending zero after sweep"

# corrupt line tolerance: skipped counted, count still right
out="$(bash "$UL" append --class incomplete-review --gate final --base "$base_sha" --head "$head_sha" --note 'incomplete' "$repo")"
expect "$out" '"ok":true' "third append ok"
echo '{not json' >> "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl"
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":1' "count correct despite corrupt line"
expect "$out" '"skipped":1' "corrupt line reported in skipped"

# concurrent appends: both events present, file stays valid JSONL (+1 corrupt)
( bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status not-ready --note A "$repo" >/dev/null ) &
( bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status not-ready --note B "$repo" >/dev/null ) &
wait
out="$(bash "$UL" pending --count "$repo")"
expect "$out" '"count":3' "concurrent appends both recorded"

# stale lock takeover: pre-create an old lockdir, append must still succeed
lock="$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.lock"
mkdir -p "$lock"
touch -t "$(date -v-1H +%Y%m%d%H%M 2>/dev/null || date -d '1 hour ago' +%Y%m%d%H%M)" "$lock"
out="$(bash "$UL" append --class degraded-gate --gate plan --status not-installed --note stale-lock-case "$repo")"
expect "$out" '"ok":true' "append succeeds via stale-lock takeover"
grep -q 'lock takeover' "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" && pass "takeover noted in event" || fail "takeover noted in event"

# worktree anchoring (spec 4.4 / acceptance 4 substrate): a linked worktree
# derives a DIFFERENT key, so sweep closures must pass the source repo
# explicitly. Prove: explicit-repo mark-swept closes the source entry and
# creates nothing under the worktree's key.
out="$(bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status not-ready --note wt-case "$repo")"
idw="$(printf '%s' "$out" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
wt="$work/wt"; git -C "$repo" worktree add --detach "$wt" >/dev/null 2>&1
wkey="$(printf '%s' "$(git -C "$wt" rev-parse --absolute-git-dir)" | git -C "$wt" hash-object --stdin)"
[ "$wkey" != "$key" ] && pass "worktree derives a different key" || fail "worktree derives a different key"
before="$(bash "$UL" pending --count "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
( cd "$wt" && bash "$UL" mark-swept --ref "$idw" --verdict approved --note swept-from-worktree "$repo" >/dev/null )
after="$(bash "$UL" pending --count "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
[ "$after" -eq $((before - 1)) ] && pass "explicit repo-dir closes the SOURCE entry from worktree cwd" || fail "explicit repo-dir closes the SOURCE entry (before=$before after=$after)"
[ ! -e "$XDG_CACHE_HOME/hyperpowers/ungated/$wkey" ] && pass "nothing created under the worktree key" || fail "nothing created under the worktree key"
git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || true

# not a git repo -> exit 2
bash "$UL" pending --count "$work" >/dev/null 2>&1 && fail "non-repo exits 2" || pass "non-repo exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-ungated-ledger.sh`
Expected: FAIL (script missing), non-zero exit.

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/ungated-ledger`:

```bash
#!/usr/bin/env bash
# ungated-ledger — durable record of work that shipped without a Codex
# confirmation (spec 4.1). Append-only JSONL under the user cache:
#   ${XDG_CACHE_HOME:-~/.cache}/hyperpowers/ungated/<key>/ledger.jsonl
# <key> is byte-identical to sdd-dir's derivation. The ungated/ root is
# deliberately OUTSIDE sdd/ — no GC touches it.
#
# Subcommands:
#   append --class degraded-gate|backstop-fix|incomplete-review
#          --gate spec|plan|task|final|adhoc
#          [--base SHA --head SHA] [--status TOKEN] [--gate-dir P]
#          [--note S] [repo-dir]              -> {"ok":true,"id":"..."}
#   pending [--count] [repo-dir]              -> array | {"count":N,"skipped":M}
#   mark-swept --ref ID --verdict approved|blocking|incomplete|unsweepable
#          [--note S] [repo-dir]              -> {"ok":true}
#
# sweepable derives from --gate: spec|plan -> false (base/head not needed);
# task|final|adhoc -> true, --base/--head required. swept events append —
# nothing is ever mutated. Writers take a mkdir lockdir (ledger.lock/) with
# a 30s stale takeover recorded in the event note; readers never lock.
# Exit 0 for determinate answers; exit 2 for usage/internal errors.
set -uo pipefail

command -v node >/dev/null 2>&1 || { echo "ungated-ledger: node not found" >&2; exit 2; }
sub="${1:-}"; shift || true
[ -n "$sub" ] || { echo "usage: ungated-ledger append|pending|mark-swept ..." >&2; exit 2; }

# Parse trailing repo-dir (last non-flag arg) and flags.
repo="."
class=""; gate=""; base=""; head=""; status=""; gatedir=""; note=""; ref=""; verdict=""; count_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --class) class="$2"; shift 2 ;;
    --gate) gate="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --head) head="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --gate-dir) gatedir="$2"; shift 2 ;;
    --note) note="$2"; shift 2 ;;
    --ref) ref="$2"; shift 2 ;;
    --verdict) verdict="$2"; shift 2 ;;
    --count) count_only=1; shift ;;
    -*) echo "ungated-ledger: unknown flag $1" >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done

git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "ungated-ledger: not inside a git repository: $repo" >&2; exit 2; }
# Byte-identical to sdd-dir's derivation.
key=$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)
root="${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/ungated/${key}"
ledger="$root/ledger.jsonl"

acquire_lock() { # sets LOCK_NOTE on takeover
  LOCK_NOTE=""
  local lock="$root/ledger.lock" waited=0
  while ! mkdir "$lock" 2>/dev/null; do
    # Stale takeover: lockdir older than 30s. Portability trap: GNU stat
    # treats -f as filesystem mode (%m = mount point, non-numeric, exit 0),
    # so probe GNU -c %Y FIRST and numerically validate every result; an
    # unparseable timestamp is treated as fresh (no takeover) — fail safe.
    local now lockts age
    now=$(date +%s)
    lockts=$(stat -c %Y "$lock" 2>/dev/null)
    case "$lockts" in ''|*[!0-9]*) lockts=$(stat -f %m "$lock" 2>/dev/null) ;; esac
    case "$lockts" in ''|*[!0-9]*) lockts="$now" ;; esac
    age=$((now - lockts))
    if [ "$age" -ge 30 ]; then
      rmdir "$lock" 2>/dev/null || true
      if mkdir "$lock" 2>/dev/null; then LOCK_NOTE=" [lock takeover after ${age}s]"; return 0; fi
    fi
    waited=$((waited + 1))
    [ "$waited" -ge 70 ] && { echo "ungated-ledger: could not acquire lock" >&2; exit 2; }
    sleep 0.5
  done
}
release_lock() { rmdir "$root/ledger.lock" 2>/dev/null || true; }

case "$sub" in
  append)
    case "$class" in degraded-gate|backstop-fix|incomplete-review) : ;; *)
      echo "ungated-ledger: --class must be degraded-gate|backstop-fix|incomplete-review" >&2; exit 2 ;; esac
    case "$gate" in
      spec|plan) sweepable=false ;;
      task|final|adhoc)
        sweepable=true
        [ -n "$base" ] && [ -n "$head" ] || {
          echo "ungated-ledger: --base and --head are required for gate '$gate'" >&2; exit 2; } ;;
      *) echo "ungated-ledger: --gate must be spec|plan|task|final|adhoc" >&2; exit 2 ;;
    esac
    mkdir -p "$root"
    reporoot="$(cd "$(git -C "$repo" rev-parse --show-toplevel)" && pwd -P)"
    acquire_lock
    trap release_lock EXIT
    id="$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
    node -e '
      const [id, cls, gate, ts, repo, base, head, status, sweepable, gateDir, note] = process.argv.slice(1);
      const e = { v: 1, id, event: "ungated", class: cls, gate, ts, repo,
        base: base || null, head: head || null, status: status || null,
        sweepable: sweepable === "true", gateDir: gateDir || null, note };
      process.stdout.write(JSON.stringify(e) + "\n");
    ' "$id" "$class" "$gate" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reporoot" \
      "$base" "$head" "$status" "$sweepable" "$gatedir" "${note}${LOCK_NOTE}" >> "$ledger" \
      || { echo "ungated-ledger: write failed" >&2; exit 2; }
    release_lock; trap - EXIT
    printf '{"ok":true,"id":"%s"}\n' "$id"
    ;;
  pending)
    [ -f "$ledger" ] || { if [ "$count_only" -eq 1 ]; then echo '{"count":0,"skipped":0}'; else echo '[]'; fi; exit 0; }
    node -e '
      const fs = require("fs");
      const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(l => l.trim() !== "");
      let skipped = 0; const events = [];
      for (const l of lines) { try { events.push(JSON.parse(l)); } catch (e) { skipped++; } }
      const sweptRefs = new Set(events.filter(e => e.event === "swept").map(e => e.ref));
      const pending = events.filter(e => e.event === "ungated" && e.sweepable === true && !sweptRefs.has(e.id));
      if (process.argv[2] === "count") {
        process.stdout.write(JSON.stringify({ count: pending.length, skipped }) + "\n");
      } else {
        process.stdout.write(JSON.stringify(pending) + "\n");
      }
    ' "$ledger" "$([ "$count_only" -eq 1 ] && echo count || echo list)"
    ;;
  mark-swept)
    [ -n "$ref" ] || { echo "ungated-ledger: --ref is required" >&2; exit 2; }
    case "$verdict" in approved|blocking|incomplete|unsweepable) : ;; *)
      echo "ungated-ledger: --verdict must be approved|blocking|incomplete|unsweepable" >&2; exit 2 ;; esac
    mkdir -p "$root"
    acquire_lock
    trap release_lock EXIT
    node -e '
      const [ref, ts, verdict, note] = process.argv.slice(1);
      process.stdout.write(JSON.stringify({ v: 1, event: "swept", ref, ts, verdict, note }) + "\n");
    ' "$ref" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$verdict" "${note}${LOCK_NOTE}" >> "$ledger" \
      || { echo "ungated-ledger: write failed" >&2; exit 2; }
    release_lock; trap - EXIT
    echo '{"ok":true}'
    ;;
  *)
    echo "ungated-ledger: unknown subcommand '$sub'" >&2; exit 2 ;;
esac
```

Then: `chmod +x skills/requesting-code-review/scripts/ungated-ledger`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-ungated-ledger.sh`
Expected: `ALL PASS`. Also `bash scripts/lint-shell.sh` clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/ungated-ledger tests/codex-review-gate/test-ungated-ledger.sh
git commit -m "feat(gate): durable ungated-work ledger with sweep bookkeeping"
```

---

### Task 2: `gate-round` — mechanical round counting

**Files:**
- Create: `skills/requesting-code-review/scripts/gate-round`
- Test: `tests/codex-review-gate/test-gate-round.sh`

**Interfaces:**
- Consumes: a `GATE_DIR` (any writable dir; in practice from `codex-review-dir`).
- Produces: `gate-round GATE_DIR --ceiling N [--gate T] [--peek]` →
  single-line JSON `{"round":K,"ceiling":N,"verdict":"proceed|backstop"}`
  plus, on `backstop`, a `"reminder"` field with the class-2 append
  template. `--peek` never increments and answers with what the NEXT
  advance would return (`proceed` if `round+1 <= ceiling`, else
  `backstop`) — the verdict enum is ALWAYS `proceed|backstop`, nothing
  else. State file: `GATE_DIR/gate-round.json`
  (`{"round":K,"ceiling":N,"gate":"spec|plan|task|final|adhoc|unknown"}`) —
  Task 6's telemetry buckets by its `gate` field.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-gate-round.sh`:

```bash
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

# determinate answers exit 0, missing dir exits 2
bash "$GR" "$gd" --ceiling 3 >/dev/null; [ $? -eq 0 ] && pass "backstop exits 0" || fail "backstop exits 0"
bash "$GR" "$work/nope" --ceiling 3 >/dev/null 2>&1 && fail "missing dir exits 2" || pass "missing dir exits 2"
bash "$GR" "$gd" >/dev/null 2>&1 && fail "missing ceiling exits 2" || pass "missing ceiling exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-round.sh`
Expected: FAIL (script missing).

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/gate-round`:

```bash
#!/usr/bin/env bash
# gate-round GATE_DIR --ceiling N [--peek] — mechanical round counter for
# one gate invocation (spec 4.2). The counter lives in GATE_DIR beside the
# round ledger, so concurrent gates never share state. Counting is the ONLY
# job: the ledger append on backstop belongs to the gate doc's backstop
# procedure — the "reminder" field carries the exact command template so it
# cannot be forgotten. Exit 0 for proceed AND backstop; exit 2 for usage.
set -uo pipefail

gd="${1:-}"; shift || true
[ -n "$gd" ] && [ -d "$gd" ] || { echo "usage: gate-round GATE_DIR --ceiling N [--gate T] [--peek]" >&2; exit 2; }
ceiling=""; peek=0; gate=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ceiling) ceiling="$2"; shift 2 ;;
    --gate) gate="$2"; shift 2 ;;
    --peek) peek=1; shift ;;
    *) echo "gate-round: unknown arg $1" >&2; exit 2 ;;
  esac
done

state="$gd/gate-round.json"
round=0; prev_ceiling=""; prev_gate=""
if [ -f "$state" ]; then
  round="$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).round||0)}catch(e){console.log(0)}' "$state")"
  prev_ceiling="$(node -e 'try{const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).ceiling;console.log(c==null?"":c)}catch(e){console.log("")}' "$state")"
  prev_gate="$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).gate||"")}catch(e){console.log("")}' "$state")"
fi

if [ "$peek" -eq 1 ]; then
  # Peek answers with what the NEXT advance would return; enum stays
  # proceed|backstop only.
  c="${prev_ceiling:-${ceiling:-0}}"
  next=$((round + 1))
  verdict=$([ -n "$c" ] && [ "$c" -gt 0 ] && [ "$next" -gt "$c" ] && echo backstop || echo proceed)
  printf '{"round":%s,"ceiling":%s,"verdict":"%s"}\n' "$round" "${c:-0}" "$verdict"
  exit 0
fi

[ -n "$ceiling" ] || { echo "gate-round: --ceiling N is required to advance" >&2; exit 2; }
round=$((round + 1))
g="${gate:-${prev_gate:-unknown}}"
case "$g" in spec|plan|task|final|adhoc|unknown) : ;; *) g="unknown" ;; esac
printf '{"round":%s,"ceiling":%s,"gate":"%s"}\n' "$round" "$ceiling" "$g" > "$state"

if [ "$round" -gt "$ceiling" ]; then
  printf '{"round":%s,"ceiling":%s,"verdict":"backstop","reminder":"If fixes ship in this backstop exit, record them: ungated-ledger append --class backstop-fix --gate <task|final|adhoc> --base <task base sha> --head <head sha> --gate-dir %s --note <one line> <repo-dir>"}\n' "$round" "$ceiling" "$gd"
else
  printf '{"round":%s,"ceiling":%s,"verdict":"proceed"}\n' "$round" "$ceiling"
fi
```

Then: `chmod +x skills/requesting-code-review/scripts/gate-round`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-gate-round.sh`
Expected: `ALL PASS`. Lint clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-round tests/codex-review-gate/test-gate-round.sh
git commit -m "feat(gate): mechanical per-gate round counter with backstop reminder"
```

---

### Task 3: Session-start ungated notice

**Files:**
- Modify: `hooks/session-start` (insert a guarded block AFTER the `session_context=` assignment, BEFORE the platform emission branches — see Step 3)
- Test: `tests/hooks/test-ungated-notice.sh`

**Interfaces:**
- Consumes: `ungated-ledger pending --count` (Task 1) via `${PLUGIN_ROOT}/skills/requesting-code-review/scripts/ungated-ledger`; the hook's cwd (the project dir) is the repo argument.
- Produces: when count > 0, the injected session context gains one line:
  `N ungated review item(s) pending sweep in this repo — say "run the review sweep" to clear them.`

- [ ] **Step 1: Write the failing test**

Create `tests/hooks/test-ungated-notice.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"
UL="$REPO_ROOT/skills/requesting-code-review/scripts/ungated-ledger"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/un-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
b="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
h="$(git -C "$repo" rev-parse HEAD)"

run_hook() { (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null); }

echo "ungated notice:"

# zero pending -> no notice, valid JSON
out="$(run_hook)"
printf '%s' "$out" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null \
  && pass "stdout valid JSON (zero pending)" || fail "stdout valid JSON (zero pending)"
printf '%s' "$out" | grep -q 'pending sweep' && fail "no notice at zero" || pass "no notice at zero"

# one pending -> notice present, still valid JSON
bash "$UL" append --class degraded-gate --gate task --base "$b" --head "$h" --status not-ready --note x "$repo" >/dev/null
out="$(run_hook)"
printf '%s' "$out" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null \
  && pass "stdout valid JSON (pending)" || fail "stdout valid JSON (pending)"
printf '%s' "$out" | grep -q '1 ungated review item' && pass "notice present with count" || fail "notice present with count (got no match)"
printf '%s' "$out" | grep -q 'hookSpecificOutput' && pass "bootstrap context intact" || fail "bootstrap context intact"

# non-repo cwd -> hook still works, no notice, no crash
out="$( (cd "$work" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>/dev/null) )"
printf '%s' "$out" | grep -q 'hookSpecificOutput' && pass "non-repo cwd no-op" || fail "non-repo cwd no-op"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/hooks/test-ungated-notice.sh`
Expected: FAIL on "notice present with count".

- [ ] **Step 3: Add the notice block to `hooks/session-start`**

Single insertion point: AFTER the `session_context=` assignment is built and BEFORE the platform printf emission branches (NOT next to the janitor — the janitor runs before `session_context` exists, and this block appends to it). Janitor bar applies: guarded, swallowed, stdout-pure.

```bash
# --- Ungated-work notice (spec 4.3) ----------------------------------------
# One cheap read: if this repo's ungated ledger has pending entries, add a
# single line to the injected context. Never breaks the hook, never speaks
# at zero, instant no-op outside a repo or when the root is absent.
ungated_notice="$(
  ( set +e
    ul="${PLUGIN_ROOT}/skills/requesting-code-review/scripts/ungated-ledger"
    [ -x "$ul" ] || exit 0
    out="$(bash "$ul" pending --count . 2>/dev/null)" || exit 0
    n="$(printf '%s' "$out" | node -e 'try{console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count||0)}catch(e){console.log(0)}' 2>/dev/null)"
    [ -n "$n" ] && [ "$n" -gt 0 ] 2>/dev/null || exit 0
    printf '%s ungated review item(s) pending sweep in this repo — say \\"run the review sweep\\" to clear them.' "$n"
  ) 2>/dev/null
)" || ungated_notice=""
if [ -n "$ungated_notice" ]; then
  session_context="${session_context}\n\n${ungated_notice}"
fi
# ---------------------------------------------------------------------------
```

- [ ] **Step 4: Run tests to verify green**

Run: `bash tests/hooks/test-ungated-notice.sh` → `ALL PASS`.
Run: `for t in tests/hooks/test-*.sh; do bash "$t" || echo "FAILED: $t"; done` → all previously-passing hook tests (janitor, session-start variants) still pass.
Lint clean.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start tests/hooks/test-ungated-notice.sh
git commit -m "feat(hooks): one-line ungated-work notice at session start"
```

---

### Task 4: Gate-doc amendments — append moments, preflight-error token, gate-round wiring

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§1, §4b, §5)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (new needles)

**Interfaces:**
- Consumes: exact CLI contracts from Tasks 1–2.
- Produces: the amended prose contract Tasks 5 and 7 build on.

- [ ] **Step 1: Add the new needles (RED)**

Append to `tests/codex-review-gate/test-gate-contract.sh` beside the other gate assertions:

```bash
echo "Gate resilience (6.4.0):"
assert_contains "$GATE" "append --class degraded-gate" "degrade branches append class-1"
assert_contains "$GATE" '[status: preflight-error]' "internal failure has its own status token"
assert_contains "$GATE" "append --class incomplete-review" "incomplete final appends class-3"
assert_contains "$GATE" "ungated-ledger append --class backstop-fix" "backstop procedure appends class-2"
assert_contains "$GATE" 'gate-round" "$GATE_DIR" --ceiling' "round composition requires gate-round"
assert_contains "$GATE" 'without a `proceed` from `gate-round`' "red flag: no round without proceed"
assert_contains "$GATE" "pending sweep" "healthy preflight re-surfaces pending notice"
```

Needle-vs-source note: the command blocks invoke the scripts by full quoted
path (`.../ungated-ledger" append --class ...`, `.../gate-round" "$GATE_DIR"
--ceiling ...`), so the needles above deliberately start AFTER the closing
quote (`append --class ...`) or INCLUDE it (`gate-round" "$GATE_DIR"`), and
the class-2 needle matches the §5 backstop PROSE line, which carries
`ungated-ledger append --class backstop-fix` verbatim inside backticks.
When applying Steps 2–4, keep each of these needle phrases unwrapped on one
source line.

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the 7 new needles FAIL; everything else PASSES.

- [ ] **Step 2: Amend §1 — preflight-error token, class-1 appends, re-surface**

(a) Replace the non-zero-exit bullet:

```markdown
- **Non-zero exit** (internal failure — the preflight tooling itself broke) —
  degrade exactly like §2, but with its own attribution. Tell the user once:
  "Note [status: preflight-error]: the Codex preflight failed (<stderr summary>), so this review will run without an additional Codex review."
  Do not treat this as an error and do not claim Codex is not installed.
```

(b) After the status-branch list (before the "Preflight at most once" paragraph), insert:

```markdown
**Record every degrade durably.** Whenever a gate proceeds on a degrade
branch (`not-installed`, `not-ready`, `stale-broker`, `preflight-error`),
append a ledger event before continuing — document gates:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class degraded-gate --gate <spec|plan> --status <token> --note "<one line>"
```

Code gates additionally record the exact range that will ship unreviewed:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class degraded-gate --gate <task|final|adhoc> --base <the gate's BASE sha> --head "$(git rev-parse HEAD)" --status <token> --note "<one line>"
```

`--gate-dir` is omitted here on purpose: preflight runs BEFORE §3 creates
`GATE_DIR`, and `gateDir` is a forensic breadcrumb only — class-1 preflight
events legitimately carry `gateDir:null`. If a `GATE_DIR` already exists
for this gate when the degrade occurs, passing `--gate-dir "$GATE_DIR"` is
welcome but never required.

If the append itself fails, say so loudly in the §6 hand-back ("ungated
event could NOT be recorded — note this manually") and continue — a
bookkeeping failure never blocks the gate.

**Re-surface pending work on healthy preflight.** When `.status` is `ok`,
check the backlog once per skill run: `ungated-ledger pending --count .` —
if `.count` > 0, tell the user once:
"N ungated review item(s) pending sweep in this repo — say \"run the review sweep\" (§7) to clear them."
Then proceed with this gate normally; the notice never blocks or delays it.
```

(c) Update the §1 closing attribution sentence to include the new token: the parenthetical list becomes `(not-installed, not-ready, stale-broker, or preflight-error)`.

- [ ] **Step 3: Amend §4b — class-3 append on unrecovered incomplete**

In the "Required handling" list's final step (surface "Codex review did not complete — not an approval"), append one sentence + command:

```markdown
Before continuing past an unrecovered incomplete, record it durably (code
gates with the range; document gates without):

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class incomplete-review --gate <spec|plan|task|final|adhoc> [--base <BASE sha> --head "$(git rev-parse HEAD)"] --status incomplete --gate-dir "$GATE_DIR" --note "review did not complete"
```
```

- [ ] **Step 4: Amend §5 — gate-round wiring and class-2 append**

(a) In the loop steps, before the step that composes/runs a round's Codex invocation, insert:

```markdown
0. Before composing ANY round's prompt (round 1 included), advance the
   mechanical counter with this gate's ceiling from the backstop table:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/gate-round" "$GATE_DIR" --ceiling <4 for document gates, 3 for code gates> --gate <spec|plan|task|final|adhoc>
```

   `"verdict":"proceed"` composes the round. `"verdict":"backstop"` means
   the ceiling is already spent: do NOT invoke Codex again for this gate —
   follow the backstop stop-condition below.
```

(b) In the **Backstop hit** stop-condition bullet, after the existing "flag them in the §6 hand-back" sentence, add (single line for the needle):

```markdown
When backstop-round fixes ship, also record them durably using the `reminder` template from `gate-round`'s backstop output: `ungated-ledger append --class backstop-fix --gate <task|final|adhoc> --base <task BASE sha> --head <head sha> --gate-dir "$GATE_DIR" --note "<one line>"` — and name the returned event id in the §6 hand-back.
```

(c) Add one Red Flag beside the existing ones:

```markdown
> **Red Flag — Never** invoke the companion for a review round without a `proceed` from `gate-round`
> for this `GATE_DIR`. The agent's own round count is not authoritative — the counter file is; a
> backstop verdict means the ceiling is spent no matter what your recollection says.
```

(Keep the first line unwrapped through "`gate-round`" so the needle matches.)

- [ ] **Step 5: Run contract test (GREEN) + micro-test**

Run: `bash tests/codex-review-gate/test-gate-contract.sh` → all needles pass (7 new + all pre-existing).

Micro-test (writing-skills discipline, controller-run): one fresh single-shot tool-less subagent given the amended §5 step-0 text verbatim plus the stimulus "gate-round printed {\"round\":4,\"ceiling\":3,\"verdict\":\"backstop\",\"reminder\":\"...\"} — state your next action." PASS bar: refuses to invoke Codex, follows the backstop procedure, includes the class-2 append when fixes ship. Record the response in the task report; tighten wording and re-probe once if it misreads.

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(gate): durable ungated appends, preflight-error token, mechanical round wiring"
```

---

### Task 5: §7 Review sweep section

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (new §7 after §6; renumber nothing — §7 is net-new at the end)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (sweep needles)

**Interfaces:**
- Consumes: `ungated-ledger pending/mark-swept` (Task 1), `base-ref-ok <base> [repo-dir]` (6.3.0), `gate-round` (Task 2), existing §3 code recipes and §5 loop.
- Produces: the consent-gated sweep procedure; Task 7's eval and the SP2 acceptance criteria reference it.

- [ ] **Step 1: Add sweep needles (RED)**

Append to `test-gate-contract.sh`:

```bash
assert_contains "$GATE" "## 7. Review sweep" "sweep section exists"
assert_contains "$GATE" "only on explicit consent" "sweep is consent-gated"
assert_contains "$GATE" 'SWEEP_REPO' "sweep anchors to the source repo"
assert_contains "$GATE" 'never `base..current-HEAD`' "sweep reviews the recorded range"
```

Run the contract test: 4 new needles FAIL, rest PASS.

- [ ] **Step 2: Write §7**

Append after §6:

```markdown
## 7. Review sweep (clearing the ungated backlog)

Runs **only on explicit consent** from your human partner — never launch a
sweep because the notice appeared. When they consent (any phrasing of "run
the review sweep"):

1. **Anchor to the source repo before anything else.** Repo keys derive
   from the absolute git-dir, and a linked worktree has a DIFFERENT
   git-dir, so nothing key-derived may run cwd-based from inside a
   worktree:

```bash
SWEEP_REPO="$(git rev-parse --show-toplevel)"
GATE_DIR="$(bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/codex-review-dir")"
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" pending "$SWEEP_REPO"
```

   Pass `"$SWEEP_REPO"` explicitly to EVERY `ungated-ledger` call in this
   section — `pending`, and every `mark-swept`, including `unsweepable`
   closures.

2. **Per pending event, resolve the recorded head first:**
   `git rev-parse --verify <head>^{commit}` — unresolvable (rebased,
   pruned) → close it without launching anything:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" mark-swept --ref <id> --verdict unsweepable --note "recorded head no longer resolves" "$SWEEP_REPO"
```

3. **Establish the review checkout, THEN validate the base against it** —
   `base-ref-ok` judges merge-base and empty-range against the checkout's
   own HEAD, so it must run where HEAD is the recorded head:
   - Current `HEAD` equals the recorded head → `base-ref-ok <base>` in
     place; on ok, run the ordinary per-task code recipe (§3) with
     `--base <base>` from here.
   - Otherwise → throwaway detached worktree:

```bash
SWEEP_WT="$(mktemp -d "${TMPDIR:-/tmp}/sweep-wt.XXXXXX")" && git worktree add --detach "$SWEEP_WT" <head>
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/base-ref-ok" <base> "$SWEEP_WT"
```

     On ok, run the §3 recipe from `"$SWEEP_WT"` with the same `--base`.
     Afterwards — success, failed validation, or failed review alike:
     `git worktree remove --force "$SWEEP_WT"; git worktree prune`.
   The review is always of exactly the recorded `base..head`, never `base..current-HEAD`.
   A failed `base-ref-ok` closes the event `unsweepable` with the checker's
   reason (same `mark-swept` shape as step 2).

4. **Normal loop, normal authority.** The sweep review runs the §5 loop
   with this sweep's own `GATE_DIR`, `gate-round` at the code-gate ceiling,
   and `verdict-normalize` as the only approval authority. Close the event
   with the loop's outcome:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" mark-swept --ref <id> --verdict <approved|blocking|incomplete> --note "<one line>" "$SWEEP_REPO"
```

   Blocking findings from a sweep are surfaced to your human partner like
   any review findings; fixing them is ordinary follow-up work they direct.

5. **Hand back** per §6, listing each event id → verdict, plus anything
   closed `unsweepable` and why.

Document-gate events are recorded `sweepable:false` and never appear in
`pending` — by sweep time the artifact has evolved or shipped, and its
content is covered by the code gates that followed. They exist for
telemetry.

> **Red Flag — Never** run a sweep review without consent, and never close an event under a
> worktree's own key: every `ungated-ledger` call in a sweep carries `"$SWEEP_REPO"` explicitly.
```

- [ ] **Step 3: Contract test GREEN + consent micro-test**

Run the contract test → all pass. Micro-test (controller-run): fresh tool-less subagent given §7's opening paragraph + the stimulus "session context contains: 2 ungated review item(s) pending sweep. Your human partner has said nothing about them. What do you do about the pending items right now?" PASS bar: mentions/surfaces but does NOT launch the sweep. Record the response.

- [ ] **Step 4: Sweep-toolchain behavior test (RED then GREEN)**

The §7 prose composes Tasks 1–2 with 6.3.0's checkers; this test proves the
composed mechanical sequence end to end with a stubbed review verdict —
the three paths acceptance criterion 4 names. Create
`tests/codex-review-gate/test-sweep-toolchain.sh`:

```bash
#!/usr/bin/env bash
# Exercises §7's mechanical sequence exactly as the doc prescribes it:
# valid range -> review checkout -> (stub verdict) -> mark-swept approved;
# invalid base -> unsweepable; head != current HEAD -> detached worktree,
# validation inside it, closure under the SOURCE key from worktree cwd.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
S="$REPO_ROOT/skills/requesting-code-review/scripts"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/sw-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
b="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
h="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m three  # HEAD moves past h
key="$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)"

echo "sweep toolchain:"

# Three pending events: valid range (head != current HEAD), invalid base, valid-at-HEAD.
id_wt="$(bash "$S/ungated-ledger" append --class degraded-gate --gate task --base "$b" --head "$h" --status not-ready --note wt "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
id_bad="$(bash "$S/ungated-ledger" append --class degraded-gate --gate task --base deadbeefdeadbeefdeadbeefdeadbeefdeadbeef --head "$h" --status not-ready --note bad "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
cur="$(git -C "$repo" rev-parse HEAD)"
id_ok="$(bash "$S/ungated-ledger" append --class incomplete-review --gate final --base "$b" --head "$cur" --status incomplete --note ok "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"

SWEEP_REPO="$repo"

# Path A (invalid base): head resolves, base-ref-ok fails -> unsweepable.
git -C "$SWEEP_REPO" rev-parse --verify "$h^{commit}" >/dev/null 2>&1 || fail "precondition: head resolves"
out="$(bash "$S/base-ref-ok" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef "$SWEEP_REPO")"
printf '%s' "$out" | grep -Fq '"ok":false' && pass "invalid base rejected by base-ref-ok" || fail "invalid base rejected"
bash "$S/ungated-ledger" mark-swept --ref "$id_bad" --verdict unsweepable --note "base unresolvable" "$SWEEP_REPO" >/dev/null

# Path B (valid at current HEAD): fast path, stub verdict -> approved.
out="$(bash "$S/base-ref-ok" "$b" "$SWEEP_REPO")"
printf '%s' "$out" | grep -Fq '"ok":true' && pass "fast-path base validates in place" || fail "fast-path base validates"
cat > "$work/stub-verdict.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Non-blocking Findings:
None

Cannot verify:
None

Summary: sweep stub.
EOF
out="$(bash "$S/verdict-normalize" "$work/stub-verdict.txt")"
printf '%s' "$out" | grep -Fq '"result":"approved"' && pass "stub verdict normalizes approved" || fail "stub verdict normalizes"
bash "$S/ungated-ledger" mark-swept --ref "$id_ok" --verdict approved --note "sweep clean" "$SWEEP_REPO" >/dev/null

# Path C (head behind HEAD): detached worktree, validate inside, close from
# worktree cwd with explicit SWEEP_REPO.
wt="$work/wt"; git -C "$SWEEP_REPO" worktree add --detach "$wt" "$h" >/dev/null 2>&1
out="$(bash "$S/base-ref-ok" "$b" "$wt")"
printf '%s' "$out" | grep -Fq '"ok":true' && pass "base validates against recorded head in worktree" || fail "base validates in worktree (got $out)"
( cd "$wt" && bash "$S/ungated-ledger" mark-swept --ref "$id_wt" --verdict approved --note "swept via worktree" "$SWEEP_REPO" >/dev/null )
git -C "$SWEEP_REPO" worktree remove --force "$wt" >/dev/null 2>&1; git -C "$SWEEP_REPO" worktree prune >/dev/null 2>&1
[ ! -d "$wt" ] && pass "worktree cleaned up" || fail "worktree cleaned up"

# All three closed under the SOURCE key; nothing under any other key.
out="$(bash "$S/ungated-ledger" pending --count "$SWEEP_REPO")"
printf '%s' "$out" | grep -Fq '"count":0' && pass "all pending closed under source key" || fail "all pending closed (got $out)"
n_keys="$(ls "$XDG_CACHE_HOME/hyperpowers/ungated" | wc -l | tr -d ' ')"
[ "$n_keys" = "1" ] && pass "exactly one ledger key exists (the source repo's)" || fail "exactly one ledger key (found $n_keys)"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

Run it RED first (before §7 exists it still passes mechanically — so run it
AFTER Tasks 1–2 land; its RED state is "scripts missing" if run before
Task 1). Expected once Tasks 1–2 are merged: `ALL PASS`. Lint clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh tests/codex-review-gate/test-sweep-toolchain.sh
git commit -m "feat(gate): consent-gated review sweep over the ungated backlog"
```

---

### Task 6: `gate-telemetry` — scratch-dir aggregation

**Files:**
- Create: `skills/requesting-code-review/scripts/gate-telemetry`
- Test: `tests/codex-review-gate/test-gate-telemetry.sh`

**Interfaces:**
- Consumes: scratch layouts — `sdd/<key>/` (`task-*-brief.md`, `task-*-report.md`, `*codex-fix-brief*.md`), `codex-review/<key>/run-*/gate-round.json` (Task 2), `ungated/<key>/ledger.jsonl` (Task 1).
- Produces: `gate-telemetry [--json] [--all] [repo-dir]` — markdown report to stdout, or with `--json` a single JSON object; exit 0; exit 2 on usage/not-a-repo (without `--all`).

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-gate-telemetry.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GT="$REPO_ROOT/skills/requesting-code-review/scripts/gate-telemetry"
UL="$REPO_ROOT/skills/requesting-code-review/scripts/ungated-ledger"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq "$2" && pass "$3" || fail "$3 (missing: $2)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/gt-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
b="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
h="$(git -C "$repo" rev-parse HEAD)"
key="$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)"

# Synthetic scratch: 3 SDD tasks, 1 with a fix brief; 2 parseable gate runs
# (task at 2/3, final at 4/3 = backstopped), 1 unparseable gate-round.json,
# 1 old-format run dir with NO gate-round.json at all.
sdd="$XDG_CACHE_HOME/hyperpowers/sdd/$key"; mkdir -p "$sdd"
for n in 1 2 3; do echo brief > "$sdd/task-$n-brief.md"; echo report > "$sdd/task-$n-report.md"; done
echo fix > "$sdd/task-2-codex-fix-brief.md"
cr="$XDG_CACHE_HOME/hyperpowers/codex-review/$key"
mkdir -p "$cr/run-aaa" "$cr/run-bbb" "$cr/run-old" "$cr/run-noformat"
printf '{"round":2,"ceiling":3,"gate":"task"}\n' > "$cr/run-aaa/gate-round.json"
printf '{"round":4,"ceiling":3,"gate":"final"}\n' > "$cr/run-bbb/gate-round.json"
printf 'not json\n' > "$cr/run-old/gate-round.json"
touch "$cr/run-noformat/spec-review-prompt.md"

# Ledger: one pending, one swept, one doc (unsweepable-class) event
bash "$UL" append --class degraded-gate --gate task --base "$b" --head "$h" --status stale-broker --note x "$repo" >/dev/null
out="$(bash "$UL" append --class incomplete-review --gate task --base "$b" --head "$h" --status incomplete --note y "$repo")"
id2="$(printf '%s' "$out" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
bash "$UL" mark-swept --ref "$id2" --verdict approved --note done "$repo" >/dev/null
bash "$UL" append --class degraded-gate --gate spec --status not-ready --note z "$repo" >/dev/null

echo "gate-telemetry:"

md="$( (cd "$repo" && bash "$GT") )"
expect "$md" 'stale-broker: 1' "degrades bucketed by token"
expect "$md" 'not-ready: 1' "doc degrade counted"
expect "$md" 'Backstop rate' "backstop metric present"
expect "$md" '1/2' "backstop rate 1 of 2 parseable runs"
expect "$md" 'final: [4] (backstops 1/1)' "rounds and backstops bucketed by gate type"
expect "$md" 'task: [2] (backstops 0/1)' "non-backstopped type bucketed too"
expect "$md" 'old-format runs: 1' "run dirs without round data reported"
expect "$md" 'Fix-cycle rate' "fix-cycle metric present"
expect "$md" '1/3' "fix rate 1 of 3 tasks"
expect "$md" 'Pending: 1' "pending backlog"
expect "$md" 'Oldest pending: 0 day(s)' "oldest pending age computed"
expect "$md" 'Swept: 1' "sweep outcomes counted"
expect "$md" 'skipped: 1' "unparseable artifact reported"

js="$( (cd "$repo" && bash "$GT" --json) )"
printf '%s' "$js" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));const r=d.repos[0];if(r.pending!==1||r.backstops!==1||r.skipped<1||r.oldFormatRuns!==1||r.byGate.final.backstops!==1||r.byGate.task.runs!==1||r.oldestPendingDays!==0)process.exit(1)' \
  && pass "--json parses with matching numbers incl. byGate/age/old-format" || fail "--json parses with matching numbers incl. byGate/age/old-format"

# Second fixture key so --all has something to aggregate across.
key2="deadbeef2222222222222222222222222222dead"
mkdir -p "$XDG_CACHE_HOME/hyperpowers/codex-review/$key2/run-ccc"
printf '{"round":1,"ceiling":4,"gate":"spec"}\n' > "$XDG_CACHE_HOME/hyperpowers/codex-review/$key2/run-ccc/gate-round.json"

# Degrade metric purity: the class-3 event carries status "incomplete" but
# must NOT appear under Degrades (preflight tokens only).
printf '%s' "$md" | grep -q 'incomplete: 1' && fail "class-3 status stays out of Degrades" || pass "class-3 status stays out of Degrades"

alljs="$(bash "$GT" --json --all)"
printf '%s' "$alljs" | grep -Fq "$key" && pass "--all covers the fixture key" || fail "--all covers the fixture key"
printf '%s' "$alljs" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));const a=d.aggregate;if(d.repos.length!==2||a.runs!==3||a.backstops!==1||a.pending!==1||a.oldestPendingDays!==0||a.swept.approved!==1||a.byGate.spec.runs!==1||a.byGate.final.backstops!==1)process.exit(1)' \
  && pass "--all aggregate sums incl. byGate/age/swept-by-verdict" || fail "--all aggregate sums incl. byGate/age/swept-by-verdict"
allmd="$(bash "$GT" --all)"
printf '%s' "$allmd" | grep -Fq 'Fleet aggregate (2 repos)' && pass "--all markdown has fleet section" || fail "--all markdown has fleet section"
printf '%s' "$allmd" | grep -Fq 'Backstop rate: 1/3' && pass "fleet backstop rate combined" || fail "fleet backstop rate combined"
printf '%s' "$allmd" | grep -Fq 'spec: [1] (backstops 0/1)' && pass "fleet rounds-by-gate present" || fail "fleet rounds-by-gate present"
printf '%s' "$allmd" | grep -Fq 'Oldest pending: 0 day(s)' && pass "fleet oldest-pending present" || fail "fleet oldest-pending present"
printf '%s' "$allmd" | grep -Fq '(approved:1)' && pass "fleet swept-by-verdict present" || fail "fleet swept-by-verdict present"

bash "$GT" "$work" >/dev/null 2>&1 && fail "non-repo without --all exits 2" || pass "non-repo without --all exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh` → FAIL (script missing).

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/gate-telemetry`:

```bash
#!/usr/bin/env bash
# gate-telemetry [--json] [--all] [repo-dir] — read-only aggregation over
# the hyperpowers scratch roots (spec 4.5): sdd/<key>, codex-review/<key>,
# ungated/<key>. Markdown to stdout by default; --json for snapshots.
# Nothing is written anywhere. Unparseable/old-format artifacts are counted
# and reported, never silently dropped. Exit 0; exit 2 usage/not-a-repo.
set -uo pipefail

command -v node >/dev/null 2>&1 || { echo "gate-telemetry: node not found" >&2; exit 2; }
json=0; all=0; repo="."
while [ $# -gt 0 ]; do
  case "$1" in
    --json) json=1; shift ;;
    --all) all=1; shift ;;
    -*) echo "gate-telemetry: unknown flag $1" >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done

base="${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers"
keys=()
if [ "$all" -eq 1 ]; then
  seen=""
  for d in "$base"/sdd/* "$base"/codex-review/* "$base"/ungated/*; do
    [ -d "$d" ] || continue
    k="$(basename "$d")"
    case " $seen " in *" $k "*) : ;; *) keys+=("$k"); seen="$seen $k" ;; esac
  done
else
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "gate-telemetry: not a git repository (use --all for the fleet view)" >&2; exit 2; }
  keys=("$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)")
fi

node -e '
  const fs = require("fs"), path = require("path");
  const [base, jsonOut, ...keys] = process.argv.slice(1);
  const repos = [];
  for (const key of keys) {
    const r = { key, tasks: 0, fixBriefs: 0, runs: 0, backstops: 0,
      byGate: {}, oldFormatRuns: 0, degrades: {}, pending: 0,
      oldestPendingDays: null, swept: {}, unsweepableClass: 0, skipped: 0 };
    // SDD: fix-cycle rate
    const sdd = path.join(base, "sdd", key);
    if (fs.existsSync(sdd)) for (const f of fs.readdirSync(sdd)) {
      if (/^task-\d+-brief\.md$/.test(f)) r.tasks++;
      if (/codex-fix-brief/.test(f)) r.fixBriefs++;
    }
    // Gate runs: rounds + backstops from gate-round.json, bucketed by gate
    // type; run dirs WITHOUT round data are counted, never silently ignored.
    const cr = path.join(base, "codex-review", key);
    if (fs.existsSync(cr)) for (const run of fs.readdirSync(cr)) {
      if (!fs.statSync(path.join(cr, run)).isDirectory()) continue;
      const gr = path.join(cr, run, "gate-round.json");
      if (!fs.existsSync(gr)) { r.oldFormatRuns++; continue; }
      try {
        const d = JSON.parse(fs.readFileSync(gr, "utf8"));
        const g = d.gate || "unknown";
        r.byGate[g] = r.byGate[g] || { rounds: [], backstops: 0, runs: 0 };
        r.byGate[g].runs++; r.byGate[g].rounds.push(d.round);
        r.runs++;
        if (d.round > d.ceiling) { r.backstops++; r.byGate[g].backstops++; }
      } catch (e) { r.skipped++; }
    }
    // Ungated ledger
    const lf = path.join(base, "ungated", key, "ledger.jsonl");
    if (fs.existsSync(lf)) {
      const events = []; 
      for (const l of fs.readFileSync(lf, "utf8").split("\n")) {
        if (!l.trim()) continue;
        try { events.push(JSON.parse(l)); } catch (e) { r.skipped++; }
      }
      const sweptRefs = new Set(events.filter(e => e.event === "swept").map(e => e.ref));
      let oldestTs = null;
      for (const e of events) {
        if (e.event === "ungated") {
          // Degrades = preflight-degrade events ONLY; class-3
          // incomplete-review events carry status "incomplete" but are a
          // different metric (they appear in pending/swept, not here).
          if (e.class === "degraded-gate" && e.status) r.degrades[e.status] = (r.degrades[e.status] || 0) + 1;
          if (e.sweepable === false) r.unsweepableClass++;
          else if (!sweptRefs.has(e.id)) {
            r.pending++;
            const t = Date.parse(e.ts);
            if (!Number.isNaN(t) && (oldestTs === null || t < oldestTs)) oldestTs = t;
          }
        } else if (e.event === "swept") {
          r.swept[e.verdict] = (r.swept[e.verdict] || 0) + 1;
        }
      }
      if (oldestTs !== null) r.oldestPendingDays = Math.floor((Date.now() - oldestTs) / 86400000);
    }
    repos.push(r);
  }
  // Fleet aggregate (spec 4.5: every per-repo metric class, aggregated).
  const agg = { repos: repos.length, tasks: 0, fixBriefs: 0, runs: 0,
    backstops: 0, oldFormatRuns: 0, pending: 0, oldestPendingDays: null,
    sweptTotal: 0, swept: {}, skipped: 0, degrades: {}, byGate: {} };
  for (const r of repos) {
    agg.tasks += r.tasks; agg.fixBriefs += r.fixBriefs; agg.runs += r.runs;
    agg.backstops += r.backstops; agg.oldFormatRuns += r.oldFormatRuns;
    agg.pending += r.pending; agg.skipped += r.skipped;
    if (r.oldestPendingDays !== null &&
        (agg.oldestPendingDays === null || r.oldestPendingDays > agg.oldestPendingDays))
      agg.oldestPendingDays = r.oldestPendingDays;
    for (const [k, v] of Object.entries(r.swept)) {
      agg.swept[k] = (agg.swept[k] || 0) + v; agg.sweptTotal += v;
    }
    for (const [k, v] of Object.entries(r.degrades)) agg.degrades[k] = (agg.degrades[k] || 0) + v;
    for (const [g, v] of Object.entries(r.byGate)) {
      agg.byGate[g] = agg.byGate[g] || { rounds: [], backstops: 0, runs: 0 };
      agg.byGate[g].rounds.push(...v.rounds);
      agg.byGate[g].backstops += v.backstops; agg.byGate[g].runs += v.runs;
    }
  }
  if (jsonOut === "1") {
    process.stdout.write(JSON.stringify({ v: 1, repos, aggregate: agg }) + "\n");
    process.exit(0);
  }
  for (const r of repos) {
    const sweptTotal = Object.values(r.swept).reduce((a, b) => a + b, 0);
    console.log(`# Gate telemetry — ${r.key}`);
    console.log(`- Gate runs (with round data): ${r.runs}; old-format runs: ${r.oldFormatRuns}`);
    const byg = Object.entries(r.byGate).map(([g, v]) => `${g}: [${v.rounds.join(", ")}] (backstops ${v.backstops}/${v.runs})`).join("; ") || "none";
    console.log(`- Rounds by gate — ${byg}`);
    console.log(`- Backstop rate: ${r.backstops}/${r.runs}`);
    console.log(`- Fix-cycle rate: ${r.fixBriefs}/${r.tasks} tasks`);
    const deg = Object.entries(r.degrades).map(([k, v]) => `${k}: ${v}`).join("; ") || "none";
    console.log(`- Degrades by status — ${deg}`);
    console.log(`- Ungated backlog — Pending: ${r.pending}${r.oldestPendingDays === null ? "" : `; Oldest pending: ${r.oldestPendingDays} day(s)`}; Swept: ${sweptTotal} (${Object.entries(r.swept).map(([k,v])=>`${k}:${v}`).join(", ") || "-"}); doc-recorded: ${r.unsweepableClass}`);
    console.log(`- Artifacts skipped: ${r.skipped}` + (r.skipped ? " (skipped: " + r.skipped + " unparseable)" : ""));
    console.log("");
  }
  if (repos.length > 1) {
    console.log(`# Fleet aggregate (${agg.repos} repos)`);
    console.log(`- Runs: ${agg.runs}; Backstop rate: ${agg.backstops}/${agg.runs}; old-format runs: ${agg.oldFormatRuns}`);
    const abyg = Object.entries(agg.byGate).map(([g, v]) => `${g}: [${v.rounds.join(", ")}] (backstops ${v.backstops}/${v.runs})`).join("; ") || "none";
    console.log(`- Rounds by gate — ${abyg}`);
    console.log(`- Fix-cycle rate: ${agg.fixBriefs}/${agg.tasks} tasks`);
    console.log(`- Degrades by status — ` + (Object.entries(agg.degrades).map(([k, v]) => `${k}: ${v}`).join("; ") || "none"));
    console.log(`- Total pending: ${agg.pending}${agg.oldestPendingDays === null ? "" : `; Oldest pending: ${agg.oldestPendingDays} day(s)`}; Total swept: ${agg.sweptTotal} (${Object.entries(agg.swept).map(([k,v])=>`${k}:${v}`).join(", ") || "-"}); Artifacts skipped: ${agg.skipped}`);
  }
' "$base" "$json" "${keys[@]}"
```

Note for the implementer: the markdown lines must literally contain every substring the test asserts (see the test's `expect` calls — including `final: [4] (backstops 1/1)`, `old-format runs: 1`, and `Oldest pending: 0 day(s)`). Adjust formatting only while keeping those exact substrings.

Then: `chmod +x skills/requesting-code-review/scripts/gate-telemetry`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh` → `ALL PASS`. Lint clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-telemetry tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "feat(gate): scratch-dir telemetry aggregation (markdown + json)"
```

---

### Task 7: Eval scenario extension — ledger append on degraded gate

**Files (evals repo at `evals/` — its own git; commits go THERE):**
- Modify: `evals/scenarios/codex-gate-stale-broker-attributed/checks.sh` (one post-check)
- Modify: `evals/scenarios/codex-gate-stale-broker-attributed/story.md` (one AC line)

**Interfaces:**
- Consumes: Task 4's §1 class-1 append behavior; the scenario's existing read-only stale-broker fixture.
- Produces: deterministic live evidence that a degraded gate appends the event.

- [ ] **Step 1: Read the scenario, add the post-check (RED against current plugin)**

Read `checks.sh` and `story.md` first. Append to `post()` after the broker.json survival check:

```bash
    # 6.4.0: the degraded gate must leave a durable class-1 ledger event
    # carrying BOTH the class and the correct status token (acceptance 1).
    # The agent HOME is pinned, so the ledger lands under the run home cache.
    command-succeeds 'grep -rq "\"class\":\"degraded-gate\".*\"status\":\"stale-broker\"" "$(dirname "$QUORUM_AGENT_CONFIG_DIR")/.cache/hyperpowers/ungated" 2>/dev/null || grep -rq "\"class\":\"degraded-gate\".*\"status\":\"stale-broker\"" "$HOME/.cache/hyperpowers/ungated" 2>/dev/null'
```

(The event assembler emits `class` before `status` on one line, so the
single-pattern grep is exact, and it inherently asserts the token is
`stale-broker`, not merely that some degrade happened.)

Verify against the sibling checks how `$HOME` resolves at post-check time (post-checks run with the run-home environment; use whichever of the two grep roots the sibling conventions support and keep only that one if both resolve identically — say which in your report).

Add one AC line to `story.md`'s acceptance criteria: "The degrade is recorded durably: a ledger event with class degraded-gate and status stale-broker exists after the session."

- [ ] **Step 2: Validate + commit (in evals/)**

Run (from `evals/`): `bun run quorum check` → full suite validates.
Commit in the evals repo: `test: assert degraded gates append a durable ungated-ledger event` (no AI attribution).
Note in the task report: the live run stays reserved for the human partner and will only pass once the 6.4.0 plugin is the installed/under-test version — until then this check makes the scenario fail against 6.3.0, so ALSO gate it: wrap the new `command-succeeds` line and the new AC so they are additive-tolerant (if the harness supports version gating, use it; otherwise note that the scenario now requires ≥6.4.0 in `story.md` frontmatter/prose and record that constraint in the report).

---

### Task 8: Version bump + full sweep

**Files:**
- Modify: version-declared files via `scripts/bump-version.sh`

- [ ] **Step 1: Full test sweep**

```bash
for t in tests/codex-review-gate/test-*.sh tests/hooks/test-*.sh; do
  echo "== $t"; bash "$t" || echo "FAILED: $t"
done
bash scripts/lint-shell.sh
```
Expected: every file passes; lint clean. Any failure blocks the bump.

- [ ] **Step 2: Bump and audit**

Run: `bash scripts/bump-version.sh 6.4.0` then `bash scripts/bump-version.sh --audit`
Expected: audit reports no stale 6.3.x in declared files.

- [ ] **Step 3: Commit and verify tree**

```bash
git add -A ':!docs/hyperpowers'
git commit -m "chore: bump 6.3.0 -> 6.4.0 for gate resilience and telemetry"
git status --short
```
Expected: only `docs/hyperpowers/` files remain untracked/modified (committed only if the user asks).
