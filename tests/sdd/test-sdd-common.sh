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
TEST_ROOT=$(mktemp -d) || exit 2
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || exit 2
export XDG_CACHE_HOME="$TEST_ROOT/cache"
# The identity-fallback assertions need a host whose global git config sets no user.name or user.email (GIT_CONFIG_GLOBAL needs git 2.32+).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
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

ln -s "$TEST_ROOT/outside.md" "$repo_a/docs/x/link.md"; : > "$TEST_ROOT/outside.md"
if hp_plan_dir "$repo_a/docs/x/link.md" >/dev/null 2>&1; then fail "hp_plan_dir rejects a symlinked plan file"; else pass "hp_plan_dir rejects a symlinked plan file"; fi

# --- old git and no repository ---------------------------------------------
real_git=$(command -v git)
stub="$TEST_ROOT/stub"; mkdir -p "$stub"
printf '#!/bin/sh\ncase "$*" in *--path-format=absolute*) echo --path-format=absolute; exec "%s" "$@" ;; esac\nexec "%s" "$@"\n' "$real_git" "$real_git" > "$stub/git"
chmod +x "$stub/git"
stub_dir=$(PATH="$stub:$PATH" hp_common_dir "$repo_a")
if [ "$stub_dir" = "$(cd "$repo_a/.git" && pwd -P)" ]; then pass "hp_common_dir survives a git that echoes --path-format"; else fail "hp_common_dir survives a git that echoes --path-format (got '$stub_dir')"; fi
nogit="$TEST_ROOT/nogit"; mkdir -p "$nogit"
bad=0
for fn in hp_checkout_path hp_plain_root hp_stamp_path hp_backend; do
    if (cd "$nogit" && $fn "$nogit") >/dev/null 2>&1; then bad=1; fi
done
if (cd "$nogit" && hp_lock "$nogit") >/dev/null 2>&1; then bad=1; fi
state_root="$XDG_CACHE_HOME/hyperpowers/state"
if [ "$bad" -eq 0 ] && [ ! -e "$state_root/.lock" ] && [ ! -e "$state_root/.backend" ] && [ ! -e "$state_root/.fetched" ] && [ ! -e "$state_root/.lock-history" ]; then pass "keyed paths and the lock fail outside a repository without unkeyed files"; else fail "keyed paths and the lock fail outside a repository without unkeyed files"; fi

