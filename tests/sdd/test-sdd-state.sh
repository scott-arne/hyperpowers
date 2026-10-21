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
TEST_ROOT=$(mktemp -d) || exit 2
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || exit 2
# git prints worktree paths physically; a symlinked temp root (macOS /var) would defeat registrations().
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 2
export XDG_CACHE_HOME="$TEST_ROOT/cache"
STATE_ROOT="$XDG_CACHE_HOME/hyperpowers/state"
cleanup() { if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then rm -rf "$TEST_ROOT"; fi; }
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
# materialize <repo> <ws> <dest>: hp_materialize_plain in a subshell.
# shellcheck source=/dev/null
materialize() { ( . "$LIB"; hp_materialize_plain "$@" ); }
# shellcheck source=/dev/null
state_key() { ( . "$LIB"; hp_key "$1" ); }
run_state() { ( cd "$1" && shift && bash "$SDD_STATE" "$@" ); }
run_sdd_dir() { ( cd "$1" && shift && bash "$SDD_DIR" "$@" ); }
registrations() { git -C "$1" worktree list --porcelain | grep -c "^worktree $STATE_ROOT/"; }
# ws_path <repo> <plan>: the workspace path inside the repository's checkout,
# created, without going through sdd-dir (Task 5 asserts sdd-dir prints it).
# shellcheck source=/dev/null
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

