# SDD Stop Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md` (approved by the human partner on 2026-10-23). The spec is binding; where this plan and the spec disagree, the spec governs, except for the deviations listed below once the human partner has approved them at the pre-flight scan (Before Task 1, last item).

**Goal:** Make a mid-plan turn end with nothing tracked live impossible on Claude Code by construction: a Stop hook that refuses it (fail open, two consecutive refusals per plan, every decision logged), helpers that write the ledger's machine records (`sdd-state complete`, `sdd-state handback`, `tracked-job`), a receipt that survives Finish, the skill text that names them, a pre-registered ten-run campaign plus unit tests and Zed checks that prove it, the field instrument's Correction 8 and the hook-record field reader, before releasing 6.17.0.

**Architecture:** Hyperpowers first: a live probe of the session-id assumption, then the ledger-writing helpers (`sdd-state complete`/`handback`; `tracked-job` in two tasks, allocation and supervision, then waiting and stopping; the Finish receipt), then the hook in four pieces (discovery, plan state and the log; the decision table and `main`; the transcript-tail reader; the bash wrapper and registration), then the skill text and its contract needles. Evals next: the field instrument's Correction 8, the hook-record field reader, the fixture's deliberate conflict, the analyzer in two tasks (artifact readers, then measures), the tally, the launcher and archive copies with the fork-mode scenario, the pre-registration, one smoke and the fork-mode smoke T1, the ten counted runs and the decision. Last, the manual Zed checks and the release or the hold, so every branch change passes the final whole-branch review and the Codex final gate.

**Tech Stack:** bash 3.2-compatible hook wrapper and helpers (no heredocs under `hooks/`); one node ES module with `node --test` unit tests (node 26 on this host, no dependencies); bash contract and behavior suites under `tests/`; Python 3 standard library analyzers (ruff, mypy, `python3 -m unittest`) and TypeScript on Bun for the harness tests, in hyperpowers-evals.

## Deviations from the spec (proposed; the human partner decides at the pre-flight scan)

1. **Process-group isolation through bash job control, not `setsid`.** Spec Design §2 starts the command "in a new session (`setsid`, ...)". macOS ships no `setsid` (checked on this host 2026-10-23: `command -v setsid` is empty). `tracked-job run` therefore starts the child under `set -m`, which bash 3.2 and later give every background job its own process group whose id is the child's pid; the supervisor stays in its own group, which is what the design uses (`kill -- -<pgid>` from `run`; the group id held while any member lives). What `setsid` would add and job control does not: the command stays in the supervisor's session and keeps its controlling terminal, so a SIGHUP from that terminal reaches the command as well as the supervisor (the supervisor traps HUP and sweeps the group; under the Bash tool there is no terminal); the escalation signals only the child's group and never the supervisor's. Task 3's unsandboxed assertion checks the pid, pgid and session relationships.
2. **Loss of a job by the supervisor's death, read with `kill -0`, and a `lost-unswept` state the guard keeps live.** Spec Design §2 detects a lost job by the recorded pid's absence or a changed start time (`ps -o lstart=`) and sweeps a lost job's survivors by their environment fence (`ps -E`, `/proc`). Inside the Claude Code Bash sandbox, where controllers run `tracked-job wait` and `stop`, `ps` exits with "Operation not permitted" (checked 2026-10-23), and `/proc` does not exist on macOS. `wait` therefore declares `lost` only when `kill -0 <run pid>` answers "No such process" (ESRCH: the supervisor is dead) and no `exit` file appears within a two-second grace; EPERM or a live answer is `running`, whatever any timer says, so a suspended or stalled supervisor (SIGSTOP, host sleep) is never `lost`. When `ps` works, a recorded start time that no longer matches the pid's also means `lost` (a reused pid). `stop` on a lost job sweeps by the environment fence when process environments can be read (`/proc/<pid>/environ` on Linux, `ps -E` on macOS); when they cannot, it signals nothing, writes `state: lost-unswept`, and prints `status=lost-unswept pgid=<n>` (exit 7). The hook treats `running` and `lost-unswept` as live tracked shells, so a controller that cannot sweep must hand the job back (the refusal message names it) and an unsandboxed `stop` later finishes the sweep. A pid reused by an unrelated process while `ps` is unavailable reads as `running` until `stop`; that residual is stated in the skill text's `lost-unswept` sentence and in the evidence note.
3. **Terminal job lines carry their job's path.** Spec Design §2 writes the terminal line as `job <sid> <UTC-ms>: <name> exited code=<n>` (or `lost`, `stopped`), written once. The once is enforced by a key in the ledger itself rather than by a sidecar file: the line is `job <sid> <UTC-ms>: <name> exited code=<n> jobdir=<path>`, and the writer, under the workspace lock, appends only when no line for that `jobdir=` and that outcome exists. A sidecar marker would be lost on a hand-off (it is job scratch, excluded from snapshots) and raced by concurrent `wait` and `stop` calls.

## Global Constraints

- Repositories and branches: hyperpowers branch `sdd-stop-guard` in `.worktrees/sdd-stop-guard`, from `main` at the docs commit that adds the spec and this plan (its parent is the `main` tip at commit time, `d7d6883` when this plan was written); hyperpowers-evals branch `sdd-stop-guard` in the worktree `/Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-stop-guard` (the evals worktree; every evals path and command in this plan is relative to it, never to the `evals/` base checkout), from evals `main` at `63d368e72`. No commit lands on either `main` during the plan; the human partner reviews both branches at Finish and decides whether they merge. Nothing is pushed. The evals branch is merged with a real merge or a fast-forward, never a squash.
- Evidence directory for every artifact an evidence note cites: `evals/evidence/2026-10-23-sdd-stop-guard/` (committed in hyperpowers-evals). Nothing is cited from the SDD workspace. Archived runs follow `evals/evidence/README.md` "Before committing a run": `task-19-runs/smoke/`, `task-19-runs/t1/`, `task-20-runs/treatment/`, `task-21-runs/treatment/` (only under the Z4 contingency), each beside its `workspaces/` copy. The hyperpowers note is `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md`.
- Hook constraints (spec Constraints, verbatim in substance): bash wrapper plus node module, no third-party packages, no heredocs under `hooks/`, exit 0 on every path, explicit 30 s timeout in `hooks.json`, no whole-transcript reads (16 MB cap, 512 KB chunks, lines split on the newline byte and decoded whole), at most 64 candidate ledgers opened (more than 64 is `ambiguous` before any is read) and at most the newest 64 receipts read (a receipt older than those is invisible to the hook, a known limit the evidence note records; a receipt this session wrote at Finish is by construction among the newest), no reads of `out.log`. Claude Code only; every skill path works with the hook absent or disabled. `hooks-codex.json` and `hooks-cursor.json` are unchanged.
- Exact names, used identically in every task: `hooks/sdd-stop-guard`, `hooks/lib/stop-guard.mjs`, `hooks/lib/stop-guard.test.mjs`, `tests/hooks/test-sdd-stop-guard.sh`, `skills/subagent-driven-development/scripts/tracked-job`, subcommands `new`, `run`, `wait`, `stop`; `sdd-state` subcommands `complete`, `handback`; the log files `<workspace>/stop-guard.jsonl` and `<cache>/hyperpowers/stop-guard/<session_id>.jsonl`; receipts under `<cache>/hyperpowers/receipts/<workspace name>-<UTC>/` (staged as `<cache>/hyperpowers/receipts/.staging-<workspace name>-<UTC>/` until Finish succeeds; a staging whose final rename failed after the removal keeps that name and carries the marker file `FINISHED`, and only then counts as a receipt); job directories `<workspace>/jobs/<name>-<UTC>-<rand4>/` holding `meta.json`, `out.log`, `exit`, `launch.lock`, `go`, `stop-request`; `meta.json` field `state` in `allocated`, `running`, `exited`, `lost`, `lost-unswept`, `stopped`; the hook-record field reader `evidence/2026-10-19-sdd-turn-liveness/field_hook.py`.
- Decision reasons, verbatim from the spec's table and used as the log's `reason` strings: `no-ledger`, `ambiguous`, `no-plan`, `turn-too-long`, `live-agent`, `handback-line`, `handback-text`, `cap`, `log-failed`, `live-shell`, `open-tasks`, plus `hook-error` (the wrapper's line when node is missing or the module fails, and the module's own allow when a job record exists but cannot be read, with the cause in `detail`). The decision line's keys: `ts`, `session`, `decision`, `reason`, `plan`, `open`, `total`, `live`, `refusals`, `stop_hook_active`, `elapsed_ms`, and when they apply `candidates`, `matches`, `receipt`, `mirror_failed`, `detail`. The cap counts `block` lines of the plan's own authoritative log, in the order the session mirror records decisions (an authoritative line absent from the mirror is placed by its `ts`), and any `allow` from either log resets it.
- The refusal messages, verbatim. For `open-tasks`: `SDD stop guard: plan <plan path> is not finished (<state>; nothing tracked is live). Take the next step now, in this turn. If you are handing back to your human partner (a question only they can answer, a BLOCKED report, or they asked you to stop), run scripts/sdd-state handback PLAN_FILE --session <sid> --reason "<why>" and end the turn with that message.` For `live-shell`: `SDD stop guard: plan <plan path> is not finished (<state>; job(s) <names> are live). Job(s) <names> are still running: watch them in the foreground with tracked-job wait, and report a lost-unswept job to your human partner with its pgid. If you are handing back to your human partner (a question only they can answer, a BLOCKED report, or they asked you to stop), run scripts/sdd-state handback PLAN_FILE --session <sid> --reason "<why>" and end the turn with that message.` (The spec's generic first sentence says "nothing tracked is live", which a live job contradicts; this shape keeps the spec's second sentence and names the jobs in the first.) In both, `<state>` is `<open> of <total> tasks open` or `all <total> tasks complete; the final review and Finish remain`, `<sid>` is the real session id, `<names>` the job names comma-separated. The contract test pins the prefix `SDD stop guard: plan`.
- Helper status lines and exit codes (spec Design §2 plus deviation 2): `complete` prints `status=complete task=N appended=<1|0> snapshot=<sha|plain>` (0), `status=unknown-task task=N tasks=T` (2), `status=no-workspace` (2), `status=busy` (3), `status=error` (2), and usage errors exit 2 with nothing on stdout; `handback` prints `status=handback` (0), `status=no-workspace` (2), `status=busy` (3), `status=error` (2); `tracked-job new` prints `jobdir=<path>` (0), `status=busy` (3) or `status=error` (2); `run` prints `status=already-launched` (2) or `status=error` (2) on a failed launch and otherwise runs to the command's end printing nothing; `wait` prints `status=exited code=0` (0), `status=exited code=<n>` (1), `status=running` (3), `status=lost` (4), `status=not-started` (5), `status=lost-unswept pgid=<n>` (7, for a job already in that state); `stop` prints `status=stopped` (0), `status=not-running` (0), `status=busy` (3, the workspace lock could not be taken for the terminal record: nothing changed, retry), `status=stop-timeout` (6), `status=lost-unswept pgid=<n>` (7). `finish` adds `receipt=<path>` to its `finished` line.
- Ledger lines, verbatim shapes: `Task N: complete (commits <base7>..<head7>, review clean)` with `<base7>` and `<head7>` exactly seven lowercase hex digits; `handback <sid> <UTC-ms>: <text>`; `job <sid> <UTC-ms>: <name> jobdir=<path>`; `job <sid> <UTC-ms>: <name> exited code=<n> jobdir=<path>` (or `lost jobdir=<path>`, `stopped jobdir=<path>`, `lost-unswept pgid=<n> jobdir=<path>`). `<UTC-ms>` is `new Date().toISOString()` from node (for example `2026-10-23T18:57:21.123Z`).
- Pre-registered criteria, verbatim from spec Design §4, with the analyzer's names: H1 every valid run's decision record holds at least one line for the plan (`plan_decisions >= 1`: a line whose `plan` is the run's plan, not a `no-ledger` or `ambiguous` line); H2 the Gauntlet's STOP list has no `neither` entry in any valid run (`neither_listed == 0`) and every `allow` with reason `handback-text` or `handback-line` is adjudicated a genuine hand-back (`false_handbacks == 0` and `unadjudicated_allows == 0`); H3 every `block` line in the receipt's log is adjudicated as not a legitimate hand-back (`false_blocks == 0` and `unadjudicated_blocks == 0`); H4 pooled foreground dispatch share at least 0.9, no untracked launch, both slow commands handled as the rule says in at least nine runs (the short one in the foreground, the long one through `tracked-job` and watched to `exited code=0`), no turn end with only a tracked shell live; R at least seven successful runs. The scenario passes when H1 to H4 and R hold. The decision record of a run is the union of the receipt's `stop-guard.jsonl` (or, for a run that never reached Finish, the live workspace's) and the per-session mirror, keyed by `(ts, session)`; two lines with one key and different payloads are a conflict that voids the run (`void-instrument`); every Gauntlet-listed stop is matched one-to-one, in time order, to an `allow` within a minute of it, and a listed stop without a match, or without a timestamp, makes the run `void-instrument`, outside the cap, relaunched.
- Void rules carry over from `evals/evidence/2026-10-19-sdd-turn-liveness/README.md` "Void rules" (setup and transport voids uncapped; capped voids at most three), plus `void-instrument` (uncapped). Campaign pin keys carry over from that README's "Config" (`manifest.tsv`) minus `control` and `control_root`, with `treatment` the hyperpowers commit Task 10 makes and `treatment_root` `/Users/johnss51/.cache/hyperpowers/sdd-stop-guard/hp-treatment`; there is no control row. The scenario's `# claude-env:` stays `CLAUDE_CODE_ENABLE_TODO_TOOLS=1, CLAUDE_CODE_FORK_SUBAGENT=0`; T1 alone runs the fork-mode copy of the scenario.
- Zed checks (spec Design §4): Z1 a foreground Agent call keeps the prompt pending for its whole duration; Z2 Esc on a foreground subagent is recoverable through NEEDS_CONTEXT/BLOCKED without ledger loss; Z3 the Stop hook fires in a Zed session and a block keeps the prompt pending and the controller continuing; Z4 a `SendMessage`-resumed agent keeps the prompt pending. Z4's contingency is Task 21 Step 3, which re-pins the treatment and repeats the ten runs under a second manifest.
- Field Correction 8 (spec Design §5): `field.collect` bounds each qualifying session at its first in-window SDD invocation; expected baseline 14 sessions, 1434 boundaries, 296 premature stops, 20.64 per 100, 21 followed by a resume, 2211 live-work turn ends, 9 live-work resumes; superseded numbers kept beside the new ones in every record. The hook-record field reader (`field_hook.py`) is implemented and tested before release; the after-window itself is a dated follow-up (After the final review).
- Commit messages follow each repository's `type(scope): sentence` style (`feat(hooks): …`, `feat(sdd): …`, `test(sdd): …`, `docs(hyperpowers): …`, `fix(evidence): …`, `test(evidence): …`, `docs(evidence): …`); no attribution lines of any kind. Before every commit the staged diff passes `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` with `hits: 0`. No committed file carries transcript text from this host's sessions, the proxy host, the `NO_PROXY` list or the GCP project id; a resolver error in a log names the proxy host and is replaced with `<proxy-host>` before staging.
- Hyperpowers: at every hyperpowers commit `bash tests/run-offline.sh` (outside the sandbox) ends with exactly one `FAILED:` line, `FAILED: tests/brainstorm-server npm test (log: <path>)`, followed by the closing line `offline set: 1 failed (logs: <dir>)` (the worktree has no `node_modules`; recorded verbatim at Before Task 1); any other `FAILED:` line, or a closing count other than 1, is a regression; `bash tests/sdd/test-sdd-contract.sh` prints `STATUS: PASSED`. New suites join `docs/testing.md`'s table in the task that creates them.
- Evals: `bun run check` runs before every evals commit; inside the sandbox two pre-existing failures are known (recorded at Before Task 1: `provision expands a leading ~ in SUPERPOWERS_ROOT under the home dir` and `provision expands a ~-prefixed SUPERPOWERS_ROOT under HOME`, 1575 pass, 2 fail) and compared; unsandboxed the suite is green. Python files pass `ruff check` and `mypy` (both on `PATH`). Analyzer pins are recorded in the README; any change after the pre-registration is a numbered Correction recorded before the tally it affects. `tally.py` and the per-run analyzer are run from their own directory in the evals worktree (`cd /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-stop-guard/evidence/2026-10-23-sdd-stop-guard && python3 tally.py`), and only over archived runs: a run is archived and post-checked before it is adjudicated or tallied.
- Live runs (Tasks 1, 19, 20, 21) run outside the Bash sandbox: quorum's `git init` fails inside it with "Operation not permitted". Each live command is tried once inside the sandbox; on that signature it is rerun with the sandbox disabled. The campaign launcher runs detached (`nohup … &` with output to a log) because a tracked background job lives at most 2 hours; the operator watches `wait-done.sh` in foreground calls of at most 600000 ms each. Git worktree creation and removal in the evals repository also need the sandbox off (`.git/config` and `.git/worktrees` writes are refused inside it).
- Multi-command evidence steps are committed bash scripts run as `bash <script>`: the interactive shell is zsh. No `grep -q` reads from a pipe; write to a file first.
- `ps` is unavailable inside the sandbox (deviation 2): every helper test that needs process identity runs its `ps`-dependent cases only when `ps -o pid= -p $$` succeeds and prints `[SKIP]` lines otherwise; the suite's STATUS counts skips separately, and the SDD controller runs Tasks 3 and 4's suites once unsandboxed per task and records both results in the ledger and, for Task 3's pid/pgid/session assertion, in the evidence note.

## Grounding

- Hook registration and dispatch: `hooks/hooks.json:1-15` (one `SessionStart` entry, `"shell": "bash"`), `hooks/run-hook.cmd:1-4` (the bash lines of the polyglot exec `bash hooks/<name>`). Hook stdin and JSON parsing: `hooks/session-start:38-55` (`IFS= read -r -d '' -t 2 hook_input` then `node -e` to read a field). JSON escaping in bash: `hooks/session-start:17-36` (`escape_for_json`). Hook output shape: `hooks/session-start` prints one JSON object on stdout at its end.
- Hook tests: `tests/hooks/test-session-start.sh:1-45` (`TEST_ROOT=$(mktemp -d)`, `make_home`, `HOOK_STDIN` consumed per assertion, `[PASS]`/`[FAIL]` lines); the heredoc fence `tests/hooks/test-no-heredocs-in-hooks.sh:1-40` scans every file under `hooks/`.
- Node test shape: `tests/pi/test-pi-extension.mjs:1-30` (`node:test`, `node:assert/strict`, `repoRoot` from `import.meta.url`); `docs/testing.md:29` lists it as `node tests/pi/test-pi-extension.mjs`.
- State helpers: `skills/subagent-driven-development/scripts/sdd-state:17-22` (exit-code table), `:38-52` (`usage`), `:68-78` (`resolve_plan`, `ledger_path`), `:91-115` (`cmd_snapshot`: `resolve_plan`, `hp_lock "$PLAN_DIR"`, `recover_apply`, `hp_contained`, `hp_commit_paths`, `status=` lines), `:123-178` (`cmd_claim`: argument loop, `(^|[^A-Za-z0-9])Task $n: complete` test, atomic publish through `node -e renameSync`), `:595-655` (`cmd_finish`: `open_claims`, the plain backend branch, `remove_verified`, `hp_commit_paths --remove`, the `finished` line), `:659-690` (`cmd_prune` argument loop). Library: `sdd-common.sh:13-38` (`hp_cache_root`, `hp_physical_dir`, `hp_common_dir`, `hp_key`), `:55-56` (`hp_checkout_path`, `hp_plain_root`), `:75-76` (`hp_session_id`, `hp_utc_now`), `:179-231` (`hp_lock`, `hp_lock_at` with its 150-step wait, `hp_unlock`), `:240` (`hp_contained`), `:266-300` (`hp_commit_paths`), `:390-396` (`hp_write_root_files`, the state checkout's `.gitignore`), `:539` (its caller inside `hp_ensure_checkout`).
- State tests: `tests/sdd/test-sdd-state.sh:1-60` (temporary `XDG_CACHE_HOME`, `GIT_CONFIG_GLOBAL=/dev/null`, `make_repo`, `make_pair`, `run_state`), its closing `STATUS` lines (new sections go above them); `tests/sdd/test-sdd-contract.sh:1-34` (`assert_contains` over a whitespace-collapsed haystack) and its "Turn liveness" needle block (the lines between `# Turn liveness (spec 2026-10-19)` and the closing `STATUS` lines).
- EPERM-aware liveness: `skills/brainstorming/scripts/stop-server.sh:42-48` (`process_exists`: `kill -0` with only "No such process" read as dead).
- Skill text anchors in `skills/subagent-driven-development/SKILL.md`: `:19` (Continuous execution), `:21` (Tracked work only), `:76,113-114` (the process graph's snapshot node), `:349-357` (Waiting on subagents and long commands), `:358` (Dispatch the implementer), `:427` (the last dispatch bullet), `:557-562` (Rounds 1-3), `:563` (Rounds 4-5), `:695-705` (Complete the task), `:805-840` (Finish); rationalization table `common-rationalizations.md:3-4` (header) and its last two rows.
- Offline set: `docs/testing.md:23-29` (suite table), `:50-61` (the set's definition), `tests/run-offline.sh` (exits non-zero on any failure; the accepted signature is in Global Constraints).
- Release notes: `CHANGELOG.md:5-12` (`## Unreleased` already holds the portable-dossiers notes; the release task renames that heading); version files are the six `vrzn.toml` locations (`vrzn -y bump minor`).
- Evals transcript model: `evidence/2026-10-19-sdd-turn-liveness/liveness.py:33-58` (launch and completion constants), `:146-173` (`idle_marker`), `:244-272` (`tasks`, `Task.kind`), `:287` (`turn_ends`), `:355` (`state_at`), `:376-391` (`asks_or_blocks`, `APPROVAL`, `SENTENCE_END`); synthetic records `synth.py:27-105` (`assistant`, `result`, `human`, `notification`, `compact_summary`); analyzer `analyze.py:121-131` (`Call`: `tool_id`, `at`, `name`, `inp`, `result_at`, `result`, `error`), `:193-202` (`ledger_tasks`), `:221-250` (`stop_lines`, `_label`), `:400-422` (`_calls`), `:620-670` (`_untracked`), `:672-683` (`empty_measure`), `:685-838` (`_transcript_measures`), `:840-884` (`measure`); tally `tally.py:31-47` (constants, `PIN_KEYS`, `HARNESS_PATHS`), `:115-136` (`harness_ok`), `:153-182` (`_problems`), `:184-209` (`decide`), `:211-311` (`evaluate`), `:313-330` (`main`, the row format); tests `test_analyze.py`, `test_tally.py` (unittest, `sys.path` insert, `synth` builders).
- Campaign tooling: `evidence/2026-10-19-sdd-turn-liveness/launch-all.sh:1-30`, `launch-all.test.sh`, `wait-done.sh`, `logs/measure-launch.sh:1-20`, `archive-runs.sh:1-25`; the archive procedure `evals/evidence/README.md:26-56`.
- Field instrument: `evidence/2026-10-19-sdd-turn-liveness/field.py:174-200` (`collect`), `:69-79` (`is_sdd`), `test_field.py:65-161` (class `Collect`, `SINCE`, `UNTIL`, `session()`), `field/run-baseline.sh:1-20`; the README's `## Corrections` list (entries 1-7, the shape of entry 7), its baseline table (the `| Sessions | 14 |` table), its `## Question` numbers, its `## Field decision rule` paragraph "Correction owed before the after-window"; the experiment entry `evals/docs/experiments/2026-10-19-sdd-turn-liveness.md:3-11`; the hyperpowers note's table `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md:67-76`.
- Scenario and fixture: `evals/scenarios/sdd-turn-liveness/story.md:12-20` (the scripted answers), `checks.sh:1-45`; fixture `evals/fixtures/sdd-turn-liveness/plan.md:67-80` (Task 1, "Package and clocks", its Produces list), `:545-556` (Task 5, the CLI's Produces line); the plan-shape test `evals/test/setup-helpers-sdd.test.ts:57-80`; the scaffold `evals/src/setup-helpers/sdd-fixtures.ts:569-580`.
- Evidence note and experiment entry shapes: `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md:1-60`, `evals/docs/experiments/2026-10-19-sdd-turn-liveness.md:1-30`.
- Headless session recipe for the probe: `evals/evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:1-35` (empty `CLAUDE_CONFIG_DIR`, `--plugin-dir`, stripped session variables, `--output-format stream-json`).
- `none: no existing Stop hook or node hook module in this repository`; Task 6 introduces the first.
- `none: no existing process supervisor script`; Task 3 introduces `tracked-job`.
- `none: no existing reader of the hook's logs`; Task 12 introduces `field_hook.py`.

## Before Task 1

- [ ] With the human partner's approval of the spec and plan diff, commit both on hyperpowers `main` as one docs commit (`docs(hyperpowers): the SDD stop guard design and its implementation plan`), leak scan first.
- [ ] Create the hyperpowers worktree with `hyperpowers:using-git-worktrees`: branch `sdd-stop-guard` from that commit, under `.worktrees/`. Run `bash tests/sdd/test-sdd-contract.sh` and `bash tests/run-offline.sh` there (the latter outside the sandbox) and record `STATUS: PASSED` and the offline set's single `FAILED:` line with its closing `offline set: 1 failed` line in the ledger: that is the accepted signature for the rest of the plan.
- [ ] Create the evals worktree outside the sandbox: `git -C /Users/johnss51/Development/agents/hyperpowers/evals worktree add -b sdd-stop-guard /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-stop-guard main` (several minutes on this repository); verify with `git -C /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-stop-guard rev-parse --abbrev-ref HEAD` printing `sdd-stop-guard`. Run `bun run check` there inside the sandbox and record the two known failing test names in the ledger as the baseline.
- [ ] Record `ps -o pid= -p $$` inside the sandbox in the ledger (expected: "Operation not permitted"), the fact deviation 2 rests on.
- [ ] **Deviation gate.** The pre-flight scan presents the three deviations above to the human partner in the Deciding Together shape, one decision each, and records each answer in the ledger as `deviation <n>: approved` or `deviation <n>: rejected`. A rejected deviation stops the run before Task 1: the plan is repaired and re-gated, never improvised around. Tasks 3 and 4 do not start without `deviation 1: approved`, `deviation 2: approved` and `deviation 3: approved` in the ledger.

---

### Task 1: The session-id probe (Assumption 1)

**Risk tier:** standard — a live probe whose recorded result decides the hook's discovery key; no product code.

**Files:**
- Create (hyperpowers worktree): `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md` (header and a "Probe" section only; the rest is filled by Tasks 3, 11, 18, 19, 20, 21, 22)
- Create (SDD workspace, scratch): `probe/plugin/.claude-plugin/plugin.json`, `probe/plugin/hooks/hooks.json`, `probe/plugin/hooks/probe-stop`, `probe/run-probe.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the recorded answer to "does the Stop event's `session_id` equal `$CLAUDE_CODE_SESSION_ID` in the controller's shell?", which Task 6 reads: on yes, discovery matches `session <session_id>:`; on no, the plan stops here and the human partner decides the key (a plan conflict, not a value to guess).

**Mirror:** `evals/evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:1-35` for the headless session (empty config dir, `--plugin-dir`, stripped session variables).

- [ ] **Step 1: Write the probe plugin**

`probe/plugin/.claude-plugin/plugin.json`:

```json
{ "name": "stop-probe", "version": "0.0.1", "description": "records the Stop event's session id" }
```

`probe/plugin/hooks/hooks.json`:

```json
{ "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/probe-stop\"", "timeout": 10 } ] } ] } }
```

`probe/plugin/hooks/probe-stop` (no heredocs):

```bash
#!/usr/bin/env bash
# Records the Stop payload's session_id beside the shell's CLAUDE_CODE_SESSION_ID.
input=""
if [ ! -t 0 ]; then IFS= read -r -d '' -t 2 input 2>/dev/null || true; fi
sid=$(printf '%s' "$input" | node -e 'try{process.stdout.write(String(JSON.parse(require("fs").readFileSync(0,"utf8")).session_id||""))}catch(e){}' 2>/dev/null)
printf 'hook_session_id=%s env_session_id=%s\n' "$sid" "${CLAUDE_CODE_SESSION_ID:-}" >> "${STOP_PROBE_OUT:?}"
exit 0
```

- [ ] **Step 2: Write the runner**

`probe/run-probe.sh`:

```bash
#!/usr/bin/env bash
# One headless session that runs one Bash command printing $CLAUDE_CODE_SESSION_ID,
# with the probe plugin's Stop hook recording the event's session_id.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export STOP_PROBE_OUT="$here/probe.out"
: > "$STOP_PROBE_OUT"
cfg=$(mktemp -d "${TMPDIR:-/tmp}/probe-cfg.XXXXXX")
env -u CLAUDE_CODE_SESSION_ID -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT CLAUDE_CONFIG_DIR="$cfg" \
  claude -p --plugin-dir "$here/plugin" --output-format stream-json --verbose \
  'Run exactly this shell command and reply with its output only: printf "shell_session_id=%s\n" "$CLAUDE_CODE_SESSION_ID"' \
  > "$here/probe.stream.jsonl" 2> "$here/probe.err"
echo "claude rc=$?"
echo "--- probe.out"; cat "$STOP_PROBE_OUT"
echo "--- shell line from the stream"; grep -o 'shell_session_id=[0-9a-f-]*' "$here/probe.stream.jsonl" | sort -u
```

- [ ] **Step 3: Run it outside the sandbox**

Run: `bash <workspace>/probe/run-probe.sh` — Expected: `probe.out` holds one line whose `hook_session_id` equals the `shell_session_id` the model printed. If they differ, or `probe.out` is empty (the Stop hook did not fire under `-p`), stop and surface it to the human partner with both outputs: Task 6's discovery key depends on the answer.

- [ ] **Step 4: Record the result**

Create `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md` in the shape of `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md:1-25` (date, skill changed, spec and plan paths, where the artifacts live) with a `## Probe` section: the command, the Claude Code version, the three ids (hook, env, shell) with their equality stated, and the date. Leak scan, commit `docs(hyperpowers): the stop guard's session-id probe`.

---

### Task 2: `sdd-state complete` and `sdd-state handback`

**Risk tier:** high — durable-record writers under the workspace lock; `finish`'s open-claims check and the hook read what they write.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (usage block `:38-52`, the header's exit-code table `:17-22`, new `cmd_complete` and `cmd_handback` after `cmd_claim`, the dispatcher's `case`)
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh` (one function, `hp_utc_now_ms`; `hp_lock_at`'s wait bound reads `HYPERPOWERS_LOCK_WAIT_STEPS`)
- Test: `tests/sdd/test-sdd-state.sh` (a new section above the closing `STATUS` lines)

**Interfaces:**
- Consumes: `resolve_plan`, `hp_checkout_path`, `hp_lock`, `hp_unlock`, `recover_apply`, `hp_contained`, `hp_commit_paths`, `hp_session_id`, `hp_utc_now` (sdd-state and sdd-common.sh as they stand).
- Produces: `sdd-state complete PLAN_FILE N --commits <base7>..<head7> [--session SID]` and `sdd-state handback PLAN_FILE --reason "<text>" [--session SID]` with the status lines and exit codes in Global Constraints; `hp_utc_now_ms` printing `new Date().toISOString()` through node; `take_lock_or_busy` (a function in `sdd-state`: `hp_checkout_path` failure is `status=error` exit 2, lock contention is `status=busy` exit 3; `tracked-job` is a separate script and carries the same two checks inline). Task 10's skill text names both commands.

**Mirror:** `skills/subagent-driven-development/scripts/sdd-state:123-178` (`cmd_claim`: the argument loop, `resolve_plan`, `hp_lock "$PLAN_DIR"`, every write checked, `status=` lines, `hp_unlock` before each return).

The spec's Files list names `tests/sdd/test-sdd-state-complete.sh`; the repository's convention is one behavior suite per helper with each task appending its section above the closing `STATUS` lines (`tests/sdd/test-sdd-state.sh:1-8`), so these cases join that suite instead. The receipt gets its own file in Task 5 because `finish` needs a fixture of its own.

- [ ] **Step 1: Write the failing tests**

Append to `tests/sdd/test-sdd-state.sh`, above the closing `STATUS` lines, using the file's `make_repo`, `run_state` and `run_sdd_dir` helpers and a plan file with two task headings:

```bash
# --- complete and handback (stop guard, 2026-10-23) -------------------------
repo30="$TEST_ROOT/complete30"; make_repo "$repo30"
mkdir -p "$repo30/docs"; printf '# Plan\n\n### Task 1: one\n\n### Task 2: two\n' > "$repo30/docs/plan.md"
git -C "$repo30" add docs/plan.md; git -C "$repo30" commit -q -m plan
ws30=$(run_sdd_dir "$repo30" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s30: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo30" > "$ws30/progress.md"
out=$(run_state "$repo30" complete docs/plan.md 1 --commits 1111111..2222222 --session s30); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -Eq '^status=complete task=1 appended=1 snapshot=(plain|[0-9a-f]{7})$'; then pass "complete appends the canonical line and snapshots"; else fail "complete appends the canonical line and snapshots (rc=$rc: $out)"; fi
if [ "$(grep -c '^Task 1: complete (commits 1111111..2222222, review clean)$' "$ws30/progress.md")" = 1 ]; then pass "the completion line has the canonical shape"; else fail "the completion line has the canonical shape"; fi
out=$(run_state "$repo30" complete docs/plan.md 1 --commits 1111111..2222222 --session s30); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^status=complete task=1 appended=0 snapshot=' && [ "$(grep -c '^Task 1: complete' "$ws30/progress.md")" = 1 ]; then pass "a repeated complete appends nothing and still snapshots"; else fail "a repeated complete appends nothing and still snapshots (rc=$rc: $out)"; fi
out=$(run_state "$repo30" complete docs/plan.md 3 --commits 1111111..2222222 --session s30); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=unknown-task task=3 tasks=2" ]; then pass "complete refuses a task the plan does not have"; else fail "complete refuses a task the plan does not have (rc=$rc: $out)"; fi
for bad in 111111..2222222 1111111..22222222 abcdefg..1234567 1111111.2222222 1111111..2222222x; do
  out=$(run_state "$repo30" complete docs/plan.md 2 --commits "$bad" --session s30); rc=$?
  if [ "$rc" -eq 2 ] && [ -z "$out" ] && ! grep -q '^Task 2: complete' "$ws30/progress.md"; then pass "complete rejects the range '$bad'"; else fail "complete rejects the range '$bad' (rc=$rc: $out)"; fi
done
out=$(HYPERPOWERS_TEST_FAIL_SNAPSHOT=1 run_state "$repo30" complete docs/plan.md 2 --commits 3333333..4444444 --session s30); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(grep -c '^Task 2: complete' "$ws30/progress.md")" = 1 ]; then pass "a failed snapshot leaves the line and reports error"; else fail "a failed snapshot leaves the line and reports error (rc=$rc: $out)"; fi
out=$(run_state "$repo30" complete docs/plan.md 2 --commits 3333333..4444444 --session s30); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^status=complete task=2 appended=0 snapshot='; then pass "the retry after a failed snapshot succeeds without a second line"; else fail "the retry after a failed snapshot succeeds without a second line (rc=$rc: $out)"; fi
# lock contention: busy, exit 3, nothing written
lock30="$( . "$LIB"; hp_checkout_path "$repo30" ).lock"; mkdir -p "$lock30"; printf 'pid=1\n' > "$lock30/owner"
before30=$(wc -l < "$ws30/progress.md")
out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 run_state "$repo30" complete docs/plan.md 2 --commits 5555555..6666666 --session s30); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(wc -l < "$ws30/progress.md")" = "$before30" ]; then pass "complete under a held lock is busy"; else fail "complete under a held lock is busy (rc=$rc: $out)"; fi
out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 run_state "$repo30" handback docs/plan.md --reason "x" --session s30); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(wc -l < "$ws30/progress.md")" = "$before30" ]; then pass "handback under a held lock is busy"; else fail "handback under a held lock is busy (rc=$rc: $out)"; fi
rm -rf "$lock30"
out=$(run_state "$repo30" handback docs/plan.md --reason "a question only you can answer" --session s30); rc=$?
line=$(tail -n 1 "$ws30/progress.md")
if [ "$rc" -eq 0 ] && [ "$out" = "status=handback" ] && printf '%s' "$line" | grep -Eq '^handback s30 [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z: a question only you can answer$'; then pass "handback appends a millisecond-stamped line"; else fail "handback appends a millisecond-stamped line (rc=$rc: $out / $line)"; fi
out=$(cd "$repo30" && CLAUDE_CODE_SESSION_ID=s31 bash "$SDD_STATE" handback docs/plan.md --reason "stopped by your human partner"); rc=$?
if [ "$rc" -eq 0 ] && tail -n 1 "$ws30/progress.md" | grep -q '^handback s31 '; then pass "handback takes the session from CLAUDE_CODE_SESSION_ID when --session is omitted"; else fail "handback takes the session from CLAUDE_CODE_SESSION_ID when --session is omitted (rc=$rc: $out)"; fi
out=$(run_state "$repo30" complete docs/plan.md 1 --session s30); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ]; then pass "complete without --commits is a usage error"; else fail "complete without --commits is a usage error (rc=$rc: $out)"; fi
rm -rf "$ws30"
out=$(run_state "$repo30" complete docs/plan.md 1 --commits 1111111..2222222 --session s30); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=no-workspace" ]; then pass "complete without a ledger is no-workspace"; else fail "complete without a ledger is no-workspace (rc=$rc: $out)"; fi
```

(`$LIB` is the suite's existing variable for `sdd-common.sh`.)

- [ ] **Step 2: Run the suite to verify the new cases fail**

Run: `bash tests/sdd/test-sdd-state.sh 2>&1 | tail -n 20` — Expected: the new cases `[FAIL]` (usage error: unknown subcommand), the older cases unchanged.

- [ ] **Step 3: Library changes**

In `sdd-common.sh`, below `hp_utc_now` (line 76):

```bash
# Millisecond UTC for lines the stop guard compares against transcript
# timestamps; macOS date has no sub-second field, node is always present.
hp_utc_now_ms() { node -e 'process.stdout.write(new Date().toISOString())' 2>/dev/null || hp_utc_now; }
```

and in `hp_lock_at`, the wait bound `[ "$waited" -ge 150 ]` becomes `[ "$waited" -ge "${HYPERPOWERS_LOCK_WAIT_STEPS:-150}" ]`.

- [ ] **Step 4: Implement `cmd_complete` and `cmd_handback`**

After `cmd_claim` in `sdd-state`:

```bash
# take_lock_or_busy: the lock path must derive (else error, 2); contention past
# the wait is busy (3). Prints the status line itself and returns the code.
take_lock_or_busy() {
  hp_checkout_path "$PLAN_DIR" >/dev/null 2>&1 || { echo "status=error"; return 2; }
  hp_lock "$PLAN_DIR" 2>/dev/null || { echo "status=busy"; return 3; }
  return 0
}

