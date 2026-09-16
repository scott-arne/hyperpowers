# Brainstorming Trigger Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-09-16-brainstorming-trigger-calibration-design.md`

**Goal:** Reword the `brainstorming` skill's description so a request that is one obvious edit implements directly while anything with design content still triggers, and ship it behind a two-arm live measurement on the eval suite's own calibration set.

**Architecture:** One frontmatter line changes in `skills/brainstorming/SKILL.md`; nothing else in the skill or the bootstrap moves. The measurement runs the hyperpowers-evals harness at one pinned commit twice per scenario, control against the branch base and treatment against this branch, both with Claude Code's skill-listing budget raised so the description is in the model's context. A manifest declares every trial; a launcher refuses to run unless roots and harness match it; an analysis script refuses to produce a table unless the observed runs match it exactly. Runs, logs, manifest, and analysis are committed in the evals clone; the hyperpowers evidence note cites them.

**Tech Stack:** bash test suites under `tests/`; hyperpowers-evals (Bun, `quorum run --repeat`, `claude-auto` coding agent, `claude-opus-5`); Python 3 (ruff and mypy clean) for the analysis.

## Global Constraints

- The new description text is the spec's, verbatim, double-quoted; it names no eval fixture. No other line of `skills/brainstorming/SKILL.md` and no line of `skills/using-hyperpowers/SKILL.md` changes.
- One harness commit for every trial, recorded as the `harness` row of `manifest.tsv` before the first launch; the launcher (`launch-all.sh`) exits 1 if the evals clone, the control root, or the treatment root is not at its manifest commit with a clean tree. Nothing from `evidence/2026-09-16-over-trigger-measurement/` is reused as a trial.
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
- Consumes: the two roots' paths (Global Constraints) and their `skills/brainstorming/SKILL.md` description lines (the analysis renders each arm's expected listing line from them); the Task 1 commit SHA for the manifest's `treatment` row.
- Produces: `manifest.tsv` (rows `harness<TAB>sha`, `control<TAB>sha`, `treatment<TAB>sha`, `model<TAB>claude-opus-5`, then one `arm<TAB>scenario<TAB>repeat<TAB>proc` row per launch); `launch-all.sh manifest.tsv [max]`; `logs/measure-launch.sh arm scenario repeat proc`; `analyze.py` writing `runs.json` and printing the table, exit 1 with `DESIGN ERROR:` on any deviation; `reruns.tsv` format (`original<TAB>replacement`, `#` comments) consumed by `analyze.py`.

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

Tab-separated. `<EVALS_COMMIT>` is filled by the controller at Task 3 Step 1 with `git rev-parse HEAD` of the evals clone at that moment; `<TASK_1_COMMIT>` is Task 1's full SHA. Until both are filled, `launch-all.sh` refuses to run.

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
# measure-launch.sh <arm> <scenario> <repeat> <proc-id>
# Runs one quorum process for the calibration and writes
# logs/<arm>-<scenario>-p<proc-id>.log with the roots' commits and cleanliness,
# the harness commit, the time, the exact command, and quorum's output. The last
# line is DONE only when quorum exited 0; otherwise it is FAILED <code>, which
# analyze.py treats as a design error rather than a smaller sample.
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
  code=$?
  echo "EXIT=$code"; date -u +%Y-%m-%dT%H:%M:%SZ
  # quorum exits 1 when any trial failed and 2 when any was indeterminate; both
  # are measurements, not launch failures. Anything else is a broken launch.
  case "$code" in 0|1|2) echo "DONE $arm $scen p$pid" ;; *) echo "FAILED $code $arm $scen p$pid" ;; esac
} > "$log" 2>&1
```

- [ ] **Step 4: Write `launch-all.sh`**

```bash
#!/usr/bin/env bash
# launch-all.sh <manifest.tsv> [max-concurrent]
# Runs every line of the manifest (arm<TAB>scenario<TAB>repeat<TAB>proc) through
# measure-launch.sh, at most N at a time (default 8), and waits for all of them.
# Refuses to start unless both roots are at their manifest commits with clean
# trees and the harness is at its manifest commit.
set -uo pipefail
manifest="$1"; max="${2:-8}"
E=/Users/johnss51/Development/agents/hyperpowers/evals/evidence/2026-09-16-brainstorming-trigger-calibration
EV=/Users/johnss51/Development/agents/hyperpowers/evals
expect() { # <repo> <sha> <label>
  local have; have=$(git -C "$1" rev-parse HEAD)
  [ "$have" = "$2" ] || { echo "$3 is at $have, manifest says $2" >&2; exit 1; }
  [ -z "$(git -C "$1" status --short)" ] || { echo "$3 has uncommitted changes" >&2; exit 1; }
}
expect "$EV" "$(grep '^harness' "$E/manifest.tsv" | cut -f2)" "harness"
expect /Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption "$(grep '^control' "$E/manifest.tsv" | cut -f2)" "control root"
expect /Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger "$(grep '^treatment' "$E/manifest.tsv" | cut -f2)" "treatment root"
running=0
while IFS=$'\t' read -r arm scen rep proc; do
  case "$arm" in control|treatment) ;; *) continue ;; esac
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$max" ]; do sleep 15; done
  bash "$E/logs/measure-launch.sh" "$arm" "$scen" "$rep" "$proc" &
  running=$((running + 1)); echo "started $arm $scen x$rep p$proc ($running launched) $(date -u +%H:%M:%SZ)"
