# Read the Docs Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. A correction added during execution that alters one of the spec's decisions names it: `Correction (<date>), decision <N> (<title>):`.

**Spec:** `docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md`

**Goal:** A Sphinx documentation site in `docs/site/` (Lumina theme, MyST) that explains what each hyperpowers skill does, why, and its pros and cons, with an offline check that fails when a page drifts from the sources it describes.

**Architecture:** Hand-written MyST pages under `docs/site/`, built by Sphinx with pinned dependencies through `uv run` locally and on Read the Docs. A bash checker, `tests/docs/docs-check.sh`, reads each page's `sources:` and `source-digest:` front matter, recomputes the digest over the tracked files under those sources, and also checks coverage, the skills index, skill-page structure, and dollar amounts. Pages are written in category batches, each adding itself to the toctrees so the `-W` build stays green after every task.

**Tech Stack:** Sphinx 9.2.0, sphinx-lumina-theme 2.19.1, myst-parser 5.1.0, sphinx-design 0.7.0, sphinx-copybutton 0.5.2, sphinxcontrib-mermaid 2.1.1, sphinx-sitemap 2.9.0, Python 3.13 via `uv run`, bash 3.2-compatible shell, BSD `grep`/`sed`/`awk`.

## Global Constraints

- No dollar figures anywhere: not in pages, tests, commit messages, or this plan. Percentages are allowed.
- No private information about the maintainer's organization in any committed file. The organization is not named. Recommended settings describe measured results without saying whose sessions they came from.
- Every commit runs in this order: stage the task's files, then scan what is staged, then commit that index with that message. The scans: `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` (expect `hits: 0`), `git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'` (expect `0`), and `printf '%s\n' "<message>" | grep -cE '\$[0-9]'` (expect `0`). Each task's commit block spells these out. Because the scan matches any `$` followed by a digit, shell code written in this plan uses `${1}` for positional parameters and awk uses `$(0)` for the whole record.
- Work happens on a feature branch in a worktree (hyperpowers:using-git-worktrees). Per-task commits stay on that branch; it reaches `main` only through hyperpowers:finishing-a-development-branch, where the human partner sees the branch diff and chooses to merge, open a pull request, keep, or discard.
- Credit follows the README's attribution policy (`README.md:9`): the methodology and most skill design are upstream Superpowers' work by Jesse Vincent and Prime Radiant; Scott Johnson maintains the fork.
- Every claim about a skill's behavior is checked against that skill's `SKILL.md` and supporting files at the commit the page is written from. Reasons come from `docs/hyperpowers/specs/`, `docs/hyperpowers/decisions/`, and the README. Pages do not invent behavior, outputs, or numbers.
- Skill pages carry no eval numbers. `advanced/testing-skills.md` explains the method without per-release numbers. `recommended-settings.md` may quote only the percentages listed in Task 10.
- Prose follows hyperpowers:communication: lead with the point, name the specific thing, no filler, no metaphors standing in for facts. Implementers writing pages invoke that skill first.
- Pages address the reader as "you". Skill vocabulary such as "your human partner" appears in quotes where a page explains it.
- Python tooling runs through `uv run --python 3.13 --with-requirements docs/site/requirements.txt ...` with an ephemeral environment. Nothing is installed into a shared or global environment. If the Bash sandbox blocks PyPI, re-run the same command with `pypi.org` and `files.pythonhosted.org` as allowed domains.
- Build command (every page task runs it; exit 0 required):
  `uv run --python 3.13 --with-requirements docs/site/requirements.txt sphinx-build -W --keep-going docs/site docs/site/_build/html`
- No file under `skills/`, `hooks/`, or `scripts/` changes.
- Nothing is pushed. The pending history rewrite (memory note `history-rewrite-2026-11-05-pending`) is not run while this plan executes; it would rewrite this branch's base.
- No live eval runs; no evidence directory is needed.

## Grounding

- Offline bash test shape: `tests/claude-code/test-docs-allowlist.sh:1-35` (purpose header, `set -euo pipefail`, `SCRIPT_DIR`/`REPO_ROOT`, a `mktemp` root with a refusal guard and cleanup trap, `pass`/`fail` helpers, a `make_repo` git fixture).
- Fixture text in tests: `tests/hooks/test-no-heredocs-in-hooks.sh:1-9` (no here-strings in `tests/`, heredocs are a known deadlock gap; build fixture files with `printf`).
- Offline runner wiring: `tests/run-offline.sh:20-23` (one explicit glob per test directory in the loop).
- Test table: `docs/testing.md:21-33` (one row per directory: covers, runner).
- Contributor guidelines: `CLAUDE.md:22-27` ("Making Changes in This Fork" bullet list).
- Shell lint scope: `scripts/lint-shell.sh:74,96` (lints every tracked and untracked non-ignored `.sh`, so new suites must be shellcheck-clean).
- Ignore file: `.gitignore:1-10` (one path per line, `dist/` style).
- Version source: `vrzn.toml:11-13` (`package.json` is the first of the version locations vrzn keeps in step, so it is the file to read).
- Attribution policy: `README.md:9`.
- Cost material for Task 10: `README.md:178-198` ("Cost and Context") and `docs/hyperpowers/2026-11-03-cost-reduction-6-16-2-eval-evidence.md:78-93` (per-compaction re-read rates, the 300K headroom, the 200K floor).
- Decision records index: `docs/hyperpowers/decisions/README.md:1-12`.
- Sphinx project, `conf.py`, MyST pages, Read the Docs config: none: no existing Sphinx project in this repository.

A scratch probe build on 2026-11-05 with the pinned requirements and the `conf.py` below established, before any task depends on it: the `-W` build passes with empty captioned toctrees, the `sources:`/`source-digest:` front matter, a sphinx-design card, and a Mermaid block; the `{source}` role renders `blob/<ref>/<path>`; the theme's edit link is `edit/<ref>/docs/site/<page>.md`; sitemap URLs come out as `<canonical URL><page>.html` with Read the Docs' variables set; the sidebar shows captions only from the root document's toctrees (captions of toctrees inside `skills/index.md` are not rendered), which is why the six category toctrees live in `docs/site/index.md`.

External facts checked on 2026-11-05, so no task carries them as assumptions:

- Read the Docs configuration reference (`https://docs.readthedocs.com/platform/stable/config-file/v2.html`): `build.os` accepts `"ubuntu-24.04"`, `build.tools.python` accepts `"3.13"`, `build.jobs.post_checkout` is an allowed key, and `sphinx.fail_on_warning` runs Sphinx with `-W --keep-going`.
- Read the Docs environment variables (`https://docs.readthedocs.com/platform/stable/reference/environment-variables.html`): `READTHEDOCS_GIT_IDENTIFIER` is the branch or tag checked out (a pull-request build gets the request's number instead, which only affects preview builds); `READTHEDOCS_CANONICAL_URL` is the version's base URL with language and version appended, for example `https://docs.readthedocs.io/ja/stable/`.
- Claude Code 2.1.317 (the newest binary under `~/.local/share/claude/versions/`) contains the strings `autoCompactWindow`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, and `ENABLE_PROMPT_CACHING_1H`; their effects are the ones measured in `docs/hyperpowers/specs/2026-11-03-cost-reduction-6-16-2-design.md`.

---

### Task 1: Site scaffold and home page

**Risk tier:** standard — new build configuration across five files.

**Files:**
- Create: `docs/site/conf.py`
- Create: `docs/site/requirements.txt`
- Create: `docs/site/index.md`
- Create: `.readthedocs.yaml`
- Modify: `.gitignore` (append one line)

**Interfaces:**
- Produces: the build command in Global Constraints; the `{source}` role (`` {source}`path/in/repo` `` links to `https://github.com/scott-arne/hyperpowers/blob/<SOURCE_REF>/path/in/repo`); `index.md` with ten captioned toctrees, in this order, that later tasks append entries to: `Guide`, `Skills`, `Process skills`, `Testing skills`, `Debugging skills`, `Review skills`, `Performance skills`, `Meta skills`, `Advanced`, `About`. Entries are paths relative to `docs/site/` without `.md` (for example `skills/brainstorming`).

- [ ] **Step 1: Confirm the build fails before the scaffold exists**

Run: `uv run --python 3.13 --with-requirements docs/site/requirements.txt sphinx-build -W --keep-going docs/site docs/site/_build/html`
Expected: FAIL (`docs/site/requirements.txt` does not exist).

- [ ] **Step 2: Write `docs/site/requirements.txt`**

Create the directory first: `mkdir -p docs/site`.

```text
# Pinned for the Read the Docs build and the local build command in
# docs/testing.md (Python 3.13).
sphinx==9.2.0
sphinx-lumina-theme==2.19.1
sphinx-design==0.7.0
sphinx-sitemap==2.9.0
myst-parser==5.1.0
sphinx-copybutton==0.5.2
sphinxcontrib-mermaid==2.1.1
```

- [ ] **Step 3: Write `docs/site/conf.py`**

```python
"""Sphinx configuration for the hyperpowers documentation site."""

import json
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REPO_URL = "https://github.com/scott-arne/hyperpowers"

project = "Hyperpowers"
author = "Jesse Vincent and Prime Radiant (Superpowers); Scott Johnson (Hyperpowers fork)"
copyright = "2025-2026, Jesse Vincent (Superpowers) and Scott Johnson (Hyperpowers fork)"

# vrzn keeps package.json in step with the plugin manifests, so it is the
# one place the version is read from.
release = json.loads((REPO_ROOT / "package.json").read_text())["version"]
version = release

# Read the Docs sets the branch or tag being built. Links to repository
# files follow it, so a page built from a tag shows the code it documents.
SOURCE_REF = os.environ.get("READTHEDOCS_GIT_IDENTIFIER", "main")

extensions = [
    "myst_parser",
    "sphinx_design",
    "sphinx_copybutton",
    "sphinxcontrib.mermaid",
    "sphinx.ext.extlinks",
    "sphinx_sitemap",
]
myst_enable_extensions = ["colon_fence"]
extlinks = {"source": (f"{REPO_URL}/blob/{SOURCE_REF}/%s", "%s")}
exclude_patterns = ["_build"]

html_theme = "lumina"
html_title = "Hyperpowers"
html_theme_options = {
    "source_repository": REPO_URL,
    "source_branch": SOURCE_REF,
    "source_directory": "docs/site/",
    "nav_links": [
        {"title": "GitHub", "url": REPO_URL, "external": True},
        {
            "title": "Superpowers (upstream)",
            "url": "https://github.com/obra/superpowers",
            "external": True,
        },
    ],
}

# sphinx-sitemap needs a base URL. Read the Docs provides the real one; a
# local build gets a placeholder so it does not warn, and its sitemap is
# never published.
html_baseurl = os.environ.get("READTHEDOCS_CANONICAL_URL", "http://localhost:8000/")
```

- [ ] **Step 4: Write `docs/site/index.md`**

The home page. Required content, in this order, in plain prose following the Global Constraints:

1. `# Hyperpowers` and one paragraph: hyperpowers is a set of skills and a session-start bootstrap that give a coding agent a working method: design before code, tests before implementation, review before "done". It runs in ten agent harnesses (name Claude Code, Codex, Cursor, and "seven more", linking `install` once Task 7 exists; in this task, no link).
2. The problem it addresses, in two to four sentences, drawn from `README.md:13-24` ("How it works").
3. Where to start: three short bullets (new reader: the guide pages; choosing skills: the skills reference; cost: recommended settings). In this task these are plain text; Task 11 turns them into `{doc}` links once every target exists.
4. A credit paragraph: hyperpowers is a fork of Superpowers by Jesse Vincent and Prime Radiant, who designed the methodology; this fork adds Codex review gates, decision records, and other changes; link `https://github.com/obra/superpowers`.
5. One `{source}` link to `README.md` ("Full installation commands are in the {source}`README.md`.").
6. The ten toctrees, each hidden from the page body, with no entries yet. Sphinx renders sidebar captions only from the root document, so the skill categories get their own toctrees here rather than in `skills/index.md`:

````markdown
```{toctree}
:caption: Guide
:hidden:
```

```{toctree}
:caption: Skills
:hidden:
```

```{toctree}
:caption: Process skills
:hidden:
```

```{toctree}
:caption: Testing skills
:hidden:
```

```{toctree}
:caption: Debugging skills
:hidden:
```

```{toctree}
:caption: Review skills
:hidden:
```

```{toctree}
:caption: Performance skills
:hidden:
```

```{toctree}
:caption: Meta skills
:hidden:
```

```{toctree}
:caption: Advanced
:hidden:
```

```{toctree}
:caption: About
:hidden:
```
````

- [ ] **Step 5: Write `.readthedocs.yaml`**

```yaml
# Read the Docs build for the documentation site in docs/site/.
version: 2

build:
  os: ubuntu-24.04
  tools:
    python: "3.13"
  jobs:
    post_checkout:
      # sphinx-sitemap depends on sphinx-last-updated-by-git, which needs
      # full history when it runs; Read the Docs clones shallow. The theme's
      # own Read the Docs build does the same.
      - git fetch --unshallow || true

sphinx:
  configuration: docs/site/conf.py
  fail_on_warning: true

python:
  install:
    - requirements: docs/site/requirements.txt
```

The image, Python version, and variables used here are checked against Read the Docs' references in Grounding.

- [ ] **Step 6: Append the build directory to `.gitignore`**

Add this line at the end of `.gitignore`:

```text
docs/site/_build/
```

- [ ] **Step 7: Build and verify**

Run the build command from Global Constraints.
Expected: exit 0, no warnings (the probe in Grounding passed this configuration). If the build warns, record the exact warning and stop: it is a plan conflict (spec assumptions 1-2).

Run the Python checks on the one Python file: `ruff check docs/site/conf.py` and `mypy docs/site/conf.py`. Expected: `All checks passed!` and `Success: no issues found in 1 source file` (the plan's `conf.py` passed both when extracted on 2026-11-05).

Then verify the version-aware links:

```bash
READTHEDOCS_GIT_IDENTIFIER=v0.0.0-test uv run --python 3.13 --with-requirements docs/site/requirements.txt sphinx-build -W --keep-going docs/site "$TMPDIR/hp-docs-ref"
grep -c 'blob/v0.0.0-test/README.md' "$TMPDIR/hp-docs-ref/index.html"
grep -c 'edit/v0.0.0-test/docs/site/index.md' "$TMPDIR/hp-docs-ref/index.html"
```

Expected: both counts at least 1 (the `{source}` link and the theme's edit link use the tag).

- [ ] **Step 8: Commit**

Stage, scan, and commit:

```bash
git add docs/site/conf.py docs/site/requirements.txt docs/site/index.md .readthedocs.yaml .gitignore
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): Sphinx scaffold with the Lumina theme and a home page" | grep -cE '\$[0-9]'
git commit -m "docs(site): Sphinx scaffold with the Lumina theme and a home page"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 2: Drift and content checker

**Risk tier:** high — the offline runner and every later task trust this checker's verdict.

**Files:**
- Create: `tests/docs/docs-check.sh`
- Create: `tests/docs/test-docs-check.sh`
- Modify: `tests/run-offline.sh:20` (loop glob list)
- Modify: `docs/testing.md` (table row after line 33; new section before "## Skill behavior evals")
- Modify: `CLAUDE.md:22-27` (one bullet)

The wiring and documentation land here, before any page exists, because `docs/testing.md` and `CLAUDE.md` are sources of pages written in Task 9; editing them later would make those pages' digests stale. Only `test-docs-check.sh` matches the new runner glob until Task 11 adds `test-docs-skills.sh`, so the offline set stays green throughout.

**Interfaces:**
- Produces: `bash tests/docs/docs-check.sh [--root DIR]` (all checks), `--page PAGE` (repeatable; per-page checks: sources, digest, structure, dollar amounts), `--digest PAGE` (prints PAGE's current 12-hex digest, exit 0). PAGE is relative to the repository root. Exit 0 with `docs-check: OK`, 1 with one `FAIL: <check>: ...` line per failure (`<check>` is one of `coverage`, `orphan`, `sources`, `digest`, `structure`, `index`, `dollar`), 2 on usage errors.

**Mirror:** `tests/claude-code/test-docs-allowlist.sh:1-35`, the header, temporary-root guard, `pass`/`fail` helpers, and git fixture.

- [ ] **Step 1: Write the fixture test `tests/docs/test-docs-check.sh`**

Create the directory first: `mkdir -p tests/docs`.

```bash
#!/usr/bin/env bash
# Proves tests/docs/docs-check.sh catches each defect the documentation spec
# names (docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md,
# "Drift checks") and passes a clean site. Each case builds a one-skill git
# repository, breaks one thing, and expects a FAIL line for that check.
#
# Fixture files are written with printf (heredocs under tests/ can deadlock
# on small macOS pipes). Text that must contain a dollar amount is assembled
# at run time from '$' and a digit, so no amount appears in this file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK="$SCRIPT_DIR/docs-check.sh"

failures=0
TEST_ROOT=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || { echo "no temporary directory" >&2; exit 1; }
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 1
case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) echo "refusing temporary root $TEST_ROOT" >&2; exit 1 ;; esac
cleanup() { case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) return ;; esac; rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] ${1}"; }
fail() { echo "  [FAIL] ${1}"; failures=$((failures + 1)); }

# edit SCRIPT FILE: in-place sed that works with BSD and GNU sed.
edit() { sed -i.bak "${1}" "${2}" && rm -f "${2}.bak"; }

# write_alpha_page DIR DIGEST [SOURCES]
write_alpha_page() {
  local dir="${1}" digest="${2}" sources="${3:-skills/alpha}"
  printf '%s\n' \
    '---' \
    "sources: $sources" \
    "source-digest: $digest" \
    '---' \
    '# alpha' '' 'Does one thing for you.' '' \
    '## When it triggers' '' 'When you test it.' '' \
    '## What it does' '' 'It runs.' '' \
    '## Why it exists' '' 'To be checked.' '' \
    '## Pros' '' '- It is small.' '' \
    '## Cons and costs' '' '- It does little.' '- It exists only for this test.' '' \
    '## Skipping or overriding' '' 'Ask.' '' \
    '## Works with' '' 'Nothing.' '' \
    '## Under the hood' '' 'One helper file.' \
    > "$dir/docs/site/skills/alpha.md"
}

# set_alpha_sources DIR SOURCES: rewrite the page with SOURCES and a matching digest.
set_alpha_sources() {
  local dir="${1}" sources="${2}" digest
  write_alpha_page "$dir" 000000000000 "$sources"
  digest="$(bash "$CHECK" --root "$dir" --digest docs/site/skills/alpha.md)"
  write_alpha_page "$dir" "$digest" "$sources"
}

# make_fixture NAME: print the path of a fresh, clean one-skill repository.
make_fixture() {
  local dir="$TEST_ROOT/${1}"
  mkdir -p "$dir/skills/alpha" "$dir/docs/site/skills" "$dir/docs/site/advanced"
  printf '%s\n' '---' 'name: alpha' 'description: Use when testing the docs check' '---' '# Alpha' > "$dir/skills/alpha/SKILL.md"
  printf 'helper\n' > "$dir/skills/alpha/helper.md"
  printf '%s\n' '# Skills' '' '| Skill | What it does |' '|---|---|' '| {doc}`alpha` | Does one thing. |' > "$dir/docs/site/skills/index.md"
  git init -q "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  git -C "$dir" add -A
  set_alpha_sources "$dir" skills/alpha
  git -C "$dir" add -A
  printf '%s\n' "$dir"
}

# expect_ok LABEL DIR [ARGS...]: the check exits 0.
expect_ok() {
  local label="${1}" dir="${2}" out status=0
  shift 2
  out="$(bash "$CHECK" --root "$dir" "$@" 2>&1)" || status=$?
  if [ "$status" -eq 0 ]; then
    pass "$label"
  else
    fail "$label (exit $status)"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
}

# expect_fail LABEL DIR TAG [ARGS...]: the check exits 1 and prints a line starting "FAIL: TAG".
expect_fail() {
  local label="${1}" dir="${2}" tag="${3}" out status=0 nl='
'
  shift 3
  out="$(bash "$CHECK" --root "$dir" "$@" 2>&1)" || status=$?
  case "$nl$out" in
    *"${nl}FAIL: $tag"*) matched=1 ;;
    *) matched=0 ;;
  esac
  if [ "$status" -eq 1 ] && [ "$matched" -eq 1 ]; then
    pass "$label"
  else
    fail "$label (exit $status, expected a line starting: FAIL: $tag)"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
}

