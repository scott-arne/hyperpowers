# Portable SDD Dossiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md` (approved by the human partner on 2026-10-20). The spec is binding; where this plan and the spec disagree, the spec governs, except for the seven deviations listed below, which the human partner approved at hand-off.

**Goal:** Move each plan's SDD dossier onto a per-repository orphan state branch checked out once per clone under the user cache, so a run handed from one host to another by git push and pull resumes with its ledger, reports, and claims, while every worktree of a clone shares one live ledger.

**Architecture:** A sourced library, `sdd-common.sh`, owns the key (hash of the physical common git directory), the state branch and remote names, the checkout path, the backend file, the lock (with a guarded stale takeover and owner-checked release), private-index commits, and checkout creation with crash recovery. `sdd-dir` keeps its stdout contract and prints a workspace inside that checkout (or the plain cache when the branch backend is unavailable). A new helper, `sdd-state`, carries the lifecycle: `sync`, `verify`, `snapshot`, `handoff`, `finish`, `import`, `prune`, `claim`. The three requesting-code-review scripts and the session-start hook move to the same key. Skill text in using-git-worktrees (the three-way branch question, first), subagent-driven-development (the new setup order, per-session mode lines, claims, the hand-off), and finishing-a-development-branch (the mode input) follows. Offline bash suites pin every contract; a two-clone rehearsal, one quorum scenario, and a release-readiness task that validates the spec's assumptions with the human partner close the plan.

