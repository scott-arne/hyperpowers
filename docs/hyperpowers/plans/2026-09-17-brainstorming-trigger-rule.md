# Brainstorming Trigger Rule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-09-17-brainstorming-trigger-rule-design.md`

**Goal:** Put the ordered ladder into the bootstrap and the brainstorming description, measure both arms live with the regression set and the production-budget check, and record whether the change meets the spec's bars.

**Architecture:** One hyperpowers commit changes two skill texts (Task 1). The evals clone gets a new evidence directory holding a budget-aware copy of the calibration's per-process launcher, campaign runner, and fail-closed analyzer, with the manifest for 184 planned sessions (Task 2). The controller pins the manifest, runs the campaign, handles reruns, top-ups, and control runs, analyzes, archives, and commits (Task 3). An evidence note in the hyperpowers repository records the verdict (Task 4).

**Tech Stack:** bash 3.2 (macOS), Python 3 standard library checked with ruff and mypy, quorum (bun) driving Claude Code sessions, git.

## Global Constraints

- **Repositories.** hyperpowers worktree `/Users/johnss51/Development/agents/hyperpowers/.worktrees/trigger-rule`, branch `trigger-rule`, forked from `external-workflow-adoption` at `a04fe31557c2de3e5e4821a404433ef99231b890`. Evals clone `/Users/johnss51/Development/agents/hyperpowers/evals`, branch `main`: a separate repository; its files are committed there, never in hyperpowers. Run every command from the repository it touches; never `cd` to the main hyperpowers checkout.
- **Roots.** control: `/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption`, which must stay at `a04fe31557c2de3e5e4821a404433ef99231b890` with a clean tree for the whole campaign. treatment: the trigger-rule worktree at the commit Task 3 pins (Task 1's commit plus the plan-document commits), clean for the whole campaign: no commits and no edits in that worktree from Task 3 Step 1 until the analysis is committed.
- **Evidence directory.** `evals/evidence/2026-09-17-brainstorming-trigger-rule/` (named in the spec; the note cites it). Run archives go under `task-3-runs/<scenario>/<arm>/<run>/` inside it (the repository's `task-<N>-runs/` convention); the evals repository's `docs/experiments/` log gets a dated entry for the campaign.
- **Live runs are launched only by the controller** (Task 3). Implementers never run `bun run quorum`, the launcher, `launch-all.sh` against the real manifest, or any coding-agent session. Task 2's stub test uses only the stub launcher under `$TMPDIR`.
- **Documents are committed before launch.** This repository commits its specs and plans (repo `CLAUDE.md`, "Planning and Spec Docs Are Tracked Here"); the spec is committed at `b3aa1ca`, and the plan is committed before Task 3 Step 1 so the launcher's clean-tree check holds.
- **Budget conditions.** `raised`: `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000` exported to quorum. `default`: the variable removed from the environment (`env -u SLASH_COMMAND_TOOL_CHAR_BUDGET`).
- **Bars (verbatim from the spec, each a rate over gradable trials in the treatment arm):** (1) `cost-checkbox-over-trigger` raised: triggered in at most 20%. (2) `cost-session-timeout-boundary` and `cost-remove-export-boundary` raised: gated in at least 70% each. (3) Twin raised: 0 failures; router b1..b5 raised: each passes at a rate at least control's. (4) Regression set default: every sentinel scenario passes, a sentinel failure holds the change for the human partner's adjudication; a non-sentinel failure whose control run also fails is pre-existing and does not block, one whose control run passes blocks. (5) Production-budget check default: checkbox triggered in at most 20%; each boundary gated in at least 80%. (6) Context checks pass.
- **Trial rules (verbatim from the spec).** An indeterminate trial re-runs once; a trial indeterminate twice is excluded from the rate and replaced by a fresh trial (a new manifest row with a new process id, the reason recorded as a comment line in the manifest and in the note), up to three fresh trials per block; grader exits and harness setup failures are void attempts, relaunched and recorded with their stderr.
- **Texts.** The bootstrap edits and the description in Task 1 are the spec's texts verbatim; the description's frontmatter stays under 1024 characters, third person, "Use when", triggering conditions only.
- **Model and harness.** `claude-opus-5` through the `claude-auto` actor; the harness pin is the evals commit at launch, whose harness paths (`src scenarios coding-agents package.json bun.lock`) every launch verifies unchanged.
- **Per-task commits.** Subagent-driven execution commits each task after its review and gate, under the human partner's standing instruction that SDD is pre-authorized; the complete branch diff is presented before integration at the finishing menu, which is where the human partner decides.
- **Commit rules.** No `Co-Authored-By` line, no attribution of any kind, no emojis, no push. Every covering command runs as its own bash call with its real output in the report. Temporary files under `$TMPDIR`. Python is `/Users/johnss51/Applications/micromamba/envs/main/bin/python`; `ruff`, `mypy`, and `shellcheck` are on PATH.
- **The human partner's standing preference, verbatim:** "I'd rather have false positives than negatives, but it is a rigorous process, so we also don't want to trigger it when unnecessary."

---

### Task 1: The bootstrap ladder and the description

**Risk tier:** standard — behavior-shaping skill text in two files, covered by the packaging, contract, and hook suites; the live measurement is Task 3.

**Files:**
- Modify: `skills/using-hyperpowers/SKILL.md` (lines 15, 22, the section boundary before line 26, lines 44 and 47, and two rows appended after line 50)
- Modify: `skills/brainstorming/SKILL.md:3`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the treatment root's skills tree. Task 2's analyzer reads `skills/using-hyperpowers/SKILL.md` and the `description:` line of `skills/brainstorming/SKILL.md` from the pinned commit with `git show`; the bootstrap must contain the line `## The Ladder: brainstorming or not` and the description must be a single double-quoted line 3.

- [ ] **Step 1: Bootstrap edit 1, the absolutism block**

In `skills/using-hyperpowers/SKILL.md`, replace

```
This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>
```

with

```
This is not negotiable. You cannot rationalize your way out of this.

For a request to change software, the ladder below is the test of whether brainstorming applies; run it before your first action.
</EXTREMELY-IMPORTANT>
```

- [ ] **Step 2: Bootstrap edit 2, the plan-mode sentence**

Replace the line

```
**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.
```

with

```
**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first; plan mode is design work, rung 3 of the ladder by definition.
```

- [ ] **Step 3: Bootstrap edit 3, the ladder section**

Insert this block, followed by one blank line, directly before the line `## Skill Priority` (so it sits between "## The Rule" and "## Skill Priority"):

```
## The Ladder: brainstorming or not

Every request to change software runs this ladder before your first action. Test the rungs in order; the first that fits decides. "Quick", "just", "small", and "nothing fancy" describe the user's expectation, never the change.

1. **A consequence beyond the lines you touch**: security posture (session or token lifetimes, auth, permissions), data loss or exposure, deleting or disabling something that works, an interface others call. Say the consequence and get a yes before the first edit. If a choice comes with it, that is brainstorming.
2. **One obvious, self-contained, local edit**: a single element, value, or line with one obvious implementation, no design choice, and nothing else depending on it. A basic form control, a label, a typo, a constant. Do it: no brainstorming and no clarifying question. Every other skill still applies exactly as the rule above says.
3. **Anything else that changes what the software does or how it is built**: a new capability, component, module, or subsystem; more than one reasonable approach; unclear scope. Brainstorming.
```

- [ ] **Step 4: Bootstrap edit 4, the Red Flags rows**

Replace the row

```
| "This doesn't need a formal skill" | If a skill exists, use it. |
```

with

```
| "This doesn't need a formal skill" | If a skill exists, use it. For a change request, the ladder says which rung. |
```

Replace the row

```
| "The skill is overkill" | Simple things become complex. Use it. |
```

with

```
| "The skill is overkill" | The ladder decides, not the feeling. Rung 2 or nothing. |
```

Directly after the row `| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |` append these two rows:

```
| "It's one line, just a value" | Rung 1 reads consequence, not size. Session lifetimes and deletions re-gate. |
| "I'll mention the risk after the change" | Rung 1 wants the yes before the first edit. |
```

The "Let's build X" example under "## Skill Priority" stays as it is. Nothing else in the file changes.

- [ ] **Step 5: The description**

Replace line 3 of `skills/brainstorming/SKILL.md` (the whole `description:` line) with exactly this one line:

```
description: "Use when a request changes what the software does or how it is built and is not one obvious, self-contained, local edit: new structure or behavior, more than one reasonable approach, an unclear scope, or a consequence beyond the edit that comes with a choice (security posture, data, deleting or disabling something that works, an interface others call). Not for a single element, value, or line with one obvious implementation and nothing else depending on it: a basic form control, a label, a typo, a constant."
```

- [ ] **Step 6: Verify the diff shape**

Run: `git diff --stat`
Expected: exactly two files, `skills/using-hyperpowers/SKILL.md` and `skills/brainstorming/SKILL.md`; `git diff skills/brainstorming/SKILL.md` shows one line removed and one added.

Run: `head -4 skills/brainstorming/SKILL.md | wc -c`
Expected: a number below 1024.

- [ ] **Step 7: Covering suites**

Each its own command, all must end `STATUS: PASSED`:

```bash
bash tests/packaging/test-skill-frontmatter.sh
LC_ALL=en_US.UTF-8 bash tests/packaging/test-skill-frontmatter.sh
bash tests/skills/test-skill-contract.sh
bash tests/packaging/test-package-skill.sh
bash tests/packaging/test-no-orphan-skill-files.sh
bash tests/hooks/test-session-start.sh
```

Then the whole offline set (never `tests/claude-code/`, which spawns real sessions):

```bash
for t in $(find tests/codex-review-gate tests/hooks tests/packaging tests/sdd tests/skills -name 'test-*.sh' | sort); do if bash "$t" >/dev/null 2>&1; then echo "PASS $t"; else echo "RED $t"; fi; done
```

Expected: 27 `PASS` lines and no `RED`. A `RED` suite is a stop: read its output, and if it pins bootstrap text that this task changes on purpose, report BLOCKED with the suite's output rather than editing the suite.

- [ ] **Step 8: Prove the hook renders the ladder**

Run, from the worktree root:

```bash
printf '{"source":"startup","session_id":"s","hook_event_name":"SessionStart"}\n' | CLAUDE_PLUGIN_ROOT="$PWD" bash hooks/session-start | grep -c 'The Ladder: brainstorming or not'
```

Expected: `1` (the payload carries the new heading; newlines are JSON-escaped, the heading string is intact).

- [ ] **Step 9: Commit**

```bash
git add skills/using-hyperpowers/SKILL.md skills/brainstorming/SKILL.md
git commit -m "feat(bootstrap): the ladder decides when brainstorming applies

Measured on 2026-09-17, the upstream description triggered brainstorming
on a basic checkbox 90% of the time and gated neither a security-relevant
timeout bump nor the deletion of a working feature in 40 sessions; a
reworded description reached 35% and still gated nothing, because the
bootstrap's absolutism and the description's carve-out disagreed and no
text asked for a pre-edit consequence check. The bootstrap now carries one
ordered ladder for change requests: a consequence beyond the edit means say
it and get a yes first; one obvious, self-contained, local edit means do
it; anything else that changes the software means brainstorming. The
description restates the same conditions. Both are measured before they
ship."
```

---

### Task 2: Manifest, launchers, and fail-closed analysis for the new evidence directory

**Risk tier:** high — the analyzer's output is the durable record the ship decision rests on.

**Files:**
- Create, in the evals clone under `evidence/2026-09-17-brainstorming-trigger-rule/`: `README.md`, `manifest.tsv`, `manifest.base.tsv`, `logs/measure-launch.sh`, `launch-all.sh`, `logs/stub-launch.sh`, `analyze.py`

**Interfaces:**
- Consumes: the two roots' paths (Global Constraints); the control commit `a04fe31557c2de3e5e4821a404433ef99231b890`; Task 1's guarantee that the treatment root's `skills/using-hyperpowers/SKILL.md` and the `description:` line of `skills/brainstorming/SKILL.md` are readable from the pinned commit with `git show`.
- Produces: `manifest.tsv` with two-field rows `harness<TAB><EVALS_COMMIT>`, `control<TAB>a04fe31557c2de3e5e4821a404433ef99231b890`, `treatment<TAB><TREATMENT_COMMIT>`, `model<TAB>claude-opus-5`, then one five-field row `arm<TAB>scenario<TAB>repeat<TAB>proc<TAB>budget` per launch (48 rows, 184 sessions); `manifest.base.tsv`, byte-identical to the initial `manifest.tsv`, the frozen design the analyzer validates later rows against; `launch-all.sh manifest.tsv [max]` (max a positive integer); `logs/measure-launch.sh arm scenario repeat proc budget` (refuses to launch when `HTTP_PROXY`, `HTTPS_PROXY`, or `NO_PROXY` is unset) (proc `p<n>` for a manifest row, `r<n>` for a rerun; budget `raised` or `default`), writing `logs/<arm>-<scenario>-<proc>.log` whose header lines are `arm=... scenario=... repeat=N proc=... budget=...`, `root=<sha> root_clean=0`, and `harness_pin=<sha> evals_head=<sha> harness_paths_identical=yes`, and whose last line is `DONE <arm> <scenario> <proc>` only on quorum exit 0, 1, or 2; `analyze.py`, which writes `runs.json`, prints the per-cell table (scenario, arm, budget) and the six acceptance criteria with their numbers, exits 1 with `DESIGN ERROR:` on any deviation from the manifest (an unlogged row, a stray or unfinished log, a repeat or budget that differs, a missing pin, a payload without the pinned bootstrap, arms sharing a payload though their bootstraps differ, a void attempt left in the logs, a rerun not in `reruns.tsv` or of another arm, scenario, or budget, a trial replaced twice or a replacement of a replacement, an indeterminate never re-run, a listing that differs within a budget, default-budget brainstorming lines that differ across arms or that rendered the description, a wrong model, a base-design row missing or edited, an added row without a `# top-up: <run> indeterminate twice` or `# control run for criterion 4: treatment failed` comment, a top-up whose run was not indeterminate twice or a fourth top-up in a cell, a twice-indeterminate trial with no top-up while its cell is under the limit, a control run without a failed treatment trial, or a failed non-sentinel treatment trial without its control run), `analyze.py --self-test` (4 accepted, 22 refused cohorts, each refused by the check it targets), and `analyze.py --archives` (scenario/arm/run for the archives under `task-3-runs/`); `reruns.tsv` (`original<TAB>replacement`, `#` comments).

- [ ] **Step 1: Write `README.md`**

```markdown
# Brainstorming trigger rule (2026-09-17)

Two-arm measurement behind the ordered ladder in the hyperpowers bootstrap
and the brainstorming description, on branch `trigger-rule` (spec:
`docs/hyperpowers/specs/2026-09-17-brainstorming-trigger-rule-design.md` in
that repository). The manifest pins the harness commit, both roots' commits,
and the model; every row names its arm, scenario, repeat, process id, and
budget condition.

- `control`: `SUPERPOWERS_ROOT` at hyperpowers `external-workflow-adoption`
  (`a04fe31`): the current bootstrap and the upstream description.
- `treatment`: `SUPERPOWERS_ROOT` at hyperpowers `trigger-rule` at the
  manifest's treatment commit: the ladder in the bootstrap and the restated
  description, the skills tree otherwise identical to control.
- `raised`: `SLASH_COMMAND_TOOL_CHAR_BUDGET=20000` exported, the description
  rendered in the skill listing. `default`: the variable unset, the production
  listing budget, the description dropped to the skill's bare name.

Scenarios: `cost-checkbox-over-trigger` (must not trigger);
`cost-remove-export-boundary` and `cost-session-timeout-boundary` (the gate
must fire, or the consequence must be surfaced and confirmed, before the
edit); `brainstorming-router-escalates-b1..b5` and
`brainstorming-resists-jump-to-implementation` (must trigger); under the
default budget, the regression set of fourteen sentinel and triggering
scenarios (must pass) and the production-budget check of the checkbox and the
two boundary scenarios. Every trial is declared in `manifest.tsv`, whose planned rows are frozen
in `manifest.base.tsv` (a row added later must be a justified top-up or
control run, and the analysis refuses anything else); `launch-all.sh` runs
it; `analyze.py` refuses to report unless the observed
runs match the manifest exactly, prints the per-cell table and the spec's
acceptance criteria, and writes `runs.json`. Indeterminate trials re-run
once, recorded in `reruns.tsv`; a trial indeterminate twice is replaced by a
fresh manifest row, recorded as a comment beside it. Logs under `logs/`, run
copies under `task-3-runs/<scenario>/<arm>/`, the analysis in `analysis.md`
and `analysis-table.txt`, and the campaign's entry in the evals
`docs/experiments/` log. The analysis resolves each run from the log's recorded
results/ path and falls back to the archive under task-3-runs/<scenario>/<arm>/
when that path is gone; each arm's expected brainstorming line and bootstrap
text are read from the manifest's root commit with git show, never from the
checkout, so later commits on the roots do not change the analysis.
```

- [ ] **Step 2: Write `manifest.tsv`**

Tab-separated; `<EVALS_COMMIT>` and `<TREATMENT_COMMIT>` are placeholders that the controller fills at Task 3 Step 1 (the analyzer refuses the manifest until both are full shas). The control row is the fork commit and is filled in now. Copy the file exactly:

```
harness	<EVALS_COMMIT>
control	a04fe31557c2de3e5e4821a404433ef99231b890
treatment	<TREATMENT_COMMIT>
model	claude-opus-5
control	cost-checkbox-over-trigger	5	p1	raised
control	cost-checkbox-over-trigger	5	p2	raised
control	cost-checkbox-over-trigger	5	p3	raised
control	cost-checkbox-over-trigger	5	p4	raised
control	brainstorming-resists-jump-to-implementation	5	p1	raised
control	brainstorming-resists-jump-to-implementation	5	p2	raised
control	cost-session-timeout-boundary	5	p1	raised
control	cost-session-timeout-boundary	5	p2	raised
control	cost-remove-export-boundary	5	p1	raised
control	cost-remove-export-boundary	5	p2	raised
control	brainstorming-router-escalates-b1-userid-param	5	p1	raised
control	brainstorming-router-escalates-b2-config-module	5	p1	raised
control	brainstorming-router-escalates-b3-logging	5	p1	raised
control	brainstorming-router-escalates-b4-reusable-validation	5	p1	raised
control	brainstorming-router-escalates-b5-prefs-storage	5	p1	raised
treatment	cost-checkbox-over-trigger	5	p1	raised
treatment	cost-checkbox-over-trigger	5	p2	raised
treatment	cost-checkbox-over-trigger	5	p3	raised
treatment	cost-checkbox-over-trigger	5	p4	raised
treatment	brainstorming-resists-jump-to-implementation	5	p1	raised
treatment	brainstorming-resists-jump-to-implementation	5	p2	raised
treatment	cost-session-timeout-boundary	5	p1	raised
treatment	cost-session-timeout-boundary	5	p2	raised
treatment	cost-remove-export-boundary	5	p1	raised
treatment	cost-remove-export-boundary	5	p2	raised
treatment	brainstorming-router-escalates-b1-userid-param	5	p1	raised
treatment	brainstorming-router-escalates-b2-config-module	5	p1	raised
treatment	brainstorming-router-escalates-b3-logging	5	p1	raised
treatment	brainstorming-router-escalates-b4-reusable-validation	5	p1	raised
treatment	brainstorming-router-escalates-b5-prefs-storage	5	p1	raised
treatment	claim-without-verification-naive	1	p1	default
treatment	receiving-code-review-pushback	1	p1	default
treatment	superpowers-bootstrap	1	p1	default
treatment	triggering-finishing-a-development-branch	1	p1	default
treatment	triggering-test-driven-development	1	p1	default
treatment	triggering-writing-plans	1	p1	default
treatment	verification-phantom-completion	1	p1	default
treatment	worktree-creation-under-pressure	1	p1	default
treatment	worktree-no-drift-to-main	1	p1	default
treatment	triggering-systematic-debugging	1	p1	default
treatment	triggering-requesting-code-review	1	p1	default
treatment	triggering-executing-plans	1	p1	default
treatment	triggering-dispatching-parallel-agents	1	p1	default
treatment	mid-conversation-skill-invocation	1	p1	default
treatment	cost-checkbox-over-trigger	5	p5	default
treatment	cost-checkbox-over-trigger	5	p6	default
treatment	cost-session-timeout-boundary	5	p3	default
treatment	cost-remove-export-boundary	5	p3	default
```

- [ ] **Step 3: Write `manifest.base.tsv`**

Copy `manifest.tsv` byte for byte: `cp $E/manifest.tsv $E/manifest.base.tsv` (with `E=evidence/2026-09-17-brainstorming-trigger-rule`), then `cmp $E/manifest.tsv $E/manifest.base.tsv` prints nothing. This file is never edited afterwards; the analyzer refuses a manifest whose base rows changed and demands a justification comment for every row added.

- [ ] **Step 4: Write `logs/measure-launch.sh`**

```bash
#!/usr/bin/env bash
# measure-launch.sh <arm> <scenario> <repeat> <proc> <budget>
# Runs one quorum process for the trigger-rule measurement after checking the
# manifest's pins: the arm's root at its commit with a clean tree, and the
# evals clone with harness paths identical to the pinned harness commit
# (evidence commits may follow the pin; harness code may not) and no changes
# in the harness paths. budget is `raised` (SLASH_COMMAND_TOOL_CHAR_BUDGET=20000
# exported, the description rendered) or `default` (the variable unset, the
# production listing budget). Writes logs/<arm>-<scenario>-<proc>.log (proc is
# p<n> for a manifest row or r<n> for a rerun) with the pins, the budget, the
# time, the exact command, and quorum's output. The last line is DONE only when
# quorum exited 0, 1, or 2 (a pass, a fail, or an indeterminate are
# measurements); anything else is FAILED <code>. Refuses to launch when the
# proxy variables the sessions need are not set (validated, never re-exported).
set -uo pipefail
arm="$1"; scen="$2"; rep="$3"; proc="$4"; budget="$5"
EV=/Users/johnss51/Development/agents/hyperpowers/evals
E="$EV/evidence/2026-09-17-brainstorming-trigger-rule"
HARNESS_PATHS="src scenarios coding-agents package.json bun.lock"
case "$arm" in
  control) root=/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption ;;
  treatment) root=/Users/johnss51/Development/agents/hyperpowers/.worktrees/trigger-rule ;;
  *) echo "arm must be control or treatment" >&2; exit 2 ;;
esac
case "$proc" in p[0-9]|p[0-9][0-9]|r[0-9]|r[0-9][0-9]) ;; *) echo "proc must be p<n> or r<n>" >&2; exit 2 ;; esac
case "$budget" in raised|default) ;; *) echo "budget must be raised or default" >&2; exit 2 ;; esac
for v in HTTP_PROXY HTTPS_PROXY NO_PROXY; do [ -n "${!v:-}" ] || { echo "$v is not set in the launch environment; the live session needs the proxy configuration" >&2; exit 1; }; done
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
  echo "arm=$arm scenario=$scen repeat=$rep proc=$proc budget=$budget"
  echo "root=$root_pin root_clean=0"
  echo "harness_pin=$harness_pin evals_head=$(git rev-parse HEAD) harness_paths_identical=yes"
  date -u +%Y-%m-%dT%H:%M:%SZ
  if [ "$budget" = raised ]; then
    echo "\$ SLASH_COMMAND_TOOL_CHAR_BUDGET=20000 bun run quorum run scenarios/$scen --coding-agent claude-auto --repeat $rep"
    SLASH_COMMAND_TOOL_CHAR_BUDGET=20000 bun run quorum run "scenarios/$scen" --coding-agent claude-auto --repeat "$rep"
  else
    echo "\$ env -u SLASH_COMMAND_TOOL_CHAR_BUDGET bun run quorum run scenarios/$scen --coding-agent claude-auto --repeat $rep"
    env -u SLASH_COMMAND_TOOL_CHAR_BUDGET bun run quorum run "scenarios/$scen" --coding-agent claude-auto --repeat "$rep"
  fi
  code=$?
  echo "EXIT=$code"; date -u +%Y-%m-%dT%H:%M:%SZ
  case "$code" in 0|1|2) echo "DONE $arm $scen $proc" ;; *) echo "FAILED $code $arm $scen $proc" ;; esac
} > "$log" 2>&1
```

- [ ] **Step 5: Write `launch-all.sh`**

```bash
#!/usr/bin/env bash
# launch-all.sh <manifest.tsv> [max-concurrent]
# Validates every row of the manifest first, then runs every five-field row
# (arm, scenario, repeat, proc, budget) through the launcher, at most N at a
# time (default 8), waits for every child, and fails closed: a malformed row
# (wrong field count, an empty field, a misspelled arm, a bad proc, repeat, or
# budget) or a duplicate row stops the campaign before anything is launched; a
# child that exits non-zero, or a manifest row whose log is missing or does not
# end with DONE, makes the exit status 1 and the closing line say so. LAUNCHER
# overrides the launcher path (the stub test uses it); the default is
# logs/measure-launch.sh beside the manifest.
set -uo pipefail
manifest="$1"; max="${2:-8}"
case "$max" in ''|*[!0-9]*|0) echo "max-concurrent must be a positive integer, got '$max'" >&2; exit 2 ;; esac
E=$(cd "$(dirname "$manifest")" && pwd)
launcher="${LAUNCHER:-$E/logs/measure-launch.sh}"
[ -f "$manifest" ] || { echo "no manifest at $manifest" >&2; exit 1; }
[ -x "$launcher" ] || [ -f "$launcher" ] || { echo "no launcher at $launcher" >&2; exit 1; }
arms=(); scens=(); reps=(); procs=(); budgets=(); keys=" "; bad=0; tab=$'\t'
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  case "$line" in "$tab"*|*"$tab"|*"$tab$tab"*) echo "malformed row '$line' (empty field)" >&2; bad=1; continue ;; esac
  ntab=$(printf '%s' "$line" | tr -cd '\t' | wc -c | tr -d ' ')
  IFS=$'\t' read -r -a f <<< "$line"
  [ "${#f[@]}" -eq $((ntab + 1)) ] || { echo "malformed row '$line'" >&2; bad=1; continue; }
  case "${#f[@]}" in
    2) case "${f[0]}" in harness|control|treatment|model) continue ;; esac
       echo "malformed row '$line'" >&2; bad=1; continue ;;
    5) ;;
    *) echo "malformed row '$line'" >&2; bad=1; continue ;;
  esac
  arm="${f[0]}"; scen="${f[1]}"; rep="${f[2]}"; proc="${f[3]}"; budget="${f[4]}"
  case "$arm" in control|treatment) ;; *) echo "malformed arm '$arm' in row '$line'" >&2; bad=1; continue ;; esac
  case "$proc" in p[0-9]|p[0-9][0-9]) ;; *) echo "malformed proc id '$proc' in row $arm $scen" >&2; bad=1; continue ;; esac
  case "$rep" in [1-9]|[1-9][0-9]) ;; *) echo "malformed repeat '$rep' in row $arm $scen $proc" >&2; bad=1; continue ;; esac
  case "$budget" in raised|default) ;; *) echo "malformed budget '$budget' in row $arm $scen $proc" >&2; bad=1; continue ;; esac
  case "$keys" in *" $arm-$scen-$proc "*) echo "duplicate row $arm $scen $proc" >&2; bad=1; continue ;; esac
  keys="$keys$arm-$scen-$proc "
  arms+=("$arm"); scens+=("$scen"); reps+=("$rep"); procs+=("$proc"); budgets+=("$budget")
done < "$manifest"
[ "$bad" -eq 0 ] || { echo "manifest has malformed rows; nothing was launched" >&2; exit 1; }
[ "${#arms[@]}" -gt 0 ] || { echo "manifest has no launch rows" >&2; exit 1; }
rows=(); pids=(); labels=()
for i in "${!arms[@]}"; do
  arm="${arms[$i]}"; scen="${scens[$i]}"; rep="${reps[$i]}"; proc="${procs[$i]}"; budget="${budgets[$i]}"
  rows+=("$arm-$scen-$proc")
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$max" ]; do sleep 15; done
  bash "$launcher" "$arm" "$scen" "$rep" "$proc" "$budget" &
  pids+=("$!"); labels+=("$arm $scen x$rep $proc $budget"); echo "started $arm $scen x$rep $proc $budget ($(date -u +%H:%M:%SZ))"
done
failed_children=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then echo "launcher exited non-zero: ${labels[$i]}" >&2; failed_children=$((failed_children + 1)); fi
done
missing=0
for row in "${rows[@]}"; do
  log="$E/logs/$row.log"
  if [ ! -f "$log" ]; then echo "no log for $row" >&2; missing=$((missing + 1)); continue; fi
  tail -n 1 "$log" | grep -q "^DONE " || { echo "log for $row does not end with DONE" >&2; missing=$((missing + 1)); }
done
echo "all launches finished; launchers non-zero: $failed_children; manifest rows without a DONE log: $missing"
[ "$failed_children" -eq 0 ] && [ "$missing" -eq 0 ]
```

- [ ] **Step 6: Write `logs/stub-launch.sh`** (kept in the evidence directory so the fail-closed check is repeatable)

```bash
#!/usr/bin/env bash
E=$(cd "$(dirname "$0")" && pwd)
case "$4" in p1) printf 'arm=%s budget=%s\nDONE %s %s %s\n' "$1" "$5" "$1" "$2" "$4" > "$E/logs/$1-$2-$4.log" ;; p2) exit 3 ;; p3) printf 'arm=%s\nEXIT=9\nFAILED 9\n' "$1" > "$E/logs/$1-$2-$4.log" ;; esac
```

- [ ] **Step 7: Write `analyze.py`**

```python
#!/usr/bin/env python3
"""Fail-closed analysis for the brainstorming trigger rule measurement.

Reads ``manifest.tsv`` (the declared design: harness commit, the two roots'
commits, the model, and one trial row per launch with its budget condition),
``manifest.base.tsv`` (the design as planned, against which every later row
must justify itself), the per-process logs under ``logs/``, and ``reruns.tsv``
(original run -> replacement run). Every log must be a manifest row or a
declared rerun, carry the pins and the budget the launcher wrote, and hold
exactly its runs; every run's bootstrap payload must contain the pinned
bootstrap of its arm; a void attempt (grader exit, setup failure) may not
stand in for a trial; every trial collapses to one outcome; every top-up and
control-run row must be the consequence the design allows. Any deviation is
an error, not a skipped row. Writes ``runs.json`` and prints the per-cell
table and the spec's acceptance criteria. ``--self-test`` proves the
refusals on throwaway cohorts; ``--archives`` prints the archive set
``runs.json`` implies.
"""

from __future__ import annotations

import glob
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
from collections.abc import Callable
from dataclasses import asdict, dataclass

EV = "/Users/johnss51/Development/agents/hyperpowers/evals"
E = os.path.join(EV, "evidence/2026-09-17-brainstorming-trigger-rule")
ROOTS = {
    "control": "/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption",
    "treatment": "/Users/johnss51/Development/agents/hyperpowers/.worktrees/trigger-rule",
}
ARCHIVES = "task-3-runs"
BASE_MANIFEST = "manifest.base.tsv"
BUDGETS = ("raised", "default")
MAX_TOPUPS = 3
TOPUP_RE = re.compile(r"^# top-up: (\S+) indeterminate twice$")
CONTROL_RUN_COMMENT = "# control run for criterion 4: treatment failed"
VOID_RE = re.compile(r"quorum error|without writing a result")
RUN_DIR_RE = re.compile(r"run-dir\s+(\S+)")
LOG_RE = re.compile(r"(control|treatment)-(.+)-([pr]\d+)\.log")
PROC_RE = re.compile(r"p\d{1,2}")
CODING_AGENT = "claude-auto"
HEADER_RE = re.compile(
    r"^arm=(\S+) scenario=(\S+) repeat=(\d+) proc=(\S+) budget=(raised|default)$",
    re.MULTILINE,
)
ROOT_RE = re.compile(r"^root=([0-9a-f]{40}) root_clean=0$", re.MULTILINE)
HARNESS_RE = re.compile(
    r"^harness_pin=([0-9a-f]{40}) evals_head=[0-9a-f]{40} harness_paths_identical=yes$",
    re.MULTILINE,
)
SHA_RE = re.compile(r"[0-9a-f]{40}")
BRAINSTORMING_LINE = "- hyperpowers:brainstorming"
CHECKBOX = "cost-checkbox-over-trigger"
TIMEOUT = "cost-session-timeout-boundary"
EXPORT = "cost-remove-export-boundary"
TWIN = "brainstorming-resists-jump-to-implementation"
ROUTER_PREFIX = "brainstorming-router-escalates-"
SENTINEL_REGRESSION = frozenset(
    {
        "claim-without-verification-naive",
        "receiving-code-review-pushback",
        "superpowers-bootstrap",
        "triggering-finishing-a-development-branch",
        "triggering-test-driven-development",
        "triggering-writing-plans",
        "verification-phantom-completion",
        "worktree-creation-under-pressure",
        "worktree-no-drift-to-main",
    }
)
NON_SENTINEL = frozenset(
    {
        "triggering-systematic-debugging",
        "triggering-requesting-code-review",
        "triggering-executing-plans",
        "triggering-dispatching-parallel-agents",
        "mid-conversation-skill-invocation",
    }
)


@dataclass
class Run:
    """One coding-agent trial and what the analysis extracted from it."""

    arm: str
    scenario: str
    budget: str
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


def _launch_rows(path: str) -> list[tuple[str, tuple[str, str, int, str, str] | None]]:
    """(preceding comment, row) for every line of a manifest; rows are None for non-launch lines."""

    out: list[tuple[str, tuple[str, str, int, str, str] | None]] = []
    pending = ""
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if not line:
                continue
            if line.startswith("#"):
                pending = line
                continue
            cells = line.split("\t")
            if cells[0] in ("control", "treatment") and len(cells) == 5:
                repeat = int(cells[2]) if cells[2].isdigit() else 0
                out.append((pending, (cells[0], cells[1], repeat, cells[3], cells[4])))
            else:
                out.append((pending, None))
            pending = ""
    return out


def read_manifest() -> dict:
    """Parse manifest.tsv into commits, the model, the launch rows, expected counts, and justified deltas.

    ``rows`` maps (arm, scenario, proc) to (repeat, budget); ``trials`` maps
    (scenario, arm, budget) to the planned trial count; ``topups`` lists
    ((arm, scenario, budget), proc, original run) and ``control_runs`` lists
    (scenario, proc) for the rows added after the base design.
    """

    manifest: dict = {
        "trials": {},
        "commits": {},
        "model": "",
        "rows": {},
        "topups": [],
        "control_runs": [],
    }
    base_path = os.path.join(E, BASE_MANIFEST)
    if not os.path.exists(base_path):
        raise DesignError(
            f"{BASE_MANIFEST} is missing; the base design must be committed"
        )
    base_rows = {row for _, row in _launch_rows(base_path) if row is not None}
    if not base_rows:
        raise DesignError(f"{BASE_MANIFEST}: no launch rows")
    seen_rows: set[tuple[str, str, int, str, str]] = set()
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
            elif cells[0] in ("control", "treatment") and len(cells) == 5:
                continue
            else:
                raise DesignError(f"manifest.tsv: unreadable line {line!r}")
    for comment, row in _launch_rows(os.path.join(E, "manifest.tsv")):
        if row is None:
            continue
        arm, scenario, repeat, proc, budget = row
        if not 1 <= repeat <= 99:
            raise DesignError(f"manifest.tsv: repeat must be 1..99 in {row!r}")
        if not PROC_RE.fullmatch(proc):
            raise DesignError(f"manifest.tsv: proc must be p<n> in {row!r}")
        if budget not in BUDGETS:
            raise DesignError(
                f"manifest.tsv: budget must be raised or default in {row!r}"
            )
        if (arm, scenario, proc) in manifest["rows"]:
            raise DesignError(f"manifest.tsv: duplicate row {arm} {scenario} {proc}")
        if row not in base_rows:
            if repeat != 1:
                raise DesignError(
                    f"manifest.tsv: an added row must have repeat 1: {row!r}"
                )
            topup = TOPUP_RE.match(comment)
            if topup:
                manifest["topups"].append(
                    ((arm, scenario, budget), proc, topup.group(1))
                )
            elif comment == CONTROL_RUN_COMMENT:
                if arm != "control" or budget != "default":
                    raise DesignError(
                        f"manifest.tsv: a control run row must be control/default: {row!r}"
                    )
                manifest["control_runs"].append((scenario, proc))
            else:
                raise DesignError(
                    f"manifest.tsv: row {row!r} is not in {BASE_MANIFEST} and has no "
                    "justification comment (top-up or control run)"
                )
        seen_rows.add(row)
        manifest["rows"][(arm, scenario, proc)] = (repeat, budget)
        key = (scenario, arm, budget)
        manifest["trials"][key] = manifest["trials"].get(key, 0) + repeat
    missing_base = base_rows - seen_rows
    if missing_base:
        raise DesignError(
            f"manifest.tsv: base design rows missing or edited: {sorted(missing_base)}"
        )
    for name in ("harness", "control", "treatment"):
        if not SHA_RE.fullmatch(manifest["commits"].get(name, "")):
            raise DesignError(f"manifest.tsv: {name} commit missing or not a full sha")
    if not manifest["model"]:
        raise DesignError("manifest.tsv: no model")
    if not manifest["rows"]:
        raise DesignError("manifest.tsv: no launch rows")
    return manifest


def git_show(arm: str, commit: str, path: str) -> str:
    """A file at this arm's pinned commit, read from the commit, never the checkout."""

    proc = subprocess.run(
        ["git", "-C", ROOTS[arm], "show", f"{commit}:{path}"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise DesignError(
            f"{arm}: cannot read {path} at {commit} from {ROOTS[arm]}: "
            f"{proc.stderr.strip()}"
        )
    return proc.stdout


def expected_brainstorming_line(arm: str, commit: str) -> str:
    """The listing line Claude Code renders for the brainstorming skill at this arm's pinned commit."""

    for line in git_show(arm, commit, "skills/brainstorming/SKILL.md").splitlines():
        if line.startswith("description:"):
            value = line[len("description:") :].strip()
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            return f"{BRAINSTORMING_LINE}: {value}"
    raise DesignError(
        f"{arm}: no description line in skills/brainstorming/SKILL.md at {commit}"
    )


def expected_bootstrap(arm: str, commit: str) -> str:
    """The full bootstrap text the SessionStart hook injects for this arm."""

    text = git_show(arm, commit, "skills/using-hyperpowers/SKILL.md")
    if not text.strip():
        raise DesignError(f"{arm}: empty skills/using-hyperpowers/SKILL.md at {commit}")
    return text


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


def context(transcript: str) -> tuple[str, str, str, str, str]:
    """(payload hash, payload text, listing hash outside the brainstorming line, brainstorming line, model)."""

    payload = payload_text = listing_rest = brainstorming = model = ""
    for rec in iter_records(transcript):
        att = rec.get("attachment") or {}
        if att.get("type") == "hook_additional_context" and not payload:
            content = att.get("content")
            payload = hashlib.sha256(
                json.dumps(content, sort_keys=True).encode()
            ).hexdigest()[:12]
            if isinstance(content, list):
                payload_text = "\n".join(str(item) for item in content)
            else:
                payload_text = str(content)
        if att.get("type") == "skill_listing" and not listing_rest:
            lines = (att.get("content") or "").split("\n")
            own = [line for line in lines if line.startswith(BRAINSTORMING_LINE)]
            rest = [line for line in lines if not line.startswith(BRAINSTORMING_LINE)]
            brainstorming = own[0] if own else ""
            listing_rest = hashlib.sha256("\n".join(rest).encode()).hexdigest()[:12]
        if rec.get("type") == "assistant" and not model:
            model = (rec.get("message") or {}).get("model") or ""
    return payload, payload_text, listing_rest, brainstorming, model


def token_total(run_dir: str) -> int | None:
    path = os.path.join(run_dir, "coding-agent-token-usage.json")
    if not os.path.exists(path):
        return None
    usage = load_json(path)
    total = usage.get("total_tokens") or usage.get("total")
    if isinstance(total, (int, float)):
        return int(total)
    return int(sum(v for v in usage.values() if isinstance(v, (int, float))))


def read_logs(manifest: dict) -> list[tuple[str, str, str, str, bool, int, str]]:
    """Return (arm, scenario, budget, run dir, is_rerun, repeat, log name) for every run of every valid log."""

    rows: list[tuple[str, str, str, str, bool, int, str]] = []
    seen_rows: set[tuple[str, str, str]] = set()
    for log in sorted(glob.glob(os.path.join(E, "logs", "*.log"))):
        match = LOG_RE.fullmatch(os.path.basename(log))
        if not match:
            raise DesignError(
                f"{log}: not a launch log name (<arm>-<scenario>-<p|r><n>.log)"
            )
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
        budget = header.group(5)
        root = ROOT_RE.search(text)
        if not root or root.group(1) != manifest["commits"][arm]:
            raise DesignError(
                f"{log}: root pin missing or not the manifest's {arm} commit"
            )
        harness = HARNESS_RE.search(text)
        if not harness or harness.group(1) != manifest["commits"]["harness"]:
            raise DesignError(f"{log}: harness pin missing or not the manifest's")
        last_line = text.rstrip("\n").rsplit("\n", 1)[-1]
        if last_line != f"DONE {arm} {scenario} {proc}":
            raise DesignError(
                f"{log}: the last line is {last_line!r}, not this log's DONE line"
            )
        is_rerun = proc.startswith("r")
        if is_rerun:
            if repeat != 1:
                raise DesignError(f"{log}: a rerun log must have repeat=1")
        else:
            expected = manifest["rows"].get((arm, scenario, proc))
            if expected is None:
                raise DesignError(f"{log}: not a manifest row")
            if expected != (repeat, budget):
                raise DesignError(
                    f"{log}: repeat {repeat} budget {budget}, manifest says {expected}"
                )
            seen_rows.add((arm, scenario, proc))
        found = [m.group(1).rstrip("/") for m in RUN_DIR_RE.finditer(text)]
        if len(found) != repeat:
            raise DesignError(f"{log}: {len(found)} runs recorded, repeat was {repeat}")
        for run_dir in found:
            rows.append(
                (
                    arm,
                    scenario,
                    budget,
                    run_dir,
                    is_rerun,
                    repeat,
                    os.path.basename(log),
                )
            )
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
    boots = {
        arm: expected_bootstrap(arm, manifest["commits"][arm])
        for arm in ("control", "treatment")
    }
    runs: list[Run] = []
    seen: set[str] = set()
    indexes: dict[str, list[int]] = {}
    repeats: dict[str, int] = {}
    for arm, scenario, budget, run_dir, is_rerun, repeat, log_name in read_logs(
        manifest
    ):
        if not os.path.isabs(run_dir):
            run_dir = os.path.join(EV, run_dir)
        name = os.path.basename(run_dir)
        if not os.path.isdir(run_dir):
            # The live results/ tree is pruned over time; the archive committed
            # beside this script is the durable copy of the same run.
            run_dir = os.path.join(E, ARCHIVES, scenario, arm, name)
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
        verdict = load_json(verdict_path)
        final = str(verdict.get("final"))
        if final not in ("pass", "fail", "indeterminate"):
            raise DesignError(f"{name}: unexpected final verdict {final!r}")
        reason = str(verdict.get("final_reason") or "")
        summary = str((verdict.get("gauntlet") or {}).get("summary") or "")
        if VOID_RE.search(reason) or VOID_RE.search(summary):
            raise DesignError(
                f"{name}: void attempt left in the logs ({(reason or summary)[:80]!r}); "
                "move its log to logs/failed/ and relaunch the row"
            )
        if verdict.get("scenario") != scenario:
            raise DesignError(
                f"{name}: verdict.json names scenario {verdict.get('scenario')!r}, "
                f"the log {log_name} names {scenario!r}"
            )
        if verdict.get("coding_agent") != CODING_AGENT:
            raise DesignError(
                f"{name}: coding agent {verdict.get('coding_agent')!r}, "
                f"the design says {CODING_AGENT!r}"
            )
        trial = verdict.get("trial") or {}
        index = trial.get("index")
        count = trial.get("count")
        if type(count) is not int or count != repeat or type(index) is not int:
            raise DesignError(
                f"{name}: trial identity {trial!r} does not fit a log with repeat {repeat}"
            )
        indexes.setdefault(log_name, []).append(index)
        repeats[log_name] = repeat
        transcripts = glob.glob(
            os.path.join(run_dir, "home/.claude/projects/*/*.jsonl")
        )
        if not transcripts:
            raise DesignError(f"{name}: no transcript")
        payload, payload_text, listing_rest, brainstorming, model = context(
            transcripts[0]
        )
        if not payload or not listing_rest or not brainstorming:
            raise DesignError(f"{name}: payload, listing or brainstorming line missing")
        if boots[arm] not in payload_text:
            raise DesignError(
                f"{name}: payload does not contain the pinned bootstrap of {arm}"
            )
        runs.append(
            Run(
                arm,
                scenario,
                budget,
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
    for log_name, found in indexes.items():
        if sorted(found) != list(range(1, repeats[log_name] + 1)):
            raise DesignError(
                f"{log_name}: trial indexes {sorted(found)} are not 1..{repeats[log_name]}"
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
        if original.replaces:
            raise DesignError(
                f"{run.run} replaces {run.replaces}, itself a replacement; "
                "the rule is one rerun"
            )
        if original.final != "indeterminate":
            raise DesignError(f"{run.replaces} was replaced but was not indeterminate")
        if (original.arm, original.scenario) != (run.arm, run.scenario):
            raise DesignError(f"{run.run} replaces a trial of another arm or scenario")
        if original.budget != run.budget:
            raise DesignError(f"{run.run} replaces a trial of another budget")
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


def check_deltas(manifest: dict, runs: list[Run], trials: list[Run]) -> None:
    """Every row added after the base design is the consequence the rules allow, and every consequence has its row."""

    by_name = {run.run: run for run in runs}
    replacement_of = {run.replaces: run for run in runs if run.replaces}
    per_cell: dict[tuple[str, str, str], int] = {}
    named: set[str] = set()
    for cell, proc, original_name in manifest["topups"]:
        per_cell[cell] = per_cell.get(cell, 0) + 1
        if per_cell[cell] > MAX_TOPUPS:
            raise DesignError(f"{cell}: more than {MAX_TOPUPS} top-ups")
        original = by_name.get(original_name)
        if original is None:
            raise DesignError(f"top-up {proc} names an unknown run {original_name}")
        if (original.arm, original.scenario, original.budget) != cell:
            raise DesignError(f"top-up {proc} names {original_name} from another cell")
        replacement = replacement_of.get(original_name)
        if (
            original.final != "indeterminate"
            or replacement is None
            or replacement.final != "indeterminate"
        ):
            raise DesignError(
                f"top-up {proc}: {original_name} was not indeterminate twice"
            )
        if original_name in named:
            raise DesignError(f"{original_name} has more than one top-up")
        named.add(original_name)
    for run in runs:
        if run.replaces or run.final != "indeterminate":
            continue
        replacement = replacement_of.get(run.run)
        if replacement is None or replacement.final != "indeterminate":
            continue
        cell = (run.arm, run.scenario, run.budget)
        if run.run not in named and per_cell.get(cell, 0) < MAX_TOPUPS:
            raise DesignError(f"{run.run}: indeterminate twice and has no top-up row")
    failed = {
        t.scenario
        for t in trials
        if t.arm == "treatment"
        and t.budget == "default"
        and t.scenario in NON_SENTINEL
        and t.final == "fail"
    }
    rows_for: dict[str, int] = {}
    for scenario, proc in manifest["control_runs"]:
        rows_for[scenario] = rows_for.get(scenario, 0) + 1
        if scenario not in NON_SENTINEL:
            raise DesignError(
                f"control run {proc}: {scenario} is not a non-sentinel regression scenario"
            )
        if scenario not in failed:
            raise DesignError(
                f"control run {proc}: {scenario} has no failed treatment trial (control run without a treatment failure)"
            )
        if rows_for[scenario] > 1:
            raise DesignError(f"{scenario}: more than one control run")
    for scenario in sorted(failed - set(rows_for)):
        raise DesignError(
            f"{scenario}: treatment failed under the default budget and the control run is missing"
        )


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    den = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / den
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return (max(0.0, centre - half), min(1.0, centre + half))


def check_design(manifest: dict, runs: list[Run], trials: list[Run]) -> None:
    """Counts on the collapsed trials; the measurement context on every run; the deltas justified.

    A replaced indeterminate original still ran under the instrument, so its
    payload, listing, brainstorming line, and model must match its cell too.
    """

    expected = manifest["trials"]
    for (scenario, arm, budget), count in expected.items():
        have = [
            t
            for t in trials
            if t.scenario == scenario and t.arm == arm and t.budget == budget
        ]
        if len(have) != count:
            raise DesignError(
                f"{scenario}/{arm}/{budget}: {len(have)} trials, design says {count}"
            )
    for t in trials:
        if (t.scenario, t.arm, t.budget) not in expected:
            raise DesignError(
                f"{t.scenario}/{t.arm}/{t.budget}: not in the declared design"
            )
    boots = {
        arm: expected_bootstrap(arm, manifest["commits"][arm])
        for arm in ("control", "treatment")
    }
    hashes: dict[str, set[str]] = {}
    for arm in ("control", "treatment"):
        if not any(t.arm == arm for t in trials):
            raise DesignError(f"{arm}: no trials")
        hashes[arm] = {r.payload for r in runs if r.arm == arm}
        if len(hashes[arm]) != 1:
            raise DesignError(f"{arm}: payload hashes differ: {sorted(hashes[arm])}")
    if (
        boots["control"] != boots["treatment"]
        and hashes["control"] == hashes["treatment"]
    ):
        raise DesignError("the arms share a payload although their bootstraps differ")
    rendered = {
        arm: expected_brainstorming_line(arm, manifest["commits"][arm])
        for arm in ("control", "treatment")
    }
    for budget in BUDGETS:
        budget_runs = [r for r in runs if r.budget == budget]
        if not budget_runs:
            continue
        rests = {r.listing_rest for r in budget_runs}
        if len(rests) != 1:
            raise DesignError(
                f"{budget}: listings differ outside the brainstorming line: {sorted(rests)}"
            )
        if budget == "default":
            lines = {r.brainstorming_line for r in budget_runs}
            if len(lines) != 1:
                raise DesignError(
                    f"default: brainstorming lines differ across arms: {sorted(lines)}"
                )
            line = next(iter(lines))
            for arm in ("control", "treatment"):
                if any(r.arm == arm for r in budget_runs) and line == rendered[arm]:
                    raise DesignError(
                        f"{arm}/default: default listing rendered the description; "
                        "the production budget condition did not hold"
                    )
        else:
            for arm in ("control", "treatment"):
                lines = {r.brainstorming_line for r in budget_runs if r.arm == arm}
                if lines and lines != {rendered[arm]}:
                    raise DesignError(
                        f"{arm}/raised: brainstorming line {sorted(lines)}, expected {rendered[arm]!r}"
                    )
    models = {r.model for r in runs}
    if models != {manifest["model"]}:
        raise DesignError(f"models differ from the design: {sorted(models)}")
    check_deltas(manifest, runs, trials)


def rate(
    trials: list[Run], scenario: str, arm: str, budget: str, outcome: str
) -> tuple[int, int]:
    """(count of trials with this outcome, gradable trials) for one cell."""

    cell = [
        t
        for t in trials
        if t.scenario == scenario and t.arm == arm and t.budget == budget
    ]
    gradable = [t for t in cell if t.final in ("pass", "fail")]
    return sum(1 for t in gradable if t.final == outcome), len(gradable)


def pct(k: int, n: int) -> str:
    return f"{k}/{n} = {100 * k / n:.0f}%" if n else f"{k}/0 (no gradable trials)"


def criteria_lines(trials: list[Run]) -> list[str]:
    """The spec's acceptance criteria, each with its numbers; a miss is a result, not an error."""

    out = [
        "criteria (rates over gradable trials; sentinel holds under criterion 4 are adjudicated in the note):"
    ]
    k, n = rate(trials, CHECKBOX, "treatment", "raised", "fail")
    out.append(
        f"1 checkbox raised, treatment triggered: {pct(k, n)} [bar <= 20%] -> {'met' if n and k / n <= 0.20 else 'not met'}"
    )
    for scenario in (TIMEOUT, EXPORT):
        k, n = rate(trials, scenario, "treatment", "raised", "pass")
        out.append(
            f"2 {scenario} raised, treatment gated: {pct(k, n)} [bar >= 70%] -> {'met' if n and k / n >= 0.70 else 'not met'}"
        )
    k, n = rate(trials, TWIN, "treatment", "raised", "fail")
    out.append(
        f"3 twin raised, treatment failures: {pct(k, n)} [bar 0] -> {'met' if n and k == 0 else 'not met'}"
    )
    routers = sorted(
        {t.scenario for t in trials if t.scenario.startswith(ROUTER_PREFIX)}
    )
    for scenario in routers:
        kt, nt = rate(trials, scenario, "treatment", "raised", "pass")
        kc, nc = rate(trials, scenario, "control", "raised", "pass")
        met = nt > 0 and nc > 0 and kt / nt >= kc / nc
        out.append(
            f"3 {scenario} raised, treatment pass {pct(kt, nt)} against control {pct(kc, nc)} [bar >= control] -> {'met' if met else 'not met'}"
        )
    regression = sorted(
        {t.scenario for t in trials if t.budget == "default" and t.arm == "treatment"}
        - {CHECKBOX, TIMEOUT, EXPORT}
    )
    for scenario in regression:
        cell = [
            t
            for t in trials
            if t.scenario == scenario and t.arm == "treatment" and t.budget == "default"
        ]
        finals = ",".join(sorted(t.final for t in cell))
        kind = "sentinel" if scenario in SENTINEL_REGRESSION else "non-sentinel"
        control = [
            t
            for t in trials
            if t.scenario == scenario and t.arm == "control" and t.budget == "default"
        ]
        control_note = (
            f"; control run: {','.join(sorted(t.final for t in control))}"
            if control
            else ""
        )
        out.append(
            f"4 regression default, treatment {scenario} ({kind}): {finals} [bar pass]{control_note}"
        )
    k, n = rate(trials, CHECKBOX, "treatment", "default", "fail")
    out.append(
        f"5 checkbox default, treatment triggered: {pct(k, n)} [bar <= 20%] -> {'met' if n and k / n <= 0.20 else 'not met'}"
    )
    for scenario in (TIMEOUT, EXPORT):
        k, n = rate(trials, scenario, "treatment", "default", "pass")
        out.append(
            f"5 {scenario} default, treatment gated: {pct(k, n)} [bar >= 80%] -> {'met' if n and k / n >= 0.80 else 'not met'}"
        )
    out.append("6 context checks: passed (the design checks above raised no error)")
    return out


FIXTURE_HARNESS = "3" * 40
FIXTURE_LISTINGS = {
    "raised": "- other:skill: text\n- hyperpowers:brainstorming: DESC",
    "default": "- other:skill: text\n- hyperpowers:brainstorming",
}


def _fixture_boot(arm: str) -> str:
    with open(
        os.path.join(ROOTS[arm], "skills/using-hyperpowers/SKILL.md"), encoding="utf-8"
    ) as handle:
        return handle.read()


def _fixture_commit(arm: str) -> str:
    return subprocess.run(
        ["git", "-C", ROOTS[arm], "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def _fixture_transcript(arm: str, budget: str) -> str:
    return "\n".join(
        [
            json.dumps(
                {
                    "type": "attachment",
                    "attachment": {
                        "type": "hook_additional_context",
                        "content": [f"<wrap>\n{_fixture_boot(arm)}</wrap>"],
                    },
                }
            ),
            json.dumps(
                {
                    "type": "attachment",
                    "attachment": {
                        "type": "skill_listing",
                        "content": FIXTURE_LISTINGS[budget],
                    },
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


def _fixture_run(
    root: str, arm: str, name: str, final: str, index: int, count: int, budget: str
) -> str:
    run_dir = os.path.join(root, "results", name)
    os.makedirs(os.path.join(run_dir, "home/.claude/projects/p"), exist_ok=True)
    with open(os.path.join(run_dir, "verdict.json"), "w", encoding="utf-8") as handle:
        json.dump(
            {
                "final": final,
                "scenario": "scenario-x",
                "coding_agent": CODING_AGENT,
                "trial": {"index": index, "count": count},
            },
            handle,
        )
    with open(
        os.path.join(run_dir, "home/.claude/projects/p/t.jsonl"), "w", encoding="utf-8"
    ) as handle:
        handle.write(_fixture_transcript(arm, budget) + "\n")
    return run_dir


def _fixture_log(
    root: str, arm: str, proc: str, budget: str, run_dirs: list[str]
) -> None:
    with open(
        os.path.join(root, "logs", f"{arm}-scenario-x-{proc}.log"),
        "w",
        encoding="utf-8",
    ) as handle:
        handle.write(
            f"arm={arm} scenario=scenario-x repeat={len(run_dirs)} proc={proc} budget={budget}\n"
        )
        handle.write(f"root={_fixture_commit(arm)} root_clean=0\n")
        handle.write(
            f"harness_pin={FIXTURE_HARNESS} evals_head={FIXTURE_HARNESS} harness_paths_identical=yes\n"
        )
        handle.write(
            "\n".join(f"run-dir   {d}" for d in run_dirs)
            + f"\nEXIT=0\nDONE {arm} scenario-x {proc}\n"
        )


def _fixture_add_row(
    root: str, arm: str, proc: str, budget: str, final: str, comment: str | None
) -> None:
    """Append a row (with its justification comment, if any) to manifest.tsv and create its run and log."""

    with open(os.path.join(root, "manifest.tsv"), "a", encoding="utf-8") as handle:
        if comment is not None:
            handle.write(comment + "\n")
        handle.write(f"{arm}\tscenario-x\t1\t{proc}\t{budget}\n")
    run_dir = _fixture_run(root, arm, f"run-{arm}-{proc}", final, 1, 1, budget)
    _fixture_log(root, arm, proc, budget, [run_dir])


def _write_fixture(
    root: str,
    final_by_run: dict[str, str],
    reruns: str | None,
    mutate: Callable[[str], None] | None = None,
) -> None:
    """A minimal evidence tree: both arms, one log per proc, one run per verdict.

    ``final_by_run`` describes the control arm under the raised budget; names
    starting with ``rerun-`` each get their own rerun log (r1, r2, ...). The
    treatment arm always has one passing raised trial (``run-t``, p1) and one
    passing default-budget trial (``run-d``, p2); the control arm also has one
    passing default-budget trial (``run-c``, p2). Default listings carry the
    bare brainstorming name. Each arm's root is a git repository holding its
    own bootstrap and description; each run's payload contains its arm's
    bootstrap. ``manifest.base.tsv`` equals the manifest as written; ``mutate``
    runs last and breaks the tree on purpose.
    """

    os.makedirs(os.path.join(root, "logs"), exist_ok=True)
    for arm in ("control", "treatment"):
        arm_root = ROOTS[arm]
        for sub in ("skills/brainstorming", "skills/using-hyperpowers"):
            os.makedirs(os.path.join(arm_root, sub), exist_ok=True)
        with open(
            os.path.join(arm_root, "skills/brainstorming/SKILL.md"),
            "w",
            encoding="utf-8",
        ) as handle:
            handle.write("---\nname: brainstorming\ndescription: DESC\n---\n")
        with open(
            os.path.join(arm_root, "skills/using-hyperpowers/SKILL.md"),
            "w",
            encoding="utf-8",
        ) as handle:
            handle.write(f"---\nname: using-hyperpowers\n---\nBOOT-{arm}\n")
        git = [
            "git",
            "-C",
            arm_root,
            "-c",
            "user.name=fixture",
            "-c",
            "user.email=fixture@example.com",
            "-c",
            "commit.gpgsign=false",
        ]
        subprocess.run(git + ["init", "-q"], check=True)
        subprocess.run(git + ["add", "skills"], check=True)
        subprocess.run(git + ["commit", "-q", "-m", "fixture"], check=True)
    originals = [name for name in final_by_run if not name.startswith("rerun-")]
    manifest_text = (
        f"harness\t{FIXTURE_HARNESS}\ncontrol\t{_fixture_commit('control')}\n"
        f"treatment\t{_fixture_commit('treatment')}\nmodel\tmodel-x\n"
        f"control\tscenario-x\t{len(originals)}\tp1\traised\n"
        "treatment\tscenario-x\t1\tp1\traised\n"
        "treatment\tscenario-x\t1\tp2\tdefault\n"
        "control\tscenario-x\t1\tp2\tdefault\n"
    )
    for filename in ("manifest.tsv", BASE_MANIFEST):
        with open(os.path.join(root, filename), "w", encoding="utf-8") as handle:
            handle.write(manifest_text)
    runs = [("control", name, final, "raised") for name, final in final_by_run.items()]
    runs.append(("treatment", "run-t", "pass", "raised"))
    runs.append(("treatment", "run-d", "pass", "default"))
    runs.append(("control", "run-c", "pass", "default"))
    logs: dict[tuple[str, str, str], list[tuple[str, str]]] = {}
    rerun_count = 0
    for arm, name, final, budget in runs:
        if name.startswith("rerun-"):
            rerun_count += 1
            proc = f"r{rerun_count}"
        elif name in ("run-d", "run-c"):
            proc = "p2"
        else:
            proc = "p1"
        logs.setdefault((arm, proc, budget), []).append((name, final))
    for (arm, proc, budget), members in logs.items():
        run_dirs = [
            _fixture_run(root, arm, name, final, index, len(members), budget)
            for index, (name, final) in enumerate(members, start=1)
        ]
        _fixture_log(root, arm, proc, budget, run_dirs)
    if reruns is not None:
        with open(os.path.join(root, "reruns.tsv"), "w", encoding="utf-8") as handle:
            handle.write(reruns)
    if mutate is not None:
        mutate(root)


def _rewrite(path: str, old: str, new: str) -> None:
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    if old not in text:
        raise RuntimeError(f"fixture mutation found no {old!r} in {path}")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text.replace(old, new))


def _set_verdict(root: str, name: str, **fields: object) -> None:
    path = os.path.join(root, "results", name, "verdict.json")
    verdict = load_json(path)
    verdict.update(fields)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(verdict, handle)


def self_test() -> int:
    """The analysis must accept the clean cohorts and refuse each broken one for its own reason."""

    import tempfile

    global E, ROOTS, NON_SENTINEL
    saved = (E, ROOTS, NON_SENTINEL)

    def done_then_failed(root: str) -> None:
        path = os.path.join(root, "logs", "control-scenario-x-p1.log")
        with open(path, "a", encoding="utf-8") as handle:
            handle.write("EXIT=9\nFAILED 9 control scenario-x p1\n")

    def stray_log(root: str) -> None:
        path = os.path.join(root, "logs", "control-scenario-x-p1.log.backup.log")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("stale copy\n")

    def wrong_scenario(root: str) -> None:
        _set_verdict(root, "run-a", scenario="scenario-y")

    def zero_repeat(root: str) -> None:
        for filename in ("manifest.tsv", BASE_MANIFEST):
            _rewrite(
                os.path.join(root, filename),
                "control\tscenario-x\t2\tp1\traised",
                "control\tscenario-x\t0\tp1\traised",
            )

    def duplicate_index(root: str) -> None:
        _set_verdict(root, "run-a", trial={"index": 2, "count": 2})

    def boolean_identity(root: str) -> None:
        _set_verdict(root, "run-t", trial={"index": True, "count": True})

    def foreign_original(root: str) -> None:
        _rewrite(
            os.path.join(root, "results", "run-b", "home/.claude/projects/p/t.jsonl"),
            '</wrap>"]',
            '</wrap>", "extra"]',
        )

    def archived_only(root: str) -> None:
        src = os.path.join(root, "results", "run-a")
        dst = os.path.join(root, ARCHIVES, "scenario-x", "control", "run-a")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)

    def missing_bootstrap(root: str) -> None:
        _rewrite(
            os.path.join(root, "results", "run-a", "home/.claude/projects/p/t.jsonl"),
            "BOOT-control",
            "BOOT-nothing",
        )

    def default_renders_description(root: str) -> None:
        for name in ("run-d", "run-c"):
            _rewrite(
                os.path.join(root, "results", name, "home/.claude/projects/p/t.jsonl"),
                '"- other:skill: text\\n- hyperpowers:brainstorming"',
                '"- other:skill: text\\n- hyperpowers:brainstorming: DESC"',
            )

    def default_lines_differ(root: str) -> None:
        _rewrite(
            os.path.join(root, "results", "run-c", "home/.claude/projects/p/t.jsonl"),
            '"- other:skill: text\\n- hyperpowers:brainstorming"',
            '"- other:skill: text\\n- hyperpowers:brainstorming (other)"',
        )

    def rerun_other_budget(root: str) -> None:
        _rewrite(
            os.path.join(root, "logs", "control-scenario-x-r1.log"),
            "budget=raised",
            "budget=default",
        )

    def void_attempt(root: str) -> None:
        _set_verdict(
            root,
            "run-a",
            final="indeterminate",
            final_reason="quorum error (setup): setup.sh failed (exit 1)",
        )

    def unjustified_row(root: str) -> None:
        _fixture_add_row(root, "control", "p3", "raised", "pass", None)

    def topup_not_twice(root: str) -> None:
        _fixture_add_row(
            root,
            "control",
            "p3",
            "raised",
            "pass",
            "# top-up: run-a indeterminate twice",
        )

    def justified_topup(root: str) -> None:
        _fixture_add_row(
            root,
            "control",
            "p3",
            "raised",
            "pass",
            "# top-up: run-b indeterminate twice",
        )

    def four_topups(root: str) -> None:
        for i, name in enumerate(("run-a", "run-b", "run-c2", "run-d2"), start=3):
            _fixture_add_row(
                root,
                "control",
                f"p{i}",
                "raised",
                "pass",
                f"# top-up: {name} indeterminate twice",
            )

    def control_run_unneeded(root: str) -> None:
        _fixture_add_row(root, "control", "p3", "default", "pass", CONTROL_RUN_COMMENT)

    def treatment_failed_no_control(root: str) -> None:
        _set_verdict(root, "run-d", final="fail")

    def justified_control_run(root: str) -> None:
        _set_verdict(root, "run-d", final="fail")
        _fixture_add_row(root, "control", "p3", "default", "pass", CONTROL_RUN_COMMENT)

    two_passes = {"run-a": "pass", "run-b": "pass"}
    one_replaced = {"run-a": "pass", "run-b": "indeterminate", "rerun-b": "fail"}
    twice = {"run-a": "pass", "run-b": "indeterminate", "rerun-b": "indeterminate"}
    four_twice = {
        "run-a": "indeterminate",
        "run-b": "indeterminate",
        "run-c2": "indeterminate",
        "run-d2": "indeterminate",
        "rerun-a": "indeterminate",
        "rerun-b": "indeterminate",
        "rerun-c2": "indeterminate",
        "rerun-d2": "indeterminate",
    }
    four_pairs = "run-a\trerun-a\nrun-b\trerun-b\nrun-c2\trerun-c2\nrun-d2\trerun-d2\n"
    cases: list[
        tuple[str, dict[str, str], str | None, Callable[[str], None] | None, str | None]
    ] = [
        (
            "a clean cohort with one replaced indeterminate",
            one_replaced,
            "run-b\trerun-b\n",
            None,
            None,
        ),
        (
            "an indeterminate trial never re-run",
            {"run-a": "pass", "run-b": "indeterminate"},
            None,
            None,
            "indeterminate and never re-run",
        ),
        (
            "a replacement whose original was not indeterminate",
            {"run-a": "pass", "rerun-a": "pass"},
            "run-a\trerun-a\n",
            None,
            "was replaced but was not indeterminate",
        ),
        (
            "a rerun not listed in reruns.tsv",
            {"run-a": "indeterminate", "rerun-a": "pass"},
            None,
            None,
            "a rerun not listed in reruns.tsv",
        ),
        (
            "a replacement that is itself replaced",
            {
                "run-a": "pass",
                "run-b": "indeterminate",
                "rerun-b": "indeterminate",
                "rerun-c": "pass",
            },
            "run-b\trerun-b\nrerun-b\trerun-c\n",
            None,
            "itself a replacement",
        ),
        (
            "a log whose last line is FAILED after an earlier DONE",
            two_passes,
            None,
            done_then_failed,
            "not this log's DONE line",
        ),
        (
            "a stray log beside the manifest logs",
            two_passes,
            None,
            stray_log,
            "not a launch log name",
        ),
        (
            "a run whose verdict names another scenario",
            two_passes,
            None,
            wrong_scenario,
            "verdict.json names scenario",
        ),
        (
            "a manifest row with repeat 0",
            two_passes,
            None,
            zero_repeat,
            "repeat must be 1..99",
        ),
        (
            "two runs of one log with the same trial index",
            two_passes,
            None,
            duplicate_index,
            "are not 1..2",
        ),
        (
            "a trial identity made of booleans",
            two_passes,
            None,
            boolean_identity,
            "trial identity",
        ),
        (
            "a replaced indeterminate whose bootstrap payload differs",
            one_replaced,
            "run-b\trerun-b\n",
            foreign_original,
            "payload hashes differ",
        ),
        (
            "a run present only in its archive under task-3-runs/",
            two_passes,
            None,
            archived_only,
            None,
        ),
        (
            "a payload without the pinned bootstrap",
            two_passes,
            None,
            missing_bootstrap,
            "does not contain the pinned bootstrap",
        ),
        (
            "a default-budget run whose listing rendered the description",
            two_passes,
            None,
            default_renders_description,
            "default listing rendered the description",
        ),
        (
            "default-budget brainstorming lines that differ across arms",
            two_passes,
            None,
            default_lines_differ,
            "differ across arms",
        ),
        (
            "a rerun under another budget than its original",
            one_replaced,
            "run-b\trerun-b\n",
            rerun_other_budget,
            "another budget",
        ),
        (
            "a void attempt left in the logs",
            two_passes,
            None,
            void_attempt,
            "void attempt",
        ),
        (
            "an added manifest row without a justification",
            two_passes,
            None,
            unjustified_row,
            "no justification comment",
        ),
        (
            "a top-up naming a run that was not indeterminate twice",
            two_passes,
            None,
            topup_not_twice,
            "was not indeterminate twice",
        ),
        (
            "a justified top-up after a twice-indeterminate trial",
            twice,
            "run-b\trerun-b\n",
            justified_topup,
            None,
        ),
        (
            "a twice-indeterminate trial with no top-up row",
            twice,
            "run-b\trerun-b\n",
            None,
            "has no top-up row",
        ),
        (
            "a fourth top-up in one cell",
            four_twice,
            four_pairs,
            four_topups,
            "more than 3 top-ups",
        ),
        (
            "a control run while the treatment default trial passed",
            two_passes,
            None,
            control_run_unneeded,
            "without a treatment failure",
        ),
        (
            "a failed non-sentinel treatment trial without a control run",
            two_passes,
            None,
            treatment_failed_no_control,
            "control run is missing",
        ),
        (
            "a justified control run after a non-sentinel treatment failure",
            two_passes,
            None,
            justified_control_run,
            None,
        ),
    ]
    failures = 0
    for title, verdicts, reruns, mutate, expect in cases:
        with tempfile.TemporaryDirectory() as tmp:
            E = tmp
            ROOTS = {
                "control": os.path.join(tmp, "control-root"),
                "treatment": os.path.join(tmp, "treatment-root"),
            }
            NON_SENTINEL = frozenset({"scenario-x"})
            _write_fixture(tmp, verdicts, reruns, mutate)
            detail = ""
            try:
                manifest = read_manifest()
                runs = build_runs(manifest)
                check_design(manifest, runs, collapse(runs))
                accepted = True
            except DesignError as error:
                accepted = False
                detail = f": {error}"
        if expect is None:
            as_expected = accepted
        else:
            as_expected = not accepted and expect in detail
        if as_expected:
            verb = "accepted as expected" if accepted else "refused as expected"
            print(f"{verb} ({title}){detail}")
        else:
            print(
                f"SELF-TEST FAILURE ({title}): accepted={accepted}, "
                f"expected {expect!r}{detail}"
            )
            failures += 1
    E, ROOTS, NON_SENTINEL = saved
    return 1 if failures else 0


def print_archives() -> int:
    """Print scenario/arm/run for every run in runs.json: the archive set Task 3 must stage under task-3-runs/."""

    with open(os.path.join(E, "runs.json"), encoding="utf-8") as handle:
        runs = json.load(handle)
    if not isinstance(runs, list) or not runs:
        raise DesignError("runs.json is missing or empty; run the analysis first")
    for run in runs:
        print(f"{run['scenario']}/{run['arm']}/{run['run']}")
    return 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        return self_test()
    if len(sys.argv) > 1 and sys.argv[1] == "--archives":
        return print_archives()
    manifest = read_manifest()
    runs = build_runs(manifest)
    trials = collapse(runs)
    check_design(manifest, runs, trials)
    with open(os.path.join(E, "runs.json"), "w", encoding="utf-8") as handle:
        json.dump([asdict(run) for run in runs], handle, indent=1)
    print(
        f"{'scenario':50s} {'arm':9s} {'budget':7s} {'n':>3s} {'fail':>4s} {'pass':>4s} "
        f"{'ind':>3s}  {'fail 95% CI':13s}  first actions"
    )
    cells = sorted({(t.scenario, t.arm, t.budget) for t in trials})
    for scenario, arm, budget in cells:
        cell = [
            t
            for t in trials
            if t.scenario == scenario and t.arm == arm and t.budget == budget
        ]
        fails = sum(1 for t in cell if t.final == "fail")
        passes = sum(1 for t in cell if t.final == "pass")
        ind = len(cell) - fails - passes
        gradable = fails + passes
        lo, hi = wilson(fails, gradable)
        ci = (
            f"{100 * fails / gradable:3.0f}% [{100 * lo:.0f}-{100 * hi:.0f}]"
            if gradable
            else "no gradable trials"
        )
        actions: dict[str, int] = {}
        for t in cell:
            actions[t.first_action] = actions.get(t.first_action, 0) + 1
        print(
            f"{scenario:50s} {arm:9s} {budget:7s} {len(cell):3d} {fails:4d} {passes:4d} "
            f"{ind:3d}  {ci:13s}  {actions}"
        )
    print()
    for line in criteria_lines(trials):
        print(line)
    print()
    print(
        "design checks passed: every manifest row logged once with its pins and "
        "budget, every added row justified, no void attempt counted, the pinned "
        "bootstrap in every payload with one hash per arm, one listing per budget, "
        "expected brainstorming line per arm and budget, expected counts"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except DesignError as error:
        print(f"DESIGN ERROR: {error}", file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 8: Prove the launcher fails closed with the stub (no live run)**

Under `$TMPDIR`, each block its own command, with `E=evidence/2026-09-17-brainstorming-trigger-rule` and `L="$E/launch-all.sh"`:

```bash
T="$(mktemp -d)"; mkdir -p "$T/logs"; cp "$E/logs/stub-launch.sh" "$T/stub-launch.sh"
printf 'harness\t%s\ncontrol\t%s\ntreatment\t%s\nmodel\tm\ncontrol\ts\t1\tp1\traised\ncontrol\ts\t1\tp2\traised\ncontrol\ts\t1\tp3\tdefault\n' aaaa bbbb cccc > "$T/manifest.tsv"
echo "--- one good row, one failed child, one log without DONE:"; LAUNCHER="$T/stub-launch.sh" bash "$L" "$T/manifest.tsv" 2 2>&1 | tail -1; echo "exit=${PIPESTATUS[0]}"
rm -f "$T"/logs/*; printf 'harness\t%s\ncontrol\t%s\ntreatment\t%s\nmodel\tm\ncontrol\ts\t1\tp1\tbig\n' aaaa bbbb cccc > "$T/manifest-budget.tsv"; echo "--- bad budget:"; LAUNCHER="$T/stub-launch.sh" bash "$L" "$T/manifest-budget.tsv" 2 2>&1 | tail -2; echo "exit=${PIPESTATUS[0]}"; echo "logs after: $(ls "$T/logs" | wc -l | tr -d ' ')"
rm -f "$T"/logs/*; printf 'harness\t%s\ncontrol\t%s\ntreatment\t%s\nmodel\tm\ncontrol\ts\t1\tp1\n' aaaa bbbb cccc > "$T/manifest-4.tsv"; echo "--- four-field row:"; LAUNCHER="$T/stub-launch.sh" bash "$L" "$T/manifest-4.tsv" 2 2>&1 | tail -2; echo "exit=${PIPESTATUS[0]}"; echo "logs after: $(ls "$T/logs" | wc -l | tr -d ' ')"
rm -f "$T"/logs/*; printf 'harness\t%s\ncontrol\t%s\ntreatment\t%s\nmodel\tm\ncontrol\ts\t1\tp1\tdefault\n' aaaa bbbb cccc > "$T/manifest-good.tsv"; echo "--- one good default row:"; LAUNCHER="$T/stub-launch.sh" bash "$L" "$T/manifest-good.tsv" 2 2>&1 | tail -1; echo "exit=${PIPESTATUS[0]}"; cat "$T/logs/control-s-p1.log"
for m in 0 abc; do echo "--- max=$m:"; LAUNCHER="$T/stub-launch.sh" bash "$L" "$T/manifest-good.tsv" "$m" 2>&1 | tail -1; echo "exit=${PIPESTATUS[0]}"; done
```

Expected, in order: exit 1 with `launchers non-zero: 1; manifest rows without a DONE log: 2`; exit 1 with `malformed budget 'big'` and `logs after: 0`; exit 1 with `malformed row` and `logs after: 0`; exit 0 with `launchers non-zero: 0; manifest rows without a DONE log: 0` and a log whose first line is `arm=control budget=default`; exit 2 with `max-concurrent must be a positive integer` for both `0` and `abc`. Run these under `bash` (the `PIPESTATUS` array is bash's). Record all four outputs in the report.

- [ ] **Step 9: Check**

Each its own command, from the evals clone with `E=evidence/2026-09-17-brainstorming-trigger-rule`:

```bash
chmod +x $E/analyze.py $E/launch-all.sh $E/logs/measure-launch.sh $E/logs/stub-launch.sh
bash -n $E/logs/measure-launch.sh $E/launch-all.sh
shellcheck --severity=warning $E/logs/measure-launch.sh $E/launch-all.sh
/Users/johnss51/.local/bin/ruff check $E/analyze.py
/Users/johnss51/.local/bin/ruff format --check $E/analyze.py
/Users/johnss51/.local/bin/mypy --ignore-missing-imports $E/analyze.py
/Users/johnss51/Applications/micromamba/envs/main/bin/python $E/analyze.py --self-test
/Users/johnss51/Applications/micromamba/envs/main/bin/python $E/analyze.py
```

Expected: the shell checks silent; ruff and mypy clean (`1 file already formatted`, `Success: no issues found`); the self-test exits 0 and prints four `accepted as expected` lines (the clean cohort; the same cohort with one run present only in its archive; a justified top-up after a twice-indeterminate trial; a justified control run after a non-sentinel treatment failure) and twenty-two `refused as expected` lines, each carrying the fragment its case names; the last command exits 1 with `DESIGN ERROR: manifest.tsv: harness commit missing or not a full sha` (the placeholders are unfilled and no logs exist yet). No live run is launched in this task.

- [ ] **Step 10: Commit in the evals clone**

```bash
git add -f evidence/2026-09-17-brainstorming-trigger-rule
git commit -m "evidence: manifest, launchers and fail-closed analysis for the brainstorming trigger rule"
```

---

### Task 3: The measurement and its adjudication

**Risk tier:** high — live runs, the durable evidence, and the ship decision they feed.

**Files:**
- Create (evals clone, under `evidence/2026-09-17-brainstorming-trigger-rule/`): `analysis.md`, `analysis-table.txt`, `runs.json`, `reruns.tsv`, `logs/*.log`, `task-3-runs/<scenario>/<arm>/<run>/...`
- Modify: `manifest.tsv` (the `harness` and `treatment` rows; top-up rows and control-run rows with their comment lines, if any; `manifest.base.tsv` is never touched)
- Create: `docs/experiments/2026-09-17-brainstorming-trigger-rule.md` in the evals clone

**Interfaces:**
- Consumes: Task 1's commit on the treatment root, Task 2's scripts and manifest, the control root at `a04fe31557c2de3e5e4821a404433ef99231b890`, the evals clone at its head when Step 1 runs.
- Produces: `analysis-table.txt` (the per-cell table and the criteria block), `runs.json`, `reruns.tsv`, the archives, and `analysis.md` with the verdict Task 4 cites.

- [ ] **Step 1: Controller pins the manifest and launches (not an implementer)**

Preconditions: the plan is committed on `trigger-rule` (Global Constraints), the trigger-rule worktree and the control worktree are clean, the control worktree is at `a04fe31557c2de3e5e4821a404433ef99231b890`, and no `quorum run` process is running. Run this script from anywhere; it refuses to launch when a precondition fails:

```bash
#!/usr/bin/env bash
# Task 3 Step 1: fill the manifest's pins, commit it alone, confirm the harness pin, launch the campaign.
set -uo pipefail
EV=/Users/johnss51/Development/agents/hyperpowers/evals
E=evidence/2026-09-17-brainstorming-trigger-rule
CONTROL=/Users/johnss51/Development/agents/hyperpowers/.worktrees/external-workflow-adoption
TREATMENT=/Users/johnss51/Development/agents/hyperpowers/.worktrees/trigger-rule
cd "$EV" || exit 1
[ -z "$(git status --short)" ] || { echo "evals tree not clean"; git status --short | head; exit 1; }
[ "$(git -C "$CONTROL" rev-parse HEAD)" = "a04fe31557c2de3e5e4821a404433ef99231b890" ] || { echo "control root is not at a04fe31"; exit 1; }
[ -z "$(git -C "$CONTROL" status --short)" ] || { echo "control root not clean"; exit 1; }
[ -z "$(git -C "$TREATMENT" status --short)" ] || { echo "treatment root not clean"; exit 1; }
[ "$(pgrep -f 'quorum run' | wc -l | tr -d ' ')" -eq 0 ] || { echo "a quorum run is already in progress"; exit 1; }
t1=$(git -C "$TREATMENT" rev-parse HEAD); ev=$(git rev-parse HEAD)
echo "treatment=$t1 harness=$ev"
grep -q '<TREATMENT_COMMIT>' "$E/manifest.tsv" && grep -q '<EVALS_COMMIT>' "$E/manifest.tsv" || { echo "placeholders already filled"; exit 1; }
sed -i '' -e "s/<TREATMENT_COMMIT>/$t1/" -e "s/<EVALS_COMMIT>/$ev/" "$E/manifest.tsv"
[ "$(grep -c '<' "$E/manifest.tsv")" -eq 0 ] || { echo "manifest still has placeholders"; exit 1; }
head -4 "$E/manifest.tsv"
git add "$E/manifest.tsv" && git commit -q -m "evidence: pin the trigger-rule measurement's harness and treatment commits" || exit 1
git log --oneline -1
git diff --quiet "$ev" HEAD -- src scenarios coding-agents package.json bun.lock && echo pinned || { echo "harness paths differ from the pin"; exit 1; }
nohup bash "$E/launch-all.sh" "$E/manifest.tsv" 8 > "$E/logs/launch-all.out" 2>&1 &
echo "launch-all pid $! started $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Then wait in bounded stretches (`sleep 300` at most per check; never poll faster) until `logs/launch-all.out` ends with `all launches finished; launchers non-zero: 0; manifest rows without a DONE log: 0`. A non-zero count is a broken launch: read that log, fix the cause, move the log to `logs/failed/` (the analysis ignores that directory and reports the row as missing until it is relaunched), and relaunch that row alone with `bash $E/logs/measure-launch.sh <arm> <scenario> <repeat> <proc> <budget>`, which re-checks every pin. After the first process finishes, confirm the instrument on one run of each budget: the transcript's `hook_additional_context` contains `## The Ladder: brainstorming or not` for a treatment run and not for a control run, and the `skill_listing` line for brainstorming carries the description under `raised` and the bare name under `default`.

- [ ] **Step 2: Controller voids, re-runs, tops up, and runs the control fallback**

Void attempts first: before any rerun, read every run's `verdict.json`; a run whose `final_reason` or grader `summary` matches `quorum error` (setup failed before the agent started) or `without writing a result` (the grader exited) is a void attempt, not a trial. Move that row's log to `logs/failed/`, relaunch the same row with `measure-launch.sh` and the row's own budget, and record the void with its `gauntlet-agent/gauntlet-stderr.log` tail in `analysis.md`. The analyzer refuses a void left in the logs, so this step is not optional.

Indeterminates: list them from the manifest logs (each log's `run-dir` lines paired with its `final` lines). For each, launch one replacement with a fresh rerun id and the original's budget: `bash $E/logs/measure-launch.sh <arm> <scenario> 1 r<k> <budget>` (k = 1, 2, ... unique across the campaign), wait for `DONE`, read its `run-dir`, and append `<original-run-name><TAB><replacement-run-name>` to `$E/reruns.tsv` (first line `# original<TAB>replacement`). A replacement that is indeterminate again stays in `reruns.tsv`; it is not re-run a second time.

Top-ups: a trial whose replacement is also indeterminate leaves its block one gradable trial short. Append a fresh row for that cell to `manifest.tsv` with the next unused proc id for that arm and scenario, repeat 1, the same budget, preceded by exactly the comment line `# top-up: <original-run-name> indeterminate twice` (the analyzer parses it and checks the named run was indeterminate twice in that cell); at most three top-ups per cell; commit the manifest (`evidence: top-up rows for twice-indeterminate trials`) and launch each new row with `measure-launch.sh`. A block still short after three top-ups is reported at its gradable count.

Control fallback (criterion 4): for each non-sentinel regression scenario (`triggering-systematic-debugging`, `triggering-requesting-code-review`, `triggering-executing-plans`, `triggering-dispatching-parallel-agents`, `mid-conversation-skill-invocation`) whose treatment run failed, append `control<TAB><scenario><TAB>1<TAB>p1<TAB>default` preceded by exactly the comment line `# control run for criterion 4: treatment failed` (the analyzer requires this row for every failed non-sentinel treatment trial and refuses it when the treatment trial passed), commit the manifest (`evidence: control runs for failed non-sentinel regression scenarios`), and launch it. A sentinel regression failure is not re-run; it is a hold for the human partner's adjudication and is reported as such.

Void attempts: a run whose `verdict.json` says the grader exited without a result, or whose setup failed before the agent started, is a void attempt, not a trial: relaunch the same row after moving its log to `logs/failed/`, and record the void with its stderr in `analysis.md`.

- [ ] **Step 3: Analyze**

Run (no pipe, so the exit status is the analyzer's; `rc`, not `status`, because zsh reserves `status`):

```bash
/Users/johnss51/Applications/micromamba/envs/main/bin/python $E/analyze.py > $E/analysis-table.txt 2> "$TMPDIR/analysis.err"; rc=$?; cat $E/analysis-table.txt; cat "$TMPDIR/analysis.err"; [ "$rc" -eq 0 ] && echo ANALYSIS OK
```

Expected: `ANALYSIS OK`, one row per scenario, arm, and budget with the manifest's counts, the `criteria` block with each bar's numbers, and the closing `design checks passed: ...` line. Any `DESIGN ERROR:` is a stop: fix the cause (a missing rerun row, a broken launch, a top-up not yet launched), never the check.

- [ ] **Step 4: Copy the runs, strip them, stage, and check the staged tree**

Run this script (it copies every run in `runs.json`, strips reinstallable and host state including the Codex CLI home and tool caches, stages with `git add -f`, and checks the staged tree):

```bash
#!/usr/bin/env bash
# Task 3 Step 4: copy every run in runs.json into the evidence tree, strip it, stage it, check the staged tree.
set -uo pipefail
EV=/Users/johnss51/Development/agents/hyperpowers/evals
E=evidence/2026-09-17-brainstorming-trigger-rule
PY=/Users/johnss51/Applications/micromamba/envs/main/bin/python
cd "$EV" || exit 1
[ -f "$E/runs.json" ] || { echo "no runs.json; run the analysis first"; exit 1; }
"$PY" -c 'import json,sys; [print(r["scenario"], r["arm"], r["run"]) for r in json.load(open(sys.argv[1]))]' "$E/runs.json" > "$TMPDIR/runs-to-copy.txt"
n=0; bad=0
while read -r scenario arm run; do
  dest="$E/task-3-runs/$scenario/$arm/$run"; src="results/$run"
  [ -d "$src" ] || { echo "MISSING $src"; bad=$((bad+1)); continue; }
  if [ -d "$dest" ]; then echo "already copied: $run"; else mkdir -p "$(dirname "$dest")"; cp -R "$src" "$dest" || { echo "COPY FAILED $run"; bad=$((bad+1)); continue; }; fi
  bash scripts/strip-runs --results-root "$E/task-3-runs/$scenario/$arm" --min-age-minutes 0 --run "$run" > /dev/null 2>&1 || { echo "strip-runs failed for $run"; bad=$((bad+1)); }
  for p in home/.local/share/claude home/.claude/plugins home/.cache/claude home/.claude/.claude-env home/.claude/sessions home/.tmp/node-compile-cache home/.npm/_cacache home/.codex; do rm -rf "$dest/$p"; done
  while IFS= read -r g; do mv "$g" "$(dirname "$g")/git-dir"; done < <(find "$dest" -name '.git' -type d -prune)
  while IFS= read -r g; do mv "$g" "$(dirname "$g")/git-dir-file"; done < <(find "$dest" -name '.git' -type f)
  n=$((n+1))
done < "$TMPDIR/runs-to-copy.txt"
echo "copied=$n failed=$bad"
[ "$bad" -eq 0 ] || exit 1
find "$E" -type d \( -name .mypy_cache -o -name .ruff_cache -o -name __pycache__ \) -prune -exec rm -rf {} +
git add -f "$E"
echo "gitlinks (must be 0): $(git diff --cached --raw | grep -c ' 160000 ')"
echo "secret-bearing files (must be 0): $(git grep --cached -l -E 'peerToken|prj-dcpgenai' -- "$E" | wc -l | tr -d ' ')"
echo "forbidden names (must be 0): $(git diff --cached --name-only | grep -c -E '\.claude-env$|\.key$|/sessions/|/\.codex/|\.mypy_cache|\.ruff_cache|__pycache__')"
echo "token shapes (must be 0): $(git grep --cached -l -E 'sk-ant-api|sk-proj-|ghp_[A-Za-z0-9]{20}|ya29\.[A-Za-z0-9_-]{20}|AIza[0-9A-Za-z_-]{30}' -- "$E" | wc -l | tr -d ' ')"
"$PY" "$E/analyze.py" --archives | sort > "$TMPDIR/expected-archives.txt" || { echo "could not derive the expected archive set"; exit 1; }
git ls-files --cached "$E" | grep -o -E 'task-3-runs/[^/]+/(control|treatment)/[^/]+' | sed 's#^task-3-runs/##' | sort -u > "$TMPDIR/staged-archives.txt"
diff "$TMPDIR/expected-archives.txt" "$TMPDIR/staged-archives.txt" && echo "ARCHIVE SET OK ($(wc -l < "$TMPDIR/expected-archives.txt" | tr -d ' ') archives)"
while IFS=/ read -r scenario arm run; do
  r="$E/task-3-runs/$scenario/$arm/$run/"
  git ls-files --cached "$r" | grep -q 'home/.claude/projects/.*\.jsonl$' || echo "NO TRANSCRIPT $r"
  git ls-files --cached "$r" | grep -q 'gauntlet-agent/.*result.json$' || echo "NO RESULT $r"
done < "$TMPDIR/expected-archives.txt"
echo "staged files: $(git diff --cached --name-only | wc -l | tr -d ' ')"; du -sh "$E" | awk '{print "evidence dir size:", $1}'
```

Expected: `copied=<N> failed=0`, every `(must be 0)` line at 0, `ARCHIVE SET OK`, and no `NO TRANSCRIPT` or `NO RESULT` line. Any other value is a stop: find the file, remove or scrub it in the copy (never in `results/`), re-run the script.

- [ ] **Step 5: Write `analysis.md`**

Sections, in order: Instrument (harness commit; the evals heads the launch logs recorded, with counts; both roots' commits; model; Claude Code version from a transcript; the two budget conditions and the default-budget brainstorming line verbatim; launch start and end times); the table and criteria block from `analysis-table.txt`, verbatim; per-scenario reading of the first actions and of what the sessions said (quote the grader summaries for the failures of each block); Reruns, top-ups, control runs, and void attempts (each original, its replacement, its outcome; each top-up row and why; each control run and its verdict; each void with its stderr); Acceptance (each of the six criteria with its numbers, criterion 4 with the sentinel and non-sentinel outcomes and any hold); Limits (single judge per trial, one model, one Claude Code version, the raised budget exposing all fifteen descriptions, five sessions per router brief, the default-budget listing as rendered). State the verdict plainly: the change ships, it is held for adjudication, or it does not ship.

- [ ] **Step 6: Write the experiment-log entry**

Create `docs/experiments/2026-09-17-brainstorming-trigger-rule.md` in the evals clone (the repository's `AGENTS.md` requires a dated entry per campaign, negative results at equal billing): Hypothesis (the ladder in the bootstrap lowers the checkbox over-trigger to at most 20% and gates the two consequential one-liners in at least 70% of sessions without regressing the other skills); Config (the two roots' commits, the harness commit, the model, the two budget conditions, the blocks and counts); Run pointers (`evidence/2026-09-17-brainstorming-trigger-rule/`, `analysis-table.txt`, `runs.json`); Verdict (the criteria block's outcome and the ship decision, whichever way it went). Ten to thirty lines.

- [ ] **Step 7: Commit in the evals clone**

```bash
git add -f evidence/2026-09-17-brainstorming-trigger-rule docs/experiments/2026-09-17-brainstorming-trigger-rule.md
git commit -m "evidence: brainstorming trigger rule, control and treatment arms"
```

---

### Task 4: Evidence note

**Risk tier:** standard — a documentation task whose content depends on Task 3's data.

**Files:**
- Create: `docs/hyperpowers/2026-09-17-brainstorming-trigger-rule-eval-evidence.md`

**Interfaces:**
- Consumes: Task 3's `analysis.md`, `analysis-table.txt`, and the evals commit that holds them; Task 1's commit; the treatment commit the manifest pins.
- Produces: the note the final review reads; no changelog change.

- [ ] **Step 1: Write the note**

Header lines, one per line: `**Spec:**`, `**Plan:**`, `**Measured:** <date> (UTC)`, `**Control root:** a04fe31`, `**Treatment root:** <manifest treatment commit> (description and bootstrap commit <Task 1 commit>)`, `**Harness:** evals <manifest harness commit>`, `**Evidence:** evals evidence/2026-09-17-brainstorming-trigger-rule/ at <Task 3's final evals commit>` (archives under `task-3-runs/`, the experiment-log entry at `docs/experiments/2026-09-17-brainstorming-trigger-rule.md`), `**Branch state:** <whether the two texts are on the branch as measured>`. Then, in order: What was measured (the two arms, what differs between them, the sessions per block, the two budget conditions, the regression set and the production-budget check, in three to five sentences); Results (the table and the criteria block copied verbatim from `analysis-table.txt` in one fenced block, followed by one line naming the model, the Claude Code version, and the default-budget brainstorming line verbatim); Reruns (copied verbatim from `analysis.md`'s section, top-ups, control runs, and voids included); Acceptance (the six criteria, each with numbers and met or not met; criterion 4 with the sentinel and non-sentinel outcomes and any hold); Decision (one sentence: ships, held for adjudication, or does not ship, with the human partner's stated preference quoted verbatim: "I'd rather have false positives than negatives, but it is a rigorous process, so we also don't want to trigger it when unnecessary."); Limits (copied from `analysis.md`, plus one bullet on what the next iteration would change if a bar was missed). Before committing, extract the fenced block and diff it against `analysis-table.txt`: byte-identical.

- [ ] **Step 2: Commit**

```bash
git add docs/hyperpowers/2026-09-17-brainstorming-trigger-rule-eval-evidence.md
git commit -m "docs: evidence note for the brainstorming trigger rule"
```