echo "=== docs-check ==="

d="$(make_fixture clean)"
expect_ok "a clean one-skill site passes" "$d"
expect_ok "--page passes a clean skill page" "$d" --page docs/site/skills/alpha.md
digest="$(bash "$CHECK" --root "$d" --digest docs/site/skills/alpha.md)"
case "$digest" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) pass "--digest prints 12 hex digits" ;;
  *) fail "--digest output (got: $digest)" ;;
esac

d="$(make_fixture missing-page)"
rm "$d/docs/site/skills/alpha.md"
expect_fail "a skill without a page fails" "$d" "coverage: skills/alpha has no page"

d="$(make_fixture orphan)"
cp "$d/docs/site/skills/alpha.md" "$d/docs/site/skills/beta.md"
expect_fail "a page without a skill fails" "$d" "orphan: docs/site/skills/beta.md"

d="$(make_fixture no-sources)"
edit '/^sources:/d' "$d/docs/site/skills/alpha.md"
expect_fail "a skill page without sources fails" "$d" "sources: docs/site/skills/alpha.md needs"

d="$(make_fixture own-dir)"
set_alpha_sources "$d" skills/alpha/helper.md
expect_fail "a skill page whose sources omit its own directory fails" "$d" "sources: docs/site/skills/alpha.md must list skills/alpha"