**Tech Stack:** bash 3.2 (the host's `/bin/bash` and `bash` are both 3.2.57), git 2.56 on the laptop (every command newer than git 2.23 has a fallback), node 26 for the two places bash cannot do the job (an atomic directory rename and the existing JSON readers), markdown skill text, and the repository's bash test suites.

## Deviations from the spec (approved by the human partner on 2026-10-20)

1. **Ledgers are appended to, never checked out.** Spec section 2 applies a fast-forward or merge by checking out the changed paths and re-appending ledger lines gained since the snapshot, and accepts the window of one `git checkout` for lines written meanwhile. Task 7 instead appends the target's new ledger lines to the live file, so no ledger line can be lost at any moment; the residual window applies to report files only. Stricter than the spec on the point the spec protects.
2. **A plan file must exist.** The spec is silent; `sdd-dir` used to accept a path whose directory exists. Task 1's `hp_plan_dir` requires an existing regular file, so a mistyped path never earns a workspace (`sdd-dir`, `sdd-state`, and the tests agree).
3. **`import` stages and rewrites by suffix.** Spec section 2 copies into the destination and verifies by file list and sizes, and rewrites an absolute identity line that lies inside the plan repository. Task 4 stages the copy beside the destination, compares full manifests (type, size, link target) before installing it, and also rewrites an absolute identity from another host that ends with the plan's repo-relative path, which is the case the spec's resume rule accepts by suffix.
4. **`claim` takes the repository lock.** Spec section 2 says a claim is a single atomic publication and needs no lock. Task 3 keeps the atomic rename and also takes the lock around it, so a claim cannot appear between `finish`'s read of the claims and its removal of the workspace (both read and remove run under the same lock).
5. **A shallow code repository skips the root comparison.** Spec section 2 compares the code repository's root commit with the recorded one. In a depth-limited clone the shallow boundary reads as a root, so `verify` (Task 8) skips that comparison when `git rev-parse --is-shallow-repository` is true and judges the clone by commit presence alone, which reports the missing history as `code-missing` with the branch to fetch.
6. **Removal is rename, verify, delete; and a few additive outcomes.** Spec section 2 removes a workspace with `rm -rf` after a check, and controllers write without the lock, so a line written between the check and the removal would be lost. Every removal in this plan (`finish`, `prune --apply`, and a remote finish applied by `sync`) renames the directory aside atomically, compares its tracked files with the committed tip (the plain backend compares the ledger's size with the size read before), deletes only an unchanged directory, and renames a changed one back. A writer that opens the old path after the rename fails with ENOENT instead of writing into the void, so no write is lost silently. The outcomes this adds: `sync` `status=remote-finished plans=<ws,...>` (exit 3, nothing changed, the human partner decides), `finish` `status=busy` (exit 3, retry), `prune --apply` `kept=<ws,...>` for candidates found active, `handoff` `status=detached-head repo=<code|plan>` (exit 11; a detached checkout has no branch the other host could pull), `claim` `status=no-workspace` (exit 2, the plan is finished or never started here) and `status=done task=<N>` (exit 0, the ledger already records the task complete). `sync` also leaves a marker while it applies files and recovers it on the next call, so an interrupted apply never turns into a revert snapshot.
7. **The bump and the install are the human partner's steps.** Spec section 6 says "Minor bump. Install on each host from the release tag." Task 17 validates the spec's assumptions and prepares the exact commands; running them is sequenced by the human partner against the in-flight `sdd-turn-liveness` plan, which targets the same next minor version.

## Global Constraints

- Branch and worktree: hyperpowers branch `portable-sdd-dossiers` in `.worktrees/portable-sdd-dossiers`, from `main` at the docs commit that adds the spec and this plan (its parent is `16485f4`). No commit lands on `main` during the plan; the human partner reviews the branch at Finish. Nothing is pushed.
- Evidence directory for every artifact an evidence note cites: `evals/evidence/2026-10-20-portable-sdd-dossiers/` on hyperpowers-evals branch `portable-sdd-dossiers` in `evals/.worktrees/portable-sdd-dossiers` (created in Task 16, about 8 minutes on that repository). Nothing is cited from the SDD workspace.
- Exact names, used identically in every task: state branch default `hyperpowers/state`; git config keys `hyperpowers.stateBranch`, `hyperpowers.stateRemote` (default `origin`), `hyperpowers.prePushScan`; checkout `${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/state/<key>/` with siblings `<key>.backend`, `<key>.lock/`, `<key>.lock-history`, `<key>.fetched`, temporary `<key>.tmp-*`; plain root `${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/sdd/<key>/`; workspace `plans/<slug>-<hash8>/`; library `skills/subagent-driven-development/scripts/sdd-common.sh` with the functions `hp_cache_root`, `hp_physical_dir`, `hp_common_dir`, `hp_key`, `hp_legacy_key`, `hp_state_branch`, `hp_state_remote`, `hp_has_remote`, `hp_checkout_path`, `hp_plain_root`, `hp_stamp_path`, `hp_backend`, `hp_write_backend`, `hp_session_id`, `hp_utc_now`, `hp_plan_dir`, `hp_plan_rel`, `hp_plan_ws_name`, `hp_git_id`, `hp_zero_oid`, `hp_lock`, `hp_lock_at`, `hp_lock_stale`, `hp_unlock`, `hp_commit_paths`, `hp_contained`, `hp_git_version_at_least`, `hp_check_sentinel`, `hp_write_root_files`, `hp_add_orphan_worktree`, `hp_recover_tmp_checkouts`, `hp_ensure_checkout`, `hp_materialize_plain`; helper `skills/subagent-driven-development/scripts/sdd-state` with subcommands `sync`, `verify`, `snapshot`, `handoff`, `finish`, `import`, `prune`, `claim`.
- Root files of a new state branch, byte for byte: `.hyperpowers-state` holding the single line `hyperpowers-state 1`; `.gitignore` holding the comment line `# Regenerable on any host: briefs come from task-brief, packages from review-package.` then `plans/*/task-*-brief.md` then `plans/*/review-*.diff`; `.gitattributes` holding `plans/*/progress.md merge=union`; `README.md` as written in Task 2.
- Output grammar: every `sdd-state` subcommand prints exactly one stdout line of space-separated `key=value` pairs with `status=` first; `sync` adds a second line `merge=<command>` on `diverged`. A value never contains a space: a plan workspace name with a space is printed percent-encoded (`%20`), and lists are comma-separated. `push=<remote>/<branch>` names the target; the command the skill may run on request is `git -C <checkout> push <remote> <branch>`, the checkout being the parent of the `plans/` directory `sdd-dir` printed. Every path-valued field (`worktree=`, `path=`, `from=`, `file=`, `paths=`, `plans=`, `kept=`) goes through one routine, `enc`, which turns a space into `%20`. Exit codes: 0 ok; 1 `offline`, `offline-no-state`, `push-failed`; 2 usage or internal (including `needs-sync`, a foreign branch, `import-failed`, `no-workspace`); 3 `diverged`, `busy` (from `sync` and from `finish`), `remote-finished`; 4 claim `held` by another session; 5 `scan-failed`; 6 `open-claims`; 7 `plain` from `handoff`; 8 `plan-not-committed`; 9 `wrong-repo`, `code-missing`, `plan-stale`; 10 `code-dirty`; 11 `detached-head`; 12 `shallow-source`.
- The session id: `$CLAUDE_CODE_SESSION_ID` on Claude Code; elsewhere a value generated once as `$(date -u +%s)-$RANDOM$RANDOM` (bash only, no `uuidgen` dependency).
- Ledger line shapes, verbatim: identity `# SDD ledger — plan: <repo-relative path>`; session `session <sid>: mode <current-branch|new-branch|worktree> on <branch> at <toplevel> started <UTC time>`; task list `session <sid>: tasks <N,M,...>`; implementer `Task <N>: implementer <agent-id> (session <sid>, worktree <path>, branch <name>)`; completion `Task <N>: complete (commits <base7>..<head7>, review clean)` (unchanged); hand-off `handoff: code root=<root commit full sha> <branch>@<full sha> at <UTC time> from <host>` and `handoff: plan root=<plan repository root commit> <branch>@<full sha>`; offline `state: sync offline at <time>`. The em dash in the identity line is U+2014, as today.
- Lock timings: retry every 200 ms, give up after 30 s (exit 2, owner shown), take over a lock older than 10 minutes whose pid is dead or unverifiable, through the takeover guard `<key>.lock.takeover/` so two contenders cannot both take over; record every takeover in `<key>.lock-history`; `hp_unlock` removes only a lock whose `owner` names this pid; the `INT` and `TERM` traps unlock and exit (130, 143).
- Test and environment overrides, read only by the helper: `HYPERPOWERS_FORCE_LEGACY_ORPHAN=1`, `HYPERPOWERS_TEST_CRASH_AT=after-worktree-add|after-initial-commit` (exit 99 at that point), `HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1`, `HYPERPOWERS_TEST_PAUSE_AT=sync-before-apply` (hold while `<checkout>/.sync-pause` exists) or `handoff-after-scan` (hold while `<checkout>/.handoff-pause` exists), `HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref` (exit 99 there), `HYPERPOWERS_TEST_WRITER_AT=<point>:<relative path>` (append one line to that file inside the checkout at `sync-before-apply`, `sync-before-delete`, `finish-before-remove`, or `prune-before-remove`, each placed after the last check and before the rename, standing in for an unlocked writer), `HYPERPOWERS_SESSION_ID` (preferred over `CLAUDE_CODE_SESSION_ID`).
- bash 3.2 compatibility in every script and test: no associative arrays (indexed arrays are fine and are used wherever a list holds paths), no `${var,,}`, no `mapfile`, no `read -d ''`; `sleep 0.2` is fine. The two new test suites run under `set -u` without `pipefail`, so a `producer | grep -q` is safe there; additions to suites that set `pipefail` use `grep -q PATTERN < <(producer)` or a file. `hooks/` files carry no heredoc or here-string (`tests/hooks/test-no-heredocs-in-hooks.sh`); `sdd-common.sh` has no side effects when sourced (no `set -e`, no trap, no output) because the hook sources it.
- No network access from `sdd-dir`, `verify`, the hook, `task-brief`, or `review-package`. Only `sdd-state sync` and `sdd-state handoff --push` touch a remote, and the skill text passes `--push` only on the human partner's explicit hand-off request. Finish prints the push command and never runs it.
- Skill changes keep the "your human partner" voice; the Red Flags tables and rationalization lists stay as they are apart from the one row added to using-git-worktrees in Task 12.
- Tests: the offline set in `docs/testing.md:50-55` passes at Task 15's commit, one suite per `bash` call, through the committed runner `tests/run-offline.sh` (Task 15 Step 4); never a blanket `find tests` (it launches live sessions). Every new or changed suite runs under a temporary `XDG_CACHE_HOME` and never touches the real cache. Live runs (Task 16) run outside the Bash sandbox when `git init` or a worktree add fails there with "Operation not permitted"; each live command is tried once inside first.
- Commit messages follow `type(scope): sentence` (`feat(sdd): …`, `test(sdd): …`, `docs(hyperpowers): …`); no attribution lines of any kind. Before every commit the staged diff passes `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` with `hits: 0`. No committed file carries the proxy host, the `NO_PROXY` list, or the GCP project id.
- The spec's minor bump and the install on both hosts are Task 17's human-partner-run steps: the plan prepares the CHANGELOG entry under `## Unreleased` (Task 15), validates the spec's assumptions (Task 17), and lists the exact bump and install commands, which run only on the human partner's go, because the in-flight `sdd-turn-liveness` plan also targets the next minor version and the human partner sequences the two. The release note must say that both hosts need a plugin version with the state branch.
- Multi-command evidence steps are committed bash scripts run as `bash <script>` (the rehearsal scripts in the evals evidence tree, the offline runner in `tests/`): the interactive shell is zsh, where a lowercase `path=` replaces `PATH` and `PIPESTATUS` does not exist. No `grep -q` reads from a pipe (the host's 512-byte pipe trap); write to a file first.

## Grounding

- Current derivation and the behaviors being replaced: `skills/subagent-driven-development/scripts/sdd-dir:1-21` (header rationale), `:26-48` (plan argument handling, kept), `:50-70` (key, slug, hash8), `:81-103` (cross-repository pointer under the cwd key, kept in the plain cache), `:105-123` (14-day reclaim, kept for the plain cache only).
- Other key derivations to replace: `skills/requesting-code-review/scripts/codex-review-dir:44-50`; `skills/requesting-code-review/scripts/ungated-ledger:52-57` (key and root) and `:184-199` (`pending`); `skills/requesting-code-review/scripts/gate-telemetry:45-58` (key enumeration) and `:128-141` (the SDD workspace walk).
- Hook: `hooks/session-start:7-8` (`PLUGIN_ROOT`), `:158-186` (compaction key and ledger scan, read-only), `:224` (notice text); the heredoc fence `tests/hooks/test-no-heredocs-in-hooks.sh:1-9`.
- Nearest existing lock: `skills/requesting-code-review/scripts/ungated-ledger:21-23` (mkdir lockdir with a stale takeover). `none: no existing private-index commit, checkout creation, or claim primitive in the repository.`
- Test shape: `tests/claude-code/test-sdd-dir-path.sh:11-45` (`TEST_ROOT`, pinned `XDG_CACHE_HOME`, `pass`/`fail`, `make_repo`, `run_sdd_dir`), `:206-262` (pointer assertions 10g-10i), `:264-290` (reclaim assertions 11-12), `:293-305` (plan-scoped shape), `:424-428` (closing STATUS lines); `tests/hooks/test-session-start.sh:448-470` (`NOTICE_HEAD`/`NOTICE_TAIL`, `sdd_key`, `seed_ledger`); `tests/codex-review-gate/test-ungated-ledger.sh:31-33`; `tests/codex-review-gate/test-gate-telemetry.sh:24-33`; `tests/claude-code/test-codex-review-dir-path.sh:40-60`; `tests/sdd/test-sdd-contract.sh:19-34` (`assert_contains` over a whitespace-collapsed haystack) and `:385-390` (closing lines).
- SDD skill text sites: `skills/subagent-driven-development/SKILL.md:117-125` (Setup, the main/master consent sentence at `:121-123`), `:129-137` (workspace bullet), `:138-155` (ledger check bullet), `:156-157` (identity line), `:161-165` (scratch bullet), `:241-285` (Dispatch; identity line `:279-283`, no-parallel rule `:285`), `:582-596` (Final Review), `:627-640` (Finish); `skills/subagent-driven-development/example-workflow.md:6-9`.
- using-git-worktrees: `skills/using-git-worktrees/SKILL.md:16-49` (Step 0; the consent question `:43`), `:142-157` (Quick Reference), `:159-166` (Common Rationalizations).
- finishing-a-development-branch: `skills/finishing-a-development-branch/SKILL.md:30-46` (Step 2 and its table), `:55-78` (Step 4 menus), `:205-212` (Quick Reference).
- executing-plans: `skills/executing-plans/SKILL.md:21` (reaches the branch question through using-git-worktrees; otherwise untouched). optimizing-performance: `skills/optimizing-performance/SKILL.md:38`, `skills/optimizing-performance/perf-implementer-notes.md:12`.
- Docs: `docs/testing.md:21-33` (suite table) and `:50-55` (offline set); `README.md:164`; `CHANGELOG.md:1-9` (heading and bullet style); `scripts/lint-shell.sh:1-9` (usage; it lints tracked shell files).
- `tests/claude-code/test-sdd-dir-path.sh:151-168` (test 10b, the nonexistent-plan guard) and `:218-233` (test 10g, the real-directory assertion that moves to the checkout).
- Live recipe: `evals/evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:16-28` (`env -u` of the session variables, empty `CLAUDE_CONFIG_DIR`, `--plugin-dir`, `--output-format stream-json`); evidence rules `evals/evidence/README.md:1-30`.
- Quorum scenario: `evals/scenarios/sdd-plan-scoped-scratch/checks.sh:22,42,50` (ledger found by `find ../home/.cache -name progress.md`, layout-agnostic) and `setup.sh:55-68` (plan A seeded through the candidate's `sdd-dir` with `HOME` and `XDG_CACHE_HOME` pinned to the run's home).

---

## Before Task 1

- [ ] With the human partner's approval of the spec and plan diff, commit both on hyperpowers `main` as one docs commit (`docs(hyperpowers): the portable SDD dossiers design and its implementation plan`), leak scan first.
- [ ] Create the worktree with `hyperpowers:using-git-worktrees`: branch `portable-sdd-dossiers` from that commit, under `.worktrees/`. In it run `bash tests/claude-code/test-sdd-dir-path.sh`, `bash tests/sdd/test-sdd-contract.sh`, `bash tests/hooks/test-session-start.sh`, `bash tests/codex-review-gate/test-gate-telemetry.sh`, `bash tests/codex-review-gate/test-ungated-ledger.sh`, `bash tests/claude-code/test-codex-review-dir-path.sh`, one per `bash` call, and record each `STATUS:` line in the ledger as the baseline.
- [ ] Record `git --version` (2.56.0 on the laptop) and `bash --version | head -1` (3.2.57) in the ledger.

---

### Task 1: The shared library `sdd-common.sh`: key, config, backend, lock, private-index commits

**Risk tier:** high — the lock and the private-index commit are concurrency code, and every later script trusts the key this file derives.

**Files:**
- Create: `skills/subagent-driven-development/scripts/sdd-common.sh`
- Test: `tests/sdd/test-sdd-common.sh`

**Interfaces:**
- Produces: the functions listed in Global Constraints up to `hp_commit_paths`. Signatures: `hp_key REPO_DIR` prints the key; `hp_legacy_key REPO_DIR`; `hp_state_branch REPO_DIR`; `hp_state_remote REPO_DIR`; `hp_has_remote REPO_DIR` (exit status); `hp_checkout_path REPO_DIR`; `hp_plain_root REPO_DIR`; `hp_stamp_path REPO_DIR`; `hp_backend REPO_DIR` prints `branch`, `plain`, or `none`; `hp_write_backend REPO_DIR LINE`; `hp_plan_dir PLAN_FILE` (fails unless the plan is an existing regular file inside a repository), `hp_plan_rel PLAN_FILE`, `hp_plan_ws_name PLAN_FILE`; `hp_git_id REPO_DIR GIT_ARGS...`; `hp_zero_oid REPO_DIR` (the all-zero object id of the repository's hash length); `hp_lock REPO_DIR` (sets `HP_LOCK_DIR`, traps, exit 2 after 30 s); `hp_unlock` (removes only a lock this pid owns); `hp_commit_paths CHECKOUT BRANCH MESSAGE PATH...` prints the new commit sha or `none`, exit 2 on failure. Task 2 appends the creation functions to the same file.

**Mirror:** `skills/requesting-code-review/scripts/ungated-ledger:21-23` for the lock idea (mkdir lockdir, stale takeover); `skills/subagent-driven-development/scripts/sdd-dir:50-70` for slug and hash8; `tests/claude-code/test-sdd-dir-path.sh:11-45` for the test scaffold.

- [ ] **Step 1: Write the failing test**

Create `tests/sdd/test-sdd-common.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for skills/subagent-driven-development/scripts/sdd-common.sh:
# the state key, config lookups, the backend file, plan naming, the lock, and
# the private-index commit. Runs under a temporary cache root and never
# touches the real ~/.cache. No pipefail: several checks pipe a producer into
# grep -q, and under pipefail the producer's SIGPIPE would read as a failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"

failures=0
TEST_ROOT="$(mktemp -d)"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

make_repo() { # <path>
    git init -q -b main "$1"
    git -C "$1" config user.name "Test Bot"
    git -C "$1" config user.email "test@example.com"
    git -C "$1" commit -q --allow-empty -m "initial"
}

echo "=== sdd-common.sh ==="

# shellcheck source=/dev/null
. "$LIB"

# --- key -------------------------------------------------------------------
repo_a="$TEST_ROOT/a"; make_repo "$repo_a"
repo_b="$TEST_ROOT/b"; make_repo "$repo_b"
git -C "$repo_a" worktree add -q "$TEST_ROOT/a-wt" -b wt >/dev/null 2>&1

key_a=$(hp_key "$repo_a"); key_wt=$(hp_key "$TEST_ROOT/a-wt"); key_b=$(hp_key "$repo_b")
if [ "$key_a" = "$key_wt" ]; then pass "a linked worktree shares its clone's key"; else fail "a linked worktree shares its clone's key ($key_a vs $key_wt)"; fi
if [ "$key_a" != "$key_b" ]; then pass "two clones have different keys"; else fail "two clones have different keys"; fi
if [ "$(hp_legacy_key "$repo_a")" != "$(hp_legacy_key "$TEST_ROOT/a-wt")" ]; then pass "the legacy key still differs per worktree"; else fail "the legacy key still differs per worktree"; fi
if [ "$key_a" = "$(hp_legacy_key "$repo_a")" ]; then pass "for the main checkout the new key equals the legacy key"; else fail "for the main checkout the new key equals the legacy key"; fi
ln -s "$repo_a" "$TEST_ROOT/a-link"
if [ "$(hp_key "$TEST_ROOT/a-link")" = "$key_a" ]; then pass "a symlinked path yields the physical key"; else fail "a symlinked path yields the physical key"; fi
case "$(hp_zero_oid "$repo_a")" in 0000000000000000000000000000000000000000) pass "the zero oid matches the repository's hash length" ;; *) fail "the zero oid matches the repository's hash length ($(hp_zero_oid "$repo_a"))" ;; esac

# --- config ----------------------------------------------------------------
if [ "$(hp_state_branch "$repo_a")" = "hyperpowers/state" ]; then pass "default state branch"; else fail "default state branch"; fi
if [ "$(hp_state_remote "$repo_a")" = "origin" ]; then pass "default state remote"; else fail "default state remote"; fi
git -C "$repo_b" config hyperpowers.stateBranch team/state
git -C "$repo_b" config hyperpowers.stateRemote upstream
if [ "$(hp_state_branch "$repo_b")" = "team/state" ] && [ "$(hp_state_remote "$repo_b")" = "upstream" ]; then pass "config overrides branch and remote"; else fail "config overrides branch and remote"; fi
if hp_has_remote "$repo_a"; then fail "no remote configured means hp_has_remote fails"; else pass "no remote configured means hp_has_remote fails"; fi
git -C "$repo_a" remote add origin "$TEST_ROOT/nowhere.git"
if hp_has_remote "$repo_a"; then pass "a configured remote means hp_has_remote succeeds"; else fail "a configured remote means hp_has_remote succeeds"; fi

# --- paths and backend -----------------------------------------------------
case "$(hp_checkout_path "$repo_a")" in
    "$XDG_CACHE_HOME/hyperpowers/state/$key_a") pass "checkout path is state/<key> under the cache" ;;
    *) fail "checkout path is state/<key> under the cache (got $(hp_checkout_path "$repo_a"))" ;;
esac
case "$(hp_plain_root "$repo_a")" in
    "$XDG_CACHE_HOME/hyperpowers/sdd/$key_a") pass "plain root is sdd/<key> under the cache" ;;
    *) fail "plain root is sdd/<key> under the cache" ;;
esac
if [ "$(hp_backend "$repo_a")" = "none" ]; then pass "no backend file reads as none"; else fail "no backend file reads as none"; fi
hp_write_backend "$repo_a" "plain source=abc"
if [ "$(hp_backend "$repo_a")" = "plain" ] && [ -f "$(hp_checkout_path "$repo_a").backend" ] && [ ! -e "$(hp_checkout_path "$repo_a").backend.tmp.$$" ]; then pass "backend file written atomically and read by first word"; else fail "backend file written atomically and read by first word"; fi
hp_write_backend "$repo_a" branch
if [ "$(hp_backend "$repo_a")" = "branch" ]; then pass "backend file rewritten"; else fail "backend file rewritten"; fi

# --- plan naming -----------------------------------------------------------
mkdir -p "$repo_a/docs/x" "$repo_a/docs/y"
: > "$repo_a/docs/x/plan.md"; : > "$repo_a/docs/y/plan.md"
rel_x=$(cd "$repo_a" && hp_plan_rel docs/x/plan.md)
if [ "$rel_x" = "docs/x/plan.md" ]; then pass "hp_plan_rel is repo-relative"; else fail "hp_plan_rel is repo-relative (got $rel_x)"; fi
ws_rel=$(cd "$repo_a" && hp_plan_ws_name docs/x/plan.md)
ws_abs=$(hp_plan_ws_name "$repo_a/docs/x/plan.md")
ws_y=$(hp_plan_ws_name "$repo_a/docs/y/plan.md")
case "$ws_rel" in plan-????????) pass "workspace name is <slug>-<hash8>" ;; *) fail "workspace name is <slug>-<hash8> (got $ws_rel)" ;; esac
if [ "$ws_rel" = "$ws_abs" ]; then pass "relative and absolute plan paths name one workspace"; else fail "relative and absolute plan paths name one workspace"; fi
if [ "$ws_rel" != "$ws_y" ]; then pass "same basename in another directory names another workspace"; else fail "same basename in another directory names another workspace"; fi
if hp_plan_dir "$TEST_ROOT/nowhere/plan.md" >/dev/null 2>&1; then fail "hp_plan_dir fails outside a repository"; else pass "hp_plan_dir fails outside a repository"; fi
if hp_plan_dir "$repo_a/docs/x/missing.md" >/dev/null 2>&1; then fail "hp_plan_dir fails for a plan file that does not exist"; else pass "hp_plan_dir fails for a plan file that does not exist"; fi

# --- lock ------------------------------------------------------------------
lock_repo="$TEST_ROOT/lock"; make_repo "$lock_repo"
lock_dir="$(hp_checkout_path "$lock_repo").lock"
bash -c '. "$1"; hp_lock "$2"; sleep 1.5; hp_unlock' _ "$LIB" "$lock_repo" &
holder=$!
sleep 0.3
start=$(date +%s)
hp_lock "$lock_repo"; rc=$?
end=$(date +%s)
wait "$holder"
if [ "$rc" -eq 0 ] && [ $((end - start)) -ge 1 ]; then pass "a second caller waits for a fresh lock and then takes it"; else fail "a second caller waits for a fresh lock and then takes it (rc=$rc, waited $((end - start))s)"; fi
if grep -q "^pid=$$\$" "$lock_dir/owner" 2>/dev/null; then pass "the lock records this pid as its owner"; else fail "the lock records this pid as its owner"; fi
hp_unlock
if [ ! -d "$lock_dir" ]; then pass "hp_unlock removes the lock"; else fail "hp_unlock removes the lock"; fi
mkdir -p "$lock_dir"; printf 'session=old\npid=999999\nhost=x\ntime=t\n' > "$lock_dir/owner"
touch -t 202601010000 "$lock_dir"
start=$(date +%s); hp_lock "$lock_repo"; rc=$?; end=$(date +%s)
if [ "$rc" -eq 0 ] && [ $((end - start)) -le 2 ] && grep -q 'takeover' "$lock_dir-history" && [ ! -d "$lock_dir.takeover" ]; then pass "a stale lock with a dead pid is taken over, recorded, and the guard released"; else fail "a stale lock with a dead pid is taken over, recorded, and the guard released (rc=$rc)"; fi
hp_unlock
# Two contenders meeting one stale lock: exactly one takes over, the other
# waits for it, and the lock that remains belongs to the second one.
mkdir -p "$lock_dir"; printf 'session=old\npid=999999\nhost=x\ntime=t\n' > "$lock_dir/owner"; touch -t 202601010000 "$lock_dir"
bash -c '. "$1"; hp_lock "$2" && { echo "$$" > "$3"; sleep 1; hp_unlock; }' _ "$LIB" "$lock_repo" "$TEST_ROOT/race1" &
bash -c '. "$1"; hp_lock "$2" && { echo "$$" > "$3"; sleep 1; hp_unlock; }' _ "$LIB" "$lock_repo" "$TEST_ROOT/race2" &
wait
if [ -f "$TEST_ROOT/race1" ] && [ -f "$TEST_ROOT/race2" ] && [ "$(grep -c takeover "$lock_dir-history")" -eq 2 ] && [ ! -d "$lock_dir" ]; then pass "two contenders on one stale lock serialize through the takeover guard"; else fail "two contenders on one stale lock serialize through the takeover guard"; fi
# unlock refuses a lock another process owns.
mkdir -p "$lock_dir"; printf 'session=x\npid=999998\nhost=x\ntime=t\n' > "$lock_dir/owner"
HP_LOCK_DIR=$lock_dir; hp_unlock
if [ -d "$lock_dir" ]; then pass "hp_unlock leaves a lock owned by another pid"; else fail "hp_unlock leaves a lock owned by another pid"; fi
rm -rf "$lock_dir"
# An interrupted holder releases the lock and stops.
bash -c '. "$1"; hp_lock "$2"; kill -INT $$; echo continued > "$3"; sleep 1' _ "$LIB" "$lock_repo" "$TEST_ROOT/continued" 2>/dev/null
if [ ! -d "$lock_dir" ] && [ ! -f "$TEST_ROOT/continued" ]; then pass "INT releases the lock and ends the holder"; else fail "INT releases the lock and ends the holder"; fi
trap cleanup EXIT

# --- concurrent appends ----------------------------------------------------
# Two processes append one line at a time with quoted heredocs, 200 times
# each: every line arrives whole (the spec's O_APPEND assumption on this
# filesystem; Task 17 runs this suite on ext4 too).
ap="$TEST_ROOT/append.md"; : > "$ap"
bash -c 'for i in $(seq 1 200); do cat >> "$1" <<EOF
alpha line $i of a controller writing its ledger entry with enough text to matter
EOF
done' _ "$ap" &
bash -c 'for i in $(seq 1 200); do cat >> "$1" <<EOF
beta line $i of another controller writing its ledger entry with enough text to matter
EOF
done' _ "$ap" &
wait
total=$(wc -l < "$ap" | tr -d ' ')
malformed=$(grep -vcE '^(alpha|beta) line [0-9]+ of (a|another) controller writing its ledger entry with enough text to matter$' "$ap")
if [ "$total" -eq 400 ] && [ "$malformed" -eq 0 ]; then pass "400 concurrent heredoc appends arrive whole, none interleaved"; else fail "400 concurrent heredoc appends arrive whole ($total lines, $malformed malformed)"; fi

# --- private-index commit --------------------------------------------------
co="$TEST_ROOT/co"
git init -q -b hyperpowers/state "$co"
mkdir -p "$co/plans/p1" "$co/plans/p2"
printf 'ledger\n' > "$co/plans/p1/progress.md"
printf 'other\n' > "$co/plans/p2/progress.md"
# A failing pre-commit hook and a staged unrelated file: neither may matter.
mkdir -p "$co/.git/hooks"; printf '#!/bin/sh\nexit 1\n' > "$co/.git/hooks/pre-commit"; chmod +x "$co/.git/hooks/pre-commit"
git -C "$co" add plans/p2/progress.md
git -C "$co" config commit.gpgsign true
sha1=$(hp_commit_paths "$co" hyperpowers/state "first" plans/p1)
if [ -n "$sha1" ] && [ "$sha1" != none ] && git -C "$co" cat-file -e "$sha1" 2>/dev/null; then pass "hp_commit_paths creates a root commit on an unborn branch"; else fail "hp_commit_paths creates a root commit on an unborn branch (got '$sha1')"; fi
if git -C "$co" ls-tree -r --name-only "$sha1" | grep -qx 'plans/p1/progress.md' && ! git -C "$co" ls-tree -r --name-only "$sha1" | grep -q 'plans/p2'; then pass "the commit holds only the given paths, not the shared index's staged file"; else fail "the commit holds only the given paths, not the shared index's staged file"; fi
if [ "$(git -C "$co" rev-parse hyperpowers/state)" = "$sha1" ]; then pass "the branch ref moved to the new commit"; else fail "the branch ref moved to the new commit"; fi
if [ "$(hp_commit_paths "$co" hyperpowers/state "again" plans/p1)" = none ]; then pass "an unchanged path commits nothing"; else fail "an unchanged path commits nothing"; fi
git -C "$co" config --unset user.email
printf 'more\n' >> "$co/plans/p1/progress.md"
sha2=$(hp_commit_paths "$co" hyperpowers/state "second" plans/p1)
if [ "$(git -C "$co" log -1 --format=%ae "$sha2")" = "hyperpowers@localhost" ]; then pass "a missing user.email falls back to the hyperpowers identity"; else fail "a missing user.email falls back to the hyperpowers identity"; fi
git -C "$co" config user.email test@example.com; git -C "$co" config --unset user.name
printf 'again\n' >> "$co/plans/p1/progress.md"
sha3=$(hp_commit_paths "$co" hyperpowers/state "third" plans/p1)
if [ "$(git -C "$co" log -1 --format=%an "$sha3")" = "hyperpowers" ]; then pass "a missing user.name falls back to the hyperpowers identity"; else fail "a missing user.name falls back to the hyperpowers identity"; fi
if [ "$(git -C "$co" rev-parse "$sha3^")" = "$sha2" ] && [ "$(git -C "$co" rev-parse "$sha2^")" = "$sha1" ]; then pass "successive commits chain"; else fail "successive commits chain"; fi
rm -rf "$co/plans/p1"
sha4=$(hp_commit_paths "$co" hyperpowers/state "remove" plans/p1)
if [ "$sha4" != none ] && ! git -C "$co" ls-tree -r --name-only "$sha4" | grep -q 'plans/p1'; then pass "a removed directory commits as a deletion"; else fail "a removed directory commits as a deletion"; fi
# Two concurrent first commits on an unborn branch: one creates it, the other chains.
co2="$TEST_ROOT/co2"; git init -q -b hyperpowers/state "$co2"; mkdir -p "$co2/plans/a" "$co2/plans/b"
printf 'a\n' > "$co2/plans/a/progress.md"; printf 'b\n' > "$co2/plans/b/progress.md"
bash -c '. "$1"; hp_commit_paths "$2" hyperpowers/state a plans/a' _ "$LIB" "$co2" > "$TEST_ROOT/co2.a" &
bash -c '. "$1"; hp_commit_paths "$2" hyperpowers/state b plans/b' _ "$LIB" "$co2" > "$TEST_ROOT/co2.b" &
wait
if [ "$(git -C "$co2" rev-list --count hyperpowers/state)" -eq 2 ] && git -C "$co2" ls-tree -r --name-only hyperpowers/state | grep -qx 'plans/a/progress.md' && git -C "$co2" ls-tree -r --name-only hyperpowers/state | grep -qx 'plans/b/progress.md'; then pass "two concurrent first commits both land in order"; else fail "two concurrent first commits both land in order ($(cat "$TEST_ROOT/co2.a") / $(cat "$TEST_ROOT/co2.b"))"; fi

echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-common.sh`
Expected: the `. "$LIB"` line fails (`No such file or directory`) and the script exits non-zero before any `[PASS]`.

- [ ] **Step 3: Write the library**

Create `skills/subagent-driven-development/scripts/sdd-common.sh`:

```bash
#!/usr/bin/env bash
# sdd-common.sh — shared derivations for the SDD state branch. Sourced, never
# executed, by sdd-dir, sdd-state, codex-review-dir, gate-telemetry,
# ungated-ledger and, read-only, by hooks/session-start. It must stay free of
# side effects at source time (no set -e, no trap, no output) and bash 3.2
# compatible. Design: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md.
#
# The key hashes the physical common git directory. Every linked worktree of
# a clone shares it, so every session on a host resolves to one state
# checkout and one live ledger per plan; the pre-6.17 key hashed the
# per-worktree git directory and split a plan across worktrees.

hp_cache_root() { printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers"; }

# Physical absolute path of a directory (symlinks resolved).
hp_physical_dir() { (cd "$1" 2>/dev/null && pwd -P); }

# <repo-dir> -> physical absolute common git directory.
hp_common_dir() {
  local d
  if ! d=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    d=$(git -C "$1" rev-parse --git-common-dir 2>/dev/null) || return 1
    case "$d" in /*) ;; *) d="$(hp_physical_dir "$1")/$d" ;; esac
  fi
  hp_physical_dir "$d"
}

# <repo-dir> -> the state key, hashed with the repository's own object format.
hp_key() {
  local d
  d=$(hp_common_dir "$1") || return 1
  printf '%s' "$d" | git -C "$1" hash-object --stdin
}

# <repo-dir> -> the pre-state key (hash of the absolute git directory), kept
# so readers still find workspaces an older plugin wrote.
hp_legacy_key() {
  printf '%s' "$(git -C "$1" rev-parse --absolute-git-dir)" | git -C "$1" hash-object --stdin
}

# <repo-dir> -> the all-zero object id in the repository's hash length, the
# "must not exist" old value for update-ref.
hp_zero_oid() { printf '' | git -C "$1" hash-object --stdin | tr '0-9a-f' '0'; }

hp_state_branch() { git -C "$1" config --get hyperpowers.stateBranch 2>/dev/null || printf 'hyperpowers/state\n'; }
hp_state_remote() { git -C "$1" config --get hyperpowers.stateRemote 2>/dev/null || printf 'origin\n'; }
hp_has_remote() { git -C "$1" remote get-url "$(hp_state_remote "$1")" >/dev/null 2>&1; }

hp_checkout_path() { printf '%s/state/%s\n' "$(hp_cache_root)" "$(hp_key "$1")"; }
hp_plain_root() { printf '%s/sdd/%s\n' "$(hp_cache_root)" "$(hp_key "$1")"; }
hp_stamp_path() { printf '%s.fetched\n' "$(hp_checkout_path "$1")"; }

# The backend file: first word branch|plain, the rest free-form key=value.
hp_backend() {
  local f
  f="$(hp_checkout_path "$1").backend"
  if [ -f "$f" ]; then head -n 1 "$f" | cut -d' ' -f1; else printf 'none\n'; fi
}
hp_write_backend() { # <repo-dir> <line>
  local f tmp
  f="$(hp_checkout_path "$1").backend"
  tmp="$f.tmp.$$"
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$2" > "$tmp" && mv -f "$tmp" "$f"
}

hp_session_id() { printf '%s\n' "${HYPERPOWERS_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"; }
hp_utc_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# <plan-file> -> physical directory of the plan. The plan must be an existing
# regular file inside a repository: a mistyped path never earns a workspace.
hp_plan_dir() {
  local d
  [ -f "$1" ] || return 1
  d=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P) || return 1
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || return 1
  printf '%s\n' "$d"
}
# <plan-file> -> repo-relative path of the plan.
hp_plan_rel() {
  local d top abs
  d=$(hp_plan_dir "$1") || return 1
  top=$(hp_physical_dir "$(git -C "$d" rev-parse --show-toplevel)")
  abs="$d/$(basename "$1")"
  printf '%s\n' "${abs#"$top"/}"
}
# <plan-file> -> <slug>-<hash8>, the workspace name, identical on every host.
hp_plan_ws_name() {
  local d rel slug hash8
  d=$(hp_plan_dir "$1") || return 1
  rel=$(hp_plan_rel "$1")
  slug=$(basename "$1"); slug=${slug%.*}
  hash8=$(printf '%s' "$rel" | git -C "$d" hash-object --stdin | cut -c1-8)
  printf '%s-%s\n' "$slug" "$hash8"
}

# git with the dedicated identity when either identity field is missing.
hp_git_id() { # <repo-dir> <git args...>
  local r=$1
  shift
  if [ -n "$(git -C "$r" config --get user.name 2>/dev/null)" ] && [ -n "$(git -C "$r" config --get user.email 2>/dev/null)" ]; then
    git -C "$r" "$@"
  else
    git -C "$r" -c user.name=hyperpowers -c user.email=hyperpowers@localhost "$@"
  fi
}

# --- lock -------------------------------------------------------------------
# mkdir is atomic. A lock older than ten minutes whose pid is dead, or cannot
# be checked, is taken over; the takeover itself goes through a second
# atomic directory, the guard, so two contenders cannot both remove a lock
# and one of them delete the other's fresh one. Readers never take the lock.
HP_LOCK_DIR=""
hp_lock_stale() { # <lock-dir>
  local pid
  [ -n "$(find "$1" -maxdepth 0 -mmin +10 2>/dev/null)" ] || return 1
  pid=$(sed -n 's/^pid=//p' "$1/owner" 2>/dev/null)
  [ -n "$pid" ] || return 0
  if kill -0 "$pid" 2>/dev/null; then return 1; fi
  return 0
}
hp_lock() { # <repo-dir>
  local lock guard waited=0 owner
  lock="$(hp_checkout_path "$1").lock"
  guard="$lock.takeover"
  mkdir -p "$(dirname "$lock")"
  while ! mkdir "$lock" 2>/dev/null; do
    if hp_lock_stale "$lock" && mkdir "$guard" 2>/dev/null; then
      # Re-check under the guard: the lock may have been replaced meanwhile.
      if [ -d "$lock" ] && hp_lock_stale "$lock"; then
        owner=$(tr '\n' ' ' < "$lock/owner" 2>/dev/null)
        printf 'takeover by pid %s at %s of: %s\n' "$$" "$(hp_utc_now)" "$owner" >> "$lock-history"
        rm -rf "$lock"
      fi
      rmdir "$guard" 2>/dev/null
      continue
    fi
    if [ "$waited" -ge 150 ]; then
      echo "sdd-state: lock held: $(tr '\n' ' ' < "$lock/owner" 2>/dev/null)" >&2
      return 2
    fi
    sleep 0.2
    waited=$((waited + 1))
  done
  printf 'session=%s\npid=%s\nhost=%s\ntime=%s\n' "$(hp_session_id)" "$$" "$(hostname)" "$(hp_utc_now)" > "$lock/owner"
  HP_LOCK_DIR=$lock
  trap 'hp_unlock' EXIT
  trap 'hp_unlock; exit 130' INT
  trap 'hp_unlock; exit 143' TERM
}
# Remove the lock only when this pid owns it: a stale takeover may have
# replaced it with another process's lock.
hp_unlock() {
  if [ -n "$HP_LOCK_DIR" ] && [ "$(sed -n 's/^pid=//p' "$HP_LOCK_DIR/owner" 2>/dev/null)" = "$$" ]; then
    rm -rf "$HP_LOCK_DIR"
  fi
  HP_LOCK_DIR=""
}

# --- private-index commit ---------------------------------------------------
# Commit only <paths> of <checkout> onto <branch> through a private index, so
# another session's staged or half-written files are never included. Plumbing
# runs no hooks and signs nothing. Prints the new commit, or "none" when the
# paths already match the tip; a lost ref race is retried from the new tip,
# and creation of an unborn branch is conditional on the zero oid. The index
# path must not exist before read-tree: git rejects an existing empty file.
hp_commit_paths() { # <checkout> <branch> <message> <path>...
  local co=$1 br=$2 msg=$3 ref idxdir idx tip tree commit attempt old
  shift 3
  ref="refs/heads/$br"
  idxdir=$(mktemp -d "${TMPDIR:-/tmp}/sdd-index.XXXXXX") || return 2
  idx="$idxdir/index"
  for attempt in 1 2 3; do
    rm -f "$idx"
    tip=$(git -C "$co" rev-parse -q --verify "$ref^{commit}" 2>/dev/null || true)
    if [ -n "$tip" ]; then
      GIT_INDEX_FILE=$idx git -C "$co" read-tree "$tip" || { rm -rf "$idxdir"; return 2; }
    else
      GIT_INDEX_FILE=$idx git -C "$co" read-tree --empty || { rm -rf "$idxdir"; return 2; }
    fi
    GIT_INDEX_FILE=$idx git -C "$co" add -A -- "$@" 2>/dev/null || { rm -rf "$idxdir"; return 2; }
    tree=$(GIT_INDEX_FILE=$idx git -C "$co" write-tree) || { rm -rf "$idxdir"; return 2; }
    if [ -n "$tip" ] && [ "$tree" = "$(git -C "$co" rev-parse "$tip^{tree}")" ]; then
      rm -rf "$idxdir"; printf 'none\n'; return 0
    fi
    if [ -n "$tip" ]; then
      commit=$(printf '%s\n' "$msg" | hp_git_id "$co" commit-tree "$tree" -p "$tip") || { rm -rf "$idxdir"; return 2; }
      old=$tip
    else
      commit=$(printf '%s\n' "$msg" | hp_git_id "$co" commit-tree "$tree") || { rm -rf "$idxdir"; return 2; }
      old=$(hp_zero_oid "$co")
    fi
    if git -C "$co" update-ref -m sdd "$ref" "$commit" "$old" 2>/dev/null; then
      git -C "$co" reset -q -- "$@" 2>/dev/null || true
      rm -rf "$idxdir"; printf '%s\n' "$commit"; return 0
    fi
  done
  rm -rf "$idxdir"
  return 2
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/sdd/test-sdd-common.sh`
Expected: every line `[PASS]`, then `STATUS: PASSED`. If the lock wait assertion fails on a slow machine, the holder's `sleep 1.5` versus the waiter's whole-second clock is the cause; the assertion allows a 1 s floor on purpose.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-common.sh tests/sdd/test-sdd-common.sh`
Expected: no findings. The one shellcheck note worth a directive is SC1090 on the test's `. "$LIB"` line, already covered by the `# shellcheck source=/dev/null` comment.

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh tests/sdd/test-sdd-common.sh
git commit -m "feat(sdd): shared library for the state key, lock and private-index commits"
```

---

### Task 2: Checkout creation with recovery, the plain fallback, and the state test scaffold

**Risk tier:** high — creates git worktrees and branches, decides between the branch and plain backends, and recovers from crashes under the lock.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh` (append the creation section)
- Create: `tests/sdd/test-sdd-state.sh` (scaffold plus the creation section; later tasks append sections above its closing STATUS lines)

**Interfaces:**
- Consumes: Task 1's `hp_lock`, `hp_unlock`, `hp_commit_paths`, `hp_git_id`, `hp_checkout_path`, `hp_backend`, `hp_write_backend`, `hp_stamp_path`, `hp_has_remote`, `hp_state_branch`, `hp_state_remote`, `hp_plain_root`.
- Produces: `hp_git_version_at_least MAJOR MINOR` (exit status); `hp_check_sentinel REPO_DIR COMMIT` (exit 2 with a message when the commit's root lacks the sentinel); `hp_write_root_files DIR`; `hp_add_orphan_worktree REPO_DIR PATH BRANCH`; `hp_recover_tmp_checkouts REPO_DIR CHECKOUT BRANCH`; `hp_ensure_checkout REPO_DIR` prints `branch <checkout>` or `plain <plain-root>`, exit 2 on `needs-sync` or a foreign branch; `hp_materialize_plain REPO_DIR WS DEST_DIR` (exit 2 when the archive fails; callers hold the lock). The test file's helpers `make_repo`, `make_pair` (sets `PAIR_REMOTE`, `PAIR_A`, `PAIR_B`), `ensure`, `state_key`, `run_state`, `run_sdd_dir`, `registrations`, `ws_path`, and its closing STATUS block, which every later task's section goes above.

**Mirror:** `tests/claude-code/test-sdd-dir-path.sh:11-45` for the scaffold; `skills/subagent-driven-development/scripts/sdd-dir:1-21` for the header voice.

- [ ] **Step 1: Write the failing test**

Create `tests/sdd/test-sdd-state.sh`:

```bash
#!/usr/bin/env bash
# Behavior tests for the SDD state branch: checkout creation and recovery,
# then each sdd-state subcommand (each task appends its section above the
# closing STATUS lines). Two clones of one bare repository at different
# paths stand in for two hosts. Everything runs under a temporary cache root
# and never touches the real ~/.cache. No pipefail: several checks pipe a
# producer into grep -q, and under pipefail the producer's SIGPIPE would read
# as a failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
SDD_DIR="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-dir"
SDD_STATE="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-state"

failures=0
TEST_ROOT="$(mktemp -d)"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
STATE_ROOT="$XDG_CACHE_HOME/hyperpowers/state"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

make_repo() { # <path>
    git init -q -b main "$1"
    git -C "$1" config user.name "Test Bot"
    git -C "$1" config user.email "test@example.com"
    git -C "$1" commit -q --allow-empty -m "initial"
}
# A bare origin holding main, cloned twice at different paths (two hosts).
make_pair() { # <name> -> PAIR_REMOTE PAIR_A PAIR_B
    PAIR_REMOTE="$TEST_ROOT/$1.git"
    git init -q --bare -b main "$PAIR_REMOTE"
    PAIR_A="$TEST_ROOT/hostA/$1"; mkdir -p "$(dirname "$PAIR_A")"
    git clone -q "$PAIR_REMOTE" "$PAIR_A" 2>/dev/null
    git -C "$PAIR_A" config user.name "Host A"; git -C "$PAIR_A" config user.email "a@example.com"
    git -C "$PAIR_A" commit -q --allow-empty -m "initial"
    git -C "$PAIR_A" push -q origin main 2>/dev/null
    PAIR_B="$TEST_ROOT/hostB/$1"; mkdir -p "$(dirname "$PAIR_B")"
    git clone -q "$PAIR_REMOTE" "$PAIR_B" 2>/dev/null
    git -C "$PAIR_B" config user.name "Host B"; git -C "$PAIR_B" config user.email "b@example.com"
}
# ensure <repo> [VAR=value...]: hp_ensure_checkout in a fresh bash; prints its line.
ensure() { local repo=$1; shift; env "$@" bash -c '. "$1"; hp_ensure_checkout "$2"' _ "$LIB" "$repo"; }
state_key() { ( . "$LIB"; hp_key "$1" ); }
run_state() { ( cd "$1" && shift && bash "$SDD_STATE" "$@" ); }
run_sdd_dir() { ( cd "$1" && shift && bash "$SDD_DIR" "$@" ); }
registrations() { git -C "$1" worktree list --porcelain | grep -c "^worktree $STATE_ROOT/"; }
# ws_path <repo> <plan>: the workspace path inside the repository's checkout,
# created, without going through sdd-dir (Task 5 asserts sdd-dir prints it).
ws_path() { ( . "$LIB"; e=$(hp_ensure_checkout "$1") || exit 2; printf '%s/plans/%s\n' "${e#* }" "$(hp_plan_ws_name "$2")" ) ; }

echo "=== creation ==="

# Orphan creation in a repository with no remote.
r1="$TEST_ROOT/r1"; make_repo "$r1"
out=$(ensure "$r1"); rc=$?
co1="$STATE_ROOT/$(state_key "$r1")"
if [ "$rc" -eq 0 ] && [ "$out" = "branch $co1" ]; then pass "orphan creation prints branch <checkout>"; else fail "orphan creation prints branch <checkout> (rc=$rc, got '$out')"; fi
if [ -f "$co1/.git" ] && [ "$(registrations "$r1")" -eq 1 ]; then pass "the checkout is a linked worktree of the clone"; else fail "the checkout is a linked worktree of the clone"; fi
if [ "$(git -C "$r1" rev-list --count hyperpowers/state 2>/dev/null)" = 1 ]; then pass "the new branch has exactly one commit"; else fail "the new branch has exactly one commit"; fi
if [ "$(git -C "$r1" show hyperpowers/state:.hyperpowers-state 2>/dev/null)" = "hyperpowers-state 1" ]; then pass "the sentinel is committed with its exact content"; else fail "the sentinel is committed with its exact content"; fi
expected_ignore='# Regenerable on any host: briefs come from task-brief, packages from review-package.
plans/*/task-*-brief.md
plans/*/review-*.diff'
if [ "$(git -C "$r1" show hyperpowers/state:.gitignore 2>/dev/null)" = "$expected_ignore" ]; then pass ".gitignore keeps briefs and packages local"; else fail ".gitignore keeps briefs and packages local"; fi
if [ "$(git -C "$r1" show hyperpowers/state:.gitattributes 2>/dev/null)" = "plans/*/progress.md merge=union" ]; then pass ".gitattributes gives the ledger the union driver"; else fail ".gitattributes gives the ledger the union driver"; fi
if [ -f "$co1/README.md" ] && grep -q 'never merged into a code branch' "$co1/README.md"; then pass "README names the branch's purpose"; else fail "README names the branch's purpose"; fi
if [ "$(cat "$co1.backend")" = "branch" ]; then pass "backend file records branch"; else fail "backend file records branch"; fi
out2=$(ensure "$r1")
if [ "$out2" = "$out" ] && [ "$(git -C "$r1" rev-list --count hyperpowers/state)" = 1 ]; then pass "a second call is idempotent"; else fail "a second call is idempotent"; fi

# The legacy orphan path (git older than 2.42) builds the same branch.
r2="$TEST_ROOT/r2"; make_repo "$r2"
out=$(ensure "$r2" HYPERPOWERS_FORCE_LEGACY_ORPHAN=1); rc=$?
co2="$STATE_ROOT/$(state_key "$r2")"
if [ "$rc" -eq 0 ] && [ "$out" = "branch $co2" ] && [ "$(git -C "$r2" rev-list --count hyperpowers/state)" = 1 ] && [ "$(git -C "$r2" show hyperpowers/state:.hyperpowers-state)" = "hyperpowers-state 1" ] && [ "$(registrations "$r2")" -eq 1 ]; then pass "the legacy orphan path yields the same branch and checkout"; else fail "the legacy orphan path yields the same branch and checkout (rc=$rc, '$out')"; fi

# A foreign branch at the state name is refused, and the config key resolves it.
r3="$TEST_ROOT/r3"; make_repo "$r3"
git -C "$r3" branch hyperpowers/state
err=$(ensure "$r3" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'hyperpowers.stateBranch'; then pass "a foreign branch exits 2 naming the config key"; else fail "a foreign branch exits 2 naming the config key (rc=$rc: $err)"; fi
git -C "$r3" config hyperpowers.stateBranch other/state
out=$(ensure "$r3"); rc=$?
if [ "$rc" -eq 0 ] && git -C "$r3" rev-parse -q --verify other/state >/dev/null && [ "$(git -C "$r3" rev-list --count hyperpowers/state)" = 1 ]; then pass "the configured name is used and the foreign branch untouched"; else fail "the configured name is used and the foreign branch untouched"; fi

# With a remote and no fetch stamp, no orphan is invented.
make_pair p1
err=$(ensure "$PAIR_A" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'needs-sync' && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ]; then pass "a clone with a remote and no stamp gets needs-sync and no checkout"; else fail "a clone with a remote and no stamp gets needs-sync and no checkout (rc=$rc: $err)"; fi
: > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
out=$(ensure "$PAIR_A"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "branch $STATE_ROOT/$(state_key "$PAIR_A")" ]; then pass "the stamp allows the orphan"; else fail "the stamp allows the orphan (rc=$rc, '$out')"; fi

# A remote-tracking state branch is checked out with tracking, not recreated.
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
out=$(ensure "$PAIR_B"); rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$PAIR_B" rev-parse hyperpowers/state)" = "$(git -C "$PAIR_A" rev-parse hyperpowers/state)" ] && [ "$(git -C "$PAIR_B" config branch.hyperpowers/state.remote)" = origin ]; then pass "a fetched state branch is checked out tracking the remote"; else fail "a fetched state branch is checked out tracking the remote (rc=$rc)"; fi

# Crash after the worktree add: the next call starts clean.
r4="$TEST_ROOT/r4"; make_repo "$r4"
ensure "$r4" HYPERPOWERS_TEST_CRASH_AT=after-worktree-add >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 99 ] && ls -d "$STATE_ROOT/$(state_key "$r4").tmp-"* >/dev/null 2>&1; then pass "the crash hook stops after the worktree add"; else fail "the crash hook stops after the worktree add (rc=$rc)"; fi
out=$(ensure "$r4"); rc=$?
if [ "$rc" -eq 0 ] && [ "$(registrations "$r4")" -eq 1 ] && ! ls -d "$STATE_ROOT/$(state_key "$r4").tmp-"* >/dev/null 2>&1 && [ "$(git -C "$r4" rev-list --count hyperpowers/state)" = 1 ]; then pass "recovery after the worktree add leaves one registration and one commit"; else fail "recovery after the worktree add leaves one registration and one commit (rc=$rc, registrations=$(registrations "$r4"))"; fi

# Crash after the initial commit: the next call moves the finished checkout into place.
r5="$TEST_ROOT/r5"; make_repo "$r5"
ensure "$r5" HYPERPOWERS_TEST_CRASH_AT=after-initial-commit >/dev/null 2>&1; rc=$?
sha_before=$(git -C "$r5" rev-parse hyperpowers/state 2>/dev/null)
out=$(ensure "$r5"); rc2=$?
if [ "$rc" -eq 99 ] && [ "$rc2" -eq 0 ] && [ "$out" = "branch $STATE_ROOT/$(state_key "$r5")" ] && [ "$(git -C "$r5" rev-parse hyperpowers/state)" = "$sha_before" ] && [ "$(registrations "$r5")" -eq 1 ]; then pass "recovery after the initial commit keeps the commit and moves the checkout"; else fail "recovery after the initial commit keeps the commit and moves the checkout (rc=$rc/$rc2)"; fi

# Two concurrent first calls produce one checkout and one commit.
r6="$TEST_ROOT/r6"; make_repo "$r6"
( ensure "$r6" > "$TEST_ROOT/r6.out1" 2>/dev/null ) &
( ensure "$r6" > "$TEST_ROOT/r6.out2" 2>/dev/null ) &
wait
if [ "$(cat "$TEST_ROOT/r6.out1")" = "branch $STATE_ROOT/$(state_key "$r6")" ] && [ "$(cat "$TEST_ROOT/r6.out2")" = "$(cat "$TEST_ROOT/r6.out1")" ] && [ "$(registrations "$r6")" -eq 1 ] && [ "$(git -C "$r6" rev-list --count hyperpowers/state)" = 1 ]; then pass "concurrent first calls agree on one checkout"; else fail "concurrent first calls agree on one checkout"; fi

# The plain fallback is selected, persisted, and reversible.
r7="$TEST_ROOT/r7"; make_repo "$r7"
out=$(ensure "$r7" HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 2>/dev/null); rc=$?
plain7="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$r7")"
if [ "$rc" -eq 0 ] && [ "$out" = "plain $plain7" ] && [ "$(head -n1 "$STATE_ROOT/$(state_key "$r7").backend")" = plain ]; then pass "a failed worktree add selects and persists the plain backend"; else fail "a failed worktree add selects and persists the plain backend (rc=$rc, '$out')"; fi
out=$(ensure "$r7" 2>/dev/null)
if [ "$out" = "plain $plain7" ]; then pass "a later call honors the backend file"; else fail "a later call honors the backend file ('$out')"; fi
rm -f "$STATE_ROOT/$(state_key "$r7").backend"
out=$(ensure "$r7")
if [ "$out" = "branch $STATE_ROOT/$(state_key "$r7")" ]; then pass "deleting the backend file retries the branch backend"; else fail "deleting the backend file retries the branch backend ('$out')"; fi

# A repository kept on the plain backend for the plain-mode assertions of
# later sections (snapshot, finish, prune, sync, handoff).
rp="$TEST_ROOT/rp"; make_repo "$rp"
ensure "$rp" HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 >/dev/null 2>&1
mkdir -p "$rp/docs"; : > "$rp/docs/plan.md"; git -C "$rp" add docs; git -C "$rp" commit -qm plan
if [ "$(ensure "$rp" 2>/dev/null)" = "plain $XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$rp")" ]; then pass "the plain fixture repository stays plain"; else fail "the plain fixture repository stays plain"; fi

echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi
echo "STATUS: PASSED"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: `hp_ensure_checkout: command not found` from the first `ensure` call and `[FAIL]` lines after it.

- [ ] **Step 3: Append the creation section to the library**

Append to `skills/subagent-driven-development/scripts/sdd-common.sh`:

```bash

# --- checkout creation ------------------------------------------------------
hp_git_version_at_least() { # <major> <minor>
  local v maj rest min
  v=$(git --version | sed 's/^git version //; s/[^0-9.].*$//')
  maj=${v%%.*}; rest=${v#*.}; min=${rest%%.*}
  if [ "$maj" -gt "$1" ] 2>/dev/null; then return 0; fi
  [ "$maj" -eq "$1" ] 2>/dev/null && [ "$min" -ge "$2" ] 2>/dev/null
}

# <repo-dir> <commit>: 0 when the commit's root carries the sentinel. A
# branch at the state name without it is someone else's and is never used.
hp_check_sentinel() {
  local content
  content=$(git -C "$1" cat-file -p "$2:.hyperpowers-state" 2>/dev/null) || content=""
  if [ "$content" != "hyperpowers-state 1" ]; then
    echo "sdd-dir: branch $(hp_state_branch "$1") exists but is not a hyperpowers state branch; set git config hyperpowers.stateBranch to another name" >&2
    return 2
  fi
}

hp_write_root_files() { # <dir>
  printf 'hyperpowers-state 1\n' > "$1/.hyperpowers-state"
  printf '%s\n' '# Regenerable on any host: briefs come from task-brief, packages from review-package.' 'plans/*/task-*-brief.md' 'plans/*/review-*.diff' > "$1/.gitignore"
  printf 'plans/*/progress.md merge=union\n' > "$1/.gitattributes"
  printf '%s\n' '# hyperpowers state' '' 'This branch holds the SDD dossiers of this repository (progress ledgers, implementer reports, claims), one directory per plan under plans/. hyperpowers maintains it through skills/subagent-driven-development/scripts/sdd-state.' 'It shares no history with the code and is never merged into a code branch.' 'Design: docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md in the hyperpowers repository.' > "$1/README.md"
}

# <repo-dir> <path> <branch>: a worktree on an unborn branch. git 2.42 has
# --orphan; older git detaches at a throwaway empty commit and switches.
hp_add_orphan_worktree() {
  local repo=$1 path=$2 br=$3 empty_tree seed
  if [ -z "${HYPERPOWERS_FORCE_LEGACY_ORPHAN:-}" ] && hp_git_version_at_least 2 42; then
    git -C "$repo" worktree add -q --orphan -b "$br" "$path" >/dev/null 2>&1
  else
    empty_tree=$(git -C "$repo" hash-object -t tree /dev/null)
    seed=$(printf 'hyperpowers state seed\n' | hp_git_id "$repo" commit-tree "$empty_tree") || return 1
    git -C "$repo" worktree add -q --detach "$path" "$seed" >/dev/null 2>&1 || return 1
    git -C "$path" switch -q --orphan "$br" >/dev/null 2>&1
  fi
}

# <repo-dir> <checkout> <branch>: finish or undo an interrupted creation.
# A temporary checkout whose branch already carries the sentinel commit is
# moved into place; any other is removed. An interrupted orphan leaves no
# ref (the branch is unborn until its first commit), so there is nothing to
# delete; a branch with commits but no sentinel is foreign and refused later.
hp_recover_tmp_checkouts() {
  local repo=$1 co=$2 br=$3 wt tip
  git -C "$repo" worktree prune >/dev/null 2>&1 || true
  if [ -d "$co" ] && [ ! -e "$co/.git" ]; then rmdir "$co" 2>/dev/null || true; fi
  tip=$(git -C "$repo" rev-parse -q --verify "refs/heads/$br^{commit}" 2>/dev/null || true)
  for wt in "$co".tmp-*; do
    [ -e "$wt/.git" ] || continue
    if [ -n "$tip" ] && [ ! -e "$co/.git" ] && [ "$(git -C "$repo" cat-file -p "$tip:.hyperpowers-state" 2>/dev/null)" = "hyperpowers-state 1" ]; then
      if git -C "$repo" worktree move "$wt" "$co" >/dev/null 2>&1; then continue; fi
    fi
    git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
  done
  git -C "$repo" worktree prune >/dev/null 2>&1 || true
  rm -rf "$co".tmp-* 2>/dev/null || true
}

# <repo-dir> -> "branch <checkout>" or "plain <plain-root>". Exit 2 when the
# repository has a remote that has never been asked (needs-sync) or the
# state name belongs to a foreign branch. The one creation operation: it
# owns the lock, the temporary path, recovery, and the backend file.
hp_ensure_checkout() {
  local repo=$1 co br remote backend tmp mode tip rc=0
  co=$(hp_checkout_path "$repo") || return 2
  br=$(hp_state_branch "$repo"); remote=$(hp_state_remote "$repo")
  backend=$(hp_backend "$repo")
  if [ "$backend" = plain ]; then printf 'plain %s\n' "$(hp_plain_root "$repo")"; return 0; fi
  if [ -e "$co/.git" ]; then printf 'branch %s\n' "$co"; return 0; fi
  hp_lock "$repo" || return 2
  if [ -e "$co/.git" ]; then hp_unlock; printf 'branch %s\n' "$co"; return 0; fi
  hp_recover_tmp_checkouts "$repo" "$co" "$br"
  if [ -e "$co/.git" ]; then hp_write_backend "$repo" branch; hp_unlock; printf 'branch %s\n' "$co"; return 0; fi
  if tip=$(git -C "$repo" rev-parse -q --verify "refs/heads/$br^{commit}" 2>/dev/null); then
    hp_check_sentinel "$repo" "$tip" || { hp_unlock; return 2; }
    mode=local
  elif tip=$(git -C "$repo" rev-parse -q --verify "refs/remotes/$remote/$br^{commit}" 2>/dev/null); then
    hp_check_sentinel "$repo" "$tip" || { hp_unlock; return 2; }
    mode=remote
  else
    if hp_has_remote "$repo" && [ ! -f "$(hp_stamp_path "$repo")" ]; then
      echo "sdd-dir: status=needs-sync: this repository has a remote and no state branch here; run sdd-state sync <plan> first (or sdd-state sync --assume-absent <plan>)" >&2
      hp_unlock; return 2
    fi
    mode=orphan
  fi
  tmp="$co.tmp-$$-$RANDOM"
  mkdir -p "$(dirname "$co")"
  if [ -n "${HYPERPOWERS_TEST_FAIL_WORKTREE_ADD:-}" ]; then
    rc=1
  else
    case "$mode" in
      local) git -C "$repo" worktree add -q "$tmp" "$br" >/dev/null 2>&1 || rc=$? ;;
      remote) git -C "$repo" worktree add -q --track -b "$br" "$tmp" "$remote/$br" >/dev/null 2>&1 || rc=$? ;;
      orphan) hp_add_orphan_worktree "$repo" "$tmp" "$br" || rc=$? ;;
    esac
  fi
  if [ "$rc" -ne 0 ]; then
    echo "sdd-dir: git worktree add failed (rc=$rc); this repository uses the plain cache (backend=plain)" >&2
    git -C "$repo" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"
    hp_write_backend "$repo" plain
    hp_unlock; printf 'plain %s\n' "$(hp_plain_root "$repo")"; return 0
  fi
  if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = after-worktree-add ]; then hp_unlock; exit 99; fi
  if [ "$mode" = orphan ]; then
    hp_write_root_files "$tmp"
    hp_commit_paths "$tmp" "$br" "hyperpowers state: initial layout" . >/dev/null || { hp_unlock; return 2; }
  fi
  if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = after-initial-commit ]; then hp_unlock; exit 99; fi
  git -C "$repo" worktree move "$tmp" "$co" >/dev/null 2>&1 || { echo "sdd-dir: git worktree move failed" >&2; hp_unlock; return 2; }
  hp_write_backend "$repo" branch
  hp_unlock
  printf 'branch %s\n' "$co"
}

# <repo-dir> <ws> <dest-dir>: under the plain backend, copy the plan's
# workspace out of an existing state branch (local or remote-tracking) when
# the destination has no ledger yet. Records the source tip in the backend
# file. Callers hold the repository lock. A plain fallback never starts an
# empty ledger over branch state: a failed archive is exit 2, and the caller
# removes the half-written destination.
hp_materialize_plain() {
  local repo=$1 ws=$2 dest=$3 br remote tip root
  [ -f "$dest/progress.md" ] && return 0
  br=$(hp_state_branch "$repo"); remote=$(hp_state_remote "$repo")
  tip=$(git -C "$repo" rev-parse -q --verify "refs/heads/$br^{commit}" 2>/dev/null) \
    || tip=$(git -C "$repo" rev-parse -q --verify "refs/remotes/$remote/$br^{commit}" 2>/dev/null) \
    || return 0
  git -C "$repo" cat-file -e "$tip:plans/$ws/progress.md" 2>/dev/null || return 0
  root=$(dirname "$(dirname "$dest")")
  mkdir -p "$dest"
  git -C "$repo" archive "$tip" "plans/$ws" | tar -x -C "$root" || return 2
  hp_write_backend "$repo" "plain source=$tip"
}
```

- [ ] **Step 4: Run the tests**

Run: `bash tests/sdd/test-sdd-state.sh` and `bash tests/sdd/test-sdd-common.sh`
Expected: both end with `STATUS: PASSED`.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-common.sh tests/sdd/test-sdd-state.sh`
Expected: no findings.

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): create the state checkout once per clone, recover interrupted creations, fall back to the plain cache"
```

---

### Task 3: `sdd-state` skeleton with `snapshot` and `claim`

**Risk tier:** high — `snapshot` writes the durable record and `claim` is the concurrency primitive two sessions race on; takeover runs under the repository lock.

**Files:**
- Create: `skills/subagent-driven-development/scripts/sdd-state`
- Test: `tests/sdd/test-sdd-state.sh` (append the `snapshot` and `claim` sections above the closing STATUS lines)

**Interfaces:**
- Consumes: Task 1 and 2 functions from `sdd-common.sh`.
- Produces: the executable `sdd-state` with `usage`, `enc` (the percent-encoding routine every path-valued field uses), the globals `PLAN PLAN_DIR REPO WS SLUG BRANCH REMOTE CO BACKEND ROOT WSDIR`, the resolvers `resolve_plan_basic PLAN_FILE` (no checkout access) and `resolve_plan PLAN_FILE` (runs `hp_ensure_checkout`), `ledger_path`, and the subcommands `snapshot PLAN_FILE [-m MSG]` and `claim PLAN_FILE N --session SID [--takeover]`; both claim paths run under the repository lock, so they serialize with `finish` (Deviation 4); `claim` refuses with `status=no-workspace` (exit 2) when the workspace has no ledger (finished, or never started here) and answers `status=done task=N` (exit 0) when the ledger already records the task complete. Later tasks add one `cmd_<name>` function each and one `case` arm in the dispatcher at the bottom.

**Mirror:** `skills/requesting-code-review/scripts/ungated-ledger:25-50` for subcommand parsing of a bash helper with a trailing repo-dir; `skills/subagent-driven-development/scripts/review-package:1-30` for the header and exit-code comment style.

- [ ] **Step 1: Write the failing tests**

Insert above the closing `echo ""` / STATUS lines of `tests/sdd/test-sdd-state.sh`:

```bash
echo ""
echo "=== snapshot ==="
s1="$TEST_ROOT/s1"; make_repo "$s1"
mkdir -p "$s1/docs"; : > "$s1/docs/plan.md"
git -C "$s1" add docs/plan.md; git -C "$s1" commit -qm "plan"
ws1=$(ws_path "$s1" "$s1/docs/plan.md"); mkdir -p "$ws1"
co_s1="$STATE_ROOT/$(state_key "$s1")"
printf '# SDD ledger — plan: docs/plan.md\n' > "$ws1/progress.md"
printf 'brief\n' > "$ws1/task-1-brief.md"
printf 'diff\n' > "$ws1/review-abc1234..def5678.diff"
printf 'report\n' > "$ws1/task-1-report.md"
out=$(run_state "$s1" snapshot docs/plan.md); rc=$?
case "$out" in
    "status=snapshot sha="???????" files=2") pass "snapshot commits the ledger and the report, not the brief or the package" ;;
    *) fail "snapshot commits the ledger and the report, not the brief or the package (rc=$rc: $out)" ;;