done < "$manifest"
wait
failed=$(grep -L '^DONE' "$E"/logs/*.log 2>/dev/null | wc -l | tr -d ' ')
echo "all launches finished; logs without DONE: $failed"
[ "$failed" -eq 0 ]
```

- [ ] **Step 5: Write `analyze.py`**

```python
#!/usr/bin/env python3
"""Fail-closed analysis for the brainstorming trigger calibration.

Reads ``manifest.tsv`` (the declared design: harness commit, the two roots'
commits, the model, and one trial row per launch), the per-process logs under
``logs/``, and ``reruns.tsv`` (original run -> replacement run). The expected
brainstorming listing line per arm is rendered from each root's
``skills/brainstorming/SKILL.md`` description. Every trial collapses to
one outcome. Any deviation from the declared design is an error, not a skipped
row. Writes ``runs.json`` and prints the per-arm table.
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
RUN_DIR_RE = re.compile(r"run-dir\s+(\S+)")
LOG_RE = re.compile(r"(control|treatment)-(.+)-p\d+\.log")
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


ROOTS = {
    "control": "/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption",
    "treatment": "/Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger",
}


def read_manifest() -> dict:
    """Parse manifest.tsv into commits, the model, and expected trial counts."""

    manifest: dict = {"trials": {}, "commits": {}, "model": ""}
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
                arm, scenario, repeat = cells[0], cells[1], int(cells[2])
                manifest["trials"].setdefault(scenario, {}).setdefault(arm, 0)
                manifest["trials"][scenario][arm] += repeat
            else:
                raise DesignError(f"manifest.tsv: unreadable line {line!r}")
    for key in ("harness", "control", "treatment"):
        if key not in manifest["commits"]:
            raise DesignError(f"manifest.tsv: no {key} commit")
    if not manifest["model"]:
        raise DesignError("manifest.tsv: no model")
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


def read_logs() -> list[tuple[str, str, str, str]]:
    rows: list[tuple[str, str, str, str]] = []
    for log in sorted(glob.glob(os.path.join(E, "logs", "*.log"))):
        match = LOG_RE.match(os.path.basename(log))
        if not match:
            continue
        with open(log, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        if "\nDONE " not in text:
            raise DesignError(
                f"{log}: the launch did not finish cleanly (no DONE line)"
            )
        for found in RUN_DIR_RE.finditer(text):
            rows.append(
                (match.group(1), match.group(2), found.group(1).rstrip("/"), log)
            )
    return rows


def read_reruns() -> dict[str, str]:
    path = os.path.join(E, "reruns.tsv")
    replaced: dict[str, str] = {}
    if not os.path.exists(path):
        return replaced
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            original, replacement = line.split()[:2]
            replaced[replacement] = original
    return replaced


def build_runs(manifest: dict) -> list[Run]:
    replaced = read_reruns()
    runs: list[Run] = []
    seen: set[str] = set()
    for arm, scenario, run_dir, log in read_logs():
        if not os.path.isabs(run_dir):
            run_dir = os.path.join(EV, run_dir)
        name = os.path.basename(run_dir)
        if name in seen:
            raise DesignError(f"{name}: listed twice ({log})")
        seen.add(name)
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
    return runs


def collapse(runs: list[Run]) -> list[Run]:
    """One outcome per trial: a replacement stands in for its original."""

    by_name = {run.run: run for run in runs}
    replaced_originals = {run.replaces for run in runs if run.replaces}
    for original in replaced_originals:
        if original not in by_name:
            raise DesignError(f"reruns.tsv names an unknown original {original}")
        if by_name[original].final != "indeterminate":
            raise DesignError(f"{original} was replaced but was not indeterminate")
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
        lines = {t.brainstorming_line for t in trials if t.arm == arm}
        if lines != {expected_brainstorming_line(arm)}:
            raise DesignError(f"{arm}: brainstorming line {sorted(lines)}")
    models = {t.model for t in trials}
    if models != {manifest["model"]}:
        raise DesignError(f"models differ from the design: {sorted(models)}")


def main() -> int:
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
        "\ndesign checks passed: one payload hash, one listing outside the brainstorming line, expected lines per arm, expected counts"
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

Run, each its own command, from the evals clone with `E=evidence/2026-09-16-brainstorming-trigger-calibration`: `chmod +x $E/analyze.py $E/launch-all.sh $E/logs/measure-launch.sh`; `bash -n $E/logs/measure-launch.sh $E/launch-all.sh`; `shellcheck --severity=warning $E/logs/measure-launch.sh $E/launch-all.sh`; `/Users/johnss51/.local/bin/ruff check $E/analyze.py`; `/Users/johnss51/.local/bin/ruff format --check $E/analyze.py`; `/Users/johnss51/.local/bin/mypy --ignore-missing-imports $E/analyze.py`; then `python3 $E/analyze.py` must exit 1 with `DESIGN ERROR:` naming the unfilled manifest (no logs exist yet) — that is the fail-closed behaviour under test. No live run is launched in this task.

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

From the evals clone: replace `<TASK_1_COMMIT>` with `git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/brainstorming-trigger rev-parse HEAD` and `<EVALS_COMMIT>` with `git rev-parse HEAD` (both trees clean), commit `manifest.tsv` alone (`git commit -m "evidence: pin the calibration's harness and treatment commits"`), and re-read `git rev-parse HEAD` — that new commit is NOT the harness value; the harness row names the commit the runs are taken at, so fill it with the SHA after this commit in a second one-line commit if they differ, then verify `launch-all.sh` accepts the tree. Then run, from the evals clone, in the background with a log:

```bash
E=evidence/2026-09-16-brainstorming-trigger-calibration
nohup bash $E/launch-all.sh $E/manifest.tsv 8 > $E/logs/launch-all.out 2>&1 &
```

Wait in bounded stretches (`sleep 300` at most per check; never poll faster) until `launch-all.out` ends with `all launches finished; logs without DONE: 0`. A non-zero count means a broken launch: read that log, fix the cause, delete only that log's run directories from consideration by removing the log, and relaunch that row alone with `bash $E/logs/measure-launch.sh <arm> <scenario> 5 <proc>`.

- [ ] **Step 2: Controller re-runs indeterminates once**

Run `python3 $E/analyze.py`; it fails closed until counts match, so first list indeterminates directly: `grep -l 'final *indeterminate' $E/logs/*.log` and, per log, the `run-dir` of each indeterminate trial. For each, launch one replacement: `bash $E/logs/measure-launch.sh <arm> <scenario> 1 r<k>` (k = 1, 2, ...), then append `<original-run-name><TAB><replacement-run-name>` to `$E/reruns.tsv` (create it with a first line `# original<TAB>replacement` if absent). Replacements that are indeterminate again stay in `reruns.tsv` and are excluded from the rate by the analysis; do not re-run a trial twice.

- [ ] **Step 3: Analyze**

Run: `python3 $E/analyze.py | tee $E/analysis-table.txt`
Expected: exit 0, one row per scenario and arm with the manifest's counts, the closing line `design checks passed: ...`. Any `DESIGN ERROR:` is a stop: fix the cause (a missing rerun row, a broken launch), never the check.

- [ ] **Step 4: Copy the runs, strip them, and check the staged tree**

For every run in `runs.json` (including replaced originals), copy its directory from `results/<run>` to `$E/runs-<scenario>/<arm>/<run>` (`cp -R`), run `scripts/strip-runs` over each copy, rename any nested `.git` directory or file to `git-dir`/`git-dir-file`, then stage with `git add -f $E` and check the staged tree before committing:

```bash
git diff --cached --raw | grep -c ' 160000 '                    # must print 0
git grep --cached -l -E 'peerToken|prj-dcpgenai' -- "$E" | wc -l  # must print 0
for r in "$E"/runs-*/*/*/; do
  git ls-files --cached "$r" | grep -q 'home/.claude/projects/.*\.jsonl$' || echo "NO TRANSCRIPT $r"
  git ls-files --cached "$r" | grep -q 'gauntlet-agent/.*result.json$' || echo "NO RESULT $r"
done                                                              # must print nothing
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
