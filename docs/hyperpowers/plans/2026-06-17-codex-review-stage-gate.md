# Codex Review Stage-Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire codex-plugin-cc into Hyperpowers as an active review stage-gate for specs, plans, and code on Claude Code, degrading cleanly to a warning when Codex is unavailable.

**Architecture:** A single dependency-free bash probe resolves codex-plugin-cc from Claude Code's plugin registry and asks the Codex companion whether a review can run. A shared markdown contract (`codex-review-gate.md`) defines one gate procedure — probe, invoke, interpret, fix-loop, hand back — that four tuned skills reference at defined points (after Claude's own self-review, before handback). All Codex invocation is centralized so a codex-plugin-cc change is a one-place fix.

**Tech Stack:** Bash (probe + tests, shellcheck-clean), Node (JSON parsing — already required by codex-plugin-cc), Markdown skill content.

**Spec:** [docs/hyperpowers/specs/2026-06-17-codex-plugin-cc-required-dependency-design.md](../specs/2026-06-17-codex-plugin-cc-required-dependency-design.md) — read it before starting.

## Global Constraints

- **Claude Code only.** Gate logic fires only under Claude Code. No behavior change in any other harness (Codex, Cursor, Kimi, OpenCode, Pi, Antigravity, Gemini). The *probe script* is harness-agnostic; the *Claude-Code-only* condition lives in the skill instructions that call it.
- **Fail-safe = degrade.** On any uncertainty (missing registry, parse error, missing `node`, Codex not ready, probe timeout), the gate skips Codex and continues the skill. A gate must never hard-fail a skill.
- **No new runtime dependency.** No `jq`. JSON is parsed with `node` (whose absence correctly means "Codex can't run" → degrade). The shipped skills add only bash + markdown.
- **Severity mapping (one vocabulary):** Codex `critical → Critical`, `high → Important`, `medium|low → Minor`. **Blocking = Critical + Important.** Minor is noted, non-blocking.
- **Foreground review (`--wait`).** All gates run Codex synchronously; the gate blocks on the result. Background/polling is explicitly out of scope for v1.
- **Round cap = 2.** The fix-and-re-review loop runs at most 2 Codex rounds; on hitting the cap with unresolved blocking findings, hand back with them listed rather than looping.
- **Single invocation surface.** Every Codex call goes through the recipes in `codex-review-gate.md`. No skill hand-rolls a `codex-companion.mjs` call.
- **Skill content is tuned code.** Edits to the four consuming SKILL.md files follow CLAUDE.md's writing-skills discipline: minimal, targeted insertions that reference the shared doc — do not reword surrounding tuned content.
- **Git:** no `Co-Authored-By` or AI-attribution lines. Do not commit plan/spec docs (per user CLAUDE.md) — only commit code, skills, tests, and product docs.
- **Canonical strings (use verbatim where a task emits them):**
  - Registry key: `codex@openai-codex`
  - Registry file: `$HOME/.claude/plugins/installed_plugins.json`
  - Companion: `<installPath>/scripts/codex-companion.mjs`
  - Install block:
    ```
    /plugin marketplace add openai/codex-plugin-cc
    /plugin install codex@openai-codex
    /reload-plugins
    /codex:setup
    ```

---

## File Structure

