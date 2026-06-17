# Codex Rebrand — Remediation Plan

**Date:** 2026-06-17
**Companion to:** [`2026-06-17_codex_rebrand_audit.md`](2026-06-17_codex_rebrand_audit.md)
**Status:** Plan only — not yet executed.

## Purpose

Close all 9 findings from the rebrand audit so the fork is logically coherent:
repository identity, plugin paths, skill labels, install docs, and branch
topology all point at `scott-arne/hyperpowers`, while the deliberately-preserved
upstream attribution (Jesse Vincent authorship, the `obra/superpowers` brand
link, the agent-facing phrase "You have superpowers") stays intact and is
documented as intentional.

All 9 findings were re-verified against the working tree on 2026-06-17 before
this plan was written; every finding still holds.

## Decisions locked (from your-partner review)

These three decisions shape the plan; they are settled, not open questions.

1. **Canonical branch → `main`.** Rename local `master` → `main`, fast-forward
   `origin/main` to the merge commit, set the GitHub default branch to `main`,
   retire `origin/master`. Verified safe: `origin/master` (`c6d6218`) and
   `origin/main` (`284be59`) are both ancestors of `HEAD` (`ab6cf86`), so no
   commits are lost and the remote update is a fast-forward.
2. **Attribution stays upstream; Scott is developer/maintainer.**
   - `author` fields in all manifests **stay** Jesse Vincent (upstream authorship).
   - The brainstorming brand link **stays** `https://github.com/obra/superpowers`
     and is documented as deliberate attribution (finding 2 becomes a
     *document + lock* task, not a code redirect).
   - `interface.developerName` (the fork's developer/maintainer UI field,
     currently Jesse) **changes to Scott Johnson**. Marketplace `owner` is
     already Scott. *(Interpretation flag: "Scott is just the developer and
     maintainer" → developer/maintainer fields are Scott, authorship is Jesse.
     If you intended developerName to also stay Jesse, say so before Stage 2 and
     drop that one edit.)*
3. **Scope → all 9 findings**, staged by risk.

## Execution staging

Stages are ordered so each is independently shippable and the riskiest
operational change (branch surgery) is isolated and last.

| Stage | Findings | Theme | Risk |
|------|----------|-------|------|
| 1 | 1, 3, 4 | Path + label drift in living docs/tests | Low, code-only |
| 2 | 2, 5 | Attribution policy: document + adjust developerName | Low, manifests/docs |
| 3 | 7, 8 | Install-doc accuracy (dev branch, version pins) | Low, docs-only |
| 4 | 9 | `ws` test-dependency advisory | Low, needs network/proxy |
| 5 | 6 | Branch canonicalization (`master` → `main`) | **Medium operational — has remote force-update** |

Each stage ends with its own verification. Commit per stage (one problem per
change, per `CLAUDE.md`); do **not** commit this plan file unless explicitly
asked.

---

## Stage 1 — Path + label drift (findings 1, 3, 4)

### 1.1 — Antigravity skill-load path (finding 1, **Medium**)

**File:** `skills/using-hyperpowers/references/antigravity-tools.md:27`

Change the concrete plugin path so Antigravity agents load the fork's skill
tree, not a co-installed upstream copy:

```diff
-`.../plugins/superpowers/skills/<skill-name>/SKILL.md` with `IsSkillFile: true`.
+`.../plugins/hyperpowers/skills/<skill-name>/SKILL.md` with `IsSkillFile: true`.
```

**Regression guard.** Add to `tests/antigravity/test-antigravity-tools.sh` (after
the existing mapping checks) an assertion that the mapping contains **no** stale
upstream plugin path:

```bash
# --- No stale upstream plugin path (rebrand regression) ---------------------
grep -q "plugins/superpowers" "$MAPPING" \
  && fail "mapping points at stale upstream plugins/superpowers path"
```

(Note the inverted sense: this `grep` must *not* match. Use `! grep -q ... ||
fail` form to keep `set -euo pipefail` happy:)

```bash
! grep -q "plugins/superpowers" "$MAPPING" \
  || fail "mapping points at stale upstream plugins/superpowers path"
```

**Verify:** `bash tests/antigravity/run-tests.sh` → all pass.

### 1.2 — "Superpowers skills" labels in living instructions (finding 3, **Low–Med**)

Replace package/skill *identity* labels with "Hyperpowers" while leaving the
agent-facing capability phrase ("You have superpowers") untouched.

**File:** `skills/using-hyperpowers/SKILL.md` (Instruction Priority section, ~18–24)
- "Superpowers skills override default system prompt behavior" → "Hyperpowers skills override…"
- List item `2. **Superpowers skills**` → `2. **Hyperpowers skills**`

**File:** `skills/using-hyperpowers/references/pi-tools.md`
- ~line 20: "A Superpowers Pi package" → "A Hyperpowers Pi package"; "the
  Superpowers rule" → "the Hyperpowers rule".
- ~line 28: "Superpowers plan files" → "Hyperpowers plan files"; "Older
  Superpowers docs" → "Older Hyperpowers docs".

