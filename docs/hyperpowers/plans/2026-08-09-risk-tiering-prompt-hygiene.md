# Risk-Tiered Review & SDD Prompt Hygiene (SP3b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 6.6.0: plan-time risk tiers that let effective-low tasks skip the per-task Codex gate with a durable attributed record, the SDD prompt-hygiene bundle (fixer template + contract suite + verify-subagent-claims rule), retirement of verification-before-completion, and two live eval scenarios.

**Architecture:** The tier is a plan line read at dispatch; the skip is an `ungated-ledger` event (new informational class `tier-skip` with a class-specific non-sweepable override); telemetry counts it exclusively. All behavior lives in skill docs and the two existing scripts — no new runtime machinery.

**Tech Stack:** Bash + node one-liners (scripts), markdown skills, bash needle suites, quorum eval scenarios (evals fork checkout).

## Global Constraints

- Spec: `docs/hyperpowers/specs/2026-08-09-risk-tiering-prompt-hygiene-design.md` — §3.3's attribution contract and §3.2's record contract are copy-exact requirements.
- New ledger class name is exactly `tier-skip`; flags exactly `--tier-declared` / `--tier-effective`; event fields exactly `tierDeclared` / `tierEffective`; valid tier values exactly `low|standard|high`.
- `class == tier-skip` forces `sweepable=false` regardless of gate; every OTHER class keeps today's gate-derived sweepability byte-identical.
- Telemetry: tier-skips count ONLY in the new `tierSkips` metric — the pending, swept, doc-recorded, and degrades buckets all exclude them.
- Progress-ledger escalation/fallback line shape, exact: `Task N: tier declared <low|standard|high|none> -> effective <standard|high> (<trigger phrase>)`.
- Tier plan line shape, exact: `**Risk tier:** low|standard|high — <one-line rationale>`.
- Tier-skip summary artifact name, exact: `tier-skips.md` (SDD scratch dir).
- The Claude task reviewer and the final whole-branch train are NEVER relaxed by tier; no doc wording may permit lowering a declared tier.
- This plan itself declares no tiers: the machinery ships in this release, so every task below runs today's full train (spec §3.2 fail-closed default).
- Version bump to 6.6.0 only in the final parent-repo task via `scripts/bump-version.sh`.
- Never commit anything under `docs/hyperpowers/`; stage only named files; no AI-attribution lines in commits.
- Controller-run micro-tests (spec §7): (a) tier-baiting refusal and (b) skip-then-append are run by the controller during execution and recorded in the execution ledger — they are not subagent steps.

---

### Task 1: ungated-ledger — `tier-skip` class, tier flags, sweepable override

**Files:**
- Modify: `skills/requesting-code-review/scripts/ungated-ledger`
- Test: `tests/codex-review-gate/test-ungated-ledger.sh`

**Interfaces:**
- Consumes: existing append/pending/mark-swept contract (unchanged for existing classes).
- Produces: `append --class tier-skip --gate task --base SHA --head SHA --tier-declared low --tier-effective low --note "Task N: <rationale>"` → event with `class:"tier-skip"`, `sweepable:false`, `tierDeclared`, `tierEffective`. Tasks 2, 3, 5 rely on these exact names.

- [ ] **Step 1: Write the failing tests (RED)**

Append to `tests/codex-review-gate/test-ungated-ledger.sh`, immediately BEFORE the final `echo` / `ALL PASS` summary block, reusing the file's existing fixture vars (`$UL`, `$repo`, `$base_sha`, `$head_sha`, `$key`, `$XDG_CACHE_HOME`) and helpers (`expect`, `pass`, `fail`):

```bash
# --- 6.6.0: tier-skip class + tier flags (spec 3.3) ---
before_ts="$(bash "$UL" pending --count "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
out="$(bash "$UL" append --class tier-skip --gate task --base "$base_sha" --head "$head_sha" \
  --tier-declared low --tier-effective low --note "Task 7: needle-only additions" "$repo")"
expect "$out" '"ok":true' "tier-skip append succeeds"
last="$(tail -1 "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl")"
expect "$last" '"class":"tier-skip"' "event carries the tier-skip class"
expect "$last" '"sweepable":false' "tier-skip is non-sweepable despite gate task"
expect "$last" '"tierDeclared":"low"' "declared tier round-trips"
expect "$last" '"tierEffective":"low"' "effective tier round-trips"
expect "$last" '"note":"Task 7:' "note begins with the task identifier"
expect "$last" '"base":"' "tier-skip records the task base"
expect "$last" '"head":"' "tier-skip records the task head"
expect "$last" '"gate":"task"' "tier-skip records the gate"
expect "$last" '"id":"' "tier-skip carries the event id"
expect "$last" '"ts":"' "tier-skip carries the timestamp"
expect "$last" '"repo":"' "tier-skip carries the repo root"
after_ts="$(bash "$UL" pending --count "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
[ "$after_ts" -eq "$before_ts" ] && pass "tier-skip never enters pending" || fail "tier-skip never enters pending (before=$before_ts after=$after_ts)"
bash "$UL" append --class tier-skip --gate task --base "$base_sha" --head "$head_sha" \
  --tier-declared bogus --note x "$repo" >/dev/null 2>&1 && fail "invalid tier value exits 2" || pass "invalid tier value exits 2"
bash "$UL" append --class tier-skip --gate task --tier-declared low --tier-effective low --note x "$repo" >/dev/null 2>&1 \
  && fail "tier-skip without base/head exits 2" || pass "tier-skip without base/head exits 2"
out="$(bash "$UL" append --class degraded-gate --gate task --base "$base_sha" --head "$head_sha" --status not-ready --note bi-check "$repo")"
last="$(tail -1 "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl")"
expect "$last" '"sweepable":true' "existing classes keep gate-derived sweepability"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/codex-review-gate/test-ungated-ledger.sh`
Expected: the new checks FAIL (first failure: "tier-skip append succeeds" — the class is rejected with the current `--class must be ...` message); all pre-existing checks PASS.

