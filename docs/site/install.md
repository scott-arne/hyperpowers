# Install

Hyperpowers is distributed from its GitHub repository, [`scott-arne/hyperpowers`](https://github.com/scott-arne/hyperpowers). It is not published to any official plugin marketplace. Install it separately for each harness you use. The commands below come from the {source}`README.md`, which has the full detail.

## Claude Code

```bash
/plugin marketplace add scott-arne/hyperpowers
/plugin install hyperpowers@hyperpowers
```

The Codex review gates are optional and need [codex-plugin-cc](https://github.com/openai/codex-plugin-cc). Without it the skills work and skip the Codex review, with a one-line notice. To enable it, install the plugin, reload plugins, and run `/codex:setup`. It requires Node 18.18 or later and the Codex CLI with ChatGPT or OpenAI API authentication. The README has the exact commands.

## Codex

The fork is not in OpenAI's Codex plugin marketplace. The repository ships a Codex manifest (`.codex-plugin/plugin.json`) and Codex session hooks. Clone the repository and load it as a local plugin checkout.

## Cursor

The fork is not on Cursor's marketplace. The repository ships a Cursor manifest (`.cursor-plugin/plugin.json`) and `hooks/hooks-cursor.json`. Point Cursor at a local checkout.

## Antigravity

```bash
agy plugin install https://github.com/scott-arne/hyperpowers
```

## Factory Droid

```bash
droid plugin marketplace add https://github.com/scott-arne/hyperpowers
droid plugin install hyperpowers@hyperpowers
```

## GitHub Copilot CLI

```bash
copilot plugin marketplace add scott-arne/hyperpowers
copilot plugin install hyperpowers@hyperpowers
```

## Kimi Code

```text
/plugins install https://github.com/scott-arne/hyperpowers
```

Start a new session with `/new` afterward. Details are in {source}`docs/README.kimi.md`.

## OpenCode

Add the package spec to the `plugin` array in your `opencode.json`, then restart OpenCode:

```json
{
  "plugin": ["hyperpowers@git+https://github.com/scott-arne/hyperpowers.git"]
}
```

Details are in {source}`docs/README.opencode.md`.

## Pi

```bash
pi install git:github.com/scott-arne/hyperpowers
```

## Claude Desktop and claude.ai

Build an uploadable skill bundle from a checkout:

```bash
bash scripts/package-claude-skill.sh
```

The zip is written to `dist/`. Upload it in Settings, under Customize, then Skills. Code execution must be enabled.

## What each harness gets

The bootstrap column says how the repository's files load the `using-hyperpowers` bootstrap at session start. "Not stated" means no file in the repository says how that harness loads it. The Codex gates column follows {source}`skills/requesting-code-review/codex-review-gate.md`, which runs the gates under Claude Code only and skips them silently in every other harness. In the Claude Desktop bundle, the router tells the agent to print a one-time notice in place of a gate.

| Harness | Install method | Session-start bootstrap | Codex review gates |
|---|---|---|---|
| Claude Code | Marketplace commands | `SessionStart` hook in {source}`hooks/hooks.json` | Yes, with codex-plugin-cc installed |
| Codex | Local plugin checkout | `SessionStart` hook in {source}`hooks/hooks-codex.json` | Skipped |
| Cursor | Local plugin checkout | `sessionStart` hook in {source}`hooks/hooks-cursor.json` | Skipped |
| Antigravity | `agy plugin install` | The README says the plugin's session-start hook runs | Skipped |
| Factory Droid | Marketplace commands | Not stated | Skipped |
| GitHub Copilot CLI | Marketplace commands | Not stated. {source}`hooks/session-start` formats its output for Copilot CLI, but no file here registers its events | Skipped |
| Kimi Code | `/plugins install` | The manifest's `sessionStart.skill` loads `using-hyperpowers` | Skipped |
| OpenCode | `opencode.json` package spec | {source}`.opencode/plugins/hyperpowers.js` injects it through a message transform | Skipped |
| Pi | `pi install` | A Pi extension injects it at session start and after compaction | Skipped |
| Claude Desktop, claude.ai | Uploaded skill bundle | No hook. A router `SKILL.md` stands in for `using-hyperpowers` | Not run. The router prints a one-time notice |

Skills trigger automatically only when the bootstrap loads at session start, as {source}`CLAUDE.md` describes under New Harness Support. For the harnesses marked "Not stated", no file here shows the bootstrap loading, so this site cannot confirm that skills trigger automatically there.

Next, read {doc}`first-session`.