- **Create** `skills/requesting-code-review/scripts/codex-available.sh` — the availability probe. Prints the resolved Codex install path and exits 0 when a review can run; exits 1 otherwise.
- **Create** `skills/requesting-code-review/codex-review-gate.md` — the shared gate contract (probe → invoke → interpret → fix-loop → hand back), referenced by all four skills. A plain reference doc, like the existing `code-reviewer.md` (not a SKILL.md, so not a discoverable skill).
- **Create** `tests/codex-review-gate/test-codex-available.sh` — hermetic shell tests for the probe.
- **Modify** `skills/brainstorming/SKILL.md` — spec gate after spec self-review, before user spec review.
- **Modify** `skills/writing-plans/SKILL.md` — plan gate after plan self-review, before execution handoff.
- **Modify** `skills/subagent-driven-development/SKILL.md` — per-task code gate (after task reviewer approves) and final whole-branch code gate (after Claude's final review).
- **Modify** `skills/requesting-code-review/SKILL.md` — code gate after the Claude reviewer subagent feedback is addressed.
- **Modify** `README.md` — codex-plugin-cc prerequisite + Stop-gate overlap note.
- **Modify** `CLAUDE.md` — reconcile inherited zero-dependency language with the fork's deliberate-dependency policy.

---

## Task 1: Availability probe + shared gate contract

**Files:**
- Create: `skills/requesting-code-review/scripts/codex-available.sh`
- Create: `skills/requesting-code-review/codex-review-gate.md`
- Test: `tests/codex-review-gate/test-codex-available.sh`

**Interfaces:**
- Produces: `codex-available.sh` — reads registry at `${HYPERPOWERS_PLUGINS_FILE:-$HOME/.claude/plugins/installed_plugins.json}`; honors `HYPERPOWERS_CODEX_SETUP_JSON` (literal JSON) to stub the readiness probe in tests. On success: stdout = Codex `installPath`, exit 0. On any failure/degrade: exit 1, no stdout.
- Produces: `codex-review-gate.md` — the gate procedure other tasks reference by relative path (`codex-review-gate.md` from this skill, `../requesting-code-review/codex-review-gate.md` from others).

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-codex-available.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROBE="$REPO_ROOT/skills/requesting-code-review/scripts/codex-available.sh"

FAILURES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "codex-available probe tests"

# 1. Missing registry -> degrade (exit 1)
if HYPERPOWERS_PLUGINS_FILE="$TMP/nope.json" bash "$PROBE" >/dev/null 2>&1; then
  fail "missing registry -> exit 1"
else
  pass "missing registry -> exit 1"
fi

# 2. Registry without the codex key -> degrade even if 'ready'
printf '%s' '{"version":2,"plugins":{"superpowers@x":[{"installPath":"/p"}]}}' > "$TMP/nocodex.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/nocodex.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "no codex key -> exit 1"
else
  pass "no codex key -> exit 1"
fi

# 3. Codex present but not ready -> degrade
printf '%s' '{"version":2,"plugins":{"codex@openai-codex":[{"installPath":"'"$TMP"'/codex"}]}}' > "$TMP/reg.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/reg.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":false}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "ready:false -> exit 1"
else
  pass "ready:false -> exit 1"
fi

# 4. Codex present and ready -> exit 0 and print the install path
out="$(HYPERPOWERS_PLUGINS_FILE="$TMP/reg.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
        bash "$PROBE" 2>/dev/null)"
rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$TMP/codex" ]; then
  pass "ready:true -> exit 0 + install path"
else
  fail "ready:true -> exit 0 + install path (rc=$rc out=$out)"
fi

# 5. Malformed registry JSON -> degrade
printf '%s' 'not json{' > "$TMP/bad.json"
if HYPERPOWERS_PLUGINS_FILE="$TMP/bad.json" HYPERPOWERS_CODEX_SETUP_JSON='{"ready":true}' \
     bash "$PROBE" >/dev/null 2>&1; then
  fail "malformed registry -> exit 1"
else
  pass "malformed registry -> exit 1"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "STATUS: FAILED ($FAILURES failure(s))"
  exit 1
fi
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/codex-review-gate/test-codex-available.sh`
Expected: FAIL — the probe does not exist yet, so every case errors (`bash: .../codex-available.sh: No such file or directory`), ending in `STATUS: FAILED`.

- [ ] **Step 3: Write the probe script**

Create `skills/requesting-code-review/scripts/codex-available.sh`:

```bash
#!/usr/bin/env bash
# Probe whether a Codex review can run right now. Resolves codex-plugin-cc's
# install path from Claude Code's plugin registry, then asks the Codex
# companion whether it is ready (CLI present + authenticated).
#
# On success: print the Codex install path to stdout and exit 0.
# On any failure or uncertainty: exit 1 with no stdout (caller degrades to
# "no Codex review"). This probe never hard-errors a calling skill.
#
# Test overrides:
#   HYPERPOWERS_PLUGINS_FILE      path to installed_plugins.json
#   HYPERPOWERS_CODEX_SETUP_JSON  literal JSON used instead of running setup
set -uo pipefail

registry="${HYPERPOWERS_PLUGINS_FILE:-${HOME:-}/.claude/plugins/installed_plugins.json}"

[ -f "$registry" ] || exit 1
command -v node >/dev/null 2>&1 || exit 1

# Resolve the Codex install path from the first install record for the key.
install_path="$(node -e '
  const fs = require("fs");
  try {
    const reg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const recs = reg && reg.plugins && reg.plugins["codex@openai-codex"];
    const p = Array.isArray(recs) && recs[0] && recs[0].installPath;
    if (typeof p === "string" && p) process.stdout.write(p);
  } catch (e) { /* degrade */ }
