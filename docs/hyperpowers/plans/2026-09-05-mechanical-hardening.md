# Mechanical Hardening (Part 1 of 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-09-05-gate-churn-and-skill-hardening-design.md`

**Goal:** Fix every defect from the 2026-09-05 gate-churn analysis and skills audit whose correctness an offline suite can prove, and release it so Part 2's live evals measure against a clean baseline.

**Architecture:** Fifteen independent tasks over four surfaces: the gate's approval script and its telemetry reader, the session-start hook and its polyglot wrapper, the two SDD helper scripts, and skill/doc prose whose claims contradict shipped code. Every behavioral change gets an assertion in an existing bash suite; two tasks add new suites. No task depends on another's output, so they may execute in any order, but Task 15 (release) must run last.

**Tech Stack:** Bash 3.2+ (macOS default), Node.js (already required by the gate scripts), Markdown. No new dependencies.

## Global Constraints

- Zero new third-party dependencies. The only permitted external tool remains `codex-plugin-cc`, and every gate path must still degrade cleanly when it is absent.
- No emojis in code, documentation, commit messages, or reports.
- No `Co-Authored-By` lines and no text implying AI-generated assistance, in commits or file content.
- Never run `git reset --hard`, `git clean`, `git checkout -- <path>`, or any force-push. To restore a tracked file, use `git show HEAD:<path> > <path>`.
- Do not push. Committing is expected; pushing is a separate instruction from the human partner.
- Heredocs are banned in `hooks/` executables (bash 5.1+ deadlock, upstream issue #571). Use `printf`.
- Bash must stay macOS-compatible: no `cat -A`, no GNU-only `sed -i` form, no `readarray`.
- Every gate section file under `skills/requesting-code-review/` is covered by a losslessness proof. Any edit to one of `gate-preflight.md`, `gate-setup.md`, `gate-lenses.md`, `recipe-document.md`, `recipe-code.md`, `gate-output-schema.md`, `gate-findings.md`, `gate-fix-loop.md`, `gate-sweep.md` MUST add a row to `tests/codex-review-gate/gate-post-split-edits.tsv` or `tests/codex-review-gate/test-gate-split-lossless.sh` fails. No task in this plan edits one of those nine files.
- Version bumps use `vrzn`. Never hand-edit a version string.
- This repository commits its `docs/hyperpowers/` specs and plans. That is a deliberate local exception; do not add `docs/hyperpowers` to `.gitignore`.

---

### Task 1: verdict-normalize approves needs-attention with no blocking findings

**Risk tier:** high — `verdict-normalize` is the gate's only approval authority; the rubric names it explicitly.

**Files:**
- Modify: `skills/requesting-code-review/scripts/verdict-normalize:55-73`
- Test: `tests/codex-review-gate/test-verdict-normalize.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: no new callable interface. The stdout contract is unchanged in shape — `{"result":"approved|blocking|incomplete","verdict":"approve|needs-attention|none","blockingCount":N,"reason":"..."}` — but the JSON path can now emit `{"result":"approved","verdict":"needs-attention",...}`, which no previous version produced. Task 13's telemetry reader does not read this output.

**Context the implementer needs.** The script accepts two payload shapes. A code-gate `--json` payload is parsed by `fromStructured`, which reads a `findings[]` array with a `severity` field. A document-gate text payload is parsed by `parseText`, which counts findings inside a literal `Blocking Findings:` section. **Only `fromStructured` changes in this task.** The text path is deliberately untouched: in the document shape, placing a finding under `Blocking Findings:` is the reviewer's explicit judgment that it blocks, and a severity field should not override it. Do not modify `parseText`.

- [ ] **Step 1: Write the failing tests**

Open `tests/codex-review-gate/test-verdict-normalize.sh`. Find this existing block (it currently ends at the line asserting `"blockingCount":1`):

```bash
check "$work/blocking.json" '"result":"blocking"' "json needs-attention -> blocking"
check "$work/blocking.json" '"blockingCount":1' "json counts only critical/high"
```

Insert the following immediately after those two lines:

```bash
# spec D2: needs-attention whose findings are all below the blocking bar is an
# approval with notes — "Blocking = Critical + Important" (gate-findings.md).
cat > "$work/na-minor.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "needs-attention",
    "findings": [ { "severity": "medium", "title": "untested path" },
                  { "severity": "low", "title": "nit" } ] },
  "rawOutput": "..." } } }
EOF
check "$work/na-minor.json" '"result":"approved"' "json needs-attention with only medium/low -> approved"
check "$work/na-minor.json" '"verdict":"needs-attention"' "approved-with-notes keeps the reviewer's verdict"
check "$work/na-minor.json" '"blockingCount":0' "approved-with-notes reports zero blocking"
check "$work/na-minor.json" '2 non-blocking' "reason names the non-blocking count"

# spec D3: needs-attention with no findings at all is an unfinished review,
# not an approval — 37 measured task captures were interim narration.
cat > "$work/na-empty.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "needs-attention", "findings": [] },
  "rawOutput": "I'm checking whether that gap is covered elsewhere" } } }
EOF
check "$work/na-empty.json" '"result":"incomplete"' "json needs-attention with no findings -> incomplete"

# An unrecognized verdict string may never reach the new approval path.
cat > "$work/na-unknown.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "reject", "findings": [ { "severity": "low", "title": "nit" } ] },
  "rawOutput": "..." } } }
EOF
check "$work/na-unknown.json" '"result":"blocking"' "unknown verdict with only low findings stays blocking"
```

Then find the `--require-coverage` section (the block using the `checkc` helper, after the comment `# needs-attention unaffected by the flag`). Insert this after the line `checkc "$work/needs.txt" '"result":"blocking"' "flag: needs-attention unaffected"`:

```bash
# spec D3: the coverage floor governs the D2 approval exactly as it governs an
# ordinary approve — a way to be incomplete, never a way to approve.
checkc "$work/na-minor.json" '"result":"incomplete"' "flag: approved-with-notes without coverage -> incomplete"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh`

Expected: FAIL. The three `na-minor.json` result assertions report `"result":"blocking"`, the reason assertion finds no `2 non-blocking` substring, and `na-empty.json` reports `"result":"blocking"` instead of `"result":"incomplete"`. The `na-unknown.json` and `checkc` assertions may already pass; that is fine, they are regression fences.

- [ ] **Step 3: Rewrite `fromStructured`**

In `skills/requesting-code-review/scripts/verdict-normalize`, replace the whole `fromStructured` function (currently lines 54-73, from the comment `// Reduce a structured verdict object` through the closing `};`) with:

```js
  // Reduce a structured verdict object ({verdict, findings[]}) to the tri-state.
  const fromStructured = (v, source, raw) => {
    if (!v || typeof v.verdict !== "string") return false;
    const findings = Array.isArray(v.findings) ? v.findings : [];
    const blocking = findings.filter(f => f && /^(critical|high)$/i.test(String(f.severity || ""))).length;
    // Coverage is satisfied if EITHER the raw markdown has a Coverage heading
    // (text path), OR the structured payload summary field contains a
    // Coverage: run (structured path). Governs every approval this function
    // can produce, including the needs-attention-with-no-blocking one.
    const coverageMissing = () => {
      if (!requireCoverage) return false;
      const rawCoverageOk = coverageOk(raw || "");
      const summaryCoverageOk = typeof v.summary === "string" && /(?:^|[\s;.…)\-—"\x27(])Coverage:\s*\S/.test(v.summary);
      return !rawCoverageOk && !summaryCoverageOk;
    };
    if (v.verdict === "approve" && blocking === 0) {
      if (coverageMissing())
        out("incomplete", "approve", 0, source + ": approve without coverage evidence");
      out("approved", "approve", 0, source + ": approve, no blocking findings");
    }
    if (v.verdict === "approve") out("blocking", "approve", blocking, source + ": contradictory approve with blocking findings");
    // spec D2/D3. The written contract is "Blocking = Critical + Important"
    // (gate-findings.md), so a needs-attention carrying only medium/low
    // findings has raised nothing the fix loop is chartered to fix: it is an
    // approval with notes, and the findings still travel in the payload for
    // the round ledger. A needs-attention carrying NO findings at all is not a
    // verdict about the code but an unfinished review, so it fails closed to
    // incomplete. Restricted to the exact string "needs-attention" so an
    // unrecognized verdict can never reach an approval. The text path
    // (parseText) is deliberately excluded: there, placing a finding under
    // "Blocking Findings:" is the blocking judgment of the reviewer.
    if (v.verdict === "needs-attention" && blocking === 0) {
      if (findings.length === 0)
        out("incomplete", "needs-attention", 0, source + ": needs-attention with no findings");
      if (coverageMissing())
        out("incomplete", "needs-attention", 0, source + ": needs-attention without coverage evidence");
      out("approved", "needs-attention", 0, source + ": needs-attention, no blocking findings (" + findings.length + " non-blocking)");
    }
    out("blocking", "needs-attention", blocking, source + ": " + v.verdict);
    return true;
  };
```

