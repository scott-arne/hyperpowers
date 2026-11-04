# Cost Reduction 6.16.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md`

**Goal:** Ship hyperpowers 6.16.2 from tag `v6.16.1` with a re-read-after-compaction paragraph in SDD and brainstorming, a `gate-wait` script that watches every Codex job of a gate in one call, and a README section on cost settings, each backed by tests or eval evidence.

**Architecture:** Three independent changes on a branch cut from `v6.16.1`. The skill paragraphs and the README are text. `gate-wait` is a bash helper beside the other gate scripts, and the gate docs switch their watch step to it under the split-proof edit table. A new evals scenario plus a paired control/treatment campaign measures the skill change; the campaign tooling copies the companion campaign's launcher and tally.

**Tech Stack:** bash, node (JSON parsing in scripts, fake companion in tests), Markdown skills, the hyperpowers-evals quorum harness (bun), Python 3 for the campaign tally.

## Global Constraints

- All work on a branch from `v6.16.1` in its own worktree; nothing from `main` is cherry-picked in. Create it with `git -C /Users/johnss51/Development/agents/hyperpowers worktree add -b cost-6-16-2 .worktrees/cost-6-16-2 v6.16.1`; every hyperpowers path below is relative to that worktree.
- Skill text changes follow `hyperpowers:writing-skills` and carry before/after eval evidence from multiple sessions. Existing lines in the two skills stay as they are; the change adds one paragraph per skill.
- Gate doc edits are recorded in `tests/codex-review-gate/gate-post-split-edits.tsv` and pass `test-assemble-gate.sh` and `test-gate-contract.sh`.
- New shell passes `scripts/lint-shell.sh`.
- Eval run artifacts cited by the evidence note go to `evals/evidence/2026-11-03-cost-reduction-6-16-2/` in the evals repository (`/Users/johnss51/Development/agents/hyperpowers/evals`, committed there, never in hyperpowers).
- The README states savings as percentages, never the human partner's dollar figures. Every commit's staged diff passes `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` with `hits: 0`.
- No push, no merge into `main` without the human partner's go-ahead.
- Commit messages carry no AI attribution and no `Co-Authored-By` line.
- Companion commands (`codex-companion.mjs`, and `gate-wait` when it talks to a real companion) run outside the shell sandbox; tests use a fake companion and run sandboxed.

## Grounding

- Bash helper shape: `skills/requesting-code-review/scripts/gate-round:1-39` (header comment with stdout shape and exit codes, `set -uo pipefail`, `while`/`case` flag loop with `[ $# -ge 2 ]` value guards, `<name>: <message>` on stderr).
- JSON from bash via node: `skills/requesting-code-review/scripts/verdict-normalize:23-28` (`command -v node` check, `node -e '...'`).
- Fake companion in a test: `tests/codex-review-gate/test-codex-available.sh:34-53` (`make_fake_companion` writes `scripts/codex-companion.mjs` from a quoted heredoc and reads env vars).
- Small test boilerplate: `tests/codex-review-gate/test-base-ref-ok.sh:2-15` (`SCRIPT_DIR`/`REPO_ROOT`, `pass`/`fail`/`expect`, `mktemp -d` plus `trap`) and `:36-37` (ending).
- Skill-text assertions: `tests/sdd/test-sdd-contract.sh:1-30` (paths to skill files, `assert_contains` with whitespace normalization).
- Split-proof edit table: `tests/codex-review-gate/gate-post-split-edits.tsv:1-11` (format `srcline<TAB>reason<TAB>replacement`, one line in and one out, no tabs or backslashes); pinned row count `tests/codex-review-gate/test-gate-split-lossless.sh:355-360`; original file `cdd8719:skills/requesting-code-review/codex-review-gate.md` (`test-gate-split-lossless.sh:36-38`); section offsets from `gate-split-manifest.tsv` (`recipe-code.md` starts at original line 274, `gate-findings.md` at 394, `gate-lenses.md` at 177, so original line = file line + start - 1).
- Gate contract assertions: `tests/codex-review-gate/test-gate-contract.sh:24-38` (`assert_contains`) and `:129-130` (the "4 consecutive wait cycles" assertion).
- Shell lint: `scripts/lint-shell.sh:5-6` (`scripts/lint-shell.sh [file ...]`).
- Offline suite set: `docs/testing.md:45-57` (loop form and the offline set definition).
- Changelog entry: `CHANGELOG.md:5-10` (`## 6.16.1 (2026-10-19)`, one summary sentence, `- **Bold lead-in.** ...` bullets).
- README placement: `README.md:160-178` (`## The Basic Workflow` then `## What's Inside`).
- Evidence note: `docs/hyperpowers/2026-10-03-communication-skill-eval-evidence.md` (headings: Scenarios, RED control arm, GREEN treatment arm, REFACTOR, Not measured).
- Eval scenario layout (evals repo): `scenarios/sdd-unified-fix-loop/setup.sh:15-16` (`setup-helpers run create_base_repo`, feature branch, committed plan with `**Spec:**` header), `scenarios/sdd-unified-fix-loop/checks.sh:21-71` (`pre`/`post`, `check-transcript` verbs), `scenarios/brainstorming-bounded-companion-after-compaction/setup.sh:297-302` (fixture `.claude/settings.json` with `autoCompactWindow: 100000`), `docs/scenario-authoring.md:423-440` (transcript verb table).
- Campaign tooling (evals repo): `evidence/2026-10-02-companion-default-window/launch-all.sh:1-40` (manifest-driven launcher, bare `wait`, PID-reuse note), `evidence/2026-10-02-companion-default-window/logs/measure-launch.sh:47-74` (model pin check, `SUPERPOWERS_ROOT`, `env -u ... bun run quorum run`), `evidence/2026-10-02-companion-default-window/tally.py:125-175` (`transcript_facts` over `home/.claude/projects/*/*.jsonl`, `compact_boundary` detection), `evidence/2026-10-03-release-6150-paired-control/logs/launch-commands.txt:11-18` (control worktree at a tag, per-arm `SUPERPOWERS_ROOT`).
- Evidence copying: `evidence/README.md` (evals repo; `scripts/strip-runs`, `.git` renamed to `git-dir`, `git add -f`).
- Sentinel and void rules: `docs/scenario-authoring.md:642-700` and `:893-915` (evals repo).
- none: no existing compaction-aware check verb in quorum; compaction timing is computed by the campaign tally, as in the companion campaign.

---

### Task 1: `gate-wait` script and tests

**Risk tier:** standard — new script whose output tells the agent when Codex jobs are done; the verdict authority stays with `verdict-normalize`.

**Files:**
- Create: `skills/requesting-code-review/scripts/gate-wait`
- Create: `tests/codex-review-gate/test-gate-wait.sh`
- Also commit: `docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md` and `docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md`, copied from `/Users/johnss51/Development/agents/hyperpowers/docs/hyperpowers/` (the main checkout, where they were written)

**Interfaces:**
- Produces: `gate-wait [--budget SECONDS] JOB_ID...`; env `CODEX_PATH` required; stdout one `<id> <status>` line per job then `all-terminal` (exit 0) or `running: <id> ...` (exit 2); on exit 1 for unreadable jobs, a `running:` line when any still run, then `unreadable: <id> ...` (stderr `gate-wait: <id>: <cause>`); usage errors exit 1 with a stderr message only. Task 2 names it in the gate docs.

**Mirror:** `skills/requesting-code-review/scripts/gate-round:1-39` for the header and flag loop; `tests/codex-review-gate/test-codex-available.sh:34-53` for the fake companion.

- [ ] **Step 1: Commit the spec and plan on the branch**

```bash
cd /Users/johnss51/Development/agents/hyperpowers/.worktrees/cost-6-16-2
mkdir -p docs/hyperpowers/specs docs/hyperpowers/plans
cp ../../docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md docs/hyperpowers/specs/
cp ../../docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md docs/hyperpowers/plans/
git add docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md docs/hyperpowers/plans/2026-11-03-cost-reduction-6-16-2.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(hyperpowers): spec and plan for the 6.16.2 cost release"
```

Expected: the scan prints `hits: 0`.

- [ ] **Step 2: Write the failing test**

Create `tests/codex-review-gate/test-gate-wait.sh`:

```bash
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
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-wait.sh`
Expected: FAIL lines (the script does not exist yet; `bash` reports no such file) and a final `N FAILURES`, exit 1.

- [ ] **Step 4: Write the script**

Create `skills/requesting-code-review/scripts/gate-wait` and `chmod +x` it:

```bash
#!/usr/bin/env bash
# gate-wait [--budget SECONDS] JOB_ID...
# Watch one or more codex-plugin-cc companion jobs in a single shell call.
# Each pass re-reads every pending job without blocking, then blocks on the
# first job still pending for at most 30 s, so a stalled job cannot hide
# others that finished. Every exit follows a full pass, so every status
# printed is current. Requires CODEX_PATH (the install the recipes use).
# Stdout: one "<id> <status>" line per job, then "all-terminal" or
# "running: <id> ...". Exit 0 = every job terminal; 2 = budget spent with jobs
# still running; 1 = usage error, or a job whose status could not be read
# (stderr "gate-wait: <id>: <cause>"; the other jobs are still listed, then a
# "running:" line if any still run, then "unreadable: <id> ...").
# SECONDS is an integer from 1 to 570 (default 480: one call fits the
# 600000 ms shell timeout, two match the 16-minute watch cap). Like every
# companion command, run it outside the shell sandbox.
set -uo pipefail

budget=480
ids=()
while [ $# -gt 0 ]; do
  case "$1" in
    --budget) [ $# -ge 2 ] || { echo "gate-wait: --budget needs a value" >&2; exit 1; }; budget="$2"; shift 2 ;;
    --) shift; ids+=("$@"); break ;;
    -*) echo "gate-wait: unknown arg $1" >&2; exit 1 ;;
    *) ids+=("$1"); shift ;;
  esac
done

raw_budget="$budget"
case "$budget" in
  ''|*[!0-9]*) echo "gate-wait: --budget must be an integer from 1 to 570 (got '$raw_budget')" >&2; exit 1 ;;
esac
# Strip leading zeros so "008" reads as decimal 8 (bash arithmetic would take
# it as octal and fail) and "0570" as 570. Length next: an overlong number
# would make the integer tests error out (status 2), which reads as false and
# would accept it.
budget="${budget#"${budget%%[!0]*}"}"
if [ -z "$budget" ] || [ "${#budget}" -gt 3 ] || [ "$budget" -lt 1 ] || [ "$budget" -gt 570 ]; then
  echo "gate-wait: --budget must be an integer from 1 to 570 (got '$raw_budget')" >&2; exit 1
fi
[ "${#ids[@]}" -gt 0 ] || { echo "usage: gate-wait [--budget SECONDS] JOB_ID..." >&2; exit 1; }
[ -n "${CODEX_PATH:-}" ] || { echo "gate-wait: CODEX_PATH is not set" >&2; exit 1; }
companion="$CODEX_PATH/scripts/codex-companion.mjs"
[ -f "$companion" ] || { echo "gate-wait: no companion at $companion" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "gate-wait: node not found" >&2; exit 1; }

job_status() {
  node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const s=JSON.parse(d).job.status;if(typeof s==="string"&&s)process.stdout.write(s)}catch(e){}})'
}

n=${#ids[@]}
st=(); pend=()
for ((i = 0; i < n; i++)); do st[i]="unknown"; pend[i]=1; done
err=0

# query INDEX [WAIT_SECONDS]: refresh one job's status; non-zero when unreadable.
query() {
  local i="$1" w="${2:-}" out rc s
  if [ -n "$w" ]; then
    out="$(node "$companion" status "${ids[i]}" --wait --timeout-ms "$((w * 1000))" --json)"; rc=$?
  else
    out="$(node "$companion" status "${ids[i]}" --json)"; rc=$?
  fi
  if [ "$rc" -ne 0 ]; then echo "gate-wait: ${ids[i]}: companion exited $rc" >&2; return 1; fi
  s="$(printf '%s' "$out" | job_status)"
  if [ -z "$s" ]; then echo "gate-wait: ${ids[i]}: no .job.status in companion output" >&2; return 1; fi
  st[i]="$s"
  case "$s" in completed|failed|cancelled) pend[i]=0 ;; esac
  return 0
}

deadline=$(( $(date +%s) + budget ))
while :; do
  for ((i = 0; i < n; i++)); do
    [ "${pend[i]}" -eq 1 ] || continue
    query "$i" || { pend[i]=0; st[i]="unreadable"; err=1; }
  done
  [ "$err" -eq 0 ] || break
  first=-1
  for ((i = 0; i < n; i++)); do
    if [ "${pend[i]}" -eq 1 ]; then first=$i; break; fi
  done
  [ "$first" -ge 0 ] || break
  remaining=$(( deadline - $(date +%s) ))
  [ "$remaining" -gt 0 ] || break
  slice=$(( remaining < 30 ? remaining : 30 ))
  # A failed blocking read sets err; the loop's next pass still sweeps the
  # other jobs before exiting, so their printed statuses stay current.
  query "$first" "$slice" || { pend[first]=0; st[first]="unreadable"; err=1; }
done

running=(); unreadable=()
for ((i = 0; i < n; i++)); do
  echo "${ids[i]} ${st[i]}"
  if [ "${pend[i]}" -eq 1 ]; then running+=("${ids[i]}"); fi
  if [ "${st[i]}" = "unreadable" ]; then unreadable+=("${ids[i]}"); fi
done
if [ "$err" -ne 0 ]; then
  if [ "${#running[@]}" -gt 0 ]; then echo "running: ${running[*]}"; fi
  echo "unreadable: ${unreadable[*]}"
  exit 1
fi
if [ "${#running[@]}" -eq 0 ]; then echo "all-terminal"; exit 0; fi
echo "running: ${running[*]}"
exit 2
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/codex-review-gate/test-gate-wait.sh`
Expected: every line `[PASS]`, final `ALL PASS`, exit 0. (Cases 2, 3 and 8 take about 2-3 s each.)

- [ ] **Step 6: Lint**

Run: `scripts/lint-shell.sh skills/requesting-code-review/scripts/gate-wait tests/codex-review-gate/test-gate-wait.sh`
Expected: no findings, exit 0. Fix any finding in the files themselves; do not add blanket disables.

- [ ] **Step 7: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-wait tests/codex-review-gate/test-gate-wait.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(gate-wait): watch every Codex job of a gate in one call"
```

---

### Task 2: Gate docs use `gate-wait`

**Risk tier:** standard — behavior-shaping gate doc surgery under the split proof.

**Files:**
- Modify: `skills/requesting-code-review/recipe-code.md:18-22,30`
- Modify: `skills/requesting-code-review/gate-lenses.md:38`
- Modify: `skills/requesting-code-review/gate-findings.md:84,99,123,131,136`
- Modify: `tests/codex-review-gate/gate-post-split-edits.tsv` (rows 214 and 529 updated, 10 rows added)
- Modify: `tests/codex-review-gate/test-gate-split-lossless.sh:358` (pinned count 21 to 31, and the pass/fail messages beside it)
- Modify: `tests/codex-review-gate/test-gate-contract.sh:129-130` (and new assertions after line 134)

**Interfaces:**
- Consumes: `gate-wait [--budget SECONDS] JOB_ID...` and its exit codes from Task 1.

**Mirror:** existing rows `tests/codex-review-gate/gate-post-split-edits.tsv:11-24` (each row's replacement is the whole new line, byte-identical to the section file's line).

How the edit table works: each changed line of a section file is one row `srcline<TAB>reason<TAB>replacement`, where `srcline` = section-file line + section start - 1 (`recipe-code.md` +273, `gate-findings.md` +393, `gate-lenses.md` +176). The replacement is the entire new line, contains no tab and no backslash, differs from the original line, and the section file's line must equal it byte for byte. Lines are replaced in place: never add or remove a line in a section file. None of the srclines below is a referent in `gate-split-references.tsv`, so check 4d's count stays 2.

- [ ] **Step 1: Update the contract test first (failing)**

In `tests/codex-review-gate/test-gate-contract.sh`, replace lines 129-130:

```bash
assert_contains "$GATE" "2 consecutive \`gate-wait\` calls" \
  "watch loop has a bounded cap"
```

and after line 134 (the second `assert_not_contains` about `--wait`), add:

```bash
assert_contains "$GATE" "skills/requesting-code-review/scripts/gate-wait\" <job-id>..." \
  "recipe watch step blocks on gate-wait"
assert_contains "$GATE" "watch them all with one \`gate-wait\` call over every recorded id" \
  "lens fan-out watches every lens with one gate-wait call"
assert_contains "$GATE" "keeps a blocking \`gate-wait\` call in the" \
  "red flag names gate-wait as the watch call"
assert_not_contains "$GATE" "immediately issue the next \`status <job-id> --wait --json\`" \
  "agents no longer loop status --wait themselves"
