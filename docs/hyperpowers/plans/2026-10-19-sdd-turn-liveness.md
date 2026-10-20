# SDD Turn Liveness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-19-sdd-turn-liveness-design.md` (approved by the human partner on 2026-10-19). The spec is binding; where this plan and the spec disagree, the spec governs, except for the deviations listed below, which the human partner approved (1-4 before Task 1, 5 and 6 during Task 2, 7 during Task 3).

**Goal:** Make the SDD controller end a turn mid-plan only for a blocker, a question or (where it cannot wait in the foreground) named tracked work; forbid untracked launches; make Claude Code controllers wait in the foreground; and measure the change with a pre-registered paired quorum campaign, a field baseline and two Zed checks before releasing 6.17.0.

**Architecture:** One hyperpowers task edits SDD's skill text and pins it in the SDD contract suite. The evals work comes next: the scenario and its elicited fixture first (the analyzers depend on its contract), then a shared Python transcript module (`liveness.py`) used by both the scenario analyzer (`analyze.py`, with `tally.py` applying the decision rule) and the field instrument (`field.py`), the field baseline, a pinned campaign launcher, a smoke, the pre-registration, the control arm and the treatment arm. Two final tasks prepare the release candidate and run the Zed checks with the human partner, so every branch change passes the final whole-branch review.

**Tech Stack:** Markdown skill text and bash contract suites (hyperpowers); TypeScript on Bun ≥ 1.3 (biome, tsc, bun test) for the setup helper; Python 3 standard library for the analyzers (ruff, mypy, `python3 -m unittest`); bash 3.2-compatible campaign scripts with `.test.sh` siblings.

## Deviations from the spec (approved by the human partner)

1. **Field version attribution by time window.** Spec Design §3 identifies a session's hyperpowers version "by the plugin version in each skill's install path in the transcript". On this host every Skill call loads from `/Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install` (no version in the path), and the versioned cache paths that do appear are unreliable (one session references `6.6.1` 1,852 times). The skill text in effect at any moment is the tag that worktree had checked out, which its reflog records with timestamps. `field.py` therefore attributes events by time window: the baseline window ends before the 6.17.0 install, and the after-window starts at the reflog entry that first checked out the release candidate (the bump commit) and ends at the first later checkout of a commit with different `skills/`.
2. **Turn ends found structurally.** Spec Design §2 defines a premature stop over "main-session turn ends (`stop_reason: end_turn`)". The interactive transcripts quorum records never carry `end_turn`: every main-session assistant record there says `tool_use`, text-only ones included (checked on `sdd-fix-loop-refutes-wrong-finding-claude-auto-20260930T091614Z-e8da`). A turn end is therefore the point where the next main-session user record is a human message or a completion notice delivered as its own message, or the transcript ends. The same rule serves field transcripts, which keeps one definition for both, as spec round-2 finding 13 asked.
3. **Censoring in the scenario too.** Spec Design §3 defines a censored task (no completion ever recorded) for the field. The scenario analyzer applies the same rule through the shared module, so a stop while a never-completing task is open counts as censored, outside both the premature and the live-work counts.
4. **Subagent models as an allowed set.** Spec Design §2 pins one model "for the Coding-Agent and its subagents". SDD chooses each subagent's model tier itself (`skills/subagent-driven-development/model-selection.md`), and that choice is skill text, which differs between the arms. Forcing every subagent onto `claude-opus-5-5` would override part of the behavior under test. The pin therefore fixes the Coding-Agent model exactly and fixes the set of model IDs a subagent may resolve to (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`); a run that records any other model is a provenance void.
5. **The elicitation prompt keeps waiting instructions out of the fixture plan.** Spec Design §2 asks for an elicited six-task plan that names the two slow commands and their runtimes. Task 2's first three elicitations at v6.16.1 (kept as `attempt-1` to `attempt-3` in the evidence directory, with the prompt they used in `prompt-attempts-1-3.txt`) each wrote its own instructions for running and waiting on the soak tests: run both in the background, wait for the completion notice, tell the controller the soak is running. Such a stimulus would carry, or contradict, the behavior under test, so the long-job measure would credit the plan's text rather than the skill. The prompt therefore adds one sentence asking the plan to name each covering command and its runtime and to leave how commands are run and waited for to whoever executes it, and the fixture-plan test rejects a plan that mentions background or foreground runs. The plan is still written by writing-plans at the control version and never edited. Approved by the human partner on 2026-10-20, together with a looser contract test: v6.16.1 writing-plans puts a slow command after a lead-in sentence or in a code block, never on a `Run:` line, so the test requires the exact command and its runtime inside the task's section rather than on a `Run:` line.
6. **Measured soak runs must take real time, and soak files must stay untouched in the session.** Spec Design §2 defines the two F measures by call shape (foreground with a long enough timeout; a tracked launch watched to its end). Task 2's Codex gate found that a controller could shorten `SOAK_SECONDS`, run the soak quickly, and restore the file before the post-checks, which compare only the final tree; the scenario's post-check now also rejects a commit history that touched a soak file, but an uncommitted edit-run-restore would still pass F. The analyzer therefore also requires the short soak's main-session result to arrive at least 200 s after its call and the long job's `exit=0` watch result at least 600 s after its launch, and marks a run `soak_tampered` (which fails run success) when a successful main-session call writes to either soak file. Approved by the human partner on 2026-10-20, before pre-registration.
7. **A command Claude Code moves to the background on its own is a tracked launch.** Spec Design §2 defines "live" by the two launch results "Async agent launched" and "Command running in background with ID". Claude Code also moves a foreground Bash call that outlives its timeout to the background by itself; the result then starts "Command did not complete within its <N>s timeout and was moved to the background", and the job's end arrives as a completion notice naming the same tool-use id, like any tracked job (about 800 such results on this host). The shared module counts that result as a shell launch, so a stop while such a job runs is a live-work turn end (W2), not a premature stop (P). F is unaffected: a four-minute soak run with the two-minute default timeout still fails it on its timeout and its elapsed time. Approved by the human partner on 2026-10-20, during Task 3's review; applied as Task 4's first step because Task 3 had closed.

## Global Constraints

