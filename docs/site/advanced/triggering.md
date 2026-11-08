---
sources: skills/using-hyperpowers hooks .opencode/plugins .pi/extensions .kimi-plugin/plugin.json skills/writing-skills/SKILL.md .cursor-plugin/plugin.json .codex-plugin/plugin.json scripts/claude-skill-root.md skills/subagent-driven-development/SKILL.md README.md tests/antigravity/test-antigravity-tools.sh RELEASE-NOTES.md docs/porting-to-a-new-harness.md docs/README.kimi.md
source-digest: ea644eb8a7ed
---
# How skills trigger

Skills fire because the `using-hyperpowers` bootstrap is in the agent's context and tells it to check for a skill before it responds. This page covers how each harness puts that bootstrap in place, what the bootstrap and each skill's description decide, and what happens after compaction. The skill itself is described in {doc}`../skills/using-hyperpowers`.

## How the bootstrap gets into a session

Each harness uses its own mechanism. The session-start hooks, the OpenCode plugin, and the Pi extension read {source}`skills/using-hyperpowers/SKILL.md`. The Claude Desktop and claude.ai bundle uses a router document instead, and {source}`docs/README.kimi.md` says the Kimi manifest loads the skill at session start through `sessionStart.skill`, though no code here shows the mechanism.

**Claude Code.** {source}`hooks/hooks.json` registers a `SessionStart` hook that runs `hooks/run-hook.cmd session-start` for the sources `startup`, `clear`, and `compact`. {source}`hooks/session-start` wraps the skill text in an `<EXTREMELY_IMPORTANT>` block that begins "You have superpowers" and returns it as `hookSpecificOutput.additionalContext`. The same file also registers a `Stop` hook, the SDD stop guard, which plays no part in the bootstrap; {doc}`sdd-internals` covers it.

**Codex.** {source}`hooks/hooks-codex.json` registers the same three sources and runs {source}`hooks/session-start-codex`, which injects the same skill text with a different wrapper sentence about loading other skills. It adds none of the one-line notices described below. {source}`.codex-plugin/plugin.json` points at that hooks file.

**Cursor.** {source}`.cursor-plugin/plugin.json` points at {source}`hooks/hooks-cursor.json`, which sets only `sessionStart`, to `hooks/run-hook.cmd session-start`. The hook detects Cursor from the `CURSOR_PLUGIN_ROOT` variable and returns the text as `additional_context`.

**OpenCode.** {source}`.opencode/plugins/hyperpowers.js` adds the skills directory to OpenCode's configuration and uses the `experimental.chat.messages.transform` hook to put the bootstrap, followed by an OpenCode tool mapping, in front of the first user message. It skips the insertion when that message already contains the bootstrap.

**Pi.** {source}`.pi/extensions/hyperpowers.ts` registers the skills directory and sets a flag on `session_start` and on `session_compact`. While the flag is set, it inserts the bootstrap, followed by a Pi tool mapping, as a user message in the `context` event, after any compaction summary at the start of the messages. It clears the flag at `agent_end`.

**Kimi.** {source}`.kimi-plugin/plugin.json` declares `sessionStart.skill` as `using-hyperpowers`, along with a `skillInstructions` text that maps skill actions to Kimi Code's tools. The {source}`docs/README.kimi.md` says the manifest loads `using-hyperpowers` at session start through `sessionStart.skill`. The manifest holds no code, and no code here shows how Kimi acts on the declaration. The manifest also carries the plugin version, so every release changes a file this page lists and flags the page for a re-read.

**Antigravity.** The {source}`README.md` says Antigravity runs the plugin's session-start hook, so the skills are active from the first message. The header comment of {source}`tests/antigravity/test-antigravity-tools.sh` says `agy` installs the existing plugin from the repository, loads the bundled skills, and runs the `SessionStart` hook, with no Antigravity-specific scaffold.