```

Run: `bash tests/codex-review-gate/test-gate-contract.sh`
Expected: the new and changed assertions FAIL, the rest pass.

- [ ] **Step 2: Edit `recipe-code.md`**

Replace lines 18-22 and 30 with exactly these lines (lines 19-22 keep their three-space indent; lines 23-29 and 31-33 stay as they are):

Line 18:
```
3. **Watch in the foreground — never idle.** Block on one shell call (timeout 600000 ms) that watches every job id at once:
```
Line 19:
```
   `bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/gate-wait" <job-id>...` with `CODEX_PATH` exported;
```
Line 20:
```
   it re-reads every job without blocking, waits on one at a time in slices of at most 30 s, and returns when all are terminal (exit 0, last line `all-terminal`) or after its 480 s budget (exit 2, last line `running: <ids>`).
```
Line 21:
```
   On exit 2, immediately issue the next `gate-wait` over the ids still running. On exit 1 from a usage error, fix the call and re-run; on exit 1 for a job it could not read (last line `unreadable: <ids>`, stderr names the cause), run the §4b code-gate recovery for that job only and keep watching the ids still running with `gate-wait`.
```
Line 22:
```
   Never call `status <job-id> --wait` yourself; it is the primitive `gate-wait` runs for you.
```
Line 30:
```
Cap the watch at **2 consecutive `gate-wait` calls** (~16 minutes). If the job is
```

- [ ] **Step 3: Edit `gate-lenses.md` line 38**

In line 38, replace only the phrase

```
watch them in any order or concurrently via `status <job-id> --wait --json` — the ids, not recency, bind results to lenses.
```

with

```
watch them all with one `gate-wait` call over every recorded id — the ids, not recency, bind results to lenses.
```

Leave the rest of the line unchanged. (Do not name `recipe-code.md` here: `gate-lenses.md` is on document-gate routes that do not deliver it, and `test-gate-topology.sh` check 6 would fail.)

- [ ] **Step 4: Edit `gate-findings.md`**

Line 84 (five-space indent) becomes:
```
     known from launch, and `gate-wait <job-id>` / `result <job-id>
```
Line 99: replace only the sentence
```
`status <job-id> --wait --json` is the condition-based primitive (2 s interval, 240 s deadline) and returns as soon as Codex is done.
```
with
```
`status <job-id> --wait --json` is the condition-based primitive (2 s interval, 240 s deadline by default) and returns as soon as Codex is done; agents reach it through `gate-wait`, which applies it to every job of a gate in one call.
```
Line 123 becomes:
```
`gate-wait <job-id>`, never a blind `sleep`.
```
Line 131 becomes:
```
> genuinely needs awaiting, `gate-wait <job-id>` returns the instant it is
```
Line 136 becomes:
```
> runs. The recipe-code.md watch loop keeps a blocking `gate-wait` call in the
```

- [ ] **Step 5: Record the edits in `gate-post-split-edits.tsv`**

Update the replacement column of the existing rows `214` (the full new `gate-lenses.md` line 38) and `529` (the new `gate-findings.md` line 136). Add these ten rows (reason `gate-wait-watch`; replacement = the full new line from the section file, copied byte for byte): `291`, `292`, `293`, `294`, `295`, `303` (recipe-code.md lines 18-22 and 30), `477`, `492`, `516`, `524` (gate-findings.md lines 84, 99, 123, 131). Use a tab between columns. Verify no replacement contains a tab or a backslash:

```bash
awk -F'\t' '!/^#/ && NF!=3 {print "bad field count: " NR}' tests/codex-review-gate/gate-post-split-edits.tsv
grep -n '\\' tests/codex-review-gate/gate-post-split-edits.tsv | grep -v '^[0-9]*:#' || echo "no backslashes"
```

Expected: no "bad field count" lines; `no backslashes`.

- [ ] **Step 6: Bump the pinned count**

In `tests/codex-review-gate/test-gate-split-lossless.sh` line 358 change `-eq 21` to `-eq 31`, and change `21` to `31` in the pass and fail messages on the following lines.

- [ ] **Step 7: Run the gate suites**

Run each in its own call:
```bash
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/codex-review-gate/test-gate-topology.sh
bash tests/codex-review-gate/test-assemble-gate.sh
bash tests/codex-review-gate/test-gate-placement.sh
```
Expected: each exits 0 with no FAIL line. If `test-gate-split-lossless.sh` reports a mismatch, compare the named section file's line with its row's replacement byte for byte (`sed -n Np file | od -c | head`), fix the row or the line, and re-run.

- [ ] **Step 8: Commit**

```bash
git add skills/requesting-code-review/recipe-code.md skills/requesting-code-review/gate-lenses.md skills/requesting-code-review/gate-findings.md tests/codex-review-gate/gate-post-split-edits.tsv tests/codex-review-gate/test-gate-split-lossless.sh tests/codex-review-gate/test-gate-contract.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(codex-review-gate): the watch step blocks on one gate-wait call for every job"
```

---

### Task 3: README cost section

**Risk tier:** low — single-file documentation; the plan contains the complete text.

**Files:**
- Modify: `README.md` (new section between `## The Basic Workflow` and `## What's Inside`, around line 177)

- [ ] **Step 1: Insert the section**

Immediately before the line `## What's Inside`, insert (followed by one blank line):

````markdown
## Cost and Context

Long hyperpowers sessions cost more than their tasks suggest, because every model call re-sends the whole conversation. Over a month of heavy use, nine tenths of the cost was reading and writing cached context, and main sessions averaged over 400K tokens of context per call. On models with a 1M-token window, Claude Code compacts only near 968K tokens, so a session that runs brainstorming, planning and subagent-driven development for days spends most of its calls between 500K and 968K.

Recommended setting in `~/.claude/settings.json` (the environment variable `CLAUDE_CODE_AUTO_COMPACT_WINDOW` does the same):

```json
{
  "autoCompactWindow": 400000
}
```

Replaying that month of sessions, a 400K window cut cost by about 28%. A 300K or 200K window saved only 4 or 7 points more, while adding 1.5 or 2.6 times as many compactions, and each compaction drops detail.

If you set `ENABLE_PROMPT_CACHING_1H=1`, keep it. With a five-minute cache the same replay cost about 56% more: long sessions pause for five to sixty minutes while subagents, reviews or you are busy, and every pause past five minutes rewrites the whole context.

When a plan is written, run `/clear` before starting subagent-driven development. The spec and plan are on disk, so the execution session starts small.

After a compaction, Claude Code re-attaches each skill the session used, cut to its first 20,000 characters. The subagent-driven-development and brainstorming skills tell the agent to Read their full text after a compaction, so a lower window does not leave them running from a cut copy.

````

- [ ] **Step 2: Check and commit**

```bash
grep -n "^## Cost and Context" README.md
grep -n '\$[0-9]' README.md | grep -i -E "cost|bill|spend" || echo "no dollar figures"
git add README.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(readme): cost and context settings for long sessions"
```

Expected: the heading appears once; `no dollar figures`; `hits: 0`.

---

### Task 4: Eval scenario `sdd-compaction-reread`

**Risk tier:** high — its `checks.sh` output feeds quorum's verdict, which the campaign tally trusts.

All paths in Tasks 4-8 and 10 are in the evals repository, `/Users/johnss51/Development/agents/hyperpowers/evals`, on its `main` branch, unless they name the hyperpowers worktree.

**Files:**
- Create: `scenarios/sdd-compaction-reread/setup.sh`, `scenarios/sdd-compaction-reread/checks.sh`, `scenarios/sdd-compaction-reread/story.md`

**Interfaces:**
- Produces: scenario name `sdd-compaction-reread`; the evals commit that adds it is the campaign's `harness` pin (Task 6). Nothing after this task may change `src`, `scenarios`, `coding-agents`, `package.json` or `bun.lock`, or the pin goes stale.

**Mirror:** `scenarios/sdd-unified-fix-loop/setup.sh:1-20` (fixture start), `scenarios/sdd-unified-fix-loop/checks.sh:21-71` (`pre`/`post`), `scenarios/brainstorming-bounded-companion-after-compaction/setup.sh:297-302` (window block) and `:33` (window comment), `scenarios/brainstorming-bounded-companion-after-compaction/story.md:1-33` (frontmatter and brief shape).

- [ ] **Step 1: Write `setup.sh`**

