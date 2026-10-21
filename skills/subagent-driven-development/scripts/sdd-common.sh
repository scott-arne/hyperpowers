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
      # Re-check under the guard: the lock may have been replaced meanwhile.
      if [ -d "$lock" ] && hp_lock_stale "$lock"; then
        owner=$(tr '\n' ' ' < "$lock/owner" 2>/dev/null)
        printf 'takeover by pid %s at %s of: %s\n' "$$" "$(hp_utc_now)" "$owner" >> "$lock-history"
        rm -rf "$lock"
      fi
      rmdir "$guard" 2>/dev/null
      waited=$((waited + 1))
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