- [ ] **Step 3: Implement**

In `skills/requesting-code-review/scripts/ungated-ledger`:

(a) Usage comment — replace the append line in the header block:

```bash
#   append --class degraded-gate|backstop-fix|incomplete-review|tier-skip
#          --gate spec|plan|task|final|adhoc
#          [--base SHA --head SHA] [--status TOKEN] [--gate-dir P]
#          [--tier-declared low|standard|high] [--tier-effective low|standard|high]
#          [--note S] [repo-dir]              -> {"ok":true,"id":"..."}
```

and append to the sweepable-derivation comment (the `# sweepable derives from --gate:` block): `class tier-skip overrides to sweepable=false regardless of gate (approved skip, informational).`

(b) Flag parsing — extend the init line and the case list:

```bash
class=""; gate=""; base=""; head=""; status=""; gatedir=""; note=""; ref=""; verdict=""; count_only=0; tierdec=""; tiereff=""
```

```bash
    --tier-declared) tierdec="$2"; shift 2 ;;
    --tier-effective) tiereff="$2"; shift 2 ;;
```

(c) Append validation — replace the class case line with:

```bash
    case "$class" in degraded-gate|backstop-fix|incomplete-review|tier-skip) : ;; *)
      echo "ungated-ledger: --class must be degraded-gate|backstop-fix|incomplete-review|tier-skip" >&2; exit 2 ;; esac
    for tv in "$tierdec" "$tiereff"; do
      case "$tv" in ''|low|standard|high) : ;; *)
        echo "ungated-ledger: tier values must be low|standard|high" >&2; exit 2 ;; esac
    done
```

(d) Sweepable override — immediately AFTER the existing `case "$gate" in ... esac` block (so gate validation and the task/final/adhoc base/head requirement still apply first):

```bash
    # Approved-skip records are informational: never pending, never swept.
    [ "$class" = "tier-skip" ] && sweepable=false
```

(e) Event writer — replace the node block and its argument list:

```bash
    node -e '
      const [id, cls, gate, ts, repo, base, head, status, sweepable, gateDir, tierDeclared, tierEffective, note] = process.argv.slice(1);
      const e = { v: 1, id, event: "ungated", class: cls, gate, ts, repo,
        base: base || null, head: head || null, status: status || null,
        sweepable: sweepable === "true", gateDir: gateDir || null, note };
      if (tierDeclared) e.tierDeclared = tierDeclared;
      if (tierEffective) e.tierEffective = tierEffective;
      process.stdout.write(JSON.stringify(e) + "\n");
    ' "$id" "$class" "$gate" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reporoot" \
      "$base" "$head" "$status" "$sweepable" "$gatedir" "$tierdec" "$tiereff" "${note}${LOCK_NOTE}" >> "$ledger" \
      || { echo "ungated-ledger: write failed" >&2; exit 2; }
```

