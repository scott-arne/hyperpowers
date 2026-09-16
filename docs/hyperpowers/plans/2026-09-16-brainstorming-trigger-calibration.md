# Brainstorming Trigger Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md`

**Goal:** Reword the `brainstorming` skill's description so a request that is one obvious edit implements directly while anything with design content still triggers, and ship it behind a two-arm live measurement on the eval suite's own calibration set.

**Architecture:** One frontmatter line changes in `skills/brainstorming/SKILL.md`; nothing else in the skill or the bootstrap moves. The measurement runs the hyperpowers-evals harness twice per scenario at a pinned commit, control against the branch base and treatment against this branch, both with Claude Code's skill-listing budget raised so the description is in the model's context. The runs, logs, and analysis are committed in the evals clone; the hyperpowers evidence note cites them.

**Tech Stack:** bash test suites under `tests/`; hyperpowers-evals (Bun, `quorum run --repeat`, `claude-auto` coding agent, `claude-opus-5`); Python for the analysis script.

## Global Constraints

- The new description text is the spec's, verbatim, double-quoted; it names no eval fixture. No other line of `skills/brainstorming/SKILL.md` and no line of `skills/using-hyperpowers/SKILL.md` changes.
- Both arms run with `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000` in the runner's environment (Claude Code honours it as the skill-listing character budget); every run records the SessionStart payload hash and the skill-listing hash, and the arms must differ in the listing hash only.
- Control `SUPERPOWERS_ROOT` = `/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption` at `2e83fd8`; treatment `SUPERPOWERS_ROOT` = this worktree at the Task 1 commit. Harness: the evals clone at its head when Task 3 starts, recorded in the adjudication.
- Evidence directory (committed in hyperpowers-evals): `evidence/2026-09-16-brainstorming-trigger-calibration/`; run copies are lean (`verdict.json`, `coding-agent-token-usage.json`, `phase.json`, `trajectory.json`, `gauntlet-agent/`, `home/.claude/projects/`), as `evidence/2026-09-16-over-trigger-measurement/` established.
- Live `quorum run` commands are the controller's to launch (trusted-maintainer operation, approved by the human partner in chat on 2026-09-16); implementers write scripts and analysis only and never launch a live run.
- Indeterminate trials are re-run once each; twice-indeterminate stays `I` and is excluded from the rate (void-attempt rule). A real failure is a trial.
- Acceptance is the spec's: checkbox treatment fail rate at most 20%; twin, session-timeout and every router brief pass at least as often as control with zero treatment failures on the twin; remove-export no higher than control.

## Grounding