# --- complete ----------------------------------------------------------------
# The one writer of a completion line. Idempotent: the line is appended once,
# the snapshot runs every time, so a failed snapshot is retried by calling
# complete again with the same arguments. The task number must be one of the
# plan's headings, so a controller cannot complete a task that does not exist.
cmd_complete() {
  local plan="" n="" commits="" sid="" total line out rc appended
  while [ $# -gt 0 ]; do
    case "$1" in
      --commits) [ $# -ge 2 ] || usage; commits=$2; shift 2 ;;
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      -*) usage ;;
      *) if [ -z "$plan" ]; then plan=$1; elif [ -z "$n" ]; then n=$1; else usage; fi; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$n" ] && [ -n "$commits" ] || usage
  case "$n" in ''|*[!0-9]*) usage ;; esac
  [[ "$commits" =~ ^[0-9a-f]{7}\.\.[0-9a-f]{7}$ ]] || usage
  resolve_plan "$plan"
  total=$(grep -Ec '^### Task [0-9]+:' "$PLAN") || total=0
  if ! grep -Eq "^### Task $n:" "$PLAN"; then echo "status=unknown-task task=$n tasks=$total"; return 2; fi
  take_lock_or_busy || return $?
  recover_apply || { hp_unlock; echo "status=error"; return 2; }
  if [ ! -f "$WSDIR/progress.md" ]; then hp_unlock; echo "status=no-workspace"; return 2; fi
  hp_contained "$ROOT" "plans/$WS/progress.md" || { hp_unlock; echo "status=error"; return 2; }
  line="Task $n: complete (commits $commits, review clean)"
  grep -Eq "(^|[^A-Za-z0-9])Task $n: complete" "$WSDIR/progress.md"; rc=$?
  case "$rc" in
    0) appended=0 ;;
    1) if ! printf '%s\n' "$line" >> "$WSDIR/progress.md"; then hp_unlock; echo "status=error"; return 2; fi; appended=1 ;;
    *) hp_unlock; echo "status=error"; return 2 ;;
  esac
  if [ "$BACKEND" != branch ]; then hp_unlock; echo "status=complete task=$n appended=$appended snapshot=plain"; return 0; fi
  if [ -n "${HYPERPOWERS_TEST_FAIL_SNAPSHOT:-}" ]; then hp_unlock; echo "status=error"; return 2; fi
  hp_contained "$CO" "plans/$WS" || { hp_unlock; echo "status=error"; return 2; }
  out=$(hp_commit_paths "$CO" "$BRANCH" "sdd $SLUG: Task $n complete" "plans/$WS"); rc=$?
  hp_unlock
  [ "$rc" -eq 0 ] || { echo "status=error"; return 2; }
  if [ "$out" = none ]; then out=$(git -C "$CO" rev-parse "refs/heads/$BRANCH"); fi
  echo "status=complete task=$n appended=$appended snapshot=${out:0:7}"
}

# --- handback ----------------------------------------------------------------
# The explicit hand-back the stop guard honours for the current turn: one
# millisecond-stamped line, appended under the lock, no snapshot.
cmd_handback() {
  local plan="" reason="" sid=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --reason) [ $# -ge 2 ] || usage; reason=$2; shift 2 ;;
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$reason" ] || usage
  [ -n "$sid" ] || sid=$(hp_session_id)
  [ -n "$sid" ] || { echo "sdd-state: no session id: pass --session SID" >&2; return 2; }
  case "$reason" in *$'\n'*) echo "sdd-state: --reason must be one line" >&2; return 2 ;; esac
  resolve_plan "$plan"
  take_lock_or_busy || return $?
  recover_apply || { hp_unlock; echo "status=error"; return 2; }
  if [ ! -f "$WSDIR/progress.md" ]; then hp_unlock; echo "status=no-workspace"; return 2; fi
  hp_contained "$ROOT" "plans/$WS/progress.md" || { hp_unlock; echo "status=error"; return 2; }
  if ! printf 'handback %s %s: %s\n' "$sid" "$(hp_utc_now_ms)" "$reason" >> "$WSDIR/progress.md"; then hp_unlock; echo "status=error"; return 2; fi
  hp_unlock
  echo "status=handback"
}
```

Wire both into the dispatcher's `case` (`complete) cmd_complete "$@" ;;`, `handback) cmd_handback "$@" ;;`), add them to `usage` (`'  complete PLAN_FILE N --commits BASE..HEAD [--session SID]'`, `'  handback PLAN_FILE --reason TEXT [--session SID]'`), and extend the header's exit-code comment with `complete`'s `unknown-task` (2) and both commands' `busy` (3). `usage` exits 2 with its text on stderr and nothing on stdout, which the range-rejection cases assert.

- [ ] **Step 5: Run the suites**

Run: `bash tests/sdd/test-sdd-state.sh 2>&1 | tail -n 22` — Expected: every new case `[PASS]`, `STATUS: PASSED`. Also `bash tests/sdd/test-sdd-common.sh` — Expected: `STATUS: PASSED`.

- [ ] **Step 6: Commit**

Leak scan, then `git add skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/scripts/sdd-common.sh tests/sdd/test-sdd-state.sh` and commit `feat(sdd): sdd-state complete and handback write the ledger's machine lines`.

---
### Task 3: `tracked-job new` and `tracked-job run`: allocation and the supervisor

**Risk tier:** high — process supervision, signals, and ledger writes under the lock.

**Files:**
- Create: `skills/subagent-driven-development/scripts/tracked-job` (the shared functions, `new`, `run`; `wait` and `stop` arrive in Task 4)
- Test: `tests/sdd/test-tracked-job.sh` (the `new` and `run` cases; Task 4 appends its own)
- Modify: `docs/testing.md:25` (add the suite to the `tests/sdd/` row)

**Interfaces:**
- Consumes: `sdd-common.sh` (`hp_cache_root`, `hp_plan_dir`, `hp_checkout_path`, `hp_lock`, `hp_unlock`, `hp_contained`, `hp_session_id`, `hp_utc_now_ms` from Task 2); `scripts/sdd-dir PLAN_FILE` (prints the workspace path on stdout).
- Produces: `new` and `run` with the status lines in Global Constraints; the shared functions `meta_get`, `meta_set`, `alive` (ESRCH-only death), `have_ps`, `lstart_of`, `job_dir_ok` (a real path under a workspace's `jobs/`, meta's `ledger` that workspace's, meta's `plan_dir` in the repository whose key the path carries), `ledger_append_once`, `group_alive`, `conclude` (every terminal state transition, under the workspace lock, only from an expected state) (Task 4 uses them); `meta.json` with `name`, `cwd`, `created`, `budget_ms`, `deadline`, `session`, `ledger`, `plan_dir`, `state`, and after launch `pid`, `pgid`, `run_pid`, `run_lstart` (the supervisor's start time, empty without ps), `lstart`, `command`, `launched`, and at the end `ended`, `code`, `survivors`, or `launch_error`; the files `out.log`, `exit`, `launch.lock`, `go`, `stop-request`. Task 6's hook reads `meta.json`'s `state`; Task 5's receipt copies `meta.json` and `exit`; Task 10's skill text names the commands.

**Mirror:** `skills/subagent-driven-development/scripts/sdd-state:123-178` for argument loops and `status=` lines; `skills/brainstorming/scripts/stop-server.sh:42-48` for the EPERM-aware `kill -0` test.

- [ ] **Step 1: Write the failing suite**

Create `tests/sdd/test-tracked-job.sh` with this preamble and the `new`/`run` cases (Task 4 appends the rest above the closing `STATUS` lines):

```bash
#!/usr/bin/env bash
# Behavior tests for tracked-job (stop guard, 2026-10-23). No pipefail: a
# producer's SIGPIPE under grep -q would read as a failure. Cases that need
# process identity run only where ps works (deviation 2) and print [SKIP]
# otherwise; the controller runs the suite once unsandboxed per task.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TJ="$REPO_ROOT/skills/subagent-driven-development/scripts/tracked-job"
SDD_DIR="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-dir"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
failures=0; skips=0
TEST_ROOT=$(mktemp -d) || exit 2
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 2
export XDG_CACHE_HOME="$TEST_ROOT/cache"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
cleanup() { [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"; }
trap cleanup EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }
skip() { echo "  [SKIP] $1"; skips=$((skips + 1)); }
HAVE_PS=0; ps -o pid= -p $$ >/dev/null 2>&1 && HAVE_PS=1

repo="$TEST_ROOT/repo"; git init -q -b main "$repo"
git -C "$repo" config user.name t; git -C "$repo" config user.email t@example.com
mkdir -p "$repo/docs"; printf '# Plan\n\n### Task 1: one\n' > "$repo/docs/plan.md"
git -C "$repo" add docs/plan.md; git -C "$repo" commit -q -m plan
ws=$(cd "$repo" && bash "$SDD_DIR" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s1: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
tj() { (cd "$repo" && bash "$TJ" "$@"); }
meta() { node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1]+"/meta.json","utf8"));const v=m[process.argv[2]];console.log(v===undefined||v===null?"":(typeof v==="object"?JSON.stringify(v):String(v)))' "$1" "$2"; }
newjob() { tj new docs/plan.md "$1" --budget-ms 60000 --session s1 | sed -n 's/^jobdir=//p'; }

echo "=== tracked-job new ==="
j1=$(newjob soak); j2=$(newjob soak)
if [ -d "$j1" ] && [ -d "$j2" ] && [ "$j1" != "$j2" ] && [ "$(meta "$j1" state)" = allocated ] && [ "$(meta "$j1" session)" = s1 ]; then pass "new allocates a distinct directory per launch, state allocated"; else fail "new allocates a distinct directory per launch ($j1 / $j2)"; fi
if [ "$(grep -c "^job s1 .*: soak jobdir=$j1\$" "$ws/progress.md")" = 1 ]; then pass "new appends the allocation line to the ledger"; else fail "new appends the allocation line to the ledger"; fi
case "$j1" in "$ws/jobs/soak-"*) pass "the job directory lives under the workspace's jobs/" ;; *) fail "the job directory lives under the workspace's jobs/ ($j1)" ;; esac
lockdir="$( . "$LIB"; hp_checkout_path "$repo" ).lock"; mkdir -p "$lockdir"; printf 'pid=1\n' > "$lockdir/owner"
before=$(wc -l < "$ws/progress.md"); n3=$(ls "$ws/jobs" | wc -l)
out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 tj new docs/plan.md held --budget-ms 1000 --session s1); rc=$?
rm -rf "$lockdir"
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(wc -l < "$ws/progress.md")" = "$before" ] && [ "$(ls "$ws/jobs" | wc -l)" = "$n3" ]; then pass "a new that cannot take the lock is busy, leaves no directory and appends nothing"; else fail "a new that cannot take the lock is busy, leaves no directory and appends nothing (rc=$rc: $out)"; fi
# a workspace Finish has removed (the ledger gone under the lock): nothing is created and no ledger comes back.
mv "$ws/progress.md" "$ws/progress.md.away"
out=$(tj new docs/plan.md gone --budget-ms 1000 --session s1); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -e "$ws/progress.md" ] && [ "$(ls "$ws/jobs" | wc -l)" = "$n3" ]; then pass "a new after the ledger is gone creates nothing and resurrects nothing"; else fail "a new after the ledger is gone creates nothing and resurrects nothing (rc=$rc: $out)"; fi
mv "$ws/progress.md.away" "$ws/progress.md"
out=$(tj new docs/plan.md 'bad name' --budget-ms 1000 --session s1); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ]; then pass "a name outside [A-Za-z0-9._-] is a usage error"; else fail "a name outside [A-Za-z0-9._-] is a usage error (rc=$rc: $out)"; fi

echo "=== tracked-job run ==="
tj run "$j1" -- bash -c 'echo hello; exit 0' >/dev/null 2>&1
if [ "$(cat "$j1/exit")" = 0 ] && [ "$(meta "$j1" state)" = exited ] && [ "$(meta "$j1" code)" = 0 ] && grep -q hello "$j1/out.log" && [ -n "$(meta "$j1" launched)" ] && [ -n "$(meta "$j1" ended)" ]; then pass "run records exit 0, the output and the times"; else fail "run records exit 0, the output and the times"; fi
pid1=$(meta "$j1" pid)
out=$(tj run "$j1" -- bash -c 'exit 0'); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=already-launched" ] && [ "$(meta "$j1" pid)" = "$pid1" ]; then pass "a second run on one directory is already-launched and changes nothing"; else fail "a second run on one directory is already-launched (rc=$rc: $out)"; fi
j4=$(newjob failing); tj run "$j4" -- bash -c 'exit 3' >/dev/null 2>&1
if [ "$(cat "$j4/exit")" = 3 ] && [ "$(meta "$j4" state)" = exited ]; then pass "a failing command records its code"; else fail "a failing command records its code"; fi
j5=$(newjob sig); tj run "$j5" -- bash -c 'kill -TERM $$' >/dev/null 2>&1
if [ "$(cat "$j5/exit")" = 143 ]; then pass "a command killed by TERM records 143"; else fail "a command killed by TERM records 143 ($(cat "$j5/exit" 2>/dev/null))"; fi
j6=$(newjob fence); tj run "$j6" -- bash -c 'printf "%s" "$TRACKED_JOB_DIR" > fence.txt' >/dev/null 2>&1
if [ "$(cat "$repo/fence.txt" 2>/dev/null)" = "$j6" ]; then pass "the command runs with TRACKED_JOB_DIR set to its job directory"; else fail "the command runs with TRACKED_JOB_DIR set to its job directory"; fi
# the launch barrier: a metadata write that fails kills the waiting child and leaves the job allocated.
j7=$(newjob barrier)
out=$(HYPERPOWERS_TEST_FAIL_META=1 tj run "$j7" -- bash -c 'echo ran > ran.txt'); rc=$?; sleep 1
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(meta "$j7" state)" = allocated ] && [ -n "$(meta "$j7" launch_error)" ] && [ ! -d "$j7/launch.lock" ] && [ ! -f "$repo/ran.txt" ]; then pass "a failed launch kills the barrier-held child and leaves the job allocated"; else fail "a failed launch kills the barrier-held child and leaves the job allocated (rc=$rc: $out)"; fi
tj run "$j7" -- bash -c 'exit 0' >/dev/null 2>&1
if [ "$(cat "$j7/exit" 2>/dev/null)" = 0 ]; then pass "a later run on the same directory succeeds"; else fail "a later run on the same directory succeeds"; fi
# the supervisor's own TERM: the group is swept, the result recorded, state stopped.
j8=$(newjob trapped); ( tj run "$j8" -- bash -c 'sleep 60' >/dev/null 2>&1 ) & sleep 1
kill -TERM "$(meta "$j8" run_pid)"; sleep 2
if [ "$(cat "$j8/exit" 2>/dev/null)" = 143 ] && [ "$(meta "$j8" state)" = stopped ] && ! kill -0 "$(meta "$j8" pid)" 2>/dev/null; then pass "a TERM to the supervisor sweeps the command and records the result"; else fail "a TERM to the supervisor sweeps the command and records the result (exit=$(cat "$j8/exit" 2>/dev/null), state=$(meta "$j8" state))"; fi
# path trust: a directory outside the workspace, and a symlinked job directory, are refused.
mkdir -p "$TEST_ROOT/outside"; cp "$j4/meta.json" "$TEST_ROOT/outside/"
out=$(tj run "$TEST_ROOT/outside" -- bash -c 'exit 0'); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "run refuses a job directory outside the workspace"; else fail "run refuses a job directory outside the workspace (rc=$rc: $out)"; fi
ln -s "$j4" "$ws/jobs/link-x-0000"
out=$(tj run "$ws/jobs/link-x-0000" -- bash -c 'exit 0'); rc=$?; rm -f "$ws/jobs/link-x-0000"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "run refuses a symlinked job directory"; else fail "run refuses a symlinked job directory (rc=$rc: $out)"; fi
# a legitimate job directory whose metadata names another repository: refused before any lock or write.
repo2="$TEST_ROOT/repo2"; git init -q -b main "$repo2"
j4b=$(newjob forged)
node -e 'const fs=require("fs"),p=process.argv[1]+"/meta.json",m=JSON.parse(fs.readFileSync(p,"utf8"));m.plan_dir=process.argv[2];fs.writeFileSync(p,JSON.stringify(m))' "$j4b" "$repo2"
out=$(tj run "$j4b" -- bash -c 'exit 0'); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(meta "$j4b" state)" = allocated ] && [ ! -e "$j4b/exit" ]; then pass "run refuses a job whose metadata names another repository"; else fail "run refuses a job whose metadata names another repository (rc=$rc: $out)"; fi
# process relationships (deviation 1), where ps works.
if [ "$HAVE_PS" -eq 1 ]; then
  j9=$(newjob groups); ( tj run "$j9" -- bash -c 'sleep 5' >/dev/null 2>&1 ) & sleep 1
  cpid=$(meta "$j9" pid); rpid=$(meta "$j9" run_pid)
  cpg=$(ps -o pgid= -p "$cpid" | tr -d ' '); rpg=$(ps -o pgid= -p "$rpid" | tr -d ' '); csid=$(ps -o sess= -p "$cpid" | tr -d ' '); rsid=$(ps -o sess= -p "$rpid" | tr -d ' ')
  if [ "$cpg" = "$cpid" ] && [ "$cpg" != "$rpg" ] && [ "$csid" = "$rsid" ]; then pass "the child leads its own process group inside the supervisor's session"; else fail "the child leads its own process group inside the supervisor's session (child $cpid pgid $cpg sid $csid; run $rpid pgid $rpg sid $rsid)"; fi
  printf '%s\n' "child=$cpid pgid=$cpg sid=$csid run=$rpid pgid=$rpg sid=$rsid" > "$TEST_ROOT/groups.txt"; cat "$TEST_ROOT/groups.txt"
  kill -KILL -- "-$cpg" 2>/dev/null; sleep 2
  if [ "$(cat "$j9/exit" 2>/dev/null)" = 137 ] && [ "$(meta "$j9" state)" = exited ]; then pass "a KILL to the child's group leaves the supervisor alive to record 137"; else fail "a KILL to the child's group leaves the supervisor alive to record 137 (exit=$(cat "$j9/exit" 2>/dev/null))"; fi
else
  skip "the child leads its own process group inside the supervisor's session (ps unavailable)"
  skip "a KILL to the child's group leaves the supervisor alive to record 137 (ps unavailable)"
fi

echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures, $skips skipped)"; exit 1; fi
echo "STATUS: PASSED ($skips skipped)"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/sdd/test-tracked-job.sh 2>&1 | tail -n 5` — Expected: `[FAIL]` lines (the helper does not exist), `STATUS: FAILED`.

- [ ] **Step 3: Write the helper (shared functions, `new`, `run`)**

Create `skills/subagent-driven-development/scripts/tracked-job` (mode 755). The environment knobs `TRACKED_JOB_GRACE_S` (default 5), `TRACKED_JOB_STOP_WAIT_S` (default 10), `TRACKED_JOB_PROC_ROOT` (default `/proc`, Task 4), `HYPERPOWERS_LOCK_WAIT_STEPS` and `HYPERPOWERS_TEST_FAIL_META` exist for the tests.

```bash
#!/usr/bin/env bash
# tracked-job — long commands for the SDD controller: a job directory per
# launch, a supervisor that owns the command's process group, an exit file
# written whatever the status, and ledger lines written once.
# Design: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (Design §2),
# with plan deviations 1 (bash job control instead of setsid), 2 (loss is the
# supervisor's death read with kill -0; the sweep of a lost job needs ps) and
# 3 (terminal lines carry jobdir= as their once-key).
#
# Usage:
#   tracked-job new PLAN_FILE NAME --budget-ms N [--session SID]   -> jobdir=<path>
#   tracked-job run JOBDIR -- COMMAND...                           (the tracked background command)
#   tracked-job wait JOBDIR --max-ms N                             -> status=exited code=N | running | lost | not-started | lost-unswept pgid=N
#   tracked-job stop JOBDIR                                        -> status=stopped | not-running | stop-timeout | lost-unswept pgid=N
# exit: 0 ok | 1 exited with a nonzero code | 2 usage, already-launched, error |
#       3 running, busy | 4 lost | 5 not-started | 6 stop-timeout | 7 lost-unswept
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=sdd-common.sh
. "$HERE/sdd-common.sh"
GRACE=${TRACKED_JOB_GRACE_S:-5}
STOP_WAIT=${TRACKED_JOB_STOP_WAIT_S:-10}

usage() {
  printf '%s\n' 'usage: tracked-job new PLAN_FILE NAME --budget-ms N [--session SID]' \
    '       tracked-job run JOBDIR -- COMMAND...' \
    '       tracked-job wait JOBDIR --max-ms N' \
    '       tracked-job stop JOBDIR' >&2
  exit 2
}
command -v node >/dev/null 2>&1 || { echo "tracked-job: node not found" >&2; exit 2; }

# meta_get <jobdir> <key>: one value from meta.json, empty when absent.
meta_get() {
  node -e 'try{const m=JSON.parse(require("fs").readFileSync(process.argv[1]+"/meta.json","utf8"));const v=m[process.argv[2]];process.stdout.write(v===undefined||v===null?"":(typeof v==="object"?JSON.stringify(v):String(v)))}catch(e){}' "$1" "$2"
}
# meta_set <jobdir> key=value... : atomic rewrite (temporary file, rename); a
# value given as key:=json is parsed (numbers, arrays).
meta_set() {
  local dir=$1; shift
  node -e '
    const fs=require("fs"),p=process.argv[1]+"/meta.json";
    let m={}; try{m=JSON.parse(fs.readFileSync(p,"utf8"))}catch(e){}
    for(const a of process.argv.slice(2)){const i=a.indexOf("=");let k=a.slice(0,i),v=a.slice(i+1);
      if(k.endsWith(":")){k=k.slice(0,-1);v=JSON.parse(v)} m[k]=v}
    fs.writeFileSync(p+".tmp",JSON.stringify(m,null,1)+"\n"); fs.renameSync(p+".tmp",p);' "$dir" "$@"
}
utc_ms() { hp_utc_now_ms; }
# alive <pid>: kill -0 with only "No such process" read as dead (EPERM is alive
# or unknown, which the sandbox gives for another call's process).
alive() {
  local err
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  err=$(LC_ALL=C kill -0 "$1" 2>&1) && return 0
  case "$err" in *"No such process"*) return 1 ;; *) return 0 ;; esac
}
have_ps() { ps -o pid= -p $$ >/dev/null 2>&1; }
lstart_of() { ps -o lstart= -p "$1" 2>/dev/null | sed 's/^ *//;s/ *$//'; }

# job_dir_ok <jobdir>: 0 when the directory is a real path under a hyperpowers
# workspace's jobs/ (no symlink in any component below the cache root) and its
# meta.json names that workspace's ledger. Every write and every signal is
# preceded by this check, so a crafted directory cannot steer either.
job_dir_ok() {
  local dir=$1 root rel real key
  [ -d "$dir" ] && [ -f "$dir/meta.json" ] || return 1
  root=$(hp_cache_root)
  case "$dir" in "$root"/state/*/plans/*/jobs/*|"$root"/sdd/*/plans/*/jobs/*) ;; *) return 1 ;; esac
  rel=${dir#"$root"/}
  hp_contained "$root" "$rel" 2>/dev/null || return 1
  real=$(cd "$dir" && pwd -P) || return 1
  [ "$real" = "$dir" ] || return 1
  [ "$(meta_get "$dir" ledger)" = "$(cd "$dir/../.." && pwd -P)/progress.md" ] || return 1
  # The workspace lock is taken on meta's plan_dir, so that directory must
  # belong to the repository whose key the job path carries; forged or stale
  # metadata cannot lock another repository while writing this ledger.
  key=${rel#*/}; key=${key%%/*}
  [ -d "$(meta_get "$dir" plan_dir)" ] || return 1
  [ "$(hp_key "$(meta_get "$dir" plan_dir)" 2>/dev/null)" = "$key" ] || return 1
  return 0
}
# ledger_append_once <jobdir> <text>: one job line under the workspace lock;
# the line's "jobdir=<path>" plus its outcome word is the key checked in the
# ledger before appending, so repeats and retries append nothing twice.
ledger_append_once() {
  local dir=$1 text=$2 ledger plan_dir sid outcome
  job_dir_ok "$dir" || return 1
  ledger=$(meta_get "$dir" ledger); plan_dir=$(meta_get "$dir" plan_dir); sid=$(meta_get "$dir" session)
  outcome=${text%% *}
  hp_lock "$plan_dir" 2>/dev/null || return 1
  if grep -Fq -- "$(meta_get "$dir" name) $outcome" < <(grep -F -- "jobdir=$dir" "$ledger" 2>/dev/null); then hp_unlock; return 0; fi
  if printf 'job %s %s: %s %s jobdir=%s\n' "$sid" "$(utc_ms)" "$(meta_get "$dir" name)" "$text" "$dir" >> "$ledger"; then hp_unlock; return 0; fi
  hp_unlock; return 1
}

# conclude <jobdir> <from> <to> <ledger text or ""> [key=value...]: a terminal
# transition under the workspace lock, written only while the state is still
# <from>, so concurrent wait, stop and run calls never overwrite each other's
# outcome. Prints the state in force afterwards. Exit 0 when this call wrote
# it, 2 when another writer got there first, 1 when the lock was not taken.
conclude() {
  local dir=$1 from=$2 to=$3 text=$4 cur; shift 4
  hp_lock "$(meta_get "$dir" plan_dir)" 2>/dev/null || return 1
  cur=$(meta_get "$dir" state)
  if [ "$cur" != "$from" ]; then hp_unlock; printf '%s' "$cur"; return 2; fi
  meta_set "$dir" "state=$to" "ended=$(utc_ms)" "$@" || { hp_unlock; return 1; }
  hp_unlock
  [ -z "$text" ] || ledger_append_once "$dir" "$text"
  printf '%s' "$to"
}

cmd_new() {
  local plan="" name="" budget="" sid="" ws plan_dir jobs tmp final rand n=0 created deadline
  while [ $# -gt 0 ]; do
    case "$1" in
      --budget-ms) [ $# -ge 2 ] || usage; budget=$2; shift 2 ;;
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      -*) usage ;;
      *) if [ -z "$plan" ]; then plan=$1; elif [ -z "$name" ]; then name=$1; else usage; fi; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$name" ] && [ -n "$budget" ] || usage
  case "$budget" in ''|*[!0-9]*) usage ;; esac
  case "$name" in *[!A-Za-z0-9._-]*|'') usage ;; esac
  [ -n "$sid" ] || sid=$(hp_session_id)
  [ -n "$sid" ] || { echo "tracked-job: no session id: pass --session SID" >&2; exit 2; }
  ws=$(bash "$HERE/sdd-dir" "$plan" 2>/dev/null) || { echo "status=error"; exit 2; }
  plan_dir=$(hp_plan_dir "$plan") || { echo "status=error"; exit 2; }
  hp_checkout_path "$plan_dir" >/dev/null 2>&1 || { echo "status=error"; exit 2; }
  # The whole allocation runs under the workspace lock, which Finish holds
  # while it removes the workspace: a ledger present under the lock is one
  # Finish has not removed, and when it is gone nothing is created, so a
  # removed workspace is never resurrected by a job line.
  if ! hp_lock "$plan_dir" 2>/dev/null; then echo "status=busy"; exit 3; fi
  if [ ! -f "$ws/progress.md" ]; then hp_unlock; echo "tracked-job: no ledger at $ws/progress.md" >&2; echo "status=error"; exit 2; fi
  jobs="$ws/jobs"; mkdir -p "$jobs" || { hp_unlock; echo "status=error"; exit 2; }
  tmp=$(mktemp -d "$jobs/.new-XXXXXX") || { hp_unlock; echo "status=error"; exit 2; }
  created=$(utc_ms)
  deadline=$(node -e 'process.stdout.write(new Date(Date.parse(process.argv[1])+Number(process.argv[2])).toISOString())' "$created" "$budget")
  if ! meta_set "$tmp" "name=$name" "cwd=$PWD" "created=$created" "budget_ms:=$budget" "deadline=$deadline" "session=$sid" "ledger=$ws/progress.md" "plan_dir=$plan_dir" "state=allocated"; then rm -rf "$tmp"; hp_unlock; echo "status=error"; exit 2; fi
  while :; do
    rand=$(printf '%04x' $((RANDOM % 65536)))
    final="$jobs/$name-$(date -u +%Y%m%dT%H%M%SZ)-$rand"
    [ -e "$final" ] || break
    n=$((n + 1)); [ "$n" -lt 20 ] || { rm -rf "$tmp"; hp_unlock; echo "status=error"; exit 2; }
  done
  mv "$tmp" "$final" || { rm -rf "$tmp"; hp_unlock; echo "status=error"; exit 2; }
  if ! printf 'job %s %s: %s jobdir=%s\n' "$sid" "$(utc_ms)" "$name" "$final" >> "$ws/progress.md"; then rm -rf "$final"; hp_unlock; echo "status=error"; exit 2; fi
  hp_unlock
  echo "jobdir=$final"
}

# The supervisor. It stays in its own process group; the command gets its own
# through job control (deviation 1) and starts only after the metadata is
# durable (the FIFO barrier).
RUN_DIR=""; RUN_PID=""; RUN_PGID=""; RUN_STOPPED=0
# group_alive: any member of the command's group, leader or descendant; kill -0
# on the negative group id asks the kernel, so it needs no ps.
group_alive() { kill -0 -- "-$RUN_PGID" 2>/dev/null; }
stop_group() { # TERM, grace, then KILL while any member survives; marks the job stopped
  RUN_STOPPED=1
  kill -TERM -- "-$RUN_PGID" 2>/dev/null
  local i=0; while [ "$i" -lt "$GRACE" ] && group_alive; do sleep 1; i=$((i + 1)); done
  group_alive && kill -KILL -- "-$RUN_PGID" 2>/dev/null
}
finish_run() { # <code>
  local code=$1 state=exited survivors=-1 i=0 rc
  [ "$RUN_STOPPED" -eq 1 ] && state=stopped
  if have_ps; then survivors=$(ps -o pid= -g "$RUN_PGID" 2>/dev/null | grep -c .); elif ! group_alive; then survivors=0; fi
  # The terminal state goes first, under the lock and only from running, and
  # the exit file second: a reader that sees exit also sees the state, and a
  # concurrent wait or stop never races this writer. A lock that stays held
  # through five attempts is noted in out.log and the exit file is written
  # anyway, so the job never reads as lost; wait repairs the state from the
  # exit file once the lock is free.
  while :; do
    conclude "$RUN_DIR" running "$state" "" "code:=$code" "survivors:=$survivors" >/dev/null; rc=$?
    [ "$rc" -eq 1 ] || break
    i=$((i + 1))
    if [ "$i" -ge 5 ]; then printf 'tracked-job: terminal state %s not recorded (lock held); exit=%s\n' "$state" "$code" >> "$RUN_DIR/out.log"; break; fi
    sleep 1
  done
  printf '%s\n' "$code" > "$RUN_DIR/exit.tmp" && mv "$RUN_DIR/exit.tmp" "$RUN_DIR/exit"
}
abort_launch() { # <reason>
  kill -KILL -- "-$RUN_PGID" 2>/dev/null; wait "$RUN_PID" 2>/dev/null
  rmdir "$RUN_DIR/launch.lock" 2>/dev/null; rm -f "$RUN_DIR/go"
  meta_set "$RUN_DIR" "state=allocated" "launch_error=$1 at $(utc_ms)" >/dev/null 2>&1
  echo "status=error"; exit 2
}
cmd_run() {
  local dir cmd_json i t code
  [ $# -ge 3 ] && [ "$2" = "--" ] || usage
  dir=$1; shift 2
  job_dir_ok "$dir" || { echo "status=error"; exit 2; }
  [ "$(meta_get "$dir" state)" = allocated ] || { echo "status=already-launched"; exit 2; }
  mkdir "$dir/launch.lock" 2>/dev/null || { echo "status=already-launched"; exit 2; }
  RUN_DIR=$dir
  rm -f "$dir/go"; mkfifo "$dir/go" || { rmdir "$dir/launch.lock"; echo "status=error"; exit 2; }
  : > "$dir/out.log"
  set -m
  ( exec env "TRACKED_JOB_DIR=$dir" bash -c 'read -r _ < "$0/go" || exit 97; exec "$@"' "$dir" "$@" ) >> "$dir/out.log" 2>&1 &
  RUN_PID=$!; RUN_PGID=$RUN_PID
  set +m
  cmd_json=$(node -e 'process.stdout.write(JSON.stringify(process.argv.slice(1)))' "$@")
  if [ -n "${HYPERPOWERS_TEST_FAIL_META:-}" ] || ! meta_set "$dir" "pid:=$RUN_PID" "pgid:=$RUN_PGID" "run_pid:=$$" "run_lstart=$(lstart_of $$)" "lstart=$(lstart_of "$RUN_PID")" "command:=$cmd_json" "launched=$(utc_ms)" "state=running"; then
    abort_launch "metadata write failed"
  fi
  # Open the barrier: the child is blocked in read on the FIFO. A writer that
  # cannot open within five seconds means the child died before reading.
  ( printf 'go\n' > "$dir/go" ) & t=$!
  i=0; while [ "$i" -lt 50 ] && kill -0 "$t" 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
  if kill -0 "$t" 2>/dev/null; then kill -KILL "$t" 2>/dev/null; abort_launch "barrier not taken"; fi
  rm -f "$dir/go"
  trap 'stop_group' TERM INT HUP
  while alive "$RUN_PID"; do
    sleep 1
    if [ -e "$dir/stop-request" ] && [ "$RUN_STOPPED" -eq 0 ]; then stop_group; fi
  done
  wait "$RUN_PID"; code=$?
  trap - TERM INT HUP
  finish_run "$code"
}

case "${1:-}" in
  new) shift; cmd_new "$@" ;;
  run) shift; cmd_run "$@" ;;
  wait|stop) echo "tracked-job: $1 arrives with Task 4" >&2; exit 2 ;;
  *) usage ;;
esac
```

In the barrier child, `bash -c` binds the first argument after the script to `$0`, which is why the directory is read as `$0`; keep that form. `set -m` prints job-control notices to the supervisor's stderr; they are harmless and the controller's Bash output is the supervisor's stdout only when the launch is a background call.

- [ ] **Step 4: Run the suite until it passes**

Run: `bash tests/sdd/test-tracked-job.sh` — Expected: `STATUS: PASSED (<k> skipped)` with the two `ps` cases skipped inside the sandbox; the controller runs it once more unsandboxed and expects `STATUS: PASSED (0 skipped)` and pastes the printed `child=... pgid=... sid=...` line into the evidence note's Probe section (the deviation 1 assertion). Also `bash tests/sdd/test-sdd-state.sh` and `bash tests/sdd/test-sdd-common.sh` — Expected: `STATUS: PASSED`.

- [ ] **Step 5: Document and commit**

Add `bash tests/sdd/test-tracked-job.sh` to the `tests/sdd/` row of `docs/testing.md:25`. Leak scan, then `git add skills/subagent-driven-development/scripts/tracked-job tests/sdd/test-tracked-job.sh docs/testing.md` and commit `feat(sdd): tracked-job allocates a job directory per launch and supervises the command`.

---

### Task 4: `tracked-job wait` and `tracked-job stop`

**Risk tier:** high — loss detection and process termination.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/tracked-job` (`supervisor_reused`, `cmd_wait`, `env_of`, `can_read_env`, `fenced`, `fenced_pids`, `cmd_stop`, the dispatcher)
- Test: `tests/sdd/test-tracked-job.sh` (the `wait` and `stop` cases, appended above the closing `STATUS` lines)

**Interfaces:**
- Consumes: Task 3's functions and layout.
- Produces: `wait` and `stop` with the status lines in Global Constraints (including `stop`'s `status=busy`, exit 3, when the workspace lock cannot be taken for the terminal record), the `lost` and `lost-unswept` states, the terminal ledger lines written once by `ledger_append_once`, and `meta.json`'s `survivors` and `skipped` counts.

**Mirror:** Task 3's `cmd_new` for the argument loop; `stop-server.sh:42-48` for `alive`.

- [ ] **Step 1: Append the failing cases**

Above the closing `STATUS` lines of `tests/sdd/test-tracked-job.sh`:

```bash
echo "=== tracked-job wait ==="
# an exited job: exited code=0, the terminal line once, repeats append nothing.
out=$(tj wait "$j1" --max-ms 1000); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=exited code=0" ] && [ "$(grep -c "^job s1 .*: soak exited code=0 jobdir=$j1\$" "$ws/progress.md")" = 1 ]; then pass "wait reports exited code=0 and appends the terminal line once"; else fail "wait reports exited code=0 and appends the terminal line once (rc=$rc: $out)"; fi
tj wait "$j1" --max-ms 1000 >/dev/null; tj wait "$j1" --max-ms 1000 >/dev/null
if [ "$(grep -c "^job s1 .*: soak exited code=0 jobdir=$j1\$" "$ws/progress.md")" = 1 ]; then pass "repeated waits append nothing"; else fail "repeated waits append nothing"; fi
out=$(tj wait "$j4" --max-ms 1000); rc=$?
if [ "$rc" -eq 1 ] && [ "$out" = "status=exited code=3" ]; then pass "a nonzero exit is reported with exit 1"; else fail "a nonzero exit is reported with exit 1 (rc=$rc: $out)"; fi
out=$(tj wait "$j2" --max-ms 1500); rc=$?
if [ "$rc" -eq 5 ] && [ "$out" = "status=not-started" ]; then pass "wait on an allocated job is not-started at the bound"; else fail "wait on an allocated job is not-started at the bound (rc=$rc: $out)"; fi
j10=$(newjob slow); ( tj run "$j10" -- bash -c 'sleep 4; exit 0' >/dev/null 2>&1 ) & sleep 1
t0=$(date +%s); out=$(tj wait "$j10" --max-ms 1000); rc=$?; t1=$(date +%s)
if [ "$rc" -eq 3 ] && [ "$out" = "status=running" ] && [ $((t1 - t0)) -le 3 ]; then pass "wait returns running within its bound while the command runs"; else fail "wait returns running within its bound while the command runs (rc=$rc: $out, $((t1 - t0))s)"; fi
out=$(tj wait "$j10" --max-ms 10000); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=exited code=0" ]; then pass "the same job is exited once the command ends"; else fail "the same job is exited once the command ends (rc=$rc: $out)"; fi
# a suspended supervisor is running, never lost (deviation 2).
j11=$(newjob frozen); ( tj run "$j11" -- bash -c 'sleep 60' >/dev/null 2>&1 ) & sleep 1
rp=$(meta "$j11" run_pid); kill -STOP "$rp"; sleep 3
out=$(tj wait "$j11" --max-ms 1000); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=running" ]; then pass "a stopped supervisor keeps the job running"; else fail "a stopped supervisor keeps the job running (rc=$rc: $out)"; fi
out=$(TRACKED_JOB_STOP_WAIT_S=2 tj stop "$j11"); rc=$?
if [ "$rc" -eq 6 ] && [ "$out" = "status=stop-timeout" ] && [ "$(meta "$j11" state)" = running ]; then pass "a supervisor that does not answer yields stop-timeout and the job stays running"; else fail "a supervisor that does not answer yields stop-timeout (rc=$rc: $out)"; fi
kill -CONT "$rp"; TRACKED_JOB_GRACE_S=1 tj stop "$j11" >/dev/null 2>&1
# lost: the supervisor killed with KILL; its pid answers ESRCH; wait says lost once.
j12=$(newjob lost); ( tj run "$j12" -- bash -c 'sleep 60' >/dev/null 2>&1 ) & sleep 1
kill -KILL "$(meta "$j12" run_pid)"; sleep 1
out=$(tj wait "$j12" --max-ms 1000); rc=$?
if [ "$rc" -eq 4 ] && [ "$out" = "status=lost" ] && [ "$(meta "$j12" state)" = lost ] && [ "$(grep -c "^job s1 .*: lost lost jobdir=$j12\$" "$ws/progress.md")" = 1 ]; then pass "a killed supervisor leaves a lost job that wait reports once"; else fail "a killed supervisor leaves a lost job that wait reports once (rc=$rc: $out)"; fi
# a reused supervisor pid: alive, but not the process recorded at launch (ps only).
if [ "$HAVE_PS" -eq 1 ]; then
  j18=$(newjob reused); ( tj run "$j18" -- bash -c 'sleep 60' >/dev/null 2>&1 ) & sleep 1
  realrun=$(meta "$j18" run_pid)
  node -e 'const fs=require("fs"),p=process.argv[1]+"/meta.json",m=JSON.parse(fs.readFileSync(p,"utf8"));m.run_pid=Number(process.argv[2]);fs.writeFileSync(p,JSON.stringify(m))' "$j18" "$$"
  out=$(tj wait "$j18" --max-ms 1000); rc=$?
  if [ "$rc" -eq 4 ] && [ "$out" = "status=lost" ] && [ "$(meta "$j18" state)" = lost ]; then pass "a supervisor pid now owned by another process reads as lost"; else fail "a supervisor pid now owned by another process reads as lost (rc=$rc: $out)"; fi
  out=$(TRACKED_JOB_STOP_WAIT_S=2 tj stop "$j18"); rc=$?
  if [ "$rc" -ne 6 ]; then pass "stop on the reused pid does not wait on the stranger"; else fail "stop on the reused pid does not wait on the stranger (rc=$rc: $out)"; fi
  kill -TERM "$realrun" 2>/dev/null; sleep 3
else
  skip "a supervisor pid now owned by another process reads as lost (ps unavailable)"
  skip "stop on the reused pid does not wait on the stranger (ps unavailable)"
fi

echo "=== tracked-job stop ==="
j13=$(newjob stubborn); ( tj run "$j13" -- bash -c 'trap "" TERM; sleep 60' >/dev/null 2>&1 ) & sleep 1
t0=$(date +%s); out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j13"); rc=$?; t1=$(date +%s)
if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && [ "$(cat "$j13/exit")" = 137 ] && [ "$(meta "$j13" state)" = stopped ] && [ $((t1 - t0)) -le 15 ] && [ "$(grep -c "^job s1 .*: stubborn stopped jobdir=$j13\$" "$ws/progress.md")" = 1 ]; then pass "stop ends a TERM-resistant command through the supervisor, records 137 and the line once"; else fail "stop ends a TERM-resistant command through the supervisor (rc=$rc: $out, exit=$(cat "$j13/exit" 2>/dev/null))"; fi
j14=$(newjob parent); ( tj run "$j14" -- bash -c 'sleep 60 & echo $! > child.pid; wait' >/dev/null 2>&1 ) & sleep 1
childpid=$(cat "$repo/child.pid" 2>/dev/null); out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j14"); rc=$?; sleep 1
if [ "$rc" -eq 0 ] && [ -n "$childpid" ] && ! kill -0 "$childpid" 2>/dev/null; then pass "stop ends the command's children with it"; else fail "stop ends the command's children with it (rc=$rc: $out, child=$childpid)"; fi
# the leader exits on TERM while a descendant ignores it: KILL still reaches the group.
j19=$(newjob orphaning); ( tj run "$j19" -- bash -c '(trap "" TERM; exec sleep 60) & echo $! > inner.pid; trap "exit 0" TERM; wait' >/dev/null 2>&1 ) & sleep 1
inner=$(cat "$repo/inner.pid" 2>/dev/null); out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j19"); rc=$?; sleep 1
if [ "$rc" -eq 0 ] && [ -n "$inner" ] && ! kill -0 "$inner" 2>/dev/null && [ "$(meta "$j19" state)" = stopped ]; then pass "stop ends a TERM-ignoring descendant after its leader exits on TERM"; else fail "stop ends a TERM-ignoring descendant after its leader exits on TERM (rc=$rc: $out, inner=$inner)"; fi
out=$(tj stop "$j4"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=not-running" ]; then pass "stop on a finished job is not-running"; else fail "stop on a finished job is not-running (rc=$rc: $out)"; fi
# lost-job sweep: fenced survivors ended one by one; a fenceless process in the group left alone (ps only).
j15=$(newjob survivors); ( tj run "$j15" -- bash -c 'sleep 60 & env -u TRACKED_JOB_DIR sleep 60 & echo $! > stranger.pid; wait' >/dev/null 2>&1 ) & sleep 1
stranger=$(cat "$repo/stranger.pid" 2>/dev/null); kill -KILL "$(meta "$j15" run_pid)"; sleep 1
out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j15"); rc=$?; sleep 1
if [ "$HAVE_PS" -eq 1 ]; then
  if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && ! kill -0 "$(meta "$j15" pid)" 2>/dev/null && kill -0 "$stranger" 2>/dev/null && [ "$(meta "$j15" skipped)" = 1 ] && [ "$(meta "$j15" state)" = stopped ]; then pass "stop on a lost job ends the fenced survivors and leaves the fenceless process, counting it as skipped"; else fail "stop on a lost job ends the fenced survivors and leaves the fenceless process (rc=$rc: $out, skipped=$(meta "$j15" skipped))"; fi
  if [ "$(grep -c "^job s1 .*: survivors stopped jobdir=$j15\$" "$ws/progress.md")" = 1 ]; then pass "the lost job's stopped line is written once"; else fail "the lost job's stopped line is written once"; fi
  out=$(tj stop "$j15"); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "status=not-running" ]; then pass "a second stop on the swept job is not-running"; else fail "a second stop on the swept job is not-running (rc=$rc: $out)"; fi
  out=$(tj wait "$j15" --max-ms 1000); rc=$?
  if [ "$rc" -eq 4 ] && [ "$out" = "status=lost" ]; then pass "wait on a swept lost job reports lost"; else fail "wait on a swept lost job reports lost (rc=$rc: $out)"; fi
  # the Linux fence (/proc/<pid>/environ) through a supplied proc tree: only the process whose environ carries the fence is signalled.
  j21=$(newjob procfence); ( tj run "$j21" -- bash -c 'sleep 60 & echo $! > a.pid; sleep 60 & echo $! > b.pid; env -u TRACKED_JOB_DIR sleep 60 & echo $! > c.pid; wait' >/dev/null 2>&1 ) & sleep 1
  pa=$(cat "$repo/a.pid"); pb=$(cat "$repo/b.pid"); pc=$(cat "$repo/c.pid"); leader=$(meta "$j21" pid)
  kill -KILL "$(meta "$j21" run_pid)"; sleep 1
  # the group holds four processes: the leader and pa fenced in the fake tree, pb with no environ (unreadable), pc fenceless.
  proc="$TEST_ROOT/proc"; mkdir -p "$proc/$leader" "$proc/$pa" "$proc/$pc"
  printf 'TRACKED_JOB_DIR=%s\0HOME=/x\0' "$j21" > "$proc/$leader/environ"
  printf 'TRACKED_JOB_DIR=%s\0HOME=/x\0' "$j21" > "$proc/$pa/environ"
  printf 'OTHER=1\0' > "$proc/$pc/environ"
  out=$(TRACKED_JOB_PROC_ROOT="$proc" TRACKED_JOB_GRACE_S=1 tj stop "$j21"); rc=$?; sleep 1
  if [ "$rc" -eq 0 ] && [ "$out" = "status=stopped" ] && ! kill -0 "$leader" 2>/dev/null && ! kill -0 "$pa" 2>/dev/null && kill -0 "$pb" 2>/dev/null && kill -0 "$pc" 2>/dev/null && [ "$(meta "$j21" skipped)" = 2 ] && [ "$(meta "$j21" survivors)" = 0 ]; then pass "the /proc fence signals only the processes whose environ carries it; the unreadable one and the fenceless one are skipped and counted"; else fail "the /proc fence signals only the processes whose environ carries it (rc=$rc: $out, skipped=$(meta "$j21" skipped), survivors=$(meta "$j21" survivors))"; fi
  kill -KILL "$pb" "$pc" 2>/dev/null; rm -rf "$proc"
else
  if [ "$rc" -eq 7 ] && [ "$out" = "status=lost-unswept pgid=$(meta "$j15" pgid)" ] && [ "$(meta "$j15" state)" = lost-unswept ] && [ "$(grep -c "^job s1 .*: survivors lost-unswept pgid=$(meta "$j15" pgid) jobdir=$j15\$" "$ws/progress.md")" = 1 ]; then pass "without ps, stop on a lost job refuses to signal, names the group and records lost-unswept"; else fail "without ps, stop on a lost job refuses to signal and names the group (rc=$rc: $out)"; fi
  out=$(tj wait "$j15" --max-ms 1000); rc=$?
  if [ "$rc" -eq 7 ] && [ "$out" = "status=lost-unswept pgid=$(meta "$j15" pgid)" ]; then pass "wait on a lost-unswept job repeats the state"; else fail "wait on a lost-unswept job repeats the state (rc=$rc: $out)"; fi
  skip "stop on a lost job ends the fenced survivors and leaves the fenceless process (ps unavailable)"
  skip "the lost job's stopped line is written once (ps unavailable)"
  skip "wait on a swept lost job reports lost (ps unavailable)"
  skip "the /proc fence signals only the process whose environ carries it (ps unavailable)"
fi
kill -KILL "$stranger" "$(meta "$j15" pid)" 2>/dev/null
# concurrent wait and stop on a lost job: whichever writes first wins, the job never ends lost with survivors, no outcome line repeats.
j20=$(newjob raced); ( tj run "$j20" -- bash -c 'sleep 60' >/dev/null 2>&1 ) & sleep 1
kill -KILL "$(meta "$j20" run_pid)"; sleep 1
( tj wait "$j20" --max-ms 8000 > "$TEST_ROOT/raced-wait.out" 2>&1 ) & rw=$!
( TRACKED_JOB_GRACE_S=1 tj stop "$j20" > "$TEST_ROOT/raced-stop.out" 2>&1 ) & rs=$!
wait "$rw" "$rs"
final=$(meta "$j20" state)
dups=$(grep -F "jobdir=$j20" "$ws/progress.md" | sed -E 's/^job [^:]*: raced //; s/ jobdir=.*//' | sort | uniq -d | grep -c .)
if { [ "$final" = stopped ] || [ "$final" = lost-unswept ]; } && [ "$dups" = 0 ]; then pass "concurrent wait and stop on a lost job never leave it lost and never repeat a line"; else fail "concurrent wait and stop on a lost job never leave it lost and never repeat a line (final=$final dups=$dups; wait: $(cat "$TEST_ROOT/raced-wait.out"); stop: $(cat "$TEST_ROOT/raced-stop.out"))"; fi
kill -KILL "$(meta "$j20" pid)" 2>/dev/null
# a held workspace lock: no terminal record is written and no success is claimed; the record repairs once the lock is free.
lockdir="$( . "$LIB"; hp_checkout_path "$repo" ).lock"
j22=$(newjob locked); j23=$(newjob lockedexit)
( tj run "$j22" -- bash -c 'sleep 60' >/dev/null 2>&1 ) & sleep 1
kill -KILL "$(meta "$j22" run_pid)"; sleep 1
mkdir -p "$lockdir"; printf 'pid=1\n' > "$lockdir/owner"
out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 tj stop "$j22"); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(meta "$j22" state)" = running ]; then pass "stop under a held lock is busy and records nothing"; else fail "stop under a held lock is busy and records nothing (rc=$rc: $out, state=$(meta "$j22" state))"; fi
out=$(HYPERPOWERS_LOCK_WAIT_STEPS=2 tj wait "$j22" --max-ms 3000); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=running" ] && [ "$(meta "$j22" state)" = running ]; then pass "wait under a held lock reads running at its bound and records nothing"; else fail "wait under a held lock reads running at its bound and records nothing (rc=$rc: $out, state=$(meta "$j22" state))"; fi
( HYPERPOWERS_LOCK_WAIT_STEPS=2 tj run "$j23" -- bash -c 'exit 0' >/dev/null 2>&1 ) & sleep 8
if [ "$(cat "$j23/exit" 2>/dev/null)" = 0 ] && [ "$(meta "$j23" state)" = running ] && grep -q 'terminal state exited not recorded' "$j23/out.log"; then pass "a supervisor that cannot take the lock still writes exit and says so in out.log"; else fail "a supervisor that cannot take the lock still writes exit and says so in out.log (exit=$(cat "$j23/exit" 2>/dev/null), state=$(meta "$j23" state))"; fi
rm -rf "$lockdir"
out=$(tj wait "$j23" --max-ms 1000); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=exited code=0" ] && [ "$(meta "$j23" state)" = exited ]; then pass "wait repairs the state from the exit file once the lock is free"; else fail "wait repairs the state from the exit file once the lock is free (rc=$rc: $out, state=$(meta "$j23" state))"; fi
out=$(TRACKED_JOB_GRACE_S=1 tj stop "$j22"); rc=$?
case "$rc" in 0|7) pass "stop on the lost job proceeds once the lock is free" ;; *) fail "stop on the lost job proceeds once the lock is free (rc=$rc: $out)" ;; esac
kill -KILL "$(meta "$j22" pid)" 2>/dev/null
# a stale leader whose group has no fenced member: not-running (ps only).
if [ "$HAVE_PS" -eq 1 ]; then
  j16=$(newjob stale); ( tj run "$j16" -- bash -c 'sleep 2' >/dev/null 2>&1 ) & sleep 1
  kill -KILL "$(meta "$j16" run_pid)"; sleep 3
  out=$(tj stop "$j16"); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "status=not-running" ] && [ "$(meta "$j16" state)" = stopped ]; then pass "a lost job whose group is already gone is not-running"; else fail "a lost job whose group is already gone is not-running (rc=$rc: $out)"; fi