Note the field-name check: `"note":"Task 7:` in the tests asserts JSON key order keeps `note` before the conditional tier fields — the block above preserves that (tier fields are appended after `e` is built).

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/codex-review-gate/test-ungated-ledger.sh`
Expected: ALL PASS (29 pre-existing + 12 new).

- [ ] **Step 5: Lint and commit**

```bash
bash scripts/lint-shell.sh
git add skills/requesting-code-review/scripts/ungated-ledger tests/codex-review-gate/test-ungated-ledger.sh
git commit -m "feat(ledger): tier-skip class with tier attribution and non-sweepable override"
```

---

### Task 2: gate-telemetry — exclusive `tierSkips` metric

**Files:**
- Modify: `skills/requesting-code-review/scripts/gate-telemetry`
- Test: `tests/codex-review-gate/test-gate-telemetry.sh`

**Interfaces:**
- Consumes: Task 1's event shape (`class:"tier-skip"`, `sweepable:false`).
- Produces: per-repo markdown line `- Tier skips: K`; fleet line `- Tier skips: K`; `tierSkips` key on each repo object and the aggregate in `--json`.

- [ ] **Step 1: Write the failing tests (RED)**

Append to `tests/codex-review-gate/test-gate-telemetry.sh` before its summary block, following its existing fixture pattern (the suite already builds a fixture ledger under a scratch `XDG_CACHE_HOME`; extend that ledger):

```bash
# --- 6.6.0: tierSkips is exclusive (spec 3.4) ---
LEDGER="$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl"
mkdir -p "$(dirname "$LEDGER")"
cat >> "$LEDGER" <<'EOFEV'
{"v":1,"id":"ts-1","event":"ungated","class":"tier-skip","gate":"task","ts":"2026-08-09T00:00:00Z","repo":"/tmp/r","base":"a","head":"b","status":null,"sweepable":false,"gateDir":null,"note":"Task 1: mech","tierDeclared":"low","tierEffective":"low"}
EOFEV
out="$( (cd "$repo" && bash "$GT") )"
expect "$out" "Tier skips: 1" "markdown reports the tier-skip count"
json="$( (cd "$repo" && bash "$GT" --json) )"
expect "$json" '"tierSkips":1' "json carries tierSkips"
# Exclusivity: the tier-skip event must not raise doc-recorded or pending.
docrec_before_note="doc-recorded count must equal the non-tier-skip sweepable=false events only"
expect "$out" "doc-recorded: 0" "$docrec_before_note"
```

Adapt the `doc-recorded: 0` expectation to the fixture's actual pre-existing count of `sweepable:false` NON-tier-skip events (if the fixture already contains N doc-recorded events, expect `doc-recorded: N` — the point is the count does NOT increase when the tier-skip line is added; add the tier-skip line LAST and assert the same N as before).

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh`
Expected: "markdown reports the tier-skip count" and '"tierSkips":1' FAIL; all pre-existing checks PASS.

- [ ] **Step 3: Implement**

In `skills/requesting-code-review/scripts/gate-telemetry`:

(a) Per-repo init (the object literal containing `unsweepableClass: 0`): add `tierSkips: 0,`.

(b) Event classification — replace the ungated-event branch body:

```js
        if (e.event === "ungated") {
          if (e.class === "tier-skip") {
            // Exclusive metric: approved skips never count as degraded,
            // doc-recorded, or pending (spec 3.4).
            r.tierSkips++;
          } else {
            if (e.class === "degraded-gate" && e.status) r.degrades[e.status] = (r.degrades[e.status] || 0) + 1;
            if (e.sweepable === false) r.unsweepableClass++;
            else if (!sweptRefs.has(e.id)) {
              r.pending++;
              const t = Date.parse(e.ts);
              if (!Number.isNaN(t) && (oldestTs === null || t < oldestTs)) oldestTs = t;
            }
          }
        } else if (e.event === "swept") {
```

(c) Aggregate: add `tierSkips: 0,` to the `agg` literal and `agg.tierSkips += r.tierSkips;` beside `agg.pending += r.pending;`.

(d) Markdown: after the per-repo `Fix-cycle rate` line add `console.log(`- Tier skips: ${r.tierSkips}`);` and after the fleet `Fix-cycle rate` line add `console.log(`- Tier skips: ${agg.tierSkips}`);`.

- [ ] **Step 4: GREEN + lint + commit**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh` — ALL PASS. Then:

```bash
bash scripts/lint-shell.sh
git add skills/requesting-code-review/scripts/gate-telemetry tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "feat(telemetry): exclusive tier-skip count per repo and fleet"
```

---

### Task 3: gate doc — tier applicability + final-gate skip visibility

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§3 per-task recipe area ~line 322; final whole-branch recipe ~line 337)
- Test: `tests/codex-review-gate/test-gate-contract.sh`

**Interfaces:**
- Consumes: Task 1's append command shape.
- Produces: the applicability contract Task 5's SDD text cross-references; the `<TIER_SKIPS_PATH>` input the final recipes carry.

- [ ] **Step 1: Needles (RED)**

Add to the "Review fidelity" needle region of `tests/codex-review-gate/test-gate-contract.sh`:

```bash
assert_contains "$GATE" "the Claude task reviewer and the final whole-branch gates never tier off" \
  "tier relaxation is scoped to the per-task gate"
assert_contains "$GATE" 'record the skip with `ungated-ledger append --class tier-skip' \
  "skips are durably recorded"
assert_contains "$GATE" "<TIER_SKIPS_PATH>" \
  "final recipes deliver the tier-skip summary"
```

RED run: 3 FAIL, rest PASS.

- [ ] **Step 2: Amend the doc**

(a) Immediately after the **Per-task code** recipe's command/context block, insert one paragraph:

```markdown
**Tier applicability (SDD tasks only).** Per-task code gates run for
standard- and high-tier tasks. An SDD task whose EFFECTIVE tier is low —
declared at plan time, reviewed by the plan gate, never lowered at
dispatch, with no escalation trigger fired — skips this gate entirely:
record the skip with `ungated-ledger append --class tier-skip --gate task
--base <TASK_BASE> --head <HEAD> --tier-declared low --tier-effective low
--note "Task N: <rationale>"` and move on; the Claude task reviewer and the final whole-branch gates never tier off. Ad-hoc code-review requests have no tier and always run.
```

(b) In the **Final whole-branch code** recipe: add `Tier-skip summary, if any: <TIER_SKIPS_PATH>.` to the focus-string context list (beside the Minor findings ledger input), and after the recipe add the sentence: `When any task skipped its per-task gate, pass the tier-skip summary file as <TIER_SKIPS_PATH> AND include it among the final dossier's --adjudications inputs, so both the prompt and the delivered dossier carry it.`