' "$registry" 2>/dev/null)"

[ -n "$install_path" ] || exit 1

# Determine readiness. Tests inject the JSON; production runs the companion.
if [ -n "${HYPERPOWERS_CODEX_SETUP_JSON:-}" ]; then
  setup_json="$HYPERPOWERS_CODEX_SETUP_JSON"
else
  companion="$install_path/scripts/codex-companion.mjs"
  [ -f "$companion" ] || exit 1
  setup_json="$(node "$companion" setup --json 2>/dev/null)" || exit 1
fi

ready="$(printf '%s' "$setup_json" | node -e '
  const fs = require("fs");
  try {
    const d = JSON.parse(fs.readFileSync(0, "utf8"));
    process.stdout.write(d && d.ready === true ? "yes" : "no");
  } catch (e) { process.stdout.write("no"); }
' 2>/dev/null)"

[ "$ready" = "yes" ] || exit 1

printf '%s\n' "$install_path"
exit 0
```

Then make it executable:

```bash
chmod +x skills/requesting-code-review/scripts/codex-available.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/codex-review-gate/test-codex-available.sh`
Expected: five `[PASS]` lines, ending `STATUS: PASSED`.

- [ ] **Step 5: Verify the probe is shellcheck-clean**

Run: `bash tests/shell-lint/test-lint-shell.sh`
Then: `shellcheck skills/requesting-code-review/scripts/codex-available.sh`
Expected: shell-lint suite `STATUS: PASSED`; shellcheck prints nothing (exit 0).

- [ ] **Step 6: Write the shared gate contract**

Create `skills/requesting-code-review/codex-review-gate.md`:

````markdown
# Codex Review Gate

A shared stage-gate that asks Codex (via codex-plugin-cc) to review an artifact
**after** Claude has done its own review/refine/fix pass and **before** the user
is re-engaged or the work is declared complete. Referenced by brainstorming,
writing-plans, subagent-driven-development, and requesting-code-review.

**Claude Code only.** Run this gate only under Claude Code. In any other harness,
skip it silently — do not run the probe, do not emit the notice.

## 1. Probe availability

Run, from the repo root:

```bash
bash skills/requesting-code-review/scripts/codex-available.sh
```

- **Exit 0:** a Codex review can run. stdout is the Codex install path — capture it
  as `CODEX_PATH` for the invocation step.
- **Non-zero exit:** Codex is unavailable. Emit the **No-Codex notice** (below) at
  this point and continue the skill unchanged. Do not treat this as an error.

Probe at most once per skill run and reuse the result for every gate in that run.

## 2. No-Codex notice (degrade path)

When the probe exits non-zero, tell the user once, at this gate:

```
Note: codex-plugin-cc is not available, so this review will run without an
additional Codex review. Install it for an extra review gate:
  /plugin marketplace add openai/codex-plugin-cc
  /plugin install codex@openai-codex
  /reload-plugins
  /codex:setup
```

Then proceed exactly as the skill would without this gate.

## 3. Invoke Codex

**Documents (spec, plan)** — use `task`, read-only (no `--write`):

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task "Review the document at <ABSOLUTE_PATH> for completeness, internal consistency, ambiguity, and scope. Do not edit anything. Give a verdict of 'approve' or 'needs-attention', then list findings, each with a severity of critical, high, medium, or low, a short title, and a recommendation."
```

Read Codex's free-form reply and extract its verdict and findings.

