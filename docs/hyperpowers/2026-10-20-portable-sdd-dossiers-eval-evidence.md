# Portable SDD Dossiers — Eval Evidence

Date: 2026-10-20 (runs on the dates recorded in the artifacts)
Skills changed: using-git-worktrees, subagent-driven-development,
finishing-a-development-branch, optimizing-performance (one sentence).
Scripts added: `sdd-common.sh`, `sdd-state`, `tests/run-offline.sh`; rewritten: `sdd-dir`.

Spec: `docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md`.
Plan: `docs/hyperpowers/plans/2026-10-20-portable-sdd-dossiers.md`.

**Where the run artifacts live.** Every path below resolves under the evals
repository's committed evidence tree,
`evals/evidence/2026-10-20-portable-sdd-dossiers/` (hyperpowers-evals commit
`f291f9a0afd895f2b9a1d7046407f1d5f7c912a8`). Nothing in this note cites the SDD
workspace.

## Two-clone rehearsal (`rehearsal/`)

Four Claude Code sessions on 2026-10-22, Opus 5.5 through Vertex, each against
the plugin worktree at `e5218e9` and a cache root inside the rehearsal tree.
Four clones of two bare origins stand in for hosts; `run-rehearsal.sh` drives
them and `check-rehearsal.sh` reads the outcomes.

Pass 0 (clone P, `--permission-mode acceptEdits`, Edit and Write deliberately
left out of `--allowedTools`) answers what the spec assumes about writes under
the state checkout. The session made 55 Bash calls, 4 Read, 2 Agent, 2 Write and
1 Skill. Both Write calls addressed the state checkout
(`plans/rehearsal-0797b45f/task-1-report.md` and `global-constraints.md`), and
both came back `Claude requested permissions to write to <path>, but you haven't
granted it yet.` Those two are the only denials in the transcript. Of thirteen
Bash calls that referenced the same checkout, nine wrote to it (the `noclobber`
ledger creation, the heredoc appends, the report) and none were refused, so the
ledger still reached
`Task 1: complete (commits 3b7f456..84b5434, review clean; codex gate
incomplete, recorded ungated)`, and both denied files exist, written through
Bash instead. That is the footing the plain cache has today: Edit and Write under
the cache need the human partner's own allow rules either way, Bash appends do
not, and no ledger line depends on the tool that was denied. The session ended
normally and stopped before Task 2. (`rehearsal/hostP-accept.jsonl`;
`rehearsal/hostP-state-paths.txt` lists the 34 distinct state-checkout paths the
session touched.)

A control arm settles what pass 0 alone could not (`rehearsal/control/`,
`run-control.sh`): two sessions, one in the default permission mode and one
with `Write` allowed, each asked to Write the same file under a plain-cache
path and under a state-checkout path with no other tool. The outcomes
(`rehearsal/control/outcomes.txt`):

```
default-mode plainkey absent
default-mode statekey absent
write-allowed plainkey written
write-allowed statekey written
```

Each session made exactly one Write call per path. In `default-mode` both
came back `Claude requested permissions to write to <path>, but you haven't
granted it yet.`, one denial per path and none elsewhere; in `write-allowed`
both returned `File created successfully`, with no denial naming either path.
The two paths agree within each arm, so the state checkout asks for nothing the
plain cache does not ask for today, in the default mode as in the allowed
one; that is the spec's assumption, measured for the Write tool. The arm does
not measure Bash writes, a session carrying the operator's own allow rules
(both sessions ran with a fresh `CLAUDE_CONFIG_DIR`), or a checkout
`sdd-state` created (the state-side path is a bare `git init`); pass 0 covers
the Bash appends under the operator's rules.

Pass 1 (clone A) executed Task 1 only: the implementer committed
`d0a847b feat: first file` on `main` and the controller stopped there. Then
`sdd-state handoff docs/hyperpowers/plans/rehearsal.md --push` printed
`status=pushed sha=5f4133c code=main@d0a847b` (`rehearsal/handoff.txt`), and the
script pushed `main` to the shared origin.