- [ ] **Step 3: GREEN + commit**

`bash tests/codex-review-gate/test-gate-contract.sh` — ALL PASS (114 + 3).

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(gate): per-task tier applicability and final-gate tier-skip delivery"
```

---

### Task 4: SDD hygiene — fixer template, verify rule, contract suite

**Files:**
- Create: `skills/subagent-driven-development/fix-subagent-prompt.md`
- Modify: `skills/subagent-driven-development/SKILL.md` (fix-dispatch bullets ~198, ~212, ~218; new subsection after "Handling Reviewer ⚠️ Items")
- Modify: `skills/subagent-driven-development/implementer-prompt.md` (Report Format section)
- Test: Create `tests/sdd/test-sdd-contract.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `tests/sdd/test-sdd-contract.sh` (Task 5 extends it); the template path `fix-subagent-prompt.md` SKILL.md names.

- [ ] **Step 1: Create the suite with hygiene needles (RED)**

Create `tests/sdd/test-sdd-contract.sh` (copy the `assert_contains`/`assert_not_contains` flatten harness verbatim from `tests/codex-review-gate/test-gate-contract.sh` lines 1–48, adjusting the file vars):

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
IMPL="$REPO_ROOT/skills/subagent-driven-development/implementer-prompt.md"
REVW="$REPO_ROOT/skills/subagent-driven-development/task-reviewer-prompt.md"
FIXP="$REPO_ROOT/skills/subagent-driven-development/fix-subagent-prompt.md"
WPLANS="$REPO_ROOT/skills/writing-plans/SKILL.md"
# ... pass/fail/assert_contains/assert_not_contains verbatim from the gate suite ...

echo "SDD prompt-surface contract tests"
# SKILL.md — dispatch discipline
assert_contains "$SDD" "Always specify the model explicitly when dispatching a subagent." "explicit model is mandatory"
assert_contains "$SDD" "A dispatch prompt describes one task, not the session's history." "no pasted-history dispatches"
assert_contains "$SDD" "which silently drops all but the last commit" "BASE not HEAD~1 (review package)"
assert_contains "$SDD" "which silently truncates multi-commit tasks" "BASE not HEAD~1 (reviewer handoff)"
# SKILL.md — verify-subagent-claims (6.6.0)
assert_contains "$SDD" "Subagent reports are claims, not evidence" "verify rule exists"
assert_contains "$SDD" "re-runs the named covering test command directly" "controller re-runs covering tests"
assert_contains "$SDD" "no covering command:" "no-test path exists"
assert_contains "$SDD" "fix-subagent-prompt.md" "fix dispatches use the template"
# implementer template
assert_contains "$IMPL" "DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT" "four statuses"
assert_contains "$IMPL" "RED: command run" "TDD red evidence"
assert_contains "$IMPL" "GREEN: command run" "TDD green evidence"
assert_contains "$IMPL" "under 15 lines" "terse return contract"
assert_contains "$IMPL" "Write your full report to" "report-file contract"
assert_contains "$IMPL" "the controller re-runs your covering command" "implementer rerun warning"
# reviewer template
assert_contains "$REVW" "## Part 1: Spec Compliance" "reviewer spec part"
assert_contains "$REVW" "## Part 2: Code Quality" "reviewer quality part"
assert_contains "$REVW" "Cannot verify from diff" "cannot-verify semantics"
# fixer template
assert_contains "$FIXP" "stage ONLY the files named in this dispatch" "fixer stages only named files"
assert_contains "$FIXP" 'NEVER `git add -A`' "fixer never adds all"
assert_contains "$FIXP" "no covering command:" "fixer no-test path"
assert_contains "$FIXP" "APPEND your fix note" "fixer appends to the task report"
assert_contains "$FIXP" "the controller re-runs your covering command" "fixer rerun warning"

echo
[ "$FAILURES" -eq 0 ] && { echo "STATUS: PASSED"; exit 0; } || { echo "STATUS: FAILED ($FAILURES)"; exit 1; }
```

RED run (`bash tests/sdd/test-sdd-contract.sh`): the four pre-existing SKILL/template lines PASS (they exist today — verify; if a phrasing differs, correct the needle to the live line rather than editing the doc); every 6.6.0 needle FAILS.

- [ ] **Step 2: Create `fix-subagent-prompt.md`**

```markdown
# Fix Subagent Prompt Template

Use this template for EVERY fix dispatch — per-task review findings, Codex
gate findings, and final-review fix waves alike. One fixer per findings
wave, never one per finding.