**Code (diff range)** — use `review`:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" review --base <BASE_SHA> --wait
```

`<BASE_SHA>` is the range start: the recorded task base for a per-task review, or
the branch merge-base for a final whole-branch review. `review` returns JSON with
`verdict` (`approve` | `needs-attention`) and `findings[]` (each carrying
`severity` of `critical|high|medium|low`, `title`, `body`, `file`, `line_start`,
`line_end`, `recommendation`).

## 4. Interpret — severity mapping

Map Codex severities to Hyperpowers' vocabulary:

| Codex | Hyperpowers | Blocking? |
|-------|-------------|-----------|
| critical | Critical | yes |
| high | Important | yes |
| medium / low | Minor | no |

**Blocking = Critical + Important.** Minor findings are noted, not fixed in the loop.

## 5. Fix-and-re-review loop (cap = 2 rounds)

1. If verdict is `approve` and there are no blocking findings → done; go to step 6.
2. Otherwise address each blocking finding: for a document, edit the spec/plan; for
   code, dispatch a fix through the skill's existing fix path (e.g. SDD's fix
   subagent). You MAY decline a finding with explicit reasoning instead of fixing it.
3. Re-run the same Codex invocation over the updated artifact.
4. Repeat until `approve`/no blocking findings, or **2 rounds** have run. On reaching
   the cap with unresolved blocking findings, stop looping and hand back with them
   listed — do not loop indefinitely.

## 6. Hand back

Summarize concisely before returning to the skill's normal next step:

- Codex verdict (and round count if it looped),
- what Codex flagged (by mapped severity),
- what was fixed,
- what was declined and why,
- any unresolved blocking findings if the cap was hit.

Then continue the skill (present to user / mark complete / finish branch).
````

- [ ] **Step 7: Verify references resolve and discovery is intact**

Run:
```bash
test -f skills/requesting-code-review/codex-review-gate.md && echo "gate doc OK"
test -x skills/requesting-code-review/scripts/codex-available.sh && echo "probe exec OK"
bash tests/hooks/test-session-start.sh
```
Expected: `gate doc OK`, `probe exec OK`, and the SessionStart suite `STATUS: PASSED` (confirms the new files under an existing skill dir did not disturb the bootstrap).

- [ ] **Step 8: Commit**

```bash
git add skills/requesting-code-review/scripts/codex-available.sh \
        skills/requesting-code-review/codex-review-gate.md \
        tests/codex-review-gate/test-codex-available.sh
git commit -m "Add Codex review-gate probe and shared gate contract"
```

---

## Task 2: Brainstorming spec gate

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

**Interfaces:**
- Consumes: `codex-review-gate.md` (Task 1) via `../requesting-code-review/codex-review-gate.md`.

- [ ] **Step 1: Insert the gate as a checklist step**

In `skills/brainstorming/SKILL.md`, the checklist currently reads:

```markdown
7. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
8. **User reviews written spec** — ask user to review the spec file before proceeding
9. **Transition to implementation** — invoke writing-plans skill to create implementation plan
```

Replace with:

```markdown
7. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
8. **Codex spec review gate** (Claude Code only) — run the Codex review gate over the spec before involving the user (see below)
9. **User reviews written spec** — ask user to review the spec file before proceeding
10. **Transition to implementation** — invoke writing-plans skill to create implementation plan
```

- [ ] **Step 2: Add the gate node to the process flow digraph**

In the same file, the digraph contains:

```dot
    "Spec self-review\n(fix inline)" [shape=box];
    "User reviews spec?" [shape=diamond];
```

Add a node declaration directly after the `"Spec self-review\n(fix inline)"` line:

```dot
    "Codex spec gate\n(Claude Code; degrade if absent)" [shape=box];
```

Then replace the edge:

```dot
    "Spec self-review\n(fix inline)" -> "User reviews spec?";
```

with:

```dot
    "Spec self-review\n(fix inline)" -> "Codex spec gate\n(Claude Code; degrade if absent)";
    "Codex spec gate\n(Claude Code; degrade if absent)" -> "User reviews spec?";
```

- [ ] **Step 3: Add the prose subsection**

In the same file, immediately before the `**User Review Gate:**` paragraph in the
"After the Design" section, insert:

```markdown
**Codex Spec Review Gate (Claude Code only):**
After the spec self-review passes and before involving the user, run the Codex
review gate over the spec file as a **document** review. Follow
[../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md):
probe availability, and if Codex is present, have it review the spec and resolve
blocking findings in the fix loop before the user review; if Codex is absent, emit
the no-Codex notice and proceed. This gate never blocks the user review — at worst
it is skipped.

```

- [ ] **Step 4: Verify the reference resolves and the skill still parses**

Run:
```bash
test -f "$(cd skills/brainstorming && readlink -f ../requesting-code-review/codex-review-gate.md)" && echo "ref OK"
grep -n "Codex spec review gate" skills/brainstorming/SKILL.md
bash tests/hooks/test-session-start.sh
```
Expected: `ref OK`; the grep shows the new checklist line; SessionStart suite `STATUS: PASSED`.

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "Add Codex spec review gate to brainstorming"
```

---

## Task 3: Writing-plans plan gate

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

**Interfaces:**
- Consumes: `codex-review-gate.md` via `../requesting-code-review/codex-review-gate.md`.

- [ ] **Step 1: Insert the gate between Self-Review and Execution Handoff**

