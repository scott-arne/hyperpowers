---
sources: skills/subagent-driven-development hooks/session-start docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md
source-digest: 70cd14a4ba1d
---
# How subagent-driven development keeps its place

This page covers the files and scripts behind {doc}`../skills/subagent-driven-development`: where a run keeps its state, what the ledger records, how briefs and review packages move work between agents, how risk tiers, model choice, and the fix-loop cap work, and how a run resumes after compaction. The loop itself is in the skill page. This page covers the mechanics that let it survive an interruption.

## The workspace

Each plan owns a workspace, a directory holding that plan's ledger, task briefs, reports, review packages, claims, and tier-skip summary. At the start of a run the controller runs two scripts from the skill's `scripts/` directory.

- {source}`skills/subagent-driven-development/scripts/sdd-state` with `sync PLAN_FILE` fetches the repository's state branch and prints a status line.
- {source}`skills/subagent-driven-development/scripts/sdd-dir` with the plan path prints the workspace path.

The workspace is inside a state checkout: a linked worktree of an orphan branch named `hyperpowers/state`, kept once per clone under `${XDG_CACHE_HOME:-~/.cache}/hyperpowers/state/<key>/plans/<plan-slug>-<hash8>/`. The key hashes the clone's common git directory, so every worktree of that clone shares the checkout, and the workspace name derives from the plan's repo-relative path, so it is the same on every host. The skill gives two reasons for the location. The cache is outside the working tree, so nothing in it can be committed with your code. It is also off Claude Code's protected paths, so writing there never triggers a permission prompt.

The ledger, reports, notes, and claims are committed to the state branch by `sdd-state snapshot PLAN_FILE`. Briefs and review packages are ignored there and regenerate. When `sdd-dir` reports `backend=plain` on stderr, the state branch is unavailable on this host, so the workspace lives in a plain cache directory and does not travel. The controller then tells you once and continues.

The design for the state branch and its hand-off between machines is in {source}`docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md`.

### Sync outcomes

`sdd-state sync` prints one status. The skill continues on `up-to-date`, `fast-forwarded`, `merged`, `ahead`, `created`, `absent`, `no-remote`, `assumed-absent`, and `plain`. It continues on the local checkout on `offline`, and appends a `state: sync offline` line to the ledger once the ledger exists. The other statuses stop the run until you answer a question or `sync` succeeds:

- `offline-no-state`, or `needs-sync` from `sdd-dir`: this host has no dossier and cannot learn whether the remote holds one. You get online, or confirm that no remote dossier exists.
- `diverged`: the controller presents both tips and the printed merge command as a question and never merges on its own.
- `busy`: one retry after the other session's writes settle, then a question.
- `foreign`: the branch at that name is not a hyperpowers state branch. The remedy is a different branch name in the git config key `hyperpowers.stateBranch`.
- `remote-finished`: another host finished a plan whose workspace here holds ledger lines the branch lacks. For this plan, you decide whether to snapshot those lines or discard them.

The controller pushes the state branch only when you ask for a hand-off to another host, through `sdd-state handoff PLAN_FILE --push`, and it never pushes on its own initiative. Before a hand-off, it relays any uncommitted plan, uncommitted code, detached head, or shallow clone it finds, with the exact commands, and does not report the run as ready to pull.

## The ledger

The ledger is `progress.md` in the workspace. Its first line records the plan's repo-relative path (`# SDD ledger — plan: <path>`), written with a no-clobber write so two sessions that both saw no ledger cannot overwrite each other. A ledger whose first line resolves to a different plan means the workspace is corrupt, and the controller stops and tells you.

The ledger is the recovery map. The skill says that after compaction the controller trusts the ledger and `git log` over its own recollection, because the commits the ledger names exist in git even when the context no longer remembers them. These are the lines it holds:

- A session line with the mode, branch, and toplevel, and a `tasks` line if you assigned this session specific tasks.
- The pre-flight scan table, one row per pair of tasks that share a file or interface and one per task.
- For each task: the implementer's agent identity, each fix round (`Task N: fix round R/5 (...)`), deferred minor findings (`Task N: minor (deferred): ...`), the task's gate directory when a Codex gate ran, and the completion line (`Task N: complete (commits <base7>..<head7>, review clean)`).
- A `Decisions listing:` line and a `Decision extractor:` line when the plan has a spec.
- Tier lines, described below.

On resume, a task with a completion line is done and is never re-dispatched. A task whose last line is a fix round resumes at the next round. A task whose last line is its implementer identity is a dispatch in flight: the controller reconciles that agent first, resumes it by its recorded id where the harness allows, and dispatches a takeover only if it cannot be recovered. The controller appends to the ledger with a quoted heredoc when another session may be live, because an edit that rewrites the file would drop a line another session appended in between.

After the pre-flight scan and after every completion line, the controller runs `sdd-state snapshot`, so a hand-off or a crash loses at most the task in flight. A snapshot outcome of `none` or `error` stops the run before the next task.

Before a task is dispatched, the controller claims it with `sdd-state claim PLAN_FILE N --session <sid>`. A claim held by another session means the controller asks you who holds it and whether to take it over, and it takes over only on your explicit yes.

