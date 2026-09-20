# Testing Hyperpowers

Hyperpowers has two distinct kinds of tests, in two different repositories:

- **`tests/`** — does the plugin's non-LLM code work? Bash, node, and python
  tests over the hooks, the gate scripts, the SDD helpers, and each harness
  integration. These live here and run offline.
- **`evals/`** — do agents behave correctly in real LLM sessions? Quorum drives
  real agent CLI sessions of Claude Code and Codex and judges skill compliance
  with an LLM verifier. This is a **separate clone** of
  [hyperpowers-evals](https://github.com/scott-arne/hyperpowers-evals/), not a
  submodule, and it is gitignored here. Scenario and harness work gets
  committed in that repo, never in this one.

## Plugin tests

Most suites are standalone bash scripts; two directories are not. There is no
aggregate runner and no CI; run the suites that cover what you changed, one
script per `bash` invocation.

| Directory | Covers | Runner |
|---|---|---|
| `tests/hooks/` | session-start context injection, the ungated notice, the Codex broker janitor, the first-edit interlock (decision table, lazy wave resolution, atomic publication, mutation vectors, pruning), the hooks heredoc fence | each `test-*.sh`, one per `bash` call |
| `tests/codex-review-gate/` | gate scripts (`verdict-normalize`, `gate-round`, `gate-telemetry`, `ungated-ledger`, preflight, broker health), gate topology, and the gate-split losslessness proof | each `test-*.sh`, one per `bash` call |
| `tests/sdd/` | the subagent-driven-development contract | `bash tests/sdd/test-sdd-contract.sh` |
| `tests/skills/` | prose contracts for behavior-shaping skill wording with no other test: the parallel-dispatch collection contract, the writing-skills pruning rules | `bash tests/skills/test-skill-contract.sh` |
| `tests/claude-code/` | offline: SDD scratch-dir derivation, helper stdout and range guards, delivery resolution, worktree path policy; live: skill tests that spawn the real `claude` CLI | offline: `test-sdd-dir-path.sh`, `test-codex-review-dir-path.sh`, `test-delivery-resolution.sh`, `test-worktree-path-policy.sh`, one per `bash` call; live: `run-skill-tests.sh` (covers `test-subagent-driven-development.sh`; `--integration` adds `test-subagent-driven-development-integration.sh`), plus `test-worktree-native-preference.sh` |
| `tests/packaging/` | manifest wiring, the orphaned-skill-file guard, skill frontmatter, and the frontmatter rejection fixtures that prove the validator still rejects | each `test-*.sh`, one per `bash` call |
| `tests/brainstorm-server/` | the brainstorm server: JavaScript unit tests plus the start/stop and Windows-lifecycle shell tests | `cd tests/brainstorm-server && npm test`; `bash tests/brainstorm-server/windows-lifecycle.test.sh` |
| `tests/pi/` | the Pi extension | `node tests/pi/test-pi-extension.mjs` |
| `tests/opencode/`, `tests/kimi/`, `tests/antigravity/` | per-harness plugin loading, bootstrap caching, tool registration | each directory's `run-tests.sh` (default set); OpenCode's `test-tools.sh` and `test-priority.sh` are integration suites, run only with `run-tests.sh --integration` and an installed OpenCode |
| `tests/writing-skills/`, `tests/systematic-debugging/` | skill-specific structural checks | each `test-*.sh`, one per `bash` call |
| `tests/explicit-skill-requests/` | Haiku-specific, multi-turn, and skill-name-prompted behavior (live) | `tests/explicit-skill-requests/run-all.sh` |
| `tests/shell-lint/` | shellcheck over the repo's shell scripts | `bash tests/shell-lint/test-lint-shell.sh` |

Run one suite directly:

```bash
bash tests/codex-review-gate/test-verdict-normalize.sh
```

Run a directory's worth and fail if any suite fails. A loop that only echoes on
failure exits 0 and reads as green, and `bash tests/hooks/test-*.sh` runs only
the first file:

```bash
fails=0
for t in tests/hooks/test-*.sh; do bash "$t" || { echo "FAILED: $t"; fails=$((fails + 1)); }; done
[ "$fails" -eq 0 ]
```

The offline set is every `test-*.sh` outside `tests/claude-code/` and
`tests/explicit-skill-requests/` (excluding `tests/opencode/test-tools.sh` and
`tests/opencode/test-priority.sh`), the four offline `tests/claude-code/` suites
named in the table, `npm test` in `tests/brainstorm-server/`, the
`windows-lifecycle.test.sh` test, and the Pi Node file. The live suites spawn
the real `claude` CLI: they need credentials, take minutes, and are not part of
any automated run.

## Skill behavior evals

Quorum is the harness. Scenarios live at `evals/scenarios/<name>/` as a
`setup.sh`, a `checks.sh` with `pre()` and `post()` functions, and a
`story.md`. See `evals/README.md` for setup.

Live eval runs are trusted-maintainer operations: they consume real API
credit and run agents in dangerous mode. Never add live evals, API keys, or
dangerous-mode launches to public CI.

Evals are slow — minutes to tens of minutes each — and run real LLM sessions.
They are the required evidence for any change to behavior-shaping skill prose;
see "Skill Changes Require Evaluation" in `CLAUDE.md`.
