# Hyperpowers for Kimi Code

Complete guide for using Hyperpowers with [Kimi Code](https://github.com/MoonshotAI/kimi-code).

Hyperpowers is a fork of [Superpowers](https://github.com/obra/superpowers); see the [top-level README](../README.md) for the relationship to upstream.

## Installation

This fork is **not** published to Kimi Code's plugin marketplace, so the in-app `Marketplace` browser will not list it. Install it directly from the repository:

```text
/plugins install https://github.com/scott-arne/hyperpowers
```

For unreleased validation against `dev`, pin the branch explicitly:

```text
/plugins install https://github.com/scott-arne/hyperpowers/tree/dev
```

Kimi Code applies plugin changes to new sessions. After installing, updating, enabling, disabling, or reloading a plugin, start a fresh session with `/new`.

## How It Works

The Kimi plugin manifest lives at `.kimi-plugin/plugin.json`.

The manifest does three things:

1. Points Kimi Code at the existing `skills/` directory.
2. Loads `using-hyperpowers` at session start through `sessionStart.skill`.
3. Provides Kimi-specific tool mapping through `skillInstructions`.

Kimi Code reads the skills directly from this repository. There are no copied skills, symlinks, hooks, or extra runtime dependencies.

## Tool Mapping

Skills describe actions instead of hard-coding one runtime's tool names. On Kimi Code these resolve to:

- "Ask the user" / "ask clarifying questions" -> `AskUserQuestion`
- "Create a todo" / "mark complete in todo list" -> `TodoList`
- "Dispatch a subagent" -> `Agent`
- "Invoke a skill" -> Kimi Code's native `Skill` tool
- "Read a file" / "write a file" / "edit a file" -> `Read`, `Write`, `Edit`
- "Run a shell command" -> `Bash`
- "Search file contents" -> `Grep`
- "Find files by path or pattern" -> `Glob`
- "Fetch a URL" -> `FetchURL`
- "Search the web" -> `WebSearch`

## Updating

Reinstall from the repository to pick up the latest changes:

```text
/plugins install https://github.com/scott-arne/hyperpowers
```

Start a fresh session with `/new` after updating.

## Troubleshooting

### Plugin not loading

1. Run `/plugins info hyperpowers` and check diagnostics.
2. Make sure the plugin is enabled.
3. Start a fresh session with `/new` after install or update.

### Direct GitHub install used an old release

Kimi Code installs the latest GitHub release for a bare repository URL when one exists. To test unreleased changes, install the branch explicitly:

```text
/plugins install https://github.com/scott-arne/hyperpowers/tree/dev
```

### Skills not triggering

1. Confirm `/plugins info hyperpowers` shows the plugin enabled.
2. Start a fresh session with `/new`.
3. Try the acceptance prompt: `Let's make a react todo list`. A working install should load `brainstorming` before writing code.
