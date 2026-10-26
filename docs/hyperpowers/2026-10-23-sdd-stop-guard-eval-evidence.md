# SDD Stop Guard: Eval Evidence

Date: 2026-10-23 (spec and plan).
Skill changed: `subagent-driven-development`, which gains a Stop hook (the
stop guard) that finds a session's plan by matching the Stop event's
`session_id` against `session <id>:` lines in the SDD ledger.

Spec: `docs/hyperpowers/specs/2026-10-23-sdd-stop-guard-design.md`.
Plan: `docs/hyperpowers/plans/2026-10-23-sdd-stop-guard.md`.

**Where the run artifacts live.** The probe below ran from a throwaway plugin
in the SDD workspace. Its output is quoted in this note; nothing else cites
the workspace.

## Probe

Question: does the Stop event's `session_id` equal `$CLAUDE_CODE_SESSION_ID`
as the session's own Bash tool sees it? The hook's discovery key depends on it.

Command: one headless session with an empty config dir, the probe plugin
(a Stop hook that appends `session_id` beside its own
`$CLAUDE_CODE_SESSION_ID`) and a narrow allowlist:

```
env -u CLAUDE_CODE_SESSION_ID -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT CLAUDE_CONFIG_DIR=<empty dir> \
  claude -p --plugin-dir <probe plugin> --output-format stream-json --verbose \
  --allowedTools='Bash(printenv CLAUDE_CODE_SESSION_ID)' \
  'Run exactly this shell command and reply with its output only: printenv CLAUDE_CODE_SESSION_ID'
```

The allowlist is there because the `-p` permission layer refuses a command
that contains a variable ("A variable in this command can't be checked before
it runs"), so the first attempt, which ran `printf` with
`$CLAUDE_CODE_SESSION_ID`, never produced a shell id. That attempt did show the
Stop hook firing under `-p` (hook and env ids equal) while the shell command
was refused.

Claude Code: 2.1.302. Date: 2026-10-24. This is the run of record: it ran
outside the Bash sandbox, the environment a real hook runs in. The same
command inside the sandbox gave `efa38fbc-b7dd-49ec-ba78-b8d99400143f` for all
three ids as well.

| Id | Value |
|----|-------|
| hook (`session_id` in the Stop payload) | `72cc3565-6224-4818-baa9-5be5404b7993` |
| env (`$CLAUDE_CODE_SESSION_ID` in the hook process) | `72cc3565-6224-4818-baa9-5be5404b7993` |
| shell (the Bash tool's `tool_result`) | `72cc3565-6224-4818-baa9-5be5404b7993` |

All three are equal, so the assumption holds: discovery matches
`session <session_id>:`.

## Process groups (Task 3, deviation 1)

`tracked-job run` gives the command its own process group through bash job
control and keeps the supervisor outside it; `setsid` is not used, so both
stay in the controller's session. The line below is what
`tests/sdd/test-tracked-job.sh` printed on 2026-10-25 when the controller ran
it outside the Bash sandbox (inside it, `ps` is refused and the two
process-identity cases skip): the child leads its own group, the supervisor
sits in another, and `ps -o sess=` reports 0 for both on this host (macOS
prints 0 for a process that is not a session leader).

```
child=51098 pgid=51098 sid=0 run=50973 pgid=34374 sid=0
```

Result: `STATUS: PASSED (0 skipped)`, 20 cases; inside the sandbox,
`STATUS: PASSED (2 skipped)`. That run was at 422d539. The task's fix rounds
added cases and a discriminating assertion (the child is not a session
leader: its `sess` differs from its pid, which fails under `setsid`); the run
at the task's final helper, a9a7396, printed:

```
child=48276 pgid=48276 sid=0 run=48226 pgid=32250 sid=0
```

Result: `STATUS: PASSED (0 skipped)`, 36 cases; inside the sandbox,
`STATUS: PASSED (2 skipped)`.

## The fence on macOS (Task 4, a deviation from Design 2)

The spec names `ps -E` as the reader of another process's environment where
`/proc` is absent. On this host (macOS, Darwin 25.6) it is not one: `ps -E`
prints the environment of the calling process only. Controller probes
outside the Bash sandbox on 2026-10-25, all against a direct child of the
shell with the same uid, returned the child's command line without its
environment under `ps -E -o command= -p`, `ps -eE`, `ps -axE`, with `-ww`,
and for a child started with a two-variable `env -i` environment. The first
unsandboxed run of Task 4's suite failed its lost-job sweep for that reason:
the fenced survivor and the fenceless stranger both counted as skipped.

The human partner chose to keep the sweep working here. A process now
carries a job's fence when its environment holds `TRACKED_JOB_DIR=<jobdir>`
or one of its open descriptors resolves to `<jobdir>/out.log` (every process
of the command's tree inherits stdout and stderr on that file); the readers
are `/proc` (`environ` and `fd/`) where it exists and `lsof -p PID -Fn`
otherwise, the `ps -E` reader is gone, and `can_read_fence` probes a real
child instead of the supervisor's own pid. A process that drops both halves
is fenceless and skipped; a host with neither `/proc` nor lsof degrades a
lost job to `lost-unswept`. The spec text stays as written; this note and the
decision records carry the deviation.

The suite's last unsandboxed run at Task 4's final helper, f560544, printed:

```
child=11280 pgid=11280 sid=0 run=11148 pgid=81830 sid=0
```

Result: `STATUS: PASSED (0 skipped)`, 79 cases; inside the sandbox,
`STATUS: PASSED (16 skipped)`.