**Do not touch:** any `You have superpowers` injection, README/CLAUDE prose that
deliberately explains the superpowers-capability naming, or historical
docs/plans (see *Out of scope* below).

**Verify:** `node --test tests/pi/test-pi-extension.mjs`;
`bash tests/hooks/test-session-start.sh`. Grep the two files to confirm no
remaining identity-label "Superpowers" except intentional capability phrasing.

### 1.3 — Brainstorm test fixture package name (finding 4, **Low**)

**File:** `tests/brainstorm-server/branding.test.js:84`

```diff
-    JSON.stringify({ name: 'superpowers', version }, null, 2)
+    JSON.stringify({ name: 'hyperpowers', version }, null, 2)
```

The brand/link assertion this fixture should also gain is added in Stage 2.4
(kept with the brand-link decision so both land together).

**Verify:** deferred to Stage 2 (same test file).

---

## Stage 2 — Attribution policy (findings 2, 5)

### 2.1 — `interface.developerName` → Scott Johnson

Per decision 2, the developer/maintainer UI field becomes Scott; `author` stays
Jesse.

**Files:**
- `.codex-plugin/plugin.json` — `interface.developerName`: `"Jesse Vincent"` → `"Scott Johnson"`
- `.kimi-plugin/plugin.json` — `interface.developerName`: `"Jesse Vincent"` → `"Scott Johnson"`

**Unchanged (confirm, do not edit):**
- `author` in `.codex-plugin`, `.kimi-plugin`, `.claude-plugin`, `.cursor-plugin` → stays Jesse Vincent.
- `.claude-plugin/marketplace.json` `owner`/`author` → already Scott Johnson.

### 2.2 — Brand link stays upstream, documented as intentional (finding 2)

**File:** `skills/brainstorming/scripts/server.cjs:251` — **no change to the URL.**
Add a brief comment above the return so the choice is explicit and survives
future audits:

```js
// Brand link intentionally points at the upstream project (obra/superpowers)
// as authorship attribution. This fork (scott-arne/hyperpowers) is maintained
// by Scott Johnson; see README "Relationship to Upstream".
```

### 2.3 — Document the attribution policy once, centrally

**File:** `README.md` (and/or `CLAUDE.md`) — add a short, durable note under the
existing upstream-relationship section so future contributors keep manifests
consistent:

> **Attribution policy.** Package `author` and the visual companion's brand link
> credit the upstream author (Jesse Vincent / `obra/superpowers`). Fork
> maintainer identity — marketplace `owner`, `interface.developerName` — is Scott
> Johnson. Keep these consistent when bumping or adding manifests.

### 2.4 — Lock both decisions with a test (findings 2 + 4)

**File:** `tests/brainstorm-server/branding.test.js`

Add an assertion that the rendered brand link target is the intentional upstream
URL (turns the kept-on-purpose link into a tested invariant; if someone later
"fixes" it to the fork without updating policy, the test fails and forces the
conversation):

```js
assert(
  html.includes('href="https://github.com/obra/superpowers"'),
  'brand link intentionally attributes upstream obra/superpowers (see attribution policy)'
);
```

**Verify:** `cd tests/brainstorm-server && node branding.test.js` (allow
localhost bind). Pre-existing network-dependent logo assertions that require
`primeradiant.com` may still fail offline — that is the known baseline, not a
regression introduced here; note any such failures rather than chasing them.

---

## Stage 3 — Install-doc accuracy (findings 7, 8)

### 3.1 — Kimi `dev`-branch install path (finding 7, **Low**)

`origin` has only `main` and `master` — no `dev`. With `main` canonical, the
fork's development branch *is* `main` (releases are tags `v6.0.x`).

**File:** `docs/README.kimi.md` — two locations (~15–18 and ~68–74):
- "For unreleased validation against `dev`" → "against the latest `main`".
- `/plugins install https://github.com/scott-arne/hyperpowers/tree/dev` →
  `/plugins install https://github.com/scott-arne/hyperpowers/tree/main`.
- Troubleshooting "install the branch explicitly" example → `/tree/main`.

### 3.2 — OpenCode version pins (finding 8, **Low**)

Current declared version is `6.0.2`. Update the stale pin examples:

**Files:**
- `.opencode/INSTALL.md:59` — `#v6.0.0` → `#v6.0.2`
- `docs/README.opencode.md:91` — `#v6.0.0` → `#v6.0.2`

**Recurrence guard (optional but recommended):** these example pins are not
covered by `scripts/bump-version.sh --check` (it validates manifests, not doc
prose), which is why they drifted. Either (a) extend `bump-version.sh` to rewrite
`#vX.Y.Z` examples in these two docs during a bump, or (b) make the examples
generic (`#vX.Y.Z`) so they can't go stale. Pick one; note the choice in the
commit message.

**Verify:** `bash scripts/bump-version.sh --check` still passes; grep confirms no
`v6.0.0` remains outside `RELEASE-NOTES.md` (a legitimate historical entry) and
this plans/ directory.

---

## Stage 4 — `ws` test-dependency advisory (finding 9, **Low**)