# --- lock ------------------------------------------------------------------
# The staleness cases need owner pids that are certainly not live. A literal
# like 999999 is dead on macOS and can be a running process on a Linux host
# with a large pid_max, where every assertion below would become a 30 s wait
# and a false FAIL; a child this shell has reaped is dead on either.
dead_pid() { local p; ( exit 0 ) & p=$!; wait "$p" 2>/dev/null; printf '%s\n' "$p"; }
DEAD_A=$(dead_pid); DEAD_B=$(dead_pid)
while [ "$DEAD_B" = "$DEAD_A" ]; do DEAD_B=$(dead_pid); done
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
mkdir -p "$lock_dir"; printf 'session=old\npid=%s\nhost=x\ntime=t\n' "$DEAD_A" > "$lock_dir/owner"
touch -t 202601010000 "$lock_dir"
start=$(date +%s); hp_lock "$lock_repo"; rc=$?; end=$(date +%s)
if [ "$rc" -eq 0 ] && [ $((end - start)) -le 2 ] && grep -q 'takeover' "$lock_dir-history" && [ ! -d "$lock_dir.takeover" ]; then pass "a stale lock with a dead pid is taken over, recorded, and the guard released"; else fail "a stale lock with a dead pid is taken over, recorded, and the guard released (rc=$rc)"; fi
hp_unlock
# Two contenders meeting one stale lock: exactly one takes over, the other
# waits for it, and the lock that remains belongs to the second one.
mkdir -p "$lock_dir"; printf 'session=old\npid=%s\nhost=x\ntime=t\n' "$DEAD_A" > "$lock_dir/owner"; touch -t 202601010000 "$lock_dir"
bash -c '. "$1"; hp_lock "$2" && { echo "$$" > "$3"; sleep 1; hp_unlock; }' _ "$LIB" "$lock_repo" "$TEST_ROOT/race1" &
bash -c '. "$1"; hp_lock "$2" && { echo "$$" > "$3"; sleep 1; hp_unlock; }' _ "$LIB" "$lock_repo" "$TEST_ROOT/race2" &
wait
if [ -f "$TEST_ROOT/race1" ] && [ -f "$TEST_ROOT/race2" ] && [ "$(grep -c takeover "$lock_dir-history")" -eq 2 ] && [ ! -d "$lock_dir" ]; then pass "two contenders on one stale lock serialize through the takeover guard"; else fail "two contenders on one stale lock serialize through the takeover guard"; fi
# A stale lock plus a stranded, backdated takeover guard is recovered.
mkdir -p "$lock_dir" "$lock_dir.takeover"; printf 'session=old\npid=%s\nhost=x\ntime=t\n' "$DEAD_A" > "$lock_dir/owner"
touch -t 202601010000 "$lock_dir" "$lock_dir.takeover"
start=$(date +%s); hp_lock "$lock_repo"; rc=$?; end=$(date +%s)
if [ "$rc" -eq 0 ] && [ $((end - start)) -le 5 ] && [ ! -d "$lock_dir.takeover" ]; then pass "a stranded takeover guard is cleared and the lock taken"; else fail "a stranded takeover guard is cleared and the lock taken (rc=$rc)"; fi
hp_unlock
# A contender that paused after validating a stale lock cannot take the lock
# from the faster contender that replaced that owner meanwhile: its claim
# names a generation that is already taken, and the fresh owner survives.
mkdir -p "$lock_dir"; printf 'session=old\npid=%s\nhost=x\ntime=t\n' "$DEAD_A" > "$lock_dir/owner"; touch -t 202601010000 "$lock_dir"
paused_gen=$(hp_lock_generation "$(hp_lock_owner_text "$lock_dir")")
hp_lock "$lock_repo"; rc=$?
bash -c '. "$1"; hp_lock_claim "$2" "$3"' _ "$LIB" "$lock_dir" "$paused_gen" 2>/dev/null; claim_rc=$?
if [ "$rc" -eq 0 ] && [ "$claim_rc" -ne 0 ] && grep -q "^pid=$$\$" "$lock_dir/owner" 2>/dev/null && [ -d "$lock_dir/taken-$paused_gen" ] && [ -d "$lock_dir" ]; then pass "a paused contender's late claim fails and the fresh owner survives"; else fail "a paused contender's late claim fails and the fresh owner survives (rc=$rc claim_rc=$claim_rc)"; fi
hp_unlock
if [ ! -d "$lock_dir" ]; then pass "hp_unlock removes a taken-over lock and its markers"; else fail "hp_unlock removes a taken-over lock and its markers"; fi
# A claimant that died before renaming its identity over owner is the
# effective owner: the next contender follows the chain and takes over
# that generation, and the history names the dead claimant.
mkdir -p "$lock_dir"; printf 'session=old\npid=%s\nhost=x\ntime=t\n' "$DEAD_A" > "$lock_dir/owner"
dead_gen=$(hp_lock_generation "$(cat "$lock_dir/owner")")
mkdir -p "$lock_dir/taken-$dead_gen"; printf 'session=dead\npid=%s\nhost=x\ntime=t\n' "$DEAD_B" > "$lock_dir/taken-$dead_gen/owner"
chain_gen=$(hp_lock_generation "$(cat "$lock_dir/taken-$dead_gen/owner")")
touch -t 202601010000 "$lock_dir"
hp_lock "$lock_repo"; rc=$?
if [ "$rc" -eq 0 ] && grep -q "^pid=$$\$" "$lock_dir/owner" 2>/dev/null && [ -d "$lock_dir/taken-$chain_gen" ] && tail -n 1 "$lock_dir-history" | grep -q "session=dead pid=$DEAD_B"; then pass "a stranded claim is the effective owner and the next contender takes over its generation"; else fail "a stranded claim is the effective owner and the next contender takes over its generation (rc=$rc)"; fi
hp_unlock
# unlock refuses a lock another process owns.
mkdir -p "$lock_dir"; printf 'session=x\npid=%s\nhost=x\ntime=t\n' "$DEAD_B" > "$lock_dir/owner"
# shellcheck disable=SC2034 # read by hp_unlock from the sourced library
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
mkdir -p "$co/plans/p3"; printf 'kept on disk\n' > "$co/plans/p3/progress.md"
sha5=$(hp_commit_paths "$co" hyperpowers/state "p3" plans/p3)
printf 'recreated after verification\n' > "$co/plans/p3/progress.md"
sha6=$(hp_commit_paths --remove "$co" hyperpowers/state "remove p3" plans/p3)
if [ -n "$sha6" ] && [ "$sha6" != none ] && ! git -C "$co" ls-tree -r --name-only "$sha6" | grep -q 'plans/p3' && [ "$(git -C "$co" rev-parse "$sha6^")" = "$sha5" ] && [ "$(cat "$co/plans/p3/progress.md")" = "recreated after verification" ]; then pass "--remove drops the path from the tip without reading the working tree"; else fail "--remove drops the path from the tip without reading the working tree (got '$sha6')"; fi
if [ "$(hp_commit_paths --remove "$co" hyperpowers/state "remove p3 again" plans/p3)" = none ]; then pass "--remove of a path the tip lacks commits nothing"; else fail "--remove of a path the tip lacks commits nothing"; fi
rm -rf "$co/plans/p3"
# A remove with no paths at all would drop every tracked file from the tip.
tip_before=$(git -C "$co" rev-parse hyperpowers/state)
hp_commit_paths --remove "$co" hyperpowers/state "remove nothing" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ] && [ "$(git -C "$co" rev-parse hyperpowers/state)" = "$tip_before" ]; then pass "--remove with no paths refuses and leaves the branch where it was"; else fail "--remove with no paths refuses and leaves the branch where it was (rc=$rc)"; fi