# A checkout left on another branch than the configured one is refused on
# the fast path, with the remedy, and nothing is created for the new name.
git -C "$r1" config hyperpowers.stateBranch renamed/state
err=$(ensure "$r1" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'renamed/state' && printf '%s' "$err" | grep -q 'refs/heads/hyperpowers/state' && ! git -C "$r1" rev-parse -q --verify renamed/state >/dev/null; then pass "a checkout on another branch than configured is refused with the remedy"; else fail "a checkout on another branch than configured is refused with the remedy (rc=$rc: $err)"; fi
git -C "$r1" config --unset hyperpowers.stateBranch
out=$(ensure "$r1"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "branch $co1" ]; then pass "restoring the config restores the fast path"; else fail "restoring the config restores the fast path (rc=$rc, '$out')"; fi
# A checkout whose backend record is missing (a crash between the move and
# the backend write) is repaired on the next call.
rm -f "$co1.backend"
out=$(ensure "$r1"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "branch $co1" ] && [ "$(cat "$co1.backend" 2>/dev/null)" = branch ]; then pass "a missing backend record is repaired on the next call"; else fail "a missing backend record is repaired on the next call (rc=$rc)"; fi

# The sentinel is byte-exact: an extra trailing newline makes the branch foreign.
r8="$TEST_ROOT/r8"; make_repo "$r8"
sloppy_blob=$(printf 'hyperpowers-state 1\n\n' | git -C "$r8" hash-object -w --stdin)
sloppy_tree=$(printf '100644 blob %s\t.hyperpowers-state\n' "$sloppy_blob" | git -C "$r8" mktree)
sloppy_commit=$(git -C "$r8" commit-tree "$sloppy_tree" -m sloppy)
git -C "$r8" branch hyperpowers/state "$sloppy_commit"
err=$(ensure "$r8" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'hyperpowers.stateBranch' && [ ! -e "$STATE_ROOT/$(state_key "$r8")/.git" ]; then pass "a sentinel with an extra trailing newline is foreign"; else fail "a sentinel with an extra trailing newline is foreign (rc=$rc: $err)"; fi

# Recovery promotes only a temporary checkout that is itself on the
# configured branch: a leftover on another branch is removed and a fresh
# checkout is created from the branch tip.
r9="$TEST_ROOT/r9"; make_repo "$r9"
ensure "$r9" >/dev/null; co9="$STATE_ROOT/$(state_key "$r9")"
git -C "$r9" worktree remove --force "$co9"
git -C "$r9" worktree add -q -b leftover "$co9.tmp-stale" >/dev/null 2>&1
out=$(ensure "$r9"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "branch $co9" ] && [ "$(git -C "$co9" symbolic-ref -q HEAD)" = refs/heads/hyperpowers/state ] && [ ! -e "$co9.tmp-stale" ] && [ "$(registrations "$r9")" -eq 1 ]; then pass "recovery removes a leftover on another branch and recreates from the tip"; else fail "recovery removes a leftover on another branch and recreates from the tip (rc=$rc, '$out')"; fi

# The plain fallback reads both owned tips: the one that holds the plan is
# the source, the descendant when both do, diverged tips are refused, and a
# foreign tip is refused before anything is read from it.
make_pair p2
keyA=$(state_key "$PAIR_A"); keyB=$(state_key "$PAIR_B")
: > "$STATE_ROOT/$keyA.fetched"
coA="$STATE_ROOT/$keyA"
ensure "$PAIR_A" >/dev/null
mkdir -p "$coA/plans/demo-00000000"
printf '# SDD ledger — plan: docs/plan.md\n' > "$coA/plans/demo-00000000/progress.md"
# shellcheck source=/dev/null
( . "$LIB"; hp_commit_paths "$coA" hyperpowers/state "demo ledger" plans/demo-00000000/progress.md >/dev/null )
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
: > "$STATE_ROOT/$keyB.fetched"
ensure "$PAIR_B" HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 >/dev/null 2>&1
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
remote_tip=$(git -C "$PAIR_B" rev-parse origin/hyperpowers/state)
initial=$(git -C "$PAIR_B" rev-parse "origin/hyperpowers/state~1")
remote_tree=$(git -C "$PAIR_B" rev-parse "origin/hyperpowers/state^{tree}")
git -C "$PAIR_B" branch hyperpowers/state "$initial"
plainB="$XDG_CACHE_HOME/hyperpowers/sdd/$keyB"; destB="$plainB/plans/demo-00000000"
materialize "$PAIR_B" demo-00000000 "$destB"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$destB/progress.md" ] && [ "$(cat "$STATE_ROOT/$keyB.backend")" = "plain source=$remote_tip" ]; then pass "the plain fallback materializes from the remote tip when only it holds the plan"; else fail "the plain fallback materializes from the remote tip when only it holds the plan (rc=$rc)"; fi
ahead=$(git -C "$PAIR_B" commit-tree "$remote_tree" -p "$remote_tip" -m "local ahead")
git -C "$PAIR_B" update-ref refs/heads/hyperpowers/state "$ahead"
rm -rf "$destB"
materialize "$PAIR_B" demo-00000000 "$destB"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$destB/progress.md" ] && [ "$(cat "$STATE_ROOT/$keyB.backend")" = "plain source=$ahead" ]; then pass "when both tips hold the plan the descendant is the source"; else fail "when both tips hold the plan the descendant is the source (rc=$rc)"; fi
diverged=$(git -C "$PAIR_B" commit-tree "$remote_tree" -p "$initial" -m "diverged")
git -C "$PAIR_B" update-ref refs/heads/hyperpowers/state "$diverged"
rm -rf "$destB"
err=$(materialize "$PAIR_B" demo-00000000 "$destB" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q "$diverged" && printf '%s' "$err" | grep -q "$remote_tip" && [ ! -f "$destB/progress.md" ]; then pass "diverged tips that both hold the plan are refused, naming both"; else fail "diverged tips that both hold the plan are refused, naming both (rc=$rc: $err)"; fi
git -C "$PAIR_B" update-ref refs/heads/hyperpowers/state "$(git -C "$PAIR_B" rev-parse main)"
err=$(materialize "$PAIR_B" demo-00000000 "$destB" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'hyperpowers.stateBranch' && [ ! -f "$destB/progress.md" ]; then pass "a foreign tip at the state name is refused by the plain fallback"; else fail "a foreign tip at the state name is refused by the plain fallback (rc=$rc: $err)"; fi

# A descendant that removed the plan (finish) is authoritative over a stale
# ancestor that still holds it, in either direction; a diverged pair that
# disagrees about the plan is refused.
initial_tree=$(git -C "$PAIR_B" rev-parse "$initial^{tree}")
finished=$(git -C "$PAIR_B" commit-tree "$initial_tree" -p "$remote_tip" -m "finished: workspace removed")
git -C "$PAIR_B" update-ref refs/heads/hyperpowers/state "$remote_tip"
git -C "$PAIR_B" update-ref refs/remotes/origin/hyperpowers/state "$finished"
rm -rf "$destB"
materialize "$PAIR_B" demo-00000000 "$destB"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$destB" ] && [ "$(cat "$STATE_ROOT/$keyB.backend")" = "plain source=$ahead" ]; then pass "a remote descendant that finished the plan is not undone by a stale local copy"; else fail "a remote descendant that finished the plan is not undone by a stale local copy (rc=$rc)"; fi
git -C "$PAIR_B" update-ref refs/heads/hyperpowers/state "$finished"
git -C "$PAIR_B" update-ref refs/remotes/origin/hyperpowers/state "$remote_tip"
materialize "$PAIR_B" demo-00000000 "$destB"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$destB" ]; then pass "a local descendant that finished the plan is not undone by a stale remote copy"; else fail "a local descendant that finished the plan is not undone by a stale remote copy (rc=$rc)"; fi
git -C "$PAIR_B" update-ref refs/heads/hyperpowers/state "$diverged"
git -C "$PAIR_B" update-ref refs/remotes/origin/hyperpowers/state "$finished"
err=$(materialize "$PAIR_B" demo-00000000 "$destB" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q "$diverged" && printf '%s' "$err" | grep -q "$finished" && [ ! -e "$destB" ]; then pass "a diverged pair that disagrees about the plan is refused, naming both"; else fail "a diverged pair that disagrees about the plan is refused, naming both (rc=$rc: $err)"; fi
git -C "$PAIR_B" update-ref refs/remotes/origin/hyperpowers/state "$remote_tip"

# A ref that moves between the sentinel check and the worktree add cannot
# smuggle a foreign commit in: remote mode creates from the validated
# commit, and every mode verifies the temporary checkout before the move.
make_pair p3
: > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
ensure "$PAIR_A" >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
validated=$(git -C "$PAIR_B" rev-parse origin/hyperpowers/state)
foreign=$(git -C "$PAIR_B" rev-parse main)
out=$(ensure "$PAIR_B" "HYPERPOWERS_TEST_SWAP_REF=refs/remotes/origin/hyperpowers/state=$foreign" 2>/dev/null); rc=$?
coB3="$STATE_ROOT/$(state_key "$PAIR_B")"
if [ "$rc" -eq 0 ] && [ "$out" = "branch $coB3" ] && [ "$(git -C "$PAIR_B" rev-parse hyperpowers/state)" = "$validated" ] && [ "$(git -C "$PAIR_B" config branch.hyperpowers/state.remote)" = origin ]; then pass "remote mode creates from the validated commit when the remote ref moves under it"; else fail "remote mode creates from the validated commit when the remote ref moves under it (rc=$rc, '$out', branch=$(git -C "$PAIR_B" rev-parse hyperpowers/state 2>/dev/null))"; fi
git -C "$PAIR_B" update-ref refs/remotes/origin/hyperpowers/state "$validated"
# Local mode: the local branch is moved to a foreign commit under the add;
# the temporary checkout fails verification and nothing becomes live.
r10="$TEST_ROOT/r10"; make_repo "$r10"
ensure "$r10" >/dev/null; co10="$STATE_ROOT/$(state_key "$r10")"
git -C "$r10" worktree remove --force "$co10"
err=$(ensure "$r10" "HYPERPOWERS_TEST_SWAP_REF=refs/heads/hyperpowers/state=$(git -C "$r10" rev-parse main)" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'hyperpowers.stateBranch' && [ ! -e "$co10/.git" ] && ! ls -d "$co10.tmp-"* >/dev/null 2>&1 && [ "$(registrations "$r10")" -eq 0 ]; then pass "a local branch moved under the add fails verification before the move"; else fail "a local branch moved under the add fails verification before the move (rc=$rc: $err)"; fi

# A caller that waited for the lock honors a plain backend persisted by the
# holder meanwhile, instead of creating a branch checkout beside it.
r11="$TEST_ROOT/r11"; make_repo "$r11"
bash -c '. "$1"; hp_lock "$2"; sleep 1; hp_write_backend "$2" plain; hp_unlock' _ "$LIB" "$r11" &
holder11=$!
sleep 0.3
out=$(ensure "$r11" 2>/dev/null); rc=$?
wait "$holder11"
plain11="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$r11")"
if [ "$rc" -eq 0 ] && [ "$out" = "plain $plain11" ] && [ ! -e "$STATE_ROOT/$(state_key "$r11")/.git" ] && [ "$(registrations "$r11")" -eq 0 ]; then pass "a waiter honors a plain backend persisted while it waited"; else fail "a waiter honors a plain backend persisted while it waited (rc=$rc, '$out')"; fi

# Materialization publishes the whole workspace by one rename: a partial
# destination without a ledger is replaced, a stale staging directory from
# an interrupted run is removed, and no staging directory remains.
make_pair p4
: > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
coA4="$STATE_ROOT/$(state_key "$PAIR_A")"
ensure "$PAIR_A" >/dev/null
mkdir -p "$coA4/plans/demo-00000000"
printf '# SDD ledger — plan: docs/plan.md\n' > "$coA4/plans/demo-00000000/progress.md"
printf 'report\n' > "$coA4/plans/demo-00000000/task-1-report.md"
# shellcheck source=/dev/null
( . "$LIB"; hp_commit_paths "$coA4" hyperpowers/state "demo ledger and report" plans/demo-00000000/progress.md plans/demo-00000000/task-1-report.md >/dev/null )
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
: > "$STATE_ROOT/$(state_key "$PAIR_B").fetched"
ensure "$PAIR_B" HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 >/dev/null 2>&1
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
plainB4="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$PAIR_B")"; destB4="$plainB4/plans/demo-00000000"
mkdir -p "$destB4" "$plainB4/.materialize.stale/plans/demo-00000000"
printf 'partial\n' > "$destB4/task-1-report.md"
printf 'stale\n' > "$plainB4/.materialize.stale/plans/demo-00000000/progress.md"
materialize "$PAIR_B" demo-00000000 "$destB4"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$destB4/progress.md")" = "# SDD ledger — plan: docs/plan.md" ] && [ "$(cat "$destB4/task-1-report.md")" = report ] && [ ! -e "$plainB4/.materialize.stale" ] && ! ls -d "$plainB4"/.materialize.* >/dev/null 2>&1 && [ "$(cat "$STATE_ROOT/$(state_key "$PAIR_B").backend")" = "plain source=$(git -C "$PAIR_B" rev-parse origin/hyperpowers/state)" ]; then pass "materialization replaces a partial destination whole and leaves no staging"; else fail "materialization replaces a partial destination whole and leaves no staging (rc=$rc)"; fi

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
run_state "$c1" claim docs/plan.md 3 >/dev/null 2>&1; rc=$?
   if [ "$rc" -eq 2 ] && [ ! -d "$wsc/claims/task-3" ]; then pass "claim without --session is a usage error (exit 2, nothing created)"; else fail "claim without --session is a usage error (rc=$rc)"; fi
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
rm -rf "$wsc/claims/.tmp-prepared"
# Claims fail closed: a failed owner write publishes nothing and reports
# error; a takeover whose record cannot be written leaves the old owner and
# no history line; an unreadable ledger is an error, not "not complete";
# malformed task numbers and extra operands are usage errors.
out=$(HYPERPOWERS_TEST_FAIL_OWNER_WRITE=1 run_state "$c1" claim docs/plan.md 6 --session s-twelve 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -d "$wsc/claims/task-6" ] && ! ls -d "$wsc/claims/.tmp-"* >/dev/null 2>&1; then pass "a failed owner write publishes no claim and reports error"; else fail "a failed owner write publishes no claim and reports error (rc=$rc: $out)"; fi
chmod a-w "$wsc/claims/task-2"
out=$(run_state "$c1" claim docs/plan.md 2 --session s-thirteen --takeover 2>/dev/null); rc=$?
chmod u+w "$wsc/claims/task-2"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(sed -n 's/^session=//p' "$wsc/claims/task-2/owner")" = s-three ] && [ ! -e "$wsc/claims/task-2/owner.history" ] && [ ! -e "$wsc/claims/task-2/owner.new" ]; then pass "a takeover whose record cannot be written leaves the old owner and no history"; else fail "a takeover whose record cannot be written leaves the old owner and no history (rc=$rc: $out)"; fi
chmod a-r "$wsc/progress.md"
out=$(run_state "$c1" claim docs/plan.md 7 --session s-fourteen 2>/dev/null); rc=$?
chmod u+r "$wsc/progress.md"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -d "$wsc/claims/task-7" ]; then pass "an unreadable ledger is an error, not an unclaimed task"; else fail "an unreadable ledger is an error, not an unclaimed task (rc=$rc: $out)"; fi
run_state "$c1" claim docs/plan.md 1x --session s-fifteen >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ] && [ ! -d "$wsc/claims/task-1x" ]; then pass "a task number that is not decimal is a usage error"; else fail "a task number that is not decimal is a usage error (rc=$rc)"; fi
run_state "$c1" claim docs/plan.md 8 9 --session s-sixteen >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ] && [ ! -d "$wsc/claims/task-8" ] && [ ! -d "$wsc/claims/task-9" ]; then pass "an extra operand is a usage error and claims nothing"; else fail "an extra operand is a usage error and claims nothing (rc=$rc)"; fi

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
pointer="$XDG_CACHE_HOME/hyperpowers/sdd/cwdkey0000000000/plans/$(basename "$wsi")+$(state_key "$i1" | cut -c1-8)"
mkdir -p "$(dirname "$pointer")"; ln -s "$other" "$pointer"
out=$(run_state "$i1" import docs/plan.md)
if [ "$out" = "status=skipped reason=ledger-exists path=$pointer" ] && [ -d "$other" ]; then pass "a candidate behind an existing ledger is left alone and named"; else fail "a candidate behind an existing ledger is left alone and named ($out)"; fi