d="$(make_fixture untracked-source)"
set_alpha_sources "$d" "skills/alpha nosuch/path"
expect_fail "a source that matches no tracked file fails" "$d" "sources: docs/site/skills/alpha.md lists nosuch/path"

d="$(make_fixture advanced-no-sources)"
printf '%s\n' '# Triggering' '' 'Text.' > "$d/docs/site/advanced/triggering.md"
expect_fail "an advanced page without sources fails" "$d" "sources: docs/site/advanced/triggering.md needs"

d="$(make_fixture stale-skill)"
printf 'changed\n' >> "$d/skills/alpha/SKILL.md"
expect_fail "editing SKILL.md fails the digest" "$d" "digest: docs/site/skills/alpha.md"

d="$(make_fixture stale-helper)"
printf 'changed\n' >> "$d/skills/alpha/helper.md"
expect_fail "editing only a supporting file fails the digest" "$d" "digest: docs/site/skills/alpha.md"

d="$(make_fixture new-helper)"
printf 'new\n' > "$d/skills/alpha/extra.md"
git -C "$d" add skills/alpha/extra.md
expect_fail "adding a tracked file under the skill fails the digest" "$d" "digest: docs/site/skills/alpha.md"

d="$(make_fixture untracked-scratch)"
printf 'scratch\n' > "$d/skills/alpha/scratch.tmp"
expect_ok "an untracked file under the skill leaves the digest alone" "$d"

d="$(make_fixture missing-heading)"
edit '/^## Pros$/d' "$d/docs/site/skills/alpha.md"
expect_fail "a missing template heading fails" "$d" "structure: docs/site/skills/alpha.md is missing \"## Pros\""

d="$(make_fixture reordered)"
edit 's/^## Why it exists$/## TMP/; s/^## Pros$/## Why it exists/; s/^## TMP$/## Pros/' "$d/docs/site/skills/alpha.md"
expect_fail "reordered template headings fail" "$d" "structure: docs/site/skills/alpha.md is missing"

d="$(make_fixture fenced-heading)"
edit 's/^## Pros$/```/; s/^- It is small\.$/## Pros/' "$d/docs/site/skills/alpha.md"
printf '%s\n' '```' >> "$d/docs/site/skills/alpha.md"
expect_fail "a heading inside a code fence does not count" "$d" "structure: docs/site/skills/alpha.md is missing \"## Pros\""

d="$(make_fixture one-con)"
edit '/^- It exists only for this test\.$/d' "$d/docs/site/skills/alpha.md"
expect_fail "a single cons item fails" "$d" "structure: docs/site/skills/alpha.md has 1 list item(s)"

d="$(make_fixture unlisted)"
edit '/{doc}`alpha`/d' "$d/docs/site/skills/index.md"
expect_fail "an index that does not link the skill fails" "$d" "index: docs/site/skills/index.md does not link alpha"

d="$(make_fixture amount)"
printf 'It costs %s5 a run.\n' '$' >> "$d/docs/site/skills/alpha.md"
expect_fail "a dollar amount in a page fails" "$d" "dollar: docs/site/skills/alpha.md"
expect_fail "--page also catches the amount" "$d" "dollar: docs/site/skills/alpha.md" --page docs/site/skills/alpha.md

d="$(make_fixture word)"
printf '%s\n' 'project = "priced in USD"' > "$d/docs/site/conf.py"
expect_fail "the word USD in any site file fails" "$d" "dollar: docs/site/conf.py"

d="$(make_fixture build-output)"
mkdir -p "$d/docs/site/_build"
printf 'USD\n' > "$d/docs/site/_build/page.html"
expect_ok "build output is not scanned" "$d"

echo
if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures"
  exit 1