# --- containment ------------------------------------------------------------
croot="$TEST_ROOT/contained"; outside_c="$TEST_ROOT/outside-contained"
mkdir -p "$croot/plans/ws" "$outside_c"; printf 'ledger\n' > "$croot/plans/ws/progress.md"; printf 'untouched\n' > "$outside_c/sentinel"
if hp_contained "$croot" "plans/ws/progress.md" 2>/dev/null; then pass "hp_contained accepts a path of real directories"; else fail "hp_contained accepts a path of real directories"; fi
if hp_contained "$croot" "plans/ws/task-1-report.md" 2>/dev/null; then pass "hp_contained accepts a leaf that does not exist yet"; else fail "hp_contained accepts a leaf that does not exist yet"; fi
ln -s "$outside_c" "$croot/plans/link-ws"
err=$(hp_contained "$croot" "plans/link-ws/progress.md" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && grep -q 'plans/link-ws' < <(printf '%s\n' "$err"); then pass "hp_contained refuses a path under a symlinked directory and names the link"; else fail "hp_contained refuses a path under a symlinked directory and names the link (rc=$rc: $err)"; fi
ln -s "$outside_c/sentinel" "$croot/plans/ws/linked-ledger"
err=$(hp_contained "$croot" "plans/ws/linked-ledger" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && grep -q 'linked-ledger' < <(printf '%s\n' "$err"); then pass "hp_contained refuses a leaf that is a symbolic link"; else fail "hp_contained refuses a leaf that is a symbolic link (rc=$rc: $err)"; fi
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