esac
if ! git -C "$co_s1" ls-tree -r --name-only hyperpowers/state | grep -q 'task-1-brief.md' && git -C "$co_s1" ls-tree -r --name-only hyperpowers/state | grep -q "plans/$(basename "$ws1")/task-1-report.md"; then pass "the tree holds the report and not the brief"; else fail "the tree holds the report and not the brief"; fi
if [ "$(run_state "$s1" snapshot docs/plan.md)" = "status=none" ]; then pass "an unchanged workspace snapshots nothing"; else fail "an unchanged workspace snapshots nothing"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$ws1/progress.md"
out=$(run_state "$s1" snapshot docs/plan.md -m "custom message")
if [ "$(git -C "$co_s1" log -1 --format=%s hyperpowers/state)" = "custom message" ] && case "$out" in "status=snapshot sha="*" files=1") true;; *) false;; esac; then pass "-m sets the commit message and files counts the changed paths"; else fail "-m sets the commit message and files counts the changed paths ($out)"; fi
out=$(run_state "$s1" snapshot docs/nonexistent-plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ]; then pass "a plan file that does not exist is refused with exit 2"; else fail "a plan file that does not exist is refused with exit 2 (rc=$rc: $out)"; fi
if [ "$(run_state "$rp" snapshot docs/plan.md 2>/dev/null)" = "status=plain" ]; then pass "snapshot under the plain backend reports plain"; else fail "snapshot under the plain backend reports plain"; fi

# Two concurrent snapshots of two plans both land, each with only its own
# directory, while a third session has staged an unrelated file in the
# shared index.
s2="$TEST_ROOT/s2"; make_repo "$s2"
mkdir -p "$s2/docs"; : > "$s2/docs/p.md"; : > "$s2/docs/q.md"; git -C "$s2" add docs; git -C "$s2" commit -qm plans
wsp=$(ws_path "$s2" "$s2/docs/p.md"); wsq=$(ws_path "$s2" "$s2/docs/q.md"); mkdir -p "$wsp" "$wsq"
printf 'p\n' > "$wsp/progress.md"; printf 'q\n' > "$wsq/progress.md"
co_s2="$STATE_ROOT/$(state_key "$s2")"
git -C "$co_s2" add "plans/$(basename "$wsq")/progress.md"
( run_state "$s2" snapshot docs/p.md > "$TEST_ROOT/s2.p" 2>/dev/null ) &
( run_state "$s2" snapshot docs/q.md > "$TEST_ROOT/s2.q" 2>/dev/null ) &
wait
p_sha=$(sed -n 's/.*sha=\([0-9a-f]*\).*/\1/p' "$TEST_ROOT/s2.p"); q_sha=$(sed -n 's/.*sha=\([0-9a-f]*\).*/\1/p' "$TEST_ROOT/s2.q")
if [ "$(git -C "$co_s2" rev-list --count hyperpowers/state)" -eq 3 ] && [ -n "$p_sha" ] && [ -n "$q_sha" ] && [ "$(git -C "$co_s2" show --name-only --format= "$p_sha" | grep -c .)" = 1 ] && git -C "$co_s2" show --name-only --format= "$p_sha" | grep -q "^plans/$(basename "$wsp")/" && [ "$(git -C "$co_s2" show --name-only --format= "$q_sha" | grep -c .)" = 1 ]; then pass "two concurrent snapshots of two plans both land, each with only its own directory"; else fail "two concurrent snapshots of two plans both land, each with only its own directory ($(cat "$TEST_ROOT/s2.p") / $(cat "$TEST_ROOT/s2.q"))"; fi

echo ""
echo "=== claim ==="
c1="$TEST_ROOT/c1"; make_repo "$c1"
mkdir -p "$c1/docs"; : > "$c1/docs/plan.md"; git -C "$c1" add docs; git -C "$c1" commit -qm plan
wsc=$(ws_path "$c1" "$c1/docs/plan.md"); mkdir -p "$wsc"
printf '# SDD ledger — plan: docs/plan.md\n' > "$wsc/progress.md"
( run_state "$c1" claim docs/plan.md 1 --session s-one > "$TEST_ROOT/c1.o1" 2>/dev/null; echo $? > "$TEST_ROOT/c1.rc1" ) &
( run_state "$c1" claim docs/plan.md 1 --session s-two > "$TEST_ROOT/c1.o2" 2>/dev/null; echo $? > "$TEST_ROOT/c1.rc2" ) &
wait
rcs="$(cat "$TEST_ROOT/c1.rc1") $(cat "$TEST_ROOT/c1.rc2")"
outs="$(cat "$TEST_ROOT/c1.o1")
$(cat "$TEST_ROOT/c1.o2")"
case "$rcs" in "0 4"|"4 0") pass "two concurrent claims: one claimed, one held" ;; *) fail "two concurrent claims: one claimed, one held (rcs: $rcs)" ;; esac
if printf '%s\n' "$outs" | grep -q '^status=claimed task=1$' && printf '%s\n' "$outs" | grep -Eq '^status=held task=1 owner=s-(one|two) since=[0-9TZ:-]+ worktree=/'; then pass "the loser's line carries the winner's complete owner record"; else fail "the loser's line carries the winner's complete owner record ($outs)"; fi
winner=$(sed -n 's/^session=//p' "$wsc/claims/task-1/owner")
out=$(run_state "$c1" claim docs/plan.md 1 --session "$winner"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=held task=1 owner=$winner own=1" ]; then pass "re-claiming with the owner's own session exits 0"; else fail "re-claiming with the owner's own session exits 0 (rc=$rc: $out)"; fi
if grep -q "^worktree=$c1$" "$wsc/claims/task-1/owner" && grep -q '^branch=main$' "$wsc/claims/task-1/owner" && grep -q '^host=' "$wsc/claims/task-1/owner"; then pass "the owner record names worktree, branch and host"; else fail "the owner record names worktree, branch and host"; fi
mkdir -p "$wsc/claims/.tmp-prepared"; printf 'session=ghost\n' > "$wsc/claims/.tmp-prepared/owner"
out=$(run_state "$c1" claim docs/plan.md 2 --session s-three); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=2" ]; then pass "a prepared but unpublished claim is invisible to the next claimant"; else fail "a prepared but unpublished claim is invisible to the next claimant (rc=$rc: $out)"; fi
out=$(run_state "$c1" claim docs/plan.md 1 --session s-four --takeover); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 takeover=1" ] && [ "$(sed -n 's/^session=//p' "$wsc/claims/task-1/owner")" = s-four ] && grep -q "^session=$winner" "$wsc/claims/task-1/owner.history"; then pass "--takeover rewrites the owner and keeps the history"; else fail "--takeover rewrites the owner and keeps the history (rc=$rc: $out)"; fi
if run_state "$c1" claim docs/plan.md 3 >/dev/null 2>&1; then fail "claim without --session is a usage error"; else pass "claim without --session is a usage error"; fi
bash -c '. "$1"; hp_lock "$2"; sleep 1.5; hp_unlock' _ "$LIB" "$c1" &
sleep 0.3; start=$(date +%s); out=$(run_state "$c1" claim docs/plan.md 4 --session s-seven); end=$(date +%s); wait
if [ "$out" = "status=claimed task=4" ] && [ $((end - start)) -ge 1 ]; then pass "claim waits for the repository lock, so it serializes with finish"; else fail "claim waits for the repository lock ($out, waited $((end - start))s)"; fi
printf 'Task 5: complete (commits 1111111..2222222, review clean)\n' >> "$wsc/progress.md"
out=$(run_state "$c1" claim docs/plan.md 5 --session s-eight); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=done task=5" ] && [ ! -d "$wsc/claims/task-5" ]; then pass "a task the ledger records complete is not claimed"; else fail "a task the ledger records complete is not claimed (rc=$rc: $out)"; fi
c2="$TEST_ROOT/c2"; make_repo "$c2"
mkdir -p "$c2/docs"; : > "$c2/docs/plan.md"; git -C "$c2" add docs; git -C "$c2" commit -qm plan
wsc2=$(ws_path "$c2" "$c2/docs/plan.md")
out=$(run_state "$c2" claim docs/plan.md 1 --session s-nine); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=no-workspace task=1" ] && [ ! -d "$wsc2/claims" ]; then pass "a workspace without a ledger cannot be claimed into existence"; else fail "a workspace without a ledger cannot be claimed into existence (rc=$rc: $out)"; fi
mkdir -p "$TEST_ROOT/with space"; c3="$TEST_ROOT/with space/repo"; make_repo "$c3"
mkdir -p "$c3/docs"; : > "$c3/docs/plan.md"; git -C "$c3" add docs; git -C "$c3" commit -qm plan
wsc3=$(ws_path "$c3" "$c3/docs/plan.md"); mkdir -p "$wsc3"; printf '# SDD ledger — plan: docs/plan.md\n' > "$wsc3/progress.md"
run_state "$c3" claim docs/plan.md 1 --session s-ten >/dev/null
out=$(run_state "$c3" claim docs/plan.md 1 --session s-eleven)
if grep -q "worktree=$(printf '%s' "$c3" | sed 's/ /%20/g')" < <(printf '%s\n' "$out"); then pass "a worktree path with a space is percent-encoded in held output"; else fail "a worktree path with a space is percent-encoded in held output ($out)"; fi
( run_state "$c1" claim docs/plan.md 1 --session s-five --takeover > "$TEST_ROOT/c1.t1" 2>/dev/null ) &
( run_state "$c1" claim docs/plan.md 1 --session s-six --takeover > "$TEST_ROOT/c1.t2" 2>/dev/null ) &
wait
final=$(sed -n 's/^session=//p' "$wsc/claims/task-1/owner")
if { [ "$final" = s-five ] || [ "$final" = s-six ]; } && [ "$(grep -c '^--- superseded' "$wsc/claims/task-1/owner.history")" -eq 3 ]; then pass "concurrent takeovers serialize: one final owner, every supersession recorded"; else fail "concurrent takeovers serialize ($final)"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: the creation section passes; the new sections fail because `sdd-state` does not exist.

- [ ] **Step 3: Write the helper**

Create `skills/subagent-driven-development/scripts/sdd-state`:

```bash
#!/usr/bin/env bash
# sdd-state — lifecycle helper for the SDD state branch, the durable home of
# a plan's dossier (ledger, reports, claims). Design and contracts:
# docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md.
#
# Usage:
#   sdd-state sync PLAN_FILE [--assume-absent]      (or: sync --repo DIR [--assume-absent])
#   sdd-state verify PLAN_FILE [--code-repo DIR]
#   sdd-state snapshot PLAN_FILE [-m MSG]
#   sdd-state handoff PLAN_FILE [--push] [--plan-untracked-ok] [--code-dirty-ok] [--code-repo DIR]
#   sdd-state finish PLAN_FILE [--force]
#   sdd-state import PLAN_FILE
#   sdd-state prune [--days N] [--apply] --repo DIR
#   sdd-state claim PLAN_FILE N --session SID [--takeover]
#
# stdout: one line of space-separated key=value pairs, status= first; sync
# adds a second line "merge=<command>" on diverged.
# exit: 0 ok | 1 offline, offline-no-state, push-failed | 2 usage or internal
#       (needs-sync, foreign branch, import-failed) | 3 diverged, busy |
#       4 claim held by another session | 5 scan-failed | 6 open-claims |
#       7 plain backend (handoff) | 8 plan-not-committed |
#       9 wrong-repo, code-missing, plan-stale | 10 code-dirty
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sdd-common.sh
. "$SCRIPT_DIR/sdd-common.sh"

usage() {
  printf '%s\n' \
    'usage: sdd-state <subcommand> ...' \
    '  sync PLAN_FILE [--assume-absent]   |   sync --repo DIR [--assume-absent]' \
    '  verify PLAN_FILE [--code-repo DIR]' \
    '  snapshot PLAN_FILE [-m MSG]' \
    '  handoff PLAN_FILE [--push] [--plan-untracked-ok] [--code-dirty-ok] [--code-repo DIR]' \
    '  finish PLAN_FILE [--force]' \
    '  import PLAN_FILE' \
    '  prune [--days N] [--apply] --repo DIR' \
    '  claim PLAN_FILE N --session SID [--takeover]' >&2
  exit 2
}

PLAN=""; PLAN_DIR=""; REPO=""; WS=""; SLUG=""; BRANCH=""; REMOTE=""; CO=""; BACKEND=""; ROOT=""; WSDIR=""

# Resolve PLAN_FILE without touching the checkout: sync fetches first.
resolve_plan_basic() {
  PLAN=$1
  PLAN_DIR=$(hp_plan_dir "$PLAN") || { echo "sdd-state: plan file is not inside a git repository: $PLAN" >&2; exit 2; }
  REPO=$(hp_physical_dir "$(git -C "$PLAN_DIR" rev-parse --show-toplevel)")
  WS=$(hp_plan_ws_name "$PLAN")
  SLUG=${WS%-*}
  BRANCH=$(hp_state_branch "$PLAN_DIR")
  REMOTE=$(hp_state_remote "$PLAN_DIR")
  CO=$(hp_checkout_path "$PLAN_DIR")
}
# Resolve and make sure the checkout (or the plain root) exists.
resolve_plan() {
  local ensure
  resolve_plan_basic "$1"
  ensure=$(hp_ensure_checkout "$PLAN_DIR") || exit 2
  BACKEND=${ensure%% *}
  ROOT=${ensure#* }
  WSDIR="$ROOT/plans/$WS"
}
ledger_path() { printf '%s/progress.md\n' "$WSDIR"; }
# One encoding for every path-valued stdout field: a space becomes %20.
enc() { printf '%s' "$1" | sed 's/ /%20/g'; }
owner_record() { # <sid>
  local top b
  top=$(git rev-parse --show-toplevel 2>/dev/null) || top=$(pwd -P)
  b=$(git branch --show-current 2>/dev/null)
  [ -n "$b" ] || b="detached@$(git rev-parse --short=7 HEAD 2>/dev/null || echo none)"
  printf 'session=%s\nworktree=%s\nbranch=%s\nhost=%s\ntime=%s\n' "$1" "$top" "$b" "$(hostname)" "$(hp_utc_now)"
}

# --- snapshot ----------------------------------------------------------------
cmd_snapshot() {
  local plan="" msg="" out rc n
  while [ $# -gt 0 ]; do
    case "$1" in
      -m) [ $# -ge 2 ] || usage; msg=$2; shift 2 ;;
      -*) usage ;;
      *) plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] || usage
  resolve_plan "$plan"
  if [ "$BACKEND" != branch ]; then echo "status=plain"; return 0; fi
  [ -d "$WSDIR" ] || { echo "status=none"; return 0; }
  [ -n "$msg" ] || msg="sdd $SLUG: snapshot $(hp_utc_now)"
  hp_lock "$PLAN_DIR" || return 2
  out=$(hp_commit_paths "$CO" "$BRANCH" "$msg" "plans/$WS"); rc=$?
  hp_unlock
  [ "$rc" -eq 0 ] || { echo "status=error"; return 2; }
  if [ "$out" = none ]; then echo "status=none"; return 0; fi
  n=$(git -C "$CO" show --name-only --format= "$out" | grep -c .)
  echo "status=snapshot sha=${out:0:7} files=$n"
}

# --- claim -------------------------------------------------------------------
# The record is prepared in a temporary directory and published with one
# rename(2), through node because a shell mv on macOS moves a directory into
# an existing target instead of failing. A loser never sees a claim without
# its owner file. Publication and takeover run under the repository lock,
# the same lock finish holds while it reads the claims and removes the
# workspace, so a claim can never slip in between those two steps.
cmd_claim() {
  local plan="" n="" sid="" takeover=0 claims target tmp rc owner
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      --takeover) takeover=1; shift ;;
      -*) usage ;;
      *) if [ -z "$plan" ]; then plan=$1; else n=$1; fi; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$n" ] && [ -n "$sid" ] || usage
  resolve_plan "$plan"
  claims="$WSDIR/claims"; target="$claims/task-$n"
  # Everything below runs under the repository lock, the same lock finish
  # holds while it reads the claims and removes the workspace: a claim can
  # never slip in between those steps, and never resurrect a finished one.
  hp_lock "$PLAN_DIR" || return 2
  if [ ! -f "$WSDIR/progress.md" ]; then hp_unlock; echo "status=no-workspace task=$n"; return 2; fi
  if grep -Eq "(^|[^A-Za-z0-9])Task $n: complete" "$WSDIR/progress.md"; then hp_unlock; echo "status=done task=$n"; return 0; fi
  mkdir -p "$claims" || { hp_unlock; echo "status=error"; return 2; }
  if [ "$takeover" -eq 1 ] && [ -d "$target" ]; then
    { printf -- '--- superseded at %s\n' "$(hp_utc_now)"; cat "$target/owner" 2>/dev/null; } >> "$target/owner.history"
    owner_record "$sid" > "$target/owner.new" && mv -f "$target/owner.new" "$target/owner"
    hp_unlock
    echo "status=claimed task=$n takeover=1"; return 0
  fi
  tmp=$(mktemp -d "$claims/.tmp-XXXXXX") || { hp_unlock; echo "status=error"; return 2; }
  owner_record "$sid" > "$tmp/owner"
  node -e 'const fs=require("fs");try{fs.renameSync(process.argv[1],process.argv[2]);}catch(e){process.exit(e.code==="ENOTEMPTY"||e.code==="EEXIST"?4:2);}' "$tmp" "$target"; rc=$?
  if [ "$rc" -eq 0 ]; then hp_unlock; echo "status=claimed task=$n"; return 0; fi
  rm -rf "$tmp"
  hp_unlock
  [ "$rc" -eq 4 ] || { echo "status=error"; return 2; }
  owner=$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null)
  if [ "$owner" = "$sid" ]; then echo "status=held task=$n owner=$owner own=1"; return 0; fi
  echo "status=held task=$n owner=$owner since=$(sed -n 's/^time=//p' "$target/owner" 2>/dev/null) worktree=$(enc "$(sed -n 's/^worktree=//p' "$target/owner" 2>/dev/null)")"
  return 4
}

# --- dispatch ----------------------------------------------------------------
sub=${1:-}
[ -n "$sub" ] || usage
shift
case "$sub" in
  snapshot) cmd_snapshot "$@" ;;
  claim) cmd_claim "$@" ;;
  *) usage ;;
esac
```

- [ ] **Step 4: Run the tests**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: `STATUS: PASSED`. The new sections build their workspace path with the scaffold's `ws_path`, so they do not depend on the `sdd-dir` rewrite of Task 5.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh`

```bash
chmod +x skills/subagent-driven-development/scripts/sdd-state
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): sdd-state with snapshot and atomic claims"
```

---

### Task 4: `sdd-state import`

**Risk tier:** high — it moves a dossier out of the legacy cache and removes the source; a wrong step loses a ledger. The copy is staged beside the destination and compared by manifest before anything is removed.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (add `rewrite_identity_line`, `tree_manifest`, `verify_subset`, `cmd_import`, and the `import` dispatch arm)
- Test: `tests/sdd/test-sdd-state.sh` (append the `import` section above the closing STATUS lines)

**Interfaces:**
- Consumes: `resolve_plan`, `hp_lock`/`hp_unlock`, `hp_legacy_key`, `hp_key`, `hp_cache_root`, `hp_physical_dir`, `hp_materialize_plain`.
- Produces: `sdd-state import PLAN_FILE` printing `status=moved from=<path>`, `status=skipped reason=ledger-exists path=<path>`, `status=none`, or `status=import-failed from=<path>` (exit 2, source intact, no ledger left in the destination); the globals `IDENTITY_PREFIX` (the literal `# SDD ledger — plan: ` with U+2014) and `rewrite_identity_line LEDGER REL`, which rewrites an absolute identity that lies inside the plan repository, or that ends with `/<rel>` (a path from another host), to `<rel>`.

- [ ] **Step 1: Write the failing tests**

Insert above the closing STATUS lines of `tests/sdd/test-sdd-state.sh`:

```bash
echo ""
echo "=== import ==="
i1="$TEST_ROOT/i1"; make_repo "$i1"
mkdir -p "$i1/docs"; : > "$i1/docs/plan.md"; git -C "$i1" add docs; git -C "$i1" commit -qm plan
wsi=$(ws_path "$i1" "$i1/docs/plan.md")
legacy_i1="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i1")/plans/$(basename "$wsi")"
mkdir -p "$legacy_i1"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' "$i1" > "$legacy_i1/progress.md"
printf 'report\n' > "$legacy_i1/task-1-report.md"
printf 'brief\n' > "$legacy_i1/task-1-brief.md"
out=$(run_state "$i1" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i1" ] && [ -f "$wsi/task-1-report.md" ] && [ -f "$wsi/task-1-brief.md" ]; then pass "import moves a legacy workspace into the checkout"; else fail "import moves a legacy workspace into the checkout (rc=$rc: $out)"; fi
if [ "$(head -n 1 "$wsi/progress.md")" = "# SDD ledger — plan: docs/plan.md" ] && [ "$(sed -n 2p "$wsi/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "an absolute identity line is rewritten to the repo-relative form"; else fail "an absolute identity line is rewritten to the repo-relative form ($(head -n 1 "$wsi/progress.md"))"; fi
if [ -L "$legacy_i1" ] && [ "$(cd "$legacy_i1" && pwd -P)" = "$(cd "$wsi" && pwd -P)" ]; then pass "the legacy location becomes a symlink to the new workspace"; else fail "the legacy location becomes a symlink to the new workspace"; fi
if [ "$(run_state "$i1" import docs/plan.md)" = "status=none" ]; then pass "a second import finds nothing"; else fail "a second import finds nothing"; fi
other="$XDG_CACHE_HOME/hyperpowers/sdd/otherkey00000000/plans/$(basename "$wsi")"
mkdir -p "$other"; printf '# SDD ledger — plan: docs/plan.md\n' > "$other/progress.md"
pointer="$XDG_CACHE_HOME/hyperpowers/sdd/cwdkey0000000000/plans/$(basename "$wsi")+otherkey"
mkdir -p "$(dirname "$pointer")"; ln -s "$other" "$pointer"
out=$(run_state "$i1" import docs/plan.md)
if [ "$out" = "status=skipped reason=ledger-exists path=$pointer" ] && [ -d "$other" ]; then pass "a candidate behind an existing ledger is left alone and named"; else fail "a candidate behind an existing ledger is left alone and named ($out)"; fi

# A pointer candidate is relinked to the new workspace after the move.
i2="$TEST_ROOT/i2"; make_repo "$i2"
mkdir -p "$i2/docs"; : > "$i2/docs/plan.md"; git -C "$i2" add docs; git -C "$i2" commit -qm plan
wsi2=$(ws_path "$i2" "$i2/docs/plan.md")
real2="$XDG_CACHE_HOME/hyperpowers/sdd/legacykey0000000/plans/$(basename "$wsi2")"
ptr2="$XDG_CACHE_HOME/hyperpowers/sdd/cwdkey0000000001/plans/$(basename "$wsi2")+legacyke"
mkdir -p "$real2" "$(dirname "$ptr2")"; printf '# SDD ledger — plan: docs/plan.md\n' > "$real2/progress.md"; ln -s "$real2" "$ptr2"
out=$(run_state "$i2" import docs/plan.md)
if [ "$out" = "status=moved from=$ptr2" ] && [ -f "$wsi2/progress.md" ] && [ -L "$ptr2" ] && [ "$(cd "$ptr2" && pwd -P)" = "$(cd "$wsi2" && pwd -P)" ] && [ ! -d "$real2" ]; then pass "a pointer candidate is moved and relinked"; else fail "a pointer candidate is moved and relinked ($out)"; fi

# A failed verification leaves the source intact.
i3="$TEST_ROOT/i3"; make_repo "$i3"
mkdir -p "$i3/docs"; : > "$i3/docs/plan.md"; git -C "$i3" add docs; git -C "$i3" commit -qm plan
wsi3=$(ws_path "$i3" "$i3/docs/plan.md")
legacy_i3="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i3")/plans/$(basename "$wsi3")"
mkdir -p "$legacy_i3"; printf '# SDD ledger — plan: docs/plan.md\n' > "$legacy_i3/progress.md"; printf 'secret\n' > "$legacy_i3/task-1-report.md"
chmod 000 "$legacy_i3/task-1-report.md"
out=$(run_state "$i3" import docs/plan.md 2>/dev/null); rc=$?
chmod 644 "$legacy_i3/task-1-report.md"
if [ "$rc" -eq 2 ] && [ "$out" = "status=import-failed from=$legacy_i3" ] && [ -d "$legacy_i3" ] && [ ! -L "$legacy_i3" ] && [ -f "$legacy_i3/progress.md" ] && [ ! -f "$wsi3/progress.md" ] && ! ls -d "$wsi3.import-"* >/dev/null 2>&1; then pass "a failed copy exits 2, keeps the source, and leaves no ledger or staging behind"; else fail "a failed copy exits 2, keeps the source, and leaves no ledger or staging behind (rc=$rc: $out)"; fi
out=$(run_state "$i3" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i3" ] && [ -f "$wsi3/task-1-report.md" ]; then pass "the next import succeeds once the source is readable"; else fail "the next import succeeds once the source is readable (rc=$rc: $out)"; fi

# An identity line written on another host (an absolute path that does not
# exist here) is rewritten by its suffix; one naming a different plan is left.
i4="$TEST_ROOT/i4"; make_repo "$i4"
mkdir -p "$i4/docs"; : > "$i4/docs/plan.md"; git -C "$i4" add docs; git -C "$i4" commit -qm plan
wsi4=$(ws_path "$i4" "$i4/docs/plan.md")
legacy_i4="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i4")/plans/$(basename "$wsi4")"
mkdir -p "$legacy_i4"; printf '# SDD ledger — plan: /home/someone/else/docs/plan.md\n' > "$legacy_i4/progress.md"
run_state "$i4" import docs/plan.md >/dev/null
if [ "$(head -n 1 "$wsi4/progress.md")" = "# SDD ledger — plan: docs/plan.md" ]; then pass "a foreign-host absolute identity ending in the plan's relative path is rewritten"; else fail "a foreign-host absolute identity ending in the plan's relative path is rewritten ($(head -n 1 "$wsi4/progress.md"))"; fi
i5="$TEST_ROOT/i5"; make_repo "$i5"
mkdir -p "$i5/docs"; : > "$i5/docs/plan.md"; git -C "$i5" add docs; git -C "$i5" commit -qm plan
wsi5=$(ws_path "$i5" "$i5/docs/plan.md")
legacy_i5="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i5")/plans/$(basename "$wsi5")"
mkdir -p "$legacy_i5"; printf '# SDD ledger — plan: /home/someone/else/docs/other.md\n' > "$legacy_i5/progress.md"
run_state "$i5" import docs/plan.md >/dev/null
if [ "$(head -n 1 "$wsi5/progress.md")" = "# SDD ledger — plan: /home/someone/else/docs/other.md" ]; then pass "an identity naming a genuinely different plan is left for the controller to flag"; else fail "an identity naming a genuinely different plan is left for the controller to flag"; fi

# A pointer that belongs to another repository with a plan at the same
# relative path is never a candidate.
j1="$TEST_ROOT/j1"; make_repo "$j1"; j2="$TEST_ROOT/j2"; make_repo "$j2"
for r in "$j1" "$j2"; do mkdir -p "$r/docs"; : > "$r/docs/plan.md"; git -C "$r" add docs; git -C "$r" commit -qm plan; done
wsj1=$(ws_path "$j1" "$j1/docs/plan.md"); wsj2=$(ws_path "$j2" "$j2/docs/plan.md")
if [ "$(basename "$wsj1")" = "$(basename "$wsj2")" ]; then pass "two repositories with one relative plan path share a workspace name"; else fail "two repositories with one relative plan path share a workspace name"; fi
foreign_real="$XDG_CACHE_HOME/hyperpowers/sdd/foreignkey000000/plans/$(basename "$wsj1")"
foreign_ptr="$XDG_CACHE_HOME/hyperpowers/sdd/somecwdkey00000/plans/$(basename "$wsj1")+$(state_key "$j2" | cut -c1-8)"
mkdir -p "$foreign_real" "$(dirname "$foreign_ptr")"; printf '# SDD ledger — plan: docs/plan.md\nforeign\n' > "$foreign_real/progress.md"; ln -s "$foreign_real" "$foreign_ptr"
out=$(run_state "$j1" import docs/plan.md)
if [ "$out" = "status=none" ] && [ -d "$foreign_real" ] && [ ! -f "$wsj1/progress.md" ]; then pass "a pointer with another repository's key suffix is not a candidate"; else fail "a pointer with another repository's key suffix is not a candidate ($out)"; fi
# The cwd repository's own legacy workspace of the same name is not a
# candidate for another repository's plan.
own_j2="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$j2")/plans/$(basename "$wsj2")"
mkdir -p "$own_j2"; printf '# SDD ledger — plan: docs/plan.md\nj2 own\n' > "$own_j2/progress.md"
out=$(cd "$j2" && bash "$SDD_STATE" import "$j1/docs/plan.md")
if [ "$out" = "status=none" ] && [ -d "$own_j2" ] && [ ! -L "$own_j2" ] && [ ! -f "$wsj1/progress.md" ]; then pass "the cwd repository's same-named workspace is not consumed for another repository's plan"; else fail "the cwd repository's same-named workspace is not consumed ($out)"; fi

# Two concurrent imports of one legacy workspace: one moves it, the other
# finds the ledger in place; nothing is copied twice or overwritten.
i6="$TEST_ROOT/i6"; make_repo "$i6"
mkdir -p "$i6/docs"; : > "$i6/docs/plan.md"; git -C "$i6" add docs; git -C "$i6" commit -qm plan
wsi6=$(ws_path "$i6" "$i6/docs/plan.md")
legacy_i6="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i6")/plans/$(basename "$wsi6")"
mkdir -p "$legacy_i6"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i6/progress.md"
( run_state "$i6" import docs/plan.md > "$TEST_ROOT/i6.o1" 2>/dev/null ) &
( run_state "$i6" import docs/plan.md > "$TEST_ROOT/i6.o2" 2>/dev/null ) &
wait
moved=$(cat "$TEST_ROOT/i6.o1" "$TEST_ROOT/i6.o2" | grep -c '^status=moved')
if [ "$moved" -eq 1 ] && [ "$(sed -n 2p "$wsi6/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && [ -L "$legacy_i6" ]; then pass "concurrent imports move the workspace once and leave the ledger intact"; else fail "concurrent imports move the workspace once and leave the ledger intact ($(cat "$TEST_ROOT/i6.o1") / $(cat "$TEST_ROOT/i6.o2"))"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: the `import` section fails with the usage message (unknown subcommand).

- [ ] **Step 3: Add `import` to the helper**

Insert before the `# --- dispatch` block of `sdd-state`:

```bash
# --- import ------------------------------------------------------------------
# Move a workspace an older plugin (or a plain-backend run) left in the plain
# cache into place. Candidates resolve to their physical referents; the copy
# is staged beside the destination, compared with the source by manifest, and
# only then installed and the source replaced by a symlink. A failure leaves
# the source untouched and no ledger in the destination, so the next call
# retries instead of reporting ledger-exists.
IDENTITY_PREFIX="# SDD ledger $(printf '\xe2\x80\x94') plan: "
rewrite_identity_line() { # <ledger> <rel>: an absolute identity inside REPO, or ending in /<rel>, becomes <rel>
  local first path tmp
  first=$(head -n 1 "$1")
  case "$first" in
    "$IDENTITY_PREFIX"/*) path=${first#"$IDENTITY_PREFIX"} ;;
    *) return 0 ;;
  esac
  case "$path" in
    "$REPO"/*) [ "${path#"$REPO"/}" = "$2" ] || return 0 ;;
    */"$2") ;;
    *) return 0 ;;
  esac
  tmp="$1.tmp.$$"
  { printf '%s%s\n' "$IDENTITY_PREFIX" "$2"; tail -n +2 "$1"; } > "$tmp" && mv -f "$tmp" "$1"
}
# <dir> -> one line per entry: type, size or link target, path; sorted.
tree_manifest() {
  ( cd "$1" && find . -mindepth 1 \( -type f -o -type d -o -type l \) | LC_ALL=C sort | while IFS= read -r e; do
      if [ -L "$e" ]; then printf 'l %s %s\n' "$(readlink "$e")" "$e"
      elif [ -f "$e" ]; then printf 'f %s %s\n' "$(wc -c < "$e" | tr -d ' ')" "$e"
      else printf 'd - %s\n' "$e"; fi
    done )
}
# <src> <dst>: every entry of src is in dst with the same type and size.
verify_subset() {
  local line dst_manifest
  dst_manifest=$(tree_manifest "$2")
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    grep -Fxq -- "$line" < <(printf '%s\n' "$dst_manifest") || return 1
  done < <(tree_manifest "$1")
  return 0
}
cmd_import() {
  local plan cache candidates c ref dest dest_phys seen="" stage e rel
  [ $# -eq 1 ] || usage
  plan=$1
  resolve_plan "$plan"
  dest="$WSDIR"
  rel=$(hp_plan_rel "$plan")
  cache="$(hp_cache_root)/sdd"
  if [ "$BACKEND" = plain ]; then
    hp_lock "$PLAN_DIR" || return 2
    if ! hp_materialize_plain "$PLAN_DIR" "$WS" "$dest"; then rm -rf "$dest"; hp_unlock; echo "status=import-failed from=$BRANCH"; return 2; fi
    hp_unlock
  fi
  candidates="$cache/$(hp_legacy_key "$PLAN_DIR")/plans/$WS"
  # The cwd's unsuffixed legacy workspace qualifies only when the cwd is a
  # worktree of the plan repository: another repository with a plan at the
  # same relative path owns a workspace of the same name, and a cross-
  # repository run before 6.16.0 left ambiguous copies that stay manual.
  if git rev-parse --git-dir >/dev/null 2>&1 && [ "$(hp_key .)" = "$(hp_key "$PLAN_DIR")" ]; then
    candidates="$candidates
$cache/$(hp_legacy_key .)/plans/$WS"
  fi
  # Pointers carry the plan repository's key prefix as their suffix; only
  # this repository's suffixes qualify, so another repository that happens
  # to hold a plan at the same relative path is never touched.
  for c in "$cache"/*/plans/"$WS"+"$(hp_legacy_key "$PLAN_DIR" | cut -c1-8)" "$cache"/*/plans/"$WS"+"$(hp_key "$PLAN_DIR" | cut -c1-8)"; do
    [ -e "$c" ] && candidates="$candidates
$c"
  done
  if [ "$BACKEND" = branch ]; then
    candidates="$candidates
$cache/$(hp_key "$PLAN_DIR")/plans/$WS"
  fi
  # The lock is taken before any candidate is resolved or the destination is
  # read, so two importers cannot both find the destination empty.
  hp_lock "$PLAN_DIR" || return 2
  dest_phys=$(hp_physical_dir "$dest" 2>/dev/null) || dest_phys=$dest
  while IFS= read -r c; do
    [ -n "$c" ] && [ -e "$c" ] || continue
    ref=$(hp_physical_dir "$c") || continue
    [ "$ref" != "$dest_phys" ] || continue
    case " $seen " in *" $ref "*) continue ;; esac
    seen="$seen $ref"
    [ -f "$ref/progress.md" ] || continue
    if [ -f "$dest/progress.md" ]; then hp_unlock; echo "status=skipped reason=ledger-exists path=$(enc "$c")"; return 0; fi
    stage="$dest.import-$$"
    rm -rf "$stage"; mkdir -p "$stage"
    if ! cp -a "$ref/." "$stage/" 2>/dev/null || [ "$(tree_manifest "$ref")" != "$(tree_manifest "$stage")" ]; then
      rm -rf "$stage"; hp_unlock; echo "status=import-failed from=$(enc "$c")"; return 2
    fi
    rewrite_identity_line "$stage/progress.md" "$rel"
    if [ ! -d "$dest" ] || [ -z "$(ls -A "$dest" 2>/dev/null)" ]; then
      rmdir "$dest" 2>/dev/null
      mv "$stage" "$dest" || { rm -rf "$stage"; hp_unlock; echo "status=import-failed from=$(enc "$c")"; return 2; }
    else
      # The destination already holds regenerable files: install the staged
      # entries one by one, the ledger last, so a failure leaves no ledger.
      for e in "$stage"/* "$stage"/.[!.]*; do
        [ -e "$e" ] || [ -L "$e" ] || continue
        [ "$(basename "$e")" != progress.md ] || continue
        if ! mv -f "$e" "$dest/" 2>/dev/null; then cp -a "$e" "$dest/" || { rm -rf "$stage"; hp_unlock; echo "status=import-failed from=$(enc "$c")"; return 2; }; fi
      done
      mv -f "$stage/progress.md" "$dest/progress.md" || { rm -rf "$stage"; hp_unlock; echo "status=import-failed from=$(enc "$c")"; return 2; }
      rm -rf "$stage"
      if ! verify_subset "$ref" "$dest"; then rm -f "$dest/progress.md"; hp_unlock; echo "status=import-failed from=$(enc "$c")"; return 2; fi
    fi
    if [ -L "$c" ]; then rm -rf "$ref"; ln -sfn "$dest" "$c"; else rm -rf "$ref"; ln -s "$dest" "$ref"; fi
    hp_unlock
    echo "status=moved from=$(enc "$c")"
    return 0
  done < <(printf '%s\n' "$candidates")
  hp_unlock
  echo "status=none"
}
```

Add the dispatch arm `import) cmd_import "$@" ;;` beside `snapshot)`.

- [ ] **Step 4: Run the tests**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: `STATUS: PASSED`.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh`

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): import a legacy workspace into the state checkout, verified before the source goes"
```

---

### Task 5: `sdd-dir` prints the checkout workspace

**Risk tier:** high — every other script and the skill text trust the path this script prints, it runs the import, and it writes the plain workspace under the lock.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-dir` (full rewrite below)
- Modify: `tests/claude-code/test-sdd-dir-path.sh` (the blocks named in Step 1)
- Test: `tests/sdd/test-sdd-state.sh` (append the `sdd-dir` section)

**Interfaces:**
- Consumes: `hp_key`, `hp_plan_ws_name`, `hp_ensure_checkout`, `hp_materialize_plain`, `hp_cache_root`, `sdd-state import`.
- Produces: `sdd-dir PLAN_FILE` prints `<checkout>/plans/<ws>` (branch backend) or `<plain-root>/plans/<ws>` (plain backend); exit 2 for the existing errors, for a plan file that does not exist, for `needs-sync`, for a foreign branch, and when materialization or the legacy import fails (nothing is printed then, so no caller works in a half-built workspace); `sdd-dir` with no argument prints `<cache>/sdd/<common-dir key>`. `task-brief` and `review-package` are untouched.

**Mirror:** the current `skills/subagent-driven-development/scripts/sdd-dir:26-48` (argument handling, kept verbatim) and `:81-103` (pointer, kept in the plain cache).

- [ ] **Step 1: Update the path test**

In `tests/claude-code/test-sdd-dir-path.sh`:

1. After the `cleanup()`/`trap` lines (`:26-27`), add:

```bash
STATE_ROOT="$XDG_CACHE_HOME/hyperpowers/state"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
state_key() { ( . "$LIB"; hp_key "$1" ); }
```

2. Rewrite test 10g (`:218-233`): keep the `pointer_b` assertion as it is, and replace the `own_a` check (the plan repository's own workspace was a real directory under its plain root) with:

```bash
if [ -d "$from_a" ] && [ ! -L "$from_a" ] && [ ! -e "$bare_a/plans/$(basename "$from_a")" ]; then
    pass "the plan repository's workspace is a real directory in its state checkout, with no copy under its plain root"
else
    fail "the plan repository's workspace is a real directory in its state checkout, with no copy under its plain root ($from_a)"
fi
```

3. Replace the block headed `echo "Test: plan-scoped workspaces are distinct for same-basename plans"` (`:293-305`) with:

```bash
echo "Test: plan-scoped workspaces are distinct for same-basename plans"
make_repo "$TEST_ROOT/repo-plan"
git -C "$TEST_ROOT/repo-plan" commit -q --allow-empty -m "initial"
mkdir -p "$TEST_ROOT/repo-plan/docs/a" "$TEST_ROOT/repo-plan/docs/b"
echo plan > "$TEST_ROOT/repo-plan/docs/a/plan.md"
echo plan > "$TEST_ROOT/repo-plan/docs/b/plan.md"
noarg=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT")
da=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
db=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/b/plan.md)
plan_key=$(state_key "$TEST_ROOT/repo-plan")
if [ "$da" != "$db" ]; then pass "same basename, different dirs -> distinct workspaces"; else fail "collision: $da == $db"; fi
case "$da" in "$STATE_ROOT/$plan_key"/plans/plan-*) pass "plan dir nests under the state checkout's plans/ with the slug prefix";; *) fail "unexpected plan dir shape: $da";; esac
case "$noarg" in "$XDG_CACHE_HOME/hyperpowers/sdd/$plan_key") pass "the no-argument root stays in the plain cache under the common-directory key";; *) fail "no-argument root shape: $noarg";; esac
if [ -f "$STATE_ROOT/$plan_key/.git" ] && [ "$(git -C "$STATE_ROOT/$plan_key" branch --show-current)" = "hyperpowers/state" ]; then pass "the checkout is a worktree on hyperpowers/state"; else fail "the checkout is a worktree on hyperpowers/state"; fi
dabs=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" "$TEST_ROOT/repo-plan/docs/a/plan.md")
if [ "$da" = "$dabs" ]; then pass "relative and absolute plan paths agree"; else fail "path-form sensitivity: $da vs $dabs"; fi
git -C "$TEST_ROOT/repo-plan" worktree add -q "$TEST_ROOT/repo-plan-wt" -b wt >/dev/null 2>&1
dwt=$(cd "$TEST_ROOT/repo-plan-wt" && "$SDD_DIR_SCRIPT" "$TEST_ROOT/repo-plan/docs/a/plan.md")
if [ "$dwt" = "$da" ]; then pass "a linked worktree of the clone resolves to the same workspace"; else fail "a linked worktree of the clone resolves to the same workspace ($dwt vs $da)"; fi
: > "$da/task-1-brief.md"; : > "$da/review-1111111..2222222.diff"; : > "$da/progress.md"
if git -C "$STATE_ROOT/$plan_key" check-ignore -q "$da/task-1-brief.md" && git -C "$STATE_ROOT/$plan_key" check-ignore -q "$da/review-1111111..2222222.diff" && ! git -C "$STATE_ROOT/$plan_key" check-ignore -q "$da/progress.md"; then pass "briefs and packages are ignored in the checkout, the ledger is not"; else fail "briefs and packages are ignored in the checkout, the ledger is not"; fi
```

4. Replace the block headed `echo "Test: stale sibling plan workspaces pruned; fresh and non-plan content kept"` (`:307-318`) with:

```bash
echo "Test: nothing inside plans/ is reclaimed automatically"
stale="$STATE_ROOT/$plan_key/plans/old-plan-deadbeef"
nonplan="$noarg/perf-cache-notaplan"
mkdir -p "$stale" "$nonplan"
OLDSTAMP="$(date -v-20d +%Y%m%d%H%M 2>/dev/null || date -d '20 days ago' +%Y%m%d%H%M)"
touch -mt "$OLDSTAMP" "$stale" "$nonplan"
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -d "$stale" ]; then pass "an idle sibling plan dir in the checkout is kept (prune is explicit)"; else fail "an idle sibling plan dir in the checkout was removed"; fi
if [ -d "$nonplan" ]; then pass "stale NON-plan content under the plain root preserved"; else fail "reclaim deleted non-plan cache content"; fi
```

5. Replace the block headed `echo "Test: resumed plan workspace survives sibling GC"` (`:320-327`) with:

```bash
echo "Test: a plan's workspace survives another plan's invocation"
planA_dir=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
touch -mt "$OLDSTAMP" "$planA_dir"
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/b/plan.md)
if [ -d "$planA_dir" ]; then pass "plan A survives plan B's invocation"; else fail "plan A wrongly removed by plan B"; fi
```

6. In the block headed `echo "Test: plan mode refreshes parent repo cache dir to survive cross-repo GC"` (`:329-339`) keep every line; it still holds because plan mode touches the plain root.

7. In test 10b (`:151-168`), after the line `expected_nonexistent_dir=...` (`:162`), add a second path and extend the check:

```bash
    expected_nonexistent_state="$XDG_CACHE_HOME/hyperpowers/state/$repo_key/plans/$slug-$hash8"
    if [ -d "$expected_nonexistent_dir" ] || [ -d "$expected_nonexistent_state" ]; then