else
  skip "a lost job whose group is already gone is not-running (ps unavailable)"
fi
```

- [ ] **Step 2: Run to verify the new cases fail**

Run: `bash tests/sdd/test-tracked-job.sh 2>&1 | grep -c "\[FAIL\]"` — Expected: at least 10.

- [ ] **Step 3: Implement `wait` and `stop`**

Replace the dispatcher's placeholder and add before it:

```bash
# supervisor_reused <jobdir>: the recorded supervisor pid answers kill -0 but
# its start time is not the one recorded at launch, so another process owns
# the pid now (ps only; without ps the residual stated in deviation 2 stands).
supervisor_reused() {
  local want
  have_ps || return 1
  want=$(meta_get "$1" run_lstart); [ -n "$want" ] || return 1
  [ "$(lstart_of "$(meta_get "$1" run_pid)")" != "$want" ]
}
# terminal_line <jobdir>: the ledger line for a job that has an exit file.
terminal_line() {
  local dir=$1 code
  code=$(cat "$dir/exit")
  if [ "$(meta_get "$dir" state)" = stopped ]; then printf 'stopped'; else printf 'exited code=%s' "$code"; fi
}
cmd_wait() {
  local dir="" max="" state deadline code now rc
  while [ $# -gt 0 ]; do
    case "$1" in
      --max-ms) [ $# -ge 2 ] || usage; max=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$dir" ] || usage; dir=$1; shift ;;
    esac
  done
  [ -n "$dir" ] && [ -n "$max" ] || usage
  case "$max" in ''|*[!0-9]*) usage ;; esac
  [ "$max" -le 600000 ] || usage
  job_dir_ok "$dir" || { echo "status=error"; exit 2; }
  deadline=$(( $(date +%s) + (max + 999) / 1000 ))
  while :; do
    state=$(meta_get "$dir" state)
    if [ -f "$dir/exit" ]; then
      code=$(cat "$dir/exit")
      # A supervisor that could not take the lock left the state running: repair it from the exit file.
      [ "$state" != running ] || conclude "$dir" running exited "" "code:=$code" >/dev/null
      ledger_append_once "$dir" "$(terminal_line "$dir")"
      echo "status=exited code=$code"; [ "$code" = 0 ] && exit 0; exit 1
    fi
    case "$state" in
      lost) ledger_append_once "$dir" "lost"; echo "status=lost"; exit 4 ;;
      lost-unswept) echo "status=lost-unswept pgid=$(meta_get "$dir" pgid)"; exit 7 ;;
      stopped)
        # Swept after a loss (no exit file, or wait would have seen it): the job was lost.
        echo "status=lost"; exit 4 ;;
      running)
        # Loss is the supervisor's death: its pid answers ESRCH (deviation 2),
        # or, where ps works, its pid now carries a different start time (reused).
        # The transition is a conclude from running: when stop concluded the job
        # first (lost-unswept, stopped), the loop reports what stop decided; a
        # lock that could not be taken (rc 1) leaves the state alone and the
        # job reads as running until the bound.
        if ! alive "$(meta_get "$dir" run_pid)"; then sleep 2
          if [ ! -f "$dir/exit" ]; then
            conclude "$dir" running lost "lost" >/dev/null; rc=$?
            case "$rc" in 0) echo "status=lost"; exit 4 ;; 2) continue ;; esac
          fi
        elif supervisor_reused "$dir"; then
          conclude "$dir" running lost "lost" >/dev/null; rc=$?
          case "$rc" in 0) echo "status=lost"; exit 4 ;; 2) continue ;; esac
        fi ;;
    esac
    now=$(date +%s)
    if [ "$now" -ge "$deadline" ]; then
      case "$state" in allocated) echo "status=not-started"; exit 5 ;; *) echo "status=running"; exit 3 ;; esac
    fi
    sleep 1
  done
}

PROC_ROOT=${TRACKED_JOB_PROC_ROOT:-/proc}
# env_of <pid>: the process's environment, one entry per line: /proc on Linux,
# ps -E on macOS (whose output splits on spaces, so a cache path containing a
# space never matches and the process is skipped, never signalled). Status 1
# when it cannot be read.
env_of() {
  if [ -r "$PROC_ROOT/$1/environ" ]; then tr '\0' '\n' < "$PROC_ROOT/$1/environ"; return 0; fi
  if [ ! -d "$PROC_ROOT" ]; then ps -E -o command= -p "$1" 2>/dev/null | tr ' ' '\n'; return "${PIPESTATUS[0]}"; fi
  return 1
}
can_read_env() { [ -d "$PROC_ROOT" ] || ps -E -o command= -p $$ >/dev/null 2>&1; }
# fenced <pid> <jobdir>: the process carries this job's fence, read now.
fenced() { env_of "$1" 2>/dev/null | grep -Fxq "TRACKED_JOB_DIR=$2"; }
# fenced_pids <jobdir> <pgid>: the recorded group's fenced processes.
fenced_pids() {
  local dir=$1 pgid=$2 p
  for p in $(ps -o pid= -g "$pgid" 2>/dev/null); do fenced "$p" "$dir" && printf '%s\n' "$p"; done
}
cmd_stop() {
  local dir=${1:-} state i pgid pids p total skipped survivors rc
  [ -n "$dir" ] || usage
  job_dir_ok "$dir" || { echo "status=error"; exit 2; }
  state=$(meta_get "$dir" state)
  case "$state" in exited|stopped|allocated) echo "status=not-running"; exit 0 ;; esac
  if [ "$state" = running ] && alive "$(meta_get "$dir" run_pid)" && ! supervisor_reused "$dir"; then
    : > "$dir/stop-request"
    i=0; while [ "$i" -lt "$STOP_WAIT" ] && [ ! -f "$dir/exit" ]; do sleep 1; i=$((i + 1)); done
    if [ -f "$dir/exit" ]; then ledger_append_once "$dir" "$(terminal_line "$dir")"; echo "status=stopped"; exit 0; fi
    echo "status=stop-timeout"; exit 6
  fi
  # The supervisor is dead: record the loss (wait may have already), then sweep by identity only.
  # Every conclude result is checked: a lock that cannot be taken is status=busy (3), the state
  # is left as it was, and nothing is claimed; the controller retries stop.
  if [ "$state" = running ]; then
    conclude "$dir" running lost "lost" >/dev/null; rc=$?
    [ "$rc" -ne 1 ] || { echo "status=busy"; exit 3; }
    state=$(meta_get "$dir" state)
  fi
  case "$state" in lost|lost-unswept) ;; *) echo "status=not-running"; exit 0 ;; esac
  pgid=$(meta_get "$dir" pgid)
  if ! have_ps || ! can_read_env; then
    if [ "$state" != lost-unswept ]; then
      conclude "$dir" lost lost-unswept "lost-unswept pgid=$pgid" >/dev/null; rc=$?
      [ "$rc" -ne 1 ] || { echo "status=busy"; exit 3; }
    fi
    echo "status=lost-unswept pgid=$pgid"; exit 7
  fi
  if [ "$(ps -o pid= -g "$pgid" 2>/dev/null | grep -c .)" -eq 0 ]; then
    conclude "$dir" "$state" stopped "stopped" "survivors:=0" "skipped:=0" >/dev/null; rc=$?
    [ "$rc" -ne 1 ] || { echo "status=busy"; exit 3; }
    echo "status=not-running"; exit 0
  fi
  pids=$(fenced_pids "$dir" "$pgid")
  for p in $pids; do if fenced "$p" "$dir"; then kill -TERM "$p" 2>/dev/null; fi; done
  sleep "$GRACE"
  for p in $pids; do if fenced "$p" "$dir"; then kill -KILL "$p" 2>/dev/null; fi; done
  sleep 1
  survivors=$(fenced_pids "$dir" "$pgid" | grep -c .)
  skipped=$(( $(ps -o pid= -g "$pgid" 2>/dev/null | grep -c .) - survivors ))
  i=0
  while :; do
    conclude "$dir" "$state" stopped "stopped" "survivors:=$survivors" "skipped:=$skipped" >/dev/null; rc=$?
    [ "$rc" -eq 1 ] || break
    i=$((i + 1)); [ "$i" -lt 5 ] || { echo "status=busy"; exit 3; }
    sleep 1
  done
  if [ "$rc" -eq 2 ]; then echo "status=not-running"; exit 0; fi
  echo "status=stopped"; exit 0
}
```

and the dispatcher: `wait) shift; cmd_wait "$@" ;;` and `stop) shift; cmd_stop "${1:-}" ;;`. `survivors` counts fenced processes still alive after KILL; `skipped` counts the group's processes without the fence or with an unreadable environment, which are left alone. When the lost job's group has no process at all, `stop` is `not-running` and the state becomes `stopped` with zero counts. Every terminal transition goes through `conclude`, so when `wait` and `stop` run at once on a lost job the outcome is whichever wrote first and the other reports it: a job never ends `lost` with survivors unswept, and a `stopped` or `lost-unswept` state is never overwritten by `lost`. `TRACKED_JOB_PROC_ROOT` (default `/proc`) lets a test supply a proc tree on a host without one.

- [ ] **Step 4: Run the suite**

Run: `bash tests/sdd/test-tracked-job.sh` — Expected: `STATUS: PASSED (<k> skipped)` in the sandbox (the lost-unswept branch exercised), and `STATUS: PASSED (0 skipped)` unsandboxed (the fenced sweep, the stale leader, the process relationships); the controller records both lines in the ledger.

- [ ] **Step 5: Commit**

Leak scan, `git add skills/subagent-driven-development/scripts/tracked-job tests/sdd/test-tracked-job.sh`, commit `feat(sdd): tracked-job waits on a job and stops it through its supervisor`.

---

### Task 5: The Finish receipt, the snapshot set, and `prune --receipts`

**Risk tier:** high — `finish` is a destructive step; the receipt is the durable record the analyzer reads.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`cmd_finish` `:595-655`, `cmd_prune` `:659-690`, `usage`)
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh` (`hp_write_root_files` `:390-396` and a refresh inside `hp_ensure_checkout`)
- Test: `tests/sdd/test-sdd-state-finish-receipt.sh`; one section in `tests/sdd/test-sdd-state.sh` (the branch-backend `.gitignore` and snapshot case)
- Modify: `docs/testing.md:25`