In `skills/writing-plans/SKILL.md`, the "Self-Review" section ends and the
"## Execution Handoff" heading begins. Immediately before `## Execution Handoff`,
insert:

```markdown
## Codex Plan Review Gate (Claude Code only)

After the plan self-review and before presenting the plan to the user, run the
Codex review gate over the plan file as a **document** review. Follow
[../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md):
probe availability; if Codex is present, have it review the plan (feasibility, task
sizing, missing steps, spec coverage) and resolve blocking findings in the fix loop
before the execution handoff; if Codex is absent, emit the no-Codex notice and
proceed. This gate never blocks the handoff — at worst it is skipped.

```

- [ ] **Step 2: Verify the reference resolves and the skill still parses**

Run:
```bash
test -f "$(cd skills/writing-plans && readlink -f ../requesting-code-review/codex-review-gate.md)" && echo "ref OK"
grep -n "Codex Plan Review Gate" skills/writing-plans/SKILL.md
bash tests/hooks/test-session-start.sh
```
Expected: `ref OK`; grep shows the new heading; SessionStart suite `STATUS: PASSED`.

- [ ] **Step 3: Commit**

```bash
git add skills/writing-plans/SKILL.md
git commit -m "Add Codex plan review gate to writing-plans"
```

---

## Task 4: Subagent-driven-development code gates (per-task + final)

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`

**Interfaces:**
- Consumes: `codex-review-gate.md` via `../requesting-code-review/codex-review-gate.md`. Per-task review uses the recorded task BASE SHA; final review uses the branch merge-base.

- [ ] **Step 1: Add the per-task gate node to the process digraph**

In `skills/subagent-driven-development/SKILL.md` "The Process" digraph, the
per-task cluster contains:

```dot
        "Task reviewer reports spec ✅ and quality approved?" [shape=diamond];
        "Dispatch fix subagent for Critical/Important findings" [shape=box];
        "Mark task complete in todo list and progress ledger" [shape=box];
```

Add a node after the "Mark task complete..." declaration line:

```dot
        "Codex task code gate\n(Claude Code; degrade if absent)" [shape=box];
```

Then replace this edge:

```dot
    "Task reviewer reports spec ✅ and quality approved?" -> "Mark task complete in todo list and progress ledger" [label="yes"];
```

with:

```dot
    "Task reviewer reports spec ✅ and quality approved?" -> "Codex task code gate\n(Claude Code; degrade if absent)" [label="yes"];
    "Codex task code gate\n(Claude Code; degrade if absent)" -> "Mark task complete in todo list and progress ledger";
```

- [ ] **Step 2: Add the final-review gate node to the digraph**

In the same digraph, replace this edge:

```dot
    "Dispatch final code reviewer subagent (../requesting-code-review/code-reviewer.md)" -> "Use hyperpowers:finishing-a-development-branch";
```

with:

```dot
    "Dispatch final code reviewer subagent (../requesting-code-review/code-reviewer.md)" -> "Codex final code gate\n(Claude Code; degrade if absent)";
    "Codex final code gate\n(Claude Code; degrade if absent)" -> "Use hyperpowers:finishing-a-development-branch";
```

And add the new node declaration directly after the existing finishing-branch
declaration line (which reads
`"Use hyperpowers:finishing-a-development-branch" [shape=box style=filled fillcolor=lightgreen];`):

```dot
    "Codex final code gate\n(Claude Code; degrade if absent)" [shape=box];
```

- [ ] **Step 3: Add the prose section**

In the same file, immediately before the `## File Handoffs` heading, insert:

```markdown
## Codex Review Gate (Claude Code only)

When running under Claude Code, add a Codex **code** review gate at two points,
following [../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md).
Probe once per skill run and reuse the result; if Codex is absent, emit the
no-Codex notice once and run both gates as no-ops.

- **Per task:** after the task reviewer approves (spec ✅ and quality approved) and
  before marking the task complete, run the gate with `--base <the task BASE you
  recorded before dispatching the implementer>`. Route blocking findings through the
  same fix-subagent loop you already use, then re-review per the gate contract.
- **Final whole-branch:** after the final code-reviewer subagent and before
  hyperpowers:finishing-a-development-branch, run the gate with `--base <branch
  merge-base, e.g. git merge-base main HEAD>`. Resolve blocking findings (one fix
  subagent with the complete list, per this skill's existing guidance) before finishing.

The gate's round cap bounds the loop; if it is hit with unresolved blocking
findings, surface them rather than looping.

```

- [ ] **Step 4: Verify references resolve and the skill still parses**