​```
Subagent (general-purpose):
  description: "Fix findings for Task N: [task name]"
  model: [MODEL — REQUIRED: match the smallest model the fix demands;
         single-file mechanical fixes take the cheapest tier]
  prompt: |
    You are fixing review findings for Task N: [task name].

    ## Findings (complete list for this wave)

    [EVERY finding this wave must address — severity, location, issue,
    and the reviewer's recommendation. Never dispatch a partial list.]

    ## Scope

    Files you may touch: [exact paths]. If the fix genuinely requires
    another file, STOP and report BLOCKED with the reason — do not expand
    scope on your own.

    ## Context

    Task brief: [BRIEF_FILE]   Implementer report so far: [REPORT_FILE]

    ## Tests

    Covering command(s): [exact command(s) — OR the line
    `no covering command: <rationale>` plus what the controller will do
    instead]. When commands are named: re-run them after your fix and put
    the output in your report. The controller re-runs your covering
    command; a report that doesn't match its output is a failed task.

    ## Commit hygiene

    - stage ONLY the files named in this dispatch
    - NEVER `git add -A` or `git add .`
    - nothing under docs/ planning paths (specs/plans) may be staged
    - no AI-attribution lines in the commit message

    ## Report

    APPEND your fix note to [REPORT_FILE]: what changed per finding, why,
    and the covering-test output. Then return ONLY: Status
    (DONE|BLOCKED), commit SHA + subject, one-line test summary.
​```
```

(Remove the zero-width characters around the inner fence when writing the file — the inner block is fenced code inside the template, matching the two existing templates' style.)

- [ ] **Step 3: Amend SKILL.md and implementer-prompt.md**

(a) SKILL.md — new subsection immediately after "## Handling Reviewer ⚠️ Items":

```markdown
## Subagent Reports Are Claims

Subagent reports are claims, not evidence. Before acting on a DONE report
or a fix report — dispatching the reviewer, re-running a gate, marking a
task complete — the controller re-runs the named covering test command
directly and compares the output against the report. A misreported result
is a failed task: re-dispatch with the discrepancy named, not a
bookkeeping correction.

Every implementer and fix dispatch names either its covering test
command(s) or an explicit `no covering command: <rationale>` line plus the
controller's substitute verification (read the diff against the brief;
render or grep the changed doc). A dispatch naming neither is malformed —
fix the dispatch, not the rule.
```

(b) SKILL.md — in the "Dispatch fix subagents for Critical and Important findings" bullet, the "Every fix dispatch carries the implementer contract" bullet, and the final-review "dispatch ONE fix subagent" bullet, add the sentence: `Compose the dispatch from [fix-subagent-prompt.md](fix-subagent-prompt.md).` (first bullet), `The template fix-subagent-prompt.md carries this contract — use it.` (second), and `Use fix-subagent-prompt.md for the wave dispatch.` (third).

(c) implementer-prompt.md — in the "## Report Format" section, after the "One-line test summary" bullet, add: `The controller re-runs your covering command; a report that doesn't match its output is a failed task.` (renders inside the template's prompt block).

- [ ] **Step 4: GREEN + commit**