**GitHub Copilot CLI.** The upstream release notes in {source}`RELEASE-NOTES.md` say that Copilot CLI v1.0.11 added `additionalContext` support in `sessionStart` hook output, that `hooks/session-start` detects the `COPILOT_CLI` variable and emits the top-level `additionalContext` form, and that this gives Copilot CLI users the bootstrap at session start. {source}`docs/porting-to-a-new-harness.md` lists Copilot CLI among the harnesses whose hook system runs a shell command at session start and reads its output. No hooks file in the repository names Copilot CLI, so the repository does not say which configuration Copilot CLI reads.

**Factory Droid.** No file here describes how Factory Droid loads the bootstrap.

**Claude Desktop and claude.ai.** {source}`scripts/claude-skill-root.md` is the router document for the bundled package. It lists the bundled skills with their descriptions and says that `using-hyperpowers` is the router document itself in that environment.

An edit to `SKILL.md` reaches the session-start hooks the next time they run. The OpenCode plugin and the Pi extension each keep the text in a module-level cache after their first read, so an edit reaches them only once that cache is rebuilt.

## Notices from the session-start hook

After the skill text, `hooks/session-start` can append one-line notices. Each appears only when it applies:

- A count of ungated review items pending in the repository, with the phrase that clears them ("run the review sweep").
- A line saying the marketplace has a newer plugin version than the one the session loaded.
- On a start whose source is `compact`, inside a git repository that has a subagent-driven-development ledger, a line that names the newest ledger, says it records which tasks are complete, tells the agent to read it and `git log` before dispatching anything, and tells the agent to treat task instructions in the compaction summary as stale by default.

A comment in the script states a ceiling of 1200 characters of injected context beyond the skill body when all notices fire.

## What decides whether a skill fires

The bootstrap states the rule: if there is even a 1% chance a skill applies, the agent invokes it before any response or action, including clarifying questions. If the skill then turns out wrong for the situation, the agent does not have to use it. It also says to invoke the brainstorming skill before entering plan mode when the agent has not brainstormed yet.

Each skill also has a `description` in its front matter. {source}`skills/writing-skills/SKILL.md` says the agent reads the descriptions to decide which skills to load, and sets the rule for writing one: the description states only the triggering conditions ("Use when ...") and never summarizes the skill's workflow. Its stated reason is a test in which a description that summarized the workflow led an agent to follow the summary and skip the skill's body. This is why the descriptions on the skill pages read as conditions, such as "Use when executing implementation plans with independent tasks in the current session".

## Priority

The bootstrap orders skills when several apply. Process skills go first because they set the approach, and implementation skills carry it out. A build request goes to {doc}`../skills/brainstorming` first, a bug report to {doc}`../skills/systematic-debugging` first, and any writing for you (a summary, a finding, a design, a plan, a recommendation, or a reply longer than a few sentences) to {doc}`../skills/communication` before the agent writes it.

Your own instructions come before all of it. The bootstrap says that instructions in CLAUDE.md, AGENTS.md, GEMINI.md, and direct requests take precedence over skills, and that the agent skips a skill workflow only when you have explicitly said to. A subagent dispatched to execute a specific task ignores the bootstrap, because the skill opens with a block that says so.

## After compaction

What each mechanism does when the context is compacted:

- Claude Code and Codex: the hooks files match `compact`, so the bootstrap is injected again. On Claude Code, `hooks/session-start` can follow the bootstrap with the compaction notice described above.
- Pi: the `session_compact` handler sets the flag again, so the bootstrap is inserted again at the next `context` event.
- Cursor: the configuration sets only `sessionStart`, so no file here re-injects the bootstrap at compaction.
- OpenCode: the transform runs on each agent step and inserts the bootstrap into the first user message when it is absent. No file there mentions compaction.
- Kimi: the manifest declares a session-start skill and nothing else. No code here shows re-injection after compaction.
- Antigravity and Copilot CLI: no file here says whether the hook runs again at compaction.

The subagent-driven-development skill separately tells the controller to re-read the skill after each compaction. {doc}`sdd-internals` covers that instruction.