```

replacing the existing `if [ -d "$expected_nonexistent_dir" ]; then`.

8. Append before the closing STATUS lines (this suite sets `pipefail`, so every `grep -q` reads through process substitution):

```bash
echo ""
echo "Test: branch availability decides the backend"
make_repo "$TEST_ROOT/repo-remote"
git -C "$TEST_ROOT/repo-remote" commit -q --allow-empty -m "initial"
git -C "$TEST_ROOT/repo-remote" remote add origin "$TEST_ROOT/nowhere.git"
: > "$TEST_ROOT/repo-remote/plan.md"
err=$(cd "$TEST_ROOT/repo-remote" && bash "$SDD_DIR_SCRIPT" plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && grep -q 'needs-sync' < <(printf '%s\n' "$err"); then pass "a clone with a remote and no fetch stamp gets needs-sync"; else fail "a clone with a remote and no fetch stamp gets needs-sync (rc=$rc: $err)"; fi
if ( cd "$TEST_ROOT/repo-remote" && bash "$SDD_DIR_SCRIPT" missing.md ) >/dev/null 2>&1; then fail "a plan file that does not exist is refused"; else pass "a plan file that does not exist is refused"; fi
make_repo "$TEST_ROOT/repo-plain"
git -C "$TEST_ROOT/repo-plain" commit -q --allow-empty -m "initial"
: > "$TEST_ROOT/repo-plain/plan.md"
plain_key=$(state_key "$TEST_ROOT/repo-plain")
out=$(cd "$TEST_ROOT/repo-plain" && HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null); rc=$?
case "$out" in
    "$XDG_CACHE_HOME/hyperpowers/sdd/$plain_key/plans/plan-"*) pass "a failed worktree add prints the plain-cache workspace" ;;
    *) fail "a failed worktree add prints the plain-cache workspace (rc=$rc: $out)" ;;
esac
out2=$(cd "$TEST_ROOT/repo-plain" && bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null)
if [ "$out2" = "$out" ] && [ "$(head -n1 "$STATE_ROOT/$plain_key.backend")" = plain ]; then pass "the plain backend persists for later calls"; else fail "the plain backend persists for later calls"; fi

echo ""
echo "Test: a legacy workspace is imported on the first call"
make_repo "$TEST_ROOT/repo-legacy"
git -C "$TEST_ROOT/repo-legacy" commit -q --allow-empty -m "initial"
: > "$TEST_ROOT/repo-legacy/plan.md"
legacy_key=$(state_key "$TEST_ROOT/repo-legacy")
legacy_hash8=$(printf '%s' "plan.md" | git hash-object --stdin | cut -c1-8)
legacy_ws="$XDG_CACHE_HOME/hyperpowers/sdd/$legacy_key/plans/plan-$legacy_hash8"
mkdir -p "$legacy_ws"; printf '# SDD ledger — plan: plan.md\n' > "$legacy_ws/progress.md"
out=$(cd "$TEST_ROOT/repo-legacy" && bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null)
if [ "$out" = "$STATE_ROOT/$legacy_key/plans/plan-$legacy_hash8" ] && [ -f "$out/progress.md" ] && [ -L "$legacy_ws" ]; then pass "the legacy workspace moved into the checkout and left a symlink"; else fail "the legacy workspace moved into the checkout and left a symlink ($out)"; fi
```

Then insert above the closing STATUS lines of `tests/sdd/test-sdd-state.sh`:

```bash
echo ""
echo "=== sdd-dir and the plain fallback over branch state ==="
make_pair p2
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
: > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 bash "$SDD_DIR" docs/plan.md 2>/dev/null)
keyb=$(state_key "$PAIR_B")
if [ "$out" = "$XDG_CACHE_HOME/hyperpowers/sdd/$keyb/plans/$(basename "$wsa")" ] && [ "$(sed -n 2p "$out/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && grep -q "^plain source=$(git -C "$PAIR_B" rev-parse refs/remotes/origin/hyperpowers/state)$" "$STATE_ROOT/$keyb.backend"; then pass "the plain fallback materializes the branch workspace and records its source"; else fail "the plain fallback materializes the branch workspace and records its source ($out)"; fi
if [ ! -d "$STATE_ROOT/$keyb.lock" ]; then pass "the plain materialization released the lock"; else fail "the plain materialization released the lock"; fi
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/claude-code/test-sdd-dir-path.sh`
Expected: the plan-scoped shape, worktree, ignore, backend, and import tests fail; the legacy assertions still pass.

- [ ] **Step 3: Rewrite `sdd-dir`**

Replace the whole file with:

```bash
#!/usr/bin/env bash
# Emit the SDD workspace for a plan: the directory holding its ledger, briefs,
# reports, review packages and claims. Single source of truth for task-brief,
# review-package, sdd-state and the SKILL.md ledger guidance.
#
# With a plan argument the workspace lives inside the repository's state
# checkout, a linked worktree of the orphan branch hyperpowers/state kept
# once per clone under the user cache (sdd-common.sh, hp_ensure_checkout):
#   ${XDG_CACHE_HOME:-~/.cache}/hyperpowers/state/<key>/plans/<slug>-<hash8>/
# <key> hashes the clone's physical common git directory, so every worktree
# of the clone shares the checkout, and the workspace name derives from the
# plan's repo-relative path, so it is the same on every host. When the
# branch backend is unavailable (git worktree add failed, for example under
# a sandbox) the workspace falls back to the plain cache at
#   ${XDG_CACHE_HOME:-~/.cache}/hyperpowers/sdd/<key>/plans/<slug>-<hash8>/
# and does not travel. Without a plan argument the plain-cache root
# sdd/<key> is printed: the repository-level scratch other skills use.
#
# Why not <git-dir>/sdd: .git/ is a hardcoded protected path in Claude Code;
# writes under it prompt in every permission mode. Why not the working tree:
# the dossier must survive git clean, stash and checkout, and never be
# committed by accident. Design:
# docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sdd-common.sh
. "$SCRIPT_DIR/sdd-common.sh"

plan_dir=""
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
  plan=$1
  [ -f "$plan" ] || {
    echo "sdd-dir: plan file does not exist: $plan" >&2
    exit 2
  }
  plan_dir=$(cd "$(dirname "$plan")" 2>/dev/null && pwd -P) || {
    echo "sdd-dir: plan file directory does not exist: $plan" >&2
    exit 2
  }
  git -C "$plan_dir" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "sdd-dir: plan file directory is not inside a git repository: $plan" >&2
    exit 2
  }
else
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "sdd-dir: not inside a git repository" >&2
    exit 2
  }
fi

base="$(hp_cache_root)/sdd"

# Reclaim plain-cache roots idle for 14+ days, never the given key's. Left
# alone the cache grows one root per repository instance forever, and editors
# that follow agent-touched files hold a watcher per scratch file. Best
# effort: pruning must never break the contract that stdout is the path.
reclaim_plain() {
  find "$base" -mindepth 1 -maxdepth 1 -type d ! -name "$1" -mtime +14 \
    -exec rm -rf {} + 2>/dev/null || true
}

if [ -z "$plan_dir" ]; then
  key=$(hp_key .)
  dir="$base/$key"
  mkdir -p "$dir"
  touch "$dir"
  reclaim_plain "$key"
  printf '%s\n' "$dir"
  exit 0
fi