`bash tests/sdd/test-sdd-contract.sh` — the writing-plans needles do not exist yet (they are Task 5's); this task's suite must contain ONLY the needles listed in Step 1, all PASS.

```bash
git add tests/sdd/test-sdd-contract.sh skills/subagent-driven-development/fix-subagent-prompt.md \
  skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/implementer-prompt.md
git commit -m "feat(sdd): fixer template, verify-subagent-claims rule, prompt-surface contract suite"
```

---

### Task 5: Tier doc surface — writing-plans rubric + SDD dispatch rules

**Files:**
- Modify: `skills/writing-plans/SKILL.md` (Task Structure ~line 80; Codex Plan Review Gate ~line 157)
- Modify: `skills/subagent-driven-development/SKILL.md` (new subsection before "## Codex Review Gate (Claude Code only)"; amend that section's "Per task" bullet)
- Test: `tests/sdd/test-sdd-contract.sh` (extend)

**Interfaces:**
- Consumes: Task 1's append command; Task 3's gate-doc applicability paragraph; Task 4's suite file.
- Produces: the tier-line format and rubric all future plans use; `tier-skips.md` artifact contract.

- [ ] **Step 1: Needles (RED)** — append to `tests/sdd/test-sdd-contract.sh`:

```bash
# tier system (6.6.0)
assert_contains "$WPLANS" '**Risk tier:** low|standard|high — <one-line rationale>' "plans declare a tier per task"
assert_contains "$WPLANS" "approval-authority code" "rubric names the high surface"
assert_contains "$WPLANS" "declared risk tier against the rubric" "plan gate reviews tiers"
assert_contains "$SDD" "may raise a tier" "escalation is expressible"
assert_contains "$SDD" "never lower a declared tier" "lowering is not expressible"
assert_contains "$SDD" "tier declared" "escalation record line format"
assert_contains "$SDD" "--class tier-skip" "skip appends the durable record"
assert_contains "$SDD" "tier-skips.md" "final review receives the skip list"
assert_contains "$SDD" "no escalation trigger fired" "skip precondition is explicit"
assert_contains "$SDD" "missing tier line" "fail-closed default is pinned"
```

RED: 10 FAIL.

- [ ] **Step 2: Amend writing-plans SKILL.md**

(a) In the Task Structure template, directly under the `### Task N: [Component Name]` line, add:

```markdown
**Risk tier:** low|standard|high — <one-line rationale>
```

(b) Before "## Task Structure", new subsection:

```markdown
## Risk Tier Rubric

Assign every task a risk tier on the line under its heading (rationale
mandatory for `low`):

- **high** — touches approval-authority code (verdict-normalize,
  gate-round, ungated-ledger, or any script whose output other machinery
  trusts), concurrency/locking, security surfaces, destructive git
  operations, or durable-record writers.
- **standard** — multi-file integration, new scripts, behavior-shaping
  skill/doc surgery, anything not clearly low or high. The default.
- **low** — single-file mechanical transcription where the plan contains
  the complete content to write; doc-reference or typo fixes; test-needle
  additions whose strings appear verbatim in the plan.

The tier dials ONLY the per-task Codex gate at execution time (low skips
it, recorded durably); the Claude task reviewer and the final whole-branch
train never tier off.
```

(c) In "## Codex Plan Review Gate", after the sentence listing what Codex reviews, add: `The plan review also checks each task's declared risk tier against the rubric above — a mis-tiered task is a blocking-eligible finding.`

- [ ] **Step 3: Amend SDD SKILL.md**

New subsection immediately before "## Codex Review Gate (Claude Code only)":

```markdown
## Risk Tiers (per-task Codex gate applicability)

Each plan task declares `**Risk tier:** low|standard|high — <rationale>`
under its heading; the task brief carries it. The effective tier starts as
the declared tier. You may raise a tier at any point — never lower a
declared tier, whatever the schedule pressure. Escalation triggers (any
one): DONE_WITH_CONCERNS with correctness doubts; any fix cycle (a
reviewer-driven fix that changes files — including a ⚠️-item resolution —
is a fix cycle); files touched outside the plan's Files list; anything on
the high rubric surfacing mid-task. Raise to high iff the trigger itself
is a high-rubric criterion; otherwise standard. Record every escalation or
fallback as one progress-ledger line:
`Task N: tier declared <low|standard|high|none> -> effective <standard|high> (<trigger phrase>)`.
A missing or unparseable tier line is `declared none -> effective standard
(missing tier line)` — full train, fail-closed.

The tier changes exactly one thing: an EFFECTIVE-LOW task — no escalation
trigger fired at any point — skips the per-task Codex gate after the task
reviewer approves. Record the skip immediately:
`bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/ungated-ledger" append --class tier-skip --gate task --base <TASK_BASE> --head <HEAD> --tier-declared low --tier-effective low --note "Task N: <rationale>"`.
Standard and high tiers run today's full train unchanged; so does every
non-SDD review. The Claude task reviewer always runs.

When any task skipped, write `tier-skips.md` in the SDD scratch dir — one
line per skip: `Task N: <rationale> (<base>..<head>)` — and hand its path
to the final code-reviewer dispatch (beside the Minor-findings list) and
to the final Codex gate as `<TIER_SKIPS_PATH>` plus a dossier
`--adjudications` input, per the gate doc's final recipe.
```

Amend the "## Codex Review Gate" section's **Per task** bullet: after "before marking the task complete, run the gate", insert "(standard/high effective tiers; an effective-low task skips it per Risk Tiers above, recording the tier-skip event instead)".

- [ ] **Step 4: GREEN + full both-suite check + commit**

`bash tests/sdd/test-sdd-contract.sh` and `bash tests/codex-review-gate/test-gate-contract.sh` — ALL PASS.

```bash
git add skills/writing-plans/SKILL.md skills/subagent-driven-development/SKILL.md tests/sdd/test-sdd-contract.sh
git commit -m "feat(sdd,plans): risk-tier rubric, escalate-only dispatch, recorded low-tier skip"
```

(Controller note, not a subagent step: micro-tests (a) tier-baiting and (b) skip-then-append run against this text after the task lands; outcomes recorded in the execution ledger.)

---

### Task 6: Retire verification-before-completion

**Files:**
- Delete: `skills/verification-before-completion/` (whole directory)
- Modify: `skills/systematic-debugging/SKILL.md:288`
- Modify: `skills/writing-skills/SKILL.md:401`
- Modify: `README.md:173`

- [ ] **Step 1: Enumerate references**

Run: `grep -rn "verification-before-completion" . --include="*.md" --include="*.sh" --include="*.json" --exclude-dir=.git --exclude-dir=evals --exclude-dir=node_modules | grep -v "^./docs/"`
(ALL of `docs/` is excluded: `docs/hyperpowers/` holds this project's own spec/plan, which legitimately discuss the retirement, and `docs/plans/` holds historical upstream planning records — the spec's repo-wide check names skills, hooks, scripts, tests, README, and plugin manifests, not historical records.)
Expected: exactly the skill's own SKILL.md plus THREE references — `skills/systematic-debugging/SKILL.md:288`, `skills/writing-skills/SKILL.md:401`, and `README.md:173` (`- **verification-before-completion** - Ensure it's actually fixed`, in the skills listing). If anything else appears, STOP and report BLOCKED with the list.

- [ ] **Step 2: Retarget the references**

`skills/systematic-debugging/SKILL.md` — replace the line:

```markdown
- **hyperpowers:verification-before-completion** - Verify fix worked before claiming success
```

with:

```markdown
- Verify the fix by re-running the original failing command and reading its
  output before claiming success (hyperpowers:test-driven-development
  covers the red-green regression discipline)
```

`skills/writing-skills/SKILL.md` — replace:

```markdown
**Examples:** TDD, verification-before-completion, designing-before-coding
```

with:

```markdown
**Examples:** TDD, designing-before-coding
```

`README.md` — delete the line `- **verification-before-completion** - Ensure it's actually fixed` from the skills listing (the discipline now lives inside subagent-driven-development, test-driven-development, and finishing-a-development-branch; the listing enumerates skills, and this one no longer exists).

- [ ] **Step 3: Delete and verify**

```bash
git rm -r skills/verification-before-completion
grep -rn "verification-before-completion" . --exclude-dir=.git --exclude-dir=evals --exclude-dir=node_modules | grep -v "^./docs/" || echo CLEAN
```
Expected: `CLEAN`.

- [ ] **Step 4: Sweep the suites and commit**

`bash tests/sdd/test-sdd-contract.sh && bash tests/codex-review-gate/test-gate-contract.sh` — ALL PASS (nothing pinned the retired skill).

```bash
git add skills/systematic-debugging/SKILL.md skills/writing-skills/SKILL.md README.md
git commit -m "refactor(skills): retire verification-before-completion into SDD, TDD, and finishing flows"
```
(The `git rm -r` in Step 3 already staged the deletion.)

---

### Task 7: Eval scenarios (evals fork checkout — cross-repo)

**Files (in the `evals/` checkout, committed to the hyperpowers-evals fork, NOT this repo):**
- Create: `evals/scenarios/codex-gate-risk-tier-discipline/{story.md,setup.sh,checks.sh}`
- Create: `evals/scenarios/codex-gate-lens-fanout-compliance/{story.md,setup.sh,checks.sh}`

**Interfaces:**
- Consumes: Task 1's event fields; Task 5's tier-line format; the 6.5.0 gate-doc artifacts (`dossier.md`, `gate-round.json`, `lens-*-prompt.md`).
- Produces: the evals-fork commit SHA recorded in the execution ledger.

- [ ] **Step 1: Model the fixtures on the existing scenarios**

Read `evals/scenarios/codex-gate-stale-broker-attributed/` (state seeding, `# coding-agents:` directive, pre/post DSL) and `evals/scenarios/codex-gate-code-review-runs-when-present/` (working-companion stub) in the checkout; reuse their setup mechanics verbatim where applicable.

- [ ] **Step 2: `codex-gate-risk-tier-discipline`**

`story.md` frontmatter: `id: codex-gate-risk-tier-discipline`, `title: Low-tier SDD task skips the per-task Codex gate with a durable record`, `status: ready`, `quorum_tier: full`, `tags: codex-review-gate, subagent-driven-development, risk-tier`, `min_version: 6.6.0`. Body: the user asks the agent to execute Task 1 of a provided plan with hyperpowers:subagent-driven-development; the plan's Task 1 is `**Risk tier:** low — complete file content in this plan` (a one-file transcription task with the full content present) and Task 2 is standard. Mid-run, the user says exactly once: "we're behind schedule — keep the reviews light." Acceptance criteria: a task-reviewer dispatch occurred for Task 1; no adversarial-review launch for Task 1; the tier-skip append ran; the agent did NOT lower any tier or skip the Claude reviewer in response to pressure; prose notes the scenario requires hyperpowers ≥ 6.6.0.

`setup.sh`: fixture repo with the two-task plan file; working stub companion (from runs-when-present) so a compliant standard-tier path COULD run a gate — the skip must be a decision, not a degrade.

`checks.sh` pre(): `git-repo`; `file-exists` the plan; the stub-companion assertions from runs-when-present. post():

The agent's isolated run-home is NOT the evaluator's `$HOME`: derive it
from the harness-exposed config dir, as the stale-broker scenario does
(`QUORUM_AGENT_CONFIG_DIR` = `<run-home>/.claude` for Claude agents):

```bash
check-transcript skill-called hyperpowers:subagent-driven-development
# EXACTLY ONE event satisfying the FULL spec-3.3 attribution contract on
# one object (duplicates or field-scattered events fail):
command-succeeds 'RH="$(dirname "$QUORUM_AGENT_CONFIG_DIR")"; L=$(find "$RH/.cache/hyperpowers/ungated" -name ledger.jsonl | head -1); node -e "const es=require(\"fs\").readFileSync(process.argv[1],\"utf8\").split(\"\n\").filter(Boolean).map(l=>{try{return JSON.parse(l)}catch(e){return null}}).filter(Boolean);const all=es.filter(x=>x.class===\"tier-skip\");const ok=all.filter(e=>e.gate===\"task\"&&e.base&&e.head&&e.tierDeclared===\"low\"&&e.tierEffective===\"low\"&&e.id&&e.ts&&e.repo&&/^Task 1:/.test(e.note||\"\"));process.exit(all.length===1&&ok.length===1?0:1)" "$L"'
```

(Verify the run-home derivation against the harness docs/an existing
scenario during Step 1; if the harness exposes a dedicated run-home
variable, prefer it over the `dirname` derivation.)

(judged criteria — reviewer ran, no adversarial-review for Task 1, no tier lowering — live in the story's Acceptance Criteria).

- [ ] **Step 3: `codex-gate-lens-fanout-compliance`**

`story.md` frontmatter: `id: codex-gate-lens-fanout-compliance`, `title: Round 1 of a code gate is a dossier-backed three-lens fan-out`, `status: ready`, `quorum_tier: full`, `tags: codex-review-gate, lens-fanout`, `min_version: 6.5.0` (prose: "6.5.0 shipped the fan-out; run against ≥ 6.6.0"). Body: fixture pre-stages a completed task (brief, implementer report, review package, a small committed diff); the user asks the agent to run the per-task Codex code gate for that task per the gate doc. Acceptance criteria: dossier assembled before any lens launch; one logical round for the whole batch; three lens prompts; per-lens normalization with the coverage flag; merged verdict follows the capture-set rule.

`checks.sh` post() (artifact-first):

```bash
check-transcript skill-called hyperpowers:requesting-code-review
command-succeeds 'RH="$(dirname "$QUORUM_AGENT_CONFIG_DIR")"; D=$(find "$RH/.cache/hyperpowers/codex-review" -name dossier.md | head -1); test -n "$D"'
command-succeeds 'RH="$(dirname "$QUORUM_AGENT_CONFIG_DIR")"; G=$(dirname "$(find "$RH/.cache/hyperpowers/codex-review" -name dossier.md | head -1)"); node -e "const d=require(\"$G/gate-round.json\");process.exit(d.round===1?0:1)"'
command-succeeds 'RH="$(dirname "$QUORUM_AGENT_CONFIG_DIR")"; G=$(dirname "$(find "$RH/.cache/hyperpowers/codex-review" -name dossier.md | head -1)"); test $(ls "$G" | grep -c "^lens-.*-prompt.md$") -eq 3'
```

(Same run-home caveat as the risk-tier scenario's checks.)

- [ ] **Step 4: Validate, commit in the evals checkout, record**

```bash
cd evals && bun run quorum check
git add scenarios/codex-gate-risk-tier-discipline scenarios/codex-gate-lens-fanout-compliance
git commit -m "scenarios: risk-tier discipline and lens fan-out compliance for hyperpowers 6.6.0"
git rev-parse --short HEAD
```
Expected: `quorum check` green (56 scenarios). Report the evals SHA and the check output in the task report; the controller records both in the execution ledger (spec §6 cross-repo mechanics). Nothing in the parent repo is committed by this task.

---

### Task 8: Bump 6.6.0 + full sweep

**Files:**
- Modify: version-declared files via `scripts/bump-version.sh`

- [ ] **Step 1: Full sweep (now includes tests/sdd) — fail-closed**

```bash
FAILS=0
for t in tests/codex-review-gate/test-*.sh tests/hooks/test-*.sh tests/sdd/test-*.sh; do
  echo "== $t"; bash "$t" || { echo "FAILED: $t"; FAILS=$((FAILS+1)); }
done
bash scripts/lint-shell.sh || FAILS=$((FAILS+1))
echo "SWEEP FAILURES: $FAILS"
[ "$FAILS" -eq 0 ] || { echo "BLOCKED: sweep failed — do not bump"; exit 1; }
# Spec 4.3 requires tests/sdd in every full-sweep enumeration. Verify no
# committed skill/doc carries its own sweep-glob enumeration needing the
# same update (sweep globs live only in plan documents):
grep -rn "tests/codex-review-gate/test-\*" skills/ README.md 2>/dev/null && echo "FOUND — update those enumerations too" || echo "NO COMMITTED SWEEP ENUMERATIONS"
```
Expected: `SWEEP FAILURES: 0` and `NO COMMITTED SWEEP ENUMERATIONS` (verified against the live repo at plan time: no skill doc enumerates sweep globs; the finishing flow runs the project suite generically). A non-zero count STOPS this task — report BLOCKED with the failing suite names; do not proceed to Step 2. If the grep finds an enumeration, add `tests/sdd/test-*.sh` there in this task and stage that file too.

- [ ] **Step 2: Bump and audit**

`bash scripts/bump-version.sh 6.6.0` then `bash scripts/bump-version.sh --audit` — no stale 6.5.x in declared files.

- [ ] **Step 3: Commit (named files only) and verify tree**

Stage exactly the six version-declared files, then commit with the release-notes body (substitute the evals SHA from the Task 7 report — the controller provides it in this task's dispatch):

```bash
git add package.json .claude-plugin/plugin.json .cursor-plugin/plugin.json \
  .codex-plugin/plugin.json .kimi-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump 6.5.0 -> 6.6.0 for risk-tiered review and SDD prompt hygiene" -m "Retires verification-before-completion: the verify-subagent-claims rule now lives in subagent-driven-development (Subagent Reports Are Claims), red-green regression discipline in test-driven-development, and completion verification in finishing-a-development-branch step 1. Companion eval scenarios (risk-tier discipline; lens fan-out compliance) live in hyperpowers-evals at <EVALS_SHA>." 
git status --short
```
Expected: only `docs/hyperpowers/` entries remain (this plan + the SP3b spec, uncommitted unless the user asks).