`tests/brainstorm-server` pins `ws@^8.19.0`. Advisories:
`GHSA-58qx-3vcg-4xpx` (range `<8.20.1`) and `GHSA-96hv-2xvq-fx4p` (range
`<8.21.0`). Latest `ws` is `8.21.0`, which clears **both** ranges.

**File:** `tests/brainstorm-server/package.json` — `"ws": "^8.19.0"` → `"^8.21.0"`.

Then regenerate the lockfile and rerun the suite. **This step needs network**;
set the corporate proxy first (per global `CLAUDE.md`):

```bash
export HTTP_PROXY=http://proxy-server.bms.com:8080
export HTTPS_PROXY=http://proxy-server.bms.com:8080
export NO_PROXY=s3.amazonaws.com,bms.com,localhost,127.0.0.1,169.254.169.254
cd tests/brainstorm-server
npm install            # regenerates package-lock.json against ws@8.21.0
npm audit              # expect: 0 advisories for ws
npm test               # full brainstorm-server suite
```

Commit both `package.json` and the regenerated `package-lock.json`. This is the
test harness only — the shipped plugin remains zero-dependency, so there is no
runtime impact.

---

## Stage 5 — Branch canonicalization (finding 6, **Medium operational**)

Goal: one canonical branch `main`, with local name, tracking ref, and GitHub
default all aligned. Pre-verified safe (both remote heads are ancestors of HEAD).

**Pre-flight (sanity, no mutation):**

```bash
git status -sb                       # expect: master...origin/main [ahead 8]
git merge-base --is-ancestor c6d6218 HEAD && echo "origin/master contained: OK"
git merge-base --is-ancestor 284be59 HEAD && echo "origin/main contained: OK"
```

**Runbook:**

```bash
# 1. Rename the local branch.
git branch -m master main

# 2. Fast-forward origin/main to the merge commit (FF, not a true force;
#    --force-with-lease guards against an unexpected remote move).
git push origin main --force-with-lease

# 3. Re-point local tracking at origin/main.
git branch -u origin/main main
```

**4. GitHub default branch → `main`.** The `gh` CLI cannot read its config in
this environment (permission denied), so do this via the GitHub web UI
(*Settings → Branches → Default branch → main*), or run the `gh` command below
once `gh auth`/config is fixed:

```bash
gh repo edit scott-arne/hyperpowers --default-branch main
```

**5. Retire `origin/master`** (optional; safe — it is an ancestor of `main`).
Only after the default branch is switched to `main` on GitHub:

```bash
git push origin --delete master
```

**Post-checks:**

```bash
git status -sb                       # expect: main...origin/main (in sync)
git ls-remote --heads origin         # expect: refs/heads/main only (master gone if deleted)
```

**Caution:** Do not delete `origin/master` *before* GitHub's default branch is
moved off it — deleting the current default branch is rejected / disruptive.
Nothing here is run without your go-ahead.

---

## Final validation (run after all stages)

Re-run the audit's "Passed" battery to confirm no regressions:

```bash
bash scripts/bump-version.sh --check
bash tests/hooks/test-session-start.sh
bash tests/kimi/run-tests.sh
bash tests/antigravity/run-tests.sh
bash tests/opencode/run-tests.sh        # non-integration only
node --test tests/pi/test-pi-extension.mjs
bash tests/shell-lint/test-lint-shell.sh
cd tests/brainstorm-server && npm test  # with proxy + localhost bind
```

JSON-parse every manifest touched in Stage 2 (`node -e "require('./<file>')"` or
`jq . <file>`) to guarantee no syntax breakage. Acceptance test for harness
integrity (per `CLAUDE.md`): a clean session given *"Let's make a react todo
list"* should still auto-trigger `brainstorming`.

## Out of scope (deliberately not changed)

- **Historical references.** `superpowers:` / `docs/superpowers/...` strings in
  `RELEASE-NOTES.md`, `docs/plans/**`, and dated `docs/hyperpowers/{plans,specs}/**`
  are artifacts of their time. Per the audit's policy, leave them; rewriting
  invites noisy upstream merge conflicts and obscures history.
- **Intentional "superpowers" capability language.** `You have superpowers.`
  injections in `hooks/session-start*`, `.opencode/plugins/hyperpowers.js`,
  `.pi/extensions/hyperpowers.ts`, and the explanatory README/CLAUDE/AGENTS prose
  stay verbatim.
- **`author` = Jesse Vincent** in all manifests (attribution, per decision 2).
- **Brand link → `obra/superpowers`** in `server.cjs` (attribution, per decision 2).

## Skill-content caveat

`skills/using-hyperpowers/SKILL.md` and `pi-tools.md` are skill content. The
Stage 1.2 edits are pure identity-label swaps (Superpowers→Hyperpowers), not
changes to tuned behavior-shaping language (no Red Flags tables, rationalization
lists, or "human partner" phrasing touched), so they do not require the full
`writing-skills` adversarial evaluation loop. If review disagrees, route 1.2
through `hyperpowers:writing-skills` before committing.