**Interfaces:**
- Consumes: `hp_cache_root`, `hp_lock`, `remove_verified`, `hp_commit_paths` (as they stand); the job directory layout from Task 3.
- Produces: `sdd-state finish` stages the receipt as `<cache>/hyperpowers/receipts/.staging-<workspace name>-<UTC>/` before any removal, renames it to `<cache>/hyperpowers/receipts/<workspace name>-<UTC>/` only after the removal and its commit succeed, and prints `receipt=<path>` beside `last=` (branch backend) or `backend=plain` (plain); it refuses with `status=error` before removing anything when the staging cannot be built, and removes the staging on any failure before the removal; after the removal the record is never discarded: `finish` writes the marker file `FINISHED` into the staging (it may exist only once the removal and its commit are done), then renames, retrying three times a second apart; when the rename still fails and the marker exists, the staging stays under its dot-prefixed name and `finish` prints `status=finished ... receipt=<staging path>` (the plan did finish and the record exists; the hook's discovery and the analyzer accept a dot-prefixed receipt only when it carries `FINISHED`); when neither the rename nor the marker could be written, `finish` prints `status=finished ... receipt=none staging=<staging path>`, the explicit unrecoverable outcome, which the skill text tells the controller to report to the human partner; the receipt holds `progress.md` (required) and, when they exist, `stop-guard.jsonl` and `jobs/<job>/meta.json` and `jobs/<job>/exit`; `sdd-state prune --receipts --days N [--apply]` lists (and with `--apply` removes) receipts older than N days, staging directories included, marking a staging without `FINISHED` as `stale=1`; the state checkout's `.gitignore` excludes `plans/*/jobs/*/out.log`, `plans/*/jobs/*/go`, `plans/*/jobs/*/launch.lock` and `plans/*/jobs/*/stop-request`, so `snapshot` commits `stop-guard.jsonl`, `meta.json` and `exit` and nothing else from a job. Task 6's hook discovers receipts by their `progress.md`, skipping dot-prefixed names; Task 14's analyzer reads them the same way.

**Mirror:** `cmd_finish:595-655` (the lock, the `open-claims` refusal, `remove_verified`, the commit); `cmd_prune:659-690` (argument loop, `--apply` under the lock).

- [ ] **Step 1: Write the failing suite**

Create `tests/sdd/test-sdd-state-finish-receipt.sh` with the preamble of `tests/sdd/test-sdd-state.sh` (its temporary `XDG_CACHE_HOME`, `GIT_CONFIG_GLOBAL=/dev/null`, and the `make_repo`, `run_state` and `run_sdd_dir` helpers copied in), one repository `$repo` with a plan at `docs/plan.md`, its workspace `$ws` from `run_sdd_dir`, a ledger with a session line, and these cases:

```bash
RECEIPTS="$XDG_CACHE_HOME/hyperpowers/receipts"
echo "=== finish writes a receipt ==="
out=$(run_state "$repo" finish docs/plan.md); rc=$?
r=$(printf '%s' "$out" | sed -n 's/.*receipt=\([^ ]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ -n "$r" ] && [ -f "$r/progress.md" ] && [ "$(ls "$r" | wc -l | tr -d ' ')" = 1 ] && [ ! -d "$ws" ]; then pass "a finish with no hook log and no jobs writes a receipt with the ledger alone"; else fail "a finish with no hook log and no jobs writes a receipt with the ledger alone (rc=$rc: $out)"; fi
case "$(basename "$r")" in .staging-*) fail "the receipt is renamed out of staging" ;; *) pass "the receipt is renamed out of staging" ;; esac
ws=$(run_sdd_dir "$repo" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s2: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
printf '{"ts":"2026-10-23T00:00:01.000Z","session":"s2","decision":"block","reason":"open-tasks"}\n' > "$ws/stop-guard.jsonl"
mkdir -p "$ws/jobs/a-x-0001" "$ws/jobs/b-x-0002" "$ws/jobs/c-x-0003"
printf '{"name":"a","state":"allocated"}\n' > "$ws/jobs/a-x-0001/meta.json"
printf '{"name":"b","state":"lost"}\n' > "$ws/jobs/b-x-0002/meta.json"; printf 'noise\n' > "$ws/jobs/b-x-0002/out.log"
printf '{"name":"c","state":"exited"}\n' > "$ws/jobs/c-x-0003/meta.json"; printf '0\n' > "$ws/jobs/c-x-0003/exit"; printf 'noise\n' > "$ws/jobs/c-x-0003/out.log"
out=$(run_state "$repo" finish docs/plan.md); rc=$?
r=$(printf '%s' "$out" | sed -n 's/.*receipt=\([^ ]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ -f "$r/stop-guard.jsonl" ] && [ -f "$r/jobs/a-x-0001/meta.json" ] && [ -f "$r/jobs/b-x-0002/meta.json" ] && [ ! -e "$r/jobs/b-x-0002/exit" ] && [ -f "$r/jobs/c-x-0003/exit" ] && [ ! -e "$r/jobs/b-x-0002/out.log" ]; then pass "the receipt copies the hook log, every meta.json and the exit files that exist, and nothing else"; else fail "the receipt copies the hook log, every meta.json and the exit files that exist, and nothing else (rc=$rc: $out)"; fi
ws=$(run_sdd_dir "$repo" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s3: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
chmod 500 "$RECEIPTS"
out=$(run_state "$repo" finish docs/plan.md); rc=$?
chmod 700 "$RECEIPTS"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$ws/progress.md" ]; then pass "a receipt that cannot be staged stops finish with the workspace intact"; else fail "a receipt that cannot be staged stops finish with the workspace intact (rc=$rc: $out)"; fi
# a failure after staging (the removal refused) removes the staging and leaves no receipt.
out=$(HYPERPOWERS_TEST_FAIL_REMOVE=1 run_state "$repo" finish docs/plan.md); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$ws/progress.md" ] && [ -z "$(ls -A "$RECEIPTS" | grep '^\.staging-')" ] && [ "$(ls "$RECEIPTS" | grep -c .)" = 2 ]; then pass "a finish that fails after staging removes the staging and writes no receipt"; else fail "a finish that fails after staging removes the staging and writes no receipt (rc=$rc: $out)"; fi
# a rename that fails after the removal: the record stays as a FINISHED staging and finish still succeeds.
out=$(HYPERPOWERS_TEST_FAIL_RENAME=1 run_state "$repo" finish docs/plan.md); rc=$?
r=$(printf '%s' "$out" | sed -n 's/.*receipt=\([^ ]*\).*/\1/p')
case "$(basename "$r")" in .staging-*) staged=1 ;; *) staged=0 ;; esac
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^status=finished' && [ "$staged" = 1 ] && [ -f "$r/FINISHED" ] && [ -f "$r/progress.md" ] && [ ! -d "$ws" ]; then pass "a rename that fails after the removal leaves a FINISHED staging as the receipt"; else fail "a rename that fails after the removal leaves a FINISHED staging as the receipt (rc=$rc: $out)"; fi
# neither the rename nor the marker: finish still succeeds and says receipt=none with the staging path.
ws=$(run_sdd_dir "$repo" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s4: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
out=$(HYPERPOWERS_TEST_FAIL_RENAME=1 HYPERPOWERS_TEST_FAIL_MARKER=1 run_state "$repo" finish docs/plan.md); rc=$?
st=$(printf '%s' "$out" | sed -n 's/.*staging=\([^ ]*\).*/\1/p')
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^status=finished' && printf '%s' "$out" | grep -q ' receipt=none staging=' && [ -f "$st/progress.md" ] && [ ! -e "$st/FINISHED" ] && [ ! -d "$ws" ]; then pass "a staging that can be neither renamed nor marked is reported as receipt=none with its path"; else fail "a staging that can be neither renamed nor marked is reported as receipt=none with its path (rc=$rc: $out)"; fi
# a finished receipt keeps its marker harmlessly, and the hook and analyzer accept it by name alone (Tasks 6 and 14).
old="$RECEIPTS/old-ws-20200101T000000Z"; mkdir -p "$old"; printf 'x\n' > "$old/progress.md"; touch -t 202001010000 "$old" "$old/progress.md"
stale="$RECEIPTS/.staging-old2-20200101T000000Z"; mkdir -p "$stale"; touch -t 202001010000 "$stale"
finished="$RECEIPTS/.staging-old3-20200101T000000Z"; mkdir -p "$finished"; printf 'x\n' > "$finished/progress.md"; : > "$finished/FINISHED"; touch -t 202001010000 "$finished" "$finished/progress.md" "$finished/FINISHED"
out=$(run_state "$repo" prune --receipts --days 30); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "old-ws-20200101T000000Z" && printf '%s' "$out" | grep -q ".staging-old2.*stale=1" && printf '%s' "$out" | grep -q ".staging-old3" && ! printf '%s' "$out" | grep -q ".staging-old3.*stale=1" && [ -d "$old" ]; then pass "prune --receipts lists old receipts, marks stale stagings, and leaves everything without --apply"; else fail "prune --receipts lists old receipts, marks stale stagings, and leaves everything without --apply (rc=$rc: $out)"; fi
out=$(run_state "$repo" prune --receipts --days 30 --apply); rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$old" ] && [ ! -d "$stale" ] && [ ! -d "$finished" ] && [ "$(ls "$RECEIPTS" | grep -c .)" = 2 ] && [ "$(ls -A "$RECEIPTS" | grep -c '^\.staging-')" = 2 ]; then pass "prune --receipts --apply removes only the old ones and keeps the two young stagings"; else fail "prune --receipts --apply removes only the old ones and keeps the two young stagings (rc=$rc: $out)"; fi
```

In `tests/sdd/test-sdd-state.sh`, a section over a `make_pair` repository (branch backend): after `ensure`, the checkout's `.gitignore` contains `plans/*/jobs/*/out.log`; writing `jobs/x-0001/meta.json`, `jobs/x-0001/exit` and `jobs/x-0001/out.log` under a workspace and running `snapshot` commits the first two and not the third (`git -C "$co" show --name-only --format= HEAD`); a checkout created by an older plugin (write its `.gitignore` without the job lines, then `ensure` again) gets the lines added.

- [ ] **Step 2: Run both suites to verify the new cases fail**

Run: `bash tests/sdd/test-sdd-state-finish-receipt.sh; bash tests/sdd/test-sdd-state.sh 2>&1 | tail -n 8` — Expected: the receipt cases `[FAIL]` (no `receipt=`), the `.gitignore` cases `[FAIL]`.

- [ ] **Step 3: Implement**

In `sdd-common.sh`, factor the ignore lines into `hp_write_ignore <dir>` (called by `hp_write_root_files`), writing the four job patterns after the existing ones:

```bash
hp_write_ignore() { # <dir>
  printf '%s\n' '# Regenerable on any host: briefs come from task-brief, packages from review-package.' 'plans/*/task-*-brief.md' 'plans/*/review-*.diff' '# A copy an import left beside an entry it could not install: local to that host, for a human to merge.' 'plans/*/*.from-import' '# Job scratch (tracked-job): the record is meta.json and exit.' 'plans/*/jobs/*/out.log' 'plans/*/jobs/*/go' 'plans/*/jobs/*/launch.lock' 'plans/*/jobs/*/stop-request' > "$1/.gitignore"
}
```

and in `hp_ensure_checkout`, after an existing checkout is verified, `grep -q 'plans/\*/jobs/\*/out.log' "$co/.gitignore" 2>/dev/null || hp_write_ignore "$co"` (the sentinel and README are untouched).

In `sdd-state`, the two-phase receipt, placed before `cmd_finish`:

```bash
# stage_receipt <wsdir> <ws name>: the durable copy of what finish removes,
# built under a dot-prefixed staging name; finish renames it into place only
# after the removal and its commit succeed. progress.md is required; the hook
# log and job records are copied when present.
RECEIPT_STAGING=""; RECEIPT_FINAL=""
stage_receipt() {
  local src=$1 name=$2 root stamp j
  root="$(hp_cache_root)/receipts"
  mkdir -p "$root" || return 1
  [ -f "$src/progress.md" ] || return 1
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  RECEIPT_FINAL="$root/$name-$stamp"; [ -e "$RECEIPT_FINAL" ] && RECEIPT_FINAL="$RECEIPT_FINAL-$$"
  RECEIPT_STAGING="$root/.staging-$(basename "$RECEIPT_FINAL")"
  mkdir "$RECEIPT_STAGING" 2>/dev/null || return 1
  cp "$src/progress.md" "$RECEIPT_STAGING/progress.md" || { rm -rf "$RECEIPT_STAGING"; return 1; }
  if [ -f "$src/stop-guard.jsonl" ]; then cp "$src/stop-guard.jsonl" "$RECEIPT_STAGING/stop-guard.jsonl" || { rm -rf "$RECEIPT_STAGING"; return 1; }; fi
  for j in "$src"/jobs/*/; do
    [ -f "$j/meta.json" ] || continue
    mkdir -p "$RECEIPT_STAGING/jobs/$(basename "$j")" || { rm -rf "$RECEIPT_STAGING"; return 1; }
    cp "$j/meta.json" "$RECEIPT_STAGING/jobs/$(basename "$j")/meta.json" || { rm -rf "$RECEIPT_STAGING"; return 1; }
    if [ -f "$j/exit" ]; then cp "$j/exit" "$RECEIPT_STAGING/jobs/$(basename "$j")/exit" || { rm -rf "$RECEIPT_STAGING"; return 1; }; fi
  done
  return 0
}
# commit_receipt runs after the removal, so it never discards: the rename is
# retried, and a staging that still cannot be renamed is marked FINISHED and
# reported as the receipt under its staging name.
RECEIPT_PATH=""; RECEIPT_STAGED=""
commit_receipt() {
  local i=0
  # The marker first: it says Finish's removal and commit are done, so it may
  # exist only from here on; a renamed receipt keeps it harmlessly.
  if [ -z "${HYPERPOWERS_TEST_FAIL_MARKER:-}" ]; then : > "$RECEIPT_STAGING/FINISHED" 2>/dev/null; fi
  while [ "$i" -lt 3 ]; do
    if [ -z "${HYPERPOWERS_TEST_FAIL_RENAME:-}" ] && mv "$RECEIPT_STAGING" "$RECEIPT_FINAL" 2>/dev/null; then RECEIPT_PATH=$RECEIPT_FINAL; return 0; fi
    i=$((i + 1)); sleep 1
  done
  if [ -f "$RECEIPT_STAGING/FINISHED" ]; then RECEIPT_PATH=$RECEIPT_STAGING; return 0; fi
  # Neither the rename nor the marker could be written: the record exists but
  # no consumer accepts it; say so instead of claiming a receipt.
  RECEIPT_PATH=none; RECEIPT_STAGED=$RECEIPT_STAGING
  return 0
}
discard_receipt() { [ -n "$RECEIPT_STAGING" ] && rm -rf "$RECEIPT_STAGING"; RECEIPT_STAGING=""; }
```

In `cmd_finish`: after the `open-claims` check, `stage_receipt "$WSDIR" "$WS" || { hp_unlock; echo "status=error"; return 2; }`; every later failure path (`busy`, `error`, the `remove_verified` and `hp_commit_paths --remove` failures, the test hook `HYPERPOWERS_TEST_FAIL_REMOVE` which makes `remove_verified` return 2) calls `discard_receipt` before its status line; the two success paths call `commit_receipt` after the removal and its commit and print `status=finished backend=plain receipt=$RECEIPT_PATH` or `status=finished sha=${commit:0:7} last=$last push=$REMOTE/$BRANCH receipt=$RECEIPT_PATH`, appending ` staging=$RECEIPT_STAGED` when `RECEIPT_PATH` is `none` (`discard_receipt` is never called once the removal has started). In `cmd_prune`, a `--receipts` flag (exclusive with `--repo`): list every `<cache>/hyperpowers/receipts/*/` and `.staging-*/` whose directory mtime is older than `--days` as `receipt=<path> age_days=<n>` lines, with `stale=1` appended for a staging that has no `FINISHED` marker, remove them with `--apply`, and print `status=pruned receipts=<n>` (or `status=listed receipts=<n>`); `--receipts` needs no repository and takes no lock. Update `usage` for `prune [--receipts] [--days N] [--apply] [--repo DIR]`.

- [ ] **Step 4: Run the suites**

Run: `bash tests/sdd/test-sdd-state-finish-receipt.sh; bash tests/sdd/test-sdd-state.sh 2>&1 | tail -n 4; bash tests/sdd/test-sdd-common.sh | tail -n 2` — Expected: `STATUS: PASSED` three times.

- [ ] **Step 5: Document and commit**

Add `bash tests/sdd/test-sdd-state-finish-receipt.sh` to `docs/testing.md:25`. Leak scan, `git add skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/scripts/sdd-common.sh tests/sdd/test-sdd-state-finish-receipt.sh tests/sdd/test-sdd-state.sh docs/testing.md`, commit `feat(sdd): finish writes a two-phase receipt and snapshots keep a job's record without its scratch`.

---
### Task 6: The stop guard's discovery, plan state, job liveness and decision log

**Risk tier:** high — the first half of the module that refuses turn ends; it selects the plan a session belongs to and writes the durable decision record.

**Files:**
- Create: `hooks/lib/stop-guard.mjs` (the functions below; Task 7 adds the decision table and `main`, Task 8 the transcript reader)
- Create: `hooks/lib/stop-guard.test.mjs`
- Test runner until Task 9 creates the suite: `node --test hooks/lib/stop-guard.test.mjs`

**Interfaces:**
- Consumes: the ledger contract (`session <sid>:` lines; `Task N: complete` lines matched by `(^|[^A-Za-z0-9])Task N: complete`; `handback <sid> <UTC-ms>: <text>` lines from Task 2); `meta.json`'s `state` and the `exit` file (Tasks 3 and 4); receipts under `<cache>/hyperpowers/receipts/<name>/progress.md`, with staging directories dot-prefixed and counting only when they carry `FINISHED` (Task 5); the clone-key derivation of `sdd-common.sh:19-38`.
- Produces, exported: `CANDIDATE_CAP` (64), `REFUSAL_CAP` (2), `TAIL_CAP` (16 MiB), `TAIL_CHUNK` (512 KiB), `LIVE_JOB_STATES`; `cloneKey(cwd) -> string|null`; `discover({sessionId, cwd, cacheRoot}) -> {kind:'ledger', workspace, ledger} | {kind:'ambiguous', candidates, matches} | {kind:'receipt', receipt} | {kind:'none'}`; `planState({workspace, cwd, sessionId}) -> {plan, open, total} | {plan, unreadable:true}`; `liveJobs(workspace) -> {live: string[], unreadable: string[]}`; `handbackThisTurn(ledgerText, sessionId, promptTs) -> boolean`; `tailLines(path, sessionId, max=200) -> object[]`; `mergedDecisions(planLines, mirrorLines) -> object[]`; `refusalsBefore({workspaceLog, mirrorLog, sessionId}) -> number`; `appendLine(path, line) -> boolean`; `recordDecision({workspaceLog, mirrorLog, marker, line}) -> {line, loggedAs:'authoritative'|'log-failed'|'mirror-only'|'none'}`. Task 7's `main` composes these; Task 14's analyzer reads the lines `recordDecision` writes.

**Mirror:** `tests/pi/test-pi-extension.mjs:1-30` for the node test shape; `sdd-common.sh:19-38` for the key; `skills/subagent-driven-development/scripts/sdd-state:123-178` for the completion-line test.

- [ ] **Step 1: Write the failing tests**

Create `hooks/lib/stop-guard.test.mjs` with these helpers and cases (Tasks 7, 8 and 9 append their own):

```js
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import * as guard from './stop-guard.mjs';

const SID = 'sess-1234';
function makeRepo(root) {
  const repo = join(root, 'repo');
  mkdirSync(join(repo, 'docs'), { recursive: true });
  execFileSync('git', ['init', '-q', '-b', 'main', repo]);
  execFileSync('git', ['-C', repo, 'config', 'user.email', 't@example.com']);
  execFileSync('git', ['-C', repo, 'config', 'user.name', 't']);
  writeFileSync(join(repo, 'docs', 'plan.md'), '# Plan\n\n### Task 1: one\n\n### Task 2: two\n\n### Task 3: three\n');
  execFileSync('git', ['-C', repo, 'add', 'docs/plan.md']);
  execFileSync('git', ['-C', repo, 'commit', '-q', '-m', 'plan']);
  return repo;
}
function env() { const root = mkdtempSync(join(tmpdir(), 'sg-')); return { root, cache: join(root, 'cache'), repo: makeRepo(root) }; }
function workspaceFor(e, name = 'plan-abcdef12', backend = 'state', key = guard.cloneKey(e.repo)) {
  const ws = join(e.cache, 'hyperpowers', backend, key, 'plans', name);
  mkdirSync(ws, { recursive: true });
  return ws;
}
function ledger(ws, e, { sid = SID, tasksDone = [], extra = [], at = e.repo } = {}) {
  const lines = ['# SDD ledger — plan: docs/plan.md', `session ${sid}: mode worktree on main at ${at} started 2026-10-23T00:00:00Z`];
  for (const n of tasksDone) lines.push(`Task ${n}: complete (commits 1111111..2222222, review clean)`);
  lines.push(...extra);
  writeFileSync(join(ws, 'progress.md'), lines.join('\n') + '\n');
}
function receipt(e, name, sid = SID) {
  const r = join(e.cache, 'hyperpowers', 'receipts', name); mkdirSync(r, { recursive: true });
  writeFileSync(join(r, 'progress.md'), `# SDD ledger — plan: docs/plan.md\nsession ${sid}: mode worktree on main at ${e.repo} started x\n`);
  return r;
}
const mirrorOf = (e, sid = SID) => join(e.cache, 'hyperpowers', 'stop-guard', `${sid}.jsonl`);
const readLines = (p) => readFileSync(p, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));
const line = (ts, decision, reason, extra = {}) => ({ ts, session: SID, decision, reason, plan: 'docs/plan.md', open: 1, total: 3, live: [], refusals: 0, stop_hook_active: false, elapsed_ms: 1, ...extra });
const writeLog = (p, lines) => { mkdirSync(join(p, '..'), { recursive: true }); writeFileSync(p, lines.map((l) => JSON.stringify(l)).join('\n') + '\n'); };

