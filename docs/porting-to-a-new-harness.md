# Porting Hyperpowers to a New Harness

This guide explains how to add support for a new harness — an IDE, CLI, or
agent runner that isn't Claude Code — so that Hyperpowers skills auto-trigger
there the same way they do natively.

It is written in two layers. **Part 1–3** explain how the system works and how
to tell whether a harness can be supported at all; read these before you touch
anything. **Part 4–8** are a prescriptive procedure for an agent (supervised by
a human partner) to execute the port end to end, through distribution. An
appendix indexes the current reference integrations so you can copy the closest
one.

The integration mechanism differs across harnesses, and it will keep changing.
This guide deliberately teaches the **invariants** — the things that must be
true no matter the mechanism — and points you at a live reference implementation
to copy. When this guide and the code disagree, the code wins; fix the guide.

## Before you start

Adding a harness is the highest-stakes contribution type in this repo. Before
writing anything:

- Read `CLAUDE.md` and `.github/PULL_REQUEST_TEMPLATE.md` in full — the
  contributor rules and the new-harness PR requirements are not optional.
- Search open **and closed** PRs for a prior attempt at this harness. If one
  exists, understand why it stalled before starting your own.

---

## Part 1 — How Hyperpowers works across harnesses

Hyperpowers is the same content everywhere. What changes per harness is the thin
layer that delivers that content to the model and translates its instructions
into the harness's native tools. Three components:

1. **Skills (harness-agnostic).** Everything in `skills/` is the source of
   truth, shared verbatim by every harness. Skills are written to describe
   *actions* — "invoke a skill", "read a file", "dispatch a subagent", "create a
   todo" — and never name a specific tool. This is what lets one skill body run
   on Claude Code, Codex, Gemini, pi, and the rest without edits.

2. **Tool mapping (per-harness).** Each harness needs the action vocabulary
   translated into its real tool names. That translation lives in
   `skills/using-hyperpowers/references/<harness>-tools.md` and/or inline in the
   harness's bootstrap injector (see Part 5). It says, e.g., "*dispatch a
   subagent* → call `task` with `subagent_type`."

3. **Bootstrap (per-harness).** At the start of every session, the full
   `skills/using-hyperpowers/SKILL.md` is injected into the model's context,
   wrapped in `<EXTREMELY_IMPORTANT>` tags, with the tool mapping appended. That
   injected skill is what teaches the model that skills exist and that it must
   check for a relevant skill before acting. **The bootstrap is the entire
   integration.** Without it, the skill files are inert — present on disk, never
   invoked.

### Two rules that make this work

**1. Skills name actions, not tools.** Do **not** edit skill bodies to fit your
harness. Porting adds a tool-mapping reference and a bootstrap injector; it
never reaches into `skills/*/SKILL.md` to swap tool names. (The project's
contributor guidelines treat skill content as carefully-tuned behavior-shaping
code; rewording it for "compliance" is rejected on sight.)