Run:
```bash
test -f "$(cd skills/subagent-driven-development && readlink -f ../requesting-code-review/codex-review-gate.md)" && echo "ref OK"
grep -n "Codex Review Gate (Claude Code only)\|Codex task code gate\|Codex final code gate" skills/subagent-driven-development/SKILL.md
bash tests/hooks/test-session-start.sh
```
Expected: `ref OK`; grep shows the new section heading and both digraph nodes; SessionStart suite `STATUS: PASSED`.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md
git commit -m "Add Codex per-task and final code review gates to SDD"
```

---

## Task 5: Requesting-code-review code gate

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md`

**Interfaces:**
- Consumes: `codex-review-gate.md` (same skill dir) via `codex-review-gate.md`. Uses the same `{BASE_SHA}`/`{HEAD_SHA}` range the Claude reviewer used.

- [ ] **Step 1: Insert the gate after "Act on feedback"**

In `skills/requesting-code-review/SKILL.md`, the "## How to Request" section ends
with step 3:

```markdown
**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)
```

Immediately after that block (before the `## Example` heading), insert:

```markdown
**4. Codex review gate (Claude Code only):**
After acting on the Claude reviewer's feedback and before declaring the review
complete, run the Codex review gate over the same `{BASE_SHA}`..`{HEAD_SHA}` range
as a **code** review. Follow [codex-review-gate.md](codex-review-gate.md): probe
availability; if Codex is present, resolve its blocking findings in the fix loop;
if absent, emit the no-Codex notice and finish. This gate never blocks completion —
at worst it is skipped.
```

- [ ] **Step 2: Verify the reference resolves and the skill still parses**

Run:
```bash
test -f skills/requesting-code-review/codex-review-gate.md && echo "ref OK"
grep -n "Codex review gate (Claude Code only)" skills/requesting-code-review/SKILL.md
bash tests/hooks/test-session-start.sh
```
Expected: `ref OK`; grep shows the new step; SessionStart suite `STATUS: PASSED`.

- [ ] **Step 3: Commit**

```bash
git add skills/requesting-code-review/SKILL.md
git commit -m "Add Codex review gate to requesting-code-review"
```

---

## Task 6: Documentation — prerequisite, policy, overlap

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:** none (prose only).

- [ ] **Step 1: Add the prerequisite to the README Claude Code section**

In `README.md`, the "### Claude Code" section currently reads:

```markdown
### Claude Code

- Add this repository as a plugin marketplace:

  ```bash
  /plugin marketplace add scott-arne/hyperpowers
  ```

- Install the plugin from it:

  ```bash
  /plugin install hyperpowers@hyperpowers
  ```
```

Append, directly after the install command block and before the next `###` heading:

```markdown
- **Prerequisite for Codex review gates:** Hyperpowers' spec, plan, and code review
  steps will additionally ask [codex-plugin-cc](https://github.com/openai/codex-plugin-cc)
  to review the work when it is installed. Without it, the skills work normally but
  skip the Codex review (you'll see a one-line notice). To enable it:

  ```bash
  /plugin marketplace add openai/codex-plugin-cc
  /plugin install codex@openai-codex
  /reload-plugins
  /codex:setup
  ```

  Requires Node 18.18+ and the Codex CLI (`npm install -g @openai/codex`) with
  ChatGPT or OpenAI API authentication.

  > **Overlap note:** codex-plugin-cc also offers its own optional Stop-time review
  > gate (`/codex:setup --enable-review-gate`). Hyperpowers' gates are independent of
  > it. Enabling both means code is reviewed by Codex twice at stop time.
```

- [ ] **Step 2: Reconcile the dependency policy in CLAUDE.md**

In `CLAUDE.md`, under "## What Stays Out of Core Skills", the first bullet reads:

```markdown
- **Third-party dependencies.** The plugin is zero-dependency by design. If a change needs an external tool or service, it belongs in its own plugin.
```

Replace it with:

```markdown
- **Third-party dependencies.** Upstream Superpowers is zero-dependency by design. This fork deliberately diverges: it takes targeted Claude Code dependencies where they add value — the first is [codex-plugin-cc](https://github.com/openai/codex-plugin-cc), which powers the optional Codex review gates (spec, plan, code). Such dependencies must degrade cleanly (skills stay fully functional when the dependency is absent) and stay scoped to the harness where they apply. General-purpose, cross-harness skills should still avoid external tools so they remain mergeable with upstream.
```