`#!/usr/bin/env bash`, `set -euo pipefail`, `setup-helpers run create_base_repo`, `git checkout -b feature/textstats`. A header comment says why the window is set (after it, Claude Code re-attaches each invoked skill cut to its first 20,000 characters; the scenario measures whether the controller reads SDD in full again) and why `plan.md` is long (its size makes the controller's context cross the compaction threshold, about 33K below the window, after the first task). The script writes and commits, in one commit:

- `.claude/settings.json`:

```json
{
  "autoCompactWindow": 100000
}
```

- `package.json` with `"name": "textstats"`, `"version": "0.0.0"`, `"private": true`, `"scripts": {"test": "node --test"}` and no `type` field.
- `src/textstats.js` containing `module.exports = {};` and `test/.gitkeep`.
- `plan.md`: a four-task plan with the writing-plans header block (`# Textstats Implementation Plan`, the agentic-workers line, `**Spec:** none (fixture)`, Goal, Architecture, Tech Stack: Node.js 20 `node:test`), then Task 1 `wordCount(text)`, Task 2 `sentenceCount(text)`, Task 3 `topWords(text, n)`, Task 4 `readingTimeMinutes(text, wpm = 200)`. Each task has `**Files:**`, a failing-test step with a complete `test/<name>.test.js` of at least 12 `test()` cases, a run-and-fail step, a complete implementation added to `src/textstats.js` and exported, a run-and-pass step (`npm test`), and a commit step. The whole file is 60,000 to 80,000 characters (`wc -c plan.md` in the fixture).

- [ ] **Step 2: Write `checks.sh`**

```bash
# coding-agents: claude-auto
# Deterministic checks only. Whether the compaction landed in the window, and
# what the controller did after it, are read from the transcript by the
# campaign tally (evidence/2026-11-03-cost-reduction-6-16-2/tally.py): quorum
# has no compaction-aware check verb.
pre() {
  git-repo
  git-branch feature/textstats
  file-exists plan.md
  file-exists .claude/settings.json
  requires-tool node
}

post() {
  check-transcript skill-called superpowers:subagent-driven-development hyperpowers:subagent-driven-development
  check-transcript tool-called Agent
  command-succeeds 'npm test'
}
```

- [ ] **Step 3: Write `story.md`**

Frontmatter: `id: sdd-compaction-reread`, `title: SDD keeps its task loop after a mid-plan compaction`, `status: ready`, `quorum_tier: full`, `quorum_max_time: 60m`, `tags: [sdd, compaction]`. Brief for the Gauntlet-Agent: send exactly `Execute plan.md with subagent-driven development.`; answer a worktree or branch question with `Stay on the current branch`; answer a finishing question with `Keep the branch as-is`; answer anything else with `Proceed as you recommend.` `## Acceptance Criteria`: all four tasks are implemented and committed; each task is reviewed before the next task starts; a final whole-branch review runs; the session ends in the finishing step.

- [ ] **Step 4: Check and commit**

```bash
cd /Users/johnss51/Development/agents/hyperpowers/evals
chmod +x scenarios/sdd-compaction-reread/setup.sh
bash -n scenarios/sdd-compaction-reread/setup.sh
bun run src/cli/index.ts check sdd-compaction-reread
bun run src/cli/index.ts list | grep sdd-compaction-reread
git add scenarios/sdd-compaction-reread
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(scenarios): sdd-compaction-reread"
git rev-parse HEAD
```

Expected: `check` reports the scenario well-formed and `list` shows it. Record the printed commit as the harness pin in the task report.

---

### Task 5: Campaign tally

**Risk tier:** high — its output decides whether the skill change ships (trusted output).

**Files:**
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/tally.py`
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/test_tally.py`

**Interfaces:**
- Consumes: launcher logs `logs/<arm>-<scenario>-<proc>.log` (Task 6), each holding quorum's output with run ids; run records `verdict.json`; transcripts under `home/.claude/projects/*/*.jsonl`.
- Produces: `python3 tally.py` (all campaign logs) and `python3 tally.py --run RUN_ID --arm ARM --scenario NAME` (one run, for the smoke). Prints one line per run and a per-arm, per-scenario summary with the pass-bar reading; exits 0, or 1 when `sentinel-reruns.tsv` violates a rule.

**Mirror:** `evidence/2026-10-02-companion-after-compaction/tally.py:44-95` (`run_dir`, `void_kind`, `post_check`, `final_reading`), `:114-210` (`transcript_facts`, the brainstorming window), `:229-300` (`read_run`, `collect` parsing launcher logs).

- [ ] **Step 1: Write the failing tests**

`test_tally.py` uses only the standard library (`unittest`) and imports `tally` from its directory. Synthetic runs are built in a temporary directory with a `verdict.json` and a `home/.claude/projects/x/s.jsonl` written from lists of entries. Helper builders: `tool_use(name, input, id)` (an assistant entry), `notif(tool_use_id)` (a user entry whose content is `<task-notification> <task-id>a</task-id> <tool-use-id>ID</tool-use-id> <status>completed</status> </task-notification>`), `compact()` (a `system` entry with `subtype` `compact_boundary` and `compactMetadata.trigger` `auto`). Cases:

1. A valid passing SDD trial: dispatches `Implement Task 1: a` / notif / `Review Task 1 (spec + quality)` / notif / compact / Read `.../subagent-driven-development/SKILL.md` / `Implement Task 2: b` ... review 4 / notif / `Final whole-branch code review` / notif / Skill `hyperpowers:finishing-a-development-branch`. Expect valid, outcome pass, mechanism pass.
2. Compaction between the review-1 dispatch and its notification: void (instrument).
3. Compaction before any review-1 dispatch: void.
4. Compaction after implementer 2 was dispatched, no review-2 dispatch after it: valid, outcome fail (the task in flight lost its review).
5. Implementer 1 dispatched again after the compaction: outcome fail.
6. The Read comes after the first dispatch that follows the compaction: mechanism fail.
7. Classification by prompt when the description is non-standard: description `do task 3`, prompt starting `You are implementing Task 3` classifies as implementer 3.
8. Real transcript: the turn-liveness smoke transcript at `evidence/2026-10-19-sdd-turn-liveness/task-9-runs/smoke/control/workspaces/sdd-turn-liveness-claude-auto-20261021T185013Z-d4c8/home/.claude/projects/` classifies 6 implementer, 6 review and 1 final dispatch, and every one of those 13 has a completion event.
9. `sentinel-reruns.tsv` rules: a valid replacement of a void is accepted; a chain `orig -> r1`, `r1 -> r2` with `r1` void is accepted and only `r2` counts; two rows replacing the same original raise `ValueError`; replacing a non-void raises `ValueError`; a replacement from a different arm or scenario raises; a replacement listed twice raises; a fourth replacement in one arm and scenario raises; a run with proc `r<n>` that no row lists raises.
10. Brainstorming: compaction between the `Skill` brainstorming call and the first `start-server.sh` Bash call, with a Read of `.../brainstorming/SKILL.md` before that call: valid, mechanism pass; the same with the Read after it: mechanism fail; compaction after the first `AskUserQuestion`: void.
11. Final review not completed: as case 1 but the final review's notification is missing, or comes after the finishing `Skill` call: outcome fail.
12. Launch failures: a log ending `FAILED 3 control sdd-compaction-reread p4` whose run has an otherwise passing verdict and transcript is void with kind `launch`, not valid; a log with no terminal line is treated the same.

Run: `cd evidence/2026-11-03-cost-reduction-6-16-2 && python3 -m unittest test_tally -v`
Expected: errors (no module `tally`).

- [ ] **Step 2: Write `tally.py`**

Start the file with the module docstring (usage, what it reads, the rules below) and these core functions; copy `void_kind`, `post_check`, `final_reading` and the log-parsing part of `collect` from the companion-after-compaction tally, citing it in a comment.

```python
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
EVALS = HERE.parents[1]
SDD = "sdd-compaction-reread"
BRAIN = "brainstorming-bounded-companion-after-compaction"
RUN_ROOTS = ("task-10-runs", "task-8-runs", "task-7-runs")
NOTIF_ID = re.compile(r"<tool-use-id>([^<]+)</tool-use-id>")
NOTIF_STATUS = re.compile(r"<status>([^<]+)</status>")


def run_paths(arm: str, run_id: str) -> tuple[Path, list[Path]]:
    """Locate a run's record and main transcripts, archived or live, relocated or legacy.

    :param arm: ``control``, ``treatment`` or ``smoke``.
    :param run_id: The quorum run id.
    :returns: The directory holding ``verdict.json`` and the sorted transcript paths.
    :raises FileNotFoundError: When no root holds the run.
    """
    bases = [HERE / root / arm for root in RUN_ROOTS] + [EVALS / "results"]
    for base in bases:
        record = base / run_id
        if (record / "verdict.json").is_file():
            workspace = base / "workspaces" / run_id
            home_root = workspace if (workspace / "home").is_dir() else record
            return record, sorted(home_root.glob("home/.claude/projects/*/*.jsonl"))
    raise FileNotFoundError(f"no record for run {run_id} under {[str(b) for b in bases]}")


def classify(description: str, prompt: str) -> tuple[str, int | None]:
    """Classify an Agent dispatch as implement/review/rereview/fix/final/other with its task number."""
    for kind, pattern in (
        ("implement", r"\s*Implement Task (\d+)"),
        ("rereview", r"\s*Re-review Task (\d+)"),
        ("review", r"\s*Review Task (\d+)"),
        ("fix", r"\s*Fix findings for Task (\d+)"),
    ):
        match = re.match(pattern, description or "")
        if match:
            return kind, int(match.group(1))
    match = re.match(r"\s*You are implementing Task (\d+)", prompt or "")
    if match:
        return "implement", int(match.group(1))
    if (
        re.search(r"final", description or "", re.IGNORECASE)
        or description == "Review code changes"
        or (prompt or "").lstrip().startswith("You are a Senior Code Reviewer")
    ):
        return "final", None
    return "other", None


def events(transcripts: list[Path]) -> list[dict[str, Any]]:
    """Main-thread events in file order: compact, dispatch, done, read, skill, ask, server."""
    found: list[dict[str, Any]] = []
    for path in transcripts:
        for line in path.read_text(encoding="utf-8").splitlines():
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(entry, dict) or entry.get("isSidechain"):
                continue
            if (
                entry.get("type") == "system"
                and entry.get("subtype") == "compact_boundary"
                and (entry.get("compactMetadata") or {}).get("trigger") == "auto"
            ):
                found.append({"kind": "compact"})
                continue
            message = entry.get("message") or {}
            content = message.get("content") if isinstance(message, dict) else None
            if entry.get("type") == "assistant" and isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict) or block.get("type") != "tool_use":
                        continue
                    name, args = block.get("name"), block.get("input") or {}
                    if name in ("Agent", "Task"):
                        kind, task = classify(str(args.get("description") or ""), str(args.get("prompt") or ""))
                        found.append({"kind": "dispatch", "class": kind, "task": task, "id": block.get("id")})
                    elif name == "Read":
                        found.append({"kind": "read", "path": str(args.get("file_path") or "")})
                    elif name == "Skill":
                        found.append({"kind": "skill", "skill": str(args.get("skill") or "")})
                    elif name == "AskUserQuestion":
                        found.append({"kind": "ask"})
                    elif name == "Bash" and "start-server.sh" in str(args.get("command") or ""):
                        found.append({"kind": "server"})
            elif entry.get("type") == "user":
                if isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "tool_result":
                            if "Async agent launched" not in json.dumps(block.get("content")):
                                found.append({"kind": "done", "id": block.get("tool_use_id")})
                text = content if isinstance(content, str) else json.dumps(content)
                if "<task-notification>" in text:
                    ident, status = NOTIF_ID.search(text), NOTIF_STATUS.search(text)
                    if ident and (status is None or status.group(1) == "completed"):
                        found.append({"kind": "done", "id": ident.group(1)})
    return found


def sdd_reading(found: list[dict[str, Any]]) -> dict[str, Any]:
    """Validity, outcome and mechanism for one SDD trial (rules in the module docstring)."""
    compact = next((i for i, e in enumerate(found) if e["kind"] == "compact"), None)
    dispatches = {e["id"]: e for e in found if e["kind"] == "dispatch"}
    done_at: dict[str, int] = {}
    for i, e in enumerate(found):
        if e["kind"] == "done" and e["id"] in dispatches and e["id"] not in done_at:
            done_at[e["id"]] = i
    review1_done = min(
        (done_at[k] for k, d in dispatches.items() if d["class"] == "review" and d["task"] == 1 and k in done_at),
        default=None,
    )
    final_at = next((i for i, e in enumerate(found) if e["kind"] == "dispatch" and e["class"] == "final"), None)
    valid = (
        compact is not None
        and review1_done is not None
        and review1_done < compact
        and (final_at is None or compact < final_at)
    )
    reading: dict[str, Any] = {"valid": valid, "outcome": None, "mechanism": None}
    if not valid:
        return reading
    done_before = {
        d["task"] for k, d in dispatches.items()
        if d["class"] in ("review", "rereview") and k in done_at and done_at[k] < compact
    }
    after = found[compact + 1:]
    reviewed_after = {e["task"] for e in after if e["kind"] == "dispatch" and e["class"] in ("review", "rereview")}
    final_pos = next((j for j, e in enumerate(after) if e["kind"] == "dispatch" and e["class"] == "final"), None)
    finish_pos = next(
        (
            j for j, e in enumerate(after)
            if final_pos is not None and j > final_pos
            and e["kind"] == "skill" and e["skill"].endswith("finishing-a-development-branch")
        ),
        None,
    )
    # The final review has to come back before Finish: a dispatched review
    # that never returned did not run in the sense the spec requires.
    final_id = after[final_pos]["id"] if final_pos is not None else None
    finished = (
        finish_pos is not None
        and final_id in done_at
        and done_at[final_id] < compact + 1 + finish_pos
    )
    redispatch = any(
        e["kind"] == "dispatch" and e["class"] == "implement" and e["task"] in done_before for e in after
    )
    reading["outcome"] = ({1, 2, 3, 4} - done_before) <= reviewed_after and finished and not redispatch
    first_dispatch = next((j for j, e in enumerate(after) if e["kind"] == "dispatch"), len(after))
    reading["mechanism"] = any(
        e["kind"] == "read" and e["path"].endswith("subagent-driven-development/SKILL.md")
        for e in after[:first_dispatch]
    )
    return reading


def brainstorming_reading(found: list[dict[str, Any]]) -> dict[str, Any]:
    """Window validity and mechanism for one brainstorming trial."""
    load = next(
        (i for i, e in enumerate(found) if e["kind"] == "skill" and e["skill"].endswith("brainstorming")), None
    )
    question = next((i for i, e in enumerate(found) if e["kind"] in ("ask", "server")), None)
    compact = next(
        (i for i, e in enumerate(found) if e["kind"] == "compact" and load is not None and i > load), None
    )
    valid = load is not None and compact is not None and (question is None or compact < question)
    reading: dict[str, Any] = {"valid": valid, "mechanism": None}
    if valid:
        stop = question if question is not None else len(found)
        reading["mechanism"] = any(
            e["kind"] == "read" and e["path"].endswith("brainstorming/SKILL.md") for e in found[compact + 1:stop]
        )
    return reading


def load_reruns(path: Path, runs: dict[str, dict[str, Any]]) -> dict[str, str]:
    """Read ``sentinel-reruns.tsv`` (original, replacement) and enforce the replacement rules.

    A replacement that is itself void may be replaced in turn by a later row
    naming it as the original (``original -> r1``, ``r1 -> r2``); every link
    counts toward the cell's cap of three.

    :raises ValueError: On an unknown run, an original replaced twice, a
        non-void original, a cross-cell replacement, a replacement used twice,
        more than three per arm and scenario, or an ``r<n>`` run no row lists.
    """
    pairs: dict[str, str] = {}
    used: set[str] = set()
    per_cell: Counter[tuple[str, str]] = Counter()
    if path.is_file():
        with path.open(encoding="utf-8") as handle:
            for row in csv.reader(handle, delimiter="\t"):
                if not row or row[0].startswith("#"):
                    continue
                original, replacement = row[0], row[1]
                if original not in runs or replacement not in runs:
                    raise ValueError(f"unknown run in sentinel-reruns.tsv: {original} {replacement}")
                o, r = runs[original], runs[replacement]
                if original in pairs:
                    raise ValueError(f"{original} is replaced more than once")
                if not o["void"]:
                    raise ValueError(f"{original} is not a void")
                if (o["arm"], o["scenario"]) != (r["arm"], r["scenario"]):
                    raise ValueError(f"{replacement} is not in {original}'s arm and scenario")
                if replacement in used:
                    raise ValueError(f"{replacement} replaces more than one run")
                used.add(replacement)
                per_cell[(o["arm"], o["scenario"])] += 1
                if per_cell[(o["arm"], o["scenario"])] > 3:
                    raise ValueError(f"more than three replacements in {o['arm']} {o['scenario']}")
                pairs[original] = replacement
    for run_id, run in runs.items():
        if run["proc"].startswith("r") and run_id not in used:
            raise ValueError(f"replacement run {run_id} has no sentinel-reruns.tsv row")
    return pairs
```

The rest of `tally.py`:

- `read_run(arm, scenario, proc, run_id)` returns `{"run", "arm", "scenario", "proc", "void", "void_kind", "valid", "outcome", "mechanism"}`. `void_kind` comes from the copied `void_kind(verdict)` (setup or grader void); a run with no void kind but an invalid timing reading is void with kind `instrument`. SDD outcome is `sdd_reading(...)["outcome"]` and quorum's post checks all passing (`post_check`); brainstorming outcome is quorum's post checks all passing.
- `collect(logs)` parses `logs/<arm>-<scenario>-<proc>.log` names (arm `control` or `treatment`, scenario one of the two names, proc `p1`-`p10` or `r1`-`r3`; it skips proc `p90`, the Task 7 smoke) and the run ids in each log, as the companion tally does, and returns the runs keyed by run id. A log whose last line does not start with `DONE ` (a `FAILED <code>` line, or no terminal line) never yields a valid trial: its run, if one was recorded, is void with kind `launch`, and a log with no run id is reported as a launch failure for that row. `measure-launch.sh` exits 0 even when it prints `FAILED`, so this check is the only thing that keeps such a run out of the counts.
- `main()`: with `--run/--arm/--scenario` reads that one run and prints its line. Otherwise it collects every log, applies `load_reruns(HERE / "sentinel-reruns.tsv", runs)` (an original that has a replacement drops out of the counts; the replacement counts), prints one line per run, then for each arm and scenario: runs, valid, voids by kind, outcome passes, mechanism passes. It ends with the pass-bar reading from the spec: SDD treatment outcome >= 8 of valid (n = 10 expected) and >= control's rate, SDD treatment mechanism >= 8 of 10; brainstorming treatment outcome rate >= control's, mechanism >= 8 of 10. Each bar prints `PASS`, `FAIL`, or `INCOMPLETE` (fewer than 10 valid in a needed cell). `ValueError` from `load_reruns` prints the message and exits 1.

- [ ] **Step 3: Run the tests to verify they pass**

Run: `cd evidence/2026-11-03-cost-reduction-6-16-2 && python3 -m unittest test_tally -v`
Expected: all twelve test methods OK.

- [ ] **Step 4: Commit**

```bash
cd /Users/johnss51/Development/agents/hyperpowers/evals
git add evidence/2026-11-03-cost-reduction-6-16-2/tally.py evidence/2026-11-03-cost-reduction-6-16-2/test_tally.py
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(evidence): tally for the 6.16.2 re-read campaign"
```

---

### Task 6: Campaign launcher and manifests

**Risk tier:** high — concurrent launcher whose logs and pins become committed evidence.

**Files:**
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/launch-all.sh` (copied unchanged)
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/logs/measure-launch.sh` (copied and adapted)
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/manifest-red.tsv`, `manifest-green.tsv`
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/README.md`

**Interfaces:**
- Consumes: the harness pin from Task 4.
- Produces: `bash launch-all.sh <manifest> <max>` writing `logs/<arm>-<scenario>-<proc>.log`, each ending `DONE` or `FAILED <code>`; Tasks 7, 8 and 10 run it; Task 5's `collect` reads the logs.

**Mirror:** `evidence/2026-10-02-companion-default-window/launch-all.sh:1-82` and `logs/measure-launch.sh:1-82`.

- [ ] **Step 1: Create the control checkout**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers worktree add --detach /Users/johnss51/.cache/hyperpowers/cost-6162/hp-6161 v6.16.1
git -C /Users/johnss51/Development/agents/hyperpowers rev-parse 'v6.16.1^{commit}'
```

Record the commit as the control pin.

- [ ] **Step 2: Copy and adapt the launcher**

Copy `launch-all.sh` unchanged. Copy `logs/measure-launch.sh` and change only:

- the header's campaign name and the "Adapted from" line (name the source);
- `E="$EV/evidence/2026-11-03-cost-reduction-6-16-2"`;
- `CC_PIN=2.1.317` (the host's `claude --version` when this plan was written; confirm it again before each campaign and update the pin, with a note in README.md, if the host has moved);
- `GRADER_PIN=claude-opus-5-5`;
- the arm `case`:

```bash
case "$arm" in
  control) root=/Users/johnss51/.cache/hyperpowers/cost-6162/hp-6161 ;;
  treatment) root=/Users/johnss51/Development/agents/hyperpowers/.worktrees/cost-6-16-2 ;;
  *) echo "arm must be control or treatment" >&2; exit 2 ;;