**2. Everything ships through the harness's own install mechanism. Never edit the
user's files.** The bootstrap, the skills, and the tool mapping all get delivered
*as part of what the harness installs* — a plugin, an extension, a marketplace
entry, an extension-bundled context file. A port **must not** reach into a user's
global or personal config (`~/.gemini/config/AGENTS.md`, `settings.json`,
`trustedFolders.json`, a hand-edited `~/.bashrc`, etc.) to inject anything. The
harness owns what it loads; your install artifact is the only thing you get to
write. If the install mechanism genuinely can't carry the bootstrap, that is a
limitation to surface (Part 6) — never a license to hand-edit the user's config.
(Shape C is *not* an exception: Gemini's context file is fine because it ships
*inside the installed extension* and is declared by the manifest's
`contextFileName` — the harness loads the extension's own file, not a file you
edited in the user's home.)

---

## Part 2 — Can this harness be supported?

A harness can support Hyperpowers only if it can do all of the following. Check
these before writing code — if the first one fails, stop.

### Hard requirement: automatic session-start injection

The harness must let you inject text into the model's context **at the start of
every session, with no per-session opt-in by your human partner.** This is the
one non-negotiable capability. It can take any form:

- a **hook/event system** that runs a shell command at session start and reads
  its stdout (Claude Code, Codex, Cursor, Copilot CLI), or
- an **in-process plugin/extension** with a session-start or message lifecycle
  callback that can mutate the message array (OpenCode, pi), or
- an **instructions-file** convention where the harness loads a context file that
  *your installed extension ships and declares* (e.g. Gemini's `contextFileName`
  pointing at the extension's own `GEMINI.md`) — not a file you edit in the user's
  home.

If the only way to get Hyperpowers in front of the model is for your human
partner to opt in each session (paste a prompt, run a command, enable a mode),
the harness
**cannot** be properly supported. The acceptance test in Part 3 will fail, and
the PR will be closed. This is the single most common reason a "port" isn't a
real port.

### The rest of the capability checklist

| Capability | Why it's needed | If absent |
|---|---|---|
| **Skill discovery + invocation** | The model must be able to load a skill's full content on demand | If there's no native skill tool, the sanctioned fallback is to `read` the relevant `SKILL.md` directly — see Part 5. A harness with neither a skill tool nor file-read cannot work. |
| **File read / write / edit** | Nearly every skill manipulates files | Essential. No workaround. |
| **Run shell commands** | TDD, verification, git workflows | Essential. |
| **Subagent / task dispatch** | `dispatching-parallel-agents`, `subagent-driven-development` | Degradable: if unavailable, those specific skills tell the model to do the work inline or report the missing capability — *never* to invent a `Task` call. Some harnesses gate this behind a config flag (e.g. Codex needs multi-agent enabled). |
| **Todo / task tracking** | Progress tracking in several skills | Degradable: fall back to a plan file or `TODO.md`. |
| **Web fetch / search** | A few skills | Degradable. |
| **Shell or polyglot script execution (Windows)** | Only for the shell-hook shape, only if you want Windows support | See Part 7. In-process-plugin harnesses sidestep this entirely. |

"Degradable" means: the skill already has fallback wording for the missing
tool. Your job in the tool mapping is to point at the real tool when it exists
and reuse that fallback wording when it doesn't.

### You may not need a new directory at all

Some "new harnesses" are really existing integrations under a different
installer. Factory's Droid, for example, consumes the Claude Code plugin via its
own `plugin install` command and needs no new files here. Before building,
check whether the harness can simply load an existing manifest. A port that adds
nothing to this repo but a paragraph in the README is a perfectly good outcome.

---

## Part 3 — Definition of done

A port is finished when **all** of these are true:

1. The `using-hyperpowers` bootstrap loads at session start, every session, with
   no per-session opt-in.
2. A tool mapping exists for the harness (in
   `references/<harness>-tools.md`, inline in the bootstrap, or both — per Part 5).
3. Skills can actually be invoked — natively, or via the documented
   read-`SKILL.md` fallback — and the model follows them.
4. **The acceptance test passes.** In a clean session, the user message:

   > Let's make a react todo list

   auto-triggers the `brainstorming` skill *before any code is written*. Capture
   the full transcript — the PR requires it.
5. Tests cover the integration (Part 5) and pass.
6. A real user can install it through the harness's own mechanism (not by
   hand-copying files), and the version is tracked in `.version-bump.json` where
   applicable (Part 6). Note that some installers rewrite or strip the manifest on
   install (one drops it to just `{"name": …}`), so "the *installed* files report
   the repo version" is not always achievable — track the version at the source
   manifest and don't treat a rewritten installed manifest as a failure.

A quick smoke check before the full acceptance test: start a session and ask the
model to describe its superpowers. If the bootstrap injected, it knows it has
them. (OpenCode's install doc uses `opencode run --print-logs "hello" 2>&1 |
grep -i hyperpowers` for the same goal via a different mechanism — log-grep
rather than asking the model; the `2>&1` matters because logs go to stderr. Find
your harness's equivalent.)

---

## Part 4 — Choose your integration shape

There are three structural shapes, distinguished by *how you get the bootstrap
in front of the model*. Pick the one that matches what your harness exposes,
then copy that reference implementation. The shape determines almost everything
in Part 5 — the steps below branch on it.

### How to tell which shape you have

Before routing, learn the harness's *actual* mechanism — and don't assume it's
well documented or that it behaves like whatever harness it forked from.

**Find the surface:**

- **Search the web for the harness's docs** (extension / plugin / hook / skill /
  MCP / "context file" / "rules file"). Vendor tools change fast; search rather
  than trust training knowledge.
- **Find and read an existing third-party extension/plugin for the harness.** A
  real working example beats docs — it shows the manifest shape, the install
  command, and which components the harness actually loads.
- Check what the harness loads at startup: a settings file? an extensions
  directory? a per-project or global instructions file (`AGENTS.md`, `<NAME>.md`)?

**If it's underdocumented, reverse-engineer it empirically** (a real porter has
had to do every one of these):

- `strings` the binary / grep the install tree for hook event names, config
  paths, and the instructions file it reads.
- **Ask the running model to enumerate its own tool names** — e.g. "list the
  exact machine names of every tool you can call." This is the authoritative way
  to get tool names without inventing them (see Step 4).
- Prove every assumption with a **unique-marker test**: inject a nonsense token
  through the mechanism you think works, start a fresh session, and confirm the
  token actually reached the model.

**A fork does not inherit its parent's behavior.** A harness derived from another
(e.g. a Gemini-derived CLI) may expose the parent's manifest fields and
`@`-include syntax and *still not honor them the same way*. Verify with a marker;
never assume the parent's recipe transfers.

Then route to a shape:

- Shell command at session start whose stdout is read → **Shape A**.
- Plugin/extension module with lifecycle callbacks you run code in → **Shape B**.
- Only ever an always-on instructions file, no hook and no code plugin →
  **Shape C**.

**Shapes compose — they are not mutually exclusive.** The *skill-discovery*
mechanism and the *bootstrap* mechanism need not be the same shape — but **both
must still ride the install mechanism** (rule 2). Decide the two questions
separately: *where do skills get discovered?* and *how does the bootstrap reach
the model every session?* A harness might install skills via a plugin yet need
the bootstrap delivered another install-shipped way (an extension-declared
context file, or — see below — by the harness surfacing the installed
`using-hyperpowers` skill's own description at session start). If more than one
install-mechanism surface injects automatically, prefer the most reliable. What
you may **not** do is bridge a gap by editing the user's global config.

### Shape A — Shell-hook

The harness has a hook system that runs a shell command at session start and
reads JSON from its stdout. The configured command runs `run-hook.cmd`, a
polyglot wrapper that just locates bash and dispatches the named script; the
script (`hooks/session-start`, or a harness-specific variant like
`hooks/session-start-codex`) is what reads `using-hyperpowers/SKILL.md` and
prints a JSON object whose **field name and nesting differ per harness**.

- Reference: `hooks/session-start` (and `hooks/session-start-codex`),
  `hooks/run-hook.cmd`, and the per-harness hook config `hooks/hooks.json`
  (Claude Code), `hooks/hooks-codex.json` (Codex), `hooks/hooks-cursor.json`
  (Cursor).
- Manifests: `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json` point the
  harness at `./skills/` and the right `hooks-*.json`. (Claude Code's
  `.claude-plugin/plugin.json` sets neither field — it auto-discovers `skills/`
  and `hooks/hooks.json` by convention.)

> **A hook *system* is not a session-start *event*.** A harness can have a
> `hooks.json` mechanism — and even contain the literal string `SessionStart` in
> its binary — while having no hook event that fires at session start and can
> inject context. (One real harness only exposed pre/post-tool and stop events;
> the `SessionStart` strings were telemetry.) Confirm the *specific event* you
> need exists and can write to the model's context before committing to Shape A.
> If it can't, the bootstrap belongs in an instructions file (Shape C) instead.

### Shape B — In-process plugin / extension

The harness loads a JS/TS module that exposes lifecycle callbacks. You register
the skills directory through the harness's API and inject the bootstrap by
mutating the message array in code.

- Reference: `.opencode/plugins/hyperpowers.js` (JavaScript) and
  `.pi/extensions/hyperpowers.ts` (TypeScript). pi is the closest reference for
  any harness that has **no native skill tool**.

### Shape C — Instructions-file

The harness has neither a shell hook nor a code plugin — its session-start
surface is a context file that *your installed extension ships and the manifest
declares* (e.g. Gemini's `contextFileName` → the extension's own `GEMINI.md`).
You can't run code or mutate messages; the extension's context file points at the
bootstrap. There is no injector to assemble a string or strip frontmatter — the
harness loads the referenced content as-is. **This works only because the file is
part of the installed extension** — never substitute "edit the user's global
`GEMINI.md`/`AGENTS.md`" for shipping your own (rule 2).

- Reference: `gemini-extension.json` (manifest, with `contextFileName`),
  `GEMINI.md` (two `@`-includes — the bootstrap skill and the tool-mapping
  reference), `skills/using-hyperpowers/references/gemini-tools.md`.
- Note: `@`-include is a Gemini feature. If your harness loads an instructions
  file but has no include syntax, you must inline the bootstrap content into the
  file instead.
- **Don't trust that an `@`-include is actually expanded — prove it.** A
  Gemini-*derived* harness can accept `@./path` syntax yet treat it as a *hint
  the model may choose to read* (it emits a file-read tool call) rather than a
  guaranteed inline expansion. That's the difference between the bootstrap being
  reliably present every session and the model maybe-reading it. Run a
  unique-marker test: if the marker isn't in context *without* a tool call,
  **inline the content** rather than `@`-include it.

### Routing table

| If the harness… | Use shape | Copy from |
|---|---|---|
| runs a shell command at session start and reads its stdout | A (shell-hook) | Codex (`hooks/session-start-codex` + `hooks/hooks-codex.json` + `.codex-plugin/`) |
| is a JS/TS plugin host with session/message lifecycle callbacks | B (in-process) | OpenCode (`.opencode/`) — or pi (`.pi/`) if it has no native skill tool |
| ships an extension-declared context file it always loads | C (instructions-file) | Gemini (`gemini-extension.json` + `GEMINI.md` + `references/gemini-tools.md`) |
| has a plugin install command and a manifest `contextFileName` (or equivalent) the installer keeps | C via the plugin installer | Antigravity (`.antigravity-plugin/` — `agy plugin install` ships a generated context file; verify the installer preserves it — Part 6) |

Most real harnesses fit one row cleanly; the last is the hybrid case (rule 2 still
holds — the bootstrap rides the install mechanism, never a user-config edit).

---

## Part 5 — The porting procedure

### Step 1 — Study the closest reference implementation

Open the files named in Part 4 for your shape and read them end to end. The
patterns below are summaries; the code is the spec.

### Step 2 — Create the manifest / entry point

Create whatever the harness uses to recognize the plugin. Match the existing
ones in spirit:

- **Shape A:** a `*-plugin/plugin.json` (see `.codex-plugin/plugin.json`) with
  `name`, `version`, `description`, author/license/keywords, `"skills":
  "./skills/"`, and `"hooks": "./hooks/hooks-<harness>.json"`. Plus the
  `hooks-<harness>.json` itself, registering a session-start hook whose command
  invokes `run-hook.cmd`.
- **Shape B:** the module the harness loads (e.g. `.<harness>/plugins/*.js`) plus
  whatever package metadata it needs to be discovered. The committed package
  metadata is the **repo-root `package.json`**: `main` points at the OpenCode
  plugin, the `pi` field (`pi.extensions`, `pi.skills`) plus the `pi-package`
  keyword declare the pi extension. Per-harness local manifests and lockfiles are
  kept out of git — `.opencode/.gitignore` excludes `node_modules`,
  `package.json`, and lockfiles. Do the same for your harness's *local* install
  artifacts so they don't pollute the repo — but never gitignore the repo-root
  `package.json`, which is the tracked source of truth.
  - **Build/dependency check.** Decide how the harness loads your module:
    does it run the source directly (pi's `.ts` is referenced as-is from
    `package.json`; OpenCode ships plain `.js`), or does it need a transpile/build
    step? Hyperpowers is zero-runtime-dependency. pi's `import type
    { ExtensionAPI }` works specifically because the harness runs the `.ts`
    directly, supplies that type at load, and the repo never type-checks the file
    in CI — the import isn't even declared as a dependency. If *your* harness
    actually type-checks or bundles the plugin, that breaks: an undeclared type
    import fails, and the PR rules only carve out *runtime* deps for new
    harnesses, not dev/type packages. If you hit this, confirm the approach with
    the maintainer rather than quietly adding a dependency. Keep any build output
    out of git and document the command.
- **Shape C (instructions-file):** a small manifest (see `gemini-extension.json`:
  `name`, `description`, `version`, `contextFileName`) plus the context file
  itself (`GEMINI.md` is just two `@`-includes: the bootstrap skill and the
  tool-mapping reference). The Gemini manifest has no `skills` field — Gemini
  auto-discovers the `skills/` directory bundled in the installed extension. If
  your harness has a native skill tool but no manifest field to register the
  directory, you must find its discovery convention (read its extension docs),
  then verify empirically: after wiring, ask the model to list its available
  skills — if the bundled skills don't appear, discovery isn't working yet.

### Step 3 — Wire the bootstrap injection

This is the heart of the port. The shared goal: at session start, get the
`using-hyperpowers` skill content (wrapped in `<EXTREMELY_IMPORTANT>` tags) plus
the harness's tool mapping in front of the model, with a note that the skill is
already active so the model doesn't try to load it again. *How* you do that —
and what you assemble vs. what the harness loads raw — depends entirely on your
shape. Do **not** apply one shape's recipe to another.

**Shape A — a script reads `SKILL.md` and prints the harness's JSON.** The
dispatched script (`hooks/session-start`) `cat`s the whole `SKILL.md` (frontmatter
included — that's fine; it's emitted verbatim), wraps it with the "You have
superpowers… for all other skills use the Skill tool" preamble, escapes it, and
prints the harness's JSON shape. The tool mapping for Shape A does **not** go
inline here — it lives in `references/<harness>-tools.md` (Step 4). Get the JSON
output shape exactly right. `hooks/session-start`
detects the harness from environment variables and prints *one of three* shapes:

- Cursor (`CURSOR_PLUGIN_ROOT` set): `{ "additional_context": "…" }`
- Claude Code (`CLAUDE_PLUGIN_ROOT` set, `COPILOT_CLI` unset):
  `{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "…" } }`
- Copilot CLI / SDK standard (else): `{ "additionalContext": "…" }`

This is a trap. Emitting the wrong field, or an extra one, means the bootstrap
either never injects or injects twice (Claude Code reads both
`additional_context` and `hookSpecificOutput` without de-duplicating, so emitting
both double-injects). Find the
exact field, nesting, and event-matcher values your harness expects. Then
decide: add a fourth branch to `hooks/session-start`, or — if the harness needs
a different bootstrap message or env contract — add a dedicated
`hooks/session-start-<harness>` script, the way Codex did. If you add a branch
and your harness *also* sets an env var an earlier branch keys on (some harnesses
set `CLAUDE_PLUGIN_ROOT` too), order your branch before the one that would
otherwise shadow it. Match the harness's
own event-matcher strings (Claude Code uses `startup|clear|compact`, Codex
`startup|resume|clear`, Cursor `sessionStart`); wrong matchers mean the hook
silently never fires.

The **hook-config schema itself varies per harness** — don't assume the
Claude/Codex shape is universal. Compare `hooks/hooks.json`,
`hooks/hooks-codex.json`, and `hooks/hooks-cursor.json`: Cursor's uses
`"version": 1`, a lowercase `sessionStart` key, a relative
`./hooks/run-hook.cmd` command, and omits the `matcher`/`type`/`async` fields the
others use. Match your `hooks-<harness>.json` to whichever existing file is
closest, not to a single canonical template.

The hook **command string references a harness-provided plugin-root variable**,
and its name differs per harness: `hooks.json` uses `${CLAUDE_PLUGIN_ROOT}`,
`hooks-codex.json` uses `${PLUGIN_ROOT}`, Cursor uses a relative path. Use
whatever your harness exports. (The `session-start` script re-derives the root
itself via `dirname`, so the script body doesn't depend on this — but the
command in the manifest does.)

**Discovering the harness's contract.** The three facts above — env var, JSON
field/nesting, matcher strings — are the harness's contract, not Hyperpowers',
so you have to source them. Read the harness's hook docs, or find out
empirically: register a throwaway session-start hook that dumps its environment
and emits a marker, then observe which env var identifies the harness and
whether/how the harness ingests your stdout. Pin these down before writing the
real branch.

**Shape B — assemble the string in code, then inject as a user message.** Here
you build the bootstrap yourself: read `SKILL.md`, strip its YAML frontmatter,
and assemble `<EXTREMELY_IMPORTANT>` + a short preamble that the skill is already
loaded and must not be re-invoked + the stripped body + the inline tool mapping +
`</EXTREMELY_IMPORTANT>`. One subtlety the references disagree on: OpenCode's
preamble says "do NOT use the skill tool…" (assumes a `skill` tool exists), while
pi's just says "do not try to load using-hyperpowers again." If your harness has
no skill tool, use pi's wording, not OpenCode's.

Inject the result as a **user-role message, not a system message** — system
messages bloat tokens when repeated every turn (#750) and multiple system
messages break some models (#894). Three things you must replicate:

- **Dedup guard.** The lifecycle callback can fire repeatedly (OpenCode's
  transform runs on *every* agent step; pi's `context` fires per turn). Before
  injecting, check whether a bootstrap marker is already present and skip if so.
  (The references pick different markers — pi a custom string, OpenCode the
  `EXTREMELY_IMPORTANT` tag; matching the tag is more robust since it needs no
  harness-specific constant.) Cache the bootstrap content at module level so
  you're not re-reading and re-parsing `SKILL.md` on every call (#1202).
- **Compaction.** If the harness compacts/summarizes history, re-inject
  afterward. pi sets an `injectBootstrap` flag on `session_start` and
  `session_compact`, clears it on `agent_end`, and inserts the message *after*
  any leading compaction-summary messages. OpenCode relies on its per-step
  re-injection plus the dedup guard.
- **Message-object shape is per-harness — discover yours, don't copy a literal.**
  The two references use *incompatible* shapes: pi builds
  `{ role, content: [{ type, text }], timestamp }`; OpenCode manipulates
  `message.info.role` and `message.parts[]`. Find your harness's message shape
  from its API; copying a reference's object literal verbatim will fail silently.

**Shape C — point your extension's context file at the bootstrap; assemble
nothing.** There is no injector, so you do *not* strip frontmatter or build a
wrapped string. The context file your extension ships (declared by the manifest —
*not* the user's own global file) pulls in two things: the `using-hyperpowers`
skill and the harness's tool-mapping reference. `GEMINI.md`
does this with two `@`-includes (`@./skills/using-hyperpowers/SKILL.md` and
`@./skills/using-hyperpowers/references/<harness>-tools.md`); the harness loads
them raw, frontmatter and all, and `SKILL.md` already carries its own
`<EXTREMELY-IMPORTANT>` block internally. If your harness has no include syntax,
inline the content into the instructions file instead. Gemini ships **no**
"already loaded, don't re-invoke" preamble — for an `@`-include harness the
content is the active instruction set, not a skill the model would re-load. If
you find your harness does try to re-invoke, add that note as a literal line in
the instructions file (you have no code to add it any other way).

### Step 4 — Write the tool mapping

Translate the action vocabulary into the harness's real tools. Cover every one
of these actions (omit only what genuinely doesn't apply):

- read a file
- create / edit / delete a file (one `apply_patch`-style tool, or separate
  write/edit?)
- run a shell command
- search file contents / find files by name (grep, glob)
- fetch a URL / web search
- **dispatch a subagent**, including how to pass the agent type — and any config
  flag needed to enable it
- **create / update todos** (treat older `TodoWrite` references as this action)
- **invoke a skill** — see Step 5

**Get the real tool names from the harness; never invent them.** If the docs
don't list them, the authoritative source is the harness itself: in a live
session, ask the model to "list the exact machine names of every tool you can
call, one per line" and use what it reports.

**How the harness finds the `skills/` directory is itself per-harness** — confirm
it, don't assume. Possibilities: a manifest `skills` path field (Codex's
`"skills": "./skills/"`); a *co-located* `skills/` the harness auto-scans (where a
path field is **ignored** — one real harness only scanned a `skills/` sitting next
to `plugin.json`); an API/registration call (OpenCode, pi); or you stage an
install dir that pairs the manifest with a **symlink to the repo's `skills/`** and
point the installer at the staging dir (verify the installer *dereferences* the
symlink and copies the real files — confirm with `agy plugin validate`/`install`
or the equivalent before relying on it). A `skills` path field is *not* portable.

Where the mapping lives depends on shape:

- **Shape A:** put it in `skills/using-hyperpowers/references/<harness>-tools.md`.
  The agent reaches it from the bootstrap — `SKILL.md`'s "Platform Adaptation"
  section links the per-harness references files. (Shape A harnesses have no
  instructions file; the mapping is *not* inlined into the hook output.)
- **Shape B:** the mapping is typically inlined into the bootstrap string you
  inject (see the `toolMapping` constant in `hyperpowers.js`). pi keeps it in
  *both* places — `piToolMapping()` inline **and** `references/pi-tools.md`. If
  you maintain it in two places, update both, or the port is half-done.
- **Shape C:** put it in `references/<harness>-tools.md` and pull it into the
  always-loaded instructions file (e.g. `GEMINI.md` `@`-includes
  `gemini-tools.md`).

You may also add a one-line pointer to your harness in `SKILL.md`'s "Platform
Adaptation" section so an agent reading the bootstrap knows where its mapping
lives. This is the one edit to a `SKILL.md` a port may make — and only because
that section is a pointer list, not behavior-shaping content. It does not violate
the "don't edit skill bodies" rule (Part 1); do not touch anything else in any
skill. (The list is a convenience pointer, not an exhaustive registry — not every
harness is listed.)

### Step 5 — Handle a harness with no native skill tool

`using-hyperpowers/SKILL.md` tells the model to *never read skill files manually
with file tools — always use your platform's skill-loading mechanism.* The point
is "don't bypass the mechanism," not "never use file-read." What counts as "your
platform's mechanism" depends on the harness — and for a harness with no skill
tool, the documented mechanism *is* reading `SKILL.md`. So r