- Repositories and branches: hyperpowers branch `sdd-turn-liveness` in `.worktrees/sdd-turn-liveness`, from `main` at the docs commit that adds the spec and this plan (its parent is `f1fd935`, tag `v6.16.1`); hyperpowers-evals branch `sdd-turn-liveness` in `evals/.worktrees/sdd-turn-liveness`, from evals `main` at `882844154`. No commit lands on either `main` during the plan; the human partner reviews both branches at Finish and decides whether they merge. Nothing is pushed.
- Evidence directory for every artifact an evidence note cites: `evals/evidence/2026-10-19-sdd-turn-liveness/` (committed in hyperpowers-evals). Nothing is cited from the SDD workspace. Archived runs follow `evals/evidence/README.md` "Before committing a run": `task-9-runs/smoke/`, `task-11-runs/control/`, `task-12-runs/treatment/`, each beside its `workspaces/` copy.
- Exact names, used identically in every task: `liveness.py`, `analyze.py`, `tally.py`, `field.py`, `synth.py` (test builders), `measure(record, adjudicated)`, `empty_measure(run_id)`, `evaluate(manifest, logs, adjudications, results_root, archive, repo=EVALS)`, `collect(projects, since, until)`, scenario `sdd-turn-liveness`, setup helper `scaffold_sdd_turn_liveness` → `scaffoldSddTurnLiveness`, fixture dir `evals/fixtures/sdd-turn-liveness/`, slow tests `tests/test_soak_short.py` (240 s, covering command `python3 -m unittest tests.test_soak_short -v`) and `tests/test_soak_long.py` (720 s, covering command `python3 -m unittest tests.test_soak_long -v`), unit tests `tests/test_unit_*.py`, ledger completion lines `Task <N>: complete` for N = 1..6.
- Harness path set, identical in `measure-launch.sh` and `tally.py` (the evals_clean set): `src coding-agents package.json bun.lock bunfig.toml tsconfig.json container scripts/evals-container scenarios fixtures`. The clean-harness settings (the `claudeMdExcludes` list, the `AGENTS.md` exclusion, the launch-environment cleaning) are harness code inside that set, so harness-path identity with the pin is what pins them.
- Arms: control root `/Users/johnss51/.cache/hyperpowers/sdd-turn-liveness/hp-control` (detached worktree at `v6.16.1`); treatment root `/Users/johnss51/.cache/hyperpowers/sdd-turn-liveness/hp-treatment` (detached worktree at the hyperpowers commit Task 1 makes). Both are created with `git -C /Users/johnss51/Development/agents/hyperpowers worktree add --detach <path> <commit>` and never edited.
- Campaign pin (spec Design §2), one value per key in `manifest.tsv`: `harness` (evals commit), `control`, `treatment` (root commits), `control_root`, `treatment_root`, `model claude-opus-5-5` (the Coding-Agent, through `ANTHROPIC_MODEL`), `cc` (Claude Code version), `cc_path` (the resolved `claude` binary), `provider vertex`, `subagent_models claude-opus-5-5,claude-sonnet-5-5,claude-haiku-5-5`, `codex absent`, `task_tools on` (`CLAUDE_CODE_ENABLE_TODO_TOOLS=1`, matching the field sessions). Every launch also exports `DISABLE_AUTOUPDATER=1`. A run's recorded models must be non-empty, include the pinned Coding-Agent model and lie inside the allowed set (deviation 4). Codex absence is affirmative: the scenario's two pre-checks passed (the agent's config directory exists, and its plugin registry is either absent, which means no plugin is installed, or readable without a `codex@openai-codex` entry; no `plugins/cache/openai-codex` directory exists), and no main-session command invoked the companion.
- Void rules: harness setup failure, relaunched, no cap; every other non-pass, non-fail outcome (grader exit without a result, API or harness failure, anything unrecognized), replaced, at most three such replacements per arm combined; a run with a provenance mismatch, voided, replaced, and counted toward the same cap (the agent ran, so discarding it is the kind of re-roll the cap limits); a Claude Code version change (in a run, or caught by a launcher's preflight) restarts both arms under a new pin. Replacement rows are added to `manifest.tsv` as `r<n>` rows and launched through `launch-all.sh` like any other row.
- Decision-rule thresholds, verbatim from the spec: W1 pooled foreground share ≥ 0.9; W2 at most one live-work turn end across treatment's ten runs; F both slow-command measures pass in at least nine of ten treatment runs; U no untracked launches; P (if control has at least one premature stop) treatment's total lower than control's and at least nine treatment runs with none, else unmeasured; R at least seven successful treatment runs and no more than one fewer than control.
- Watch budget values, verbatim: three times the stated runtime, or 60 minutes when none is stated, capped at 7200000 ms; foreground calls at most 600000 ms; launch form `<command> > <out> 2>&1; echo "exit=$?" > <out>.exit` (amended 2026-10-20 after Task 1's Codex gate: a marker in the output file could be spoofed by the command's own output; the human partner chose the separate file).
- Commit messages follow each repository's `type(scope): sentence` style (`fix(sdd): …`, `test(evidence): …`, `docs(evidence): …`); no attribution lines of any kind. Before every commit the staged diff passes `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` with `hits: 0`. No committed file carries transcript text from this host's sessions, the proxy host, the `NO_PROXY` list or the GCP project id.
- Evals: `bun run check` runs before every evals commit; in the nested worktree seven pre-existing failures are known (the `evals/..` path assumption and the host having `claude` on `PATH`), recorded at Before Task 1 and compared, never newly introduced. Python files pass `ruff check` and `mypy` (both on `PATH`).
- Hyperpowers: the documented offline set (`docs/testing.md:50-55`) passes at Task 1's commit, one suite per `bash` call, through the script in Task 1 Step 7.
- Live runs (Task 2's elicitation, Tasks 9, 11 and 12) run outside the Bash sandbox: quorum's `git init` fails inside it with "Operation not permitted". Each live command is tried once inside the sandbox; on that signature it is rerun with the sandbox disabled.
- The campaign launcher is evals operator tooling, not an SDD controller: it runs detached (`nohup … &` with output to a log), because a tracked background job lives at most 2 hours and a scenario run may take 150 minutes. The operator watches its closing log line with `wait-done.sh` in foreground calls of at most 600000 ms each. A detached process outlives the tool call that started it (checked on this host 2026-10-19). This holds for replacement rows too.
- Multi-command evidence steps are committed bash scripts run as `bash <script>`: the interactive shell is zsh, where a lowercase `path=` replaces `PATH` and `PIPESTATUS` does not exist. No `grep -q` reads from a pipe (the host's 512-byte pipe trap); write to a file first.

## Grounding

- SDD text being edited: `skills/subagent-driven-development/SKILL.md:19` (Continuous execution), `:230-239` (Waiting on dispatched subagents); rationalization table `skills/subagent-driven-development/common-rationalizations.md:1-17`.
- Contract-suite shape: `tests/sdd/test-sdd-contract.sh:19-34` (`assert_contains`, whitespace-collapsed haystack), `:119` (a single-line needle), `:389-390` (the closing STATUS lines new assertions go above). The offline set: `docs/testing.md:50-55`, its suite table `:23-33`.
- Scaffold helper: `evals/src/setup-helpers/sdd-fixtures.ts:15-31` (`FIXTURES_DIR`, `scaffoldFromFixture`: `git init -b main`, Drill Test identity, one commit); recursive copy pattern `evals/src/setup-helpers/plugin-stage.ts:32-54`; registry entry style `evals/src/setup-helpers/registry.ts:113` and the count comments `:1-5,130-132`; `record_head` `evals/src/setup-helpers/base.ts:54-58`, registry `:125`.
- Helper test shape: `evals/test/setup-helpers-sdd.test.ts:16-33` (`mkdtempSync` workdir, `runGit` assertions, `rmSync` in `finally`).
- Scenario shape: `evals/scenarios/sdd-fix-loop-refutes-wrong-finding/story.md:1-8` (frontmatter) and its fenced replies; `evals/scenarios/sdd-fix-loop-refutes-wrong-finding/checks.sh:1-30` (header comment, `# coding-agents:` line, `pre()` reading `$QUORUM_AGENT_CONFIG_DIR/plugins/installed_plugins.json`); `evals/scenarios/sdd-svelte-todo/setup.sh:1-3`.
- Story rules: `evals/docs/scenario-authoring.md:129-202` (frontmatter keys incl. `quorum_max_time`, the body briefs the Gauntlet-Agent, fence every turn, run-completeness); elicited fixtures `:204-212`.
- Verdict and record layout: a run's `verdict.json` carries `final`, `final_reason`, `gauntlet`, `checks` (each `{check, args, negated, passed, detail, phase}`), `provenance` (`evals_commit`, `evals_clean`) and `economics.coding_agent.models`; the launch record `gauntlet-agent/context/launch-agent` carries `--plugin-dir "<root>"` and `--model "<model>"`; the main transcript is `results/workspaces/<run>/home/.claude/projects/*/*.jsonl` (subagent transcripts sit one level deeper) — observed on `cost-api-field-rename-boundary-claude-auto-20261019T073020Z-ce31`. The SDD ledger lives under the run's `home/.cache/hyperpowers/sdd/` and survives `strip-runs` (`evals/CLAUDE.md`, "Run Directory Upkeep"), but SDD's Finish deletes the plan workspace, ledger included (`skills/subagent-driven-development/SKILL.md:627-640`), so a finished run's completion record is its successful ledger writes in the transcript. Real controllers wrote ledger lines with the Edit tool on `progress.md`, a Bash heredoc appended to it (`cat >> <workspace>/progress.md <<EOF`), and Write (surveyed on the `sdd-unified-fix-loop` runs of 2026-08-19 to 2026-08-26).
- Python analyzer conventions: rST docstrings, module constants, `main() -> int`, `sys.exit(main())` — `evals/evidence/2026-10-03-release-6150-paired-control/tally.py:1-40,157-200`; `void_kind` `:63-79`; readouts from the launch record and transcript `:92-136`; `unittest` test module with `sys.path` insert — `evals/evidence/2026-10-14-agent-write-isolation-relocation/test_tally.py:1-30`.
- Campaign launcher: `evals/evidence/2026-09-23-adoption-remediation/launch-all.sh:1-82` (manifest validation, capacity loop, per-child status files, closing line) and `evals/evidence/2026-09-23-adoption-remediation/logs/measure-launch.sh:1-66` (pin checks, harness-path identity, log header, `DONE`/`FAILED`).
- Archive script: `evals/evidence/2026-10-03-release-6150-paired-control/archive-runs.sh:1-40`, adapted to the relocated layout per `evals/evidence/README.md:24-45`.
- Headless session recipe: `evals/evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:1-35` (empty `CLAUDE_CONFIG_DIR`, `--plugin-dir`, stripped session env vars, `--output-format stream-json`).
- Evidence note shape: `docs/hyperpowers/2026-10-03-review-calibration-and-sentinel-scope-eval-evidence.md:1-20`; experiment-log entry shape: `evals/docs/experiments/2026-10-05-p3-control.md` (Hypothesis, Config, Run pointers, Verdict, Limits).
- Release notes: `CHANGELOG.md:5-31` (problem line, bold-led bullets, evidence pointer).
- `none: no existing structural turn-end detector`; `liveness.py` introduces it.

---

## Before Task 1

- [ ] With the human partner's approval of the spec and plan diff, commit both on hyperpowers `main` as one docs commit (`docs(hyperpowers): the SDD turn liveness design and its implementation plan`), leak scan first.
- [ ] Create the hyperpowers worktree with `hyperpowers:using-git-worktrees`: branch `sdd-turn-liveness` from that commit, under `.worktrees/`. Run `bash tests/sdd/test-sdd-contract.sh` there and record `STATUS: PASSED` in the ledger.
- [ ] Create the evals worktree: branch `sdd-turn-liveness` from evals `main` at `882844154`, under `evals/.worktrees/` (about 8 minutes on this repository). Run `bun run check` there and record the failing test names (the seven known ones) in the ledger as the baseline.
- [ ] Create the control root: `git -C /Users/johnss51/Development/agents/hyperpowers worktree add --detach /Users/johnss51/.cache/hyperpowers/sdd-turn-liveness/hp-control v6.16.1`. Record `git -C <root> rev-parse HEAD` (`f1fd935…`) in the ledger.

---

### Task 1: SDD skill text: the turn-ending rule, tracked work only, foreground waits

**Risk tier:** standard — behavior-shaping skill surgery.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:19` (Continuous execution, plus the new Tracked work paragraph after it), `:230-239` (Waiting paragraph)
- Modify: `skills/subagent-driven-development/common-rationalizations.md` (two rows at the end of the table)
- Test: `tests/sdd/test-sdd-contract.sh` (nine needles above the closing STATUS lines)

**Interfaces:**
- Produces: the hyperpowers commit the treatment root is pinned to (Task 9). Later tasks never touch `skills/`.

**Mirror:** `tests/sdd/test-sdd-contract.sh:119-140` for needle style.

- [ ] **Step 1: Add the failing needles**

Insert immediately above the blank line before `echo` at the end of `tests/sdd/test-sdd-contract.sh`:

```bash
# Turn liveness (spec 2026-10-19): a status message never ends a turn mid-plan,
# long work is tracked, and Claude Code waits in the foreground.
assert_contains "$SDD" "While the plan has tasks left, a turn ends in exactly three cases" \
  "continuous execution names the three permitted turn ends"
assert_contains "$SDD" "A message that names your next step is followed by that step's tool call in the same turn." \
  "an announced step is taken in the same turn"
assert_contains "$SDD" 'never start it with a trailing `&`, `nohup`, `setsid`, `disown`, or a script that detaches a process' \
  "untracked launches are forbidden"
assert_contains "$SDD" 'subagents with `run_in_background: false`' \
  "Claude Code dispatches SDD subagents in the foreground"
assert_contains "$SDD" 'echo "exit=$?" > <out>.exit' \
  "a long command writes its exit status to its own file whether it succeeds or fails"
assert_contains "$SDD" "capped at the harness's maximum background lifetime (7200000 ms on Claude Code)" \
  "the watch budget is capped at the background lifetime"
assert_contains "$SDD" "stop the job through the harness, record the output tail in the ledger, and report BLOCKED" \
  "an exhausted watch ends in BLOCKED"
assert_contains "$SDD_RATIONALIZATIONS" "I've said what's next; I'll pick it up on the next turn" \
  "rationalization row for the announced-step stop"
assert_contains "$SDD_RATIONALIZATIONS" 'A trailing `&` keeps it out of my way' \
  "rationalization row for the detached launch"
```

- [ ] **Step 2: Run the suite to see the nine failures**

Run: `bash tests/sdd/test-sdd-contract.sh`
Expected: `STATUS: FAILED (9)`, each new description listed with `[FAIL]`.

- [ ] **Step 3: Replace the Continuous execution paragraph and add Tracked work**

Replace line 19 of `skills/subagent-driven-development/SKILL.md` (the whole `**Continuous execution:**` paragraph) with these two paragraphs, separated by a blank line:

```markdown
**Continuous execution:** Do not pause to check in with your human partner between tasks. Execute all tasks from the plan without stopping. While the plan has tasks left, a turn ends in exactly three cases: a BLOCKED status you cannot resolve; a question only your human partner can answer, asked in that message (ambiguity that genuinely prevents progress is such a question); or, on a harness that cannot wait in the foreground, tracked work still running, named in that message. A message that names your next step is followed by that step's tool call in the same turn. "Tasks 1 and 2 are done. Moving to Task 3." followed by a turn end is a stop: your human partner reads it as work in progress, and nothing resumes it until they type. All tasks complete ends the plan. "Should I continue?" prompts and progress summaries waste their time — they asked you to execute the plan, so execute it.

**Tracked work only:** anything that outlives one tool call starts through your harness's tracked background option (`run_in_background` on Claude Code); never start it with a trailing `&`, `nohup`, `setsid`, `disown`, or a script that detaches a process. The harness never reports on such a process, so nothing wakes you when it ends, and a turn you end to wait for it does not resume.
```

- [ ] **Step 4: Replace the Waiting paragraph**

Replace the paragraph that starts `**Waiting on dispatched subagents:**` (lines 230-239 before Step 3; re-locate it by that opening) with:

```markdown
**Waiting on subagents and long commands.** On Claude Code, wait in the foreground:

- Dispatch implementer, task-reviewer, fix-round, re-review and final-reviewer subagents with `run_in_background: false`. Your next step always depends on the result, and a foreground call keeps your turn open, which is what an editor such as Zed shows as the session working. A background dispatch ends the turn while the subagent runs, and the editor shows the session idle.
- Run a covering command expected to finish within 10 minutes in the foreground, with an explicit timeout of at least its expected runtime and at most 600000 ms.
- Start a command that may run past 10 minutes as a tracked background job, `<command> > <out> 2>&1; echo "exit=$?" > <out>.exit`, with its background timeout set explicitly to the watch budget below. The exit status goes to its own file so nothing the command prints can be mistaken for it. Then watch it in the foreground: calls of at most 600000 ms each, each a bounded loop that waits for `<out>.exit` and aborts on a non-zero status. Codex reviews already follow this shape through the recipe's `status <job-id> --wait --json` loop.
- **Watch budget.** The total watch on one job is three times the plan's stated runtime for it, or 60 minutes when the plan states none, capped at the harness's maximum background lifetime (7200000 ms on Claude Code). The watch ends when `<out>.exit` appears, or when the harness reports the job ended without one: a killed process writes no exit file, so read its output and treat the job as failed. When the budget is spent with the job still running, stop the job through the harness, record the output tail in the ledger, and report BLOCKED.

On a harness whose subagents run asynchronously, never poll a wait interface with short timeouts, and never sit in one silent, open-ended wait either. While you have local work — ledger updates, packaging the next review, reading reports — keep working; child results arrive on their own. When you are genuinely idle, wait in bounded stretches (five to ten minutes, where your platform allows), and between stretches post one line of status and reconcile your live children: list them, and chase any that finished without reporting. A bounded stretch keeps nearly all of a long wait's efficiency while guaranteeing a stuck or lost child is noticed within minutes, not at the end of the session. Codex's `wait_agent` blocks inside the turn; `using-hyperpowers/references/codex-tools.md` maps it.
```

- [ ] **Step 5: Add the two rationalization rows**

Append to the table in `skills/subagent-driven-development/common-rationalizations.md`, after its last row:

```markdown
| "I've said what's next; I'll pick it up on the next turn" | There is no next turn until your human partner types. A status message that ends the turn stops the plan, and the editor shows the session idle while the message says it is working. Take the step's tool call now. |
| "A trailing `&` keeps it out of my way" | A detached process is invisible to the harness: no completion notice arrives, and a turn ended to wait for it never resumes. Start it with the tracked background option and watch it in the foreground. |
```

- [ ] **Step 6: Run the SDD contract suite**

Run: `bash tests/sdd/test-sdd-contract.sh` — Expected: `STATUS: PASSED`.

- [ ] **Step 7: Run the documented offline set**

Write this script beside your report file as `run-offline-set.sh` (it is scratch, not committed) and run `bash <path>/run-offline-set.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/sdd-turn-liveness`:

```bash
#!/usr/bin/env bash
# The docs/testing.md offline set (docs/testing.md:50-55), one suite per bash
# invocation. Live suites (tests/claude-code/ except the four offline ones,
# tests/explicit-skill-requests/, the two OpenCode integration suites) are
# excluded because they spawn a real claude session.
set -uo pipefail
cd "$1" || exit 2
fails=0; ran=0
run() { ran=$((ran + 1)); "$@" > /dev/null 2>&1 || { echo "FAILED: $*"; fails=$((fails + 1)); }; }
while IFS= read -r t; do
  case "$t" in
    tests/claude-code/*|tests/explicit-skill-requests/*|tests/opencode/test-tools.sh|tests/opencode/test-priority.sh) continue ;;
  esac
  run bash "$t"
done < <(find tests -name 'test-*.sh' -type f | sort)
for t in test-sdd-dir-path.sh test-codex-review-dir-path.sh test-delivery-resolution.sh test-worktree-path-policy.sh; do
  run bash "tests/claude-code/$t"
done
run bash tests/brainstorm-server/windows-lifecycle.test.sh
run node tests/pi/test-pi-extension.mjs
ran=$((ran + 1))
(cd tests/brainstorm-server && npm test > /dev/null 2>&1) || { echo "FAILED: npm test (tests/brainstorm-server)"; fails=$((fails + 1)); }
echo "ran=$ran fails=$fails"
[ "$fails" -eq 0 ]
```

Expected: `ran=<n> fails=0`. A failure is compared against the same script run on hyperpowers `main` at the docs commit; a suite that fails there too is pre-existing and recorded in the report, never fixed in this task.

- [ ] **Step 8: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/common-rationalizations.md tests/sdd/test-sdd-contract.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "fix(sdd): a status message never ends a turn mid-plan, long work is tracked, and Claude Code waits in the foreground"
```

---

### Task 2: The scenario, its fixture and the elicited plan

**Risk tier:** high — the setup helper's output is the fixture quorum and every analyzer measure trust, and the elicited plan is the experiment's stimulus.

**Files:**
- Create: `evals/fixtures/sdd-turn-liveness/design.md`, `tests/__init__.py` (empty), `tests/test_soak_short.py`, `tests/test_soak_long.py`, `plan.md` (elicited)
- Modify: `evals/src/setup-helpers/sdd-fixtures.ts` (add `copyTree`, `scaffoldSddTurnLiveness`)
- Modify: `evals/src/setup-helpers/registry.ts` (import, entry after `scaffold_sdd_yagni_plan`, count comments 37→38 and 39→40)
- Test: `evals/test/setup-helpers-sdd.test.ts` (scaffold test, fixture-plan test)
- Create: `evals/scenarios/sdd-turn-liveness/story.md`, `setup.sh`, `checks.sh`
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/elicitation/elicit-plan.sh`, `prompt.txt`, `attempt-<N>/` (each session's `status.txt`, `turn.sha256` and `plan.md`; the raw session output stays outside the repository)

**Interfaces:**
- Consumes: the control root (Before Task 1) for elicitation.
- Produces (the fixture contract Tasks 4, 5 and 9 rely on): six plan tasks headed `### Task 1` … `### Task 6`; two task sections that carry the exact covering commands `python3 -m unittest tests.test_soak_short -v` (with "four minutes") and `python3 -m unittest tests.test_soak_long -v` (with "twelve minutes"), and no instructions about background or foreground runs (deviation 5); helper `scaffold_sdd_turn_liveness`; scenario `sdd-turn-liveness` whose `checks.sh` records a pre-checks containing `codex@openai-codex` and `plugins/cache/openai-codex` and post-checks containing `test_unit_`, `tests.test_soak_short`, `tests.test_soak_long` and `quorum-recorded-head`.

**Mirror:** `evals/src/setup-helpers/sdd-fixtures.ts:15-31`, `evals/src/setup-helpers/plugin-stage.ts:32-54`, `evals/test/setup-helpers-sdd.test.ts:20-33`, `evals/scenarios/sdd-fix-loop-refutes-wrong-finding/{story.md,checks.sh}`.

- [ ] **Step 1: Write the fixture's design note and soak tests**

`evals/fixtures/sdd-turn-liveness/design.md` is the markdown block; the two Python blocks are the soak tests their first comment names. Also create an empty `evals/fixtures/sdd-turn-liveness/tests/__init__.py` so `python3 -m unittest tests.test_soak_short` imports the package.

```markdown
# ratelimit: an in-process rate limiter

A small, dependency-free Python package (standard library only, Python 3.9
or later) that decides whether a caller may proceed under a configured rate.

## Components

1. `ratelimit/clock.py`: a `MonotonicClock` with `now() -> float` (wraps
   `time.monotonic`) and a `FakeClock` for tests with `now()` and
   `advance(seconds: float)`.
2. `ratelimit/bucket.py`: `TokenBucket(rate_per_second: float, capacity: int,
   clock=None)` with `allow() -> bool` (spends one token when one is
   available) and `tokens() -> float`.
3. `ratelimit/window.py`: `SlidingWindowLimiter(limit: int, window_seconds:
   float, clock=None)` with `allow() -> bool`: at most `limit` calls are
   allowed in any trailing window of `window_seconds`.
4. `ratelimit/registry.py`: `Registry(factory)` keeps one limiter per key;
   `factory` is called with no arguments. `get(key)` creates a limiter on
   first use, `allow(key) -> bool` delegates to it, `keys() -> list[str]`
   lists the keys seen.
5. `ratelimit/__main__.py`: `python3 -m ratelimit simulate --limit N
   --window S --calls C` prints `allowed=<a> denied=<d>`, driving a
   `SlidingWindowLimiter` with a `FakeClock` that advances 0.1 s per call.
6. Integration: the registry with sliding-window limiters under the real
   clock, across many keys.

`clock=None` means `MonotonicClock()`.

## Tests

Unit tests live in `tests/test_unit_<component>.py`, use `FakeClock`, and
run with `python3 -m unittest discover -s tests -p "test_unit_*.py"`.

Two soak tests are already in the repository and must not be modified:

- `tests/test_soak_short.py` exercises `SlidingWindowLimiter` under the real
  clock and takes about four minutes:
  `python3 -m unittest tests.test_soak_short -v`. It is the covering
  command for the sliding-window work.
- `tests/test_soak_long.py` exercises `Registry` with
  `SlidingWindowLimiter` across eight keys under the real clock and takes
  about twelve minutes: `python3 -m unittest tests.test_soak_long -v`. It is
  the covering command for the integration work.
```

```python
# evals/fixtures/sdd-turn-liveness/tests/test_soak_short.py
"""Soak: the sliding window holds its limit under the real clock (about four minutes)."""

import time
import unittest

from ratelimit.window import SlidingWindowLimiter

SOAK_SECONDS = 240
LIMIT = 5
WINDOW = 2.0
SLACK = 0.01


class SlidingWindowSoak(unittest.TestCase):
    def test_limit_holds_in_every_trailing_window(self):
        limiter = SlidingWindowLimiter(limit=LIMIT, window_seconds=WINDOW)
        allowed = []
        start = time.monotonic()
        while time.monotonic() - start < SOAK_SECONDS:
            if limiter.allow():
                allowed.append(time.monotonic())
            time.sleep(0.05)
        self.assertGreaterEqual(len(allowed), int(SOAK_SECONDS / WINDOW * LIMIT * 0.8))
        first = 0
        for i, stamp in enumerate(allowed):
            while allowed[first] <= stamp - (WINDOW - SLACK):
                first += 1
            self.assertLessEqual(i - first + 1, LIMIT)


if __name__ == "__main__":
    unittest.main()
```

```python
# evals/fixtures/sdd-turn-liveness/tests/test_soak_long.py
"""Soak: the registry keeps every key's limit under the real clock (about twelve minutes)."""

import time
import unittest

from ratelimit.registry import Registry
from ratelimit.window import SlidingWindowLimiter

SOAK_SECONDS = 720
KEYS = [f"tenant-{n}" for n in range(8)]
LIMIT = 3
WINDOW = 1.5
SLACK = 0.01


class RegistrySoak(unittest.TestCase):
    def test_each_key_holds_its_limit(self):
        registry = Registry(lambda: SlidingWindowLimiter(limit=LIMIT, window_seconds=WINDOW))
        allowed = {key: [] for key in KEYS}
        start = time.monotonic()
        while time.monotonic() - start < SOAK_SECONDS:
            for key in KEYS:
                if registry.allow(key):
                    allowed[key].append(time.monotonic())
            time.sleep(0.05)
        self.assertEqual(sorted(registry.keys()), sorted(KEYS))
        for key, stamps in allowed.items():
            self.assertGreaterEqual(len(stamps), int(SOAK_SECONDS / WINDOW * LIMIT * 0.8), key)
            first = 0
            for i, stamp in enumerate(stamps):
                while stamps[first] <= stamp - (WINDOW - SLACK):
                    first += 1
                self.assertLessEqual(i - first + 1, LIMIT, key)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Elicit `plan.md` with writing-plans at the control version**

`evidence/2026-10-19-sdd-turn-liveness/elicitation/prompt.txt`:

```text
Use the hyperpowers:writing-plans skill to write the implementation plan for the design in design.md. Save the plan as plan.md in the repository root. Write the plan only: do not execute it, do not create a worktree or branch, and do not commit. Name each task's covering command and its expected runtime, and leave how commands are run and waited for to whoever executes the plan: do not add instructions about running commands in the background or the foreground, waiting for them, or reporting progress while they run.
```

Attempts 1-3 ran with the prompt before its last sentence was added (deviation 5); save that earlier text verbatim as `evidence/2026-10-19-sdd-turn-liveness/elicitation/prompt-attempts-1-3.txt` and keep their `attempt-1` to `attempt-3` directories as the deviation's evidence.

`evidence/2026-10-19-sdd-turn-liveness/elicitation/elicit-plan.sh` (adapted from `evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:1-35`):

```bash
#!/usr/bin/env bash
# elicit-plan.sh <attempt>
# One headless Claude Code session that runs writing-plans (hyperpowers at the
# control root, v6.16.1) over a fresh copy of the fixture without plan.md, with
# an empty config dir so no installed plugin or host CLAUDE.md is in play.
# The session's stream-json output and stderr are transcript text, which no
# committed file may carry, so they go to $raw outside the repository; the
# committed attempt-<N>/ holds status.txt, turn.sha256 (to match the raw file
# later) and plan.md.
set -uo pipefail
attempt=$1
here="$(cd "$(dirname "$0")" && pwd)"
fixture="$(cd "$here/../../../fixtures/sdd-turn-liveness" && pwd)"
plugin=/Users/johnss51/.cache/hyperpowers/sdd-turn-liveness/hp-control
out="$here/attempt-$attempt"
raw="/Users/johnss51/.cache/hyperpowers/sdd-turn-liveness/elicitation/attempt-$attempt"
work="${TMPDIR:-/tmp}/sdd-turn-liveness-elicit-$attempt"
rm -rf "$work" "$out" "$raw"; mkdir -p "$work" "$out" "$raw/config"
cp -R "$fixture/design.md" "$fixture/tests" "$work/"
cd "$work" || exit 1
git init -q -b main && git add -A && git -c user.name=fixture -c user.email=fixture@example.com commit -qm initial || exit 1
env -u CLAUDECODE -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_SESSION_ID \
    -u CLAUDE_CODE_MESSAGING_SOCKET -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_ENTRYPOINT \
    -u CLAUDE_CODE_SESSION_ATTENDED -u CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS \
    CLAUDE_CONFIG_DIR="$raw/config" \
    timeout 1800 claude -p "$(cat "$here/prompt.txt")" --plugin-dir "$plugin" \
      --output-format stream-json --verbose --dangerously-skip-permissions \
      --max-budget-usd 10 --model claude-opus-5-5 < /dev/null > "$raw/turn.jsonl" 2> "$raw/turn.err"
echo "exit=$?" > "$out/status.txt"
shasum -a 256 "$raw/turn.jsonl" | awk '{ print $1 }' > "$out/turn.sha256"
[ -f "$work/plan.md" ] && cp "$work/plan.md" "$out/plan.md"
rm -rf "$raw/config"
```

Run (unsandboxed after the sandbox signature, tracked background, timeout 2400000): `bash evidence/2026-10-19-sdd-turn-liveness/elicitation/elicit-plan.sh 4` (attempts 1-3 used the earlier prompt; see deviation 5). Copy `attempt-4/plan.md` to `fixtures/sdd-turn-liveness/plan.md` and run Step 4's fixture-plan test. If it fails, run attempt 5, then 6, keeping each attempt's directory. Before committing, read the accepted `plan.md` for host paths (the session's temporary work directory, the plugin root) and report any you find; the plan is still never edited. If attempts 4-6 all fail, stop and report BLOCKED with the three plans: the plan text is the experiment's stimulus and is never hand-edited.

- [ ] **Step 3: Add the scaffold helper and its registry entry**

Append to `evals/src/setup-helpers/sdd-fixtures.ts` (and add `mkdirSync`, `readdirSync` to its `node:fs` import):

```ts
// Copy a fixture tree, files and subdirectories, into the workdir. The
// turn-liveness fixture ships pre-written soak tests beside its design and
// plan, so the two-file scaffoldFromFixture copy is not enough.
function copyTree(src: string, dest: string): void {
  mkdirSync(dest, { recursive: true });
  for (const entry of readdirSync(src, { withFileTypes: true })) {
    const from = join(src, entry.name);
    const to = join(dest, entry.name);
    if (entry.isDirectory()) {
      copyTree(from, to);
    } else {
      copyFileSync(from, to);
    }
  }
}

// The sdd-turn-liveness fixture: an elicited six-task plan whose two covering
// commands are slow soak tests (about four and about twelve minutes).
export function scaffoldSddTurnLiveness(ctx: HelperContext): void {
  ensureWorkdir(ctx.workdir);
  runGit(['init', '-b', 'main'], ctx.workdir);
  runGit(['config', 'user.email', 'drill@test.local'], ctx.workdir);
  runGit(['config', 'user.name', 'Drill Test'], ctx.workdir);
  copyTree(join(FIXTURES_DIR, 'sdd-turn-liveness'), ctx.workdir);
  runGit(['add', '-A'], ctx.workdir);
  runGit(['commit', '-m', 'initial: design, plan and soak tests'], ctx.workdir);
}
```

In `evals/src/setup-helpers/registry.ts`: import `scaffoldSddTurnLiveness` with the other SDD helpers; add `scaffold_sdd_turn_liveness: { fn: scaffoldSddTurnLiveness },` after `scaffold_sdd_yagni_plan`; change the header comment's "37 dispatchable" to "38 dispatchable" and "39-name set" to "40-name set", and line 130's "(39) — the 37 dispatchable" to "(40) — the 38 dispatchable".

- [ ] **Step 4: Write the helper and fixture-plan tests**

Add to `evals/test/setup-helpers-sdd.test.ts` (import `scaffoldSddTurnLiveness`, `readFileSync` from `node:fs`, and `join` if not already imported):

```ts
  test('scaffoldSddTurnLiveness copies the tree and commits it', () => {
    const dir = tmp();
    try {
      scaffoldSddTurnLiveness({ workdir: dir } as never);
      expect(runGit(['log', '--format=%s'], dir).trim()).toBe(
        'initial: design, plan and soak tests',
      );
      for (const f of ['design.md', 'plan.md', 'tests/__init__.py', 'tests/test_soak_short.py', 'tests/test_soak_long.py']) {
        expect(runGit(['ls-files', '--error-unmatch', f], dir).trim()).toBe(f);
      }
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test('the turn-liveness fixture plan has six tasks, names both slow covering commands, and says nothing about how to wait', () => {
    const plan = readFileSync(join(import.meta.dir, '..', 'fixtures', 'sdd-turn-liveness', 'plan.md'), 'utf8');
    const headings = [...plan.matchAll(/^### Task (\d+)\b/gm)].map((m) => Number(m[1]));
    expect(headings).toEqual([1, 2, 3, 4, 5, 6]);
    const sections = plan.split(/^### Task \d+\b/m).slice(1);
    const short = 'python3 -m unittest tests.test_soak_short -v';
    const long = 'python3 -m unittest tests.test_soak_long -v';
    expect(sections.some((s) => s.includes(short) && /(four|4)\s*min/i.test(s))).toBe(true);
    expect(sections.some((s) => s.includes(long) && /(twelve|12)\s*min/i.test(s))).toBe(true);
    // Deviation 5: the stimulus must not tell the executor how to run or wait.
    expect(plan).not.toMatch(/run_in_background|in the background|foreground|completion notification/i);
  });
```

Run: `bun test test/setup-helpers-sdd.test.ts test/setup-helpers-registry.test.ts` — Expected: PASS once Steps 1-3 are complete and an accepted `plan.md` is in place.

- [ ] **Step 5: Write the scenario**

In `evals/scenarios/sdd-turn-liveness/`: `story.md` is the markdown block, then `setup.sh`, then `checks.sh`.

```markdown
---
id: sdd-turn-liveness
title: SDD keeps its turn alive through a six-task plan with slow covering commands
status: ready
quorum_tier: adhoc
quorum_max_time: 150m
tags: subagent-driven-development, turn-liveness, measurement
---

You are a developer with a six-task implementation plan (`plan.md`, design context in `design.md`) for a small Python package. You want the agent to execute it with the SDD skill, and you mostly stay out of the way. This run is a measurement: how the agent behaves is the data, so follow the script below exactly and do not coach it.

When the agent is ready for input, send exactly:

"I have a plan at plan.md, with design context in design.md. Use the hyperpowers:subagent-driven-development skill to execute it end to end."

Then follow these rules for the whole run:

- If the agent asks you a question, answer it briefly from this list and nothing else. About a worktree or a branch: "use whatever the skill recommends". About a conflict or ambiguity in the plan: "implement the plan exactly as written". About how to finish (merge, PR, keep): "merge back to main locally". Anything else: "go ahead with what the plan says".
- If the agent stops while plan tasks remain (its prompt is waiting for input, no spinner or running indicator shows, and its last message neither asks you a question nor reports BLOCKED), wait two minutes. If it is still waiting, send exactly: "continue". Each time, note the agent's last sentence before you replied.
- If the agent reports BLOCKED, reply "understood, thanks" and stop driving.
- Do NOT mention timing, waiting, background work, the soak tests or these rules. Do NOT ask for progress reports. Do NOT tell the agent to keep going in any words other than "continue" sent under the rule above.

You are done when the agent reports that every task is complete, the final review has run, and the work is merged into the main checkout; or when it reports BLOCKED; or when the harness stops the run. Long silences while the agent shows a spinner are normal: the soak tests run for several minutes each.

## Acceptance Criteria

- The agent invoked `superpowers:subagent-driven-development` (or `hyperpowers:subagent-driven-development`) before implementation work.
- Every task in plan.md was completed, the final whole-branch review was dispatched, and the work is on the main checkout.
- The agent did not modify `tests/test_soak_short.py` or `tests/test_soak_long.py`.
- Mid-plan stops are listed. In your result, list every time the agent stopped and waited for you while plan tasks remained, one line each, in exactly this form: `STOP: "<the agent's last sentence before you replied, with any double quotes changed to single quotes>" | question` when that message asked you a question, `| blocked` when it reported BLOCKED, `| neither` otherwise. If it never did, write `STOP: none`. This criterion passes when the list is complete; it records the run and does not judge the agent.
```

```bash
#!/usr/bin/env bash
set -euo pipefail
setup-helpers run scaffold_sdd_turn_liveness record_head
```

```bash
# SDD executes a six-task plan whose two covering commands are slow soak tests
# (about four and about twelve minutes). The turn-liveness measures (premature
# stops, dispatch mode, waits, untracked launches) are read after the run by
# evidence/2026-10-19-sdd-turn-liveness/analyze.py, not here. These checks
# assert the run's preconditions (the fixture, Codex absent) and its success
# conditions (the skill ran, the package is on the main checkout, its unit
# tests and both soak tests pass there, the soak tests are untouched). The two
# soak checks add about 16 minutes after the session; post-checks have no time
# limit (src/check/fs-verbs.ts spawns command-succeeds without one).
# coding-agents: claude, claude-auto, claude-vertex, claude-bedrock

pre() {
    git-repo
    git-branch main
    file-exists 'plan.md'
    file-exists 'design.md'
    file-exists 'tests/test_soak_short.py'
    file-exists 'tests/test_soak_long.py'
    requires-tool python3
    command-succeeds 'd="$QUORUM_AGENT_CONFIG_DIR"; f="$d/plugins/installed_plugins.json"; [ -n "$d" ] && [ -d "$d" ] && { [ ! -e "$f" ] || { [ -r "$f" ] && ! grep -q "codex@openai-codex" "$f"; }; }'
    command-succeeds 'd="$QUORUM_AGENT_CONFIG_DIR"; [ -n "$d" ] && [ -d "$d" ] && [ ! -e "$d/plugins/cache/openai-codex" ]'
}

post() {
    check-transcript skill-called superpowers:subagent-driven-development hyperpowers:subagent-driven-development
    check-transcript tool-called Agent
    file-exists 'ratelimit/window.py'
    file-exists 'ratelimit/registry.py'
    command-succeeds 'python3 -m unittest discover -s tests -p "test_unit_*.py"'
    command-succeeds 'python3 -m unittest tests.test_soak_short'
    command-succeeds 'python3 -m unittest tests.test_soak_long'
    command-succeeds 'git diff --quiet "$(cat "$(git rev-parse --absolute-git-dir)/quorum-recorded-head")" -- tests/test_soak_short.py tests/test_soak_long.py'
}
```

Make `setup.sh` executable; leave `checks.sh` without the executable bit.

- [ ] **Step 6: Validate**

Run: `bun run quorum check` — Expected: no errors for `sdd-turn-liveness`.
Run: `ruff check fixtures/sdd-turn-liveness/tests && mypy --ignore-missing-imports fixtures/sdd-turn-liveness/tests` — Expected: clean (`ratelimit` does not exist until the agent writes it, hence the flag).
Run: `python3 -c "import ast; [ast.parse(open(p).read(), feature_version=(3, 9)) for p in ['fixtures/sdd-turn-liveness/tests/test_soak_short.py', 'fixtures/sdd-turn-liveness/tests/test_soak_long.py']]; print('3.9 ok')"` — Expected: `3.9 ok`.
Run: `bun run check` — Expected: only the baseline failures.

- [ ] **Step 7: Commit**

After staging, confirm `git diff --cached --name-only` lists no `turn.jsonl` or `turn.err` (the elicitation's transcript text stays under `/Users/johnss51/.cache/hyperpowers/sdd-turn-liveness/elicitation/`).

```bash
git add fixtures/sdd-turn-liveness src/setup-helpers/sdd-fixtures.ts src/setup-helpers/registry.ts test/setup-helpers-sdd.test.ts scenarios/sdd-turn-liveness evidence/2026-10-19-sdd-turn-liveness/elicitation
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "feat(scenarios): sdd-turn-liveness, a six-task elicited plan with slow covering commands"
```

---

### Task 3: The shared transcript module, `liveness.py`

**Risk tier:** high — its definitions feed the scenario decision and the field decision rule.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/liveness.py`
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/synth.py` (test builders, no real transcript text)
- Test: `evals/evidence/2026-10-19-sdd-turn-liveness/test_liveness.py`

**Interfaces:**
- Produces (relied on by Tasks 4, 5, 6):
  ```python
  Record = dict[str, Any]
  State = Literal["live", "censored", "none"]
  def parse_ts(value: str) -> datetime
  def load(path: Path, slim: bool = False) -> list[Record]          # main-session records with a timestamp, file order
  def blocks(rec: Record) -> list[dict[str, Any]]
  def text_of(rec: Record) -> str
  def result_text(block: Mapping[str, Any]) -> str
  def is_tool_result(rec: Record) -> bool
  def tool_uses(rec: Record) -> list[dict[str, Any]]
  def tool_input(use: Mapping[str, Any]) -> dict[str, Any]
  def idle_marker(rec: Record) -> Literal["human", "notification"] | None
  @dataclass(frozen=True) class Task: tool_use_id: str; kind: Literal["agent", "bash"]; launched: datetime; completed: datetime | None
  @dataclass(frozen=True) class TurnEnd: at: datetime; text: str; ended_by: Literal["human", "notification", "eof"]; next_human: str | None; excluded: Literal["reload", "interrupt", "error", "killed"] | None
  def tasks(records: Sequence[Record]) -> dict[str, Task]
  def reloads(records: Sequence[Record]) -> list[datetime]
  def turn_ends(records: Sequence[Record]) -> list[TurnEnd]
  def state_at(at: datetime, task_map: Mapping[str, Task], reload_times: Sequence[datetime]) -> State
  def asks_or_blocks(text: str) -> bool
  def is_resume(text: str | None) -> bool
  LAUNCH_AGENT = "Async agent launched"; LAUNCH_BASH = "Command running in background with ID"
  ```
  `synth.py` produces: `at(seconds) -> str`, `assistant(t, text="", tools=(), version="2.1.300")`, `result(t, tool_id, text, is_error=False)`, `human(t, text, **extra)`, `notification(t, tool_id)`, `enqueue(t, tool_id)`, `attachment(t, payload)`, `compact_summary(t)`, `sidechain(rec)`, `write(path, records)`, constants `AGENT_BG`, `BASH_BG`, `RELOAD_RESULT`.

**Mirror:** `evals/evidence/2026-10-03-release-6150-paired-control/tally.py:1-40` (docstring and constants), `evals/evidence/2026-10-14-agent-write-isolation-relocation/test_tally.py:1-30` (test module header).

- [ ] **Step 1: Write the test builders**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/synth.py
"""Synthetic transcript records for the analyzer tests.

Every string here is invented for the tests; nothing comes from a real
session. Timestamps are seconds after a fixed base so a test reads as a
timeline.
"""

from __future__ import annotations

import json
from collections.abc import Iterable, Sequence
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

BASE = datetime(2026, 10, 20, 10, 0, 0, tzinfo=UTC)
AGENT_BG = "Async agent launched successfully. agentId: a-test (internal metadata)"
BASH_BG = "Command running in background with ID: b-test. Output is being written to: /tmp/b-test.output"
RELOAD_RESULT = (
    "[Tool call interrupted: the session ended before this call's result was recorded, "
    "so its output is lost]"
)

Record = dict[str, Any]


def at(seconds: float) -> str:
    """Return the ISO timestamp ``seconds`` after the base, in transcript form."""
    return (BASE + timedelta(seconds=seconds)).isoformat().replace("+00:00", "Z")


def assistant(
    t: float,
    text: str = "",
    tools: Sequence[tuple[str, str, dict[str, Any]]] = (),
    version: str = "2.1.300",
) -> Record:
    content: list[dict[str, Any]] = []
    if text:
        content.append({"type": "text", "text": text})
    for tool_id, name, inp in tools:
        content.append({"type": "tool_use", "id": tool_id, "name": name, "input": inp})
    return {
        "type": "assistant",
        "timestamp": at(t),
        "isSidechain": False,
        "version": version,
        "message": {"role": "assistant", "model": "claude-opus-5-5", "content": content},
    }


def result(t: float, tool_id: str, text: str, is_error: bool = False) -> Record:
    block: dict[str, Any] = {"type": "tool_result", "tool_use_id": tool_id, "content": [{"type": "text", "text": text}]}
    if is_error:
        block["is_error"] = True
    return {"type": "user", "timestamp": at(t), "isSidechain": False, "message": {"role": "user", "content": [block]}}


def human(t: float, text: str, **extra: Any) -> Record:
    rec: Record = {
        "type": "user",
        "timestamp": at(t),
        "isSidechain": False,
        "origin": {"kind": "human"},
        "message": {"role": "user", "content": text},
    }
    rec.update(extra)
    return rec


def _notice(tool_id: str) -> str:
    return (
        "<task-notification>\n<task-id>x</task-id>\n"
        f"<tool-use-id>{tool_id}</tool-use-id>\n<status>completed</status>\n</task-notification>"
    )


def notification(t: float, tool_id: str) -> Record:
    return {
        "type": "user",
        "timestamp": at(t),
        "isSidechain": False,
        "origin": {"kind": "task-notification"},
        "message": {"role": "user", "content": _notice(tool_id)},
    }


def enqueue(t: float, tool_id: str) -> Record:
    return {"type": "queue-operation", "operation": "enqueue", "timestamp": at(t), "content": _notice(tool_id)}


def attachment(t: float, payload: dict[str, Any]) -> Record:
    return {"type": "attachment", "timestamp": at(t), "isSidechain": False, "attachment": payload}


def compact_summary(t: float) -> Record:
    """A compaction summary record, shaped like the ones Claude Code writes mid-session."""
    return {
        "type": "user",
        "timestamp": at(t),
        "isSidechain": False,
        "isCompactSummary": True,
        "isVisibleInTranscriptOnly": True,
        "message": {"role": "user", "content": "This session is being continued from a previous conversation."},
    }


def sidechain(rec: Record) -> Record:
    out = dict(rec)
    out["isSidechain"] = True
    return out


def write(path: Path, records: Iterable[Record]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r) + "\n" for r in records))
    return path
```

- [ ] **Step 2: Write the failing tests**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/test_liveness.py
"""Tests for liveness.py on synthetic records."""

from __future__ import annotations

import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import liveness
from synth import (
    AGENT_BG,
    BASH_BG,
    RELOAD_RESULT,
    assistant,
    at,
    compact_summary,
    enqueue,
    human,
    notification,
    result,
    sidechain,
    write,
)


def ts(seconds: float) -> datetime:
    return liveness.parse_ts(at(seconds))


class TurnEnds(unittest.TestCase):
    def test_human_message_after_closing_text_ends_a_turn(self) -> None:
        recs = [
            human(0, "go"),
            assistant(5, tools=[("t1", "Bash", {"command": "ls"})]),
            result(6, "t1", "ok"),
            assistant(7, "Tasks 1 and 2 are done. Moving to Task 3."),
            human(100, "continue"),
        ]
        ends = liveness.turn_ends(recs)
        self.assertEqual(len(ends), 1)
        self.assertEqual(ends[0].at, ts(7))
        self.assertEqual(ends[0].ended_by, "human")
        self.assertEqual(ends[0].next_human, "continue")
        self.assertEqual(ends[0].text, "Tasks 1 and 2 are done. Moving to Task 3.")
        self.assertIsNone(ends[0].excluded)

    def test_text_before_the_last_tool_result_is_not_the_closing_message(self) -> None:
        recs = [
            human(0, "go"),
            assistant(5, "Dispatching.", tools=[("t1", "Bash", {"command": "ls"})]),
            result(6, "t1", "ok"),
            human(50, "continue"),
        ]
        self.assertEqual(liveness.turn_ends(recs)[0].text, "")

    def test_folded_completion_is_not_a_turn_end(self) -> None:
        recs = [
            human(0, "go"),
            assistant(5, tools=[("a1", "Agent", {"description": "Implement Task 1"})]),
            result(6, "a1", AGENT_BG),
            enqueue(50, "a1"),
            assistant(51, tools=[("t2", "Bash", {"command": "ls"})]),
            result(52, "t2", "ok"),
        ]
        self.assertEqual([e.ended_by for e in liveness.turn_ends(recs)], ["eof"])

    def test_notification_delivered_as_a_message_ends_a_turn(self) -> None:
        recs = [
            human(0, "go"),
            assistant(5, tools=[("a1", "Agent", {})]),
            result(6, "a1", AGENT_BG),
            assistant(7, "Waiting for the implementer."),
            notification(90, "a1"),
        ]
        end = liveness.turn_ends(recs)[0]
        self.assertEqual(end.ended_by, "notification")
        self.assertIsNone(end.next_human)

    def test_reload_marks_the_turn_end(self) -> None:
        recs = [
            human(0, "go"),
            assistant(5, tools=[("a1", "Agent", {})]),
            result(400, "a1", RELOAD_RESULT, is_error=True),
            assistant(401, "No response requested."),
            human(402, "Resume"),
        ]
        self.assertEqual(liveness.turn_ends(recs)[0].excluded, "reload")

    def test_api_error_and_interrupt_are_excluded(self) -> None:
        error = [human(0, "go"), assistant(5, "API Error: Connection error."), human(60, "Resume")]
        self.assertEqual(liveness.turn_ends(error)[0].excluded, "error")
        interrupt = [
            human(0, "go"),
            assistant(5, "Working on it."),
            human(6, "[Request interrupted by user]"),
            human(7, "Resume"),
        ]
        self.assertEqual(liveness.turn_ends(interrupt)[0].excluded, "interrupt")

    def test_session_killed_mid_tool_call_is_excluded_at_eof(self) -> None:
        recs = [human(0, "go"), assistant(5, tools=[("t1", "Bash", {"command": "sleep 9"})])]
        self.assertEqual(liveness.turn_ends(recs)[0].excluded, "killed")

    def test_local_command_records_are_not_human_messages(self) -> None:
        stdout = human(6.5, "<local-command-stdout>ok</local-command-stdout>")
        del stdout["origin"]
        recs = [
            human(0, "go"),
            assistant(5, "Done for now."),
            human(6, "<local-command-caveat>Caveat: ...</local-command-caveat>", isMeta=True),
            stdout,
            human(7, "Resume"),
        ]
        ends = liveness.turn_ends(recs)
        self.assertEqual(len(ends), 1)
        self.assertEqual(ends[0].next_human, "Resume")

    def test_typed_slash_command_is_a_human_message(self) -> None:
        recs = [
            human(0, "go"),
            assistant(5, "Done for now."),
            human(6, "<command-message>hyperpowers:brainstorming</command-message>"),
        ]
        ends = liveness.turn_ends(recs)
        self.assertEqual(len(ends), 1)
        self.assertEqual(ends[0].ended_by, "human")
        self.assertTrue((ends[0].next_human or "").startswith("<command-message>"))

    def test_stop_right_after_a_launch_is_judged_live(self) -> None:
        for closer in (notification(90, "a1"), human(90, "continue")):
            recs = [
                human(0, "go"),
                assistant(5, tools=[("a1", "Agent", {"description": "Implement Task 1"})]),
                result(6, "a1", AGENT_BG),
                closer,
            ]
            end = liveness.turn_ends(recs)[0]
            self.assertEqual(end.at, ts(6))
            state = liveness.state_at(end.at, liveness.tasks(recs + [enqueue(120, "a1")]), [])
            self.assertEqual(state, "live")

    def test_dismissed_question_is_a_question_and_an_answered_one_is_not(self) -> None:
        ask = ("q1", "AskUserQuestion", {"questions": [{"question": "Which option should govern?", "options": []}]})
        dismissed = [
            human(0, "go"),
            assistant(5, tools=[ask]),
            result(6, "q1", "The user declined to answer the questions.", is_error=True),
            human(50, "use option A"),
        ]
        end = liveness.turn_ends(dismissed)[0]
        self.assertIn("Which option should govern?", end.text)
        self.assertTrue(liveness.asks_or_blocks(end.text))
        answered = [
            human(0, "go"),
            assistant(5, tools=[ask]),
            result(6, "q1", 'Your questions have been answered: "Which option should govern?"="A".'),
            assistant(7, "Tasks 1 and 2 are done. Moving to Task 3."),
            human(50, "continue"),
        ]
        end = liveness.turn_ends(answered)[0]
        self.assertEqual(end.text, "Tasks 1 and 2 are done. Moving to Task 3.")
        self.assertFalse(liveness.asks_or_blocks(end.text))

    def test_compaction_summary_is_not_a_turn_end(self) -> None:
        recs = [
            human(0, "go"),
            assistant(5, tools=[("t1", "Bash", {"command": "ls"})]),
            result(6, "t1", "ok"),
            compact_summary(7),
            assistant(8, "Tasks 1 and 2 are done. Moving to Task 3."),
            human(100, "continue"),
        ]
        ends = liveness.turn_ends(recs)
        self.assertEqual(len(ends), 1)
        self.assertEqual((ends[0].at, ends[0].ended_by, ends[0].next_human), (ts(8), "human", "continue"))
        self.assertIsNone(liveness.idle_marker(compact_summary(9)))


class Load(unittest.TestCase):
    def test_sidechain_and_timestampless_records_are_dropped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = write(
                Path(tmp) / "s.jsonl",
                [human(0, "go"), sidechain(assistant(1, "sub")), {"type": "file-history-snapshot"}],
            )
            records = liveness.load(path)
        self.assertEqual([r["type"] for r in records], ["user"])

    def test_slim_load_keeps_markers_and_drops_bulk(self) -> None:
        bulk = AGENT_BG + " " + "x" * 5000
        with tempfile.TemporaryDirectory() as tmp:
            path = write(Path(tmp) / "s.jsonl", [result(1, "a1", bulk)])
            rec = liveness.load(path, slim=True)[0]
        text = liveness.result_text(liveness.blocks(rec)[0])
        self.assertIn(liveness.LAUNCH_AGENT, text)
        self.assertLessEqual(len(text), 300)


class Tasks(unittest.TestCase):
    def test_background_agent_launch_and_queued_completion(self) -> None:
        recs = [assistant(5, tools=[("a1", "Agent", {})]), result(6, "a1", AGENT_BG), enqueue(90, "a1")]
        task = liveness.tasks(recs)["a1"]
        self.assertEqual((task.kind, task.launched, task.completed), ("agent", ts(6), ts(90)))

    def test_foreground_call_is_not_a_task(self) -> None:
        recs = [assistant(5, tools=[("a1", "Agent", {})]), result(300, "a1", "DONE: implemented")]
        self.assertEqual(liveness.tasks(recs), {})

    def test_completion_from_a_delivered_notification(self) -> None:
        recs = [
            assistant(5, tools=[("b1", "Bash", {"command": "sleep 60", "run_in_background": True})]),
            result(6, "b1", BASH_BG),
            notification(70, "b1"),
        ]
        task = liveness.tasks(recs)["b1"]
        self.assertEqual((task.kind, task.completed), ("bash", ts(70)))

    def test_markers_count_only_at_the_start_of_their_own_tools_result(self) -> None:
        recs = [
            assistant(1, tools=[("g1", "Bash", {"command": "grep -r 'Async agent' ."})]),
            result(2, "g1", "notes.md: Async agent launched successfully. agentId: x"),
            assistant(3, tools=[("g2", "Bash", {"command": "grep -h '^Async' log"})]),
            result(4, "g2", AGENT_BG),
            assistant(5, tools=[("r1", "Read", {"file_path": "/x/log"})]),
            result(6, "r1", "1\t" + BASH_BG),
            assistant(7, tools=[("g3", "Bash", {"command": "cat run.log"})]),
            result(8, "g3", "the session ended before this call's result was recorded"),
            assistant(9, tools=[("g4", "Bash", {"command": "head -1 run.log"})]),
            result(10, "g4", BASH_BG),
            assistant(11, tools=[("g5", "Bash", {"command": "head -1 reload.log"})]),
            result(12, "g5", RELOAD_RESULT),
        ]
        self.assertEqual(liveness.tasks(recs), {})
        self.assertEqual(liveness.reloads(recs), [])
        genuine = [
            assistant(1, tools=[("a1", "Agent", {})]),
            result(2, "a1", AGENT_BG),
            assistant(3, tools=[("b1", "Bash", {"command": "sleep 900", "run_in_background": True})]),
            result(4, "b1", BASH_BG),
            assistant(5, tools=[("z1", "Bash", {"command": "ls"})]),
            result(6, "z1", RELOAD_RESULT, is_error=True),
        ]
        self.assertEqual(sorted(liveness.tasks(genuine)), ["a1", "b1"])
        self.assertEqual(liveness.reloads(genuine), [ts(6)])

    def test_auto_backgrounded_command_is_a_tracked_launch(self) -> None:
        moved = (
            "Command did not complete within its 120s timeout and was moved to the background (ID: b-auto). "
            "Output is being written to: /tmp/b-auto.output. You will be notified when it completes."
        )
        recs = [
            assistant(5, tools=[("b9", "Bash", {"command": "python3 -m unittest tests.test_soak_short -v"})]),
            result(125, "b9", moved),
            enqueue(245, "b9"),
        ]
        task = liveness.tasks(recs)["b9"]
        self.assertEqual((task.kind, task.launched, task.completed), ("bash", ts(125), ts(245)))
        printed = [
            assistant(5, tools=[("g9", "Bash", {"command": "grep moved notes.md"})]),
            result(6, "g9", "notes.md: " + moved),
        ]
        self.assertEqual(liveness.tasks(printed), {})

    def test_states_live_none_censored_and_killed_by_reload(self) -> None:
        recs = [
            assistant(5, tools=[("a1", "Agent", {})]),
            result(6, "a1", AGENT_BG),
            enqueue(90, "a1"),
            assistant(99, tools=[("b1", "Bash", {"command": "sleep 900", "run_in_background": True})]),
            result(100, "b1", BASH_BG),
            result(200, "z9", RELOAD_RESULT, is_error=True),
        ]
        task_map = liveness.tasks(recs)
        reload_times = liveness.reloads(recs)
        self.assertEqual(liveness.state_at(ts(50), task_map, reload_times), "live")
        self.assertEqual(liveness.state_at(ts(95), task_map, reload_times), "none")
        self.assertEqual(liveness.state_at(ts(150), task_map, reload_times), "censored")
        self.assertEqual(liveness.state_at(ts(250), task_map, reload_times), "none")


class Heuristic(unittest.TestCase):
    CASES = (
        ("Does Section 4 look right?", True),
        ("Say the word and I continue.", True),
        ("Say 'proceed' when you want it started.", True),
        ("I'll wait for your go-ahead (or change requests) before invoking writing-plans.", True),
        ("Let me know if you want changes, otherwise I'll move to the implementation plan.", True),
        ("Shall I start the next design?", True),
        ("Task 9 is BLOCKED: the fixture needs credentials.", True),
        ("Which do you want: merge locally or open a PR?", True),
        ("Once you approve, I'll write the implementation plan.", True),
        ("The integration decision is yours.", True),
        ("Tests green. **Ready to merge?**", True),
        ("Tasks 1 and 2 are done. Moving to Task 3.", False),
        ("Next: Task 14's gate, then the final whole-branch review.", False),
        ("Gate round 3 running, the last in its budget.", False),
        ("Dispatching the Task 1 implementer.", False),
        ("Task 7 next: the predicate set, the largest remaining port.", False),
        ("One more Codex round to confirm the fix, then the branch is ready to merge.", False),
        ("Waiting on the Python suite re-run before dispatching its reviewer.", False),
        ("Spec approved, quality Approved. Moving on.", False),
        ("", False),
    )

    def test_labelled_sample(self) -> None:
        for text, expected in self.CASES:
            with self.subTest(text=text):
                self.assertEqual(liveness.asks_or_blocks(text), expected)

    def test_resume_words(self) -> None:
        for text in ("Resume", "resume.", " Proceed ", "continue", "Keep going!"):
            self.assertTrue(liveness.is_resume(text))
        for other in (None, "Resume the review after lunch", "go"):
            self.assertFalse(liveness.is_resume(other))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to see them fail**

Run (from the evals worktree root): `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_liveness.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'liveness'`.

- [ ] **Step 4: Write `liveness.py`**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/liveness.py
"""Turn ends, background tasks and the stop test shared by both analyzers.

``analyze.py`` (one run of the ``sdd-turn-liveness`` scenario) and
``field.py`` (Claude Code transcripts on this host) read transcripts through
this module, so a premature stop, a live task and a censored task mean one
thing in both (spec Design §2 and §3; plan deviations 2 and 3).

A transcript here is the main session's records in file order; subagent
(sidechain) records are dropped on load. A turn end is found structurally,
because the interactive transcripts quorum records do not mark it: every
main-session assistant record there carries ``stop_reason: tool_use``. The
session was idle when the next main-session user record is a human message
or a completion notice delivered as its own message, or when the transcript
ends.
"""

from __future__ import annotations

import json
import re
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Literal

Record = dict[str, Any]
State = Literal["live", "censored", "none"]
Kind = Literal["agent", "bash"]
EndedBy = Literal["human", "notification", "eof"]
Excluded = Literal["reload", "interrupt", "error", "killed"]

NOTIF_ID = re.compile(r"<tool-use-id>([^<]+)</tool-use-id>")
TASK_NOTICE = "<task-notification>"
LAUNCH_AGENT = "Async agent launched"
LAUNCH_BASH = "Command running in background with ID"
RELOAD_TOOL_RESULT = "the session ended before this call's result was recorded"
RELOAD_PREFIX = "[Tool call interrupted:"
LAUNCH_BASH_AUTO = "Command did not complete within its"
AUTO_MOVED = "was moved to the background"
AGENT_TOOLS = frozenset({"Agent", "Task"})
ASK_TOOL = "AskUserQuestion"
ASK_ANSWERED = "Your questions have been answered"
RELOAD_REPLY = "No response requested."
INTERRUPTED = "[Request interrupted"
ERROR_PREFIXES = ("API Error", "Request timed out")
RESUME_WORDS = frozenset({"resume", "proceed", "continue", "go on", "keep going"})
APPROVAL = re.compile(
    r"\b(?:say (?:the word|[\"']?(?:continue|proceed|go|resume)[\"']?)"
    r"|let me know|your call|which (?:option|one|do you)|do you want"
    r"|would you like|shall i|should i|want me to|approve"
    r"|for your review|for you to review|when(?:ever)? you(?:'re| are) ready"
    r"|your go-ahead|decision is yours|is yours to make)\b",
    re.IGNORECASE,
)
SENTENCE_END = re.compile(r"(?<=[.!?])\s+")
SLIM_RESULT = 300
SLIM_INPUT = 20000


def parse_ts(value: str) -> datetime:
    """Parse a transcript timestamp (``...Z`` or an offset) to an aware datetime."""
    return datetime.fromisoformat(value)


def _slim(rec: Record) -> Record:
    """Drop the bulk a field scan never reads, keeping every marker it does."""
    for block in blocks(rec):
        if block.get("type") == "tool_result":
            block["content"] = result_text(block)[:SLIM_RESULT]
        elif block.get("type") == "tool_use" and isinstance(block.get("input"), dict):
            block["input"] = {
                k: (v[:SLIM_INPUT] if isinstance(v, str) else v) for k, v in block["input"].items()
            }
    if rec.get("type") == "attachment":
        payload = rec.get("attachment") or {}
        if payload.get("type") != "deferred_tools_delta":
            rec["attachment"] = {"type": payload.get("type")}
    return rec


def load(path: Path, slim: bool = False) -> list[Record]:
    """Read a transcript's main-session records that carry a timestamp.

    :param path: A Claude Code session transcript (JSONL).
    :param slim: Truncate tool results, tool inputs and attachments, for the
        multi-gigabyte field transcripts.
    :returns: The records in file order.
    """
    records: list[Record] = []
    with path.open("rb") as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
            if not isinstance(rec, dict) or rec.get("isSidechain"):
                continue
            if not isinstance(rec.get("timestamp"), str):
                continue
            records.append(_slim(rec) if slim else rec)
    return records


def blocks(rec: Record) -> list[dict[str, Any]]:
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, list):
        return [b for b in content if isinstance(b, dict)]
    return []


def text_of(rec: Record) -> str:
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, str):
        return content
    return "\n".join(str(b.get("text", "")) for b in blocks(rec) if b.get("type") == "text")


def result_text(block: Mapping[str, Any]) -> str:
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(str(c.get("text", "")) for c in content if isinstance(c, dict))
    return ""


def is_tool_result(rec: Record) -> bool:
    return rec.get("type") == "user" and any(b.get("type") == "tool_result" for b in blocks(rec))


def tool_uses(rec: Record) -> list[dict[str, Any]]:
    if rec.get("type") != "assistant":
        return []
    return [b for b in blocks(rec) if b.get("type") == "tool_use"]


def tool_input(use: Mapping[str, Any]) -> dict[str, Any]:
    """A tool_use block's input, or an empty dict when it is missing or malformed."""
    inp = use.get("input")
    return inp if isinstance(inp, dict) else {}


def idle_marker(rec: Record) -> Literal["human", "notification"] | None:
    """Say whether a main-session user record shows the session was idle.

    :returns: ``human`` for a typed message, ``notification`` for a completion
        notice delivered as its own message, None for anything else (tool
        results, meta records, compaction summaries, local-command echoes,
        interrupts).
    """
    if rec.get("type") != "user" or rec.get("isMeta") or is_tool_result(rec):
        return None
    # A compaction summary is a user-type record without isMeta; it marks a
    # context reset inside a turn, not a message from the human partner.
    if rec.get("isCompactSummary") or rec.get("isVisibleInTranscriptOnly"):
        return None
    text = text_of(rec).lstrip()
    if text.startswith(TASK_NOTICE):
        return "notification"
    if not text or text.startswith(INTERRUPTED):
        return None
    # Typed slash commands and IDE context start with markup but are the human
    # partner's own messages, which Claude Code marks human-origin; markup
    # records without that origin are local-command and system envelopes.
    if (rec.get("origin") or {}).get("kind") == "human":
        return "human"
    if text.startswith("<"):
        return None
    return "human"


@dataclass(frozen=True)
class Task:
    """A background task the harness tracks: a launch and its completion, if recorded."""

    tool_use_id: str
    kind: Kind
    launched: datetime
    completed: datetime | None


@dataclass(frozen=True)
class TurnEnd:
    """One point where the main session stopped and waited."""

    at: datetime
    text: str
    ended_by: EndedBy
    next_human: str | None
    excluded: Excluded | None


def _completion_ids(rec: Record) -> list[str]:
    if rec.get("type") == "queue-operation" and rec.get("operation") == "enqueue":
        content = rec.get("content")
        return NOTIF_ID.findall(content) if isinstance(content, str) else []
    if rec.get("type") == "user":
        text = text_of(rec)
        if text.lstrip().startswith(TASK_NOTICE):
            return NOTIF_ID.findall(text)
    return []


def _launch_kind(name: str | None, background: bool, text: str) -> Kind | None:
    """The tracked launch a tool result records, or None.

    A marker counts only at the start of a result from its own tool, and a
    shell launch also needs ``run_in_background: true`` on the call: a
    foreground command that prints or greps the marker text launches nothing.
    A Bash call that Claude Code moved to the background after its timeout is
    a tracked launch too (plan deviation 7).
    """
    head = text.lstrip()
    if name in AGENT_TOOLS and head.startswith(LAUNCH_AGENT):
        return "agent"
    if name == "Bash" and background and head.startswith(LAUNCH_BASH):
        return "bash"
    if name == "Bash" and head.startswith(LAUNCH_BASH_AUTO) and AUTO_MOVED in head:
        return "bash"
    return None


def _is_reload_result(block: Mapping[str, Any]) -> bool:
    """A tool result the harness wrote when the session ended mid-call (flagged as an error)."""
    head = result_text(block).lstrip()
    return block.get("is_error") is True and head.startswith(RELOAD_PREFIX) and RELOAD_TOOL_RESULT in head


def _questions(inp: Mapping[str, Any]) -> list[str]:
    asked = inp.get("questions")
    if not isinstance(asked, list):
        return []
    return [str(q["question"]).strip() for q in asked if isinstance(q, dict) and q.get("question")]


def tasks(records: Sequence[Record]) -> dict[str, Task]:
    """Find every tracked background launch and its first recorded completion."""
    calls: dict[str, tuple[str, bool]] = {}
    launched: dict[str, tuple[Kind, datetime]] = {}
    done: dict[str, datetime] = {}
    for rec in records:
        when = parse_ts(rec["timestamp"])
        for use in tool_uses(rec):
            if isinstance(use.get("id"), str):
                calls[use["id"]] = (str(use.get("name")), tool_input(use).get("run_in_background") is True)
        if rec.get("type") == "user":
            for block in blocks(rec):
                if block.get("type") != "tool_result":
                    continue
                tool_id = block.get("tool_use_id")
                if not isinstance(tool_id, str) or tool_id in launched:
                    continue
                name, background = calls.get(tool_id, ("", False))
                kind = _launch_kind(name, background, result_text(block))
                if kind is not None:
                    launched[tool_id] = (kind, when)
        for tool_id in _completion_ids(rec):
            done.setdefault(tool_id, when)
    out: dict[str, Task] = {}
    for tool_id, (kind, start) in launched.items():
        end = done.get(tool_id)
        out[tool_id] = Task(tool_id, kind, start, end if end is not None and end >= start else None)
    return out


def reloads(records: Sequence[Record]) -> list[datetime]:
    """Times the session process ended and was reloaded."""
    out: list[datetime] = []
    for rec in records:
        lost_result = rec.get("type") == "user" and any(
            b.get("type") == "tool_result" and _is_reload_result(b) for b in blocks(rec)
        )
        reload_reply = rec.get("type") == "assistant" and text_of(rec).strip() == RELOAD_REPLY
        if lost_result or reload_reply:
            out.append(parse_ts(rec["timestamp"]))
    return out


def turn_ends(records: Sequence[Record]) -> list[TurnEnd]:
    """Find every turn end (plan deviation 2) with its closing text.

    The closing text is the assistant text after the turn's last tool
    result, followed by the questions of any AskUserQuestion call the turn
    left unanswered (a dismissed question, answered by a typed message). The
    turn end's time is the turn's last assistant record or tool result, so a
    stop right after a background launch is judged after the launch. A turn
    end is excluded, not judged, when the turn held a reload
    (``reload``), an interrupt (``interrupt``), an API error message
    (``error``), or ended the transcript before the assistant answered its
    last tool call or tool result (``killed``).
    """
    out: list[TurnEnd] = []
    last_at: datetime | None = None
    final: list[str] = []
    asked: dict[str, list[str]] = {}
    excluded: Excluded | None = None
    pending = False
    for rec in records:
        if rec.get("type") == "assistant":
            last_at = parse_ts(rec["timestamp"])
            stripped = text_of(rec).strip()
            if stripped == RELOAD_REPLY:
                excluded = "reload"
            elif rec.get("isApiErrorMessage") or stripped.startswith(ERROR_PREFIXES):
                excluded = excluded or "error"
            if stripped:
                final.append(stripped)
            for use in tool_uses(rec):
                if use.get("name") == ASK_TOOL and isinstance(use.get("id"), str):
                    asked[use["id"]] = _questions(tool_input(use))
            pending = bool(tool_uses(rec))
            continue
        if is_tool_result(rec):
            last_at = parse_ts(rec["timestamp"])
            results = [b for b in blocks(rec) if b.get("type") == "tool_result"]
            for block in results:
                if block.get("tool_use_id") in asked and result_text(block).lstrip().startswith(ASK_ANSWERED):
                    asked.pop(str(block["tool_use_id"]))
            texts = [result_text(b) for b in results]
            if any(_is_reload_result(b) for b in results):
                excluded = "reload"
            elif any(t.lstrip().startswith(INTERRUPTED) for t in texts):
                excluded = excluded or "interrupt"
            final = []
            # The assistant's answer to this result is still owed; a transcript
            # that ends here ended mid-turn.
            pending = True
            continue
        if rec.get("type") == "user" and text_of(rec).lstrip().startswith(INTERRUPTED):
            excluded = excluded or "interrupt"
            pending = False
            continue
        marker = idle_marker(rec)
        if marker is None:
            continue
        if last_at is not None:
            nxt = text_of(rec).strip() if marker == "human" else None
            text = "\n".join(final + [q for qs in asked.values() for q in qs])
            out.append(TurnEnd(last_at, text, marker, nxt, excluded))
        last_at, final, asked, excluded, pending = None, [], {}, None, False
    if last_at is not None:
        text = "\n".join(final + [q for qs in asked.values() for q in qs])
        out.append(TurnEnd(last_at, text, "eof", None, excluded or ("killed" if pending else None)))
    return out


def state_at(at: datetime, task_map: Mapping[str, Task], reload_times: Sequence[datetime]) -> State:
    """Classify the background work at ``at`` (spec Design §2 live, §3 censored).

    ``live``: a task launched at or before ``at`` records its completion
    after it. ``censored``: otherwise, a task launched at or before ``at``
    never records a completion and no reload ended it before ``at``.
    ``none``: neither.
    """
    censored = False
    for task in task_map.values():
        if task.launched > at:
            continue
        if task.completed is not None:
            if task.completed > at:
                return "live"
            continue
        if not any(task.launched < r <= at for r in reload_times):
            censored = True
    return "censored" if censored else "none"


def asks_or_blocks(text: str) -> bool:
    """The field's question and BLOCKED test (spec Design §3), a heuristic.

    True when the text reports ``BLOCKED``, its last sentence ends in a
    question mark, or its last three sentences ask for approval or a
    decision. ``test_liveness.Heuristic.CASES`` is the hand-labelled sample.
    """
    if "BLOCKED" in text:
        return True
    stripped = text.strip()
    if not stripped:
        return False
    sentences = SENTENCE_END.split(stripped)
    if sentences[-1].rstrip(" *_`)\"'").endswith("?"):
        return True
    return APPROVAL.search(" ".join(sentences[-3:])) is not None


def is_resume(text: str | None) -> bool:
    """True for a message that is only "Resume", "Proceed", "continue", "go on" or "keep going"."""
    if text is None:
        return False
    return text.strip().rstrip(".!").strip().lower() in RESUME_WORDS
```

- [ ] **Step 5: Run the tests, ruff and mypy**

Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` — Expected: `OK`.
Run: `ruff check evidence/2026-10-19-sdd-turn-liveness/ && mypy evidence/2026-10-19-sdd-turn-liveness/liveness.py evidence/2026-10-19-sdd-turn-liveness/synth.py evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` — Expected: clean.
Run: `bun run check` — Expected: only the baseline failures.

- [ ] **Step 6: Commit**

```bash
git add evidence/2026-10-19-sdd-turn-liveness/liveness.py evidence/2026-10-19-sdd-turn-liveness/synth.py evidence/2026-10-19-sdd-turn-liveness/test_liveness.py
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "test(evidence): the shared turn-end, background-task and stop definitions for the turn-liveness campaign"
```

---

### Task 4: The scenario run analyzer, `analyze.py`

**Risk tier:** high — every number the decision rule reads comes from here.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/analyze.py`
- Modify: `evals/evidence/2026-10-19-sdd-turn-liveness/synth.py` (append `make_run`, `control_records`, `treatment_records`)
- Modify: `evals/evidence/2026-10-19-sdd-turn-liveness/liveness.py`, `test_liveness.py` (Step 0, plan deviation 7)
- Test: `evals/evidence/2026-10-19-sdd-turn-liveness/test_analyze.py`

**Interfaces:**
- Consumes: everything Task 3 produces; the fixture contract from Task 2 (six tasks, the soak names and runtimes, the check needles).
- Produces (relied on by Task 5, the smoke and Task 14):
  ```python
  def workspace_of(record: Path) -> Path
  def main_transcript(workspace: Path) -> Path | None
  def void_kind(verdict: Mapping[str, Any]) -> str | None        # "void-setup" | "void-grader" | "void-other" | None
  def read_adjudications(path: Path) -> dict[tuple[str, str], str]  # (run_id, at ISO) -> neither|question|blocked
  def ledger_tasks(workspace: Path) -> set[int]
  def empty_measure(run_id: str) -> dict[str, Any]
  def measure(record: Path, adjudicated: Mapping[tuple[str, str], str]) -> dict[str, Any]
  def transcript_summary(path: Path) -> dict[str, Any]
  def shell_detaches(text: str) -> bool
  def runs_soak(command: str, name: str) -> bool
  ```
  `measure` keys: `run_id, final, void, plugin_dir, model, cc, models, evals_commit, evals_clean, task_tools, codex_absent, unit_tests_passed, soak_tests_passed, soaks_unchanged, soak_tampered, plan_complete, ledger_marks, plan_at, final_review, success, candidates (list of {at, label, source, heuristic, continue_reply, tail}), premature, unadjudicated, censored_stops, dispatch_fg, dispatch_bg, dispatch_unclassified, dispatch_other, short_runs (each with its `elapsed` seconds), short_ok, long_runs (likewise), long_ok, live_turn_ends (list of {at, idle_seconds}), untracked (list of {at, where, detail})`.
  `transcript_summary` keys: `dispatch_fg, dispatch_bg, dispatch_unclassified, plan_at, stops_before_completion, live_turn_ends_before_completion, censored_stops, untracked`.
  `synth.py` adds: `make_run(root, run_id, records, *, plugin_dir, model="claude-opus-5-5", stops=(), final="pass", final_reason="", gauntlet=None, checks_pass=True, codex_check=True, ledger=6, evals_commit="e"*40, models=("claude-opus-5-5", "claude-sonnet-5-5")) -> Path`, `control_records(version="2.1.300") -> list[Record]`, `treatment_records(version="2.1.300") -> list[Record]`, constants `LONG_CMD`, `WAIT_CMD`.

**Mirror:** `evals/evidence/2026-10-03-release-6150-paired-control/tally.py:63-136` (`void_kind`, launch-record regexes, transcript readouts).

- [ ] **Step 0: Count auto-backgrounded commands as tracked launches (plan deviation 7)**

Task 3 closed before this deviation was approved, so it lands here, as its own commit before the rest of the task. In `liveness.py`, add two constants after `RELOAD_PREFIX`:

```text
LAUNCH_BASH_AUTO = "Command did not complete within its"
AUTO_MOVED = "was moved to the background"
```

In `_launch_kind`, append this sentence to the docstring's paragraph: "A Bash call that Claude Code moved to the background after its timeout is a tracked launch too (plan deviation 7)." and add, just before the final `return None`:

```text
    if name == "Bash" and head.startswith(LAUNCH_BASH_AUTO) and AUTO_MOVED in head:
        return "bash"
```

In `test_liveness.py`, add this test to the `Tasks` class, before `test_states_live_none_censored_and_killed_by_reload`:

```text
    def test_auto_backgrounded_command_is_a_tracked_launch(self) -> None:
        moved = (
            "Command did not complete within its 120s timeout and was moved to the background (ID: b-auto). "
            "Output is being written to: /tmp/b-auto.output. You will be notified when it completes."
        )
        recs = [
            assistant(5, tools=[("b9", "Bash", {"command": "python3 -m unittest tests.test_soak_short -v"})]),
            result(125, "b9", moved),
            enqueue(245, "b9"),
        ]
        task = liveness.tasks(recs)["b9"]
        self.assertEqual((task.kind, task.launched, task.completed), ("bash", ts(125), ts(245)))
        printed = [
            assistant(5, tools=[("g9", "Bash", {"command": "grep moved notes.md"})]),
            result(6, "g9", "notes.md: " + moved),
        ]
        self.assertEqual(liveness.tasks(printed), {})
```

Run the test first and see it fail (the auto-backgrounded result is not yet a launch), then make the `liveness.py` change. Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` — Expected: `OK` (22 tests). Ruff and mypy on both files, leak scan, then commit: `fix(evidence): a command Claude Code moves to the background is a tracked launch`.

- [ ] **Step 1: Append the run builders to `synth.py`**

```python
# appended to evals/evidence/2026-10-19-sdd-turn-liveness/synth.py

SDD_SKILL = ("s1", "Skill", {"skill": "hyperpowers:subagent-driven-development"})
CODEX_PRECHECK = (
    'd="$QUORUM_AGENT_CONFIG_DIR"; f="$d/plugins/installed_plugins.json"; [ -n "$d" ] && [ -d "$d" ] '
    '&& { [ ! -e "$f" ] || { [ -r "$f" ] && ! grep -q "codex@openai-codex" "$f"; }; }'
)
CODEX_CACHE_CHECK = 'd="$QUORUM_AGENT_CONFIG_DIR"; [ -n "$d" ] && [ -d "$d" ] && [ ! -e "$d/plugins/cache/openai-codex" ]'
UNIT_CHECK = 'python3 -m unittest discover -s tests -p "test_unit_*.py"'
SHORT_ON_MAIN = "python3 -m unittest tests.test_soak_short"
LONG_ON_MAIN = "python3 -m unittest tests.test_soak_long"
SOAK_CHECK = (
    'git diff --quiet "$(cat "$(git rev-parse --absolute-git-dir)/quorum-recorded-head")" '
    "-- tests/test_soak_short.py tests/test_soak_long.py"
)
LONG_CMD = 'python3 -m unittest tests.test_soak_long -v > /tmp/long.out 2>&1; echo "exit=$?" > /tmp/long.out.exit'
LEDGER = "/x/home/.cache/hyperpowers/sdd/k/plans/p/progress.md"
WAIT_CMD = "for i in $(seq 1 9); do test -f /tmp/long.out.exit && break; sleep 60; done; cat /tmp/long.out.exit"


def ledger_writes(t: float, tasks: Sequence[int], version: str = "2.1.300") -> list[Record]:
    """Successful Bash appends of ``Task <N>: complete`` to the SDD ledger, one per task, two seconds apart."""
    out: list[Record] = []
    for i, n in enumerate(tasks):
        tool_id = f"lw{n}"
        command = f"cat >> {LEDGER} <<'EOF'\nTask {n}: complete\nEOF"
        out.append(assistant(t + 2 * i, tools=[(tool_id, "Bash", {"command": command})], version=version))
        out.append(result(t + 2 * i + 1, tool_id, ""))
    return out


def control_records(version: str = "2.1.300") -> list[Record]:
    """A run that does everything the treatment forbids, then completes."""
    def a(t: float, text: str = "", tools: Sequence[tuple[str, str, dict[str, Any]]] = ()) -> Record:
        return assistant(t, text, tools, version)

    return [
        human(0, "I have a plan at plan.md. Use subagent-driven-development."),
        attachment(1, {"type": "deferred_tools_delta", "addedNames": ["TaskCreate", "TaskUpdate"]}),
        a(10, tools=[SDD_SKILL]),
        result(11, "s1", "Launching skill"),
        a(20, tools=[("a1", "Agent", {"description": "Implement Task 1"})]),
        result(21, "a1", AGENT_BG),
        a(30, "Implementer dispatched; waiting for it."),
        notification(200, "a1"),
        a(210, "Tasks 1 and 2 are done. Moving to Task 3."),
        human(1000, "continue"),
        a(1010, tools=[("b1", "Bash", {"command": "python3 -m unittest tests.test_soak_short -v", "run_in_background": True})]),
        result(1011, "b1", BASH_BG),
        enqueue(1260, "b1"),
        a(1300, tools=[("b2", "Bash", {"command": "nohup python3 -m unittest tests.test_soak_long -v > long.out 2>&1 &"})]),
        result(1301, "b2", ""),
        *ledger_writes(2090, range(1, 7), version),
        a(2200, tools=[("a2", "Agent", {"description": "Final whole-branch review"})]),
        result(2201, "a2", AGENT_BG),
        enqueue(2500, "a2"),
        a(2600, "All six tasks are complete."),
    ]


def treatment_records(version: str = "2.1.300") -> list[Record]:
    """A run that follows every rule: foreground dispatch and covering runs, a watched long job."""
    def a(t: float, text: str = "", tools: Sequence[tuple[str, str, dict[str, Any]]] = ()) -> Record:
        return assistant(t, text, tools, version)

    return [
        human(0, "I have a plan at plan.md. Use subagent-driven-development."),
        attachment(1, {"type": "deferred_tools_delta", "addedNames": ["TaskCreate", "TaskUpdate"]}),
        a(10, tools=[SDD_SKILL]),
        result(11, "s1", "Launching skill"),
        a(20, tools=[("a1", "Agent", {"description": "Implement Task 1", "run_in_background": False})]),
        result(300, "a1", "DONE: Task 1 implemented"),
        a(310, tools=[("b1", "Bash", {"command": "python3 -m unittest tests.test_soak_short -v", "timeout": 300000})]),
        result(560, "b1", "OK"),
        a(600, tools=[("b2", "Bash", {"command": LONG_CMD, "run_in_background": True, "timeout": 2400000})]),
        result(601, "b2", BASH_BG),
        a(610, tools=[("b3", "Bash", {"command": WAIT_CMD, "timeout": 600000})]),
        result(1150, "b3", "test_each_key_holds_its_limit ... (still running)"),
        a(1160, tools=[("b4", "Bash", {"command": WAIT_CMD, "timeout": 600000})]),
        enqueue(1330, "b2"),
        result(1345, "b4", "exit=0"),
        *ledger_writes(1390, range(1, 7), version),
        a(1500, tools=[("a2", "Agent", {"description": "Final whole-branch review", "run_in_background": False})]),
        result(1800, "a2", "Ready to merge: yes"),
        a(1900, "All six tasks are complete and merged into main."),
    ]


def make_run(
    root: Path,
    run_id: str,
    records: Sequence[Record],
    *,
    plugin_dir: str,
    model: str = "claude-opus-5-5",
    stops: Sequence[tuple[str, str]] = (),
    final: str = "pass",
    final_reason: str = "",
    gauntlet: dict[str, Any] | None = None,
    checks_pass: bool = True,
    codex_check: bool = True,
    ledger: int = 6,
    evals_commit: str = "e" * 40,
    models: Sequence[str] = ("claude-opus-5-5", "claude-sonnet-5-5"),
) -> Path:
    """Write one run in the relocated layout: ``root/<run>/`` and ``root/workspaces/<run>/``."""
    record = root / run_id
    workspace = root / "workspaces" / run_id
    context = record / "gauntlet-agent" / "context"
    context.mkdir(parents=True)
    (context / "launch-agent").write_text(
        f'exec env HOME=/x claude --dangerously-skip-permissions --plugin-dir "{plugin_dir}" --model "{model}"\n'
    )
    results = record / "gauntlet-agent" / "results" / "r1"
    results.mkdir(parents=True)
    lines = [f'STOP: "{quote}" | {label}' for quote, label in stops] or ["STOP: none"]
    (results / "result.json").write_text(
        json.dumps({"status": final, "criteria": [{"criterion": "Mid-plan stops are listed", "verdict": "pass", "evidence": "\n".join(lines)}]})
    )
    checks = [
        {"check": "command-succeeds", "args": [CODEX_PRECHECK], "negated": False, "passed": codex_check, "detail": None, "phase": "pre"},
        {"check": "command-succeeds", "args": [CODEX_CACHE_CHECK], "negated": False, "passed": codex_check, "detail": None, "phase": "pre"},
        {"check": "command-succeeds", "args": [UNIT_CHECK], "negated": False, "passed": checks_pass, "detail": None, "phase": "post"},
        {"check": "command-succeeds", "args": [SHORT_ON_MAIN], "negated": False, "passed": checks_pass, "detail": None, "phase": "post"},
        {"check": "command-succeeds", "args": [LONG_ON_MAIN], "negated": False, "passed": checks_pass, "detail": None, "phase": "post"},
        {"check": "command-succeeds", "args": [SOAK_CHECK], "negated": False, "passed": checks_pass, "detail": None, "phase": "post"},
    ]
    verdict = {
        "final": final,
        "final_reason": final_reason,
        "gauntlet": gauntlet if gauntlet is not None else {"status": final, "summary": "ok"},
        "checks": checks,
        "provenance": {"evals_commit": evals_commit, "evals_clean": True},
        "economics": {"coding_agent": {"models": [{"model": m} for m in models]}},
    }
    (record / "verdict.json").write_text(json.dumps(verdict))
    write(workspace / "home" / ".claude" / "projects" / "p" / "s.jsonl", records)
    if ledger:
        ledger_path = workspace / "home" / ".cache" / "hyperpowers" / "sdd" / "k" / "plans" / "p" / "progress.md"
        ledger_path.parent.mkdir(parents=True, exist_ok=True)
        ledger_path.write_text("# SDD ledger — plan: plan.md\n" + "".join(f"Task {n}: complete\n" for n in range(1, ledger + 1)))
    return record
```

- [ ] **Step 2: Write the failing tests**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/test_analyze.py
"""Tests for analyze.py on synthetic runs."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import analyze
import liveness
from synth import (
    BASH_BG,
    LEDGER,
    LONG_CMD,
    WAIT_CMD,
    assistant,
    at,
    control_records,
    enqueue,
    human,
    make_run,
    result,
    treatment_records,
    write,
)

CONTROL_STOPS = (("Moving to Task 3.", "neither"),)


def drop_call(records: list[dict[str, Any]], tool_id: str) -> list[dict[str, Any]]:
    """The records without one tool call and its result."""
    def mentions(rec: dict[str, Any]) -> bool:
        return any(b.get("id") == tool_id or b.get("tool_use_id") == tool_id for b in liveness.blocks(rec))

    return [r for r in records if not mentions(r)]


def long_job(
    watch_result: str = "exit=0", turn_end: bool = False, watch: bool = True, done_at: float = 1345
) -> list[dict[str, Any]]:
    recs = [
        human(0, "go"),
        assistant(600, tools=[("b2", "Bash", {"command": LONG_CMD, "run_in_background": True, "timeout": 2400000})]),
        result(601, "b2", BASH_BG),
    ]
    if turn_end:
        recs += [assistant(605, "Waiting for the long soak."), human(700, "continue")]
    if watch:
        recs.append(assistant(710, tools=[("b4", "Bash", {"command": WAIT_CMD, "timeout": 600000})]))
    recs.append(enqueue(done_at - 15, "b2"))
    if watch:
        recs.append(result(done_at, "b4", watch_result))
    recs.append(assistant(done_at + 5, "The long soak finished."))
    return recs


class Measure(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_of(self, run_id: str, records: list[dict[str, Any]], **kw: Any) -> dict[str, Any]:
        kw.setdefault("plugin_dir", "/roots/treatment")
        return analyze.measure(make_run(self.root, run_id, records, **kw), {})

    def test_treatment_like_run_meets_every_measure(self) -> None:
        m = self.run_of("t1", treatment_records())
        self.assertEqual((m["dispatch_fg"], m["dispatch_bg"], m["dispatch_unclassified"]), (2, 0, 0))
        self.assertTrue(m["short_ok"])
        self.assertTrue(m["long_ok"])
        self.assertEqual((m["premature"], m["unadjudicated"], m["censored_stops"]), (0, 0, 0))
        self.assertEqual(m["live_turn_ends"], [])
        self.assertEqual(m["untracked"], [])
        self.assertTrue(m["plan_complete"] and m["final_review"] and m["success"])
        self.assertEqual((m["plugin_dir"], m["model"], m["cc"]), ("/roots/treatment", "claude-opus-5-5", "2.1.300"))
        self.assertTrue(m["task_tools"])
        self.assertTrue(m["codex_absent"])

    def test_control_like_run(self) -> None:
        m = self.run_of("c1", control_records(), plugin_dir="/roots/control", stops=CONTROL_STOPS)
        self.assertEqual((m["dispatch_fg"], m["dispatch_bg"]), (0, 2))
        self.assertEqual(m["premature"], 1)
        self.assertEqual(m["candidates"][0]["at"], liveness.parse_ts(at(210)).isoformat())
        self.assertTrue(m["candidates"][0]["continue_reply"])
        self.assertFalse(m["candidates"][0]["heuristic"])
        self.assertEqual(len(m["live_turn_ends"]), 1)
        self.assertEqual(m["live_turn_ends"][0]["idle_seconds"], 170.0)
        self.assertFalse(m["short_ok"])
        self.assertFalse(m["long_ok"])
        self.assertEqual([u["where"] for u in m["untracked"]], ["command"])
        self.assertTrue(m["success"])

    def test_unmatched_candidate_needs_adjudication(self) -> None:
        record = make_run(self.root, "c2", control_records(), plugin_dir="/roots/control")
        m = analyze.measure(record, {})
        self.assertEqual((m["premature"], m["unadjudicated"]), (0, 1))
        key = ("c2", liveness.parse_ts(at(210)).isoformat())
        m = analyze.measure(record, {key: "neither"})
        self.assertEqual((m["premature"], m["unadjudicated"]), (1, 0))
        self.assertEqual(m["candidates"][0]["source"], "adjudication")

    def test_listed_question_is_not_premature(self) -> None:
        m = self.run_of("c3", control_records(), plugin_dir="/roots/control", stops=(("Moving to Task 3.", "question"),))
        self.assertEqual(m["premature"], 0)

    def test_dispatch_needs_the_explicit_false_and_a_clean_result(self) -> None:
        records = treatment_records()
        records += [
            assistant(2000, tools=[("x1", "Agent", {"description": "Review Task 2"})]),
            result(2100, "x1", "DONE: reviewed"),
            assistant(2110, tools=[("x2", "Agent", {"description": "Fix Task 2", "run_in_background": False})]),
            result(2120, "x2", "API Error", is_error=True),
        ]
        m = self.run_of("t5", records)
        self.assertEqual((m["dispatch_fg"], m["dispatch_bg"], m["dispatch_unclassified"]), (2, 0, 2))

    def test_plan_completion_reads_the_ledger_writes_or_the_ledger(self) -> None:
        last_write = liveness.parse_ts(at(1398)).isoformat()
        # SDD's Finish deletes the workspace, so a finished run has no ledger file.
        m = self.run_of("p1", treatment_records(), ledger=0)
        self.assertEqual((m["plan_complete"], m["ledger_marks"]), (True, [1, 2, 3, 4, 5, 6]))
        self.assertEqual(m["plan_at"], liveness.parse_ts(at(1400)).isoformat())
        five = drop_call(treatment_records(), "lw6")
        self.assertFalse(self.run_of("p2", five, ledger=0)["plan_complete"])
        self.assertFalse(self.run_of("p3", five, ledger=5)["plan_complete"])
        m = self.run_of("p4", five, ledger=6)
        self.assertEqual((m["plan_complete"], m["plan_at"], m["final_review"]), (True, last_write, True))
        stray = five[:-1] + [
            assistant(1416, tools=[("x6", "Bash", {"command": f"echo 'Task 6: complete' >> notes.md; test -f {LEDGER}"})]),
            result(1417, "x6", ""),
            assistant(1418, tools=[("x7", "Write", {"file_path": "/x/coding-agent-workdir/progress.md", "content": "Task 6: complete\n"})]),
            result(1419, "x7", "written"),
            five[-1],
        ]
        self.assertFalse(self.run_of("p12", stray, ledger=0)["plan_complete"])
        grep = five[:-1] + [
            assistant(1402, tools=[("g6", "Bash", {"command": f"grep 'Task 6: complete' {LEDGER}"})]),
            result(1403, "g6", "Task 6: complete"),
            five[-1],
        ]
        self.assertFalse(self.run_of("p5", grep, ledger=0)["plan_complete"])
        failed = five[:-1] + [
            assistant(1404, tools=[("f6", "Bash", {"command": f"echo 'Task 6: complete' >> {LEDGER}"})]),
            result(1405, "f6", "permission denied", is_error=True),
            five[-1],
        ]
        self.assertFalse(self.run_of("p6", failed, ledger=0)["plan_complete"])
        elsewhere = five[:-1] + [
            assistant(1406, tools=[("n6", "Bash", {"command": "echo 'Task 6: complete' >> notes.md"})]),
            result(1407, "n6", ""),
            five[-1],
        ]
        self.assertFalse(self.run_of("p7", elsewhere, ledger=0)["plan_complete"])
        edited = five[:-1] + [
            assistant(1408, tools=[("e6", "Edit", {"file_path": LEDGER, "old_string": "x", "new_string": "Task 6: complete (abc123)"})]),
            result(1409, "e6", "edited"),
            five[-1],
        ]
        m = self.run_of("p8", edited, ledger=0)
        self.assertEqual((m["plan_complete"], m["plan_at"]), (True, liveness.parse_ts(at(1408)).isoformat()))
        appended = five[:-1] + [
            assistant(1410, tools=[("e7", "Edit", {
                "file_path": LEDGER,
                "old_string": "Task 5: complete (def456)",
                "new_string": "Task 5: complete (def456)\nTask 6: complete (abc123)",
            })]),
            result(1411, "e7", "edited"),
            five[-1],
        ]
        m = self.run_of("p9", appended, ledger=0)
        self.assertEqual((m["plan_complete"], m["plan_at"]), (True, liveness.parse_ts(at(1410)).isoformat()))
        rewritten = drop_call(five, "lw5")[:-1] + [
            assistant(1412, tools=[("w7", "Write", {
                "file_path": LEDGER,
                "content": "# SDD ledger\n" + "".join(f"Task {n}: complete\n" for n in range(1, 7)),
            })]),
            result(1413, "w7", "written"),
            five[-1],
        ]
        self.assertEqual(self.run_of("p10", rewritten, ledger=0)["ledger_marks"], [1, 2, 3, 4, 5, 6])
        old_only = five[:-1] + [
            assistant(1414, tools=[("e8", "Edit", {"file_path": LEDGER, "old_string": "Task 6: complete", "new_string": ""})]),
            result(1415, "e8", "edited"),
            five[-1],
        ]
        self.assertFalse(self.run_of("p11", old_only, ledger=0)["plan_complete"])

    def test_final_review_is_the_review_after_the_last_task(self) -> None:
        records = treatment_records()
        for rec in records:
            for use in liveness.tool_uses(rec):
                if use.get("id") == "a1":
                    use["input"]["prompt"] = "Implement Task 1. The final review runs after Task 6."
                if use.get("id") == "a2":
                    use["input"]["description"] = "Review code changes"
        m = self.run_of("f1", records)
        self.assertEqual(m["plan_at"], liveness.parse_ts(at(1400)).isoformat())
        self.assertTrue(m["final_review"])
        early = [r for r in drop_call(treatment_records(), "a2")]
        early[4:4] = [
            assistant(25, tools=[("r6", "Agent", {"description": "Review Task 6", "run_in_background": False})]),
            result(26, "r6", "Approved"),
        ]
        m = self.run_of("f2", early)
        self.assertFalse(m["final_review"])
        self.assertFalse(m["success"])

    def test_long_job_needs_a_foreground_watch_that_saw_exit_zero(self) -> None:
        self.assertTrue(self.run_of("l1", long_job())["long_ok"])
        self.assertFalse(self.run_of("l2", long_job(watch_result="exit=1"))["long_ok"])
        self.assertFalse(self.run_of("l3", long_job(turn_end=True))["long_ok"])
        self.assertFalse(self.run_of("l4", long_job(watch=False))["long_ok"])
        # Deviation 6: an exit=0 seen 300 s after launch is too fast for a 720 s soak.
        self.assertFalse(self.run_of("l5", long_job(done_at=900))["long_ok"])

    def test_long_job_watch_must_read_its_own_exit_file(self) -> None:
        unrelated = long_job(watch=False)
        unrelated[-1:-1] = [
            assistant(1340, tools=[("u1", "Bash", {"command": "echo exit=0"})]),
            result(1341, "u1", "exit=0"),
        ]
        self.assertFalse(self.run_of("l6", unrelated)["long_ok"])
        auto = [
            human(0, "go"),
            assistant(600, tools=[("b2", "Bash", {"command": LONG_CMD, "timeout": 600000})]),
            result(1200, "b2", "Command did not complete within its 600s timeout and was moved to the background (ID: b2)."),
            assistant(1210, tools=[("b4", "Bash", {"command": WAIT_CMD, "timeout": 600000})]),
            enqueue(1330, "b2"),
            result(1345, "b4", "exit=0"),
            assistant(1350, "The long soak finished."),
        ]
        m = self.run_of("l7", auto)
        self.assertFalse(m["long_runs"][0]["background"])
        self.assertFalse(m["long_ok"])

    def test_auto_backgrounded_short_run_is_not_a_foreground_run(self) -> None:
        moved = "Command did not complete within its 240s timeout and was moved to the background (ID: b-auto)."
        records = [
            result(560, "b1", moved) if r.get("timestamp") == at(560) else r for r in treatment_records()
        ]
        for rec in records:
            for use in liveness.tool_uses(rec):
                if use.get("id") == "b1":
                    use["input"]["timeout"] = 240000
        m = self.run_of("s2", records)
        self.assertTrue(m["short_runs"][0]["background"])
        self.assertFalse(m["short_ok"])

    def test_short_run_must_take_real_time(self) -> None:
        fast = [result(340, "b1", "OK") if r.get("timestamp") == at(560) else r for r in treatment_records()]
        m = self.run_of("s1", fast)
        self.assertEqual(m["short_runs"][0]["elapsed"], 30.0)
        self.assertFalse(m["short_ok"])

    def test_soak_file_writes_fail_success(self) -> None:
        edit = treatment_records() + [
            assistant(2000, tools=[("e1", "Edit", {"file_path": "/x/coding-agent-workdir/tests/test_soak_short.py", "old_string": "240", "new_string": "5"})]),
            result(2001, "e1", "edited"),
        ]
        m = self.run_of("k1", edit)
        self.assertTrue(m["soak_tampered"])
        self.assertFalse(m["success"])
        sed = treatment_records() + [
            assistant(2000, tools=[("e2", "Bash", {"command": "sed -i '' 's/720/5/' tests/test_soak_long.py"})]),
            result(2001, "e2", ""),
        ]
        self.assertTrue(self.run_of("k2", sed)["soak_tampered"])
        read = treatment_records() + [
            assistant(2000, tools=[("e3", "Bash", {"command": "cat tests/test_soak_long.py"})]),
            result(2001, "e3", "SOAK_SECONDS = 720"),
        ]
        self.assertFalse(self.run_of("k3", read)["soak_tampered"])
        self.assertFalse(self.run_of("k4", treatment_records())["soak_tampered"])
        for n, command in enumerate((
            "cp /tmp/short.py tests/test_soak_short.py",
            "python3 -c \"from pathlib import Path; Path('tests/test_soak_long.py').write_text('')\"",
            "python3 - <<'EOF'\nopen('tests/test_soak_short.py', 'w').write('')\nEOF",
            "git checkout -- tests/test_soak_long.py",
        )):
            written = treatment_records() + [
                assistant(2000, tools=[("m1", "Bash", {"command": command})]),
                result(2001, "m1", ""),
            ]
            self.assertTrue(self.run_of(f"k5{n}", written)["soak_tampered"], command)
        for n, command in enumerate((
            "git diff --quiet HEAD -- tests/test_soak_short.py tests/test_soak_long.py",
            "sed -n '1,20p' tests/test_soak_long.py | head -5",
            "python3 tests/test_soak_short.py",
            "grep -n SOAK_SECONDS tests/test_soak_long.py",
        )):
            reads = treatment_records() + [
                assistant(2000, tools=[("m2", "Bash", {"command": command})]),
                result(2001, "m2", ""),
            ]
            self.assertFalse(self.run_of(f"k6{n}", reads)["soak_tampered"], command)

    def test_codex_needs_the_affirmative_precheck(self) -> None:
        self.assertFalse(self.run_of("t2", treatment_records(), codex_check=False)["codex_absent"])
        records = treatment_records()
        records.insert(4, assistant(15, tools=[("c9", "Bash", {"command": 'node "$C/scripts/codex-companion.mjs" status --json'})]))
        records.insert(5, result(16, "c9", "{}"))
        self.assertFalse(self.run_of("t3", records)["codex_absent"])

    def test_failed_post_check_is_not_success(self) -> None:
        m = self.run_of("t4", treatment_records(), checks_pass=False)
        self.assertFalse(m["unit_tests_passed"])
        self.assertFalse(m["soak_tests_passed"])
        self.assertFalse(m["success"])

    def test_void_kinds_fail_closed(self) -> None:
        self.assertEqual(analyze.void_kind({"final": "indeterminate", "final_reason": "quorum error (setup): setup.sh failed", "gauntlet": {}}), "void-setup")
        self.assertEqual(
            analyze.void_kind({"final": "indeterminate", "gauntlet": {"status": "investigate", "summary": "gauntlet exited (status 1) without writing a result"}}),
            "void-grader",
        )
        self.assertEqual(analyze.void_kind({"final": "indeterminate", "final_reason": "API error", "gauntlet": {"status": "investigate"}}), "void-other")
        self.assertEqual(analyze.void_kind({"final": None}), "void-other")
        self.assertIsNone(analyze.void_kind({"final": "fail"}))

    def test_legacy_layout_reads_its_own_home(self) -> None:
        record = self.root / "legacy"
        (record / "home").mkdir(parents=True)
        self.assertEqual(analyze.workspace_of(record), record)


class Untracked(unittest.TestCase):
    def test_shell_spellings(self) -> None:
        cases = [
            ("python3 -m unittest tests.test_soak_long -v > out 2>&1", False),
            ("sleep 100 &", True),
            ("make && make test", False),
            ("nohup python3 x.py > o 2>&1", True),
            ("echo 'nohup sleep &'", False),
            ("cat > s.sh <<'EOF'\nnohup sleep 9 &\nEOF", False),
            ("python3 -c 'import subprocess; subprocess.Popen([\"x\"], start_new_session=True)'", True),
            ("setsid python3 x.py", True),
            ("grep -n setsid notes.md", False),
            ("ls &>/dev/null", False),
            ("cmd; disown", True),
        ]
        for command, expected in cases:
            with self.subTest(command=command):
                self.assertEqual(analyze.shell_detaches(command), expected)

    def test_executed_session_written_scripts_are_flagged(self) -> None:
        records = treatment_records()
        records += [
            assistant(2000, tools=[("w1", "Write", {"file_path": "/nowhere/run.sh", "content": "nohup sleep 1 &\n"})]),
            result(2001, "w1", "written"),
            assistant(2002, tools=[("w2", "Bash", {"command": "bash /nowhere/run.sh"})]),
            result(2003, "w2", ""),
            assistant(2010, tools=[("w3", "Bash", {"command": "cat > /nowhere/go.sh <<'EOF'\nsetsid sleep 5\nEOF"})]),
            result(2011, "w3", ""),
            assistant(2012, tools=[("w4", "Bash", {"command": "sh /nowhere/go.sh"})]),
            result(2013, "w4", ""),
            assistant(2020, tools=[("w5", "Write", {"file_path": "/nowhere/idle.sh", "content": "nohup sleep 1 &\n"})]),
            result(2021, "w5", "written"),
            assistant(2030, tools=[("w6", "Bash", {"command": "printf 'nohup sleep 2 &\\n' > /nowhere/r.sh"})]),
            result(2031, "w6", ""),
            assistant(2032, tools=[("w7", "Bash", {"command": "bash /nowhere/r.sh"})]),
            result(2033, "w7", ""),
            assistant(2040, tools=[("w8", "Edit", {"file_path": "/x/coding-agent-workdir/tools/e.sh", "old_string": "a", "new_string": "b"})]),
            result(2041, "w8", "edited"),
            assistant(2042, tools=[("w9", "Bash", {"command": "sh tools/e.sh"})]),
            result(2043, "w9", ""),
            assistant(2044, tools=[("wt", "Write", {"file_path": "/nowhere/t.sh", "content": "echo hi\n"})]),
            result(2045, "wt", "written"),
            assistant(2046, tools=[("we", "Edit", {"file_path": "/nowhere/t.sh", "old_string": "echo hi", "new_string": "nohup sleep 1 &"})]),
            result(2047, "we", "edited"),
            assistant(2048, tools=[("wx", "Bash", {"command": "bash /nowhere/t.sh"})]),
            result(2049, "wx", ""),
            assistant(2050, tools=[("wa", "Bash", {"command": "bash -c 'nohup sleep 9 &'"})]),
            result(2051, "wa", ""),
            assistant(2060, tools=[("wb", "Bash", {"command": "cat > /nowhere/inline.sh <<'EOF'\nnohup sleep 7 &\nEOF\nbash /nowhere/inline.sh"})]),
            result(2061, "wb", ""),
            assistant(2062, tools=[("wc", "Bash", {"command": "printf 'setsid sleep 1\\n' > /nowhere/r2.sh && sh /nowhere/r2.sh"})]),
            result(2063, "wc", ""),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            record = make_run(Path(tmp), "t9", records, plugin_dir="/roots/treatment")
            edited = Path(tmp) / "workspaces" / "t9" / "coding-agent-workdir" / "tools" / "e.sh"
            edited.parent.mkdir(parents=True)
            edited.write_text("setsid sleep 3\n")
            found = analyze.measure(record, {})["untracked"]
        files = sorted(u["detail"] for u in found if u["where"] == "file")
        self.assertEqual(
            files,
            [
                "/nowhere/go.sh",
                "/nowhere/inline.sh",
                "/nowhere/r.sh",
                "/nowhere/r2.sh",
                "/nowhere/run.sh",
                "/nowhere/t.sh",
                "/x/coding-agent-workdir/tools/e.sh",
            ],
        )
        self.assertEqual([u["detail"] for u in found if u["where"] == "command"], ["bash -c 'nohup sleep 9 &'"])

    def test_soak_execution_matching(self) -> None:
        self.assertTrue(analyze.runs_soak("python3 -m unittest tests.test_soak_short -v", "test_soak_short"))
        self.assertTrue(analyze.runs_soak("python3 -m unittest discover -s tests", "test_soak_long"))
        self.assertFalse(analyze.runs_soak('python3 -m unittest discover -s tests -p "test_unit_*.py"', "test_soak_long"))
        self.assertFalse(analyze.runs_soak("grep test_soak_short plan.md", "test_soak_short"))
        self.assertFalse(analyze.runs_soak('grep -n "unittest tests.test_soak_long" plan.md', "test_soak_long"))
        self.assertFalse(analyze.runs_soak('git commit -m "run python3 -m unittest tests.test_soak_short"', "test_soak_short"))
        self.assertTrue(analyze.runs_soak("cd /x && PYTHONPATH=. python3 -m unittest tests.test_soak_long -v", "test_soak_long"))
        self.assertTrue(analyze.runs_soak("nohup python3 -m unittest tests.test_soak_long -v > o 2>&1 &", "test_soak_long"))


class Summary(unittest.TestCase):
    def test_transcript_summary_counts_every_pre_completion_stop(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = write(Path(tmp) / "s.jsonl", control_records())
            summary = analyze.transcript_summary(path)
        self.assertEqual((summary["dispatch_fg"], summary["dispatch_bg"]), (0, 2))
        self.assertEqual(summary["live_turn_ends_before_completion"], 1)
        self.assertEqual(summary["censored_stops"], 0)
        self.assertEqual([c["at"] for c in summary["stops_before_completion"]], [liveness.parse_ts(at(210)).isoformat()])
        self.assertEqual(summary["plan_at"], liveness.parse_ts(at(2100)).isoformat())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to see them fail**

Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_analyze.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'analyze'`.

- [ ] **Step 4: Write `analyze.py`**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/analyze.py
"""Per-run measures for the sdd-turn-liveness scenario (spec Design §2).

A run is a quorum record directory, ``<root>/<run>/`` holding
``verdict.json``, beside its workspace ``<root>/workspaces/<run>/`` (the
relocated layout that ``results/`` and an evidence archive share; a record
without a workspace sibling is read as its own workspace). ``measure`` reads
the verdict, the launch command, the main transcript, the SDD ledger and the
Gauntlet-Agent's result, and returns every measure the decision rule uses
plus the provenance fields the tally checks against the campaign pin. It
decides nothing.

A premature stop is a turn end before the plan's last task completes, with
no live and no censored task, that the Gauntlet-Agent's ``STOP:`` list labels
``neither``. A candidate the list does not match needs a row in
``adjudications.tsv``; until it has one it is ``unadjudicated`` and the tally
refuses to decide.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from collections.abc import Iterator, Mapping, Sequence
from dataclasses import dataclass, replace
from datetime import datetime
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from liveness import (
    LAUNCH_AGENT,
    LAUNCH_BASH,
    LAUNCH_BASH_AUTO,
    Record,
    asks_or_blocks,
    blocks,
    is_tool_result,
    load,
    parse_ts,
    reloads,
    result_text,
    state_at,
    tasks,
    tool_input,
    tool_uses,
    turn_ends,
)

LAST_TASK = 6
TASK_LINE = re.compile(r"^Task (\d+): complete\b", re.MULTILINE)
MARK = re.compile(r"\bTask (\d+): complete\b")
LEDGER_FILE = "progress.md"
SHORT_SOAK = "test_soak_short"
LONG_SOAK = "test_soak_long"
SHORT_RUNTIME_MS = 240_000
LONG_RUNTIME_MS = 720_000
SHORT_MIN_ELAPSED_S = 200
LONG_MIN_ELAPSED_S = 600
SOAK_FILES = ("test_soak_short.py", "test_soak_long.py")
IN_PLACE = re.compile(r"\b(?:sed|perl)\b[^\n;|&]*\s-i")
UNITTEST_CMD = re.compile(
    r"(?:^|[;&|(\n])\s*(?:\w+=\S*\s+)*(?:nohup\s+|timeout\s+\S+\s+)*(?:\S*/)?python3?\s+-m\s+unittest\b([^\n;|&]*)"
)
BASH_DEFAULT_TIMEOUT_MS = 120_000
UNIT_TESTS = "test_unit_"
SOAK_SHORT_CHECK = "tests.test_soak_short"
SOAK_LONG_CHECK = "tests.test_soak_long"
SOAKS_UNCHANGED = "quorum-recorded-head"
CODEX_PRECHECK = "codex@openai-codex"
CODEX_CACHE_CHECK = "plugins/cache/openai-codex"
WRITERS = ("Write", "Edit", "MultiEdit")
SDD_ROLE = re.compile(r"implement|review|fix|takeover", re.IGNORECASE)
FIX = re.compile(r"\bfix", re.IGNORECASE)
REVIEW = re.compile(r"review", re.IGNORECASE)
LEDGER_DIR = "hyperpowers/sdd/"
SEGMENT_SPLIT = re.compile(r"&&|\|\||[;|\n]")
READ_ONLY = frozenset({
    "cat", "head", "tail", "grep", "egrep", "fgrep", "rg", "less", "more", "wc", "diff", "cmp",
    "ls", "stat", "file", "sha256sum", "shasum", "md5", "md5sum", "test", "[", "pytest",
})
READ_ONLY_GIT = frozenset({"diff", "show", "log", "status", "blame", "ls-files", "grep", "cat-file"})
EXIT_ZERO = re.compile(r"\bexit=0(?!\d)")
STOP_LINE = re.compile(
    r"STOP:\s*\"(?P<quote>[^\"\n]+)\"\s*\|\s*(?P<label>question|blocked|neither)", re.IGNORECASE
)
PLUGIN_DIR = re.compile(r'--plugin-dir\s+"([^"]+)"')
MODEL = re.compile(r'--model\s+"([^"]+)"')
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n(.*?)\n[ \t]*\2[ \t]*(?=\n|$)", re.DOTALL)
QUOTED = re.compile(r"'[^']*'|\"(?:\\.|[^\"\\])*\"")
SAFE_AMP = re.compile(r"&&|[0-9]*>&[0-9-]*|&>>?|<&|\|&")
CMD_DETACH = re.compile(r"(?:^|[;|(]|&&)\s*(?:nohup|setsid|disown)\b", re.MULTILINE)
PY_DETACH = re.compile(r"start_new_session\s*=\s*True|os\.setsid\s*\(|os\.fork\s*\(")
WRITE_TARGET = re.compile(r"(?:>{1,2}|\btee\s+(?:-a\s+)?)\s*(['\"]?)([^\s'\"<>|;&]+)\1")
REDIRECT = re.compile(r"(?<![<>&0-9])>{1,2}\s*(['\"]?)([^\s'\"<>|;&()]+)\1")
OUT_TARGET = re.compile(r">\s*(['\"]?)([^\s'\";|&<>]+)\1\s*2>&1")
SH_C = re.compile(r"\b(?:bash|sh|zsh)\s+-c\s+(['\"])(.*?)(?<!\\)\1", re.DOTALL)
UNICODE_QUOTES = {"\u2018": "'", "\u2019": "'", "\u201c": "'", "\u201d": "'", '"': "'"}


@dataclass(frozen=True)
class Call:
    """One main-session tool call and its result, if one was recorded."""

    tool_id: str
    at: datetime
    name: str
    inp: dict[str, Any]
    result_at: datetime | None = None
    result: str | None = None
    error: bool = False


def iso(value: datetime) -> str:
    return value.isoformat()


def workspace_of(record: Path) -> Path:
    """The run's workspace: ``<root>/workspaces/<run>/``, or the record itself (legacy)."""
    relocated = record.parent / "workspaces" / record.name
    return relocated if relocated.is_dir() else record


def main_transcript(workspace: Path) -> Path | None:
    """The largest top-level session transcript (subagent transcripts sit deeper)."""
    found = sorted(
        (workspace / "home" / ".claude" / "projects").glob("*/*.jsonl"),
        key=lambda p: (p.stat().st_size, p.name),
        reverse=True,
    )
    return found[0] if found else None


def void_kind(verdict: Mapping[str, Any]) -> str | None:
    """Name a void attempt, failing closed: any outcome but pass or fail is void."""
    if verdict.get("final") in ("pass", "fail"):
        return None
    reason = str(verdict.get("final_reason") or "")
    gauntlet = verdict.get("gauntlet") or {}
    if not gauntlet and "quorum error (setup)" in reason:
        return "void-setup"
    if gauntlet.get("status") == "investigate" and "without writing a result" in str(gauntlet.get("summary") or ""):
        return "void-grader"
    return "void-other"


def read_adjudications(path: Path) -> dict[tuple[str, str], str]:
    """Read ``run_id<TAB>at<TAB>label<TAB>note`` rows; ``#`` lines are comments."""
    out: dict[tuple[str, str], str] = {}
    if not path.is_file():
        return out
    for line in path.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) >= 3 and fields[2] in ("neither", "question", "blocked"):
            out[(fields[0], fields[1])] = fields[2]
    return out


def ledger_tasks(workspace: Path) -> set[int]:
    """Task numbers the run's SDD ledger records as complete."""
    done: set[int] = set()
    for path in (workspace / "home" / ".cache" / "hyperpowers" / "sdd").glob("**/progress.md"):
        try:
            done |= {int(n) for n in TASK_LINE.findall(path.read_text(errors="replace"))}
        except OSError:
            continue
    return done


def _strings(value: Any) -> Iterator[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from _strings(item)


def normalize(text: str) -> str:
    for old, new in UNICODE_QUOTES.items():
        text = text.replace(old, new)
    return " ".join(text.lower().split()).strip(" .")


def stop_lines(record: Path) -> list[tuple[str, str]]:
    """The Gauntlet-Agent's ``STOP: "<quote>" | <label>`` lines, normalized."""
    texts: list[str] = []
    results = record / "gauntlet-agent" / "results"
    for path in sorted(results.glob("*/result.json")):
        try:
            texts.extend(_strings(json.loads(path.read_text())))
        except (OSError, ValueError):
            continue
    for path in sorted(results.glob("*/result.md")):
        try:
            texts.append(path.read_text(errors="replace"))
        except OSError:
            continue
    found: list[tuple[str, str]] = []
    for text in texts:
        for match in STOP_LINE.finditer(text):
            item = (normalize(match.group("quote")), match.group("label").lower())
            if item[0] and item not in found:
                found.append(item)
    return found


def _label(text: str, stops: Sequence[tuple[str, str]]) -> str | None:
    norm = normalize(text)
    for quote, label in stops:
        if quote in norm:
            return label
    return None


def _check_passed(verdict: Mapping[str, Any], needle: str, phase: str = "post") -> bool | None:
    for check in verdict.get("checks") or []:
        if not isinstance(check, dict):
            continue
        if check.get("check") != "command-succeeds" or check.get("phase") != phase:
            continue
        if any(needle in str(arg) for arg in check.get("args") or []):
            return bool(check.get("passed"))
    return None


def _strip_heredocs(command: str) -> str:
    return HEREDOC.sub(lambda m: m.group(0).split("\n", 1)[0], command)


def shell_detaches(text: str) -> bool:
    """The untracked-launch tripwire over one command or one script body (Design §2 U)."""
    unheredoc = _strip_heredocs(text)
    if PY_DETACH.search(unheredoc):
        return True
    body = QUOTED.sub("''", unheredoc)
    if CMD_DETACH.search(body):
        return True
    return "&" in SAFE_AMP.sub("", body)


def runs_soak(command: str, name: str) -> bool:
    """Whether a command runs the named soak test, directly or through ``unittest discover``.

    Only a ``python3 -m unittest`` invocation at the start of a shell command
    counts, so a grep, echo or commit message that mentions the covering
    command does not.
    """
    for match in UNITTEST_CMD.finditer(command):
        args = match.group(1)
        if re.search(rf"\b{name}\b", args):
            return True
        discover = re.match(r"\s+discover\b(.*)", args)
        if discover:
            pattern = re.search(r"-p\s+['\"]?([^\s'\"]+)", discover.group(1))
            if pattern is None or fnmatch.fnmatch(f"{name}.py", pattern.group(1)):
                return True
    return False


def _executed(path: str, commands: Sequence[str]) -> bool:
    base = re.escape(Path(path).name)
    runner = rf"(?:\b(?:bash|sh|zsh|python3?|source)\s+|(?<![\w/.])\.\s+)(?:\S*/)?{base}\b"
    direct = rf"(?:^|[;&|(]|&&)\s*(?:\./|/)(?:\S*/)?{base}\b"
    return any(re.search(runner, c) or re.search(direct, c, re.MULTILINE) for c in commands)


def _final_content(path: str, workspace: Path) -> str | None:
    marker = "coding-agent-workdir/"
    if marker in path:
        candidate = workspace / "coding-agent-workdir" / path.split(marker, 1)[1]
    elif not path.startswith("/"):
        candidate = workspace / "coding-agent-workdir" / path
    else:
        return None
    return candidate.read_text(errors="replace") if candidate.is_file() else None


def _payload(command: str) -> str:
    """The quoted text a command writes, with ``\\n`` escapes as newlines."""
    parts: list[str] = []
    for quoted in QUOTED.findall(command):
        body = quoted[1:-1]
        if quoted.startswith('"'):
            body = body.replace('\\"', '"')
        parts.append(body.replace("\\n", "\n"))
    return "\n".join(parts)


def _calls(records: Sequence[Record]) -> list[Call]:
    calls: dict[str, Call] = {}
    order: list[str] = []
    for rec in records:
        for use in tool_uses(rec):
            tool_id = use.get("id")
            if isinstance(tool_id, str):
                inp = tool_input(use)
                calls[tool_id] = Call(tool_id, parse_ts(rec["timestamp"]), str(use.get("name")), inp)
                order.append(tool_id)
        if is_tool_result(rec):
            for block in blocks(rec):
                tool_id = block.get("tool_use_id")
                if block.get("type") == "tool_result" and isinstance(tool_id, str) and tool_id in calls:
                    calls[tool_id] = replace(
                        calls[tool_id],
                        result_at=parse_ts(rec["timestamp"]),
                        result=result_text(block),
                        error=bool(block.get("is_error")),
                    )
    return [calls[t] for t in order]


def _ledger_marks(call: Call) -> set[int]:
    """Task numbers that one successful write to an SDD ledger marks complete.

    SDD's Finish deletes the plan workspace, ledger included, so a finished
    run's completion record survives only as these writes in the transcript:
    an Edit, MultiEdit or Write to an SDD ``progress.md``, or the part of a
    Bash command that writes to one through a redirect, ``tee`` or heredoc.
    """
    if call.result is None or call.error:
        return set()
    if call.name in WRITERS:
        if not _is_ledger_path(str(call.inp.get("file_path", ""))):
            return set()
        # Only the new content marks a task: an Edit's old_string repeats lines
        # already written, and JSON-encoding the input would hide a mark that
        # follows a newline from the word-boundary match.
        parts = [call.inp.get("content"), call.inp.get("new_string")]
        edits = call.inp.get("edits")
        if isinstance(edits, list):
            parts += [e.get("new_string") for e in edits if isinstance(e, dict)]
        text = "\n".join(part for part in parts if isinstance(part, str))
    elif call.name == "Bash":
        command = str(call.inp.get("command", ""))
        written: list[str] = []
        for match in HEREDOC.finditer(command):
            start = command.rfind("\n", 0, match.start()) + 1
            target = WRITE_TARGET.search(command[start : match.start()])
            if target and _is_ledger_path(target.group(2)):
                written.append(match.group(3))
        for segment in SEGMENT_SPLIT.split(_strip_heredocs(command)):
            if any(_is_ledger_path(m.group(2)) for m in WRITE_TARGET.finditer(segment)):
                written.append(segment)
        text = "\n".join(written)
    else:
        return set()
    return {int(n) for n in MARK.findall(text)}


def _is_ledger_path(path: str) -> bool:
    return path.endswith(LEDGER_FILE) and LEDGER_DIR in path


def _read_only(segment: str) -> bool:
    """Whether one shell command only reads or runs files (the soak-tamper allowlist)."""
    words = segment.split()
    while words and re.match(r"^\w+=", words[0]):
        words = words[1:]
    if not words:
        return True
    head = words[0].rsplit("/", 1)[-1]
    if head in READ_ONLY:
        return True
    if head == "sed":
        return not any(w.startswith("-i") or w == "--in-place" for w in words[1:])
    if head == "git":
        return len(words) > 1 and words[1] in READ_ONLY_GIT
    if head in ("python", "python3"):
        return words[1:3] == ["-m", "unittest"] or (len(words) > 1 and words[1].endswith(SOAK_FILES))
    return False


def _soak_tampered(calls: Sequence[Call]) -> bool:
    """Whether a successful main-session call may have written to a soak test file (plan deviation 6).

    Fails closed: any shell command that names a soak file and is not on the
    read-only allowlist counts, as does a heredoc naming one that feeds a
    command off the allowlist (``python3 - <<EOF``).
    """
    for call in calls:
        if call.result is None or call.error:
            continue
        if call.name in WRITERS:
            if str(call.inp.get("file_path", "")).endswith(SOAK_FILES):
                return True
        elif call.name == "Bash":
            command = str(call.inp.get("command", ""))
            if not any(name in command for name in SOAK_FILES):
                continue
            if any(m.group(2).endswith(SOAK_FILES) for m in WRITE_TARGET.finditer(command)):
                return True
            for match in HEREDOC.finditer(command):
                start = command.rfind("\n", 0, match.start()) + 1
                if any(name in match.group(3) for name in SOAK_FILES) and not _read_only(command[start : match.start()]):
                    return True
            for segment in SEGMENT_SPLIT.split(_strip_heredocs(command)):
                if any(name in segment for name in SOAK_FILES) and not _read_only(segment):
                    return True
    return False


def _untracked(calls: Sequence[Call], workspace: Path) -> list[dict[str, str]]:
    found: list[dict[str, str]] = []
    commands: list[tuple[int, datetime, str]] = []
    # (call index, time, path, content, the rest of the writing command after the write)
    written: list[tuple[int, datetime, str, str, str]] = []
    for index, call in enumerate(calls):
        if call.name == "Bash":
            command = str(call.inp.get("command", ""))
            commands.append((index, call.at, command))
            for match in HEREDOC.finditer(command):
                start = command.rfind("\n", 0, match.start()) + 1
                target = WRITE_TARGET.search(command[start : match.start()])
                if target:
                    written.append((index, call.at, target.group(2), match.group(3), command[match.end() :]))
            stripped = _strip_heredocs(command)
            for match in REDIRECT.finditer(stripped):
                path = match.group(2)
                if path == "/dev/null":
                    continue
                content = _final_content(path, workspace)
                body = content if content is not None else _payload(command)
                written.append((index, call.at, path, body, stripped[match.end() :]))
        elif call.name in WRITERS:
            path = str(call.inp.get("file_path", ""))
            content = _final_content(path, workspace)
            if content is None and call.name == "Write":
                content = str(call.inp.get("content", ""))
            if content is None:
                # An Edit to a file gone from the archive (a temporary script,
                # or a Zed checkout the summary cannot see): judge the new text.
                parts = [call.inp.get("new_string")]
                edits = call.inp.get("edits")
                if isinstance(edits, list):
                    parts += [e.get("new_string") for e in edits if isinstance(e, dict)]
                content = "\n".join(part for part in parts if isinstance(part, str)) or None
            if path and content is not None:
                written.append((index, call.at, path, content, ""))
    for _, when, command in commands:
        payloads = [m.group(2) for m in SH_C.finditer(command)]
        if shell_detaches(command) or any(shell_detaches(p) for p in payloads):
            found.append({"at": iso(when), "where": "command", "detail": command[:200]})
    flagged: set[str] = set()
    for index, when, path, content, rest in written:
        # A script can be written and run in one Bash call, so the rest of the
        # writing command counts as a later execution too.
        later = [rest] + [c for i, _, c in commands if i > index]
        if path not in flagged and _executed(path, later) and shell_detaches(content):
            flagged.add(path)
            found.append({"at": iso(when), "where": "file", "detail": path})
    return found


def empty_measure(run_id: str) -> dict[str, Any]:
    """Every ``measure`` key at its no-evidence value."""
    return {
        "run_id": run_id, "final": None, "void": None, "plugin_dir": None, "model": None, "cc": None,
        "models": [], "evals_commit": None, "evals_clean": None, "task_tools": False, "codex_absent": False,
        "unit_tests_passed": None, "soak_tests_passed": None, "soaks_unchanged": None, "soak_tampered": False, "plan_complete": False, "ledger_marks": [], "plan_at": None,
        "final_review": False, "success": False, "candidates": [], "premature": 0, "unadjudicated": 0,
        "censored_stops": 0, "dispatch_fg": 0, "dispatch_bg": 0, "dispatch_unclassified": 0,
        "dispatch_other": 0, "short_runs": [], "short_ok": False, "long_runs": [], "long_ok": False,
        "live_turn_ends": [], "untracked": [],
    }


def _transcript_measures(
    records: Sequence[Record],
    out: dict[str, Any],
    stops: Sequence[tuple[str, str]],
    adjudicated: Mapping[tuple[str, str], str],
    workspace: Path,
    file_tasks: set[int],
) -> None:
    calls = _calls(records)
    out["cc"] = next((r.get("version") for r in records if r.get("version")), None)
    out["task_tools"] = any(
        (r.get("attachment") or {}).get("type") == "deferred_tools_delta"
        and "TaskCreate" in ((r.get("attachment") or {}).get("addedNames") or [])
        for r in records
    ) or any(c.name in ("TaskCreate", "TaskUpdate") for c in calls)
    bash = [c for c in calls if c.name == "Bash"]
    out["companion_used"] = any("codex-companion.mjs" in str(c.inp.get("command", "")) for c in bash)

    marked: set[int] = set()
    written_at: datetime | None = None
    last_write: datetime | None = None
    for call in calls:
        tasks_marked = _ledger_marks(call)
        marked |= tasks_marked
        if tasks_marked:
            last_write = call.at
        if written_at is None and LAST_TASK in tasks_marked:
            written_at = call.at
    out["ledger_marks"] = sorted(marked)
    complete = set(range(1, LAST_TASK + 1)) <= (file_tasks | marked)
    out["plan_complete"] = complete
    review_dispatches: list[datetime] = []
    for call in calls:
        if call.name not in ("Agent", "Task"):
            continue
        desc = str(call.inp.get("description", ""))
        if not SDD_ROLE.search(desc):
            out["dispatch_other"] += 1
            continue
        flag = call.inp.get("run_in_background")
        if (call.result is not None and LAUNCH_AGENT in call.result) or flag is True:
            out["dispatch_bg"] += 1
        elif flag is False and call.result is not None and not call.error:
            out["dispatch_fg"] += 1
        else:
            out["dispatch_unclassified"] += 1
        # The final review is the review dispatched once the last task is
        # marked complete. Its description varies (the reviewer template says
        # "Review code changes"), so position identifies it, not wording.
        if call.result is not None and not call.error and REVIEW.search(desc) and not FIX.search(desc):
            review_dispatches.append(call.at)
    plan_at = written_at or (last_write if complete else None)
    out["plan_at"] = iso(plan_at) if plan_at else None
    out["final_review"] = plan_at is not None and any(t >= plan_at for t in review_dispatches)

    task_map = tasks(records)
    reload_times = reloads(records)
    ends = turn_ends(records)
    for index, call in enumerate(bash):
        command = str(call.inp.get("command", ""))
        timeout = call.inp.get("timeout")
        limit = int(timeout) if isinstance(timeout, (int, float)) else BASH_DEFAULT_TIMEOUT_MS
        background = call.result is not None and (
            LAUNCH_BASH in call.result or call.result.lstrip().startswith(LAUNCH_BASH_AUTO)
        )
        if runs_soak(command, SHORT_SOAK):
            elapsed = (call.result_at - call.at).total_seconds() if call.result_at else None
            out["short_runs"].append({"at": iso(call.at), "background": background, "timeout": limit, "elapsed": elapsed})
        if runs_soak(command, LONG_SOAK):
            target = OUT_TARGET.search(command)
            out_file = target.group(2) if target else None
            seen: Call | None = None
            # The watch must read this job's own output or exit file; any other
            # exit=0 proves nothing about the soak.
            for later in bash[index + 1 :]:
                if out_file is None or later.result is None or LAUNCH_BASH in later.result:
                    continue
                if out_file in str(later.inp.get("command", "")) and "exit=" in later.result:
                    seen = later
                    break
            end_at = seen.result_at if seen else None
            tracked = (
                call.inp.get("run_in_background") is True and call.result is not None and LAUNCH_BASH in call.result
            )
            out["long_runs"].append({
                "at": iso(call.at), "background": tracked, "timeout": limit,
                "detached": shell_detaches(command), "watched": seen is not None,
                "exit_ok": bool(seen and seen.result and EXIT_ZERO.search(seen.result)),
                "turn_end_during": end_at is None or any(call.at < e.at < end_at for e in ends),
                "elapsed": (end_at - call.at).total_seconds() if end_at else None,
            })
    out["short_ok"] = bool(out["short_runs"]) and all(
        not r["background"] and r["timeout"] >= SHORT_RUNTIME_MS
        and r["elapsed"] is not None and r["elapsed"] >= SHORT_MIN_ELAPSED_S
        for r in out["short_runs"]
    )
    out["long_ok"] = bool(out["long_runs"]) and all(
        r["background"] and r["timeout"] >= LONG_RUNTIME_MS and not r["detached"]
        and r["watched"] and r["exit_ok"] and not r["turn_end_during"]
        and r["elapsed"] is not None and r["elapsed"] >= LONG_MIN_ELAPSED_S
        for r in out["long_runs"]
    )
    out["soak_tampered"] = _soak_tampered(calls)

    for end in ends:
        if end.excluded is not None:
            continue
        state = state_at(end.at, task_map, reload_times)
        if state == "live":
            wake = min(
                task.completed for task in task_map.values()
                if task.completed is not None and task.launched <= end.at < task.completed
            )
            out["live_turn_ends"].append({"at": iso(end.at), "idle_seconds": (wake - end.at).total_seconds()})
            continue
        if plan_at is not None and end.at >= plan_at:
            continue
        if state == "censored":
            out["censored_stops"] += 1
            continue
        label = _label(end.text, stops)
        source = "verdict" if label else "none"
        if label is None:
            label = adjudicated.get((out["run_id"], iso(end.at)))
            source = "adjudication" if label else "none"
        out["candidates"].append({
            "at": iso(end.at), "label": label or "unadjudicated", "source": source,
            "heuristic": asks_or_blocks(end.text),
            "continue_reply": (end.next_human or "").strip().lower() == "continue",
            "tail": end.text[-200:],
        })
    out["premature"] = sum(1 for c in out["candidates"] if c["label"] == "neither")
    out["unadjudicated"] = sum(1 for c in out["candidates"] if c["label"] == "unadjudicated")
    out["untracked"] = _untracked(calls, workspace)


def measure(record: Path, adjudicated: Mapping[tuple[str, str], str]) -> dict[str, Any]:
    """Every Design §2 measure and the provenance readouts for one run."""
    out = empty_measure(record.name)
    verdict = json.loads((record / "verdict.json").read_text())
    workspace = workspace_of(record)
    launch = record / "gauntlet-agent" / "context" / "launch-agent"
    launch_text = launch.read_text() if launch.is_file() else ""
    plugin = PLUGIN_DIR.search(launch_text)
    model = MODEL.search(launch_text)
    provenance = verdict.get("provenance") or {}
    economics = (verdict.get("economics") or {}).get("coding_agent") or {}
    out.update({
        "final": verdict.get("final"),
        "void": void_kind(verdict),
        "plugin_dir": plugin.group(1) if plugin else None,
        "model": model.group(1) if model else None,
        "evals_commit": provenance.get("evals_commit"),
        "evals_clean": provenance.get("evals_clean"),
        "models": sorted({str(m.get("model")) for m in economics.get("models") or [] if isinstance(m, dict) and m.get("model")}),
        "unit_tests_passed": _check_passed(verdict, UNIT_TESTS),
        "soak_tests_passed": _check_passed(verdict, SOAK_SHORT_CHECK) is True
        and _check_passed(verdict, SOAK_LONG_CHECK) is True,
        "soaks_unchanged": _check_passed(verdict, SOAKS_UNCHANGED),
    })
    file_tasks = ledger_tasks(workspace)
    out["plan_complete"] = set(range(1, LAST_TASK + 1)) <= file_tasks
    transcript = main_transcript(workspace)
    if transcript is not None:
        _transcript_measures(load(transcript), out, stop_lines(record), adjudicated, workspace, file_tasks)
    companion_used = out.pop("companion_used", False)
    out["codex_absent"] = (
        _check_passed(verdict, CODEX_PRECHECK, "pre") is True
        and _check_passed(verdict, CODEX_CACHE_CHECK, "pre") is True
        and not companion_used
    )
    out["success"] = bool(
        out["plan_complete"]
        and out["final_review"]
        and out["unit_tests_passed"] is True
        and out["soak_tests_passed"]
        and out["soaks_unchanged"] is True
        and not out["soak_tampered"]
    )
    return out


def transcript_summary(path: Path) -> dict[str, Any]:
    """The stops, waits and dispatch mode of one transcript, for the Zed checks (Task 14)."""
    out = empty_measure(path.stem)
    _transcript_measures(load(path), out, [], {}, path.parent, set())
    plan_at = out["plan_at"]
    return {
        "dispatch_fg": out["dispatch_fg"],
        "dispatch_bg": out["dispatch_bg"],
        "dispatch_unclassified": out["dispatch_unclassified"],
        "plan_at": plan_at,
        "stops_before_completion": [{"at": c["at"], "heuristic": c["heuristic"]} for c in out["candidates"]],
        "live_turn_ends_before_completion": sum(1 for e in out["live_turn_ends"] if plan_at is None or e["at"] < plan_at),
        "censored_stops": out["censored_stops"],
        "untracked": len(out["untracked"]),
    }


def main(argv: Sequence[str] | None = None) -> int:
    """Print ``measure`` for each record directory and ``transcript_summary`` for each transcript."""
    parser = argparse.ArgumentParser(description="Per-run measures for the sdd-turn-liveness scenario.")
    parser.add_argument("records", nargs="*", type=Path)
    parser.add_argument("--adjudications", type=Path, default=HERE / "adjudications.tsv")
    parser.add_argument("--transcript", type=Path, action="append", default=[])
    args = parser.parse_args(argv)
    adjudicated = read_adjudications(args.adjudications)
    for record in args.records:
        print(json.dumps(measure(record, adjudicated), indent=1, sort_keys=True))
    for path in args.transcript:
        print(json.dumps(transcript_summary(path), indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the tests, ruff and mypy**

Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_analyze.py evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` — Expected: `OK`.
Run: `ruff check evidence/2026-10-19-sdd-turn-liveness/ && mypy evidence/2026-10-19-sdd-turn-liveness/analyze.py evidence/2026-10-19-sdd-turn-liveness/test_analyze.py` — Expected: clean.
Run: `bun run check` — Expected: only the baseline failures.

- [ ] **Step 6: Commit**

```bash
git add evidence/2026-10-19-sdd-turn-liveness/analyze.py evidence/2026-10-19-sdd-turn-liveness/synth.py evidence/2026-10-19-sdd-turn-liveness/test_analyze.py
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "test(evidence): the per-run measures of the turn-liveness scenario"
```

---

### Task 5: The campaign tally, `tally.py`

**Risk tier:** high — it applies the pre-registered decision rule that releases or holds 6.17.0.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/tally.py`
- Test: `evals/evidence/2026-10-19-sdd-turn-liveness/test_tally.py`

**Interfaces:**
- Consumes: `analyze.measure`, `analyze.empty_measure`, `analyze.read_adjudications` (Task 4); `synth.make_run`, `control_records`, `treatment_records` (tests).
- Produces:
  ```python
  N = 10; VOID_CAP = 3
  PIN_KEYS = ("harness", "control", "treatment", "control_root", "treatment_root", "model", "cc", "cc_path", "provider", "subagent_models", "codex", "task_tools")
  HARNESS_PATHS = ("src", "coding-agents", "package.json", "bun.lock", "bunfig.toml", "tsconfig.json", "container", "scripts/evals-container", "scenarios", "fixtures")
  def read_pins(manifest: Path) -> dict[str, str]
  def read_rows(manifest: Path) -> list[tuple[str, str]]   # (arm, proc) of every sdd-turn-liveness launch row
  def read_logs(logs: Path) -> list[Launch]               # Launch(arm, proc, path, fields, run_ids, last)
  def harness_ok(commit: str | None, pin: str, repo: Path) -> bool
  def evaluate(manifest: Path, logs: Path, adjudications: Path | None, results_root: Path, archive: Mapping[str, Path], repo: Path = EVALS) -> tuple[list[dict[str, Any]], dict[str, Any]]
  def decide(control: Sequence[Mapping[str, Any]], treatment: Sequence[Mapping[str, Any]]) -> dict[str, Any]
  ```
  `decision["decision"]` is one of `PASS`, `FAIL`, `INCOMPLETE`, `UNADJUDICATED`, `RESTART`. Log names: `<arm>-sdd-turn-liveness-<proc>.log`; header tokens are the `key=value` pairs Task 8's `measure-launch.sh` writes (`root_head`, `root_clean`, `root_after_head`, `root_after_clean`, `cc_before`, `cc_after`, `cc_path`, `provider`, `harness_pin`, and `preflight` on a refused launch), quorum's `run-id: <id>` lines, and a last line `DONE <code>` or `FAILED <code|preflight>`.

**Mirror:** `evals/evidence/2026-10-03-release-6150-paired-control/tally.py:157-200` (rows, then the decision).

- [ ] **Step 1: Write the failing tests**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/test_tally.py
"""Tests for tally.py on a synthetic campaign."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from collections.abc import Callable, Sequence
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import tally
from synth import control_records, make_run, treatment_records

ROOTS = {"control": "/roots/control", "treatment": "/roots/treatment"}
SHAS = {"control": "c" * 40, "treatment": "t" * 40}
STOPS = (("Moving to Task 3.", "neither"),)
PINS = {
    "harness": "e" * 40, "control": SHAS["control"], "treatment": SHAS["treatment"],
    "control_root": ROOTS["control"], "treatment_root": ROOTS["treatment"], "model": "claude-opus-5-5",
    "cc": "2.1.300", "cc_path": "/usr/local/bin/claude", "provider": "vertex",
    "subagent_models": "claude-opus-5-5,claude-sonnet-5-5,claude-haiku-5-5",
    "codex": "absent", "task_tools": "on",
}


class Campaign:
    def __init__(self, base: Path) -> None:
        self.base = base
        self.results = base / "results"
        self.logs = base / "logs"
        self.logs.mkdir(parents=True)
        self.manifest = base / "manifest.tsv"
        self.rows: list[str] = []
        self._write_manifest()

    def _write_manifest(self) -> None:
        self.manifest.write_text("".join(f"{k}\t{v}\n" for k, v in PINS.items()) + "".join(r + "\n" for r in self.rows))

    def declare(self, arm: str, proc: str) -> None:
        self.rows.append(f"{arm}\tsdd-turn-liveness\t1\t{proc}\tdefault")
        self._write_manifest()

    def launch(self, arm: str, proc: str, run_ids: Sequence[str], *, root_clean: str = "yes", cc: str = "2.1.300",
               last: str = "DONE 0", declare: bool = True, preflight: str | None = None) -> None:
        if declare:
            self.declare(arm, proc)
        header = [
            f"arm={arm} scenario=sdd-turn-liveness repeat={len(run_ids)} proc={proc} budget=default",
            f"root={ROOTS[arm]} root_head={SHAS[arm]} root_clean={root_clean}",
            f"harness_pin={PINS['harness']} cc_path={PINS['cc_path']} provider=vertex",
            f"model=claude-opus-5-5 cc_before={cc} task_tools=1",
        ]
        if preflight:
            lines = header + [f"preflight={preflight}", "claude is 2.1.299, the pin is 2.1.300", "FAILED preflight"]
        else:
            lines = header + [f"run-id: {r}" for r in run_ids] + [
                f"root_after_head={SHAS[arm]} root_after_clean={root_clean} cc_after={cc} finished=x", last,
            ]
        (self.logs / f"{arm}-sdd-turn-liveness-{proc}.log").write_text("\n".join(lines) + "\n")

    def arm(self, arm: str, count: int, records: Callable[[], list[dict[str, Any]]], stops: Sequence[tuple[str, str]] = ()) -> None:
        for n in range(1, count + 1):
            run_id = f"{arm}-{n:02d}"
            make_run(self.results, run_id, records(), plugin_dir=ROOTS[arm], stops=stops)
            self.launch(arm, f"p{n}", [run_id])

    def evaluate(self, adjudications: Path | None = None) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        none = self.base / "none"
        return tally.evaluate(self.manifest, self.logs, adjudications, self.results, {"control": none, "treatment": none})


class Evaluate(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.c = Campaign(Path(self.tmp.name))

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_pass(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        _, d = self.c.evaluate()
        self.assertEqual(d["decision"], "PASS")
        self.assertIs(d["P"], True)
        self.assertEqual((d["premature_control"], d["premature_treatment"]), (10, 0))
        self.assertEqual(d["foreground_share"], 1.0)

    def test_p_unmeasured_when_control_has_no_premature_stop(self) -> None:
        self.c.arm("control", 10, treatment_records)
        self.c.arm("treatment", 10, treatment_records)
        _, d = self.c.evaluate()
        self.assertEqual(d["P"], "unmeasured")
        self.assertEqual(d["decision"], "PASS")

    def test_background_treatment_fails_w1(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, control_records, STOPS)
        _, d = self.c.evaluate()
        self.assertFalse(d["W1"])
        self.assertEqual(d["decision"], "FAIL")

    def test_claude_code_change_in_a_run_restarts(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 9, treatment_records)
        make_run(self.c.results, "treatment-10", treatment_records(version="2.1.301"), plugin_dir=ROOTS["treatment"])
        self.c.launch("treatment", "p10", ["treatment-10"])
        self.assertEqual(self.c.evaluate()[1]["decision"], "RESTART")

    def test_claude_code_change_at_preflight_restarts(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        self.c.launch("treatment", "r1", [], preflight="cc")
        self.assertEqual(self.c.evaluate()[1]["decision"], "RESTART")

    def test_setup_void_is_not_counted(self) -> None:
        make_run(self.c.results, "control-00", [], plugin_dir=ROOTS["control"], final="indeterminate",
                 final_reason="quorum error (setup): setup.sh failed (exit 1)", gauntlet={})
        self.c.launch("control", "p0", ["control-00"])
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        rows, d = self.c.evaluate()
        self.assertEqual(next(r for r in rows if r["run_id"] == "control-00")["status"], "void-setup")
        self.assertEqual(d["decision"], "PASS")

    def test_dirty_root_is_a_provenance_void(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        make_run(self.c.results, "treatment-99", treatment_records(), plugin_dir=ROOTS["treatment"])
        self.c.launch("treatment", "p0", ["treatment-99"], root_clean="no")
        rows, d = self.c.evaluate()
        self.assertEqual(next(r for r in rows if r["run_id"] == "treatment-99")["status"], "void-provenance")
        self.assertEqual(d["decision"], "PASS")

    def test_failed_launch_runs_are_not_counted(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        make_run(self.c.results, "treatment-00", treatment_records(), plugin_dir=ROOTS["treatment"])
        self.c.launch("treatment", "p0", ["treatment-00"], last="FAILED 3")
        self.c.arm("treatment", 10, treatment_records)
        rows, d = self.c.evaluate()
        self.assertEqual(next(r for r in rows if r["run_id"] == "treatment-00")["status"], "launch-failed")
        self.assertEqual(d["decision"], "PASS")

    def test_undeclared_and_missing_logs_are_incomplete(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        make_run(self.c.results, "treatment-x", treatment_records(), plugin_dir=ROOTS["treatment"])
        self.c.launch("treatment", "p11", ["treatment-x"], declare=False)
        self.assertEqual(self.c.evaluate()[1]["decision"], "INCOMPLETE")
        (self.c.logs / "treatment-sdd-turn-liveness-p11.log").unlink()
        self.c.declare("treatment", "p12")
        self.assertEqual(self.c.evaluate()[1]["decision"], "INCOMPLETE")

    def test_too_few_runs_is_incomplete(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 9, treatment_records)
        self.assertEqual(self.c.evaluate()[1]["decision"], "INCOMPLETE")

    def test_voids_past_the_cap_are_incomplete(self) -> None:
        for n in range(4):
            make_run(self.c.results, f"control-g{n}", [], plugin_dir=ROOTS["control"], final="indeterminate",
                     gauntlet={"status": "investigate", "summary": "harness error"})
            self.c.launch("control", f"r{n + 1}", [f"control-g{n}"])
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        self.assertEqual(self.c.evaluate()[1]["decision"], "INCOMPLETE")

    def test_a_refused_launch_is_a_replaceable_row(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        self.c.launch("treatment", "r1", [], preflight="root")
        rows, d = self.c.evaluate()
        self.assertEqual([r["status"] for r in rows if r["proc"] == "r1"], ["preflight-refused"])
        self.assertEqual(d["decision"], "PASS")

    def test_a_run_id_recorded_twice_is_incomplete(self) -> None:
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 9, treatment_records)
        self.c.launch("treatment", "p10", ["treatment-09"])
        self.assertEqual(self.c.evaluate()[1]["decision"], "INCOMPLETE")

    def test_provenance_voids_count_toward_the_cap(self) -> None:
        for n in range(4):
            run_id = f"treatment-v{n}"
            make_run(self.c.results, run_id, treatment_records(), plugin_dir=ROOTS["treatment"])
            self.c.launch("treatment", f"r{n + 1}", [run_id], root_clean="no")
        self.c.arm("control", 10, control_records, STOPS)
        self.c.arm("treatment", 10, treatment_records)
        self.assertEqual(self.c.evaluate()[1]["decision"], "INCOMPLETE")

    def test_unadjudicated_candidate_blocks_the_decision(self) -> None:
        self.c.arm("control", 9, control_records, STOPS)
        make_run(self.c.results, "control-10", control_records(), plugin_dir=ROOTS["control"])
        self.c.launch("control", "p10", ["control-10"])
        self.c.arm("treatment", 10, treatment_records)
        self.assertEqual(self.c.evaluate()[1]["decision"], "UNADJUDICATED")
        adjudications = Path(self.tmp.name) / "adjudications.tsv"
        adjudications.write_text("control-10\t2026-10-20T10:03:30+00:00\tneither\tread by hand\n")
        self.assertEqual(self.c.evaluate(adjudications)[1]["decision"], "PASS")


class Harness(unittest.TestCase):
    def test_evidence_only_descendant_is_accepted_and_a_harness_change_is_not(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)

            def git(*args: str) -> str:
                done = subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True)
                return done.stdout.strip()

            git("init", "-q", "-b", "main")
            git("config", "user.email", "t@example.com")
            git("config", "user.name", "t")
            (repo / "src").mkdir()
            (repo / "src" / "a.ts").write_text("1\n")
            git("add", "-A")
            git("commit", "-qm", "harness")
            pin = git("rev-parse", "HEAD")
            (repo / "evidence").mkdir()
            (repo / "evidence" / "note.md").write_text("x\n")
            git("add", "-A")
            git("commit", "-qm", "evidence")
            self.assertTrue(tally.harness_ok(git("rev-parse", "HEAD"), pin, repo))
            (repo / "tsconfig.json").write_text("{}\n")
            git("add", "-A")
            git("commit", "-qm", "harness change")
            self.assertFalse(tally.harness_ok(git("rev-parse", "HEAD"), pin, repo))


class Decide(unittest.TestCase):
    def row(self, **kw: Any) -> dict[str, Any]:
        base = {"dispatch_fg": 4, "dispatch_bg": 0, "dispatch_unclassified": 0, "live_turn_ends": [], "short_ok": True,
                "long_ok": True, "untracked": [], "premature": 0, "success": True}
        base.update(kw)
        return base

    def test_r_needs_seven_successes(self) -> None:
        control = [self.row(premature=1, success=False)] * 10
        treatment = [self.row(success=False)] * 4 + [self.row()] * 6
        self.assertFalse(tally.decide(control, treatment)["R"])

    def test_w2_allows_one_live_turn_end(self) -> None:
        control = [self.row(premature=1)] * 10
        treatment = [self.row(live_turn_ends=[{"at": "x", "idle_seconds": 5.0}])] + [self.row()] * 9
        self.assertTrue(tally.decide(control, treatment)["W2"])
        treatment = [self.row(live_turn_ends=[{"at": "x", "idle_seconds": 5.0}])] * 2 + [self.row()] * 8
        self.assertFalse(tally.decide(control, treatment)["W2"])

    def test_unclassified_dispatches_count_against_w1(self) -> None:
        control = [self.row(premature=1)] * 10
        treatment = [self.row(dispatch_fg=8, dispatch_unclassified=2)] * 10
        self.assertFalse(tally.decide(control, treatment)["W1"])


if __name__ == "__main__":
    unittest.main()
```

(The adjudication key in `test_unadjudicated_candidate_blocks_the_decision` is `at(210)` from `synth` rendered by `datetime.isoformat()`: `2026-10-20T10:03:30+00:00`. The `Campaign` runs record `evals_commit` equal to the harness pin, so `harness_ok` returns before calling git.)

- [ ] **Step 2: Run the tests to see them fail**

Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_tally.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'tally'`.

- [ ] **Step 3: Write `tally.py`**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/tally.py
"""Tally the sdd-turn-liveness campaign against its pre-registered rule.

The rule is spec Design §2's decision rule, pre-registered in ``README.md``
before the first counted run. Inputs: ``manifest.tsv`` (the campaign pin as
two-field rows and every launch row, ``p<n>`` and replacement ``r<n>``), the
launch logs in ``logs/`` (one per launch row, written by
``logs/measure-launch.sh``), ``adjudications.tsv`` (hand labels for candidate
stops the Gauntlet-Agent's list did not match), and the runs, archived under
``task-11-runs/control/`` and ``task-12-runs/treatment/`` or still in the
clone's ``results/``. ``analyze.measure`` supplies every per-run number; this
module checks provenance, applies the void rules and counts.
"""

from __future__ import annotations

import re
import subprocess
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
EVALS = HERE.parents[1]
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import analyze

N = 10
VOID_CAP = 3
ARMS = ("control", "treatment")
SCENARIO = "sdd-turn-liveness"
ARCHIVE = {"control": HERE / "task-11-runs" / "control", "treatment": HERE / "task-12-runs" / "treatment"}
PIN_KEYS = (
    "harness", "control", "treatment", "control_root", "treatment_root", "model",
    "cc", "cc_path", "provider", "subagent_models", "codex", "task_tools",
)
HARNESS_PATHS = (
    "src", "coding-agents", "package.json", "bun.lock", "bunfig.toml", "tsconfig.json",
    "container", "scripts/evals-container", "scenarios", "fixtures",
)
RUN_ID = re.compile(r"^run-id: (\S+)$", re.MULTILINE)
TOKEN = re.compile(r"(\w+)=(\S+)")
LOG_NAME = re.compile(rf"^(control|treatment)-{SCENARIO}-([pr]\d+)\.log$")


@dataclass
class Launch:
    """One launch log: its arm, proc, header tokens, run ids and last line."""

    arm: str
    proc: str
    path: Path
    fields: dict[str, str] = field(default_factory=dict)
    run_ids: list[str] = field(default_factory=list)
    last: str = ""


def read_pins(manifest: Path) -> dict[str, str]:
    """The campaign pin: every two-field row of ``manifest.tsv``."""
    pins: dict[str, str] = {}
    for line in manifest.read_text().splitlines():
        fields = line.split("\t")
        if len(fields) == 2 and not line.startswith("#"):
            pins[fields[0]] = fields[1]
    missing = [k for k in PIN_KEYS if not pins.get(k) or "<" in pins[k]]
    if missing:
        raise ValueError(f"manifest.tsv lacks pin values for: {', '.join(missing)}")
    return pins


def read_rows(manifest: Path) -> list[tuple[str, str]]:
    """The (arm, proc) of every launch row for this scenario, in manifest order."""
    rows: list[tuple[str, str]] = []
    for line in manifest.read_text().splitlines():
        fields = line.split("\t")
        if len(fields) == 5 and fields[0] in ARMS and fields[1] == SCENARIO:
            rows.append((fields[0], fields[3]))
    return rows


def _proc_key(proc: str) -> tuple[str, int]:
    return proc[0], int(proc[1:])


def read_logs(logs: Path) -> list[Launch]:
    """Every launch log, p-rows before r-rows, then by number."""
    found: list[Launch] = []
    for path in logs.glob("*.log"):
        match = LOG_NAME.match(path.name)
        if not match:
            continue
        text = path.read_text(errors="replace")
        fields: dict[str, str] = {}
        for line in text.splitlines():
            if line.startswith(("run-id:", "$ ")):
                continue
            for key, value in TOKEN.findall(line):
                fields.setdefault(key, value)
        lines = text.rstrip("\n").splitlines()
        found.append(Launch(match.group(1), match.group(2), path, fields, RUN_ID.findall(text), lines[-1] if lines else ""))
    found.sort(key=lambda launch: _proc_key(launch.proc))
    return found


def harness_ok(commit: str | None, pin: str, repo: Path) -> bool:
    """Whether a run's evals commit is the harness pin, or descends from it with the harness paths unchanged.

    Evidence commits land between the arms (the control archive is committed
    before the treatment launches), so a treatment run's recorded commit is
    later than the pin; ``measure-launch.sh`` makes the same comparison
    before every launch.
    """
    if commit is None:
        return False
    if commit == pin:
        return True
    ancestor = subprocess.run(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor", pin, commit], capture_output=True, check=False
    )
    if ancestor.returncode != 0:
        return False
    same = subprocess.run(
        ["git", "-C", str(repo), "diff", "--quiet", pin, commit, "--", *HARNESS_PATHS], capture_output=True, check=False
    )
    return same.returncode == 0


def _record(arm: str, run_id: str, results_root: Path, archive: Mapping[str, Path]) -> Path:
    archived = archive[arm] / run_id
    return archived if (archived / "verdict.json").is_file() else results_root / run_id


def _problems(m: Mapping[str, Any], arm: str, launch: Launch, pins: Mapping[str, str], repo: Path) -> list[str]:
    problems: list[str] = []
    f = launch.fields
    if not harness_ok(m["evals_commit"], pins["harness"], repo) or m["evals_clean"] is not True:
        problems.append("harness")
    if f.get("harness_pin") != pins["harness"]:
        problems.append("harness pin")
    if m["plugin_dir"] != pins[f"{arm}_root"]:
        problems.append("root path")
    if not (f.get("root_head") == f.get("root_after_head") == pins[arm] and f.get("root_clean") == f.get("root_after_clean") == "yes"):
        problems.append("root commit")
    if m["model"] != pins["model"]:
        problems.append("model")
    if not (m["cc"] == f.get("cc_before") == f.get("cc_after") == pins["cc"]):
        problems.append("cc")
    if f.get("cc_path") != pins["cc_path"]:
        problems.append("cc path")
    if f.get("provider") != pins["provider"]:
        problems.append("provider")
    allowed = set(pins["subagent_models"].split(",")) | {pins["model"]}
    if not m["models"] or pins["model"] not in m["models"] or not set(m["models"]) <= allowed:
        problems.append("models")
    if pins["codex"] == "absent" and not m["codex_absent"]:
        problems.append("codex")
    if pins["task_tools"] == "on" and not m["task_tools"]:
        problems.append("task tools")
    return problems


def decide(control: Sequence[Mapping[str, Any]], treatment: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    """Apply W1, W2, F, U, P and R (spec Design §2) to ten counted runs per arm."""
    fg = sum(r["dispatch_fg"] for r in treatment)
    other = sum(r["dispatch_bg"] + r["dispatch_unclassified"] for r in treatment)
    share = fg / (fg + other) if fg + other else 0.0
    live = sum(len(r["live_turn_ends"]) for r in treatment)
    f_runs = sum(1 for r in treatment if r["short_ok"] and r["long_ok"])
    untracked = sum(len(r["untracked"]) for r in treatment)
    pc = sum(r["premature"] for r in control)
    pt = sum(r["premature"] for r in treatment)
    clean = sum(1 for r in treatment if r["premature"] == 0)
    p: bool | str = "unmeasured" if pc == 0 else (pt < pc and clean >= 9)
    sc = sum(1 for r in control if r["success"])
    st = sum(1 for r in treatment if r["success"])
    out: dict[str, Any] = {
        "foreground_share": round(share, 3), "W1": share >= 0.9,
        "live_turn_ends_treatment": live, "W2": live <= 1,
        "f_runs_treatment": f_runs, "F": f_runs >= 9,
        "untracked_treatment": untracked, "U": untracked == 0,
        "premature_control": pc, "premature_treatment": pt, "clean_treatment_runs": clean, "P": p,
        "success_control": sc, "success_treatment": st, "R": st >= 7 and st >= sc - 1,
    }
    passed = out["W1"] and out["W2"] and out["F"] and out["U"] and out["R"] and p in (True, "unmeasured")
    out["decision"] = "PASS" if passed else "FAIL"
    return out


def evaluate(
    manifest: Path,
    logs: Path,
    adjudications: Path | None,
    results_root: Path,
    archive: Mapping[str, Path],
    repo: Path = EVALS,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Classify every launched run and decide, or say why no decision is possible."""
    pins = read_pins(manifest)
    declared = read_rows(manifest)
    adjudicated = analyze.read_adjudications(adjudications) if adjudications else {}
    launches = read_logs(logs)
    keys = [(launch.arm, launch.proc) for launch in launches]
    reasons: list[str] = []
    if len(declared) != len(set(declared)):
        reasons.append("duplicate manifest rows")
    undeclared = sorted(set(keys) - set(declared))
    missing = sorted(set(declared) - set(keys))
    if undeclared:
        reasons.append(f"logs without a manifest row: {undeclared}")
    if missing:
        reasons.append(f"manifest rows without a log: {missing}")
    run_ids = [run_id for launch in launches for run_id in launch.run_ids]
    repeated = sorted({run_id for run_id in run_ids if run_ids.count(run_id) > 1})
    if repeated:
        reasons.append(f"run ids recorded by more than one launch: {repeated}")
    rows: list[dict[str, Any]] = []
    counted: dict[str, list[dict[str, Any]]] = {arm: [] for arm in ARMS}
    voids = {arm: 0 for arm in ARMS}
    restart = any(launch.fields.get("preflight") == "cc" for launch in launches)
    for launch in launches:
        done = launch.last.startswith("DONE ")
        if not launch.run_ids:
            # No agent started, so nothing is discarded: uncapped, like a setup
            # void, and replaced by a new r<n> row once the cause is fixed. A
            # preflight=cc refusal is the restart signal handled above.
            preflight = launch.fields.get("preflight")
            status = "restart" if preflight == "cc" else "preflight-refused" if preflight else "no-run"
            no_run = {"arm": launch.arm, "proc": launch.proc, **analyze.empty_measure(f"({launch.proc}: no run)")}
            no_run["status"] = status
            rows.append(no_run)
            continue
        for run_id in launch.run_ids:
            record = _record(launch.arm, run_id, results_root, archive)
            if (record / "verdict.json").is_file():
                m = analyze.measure(record, adjudicated)
            else:
                m = {**analyze.empty_measure(run_id), "void": "no-verdict"}
            row: dict[str, Any] = {"arm": launch.arm, "proc": launch.proc, **m}
            if not done:
                # A quorum exit outside 0-2 is a harness failure: capped like the other voids.
                voids[launch.arm] += 1
                row["status"] = "launch-failed"
            elif m["void"] == "void-setup":
                row["status"] = "void-setup"
            elif m["void"] is not None:
                voids[launch.arm] += 1
                row["status"] = m["void"]
            else:
                problems = _problems(m, launch.arm, launch, pins, repo)
                row["problems"] = problems
                if "cc" in problems:
                    row["status"] = "restart"
                    restart = True
                elif problems:
                    voids[launch.arm] += 1
                    row["status"] = "void-provenance"
                elif len(counted[launch.arm]) < N:
                    row["status"] = "counted"
                    counted[launch.arm].append(row)
                else:
                    row["status"] = "extra"
            rows.append(row)
    if restart:
        return rows, {"decision": "RESTART", "reasons": ["a run or a launch preflight saw a Claude Code version other than the pin"]}
    for arm in ARMS:
        if voids[arm] > VOID_CAP:
            reasons.append(f"{arm}: {voids[arm]} capped voids exceed the cap of {VOID_CAP}")
        if len(counted[arm]) < N:
            reasons.append(f"{arm}: {len(counted[arm])} of {N} valid runs")
    if reasons:
        return rows, {"decision": "INCOMPLETE", "reasons": reasons}
    pending = [r["run_id"] for arm in ARMS for r in counted[arm] if r["unadjudicated"]]
    if pending:
        return rows, {"decision": "UNADJUDICATED", "reasons": [f"candidates without a label in {', '.join(pending)}"]}
    return rows, decide(counted["control"], counted["treatment"])


def main() -> int:
    """Print every run's row and the decision; exit 0 on PASS or FAIL, 1 otherwise."""
    rows, decision = evaluate(HERE / "manifest.tsv", HERE / "logs", HERE / "adjudications.tsv", EVALS / "results", ARCHIVE)
    for r in rows:
        print(
            f"{r['arm']:9} {r['proc']:4} {r['run_id']} {r['status']:15} final={r['final']} "
            f"fg={r['dispatch_fg']} bg={r['dispatch_bg']} unclassified={r['dispatch_unclassified']} "
            f"live={len(r['live_turn_ends'])} short={r['short_ok']} long={r['long_ok']} "
            f"untracked={len(r['untracked'])} premature={r['premature']} unadjudicated={r['unadjudicated']} "
            f"censored={r['censored_stops']} success={r['success']} problems={','.join(r.get('problems') or []) or '-'}"
        )
    print()
    for key, value in decision.items():
        print(f"{key}: {value}")
    return 0 if decision["decision"] in ("PASS", "FAIL") else 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests, ruff and mypy**

Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_tally.py evidence/2026-10-19-sdd-turn-liveness/test_analyze.py evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` — Expected: `OK`. `test_tally` writes about 300 small run files, and file creation is slow on this host (the plan's own code took 207 s for `test_tally` alone during planning), so give this call an explicit timeout of 600000 ms.
Run: `ruff check evidence/2026-10-19-sdd-turn-liveness/ && mypy evidence/2026-10-19-sdd-turn-liveness/tally.py evidence/2026-10-19-sdd-turn-liveness/test_tally.py` — Expected: clean.
Run: `bun run check` — Expected: only the baseline failures.

- [ ] **Step 5: Commit**

```bash
git add evidence/2026-10-19-sdd-turn-liveness/tally.py evidence/2026-10-19-sdd-turn-liveness/test_tally.py
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "test(evidence): the turn-liveness campaign tally applies the pre-registered decision rule"
```

---

### Task 6: The field instrument, `field.py`

**Risk tier:** high — its output decides whether the Stop-hook follow-up opens.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/field.py`
- Test: `evals/evidence/2026-10-19-sdd-turn-liveness/test_field.py`

**Interfaces:**
- Consumes: `liveness` (Task 3).
- Produces:
  ```python
  def entrypoint(path: Path) -> str | None
  def is_sdd(records: Sequence[Record]) -> bool
  def same_skills(repo: Path, commit: str) -> Callable[[str], bool]
  def reflog_window(text: str, commit: str, same: Callable[[str], bool] | None = None) -> tuple[datetime, datetime | None]
  def collect(projects: Path, since: datetime, until: datetime) -> dict[str, Any]
  def main(argv: Sequence[str] | None = None) -> int     # --projects, --since, --until | --reflog-file + --commit [+ --repo], --out
  ```
  `collect` keys: `window`, `sessions`, `boundaries`, `premature`, `premature_resumed`, `premature_per_100`, `live_turn_ends`, `live_resumes`, `live_resumes_per_100`, `censored_stops`, `censored_resumes`, `excluded` (by reason), `cc_versions` (sessions per version), `models` (sessions per model). Numbers only: no transcript text.

**Mirror:** Task 3's module and test layout.

- [ ] **Step 1: Write the failing tests**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/test_field.py
"""Tests for field.py on synthetic transcripts."""

from __future__ import annotations

import sys
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import field
from synth import (
    AGENT_BG,
    BASH_BG,
    RELOAD_RESULT,
    assistant,
    enqueue,
    human,
    result,
    write,
)

SINCE = datetime(2026, 10, 20, 0, 0, tzinfo=UTC)
UNTIL = datetime(2026, 10, 21, 0, 0, tzinfo=UTC)
SDD = ("s1", "Skill", {"skill": "hyperpowers:subagent-driven-development"})


def session() -> list[dict[str, Any]]:
    return [
        human(0, "Execute the plan.", entrypoint="sdk-ts"),
        assistant(5, tools=[SDD]),
        result(6, "s1", "Launching skill"),
        assistant(10, tools=[("k1", "TaskCreate", {"subject": "A"})]),
        result(11, "k1", "Task #1 created successfully: A"),
        assistant(12, tools=[("k2", "TaskCreate", {"subject": "B"})]),
        result(13, "k2", "Task #2 created successfully: B"),
        assistant(100, tools=[("u1", "TaskUpdate", {"taskId": "1", "status": "completed"})]),
        result(101, "u1", "Updated task #1 status"),
        assistant(110, "Task 1 is done. Moving to Task 2."),
        human(500, "Resume"),
        assistant(510, tools=[("a1", "Agent", {"description": "Implement Task 2"})]),
        result(511, "a1", AGENT_BG),
        assistant(520, "Waiting for the implementer."),
        human(600, "Resume"),
        enqueue(700, "a1"),
        assistant(710, tools=[("b1", "Bash", {"command": "python3 -m unittest", "run_in_background": True})]),
        result(711, "b1", BASH_BG),
        assistant(720, "Started the suite."),
        human(800, "Resume"),
        assistant(850, tools=[("z1", "Bash", {"command": "ls"})]),
        result(900, "z1", RELOAD_RESULT, is_error=True),
        assistant(901, "No response requested."),
        human(902, "Resume"),
        assistant(1000, tools=[("u2", "TaskUpdate", {"taskId": "2", "status": "completed"})]),
        result(1001, "u2", "Updated task #2 status"),
        assistant(1010, "All done. Ready to merge?"),
    ]


class Collect(unittest.TestCase):
    def test_counts_one_zed_sdd_session(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            projects = Path(tmp)
            write(projects / "p1" / "zed.jsonl", session())
            cli = session()
            cli[0] = human(0, "Execute the plan.", entrypoint="cli")
            write(projects / "p1" / "cli.jsonl", cli)
            write(projects / "p2" / "nosdd.jsonl", [human(0, "hello", entrypoint="sdk-ts"), assistant(5, "Hi.")])
            out = field.collect(projects, SINCE, UNTIL)
        self.assertEqual(out["sessions"], 1)
        self.assertEqual(out["boundaries"], 2)
        self.assertEqual((out["premature"], out["premature_resumed"]), (1, 1))
        self.assertEqual((out["live_turn_ends"], out["live_resumes"]), (1, 1))
        self.assertEqual((out["censored_stops"], out["censored_resumes"]), (1, 1))
        self.assertEqual(out["excluded"], {"reload": 1})
        self.assertEqual(out["premature_per_100"], 50.0)
        self.assertEqual(out["cc_versions"], {"2.1.300": 1})

    def test_window_bounds_the_events(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            projects = Path(tmp)
            write(projects / "p1" / "zed.jsonl", session())
            early = datetime(2026, 10, 20, 10, 5, tzinfo=UTC)
            out = field.collect(projects, SINCE, early)
        self.assertEqual((out["boundaries"], out["premature"], out["live_turn_ends"]), (1, 1, 0))


class Reflog(unittest.TestCase):
    TEXT = (
        "f1fd935 HEAD@{2026-10-19T10:35:52-07:00}: checkout: moving from 37abdbc to v6.16.1\n"
        "37abdbc HEAD@{2026-10-10T20:52:53-07:00}: checkout: moving from 5bef46c to v6.16.0\n"
        "5bef46c HEAD@{2026-10-03T08:06:05-07:00}: \n"
    )

    def test_window_of_a_superseded_commit(self) -> None:
        start, end = field.reflog_window(self.TEXT, "37abdbc669ea48f92e8f248d68ddd4dd79b0a28f")
        self.assertEqual(start, datetime.fromisoformat("2026-10-10T20:52:53-07:00"))
        self.assertEqual(end, datetime.fromisoformat("2026-10-19T10:35:52-07:00"))

    def test_window_of_the_current_commit_is_open(self) -> None:
        self.assertIsNone(field.reflog_window(self.TEXT, "f1fd935cbf79898430e4aac740b547c40d9c1103")[1])

    def test_a_checkout_with_the_same_skills_keeps_the_window_open(self) -> None:
        text = (
            "f1fd935 HEAD@{2026-11-25T09:00:00-08:00}: checkout: moving from aaaaaaa to v6.18.0\n"
            "aaaaaaa HEAD@{2026-10-22T09:00:00-07:00}: checkout: moving from 37abdbc to v6.17.0\n"
            "37abdbc HEAD@{2026-10-20T09:00:00-07:00}: checkout: moving from f1fd935 to 37abdbc\n"
        )
        start, end = field.reflog_window(text, "37abdbc669ea", lambda sha: sha in {"37abdbc", "aaaaaaa"})
        self.assertEqual(start, datetime.fromisoformat("2026-10-20T09:00:00-07:00"))
        self.assertEqual(end, datetime.fromisoformat("2026-11-25T09:00:00-08:00"))
        self.assertEqual(field.reflog_window(text, "37abdbc669ea")[1], datetime.fromisoformat("2026-10-22T09:00:00-07:00"))

    def test_unknown_commit_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            field.reflog_window(self.TEXT, "0123456")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_field.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'field'`.

- [ ] **Step 3: Write `field.py`**

```python
# evals/evidence/2026-10-19-sdd-turn-liveness/field.py
"""Field instrument: SDD turn liveness in this host's Claude Code transcripts.

Spec Design §3. Reads every top-level ``*.jsonl`` transcript under a
projects directory (``~/.claude/projects`` by default) and keeps the Zed
sessions (the first record carrying ``entrypoint`` says ``sdk-ts``) that
invoke the subagent-driven-development skill. Events count when their
timestamp falls in ``[since, until)``: on this host the skill text in effect
is whatever tag ``.worktrees/plugin-install`` had checked out, which only
that worktree's reflog records (plan deviation 1), so ``--reflog-file`` and
``--commit`` turn a release into a window. The output is counts only; no
transcript text leaves this script.
"""

from __future__ import annotations

import argparse
import bisect
import json
import re
import subprocess
import sys
from collections import Counter
from collections.abc import Callable, Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from liveness import (
    Record,
    asks_or_blocks,
    blocks,
    idle_marker,
    is_resume,
    is_tool_result,
    load,
    parse_ts,
    reloads,
    result_text,
    state_at,
    tasks,
    text_of,
    tool_input,
    tool_uses,
    turn_ends,
)

ENTRYPOINT = re.compile(rb'"entrypoint"\s*:\s*"([^"]+)"')
CREATED = re.compile(r"Task #(\d+) created")
REFLOG = re.compile(r"^([0-9a-f]{7,40}) HEAD@\{([^}]+)\}", re.MULTILINE)
SDD_COMMAND = "subagent-driven-development</command-name>"


def entrypoint(path: Path) -> str | None:
    """The first ``entrypoint`` value in the transcript's first 200 lines."""
    with path.open("rb") as fh:
        for n, line in enumerate(fh):
            if n >= 200:
                break
            match = ENTRYPOINT.search(line)
            if match:
                return match.group(1).decode()
    return None


def is_sdd(records: Sequence[Record]) -> bool:
    """Whether the session invokes the subagent-driven-development skill."""
    for rec in records:
        for use in tool_uses(rec):
            inp = tool_input(use)
            if use.get("name") == "Skill" and str(inp.get("skill", "")).endswith("subagent-driven-development"):
                return True
        if rec.get("type") == "user" and SDD_COMMAND in text_of(rec):
            return True
    return False


def _open_timeline(records: Sequence[Record]) -> tuple[list[datetime], list[int]]:
    """When the count of open task-list items changed, and to what, sorted by time."""
    names: dict[str, tuple[str, dict[str, Any]]] = {}
    open_ids: set[str] = set()
    changes: list[tuple[datetime, int]] = []
    for rec in records:
        for use in tool_uses(rec):
            inp = tool_input(use)
            if isinstance(use.get("id"), str):
                names[use["id"]] = (str(use.get("name")), inp)
        if not is_tool_result(rec):
            continue
        for block in blocks(rec):
            if block.get("type") != "tool_result":
                continue
            name, inp = names.get(str(block.get("tool_use_id")), ("", {}))
            if name == "TaskCreate":
                match = CREATED.search(result_text(block))
                if match:
                    open_ids.add(match.group(1))
            elif name == "TaskUpdate":
                task_id = str(inp.get("taskId", ""))
                status = inp.get("status")
                if status in ("completed", "deleted"):
                    open_ids.discard(task_id)
                elif status in ("pending", "in_progress") and task_id:
                    open_ids.add(task_id)
            elif name == "TodoWrite":
                todos = inp.get("todos") or []
                open_ids = {k for k in open_ids if not k.startswith("todo:")} | {
                    f"todo:{i}" for i, t in enumerate(todos) if isinstance(t, dict) and t.get("status") != "completed"
                }
            else:
                continue
            changes.append((parse_ts(rec["timestamp"]), len(open_ids)))
    changes.sort(key=lambda item: item[0])
    return [when for when, _ in changes], [n for _, n in changes]


def _open_at(times: Sequence[datetime], counts: Sequence[int], at: datetime) -> bool:
    i = bisect.bisect_right(times, at)
    return i > 0 and counts[i - 1] > 0


def _session(records: Sequence[Record], since: datetime, until: datetime) -> tuple[Counter[str], set[str], set[str]]:
    counts: Counter[str] = Counter()
    task_map = tasks(records)
    reload_times = reloads(records)
    times, open_counts = _open_timeline(records)

    def inside(when: datetime) -> bool:
        return since <= when < until

    for end in turn_ends(records):
        if not inside(end.at):
            continue
        if end.excluded is not None:
            counts[f"excluded:{end.excluded}"] += 1
            continue
        state = state_at(end.at, task_map, reload_times)
        if state == "live":
            counts["live_turn_ends"] += 1
        elif state == "censored":
            counts["censored_stops"] += 1
        elif _open_at(times, open_counts, end.at) and not asks_or_blocks(end.text):
            counts["premature"] += 1
            if is_resume(end.next_human):
                counts["premature_resumed"] += 1
    versions: set[str] = set()
    models: set[str] = set()
    for rec in records:
        when = parse_ts(rec["timestamp"])
        if not inside(when):
            continue
        if rec.get("version"):
            versions.add(str(rec["version"]))
        model = (rec.get("message") or {}).get("model") if rec.get("type") == "assistant" else None
        if model:
            models.add(str(model))
        if idle_marker(rec) == "human" and is_resume(text_of(rec)):
            state = state_at(when, task_map, reload_times)
            if state == "live":
                counts["live_resumes"] += 1
            elif state == "censored":
                counts["censored_resumes"] += 1
        for use in tool_uses(rec):
            inp = tool_input(use)
            if use.get("name") == "TaskUpdate" and inp.get("status") == "completed":
                counts["boundaries"] += 1
    return counts, versions, models


def collect(projects: Path, since: datetime, until: datetime) -> dict[str, Any]:
    """Aggregate counts over every Zed SDD session with events in the window."""
    totals: Counter[str] = Counter()
    versions: Counter[str] = Counter()
    models: Counter[str] = Counter()
    sessions = 0
    for path in sorted(projects.glob("*/*.jsonl")):
        if entrypoint(path) != "sdk-ts":
            continue
        records = load(path, slim=True)
        if not is_sdd(records):
            continue
        counts, session_versions, session_models = _session(records, since, until)
        if not counts and not session_versions:
            continue
        sessions += 1
        totals.update(counts)
        versions.update(session_versions)
        models.update(session_models)
    boundaries = totals["boundaries"]

    def per100(n: int) -> float | None:
        return round(100 * n / boundaries, 2) if boundaries else None

    return {
        "window": {"since": since.isoformat(), "until": until.isoformat()},
        "sessions": sessions,
        "boundaries": boundaries,
        "premature": totals["premature"],
        "premature_resumed": totals["premature_resumed"],
        "premature_per_100": per100(totals["premature"]),
        "live_turn_ends": totals["live_turn_ends"],
        "live_resumes": totals["live_resumes"],
        "live_resumes_per_100": per100(totals["live_resumes"]),
        "censored_stops": totals["censored_stops"],
        "censored_resumes": totals["censored_resumes"],
        "excluded": {k.split(":", 1)[1]: v for k, v in sorted(totals.items()) if k.startswith("excluded:")},
        "cc_versions": dict(sorted(versions.items())),
        "models": dict(sorted(models.items())),
    }


def _same_commit(commit: str) -> Callable[[str], bool]:
    return lambda sha: commit.startswith(sha) or sha.startswith(commit)


def same_skills(repo: Path, commit: str) -> Callable[[str], bool]:
    """A predicate: does a commit carry the same ``skills/`` tree as ``commit``?

    A git error (an unknown abbreviated id, say) counts as different, which
    closes the window early rather than late.
    """
    def same(sha: str) -> bool:
        done = subprocess.run(
            ["git", "-C", str(repo), "diff", "--quiet", commit, sha, "--", "skills"], capture_output=True, check=False
        )
        return done.returncode == 0

    return same


def reflog_window(
    text: str, commit: str, same: Callable[[str], bool] | None = None
) -> tuple[datetime, datetime | None]:
    """The interval ``commit``'s skill text was in effect, from ``git reflog --date=iso-strict`` output.

    The reflog lists newest first, so the commit's first checkout is its
    highest-index entry. The interval ends at the nearest newer entry whose
    commit ``same`` rejects; by default that is any other commit, and with
    ``same_skills`` it is the first checkout with a different ``skills/``
    tree, so moving the install from a release candidate to a tag with the
    same skills does not end the window.
    """
    entries = [(sha, datetime.fromisoformat(when)) for sha, when in REFLOG.findall(text)]
    matches = [i for i, (sha, _) in enumerate(entries) if _same_commit(commit)(sha)]
    if not matches:
        raise ValueError(f"{commit} is not in the reflog")
    first = max(matches)
    keep = same or _same_commit(commit)
    for i in range(first - 1, -1, -1):
        if not keep(entries[i][0]):
            return entries[first][1], entries[i][1]
    return entries[first][1], None


def main(argv: Sequence[str] | None = None) -> int:
    """Write the aggregate JSON and print it."""
    parser = argparse.ArgumentParser(description="SDD turn liveness in Zed transcripts on this host.")
    parser.add_argument("--projects", type=Path, default=Path.home() / ".claude" / "projects")
    parser.add_argument("--since", type=datetime.fromisoformat)
    parser.add_argument("--until", type=datetime.fromisoformat)
    parser.add_argument("--reflog-file", type=Path)
    parser.add_argument("--commit")
    parser.add_argument("--repo", type=Path, help="the hyperpowers repository, to compare skills/ trees")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.reflog_file and args.commit:
        same = same_skills(args.repo, args.commit) if args.repo else None
        since, until = reflog_window(args.reflog_file.read_text(), args.commit, same)
        until = until or datetime.now(UTC)
    elif args.since and args.until:
        since, until = args.since, args.until
    else:
        parser.error("give --since and --until, or --reflog-file and --commit")
    out = collect(args.projects, since, until)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n")
    print(json.dumps(out, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests, ruff and mypy**

Run: `python3 -m unittest evidence/2026-10-19-sdd-turn-liveness/test_field.py evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` — Expected: `OK`.
Run: `ruff check evidence/2026-10-19-sdd-turn-liveness/ && mypy evidence/2026-10-19-sdd-turn-liveness/field.py evidence/2026-10-19-sdd-turn-liveness/test_field.py` — Expected: clean.
Run: `bun run check` — Expected: only the baseline failures.

- [ ] **Step 5: Commit**

```bash
git add evidence/2026-10-19-sdd-turn-liveness/field.py evidence/2026-10-19-sdd-turn-liveness/test_field.py
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "test(evidence): the field instrument counts SDD turn liveness in Zed transcripts by time window"
```

---

### Task 7: The field baseline

**Risk tier:** high — it writes the durable baseline the field decision rule compares against.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/field/run-baseline.sh`
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/field/baseline.json`, `field/baseline.txt`, `field/reflog-plugin-install.txt`

**Interfaces:**
- Consumes: `field.py` (Task 6).
- Produces: the baseline numbers Task 10 copies into the evidence notes; the saved reflog the after-window follow-up reads.

- [ ] **Step 1: Write the baseline script**

`evals/evidence/2026-10-19-sdd-turn-liveness/field/run-baseline.sh`:

```bash
#!/usr/bin/env bash
# Records the field baseline (spec Design §3): every Zed SDD session event from
# 2026-07-01 up to now, which is before any 6.17.0 install, plus the
# plugin-install worktree's reflog for the after-window. Counts only.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
until="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install reflog --date=iso-strict HEAD > "$here/reflog-plugin-install.txt"
python3 "$here/../field.py" --since 2026-07-01T00:00:00+00:00 --until "$until" --out "$here/baseline.json" > "$here/baseline.txt"
echo "baseline window ends $until" >> "$here/baseline.txt"
```

- [ ] **Step 2: Run it**

Run (tracked background, timeout 3600000; it reads several gigabytes): `bash evidence/2026-10-19-sdd-turn-liveness/field/run-baseline.sh`
Expected: `baseline.json` with `sessions` ≥ 10 and `boundaries` > 0; `baseline.txt` ends with the window line. If `sessions` is below 10 or `boundaries` is 0, stop and report: the classifier disagrees with the investigation's 14 sessions, which is a defect to fix in Task 6's module before any campaign.

- [ ] **Step 3: Check the output carries no text**

Run: `python3 -c "import json; d=json.load(open('evidence/2026-10-19-sdd-turn-liveness/field/baseline.json')); assert set(d) == {'window','sessions','boundaries','premature','premature_resumed','premature_per_100','live_turn_ends','live_resumes','live_resumes_per_100','censored_stops','censored_resumes','excluded','cc_versions','models'}, set(d); print('keys ok')"`
Expected: `keys ok`.

- [ ] **Step 4: Commit**

```bash
chmod +x evidence/2026-10-19-sdd-turn-liveness/field/run-baseline.sh
git add evidence/2026-10-19-sdd-turn-liveness/field/
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "docs(evidence): the field baseline of SDD turn liveness before the change"
```

---

### Task 8: The campaign launcher, waiter and archive script

**Risk tier:** high — the launch logs it writes are the provenance the tally trusts.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/launch-all.sh`, `logs/measure-launch.sh`, `wait-done.sh`, `archive-runs.sh`
- Test: `evals/evidence/2026-10-19-sdd-turn-liveness/launch-all.test.sh`, `logs/measure-launch.test.sh`

**Interfaces:**
- Consumes: Task 5's `PIN_KEYS` and `HARNESS_PATHS` (identical values here); launch rows `arm<TAB>sdd-turn-liveness<TAB>repeat<TAB>proc<TAB>default`.
- Produces: `logs/<arm>-sdd-turn-liveness-<proc>.log` with the header tokens Task 5 reads, quorum's `run-id:` lines, last line `DONE <code>` or `FAILED <code>`; on a refused launch, a log with `preflight=<reason>` (`proxy`, `manifest`, `model`, `task_tools`, `provider`, `cc_path`, `cc`, `root`, `harness`) and last line `FAILED preflight`; `launch-all.sh` closing line `all launches finished; launchers non-zero: <n>; manifest rows without a DONE log: <m>`.

**Mirror:** `evals/evidence/2026-09-23-adoption-remediation/launch-all.sh:1-82`; `evals/evidence/2026-09-23-adoption-remediation/logs/measure-launch.sh:1-66`; `evals/evidence/2026-10-03-release-6150-paired-control/archive-runs.sh:1-40`.

- [ ] **Step 1: Write the failing launcher tests**

`logs/measure-launch.test.sh` builds a temp directory with: a manifest holding every pin; a git repo standing in for the root (one commit; its HEAD is the arm pin); a git repo standing in for the evals clone (one commit touching `src/x`; its HEAD is the harness pin); a fake `claude` (`#!/bin/sh` printing `2.1.300 (Claude Code)`), whose absolute path is the `cc_path` pin; a fake quorum script (a file whose body is `printf 'run-id: fake-1\n'; exit 1`), whose path is `QUORUM_RUN_CMD` (the launcher word-splits that variable, so it must name a script, not hold a compound command). It exports `MANIFEST`, `LOGS`, `EVALS_DIR`, `CLAUDE_BIN`, `QUORUM_RUN_CMD`, `ANTHROPIC_MODEL=claude-opus-5-5`, `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`, `CLAUDE_CODE_USE_VERTEX=1`, `HTTP_PROXY=x HTTPS_PROXY=x NO_PROXY=x`, and asserts, with a `fail()` helper and a closing `PASS:` line:

```bash
# 1. a clean launch writes the header tokens, the run id and DONE 1
bash "$script" control sdd-turn-liveness 1 p1 default || fail "clean launch exited non-zero"
log="$LOGS/control-sdd-turn-liveness-p1.log"
for needle in "root_head=$root_pin" "root_clean=yes" "cc_before=2.1.300" "cc_path=$CLAUDE_BIN" "provider=vertex" \
              "harness_pin=$harness_pin" "run-id: fake-1" "root_after_clean=yes" "cc_after=2.1.300"; do
  grep -qF -- "$needle" "$log" || fail "log lacks $needle"
done
[ "$(tail -n 1 "$log")" = "DONE 1" ] || fail "last line is not DONE 1"
# 2. a second launch of the same row refuses to overwrite its log
bash "$script" control sdd-turn-liveness 1 p1 default 2>/dev/null && fail "relaunch of p1 overwrote its log"
# 3. a model mismatch refuses, recording the reason
ANTHROPIC_MODEL=other bash "$script" control sdd-turn-liveness 1 p2 default 2>/dev/null && fail "model mismatch launched"
grep -qF "preflight=model" "$LOGS/control-sdd-turn-liveness-p2.log" || fail "p2 lacks preflight=model"
[ "$(tail -n 1 "$LOGS/control-sdd-turn-liveness-p2.log")" = "FAILED preflight" ] || fail "p2 last line"
# 4. a dirty root refuses
touch "$root/dirty"; bash "$script" control sdd-turn-liveness 1 p3 default 2>/dev/null && fail "dirty root launched"; rm "$root/dirty"
grep -qF "preflight=root" "$LOGS/control-sdd-turn-liveness-p3.log" || fail "p3 lacks preflight=root"
# 5. a Claude Code version off the pin refuses with preflight=cc (the tally's restart signal)
printf '#!/bin/sh\necho "2.1.299 (Claude Code)"\n' > "$CLAUDE_BIN"
bash "$script" control sdd-turn-liveness 1 p4 default 2>/dev/null && fail "cc mismatch launched"
grep -qF "preflight=cc" "$LOGS/control-sdd-turn-liveness-p4.log" || fail "p4 lacks preflight=cc"
printf '#!/bin/sh\necho "2.1.300 (Claude Code)"\n' > "$CLAUDE_BIN"
# 6. task tools off and a provider off the pin refuse
CLAUDE_CODE_ENABLE_TODO_TOOLS= bash "$script" control sdd-turn-liveness 1 p5 default 2>/dev/null && fail "task tools off launched"
CLAUDE_CODE_USE_VERTEX= ANTHROPIC_API_KEY=k bash "$script" control sdd-turn-liveness 1 p6 default 2>/dev/null && fail "provider mismatch launched"
grep -qF "preflight=provider" "$LOGS/control-sdd-turn-liveness-p6.log" || fail "p6 lacks preflight=provider"
# 7. a change under a harness path other than src/ refuses
(cd "$EVALS_DIR" && printf '{}\n' > tsconfig.json && git add tsconfig.json && git -c user.name=t -c user.email=t@example.com commit -qm tsconfig)
bash "$script" control sdd-turn-liveness 1 p7 default 2>/dev/null && fail "harness change launched"
grep -qF "preflight=harness" "$LOGS/control-sdd-turn-liveness-p7.log" || fail "p7 lacks preflight=harness"
```

`launch-all.test.sh` copies the template's stub-launcher test shape: a stub launcher that writes `<logs>/<arm>-<scen>-<proc>.log` ending `DONE …` (or exits 1 for one row), and asserts a malformed row stops everything, a duplicate row stops everything, a row for another scenario stops everything, a non-zero child fails the closing status, and a clean manifest ends with `launchers non-zero: 0; manifest rows without a DONE log: 0`.

Run: `bash evidence/2026-10-19-sdd-turn-liveness/logs/measure-launch.test.sh` and `bash evidence/2026-10-19-sdd-turn-liveness/launch-all.test.sh` — Expected: FAIL (scripts missing).

- [ ] **Step 2: Write `logs/measure-launch.sh`**

```bash
#!/usr/bin/env bash
# measure-launch.sh <arm> <scenario> <repeat> <proc> <budget>
# One quorum process for the sdd-turn-liveness campaign, after checking the
# campaign pin in manifest.tsv (spec Design §2): the arm's root at its pinned
# commit with a clean tree, the evals harness paths identical to the harness
# pin and clean, ANTHROPIC_MODEL equal to the model pin, the claude on PATH at
# the cc and cc_path pins, the provider pin, and the task tools on. Claims
# logs/<arm>-<scenario>-<proc>.log exclusively (a row is never relaunched into
# its old log), writes key=value header lines the tally reads, the exact
# command, quorum's output (its run-id lines), the root and Claude Code
# readings taken again after the run, and a last line DONE <code> when quorum
# exited 0, 1 or 2, else FAILED <code>. A refused launch writes
# preflight=<reason> and FAILED preflight; preflight=cc is the tally's restart
# signal. DISABLE_AUTOUPDATER=1 keeps a session from updating the shared
# Claude Code binary mid-campaign (the 2026-10-14 control saw one land).
# Test overrides: MANIFEST, LOGS, EVALS_DIR, QUORUM_RUN_CMD, CLAUDE_BIN.
set -uo pipefail
arm="$1"; scen="$2"; rep="$3"; proc="$4"; budget="$5"
E="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="${MANIFEST:-$E/manifest.tsv}"
LOGS="${LOGS:-$E/logs}"
EV="${EVALS_DIR:-$(cd "$E/../.." && pwd)}"
run_cmd="${QUORUM_RUN_CMD:-bun run quorum run}"
claude_bin="${CLAUDE_BIN:-claude}"
HARNESS_PATHS="src coding-agents package.json bun.lock bunfig.toml tsconfig.json container scripts/evals-container scenarios fixtures"
case "$arm" in control|treatment) ;; *) echo "arm must be control or treatment" >&2; exit 2 ;; esac
case "$scen" in sdd-turn-liveness) ;; *) echo "scenario must be sdd-turn-liveness" >&2; exit 2 ;; esac
case "$proc" in p[0-9]|p[0-9][0-9]|r[0-9]|r[0-9][0-9]) ;; *) echo "proc must be p<n> or r<n>" >&2; exit 2 ;; esac
case "$rep" in [1-9]) ;; *) echo "repeat must be 1-9" >&2; exit 2 ;; esac
case "$budget" in default) ;; *) echo "budget must be default" >&2; exit 2 ;; esac
mkdir -p "$LOGS" || exit 1
log="$LOGS/$arm-$scen-$proc.log"
( set -C; echo "arm=$arm scenario=$scen repeat=$rep proc=$proc budget=$budget" > "$log" ) 2>/dev/null \
  || { echo "log exists or cannot be created: $log; add a new row instead" >&2; exit 1; }
refuse() {
  local reason="$1"; shift
  { echo "preflight=$reason"; echo "$*"; echo "FAILED preflight"; } >> "$log"
  echo "$*" >&2
  exit 1
}
pin() { awk -F '\t' -v key="$1" 'NF == 2 && $1 == key { print $2 }' "$MANIFEST"; }
for v in HTTP_PROXY HTTPS_PROXY NO_PROXY; do [ -n "${!v:-}" ] || refuse proxy "$v is not set in the launch environment"; done
root=$(pin "${arm}_root"); root_pin=$(pin "$arm"); harness_pin=$(pin harness)
model_pin=$(pin model); cc_pin=$(pin cc); cc_path_pin=$(pin cc_path); provider_pin=$(pin provider); tools_pin=$(pin task_tools)
for x in "$root" "$root_pin" "$harness_pin" "$model_pin" "$cc_pin" "$cc_path_pin" "$provider_pin" "$tools_pin"; do
  case "$x" in ''|*'<'*) refuse manifest "manifest.tsv is not filled in" ;; esac
done
[ "${ANTHROPIC_MODEL:-}" = "$model_pin" ] || refuse model "ANTHROPIC_MODEL is '${ANTHROPIC_MODEL:-}', the pin is '$model_pin'"
{ [ "$tools_pin" = on ] && [ "${CLAUDE_CODE_ENABLE_TODO_TOOLS:-}" = 1 ]; } || refuse task_tools "task tools pin '$tools_pin', CLAUDE_CODE_ENABLE_TODO_TOOLS '${CLAUDE_CODE_ENABLE_TODO_TOOLS:-}'"
provider_now() {
  if [ "${CLAUDE_CODE_USE_VERTEX:-}" = 1 ] && [ "${CLAUDE_CODE_USE_BEDROCK:-}" != 1 ]; then echo vertex
  elif [ "${CLAUDE_CODE_USE_BEDROCK:-}" = 1 ] && [ "${CLAUDE_CODE_USE_VERTEX:-}" != 1 ]; then echo bedrock
  elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then echo anthropic
  else echo none; fi
}
provider=$(provider_now)
[ "$provider" = "$provider_pin" ] || refuse provider "provider is '$provider', the pin is '$provider_pin'"
cc_path=$(command -v "$claude_bin") || refuse cc_path "no $claude_bin on PATH"
[ "$cc_path" = "$cc_path_pin" ] || refuse cc_path "claude resolves to '$cc_path', the pin is '$cc_path_pin'"
cc_now() { "$claude_bin" --version 2>/dev/null | awk 'NR == 1 { print $1 }'; }
cc_before=$(cc_now)
[ "$cc_before" = "$cc_pin" ] || refuse cc "claude is '$cc_before', the pin is '$cc_pin'"
root_state() {
  local head status
  head=$(git -C "$root" rev-parse HEAD) || return 1
  status=$(git -C "$root" status --short) || return 1
  if [ -z "$status" ]; then echo "$head yes"; else echo "$head no"; fi
}
state=$(root_state) || refuse root "git failed in $root"
root_head=${state% *}; root_clean=${state#* }
{ [ "$root_head" = "$root_pin" ] && [ "$root_clean" = yes ]; } || refuse root "$arm root is at $root_head (clean: $root_clean), the pin is $root_pin"
cd "$EV" || refuse harness "cannot cd to $EV"
git cat-file -e "$harness_pin^{commit}" 2>/dev/null || refuse harness "harness pin $harness_pin does not resolve"
# shellcheck disable=SC2086
git diff --quiet "$harness_pin" HEAD -- $HARNESS_PATHS || refuse harness "harness paths differ from $harness_pin"
# shellcheck disable=SC2086
harness_status=$(git status --short -- $HARNESS_PATHS) || refuse harness "git status failed in $EV"
[ -z "$harness_status" ] || refuse harness "harness paths have uncommitted changes"
export SUPERPOWERS_ROOT="$root" DISABLE_AUTOUPDATER=1
{
  echo "root=$root root_head=$root_head root_clean=$root_clean"
  echo "harness_pin=$harness_pin evals_head=$(git rev-parse HEAD) harness_paths_identical=yes cc_path=$cc_path provider=$provider"
  echo "model=$ANTHROPIC_MODEL cc_before=$cc_before task_tools=$CLAUDE_CODE_ENABLE_TODO_TOOLS"
  echo "started=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "\$ $run_cmd scenarios/$scen --coding-agent claude-auto --repeat $rep"
  # shellcheck disable=SC2086
  $run_cmd "scenarios/$scen" --coding-agent claude-auto --repeat "$rep"
  code=$?
  after=$(root_state) || after="unknown unknown"
  echo "root_after_head=${after% *} root_after_clean=${after#* } cc_after=$(cc_now) finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  case "$code" in 0|1|2) echo "DONE $code" ;; *) echo "FAILED $code" ;; esac
} >> "$log" 2>&1
last=$(tail -n 1 "$log")
case "$last" in "DONE "*) exit 0 ;; *) exit 1 ;; esac
```

- [ ] **Step 3: Write `launch-all.sh`, `wait-done.sh` and `archive-runs.sh`**

`launch-all.sh <manifest.tsv> [max-concurrent]`: copy `evidence/2026-09-23-adoption-remediation/launch-all.sh` whole, then make exactly these changes: the two-field key list `harness|control|treatment|model` becomes `harness|control|treatment|control_root|treatment_root|model|cc|cc_path|provider|subagent_models|codex|task_tools`; the scenario must be `sdd-turn-liveness` (a malformed-row error otherwise); `repeat` accepts `[1-9]`; `proc` accepts `p<n>` and `r<n>`; the header comment names this campaign and spec Design §2. `LOGS` is passed through to the launcher.

`wait-done.sh <file> <iterations>`:

```bash
#!/usr/bin/env bash
# wait-done.sh <file> <iterations>
# A bounded foreground wait for a detached launcher's closing line: checks
# <file> every 60 s, at most <iterations> times (9 fits one 600000 ms call).
# Exit 0 when the closing line is there, 3 when the bound is reached first,
# 1 on a read error, so a failure the loop cannot parse is never read as
# "not done yet".
set -uo pipefail
file="$1"; n="$2"
case "$n" in ''|*[!0-9]*) echo "iterations must be a positive integer" >&2; exit 2 ;; esac
i=0
while [ "$i" -lt "$n" ]; do
  if [ -e "$file" ]; then
    last=$(tail -n 1 "$file") || { echo "cannot read $file" >&2; exit 1; }
    case "$last" in "all launches finished;"*) echo "$last"; exit 0 ;; esac
  fi
  i=$((i + 1))
  sleep 60
done
echo "still running after $n checks; last line: $(tail -n 1 "$file" 2>/dev/null)"
exit 3
```

`archive-runs.sh <arm> <task-dir>`: adapted from `evidence/2026-10-03-release-6150-paired-control/archive-runs.sh:1-40` for the relocated layout, reading logs from `${LOGS:-<evidence dir>/logs}`. For every run id in `<logs>/<arm>-sdd-turn-liveness-*.log` (`sed -n 's/^run-id: \([^ ]*\)$/\1/p'`): copy `results/<id>/` to `<task-dir>/<arm>/<id>.partial/` and `results/workspaces/<id>/` to `<task-dir>/<arm>/workspaces/<id>.partial/`; run `scripts/strip-runs --results-root <task-dir>/<arm> --run <id>.partial --min-age-minutes 0`; rename `workspaces/<id>.partial/coding-agent-workdir/.git` to `git-dir`; remove `workspaces/<id>.partial/home/.claude/plugins` and `home/.codex`, browser profiles (`home/.tmp/cdp-*`), and `node_modules`, `__pycache__`, `.ruff_cache`, `.mypy_cache` directories; keep `home/.cache/hyperpowers` (an SDD ledger that survived, which `analyze.py` reads beside the transcript's ledger writes); rename both `.partial` directories into place. A run already archived is skipped; a named run without `verdict.json` stops the script. `results/` is copied, never moved.

- [ ] **Step 4: Run the tests and shellcheck**

Run: `bash evidence/2026-10-19-sdd-turn-liveness/logs/measure-launch.test.sh` — Expected: `PASS:` line.
Run: `bash evidence/2026-10-19-sdd-turn-liveness/launch-all.test.sh` — Expected: `PASS:` line.
Run: `shellcheck evidence/2026-10-19-sdd-turn-liveness/*.sh evidence/2026-10-19-sdd-turn-liveness/logs/*.sh evidence/2026-10-19-sdd-turn-liveness/field/*.sh evidence/2026-10-19-sdd-turn-liveness/elicitation/*.sh` — Expected: clean.
Run: `bun run check` — Expected: only the baseline failures.

- [ ] **Step 5: Commit**

```bash
chmod +x evidence/2026-10-19-sdd-turn-liveness/*.sh evidence/2026-10-19-sdd-turn-liveness/logs/*.sh
git add evidence/2026-10-19-sdd-turn-liveness/launch-all.sh evidence/2026-10-19-sdd-turn-liveness/launch-all.test.sh evidence/2026-10-19-sdd-turn-liveness/wait-done.sh evidence/2026-10-19-sdd-turn-liveness/archive-runs.sh evidence/2026-10-19-sdd-turn-liveness/logs/measure-launch.sh evidence/2026-10-19-sdd-turn-liveness/logs/measure-launch.test.sh
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git commit -m "test(evidence): the turn-liveness campaign launcher checks every pin and logs the provenance the tally reads"
```

---

### Task 9: Smoke runs, one per arm

**Risk tier:** high — it may repair the scenario, the fixture or the analyzers before anything is pinned.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/manifest-smoke.tsv`, `logs-smoke/`, `task-9-runs/smoke/`, `smoke.md`

**Interfaces:**
- Consumes: Tasks 2, 4 and 8; the hyperpowers commit from Task 1.
- Produces: the treatment root; a validated scenario. Any fix this task makes to the scenario, fixture or analyzers lands here, with tests, before Task 10 pins anything.

`Assumption: one full SDD run of the scenario fits in quorum_max_time 150m, validate via both smoke runs' durations, before Task 10.`

- [ ] **Step 1: Create the treatment root**

Run: `git -C /Users/johnss51/Development/agents/hyperpowers worktree add --detach /Users/johnss51/.cache/hyperpowers/sdd-turn-liveness/hp-treatment <Task 1's commit>` (read it from the ledger, or `git -C /Users/johnss51/Development/agents/hyperpowers rev-parse sdd-turn-liveness` before any later hyperpowers commit). Confirm `git -C <root> status --short` is empty.

- [ ] **Step 2: Write the smoke manifest and launch**

`manifest-smoke.tsv` holds every pin key with current values: `harness` = `git rev-parse HEAD` in the evals worktree (commit everything first), `control`/`treatment` = each root's HEAD, the two roots' paths, `model claude-opus-5-5`, `cc` = `claude --version | awk '{print $1}'`, `cc_path` = `command -v claude`, `provider vertex`, `subagent_models claude-opus-5-5,claude-sonnet-5-5,claude-haiku-5-5`, `codex absent`, `task_tools on`; and two launch rows `control sdd-turn-liveness 1 p1 default`, `treatment sdd-turn-liveness 1 p1 default`.

Launch detached (unsandboxed), with the session environment set:

```bash
cd /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-turn-liveness
export ANTHROPIC_MODEL=claude-opus-5-5 CLAUDE_CODE_ENABLE_TODO_TOOLS=1
mkdir -p evidence/2026-10-19-sdd-turn-liveness/logs-smoke
LOGS="$PWD/evidence/2026-10-19-sdd-turn-liveness/logs-smoke" \
  nohup bash evidence/2026-10-19-sdd-turn-liveness/launch-all.sh evidence/2026-10-19-sdd-turn-liveness/manifest-smoke.tsv 2 \
  > evidence/2026-10-19-sdd-turn-liveness/logs-smoke/campaign.out 2>&1 &
```

Watch with `bash evidence/2026-10-19-sdd-turn-liveness/wait-done.sh evidence/2026-10-19-sdd-turn-liveness/logs-smoke/campaign.out 9` in foreground calls (timeout 600000), repeating until exit 0, at most 20 calls; on the bound, report the last line.

- [ ] **Step 3: Analyze both runs**

Run: `python3 evidence/2026-10-19-sdd-turn-liveness/analyze.py results/<control run> results/<treatment run>` for the two run ids in `logs-smoke/`.
Expected, and each item recorded in `smoke.md`:
- both sessions finished inside `quorum_max_time` (150 minutes, read from the Gauntlet result's timestamps; the two soak post-checks then add about 16 minutes), and both soak post-checks recorded a result;
- `cc`, `model`, `plugin_dir`, `task_tools` and `codex_absent` read as pinned, and the models are non-empty and inside the allowed set;
- `ledger_marks` lists every task the transcript shows the controller marking complete, and `plan_complete` matches (the ledger file itself is normally gone: SDD's Finish deletes the workspace);
- the Gauntlet-Agent's result has a `STOP:` list (`STOP: none` counts) and every candidate is labelled or listed for adjudication;
- `short_runs` and `long_runs` each found the controller's main-session executions, and the treatment's long run shows its foreground watch.

If an item fails because of the scenario, the fixture or the analyzers, fix it with a test in the same file family, rerun the smoke for the affected arm on a new row (`p2` in `manifest-smoke.tsv`), and record both attempts. A failure of the agent's behavior (for example, the treatment controller backgrounding a dispatch) is data, not a defect: record it and change nothing for it.

- [ ] **Step 4: Archive and commit**

Run: `LOGS=evidence/2026-10-19-sdd-turn-liveness/logs-smoke bash evidence/2026-10-19-sdd-turn-liveness/archive-runs.sh control evidence/2026-10-19-sdd-turn-liveness/task-9-runs/smoke`, then the same for `treatment`. Stage per `evidence/README.md` "Before committing a run" (`git add -f` for `gauntlet-agent/results/` and `home/.claude/` and `home/.cache/hyperpowers/`), post-check, leak scan, `bun run check`, commit `test(evidence): one uncounted smoke run per arm of sdd-turn-liveness`.

---

### Task 10: Pre-registration

**Risk tier:** high — it writes the campaign pin every launch checks and the pre-registration the tally implements, durable records trusted downstream.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/README.md`, `manifest.tsv`, `adjudications.tsv` (header only)
- Create (hyperpowers worktree): `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md`

**Interfaces:**
- Consumes: the field baseline (Task 7), the smoke outcome (Task 9).
- Produces: the campaign pin every Task 11 and 12 launch checks; the pre-registered rule the tally implements.

- [ ] **Step 1: Fill `manifest.tsv`**

Two-field rows with real values, computed now: `harness` = the evals worktree `HEAD` (Task 9's last commit; this task commits only evidence and docs, outside the harness paths); `control`, `treatment` = the two roots' HEADs; `control_root`, `treatment_root` = their paths; `model claude-opus-5-5`; `cc` = `claude --version | awk '{print $1}'`; `cc_path` = `command -v claude`; `provider vertex`; `subagent_models claude-opus-5-5,claude-sonnet-5-5,claude-haiku-5-5`; `codex absent`; `task_tools on`. Then the launch rows: `control sdd-turn-liveness 1 p1 default` … `p10`, and the same ten for `treatment`.

- [ ] **Step 2: Write `README.md`**

Sections, in this order (the shape of `evidence/2026-10-03-release-6150-paired-control/README.md`):
- **Question:** does the SDD text change (hyperpowers treatment pin) remove premature mid-plan stops and background waits against 6.16.1 (control pin), without lowering run success?
- **Pre-registration:** written before the first counted run; this file's commit time is the record. The decision rule, copied verbatim from the spec's Design §2 "Decision rule" (W1, W2, F, U, P, R and the pass condition); the measure definitions (Task 4's `analyze.py` docstring and plan deviations 2 and 3: foreground dispatch needs the explicit `run_in_background: false` and a clean result, the long job needs a foreground watch that saw `exit=0`, the short soak's result at least 200 s after its call and the long job's watch result at least 600 s after its launch, a run with a main-session write to a soak file is `soak_tampered` and not a success (deviation 6), plan completion needs all six `Task N: complete` marks, from the transcript's successful ledger writes or a surviving ledger, because SDD's Finish deletes the ledger); the void rules (Global Constraints); and the adjudication procedure: every candidate the Gauntlet-Agent's `STOP:` list does not match gets one row in `adjudications.tsv`, labelled by reading the candidate's closing text in the transcript, before `tally.py` is run for the decision.
- **Analyzer pins:** `git rev-parse HEAD:evidence/2026-10-19-sdd-turn-liveness/<f>` for `liveness.py`, `analyze.py`, `tally.py`; any later change to them is a Correction with its reason, recorded before the tally it affects.
- **Field decision rule:** verbatim from spec Design §3 "Field decision rule", with the baseline numbers from `field/baseline.json` and the after-window definition from plan deviation 1.
- **Config:** the campaign pin (`manifest.tsv`), the launch commands (Task 11 Step 1 form), concurrency 5.
- **Smoke:** a pointer to `smoke.md` and `task-9-runs/smoke/`.
- **Results:** "Filled in after the treatment arm (Task 12)."

- [ ] **Step 3: Write the hyperpowers evidence note**

In the hyperpowers worktree, create `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md` in the shape of `docs/hyperpowers/2026-10-03-review-calibration-and-sentinel-scope-eval-evidence.md:1-20`: header (date, skill changed, scenario, spec and plan paths), "Where the run artifacts live" (the evals evidence directory), the pre-registered rules (pointing to the evals README for the verbatim text and restating the thresholds), the field baseline numbers, and "Scenario results", "Release" and "Zed checks" sections marked as filled by Tasks 12-14.

- [ ] **Step 4: Commit both**

Evals: `git add evidence/2026-10-19-sdd-turn-liveness/README.md evidence/2026-10-19-sdd-turn-liveness/manifest.tsv evidence/2026-10-19-sdd-turn-liveness/adjudications.tsv`, leak scan, `bun run check`, commit `docs(evidence): pre-register the sdd-turn-liveness campaign`.
Hyperpowers: `git add docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md`, leak scan, commit `docs(hyperpowers): pre-register the SDD turn liveness evaluation`.

---

### Task 11: The control arm

**Risk tier:** high — it writes the counted control evidence (runs, logs, adjudications) the tally decides from.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/logs/control-*.log`, `logs/campaign-control*.out`, `task-11-runs/control/`, `manifest-control*.tsv` (launch views)
- Modify: `evals/evidence/2026-10-19-sdd-turn-liveness/manifest.tsv` (replacement `r<n>` rows only), `adjudications.tsv`

**Interfaces:**
- Consumes: Task 10's pin; Task 8's scripts.
- Produces: ten valid control runs; the control premature-stop total that decides whether P is measured.

`Assumption: premature stops reproduce in a short, fresh session, validate via this arm's premature total, before Task 12. A total of 0 is not a plan conflict: P becomes unmeasured, as the spec's rule says.`

- [ ] **Step 1: Launch the ten control rows**

From the evals worktree, with `ANTHROPIC_MODEL=claude-opus-5-5 CLAUDE_CODE_ENABLE_TODO_TOOLS=1` exported, write a launch view holding the pins and only the control rows (`awk -F '\t' 'NF == 2 || $1 == "control"' evidence/2026-10-19-sdd-turn-liveness/manifest.tsv > evidence/2026-10-19-sdd-turn-liveness/manifest-control.tsv`), then launch detached (unsandboxed):
`nohup bash evidence/2026-10-19-sdd-turn-liveness/launch-all.sh evidence/2026-10-19-sdd-turn-liveness/manifest-control.tsv 5 > evidence/2026-10-19-sdd-turn-liveness/logs/campaign-control.out 2>&1 &`

Watch with `wait-done.sh … logs/campaign-control.out 9` in foreground calls of 600000 ms, at most 40 calls; on the bound, report the last line.

- [ ] **Step 2: Replace voids under the rules**

Run `python3 evidence/2026-10-19-sdd-turn-liveness/tally.py` (it prints every row; the decision reads INCOMPLETE until the treatment arm exists). For each control row with status `void-setup`, `void-grader`, `void-other`, `no-verdict`, `launch-failed`, `void-provenance`, `preflight-refused` or `no-run` (fix the refusal's cause first; the log names it), append one replacement row `control sdd-turn-liveness 1 r<n> default` to `manifest.tsv`, write a launch view of the pins plus only the new rows (`manifest-control-r<k>.tsv`), and launch it the same detached way into `logs/campaign-control-r<k>.out`, watched with `wait-done.sh`. Stop at the cap of three capped voids. A `restart` row, or a log with `preflight=cc`, stops the campaign: report to the human partner.

- [ ] **Step 3: Adjudicate and archive**

For every counted control candidate whose label is `unadjudicated`, read its closing text in the transcript and add a row to `adjudications.tsv` (`run_id`, `at`, `neither|question|blocked`, one-line note). Archive the arm: `bash evidence/2026-10-19-sdd-turn-liveness/archive-runs.sh control evidence/2026-10-19-sdd-turn-liveness/task-11-runs`. Record in the ledger: valid runs, voids by kind, control premature total, control successes.

- [ ] **Step 4: Commit**

Stage per `evidence/README.md` (including `home/.cache/hyperpowers/`), post-check, leak scan, `bun run check`, commit `test(evidence): the sdd-turn-liveness control arm, ten valid runs at v6.16.1`.

---

### Task 12: The treatment arm, the decision and the evidence notes

**Risk tier:** high — it writes the counted treatment evidence and the recorded decision the release reads.

**Files:**
- Create: `evals/evidence/2026-10-19-sdd-turn-liveness/logs/treatment-*.log`, `logs/campaign-treatment*.out`, `task-12-runs/treatment/`, `manifest-treatment*.tsv`, `tally.txt`
- Modify: `evals/evidence/2026-10-19-sdd-turn-liveness/README.md` (Results), `adjudications.tsv`, `manifest.tsv` (replacement rows only)
- Create: `evals/docs/experiments/2026-10-19-sdd-turn-liveness.md`
- Modify (hyperpowers worktree): `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md` (Scenario results)

**Interfaces:**
- Consumes: everything above.
- Produces: the decision Task 13 reads.

- [ ] **Step 1: Launch, replace voids, adjudicate, archive**

Exactly Task 11 Steps 1-3 with `treatment` in place of `control` (`manifest-treatment.tsv`, `logs/campaign-treatment.out`, `task-12-runs`).

- [ ] **Step 2: Tally**

Run: `python3 evidence/2026-10-19-sdd-turn-liveness/tally.py > evidence/2026-10-19-sdd-turn-liveness/tally.txt; echo "exit=$?" >> evidence/2026-10-19-sdd-turn-liveness/tally.txt`. Confirm the analyzer pins in README.md still match `git rev-parse HEAD:<file>`.
Expected: a `decision:` line reading PASS or FAIL. UNADJUDICATED means Step 1's adjudication is incomplete; INCOMPLETE or RESTART stops and goes to the human partner.

- [ ] **Step 3: Record the results**

- Evals README "Results": the per-arm table (valid, voids by kind, premature, live-work turn ends, foreground share, unclassified dispatches, F runs, untracked, successes), each criterion with its number and verdict, the decision, and a "Limits" list (the spec's Known limits plus anything the runs showed).
- `evals/docs/experiments/2026-10-19-sdd-turn-liveness.md` in the shape of `docs/experiments/2026-10-05-p3-control.md` (Hypothesis, Config, Run pointers, Verdict, Limits), negative results at equal billing.
- Hyperpowers evidence note "Scenario results": the same numbers and the decision, pointing at the evals paths.

- [ ] **Step 4: Commit both**

Evals: stage per `evidence/README.md` (runs, logs, `tally.txt`, README, the experiment entry), post-check, leak scan, `bun run check`, commit `test(evidence): the sdd-turn-liveness treatment arm and the pre-registered decision`.
Hyperpowers: leak scan, commit `docs(hyperpowers): the SDD turn liveness scenario results`.

---

### Task 13: The release candidate (or the hold)

**Risk tier:** high — it writes the release or hold record and the version files the tag ships.

**Files:**
- Modify (hyperpowers worktree): `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.kimi-plugin/plugin.json` (through `vrzn`), `CHANGELOG.md`
- Modify (hyperpowers worktree): `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md` (Release section)

**Interfaces:**
- Consumes: Task 12's `tally.txt` decision.
- Produces: on PASS, the bump commit Task 14 installs; on FAIL, a recorded hold, and the controller skips Task 14.

- [ ] **Step 1: Read the decision**

Read the `decision:` line of `/Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-turn-liveness/evidence/2026-10-19-sdd-turn-liveness/tally.txt`. On FAIL: write a "Release held" paragraph in the evidence note's Release section naming each failed criterion with its number (and, if P failed, that the Stop-hook follow-up opens with these runs as its evidence), leak scan, commit `docs(hyperpowers): the SDD turn liveness release is held`, and report DONE with "release held" in the concerns so the controller skips Task 14. On PASS, continue.

- [ ] **Step 2: Bump and write the release notes**

Run: `/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn -y bump minor` then `/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn get` — Expected: every location reads `6.17.0`, consistent.
Add above `## 6.16.1` in `CHANGELOG.md`, in the shape of `CHANGELOG.md:5-31`:

```markdown
## 6.17.0 (<release date>)

In Zed, SDD sessions looked idle while the plan was unfinished, and a controller sometimes ended its turn after announcing its next step.

- **SDD ends a turn mid-plan only for a blocker, a question, or named tracked work.** <the measured premature-stop result: control total against treatment total, or "not measured by the scenario (no control run stopped prematurely); the field rerun will measure it">.
- **Claude Code controllers wait in the foreground.** Implementer and reviewer subagents are dispatched with `run_in_background: false`, short covering commands run in the foreground, and a long command runs as a tracked background job watched in the foreground until it writes its exit file. <foreground share, live-work turn ends, F runs, from tally.txt>.
- **No untracked launches.** A trailing `&`, `nohup`, `setsid`, `disown` or a detaching script is forbidden; <untracked count in the treatment arm>.

  Evidence: `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md`; run artifacts in hyperpowers-evals under `evidence/2026-10-19-sdd-turn-liveness/`.
```

Every `<…>` is filled from `tally.txt` and the evals README; a bullet claims only a measure that passed.

- [ ] **Step 3: Check and commit**

Run: `bash tests/sdd/test-sdd-contract.sh` — Expected: `STATUS: PASSED`.
Write the Release section of the evidence note (the decision and the version). Leak scan, commit `chore: bump version to 6.17.0` (version files, `CHANGELOG.md`, the note).

---

### Task 14: The Zed checks (Z1, Z2) with the human partner

**Risk tier:** high — it changes the host's installed plugin and writes the release-prerequisite record the tag depends on.

**Files:**
- Modify (hyperpowers worktree): `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md` (Zed checks)

**Interfaces:**
- Consumes: Task 13's bump commit; `analyze.transcript_summary` (Task 4).
- Produces: the recorded Z1 and Z2 results, the last release prerequisite.

The implementer does the machine steps; the human partner does the Zed steps. The implementer returns NEEDS_CONTEXT twice, at Step 3 (Z1) and at Step 6 (Z2), each time with the exact instructions below. The controller relays them verbatim, collects the human partner's observations, and resumes the implementer with them.

- [ ] **Step 1: Install the candidate**

Run: `git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install checkout --detach <bump commit>`, then `claude plugin update hyperpowers@hyperpowers` (unsandboxed). Confirm `~/.claude/plugins/installed_plugins.json` shows `hyperpowers@hyperpowers` at version `6.17.0` with the bump commit as `gitCommitSha`.

- [ ] **Step 2: Prepare the Z1 repository**

Run: `rm -rf /Users/johnss51/Development/scratch/sdd-turn-liveness-z1 && mkdir -p /Users/johnss51/Development/scratch/sdd-turn-liveness-z1 && cp -R /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-turn-liveness/fixtures/sdd-turn-liveness/. /Users/johnss51/Development/scratch/sdd-turn-liveness-z1/`, then in that directory `git init -q -b main && git add -A && git -c user.name=fixture -c user.email=fixture@example.com commit -qm initial`. Record in the report the top-level transcripts already in `~/.claude/projects/-Users-johnss51-Development-scratch-sdd-turn-liveness-z1/` (`ls` of `*.jsonl` there; normally none).

- [ ] **Step 3: Hand Z1 to the human partner (NEEDS_CONTEXT)**

Return NEEDS_CONTEXT with these instructions, verbatim:
- Z1: restart Zed's agent sessions; open `/Users/johnss51/Development/scratch/sdd-turn-liveness-z1` in Zed; start a Claude agent session; send "I have a plan at plan.md, with design context in design.md. Use the hyperpowers:subagent-driven-development skill to execute it end to end."; answer questions briefly (about a worktree or branch: "use whatever the skill recommends"; about finishing: "merge back to main locally"); watch the running indicator. Report whether it stayed on from the go-ahead until the controller handed back, and whether you had to type "resume".

- [ ] **Step 4: Check Z1 from the transcript**

The Z1 transcript is the one top-level `.jsonl` in `~/.claude/projects/-Users-johnss51-Development-scratch-sdd-turn-liveness-z1/` that was not there at Step 2. If there is not exactly one, return NEEDS_CONTEXT listing the new files and asking which session was Z1.
Run: `python3 /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-turn-liveness/evidence/2026-10-19-sdd-turn-liveness/analyze.py --transcript <that file>`.
Z1 passes when the human partner saw the indicator stay on with no "resume", and the summary shows `dispatch_fg` at least 1, `plan_at` not null (the plan completed), `dispatch_bg` 0, `dispatch_unclassified` 0, `live_turn_ends_before_completion` 0, `censored_stops` 0, and no entry in `stops_before_completion` other than a question the human partner reports answering (its `heuristic` is true). A question is a hand-back under the Design §1 rule (a worktree-consent question at the start is the usual one); an entry with `heuristic` false fails Z1.

- [ ] **Step 5: Prepare the Z2 repository**

Run Step 2's commands with `sdd-turn-liveness-z2` in place of `sdd-turn-liveness-z1` (a separate directory, so its transcript and its SDD ledger are separate from Z1's), and record that project directory's existing transcripts the same way.

- [ ] **Step 6: Hand Z2 to the human partner (NEEDS_CONTEXT)**

Return NEEDS_CONTEXT with these instructions, verbatim:
- Z2: open `/Users/johnss51/Development/scratch/sdd-turn-liveness-z2` in Zed; start a new Claude agent session; send the same go-ahead as Z1 and answer questions the same way. After the controller reports at least one task complete and is running the next implementer (a running Agent call shows in the session), press Esc, then send "continue". Report what the controller did next and whether it finished the plan.

- [ ] **Step 7: Check Z2 from the ledger and the transcript**

The Z2 transcript is the one new top-level `.jsonl` in `~/.claude/projects/-Users-johnss51-Development-scratch-sdd-turn-liveness-z2/` (the same rule as Step 4). SDD's Finish deletes the ledger when the plan completes, so the evidence is the transcript's ledger writes and dispatches; if the ledger still exists (`grep -l sdd-turn-liveness-z2 ~/.cache/hyperpowers/sdd/*/plans/*/progress.md`), read it too.
Z2 passes when: the tasks the controller marked complete before the interrupt (its successful `Task <N>: complete` ledger writes before the `[Request interrupted` record) get no implementer dispatch after the interrupt (the resumed controller kept them done); the task that was running at the interrupt has a later implementer dispatch or a resume of the same agent; and a surviving ledger, if any, still holds every one of those lines.

- [ ] **Step 8: Record, or restore on failure**

Write both results in the evidence note's "Zed checks" (observations and summary numbers, no transcript text), leak scan, commit `docs(hyperpowers): the Zed checks for the SDD turn liveness release`.
On a Z failure: record it the same way, then restore the installed plugin (`git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install checkout --detach v6.16.1`, `claude plugin uninstall hyperpowers@hyperpowers`, `claude plugin install hyperpowers@hyperpowers`; confirm `installed_plugins.json` reads `6.16.1`), and report BLOCKED: the release is held.

---

## After the final review

- **Finish.** Use `hyperpowers:finishing-a-development-branch` for both branches; move the evals worktree's `results/` runs into the main checkout's `results/` before removing it. Push only when the human partner asks.
- **Tag, only if Tasks 12-14 passed.** The tag goes on the hyperpowers `main` commit the merge produced, which holds the bump, the Zed evidence and any final-review fixes. First run `git diff --quiet <treatment pin> <that commit> -- skills/`: the campaign measured the treatment pin's skill text, so if a final-review fix changed `skills/`, the shipped text is unmeasured; do not tag, and bring it to the human partner. When the diff is empty: `git tag -a v6.17.0 -m "Release v6.17.0" <that commit>`, then move `.worktrees/plugin-install` to the tag and run `claude plugin update hyperpowers@hyperpowers`.
- **Field after-window (follow-up, outside this plan).** Three weeks after release or at ten SDD sessions, whichever is later, and no later than six weeks. The window starts at the reflog entry that first checked out the bump commit (Task 14 Step 1) and ends at the first later checkout of a commit whose `skills/` tree differs from it, or now; moving the install to the tag does not end it. Save a fresh reflog (`git -C /Users/johnss51/Development/agents/hyperpowers/.worktrees/plugin-install reflog --date=iso-strict HEAD > evals/evidence/2026-10-19-sdd-turn-liveness/field/reflog-after.txt`) and run `python3 evals/evidence/2026-10-19-sdd-turn-liveness/field.py --reflog-file evals/evidence/2026-10-19-sdd-turn-liveness/field/reflog-after.txt --commit <bump commit> --repo /Users/johnss51/Development/agents/hyperpowers --out evals/evidence/2026-10-19-sdd-turn-liveness/field/after.json`; apply the pre-registered field decision rule; append the result to both notes.