- [ ] **Step 4: Update the script's header contract**

Replace lines 5-8 of the same file (the header comment block running from `# shape) or a code-gate --json payload, and reduces it to a tri-state` through `# approve-with-blocking-findings case is "blocking" (conservative).`) with:

```
# shape) or a code-gate --json payload, and reduces it to a tri-state
# (spec 4.5). Fail-closed: anything without a parseable verdict is
# "incomplete", and incomplete is never approval. The contradictory
# approve-with-blocking-findings case is "blocking" (conservative). On the
# JSON path a "needs-attention" carrying only medium/low findings is
# "approved" with those findings reported, and one carrying no findings at
# all is "incomplete" (2026-09-05 spec, D2/D3).
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh`

Expected: `STATUS: PASSED`. Every pre-existing assertion must still pass, including `"needs-attention with zero blocking -> blocking"` — that fixture is `mirror.txt`, a text payload, and the text path is unchanged.

- [ ] **Step 6: Run the neighbouring gate suites**

Run each and expect `STATUS: PASSED`:

```bash
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/codex-review-gate/test-gate-round.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
```

- [ ] **Step 7: Commit**

```bash
git add skills/requesting-code-review/scripts/verdict-normalize tests/codex-review-gate/test-verdict-normalize.sh
git commit -m "fix(gate): needs-attention over medium findings blocked a loop chartered for critical and important"
```

---

### Task 2: session-start announces a newer plugin version

**Risk tier:** standard — new logic inside the hook that injects every session's bootstrap; a failure here silences all skills.

