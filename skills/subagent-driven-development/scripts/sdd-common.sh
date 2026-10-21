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
  d=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || d=""
  # Git 2.23-2.30 does not know --path-format: it echoes the flag as a second
  # line and exits 0, so only a single line naming a directory is trusted.
  case "$d" in *"
"*) d="" ;; esac
  if [ -z "$d" ] || [ ! -d "$d" ]; then
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

# Each fails outside a repository rather than naming an unkeyed shared path.
hp_checkout_path() { local k; k=$(hp_key "$1") || return 1; printf '%s/state/%s\n' "$(hp_cache_root)" "$k"; }
hp_plain_root() { local k; k=$(hp_key "$1") || return 1; printf '%s/sdd/%s\n' "$(hp_cache_root)" "$k"; }
hp_stamp_path() { local c; c=$(hp_checkout_path "$1") || return 1; printf '%s.fetched\n' "$c"; }

# The backend file: first word branch|plain, the rest free-form key=value.
hp_backend() {
  local c f
  c=$(hp_checkout_path "$1") || return 1
  f="$c.backend"
  if [ -f "$f" ]; then head -n 1 "$f" | cut -d' ' -f1; else printf 'none\n'; fi
}
hp_write_backend() { # <repo-dir> <line>
  local c f tmp
  c=$(hp_checkout_path "$1") || return 1
  f="$c.backend"
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
  # The plan must be a regular file git can carry, not a link out of the repo.
  [ -L "$1" ] && return 1
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
# One lock per repository: `mkdir <checkout>.lock`, which is atomic; the
# holder's identity sits in `<lock>/owner`. Acquisition retries every 200 ms
# for 30 s, then gives up with the owner shown (exit 2). A lock older than
# ten minutes whose pid is dead, or cannot be checked, is taken over in
# place: the contender claims the generation it validated by creating
# `<lock>/taken-<generation>` (atomic, exactly one winner per generation),
# writes its identity there, and only then renames a copy over `owner`. The
# lock directory is never removed or renamed during a takeover, so a
# contender that paused after validating a stale lock cannot destroy the
# hold a faster contender established meanwhile: its claim names a
# generation that is already taken. A claimant that dies before the rename
# leaves its marker as the newest link of the takeover chain; readers follow
# the chain, so that dead claimant is the effective owner and the next
# contender takes over its generation. The guard directory
# `<lock>.takeover` serializes takeover attempts and is reclaimed when a
# contender died inside it; exclusion does not depend on it. Readers never
# take the lock.
HP_LOCK_DIR=""
hp_write_owner() { # <file>
  printf 'session=%s\npid=%s\nhost=%s\ntime=%s\n' "$(hp_session_id)" "$$" "$(hostname)" "$(hp_utc_now)" > "$1"
}
hp_lock_generation() { # <owner-text>
  printf '%s\n' "$1" | cksum | cut -d' ' -f1
}
# Print the content of the effective owner: the newest link of the chain of
# claimed generations. A missing file reads as empty text.
hp_lock_owner_text() { # <lock-dir>
  local text g n=0
  text=$(cat "$1/owner" 2>/dev/null)
  while [ "$n" -lt 64 ]; do
    g=$(hp_lock_generation "$text")
    [ -d "$1/taken-$g" ] || break
    text=$(cat "$1/taken-$g/owner" 2>/dev/null)
    n=$((n + 1))
  done
  printf '%s\n' "$text"
}
# Stale: older than ten minutes and the effective owner's pid is dead or
# unknown. The optional second argument is owner text already read, so the
# caller validates and claims the same bytes.
hp_lock_stale() { # <lock-dir> [owner-text]
  local pid text
  [ -n "$(find "$1" -maxdepth 0 -mmin +10 2>/dev/null)" ] || return 1
  text=${2-$(hp_lock_owner_text "$1")}
  pid=$(printf '%s\n' "$text" | sed -n 's/^pid=//p')
  [ -n "$pid" ] || return 0
  if kill -0 "$pid" 2>/dev/null; then return 1; fi
  return 0
}
# Claim <generation> of <lock-dir> for this pid. Succeeds only when this
# process created the marker and its identity is now the owner file.
hp_lock_claim() { # <lock-dir> <generation>
  local marker="$1/taken-$2" tmp="$1/owner.$$"
  mkdir "$marker" 2>/dev/null || return 1
  hp_write_owner "$marker/owner" 2>/dev/null || return 1
  { cp "$marker/owner" "$tmp" 2>/dev/null && mv -f "$tmp" "$1/owner" 2>/dev/null; } || { rm -f "$tmp"; return 1; }
  [ "$(sed -n 's/^pid=//p' "$1/owner" 2>/dev/null)" = "$$" ]
}
hp_lock() { # <repo-dir>
  local lock guard waited=0 owner
  lock=$(hp_checkout_path "$1") || return 2
  lock="$lock.lock"
  guard="$lock.takeover"
  mkdir -p "$(dirname "$lock")"
  while ! mkdir "$lock" 2>/dev/null; do
    # A contender that died inside the takeover leaves the guard behind.
    if [ -d "$guard" ] && [ -n "$(find "$guard" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
      rmdir "$guard" 2>/dev/null || rm -rf "$guard"
    fi
    if hp_lock_stale "$lock" && mkdir "$guard" 2>/dev/null; then
      # Re-check under the guard and claim the generation that was checked.
      owner=$(hp_lock_owner_text "$lock")
      if [ -d "$lock" ] && hp_lock_stale "$lock" "$owner" && hp_lock_claim "$lock" "$(hp_lock_generation "$owner")"; then
        printf 'takeover by pid %s at %s of: %s\n' "$$" "$(hp_utc_now)" "$(printf '%s' "$owner" | tr '\n' ' ')" >> "$lock-history"
        rmdir "$guard" 2>/dev/null
        break
      fi
      rmdir "$guard" 2>/dev/null
      waited=$((waited + 1))
      continue
    fi
    if [ "$waited" -ge 150 ]; then
      echo "sdd-state: lock held: $(hp_lock_owner_text "$lock" | tr '\n' ' ')" >&2
      return 2
    fi
    sleep 0.2
    waited=$((waited + 1))
  done
  # A fresh lock gets its owner here; a takeover already wrote it.
  if [ "$(sed -n 's/^pid=//p' "$lock/owner" 2>/dev/null)" != "$$" ]; then hp_write_owner "$lock/owner"; fi
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
  local co=$1 br=$2 msg=$3 ref idxdir idx tip tree commit old
  shift 3
  ref="refs/heads/$br"
  idxdir=$(mktemp -d "${TMPDIR:-/tmp}/sdd-index.XXXXXX") || return 2
  idx="$idxdir/index"
  for _ in 1 2 3; do
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