esac
```

Leave the pin checks, the clean-tree checks, the proxy checks, the `env -u INTERLOCK_PROBE_TRACE -u SLASH_COMMAND_TOOL_CHAR_BUDGET bun run quorum run ...` command, the DONE/FAILED line and the PID-reuse handling as they are.

- [ ] **Step 3: Write the manifests**

`manifest-red.tsv` (control arm; SDD rows first so the longer trials start first):

```
harness	<Task 4 commit>
control	<v6.16.1 commit>
treatment	<fill in Task 10>
model	claude-opus-5-5
control	sdd-compaction-reread	1	p1	default
control	sdd-compaction-reread	1	p2	default
control	sdd-compaction-reread	1	p3	default
control	sdd-compaction-reread	1	p4	default
control	sdd-compaction-reread	1	p5	default
control	sdd-compaction-reread	1	p6	default
control	sdd-compaction-reread	1	p7	default
control	sdd-compaction-reread	1	p8	default
control	sdd-compaction-reread	1	p9	default
control	sdd-compaction-reread	1	p10	default
control	brainstorming-bounded-companion-after-compaction	1	p1	default
control	brainstorming-bounded-companion-after-compaction	1	p2	default
control	brainstorming-bounded-companion-after-compaction	1	p3	default
control	brainstorming-bounded-companion-after-compaction	1	p4	default
control	brainstorming-bounded-companion-after-compaction	1	p5	default
control	brainstorming-bounded-companion-after-compaction	1	p6	default
control	brainstorming-bounded-companion-after-compaction	1	p7	default
control	brainstorming-bounded-companion-after-compaction	1	p8	default
control	brainstorming-bounded-companion-after-compaction	1	p9	default
control	brainstorming-bounded-companion-after-compaction	1	p10	default
```

`manifest-green.tsv` is the same with every row's arm `treatment` (pin rows identical). Fill the two known pins now; `treatment` stays `<fill in Task 10>`, which the launcher refuses for treatment rows until it is filled.

One trial per row keeps each launcher process under the scenario's 60-minute limit; at 14 concurrent processes the ten SDD trials and four brainstorming trials start at once, and the remaining brainstorming trials (about 10-15 minutes each) take the first free slots, so a wave fits the 7200000 ms background limit.

- [ ] **Step 4: Validate the launcher with a stub**

```bash
cd /Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-11-03-cost-reduction-6-16-2
stub="$(mktemp "${TMPDIR:-/tmp}/stub-launch.XXXXXX")"
printf '#!/usr/bin/env bash\nmkdir -p "$LOGS"; echo "DONE $1 $2 $4" > "$LOGS/$1-$2-$4.log"\n' > "$stub"; chmod +x "$stub"
LOGS="$(mktemp -d "${TMPDIR:-/tmp}/stub-logs.XXXXXX")" LAUNCHER="$stub" bash launch-all.sh manifest-red.tsv 14; echo "exit=$?"
bash -n logs/measure-launch.sh
```

Expected: `exit=0` and a closing line reporting every row DONE; `bash -n` silent. Then confirm the real launcher refuses a treatment row while the pin is unfilled: `bash logs/measure-launch.sh treatment sdd-compaction-reread 1 p1 default` (from a shell with the proxy variables set) must exit non-zero with "manifest.tsv is not filled in" or the equivalent message, before launching anything; run it with `MANIFEST=$PWD/manifest-green.tsv`.

- [ ] **Step 5: Write README.md and commit**

`README.md`: what the campaign measures (spec path, pass bar), the pins and where they come from, how to launch a wave (the Task 8 command), how to tally, and the replacement rules (`sentinel-reruns.tsv`, at most three per arm and scenario).

```bash
cd /Users/johnss51/Development/agents/hyperpowers/evals
git add evidence/2026-11-03-cost-reduction-6-16-2/launch-all.sh evidence/2026-11-03-cost-reduction-6-16-2/logs/measure-launch.sh evidence/2026-11-03-cost-reduction-6-16-2/manifest-red.tsv evidence/2026-11-03-cost-reduction-6-16-2/manifest-green.tsv evidence/2026-11-03-cost-reduction-6-16-2/README.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(evidence): launcher and manifests for the 6.16.2 re-read campaign"
```

---

### Task 7: Smoke run and assumption checks

**Risk tier:** standard — validates the two spec assumptions every later measurement depends on.

`Assumption: autoCompactWindow 100000 makes a compaction land after task 1's review returns and before the final review in the four-task run, validate via this task's smoke run, before Task 8.`
`Assumption: Claude Code 2.1.317 still re-attaches skills cut at 20,000 characters, validate via this task's smoke transcript, before Task 8.`