- Frontmatter rules: `tests/packaging/test-skill-frontmatter.sh` accepts a double-quoted single-line description and rejects tabs, control bytes, and mappings (the branch's own validator); the description length stays under the 1024-character block cap.
- Description guidance: `skills/writing-skills/SKILL.md`, section "Skill Discovery Optimization" (third person, "Use when ...", triggering conditions only, no workflow summary).
- Measurement pattern: `evals/evidence/2026-09-16-over-trigger-measurement/logs/measure-launch.sh` (per-process launcher with header lines) and `evals/evidence/2026-09-16-over-trigger-measurement/analyze.py` (turn-1 action classification, Wilson intervals, payload and listing hashes); Task 2's scripts mirror them.
- Evidence layout: `evals/evidence/README.md` (one directory per plan; copy never move; strip before committing).
- Re-run rule: `~/.claude/projects/-Users-johnss51-Development-agents-hyperpowers/memory/eval-void-attempt-rule.md` and the plan text of 2026-09-10 (Task 8 Step 5): one re-run per indeterminate trial.
- Convention with no existing pattern: `none: no existing pattern for a two-arm run at two SUPERPOWERS_ROOT values in one evidence directory`; Task 2 names the arm in the log file name and the run copy path.

---

### Task 1: The description

**Risk tier:** standard — behavior-shaping skill text, one line, measured by Task 3.

**Files:**
- Modify: `skills/brainstorming/SKILL.md:3`
- Test: `tests/packaging/test-skill-frontmatter.sh`, `tests/skills/test-skill-contract.sh`, `tests/packaging/test-package-skill.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the treatment skills tree Task 3 measures (this branch's head after this commit).

- [ ] **Step 1: Confirm nothing pins the old description**

Run: `grep -rn -F 'You MUST use this before any creative work' tests/ skills/ hooks/`
Expected: exactly one hit, `skills/brainstorming/SKILL.md:3`. (The spec quotes the old text and is not a pin.)

- [ ] **Step 2: Replace line 3 of `skills/brainstorming/SKILL.md`**

The new line, exactly (one line, double-quoted):

```yaml
description: "Use when a request changes what the software does or how it is built: a new feature or behavior, a new component, module, or subsystem, a change to an interface others call, a security or data consequence, more than one reasonable approach, or an unclear scope, however small it sounds. Not for a change whose whole scope is one obvious, self-contained edit with no design choice and no consequence beyond it (a typo, a label, a value nothing else depends on). When in doubt, use it."
```

Lines 1, 2, and 4 onward are unchanged. Mirror: the other skills' descriptions in `skills/*/SKILL.md` (single line, `Use when ...`).

- [ ] **Step 3: Run the covering suites**

Run, each its own command: `bash tests/packaging/test-skill-frontmatter.sh`; `LC_ALL=en_US.UTF-8 bash tests/packaging/test-skill-frontmatter.sh`; `bash tests/skills/test-skill-contract.sh`; `bash tests/packaging/test-package-skill.sh`.
Expected: `STATUS: PASSED` from each; the frontmatter suite still reports the brainstorming block under 1024 characters.

- [ ] **Step 4: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat(brainstorming): the description names the edits that need no design

The upstream text told the model to brainstorm before any creative work,
building components included, so a one-line checkbox request triggered
the skill 81 percent of the time when the description was in context.
Say what a design request is, say what a single self-contained edit is
not, and keep the tie going to brainstorming."
```

### Task 2: Measurement scripts and evidence directory

**Risk tier:** low — single-repository transcription; the plan carries the complete scripts.

**Files:**
- Create (in the evals clone `/Users/johnss51/Development/agents/hyperpowers/evals`): `evidence/2026-09-16-brainstorming-trigger-calibration/README.md`, `evidence/2026-09-16-brainstorming-trigger-calibration/logs/measure-launch.sh`, `evidence/2026-09-16-brainstorming-trigger-calibration/analyze.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `measure-launch.sh <arm> <scenario> <repeat> <proc-id>` writing `logs/<arm>-<scenario>-p<id>.log`; `analyze.py` writing `runs.json` and printing the per-arm table; the README the note cites.

- [ ] **Step 1: Write the README**

```markdown
# Brainstorming trigger calibration (2026-09-16)

Two-arm measurement behind the `brainstorming` description change on the
hyperpowers branch `brainstorming-trigger` (spec:
`docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md`
in that repository). Both arms run with `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000`
so the description is in the model's context.

- `control`: `SUPERPOWERS_ROOT` at hyperpowers `external-workflow-adoption`
  (`2e83fd8`), the current description.
- `treatment`: `SUPERPOWERS_ROOT` at hyperpowers `brainstorming-trigger`
  after the description commit.

Scenarios: `cost-checkbox-over-trigger`, `cost-remove-export-boundary`
(must not trigger); `cost-session-timeout-boundary`,
`brainstorming-router-escalates-b1..b5`,
`brainstorming-resists-jump-to-implementation` (must trigger). The control
checkbox (21) and twin (10) runs of
`../2026-09-16-over-trigger-measurement/` (descriptions-on condition) are
reused as this measurement's control for those two scenarios; the rest run
here. Logs under `logs/`, lean run copies under `runs-<scenario>/<arm>/`,
the analysis in `analysis.md` and `analysis-table.txt`.
```

- [ ] **Step 2: Write `logs/measure-launch.sh`**

```bash
#!/usr/bin/env bash
# measure-launch.sh <arm> <scenario> <repeat> <proc-id>
# arm: control | treatment. Writes logs/<arm>-<scenario>-p<id>.log with the
# heads, the time, the exact command, and quorum's output.
set -uo pipefail
arm="$1"; scen="$2"; rep="$3"; pid="$4"
EV=/Users/johnss51/Development/agents/hyperpowers/evals
E="$EV/evidence/2026-09-16-brainstorming-trigger-calibration"
case "$arm" in
  control) root=/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption ;;
  treatment) root=/Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger ;;
  *) echo "arm must be control or treatment" >&2; exit 2 ;;
esac
cd "$EV" || exit 1
export SUPERPOWERS_ROOT="$root"
log="$E/logs/$arm-$scen-p$pid.log"
{
  echo "arm=$arm scenario=$scen repeat=$rep proc=$pid"
  echo "\$ git -C \$SUPERPOWERS_ROOT rev-parse HEAD"; git -C "$SUPERPOWERS_ROOT" rev-parse HEAD
  echo "\$ git -C \$SUPERPOWERS_ROOT status --short | wc -l"; git -C "$SUPERPOWERS_ROOT" status --short | wc -l
  echo "\$ git rev-parse HEAD"; git rev-parse HEAD
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "\$ SLASH_COMMAND_TOOL_CHAR_BUDGET=20000 bun run quorum run scenarios/$scen --coding-agent claude-auto --repeat $rep"
  SLASH_COMMAND_TOOL_CHAR_BUDGET=20000 bun run quorum run "scenarios/$scen" --coding-agent claude-auto --repeat "$rep"
  echo "EXIT=$?"; date -u +%Y-%m-%dT%H:%M:%SZ
} > "$log" 2>&1
echo "DONE $arm $scen p$pid" >> "$log"
```

- [ ] **Step 3: Write `analyze.py`**

```python
#!/usr/bin/env python3
"""Per-run classification and per-arm rates for the calibration measurement.
Reads logs/*.log for run dirs (and the reused control logs of the earlier
measurement for the checkbox and twin), writes runs.json, prints the table."""
import glob, hashlib, json, math, os, re
EV = "/Users/johnss51/Development/agents/hyperpowers/evals"
E = os.path.join(EV, "evidence/2026-09-16-brainstorming-trigger-calibration")
PREV = os.path.join(EV, "evidence/2026-09-16-over-trigger-measurement/logs")
REUSED = {"cost-checkbox-over-trigger", "brainstorming-resists-jump-to-implementation"}
rows = []
for log in sorted(glob.glob(os.path.join(E, "logs", "*.log"))):
    m = re.match(r"(control|treatment)-(.+)-p\d+\.log", os.path.basename(log))
    if not m: continue
    for line in open(log, encoding="utf-8", errors="replace"):
        r = re.search(r"run-dir\s+(\S+)", line)
        if r: rows.append((m.group(1), m.group(2), r.group(1).rstrip("/")))
for log in sorted(glob.glob(os.path.join(PREV, "descriptions-on-*.log")) + glob.glob(os.path.join(PREV, "pilot-descriptions-on.log"))):
    name = os.path.basename(log)
    scen = "cost-checkbox-over-trigger" if name.startswith("pilot") else re.match(r"descriptions-on-(.+)-p\d+\.log", name).group(1)
    if scen not in REUSED: continue
    for line in open(log, encoding="utf-8", errors="replace"):
        r = re.search(r"run-dir\s+(\S+)", line)
        if r: rows.append(("control", scen, r.group(1).rstrip("/")))
def first_action(t):
    for line in open(t, encoding="utf-8", errors="replace"):
        try: rec = json.loads(line)
        except Exception: continue
        if rec.get("type") != "assistant": continue
        for c in (rec.get("message") or {}).get("content") or []:
            if c.get("type") == "tool_use":
                n = c.get("name"); inp = c.get("input") or {}
                if n == "Skill": return "Skill(%s)" % inp.get("skill")
                if n in ("Edit", "Write", "MultiEdit", "NotebookEdit"): return "direct-edit"
                return "explore(%s)" % n
    return "none"
def hashes(t):
    h = {"payload": None, "listing": None, "model": None}
    for line in open(t, encoding="utf-8", errors="replace"):
        try: rec = json.loads(line)
        except Exception: continue
        att = rec.get("attachment") or {}
        if att.get("type") == "hook_additional_context" and h["payload"] is None:
            h["payload"] = hashlib.sha256(json.dumps(att.get("content"), sort_keys=True).encode()).hexdigest()[:12]
        if att.get("type") == "skill_listing" and h["listing"] is None:
            c = att.get("content") or ""
            h["listing"] = hashlib.sha256(c.encode()).hexdigest()[:8]
            h["brainstorming_line"] = next((l for l in c.split("\n") if l.startswith("- hyperpowers:brainstorming")), "")[:90]
        if rec.get("type") == "assistant" and h["model"] is None:
            h["model"] = (rec.get("message") or {}).get("model")
    return h
out = []
for arm, scen, rd in rows:
    if not os.path.isabs(rd): rd = os.path.join(EV, rd)
    v = os.path.join(rd, "verdict.json")
    if not os.path.exists(v): continue
    d = json.load(open(v))
    ts = glob.glob(os.path.join(rd, "home/.claude/projects/*/*.jsonl"))
    tok = None
    tu = os.path.join(rd, "coding-agent-token-usage.json")
    if os.path.exists(tu):
        try:
            u = json.load(open(tu)); tok = u.get("total_tokens") or u.get("total") or sum(x for x in u.values() if isinstance(x, (int, float)))
        except Exception: tok = None
    out.append({"arm": arm, "scenario": scen, "run": os.path.basename(rd), "final": d.get("final"),
                "first_action": first_action(ts[0]) if ts else "no-transcript", "tokens": tok, **(hashes(ts[0]) if ts else {})})
json.dump(out, open(os.path.join(E, "runs.json"), "w"), indent=1)
def wilson(k, n, z=1.96):
    if n == 0: return (0.0, 0.0)
    p = k / n; den = 1 + z*z/n; c = (p + z*z/(2*n)) / den; h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / den
    return (max(0.0, c-h), min(1.0, c+h))
print("%-50s %-10s %3s %4s %4s %3s  %-14s %s" % ("scenario", "arm", "n", "fail", "pass", "ind", "fail 95% CI", "first actions"))
for scen in sorted({r["scenario"] for r in out}):
    for arm in ("control", "treatment"):
        rs = [r for r in out if r["arm"] == arm and r["scenario"] == scen]
        if not rs: continue
        det = [r for r in rs if r["final"] in ("pass", "fail")]
        k = sum(1 for r in det if r["final"] == "fail"); n = len(det); lo, hi = wilson(k, n)
        fa = {}
        for r in rs: fa[r["first_action"]] = fa.get(r["first_action"], 0) + 1
        print("%-50s %-10s %3d %4d %4d %3d  %3.0f%% [%.0f-%.0f]   %s" % (scen, arm, len(rs), k, n - k, len(rs) - n, 100*k/n if n else 0, 100*lo, 100*hi, dict(sorted(fa.items(), key=lambda x: -x[1]))))
print("\npayload hashes:", sorted({r.get("payload") for r in out if r.get("payload")}))
print("listing by arm:", sorted({(r["arm"], r.get("listing"), r.get("brainstorming_line")) for r in out if r.get("listing")}))
print("models:", sorted({r.get("model") for r in out if r.get("model")}))
```

- [ ] **Step 4: Syntax-check and commit in the evals clone**

Run: `bash -n evidence/2026-09-16-brainstorming-trigger-calibration/logs/measure-launch.sh && python3 -m py_compile evidence/2026-09-16-brainstorming-trigger-calibration/analyze.py && echo ok`
Expected: `ok`. No live run is launched in this task.

```bash
git add evidence/2026-09-16-brainstorming-trigger-calibration
git commit -m "evidence: scripts and README for the brainstorming trigger calibration"
```

### Task 3: The measurement and its adjudication

**Risk tier:** standard — live runs and the decision they feed.

**Files:**
- Create (evals clone): `evidence/2026-09-16-brainstorming-trigger-calibration/analysis.md`, `analysis-table.txt`, `runs.json`, `logs/*.log`, `runs-<scenario>/<arm>/<run>/...`

**Interfaces:**
- Consumes: Task 1's commit (treatment root), Task 2's scripts.
- Produces: the per-arm table and the acceptance verdict Task 4 cites.

- [ ] **Step 1: Controller launches the arms (not an implementer)**

From the evals clone, with `L=evidence/2026-09-16-brainstorming-trigger-calibration/logs/measure-launch.sh`, each line its own background process (`nohup bash $L <arm> <scenario> <repeat> <proc> &`), at most eight coding sessions at once:

```
treatment cost-checkbox-over-trigger 5 1..4          (20)
treatment brainstorming-resists-jump-to-implementation 5 1..2   (10)
control   cost-session-timeout-boundary 5 1..2       (10)
treatment cost-session-timeout-boundary 5 1..2       (10)
control   cost-remove-export-boundary 5 1..2         (10)
treatment cost-remove-export-boundary 5 1..2         (10)
control   brainstorming-router-escalates-b1-userid-param 5 1     (5)   ... same for b2, b3, b4, b5
treatment brainstorming-router-escalates-b1-userid-param 5 1     (5)   ... same for b2, b3, b4, b5
```

Record the launch times in `analysis.md`. When every log ends with `DONE`, re-run each indeterminate trial once with the same script (`repeat 1`, a new proc id) and note which trial it replaces.

- [ ] **Step 2: Analyze**

Run: `python3 evidence/2026-09-16-brainstorming-trigger-calibration/analyze.py | tee evidence/2026-09-16-brainstorming-trigger-calibration/analysis-table.txt`
Expected: one row per scenario and arm; `payload hashes` a single value; `listing by arm` two values whose brainstorming lines differ in their description text only.

- [ ] **Step 3: Copy the runs lean and check hygiene**

For every run in `runs.json` not already under `runs-*/`, copy `verdict.json`, `coding-agent-token-usage.json`, `phase.json`, `trajectory.json`, `gauntlet-agent/`, and `home/.claude/projects/` into `runs-<scenario>/<arm>/<run>/`. Then:
`find evidence/2026-09-16-brainstorming-trigger-calibration -name '.git' -o -name '.claude-env' -o -name '*.key' | wc -l` must print 0 and `grep -rl -E 'peerToken|prj-dcpgenai' evidence/2026-09-16-brainstorming-trigger-calibration | wc -l` must print 0.

- [ ] **Step 4: Write `analysis.md`**

Sections, in order: Instrument (harness commit, both roots' commits, model, Claude Code version, the budget override, launch times); the table from Step 2; per-scenario reading of first actions; Re-runs (each indeterminate, its re-run, the rule); Acceptance (each spec criterion with its numbers and a yes/no); Limits (single judge, one model, one Claude Code version, the budget override exposes all fifteen descriptions, not only brainstorming's). State the verdict plainly: the description ships, or it does not.

- [ ] **Step 5: Commit in the evals clone**

```bash
git add evidence/2026-09-16-brainstorming-trigger-calibration
git commit -m "evidence: brainstorming trigger calibration, control and treatment arms"
```

### Task 4: Evidence note and changelog line

**Risk tier:** low — documentation whose content is Task 3's table and verdict, transcribed.

**Files:**
- Create: `docs/hyperpowers/2026-09-16-brainstorming-trigger-calibration-eval-evidence.md`
- Modify: `CHANGELOG.md` (only if Task 3's verdict is "ships"; the entry goes under the next unreleased version heading in the file's existing style)

**Interfaces:**
- Consumes: Task 3's `analysis.md` and the evals commit that holds it.
- Produces: the note the final review reads.

- [ ] **Step 1: Write the note**

Header lines `**Spec:**`, `**Plan:**`, `**Measured:**` (date), `**Control root:** 2e83fd8`, `**Treatment root:** <Task 1 commit>`, `**Harness:** <evals commit>`, `**Evidence:** evals evidence/2026-09-16-brainstorming-trigger-calibration/ at <evals commit of Task 3>`. Then: What was measured (the mechanism paragraph from the spec, three sentences); the table copied from `analysis-table.txt`; Acceptance (the spec's four criteria, each with numbers); Decision (ships or does not, in one sentence, with the human partner's stated preference quoted: false positives over false negatives, but no trigger where none is needed); Limits.

- [ ] **Step 2: Changelog (only when the verdict is "ships")**

One bullet under the unreleased heading, in the file's voice: the description now names the class of edits that need no design and keeps the tie with brainstorming; the measured checkbox over-trigger rate with the description in context, control versus treatment; the calibration scenarios that must trigger stayed at their control rates. No emojis.

- [ ] **Step 3: Commit**

```bash
git add docs/hyperpowers/2026-09-16-brainstorming-trigger-calibration-eval-evidence.md CHANGELOG.md
git commit -m "docs: evidence note for the brainstorming trigger calibration"
```