test('discover: no ledger and no receipt is none', () => {
  const e = env();
  assert.deepEqual(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }), { kind: 'none' });
});
test('discover: one ledger carrying the session selects its workspace', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e); ledger(workspaceFor(e, 'other-00000000'), e, { sid: 'someone-else' });
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ledger'); assert.equal(d.workspace, ws); assert.equal(d.ledger, join(ws, 'progress.md'));
});
test('discover: two ledgers carrying the session are ambiguous', () => {
  const e = env(); ledger(workspaceFor(e, 'a-11111111'), e); ledger(workspaceFor(e, 'b-22222222'), e);
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ambiguous'); assert.equal(d.matches.length, 2); assert.equal(d.candidates, 2);
});
test('discover: 65 candidate ledgers are ambiguous before any is read', () => {
  const e = env();
  for (let i = 0; i < 65; i++) ledger(workspaceFor(e, `p${i}-0000000${i}`), e, { sid: 'other' });
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'ambiguous'); assert.equal(d.candidates, 65); assert.deepEqual(d.matches, []);
});
test('discover: a receipt carrying the session is found when no ledger does; a staging counts only with FINISHED', () => {
  const e = env();
  const staging = receipt(e, '.staging-plan-abcdef12-20261023T000001Z');
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).kind, 'none');
  writeFileSync(join(staging, 'FINISHED'), '');
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).receipt, staging);
  rmSync(staging, { recursive: true });
  const r = receipt(e, 'plan-abcdef12-20261023T000000Z');
  const d = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  assert.equal(d.kind, 'receipt'); assert.equal(d.receipt, r);
});
test('discover: with more than 64 receipts the newest 64 are read and an older match is invisible', () => {
  const e = env();
  const old = receipt(e, 'plan-aaaaaaaa-20200101T000000Z');
  execFileSync('touch', ['-t', '202001010000', join(old, 'progress.md')]);
  for (let i = 0; i < 64; i++) receipt(e, `p${i}-bbbbbbbb-20261023T0000${String(i).padStart(2, '0')}Z`, 'other');
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).kind, 'none');
});
test('discover: the plain cache is searched too, and a cwd outside any repository searches every key', () => {
  const e = env(); const ws = workspaceFor(e, 'plan-abcdef12', 'sdd'); ledger(ws, e);
  assert.equal(guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache }).workspace, ws);
  assert.equal(guard.discover({ sessionId: SID, cwd: tmpdir(), cacheRoot: e.cache }).workspace, ws);
});
test('planState: open and total from the plan and the ledger; the plan resolves through the session line', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1, 2] });
  assert.deepEqual(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }), { plan: 'docs/plan.md', open: 1, total: 3 });
  assert.deepEqual(guard.planState({ workspace: ws, cwd: tmpdir(), sessionId: SID }), { plan: 'docs/plan.md', open: 1, total: 3 });
  writeFileSync(join(ws, 'progress.md'), readFileSync(join(ws, 'progress.md'), 'utf8') + 'note: xTask 3: complete is prose, not a completion\n');
  assert.equal(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }).open, 1);
});
test('planState: a missing plan, or a ledger without the session line, is unreadable', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { sid: 'other' });
  assert.equal(guard.planState({ workspace: ws, cwd: tmpdir(), sessionId: SID }).unreadable, true);
  ledger(ws, e); rmSync(join(e.repo, 'docs', 'plan.md'));
  assert.equal(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }).unreadable, true);
});
test('liveJobs: running and lost-unswept are live; allocated, exited, lost, stopped and a job with an exit file are not', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  for (const [name, state] of [['b', 'running'], ['a', 'lost-unswept'], ['c', 'allocated'], ['d', 'exited'], ['e', 'lost'], ['f', 'stopped'], ['g', 'running']]) {
    mkdirSync(join(ws, 'jobs', `${name}-x-0001`), { recursive: true });
    writeFileSync(join(ws, 'jobs', `${name}-x-0001`, 'meta.json'), JSON.stringify({ name, state }));
  }
  writeFileSync(join(ws, 'jobs', 'g-x-0001', 'exit'), '0\n');
  mkdirSync(join(ws, 'jobs', '.new-abc123')); // an allocation in progress: no meta.json yet, not a job
  assert.deepEqual(guard.liveJobs(ws), { live: ['a', 'b'], unreadable: [] });
  mkdirSync(join(ws, 'jobs', 'h-x-0001')); writeFileSync(join(ws, 'jobs', 'h-x-0001', 'meta.json'), '{not json');
  assert.deepEqual(guard.liveJobs(ws), { live: ['a', 'b'], unreadable: ['h-x-0001'] });
});
test('handbackThisTurn: later than the prompt counts; the same millisecond, earlier, or another session does not', () => {
  const text = `handback ${SID} 2026-10-23T10:00:05.000Z: a question only you can answer\nhandback other 2026-10-23T10:00:09.000Z: x\n`;
  assert.equal(guard.handbackThisTurn(text, SID, '2026-10-23T10:00:04.999Z'), true);
  assert.equal(guard.handbackThisTurn(text, SID, '2026-10-23T10:00:05.000Z'), false);
  assert.equal(guard.handbackThisTurn(text, SID, '2026-10-23T10:00:05.500Z'), false);
  assert.equal(guard.handbackThisTurn(text, 'other', '2026-10-23T10:00:08.000Z'), true);
  assert.equal(guard.handbackThisTurn(text, 'nobody', '2026-10-23T10:00:00.000Z'), false);
});
test('refusalsBefore: consecutive blocks of the plan log since the last allow in either log', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e);
  const args = { workspaceLog: wl, mirrorLog: ml, sessionId: SID };
  assert.equal(guard.refusalsBefore(args), 0);
  const b1 = line('2026-10-23T10:00:00.100Z', 'block', 'open-tasks', { refusals: 1 }); const b2 = line('2026-10-23T10:01:00.100Z', 'block', 'open-tasks', { refusals: 2 });
  writeLog(wl, [b1, b2]); writeLog(ml, [b1, b2]);
  assert.equal(guard.refusalsBefore(args), 2);
  // a mirror-only allow (ambiguous) after the blocks resets the count
  writeLog(ml, [b1, b2, line('2026-10-23T10:02:00.000Z', 'allow', 'ambiguous', { plan: null })]);
  assert.equal(guard.refusalsBefore(args), 0);
  // a hook-error line written by the wrapper carries a coarser timestamp that sorts before the block it follows: file order wins
  writeLog(ml, [b1, b2, { ts: '2026-10-23T10:01:00Z', session: SID, decision: 'allow', reason: 'hook-error', detail: 'module exit 1' }]);
  assert.equal(guard.refusalsBefore(args), 0);
  // a line only in the plan log is placed by its timestamp
  writeLog(ml, [b1]); writeLog(wl, [b1, b2]);
  assert.equal(guard.refusalsBefore(args), 2);
  // blocks found only in the mirror belong to another plan: neither counted nor a reset
  writeLog(wl, []); writeLog(ml, [line('2026-10-23T09:00:00.000Z', 'block', 'open-tasks', { plan: 'docs/earlier.md', refusals: 1 }), line('2026-10-23T09:01:00.000Z', 'block', 'open-tasks', { plan: 'docs/earlier.md', refusals: 2 })]);
  assert.equal(guard.refusalsBefore(args), 0);
  // an unreadable mirror leaves the plan log to answer
  writeLog(wl, [b1, b2]); chmodSync(ml, 0o000);
  assert.equal(guard.refusalsBefore(args), 2);
  chmodSync(ml, 0o644);
});
test('recordDecision: the plan log first, then the mirror; failures become log-failed, mirror_failed, or nothing', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  let r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'authoritative'); assert.equal(readLines(wl).length, 1); assert.deepEqual(readLines(ml), readLines(wl));
  // the mirror unwritable: the plan log has the line, the marker is left, the next line carries mirror_failed and clears it
  chmodSync(ml, 0o444);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:01:00.000Z', 'block', 'open-tasks', { refusals: 2 }) });
  assert.equal(r.loggedAs, 'authoritative'); assert.equal(existsSync(marker), true); assert.equal(readLines(wl).length, 2); assert.equal(readLines(ml).length, 1);
  chmodSync(ml, 0o644);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:02:00.000Z', 'allow', 'handback-text') });
  assert.equal(r.line.mirror_failed, true); assert.equal(existsSync(marker), false); assert.equal(readLines(ml).at(-1).mirror_failed, true);
  // the plan log unwritable: one log-failed allow in the mirror and nothing else, whatever the decision was
  chmodSync(wl, 0o444);
  const before = readLines(wl).length; const beforeMirror = readLines(ml).length;
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:03:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'log-failed'); assert.equal(r.line.decision, 'allow'); assert.equal(r.line.reason, 'log-failed'); assert.equal(r.line.refusals, 0);
  assert.equal(readLines(wl).length, before); assert.equal(readLines(ml).length, beforeMirror + 1); assert.equal(readLines(ml).at(-1).reason, 'log-failed');
  // both unwritable: nothing recorded, the allow stands
  chmodSync(ml, 0o444);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:04:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'none'); assert.equal(r.line.decision, 'allow'); assert.equal(readLines(ml).length, beforeMirror + 1);
  chmodSync(ml, 0o644); chmodSync(wl, 0o644);
  // no workspace (ambiguous, receipt): the mirror only
  r = guard.recordDecision({ workspaceLog: null, mirrorLog: ml, marker: null, line: line('2026-10-23T10:05:00.000Z', 'allow', 'no-ledger', { plan: null, receipt: '/r' }) });
  assert.equal(r.loggedAs, 'mirror-only'); assert.equal(readLines(ml).at(-1).receipt, '/r');
});
test('recordDecision: a pending mirror_failed marker survives a double write failure and is reported by the next line that reaches a log', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e);
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e); const marker = join(ws, '.mirror-failed');
  writeFileSync(marker, ''); writeLog(wl, []); writeLog(ml, []); chmodSync(wl, 0o444); chmodSync(ml, 0o444);
  let r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:00:00.000Z', 'block', 'open-tasks', { refusals: 1 }) });
  assert.equal(r.loggedAs, 'none'); assert.equal(existsSync(marker), true);
  chmodSync(wl, 0o644); chmodSync(ml, 0o644);
  r = guard.recordDecision({ workspaceLog: wl, mirrorLog: ml, marker, line: line('2026-10-23T10:01:00.000Z', 'allow', 'handback-text') });
  assert.equal(r.line.mirror_failed, true); assert.equal(existsSync(marker), false); assert.equal(readLines(wl).at(-1).mirror_failed, true); assert.equal(readLines(ml).at(-1).mirror_failed, true);
});
test('cloneKey: null outside a repository, stable inside one', () => {
  const e = env();
  assert.equal(guard.cloneKey(tmpdir()), null);
  assert.match(guard.cloneKey(e.repo), /^[0-9a-f]{40}$/);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test hooks/lib/stop-guard.test.mjs 2>&1 | tail -n 5` — Expected: every test fails (`Cannot find module`).

- [ ] **Step 3: Write the module's first half**

Create `hooks/lib/stop-guard.mjs`:

```js
// The SDD stop guard: refuses a turn end it can prove premature (a plan ledger
// found for this session, nothing handed back, nothing tracked live), twice in
// a row per plan, logging every decision. Fails open on every doubt.
// Design: docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md (Design §1).
import { execFileSync } from 'node:child_process';
import { appendFileSync, closeSync, existsSync, fstatSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, realpathSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

export const CANDIDATE_CAP = 64;
export const REFUSAL_CAP = 2;
export const TAIL_CAP = 16 * 1024 * 1024;
export const TAIL_CHUNK = 512 * 1024;
export const LIVE_JOB_STATES = new Set(['running', 'lost-unswept']);
const COMPLETE = (n) => new RegExp(`(^|[^A-Za-z0-9])Task ${n}: complete`, 'm');
const TASK_HEADING = /^### Task (\d+):/gm;
const HANDBACK = /^handback (\S+) (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z): /;

function git(cwd, args, input) {
  try { return execFileSync('git', ['-C', cwd, ...args], { encoding: 'utf8', input, stdio: [input === undefined ? 'ignore' : 'pipe', 'pipe', 'ignore'] }).trim(); } catch { return null; }
}
// sdd-common.sh hp_common_dir and hp_key: the physical common git directory,
// hashed with the repository's own hash-object. Null outside a repository.
export function cloneKey(cwd) {
  if (!cwd || !existsSync(cwd)) return null;
  let d = git(cwd, ['rev-parse', '--path-format=absolute', '--git-common-dir']);
  if (!d || d.includes('\n') || !existsSync(d)) {
    d = git(cwd, ['rev-parse', '--git-common-dir']);
    if (!d) return null;
    if (!d.startsWith('/')) d = join(realpathSync(cwd), d);
  }
  if (!existsSync(d)) return null;
  return git(cwd, ['hash-object', '--stdin'], realpathSync(d)) || null;
}

function ledgersUnder(plansDir) {
  const out = [];
  if (!existsSync(plansDir)) return out;
  for (const ws of readdirSync(plansDir)) { const p = join(plansDir, ws, 'progress.md'); if (existsSync(p)) out.push(p); }
  return out;
}
function newestFirst(paths) {
  return paths.map((p) => { try { return { p, m: statSync(p).mtimeMs }; } catch { return null; } }).filter(Boolean).sort((a, b) => b.m - a.m).map((x) => x.p);
}
function carriesSession(path, sessionId) {
  try { return readFileSync(path, 'utf8').split('\n').some((l) => l.startsWith(`session ${sessionId}:`)); } catch { return false; }
}
// Step A. Candidates are the ledgers under this clone's key (every key when
// cwd is outside a repository), newest first; more than the cap is ambiguous
// before any is read. Receipts are the fallback for a session whose plan has
// finished: only the newest 64 are read, because a receipt this session wrote
// is by construction among them and reading every receipt on a long-lived
// host would turn every session's Stop into a logged ambiguity.
export function discover({ sessionId, cwd, cacheRoot }) {
  const hp = join(cacheRoot, 'hyperpowers');
  const key = cloneKey(cwd);
  let candidates = [];
  for (const backend of ['state', 'sdd']) {
    const root = join(hp, backend);
    if (key) candidates.push(...ledgersUnder(join(root, key, 'plans')));
    else if (existsSync(root)) for (const k of readdirSync(root)) candidates.push(...ledgersUnder(join(root, k, 'plans')));
  }
  if (candidates.length > CANDIDATE_CAP) return { kind: 'ambiguous', candidates: candidates.length, matches: [] };
  candidates = newestFirst(candidates);
  const matches = candidates.filter((p) => carriesSession(p, sessionId));
  if (matches.length === 1) return { kind: 'ledger', workspace: dirname(matches[0]), ledger: matches[0] };
  if (matches.length > 1) return { kind: 'ambiguous', candidates: candidates.length, matches };
  const receipts = join(hp, 'receipts');
  if (existsSync(receipts)) {
    // A dot-prefixed staging is a receipt only once finish marked it FINISHED
    // (its final rename failed after the workspace was removed, Task 5).
    const all = readdirSync(receipts).filter((r) => !r.startsWith('.') || existsSync(join(receipts, r, 'FINISHED'))).map((r) => join(receipts, r, 'progress.md')).filter((p) => existsSync(p));
    const hit = newestFirst(all).slice(0, CANDIDATE_CAP).find((p) => carriesSession(p, sessionId));
    if (hit) return { kind: 'receipt', receipt: dirname(hit) };
  }
  return { kind: 'none' };
}

// Step B. The plan path from the ledger's first line, resolved against the
// toplevel this session's line records, then against cwd's toplevel.
export function planState({ workspace, cwd, sessionId }) {
  let text;
  try { text = readFileSync(join(workspace, 'progress.md'), 'utf8'); } catch { return { plan: null, unreadable: true }; }
  const m = (text.split('\n')[0] || '').match(/^# SDD ledger — plan: (.+)$/);
  if (!m) return { plan: null, unreadable: true };
  const rel = m[1].trim();
  const roots = [];
  const sess = text.split('\n').find((l) => l.startsWith(`session ${sessionId}:`));
  const at = sess && sess.match(/ at (\S+) started /);
  if (at) roots.push(at[1]);
  const top = git(cwd, ['rev-parse', '--show-toplevel']);
  if (top) roots.push(top);
  let planText = null;
  for (const r of roots) {
    const p = rel.startsWith('/') ? rel : join(r, rel);
    try { planText = readFileSync(p, 'utf8'); break; } catch { /* the next root */ }
  }
  if (planText === null) return { plan: rel, unreadable: true };
  const tasks = [...new Set([...planText.matchAll(TASK_HEADING)].map((x) => Number(x[1])))];
  const done = tasks.filter((n) => COMPLETE(n).test(text)).length;
  return { plan: rel, total: tasks.length, open: tasks.length - done };
}

// A job is live while its supervisor runs or while a lost job awaits its
// sweep (lost-unswept, plan deviation 2); an exit file ends it whatever the
// state says, so a supervisor that died between writing exit and meta.json
// does not pin the session.
// A record that exists but cannot be read is uncertainty, not absence: it is
// returned as unreadable and main allows on it (hook-error with the detail).
export function liveJobs(workspace) {
  const jobs = join(workspace, 'jobs');
  const out = { live: [], unreadable: [] };
  if (!existsSync(jobs)) return out;
  for (const d of readdirSync(jobs)) {
    const metaPath = join(jobs, d, 'meta.json');
    if (d.startsWith('.') || !existsSync(metaPath)) continue; // an allocation still in progress is not a job yet
    try {
      const m = JSON.parse(readFileSync(metaPath, 'utf8'));
      if (LIVE_JOB_STATES.has(m.state) && !existsSync(join(jobs, d, 'exit'))) out.live.push(String(m.name || d));
    } catch { out.unreadable.push(d); }
  }
  out.live.sort(); out.unreadable.sort();
  return out;
}

export function handbackThisTurn(ledgerText, sessionId, promptTs) {
  const prompt = Date.parse(promptTs);
  if (Number.isNaN(prompt)) return false;
  for (const l of ledgerText.split('\n')) {
    const m = l.match(HANDBACK);
    if (m && m[1] === sessionId && Date.parse(m[2]) > prompt) return true;
  }
  return false;
}

// The last `max` lines of a log that belong to this session, in file order.
export function tailLines(path, sessionId, max = 200) {
  try {
    return readFileSync(path, 'utf8').split('\n').filter(Boolean).slice(-max)
      .map((l) => { try { return JSON.parse(l); } catch { return null; } })
      .filter((l) => l && l.session === sessionId);
  } catch { return []; }
}
const keyOf = (l) => `${l.ts}|${l.session}`;
// The cap's view of the record: the mirror in file order (the order decisions
// were made, which a wrapper line's second-resolution timestamp would
// misplace), with lines found only in the plan log inserted by timestamp.
// Each entry says whether the plan log holds it.
export function mergedDecisions(planLines, mirrorLines) {
  const inPlan = new Set(planLines.map(keyOf));
  const inMirror = new Set(mirrorLines.map(keyOf));
  const merged = mirrorLines.map((l) => ({ ...l, inPlanLog: inPlan.has(keyOf(l)) }));
  for (const a of planLines) {
    if (inMirror.has(keyOf(a))) continue;
    let i = merged.length;
    while (i > 0 && String(merged[i - 1].ts) > String(a.ts)) i--;
    merged.splice(i, 0, { ...a, inPlanLog: true });
  }
  return merged;
}
// Consecutive refusals of this plan since the last allow in either log. A
// block the mirror alone holds belongs to another plan of the session and
// neither counts nor resets.
export function refusalsBefore({ workspaceLog, mirrorLog, sessionId }) {
  const merged = mergedDecisions(tailLines(workspaceLog, sessionId), tailLines(mirrorLog, sessionId));
  let n = 0;
  for (let i = merged.length - 1; i >= 0; i--) {
    if (merged[i].decision === 'allow') break;
    if (merged[i].decision === 'block' && merged[i].inPlanLog) n++;
  }
  return n;
}

// One JSON line, built whole, appended with one write.
export function appendLine(path, line) {
  try { mkdirSync(dirname(path), { recursive: true }); appendFileSync(path, JSON.stringify(line) + '\n'); return true; } catch { return false; }
}
// The plan log first, then its copy in the mirror. A failed plan-log write
// turns the decision into a log-failed allow that goes to the mirror alone;
// a failed mirror write leaves a marker so the next line carries
// mirror_failed. Returns the line as recorded and where it went.
export function recordDecision({ workspaceLog, mirrorLog, marker, line }) {
  const out = { ...line };
  const pending = Boolean(marker && existsSync(marker));
  if (pending) out.mirror_failed = true;
  // The marker is cleared only once a line carrying mirror_failed reached a
  // log; a decision that reaches neither leaves it for the next one.
  const clear = () => { if (pending) { try { rmSync(marker); } catch { /* the next line repeats it */ } } };
  if (!workspaceLog) { const ok = appendLine(mirrorLog, out); if (ok) clear(); return { line: out, loggedAs: ok ? 'mirror-only' : 'none' }; }
  if (!appendLine(workspaceLog, out)) {
    const failed = { ...out, decision: 'allow', reason: 'log-failed', refusals: 0 };
    const ok = appendLine(mirrorLog, failed); if (ok) clear();
    return { line: failed, loggedAs: ok ? 'log-failed' : 'none' };
  }
  clear();
  if (!appendLine(mirrorLog, out) && marker) { try { writeFileSync(marker, ''); } catch { /* best effort */ } }
  return { line: out, loggedAs: 'authoritative' };
}
// Task 7 appends asksOrBlocks, the messages, decideStop and main; Task 8 the
// transcript reader. closeSync, fstatSync, openSync and readSync are theirs.
void closeSync; void fstatSync; void openSync; void readSync;
```

Both logs carry `session`, so `tailLines` filters by it; the 200-line tail is a known limit recorded in the evidence note (the logs hold a few hundred lines at most, and the cap only needs the lines since the last allow).

- [ ] **Step 4: Run the tests until they pass**

Run: `node --test hooks/lib/stop-guard.test.mjs` — Expected: all pass.

- [ ] **Step 5: Commit**

Leak scan, `git add hooks/lib/stop-guard.mjs hooks/lib/stop-guard.test.mjs`, commit `feat(hooks): the stop guard finds a session's plan and keeps its decision log`.

---

### Task 7: The decision table and `main`

**Risk tier:** high — the table is the release guarantee; `main` is what the wrapper runs.

**Files:**
- Modify: `hooks/lib/stop-guard.mjs` (append `asksOrBlocks`, the two messages, `decideStop`, a minimal `readTurn`, `main`)
- Modify: `hooks/lib/stop-guard.test.mjs` (append the decision cases)

**Interfaces:**
- Consumes: Task 6's exports; the hand-labelled sample in `evals/evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` (class `Heuristic`, attribute `CASES`).
- Produces, exported: `asksOrBlocks(text) -> boolean` (the verbatim port of `liveness.asks_or_blocks`); `openTasksMessage(plan, state, sid)` and `liveShellMessage(plan, state, names, sid)` (the two strings of Global Constraints); `decideStop({discovery, plan, turn, jobs, jobsUnreadable?, refusals, sessionId, ledgerText?}) -> {decision:'allow'|'block', reason, state?, message?, detail?}` (an unreadable job record allows as `hook-error` with the detail) where `turn` is `{ok, tooLong, promptTs, lastAssistantText, liveAgents, liveShells, detail?}`; `readTurn(transcriptPath)` (minimal, replaced in Task 8); `main(stdinText, env) -> {stdout, exitCode}` honouring the test variables `STOP_GUARD_TURN` (a JSON turn used instead of the transcript) and `STOP_GUARD_FAULT=throw` (throws after deciding, before writing). Task 9's wrapper runs `main`; Task 10's skill text quotes the messages.

**Mirror:** `evidence/2026-10-19-sdd-turn-liveness/liveness.py:376-391` (`asks_or_blocks`, `APPROVAL`, `SENTENCE_END`), ported line for line.

- [ ] **Step 1: Append the failing tests**

```js
const HEURISTIC_CASES = [
  // Transcribed verbatim from evals evidence/2026-10-19-sdd-turn-liveness/test_liveness.py, class Heuristic, CASES: [text, expected]. Every pair.
];
const turn = (o = {}) => ({ ok: true, tooLong: false, promptTs: '2026-10-23T10:00:00.000Z', lastAssistantText: 'Tasks 1 and 2 are done. Moving to Task 3.', liveAgents: [], liveShells: [], ...o });
function decide(e, ws, t) {
  const discovery = guard.discover({ sessionId: SID, cwd: e.repo, cacheRoot: e.cache });
  const plan = discovery.kind === 'ledger' ? guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }) : null;
  const refusals = discovery.kind === 'ledger' ? guard.refusalsBefore({ workspaceLog: join(ws, 'stop-guard.jsonl'), mirrorLog: mirrorOf(e), sessionId: SID }) : 0;
  const jobsRead = discovery.kind === 'ledger' ? guard.liveJobs(ws) : { live: [], unreadable: [] };
  return guard.decideStop({ discovery, plan, turn: t, jobs: jobsRead.live, jobsUnreadable: jobsRead.unreadable, refusals, sessionId: SID });
}
const input = (e, extra = {}) => JSON.stringify({ session_id: SID, transcript_path: join(e.root, 't.jsonl'), cwd: e.repo, hook_event_name: 'Stop', stop_hook_active: false, ...extra });
const step = (e, t, extra = {}, envExtra = {}) => guard.main(input(e, extra), { XDG_CACHE_HOME: e.cache, STOP_GUARD_TURN: JSON.stringify(t), ...envExtra });

test('the hand-labelled sample', () => {
  assert.ok(HEURISTIC_CASES.length > 10, 'transcribe the sample first');
  for (const [text, expected] of HEURISTIC_CASES) assert.equal(guard.asksOrBlocks(text), expected, text);
});
test('open tasks with a status message: block, open-tasks, the exact message', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1, 2] });
  const r = decide(e, ws, turn());
  assert.equal(r.decision, 'block'); assert.equal(r.reason, 'open-tasks');
  assert.equal(r.message, guard.openTasksMessage('docs/plan.md', '1 of 3 tasks open', SID));
  assert.equal(r.message, `SDD stop guard: plan docs/plan.md is not finished (1 of 3 tasks open; nothing tracked is live). Take the next step now, in this turn. If you are handing back to your human partner (a question only they can answer, a BLOCKED report, or they asked you to stop), run scripts/sdd-state handback PLAN_FILE --session ${SID} --reason "<why>" and end the turn with that message.`);
});
test('all tasks complete with the ledger present: block, the final-review state', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1, 2, 3] });
  const r = decide(e, ws, turn({ lastAssistantText: 'All three tasks are complete. Final review next.' }));
  assert.equal(r.decision, 'block'); assert.match(r.message, /\(all 3 tasks complete; the final review and Finish remain; nothing tracked is live\)/);
});
test('a question, BLOCKED, and the approval pattern allow as handback-text', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  for (const text of ['Which option do you want?', 'BLOCKED: the fixture is missing.', 'Two tasks are done. Let me know how you want to proceed.']) {
    const r = decide(e, ws, turn({ lastAssistantText: text }));
    assert.equal(r.decision, 'allow', text); assert.equal(r.reason, 'handback-text', text);
  }
});
test('a hand-back line after the prompt allows as handback-line; at or before it does not', () => {
  const e = env(); const ws = workspaceFor(e);
  ledger(ws, e, { tasksDone: [1], extra: [`handback ${SID} 2026-10-23T10:00:05.000Z: a question only you can answer`] });
  assert.equal(decide(e, ws, turn({ promptTs: '2026-10-23T10:00:00.000Z' })).reason, 'handback-line');
  assert.equal(decide(e, ws, turn({ promptTs: '2026-10-23T10:00:05.000Z' })).reason, 'open-tasks');
  assert.equal(decide(e, ws, turn({ promptTs: '2026-10-23T10:00:05.500Z' })).reason, 'open-tasks');
});
test('a live tracked agent allows; a live shell blocks with the live-shell message; a running job counts as a shell', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  assert.equal(decide(e, ws, turn({ liveAgents: ['toolu_a'] })).reason, 'live-agent');
  assert.equal(decide(e, ws, turn({ liveAgents: ['toolu_a'], liveShells: ['toolu_b'] })).reason, 'live-agent');
  let r = decide(e, ws, turn({ liveShells: ['toolu_b'] }));
  assert.equal(r.decision, 'block'); assert.equal(r.reason, 'live-shell');
  assert.equal(r.message, guard.liveShellMessage('docs/plan.md', '2 of 3 tasks open', ['toolu_b'], SID));
  assert.match(r.message, /^SDD stop guard: plan docs\/plan\.md is not finished \(2 of 3 tasks open; job\(s\) toolu_b are live\)\. Job\(s\) toolu_b are still running: watch them in the foreground with tracked-job wait, and report a lost-unswept job to your human partner with its pgid\. If you are handing back/);
  mkdirSync(join(ws, 'jobs', 'soak-x-0001'), { recursive: true }); writeFileSync(join(ws, 'jobs', 'soak-x-0001', 'meta.json'), JSON.stringify({ name: 'soak', state: 'running' }));
  r = decide(e, ws, turn());
  assert.equal(r.reason, 'live-shell'); assert.match(r.message, /job\(s\) soak are live/);
});
test('ambiguous, receipt and no-plan allow with their reasons', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e); ledger(workspaceFor(e, 'b-22222222'), e);
  assert.equal(decide(e, ws, turn()).reason, 'ambiguous');
  rmSync(join(e.cache, 'hyperpowers', 'state'), { recursive: true }); receipt(e, 'plan-abcdef12-20261023T000000Z');
  assert.equal(decide(e, null, turn()).reason, 'no-ledger');
  const ws2 = workspaceFor(e); ledger(ws2, e); rmSync(join(e.repo, 'docs', 'plan.md'));
  assert.equal(decide(e, ws2, turn()).reason, 'no-plan');
});
test('an unreadable job record allows as hook-error with the detail, and is logged to both logs', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  mkdirSync(join(ws, 'jobs', 'bad-x-0001'), { recursive: true }); writeFileSync(join(ws, 'jobs', 'bad-x-0001', 'meta.json'), '{not json');
  const r = step(e, turn());
  assert.equal(r.stdout, '');
  const last = readLines(join(ws, 'stop-guard.jsonl')).at(-1);
  assert.equal(last.decision, 'allow'); assert.equal(last.reason, 'hook-error'); assert.match(last.detail, /job meta unreadable: bad-x-0001/);
  assert.deepEqual(readLines(mirrorOf(e)).at(-1), last);
});
test('a turn that is not ok allows as turn-too-long, with the detail', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  assert.equal(decide(e, ws, turn({ ok: false, tooLong: true })).reason, 'turn-too-long');
  const r = decide(e, ws, turn({ ok: false, tooLong: false, detail: 'no-prompt' }));
  assert.equal(r.reason, 'turn-too-long'); assert.equal(r.detail, 'no-prompt');
});
test('main: block, block, cap, block, block, cap; a hand-back resets; stop_hook_active is logged and never decides', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  const wl = join(ws, 'stop-guard.jsonl');
  step(e, turn()); step(e, turn(), { stop_hook_active: true }); step(e, turn(), { stop_hook_active: true });
  assert.deepEqual(readLines(wl).map((l) => [l.decision, l.reason, l.refusals, l.stop_hook_active]), [['block', 'open-tasks', 1, false], ['block', 'open-tasks', 2, true], ['allow', 'cap', 0, true]]);
  step(e, turn()); step(e, turn()); const third = step(e, turn());
  assert.deepEqual(readLines(wl).slice(3).map((l) => l.reason), ['open-tasks', 'open-tasks', 'cap']); assert.equal(third.stdout, '');
  step(e, turn({ lastAssistantText: 'Which option do you want?' })); step(e, turn()); const r = step(e, turn());
  assert.deepEqual(readLines(wl).slice(6).map((l) => [l.reason, l.refusals]), [['handback-text', 0], ['open-tasks', 1], ['open-tasks', 2]]);
  assert.deepEqual(JSON.parse(r.stdout).decision, 'block');
  assert.deepEqual(readLines(mirrorOf(e)).map((l) => l.ts), readLines(wl).map((l) => l.ts));
  assert.ok(readLines(wl).every((l) => ['ts', 'session', 'decision', 'reason', 'plan', 'open', 'total', 'live', 'refusals', 'stop_hook_active', 'elapsed_ms'].every((k) => k in l)));
});
test('main: a mirror-only allow between refusals resets the count (ambiguous, and log-failed)', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  const wl = join(ws, 'stop-guard.jsonl');
  step(e, turn()); step(e, turn());
  const ws2 = workspaceFor(e, 'other-99999999'); ledger(ws2, e);
  assert.equal(step(e, turn()).stdout, ''); // ambiguous: two ledgers carry the session
  rmSync(ws2, { recursive: true });
  step(e, turn());
  assert.deepEqual(readLines(wl).map((l) => [l.reason, l.refusals]), [['open-tasks', 1], ['open-tasks', 2], ['open-tasks', 1]]);
  assert.equal(readLines(mirrorOf(e))[2].reason, 'ambiguous');
  step(e, turn()); // refusals 2
  chmodSync(wl, 0o444);
  assert.equal(step(e, turn()).stdout, ''); // log-failed: the mirror alone records it
  chmodSync(wl, 0o644);
  step(e, turn());
  assert.deepEqual(readLines(wl).slice(3).map((l) => [l.reason, l.refusals]), [['open-tasks', 2], ['open-tasks', 1]]);
  assert.equal(readLines(mirrorOf(e)).at(-2).reason, 'log-failed');
  assert.equal(readLines(mirrorOf(e)).length, readLines(wl).length + 2);
});
test('main: a finished plan\'s refusals do not count for the next plan in the same session', () => {
  const e = env(); const wsA = workspaceFor(e, 'a-11111111'); ledger(wsA, e, { tasksDone: [1] });
  step(e, turn()); step(e, turn());
  rmSync(wsA, { recursive: true }); receipt(e, 'a-11111111-20261023T000000Z');
  assert.equal(readLines(mirrorOf(e)).length, 2);
  step(e, turn()); // no-ledger with the receipt: mirror only
  assert.equal(readLines(mirrorOf(e)).at(-1).reason, 'no-ledger');
  const wsB = workspaceFor(e, 'b-22222222'); ledger(wsB, e, { tasksDone: [1] });
  const r = step(e, turn());
  assert.match(r.stdout, /"decision":"block"/); assert.deepEqual(readLines(join(wsB, 'stop-guard.jsonl')).map((l) => l.refusals), [1]);
});
test('main: both logs unwritable records nothing and allows; a failed mirror write marks the next line', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  const wl = join(ws, 'stop-guard.jsonl'); const ml = mirrorOf(e);
  writeLog(wl, []); writeLog(ml, []); chmodSync(wl, 0o444); chmodSync(ml, 0o444);
  const r = step(e, turn());
  assert.equal(r.stdout, ''); assert.equal(r.exitCode, 0); assert.equal(readFileSync(ml, 'utf8'), ''); assert.equal(readFileSync(wl, 'utf8'), '');
  chmodSync(wl, 0o644);
  step(e, turn()); chmodSync(ml, 0o644); step(e, turn());
  assert.deepEqual(readLines(wl).map((l) => l.mirror_failed), [undefined, true]);
});
test('main: no session id, malformed input, or no plan writes nothing', () => {
  const e = env();
  for (const text of ['', 'not json', JSON.stringify({ transcript_path: '/x' }), JSON.stringify({ session_id: '../x', cwd: e.repo }), input(e)]) {
    const r = guard.main(text, { XDG_CACHE_HOME: e.cache, STOP_GUARD_TURN: JSON.stringify(turn()) });
    assert.equal(r.stdout, ''); assert.equal(r.exitCode, 0);
  }
  assert.equal(existsSync(join(e.cache, 'hyperpowers', 'stop-guard')), false);
});
test('main: the fault variable throws after deciding and before writing', () => {
  const e = env(); const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  assert.throws(() => step(e, turn(), {}, { STOP_GUARD_FAULT: 'throw' }), /injected/);
  assert.equal(existsSync(join(ws, 'stop-guard.jsonl')), false);
});
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `node --test hooks/lib/stop-guard.test.mjs 2>&1 | grep -c "^not ok"` — Expected: at least 10.

- [ ] **Step 3: Append the decision core**

Append to `hooks/lib/stop-guard.mjs`, replacing the `void` line at its end:

```js
// liveness.asks_or_blocks, ported verbatim.
const APPROVAL = /\b(?:say (?:the word|["']?(?:continue|proceed|go|resume)["']?)|let me know|your call|which (?:option|one|do you)|do you want|would you like|shall i|should i|want me to|approve|for your review|for you to review|when(?:ever)? you(?:'re| are) ready|your go-ahead|decision is yours|is yours to make)\b/i;
const SENTENCE_END = /(?<=[.!?])\s+/;
export function asksOrBlocks(text) {
  if (text.includes('BLOCKED')) return true;
  const stripped = text.trim();
  if (!stripped) return false;
  const sentences = stripped.split(SENTENCE_END);
  if (sentences[sentences.length - 1].replace(/[ *_`)"']+$/, '').endsWith('?')) return true;
  return APPROVAL.test(sentences.slice(-3).join(' '));
}

const handbackHint = (sid) => `If you are handing back to your human partner (a question only they can answer, a BLOCKED report, or they asked you to stop), run scripts/sdd-state handback PLAN_FILE --session ${sid} --reason "<why>" and end the turn with that message.`;
export function openTasksMessage(plan, state, sid) {
  return `SDD stop guard: plan ${plan} is not finished (${state}; nothing tracked is live). Take the next step now, in this turn. ${handbackHint(sid)}`;
}
export function liveShellMessage(plan, state, names, sid) {
  const list = names.join(', ');
  return `SDD stop guard: plan ${plan} is not finished (${state}; job(s) ${list} are live). Job(s) ${list} are still running: watch them in the foreground with tracked-job wait, and report a lost-unswept job to your human partner with its pgid. ${handbackHint(sid)}`;
}

// Step D, in the spec's order. log-failed is decided at write time by
// recordDecision, which is why it is absent here.
export function decideStop({ discovery, plan, turn, jobs, jobsUnreadable = [], refusals, sessionId, ledgerText = null }) {
  if (discovery.kind !== 'ledger') return { decision: 'allow', reason: discovery.kind === 'ambiguous' ? 'ambiguous' : 'no-ledger' };
  if (!plan || plan.unreadable) return { decision: 'allow', reason: 'no-plan' };
  const state = plan.open > 0 ? `${plan.open} of ${plan.total} tasks open` : `all ${plan.total} tasks complete; the final review and Finish remain`;
  // A job record that cannot be read is not evidence that nothing is live: allow, and say which.
  if (jobsUnreadable.length) return { decision: 'allow', reason: 'hook-error', state, detail: `job meta unreadable: ${jobsUnreadable.join(', ')}` };
  if (!turn.ok || turn.tooLong) return { decision: 'allow', reason: 'turn-too-long', state, ...(turn.detail ? { detail: turn.detail } : {}) };
  if ((turn.liveAgents || []).length) return { decision: 'allow', reason: 'live-agent', state };
  const text = ledgerText ?? (() => { try { return readFileSync(discovery.ledger, 'utf8'); } catch { return ''; } })();
  if (handbackThisTurn(text, sessionId, turn.promptTs)) return { decision: 'allow', reason: 'handback-line', state };
  if (asksOrBlocks(turn.lastAssistantText || '')) return { decision: 'allow', reason: 'handback-text', state };
  if (refusals >= REFUSAL_CAP) return { decision: 'allow', reason: 'cap', state };
  const live = [...(turn.liveShells || []), ...jobs];
  if (live.length) return { decision: 'block', reason: 'live-shell', state, message: liveShellMessage(plan.plan, state, live, sessionId) };
  return { decision: 'block', reason: 'open-tasks', state, message: openTasksMessage(plan.plan, state, sessionId) };
}

// Minimal turn reader for this task's tests; Task 8 replaces it.
export function readTurn(transcriptPath) {
  const none = { ok: false, tooLong: false, promptTs: null, lastAssistantText: '', liveAgents: [], liveShells: [], detail: 'unreadable' };
  try {
    const recs = readFileSync(transcriptPath, 'utf8').split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
    let promptTs = null; let lastAssistantText = '';
    for (const r of recs) {
      if (r.type === 'user' && typeof r.message?.content === 'string' && !r.isMeta) { promptTs = r.timestamp; lastAssistantText = ''; }
      if (r.type === 'assistant' && Array.isArray(r.message?.content)) { const t = r.message.content.filter((b) => b.type === 'text').map((b) => b.text).join('\n'); if (t) lastAssistantText = t; }
    }
    return promptTs ? { ok: true, tooLong: false, promptTs, lastAssistantText, liveAgents: [], liveShells: [] } : { ...none, detail: 'no-prompt' };
  } catch { return none; }
}

export function main(stdinText, env = process.env) {
  const started = Date.now();
  let input;
  try { input = JSON.parse(stdinText || '{}'); } catch { return { stdout: '', exitCode: 0 }; }
  if (!input || typeof input !== 'object') return { stdout: '', exitCode: 0 };
  const sessionId = String(input.session_id || '');
  if (!sessionId || /[^A-Za-z0-9._-]/.test(sessionId)) return { stdout: '', exitCode: 0 };
  const cwd = String(input.cwd || process.cwd());
  const cacheRoot = env.XDG_CACHE_HOME || join(env.HOME || '', '.cache');
  const mirrorLog = join(cacheRoot, 'hyperpowers', 'stop-guard', `${sessionId}.jsonl`);
  const discovery = discover({ sessionId, cwd, cacheRoot });
  if (discovery.kind === 'none') return { stdout: '', exitCode: 0 };
  const workspace = discovery.kind === 'ledger' ? discovery.workspace : null;
  const workspaceLog = workspace ? join(workspace, 'stop-guard.jsonl') : null;
  const marker = workspace ? join(workspace, '.mirror-failed') : null;
  const plan = workspace ? planState({ workspace, cwd, sessionId }) : null;
  const turn = env.STOP_GUARD_TURN ? JSON.parse(env.STOP_GUARD_TURN) : readTurn(String(input.transcript_path || ''));
  const jobsRead = workspace ? liveJobs(workspace) : { live: [], unreadable: [] };
  const jobs = jobsRead.live;
  const refusals = workspace ? refusalsBefore({ workspaceLog, mirrorLog, sessionId }) : 0;
  const d = decideStop({ discovery, plan, turn, jobs, jobsUnreadable: jobsRead.unreadable, refusals, sessionId });
  if (env.STOP_GUARD_FAULT === 'throw') throw new Error('injected fault');
  const line = {
    ts: new Date().toISOString(), session: sessionId, decision: d.decision, reason: d.reason,
    plan: plan?.plan ?? null, open: plan?.open ?? null, total: plan?.total ?? null,
    live: [...(turn.liveAgents || []), ...(turn.liveShells || []), ...jobs],
    refusals: d.decision === 'block' ? refusals + 1 : 0,
    stop_hook_active: Boolean(input.stop_hook_active), elapsed_ms: Date.now() - started,
  };
  if (discovery.kind === 'ambiguous') { line.candidates = discovery.candidates; line.matches = discovery.matches; }
  if (discovery.kind === 'receipt') line.receipt = discovery.receipt;
  if (d.detail) line.detail = d.detail;
  const recorded = recordDecision({ workspaceLog, mirrorLog, marker, line });
  if (recorded.line.decision === 'block') return { stdout: JSON.stringify({ decision: 'block', reason: d.message }), exitCode: 0 };
  return { stdout: '', exitCode: 0 };
}
```

- [ ] **Step 4: Run the tests until they pass**

Run: `node --test hooks/lib/stop-guard.test.mjs` — Expected: all pass. Transcribe `HEURISTIC_CASES` from `evals/evidence/2026-10-19-sdd-turn-liveness/test_liveness.py` (class `Heuristic`, attribute `CASES`) first; the sample test fails on an empty list.

- [ ] **Step 5: Commit**

Leak scan, `git add hooks/lib/stop-guard.mjs hooks/lib/stop-guard.test.mjs`, commit `feat(hooks): the stop guard's decision table and entry point`.

---

### Task 8: The transcript tail reader

**Risk tier:** high — it decides what counts as live work and which message is the turn's last; a wrong read refuses a legitimate stop or allows a premature one.

**Files:**
- Modify: `hooks/lib/stop-guard.mjs` (replace `readTurn`; add `idleMarker`, `isHumanPrompt`, `linesFromEnd`)
- Modify: `hooks/lib/stop-guard.test.mjs` (a transcript-fixture section)

**Interfaces:**
- Consumes: the record shapes of `liveness.py:33-58,146-173` and `synth.py:27-105` (user and assistant records, `tool_use` and `tool_result` blocks, `<task-notification>` notices with `<tool-use-id>`).
- Produces: `readTurn(transcriptPath, {capBytes = TAIL_CAP, chunkBytes = TAIL_CHUNK} = {}) -> {ok, tooLong, promptTs, lastAssistantText, liveAgents, liveShells, detail?}` reading from the file's end in chunks until the turn's human prompt; `idleMarker(rec) -> 'human'|'notification'|null` and `isHumanPrompt(rec)` (the `idle_marker` port), exported for tests; `linesFromEnd(path, capBytes, chunkBytes)` (a generator of decoded lines, newest first, `null` when the cap stops it), exported for the straddling test.

**Mirror:** `liveness.py:146-173` (`idle_marker`), `:33-58` (launch and completion constants).

- [ ] **Step 1: Append the failing tests**

```js
const T0 = Date.parse('2026-10-23T10:00:00.000Z');
const at = (s) => new Date(T0 + s * 1000).toISOString();
const human = (t, text, extra = {}) => ({ type: 'user', timestamp: at(t), isSidechain: false, origin: { kind: 'human' }, message: { role: 'user', content: text }, ...extra });
const assistant = (t, text = '', tools = []) => ({ type: 'assistant', timestamp: at(t), isSidechain: false, message: { role: 'assistant', model: 'claude-opus-5-5', content: [...(text ? [{ type: 'text', text }] : []), ...tools.map(([id, name, input]) => ({ type: 'tool_use', id, name, input }))] } });
const result = (t, id, text) => ({ type: 'user', timestamp: at(t), isSidechain: false, message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id, content: [{ type: 'text', text }] }] } });
const notice = (t, id) => ({ type: 'user', timestamp: at(t), isSidechain: false, origin: { kind: 'task-notification' }, message: { role: 'user', content: `<task-notification>\n<task-id>x</task-id>\n<tool-use-id>${id}</tool-use-id>\n<status>completed</status>\n</task-notification>` } });
const compact = (t) => ({ type: 'user', timestamp: at(t), isSidechain: false, isCompactSummary: true, isVisibleInTranscriptOnly: true, message: { role: 'user', content: 'This session is being continued.' } });
function transcript(root, recs) { const p = join(root, 't.jsonl'); writeFileSync(p, recs.map((r) => JSON.stringify(r)).join('\n') + '\n'); return p; }
const AGENT_LAUNCHED = 'Async agent launched successfully. agentId: a1';
const BASH_BG = 'Command running in background with ID: b1. Output is being written to: /x';
const BASH_MOVED = 'Command did not complete within its 120s timeout and was moved to the background (ID: b2).';
const RESUMED = '{"success":true,"message":"Resuming agent a1 in the background with your message"}';

test('readTurn finds the last human prompt and the last assistant text', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const p = transcript(root, [human(0, 'Execute the plan.'), assistant(5, 'Working.'), human(100, 'continue'), assistant(105, 'Tasks 1 and 2 are done. Moving to Task 3.')]);
  const t = guard.readTurn(p);
  assert.equal(t.ok, true); assert.equal(t.promptTs, at(100)); assert.equal(t.lastAssistantText, 'Tasks 1 and 2 are done. Moving to Task 3.');
});
test('a tool result, a notification and a compaction summary are not the prompt', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const p = transcript(root, [human(0, 'go'), assistant(1, '', [['k1', 'Bash', { command: 'ls' }]]), result(2, 'k1', 'ok'), compact(3), notice(4, 'zz'), assistant(5, 'Done with that.')]);
  assert.equal(guard.readTurn(p).promptTs, at(0));
});
test('a human prompt that starts with < but carries origin human counts; markup without it does not', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const p = transcript(root, [human(0, 'go'), assistant(1, 'a'), human(2, '<ide_context>x</ide_context> continue'), assistant(3, 'b'), { type: 'user', timestamp: at(4), isSidechain: false, message: { role: 'user', content: '<local-command-stdout>x</local-command-stdout>' } }, assistant(5, 'c')]);
  assert.equal(guard.readTurn(p).promptTs, at(2));
});
test('launches in the turn without completions are live; completions by tool-use id clear them, for Agent, Bash, moved Bash and SendMessage alike', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const recs = [human(0, 'go'),
    assistant(1, '', [['a1', 'Agent', { prompt: 'x', run_in_background: true }]]), result(2, 'a1', AGENT_LAUNCHED),
    assistant(3, '', [['b1', 'Bash', { command: 'sleep 999', run_in_background: true }]]), result(4, 'b1', BASH_BG),
    assistant(5, '', [['b2', 'Bash', { command: 'sleep 999' }]]), result(6, 'b2', BASH_MOVED),
    assistant(7, '', [['s1', 'SendMessage', { to: 'a1', message: 'fix it' }]]), result(8, 's1', RESUMED),
    assistant(9, 'Waiting on the implementer.')];
  let t = guard.readTurn(transcript(root, recs));
  assert.deepEqual(t.liveAgents.sort(), ['a1', 's1']); assert.deepEqual(t.liveShells.sort(), ['b1', 'b2']);
  t = guard.readTurn(transcript(root, [...recs, notice(10, 'a1'), notice(11, 's1'), notice(12, 'b1'), assistant(13, 'All back but b2.')]));
  assert.deepEqual(t.liveAgents, []); assert.deepEqual(t.liveShells, ['b2']);
});
test('a resumed agent is matched by the SendMessage tool-use id, not the agent id', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const recs = [human(0, 'go'), assistant(1, '', [['s1', 'SendMessage', { to: 'a1', message: 'fix' }]]), result(2, 's1', RESUMED), notice(3, 'a1'), assistant(4, 'hm')];
  assert.deepEqual(guard.readTurn(transcript(root, recs)).liveAgents, ['s1']);
});
test('launches from an earlier turn are not read as live; sidechain records are skipped', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const recs = [human(0, 'go'), assistant(1, '', [['b1', 'Bash', { command: 'x', run_in_background: true }]]), result(2, 'b1', BASH_BG), human(50, 'status?'), { ...assistant(51, 'side', [['b9', 'Bash', { command: 'y', run_in_background: true }]]), isSidechain: true }, assistant(52, 'Still running.')];
  const t = guard.readTurn(transcript(root, recs));
  assert.equal(t.promptTs, at(50)); assert.deepEqual(t.liveShells, []); assert.equal(t.lastAssistantText, 'Still running.');
});
test('lines are split on the newline byte, so a multibyte character straddling a chunk boundary decodes whole', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const text = 'Tâche 3 terminée: résumé 日本語 écrit.';
  const p = transcript(root, [human(0, 'allez'), assistant(1, text)]);
  for (const chunkBytes of [1, 2, 3, 5, 7]) {
    const t = guard.readTurn(p, { chunkBytes });
    assert.equal(t.ok, true, `chunk ${chunkBytes}`); assert.equal(t.lastAssistantText, text, `chunk ${chunkBytes}`); assert.equal(t.promptTs, at(0));
  }
  assert.deepEqual([...guard.linesFromEnd(p, 1 << 20, 3)].map((l) => l && JSON.parse(l).timestamp), [at(1), at(0)]);
});
test('the reader stops at the cap and reports tooLong; a small last turn on a huge file is read quickly; a file without a prompt is no-prompt', () => {
  const root = mkdtempSync(join(tmpdir(), 'sg-'));
  const filler = assistant(1, 'x'.repeat(1000));
  const many = []; for (let i = 0; i < 20000; i++) many.push({ ...filler, timestamp: at(1 + i) });
  const pLong = transcript(root, [human(0, 'go'), ...many, assistant(30000, 'end')]);
  const long = guard.readTurn(pLong, { capBytes: 4 * 1024 * 1024 });
  assert.equal(long.ok, false); assert.equal(long.tooLong, true);
  const pShort = transcript(root, [human(0, 'go'), ...many, human(40000, 'continue'), assistant(40001, 'Moving to Task 3.')]);
  const t0 = Date.now(); const t = guard.readTurn(pShort, { capBytes: 4 * 1024 * 1024 });
  assert.equal(t.ok, true); assert.equal(t.promptTs, at(40000)); assert.ok(Date.now() - t0 < 1000);
  const none = guard.readTurn(transcript(root, [assistant(1, 'orphan')]));
  assert.equal(none.ok, false); assert.equal(none.tooLong, false); assert.equal(none.detail, 'no-prompt');
});
test('a missing transcript is not ok', () => { const t = guard.readTurn('/nonexistent/t.jsonl'); assert.equal(t.ok, false); assert.equal(t.detail, 'unreadable'); });
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `node --test hooks/lib/stop-guard.test.mjs 2>&1 | grep -c "^not ok"` — Expected: at least 5.

- [ ] **Step 3: Replace `readTurn`**

Remove Task 7's minimal `readTurn` and add:

```js
const TASK_NOTICE = '<task-notification>';
const INTERRUPTED = '[Request interrupted';
const NOTIF_ID = /<tool-use-id>([^<]+)<\/tool-use-id>/;
const LAUNCH_AGENT = 'Async agent launched';
const LAUNCH_BASH = 'Command running in background with ID';
const AUTO_MOVED = 'was moved to the background';
const RESUMED = ['Resuming agent ', 'in the background with your message'];
const AGENT_TOOLS = new Set(['Agent', 'Task']);

function textOf(rec) {
  const c = rec?.message?.content;
  if (typeof c === 'string') return c;
  if (Array.isArray(c)) return c.filter((b) => b.type === 'text').map((b) => b.text || '').join('\n');
  return '';
}
function isToolResult(rec) { const c = rec?.message?.content; return Array.isArray(c) && c.some((b) => b.type === 'tool_result'); }
// liveness.idle_marker: 'human' | 'notification' | null
export function idleMarker(rec) {
  if (rec.type !== 'user' || rec.isMeta || isToolResult(rec)) return null;
  if (rec.isCompactSummary || rec.isVisibleInTranscriptOnly) return null;
  const text = textOf(rec).replace(/^\s+/, '');
  if (text.startsWith(TASK_NOTICE)) return 'notification';
  if (!text || text.startsWith(INTERRUPTED)) return null;
  if (rec.origin && rec.origin.kind === 'human') return 'human';
  if (text.startsWith('<')) return null;
  return 'human';
}
export function isHumanPrompt(rec) { return idleMarker(rec) === 'human'; }
function resultText(block) { const c = block.content; if (typeof c === 'string') return c; if (Array.isArray(c)) return c.filter((b) => b.type === 'text').map((b) => b.text || '').join('\n'); return ''; }

// Lines of the file from its end, newest first, decoded only once complete:
// bytes are split on 0x0a, which no multibyte UTF-8 sequence contains, so a
// character straddling two chunks is never cut. Yields null when the cap
// stops the read before the file's start.
export function* linesFromEnd(path, capBytes, chunkBytes) {
  const fd = openSync(path, 'r');
  try {
    const size = fstatSync(fd).size;
    let pos = size; let carry = Buffer.alloc(0); let read = 0;
    while (pos > 0 && read < capBytes) {
      const len = Math.min(chunkBytes, pos); pos -= len;
      const buf = Buffer.alloc(len); readSync(fd, buf, 0, len, pos); read += len;
      const data = carry.length ? Buffer.concat([buf, carry]) : buf;
      let end = data.length;
      for (let i = data.length - 1; i >= 0; i--) {
        if (data[i] !== 0x0a) continue;
        if (i + 1 < end) yield data.subarray(i + 1, end).toString('utf8');
        end = i;
      }
      carry = Buffer.from(data.subarray(0, end));
    }
    if (pos === 0) { if (carry.length) yield carry.toString('utf8'); }
    else yield null;
  } finally { closeSync(fd); }
}

export function readTurn(transcriptPath, { capBytes = TAIL_CAP, chunkBytes = TAIL_CHUNK } = {}) {
  const none = { ok: false, tooLong: false, promptTs: null, lastAssistantText: '', liveAgents: [], liveShells: [], detail: 'unreadable' };
  if (!transcriptPath || !existsSync(transcriptPath)) return none;
  const turnRecs = []; let tooLong = false; let found = false;
  try {
    for (const l of linesFromEnd(transcriptPath, capBytes, chunkBytes)) {
      if (l === null) { tooLong = true; break; }
      let rec; try { rec = JSON.parse(l); } catch { continue; }
      if (!rec || rec.isSidechain) continue;
      turnRecs.push(rec);
      if (isHumanPrompt(rec)) { found = true; break; }
    }
  } catch { return none; }
  if (!found) return { ...none, tooLong, detail: tooLong ? 'cap' : 'no-prompt' };
  turnRecs.reverse(); // chronological, starting at the prompt
  const promptTs = turnRecs[0].timestamp;
  let lastAssistantText = '';
  const uses = new Map(); const launched = new Map(); const completed = new Set();
  for (const rec of turnRecs) {
    if (rec.type === 'assistant') {
      const t = textOf(rec); if (t) lastAssistantText = t;
      for (const b of rec.message?.content || []) if (b.type === 'tool_use') uses.set(b.id, { name: b.name, input: b.input || {} });
      continue;
    }
    if (rec.type !== 'user') continue;
    if (isToolResult(rec)) {
      for (const b of rec.message.content) {
        if (b.type !== 'tool_result') continue;
        const use = uses.get(b.tool_use_id); if (!use) continue;
        const text = resultText(b);
        if (AGENT_TOOLS.has(use.name) && text.includes(LAUNCH_AGENT)) launched.set(b.tool_use_id, 'agent');
        else if (use.name === 'SendMessage' && RESUMED.some((s) => text.includes(s))) launched.set(b.tool_use_id, 'agent');
        else if (use.name === 'Bash' && (use.input.run_in_background === true || text.includes(LAUNCH_BASH) || text.includes(AUTO_MOVED))) launched.set(b.tool_use_id, 'shell');
      }
      continue;
    }
    if (idleMarker(rec) === 'notification') { const m = textOf(rec).match(NOTIF_ID); if (m) completed.add(m[1]); }
  }
  const liveAgents = []; const liveShells = [];
  for (const [id, kind] of launched) if (!completed.has(id)) (kind === 'agent' ? liveAgents : liveShells).push(id);
  return { ok: true, tooLong: false, promptTs, lastAssistantText, liveAgents, liveShells };
}
```

A turn whose prompt lies beyond the cap returns `ok: false, tooLong: true`; a transcript with no prompt at all returns `ok: false, tooLong: false, detail: 'no-prompt'`; `decideStop` allows both as `turn-too-long`, carrying the detail into the log line.

- [ ] **Step 4: Run the tests**

Run: `node --test hooks/lib/stop-guard.test.mjs` — Expected: all pass, including the timing assertion on the 20 MB fixture and every chunk size of the straddling test.

- [ ] **Step 5: Commit**

Leak scan, `git add hooks/lib/stop-guard.mjs hooks/lib/stop-guard.test.mjs`, commit `feat(hooks): the stop guard reads the current turn from the transcript's tail`.

---

### Task 9: The wrapper, the registration, the `hook-error` line, the benchmark and the key parity

**Risk tier:** high — the registration makes the guard live for every Claude Code session that loads the plugin.

**Files:**
- Create: `hooks/sdd-stop-guard`
- Modify: `hooks/hooks.json`
- Create: `tests/hooks/test-sdd-stop-guard.sh`
- Modify: `hooks/lib/stop-guard.mjs` (the CLI entry at its bottom), `hooks/lib/stop-guard.test.mjs` (the benchmark, guarded by `STOP_GUARD_BENCH`)
- Modify: `docs/testing.md:23` (the `tests/hooks/` row); `tests/hooks/test-session-start.sh` or `tests/hooks/test-ungated-notice.sh` only if one asserts the exact set of hooks in `hooks.json` (check both)

**Interfaces:**
- Consumes: `main` (Task 7), `readTurn` (Task 8), `hp_key` from `sdd-common.sh`.
- Produces: the installed hook; `tests/hooks/test-sdd-stop-guard.sh` running `node --test hooks/lib/stop-guard.test.mjs` plus the wrapper cases; the two benchmark numbers (`# bench no-plan <n> ms`, `# bench with-plan <n> ms`) that Task 18 records.

**Mirror:** `hooks/session-start:38-55` (bounded stdin read), `hooks/run-hook.cmd:1-4` (exec by name), `tests/hooks/test-session-start.sh:1-45` (suite shape).

- [ ] **Step 1: Write the failing suite**

Create `tests/hooks/test-sdd-stop-guard.sh`:

```bash
#!/usr/bin/env bash
# The stop guard: the node unit matrix, then the bash wrapper's own behavior
# (registration, exit 0 everywhere, the hook-error line without node, the
# bash/node key parity) and the benchmark.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/sdd-stop-guard"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
FAILURES=0
TEST_ROOT=$(mktemp -d); TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P)
trap 'rm -rf "$TEST_ROOT"' EXIT
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "=== stop guard: unit matrix ==="
if STOP_GUARD_BENCH=1 node --test "$REPO_ROOT/hooks/lib/stop-guard.test.mjs" > "$TEST_ROOT/node.out" 2>&1; then pass "node --test hooks/lib/stop-guard.test.mjs"; else fail "node --test hooks/lib/stop-guard.test.mjs"; tail -n 40 "$TEST_ROOT/node.out"; fi
grep -E '^# bench' "$TEST_ROOT/node.out" || true

echo "=== stop guard: registration ==="
if node -e 'const h=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).hooks.Stop;if(!Array.isArray(h)||h.length!==1)process.exit(1);const c=h[0].hooks[0];if(!c.command.includes("run-hook.cmd\" sdd-stop-guard")||c.timeout!==30||c.shell!=="bash")process.exit(1)' "$REPO_ROOT/hooks/hooks.json"; then pass "hooks.json registers Stop -> run-hook.cmd sdd-stop-guard with a 30 s timeout"; else fail "hooks.json registers Stop -> run-hook.cmd sdd-stop-guard with a 30 s timeout"; fi
if grep -q '"Stop"' "$REPO_ROOT/hooks/hooks-codex.json" 2>/dev/null || grep -q '"Stop"' "$REPO_ROOT/hooks/hooks-cursor.json" 2>/dev/null; then fail "the Codex and Cursor hook files do not register the guard"; else pass "the Codex and Cursor hook files do not register the guard"; fi
if [ -x "$HOOK" ] && head -n 1 "$HOOK" | grep -q '^#!/usr/bin/env bash$'; then pass "the wrapper is an executable bash script"; else fail "the wrapper is an executable bash script"; fi

echo "=== stop guard: wrapper ==="
export XDG_CACHE_HOME="$TEST_ROOT/cache"
repo="$TEST_ROOT/repo"; git init -q -b main "$repo"; git -C "$repo" config user.name t; git -C "$repo" config user.email t@example.com
mkdir -p "$repo/docs"; printf '# Plan\n\n### Task 1: one\n' > "$repo/docs/plan.md"; git -C "$repo" add docs/plan.md; git -C "$repo" commit -q -m plan
input='{"session_id":"s-wrap","transcript_path":"/nonexistent","cwd":"'"$repo"'","hook_event_name":"Stop","stop_hook_active":false}'
out=$(printf '%s' "$input" | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/stop-guard" ]; then pass "a session with no plan: exit 0, no output, nothing written"; else fail "a session with no plan: exit 0, no output, nothing written (rc=$rc: $out)"; fi
key=$(bash -c '. "$1"; hp_key "$2"' _ "$LIB" "$repo")
ws="$XDG_CACHE_HOME/hyperpowers/state/$key/plans/plan-00000000"; mkdir -p "$ws"
printf '# SDD ledger — plan: docs/plan.md\nsession s-wrap: mode worktree on main at %s started x\n' "$repo" > "$ws/progress.md"
printf '%s\n' '{"type":"user","timestamp":"2026-10-23T10:00:00.000Z","isSidechain":false,"origin":{"kind":"human"},"message":{"role":"user","content":"go"}}' '{"type":"assistant","timestamp":"2026-10-23T10:00:05.000Z","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"Moving to Task 1."}]}}' > "$TEST_ROOT/t.jsonl"
input='{"session_id":"s-wrap","transcript_path":"'"$TEST_ROOT/t.jsonl"'","cwd":"'"$repo"'","hook_event_name":"Stop","stop_hook_active":false}'
out=$(printf '%s' "$input" | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"decision":"block"' && printf '%s' "$out" | grep -q 'SDD stop guard: plan docs/plan.md is not finished (1 of 1 tasks open; nothing tracked is live)'; then pass "a provable premature stop is refused through the wrapper"; else fail "a provable premature stop is refused through the wrapper (rc=$rc: $out)"; fi
if [ "$(grep -c '"decision":"block"' "$ws/stop-guard.jsonl")" = 1 ] && [ "$(grep -c '"decision":"block"' "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl")" = 1 ]; then pass "the decision is in the plan log and the mirror"; else fail "the decision is in the plan log and the mirror"; fi
# node absent from PATH: hook-error to the mirror, exit 0, nothing in the plan log
nopath="$TEST_ROOT/bin"; mkdir -p "$nopath"
for tool in bash git date mkdir dirname sed head; do ln -s "$(command -v "$tool")" "$nopath/$tool"; done
before=$(wc -l < "$ws/stop-guard.jsonl")
out=$(printf '%s' "$input" | PATH="$nopath" bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" | grep -q '"reason":"hook-error","detail":"node not found"' && [ "$(wc -l < "$ws/stop-guard.jsonl")" = "$before" ]; then pass "without node the wrapper allows and writes hook-error to the mirror"; else fail "without node the wrapper allows and writes hook-error to the mirror (rc=$rc: $out)"; fi
# the module throws: hook-error, exit 0
out=$(printf '%s' "$input" | STOP_GUARD_FAULT=throw bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" | grep -q '"reason":"hook-error","detail":"module exit 1"'; then pass "a module failure allows and writes hook-error"; else fail "a module failure allows and writes hook-error (rc=$rc: $out)"; fi
# the wrapper's line has the documented keys and a parsable timestamp
if tail -n 1 "$XDG_CACHE_HOME/hyperpowers/stop-guard/s-wrap.jsonl" | node -e 'const l=JSON.parse(require("fs").readFileSync(0,"utf8"));if(l.session!=="s-wrap"||l.decision!=="allow"||isNaN(Date.parse(l.ts)))process.exit(1)'; then pass "the hook-error line is well-formed JSON with ts, session, decision, reason, detail"; else fail "the hook-error line is well-formed JSON"; fi
# malformed stdin, and a session id the mirror path must not take
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass "malformed input exits 0 silently"; else fail "malformed input exits 0 silently (rc=$rc: $out)"; fi
out=$(printf '{"session_id":"../../etc/x","cwd":"%s"}' "$repo" | STOP_GUARD_FAULT=throw bash "$HOOK"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -e "$XDG_CACHE_HOME/hyperpowers/stop-guard/../../etc" ]; then pass "a session id with path characters writes nothing"; else fail "a session id with path characters writes nothing (rc=$rc)"; fi
# a cap refusal sequence through the real wrapper: the hook-error allows above reset the count, so block, block, allow
out1=$(printf '%s' "$input" | bash "$HOOK"); out2=$(printf '%s' "$input" | bash "$HOOK"); out3=$(printf '%s' "$input" | bash "$HOOK")
if printf '%s' "$out1" | grep -q '"decision":"block"' && printf '%s' "$out2" | grep -q '"decision":"block"' && [ -z "$out3" ] && tail -n 1 "$ws/stop-guard.jsonl" | grep -q '"reason":"cap"'; then pass "after an allow, the third consecutive attempt is allowed as cap through the wrapper"; else fail "after an allow, the third consecutive attempt is allowed as cap through the wrapper ($out1 / $out2 / $out3)"; fi

echo "=== stop guard: key parity ==="
nodekey=$(node -e 'import(process.argv[1]).then(m=>process.stdout.write(m.cloneKey(process.argv[2])||""))' "$REPO_ROOT/hooks/lib/stop-guard.mjs" "$repo")
if [ -n "$key" ] && [ "$key" = "$nodekey" ]; then pass "cloneKey agrees with hp_key"; else fail "cloneKey agrees with hp_key ($key vs $nodekey)"; fi

echo ""
if [ "$FAILURES" -gt 0 ]; then echo "STATUS: FAILED ($FAILURES failures)"; exit 1; fi
echo "STATUS: PASSED"
```

The benchmark appended to `hooks/lib/stop-guard.test.mjs`, run only with `STOP_GUARD_BENCH=1` (`openSync`, `writeSync`, `closeSync` join its imports):

```js
test('benchmark: no-plan under 100 ms with 50 candidate ledgers; a small last turn on a 300 MB transcript under 1 s', { skip: !process.env.STOP_GUARD_BENCH }, () => {
  const e = env();
  for (let k = 0; k < 5; k++) for (let i = 0; i < 10; i++) { const ws = join(e.cache, 'hyperpowers', 'state', `key${k}`, 'plans', `p${i}-0000000${i}`); mkdirSync(ws, { recursive: true }); writeFileSync(join(ws, 'progress.md'), `# SDD ledger — plan: docs/plan.md\nsession other-${k}-${i}: mode worktree on main at /x started x\n`); }
  let t0 = Date.now(); guard.main(JSON.stringify({ session_id: 'nobody', transcript_path: join(e.root, 'none'), cwd: tmpdir() }), { XDG_CACHE_HOME: e.cache }); const noPlan = Date.now() - t0;
  console.log(`# bench no-plan ${noPlan} ms`); assert.ok(noPlan < 100, `no-plan took ${noPlan} ms`);
  const ws = workspaceFor(e); ledger(ws, e, { tasksDone: [1] });
  const big = join(e.root, 'big.jsonl'); const fd = openSync(big, 'w');
  const filler = JSON.stringify(assistant(1, 'x'.repeat(4000))) + '\n';
  for (let i = 0; i < Math.ceil(300 * 1024 * 1024 / filler.length); i++) writeSync(fd, filler);
  writeSync(fd, JSON.stringify(human(90000, 'continue')) + '\n' + JSON.stringify(assistant(90001, 'Moving to Task 2.')) + '\n'); closeSync(fd);
  t0 = Date.now(); const r = guard.main(JSON.stringify({ session_id: SID, transcript_path: big, cwd: e.repo }), { XDG_CACHE_HOME: e.cache }); const withPlan = Date.now() - t0;
  console.log(`# bench with-plan ${withPlan} ms`); assert.ok(withPlan < 1000, `with-plan took ${withPlan} ms`); assert.match(r.stdout, /"decision":"block"/);
  rmSync(big);
});
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/hooks/test-sdd-stop-guard.sh 2>&1 | tail -n 12` — Expected: the registration and wrapper cases `[FAIL]` (no hook file, no `Stop` entry), `STATUS: FAILED`.

- [ ] **Step 3: Write the wrapper and register it**

`hooks/sdd-stop-guard` (mode 755, no heredocs, no here-strings):

```bash
#!/usr/bin/env bash
# Stop hook: the SDD stop guard. Reads the Stop payload once, hands it to the
# node module, prints the module's output (a block decision or nothing), and
# exits 0 on every path. When node is missing or the module fails, an allow
# is recorded in the session mirror as hook-error, with printf alone.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
input=""
if [ ! -t 0 ]; then IFS= read -r -d '' -t 2 input 2>/dev/null || true; fi
[ -n "$input" ] || exit 0
record_error() { # <detail>
  local sid ts dir
  sid=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$sid" ] || return 0
  case "$sid" in *[!A-Za-z0-9._-]*) return 0 ;; esac
  dir="${XDG_CACHE_HOME:-${HOME:-}/.cache}/hyperpowers/stop-guard"
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  mkdir -p "$dir" 2>/dev/null || return 0
  printf '{"ts":"%s","session":"%s","decision":"allow","reason":"hook-error","detail":"%s"}\n' "$ts" "$sid" "$1" >> "$dir/$sid.jsonl" 2>/dev/null || true
}
if ! command -v node >/dev/null 2>&1; then record_error "node not found"; exit 0; fi
out=$(printf '%s' "$input" | node "$SCRIPT_DIR/lib/stop-guard.mjs" 2>/dev/null); rc=$?
if [ "$rc" -ne 0 ]; then record_error "module exit $rc"; exit 0; fi
[ -n "$out" ] && printf '%s\n' "$out"
exit 0
```

The module's CLI entry, at the bottom of `hooks/lib/stop-guard.mjs` (an uncaught exception exits 1, which the wrapper turns into `hook-error`):

```js
if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  const text = readFileSync(0, 'utf8');
  const r = main(text, process.env);
  if (r.stdout) process.stdout.write(r.stdout + '\n');
  process.exit(r.exitCode);
}
```

`hooks/hooks.json` gains, beside `SessionStart`:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" sdd-stop-guard",
        "shell": "bash",
        "timeout": 30
      }
    ]
  }
]
```

- [ ] **Step 4: Run the suites**

Run: `bash tests/hooks/test-sdd-stop-guard.sh; bash tests/hooks/test-no-heredocs-in-hooks.sh | tail -n 2; bash tests/hooks/test-session-start.sh | tail -n 2; bash tests/hooks/test-ungated-notice.sh | tail -n 2` — Expected: `STATUS: PASSED` for each; the two `# bench` lines printed (record them in the ledger for Task 18). If `test-ungated-notice.sh` or `test-session-start.sh` asserts the exact set of hooks in `hooks.json`, extend that assertion to include `Stop` in the same commit.

- [ ] **Step 5: Document and commit**

Add `test-sdd-stop-guard.sh` (the stop guard: unit matrix, wrapper, parity, benchmark) to `docs/testing.md:23`. Leak scan, `git add hooks/sdd-stop-guard hooks/hooks.json hooks/lib/stop-guard.mjs hooks/lib/stop-guard.test.mjs tests/hooks/test-sdd-stop-guard.sh docs/testing.md` (and any adjusted hook test), commit `feat(hooks): register the SDD stop guard`.

---
### Task 10: The skill text and the contract test

**Risk tier:** standard — behavior-shaping text, pinned by the contract suite; no code.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:19` (Continuous execution), `:76,113-114` (the process graph's snapshot node), the Setup paragraph that names the snapshot cadence, `:349-357` (Waiting on subagents and long commands), after `:427` (the dispatch bullets), `:557-562` (Rounds 1-3), `:695-705` (Complete the task), `:805-840` (Finish)
- Modify: `skills/subagent-driven-development/common-rationalizations.md` (one row at the end)
- Test: `tests/sdd/test-sdd-contract.sh`

**Interfaces:**
- Consumes: the helper contracts of Tasks 2 to 5 and the two refusal messages of Task 7 (Global Constraints carry the exact strings).
- Produces: the treatment skill text the campaign measures; its commit is the `treatment` pin Task 18 writes.

**Mirror:** `tests/sdd/test-sdd-contract.sh`'s "Turn liveness (spec 2026-10-19)" block for needle style (single-line needles, one description each, matched against a whitespace-collapsed haystack).

- [ ] **Step 1: Add the failing needles and drop the two retired ones**

In `tests/sdd/test-sdd-contract.sh`, inside the "Turn liveness" block, delete the two `assert_contains` lines whose needles pin the hand-written exit-file protocol (`grep -n '\.exit' tests/sdd/test-sdd-contract.sh` finds them; their needles name `<out>.exit`). Below that block and above the closing `STATUS` lines add:

```bash
# Stop guard (spec 2026-10-23): helpers write the ledger's machine lines, the
# guard's refusal is quoted, long commands go through tracked-job.
assert_contains "$SDD" 'scripts/sdd-state complete PLAN_FILE N --commits <base7>..<head7>' "completion goes through sdd-state complete"
assert_contains "$SDD" 'repeat it until it prints `status=complete`' "complete is repeated until it succeeds"
assert_contains "$SDD" '`busy` and `error` are retried' "complete's retryable statuses are named"
assert_contains "$SDD" 'scripts/sdd-state handback PLAN_FILE --reason "<why>"' "a hand-back is written with sdd-state handback"
assert_contains "$SDD" 'SDD stop guard: plan' "the refusal message is quoted"
assert_contains "$SDD" 'two consecutive attempts per plan, the count resetting after any allow' "the cap is stated as consecutive attempts per plan"
assert_contains "$SDD" 'writing a question you do not need answered to get past it is the stop it exists to prevent' "gaming the heuristic is named"
assert_contains "$SDD" 'scripts/tracked-job new PLAN_FILE <name> --budget-ms <budget>' "long commands are allocated with tracked-job new"
assert_contains "$SDD" 'the helper writes the `jobdir=` line in the ledger itself' "the allocation line is the helper's, not the controller's"
assert_contains "$SDD" 'scripts/tracked-job run <jobdir> -- <command>' "long commands are launched with tracked-job run"
assert_contains "$SDD" 'scripts/tracked-job wait <jobdir> --max-ms 600000' "long commands are watched with tracked-job wait"
assert_contains "$SDD" '`exited code=0` is success; any other `exited` code is a failed command' "only code 0 is success"
assert_contains "$SDD" 'on `lost`, run `tracked-job stop <jobdir>` first' "a lost job is swept before it is handled as failed"
assert_contains "$SDD" '`lost-unswept pgid=<n>`' "the unswept outcome is reported to the human partner"
assert_contains "$SDD" 'output never goes in the ledger' "job output stays out of the ledger"
assert_contains "$SDD" 'the stop guard treats it as live work, and your turn may end while it runs' "SendMessage resumes are named as live work"
assert_contains "$SDD" 'where it does not (fork mode in an interactive terminal), dispatches run in the background and the stop guard treats them as live work' "the fork-mode sentence"
assert_contains "$SDD" 'receipt=<path>' "finish records the receipt"
assert_not_contains "$SDD" '<out>.exit' "the hand-written exit-file protocol is gone"
assert_contains "$SDD_RATIONALIZATIONS" 'The hook blocked me, so I'"'"'ll ask a question to get out' "rationalization row for gaming the guard"
```

Run: `bash tests/sdd/test-sdd-contract.sh 2>&1 | grep -c "\[FAIL\]"` — Expected: 20.

- [ ] **Step 2: Edit SKILL.md**

Line 19, append to the "Continuous execution" paragraph after "All tasks complete ends the plan.":

> Each permitted turn end, and "your human partner asked you to stop", is written to the ledger in the same message that ends the turn: run `scripts/sdd-state handback PLAN_FILE --reason "<why>"` (add `--session <sid>` on a harness without `CLAUDE_CODE_SESSION_ID`; `busy` or `error` is retried, and without the line the guard falls back to reading your last message). On Claude Code the SDD stop guard refuses a turn end it can prove is premature, two consecutive attempts per plan, the count resetting after any allow, with this message: "SDD stop guard: plan <plan path> is not finished (<state>; nothing tracked is live). Take the next step now, in this turn. If you are handing back to your human partner (a question only they can answer, a BLOCKED report, or they asked you to stop), run scripts/sdd-state handback PLAN_FILE --session <sid> --reason "<why>" and end the turn with that message." (with a live job the first sentences name the job and say to watch it with `tracked-job wait`). When you meet it, take the next step; writing a question you do not need answered to get past it is the stop it exists to prevent, and the log records every allow.

The Setup paragraph at `:235-241` (the sentences beginning "Snapshot the workspace (`scripts/sdd-state snapshot PLAN_FILE`) after the pre-flight scan table and after every `Task <N>: complete` line"): the by-hand snapshot happens "after the pre-flight scan table and before the final review", the completion line's snapshot belongs to the helper ("`scripts/sdd-state complete` snapshots after every completion line it writes, so a hand-off or a crash loses at most the task in flight"), and the outcome sentences that follow ("The snapshot is the completion's durable record, so its outcome decides whether you go on ...") are reworded for the helper's status line: `status=complete` continues, `busy` and `error` are retried, every other status stops. The process graph node at `:76` ("Snapshot the workspace (scripts/sdd-state snapshot); error or none stops") is renamed "Complete the task (scripts/sdd-state complete); any status but complete stops", and the edge labels at `:113-114` that name it follow.

Lines 349-357, the long-command bullet (the third bullet of "Waiting on subagents and long commands") becomes:

> - A command that may run past 10 minutes is a tracked job. Allocate it in the foreground with `scripts/tracked-job new PLAN_FILE <name> --budget-ms <budget>` (the watch budget below; the helper writes the `jobdir=` line in the ledger itself), launch `scripts/tracked-job run <jobdir> -- <command>` through the tracked background option with the budget as its timeout, then watch it in the foreground with repeated `scripts/tracked-job wait <jobdir> --max-ms 600000` calls: `exited code=0` is success; any other `exited` code is a failed command, handled as that command's failure (a failed test is a fix round, a failed covering command a failed task); `running` at the bound means another `wait`; on `lost`, run `tracked-job stop <jobdir>` first, so the job's survivors are swept, then treat the job as failed; `lost-unswept pgid=<n>` means the sweep needs a shell that can read process environments (the sandbox cannot), so the job stays live to the stop guard until `tracked-job stop <jobdir>` runs where it can: report it to your human partner with its pgid beside the failure, and expect a reused pid to read as `running` until that sweep. When you need a job's output, write the tail of its `out.log` to `<workspace>/reports/job-<name>.txt` and cite the path; output never goes in the ledger. Codex reviews already follow this shape through the recipe's `status <job-id> --wait --json` loop.

The watch-budget bullet keeps its arithmetic; its sentence "The watch ends when `<out>.exit` appears, or when the harness reports the job ended without one: a killed process writes no exit file, so read its output and treat the job as failed." becomes "The watch ends when `wait` reports `exited`, `lost` or `lost-unswept`; a supervisor the harness killed writes no exit file, and `wait` reports it as `lost`." and its sentence "When the budget is spent with the job still running, stop the job through the harness, record the output tail in the ledger, and report BLOCKED." becomes "When the budget is spent with the job still running, run `tracked-job stop <jobdir>`, write the `out.log` tail to `<workspace>/reports/job-<name>.txt`, and report BLOCKED naming that path." (After both edits the string `<out>.exit` appears nowhere in the file, which the contract suite asserts.)

After line 427 (`- Never dispatch multiple implementation subagents in parallel (conflicts).`), a bullet:

> - Where the Agent tool offers `run_in_background`, dispatch with it false; where it does not (fork mode in an interactive terminal), dispatches run in the background and the stop guard treats them as live work.

Lines 557-562 (Rounds 1-3), after "the report file is the persistent memory either way.":

> On Claude Code the resumed agent runs in the background, the stop guard treats it as live work, and your turn may end while it runs; its completion notice resumes you.

Lines 695-705 (Complete the task): replace "append the completion line to the ledger in the same message as your other bookkeeping: - `Task <N>: complete (...)`" and the snapshot sentence with:

> run `scripts/sdd-state complete PLAN_FILE N --commits <base7>..<head7>` and repeat it until it prints `status=complete` (`busy` and `error` are retried; `unknown-task` means the number is not a heading in the plan, `no-workspace` that the ledger is gone, and a usage error that the arguments are wrong: each of those stops you, not the loop). Its `snapshot=` is the completion's durable record. Then mark the task's todo complete, where you keep todos, and move on.

Lines 805-840 (Finish), step 2: "... and prints `last=<sha>`, the commit that still holds the dossier, `push=<remote>/<branch>` and `receipt=<path>`, the durable copy of the ledger, the guard's log and the job records; record the receipt path in your closing message. A line reading `receipt=none staging=<path>` means the record exists only under that staging path: name the path to your human partner in the closing message".

`common-rationalizations.md`, last row:

```
| "The hook blocked me, so I'll ask a question to get out" | A question you do not need answered is a premature stop with extra steps; the log records every allow and the field reads it. Take the step the message names. |
```

- [ ] **Step 3: Run the suites**

Run: `bash tests/sdd/test-sdd-contract.sh | tail -n 3` — Expected: `STATUS: PASSED`, and `grep -c "\[PASS\]"` on its output is 249 (231 at Before Task 1, minus the 2 retired needles, plus 20). Then `bash tests/run-offline.sh` outside the sandbox — Expected: the accepted signature of Global Constraints (exactly one `FAILED:` line, the brainstorm-server npm test, and the closing `offline set: 1 failed` line).

- [ ] **Step 4: Commit**

Leak scan, `git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/common-rationalizations.md tests/sdd/test-sdd-contract.sh`, commit `feat(sdd): the skill names the stop guard, the completion helper and tracked-job`. Record this commit's sha in the ledger: it is the `treatment` pin.

---

### Task 11: Field Correction 8 and the cohort and premature-end helpers

**Risk tier:** high — it changes a published baseline and the record in three documents.

**Files:**
- Modify (evals worktree): `evidence/2026-10-19-sdd-turn-liveness/field.py:127-222` (`_session`, `collect`, plus `cohort` and `premature_ends`), `test_field.py` (class `Collect` and a new class `Helpers`), `field/baseline.json`, `field/baseline.txt`, `field/reflog-plugin-install.txt` (regenerated by `run-baseline.sh`), `README.md` (`## Question`, the baseline table, `## Field decision rule`'s "Correction owed" paragraph, `## Corrections` entry 8), `docs/experiments/2026-10-19-sdd-turn-liveness.md:3-11`
- Modify (hyperpowers worktree): `docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md:60-83` (the field baseline table)

**Interfaces:**
- Consumes: `field.collect(projects, since, until)` and `_session` as they stand; `liveness.turn_ends`, `tasks`, `reloads`, `state_at`, `asks_or_blocks`, `TurnEnd`; `run-baseline.sh`.
- Produces: `field.cohort(projects, since, until) -> Iterator[tuple[Path, list[Record], datetime]]` (each qualifying transcript, its records before `until`, and the time of its first in-window SDD invocation); `field.premature_ends(records, since, until) -> list[TurnEnd]` (the in-window turn ends the measure scores as premature); `collect` built on both; the corrected baseline Task 18 cites. Task 12 imports `cohort` and `premature_ends`.

**Mirror:** `test_field.py:139-161` (`test_records_after_the_window_change_nothing`) for the test shape; README Correction 7's entry for the Correction's shape.

- [ ] **Step 1: Write the failing tests**

In `test_field.py`, class `Collect`:

```python
    def test_a_session_is_measured_from_its_first_in_window_sdd_invocation(self) -> None:
        # Planning-phase task events before the skill is invoked are not SDD execution.
        early_work = [
            human(0, "Let's plan this.", entrypoint="sdk-ts"),
            assistant(10, tools=[("k0", "TaskCreate", {"subject": "plan"})]),
            result(11, "k0", "Task #1 created successfully: plan"),
            assistant(20, "Thinking about the design."),
            human(30, "Resume"),
            assistant(40, tools=[("k1", "TaskUpdate", {"taskId": "1", "status": "completed"})]),
            result(41, "k1", "Task #1 updated"),
            assistant(100, tools=[SDD]),
            result(101, "s1", "Launching skill"),
            assistant(110, tools=[("k2", "TaskCreate", {"subject": "A"})]),
            result(111, "k2", "Task #2 created successfully: A"),
            assistant(120, "Working on Task 2."),
            human(130, "Resume"),
            assistant(140, tools=[("k3", "TaskUpdate", {"taskId": "2", "status": "completed"})]),
            result(141, "k3", "Task #2 updated"),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            projects = Path(tmp)
            write(projects / "p1" / "zed.jsonl", early_work)
            out = field.collect(projects, SINCE, UNTIL)
        self.assertEqual(out["sessions"], 1)
        # one boundary (Task 2) and one premature stop (at 120), none from before the invocation
        self.assertEqual((out["boundaries"], out["premature"]), (1, 1))
```

and a new class:

```python
class Helpers(unittest.TestCase):
    def test_cohort_yields_qualifying_sessions_with_their_first_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            projects = Path(tmp)
            write(projects / "p1" / "zed.jsonl", session())
            write(projects / "p1" / "cli.jsonl", [human(0, "hi", entrypoint="cli"), assistant(5, tools=[SDD]), result(6, "s1", "x")])
            write(projects / "p2" / "nosdd.jsonl", [human(0, "hi", entrypoint="sdk-ts"), assistant(5, "ok.")])
            rows = list(field.cohort(projects, SINCE, UNTIL))
        self.assertEqual([p.name for p, _, _ in rows], ["zed.jsonl"])
        self.assertEqual(rows[0][2], parse_ts(at(5)))

    def test_premature_ends_are_the_open_task_stops_that_neither_ask_nor_wait(self) -> None:
        ends = field.premature_ends(session(), SINCE, UNTIL)
        self.assertEqual([e.at for e in ends], [parse_ts(at(110))])
        self.assertEqual(field.premature_ends(session(), parse_ts(at(115)), UNTIL), [])
```

(`parse_ts` and `at` join the imports from `liveness` and `synth`.)

Run: `python3 -m unittest test_field -v 2>&1 | tail -n 12` — Expected: the first case fails with `(2, 2) != (1, 1)`, the `Helpers` cases with `AttributeError`.

- [ ] **Step 2: Change `field.py`**

Factor the cohort and the premature classification out of `collect` and `_session`:

```python
def cohort(projects: Path, since: datetime, until: datetime) -> Iterator[tuple[Path, list[Record], datetime]]:
    """Every Zed session with an SDD invocation inside the window.

    Yields the transcript path, its records before ``until`` (the observation
    cutoff), and the time of its first in-window SDD invocation, which is
    where its measurement starts (Correction 8).
    """
    for path in sorted(projects.glob("*/*.jsonl")):
        if entrypoint(path) != "sdk-ts":
            continue
        records = [rec for rec in load(path, slim=True) if parse_ts(rec["timestamp"]) < until]
        inwin = [rec for rec in records if since <= parse_ts(rec["timestamp"]) < until]
        if not is_sdd(inwin):
            continue
        yield path, records, min(parse_ts(rec["timestamp"]) for rec in inwin if is_sdd([rec]))


def _premature(end: TurnEnd, task_map: Mapping[str, Task], reload_times: Sequence[datetime], times: Sequence[datetime], open_counts: Sequence[int]) -> bool:
    return (
        end.excluded is None
        and state_at(end.at, task_map, reload_times) == "none"
        and _open_at(times, open_counts, end.at)
        and not asks_or_blocks(end.text)
    )


def premature_ends(records: Sequence[Record], since: datetime, until: datetime) -> list[TurnEnd]:
    """The in-window turn ends the measure scores as premature stops."""
    task_map = tasks(records)
    reload_times = reloads(records)
    times, open_counts, _ = _open_timeline(records)
    return [end for end in turn_ends(records) if since <= end.at < until and _premature(end, task_map, reload_times, times, open_counts)]
```

In `_session`, the branch `elif _open_at(times, open_counts, end.at) and not asks_or_blocks(end.text):` becomes `elif _premature(end, task_map, reload_times, times, open_counts):` (the preceding `excluded`, `live` and `censored` branches stay, so the counts are unchanged). In `collect`, the loop becomes:

```python
    for _path, records, first in cohort(projects, since, until):
        counts, session_versions, session_models = _session(records, first, until)
```

with the docstring sentence "The session is measured from its first in-window SDD invocation; its earlier records still reconstruct the state its later events are read against." (`Iterator`, `Mapping`, `Task`, `TurnEnd` join the imports.)

Run: `python3 -m unittest test_field test_analyze test_tally test_liveness` — Expected: OK (the previous count plus three); `ruff check .` clean; `mypy field.py test_field.py` clean.

- [ ] **Step 3: Re-record the baseline**

Run, outside the sandbox where the host transcripts are readable: `bash evidence/2026-10-19-sdd-turn-liveness/field/run-baseline.sh` (two passes, about ten minutes). Expected: it exits 0 (the two passes agree) and `field/baseline.json` reads `sessions 14, boundaries 1434, premature 296, premature_per_100 20.64, premature_resumed 21, live_turn_ends 2211, live_resumes 9, live_resumes_per_100 0.63, censored_stops 1423, censored_resumes 144, excluded {error 373, interrupt 17, killed 2, reload 69}`. Any other reading stops the task: the spec's expected numbers came from the controller's replay on 2026-10-22, and a difference means the host's transcripts changed since; report both readings to the human partner.

- [ ] **Step 4: Update the records**

`README.md`: append Correction 8 to `## Corrections` in the shape of entry 7: "2026-10-23, before any after-window and before the stop-guard campaign. `field.collect` measured a qualifying session from the window's start, so a session's brainstorming and planning events before it invoked SDD counted as SDD boundaries and stops. It now measures from the session's first in-window SDD invocation, keeping earlier records for state (`field.cohort`); the premature classification moved into `field.premature_ends` for the hook-record reader, with no number changed by that move. Re-recorded: 14 sessions, 1434 boundaries (1495 before), 296 premature stops (301), 20.64 per 100 (20.13), 21 resumed (21), 2211 live-work turn ends (2228), 9 live-work resumes at 0.63 per 100 (9 at 0.6), 1423 and 144 censored (1424 and 144), excluded error 373, interrupt 17, killed 2, reload 69 (383, 20, 2, 71). No session straddles the window start. Pin after the Correction: `field.py` `<blob>`." Rewrite the baseline table with the new values and the superseded ones in a second column headed "Before Correction 8"; replace the `## Field decision rule` paragraph "Correction owed before the after-window" with "Correction 8 landed on 2026-10-23: ..." pointing at the entry; update the `## Question` numbers (301, 1495, 20.13, 9, 0.6) to the corrected ones with "(before Correction 8: ...)" once. `docs/experiments/2026-10-19-sdd-turn-liveness.md:3-11`: the same numbers, the same parenthetical. In the hyperpowers worktree, the note's table (`:67-76`) gains the second column and one sentence below it naming Correction 8.

- [ ] **Step 5: Commit**

Evals: leak scan, `bun run check` (compare with the baseline failures), `git add evidence/2026-10-19-sdd-turn-liveness/field.py evidence/2026-10-19-sdd-turn-liveness/test_field.py evidence/2026-10-19-sdd-turn-liveness/field evidence/2026-10-19-sdd-turn-liveness/README.md docs/experiments/2026-10-19-sdd-turn-liveness.md`, commit `fix(evidence): the field cohort is measured from each session's first in-window SDD invocation (Correction 8)`. Hyperpowers: `git add docs/hyperpowers/2026-10-19-sdd-turn-liveness-eval-evidence.md`, commit `docs(hyperpowers): the field baseline under Correction 8`.

---

### Task 12: The hook-record field reader

**Risk tier:** high — it is the after-window's second measure; its numbers decide whether the follow-up opens.

**Files:**
- Create (evals worktree): `evidence/2026-10-19-sdd-turn-liveness/field_hook.py`, `test_field_hook.py`
- Modify: `evidence/2026-10-19-sdd-turn-liveness/README.md` (`## Field decision rule`: one paragraph naming the reader and its command)

**Interfaces:**
- Consumes: `field.cohort`, `field.premature_ends`, `field.collect` (Task 11); `liveness.parse_ts`; the decision-line schema (Global Constraints) and the wrapper's `hook-error` line (Task 9); the mirror directory `<cache>/hyperpowers/stop-guard/`, one `<session_id>.jsonl` per session, where Claude Code's transcript file name is the session id.
- Produces: `field_hook.mirror_lines(path, since, until) -> list[dict]`; `field_hook.misses(lines, premature_times) -> list[dict]`; `field_hook.collect(projects, mirror_dir, since, until) -> dict` with `window`, `sessions`, `sessions_with_log`, `boundaries`, `blocks`, `blocks_per_100`, `allows` (reason to count), `cap`, `log_failed`, `hook_error`, `mirror_failed`, `misses` (hand-back allows inside `[stop - 2 s, stop + 1 min]` of a premature stop the transcript measure scored, each with its `session`); `python3 field_hook.py --since <iso> --until <iso> [--projects DIR] [--mirror-dir DIR]` printing that JSON. The after-window follow-up (After the final review) runs it.

**Mirror:** `field.py:174-222` (`collect`, the return dictionary and `per100`), `test_field.py:65-161` (class `Collect`: temporary projects directory, `write`, `session()`).

- [ ] **Step 1: Write the failing tests**

Create `test_field_hook.py`:

```python
"""Tests for field_hook.py: the stop guard's record over the field cohort."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import field
import field_hook
from liveness import parse_ts
from synth import at, write
from test_field import SINCE, UNTIL, session


def decision(t: float, kind: str, reason: str, **extra: Any) -> dict[str, Any]:
    return {"ts": at(t), "session": "zed", "decision": kind, "reason": reason, "plan": "plan.md", "open": 1, "total": 2, "live": [], "refusals": 0, "stop_hook_active": False, "elapsed_ms": 3, **extra}


class Collect(unittest.TestCase):
    def test_counts_blocks_allows_and_misses_for_the_cohort(self) -> None:
        lines = [
            decision(100, "block", "open-tasks", refusals=1),
            decision(111, "allow", "handback-text"),  # within a minute of the premature stop at 110: a miss
            decision(200, "allow", "cap"),
            decision(300, "allow", "log-failed"),
            {"ts": at(400), "session": "zed", "decision": "allow", "reason": "hook-error", "detail": "module exit 1"},
            decision(1005, "allow", "handback-text", mirror_failed=True),  # the stop at 1010 asks: not a miss
            decision(-100000, "block", "open-tasks"),  # outside the window
        ]
        with tempfile.TemporaryDirectory() as tmp:
            projects = Path(tmp) / "projects"
            mirrors = Path(tmp) / "stop-guard"
            mirrors.mkdir()
            write(projects / "p1" / "zed.jsonl", session())
            (mirrors / "zed.jsonl").write_text("\n".join(json.dumps(line) for line in lines) + "\nnot json\n")
            (mirrors / "stranger.jsonl").write_text(json.dumps(decision(100, "block", "open-tasks")) + "\n")
            out = field_hook.collect(projects, mirrors, SINCE, UNTIL)
            base = field.collect(projects, SINCE, UNTIL)
        self.assertEqual((out["sessions"], out["sessions_with_log"]), (1, 1))
        self.assertEqual(out["boundaries"], base["boundaries"])
        self.assertEqual(out["blocks"], 1)
        self.assertEqual(out["blocks_per_100"], round(100 * 1 / base["boundaries"], 2))
        self.assertEqual(out["allows"], {"cap": 1, "handback-text": 2, "hook-error": 1, "log-failed": 1})
        self.assertEqual((out["cap"], out["log_failed"], out["hook_error"], out["mirror_failed"]), (1, 1, 1, 1))
        self.assertEqual([(m["session"], m["ts"]) for m in out["misses"]], [("zed", at(111))])

    def test_a_cohort_session_without_a_mirror_counts_as_a_session_without_a_log(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            projects = Path(tmp) / "projects"
            mirrors = Path(tmp) / "stop-guard"
            write(projects / "p1" / "zed.jsonl", session())
            out = field_hook.collect(projects, mirrors, SINCE, UNTIL)
        self.assertEqual((out["sessions"], out["sessions_with_log"], out["blocks"], out["misses"]), (1, 0, 0, []))


class Units(unittest.TestCase):
    def test_mirror_lines_keeps_well_formed_in_window_lines_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "s.jsonl"
            p.write_text(json.dumps(decision(10, "block", "open-tasks")) + "\n{\"ts\":\"nope\"}\n[1]\n" + json.dumps(decision(-100000, "allow", "cap")) + "\n")
            self.assertEqual([d["reason"] for d in field_hook.mirror_lines(p, SINCE, UNTIL)], ["open-tasks"])
        self.assertEqual(field_hook.mirror_lines(Path(tmp) / "missing.jsonl", SINCE, UNTIL), [])

    def test_misses_are_hand_back_allows_that_follow_a_premature_stop_within_a_minute(self) -> None:
        # 50 precedes the stop at 110 (an earlier stop's allow), 112 is a cap, 200 is past the minute: only 111 is a miss.
        lines = [decision(50, "allow", "handback-line"), decision(111, "allow", "handback-text"), decision(112, "allow", "cap"), decision(200, "allow", "handback-text")]
        self.assertEqual([m["ts"] for m in field_hook.misses(lines, [parse_ts(at(110))])], [at(111)])
        self.assertEqual([m["ts"] for m in field_hook.misses([decision(109, "allow", "handback-text")], [parse_ts(at(110))])], [at(109)])
        self.assertEqual(field_hook.misses(lines, []), [])


if __name__ == "__main__":
    unittest.main()
```

Run: `python3 -m unittest test_field_hook -v 2>&1 | tail -n 4` — Expected: `ModuleNotFoundError: No module named 'field_hook'`.

- [ ] **Step 2: Write `field_hook.py`**

```python
"""The stop guard's record over the field cohort.

For every session ``field.cohort`` qualifies, the hook's record is
``<mirror_dir>/<session id>.jsonl`` (Claude Code names a transcript after its
session id, so the transcript's stem is the key). Inside the window it counts
blocks, allows by reason, ``cap``, ``log-failed`` and ``hook-error`` events and
``mirror_failed`` marks, blocks per 100 boundaries against the transcript
measure's count, and the hook's misses: hand-back allows that follow, within a
minute, a turn end the transcript measure scores as premature (spec Design §5).
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any, Sequence

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import field
from liveness import parse_ts

HANDBACK = ("handback-text", "handback-line")
MINUTE = timedelta(minutes=1)
SKEW = timedelta(seconds=2)
DEFAULT_PROJECTS = Path.home() / ".claude" / "projects"
DEFAULT_MIRRORS = Path.home() / ".cache" / "hyperpowers" / "stop-guard"


def mirror_lines(path: Path, since: datetime, until: datetime) -> list[dict[str, Any]]:
    """Well-formed decision lines of one mirror inside the window, in file order."""
    out: list[dict[str, Any]] = []
    if not path.is_file():
        return out
    for raw in path.read_text().splitlines():
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(d, dict) or "ts" not in d:
            continue
        try:
            when = parse_ts(str(d["ts"]))
        except ValueError:
            continue
        if since <= when < until:
            out.append(d)
    return out


def misses(lines: Sequence[dict[str, Any]], premature_times: Sequence[datetime]) -> list[dict[str, Any]]:
    """Hand-back allows the transcript measure contradicts.

    The Stop hook runs after the message a turn ends on, so an allow belongs to
    a premature stop only inside ``[stop - 2 s, stop + 1 min]``; an allow before
    that window was an earlier stop's.
    """
    out: list[dict[str, Any]] = []
    for d in lines:
        if d.get("decision") != "allow" or d.get("reason") not in HANDBACK:
            continue
        when = parse_ts(str(d["ts"]))
        if any(-SKEW <= when - t <= MINUTE for t in premature_times):
            out.append(d)
    return out


def collect(projects: Path, mirror_dir: Path, since: datetime, until: datetime) -> dict[str, Any]:
    base = field.collect(projects, since, until)
    totals: Counter[str] = Counter()
    allows: Counter[str] = Counter()
    sessions = with_log = 0
    missed: list[dict[str, Any]] = []
    for path, records, first in field.cohort(projects, since, until):
        sessions += 1
        lines = mirror_lines(mirror_dir / f"{path.stem}.jsonl", since, until)
        if not lines:
            continue
        with_log += 1
        for d in lines:
            if d.get("decision") == "block":
                totals["blocks"] += 1
            else:
                allows[str(d.get("reason"))] += 1
            if d.get("mirror_failed"):
                totals["mirror_failed"] += 1
        premature = [end.at for end in field.premature_ends(records, first, until)]
        missed.extend({"session": path.stem, **d} for d in misses(lines, premature))
    boundaries = base["boundaries"]
    return {
        "window": base["window"],
        "sessions": sessions,
        "sessions_with_log": with_log,
        "boundaries": boundaries,
        "blocks": totals["blocks"],
        "blocks_per_100": round(100 * totals["blocks"] / boundaries, 2) if boundaries else None,
        "allows": dict(sorted(allows.items())),
        "cap": allows["cap"],
        "log_failed": allows["log-failed"],
        "hook_error": allows["hook-error"],
        "mirror_failed": totals["mirror_failed"],
        "misses": missed,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--since", required=True, help="ISO-8601 UTC, inclusive")
    parser.add_argument("--until", required=True, help="ISO-8601 UTC, exclusive")
    parser.add_argument("--projects", type=Path, default=DEFAULT_PROJECTS)
    parser.add_argument("--mirror-dir", type=Path, default=DEFAULT_MIRRORS)
    args = parser.parse_args(argv)
    since = datetime.fromisoformat(args.since).astimezone(UTC)
    until = datetime.fromisoformat(args.until).astimezone(UTC)
    print(json.dumps(collect(args.projects, args.mirror_dir, since, until), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Add to the README's `## Field decision rule` one paragraph: the after-window's hook measure is `python3 field_hook.py --since <window start> --until <window end>` run beside `field.py` over the same window, and its `misses` list is the "hook's misses" the rule names.

- [ ] **Step 3: Run, lint, commit**

Run: `python3 -m unittest test_field_hook test_field; ruff check .; mypy field_hook.py test_field_hook.py field.py` in the directory — Expected: OK, clean, no issues. Leak scan, `bun run check`, `git add evidence/2026-10-19-sdd-turn-liveness/field_hook.py evidence/2026-10-19-sdd-turn-liveness/test_field_hook.py evidence/2026-10-19-sdd-turn-liveness/README.md`, commit `test(evidence): the hook-record field reader`.

---

### Task 13: The fixture's deliberate conflict and the story's answer

**Risk tier:** standard — a stimulus change the whole campaign depends on, with a harness test.

**Files:**
- Modify (evals worktree): `fixtures/sdd-turn-liveness/plan.md:67-80` (Task 1's Produces list) and `:545-556` (Task 5's Produces line), `scenarios/sdd-turn-liveness/story.md:18` (the answer list), `test/setup-helpers-sdd.test.ts:57-80`

**Interfaces:**
- Consumes: nothing.
- Produces: a plan with one conflict between two tasks' values for the same constant (spec Design §4), so the pre-flight scan must surface it as the batched question and every run has a legitimate mid-plan hand-back; the Gauntlet's scripted answer.

**Mirror:** `test/setup-helpers-sdd.test.ts:57-80` (the plan-shape test, with `sections[0]` Task 1 and `sections[4]` Task 5).

- [ ] **Step 1: Extend the plan-shape test**

In `test/setup-helpers-sdd.test.ts`, after the existing expectations of the plan test:

```ts
    // The deliberate conflict (stop-guard spec, Design §4): Task 1 and Task 5 give DEFAULT_WINDOW_SECONDS two values.
    expect(sections[0]).toContain('`DEFAULT_WINDOW_SECONDS = 1.0` in `ratelimit/__init__.py`');
    expect(sections[4]).toContain('`--window` is optional and defaults to `DEFAULT_WINDOW_SECONDS` from Task 1, which is 1.5 seconds.');
```

Run: `bun test test/setup-helpers-sdd.test.ts` — Expected: 1 fail.

- [ ] **Step 2: Edit the fixture and the story**

`fixtures/sdd-turn-liveness/plan.md`, Task 1's Produces list gains a third item after `FakeClock`: `` - `DEFAULT_WINDOW_SECONDS = 1.0` in `ratelimit/__init__.py`: the window `simulate` uses when `--window` is omitted. `` Task 5's Interfaces gain, after the `Produces:` line: `` - `--window` is optional and defaults to `DEFAULT_WINDOW_SECONDS` from Task 1, which is 1.5 seconds. `` Nothing else changes: the soak tests, the task count, the covering commands and their runtimes stay as the plan-shape test requires.

`scenarios/sdd-turn-liveness/story.md`, the answer list: replace "About a conflict or ambiguity in the plan: "implement the plan exactly as written"." with "About the plan's conflict over `DEFAULT_WINDOW_SECONDS` (Task 1 defines it as 1.0, Task 5 calls it 1.5): "Task 1 governs: the constant is 1.0 and the CLI default follows it". About any other conflict or ambiguity in the plan: "implement the plan exactly as written"."

- [ ] **Step 3: Check**

Run: `bun test test/setup-helpers-sdd.test.ts && bun run quorum check` — Expected: pass; `quorum check` ok for `sdd-turn-liveness`.

- [ ] **Step 4: Commit**

Leak scan, `bun run check`, `git add fixtures/sdd-turn-liveness/plan.md scenarios/sdd-turn-liveness/story.md test/setup-helpers-sdd.test.ts`, commit `test(scenario): the turn-liveness plan gives one constant two values for the pre-flight question`.

---
### Task 14: The run analyzer's artifact readers

**Risk tier:** high — the analyzer's output is what the tally and the decision trust; this task decides which artifacts are a run's.

**Files:**
- Create (evals worktree): `evidence/2026-10-23-sdd-stop-guard/liveness.py`, `synth.py`, `analyze.py`, `test_liveness.py`, `test_analyze.py` (copied from `evidence/2026-10-19-sdd-turn-liveness/` and changed as below)

**Interfaces:**
- Consumes: the archived run layout (`<run>/verdict.json`, `<run>/gauntlet-agent/results/*/result.json`, `workspaces/<run>/home/.claude/projects/*/<session>.jsonl`, `workspaces/<run>/home/.cache/hyperpowers/{state,sdd}/<key>/plans/<ws>/`, `workspaces/<run>/home/.cache/hyperpowers/receipts/<ws>-<UTC>/`, `workspaces/<run>/home/.cache/hyperpowers/stop-guard/<session>.jsonl`); the decision-line schema (Global Constraints); `meta.json`'s keys (Task 3); Claude Code's transcript file name as the session id.
- Produces, in `analyze.py`: `ArtifactError`; `session_id(transcript) -> str`; `receipt_for(workspace, sid) -> Path | None` (the newest receipt by the UTC stamp in its name whose ledger carries `session <sid>:`; a dot-prefixed staging counts only with a `FINISHED` marker); `live_workspace_for(workspace, sid) -> Path | None` (the one live workspace whose ledger carries the session; two raise `ArtifactError`); `ledger_text_for(receipt, live) -> str`; `plan_path_from(text) -> str | None`; `ledger_tasks_from(text) -> set[int]`; `decisions_for(workspace, receipt, live, sid) -> tuple[list[dict], list[tuple[dict, dict]]]` (the union keyed by `(ts, session)` in timestamp order, and the pairs whose payloads differ under one key); `jobs_for(receipt, live) -> list[dict]` (each `meta.json` with `_dir`); `stop_lines(record) -> list[tuple[str, str]]` (as before); `stop_times(stops, records) -> list[tuple[str, str, datetime | None]]` (each listed stop timed from the main transcript); `read_adjudications(path) -> dict[tuple[str, str], str]` (rows `run_id<TAB>key<TAB>label`, `#` comments). Task 15 builds `measure` on these; `synth.make_run` gains the keyword arguments below for both tasks' tests.

**Mirror:** `evidence/2026-10-19-sdd-turn-liveness/analyze.py:179` (`read_adjudications`), `:221-250` (`stop_lines`, `_label`), `:143` (`main_transcript`); `test_analyze.py` and `synth.py:206` (`make_run`) for the fixtures.

- [ ] **Step 1: Copy and prune**

Copy `liveness.py`, `synth.py`, `analyze.py`, `test_liveness.py`, `test_analyze.py` from `evidence/2026-10-19-sdd-turn-liveness/` to `evidence/2026-10-23-sdd-stop-guard/`. In `analyze.py` delete the ledger-mark machinery: `MARK`, `TASK_LINE`, `_ledger_marks`, `_is_ledger_path`, `_cwd_segments`, `_names_file`, `_writes_ledger`, `_interpret_escapes`, `_unescape`, `_requote`, `PRINTF_FORMAT`, `ECHO_E`, `ANSI_C`, `ESCAPE`, `ESCAPES`, `HEREDOC`, `_heredoc_command`, `_strip_heredocs`, `_final_content`, `_executed`, the `plan_at` logic in `_transcript_measures`, and the `candidates`/`premature`/`unadjudicated` computation; delete their tests. Keep the dispatch classification, `_untracked`, `shell_detaches`, `runs_soak`, the short-soak measure, the Codex checks, `void_kind`, `stop_lines`, `normalize`, `_calls`, `Call`. Run `python3 -m unittest test_liveness test_analyze` to find what else the deletions pulled out; remove only what no longer has a caller.

- [ ] **Step 2: Extend `synth.make_run` and write the failing reader tests**

`make_run` gains keyword arguments, all optional: `sid: str = "sess-1"` (the transcript file name), `receipt: dict | None` (`{"ledger": str, "log": list[dict], "jobs": list[dict], "name": str, "finished": bool}` written under `home/.cache/hyperpowers/receipts/<name>/`, with a `FINISHED` marker file when `finished` is true), `extra_receipts: list[dict]` (more receipt dicts, for other sessions or older stamps), `mirror: list[dict]` (written to `home/.cache/hyperpowers/stop-guard/<sid>.jsonl`), `workspace_ledger: str | None`, `workspace_log: list[dict]`, `workspace_jobs: list[dict]` (written under `home/.cache/hyperpowers/state/<key>/plans/<ws>/`), `extra_workspaces: list[dict]`, `stops: list[tuple[str, str]]` (the Gauntlet's STOP entries written into `result.json` in the shape `stop_lines` reads), `records: list[Record]` (the main transcript). A job dict is written as `jobs/<name>-x-<n>/meta.json` and, when it has `code`, `jobs/<name>-x-<n>/exit`. `ledger_text(done=[...], sid="sess-1", plan="plan.md")` builds a ledger with the session line and completion lines; `line(ts, decision, reason, **extra)` builds a decision dict with `session` set to the fixture's id.

In `test_analyze.py`:

```python
class Readers(unittest.TestCase):
    def test_receipt_for_picks_the_newest_receipt_carrying_the_session_and_skips_unfinished_staging(self) -> None:
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "name": "p-20261023T100000Z"},
                       extra_receipts=[{"ledger": ledger_text(done=[1]), "name": "p-20261023T090000Z"},
                                       {"ledger": ledger_text(done=[1], sid="other"), "name": "p-20261023T110000Z"},
                                       {"ledger": ledger_text(done=[1]), "name": ".staging-p-20261023T120000Z"}])
        ws = analyze.workspace_of(run)
        self.assertEqual(analyze.receipt_for(ws, "sess-1").name, "p-20261023T100000Z")
        self.assertIsNone(analyze.receipt_for(ws, "nobody"))
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "name": "p-20261023T100000Z"},
                       extra_receipts=[{"ledger": ledger_text(done=[1]), "name": ".staging-p-20261023T130000Z", "finished": True}])
        self.assertEqual(analyze.receipt_for(analyze.workspace_of(run), "sess-1").name, ".staging-p-20261023T130000Z")

    def test_live_workspace_for_needs_exactly_one_ledger_with_the_session(self) -> None:
        run = make_run(workspace_ledger=ledger_text(done=[1]), extra_workspaces=[{"ledger": ledger_text(done=[2], sid="other")}])
        self.assertIsNotNone(analyze.live_workspace_for(analyze.workspace_of(run), "sess-1"))
        self.assertIsNone(analyze.live_workspace_for(analyze.workspace_of(run), "nobody"))
        run = make_run(workspace_ledger=ledger_text(done=[1]), extra_workspaces=[{"ledger": ledger_text(done=[2])}])
        with self.assertRaises(analyze.ArtifactError):
            analyze.live_workspace_for(analyze.workspace_of(run), "sess-1")

    def test_decisions_are_the_union_by_timestamp_and_session(self) -> None:
        a = line("2026-10-23T10:05:00.000Z", "block", "open-tasks", refusals=1)
        b = line("2026-10-23T10:06:00.000Z", "allow", "handback-text")
        c = line("2026-10-23T10:07:00.000Z", "block", "open-tasks", refusals=1)
        d = line("2026-10-23T11:00:00.000Z", "allow", "no-ledger", plan=None)  # after Finish: mirror only
        other = line("2026-10-23T10:05:30.000Z", "block", "open-tasks", session="stranger")
        # the mirror lost a middle line (b) and its final line (c); the receipt has them; the mirror alone has d
        run = make_run(receipt={"ledger": ledger_text(done=[1, 2, 3, 4, 5, 6]), "log": [a, b, c]}, mirror=[a, other, d])
        ws = analyze.workspace_of(run)
        decisions, conflicts = analyze.decisions_for(ws, analyze.receipt_for(ws, "sess-1"), None, "sess-1")
        self.assertEqual([x["reason"] for x in decisions], ["open-tasks", "handback-text", "open-tasks", "no-ledger"])
        self.assertEqual(conflicts, [])

    def test_two_payloads_under_one_key_are_a_conflict(self) -> None:
        a = line("2026-10-23T10:05:00.000Z", "block", "open-tasks", refusals=1)
        a2 = {**a, "reason": "live-shell"}
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "log": [a]}, mirror=[a2])
        ws = analyze.workspace_of(run)
        decisions, conflicts = analyze.decisions_for(ws, analyze.receipt_for(ws, "sess-1"), None, "sess-1")
        self.assertEqual(len(decisions), 1)
        self.assertEqual([(x["reason"], y["reason"]) for x, y in conflicts], [("open-tasks", "live-shell")])

    def test_an_unfinished_run_reads_the_live_workspace_log_and_jobs(self) -> None:
        a = line("2026-10-23T10:05:00.000Z", "block", "open-tasks", refusals=1)
        run = make_run(workspace_ledger=ledger_text(done=[1]), workspace_log=[a], workspace_jobs=[{"name": "soak", "state": "running"}])
        ws = analyze.workspace_of(run)
        live = analyze.live_workspace_for(ws, "sess-1")
        decisions, _ = analyze.decisions_for(ws, None, live, "sess-1")
        self.assertEqual([x["reason"] for x in decisions], ["open-tasks"])
        self.assertEqual([j["name"] for j in analyze.jobs_for(None, live)], ["soak"])
        self.assertEqual(analyze.ledger_tasks_from(analyze.ledger_text_for(None, live)), {1})
        self.assertEqual(analyze.plan_path_from(analyze.ledger_text_for(None, live)), "plan.md")

    def test_jobs_come_from_the_receipt_when_there_is_one(self) -> None:
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "jobs": [{"name": "soak", "state": "exited", "code": 0}]},
                       workspace_ledger=ledger_text(done=[1], sid="stale"), workspace_jobs=[{"name": "stale", "state": "lost"}])
        ws = analyze.workspace_of(run)
        jobs = analyze.jobs_for(analyze.receipt_for(ws, "sess-1"), None)
        self.assertEqual([(j["name"], j["state"]) for j in jobs], [("soak", "exited")])
        self.assertTrue(jobs[0]["_dir"].endswith("soak-x-0"))

    def test_stop_times_come_from_the_main_transcript_in_order(self) -> None:
        recs = [human(0, "go"), assistant(10, "Task 1 done. Moving to Task 2."), human(100, "continue"),
                assistant(110, "Which option do you want?"), human(200, "Task 1 governs"),
                assistant(210, "Task 1 done. Moving to Task 2."), human(300, "continue"), assistant(310, "All done.")]
        stops = [("Task 1 done. Moving to Task 2.", "neither"), ("Which option do you want?", "question"),
                 ("Task 1 done. Moving to Task 2.", "neither"), ("never said", "neither")]
        timed = analyze.stop_times(stops, recs)
        self.assertEqual([t for _, _, t in timed], [parse_ts(at(10)), parse_ts(at(110)), parse_ts(at(210)), None])
```

(`workspace_of(run)` is the existing helper that maps a record directory to its `workspaces/<run>/` copy; if the copied analyzer names it differently, use that name throughout.) Run: `python3 -m unittest test_analyze.Readers 2>&1 | tail -n 3` — Expected: `AttributeError` on the new names.

- [ ] **Step 3: Implement the readers**

In `analyze.py`:

```python
RECEIPTS_DIR = "hyperpowers/receipts"
MIRROR_DIR = "hyperpowers/stop-guard"
LEDGER_HEAD = re.compile(r"^# SDD ledger — plan: (.+)$", re.MULTILINE)
COMPLETE_LINE = re.compile(r"(?:^|[^A-Za-z0-9])Task (\d+): complete")


class ArtifactError(Exception):
    """An archived run whose artifacts contradict each other."""


def session_id(transcript: Path) -> str:
    return transcript.stem


def _carries(ledger: Path, sid: str) -> bool:
    try:
        return any(l.startswith(f"session {sid}:") for l in ledger.read_text().splitlines())
    except OSError:
        return False


def _is_receipt(d: Path) -> bool:
    """A receipt directory: not dot-prefixed, or a staging that finish marked FINISHED."""
    return not d.name.startswith(".") or (d / "FINISHED").is_file()


def receipt_for(workspace: Path, sid: str) -> Path | None:
    """The newest receipt (by the UTC stamp its name ends in) whose ledger carries the session."""
    root = workspace / "home" / ".cache" / RECEIPTS_DIR
    hits = [p.parent for p in root.glob("*/progress.md") if _is_receipt(p.parent) and _carries(p, sid)]
    return max(hits, key=lambda p: p.name.rsplit("-", 1)[-1]) if hits else None


def live_workspace_for(workspace: Path, sid: str) -> Path | None:
    """The one live workspace whose ledger carries the session (a run that never reached Finish)."""
    hits = [p.parent for p in workspace.glob("home/.cache/hyperpowers/*/*/plans/*/progress.md") if _carries(p, sid)]
    if len(hits) > 1:
        raise ArtifactError(f"{len(hits)} live workspaces carry session {sid}")
    return hits[0] if hits else None


def ledger_text_for(receipt: Path | None, live: Path | None) -> str:
    for root in (receipt, live):
        if root is not None and (root / "progress.md").is_file():
            return (root / "progress.md").read_text()
    return ""


def plan_path_from(text: str) -> str | None:
    m = LEDGER_HEAD.search(text)
    return m.group(1).strip() if m else None


def ledger_tasks_from(text: str) -> set[int]:
    return {int(m.group(1)) for m in COMPLETE_LINE.finditer(text)}


def _lines(path: Path, sid: str) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if not path.is_file():
        return out
    for raw in path.read_text().splitlines():
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        if isinstance(d, dict) and d.get("session") == sid:
            out.append(d)
    return out


def decisions_for(workspace: Path, receipt: Path | None, live: Path | None, sid: str) -> tuple[list[dict[str, Any]], list[tuple[dict[str, Any], dict[str, Any]]]]:
    """The union of the plan log (the receipt's, else the live workspace's) and the session mirror.

    Keyed by ``(ts, session)``; a line present in one log only is kept; two
    different payloads under one key are returned as a conflict, which the
    tally voids as an instrument failure.
    """
    plan_root = receipt if receipt is not None else live
    sources = ([plan_root / "stop-guard.jsonl"] if plan_root is not None else []) + [workspace / "home" / ".cache" / MIRROR_DIR / f"{sid}.jsonl"]
    seen: dict[tuple[str, str], dict[str, Any]] = {}
    conflicts: list[tuple[dict[str, Any], dict[str, Any]]] = []
    for path in sources:
        for d in _lines(path, sid):
            key = (str(d.get("ts")), str(d.get("session")))
            prior = seen.get(key)
            if prior is None:
                seen[key] = d
            elif prior != d:
                conflicts.append((prior, d))
    return sorted(seen.values(), key=lambda d: str(d.get("ts"))), conflicts


def jobs_for(receipt: Path | None, live: Path | None) -> list[dict[str, Any]]:
    root = receipt if receipt is not None else live
    out: list[dict[str, Any]] = []
    if root is None:
        return out
    for meta in sorted(root.glob("jobs/*/meta.json")):
        try:
            m = json.loads(meta.read_text())
        except (OSError, ValueError):
            continue
        m["_dir"] = str(meta.parent)
        out.append(m)
    return out


def stop_times(stops: Sequence[tuple[str, str]], records: Sequence[Record]) -> list[tuple[str, str, datetime | None]]:
    """Each listed stop's time: the first turn end after the previous match whose text contains the quote.

    The Gauntlet lists its stops in order, so matching is one-to-one and
    chronological; a quote found in no turn end is timed ``None``, which the
    tally treats as an instrument failure.
    """
    ends = turn_ends(records)
    out: list[tuple[str, str, datetime | None]] = []
    start = 0
    for quote, label in stops:
        needle = normalize(quote)
        hit = next((i for i in range(start, len(ends)) if needle and needle in normalize(ends[i].text)), None)
        if hit is None:
            out.append((quote, label, None))
        else:
            out.append((quote, label, ends[hit].at))
            start = hit + 1
    return out
```

(`turn_ends`, `Record` and `datetime` join the imports from `liveness`.) `read_adjudications` keeps its shape.

- [ ] **Step 4: Run the suites**

Run: `python3 -m unittest test_liveness test_analyze; ruff check .; mypy liveness.py synth.py analyze.py test_liveness.py test_analyze.py` in the new directory — Expected: OK, clean, no issues.

- [ ] **Step 5: Commit**

Leak scan, `bun run check`, `git add evidence/2026-10-23-sdd-stop-guard/`, commit `test(evidence): the stop-guard run analyzer reads receipts, mirrors and job records by session`.

---

### Task 15: The run analyzer's measures

**Risk tier:** high — these numbers are the inputs of H1 to H4.

**Files:**
- Modify (evals worktree): `evidence/2026-10-23-sdd-stop-guard/analyze.py` (`measure`, `empty_measure`, the new helpers), `liveness.py` (`live_kinds_at`), `test_analyze.py`, `test_liveness.py`

**Interfaces:**
- Consumes: Task 14's readers; `liveness.tasks`, `turn_ends`, `reloads`, `state_at`, `Task`; `Call` (`name`, `inp`, `result`); `parse_ts`.
- Produces: `liveness.live_kinds_at(at, task_map) -> set[str]`; `analyze.match_allows(stops, decisions) -> tuple[list, list]` (matched and unmatched; an allow matches a stop only inside `[stop - 2 s, stop + 1 min]`, consumed one-to-one in time order); `analyze.live_shell_turn_ends(records) -> list[str]`; `analyze.long_job_of(jobs)`, `analyze.long_ok_from(job, calls) -> bool`; `measure(record, adjudicated) -> dict` with the previous keys minus the retired ones (`ledger_marks`, `plan_at`, `candidates`, `premature`, `unadjudicated`) and these: `receipt` (path or None), `plan_path`, `plan_complete`, `decisions` (the union), `decision_conflicts` (count), `plan_decisions` (lines whose `plan` is the run's plan path), `blocks`, `allows` (reason to count), `listed_stops` (`(quote, label, ts)`), `neither_listed`, `unmatched_stops`, `false_blocks` (blocks labelled `handback`), `false_handbacks` (hand-back allows labelled `neither`), `unadjudicated_allows` (hand-back allows without a label), `unadjudicated_blocks` (blocks without a label), `live_shell_turn_ends`, `long_job`, `long_ok`, `live_complete`; `plan_complete` is true only when a receipt exists and its ledger holds every task's completion line (the plan is unfinished until Finish removed its ledger, spec Decision 5), `live_complete` reads the live workspace's ledger the same way for diagnosing runs that never reached Finish, and `success` keeps its previous definition and additionally requires `receipt`. Task 16's tally applies H1 to H4 and R to these.

**Mirror:** `evidence/2026-10-19-sdd-turn-liveness/analyze.py:840-884` (`measure`), `:672-683` (`empty_measure`).

- [ ] **Step 1: Write the failing tests**

In `test_liveness.py`:

```python
    def test_live_kinds_at_names_the_kinds_of_tasks_live_at_a_moment(self) -> None:
        recs = [human(0, "go"), assistant(10, tools=[("a1", "Agent", {"description": "x"})]), result(11, "a1", AGENT_BG),
                assistant(20, tools=[("b1", "Bash", {"command": "sleep 9", "run_in_background": True})]), result(21, "b1", BASH_BG),
                notification(50, "a1"), notification(90, "b1")]
        task_map = liveness.tasks(recs)
        self.assertEqual(liveness.live_kinds_at(parse_ts(at(30)), task_map), {"agent", "shell"})
        self.assertEqual(liveness.live_kinds_at(parse_ts(at(60)), task_map), {"shell"})
        self.assertEqual(liveness.live_kinds_at(parse_ts(at(95)), task_map), set())
```

In `test_analyze.py`:

```python
class Measures(unittest.TestCase):
    def test_plan_completion_reads_the_receipt_ledger(self) -> None:
        run = make_run(receipt={"ledger": ledger_text(done=[1, 2, 3, 4, 5, 6])})
        m = analyze.measure(run, {})
        self.assertTrue(m["plan_complete"]); self.assertEqual(m["plan_path"], "plan.md")

    def test_an_unfinished_run_reads_the_live_workspace(self) -> None:
        run = make_run(workspace_ledger=ledger_text(done=[1, 2, 3]))
        m = analyze.measure(run, {})
        self.assertIsNone(m["receipt"]); self.assertFalse(m["plan_complete"]); self.assertFalse(m["live_complete"])

    def test_every_task_done_without_a_receipt_is_not_a_success(self) -> None:
        # The suite's successful-run keyword arguments (records and verdict that the previous
        # success definition accepts, factored into successful_run_kwargs() if they are inline),
        # with the receipt replaced by a live ledger that holds all six completion lines.
        run = make_run(**{**successful_run_kwargs(), "receipt": None, "workspace_ledger": ledger_text(done=[1, 2, 3, 4, 5, 6])})
        m = analyze.measure(run, {})
        self.assertTrue(m["live_complete"]); self.assertFalse(m["plan_complete"]); self.assertFalse(m["success"])
        run = make_run(**successful_run_kwargs())
        self.assertTrue(analyze.measure(run, {})["success"])

    def test_plan_decisions_count_lines_for_the_plan_only(self) -> None:
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "log": [line("2026-10-23T10:05:00.000Z", "allow", "handback-text")]},
                       mirror=[line("2026-10-23T11:00:00.000Z", "allow", "no-ledger", plan=None), line("2026-10-23T11:01:00.000Z", "allow", "ambiguous", plan=None)])
        m = analyze.measure(run, {})
        self.assertEqual((m["plan_decisions"], m["blocks"], m["allows"]), (1, 0, {"ambiguous": 1, "handback-text": 1, "no-ledger": 1}))
        run = make_run(mirror=[line("2026-10-23T11:00:00.000Z", "allow", "no-ledger", plan=None)])
        self.assertEqual(analyze.measure(run, {})["plan_decisions"], 0)

    def test_listed_stops_match_allows_one_to_one_within_a_minute(self) -> None:
        recs = [human(0, "go"), assistant(10, "Which option do you want?"), human(100, "Task 1 governs"),
                assistant(110, "Second question?"), human(200, "yes"), assistant(300, "Moving to Task 3.")]
        allow = line(at(12), "allow", "handback-text")
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "log": [allow]}, records=recs,
                       stops=[("Which option do you want?", "question"), ("Second question?", "question"), ("Moving to Task 3.", "neither"), ("never said", "neither")])
        m = analyze.measure(run, {(run.name, at(12)): "handback"})
        self.assertEqual(m["neither_listed"], 2)
        self.assertEqual([q for q, _, _ in m["unmatched_stops"]], ["Second question?", "Moving to Task 3.", "never said"])

    def test_an_allow_before_the_stop_does_not_match_it(self) -> None:
        recs = [human(0, "go"), assistant(10, "Which option do you want?"), human(100, "Task 1 governs"), assistant(110, "Second question?"), human(200, "yes")]
        early = line(at(80), "allow", "handback-text")
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "log": [early]}, records=recs, stops=[("Second question?", "question")])
        m = analyze.measure(run, {(run.name, at(80)): "handback"})
        self.assertEqual([q for q, _, _ in m["unmatched_stops"]], ["Second question?"])
        late = line(at(111), "allow", "handback-text")
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "log": [early, late]}, records=recs, stops=[("Second question?", "question")])
        self.assertEqual(analyze.measure(run, {(run.name, at(80)): "handback", (run.name, at(111)): "handback"})["unmatched_stops"], [])

    def test_adjudication_labels_blocks_and_allows_by_timestamp(self) -> None:
        log = [line(at(10), "block", "open-tasks", refusals=1), line(at(20), "allow", "handback-text"), line(at(30), "allow", "handback-line"), line(at(40), "block", "open-tasks", refusals=1)]
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "log": log})
        m = analyze.measure(run, {(run.name, at(10)): "handback", (run.name, at(20)): "neither", (run.name, at(30)): "handback"})
        self.assertEqual((m["false_blocks"], m["false_handbacks"], m["unadjudicated_allows"], m["unadjudicated_blocks"]), (1, 1, 0, 1))

    def test_a_decision_conflict_is_counted(self) -> None:
        a = line(at(10), "block", "open-tasks", refusals=1)
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "log": [a]}, mirror=[{**a, "reason": "live-shell"}])
        self.assertEqual(analyze.measure(run, {})["decision_conflicts"], 1)

    def test_long_ok_needs_the_job_record_and_the_foreground_watch(self) -> None:
        job = {"name": "soak-long", "state": "exited", "code": 0, "command": ["python3", "-m", "unittest", "tests.test_soak_long", "-v"],
               "launched": "2026-10-23T10:00:00.000Z", "ended": "2026-10-23T10:12:30.000Z"}
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "jobs": [job]}, records=watch_records(job))
        self.assertTrue(analyze.measure(run, {})["long_ok"])
        job_fast = {**job, "ended": "2026-10-23T10:03:00.000Z"}
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "jobs": [job_fast]}, records=watch_records(job_fast))
        self.assertFalse(analyze.measure(run, {})["long_ok"])
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "jobs": [job]}, records=[human(0, "go"), assistant(5, "ok.")])
        self.assertFalse(analyze.measure(run, {})["long_ok"])
        run = make_run(receipt={"ledger": ledger_text(done=[1]), "jobs": [{**job, "state": "lost"}]}, records=watch_records(job))
        self.assertFalse(analyze.measure(run, {})["long_ok"])

    def test_live_shell_turn_ends_count_only_shells(self) -> None:
        run = make_run(records=turn_end_with_live("shell"))
        self.assertEqual(len(analyze.measure(run, {})["live_shell_turn_ends"]), 1)
        run = make_run(records=turn_end_with_live("agent"))
        self.assertEqual(len(analyze.measure(run, {})["live_shell_turn_ends"]), 0)
        run = make_run(records=turn_end_with_live("both"))
        self.assertEqual(len(analyze.measure(run, {})["live_shell_turn_ends"]), 0)
```

`watch_records(job)` builds main-session records with one foreground Bash call whose `command` is `bash <root>/skills/subagent-driven-development/scripts/tracked-job wait <job _dir> --max-ms 600000` and whose result text is `status=exited code=0` (the job's `_dir` is `jobs/soak-long-x-0` under the receipt); `turn_end_with_live(kind)` builds a launch of that kind (`shell`: a background Bash; `agent`: an Agent; `both`: one of each) without completions, followed by a human message and a completion after it.

Run: `python3 -m unittest test_analyze.Measures test_liveness 2>&1 | tail -n 3` — Expected: failures on the new keys.

- [ ] **Step 2: Implement**

In `liveness.py`:

```python
def live_kinds_at(at: datetime, task_map: Mapping[str, Task]) -> set[str]:
    """The kinds of tracked tasks launched at or before ``at`` and not yet complete then."""
    return {t.kind for t in task_map.values() if t.launched <= at and (t.completed is None or t.completed > at)}
```

In `analyze.py`:

```python
HANDBACK_REASONS = ("handback-text", "handback-line")
MINUTE = timedelta(minutes=1)
LONG_MIN_ELAPSED_S = 600
TJ_WAIT = re.compile(r"tracked-job\s+wait\s+(\S+)")


SKEW = timedelta(seconds=2)


def match_allows(stops: Sequence[tuple[str, str, datetime | None]], decisions: Sequence[Mapping[str, Any]]) -> tuple[list[tuple[str, str, datetime, Mapping[str, Any]]], list[tuple[str, str, datetime | None]]]:
    """Pair every timed stop, in time order, with the earliest unused allow that follows it.

    The Stop hook runs after the assistant message the Gauntlet quotes, so a
    genuine decision lies in ``[stop - 2 s, stop + 1 min]``; an allow before
    that window belongs to an earlier stop and never satisfies a later one.
    """
    allows = sorted((d for d in decisions if d.get("decision") == "allow"), key=lambda d: str(d.get("ts")))
    used: set[int] = set()
    matched: list[tuple[str, str, datetime, Mapping[str, Any]]] = []
    unmatched: list[tuple[str, str, datetime | None]] = []
    timed = sorted((s for s in stops if s[2] is not None), key=lambda s: s[2])  # type: ignore[arg-type,return-value]
    for quote, label, when in timed:
        assert when is not None
        hit = next((i for i, d in enumerate(allows) if i not in used and -SKEW <= parse_ts(str(d["ts"])) - when <= MINUTE), None)
        if hit is None:
            unmatched.append((quote, label, when))
        else:
            used.add(hit)
            matched.append((quote, label, when, allows[hit]))
    unmatched.extend(s for s in stops if s[2] is None)
    return matched, unmatched


def live_shell_turn_ends(records: Sequence[Record]) -> list[str]:
    """Turn ends at which the only live tracked work is a shell."""
    task_map = tasks(records)
    reload_times = reloads(records)
    return [iso(e.at) for e in turn_ends(records)
            if e.excluded is None and state_at(e.at, task_map, reload_times) == "live" and live_kinds_at(e.at, task_map) == {"shell"}]


def long_job_of(jobs: Sequence[Mapping[str, Any]]) -> Mapping[str, Any] | None:
    for j in jobs:
        if any(LONG_SOAK in str(part) for part in j.get("command") or []):
            return j
    return None


def long_ok_from(job: Mapping[str, Any] | None, calls: Sequence[Call]) -> bool:
    """The long soak passed F: exited 0 after at least 600 s, and a foreground wait saw it."""
    if job is None or job.get("state") != "exited" or job.get("code") != 0:
        return False
    try:
        elapsed = (parse_ts(str(job["ended"])) - parse_ts(str(job["launched"]))).total_seconds()
    except (KeyError, ValueError):
        return False
    if elapsed < LONG_MIN_ELAPSED_S:
        return False
    name = Path(str(job.get("_dir", ""))).name
    for c in calls:
        if c.name != "Bash" or c.inp.get("run_in_background"):
            continue
        m = TJ_WAIT.search(str(c.inp.get("command") or ""))
        if m and Path(m.group(1)).name == name and "status=exited code=0" in (c.result or ""):
            return True
    return False
```

`measure` reads the transcript (`main_transcript`), takes `sid = session_id(transcript)`, `receipt = receipt_for(ws, sid)`, `live = live_workspace_for(ws, sid)` (an `ArtifactError` becomes `void-instrument` with the message in `void_detail`), `text = ledger_text_for(receipt, live)`, `plan_path = plan_path_from(text)`, `plan_complete` from `ledger_tasks_from` of the receipt's ledger against the fixture's six tasks (False without a receipt), `live_complete` the same over the live workspace's ledger, `success` as before and only with a receipt, `decisions, conflicts = decisions_for(...)`, `jobs = jobs_for(receipt, live)`, and derives: `blocks`, `allows` (a `Counter` of allow reasons as a dict), `plan_decisions` (decisions whose `plan` equals `plan_path`), `listed_stops = stop_times(stop_lines(record), records)`, `neither_listed`, `unmatched_stops` (from `match_allows`), the four adjudication counts keyed by `(run_id, ts)` with labels `handback` and `neither`, `live_shell_turn_ends`, `long_job = long_job_of(jobs)`, `long_ok = long_ok_from(long_job, calls)`, `decision_conflicts = len(conflicts)`. `empty_measure` carries every new key with its empty value.

- [ ] **Step 3: Run the suites**

Run: `python3 -m unittest test_liveness test_analyze; ruff check .; mypy liveness.py synth.py analyze.py test_liveness.py test_analyze.py` — Expected: OK, clean, no issues.

- [ ] **Step 4: Commit**

Leak scan, `bun run check`, `git add evidence/2026-10-23-sdd-stop-guard/`, commit `test(evidence): the stop-guard run analyzer derives the H1 to H4 measures`.

---

### Task 16: The tally applies H1 to H4 and R

**Risk tier:** high — the decision of record.

**Files:**
- Create (evals worktree): `evidence/2026-10-23-sdd-stop-guard/tally.py`, `test_tally.py` (copied from the 2026-10-19 directory and changed)

**Interfaces:**
- Consumes: `analyze.measure`, `analyze.empty_measure`, `analyze.read_adjudications` (Tasks 14 and 15); `manifest.tsv` rows `treatment sdd-turn-liveness <repeat> p<n> default` and the pin keys minus `control`/`control_root`; launch logs under `logs/`.
- Produces: `decide(treatment) -> dict` with `H1` to `H4` and `R` booleans, their supporting numbers (`runs_with_plan_decisions`, `neither_listed_total`, `false_handbacks_total`, `unadjudicated_allows_total`, `false_blocks_total`, `unadjudicated_blocks_total`, `foreground_share`, `untracked_total`, `f_runs`, `live_shell_turn_ends_total`, `success_runs`) and `decision` `PASS`/`FAIL`; `evaluate(...)` with `ARMS = ("treatment",)`, `UNCAPPED_VOIDS = ("void-setup", "void-transport", "void-instrument")`, a row status `void-instrument` when `unmatched_stops` is non-empty or `decision_conflicts` is positive, and `UNADJUDICATED` when any counted run has `unadjudicated_allows` or `unadjudicated_blocks`; `main` with `--manifest` (default `manifest.tsv`), `--archive` (default `task-20-runs/treatment`) and `--out` (default `tally.txt`), run from its own directory. Task 21's contingency runs it with a second manifest and archive.

**Mirror:** `evidence/2026-10-19-sdd-turn-liveness/tally.py:184-311`.

- [ ] **Step 1: Write the failing tests**

In `test_tally.py` (its `Campaign` helper adapted to one arm), cases: all criteria pass on ten clean measures; H1 fails when one run has `plan_decisions` 0 even with a `no-ledger` line; H2 fails on one `neither_listed`, on one `false_handbacks`, and is `UNADJUDICATED` on one `unadjudicated_allows`; H3 fails on one false block and is `UNADJUDICATED` on one `unadjudicated_blocks`; H4 fails on a 0.85 share, on one untracked launch, on eight F runs, and on one live-shell turn end; R fails at six successes; a run with an unmatched stop, and one with a decision conflict, are `void-instrument`, uncapped, and the campaign `INCOMPLETE` until replaced; the five `_problems` branches and the cap arithmetic carry over; `tally.txt`'s row format includes `plan_decisions=`, `blocks=`, `allows=`, `neither=`, `unmatched=`, `false_blocks=`, `false_handbacks=`; `--manifest`, `--archive` and `--out` are honoured.

- [ ] **Step 2: Implement `decide`**

```python
def decide(treatment: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    """H1 to H4 and R (stop-guard spec, Design §4) over the counted runs."""
    with_plan = sum(1 for r in treatment if r["plan_decisions"] >= 1)
    neither = sum(r["neither_listed"] for r in treatment)
    false_handbacks = sum(r["false_handbacks"] for r in treatment)
    pending_allows = sum(r["unadjudicated_allows"] for r in treatment)
    false_blocks = sum(r["false_blocks"] for r in treatment)
    pending_blocks = sum(r["unadjudicated_blocks"] for r in treatment)
    fg = sum(r["dispatch_fg"] for r in treatment)
    other = sum(r["dispatch_bg"] + r["dispatch_unclassified"] for r in treatment)
    share = fg / (fg + other) if fg + other else 0.0
    untracked = sum(len(r["untracked"]) for r in treatment)
    f_runs = sum(1 for r in treatment if r["short_ok"] and r["long_ok"])
    live_shell = sum(len(r["live_shell_turn_ends"]) for r in treatment)
    successes = sum(1 for r in treatment if r["success"])
    out: dict[str, Any] = {
        "runs_with_plan_decisions": with_plan, "H1": with_plan == len(treatment),
        "neither_listed_total": neither, "false_handbacks_total": false_handbacks, "unadjudicated_allows_total": pending_allows,
        "H2": neither == 0 and false_handbacks == 0 and pending_allows == 0,
        "false_blocks_total": false_blocks, "unadjudicated_blocks_total": pending_blocks, "H3": false_blocks == 0 and pending_blocks == 0,
        "foreground_share": round(share, 3), "untracked_total": untracked, "f_runs": f_runs, "live_shell_turn_ends_total": live_shell,
        "H4": share >= 0.9 and untracked == 0 and f_runs >= 9 and live_shell == 0,
        "success_runs": successes, "R": successes >= 7,
    }
    out["decision"] = "PASS" if out["H1"] and out["H2"] and out["H3"] and out["H4"] and out["R"] else "FAIL"
    return out
```

`evaluate` keeps its structure with one arm, adds the `void-instrument` status before the capped-void branch, and returns `UNADJUDICATED` naming the runs with pending labels. `main` parses `--manifest`, `--archive`, `--out`, prints the extended row format and the decision keys, and writes `--out`.

- [ ] **Step 3: Run, lint, commit**

Run: `python3 -m unittest test_tally; ruff check .; mypy tally.py test_tally.py` — Expected: OK. Leak scan, `bun run check`, commit `test(evidence): the stop-guard tally applies H1 to H4 and R`.

---

### Task 17: The campaign launcher, waiter and archive, and the fork-mode scenario copy

**Risk tier:** high — the launcher pins what runs and the archive preserves what the analyzer and the tally trust.

**Files:**
- Create (evals worktree): `evidence/2026-10-23-sdd-stop-guard/launch-all.sh`, `launch-all.test.sh`, `wait-done.sh`, `logs/measure-launch.sh`, `archive-runs.sh` (copies of the 2026-10-19 files, paths and names updated), `scenarios/sdd-turn-liveness-fork/{story.md,setup.sh,checks.sh}`

**Interfaces:**
- Consumes: the manifest schema (two-field pin rows for `harness`, `treatment`, `treatment_root`, `model`, `cc`, `cc_path`, `provider`, `subagent_models`, `codex`, `task_tools`; launch rows `<arm> <scenario> <repeat> <id> <profile>`), exercised by the fixture manifest `launch-all.test.sh` writes; Task 18 produces the real `manifest.tsv` that Tasks 19 to 21 launch.
- Produces: `launch-all.sh <manifest> [max]` accepting the arms `treatment`, `smoke`, `t1` and both scenario names; `measure-launch.sh` checking the pin without `control` keys; `archive-runs.sh <arm> <task-dir>` copying runs for the three arms and keeping `home/.cache/hyperpowers` (receipts, mirrors, state checkouts); the fork-mode scenario, identical to `sdd-turn-liveness` except that its `checks.sh` directive reads `# claude-env: CLAUDE_CODE_ENABLE_TODO_TOOLS=1` (fork mode on) and its header says why.

**Mirror:** `evidence/2026-10-19-sdd-turn-liveness/launch-all.sh:1-30`, `logs/measure-launch.sh:1-20`, `archive-runs.sh:1-25`.

- [ ] **Step 1: Copy and adapt**

Copy the five files; in `launch-all.sh` the arm set becomes `treatment|smoke|t1` and the scenario set `sdd-turn-liveness|sdd-turn-liveness-fork`; in `measure-launch.sh` the pin reads `treatment` and `treatment_root` only and the log names are `<arm>-<scenario>-<proc>.log`; in `archive-runs.sh` the arm set matches and the post-check asserts, for a run whose transcript reached Finish, that `home/.cache/hyperpowers/receipts/` holds a receipt and `home/.cache/hyperpowers/stop-guard/` a mirror. Create the fork scenario by copying the three files and editing the directive line and the comment above it.

- [ ] **Step 2: Test**

Run: `bash evidence/2026-10-23-sdd-stop-guard/launch-all.test.sh` (its manifest fixture adapted to the new arms and the pin keys above) and `bun run quorum check` — Expected: the stub test `STATUS: PASSED`; both scenarios valid. Also `bun test test/scenario-pinning.test.ts` still passes (the directive-window test reads `sdd-turn-liveness`).

- [ ] **Step 3: Commit**

Leak scan, `bun run check`, `git add evidence/2026-10-23-sdd-stop-guard/launch-all.sh evidence/2026-10-23-sdd-stop-guard/launch-all.test.sh evidence/2026-10-23-sdd-stop-guard/wait-done.sh evidence/2026-10-23-sdd-stop-guard/logs/measure-launch.sh evidence/2026-10-23-sdd-stop-guard/archive-runs.sh scenarios/sdd-turn-liveness-fork`, commit `test(evidence): the stop-guard campaign launcher, waiter, archive and the fork-mode scenario`.

---

### Task 18: Pre-registration

**Risk tier:** high — the pin every launch checks and the rule the tally implements.

**Files:**
- Create (evals worktree): `evidence/2026-10-23-sdd-stop-guard/README.md`, `manifest.tsv`, `adjudications.tsv` (header only)
- Modify (hyperpowers worktree): `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md`
- Create: the treatment root `/Users/johnss51/.cache/hyperpowers/sdd-stop-guard/hp-treatment` (a detached worktree at Task 10's commit, created outside the sandbox with `git -C /Users/johnss51/Development/agents/hyperpowers worktree add --detach <path> <commit>`)

**Interfaces:**
- Consumes: Task 10's commit (the treatment pin), the benchmark numbers from Task 9's suite output, the probe result (Task 1) and the deviation 1 assertion (Task 3), Correction 8 (Task 11), the manifest schema (Task 17).
- Produces: the campaign pin and the pre-registered rule; the note's "Pre-registered rules", "Benchmark" and "Field baseline" sections.

**Mirror:** `evidence/2026-10-19-sdd-turn-liveness/README.md` (sections `## Question`, `## Pre-registration`, `### Void rules`, `### Adjudication`, `## Analyzer pins`, `## Field decision rule`, `## Config`, `## Smoke`, `## Results`).

- [ ] **Step 1: Fill `manifest.tsv`**

Two-field rows: `harness` (the evals worktree `HEAD` after Task 17), `treatment` (Task 10's commit), `treatment_root`, `model claude-opus-5-5`, `cc`, `cc_path`, `provider vertex`, `subagent_models claude-opus-5-5,claude-sonnet-5-5,claude-haiku-4-5-20251001`, `codex absent`, `task_tools on`. Launch rows: `smoke sdd-turn-liveness 1 p1 default`, `t1 sdd-turn-liveness-fork 1 p1 default`, then `treatment sdd-turn-liveness 1 p1 default` through `p10`.

- [ ] **Step 2: Write `README.md`**

Sections in the previous README's order: **Question** (does the guard, with the helpers and the text, keep every provable premature stop from reaching the user without refusing a legitimate hand-back, while the mechanism measures hold?); **Pre-registration** with H1 to H4 and R verbatim from Global Constraints with the analyzer's names, the measure definitions (the decision record as the union of receipt log and mirror keyed by timestamp and session with conflicts voiding the run, the one-to-one chronological reconciliation with the Gauntlet's STOP list timed from the main transcript and `void-instrument`, the dispatch classification and untracked-launch tripwire carried over by reference to the 2026-10-19 README, the long-job measure from the job record plus the foreground watch, the live-shell turn end), the fixture change (two sentences added to the elicited plan giving one constant two values, nothing else; the soak tests untouched), the void rules (carried over plus `void-instrument`), and the adjudication procedure (every `block` and every hand-back `allow` gets a row keyed by its `ts`, labelled `handback` or `neither` by reading the transcript's last assistant text before it; a listed stop with no matching allow voids the run); **Analyzer pins** (`liveness.py`, `analyze.py`, `tally.py` blobs; the Corrections convention); **Hook pin** (the `hooks/lib/stop-guard.mjs` and `hooks/sdd-stop-guard` blobs at the treatment commit); **Field decision rule** (verbatim from the spec, with the corrected baseline and the two after-window measures, naming `field_hook.py`); **Config** (the pin, concurrency 5, the launch command form, `tally.py` run from its directory); **Benchmark** (the two numbers from Task 9's suite output and the host); **Known limits of the instrument** (the 200-line log tail, the newest-64 receipts scan, the second-resolution `hook-error` timestamp); **Smoke** and **T1** ("filled in by Task 19"); **Results** ("filled in by Task 20").

- [ ] **Step 3: Extend the hyperpowers note**

Sections "Pre-registered rules" (thresholds restated, pointer to the README), "Benchmark", "Field baseline" (the Correction 8 table), and empty "Scenario results", "T1", "Zed checks", "Release" marked for Tasks 19 to 22.

- [ ] **Step 4: Commit both**

Evals: leak scan, `bun run check`, commit `docs(evidence): pre-register the sdd-stop-guard campaign`. Hyperpowers: leak scan, commit `docs(hyperpowers): pre-register the SDD stop guard evaluation`. Record the evals pre-registration commit in the ledger: it is the `harness` pin's successor check for every later evals commit (analyzer-only commits are allowed; harness paths must stay identical).

---
### Task 19: The smoke and T1

**Risk tier:** high — live runs whose records are evidence.

**Files:**
- Create (evals worktree): `evidence/2026-10-23-sdd-stop-guard/smoke.md`, `task-19-runs/smoke/<run>/`, `task-19-runs/t1/<run>/` (archived per `evals/evidence/README.md`)
- Modify: `README.md` (Smoke and T1 sections); the hyperpowers note (T1)

**Interfaces:**
- Consumes: the launcher (Task 17), the pin (Task 18), the analyzer and tally (Tasks 14 to 16).
- Produces: a smoke run that passes H1 to H4 on its own (one run), or a stop with the reason; T1's record (fork mode on): dispatches background, `live-agent` allows in the hook log, completions correlated by tool-use id. Task 22 reads T1's archived record as a gate input.

- [ ] **Step 1: Launch the smoke**

Outside the sandbox: `nohup bash evidence/2026-10-23-sdd-stop-guard/launch-all.sh <manifest with the smoke row only> 1 > evidence/2026-10-23-sdd-stop-guard/logs/campaign-smoke.out 2>&1 &`, then `bash evidence/2026-10-23-sdd-stop-guard/wait-done.sh ...` in foreground calls of at most 600000 ms until the closing line. Expected: `DONE 0` and a run id.

- [ ] **Step 2: Archive the smoke, then read it**

`bash archive-runs.sh smoke task-19-runs` from the evidence directory, then the README post-check on the archived run. Run `python3 analyze.py task-19-runs/smoke/<run>` from the evidence directory (add a `main` that prints one run's measure as JSON if the copied one does not) and check: the receipt exists under the run's HOME; `plan_decisions` is at least 1 and the hook log holds the pre-flight question's `handback-text` or `handback-line` allow; no `block` that a human reads as a legitimate hand-back; `long_ok` and `short_ok` true; the STOP list has no `neither`; every listed stop matched; `decision_conflicts` 0. A smoke that fails any of these is a defect to fix before the counted runs (a fix round on the responsible task, re-pinned, and the smoke repeated); record every round in `smoke.md`.

- [ ] **Step 3: Launch T1**

The same way with the `t1` row; archive it with `bash archive-runs.sh t1 task-19-runs` and read `task-19-runs/t1/<run>`. Expected: the run completes; its hook log shows `live-agent` allows and the analyzer shows background dispatches with completions matched by tool-use id; H criteria are not applied to T1. Record its reading in `smoke.md`, the README's T1 section and the hyperpowers note's T1 section (the counts of `live-agent` allows and of background dispatches with matched completions).

- [ ] **Step 4: Commit**

Leak scan (replace any proxy host in logs with `<proxy-host>`); `bun run check`; commit `test(evidence): the stop-guard smoke and the fork-mode smoke T1` (evals) and `docs(hyperpowers): the T1 fork-mode record` (hyperpowers).

---

### Task 20: The ten counted runs, the tally and the records

**Risk tier:** high — the decision of record.

**Files:**
- Create (evals worktree): `evidence/2026-10-23-sdd-stop-guard/task-20-runs/treatment/<run>/` (ten or more, archived), `tally.txt`, `adjudications.tsv` rows, `logs/*.log`; `docs/experiments/2026-10-23-sdd-stop-guard.md`
- Modify: `README.md` (Results, Corrections if any), the hyperpowers note (Scenario results)

**Interfaces:**
- Consumes: everything above.
- Produces: `tally.txt` with `decision: PASS` or `FAIL`; the records Task 22 reads.

- [ ] **Step 1: Launch**

`launch-all.sh manifest.tsv 5` detached, watched with `wait-done.sh`; replacement rows (`r<n>`) for setup, transport and instrument voids; the capped voids counted against three.

- [ ] **Step 2: Archive every completed run, then post-check**

`bash archive-runs.sh treatment task-20-runs` from the evidence directory after each batch completes (voided runs included: they are part of the record), then the README post-check on every archived run. Nothing below reads a live record.

- [ ] **Step 3: Adjudicate from the archive**

For every counted run under `task-20-runs/treatment/`, read the archived transcript's last assistant text before each `block` and each hand-back `allow` (the hook log's `ts` finds it), and label `handback` or `neither` in `adjudications.tsv` as `run_id<TAB>ts<TAB>label`; a listed stop with no allow in its window, or a decision conflict, voids the run (`void-instrument`) and adds a replacement row, which goes back through Steps 1 and 2.

- [ ] **Step 4: Tally the archive**

`cd /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/sdd-stop-guard/evidence/2026-10-23-sdd-stop-guard && python3 tally.py` once every counted run is archived and labelled; any analyzer change on the way is a numbered Correction in the README before the tally it affects (the 2026-10-19 convention). Expected: `decision: PASS` with H1 to H4 and R true, or `FAIL` naming the criterion.

- [ ] **Step 5: Record**

README Results (the table of ten runs, each criterion's reading, limits), the experiment entry (Hypothesis, Config, Run pointers, Verdict, Limits), the hyperpowers note's Scenario results (the thresholds against the readings, decision). Leak scan; `bun run check`; commit `test(evidence): the stop-guard campaign, ten valid runs and the decision` (evals) and `docs(hyperpowers): the SDD stop guard scenario results` (hyperpowers).

---

### Task 21: The Zed checks Z1 to Z4 with the human partner, and the Z4 contingency

**Risk tier:** high — its contingency changes the treatment and produces `tally-z4.txt`, the decision of record Task 22 trusts, through a second ten-run campaign.

**Files:**
- Modify (hyperpowers worktree): `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md` (Zed checks)
- On Z4 failure (hyperpowers): `skills/subagent-driven-development/SKILL.md` (Rounds 1-3), `tests/sdd/test-sdd-contract.sh`; (evals): `evidence/2026-10-23-sdd-stop-guard/manifest-z4.tsv`, `README.md` (a dated "Pre-registration addendum (Z4 contingency)" section and a second Results table), `task-21-runs/treatment/<run>/`, `tally-z4.txt`, `adjudications.tsv` rows; a second treatment root `/Users/johnss51/.cache/hyperpowers/sdd-stop-guard/hp-treatment-z4`

**Interfaces:**
- Consumes: the treatment commit installed in `.worktrees/plugin-install`; the launcher and tally with `--manifest`, `--archive`, `--out` (Tasks 16 and 17).
- Produces: four recorded verdicts; under the contingency, a new treatment commit, a second manifest and the decision of record for Task 22 (`tally-z4.txt`).

- [ ] **Step 1: Prepare**

The human partner installs the treatment commit in `.worktrees/plugin-install` (checkout, reload plugins) in a Zed session on a scratch repository with a two-task plan and an SDD ledger. Scripts for each check are written to the SDD workspace by the controller and pasted by the human partner: Z1 dispatches an implementer with `run_in_background: false` for a five-minute task and watches the prompt indicator; Z2 presses Esc during it and resumes; Z3 asks the controller to stop mid-plan with a status message (the guard must refuse; the indicator must stay pending; the controller must continue); Z4 resumes an agent with `SendMessage` and watches the indicator.

- [ ] **Step 2: Record**

Each check gets a line in the note: what was done, what Zed showed, pass or fail, the date. Z3's hook log line is quoted. If Z3 fails, stop: the design's Zed premise failed, and the plan returns to the human partner.

- [ ] **Step 3: The Z4 contingency, in this order**

1. Edit Rounds 1-3 so that on Claude Code a fix round dispatches a fresh implementer with `run_in_background: false` (the brief path, the report path, the findings verbatim, the takeover template that already exists); move the contract needle `the stop guard treats it as live work, and your turn may end while it runs` to the new sentence (`a fix round on Claude Code dispatches a fresh foreground implementer; a SendMessage resume is for harnesses without the option`), run `bash tests/sdd/test-sdd-contract.sh` (PASSED) and `bash tests/run-offline.sh` (the accepted signature), commit `fix(sdd): fix rounds dispatch a fresh foreground implementer on Claude Code`, and record the new commit in the ledger as `treatment-z4`.
2. Create the second treatment root outside the sandbox: `git -C /Users/johnss51/Development/agents/hyperpowers worktree add --detach /Users/johnss51/.cache/hyperpowers/sdd-stop-guard/hp-treatment-z4 <treatment-z4>`; verify with `git -C <root> rev-parse HEAD`.
3. Write `manifest-z4.tsv`: the pin rows of `manifest.tsv` with `treatment` and `treatment_root` replaced, and the ten `treatment` launch rows; run `bash logs/measure-launch.sh manifest-z4.tsv` (or the launcher's dry pin check) and expect the pin to verify against the new root.
4. Before the first run, add the README section "Pre-registration addendum (Z4 contingency)" with the date, the Z4 observation, the new commit, the new root, and the statement that H1 to H4 and R apply unchanged to the ten runs under `manifest-z4.tsv`; commit `docs(evidence): pre-register the Z4 contingency runs`.
5. Repeat Task 20's steps in order with `launch-all.sh manifest-z4.tsv 5`: archive under `task-21-runs/treatment/` and post-check, adjudicate from that archive into `adjudications.tsv`, then tally it with `python3 tally.py --manifest manifest-z4.tsv --archive task-21-runs/treatment --out tally-z4.txt` from the evidence directory; record the second Results table, the experiment entry's second verdict, and the note's Zed section ("Z4 failed; contingency shipped at `<treatment-z4>`; re-measured: `tally-z4.txt`"). Commit `test(evidence): the Z4 contingency campaign` (evals) and `docs(hyperpowers): the Zed checks and the Z4 contingency` (hyperpowers).

---

### Task 22: The release candidate (or the hold)

**Risk tier:** high — version files and release notes.

**Files:**
- Modify (hyperpowers worktree): the six `vrzn.toml` locations (through `vrzn -y bump minor`), `CHANGELOG.md`, the evidence note (Release)

**Interfaces:**
- Consumes: the decision of record (`tally.txt`, or `tally-z4.txt` when Task 21's contingency ran), the note's Zed section, T1's archived record (`task-19-runs/t1/`), the suites.
- Produces: the 6.17.0 release commit, or the recorded hold.

- [ ] **Step 1: Read the gate**

All of these must hold, each recorded in the note's Release section with its reading: the decision of record says `decision: PASS`; the Zed section records Z1, Z2, Z3 pass and Z4 pass (or the contingency shipped and re-measured); `task-19-runs/t1/` holds T1's archived record with at least one `live-agent` allow; at the branch head, `bash tests/sdd/test-sdd-contract.sh` prints `STATUS: PASSED`, `bash tests/hooks/test-sdd-stop-guard.sh` prints `STATUS: PASSED`, and `bash tests/run-offline.sh` (outside the sandbox) ends with the accepted signature of Global Constraints: exactly one `FAILED:` line, naming `tests/brainstorm-server npm test`, and the closing `offline set: 1 failed` line, compared line for line (log paths aside) with the Before-Task-1 record. On any other reading: write "Release held" in the note's Release section naming the failed criterion or check and its reading, commit `docs(hyperpowers): the SDD stop guard release is held`, report DONE with "release held" so the controller skips the bump.

- [ ] **Step 2: Bump and write the notes**

`/Users/johnss51/Applications/micromamba/envs/main/bin/vrzn -y bump minor` then `vrzn get` — Expected: every location `6.17.0`. In `CHANGELOG.md`, rename `## Unreleased` to `## 6.17.0 (<date>)` and add, above the portable-dossiers bullets, the problem line "In Zed, SDD sessions looked idle while the plan was unfinished, and a controller sometimes ended its turn after announcing its next step." and three bullets: the guard in its precise form (on Claude Code, a turn that would end mid-plan with nothing tracked live is refused, and so is an immediate second attempt; a third consecutive attempt is allowed and logged; every decision for a session with a plan is logged with its reason unless the log itself cannot be written), the helpers (`sdd-state complete` and `handback`, `tracked-job`, the Finish receipt), and the foreground waits with the measured numbers from the decision of record (foreground share, F runs, untracked launches, false refusals, stops reaching the user), with the evidence pointer.

- [ ] **Step 3: Check and commit**

`bash tests/sdd/test-sdd-contract.sh` (`STATUS: PASSED`) and `bash tests/run-offline.sh` outside the sandbox (the accepted signature again, on the bumped tree). Write the note's Release section (decision, version, date). Leak scan, commit `chore: bump version to 6.17.0`.

---

## After the final review

- The final whole-branch review covers both branches; the Codex final gate runs per repository. The evals gate's range carries archives: review it from a synthetic archive-free worktree as the 2026-10-22 gate did (the companion refuses inputs over 1 MiB and the dossier's range overflows argv), and say so in the round ledger.
- Finish both branches with the finishing skill; the evals merge is a real merge, never a squash. Nothing is pushed unless the human partner asks.
- After the merge, the human partner checks out `v6.17.0` in `.worktrees/plugin-install` and reloads plugins; the after-window starts at that reflog entry (spec Design §5).
- **After-window follow-up (dated when the window opens):** the after-window runs from the `v6.17.0` reflog entry until at least 100 boundaries have accrued (check weekly with `python3 field.py` over the window, outside the sandbox). Then run both measures over the same window, `python3 field.py` and `python3 field_hook.py --since <start> --until <end>`, from `evals/evidence/2026-10-19-sdd-turn-liveness/`; apply the Field decision rule (the follow-up opens if the after rate of premature stops reaching the user is at least half the corrected baseline of 20.64 per 100, with `cap` events and the `misses` list reported beside it); record the readings in that README's Results, the experiment entry and the hyperpowers note; a follow-up that opens gets its own brainstorm, spec and plan.
- Open items this plan leaves: the five ungated backstop-fix events of the turn-liveness campaign in the evals repository and the spec-gate event `20261023T185721Z-4106-7023` in hyperpowers (the review sweep runs on request); the two campaign worktrees `hp-control` and `hp-treatment` under `~/.cache/hyperpowers/sdd-turn-liveness/`, and the new `hp-treatment` (and `hp-treatment-z4` under the contingency) under `~/.cache/hyperpowers/sdd-stop-guard/`, removable once their archives are committed; receipts accumulate under `<cache>/hyperpowers/receipts/` until `sdd-state prune --receipts --days N --apply` is run.