fi
echo "All docs-check tests passed"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/docs/test-docs-check.sh`
Expected: FAIL (`tests/docs/docs-check.sh` does not exist; `make_fixture` cannot compute a digest).

- [ ] **Step 3: Write `tests/docs/docs-check.sh`**

```bash
#!/usr/bin/env bash
# Drift and content checks for the documentation site in docs/site/.
#
# A page that describes repository behavior lists those paths in a
# `sources:` front-matter line and records a `source-digest:` over them.
# When a listed skill, hook, or script changes, this check fails until
# someone re-reads the page and records the new digest. The rules are in
# docs/hyperpowers/specs/2026-11-05-readthedocs-site-design.md ("Drift
# checks").
#
# Usage:
#   docs-check.sh [--root DIR]                  all checks over the site
#   docs-check.sh [--root DIR] --page PAGE ...  per-page checks only
#   docs-check.sh [--root DIR] --digest PAGE    print PAGE's current digest
#
# PAGE is relative to the repository root, e.g.
# docs/site/skills/brainstorming.md. Exit 0 when every check passes, 1 when
# any fails (one "FAIL: <check>: ..." line each), 2 on a usage error.
#
# Positional parameters are written ${1} and awk's whole record $(0): this
# repository's pre-commit scan flags a dollar sign followed by a digit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SITE=docs/site
HEADINGS=(
  "## When it triggers"
  "## What it does"
  "## Why it exists"
  "## Pros"
  "## Cons and costs"
  "## Skipping or overriding"
  "## Works with"
  "## Under the hood"
)

failures=0
fail() { echo "FAIL: ${1}"; failures=$((failures + 1)); }

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    sha256sum | cut -d' ' -f1
  fi
}

# front_matter_value PAGE KEY: print KEY's value from PAGE's leading
# front-matter block, or nothing.
front_matter_value() {
  awk -v key="${2}:" '
    NR == 1 { if ($(0) != "---") exit; next }
    $(0) == "---" { exit }
    index($(0), key) == 1 {
      value = substr($(0), length(key) + 1)
      sub(/^[ \t]+/, "", value)
      sub(/[ \t]+$/, "", value)
      print value
      exit
    }
  ' "$ROOT/${1}"
}

# compute_digest PATH...: one "<sha256>  <path>" line per tracked file under
# the paths, paths sorted bytewise, each line ending in a newline; print the
# first 12 hex digits of the SHA-256 of those lines.
compute_digest() {
  (cd "$ROOT" && git ls-files -z -- "$@") \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' file; do
        [ -f "$ROOT/$file" ] || continue
        printf '%s  %s\n' "$(sha256_stdin < "$ROOT/$file")" "$file"
      done \
    | sha256_stdin | cut -c1-12
}