# A pointer candidate is relinked to the new workspace after the move.
i2="$TEST_ROOT/i2"; make_repo "$i2"
mkdir -p "$i2/docs"; : > "$i2/docs/plan.md"; git -C "$i2" add docs; git -C "$i2" commit -qm plan
wsi2=$(ws_path "$i2" "$i2/docs/plan.md")
real2="$XDG_CACHE_HOME/hyperpowers/sdd/legacykey0000000/plans/$(basename "$wsi2")"
ptr2="$XDG_CACHE_HOME/hyperpowers/sdd/cwdkey0000000001/plans/$(basename "$wsi2")+$(state_key "$i2" | cut -c1-8)"
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
# A destination that already holds regenerable files (a brief written before
# the import ran) receives the ledger and reports moved: the identity line is
# rewritten in the stage and the installed tree is verified against the stage,
# not against the source's pre-rewrite sizes.
i7="$TEST_ROOT/i7"; make_repo "$i7"
mkdir -p "$i7/docs"; : > "$i7/docs/plan.md"; git -C "$i7" add docs; git -C "$i7" commit -qm plan
wsi7=$(ws_path "$i7" "$i7/docs/plan.md"); mkdir -p "$wsi7"; printf 'brief\n' > "$wsi7/task-9-brief.md"
legacy_i7="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i7")/plans/$(basename "$wsi7")"
mkdir -p "$legacy_i7/claims/task-1"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' "$i7" > "$legacy_i7/progress.md"
printf 'report\n' > "$legacy_i7/task-1-report.md"; printf 'session=s\n' > "$legacy_i7/claims/task-1/owner"
out=$(run_state "$i7" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i7" ] && [ "$(head -n 1 "$wsi7/progress.md")" = "# SDD ledger — plan: docs/plan.md" ] && [ -f "$wsi7/task-1-report.md" ] && [ -f "$wsi7/task-9-brief.md" ] && [ -f "$wsi7/claims/task-1/owner" ] && [ -L "$legacy_i7" ]; then pass "import into a destination that already holds files installs the ledger and rewrites its identity"; else fail "import into a destination that already holds files installs the ledger and rewrites its identity (rc=$rc: $out)"; fi
run_state "$i7" import >/dev/null 2>&1; rc=$?
run_state "$i7" import docs/plan.md extra >/dev/null 2>&1; rc2=$?
if [ "$rc" -eq 2 ] && [ "$rc2" -eq 2 ]; then pass "import with zero or two operands is a usage error"; else fail "import with zero or two operands is a usage error (rc=$rc/$rc2)"; fi
# An identity naming another repository's plan that EXISTS on this host is
# left alone (the SDD skill's identity check flags it); only a path that does
# not exist here is rewritten by its suffix.
i8a="$TEST_ROOT/i8a"; make_repo "$i8a"; mkdir -p "$i8a/docs"; : > "$i8a/docs/plan.md"; git -C "$i8a" add docs; git -C "$i8a" commit -qm plan
i8b="$TEST_ROOT/i8b"; make_repo "$i8b"; mkdir -p "$i8b/docs"; : > "$i8b/docs/plan.md"; git -C "$i8b" add docs; git -C "$i8b" commit -qm plan
wsi8b=$(ws_path "$i8b" "$i8b/docs/plan.md")
legacy_i8b="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i8b")/plans/$(basename "$wsi8b")"
mkdir -p "$legacy_i8b"; printf '# SDD ledger — plan: %s/docs/plan.md\n' "$i8a" > "$legacy_i8b/progress.md"
out=$(run_state "$i8b" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i8b" ] && [ "$(head -n 1 "$wsi8b/progress.md")" = "# SDD ledger — plan: $i8a/docs/plan.md" ]; then pass "an identity naming another repository's existing plan is not rewritten"; else fail "an identity naming another repository's existing plan is not rewritten (rc=$rc: $out: $(head -n 1 "$wsi8b/progress.md" 2>/dev/null))"; fi

# A failed relink is undone: the source is back as a real directory with its
# files, no backup remains, and the destination holds no ledger.
i9="$TEST_ROOT/i9"; make_repo "$i9"; mkdir -p "$i9/docs"; : > "$i9/docs/plan.md"; git -C "$i9" add docs; git -C "$i9" commit -qm plan
wsi9=$(ws_path "$i9" "$i9/docs/plan.md")
legacy_i9="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i9")/plans/$(basename "$wsi9")"
mkdir -p "$legacy_i9"; printf '# SDD ledger — plan: docs/plan.md\n' > "$legacy_i9/progress.md"; printf 'report\n' > "$legacy_i9/task-1-report.md"
out=$(HYPERPOWERS_TEST_FAIL_RELINK=1 run_state "$i9" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=import-failed from=$legacy_i9" ] && [ -d "$legacy_i9" ] && [ ! -L "$legacy_i9" ] && [ -f "$legacy_i9/progress.md" ] && [ -f "$legacy_i9/task-1-report.md" ] && ! ls -d "$legacy_i9.importing-"* >/dev/null 2>&1 && [ ! -f "$wsi9/progress.md" ]; then pass "a failed relink restores the source and leaves no ledger or backup"; else fail "a failed relink restores the source and leaves no ledger or backup (rc=$rc: $out)"; fi
out=$(run_state "$i9" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i9" ] && [ -L "$legacy_i9" ] && [ -f "$wsi9/progress.md" ]; then pass "the next import succeeds after a failed relink"; else fail "the next import succeeds after a failed relink (rc=$rc: $out)"; fi

# An import interrupted after the source was renamed aside is recovered on
# the next call: the backup is put back, then imported.
i10="$TEST_ROOT/i10"; make_repo "$i10"; mkdir -p "$i10/docs"; : > "$i10/docs/plan.md"; git -C "$i10" add docs; git -C "$i10" commit -qm plan
wsi10=$(ws_path "$i10" "$i10/docs/plan.md")
legacy_i10="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i10")/plans/$(basename "$wsi10")"
mkdir -p "$legacy_i10.importing-424242"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i10.importing-424242/progress.md"
out=$(run_state "$i10" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i10" ] && [ -L "$legacy_i10" ] && [ "$(sed -n 2p "$wsi10/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && ! ls -d "$legacy_i10.importing-"* >/dev/null 2>&1; then pass "an interrupted import's backup is recovered and imported on the next call"; else fail "an interrupted import's backup is recovered and imported on the next call (rc=$rc: $out)"; fi
# A cutover interrupted after publication (destination complete, source still
# in its backup) is finished on the next call; one whose destination differs
# from the source is left as ledger-exists with the source restored.
i11="$TEST_ROOT/i11"; make_repo "$i11"; mkdir -p "$i11/docs"; : > "$i11/docs/plan.md"; git -C "$i11" add docs; git -C "$i11" commit -qm plan
wsi11=$(ws_path "$i11" "$i11/docs/plan.md"); mkdir -p "$wsi11"
legacy_i11="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i11")/plans/$(basename "$wsi11")"
mkdir -p "$legacy_i11.importing-555"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' "$i11" > "$legacy_i11.importing-555/progress.md"
printf 'report\n' > "$legacy_i11.importing-555/task-1-report.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsi11/progress.md"
printf 'report\n' > "$wsi11/task-1-report.md"
out=$(run_state "$i11" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i11" ] && [ -L "$legacy_i11" ] && ! ls -d "$legacy_i11.importing-"* >/dev/null 2>&1 && [ "$(head -n 1 "$wsi11/progress.md")" = "# SDD ledger — plan: docs/plan.md" ]; then pass "a cutover interrupted after publication is finished on the next call"; else fail "a cutover interrupted after publication is finished on the next call (rc=$rc: $out)"; fi
i12="$TEST_ROOT/i12"; make_repo "$i12"; mkdir -p "$i12/docs"; : > "$i12/docs/plan.md"; git -C "$i12" add docs; git -C "$i12" commit -qm plan
wsi12=$(ws_path "$i12" "$i12/docs/plan.md"); mkdir -p "$wsi12"
legacy_i12="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i12")/plans/$(basename "$wsi12")"
mkdir -p "$legacy_i12.importing-556"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i12.importing-556/progress.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' > "$wsi12/progress.md"
out=$(run_state "$i12" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=skipped reason=ledger-exists path=$legacy_i12" ] && [ -d "$legacy_i12" ] && [ ! -L "$legacy_i12" ] && [ "$(wc -l < "$wsi12/progress.md" | tr -d ' ')" = 3 ]; then pass "a restored source that differs from the destination is reported, not merged"; else fail "a restored source that differs from the destination is reported, not merged (rc=$rc: $out)"; fi

# An empty pre-existing destination is replaced by the published stage (no
# nesting), and a ledger line appended to the source after the copy was
# taken is carried into the destination before the backup goes.
i13="$TEST_ROOT/i13"; make_repo "$i13"; mkdir -p "$i13/docs"; : > "$i13/docs/plan.md"; git -C "$i13" add docs; git -C "$i13" commit -qm plan
wsi13=$(ws_path "$i13" "$i13/docs/plan.md"); mkdir -p "$wsi13"
legacy_i13="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i13")/plans/$(basename "$wsi13")"
mkdir -p "$legacy_i13"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i13/progress.md"
out=$(HYPERPOWERS_TEST_LATE_APPEND='Task 2: complete (commits 3333333..4444444, review clean)' run_state "$i13" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i13" ] && [ -f "$wsi13/progress.md" ] && [ ! -d "$wsi13/$(basename "$wsi13")" ] && ! ls -d "$wsi13.import-"* >/dev/null 2>&1 && [ "$(tail -n 1 "$wsi13/progress.md")" = "Task 2: complete (commits 3333333..4444444, review clean)" ] && ! ls -d "$legacy_i13.importing-"* >/dev/null 2>&1; then pass "an empty destination is replaced in place and a late ledger append is carried over"; else fail "an empty destination is replaced in place and a late ledger append is carried over (rc=$rc: $out)"; fi

# An import interrupted while its candidate was a pointer leaves the pointer
# dangling (its referent is the backup); the next call recovers it and moves
# the referent, relinking the pointer to the new workspace.
i14="$TEST_ROOT/i14"; make_repo "$i14"; mkdir -p "$i14/docs"; : > "$i14/docs/plan.md"; git -C "$i14" add docs; git -C "$i14" commit -qm plan
wsi14=$(ws_path "$i14" "$i14/docs/plan.md")
ptr_dir="$XDG_CACHE_HOME/hyperpowers/sdd/otherkey00000014/plans"; mkdir -p "$ptr_dir"
ptr14="$ptr_dir/$(basename "$wsi14")+$(state_key "$i14" | cut -c1-8)"
referent14="$TEST_ROOT/ptrref14/$(basename "$wsi14")"; mkdir -p "$referent14.importing-777"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$referent14.importing-777/progress.md"
ln -s "$referent14" "$ptr14"
out=$(run_state "$i14" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$ptr14" ] && [ "$(sed -n 2p "$wsi14/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && [ -L "$ptr14" ] && [ "$(cd "$ptr14" && pwd -P)" = "$(cd "$wsi14" && pwd -P)" ] && ! ls -d "$referent14.importing-"* >/dev/null 2>&1; then pass "a dangling pointer whose referent is an interrupted import's backup is recovered and moved"; else fail "a dangling pointer whose referent is an interrupted import's backup is recovered and moved (rc=$rc: $out)"; fi

# A late change that is not an append (the ledger replaced after the copy)
# aborts the import: the source is restored with the new content, nothing
# is moved, and the next import starts over.
i15="$TEST_ROOT/i15"; make_repo "$i15"; mkdir -p "$i15/docs"; : > "$i15/docs/plan.md"; git -C "$i15" add docs; git -C "$i15" commit -qm plan
wsi15=$(ws_path "$i15" "$i15/docs/plan.md")
legacy_i15="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i15")/plans/$(basename "$wsi15")"
mkdir -p "$legacy_i15"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i15/progress.md"
out=$(HYPERPOWERS_TEST_LATE_REPLACE='# SDD ledger — plan: docs/plan.md' run_state "$i15" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=import-failed from=$legacy_i15" ] && [ -d "$legacy_i15" ] && [ ! -L "$legacy_i15" ] && [ "$(wc -l < "$legacy_i15/progress.md" | tr -d ' ')" = 1 ] && [ ! -f "$wsi15/progress.md" ] && ! ls -d "$legacy_i15.importing-"* >/dev/null 2>&1; then pass "a non-append late change aborts the import and restores the current source"; else fail "a non-append late change aborts the import and restores the current source (rc=$rc: $out)"; fi
out=$(run_state "$i15" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i15" ] && [ -L "$legacy_i15" ] && [ "$(wc -l < "$wsi15/progress.md" | tr -d ' ')" = 1 ]; then pass "the next import moves the current source"; else fail "the next import moves the current source (rc=$rc: $out)"; fi

# A cutover interrupted after publication whose source then gained a line
# (the destination is a published prefix of the source) is finished with
# the remainder reconciled, not reported as ledger-exists.
i16="$TEST_ROOT/i16"; make_repo "$i16"; mkdir -p "$i16/docs"; : > "$i16/docs/plan.md"; git -C "$i16" add docs; git -C "$i16" commit -qm plan
wsi16=$(ws_path "$i16" "$i16/docs/plan.md"); mkdir -p "$wsi16"
legacy_i16="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i16")/plans/$(basename "$wsi16")"
mkdir -p "$legacy_i16.importing-616"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' "$i16" > "$legacy_i16.importing-616/progress.md"
printf 'report\n' > "$legacy_i16.importing-616/task-1-report.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsi16/progress.md"
printf 'report\n' > "$wsi16/task-1-report.md"
out=$(run_state "$i16" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i16" ] && [ -L "$legacy_i16" ] && ! ls -d "$legacy_i16.importing-"* >/dev/null 2>&1 && [ "$(wc -l < "$wsi16/progress.md" | tr -d ' ')" = 3 ] && [ "$(tail -n 1 "$wsi16/progress.md")" = "Task 2: complete (commits 3333333..4444444, review clean)" ] && [ "$(head -n 1 "$wsi16/progress.md")" = "# SDD ledger — plan: docs/plan.md" ]; then pass "an interrupted cutover whose source gained a line is finished with the remainder reconciled"; else fail "an interrupted cutover whose source gained a line is finished with the remainder reconciled (rc=$rc: $out)"; fi

# import touches the legacy root before renaming the source aside, so the
# plain-cache reclaim of idle roots cannot take the backup during the cutover.
i17="$TEST_ROOT/i17"; make_repo "$i17"; mkdir -p "$i17/docs"; : > "$i17/docs/plan.md"; git -C "$i17" add docs; git -C "$i17" commit -qm plan
wsi17=$(ws_path "$i17" "$i17/docs/plan.md")
root_i17="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i17")"
legacy_i17="$root_i17/plans/$(basename "$wsi17")"
mkdir -p "$legacy_i17"; printf '# SDD ledger — plan: docs/plan.md\n' > "$legacy_i17/progress.md"
touch -t 202601010000 "$root_i17"
out=$(run_state "$i17" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i17" ] && [ -z "$(find "$root_i17" -maxdepth 0 -mtime +14 2>/dev/null)" ]; then pass "import refreshes the legacy root before the cutover"; else fail "import refreshes the legacy root before the cutover (rc=$rc: $out)"; fi

echo ""
echo "=== sdd-dir and the plain fallback over branch state ==="
make_pair p5
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
wsf4=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf4/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove:plans/$(basename "$wsf4")/notes.txt" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ -f "$wsf4/notes.txt" ] && [ "$(sed -n 2p "$wsf4/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "a file created between the snapshot and the removal makes finish busy and keeps it"; else fail "a file created between the snapshot and the removal makes finish busy (rc=$rc: $out)"; fi
out=$(run_state "$f1" finish docs/plan.md); rc=$?
last4=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf4" ] && [ "$(git -C "$co_f1" show "$last4:plans/$(basename "$wsf4")/notes.txt" 2>/dev/null)" = "concurrent write" ]; then pass "the retry snapshots the new file and finishes"; else fail "the retry snapshots the new file and finishes (rc=$rc: $out)"; fi
wsf5=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf5/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove:plans/$(basename "$wsf5")/task-9-brief.md" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf5" ]; then pass "an ignored file created between the snapshot and the removal does not block finish"; else fail "an ignored file created between the snapshot and the removal does not block finish (rc=$rc: $out)"; fi
wsf6=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf6/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="remove-after-rename:task-2-report.md" bash "$SDD_STATE" finish docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(sed -n 2p "$wsf6/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && [ ! -e "$wsf6/task-2-report.md" ] && ! ls -d "$wsf6"/.removing-* >/dev/null 2>&1 && [ "$(cat "$wsf6".reappeared-*/task-2-report.md 2>/dev/null)" = "written after rename" ]; then pass "a workspace recreated after the rename-aside is moved beside the restored copy and finish is busy"; else fail "a workspace recreated after the rename-aside is moved beside the restored copy (rc=$rc: $out)"; fi
rm -rf "$wsf6".reappeared-*
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="remove-after-rename-changed:task-2-report.md" bash "$SDD_STATE" finish docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && grep -q '^concurrent write$' "$wsf6/progress.md" && ! ls -d "$wsf6"/.removing-* >/dev/null 2>&1 && [ "$(cat "$wsf6".reappeared-*/task-2-report.md 2>/dev/null)" = "written after rename" ]; then pass "a changed copy restored over a recreated workspace is not nested inside it"; else fail "a changed copy restored over a recreated workspace is not nested inside it (rc=$rc: $out; $(ls -a "$wsf6" 2>/dev/null | tr '\n' ' '))"; fi
rm -rf "$wsf6".reappeared-*
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf6" ]; then pass "finish succeeds once the recreated files are out of the way"; else fail "finish succeeds once the recreated files are out of the way (rc=$rc: $out)"; fi
wsf7=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf7/progress.md"
out=$(run_state "$f1" finish docs/plan.md docs/other.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ -d "$wsf7" ]; then pass "a second positional argument is a usage error and finishes nothing"; else fail "a second positional argument is a usage error and finishes nothing (rc=$rc: $out)"; fi
ln -s progress.md "$wsf7/ledger-link"; run_state "$f1" snapshot docs/plan.md >/dev/null
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf7" ]; then pass "a tracked symlink compares by its link text and does not block finish"; else fail "a tracked symlink compares by its link text and does not block finish (rc=$rc: $out)"; fi
wsf8=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf8/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove-link:plans/$(basename "$wsf8")/late-link" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ -L "$wsf8/late-link" ]; then pass "a symlink created between the snapshot and the removal counts as an extra entry"; else fail "a symlink created between the snapshot and the removal counts as an extra entry (rc=$rc: $out)"; fi
rm -f "$wsf8/late-link"
tomb8="$(dirname "$wsf8")/.removing-$(basename "$wsf8")-424242"; mv "$wsf8" "$tomb8"
out=$(run_state "$f1" finish docs/plan.md 2>/dev/null); rc=$?
last8=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$tomb8" ] && [ ! -d "$wsf8" ] && [ "$(git -C "$co_f1" show "$last8:plans/$(basename "$wsf8")/progress.md" 2>/dev/null | sed -n 2p)" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "a copy left by an interrupted removal is restored and finished, its ledger in history"; else fail "a copy left by an interrupted removal is restored and finished (rc=$rc: $out)"; fi
wsf9=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf9/progress.md"
tomb9="$(dirname "$wsf9")/.removing-$(basename "$wsf9")-434343"; mkdir -p "$tomb9"; printf 'older copy\n' > "$tomb9/progress.md"
err=$(run_state "$f1" finish docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q "$tomb9" && [ -d "$wsf9" ] && [ -d "$tomb9" ]; then pass "a leftover copy beside a live workspace makes finish refuse and name the copy"; else fail "a leftover copy beside a live workspace makes finish refuse and name the copy (rc=$rc: $err)"; fi
rm -rf "$tomb9"
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ]; then pass "finish proceeds once the leftover copy is resolved"; else fail "finish proceeds once the leftover copy is resolved (rc=$rc: $out)"; fi
wsf10=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nrestored by sdd-dir\n' > "$wsf10/progress.md"
mv "$wsf10" "$(dirname "$wsf10")/.removing-$(basename "$wsf10")-454545"
out=$(run_sdd_dir "$f1" docs/plan.md)
if [ "$out" = "$wsf10" ] && [ "$(sed -n 2p "$wsf10/progress.md")" = "restored by sdd-dir" ] && ! ls -d "$(dirname "$wsf10")"/.removing-* >/dev/null 2>&1; then pass "sdd-dir brings back a copy left by an interrupted removal instead of creating an empty workspace"; else fail "sdd-dir brings back a copy left by an interrupted removal instead of creating an empty workspace ($out)"; fi
run_state "$f1" finish docs/plan.md >/dev/null
wsf11=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsf11/progress.md"; mkdir "$wsf11/held"; : > "$wsf11/held/f"; chmod 555 "$wsf11/held"
err=$(run_state "$f1" finish docs/plan.md 2>&1 >/dev/null); rc=$?
chmod 755 "$(dirname "$wsf11")"/.removing-*/held 2>/dev/null
if [ "$rc" -eq 0 ] && printf '%s' "$err" | grep -q 'could not delete' && ! git -C "$co_f1" ls-tree -r --name-only hyperpowers/state | grep -q "plans/$(basename "$wsf11")/" && ls -d "$(dirname "$wsf11")"/.removing-* >/dev/null 2>&1 && [ ! -d "$wsf11" ]; then pass "under the branch backend the removal is committed and a deletion that fails names the surviving copy"; else fail "under the branch backend the removal is committed and a deletion that fails names the surviving copy (rc=$rc: $err)"; fi
rm -rf "$(dirname "$wsf11")"/.removing-*
wsf12=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf12/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-after-verify:task-3-report.md" bash "$SDD_STATE" finish docs/plan.md 2>"$TEST_ROOT/wsf12.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recreated during finish' "$TEST_ROOT/wsf12.err" && ! git -C "$co_f1" ls-tree -r --name-only hyperpowers/state | grep -q "plans/$(basename "$wsf12")/" && [ "$(cat "$wsf12/task-3-report.md")" = "late" ] && [ ! -e "$wsf12/progress.md" ] && ! ls -d "$(dirname "$wsf12")"/.removing-* >/dev/null 2>&1; then pass "a workspace recreated after the verification stays on disk, is named, and never enters the removal commit"; else fail "a workspace recreated after the verification stays on disk, is named, and never enters the removal commit (rc=$rc: $out)"; fi
rm -rf "$wsf12"
wsp=$(run_sdd_dir "$rp" docs/plan.md 2>/dev/null); printf 'x\n' > "$wsp/progress.md"
out=$(run_state "$rp" finish docs/plan.md 2>/dev/null)
if [ "$out" = "status=finished backend=plain" ] && [ ! -d "$wsp" ]; then pass "finish under the plain backend removes the plain workspace"; else fail "finish under the plain backend removes the plain workspace ($out)"; fi
wsp2=$(run_sdd_dir "$rp" docs/plan.md 2>/dev/null); printf 'x\n' > "$wsp2/progress.md"
out=$(cd "$rp" && HYPERPOWERS_TEST_WRITER_AT="remove-after-rename-changed:task-2-report.md" bash "$SDD_STATE" finish docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && grep -q '^concurrent write$' "$wsp2/progress.md" && ! ls -d "$wsp2"/.removing-* >/dev/null 2>&1 && [ "$(cat "$wsp2".reappeared-*/task-2-report.md 2>/dev/null)" = "written after rename" ]; then pass "under the plain backend a changed copy restored over a recreated workspace is not nested either"; else fail "under the plain backend a changed copy restored over a recreated workspace is not nested (rc=$rc: $out)"; fi
rm -rf "$wsp2".reappeared-*
wsp3=$(run_sdd_dir "$rp" docs/plan.md 2>/dev/null); printf 'x\n' > "$wsp3/progress.md"; mkdir "$wsp3/held"; : > "$wsp3/held/f"; chmod 555 "$wsp3/held"
err=$(run_state "$rp" finish docs/plan.md 2>&1 >/dev/null); rc=$?
chmod 755 "$wsp3/held" 2>/dev/null; chmod 755 "$(dirname "$wsp3")"/.removing-*/held 2>/dev/null
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'could not delete' && [ -f "$wsp3/held/f" ] && ! ls -d "$(dirname "$wsp3")"/.removing-* >/dev/null 2>&1; then pass "under the plain backend a deletion that fails is an error and what remains is restored"; else fail "under the plain backend a deletion that fails is an error and what remains is restored (rc=$rc: $err)"; fi
rm -rf "$wsp3"

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
mkdir -p "$STATE_ROOT/badkey0000000000000000000000000000000000"; printf 'not a gitdir line\n' > "$STATE_ROOT/badkey0000000000000000000000000000000000/.git"
mkdir -p "$STATE_ROOT/relkey0000000000000000000000000000000000/.gitdir-here"; printf 'gitdir: .gitdir-here\n' > "$STATE_ROOT/relkey0000000000000000000000000000000000/.git"
out=$(run_state "$pr" prune --repo "$pr"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=listed plans=$wso_enc checkouts=deadkey0000000000000000000000000000000000" ] && [ -d "$wso" ]; then pass "prune lists the idle plan (space percent-encoded) and the dead checkout without removing them"; else fail "prune lists the idle plan and the dead checkout without removing them (rc=$rc: $out)"; fi
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-before-remove:plans/$(basename "$wso")/progress.md" bash "$SDD_STATE" prune --repo "$pr" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=pruned plans= kept=$wso_enc checkouts=deadkey0000000000000000000000000000000000" ] && [ -d "$wso" ] && grep -q '^concurrent write$' "$wso/progress.md"; then pass "a workspace written to after selection is kept, line intact"; else fail "a workspace written to after selection is kept (rc=$rc: $out)"; fi
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$pr" snapshot "docs/old plan.md" >/dev/null
touch -t 202601010000 "$wso/progress.md" "$wso"
mkdir -p "$STATE_ROOT/deadkey0000000000000000000000000000000000"; printf 'gitdir: %s/gone/.git/worktrees/x\n' "$TEST_ROOT" > "$STATE_ROOT/deadkey0000000000000000000000000000000000/.git"
mkdir -p "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock"; printf 'session=s-dead\npid=999999\nhost=h\ntime=2026-01-01T00:00:00Z\n' > "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock/owner"; touch -t 202601010000 "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock"
: > "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock-history"; : > "$STATE_ROOT/deadkey0000000000000000000000000000000000.fetched"
out=$(run_state "$pr" prune --repo "$pr" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=pruned plans=$wso_enc kept= checkouts=deadkey0000000000000000000000000000000000" ] && [ ! -d "$wso" ] && [ -d "$wsn" ] && [ ! -d "$STATE_ROOT/deadkey0000000000000000000000000000000000" ] && [ ! -e "$STATE_ROOT/deadkey0000000000000000000000000000000000.backend" ] && [ "$(git -C "$co_pr" log -1 --format=%s hyperpowers/state)" = "sdd: prune $(basename "$wso")" ] && ! git -C "$co_pr" ls-tree -r --name-only hyperpowers/state | grep -q "^plans/$(basename "$wso")/"; then pass "prune --apply removes the whole idle plan, space and all, in one commit and the dead checkout"; else fail "prune --apply removes the idle plan in one commit and the dead checkout (rc=$rc: $out)"; fi
if [ ! -d "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock" ] && [ ! -e "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock-history" ] && [ ! -e "$STATE_ROOT/deadkey0000000000000000000000000000000000.fetched" ]; then pass "a dead checkout's stale lock is taken over and released last, its sidecars gone"; else fail "a dead checkout's stale lock is taken over and released last, its sidecars gone"; fi
if [ -d "$STATE_ROOT/badkey0000000000000000000000000000000000" ]; then pass "a checkout whose .git file cannot be parsed is neither listed nor removed"; else fail "a checkout whose .git file cannot be parsed is neither listed nor removed"; fi
if [ -d "$STATE_ROOT/relkey0000000000000000000000000000000000/.gitdir-here" ]; then pass "a relative gitdir resolves against its checkout and a live one is kept"; else fail "a relative gitdir resolves against its checkout and a live one is kept"; fi
out=$(run_state "$pr" prune --repo "$pr" --days 08); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=listed" ]; then pass "--days 08 is read as decimal eight"; else fail "--days 08 is read as decimal eight (rc=$rc: $out)"; fi
: > "$pr/docs/third.md"; git -C "$pr" add docs; git -C "$pr" commit -qm third
wst=$(run_sdd_dir "$pr" docs/third.md); printf 'third\n' > "$wst/progress.md"
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$pr" snapshot docs/third.md >/dev/null
touch -t 202601010000 "$wst/progress.md" "$wst"
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-after-verify:$(basename "$wst")/late.md" bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pruned" ] && printf '%s' "$out" | grep -q "plans=$(basename "$wst")" && ! git -C "$co_pr" ls-tree -r --name-only hyperpowers/state | grep -q "^plans/$(basename "$wst")/" && [ "$(cat "$wst/late.md")" = "late" ] && [ ! -e "$wst/progress.md" ] && ! ls -d "$co_pr"/plans/.removing-* >/dev/null 2>&1; then pass "a plan recreated after prune's verification stays on disk and never enters the prune commit"; else fail "a plan recreated after prune's verification stays on disk and never enters the prune commit (rc=$rc: $out)"; fi
rm -rf "$wst"
out=$(run_state "$pr" prune --repo "$pr" --days abc 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ]; then pass "--days rejects a non-numeric value with usage"; else fail "--days rejects a non-numeric value with usage (rc=$rc: $out)"; fi
if [ "$(run_state "$rp" prune --repo "$rp" 2>/dev/null)" = "status=plain" ]; then pass "prune under the plain backend reports plain"; else fail "prune under the plain backend reports plain"; fi
echo ""
echo "=== sync ==="
make_pair p7
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
if [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ] && [ "$(cat "$wsb/progress.md")" = "$(git -C "$co_b" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ]; then pass "after a writer-free fast-forward the checkout is clean and the ledger equals the tree's blob"; else fail "after a writer-free fast-forward the checkout is clean and the ledger equals the tree's blob"; fi
printf 'Task 3: complete (commits 5555555..6666666, review clean)\n' >> "$wsb/progress.md"
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=ahead" ]; then pass "an unpushed snapshot reports ahead"; else fail "an unpushed snapshot reports ahead ($out)"; fi
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
printf 'note from A while behind\n' >> "$wsa/progress.md"
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=merged" ] && grep -q '^Task 3: complete' "$wsa/progress.md" && grep -q '^note from A while behind$' "$wsa/progress.md" && ! grep -q '^<<<<<<<' "$wsa/progress.md" && [ "$(git -C "$co_a" log -1 --format=%P hyperpowers/state | wc -w | tr -d ' ')" = 2 ]; then pass "behind with pending ledger edits ends merged with both sides' lines and two parents"; else fail "behind with pending ledger edits ends merged (rc=$rc: $out)"; fi
if [ -z "$(git -C "$co_a" status --porcelain -- plans/)" ] && [ "$(cat "$wsa/progress.md")" = "$(git -C "$co_a" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ]; then pass "after a merge the checkout is clean and the ledger equals the merged blob"; else fail "after a merge the checkout is clean and the ledger equals the merged blob"; fi
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
# Two hosts append concurrently; the second host's fast-forward lands on
# the first host's merge, where S is not a prefix of the target.
printf 'walk A\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
printf 'walk B\n' >> "$wsb/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=merged" ] && [ "$(cat "$wsb/progress.md")" = "$(git -C "$co_b" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ]; then pass "the merging host's live ledger equals the merged blob"; else fail "the merging host's live ledger equals the merged blob (rc=$rc: $out)"; fi
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(cat "$wsa/progress.md")" = "$(git -C "$co_a" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ] && [ "$(grep -c '^walk A$' "$wsa/progress.md")" -eq 1 ] && [ "$(grep -c '^walk B$' "$wsa/progress.md")" -eq 1 ]; then pass "a fast-forward onto the other host's merge rewrites the ledger in place: tree order, each line once"; else fail "a fast-forward onto the other host's merge rewrites the ledger in place (rc=$rc: $out)"; fi
if [ "$(run_state "$PAIR_A" sync docs/plan.md | cut -d' ' -f1)" = "status=up-to-date" ] && [ "$(run_state "$PAIR_B" sync docs/plan.md | cut -d' ' -f1)" = "status=up-to-date" ]; then pass "both hosts stay up-to-date afterwards: no reorder commit"; else fail "both hosts stay up-to-date afterwards: no reorder commit"; fi
# A writer that lands between the rewrite's size check and its write on
# every attempt: the apply stops with the ref moved and the marker kept,
# nothing is snapshotted over it, and the next call finishes the apply with
# every raced line preserved.
printf 'walk2 A\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
printf 'walk2 B\n' >> "$wsb/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT=ledger-apply-before-rewrite bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
remote_tip=$(git -C "$co_a" rev-parse origin/hyperpowers/state)
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ] && [ -f "$co_a/.sync-applying" ] && [ "$(git -C "$co_a" rev-parse hyperpowers/state)" = "$remote_tip" ]; then pass "a writer racing the rewrite leaves the apply unfinished with the marker kept and nothing snapshotted over it"; else fail "a writer racing the rewrite leaves the apply unfinished with the marker kept and nothing snapshotted over it (rc=$rc: $out)"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=ahead" ] && [ ! -f "$co_a/.sync-applying" ] && [ -z "$(git -C "$co_a" status --porcelain -- plans/)" ] && [ "$(grep -c '^raced the rewrite$' "$wsa/progress.md")" -eq 3 ] && [ "$(grep -c '^walk2 A$' "$wsa/progress.md")" -eq 1 ] && [ "$(grep -c '^walk2 B$' "$wsa/progress.md")" -eq 1 ] && [ "$(git -C "$co_a" rev-parse hyperpowers/state^)" = "$remote_tip" ]; then pass "the next call finishes the apply, keeps all three raced lines, and snapshots them on top of the target"; else fail "the next call finishes the apply, keeps all three raced lines, and snapshots them on top of the target (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_B" sync docs/plan.md >/dev/null
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
( cd "$PAIR_B" && HYPERPOWERS_TEST_PAUSE_AT=sync-before-apply bash "$SDD_STATE" sync docs/plan.md > "$TEST_ROOT/p7.sync.out" 2>/dev/null ) &
sync_pid=$!
n=0; while [ ! -e "$co_b/.sync-paused" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
printf 'appended during sync\n' >> "$wsb/progress.md"
rm -f "$co_b/.sync-pause"
wait "$sync_pid"
if [ "$(cut -d' ' -f1 "$TEST_ROOT/p7.sync.out")" = "status=fast-forwarded" ] && grep -q '^Task 4: complete' "$wsb/progress.md" && grep -q '^appended during sync$' "$wsb/progress.md" && [ "$(grep -c '^Task 4: complete' "$wsb/progress.md")" -eq 1 ]; then pass "a ledger line appended while apply is held survives the fast-forward, and the remote line lands once"; else fail "a ledger line appended while apply is held survives the fast-forward ($(cat "$TEST_ROOT/p7.sync.out"))"; fi
# The held-apply line is still local: publish it so the next remote change is
# a plain fast-forward for this host.
settle_pair() { run_state "$PAIR_B" snapshot docs/plan.md >/dev/null; run_state "$PAIR_B" sync docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_A" sync docs/plan.md >/dev/null; }
settle_pair
# A write after the status check: the ledger is appended to, never replaced,
# so a line written at the last moment is kept too.
printf 'Task 4b: complete (commits bbbbbbb..ccccccc, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-apply:plans/$(basename "$wsa")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^concurrent write$' "$wsb/progress.md" && grep -q '^Task 4b: complete' "$wsb/progress.md"; then pass "a ledger line written during apply is kept beside the remote lines"; else fail "a ledger line written during apply is kept beside the remote lines (rc=$rc: $out)"; fi
settle_pair
printf 'Task 5: complete (commits 9999999..aaaaaaa, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-apply:plans/$(basename "$wsa")/task-1-report.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ]; then pass "a report that keeps changing across three attempts ends busy"; else fail "a report that keeps changing across three attempts ends busy (rc=$rc: $out)"; fi

# The busy attempts left local snapshots behind; stand in for the human
# partner discarding them, so the next remote change is a plain fast-forward.
git -C "$co_b" reset -q --hard origin/hyperpowers/state
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
printf 'Task 5c: complete (commits 9999999..aaaaaaa, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-ledger-apply bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && [ "$(grep -c '^Task 5c: complete' "$wsb/progress.md")" -eq 1 ]; then pass "the crash seam after the ledger apply leaves the line applied and the marker in place"; else fail "the crash seam after the ledger apply leaves the line applied and the marker in place (rc=$rc)"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=up-to-date" ] && [ "$(grep -c '^Task 5c: complete' "$wsb/progress.md")" -eq 1 ] && [ ! -f "$co_b/.sync-applying" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "recovery after the ledger apply appends nothing twice"; else fail "recovery after the ledger apply appends nothing twice ($out)"; fi

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
git -C "$co_b" merge --abort >/dev/null 2>&1 || true
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); run_state "$PAIR_A" sync docs/plan.md >/dev/null

# Offline outcomes and the explicit override.
off="$TEST_ROOT/hostA/p7-off"; git clone -q --single-branch -b main "$PAIR_REMOTE" "$off" 2>/dev/null
git -C "$off" remote set-url origin "$TEST_ROOT/does-not-exist.git"
out=$(run_state "$off" sync docs/plan.md); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=offline-no-state" ]; then pass "a fresh clone that cannot fetch reports offline-no-state"; else fail "a fresh clone that cannot fetch reports offline-no-state (rc=$rc: $out)"; fi
if run_sdd_dir "$off" docs/plan.md >/dev/null 2>&1; then fail "sdd-dir refuses to invent a dossier on that host"; else pass "sdd-dir refuses to invent a dossier on that host"; fi
off2="$TEST_ROOT/hostA/p7-off2"; git clone -q "$PAIR_REMOTE" "$off2" 2>/dev/null
git -C "$off2" remote set-url origin "$TEST_ROOT/does-not-exist.git"
out=$(run_state "$off2" sync docs/plan.md); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=offline" ] && [ -e "$STATE_ROOT/$(state_key "$off2")/.git" ] && [ -n "$(git -C "$off2" rev-parse -q --verify refs/heads/hyperpowers/state 2>/dev/null)" ]; then pass "a default clone that cannot fetch still has the branch as a remote-tracking ref: offline, checkout built from it"; else fail "a default clone that cannot fetch still has the branch as a remote-tracking ref (rc=$rc: $out)"; fi
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
# The remaining checks use docs/second.md, present on both hosts.
ws2b="$co_b/plans/$(basename "$ws2a")"
run_state "$PAIR_A" sync docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_B" sync docs/second.md >/dev/null
# The race test above left B's snapshot of its local line unmerged (an
# ordinary divergence by design); the human partner discards it here so the
# checks below start from a host that is level with the remote.
git -C "$co_b" merge --abort >/dev/null 2>&1 || true
git -C "$co_b" reset -q --hard origin/hyperpowers/state
# A branch at the state name without the sentinel is foreign.
foreign=$(git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(git -C "$PAIR_A" hash-object -t tree /dev/null)" -m foreign)
git -C "$PAIR_A" push -qf origin "$foreign:refs/heads/hyperpowers/state" 2>/dev/null
tip_b=$(git -C "$co_b" rev-parse hyperpowers/state)
out=$(run_state "$PAIR_B" sync docs/second.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "${out%% *}" = "status=foreign" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$tip_b" ] && [ -f "$ws2b/progress.md" ]; then pass "a remote branch without the sentinel is foreign: nothing reconciled, ref and files untouched"; else fail "a remote branch without the sentinel is foreign: nothing reconciled, ref and files untouched (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -qf origin hyperpowers/state 2>/dev/null
if [ "$(run_state "$PAIR_B" sync docs/second.md | cut -d' ' -f1)" = "status=up-to-date" ]; then pass "with the real branch restored, sync resumes"; else fail "with the real branch restored, sync resumes"; fi
# A deletion the target asks for that cannot be done is an error, never "applied".
printf 'report two\n' > "$ws2a/task-2-report.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/second.md >/dev/null
rm -f "$ws2a/task-2-report.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
chmod 555 "$ws2b"
out=$(run_state "$PAIR_B" sync docs/second.md 2>/dev/null); rc=$?
chmod 755 "$ws2b"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ -f "$ws2b/task-2-report.md" ]; then pass "a deletion the target asks for that fails is an error with the marker kept, never reported as applied"; else fail "a deletion the target asks for that fails is an error with the marker kept, never reported as applied (rc=$rc: $out)"; fi
out=$(run_state "$PAIR_B" sync docs/second.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=up-to-date" ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -e "$ws2b/task-2-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "once the directory is writable the next sync finishes the deletion"; else fail "once the directory is writable the next sync finishes the deletion (rc=$rc: $out)"; fi
# A writer that lands between the extension append and the in-place
# overwrite: the line survives and the apply succeeds.
printf 'ov A\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null
printf 'ov B\n' >> "$ws2b/progress.md"; run_state "$PAIR_B" snapshot docs/second.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/second.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT=ledger-apply-before-overwrite bash "$SDD_STATE" sync docs/second.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(grep -c '^raced the overwrite$' "$ws2a/progress.md")" -eq 1 ] && [ "$(grep -c '^ov A$' "$ws2a/progress.md")" -eq 1 ] && [ "$(grep -c '^ov B$' "$ws2a/progress.md")" -eq 1 ]; then pass "a line appended between the extension append and the overwrite survives the rewrite"; else fail "a line appended between the extension append and the overwrite survives the rewrite (rc=$rc: $out)"; fi
run_state "$PAIR_A" sync docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_B" sync docs/second.md >/dev/null
# The marker is a barrier for claim, prune and finish.
printf 'Task 9: complete (commits fffffff..0000000, review clean)\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/second.md >/dev/null 2>&1 )
out=$(run_state "$PAIR_B" claim docs/second.md 9 --session s-claim); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=done task=9" ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 9: complete' "$ws2b/progress.md"; then pass "claim recovers an interrupted apply before it reads the ledger"; else fail "claim recovers an interrupted apply before it reads the ledger (rc=$rc: $out)"; fi
printf 'Task 10: complete (commits 1212121..3434343, review clean)\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/second.md >/dev/null 2>&1 )
out=$(run_state "$PAIR_B" prune --repo "$PAIR_B" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pruned" ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 10: complete' "$ws2b/progress.md"; then pass "prune --apply recovers an interrupted apply before it selects"; else fail "prune --apply recovers an interrupted apply before it selects (rc=$rc: $out)"; fi
printf 'Task 11: complete (commits 5656565..7878787, review clean)\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/second.md >/dev/null 2>&1 )
out=$(run_state "$PAIR_B" finish docs/second.md --force); rc=$?
last_b=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -f "$co_b/.sync-applying" ] && git -C "$co_b" show "$last_b:plans/$(basename "$ws2a")/progress.md" 2>/dev/null | grep -q '^Task 11: complete'; then pass "finish recovers an interrupted apply before it reads claims or snapshots"; else fail "finish recovers an interrupted apply before it reads claims or snapshots (rc=$rc: $out)"; fi
# A marker that cannot be trusted fails closed and is named.
printf 'garbage\n' > "$co_b/.sync-applying"
out=$(run_state "$PAIR_B" sync docs/second.md 2>"$TEST_ROOT/marker.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'not a valid sync marker' "$TEST_ROOT/marker.err" && [ -f "$co_b/.sync-applying" ]; then pass "a malformed marker fails closed and is named"; else fail "a malformed marker fails closed and is named (rc=$rc: $out)"; fi
rm -f "$co_b/.sync-applying"
tipb=$(git -C "$co_b" rev-parse hyperpowers/state); prev=$(git -C "$co_b" rev-parse hyperpowers/state^)
printf '%s %s\n' "$prev" "$prev" > "$co_b/.sync-applying"
out=$(run_state "$PAIR_B" sync docs/second.md 2>"$TEST_ROOT/marker2.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'has moved from its target' "$TEST_ROOT/marker2.err" && [ -f "$co_b/.sync-applying" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$tipb" ]; then pass "a marker whose target the branch has left fails closed and is named"; else fail "a marker whose target the branch has left fails closed and is named (rc=$rc: $out)"; fi
rm -f "$co_b/.sync-applying"
echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi
echo "STATUS: PASSED"
