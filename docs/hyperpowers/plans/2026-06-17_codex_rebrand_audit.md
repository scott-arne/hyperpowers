# Codex Rebrand Audit

**Date:** 2026-06-17

**Scope:** Validate that the fork is logically coherent after the upstream
`obra/superpowers` -> `scott-arne/hyperpowers` rebrand, with the intended split:
agent-facing prompt language can still say "superpowers", while repository
identity, plugin names, skill namespaces, paths, and install instructions should
point at Hyperpowers so the customized fork is what loads.

## Summary

The repository is mostly coherent after the rebrand. The active manifests,
bootstrap hooks, core skill namespace references, plan/spec output paths, Pi
extension, OpenCode plugin, Kimi manifest, and version-bump configuration all
use `hyperpowers` where that affects install or runtime behavior.

I found no broken JSON manifests and the main non-LLM validation tests pass.
There are still a few living, non-historical references that point at upstream
Superpowers or use `superpowers` where this fork's identity is intended. Most
are low-risk wording or link issues, but one Antigravity runtime path is a real
stale install path.

## Findings

### 1. Antigravity skill-loading example still points at `plugins/superpowers`

**Severity:** Medium

`skills/using-hyperpowers/references/antigravity-tools.md:21-28` documents the
Antigravity skill-loading mechanism and tells agents to read:

```text
.../plugins/superpowers/skills/<skill-name>/SKILL.md
```

That is a concrete plugin path, not just prompt prose. In a machine with both
upstream Superpowers and this fork installed, this instruction can send an
Antigravity agent to the upstream skill tree instead of the customized
Hyperpowers skill tree.

**Remediation:** Change the example to `.../plugins/hyperpowers/skills/<skill-name>/SKILL.md`.
Add an Antigravity test assertion that living tool mappings do not contain
`plugins/superpowers`.

### 2. Visual companion branding links to upstream repository

**Severity:** Medium

`skills/brainstorming/scripts/server.cjs:251` renders the visual companion brand
link as:

```text
https://github.com/obra/superpowers
```

The visible label "Superpowers" can reasonably remain prompt/product language,
but the link is a repository reference. It sends users away from this fork and
toward upstream, which conflicts with the fork's install and customization
story.

**Remediation:** Point the link to `https://github.com/scott-arne/hyperpowers`,
or add an explicit comment and README note if the upstream link is deliberately
kept as attribution. If changed, extend `tests/brainstorm-server/branding.test.js`
to assert the link target.

### 3. Living skill docs still label this package as "Superpowers skills"

**Severity:** Low to Medium

The runtime namespace is rebranded, but a few living skill/tool-reference docs
still refer to the active package/skills as Superpowers rather than Hyperpowers:

- `skills/using-hyperpowers/SKILL.md:18-24` says "Superpowers skills" in the
  instruction-priority section.
- `skills/using-hyperpowers/references/pi-tools.md:20` says "A Superpowers Pi
  package" and "the Superpowers rule".
- `skills/using-hyperpowers/references/pi-tools.md:28` says "Superpowers plan
  files" and "Older Superpowers docs".

This does not appear to break skill loading, because the bootstrap path and
skill namespace are already `using-hyperpowers` / `hyperpowers:<skill>`. It is
still identity drift in active instructions.

**Remediation:** Replace these active package/skill labels with "Hyperpowers"
where they refer to this installed fork. Keep the agent-facing capability
phrasing, such as `You have superpowers`, unchanged.

### 4. Visual companion test fixture still models a packaged plugin named `superpowers`

**Severity:** Low

`tests/brainstorm-server/branding.test.js:77-85` creates a packaged Codex
fixture with:

```js
JSON.stringify({ name: 'superpowers', version }, null, 2)
```

The production code only reads the version field, so this did not fail tests.
However, as a rebrand regression test, the fixture is weaker than it should be:
it can keep passing even if code or UI starts depending on the upstream package
name.

**Remediation:** Change the fixture package name to `hyperpowers` and add
assertions for any brand/repository identity that should differ from upstream.

### 5. Manifest maintainer/author identity is mixed

**Severity:** Low

Repository URLs point to `scott-arne/hyperpowers`, but several plugin manifests
still display Jesse Vincent as the author/developer:

- `.codex-plugin/plugin.json:4-10` lists Jesse/obra as `author`, while
  `homepage` and `repository` are the fork.
- `.codex-plugin/plugin.json:28` sets `interface.developerName` to Jesse
  Vincent.
- `.kimi-plugin/plugin.json:4-8` and `.kimi-plugin/plugin.json:29` do the same.
- `.claude-plugin/plugin.json:5-10` and `.cursor-plugin/plugin.json:6-11` keep
  upstream author fields.
- `.claude-plugin/marketplace.json:4-17` uses Scott Johnson as owner/author.

This may be intentional attribution, but marketplace/plugin UI can read these
fields as current maintainer identity rather than historical authorship.

**Remediation:** Decide a policy and encode it consistently. A conservative
option is: package `author` remains Jesse Vincent for upstream authorship,
marketplace `owner`/interface `developerName` uses Scott Johnson for this fork's
maintainer. If the schema lacks a maintainer field, document the choice in a
short manifest-adjacent comment is not possible for JSON, so prefer README
clarity and consistent UI-facing `developerName`.

### 6. Git branch tracking points `master` at stale `origin/main`

**Severity:** Medium operational risk

The local branch is:

```text
master ab6cf86 [origin/main: ahead 8] Merge upstream v6.0.2 (superpowers) into hyperpowers fork
```

Remote refs show:

```text
origin/HEAD -> origin/main
origin/main 284be59  # v6.0.0-era upstream-shaped history
origin/master c6d6218 # fork rebrand commit history
```

This is not a code bug, but it is a repo correctness risk. A normal `git status`
reports the fork as "ahead 8" of `origin/main`, while `origin/master` already has
some fork-specific commits. Depending on the user's `push.default`, a push from
`master` may fail, push to an unexpected branch, or leave GitHub's default branch
behind the actual fork work.

**Remediation:** Choose the fork's canonical branch name, then align all three:
local branch name, upstream tracking branch, and GitHub default branch. For
example, either rename local `master` to `main` and push/update `origin/main`, or
change tracking/default branch to `origin/master` if `master` is the intended
fork branch.

### 7. Kimi docs reference a `dev` branch that is not present in this checkout

**Severity:** Low

`docs/README.kimi.md:15-18` and `docs/README.kimi.md:68-74` tell users to install:

```text
/plugins install https://github.com/scott-arne/hyperpowers/tree/dev
```

This checkout currently has no `origin/dev` ref. If GitHub also lacks that branch,
the documented unreleased-validation install path fails.

**Remediation:** Update the docs to the actual development branch, or create and
maintain `dev` in the fork. If the intended branch is `master` or `main`, use
that in the Kimi instructions.

### 8. OpenCode pin examples still use `v6.0.0`

**Severity:** Low

The current declared version is `6.0.2`, and `scripts/bump-version.sh --check`
confirms all declared manifests agree. The OpenCode docs still show pin examples
for `#v6.0.0`:

- `.opencode/INSTALL.md:55-60`
- `docs/README.opencode.md:87-92`

This is not a rebrand error, but it is stale user-facing guidance.

**Remediation:** Change the examples to `#v6.0.2`, or make them intentionally
generic, such as `#vX.Y.Z`.

### 9. Test dependency audit reports a high-severity `ws` advisory

**Severity:** Low for shipped plugin, Medium for test hygiene

`tests/brainstorm-server/package-lock.json` pins `ws@8.19.0`. `npm audit --json`
reports:

- `GHSA-58qx-3vcg-4xpx`: uninitialized memory disclosure, range `>=8.0.0 <8.20.1`
- `GHSA-96hv-2xvq-fx4p`: memory exhaustion DoS, range `>=8.0.0 <8.21.0`

This dependency is in the test package, not the shipped zero-dependency plugin
runtime, but it is still audit noise and can block security-gated workflows.

**Remediation:** Update the test dependency to a fixed `ws` version outside the
reported vulnerable ranges, then regenerate `tests/brainstorm-server/package-lock.json`
and rerun `npm test` in that directory.

## Historical References I Would Not Rewrite By Default

There are many `superpowers:` and `docs/superpowers/...` references in
`RELEASE-NOTES.md`, `docs/plans/**`, and older files under
`docs/hyperpowers/plans/**` / `docs/hyperpowers/specs/**`. These are dated
artifacts and upstream release history. Rewriting them wholesale would obscure
what happened at the time and create noisy merge conflicts with upstream.

Recommended policy:

- Do not rewrite dated plans/specs/release notes by default.
- Keep current living docs, manifests, tests, hooks, and skill instructions
  rebranded.
- If historical references cause repeated confusion, add a one-line historical
  artifact note at the top of the relevant file or exclude those paths from
  rebrand audit scripts.

## Intentional Superpowers Language

The following pattern appears intentional and should be preserved unless the
product language changes:

- `hooks/session-start:27`, `hooks/session-start-codex:22`,
  `.opencode/plugins/hyperpowers.js:89-97`, and
  `.pi/extensions/hyperpowers.ts:65-75` inject "You have superpowers."
- README and CLAUDE/AGENTS explicitly document that the agent-facing capability
  is still called "superpowers" while package identity and skill namespace are
  `hyperpowers`.

## Validation Performed

Passed:

- Parsed JSON manifests/configs with Node:
  `package.json`, `.codex-plugin/plugin.json`, `.claude-plugin/plugin.json`,
  `.cursor-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
  `.kimi-plugin/plugin.json`, `gemini-extension.json`, and hook JSON files.
- `bash scripts/bump-version.sh --check`
- `bash tests/hooks/test-session-start.sh`
- `bash tests/kimi/run-tests.sh`
- `bash tests/antigravity/run-tests.sh`
- `bash tests/opencode/run-tests.sh` (non-integration tests only)
- `node --test tests/pi/test-pi-extension.mjs`
- `bash tests/shell-lint/test-lint-shell.sh`
- `node tests/brainstorm-server/branding.test.js` after allowing localhost bind
- `npm test` in `tests/brainstorm-server` after installing locked test deps

Not run:

- OpenCode integration tests requiring an installed/configured OpenCode runtime.
- Claude Code behavioral/eval tests requiring live agent harnesses and model
  execution.
- Drill evals, because `evals/` is intentionally ignored and absent from this
  checkout.

## Overall Recommendation

Fix findings 1, 2, 6, and 7 before treating the fork as fully rebrand-clean.
Findings 3, 4, 5, 8, and 9 are lower-risk cleanup or policy decisions, but they
are worth addressing while the rebrand context is still fresh.
