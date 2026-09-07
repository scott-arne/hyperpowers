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

Every suite is a standalone bash script. There is no aggregate runner and no
CI; run the suites that cover what you changed.

| Directory | Covers |
|---|---|
| `tests/hooks/` | session-start context injection, the ungated notice, the Codex broker janitor, the hooks heredoc fence |
| `tests/codex-review-gate/` | gate scripts (`verdict-normalize`, `gate-round`, `gate-telemetry`, `ungated-ledger`, preflight, broker health), gate topology, and the gate-split losslessness proof |
| `tests/sdd/` | the subagent-driven-development contract |
| `tests/claude-code/` | SDD scratch-dir derivation and helper behavior, plus Claude Code skill tests and token analysis |
| `tests/packaging/` | manifest wiring and the orphaned-skill-file guard |
| `tests/brainstorm-server/` | the brainstorm server JS |
| `tests/opencode/`, `tests/kimi/`, `tests/pi/`, `tests/antigravity/` | per-harness plugin loading, bootstrap caching, tool registration |
| `tests/writing-skills/`, `tests/systematic-debugging/` | skill-specific structural checks |
| `tests/explicit-skill-requests/` | Haiku-specific, multi-turn, and skill-name-prompted behavior |
| `tests/shell-lint/` | shellcheck over the repo's shell scripts |

Run one suite directly:

```bash
bash tests/codex-review-gate/test-verdict-normalize.sh
```

Run a directory's worth:

```bash
for t in tests/hooks/test-*.sh; do bash "$t" || echo "FAILED: $t"; done
```

Some directories ship a `run-tests.sh` or `run-all.sh`; prefer it when present.

The suites under `tests/claude-code/` and `tests/explicit-skill-requests/`
spawn the real `claude` CLI. They need credentials, take minutes, and are not
part of any automated run.

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
