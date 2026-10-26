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
# Millisecond UTC for lines the stop guard compares against transcript
# timestamps; macOS date has no sub-second field, node is always present.
hp_utc_now_ms() { node -e 'process.stdout.write(new Date().toISOString())' 2>/dev/null || hp_utc_now; }

# hp_ledger_append LEDGER LINE: the one way a machine-written line reaches a
# ledger. The ledger is only ever appended to, never truncated or replaced:
# the controller appends prose to it without the lock, and any shrinking step
# could delete such an append. A failed write can leave an unterminated
# fragment. The next append saves it as one line in fragments.log beside the
# ledger, then ends it with a tab-"#fragment" marker line that the completion
# readers skip. A controller append that lands on an unended fragment glues to
# it, which is what an unlocked append always did and loses no data. Success
# means the tail really is LINE.
hp_ledger_append() { # <ledger> <line>
  local ledger=$1 line=$2 last cut
  if [ -s "$ledger" ]; then
    last=$(tail -c 1 "$ledger" | od -An -c | tr -d ' ')
    if [ "$last" != '\n' ]; then
      # One no-follow open: a symlink planted at fragments.log must not send
      # ledger text elsewhere, and a failure leaves the ledger untouched.
      node -e 'const fs=require("fs"),c=fs.constants;const b=fs.readFileSync(process.argv[1]);const f=b.subarray(b.lastIndexOf(10)+1).toString();const fd=fs.openSync(process.argv[2],c.O_WRONLY|c.O_APPEND|c.O_CREAT|c.O_NOFOLLOW,0o644);fs.writeSync(fd,process.argv[3]+" "+f+"\n");fs.closeSync(fd)' "$ledger" "$(dirname "$ledger")/fragments.log" "$(hp_utc_now)" 2>/dev/null || return 1
      printf '\t#fragment\n' >> "$ledger" || return 1
    fi
  fi
  if [ -n "${HYPERPOWERS_TEST_FAIL_APPEND:-}" ]; then
    # 1 cuts the last 15 bytes; a larger number cuts that many (inside the sha).
    case "$HYPERPOWERS_TEST_FAIL_APPEND" in *[!0-9]*|1) cut=15 ;; *) cut=$HYPERPOWERS_TEST_FAIL_APPEND ;; esac
    cut=$(( ${#line} > cut ? ${#line} - cut : 0 ))
    printf '%s' "${line:0:$cut}" >> "$ledger"
  else
    printf '%s\n' "$line" >> "$ledger" || return 1
  fi
  last=$(tail -c 1 "$ledger" | od -An -c | tr -d ' ')
  [ "$last" = '\n' ] && [ "$(tail -n 1 "$ledger")" = "$line" ]
}

# hp_ledger_records LEDGER: the ledger's lines that are records. An
# unterminated last line and any line ending in tab-"#fragment" are remains
# of an interrupted write, never records, even when their prefix reads like
# one. Every reader of a ledger line goes through here: sdd-state's
# completion readers and tracked-job's once-key check. 2 when unreadable.
hp_ledger_records() { # <ledger>
  local last tab
  tab=$(printf '\t')
  [ -r "$1" ] || return 2
  last=$(tail -c 1 "$1" | od -An -c | tr -d ' ')
  if [ "$last" = '\n' ]; then
    grep -v "${tab}#fragment\$" "$1"
  else
    sed '$d' "$1" | grep -v "${tab}#fragment\$"
  fi
  return 0
}

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
# Sourcing the library twice must not forget a lock this shell already
# holds, so the default is conditional.
: "${HP_LOCK_DIR:=}"
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
  local lock
  lock=$(hp_checkout_path "$1") || return 2
  hp_lock_at "$lock.lock"
}
# <lock-dir>: take a lock by its path. hp_lock derives the path from a
# repository; prune's dead-checkout removal has only the key.
hp_lock_at() { # <lock-dir>
  local lock=$1 guard waited=0 owner
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
    if [ "$waited" -ge "${HYPERPOWERS_LOCK_WAIT_STEPS:-150}" ]; then
      echo "sdd-state: lock held: $(hp_lock_owner_text "$lock" | tr '\n' ' ')" >&2
      return 2
    fi
    sleep 0.2
    waited=$((waited + 1))
  done
  # A fresh lock gets its owner here; a takeover already wrote it.
  if [ "$(sed -n 's/^pid=//p' "$lock/owner" 2>/dev/null)" != "$$" ]; then hp_write_owner "$lock/owner"; fi
  HP_LOCK_DIR=$lock
  # These traps replace the caller's: a script with its own EXIT handler
  # re-arms it after hp_lock and calls hp_unlock from it. A caller that must
  # not die under the lock sets HP_LOCK_KEEP_DISPOSITIONS=1 and keeps its own
  # INT and TERM dispositions, an ignore included — the SDD supervisor does,
  # because by the time it locks, its command has gone and the terminal
  # record has to land. The EXIT trap still releases the lock, and re-arming
  # the two here afterwards would leave the same gap this avoids.
  trap 'hp_unlock' EXIT
  if [ "${HP_LOCK_KEEP_DISPOSITIONS:-}" != 1 ]; then
    trap 'hp_unlock; exit 130' INT
    trap 'hp_unlock; exit 143' TERM
  fi
}
# Remove the lock only when this pid owns it: a stale takeover may have
# replaced it with another process's lock.
hp_unlock() {
  if [ -n "$HP_LOCK_DIR" ] && [ "$(sed -n 's/^pid=//p' "$HP_LOCK_DIR/owner" 2>/dev/null)" = "$$" ]; then
    rm -rf "$HP_LOCK_DIR"
  fi
  HP_LOCK_DIR=""
}

# --- containment ------------------------------------------------------------
# <root> <relative path>: 0 when every component of the path, from <root>
# down, is a real entry rather than a symbolic link. The dossier writers
# use shell redirection (>>, dd, mkdir -p), which follows a link out of the
# cache, and a state branch fetched from a remote can carry plans/<ws>, a
# ledger or any other entry as a link. The leaf is checked too and need not
# exist; -L is true for a dangling link, which a -f test would create
# through. The link that was found is named on stderr.
hp_contained() { # <root> <relative path>
  local cur=$1 rel=$2 part
  case "$rel" in /*|'') return 2 ;; esac
  while [ -n "$rel" ]; do
    part=${rel%%/*}
    if [ "$part" = "$rel" ]; then rel=""; else rel=${rel#*/}; fi
    case "$part" in ''|.|..) return 2 ;; esac
    cur="$cur/$part"
    if [ -L "$cur" ]; then
      echo "sdd-state: $cur is a symbolic link; refusing to write through it" >&2
      return 1
    fi
  done
  return 0
}

