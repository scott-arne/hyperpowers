# Brainstorming Trigger Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md`

**Goal:** Reword the `brainstorming` skill's description so a request that is one obvious edit implements directly while anything with design content still triggers, and ship it behind a two-arm live measurement on the eval suite's own calibration set.

**Architecture:** One frontmatter line changes in `skills/brainstorming/SKILL.md`; nothing else in the skill or the bootstrap moves. The measurement runs the hyperpowers-evals harness at one pinned commit twice per scenario, control against the branch base and treatment against this branch, both with Claude Code's skill-listing budget raised so the description is in the model's context. A manifest declares every trial; a launcher refuses to run unless roots and harness match it; an analysis script refuses to produce a table unless the observed runs match it exactly. Runs, logs, manifest, and analysis are committed in the evals clone; the hyperpowers evidence note cites them.

**Tech Stack:** bash test suites under `tests/`; hyperpowers-evals (Bun, `quorum run --repeat`, `claude-auto` coding agent, `claude-opus-5`); Python 3 (ruff and mypy clean) for the analysis.

## Global Constraints

- The new description text is the spec's, verbatim, double-quoted; it names no eval fixture. No other line of `skills/brainstorming/SKILL.md` and no line of `skills/using-hyperpowers/SKILL.md` changes.
- One harness for every trial: the `harness` row of `manifest.tsv` names the evals commit whose harness paths (`src`, `scenarios`, `coding-agents`, `package.json`, `bun.lock`) every run must match byte for byte; evidence commits may follow that pin, harness changes may not. Every `measure-launch.sh` invocation checks, before launching, that the arm's root is at its manifest commit with a clean tree, that `git diff --quiet <harness> HEAD -- <harness paths>` holds, and that the harness paths have no uncommitted changes; it refuses otherwise, so a direct rerun launch is as fenced as a scheduled one. Nothing from `evidence/2026-09-16-over-trigger-measurement/` is reused as a trial.
- Both arms run with `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000` in the runner's environment. Control root: `/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption` at `2e83fd8`. Treatment root: `/Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger` at the Task 1 commit.
- Evidence directory (hyperpowers-evals): `evidence/2026-09-16-brainstorming-trigger-calibration/`. Run copies are prepared with `scripts/strip-runs` and staged with `git add -f` (the README's procedure: `home/.claude/` and `gauntlet-agent/results/` match unanchored ignore rules), and the staged tree is checked before the commit: one transcript and one `result.json` per run, no gitlinks, no `.claude-env`, no `.key`, no `peerToken`.
- Live `quorum run` commands are the controller's to launch (trusted-maintainer operation, approved by the human partner in chat on 2026-09-16); implementers write scripts, manifests, and analysis and never launch a live run.
- Indeterminate trials are re-run once each and recorded in `reruns.tsv` (`original<TAB>replacement`); the replacement stands in for the original; twice-indeterminate stays `I` and is excluded from the rate; a failure is a trial.
- Acceptance is the spec's: checkbox treatment fail rate at most 20%; twin, session-timeout and every router brief pass at least as often as control with zero treatment failures on the twin; remove-export no higher than control; one payload hash; one listing hash with the brainstorming line removed; each arm's brainstorming line equals the one its root renders.
- No `CHANGELOG.md` change in this plan: the changelog entry belongs to the release task that ships the next version, and `CHANGELOG.md` has no unreleased heading to write under.

## Grounding

- Frontmatter rules: `tests/packaging/test-skill-frontmatter.sh` accepts a double-quoted single-line description and rejects tabs, control bytes, and mappings; the description length stays under the 1024-character block cap.
- Description guidance: `skills/writing-skills/SKILL.md`, section "Skill Discovery Optimization" (third person, "Use when ...", triggering conditions only, no workflow summary).
- Measurement pattern: `evals/evidence/2026-09-16-over-trigger-measurement/logs/measure-launch.sh` and `.../analyze.py` (per-process launcher with header lines; turn-1 action classification; Wilson intervals; payload and listing hashes). Task 2's scripts mirror them and add the manifest, the fail-closed checks, and the rerun manifest.
- Evidence layout and preservation: `evals/evidence/README.md` (one directory per plan; `scripts/strip-runs`; `git add -f`; staged-tree checks).
- Re-run rule: `~/.claude/projects/-Users-johnss51-Development-agents-hyperpowers/memory/eval-void-attempt-rule.md` (one re-run per indeterminate trial; twice stays `I`).
- Python quality: ruff and mypy at `/Users/johnss51/.local/bin/`; every Python file in this plan passes `ruff check`, `ruff format --check`, and `mypy --ignore-missing-imports`.
- Convention with no existing pattern: `none: no existing pattern for a manifest-declared two-arm run`; Task 2 defines `manifest.tsv` and `reruns.tsv`, and the analysis derives every expectation from them and from the two roots.

---

### Task 1: The description

**Risk tier:** standard — behavior-shaping skill text, one line, measured by Task 3.

**Files:**
- Modify: `skills/brainstorming/SKILL.md:3`
- Test: `tests/packaging/test-skill-frontmatter.sh`, `tests/skills/test-skill-contract.sh`, `tests/packaging/test-package-skill.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the treatment root Task 3 measures (this branch's head after this commit; its full SHA goes into the `treatment` row of `manifest.tsv`).

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

### Task 2: Manifest, launcher, and fail-closed analysis

**Risk tier:** high — the analysis script's output is the durable record the ship decision rests on.

**Files:**
- Create (in the evals clone `/Users/johnss51/Development/agents/hyperpowers/evals`, all under `evidence/2026-09-16-brainstorming-trigger-calibration/`): `README.md`, `manifest.tsv`, `logs/measure-launch.sh`, `launch-all.sh`, `analyze.py`

**Interfaces:**
- Consumes: the two roots' paths (Global Constraints) and their `skills/brainstorming/SKILL.md` description lines (the analysis renders each arm's expected listing line from them); the Task 1 commit SHA for the manifest's `treatment` row; the evals harness paths named in Global Constraints.
- Produces: `manifest.tsv` (two-field rows `harness<TAB>sha`, `control<TAB>sha`, `treatment<TAB>sha`, `model<TAB>claude-opus-5`, then one four-field `arm<TAB>scenario<TAB>repeat<TAB>proc` row per launch, proc `p<n>`); `launch-all.sh manifest.tsv [max]`; `logs/measure-launch.sh arm scenario repeat proc` (proc `p<n>` for a manifest row, `r<n>` for a rerun; it writes `logs/<arm>-<scenario>-<proc>.log` with `root=<sha> root_clean=0` and `harness_pin=<sha> evals_head=<sha> harness_paths_identical=yes` header lines that `analyze.py` requires); `analyze.py` writing `runs.json` and printing the table, exit 1 with `DESIGN ERROR:` on any deviation (a manifest row without a log, a log that is neither a manifest row nor a rerun, a repeat count that differs, a missing pin, a rerun not in `reruns.tsv`, a replacement without a log or of another arm or scenario, a trial replaced twice, an indeterminate trial never re-run, an arm with no trials), and `analyze.py --self-test`, which builds throwaway cohorts under `$TMPDIR` and proves one clean cohort is accepted and three broken ones refused; `reruns.tsv` (`original<TAB>replacement`, `#` comments).

- [ ] **Step 1: Write the README**

```markdown
# Brainstorming trigger calibration (2026-09-16)

Two-arm measurement behind the `brainstorming` description change on the
hyperpowers branch `brainstorming-trigger` (spec:
`docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md`
in that repository). Both arms run with `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000`
so the description is in the model's context, at the one harness commit
`manifest.tsv` records.

- `control`: `SUPERPOWERS_ROOT` at hyperpowers `external-workflow-adoption`
  (`2e83fd8`), the current description.
- `treatment`: `SUPERPOWERS_ROOT` at hyperpowers `brainstorming-trigger`
  after the description commit (the `treatment` row of `manifest.tsv`).

Scenarios: `cost-checkbox-over-trigger`, `cost-remove-export-boundary`
(must not trigger); `cost-session-timeout-boundary`,
`brainstorming-router-escalates-b1..b5`,
`brainstorming-resists-jump-to-implementation` (must trigger). Every trial
is declared in `manifest.tsv`; `launch-all.sh` runs it; `analyze.py`
refuses to report unless the observed runs match the manifest exactly.
Indeterminate trials re-run once, recorded in `reruns.tsv`. Logs under
`logs/`, run copies under `runs-<scenario>/<arm>/`, the analysis in
`analysis.md` and `analysis-table.txt`.
```

- [ ] **Step 2: Write `manifest.tsv`**

Tab-separated. `<EVALS_COMMIT>` is filled by the controller at Task 3 Step 1 with the evals commit that pins the harness (Task 2's commit: the last commit that touched the harness paths or later, as long as the harness paths are identical to it); `<TASK_1_COMMIT>` is Task 1's full SHA. Until both are full SHAs, `measure-launch.sh` refuses to run and `analyze.py` reports a design error.

```
harness	<EVALS_COMMIT>
control	2e83fd8f42417168cf3f12d5d99e1e484859a06d
treatment	<TASK_1_COMMIT>
model	claude-opus-5
control	cost-checkbox-over-trigger	5	1
control	cost-checkbox-over-trigger	5	2
control	cost-checkbox-over-trigger	5	3
control	cost-checkbox-over-trigger	5	4
control	brainstorming-resists-jump-to-implementation	5	1
control	brainstorming-resists-jump-to-implementation	5	2
control	cost-session-timeout-boundary	5	1
control	cost-session-timeout-boundary	5	2
control	cost-remove-export-boundary	5	1
control	cost-remove-export-boundary	5	2
control	brainstorming-router-escalates-b1-userid-param	5	1
control	brainstorming-router-escalates-b2-config-module	5	1
control	brainstorming-router-escalates-b3-logging	5	1
control	brainstorming-router-escalates-b4-reusable-validation	5	1
control	brainstorming-router-escalates-b5-prefs-storage	5	1
treatment	cost-checkbox-over-trigger	5	1
treatment	cost-checkbox-over-trigger	5	2
treatment	cost-checkbox-over-trigger	5	3
treatment	cost-checkbox-over-trigger	5	4
treatment	brainstorming-resists-jump-to-implementation	5	1
treatment	brainstorming-resists-jump-to-implementation	5	2
treatment	cost-session-timeout-boundary	5	1
treatment	cost-session-timeout-boundary	5	2
treatment	cost-remove-export-boundary	5	1
treatment	cost-remove-export-boundary	5	2
treatment	brainstorming-router-escalates-b1-userid-param	5	1
treatment	brainstorming-router-escalates-b2-config-module	5	1
treatment	brainstorming-router-escalates-b3-logging	5	1
treatment	brainstorming-router-escalates-b4-reusable-validation	5	1
treatment	brainstorming-router-escalates-b5-prefs-storage	5	1
```

- [ ] **Step 3: Write `logs/measure-launch.sh`**

```bash
#!/usr/bin/env bash
# measure-launch.sh <arm> <scenario> <repeat> <proc>
# Runs one quorum process for the calibration after checking the manifest's
# pins: the arm's root at its commit with a clean tree, and the evals clone with
# harness paths identical to the pinned harness commit (evidence commits may
# follow the pin; harness code may not) and no changes outside evidence/.
# Writes logs/<arm>-<scenario>-<proc>.log (proc is p<n> for a manifest row or
# r<n> for a rerun) with the pins, the time, the exact command, and quorum's
# output. The last line is DONE only when quorum exited 0, 1, or 2 (a pass, a
# fail, or an indeterminate are measurements); anything else is FAILED <code>.
set -uo pipefail
arm="$1"; scen="$2"; rep="$3"; proc="$4"
EV=/Users/johnss51/Development/agents/hyperpowers/evals
E="$EV/evidence/2026-09-16-brainstorming-trigger-calibration"
HARNESS_PATHS="src scenarios coding-agents package.json bun.lock"
case "$arm" in
  control) root=/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption ;;
  treatment) root=/Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger ;;
  *) echo "arm must be control or treatment" >&2; exit 2 ;;
esac
case "$proc" in p[0-9]|p[0-9][0-9]|r[0-9]|r[0-9][0-9]) ;; *) echo "proc must be p<n> or r<n>" >&2; exit 2 ;; esac
pin() { awk -F '\t' -v key="$1" 'NF == 2 && $1 == key { print $2 }' "$E/manifest.tsv"; }
root_pin=$(pin "$arm"); harness_pin=$(pin harness)
case "$root_pin$harness_pin" in *'<'*|'') echo "manifest.tsv is not filled in" >&2; exit 1 ;; esac
[ "$(git -C "$root" rev-parse HEAD)" = "$root_pin" ] || { echo "$arm root is not at $root_pin" >&2; exit 1; }
[ -z "$(git -C "$root" status --short)" ] || { echo "$arm root has uncommitted changes" >&2; exit 1; }
cd "$EV" || exit 1
git cat-file -e "$harness_pin^{commit}" 2>/dev/null || { echo "harness pin $harness_pin does not resolve" >&2; exit 1; }
# shellcheck disable=SC2086
git diff --quiet "$harness_pin" HEAD -- $HARNESS_PATHS || { echo "harness paths differ from $harness_pin" >&2; exit 1; }
# shellcheck disable=SC2086
[ -z "$(git status --short -- $HARNESS_PATHS)" ] || { echo "harness paths have uncommitted changes" >&2; exit 1; }
export SUPERPOWERS_ROOT="$root"
log="$E/logs/$arm-$scen-$proc.log"
{
  echo "arm=$arm scenario=$scen repeat=$rep proc=$proc"
  echo "root=$root_pin root_clean=0"
  echo "harness_pin=$harness_pin evals_head=$(git rev-parse HEAD) harness_paths_identical=yes"
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "\$ SLASH_COMMAND_TOOL_CHAR_BUDGET=20000 bun run quorum run scenarios/$scen --coding-agent claude-auto --repeat $rep"
  SLASH_COMMAND_TOOL_CHAR_BUDGET=20000 bun run quorum run "scenarios/$scen" --coding-agent claude-auto --repeat "$rep"
  code=$?
  echo "EXIT=$code"; date -u +%Y-%m-%dT%H:%M:%SZ
  case "$code" in 0|1|2) echo "DONE $arm $scen $proc" ;; *) echo "FAILED $code $arm $scen $proc" ;; esac
} > "$log" 2>&1
```

- [ ] **Step 4: Write `launch-all.sh`**

```bash
#!/usr/bin/env bash
# launch-all.sh <manifest.tsv> [max-concurrent]
# Runs every four-field row of the manifest (arm, scenario, repeat, proc)
# through logs/measure-launch.sh, at most N at a time (default 8), and waits.
# measure-launch.sh does the pin checks for every launch, so a row that cannot
# run refuses on its own; this script only schedules and reports.
set -uo pipefail
manifest="$1"; max="${2:-8}"
E=/Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-09-16-brainstorming-trigger-calibration
[ -f "$manifest" ] || { echo "no manifest at $manifest" >&2; exit 1; }
launched=0
while IFS=$'\t' read -r arm scen rep proc; do
  case "$arm" in control|treatment) ;; *) continue ;; esac
  [ -n "$proc" ] || continue
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$max" ]; do sleep 15; done
  bash "$E/logs/measure-launch.sh" "$arm" "$scen" "$rep" "$proc" &
  launched=$((launched + 1)); echo "started $arm $scen x$rep $proc ($launched launched) $(date -u +%H:%M:%SZ)"
done < "$manifest"
wait
without_done=$(grep -L '^DONE ' "$E"/logs/*-p[0-9]*.log 2>/dev/null | wc -l | tr -d ' ')
echo "all launches finished; manifest logs without DONE: $without_done"
[ "$without_done" -eq 0 ]
```

- [ ] **Step 5: Write `analyze.py`**

```python
#!/usr/bin/env python3
"""Fail-closed analysis for the brainstorming trigger calibration.

Reads ``manifest.tsv`` (the declared design: harness commit, the two roots'
commits, the model, and one trial row per launch), the per-process logs under
``logs/``, and ``reruns.tsv`` (original run -> replacement run). Every log
must be a manifest row or a declared rerun, carry the pins the launcher wrote,
and hold exactly its runs; every trial collapses to one outcome. Any deviation
from the declared design is an error, not a skipped row. Writes ``runs.json``
and prints the per-arm table.
"""

from __future__ import annotations

import glob
import hashlib
import json
import math
import os
import re
import sys
from dataclasses import asdict, dataclass

EV = "/Users/johnss51/Development/agents/hyperpowers/evals"
E = os.path.join(EV, "evidence/2026-09-16-brainstorming-trigger-calibration")
ROOTS = {
    "control": "/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption",
    "treatment": "/Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger",
}
RUN_DIR_RE = re.compile(r"run-dir\s+(\S+)")
LOG_RE = re.compile(r"(control|treatment)-(.+)-([pr]\d+)\.log")
HEADER_RE = re.compile(
    r"^arm=(\S+) scenario=(\S+) repeat=(\d+) proc=(\S+)$", re.MULTILINE
)
ROOT_RE = re.compile(r"^root=([0-9a-f]{40}) root_clean=0$", re.MULTILINE)
HARNESS_RE = re.compile(
    r"^harness_pin=([0-9a-f]{40}) evals_head=[0-9a-f]{40} harness_paths_identical=yes$",
    re.MULTILINE,
)
SHA_RE = re.compile(r"[0-9a-f]{40}")
BRAINSTORMING_LINE = "- hyperpowers:brainstorming"


@dataclass
class Run:
    """One coding-agent trial and what the analysis extracted from it."""

    arm: str
    scenario: str
    run: str
    final: str
    first_action: str
    tokens: int | None
    payload: str
    listing_rest: str
    brainstorming_line: str
    model: str
    replaces: str | None = None


class DesignError(Exception):
    """The observed runs do not match the declared design."""


def read_manifest() -> dict:
    """Parse manifest.tsv into commits, the model, the launch rows, and expected counts."""

    manifest: dict = {"trials": {}, "commits": {}, "model": "", "rows": {}}
    with open(os.path.join(E, "manifest.tsv"), encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            cells = line.split("\t")
            if cells[0] in ("harness", "control", "treatment") and len(cells) == 2:
                manifest["commits"][cells[0]] = cells[1]
            elif cells[0] == "model" and len(cells) == 2:
                manifest["model"] = cells[1]
            elif cells[0] in ("control", "treatment") and len(cells) == 4:
                arm, scenario, repeat, proc = (
                    cells[0],
                    cells[1],
                    int(cells[2]),
                    cells[3],
                )
                if (arm, scenario, proc) in manifest["rows"]:
                    raise DesignError(
                        f"manifest.tsv: duplicate row {arm} {scenario} {proc}"
                    )
                manifest["rows"][(arm, scenario, proc)] = repeat
                manifest["trials"].setdefault(scenario, {}).setdefault(arm, 0)
                manifest["trials"][scenario][arm] += repeat
            else:
                raise DesignError(f"manifest.tsv: unreadable line {line!r}")
    for key in ("harness", "control", "treatment"):
        if not SHA_RE.fullmatch(manifest["commits"].get(key, "")):
            raise DesignError(f"manifest.tsv: {key} commit missing or not a full sha")
    if not manifest["model"]:
        raise DesignError("manifest.tsv: no model")
    if not manifest["rows"]:
        raise DesignError("manifest.tsv: no launch rows")
    return manifest


def expected_brainstorming_line(arm: str) -> str:
    """The listing line Claude Code renders for the brainstorming skill at this arm's root."""

    path = os.path.join(ROOTS[arm], "skills/brainstorming/SKILL.md")
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("description:"):
                value = line[len("description:") :].strip()
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                return f"{BRAINSTORMING_LINE}: {value}"
    raise DesignError(f"{path}: no description line")


def load_json(path: str) -> dict:
    with open(path, encoding="utf-8") as handle:
        loaded = json.load(handle)
    if not isinstance(loaded, dict):
        raise DesignError(f"{path}: expected a JSON object")
    return loaded


def iter_records(path: str):
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def first_action(transcript: str) -> str:
    for rec in iter_records(transcript):
        if rec.get("type") != "assistant":
            continue
        for part in (rec.get("message") or {}).get("content") or []:
            if part.get("type") != "tool_use":
                continue
            name = part.get("name")
            if name == "Skill":
                return f"Skill({(part.get('input') or {}).get('skill')})"
            if name in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
                return "direct-edit"
            return f"explore({name})"
    return "none"


def context_hashes(transcript: str) -> tuple[str, str, str, str]:
    payload = listing_rest = brainstorming = model = ""
    for rec in iter_records(transcript):
        att = rec.get("attachment") or {}
        if att.get("type") == "hook_additional_context" and not payload:
            payload = hashlib.sha256(
                json.dumps(att.get("content"), sort_keys=True).encode()
            ).hexdigest()[:12]
        if att.get("type") == "skill_listing" and not listing_rest:
            lines = (att.get("content") or "").split("\n")
            own = [line for line in lines if line.startswith(BRAINSTORMING_LINE)]
            rest = [line for line in lines if not line.startswith(BRAINSTORMING_LINE)]
            brainstorming = own[0] if own else ""
            listing_rest = hashlib.sha256("\n".join(rest).encode()).hexdigest()[:12]
        if rec.get("type") == "assistant" and not model:
            model = (rec.get("message") or {}).get("model") or ""
    return payload, listing_rest, brainstorming, model


def token_total(run_dir: str) -> int | None:
    path = os.path.join(run_dir, "coding-agent-token-usage.json")
    if not os.path.exists(path):
        return None
    usage = load_json(path)
    total = usage.get("total_tokens") or usage.get("total")
    if isinstance(total, (int, float)):
        return int(total)
    return int(sum(v for v in usage.values() if isinstance(v, (int, float))))


def read_logs(manifest: dict) -> list[tuple[str, str, str, bool]]:
    """Return (arm, scenario, run dir, is_rerun) for every run of every valid log."""

    rows: list[tuple[str, str, str, bool]] = []
    seen_rows: set[tuple[str, str, str]] = set()
    for log in sorted(glob.glob(os.path.join(E, "logs", "*.log"))):
        match = LOG_RE.match(os.path.basename(log))
        if not match:
            continue
        arm, scenario, proc = match.group(1), match.group(2), match.group(3)
        with open(log, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        header = HEADER_RE.search(text)
        if not header or (header.group(1), header.group(2), header.group(4)) != (
            arm,
            scenario,
            proc,
        ):
            raise DesignError(f"{log}: header does not match the file name")
        repeat = int(header.group(3))
        root = ROOT_RE.search(text)
        if not root or root.group(1) != manifest["commits"][arm]:
            raise DesignError(
                f"{log}: root pin missing or not the manifest's {arm} commit"
            )
        harness = HARNESS_RE.search(text)
        if not harness or harness.group(1) != manifest["commits"]["harness"]:
            raise DesignError(f"{log}: harness pin missing or not the manifest's")
        if "\nDONE " not in text:
            raise DesignError(
                f"{log}: the launch did not finish cleanly (no DONE line)"
            )
        is_rerun = proc.startswith("r")
        if is_rerun:
            if repeat != 1:
                raise DesignError(f"{log}: a rerun log must have repeat=1")
        else:
            expected_repeat = manifest["rows"].get((arm, scenario, proc))
            if expected_repeat is None:
                raise DesignError(f"{log}: not a manifest row")
            if expected_repeat != repeat:
                raise DesignError(
                    f"{log}: repeat {repeat}, manifest says {expected_repeat}"
                )
            seen_rows.add((arm, scenario, proc))
        found = [m.group(1).rstrip("/") for m in RUN_DIR_RE.finditer(text)]
        if len(found) != repeat:
            raise DesignError(f"{log}: {len(found)} runs recorded, repeat was {repeat}")
        for run_dir in found:
            rows.append((arm, scenario, run_dir, is_rerun))
    missing = set(manifest["rows"]) - seen_rows
    if missing:
        raise DesignError(f"manifest rows without a log: {sorted(missing)}")
    return rows


def read_reruns() -> dict[str, str]:
    """replacement run name -> original run name."""

    path = os.path.join(E, "reruns.tsv")
    replaced: dict[str, str] = {}
    if not os.path.exists(path):
        return replaced
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            original, replacement = line.split()[:2]
            if replacement in replaced:
                raise DesignError(f"reruns.tsv: {replacement} listed twice")
            replaced[replacement] = original
    return replaced


def build_runs(manifest: dict) -> list[Run]:
    replaced = read_reruns()
    runs: list[Run] = []
    seen: set[str] = set()
    for arm, scenario, run_dir, is_rerun in read_logs(manifest):
        if not os.path.isabs(run_dir):
            run_dir = os.path.join(EV, run_dir)
        name = os.path.basename(run_dir)
        if name in seen:
            raise DesignError(f"{name}: listed twice")
        seen.add(name)
        if is_rerun and name not in replaced:
            raise DesignError(f"{name}: a rerun not listed in reruns.tsv")
        if not is_rerun and name in replaced:
            raise DesignError(
                f"{name}: listed as a replacement but launched as a manifest row"
            )
        verdict_path = os.path.join(run_dir, "verdict.json")
        if not os.path.exists(verdict_path):
            raise DesignError(f"{name}: no verdict.json")
        final = str(load_json(verdict_path).get("final"))
        if final not in ("pass", "fail", "indeterminate"):
            raise DesignError(f"{name}: unexpected final verdict {final!r}")
        transcripts = glob.glob(
            os.path.join(run_dir, "home/.claude/projects/*/*.jsonl")
        )
        if not transcripts:
            raise DesignError(f"{name}: no transcript")
        payload, listing_rest, brainstorming, model = context_hashes(transcripts[0])
        if not payload or not listing_rest or not brainstorming:
            raise DesignError(f"{name}: payload, listing or brainstorming line missing")
        runs.append(
            Run(
                arm,
                scenario,
                name,
                final,
                first_action(transcripts[0]),
                token_total(run_dir),
                payload,
                listing_rest,
                brainstorming,
                model,
                replaced.get(name),
            )
        )
    for replacement in replaced:
        if replacement not in seen:
            raise DesignError(
                f"reruns.tsv names a replacement with no log: {replacement}"
            )
    return runs


def collapse(runs: list[Run]) -> list[Run]:
    """One outcome per trial: a replacement stands in for its original."""

    by_name = {run.run: run for run in runs}
    replaced_originals: set[str] = set()
    for run in runs:
        if not run.replaces:
            continue
        original = by_name.get(run.replaces)
        if original is None:
            raise DesignError(f"reruns.tsv names an unknown original {run.replaces}")
        if original.final != "indeterminate":
            raise DesignError(f"{run.replaces} was replaced but was not indeterminate")
        if (original.arm, original.scenario) != (run.arm, run.scenario):
            raise DesignError(f"{run.run} replaces a trial of another arm or scenario")
        if run.replaces in replaced_originals:
            raise DesignError(
                f"{run.replaces} was replaced twice; the rule is one rerun"
            )
        replaced_originals.add(run.replaces)
    for run in runs:
        if (
            run.final == "indeterminate"
            and not run.replaces
            and run.run not in replaced_originals
        ):
            raise DesignError(
                f"{run.run}: indeterminate and never re-run; the rule is one rerun"
            )
    return [run for run in runs if run.run not in replaced_originals]


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    den = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / den
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return (max(0.0, centre - half), min(1.0, centre + half))


def check_design(manifest: dict, trials: list[Run]) -> None:
    expected = manifest["trials"]
    for scenario, arms in expected.items():
        for arm, count in arms.items():
            have = [t for t in trials if t.scenario == scenario and t.arm == arm]
            if len(have) != count:
                raise DesignError(
                    f"{scenario}/{arm}: {len(have)} trials, design says {count}"
                )
    for scenario in {t.scenario for t in trials}:
        if scenario not in expected:
            raise DesignError(f"{scenario}: not in the declared design")
    payloads = {t.payload for t in trials}
    if len(payloads) != 1:
        raise DesignError(f"payload hashes differ: {sorted(payloads)}")
    rests = {t.listing_rest for t in trials}
    if len(rests) != 1:
        raise DesignError(
            f"listings differ outside the brainstorming line: {sorted(rests)}"
        )
    for arm in ("control", "treatment"):
        if not any(t.arm == arm for t in trials):
            raise DesignError(f"{arm}: no trials")
        lines = {t.brainstorming_line for t in trials if t.arm == arm}
        if lines != {expected_brainstorming_line(arm)}:
            raise DesignError(f"{arm}: brainstorming line {sorted(lines)}")
    models = {t.model for t in trials}
    if models != {manifest["model"]}:
        raise DesignError(f"models differ from the design: {sorted(models)}")


def _write_fixture(root: str, final_by_run: dict[str, str], reruns: str | None) -> None:
    """A minimal evidence tree: both arms, one log per proc, one run per verdict.

    ``final_by_run`` describes the control arm; names starting with ``rerun-``
    go into a rerun log. The treatment arm always has one passing trial.
    """

    os.makedirs(os.path.join(root, "logs"), exist_ok=True)
    os.makedirs(os.path.join(root, "skills/brainstorming"), exist_ok=True)
    with open(
        os.path.join(root, "skills/brainstorming/SKILL.md"), "w", encoding="utf-8"
    ) as handle:
        handle.write("---\nname: brainstorming\ndescription: DESC\n---\n")
    control, treatment, harness = "1" * 40, "2" * 40, "3" * 40
    commits = {"control": control, "treatment": treatment}
    originals = [name for name in final_by_run if not name.startswith("rerun-")]
    with open(os.path.join(root, "manifest.tsv"), "w", encoding="utf-8") as handle:
        handle.write(
            f"harness\t{harness}\ncontrol\t{control}\ntreatment\t{treatment}\n"
        )
        handle.write(f"model\tmodel-x\ncontrol\tscenario-x\t{len(originals)}\tp1\n")
        handle.write("treatment\tscenario-x\t1\tp1\n")
    listing = "- other:skill: text\n- hyperpowers:brainstorming: DESC"
    transcript = "\n".join(
        [
            json.dumps(
                {
                    "type": "attachment",
                    "attachment": {
                        "type": "hook_additional_context",
                        "content": ["boot"],
                    },
                }
            ),
            json.dumps(
                {
                    "type": "attachment",
                    "attachment": {"type": "skill_listing", "content": listing},
                }
            ),
            json.dumps(
                {
                    "type": "assistant",
                    "message": {
                        "model": "model-x",
                        "content": [{"type": "tool_use", "name": "Bash"}],
                    },
                }
            ),
        ]
    )
    runs = [("control", name, final) for name, final in final_by_run.items()]
    runs.append(("treatment", "run-t", "pass"))
    logs: dict[tuple[str, str], list[str]] = {}
    for arm, name, final in runs:
        run_dir = os.path.join(root, "results", name)
        os.makedirs(os.path.join(run_dir, "home/.claude/projects/p"), exist_ok=True)
        with open(
            os.path.join(run_dir, "verdict.json"), "w", encoding="utf-8"
        ) as handle:
            json.dump({"final": final}, handle)
        with open(
            os.path.join(run_dir, "home/.claude/projects/p/t.jsonl"),
            "w",
            encoding="utf-8",
        ) as handle:
            handle.write(transcript + "\n")
        proc = "r1" if name.startswith("rerun-") else "p1"
        logs.setdefault((arm, proc), []).append(f"run-dir   {run_dir}")
    for (arm, proc), lines in logs.items():
        with open(
            os.path.join(root, "logs", f"{arm}-scenario-x-{proc}.log"),
            "w",
            encoding="utf-8",
        ) as handle:
            handle.write(
                f"arm={arm} scenario=scenario-x repeat={len(lines)} proc={proc}\n"
            )
            handle.write(f"root={commits[arm]} root_clean=0\n")
            handle.write(
                f"harness_pin={harness} evals_head={harness} harness_paths_identical=yes\n"
            )
            handle.write("\n".join(lines) + f"\nEXIT=0\nDONE {arm} scenario-x {proc}\n")
    if reruns is not None:
        with open(os.path.join(root, "reruns.tsv"), "w", encoding="utf-8") as handle:
            handle.write(reruns)


def self_test() -> int:
    """The analysis must accept the clean cohort and refuse each broken one."""

    import tempfile

    global E, ROOTS
    saved = (E, ROOTS)
    cases: list[tuple[str, dict[str, str], str | None, bool]] = [
        (
            "a clean cohort with one replaced indeterminate",
            {"run-a": "pass", "run-b": "indeterminate", "rerun-b": "fail"},
            "run-b\trerun-b\n",
            True,
        ),
        (
            "an indeterminate trial never re-run",
            {"run-a": "pass", "run-b": "indeterminate"},
            None,
            False,
        ),
        (
            "a replacement whose original was not indeterminate",
            {"run-a": "pass", "rerun-a": "pass"},
            "run-a\trerun-a\n",
            False,
        ),
        (
            "a rerun not listed in reruns.tsv",
            {"run-a": "indeterminate", "rerun-a": "pass"},
            None,
            False,
        ),
    ]
    failures = 0
    for title, verdicts, reruns, should_pass in cases:
        with tempfile.TemporaryDirectory() as tmp:
            E = tmp
            ROOTS = {"control": tmp, "treatment": tmp}
            _write_fixture(tmp, verdicts, reruns)
            detail = ""
            try:
                manifest = read_manifest()
                check_design(manifest, collapse(build_runs(manifest)))
                accepted = True
            except DesignError as error:
                accepted = False
                detail = f": {error}"
        if accepted == should_pass:
            verb = "accepted as expected" if accepted else "refused as expected"
            print(f"{verb} ({title}){detail}")
        else:
            print(f"SELF-TEST FAILURE ({title}): accepted={accepted}{detail}")
            failures += 1
    E, ROOTS = saved
    return 1 if failures else 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        return self_test()
    manifest = read_manifest()
    runs = build_runs(manifest)
    trials = collapse(runs)
    check_design(manifest, trials)
    with open(os.path.join(E, "runs.json"), "w", encoding="utf-8") as handle:
        json.dump([asdict(run) for run in runs], handle, indent=1)
    header = "{:<50} {:<10} {:>3} {:>4} {:>4} {:>3}  {:<14} {}"
    print(
        header.format(
            "scenario",
            "arm",
            "n",
            "fail",
            "pass",
            "ind",
            "fail 95% CI",
            "first actions",
        )
    )
    for scenario in sorted(manifest["trials"]):
        for arm in ("control", "treatment"):
            rows = [t for t in trials if t.arm == arm and t.scenario == scenario]
            determinate = [t for t in rows if t.final in ("pass", "fail")]
            fails = sum(1 for t in determinate if t.final == "fail")
            n = len(determinate)
            low, high = wilson(fails, n)
            actions: dict[str, int] = {}
            for t in rows:
                actions[t.first_action] = actions.get(t.first_action, 0) + 1
            rate = 100 * fails / n if n else 0.0
            interval = f"{rate:3.0f}% [{100 * low:.0f}-{100 * high:.0f}]"
            ranked = dict(sorted(actions.items(), key=lambda item: -item[1]))
            print(
                header.format(
                    scenario,
                    arm,
                    len(rows),
                    fails,
                    n - fails,
                    len(rows) - n,
                    interval,
                    ranked,
                )
            )
    print(
        "\ndesign checks passed: every manifest row logged once with its pins, "
        "one payload hash, one listing outside the brainstorming line, "
        "expected brainstorming line per arm, expected counts"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except DesignError as error:
        print(f"DESIGN ERROR: {error}", file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 6: Check and commit in the evals clone**

Run, each its own command, from the evals clone with `E=evidence/2026-09-16-brainstorming-trigger-calibration`: `chmod +x $E/analyze.py $E/launch-all.sh $E/logs/measure-launch.sh`; `bash -n $E/logs/measure-launch.sh $E/launch-all.sh`; `shellcheck --severity=warning $E/logs/measure-launch.sh $E/launch-all.sh`; `/Users/johnss51/.local/bin/ruff check $E/analyze.py`; `/Users/johnss51/.local/bin/ruff format --check $E/analyze.py`; `/Users/johnss51/.local/bin/mypy --ignore-missing-imports $E/analyze.py`; `python3 $E/analyze.py --self-test` must exit 0 and print one `accepted as expected` line and three `refused as expected` lines (an indeterminate never re-run; a replacement whose original was not indeterminate; a rerun absent from `reruns.tsv`); then `python3 $E/analyze.py` must exit 1 with `DESIGN ERROR:` naming the unfilled manifest (no logs exist yet). No live run is launched in this task.

```bash
git add -f evidence/2026-09-16-brainstorming-trigger-calibration
git commit -m "evidence: manifest, launcher and fail-closed analysis for the brainstorming trigger calibration"
```

### Task 3: The measurement and its adjudication

**Risk tier:** high — live runs, the durable evidence, and the ship decision they feed.

**Files:**
- Create (evals clone, under `evidence/2026-09-16-brainstorming-trigger-calibration/`): `analysis.md`, `analysis-table.txt`, `runs.json`, `reruns.tsv`, `logs/*.log`, `runs-<scenario>/<arm>/<run>/...`
- Modify: `manifest.tsv` (the `harness` and `treatment` rows)

**Interfaces:**
- Consumes: Task 1's commit (treatment root), Task 2's scripts and manifest, the control root at `2e83fd8`, the evals clone at its head when Step 1 runs.
- Produces: the per-arm table (`analysis-table.txt`), `runs.json`, `reruns.tsv`, and the acceptance verdict in `analysis.md` that Task 4 cites.

- [ ] **Step 1: Controller fills the manifest and launches (not an implementer)**

From the evals clone with a clean tree: replace `<TASK_1_COMMIT>` with `git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger rev-parse HEAD` and `<EVALS_COMMIT>` with `git rev-parse HEAD` (Task 2's commit or later; it pins the harness paths, and the manifest commit that follows does not touch them), commit `manifest.tsv` alone (`git commit -m "evidence: pin the calibration's harness and treatment commits"`), then confirm the pin holds: `git diff --quiet <EVALS_COMMIT> HEAD -- src scenarios coding-agents package.json bun.lock && echo pinned`. Then run, from the evals clone, in the background with a log:

```bash
E=evidence/2026-09-16-brainstorming-trigger-calibration
nohup bash $E/launch-all.sh $E/manifest.tsv 8 > $E/logs/launch-all.out 2>&1 &
```

Wait in bounded stretches (`sleep 300` at most per check; never poll faster) until `launch-all.out` ends with `all launches finished; manifest logs without DONE: 0`. A non-zero count means a broken launch: read that log, fix the cause, move the log to `logs/failed/` (the analysis ignores that directory and will report the manifest row as missing until it is relaunched), and relaunch that row alone with `bash $E/logs/measure-launch.sh <arm> <scenario> 5 <proc>`, which re-checks every pin.

- [ ] **Step 2: Controller re-runs indeterminates once**

List indeterminates directly: `grep -l 'final *indeterminate' $E/logs/*-p*.log` and, per log, the `run-dir` of each indeterminate trial. For each, launch one replacement with a fresh rerun id: `bash $E/logs/measure-launch.sh <arm> <scenario> 1 r<k>` (k = 1, 2, ... unique across the campaign), wait for its log to end with `DONE`, read its `run-dir`, and append `<original-run-name><TAB><replacement-run-name>` to `$E/reruns.tsv` (create it with a first line `# original<TAB>replacement` if absent). A replacement that is indeterminate again stays in `reruns.tsv` and is excluded from the rate by the analysis; do not re-run a trial twice (the analysis rejects a second replacement).

- [ ] **Step 3: Analyze**

Run: `python3 $E/analyze.py > $E/analysis-table.txt; status=$?; cat $E/analysis-table.txt; [ "$status" -eq 0 ] && echo ANALYSIS OK` (no pipe: `tee` would hide the exit status).
Expected: `ANALYSIS OK`, one row per scenario and arm with the manifest's counts, the closing line `design checks passed: ...`. Any `DESIGN ERROR:` (printed on stderr; `analysis-table.txt` is then not a table) is a stop: fix the cause (a missing rerun row, a broken launch), never the check.

- [ ] **Step 4: Copy the runs, strip them, and check the staged tree**

For every run in `runs.json` (including replaced originals), copy its directory from `results/<run>` to `$E/runs-<scenario>/<arm>/<run>` (`cp -R`), run `scripts/strip-runs --min-age-minutes 0` over each copy (the default skips directories touched in the last hour, which a fresh copy always is), rename any nested `.git` directory or file to `git-dir`/`git-dir-file`, then stage with `git add -f $E` and check the staged tree before committing:

```bash
git diff --cached --raw | grep -c ' 160000 '                                      # must print 0
git grep --cached -l -E 'peerToken|prj-dcpgenai' -- "$E" | wc -l                    # must print 0
git diff --cached --name-only | grep -c -E '\.claude-env$|\.key$|/sessions/'       # must print 0
# The staged archive set must equal the run set in runs.json, and every archive
# must carry a transcript and a grader result. Expected paths come from
# runs.json, not from what happens to be on disk.
python3 -c 'import json,sys; [print(f"{r[\"scenario\"]}/{r[\"arm\"]}/{r[\"run\"]}") for r in json.load(open(sys.argv[1]))]' "$E/runs.json" | sort > "$TMPDIR/expected-archives.txt"
git ls-files --cached "$E" | grep -o -E 'runs-[^/]+/(control|treatment)/[^/]+' | sed 's/^runs-//' | sort -u > "$TMPDIR/staged-archives.txt"
diff "$TMPDIR/expected-archives.txt" "$TMPDIR/staged-archives.txt" && echo ARCHIVE SET OK     # must print ARCHIVE SET OK
while IFS=/ read -r scenario arm run; do
  r="$E/runs-$scenario/$arm/$run/"
  git ls-files --cached "$r" | grep -q 'home/.claude/projects/.*\.jsonl$' || echo "NO TRANSCRIPT $r"
  git ls-files --cached "$r" | grep -q 'gauntlet-agent/.*result.json$' || echo "NO RESULT $r"
done < "$TMPDIR/expected-archives.txt"                                             # must print nothing
```

- [ ] **Step 5: Write `analysis.md`**

Sections, in order: Instrument (harness commit, both roots' commits, model, Claude Code version from a transcript, the budget override, launch start and end times); the table from Step 3, verbatim; per-scenario reading of the first actions; Reruns (each original, its replacement, its outcome); Acceptance (each spec criterion with its numbers and a yes or no); Limits (single judge per trial, one model, one Claude Code version, the budget override exposes all fifteen descriptions, not only brainstorming's). State the verdict plainly: the description ships, or it does not.

- [ ] **Step 6: Commit in the evals clone**

```bash
git add -f evidence/2026-09-16-brainstorming-trigger-calibration
git commit -m "evidence: brainstorming trigger calibration, control and treatment arms"
```

### Task 4: Evidence note

**Risk tier:** standard — a documentation task whose content depends on Task 3's data.

**Files:**
- Create: `docs/hyperpowers/2026-09-16-brainstorming-trigger-calibration-eval-evidence.md`

**Interfaces:**
- Consumes: Task 3's `analysis.md`, `analysis-table.txt`, and the evals commit that holds them; the Task 1 commit.
- Produces: the note the final review reads; no changelog change (Global Constraints).

- [ ] **Step 1: Write the note**

Header lines `**Spec:**`, `**Plan:**`, `**Measured:**` (date), `**Control root:** 2e83fd8`, `**Treatment root:** <Task 1 commit>`, `**Harness:** <manifest harness commit>`, `**Evidence:** evals evidence/2026-09-16-brainstorming-trigger-calibration/ at <Task 3's evals commit>`. Then: What was measured (the mechanism paragraph from the spec, three sentences); the table copied from `analysis-table.txt`; Reruns (copied from `analysis.md`); Acceptance (the spec's criteria, each with numbers); Decision (ships or does not, in one sentence, with the human partner's stated preference quoted: false positives over false negatives, but no trigger where none is needed); Limits.

- [ ] **Step 2: Commit**

```bash
git add docs/hyperpowers/2026-09-16-brainstorming-trigger-calibration-eval-evidence.md
git commit -m "docs: evidence note for the brainstorming trigger calibration"
```