- [ ] **Step 3: Verify and check version-audit is undisturbed**

Run:
```bash
grep -n "codex-plugin-cc" README.md CLAUDE.md
bash scripts/bump-version.sh --check
```
Expected: grep shows the README prerequisite and the CLAUDE.md policy line; version check `All declared files are in sync at 6.0.2`.

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "Document codex-plugin-cc prerequisite and fork dependency policy"
```

---

## Task 7: Full regression run + skill-behavior validation

**Files:** none (validation only).

**Interfaces:** none. Deliverable: recorded evidence that automated suites pass and the gate behaves correctly; capture it in the branch/PR description (do not commit a results file).

- [ ] **Step 1: Run the full automated test battery**

Run each and confirm the stated result:
```bash
bash tests/codex-review-gate/test-codex-available.sh    # STATUS: PASSED
bash tests/hooks/test-session-start.sh                  # STATUS: PASSED
bash tests/shell-lint/test-lint-shell.sh                # STATUS: PASSED
bash tests/kimi/run-tests.sh                            # manifest looks good
bash tests/antigravity/run-tests.sh                     # All Antigravity tests passed
bash tests/opencode/run-tests.sh                        # STATUS: PASSED (non-integration)
node --test tests/pi/test-pi-extension.mjs              # pass 6 / fail 0
bash scripts/bump-version.sh --check                    # in sync at 6.0.2
```
Expected: every suite passes. Record the outputs.

- [ ] **Step 2: Probe behavior sanity check on this machine**

codex-plugin-cc is installed here, so the probe should resolve and report ready:
```bash
bash skills/requesting-code-review/scripts/codex-available.sh; echo "exit=$?"
```
Expected: prints the Codex install path and `exit=0`. (If Codex is unauthenticated, `exit=1` is the correct degrade result — note which occurred.)

- [ ] **Step 3: Skill-behavior validation (writing-skills discipline)**

Per CLAUDE.md, skill-content changes require behavioral evidence. The eval harness
lives in `evals/` (a separate repo, absent from this checkout). If `evals/` is
present and set up, run the brainstorming, writing-plans, SDD, and
requesting-code-review scenarios and compare before/after for: (a) the gate fires
after self-review and before handback when Codex is available; (b) clean degrade
with the notice when Codex is absent; (c) the round cap is honored; (d) one severity
vocabulary in handback summaries.

If `evals/` is absent, run the manual acceptance check instead: in a clean Claude
Code session on this branch, brainstorm a trivial feature and confirm the spec gate
runs (Codex present) or emits the notice (Codex disabled via an unauthenticated
state). Capture the transcript as the evidence.

Expected: documented evidence that all four gates behave per the contract in both
the available and degraded states.

- [ ] **Step 4: No commit**

This task produces validation evidence, not code. Do not create or commit a results
file; record the evidence in the branch/PR description.

---

## Self-Review

**1. Spec coverage** — every spec section maps to a task:
- Trigger = companion script (spec §Decisions 1) → Task 1 probe + gate doc recipes.
- Run-time availability probe via `setup --json` `ready` + path resolution (spec §Availability detection) → Task 1.
- Gate placements: brainstorming/writing-plans/SDD per-task+final/requesting-code-review (spec §Gate placements) → Tasks 2–5.
- Gate behavior contract: probe → invoke → interpret → fix-loop(cap) → push-back → handback (spec §Gate behavior contract) → Task 1 doc; consumed by 2–5.
- Severity reconciliation (spec §Severity reconciliation) → Task 1 doc, Global Constraints.
- No-Codex notice, per-skill not session-start (spec §No-Codex-review warning) → Task 1 doc; emitted by 2–5.
- Shared implementation surface (spec §Shared implementation surface) → Task 1 (`codex-review-gate.md` + probe in requesting-code-review).
- Docs: README prerequisite, CLAUDE.md policy, overlap note (spec §Documentation) → Task 6.
- Testing: hermetic plumbing tests + eval/acceptance (spec §Testing) → Task 1 tests, Task 7.
- Claude-Code-only, fail-safe degrade, independent of Codex Stop gate (spec §Decisions 4,6; §Out of scope) → Global Constraints; Task 6 overlap note.
- Risks (coupling, cost, thrash, severity, skill regression) → Global Constraints (single surface, `--wait`, cap=2, mapping, minimal edits).

**2. Placeholder scan** — no TBD/TODO/"handle edge cases"/"similar to Task N". Every code step shows complete content; every skill edit gives exact anchor + replacement.

**3. Type/identifier consistency** — `codex@openai-codex`, `installPath`, `ready`, `HYPERPOWERS_PLUGINS_FILE`, `HYPERPOWERS_CODEX_SETUP_JSON`, `CODEX_PATH`, `--base`, `--wait`, and the `codex-available.sh` / `codex-review-gate.md` paths are used identically across the probe (Task 1), the gate doc (Task 1), and every consumer (Tasks 2–5). Severity mapping (critical→Critical, high→Important, medium/low→Minor; blocking=Critical+Important) and round cap (2) are stated once in Global Constraints and referenced, not redefined.


---

## Post-Implementation: Eval Validation Status (2026-06-17)

The feature was implemented (Tasks 1–7) and merged to `main` (merge `0f3b477`).
This section records the skill-behavior eval work done afterward.

### Bug found by authoring evals (fixed — commit `b5faff2`)

Writing the eval scenarios surfaced a real defect: `codex-review-gate.md` told the
agent to run the probe by a **repo-relative** path
(`bash skills/requesting-code-review/scripts/codex-available.sh`). That only
resolves in a hyperpowers dev checkout. When hyperpowers runs as an **installed
plugin**, the agent's cwd is the user's project, so the probe was never found and
the gate **silently always-degraded** — the Codex review would never run for any
real installed user.

Fix: invoke the probe via `${CLAUDE_PLUGIN_ROOT}/skills/requesting-code-review/scripts/codex-available.sh`
(with a dev-checkout fallback noted in the contract). Also hardened the probe's
install resolution to pick the newest registry record whose `codex-companion.mjs`
actually exists on disk (skips stale/uninstalled version records), with two new
regression tests. All 7 probe tests pass; shellcheck clean.

### Scenarios authored (in the evals/ clone — NOT committed)

The eval harness is `prime-radiant-inc/superpowers-evals` (cloned into the
gitignored `evals/`; it is a TypeScript/Bun "quorum" harness, not the Python/uv
layout the older docs describe). Two degrade-path scenarios were authored, hand-
validated against the harness's `checkScenario` contract (frontmatter, exec bits,
functions-only checks.sh, known helpers, valid verbs):

- `evals/scenarios/codex-gate-spec-degrades-without-codex/` — brainstorming spec
  gate degrades cleanly (produces a spec, reaches handback) when codex-plugin-cc
  is absent.
- `evals/scenarios/codex-gate-code-review-degrades-without-codex/` —
  requesting-code-review code gate degrades cleanly (delivers the review) when
  codex-plugin-cc is absent.

These files live in the upstream evals clone, which hyperpowers gitignores. They
are NOT committed anywhere (committing fork-specific scenarios to upstream's repo
is out of scope per CLAUDE.md).

### Why only the degrade path, and what is NOT yet validated

The harness pins each agent's `HOME` to a throwaway dir and stages only the
hyperpowers plugin — **codex-plugin-cc is never present in the run home**, so the
probe always degrades there. That makes the degrade path (the more important
safety property) directly testable, but means:

- **The "Codex present" branch is NOT eval-covered.** Testing it requires a new
  `needsSuperpowersRoot`-style setup-helper (TypeScript, in the evals repo) that
  seeds a fake codex-plugin-cc install + a stubbed `codex-companion.mjs` into the
  run home's `.claude/plugins/`. Deferred.
- The gate's fix-loop, severity mapping, and round-cap behaviors are only covered
  by the structural review + the probe's unit tests, not by a live eval.

### Blockers to actually RUNNING the evals (none run yet)

1. **No Bedrock support in the harness.** The Claude launcher hardcodes
   `ANTHROPIC_API_KEY`; this machine uses Bedrock (`CLAUDE_CODE_USE_BEDROCK=1`).
   Running requires either a direct `ANTHROPIC_API_KEY` or patching the harness's
   launcher/agent-yaml for Bedrock (modifies the upstream evals repo).
2. **`bun` is not installed** — required for `quorum check` and `quorum run`.

### To run later

```bash
brew install bun                       # prerequisite
cd evals && bun install
export SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers
export ANTHROPIC_API_KEY=sk-...        # harness has no Bedrock path
bun run quorum check codex-gate-spec-degrades-without-codex codex-gate-code-review-degrades-without-codex
bun run quorum run scenarios/codex-gate-spec-degrades-without-codex --coding-agent claude
bun run quorum run scenarios/codex-gate-code-review-degrades-without-codex --coding-agent claude
```