Pass 2 (clone B, cloned after that push) resumed from the state branch alone.
`sdd-state sync` printed `status=created local=5f4133c remote=5f4133c age=44`
and `sdd-state verify` printed `status=ok tasks=1`. The session claimed the next
task (`status=claimed task=2`), never wrote a `task-1-brief`, committed
`fa2abc6 feat: second file`, ran the final review, and closed with
`status=finished sha=a5f5134 last=5e31003fc8c13027af9e56050b31172a694dd020
push=origin/hyperpowers/state`. Clone B's state key holds no `plans/` entry
afterwards (its transcript's `test ! -d` check printed `deleted`); the state of
clone A's and clone C's keys was not recorded.

Pass 3 (clone C, reset to the root commit so Task 1's commit is absent) stopped
where it should. `sdd-state sync` printed
`status=created local=5f4133c remote=5f4133c age=350`; `sdd-state verify`
printed `status=code-missing missing=d0a847b branch=main`. The session claimed
nothing, dispatched nothing, and asked the human partner to pull `main` before
it would continue.

One environment artifact runs through the three passes that reached a gate (P,
A and B; C stopped at `code-missing` before any gate): the Codex companion could
not create `~/.claude/plugins/data/codex-openai-codex/state/repo-*/jobs` on this
host (EPERM, sandboxed and not), so each of those passes recorded its Codex gate
as incomplete and logged the range in the ungated ledger instead of treating it
as an approval. That is the documented behaviour for a gate that cannot run, and it
left the state machinery under test untouched. The rehearsal therefore measures
nothing about the Codex gate's behaviour on the new layout; the gate directories
keyed by the common git directory are covered by the offline suites only.

`check-rehearsal.sh` output, verbatim:

```
  [PASS] A committed Task 1
  [PASS] handoff pushed the state branch
  [PASS] B ran sync
  [PASS] B ran verify
  [PASS] B did not re-dispatch Task 1
  [PASS] B committed Task 2
  [PASS] C saw code-missing
  [PASS] C did not dispatch on a stale checkout
  [INFO] pass 0: 70 lines mention permission; state-checkout paths touched: 34
  [PASS] pass 0's session ended normally
  [PASS] pass 0 wrote Task 1's completion line in host P's own ledger in acceptEdits mode
rehearsal: 0 failed
```

(The `[INFO]` line counts every transcript line containing the word
"permission", which includes the session's own mode announcements; the two real
denials are the Write calls described above.)

## Quorum scenario `sdd-plan-scoped-scratch` (`scenario-runs/`)

Run `sdd-plan-scoped-scratch-claude-auto-20261022T165919Z-9490`, coding agent
`claude-auto`, against the plugin worktree at `e5218e9`:
`final pass`, reason `Gauntlet-Agent passed; 5 post-check(s) passed`. All seven
pre-checks and all five post-checks passed (`scenario-runs/quorum-show.txt`,
`scenario-runs/sdd-plan-scoped-scratch-claude-auto-20261022T165919Z-9490/verdict.json`).

The two layout facts the run shows. Plan A's seeded ledger lives at
`scenario-runs/workspaces/sdd-plan-scoped-scratch-claude-auto-20261022T165919Z-9490/home/.cache/hyperpowers/state/01d6a2e76034ff1d5434c16e9767250a7d1194e6/plans/planA-89f00a91/progress.md`
(inside the state checkout, under `state/<key>/plans/`, in the run's own home),
and the scenario's `find ../home/.cache -name progress.md` check reaches it
there without change. Plan B's workspace `plans/planB-7af75392` existed during
the run (the Gauntlet-Agent saw the controller create and use it) and is gone
after `sdd-state finish`: the negated post-check finds no surviving plan B
ledger, while plan A's workspace is still complete beside it
(`progress.md`, `review-task-1.md`, `task-1-brief.md`).

The first attempt at this run,
`sdd-plan-scoped-scratch-claude-auto-20261022T165752Z-7003`, is an instrument
void, not a result: `setup.sh`'s
`git init` failed inside the Bash sandbox with "Operation not permitted" while
copying a hook sample. The run above is the same command with the sandbox off.
It is not archived.

## The branch question (`choice/`)

`bash tests/claude-code/test-worktree-native-preference.sh choice 3` from the
plugin worktree at `e5218e9` (`choice/run.txt`), verbatim:

```
  [PASS] CHOICE run 1: the three options in order, nothing created
  [PASS] CHOICE run 2: the three options in order, nothing created
  [PASS] CHOICE run 3: the three options in order, nothing created
CHOICE: 3 passed, 0 failed
```

Half of each check is that the session created nothing, and the phase passes no
`--allowed-tools`, so a session denied its tools would pass that half without
being able to fail it. It was not: one further session on the same invocation
(`choice/tooling-probe.jsonl`, run after the phase and not counted in the three)
made four Bash calls (`git rev-parse --git-dir --git-common-dir`,
`git rev-parse --show-superproject-working-tree`, `git branch --show-current`,
and an `ls -a` of the fixture), each returning output with no permission denial
anywhere in its transcript, and it still created no branch and no worktree. The
sessions could act on the repository and chose to ask instead.

What this phase cannot see: `claude -p` returns the session's final text, so
the check reads the options and the repository state afterwards, not the tool
calls in between. A session that attempted a branch and undid it before
answering would leave identical refs and pass. Asserting on the tool stream
needs the suite's shared `run_claude` to record `stream-json`, a change to
the test helper outside this plan; it is listed as a follow-up.

## Offline suites

`offline set: 0 failed` from `bash tests/run-offline.sh` at hyperpowers commit
`0b868bd` (Task 15; 40 shell suites plus the brainstorm-server `npm test` and
the Pi node test, one entry per `bash` call, in an unsandboxed shell with
`brainstorm-server`'s node_modules installed). The per-suite logs are copied to
`offline/`. The summary line is quoted from the controller's run log; the
archive holds the 42 entry logs, none of which records a failure.

## Release readiness

Each row resolves one of the spec's Assumptions or one check the human partner
was asked to run. A slot holds an observation or a stated reason it was not
observed, and the latter stays open until its output arrives.

### Checks on bergen

The human partner was asked on 2026-10-22 to run these four commands on bergen,
from a checkout of `portable-sdd-dossiers` inside a Claude Code session, and to
paste the output. The branch was pushed to origin for that purpose (the ref is at
`777a392`; the two later commits are documentation only). No output has arrived.
A failing suite there is a plan conflict to surface to the human partner, not a
value to guess.

| Check | Answer |
| --- | --- |
| `git --version` (spec: 2.42 or newer; the fallback is implemented and tested regardless) | not observed: awaiting the human partner's run on bergen (requested 2026-10-22; the branch is on origin at 777a392) |
| `CLAUDE_CODE_SESSION_ID` presence in a Bash call | not observed: awaiting the human partner's run on bergen (requested 2026-10-22; the branch is on origin at 777a392) |
| `bash tests/sdd/test-sdd-common.sh \| tail -n 1` on ext4 | not observed: awaiting the human partner's run on bergen (requested 2026-10-22; the branch is on origin at 777a392) |
| `bash tests/sdd/test-sdd-state.sh \| tail -n 1` on ext4 | not observed: awaiting the human partner's run on bergen (requested 2026-10-22; the branch is on origin at 777a392) |

### Remote acceptance of the branch name

| Remote | Answer |
| --- | --- |
| `git@github.com:scott-arne/hyperpowers.git` | observed 2026-10-22 from the plugin worktree: `git push --dry-run origin HEAD:refs/heads/hyperpowers/state` printed `* [new branch]      HEAD -> hyperpowers/state` with no policy rejection; nothing was pushed |
| one work repository of the human partner's choice | not observed: the repository was not yet named |

A rejection in a work repository means that repository sets
`hyperpowers.stateBranch` to a name its remote accepts, and the release note
says so.

### Session id across compaction

Observed stable. In the controller session (transcript id
`ec562ba3-23b9-4cc9-abad-014f867d8ff8`), `printf '%s' "${CLAUDE_CODE_SESSION_ID:-unset}"`
in a Bash call returned that same id in two samples taken hours apart on
2026-10-22, with several compactions and two session restarts between the
session's start on 2026-10-21 and the second sample. The claim identity
therefore survives compaction, and the SDD text's fallback (treat every claim as
foreign after compaction) was not needed on this host. The laptop is the only
host this covers; bergen's presence of the variable is the second bergen row
above.

### Permission footing

The two-clone rehearsal's pass 0 ran in `acceptEdits` mode with Write and Edit
not pre-allowed. It denied exactly two Write calls under the state checkout,
eleven Bash writes to it went through, and the ledger reached `Task 1:
complete`. The control arm (`rehearsal/control/`) showed the plain cache path and
the state checkout path behave identically in the default permission mode (both
denied) and with `Write` allowed (both written). That is measured for the Write
tool only: not Bash writes, not the operator's own allow rules, and not a
checkout that `sdd-state` created. The numbers and their limits are in the
"Two-clone rehearsal" section above.

### Open items

Eight ungated events from this plan's task gates await the final whole branch
gate, which the controller sweeps before the hand back. Release readiness is
conditional on that gate passing.

Two decisions the plan queued for the human partner are still open:

1. The fetch stamp binding: remote plus branch, or the per key boolean.
2. The import's behavior after verification: remove the source, or retain a
   backup.

### Release commands

The human partner runs these once this release is sequenced against the
`sdd-turn-liveness` plan. The version is `6.17.0` (the human partner chose it:
this plan ships first). At release time the CHANGELOG's `## Unreleased` heading
becomes `## 6.17.0 (<date>)`, with the date of the release day, before the bump.

```bash
# in the hyperpowers main checkout, after the branch is merged and the CHANGELOG heading is set to the version and date
bash scripts/bump-version.sh 6.17.0
git commit -am "chore(release): 6.17.0"
git tag v6.17.0
# install on each host: check out the tag in the plugin-install worktree, then
claude plugin update hyperpowers
```