key=$(hp_key "$plan_dir")
ws=$(hp_plan_ws_name "$plan")
ensure=$(hp_ensure_checkout "$plan_dir") || exit 2
backend=${ensure%% *}
root=${ensure#* }
dir="$root/plans/$ws"
mkdir -p "$dir"
if [ "$backend" = plain ]; then
  touch "$root"
  # Writes under the plain backend take the repository lock like every other
  # mutation; a failed materialization leaves no half-built workspace.
  hp_lock "$plan_dir" || exit 2
  if ! hp_materialize_plain "$plan_dir" "$ws" "$dir"; then
    rm -rf "$dir"; hp_unlock
    echo "sdd-dir: could not materialize the branch workspace into the plain cache" >&2
    exit 2
  fi
  hp_unlock
  echo "sdd-dir: backend=plain for this repository; the dossier will not travel from this host" >&2
fi

# Pull a workspace an older plugin left in the plain cache into place. A
# failed import stops here: no caller may work in a workspace whose legacy
# ledger is still elsewhere.
bash "$SCRIPT_DIR/sdd-state" import "$plan" >/dev/null 2>&1 || {
  echo "sdd-dir: importing a legacy workspace failed; run: sdd-state import $plan" >&2
  exit 2
}

# Keep the plan repository's plain root fresh: it holds pointers for other
# repositories and the no-argument scratch, and another repository's reclaim
# would otherwise take it after 14 idle days.
mkdir -p "$base/$key" 2>/dev/null || true
touch "$base/$key" 2>/dev/null || true
reclaim_plain "$key"

# A plan run from another repository's checkout: leave a pointer under the
# cwd's key in the plain cache, so the compaction notice finds the ledger
# without a state branch being created in the hosting repository. Dangling
# pointers left by finished workspaces are pruned alongside.
if git rev-parse --git-dir >/dev/null 2>&1; then
  cwd_key=$(hp_key .)
  if [ "$cwd_key" != "$key" ]; then
    cwd_plans="$base/$cwd_key/plans"
    mkdir -p "$cwd_plans" 2>/dev/null || true
    touch "$base/$cwd_key" 2>/dev/null || true
    pointer="${cwd_plans}/${ws}+${key:0:8}"
    if [ ! -e "$pointer" ] || [ -L "$pointer" ]; then
      ln -sfn "$dir" "$pointer" 2>/dev/null || true
    fi
    find "$cwd_plans" -mindepth 1 -maxdepth 1 -type l ! -exec test -e {} \; -delete 2>/dev/null || true
  fi
fi

printf '%s\n' "$dir"
```

- [ ] **Step 4: Run the tests**

Run, one per `bash` call: `bash tests/claude-code/test-sdd-dir-path.sh`, `bash tests/sdd/test-sdd-state.sh`, `bash tests/sdd/test-sdd-common.sh`
Expected: `STATUS: PASSED` from each. The `make_repo` of the path test creates empty repositories (no commit); the orphan creation works on them, which is why tests 1-9 keep passing without a commit. Test 9 creates `plan.md` before the first plan-mode call and the `nowhere/plan.md` case creates its file, so the existing-file requirement changes none of the older assertions.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-dir tests/claude-code/test-sdd-dir-path.sh tests/sdd/test-sdd-state.sh`

```bash
git add skills/subagent-driven-development/scripts/sdd-dir tests/claude-code/test-sdd-dir-path.sh tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): sdd-dir resolves a plan's workspace inside the state checkout"
```

---

### Task 6: `sdd-state finish` and `sdd-state prune`

**Risk tier:** high — both remove dossier directories; `finish` is the step that ends every SDD run, and both run under the repository lock.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (add `open_claims`, `cmd_finish`, `cmd_prune`, dispatch arms)
- Test: `tests/sdd/test-sdd-state.sh` (append the `finish` and `prune` sections)

**Interfaces:**
- Consumes: `resolve_plan`, `hp_lock`, `hp_commit_paths`, `hp_backend`, `hp_checkout_path`, `hp_state_branch`, `hp_cache_root`, `hp_physical_dir`.
- Produces: `sdd-state finish PLAN_FILE [--force]` printing `status=finished sha=<sha7> last=<full sha> push=<remote>/<branch>` (branch), `status=finished backend=plain`, `status=none`, `status=open-claims tasks=<n,...>` (exit 6), or `status=busy` (exit 3) when the workspace changed between the final snapshot and its removal. Removal is rename, verify, delete (Deviation 6): the directory is renamed aside atomically, every file the tip tracks is compared by object id with the renamed copy and any extra non-ignored file counts as a change; an unchanged copy is deleted, a changed one renamed back. The plain backend compares the ledger's size before and after the rename. The helper `remove_verified DIR TIP_TREE_PREFIX` is shared with `prune` and with `sync`'s remote-finish path. `sdd-state prune [--days N] [--apply] --repo DIR` printing `status=listed plans=<ws,...> checkouts=<key,...>`, `status=pruned plans=<ws,...> kept=<ws,...> checkouts=<key,...>`, or `status=plain`; with `--apply` the selection runs under the lock and every candidate goes through `remove_verified`, an active or changed one being kept; workspace names percent-encoded (`%20` for a space) and handled in arrays. The test seam `HYPERPOWERS_TEST_WRITER_AT=finish-before-remove:<path>` and `prune-before-remove:<path>` appends one line to that file at those points.

- [ ] **Step 1: Write the failing tests**

Insert above the closing STATUS lines of `tests/sdd/test-sdd-state.sh`:

```bash
echo ""
echo "=== finish ==="
f1="$TEST_ROOT/f1"; make_repo "$f1"
mkdir -p "$f1/docs"; : > "$f1/docs/plan.md"; git -C "$f1" add docs; git -C "$f1" commit -qm plan
wsf=$(run_sdd_dir "$f1" docs/plan.md); co_f1="$STATE_ROOT/$(state_key "$f1")"
printf '# SDD ledger — plan: docs/plan.md\n' > "$wsf/progress.md"
run_state "$f1" claim docs/plan.md 1 --session s-f >/dev/null
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 6 ] && [ "$out" = "status=open-claims tasks=1" ] && [ -d "$wsf" ]; then pass "finish refuses while a claim has no completion line"; else fail "finish refuses while a claim has no completion line (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsf/progress.md"
out=$(run_state "$f1" finish docs/plan.md); rc=$?
last=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
case "$out" in
    "status=finished sha="???????" last="????????????????????????????????????????" push=origin/hyperpowers/state") pass "finish prints the finish sha, the full last sha and the push target" ;;
    *) fail "finish prints the finish sha, the full last sha and the push target (rc=$rc: $out)" ;;
esac
if [ ! -d "$wsf" ] && ! git -C "$co_f1" ls-tree -r --name-only hyperpowers/state | grep -q "plans/$(basename "$wsf")/"; then pass "finish removes the workspace from the tree and the disk"; else fail "finish removes the workspace from the tree and the disk"; fi
if [ "$(git -C "$co_f1" show "$last:plans/$(basename "$wsf")/progress.md" 2>/dev/null | sed -n 2p)" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "the last sha still shows the ledger"; else fail "the last sha still shows the ledger"; fi
if [ "$(run_state "$f1" finish docs/plan.md)" = "status=none" ]; then pass "finishing twice reports none"; else fail "finishing twice reports none"; fi
wsf3=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf3/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove:plans/$(basename "$wsf3")/progress.md" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ -d "$wsf3" ] && grep -q '^concurrent write$' "$wsf3/progress.md"; then pass "a line appended between the final snapshot and the removal makes finish busy and keeps the workspace"; else fail "a line appended between the final snapshot and the removal makes finish busy (rc=$rc: $out)"; fi
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ]; then pass "finish succeeds on the retry"; else fail "finish succeeds on the retry (rc=$rc: $out)"; fi
wsf2=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsf2/progress.md"
run_state "$f1" claim docs/plan.md 2 --session s-g >/dev/null
out=$(run_state "$f1" finish docs/plan.md --force); rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$wsf2" ]; then pass "--force finishes over an open claim"; else fail "--force finishes over an open claim (rc=$rc: $out)"; fi
wsp=$(run_sdd_dir "$rp" docs/plan.md 2>/dev/null); printf 'x\n' > "$wsp/progress.md"
out=$(run_state "$rp" finish docs/plan.md 2>/dev/null)
if [ "$out" = "status=finished backend=plain" ] && [ ! -d "$wsp" ]; then pass "finish under the plain backend removes the plain workspace"; else fail "finish under the plain backend removes the plain workspace ($out)"; fi

echo ""
echo "=== prune ==="
pr="$TEST_ROOT/pr"; make_repo "$pr"
mkdir -p "$pr/docs"; : > "$pr/docs/old plan.md"; : > "$pr/docs/new.md"; git -C "$pr" add docs; git -C "$pr" commit -qm plans
wso=$(run_sdd_dir "$pr" "docs/old plan.md"); wsn=$(run_sdd_dir "$pr" docs/new.md); co_pr="$STATE_ROOT/$(state_key "$pr")"
printf 'old\n' > "$wso/progress.md"; printf 'new\n' > "$wsn/progress.md"
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$pr" snapshot "docs/old plan.md" >/dev/null
run_state "$pr" snapshot docs/new.md >/dev/null
touch -t 202601010000 "$wso/progress.md" "$wso"
wso_enc=$(basename "$wso" | sed 's/ /%20/g')
mkdir -p "$STATE_ROOT/deadkey0000000000000000000000000000000000"; printf 'gitdir: %s/gone/.git/worktrees/x\n' "$TEST_ROOT" > "$STATE_ROOT/deadkey0000000000000000000000000000000000/.git"
: > "$STATE_ROOT/deadkey0000000000000000000000000000000000.backend"
out=$(run_state "$pr" prune --repo "$pr"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=listed plans=$wso_enc checkouts=deadkey0000000000000000000000000000000000" ] && [ -d "$wso" ]; then pass "prune lists the idle plan (space percent-encoded) and the dead checkout without removing them"; else fail "prune lists the idle plan and the dead checkout without removing them (rc=$rc: $out)"; fi
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-before-remove:plans/$(basename "$wso")/progress.md" bash "$SDD_STATE" prune --repo "$pr" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=pruned plans= kept=$wso_enc checkouts=deadkey0000000000000000000000000000000000" ] && [ -d "$wso" ] && grep -q '^concurrent write$' "$wso/progress.md"; then pass "a workspace written to after selection is kept, line intact"; else fail "a workspace written to after selection is kept (rc=$rc: $out)"; fi
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$pr" snapshot "docs/old plan.md" >/dev/null
touch -t 202601010000 "$wso/progress.md" "$wso"
mkdir -p "$STATE_ROOT/deadkey0000000000000000000000000000000000"; printf 'gitdir: %s/gone/.git/worktrees/x\n' "$TEST_ROOT" > "$STATE_ROOT/deadkey0000000000000000000000000000000000/.git"
out=$(run_state "$pr" prune --repo "$pr" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=pruned plans=$wso_enc kept= checkouts=deadkey0000000000000000000000000000000000" ] && [ ! -d "$wso" ] && [ -d "$wsn" ] && [ ! -d "$STATE_ROOT/deadkey0000000000000000000000000000000000" ] && [ ! -e "$STATE_ROOT/deadkey0000000000000000000000000000000000.backend" ] && [ "$(git -C "$co_pr" log -1 --format=%s hyperpowers/state)" = "sdd: prune $(basename "$wso")" ] && ! git -C "$co_pr" ls-tree -r --name-only hyperpowers/state | grep -q "^plans/$(basename "$wso")/"; then pass "prune --apply removes the whole idle plan, space and all, in one commit and the dead checkout"; else fail "prune --apply removes the idle plan in one commit and the dead checkout (rc=$rc: $out)"; fi
if [ "$(run_state "$rp" prune --repo "$rp" 2>/dev/null)" = "status=plain" ]; then pass "prune under the plain backend reports plain"; else fail "prune under the plain backend reports plain"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: the two new sections fail on the usage message.

- [ ] **Step 3: Add `finish` and `prune`**

Insert before the `# --- dispatch` block of `sdd-state`:

```bash
# --- finish ------------------------------------------------------------------
# Task numbers that hold a claim but have no completion line in the ledger.
open_claims() {
  local d n open=""
  for d in "$WSDIR"/claims/task-*/; do
    [ -d "$d" ] || continue
    n=${d%/}; n=${n##*/task-}
    if ! grep -Eq "(^|[^A-Za-z0-9])Task $n: complete" "$WSDIR/progress.md" 2>/dev/null; then open="$open,$n"; fi
  done
  printf '%s' "${open#,}"
}
# <dir> <tree-prefix>: remove a workspace directory only if it still equals
# the committed tip. The directory is renamed aside first (atomic), so a
# writer that opens the old path afterwards fails with ENOENT instead of
# writing into a directory about to vanish; then every tracked file is
# compared by object id with the renamed copy, and any extra file that is
# not ignored counts as a change. Unchanged: deleted, returns 0. Changed:
# renamed back, returns 1. <tree-prefix> is "<tip>:plans/<ws>"; an empty
# prefix (plain backend) compares the ledger's size with SIZE_BEFORE.
remove_verified() {
  local dir=$1 prefix=$2 tomb f committed live
  tomb="$(dirname "$dir")/.removing-$(basename "$dir")-$$"
  mv "$dir" "$tomb" 2>/dev/null || return 1
  if [ -z "$prefix" ]; then
    if [ "$(wc -c < "$tomb/progress.md" 2>/dev/null | tr -d ' ')" != "${SIZE_BEFORE:-}" ]; then mv "$tomb" "$dir"; return 1; fi
    rm -rf "$tomb"; return 0
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    committed=$(git -C "$CO" rev-parse "$prefix/$f" 2>/dev/null)
    live=$(git -C "$CO" hash-object "$tomb/$f" 2>/dev/null)
    if [ "$committed" != "$live" ]; then mv "$tomb" "$dir"; return 1; fi
  done < <(git -C "$CO" ls-tree -r --name-only "$prefix" 2>/dev/null)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    git -C "$CO" cat-file -e "$prefix/$f" 2>/dev/null && continue
    if ! git -C "$CO" check-ignore -q "plans/x/$f" 2>/dev/null; then mv "$tomb" "$dir"; return 1; fi
  done < <(cd "$tomb" && find . -type f | sed 's|^\./||')
  rm -rf "$tomb"
  return 0
}
cmd_finish() {
  local plan="" force=0 open last commit rc
  while [ $# -gt 0 ]; do
    case "$1" in --force) force=1; shift ;; -*) usage ;; *) plan=$1; shift ;; esac
  done
  [ -n "$plan" ] || usage
  resolve_plan "$plan"
  [ -d "$WSDIR" ] || { echo "status=none"; return 0; }
  # The claims are read under the lock, so a claim published after a first
  # look, or a takeover in flight, is seen before anything is removed.
  hp_lock "$PLAN_DIR" || return 2
  open=$(open_claims)
  if [ -n "$open" ] && [ "$force" -eq 0 ]; then hp_unlock; echo "status=open-claims tasks=$open"; return 6; fi
  if [ "$BACKEND" != branch ]; then
    SIZE_BEFORE=$(wc -c < "$WSDIR/progress.md" 2>/dev/null | tr -d ' ')
    if ! remove_verified "$WSDIR" ""; then hp_unlock; echo "status=busy"; return 3; fi
    hp_unlock
    echo "status=finished backend=plain"; return 0
  fi
  if type recover_apply >/dev/null 2>&1; then recover_apply || { hp_unlock; echo "status=error"; return 2; }; fi
  hp_commit_paths "$CO" "$BRANCH" "sdd $SLUG: snapshot before finish" "plans/$WS" >/dev/null || { hp_unlock; echo "status=error"; return 2; }
  last=$(git -C "$CO" rev-parse "refs/heads/$BRANCH")
  # Controllers append without the lock: the removal renames the directory
  # aside and verifies it against the snapshot before deleting it.
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in finish-before-remove:*) printf 'concurrent write\n' >> "$CO/${HYPERPOWERS_TEST_WRITER_AT#finish-before-remove:}" ;; esac
  if ! remove_verified "$WSDIR" "$last:plans/$WS"; then hp_unlock; echo "status=busy"; return 3; fi
  commit=$(hp_commit_paths "$CO" "$BRANCH" "sdd $SLUG: finish" "plans/$WS"); rc=$?
  hp_unlock
  [ "$rc" -eq 0 ] || { echo "status=error"; return 2; }
  [ ! -d "$WSDIR" ] || { echo "status=error"; return 2; }
  echo "status=finished sha=${commit:0:7} last=$last push=$REMOTE/$BRANCH"
}

# --- prune -------------------------------------------------------------------
# Lists, and with --apply removes, plan directories idle for N days (last
# commit and newest file both older) and checkouts whose clone is gone. Never
# runs implicitly.
cmd_prune() {
  local repo="" days=30 apply=0 repo_dir co br d name now cutoff c key list="" dead_list="" i tip
  local plans=() paths=() dead=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --days) [ $# -ge 2 ] || usage; days=$2; shift 2 ;;
      --apply) apply=1; shift ;;
      --repo) [ $# -ge 2 ] || usage; repo=$2; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$repo" ] || usage
  repo_dir=$(hp_physical_dir "$repo") || usage
  git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1 || { echo "sdd-state: not a git repository: $repo" >&2; exit 2; }
  if [ "$(hp_backend "$repo_dir")" = plain ]; then echo "status=plain"; return 0; fi
  co=$(hp_checkout_path "$repo_dir"); br=$(hp_state_branch "$repo_dir")
  now=$(date +%s); cutoff=$((now - days * 86400))
  # <name> -> 0 when the plan directory is idle: last commit and newest file both older than N days.
  idle() {
    local lc
    lc=$(git -C "$co" log -1 --format=%ct -- "plans/$1" 2>/dev/null)
    [ -n "$lc" ] && [ "$lc" -lt "$cutoff" ] && [ -z "$(find "$co/plans/$1" -type f -mtime -"$days" 2>/dev/null | head -n 1)" ]
  }
  # With --apply the selection itself runs under the lock, and each candidate
  # is revalidated right before its removal; a workspace that became active
  # in between is kept and reported.
  if [ "$apply" -eq 1 ]; then hp_lock "$repo_dir" || return 2; fi
  if [ -e "$co/.git" ]; then
    for d in "$co"/plans/*/; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      idle "$name" || continue
      plans[${#plans[@]}]=$name
      paths[${#paths[@]}]="plans/$name"
      list="$list,$(enc "$name")"
    done
  fi
  for c in "$(hp_cache_root)"/state/*/; do
    [ -f "$c.git" ] || continue
    if [ ! -d "$(sed -n 's/^gitdir: //p' "$c.git")" ]; then dead[${#dead[@]}]=$(basename "$c"); dead_list="$dead_list,$(basename "$c")"; fi
  done
  list=${list#,}; dead_list=${dead_list#,}
  if [ "$apply" -eq 0 ]; then echo "status=listed plans=$list checkouts=$dead_list"; return 0; fi
  local removed=() removed_paths=() kept_list="" removed_list=""
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in prune-before-remove:*) printf 'concurrent write\n' >> "$co/${HYPERPOWERS_TEST_WRITER_AT#prune-before-remove:}" ;; esac
  CO=$co
  tip=$(git -C "$co" rev-parse "refs/heads/$br")
  i=0
  while [ "$i" -lt "${#plans[@]}" ]; do
    name=${plans[$i]}
    if idle "$name" && remove_verified "$co/plans/$name" "$tip:plans/$name"; then
      removed[${#removed[@]}]=$name; removed_paths[${#removed_paths[@]}]="plans/$name"; removed_list="$removed_list,$(enc "$name")"
    else
      kept_list="$kept_list,$(enc "$name")"
    fi
    i=$((i + 1))
  done
  if [ "${#removed[@]}" -gt 0 ]; then
    hp_commit_paths "$co" "$br" "sdd: prune ${removed[*]}" "${removed_paths[@]}" >/dev/null || { hp_unlock; echo "status=error"; return 2; }
  fi
  hp_unlock
  list=${removed_list#,}; kept_list=${kept_list#,}
  i=0
  while [ "$i" -lt "${#dead[@]}" ]; do
    key=${dead[$i]}
    rm -rf "$(hp_cache_root)/state/$key" "$(hp_cache_root)/state/$key.backend" "$(hp_cache_root)/state/$key.lock" "$(hp_cache_root)/state/$key.lock-history" "$(hp_cache_root)/state/$key.fetched"
    i=$((i + 1))
  done
  echo "status=pruned plans=$list kept=$kept_list checkouts=$dead_list"
}
```

Add the dispatch arms `finish) cmd_finish "$@" ;;` and `prune) cmd_prune "$@" ;;`.

- [ ] **Step 4: Run the tests**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: `STATUS: PASSED`.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh`

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): finish keeps the dossier in history and refuses open claims; prune is explicit"
```

---

### Task 7: `sdd-state sync`

**Risk tier:** high — the only network step, and the reconciliation that moves the shared checkout under live writers.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (add `tip_of`, `short`, `age_of`, `snapshot_pending`, `apply_files`, `recover_apply`, `apply_target`, `cmd_sync`, dispatch arm; `snapshot`, `finish` and `handoff` call `recover_apply` before committing)

**Deviation from the spec (for the human partner's approval at hand-off):** spec section 2 applies a fast-forward or merge by checking out the changed paths and re-appending ledger lines gained since the snapshot. That leaves a window between the status re-read and the checkout in which a ledger line could be lost. This task never checks out a ledger: it appends the target's new lines to the live file, so no window exists for ledgers; the residual window applies to report files only, as the spec's known limits already say for files outside the lock.
- Test: `tests/sdd/test-sdd-state.sh` (append the `sync` section)

**Interfaces:**
- Consumes: `resolve_plan_basic`, `hp_ensure_checkout`, `hp_stamp_path`, `hp_has_remote`, `hp_lock`, `hp_commit_paths`, `hp_git_id`, `hp_git_version_at_least`, `hp_backend`.
- Produces: `sdd-state sync PLAN_FILE [--assume-absent]` and `sync --repo DIR [--assume-absent]` with the outcomes of the spec's table: `up-to-date`, `fast-forwarded`, `ahead`, `merged`, `created`, `no-remote`, `absent`, `assumed-absent` (exit 0, each with `local=<sha7|none> remote=<sha7|none> age=<seconds>`); `plain` (exit 0, the bare `status=plain` line); `offline`, `offline-no-state` (exit 1); `busy`, `diverged` (exit 3, `diverged` adds the `merge=` line); `remote-finished plans=<ws,...>` (exit 3, nothing changed) when the target deletes a ledger this host has modified since the snapshot, which is a remote `finish` racing a local writer and the human partner's call (Deviation 6). Ledgers are never overwritten: the apply step appends to the live `progress.md` the lines the target adds over S, so a line another session appends at any moment survives; only non-ledger files are checked out, and a pending change to one of them makes the attempt retry. A ledger the target deletes (a remote finish) goes through `remove_verified` (Task 6's rename, verify, delete), so a line written up to the rename is caught and the outcome is `remote-finished`; a parent directory an added file needs is created, and any failure while applying is `status=error`. While files are being applied a marker `<checkout>/.sync-applying` holds `S target`; `recover_apply` (run by `sync`, `snapshot`, `finish` and `handoff` under the lock) finishes an interrupted apply from that marker before anything is committed, so a crash after the ref moved never becomes a revert snapshot. The test seam `HYPERPOWERS_TEST_PAUSE_AT=sync-before-apply` holds `apply_target` while `<checkout>/.sync-pause` exists, and `HYPERPOWERS_TEST_WRITER_AT=sync-before-apply:<relative path>` appends one line to that file inside the checkout before every pending re-check, standing in for a concurrent writer.

- [ ] **Step 1: Write the failing tests**

Insert above the closing STATUS lines of `tests/sdd/test-sdd-state.sh`:

```bash
echo ""
echo "=== sync ==="
make_pair p3
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_a="$STATE_ROOT/$(state_key "$PAIR_A")"; co_b="$STATE_ROOT/$(state_key "$PAIR_B")"
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
case "$out" in "status=absent local="???????" remote=none age="*) pass "a remote without the branch is absent and the orphan is created" ;; *) fail "a remote without the branch is absent and the orphan is created (rc=$rc: $out)" ;; esac
if [ -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ]; then pass "a successful fetch writes the stamp"; else fail "a successful fetch writes the stamp"; fi
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa/progress.md"
printf 'report A\n' > "$wsa/task-1-report.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
case "$out" in "status=created local="???????" remote="???????" age="*) pass "the second host creates its checkout from the remote" ;; *) fail "the second host creates its checkout from the remote (rc=$rc: $out)" ;; esac
wsb="$co_b/plans/$(basename "$wsa")"
if [ "$(sed -n 2p "$wsb/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "the ledger arrived on the second host"; else fail "the ledger arrived on the second host"; fi
if [ "$(run_state "$PAIR_B" sync docs/plan.md | cut -d' ' -f1)" = "status=up-to-date" ]; then pass "a second sync is up-to-date"; else fail "a second sync is up-to-date"; fi
printf 'Task 2: complete (commits 3333333..4444444, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(sed -n 3p "$wsb/progress.md")" = "Task 2: complete (commits 3333333..4444444, review clean)" ]; then pass "a behind checkout fast-forwards, after private-index commits left its index stale"; else fail "a behind checkout fast-forwards ($out)"; fi
printf 'Task 3: complete (commits 5555555..6666666, review clean)\n' >> "$wsb/progress.md"
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=ahead" ]; then pass "an unpushed snapshot reports ahead"; else fail "an unpushed snapshot reports ahead ($out)"; fi
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
printf 'note from A while behind\n' >> "$wsa/progress.md"
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=merged" ] && grep -q '^Task 3: complete' "$wsa/progress.md" && grep -q '^note from A while behind$' "$wsa/progress.md" && ! grep -q '^<<<<<<<' "$wsa/progress.md" && [ "$(git -C "$co_a" log -1 --format=%P hyperpowers/state | wc -w | tr -d ' ')" = 2 ]; then pass "behind with pending ledger edits ends merged with both sides' lines and two parents"; else fail "behind with pending ledger edits ends merged (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'report edited on A\n' > "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
printf 'report edited on B\n' > "$wsb/task-1-report.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1)" = "status=diverged" ] && [ "$(printf '%s\n' "$out" | sed -n 2p)" = "merge=git -C $co_b merge origin/hyperpowers/state" ] && [ "$(cat "$wsb/task-1-report.md")" = "report edited on B" ]; then pass "conflicting report edits end diverged with the merge command and nothing changed"; else fail "conflicting report edits end diverged (rc=$rc: $out)"; fi
git -C "$co_b" -c user.name=t -c user.email=t@example.com merge -q -m "resolve" -X ours origin/hyperpowers/state >/dev/null 2>&1
if [ -z "$(git -C "$co_b" status --porcelain)" ] && [ "$(git -C "$co_b" log -1 --format=%P hyperpowers/state | wc -w | tr -d ' ')" = 2 ]; then pass "the human-run merge resolves the conflict (ours) and the ledger needs no markers"; else fail "the human-run merge resolves the conflict"; fi
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null

# A live writer during reconciliation: a ledger line appended while apply is
# held survives; a report that keeps changing ends busy.
printf 'Task 4: complete (commits 7777777..8888888, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
: > "$co_b/.sync-pause"
( cd "$PAIR_B" && HYPERPOWERS_TEST_PAUSE_AT=sync-before-apply bash "$SDD_STATE" sync docs/plan.md > "$TEST_ROOT/p3.sync.out" 2>/dev/null ) &
sync_pid=$!
sleep 1
printf 'appended during sync\n' >> "$wsb/progress.md"
rm -f "$co_b/.sync-pause"
wait "$sync_pid"
if [ "$(cut -d' ' -f1 "$TEST_ROOT/p3.sync.out")" = "status=fast-forwarded" ] && grep -q '^Task 4: complete' "$wsb/progress.md" && grep -q '^appended during sync$' "$wsb/progress.md" && [ "$(grep -c '^Task 4: complete' "$wsb/progress.md")" -eq 1 ]; then pass "a ledger line appended while apply is held survives the fast-forward, and the remote line lands once"; else fail "a ledger line appended while apply is held survives the fast-forward ($(cat "$TEST_ROOT/p3.sync.out"))"; fi
# A write after the status check: the ledger is appended to, never replaced,
# so a line written at the last moment is kept too.
printf 'Task 4b: complete (commits bbbbbbb..ccccccc, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-apply:plans/$(basename "$wsa")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^concurrent write$' "$wsb/progress.md" && grep -q '^Task 4b: complete' "$wsb/progress.md"; then pass "a ledger line written during apply is kept beside the remote lines"; else fail "a ledger line written during apply is kept beside the remote lines (rc=$rc: $out)"; fi
printf 'Task 5: complete (commits 9999999..aaaaaaa, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-apply:plans/$(basename "$wsa")/task-1-report.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ]; then pass "a report that keeps changing across three attempts ends busy"; else fail "a report that keeps changing across three attempts ends busy (rc=$rc: $out)"; fi

# A second plan created on A appears on B, parent directory and all.
: > "$PAIR_A/docs/second.md"; git -C "$PAIR_A" add docs/second.md; git -C "$PAIR_A" commit -qm second; git -C "$PAIR_A" push -q origin main 2>/dev/null
ws2a=$(run_sdd_dir "$PAIR_A" docs/second.md); printf '# SDD ledger — plan: docs/second.md\n' > "$ws2a/progress.md"
run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=fast-forwarded" ] && [ -f "$co_b/plans/$(basename "$ws2a")/progress.md" ]; then pass "a plan added on the other host is materialized, parent directory included"; else fail "a plan added on the other host is materialized ($out)"; fi

# A crash after the ref moved: the next sync finishes the apply instead of
# snapshotting stale files as a revert.
printf 'Task 5b: complete (commits fffffff..1111111, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && ! grep -q '^Task 5b: complete' "$wsb/progress.md"; then pass "the crash seam stops after the ref moved, marker left"; else fail "the crash seam stops after the ref moved (rc=$rc)"; fi
tip_before=$(git -C "$co_b" rev-parse hyperpowers/state)
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=up-to-date" ] && grep -q '^Task 5b: complete' "$wsb/progress.md" && [ ! -f "$co_b/.sync-applying" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$tip_before" ]; then pass "the next sync recovers the interrupted apply without a revert commit"; else fail "the next sync recovers the interrupted apply without a revert commit ($out)"; fi

# A remote finish racing a local writer: refused, nothing changed. The seam
# writes after the pending check and right before the rename.
printf 'Task 6: complete (commits ddddddd..eeeeeee, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
run_state "$PAIR_A" finish docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-delete:plans/$(basename "$wsa")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=remote-finished" ] && grep -q "plans=$(basename "$wsa")" < <(printf '%s\n' "$out") && [ -f "$wsb/progress.md" ] && grep -q '^concurrent write$' "$wsb/progress.md" && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" != "$(git -C "$co_b" rev-parse origin/hyperpowers/state)" ]; then pass "a line written after the check and before the rename still makes the remote finish refuse, ledger and ref intact"; else fail "a remote finish racing a local ledger write is refused (rc=$rc: $out)"; fi
if ( cd "$co_b" && printf 'late\n' >> "plans/.removing-probe-0/progress.md" ) 2>/dev/null; then fail "a write to a renamed-away path fails loudly"; else pass "a write to a renamed-away path fails loudly (ENOENT), never silently"; fi
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=diverged" ]; then pass "after snapshotting the local line the race is an ordinary divergence"; else fail "after snapshotting the local line the race is an ordinary divergence (rc=$rc: $out)"; fi
git -C "$co_b" -c user.name=t -c user.email=t@example.com merge -q -m "resolve after finish" -X ours origin/hyperpowers/state >/dev/null 2>&1
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); run_state "$PAIR_A" sync docs/plan.md >/dev/null

# Offline outcomes and the explicit override.
off="$TEST_ROOT/hostA/p3-off"; git clone -q "$PAIR_REMOTE" "$off" 2>/dev/null
git -C "$off" remote set-url origin "$TEST_ROOT/does-not-exist.git"
out=$(run_state "$off" sync docs/plan.md); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=offline-no-state" ]; then pass "a fresh clone that cannot fetch reports offline-no-state"; else fail "a fresh clone that cannot fetch reports offline-no-state (rc=$rc: $out)"; fi
if run_sdd_dir "$off" docs/plan.md >/dev/null 2>&1; then fail "sdd-dir refuses to invent a dossier on that host"; else pass "sdd-dir refuses to invent a dossier on that host"; fi
out=$(run_state "$off" sync docs/plan.md --assume-absent); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=assumed-absent" ] && [ -f "$STATE_ROOT/$(state_key "$off").fetched" ] && [ -e "$STATE_ROOT/$(state_key "$off")/.git" ]; then pass "--assume-absent writes the stamp and creates the orphan"; else fail "--assume-absent writes the stamp and creates the orphan (rc=$rc: $out)"; fi
out=$(run_state "$off" sync docs/plan.md); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=offline" ]; then pass "a later failed fetch with a local branch reports offline"; else fail "a later failed fetch with a local branch reports offline (rc=$rc: $out)"; fi
norem="$TEST_ROOT/norem"; make_repo "$norem"; mkdir -p "$norem/docs"; : > "$norem/docs/plan.md"; git -C "$norem" add docs; git -C "$norem" commit -qm plan
out=$(run_state "$norem" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=no-remote" ]; then pass "no remote reports no-remote"; else fail "no remote reports no-remote (rc=$rc: $out)"; fi
if [ "$(run_state "$rp" sync docs/plan.md 2>/dev/null)" = "status=plain" ]; then pass "sync under the plain backend reports plain"; else fail "sync under the plain backend reports plain"; fi

# Cross-repository: sync resolves the plan's repository, not the cwd's.
other_cwd="$TEST_ROOT/other-cwd"; make_repo "$other_cwd"
out=$(cd "$other_cwd" && bash "$SDD_STATE" sync "$PAIR_A/docs/plan.md"); rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$STATE_ROOT/$(state_key "$other_cwd")" ]; then pass "sync from another repository's cwd touches only the plan repository"; else fail "sync from another repository's cwd touches only the plan repository (rc=$rc: $out)"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: the `sync` section fails on the usage message.

- [ ] **Step 3: Add `sync`**

Insert before the `# --- dispatch` block of `sdd-state`:

```bash
# --- sync --------------------------------------------------------------------
tip_of() { git -C "$1" rev-parse -q --verify "$2^{commit}" 2>/dev/null || true; }
short() { if [ -n "$1" ]; then printf '%s' "${1:0:7}"; else printf 'none'; fi; }
age_of() { # <checkout> <sha>... -> seconds since the newest of them
  local co=$1 newest=0 t s
  shift
  for s in "$@"; do
    [ -n "$s" ] || continue
    t=$(git -C "$co" log -1 --format=%ct "$s" 2>/dev/null || echo 0)
    [ "$t" -gt "$newest" ] && newest=$t
  done
  if [ "$newest" -gt 0 ]; then echo $(( $(date +%s) - newest )); else echo 0; fi
}
# Commit every plan directory with pending tracked changes, so the working
# tree equals the local tip and nothing local can be lost.
snapshot_pending() {
  local d name
  for d in "$CO"/plans/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ -n "$(git -C "$CO" status --porcelain -- "plans/$name" 2>/dev/null)" ] || continue
    hp_commit_paths "$CO" "$BRANCH" "sdd $name: snapshot $(hp_utc_now)" "plans/$name" >/dev/null || return 2
  done
}
# apply_files <S> <target>: bring the working tree from S to target without
# ever overwriting a ledger. Added or modified ledgers get the target's new
# lines appended; other files are checked out; files the target deletes are
# removed, a ledger among them through remove_verified. Any failure returns 2;
# a changed ledger the target deletes returns 6.
apply_files() {
  local S=$1 target=$2 path dir
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    mkdir -p "$(dirname "$CO/$path")" || return 2
    case "$path" in
      plans/*/progress.md)
        if [ -f "$CO/$path" ]; then
          git -C "$CO" diff -U0 "$S" "$target" -- "$path" | sed -n '/^+++/d; s/^+//p' >> "$CO/$path" || return 2
        else
          git -C "$CO" show "$target:$path" > "$CO/$path" || return 2
        fi ;;
      *) git -C "$CO" checkout -q "$target" -- "$path" || return 2 ;;
    esac
  done < <(git -C "$CO" diff --name-only --diff-filter=AM "$S" "$target")
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      plans/*/progress.md)
        dir=$(dirname "$CO/$path")
        if [ -d "$dir" ]; then remove_verified "$dir" "$S:plans/$(basename "$dir")" || return 6; fi ;;
      *) rm -f "$CO/$path" ;;
    esac
  done < <(git -C "$CO" diff --name-only --diff-filter=D "$S" "$target")
  return 0
}
# recover_apply: finish an apply that was interrupted after the ref moved.
recover_apply() {
  local S target
  [ -f "$CO/.sync-applying" ] || return 0
  read -r S target < "$CO/.sync-applying"
  if [ "$(tip_of "$CO" "refs/heads/$BRANCH")" = "$target" ]; then
    git -C "$CO" reset -q 2>/dev/null
    apply_files "$S" "$target" || return 2
  fi
  rm -f "$CO/.sync-applying"
}
# apply_target <S> <target>: 0 applied, 5 retry (a non-ledger file changed
# meanwhile), 6 remote-finished (a ledger the target deletes changed here),
# 2 error. Controllers write without the lock, so the working tree is live.
apply_target() {
  local S=$1 target=$2 pending line status path res
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in sync-before-apply:*) printf 'concurrent write\n' >> "$CO/${HYPERPOWERS_TEST_WRITER_AT#sync-before-apply:}" ;; esac
  if [ "${HYPERPOWERS_TEST_PAUSE_AT:-}" = sync-before-apply ]; then
    while [ -e "$CO/.sync-pause" ]; do sleep 0.1; done
  fi
  pending=$(git -C "$CO" status --porcelain -- plans/ 2>/dev/null)
  if [ -n "$pending" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      status=${line:0:2}; path=${line:3}
      case "$status|$path" in
        " M|plans/"*"/progress.md") ;;
        *) return 5 ;;
      esac
    done < <(printf '%s\n' "$pending")
  fi
  # Ledgers the target deletes are a remote finish: rename, verify, delete
  # each one first, before the ref moves, so a line written up to the rename
  # is caught and nothing has changed when it is.
  REMOTE_FINISHED=""
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in sync-before-delete:*) printf 'concurrent write\n' >> "$CO/${HYPERPOWERS_TEST_WRITER_AT#sync-before-delete:}" ;; esac
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in plans/*/progress.md) ;; *) continue ;; esac
    if [ -d "$(dirname "$CO/$path")" ] && ! remove_verified "$(dirname "$CO/$path")" "$S:plans/$(basename "$(dirname "$path")")"; then
      REMOTE_FINISHED="$REMOTE_FINISHED,$(enc "$(basename "$(dirname "$path")")")"
    fi
  done < <(git -C "$CO" diff --name-only --diff-filter=D "$S" "$target")
  if [ -n "$REMOTE_FINISHED" ]; then REMOTE_FINISHED=${REMOTE_FINISHED#,}; return 6; fi
  printf '%s %s\n' "$S" "$target" > "$CO/.sync-applying"
  git -C "$CO" update-ref -m "sdd sync" "refs/heads/$BRANCH" "$target" "$S" 2>/dev/null || { rm -f "$CO/.sync-applying"; return 5; }
  if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = sync-after-update-ref ]; then hp_unlock; exit 99; fi
  git -C "$CO" reset -q 2>/dev/null
  apply_files "$S" "$target"; res=$?
  [ "$res" -eq 0 ] || return "$res"
  rm -f "$CO/.sync-applying"
  return 0
}
cmd_sync() {
  local plan="" repo="" assume=0 stamp err rc S R target kind attempt mt tree res had_co created="" ensure
  REMOTE_FINISHED=""
  # remove_verified (Task 6) and recover_apply live in this file; sync, finish, handoff and snapshot share them.
  while [ $# -gt 0 ]; do
    case "$1" in
      --assume-absent) assume=1; shift ;;
      --repo) [ $# -ge 2 ] || usage; repo=$2; shift 2 ;;
      -*) usage ;;
      *) plan=$1; shift ;;
    esac
  done
  if [ -n "$plan" ]; then
    resolve_plan_basic "$plan"
  elif [ -n "$repo" ]; then
    PLAN_DIR=$(hp_physical_dir "$repo") || usage
    git -C "$PLAN_DIR" rev-parse --git-dir >/dev/null 2>&1 || { echo "sdd-state: not a git repository: $repo" >&2; exit 2; }
    BRANCH=$(hp_state_branch "$PLAN_DIR"); REMOTE=$(hp_state_remote "$PLAN_DIR"); CO=$(hp_checkout_path "$PLAN_DIR")
  else
    usage
  fi
  if [ "$(hp_backend "$PLAN_DIR")" = plain ]; then echo "status=plain"; return 0; fi
  stamp=$(hp_stamp_path "$PLAN_DIR")
  mkdir -p "$(dirname "$stamp")"
  # Outcomes that end before reconciliation still ensure the checkout.
  settle() { # <status> <exit>
    ensure=$(hp_ensure_checkout "$PLAN_DIR") || return 2
    if [ "${ensure%% *}" != branch ]; then echo "status=plain"; return 0; fi
    S=$(tip_of "$CO" "refs/heads/$BRANCH")
    echo "status=$1 local=$(short "$S") remote=none age=$(age_of "$CO" "$S")"
    return "$2"
  }
  if [ "$assume" -eq 1 ]; then : > "$stamp"; settle assumed-absent 0; return $?; fi
  if ! hp_has_remote "$PLAN_DIR"; then : > "$stamp"; settle no-remote 0; return $?; fi
  err=$(GIT_HTTP_LOW_SPEED_LIMIT=1 GIT_HTTP_LOW_SPEED_TIME=30 git -C "$PLAN_DIR" fetch -q "$REMOTE" "+refs/heads/$BRANCH:refs/remotes/$REMOTE/$BRANCH" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    case "$err" in
      *"couldn't find remote ref"*) : > "$stamp"; settle absent 0; return $? ;;
    esac
    S=$(tip_of "$PLAN_DIR" "refs/heads/$BRANCH")
    if [ -n "$S" ]; then
      hp_ensure_checkout "$PLAN_DIR" >/dev/null 2>&1 || true
      echo "status=offline local=$(short "$S") remote=$(short "$(tip_of "$PLAN_DIR" "refs/remotes/$REMOTE/$BRANCH")") age=$(age_of "$PLAN_DIR" "$S")"
      return 1
    fi
    echo "status=offline-no-state local=none remote=none age=0"
    return 1
  fi
  : > "$stamp"
  had_co=0; [ -e "$CO/.git" ] && had_co=1
  ensure=$(hp_ensure_checkout "$PLAN_DIR") || return 2
  if [ "${ensure%% *}" != branch ]; then echo "status=plain"; return 0; fi
  [ "$had_co" -eq 1 ] || created=created
  R=$(tip_of "$CO" "refs/remotes/$REMOTE/$BRANCH")
  hp_lock "$PLAN_DIR" || return 2
  recover_apply || { hp_unlock; echo "status=error"; return 2; }
  for attempt in 1 2 3; do
    snapshot_pending || { hp_unlock; echo "status=error"; return 2; }
    S=$(tip_of "$CO" "refs/heads/$BRANCH")
    if [ "$S" = "$R" ]; then
      hp_unlock; echo "status=${created:-up-to-date} local=$(short "$S") remote=$(short "$R") age=$(age_of "$CO" "$S")"; return 0
    fi
    if git -C "$CO" merge-base --is-ancestor "$S" "$R" 2>/dev/null; then
      target=$R; kind=fast-forwarded
    elif git -C "$CO" merge-base --is-ancestor "$R" "$S" 2>/dev/null; then
      hp_unlock; echo "status=ahead local=$(short "$S") remote=$(short "$R") age=$(age_of "$CO" "$S" "$R")"; return 0
    else
      if hp_git_version_at_least 2 38 && mt=$(git -C "$CO" merge-tree --write-tree "$S" "$R" 2>/dev/null); then
        tree=$(printf '%s\n' "$mt" | head -n 1)
        target=$(printf 'sdd: merge %s into %s\n' "$(short "$R")" "$(short "$S")" | hp_git_id "$CO" commit-tree "$tree" -p "$S" -p "$R") || { hp_unlock; echo "status=error"; return 2; }
        kind=merged
      else
        hp_unlock
        echo "status=diverged local=$(short "$S") remote=$(short "$R") age=$(age_of "$CO" "$S" "$R")"
        echo "merge=git -C $CO merge $REMOTE/$BRANCH"
        return 3
      fi
    fi
    apply_target "$S" "$target"; res=$?
    if [ "$res" -eq 0 ]; then
      hp_unlock; echo "status=$kind local=$(short "$target") remote=$(short "$R") age=$(age_of "$CO" "$target")"; return 0
    fi
    if [ "$res" -eq 6 ]; then
      hp_unlock; echo "status=remote-finished plans=$REMOTE_FINISHED local=$(short "$S") remote=$(short "$R") age=$(age_of "$CO" "$S" "$R")"; return 3
    fi
    [ "$res" -eq 5 ] || { hp_unlock; echo "status=error"; return 2; }
  done
  hp_unlock
  echo "status=busy local=$(short "$S") remote=$(short "$R") age=$(age_of "$CO" "$S" "$R")"
  return 3
}
```

Add the dispatch arm `sync) cmd_sync "$@" ;;`.

- [ ] **Step 4: Run the tests**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: `STATUS: PASSED`. If the `merged` case reports `diverged` instead, `git merge-tree` did not apply the union driver: confirm with `git -C <checkout> check-attr merge plans/<ws>/progress.md`, and if the attribute is set, pass the checkout's tip as the attribute source (`git -C "$CO" --attr-source="$S" merge-tree --write-tree "$S" "$R"`, git 2.41+) and record the finding in the task report. Do not weaken the assertion.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh`

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): sync fetches the state branch and reconciles under live writers"
```

---

### Task 8: `sdd-state verify`

**Risk tier:** high — it decides whether a resumed run may trust the ledger against the code and plan it sees.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (add `root_of`, `cmd_verify`, dispatch arm)
- Test: `tests/sdd/test-sdd-state.sh` (append the `verify` section; its hand-off lines are written by hand, so the section is green without Task 9)

**Interfaces:**
- Consumes: `resolve_plan`, `ledger_path`, `hp_physical_dir`.
- Produces: `sdd-state verify PLAN_FILE [--code-repo DIR]` printing `status=ok tasks=<n>`, `status=wrong-repo expected=<root sha7> repo=<code|plan>` (exit 9), `status=code-missing missing=<sha7,...> branch=<name>` (exit 9), or `status=plan-stale sha=<sha7> branch=<name>` (exit 9); both endpoints of every `commits <base7>..<head7>` range are checked; a shallow repository (`git rev-parse --is-shallow-repository` is `true`) skips the root comparison, because its shallow boundary reads as a root, and is judged by commit presence (Deviation 5); `root_of REPO_DIR` prints the lexicographically smallest root commit of `HEAD`, which Task 9's `handoff` records.

- [ ] **Step 1: Write the failing tests**

Insert above the closing STATUS lines of `tests/sdd/test-sdd-state.sh`:

```bash
echo ""
echo "=== verify ==="
make_pair p5
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
base_a=$(git -C "$PAIR_A" rev-parse HEAD)
printf 'work\n' > "$PAIR_A/work.txt"; git -C "$PAIR_A" add work.txt; git -C "$PAIR_A" commit -qm "task 1"
head_a=$(git -C "$PAIR_A" rev-parse HEAD)
root_a=$(git -C "$PAIR_A" rev-list --max-parents=0 HEAD | sort | head -n 1)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits %s..%s, review clean)\n' "$(git -C "$PAIR_A" rev-parse --short=7 "$base_a")" "$(git -C "$PAIR_A" rev-parse --short=7 "$head_a")" > "$wsa/progress.md"
if [ "$(run_state "$PAIR_A" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "verify passes where the commits live"; else fail "verify passes where the commits live"; fi
printf 'handoff: code root=%s main@%s at 2026-10-20T00:00:00Z from hostA\n' "$root_a" "$head_a" >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=created" ]; then pass "the second host receives the dossier"; else fail "the second host receives the dossier ($out)"; fi
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=code-missing missing=$(git -C "$PAIR_A" rev-parse --short=7 "$head_a") branch=main" ]; then pass "verify names the missing head commit once and the branch before the pull"; else fail "verify names the missing head commit once and the branch before the pull (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
if [ "$(run_state "$PAIR_B" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "verify passes after the pull"; else fail "verify passes after the pull"; fi
# A range whose base is missing fails too: a shallow clone of depth 1 has
# the head but not the base.
shallow="$TEST_ROOT/hostB/p5-shallow"
git clone -q --depth 1 "file://$PAIR_REMOTE" "$shallow" 2>/dev/null
git -C "$shallow" config user.name t; git -C "$shallow" config user.email t@example.com
run_state "$shallow" sync docs/plan.md >/dev/null
out=$(run_state "$shallow" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% *}" = "status=code-missing" ] && grep -q "missing=$(git -C "$PAIR_A" rev-parse --short=7 "$base_a")" < <(printf '%s\n' "$out"); then pass "a shallow checkout without the range's base is code-missing, not wrong-repo"; else fail "a shallow checkout without the range's base is code-missing, not wrong-repo (rc=$rc: $out)"; fi
unrelated="$TEST_ROOT/unrelated"; make_repo "$unrelated"
out=$(cd "$unrelated" && bash "$SDD_STATE" verify "$PAIR_B/docs/plan.md"); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-repo expected=${root_a:0:7} repo=code" ]; then pass "verify from an unrelated repository reports wrong-repo"; else fail "verify from an unrelated repository reports wrong-repo (rc=$rc: $out)"; fi
# The plan repository is checked when a handoff: plan line exists.
wsb="$STATE_ROOT/$(state_key "$PAIR_B")/plans/$(basename "$wsa")"
git -C "$PAIR_A" commit -q --allow-empty -m "plan v2"
printf 'handoff: plan root=%s main@%s\n' "$root_a" "$(git -C "$PAIR_A" rev-parse HEAD)" >> "$wsb/progress.md"
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=plan-stale sha=$(git -C "$PAIR_A" rev-parse --short=7 HEAD) branch=main" ]; then pass "a destination holding an older plan is plan-stale"; else fail "a destination holding an older plan is plan-stale (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
if [ "$(run_state "$PAIR_B" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "verify passes once the plan repository has the recorded commit"; else fail "verify passes once the plan repository has the recorded commit"; fi
printf 'handoff: plan root=0000000000000000000000000000000000000001 main@%s\n' "$(git -C "$PAIR_A" rev-parse HEAD)" >> "$wsb/progress.md"
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-repo expected=0000000 repo=plan" ]; then pass "a plan repository with another root is wrong-repo"; else fail "a plan repository with another root is wrong-repo (rc=$rc: $out)"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: the `verify` section fails on the usage message.

- [ ] **Step 3: Add `verify`**

Insert before the `# --- dispatch` block of `sdd-state`:

```bash
# --- verify ------------------------------------------------------------------
# The repository identity recorded at hand-off: the lexicographically
# smallest root commit of HEAD, stable across clones and hosts.
root_of() { git -C "$1" rev-list --max-parents=0 HEAD 2>/dev/null | sort | head -n 1; }
# <repo> <sha>: the commit exists, is unambiguous, and is reachable from HEAD.
commit_present() {
  git -C "$1" cat-file -e "$2^{commit}" 2>/dev/null && git -C "$1" merge-base --is-ancestor "$2" HEAD 2>/dev/null
}
cmd_verify() {
  local plan="" code="" ledger line rec_root rec_sha="" rec_branch="" shas sha missing="" tasks plan_line plan_root plan_sha plan_branch
  while [ $# -gt 0 ]; do
    case "$1" in
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] || usage
  resolve_plan "$plan"
  ledger=$(ledger_path)
  [ -f "$ledger" ] || { echo "status=ok tasks=0"; return 0; }
  if [ -z "$code" ]; then
    code=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "sdd-state: not inside a code repository; pass --code-repo DIR" >&2; exit 2; }
  fi
  code=$(hp_physical_dir "$code") || { echo "sdd-state: no such directory: $code" >&2; exit 2; }
  line=$(grep -E '^handoff: code root=' "$ledger" | tail -n 1)
  if [ -n "$line" ]; then
    rec_root=$(printf '%s' "$line" | sed -n 's/^handoff: code root=\([0-9a-f]*\) .*/\1/p')
    rec_branch=$(printf '%s' "$line" | sed -n 's/^handoff: code root=[0-9a-f]* \(.*\)@[0-9a-f]* at .*/\1/p')
    rec_sha=$(printf '%s' "$line" | sed -n 's/^handoff: code root=[0-9a-f]* .*@\([0-9a-f]*\) at .*/\1/p')
    # A shallow clone's boundary commits read as roots: skip the identity
    # comparison there and let commit presence speak.
    if [ "$(git -C "$code" rev-parse --is-shallow-repository 2>/dev/null)" != true ] && [ "$(root_of "$code")" != "$rec_root" ]; then
      echo "status=wrong-repo expected=${rec_root:0:7} repo=code"; return 9
    fi
  fi
  # Both endpoints of every completion range, then the hand-off head.
  shas=$(grep -Eo 'Task [0-9]+: complete \(commits [0-9a-f]+\.\.[0-9a-f]+' "$ledger" | sed 's/.*(commits //; s/\.\./ /')
  tasks=$(printf '%s\n' "$shas" | grep -c .)
  [ -n "$rec_sha" ] && shas="$shas $rec_sha"
  for sha in $shas; do
    case ",$missing," in *",${sha:0:7},"*) continue ;; esac
    commit_present "$code" "$sha" || missing="$missing,${sha:0:7}"
  done
  if [ -n "$missing" ]; then echo "status=code-missing missing=${missing#,} branch=${rec_branch:-unknown}"; return 9; fi
  plan_line=$(grep -E '^handoff: plan root=' "$ledger" | tail -n 1)
  if [ -n "$plan_line" ]; then
    plan_root=$(printf '%s' "$plan_line" | sed -n 's/^handoff: plan root=\([0-9a-f]*\) .*/\1/p')
    plan_branch=$(printf '%s' "$plan_line" | sed -n 's/^handoff: plan root=[0-9a-f]* \(.*\)@[0-9a-f]*$/\1/p')
    plan_sha=$(printf '%s' "$plan_line" | sed -n 's/^handoff: plan root=[0-9a-f]* .*@\([0-9a-f]*\)$/\1/p')
    if [ "$(git -C "$REPO" rev-parse --is-shallow-repository 2>/dev/null)" != true ] && [ "$(root_of "$REPO")" != "$plan_root" ]; then
      echo "status=wrong-repo expected=${plan_root:0:7} repo=plan"; return 9
    fi
    commit_present "$REPO" "$plan_sha" || { echo "status=plan-stale sha=${plan_sha:0:7} branch=$plan_branch"; return 9; }
  fi
  echo "status=ok tasks=$tasks"
}
```

Add the dispatch arm `verify) cmd_verify "$@" ;;`.

- [ ] **Step 4: Run the tests**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: `STATUS: PASSED`. The shallow-clone case needs `file://` so git honors `--depth`; if the host git clones a local path fully anyway, the test's `git clone -q --depth 1 "file://..."` form is the one that works.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh`

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): verify checks both ends of every completion range, the code repository and the plan repository"
```

---

### Task 9: `sdd-state handoff`

**Risk tier:** high — the one step that publishes the dossier, with the leak scan and the two preconditions in front of it.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (add `cmd_handoff`, dispatch arm)
- Test: `tests/sdd/test-sdd-state.sh` (append the `handoff` section)

**Interfaces:**
- Consumes: `resolve_plan`, `hp_plan_rel`, `root_of`, `IDENTITY_PREFIX`, `hp_lock`, `hp_commit_paths`, `hp_has_remote`, `hp_utc_now`.
- Produces: `sdd-state handoff PLAN_FILE [--push] [--plan-untracked-ok] [--code-dirty-ok] [--code-repo DIR]` printing `status=snapshot sha=<sha7> code=<branch>@<sha7> [plan=<branch>@<sha7>] push=<remote>/<branch>|none`, `status=pushed sha=<sha7> code=... [plan=...]`, `status=plan-not-committed file=<rel>` (exit 8), `status=code-dirty paths=<p1,p2,p3>` (exit 10), `status=detached-head repo=<code|plan>` (exit 11), `status=plain` (exit 7), `status=scan-failed reason=git|scanner` (exit 5), `status=push-failed sha=<sha7>` (exit 1). The repository lock is held from the snapshot through the scan and the push, and the push publishes the exact scanned commit (`<sha>:refs/heads/<branch>`), so a snapshot another session makes meanwhile waits and lands after it. The scan covers every commit the push would publish, the root commit included (`git log --root -p`). The pause seam `HYPERPOWERS_TEST_PAUSE_AT=handoff-after-scan` holds while `<checkout>/.handoff-pause` exists.

- [ ] **Step 1: Write the failing tests**

Insert above the closing STATUS lines of `tests/sdd/test-sdd-state.sh`:

```bash
echo ""
echo "=== handoff ==="
make_pair p7
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf 'work\n' > "$PAIR_A/work.txt"; git -C "$PAIR_A" add work.txt; git -C "$PAIR_A" commit -qm "task 1"
head_a=$(git -C "$PAIR_A" rev-parse HEAD)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits %s..%s, review clean)\n' "$(git -C "$PAIR_A" rev-parse --short=7 HEAD~1)" "$(git -C "$PAIR_A" rev-parse --short=7 HEAD)" > "$wsa/progress.md"
: > "$PAIR_A/docs/untracked.md"
out=$(run_state "$PAIR_A" handoff docs/untracked.md); rc=$?
if [ "$rc" -eq 8 ] && [ "$out" = "status=plan-not-committed file=docs/untracked.md" ]; then pass "handoff refuses an untracked plan"; else fail "handoff refuses an untracked plan (rc=$rc: $out)"; fi
rm -f "$PAIR_A/docs/untracked.md"
printf 'edit\n' >> "$PAIR_A/docs/plan.md"
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 8 ]; then pass "handoff refuses a modified plan"; else fail "handoff refuses a modified plan (rc=$rc: $out)"; fi
out=$(run_state "$PAIR_A" handoff docs/plan.md --plan-untracked-ok); rc=$?
if [ "$rc" -eq 10 ] && [ "${out%% *}" = "status=code-dirty" ]; then pass "--plan-untracked-ok waives the plan check and the dirty tree is caught next"; else fail "--plan-untracked-ok waives the plan check and the dirty tree is caught next (rc=$rc: $out)"; fi
git -C "$PAIR_A" checkout -q -- docs/plan.md
: > "$PAIR_A/stray.txt"
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 10 ] && [ "$out" = "status=code-dirty paths=stray.txt" ]; then pass "an untracked file is a dirty code tree"; else fail "an untracked file is a dirty code tree (rc=$rc: $out)"; fi
out=$(run_state "$PAIR_A" handoff docs/plan.md --code-dirty-ok); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=snapshot" ]; then pass "--code-dirty-ok waives the dirty check"; else fail "--code-dirty-ok waives the dirty check (rc=$rc: $out)"; fi
rm -f "$PAIR_A/stray.txt"
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
case "$out" in "status=snapshot sha="???????" code=main@"???????" push=origin/hyperpowers/state") pass "handoff without --push snapshots and names the push target" ;; *) fail "handoff without --push snapshots and names the push target (rc=$rc: $out)" ;; esac
if grep -Eq "^handoff: code root=[0-9a-f]{40} main@$head_a at [0-9TZ:-]+ from " "$wsa/progress.md"; then pass "the ledger records the code repository's root, branch and head"; else fail "the ledger records the code repository's root, branch and head"; fi
if ! git -C "$PAIR_REMOTE" rev-parse -q --verify refs/heads/hyperpowers/state >/dev/null 2>&1; then pass "nothing was pushed without --push"; else fail "nothing was pushed without --push"; fi

