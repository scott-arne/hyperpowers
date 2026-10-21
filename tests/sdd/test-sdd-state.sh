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

echo ""
if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi
echo "STATUS: PASSED"