## Task briefs and review packages

Two scripts keep requirements and diffs out of the controller's context by writing them to files that other agents read.

- {source}`skills/subagent-driven-development/scripts/task-brief` with `PLAN_FILE N` extracts one task's text from the plan into `task-N-brief.md` in the workspace and prints `wrote <path>: <N> lines`. The dispatch prompt points the implementer at that path as its requirements, with the exact values to use verbatim. The skill says never to make a subagent read the whole plan.
- {source}`skills/subagent-driven-development/scripts/review-package` with `PLAN_FILE BASE HEAD` writes the commit list, the stat, and the full diff with extended context to one file. The controller records `BASE` before it dispatches the implementer, and the skill says never to use `HEAD~1`, which drops all but the last commit of a multi-commit task. The script exits 3 when the range is empty or `HEAD` is not a descendant of `BASE`.

The implementer writes its full report to a file named after the brief (`task-N-report.md`) and returns only a status, commits, a one-line test summary, and concerns. The controller treats that report as a claim: it re-runs the named covering command itself, and a misreported result is a failed task. The task reviewer receives three paths (brief, report, review package) plus a file of the global constraints that bind the task. The per-task Codex gate takes that same global-constraints file.

## Risk tiers

Each plan task declares a tier (`low`, `standard`, or `high`) on a line under its heading, and the brief carries it. The tier changes one thing: whether the per-task Codex review runs. {doc}`codex-gates` covers the conditions for skipping it. Two parts live in the SDD files:

- The controller raises a tier when an escalation trigger fires and never lowers a declared tier. Each escalation or fallback is a ledger line of the form `Task N: tier declared <...> -> effective <standard|high> (<trigger>)`. A missing or unparseable tier line becomes `declared none -> effective standard (missing tier line)`.
- When any task skipped its gate, the controller writes `tier-skips.md` in the workspace, one line per skip, and hands its path to the final reviewer and the final Codex review.

A batch of small same-shape tasks sent to one subagent takes the highest tier among them, so batching low-tier tasks never creates a skip.

## Model selection

The controller names a model on every dispatch, because an omitted model inherits the session's. The rules in {source}`skills/subagent-driven-development/model-selection.md`:

| Role | Model |
|---|---|
| Implementer with the complete code in the task text, and single-file mechanical fixes | Cheapest tier |
| Implementer working from prose, and reviewers | Mid-tier model as the floor, scaled to the diff's size, complexity, and risk |
| Multi-file integration and judgment | Standard model |
| Architecture and design tasks, and the final whole-branch review | Most capable available model |
| Fix-loop rounds 4 and 5 | At least one tier above the implementer that got stuck |

The file's reason for the mid-tier floor is turn count: the cheapest models routinely take two to three times the turns on multi-step work, which can cost more overall.

## The fix loop and its cap

A task's blocking findings come from the task reviewer, from the controller's own resolution of the reviewer's "cannot verify" items, and from the per-task Codex review. They share one cap of five rounds per task. A round is one fix dispatch, or one small controller-applied fix that the skill limits to at most three lines in one file with no new logic, plus one scoped re-review.

- Rounds 1 to 3 resume the original implementer, with the open findings verbatim.
- Rounds 4 and 5 dispatch a fresh implementer on a more capable model, given the brief path, the report path, and the findings.
- The re-review covers the fix diff only. It returns ADDRESSED, NOT ADDRESSED, or DECLINED for each finding, and a decline counts only when the re-reviewer confirms its file and line evidence.
- Minor findings never enter the loop. They go to the ledger as deferred, and the final review triages them.
- A finding that conflicts with the plan's text goes to you before any fix is dispatched.

For a Codex round in this loop, the controller passes `gate-round` the number of non-gate fix rounds the task has used, and the script derives the ceiling from the cap. When round five, or a Codex round at the spent cap, still leaves blocking findings, the controller stops, ledgers `Task N: BLOCKED at cap`, and reports the open findings to you with the rounds spent and the evidence.

## Resuming after compaction

Three things bring a controller back to its place.

- The skill says Claude Code re-attaches it cut to its first 20,000 characters, which ends before the task loop, and that a full read made before the compaction does not survive it. After each compaction, the first and every later one, the controller reads the whole skill file before its next action, then the ledger.
- On Claude Code, the session-start hook adds a line when a session resumes after compaction in a repository that has a ledger. {doc}`triggering` describes it.
- The ledger's resume rules above, which tell the controller which task is done, mid-loop, or in flight.

The skill also covers a decision extractor, a background subagent that drafts notes for the decision records. The controller records its task id and output path in the ledger before any other call, because after a compaction that line is the only record of them.

## Finish

At the end the controller removes the plan's directory from the checkout with `sdd-state finish PLAN_FILE`. The branch history keeps the workspace, so an evidence note can cite it with `git show <sha>:plans/<ws>/<file>`. Nothing inside the checkout is reclaimed automatically, and `sdd-state prune --repo <dir>` lists and removes idle plan directories only when asked.