**Files:**
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/task-7-runs/smoke/` (copied run), `evidence/2026-11-03-cost-reduction-6-16-2/smoke.md`

- [ ] **Step 1: Run one control trial**

From the evals repo with a clean tree, with `ANTHROPIC_MODEL=claude-opus-5-5` and `GAUNTLET_AGENT_MODEL=claude-opus-5-5` exported, as a tracked background job (run-in-background, background timeout 7200000 ms):

```bash
MANIFEST=/Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-11-03-cost-reduction-6-16-2/manifest-red.tsv bash evidence/2026-11-03-cost-reduction-6-16-2/logs/measure-launch.sh control sdd-compaction-reread 1 p90 default; echo "exit=$?" > evidence/2026-11-03-cost-reduction-6-16-2/logs/smoke.exit
```

Watch in the foreground with bounded calls (at most 600000 ms each) that wait for `logs/smoke.exit`, per SDD's watch rules. The smoke counts only when `logs/control-sdd-compaction-reread-p90.log` ends with `DONE control sdd-compaction-reread p90`; a `FAILED` line is an infrastructure failure to diagnose and re-run, not an attempt against the three-attempt limit. The smoke uses proc `p90` so its log never collides with a campaign row; it is not part of either wave's counts.

- [ ] **Step 2: Check both assumptions**

Take the run id from `logs/control-sdd-compaction-reread-p90.log` and run `python3 evidence/2026-11-03-cost-reduction-6-16-2/tally.py --run <id> --arm smoke --scenario sdd-compaction-reread` (before the copy in Step 4 it resolves from `results/`). The run must be valid. In the transcript, the `attachment` entry of type `invoked_skills` after the compaction must show the SDD skill's content at 20,000 characters ending with the "truncated for compaction" note.

- If the compaction lands after the final review or never: lengthen `plan.md` (more test cases per task, or a fifth task, updating the tally's `{1, 2, 3, 4}` set and its test to match), commit the fixture change (which moves the harness pin: update both manifests' `harness` row) and re-run, at most three attempts. Record each attempt in `smoke.md`.
- If it lands before review 1 returns: shorten `plan.md`, same procedure.
- If the truncation length or note differs: stop and report BLOCKED with the transcript excerpt; the spec's premise changed and the human partner decides.

- [ ] **Step 3: Confirm the tally reads the real run**

The `--run` line must show the dispatch classes the tally found for the smoke transcript (4 implementer, at least 4 review, 1 final when the run finished). A run that finished but shows a missing class means the classifier misses a real description; fix `classify`, add the description to `test_tally.py` case 7, re-run the tests, and commit.

- [ ] **Step 4: Copy and commit the smoke evidence**

Copy the run into `task-7-runs/smoke/` following `evidence/README.md` (`scripts/strip-runs`, rename `.git` to `git-dir`, `git add -f` the listed paths, then the post-check), write `smoke.md` (attempts, compaction position, truncation observation, tally line), and commit in the evals repo with the realval scan. The commit includes `evidence/2026-11-03-cost-reduction-6-16-2/smoke.md`, `task-7-runs/smoke/`, `logs/control-sdd-compaction-reread-p90.log` and `logs/smoke.exit` by explicit path, so the evals tree is clean before Task 8.

---

### Task 8: RED campaign (control arm)

**Risk tier:** standard — runs the baseline the skill change is measured against.

**Files:**
- Create: `evidence/2026-11-03-cost-reduction-6-16-2/task-8-runs/control/...`, `logs/control-*.log`, `tally-red.txt`

- [ ] **Step 1: Launch the wave**

Confirm `claude --version` still matches `CC_PIN`. From the evals repo with a clean tree, `ANTHROPIC_MODEL` and `GAUNTLET_AGENT_MODEL` exported as in Task 7, as one tracked background job (background timeout 7200000 ms):

```bash
bash evidence/2026-11-03-cost-reduction-6-16-2/launch-all.sh evidence/2026-11-03-cost-reduction-6-16-2/manifest-red.tsv 14 > evidence/2026-11-03-cost-reduction-6-16-2/logs/launch-red.out 2>&1; echo "exit=$?" > evidence/2026-11-03-cost-reduction-6-16-2/logs/launch-red.exit
```

Watch in the foreground with bounded calls (at most 600000 ms each) waiting for `logs/launch-red.exit`. If the 7200000 ms watch budget is spent with the job still running, stop it through the harness, record the log tail, and report BLOCKED. When the exit file reads anything but `exit=0`, read `logs/launch-red.out`'s closing line and each row log's last line: a row whose log ends `FAILED <code>` or lacks a `DONE` line is a launch void (the tally counts it so), replaced in Step 2; a manifest validation failure (nothing launched) is fixed and the wave relaunched.

- [ ] **Step 2: Tally and replace voids**

`python3 evidence/2026-11-03-cost-reduction-6-16-2/tally.py > evidence/2026-11-03-cost-reduction-6-16-2/tally-red.txt`. For each control cell below 10 valid trials, launch replacement rows with proc `r1`, `r2`, `r3` (at most three per cell) through `logs/measure-launch.sh` with `MANIFEST` set to `manifest-red.tsv`, confirm each replacement's log ends with `DONE control <scenario> r<n>` (a `FAILED` replacement is itself a void and may be replaced in turn within the cap), add one `sentinel-reruns.tsv` row per replacement (`<original run id><TAB><replacement run id>`), and re-tally. A cell still short of 10 valid trials is reported with its actual n.

- [ ] **Step 3: Copy runs and commit**

Copy every control run into `task-8-runs/control/` per `evidence/README.md`, then commit, by explicit path, `task-8-runs/`, `logs/control-sdd-compaction-reread-p*.log`, `logs/control-sdd-compaction-reread-r*.log` and the brainstorming equivalents that exist, `logs/launch-red.out`, `logs/launch-red.exit`, `tally-red.txt` and `sentinel-reruns.tsv` (if written) in the evals repo with the realval scan. `git status --short evidence/2026-11-03-cost-reduction-6-16-2` must print nothing afterwards.

---
### Task 9: Re-read-after-compaction paragraphs (GREEN edit)

**Risk tier:** standard — behavior-shaping skill text in SDD and brainstorming.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (insert after the `**Continuous execution:**` paragraph, before `## When to Use`)
- Modify: `skills/brainstorming/SKILL.md` (insert after the `**REQUIRED SUB-SKILL:**` line, before `## Three Paths`)
- Create: `tests/sdd/test-compaction-reread.sh`