# The first push is scanned over the whole history, root commit included.
git -C "$PAIR_A" config hyperpowers.prePushScan '! grep -q SECRETTOKEN'
printf 'SECRETTOKEN\n' > "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
rm -f "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_A" handoff docs/plan.md --push 2>/dev/null); rc=$?
if [ "$rc" -eq 5 ] && [ "$out" = "status=scan-failed reason=scanner" ] && ! git -C "$PAIR_REMOTE" rev-parse -q --verify refs/heads/hyperpowers/state >/dev/null 2>&1; then pass "content added and deleted before the first push still blocks it"; else fail "content added and deleted before the first push still blocks it (rc=$rc: $out)"; fi
git -C "$PAIR_A" config hyperpowers.prePushScan 'cat > /dev/null'
out=$(run_state "$PAIR_A" handoff docs/plan.md --push); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pushed" ] && [ "$(git -C "$PAIR_REMOTE" rev-parse refs/heads/hyperpowers/state)" = "$(git -C "$PAIR_A" rev-parse hyperpowers/state)" ]; then pass "a passing scanner lets --push publish the state branch"; else fail "a passing scanner lets --push publish the state branch (rc=$rc: $out)"; fi
git -C "$PAIR_A" config hyperpowers.prePushScan '! grep -q SECRETTOKEN'
printf 'SECRETTOKEN again\n' > "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
rm -f "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_A" handoff docs/plan.md --push 2>/dev/null); rc=$?
if [ "$rc" -eq 5 ]; then pass "content added and deleted since the last push blocks a later push"; else fail "content added and deleted since the last push blocks a later push (rc=$rc: $out)"; fi
git -C "$PAIR_A" config --unset hyperpowers.prePushScan

# A snapshot queued during a hand-off lands after the push; the push carries
# exactly the scanned commit.
co_a7="$STATE_ROOT/$(state_key "$PAIR_A")"
git -C "$PAIR_A" config hyperpowers.prePushScan 'cat > /dev/null'
: > "$co_a7/.handoff-pause"
( cd "$PAIR_A" && HYPERPOWERS_TEST_PAUSE_AT=handoff-after-scan bash "$SDD_STATE" handoff docs/plan.md --push > "$TEST_ROOT/p7.handoff" 2>/dev/null ) &
sleep 1
printf 'queued\n' > "$wsa/task-9-report.md"
( run_state "$PAIR_A" snapshot docs/plan.md > "$TEST_ROOT/p7.snap" 2>/dev/null ) &
sleep 1; rm -f "$co_a7/.handoff-pause"; wait
pushed_sha=$(sed -n 's/^status=pushed sha=\([0-9a-f]*\).*/\1/p' "$TEST_ROOT/p7.handoff")
if [ -n "$pushed_sha" ] && [ "$(git -C "$PAIR_REMOTE" rev-parse --short=7 refs/heads/hyperpowers/state)" = "$pushed_sha" ] && [ "$(git -C "$PAIR_A" rev-parse --short=7 hyperpowers/state)" != "$pushed_sha" ] && grep -q '^status=snapshot' "$TEST_ROOT/p7.snap"; then pass "a snapshot queued during a hand-off waits; the push carries the scanned commit only"; else fail "a snapshot queued during a hand-off waits ($(cat "$TEST_ROOT/p7.handoff") / $(cat "$TEST_ROOT/p7.snap"))"; fi
git -C "$PAIR_A" config --unset hyperpowers.prePushScan
git -C "$PAIR_A" checkout -q --detach
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 11 ] && [ "$out" = "status=detached-head repo=code" ]; then pass "a detached code checkout cannot hand off"; else fail "a detached code checkout cannot hand off (rc=$rc: $out)"; fi
git -C "$PAIR_A" checkout -q main