**Files:**
- Modify: `hooks/session-start:79` (insert a new block after the ungated-notice block's closing `# ---` rule)
- Test: `tests/hooks/test-session-start.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks call. The block appends to the existing shell variable `session_context`, the same variable the ungated notice at lines 62-78 appends to.

**Context the implementer needs.** Releases 6.10.0 through 6.11.1 never loaded in any session because the plugin cache went stale and nothing said so. `PLUGIN_ROOT` is already computed at line 8 and points at the plugin copy this session actually loaded. The marketplace clone that `/plugin` refreshes lives at `~/.claude/plugins/marketplaces/hyperpowers/`, and its `.claude-plugin/marketplace.json` carries a `plugins` array whose `hyperpowers` entry has the published `version`. The notice must be silent unless the marketplace version is strictly newer, so a contributor running from the repo (whose version leads the marketplace) is never nagged.

The notice text is appended to `session_context` raw, exactly like `ungated_notice`. `session_context` is later interpolated into JSON by `printf`, and only `using_hyperpowers_content` goes through `escape_for_json`. The notice therefore MUST NOT contain a double quote, a backslash, or a newline.

- [ ] **Step 1: Write the failing tests**

Append the following to `tests/hooks/test-session-start.sh`, immediately BEFORE the final `if [[ "$FAILURES" -gt 0 ]]; then` block:

```bash
# --- plugin version staleness notice (spec D4) ------------------------------
# The running version is this repo's .claude-plugin/plugin.json; the test writes
# a marketplace manifest under the sandboxed HOME and varies only its version.
running_version="$(node -e 'console.log(require(process.argv[1]).version)' "$REPO_ROOT/.claude-plugin/plugin.json")"

write_marketplace() { # <home> <version>
    local mdir="$1/.claude/plugins/marketplaces/hyperpowers/.claude-plugin"
    mkdir -p "$mdir"
    printf '{"name":"hyperpowers","owner":{"name":"t"},"plugins":[{"name":"hyperpowers","source":"./","version":"%s"}]}\n' \
        "$2" > "$mdir/marketplace.json"
}

stale_home="$(make_home version-stale)"
write_marketplace "$stale_home" "99.0.0"
assert_command_output \
    "SessionStart announces a strictly newer marketplace version" \
    "nested" \
    "hyperpowers 99.0.0 is available"$'\037'"this session loaded ${running_version}" \
    "" \
    "$stale_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

current_home="$(make_home version-current)"
write_marketplace "$current_home" "$running_version"
assert_command_output \
    "SessionStart is silent when the marketplace version matches" \
    "nested" \
    "" \
    "is available" \
    "$current_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

ahead_home="$(make_home version-ahead)"
write_marketplace "$ahead_home" "0.0.1"
assert_command_output \
    "SessionStart is silent when the running version leads the marketplace" \
    "nested" \
    "" \
    "is available" \
    "$ahead_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

absent_home="$(make_home version-no-marketplace)"
assert_command_output \
    "SessionStart is silent with no marketplace clone" \
    "nested" \
    "" \
    "is available" \
    "$absent_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"

corrupt_home="$(make_home version-corrupt-marketplace)"
mkdir -p "$corrupt_home/.claude/plugins/marketplaces/hyperpowers/.claude-plugin"
printf 'not json at all' > "$corrupt_home/.claude/plugins/marketplaces/hyperpowers/.claude-plugin/marketplace.json"
assert_command_output \
    "SessionStart survives an unparseable marketplace manifest" \
    "nested" \
    "You have superpowers" \
    "is available" \
    "$corrupt_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash "$HOOK_UNDER_TEST"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/hooks/test-session-start.sh`

Expected: FAIL on `SessionStart announces a strictly newer marketplace version` (the notice does not exist yet). The four silence assertions pass vacuously; they are the fences that keep the fix from over-firing.

- [ ] **Step 3: Add the notice block to the hook**

In `hooks/session-start`, find the line `# ---------------------------------------------------------------------------` that closes the ungated-work notice block (line 79, immediately before the blank line and `# Output context injection as JSON.`). Insert this block after it:

```bash

# --- Plugin version staleness notice (spec D4) ------------------------------
# Releases 6.10.0-6.11.1 never loaded in a single session: the plugin cache
# went stale and nothing said so. Compare the manifest this session actually
# loaded against the marketplace clone's, and speak one line only when the
# marketplace is strictly newer — a contributor running ahead of the
# marketplace is never nagged. Never updates anything, never fails the hook.
# The text carries no quote, backslash, or newline: it is appended to
# session_context raw and interpolated into JSON by printf below.
version_notice="$(
  ( set +e
    running="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
    market="${HOME:-}/.claude/plugins/marketplaces/hyperpowers/.claude-plugin/marketplace.json"
    [ -f "$running" ] && [ -f "$market" ] || exit 0
    command -v node >/dev/null 2>&1 || exit 0
    node -e '
      const fs = require("fs");
      const read = (p) => { try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) { return null; } };
      const cur = read(process.argv[1]), mkt = read(process.argv[2]);
      if (!cur || !mkt) process.exit(0);
      const list = Array.isArray(mkt.plugins) ? mkt.plugins : [];
      const entry = list.find((p) => p && p.name === "hyperpowers");
      const a = String(cur.version || "");
      const b = String((entry && entry.version) || mkt.version || "");
      const tri = (s) => { const m = /^(\d+)\.(\d+)\.(\d+)/.exec(s); return m ? [+m[1], +m[2], +m[3]] : null; };
      const x = tri(a), y = tri(b);
      if (!x || !y) process.exit(0);
      const newer = (p, q) => { for (let i = 0; i < 3; i++) if (p[i] !== q[i]) return p[i] > q[i]; return false; };
      if (!newer(y, x)) process.exit(0);
      process.stdout.write("hyperpowers " + b + " is available; this session loaded " + a + ". Run /plugin and restart to pick it up.");
    ' "$running" "$market" 2>/dev/null
  ) 2>/dev/null
)" || version_notice=""
if [ -n "$version_notice" ]; then
  session_context="${session_context}\n\n${version_notice}"
fi
# ---------------------------------------------------------------------------
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/hooks/test-session-start.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 5: Run the sibling hook suites**

Run each and expect `STATUS: PASSED`:

```bash
bash tests/hooks/test-ungated-notice.sh
bash tests/hooks/test-broker-janitor.sh
```

- [ ] **Step 6: Verify the hook still emits valid JSON in this repo**

Run: `CLAUDE_PLUGIN_ROOT="$PWD" bash hooks/session-start | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8")); console.log("valid JSON")'`

Expected: `valid JSON`.

- [ ] **Step 7: Commit**

```bash
git add hooks/session-start tests/hooks/test-session-start.sh
git commit -m "feat(hooks): three releases shipped without ever loading in a session"
```

---

### Task 3: replace the run-hook heredoc with label lines and fence the class

**Risk tier:** standard — the wrapper is the entry point for every hook on Windows; a syntax error there disables the bootstrap.

**Files:**
- Modify: `hooks/run-hook.cmd:1-45` (whole file)
- Create: `tests/hooks/test-no-heredocs-in-hooks.sh`
- Modify: `docs/windows/polyglot-hooks.md`
- Modify: `docs/porting-to-a-new-harness.md`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks call. The wrapper's command-line contract is unchanged: `run-hook.cmd <script-name> [args...]` execs `bash <hooks-dir>/<script-name> [args...]`.

**Context the implementer needs.** This is a port of upstream Superpowers commit `d80fc18`. bash 5.1 and newer write a heredoc into a pipe before forking; under macOS pipe pressure the kernel hands out 512-byte pipes and this file's 1.4 KB `CMDBLOCK` heredoc deadlocks every hook. The replacement uses `:;` label lines, which parse in both interpreters: `cmd.exe` treats a line starting with `:` as a label and skips it, while a POSIX shell runs `:` as a no-op and then `exec`s away before reaching the batch block. The current file is the only heredoc anywhere in `hooks/`; the new test keeps it that way.

Upstream's exact replacement text for the first line and the header comment is reproduced below. Adapt nothing except keeping the fork's existing batch body byte-for-byte.

- [ ] **Step 1: Write the failing fence test**

Create `tests/hooks/test-no-heredocs-in-hooks.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Heredocs are banned in hooks/ executables. bash 5.1+ delivers a heredoc via a
# pre-fork pipe write; under macOS pipe pressure the kernel hands out 512-byte
# pipes and the write deadlocks, hanging every hook in the session. See
# https://github.com/obra/superpowers/issues/571. printf is the replacement.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "=== hooks heredoc fence ==="
echo ""

offenders=""
for f in "$REPO_ROOT"/hooks/*; do
    [ -f "$f" ] || continue
    # `<<` opens a heredoc; `<<<` is a here-string and writes no pipe.
    if grep -Eq '<<[^<]' "$f"; then
        offenders="$offenders $(basename "$f")"
    fi
done

if [ -z "$offenders" ]; then
    pass "no hooks/ file opens a heredoc"
else
    fail "heredoc found in hooks/:$offenders"
fi

# The wrapper must still be a working Unix launcher.
probe="$(mktemp -d)"
trap 'rm -rf "$probe"' EXIT
cp "$REPO_ROOT/hooks/run-hook.cmd" "$probe/run-hook.cmd"
printf '#!/usr/bin/env bash\nprintf "ran:%%s\\n" "$1"\n' > "$probe/probe-hook"
chmod +x "$probe/run-hook.cmd" "$probe/probe-hook"

if out="$(bash "$probe/run-hook.cmd" probe-hook arg1 2>&1)" && [ "$out" = "ran:arg1" ]; then
    pass "wrapper execs the named script with its arguments"
else
    fail "wrapper exec (got: ${out:-<empty>})"
fi

if out="$(bash "$probe/run-hook.cmd" 2>&1)" && [ -z "$out" ]; then
    pass "wrapper exits 0 silently with no script name"
else
    fail "wrapper with no arguments (got: ${out:-<empty>})"
fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/hooks/test-no-heredocs-in-hooks.sh`

Expected: FAIL on `heredoc found in hooks/: run-hook.cmd`, and FAIL on `wrapper exits 0 silently with no script name` (today the batch guard never runs on Unix, so bash reaches the tail and execs a script named by an unset `$1`). The `wrapper execs the named script` assertion passes already.

- [ ] **Step 3: Replace the wrapper's head and tail**

In `hooks/run-hook.cmd`, replace line 1 (`: << 'CMDBLOCK'`) with these four lines:

```
:; command -v bash >/dev/null 2>&1 || exit 0
:; [ $# -ge 1 ] || exit 0
:; SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
:; SCRIPT_NAME="$1"; shift; exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
```

Then replace the two comment lines that currently read:

```
REM On Windows: cmd.exe runs the batch portion, which finds and calls bash.
REM On Unix: the shell interprets this as a script (: is a no-op in bash).
```

with:

```
REM On Unix: POSIX shells execute the ":;" lines above and exec away before
REM reaching this batch block (":" is a no-op; cmd.exe treats lines starting
REM with ":" as labels and skips them). If bash or the script name is
REM missing, the wrapper exits 0 silently - hooks are optional context, never
REM a session breaker.
REM On Windows: cmd.exe runs this batch portion, which finds and calls bash.
REM
REM Heredocs are banned in this file and every hooks/ executable: bash 5.1+
REM delivers them via a pre-fork pipe write that deadlocks on macOS under
REM pipe pressure (issue #571). tests/hooks/test-no-heredocs-in-hooks.sh is
REM the fence.
```

Finally delete the file's last seven lines, which are the closing `CMDBLOCK` marker and the Unix tail it guarded:

```
CMDBLOCK

# Unix: run the named script directly
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"
shift
exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
```

The file must now end with `exit /b 0` and a trailing newline.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/hooks/test-no-heredocs-in-hooks.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 5: Verify the real hooks still run through the wrapper**

Run: `CLAUDE_PLUGIN_ROOT="$PWD" bash hooks/run-hook.cmd session-start | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8")); console.log("valid JSON")'`

Expected: `valid JSON`.

Run: `bash tests/hooks/test-session-start.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 6: Update the two docs that describe the old mechanism**

In `docs/windows/polyglot-hooks.md`, find the passage describing the heredoc mechanism (the `: << 'CMDBLOCK'` explanation, around lines 64-100) and replace the mechanism description with:

```markdown
The wrapper opens with four `:;` label lines:

```
:; command -v bash >/dev/null 2>&1 || exit 0
:; [ $# -ge 1 ] || exit 0
:; SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
:; SCRIPT_NAME="$1"; shift; exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
```

`cmd.exe` reads a line beginning with `:` as a label and skips it, so Windows
falls straight through to the `@echo off` batch block. A POSIX shell runs `:`
as a no-op, evaluates the rest of each line, and `exec`s bash on the named
hook before it ever reaches the batch text.

This replaced an earlier `: << 'CMDBLOCK'` heredoc that wrapped the batch
block. bash 5.1 and newer write a heredoc into a pipe before forking; under
macOS pipe pressure the kernel hands out 512-byte pipes and the wrapper's
1.4 KB block deadlocked every hook
([obra/superpowers#571](https://github.com/obra/superpowers/issues/571)).
Heredocs are now banned throughout `hooks/`, with
`tests/hooks/test-no-heredocs-in-hooks.sh` as the fence.

Both missing-bash and missing-script-name exit 0 silently. Hooks supply
optional context; a wrapper that errors is worse than one that says nothing.
```

In `docs/porting-to-a-new-harness.md`, find every sentence describing the wrapper as heredoc-based and replace the mechanism phrase with `four leading `:;` label lines (a no-op in POSIX shells, a skipped label in cmd.exe)`. Locate them with:

```bash
grep -n 'CMDBLOCK\|heredoc' docs/porting-to-a-new-harness.md
```

- [ ] **Step 7: Confirm no doc still describes the retired mechanism**

Run: `grep -rn "CMDBLOCK" docs/ hooks/ || echo "no CMDBLOCK references remain"`

Expected: `no CMDBLOCK references remain`.

- [ ] **Step 8: Commit**

```bash
git add hooks/run-hook.cmd tests/hooks/test-no-heredocs-in-hooks.sh docs/windows/polyglot-hooks.md docs/porting-to-a-new-harness.md
git commit -m "fix(hooks): the wrapper's own heredoc could deadlock every hook it exists to launch"
```

---

### Task 4: review-package rejects empty and non-descendant ranges

**Risk tier:** standard — the review package is the reviewer's only view of the diff; a silent empty one lets a reviewer approve work that is not there.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/review-package:27` (insert after the HEAD validation)
- Test: `tests/claude-code/test-sdd-dir-path.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a new exit code. `review-package` already exits 2 for usage and bad-ref errors; it now exits 3 for a range problem, so a caller can tell "you passed nonsense" from "your BASE..HEAD is not a real range".

**Context the implementer needs.** Port of upstream commit `99f9f00`. When an SDD implementer commits to the wrong branch, the recorded BASE and the current HEAD no longer form a rooted, non-empty range. Today `review-package` writes a package anyway, and an empty one reads to a reviewer as clean work.

- [ ] **Step 1: Write the failing tests**

Append to `tests/claude-code/test-sdd-dir-path.sh`, immediately BEFORE the final `if [ "$failures" -gt 0 ]` block:

```bash
echo ""
echo "Test: review-package rejects ranges that cannot describe a task's work"
make_repo "$TEST_ROOT/repo-range"
mkdir -p "$TEST_ROOT/repo-range/docs"
echo plan > "$TEST_ROOT/repo-range/docs/plan.md"
git -C "$TEST_ROOT/repo-range" add -A
git -C "$TEST_ROOT/repo-range" commit -qm "base"
range_base=$(git -C "$TEST_ROOT/repo-range" rev-parse HEAD)
echo more >> "$TEST_ROOT/repo-range/docs/plan.md"
git -C "$TEST_ROOT/repo-range" commit -qam "work"
range_head=$(git -C "$TEST_ROOT/repo-range" rev-parse HEAD)

rc=0
( cd "$TEST_ROOT/repo-range" && bash "$REVIEW_PACKAGE" docs/plan.md "$range_head" "$range_head" ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 3 ]; then pass "empty commit range exits 3"; else fail "empty commit range exits 3 (got rc=$rc)"; fi

rc=0
( cd "$TEST_ROOT/repo-range" && bash "$REVIEW_PACKAGE" docs/plan.md "$range_head" "$range_base" ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 3 ]; then pass "non-descendant HEAD exits 3"; else fail "non-descendant HEAD exits 3 (got rc=$rc)"; fi

rc=0
( cd "$TEST_ROOT/repo-range" && bash "$REVIEW_PACKAGE" docs/plan.md "$range_base" "$range_head" ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then pass "a real range still produces a package"; else fail "a real range still produces a package (got rc=$rc)"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`

Expected: FAIL on `empty commit range exits 3 (got rc=0)` and `non-descendant HEAD exits 3 (got rc=0)`. The third assertion passes.

- [ ] **Step 3: Add the guards**

In `skills/subagent-driven-development/scripts/review-package`, insert this after line 27 (the `bad HEAD` validation) and before the blank line preceding `if [ $# -eq 4 ]; then`:

```bash

# Range guards (exit 3): a wrong-branch HEAD yields a range that is empty or
# not rooted at BASE; either would silently produce a bogus review package,
# and an empty one reads to a reviewer as clean work that was never done.
git merge-base --is-ancestor "$base" "$head" || { echo "HEAD is not a descendant of BASE: ${base}..${head}" >&2; exit 3; }
[ "$(git rev-list --count "${base}..${head}")" -gt 0 ] || { echo "empty commit range: ${base}..${head}" >&2; exit 3; }
```

- [ ] **Step 4: Update the script's usage comment**

In the same file, replace line 7 (`# Usage: review-package PLAN_FILE BASE HEAD [OUTFILE]`) with:

```
# Usage: review-package PLAN_FILE BASE HEAD [OUTFILE]
# Exit 2: usage or unresolvable ref. Exit 3: BASE..HEAD is empty or HEAD is
# not a descendant of BASE (a wrong-branch commit, upstream #2050).
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 6: Run the SDD contract suite**

Run: `bash tests/sdd/test-sdd-contract.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/scripts/review-package tests/claude-code/test-sdd-dir-path.sh
git commit -m "fix(sdd): an empty review package reads to a reviewer as clean work"
```

---

### Task 5: SDD helpers invoke sdd-dir through bash

**Risk tier:** low — two one-line changes whose complete replacement text is in this task, plus one test whose full body is here.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/review-package:32`
- Modify: `skills/subagent-driven-development/scripts/task-brief:26`
- Test: `tests/claude-code/test-sdd-dir-path.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing. Both helpers' stdout and exit codes are unchanged.

**Context the implementer needs.** Port of upstream commit `0be4987`. Some archive extractors, notably Python's `zipfile`, discard Unix mode bits when unpacking a marketplace package. The helpers then fail with `Permission denied` and rc=126 when they exec their sibling. Invoking through `bash` makes the exec bit irrelevant. This repo's packaging preserves 0755, so no packaging change can reach the defect: it happens on the consumer's machine. The fork's helper is named `sdd-dir`, not upstream's `sdd-workspace`, and both scripts already hold the directory in `SCRIPT_DIR`.

- [ ] **Step 1: Write the failing test**

Append to `tests/claude-code/test-sdd-dir-path.sh`, immediately BEFORE the final `if [ "$failures" -gt 0 ]` block:

```bash
echo ""
echo "Test: helpers still work when an extractor has stripped their exec bits"
make_repo "$TEST_ROOT/repo-nomode"
mkdir -p "$TEST_ROOT/repo-nomode/docs"
printf '### Task 1: Thing\n\nbody\n' > "$TEST_ROOT/repo-nomode/docs/plan.md"
nomode="$TEST_ROOT/nomode-scripts"
mkdir -p "$nomode"
cp "$SDD_DIR_SCRIPT" "$TASK_BRIEF" "$REVIEW_PACKAGE" "$nomode/"
chmod -x "$nomode"/*

rc=0
out=$( ( cd "$TEST_ROOT/repo-nomode" && bash "$nomode/task-brief" docs/plan.md 1 ) 2>&1 ) || rc=$?
if [ "$rc" -eq 0 ]; then pass "task-brief survives stripped exec bits"; else fail "task-brief with stripped exec bits (rc=$rc: $out)"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`

Expected: FAIL with `rc=126` and a `Permission denied` message naming `sdd-dir`.

- [ ] **Step 3: Change both call sites**

In `skills/subagent-driven-development/scripts/task-brief`, replace line 26:

```bash
  dir=$("$SCRIPT_DIR/sdd-dir" "$plan")
```

with:

```bash
  # Invoke via bash rather than direct exec: some extractors (Python zipfile)
  # strip Unix exec bits when unpacking marketplace packages.
  dir=$("${BASH:-bash}" "$SCRIPT_DIR/sdd-dir" "$plan")
```

In `skills/subagent-driven-development/scripts/review-package`, replace line 32 (the same expression) with the identical three lines.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/task-brief skills/subagent-driven-development/scripts/review-package tests/claude-code/test-sdd-dir-path.sh
git commit -m "fix(sdd): helpers died with Permission denied where an extractor dropped the exec bit"
```

---

### Task 6: pin what task-brief and review-package print

**Risk tier:** low — four documentation corrections whose exact replacement text is in this task, plus two assertions whose strings appear verbatim here.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:246`
- Modify: `skills/subagent-driven-development/SKILL.md:308`
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md:193`
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md:203`
- Test: `tests/claude-code/test-sdd-dir-path.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing. No script changes; the helpers keep the stdout they already have.

**Context the implementer needs.** Four places tell the controller that these helpers print a path. They do not. `task-brief` prints `wrote <path>: <N> lines` and `review-package` prints `wrote <path>: <N> commit(s), <N> bytes`. Only `sdd-dir` prints a bare path. A controller that pastes the helper's stdout into a dispatch prompt hands the implementer a sentence where a path belongs. The fix corrects the docs to match the scripts, and pins the scripts' stdout so the docs cannot silently drift again. Do not change what the scripts print.

- [ ] **Step 1: Write the failing tests**

Append to `tests/claude-code/test-sdd-dir-path.sh`, immediately BEFORE the final `if [ "$failures" -gt 0 ]` block:

```bash
echo ""
echo "Test: helper stdout matches what the skill docs tell controllers to expect"
make_repo "$TEST_ROOT/repo-stdout"
mkdir -p "$TEST_ROOT/repo-stdout/docs"
printf '### Task 1: Thing\n\nbody\n' > "$TEST_ROOT/repo-stdout/docs/plan.md"
git -C "$TEST_ROOT/repo-stdout" add -A
git -C "$TEST_ROOT/repo-stdout" commit -qm "base"
so_base=$(git -C "$TEST_ROOT/repo-stdout" rev-parse HEAD)
echo more >> "$TEST_ROOT/repo-stdout/docs/plan.md"
git -C "$TEST_ROOT/repo-stdout" commit -qam "work"
so_head=$(git -C "$TEST_ROOT/repo-stdout" rev-parse HEAD)

tb_out=$( cd "$TEST_ROOT/repo-stdout" && bash "$TASK_BRIEF" docs/plan.md 1 )
case "$tb_out" in
    "wrote "*": "*" lines") pass "task-brief prints 'wrote <path>: <N> lines'" ;;
    *) fail "task-brief stdout shape (got: $tb_out)" ;;
esac

rp_out=$( cd "$TEST_ROOT/repo-stdout" && bash "$REVIEW_PACKAGE" docs/plan.md "$so_base" "$so_head" )
case "$rp_out" in
    "wrote "*": "*" commit(s), "*" bytes") pass "review-package prints 'wrote <path>: <N> commit(s), <N> bytes'" ;;
    *) fail "review-package stdout shape (got: $rp_out)" ;;
esac
```

- [ ] **Step 2: Run the tests to verify they pass immediately**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`

Expected: `STATUS: PASSED`. These two assertions pass on the first run by design. They are characterization tests: the defect is in the prose, not the scripts, and this is the fence that keeps the prose honest. Confirm they genuinely exercise the helpers by temporarily changing `task-brief`'s final `echo` to `echo "$out"`, re-running to see the assertion FAIL, then restoring the line with `git show HEAD:skills/subagent-driven-development/scripts/task-brief > skills/subagent-driven-development/scripts/task-brief`.

- [ ] **Step 3: Correct the four prose claims**

In `skills/subagent-driven-development/SKILL.md` line 246, replace:

```
  uniquely named file and prints the path. Compose the dispatch so the
```

with:

```
  uniquely named file and prints `wrote <path>: <N> lines`. Take the path
  from that line; do not paste the line itself into a dispatch. Compose the
  dispatch so the
```

In `skills/subagent-driven-development/SKILL.md` line 308, replace the parenthetical `it prints the unique file path it wrote` with:

```
it prints `wrote <path>: <N> commit(s), <N> bytes`, so take the path from that line
```

In `skills/subagent-driven-development/task-reviewer-prompt.md`, apply the same correction at lines 193 and 203. Locate both with:

```bash
grep -n 'prints the path\|prints the unique file path' skills/subagent-driven-development/task-reviewer-prompt.md
```

Replace each occurrence so it names the actual output shape for the helper that line describes.

- [ ] **Step 4: Confirm no claim survives**

Run: `grep -rn "prints the path\|prints the unique file path" skills/ || echo "no stale stdout claims remain"`

Expected: `no stale stdout claims remain`.

- [ ] **Step 5: Run the tests again**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 6: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/task-reviewer-prompt.md tests/claude-code/test-sdd-dir-path.sh
git commit -m "docs(sdd): four places promised a bare path from helpers that print a sentence"
```

---

### Task 7: anchor the alternative BASE_SHA to the merge base

**Risk tier:** low — a single-line documentation change whose complete before and after text is in this task.

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md:28`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing.

**Context the implementer needs.** Port of upstream commit `2a500fe`. The comment offers `origin/main` as the alternative base for a multi-commit review. `origin/main` is a moving ref: once it advances past the branch point, main's newer files show up in the reviewer's two-dot diff as deletions the reviewer cannot distinguish from real ones. `git merge-base origin/main HEAD` anchors the range to the branch point, matching how `review-package` already computes BASE. This is also the same hazard SDD warns about at `SKILL.md:308` and `:343`.

- [ ] **Step 1: Make the change**

In `skills/requesting-code-review/SKILL.md`, replace line 28:

```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
```

with:

```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or: git merge-base origin/main HEAD
```

- [ ] **Step 2: Verify the moving-ref form is gone**

Run: `grep -n 'or origin/main' skills/requesting-code-review/SKILL.md || echo "moving-ref alternative removed"`

Expected: `moving-ref alternative removed`.

- [ ] **Step 3: Confirm the gate suites are unaffected**

Run: `bash tests/codex-review-gate/test-gate-topology.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 4: Commit**

```bash
git add skills/requesting-code-review/SKILL.md
git commit -m "docs(requesting-code-review): a moving base ref rendered main's new files as phantom deletions"
```

---

### Task 8: the claude CLI test helper must not inherit the suite's stdin

**Risk tier:** low — a single-line test-harness change whose complete before and after text is in this task.

**Files:**
- Modify: `tests/claude-code/test-helpers.sh:30`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing. `run_claude`'s signature and return value are unchanged.

**Context the implementer needs.** Port of upstream commit `72ee5bb`. `run_claude` spawns `claude -p` with the suite's stdin inherited. Run from a terminal, or from anything with an open stdin, the CLI can block reading it, and each test stalls for its full timeout instead of completing.

- [ ] **Step 1: Make the change**

In `tests/claude-code/test-helpers.sh`, replace lines 29-30:

```bash
    # Run Claude in headless mode with timeout
    if timeout "$timeout" "${cmd[@]}" > "$output_file" 2>&1; then
```

with:

```bash
    # Run Claude in headless mode with timeout. Redirect stdin from
    # /dev/null so the CLI can't block waiting for input and hang the suite.
    if timeout "$timeout" "${cmd[@]}" > "$output_file" 2>&1 < /dev/null; then
```

- [ ] **Step 2: Verify the helper still parses**

Run: `bash -n tests/claude-code/test-helpers.sh && echo "syntax OK"`

Expected: `syntax OK`.

- [ ] **Step 3: Verify the redirect is present exactly once**

Run: `grep -c 'timeout "$timeout" "${cmd\[@\]}" > "$output_file" 2>&1 < /dev/null' tests/claude-code/test-helpers.sh`

Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add tests/claude-code/test-helpers.sh
git commit -m "test(claude-code): the spawned CLI inherited the suite's stdin and stalled to timeout"
```

---

### Task 9: delete the orphaned skill files and fence the class

**Risk tier:** standard — deletes seven tracked files and adds a guard that can fail future work.

**Files:**
- Delete: `skills/brainstorming/spec-document-reviewer-prompt.md`
- Delete: `skills/writing-plans/plan-document-reviewer-prompt.md`
- Delete: `skills/systematic-debugging/CREATION-LOG.md`
- Delete: `skills/systematic-debugging/test-academic.md`
- Delete: `skills/systematic-debugging/test-pressure-1.md`
- Delete: `skills/systematic-debugging/test-pressure-2.md`
- Delete: `skills/systematic-debugging/test-pressure-3.md`
- Create: `tests/packaging/test-no-orphan-skill-files.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks call.

**Context the implementer needs.** Sixty-seven files under `skills/` are not `SKILL.md`. Exactly these seven have no other tracked file mentioning their basename, once `docs/`, `CHANGELOG.md`, and `RELEASE-NOTES.md` are excluded, because a mention in those three records history rather than a live reference. Two of the seven have been disconnected since 2026-03-24. Because the current orphan set is exactly the delete set, the guard's allowlist ships empty.

Do not delete anything else. Files such as `graphviz-conventions.dot` and `visual-companion.md` look standalone but are referenced from their skill bodies.

- [ ] **Step 1: Write the guard test**

Create `tests/packaging/test-no-orphan-skill-files.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Every non-SKILL.md file under skills/ must be reachable: some other tracked
# file outside docs/, CHANGELOG.md, and RELEASE-NOTES.md has to mention its
# basename. Those three record history, so a mention there is not a live
# reference — which is how seven files shipped for months with no skill, hook,
# test, or manifest pointing at them.
#
# A genuine exception goes in ALLOWLIST below, with a comment saying why.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== orphaned skill files ==="
echo ""

cd "$REPO_ROOT"
if ! out="$(node -e '
  const fs = require("fs"), cp = require("child_process"), path = require("path");
  // Paths whose mention does not count as a live reference.
  const HISTORY = /^(docs\/|RELEASE-NOTES\.md$|CHANGELOG\.md$)/;
  // Genuine exceptions, each with a reason. Empty by construction: the seven
  // files that failed this check when it was written were deleted, not listed.
  const ALLOWLIST = new Set([]);
  const all = cp.execSync("git ls-files", { encoding: "utf8", maxBuffer: 1 << 28 })
    .split("\n").filter(Boolean);
  const searchable = all.filter((f) => !HISTORY.test(f));
  const contents = new Map();
  for (const f of searchable) {
    try { contents.set(f, fs.readFileSync(f, "utf8")); } catch (e) { /* binary or gone */ }
  }
  const orphans = [];
  for (const c of all) {
    if (!c.startsWith("skills/")) continue;
    if (path.basename(c) === "SKILL.md") continue;
    if (ALLOWLIST.has(c)) continue;
    const b = path.basename(c);
    let referenced = false;
    for (const [f, t] of contents) {
      if (f === c) continue;
      if (t.includes(b)) { referenced = true; break; }
    }
    if (!referenced) orphans.push(c);
  }
  if (orphans.length) {
    console.error("orphaned skill files (no inbound reference):");
    for (const o of orphans) console.error("  " + o);
    process.exit(1);
  }
  console.log("checked " + all.filter((f) => f.startsWith("skills/") && path.basename(f) !== "SKILL.md").length + " skill files");
' 2>&1)"; then
    echo "  [FAIL] every skill file has an inbound reference"
    echo "$out" | sed 's/^/    /'
    echo ""
    echo "STATUS: FAILED (1 failure)"
    exit 1
fi

echo "  [PASS] every skill file has an inbound reference ($out)"
echo ""
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run the guard to verify it fails**

Run: `bash tests/packaging/test-no-orphan-skill-files.sh`

Expected: `STATUS: FAILED`, listing exactly these seven paths:

```
  skills/brainstorming/spec-document-reviewer-prompt.md
  skills/systematic-debugging/CREATION-LOG.md
  skills/systematic-debugging/test-academic.md
  skills/systematic-debugging/test-pressure-1.md
  skills/systematic-debugging/test-pressure-2.md
  skills/systematic-debugging/test-pressure-3.md
  skills/writing-plans/plan-document-reviewer-prompt.md
```

If the list differs from these seven, STOP and report the difference rather than deleting anything. A file that appears here unexpectedly means the reference it had was removed by another task, not that it is dead.

- [ ] **Step 3: Delete the seven files**

```bash
git rm skills/brainstorming/spec-document-reviewer-prompt.md \
       skills/writing-plans/plan-document-reviewer-prompt.md \
       skills/systematic-debugging/CREATION-LOG.md \
       skills/systematic-debugging/test-academic.md \
       skills/systematic-debugging/test-pressure-1.md \
       skills/systematic-debugging/test-pressure-2.md \
       skills/systematic-debugging/test-pressure-3.md
```

- [ ] **Step 4: Run the guard to verify it passes**

Run: `bash tests/packaging/test-no-orphan-skill-files.sh`

Expected: `STATUS: PASSED` with `checked 60 skill files`.

- [ ] **Step 5: Verify the affected skills still load**

Run: `bash tests/packaging/test-package-skill.sh`

Expected: `STATUS: PASSED`. That suite is the only other test under `tests/packaging/`; it certifies the packaged skill tree, so it is the one that would notice a deletion that broke packaging.

- [ ] **Step 6: Commit**

```bash
git add -A tests/packaging/test-no-orphan-skill-files.sh skills/
git commit -m "chore(skills): seven files shipped in the package with nothing pointing at them"
```

---

### Task 10: route requesting-code-review into receiving-code-review

**Risk tier:** standard — adds a cross-skill routing edge that changes what an agent does after a review returns.

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md:42-47`
- Test: `tests/codex-review-gate/test-gate-topology.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks call.

**Context the implementer needs.** `skills/receiving-code-review/` is referenced by no skill, no hook, and no test. The only place it is named outside its own directory is the README, the release notes, and a skill index. It is the skill that governs the exact moment `requesting-code-review` step 3 describes: feedback has arrived and the agent is deciding what to do with it. The two skills are adjacent in the workflow and unconnected in the text.

Keep the change to a routing pointer in the existing step 3. Do not restate `receiving-code-review`'s content here.

- [ ] **Step 1: Write the failing test**

Append to `tests/codex-review-gate/test-gate-topology.sh`, immediately BEFORE its final status block:

```bash
# The skill that governs "feedback has arrived, now what" must be reachable
# from the skill that requests the feedback. It was referenced by no skill,
# hook, or test until 2026-09-05.
if grep -q 'hyperpowers:receiving-code-review' "$REPO_ROOT/skills/requesting-code-review/SKILL.md"; then
    pass "requesting-code-review routes to receiving-code-review"
else
    fail "requesting-code-review routes to receiving-code-review"
fi
```

If `test-gate-topology.sh` names its repo root or its helpers differently, adapt the two identifiers to that file's existing convention. Read its header before editing.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-topology.sh`

Expected: FAIL on `requesting-code-review routes to receiving-code-review`.

- [ ] **Step 3: Add the routing pointer**

In `skills/requesting-code-review/SKILL.md`, replace the step 3 block:

```markdown
**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)
```

with:

```markdown
**3. Act on feedback:**

**REQUIRED SUB-SKILL:** Use hyperpowers:receiving-code-review. Findings arrive
as claims to evaluate, not instructions to execute, and that skill is where the
evaluation discipline lives.

- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/codex-review-gate/test-gate-topology.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 5: Verify the orphan guard is unaffected**

Run: `bash tests/packaging/test-no-orphan-skill-files.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/SKILL.md tests/codex-review-gate/test-gate-topology.sh
git commit -m "fix(skills): the skill for receiving review was unreachable from the skill that requests it"
```

---

### Task 11: stop executing-plans from overriding the human's execution choice

**Risk tier:** standard — behavior-shaping routing prose in two skills plus a divergent reviewer clause.

**Files:**
- Modify: `skills/executing-plans/SKILL.md:14`
- Modify: `skills/writing-plans/SKILL.md:199`
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md:52-53`
- Modify: `skills/subagent-driven-development/re-review-prompt.md:43-44`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks call.

**Context the implementer needs.** Three separate contradictions, all mechanically checkable against text that exists.

First, `writing-plans/SKILL.md:201` routes to `executing-plans` only when the human partner explicitly asked for inline execution. `executing-plans/SKILL.md:14` then tells the agent to use SDD instead whenever subagents are available. On Claude Code subagents are always available, so the note always fires and overrides the choice the human just made. The note should tell the agent it is on the inline path by request, not push it off.

Second, `writing-plans/SKILL.md:199` says `Fresh subagent per task + two-stage review`. The task reviewer has been one reviewer returning two verdicts since 2026-06-10; `task-reviewer-prompt.md:3` says so.

Third, the reviewer read-only clause exists in three copies and has diverged. `code-reviewer.md:35` carries the worktree escape hatch; the other two do not, so a reviewer that legitimately needs a different revision has no sanctioned way to get one and may move HEAD on the shared checkout.

- [ ] **Step 1: Fix the executing-plans note**

In `skills/executing-plans/SKILL.md`, replace line 14:

```markdown
**Note:** Tell your human partner that Superpowers works much better with access to subagents (Claude Code, Codex CLI, Codex App, and Copilot CLI all qualify; see the per-platform tool refs in `../using-hyperpowers/references/`). If subagents are available, use hyperpowers:subagent-driven-development instead of this skill.
```

with:

```markdown
**Note:** This skill is the inline path — you are here because your human partner asked for in-session execution, or because this harness has no subagents. Either way, execute the plan here; do not re-open the choice they already made. If your harness has no subagents (see the per-platform tool refs in `../using-hyperpowers/references/`; Claude Code, Codex CLI, Codex App, and Copilot CLI all have them), mention once that hyperpowers:subagent-driven-development is the stronger default on a harness that does.
```

- [ ] **Step 2: Fix the stale review-stage count**

In `skills/writing-plans/SKILL.md`, replace line 199:

```markdown
- Fresh subagent per task + two-stage review
```

with:

```markdown
- Fresh subagent per task, then one task reviewer returning a spec verdict and a quality verdict
```

- [ ] **Step 3: Bring the two short read-only clauses up to the full form**

In `skills/subagent-driven-development/task-reviewer-prompt.md`, replace:

```
    Your review is read-only on this checkout. Do not mutate the working
    tree, the index, HEAD, or branch state in any way.
```

with:

```
    Your review is read-only on this checkout. Do not mutate the working
    tree, the index, HEAD, or branch state in any way. Use tools like
    `git show`, `git diff`, and `git log` to inspect history. If you need a
    working copy of a different revision, check it out into a separate
    temporary directory (e.g. `git worktree add /tmp/review-[SHA] [SHA]`) —
    never move HEAD on this checkout.
```

Apply the identical replacement in `skills/subagent-driven-development/re-review-prompt.md`.

- [ ] **Step 4: Verify all three clauses now agree**

Run: `grep -c 'never move HEAD on this checkout' skills/requesting-code-review/code-reviewer.md skills/subagent-driven-development/task-reviewer-prompt.md skills/subagent-driven-development/re-review-prompt.md`

Expected: each of the three files reports `1`.

- [ ] **Step 5: Verify the contradictions are gone**

Run: `grep -n 'two-stage review' skills/writing-plans/SKILL.md || echo "stale stage count removed"`

Expected: `stale stage count removed`.

Run: `grep -n 'use hyperpowers:subagent-driven-development instead of this skill' skills/executing-plans/SKILL.md || echo "routing override removed"`

Expected: `routing override removed`.

- [ ] **Step 6: Run the SDD suites**

Run each and expect `STATUS: PASSED`:

```bash
bash tests/sdd/test-sdd-contract.sh
bash tests/packaging/test-no-orphan-skill-files.sh
```

- [ ] **Step 7: Commit**

```bash
git add skills/executing-plans/SKILL.md skills/writing-plans/SKILL.md skills/subagent-driven-development/task-reviewer-prompt.md skills/subagent-driven-development/re-review-prompt.md
git commit -m "fix(skills): the inline-execution skill talked every session out of inline execution"
```

---

### Task 12: point the performance baseline at a directory that survives the run

**Risk tier:** low — a single prose correction whose complete before and after text is in this task.

**Files:**
- Modify: `skills/optimizing-performance/SKILL.md:38`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing.

**Context the implementer needs.** Step 1 of the workflow persists `baseline.json`, the correctness reference, and the attempts ledger to "the path `sdd-dir` prints". `sdd-dir` has two behaviors: with no argument it prints a repo-scoped directory, and with a plan file it prints a plan-scoped one. At step 1 no plan exists yet, since the plan is not written until step 2. Worse, the plan-scoped directory is deleted by SDD's Finish step (`subagent-driven-development/SKILL.md:598`, `rm -rf <workspace>`), which would destroy the baseline that the bounded re-profile round at step 5 needs. The repo-scoped directory is the one that survives, and naming it removes the ambiguity.

- [ ] **Step 1: Make the change**

In `skills/optimizing-performance/SKILL.md` line 38, replace:

```
Persist to the SDD scratch dir via the `sdd-dir` cache helper (the path `subagent-driven-development`'s `scripts/sdd-dir` prints — **never** `.git/`, never the working tree):
```

with:

```
Persist to the repo-scoped scratch dir: run `subagent-driven-development`'s `scripts/sdd-dir` with **no plan argument** and use the path it prints (**never** `.git/`, never the working tree). The no-argument form is required — the plan-scoped directory does not exist yet at this step, and SDD's Finish deletes it, which would destroy the baseline the bounded re-profile round in step 5 reads:
```

- [ ] **Step 2: Verify the ambiguous phrasing is gone**

Run: `grep -n 'the path .subagent-driven-development.*sdd-dir. prints' skills/optimizing-performance/SKILL.md || echo "ambiguous path reference removed"`

Expected: `ambiguous path reference removed`.

- [ ] **Step 3: Verify the guard still passes**

Run: `bash tests/packaging/test-no-orphan-skill-files.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 4: Commit**

```bash
git add skills/optimizing-performance/SKILL.md
git commit -m "fix(optimizing-performance): the baseline was written to a directory SDD deletes before the re-profile reads it"
```

---

### Task 13: gate-telemetry reports the churn the analysis had to compute by hand

**Risk tier:** standard — new aggregation logic in a read-only reporting script.

**Files:**
- Modify: `skills/requesting-code-review/scripts/gate-telemetry`
- Test: `tests/codex-review-gate/test-gate-telemetry.sh`

**Interfaces:**
- Consumes: nothing from other tasks. In particular, it does not read Task 1's changed output.
- Produces: two new fields on every `byGate` entry in the `--json` output, `meanRounds` (a number rounded to two decimals, or `null` when `runs` is 0) and `firstRound` (an integer count of runs that finished in one round). Both appear on per-repo entries and on the fleet aggregate. Every existing field keeps its name, type, and meaning.

**Context the implementer needs.** The 2026-09-05 analysis had to read 696 `gate-round.json` files with an ad-hoc script to learn that task gates average 2.24 rounds and converge in one round 27% of the time. The data was already in the directories the telemetry reader walks; it just was not summarized. Part 2 measures its arms against exactly these two numbers, so shipping them here means the baseline comes from the tool rather than a throwaway script.

`byGate[g]` already accumulates `{ rounds: [], backstops: 0, runs: 0 }` at line 63 and merges into the fleet aggregate at lines 119-123. Derive both new fields from the `rounds` array at render and serialize time. Do not change how `rounds` is collected.

- [ ] **Step 1: Write the failing test**

Read `tests/codex-review-gate/test-gate-telemetry.sh` first to learn how it builds a fixture cache root and asserts on output. Then append a case, before the file's final status block, that:

1. Creates a fixture cache root with four `codex-review/<key>/<run>/gate-round.json` files for gate `task`, with `round` values 1, 1, 3, and 3 and any `ceiling`.
2. Runs `gate-telemetry --json` against it and pipes through node.
3. Asserts `aggregate.byGate.task.meanRounds` equals `2`.
4. Asserts `aggregate.byGate.task.firstRound` equals `2`.
5. Runs `gate-telemetry` without `--json` and asserts the markdown line for gate `task` contains `mean 2` and `first-round 2/4`.

Follow the file's existing fixture and assertion helpers rather than introducing new ones. The assertion strings above are the exact substrings the implementation in Step 3 produces.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh`

Expected: FAIL. `meanRounds` and `firstRound` are `undefined`, and the markdown line has neither substring.

- [ ] **Step 3: Add the two derived metrics**

In `skills/requesting-code-review/scripts/gate-telemetry`, insert this helper immediately after the line `const [base, jsonOut, ...keys] = process.argv.slice(1);`:

```js
  // Churn metrics (2026-09-05 spec): the round distribution was already in
  // byGate.rounds; only the summary was missing, so every churn question had
  // to be answered with a throwaway script over the cache.
  const churn = (rounds) => {
    const n = rounds.length;
    if (!n) return { meanRounds: null, firstRound: 0 };
    const sum = rounds.reduce((a, b) => a + (Number(b) || 0), 0);
    return {
      meanRounds: Math.round((sum / n) * 100) / 100,
      firstRound: rounds.filter((r) => Number(r) === 1).length,
    };
  };
```

Immediately before the `if (jsonOut === "1")` block, insert:

```js
  // Attach the derived metrics to every byGate entry, per-repo and fleet.
  for (const r of repos)
    for (const v of Object.values(r.byGate)) Object.assign(v, churn(v.rounds));
  for (const v of Object.values(agg.byGate)) Object.assign(v, churn(v.rounds));
```

Replace the per-repo `byg` line:

```js
    const byg = Object.entries(r.byGate).map(([g, v]) => `${g}: [${v.rounds.join(", ")}] (backstops ${v.backstops}/${v.runs})`).join("; ") || "none";
```

with:

```js
    const byg = Object.entries(r.byGate).map(([g, v]) => `${g}: mean ${v.meanRounds === null ? "-" : v.meanRounds}, first-round ${v.firstRound}/${v.runs}, backstops ${v.backstops}/${v.runs} [${v.rounds.join(", ")}]`).join("; ") || "none";
```

Replace the fleet `abyg` line:

```js
    const abyg = Object.entries(agg.byGate).map(([g, v]) => `${g}: [${v.rounds.join(", ")}] (backstops ${v.backstops}/${v.runs})`).join("; ") || "none";
```

with:

```js
    const abyg = Object.entries(agg.byGate).map(([g, v]) => `${g}: mean ${v.meanRounds === null ? "-" : v.meanRounds}, first-round ${v.firstRound}/${v.runs}, backstops ${v.backstops}/${v.runs} [${v.rounds.join(", ")}]`).join("; ") || "none";
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh`

Expected: `STATUS: PASSED`.

- [ ] **Step 5: Capture the Part 2 baseline from real data**

Run: `bash skills/requesting-code-review/scripts/gate-telemetry --all`

Record the `Rounds by gate` line from the fleet aggregate. Paste it into the task report. Part 2's control arms compare against these numbers, and this is the run that establishes them.

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-telemetry tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "feat(gate): the churn numbers were in the cache but only a throwaway script could read them"
```

---

### Task 14: docs/testing.md describes the harness that exists

**Risk tier:** low — a documentation file replaced in full, with the complete new content in this task.

**Files:**
- Modify: `docs/testing.md`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing.

**Context the implementer needs.** All 34 lines describe a Python Drill harness with `uv run drill run` and `evals/scenarios/*.yaml`. The eval harness is Quorum, written in TypeScript, and lives in a separate clone of `scott-arne/hyperpowers-evals` at `evals/`, which is gitignored here. The plugin test listing is also stale: it names five directories out of fourteen.

- [ ] **Step 1: Verify the current test directory listing**

Run: `ls tests/`

Expected: fourteen directories. Use the actual listing in Step 2; the content below reflects the tree as of 2026-09-05, so reconcile any difference before writing.

- [ ] **Step 2: Replace the file**

Write `docs/testing.md` with exactly this content:

```markdown
# Testing Hyperpowers

Hyperpowers has two distinct kinds of tests, in two different repositories:

- **`tests/`** — does the plugin's non-LLM code work? Bash, node, and python
  tests over the hooks, the gate scripts, the SDD helpers, and each harness
  integration. These live here and run offline.
- **`evals/`** — do agents behave correctly in real LLM sessions? Quorum drives
  real agent CLI sessions of Claude Code and Codex and judges skill compliance
  with an LLM verifier. This is a **separate clone** of
  [hyperpowers-evals](https://github.com/scott-arne/hyperpowers-evals/), not a
  submodule, and it is gitignored here. Scenario and harness work gets
  committed in that repo, never in this one.

## Plugin tests

Every suite is a standalone bash script. There is no aggregate runner and no
CI; run the suites that cover what you changed.

| Directory | Covers |
|---|---|
| `tests/hooks/` | session-start context injection, the ungated notice, the Codex broker janitor, the hooks heredoc fence |
| `tests/codex-review-gate/` | gate scripts (`verdict-normalize`, `gate-round`, `gate-telemetry`, `ungated-ledger`, preflight, broker health), gate topology, and the gate-split losslessness proof |
| `tests/sdd/` | the subagent-driven-development contract |
| `tests/claude-code/` | SDD scratch-dir derivation and helper behavior, plus Claude Code skill tests and token analysis |
| `tests/packaging/` | manifest wiring and the orphaned-skill-file guard |
| `tests/brainstorm-server/` | the brainstorm server JS |
| `tests/opencode/`, `tests/kimi/`, `tests/pi/`, `tests/antigravity/` | per-harness plugin loading, bootstrap caching, tool registration |
| `tests/writing-skills/`, `tests/systematic-debugging/` | skill-specific structural checks |
| `tests/explicit-skill-requests/` | Haiku-specific, multi-turn, and skill-name-prompted behavior |
| `tests/shell-lint/` | shellcheck over the repo's shell scripts |

Run one suite directly:

```bash
bash tests/codex-review-gate/test-verdict-normalize.sh
```

Run a directory's worth:

```bash
for t in tests/hooks/test-*.sh; do bash "$t" || echo "FAILED: $t"; done
```

Some directories ship a `run-tests.sh` or `run-all.sh`; prefer it when present.

The suites under `tests/claude-code/` and `tests/explicit-skill-requests/`
spawn the real `claude` CLI. They need credentials, take minutes, and are not
part of any automated run.

## Skill behavior evals

Quorum is the harness. Scenarios live at `evals/scenarios/<name>/` as a
`setup.sh`, a `checks.sh` with `pre()` and `post()` functions, and a
`story.md`. See `evals/README.md` for setup.

Live eval runs are trusted-maintainer operations: they consume real API
credit and run agents in dangerous mode. Never add live evals, API keys, or
dangerous-mode launches to public CI.

Evals are slow — minutes to tens of minutes each — and run real LLM sessions.
They are the required evidence for any change to behavior-shaping skill prose;
see "Skill Changes Require Evaluation" in `CLAUDE.md`.
```

- [ ] **Step 3: Verify no Drill reference survives**

Run: `grep -rn 'drill\|Drill' docs/testing.md || echo "no Drill references remain"`

Expected: `no Drill references remain`.

- [ ] **Step 4: Verify every named directory exists**

Run: `for d in hooks codex-review-gate sdd claude-code packaging brainstorm-server opencode kimi pi antigravity writing-skills systematic-debugging explicit-skill-requests shell-lint; do [ -d "tests/$d" ] || echo "MISSING tests/$d"; done; echo checked`

Expected: `checked` with no `MISSING` lines.

- [ ] **Step 5: Commit**

```bash
git add docs/testing.md
git commit -m "docs(testing): the whole file described a Python harness this repo no longer has"
```

---

### Task 15: release

**Risk tier:** standard — publishes every preceding task, and the release is what gives Part 2 a clean baseline.

**Files:**
- Modify: `CHANGELOG.md`
- Modify (by `vrzn`): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json`

**Interfaces:**
- Consumes: every preceding task's commits.
- Produces: a `v6.13.0` tag.

**Context the implementer needs.** This task runs last. `vrzn` owns every version string; never hand-edit one. The current version is 6.12.0, and this release adds features (the version notice, the churn metrics) alongside fixes, so the bump is `minor`. Task 2's notice only helps if the marketplace actually carries the new version, which is what makes the release part of the work rather than an afterthought.

Do not push. Pushing is a separate instruction from the human partner.

- [ ] **Step 1: Confirm the tree is clean and every suite is green**

```bash
git status --short
```

Expected: empty.

Run every suite touched by this plan and expect `STATUS: PASSED` from each:

```bash
bash tests/codex-review-gate/test-verdict-normalize.sh
bash tests/codex-review-gate/test-gate-telemetry.sh
bash tests/codex-review-gate/test-gate-topology.sh
bash tests/codex-review-gate/test-gate-split-lossless.sh
bash tests/codex-review-gate/test-gate-contract.sh
bash tests/hooks/test-session-start.sh
bash tests/hooks/test-no-heredocs-in-hooks.sh
bash tests/hooks/test-ungated-notice.sh
bash tests/hooks/test-broker-janitor.sh
bash tests/claude-code/test-sdd-dir-path.sh
bash tests/sdd/test-sdd-contract.sh
bash tests/packaging/test-no-orphan-skill-files.sh
```

If any suite fails, STOP and report. Do not release over a red suite.

- [ ] **Step 2: Write the changelog entry**

Add a new section at the top of `CHANGELOG.md`, matching the format of the existing 6.12.0 entry exactly. Read that entry first, then write the 6.13.0 entry covering:

- `verdict-normalize` approves a JSON-path `needs-attention` that carries only medium and low findings, and fails closed to incomplete when it carries none. Measured: 30% of task-gate blocking captures had zero critical or high findings.
- `session-start` names a newer marketplace version. Releases 6.10.0 through 6.11.1 never loaded in a session.
- `run-hook.cmd` uses `:;` label lines instead of a heredoc, and `tests/hooks/test-no-heredocs-in-hooks.sh` fences the class. Upstream `d80fc18`.
- `review-package` exits 3 on an empty or non-descendant range. Upstream `99f9f00`.
- Both SDD helpers invoke `sdd-dir` through bash so a stripped exec bit cannot break them. Upstream `0be4987`.
- The helper stdout contract is documented correctly in four places and pinned by test.
- `requesting-code-review` offers `git merge-base origin/main HEAD` instead of the moving ref. Upstream `2a500fe`.
- The `claude` CLI test helper reads stdin from `/dev/null`. Upstream `72ee5bb`.
- Seven orphaned skill files deleted; a guard now fails on any new one.
- `requesting-code-review` routes to `receiving-code-review`.
- `executing-plans` no longer overrides an explicit inline-execution request; `writing-plans` no longer claims a two-stage review; all three reviewer read-only clauses now carry the worktree escape hatch.
- `optimizing-performance` names the repo-scoped scratch dir, which survives SDD's Finish.
- `gate-telemetry` reports mean rounds and first-round convergence per gate.
- `docs/testing.md` describes Quorum and the current test tree.

- [ ] **Step 3: Bump the version**

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn bump minor -y
```

- [ ] **Step 4: Verify every manifest moved together**

```bash
git diff --stat
```

Expected: six manifest files changed, each 6.12.0 to 6.13.0, plus `CHANGELOG.md`.

Run: `grep -rh '"version"' package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json | sort -u`

Expected: a single distinct version line, `6.13.0`.

- [ ] **Step 5: Commit and tag**

```bash
git add CHANGELOG.md package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .kimi-plugin/plugin.json
git commit -m "Release 6.13.0: the gate blocked on findings its own contract calls minor"
git tag -a v6.13.0 -m "Release v6.13.0"
```

- [ ] **Step 6: Report, do not push**

Report the release commit SHA, the tag, and the fact that nothing has been pushed. Pushing is the human partner's call.
