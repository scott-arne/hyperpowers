# Hyperpowers

Hyperpowers is a fork of [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent and [Prime Radiant](https://primeradiant.com), maintained at [`scott-arne/hyperpowers`](https://github.com/scott-arne/hyperpowers). It is renamed so the package, its plugin manifests, and its skill namespace are distinct from upstream, allowing local customization of the skills and prompts without colliding with an installed copy of Superpowers.

Like the original, it is a complete software development methodology for your coding agents, built on a set of composable skills plus some initial instructions that make sure your agent uses them.

> **Relationship to upstream.** This is a personal fork for customization. The skill *design*, methodology, and most prose are the work of the upstream Superpowers project; credit for the approach belongs there. The capability the agent is told it has is still called "superpowers" in agent-facing prompts on purpose — only the package, configuration, and skill-invocation namespace are renamed to `hyperpowers`.

> **Attribution policy.** Package `author` fields and the visual companion's brand link credit the upstream author (Jesse Vincent / [`obra/superpowers`](https://github.com/obra/superpowers)). Fork maintainer identity — marketplace `owner` and each manifest's `interface.developerName` — is Scott Johnson. Keep these consistent when bumping versions or adding new manifests.

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it steps back and asks you what you're really trying to do.

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read and digest.

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI (You Aren't Gonna Need It), and DRY.

Next up, once you say "go", it launches a *subagent-driven-development* process, having agents work through each engineering task, inspecting and reviewing their work, and continuing forward. It's not uncommon for your agent to work autonomously for a couple hours at a time without deviating from the plan you put together.

There's a bunch more to it, but that's the core of the system. And because the skills trigger automatically, you don't need to do anything special.

## Installation

**This fork is distributed only from its GitHub repository ([`scott-arne/hyperpowers`](https://github.com/scott-arne/hyperpowers)).** It is *not* published to any public or official plugin marketplace — not Anthropic's official Claude marketplace, not OpenAI's Codex plugin store, not Cursor's, and not the upstream `superpowers` marketplaces. Install it directly from the repo using the per-harness commands below. If you want the original, marketplace-distributed project instead, install [Superpowers](https://github.com/obra/superpowers).

Install separately for each harness you use. The marketplace name bundled in this repo is `hyperpowers-dev` and the plugin name is `hyperpowers`; the install commands below reflect those.

### Claude Code

- Add this repository as a plugin marketplace:

  ```bash
  /plugin marketplace add scott-arne/hyperpowers
  ```

- Install the plugin from it:

  ```bash
  /plugin install hyperpowers@hyperpowers-dev
  ```

### Antigravity

Install as a plugin straight from the repository:

```bash
agy plugin install https://github.com/scott-arne/hyperpowers
```

Antigravity runs the plugin's session-start hook, so the skills are active from the first message. Reinstall with the same command to update.

### Codex (CLI / App)

This fork is not in OpenAI's official Codex plugin marketplace, so the in-app store and `/plugins` search will not find it. The repo does ship a Codex manifest (`.codex-plugin/plugin.json`) and Codex session hooks, so you can use it by cloning the repository and loading it as a local plugin checkout. (Upstream Superpowers *is* available through the official Codex marketplace if you want the store install.)

### Cursor

This fork is not on Cursor's plugin marketplace, so marketplace search will not find it. The repo ships a Cursor manifest (`.cursor-plugin/plugin.json`) and `hooks/hooks-cursor.json`; install it by pointing Cursor at a local checkout of this repository.

### Factory Droid

- Register this repository as a marketplace:

  ```bash
  droid plugin marketplace add https://github.com/scott-arne/hyperpowers
  ```

- Install the plugin:

  ```bash
  droid plugin install hyperpowers@hyperpowers-dev
  ```

### Gemini CLI

- Install the extension from the repository:

  ```bash
  gemini extensions install https://github.com/scott-arne/hyperpowers
  ```

- Update later:

  ```bash
  gemini extensions update hyperpowers
  ```

### GitHub Copilot CLI

- Register this repository as a marketplace:

  ```bash
  copilot plugin marketplace add scott-arne/hyperpowers
  ```

- Install the plugin:

  ```bash
  copilot plugin install hyperpowers@hyperpowers-dev
  ```

### Kimi Code

Install directly from the repository:

```text
/plugins install https://github.com/scott-arne/hyperpowers
```

Detailed docs: [docs/README.kimi.md](docs/README.kimi.md)

### OpenCode

Add the git-backed package spec to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["hyperpowers@git+https://github.com/scott-arne/hyperpowers.git"]
}
```

Detailed docs: [docs/README.opencode.md](docs/README.opencode.md)

### Pi

Install as a Pi package from the repository:

```bash
pi install git:github.com/scott-arne/hyperpowers
```

For local development, run Pi with this checkout loaded as a temporary package:

```bash
pi -e /path/to/hyperpowers
```

The Pi package loads the skills and a small extension that injects the `using-hyperpowers` bootstrap at session startup and again after compaction. Pi has native skills, so no compatibility `Skill` tool is required. Subagent and task-list tools remain optional Pi companion packages.

## The Basic Workflow

1. **brainstorming** - Activates before writing code. Refines rough ideas through questions, explores alternatives, presents design in sections for validation. Saves design document.

2. **using-git-worktrees** - Activates after design approval. Creates isolated workspace on new branch, runs project setup, verifies clean test baseline.

3. **writing-plans** - Activates with approved design. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, verification steps.

4. **subagent-driven-development** or **executing-plans** - Activates with plan. Dispatches fresh subagent per task with two-stage review (spec compliance, then code quality), or executes in batches with human checkpoints.

5. **test-driven-development** - Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests.

6. **requesting-code-review** - Activates between tasks. Reviews against plan, reports issues by severity. Critical issues block progress.

7. **finishing-a-development-branch** - Activates when tasks complete. Verifies tests, presents options (merge/PR/keep/discard), cleans up worktree.

**The agent checks for relevant skills before any task.** Mandatory workflows, not suggestions.

## What's Inside

### Skills Library

**Testing**
- **test-driven-development** - RED-GREEN-REFACTOR cycle (includes testing anti-patterns reference)

**Debugging**
- **systematic-debugging** - 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)
- **verification-before-completion** - Ensure it's actually fixed

**Collaboration**
- **brainstorming** - Socratic design refinement
- **writing-plans** - Detailed implementation plans
- **executing-plans** - Batch execution with checkpoints
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Pre-review checklist
- **receiving-code-review** - Responding to feedback
- **using-git-worktrees** - Parallel development branches
- **finishing-a-development-branch** - Merge/PR decision workflow
- **subagent-driven-development** - Fast iteration with two-stage review (spec compliance, then code quality)

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-hyperpowers** - Introduction to the skills system

## Philosophy

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success

For background on the methodology, read the upstream project's [original release announcement](https://blog.fsck.com/2025/10/09/superpowers/).

## Customizing this fork

This fork exists so the skills and prompts can be modified locally. To work on them:

1. Create a branch for your change.
2. Follow the `writing-skills` skill for creating and testing new or modified skills — skills are behavior-shaping code, not prose, so changes should be evaluated.
3. Run the plugin-infrastructure tests under `tests/` (each directory has a `run-*.sh`, or use `npm test` where present).

Skill-behavior tests use the drill eval harness from [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals/), cloned into `evals/` — see `evals/README.md` for setup. Plugin-infrastructure tests live at `tests/` and run via the relevant `run-*.sh` or `npm test`.
See `skills/writing-skills/SKILL.md` for the complete guide.

## Merging upstream Superpowers changes

This fork tracks [`obra/superpowers`](https://github.com/obra/superpowers) as a read-only `upstream` remote so improvements there — evolved prompts, new skills, new harness support — can be pulled in selectively.

### One-time setup (per clone)

```bash
git remote add upstream https://github.com/obra/superpowers.git
git remote set-url --push upstream DISABLE   # fetch-only; prevents accidental pushes to upstream
git config rerere.enabled true               # record conflict resolutions...
git config rerere.autoupdate true            # ...and replay them automatically next time
```

`rerere` matters here: because the rebrand renamed `superpowers` → `hyperpowers` across manifests, the skill namespace, and file paths, upstream edits to those same lines conflict on **every** sync. With `rerere` on, you resolve each recurring identity conflict **once** and Git replays the resolution from then on.

### Syncing a release

Work tag-to-tag (`v6.0.0` → `v6.0.2` → …), not off the moving `upstream/main` — releases are coherent, reviewable units.

```bash
git fetch upstream                                  # read-only; pulls branches + tags
git log --oneline --no-merges <your-base>..v6.0.2   # review what's new
git diff <your-base>..v6.0.2 -- <path>              # inspect a specific change
```

Then choose the granularity that fits:

- **Take most of a release** — `git merge v6.0.2` (or rebase this fork's commits onto it). Let `rerere` auto-resolve the identity conflicts; review the rest.
- **Take one specific improvement** — `git cherry-pick <sha>`. Best for pulling a single evolved prompt or bug fix without the rest of a release.
- **Skip something** — simply don't merge or cherry-pick it.

### Fork-specific things to re-check on every sync

- **Rebrand conflicts are expected.** When upstream writes `superpowers` where this fork has `hyperpowers` (manifest `name` fields, the `hyperpowers:<skill>` namespace, renamed paths), keep the `hyperpowers` side. `rerere` learns these after the first time.
- **Deleted publishing infrastructure may return.** `scripts/sync-to-codex-plugin.sh` and `tests/codex-plugin-sync/` were removed from this fork on purpose; upstream still has them, and `rerere` does **not** remember deletions. Re-run `git rm` on them after a merge that reintroduces them.
- **Skill-content prose vs. package identity.** Upstream changes to skill *behavior* are usually what you want; resist auto-renaming the agent-facing word "superpowers" in skill bodies back to "hyperpowers" — that capability phrasing is kept deliberately (see the note at the top of this README).
- **The `evals` submodule.** Upstream may add, move, or drop it; decide once per sync whether this fork follows.

Always review the complete merged diff before committing.

## License

MIT License - see [LICENSE](LICENSE) for details. Copyright for the original work belongs to the upstream Superpowers authors.

## Visual companion telemetry

This behavior is **inherited unchanged from upstream Superpowers** and has not been altered in this fork. By default, the Prime Radiant logo on brainstorming's optional visual companion feature is loaded from primeradiant.com, and that request includes the package version in use. It does not include any details about your project, prompt, or coding agent. To disable it, set the environment variable `SUPERPOWERS_DISABLE_TELEMETRY` (the variable name is kept as-is for upstream compatibility) to any true value. The companion also honors Claude Code's `DISABLE_TELEMETRY` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` opt-outs.

## Credits

Hyperpowers is a fork of [Superpowers](https://github.com/obra/superpowers), built by [Jesse Vincent](https://blog.fsck.com) and [Prime Radiant](https://primeradiant.com). For the canonical project, community, and support, see the upstream repository.

- **This fork's issues**: https://github.com/scott-arne/hyperpowers/issues
- **Upstream project**: https://github.com/obra/superpowers