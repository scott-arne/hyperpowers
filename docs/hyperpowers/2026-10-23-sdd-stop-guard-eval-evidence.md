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