requires_sources() {
  case "${1}" in
    "$SITE/skills/index.md") return 1 ;;
    "$SITE"/skills/*.md | "$SITE"/advanced/*.md | "$SITE/recommended-settings.md") return 0 ;;
    *) return 1 ;;
  esac
}

is_skill_page() {
  case "${1}" in
    "$SITE/skills/index.md") return 1 ;;
    "$SITE"/skills/*.md) return 0 ;;
    *) return 1 ;;
  esac
}

check_structure() {
  local page="${1}" i=0 line cons
  while IFS= read -r line; do
    if [ "$i" -lt "${#HEADINGS[@]}" ] && [ "$line" = "${HEADINGS[$i]}" ]; then
      i=$((i + 1))
    fi
  done < <(awk '/^```/ { fence = !fence; next } !fence && /^## / { print }' "$ROOT/$page")
  if [ "$i" -lt "${#HEADINGS[@]}" ]; then
    fail "structure: $page is missing \"${HEADINGS[$i]}\" or has it out of order"
  fi
  cons="$(awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { in_cons = ($(0) == "## Cons and costs"); next }
    in_cons && /^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]/ { n++ }
    END { print n + 0 }
  ' "$ROOT/$page")"
  if [ "$cons" -lt 2 ]; then
    fail "structure: $page has $cons list item(s) under \"## Cons and costs\"; at least 2 are required"
  fi
}

# check_amounts FILE...: dollar amounts and the words for them.
check_amounts() {
  local file rel hit
  for file in "$@"; do
    rel="${file#"$ROOT"/}"
    while IFS= read -r hit; do
      if [ -n "$hit" ]; then
        fail "dollar: $rel:$hit"
      fi
    done < <(grep -n -I -E '\$[0-9]' "$file" || true; grep -n -I -i -w -E 'usd|dollars?' "$file" || true)
  done
}

check_page() {
  local page="${1}" sources digest expected path name
  if [ ! -f "$ROOT/$page" ]; then
    fail "coverage: $page does not exist"
    return
  fi
  sources="$(front_matter_value "$page" sources)"
  digest="$(front_matter_value "$page" source-digest)"
  if requires_sources "$page" && { [ -z "$sources" ] || [ -z "$digest" ]; }; then
    fail "sources: $page needs both a sources: and a source-digest: front-matter line"
  fi
  if [ -n "$sources" ]; then
    # shellcheck disable=SC2086 # sources is a space-separated path list by design
    set -- $sources
    for path in "$@"; do
      if [ -z "$(cd "$ROOT" && git ls-files -- "$path" | head -n 1)" ]; then
        fail "sources: $page lists $path, which matches no tracked file"
      fi
    done
    if is_skill_page "$page"; then
      name="$(basename "$page" .md)"
      case " $sources " in
        *" skills/$name "* | *" skills/$name/ "*) ;;
        *) fail "sources: $page must list skills/$name" ;;
      esac
    fi
    expected="$(compute_digest "$@")"
    if [ -n "$digest" ] && [ "$digest" != "$expected" ]; then
      fail "digest: $page records $digest but its sources ($sources) now give $expected; re-read the page against the changed sources, fix what is stale, then set source-digest: $expected"
    fi
  fi
  if is_skill_page "$page"; then
    check_structure "$page"
  fi
}

full_check() {
  local skill name page index="$ROOT/$SITE/skills/index.md" files=()
  if [ ! -f "$index" ]; then
    fail "index: $SITE/skills/index.md does not exist"
  fi
  for skill in "$ROOT"/skills/*/SKILL.md; do
    [ -f "$skill" ] || continue
    name="$(basename "$(dirname "$skill")")"
    if [ ! -f "$ROOT/$SITE/skills/$name.md" ]; then
      fail "coverage: skills/$name has no page $SITE/skills/$name.md"
    fi
    if [ -f "$index" ] && ! grep -qF -- "{doc}\`${name}\`" "$index"; then
      fail "index: $SITE/skills/index.md does not link $name (expected {doc}\`${name}\`)"
    fi
  done
  for page in "$ROOT/$SITE"/skills/*.md; do
    [ -f "$page" ] || continue
    name="$(basename "$page" .md)"
    if [ "$name" != index ] && [ ! -f "$ROOT/skills/$name/SKILL.md" ]; then
      fail "orphan: $SITE/skills/$name.md has no skills/$name/SKILL.md"
    fi
  done
  while IFS= read -r -d '' page; do
    case "$page" in
      *.md) check_page "${page#"$ROOT"/}" ;;
    esac
    files+=("$page")
  done < <(find "$ROOT/$SITE" -path "$ROOT/$SITE/_build" -prune -o -type f -print0)
  if [ "${#files[@]}" -gt 0 ]; then
    check_amounts "${files[@]}"
  fi
}

mode=full
pages=()
while [ "$#" -gt 0 ]; do
  case "${1}" in
    --root)
      [ "$#" -ge 2 ] || { echo "docs-check: --root needs a directory" >&2; exit 2; }
      ROOT="$(cd "${2}" && pwd)"
      shift 2
      ;;
    --page)
      [ "$#" -ge 2 ] || { echo "docs-check: --page needs a path" >&2; exit 2; }
      mode=page
      pages+=("${2}")
      shift 2
      ;;
    --digest)
      [ "$#" -ge 2 ] || { echo "docs-check: --digest needs a path" >&2; exit 2; }
      mode=digest
      pages=("${2}")
      shift 2
      ;;
    *)
      echo "docs-check: unknown argument ${1}" >&2
      exit 2
      ;;
  esac
done

case "$mode" in
  digest)
    page="${pages[0]}"
    [ -f "$ROOT/$page" ] || { echo "docs-check: $page does not exist" >&2; exit 2; }
    sources="$(front_matter_value "$page" sources)"
    [ -n "$sources" ] || { echo "docs-check: $page has no sources: line" >&2; exit 2; }
    # shellcheck disable=SC2086 # sources is a space-separated path list by design
    compute_digest $sources
    exit 0
    ;;
  page)
    for page in "${pages[@]}"; do
      check_page "$page"
      if [ -f "$ROOT/$page" ]; then
        check_amounts "$ROOT/$page"
      fi
    done
    ;;
  full)
    full_check
    ;;
esac

if [ "$failures" -gt 0 ]; then
  echo "docs-check: $failures failure(s)"
  exit 1
fi
echo "docs-check: OK"
```

- [ ] **Step 4: Run the fixture test to verify it passes**

Run: `bash tests/docs/test-docs-check.sh`
Expected: every case `[PASS]`, last line `All docs-check tests passed`. Also run it with macOS's bash 3.2: `/bin/bash tests/docs/test-docs-check.sh`, same expectation.

- [ ] **Step 5: Lint**

Run: `bash scripts/lint-shell.sh tests/docs/docs-check.sh tests/docs/test-docs-check.sh` and `bash tests/hooks/test-no-heredocs-in-hooks.sh`
Expected: both clean.

- [ ] **Step 6: Wire the suite into the offline runner**

In `tests/run-offline.sh`, add `tests/docs/test-*.sh` to the first `for t in ...` list (line 20), after `tests/shell-lint/test-*.sh`. Then confirm the glob picks up only the fixture test for now: `ls tests/docs/test-*.sh` prints `tests/docs/test-docs-check.sh`.

- [ ] **Step 7: Document the suite and the site build in `docs/testing.md`**

Add this row to the table, after the `tests/shell-lint/` row:

```markdown
| `tests/docs/` | the documentation site: every skill has a page, the skills index links it, each page's `source-digest` matches its `sources`, skill pages keep the template, no dollar amounts; plus the checker's own fixture test | each `test-*.sh`, one per `bash` call |
```

Add this section before `## Skill behavior evals`:

````markdown
## Building the docs

The Read the Docs site lives in `docs/site/` (Sphinx, the Lumina theme,
MyST). Build it, and check its external links, with pinned dependencies in
an ephemeral environment:

```bash
uv run --python 3.13 --with-requirements docs/site/requirements.txt \
  sphinx-build -W --keep-going docs/site docs/site/_build/html
uv run --python 3.13 --with-requirements docs/site/requirements.txt \
  sphinx-build -b linkcheck docs/site docs/site/_build/linkcheck
```

`bash tests/docs/docs-check.sh --digest <page>` prints the digest a page's
`source-digest:` should hold after its sources change.
````

- [ ] **Step 8: Add the contributor rule to `CLAUDE.md`**

Append this bullet to the list under "## Making Changes in This Fork":

```markdown
- A change to a skill, hook, or script that a page under `docs/site/` lists in its `sources:` front matter also re-reads that page, fixes what is stale, and updates its `source-digest:` (`bash tests/docs/docs-check.sh --digest <page>` prints the new value).
```

- [ ] **Step 9: Commit**

Stage, scan, and commit:

```bash
git add tests/docs/docs-check.sh tests/docs/test-docs-check.sh tests/run-offline.sh docs/testing.md CLAUDE.md
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "test(docs): drift and content checker for the documentation site" | grep -cE '\$[0-9]'
git commit -m "test(docs): drift and content checker for the documentation site"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

## Writing a skill page (applies to Tasks 3-6)

Each skill page task follows the same procedure for each of its skills. Read it once; the per-task tables below give the skill-specific content.

1. Invoke hyperpowers:communication.
2. Run `bash tests/docs/docs-check.sh --page docs/site/skills/<name>.md` and confirm it fails with `coverage:` (the page does not exist yet).
3. Read every file under `skills/<name>/` (`git ls-files skills/<name>`), the decision records the index (`docs/hyperpowers/decisions/README.md`) lists for that skill's area, and the README's line for the skill.
4. Write `docs/site/skills/<name>.md` with exactly this skeleton (front matter first; the card uses sphinx-design's `card` directive through MyST's colon fence):

````markdown
---
sources: skills/<name>
source-digest: 000000000000
---
# <name>

<One sentence: what the skill does for you.>

:::{card} At a glance
**Category:** <category> · **Triggers on:** <short trigger> · **Hands off to:** <skills> · **Harness notes:** <for example "Codex gate: Claude Code only", or "none">
:::

## When it triggers

## What it does

## Why it exists

## Pros

## Cons and costs

## Skipping or overriding

## Works with

## Under the hood
````

   Fill each section per the spec's "Skill page template": "When it triggers" restates the frontmatter `description` in plain words and gives two or three example requests; "What it does" walks the process as the reader sees it; "Why it exists" names the failure it prevents and links decision records where they exist (`{source}` role, e.g. `` {source}`docs/hyperpowers/decisions/README.md` ``); "Pros" and "Cons and costs" are bullet lists, at least two concrete cons; "Skipping or overriding" says what to tell the agent and when that is reasonable; "Works with" links the skills it hands to and receives from with `{doc}` (e.g. `` {doc}`writing-plans` ``), and every link must match a hand-off the skill text actually makes; "Under the hood" lists supporting files and scripts with `{source}` links. If a page describes a path outside `skills/<name>` (for example `hooks/session-start`), add it to `sources`.
5. Record the digest: `bash tests/docs/docs-check.sh --digest docs/site/skills/<name>.md`, then put that value in `source-digest:`.
6. Add the skill in two places: a row in its category's table in `docs/site/skills/index.md`, linked as `` {doc}`<name>` `` (Task 3 creates the file and shows the layout), and `skills/<name>` on its own line in its category's toctree in `docs/site/index.md` (`Process skills`, `Testing skills`, and so on). A page left out of every toctree fails the `-W` build.
7. Run `bash tests/docs/docs-check.sh --page docs/site/skills/<name>.md` and expect `docs-check: OK`.

After all pages in the task: run the build command (exit 0), then stage, scan, and commit as the task's commit block shows. The task review takes each page separately: its claims against that page's own `sources`, and the per-page list in Task 11 Step 7 (example requests, concrete cons, "Works with" links matching real hand-offs, a complete at-a-glance card).

---

### Task 3: Skills index and the planning and execution pages

**Risk tier:** standard — behavior claims about four core skills plus the index layout every later task extends.

**Files:**
- Create: `docs/site/skills/index.md`
- Create: `docs/site/skills/brainstorming.md`, `docs/site/skills/writing-plans.md`, `docs/site/skills/executing-plans.md`, `docs/site/skills/subagent-driven-development.md`
- Modify: `docs/site/index.md` (`Skills` and `Process skills` toctree entries)

**Interfaces:**
- Consumes: `{source}` role and the ten toctrees in `index.md` (Task 1); `docs-check.sh --page/--digest` (Task 2).
- Produces: `docs/site/skills/index.md` with one `##` section and table per category, in the order Process, Testing, Debugging, Review, Performance, Meta, each row linking its page as `` {doc}`<name>` ``. Tasks 4-6 add rows and sections. `skills/index.md` holds no toctree: the category toctrees are in `docs/site/index.md` (Grounding explains why).

- [ ] **Step 1: Write `docs/site/skills/index.md`**

Create the directory first: `mkdir -p docs/site/skills`.

Layout (a category's section appears with its first page; Testing through Meta arrive in Tasks 5 and 6):

````markdown
# Skills

<Two sentences: skills trigger automatically from their descriptions; this page lists them by category.>

## Process

| Skill | What it does | Triggers when |
|---|---|---|
| {doc}`brainstorming` | <one line> | <one line> |
````

In `docs/site/index.md`, add `skills/index` as the only entry in the `Skills` toctree, and the four pages (`skills/brainstorming`, `skills/writing-plans`, `skills/executing-plans`, `skills/subagent-driven-development`) to the `Process skills` toctree in that order.

- [ ] **Step 2: Write the four pages** following "Writing a skill page".

| Skill | Category | Must cover (verify each against the skill text) | Works with |
|---|---|---|---|
| brainstorming | Process | Classifies every request as spike, bounded, or architectural and says the classification aloud; approval before any implementation on every path; one question per message; comparison in chat before a choice ("Deciding Together"); the visual companion opened only for visual questions (browser, token-intensive); the optional Codex approach consultation (Claude Code); architectural path writes a spec with a Decisions section to `docs/hyperpowers/specs/`, self-reviews it, runs the Codex spec review, then asks the reader to review it; re-reads its full text after compaction | using-hyperpowers (triggers it), writing-plans, communication, requesting-code-review (spec review) |
| writing-plans | Process | Plans written for an implementer with no context; bite-sized steps; header, Global Constraints, Grounding with real citations; risk tiers (low, standard, high) that set whether the per-task Codex review runs; no placeholders; self-review; Codex plan review; hands off to subagent-driven-development by default | brainstorming, subagent-driven-development, executing-plans, requesting-code-review |
| executing-plans | Process | Executes a plan in the current session in batches with checkpoints; stops and asks when blocked; the alternative when subagents are unavailable or the reader asks for inline execution | writing-plans, test-driven-development, finishing-a-development-branch |
| subagent-driven-development | Process | A fresh implementer subagent per task; a task review returning a spec verdict and a quality verdict; the fix loop and its cap; per-task Codex review set by risk tier; final whole-branch review; finish; model selection per role (`model-selection.md`); the SDD workspace and ledger; re-read after compaction | writing-plans, using-git-worktrees, test-driven-development, requesting-code-review, finishing-a-development-branch |

- [ ] **Step 3: Build, check, commit**

Run the build command (exit 0). Run `bash tests/docs/docs-check.sh --page` once per new skill page (all `docs-check: OK`). Stage, scan, and commit:

```bash
git add docs/site/index.md docs/site/skills/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): skills index and the planning and execution skill pages" | grep -cE '\$[0-9]'
git commit -m "docs(site): skills index and the planning and execution skill pages"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 4: Workflow-support pages

**Risk tier:** standard — behavior claims about four skills.

**Files:**
- Create: `docs/site/skills/dispatching-parallel-agents.md`, `docs/site/skills/using-git-worktrees.md`, `docs/site/skills/finishing-a-development-branch.md`, `docs/site/skills/communication.md`
- Modify: `docs/site/skills/index.md` (Process rows)
- Modify: `docs/site/index.md` (`Process skills` toctree entries, after Task 3's)

**Interfaces:**
- Consumes: `docs/site/skills/index.md` layout (Task 3); the category toctrees in `docs/site/index.md` (Task 1); `docs-check.sh` (Task 2).

- [ ] **Step 1: Write the four pages** following "Writing a skill page".

| Skill | Category | Must cover (verify each against the skill text) | Works with |
|---|---|---|---|
| dispatching-parallel-agents | Process | Identify independent domains; one focused prompt per agent; dispatch concurrently; review and integrate; when not to use (shared state, sequential dependencies) | subagent-driven-development, systematic-debugging |
| using-git-worktrees | Process | Detects existing isolation first; prefers the harness's native worktree tools, falls back to `git worktree`; asks where the work happens; runs project setup; verifies a clean test baseline before work starts | brainstorming, subagent-driven-development, executing-plans, finishing-a-development-branch |
| finishing-a-development-branch | Process | Compiles the spec's decisions into records (`scripts/decisions-compile`) and verifies tests; detects the environment and base branch; presents merge, pull request, keep, or discard; executes the choice and cleans up the worktree; removes the plan from the tree in the records commit | subagent-driven-development, executing-plans, using-git-worktrees |
| communication | Process | For prose a person reads: answer first, only what the reader lacks, name the specific thing, state what is true; the jargon table, the "not X but Y" rule, the check-before-sending table; editing others' text; when not to act | brainstorming, writing-plans, using-hyperpowers |

Note: `finishing-a-development-branch` describes `skills/finishing-a-development-branch/scripts/decisions-compile`, which is inside its own directory, so `sources: skills/finishing-a-development-branch` covers it.

- [ ] **Step 2: Build, check, commit**

Run the build command (exit 0) and `bash tests/docs/docs-check.sh --page` for each new page. Then stage, scan, and commit:

```bash
git add docs/site/index.md docs/site/skills/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): parallel agents, worktrees, finishing, and communication pages" | grep -cE '\$[0-9]'
git commit -m "docs(site): parallel agents, worktrees, finishing, and communication pages"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 5: Testing, debugging, and review pages

**Risk tier:** standard — behavior claims about four skills.

**Files:**
- Create: `docs/site/skills/test-driven-development.md`, `docs/site/skills/systematic-debugging.md`, `docs/site/skills/requesting-code-review.md`, `docs/site/skills/receiving-code-review.md`
- Modify: `docs/site/skills/index.md` (Testing, Debugging, and Review sections and rows)
- Modify: `docs/site/index.md` (`Testing skills`, `Debugging skills`, and `Review skills` toctree entries)

**Interfaces:**
- Consumes: `docs/site/skills/index.md` layout (Task 3); the category toctrees in `docs/site/index.md` (Task 1); `docs-check.sh` (Task 2).

- [ ] **Step 1: Write the four pages** following "Writing a skill page".

| Skill | Category | Must cover (verify each against the skill text) | Works with |
|---|---|---|---|
| test-driven-development | Testing | The iron law (no production code without a failing test first); red, green, refactor, watching each test fail and pass; code written before its test is deleted; good-test guidance; the verification checklist | subagent-driven-development, executing-plans, systematic-debugging |
| systematic-debugging | Debugging | No fix without a root cause; the four phases (root cause investigation, pattern analysis, hypothesis and testing, implementation); the supporting techniques files in the skill directory; what to do after repeated failed fixes | test-driven-development, dispatching-parallel-agents |
| requesting-code-review | Review | When to request review; choosing the base (never `HEAD~1` for a multi-commit change); the code-reviewer subagent; the optional Codex review (Claude Code only, degrades with a one-line notice when absent); severity mapping and what blocks | subagent-driven-development, brainstorming (spec review), writing-plans (plan review), receiving-code-review |
| receiving-code-review | Review | Verify feedback before acting; no performative agreement; push back with evidence; the YAGNI check for "professional" additions; handling feedback from the reader versus external reviewers; implementation order | requesting-code-review |

- [ ] **Step 2: Build, check, commit**

Run the build command (exit 0) and `bash tests/docs/docs-check.sh --page` for each new page. Then stage, scan, and commit:

```bash
git add docs/site/index.md docs/site/skills/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): testing, debugging, and code review pages" | grep -cE '\$[0-9]'
git commit -m "docs(site): testing, debugging, and code review pages"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 6: Performance and meta pages

**Risk tier:** standard — behavior claims about four skills.

**Files:**
- Create: `docs/site/skills/profiling-performance.md`, `docs/site/skills/optimizing-performance.md`, `docs/site/skills/using-hyperpowers.md`, `docs/site/skills/writing-skills.md`
- Modify: `docs/site/skills/index.md` (Performance and Meta sections and rows)
- Modify: `docs/site/index.md` (`Performance skills` and `Meta skills` toctree entries)

**Interfaces:**
- Consumes: `docs/site/skills/index.md` layout (Task 3); the category toctrees in `docs/site/index.md` (Task 1); `docs-check.sh` (Task 2).
- Produces: all sixteen skill pages, so `bash tests/docs/docs-check.sh` (full mode) passes its coverage and index checks from here on.

- [ ] **Step 1: Write the four pages** following "Writing a skill page".

| Skill | Category | Must cover (verify each against the skill text) | Works with |
|---|---|---|---|
| profiling-performance | Performance | A correctness baseline first; measure and find the real bottleneck; rank candidates by payoff (algorithm, data layout, platform, I/O, concurrency, micro-level); reconcile against the bound; the language packs (C++, Python, JS); no rewrite without measured evidence | optimizing-performance, systematic-debugging |
| optimizing-performance | Performance | No measurement, no empirical optimization; the hybrid workflow (subagent-driven batch plus bounded re-profiling); keep, revert, and tie-break rules; honesty rules; the final report | profiling-performance, subagent-driven-development, requesting-code-review |
| using-hyperpowers | Meta | Injected at session start by the hook (`hooks/session-start`); invoke a skill before any response when it might apply; process skills before implementation skills; the red-flags table; platform reference files; user instructions take precedence | every skill; brainstorming, systematic-debugging, and communication by name |
| writing-skills | Meta | Writing skills as test-driven work: a baseline without the skill, then with it, then closing loopholes; pressure scenarios; `SKILL.md` structure; the description states triggering conditions only; testing with subagents; skill changes need eval evidence | test-driven-development, using-hyperpowers |

`using-hyperpowers` describes `hooks/session-start`, so its front matter is `sources: skills/using-hyperpowers hooks/session-start`.

- [ ] **Step 2: Build, check, commit**

Run the build command (exit 0), then the full check `bash tests/docs/docs-check.sh` and expect `docs-check: OK` (all sixteen skills covered and listed). Stage, scan, and commit:

```bash
git add docs/site/index.md docs/site/skills/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): performance and meta skill pages" | grep -cE '\$[0-9]'
git commit -m "docs(site): performance and meta skill pages"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 7: Guide and About pages

**Risk tier:** standard — five narrative pages, including the workflow diagram.

**Files:**
- Create: `docs/site/why.md`, `docs/site/install.md`, `docs/site/first-session.md`, `docs/site/workflow.md`, `docs/site/superpowers.md`
- Modify: `docs/site/index.md` (Guide and About toctree entries)

**Interfaces:**
- Consumes: skill pages (Tasks 3-6) for `{doc}` links such as `` {doc}`skills/brainstorming` ``.

- [ ] **Step 1: Write the pages.** Invoke hyperpowers:communication first. Content, each verified against the cited sources:

| Page | Content | Sources to read |
|---|---|---|
| `why.md` | How coding agents fail without a method: code before design, tests after code, "done" without evidence. Skills as behavior-shaping text that is tested like code. Auto-triggering through descriptions and the bootstrap. What the cost is: more questions and more tokens up front | `README.md:13-24`, `skills/using-hyperpowers/SKILL.md`, `skills/writing-skills/SKILL.md` |
| `install.md` | One short subsection per harness (Claude Code, Codex, Cursor, Antigravity, Factory Droid, GitHub Copilot CLI, Kimi Code, OpenCode, Pi, Claude Desktop/claude.ai) with the install command or method, then a support table (harness, install method, session-start bootstrap, Codex review gates). Claude Code's optional codex-plugin-cc prerequisite. Link the README for full detail | `README.md:25-158`, `docs/README.opencode.md`, `docs/README.kimi.md` |
| `first-session.md` | One session from "Let's make a react todo list": brainstorming classifies and asks questions, the design is approved, a plan is written, subagent-driven development runs tasks with reviews, the branch is finished. Labeled illustrative at the top; describes what happens, quotes no invented transcript output | `skills/brainstorming/SKILL.md`, `skills/writing-plans/SKILL.md`, `skills/subagent-driven-development/SKILL.md`, `skills/finishing-a-development-branch/SKILL.md` |
| `workflow.md` | The lifecycle as a Mermaid diagram (below), the three paths and what each produces, a table of which skill takes over at each step | `README.md:160-176`, `skills/brainstorming/SKILL.md` |
| `superpowers.md` | Relationship to upstream: what Superpowers is, that the methodology and most skill design are upstream's, that the agent-facing word "superpowers" is kept on purpose, what this fork adds (Codex review gates, decision records, the communication and performance skills, the re-read after compaction, the SDD workspace), how the fork tracks upstream; credits to Jesse Vincent and Prime Radiant | `README.md:1-12`, `README.md:239-291`, `README.md:300-304`, `CLAUDE.md:1-20` |

The diagram in `workflow.md`:

````markdown
```{mermaid}
flowchart LR
  A[Request] --> B{brainstorming:<br/>classify}
  B -->|spike| C[Answer, nothing kept]
  B -->|bounded| D[Short design in chat] --> G[Implement with TDD]
  B -->|architectural| E[Spec] --> F[writing-plans] --> H[subagent-driven-development]
  H --> I[finishing-a-development-branch]
  G --> I
```
````

Add `why`, `install`, `first-session`, `workflow` (in that order) to the `Guide` toctree of `docs/site/index.md`, and `superpowers` to the `About` toctree.

- [ ] **Step 2: Build, check, commit**

Run the build command (exit 0) and `bash tests/docs/docs-check.sh` (expect `docs-check: OK`). Stage, scan, and commit:

```bash
git add docs/site/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): guide pages, workflow diagram, and the upstream page" | grep -cE '\$[0-9]'
git commit -m "docs(site): guide pages, workflow diagram, and the upstream page"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 8: Advanced pages on triggering, Codex reviews, and SDD internals

**Risk tier:** standard — mechanism descriptions of gate and SDD scripts.

**Files:**
- Create: `docs/site/advanced/triggering.md`, `docs/site/advanced/codex-gates.md`, `docs/site/advanced/sdd-internals.md`
- Modify: `docs/site/index.md` (Advanced toctree entries)

**Interfaces:**
- Consumes: `docs-check.sh --page/--digest` (Task 2); skill pages for `{doc}` links.

- [ ] **Step 1: Write the pages.** Create the directory first: `mkdir -p docs/site/advanced`. Invoke hyperpowers:communication first. Each page starts with front matter `sources:` (below) and `source-digest:`, set with `bash tests/docs/docs-check.sh --digest <page>`. Every claim is checked against the listed sources.

| Page | Content | `sources:` |
|---|---|---|
| `advanced/triggering.md` | How skills load: each harness puts the `using-hyperpowers` bootstrap into the session at start, by its own mechanism (read each one): the session-start hooks in `hooks/` (Claude Code, Codex, Cursor), the OpenCode plugin (`.opencode/plugins/hyperpowers.js`), the Pi extension (`.pi/extensions/hyperpowers.ts`), and Kimi's manifest `sessionStart.skill` (`.kimi-plugin/plugin.json`). Then: skill descriptions decide when a skill fires, the priority rules, and what happens after compaction. Because vrzn rewrites the version field of `.kimi-plugin/plugin.json` on every release, a release flags this page; the re-read is expected | `skills/using-hyperpowers hooks .opencode/plugins .pi/extensions .kimi-plugin/plugin.json` |
| `advanced/codex-gates.md` | The optional Codex reviews: the approach consultation in brainstorming, the spec and plan reviews (two lenses in round one, re-review rounds with a ledger, a four-round ceiling), the code reviews (per task by risk tier, final whole-branch), `verdict-normalize` as the only approval authority, incomplete is not approval, how skills behave without Codex (a one-line notice, then continue), why companion commands run outside the Bash sandbox | `skills/requesting-code-review skills/brainstorming/codex-approach-gate.md skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/subagent-driven-development/SKILL.md` |
| `advanced/sdd-internals.md` | The SDD workspace (`sdd-dir`, `sdd-state`, the state branch), the ledger, task briefs and review packages, risk tiers, model selection per role, the fix-loop cap, the re-read after compaction | `skills/subagent-driven-development` |

Add `advanced/triggering`, `advanced/codex-gates`, `advanced/sdd-internals` to the `Advanced` toctree.

- [ ] **Step 2: Build, check, commit**

Run the build command (exit 0) and `bash tests/docs/docs-check.sh` (expect `docs-check: OK`). Stage, scan, and commit:

```bash
git add docs/site/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): advanced pages on triggering, Codex reviews, and SDD internals" | grep -cE '\$[0-9]'
git commit -m "docs(site): advanced pages on triggering, Codex reviews, and SDD internals"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 9: Advanced pages on decision records, testing skills, and customizing

**Risk tier:** standard — mechanism descriptions and the testing-method page.

**Files:**
- Create: `docs/site/advanced/decision-records.md`, `docs/site/advanced/testing-skills.md`, `docs/site/advanced/customizing.md`
- Modify: `docs/site/index.md` (Advanced toctree entries)

**Interfaces:**
- Consumes: `docs-check.sh --page/--digest` (Task 2).

- [ ] **Step 1: Write the pages.** Invoke hyperpowers:communication first. Each page starts with front matter `sources:` (below) and `source-digest:`, set with `bash tests/docs/docs-check.sh --digest <page>`. Every claim is checked against the listed sources.

| Page | Content | `sources:` |
|---|---|---|
| `advanced/decision-records.md` | A spec's Decisions section, compiled at branch finish into one record per decision under `decisions/` beside the specs, the generated index, supersession, the plan leaving the tree in the records commit, the spec frozen with an Outcome line; link the index with `{source}` | `skills/finishing-a-development-branch skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md` |
| `advanced/testing-skills.md` | How skills are tested, method only, no per-release numbers: the offline plugin tests in `tests/`; skill-behavior evals in the separate hyperpowers-evals repository (real agent sessions judged for compliance); pressure scenarios; baseline-versus-treatment comparison; why a skill change needs evidence | `skills/writing-skills docs/testing.md` |
| `advanced/customizing.md` | Changing or adding a skill in your own fork: use writing-skills, test before and after, keep the description to triggering conditions, update the matching docs page and its `source-digest` (the contributor rule Task 2 added to `CLAUDE.md`) | `skills/writing-skills CLAUDE.md` |

Add `advanced/decision-records`, `advanced/testing-skills`, `advanced/customizing` to the `Advanced` toctree after Task 8's entries.

- [ ] **Step 2: Build, check, commit**

Run the build command (exit 0) and `bash tests/docs/docs-check.sh` (expect `docs-check: OK`). Stage, scan, and commit:

```bash
git add docs/site/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): advanced pages on decision records, testing skills, and customizing" | grep -cE '\$[0-9]'
git commit -m "docs(site): advanced pages on decision records, testing skills, and customizing"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 10: Recommended settings page

**Risk tier:** standard — quantitative claims that must match the evidence exactly.

**Files:**
- Create: `docs/site/recommended-settings.md`
- Modify: `docs/site/index.md` (Guide toctree entry after `workflow`)

**Interfaces:**
- Consumes: `docs-check.sh --page/--digest` (Task 2).

- [ ] **Step 1: Write the page.** The three setting names are checked in Grounding. Invoke hyperpowers:communication first. Front matter (the README and the cost-evidence note hold the page's numbers, so they are sources too):

```markdown
---
sources: README.md docs/hyperpowers/2026-11-03-cost-reduction-6-16-2-eval-evidence.md skills/brainstorming/SKILL.md skills/subagent-driven-development/SKILL.md skills/writing-skills/SKILL.md
source-digest: 000000000000
---
```

Content, in order (the only numbers allowed are the ones written here):

1. `# Recommended settings`, then one sentence: these tips apply to Claude Code.
2. Why sessions cost what they do: each model call re-sends the whole conversation, so in long sessions most of the cost is reading and writing cached context, and cost tracks context size times the number of calls.
3. Tip 1, lower the auto-compact window to 400K: the JSON snippet `{"autoCompactWindow": 400000}` for `~/.claude/settings.json`, and the environment variable `CLAUDE_CODE_AUTO_COMPACT_WINDOW` as the alternative. On 1M-token models compaction otherwise waits until about 968K. In a replay of a month of long sessions, 400K cut cost by about 28%; 300K or 200K saved only 4 or 7 points more while compacting 1.5 or 2.6 times as often. Quality: after a compaction Claude Code re-attaches only the first 20,000 characters of each skill; brainstorming and subagent-driven-development, the two long skills most sessions run, tell the agent to re-read their full text after every compaction; in testing at a forced 100K window, where compactions come far more often than at 400K, agents re-read after 98% (subagent-driven-development) and 100% (brainstorming) of compactions; the 400K window itself was not measured, and it leaves about 300K of free context after each compaction; writing-skills is also longer than the re-attached copy and does not yet carry the instruction. Do not go below about 200K, where a session can compact again right after the re-read.
4. Tip 2, keep one-hour prompt caching: if `ENABLE_PROMPT_CACHING_1H=1` is set, leave it. Sessions pause for five to sixty minutes while subagents and reviews run; with a five-minute cache each such pause rewrites the whole context. The same replay cost about 56% more with five-minute caching.
5. Tip 3, run `/clear` between planning and execution: the spec and plan are on disk, so subagent-driven development starts from a small context.
6. Closing note: these settings change token volume; how that shows up depends on your plan (per-token billing or subscription usage limits).

Leave out model choice and model aliases, Codex review overhead, and idle compaction. Name no organization and no person whose sessions were replayed.

Record the digest with `bash tests/docs/docs-check.sh --digest docs/site/recommended-settings.md`. Add `recommended-settings` to the `Guide` toctree after `workflow`.

- [ ] **Step 2: Build, check, commit**

Run the build command (exit 0) and `bash tests/docs/docs-check.sh` (expect `docs-check: OK`). Stage, scan, and commit:

```bash
git add docs/site/
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "docs(site): recommended settings for Claude Code" | grep -cE '\$[0-9]'
git commit -m "docs(site): recommended settings for Claude Code"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

---

### Task 11: Site check in the offline set, home-page links, and whole-site verification

**Risk tier:** high — adds the suite the offline runner trusts for the whole site, and runs the final verification.

**Files:**
- Create: `tests/docs/test-docs-skills.sh`
- Modify: `docs/site/index.md` ("Where to start" links)

**Interfaces:**
- Consumes: `docs-check.sh` and the runner glob `tests/docs/test-*.sh` (Task 2); every page (Tasks 3-10).

- [ ] **Step 1: Write `tests/docs/test-docs-skills.sh`**

```bash
#!/usr/bin/env bash
# Runs the documentation drift and content checks over this repository's
# docs/site/. The rules live in tests/docs/docs-check.sh; its fixture test
# is tests/docs/test-docs-check.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== docs-check over docs/site ==="
bash "$SCRIPT_DIR/docs-check.sh"
```

Run: `bash tests/docs/test-docs-skills.sh`
Expected: `docs-check: OK`. The runner glob added in Task 2 picks this file up with no runner edit.

- [ ] **Step 2: Turn the home page's "Where to start" bullets into links**

In `docs/site/index.md`, link the three bullets with `{doc}`: `why` (new reader), `skills/index` (choosing skills), `recommended-settings` (cost). Link `install` from the harness sentence.

- [ ] **Step 3: Run the offline set and lint**

A fresh worktree has no `tests/brainstorm-server/node_modules` (ignored by `.gitignore`), and the offline runner's brainstorm-server suite needs it. Install it first:

```bash
(cd tests/brainstorm-server && npm ci)
```

If the Bash sandbox blocks the npm registry, re-run with `registry.npmjs.org` as an allowed domain. Then:

Run: `bash tests/run-offline.sh`
Expected: `offline set: 0 failed`. If the brainstorm-server suite is the only failure and its log shows a sandbox denial, re-run the offline set outside the sandbox and report which run passed.

Run: `ruff check docs/site/conf.py` and `mypy docs/site/conf.py`
Expected: both clean.

Run: `bash tests/shell-lint/test-lint-shell.sh`
Expected: pass.

- [ ] **Step 4: Build, link check, version-aware links**

Run the build command (exit 0). Then the link check:

```bash
uv run --python 3.13 --with-requirements docs/site/requirements.txt sphinx-build -b linkcheck docs/site docs/site/_build/linkcheck
grep -c 'broken' docs/site/_build/linkcheck/output.txt
```

Expected: the count is 0 (redirects are acceptable). Then build with a test ref and confirm a skill page's `{source}` links and edit link use it:

```bash
READTHEDOCS_GIT_IDENTIFIER=v0.0.0-test uv run --python 3.13 --with-requirements docs/site/requirements.txt sphinx-build -W --keep-going docs/site "$TMPDIR/hp-docs-ref"
grep -c 'blob/v0.0.0-test/skills/brainstorming' "$TMPDIR/hp-docs-ref/skills/brainstorming.html"
grep -c 'edit/v0.0.0-test/docs/site/skills/brainstorming.md' "$TMPDIR/hp-docs-ref/skills/brainstorming.html"
```

Expected: both counts at least 1.

- [ ] **Step 5: Render and inspect**

Assumption: headless Chrome renders the local files, Mermaid's script loads from its CDN within the time budget, and `--force-dark-mode` switches the theme's automatic mode to dark, validate with the two `workflow` probes below before the remaining screenshots. If Chrome cannot run inside the Bash sandbox, re-run the same commands with the sandbox disabled (they write only under `$TMPDIR`). If dark mode does not switch or the diagram does not render, report that and inspect what did render.

Probe first, and read both PNGs:

```bash
CHROME=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
  if [ -x "$c" ]; then CHROME="$c"; break; fi
done
[ -n "$CHROME" ] || { echo "Google Chrome not found in /Applications or ~/Applications" >&2; exit 1; }
OUT="$TMPDIR/hp-docs-shots"; mkdir -p "$OUT"
"$CHROME" --headless=new --user-data-dir="$TMPDIR/hp-chrome" --virtual-time-budget=8000 --window-size=1280,1800 --screenshot="$OUT/workflow-light.png" "file://$PWD/docs/site/_build/html/workflow.html"
"$CHROME" --headless=new --user-data-dir="$TMPDIR/hp-chrome" --virtual-time-budget=8000 --force-dark-mode --window-size=1280,1800 --screenshot="$OUT/workflow-dark.png" "file://$PWD/docs/site/_build/html/workflow.html"
```

Then the rest, with the flags the probe confirmed (the first lines repeat the probe's setup, because separate shell calls do not share variables):

```bash
CHROME=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
  if [ -x "$c" ]; then CHROME="$c"; break; fi
done
[ -n "$CHROME" ] || { echo "Google Chrome not found in /Applications or ~/Applications" >&2; exit 1; }
OUT="$TMPDIR/hp-docs-shots"
for p in index skills/brainstorming recommended-settings; do
  n=$(printf '%s' "$p" | tr '/' '-')
  "$CHROME" --headless=new --user-data-dir="$TMPDIR/hp-chrome" --virtual-time-budget=8000 --window-size=1280,1800 --screenshot="$OUT/$n-light.png" "file://$PWD/docs/site/_build/html/$p.html"
  "$CHROME" --headless=new --user-data-dir="$TMPDIR/hp-chrome" --virtual-time-budget=8000 --force-dark-mode --window-size=1280,1800 --screenshot="$OUT/$n-dark.png" "file://$PWD/docs/site/_build/html/$p.html"
done
```

Read each PNG and check: the sidebar shows the Guide, Skills, six skill-category, Advanced, and About captions; the at-a-glance card renders on the skill page; the Mermaid diagram renders on `workflow`; code blocks and tables are legible in both modes. Report what was inspected.

- [ ] **Step 6: Commit**

Stage, scan, and commit:

```bash
git add tests/docs/test-docs-skills.sh docs/site/index.md
git diff --cached --stat
git diff --cached | python3 ~/.claude/scripts/realval-scan.py
git diff --cached | grep -E '^\+' | grep -cE '\$[0-9]'
printf '%s\n' "test(docs): check the whole documentation site in the offline set" | grep -cE '\$[0-9]'
git commit -m "test(docs): check the whole documentation site in the offline set"
```

Expected before the commit: the stat lists exactly this task's files, then `hits: 0`, `0`, `0`. Any other result stops the commit until the content is fixed and re-staged.

- [ ] **Step 7: Final review checklist (for the whole-branch review)**

The final review reads every file the branch changes and every commit message (`git log --format=%B <base>..HEAD`) for: behavior claims against each page's `sources`; dollar amounts (`git log --format=%B <base>..HEAD | grep -cE '\$[0-9]'` expects 0) and organization details; the upstream credit on `index.md` and `superpowers.md`. For each skill page: two or three example requests, at least two concrete cons, "Works with" links that match the skill's actual hand-offs, and an at-a-glance card with all four fields.