# Arrival on the second host after a real hand-off.
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=created" ]; then pass "the second host receives the handed-off dossier"; else fail "the second host receives the handed-off dossier ($out)"; fi
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% *}" = "status=code-missing" ]; then pass "arrival before the code pull is code-missing"; else fail "arrival before the code pull is code-missing (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
if [ "$(run_state "$PAIR_B" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "arrival after the code pull verifies"; else fail "arrival after the code pull verifies"; fi
if [ "$(run_state "$rp" handoff docs/plan.md 2>/dev/null)" = "status=plain" ]; then pass "handoff under the plain backend reports plain"; else fail "handoff under the plain backend reports plain"; fi
rc=0; run_state "$rp" handoff docs/plan.md >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 7 ]; then pass "handoff under the plain backend exits 7"; else fail "handoff under the plain backend exits 7 (rc=$rc)"; fi

# Cross-repository: plan in P, code in C; a clean destination pulls both.
make_pair p8plan; P_A=$PAIR_A; P_B=$PAIR_B
make_pair p8code; C_A=$PAIR_A; C_B=$PAIR_B
mkdir -p "$P_A/docs"; : > "$P_A/docs/plan.md"; git -C "$P_A" add docs; git -C "$P_A" commit -qm plan; git -C "$P_A" push -q origin main 2>/dev/null
( cd "$C_A" && bash "$SDD_STATE" sync "$P_A/docs/plan.md" >/dev/null )
wsp=$(cd "$C_A" && bash "$SDD_DIR" "$P_A/docs/plan.md")
printf 'code\n' > "$C_A/code.txt"; git -C "$C_A" add code.txt; git -C "$C_A" commit -qm "task 1"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits %s..%s, review clean)\n' "$(git -C "$C_A" rev-parse --short=7 HEAD~1)" "$(git -C "$C_A" rev-parse --short=7 HEAD)" > "$wsp/progress.md"
out=$(cd "$C_A" && bash "$SDD_STATE" handoff "$P_A/docs/plan.md" --push); rc=$?
if [ "$rc" -eq 0 ] && case "$out" in "status=pushed sha="???????" code=main@"???????" plan=main@"???????) true;; *) false;; esac && grep -q '^handoff: plan root=' "$wsp/progress.md"; then pass "a cross-repository handoff records and names the plan branch"; else fail "a cross-repository handoff records and names the plan branch (rc=$rc: $out)"; fi
git -C "$C_A" push -q origin main 2>/dev/null
git -C "$P_B" pull -q origin main 2>/dev/null; git -C "$C_B" pull -q origin main 2>/dev/null
( cd "$C_B" && bash "$SDD_STATE" sync "$P_B/docs/plan.md" >/dev/null )
out=$(cd "$C_B" && bash "$SDD_STATE" verify "$P_B/docs/plan.md"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=ok tasks=1" ]; then pass "clean clones of both repositories verify after pulling the named branches"; else fail "clean clones of both repositories verify after pulling the named branches (rc=$rc: $out)"; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: the `handoff` section fails on the usage message.

- [ ] **Step 3: Add `handoff`**

Insert before the `# --- dispatch` block of `sdd-state`:

```bash
# --- handoff -----------------------------------------------------------------
# Snapshot for another host. Refuses an uncommitted plan file (the
# destination could not start) and a dirty code tree (work would stay
# behind unnoticed); records the code repository's identity, and the plan
# repository's when it differs; pushes only with --push, after the
# configured scan over every commit the push would publish.
cmd_handoff() {
  local plan="" push=0 plan_ok=0 dirty_ok=0 code="" rel dirty code_root code_branch code_sha plan_root plan_sha plan_branch extra="" ledger out rc sha cmd range patch err pushto
  while [ $# -gt 0 ]; do
    case "$1" in
      --push) push=1; shift ;;
      --plan-untracked-ok) plan_ok=1; shift ;;
      --code-dirty-ok) dirty_ok=1; shift ;;
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] || usage
  resolve_plan "$plan"
  rel=$(hp_plan_rel "$plan")
  if [ "$plan_ok" -eq 0 ]; then
    if ! git -C "$REPO" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 || ! git -C "$REPO" diff --quiet HEAD -- "$rel" 2>/dev/null; then
      echo "status=plan-not-committed file=$(enc "$rel")"; return 8
    fi
  fi
  if [ -z "$code" ]; then
    code=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "sdd-state: not inside a code repository; pass --code-repo DIR" >&2; exit 2; }
  fi
  code=$(hp_physical_dir "$code") || { echo "sdd-state: no such directory: $code" >&2; exit 2; }
  if [ "$dirty_ok" -eq 0 ]; then
    dirty=$(git -C "$code" status --porcelain 2>/dev/null | head -n 3 | sed 's/^...//; s/ /%20/g' | tr '\n' ',')
    if [ -n "$dirty" ]; then echo "status=code-dirty paths=${dirty%,}"; return 10; fi
  fi
  if [ "$BACKEND" != branch ]; then echo "status=plain"; return 7; fi
  # A detached checkout has no branch the other host could pull.
  code_branch=$(git -C "$code" branch --show-current 2>/dev/null)
  [ -n "$code_branch" ] || { echo "status=detached-head repo=code"; return 11; }
  if [ "$code" != "$REPO" ]; then
    plan_branch=$(git -C "$REPO" branch --show-current 2>/dev/null)
    [ -n "$plan_branch" ] || { echo "status=detached-head repo=plan"; return 11; }
  fi
  code_root=$(root_of "$code"); code_sha=$(git -C "$code" rev-parse HEAD)
  mkdir -p "$WSDIR"
  ledger=$(ledger_path)
  [ -f "$ledger" ] || printf '%s%s\n' "$IDENTITY_PREFIX" "$rel" > "$ledger"
  printf 'handoff: code root=%s %s@%s at %s from %s\n' "$code_root" "$code_branch" "$code_sha" "$(hp_utc_now)" "$(hostname)" >> "$ledger"
  if [ "$code" != "$REPO" ]; then
    plan_root=$(root_of "$REPO"); plan_sha=$(git -C "$REPO" rev-parse HEAD)
    printf 'handoff: plan root=%s %s@%s\n' "$plan_root" "$plan_branch" "$plan_sha" >> "$ledger"
    extra=" plan=$plan_branch@${plan_sha:0:7}"
  fi
  # The lock is held from here through the scan and the push, so what is
  # pushed is exactly what was scanned.
  hp_lock "$PLAN_DIR" || return 2
  recover_apply || { hp_unlock; echo "status=error"; return 2; }
  out=$(hp_commit_paths "$CO" "$BRANCH" "sdd $SLUG: handoff $(hp_utc_now)" "plans/$WS"); rc=$?
  [ "$rc" -eq 0 ] || { hp_unlock; echo "status=error"; return 2; }
  sha=$(git -C "$CO" rev-parse "refs/heads/$BRANCH")
  if hp_has_remote "$PLAN_DIR"; then pushto="$REMOTE/$BRANCH"; else pushto=none; fi
  if [ "$push" -eq 0 ] || [ "$pushto" = none ]; then
    hp_unlock
    echo "status=snapshot sha=${sha:0:7} code=$code_branch@${code_sha:0:7}$extra push=$pushto"; return 0
  fi
  cmd=$(git -C "$PLAN_DIR" config --get hyperpowers.prePushScan 2>/dev/null || true)
  if [ -n "$cmd" ]; then
    # Every commit the push publishes, the root commit's own patch included.
    if git -C "$CO" rev-parse -q --verify "refs/remotes/$REMOTE/$BRANCH^{commit}" >/dev/null 2>&1; then range="$REMOTE/$BRANCH..HEAD"; else range=HEAD; fi
    patch=$(mktemp "${TMPDIR:-/tmp}/sdd-scan.XXXXXX") || { hp_unlock; echo "status=error"; return 2; }
    if ! git -C "$CO" log --root -p --format= --no-color "$range" -- . > "$patch" 2>/dev/null; then rm -f "$patch"; hp_unlock; echo "status=scan-failed reason=git"; return 5; fi
    if ! (cd "$CO" && HYPERPOWERS_SCAN_RANGE="$range" sh -c "$cmd" < "$patch" >&2); then rm -f "$patch"; hp_unlock; echo "status=scan-failed reason=scanner"; return 5; fi
    rm -f "$patch"
  fi
  if [ "${HYPERPOWERS_TEST_PAUSE_AT:-}" = handoff-after-scan ]; then while [ -e "$CO/.handoff-pause" ]; do sleep 0.1; done; fi
  if ! err=$(git -C "$CO" push -q "$REMOTE" "$sha:refs/heads/$BRANCH" 2>&1); then
    hp_unlock
    printf '%s\n' "$err" >&2
    echo "status=push-failed sha=${sha:0:7}"; return 1
  fi
  hp_unlock
  echo "status=pushed sha=${sha:0:7} code=$code_branch@${code_sha:0:7}$extra"
}
```

Add the dispatch arm `handoff) cmd_handoff "$@" ;;`.

- [ ] **Step 4: Run the tests**

Run: `bash tests/sdd/test-sdd-state.sh`
Expected: `STATUS: PASSED` across every section.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh`

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd): handoff snapshots, records both repositories, scans every commit, and pushes only on request"
```

---

### Task 10: The three requesting-code-review scripts move to the common-directory key

**Risk tier:** high — `ungated-ledger` is a durable compliance record and `gate-telemetry` reports from it.

**Files:**
- Modify: `skills/requesting-code-review/scripts/codex-review-dir:17-19,43-50`
- Modify: `skills/requesting-code-review/scripts/ungated-ledger:4-5,24-25,52-57,184-199`
- Modify: `skills/requesting-code-review/scripts/gate-telemetry:26,45-57,128-141`
- Test: `tests/claude-code/test-codex-review-dir-path.sh`, `tests/codex-review-gate/test-ungated-ledger.sh`, `tests/codex-review-gate/test-gate-telemetry.sh` (additions above each file's closing lines)

**Interfaces:**
- Consumes: `hp_key`, `hp_legacy_key`, `hp_cache_root` from `sdd-common.sh`, located relative to each script (`"$SCRIPT_DIR/../../subagent-driven-development/scripts/sdd-common.sh"`).
- Produces: unchanged stdout contracts; `ungated-ledger pending [--count]` now also reads the ledger under the pre-6.17 key of the given repository.

**Mirror:** `tests/codex-review-gate/test-ungated-ledger.sh:24-33` (append and key assertions), `tests/codex-review-gate/test-gate-telemetry.sh:11-33` (`expect`, seeding).

- [ ] **Step 1: Write the failing tests**

Append above the closing STATUS lines of `tests/claude-code/test-codex-review-dir-path.sh`:

```bash
echo ""
echo "Test: every worktree of a clone shares the parent key directory"
git -C "$repo_a" commit -q --allow-empty -m init
git -C "$repo_a" worktree add -q "$TEST_ROOT/repo-a-wt" -b wt >/dev/null 2>&1
dir_wt="$(run_review_dir "$TEST_ROOT/repo-a-wt")"
if [ "$(dirname "$dir_wt")" = "$(dirname "$dir_a1")" ] && [ "$dir_wt" != "$dir_a1" ]; then pass "a linked worktree's gate dirs sit under the clone's key"; else fail "a linked worktree's gate dirs sit under the clone's key ($dir_wt vs $dir_a1)"; fi
```

Insert above the final `echo` / `ALL PASS` lines of `tests/codex-review-gate/test-ungated-ledger.sh`:

```bash
echo "ungated-ledger: common-directory key"
git -C "$repo" worktree add -q "$work/wt" -b wt >/dev/null 2>&1
before="$(wc -l < "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" | tr -d ' ')"
bash "$UL" append --class degraded-gate --gate spec --status not-ready --note 'from a worktree' "$work/wt" >/dev/null
after="$(wc -l < "$XDG_CACHE_HOME/hyperpowers/ungated/$key/ledger.jsonl" | tr -d ' ')"
[ "$after" -eq $((before + 1)) ] && pass "a linked worktree appends to the clone's ledger" || fail "a linked worktree appends to the clone's ledger ($before -> $after)"
legacy_key="$(printf '%s' "$(git -C "$work/wt" rev-parse --absolute-git-dir)" | git -C "$work/wt" hash-object --stdin)"
mkdir -p "$XDG_CACHE_HOME/hyperpowers/ungated/$legacy_key"
printf '{"v":1,"id":"legacy-1","event":"ungated","class":"degraded-gate","gate":"task","ts":"2026-10-01T00:00:00Z","repo":"/tmp/r","base":"a","head":"b","status":"stale-broker","sweepable":true,"gateDir":null,"note":"legacy pending"}\n' > "$XDG_CACHE_HOME/hyperpowers/ungated/$legacy_key/ledger.jsonl"
main_count="$(bash "$UL" pending --count "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
wt_count="$(bash "$UL" pending --count "$work/wt" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).count)')"
[ "$wt_count" -eq $((main_count + 1)) ] && pass "pending from the worktree also reads its legacy ledger" || fail "pending from the worktree also reads its legacy ledger ($wt_count vs $main_count)"
[ "$(wc -l < "$XDG_CACHE_HOME/hyperpowers/ungated/$legacy_key/ledger.jsonl" | tr -d ' ')" -eq 1 ] && pass "append never writes to the legacy key" || fail "append never writes to the legacy key"
```

Insert above the final `echo` / `ALL PASS` lines of `tests/codex-review-gate/test-gate-telemetry.sh`:

```bash
# --- the state checkout layout (portable dossiers) ---
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
srepo="$work/state-repo"; git init -q "$srepo"; git -C "$srepo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
skey="$( ( . "$LIB"; hp_key "$srepo" ) )"
st="$XDG_CACHE_HOME/hyperpowers/state/$skey/plans/plan-00000001"; mkdir -p "$st"
echo brief > "$st/task-1-brief.md"; echo brief > "$st/task-2-brief.md"; echo fix > "$st/task-2-codex-fix-brief.md"
: > "$XDG_CACHE_HOME/hyperpowers/state/$skey.backend"
smd="$( (cd "$srepo" && bash "$GT") )"
expect "$smd" "Fix-cycle rate: 1/2 tasks" "plan workspaces inside the state checkout are counted"
sall="$(bash "$GT" --all --json)"
node -e 'const j=JSON.parse(process.argv[1]);process.exit(j.repos.every(r=>/^[0-9a-f]+$/.test(r.key))?0:1)' "$sall" \
  && pass "the fleet view skips the backend, lock and stamp files beside a checkout" || fail "the fleet view skips the backend, lock and stamp files beside a checkout"
```

(`$REPO_ROOT` is defined at `tests/codex-review-gate/test-gate-telemetry.sh:6`.)

- [ ] **Step 2: Run the three suites to verify they fail**

Run, one per `bash` call: `bash tests/claude-code/test-codex-review-dir-path.sh`, `bash tests/codex-review-gate/test-ungated-ledger.sh`, `bash tests/codex-review-gate/test-gate-telemetry.sh`
Expected: the worktree assertions fail (different key per worktree today); the state-layout count is `0/0` or absent.

- [ ] **Step 3: codex-review-dir**

Replace `:17-19`:

```bash
# The git-dir-keyed parent is only for tidiness — it groups a repo's runs
# together and mirrors sdd-dir's layout. Isolation comes from mktemp, not the
# key.
```

with:

```bash
# The parent is keyed by the clone's common git directory (sdd-common.sh),
# shared by every worktree of the clone, only for tidiness: it groups a
# repository's runs together and mirrors sdd-dir's layout. Isolation comes
# from mktemp, not the key.
```

Replace the body `:43-50` with:

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../../subagent-driven-development/scripts/sdd-common.sh
. "$SCRIPT_DIR/../../subagent-driven-development/scripts/sdd-common.sh"

git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "codex-review-dir: not inside a git repository" >&2
  exit 2
}

key=$(hp_key .)
base="$(hp_cache_root)/codex-review/${key}"
mkdir -p "$base"
mktemp -d "${base}/run-XXXXXXXX"
```

- [ ] **Step 4: ungated-ledger**

Replace `:4-5`:

```bash
#   ${XDG_CACHE_HOME:-~/.cache}/hyperpowers/ungated/<key>/ledger.jsonl
# <key> is byte-identical to sdd-dir's derivation. The ungated/ root is
```

with:

```bash
#   ${XDG_CACHE_HOME:-~/.cache}/hyperpowers/ungated/<key>/ledger.jsonl
# <key> is the state key of sdd-common.sh (the clone's common git directory,
# shared by every worktree). `pending` also reads the ledger under the
# pre-6.17 per-worktree key so entries written before the upgrade stay
# visible; `append` and `mark-swept` write only the new key. The ungated/ root is
```

After `set -uo pipefail` (`:24`) add:

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../../subagent-driven-development/scripts/sdd-common.sh
. "$SCRIPT_DIR/../../subagent-driven-development/scripts/sdd-common.sh"
```

Replace `:55-57`:

```bash
key=$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)
root="${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/ungated/${key}"
ledger="$root/ledger.jsonl"
```

with:

```bash
key=$(hp_key "$repo")
legacy_key=$(hp_legacy_key "$repo")
root="$(hp_cache_root)/ungated/${key}"
ledger="$root/ledger.jsonl"
legacy_ledger=""
[ "$legacy_key" != "$key" ] && legacy_ledger="$(hp_cache_root)/ungated/${legacy_key}/ledger.jsonl"
```

Replace the `pending)` arm (`:184-199`) with:

```bash
  pending)
    files=""
    [ -f "$ledger" ] && files="$ledger"
    if [ -n "$legacy_ledger" ] && [ -f "$legacy_ledger" ]; then files="$files $legacy_ledger"; fi
    [ -n "$files" ] || { if [ "$count_only" -eq 1 ]; then echo '{"count":0,"skipped":0}'; else echo '[]'; fi; exit 0; }
    # shellcheck disable=SC2086
    node -e '
      const fs = require("fs");
      const mode = process.argv[1];
      let lines = [];
      for (const f of process.argv.slice(2)) lines = lines.concat(fs.readFileSync(f, "utf8").split("\n").filter(l => l.trim() !== ""));
      let skipped = 0; const events = [];
      for (const l of lines) { try { events.push(JSON.parse(l)); } catch (e) { skipped++; } }
      const sweptRefs = new Set(events.filter(e => e.event === "swept").map(e => e.ref));
      const pending = events.filter(e => e.event === "ungated" && e.sweepable === true && !sweptRefs.has(e.id));
      if (mode === "count") {
        process.stdout.write(JSON.stringify({ count: pending.length, skipped }) + "\n");
      } else {
        process.stdout.write(JSON.stringify(pending) + "\n");
      }
    ' "$([ "$count_only" -eq 1 ] && echo count || echo list)" $files
    ;;
```

- [ ] **Step 5: gate-telemetry**

After `set -uo pipefail` (`:26`) add the same `SCRIPT_DIR` and source lines as in Step 4. Replace `:45-57`:

```bash
base="${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers"
keys=()
if [ "$all" -eq 1 ]; then
  seen=""
  for d in "$base"/sdd/* "$base"/codex-review/* "$base"/ungated/*; do
    [ -d "$d" ] || continue
    k="$(basename "$d")"
    case " $seen " in *" $k "*) : ;; *) keys+=("$k"); seen="$seen $k" ;; esac
  done
else
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "gate-telemetry: not a git repository (use --all for the fleet view)" >&2; exit 2; }
  keys=("$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)")
fi
```

with:

```bash
base="$(hp_cache_root)"
keys=()
if [ "$all" -eq 1 ]; then
  seen=""
  # state/ holds a checkout per key plus its .backend, .lock, .fetched and
  # .tmp-* siblings; only hex names are keys.
  for d in "$base"/sdd/* "$base"/codex-review/* "$base"/ungated/* "$base"/state/*; do
    [ -d "$d" ] || continue
    k="$(basename "$d")"
    case "$k" in *[!0-9a-f]*) continue ;; esac
    case " $seen " in *" $k "*) : ;; *) keys+=("$k"); seen="$seen $k" ;; esac
  done
else
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "gate-telemetry: not a git repository (use --all for the fleet view)" >&2; exit 2; }
  keys=("$(hp_key "$repo")")
fi
```

In the node block, after the `if (fs.existsSync(sdd)) { ... }` block (`:131-141`) insert:

```javascript
    // The state checkout (this release's layout): one plan workspace per
    // directory under state/<key>/plans/, beside the plain cache it replaced.
    const st = path.join(base, "state", key, "plans");
    let statePlans = [];
    try { statePlans = fs.readdirSync(st); } catch (e) { statePlans = []; }
    for (const name of statePlans) {
      const p = path.join(st, name);
      try { if (fs.statSync(p).isDirectory()) workspaces.push(p); } catch (e) { /* skip */ }
    }
```

- [ ] **Step 6: Run the suites**

Run, one per `bash` call: the three suites from Step 2, plus `bash tests/hooks/test-ungated-notice.sh` and `bash tests/codex-review-gate/test-sweep-toolchain.sh` (both read the ledger through `ungated-ledger`).
Expected: every suite passes.

- [ ] **Step 7: Lint and commit**

Run: `bash scripts/lint-shell.sh skills/requesting-code-review/scripts/codex-review-dir skills/requesting-code-review/scripts/ungated-ledger skills/requesting-code-review/scripts/gate-telemetry`

```bash
git add skills/requesting-code-review/scripts/codex-review-dir skills/requesting-code-review/scripts/ungated-ledger skills/requesting-code-review/scripts/gate-telemetry tests/claude-code/test-codex-review-dir-path.sh tests/codex-review-gate/test-ungated-ledger.sh tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "feat(gate): gate dirs, the ungated ledger and telemetry key by the clone's common git directory"
```

---

### Task 11: The compaction notice finds the ledger in the state checkout

**Risk tier:** high — the hook's output is consumed by every resumed session, and it must stay fast, offline and heredoc-free.

**Files:**
- Modify: `hooks/session-start:156-186`
- Test: `tests/hooks/test-session-start.sh` (a helper and one case after the `compact-xrepo` case)

**Interfaces:**
- Consumes: `hp_key`, `hp_legacy_key`, `hp_cache_root`, sourced from `${PLUGIN_ROOT}/skills/subagent-driven-development/scripts/sdd-common.sh`.
- Produces: the same one-line notice, naming the newest of the ledgers found in `state/<key>/plans`, `sdd/<key>/plans` (pointers followed), and `sdd/<legacy key>/plans`.

**Mirror:** `tests/hooks/test-session-start.sh:521-531` (the `compact-fires` case: `seed_ledger`, `write_hook_input`, `assert_command_output` with the notice split in `NOTICE_HEAD`/`NOTICE_TAIL`).

- [ ] **Step 1: Write the failing test**

After `seed_ledger` (`:465-470`) add:

```bash
seed_state_ledger() { # <cache-root> <repo> <plan-slug> -> prints ledger path
    local dir
    dir="$1/hyperpowers/state/$(sdd_key "$2")/plans/$3"
    mkdir -p "$dir"
    printf '# SDD ledger — plan: %s\n' "$3" > "$dir/progress.md"
    printf '%s\n' "$dir/progress.md"
}
```

(`sdd_key` hashes the absolute git directory; for the main checkouts these cases use, that equals the common-directory key.) After the `compact-xrepo` case add:

```bash
# The state checkout (this release) is searched first; a newer legacy ledger
# still wins by mtime, so a host that has not imported yet is not misled.
st_repo="$(make_repo compact-state)"
st_home="$(make_home compact-state)"
st_cache="$TEST_ROOT/compact-state/cache"
st_legacy="$(seed_ledger "$st_cache" "$st_repo" "legacy-2222bbbb")"
touch -t 202601010000 "$st_legacy"
st_ledger="$(seed_state_ledger "$st_cache" "$st_repo" "state-3333cccc")"
st_stdin="$TEST_ROOT/compact-state/stdin.json"
write_hook_input "$st_stdin" compact
HOOK_STDIN="$st_stdin"
assert_command_output \
    "SessionStart names the ledger inside the state checkout" \
    "nested" \
    "${NOTICE_HEAD}${st_ledger}${NOTICE_TAIL}" \
    "" \
    "$st_home" \
    XDG_CACHE_HOME="$st_cache" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$st_repo" "$HOOK_UNDER_TEST"
touch "$st_legacy"
touch -t 202601010000 "$st_ledger"
assert_command_output \
    "SessionStart still names a newer legacy ledger" \
    "nested" \
    "${NOTICE_HEAD}${st_legacy}${NOTICE_TAIL}" \
    "" \
    "$st_home" \
    XDG_CACHE_HOME="$st_cache" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$st_repo" "$HOOK_UNDER_TEST"
before_dirs="$(find "$st_cache" | sort)"
HOOK_STDIN="$st_stdin" XDG_CACHE_HOME="$st_cache" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" HOME="$st_home" bash -c 'cd "$1" || exit 1; exec bash "$2"' _ "$st_repo" "$HOOK_UNDER_TEST" >/dev/null 2>&1 < "$st_stdin"
after_dirs="$(find "$st_cache" | sort)"
if [ "$before_dirs" = "$after_dirs" ]; then pass "the compaction lookup creates nothing"; else fail "the compaction lookup creates nothing"; fi
```

The suite defines `pass` and `fail` (`tests/hooks/test-session-start.sh:18-25`) and counts failures in `FAILURES`.

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/hooks/test-session-start.sh`
Expected: the state-checkout case fails (the hook only looks under `sdd/<key>`).

- [ ] **Step 3: Edit the hook**

Replace `:158-161`:

```bash
# session at the durable record instead. Read-only by contract: it re-derives
# the same cache key as scripts/sdd-dir but never calls it, because sdd-dir
# creates and touches directories. Fail-silent like the notices above it.
```

with:

```bash
# session at the durable record instead. Read-only by contract: it sources
# sdd-common.sh for the key but never calls sdd-dir, because sdd-dir creates
# directories. Fail-silent like the notices above it.
```

Replace `:164-167`:

```bash
      key="$(printf '%s' "$(git rev-parse --absolute-git-dir)" | git hash-object --stdin 2>/dev/null)"
      [ -n "$key" ] || exit 0
      plans="${XDG_CACHE_HOME:-${HOME:-}/.cache}/hyperpowers/sdd/${key}/plans"
      [ -d "$plans" ] || exit 0
```

with:

```bash
      common="${PLUGIN_ROOT}/skills/subagent-driven-development/scripts/sdd-common.sh"
      [ -f "$common" ] || exit 0
      # shellcheck source=../skills/subagent-driven-development/scripts/sdd-common.sh
      . "$common"
      key="$(hp_key . 2>/dev/null)"
      [ -n "$key" ] || exit 0
      legacy="$(hp_legacy_key . 2>/dev/null)"
      cache="$(hp_cache_root)"
```

Replace the loop `:177-185` (from `newest=""` through the closing `done`) with:

```bash
      # Three places a ledger can be: the state checkout (this release), the
      # plain cache under the same key (the plain backend, and pointers for
      # cross-repository plans), and the plain cache under the pre-6.17
      # per-worktree key. Newest wins across all three.
      newest=""
      for plans in "$cache/state/$key/plans" "$cache/sdd/$key/plans" "$cache/sdd/$legacy/plans"; do
        [ -d "$plans" ] || continue
        for ledger in "$plans"/*/progress.md; do
          [ -f "$ledger" ] || continue
          if [ -z "$newest" ] || [ "$ledger" -nt "$newest" ]; then
            newest="$ledger"
          fi
        done
      done
```

Keep the `shopt -s dotglob` line and its comment above the loop.

- [ ] **Step 4: Run the hook suites**

Run, one per `bash` call: `bash tests/hooks/test-session-start.sh`, `bash tests/hooks/test-no-heredocs-in-hooks.sh`, `bash tests/hooks/test-ungated-notice.sh`
Expected: all pass. The heredoc fence scans `hooks/` only, and `sdd-common.sh` has no heredoc anyway.

- [ ] **Step 5: Lint and commit**

Run: `bash scripts/lint-shell.sh hooks/session-start tests/hooks/test-session-start.sh`

```bash
git add hooks/session-start tests/hooks/test-session-start.sh
git commit -m "fix(hooks): the compaction notice looks in the state checkout first"
```

---

### Task 12: using-git-worktrees asks one three-way question and reports a mode

**Risk tier:** standard — behavior-shaping skill text plus a live test phase.

**Files:**
- Modify: `skills/using-git-worktrees/SKILL.md:33-45` (Step 0: the existing-worktree branch and the question), `:142-157` (Quick Reference), `:159-166` (Common Rationalizations)
- Modify: `tests/claude-code/test-worktree-native-preference.sh` (a `choice` phase)

**Interfaces:**
- Produces: the mode vocabulary `current-branch`, `new-branch`, `worktree`, reported by Step 0 on every path (the existing-worktree branch reports `worktree`), which Task 13's SDD text writes into the session line and Task 14's finishing text reads; the three-option question text the live `choice` phase greps for.

**Mirror:** the surrounding Step 0 prose at `skills/using-git-worktrees/SKILL.md:16-49`; `tests/claude-code/test-worktree-native-preference.sh:55-130` (`run_and_check`: the `RUNS` loop, `create_test_project`, `run_claude`, per-run PASS/FAIL lines).

- [ ] **Step 1: Step 0**

In the existing-worktree branch (`:33-39`), after `Skip to Step 2 (Project Setup). Do NOT create another worktree.` add the sentence `The mode is \`worktree\`; report it with the branch state below.`

Replace `:41-45` (from `Has the user already indicated their worktree preference` through `work in place and skip to Step 2.`) with:

```markdown
Has your human partner already declared where this work should happen (an
instruction file naming a worktree, a new branch, or the current branch)?
If so, honor it without asking. Otherwise ask one question with exactly
these three options, in this order (on Claude Code use the selection
widget; elsewhere ask in plain text):

1. Stay on the current branch (`<current branch>`)
2. Create a new branch in place (`git switch -c <name>`; the name from the
   plan slug unless they give one)
3. Create an isolated worktree

The answer is the mode (`current-branch`, `new-branch`, or `worktree`); the
skill that called you records it in its ledger. Choosing "stay on the
current branch" is explicit consent to work there, main or master included.
For option 1 skip to Step 2; for option 2 create the branch, then skip to
Step 2; for option 3 continue with Step 1. Report the mode in every case.
```

- [ ] **Step 2: Tables**

In the Quick Reference table (`:144-156`) insert after the `| Already in linked worktree | Skip creation (Step 0) |` row:

```markdown
| Declared preference in instructions | Honor it, no question (Step 0) |
| No declared preference | Ask the three-way question (Step 0) |
| Answer: current branch | Work in place, mode `current-branch` |
| Answer: new branch | `git switch -c <name>`, mode `new-branch` |
| Answer: worktree | Step 1, mode `worktree` |
```

Append to the Common Rationalizations table (`:161-166`):

```markdown
| "They said current branch, so the consent rule does not apply to me" | It applies; that answer is the consent. Record the mode and work there; never switch branches on your own. |
```

- [ ] **Step 3: The live `choice` phase**

In `tests/claude-code/test-worktree-native-preference.sh`, after the `SCENARIO=` definition (`:30-39`) add:

```bash
# Choice scenario: no declared preference, so Step 0 must offer all three,
# in order, and create nothing.
CHOICE_SCENARIO='You are about to implement a small feature in this repository (add a "version" field to package.json).
Use the using-git-worktrees skill to settle where the work happens. Do NOT implement anything and do NOT create a branch or worktree.
Report the exact question you would ask me with its numbered options, then stop.'

run_choice_check() {
    local i test_dir output scan branch_before branch_after p1 p2 p3 passes=0 fails=0
    for i in $(seq 1 "$RUNS"); do
        test_dir=$(create_test_project)
        cd "$test_dir" || return 1
        git init -q && git commit -q --allow-empty -m "init"
        branch_before=$(git branch --show-current)
        output=$(run_claude "$CHOICE_SCENARIO" 120)
        branch_after=$(git branch --show-current)
        scan="$test_dir/choice-output.txt"
        printf '%s\n' "$output" > "$scan"
        p1=$(grep -ni 'current branch' "$scan" | head -n 1 | cut -d: -f1)
        p2=$(grep -ni 'new branch' "$scan" | head -n 1 | cut -d: -f1)
        p3=$(grep -ni 'worktree' "$scan" | head -n 1 | cut -d: -f1)
        cd - >/dev/null || true
        if [ -n "$p1" ] && [ -n "$p2" ] && [ -n "$p3" ] && [ "$p1" -lt "$p2" ] && [ "$p2" -lt "$p3" ] \
           && [ "$branch_before" = "$branch_after" ] && [ "$(git -C "$test_dir" worktree list | wc -l | tr -d ' ')" = 1 ] && [ ! -d "$test_dir/.worktrees" ]; then
            echo "  [PASS] CHOICE run $i: the three options in order, nothing created"
            passes=$((passes + 1))
        else
            echo "  [FAIL] CHOICE run $i: options at lines '$p1' '$p2' '$p3', branch $branch_before -> $branch_after"
            tail -20 "$scan"
            fails=$((fails + 1))
        fi
        cleanup_test_project "$test_dir"
    done
    echo "CHOICE: $passes passed, $fails failed"
    [ "$fails" -eq 0 ]
}
```

In the phase dispatch at the bottom of the file (the block that selects on `$PHASE` for `red`, `green`, `pressure`, and `all`), add a `choice` branch that calls `run_choice_check`, and run it in `all` after the existing phases. Running it is Task 16's work.

- [ ] **Step 4: Lint the test file and commit**

Run: `bash scripts/lint-shell.sh tests/claude-code/test-worktree-native-preference.sh`

```bash
git add skills/using-git-worktrees/SKILL.md tests/claude-code/test-worktree-native-preference.sh
git commit -m "feat(worktrees): one three-way branch question, a mode on every path"
```

---

### Task 13: SDD skill text: setup order, session line, claims, hand-off, finish

**Risk tier:** standard — behavior-shaping skill surgery, pinned by the contract suite.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:117-165` (Setup), `:279-285` (Dispatch identity and append discipline), `:582-596` (Final Review), `:627-640` (Finish)
- Modify: `skills/subagent-driven-development/example-workflow.md:6-9`, `:14-15`, `:34`, `:75`
- Test: `tests/sdd/test-sdd-contract.sh` (needles above the closing lines)

**Interfaces:**
- Consumes: every `sdd-state` subcommand name, status, and exit code from Tasks 3 to 9, verbatim as listed in Global Constraints; the mode vocabulary of Task 12.
- Produces: the sentences the contract suite pins; the session line Task 14's finishing text reads.

**Mirror:** the surrounding bullets in `SKILL.md:129-165` for voice and bullet shape; `tests/sdd/test-sdd-contract.sh:54-63` for needle style.

- [ ] **Step 1: Write the failing needles**

Insert above the closing lines of `tests/sdd/test-sdd-contract.sh` (the `echo` and the `[ "$FAILURES" -eq 0 ] && { ... }` line at `:389-390`):

```bash
# SKILL.md — the state branch (portable dossiers, 2026-10-20)
assert_contains "$SDD" "run \`scripts/sdd-state sync PLAN_FILE\`" "setup syncs the state branch first"
assert_contains "$SDD" "hyperpowers/state/<key>/plans/<plan-slug>-<hash8>/" "workspace path names the state checkout"
assert_not_contains "$SDD" "hyperpowers/sdd/<per-repo-key>/plans/<plan-slug>-<hash8>/" "the plain-cache workspace path is gone"
assert_contains "$SDD" "# SDD ledger — plan: <repo-relative plan path>" "identity line is repo-relative"
assert_contains "$SDD" "Compare repo-relative paths" "resume compares repo-relative paths"
assert_contains "$SDD" "session <sid>: mode <current-branch|new-branch|worktree> on <branch> at <toplevel> started <UTC time>" "session line shape"
assert_contains "$SDD" "\$(date -u +%s)-\$RANDOM\$RANDOM" "session id fallback needs only bash"
assert_contains "$SDD" "then run \`scripts/sdd-state verify PLAN_FILE\`" "verify runs after the session line"
assert_contains "$SDD" "scripts/sdd-state claim PLAN_FILE N --session <sid>" "claim before dispatch"
assert_contains "$SDD" "take over (\`--takeover\`) only on their explicit yes" "takeover needs an explicit yes"
assert_contains "$SDD" "(session <sid>, worktree <path>, branch <name>)" "implementer identity carries session, worktree, branch"
assert_contains "$SDD" "never with the Edit tool" "append discipline when another session may be live"
assert_contains "$SDD" "scripts/sdd-state snapshot PLAN_FILE" "snapshot cadence named"
assert_contains "$SDD" "\`remote-finished plans=<ws,...>\` (exit 3)" "the remote-finished outcome stops and asks"
assert_contains "$SDD" "\`detached-head\`" "a detached checkout is handled at hand-off"
assert_contains "$SDD" "scripts/sdd-state handoff PLAN_FILE --push" "hand-off command named"
assert_contains "$SDD" "never on your own initiative" "the push is on request only"
assert_contains "$SDD" "scripts/sdd-state finish PLAN_FILE" "finish uses the helper"
assert_contains "$SDD" "git -C <checkout> push <remote> <branch>" "the push command is spelled out"
assert_not_contains "$SDD" "with \`rm -rf <workspace>\`" "finish no longer rm -rfs the workspace by hand"
assert_not_contains "$SDD" "The 14-day reclaim in \`scripts/sdd-dir\`" "no automatic reclaim is promised"
assert_contains "$SDD" "a session that finished its assigned tasks while other sessions' tasks are open reports that and stops" "completion barrier"
```

- [ ] **Step 2: Run the contract suite to verify it fails**

Run: `bash tests/sdd/test-sdd-contract.sh`
Expected: the new `assert_contains` lines fail; the two `assert_not_contains` on the old wording fail too.

- [ ] **Step 3: Edit the Setup section**

Replace `SKILL.md:119-123`:

```markdown
Ensure the work happens in an isolated workspace: use
hyperpowers:using-git-worktrees to create one or verify the existing one.
Never start implementation on a main/master branch without your human
partner's explicit consent.
```

with:

```markdown
Settle where the work happens first: use hyperpowers:using-git-worktrees,
which detects an existing worktree or asks your human partner to choose
between staying on the current branch, a new branch in place, and a
worktree, and reports the mode. Never start implementation on a main/master
branch unless your human partner chose "stay on the current branch" in that
question; that answer is the consent, and the dossier no longer depends on
the branch.
```

Replace the workspace bullet (`:129-137`, from `- Each plan owns a workspace:` through `never yours to read or write.`) with:

```markdown
- Each plan owns a workspace: at skill start, run `scripts/sdd-state sync PLAN_FILE`
  (it fetches the repository's state branch; outcomes below), then this
  skill's `scripts/sdd-dir PLAN_FILE` — it prints the plan's workspace
  inside the repository's state checkout under the user cache
  (`${XDG_CACHE_HOME:-~/.cache}/hyperpowers/state/<key>/plans/<plan-slug>-<hash8>/`,
  one checkout per clone, shared by every worktree of it), home to every
  artifact for THIS plan: ledger, briefs, reports, review packages, claims,
  tier-skip summary. The ledger, reports, notes and claims are committed to
  the orphan branch `hyperpowers/state` by `scripts/sdd-state snapshot PLAN_FILE`
  and travel between hosts with that branch; briefs and review packages are
  ignored there and regenerate. The cache is off any protected path, so
  writing there never triggers a permission prompt, and it is outside the
  working tree, so it can never be committed with the code. Another plan's
  directory is never yours to read or write. When `sdd-dir` reports
  `backend=plain` on stderr, the state branch is unavailable on this host
  and the dossier will not travel from it: tell your human partner once and
  continue.
- `sdd-state sync` outcomes: `up-to-date`, `fast-forwarded`, `merged`,
  `ahead`, `created`, `absent`, `no-remote`, `assumed-absent`, `plain`:
  continue. `offline` (exit 1): continue on the local checkout and, as soon
  as the ledger exists (the next bullet), append
  `state: sync offline at <time>` to it. `offline-no-state` (exit 1), or
  `needs-sync` from `sdd-dir`: stop; this host has no dossier and cannot
  learn whether the remote holds one. Ask your human partner to get online,
  or to confirm `scripts/sdd-state sync --assume-absent PLAN_FILE` when they
  know no remote dossier exists. `diverged` (exit 3): stop and present both
  tips and the printed `merge=` command as a question in the Deciding
  Together shape; never merge on your own. `busy` (exit 3): retry `sync`
  once after the other session's writes settle, then ask.
  `remote-finished plans=<ws,...>` (exit 3): another host finished this
  plan while this one wrote ledger lines that are not on the branch; stop,
  show your human partner the lines this host added (the ledger's tail
  beyond the last snapshot), and ask whether to snapshot them (then `sync`
  again, which reports `diverged` for their merge) or to discard them.
```

In the ledger-check bullet (`:138-155`) replace the two sentences

```markdown
  even when its first line records the path in another form (relative vs
  absolute, or through a symlink). Resolve that line and compare the file
  it points to, not the string.
```

with:

```markdown
  even when its first line records the path in another form. Compare
  repo-relative paths: reduce the plan you were handed to its path relative
  to the plan repository's toplevel; a line holding an absolute path matches
  when it lies inside this repository and reduces to the same relative path,
  or, when it names a path that does not exist on this host (a ledger
  written on another machine), when it ends with that relative path.
```

Replace the identity bullet (`:156-157`) with:

```markdown
- Create the ledger with its identity as the first line:
  `# SDD ledger — plan: <repo-relative plan path>` (never an absolute path:
  the ledger travels between hosts). Then append your session line:
  `session <sid>: mode <current-branch|new-branch|worktree> on <branch> at <toplevel> started <UTC time>`,
  where `<sid>` is `$CLAUDE_CODE_SESSION_ID` on Claude Code and, on a harness
  without one, a value you generate once as `$(date -u +%s)-$RANDOM$RANDOM`,
  and the mode is what using-git-worktrees reported. When your human partner
  assigned this session specific tasks, add `session <sid>: tasks <N,M,...>`.
  Then run `scripts/sdd-state verify PLAN_FILE`: `ok` continues;
  `code-missing` names commits the ledger relies on that this checkout
  lacks, so stop and ask your human partner to pull the named branch;
  `wrong-repo` names the repository the ledger was handed off from;
  `plan-stale` names the plan repository branch to pull.
```

Replace the scratch bullet (`:161-165`, from `- The workspace is scratch, not a deliverable.` through `so a resumed session always finds its ledger.`) with:

```markdown
- The workspace is scratch for the working tree and a record on the branch:
  the Finish step removes the plan's directory through
  `scripts/sdd-state finish PLAN_FILE`, and the branch history keeps it, so
  an evidence note can cite `git show <sha>:plans/<ws>/<file>`. Nothing
  inside the checkout is reclaimed automatically; `scripts/sdd-state prune`
  lists and removes idle plan directories only when asked. Snapshot the
  workspace (`scripts/sdd-state snapshot PLAN_FILE`) after the pre-flight
  scan table and after every `Task <N>: complete` line, so a hand-off or a
  crash loses at most the task in flight. When your human partner asks to
  hand the run to another host, run `scripts/sdd-state handoff PLAN_FILE --push`
  (the only time the state branch is pushed, never on your own initiative),
  report its status line, relay `plan-not-committed` with the commands to
  commit the plan, relay `code-dirty` with the listed paths as a question
  (only an explicit yes passes `--code-dirty-ok`), relay `detached-head`
  by asking for a branch name and creating it (`git switch -c <name>`)
  before retrying, and list the branches
  named in `code=` and, when present, `plan=` for your human partner to push
  here and pull there. You push none of them unless asked.
```

- [ ] **Step 4: Edit Dispatch, Final Review, and Finish**

Before the identity bullet at `:279` insert:

```markdown
- Claim the task first: `scripts/sdd-state claim PLAN_FILE N --session <sid>`.
  `claimed`, or `held` by your own session id (a resume after compaction):
  proceed. `held` by another session: do not take the next task on your own
  initiative; which tasks may run concurrently is not yet decided, and
  skipping ahead would decide it by accident. Tell your human partner who
  holds the task and since when, and ask whether to take it over; take over
  (`--takeover`) only on their explicit yes to that question, recording the
  takeover beside the original identity; if they say the other session is
  still working, wait for their instruction. The exception is a task list
  your human partner assigned this session (`session <sid>: tasks ...`):
  work only those tasks, and report a held task in your list the same way.
```

In the identity bullet (`:279-283`) change `` `Task <N>: implementer <agent-id-or-name>` `` to `` `Task <N>: implementer <agent-id-or-name> (session <sid>, worktree <path>, branch <name>)` ``.

After that bullet insert:

```markdown
- When another session may be live on this plan, append ledger lines with a
  quoted heredoc (`cat >> <workspace>/progress.md <<'EOF'`), never with the
  Edit tool, whose read-modify-write drops a line another session appended
  in between.
```

Leave `:285` (`Never dispatch multiple implementation subagents in parallel`) as it is.

In Final Review, after the first paragraph (`:584-596`, ending `triage which must be fixed before merge.`) add:

```markdown
Final review requires a `Task <N>: complete` line for every task of the
plan; a session that finished its assigned tasks while other sessions' tasks
are open reports that and stops rather than finishing the plan.
```

Replace the Finish steps (`:631-634`) with:

```markdown
1. **Read your session line** from the ledger (its `mode`): the next step
   removes the ledger from the working tree, and
   hyperpowers:finishing-a-development-branch takes the mode as its input.
2. **Finish the workspace** with `scripts/sdd-state finish PLAN_FILE`: it
   refuses with `open-claims` while any claimed task lacks a completion line
   (that is a plan not finished, not a reason for `--force`); otherwise it
   removes the plan's directory, commits the removal to the state branch,
   and prints `last=<sha>`, the commit that still holds the dossier, and
   `push=<remote>/<branch>`.
3. **Verify deletion** with `test ! -d "<workspace>"` to confirm it is gone.
   The push command is `git -C <checkout> push <remote> <branch>`, the
   checkout being the parent of the `plans/` directory `sdd-dir` printed;
   run it only if your human partner asks.
```

In the paragraph that follows (`:636-640`) replace `The 14-day reclaim in \`scripts/sdd-dir\` is only the backstop for sessions that never got here.` with `\`scripts/sdd-state prune\` is the only other remover, and it runs only when asked.`

- [ ] **Step 5: Update the example workflow**

In `example-workflow.md` replace lines 6-9 with:

```text
[Setup: branch question answered: worktree]
[Read plan file once: docs/hyperpowers/plans/feature-plan.md, and the spec its **Spec:** header names]
[Resolve workspace: scripts/sdd-state sync docs/hyperpowers/plans/feature-plan.md → status=absent; scripts/sdd-dir docs/hyperpowers/plans/feature-plan.md — no ledger inside, fresh start]
[Ledger: # SDD ledger — plan: docs/hyperpowers/plans/feature-plan.md]
[Ledger: session 1f3a9c: mode worktree on feature-plan at /repo/.worktrees/feature-plan started 2026-10-20T10:00:00Z]
[scripts/sdd-state verify docs/hyperpowers/plans/feature-plan.md → status=ok tasks=0]
```

Replace line 14 (`[Run task-brief for Task 1; dispatch implementer with brief + report paths + context]`) with two lines:

```text
[scripts/sdd-state claim docs/hyperpowers/plans/feature-plan.md 1 --session 1f3a9c → status=claimed task=1]
[Run task-brief for Task 1; dispatch implementer with brief + report paths + context]
```

Replace line 15 with `[Ledger: Task 1: implementer subagent-01f3 (session 1f3a9c, worktree /repo/.worktrees/feature-plan, branch feature-plan) — recorded for fix-round resumes]`.

After line 34 (`[Ledger: Task 1: complete (commits a1b2c3d..d4e5f6a, review clean)]`) add `[scripts/sdd-state snapshot docs/hyperpowers/plans/feature-plan.md → status=snapshot sha=9e8d7c6 files=2]`.

Replace line 75 (`[Delete this plan's workspace — the record now lives in git]`) with `[Read my session line (mode worktree); scripts/sdd-state finish docs/hyperpowers/plans/feature-plan.md → status=finished sha=0a1b2c3 last=… push=origin/hyperpowers/state; test ! -d the workspace — the record lives on hyperpowers/state and in the code history]`.

- [ ] **Step 6: Run the contract suite**

Run: `bash tests/sdd/test-sdd-contract.sh`
Expected: `STATUS: PASSED` (the suite collapses whitespace, so a needle wrapped across lines in the skill still matches).

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/example-workflow.md tests/sdd/test-sdd-contract.sh
git commit -m "feat(sdd): the skill syncs, verifies, claims, snapshots and hands off through the state branch"
```

---

### Task 14: finishing-a-development-branch takes the mode; optimizing-performance names the shared root

**Risk tier:** standard — skill text in two skills.

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md:30-46` (Step 2), `:55-78` (Step 4), `:205-212` (Quick Reference)
- Modify: `skills/optimizing-performance/SKILL.md:38`, `skills/optimizing-performance/perf-implementer-notes.md:12`

**Interfaces:**
- Consumes: the mode vocabulary of Task 12 and the session line of Task 13.

- [ ] **Step 1: finishing-a-development-branch**

After the code block in Step 2 (`:33-38`) add:

```markdown
The skill that called you may pass the session's mode (`current-branch`,
`new-branch`, or `worktree`), read from the SDD ledger's `session` line
before the workspace was finished. A passed mode decides the menu; the
table below applies only when no mode was passed. The repository's default
branch is `git symbolic-ref --short refs/remotes/origin/HEAD` with the
`origin/` prefix removed when that ref exists, otherwise the `init.defaultBranch`
config value, otherwise whichever of `main` and `master` exists:

```bash
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH=$(git config --get init.defaultBranch)
[ -n "$DEFAULT_BRANCH" ] || { git show-ref --verify -q refs/heads/main && DEFAULT_BRANCH=main; }
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH=master
```
```

(The inner fence is a code block inside the skill, as the Step 2 block is.)

Add a row to the Step 2 table (`:42-46`):

```markdown
| mode `current-branch` passed, current branch is `$DEFAULT_BRANCH` | Reduced 2 options (push, keep) | Nothing to clean up |
| mode `current-branch` passed, any other branch | Standard 3 options | Nothing to clean up |
```

In Step 4, before `**Detached HEAD — present exactly these 2 options:**` (`:69`) add:

```markdown
**Mode `current-branch` on the default branch — present exactly these 2 options:**

```
Implementation complete on <branch>. What would you like to do?

1. Push <branch>
2. Keep as-is (I'll handle it later)

Which option?
```
```

(The inner fence is the menu, as the other menus are.) In Step 5, before `### Option 1: Merge Locally` (`:88`), add:

```markdown
### Mode current-branch on the default branch

The two-option menu above maps to: option 1 runs `git push <remote> <branch>`
(no merge, no pull request) and reports the branch pushed; option 2 is
"Keep as-is" below. Options 1 and 2 of the standard menu do not apply.
```

Add to the Quick Reference table (`:207-212`):

```markdown
| Push current branch (mode current-branch) | - | yes | - | - |
```

- [ ] **Step 2: optimizing-performance**

Append to `skills/optimizing-performance/SKILL.md:38`, after `which would destroy the baseline the bounded re-profile round in step 5 reads:`, the sentence `That directory is keyed by the clone's common git directory, so every worktree of the clone shares it.` Append the same sentence to `perf-implementer-notes.md:12` after `The coordinator hands you this path.`

- [ ] **Step 3: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md skills/optimizing-performance/SKILL.md skills/optimizing-performance/perf-implementer-notes.md
git commit -m "feat(finishing): take the session mode; the perf root is shared across worktrees"
```

---

### Task 15: Documentation, the offline runner, lint, and the full offline set

**Risk tier:** standard — multi-file documentation and a committed test runner, plus the offline gate.

**Files:**
- Modify: `README.md:164`, `docs/testing.md:16-17,25-26,50-55`, `CHANGELOG.md` (new `## Unreleased` section after line 3)
- Create: `tests/run-offline.sh`

**Interfaces:**
- Consumes: everything shipped by Tasks 1 to 14.
- Produces: `bash tests/run-offline.sh` (exit 0 when every suite of the documented offline set passes; prints `FAILED: <suite>` lines and `offline set: <n> failed`); the release note the human partner turns into the next version's entry.

- [ ] **Step 1: README and testing guide**

Replace `README.md:164` with:

```markdown
2. **using-git-worktrees** - Activates after design approval. Asks where the work happens (current branch, new branch in place, or isolated worktree), runs project setup, verifies clean test baseline.
```

In `docs/testing.md` replace `:16-17` (`Most suites are standalone bash scripts; two directories are not. There is no aggregate runner and no CI; run the suites that cover what you changed, one script per \`bash\` invocation.`) with:

```markdown
Most suites are standalone bash scripts; two directories are not. There is no
CI. `bash tests/run-offline.sh` runs the documented offline set, one script per
`bash` invocation; while working, run the suites that cover what you changed.
```

Replace the `tests/sdd/` row (`:25`) with:

```markdown
| `tests/sdd/` | the subagent-driven-development contract, the state library (`sdd-common.sh`), and the state branch lifecycle (`sdd-dir`, `sdd-state`) | `bash tests/sdd/test-sdd-contract.sh`, `bash tests/sdd/test-sdd-common.sh`, `bash tests/sdd/test-sdd-state.sh` |
```

In the `tests/claude-code/` row (`:26`) change `offline: SDD scratch-dir derivation,` to `offline: SDD workspace derivation (state checkout, plain fallback, pointers),` and `plus \`test-worktree-native-preference.sh\`` to `plus \`test-worktree-native-preference.sh\` (phases \`green\`, \`pressure\`, \`choice\`)`. In the offline-set paragraph (`:50-55`) append the sentence `\`tests/run-offline.sh\` runs exactly that set.`

- [ ] **Step 2: CHANGELOG**

Insert after `CHANGELOG.md:3` (the paragraph ending `[RELEASE-NOTES.md](RELEASE-NOTES.md).`), before `## 6.16.1`:

```markdown
## Unreleased

The SDD dossier follows the work between hosts.

- **A plan's workspace lives on a state branch.** `sdd-dir` prints a workspace inside `~/.cache/hyperpowers/state/<key>/`, a checkout of the orphan branch `hyperpowers/state` kept once per clone and keyed by the clone's common git directory, so every worktree of a clone shares one live ledger. The ledger, reports, notes and claims are committed there and travel with the branch; briefs and review packages stay local and regenerate. The 6.16.0 pointer symlinks remain only in the plain cache, for cross-repository plans.
- **`sdd-state` carries the lifecycle.** `sync` fetches and reconciles (a fast-forward, a conflict-free merge with the ledger under the union driver, or `diverged` for the human partner to merge), never overwriting a live ledger; `verify` checks both ends of every completion range, the code repository's identity, and the plan version the ledger relies on; `snapshot` commits through a private index, with no hooks and no signing; `handoff --push` publishes after the optional scan named in `hyperpowers.prePushScan`, over every commit the push would publish; `finish` keeps the dossier in history and refuses open claims; `prune` is the only remover; `claim` is an atomic per-task claim for parallel sessions.
- **One branch question.** using-git-worktrees asks whether to stay on the current branch, create one in place, or use a worktree. That answer is the consent SDD used to require for main, and it is recorded per session in the ledger; finishing-a-development-branch takes it as its input.
- **Upgrade notes.** Both hosts need this version: an older plugin writes to the legacy cache and splits the ledger. A legacy workspace is imported on the first `sdd-dir` call and left as a symlink. Baselines that optimizing-performance stored under a linked worktree's old key are not moved. Codex gate directories and the ungated ledger are keyed by the common git directory from now on; `ungated-ledger pending` still reads the old key for one release. `sdd-dir` now refuses a plan file that does not exist. The sandbox fallback (`backend=plain`) keeps a run working where `git worktree add` is refused, without portability.
```

- [ ] **Step 3: The offline runner**

Create `tests/run-offline.sh`:

```bash
#!/usr/bin/env bash
# The documented offline set (docs/testing.md, "Plugin tests"), one suite per
# bash call. Prints FAILED lines and a count; exit 0 only when everything
# passed. Logs go to $OUT (default: a fresh temporary directory). Never runs
# the live suites: those spawn the real claude CLI.
set -u
cd "$(dirname "$0")/.." || exit 2
OUT=${OUT:-$(mktemp -d "${TMPDIR:-/tmp}/offline-logs.XXXXXX")}
fails=0
run() {
  local name
  name=$(printf '%s' "$1" | tr '/' '_')
  if ! bash "$1" > "$OUT/$name.log" 2>&1; then echo "FAILED: $1 (log: $OUT/$name.log)"; fails=$((fails + 1)); fi
}
for t in tests/hooks/test-*.sh tests/codex-review-gate/test-*.sh tests/sdd/test-*.sh tests/packaging/test-*.sh tests/writing-skills/test-*.sh tests/systematic-debugging/test-*.sh tests/shell-lint/test-*.sh tests/opencode/test-*.sh tests/kimi/test-*.sh tests/antigravity/test-*.sh; do
  case "$t" in tests/opencode/test-tools.sh|tests/opencode/test-priority.sh) continue ;; esac
  [ -f "$t" ] && run "$t"
done
for t in tests/claude-code/test-sdd-dir-path.sh tests/claude-code/test-codex-review-dir-path.sh tests/claude-code/test-delivery-resolution.sh tests/claude-code/test-worktree-path-policy.sh; do run "$t"; done
( cd tests/brainstorm-server && npm test > "$OUT/brainstorm-npm.log" 2>&1 ) || { echo "FAILED: tests/brainstorm-server npm test (log: $OUT/brainstorm-npm.log)"; fails=$((fails + 1)); }
run tests/brainstorm-server/windows-lifecycle.test.sh
node tests/pi/test-pi-extension.mjs > "$OUT/pi.log" 2>&1 || { echo "FAILED: tests/pi/test-pi-extension.mjs (log: $OUT/pi.log)"; fails=$((fails + 1)); }
echo "offline set: $fails failed (logs: $OUT)"
[ "$fails" -eq 0 ]
```

- [ ] **Step 4: Lint every shell file the branch touched, then run the offline set**

Run:

```bash
git diff --name-only "$(git merge-base main HEAD)" HEAD -- 'skills/*/scripts/*' 'hooks/*' 'tests/*.sh' 'tests/*/*.sh' > "$TMPDIR/lint-list.txt"
printf '%s\n' tests/run-offline.sh >> "$TMPDIR/lint-list.txt"
bash scripts/lint-shell.sh $(cat "$TMPDIR/lint-list.txt")
```

Expected: no findings. Then `bash tests/run-offline.sh`.
Expected: `offline set: 0 failed`. Record the line and the commit it ran at in the ledger. A failure in a suite this plan did not touch is reported, not fixed here, unless the key change caused it (then it belongs to this plan).

- [ ] **Step 5: Commit**

```bash
chmod +x tests/run-offline.sh
git add README.md docs/testing.md CHANGELOG.md tests/run-offline.sh
git commit -m "docs(hyperpowers): the state branch in the testing guide, README and release notes; an offline runner"
```

---

### Task 16: Live checks: two-clone rehearsal, the quorum scenario, the branch question

**Risk tier:** standard — live sessions whose transcripts become the evidence; nothing in `skills/` changes.

**Files:**
- Create (hyperpowers-evals, branch `portable-sdd-dossiers`): `evals/evidence/2026-10-20-portable-sdd-dossiers/README.md`, `rehearsal/run-rehearsal.sh`, `rehearsal/check-rehearsal.sh`, the archived transcripts and outputs, `scenario-runs/` (the stripped quorum run), `choice/run.txt`
- Create (hyperpowers): `docs/hyperpowers/2026-10-20-portable-sdd-dossiers-eval-evidence.md`

**Interfaces:**
- Consumes: the plugin worktree as `--plugin-dir`; `sdd-state handoff` from Task 9; the `choice` phase from Task 12.
- Produces: the evidence note Task 17 and the release decision cite.

**Mirror:** `evals/evidence/2026-10-03-communication-skill/trigger/run-trigger.sh:16-28` (headless session recipe); `docs/hyperpowers/2026-10-03-review-calibration-and-sentinel-scope-eval-evidence.md:1-20` (note header); `evals/evidence/README.md:1-45` (archive rules).

- [ ] **Step 1: The evals branch and the evidence directory**

```bash
git -C /Users/johnss51/Development/agents/hyperpowers/evals worktree add -b portable-sdd-dossiers /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/portable-sdd-dossiers main
mkdir -p /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/portable-sdd-dossiers/evidence/2026-10-20-portable-sdd-dossiers/rehearsal
```

(About 8 minutes on this repository.) Write `evidence/2026-10-20-portable-sdd-dossiers/README.md`:

```markdown
# 2026-10-20 portable SDD dossiers

Evidence for `docs/hyperpowers/plans/2026-10-20-portable-sdd-dossiers.md` (hyperpowers).
`rehearsal/`: clones of one bare repository standing in for hosts, driven by
`run-rehearsal.sh` against the plugin worktree; `check-rehearsal.sh` reads the outcomes.
Pass 0 runs in acceptEdits mode to observe the permission footing of writes under the
state checkout; passes 1 to 3 run with permissions skipped. `scenario-runs/`: the
`sdd-plan-scoped-scratch` quorum run on the new layout, stripped per `evidence/README.md`.
`choice/`: the live `test-worktree-native-preference.sh choice 3` output.
```

- [ ] **Step 2: The rehearsal script**

Write `rehearsal/run-rehearsal.sh`:

```bash
#!/usr/bin/env bash
# run-rehearsal.sh PLUGIN_DIR
# Pass 0: clone P runs Task 1 in acceptEdits mode with Edit/Write not
#         pre-allowed, so the transcript shows how writes under the state
#         checkout are treated (the spec's permission assumption).
# Pass 1: clone A runs Task 1 (permissions skipped), hands off and pushes.
# Pass 2: clone B pulls and resumes; must not re-dispatch Task 1.
# Pass 3: clone C never pulls Task 1's commit; must stop on code-missing.
# Everything lives under ROOT with its own cache root, so no state checkout
# touches the real ~/.cache.
set -u
PLUGIN=${1:?plugin dir}
ROOT=/Users/johnss51/.cache/hyperpowers/portable-sdd-rehearsal
STATE="$PLUGIN/skills/subagent-driven-development/scripts/sdd-state"
rm -rf "$ROOT"; mkdir -p "$ROOT/cache" "$ROOT/config" "$ROOT/hostP" "$ROOT/hostA" "$ROOT/hostB" "$ROOT/hostC"
export XDG_CACHE_HOME="$ROOT/cache"

write_plan() { # <repo>
  mkdir -p "$1/docs/hyperpowers/plans" "$1/src"
  printf '# fixture\n' > "$1/README.md"
  sed 's/^@@@/###/' > "$1/docs/hyperpowers/plans/rehearsal.md" <<'PLAN'
# Rehearsal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development to implement this plan task-by-task.

**Spec:** none

**Goal:** Two trivial files, one per task.

## Global Constraints

- Plain shell only; no dependencies; one commit per task.

@@@ Task 1: First file

**Risk tier:** low — one file whose content is given here.

**Files:**
- Create: `src/one.txt`

- [ ] **Step 1: Write the file**

Run: `printf 'one\n' > src/one.txt`

- [ ] **Step 2: Verify**

Run: `test "$(cat src/one.txt)" = one`
Expected: exit 0

- [ ] **Step 3: Commit**

Run: `git add src/one.txt && git commit -m "feat: first file"`

@@@ Task 2: Second file

**Risk tier:** low — one file whose content is given here.

**Files:**
- Create: `src/two.txt`

- [ ] **Step 1: Write the file**

Run: `printf 'two\n' > src/two.txt`

- [ ] **Step 2: Verify**

Run: `test "$(cat src/two.txt)" = two`
Expected: exit 0

- [ ] **Step 3: Commit**

Run: `git add src/two.txt && git commit -m "feat: second file"`
PLAN
}
new_origin_and_clone() { # <origin> <clone>
  git init -q --bare -b main "$1"
  git clone -q "$1" "$2"
  git -C "$2" config user.name rehearsal; git -C "$2" config user.email rehearsal@example.com
  write_plan "$2"
  git -C "$2" add -A; git -C "$2" commit -qm "plan"; git -C "$2" push -q origin main
}
run_claude() { # <dir> <name> <mode: skip|accept> <prompt>
  local perm
  if [ "$3" = accept ]; then perm="--permission-mode acceptEdits --allowedTools Bash,Agent,Read,Grep,Glob,Skill,TodoWrite,TaskCreate,TaskUpdate,TaskList,TaskGet"; else perm="--dangerously-skip-permissions"; fi
  # shellcheck disable=SC2086
  ( cd "$1" && env -u CLAUDECODE -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_SESSION_ID \
      -u CLAUDE_CODE_ENABLE_TODO_TOOLS -u CLAUDE_CODE_MESSAGING_SOCKET -u CLAUDE_CODE_MESSAGING_TOKEN \
      -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_SESSION_ATTENDED -u CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS \
      CLAUDE_CONFIG_DIR="$ROOT/config" XDG_CACHE_HOME="$ROOT/cache" \
      timeout 1800 claude -p "$4" --plugin-dir "$PLUGIN" --output-format stream-json --verbose \
        $perm --max-budget-usd 10 --model claude-opus-5-5 < /dev/null \
        > "$ROOT/$2.jsonl" 2> "$ROOT/$2.err"
    echo "$2 exit=$?" >> "$ROOT/status.txt" )
}
TASK1_PROMPT="Execute docs/hyperpowers/plans/rehearsal.md with hyperpowers:subagent-driven-development. Work directly on the current branch; that is my answer to the branch question. Complete Task 1 only: once its ledger completion line is written and snapshotted, stop and do not start Task 2."

# Pass 0: the permission probe, on its own origin.
new_origin_and_clone "$ROOT/origin-p.git" "$ROOT/hostP/repo"
run_claude "$ROOT/hostP/repo" hostP-accept accept "$TASK1_PROMPT"

# Passes 1 to 3 share one origin.
new_origin_and_clone "$ROOT/origin.git" "$ROOT/hostA/repo"
A="$ROOT/hostA/repo"; B="$ROOT/hostB/repo"; C="$ROOT/hostC/repo"
run_claude "$A" hostA-task1 skip "$TASK1_PROMPT"
( cd "$A" && bash "$STATE" handoff docs/hyperpowers/plans/rehearsal.md --push ) > "$ROOT/handoff.txt" 2>&1
git -C "$A" push -q origin main

git clone -q "$ROOT/origin.git" "$B"
git -C "$B" config user.name rehearsal; git -C "$B" config user.email rehearsal@example.com
run_claude "$B" hostB-resume skip "Resume docs/hyperpowers/plans/rehearsal.md with hyperpowers:subagent-driven-development. Work directly on the current branch; that is my answer to the branch question. Finish the plan."

git clone -q "$ROOT/origin.git" "$C"
git -C "$C" config user.name rehearsal; git -C "$C" config user.email rehearsal@example.com
git -C "$C" reset -q --hard "$(git -C "$C" rev-list --max-parents=0 HEAD | head -n 1)"
run_claude "$C" hostC-stale skip "Resume docs/hyperpowers/plans/rehearsal.md with hyperpowers:subagent-driven-development. Work directly on the current branch; that is my answer to the branch question."
echo "done" >> "$ROOT/status.txt"
```

The nested plan's headings are written as `@@@ Task N` and turned into `### Task N` by the `sed`, so this plan's own `task-brief` never sees them as tasks. Clone C's reset goes back to the root commit (README and plan), so Task 1's commit is absent there.

Write `rehearsal/check-rehearsal.sh`:

```bash
#!/usr/bin/env bash
# check-rehearsal.sh PLUGIN_DIR: read the rehearsal outcomes; one line per check.
set -u
PLUGIN=${1:?plugin dir}
ROOT=/Users/johnss51/.cache/hyperpowers/portable-sdd-rehearsal
A="$ROOT/hostA/repo"; B="$ROOT/hostB/repo"
export XDG_CACHE_HOME="$ROOT/cache"
# Host P's own state key, so the permission probe cannot pass on another clone's ledger.
pkey=$( . "$PLUGIN/skills/subagent-driven-development/scripts/sdd-common.sh"; hp_key "$ROOT/hostP/repo" )
pledger=$(ls "$ROOT/cache/hyperpowers/state/$pkey/plans/"rehearsal-*/progress.md 2>/dev/null | head -n 1)
ok() { echo "  [PASS] $1"; }
bad() { echo "  [FAIL] $1"; fails=$((fails + 1)); }
fails=0
git -C "$A" log --oneline > "$ROOT/a.log"
grep -q 'first file' "$ROOT/a.log" && ok "A committed Task 1" || bad "A committed Task 1"
head -n 1 "$ROOT/handoff.txt" > "$ROOT/handoff-first.txt"
grep -q '^status=pushed' "$ROOT/handoff-first.txt" && ok "handoff pushed the state branch" || bad "handoff pushed the state branch ($(cat "$ROOT/handoff-first.txt"))"
grep -q 'sdd-state sync' "$ROOT/hostB-resume.jsonl" && ok "B ran sync" || bad "B ran sync"
grep -q 'sdd-state verify' "$ROOT/hostB-resume.jsonl" && ok "B ran verify" || bad "B ran verify"
grep -q 'task-1-brief' "$ROOT/hostB-resume.jsonl" && bad "B did not re-dispatch Task 1" || ok "B did not re-dispatch Task 1"
git -C "$B" log --oneline > "$ROOT/b.log"
grep -q 'second file' "$ROOT/b.log" && ok "B committed Task 2" || bad "B committed Task 2"
grep -q 'status=code-missing' "$ROOT/hostC-stale.jsonl" && ok "C saw code-missing" || bad "C saw code-missing"
grep -q 'task-2-brief' "$ROOT/hostC-stale.jsonl" && bad "C did not dispatch on a stale checkout" || ok "C did not dispatch on a stale checkout"
# Permission probe: how many tool denials name the state checkout versus the plain cache.
state_denied=$(grep -c 'permission' "$ROOT/hostP-accept.jsonl" 2>/dev/null | tr -d ' ')
grep -o '"[^"]*hyperpowers/state/[^"]*"' "$ROOT/hostP-accept.jsonl" | sort -u > "$ROOT/hostP-state-paths.txt"
echo "  [INFO] pass 0: $state_denied lines mention permission; state-checkout paths touched: $(wc -l < "$ROOT/hostP-state-paths.txt" | tr -d ' ')"
grep -q 'hostP-accept exit=0' "$ROOT/status.txt" && ok "pass 0's session ended normally" || bad "pass 0's session ended normally"
[ -n "$pledger" ] && grep -q 'Task 1: complete' "$pledger" && ok "pass 0 wrote Task 1's completion line in host P's own ledger in acceptEdits mode" || bad "pass 0 wrote Task 1's completion line in host P's own ledger in acceptEdits mode (ledger: ${pledger:-none})"
echo "rehearsal: $fails failed"
[ "$fails" -eq 0 ]
```

- [ ] **Step 3: Run the rehearsal**

Run: `bash <evidence>/rehearsal/run-rehearsal.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/portable-sdd-dossiers` then `bash <evidence>/rehearsal/check-rehearsal.sh /Users/johnss51/Development/agents/hyperpowers/.worktrees/portable-sdd-dossiers`
Expected: `rehearsal: 0 failed`. Try once inside the sandbox; on "Operation not permitted" from `git init` or a worktree add, rerun with the sandbox disabled. Four Opus sessions take roughly 15 to 35 minutes together. Read pass 0's transcript for denied Edit or Write calls under `hyperpowers/state/`: if the ledger still reached its completion line (through Bash appends), the footing matches today's cache (Edit and Write under the cache need the user's own allow rules either way) and the assumption holds; record the denial count in the evidence note. Copy `$ROOT/*.jsonl`, `$ROOT/*.err`, `status.txt`, `handoff.txt`, `a.log`, `b.log`, `hostP-state-paths.txt` into `<evidence>/rehearsal/` (copy, never move). A failing check is a finding about the skill text or the helper, surfaced to the human partner with the transcript lines, not a reason to loosen the check.

- [ ] **Step 4: The quorum scenario**

Run, from `evals/.worktrees/portable-sdd-dossiers`:

```bash
SUPERPOWERS_ROOT=/Users/johnss51/Development/agents/hyperpowers/.worktrees/portable-sdd-dossiers bun run quorum run scenarios/sdd-plan-scoped-scratch --coding-agent claude-auto
```

Expected: `final: pass` in `bun run quorum show`. The scenario's checks find ledgers with `find ../home/.cache -name progress.md`, which reaches the new `state/<key>/plans/` layout, and its setup seeds plan A through the candidate `sdd-dir` with `HOME` pinned, so plan A's state branch and checkout are created inside the run's home. Then `scripts/strip-runs` the run and copy its record and workspace into `<evidence>/scenario-runs/` per `evals/evidence/README.md`.

- [ ] **Step 5: The branch question, live**

Run: `bash tests/claude-code/test-worktree-native-preference.sh choice 3` from the plugin worktree.
Expected: three `[PASS] CHOICE run` lines and `CHOICE: 3 passed, 0 failed`. Save the output to `<evidence>/choice/run.txt`.

- [ ] **Step 6: The evidence note and the commits**

Write `docs/hyperpowers/2026-10-20-portable-sdd-dossiers-eval-evidence.md` in the hyperpowers worktree:

```markdown
# Portable SDD Dossiers — Eval Evidence

Date: 2026-10-20 (runs on the dates recorded in the artifacts)
Skills changed: using-git-worktrees, subagent-driven-development,
finishing-a-development-branch, optimizing-performance (one sentence).
Scripts added: `sdd-common.sh`, `sdd-state`, `tests/run-offline.sh`; rewritten: `sdd-dir`.

Spec: `docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md`.
Plan: `docs/hyperpowers/plans/2026-10-20-portable-sdd-dossiers.md`.

**Where the run artifacts live.** Every path below resolves under the evals
repository's committed evidence tree,
`evals/evidence/2026-10-20-portable-sdd-dossiers/` (hyperpowers-evals commit
`<sha>`). Nothing in this note cites the SDD workspace.

## Two-clone rehearsal (`rehearsal/`)

<one paragraph per pass: pass 0's permission footing (denials under the
state checkout, whether the completion line still landed); what host A did,
the handoff status line; what B did on arrival (sync and verify outcomes, no
re-dispatch of Task 1, Task 2 committed); what C did on the stale checkout
(code-missing, no dispatch); then the check-rehearsal.sh summary line,
verbatim>

## Quorum scenario `sdd-plan-scoped-scratch` (`scenario-runs/`)

<run id, verdict, and the two layout facts the run shows: plan A's ledger
found under state/<key>/plans/, plan B's workspace absent after finish>

## The branch question (`choice/`)

<the CHOICE lines, verbatim>

## Offline suites

<the `offline set: 0 failed` line from Task 15, with the commit it ran at>
```

Fill every angle-bracketed slot from the artifacts; a slot with no artifact is written as `not run: <reason>`, never left as a placeholder. Then:

```bash
# evals worktree
bash scripts/lint-shell.sh evidence/2026-10-20-portable-sdd-dossiers/rehearsal/run-rehearsal.sh evidence/2026-10-20-portable-sdd-dossiers/rehearsal/check-rehearsal.sh 2>/dev/null || shellcheck evidence/2026-10-20-portable-sdd-dossiers/rehearsal/*.sh
git -C /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/portable-sdd-dossiers add evidence/2026-10-20-portable-sdd-dossiers
git -C /Users/johnss51/Development/agents/hyperpowers/evals/.worktrees/portable-sdd-dossiers commit -m "test(evidence): portable SDD dossiers rehearsal, scenario run and branch-question output"
# hyperpowers worktree
git add docs/hyperpowers/2026-10-20-portable-sdd-dossiers-eval-evidence.md
git commit -m "docs(hyperpowers): portable SDD dossiers eval evidence"
```

(The evals repository has no `lint-shell.sh`; run `shellcheck` on the two scripts directly.) Leak scan before each commit; the transcripts must not carry the proxy host (they were produced with the host's environment stripped, but check).

---

### Task 17: Release readiness: the spec's assumptions, validated with the human partner

**Risk tier:** standard — no code; host checks, a dry-run push, and the bump and install commands prepared for the human partner.

**Files:**
- Modify: `docs/hyperpowers/2026-10-20-portable-sdd-dossiers-eval-evidence.md` (a "Release readiness" section)

**Interfaces:**
- Consumes: the evidence note of Task 16; the spec's Assumptions section (`docs/hyperpowers/specs/2026-10-20-portable-sdd-dossiers-design.md`, "Assumptions").
- Produces: every assumption resolved as validated, failed, or waived by the human partner, and the exact release commands, run only on their go.

- [ ] **Step 1: Checks the human partner runs on bergen**

Ask the human partner to run these on bergen, from a checkout of the `portable-sdd-dossiers` branch, inside a Claude Code session so the Bash tool's environment is the one that matters, and to paste the output:

```bash
git --version
printf 'session=%s\n' "${CLAUDE_CODE_SESSION_ID:-unset}"
bash tests/sdd/test-sdd-common.sh | tail -n 1
bash tests/sdd/test-sdd-state.sh | tail -n 1
```

`Unknown: bergen's git version, session id presence, and the two suites on ext4, validate via the output above, before Step 4.` Record each answer in the evidence note's "Release readiness" section. A failing suite on bergen is a plan conflict surfaced to the human partner, not a value to guess.

- [ ] **Step 2: Remote acceptance of the branch name**

With the human partner's go (it is a dry run; nothing is pushed), run from the hyperpowers worktree:

```bash
git push --dry-run origin HEAD:refs/heads/hyperpowers/state
```

and the same in one work repository of their choice. Expected: the remote reports the ref it would create and no policy rejection. A rejection means that repository sets `hyperpowers.stateBranch` to a name its remote accepts, and the release note says so.

- [ ] **Step 3: The session id across compaction**

From this session's own transcript, or a Claude Code session the human partner compacts on purpose, confirm `CLAUDE_CODE_SESSION_ID` is the same value in a Bash call before and after compaction. Record `observed stable`, `observed changed`, or `not observed: <reason>`; if it changes, the SDD text's fallback (treat every claim as foreign after compaction) applies and the evidence note says so.

- [ ] **Step 4: Prepare the release for the human partner**

Add to the evidence note a "Release readiness" section with the four results above, the permission footing from Task 16's pass 0, and the exact commands, which the human partner runs when they have sequenced this release against the `sdd-turn-liveness` plan:

```bash
# in the hyperpowers main checkout, after the branch is merged and the CHANGELOG heading is set to the version and date
bash scripts/bump-version.sh <version>
git commit -am "chore(release): <version>"
git tag v<version>
# install on each host: check out the tag in the plugin-install worktree, then
claude plugin update hyperpowers
```

The version number is the human partner's: `6.17.0` if this plan ships first, the next minor after the turn-liveness release otherwise. Commit the note:

```bash
git add docs/hyperpowers/2026-10-20-portable-sdd-dossiers-eval-evidence.md
git commit -m "docs(hyperpowers): release readiness for the portable SDD dossiers"
```

---
