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

echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi
echo "STATUS: PASSED"