# --- private-index commit ---------------------------------------------------
# Commit only <paths> of <checkout> onto <branch> through a private index, so
# another session's staged or half-written files are never included. With
# --remove the paths are dropped from the tip's tree without reading the
# working tree at all, so a path recreated on disk meanwhile neither enters
# the commit nor stops it. Plumbing runs no hooks and signs nothing. Prints
# the new commit, or "none" when the paths already match the tip; a lost ref
# race is retried from the new tip, and creation of an unborn branch is
# conditional on the zero oid. The index path must not exist before
# read-tree: git rejects an existing empty file.
hp_commit_paths() { # [--remove] <checkout> <branch> <message> <path>...
  local mode=add co br msg ref idxdir idx tip tree commit old
  if [ "${1:-}" = --remove ]; then mode=remove; shift; fi
  co=$1 br=$2 msg=$3
  shift 3
  # With --remove and no pathspec, ls-files would list the whole index and
  # the commit would drop every dossier and the sentinel with them.
  [ $# -gt 0 ] || return 2
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
    if [ "$mode" = remove ]; then
      GIT_INDEX_FILE=$idx git -C "$co" ls-files -z -- "$@" 2>/dev/null | GIT_INDEX_FILE=$idx git -C "$co" update-index -z --force-remove --stdin 2>/dev/null || { rm -rf "$idxdir"; return 2; }
    else
      GIT_INDEX_FILE=$idx git -C "$co" add -A -- "$@" 2>/dev/null || { rm -rf "$idxdir"; return 2; }
    fi
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
      # The index refresh assumes <checkout> has <branch> checked out, which
      # every caller guarantees (hp_ensure_checkout validates it); on any
      # other HEAD it would stage the difference, so it is best-effort only.
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

# The ownership sentinel is the blob of exactly one line. It is compared by
# object id: command substitution would drop trailing newlines and accept a
# copy with a missing or extra newline as exact.
hp_sentinel_blob() { # <repo-dir>
  printf 'hyperpowers-state 1\n' | git -C "$1" hash-object --stdin
}
# <repo-dir> <commit>: 0 when the commit's root carries the exact sentinel.
hp_has_sentinel() {
  [ "$(git -C "$1" rev-parse -q --verify "$2:.hyperpowers-state" 2>/dev/null)" = "$(hp_sentinel_blob "$1")" ]
}
# <repo-dir> <commit>: hp_has_sentinel with the message for a branch at the
# state name that belongs to someone else (exit 2). Such a branch is never
# used and never written to.
hp_check_sentinel() {
  hp_has_sentinel "$1" "$2" && return 0
  echo "sdd-dir: branch $(hp_state_branch "$1") exists but is not a hyperpowers state branch; set git config hyperpowers.stateBranch to another name" >&2
  return 2
}

# <repo-dir or checkout> <rev>: inspect a whole tree before any of it can
# reach disk. Prints "<kind> <path>" for the first entry this helper refuses
# and returns 1; silent and 0 for a clean tree, 2 when the tree cannot be
# read. A dossier holds plain files, and so do the branch's root files: a
# symbolic link or a submodule entry anywhere would take a later write out
# of the cache, and a recovery sidecar (.sync-applying, .rewrite/) is this
# host's own interrupted state, which the next recovery executes, so no
# commit may carry one whatever its mode.
hp_tree_refusal() {
  local out line mode path
  # --full-tree: ls-tree is otherwise limited to the directory git runs in,
  # and the caller may pass the directory a plan file sits in.
  out=$(git -C "$1" -c core.quotePath=false ls-tree -r --full-tree "$2" 2>/dev/null) || return 2
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    mode=${line%% *}
    path=${line#*$'\t'}
    case "$mode" in
      120000) printf 'symbolic link %s\n' "$path"; return 1 ;;
      160000) printf 'submodule entry %s\n' "$path"; return 1 ;;
    esac
    # A path git had to quote keeps its opening quote here; both forms are
    # matched rather than unquoted, since only the refusal depends on it.
    case "$path" in
      .sync-applying|.rewrite/*|'".sync-applying'*|'".rewrite/'*) printf 'recovery sidecar %s\n' "$path"; return 1 ;;
    esac
  done < <(printf '%s\n' "$out")
  return 0
}

# <repo-dir> <tip>: 0 when a checkout may be created from <tip>. The tree
# arrives from another host, and git worktree add would write all of it, so
# it is validated before the first file lands; the caller holds the lock.
hp_refuse_tip() {
  local refusal rest rc=0
  refusal=$(hp_tree_refusal "$1" "$2") || rc=$?
  [ "$rc" -eq 0 ] && return 0
  # A tree that could not be read at all names no kind and no path, so it
  # gets its own sentence: the refusal below is parsed as two kind words
  # and a path, and its remedy would be wrong advice here.
  if [ "$rc" -ne 1 ]; then
    echo "sdd-state: $2 could not be read as a tree; refusing to create the state checkout from it. Fetch the state branch again and retry; if it persists, the repository needs repair" >&2
    return 2
  fi
  rest=${refusal#* }
  echo "sdd-state: ${2:0:7} carries a ${refusal%% *} ${rest%% *} at ${rest#* }; refusing to create the state checkout from it. Remove it on the host that committed it and commit the removal on the state branch, push, then sync again" >&2
  return 2
}

# <dir>: the state checkout's ignore rules. Everything here is regenerable
# or local to one host, so the branch carries none of it. A job's scratch is
# the last group: out.log can be large, go is a FIFO git cannot index at
# all, and the launch lock and the stop request are live signalling.
hp_write_ignore() { # <dir>
  printf '%s\n' '# Regenerable on any host: briefs come from task-brief, packages from review-package.' 'plans/*/task-*-brief.md' 'plans/*/review-*.diff' '# A copy an import left beside an entry it could not install: local to that host, for a human to merge.' 'plans/*/*.from-import' '# Job scratch (tracked-job): the record is meta.json and exit.' 'plans/*/jobs/*/out.log' 'plans/*/jobs/*/go' 'plans/*/jobs/*/launch.lock' 'plans/*/jobs/*/stop-request' > "$1/.gitignore"
}

# <checkout>: a checkout an older plugin created carries that plugin's
# ignore rules. They are regenerable, so every call that hands an existing
# checkout to a writer brings them up to date; the job patterns are the
# sentinel. The rewrite stays uncommitted on purpose: git reads the working
# tree's .gitignore, and the branch takes the lines from whichever host
# creates it.
hp_refresh_ignore() { # <checkout>
  grep -q 'plans/\*/jobs/\*/out.log' "$1/.gitignore" 2>/dev/null || hp_write_ignore "$1"
}

hp_write_root_files() { # <dir>
  printf 'hyperpowers-state 1\n' > "$1/.hyperpowers-state"
  hp_write_ignore "$1"
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
# A temporary checkout is promoted only when it is itself on the configured
# branch, its own HEAD carries the sentinel and its own tree passes the
# refusal; the candidate is validated, not the branch tip, so a leftover
# from another configuration, or one holding a tree no caller may be handed,
# is removed and the checkout is created from the tip instead.
# An interrupted orphan leaves no ref (the branch is unborn until its first
# commit), so there is nothing to delete; a branch with commits but no
# sentinel is foreign and refused later.
hp_recover_tmp_checkouts() {
  local repo=$1 co=$2 br=$3 wt head
  git -C "$repo" worktree prune >/dev/null 2>&1 || true
  if [ -d "$co" ] && [ ! -e "$co/.git" ]; then rmdir "$co" 2>/dev/null || true; fi
  for wt in "$co".tmp-*; do
    [ -e "$wt/.git" ] || continue
    head=$(git -C "$wt" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null) || head=""
    if [ ! -e "$co/.git" ] && [ -n "$head" ] && [ "$(git -C "$wt" symbolic-ref -q HEAD 2>/dev/null)" = "refs/heads/$br" ] && hp_has_sentinel "$repo" "$head" && hp_tree_refusal "$wt" "$head" >/dev/null; then
      if git -C "$repo" worktree move "$wt" "$co" >/dev/null 2>&1; then continue; fi
    fi
    git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
  done
  git -C "$repo" worktree prune >/dev/null 2>&1 || true
  rm -rf "$co".tmp-* 2>/dev/null || true
}

# <repo-dir> <checkout> <branch>: 0 when the checkout at the final path is a
# worktree of this repository on the configured branch whose HEAD carries
# the sentinel. The fast paths run it on every lookup, so a checkout left on
# another branch (hyperpowers.stateBranch changed after creation, or the
# worktree switched by hand) is never handed to a writer; exit 2 with the
# remedy.
hp_verify_checkout() {
  local repo=$1 co=$2 br=$3 sym head
  if [ "$(hp_common_dir "$co" 2>/dev/null)" != "$(hp_common_dir "$repo" 2>/dev/null)" ]; then
    echo "sdd-dir: state checkout $co does not belong to this repository; remove it and run again" >&2
    return 2
  fi
  sym=$(git -C "$co" symbolic-ref -q HEAD 2>/dev/null) || sym=""
  if [ "$sym" != "refs/heads/$br" ]; then
    echo "sdd-dir: state checkout $co is on ${sym:-a detached HEAD} but git config hyperpowers.stateBranch names $br; restore the config, or remove the checkout (git -C $repo worktree remove --force $co) and run again" >&2
    return 2
  fi
  head=$(git -C "$co" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null) || head=""
  if [ -z "$head" ]; then
    echo "sdd-dir: state checkout $co has no commit; remove it (git -C $repo worktree remove --force $co) and run again" >&2
    return 2
  fi
  hp_check_sentinel "$repo" "$head"
}

# <repo-dir> -> "branch <checkout>" or "plain <plain-root>". Exit 2 when the
# repository has a remote that has never been asked (needs-sync) or the
# state name belongs to a foreign branch. The one creation operation: it
# owns the lock, the temporary path, recovery, and the backend file.
hp_ensure_checkout() {
  local repo=$1 co br remote backend tmp mode tip rc=0 refusal rest
  co=$(hp_checkout_path "$repo") || return 2
  br=$(hp_state_branch "$repo"); remote=$(hp_state_remote "$repo")
  backend=$(hp_backend "$repo")
  if [ "$backend" = plain ]; then printf 'plain %s\n' "$(hp_plain_root "$repo")"; return 0; fi
  if [ -e "$co/.git" ]; then
    hp_verify_checkout "$repo" "$co" "$br" || return 2
    hp_refresh_ignore "$co"
    if [ "$backend" != branch ]; then
      # A crash between the move and the backend write left it unrecorded.
      hp_lock "$repo" || return 2
      hp_write_backend "$repo" branch || { hp_unlock; return 2; }
      hp_unlock
    fi
    printf 'branch %s\n' "$co"; return 0
  fi
  hp_lock "$repo" || return 2
  # Another caller may have chosen the plain backend while this one waited.
  if [ "$(hp_backend "$repo")" = plain ]; then hp_unlock; printf 'plain %s\n' "$(hp_plain_root "$repo")"; return 0; fi
  if [ -e "$co/.git" ]; then
    hp_verify_checkout "$repo" "$co" "$br" || { hp_unlock; return 2; }
    hp_refresh_ignore "$co"
    hp_write_backend "$repo" branch || { hp_unlock; return 2; }
    hp_unlock; printf 'branch %s\n' "$co"; return 0
  fi
  hp_recover_tmp_checkouts "$repo" "$co" "$br"
  if [ -e "$co/.git" ]; then
    hp_write_backend "$repo" branch || { hp_unlock; return 2; }
    hp_unlock; printf 'branch %s\n' "$co"; return 0
  fi
  if tip=$(git -C "$repo" rev-parse -q --verify "refs/heads/$br^{commit}" 2>/dev/null); then
    hp_check_sentinel "$repo" "$tip" || { hp_unlock; return 2; }
    hp_refuse_tip "$repo" "$tip" || { hp_unlock; return 2; }
    mode=local
  elif tip=$(git -C "$repo" rev-parse -q --verify "refs/remotes/$remote/$br^{commit}" 2>/dev/null); then
    hp_check_sentinel "$repo" "$tip" || { hp_unlock; return 2; }
    hp_refuse_tip "$repo" "$tip" || { hp_unlock; return 2; }
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
    # Test hook: move a ref between the validation and the add (REF=SHA).
    if [ -n "${HYPERPOWERS_TEST_SWAP_REF:-}" ]; then git -C "$repo" update-ref "${HYPERPOWERS_TEST_SWAP_REF%%=*}" "${HYPERPOWERS_TEST_SWAP_REF#*=}"; fi
    case "$mode" in
      local) git -C "$repo" worktree add -q "$tmp" "$br" >/dev/null 2>&1 || rc=$? ;;
      remote)
        # From the validated commit, never the ref: a fetch outside the lock
        # may have moved the remote-tracking ref since the sentinel check.
        if git -C "$repo" worktree add -q -b "$br" "$tmp" "$tip" >/dev/null 2>&1; then
          # Tracking is recorded directly: --set-upstream-to refuses a
          # remote-tracking ref the clone's fetch refspec does not cover (a
          # single-branch or depth-1 clone), and sync fetches the branch by
          # name regardless.
          { git -C "$tmp" config "branch.$br.remote" "$remote" && git -C "$tmp" config "branch.$br.merge" "refs/heads/$br"; } >/dev/null 2>&1 || rc=$?
        else rc=$?; fi ;;
      orphan) hp_add_orphan_worktree "$repo" "$tmp" "$br" || rc=$? ;;
    esac
  fi
  if [ "$rc" -ne 0 ]; then
    echo "sdd-dir: git worktree add (or its tracking setup) failed (rc=$rc); this repository uses the plain cache (backend=plain)" >&2
    git -C "$repo" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"
    hp_write_backend "$repo" plain || { hp_unlock; return 2; }
    hp_unlock; printf 'plain %s\n' "$(hp_plain_root "$repo")"; return 0
  fi
  if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = after-worktree-add ]; then hp_unlock; exit 99; fi
  if [ "$mode" = orphan ]; then
    hp_write_root_files "$tmp"
    hp_commit_paths "$tmp" "$br" "hyperpowers state: initial layout" . >/dev/null || { hp_unlock; return 2; }
  fi
  if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = after-initial-commit ]; then hp_unlock; exit 99; fi
  # Whatever moved under the add, the checkout that becomes live is the one
  # whose own HEAD was verified and whose own tree was validated: local
  # mode adds from the branch name, so a ref moved between the validation
  # above and the add would otherwise be promoted unseen. An orphan's four
  # root files pass, so the call is the same in all three modes.
  hp_verify_checkout "$repo" "$tmp" "$br" || { git -C "$repo" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"; hp_unlock; return 2; }
  hp_refuse_tip "$tmp" "$(git -C "$tmp" rev-parse HEAD)" || { git -C "$repo" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"; hp_unlock; return 2; }
  git -C "$repo" worktree move "$tmp" "$co" >/dev/null 2>&1 || { echo "sdd-dir: git worktree move of $tmp to $co failed; remove whatever occupies $co and run again" >&2; hp_unlock; return 2; }
  hp_write_backend "$repo" branch || { hp_unlock; return 2; }
  hp_unlock
  printf 'branch %s\n' "$co"
}

# <repo-dir> <ws> <dest-dir>: under the plain backend, copy the plan's
# workspace out of the state branch when the destination has no ledger yet.
# The local branch and the remote-tracking branch are both candidates and
# each must carry the sentinel (a foreign tip is exit 2). The source is the
# descendant when both tips resolve, whatever it holds, so a finish on one
# side is not undone by a stale copy on the other; when they have diverged
# and either holds the plan, exit 2 naming both, because choosing one would
# hide the other's ledger lines or revive a finished dossier. Records the source tip in the backend file. Callers hold the
# repository lock. A plain fallback never starts an empty ledger over
# branch state: a failed archive is exit 2 and leaves no destination,
# because the workspace is published by one rename from a staging
# directory.
hp_materialize_plain() {
  local repo=$1 ws=$2 dest=$3 br remote local_tip remote_tip tip root staging archive_rc tar_rc local_has remote_has rc refusal rest
  [ -f "$dest/progress.md" ] && return 0
  br=$(hp_state_branch "$repo"); remote=$(hp_state_remote "$repo")
  local_tip=$(git -C "$repo" rev-parse -q --verify "refs/heads/$br^{commit}" 2>/dev/null) || local_tip=""
  remote_tip=$(git -C "$repo" rev-parse -q --verify "refs/remotes/$remote/$br^{commit}" 2>/dev/null) || remote_tip=""
  if [ -n "$local_tip" ]; then hp_check_sentinel "$repo" "$local_tip" || return 2; fi
  if [ -n "$remote_tip" ]; then hp_check_sentinel "$repo" "$remote_tip" || return 2; fi
  # Ancestry before presence: a descendant that removed the plan (finish)
  # is authoritative over an ancestor that still holds it.
  if [ -n "$local_tip" ] && [ -n "$remote_tip" ] && [ "$local_tip" != "$remote_tip" ]; then
    if git -C "$repo" merge-base --is-ancestor "$local_tip" "$remote_tip" 2>/dev/null; then tip=$remote_tip
    elif git -C "$repo" merge-base --is-ancestor "$remote_tip" "$local_tip" 2>/dev/null; then tip=$local_tip
    else
      local_has=0; remote_has=0
      git -C "$repo" cat-file -e "$local_tip:plans/$ws/progress.md" 2>/dev/null && local_has=1
      git -C "$repo" cat-file -e "$remote_tip:plans/$ws/progress.md" 2>/dev/null && remote_has=1
      if [ "$local_has" -eq 0 ] && [ "$remote_has" -eq 0 ]; then return 0; fi
      echo "sdd-dir: $br ($local_tip) and $remote/$br ($remote_tip) have diverged and at least one of them holds plans/$ws; reconcile them (sdd-state sync under the branch backend, or merge the state branch) before the plain fallback can materialize this plan" >&2
      return 2
    fi
  else
    tip=${local_tip:-$remote_tip}
  fi
  [ -n "$tip" ] || return 0
  git -C "$repo" cat-file -e "$tip:plans/$ws/progress.md" 2>/dev/null || return 0
  # git archive writes whatever the tip holds, so this backend inspects the
  # tree before any of it reaches the cache, as the branch backend does
  # before a checkout is created. The remedy names the branch: a link the
  # extraction had already written could not be cleared from this host,
  # because the next call extracts it again from the same tip.
  rc=0; refusal=$(hp_tree_refusal "$repo" "$tip") || rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "sdd-dir: $tip could not be read as a tree; refusing to materialize the plain workspace from it. Fetch the state branch again and retry; if it persists, the repository needs repair" >&2
    return 2
  fi
  if [ "$rc" -ne 0 ]; then
    rest=${refusal#* }
    echo "sdd-dir: ${tip:0:7} on $br carries a ${refusal%% *} ${rest%% *} at ${rest#* }; refusing to materialize the plain workspace from it. Remove it on the host that committed it and commit the removal on the state branch, push, then fetch that branch here (git fetch $remote $br; under the plain backend sdd-state sync does not fetch) and run sdd-dir again" >&2
    return 2
  fi
  root=$(dirname "$(dirname "$dest")")
  mkdir -p "$root/plans"
  # The same containment rule the branch writers follow: neither the local
  # path being published nor the workspace the branch carries may be a link.
  hp_contained "$root" "plans/$ws" || return 2
  # Extract into a staging directory beside the destination and publish it
  # with one rename, so an interrupted extraction never leaves a partial
  # workspace that the ledger check above would accept as complete. Stale
  # staging directories are leftovers of interrupted runs (callers hold the
  # lock, so none is live).
  rm -rf "${root:?}"/.materialize.* 2>/dev/null
  staging=$(mktemp -d "$root/.materialize.XXXXXX") || return 2
  # Archive from the top level: a pathspec is relative to the current
  # directory, and the plan may sit in a subdirectory of the work tree.
  git -C "$(git -C "$repo" rev-parse --show-toplevel)" archive "$tip" "plans/$ws" | tar -x -C "$staging"
  archive_rc=${PIPESTATUS[0]} tar_rc=${PIPESTATUS[1]}
  if [ "$archive_rc" -ne 0 ] || [ "$tar_rc" -ne 0 ] || [ ! -f "$staging/plans/$ws/progress.md" ]; then rm -rf "$staging"; return 2; fi
  hp_contained "$staging" "plans/$ws" || { rm -rf "$staging"; return 2; }
  rm -rf "$dest"
  if ! mv "$staging/plans/$ws" "$dest"; then rm -rf "$staging"; return 2; fi
  rm -rf "$staging"
  hp_write_backend "$repo" "plain source=$tip"
}