**Interfaces:**
- Consumes: the RED baseline from Task 8 (writing-skills order: the control arm runs before the skill text changes).
- Produces: the exact paragraph strings below; the tally (Task 5) does not depend on them (it looks for a Read of the file). Task 10 pins this task's commit as the treatment.

**Mirror:** `tests/sdd/test-sdd-contract.sh:1-30` for the test boilerplate and `assert_contains`.

- [ ] **Step 1: Write the failing test**

Create `tests/sdd/test-compaction-reread.sh`:

```bash
#!/usr/bin/env bash
# The re-read-after-compaction paragraph must exist in SDD and brainstorming
# and must end well inside the first 20,000 characters, which is what Claude
# Code keeps when it re-attaches a skill after a compaction.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
BRAIN="$REPO_ROOT/skills/brainstorming/SKILL.md"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# check FILE NEEDLE NEXT_HEADING LABEL: needle present, ends before 5,000
# characters, and sits before NEXT_HEADING.
check() {
  local file="$1" needle="$2" next="$3" label="$4" res
  res="$(node -e '
    const fs = require("fs");
    const s = fs.readFileSync(process.argv[1], "utf8");
    const i = s.indexOf(process.argv[2]);
    const h = s.indexOf(process.argv[3]);
    if (i < 0) { console.log("missing"); process.exit(0); }
    const end = i + process.argv[2].length;
    console.log(end <= 5000 && h > end ? "ok" : `bad end=${end} heading=${h}`);
  ' "$file" "$needle" "$next")"
  [ "$res" = "ok" ] && pass "$label" || fail "$label ($res)"
}

check "$SDD" "Before resuming work after any compaction, Read this file in full, then the ledger, along with any other skill you are following whose re-attached copy is cut short." "## When to Use" "SDD re-read paragraph present, early, before When to Use"
check "$BRAIN" "Before resuming work after any compaction, Read this file in full, along with any other skill you are following whose re-attached copy is cut short." "## Three Paths" "brainstorming re-read paragraph present, early, before Three Paths"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/sdd/test-compaction-reread.sh`
Expected: two `[FAIL] ... (missing)` lines, `2 FAILURES`, exit 1.

- [ ] **Step 3: Insert the SDD paragraph**

In `skills/subagent-driven-development/SKILL.md`, after the paragraph that starts `**Continuous execution:**` and its trailing blank line, and before `## When to Use`, insert this paragraph followed by one blank line:

```markdown
**After a context compaction:** a re-attached copy of this skill can be cut short (Claude Code keeps its first 20,000 characters, which ends partway through the task loop). Before resuming work after any compaction, Read this file in full, then the ledger, along with any other skill you are following whose re-attached copy is cut short.
```

- [ ] **Step 4: Insert the brainstorming paragraph**

In `skills/brainstorming/SKILL.md`, after the line that starts `**REQUIRED SUB-SKILL:**` and its trailing blank line, and before `## Three Paths`, insert this paragraph followed by one blank line:

```markdown
**After a context compaction:** a re-attached copy of this skill can be cut short (Claude Code keeps its first 20,000 characters, which ends before the spec-writing steps). Before resuming work after any compaction, Read this file in full, along with any other skill you are following whose re-attached copy is cut short.
```

- [ ] **Step 5: Run the tests**

Run each in its own call:
```bash
bash tests/sdd/test-compaction-reread.sh
bash tests/sdd/test-sdd-contract.sh
```
Expected: both exit 0 with `ALL PASS` (or the contract test's own all-pass line) and no FAIL line.

- [ ] **Step 6: Lint and commit**

```bash
scripts/lint-shell.sh tests/sdd/test-compaction-reread.sh
git add skills/subagent-driven-development/SKILL.md skills/brainstorming/SKILL.md tests/sdd/test-compaction-reread.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(sdd,brainstorming): re-read the full skill after a context compaction"
```

---

### Task 10: GREEN campaign (treatment arm) and evidence note

**Risk tier:** standard — produces the evidence the skill change ships on.

**Files:**
- Modify (evals): `evidence/2026-11-03-cost-reduction-6-16-2/manifest-red.tsv`, `manifest-green.tsv` (the `treatment` pin row)
- Create (evals): `evidence/2026-11-03-cost-reduction-6-16-2/task-10-runs/treatment/...`, `logs/treatment-*.log`, `tally.txt`
- Create (hyperpowers worktree): `docs/hyperpowers/2026-11-03-cost-reduction-6-16-2-eval-evidence.md`

- [ ] **Step 1: Pin the treatment**

The release worktree must be clean at Task 9's commit. Write `git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/cost-6-16-2 rev-parse HEAD` into the `treatment` row of both manifests and commit that change in the evals repo with the realval scan (an evidence-path change; the harness pin stays valid).

- [ ] **Step 2: Launch the wave**

Same as Task 8 Step 1 with `manifest-green.tsv`, `logs/launch-green.out` and `logs/launch-green.exit`. Do not commit anything to the release worktree while the wave runs: the launcher checks that the treatment root is clean at its pin.

- [ ] **Step 3: Tally, replace voids, re-tally**

`python3 evidence/2026-11-03-cost-reduction-6-16-2/tally.py > evidence/2026-11-03-cost-reduction-6-16-2/tally.txt`, replacing treatment voids exactly as Task 8 Step 2 did for the control (proc `r1`-`r3`, `MANIFEST` set to `manifest-green.tsv`, one `sentinel-reruns.tsv` row each), then re-tally.

- [ ] **Step 4: Read the pass bar**

`tally.txt` ends with the three bar readings. If any reads `FAIL`, stop and report BLOCKED with `tally.txt`: the paragraph wording is a skill change the human partner decides on, not something to tune silently. If any reads `INCOMPLETE` after the replacement cap, report the actual n to the human partner before Task 11.

- [ ] **Step 5: Copy runs and commit (evals)**

Copy every treatment run into `task-10-runs/treatment/` per `evidence/README.md`, then commit, by explicit path, `task-10-runs/`, the `logs/treatment-*.log` files, `logs/launch-green.out`, `logs/launch-green.exit`, `tally.txt` and `sentinel-reruns.tsv` with the realval scan. `git status --short evidence/2026-11-03-cost-reduction-6-16-2` must print nothing afterwards.

- [ ] **Step 6: Write the evidence note (hyperpowers)**

Create `docs/hyperpowers/2026-11-03-cost-reduction-6-16-2-eval-evidence.md` with the headings of `docs/hyperpowers/2026-10-03-communication-skill-eval-evidence.md`: Scenarios; RED: control arm (v6.16.1); GREEN: treatment arm (release branch); REFACTOR (none, or what changed and why); Not measured (writing-skills, deferred; field cost savings, measured two weeks after the settings change). Give per arm and scenario: valid n, voids by kind, outcome passes, mechanism passes, the smoke findings (compaction position, the 20,000-character truncation), Claude Code version, models, the harness, control and treatment pins, and the evidence path `evals/evidence/2026-11-03-cost-reduction-6-16-2/`. Commit on the release branch:

```bash
cd /Users/johnss51/Development/agents/hyperpowers/.worktrees/cost-6-16-2
git add docs/hyperpowers/2026-11-03-cost-reduction-6-16-2-eval-evidence.md
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(hyperpowers): eval evidence for the 6.16.2 re-read paragraphs"
```

---
### Task 11: Release 6.16.2

**Risk tier:** standard — version bump, changelog and tag for a shipped release.

**Files:**
- Modify: `CHANGELOG.md` (new entry above `## 6.16.1`)
- Modify (by vrzn): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json`

**Mirror:** `CHANGELOG.md:5-10`.

- [ ] **Step 1: Write the changelog entry**

Above `## 6.16.1 (2026-10-19)`, add `## 6.16.2 (<today's date>)`, one summary sentence ("Three changes cut the cost of long sessions without changing what the skills do."), then three bullets in the `- **Bold lead-in.** ...` style: the re-read paragraph (with the campaign's valid n and pass counts per arm and scenario as indented sub-bullets, and the evidence note path), `gate-wait` (one call watches every lens; the 16-minute cap is unchanged), and the README cost section (the recommended window and why the one-hour cache stays).

- [ ] **Step 2: Bump the version**

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn get
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump patch --dry-run
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump patch -y
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn get
```

Expected: the first `get` reports 6.16.1; the dry run previews 6.16.1 to 6.16.2 for six files and writes nothing; after `-y`, the last `get` reports 6.16.2 everywhere.

- [ ] **Step 3: Run the offline suite set**

Run the whole offline set defined at `docs/testing.md:51-57`: every `test-*.sh` outside `tests/claude-code/` and `tests/explicit-skill-requests/` (excluding `tests/opencode/test-tools.sh` and `tests/opencode/test-priority.sh`), the four offline `tests/claude-code/` suites named in the `docs/testing.md` table, `npm test` in `tests/brainstorm-server/`, the `windows-lifecycle.test.sh` test, and the Pi Node file. Use one `bash` call per suite, or the fail-closed loop at `docs/testing.md:45-49` written to a bash script file (not an inline zsh loop). Expected: every suite exits 0. Do not run the live suites (the rest of `tests/claude-code/` and `tests/explicit-skill-requests/`): they spawn the real `claude` CLI.

- [ ] **Step 4: Commit and tag**

```bash
git add CHANGELOG.md package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "chore(release): 6.16.2"
git tag -a v6.16.2 -m "hyperpowers 6.16.2"
```

- [ ] **Step 5: Install locally**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install checkout --detach v6.16.2
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install sparse-checkout list
```

Expected: the checkout reports HEAD at v6.16.2; the sparse patterns still read `/*` and `!/docs/`. Tell the human partner to run `/reload-plugins`. Do not push the branch or the tag, and do not merge into `main`.

---

## After the plan (controller, not a task)

- Report to the human partner: the release tag, the campaign result, and the merge-forward step that waits for their go-ahead (main's SDD is 58,280 characters and gets the same paragraph after its opening; the forward merge runs `main`'s `decisions-compile` for this spec and removes this plan there).
- With the standing approval from 2026-11-03: add `"autoCompactWindow": 400000` to `~/.claude/settings.json`; leave `ENABLE_PROMPT_CACHING_1H=1` and the model pins unchanged.
- Remove `/Users/johnss51/.cache/hyperpowers/cost-6162/hp-6161` with `git worktree remove` once the campaign evidence is committed.
- Field follow-up (spec, After the release): record the date the setting landed in memory, and tell the human partner the follow-up is due 14 days later. On or after that date, the controller of that session runs, from `~/.cache/hyperpowers/cost-investigation/` with the sandbox off (the scan's process pool needs it): `python -s scan.py home-followup.pkl <setting date>` then `python -s analyze.py <setting date> <setting date + 14 days> home-followup.pkl > report-followup.txt`, and compares against `report-home.txt` (the October baseline): average main-thread context, cost per call by model, compaction count, and the share of main-thread cost above 300K tokens. It writes the comparison to `followup-<date>.md` in that directory and reports it to the human partner.
